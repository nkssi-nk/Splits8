package com.nkssi.splits8

import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import com.nkssi.splits8.shared.GlowTheme
import com.nkssi.splits8.shared.L10n
import com.nkssi.splits8.shared.Mode
import com.nkssi.splits8.shared.PlannedWorkout
import com.nkssi.splits8.shared.ProgItem
import com.nkssi.splits8.shared.Program
import com.nkssi.splits8.shared.Record
import com.nkssi.splits8.shared.Station
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

/** 운동 예약 시트 요청 (달력 날짜 · 예약 줄에서 엶). mode = Training 또는 Sim */
data class PlanRequest(val date: java.time.Instant, val mode: Mode, val existing: PlannedWorkout? = null)

/** HIIT · 러닝 설정 시트 (새로 만들기 / 저장된 것 편집). kind = "hiit" / "run" */
data class BonusRequest(val kind: String, val existing: Program? = null, val key: String = java.util.UUID.randomUUID().toString())

/** 확인 창 (아이폰 .alert). destructive = 빨간 확인 단추 */
data class Ask(
    val title: String, val message: String? = null, val ok: String = "OK", val cancel: String? = "Cancel",
    val destructive: Boolean = false, val onOk: () -> Unit = {},
)

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

    // MARK: 트레이닝 만들기 (아이폰 BuilderView 의 draft)

    var editId by mutableStateOf<String?>(null)
    var draftName by mutableStateOf("")
    var draftSeq by mutableStateOf<List<ProgItem>>(emptyList())
    var draftSets by mutableStateOf(1)

    /** 새 트레이닝: 기본은 HYROX 한 바퀴 16구간 (Run 1KM + 스테이션 8개 순서대로) */
    fun newTraining() {
        editId = null; draftName = ""; draftSets = 1
        draftSeq = Station.all.flatMap { listOf(ProgItem("run", "1KM"), ProgItem(it.key)) }.take(MAX_SEQ)
        go(Scr.Builder)
    }

    fun edit(p: Program) {
        editId = p.id; draftName = p.name; draftSets = p.sets; draftSeq = p.seq
        go(Scr.Builder)
    }

    /** 만들기 화면 Cancel */
    fun cancelDraft() {
        editId = null
        go(Scr.Training)
    }

    /** 만들기 화면 Save: 바로 저장. 이름이 비면 "Training N" */
    fun saveDraft() {
        if (draftSeq.isEmpty()) return
        val typed = draftName.trim()
        val name = typed.ifEmpty { L10n.t("Training %lld", Store.programs.size + 1) }
        val old = Store.programs.firstOrNull { it.id == editId }
        val p = Program(editId ?: "u${System.currentTimeMillis() / 1000}", name, draftSets, draftSeq, meta = null, quick = old?.quick ?: false)
        Store.saveProgram(p)
        editId = null; draftName = ""
        go(Scr.Training)
    }

    const val MAX_SEQ = 16

    // MARK: 시트 · 확인 창

    var bonus by mutableStateOf<BonusRequest?>(null)
    var planRequest by mutableStateOf<PlanRequest?>(null)
    var ask by mutableStateOf<Ask?>(null)
    /** 레이스 탭 시트: "goal" (목표 시간) / "doubles" (더블 구간 나누기) / null */
    var raceSheet by mutableStateOf<String?>(null)
    /** 대회 화면에서 고치는 중인 대회 (Save 전) */
    var evDraft by mutableStateOf<com.nkssi.splits8.shared.RaceEvent?>(null)
    /** Test 탭 설명 시트: "pft" / "sim" / null */
    var testInfo by mutableStateOf<String?>(null)

    fun openPlan(date: java.time.Instant, mode: Mode = Mode.Training, existing: PlannedWorkout? = null) {
        planRequest = PlanRequest(date, if (mode == Mode.Sim) Mode.Sim else Mode.Training, existing)
    }

    // MARK: 가입 프로필 (성별 · 키/몸무게 · 태어난 해 · 대회 경험) — 화면은 가입 절차 단계에서

    var profileStep by mutableStateOf(1)
    var profileEdit by mutableStateOf(false)
    var profileNext by mutableStateOf(Scr.Home)

    /** 프로필 화면에서 한 항목만 고치기 */
    fun editProfile(step: Int) {
        profileStep = step; profileEdit = true; profileNext = Scr.Account
        go(Scr.ProfileSetup)
    }

    /** 계정 삭제 (서버에서 지움 — 5단계 서버 연결 때 붙임. 지금은 안내만) */
    fun deleteAccount() {
        ask = Ask("Delete account", "Account deletion comes in a later Android build.", cancel = null)
    }

    /** 폰으로 기록 (4-3 단계에서 화면을 붙임. 지금은 안내만) */
    fun startOnPhone(mode: Mode, program: Program?) {
        ask = Ask("Start on phone", "Phone recording comes in a later Android build.", cancel = null)
    }

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
        if (ask != null) { ask = null; return true }
        if (bonus != null) { bonus = null; return true }
        if (planRequest != null) { planRequest = null; return true }
        if (testInfo != null) { testInfo = null; return true }
        if (raceSheet != null) { raceSheet = null; return true }
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
