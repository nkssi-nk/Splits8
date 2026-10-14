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

/// 빌드 23: 본인만 읽고 쓰는 프로필 (profile_private 표 · 친구에게도 안 보임)
struct PrivateProfile: Codable {
    var sex: String? = nil
    var height_cm: Int? = nil
    var weight_kg: Double? = nil
    var birth_year: Int? = nil
    var raced: Bool? = nil
    var race_division: String? = nil
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
    /// 빌드 22 서버: incoming(받은 요청) / outgoing(보낸 요청) / mutual. 예전 서버엔 없음
    var direction: String? = nil
}

/// 받은 응원 한 줄 (빌드 24)
struct CheerRow: Codable, Hashable, Identifiable {
    var id: Int
    var sender: String
    var nickname: String
    var avatar_url: String?
    var kind: String
    var created_at: Date
    var seen: Bool
}

/// 응원 종류 (정해진 것만 — 자유 글 없음). 서버 check 목록과 같아야 함
enum CheerKind: String, CaseIterable, Identifiable {
    case fire, clap, muscle, pb, race, together, go
    var id: String { rawValue }
    var emoji: String {
        switch self {
        case .fire: return "🔥"
        case .clap: return "👏"
        case .muscle: return "💪"
        case .pb: return "🏆"
        case .race: return "🏁"
        case .together: return "🤝"
        case .go: return "⚡️"
        }
    }
    /// 이모지만 보내는 것 (나머지는 문구)
    var isEmoji: Bool { [.fire, .clap, .muscle].contains(self) }
    /// 문구 (번역 키)
    var line: String {
        switch self {
        case .fire, .clap, .muscle: return emoji
        case .pb: return "Nice PB!"
        case .race: return "Good luck at the race!"
        case .together: return "Let's train together"
        case .go: return "You've got this"
        }
    }
}

/// friendships 표 한 줄 (본인과 관련된 줄만 읽힘)
struct FriendLink: Codable {
    var requester: String
    var addressee: String
    var status: String
}

/// 친구 요청 (받은 것 · 보낸 것)
struct FriendReq: Codable, Hashable, Identifiable {
    var id: String
    var name: String
    var div: String
    var avatarUrl: String?
    var incoming: Bool
}

