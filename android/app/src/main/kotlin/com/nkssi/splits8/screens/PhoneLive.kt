package com.nkssi.splits8.screens

import android.Manifest
import android.annotation.SuppressLint
import android.content.Context
import android.content.pm.PackageManager
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.location.Geocoder
import android.location.Location
import android.location.LocationListener
import android.location.LocationManager
import android.os.Build
import android.os.Looper
import android.view.HapticFeedbackConstants
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.slideInVertically
import androidx.compose.animation.slideOutVertically
import androidx.compose.animation.togetherWith
import androidx.compose.animation.core.Animatable
import androidx.compose.runtime.key
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.RowScope
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.systemBarsPadding
import androidx.compose.ui.draw.clipToBounds
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableLongStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalView
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.core.content.ContextCompat
import com.nkssi.splits8.Ask
import com.nkssi.splits8.PhoneRunEngine
import com.nkssi.splits8.PhoneRunRequest
import com.nkssi.splits8.R
import com.nkssi.splits8.Router
import com.nkssi.splits8.Scr
import com.nkssi.splits8.Store
import com.nkssi.splits8.shared.Cheer
import com.nkssi.splits8.shared.Fm
import com.nkssi.splits8.shared.L10n
import com.nkssi.splits8.shared.LivePace
import com.nkssi.splits8.shared.Mode
import com.nkssi.splits8.shared.Record
import com.nkssi.splits8.shared.SegKind
import com.nkssi.splits8.shared.l10n
import com.nkssi.splits8.shared.mainSegs
import com.nkssi.splits8.ui.C
import com.nkssi.splits8.ui.F
import com.nkssi.splits8.ui.Icon8
import com.nkssi.splits8.ui.Label8
import com.nkssi.splits8.ui.Sym
import com.nkssi.splits8.ui.T
import com.nkssi.splits8.ui.W600
import com.nkssi.splits8.ui.W700
import com.nkssi.splits8.ui.card8
import com.nkssi.splits8.ui.hex
import com.nkssi.splits8.ui.press
import com.nkssi.splits8.ui.tap
import com.nkssi.splits8.ui.yellowFill
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.util.Locale
import kotlin.math.max
import kotlin.math.min

// 워치 없이 폰으로 기록 (아이폰 PhoneLiveView.swift). 큰 Next 버튼으로 구간을 넘김. 화면은 꺼지지 않음. 심박 없음.
// 끝나면 기록 상세 위로 "수고했어요" 카드 (아이폰 FinishSheet.swift)

/** 화면 높이별 크기 (760 기준 1.0, 작은 폰은 줄이고 큰 폰은 키움) */
internal class LiveMetrics(h: Float) {
    val k = max(0.8f, min(1.14f, h / 760f))
    private val kk = min(k, 1.08f)
    val totalFont = 76 * k
    val segFont = 64 * k
    val icon = 52 * k
    val nameFont = 28 * kk
    val detailFont = 16 * kk
    val nextFont = 27 * kk
    val nextIcon = 34 * kk
    val nextLabel = 16.5f * kk
    val top = 24 * k
    val segTop = 36 * k
    val nameTop = 10 * k
    val dividerTop = 26 * k
    val buttonH = max(58f, min(74f, 66 * k))
    val buttonFont = 22 * kk
    val pillH = max(46f, min(58f, 53 * k))
    val pillGap = 27 * k
    val bottom = 90 * k
}

