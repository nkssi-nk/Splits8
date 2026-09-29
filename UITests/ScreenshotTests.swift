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

    private func launch(onboarded: Bool) {
        app = XCUIApplication()
        app.launchArguments = onboarded ? ["--demo", "--onboarded"] : ["--demo"]
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

    // MARK: 1. 처음 실행 (시작 · 온보딩 · 가입)

    func test1_onboarding() {
        launch(onboarded: false)
        shot("I0_launch")
        tap("Sign in")
        shot("I0s_signin")
        back()
        tap("Get started")
        shot("I0a_division")
        tap("Continue")
        shot("I0b_heart_rate")
        tap("Continue")
        shot("I0c_connect_watch")
    }

    // MARK: 2. 탭 4개 + 하위 화면

    func test2_tabs() {
        launch(onboarded: true)
        shot("I1_training")
        tapContaining("Sled Intervals")
        shot("I2_edit_training")
        id("nav.left")
        tap("New training")
        shot("I2_new_training")
        id("nav.right")
        shot("I2_save_sheet")
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.15)).tap()   // 시트 닫기
        id("nav.left")

        tab("Simulation")
        shot("I3_full_simulation")
        tap("WALL BALLS")
        shot("I3_wall_balls")
        app.swipeUp()
        shot("I3_history")

        tab("Race")
        shot("I4_race")
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
        tap("Sign up")
        shot("I0s_create_account")
        back()
        tapContaining("Division")
        shot("I5_division")
        back()
        tapContaining("Age · Max")
        shot("I5c_max_heart_rate")
        back()
        back()
        tapContaining("Running")
        shot("I5_running")
        back()
        tapContaining("Split goals")
        shot("I5b_split_goals")
        back()
        tapContaining("Friends")
        shot("I5f_friends")
        back()
    }

    // MARK: 3. 기록 상세 · 공유

    func test3_detail_share() {
        launch(onboarded: true)
        tab("Race")
        app.swipeUp(); app.swipeUp()
        tapContaining("vs goal")
        shot("I6_detail_top")
        app.swipeUp()
        shot("I6_detail_charts")
        app.swipeUp()
        shot("I6_detail_splits")
        app.swipeDown(); app.swipeDown(); app.swipeDown()
        tap("Share with photo")
        shot("I7_share_poster_story")
        tap("Post 4:5")
        shot("I7_share_poster_post")
        tap("Story 9:16")
        tap("Ticket")
        shot("I7_share_ticket")
        tap("Block")
        shot("I7_share_block")
        id("nav.left")
    }
}
