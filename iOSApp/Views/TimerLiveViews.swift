import SwiftUI

// MARK: - 18번 · 아이폰 운동 중 화면 (타바타 · EMOM · AMRAP · 인터벌 러닝 · 기능성)

/// 큰 남은 시간 (운동 = 노랑, 휴식 · 천천히 = 회색) + 몇 번째 + 아래 한 줄 + 전체 시간 + 다음 안내
struct TimerLiveBody: View {
    let f: TimerFace
    let total: Int
    let m: PhoneLiveMetrics
    /// 인터벌 러닝 (GPS): 지금 페이스
    var pace: String? = nil
    var paceColor: Color = C.text2

    var body: some View {
        let tint: Color = f.rest ? C.text2 : C.accent
        return VStack(spacing: 0) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text(f.label.l10n).font(F.t(m.nameFont, .bold)).tracking(0.12 * m.nameFont).foregroundStyle(tint)
                    .lineLimit(1).minimumScaleFactor(0.7)
                if !f.count.isEmpty {
                    Text(verbatim: f.count).font(F.num(m.nameFont)).foregroundStyle(.white).lineLimit(1)
                }
            }
            .accessibilityIdentifier("timer.label")
            Text(verbatim: f.main)
                .font(F.num(m.totalFont * 1.6)).tracking(-0.03 * m.totalFont * 1.6)
                .foregroundStyle(tint).lineLimit(1).minimumScaleFactor(0.4)
                .contentTransition(.numericText(countsDown: true))
                .padding(.top, 4)
                .accessibilityIdentifier("timer.main")
            if !f.line.isEmpty {
                Text(verbatim: f.line).font(F.t(m.detailFont + 1, .medium)).foregroundStyle(C.aeb)
                    .multilineTextAlignment(.center).lineLimit(3).minimumScaleFactor(0.8)
                    .padding(.top, 4)
            }
            HStack(spacing: 18) {
                VStack(spacing: 2) {
                    Text("TOTAL").font(F.t(12, .semibold)).tracking(1.4).foregroundStyle(C.text2)
                    Text(Fm.t(total)).font(F.num(m.detailFont * 1.6)).foregroundStyle(.white).lineLimit(1)
                }
                if let pace {
                    VStack(spacing: 2) {
                        Text("PACE /KM").font(F.t(12, .semibold)).tracking(1.4).foregroundStyle(C.text2)
                        Text(verbatim: pace).font(F.num(m.detailFont * 1.6)).foregroundStyle(paceColor).lineLimit(1)
                    }
                }
            }
            .padding(.top, m.segTop * 0.6)
            if !f.next.isEmpty {
                Rectangle().fill(Color.white.opacity(0.12)).frame(height: 1)
                    .padding(.horizontal, 20).padding(.top, m.dividerTop * 0.8).padding(.bottom, 12 * m.k)
                Text(verbatim: f.next).font(F.t(m.nextFont * 0.85, .semibold)).foregroundStyle(.white)
                    .lineLimit(1).minimumScaleFactor(0.7)
                    .accessibilityIdentifier("timer.next")
            }
        }
        .frame(maxWidth: .infinity)
        .animation(.easeInOut(duration: 0.25), value: f.rest)
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
