import SwiftUI

// MARK: - 색 (design_tokens.json)

extension Color {
    init(hex: UInt32, alpha: Double = 1) {
        self.init(.sRGB,
                  red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255,
                  opacity: alpha)
    }
}

enum C {
    static let bg = Color.black
    static let accent = Color(hex: 0xFFE600)
    static let onAccent = Color.black
    static let text = Color.white
    static let text2 = Color(hex: 0x8E8E93)
    static let text3 = Color(hex: 0x6E6E73)
    static let good = Color(hex: 0x30D158)
    static let bad = Color(hex: 0xFF453A)
    static let hr = Color(hex: 0xFF453A)

    // 아이폰 카드
    static let card = Color.white.opacity(0.06)
    static let cardBorder = Color.white.opacity(0.08)
    static let line = Color.white.opacity(0.08)
    static let segTrack = Color.white.opacity(0.08)
    static let segOn = Color(hex: 0x2C2C2E)
    static let control = Color(hex: 0x2C2C2E)
    static let btn1A = Color(hex: 0x1A1A1A)
    static let chev = Color(hex: 0x48484C)
    static let d1 = Color(hex: 0xD1D1D6)
    static let aeb = Color(hex: 0xAEAEB2)
    static let g3A = Color(hex: 0x3A3A3C)

    // 워치 카드
    static let wCard = Color(hex: 0x151515)
    static let wBorder = Color(hex: 0x222222)

    static let zones: [Color] = [Color(hex: 0x8E8E93), Color(hex: 0x0A84FF), Color(hex: 0x30D158),
                                 Color(hex: 0xFF9F0A), Color(hex: 0xFF453A)]
    static let zoneHex: [UInt32] = [0x8E8E93, 0x0A84FF, 0x30D158, 0xFF9F0A, 0xFF453A]
    static func zone(_ z: Int) -> Color { zones[max(1, min(5, z)) - 1] }
}

// MARK: - 글꼴

enum F {
    /// SF Pro (Text/Display 자동). tracking 은 em 단위 → pt 로 바꿔서 .tracking()
    static func t(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font { .system(size: size, weight: weight) }
    /// 숫자 (SF Pro Display Semibold, 고정폭)
    static func num(_ size: CGFloat, _ weight: Font.Weight = .semibold) -> Font {
        .system(size: size, weight: weight).monospacedDigit()
    }
    /// 워치 숫자 — 사용자 요청으로 둥근 글꼴(Rounded) 대신 SF Pro 고정폭 숫자
    static func round(_ size: CGFloat, _ weight: Font.Weight = .semibold) -> Font {
        .system(size: size, weight: weight).monospacedDigit()
    }
}

extension View {
    /// CSS letter-spacing (em)
    func em(_ v: CGFloat, _ size: CGFloat) -> some View { tracking(v * size) }
}

/// 대문자 라벨 (11pt semibold, 자간 0.1em, 회색)
struct Label8: View {
    let text: String
    var size: CGFloat = 11
    var color: Color = C.text2
    var spacing: CGFloat = 0.1
    var weight: Font.Weight = .semibold
    init(_ text: String, size: CGFloat = 11, color: Color = C.text2, spacing: CGFloat = 0.1, weight: Font.Weight = .semibold) {
        self.text = text; self.size = size; self.color = color; self.spacing = spacing; self.weight = weight
    }
    var body: some View {
        Text(text).font(F.t(size, weight)).tracking(spacing * size).foregroundStyle(color).lineLimit(1)
    }
}

// MARK: - 워드마크 SPLITS8

struct Wordmark: View {
    var size: CGFloat
    var eightColor: Color = C.accent
    var color: Color = .white
    var tracking: CGFloat = -0.02
    var weight: Font.Weight = .heavy
    var body: some View {
        HStack(spacing: 0) {
            Text("SPLITS").foregroundStyle(color)
            Text("8").foregroundStyle(eightColor).padding(.leading, size * 0.08)
        }
        .font(.system(size: size, weight: weight))
        .tracking(tracking * size)
        .lineLimit(1)
        .fixedSize()
    }
}

// MARK: - 배경 빛 (CSS radial-gradient 재현)

/// radial-gradient(RX% RY% at CX% CY%, color alpha, transparent 70%)
struct Ambient: Equatable {
    var hex: UInt32
    var alpha: Double
    var rx: CGFloat, ry: CGFloat     // 반지름 (화면 너비·높이 대비)
    var cx: CGFloat, cy: CGFloat     // 중심 (0~1)
    var linear: Bool = false         // linear-gradient(180deg, color, transparent 40%)

