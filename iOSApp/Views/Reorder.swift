import SwiftUI
import UIKit

// MARK: - 17번 · 순서 바꾸기 공용 (빌더 구간 줄 · 트레이닝 목록 · 친구 목록)
// 끄는 줄 모양: 1.03배 · 그림자 · 배경 #2C2C2E, 다른 줄은 부드럽게 밀려남, 한 칸 넘을 때 선택 진동.
// 목록(트레이닝 · 친구)은 0.35초 꾹 누르면 "툭"(medium 진동) 뒤 끌기. 그냥 탭 · 스크롤은 그대로.

/// 끄는 중인 상태 (목록마다 @State 하나). 번호는 원래 목록 순서의 번호
struct Reorder: Equatable {
    /// 끄는 줄 (nil = 안 끄는 중)
    var from: Int? = nil
    /// 놓일 자리
    var to: Int = 0
    /// 손가락이 위아래로 움직인 거리
    var dy: CGFloat = 0
    /// 줄 높이 (줄 사이 간격 포함) — 줄 id 별
    var heights: [String: CGFloat] = [:]

    var active: Bool { from != nil }

    /// 끄는 중이면 놓일 자리 기준으로 미리 정렬한 순서 (원래 번호 목록)
    func order(_ n: Int) -> [Int] {
        var o: [Int] = Array(0..<max(n, 0))
        if let f = from, o.indices.contains(f) {
            let x: Int = o.remove(at: f)
            o.insert(x, at: min(max(to, 0), o.count))
        }
        return o
    }

    private func h(_ k: Int, _ ids: [String], _ fallback: CGFloat) -> CGFloat {
        guard ids.indices.contains(k) else { return fallback }
        return heights[ids[k]] ?? fallback
    }

    /// 끄는 줄의 화면 위치 보정: 손가락 이동 − 자리가 바뀌어 이미 옮겨진 만큼 (손가락에 붙어 있게)
    func liftOffset(_ ids: [String], fallback: CGFloat = 60) -> CGFloat {
        guard let f = from else { return 0 }
        var shift: CGFloat = 0
        if to > f {
            for k in (f + 1)...to { shift += h(k, ids, fallback) }
        } else if to < f {
            for k in to..<f { shift -= h(k, ids, fallback) }
        }
        return dy - shift
    }

    /// 손가락 이동(dy) → 놓일 자리. 옆 줄의 절반을 넘으면 한 칸
    func target(_ ids: [String], fallback: CGFloat = 60) -> Int {
        guard let f = from, !ids.isEmpty else { return 0 }
        var t: Int = f
        var acc: CGFloat = 0
        if dy > 0 {
            while t + 1 < ids.count {
                let next: CGFloat = h(t + 1, ids, fallback)
                if dy > acc + next / 2 { acc += next; t += 1 } else { break }
            }
        } else if dy < 0 {
            while t - 1 >= 0 {
                let prev: CGFloat = h(t - 1, ids, fallback)
                if -dy > acc + prev / 2 { acc += prev; t -= 1 } else { break }
            }
        }
        return t
    }
}

/// 끄는 중 · 방금 끝남 → 손을 뗄 때 따라오는 누름(탭)은 무시
enum ReorderKit {
    static var lastEnd: Date = .distantPast
    static var blocksTap: Bool {
        Router.shared.reordering || Date().timeIntervalSince(lastEnd) < 0.4
    }
}

extension View {
    /// 끄는 줄 모양 (빌더와 같음): 배경 #2C2C2E · 둥근 모서리 · 1.03배 · 그림자 · 손가락 따라 이동 · 맨 앞
    func reorderLift(_ dragging: Bool, offset: CGFloat, corner: CGFloat = 14) -> some View {
        self
            .background(dragging ? Color(hex: 0x2C2C2E) : Color.black.opacity(0.001))
            .clipShape(RoundedRectangle(cornerRadius: dragging ? corner : 0, style: .continuous))
            .scaleEffect(dragging ? 1.03 : 1)
            .shadow(color: .black.opacity(dragging ? 0.5 : 0), radius: 12, y: 6)
            .offset(y: dragging ? offset : 0)
            .zIndex(dragging ? 1 : 0)
            .animation(.easeOut(duration: 0.15), value: dragging)
    }

