import SwiftUI

// MARK: - 1.2.7 워치 새 디자인 공통 (대표님 11-20 확정)
// 운동 중: 스테이션 · 운동 = 노랑 / 러닝 · 빠르게 = 파랑 / Roxzone · 휴식 = 회색. 뒤에 흐린 덩어리가 비침 (리퀴드 글라스 느낌).
// 메뉴 · 시작 전 · 끝: 검정 + 테마 빛 색 덩어리. 버튼은 모두 유리 (노랑 주 버튼도 유리).
// 값은 프로젝트 문서 splits8-1.2.7-수정목록.md 2번 · -워치-넘김화면.md · -워치-메뉴화면.md (46mm 208×248 기준 pt).

/// 구간 색
enum W8Tone: Equatable {
    case station, run, gray

    static func of(_ s: Seg) -> W8Tone {
        if s.kind == .rox { return .gray }
        return s.icon == "run" ? .run : .station
    }

    /// 노랑 위는 검정 글자, 파랑 · 회색 위는 흰 글자
    var dark: Bool { self == .station }
    var ink: Color { dark ? .black : .white }
    /// 보조 글자 (검정 53% / 흰 65%)
    var sub: Color { dark ? Color.black.opacity(0.53) : Color.white.opacity(0.65) }
    /// 이름표 (검정 59% / 흰 69%)
    var label: Color { dark ? Color.black.opacity(0.59) : Color.white.opacity(0.69) }
    /// 귀퉁이 표시
    var mark: Color { dark ? Color.black.opacity(0.92) : Color.black.opacity(0.59) }
    /// 글자 그림자
    var shadow: Color { dark ? Color(red: 120 / 255, green: 80 / 255, blue: 0).opacity(0.22) : Color.black.opacity(0.35) }
    /// 유리 버튼 바탕 (흰 반투명)
    var glass: Double { dark ? 0.27 : 0.18 }
    /// 남은 점
    var dotOff: Color { dark ? Color.black.opacity(0.24) : Color.black.opacity(0.49) }

    /// 바탕 그라데이션 (위 → 아래)
    var stops: [Color] {
        switch self {
        case .station: return [Color(hex: 0xFFE600), Color(hex: 0xFFDE00), Color(hex: 0xFFD600)]
        case .run: return [Color(hex: 0x1E78FA), Color(hex: 0x186AF1), Color(hex: 0x125CE8)]
        case .gray: return [Color(hex: 0x54545C), Color(hex: 0x494951), Color(hex: 0x3E3E46)]
        }
    }
    /// 가장자리 살짝 어둡게
    var edge: Color { self == .station ? Color(hex: 0xE1A000) : .black }
    /// 뒤에 비치는 덩어리 색 · 진하기
    var blob: Color { self == .station ? Color(hex: 0xC87800) : .black }
    var blobAlpha: Double { self == .station ? 0.45 : 0.26 }

    /// 심박 Z4 · Z5 바탕 (Roxzone · 휴식은 안 바뀜). 위 · 가운데 · 아래와 가운데 자리
    func zoneStops(_ z: Int) -> (colors: [Color], mid: CGFloat)? {
        switch (self, z) {
        case (.station, 4): return ([Color(hex: 0xFFE200), Color(hex: 0xFFBE0A), Color(hex: 0xFF8C14)], 0.55)
        case (.station, 5): return ([Color(hex: 0xFFDE00), Color(hex: 0xFF9614), Color(hex: 0xF03223)], 0.45)
        case (.run, 4): return ([Color(hex: 0x1E78FA), Color(hex: 0x2869EB), Color(hex: 0xFF8C1E)], 0.62)
        case (.run, 5): return ([Color(hex: 0x1E78FA), Color(hex: 0x786EBE), Color(hex: 0xFF7814)], 0.40)
        default: return nil
        }
    }
}

/// 46mm 기준 크기를 화면에 맞춤
struct W8Scale {
    let w: CGFloat, h: CGFloat
    var s: CGFloat { min(w / 208, h / 248) }
    func x(_ v: CGFloat) -> CGFloat { v * s + (w - 208 * s) / 2 }
    func y(_ v: CGFloat) -> CGFloat { v * s + (h - 248 * s) / 2 }
    func v(_ v: CGFloat) -> CGFloat { v * s }
}

// MARK: 바탕

