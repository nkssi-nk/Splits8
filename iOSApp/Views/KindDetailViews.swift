import SwiftUI

// MARK: - 18번 · 기록 화면: 종류별 표 (타바타 · EMOM · AMRAP · 인터벌 러닝 · 기능성)

struct KindDetailSection: View {
    let rec: Record
    private let store = Store.shared

    var body: some View {
        VStack(spacing: 10) {
            switch rec.kind ?? "" {
            case WKind.amrap:
                amrapExtra
                SectionLabel(text: "ROUNDS", top: 20)
                rowsCard(rec.segs)
            case WKind.strength:
                strength
            case WKind.interval:
                SectionLabel(text: "STEPS", top: 20)
                rowsCard(rec.segs)
            case WKind.emom, WKind.tabata:
                SectionLabel(text: "ROUNDS", top: 20)
                rowsCard(rec.segs.filter { $0.tag != "rest" })
            default:
                EmptyView()
            }
        }
    }

    // MARK: 줄 (라운드 · 단계)

    private func rowsCard(_ segs: [SegResult]) -> some View {
        VStack(spacing: 0) {
            ForEach(segs.indices, id: \.self) { i in
                row(segs[i], last: i == segs.count - 1)
            }
        }
        .card8()
    }

    private func row(_ s: SegResult, last: Bool) -> some View {
        let fast: Bool = s.tag == "fast"
        let rest: Bool = ["easy", "walk", "rest"].contains(s.tag ?? "")
        let imp: Bool = store.settings.imperial
        return HStack(spacing: 12) {
            Icon8(s.icon, 22, tint: rest ? .mute : .yellow)
            VStack(alignment: .leading, spacing: 1) {
                Text(title(s)).font(F.t(15, .medium)).foregroundStyle(fast ? C.accent : .white).lineLimit(1)
                Text(sub(s, imp: imp)).font(F.num(11, .medium)).foregroundStyle(C.text2).lineLimit(1).minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Text(Fm.t(s.time)).font(F.num(17)).lineLimit(1).fixedSize()
        }
        .padding(.vertical, 11).padding(.horizontal, 18)
        .background(fast ? C.accent.opacity(0.08) : Color.clear)
        .rowLine(!last)
    }

    private func title(_ s: SegResult) -> String {
        switch rec.kind ?? "" {
        case WKind.amrap:
            return s.tag == "part" ? "Last partial round".l10n : String(format: "Round %lld".l10n, s.no ?? 1)
        case WKind.tabata, WKind.emom:
            return String(format: "Round %lld".l10n, s.no ?? 1)
        case WKind.interval:
            let n: String = s.name.l10n
            return s.no.map { n + " · " + String(format: "rep %lld".l10n, $0) } ?? n
        default:
            return s.name.l10n
        }
    }

    private func sub(_ s: SegResult, imp: Bool) -> String {
        let bpm: String = (s.hr.map { "\($0)" } ?? "--") + " BPM"
        switch rec.kind ?? "" {
        case WKind.emom:
            let w: String = s.work.map { String(format: "Done in %@".l10n, Fm.t($0)) } ?? "Not marked done".l10n
            return w + " · " + bpm
        case WKind.interval:
            let d: Double = s.dist ?? 0
            var o: String = Units.dist(d, imp) + " " + Units.distUnit(imp)
            if d > 50 {
                let p: Int = Int((Double(s.time) / d * 1000).rounded())
                o += " · " + Fm.t(Units.pace(p, imp)) + " " + Units.paceUnit(imp)
                if let tp = s.tp {
                    let diff: Int = p - tp
                    o += " (" + (diff <= 0 ? "−" : "+") + Fm.t(abs(diff)) + ")"
                }
            }
            return o + " · " + bpm
        default:
            return bpm
        }
    }

    // MARK: AMRAP 추가 동작 수

    private var amrapExtra: some View {
        let e: Int = rec.extra ?? 0
        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Label8("EXTRA REPS")
                    Text("Reps done in the last partial round").font(F.t(13)).foregroundStyle(C.text2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                stepButton("minus") { setExtra(max(0, e - 1)) }
                Text(verbatim: "\(e)").font(F.num(24)).frame(minWidth: 44)
                    .accessibilityIdentifier("detail.amrapExtra")
                stepButton("plus") { setExtra(min(999, e + 1)) }
            }
        }
        .padding(.vertical, 14).padding(.horizontal, 16)
        .card8(18)
    }

