import Foundation
import WatchConnectivity
import Observation
import UIKit
import UserNotifications

/// 아이폰 저장소: 설정·프로그램·기록·친구 + 워치 동기화 + 계정(선택)
@Observable
final class Store: NSObject, WCSessionDelegate {
    static let shared = Store()

    var settings = Settings() { didSet { persist("settings") } }
    var programs: [Program] = [] { didSet { persist("programs") } }
    private(set) var records: [Record] = []
    var friends: [Friend] = [] { didSet { persist("friends") } }
    /// 달력에 예약한 운동 (이 기기에만 저장, 워치로는 안 보냄)
    var plans: [PlannedWorkout] = [] { didSet { savePlans() } }
    var events: [EventItem] = EventItem.bundled

    /// 프로필 사진 (320px 정사각 JPEG, 이 기기에 저장)
    var photo: UIImage?
    var avatarUrl: String?

    /// 서버에서 받은 순위표 · 친구 요청 상태
    var leaderboard: [LBRow] = []
    var requested: Set<String> = []
    var lastError: String?

    private(set) var watchPaired = false
    private(set) var watchInstalled = false
    private(set) var watchReachable = false

    @ObservationIgnored private var loading = true
    @ObservationIgnored let sb = Supabase.shared

    override init() {
        super.init()
        settings = JSONStore.load(Settings.self, "settings.json") ?? Settings()
        programs = JSONStore.load([Program].self, "programs.json") ?? Program.presets()
        records = JSONStore.load([Record].self, "records.json") ?? []
        friends = JSONStore.load([Friend].self, "friends.json") ?? []
        plans = JSONStore.load([PlannedWorkout].self, "plans.json") ?? []
        // 빌드 10~12 에서 넣었던 부분 시뮬 프리셋(전반부·후반부)을 한 번만 지움
        let cleanKey = "removed.halfPresets.v1"
        if !UserDefaults.standard.bool(forKey: cleanKey) {
            let before: Int = programs.count
            programs.removeAll { $0.id.hasPrefix("preset.") }
            if programs.count != before { JSONStore.save(programs, "programs.json") }
            UserDefaults.standard.set(true, forKey: cleanKey)
        }
        if let d = try? Data(contentsOf: JSONStore.url("avatar.jpg")) { photo = UIImage(data: d) }
        if Demo.enabled {           // 화면 확인용 예시 데이터
            var s = Settings(); Demo.settings(&s); settings = s
            programs = Demo.programs()
            records = Demo.records()
            friends = []
            plans = []
        }
        if sb.session == nil && settings.nickname != nil { settings.nickname = nil }   // 세션이 없으면 로그아웃 상태
        loading = false
    }

    var div: Division { settings.div }
    var friend: Friend? { friends.first { $0.id == settings.friendId } }
    var signedIn: Bool { settings.signedIn && sb.session != nil }

    private func persist(_ what: String) {
        guard !loading, !Demo.enabled else { return }
        switch what {
        case "settings": JSONStore.save(settings, "settings.json")
        case "programs": JSONStore.save(programs, "programs.json")
        case "friends": JSONStore.save(friends, "friends.json")
        default: break
        }
        pushToWatch()
    }

    // MARK: 운동 예약 + 미리 알림

    private func savePlans() {
        guard !loading, !Demo.enabled else { return }
        JSONStore.save(plans, "plans.json")
    }

    /// 예약 추가·수정 (같은 id면 바꿈). 알림도 다시 잡음.
    func savePlan(_ p: PlannedWorkout) {
        if let i = plans.firstIndex(where: { $0.id == p.id }) { plans[i] = p } else { plans.append(p) }
        plans.sort { $0.date < $1.date }
        schedule(p)
    }