/// 운동 중 바탕: 그라데이션 + 가장자리 + 흐린 덩어리 (구간마다 새 모양) + 심박 Z4 · Z5 색
struct W8Background: View {
    let tone: W8Tone
    var zone: Int = 0
    var seed: Int = 0
    var dim: Bool = false
    var darker: Double = 0          // 조작 화면은 조금 어둡게 (0.12)

    var body: some View {
        if dim {
            Color.black
        } else {
            ZStack {
                LinearGradient(colors: tone.stops, startPoint: .top, endPoint: .bottom)
                // 심박 Z4 · Z5: 겹쳐 놓고 투명도만 천천히 바꿈 (1초)
                ForEach([4, 5], id: \.self) { z in
                    if let zs = tone.zoneStops(z) {
                        LinearGradient(stops: [.init(color: zs.colors[0], location: 0),
                                               .init(color: zs.colors[1], location: zs.mid),
                                               .init(color: zs.colors[2], location: 1)],
                                       startPoint: .top, endPoint: .bottom)
                            .opacity(zone == z ? 1 : 0)
                    }
                }
                .animation(.easeInOut(duration: 1.0), value: zone)
                // 가장자리
                GeometryReader { g in
                    RoundedRectangle(cornerRadius: g.size.width * 0.2, style: .continuous)
                        .strokeBorder(tone.edge, lineWidth: g.size.width * 0.09)
                        .blur(radius: g.size.width * 0.05)
                        .opacity(0.27)
                }
                W8Blobs(seed: seed, color: tone.blob, alpha: tone.blobAlpha)
                    .id(seed)
                    .transition(.opacity.animation(.easeInOut(duration: 0.6)))
                if darker > 0 { Color.black.opacity(darker) }
            }
            .compositingGroup()
        }
    }
}

/// 흐린 덩어리 2~4개 (같은 seed 는 같은 모양)
struct W8Blobs: View {
    let seed: Int
    let color: Color
    let alpha: Double
    var blurPt: CGFloat = 14

    private struct Blob { let x: CGFloat, y: CGFloat, r: CGFloat, a: Double }

    private var blobs: [Blob] {
        var g = W8Rand(seed: UInt64(seed &* 7919 &+ 17))
        let n: Int = 2 + Int(g.next() % 3)
        return (0..<n).map { _ in
            Blob(x: 0.05 + 0.9 * g.unit(), y: 0.1 + 0.85 * g.unit(), r: 0.18 + 0.22 * g.unit(), a: 0.6 + 0.4 * g.unit())
        }
    }

    var body: some View {
        GeometryReader { geo in
            let w: CGFloat = geo.size.width, h: CGFloat = geo.size.height
            ZStack {
                ForEach(Array(blobs.enumerated()), id: \.offset) { _, b in
                    Circle()
                        .fill(color.opacity(alpha * b.a))
                        .frame(width: w * b.r * 2, height: w * b.r * 2)
                        .position(x: w * b.x, y: h * b.y)
                }
            }
            .blur(radius: blurPt * min(w / 208, 1.3))
        }
        .allowsHitTesting(false)
    }
}

/// 같은 seed → 같은 수 (SplitMix64)
struct W8Rand {
    private var state: UInt64
    init(seed: UInt64) { state = seed &+ 0x9E37_79B9_7F4A_7C15 }
    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z: UInt64 = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
    mutating func unit() -> CGFloat { CGFloat(next() % 10_000) / 10_000 }
}

/// 메뉴 · 시작 전 · 끝 바탕: 검정 + 테마 빛 색(아이폰 설정 > Theme) 흐린 덩어리
struct W8MenuBackground: View {
    var seed: Int = 40

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(hex: 0x0E0E10), Color(hex: 0x08080A)], startPoint: .top, endPoint: .bottom)
            W8Blobs(seed: seed, color: Color(hex: GlowTheme.current.hex),
                    alpha: min(0.5, 0.30 * GlowTheme.current.gain), blurPt: 16)
        }
        .ignoresSafeArea()
    }
}

// MARK: 귀퉁이 표시 (뷰파인더)

struct W8Brackets: Shape {
    var arm: CGFloat = 9

