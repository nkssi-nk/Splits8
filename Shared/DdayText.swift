import SwiftUI
import CoreText
#if canImport(UIKit)
import UIKit
#endif

// MARK: - 1.2.8 "D-170" 의 "-" 를 대문자 · 숫자 높이 한가운데로 (대표님 11-25 "-가 왜 가운데가 아니지")
// 글꼴(SF Pro)의 하이픈은 소문자 높이 가운데에 그려져서 큰 숫자 옆에서는 아래로 처져 보임.
// → "D" · "-" · "170" 을 이어 붙이고 "-" 만 올림. 올리는 양은 그 글꼴의 실제 글자 모양(D 와 - 의 위아래)을 재서 정함.

enum DdayText {
    /// 하이픈을 올릴 양 (pt) = D 의 가운데 높이 − 하이픈의 가운데 높이
    static func lift(size: CGFloat, weight: Font.Weight) -> CGFloat {
        #if canImport(UIKit)
        let f: UIFont = UIFont.systemFont(ofSize: size, weight: uiWeight(weight))
        let ct: CTFont = f as CTFont
        func mid(_ ch: String) -> CGFloat? {
            var chars: [UniChar] = Array(ch.utf16)
            var glyphs: [CGGlyph] = Array(repeating: 0, count: chars.count)
            guard CTFontGetGlyphsForCharacters(ct, &chars, &glyphs, chars.count) else { return nil }
            var r: CGRect = .zero
            CTFontGetBoundingRectsForGlyphs(ct, .horizontal, &glyphs, &r, 1)
            return r.midY
        }
        guard let d = mid("D"), let h = mid("-") else { return size * 0.06 }
        return max(0, d - h)
        #else
        return size * 0.06
        #endif
    }

    #if canImport(UIKit)
    private static func uiWeight(_ w: Font.Weight) -> UIFont.Weight {
        switch w {
        case .black: return .black
        case .heavy: return .heavy
        case .bold: return .bold
        case .semibold: return .semibold
        case .medium: return .medium
        case .light: return .light
        default: return .regular
        }
    }
    #endif

    /// "D-170" / "D-DAY" / "D+3" 글자 (하이픈만 올림). 글꼴은 시스템(SF Pro) · 고정폭 숫자
    static func text(_ s: String, size: CGFloat, weight: Font.Weight) -> Text {
        let font: Font = .system(size: size, weight: weight).monospacedDigit()
        guard let i = s.firstIndex(of: "-") else { return Text(s).font(font) }
        let a = String(s[s.startIndex..<i])
        let b = String(s[s.index(after: i)...])
        return Text(a).font(font)
            + Text("-").font(font).baselineOffset(lift(size: size, weight: weight))
            + Text(b).font(font)
    }
}
