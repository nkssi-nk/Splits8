import SwiftUI
import WatchKit

// MARK: - 타바타 · EMOM · AMRAP · 인터벌 러닝 · 기능성 운동 — 운동 중 첫 화면 (1.2.7 새 디자인)
// 귀퉁이 표시 안: 위 단계 이름(13) · 큰 숫자(40) · 단위나 할 일 한 줄(10, 꼭 필요할 때만).
// 두 칸 · 점(라운드/세트/반복) · Next 줄 · 버튼 3개 (되돌리기 · 다음 · 일시정지) — 구간 화면과 같은 자리.
// 운동 = 노랑, 인터벌 빠르게 = 파랑, 휴식 · 천천히 = 회색. 왼쪽으로 밀기 = 다음, 오른쪽으로 밀기 = 조작 화면.

struct WTimerLive: View {
    let engine = WorkoutEngine.shared
    var zone: Int = 0
    let onControls: () -> Void
    @Environment(\.isLuminanceReduced) private var aod

    var body: some View {
        GeometryReader { geo in
            TimelineView(.periodic(from: .now, by: 1)) { ctx in
                screen(now: ctx.date, L: W8Scale(w: geo.size.width, h: geo.size.height))
            }
        }
        .ignoresSafeArea()
    }

    private var kind: String { engine.kind ?? "" }

    private func face(_ now: Date) -> TimerFace {
        TimerFaces.make(kind: kind, seq: engine.seq, idx: engine.idx, segEl: engine.segEl(now), total: engine.total(now),
                        cap: engine.amrapCap, segDist: engine.runLike && engine.distance > 0 ? engine.segDist : nil,
                        done: engine.doneAt, task: engine.program?.task)
    }

    private func tone(_ f: TimerFace) -> W8Tone {
        if f.rest { return .gray }
        if kind == WKind.interval { return .run }
        return .station
    }

    /// 위 단계 이름: 인터벌은 "FAST · 20 s" / "FAST · 400 m"
    private func top(_ f: TimerFace) -> String {
        let c: Seg = engine.cur
        guard kind == WKind.interval, c.no != nil else { return f.label.l10n }
        if let m = c.autoM { return f.label.l10n + " · \(m) m" }
        if let a = c.auto { return f.label.l10n + " · \(a) s" }
        return f.label.l10n
    }

    /// 큰 숫자와 아래 단위 ("240" + "M")
    private func mainParts(_ f: TimerFace) -> (String, String) {
        if f.main.hasSuffix(" m") { return (String(f.main.dropLast(2)), "M") }
        return (f.main, "")
    }

    /// 아래 한 줄 (EMOM 할 일 · AMRAP 라운드 · 기능성 무게). 인터벌은 목표 페이스 줄 뺌
    private func line(_ f: TimerFace) -> String {
        kind == WKind.interval ? "" : f.line
    }

    private func screen(now: Date, L: W8Scale) -> some View {
        let f: TimerFace = face(now)
        let t: W8Tone = tone(f)
        let ink: Color = aod ? W8.aodText : t.ink
        let sub: Color = aod ? W8.aodText : t.sub
        let mp: (String, String) = mainParts(f)
        let small: String = mp.1.isEmpty ? line(f) : mp.1
        return ZStack {
            W8Background(tone: t, zone: zone, seed: engine.idx, dim: aod)
            W8TotalRow(L: L, label: "TOTAL", value: Fm.t(engine.total(now)), tone: t, aod: aod)
            W8Brackets(arm: 9 * L.s)
                .stroke(aod ? W8.aodMark : t.mark, style: StrokeStyle(lineWidth: 2.6 * L.s, lineCap: .round, lineJoin: .round))
                .frame(width: L.v(176), height: L.v(66))
                .position(x: L.x(104), y: L.y(65))
            // 시안 (대문자 가운데): 단계 이름 13 → 39.9 · 큰 숫자 40 → 68.9 (단위 · 설명이 없으면 65) · 단위 · 설명 10 → 91.1
            Text(verbatim: top(f)).font(F.t(13 * L.s, .bold)).tracking(0.8).foregroundStyle(sub)
                .lineLimit(1).minimumScaleFactor(0.7).frame(width: L.v(164))
                .w8Shadow(t, L, aod)
                .position(x: L.x(104), y: L.y(small.isEmpty ? 42 : 39.9))
            Text(verbatim: mp.0).font(F.num(40 * L.s, .bold)).foregroundStyle(ink)
                .lineLimit(1).minimumScaleFactor(0.55).frame(width: L.v(164))
                .contentTransition(.numericText(countsDown: true))
                .w8Shadow(t, L, aod)
                .position(x: L.x(104), y: L.y(small.isEmpty ? 73 : 68.9))
                .accessibilityIdentifier("w.timerMain")
            if !small.isEmpty {
                Text(verbatim: small).font(F.t(10 * L.s, .bold)).foregroundStyle(sub)
                    .lineLimit(1).minimumScaleFactor(0.7).frame(width: L.v(164))
                    .w8Shadow(t, L, aod)
                    .position(x: L.x(104), y: L.y(91.1))
            }
            W8ColsRow(L: L, cols: [(countLabel.l10n, f.count.isEmpty ? "--" : f.count, false),
                                   ("♥ " + "BPM".l10n, engine.hr > 0 ? String(Int(engine.hr.rounded())) : "--", false)],
                      labelY: 109, valueY: 127.9, valueSize: 20, tone: t, aod: aod)
            if let d = dots(f) {
                W8Dots(L: L, total: d.1, current: d.0, tone: t, aod: aod)
                    .position(x: L.x(104), y: L.y(149))
            }
            nextLine(L: L, t: t)
                .w8Shadow(t, L, aod)
                .position(x: L.x(104), y: L.y(170))
            buttons(L: L, t: t)
        }
        .frame(width: L.w, height: L.h)
        .contentShape(Rectangle())
        .gesture(DragGesture(minimumDistance: 20).onEnded { v in
            let dx = v.translation.width
            guard abs(dx) >= 40, abs(dx) > abs(v.translation.height) else { return }
            if dx < 0 { main() } else { onControls() }
        })
    }