@Composable
fun PhoneLiveView() {
    val req = Router.phoneRun ?: PhoneRunRequest(Mode.Sim)
    val eng = Router.phoneEngine
    val ctx = LocalContext.current
    val view = LocalView.current
    val scope = rememberCoroutineScope()
    var count by remember { mutableStateOf<Int?>(if (eng.active || Router.phoneNoCount) null else 3) }
    var now by remember { mutableLongStateOf(Router.phoneClock()) }
    val flash = remember { Animatable(0f) }

    fun buzz(strong: Boolean = false) {
        view.performHapticFeedback(if (strong) HapticFeedbackConstants.LONG_PRESS else HapticFeedbackConstants.VIRTUAL_KEY)
    }
    fun success() {
        view.performHapticFeedback(if (Build.VERSION.SDK_INT >= 30) HapticFeedbackConstants.CONFIRM else HapticFeedbackConstants.LONG_PRESS)
    }
    fun flashNow() = scope.launch {
        flash.animateTo(1f, tween(60))
        delay(30)
        flash.animateTo(0f, tween(260))
    }
    fun done(rec: Record) {
        Store.addPhoneRecord(rec)
        // 기록 상세 위로 "수고했어요" 카드
        // 1.1.2: 트레이닝 편집 화면 등 탭이 아닌 곳에서 시작했으면, 기록 화면의 뒤로 가기는 그 모드의 탭으로
        // (예전엔 편집 화면에서 시작하면 "‹ Race" 라고 나오고 누르면 편집 화면으로 감)
        val back = when (req.from) {
            Scr.Home, Scr.Training, Scr.Sim, Scr.Race -> req.from
            else -> when (rec.mode) {
                Mode.Training -> Scr.Training
                Mode.Race -> Scr.Race
                else -> { Router.testTab = if (rec.mode == Mode.Pft) "pft" else "sim"; Scr.Sim }
            }
        }
        Router.showFinish(Store.records.firstOrNull { it.id == rec.id } ?: rec.copy(source = "phone"), back)
    }
    fun askEnd() {
        Router.ask = Ask("End workout?", "Save the segments you've done so far?", ok = "Save", cancel = "Cancel",
            alt = "Discard", onAlt = { eng.discard(); Router.go(req.from) }, onOk = { eng.endNow()?.let { done(it) } })
    }

    // 화면 켜 두기
    DisposableEffect(Unit) {
        view.keepScreenOn = true
        onDispose { view.keepScreenOn = false }
    }
    // 뒤로 가기 = End 확인 (실수로 나가지 않게). 세는 중이면 취소
    val back: () -> Unit = remember(count == null) {
        if (count != null) ({ Router.go(req.from) }) else ({ askEnd() })
    }
    BackAction(back)

    // 3 · 2 · 1 을 센 뒤 시작
    LaunchedEffect(Unit) {
        if (eng.active) return@LaunchedEffect
        if (count == null) { eng.start(req); return@LaunchedEffect }
        buzz()
        while ((count ?: 0) > 1) { delay(1000); count = count?.minus(1); buzz() }
        delay(1000)
        count = null
        if (!eng.active) eng.start(req)
        success(); flashNow()
    }
    // 0.25초마다 시간 다시 그림
    LaunchedEffect(Unit) {
        var n = 0
        while (true) {
            now = Router.phoneClock(); delay(250)
            // 5초마다 진행 상태 저장 (GPS 거리 · 경로 · 걸음까지 — 앱이 꺼져도 이어서)
            if (++n % 20 == 0 && eng.active && !eng.finished) Store.savePhoneRun(eng.snapshot())
        }
    }
    // GPS 러닝이 총거리를 다 뛰어서 저절로 끝남
    LaunchedEffect(eng.autoDone) { eng.autoDone?.let { success(); done(it) } }
    LaunchedEffect(eng.autoSplits) { if (eng.autoSplits > 0) { buzz(true); flashNow() } }

    Sensors(eng, ctx)

    Box(Modifier.fillMaxSize()) {
    // 1.1.2: 아이폰처럼 상태 줄 · 아래 내비게이션 줄을 뺀 안전 영역 안에만 그림 (크기 계산도 안전 영역 높이로)
    BoxWithConstraints(Modifier.fillMaxSize().systemBarsPadding()) {
        val m = LiveMetrics(maxHeight.value)
        Column(Modifier.fillMaxSize().padding(horizontal = 20.dp)) {
            // 빌드 24: 제목 / ● Phone · No HR / n / 16 / 막대 (워치 같이 보기 화면과 같은 머리)
            val frame = phoneFrame(eng, now)
            LiveHeader(frame, "Phone · No HR", live = false, tagPrefix = "phone")
            // 1.1.2: 가운데는 남는 자리만 씀 → 글자가 커도 아래 버튼(Next/완료 · End · Undo · Pause)은 항상 보임 (아이폰 Spacer(minLength: 16) 와 같음)
            Column(Modifier.weight(1f).clipToBounds()) {
                LiveBody(frame, m.totalFont, m.segFont, m.icon, m.nameFont, m.detailFont, m.segTop, m.nameTop, "phone", Modifier.padding(top = (m.top * 0.6f).dp))
                LiveNextRow(eng.nextSeg, m.nextLabel, m.nextFont, m.nextIcon, m.dividerTop, m.k, "phone")
            }
            Spacer(Modifier.height(16.dp))
            // Next 버튼 (GPS 러닝은 1 km 마다 저절로)
            val gpsRun = eng.isRunKind && eng.useGPS
            val enabled = eng.running && !gpsRun
            Row(
                Modifier.fillMaxWidth().height(m.buttonH.dp).yellowFill(RoundedCornerShape(50), on = enabled)
                    .press(enabled = enabled, tag = "phone.next") {
                        buzz(true); flashNow()
                        eng.advance()?.let { success(); done(it) }
                    },
                verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.Center,
            ) {
                val label = if (gpsRun) "Auto split every 1 km" else if (eng.hasNext || eng.growsOpen) "Next" else "Finish"
                T(label.l10n + "  ›", F.t(m.buttonFont, W600, if (enabled) Color.Black else C.text3), maxLines = 1, translate = false)
            }
            Row(Modifier.padding(top = m.pillGap.dp, bottom = m.bottom.dp), horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                Pill(R.drawable.sym_stop, "End", C.bad, hex(0xFF453A, 0.22f), m.pillH, "phone.end") { askEnd() }
                Pill(R.drawable.sym_undo, "Undo", if (eng.canUndo) Color.White else C.text3,
                    Color.White.copy(alpha = if (eng.canUndo) 0.12f else 0.05f), m.pillH, "phone.undo", eng.canUndo) { buzz(); eng.undo() }
                Pill(if (eng.running) R.drawable.sym_pause else R.drawable.sym_play, if (eng.running) "Pause" else "Resume",
                    if (eng.running) Color.White else C.accent, Color.White.copy(alpha = 0.12f), m.pillH, "phone.pause") { eng.togglePause() }
            }
        }
    }
        // 넘길 때 노랗게 반짝
        if (flash.value > 0f) Box(Modifier.fillMaxSize().background(C.accent.copy(alpha = flash.value * 0.22f)))
        // 시작 전 3 · 2 · 1 (누르면 취소하고 돌아감)
        count?.let { n ->
            Box(Modifier.fillMaxSize().background(Color.Black).tap { count = null; Router.go(req.from) }.testTag("phone.countdown"),
                contentAlignment = Alignment.Center) {
                Column(horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(14.dp)) {
                    // 1.1.2: 숫자가 바뀔 때마다 새 글자로 그림 (아이폰 .numericText 처럼 위로 밀려 바뀜).
                    // 예전엔 같은 글자 칸의 내용만 바꿔서 에뮬레이터 등에서 "3" 다음 "2 · 1" 이 안 그려지고 빈 화면이었음
                    AnimatedContent(n, transitionSpec = {
                        (slideInVertically(tween(250)) { it / 3 } + fadeIn(tween(250))) togetherWith
                            (slideOutVertically(tween(250)) { -it / 3 } + fadeOut(tween(200)))
                    }, label = "count") { k ->
                        key(k) { T("$k", F.num(160, W700, C.accent), Modifier.testTag("phone.count"), maxLines = 1, translate = false) }
                    }
                    T("Tap to cancel", F.t(15, color = C.text2), maxLines = 1)
                }
            }
        }
    }
}

