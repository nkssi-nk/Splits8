import SwiftUI

// MARK: - 1.2.7 워치 화면 자리 맞추기 (시안과 똑같은 계산)
// 시안(파이썬 그림)은 글자를 "대문자 높이"로 재서 쌓고, 묶음을 칸의 세로 가운데에 놓음.
// SF Pro 는 글자 틀(줄 높이)의 가운데 ≈ 대문자의 가운데 → 글자는 대문자 가운데 y 에 .position 으로 놓음.
// 모든 값은 46mm(208×248) pt. 위에서 재는 값은 W8Scale.t(), 아래에서 재는 값은 W8Scale.b().

extension W8Scale {
    /// 위에서 잰 자리 (시계 줄 · 제목 줄은 화면 위에 붙어 있음)
    func t(_ v: CGFloat) -> CGFloat { v * s }
    /// 아래에서 잰 자리 (버튼)
    func b(_ v: CGFloat) -> CGFloat { h - v * s }
    var cx: CGFloat { w / 2 }
}

/// 대문자 높이 (SF Pro ≈ 0.71)
func w8Cap(_ size: CGFloat) -> CGFloat { size * 0.71 }

/// 쌓을 것 하나
enum W8Part {
    /// 글자 한 줄 (size pt, 가운데)
    case text(String, size: CGFloat, weight: Font.Weight = .semibold, color: Color = .white, num: Bool = false, gap: CGFloat = 0)
    /// 귀퉁이 표시 블록: 이름표 · 큰 숫자 · (작은 말)
    case block(label: String, value: String, word: String? = nil, color: Color = .white,
               labelSize: CGFloat = 11, valueSize: CGFloat = 38, wordSize: CGFloat = 11,
               inner: CGFloat = 8, pad: CGFloat = 12, gap: CGFloat = 0, onTap: (() -> Void)? = nil)
    /// 두 칸 (이름표 · 값)
    case cols([(String, String)], labelSize: CGFloat = 10, valueSize: CGFloat = 17, inner: CGFloat = 7, gap: CGFloat = 0, onTap: ((Int) -> Void)? = nil)
    /// 그 밖의 것 (높이를 직접)
    case view(height: CGFloat, gap: CGFloat = 0, AnyView)

    var gap: CGFloat {
        switch self {
        case .text(_, _, _, _, _, let g): return g
        case .block(_, _, _, _, _, _, _, _, _, let g, _): return g
        case .cols(_, _, _, _, let g, _): return g
        case .view(_, let g, _): return g
        }
    }

    var height: CGFloat {
        switch self {
        case .text(_, let size, _, _, _, _): return w8Cap(size)
        case .block(_, _, let word, _, let ls, let vs, let ws, let inner, let pad, _, _):
            var h: CGFloat = pad + w8Cap(ls) + inner + w8Cap(vs) + pad
            if let word, !word.isEmpty { h += inner + w8Cap(ws) }
            return h
        case .cols(_, let ls, let vs, let inner, _, _): return w8Cap(ls) + inner + w8Cap(vs)
        case .view(let h, _, _): return h
        }
    }
}

/// 묶음 전체를 top ~ bottom (절대 y, 이미 W8Scale 로 바꾼 값) 의 세로 가운데에 놓음
struct W8Stack: View {
    let L: W8Scale
    let parts: [W8Part]
    let top: CGFloat
    let bottom: CGFloat
    var ink: Color = .white
    var label: Color = Color.white.opacity(0.65)
    var word: Color = Color.white.opacity(0.55)
    var mark: Color = Color.white.opacity(0.47)
    var shadow: Color = .clear

    var body: some View {
        let s: CGFloat = L.s
        let hs: [CGFloat] = parts.map { $0.height * s }
        let gs: [CGFloat] = parts.enumerated().map { $0.offset == 0 ? 0 : $0.element.gap * s }
        let total: CGFloat = hs.reduce(0, +) + gs.reduce(0, +)
        var ys: [CGFloat] = []
        var y: CGFloat = (top + bottom) / 2 - total / 2
        for i in parts.indices { y += gs[i]; ys.append(y); y += hs[i] }
        return ZStack {
            ForEach(parts.indices, id: \.self) { i in
                part(parts[i], y: ys[i], s: s)
            }
        }
        .frame(width: L.w, height: L.h)
    }

