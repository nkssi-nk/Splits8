import Foundation

// MARK: - 더블 구간 나누기 계획 (빌드 23 · 폰에만 저장, 서버로 안 보냄)

/// 더블에서 스테이션 8개를 파트너와 어떻게 나눌지 적어 두는 계획.
/// shares = 경기 순서대로 스테이션마다 내가 맡는 몫(%) 0...100. 기본 50(반반).
/// 러닝 8개는 더블에서도 둘이 같이 뛰므로 나누지 않음.
struct DoublesPlan: Codable, Hashable {
    var shares: [Int] = Array(repeating: 50, count: 8)

    /// 스테이션별 전체 양 — Ski 1000 · Push 50 · Pull 50 · BBJ 80 · Row 1000 · FC 200 · Lunges 100 (m) · Wall Balls 100 (개)
    static let amounts: [Int] = [1000, 50, 50, 80, 1000, 200, 100, 100]
    /// 월볼(마지막)만 개수, 나머지는 미터
    static func isReps(_ i: Int) -> Bool { i == 7 }

    /// i번째 스테이션에서 내가 맡는 몫(%) — 예전 저장 파일이 짧아도 안전하게 50 으로
    func share(_ i: Int) -> Int {
        guard shares.indices.contains(i) else { return 50 }
        return min(100, max(0, shares[i]))
    }

    /// 몫(%) 바꾸기 (0...100 으로 자름, 배열이 짧으면 채움)
    mutating func set(_ i: Int, _ v: Int) {
        guard (0..<8).contains(i) else { return }
        if shares.count < 8 { shares += Array(repeating: 50, count: 8 - shares.count) }
        shares[i] = min(100, max(0, v))
    }

    /// 모두 반반인지 (반반이면 저장 안 하고 비워 둠)
    var isDefault: Bool { (0..<8).allSatisfy { share($0) == 50 } }

    /// i번째 스테이션에서 내가 하는 양 (m 또는 개)
    func mine(_ i: Int) -> Int {
        let total: Int = Self.amounts.indices.contains(i) ? Self.amounts[i] : 100
        return Int((Double(total) * Double(share(i)) / 100).rounded())
    }
    /// i번째 스테이션에서 파트너가 하는 양
    func partners(_ i: Int) -> Int {
        (Self.amounts.indices.contains(i) ? Self.amounts[i] : 100) - mine(i)
    }

    /// 줄 아래 설명: "나 600 m · 파트너 400 m" / "나 60개 · 파트너 40개"
    func splitText(_ i: Int) -> String {
        let me: Int = mine(i), yu: Int = partners(i)
        return Self.isReps(i)
            ? String(localized: "You \(me) · Partner \(yu) reps")
            : String(localized: "You \(me) m · Partner \(yu) m")
    }

    /// 공유 문자열 한 줄: "나 600 m / 너 400 m" / "나 60개 / 너 40개"
    func shareLine(_ i: Int) -> String {
        let me: Int = mine(i), yu: Int = partners(i)
        return Self.isReps(i)
            ? String(localized: "me \(me) / you \(yu) reps")
            : String(localized: "me \(me) m / you \(yu) m")
    }

    /// 파트너에게 보낼 문자 전체 (현재 앱 언어로)
    var shareText: String {
        var lines: [String] = [String(localized: "SPLITS8 Doubles plan")]
        for i in 0..<8 { lines.append("\(Station.all[i].name): \(shareLine(i))") }
        lines.append(String(localized: "Runs: together"))
        return lines.joined(separator: "\n")
    }
}
