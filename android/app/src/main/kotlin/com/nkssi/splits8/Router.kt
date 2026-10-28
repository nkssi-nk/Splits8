package com.nkssi.splits8

import kotlinx.coroutines.launch

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
import com.nkssi.splits8.shared.l10n
import com.nkssi.splits8.ui.Ambient
import com.nkssi.splits8.ui.GlowDrift

/** 화면 목록 (아이폰 Scr 과 같음) */
enum class Scr {
    Splash, Ob1, Ob2, Ob3,
    Home, Training, Builder, Sim, Race, Settings,
    SetHr, SetDiv, SetRun, SetGoals, SetEvent, Friends,
    /** 98번(빌드 28): 설정 › 운동 · 측정 · 종목 보정 */
    SetWorkout, SetCalib,
    Auth, Code, Nick, FindEvent, Account,
    ProfileSetup,
    Detail, Share,
    PhoneLive, WatchLive;

    /** 아래 탭 바를 보여 주는 화면 */
    val showsTabs: Boolean
        get() = this in setOf(Home, Training, Sim, Race, Settings, FindEvent, Account, SetHr, SetGoals, SetDiv, SetRun, SetEvent, Friends, SetWorkout, SetCalib)

    /** 위 고정 바 (44, 반투명 검정) */
    val showsBar: Boolean
        get() = this in setOf(Home, Training, Sim, Race, Settings, FindEvent, Account, SetHr, SetGoals, SetDiv, SetRun, Friends, SetWorkout, SetCalib)

    /** 화면 자체 머리줄(Cancel · 제목 · Save)을 맨 위에 고정하는 화면 */
    val pinsNav: Boolean get() = this == Builder