    @ViewBuilder
    private func part(_ p: W8Part, y: CGFloat, s: CGFloat) -> some View {
        switch p {
        case .text(let t, let size, let weight, let color, let isNum, _):
            Text(verbatim: t.l10n)
                .font(isNum ? F.num(size * s, weight) : F.t(size * s, weight))
                .foregroundStyle(color)
                .lineLimit(1).minimumScaleFactor(0.6)
                .frame(width: L.w - 32 * s)
                .shadow(color: shadow, radius: 3.5 * s, y: 2 * s)
                .position(x: L.cx, y: y + w8Cap(size) * s / 2)
        case .block(let lab, let val, let wd, let color, let ls, let vs, let ws, let inner, let pad, _, let onTap):
            let h: CGFloat = p.height * s
            let ly: CGFloat = y + pad * s + w8Cap(ls) * s / 2
            let vy: CGFloat = y + (pad + w8Cap(ls) + inner) * s + w8Cap(vs) * s / 2
            let wy: CGFloat = y + (pad + w8Cap(ls) + inner + w8Cap(vs) + inner) * s + w8Cap(ws) * s / 2
            ZStack {
                W8Brackets(arm: 9 * s)
                    .stroke(mark, style: StrokeStyle(lineWidth: 2.6 * s, lineCap: .round, lineJoin: .round))
                    .frame(width: L.w - 32 * s, height: h)
                    .position(x: L.cx, y: y + h / 2)
                Group {
                    Text(verbatim: lab.l10n).font(F.t(ls * s, .bold)).tracking(0.6).foregroundStyle(label)
                        .lineLimit(1).minimumScaleFactor(0.6)
                        .position(x: L.cx, y: ly)
                    Text(verbatim: val).font(F.num(vs * s, .bold)).foregroundStyle(color)
                        .lineLimit(1).minimumScaleFactor(30 / 44)
                        .frame(width: L.w - 62 * s)
                        .contentTransition(.numericText())
                        .position(x: L.cx, y: vy)
                    if let wd, !wd.isEmpty {
                        Text(verbatim: wd.l10n).font(F.t(ws * s, .bold)).tracking(0.6).foregroundStyle(word)
                            .lineLimit(1).minimumScaleFactor(0.6)
                            .frame(width: L.w - 40 * s)
                            .position(x: L.cx, y: wy)
                    }
                }
                .shadow(color: shadow, radius: 3.5 * s, y: 2 * s)
                if let onTap {
                    Color.clear.contentShape(Rectangle())
                        .frame(width: L.w - 32 * s, height: h)
                        .position(x: L.cx, y: y + h / 2)
                        .onTapGesture(perform: onTap)
                }
            }
        case .cols(let cols, let ls, let vs, let inner, _, let onTap):
            let n: Int = max(1, cols.count)
            let cw: CGFloat = (L.w - 32 * s) / CGFloat(n)
            ZStack {
                ForEach(cols.indices, id: \.self) { i in
                    let cx: CGFloat = 16 * s + cw * (CGFloat(i) + 0.5) + (L.w - 208 * s) / 2
                    Text(verbatim: cols[i].0.l10n).font(F.t(ls * s, .bold)).tracking(0.6).foregroundStyle(label)
                        .lineLimit(1).minimumScaleFactor(0.6).frame(width: cw - 4)
                        .position(x: cx, y: y + w8Cap(ls) * s / 2)
                    Text(verbatim: cols[i].1).font(F.num(vs * s, .semibold)).foregroundStyle(ink)
                        .lineLimit(1).minimumScaleFactor(0.55).frame(width: cw - 4)
                        .contentTransition(.numericText())
                        .position(x: cx, y: y + (w8Cap(ls) + inner) * s + w8Cap(vs) * s / 2)
                    if let onTap {
                        Color.clear.contentShape(Rectangle())
                            .frame(width: cw, height: (w8Cap(ls) + inner + w8Cap(vs) + 12) * s)
                            .position(x: cx, y: y + (w8Cap(ls) + inner + w8Cap(vs)) * s / 2)
                            .onTapGesture { onTap(i) }
                    }
                }
            }
            .shadow(color: shadow, radius: 3.5 * s, y: 2 * s)
        case .view(let h, _, let v):
            v.frame(width: L.w, height: h * s).position(x: L.cx, y: y + h * s / 2)
        }
    }
}

/// 메뉴 · 시작 전 · 끝 화면 틀: 화면 전체를 자리로 씀 (내비게이션 위 여백 무시)
struct W8Canvas<Content: View>: View {
    @ViewBuilder let content: (W8Scale) -> Content

    var body: some View {
        GeometryReader { g in
            content(W8Scale(w: g.size.width, h: g.size.height))
                .frame(width: g.size.width, height: g.size.height)
        }
        .ignoresSafeArea()
    }
}

/// 제목 (노랑 15, 대문자 가운데 y 41 — 시계 줄 아래)
struct W8TitleAt: View {
    let L: W8Scale
    let title: String
    var body: some View {
        Text(verbatim: title.l10n)
            .font(F.t(15 * L.s, .semibold)).foregroundStyle(C.accent)
            .lineLimit(1).minimumScaleFactor(11 / 15)
            .frame(width: L.w - 32 * L.s)
            .position(x: L.cx, y: L.t(41))
    }
}

/// 아래 큰 버튼 자리 (높이 40 · 아래 12 · 좌우 12). row = 0 맨 아래 줄, 1 그 위 줄 (사이 6)
extension W8Scale {
    var btnH: CGFloat { 40 * s }
    func btnY(_ row: Int = 0) -> CGFloat { h - (12 + 20) * s - CGFloat(row) * 46 * s }
    var btnTop: CGFloat { h - 52 * s }
    var btnW: CGFloat { w - 24 * s }
    var halfW: CGFloat { (w - 24 * s - 6 * s) / 2 }
}
