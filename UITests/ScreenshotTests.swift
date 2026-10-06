import XCTest

/// 가상 아이폰에서 앱을 켜고 화면을 차례로 캡처합니다 (GitHub Actions "0. 화면 확인").
/// 결과: 환경변수 SHOT_DIR 폴더에 PNG, 그리고 테스트 결과(xcresult)에도 첨부.
final class ScreenshotTests: XCTestCase {
    private var app: XCUIApplication!
    private var dir: URL!
    private var n = 0

    override func setUpWithError() throws {
        continueAfterFailure = true
        let env = ProcessInfo.processInfo.environment
        dir = URL(fileURLWithPath: env["SHOT_DIR"] ?? NSTemporaryDirectory() + "/splits8-shots")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    }

    /// 앱은 영어(기본) + 한국어. 화면 찾기는 영어 글자로 하므로 테스트는 항상 영어로 띄움
    static let english: [String] = ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"]

    private func launch(onboarded: Bool, extra: [String] = []) {
        app = XCUIApplication()
        app.launchArguments = (onboarded ? ["--demo", "--onboarded"] : ["--demo"]) + extra + Self.english
        app.launch()
        sleep(2)
    }

    /// 화면 저장
    private func shot(_ name: String) {
        sleep(1)
        let s = XCUIScreen.main.screenshot()
        n += 1
        let file = dir.appendingPathComponent(String(format: "%02d_%@.png", n, name))
        try? s.pngRepresentation.write(to: file)
        let a = XCTAttachment(screenshot: s)
        a.name = name
        a.lifetime = .keepAlways
        add(a)
    }

    /// 기다리지 않고 바로 저장 (카운트다운처럼 금방 지나가는 화면)
    private func shotNow(_ name: String) {
        let s = XCUIScreen.main.screenshot()
        n += 1
        let file = dir.appendingPathComponent(String(format: "%02d_%@.png", n, name))
        try? s.pngRepresentation.write(to: file)
        let a = XCTAttachment(screenshot: s)
        a.name = name
        a.lifetime = .keepAlways
        add(a)
    }

    private func element(_ i: String) -> XCUIElement {
        app.descendants(matching: .any).matching(NSPredicate(format: "identifier == %@", i)).firstMatch
    }

    private func tap(_ label: String, timeout: TimeInterval = 5) {
        let q = app.descendants(matching: .any).matching(NSPredicate(format: "label == %@ OR identifier == %@", label, label))
        let e = q.firstMatch
        if e.waitForExistence(timeout: timeout) { e.tap() } else { XCTFail("못 찾음: \(label)") }
        sleep(1)
    }
    private func id(_ i: String) { tap(i) }
    private func back() { id("back") }
    private func tab(_ n: String) { id("tab." + n) }

    private func tapContaining(_ text: String) {
        let e = app.buttons.containing(NSPredicate(format: "label CONTAINS %@", text)).firstMatch
        if e.waitForExistence(timeout: 5) { e.tap() } else {
            let t = app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", text)).firstMatch
            if t.waitForExistence(timeout: 3) { t.tap() } else { XCTFail("못 찾음: \(text)") }
        }
        sleep(1)
    }

    private func swipeBack() { app.swipeDown() }

    // MARK: 0. 앱 켤 때 가운데 로고
    func test0_launchLogo() {
        app = XCUIApplication()
        app.launchArguments = ["--demo", "--onboarded", "--launch"] + Self.english
        app.launch()
        let s = XCUIScreen.main.screenshot()
        try? s.pngRepresentation.write(to: dir.appendingPathComponent("00_launch_logo.png"))
        let a = XCTAttachment(screenshot: s); a.name = "launch_logo"; a.lifetime = .keepAlways; add(a)
    }

    // MARK: 1. 처음 실행 (시작 · 가입 · 온보딩)  — 시안 I0, I0s, I0a, I0b, I0c

