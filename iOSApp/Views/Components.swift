import SwiftUI
import UIKit

// 시안 v3 (design_handoff_splits8/design/SplitsPhone.dc.html) 공통 부품.
// 글자 크기는 11 · 13 · 15 · 17 · 20 · 28 · 44 만 씁니다 (예외: 큰 제목 34, 레이스 52). 굵기는 400/500/600, 워드마크만 800.

// MARK: - 카드 (rgba 255 0.06 + inset 1px 0.08, radius 20)

struct Card8: ViewModifier {
    var radius: CGFloat = 20
    var fill: Color = C.card
    func body(content: Content) -> some View {
        content
            .background(fill, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: radius, style: .continuous).strokeBorder(C.cardBorder, lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
    }
}
extension View {
    func card8(_ r: CGFloat = 20, fill: Color = C.card) -> some View { modifier(Card8(radius: r, fill: fill)) }
    /// 목록 줄 아래 1px 선 (rgba 255 0.08)
    func rowLine(_ show: Bool) -> some View {
        overlay(alignment: .bottom) { if show { Rectangle().fill(C.line).frame(height: 1) } }
    }
}

/// 큰 제목 34 / 600, 자간 −0.03em (가입·온보딩·기록 상세에서만)
struct LargeTitle: View {
    let text: String
    var top: CGFloat = 10
    var body: some View {
        Text(text.l10n).font(F.t(34, .semibold)).tracking(-0.03 * 34)
            .lineSpacing(0)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, top)
    }
}

/// 섹션 라벨 (HISTORY 등): 11 / 600, 자간 0.1em, 회색. 시안 margin: top 14 또는 20, 좌우 4
struct SectionLabel: View {
    let text: String
    var top: CGFloat = 14
    var body: some View {
        Label8(text).frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, top).padding(.horizontal, 4)
    }
}

/// 작은 아이콘 (i_* 템플릿 이미지)
struct Glyph: View {
    let name: String
    var size: CGFloat
    var color: Color = .white
    init(_ name: String, _ size: CGFloat, _ color: Color = .white) { self.name = name; self.size = size; self.color = color }
    var body: some View {
        Image(name).renderingMode(.template).resizable().interpolation(.high).scaledToFit()
            .frame(width: size, height: size).foregroundStyle(color)
    }
}

/// › (14px, #48484C)
struct Chevron8: View {
    var size: CGFloat = 14
    var color: Color = C.chev
    var body: some View { Glyph("i_chevR", size, color) }
}

