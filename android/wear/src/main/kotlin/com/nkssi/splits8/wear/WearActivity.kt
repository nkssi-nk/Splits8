package com.nkssi.splits8.wear

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.BackHandler
import androidx.activity.compose.setContent
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.core.content.ContextCompat
import androidx.wear.ambient.AmbientLifecycleObserver
import androidx.wear.compose.foundation.BasicSwipeToDismissBox
import androidx.wear.compose.foundation.rememberSwipeToDismissBoxState
import androidx.wear.compose.material3.AppScaffold
import com.nkssi.splits8.shared.Mode
import com.nkssi.splits8.shared.PFT
import com.nkssi.splits8.shared.Program
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch

class WearActivity : ComponentActivity() {
    private var ambient by mutableStateOf(false)

    private val ambientCallback = object : AmbientLifecycleObserver.AmbientLifecycleCallback {
        override fun onEnterAmbient(ambientDetails: AmbientLifecycleObserver.AmbientDetails) { ambient = true }
        override fun onExitAmbient() { ambient = false }
        override fun onUpdateAmbient() {}
    }

    private val askPerms = registerForActivityResult(ActivityResultContracts.RequestMultiplePermissions()) {}

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        WatchStore.init(applicationContext)
        WearDevice.attach(applicationContext)
        lifecycle.addObserver(AmbientLifecycleObserver(this, ambientCallback))
        WatchStore.start()
        handle(intent)
        askPermissionsOnce()
        setContent {
            CompositionLocalProvider(LocalAod provides ambient) {
                WearApp(buzz = { Buzz.play(this, it) }, exit = { finish() })
            }
        }
    }

    /** 98번: 폰이 splits8://calib?icon=… 로 워치 앱을 켜면 보정 화면 */
    override fun onNewIntent(intent: android.content.Intent) {
        super.onNewIntent(intent)
        handle(intent)
    }

    private fun handle(i: android.content.Intent?) {
        Calib.iconFrom(i?.data)?.let { Calib.request(it) }
    }

    /** 처음 켤 때 한 번: 심박 · 활동 · 위치 · 알림 (아이폰은 앱을 켤 때 건강 권한을 물어봄) */
    private fun askPermissionsOnce() {
        val want = WearDevice.permissions().filter { ContextCompat.checkSelfPermission(this, it) != PackageManager.PERMISSION_GRANTED }
        val prefs = getSharedPreferences("w", Context.MODE_PRIVATE)
        if (want.isEmpty() || prefs.getBoolean("asked", false)) return
        prefs.edit().putBoolean("asked", true).apply()
        askPerms.launch(want.toTypedArray())
    }
}

/** 실제 워치에 이어 줌 (측정 · 진동 · 횟수 세기 · 운동 서비스) — 시험 · 화면 사진에서는 안 부름 */
object WearDevice {
    fun attach(c: Context) {
        val e = WatchStore.engine
        if (e.sensors !is NoSensors) return
        e.sensors = HealthSensors(c)
        e.reps = RepCounter(c)
        e.buzz = { Buzz.play(c, it) }
        e.onActive = { on -> if (on) WorkoutService.start(c) else WorkoutService.stop(c) }
        Calib.sensor = AccelCalibSensor(c)
        Calib.buzz = { Buzz.play(c, it) }
    }

    fun permissions(): List<String> = buildList {
        // Wear OS 6(API 36)부터 심박은 건강 권한, 그 전은 몸 센서 권한
        if (Build.VERSION.SDK_INT >= 36) add("android.permission.health.READ_HEART_RATE") else add(Manifest.permission.BODY_SENSORS)
        add(Manifest.permission.ACTIVITY_RECOGNITION)
        add(Manifest.permission.ACCESS_FINE_LOCATION)
        add(Manifest.permission.POST_NOTIFICATIONS)
    }
}

/** 워치 앱 전체 (아이폰 WRoot) */
@Composable
fun WearApp(buzz: (BuzzKind) -> Unit, exit: () -> Unit) {
    val e = WatchStore.engine
    Box(Modifier.fillMaxSize().background(Color.Black)) {
        when {
            // 98번: 보정 화면 (운동 중 · 3 · 2 · 1 중이 아닐 때만)
            Calib.icon != null && !e.active && e.countdown == null -> {
                BackHandler { Calib.close() }
                // 세는 동안 화면이 꺼지지 않게
                KeepScreenOn(Calib.phase == Calib.Phase.Counting)
                WCalibView()
            }
            e.active && e.finished -> WSummary()
            e.active -> {
                // 운동 중 뒤로 단추 = 아무것도 안 함 (실수로 나가지 않게 — 끝내기는 조작 화면에서)
                BackHandler { }
                WWorkoutPager(buzz)
            }
            e.countdown != null -> {
                LaunchedEffect(e.countdown) { delay(1000); e.countTick() }
                BackHandler { e.cancelCountdown() }
                WCountdown(e.countdown ?: 0) { e.cancelCountdown() }
            }
            else -> AppScaffold { NavStack(buzz, exit) }
        }
    }
}

