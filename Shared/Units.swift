import Foundation

// MARK: - 단위 설정 (kg · km / lb · mi) — 화면에 보일 때만 바꿈, 저장 값은 그대로 미터법
// 아이폰: Store.shared.settings.imperial, 워치: engine.settings.imperial / WatchStore.shared.settings.imperial
// 스테이션 거리(50M · 1000M 등)는 하이록스 규정이 미터라 그대로 둠. 무게(kg)와 러닝 거리(km)만 바꿈.

extension Settings {
    /// lb · mi 로 보여 주는지 (nil / "metric" = kg · km)
    var imperial: Bool { units == "imperial" }
}

enum Units {
    static let lbPerKg: Double = 2.20462
    static let mPerMile: Double = 1609.344

    /// 페이스 단위 글자: "/KM" 또는 "/MI"
    static func paceUnit(_ imperial: Bool) -> String { imperial ? "/MI" : "/KM" }
    /// 거리 단위 글자: "KM" 또는 "MI"
    static func distUnit(_ imperial: Bool) -> String { imperial ? "MI" : "KM" }

    /// 1 km 당 초 → 1 mi 당 초 (미터법이면 그대로)
    static func pace(_ secPerKm: Int, _ imperial: Bool) -> Int {
        guard imperial else { return secPerKm }
        return Int((Double(secPerKm) * mPerMile / 1000).rounded())
    }

    /// 미터 → 보여 줄 거리 숫자 (km 또는 mi)
    static func distValue(_ meters: Double, _ imperial: Bool) -> Double {
        imperial ? meters / mPerMile : meters / 1000
    }

    /// 미터 → "%.2f" 문자열 (km 또는 mi)
    static func dist(_ meters: Double, _ imperial: Bool) -> String {
        String(format: "%.2f", distValue(meters, imperial))
    }

    /// kg → 보여 줄 무게 문자열 ("152" 또는 "335")
    static func weight(_ kg: Double, _ imperial: Bool) -> String {
        if imperial { return String(Int((kg * lbPerKg).rounded())) }
        if kg == kg.rounded() { return String(Int(kg)) }
        return String(format: "%g", kg)
    }

    private static let rx: NSRegularExpression? = try? NSRegularExpression(
        pattern: "(\\d+(?:\\.\\d+)?)(\\s?)(KG|kg|Kg|KM|km|Km)(?![A-Za-z])", options: [])

    /// 세부 글자를 화면용으로: "50M · 152KG" → "50M · 335LB", "2×24KG" → "2×53LB", "1KM" → "0.62MI"
    /// 미터("1000M", "50M")는 그대로. 미터법이면 받은 글자 그대로 돌려줌.
    static func detail(_ s: String, _ imperial: Bool) -> String {
        guard imperial, !s.isEmpty, let rx = rx else { return s }
        let ns: NSString = s as NSString
        let matches: [NSTextCheckingResult] = rx.matches(in: s, options: [], range: NSRange(location: 0, length: ns.length))
        guard !matches.isEmpty else { return s }
        var out: String = s
        // 뒤에서부터 바꿔야 앞쪽 위치가 안 밀림
        for m in matches.reversed() {
            let numStr: String = ns.substring(with: m.range(at: 1))
            let space: String = ns.substring(with: m.range(at: 2))
            let unit: String = ns.substring(with: m.range(at: 3))
            guard let v = Double(numStr) else { continue }
            let lower: Bool = unit == unit.lowercased()
            let isKg: Bool = unit.uppercased() == "KG"
            let newNum: String
            let newUnit: String
            if isKg {
                newNum = String(Int((v * lbPerKg).rounded()))
                newUnit = lower ? "lb" : "LB"
            } else {
                newNum = trimmed(v * 1000 / mPerMile)
                newUnit = lower ? "mi" : "MI"
            }
            guard let r = Range(m.range, in: out) else { continue }
            out.replaceSubrange(r, with: newNum + space + newUnit)
        }
        return out
    }

    /// 0.62 / 3.11 / 6.2 처럼 소수 둘째 자리까지, 끝의 0 은 뺌
    private static func trimmed(_ v: Double) -> String {
        var t: String = String(format: "%.2f", v)
        while t.contains(".") && (t.hasSuffix("0") || t.hasSuffix(".")) { t.removeLast() }
        return t
    }
}