/** 엔진 → 화면 한 장면 */
private fun phoneFrame(eng: PhoneRunEngine, now: Long) = LiveFrame(
    mode = eng.mode, title = eng.title, seq = eng.seq, idx = eng.idx, segEl = eng.segEl(now), total = eng.total(now),
    running = eng.running, open = eng.growsOpen,
    segDist = if (eng.useGPS) eng.segDist else null, totalDist = if (eng.useGPS) eng.totalDist else null,
    runKind = eng.isRunKind, next = eng.nextSeg,
    speed = if (eng.useGPS) eng.speedNow(now) else null,
    imperial = com.nkssi.splits8.Store.settings.imperial,
)

/** ■ End · ↩ Undo · ❚❚ Pause (둥근 알약) */
@Composable
internal fun RowScope.Pill(icon: Int, label: String, fg: Color, bg: Color, h: Float, tag: String, enabled: Boolean = true, onClick: () -> Unit) {
    Row(
        Modifier.weight(1f).height(h.dp).clip(RoundedCornerShape(50)).background(bg).press(0.97f, enabled = enabled, tag = tag, onClick = onClick),
        verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.Center,
    ) {
        Sym(icon, 15.dp, fg)
        Spacer(Modifier.width(7.dp))
        T(label, F.t(15, W600, fg), maxLines = 1)
    }
}