/** 쌓인 화면 + 왼쪽 끝에서 오른쪽으로 밀면 뒤로 (첫 화면에서 밀면 앱 닫기) */
@Composable
private fun NavStack(buzz: (BuzzKind) -> Unit, exit: () -> Unit) {
    val path = WNav.path
    val top: WScreen? = path.lastOrNull()
    val below: WScreen? = path.getOrNull(path.size - 2)
    val state = rememberSwipeToDismissBoxState()
    val ctx = androidx.compose.ui.platform.LocalContext.current
    val scope = rememberCoroutineScope()
    BackHandler(enabled = top != null) { WNav.pop() }

    fun start(indoor: Boolean?) {
        val run = { startWorkout(indoor) }
        if (WatchStore.demo) { run(); return }
        scope.launch {
            // 삼성 헬스 등 다른 앱이 운동을 기록 중이면 먼저 알림 (시작하면 그쪽이 끝남)
            if (HealthSensors.otherAppRecording(ctx)) askOther = run else run()
        }
    }

    BasicSwipeToDismissBox(
        onDismissed = { if (top == null) exit() else WNav.pop() },
        state = state,
        backgroundKey = below ?: (if (top != null) "home" else "none"),
        contentKey = top ?: "home",
    ) { isBackground ->
        val s = if (isBackground) below else top
        if (isBackground && top == null) Box(Modifier.fillMaxSize().background(Color.Black))
        else Screen(s, buzz) { start(it) }
    }
    askOther?.let { go ->
        OtherAppAsk(onStart = { askOther = null; go() }, onCancel = { askOther = null })
    }
}

/** "다른 앱이 운동을 기록 중" 묻기 (시작 전) */
private var askOther by mutableStateOf<(() -> Unit)?>(null)

@Composable
private fun Screen(s: WScreen?, buzz: (BuzzKind) -> Unit, start: (Boolean?) -> Unit) {
    Box(Modifier.fillMaxSize().background(Color.Black)) {
        when (s) {
            null -> WHome()
            WScreen.Programs -> WPrograms()
            WScreen.Quick -> WQuick(buzz)
            WScreen.Confirm -> WConfirm(onStart = start)
            WScreen.Goal -> WGoalPicker()
        }
    }
}

/** 확인 화면의 Start: 3 · 2 · 1 을 센 뒤 시작. 83번: 러닝은 고른 실내/실외로 이번 운동만 바꿔서 (카드 자체는 그대로) */
fun startWorkout(indoor: Boolean? = null) {
    val mode = WNav.mode
    var program = WNav.program ?: Program.presets()[0]
    if (indoor != null) program = program.copy(indoor = indoor)
    val e = WatchStore.engine
    val title = when (mode) {
        Mode.Training -> program.name
        Mode.Pft -> PFT.title
        Mode.Sim -> "Full Simulation"
        Mode.Race -> WatchStore.settings.event.name
    }
    e.settings = WatchStore.settings
    e.pftBestCount = WatchStore.ctx.pftBest?.size ?: 0
    e.startAfterCountdown(mode, title, if (mode == Mode.Training) program.sets else 1,
        WatchStore.seq(mode, if (mode == Mode.Training) program else null),
        if (mode == Mode.Training) program else null, WatchStore.simPick.second)
}

/** 켜져 있는 동안 화면 꺼짐 막기 */
@Composable
fun KeepScreenOn(on: Boolean) {
    val view = androidx.compose.ui.platform.LocalView.current
    androidx.compose.runtime.DisposableEffect(on) {
        view.keepScreenOn = on
        onDispose { view.keepScreenOn = false }
    }
}

@Composable
private fun OtherAppAsk(onStart: () -> Unit, onCancel: () -> Unit) {
    val k = wk()
    Column(Modifier.fillMaxSize().background(Color.Black).padding(horizontal = (24 * k).dp, vertical = (30 * k).dp).testTag("w.otherApp"),
        horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(6.dp, Alignment.CenterVertically)) {
        T("Another app is recording a workout. Starting here will end it.", F.t(13, color = C.text2), Modifier.fillMaxWidth(), maxLines = 4, align = TextAlign.Center)
        Box(Modifier.width(screenFrac(0.7f)).height(34.dp).clip(Pill).background(C.accent).press(onClick = onStart), contentAlignment = Alignment.Center) {
            T("Start anyway", F.t(14, W600, Color.Black))
        }
        Box(Modifier.width(screenFrac(0.62f)).height(34.dp).clip(Pill).background(hex(0x1F1F1F)).press(onClick = onCancel), contentAlignment = Alignment.Center) {
            T("Cancel", F.t(14, W600))
        }
    }
}
