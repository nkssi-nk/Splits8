package com.nkssi.splits8

import androidx.activity.ComponentActivity
import androidx.compose.ui.test.junit4.createAndroidComposeRule
import androidx.compose.ui.test.onRoot
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.test.onNodeWithText
import com.github.takahirom.roborazzi.captureRoboImage
import com.nkssi.splits8.shared.L10n
import com.nkssi.splits8.shared.Settings
import com.nkssi.splits8.ui.GlowDrift
import com.nkssi.splits8.ui.PhoneRoot
import com.nkssi.splits8.screens.LaunchLogo
import com.nkssi.splits8.screens.ScreenFor
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.performClick
import com.nkssi.splits8.shared.Program
import org.junit.After
import org.junit.Before
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config
import org.robolectric.annotation.GraphicsMode

/**
 * 화면 사진 (에뮬레이터 없이). 결과: app/build/shots 폴더의 png
 * 크기: 갤럭시 S 시리즈와 비슷한 412 × 915 dp, 화면 밀도 2.625 (xxhdpi)
 */
@RunWith(RobolectricTestRunner::class)
@GraphicsMode(GraphicsMode.Mode.NATIVE)
@Config(sdk = [35], qualifiers = "w412dp-h915dp-xxhdpi")
class Shots {
    @get:Rule val rule = createAndroidComposeRule<ComponentActivity>()

    private val out = System.getProperty("shots.dir") ?: "build/shots"

    @Before fun setUp() {
        GlowDrift.fixed = true
        Store.useDemo(Settings(hasOnboarded = true), com.nkssi.splits8.shared.Program.presets(), emptyList())
        Health.api = FakeHealth(perms = emptySet())      // Health Connect 있고 아직 허락 전인 폰
    }

    @After fun tearDown() {
        Health.api = RealHealth
        Router.ask = null; Router.bonus = null; Router.planRequest = null; Router.editId = null; Router.testInfo = null
        Router.testTab = "pft"; Router.raceSheet = null; Router.evDraft = null; Router.toast = null
        Router.email = ""; Router.code = ""; Router.nickDraft = ""; Router.signupFlow = false; Router.profileEdit = false; Router.userMenu = null
        Router.partnerFor = null; Router.detail = null
        com.nkssi.splits8.screens.ShareDemo.photo = null; com.nkssi.splits8.screens.ShareDemo.colorDemo = false
        com.nkssi.splits8.screens.ShareDebug.dryRun = false
        Router.finish = null; Router.phoneNoCount = false; Router.phoneClock = { System.currentTimeMillis() }
    }

    private fun shot(name: String, lang: String = "en", s: Scr) {
        L10n.lang = lang
        Router.scr = s
        rule.setContent { PhoneRoot { ScreenFor(it) } }
        rule.waitForIdle()
        rule.onRoot().captureRoboImage("$out/$name.png")
    }

    @Test fun splash() = shot("01_splash", s = Scr.Splash)
    @Test fun splashKo() = shot("01_splash_ko", "ko", Scr.Splash)
    @Test fun home() = shot("02_home", s = Scr.Home)

    /** 예시 기록이 있는 홈 (아이폰 --demo --friends --racenear 와 같은 데이터). 화면 전체를 보려고 아주 긴 화면으로 */
    private fun demoHome(name: String, lang: String, raceDays: Int?) {
        val now = java.time.Instant.parse("2026-09-25T03:00:00Z")
        Store.now = { now }
        val o = Demo.Opts(friends = true, raceDays = raceDays)
        Store.useDemo(Demo.settings(o, Store.today()), Demo.programs(), Demo.records(o), Demo.friends(),
            Demo.leaderboard(), Demo.requests(), "demo.me")
        shot(name, lang, Scr.Home)
    }

    @Config(sdk = [35], qualifiers = "w412dp-h2400dp-xxhdpi")
    @Test fun homeDemoLong() = demoHome("05_home_demo_long", "en", 3)

    @Config(sdk = [35], qualifiers = "w412dp-h2400dp-xxhdpi")
    @Test fun homeDemoLongKo() = demoHome("05_home_demo_long_ko", "ko", 3)

    @Test fun homeDemo() = demoHome("06_home_demo", "en", 3)
    @Test fun trainingKo() = shot("03_training_ko", "ko", Scr.Training)

    // MARK: 트레이닝 탭 (4-2)