    func test1_onboarding() {
        launch(onboarded: false)
        shot("I0_launch")
        id("splash.signin")
        shot("I0s_signin")
        back()
        id("splash.start")
        shot("I0a_division")
        id("ob.next")
        shot("I0b_heart_rate")
        id("ob.next")
        shot("I0c_connect_watch")
    }

    // MARK: 2. 탭 5개 + 하위 화면  — 시안 I1h, I1, I2, I3, I4, I4b, I4e, I5, I5a, I5c, I5b, I5f

    func test2_tabs() {
        launch(onboarded: true)
        shot("I1h_home")
        // 달력: 날짜를 누르면 그날 구역이 펼쳐지고, 다시 누르면 접힘
        id("cal.day.15")
        shot("I1h_home_day_open")
        id("cal.day.15")
        shot("I1h_home_day_closed")
        // 달력을 지난 달로 넘기면 아래 요약도 그 달로 (예시 기록은 9월)
        id("cal.prev")
        tap("Month")
        app.swipeUp()
        shot("I1h_home_prev_month_summary")
        app.swipeDown()
        // 달력을 왼쪽으로 밀면 다음 달
        let day = element("cal.day.15")
        if day.waitForExistence(timeout: 3) { day.swipeLeft() }
        shot("I1h_home_swiped_next_month")
        tap("Week")
        app.swipeUp()
        shot("I1h_home_bottom")          // 아래로 내린 상태: 탭 바가 아이콘만
        app.swipeUp()
        shot("I1h_home_bottom2")
        app.swipeDown(); app.swipeDown(); app.swipeDown()

        tab("Training")
        shot("I1_training")
        // 16구간 카드의 "+13" 을 눌러 펼침
        let fullCard = app.buttons.containing(NSPredicate(format: "label CONTAINS %@", "Full HYROX")).firstMatch
        if fullCard.waitForExistence(timeout: 3) {
            fullCard.coordinate(withNormalizedOffset: CGVector(dx: 0.86, dy: 0.76)).tap()
            sleep(1)
            shot("I1_training_card_expanded")
        }
        app.swipeUp()
        shot("I1_training_history")
        app.swipeDown(); app.swipeDown()
        tapContaining("Sled Intervals")
        shot("I2_edit_training")
        id("nav.left")
        id("training.new")
        shot("I2_new_training")
        app.swipeUp()
        shot("I2_new_training_bottom")
        id("nav.left")

        tab("Test")
        shot("I3p_test_pft")
        id("test.seg.sim")
        shot("I3_full_simulation")
        tap("WALL BALLS")
        shot("I3_wall_balls")
        app.swipeUp()
        shot("I3_history")
        // 기록 6개 → 5개씩 두 쪽
        app.swipeUp()
        if element("pager.next").waitForExistence(timeout: 3) {
            id("pager.next")
            shot("I3_history_page2")
        } else {
            shot("I3_history_no_pager")
        }
        app.swipeDown(); app.swipeDown(); app.swipeDown()

        tab("Race")
        shot("I4_race")
        // 목표 시간 → 구간별로 나누기 (유형 고르기)
        id("race.Goal time")
        shot("I4g_goal_time")
        tap("Runner")
        shot("I4g_goal_time_runner")
        id("nav.left")
        app.swipeUp()
        shot("I4_race_bottom")
        app.swipeDown()
        id("race.Event")
        shot("I4b_race_event")
        id("ev.Date")
        shot("I4b_date_picker")
        id("ev.Date")
        id("ev.Start time")
        shot("I4b_time_picker")
        id("ev.Start time")
        id("ev.find")
        shot("I4e_find_event")
        tap("Korea")
        shot("I4e_find_event_korea")
        back()
        id("nav.left")

        tab("Settings")
        shot("I5_settings")
        id("settings.profile")
        shot("I5a_profile")
        id("profile.signup")
        shot("I0s_create_account")
        back()
        id("profile.division")
        shot("I5a_division")
        back()
        id("profile.hr")
        shot("I5c_max_heart_rate")
        back()
        back()
        id("settings.running")
        shot("I5_running")
        back()
        id("settings.goals")
        shot("I5b_split_goals")
        back()
        id("settings.friends")
        shot("I5f_friends")
        back()
    }

