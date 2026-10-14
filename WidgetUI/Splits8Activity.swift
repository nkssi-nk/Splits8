import Foundation
#if canImport(ActivityKit)
import ActivityKit

/// 잠금 화면 · 다이내믹 아일랜드 실시간 표시 (52번). 앱과 위젯 확장이 같은 정의를 씀
struct Splits8Activity: ActivityAttributes {
    typealias ContentState = LiveCardState
    /// Full Simulation / 트레이닝 이름
    var title: String
}
#endif
