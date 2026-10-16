import Foundation

// MARK: - 더블 계획 (빌드 27 · 번갈아 하기)

/// 더블에서 스테이션 8개를 파트너와 "몇 m(개)씩 번갈아 할지, 누가 먼저 할지" 적어 두는 계획.
/// 스테이션마다 chunk(한 번에 하는 양)와 meFirst(내가 먼저 하는지)를 가짐. 러닝은 둘이 같이 뛰므로 나누지 않음.
/// 예전(빌드 23) 저장 파일에는 shares(몫 %)만 있음 → 읽을 때 무시하고 기본값으로 채움.
/// 워치에서도 쓰므로 Shared 에 둠.
struct DoublesPlan: Codable, Hashable {
    /// 경기 순서대로 스테이션마다 한 번에 하는 양 (m 또는 개)
    var chunks: [Double] = DoublesPlan.defaultChunks
    /// 경기 순서대로 스테이션마다 내가 먼저 하는지
    var firsts: [Bool] = Array(repeating: true, count: 8)
    /// 파트너 이름 (비어 있으면 "Partner")
    var partnerName: String? = nil
    /// 친구 목록에서 고른 파트너의 user id (직접 적었으면 nil)
    var partnerId: String? = nil

    init() {}

    private enum CodingKeys: String, CodingKey {
        case chunks, firsts, partnerName, partnerId
    }

