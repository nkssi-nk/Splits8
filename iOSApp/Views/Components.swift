import SwiftUI

// MARK: - 카드 (rgba 255 0.06 + 1px 0.08 테두리)

struct Card8: ViewModifier {
    var radius: CGFloat = 20
    func body(content: Content) -> some View {
        content
            .background(C.card, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: radius, style: .continuous).strokeBorder(C.cardBorder, lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
    }
}
extension View {
    func card8(_ r: CGFloat = 20) -> some View { modifier(Card8(radius: r)) }
    /// 목록 줄 아래 1px 선
    func rowLine(_ show: Bool) -> some View {
        overlay(alignment: .bottom) { if show { Rectangle().fill(C.line).frame(height: 1) } }
    }
}

/// 큰 제목 34/700
struct LargeTitle: View {
    let text: String
    var top: CGFloat = 10
    var body: some View {
        Text(text).font(F.t(34, .bold)).tracking(-1.02)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, top).padding(.horizontal, 4).padding(.bottom, 10)
    }
}

/// 섹션 라벨 (HISTORY 등)
struct SectionLabel: View {
    let text: String
    var top: CGFloat = 20
    var body: some View {
        Label8(text).frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, top).padding(.horizontal, 4)
    }
}

/// ‹ Settings (노랑)
struct BackLink: View {
    let label: String
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: 2) {
                Image(systemName: "chevron.left").font(.system(size: 19, weight: .semibold))
                Text(label).font(F.t(17))
            }
            .foregroundStyle(C.accent)
            .frame(height: 44)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("back")
        .onAppear { Router.shared.backAction = action }
    }
}

/// Cancel · 제목 · Save
struct NavBar3: View {
    let left: String
    let title: String
    var right: String? = nil
    var rightColor: Color = C.accent
    var leftColor: Color = C.text2
    let onLeft: () -> Void
    var onRight: () -> Void = {}
    /// 시트 안에서 쓸 때는 false (시트는 아래로 내려 닫음)
    var edgeBack = true
    var body: some View {
        ZStack {
            Text(title).font(F.t(17, .semibold))
            HStack {
                Button(left, action: onLeft).font(F.t(17)).foregroundStyle(leftColor).accessibilityIdentifier("nav.left")
                Spacer()
                if let right {
                    Button(right, action: onRight).font(F.t(17, .semibold)).foregroundStyle(rightColor).accessibilityIdentifier("nav.right")
                }
            }
        }
        .buttonStyle(.plain)
        .frame(height: 44)
        .padding(.horizontal, 4)
        .onAppear { if edgeBack { Router.shared.backAction = onLeft } }
    }
}

/// 노란 큰 버튼
struct YellowButton<L: View>: View {
    var height: CGFloat = 54
    var radius: CGFloat = 16
    let action: () -> Void
    @ViewBuilder var label: L
    var body: some View {
        Button(action: action) {
            label
                .foregroundStyle(.black)
                .frame(maxWidth: .infinity).frame(height: height)
                .yellowFill(radius)
        }
        .buttonStyle(Press())
    }
}

/// 노란 큰 버튼 바탕 — iOS 26+: 노란 유리(Liquid Glass), 그 이전: 노란 면
extension View {
    @ViewBuilder
    func yellowFill(_ radius: CGFloat, on: Bool = true, off: Color = C.control) -> some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        // contentShape: 버튼 전체(글자 밖 노란 면까지)를 눌러도 되게
        if !on {
            self.background(off, in: shape).contentShape(shape)
        } else if #available(iOS 26.0, *) {
            self.glassEffect(.regular.tint(C.accent), in: shape).contentShape(shape)
        } else {
            self.background(C.accent, in: shape).contentShape(shape)
        }
    }
}

/// 누를 때 살짝 작아짐
struct Press: ButtonStyle {
    var scale: CGFloat = 0.98
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.scaleEffect(configuration.isPressed ? scale : 1)
            .animation(.easeOut(duration: 0.08), value: configuration.isPressed)
    }
}