    func path(in r: CGRect) -> Path {
        var p = Path()
        let a: CGFloat = min(arm, r.width / 3, r.height / 3)
        // 왼쪽 위
        p.move(to: CGPoint(x: r.minX, y: r.minY + a)); p.addLine(to: CGPoint(x: r.minX, y: r.minY)); p.addLine(to: CGPoint(x: r.minX + a, y: r.minY))
        // 오른쪽 위
        p.move(to: CGPoint(x: r.maxX - a, y: r.minY)); p.addLine(to: CGPoint(x: r.maxX, y: r.minY)); p.addLine(to: CGPoint(x: r.maxX, y: r.minY + a))
        // 왼쪽 아래
        p.move(to: CGPoint(x: r.minX, y: r.maxY - a)); p.addLine(to: CGPoint(x: r.minX, y: r.maxY)); p.addLine(to: CGPoint(x: r.minX + a, y: r.maxY))
        // 오른쪽 아래
        p.move(to: CGPoint(x: r.maxX - a, y: r.maxY)); p.addLine(to: CGPoint(x: r.maxX, y: r.maxY)); p.addLine(to: CGPoint(x: r.maxX, y: r.maxY - a))
        return p
    }
}

// MARK: 아이콘

/// 되돌리기 (대표님 참고 그림: 왼쪽 큰 화살촉 + 위 막대 + 오른쪽 반원 + 아래 막대, 굵은 채움)
struct W8UndoIcon: View {
    var size: CGFloat
    var color: Color

    var body: some View {
        Canvas { ctx, sz in
            // 원본 그림 좌표 (가로 48~303, 세로 38~258) → 가운데 맞춤
            let sc: CGFloat = sz.width / 270
            let ox: CGFloat = sz.width / 2 - 175.5 * sc
            let oy: CGFloat = sz.height / 2 - 148 * sc
            func P(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: ox + x * sc, y: oy + y * sc) }
            let shading: GraphicsContext.Shading = .color(color)
            // 화살촉 (끝을 둥글게: 둥근 선으로 한 번 더 그림)
            var tri = Path()
            tri.move(to: P(63, 106)); tri.addLine(to: P(132, 53)); tri.addLine(to: P(132, 159)); tri.closeSubpath()
            ctx.fill(tri, with: shading)
            ctx.stroke(tri, with: shading, style: StrokeStyle(lineWidth: 16 * sc, lineJoin: .round))
            // 위 막대
            ctx.fill(Path(CGRect(origin: P(128, 82), size: CGSize(width: 90 * sc, height: 48 * sc))), with: shading)
            // 오른쪽 반원 (바깥 88, 안 40)
            var ring = Path()
            ring.addArc(center: P(215, 170), radius: 64 * sc, startAngle: .degrees(-90), endAngle: .degrees(90), clockwise: false)
            ctx.stroke(ring, with: shading, style: StrokeStyle(lineWidth: 48 * sc, lineCap: .butt))
            // 아래 막대 (왼쪽 끝 살짝 둥글게)
            ctx.fill(Path(roundedRect: CGRect(origin: P(142, 210), size: CGSize(width: 75 * sc, height: 48 * sc)),
                          cornerRadius: 8 * sc), with: shading)
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

/// 다음(→) 화살표 — 막대 + 삼각형 머리
struct W8NextArrow: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        let w: CGFloat = r.width, h: CGFloat = r.height
        let bar: CGFloat = h * 0.27
        p.addRoundedRect(in: CGRect(x: r.minX, y: r.midY - bar / 2, width: w * 0.62, height: bar),
                         cornerSize: CGSize(width: bar * 0.25, height: bar * 0.25))
        p.move(to: CGPoint(x: r.minX + w * 0.48, y: r.minY))
        p.addLine(to: CGPoint(x: r.maxX, y: r.midY))
        p.addLine(to: CGPoint(x: r.minX + w * 0.48, y: r.maxY))
        p.closeSubpath()
        return p
    }
}

/// 일시정지 두 막대 / 다시 시작 세모
struct W8PauseIcon: View {
    var size: CGFloat
    var color: Color
    var paused: Bool = false

    var body: some View {
        Group {
            if paused {
                Image(systemName: "play.fill").font(.system(size: size * 0.8, weight: .bold)).foregroundStyle(color)
            } else {
                HStack(spacing: size * 0.22) {
                    RoundedRectangle(cornerRadius: size * 0.08).fill(color).frame(width: size * 0.24, height: size)
                    RoundedRectangle(cornerRadius: size * 0.08).fill(color).frame(width: size * 0.24, height: size)
                }
            }
        }
        .frame(width: size, height: size)
    }
}

// MARK: 유리

/// 유리 모양 (테두리 선 없이 위쪽만 옅은 가장자리 빛 + 아래 그림자). fill = 바탕 색 (흰 반투명 · 노랑 · 빨강 …)
struct W8Glass<S: InsettableShape>: View {
    let shape: S
    var fill: Color
    var rim: Double = 0.55          // 위쪽 가장자리 빛 (맑은 유리 0.55, 색 유리 0.22)
    var gloss: Double = 0           // 위쪽 절반 윤기 (노란 주 버튼 0.27)
    var dim: Bool = false