    private fun demoTraining(lang: String = "en") {
        val now = java.time.Instant.parse("2026-09-25T03:00:00Z")
        Store.now = { now }
        val o = Demo.Opts(friends = true)
        val progs = listOf(Program.run(5, false, "run.demo1"), Program.hiit().copy(id = "hiit.demo1")) + Demo.programs()
        Store.useDemo(Demo.settings(o, Store.today()), progs, Demo.records(o), Demo.friends(), me = "demo.me")
        L10n.lang = lang
    }

    @Config(sdk = [35], qualifiers = "w412dp-h1500dp-xxhdpi")
    @Test fun trainingDemo() { demoTraining(); shot("10_training", s = Scr.Training) }

    @Config(sdk = [35], qualifiers = "w412dp-h1500dp-xxhdpi")
    @Test fun trainingDemoKo() { demoTraining("ko"); shot("10_training_ko", "ko", Scr.Training) }

    @Config(sdk = [35], qualifiers = "w412dp-h2000dp-xxhdpi")
    @Test fun builderNew() { demoTraining(); Router.newTraining(); shot("11_builder_new", s = Scr.Builder) }

    @Config(sdk = [35], qualifiers = "w412dp-h2000dp-xxhdpi")
    @Test fun builderEditKo() {
        demoTraining("ko"); Router.edit(Store.programs.first { it.id == "p1" }); shot("12_builder_edit_ko", "ko", Scr.Builder)
    }

    @Test fun bonusRun() {
        demoTraining(); Router.bonus = BonusRequest("run"); shot("13_bonus_run", s = Scr.Training); Router.bonus = null
    }

    @Test fun bonusHiitKo() {
        demoTraining("ko"); Router.bonus = BonusRequest("hiit"); shot("14_bonus_hiit_ko", "ko", Scr.Training); Router.bonus = null
    }

    @Test fun planSheet() {
        demoTraining()
        Router.openPlan(java.time.LocalDate.of(2026, 9, 27).atTime(7, 0).atZone(com.nkssi.splits8.shared.Fm.zone).toInstant())
        shot("15_plan", s = Scr.Home)
        rule.onNodeWithTag("plan.date").performClick(); rule.waitForIdle()
        rule.onRoot().captureRoboImage("$out/15_plan_date.png")
        rule.onNodeWithTag("plan.time").performClick(); rule.waitForIdle()
        rule.onRoot().captureRoboImage("$out/15_plan_time.png")
        Router.planRequest = null
    }

    // MARK: Test 탭 (4-3)

    @Config(sdk = [35], qualifiers = "w412dp-h2000dp-xxhdpi")
    @Test fun pftDemo() { demoTraining(); Router.testTab = "pft"; shot("20_pft", s = Scr.Sim) }

    @Config(sdk = [35], qualifiers = "w412dp-h2000dp-xxhdpi")
    @Test fun pftEmptyKo() {
        Store.useDemo(Settings(hasOnboarded = true), Program.presets(), emptyList())
        Router.testTab = "pft"; shot("21_pft_empty_ko", "ko", Scr.Sim)
    }

    @Config(sdk = [35], qualifiers = "w412dp-h2800dp-xxhdpi")
    @Test fun simDemo() { demoTraining(); Router.testTab = "sim"; shot("22_sim", s = Scr.Sim) }

    @Config(sdk = [35], qualifiers = "w412dp-h2800dp-xxhdpi")
    @Test fun simDemoKo() { demoTraining("ko"); Router.testTab = "sim"; shot("22_sim_ko", "ko", Scr.Sim) }

    @Test fun simEmpty() {
        Store.useDemo(Settings(hasOnboarded = true), Program.presets(), emptyList())
        Router.testTab = "sim"; shot("23_sim_empty", s = Scr.Sim)
    }

    @Config(sdk = [35], qualifiers = "w412dp-h1600dp-xxhdpi")
    @Test fun pftInfoKo() { demoTraining("ko"); Router.testTab = "pft"; Router.testInfo = "pft"; shot("24_pft_info_ko", "ko", Scr.Sim) }

    @Test fun simInfo() { demoTraining(); Router.testTab = "sim"; Router.testInfo = "sim"; shot("25_sim_info", s = Scr.Sim) }

    // MARK: 레이스 탭 (4-4)

    private fun demoRace(lang: String = "en", dbl: Boolean = false) {
        demoTraining(lang)
        Store.update { it.copy(event = com.nkssi.splits8.shared.RaceEvent("Seoul", "KINTEX, Goyang",
            java.time.LocalDate.of(2026, 11, 13).atStartOfDay(com.nkssi.splits8.shared.Fm.zone).toInstant(), "09:30"),
            division = if (dbl) "dblM" else it.division) }
    }

