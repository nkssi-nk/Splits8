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

/// 구역 소제목 글자 (Modes · Personal Bests · History …): 15 / 600, 흰색.
/// 코드에는 예전처럼 대문자 키("PERSONAL BESTS")로 적고, 보여 줄 때 첫 글자만 대문자로 바꿈.
/// 한국어 번역이 있으면 번역을 그대로 씀 (번역 키는 대문자 원문 그대로라 ko 파일을 안 바꿔도 됨)
struct SectionText: View {
    let text: String
    init(_ text: String) { self.text = text }
    var body: some View {
        Text(Self.shown(text)).font(F.t(F.sub, .semibold)).foregroundStyle(.white).lineLimit(1)
            .minimumScaleFactor(0.85)
    }

    /// 그대로 대문자로 두는 낱말
    private static let keep: Set<String> = ["PFT", "HIIT", "HR", "PB", "KM", "ID", "VS"]

    static func shown(_ key: String) -> String {
        let loc: String = key.l10n
        if loc != key { return loc }
        return titleCase(key)
    }

    /// "PERSONAL BESTS" → "Personal Bests" (이미 소문자가 섞여 있으면 그대로)
    static func titleCase(_ s: String) -> String {
        guard s == s.uppercased() else { return s }
        let words: [String] = s.components(separatedBy: " ").map { w in
            if keep.contains(w) || w.count <= 1 { return w }
            guard w.rangeOfCharacter(from: .letters) != nil else { return w }
            return String(w.prefix(1)) + w.dropFirst().lowercased()
        }
        return words.joined(separator: " ")
    }
}