    // MARK: 3. 기록 상세 · 공유  — 시안 I6, I7, S1–S6

    func test3_detail_share() {
        launch(onboarded: true, extra: ["--sharephoto"])
        tab("Race")
        app.swipeUp(); app.swipeUp()
        tapContaining("vs goal")
        shot("I6_detail_top")
        app.swipeUp()
        shot("I6_detail_charts")
        app.swipeUp()
        shot("I6_detail_splits")
        app.swipeUp()
        shot("I6_detail_bottom")
        app.swipeDown(); app.swipeDown(); app.swipeDown(); app.swipeDown()
        tap("Share with photo")
        shot("I7_share_poster_story")
        tap("Post 4:5")
        shot("I7_share_poster_post")
        tap("Story 9:16")
        tap("Ticket")
        shot("I7_share_ticket")
        tap("Block")
        shot("I7_share_block")
        // Poster + 연기 (옅게 · 짙게) + 글자 옮기기 + 검은 글자
        tap("Poster")
        app.swipeUp()
        id("share.smoke.light")
        app.swipeDown()
        shot("I7_share_smoke_light")
        app.swipeUp()
        id("share.smoke.strong")
        app.swipeDown()
        shot("I7_share_smoke_heavy")
        let pic = element("share.photo")
        if pic.waitForExistence(timeout: 3) {
            let from = pic.coordinate(withNormalizedOffset: CGVector(dx: 0.45, dy: 0.62))
            let to = pic.coordinate(withNormalizedOffset: CGVector(dx: 0.80, dy: 0.22))
            from.press(forDuration: 0.15, thenDragTo: to, withVelocity: .slow, thenHoldForDuration: 0.2)
            sleep(1)
            shot("I7_share_smoke_time_moved")
        }
        app.swipeUp()
        id("share.text.black")
        app.swipeDown()
        shot("I7_share_smoke_black_text")
        app.swipeUp()
        id("share.smoke.off")
        id("share.text.white")
        app.swipeDown()
        shot("I7_share_gradient_time_moved")
        id("nav.left")
    }

    // MARK: 6. 아이폰으로 기록: 3 · 2 · 1 → 진행 → 넘기기 → 되돌리기

    func test6_phone_live() {
        launch(onboarded: true)
        tab("Test")
        let startBtn = element("startOnPhone.pft")
        if startBtn.waitForExistence(timeout: 3) && !startBtn.isHittable { app.swipeUp() }
        id("startOnPhone.pft")
        tap("Start")                       // 확인창
        shotNow("L1_countdown")
        sleep(4)
        shot("L2_live_started")
        id("phone.next")
        shot("L3_after_next")
        id("phone.undo")
        shot("L4_after_undo")
        id("phone.end")
        shot("L5_end_alert")
        tap("Discard")
        shot("L6_back")
    }

    // MARK: 5. PFT — Test 탭 · 기록 화면 · 설명 · 처음 화면

    func test5_pft() {
        launch(onboarded: true)
        tab("Test")
        shot("P1_pft_with_records")
        app.swipeUp()
        shot("P1_pft_history")
        tapContaining("21:48")
        shot("P2_pft_result")
        app.swipeUp()
        shot("P2_pft_result_splits")
        app.swipeDown(); app.swipeDown()
        back()
        app.swipeDown(); app.swipeDown()
        id("pft.info")
        shot("P3_pft_info")
        id("nav.left")
        id("test.seg.sim")
        id("sim.info")
        shot("P3_sim_info")
        id("nav.left")
        tab("Home")
        shot("P4_home_badge")
        app.swipeUp()
        shot("P4_home_modes")

        // 기록이 하나도 없을 때 (처음 화면)
        app.terminate()
        launch(onboarded: true, extra: ["--nopft"])
        tab("Test")
        shot("P5_pft_first_time")
        app.swipeUp()
        shot("P5_pft_first_time_bottom")
    }

