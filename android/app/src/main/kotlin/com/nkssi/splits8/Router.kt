package com.nkssi.splits8

import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import com.nkssi.splits8.shared.GlowTheme
import com.nkssi.splits8.shared.Mode
import com.nkssi.splits8.shared.Record
import com.nkssi.splits8.ui.Ambient
import com.nkssi.splits8.ui.GlowDrift

/** 화면 목록 (아이폰 Scr 과 같음) */
enum class Scr {
    Splash, Ob1, Ob2, Ob3,
    Home, Training, Builder, Sim, Race, Settings,
    SetHr, SetDiv, SetRun, SetGoals, SetEvent, Friends,
    Auth, Code, Nick, FindEvent, Account,
    ProfileSetup,
    Detail, Share,
    PhoneLive, WatchLive;

    /** 아래 탭 바를 보여 주는 화면 */
    val showsTabs: Boolean
        get() = this in setOf(Home, Training, Sim, Race, Settings, FindEvent, Account, SetHr, SetGoals, SetDiv, SetRun, SetEvent, Friends)

    /** 위 고정 바 (44, 반투명 검정) */
    val showsBar: Boolean
        get() = this in setOf(Home, Training, Sim, Race, Settings, FindEvent, Account, SetHr, SetGoals, SetDiv, SetRun, Friends)

    /** 화면 자체 머리줄(Cancel · 제목 · Save)을 맨 위에 고정하는 화면 */
    val pinsNav: Boolean get() = this == Builder

    /** 어느 탭이 켜져 보이는지 */
    fun tab(friendsFrom: Scr): Scr? = when (this) {
        Home -> Home
        Training, Builder -> Training
        Sim -> Sim
        Race, SetEvent, FindEvent, SetGoals -> Race
        Friends -> if (friendsFrom == Home) Home else Settings
        Settings, SetHr, SetDiv, SetRun, Account -> Settings
        else -> null
    }

    /** 화면 배경 빛 (아이폰 Scr.baseAmbient 와 같은 값) */
    fun baseAmbient(t: GlowTheme): Ambient = when (this) {
        Training -> Ambient.y(0.26f, 1.2f, 0.5f, 0.5f, 0f, t)
        Home -> Ambient.y(0.24f, 1.3f, 0.55f, 0.5f, 0f, t)
        Ob1 -> Ambient.y(0.24f, 1.2f, 0.55f, 0.5f, 0f, t)
        Ob2 -> Ambient(0xFF453A, 0.18f, 1.2f, 0.55f, 0.5f, 0.3f)
        Ob3 -> Ambient(0x30D158, 0.16f, 1.2f, 0.55f, 0.5f, 0.3f)
        Builder -> Ambient.y(0.20f, 1.1f, 0.55f, 0.5f, 0.08f, t)
        Sim -> Ambient.y(0.20f, 1.3f, 0.55f, 0.5f, 0.3f, t)
        Race -> Ambient.y(0.28f, 1.3f, 0.55f, 0.5f, 1.0f, t)
        Settings -> Ambient(0xFFFFFF, 0.10f, 1.2f, 0.5f, 0.5f, 0f)
        SetHr -> Ambient(0xFF453A, 0.20f, 1.2f, 0.55f, 0.5f, 0.2f)
        SetGoals -> Ambient.y(0.18f, 1.2f, 0.55f, 0.5f, 0.4f, t)
        SetDiv -> Ambient.y(0.18f, 1.2f, 0.55f, 0.5f, 0.2f, t)
        SetRun -> Ambient(0x0A84FF, 0.20f, 1.2f, 0.55f, 0.5f, 0.2f)
        SetEvent -> Ambient.y(0.22f, 1.2f, 0.55f, 0.5f, 0.2f, t)
        Friends -> Ambient(0x30D158, 0.16f, 1.2f, 0.55f, 0.5f, 0.2f)
        Detail -> Ambient.y(0.24f, 1.3f, 0.5f, 0.5f, 0.1f, t)
        Share -> Ambient.y(0.14f, 1.2f, 0.55f, 0.5f, 0.5f, t)
        Auth -> Ambient.y(0.22f, 1.2f, 0.55f, 0.5f, 0f, t)
        Code -> Ambient.y(0.18f, 1.2f, 0.55f, 0.5f, 0.2f, t)
        Nick -> Ambient(0x30D158, 0.14f, 1.2f, 0.55f, 0.5f, 0.2f)
        ProfileSetup -> Ambient.y(0.20f, 1.2f, 0.55f, 0.5f, 0.2f, t)
        FindEvent -> Ambient.y(0.22f, 1.3f, 0.5f, 0.5f, 0f, t)
        Account -> Ambient.y(0.18f, 1.2f, 0.5f, 0.5f, 0f, t)
        PhoneLive -> Ambient.y(0.18f, 1.3f, 0.5f, 0.5f, 0f, t)
        Splash, WatchLive -> Ambient.none
    }

    /** 빛 자리를 켤 때마다 조금 다르게 */
    fun ambient(t: GlowTheme): Ambient {
        val a = baseAmbient(t)
        if (a == Ambient.none || a.linear) return a
        return a.copy(cx = a.cx + GlowDrift.dx, cy = a.cy + GlowDrift.dy, rx = a.rx * GlowDrift.scale)
    }
}