    func deletePlan(_ id: UUID) {
        plans.removeAll { $0.id == id }
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [id.uuidString])
    }

    /// 앞으로 남은 예약 (오늘 이후)
    var upcomingPlans: [PlannedWorkout] {
        let start: Date = Calendar.current.startOfDay(for: Date())
        return plans.filter { $0.date >= start }.sorted { $0.date < $1.date }
    }

    func plans(on day: Date) -> [PlannedWorkout] {
        plans.filter { Calendar.current.isDate($0.date, inSameDayAs: day) }
    }

    func records(on day: Date, mode: Mode? = nil) -> [Record] {
        records.filter { Calendar.current.isDate($0.date, inSameDayAs: day) && (mode == nil || $0.mode == mode!) }
            .sorted { $0.date > $1.date }
    }

    /// 알림 시각: 1시간 전 / 전날 오후 8시 / 일주일 전 같은 시각
    static func reminderDate(_ date: Date, _ r: PlanReminder) -> Date? {
        let cal = Calendar.current
        switch r {
        case .none: return nil
        case .hourBefore: return date.addingTimeInterval(-3600)
        case .dayBefore:
            guard let prev = cal.date(byAdding: .day, value: -1, to: date) else { return nil }
            return cal.date(bySettingHour: 20, minute: 0, second: 0, of: prev)
        case .weekBefore: return cal.date(byAdding: .day, value: -7, to: date)
        }
    }

    /// 알림 권한을 (처음이면) 묻고, 예약 알림을 잡음
    func schedule(_ p: PlannedWorkout) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [p.id.uuidString])
        guard let fire = Store.reminderDate(p.date, p.reminder), fire > Date() else { return }
        center.requestAuthorization(options: [.alert, .sound, .badge]) { ok, _ in
            guard ok else { return }
            let c = UNMutableNotificationContent()
            c.title = p.title.l10n
            c.body = Store.reminderBody(p)
            c.sound = .default
            let comps: DateComponents = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: fire)
            let trig = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
            center.add(UNNotificationRequest(identifier: p.id.uuidString, content: c, trigger: trig))
        }
    }

    static func reminderBody(_ p: PlannedWorkout) -> String {
        let f = DateFormatter()
        f.locale = Fm.isKorean ? Locale(identifier: "ko_KR") : Fm.gb
        f.setLocalizedDateFormatFromTemplate("EEEMMMdjmm")
        return f.string(from: p.date)
    }

    /// 등록한 대회 알림 (대회 일주일 전 · 전날). 대회를 바꾸면 다시 잡음.
    func scheduleRaceReminders() {
        let center = UNUserNotificationCenter.current()
        let ids: [String] = ["race.week", "race.day"]
        center.removePendingNotificationRequests(withIdentifiers: ids)
        let ev = settings.event
        guard ev.isSet else { return }
        let pairs: [(String, PlanReminder)] = [("race.week", .weekBefore), ("race.day", .dayBefore)]
        center.requestAuthorization(options: [.alert, .sound, .badge]) { ok, _ in
            guard ok else { return }
            for (id, r) in pairs {
                guard let fire = Store.reminderDate(ev.date, r), fire > Date() else { continue }
                let c = UNMutableNotificationContent()
                c.title = ev.name
                c.body = r == .weekBefore ? "D-7" : "D-1"
                c.sound = .default
                let comps: DateComponents = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: fire)
                center.add(UNNotificationRequest(identifier: id, content: c,
                                                 trigger: UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)))
            }
        }
    }

    /// 워치 없이 아이폰으로 기록한 운동 저장
    func addPhoneRecord(_ r: Record) {
        var x = r
        x.source = "phone"
        add(x)
    }

    // MARK: 기록

    func records(_ m: Mode) -> [Record] { records.filter { $0.mode == m }.sorted { $0.date > $1.date } }

    func add(_ r: Record) {
        guard !records.contains(where: { $0.id == r.id }) else { return }
        records.append(r)
        if !Demo.enabled { JSONStore.save(records, "records.json") }
        pushToWatch()
        if signedIn { Task { try? await sb.upload(r) } }
    }

    /// 기록의 더블 파트너 바꾸기 (nil = 빼기). 이 기기에만 저장.
    func updatePartner(_ id: UUID, _ nick: String?) {
        guard let i = records.firstIndex(where: { $0.id == id }) else { return }
        records[i].partner = nick
        if !Demo.enabled { JSONStore.save(records, "records.json") }
    }

    func delete(_ r: Record) {
        records.removeAll { $0.id == r.id }
        if !Demo.enabled { JSONStore.save(records, "records.json") }
        pushToWatch()
        if signedIn { Task { try? await sb.deleteRecord(r.id) } }
    }

    /// 최고 Full Simulation
    /// (미완료·확인 필요 기록은 빼고)
    var simBest: Record? { records(.sim).filter { $0.counts && $0.splits16 != nil }.min { $0.total < $1.total } }
    var raceBest: Record? { records(.race).filter(\.counts).min { $0.total < $1.total } }
    /// 최고 PFT (끝까지 한 정상 기록 중 가장 빠른 것) — 홈 프로필 뱃지는 이 기록의 등급
    var pftBest: Record? { records(.pft).filter { $0.counts && $0.pftSplits != nil }.min { $0.total < $1.total } }
    var pftGrade: PFTGrade? { pftBest?.pftGrade }

    /// ★ PB: 같은 종류(트레이닝은 같은 이름·세트 수, Full Sim·Race는 각각 전체) 중 가장 빠른 기록.
    /// 비교할 기록이 2개 이상일 때만 표시 (하나뿐이면 PB 표시 없음). 저장·삭제하면 자동으로 다시 계산됨.
    func isPB(_ r: Record) -> Bool {
        guard r.counts, !r.isHIIT else { return false }      // HIIT 는 PB 없음
        let same: [Record] = pbGroup(r)
        guard same.count >= 2, let best = same.min(by: { $0.total < $1.total }) else { return false }
        return best.id == r.id
    }
    private func pbGroup(_ r: Record) -> [Record] {
        switch r.mode {
        case .training: return records(.training).filter { $0.counts && $0.title == r.title && $0.sets == r.sets }
        case .sim: return records(.sim).filter { $0.counts && $0.splits16 != nil }
        case .race: return records(.race).filter(\.counts)
        case .pft: return records(.pft).filter { $0.counts && $0.pftSplits != nil }
        }
    }

    /// 트레이닝 구간별 최고
    var segBests: [String: Int] {
        var b: [String: Int] = [:]
        for r in records where r.mode == .training && r.counts {
            for s in r.segs {
                let k = SegKey.of(icon: s.icon, detail: s.detail)
                b[k] = min(b[k] ?? .max, s.time)
            }
        }
        return b
    }

    /// 같은 프로그램 이전 최고 (VS BEST)
    func previousBest(for r: Record) -> Int? {
        records.filter { $0.mode == r.mode && $0.title == r.title && $0.id != r.id && $0.date < r.date && $0.counts }.map(\.total).min()
    }
    /// 바로 이전 기록 (VS LAST)
    func previous(for r: Record) -> Record? {
        records.filter { $0.mode == r.mode && $0.date < r.date && $0.counts }.max { $0.date < $1.date }
    }

    // MARK: 프로그램

    func save(_ p: Program) {
        if let i = programs.firstIndex(where: { $0.id == p.id }) { programs[i] = p } else { programs.insert(p, at: 0) }
    }
    func deleteProgram(_ id: String) { programs.removeAll { $0.id == id } }

    // MARK: 친구 선택

    func toggleFriend(_ f: Friend) {
        var s = settings
        let on = s.friendId == f.id
        s.friendId = on ? nil : f.id
        if on && s.simCmp == "friend" { s.simCmp = "goal" }
        if on { s.tgtSrc = "mine" }
        settings = s
    }

    // MARK: 차단 (다른 사용자를 내 화면에서 숨김)

    func isBlocked(_ id: String) -> Bool { settings.blocked.contains { $0.id == id } }

    /// 차단: 이 기기의 차단 목록에 넣고, 친구 목록 · 순위표에서 바로 빼고, 서버의 친구 관계도 끊음
    func block(id: String, name: String) {
        var s = settings
        if !s.blocked.contains(where: { $0.id == id }) { s.blocked = s.blocked + [BlockedUser(id: id, name: name)] }
        if s.friendId == id {
            s.friendId = nil
            if s.simCmp == "friend" { s.simCmp = "goal" }
            s.tgtSrc = "mine"
        }
        settings = s
        friends.removeAll { $0.id == id }
        leaderboard.removeAll { $0.user_id == id }
        requested.remove(id)
        if signedIn { Task { try? await sb.removeFriend(id) } }
    }

    func unblock(_ id: String) {
        var s = settings
        s.blocked = s.blocked.filter { $0.id != id }
        settings = s
    }

    // MARK: 프로필 사진

    func setPhoto(_ img: UIImage?) {
        photo = img
        let url = JSONStore.url("avatar.jpg")
        if let img, let d = img.jpegData(compressionQuality: 0.85) {
            try? d.write(to: url, options: .atomic)
            if signedIn { Task { await syncAvatar(d) } }
        } else {
            try? FileManager.default.removeItem(at: url)
            avatarUrl = nil
            if signedIn { Task { await syncProfile() } }
        }
    }

    /// 가운데 정사각형으로 잘라 320px
    /// 가운데 정사각형으로 잘라 720px 로 (눌러서 크게 봐도 선명, 용량은 작게)
    static func squarePhoto(_ img: UIImage) -> UIImage {
        let side: CGFloat = 720
        let s = min(img.size.width, img.size.height)
        let o = CGPoint(x: (img.size.width - s) / 2, y: (img.size.height - s) / 2)
        let r = UIGraphicsImageRenderer(size: CGSize(width: side, height: side), format: { let f = UIGraphicsImageRendererFormat(); f.scale = 1; return f }())
        return r.image { _ in
            img.draw(in: CGRect(x: -o.x * side / s, y: -o.y * side / s, width: img.size.width * side / s, height: img.size.height * side / s))
        }
    }

    // MARK: 계정 (Supabase)

    /// 로그인 끝난 뒤: 프로필 읽기. 닉네임이 있으면 바로 로그인 상태, 없으면 nil 반환 (닉네임 만들기로)
    @discardableResult
    func loadProfile() async -> RemoteProfile? {
        guard let p = try? await sb.myProfile() else { return nil }
        if let n = p.nickname {
            var s = settings
            s.nickname = n
            s.email = sb.session?.email ?? s.email
            s.visibility = p.visibility ?? s.visibility
            settings = s
            avatarUrl = p.avatar_url
            await refreshSocial()
        }
        return p
    }

    /// 닉네임 저장 (가입 마무리 · 변경)
    func saveNickname(_ n: String) async throws {
        try await sb.upsertProfile(nickname: n, division: div.name, visibility: settings.visibility, avatarUrl: avatarUrl)
        var s = settings
        s.nickname = n
        s.email = sb.session?.email ?? s.email
        settings = s
        if let d = photo?.jpegData(compressionQuality: 0.85), avatarUrl == nil { await syncAvatar(d) }
        for r in records { try? await sb.upload(r) }
        await refreshSocial()
    }

    func syncProfile() async {
        guard signedIn else { return }
        try? await sb.upsertProfile(nickname: nil, division: div.name, visibility: settings.visibility, avatarUrl: avatarUrl)
    }

    private func syncAvatar(_ d: Data) async {
        if let u = try? await sb.uploadAvatar(d) { avatarUrl = u; await syncProfile() }
    }

    /// 친구 목록 · 순위표 · 대회 목록 새로 받기
    func refreshSocial() async {
        guard signedIn else { return }
        if let rows = try? await sb.friends() {
            let sel = settings.friendId
            friends = rows.filter { ($0.status == "accepted" || $0.status == "pending") && !isBlocked($0.user_id) }.map {
                Friend(id: $0.user_id, name: $0.nickname, div: $0.division, date: $0.best_date ?? "",
                       splits: $0.splits ?? [], avatarUrl: $0.avatar_url)
            }
            if let sel, !friends.contains(where: { $0.id == sel }) { settings.friendId = nil }
        }
        await refreshLeaderboard()
    }

    func refreshLeaderboard() async {
        guard signedIn else { leaderboard = []; return }
        let kind = settings.lbTab == "stations" ? "station" : settings.lbTab
        let st = Station.all.firstIndex { $0.key == settings.lbStation } ?? 0
        if let rows = try? await sb.leaderboard(kind: kind, station: st, division: settings.lbAllDivisions ? nil : div.name) {
            leaderboard = rows.filter { !isBlocked($0.user_id) }
        }
    }

    func refreshEvents() async {
        if let e = try? await sb.events(), !e.isEmpty { events = e }
    }

    func signOut() async {
        await sb.signOut()
        var s = settings
        s.nickname = nil; s.email = nil; s.signMethod = nil
        settings = s
        leaderboard = []
        friends = []
        requested = []
    }

    func deleteAccount() async {
        try? await sb.deleteAccount()
        await signOut()
    }

    // MARK: 워치

    func activate() {
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    func pushToWatch() {
        guard WCSession.isSupported(), WCSession.default.activationState == .activated else { return }
        let best = simBest
        let pft = pftBest
        let ctx = WatchContext(settings: settings, programs: programs, friend: friend?.hasSplits == true ? friend : nil,
                               simBest: best?.splits16, simBestTotal: best?.total, segBests: segBests,
                               pftBest: pft?.pftSplits, pftBestTotal: pft?.total)
        guard let d = try? JSONStore.enc.encode(ctx) else { return }
        try? WCSession.default.updateApplicationContext([SyncKey.context: d])
    }

    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        DispatchQueue.main.async { self.status(session); self.pushToWatch() }
    }
    func sessionDidBecomeInactive(_ session: WCSession) {}
    func sessionDidDeactivate(_ session: WCSession) { WCSession.default.activate() }
    func sessionWatchStateDidChange(_ session: WCSession) { DispatchQueue.main.async { self.status(session) } }
    func sessionReachabilityDidChange(_ session: WCSession) { DispatchQueue.main.async { self.status(session) } }

    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
        if let d = userInfo[SyncKey.record] as? Data, let r = try? JSONStore.dec.decode(Record.self, from: d) {
            DispatchQueue.main.async { self.add(r) }
        }
        if let d = userInfo[SyncKey.quick] as? Data, let p = try? JSONStore.dec.decode(Program.self, from: d) {
            DispatchQueue.main.async { if !self.programs.contains(where: { $0.id == p.id }) { self.programs.insert(p, at: 0) } }
        }
    }

    private func status(_ s: WCSession) {
        watchPaired = s.isPaired
        watchInstalled = s.isWatchAppInstalled
        watchReachable = s.isReachable
    }
}
