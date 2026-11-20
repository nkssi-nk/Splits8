import SwiftUI

// MARK: - 18번 · 아이폰 운동 중 화면 (타바타 · EMOM · AMRAP · 인터벌 러닝 · 기능성)

/// 1.2.7: 귀퉁이 표시 안 [단계 이름 17 · 큰 숫자 84 · 단위나 할 일 15] → 칸 (횟수 · 페이스 · ♥ BPM) → 점 → Next (워치와 같은 틀)
/// 운동 = 노랑, 인터벌 빠르게 = 파랑, 휴식 · 천천히 = 회색
struct TimerLiveBody: View {
    let f: TimerFace
    let L: PL
    let kind: String
    let seq: [Seg]
    let idx: Int
    /// 워치 같이 보기 심박 (폰만이면 nil)
    var hr: Int? = nil
    /// 인터벌 러닝 (GPS): 지금 페이스
    var pace: String? = nil

    static func tone(_ f: TimerFace, kind: String) -> W8Tone {
        if f.rest { return .gray }
        return kind == WKind.interval ? .run : .station
    }

    private var cur: Seg { seq.indices.contains(idx) ? seq[idx] : (seq.last ?? SeqBuilder.hiitRound(1)) }

    /// 인터벌은 "FAST · 20 s" / "FAST · 400 m"
    private var top: String {
        guard kind == WKind.interval, cur.no != nil else { return f.label.l10n }
        if let m = cur.autoM { return f.label.l10n + " · \(m) m" }
        if let a = cur.auto { return f.label.l10n + " · \(a) s" }
        return f.label.l10n
    }

    private var countLabel: String {
        switch kind {
        case WKind.amrap: return "ROUNDS"
        case WKind.interval: return "REP"
        case WKind.strength: return "SET"
        default: return "ROUND"
        }
    }

    var body: some View {
        let t: W8Tone = Self.tone(f, kind: kind)
        let big: String = f.main.hasSuffix(" m") ? String(f.main.dropLast(2)) : f.main
        let small: String = f.main.hasSuffix(" m") ? "M" : (kind == WKind.interval ? "" : f.line)
        let what: String? = TimerFaces.nextWhat(kind: kind, seq: seq, idx: idx)
        ZStack {
            LiveBrackets(L: L, tone: t)
            LiveBigBlock(L: L, label: top, main: big, unit: small, tone: t)
                .accessibilityIdentifier("timer.main")
            HStack(spacing: 0) {
                LiveCell(L: L, label: countLabel.l10n, value: f.count.isEmpty ? "--" : f.count, tone: t)
                if let pace { LiveCell(L: L, label: "PACE".l10n, value: pace, tone: t) }
                if let hr { LiveCell(L: L, label: "♥ " + "BPM".l10n, value: hr > 0 ? "\(hr)" : "--", tone: t) }
            }
            .frame(width: L.w - 48)
            .shadow(color: t.shadow, radius: 7, y: 2)
            .position(x: L.w / 2, y: L.y(398))
            if let d = dots {
                LiveDots(L: L, total: d.1, current: d.0, tone: t).position(x: L.w / 2, y: L.y(482))
            }
            if kind != WKind.amrap {
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Text("Next").font(F.t(L.v(26), .semibold)).foregroundStyle(t.sub)
                    Text(verbatim: what ?? "Finish".l10n).font(F.t(L.v(26), .bold)).foregroundStyle(t.ink)
                        .lineLimit(1).minimumScaleFactor(0.6)
                        .accessibilityIdentifier("timer.next")
                }
                .frame(maxWidth: L.w - 48)
                .shadow(color: t.shadow, radius: 7, y: 2)
                .position(x: L.w / 2, y: L.y(534))
            }
        }
        .animation(.easeInOut(duration: 0.25), value: f.rest)
    }

    /// "3/8" → (2, 8)
    private var dots: (Int, Int)? {
        let p: [Substring] = f.count.split(separator: "/")
        guard p.count == 2, let a = Int(p[0]), let b = Int(p[1]), b > 1, b <= 30 else { return nil }
        return (max(0, a - 1), b)
    }
}

// MARK: - 기능성 운동: 세트 끝 확인 (실제 횟수 · 무게)

struct StrengthSetAsk: Identifiable {
    let id = UUID()
    let name: String
    let no: Int
    var reps: Int
    var kg: Double
}

struct StrengthSetSheet: View {
    let ask: StrengthSetAsk
    let onSave: (Int, Double) -> Void
    @State private var reps: Int
    @State private var kg: Double