    private func setExtra(_ v: Int) {
        var x: Record = rec
        x.extra = v > 0 ? v : nil
        store.updateRecord(x)
    }

    private func stepButton(_ sym: String, _ act: @escaping () -> Void) -> some View {
        Button(action: {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            act()
        }) {
            Image(systemName: sym).font(.system(size: 14, weight: .bold)).foregroundStyle(.white)
                .frame(width: 36, height: 36)
                .background(Color.white.opacity(0.12), in: Circle())
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
    }

    // MARK: 기능성 운동: 종목별 세트 표 · 총 볼륨 · 지난번 대비

    /// 종목 이름 (나온 순서대로)
    private var moveNames: [String] {
        var seen: [String] = []
        for s in rec.segs where s.tag == "set" && !seen.contains(s.name) { seen.append(s.name) }
        return seen
    }

    /// 같은 이름의 이전 기능성 기록
    private var previous: Record? {
        store.records.filter { $0.kind == WKind.strength && $0.title == rec.title && $0.id != rec.id && $0.date < rec.date }
            .max { $0.date < $1.date }
    }

    @ViewBuilder
    private var strength: some View {
        let vol: Int = Int(rec.volume.rounded())
        VStack(alignment: .leading, spacing: 4) {
            Label8("TOTAL VOLUME")
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(grouped(vol)).font(F.num(28))
                Text("KG").font(F.t(11, .semibold)).foregroundStyle(C.text2)
                Spacer(minLength: 0)
                if let p = previous {
                    let d: Int = vol - Int(p.volume.rounded())
                    Text((d >= 0 ? "+" : "−") + grouped(abs(d)) + " kg " + "vs last time".l10n)
                        .font(F.num(13, .medium)).foregroundStyle(d > 0 ? C.good : (d < 0 ? C.bad : C.text2))
                        .lineLimit(1).minimumScaleFactor(0.7)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 14).padding(.horizontal, 16)
        .card8(18)
        ForEach(moveNames, id: \.self) { n in
            moveCard(n)
        }
    }

    private func moveCard(_ name: String) -> some View {
        let sets: [SegResult] = rec.segs.filter { $0.tag == "set" && $0.name == name }
        let vol: Double = sets.reduce(0) { $0 + Double($1.reps ?? 0) * ($1.kg ?? 0) }
        return VStack(spacing: 0) {
            HStack {
                Text(name.l10n).font(F.t(17, .semibold)).lineLimit(1)
                Spacer(minLength: 8)
                Text(grouped(Int(vol.rounded())) + " kg").font(F.num(13, .medium)).foregroundStyle(C.text2)
            }
            .padding(.vertical, 12).padding(.horizontal, 18)
            .rowLine(true)
            ForEach(sets.indices, id: \.self) { i in
                let s: SegResult = sets[i]
                HStack(spacing: 12) {
                    Text(String(format: "Set %lld".l10n, s.no ?? i + 1)).font(F.t(15)).foregroundStyle(C.text2)
                        .frame(width: 64, alignment: .leading)
                    Text(String(format: "%lld reps × %@".l10n, s.reps ?? 0, StrengthMove.kgText(s.kg ?? 0)))
                        .font(F.num(15, .medium)).frame(maxWidth: .infinity, alignment: .leading)
                    Text(Fm.t(s.time)).font(F.num(13)).foregroundStyle(C.text2)
                }
                .padding(.vertical, 10).padding(.horizontal, 18)
                .rowLine(i < sets.count - 1)
            }
        }
        .card8()
    }
}
