import Foundation

// MARK: - Supabase (REST · 별도 라이브러리 없이 URLSession 으로)

struct Session: Codable {
    var accessToken: String
    var refreshToken: String
    var userId: String
    var email: String?
    var expiresAt: Date
}

struct RemoteProfile: Codable {
    var id: String
    var nickname: String?
    var division: String?
    var avatar_url: String?
    var visibility: String?
}

struct LBRow: Codable, Identifiable {
    var user_id: String
    var nickname: String
    var division: String
    var avatar_url: String?
    var t: Int
    var id: String { user_id }
}

struct FriendRow: Codable {
    var user_id: String
    var nickname: String
    var division: String
    var avatar_url: String?
    var best_date: String?
    var splits: [Int]?
    var status: String
}

enum SBError: LocalizedError {
    case notConfigured, http(Int, String), noSession, bad
    var errorDescription: String? {
        switch self {
        case .notConfigured: return "서버 설정이 아직 없어요 (Config.swift)"
        case .http(let c, let m): return "서버 오류 \(c): \(m)"
        case .noSession: return "로그인이 필요해요"
        case .bad: return "응답을 읽을 수 없어요"
        }
    }
}

final class Supabase {
    static let shared = Supabase()
    private let sessionFile = "session.json"
    private(set) var session: Session? {
        didSet { if let s = session { JSONStore.save(s, sessionFile) } else { try? FileManager.default.removeItem(at: JSONStore.url(sessionFile)) } }
    }
    private init() { session = JSONStore.load(Session.self, sessionFile) }

    var isConfigured: Bool { Config.hasSupabase }
    var userId: String? { session?.userId }
    private var base: String { Config.supabaseURL }

    // MARK: 요청