    var body: some View {
        ZStack {
            shape.fill(fill)
            if gloss > 0 {
                shape.fill(LinearGradient(stops: [.init(color: .white.opacity(gloss), location: 0),
                                                  .init(color: .white.opacity(0), location: 0.55)],
                                          startPoint: .top, endPoint: .bottom))
            }
            if !dim {
                shape.strokeBorder(LinearGradient(stops: [.init(color: .white.opacity(rim), location: 0),
                                                          .init(color: .white.opacity(0), location: 0.45)],
                                                  startPoint: .top, endPoint: .bottom), lineWidth: 1)
            }
        }
        .compositingGroup()
        .shadow(color: .black.opacity(dim ? 0 : 0.18), radius: 4, x: 0, y: 3)
    }
}

/// 누를 때 살짝 커지면서 밝아짐 (부드러운 스프링)
struct W8Press: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 1.08 : 1)
            .brightness(configuration.isPressed ? 0.12 : 0)
            .animation(.spring(response: 0.28, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

/// 노란 유리 주 버튼 (Start · Set · Done …) — 메뉴 화면용
struct W8PrimaryButton: View {
    let title: String
    var icon: String? = nil
    var height: CGFloat = 40
    var enabled: Bool = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let icon { Image(systemName: icon).font(.system(size: 13, weight: .bold)) }
                Text(title.l10n).font(F.t(15, .semibold)).lineLimit(1).minimumScaleFactor(0.7)
            }
            .foregroundStyle(.black.opacity(enabled ? 1 : 0.4))
            .frame(maxWidth: .infinity).frame(height: height)
            .background(W8Glass(shape: Capsule(), fill: Color(hex: 0xFFDC14).opacity(enabled ? 0.84 : 0.35), rim: 0.47, gloss: 0.27))
            .contentShape(Capsule())
        }
        .buttonStyle(W8Press())
        .disabled(!enabled)
    }
}

/// 맑은 유리 버튼 (Resume · Indoor …) · 빨간 유리 (Discard)
struct W8GlassButton: View {
    let title: String
    var red: Bool = false
    var height: CGFloat = 40
    var fontSize: CGFloat = 15
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title.l10n).font(F.t(fontSize, .semibold)).foregroundStyle(.white)
                .lineLimit(1).minimumScaleFactor(0.7)
                .frame(maxWidth: .infinity).frame(height: height)
                .background(W8Glass(shape: Capsule(), fill: red ? Color(hex: 0xFF3B30).opacity(0.59) : Color.white.opacity(0.13),
                                    rim: red ? 0.22 : 0.55))
                .contentShape(Capsule())
        }
        .buttonStyle(W8Press())
    }
}

// MARK: 메뉴 머리줄 (제목은 시계 줄 아래 가운데 — 뒤로 가기 버튼과 떨어지게)

struct W8MenuTitle: View {
    let title: String
    var body: some View {
        Text(title.l10n)
            .font(F.t(15, .semibold)).foregroundStyle(C.accent)
            .lineLimit(1).minimumScaleFactor(0.73)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 16)
    }
}

/// 메뉴 · 시작 전 · 끝 화면의 큰 숫자 블록 (귀퉁이 표시 안: 이름표 · 숫자 · 작은 말)
struct W8BigBlock: View {
    let label: String
    let value: String
    var word: String? = nil
    var color: Color = .white

    var body: some View {
        VStack(spacing: 8) {
            Text(label.l10n).font(F.t(11, .bold)).tracking(0.6).foregroundStyle(Color.white.opacity(0.65))
                .lineLimit(1).minimumScaleFactor(0.7)
            Text(verbatim: value).font(F.num(38, .bold)).foregroundStyle(color)
                .lineLimit(1).minimumScaleFactor(0.6)
            if let word, !word.isEmpty {
                Text(word.l10n).font(F.t(11, .bold)).tracking(0.5).foregroundStyle(Color.white.opacity(0.55))
                    .lineLimit(1).minimumScaleFactor(0.7)
            }
        }
        .padding(.vertical, 12).padding(.horizontal, 10)
        .frame(maxWidth: .infinity)
        .overlay(W8Brackets(arm: 9).stroke(Color.white.opacity(0.47), style: StrokeStyle(lineWidth: 2.6, lineCap: .round, lineJoin: .round)))
    }
}
