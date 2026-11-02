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
    /// 1.2.1: 스테이션마다 손으로 고친 차례 양 (고정 줄만. 총량에서 모자란 만큼은 늘 "나머지" 줄로 계산).
    /// nil = 한 번 양(chunk) 방식 그대로. 옛 앱은 이 값을 몰라서 한 번 양 방식으로 보임
    var turns: [[Double]?] = Array(repeating: nil, count: 8)

    init() {}

    private enum CodingKeys: String, CodingKey {
        case chunks, firsts, partnerName, partnerId, turns
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
        // 1.2.1: 차례 목록 — 이상한 값(단위 안 맞음 · 총량 넘음)은 버리고 한 번 양 방식으로
        if let ts: [[Double]?] = try? c.decodeIfPresent([[Double]?].self, forKey: .turns) {
            for i in 0..<min(8, ts.count) { plan.setTurns(i, ts[i]) }
        }
        self = plan
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode((0..<8).map { chunk($0) }, forKey: .chunks)
        try c.encode((0..<8).map { meFirst($0) }, forKey: .firsts)
        try c.encodeIfPresent(partnerName, forKey: .partnerName)
        try c.encodeIfPresent(partnerId, forKey: .partnerId)
        if hasTurns { try c.encode((0..<8).map { turnsRaw($0) }, forKey: .turns) }
    }

    // MARK: 스테이션 정보

    /// 스테이션별 전체 양 — Ski 1000 · Push 50 · Pull 50 · BBJ 80 · Row 1000 · FC 200 · Lunges 100 (m) · Wall Balls 100 (개)
    static let totals: [Double] = [1000, 50, 50, 80, 1000, 200, 100, 100]
    /// 스테이션별 고를 수 있는 한 번 양
    static let options: [[Double]] = [
        [100, 150, 200, 250],      // SkiErg
        [6.25, 12.5, 25],          // Sled Push (반 · 한 · 두 바퀴씩) — 1.2.1: 6.25 · 25 추가
        [6.25, 12.5, 25],          // Sled Pull
        [10, 20, 40],              // BBJ
        [100, 150, 200, 250],      // Row
        [50, 100],                 // Farmers Carry
        [25, 50],                  // Lunges
        [10, 15, 20, 25],          // Wall Balls (개)
    ]
    static let defaultChunks: [Double] = [250, 12.5, 12.5, 20, 250, 50, 25, 20]
    /// 1.2.1: 차례 양을 고칠 때 한 칸 (총량이 모두 이 값의 배수라 나머지도 늘 단위에 맞음)
    static let units: [Double] = [50, 6.25, 6.25, 10, 50, 25, 12.5, 5]

    /// 월볼(마지막)만 개수, 나머지는 미터
    static func isReps(_ i: Int) -> Bool { i == 7 }
    /// 슬레드 (양을 "반 바퀴 · 한 바퀴 · 두 바퀴"로 보여 줌)
    static func isSled(_ i: Int) -> Bool { i == 1 || i == 2 }
    /// 예전 이름 (1.2.0 까지 슬레드는 12.5 하나뿐이었음). 이제 고를 수 있으므로 늘 false
    static func isFixed(_ i: Int) -> Bool { false }
    static func total(_ i: Int) -> Double { totals.indices.contains(i) ? totals[i] : 100 }
    static func unit(_ i: Int) -> Double { units.indices.contains(i) ? units[i] : 1 }
    static let eps: Double = 0.001
    /// v 가 단위의 배수인지
    static func onUnit(_ v: Double, _ i: Int) -> Bool {
        let u: Double = unit(i)
        let q: Double = v / u
        return abs(q - q.rounded()) < eps
    }

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

    /// 기본 계획 그대로인지 (양 · 순서 · 파트너 · 차례 모두 기본)
    var isDefault: Bool {
        (0..<8).allSatisfy { chunk($0) == Self.defaultChunks[$0] && meFirst($0) } && partnerName == nil && partnerId == nil && !hasTurns
    }

    // MARK: 1.2.1 차례 목록 (대표님 10-30: 혼성 더블처럼 두 사람 몫이 다를 때 차례마다 양을 자유롭게)
    //
    // 규칙 (시험 페이지 `더블계획_차례편집_시험.html` 과 같음):
    //  · 고정 줄(turns) 뒤에 늘 "나머지" 줄 = 총량 − 고정 줄 합 (0 이면 없음). 늘릴 수 없고, 줄이면 그 뒤에 새 줄이 생김.
    //  · 고정 줄을 늘리면 나머지가 줄고, 줄이면 나머지가 늘어남 → 모자람 · 넘침이 생길 수 없음.
    //  · 한 줄 최소 = 단위 1칸. 사람은 늘 번갈아 (줄 번호 + 먼저 하는 사람).

    /// 한 번 양으로 빠르게 채운 고정 줄: c × n. 남는 양은 마지막 두 차례에 반씩 (반이 단위에 맞을 때 — Ski · Row 150, Wall Balls 15)
    static func quickFill(_ i: Int, chunk c: Double) -> [Double] {
        let tot: Double = total(i)
        let step: Double = max(unit(i), c)
        var n: Int = Int((tot / step + eps).rounded(.down))
        n = max(1, min(200, n))
        var arr: [Double] = Array(repeating: step, count: n)
        let r: Double = tot - Double(n) * step
        if r > eps, n >= 2, onUnit(r / 2, i) {
            arr[n - 1] += r / 2
            arr[n - 2] += r / 2
        }
        return arr
    }

    /// 차례 목록이 쓸 만한지 (단위 배수 · 최소 1칸 · 합이 총량 이하 · 40줄 이하)
    static func validTurns(_ i: Int, _ t: [Double]) -> Bool {
        guard !t.isEmpty, t.count <= 40 else { return false }
        guard t.allSatisfy({ $0 >= unit(i) - eps && onUnit($0, i) }) else { return false }
        return t.reduce(0, +) <= total(i) + eps
    }

    /// 손으로 고친 차례가 하나라도 있는지
    var hasTurns: Bool { (0..<8).contains { turnsRaw($0) != nil } }
    /// i번째 스테이션이 손으로 고쳐졌는지 (빠르게 채운 모양과 다를 때만)
    func isEdited(_ i: Int) -> Bool { turnsRaw(i) != nil }
    /// 저장용: 빠르게 채운 모양과 같으면 nil 로 정리
    func turnsRaw(_ i: Int) -> [Double]? {
        guard turns.indices.contains(i), let t = turns[i], Self.validTurns(i, t) else { return nil }
        return t == Self.quickFill(i, chunk: chunk(i)) ? nil : t
    }
    /// 고정 줄 (손으로 고친 게 없으면 빠르게 채운 모양)
    func fixedTurns(_ i: Int) -> [Double] { turnsRaw(i) ?? Self.quickFill(i, chunk: chunk(i)) }
    /// 나머지 줄 양 (0 이면 없음)
    func remainder(_ i: Int) -> Double { max(0, Self.total(i) - fixedTurns(i).reduce(0, +)) }

    mutating func setTurns(_ i: Int, _ t: [Double]?) {
        guard (0..<8).contains(i) else { return }
        if turns.count < 8 { turns += Array(repeating: nil, count: 8 - turns.count) }
        if let t, Self.validTurns(i, t) { turns[i] = t } else { turns[i] = nil }
    }
    /// 한 번 양을 다시 고르면 고친 차례는 지움 (화면에서 먼저 확인 창)
    mutating func resetTurns(_ i: Int) { setTurns(i, nil) }

    func canPlus(_ i: Int, _ k: Int) -> Bool { remainder(i) >= Self.unit(i) - Self.eps && fixedTurns(i).indices.contains(k) }
    func canMinus(_ i: Int, _ k: Int) -> Bool {
        let t = fixedTurns(i)
        return t.indices.contains(k) && t[k] > Self.unit(i) + Self.eps
    }
    /// 나머지 줄을 줄일 수 있는지 (2칸 이상 남았을 때 — 줄이면 그 뒤에 새 줄이 생김)
    func canSplitRemainder(_ i: Int) -> Bool { remainder(i) >= 2 * Self.unit(i) - Self.eps }

    mutating func plus(_ i: Int, _ k: Int) {
        guard canPlus(i, k) else { return }
        var t = fixedTurns(i); t[k] += Self.unit(i); setTurns(i, t)
    }
    mutating func minus(_ i: Int, _ k: Int) {
        guard canMinus(i, k) else { return }
        var t = fixedTurns(i); t[k] -= Self.unit(i); setTurns(i, t)
    }
    /// 나머지 줄 − : 나머지에서 한 칸 뺀 만큼을 고정 줄로 굳히고, 그 뒤에 한 칸짜리 새 나머지가 생김
    mutating func splitRemainder(_ i: Int) {
        guard canSplitRemainder(i) else { return }
        var t = fixedTurns(i); t.append(remainder(i) - Self.unit(i)); setTurns(i, t)
    }

    // MARK: 번갈아 하는 순서

    /// i번째 스테이션을 번갈아 하는 순서 = 고정 줄 + 나머지 줄. 사람은 먼저 하는 사람부터 번갈아
    func sequence(_ i: Int) -> [(me: Bool, amount: Double)] {
        var amounts: [Double] = fixedTurns(i)
        let r: Double = remainder(i)
        if r > Self.eps { amounts.append(r) }
        var out: [(me: Bool, amount: Double)] = []
        var me: Bool = meFirst(i)
        for a in amounts {
            out.append((me: me, amount: a))
            me.toggle()
        }
        return out
    }
    /// 마지막 줄이 "나머지" 줄인지 (화면에서 회색으로)
    func lastIsRemainder(_ i: Int) -> Bool { remainder(i) > Self.eps }
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
        if abs(v * 10 - (v * 10).rounded()) < 0.001 { return String(format: "%.1f", v) }
        return String(format: "%.2f", v)      // 1.2.1: 6.25 (반 바퀴) — 예전엔 "6.2" 로 나왔음
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
        var p = self      // 차례 양(turns)은 그대로 — 사람은 줄 번호 + 먼저 하는 사람으로 정해지므로 뒤집기만 하면 맞음
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
        /// 1.2.1: 스테이션별 고친 차례 (없으면 생략 → 옛 앱도 그대로 읽음. 옛 앱은 이 키를 몰라서 무시)
        var t: [[Double]?]?
    }

    static func token(_ p: DoublesPlan, sender: String?) -> String? {
        let pay = Payload(c: (0..<8).map { p.chunk($0) }, f: (0..<8).map { p.meFirst($0) ? 1 : 0 },
                          n: DoublesPlan.cleanName(sender),
                          t: p.hasTurns ? (0..<8).map { p.turnsRaw($0) } : nil)
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
        if let t = pay.t {
            guard t.count == 8 else { return nil }
            for i in 0..<8 {
                if let a = t[i], !DoublesPlan.validTurns(i, a) { return nil }   // 이상한 차례면 링크 전체를 거절
                plan.setTurns(i, t[i])
            }
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