    init(ask: StrengthSetAsk, onSave: @escaping (Int, Double) -> Void) {
        self.ask = ask
        self.onSave = onSave
        _reps = State(initialValue: ask.reps)
        _kg = State(initialValue: ask.kg)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(ask.name.l10n).font(F.t(F.title3, .semibold)).lineLimit(1)
                Text(String(format: "Set %lld done".l10n, ask.no)).font(F.t(15)).foregroundStyle(C.text2)
            }
            NumStepper(label: "REPS DONE", value: Binding(get: { Double(reps) }, set: { reps = Int($0) }),
                       step: 1, range: 0...200, text: { "\(Int($0))" })
            NumStepper(label: "LOAD", value: $kg, step: 2.5, range: 0...500, text: { StrengthMove.kgText($0) })
            YellowButton(action: { onSave(reps, kg) }) {
                Text("Save · start rest")
            }
            .accessibilityIdentifier("strength.saveSet")
        }
        .padding(.horizontal, 20).padding(.top, 24).padding(.bottom, 16)
    }
}

/// 이름표 · − 값 + (큰 숫자)
struct NumStepper: View {
    let label: String
    @Binding var value: Double
    var step: Double = 1
    var range: ClosedRange<Double> = 0...999
    var text: (Double) -> String = { "\(Int($0))" }

    var body: some View {
        HStack(spacing: 12) {
            Label8(label)
                .frame(maxWidth: .infinity, alignment: .leading)
            button("minus") { value = max(range.lowerBound, value - step) }
            Text(verbatim: text(value)).font(F.num(22)).frame(minWidth: 84).lineLimit(1).minimumScaleFactor(0.7)
            button("plus") { value = min(range.upperBound, value + step) }
        }
        .padding(.vertical, 10).padding(.horizontal, 14)
        .card8(14)
    }

    private func button(_ sym: String, _ act: @escaping () -> Void) -> some View {
        Button(action: {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            act()
        }) {
            Image(systemName: sym).font(.system(size: 15, weight: .bold)).foregroundStyle(.white)
                .frame(width: 38, height: 38)
                .background(Color.white.opacity(0.12), in: Circle())
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - 트레이닝 만들기: 종류 고르기 (카드)

/// 하이록스 트레이닝 · 러닝 · 인터벌 러닝 · HIIT · 타바타 · EMOM · AMRAP · 기능성 운동
struct KindPickerSheet: View {
    private let r = Router.shared
    private let cols: [GridItem] = [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text("New training").font(F.t(F.title3, .semibold))
                    Spacer(minLength: 0)
                    Button { r.kindPicker = false } label: {
                        Image(systemName: "xmark").font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(C.text2)
                            .frame(width: 32, height: 32)
                            .background(Color.white.opacity(0.10), in: Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("newKind.close")
                }
                LazyVGrid(columns: cols, spacing: 10) {
                    ForEach(WKind.menu.indices, id: \.self) { i in
                        KindCard(kind: WKind.menu[i]) { pick(WKind.menu[i]) }
                    }
                }
            }
            .padding(.horizontal, 16).padding(.top, 22).padding(.bottom, 24)
        }
    }

    private func pick(_ k: String?) {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        r.kindPicker = false
        guard let k else {
            r.newTraining()
            return
        }
        // 시트가 닫힌 뒤 설정 시트를 엶 (두 시트를 동시에 띄울 수 없음)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) { Router.shared.bonus = BonusRequest(kind: k) }
    }
}

/// 종류 카드 하나 (아이콘 · 이름 · 한 줄 설명)
struct KindCard: View {
    let kind: String?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .top) {
                    Icon8(WKind.icon(kind), 28, tint: .yellow)
                    Spacer(minLength: 0)
                    Chevron8()
                }
                Text(WKind.label(kind).l10n).font(F.t(17, .semibold)).lineLimit(1).minimumScaleFactor(0.8).padding(.top, 12)
                Text(WKind.sub(kind).l10n).font(F.t(13)).foregroundStyle(C.text2)
                    .lineLimit(2).minimumScaleFactor(0.85).fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 3)
            }
            .padding(16)
            .frame(maxWidth: .infinity, minHeight: 124, alignment: .topLeading)
            .card8()
            .contentShape(Rectangle())
        }
        .buttonStyle(Press())
        .accessibilityIdentifier("newKind." + (kind ?? "hyrox"))
    }
}