/// ‹ 뒤로 (노랑 17): 가입·코드·기록 상세 화면 안쪽에서만. 탭 화면은 위 고정 바가 뒤로를 맡음
struct BackLink: View {
    let label: String
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: 2) {
                Glyph("i_chevL", 22, C.accent)
                Text(label.l10n).font(F.t(17))
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

/// Cancel · 제목 · Save (44 높이, 좌우 4)
struct NavBar3: View {
    let left: String
    let title: String
    var right: String? = nil
    var rightColor: Color = C.accent
    var leftColor: Color = C.text2
    let onLeft: () -> Void
    var onRight: () -> Void = {}
    /// 시트 안에서 쓸 때는 false
    var edgeBack = true
    var body: some View {
        ZStack {
            Text(title.l10n).font(F.t(17, .semibold))
            HStack {
                Button(action: onLeft) {
                    Text(left.l10n).font(F.t(17)).foregroundStyle(leftColor)
                        .frame(minWidth: 44, minHeight: 44, alignment: .leading)
                        .contentShape(Rectangle())
                }
                .accessibilityIdentifier("nav.left")
                Spacer()
                if let right {
                    Button(action: onRight) {
                        Text(right.l10n).font(F.t(17, .semibold)).foregroundStyle(rightColor)
                            .frame(minWidth: 44, minHeight: 44, alignment: .trailing)
                            .contentShape(Rectangle())
                    }
                    .accessibilityIdentifier("nav.right")
                } else {
                    Color.clear.frame(width: 40, height: 1)
                }
            }
        }
        .buttonStyle(.plain)
        .frame(height: 44)
        .padding(.horizontal, 4)
        .onAppear { if edgeBack { Router.shared.backAction = onLeft } }
    }
}

// MARK: - 노란 유리 버튼 (Liquid Glass)

/// 시안: linear-gradient(180deg, rgba(255,238,70,0.96), rgba(255,214,0,0.80)) + blur 16 saturate 160%
/// + inset 위 하이라이트 rgba(255,255,255,0.6) · inset 아래 rgba(0,0,0,0.10) + 그림자 0 6 18 rgba(255,214,0,0.20)
struct YellowGlass<S: InsettableShape>: ViewModifier {
    let shape: S
    var glow = true
    func body(content: Content) -> some View {
        content
            .background {
                ZStack {
                    if #available(iOS 26.0, *) {
                        Color.clear.glassEffect(.regular.tint(Color(hex: 0xFFE600, alpha: 0.88)), in: shape)
                    } else {
                        shape.fill(.ultraThinMaterial)
                    }
                    shape.fill(LinearGradient(colors: [Color(red: 1, green: 238 / 255, blue: 70 / 255, opacity: 0.96),
                                                       Color(red: 1, green: 214 / 255, blue: 0, opacity: 0.80)],
                                              startPoint: .top, endPoint: .bottom))
                    // 위 1px 하이라이트 · 아래 1px 그늘
                    shape.strokeBorder(LinearGradient(stops: [.init(color: .white.opacity(0.6), location: 0),
                                                              .init(color: .white.opacity(0), location: 0.12),
                                                              .init(color: .black.opacity(0), location: 0.88),
                                                              .init(color: .black.opacity(0.10), location: 1)],
                                                      startPoint: .top, endPoint: .bottom), lineWidth: 1)
                }
                .shadow(color: glow ? Color(red: 1, green: 214 / 255, blue: 0, opacity: 0.20) : .clear, radius: 9, y: 6)
            }
            .contentShape(shape)
    }
}

extension View {
    /// 노란 유리 바탕 (둥근 사각형). on=false 면 회색 비활성 바탕
    @ViewBuilder
    func yellowFill(_ radius: CGFloat, on: Bool = true, off: Color = Color.white.opacity(0.12)) -> some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        if on { self.modifier(YellowGlass(shape: shape)) }
        else { self.background(off, in: shape).contentShape(shape) }
    }
    /// 노란 유리 알약 · 원
    func yellowCapsule() -> some View { modifier(YellowGlass(shape: Capsule())) }
}

/// 큰 노란 버튼 (54 높이, radius 16, 17/600). 비활성이면 rgba(255,255,255,0.12) + #6E6E73 글자
struct YellowButton<L: View>: View {
    var height: CGFloat = 54
    var radius: CGFloat = 16
    var enabled = true
    let action: () -> Void
    @ViewBuilder var label: L
    var body: some View {
        Button(action: action) {
            label
                .font(F.t(17, .semibold))
                .foregroundStyle(enabled ? Color.black : C.text3)
                .frame(maxWidth: .infinity).frame(height: height)
                .yellowFill(radius, on: enabled)
        }
        .buttonStyle(Press())
        .disabled(!enabled)
    }
}

/// 작은 노란 알약 (Add event · Sign up): 34 높이, 좌우 14, 13/600
struct YellowPill: View {
    let title: String
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Text(title.l10n).font(F.t(13, .semibold)).foregroundStyle(.black)
                .padding(.horizontal, 14).frame(height: 34)
                .yellowCapsule()
        }
        .buttonStyle(Press(scale: 0.96))
        .fixedSize()
    }
}

/// 회색 알약 (Edit): 34 높이, rgba(255,255,255,0.10)
struct GrayPill: View {
    let title: String
    var icon: String? = nil
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let icon { Glyph(icon, 13, .white) }
                Text(title.l10n).font(F.t(13, .semibold))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 14).frame(height: 34)
            .background(Color.white.opacity(0.10), in: Capsule())
            .contentShape(Capsule())
        }
        .buttonStyle(Press(scale: 0.96))
        .fixedSize()
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

// MARK: - 세그먼트 · 토글 · 스테퍼