// MARK: 센서 (위치 · 걸음 · 동네 이름)

@SuppressLint("MissingPermission")
@Composable
private fun Sensors(eng: PhoneRunEngine, ctx: Context) {
    fun granted(p: String) = ContextCompat.checkSelfPermission(ctx, p) == PackageManager.PERMISSION_GRANTED
    var locOk by remember { mutableStateOf(granted(Manifest.permission.ACCESS_FINE_LOCATION) || granted(Manifest.permission.ACCESS_COARSE_LOCATION)) }
    var stepOk by remember { mutableStateOf(granted(Manifest.permission.ACTIVITY_RECOGNITION)) }
    val ask = rememberLauncherForActivityResult(ActivityResultContracts.RequestMultiplePermissions()) { res ->
        locOk = locOk || res[Manifest.permission.ACCESS_FINE_LOCATION] == true || res[Manifest.permission.ACCESS_COARSE_LOCATION] == true
        stepOk = stepOk || res[Manifest.permission.ACTIVITY_RECOGNITION] == true
    }
    val scope = rememberCoroutineScope()
    // 시작하면 필요한 권한만 물어봄 (GPS 러닝 = 위치, 러닝 카드 = 걸음)
    LaunchedEffect(eng.active) {
        if (!eng.active) return@LaunchedEffect
        val want = buildList {
            if (eng.useGPS && !locOk) { add(Manifest.permission.ACCESS_FINE_LOCATION); add(Manifest.permission.ACCESS_COARSE_LOCATION) }
            if (eng.isRunKind && !stepOk) add(Manifest.permission.ACTIVITY_RECOGNITION)
        }
        if (want.isNotEmpty()) runCatching { ask.launch(want.toTypedArray()) }
    }
    fun lookupPlace(loc: Location) {
        if (eng.place != null) return
        scope.launch {
            val name = withContext(Dispatchers.IO) { placeName(ctx, loc) }
            if (name != null && eng.place == null) eng.place = name
        }
    }
    // GPS (야외)
    DisposableEffect(eng.active, eng.useGPS, locOk) {
        val lm = ctx.getSystemService(Context.LOCATION_SERVICE) as? LocationManager
        var listener: LocationListener? = null
        if (eng.active && lm != null && locOk) {
            if (eng.useGPS) {
                val l = LocationListener { loc ->
                    lookupPlace(loc)
                    eng.gotLocation(loc.latitude, loc.longitude, if (loc.hasAccuracy()) loc.accuracy else 0f,
                        if (loc.hasAltitude()) loc.altitude else null,
                        if (Build.VERSION.SDK_INT >= 26 && loc.hasVerticalAccuracy()) loc.verticalAccuracyMeters else null,
                        speed = if (loc.hasSpeed()) loc.speed else null)
                }
                listener = l
                runCatching { lm.requestLocationUpdates(LocationManager.GPS_PROVIDER, 1000L, 5f, l, Looper.getMainLooper()) }
            } else {
                // 실내: 마지막으로 알던 위치로 동네 이름만
                val last = listOf(LocationManager.GPS_PROVIDER, LocationManager.NETWORK_PROVIDER, LocationManager.PASSIVE_PROVIDER)
                    .mapNotNull { runCatching { lm.getLastKnownLocation(it) }.getOrNull() }.maxByOrNull { it.time }
                last?.let { lookupPlace(it) }
            }
        }
        onDispose { listener?.let { runCatching { lm?.removeUpdates(it) } } }
    }
    // 야외 GPS 기록: 화면을 끄거나 다른 앱으로 가도 위치를 계속 받게 (알림 줄 "운동 기록 중")
    val gpsOn = eng.active && !eng.finished && eng.useGPS && locOk
    DisposableEffect(gpsOn) {
        if (gpsOn) com.nkssi.splits8.RunService.start(ctx, if (eng.mode == Mode.Training) eng.title else eng.mode.title)
        onDispose { if (gpsOn) com.nkssi.splits8.RunService.stop(ctx) }
    }
        // 걸음 수 (러닝 카드 · 케이던스)
    DisposableEffect(eng.active, eng.isRunKind, stepOk) {
        val sm = ctx.getSystemService(Context.SENSOR_SERVICE) as? SensorManager
        val sensor = sm?.getDefaultSensor(Sensor.TYPE_STEP_COUNTER)
        var base: Float? = null
        val l = object : SensorEventListener {
            override fun onSensorChanged(e: SensorEvent) {
                val v = e.values.firstOrNull() ?: return
                val b = base ?: v.also { base = it }
                eng.gotSteps((v - b).toDouble())
            }
            override fun onAccuracyChanged(s: Sensor?, a: Int) {}
        }
        if (eng.active && eng.isRunKind && stepOk && sensor != null) sm.registerListener(l, sensor, SensorManager.SENSOR_DELAY_NORMAL)
        onDispose { sm?.unregisterListener(l) }
    }
}