    private var countLabel: String {
        switch kind {
        case WKind.amrap: return "ROUNDS"
        case WKind.interval: return "REP"
        case WKind.strength: return "SET"
        default: return "ROUND"
        }
    }

    /// "3/8" → (2, 8). 끝이 없는 AMRAP · 너무 많으면 점 없음
    private func dots(_ f: TimerFace) -> (Int, Int)? {
        let p: [Substring] = f.count.split(separator: "/")
        guard p.count == 2, let a = Int(p[0]), let b = Int(p[1]), b > 1, b <= 30 else { return nil }
        return (max(0, a - 1), b)
    }

    private func nextLine(L: W8Scale, t: W8Tone) -> some View {
        let what: String? = TimerFaces.nextWhat(kind: kind, seq: engine.seq, idx: engine.idx)
        return HStack(alignment: .firstTextBaseline, spacing: 9 * L.s) {
            if kind != WKind.amrap {
                Text("Next").font(F.t(17 * L.s, .semibold))
                    .foregroundStyle(aod ? W8.aodText : t.sub)
                Text(verbatim: what ?? "Finish".l10n).font(F.t(17 * L.s, .bold))
                    .foregroundStyle(aod ? W8.aodText : t.ink)
                    .lineLimit(1).minimumScaleFactor(12 / 17)
            }
        }
        .frame(maxWidth: L.v(172))
    }

    // MARK: 버튼

    private var mainOn: Bool {
        engine.running && !(kind == WKind.emom && engine.doneAt != nil)
    }

    private func main() {
        guard mainOn else { return }
        withAnimation(WLive.slideCurve) { engine.advance() }
    }

    private func buttons(L: W8Scale, t: W8Tone) -> some View {
        let cy: CGFloat = L.h - 32 * L.s
        let ic: Color = aod ? W8.aodText : t.ink
        let mainIc: Color = aod ? W8.aodText : t.ink
        return ZStack {
            W8CircleButton(L: L, r: 18, tone: t, aod: aod, on: engine.canUndo, id: "w.timerUndo",
                           action: { withAnimation(WLive.slideCurve) { engine.undo() } }) {
                W8UndoIcon(size: 19 * L.s, color: ic)
            }
            .position(x: L.w / 2 - 54 * L.s, y: cy)
            W8CircleButton(L: L, r: 25, tone: t, aod: aod, main: true, on: mainOn, id: "w.timerMainButton", action: main) {
                W8NextArrow().fill(mainIc).frame(width: 20 * L.s, height: 17 * L.s)
            }
            .accessibilityLabel(Text("Next"))
            .position(x: L.w / 2, y: cy)
            W8CircleButton(L: L, r: 18, tone: t, aod: aod, id: "w.timerPause", action: { engine.togglePause() }) {
                W8PauseIcon(size: 14 * L.s, color: ic, paused: !engine.running)
            }
            .position(x: L.w / 2 + 54 * L.s, y: cy)
        }
    }
}