/// 구역 소제목 줄. 시안 margin: top 14 또는 20, 좌우 4
struct SectionLabel: View {
    let text: String
    var top: CGFloat = 14
    var body: some View {
        SectionText(text).frame(maxWidth: .infinity, alignment: .leading)
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
        .accessibilityElement(children: .ignore)
        .accessibilityAddTraits(.isButton)
        .accessibilityValue(Text(on ? "On" : "Off"))
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

/// 칩을 한 줄만 보여 주는 배치: 앞에서부터 들어가는 만큼 놓고, 고른 칩(pinned)은 항상 보이게 함.
/// 못 들어간 칩은 화면 오른쪽 밖 멀리 둠 (바깥에서 .clipped()) — 오른쪽 reserve 만큼은 겹꺾쇠 자리로 비워 둠
struct OneRow: Layout {
    var spacing: CGFloat = 6
    var reserve: CGFloat = 0
    var pinned: Int? = nil

    /// 한 줄에 보일 칩 번호 (왼쪽부터 놓을 순서)
    static func fit(widths: [CGFloat], room: CGFloat, spacing: CGFloat, pinned: Int?) -> [Int] {
        var x: CGFloat = 0
        var shown: [Int] = []
        for (i, w) in widths.enumerated() {
            let need: CGFloat = (shown.isEmpty ? 0 : spacing) + w
            if x + need > room { break }
            x += need
            shown.append(i)
        }
        if let p = pinned, widths.indices.contains(p), !shown.contains(p) {
            // 고른 칩이 안 보이면 뒤에서부터 빼서 자리를 만듦
            while !shown.isEmpty && x + spacing + widths[p] > room {
                let last: Int = shown.removeLast()
                x -= widths[last] + (shown.isEmpty ? 0 : spacing)
            }
            shown.append(p)
        }
        if shown.isEmpty && !widths.isEmpty { shown = [pinned.flatMap { widths.indices.contains($0) ? $0 : nil } ?? 0] }
        return shown
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let sizes: [CGSize] = subviews.map { $0.sizeThatFits(.unspecified) }
        let h: CGFloat = sizes.map(\.height).max() ?? 0
        let all: CGFloat = sizes.map(\.width).reduce(0, +) + spacing * CGFloat(max(0, sizes.count - 1)) + reserve
        let w: CGFloat = proposal.width ?? all
        return CGSize(width: w.isFinite ? w : all, height: h)
    }

    func placeSubviews(in b: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let sizes: [CGSize] = subviews.map { $0.sizeThatFits(.unspecified) }
        let shown: [Int] = OneRow.fit(widths: sizes.map(\.width), room: b.width - reserve, spacing: spacing, pinned: pinned)
        var x: CGFloat = b.minX
        for i in shown {
            subviews[i].place(at: CGPoint(x: x, y: b.minY), proposal: ProposedViewSize(sizes[i]))
            x += sizes[i].width + spacing
        }
        for i in subviews.indices where !shown.contains(i) {
            subviews[i].place(at: CGPoint(x: b.maxX + 3000, y: b.minY), proposal: ProposedViewSize(sizes[i]))
        }
    }
}

/// 칩 묶음: 접으면 한 줄 + 오른쪽 겹꺾쇠(︾), 겹꺾쇠를 누르면 전부 펼쳐지고 끝에 ︽ 가 붙음.
/// 접힌 상태에서도 고른 칩(pinned)은 항상 보임
struct FoldChips<Content: View>: View {
    var spacing: CGFloat = 6
    /// 칩 높이 (겹꺾쇠 칸도 같은 높이)
    var height: CGFloat = 34
    var radius: CGFloat = 10
    var pinned: Int? = nil
    var id: String = "chips.more"
    @Binding var open: Bool
    @ViewBuilder var content: () -> Content

    private var toggleW: CGFloat { height + 6 }

    var body: some View {
        Group {
            if open {
                Flow(spacing: spacing) {
                    content()
                    toggle
                }
            } else {
                OneRow(spacing: spacing, reserve: toggleW + spacing, pinned: pinned) {
                    content()
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .clipped()
                .overlay(alignment: .trailing) { toggle }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var toggle: some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            withAnimation(.easeOut(duration: 0.2)) { open.toggle() }
        } label: {
            DoubleChevron(up: open)
                .stroke(C.aeb, style: StrokeStyle(lineWidth: 1.7, lineCap: .round, lineJoin: .round))
                .frame(width: 10, height: 11)
                .frame(width: toggleW, height: height)
                .overlay(RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.16), lineWidth: 1))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(open ? "Less" : "More"))
        .accessibilityIdentifier(id)
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
    /// 손을 떼면 Delete 가 열린 채 남는 지점을 넘었는지 (넘는 순간 진동 한 번)
    @State private var armed = false
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
            ask = false; offset = 0; settled = 0; dragged = false; armed = false
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
        let x: CGFloat = min(0, settled + dx)
        offset = x
        // 닫힌 상태에서 밀다가 "여기서 놓으면 Delete 가 열림" 지점을 넘는 순간 가볍게 한 번
        let over: Bool = x < -reveal / 2
        if over != armed {
            armed = over
            if over && settled == 0 { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
        }
    }

    private func dragEnded(_ dx: CGFloat) {
        let x = settled + dx
        armed = false
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
        /// 가로로 밀 때만 시작 (세로는 스크롤에 양보).
        /// 움직인 거리로 판단 — 천천히 밀면 속도가 0 에 가까워 못 잡고, 그러면 카드가 눌린 것으로 처리돼 화면이 잘못 열렸음
        func gestureRecognizerShouldBegin(_ g: UIGestureRecognizer) -> Bool {
            guard let p = g as? UIPanGestureRecognizer else { return false }
            let t: CGPoint = p.translation(in: p.view)
            if abs(t.x) + abs(t.y) >= 2 { return abs(t.x) > abs(t.y) }
            let v: CGPoint = p.velocity(in: p.view)
            return abs(v.x) > abs(v.y)
        }
    }
}

// MARK: - 테두리를 따라 도는 빛

/// 카드 테두리를 따라 밝은 빛이 도는 효과.
/// once = 화면에 나타날 때마다 한 바퀴 돌고 멈춤 / loop = 천천히 계속 / off = 빛 없음(테두리만).
/// "동작 줄이기"를 켠 사람에게는 빛이 돌지 않음
struct BorderLight: ViewModifier {
    enum Mode: Equatable { case off, once, loop }

    /// 고정 테두리 (nil 이면 따로 그리지 않음 — 카드가 이미 테두리를 그렸을 때)
    var border: AnyShapeStyle? = nil
    let light: Color
    var radius: CGFloat = 20
    var mode: Mode
    /// 시작을 늦춤 (위 카드의 빛이 끝날 즈음 이어서 돌게)
    var delay: Double = 0
    var lineWidth: CGFloat = 1.5

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @State private var angle: Double = -90
    @State private var shine: Double = 0
    /// 예약해 둔 시작이 낡았는지 확인하는 번호 (다시 시작하면 올라감)
    @State private var run: Int = 0

    private var moving: Bool { mode != .off && !reduceMotion }
    /// 앱을 켠 때 (이 값을 처음 읽는 때 = 홈 화면을 처음 그릴 때)
    static let launched = Date()

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        return content
            .overlay {
                if let border {
                    shape.strokeBorder(border, lineWidth: lineWidth).allowsHitTesting(false)
                }
            }
            .overlay {
                if moving {
                    GeometryReader { g in
                        let side: CGFloat = max(1, hypot(g.size.width, g.size.height))
                        // 한 구간만 밝은 원뿔 그라데이션을 돌리고, 테두리 모양으로 잘라 냄
                        AngularGradient(stops: [.init(color: light.opacity(0), location: 0),
                                                .init(color: light.opacity(0), location: 0.70),
                                                .init(color: light.opacity(0.55), location: 0.86),
                                                .init(color: light, location: 0.955),
                                                .init(color: Color.white, location: 0.985),
                                                .init(color: light.opacity(0), location: 1)],
                                        center: .center)
                            .frame(width: side, height: side)
                            .rotationEffect(.degrees(angle))
                            .position(x: g.size.width / 2, y: g.size.height / 2)
                    }
                    .mask { shape.strokeBorder(lineWidth: lineWidth) }
                    .opacity(shine)
                    .allowsHitTesting(false)
                }
            }
            .onAppear { start() }
            .onChange(of: mode) { _, _ in start() }
            .onChange(of: scenePhase) { _, p in if p == .active { start() } }
    }

    private func start() {
        guard moving else { return }
        run += 1
        let mine: Int = run
        let m: Mode = mode
        // 처음 자리로 (움직임 없이)
        var t = Transaction()
        t.disablesAnimations = true
        withTransaction(t) { angle = -90; shine = 0 }
        // 앱을 막 켰을 때는 가운데 로고가 화면을 가리고 있으므로(약 1.7초) 그 뒤에 시작
        let logo: Double = Demo.enabled ? 0 : max(0, 1.8 - Date().timeIntervalSince(BorderLight.launched))
        DispatchQueue.main.asyncAfter(deadline: .now() + (delay + logo + 0.05)) {
            guard mine == run else { return }
            if m == .loop {
                withAnimation(.easeOut(duration: 0.4)) { shine = 1 }
                withAnimation(.linear(duration: 6).repeatForever(autoreverses: false)) { angle = 270 }
            } else {
                withAnimation(.easeOut(duration: 0.25)) { shine = 1 }
                withAnimation(.easeInOut(duration: 2.6)) { angle = 270 }
                withAnimation(.easeOut(duration: 0.5).delay(2.2)) { shine = 0 }
            }
        }
    }
}

extension PFTGrade {
    /// 등급 색 테두리 (왼쪽 위가 진하고 오른쪽 아래로 옅어짐) — PFT 기록 카드와 홈 프로필 카드가 같이 씀
    var borderStyle: AnyShapeStyle {
        AnyShapeStyle(LinearGradient(stops: [.init(color: Color(hex: hex1, alpha: 0.9), location: 0),
                                             .init(color: Color(hex: hex2, alpha: 0.25), location: 0.45),
                                             .init(color: Color.white.opacity(0.08), location: 1)],
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
    }
}

/// 홈 프로필 카드: PFT 등급이 있으면 그 색 테두리. 골드는 홈에 들어올 때마다 빛이 테두리를 한 바퀴 돎
struct GradeBorder: ViewModifier {
    let grade: PFTGrade?

    func body(content: Content) -> some View {
        if let g = grade {
            content.modifier(BorderLight(border: g.borderStyle, light: Color(hex: g.hex1), radius: 20,
                                         mode: g == .gold ? BorderLight.Mode.once : BorderLight.Mode.off))
        } else {
            content
        }
    }
}

// MARK: - 빛 색 고르기

/// 배경 빛 색 동그라미 6개 (고른 것은 흰 테두리). 설정 > Theme 와 공유 그림 Block · Ticket 의 Glow 에 같이 씀
struct GlowSwatches: View {
    let selected: GlowTheme
    var size: CGFloat = 24
    var spacing: CGFloat = 6
    var idPrefix: String = "glow"
    let onPick: (GlowTheme) -> Void

    var body: some View {
        HStack(spacing: spacing) {
            ForEach(GlowTheme.allCases, id: \.self) { t in
                swatch(t)
            }
        }
    }

    private func swatch(_ t: GlowTheme) -> some View {
        let on: Bool = t == selected
        return Button { onPick(t) } label: {
            Circle().fill(Color(hex: t.hex))
                .frame(width: size, height: size)
                .padding(4)
                .overlay(Circle().strokeBorder(on ? Color.white : Color.white.opacity(0.14), lineWidth: on ? 2 : 1))
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(t.label.l10n))
        .accessibilityAddTraits(on ? AccessibilityTraits.isSelected : AccessibilityTraits())
        .accessibilityIdentifier(idPrefix + "." + t.rawValue)
    }
}

// MARK: - 기록 목록 쪽 넘기기 (History)

/// 기록 목록 카드: 한 번에 5줄만 보여 주고, 아래 "‹ 1 / 6 ›" 로 쪽을 넘김 (목록이 끝없이 길어지지 않게).
/// 5개 이하면 넘기는 줄이 없음. 화면을 떠났다 오면 1쪽으로 돌아옴.
/// ids = 기록 id 전체(최신순). row(전체에서 몇 번째인지, 아래 선을 뺄지)
struct PagedCard<Row: View>: View {
    let ids: [UUID]
    @ViewBuilder let row: (_ index: Int, _ last: Bool) -> Row

    @State private var page = 0
    /// 5줄이 다 찼을 때의 높이 — 마지막 쪽이 5줄보다 적어도 카드 길이가 변하지 않게
    @State private var fullH: CGFloat = 0

    private struct Line: Identifiable { let i: Int; let id: UUID }

    var body: some View {
        let size: Int = Paging.size
        let pages: Int = Paging.pages(ids.count)
        let p: Int = min(max(0, page), pages - 1)
        let lo: Int = p * size
        let hi: Int = min(ids.count, lo + size)
        let lines: [Line] = (lo..<hi).map { Line(i: $0, id: ids[$0]) }
        VStack(spacing: 0) {
            VStack(spacing: 0) {
                ForEach(lines) { l in
                    row(l.i, pages == 1 && l.i == hi - 1)
                }
            }
            .background {
                // 5줄이 다 찬 쪽의 높이를 기억
                GeometryReader { g in
                    let full: Bool = lines.count == size
                    Color.clear
                        .onAppear { if full && g.size.height > fullH { fullH = g.size.height } }
                        .onChange(of: g.size.height) { _, hgt in if full && hgt > fullH { fullH = hgt } }
                }
            }
            .frame(minHeight: pages > 1 && fullH > 0 ? fullH : nil, alignment: .top)
            if pages > 1 { pager(p, pages) }
        }
        .card8()
    }

    private func pager(_ p: Int, _ pages: Int) -> some View {
        HStack(spacing: 22) {
            arrow("chevron.left", on: p > 0, id: "pager.prev") { page = p - 1 }
            (Text(verbatim: "\(p + 1)").foregroundColor(.white).fontWeight(.semibold)
                + Text(verbatim: " / \(pages)").foregroundColor(C.text2))
                .font(F.num(14, .regular)).lineLimit(1)
                .frame(minWidth: 52)
                .accessibilityIdentifier("pager.label")
            arrow("chevron.right", on: p < pages - 1, id: "pager.next") { page = p + 1 }
        }
        .frame(maxWidth: .infinity).frame(height: 52)
    }

    private func arrow(_ name: String, on: Bool, id: String, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: name).font(.system(size: 13, weight: .semibold))
                .foregroundStyle(on ? C.accent : Color(hex: 0x4A4A4A))
                .frame(width: 34, height: 34)
                .background(Color.white.opacity(on ? 0.08 : 0.04), in: Circle())
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(Press(scale: 0.92))
        .disabled(!on)
        .accessibilityIdentifier(id)
    }
}

enum Paging {
    static let size = 5
    static func pages(_ n: Int) -> Int { max(1, (n + size - 1) / size) }
}