    private func request(_ path: String, method: String = "GET", body: Any? = nil, auth: Bool = true,
                         headers: [String: String] = [:], raw: Data? = nil) async throws -> Data {
        guard isConfigured else { throw SBError.notConfigured }
        if auth { try await refreshIfNeeded() }
        var req = URLRequest(url: URL(string: base + path)!)
        req.httpMethod = method
        req.setValue(Config.supabaseAnonKey, forHTTPHeaderField: "apikey")
        req.setValue("Bearer " + (auth ? (session?.accessToken ?? Config.supabaseAnonKey) : Config.supabaseAnonKey), forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        for (k, v) in headers { req.setValue(v, forHTTPHeaderField: k) }
        if let raw { req.httpBody = raw; req.setValue(headers["Content-Type"] ?? "application/octet-stream", forHTTPHeaderField: "Content-Type") }
        else if let body { req.httpBody = try JSONSerialization.data(withJSONObject: body) }
        let (data, resp) = try await URLSession.shared.data(for: req)
        let code = (resp as? HTTPURLResponse)?.statusCode ?? 0
        guard (200..<300).contains(code) else {
            let msg = (try? JSONSerialization.jsonObject(with: data) as? [String: Any]).flatMap { ($0["msg"] ?? $0["message"] ?? $0["error_description"] ?? $0["error"]) as? String } ?? String(data: data, encoding: .utf8) ?? ""
            throw SBError.http(code, msg)
        }
        return data
    }

    private func decode<T: Decodable>(_ t: T.Type, _ d: Data) throws -> T {
        do { return try JSONDecoder().decode(t, from: d) } catch { throw SBError.bad }
    }

    private func refreshIfNeeded() async throws {
        guard let s = session, s.expiresAt.timeIntervalSinceNow < 60 else { return }
        let d = try await request("/auth/v1/token?grant_type=refresh_token", method: "POST",
                                  body: ["refresh_token": s.refreshToken], auth: false)
        session = try parseSession(d)
    }

    private func parseSession(_ d: Data) throws -> Session {
        guard let j = try JSONSerialization.jsonObject(with: d) as? [String: Any],
              let at = j["access_token"] as? String, let rt = j["refresh_token"] as? String,
              let u = j["user"] as? [String: Any], let id = u["id"] as? String else { throw SBError.bad }
        let exp = (j["expires_in"] as? Double) ?? 3600
        return Session(accessToken: at, refreshToken: rt, userId: id, email: u["email"] as? String, expiresAt: Date().addingTimeInterval(exp))
    }

    // MARK: 로그인

    /// 이메일로 6자리 코드 보내기
    func sendCode(email: String) async throws {
        _ = try await request("/auth/v1/otp", method: "POST", body: ["email": email, "create_user": true], auth: false)
    }

    /// 코드 확인 → 로그인
    func verify(email: String, code: String) async throws {
        let d = try await request("/auth/v1/verify", method: "POST", body: ["type": "email", "email": email, "token": code], auth: false)
        session = try parseSession(d)
    }

    /// Sign in with Apple (identityToken + nonce)
    func signInWithApple(idToken: String, nonce: String) async throws {
        let d = try await request("/auth/v1/token?grant_type=id_token", method: "POST",
                                  body: ["provider": "apple", "id_token": idToken, "nonce": nonce], auth: false)
        session = try parseSession(d)
    }

    func signOut() async {
        _ = try? await request("/auth/v1/logout", method: "POST", body: [:])
        session = nil
    }

    /// 계정 삭제 (SQL 함수 delete_account) — 서버의 프로필·친구·기록이 지워짐
    func deleteAccount() async throws {
        _ = try await request("/rest/v1/rpc/delete_account", method: "POST", body: [:])
        session = nil
    }

    // MARK: 프로필

    func myProfile() async throws -> RemoteProfile? {
        guard let id = userId else { throw SBError.noSession }
        let d = try await request("/rest/v1/profiles?id=eq.\(id)&select=*")
        return try decode([RemoteProfile].self, d).first
    }

    func nicknameAvailable(_ n: String) async throws -> Bool {
        let d = try await request("/rest/v1/rpc/nickname_available", method: "POST", body: ["n": n])
        return (String(data: d, encoding: .utf8) ?? "") == "true"
    }

    func upsertProfile(nickname: String?, division: String, visibility: String, avatarUrl: String?) async throws {
        guard let id = userId else { throw SBError.noSession }
        var b: [String: Any] = ["id": id, "division": division, "visibility": visibility]
        if let nickname { b["nickname"] = nickname }
        if let avatarUrl { b["avatar_url"] = avatarUrl } else { b["avatar_url"] = NSNull() }
        _ = try await request("/rest/v1/profiles", method: "POST", body: b,
                              headers: ["Prefer": "resolution=merge-duplicates,return=minimal"])
    }

    /// 아바타 올리기 → 공개 URL
    func uploadAvatar(_ jpeg: Data) async throws -> String {
        guard let id = userId else { throw SBError.noSession }
        let path = "avatars/\(id).jpg"
        _ = try await request("/storage/v1/object/\(path)", method: "POST",
                              headers: ["Content-Type": "image/jpeg", "x-upsert": "true"], raw: jpeg)
        return base + "/storage/v1/object/public/\(path)?v=\(Int(Date().timeIntervalSince1970))"
    }

    // MARK: 친구

    func searchProfiles(prefix: String) async throws -> [RemoteProfile] {
        let q = prefix.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? prefix
        let d = try await request("/rest/v1/profiles?nickname=like.\(q)*&select=id,nickname,division,avatar_url&limit=5")
        return try decode([RemoteProfile].self, d)
    }

    func addFriend(_ otherId: String) async throws {
        _ = try await request("/rest/v1/rpc/add_friend", method: "POST", body: ["other": otherId])
    }

    /// 친구 + 각자의 최고 Full Simulation (SQL 함수 friends_with_best)
    func friends() async throws -> [FriendRow] {
        let d = try await request("/rest/v1/rpc/friends_with_best", method: "POST", body: [:])
        return try decode([FriendRow].self, d)
    }

    /// 순위표: kind = sim / race / station, station 0…7
    func leaderboard(kind: String, station: Int, division: String?) async throws -> [LBRow] {
        var b: [String: Any] = ["kind": kind, "station": station]
        b["div"] = division ?? NSNull()
        let d = try await request("/rest/v1/rpc/leaderboard", method: "POST", body: b)
        return try decode([LBRow].self, d)
    }

    // MARK: 기록 (요약만 올림 — 심박 원본은 기기에만)

    func upload(_ r: Record) async throws {
        guard let id = userId else { throw SBError.noSession }
        var b: [String: Any] = ["id": r.id.uuidString.lowercased(), "user_id": id, "mode": r.mode.rawValue,
                                "date": Fm.ymd.string(from: r.date), "total_s": r.total, "rox_s": r.roxTotal,
                                "division": r.division]
        b["splits"] = r.splits16 ?? NSNull()
        _ = try await request("/rest/v1/records", method: "POST", body: b,
                              headers: ["Prefer": "resolution=merge-duplicates,return=minimal"])
    }

    // MARK: 대회

    func events() async throws -> [EventItem] {
        struct Row: Codable { var city: String; var venue: String; var region: String; var start_date: String; var end_date: String }
        let d = try await request("/rest/v1/events?select=city,venue,region,start_date,end_date&order=start_date", auth: false)
        return try decode([Row].self, d).map { EventItem(city: $0.city, venue: $0.venue, region: $0.region, start: $0.start_date, end: $0.end_date) }
    }
}
