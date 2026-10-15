package com.nkssi.splits8.screens

import android.graphics.Bitmap
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.tween
import androidx.compose.foundation.gestures.awaitEachGesture
import androidx.compose.foundation.gestures.awaitFirstDown
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.requiredSize
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.wrapContentSize
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.graphics.toArgb
import androidx.compose.ui.input.pointer.PointerEventPass
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.unit.dp
import com.google.android.gms.maps.CameraUpdateFactory
import com.google.android.gms.maps.GoogleMapOptions
import com.google.android.gms.maps.model.BitmapDescriptor
import com.google.android.gms.maps.model.BitmapDescriptorFactory
import com.google.android.gms.maps.model.JointType
import com.google.android.gms.maps.model.LatLng
import com.google.android.gms.maps.model.LatLngBounds
import com.google.android.gms.maps.model.MapStyleOptions
import com.google.android.gms.maps.model.RoundCap
import com.google.maps.android.compose.GoogleMap
import com.google.maps.android.compose.MapEffect
import com.google.maps.android.compose.MapProperties
import com.google.maps.android.compose.MapUiSettings
import com.google.maps.android.compose.MapsComposeExperimentalApi
import com.google.maps.android.compose.Marker
import com.google.maps.android.compose.MarkerState
import com.google.maps.android.compose.Polyline
import com.google.maps.android.compose.rememberCameraPositionState
import com.nkssi.splits8.R
import com.nkssi.splits8.shared.RoutePt
import com.nkssi.splits8.ui.C
import com.nkssi.splits8.ui.MapTouch
import kotlinx.coroutines.delay
import kotlin.math.cos
import kotlin.math.max

// 실외 러닝 경로 지도 (아이폰 DetailView.swift RouteMap · RouteSnapshot 과 같은 모양)
// 어두운 지도(장소 이름 · 아이콘 없음) 위에 속도별 노란 경로, 시작 흰 점 · 끝 노란 점. 확대 · 이동만 (돌리기 · 기울이기 없음)

private const val MAP_BG = 0xFF1D1E20.toInt()

object RouteGeo {
    fun latLngs(route: List<RoutePt>): List<LatLng> = route.map { LatLng(it.a, it.o) }

    /** 경로가 다 보이게 — 가장자리 여유: 큰 쪽 길이의 20% + 400 m (아이폰 RouteMap.rect 와 같음) */
    fun bounds(route: List<RoutePt>): LatLngBounds {
        val lats = route.map { it.a }
        val lons = route.map { it.o }
        val lat0 = (lats.min() + lats.max()) / 2
        val mPerLat = 111_320.0
        val mPerLon = max(1.0, 111_320.0 * cos(Math.toRadians(lat0)))
        val spanM = max((lats.max() - lats.min()) * mPerLat, (lons.max() - lons.min()) * mPerLon)
        val padM = spanM * 0.2 + 400
        val dLat = padM / mPerLat
        val dLon = padM / mPerLon
        return LatLngBounds(LatLng(lats.min() - dLat, lons.min() - dLon), LatLng(lats.max() + dLat, lons.max() + dLon))
    }

    /** 고정 크기 동그라미 점 (지도를 확대해도 크기 같음) */
    fun dot(sizePx: Int, color: Int): BitmapDescriptor {
        val b = Bitmap.createBitmap(sizePx, sizePx, Bitmap.Config.ARGB_8888)
        val c = android.graphics.Canvas(b)
        val p = android.graphics.Paint(android.graphics.Paint.ANTI_ALIAS_FLAG).apply { this.color = color }
        c.drawCircle(sizePx / 2f, sizePx / 2f, sizePx / 2f, p)
        return BitmapDescriptorFactory.fromBitmap(b)
    }
}

/** 지도를 누르고 있는 동안 화면 스크롤을 멈춤 */
private fun Modifier.holdsScroll(): Modifier = pointerInput(Unit) {
    awaitEachGesture {
        awaitFirstDown(requireUnconsumed = false, pass = PointerEventPass.Initial)
        MapTouch.down = true
        do {
            val e = awaitPointerEvent(PointerEventPass.Initial)
        } while (e.changes.any { it.pressed })
        MapTouch.down = false
    }
}

/**
 * 기록 화면 경로 지도. 지도가 다 뜨기 전에는 [placeholder] (지도 없이 그린 경로) 를 보여 주고, 뜨면 부드럽게 바꿈.
 * chunks = 속도별 토막 (시작 점 번호, 끝 점 번호, 0~1 빠르기). null 이면 노란 한 줄.
 */