    @Config(sdk = [35], qualifiers = "w412dp-h1900dp-xxhdpi")
    @Test fun raceDemo() { demoRace(); shot("30_race", s = Scr.Race) }

    @Config(sdk = [35], qualifiers = "w412dp-h1900dp-xxhdpi")
    @Test fun raceDemoKoDbl() { demoRace("ko", dbl = true); shot("30_race_ko_dbl", "ko", Scr.Race) }

    @Test fun raceEmpty() {
        Store.useDemo(Settings(hasOnboarded = true), Program.presets(), emptyList())
        shot("31_race_empty", s = Scr.Race)
    }

    @Test fun goalSheet() { demoRace(); Router.raceSheet = "goal"; shot("32_goal_sheet", s = Scr.Race) }

    @Config(sdk = [35], qualifiers = "w412dp-h1100dp-xxhdpi")
    @Test fun doublesSheetKo() { demoRace("ko", dbl = true); Router.raceSheet = "doubles"; shot("33_doubles_ko", "ko", Scr.Race) }

    @Config(sdk = [35], qualifiers = "w412dp-h1400dp-xxhdpi")
    @Test fun setEvent() {
        demoRace(); Router.evDraft = null; shot("34_event", s = Scr.SetEvent)
        rule.onNodeWithTag("ev.Date").performClick(); rule.waitForIdle()
        rule.onRoot().captureRoboImage("$out/34_event_date.png")
        rule.onNodeWithTag("ev.Date").performClick(); rule.onNodeWithTag("ev.Start time").performClick(); rule.waitForIdle()
        rule.onRoot().captureRoboImage("$out/34_event_time.png")
    }

    @Config(sdk = [35], qualifiers = "w412dp-h1500dp-xxhdpi")
    @Test fun findEventKo() { demoRace("ko"); shot("35_find_ko", "ko", Scr.FindEvent) }

    @Config(sdk = [35], qualifiers = "w412dp-h1700dp-xxhdpi")
    @Test fun setGoals() { demoRace(); shot("36_goals", s = Scr.SetGoals) }

    // MARK: 설정 탭 (4-5)

    @Config(sdk = [35], qualifiers = "w412dp-h2300dp-xxhdpi")
    @Test fun settingsDemo() { demoTraining(); shot("40_settings", s = Scr.Settings) }

    @Config(sdk = [35], qualifiers = "w412dp-h2300dp-xxhdpi")
    @Test fun settingsKoGuest() {
        Store.useDemo(Settings(hasOnboarded = true), Program.presets(), emptyList())
        Store.update { it.withGlow(com.nkssi.splits8.shared.GlowTheme.Blue) }
        shot("41_settings_ko_guest", "ko", Scr.Settings)
    }

    @Config(sdk = [35], qualifiers = "w412dp-h1900dp-xxhdpi")
    @Test fun accountSigned() { demoTraining(); shot("42_account", s = Scr.Account) }

    @Config(sdk = [35], qualifiers = "w412dp-h1300dp-xxhdpi")
    @Test fun accountGuestKo() {
        Store.useDemo(Settings(hasOnboarded = true), Program.presets(), emptyList())
        shot("43_account_guest_ko", "ko", Scr.Account)
    }

    @Config(sdk = [35], qualifiers = "w412dp-h1500dp-xxhdpi")
    @Test fun setDiv() { demoTraining(); Router.subFrom = Scr.Account; shot("44_division", s = Scr.SetDiv) }

    @Test fun setHrKo() { demoTraining("ko"); Router.subFrom = Scr.Account; shot("45_hr_ko", "ko", Scr.SetHr) }

    @Test fun setRun() { demoTraining(); shot("46_running", s = Scr.SetRun) }

    // MARK: 시작 · 가입 (4-6)

    private fun fresh() = Store.useDemo(Settings(hasOnboarded = false), Program.presets(), emptyList())