/// 세그먼트 (By age | Manual): 트랙 rgba(255,255,255,0.08) radius 10, 선택 #2C2C2E radius 8, 32 높이, 13/600
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
                    Text(l.l10n).font(F.t(fontSize, .semibold)).tracking(tracking).lineLimit(1)
                        .foregroundStyle(selected == k ? Color.white : C.text2)
                        .padding(.horizontal, minWidth > 0 ? 12 : 0)
                        .frame(minWidth: minWidth > 0 ? minWidth : nil, maxWidth: minWidth > 0 ? nil : .infinity)
                        .frame(height: height)
                        .background(selected == k ? C.segOn : Color.clear,
                                    in: RoundedRectangle(cornerRadius: radius - 2, style: .continuous))
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(2)
        .background(track, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
    }
}

/// 작은 알약 세그먼트 (Mine | Jiho): 24 높이, 11/600
struct Pills8: View {
    let items: [(String, String)]
    let selected: String
    let onSelect: (String) -> Void
    var body: some View {
        HStack(spacing: 0) {
            ForEach(items.indices, id: \.self) { i in
                let k = items[i].0, l = items[i].1
                Button { onSelect(k) } label: {
                    Text(l.l10n).font(F.t(11, .semibold))
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

/// 토글 51×31, 켜짐 노랑 + 검정 손잡이 (27)
struct Toggle8: View {
    @Binding var on: Bool
    var w: CGFloat = 51, h: CGFloat = 31
    var body: some View {
        let k = h - 4
        ZStack(alignment: .leading) {
            Capsule().fill(on ? C.accent : C.control)
            Circle().fill(on ? Color.black : Color.white).frame(width: k, height: k)
                .shadow(color: .black.opacity(0.3), radius: 2, y: 2)
                .offset(x: on ? w - k - 2 : 2)
        }
        .frame(width: w, height: h)
        .animation(.timingCurve(0.32, 0.72, 0, 1, duration: 0.2), value: on)
        .contentShape(Capsule())
        .onTapGesture { on.toggle() }
    }
}

/// − 값 + (34 정사각 #1A1A1A radius 10, 값 20/600)
struct Stepper8: View {
    let value: String
    var minWidth: CGFloat = 24
    var fontSize: CGFloat = 20
    var button: CGFloat = 34
    var radius: CGFloat = 10
    var gap: CGFloat = 16
    let down: () -> Void
    let up: () -> Void
    var body: some View {
        HStack(spacing: gap) {
            sq("−", down)
            Text(value).font(F.num(fontSize)).frame(minWidth: minWidth).lineLimit(1)
            sq("+", up)
        }
    }
    private func sq(_ t: String, _ a: @escaping () -> Void) -> some View {
        Button(action: a) {
            Text(t).font(F.t(17)).foregroundStyle(.white)
                .frame(width: button, height: button)
                .background(C.btn1A, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
                .contentShape(Rectangle())
        }
        .buttonStyle(Press(scale: 0.94))
    }
}

// MARK: - 목록 줄

/// 설정 목록 줄: 제목 17 · 값 15 회색 · › (padding 14×18, 선 1px)
struct SettingRow: View {
    let title: String
    let value: String
    var numeric = false
    var last = false
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Text(title.l10n).font(F.t(17)).frame(maxWidth: .infinity, alignment: .leading)
                Text(value.l10n).font(numeric ? F.num(15, .regular) : F.t(15)).foregroundStyle(C.text2).lineLimit(1).fixedSize()
                Chevron8()
            }
            .padding(.vertical, 14).padding(.horizontal, 18)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .rowLine(!last)
    }
}

/// 체크 (노랑, 2.6 굵기)
struct Check8: View {
    var color: Color = C.accent
    var size: CGFloat = 20
    var body: some View { Glyph("i_check", size, color) }
}

/// 원형 사진/이니셜 (사진 있으면 사진)
struct Avatar8: View {
    var size: CGFloat
    var photo: UIImage? = nil
    var initial: String
    var bg: Color = C.control
    var fg: Color = .white
    var fontSize: CGFloat? = nil
    var body: some View {
        ZStack {
            if let photo {
                Image(uiImage: photo).resizable().scaledToFill()
            } else {
                bg
                Text(initial).font(F.t(fontSize ?? size * 0.38, .semibold)).foregroundStyle(fg)
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
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

/// 입력칸 (카드 모양, radius 14, 17pt, padding 14×16)
struct Field8: View {
    let placeholder: String
    @Binding var text: String
    var size: CGFloat = 17
    var vPad: CGFloat = 14
    var body: some View {
        TextField("", text: $text, prompt: Text(placeholder.l10n).foregroundColor(C.text3))
            .font(F.t(size))
            .foregroundStyle(.white)
            .padding(.vertical, vPad).padding(.horizontal, 16)
            .card8(14)
    }
}

/// 검색칸 (rgba 255 0.08, radius 12, 돋보기 16 회색, 17pt, 세로 11)
struct SearchField8: View {
    let placeholder: String
    @Binding var text: String
    var prefix: String? = nil       // "@" 등
    var body: some View {
        HStack(spacing: 8) {
            if let prefix { Text(prefix).font(F.t(17)).foregroundStyle(C.text2) }
            else { Glyph("i_search", 16, C.text2) }
            TextField("", text: $text, prompt: Text(placeholder.l10n).foregroundColor(C.text3))
                .font(F.t(17)).foregroundStyle(.white)
                .textInputAutocapitalization(.never).autocorrectionDisabled()
                .submitLabel(.search)
                .padding(.vertical, 11)
        }
        .padding(.horizontal, 12)
        .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

/// 설명 문구 (13, #6E6E73, 줄간 1.5, 좌우 4)
struct Note8: View {
    let text: String
    var color: Color = C.text3
    var body: some View {
        Text(text.l10n).font(F.t(13)).foregroundStyle(color).lineSpacing(13 * 0.5 - 3)
            .frame(maxWidth: .infinity, alignment: .leading)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 4)
    }
}

// MARK: - 왼쪽으로 밀어 삭제 (기록 줄 · 트레이닝 카드 공통)

/// 왼쪽으로 밀면 오른쪽에 빨간 Delete (Delete 를 눌러야 확인창). 밀기 시작한 손동작은 "누름"으로 치지 않음.
/// corner: 카드처럼 둥근 모서리면 그 값. press: 누를 때 살짝 작아지는 효과(카드용). menu: 길게 눌러 Delete 메뉴(기록 줄용)
struct SwipeDelete<Content: View>: View {
    var corner: CGFloat = 0
    var press: Bool = false
    var menu: Bool = true
    let alertTitle: LocalizedStringKey
    var alertMessage: LocalizedStringKey = "This can't be undone."
    let onTap: () -> Void
    let onDelete: () -> Void
    @ViewBuilder let content: () -> Content

    @State private var offset: CGFloat = 0
    @State private var settled: CGFloat = 0
    @State private var ask = false
    /// 이번 손동작에서 옆으로 밀었는지 (그러면 손을 떼도 누름 무시)
    @State private var dragged = false
    private let reveal: CGFloat = 84

    var body: some View {
        ZStack(alignment: .trailing) {
            if offset < 0 {
                Button { ask = true } label: {
                    VStack(spacing: 3) {
                        Image(systemName: "trash").font(.system(size: 17, weight: .semibold))
                        Text("Delete").font(F.t(12, .semibold))
                    }
                    .foregroundStyle(.white)
                    .frame(width: max(reveal, -offset))
                    .frame(maxHeight: .infinity)
                    .background(C.bad)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("swipe.delete")
            }
            tapArea.offset(x: offset)
        }
        .clipShape(RoundedRectangle(cornerRadius: corner, style: .continuous))
        .modifier(SwipeGesture(onChanged: dragChanged, onEnded: dragEnded))
        .modifier(DeleteMenu(on: menu, ask: $ask))
        .alert(alertTitle, isPresented: $ask) {
            Button("Delete", role: .destructive) {
                close()
                withAnimation(.easeOut(duration: 0.25)) { onDelete() }
            }
            Button("Cancel", role: .cancel) { close() }
        } message: {
            Text(alertMessage)
        }
        .onDisappear {
            // 화면이 바뀌면 열린 확인창·밀린 상태를 정리 (보이지 않는 확인창이 터치를 막지 않게)
            ask = false; offset = 0; settled = 0; dragged = false
        }
    }

    @ViewBuilder
    private var tapArea: some View {
        if press {
            Button { tap() } label: { content() }.buttonStyle(Press())
        } else {
            Button { tap() } label: { content() }.buttonStyle(.plain)
        }
    }

    private func tap() {
        if dragged { return }                 // 밀다가 손을 뗀 것 → 누름 아님
        if settled != 0 { close() } else { onTap() }
    }

    /// 옆으로 미는 중 (dx: 손가락이 옆으로 움직인 거리)
    private func dragChanged(_ dx: CGFloat) {
        dragged = true
        offset = min(0, settled + dx)
    }

    private func dragEnded(_ dx: CGFloat) {
        let x = settled + dx
        withAnimation(.snappy(duration: 0.25)) {
            if x < -reveal / 2 {
                offset = -reveal; settled = -reveal      // 많이 밀어도 확인창은 Delete 를 눌러야
            } else {
                offset = 0; settled = 0
            }
        }
        // 버튼의 누름 판정이 끝난 뒤에 풀어 줌
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { dragged = false }
    }

    private func close() {
        withAnimation(.snappy(duration: 0.25)) { offset = 0; settled = 0 }
    }
}

/// 길게 눌러 Delete 메뉴 (기록 줄만)
private struct DeleteMenu: ViewModifier {
    let on: Bool
    @Binding var ask: Bool
    func body(content: Content) -> some View {
        if on {
            content.contextMenu {
                Button(role: .destructive) { ask = true } label: { Label("Delete", systemImage: "trash") }
            }
        } else {
            content
        }
    }
}


// MARK: - 옆으로만 밀기 (스크롤을 막지 않게)

/// iOS 18+: UIKit 밀기 — 시작할 때 가로 움직임이 세로보다 클 때만 잡음. 세로로 밀면 처음부터 스크롤이 가져감.
/// iOS 17: SwiftUI DragGesture (20pt 이상, 가로일 때만)
struct SwipeGesture: ViewModifier {
    let onChanged: (CGFloat) -> Void
    let onEnded: (CGFloat) -> Void

    func body(content: Content) -> some View {
        if #available(iOS 18.0, *) {
            content.gesture(HorizontalPan(onChanged: onChanged, onEnded: onEnded))
        } else {
            content.simultaneousGesture(
                DragGesture(minimumDistance: 20)
                    .onChanged { v in
                        guard abs(v.translation.width) > abs(v.translation.height) else { return }
                        onChanged(v.translation.width)
                    }
                    .onEnded { v in
                        let horizontal = abs(v.translation.width) > abs(v.translation.height)
                        onEnded(horizontal ? v.translation.width : 0)
                    }
            )
        }
    }
}

@available(iOS 18.0, *)
struct HorizontalPan: UIGestureRecognizerRepresentable {
    let onChanged: (CGFloat) -> Void
    let onEnded: (CGFloat) -> Void

    func makeCoordinator(converter: CoordinateSpaceConverter) -> Coordinator { Coordinator() }

    func makeUIGestureRecognizer(context: Context) -> UIPanGestureRecognizer {
        let g = UIPanGestureRecognizer()
        g.delegate = context.coordinator
        return g
    }

    func handleUIGestureRecognizerAction(_ recognizer: UIPanGestureRecognizer, context: Context) {
        let dx: CGFloat = recognizer.translation(in: recognizer.view).x
        switch recognizer.state {
        case .began, .changed: onChanged(dx)
        case .ended, .cancelled, .failed: onEnded(dx)
        default: break
        }
    }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        /// 가로로 밀 때만 시작 (세로는 스크롤에 양보)
        func gestureRecognizerShouldBegin(_ g: UIGestureRecognizer) -> Bool {
            guard let p = g as? UIPanGestureRecognizer else { return false }
            let v: CGPoint = p.velocity(in: p.view)
            return abs(v.x) > abs(v.y) * 1.2
        }
    }
}