    /// 예전 파일 · 이상한 값도 안전하게 읽음 (없거나 틀리면 기본값)
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let chOpt: [Double]? = try? c.decodeIfPresent([Double].self, forKey: .chunks)
        let fsOpt: [Bool]? = try? c.decodeIfPresent([Bool].self, forKey: .firsts)
        let pnOpt: String? = try? c.decodeIfPresent(String.self, forKey: .partnerName)
        let idOpt: String? = try? c.decodeIfPresent(String.self, forKey: .partnerId)
        let ch: [Double] = chOpt ?? []
        let fs: [Bool] = fsOpt ?? []
        var plan = DoublesPlan()
        for i in 0..<8 {
            if ch.indices.contains(i) { plan.setChunk(i, ch[i]) }
            if fs.indices.contains(i) { plan.setMeFirst(i, fs[i]) }
        }
        plan.partnerName = DoublesPlan.cleanName(pnOpt)
        plan.partnerId = idOpt
        self = plan
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode((0..<8).map { chunk($0) }, forKey: .chunks)
        try c.encode((0..<8).map { meFirst($0) }, forKey: .firsts)
        try c.encodeIfPresent(partnerName, forKey: .partnerName)
        try c.encodeIfPresent(partnerId, forKey: .partnerId)
    }

    // MARK: 스테이션 정보

    /// 스테이션별 전체 양 — Ski 1000 · Push 50 · Pull 50 · BBJ 80 · Row 1000 · FC 200 · Lunges 100 (m) · Wall Balls 100 (개)
    static let totals: [Double] = [1000, 50, 50, 80, 1000, 200, 100, 100]
    /// 스테이션별 고를 수 있는 한 번 양
    static let options: [[Double]] = [
        [100, 150, 200, 250],      // SkiErg
        [12.5],                    // Sled Push (한 바퀴씩)
        [12.5],                    // Sled Pull (한 바퀴씩)
        [10, 20, 40],              // BBJ
        [100, 150, 200, 250],      // Row
        [50, 100],                 // Farmers Carry
        [25, 50],                  // Lunges
        [10, 15, 20, 25],          // Wall Balls (개)
    ]
    static let defaultChunks: [Double] = [250, 12.5, 12.5, 20, 250, 50, 25, 20]

    /// 월볼(마지막)만 개수, 나머지는 미터
    static func isReps(_ i: Int) -> Bool { i == 7 }
    /// 썰매처럼 한 가지 양만 있는 스테이션 (한 바퀴씩)
    static func isFixed(_ i: Int) -> Bool { options.indices.contains(i) && options[i].count == 1 }
    static func total(_ i: Int) -> Double { totals.indices.contains(i) ? totals[i] : 100 }

    // MARK: 읽기 · 쓰기

    /// i번째 스테이션의 한 번 양 (고를 수 없는 값이면 기본값)
    func chunk(_ i: Int) -> Double {
        guard (0..<8).contains(i) else { return 10 }
        if chunks.indices.contains(i), Self.options[i].contains(chunks[i]) { return chunks[i] }
        return Self.defaultChunks[i]
    }
    func meFirst(_ i: Int) -> Bool { firsts.indices.contains(i) ? firsts[i] : true }

    mutating func setChunk(_ i: Int, _ v: Double) {
        guard (0..<8).contains(i), Self.options[i].contains(v) else { return }
        if chunks.count < 8 { chunks += Self.defaultChunks.suffix(8 - chunks.count) }
        chunks[i] = v
    }
    mutating func setMeFirst(_ i: Int, _ v: Bool) {
        guard (0..<8).contains(i) else { return }
        if firsts.count < 8 { firsts += Array(repeating: true, count: 8 - firsts.count) }
        firsts[i] = v
    }

    /// 기본 계획 그대로인지 (양 · 순서 · 파트너 모두 기본)
    var isDefault: Bool {
        (0..<8).allSatisfy { chunk($0) == Self.defaultChunks[$0] && meFirst($0) } && partnerName == nil && partnerId == nil
    }

    // MARK: 번갈아 하는 순서

    /// i번째 스테이션을 번갈아 하는 순서. 마지막 차례는 남은 양만
    func sequence(_ i: Int) -> [(me: Bool, amount: Double)] {
        let total: Double = Self.total(i)
        let step: Double = max(1, chunk(i))
        var out: [(me: Bool, amount: Double)] = []
        var done: Double = 0
        var me: Bool = meFirst(i)
        while done < total - 0.001 && out.count < 200 {
            let a: Double = min(step, total - done)
            out.append((me: me, amount: a))
            done += a
            me.toggle()
        }
        return out
    }
    /// i번째 스테이션에서 내가 하는 양
    func mine(_ i: Int) -> Double { sequence(i).filter { $0.me }.reduce(0) { $0 + $1.amount } }
    /// i번째 스테이션에서 파트너가 하는 양
    func partners(_ i: Int) -> Double { sequence(i).filter { !$0.me }.reduce(0) { $0 + $1.amount } }
    /// 내 차례 수 · 파트너 차례 수 · 전체 차례 수
    func myTurns(_ i: Int) -> Int { sequence(i).filter { $0.me }.count }
    func partnerTurns(_ i: Int) -> Int { sequence(i).filter { !$0.me }.count }
    func turns(_ i: Int) -> Int { sequence(i).count }

    // MARK: 글자

    /// 파트너 이름 (비었으면 "Partner" 번역)
    var partnerShown: String {
        let n: String = (partnerName ?? "").trimmingCharacters(in: .whitespaces)
        return n.isEmpty ? "Partner".l10n : n
    }

    /// 150 / 12.5 (소수점은 필요할 때만)
    static func num(_ v: Double) -> String {
        if abs(v - v.rounded()) < 0.001 { return String(Int(v.rounded())) }
        return String(format: "%.1f", v)
    }
    /// "150 m" / "20 reps"
    static func amountText(_ i: Int, _ v: Double) -> String {
        isReps(i) ? String(format: "%@ reps".l10n, num(v)) : num(v) + " m"
    }

    /// 이름 정리: 줄바꿈 · 조종 글자를 빼고 20자까지. 비면 nil
    static func cleanName(_ s: String?) -> String? {
        guard let s else { return nil }
        let kept: String = String(s.unicodeScalars.filter {
            !CharacterSet.controlCharacters.contains($0) && !CharacterSet.newlines.contains($0)
        }.map { Character($0) })
        let t: String = String(kept.trimmingCharacters(in: .whitespaces).prefix(20))
        return t.isEmpty ? nil : t
    }

    /// 받은 계획: 보낸 사람 입장의 계획을 내 입장으로 (먼저 하는 사람을 바꾸고 파트너 = 보낸 사람)
    func swapped(sender: String?) -> DoublesPlan {
        var p = self
        for i in 0..<8 { p.setMeFirst(i, !meFirst(i)) }
        p.partnerName = Self.cleanName(sender)
        p.partnerId = nil
        return p
    }
}