    @Test fun ob1Ko() { fresh(); shot("50_ob1_ko", "ko", Scr.Ob1) }
    @Test fun ob2() { fresh(); shot("51_ob2", s = Scr.Ob2) }
    @Test fun ob3Ko() { fresh(); shot("52_ob3_ko", "ko", Scr.Ob3) }
    @Test fun ob3Allowed() { fresh(); Health.api = FakeHealth(); shot("52_ob3_health_allowed", "en", Scr.Ob3) }
    @Test fun authSignup() { fresh(); Router.toAuth(Scr.Account); shot("53_auth", s = Scr.Auth) }
    @Test fun authSigninKo() { fresh(); Router.toAuth(Scr.Splash, "signin"); shot("53_auth_signin_ko", "ko", Scr.Auth) }
    @Test fun code() { fresh(); Router.email = "me@example.com"; Router.code = "123"; shot("54_code", s = Scr.Code) }
    @Test fun nickKo() { fresh(); Router.signupFlow = true; Router.nickDraft = "nkssi"; shot("55_nick_ko", "ko", Scr.Nick); Router.signupFlow = false }

    private fun profileStep(name: String, lang: String, step: Int, raced: Boolean?) {
        fresh(); Store.update { it.copy(raced = raced) }
        Router.signupFlow = true; Router.startProfile(Scr.Home); Router.profileStep = step
        shot(name, lang, Scr.ProfileSetup)
        Router.signupFlow = false
    }

    @Config(sdk = [35], qualifiers = "w412dp-h1000dp-xxhdpi")
    @Test fun profile1() { profileStep("56_profile1_raced", "en", 1, true) }

    @Test fun profile2Ko() { profileStep("57_profile2_ko", "ko", 2, false) }
    @Test fun profile3() { profileStep("58_profile3", "en", 3, null) }
    @Test fun profile4Ko() { profileStep("59_profile4_ko", "ko", 4, null) }

    // MARK: 친구 (4-7)

    private fun demoFriends(lang: String) {
        demoTraining(lang)
        Store.useDemo(Store.settings, Store.programs, Store.records, Demo.friends(), req = Demo.requests(), me = "demo.me")
        Store.update { it.copy(friendId = Demo.friends().first { f -> f.hasSplits }.id) }
    }

    @Config(sdk = [35], qualifiers = "w412dp-h1700dp-xxhdpi")
    @Test fun friends() { demoFriends("en"); shot("60_friends", s = Scr.Friends) }

    @Config(sdk = [35], qualifiers = "w412dp-h1700dp-xxhdpi")
    @Test fun friendsKo() { demoFriends("ko"); Router.friendsFrom = Scr.Home; shot("60_friends_ko", "ko", Scr.Friends) }

    @Test fun friendsGuest() { Store.useDemo(Settings(hasOnboarded = true), Program.presets(), emptyList()); shot("61_friends_guest", s = Scr.Friends) }

    @Test fun userMenuKo() {
        demoFriends("ko"); Router.userMenu = com.nkssi.splits8.shared.BlockedUser("x", "jiho")
        shot("62_user_menu_ko", "ko", Scr.Friends); Router.userMenu = null
    }

    @Test fun limitAlertKo() {
        demoTraining("ko")
        Store.useDemo(Store.settings, Store.programs + Program.presets().map { it.copy(id = it.id + "x") }, Store.records)
        shot("16_limit_ko", "ko", Scr.Training)
        rule.onNodeWithTag("training.new").performClick(); rule.waitForIdle()
        rule.onRoot().captureRoboImage("$out/16_limit_ko.png")
        Router.ask = null
    }
    @Test fun settings() = shot("04_settings", s = Scr.Settings)

    // 기록 상세 (아이폰 --demo · --demorun 과 같은 기록). 화면 전체를 보려고 아주 긴 화면으로
    private fun demoDetail(name: String, lang: String, pick: (List<com.nkssi.splits8.shared.Record>) -> com.nkssi.splits8.shared.Record,
                           friend: Boolean = false, from: Scr = Scr.Race) {
        val now = java.time.Instant.parse("2026-10-05T03:00:00Z")
        Store.now = { now }
        val o = Demo.Opts(friends = friend)
        val recs = Demo.records(o) + Demo.runRecord()
        var st = Demo.settings(o, Store.today())
        if (friend) st = st.copy(friendId = Demo.friends().first { it.hasSplits }.id)
        Store.useDemo(st, Demo.programs(), recs, Demo.friends(), Demo.leaderboard(), Demo.requests(), "demo.me")
        Router.detail = pick(Store.records); Router.detailFrom = from
        shot(name, lang, Scr.Detail)
    }