/** 동(subLocality) + 시(locality, 없으면 도). "서울특별시" → "서울" (아이폰 PlaceLookup.label) */
@Suppress("DEPRECATION")
private fun placeName(ctx: Context, loc: Location): String? = runCatching {
    if (!Geocoder.isPresent()) return null
    val a = Geocoder(ctx, Locale.getDefault()).getFromLocation(loc.latitude, loc.longitude, 1)?.firstOrNull() ?: return null
    placeLabel(a.subLocality, a.locality ?: a.adminArea)
}.getOrNull()

fun placeLabel(sub: String?, city: String?): String? {
    var c = city
    if (c != null) for (suf in listOf("특별자치시", "특별자치도", "특별시", "광역시")) if (c!!.endsWith(suf)) { c = c.dropLast(suf.length); break }
    val parts = listOfNotNull(sub, c).filter { it.isNotEmpty() }.distinct()
    return if (parts.isEmpty()) null else parts.joinToString(", ")
}

// MARK: 운동이 끝났을 때 카드 (기록 상세 위로 올라옴)

private val gold = Color(0xFFFFD54A)

@Composable
fun FinishSheet(rec: Record) {
    val c = remember(rec.id, Store.book) { Store.book.cheer(rec) }
    val isGold = c.tone == Cheer.Tone.Celebrate
    val view = LocalView.current
    LaunchedEffect(rec.id) {
        view.performHapticFeedback(if (c.tone == Cheer.Tone.Check) HapticFeedbackConstants.LONG_PRESS
            else if (Build.VERSION.SDK_INT >= 30) HapticFeedbackConstants.CONFIRM else HapticFeedbackConstants.LONG_PRESS)
    }
    // 빌드 24: 이 기록으로 새로 받은 배지 (있으면 카드가 그만큼 길어짐)
    val nb = remember(rec.id, Store.records) { com.nkssi.splits8.shared.Badges.new(rec, Store.records) }
    // 1.1.2: 높이를 고정하지 않음 (예전 400/470 고정 → 멘트가 두 줄 · 배지 · 큰 글자면 아래 Share/완료 버튼이 밀려 안 보였음).
    // 아이폰처럼 최소 400, 내용이 길면 그만큼 늘어나고 버튼은 항상 맨 아래
    Box(Modifier.fillMaxWidth().heightIn(min = 400.dp)) {
        if (isGold) {
            // 카드 위쪽 금색 빛 (축하)
            androidx.compose.foundation.Canvas(Modifier.fillMaxWidth().height(300.dp)) {
                drawRect(Brush.radialGradient(listOf(gold.copy(alpha = 0.38f), gold.copy(alpha = 0f)),
                    center = androidx.compose.ui.geometry.Offset(size.width / 2, 0f), radius = 320.dp.toPx()))
            }
        }
        Column(Modifier.fillMaxWidth().padding(start = 22.dp, end = 22.dp, top = 12.dp, bottom = 12.dp + 52.dp + 16.dp)) {
            c.tag?.let { FinishTag(it, c.tone, rec) }
            T(c.line, F.t(F.title2, W600), Modifier.testTag("finish.line"), translate = false)
            val name = if (rec.mode == Mode.Training) rec.title else rec.mode.title.l10n
            T(name + " · " + Fm.wdm(rec.date), F.t(F.foot, color = C.text2), Modifier.padding(top = 4.dp), maxLines = 1, translate = false)
            FitText(Fm.t(rec.total), F.num(46, color = if (isGold) gold else Color.White, tracking = -0.92f), Modifier.padding(top = 14.dp), minScale = 0.6f)
            Row(Modifier.padding(top = 14.dp), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                for ((l, v, u) in finishTiles(rec)) FinishTile(l, v, u)
            }
            if (nb.isNotEmpty()) NewBadgesRow(nb, Modifier.padding(top = 12.dp))
        }
        Row(Modifier.align(Alignment.BottomCenter).padding(start = 22.dp, end = 22.dp, bottom = 12.dp), horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                Box(
                    Modifier.weight(1f).height(52.dp).clip(RoundedCornerShape(14.dp)).background(C.accent).press(tag = "finish.primary") {
                        Router.finish = null
                        if (c.tone != Cheer.Tone.Check) Router.go(Scr.Share)
                    },
                    contentAlignment = Alignment.Center,
                ) { T(if (c.tone == Cheer.Tone.Check) "Check splits" else "Share", F.t(17, W600, Color.Black), maxLines = 1) }
                Box(
                    Modifier.weight(1f).height(52.dp).clip(RoundedCornerShape(14.dp)).background(Color.White.copy(alpha = 0.12f))
                        .press(tag = "finish.done") { Router.finish = null },
                    contentAlignment = Alignment.Center,
                ) { T("Done", F.t(17, W600), maxLines = 1) }
        }
    }
}