// MARK: - 더블 계획 링크

/// 더블 계획을 링크 글자에 담아 보냄 (서버 없이). ProgramLink 와 같은 방식.
/// 앱 주소 = splits8://d?d=token,  홈페이지 = ProgramLink.base + "#" + token,  token = "d1." + base64url(JSON)
/// JSON: {"c": [한 번 양 8개], "f": [먼저 1/0 8개], "n": 보낸 사람 닉네임}
enum DoublesLink {
    static let host = "d"
    static let prefix = "d1."

    private struct Payload: Codable {
        var c: [Double]
        var f: [Int]
        var n: String?
    }

    static func token(_ p: DoublesPlan, sender: String?) -> String? {
        let pay = Payload(c: (0..<8).map { p.chunk($0) }, f: (0..<8).map { p.meFirst($0) ? 1 : 0 },
                          n: DoublesPlan.cleanName(sender))
        let enc = JSONEncoder()
        enc.outputFormatting = [.sortedKeys]
        guard let d = try? enc.encode(pay) else { return nil }
        let b64: String = d.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-").replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: "=", with: "")
        return prefix + b64
    }

    /// 앱 전용 주소 splits8://d?d=token
    static func appURL(_ p: DoublesPlan, sender: String?) -> URL? {
        guard let t = token(p, sender: sender) else { return nil }
        return URL(string: ProgramLink.scheme + "://" + host + "?d=" + t)
    }
    /// 홈페이지 주소 (t.html 이 d1. 글자를 받아 앱으로 넘김)
    static func webURL(_ p: DoublesPlan, sender: String?) -> URL? {
        guard let t = token(p, sender: sender) else { return nil }
        return URL(string: ProgramLink.base + "#" + t)
    }

    /// 받은 글자에서 (보낸 사람 입장의) 계획과 보낸 사람 이름을 꺼냄. 이상한 값이 하나라도 있으면 nil
    static func read(_ token: String) -> (plan: DoublesPlan, sender: String?)? {
        guard token.hasPrefix(prefix), token.count <= 2000 else { return nil }
        var b64: String = String(token.dropFirst(prefix.count))
            .replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
        while b64.count % 4 != 0 { b64 += "=" }
        guard let d = Data(base64Encoded: b64), let pay = try? JSONDecoder().decode(Payload.self, from: d) else { return nil }
        guard pay.c.count == 8, pay.f.count == 8 else { return nil }
        var plan = DoublesPlan()
        for i in 0..<8 {
            guard DoublesPlan.options[i].contains(pay.c[i]), pay.f[i] == 0 || pay.f[i] == 1 else { return nil }
            plan.setChunk(i, pay.c[i])
            plan.setMeFirst(i, pay.f[i] == 1)
        }
        return (plan, DoublesPlan.cleanName(pay.n))
    }

    /// splits8://d?d=token  또는  https://…/t.html#d1.token  에서 token 꺼내기
    static func token(from url: URL) -> String? {
        if url.scheme?.lowercased() == ProgramLink.scheme {
            guard url.host?.lowercased() == host else { return nil }
            let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
            return items.first { $0.name == "d" }?.value
        }
        if let f = url.fragment, f.hasPrefix(prefix) { return f }
        return nil
    }
}