@Composable
fun GoogleRouteMap(route: List<RoutePt>, chunks: List<Triple<Int, Int, Double>>?, modifier: Modifier = Modifier, placeholder: @Composable () -> Unit) {
    val ctx = LocalContext.current
    val density = LocalDensity.current
    val pts = remember(route) { RouteGeo.latLngs(route) }
    val bounds = remember(route) { RouteGeo.bounds(route) }
    val camera = rememberCameraPositionState()
    var loaded by remember { mutableStateOf(false) }
    val alpha by animateFloatAsState(if (loaded) 1f else 0f, tween(250), label = "map")
    val style = remember { MapStyleOptions.loadRawResourceStyle(ctx, R.raw.map_dark) }
    val lineW = with(density) { 4.dp.toPx() }
    DisposableEffect(Unit) { onDispose { MapTouch.down = false } }

    Box(modifier) {
        placeholder()
        GoogleMap(
            modifier = Modifier.fillMaxSize().graphicsLayer { this.alpha = alpha }.holdsScroll(),
            cameraPositionState = camera,
            googleMapOptionsFactory = { GoogleMapOptions().backgroundColor(MAP_BG) },
            properties = MapProperties(mapStyleOptions = style, isBuildingEnabled = false, isIndoorEnabled = false),
            uiSettings = MapUiSettings(
                compassEnabled = false, mapToolbarEnabled = false, zoomControlsEnabled = false,
                rotationGesturesEnabled = false, tiltGesturesEnabled = false,
                myLocationButtonEnabled = false, indoorLevelPickerEnabled = false,
            ),
            onMapLoaded = {
                camera.move(CameraUpdateFactory.newLatLngBounds(bounds, 0))
                loaded = true
            },
        ) {
            if (chunks != null) {
                // 느린 곳은 어두운 노랑, 빠른 곳은 밝은 노랑
                for ((a, b, f) in chunks) {
                    Polyline(
                        points = pts.subList(a, b + 1), color = RouteSpeed.color(f), width = lineW,
                        startCap = RoundCap(), endCap = RoundCap(), jointType = JointType.ROUND,
                    )
                }
            } else {
                Polyline(points = pts, color = C.accent, width = lineW, startCap = RoundCap(), endCap = RoundCap(), jointType = JointType.ROUND)
            }
            val startIcon = remember { RouteGeo.dot(with(density) { 10.dp.roundToPx() }, android.graphics.Color.WHITE) }
            val endIcon = remember { RouteGeo.dot(with(density) { 12.dp.roundToPx() }, C.accent.toArgb()) }
            Marker(state = remember { MarkerState(pts.first()) }, icon = startIcon, anchor = Offset(0.5f, 0.5f), flat = true, onClick = { true })
            Marker(state = remember { MarkerState(pts.last()) }, icon = endIcon, anchor = Offset(0.5f, 0.5f), flat = true, zIndex = 1f, onClick = { true })
        }
    }
}

/**
 * 공유 그림 배경용: 보이지 않는 작은 지도(라이트 모드)를 띄워 1080 × [h] 그림을 만들고 그 위에 노란 경로를 그림
 * (아이폰 RouteSnapshot.make 와 같음). 8초 안에 못 만들면 null.
 */
@OptIn(MapsComposeExperimentalApi::class)
@Composable
fun RouteMapShot(route: List<RoutePt>, h: Int, onImage: (Bitmap?) -> Unit) {
    val ctx = LocalContext.current
    val density = LocalDensity.current
    val w = 1080
    var done by remember(route, h) { mutableStateOf(false) }
    val finish: (Bitmap?) -> Unit = { b -> if (!done) { done = true; onImage(b) } }
    LaunchedEffect(route, h) { delay(8000); finish(null) }
    if (done) return
    val pts = remember(route) { RouteGeo.latLngs(route) }
    val bounds = remember(route) { RouteGeo.bounds(route) }
    val style = remember { MapStyleOptions.loadRawResourceStyle(ctx, R.raw.map_dark) }
    // 크기 0 자리에 실제 크기 지도를 거의 투명하게 둠 (완전히 투명하면 안 그려질 수 있음)
    Box(Modifier.size(0.dp)) {
        GoogleMap(
            modifier = Modifier.wrapContentSize(Alignment.TopStart, unbounded = true)
                .requiredSize(with(density) { w.toDp() }, with(density) { h.toDp() })
                .graphicsLayer { alpha = 0.01f },
            googleMapOptionsFactory = { GoogleMapOptions().liteMode(true).backgroundColor(MAP_BG) },
            properties = MapProperties(mapStyleOptions = style),
            uiSettings = MapUiSettings(mapToolbarEnabled = false, zoomControlsEnabled = false, compassEnabled = false),
        ) {
            MapEffect(route, h) { map ->
                runCatching {
                    map.moveCamera(CameraUpdateFactory.newLatLngBounds(bounds, w, h, 0))
                    map.setOnMapLoadedCallback {
                        runCatching {
                            map.snapshot { snap ->
                                if (snap == null) { finish(null); return@snapshot }
                                val proj = map.projection
                                val sx = w.toFloat() / snap.width
                                val sy = h.toFloat() / snap.height
                                val out = Bitmap.createBitmap(w, h, Bitmap.Config.ARGB_8888)
                                val c = android.graphics.Canvas(out)
                                c.drawBitmap(Bitmap.createScaledBitmap(snap, w, h, true), 0f, 0f, null)
                                val path = android.graphics.Path()
                                pts.forEachIndexed { i, ll ->
                                    val p = proj.toScreenLocation(ll)
                                    val x = p.x * sx
                                    val y = p.y * sy
                                    if (i == 0) path.moveTo(x, y) else path.lineTo(x, y)
                                }
                                val paint = android.graphics.Paint(android.graphics.Paint.ANTI_ALIAS_FLAG).apply {
                                    color = 0xFFFFE600.toInt(); this.style = android.graphics.Paint.Style.STROKE; strokeWidth = max(6f, w / 120f)
                                    strokeCap = android.graphics.Paint.Cap.ROUND; strokeJoin = android.graphics.Paint.Join.ROUND
                                }
                                c.drawPath(path, paint)
                                finish(out)
                            }
                        }.onFailure { finish(null) }
                    }
                }.onFailure { finish(null) }
            }
        }
    }
}