    // MARK: 4. 카드를 밀다 말았을 때 — 만들기 화면이 잘못 열려도 Cancel · Save 가 눌리는지

    private var cardButton: XCUIElement {
        app.buttons.containing(NSPredicate(format: "label CONTAINS %@", "Sled Intervals")).firstMatch
    }

    /// 만들기 화면이 열려 있으면 Cancel 을 눌러 트레이닝 목록으로 돌아오는지 확인
    private func leaveBuilderIfOpen(_ why: String) {
        let cancel = app.buttons["nav.left"]
        guard cancel.waitForExistence(timeout: 2) else { return }
        shot("S_builder_opened_" + why)
        cancel.tap()
        sleep(1)
        XCTAssertTrue(app.buttons["training.new"].waitForExistence(timeout: 3), "Cancel 이 안 눌림 (" + why + ")")
        shot("S_after_cancel_" + why)
    }

    func test4_swipe_then_builder() {
        launch(onboarded: true)
        tab("Training")
        XCTAssertTrue(cardButton.waitForExistence(timeout: 5))

        // 1) 천천히 조금만 왼쪽으로 밀다 놓기
        var a = cardButton.coordinate(withNormalizedOffset: CGVector(dx: 0.80, dy: 0.5))
        var b = cardButton.coordinate(withNormalizedOffset: CGVector(dx: 0.62, dy: 0.5))
        a.press(forDuration: 0.2, thenDragTo: b, withVelocity: .slow, thenHoldForDuration: 0.2)
        shot("S_slow_short_swipe")
        leaveBuilderIfOpen("slow_short")

        // 2) 비스듬히(왼쪽 + 아래) 밀다 놓기
        a = cardButton.coordinate(withNormalizedOffset: CGVector(dx: 0.80, dy: 0.3))
        b = cardButton.coordinate(withNormalizedOffset: CGVector(dx: 0.60, dy: 0.7))
        a.press(forDuration: 0.1, thenDragTo: b, withVelocity: .slow, thenHoldForDuration: 0.1)
        shot("S_diagonal_swipe")
        leaveBuilderIfOpen("diagonal")

        // 3) 빠르게 절반쯤 밀기 (Delete 가 열린 채 남음) → 카드 눌러 닫기
        a = cardButton.coordinate(withNormalizedOffset: CGVector(dx: 0.85, dy: 0.5))
        b = cardButton.coordinate(withNormalizedOffset: CGVector(dx: 0.45, dy: 0.5))
        a.press(forDuration: 0.05, thenDragTo: b, withVelocity: .fast, thenHoldForDuration: 0.05)
        shot("S_half_swipe_open")
        leaveBuilderIfOpen("half")
        cardButton.coordinate(withNormalizedOffset: CGVector(dx: 0.3, dy: 0.5)).tap()
        sleep(1)
        shot("S_after_tap_to_close")
        leaveBuilderIfOpen("tap_close")

        // 4) 그 뒤 카드를 눌러 만들기 화면 → 아래로 스크롤 → Cancel / Save
        cardButton.coordinate(withNormalizedOffset: CGVector(dx: 0.3, dy: 0.5)).tap()
        sleep(1)
        XCTAssertTrue(app.buttons["nav.left"].waitForExistence(timeout: 3), "만들기 화면이 안 열림")
        app.swipeUp()
        shot("S_builder_scrolled")
        app.buttons["nav.right"].tap()          // Save
        sleep(1)
        XCTAssertTrue(app.buttons["training.new"].waitForExistence(timeout: 3), "Save 가 안 눌림")
        shot("S_after_save")
    }
}
