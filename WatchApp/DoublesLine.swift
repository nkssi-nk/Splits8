import Foundation

// MARK: - 더블 계획 한 줄 (빌드 27)

/// 운동 화면에 붙일 더블 계획 한 줄. 예: "나 150 → 가테부 150 · 7번 교대"
/// 더블 디비전(키가 "dbl" 로 시작)이고 지금 구간이 스테이션이며 계획이 있을 때만 글자를 줌. 아니면 nil.
/// 파트너 이름은 6글자까지. 화면 배치는 부르는 쪽(WorkoutViews)이 정함.
func doublesLine(for seg: Seg, plan: DoublesPlan?, division: String) -> String? {
    guard let plan, division.hasPrefix("dbl"), seg.kind == .st else { return nil }
    guard let i = Station.all.firstIndex(where: { $0.key == seg.icon }) else { return nil }
    let seq: [(me: Bool, amount: Double)] = plan.sequence(i)
    guard let first = seq.first else { return nil }
    let me: String = "Me".l10n
    let partner: String = String(plan.partnerShown.prefix(6))
    let firstName: String = first.me ? me : partner
    let secondName: String = first.me ? partner : me
    // 둘째 차례 양 (한 번에 끝나면 0) — 보통은 같은 양
    let secondAmount: Double = seq.count > 1 ? seq[1].amount : 0
    let head: String = firstName + " " + DoublesPlan.num(first.amount) + " → " + secondName + " " + DoublesPlan.num(secondAmount)
    let turns: String = String(format: "%lld turns".l10n, Int64(seq.count))
    return head + " · " + turns
}
