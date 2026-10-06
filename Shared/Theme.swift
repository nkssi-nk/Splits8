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

    // 아이폰 기본 글자 크기 단계 (Apple 기본 Text Style 과 같은 pt). 새 화면은 이 단계만 씀
    static let largeTitle: CGFloat = 34   // 큰 제목
    static let title1: CGFloat = 28
    static let title2: CGFloat = 22
    static let title3: CGFloat = 20       // 카드 제목
    static let body: CGFloat = 17         // 본문 · 목록 이름
    static let callout: CGFloat = 16
    static let sub: CGFloat = 15          // 카드 안 설명 글
    static let foot: CGFloat = 13         // 소제목 · 날짜 · 작은 메모
    static let cap1: CGFloat = 12
    static let cap2: CGFloat = 11         // 가장 작게 (PB 뱃지 · 그래프 눈금 · 요일)
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
    var size: CGFloat = F.foot
    var color: Color = C.text2
    var spacing: CGFloat = 0.06
    var weight: Font.Weight = .semibold
    /// 소제목 (HISTORY · PERSONAL BESTS …) — 아이폰 설정 앱 소제목처럼 13pt
    init(_ text: String, size: CGFloat = F.foot, color: Color = C.text2, spacing: CGFloat = 0.06, weight: Font.Weight = .semibold) {
        self.text = text; self.size = size; self.color = color; self.spacing = spacing; self.weight = weight
    }
    var body: some View {
        Text(text.l10n).font(F.t(size, weight)).tracking(spacing * size).foregroundStyle(color).lineLimit(1)
            .minimumScaleFactor(0.85)
    }
}

// MARK: - 워드마크 SPLITS8

/// SPLITS8 로고 — 글꼴로 그리지 않고 시안 로고 이미지를 씀 (v4: 8이 세로로 갈라진 모양)
/// 높이 = 예전 글자 크기 × 0.83. 원본 비율 1677 × 331.
/// 검은 글자 → wordmark-black, 8도 흰색 → wordmark-white, 기본(흰 SPLITS + 노란 8) → wordmark-yellow
struct Wordmark: View {
    var size: CGFloat
    var eightColor: Color = C.accent
    var color: Color = .white
    var tracking: CGFloat = -0.02      // 예전 호출과 호환용 (이미지에는 쓰지 않음)
    var weight: Font.Weight = .heavy   // 예전 호출과 호환용

    private var imageName: String {
        if color == Color.black { return "wordmark-black" }
        if eightColor == C.accent { return "wordmark-yellow" }
        return "wordmark-white"
    }
    var body: some View {
        let h: CGFloat = size * 0.83
        Image(imageName)
            .resizable()
            .interpolation(.high)
            .scaledToFit()
            .frame(width: h * 1677 / 331, height: h)
            .accessibilityLabel("SPLITS8")
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

// MARK: - PFT 등급 뱃지 (아이폰 · 워치 공통)

/// GOLD / SILVER / BRONZE — 셋 다 같은 크기 (기본 78 × 22). 왼쪽에 작은 메달 점
struct PFTBadge: View {
    let grade: PFTGrade
    var width: CGFloat = 78
    var height: CGFloat = 22
    var fontSize: CGFloat = 12

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: height * 0.32, style: .continuous)
        return HStack(spacing: 5) {
            Circle().fill(Color.black.opacity(0.28))
                .overlay(Circle().strokeBorder(Color.white.opacity(0.55), lineWidth: 2))
                .frame(width: fontSize, height: fontSize)
            Text(verbatim: grade.label)
                .font(F.t(fontSize, .heavy)).tracking(0.04 * fontSize)
                .foregroundStyle(Color(hex: grade.inkHex))
                .lineLimit(1).fixedSize()
        }
        .frame(width: width, height: height)
        .background(LinearGradient(colors: [Color(hex: grade.hex1), Color(hex: grade.hex2)],
                                   startPoint: .topLeading, endPoint: .bottomTrailing), in: shape)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: grade.label))
    }
}

// MARK: - 번역

extension String {
    /// Localizable.strings 에서 번역을 찾음 (키 = 영어 원문). 없으면 그대로.
    /// 변수로 들어오는 화면 문자열(부품의 title/label 등)에 씀. 사용자 입력·숫자는 키가 없어 그대로 나옴.
    var l10n: String { Bundle.main.localizedString(forKey: self, value: self, table: nil) }
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
    static let posix = Locale(identifier: "en_US_POSIX")
    /// 앱 화면 언어가 한국어인지 (Localizable.strings 기준)
    /// 앱 언어가 한국어인지 (iPhone 언어 또는 설정 → Language 선택을 따름)
    static var isKorean: Bool { (Bundle.main.preferredLocalizations.first ?? "en").hasPrefix("ko") }
    /// 화면용 날짜: 영어는 시안 그대로(en_GB 고정 형식), 한국어는 template 으로 현지 형식
    private static func df(_ f: String, ko template: String, en: Locale = Fm.gb) -> DateFormatter {
        let d = DateFormatter()
        if isKorean {
            d.locale = Locale(identifier: "ko_KR")
            d.setLocalizedDateFormatFromTemplate(template)
        } else {
            d.locale = en; d.dateFormat = f
        }
        return d
    }
    /// 저장·파싱용 (언어와 상관없이 고정)
    private static func fixed(_ f: String) -> DateFormatter {
        let d = DateFormatter(); d.locale = posix; d.dateFormat = f; return d
    }
    /// Wed 24 Sep
    static let wdm = df("EEE dd MMM", ko: "MMMdEEE")
    /// Sat 13 Sep 2026
    static let wdmy = df("EEE dd MMM yyyy", ko: "yMMMdEEE")
    /// 13 Sep 2026
    static let dmy = df("d MMM yyyy", ko: "yMMMd")
    /// 20 Sep 2026 (두 자리 일)
    static let ddmy = df("dd MMM yyyy", ko: "yMMMd")
    /// 14 JUN (그래프 축)
    private static let axisF = df("dd MMM", ko: "MMMd")
    static func axis(_ d: Date) -> String { axisF.string(from: d).uppercased() }
    /// 28 Sep
    static let dm = df("d MMM", ko: "MMMd")
    /// Sep
    static let mon = df("MMM", ko: "MMM")
    /// September 2026 (달력 제목)
    static let monthYear = df("MMMM yyyy", ko: "yMMMM")
    /// 9:00 AM (12시간) — 한국어는 오전 9:00
    static let time12 = df("h:mm a", ko: "ahmm", en: Locale(identifier: "en_US"))
    static let ymd = fixed("yyyy-MM-dd")
    static let hm = fixed("HH:mm")
    static let clock: DateFormatter = { let d = DateFormatter(); d.dateFormat = "H:mm"; return d }()
}
