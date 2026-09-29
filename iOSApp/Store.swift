import Foundation
import WatchConnectivity
import Observation
import UIKit

/// 아이폰 저장소: 설정·프로그램·기록·친구 + 워치 동기화 + 계정(선택)
@Observable
final class Store: NSObject, WCSessionDelegate {
    static let shared = Store()

    var settings = Settings() { didSet { persist("settings") } }
    var programs: [Program] = [] { didSet { persist("programs") } }
    private(set) var records: [Record] = []
    var friends: [Friend] = [] { didSet { persist("friends") } }
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
        if let d = try? Data(contentsOf: JSONStore.url("avatar.jpg")) { photo = UIImage(data: d) }
        if Demo.enabled {           // 화면 확인용 예시 데이터
            var s = Settings(); Demo.settings(&s); settings = s
            programs = Program.presets()
            records = Demo.records()
            friends = []
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

    // MARK: 기록

    func records(_ m: Mode) -> [Record] { records.filter { $0.mode == m }.sorted { $0.date > $1.date } }

    func add(_ r: Record) {
        guard !records.contains(where: { $0.id == r.id }) else { return }
        records.append(r)
        if !Demo.enabled { JSONStore.save(records, "records.json") }
        pushToWatch()
        if signedIn { Task { try? await sb.upload(r) } }
    }

    func delete(_ r: Record) {
        records.removeAll { $0.id == r.id }
        if !Demo.enabled { JSONStore.save(records, "records.json") }
        pushToWatch()
        if signedIn { Task { try? await sb.deleteRecord(r.id) } }
    }

    /// 최고 Full Simulation
    var simBest: Record? { records(.sim).filter { $0.splits16 != nil }.min { $0.total < $1.total } }
    var raceBest: Record? { records(.race).min { $0.total < $1.total } }

    /// 트레이닝 구간별 최고
    var segBests: [String: Int] {
        var b: [String: Int] = [:]
        for r in records where r.mode == .training {
            for s in r.segs {
                let k = SegKey.of(icon: s.icon, detail: s.detail)
                b[k] = min(b[k] ?? .max, s.time)
            }
        }
        return b
    }

    /// 같은 프로그램 이전 최고 (VS BEST)
    func previousBest(for r: Record) -> Int? {
        records.filter { $0.mode == r.mode && $0.title == r.title && $0.id != r.id && $0.date < r.date }.map(\.total).min()
    }
    /// 바로 이전 기록 (VS LAST)
    func previous(for r: Record) -> Record? {
        records.filter { $0.mode == r.mode && $0.date < r.date }.max { $0.date < $1.date }
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
    static func square320(_ img: UIImage) -> UIImage {
        let s = min(img.size.width, img.size.height)
        let o = CGPoint(x: (img.size.width - s) / 2, y: (img.size.height - s) / 2)
        let r = UIGraphicsImageRenderer(size: CGSize(width: 320, height: 320), format: { let f = UIGraphicsImageRendererFormat(); f.scale = 1; return f }())
        return r.image { _ in
            img.draw(in: CGRect(x: -o.x * 320 / s, y: -o.y * 320 / s, width: img.size.width * 320 / s, height: img.size.height * 320 / s))
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
            friends = rows.filter { $0.status == "accepted" || $0.status == "pending" }.map {
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
            leaderboard = rows
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
        let ctx = WatchContext(settings: settings, programs: programs, friend: friend?.hasSplits == true ? friend : nil,
                               simBest: best?.splits16, simBestTotal: best?.total, segBests: segBests)
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