    /// 꾹 눌러 순서 바꾸기 한 줄. ids = 원래 순서의 줄 id 목록, index = 이 줄의 원래 번호,
    /// spacing = 줄 사이 간격 (VStack spacing), onMove(from, to) = 실제 목록 바꾸기
    func reorderRow(index: Int, ids: [String], state: Binding<Reorder>, corner: CGFloat = 14,
                    spacing: CGFloat = 0, onMove: @escaping (Int, Int) -> Void) -> some View {
        modifier(ReorderRow(index: index, ids: ids, state: state, corner: corner, spacing: spacing, onMove: onMove))
    }
}

private struct ReorderRow: ViewModifier {
    let index: Int
    let ids: [String]
    @Binding var state: Reorder
    let corner: CGFloat
    let spacing: CGFloat
    let onMove: (Int, Int) -> Void
    /// 꾹 누르기가 된 뒤 손을 떼거나 취소되면 false 로 돌아옴 → 놓기
    @GestureState private var holding = false

    private var myId: String { ids.indices.contains(index) ? ids[index] : "" }

    func body(content: Content) -> some View {
        let dragging: Bool = state.from == index
        return content
            .background(GeometryReader { g in
                Color.clear
                    .onAppear { record(g.size.height) }
                    .onChange(of: g.size.height) { _, h in record(h) }
            })
            .reorderLift(dragging, offset: dragging ? state.liftOffset(ids) : 0, corner: corner)
            .simultaneousGesture(gesture)
            .onChange(of: holding) { _, on in if !on { finish() } }
            .onDisappear { if state.from == index { finish() } }
    }

    private func record(_ h: CGFloat) {
        guard h > 1, !myId.isEmpty else { return }
        let v: CGFloat = h + spacing
        if state.heights[myId] != v { state.heights[myId] = v }
    }

    private var gesture: some Gesture {
        LongPressGesture(minimumDuration: 0.35, maximumDistance: 10)
            .sequenced(before: DragGesture(minimumDistance: 0, coordinateSpace: .global))
            .updating($holding) { v, s, _ in
                if case .second(true, _) = v { s = true }
            }
            .onChanged { v in
                guard case .second(true, let drag) = v else { return }
                if state.from == nil {
                    guard !Router.shared.reordering, ids.indices.contains(index) else { return }
                    // 꾹 누르기 성공 → "툭" 하고 줄이 떠오름. 끄는 동안 스크롤은 멈춤
                    state.from = index; state.to = index; state.dy = 0
                    Router.shared.reordering = true
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                }
                guard state.from == index else { return }
                state.dy = drag?.translation.height ?? 0
                let t: Int = state.target(ids)
                if t != state.to {
                    // 다른 줄이 부드럽게 밀려나도록 (끄는 줄은 자리 이동과 offset 보정이 같이 움직여 손가락에 붙어 있음)
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.85)) { state.to = t }
                    UISelectionFeedbackGenerator().selectionChanged()
                }
            }
    }

    private func finish() {
        guard let f = state.from, f == index else { return }
        let t: Int = min(max(state.to, 0), max(ids.count - 1, 0))
        var tx = Transaction(); tx.disablesAnimations = true
        withTransaction(tx) {
            if f != t { onMove(f, t) }
            state.from = nil; state.dy = 0; state.to = 0
        }
        Router.shared.reordering = false
        ReorderKit.lastEnd = Date()
    }
}

/// 원래 번호와 함께 (끄는 중 미리 정렬한 순서로 ForEach 돌릴 때)
struct Indexed<T: Identifiable>: Identifiable {
    let i: Int
    let item: T
    var id: T.ID { item.id }
}

extension Array {
    /// from 번째를 빼서 to 자리에 넣음 (빌더와 같은 방식)
    func moved(_ from: Int, to: Int) -> [Element] {
        guard indices.contains(from) else { return self }
        var a = self
        let x = a.remove(at: from)
        a.insert(x, at: Swift.min(Swift.max(to, 0), a.count))
        return a
    }
}