/** 타일 3개: 칼로리 · 평균 심박 · 러닝 페이스(없으면 최대 심박). 심박이 없으면(폰 기록) 구간 수 */
private fun finishTiles(rec: Record): List<Triple<String, String, String>> {
    val o = ArrayList<Triple<String, String, String>>()
    if (rec.kcal > 0) o.add(Triple("CALORIES", grouped(rec.kcal), "KCAL"))
    if (rec.avgHR > 0) o.add(Triple("AVG HR", "${rec.avgHR}", "BPM"))
    val p = rec.runPace
    val imp = com.nkssi.splits8.Store.settings.imperial
    if (p != null && rec.mode != Mode.Pft) o.add(Triple("RUN PACE", Fm.t(com.nkssi.splits8.shared.Units.pace(p, imp)), com.nkssi.splits8.shared.Units.paceUnit(imp)))
    else if (rec.maxHR > 0) o.add(Triple("MAX HR", "${rec.maxHR}", "BPM"))
    if (o.size < 3) o.add(Triple("SPLITS", "${rec.mainSegs.size}", ""))
    return o.take(3)
}

@Composable
private fun RowScope.FinishTile(label: String, value: String, unit: String) {
    Column(Modifier.weight(1f).card8(14.dp).padding(12.dp), verticalArrangement = Arrangement.spacedBy(4.dp)) {
        Label8(label, size = F.cap2)
        Row(verticalAlignment = Alignment.Bottom, horizontalArrangement = Arrangement.spacedBy(2.dp)) {
            FitText(value, F.num(20), Modifier.weight(1f, fill = false), minScale = 0.7f)
            if (unit.isNotEmpty()) T(unit, F.t(F.cap2, W600, C.text2), Modifier.padding(bottom = 2.dp), maxLines = 1, translate = false)
        }
    }
}

@Composable
private fun FinishTag(tag: String, tone: Cheer.Tone, rec: Record? = null) {
    val fill = when (tone) { Cheer.Tone.Check -> C.bad.copy(alpha = 0.18f); Cheer.Tone.Celebrate -> gold; else -> Color.White.copy(alpha = 0.12f) }
    val ink = when (tone) { Cheer.Tone.Check -> C.bad; Cheer.Tone.Celebrate -> Color.Black; else -> Color.White }
    var text = if (tag == "CHECK") "Check".l10n else tag.l10n
    // 빌드 27: 러닝 기록의 PB 는 거리까지 ("★ 5K PB")
    if (tag == "★ PB" && rec != null && rec.isRunKind) com.nkssi.splits8.Store.book.runPBLabel(rec)?.let { text = "★ $it" }
    Box(Modifier.padding(bottom = 12.dp).height(24.dp).clip(RoundedCornerShape(50)).background(fill).padding(horizontal = 10.dp),
        contentAlignment = Alignment.Center) {
        T(text, F.t(F.cap1, W700, ink, tracking = 0.72f), maxLines = 1, translate = false)
    }
}