    @Config(sdk = [35], qualifiers = "w412dp-h4200dp-xxhdpi")
    @Test fun detailRace() = demoDetail("63_detail_race", "en", { r -> r.first { it.title == "Incheon" } }, friend = true)
    @Config(sdk = [35], qualifiers = "w412dp-h4200dp-xxhdpi")
    @Test fun detailSimKo() = demoDetail("64_detail_sim_ko", "ko", { r -> r.filter { it.mode == com.nkssi.splits8.shared.Mode.Sim }.maxBy { it.date } }, from = Scr.Sim)
    @Config(sdk = [35], qualifiers = "w412dp-h3000dp-xxhdpi")
    @Test fun detailRun() = demoDetail("65_detail_run", "en", { r -> r.first { it.isRunKind } }, from = Scr.Training)
    @Config(sdk = [35], qualifiers = "w412dp-h2400dp-xxhdpi")
    @Test fun detailPftKo() = demoDetail("66_detail_pft_ko", "ko", { r -> r.filter { it.mode == com.nkssi.splits8.shared.Mode.Pft }.maxBy { it.date } }, from = Scr.Sim)
    // 공유 화면 (아이폰 --sharephoto 예시 사진). 저장 그림(1080 너비)도 같이 남김
    private fun demoShare(name: String, lang: String, run: Boolean = false, photo: Boolean = true, setup: () -> Unit = {}) {
        val now = java.time.Instant.parse("2026-10-05T03:00:00Z")
        Store.now = { now }
        val o = Demo.Opts(friends = true)
        Store.useDemo(Demo.settings(o, Store.today()), Demo.programs(), Demo.records(o) + Demo.runRecord(), Demo.friends(),
            Demo.leaderboard(), Demo.requests(), "demo.me")
        val rec = Store.records.first { if (run) it.isRunKind else it.title == "Incheon" }
        Store.updatePartner(rec.id, if (run) null else "jiho")
        Router.detail = Store.records.first { it.id == rec.id }
        if (photo) { com.nkssi.splits8.screens.ShareDemo.photo = Demo.sharePhoto().asImageBitmap(); com.nkssi.splits8.screens.ShareDemo.colorDemo = true }
        com.nkssi.splits8.screens.ShareDebug.dryRun = true
        shot(name, lang, Scr.Share)
        setup()
        rule.waitForIdle()
        rule.onRoot().captureRoboImage("$out/$name.png")
        rule.onNodeWithTag("share.save").performClick()
        rule.waitForIdle()
        com.nkssi.splits8.screens.ShareDebug.last?.let { b ->
            java.io.File(out).mkdirs()
            java.io.FileOutputStream("$out/${name}_image.png").use { b.compress(android.graphics.Bitmap.CompressFormat.PNG, 100, it) }
        }
    }

    private fun tapTag(t: String) { rule.onNodeWithTag(t).performClick(); rule.waitForIdle() }

    @Config(sdk = [35], qualifiers = "w412dp-h1700dp-xxhdpi")
    @Test fun sharePoster() = demoShare("68_share_poster", "en")
    @Config(sdk = [35], qualifiers = "w412dp-h1700dp-xxhdpi")
    @Test fun sharePosterHazeKo() = demoShare("69_share_haze_ko", "ko") { tapTag("share.smoke.strong") }
    @Config(sdk = [35], qualifiers = "w412dp-h1700dp-xxhdpi")
    @Test fun sharePosterBlack() = demoShare("70_share_black", "en") { tapTag("share.text.black"); tapTag("share.gradient") }
    @Config(sdk = [35], qualifiers = "w412dp-h1700dp-xxhdpi")
    @Test fun shareTicket() = demoShare("71_share_ticket", "en") { tapTag("Ticket") }
    @Config(sdk = [35], qualifiers = "w412dp-h1700dp-xxhdpi")
    @Test fun shareBlockPostKo() = demoShare("72_share_block_post_ko", "ko", photo = false) {
        tapTag("Block"); rule.onNodeWithText(L10n.t("Post 4:5")).performClick()
    }
    @Config(sdk = [35], qualifiers = "w412dp-h1700dp-xxhdpi")
    @Test fun shareRunMap() = demoShare("73_share_run_map", "en", run = true, photo = false) { tapTag("share.map") }
    @Config(sdk = [35], qualifiers = "w412dp-h1700dp-xxhdpi")
    @Test fun shareEmpty() = demoShare("74_share_empty", "en", photo = false)