/** 화면 이동 (아이폰 Router) */
object Router {
    var scr by mutableStateOf(Scr.Splash)
    var detail by mutableStateOf<Record?>(null)
    var detailFrom by mutableStateOf(Scr.Race)
    /** Division · 심박 화면을 어디서 열었는지 */
    var subFrom by mutableStateOf(Scr.Account)
    /** Friends 화면을 어디서 열었는지 */
    var friendsFrom by mutableStateOf(Scr.Settings)
    /** Test 탭에서 고른 쪽: "pft" / "sim" */
    var testTab by mutableStateOf("pft")
    /** 지금 화면 안 ‹ 버튼이 등록한 뒤로 동작 (시스템 뒤로 가기에 씀) */
    var backAction: (() -> Unit)? = null

    fun start() {
        scr = if (Store.settings.hasOnboarded) Scr.Home else Scr.Splash
    }

    fun go(s: Scr) {
        if (s == scr) return
        backAction = null
        TabBarScroll.reset()
        scr = s
    }

    fun goTest(tab: String) {
        testTab = if (tab == "sim") "sim" else "pft"
        go(Scr.Sim)
    }

    /** 그 기록 종류의 탭 화면으로 */
    fun goMode(m: Mode) = when (m) {
        Mode.Training -> go(Scr.Training)
        Mode.Pft -> goTest("pft")
        Mode.Sim -> goTest("sim")
        Mode.Race -> go(Scr.Race)
    }

    fun open(r: Record, from: Scr) {
        detail = r; detailFrom = from; go(Scr.Detail)
    }

    // 계정
    var authReturn by mutableStateOf(Scr.Training)
    var authMode by mutableStateOf("signup")
    fun toAuth(from: Scr, mode: String = "signup") {
        authReturn = from; authMode = mode; go(Scr.Auth)
    }

    fun sub(s: Scr, from: Scr) {
        subFrom = from; go(s)
    }

    private val subBackLabel: String
        get() = when (subFrom) {
            Scr.SetEvent -> "Race event"
            Scr.Ob1, Scr.Ob2 -> "Back"
            Scr.Settings -> "Settings"
            Scr.Race -> "Race"
            Scr.Sim -> "Full Sim"
            Scr.Home -> "Home"
            else -> "Profile"
        }

    /** 고정 바 제목 */
    val barTitle: String
        get() = when (scr) {
            Scr.Home -> "Home"
            Scr.Training -> "Training"
            Scr.Sim -> "Test"
            Scr.Race -> "Race"
            Scr.Settings -> "Settings"
            Scr.FindEvent -> "Find event"
            Scr.Account -> "Profile"
            Scr.SetHr -> "Max heart rate"
            Scr.SetGoals -> "Split goals"
            Scr.SetDiv -> "Division"
            Scr.SetRun -> "Running"
            Scr.Friends -> "Friends"
            else -> ""
        }

    /** 고정 바 왼쪽 뒤로 (없으면 SPLITS8 로고) */
    val barBack: Pair<String, () -> Unit>?
        get() = when (scr) {
            Scr.FindEvent -> "Race event" to { go(Scr.SetEvent) }
            Scr.Account, Scr.SetRun -> "Settings" to { go(Scr.Settings) }
            Scr.SetGoals -> "Race" to { go(Scr.Race) }
            Scr.Friends -> {
                val home = friendsFrom == Scr.Home
                (if (home) "Home" else "Settings") to { go(if (home) Scr.Home else Scr.Settings) }
            }
            Scr.SetDiv, Scr.SetHr -> {
                val to = if (subFrom == scr) Scr.Account else subFrom
                subBackLabel to { go(to) }
            }
            else -> null
        }

    /** 안드로이드 뒤로 가기: 화면 안 ‹ → 고정 바 ‹ → 탭 화면이면 홈 → 홈이면 앱 닫기(false) */
    fun back(): Boolean {
        backAction?.let { it(); return true }
        barBack?.let { it.second(); return true }
        if (scr.showsTabs && scr != Scr.Home) { go(Scr.Home); return true }
        return false
    }
}

/**
 * 아래 탭 바 접기/펴기: 내용을 아래로 읽어 내려가면 아이콘만, 다시 위로 분명히 되돌리면 글자까지.
 * 손가락으로 끄는 동안에만 방향을 읽음 (손을 뗀 뒤 미끄러짐은 무시). 아이폰 TabBarScroll 과 같은 값
 */
object TabBarScroll {
    var compact by mutableStateOf(false)
        private set
    private var last = 0f
    private var now = 0f
    private var isDragging = false
    private const val FOLD_BY = 8f
    private const val UNFOLD_BY = 30f

    fun dragging(on: Boolean) {
        if (on && !isDragging) last = now
        if (!on && isDragging && now >= 24 && now - last < -12) { compact = false; last = now }
        isDragging = on
    }

    /** y = 맨 위에서 내려간 거리(dp) */
    fun update(y: Float) {
        now = y
        if (y < 24) { compact = false; last = y; return }
        if (!isDragging) return
        val d = y - last
        if (d > FOLD_BY) { compact = true; last = y } else if (d < -UNFOLD_BY) { compact = false; last = y }
    }

    fun reset() {
        last = 0f; now = 0f; isDragging = false; compact = false
    }
}