/// 세그먼트 (By age | Manual 등)
struct Seg8: View {
    let items: [(String, String)]
    let selected: String
    var height: CGFloat = 32
    var radius: CGFloat = 10
    var fontSize: CGFloat = 13
    var track: Color = C.segTrack
    var tracking: CGFloat = 0
    /// 0 이면 가로로 꽉 채움, 값이 있으면 그 너비 이상(안 채움)
    var minWidth: CGFloat = 0
    let onSelect: (String) -> Void
    var body: some View {
        HStack(spacing: 0) {
            ForEach(items.indices, id: \.self) { i in
                let k = items[i].0, l = items[i].1
                Button { onSelect(k) } label: {
                    Text(l).font(F.t(fontSize, .semibold)).tracking(tracking)
                        .foregroundStyle(selected == k ? Color.white : C.text2)
                        .padding(.horizontal, minWidth > 0 ? 12 : 0)
                        .frame(minWidth: minWidth > 0 ? minWidth : nil, maxWidth: minWidth > 0 ? nil : .infinity)
                        .frame(height: height)
                        .background(selected == k ? C.segOn : Color.clear,
                                    in: RoundedRectangle(cornerRadius: radius - 2, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(2)
        .background(track, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
    }
}

/// 작은 알약 세그먼트 (Mine | Jiho, Goal | Last)
struct Pills8: View {
    let items: [(String, String)]
    let selected: String
    let onSelect: (String) -> Void
    var body: some View {
        HStack(spacing: 0) {
            ForEach(items.indices, id: \.self) { i in
                let k = items[i].0, l = items[i].1
                Button { onSelect(k) } label: {
                    Text(l).font(F.t(11, .semibold))
                        .foregroundStyle(selected == k ? Color.white : C.text2)
                        .padding(.horizontal, 9).frame(height: 24)
                        .background(selected == k ? C.segOn : Color.clear, in: RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(2)
        .background(C.segTrack, in: RoundedRectangle(cornerRadius: 8))
    }
}

/// 노란 토글
struct Toggle8: View {
    @Binding var on: Bool
    var w: CGFloat = 44, h: CGFloat = 26
    var body: some View {
        let k = h - 4
        ZStack(alignment: .leading) {
            Capsule().fill(on ? C.accent : C.control)
            Circle().fill(on ? Color.black : Color.white).frame(width: k, height: k)
                .offset(x: on ? w - k - 2 : 2)
        }
        .frame(width: w, height: h)
        .animation(.timingCurve(0.32, 0.72, 0, 1, duration: 0.2), value: on)
        .onTapGesture { on.toggle() }
    }
}

/// − 값 + (34pt 버튼)
struct Stepper8: View {
    let value: String
    var minWidth: CGFloat = 24
    var fontSize: CGFloat = 24
    var button: CGFloat = 34
    var radius: CGFloat = 10
    var gap: CGFloat = 16
    let down: () -> Void
    let up: () -> Void
    var body: some View {
        HStack(spacing: gap) {
            sq("−", down)
            Text(value).font(F.num(fontSize)).frame(minWidth: minWidth)
            sq("+", up)
        }
    }
    private func sq(_ t: String, _ a: @escaping () -> Void) -> some View {
        Button(action: a) {
            Text(t).font(F.t(button > 32 ? 18 : 16)).foregroundStyle(.white)
                .frame(width: button, height: button)
                .background(C.btn1A, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
        }
        .buttonStyle(Press(scale: 0.94))
    }
}

/// 설정 목록 줄: 제목 · 값 · ›
struct SettingRow: View {
    let title: String
    let value: String
    var numeric = false
    var last = false
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Text(title).font(F.t(16)).frame(maxWidth: .infinity, alignment: .leading)
                Text(value).font(numeric ? F.num(15, .regular) : F.t(15)).foregroundStyle(C.text2).lineLimit(1)
                Image(systemName: "chevron.right").font(.system(size: 12, weight: .bold)).foregroundStyle(C.chev)
            }
            .padding(.vertical, 14).padding(.horizontal, 18)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .rowLine(!last)
    }
}

/// 체크 표시
struct Check8: View {
    var color: Color = C.accent
    var size: CGFloat = 20
    var body: some View {
        Image(systemName: "checkmark").font(.system(size: size * 0.7, weight: .bold)).foregroundStyle(color)
            .frame(width: size, height: size)
    }
}

/// 줄바꿈되는 가로 배치 (칩)
struct Flow: Layout {
    var spacing: CGFloat = 6
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let w = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, row: CGFloat = 0
        for s in subviews {
            let z = s.sizeThatFits(.unspecified)
            if x > 0 && x + z.width > w { x = 0; y += row + spacing; row = 0 }
            x += z.width + spacing; row = max(row, z.height)
        }
        return CGSize(width: w == .infinity ? x : w, height: y + row)
    }
    func placeSubviews(in b: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = b.minX, y = b.minY, row: CGFloat = 0
        for s in subviews {
            let z = s.sizeThatFits(.unspecified)
            if x > b.minX && x + z.width > b.maxX { x = b.minX; y += row + spacing; row = 0 }
            s.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(z))
            x += z.width + spacing; row = max(row, z.height)
        }
    }
}

/// 입력칸 (카드 모양)
struct Field8: View {
    let placeholder: String
    @Binding var text: String
    var size: CGFloat = 17
    var body: some View {
        TextField("", text: $text, prompt: Text(placeholder).foregroundColor(C.text3))
            .font(F.t(size))
            .foregroundStyle(.white)
            .padding(.vertical, 14).padding(.horizontal, 16)
            .card8(14)
    }
}
