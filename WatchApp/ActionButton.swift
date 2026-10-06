import AppIntents
import Foundation

// 애플워치 울트라의 액션 버튼.
// 쓰는 사람이 워치 설정 > 액션 버튼 > 운동 에서 Splits8 과 운동 종류를 한 번 골라 두면:
//  · 운동 중이 아닐 때 누름 → 그 운동의 시작 화면을 엶 (바로 시작하지는 않음 — 실수로 눌러도 기록이 시작되지 않게)
//  · 운동 중에 누름 → 다음 구간으로 넘김 (왼쪽으로 밀기·두 번 톡톡과 같음)

/// 액션 버튼에서 고르는 운동 종류
enum SplitsWorkoutStyle: String, AppEnum {
    case training, pft, sim, race

    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Workout"
    static var caseDisplayRepresentations: [SplitsWorkoutStyle: DisplayRepresentation] = [
        .training: "Training",
        .pft: "PFT",
        .sim: "Full Simulation",
        .race: "Race",
    ]

    var mode: Mode {
        switch self {
        case .training: return .training
        case .pft: return .pft
        case .sim: return .sim
        case .race: return .race
        }
    }
}

struct SplitsStartWorkoutIntent: StartWorkoutIntent {
    static var title: LocalizedStringResource = "Start Workout"
    static var openAppWhenRun: Bool = true

    static var suggestedWorkouts: [SplitsStartWorkoutIntent] {
        [SplitsStartWorkoutIntent(.sim), SplitsStartWorkoutIntent(.pft),
         SplitsStartWorkoutIntent(.training), SplitsStartWorkoutIntent(.race)]
    }

    @Parameter(title: "Workout")
    var workoutStyle: SplitsWorkoutStyle

    init() { self.workoutStyle = .sim }
    init(_ style: SplitsWorkoutStyle) { self.workoutStyle = style }

    var displayRepresentation: DisplayRepresentation {
        SplitsWorkoutStyle.caseDisplayRepresentations[workoutStyle] ?? "Workout"
    }

    @MainActor
    func perform() async throws -> some IntentResult {
        SplitsAction.press(open: workoutStyle.mode)
        return .result(actionButtonIntent: SplitsNextSegmentIntent())
    }
}

/// 운동 중 액션 버튼 = 다음 구간
struct SplitsNextSegmentIntent: AppIntent {
    static var title: LocalizedStringResource = "Next Segment"

    init() {}

    @MainActor
    func perform() async throws -> some IntentResult {
        SplitsAction.press(open: nil)
        return .result(actionButtonIntent: SplitsNextSegmentIntent())
    }
}

enum SplitsAction {
    /// 액션 버튼을 눌렀을 때 할 일. open = 운동 중이 아닐 때 열 운동 종류 (nil 이면 아무것도 안 엶)
    @MainActor
    static func press(open: Mode?) {
        let engine = WorkoutEngine.shared
        if engine.active {
            if !engine.finished { engine.advance() }
            return
        }
        guard engine.countdown == nil, let m = open else { return }
        let nav = WNav.shared
        nav.mode = m
        nav.program = nil
        nav.screen = m == .training ? .programs : .confirm
    }
}