enum SBError: LocalizedError {
    case notConfigured, http(Int, String), noSession, bad
    var errorDescription: String? {
        switch self {
        case .notConfigured: return String(localized: "The server isn't set up yet (Config.swift)")
        case .http(let c, let m): return String(localized: "Server error \(c): \(m)")
        case .noSession: return String(localized: "Please sign in first")
        case .bad: return String(localized: "Couldn't read the server response")
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
        if auth, let t = session?.accessToken { req.setValue("Bearer " + t, forHTTPHeaderField: "Authorization") }
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

    /// 빌드 23: 다른 기기에서 로그인해서 이 기기만 로그아웃할 때.
    /// 서버에 logout 을 보내지 않음 (보통 logout 은 모든 기기의 로그인을 끊어서, 새로 로그인한 기기까지 끊길 수 있음)
    func dropSession() {
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

    /// avatarUrl 이 nil 이면 서버의 사진 주소는 건드리지 않음. 사진을 지울 때만 clearAvatar = true
    /// (빌드 19 까지는 nil 이면 항상 지웠는데, 앱을 다시 켠 뒤에는 주소를 기억하지 못해 공개 범위만 바꿔도 서버 사진이 지워질 수 있었음)
    func upsertProfile(nickname: String?, division: String, visibility: String, avatarUrl: String?,
                       clearAvatar: Bool = false) async throws {
        guard let id = userId else { throw SBError.noSession }
        var b: [String: Any] = ["id": id, "division": division, "visibility": visibility]
        if let nickname { b["nickname"] = nickname }
        if let avatarUrl { b["avatar_url"] = avatarUrl } else if clearAvatar { b["avatar_url"] = NSNull() }
        _ = try await request("/rest/v1/profiles", method: "POST", body: b,
                              headers: ["Prefer": "resolution=merge-duplicates,return=minimal"])
    }

    // MARK: 본인만 보는 프로필 (빌드 23 · supabase/build23_profile.sql)

    /// 서버에 아직 표가 없으면(404) nil
    func myPrivate() async throws -> PrivateProfile? {
        guard let id = userId else { throw SBError.noSession }
        do {
            let d = try await request("/rest/v1/profile_private?id=eq.\(id)&select=sex,height_cm,weight_kg,birth_year,raced,race_division")
            return try decode([PrivateProfile].self, d).first
        } catch SBError.http(404, _) {
            return nil
        }
    }

    /// 값이 nil 이면 서버에서도 비움 (사용자가 지운 값이 남지 않게)
    func upsertPrivate(_ p: PrivateProfile) async throws {
        guard let id = userId else { throw SBError.noSession }
        func v(_ x: Any?) -> Any { x ?? NSNull() }
        let b: [String: Any] = ["id": id,
                                "sex": v(p.sex),
                                "height_cm": v(p.height_cm),
                                "weight_kg": v(p.weight_kg),
                                "birth_year": v(p.birth_year),
                                "raced": v(p.raced),
                                "race_division": v(p.race_division)]
        _ = try await request("/rest/v1/profile_private", method: "POST", body: b,
                              headers: ["Prefer": "resolution=merge-duplicates,return=minimal"])
    }

    // MARK: 한 기기만 로그인 (빌드 23)

    /// 이 기기를 "지금 로그인한 기기"로 서버에 적음 (SQL 함수 claim_device)
    func claimDevice(_ dev: String) async throws {
        _ = try await request("/rest/v1/rpc/claim_device", method: "POST", body: ["dev": dev])
    }

    /// 서버에 적힌 "지금 로그인한 기기" (없으면 nil)
    func activeDevice() async throws -> String? {
        let d = try await request("/rest/v1/rpc/active_device", method: "POST", body: [:])
        let v = try? JSONSerialization.jsonObject(with: d, options: [.fragmentsAllowed])
        return v as? String
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

    /// 친구 찾기: 이메일 전체 또는 닉네임 전체가 정확히 맞는 한 사람만 (앞 글자만으로 찾는 건 없앰 — 모르는 사람이 훑어볼 수 없게).
    /// 서버 함수 find_user 를 씀. 아직 서버에 그 함수가 없으면(404) 닉네임이 정확히 같은 사람만 찾음
    func findUser(_ query: String) async throws -> RemoteProfile? {
        let q: String = query.trimmingCharacters(in: .whitespaces).lowercased()
        guard !q.isEmpty else { return nil }
        do {
            let d = try await request("/rest/v1/rpc/find_user", method: "POST", body: ["q": q])
            return try decode([RemoteProfile].self, d).first
        } catch SBError.http(404, _) {
            guard q.range(of: "^[a-z0-9_]{3,16}$", options: .regularExpression) != nil else { return nil }
            let d = try await request("/rest/v1/profiles?nickname=eq.\(q)&select=id,nickname,division,avatar_url&limit=1")
            return try decode([RemoteProfile].self, d).first
        }
    }

    func addFriend(_ otherId: String) async throws {
        _ = try await request("/rest/v1/rpc/add_friend", method: "POST", body: ["other": otherId])
    }

    /// 받은 요청에 답하기. 빌드 22 서버 함수 respond_friend 가 아직 없으면(404)
    /// 수락 = add_friend(서로 추가하면 바로 친구), 거절 = 줄 지우기
    func respondFriend(_ otherId: String, accept: Bool) async throws {
        do {
            _ = try await request("/rest/v1/rpc/respond_friend", method: "POST", body: ["other": otherId, "accept": accept])
        } catch SBError.http(404, _) {
            if accept { try await addFriend(otherId) } else { try await removeFriend(otherId) }
        }
    }

    /// 나와 관련된 친구 줄 (누가 누구에게 요청했는지 알기 위해)
    func friendLinks() async throws -> [FriendLink] {
        let d = try await request("/rest/v1/friendships?select=requester,addressee,status")
        return try decode([FriendLink].self, d)
    }

    /// 친구 끊기 (차단할 때): 두 사람 사이의 친구·요청 줄을 양쪽 방향 모두 지움 (서버 삭제 규칙: 당사자만)
    func removeFriend(_ otherId: String) async throws {
        guard let me = userId else { throw SBError.noSession }
        _ = try await request("/rest/v1/friendships?requester=eq.\(me)&addressee=eq.\(otherId)", method: "DELETE",
                              headers: ["Prefer": "return=minimal"])
        _ = try await request("/rest/v1/friendships?requester=eq.\(otherId)&addressee=eq.\(me)", method: "DELETE",
                              headers: ["Prefer": "return=minimal"])
    }

    // MARK: 빌드 24 · 응원 (supabase/build24_cheers.sql)

    func sendCheer(to otherId: String, kind: String) async throws {
        _ = try await request("/rest/v1/rpc/send_cheer", method: "POST", body: ["other": otherId, "kind": kind])
    }

    /// 받은 응원 최근 50개
    func cheers() async throws -> [CheerRow] {
        let d = try await request("/rest/v1/rpc/my_cheers", method: "POST", body: [:])
        let dec = JSONDecoder()
        dec.dateDecodingStrategy = .custom { c in
            // Postgres 는 "2026-10-14T06:30:12.123456+00:00" 처럼 소수점 6자리 → 소수점 부분을 떼고 읽음
            let raw = try c.singleValueContainer().decode(String.self)
            let s: String = raw.replacingOccurrences(of: "\\.[0-9]+", with: "", options: .regularExpression)
            let f = ISO8601DateFormatter()
            f.formatOptions = [.withInternetDateTime]
            return f.date(from: s) ?? Date()
        }
        do { return try dec.decode([CheerRow].self, from: d) } catch { throw SBError.bad }
    }

    func markCheersSeen() async throws {
        _ = try await request("/rest/v1/rpc/mark_cheers_seen", method: "POST", body: [:])
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

    /// 미완료·확인 필요 기록은 서버(친구 비교·순위표)에 안 올림
    func upload(_ r: Record) async throws {
        guard let id = userId else { throw SBError.noSession }
        guard r.counts else { return }
        guard r.mode != .pft else { return }      // PFT 기록은 아직 이 기기에만 (서버 표가 training·sim·race 만 받음)
        var b: [String: Any] = ["id": r.id.uuidString.lowercased(), "user_id": id, "mode": r.mode.rawValue,
                                "date": Fm.ymd.string(from: r.date), "total_s": r.total, "rox_s": r.roxTotal,
                                "division": r.division]
        b["splits"] = r.splits16 ?? NSNull()
        _ = try await request("/rest/v1/records", method: "POST", body: b,
                              headers: ["Prefer": "resolution=merge-duplicates,return=minimal"])
    }

    func deleteRecord(_ id: UUID) async throws {
        _ = try await request("/rest/v1/records?id=eq." + id.uuidString.lowercased(), method: "DELETE",
                              headers: ["Prefer": "return=minimal"])
    }

    // MARK: 대회

    func events() async throws -> [EventItem] {
        struct Row: Codable { var city: String; var venue: String; var region: String; var start_date: String; var end_date: String }
        let d = try await request("/rest/v1/events?select=city,venue,region,start_date,end_date&order=start_date", auth: false)
        return try decode([Row].self, d).map { EventItem(city: $0.city, venue: $0.venue, region: $0.region, start: $0.start_date, end: $0.end_date) }
    }
}