    static let none = Ambient(hex: 0, alpha: 0, rx: 1, ry: 1, cx: 0.5, cy: 0.5)
    static func y(_ a: Double, _ rx: CGFloat, _ ry: CGFloat, _ cx: CGFloat, _ cy: CGFloat) -> Ambient {
        Ambient(hex: 0xFFE600, alpha: a, rx: rx, ry: ry, cx: cx, cy: cy)
    }
}

struct AmbientLayer: View {
    let a: Ambient
    var body: some View {
        GeometryReader { g in
            let w = g.size.width, h = g.size.height
            if a.alpha <= 0 {
                Color.clear
            } else if a.linear {
                LinearGradient(stops: [.init(color: Color(hex: a.hex, alpha: a.alpha), location: 0),
                                       .init(color: Color(hex: a.hex, alpha: 0), location: 0.4)],
                               startPoint: .top, endPoint: .bottom)
            } else {
                let rx = max(1, a.rx * w), ry = max(1, a.ry * h)
                RadialGradient(stops: [.init(color: Color(hex: a.hex, alpha: a.alpha), location: 0),
                                       .init(color: Color(hex: a.hex, alpha: 0), location: 0.7)],
                               center: .center, startRadius: 0, endRadius: ry)
                    .frame(width: ry * 2, height: ry * 2)
                    .scaleEffect(x: rx / ry, y: 1)
                    .position(x: a.cx * w, y: a.cy * h)
            }
        }
        .allowsHitTesting(false)
        .ignoresSafeArea()
    }
}

// MARK: - 아이콘 (icons5, 흰색 원본을 색칠해서 씀)

enum IconTint {
    case white, yellow, mute, dim, black
    var color: Color {
        switch self {
        case .white: return .white
        case .yellow: return C.accent
        case .mute: return C.text2
        case .dim: return C.text3
        case .black: return .black
        }
    }
}

/// 스테이션·모드 아이콘. name = run, skiErg, … , modeTraining, modeSim, modeRace, heart 등
struct Icon8: View {
    let name: String
    var size: CGFloat
    var color: Color = .white
    init(_ name: String, _ size: CGFloat, _ color: Color = .white) {
        self.name = name; self.size = size; self.color = color
    }
    init(_ name: String, _ size: CGFloat, tint: IconTint) {
        self.name = name; self.size = size; self.color = tint.color
    }
    var body: some View {
        Image(name)
            .renderingMode(.template)
            .resizable()
            .interpolation(.high)
            .scaledToFit()
            .frame(width: size, height: size)
            .foregroundStyle(color)
    }
}

// MARK: - 시간 형식

enum Fm {
    /// 1:15:03 / 4:21
    static func t(_ s: Int) -> String {
        let s = max(0, s)
        let h = s / 3600, m = (s % 3600) / 60, x = s % 60
        return h > 0 ? String(format: "%d:%02d:%02d", h, m, x) : String(format: "%d:%02d", m, x)
    }
    static func t(_ s: Double) -> String { t(Int(s.rounded(.down))) }
    /// ±0:00 / −0:27 / +2:46
    static func d(_ v: Int) -> String { v == 0 ? "±0:00" : (v < 0 ? "−" : "+") + t(abs(v)) }

    static let gb = Locale(identifier: "en_GB")
    private static func df(_ f: String) -> DateFormatter {
        let d = DateFormatter(); d.locale = gb; d.dateFormat = f; return d
    }
    /// Wed 24 Sep
    static let wdm = df("EEE dd MMM")
    /// Sat 13 Sep 2026
    static let wdmy = df("EEE dd MMM yyyy")
    /// 13 Sep 2026
    static let dmy = df("d MMM yyyy")
    /// 20 Sep 2026 (두 자리 일)
    static let ddmy = df("dd MMM yyyy")
    /// 14 JUN (그래프 축)
    static func axis(_ d: Date) -> String { df("dd MMM").string(from: d).uppercased() }
    /// 28 Sep
    static let dm = df("d MMM")
    /// Sep
    static let mon = df("MMM")
    static let ymd = df("yyyy-MM-dd")
    static let hm = df("HH:mm")
    static let clock: DateFormatter = { let d = DateFormatter(); d.dateFormat = "H:mm"; return d }()
}