    // 폰으로 기록 (Full Sim 3번째 구간 Sled Push, 1:42 지남) · 3 2 1 · 끝 카드
    private var pt = 1_790_000_000_000L
    private fun demoPhone(name: String, lang: String, count: Boolean = false, pause: Boolean = false) {
        val o = Demo.Opts()
        Store.useDemo(Demo.settings(o, java.time.LocalDate.of(2026, 10, 5)), Demo.programs(), Demo.records(o))
        Router.phoneClock = { pt }
        Router.phoneNoCount = !count
        Router.scr = Scr.Sim
        L10n.lang = lang
        Router.startOnPhone(com.nkssi.splits8.shared.Mode.Sim, null)
        rule.setContent { PhoneRoot { ScreenFor(it) } }
        rule.waitForIdle()
        if (!count) {
            val e = Router.phoneEngine
            pt += 262_000; e.advance(); pt += 18_000; e.advance(); pt += 102_000
            if (pause) e.togglePause()
        }
        rule.mainClock.advanceTimeBy(400)
        rule.waitForIdle()
        rule.onRoot().captureRoboImage("$out/$name.png")
    }

    @Test fun phoneLive() = demoPhone("75_phone_live", "en")
    @Test fun phoneLiveKo() = demoPhone("75_phone_live_ko", "ko", pause = true)
    @Test fun phoneCount() = demoPhone("76_phone_count", "en", count = true)

    /** 워치 운동 같이 보기 (빌드 24 머리 · SPLIT | GOAL · 심박) */
    private fun demoWatchLive(name: String, lang: String, idx: Int, el: Int, reconnect: Boolean = false, finished: Boolean = false) {
        val seq = com.nkssi.splits8.shared.SeqBuilder.full(com.nkssi.splits8.shared.Division.of("openM"), true, com.nkssi.splits8.shared.Defaults.goals)
        val t = 1_790_000_000_000L
        WatchMirror.clock = { t }
        WatchMirror.demo(com.nkssi.splits8.shared.LiveState(com.nkssi.splits8.shared.Mode.Sim, "Full Simulation", seq, idx,
            seq.take(idx).map { (it.target * 1.03).toInt() }, el, true, 165, 286, 4, true, finished, "VS GOAL", delta = 14), reconnect)
        shot(name, lang, Scr.WatchLive)
        WatchMirror.reset(); WatchMirror.clock = { System.currentTimeMillis() }
    }

    @Test fun watchLive() = demoWatchLive("80_watch_live", "en", 6, 80)
    @Test fun watchLiveKo() = demoWatchLive("80_watch_live_ko", "ko", 4, 150)
    @Test fun watchLiveRox() = demoWatchLive("81_watch_live_rox_reconnect", "en", 7, 22, reconnect = true)
    @Test fun watchLiveSaving() = demoWatchLive("82_watch_live_saving_ko", "ko", 30, 10, finished = true)

    private fun demoFinish(name: String, lang: String, pick: (List<com.nkssi.splits8.shared.Record>) -> com.nkssi.splits8.shared.Record) {
        val now = java.time.Instant.parse("2026-10-05T03:00:00Z")
        Store.now = { now }
        val o = Demo.Opts(friends = true)
        Store.useDemo(Demo.settings(o, Store.today()), Demo.programs(), Demo.records(o) + Demo.runRecord(), Demo.friends(), me = "demo.me")
        val rec = pick(Store.records)
        Router.showFinish(rec, Scr.Race)
        shot(name, lang, Scr.Detail)
    }

    @Test fun finishGold() = demoFinish("77_finish_pb", "en") { r -> r.filter { it.mode == com.nkssi.splits8.shared.Mode.Sim }.maxBy { it.date } }
    @Test fun finishKo() = demoFinish("78_finish_ko", "ko") { r -> r.first { it.title == "Seoul" } }
    @Test fun finishRun() = demoFinish("79_finish_run", "en") { r -> r.first { it.isRunKind } }

    @Test fun partnerSheet() {
        demoDetail("67_detail_partner", "en", { r -> r.first { it.title == "Incheon" } }, friend = true)
        val id = Router.detail!!.id
        Store.updatePartner(id, "jiho")
        Router.detail = Store.records.first { it.id == id }
        rule.waitForIdle()
        rule.onRoot().captureRoboImage("$out/67_detail_partner.png")
        Router.partnerFor = id
        rule.waitForIdle()
        rule.onRoot().captureRoboImage("$out/67_partner_sheet.png")
    }

    @Test fun launch() {
        rule.setContent { LaunchLogo() }
        rule.mainClock.advanceTimeBy(600)
        rule.onRoot().captureRoboImage("$out/00_launch.png")
    }
}