    /** 어느 탭이 켜져 보이는지 */
    fun tab(friendsFrom: Scr): Scr? = when (this) {
        Home -> Home
        Training, Builder -> Training
        Sim -> Sim
        // 87번: Full Sim 에서 연 구간 목표는 Test 탭
        SetGoals -> if (Router.subFrom == Sim) Sim else Race
        Race, SetEvent, FindEvent -> Race
        Friends -> if (friendsFrom == Home) Home else Settings
        Settings, SetHr, SetDiv, SetRun, Account, SetWorkout, SetCalib -> Settings
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
        SetWorkout, SetCalib -> Ambient.y(0.18f, 1.2f, 0.55f, 0.5f, 0.2f, t)
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

/** 16번: 아래 "숨겼어요 · 되돌리기" 띠 (4초 뒤 사라짐). key 는 같은 글자를 다시 띄워도 4초를 새로 세게 */
data class UndoNote(val text: String, val key: String = java.util.UUID.randomUUID().toString(), val undo: () -> Unit)

/** 확인 창 (아이폰 .alert). destructive = 빨간 확인 단추 */
data class Ask(
    val title: String, val message: String? = null, val ok: String = "OK", val cancel: String? = "Cancel",
    val destructive: Boolean = false,
    /** 세 번째 단추 (빨강, 예: Discard). 있으면 단추를 세로로 쌓음 (아이폰 3단추 알림) */
    val alt: String? = null, val onAlt: () -> Unit = {},
    /** 맨 끝에 둠: Ask(...) { } 의 { } 가 이 동작이 되게 */
    val onOk: () -> Unit = {},
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
    /** Test 탭에서 고른 쪽: "sim" / "pft". 88번(빌드 28): 처음엔 Full Sim (예전에 PFT 를 골라 둔 사람은 그대로 — Store 가 기억) */
    var testTab by mutableStateOf("sim")
    /** 98번: 설정 › 운동 · 측정 에서 고른 보정 종목 (skiErg · row · wallBalls) */
    var calibIcon by mutableStateOf("wallBalls")
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
    /** ··· 메뉴 (신고 · 차단)를 띄울 사람 */
    var userMenu by mutableStateOf<com.nkssi.splits8.shared.BlockedUser?>(null)
    /** 기록 상세의 파트너 고르기 시트 (기록 id) */
    /** 빌드 24: 응원 보낼 친구 (시트) */
    var cheerTo by mutableStateOf<com.nkssi.splits8.shared.Friend?>(null)
    var partnerFor by mutableStateOf<String?>(null)
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
        signupFlow = false
        profileStep = step; profileEdit = true; profileNext = Scr.Account
        go(Scr.ProfileSetup)
    }

    /** 계정 삭제 (서버에서 지움 — 5단계 서버 연결 때 붙임. 지금은 안내만) */
    /** 계정 삭제 (서버의 프로필 · 친구 · 기록). 이 폰의 기록은 그대로 */
    fun deleteAccount() {
        kotlinx.coroutines.CoroutineScope(kotlinx.coroutines.Dispatchers.Main.immediate).launch {
            try {
                Cloud.deleteAccount()
                Store.clearAccount()
                go(Scr.Settings)
            } catch (e: Exception) {
                ask = Ask("Couldn't delete the account", e.message, cancel = null)
            }
        }
    }

    // 폰으로 기록
    var phoneRun by mutableStateOf<PhoneRunRequest?>(null)
    /** 진행 중인 폰 기록 (화면이 다시 그려져도 이어지게 여기 둠) */
    var phoneEngine = PhoneRunEngine()
    /** 시험용: 3 · 2 · 1 없이 바로 시작 (아이폰 --nocount) */
    var phoneNoCount = false

    /** 시험용 시계 (ms) */
    var phoneClock: () -> Long = { System.currentTimeMillis() }

    fun startOnPhone(mode: Mode, program: Program?) {
        phoneEngine = PhoneRunEngine(phoneClock).also { watchPhoneRun(it) }
        phoneRun = PhoneRunRequest(mode, program, scr)
        go(Scr.PhoneLive)
    }

    /** 운동이 끝났을 때 카드 (기록 상세 위로 올라옴) */
    var finish by mutableStateOf<Record?>(null)

    /** 기록 상세를 열고 그 위에 카드를 올림 */
    fun showFinish(rec: Record, from: Scr) {
        open(rec, from)
        finish = rec
    }

    fun start() {
        scr = if (Store.settings.hasOnboarded) Scr.Home else Scr.Splash
        // 폰으로 기록하던 중 앱이 꺼졌으면 그 화면으로 이어서 (3 · 2 · 1 없이)
        Store.loadPhoneRun()?.let { x ->
            phoneEngine = PhoneRunEngine(phoneClock).also { it.restore(x); watchPhoneRun(it) }
            phoneRun = x.req
            scr = Scr.PhoneLive
        }
    }

    /** 진행 상태가 바뀔 때마다 파일에 (끝나면 지움) */
    fun watchPhoneRun(e: PhoneRunEngine) {
        e.onChange = { Store.savePhoneRun(e.snapshot()) }
    }

    fun go(s: Scr) {
        if (s == scr) return
        backAction = null
        TabBarScroll.reset()
        scr = s
    }

    fun goTest(tab: String) {
        setTest(tab)
        go(Scr.Sim)
    }

    /** Test 탭 쪽 고르기 (기억해 둠) */
    fun setTest(tab: String) {
        testTab = if (tab == "pft") "pft" else "sim"
        Store.saveTestTab(testTab)
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
        authReturn = from; authMode = mode; code = ""; nickDraft = ""; go(Scr.Auth)
    }
    var email by mutableStateOf("")
    var code by mutableStateOf("")
    var nickDraft by mutableStateOf("")
    /** 새 계정 가입 중 (닉네임 → 가입 프로필 4단계, 위 점 1 / 5) */
    var signupFlow by mutableStateOf(false)

    /** 로그인 · 가입 직후: 새 계정이면 닉네임 → 가입 프로필, 아니면 (프로필을 안 했으면) 가입 프로필 → 원래 화면 */
    fun afterSignIn(newAccount: Boolean) {
        if (newAccount) {
            signupFlow = true; nickDraft = ""; go(Scr.Nick)
        } else if (Store.settings.profileDone != true) {
            startProfile(authReturn)
        } else {
            go(authReturn)
        }
    }

    /** 닉네임을 저장한 뒤 */
    fun afterNick() {
        if (signupFlow && Store.settings.profileDone != true) startProfile(authReturn)
        else { signupFlow = false; go(if (authReturn == Scr.Nick) Scr.Account else authReturn) }
    }

    /** 가입 프로필 처음부터 (끝나면 next 로) */
    fun startProfile(next: Scr) {
        profileStep = 1; profileEdit = false; profileNext = next
        go(Scr.ProfileSetup)
    }

    /** 가입 프로필이 끝났거나 건너뜀 */
    fun finishProfile() {
        signupFlow = false
        go(profileNext)
    }

    /** 잠깐 떴다 사라지는 안내 (2.5초) */
    var toast by mutableStateOf<String?>(null)

    /** 16번: 되돌리기 띠 (null = 안 보임) */
    var undo by mutableStateOf<UndoNote?>(null)

    // MARK: 링크로 받은 트레이닝 · 더블 계획 (아이폰 Router.handle(url:))

    /** splits8://t?d=… (트레이닝) · splits8://d?d=… (더블 계획) · https://…/t.html#… 로 앱이 열렸을 때. 우리 링크가 아니면 아무것도 안 함 */
    fun handleUrl(url: String) {
        if (com.nkssi.splits8.shared.DoublesLink.isDoubles(url)) {
            val got = com.nkssi.splits8.shared.DoublesLink.token(url)?.let { com.nkssi.splits8.shared.DoublesLink.read(it) }
            if (got == null) {
                ask = Ask("This doubles plan link can't be read", "The link may be cut off. Ask for it again.".l10n, cancel = null)
                return
            }
            // "가테부님의 더블 계획을 받을까요?"
            val title = got.second?.let { L10n.t("Get %@'s doubles plan?", it) } ?: "Get this doubles plan?".l10n
            ask = Ask(title, "Your doubles plan will be replaced. Who goes first is swapped so it fits you.".l10n, ok = "Get plan") {
                acceptIncomingDoubles(got)
            }
            return
        }
        val lower = url.lowercase()
        val token: String? = when {
            lower.startsWith(com.nkssi.splits8.shared.ProgramLink.scheme + "://t") ->
                url.substringAfter('?', "").split('&').firstOrNull { it.startsWith("d=") }?.substring(2)
                    ?.let { runCatching { java.net.URLDecoder.decode(it, "UTF-8") }.getOrDefault(it) }
            url.substringAfter('#', "").startsWith("1.") -> url.substringAfter('#')
            else -> return
        }
        val p = token?.let { com.nkssi.splits8.shared.ProgramLink.program(it) }
        if (p == null) {
            ask = Ask("This training link can't be read", "The link may be cut off. Ask for it again.".l10n, cancel = null)
            return
        }
        // "Leg day\n8 segments × 2 sets"
        ask = Ask("Add this training?", p.name + "\n" + L10n.t("%lld segments × %lld sets", p.seq.size, p.sets), ok = "Add") { addIncoming(p) }
    }

    /** 받은 트레이닝을 내 목록에 더함 (확인 창에서 Add). 5개 한도면 안내 */
    fun addIncoming(p: Program) {
        if (Store.programs.size >= Program.freeLimit) {
            ask = Ask(L10n.t("You can save up to %lld trainings", Program.freeLimit), "Delete one to make a new training.".l10n, cancel = null)
            return
        }
        Store.saveProgram(p)
        if (Store.settings.hasOnboarded && scr != Scr.PhoneLive && scr != Scr.Builder) go(Scr.Training)
    }

    /** 받은 더블 계획을 내 계획으로 저장 (확인 창에서 받기). 먼저 하는 사람을 바꾸고 파트너 = 보낸 사람 */
    fun acceptIncomingDoubles(d: Pair<com.nkssi.splits8.shared.DoublesPlan, String?>) {
        Store.update { it.copy(doublesPlan = d.first.swapped(d.second)) }
        // 처음 안내 화면 · 운동 중에는 화면을 옮기지 않음
        if (Store.settings.hasOnboarded && scr != Scr.PhoneLive && scr != Scr.Builder) go(Scr.Race)
    }

    // MARK: 빌드 27 · 앱을 열 때 받은 응원 · 친구 요청 알림 띠

    /** 위쪽 작은 알림 띠 글자 (null = 안 보임) */
    var notice by mutableStateOf<String?>(null)

    /** 앱이 앞으로 올 때 한 번: 로그인해 있으면 받은 응원 · 친구 요청을 보고 있으면 띠를 띄움 (4초 뒤 사라짐) */
    fun showNoticeIfAny() {
        if (!Store.signedIn) return
        val cheers = Store.unseenCheers
        val reqs = Store.incoming.size
        if (cheers <= 0 && reqs <= 0) return
        // 운동 중 · 가입 · 온보딩 · 운동 끝 카드 · 이미 친구 화면이면 띄우지 않음
        if (!scr.showsTabs || scr == Scr.Friends || finish != null || phoneRun != null || WatchMirror.on) return
        val parts = ArrayList<String>()
        if (cheers > 0) parts.add(if (cheers == 1) "1 new cheer".l10n else L10n.t("%lld new cheers", cheers))
        if (reqs > 0) parts.add(if (reqs == 1) "1 friend request".l10n else L10n.t("%lld friend requests", reqs))
        notice = (if (cheers > 0) "🔥 " else "👋 ") + parts.joinToString(" · ")
    }

    /** 띠를 누름 → 친구 화면 */
    fun openNotice() {
        notice = null
        friendsFrom = if (scr == Scr.Home) Scr.Home else Scr.Settings
        go(Scr.Friends)
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
            Scr.SetWorkout -> "Workout & tracking"
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
            Scr.SetWorkout -> "Workout & tracking"
            Scr.SetCalib -> "Calibrate"
            Scr.Friends -> "Friends"
            else -> ""
        }

    /** 고정 바 왼쪽 뒤로 (없으면 SPLITS8 로고) */
    val barBack: Pair<String, () -> Unit>?
        get() = when (scr) {
            Scr.FindEvent -> "Race event" to { go(Scr.SetEvent) }
            Scr.Account, Scr.SetWorkout -> "Settings" to { go(Scr.Settings) }
            Scr.SetRun, Scr.SetCalib -> "Workout & tracking" to { go(Scr.SetWorkout) }
            // 87번: Full Sim 에서 들어왔으면 Full Sim 으로
            Scr.SetGoals -> if (subFrom == Scr.Sim) "Full Sim" to { goTest("sim") } else "Race" to { go(Scr.Race) }
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
        if (userMenu != null) { userMenu = null; return true }
        if (partnerFor != null) { partnerFor = null; return true }
        if (finish != null) { finish = null; return true }
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
        // 74-1: 방향이 같으면 기준점을 따라 옮겨서 (접힌 채 더 내리면 기준도 내려감) 살짝 되돌림에 다시 펴지지 않게
        if (compact) {
            if (d > 0) last = y else if (d < -UNFOLD_BY) { compact = false; last = y }
        } else {
            if (d < 0) last = y else if (d > FOLD_BY) { compact = true; last = y }
        }
    }

    fun reset() {
        last = 0f; now = 0f; isDragging = false; compact = false
    }
}
