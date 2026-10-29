import SwiftUI

// MARK: - HIIT · 러닝 · 18번 새 종류 설정 시트 (종류 고르기 카드 / 저장된 카드 누르면)
// 18번: 인터벌 러닝 · 타바타 · EMOM · AMRAP · 기능성 운동(웨이트)도 같은 시트에서 설정

struct BonusSheet: View {
    let req: BonusRequest
    private let store = Store.shared
    private let r = Router.shared

    @State private var km: Int
    @State private var indoor: Bool
    /// 82번(빌드 28): 카드 이름 (비우면 기본 이름 "HIIT" · "Run 5K" · "Free run" · "Tabata" · "EMOM 12 min" …)
    @State private var name: String
    /// 새로 만들 때 쓸 id (저장·아이폰 시작이 같은 id 를 쓰게)
    @State private var fresh: String = String(UUID().uuidString.prefix(6))
    // 18번 · 타바타
    @State private var work: Int
    @State private var rest: Int
    @State private var rounds: Int
    // 18번 · EMOM · AMRAP
    @State private var every: Int
    @State private var emomRounds: Int
    @State private var capMin: Int
    @State private var task: String
    // 18번 · 인터벌 러닝
    @State private var steps: [IntervalStep]
    @State private var repeats: Int
    @State private var warm: IntervalStep?
    @State private var cool: IntervalStep?
    // 18번 · 기능성 운동
    @State private var moves: [StrengthMove]
    @State private var restSec: Int

    init(req: BonusRequest) {
        self.req = req
        let e: Program? = req.existing
        _km = State(initialValue: e?.runKm ?? 5)
        _indoor = State(initialValue: e?.indoor ?? false)
        _work = State(initialValue: e?.work ?? Program.tabataDefault.work)
        _rest = State(initialValue: (req.kind == WKind.tabata ? e?.rest : nil) ?? Program.tabataDefault.rest)
        _rounds = State(initialValue: (req.kind == WKind.tabata ? e?.rounds : nil) ?? Program.tabataDefault.rounds)
        _every = State(initialValue: e?.every ?? 60)
        _emomRounds = State(initialValue: (req.kind == WKind.emom ? e?.rounds : nil) ?? 12)
        _capMin = State(initialValue: max(1, (e?.cap ?? 15 * 60) / 60))
        _task = State(initialValue: e?.task ?? "")
        let preset: IntervalPreset = IntervalPreset.all[1]
        _steps = State(initialValue: e?.steps ?? preset.steps)
        _repeats = State(initialValue: e?.repeats ?? preset.repeats)
        _warm = State(initialValue: e?.warm)
        _cool = State(initialValue: e?.cool)
        _moves = State(initialValue: e?.moves ?? [StrengthMove(name: "Squat", sets: 3, reps: 10, kg: 40)])
        _restSec = State(initialValue: (req.kind == WKind.strength ? e?.rest : nil) ?? 90)
        // 기본 이름 그대로면 칸은 비워 둠 (자리 글자로 기본 이름이 보임)
        let n: String = e?.name ?? ""
        let isDefault: Bool = n == "HIIT" || n == "Free run" || n.hasPrefix("Run ") && n.hasSuffix("K")
            || (e.map { BonusSheet.autoName($0) == n } ?? false)
        _name = State(initialValue: isDefault ? "" : n)
    }

    /// 저장된 카드의 기본 이름 (설정에서 만든 이름)
    static func autoName(_ p: Program) -> String {
        switch p.kind ?? "" {
        case WKind.tabata: return Program.tabataName(work: p.work ?? 20, rest: p.rest ?? 10)
        case WKind.emom: return Program.timedName(Program.emomLabel(p.every ?? 60), (p.every ?? 60) * (p.rounds ?? 12))
        case WKind.amrap: return Program.timedName("AMRAP", p.cap ?? 900)
        case WKind.interval: return intervalName(p.steps ?? [], p.repeats ?? 1)
        case WKind.strength: return "Strength"
        default: return p.name
        }
    }

    /// 예시와 같으면 예시 이름, 아니면 "Interval run"
    static func intervalName(_ steps: [IntervalStep], _ repeats: Int) -> String {
        IntervalPreset.all.first { $0.steps == steps && $0.repeats == repeats }?.name ?? "Interval run"
    }

    private var kind: String { req.kind }
    private var isHIIT: Bool { kind == WKind.hiit }

    /// 지금 설정으로 만든 기본 이름
    private var defaultName: String {
        switch kind {
        case WKind.hiit: return "HIIT"
        case WKind.run: return Program.runName(km)
        case WKind.tabata: return Program.tabataName(work: work, rest: rest)
        case WKind.emom: return Program.timedName(Program.emomLabel(every), every * emomRounds)
        case WKind.amrap: return Program.timedName("AMRAP", capMin * 60)
        case WKind.interval: return BonusSheet.intervalName(steps, repeats)
        case WKind.strength: return "Strength"
        default: return WKind.label(kind)
        }
    }
    private var cleanName: String { String(name.trimmingCharacters(in: .whitespacesAndNewlines).prefix(24)) }
    private var cleanTask: String? {
        let t: String = String(task.trimmingCharacters(in: .whitespacesAndNewlines).prefix(200))
        return t.isEmpty ? nil : t
    }
    private var newId: String { req.existing?.id ?? (kind + "." + fresh) }

    /// 지금 고른 값으로 만든 프로그램 (편집이면 같은 id)
    private var program: Program {
        var p: Program
        switch kind {
        case WKind.hiit:
            if let e = req.existing { p = e } else { p = Program.hiit(); p.id = "hiit." + fresh }
        case WKind.tabata:
            p = Program.tabata(work: work, rest: rest, rounds: rounds, id: newId)
        case WKind.emom:
            p = Program.emom(every: every, rounds: emomRounds, task: cleanTask, id: newId)
        case WKind.amrap:
            p = Program.amrap(cap: capMin * 60, task: cleanTask, id: newId)
        case WKind.interval:
            p = Program.interval(indoor: indoor, id: newId)
            p.steps = steps
            p.repeats = repeats
            p.warm = warm
            p.cool = cool
        case WKind.strength:
            p = Program.strength(moves: moves.filter { $0.sets > 0 && !$0.name.trimmingCharacters(in: .whitespaces).isEmpty },
                                 rest: restSec, id: newId)
        default:
            p = Program.run(km: km, indoor: indoor, id: req.existing?.id ?? ("run." + fresh))
        }
        p.name = cleanName.isEmpty ? defaultName : cleanName
        return p
    }

    /// 지금 고른 설정과 같은 것이 이미 목록(= 워치 목록)에 있는지
    private var onWatch: Bool {
        if WKind.isNew(kind) {
            if let e = req.existing { return e.sameSetup(program) }
            return store.programs.contains { $0.sameSetup(program) }
        }
        if let e = req.existing {
            // 저장된 카드를 연 경우: 값을 바꾸지 않았으면 이미 있음
            return e.name == program.name && (isHIIT || (e.runKm == km && (e.indoor ?? false) == indoor))
        }
        return store.programs.contains { p in
            p.name == program.name && (isHIIT ? p.isHIIT : (p.isRun && p.runKm == km && (p.indoor ?? false) == indoor))
        }
    }

    /// 기능성: 종목이 하나도 없으면 저장 · 시작 안 됨
    private var canSave: Bool {
        kind != WKind.strength || program.moves?.isEmpty == false
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 10) {
                    Icon8(WKind.icon(kind), 26, tint: .yellow)
                    Text(WKind.label(kind).l10n).font(F.t(F.title3, .semibold))
                    Spacer(minLength: 0)
                    Button { r.bonus = nil } label: {
                        Image(systemName: "xmark").font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(C.text2)
                            .frame(width: 32, height: 32)
                            .background(Color.white.opacity(0.10), in: Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("bonus.close")
                }

                nameField
                switch kind {
                case WKind.hiit: hiitBody
                case WKind.tabata: tabataBody
                case WKind.emom: emomBody
                case WKind.amrap: amrapBody
                case WKind.interval: intervalBody
                case WKind.strength: strengthBody
                default: runBody
                }

                // 66번(빌드 25): 이미 워치 목록에 있는 것(같은 설정)이면 저장 버튼 대신 "워치 목록에 있음"
                if onWatch {
                    HStack(spacing: 8) {
                        Check8(color: C.good, size: 18)
                        Text("Already on your watch list").font(F.t(17, .semibold)).foregroundStyle(C.good)
                    }
                    .frame(maxWidth: .infinity).frame(height: 54)
                    .card8(16)
                    .accessibilityIdentifier("bonus.onWatch")
                } else {
                    YellowButton(enabled: canSave, action: { if canSave { save() } }) {
                        Text((req.existing != nil ? "Save changes" : "Save (add to watch list)").l10n)
                    }
                    .accessibilityIdentifier("bonus.save")
                }

                HStack {
                    if req.existing != nil {
                        Button(role: .destructive) { delete() } label: {
                            Text("Delete").font(F.t(F.sub, .semibold)).foregroundStyle(C.bad)
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("bonus.delete")
                    }
                    Spacer(minLength: 0)
                    if canSave {
                        StartOnPhoneButton(mode: .training, program: program, before: { saveQuietly(); r.bonus = nil })
                    }
                }
            }
            .padding(.horizontal, 20).padding(.top, 22).padding(.bottom, 24)
        }
    }

    // MARK: 이름 (82번)

    private var nameField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label8("NAME")
            TextField(defaultName.l10n, text: $name)
                .font(F.t(17)).textInputAutocapitalization(.words).autocorrectionDisabled()
                .submitLabel(.done)
                .padding(.horizontal, 14).frame(height: 46)
                .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .accessibilityIdentifier("bonus.name")
        }
    }

    // MARK: HIIT

    private var hiitBody: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("When a round ends, swipe left or tap Next on the watch → next interval.")
                .font(F.t(F.sub)).fixedSize(horizontal: false, vertical: true)
            Text("Saved: time per round · average heart rate · calories")
                .font(F.t(F.foot)).foregroundStyle(C.text2).fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .card8(16)
    }

    // MARK: 러닝

    private var runBody: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label8("DISTANCE")
            HStack(spacing: 6) {
                ForEach(Program.runChoices, id: \.self) { k in
                    let on: Bool = km == k
                    Button { km = k } label: {
                        Text(k > 0 ? "\(k)K" : "Free".l10n)
                            .font(F.t(F.sub, .semibold)).foregroundStyle(on ? Color.black : Color.white)
                            .lineLimit(1).minimumScaleFactor(0.8)
                            .frame(maxWidth: .infinity).frame(height: 40)
                            .background(on ? C.accent : Color.white.opacity(0.10),
                                        in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("bonus.km.\(k)")
                }
            }
            placePicker
            Text("Saved: 1 km splits · pace · heart rate · route map outdoors")
                .font(F.t(F.foot)).foregroundStyle(C.text2).fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .card8(16)
    }

    private var placePicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label8("PLACE")
            Seg8(items: [("out", "Outdoor (GPS)"), ("in", "Indoor (treadmill)")], selected: indoor ? "in" : "out",
                 height: 36, radius: 10, fontSize: 13) { v in indoor = v == "in" }
        }
    }

    // MARK: 18번 · 타바타 (운동/휴식 타이머)

    /// 바로 고르기: 운동 초 / 휴식 초 × 라운드
    private static let tabataPicks: [[Int]] = [[20, 10, 8], [40, 20, 10], [30, 15, 12], [45, 15, 8]]

    private var tabataBody: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label8("QUICK PICK")
            HStack(spacing: 6) {
                ForEach(BonusSheet.tabataPicks.indices, id: \.self) { k in
                    let x: [Int] = BonusSheet.tabataPicks[k]
                    chip("\(x[0])/\(x[1]) × \(x[2])", on: work == x[0] && rest == x[1] && rounds == x[2]) {
                        work = x[0]; rest = x[1]; rounds = x[2]
                    }
                }
            }
            NumStepper(label: "WORK", value: intBinding($work), step: 5, range: 5...600, text: { Fm.t(Int($0)) })
            NumStepper(label: "REST", value: intBinding($rest), step: 5, range: 0...600, text: { Fm.t(Int($0)) })
            NumStepper(label: "ROUNDS", value: intBinding($rounds), step: 1, range: 1...50)
            Text(String(format: "Total %@ · switches by itself, buzz 3 · 2 · 1 before each change".l10n,
                        Fm.t(work * rounds + rest * max(0, rounds - 1))))
                .font(F.t(F.foot)).foregroundStyle(C.text2).fixedSize(horizontal: false, vertical: true)
            Text("Saved: heart rate · calories per round · whether you finished")
                .font(F.t(F.foot)).foregroundStyle(C.text2).fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .card8(16)
    }

    // MARK: 18번 · EMOM

    private var emomBody: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label8("EVERY")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(Program.emomChoices, id: \.self) { e in
                        chip(Fm.t(e), on: every == e) { every = e }
                    }
                }
            }
            NumStepper(label: "ROUNDS", value: intBinding($emomRounds), step: 1, range: 1...60)
            taskField("Each round (optional), e.g. 10 burpees · 15 wall balls")
            Text(String(format: "%@ · total %@. Tap Done when the work is finished — the rest of the minute is rest.".l10n,
                        Program.emomLabel(every), Fm.t(every * emomRounds)))
                .font(F.t(F.foot)).foregroundStyle(C.text2).fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .card8(16)
    }

    // MARK: 18번 · AMRAP

    private var amrapBody: some View {
        VStack(alignment: .leading, spacing: 12) {
            NumStepper(label: "TIME", value: intBinding($capMin), step: 1, range: 1...90,
                       text: { String(format: "%lld min".l10n, Int($0)) })
            taskField("One round, one per line, e.g. 5 pull-ups / 10 push-ups / 15 squats")
            Text("Tap Round done after each round. It ends by itself when time is up, then you can add extra reps.")
                .font(F.t(F.foot)).foregroundStyle(C.text2).fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .card8(16)
    }

    private func taskField(_ hint: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label8("WORK")
            TextField(hint.l10n, text: $task, axis: .vertical)
                .font(F.t(15)).lineLimit(2...5)
                .padding(.horizontal, 14).padding(.vertical, 12)
                .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .accessibilityIdentifier("bonus.task")
        }
    }

    // MARK: 18번 · 인터벌 러닝

    private static let paceChoices: [Int] = Array(stride(from: 180, through: 480, by: 15))

    private var intervalBody: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label8("QUICK PICK")
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 6), GridItem(.flexible(), spacing: 6)], spacing: 6) {
                ForEach(IntervalPreset.all) { pr in
                    chip(pr.name, on: steps == pr.steps && repeats == pr.repeats) {
                        steps = pr.steps; repeats = pr.repeats
                    }
                }
            }
            Label8("REPEAT THIS")
            ForEach(steps.indices, id: \.self) { i in
                stepRow(i)
            }
            if steps.count < 6 {
                Button {
                    steps.append(IntervalStep(type: "easy", meters: 200))
                } label: {
                    Label("Add step", systemImage: "plus").font(F.t(15, .semibold)).foregroundStyle(C.accent)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("bonus.addStep")
            }
            NumStepper(label: "REPEATS", value: intBinding($repeats), step: 1, range: 1...30)
            Toggle(isOn: Binding(get: { warm != nil }, set: { warm = $0 ? IntervalStep(type: "easy", secs: 600) : nil })) {
                Text("Warm-up · 10 min easy").font(F.t(15))
            }
            .tint(C.accent)
            Toggle(isOn: Binding(get: { cool != nil }, set: { cool = $0 ? IntervalStep(type: "easy", secs: 300) : nil })) {
                Text("Cool-down · 5 min easy").font(F.t(15))
            }
            .tint(C.accent)
            placePicker
            Text("Outdoors, distance steps move on by GPS; time steps move on by time. Indoors, tap Next for distance steps.")
                .font(F.t(F.foot)).foregroundStyle(C.text2).fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .card8(16)
    }

    private func stepRow(_ i: Int) -> some View {
        let st: IntervalStep = steps.indices.contains(i) ? steps[i] : IntervalStep(type: "easy", meters: 200)
        let isDist: Bool = st.meters != nil
        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Menu {
                    ForEach(IntervalStep.types, id: \.self) { t in
                        Button(IntervalStep.typeName(t).l10n) { setStep(i) { $0.type = t } }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text(IntervalStep.typeName(st.type).l10n).font(F.t(15, .semibold))
                        Image(systemName: "chevron.up.chevron.down").font(.system(size: 11, weight: .semibold))
                    }
                    .foregroundStyle(st.type == "fast" ? C.accent : .white)
                }
                Spacer(minLength: 0)
                Seg8(items: [("m", "Distance"), ("t", "Time")], selected: isDist ? "m" : "t",
                     height: 30, radius: 9, fontSize: 12, minWidth: 64) { v in
                    setStep(i) { s in
                        if v == "m" { s.meters = s.meters ?? 400; s.secs = nil } else { s.secs = s.secs ?? 60; s.meters = nil }
                    }
                }
                if steps.count > 1 {
                    Button { if steps.indices.contains(i) { steps.remove(at: i) } } label: {
                        Image(systemName: "trash").font(.system(size: 13, weight: .semibold)).foregroundStyle(C.bad)
                            .frame(width: 30, height: 30)
                    }
                    .buttonStyle(.plain)
                }
            }
            NumStepper(label: isDist ? "DISTANCE" : "TIME",
                       value: Binding(get: { Double(st.meters ?? st.secs ?? 0) },
                                      set: { v in setStep(i) { s in if s.meters != nil { s.meters = Int(v) } else { s.secs = Int(v) } } }),
                       step: isDist ? 100 : 15, range: isDist ? 100...10000 : 15...1800,
                       text: { isDist ? IntervalStep(type: "fast", meters: Int($0)).amount : Fm.t(Int($0)) })
            Menu {
                Button("No target pace".l10n) { setStep(i) { $0.pace = nil } }
                ForEach(BonusSheet.paceChoices, id: \.self) { p in
                    Button(Fm.t(p) + " /km") { setStep(i) { $0.pace = p } }
                }
            } label: {
                Text(st.pace.map { String(format: "Target %@ /km".l10n, Fm.t($0)) } ?? "No target pace".l10n)
                    .font(F.t(13, .medium)).foregroundStyle(C.text2)
            }
        }
        .padding(12)
        .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func setStep(_ i: Int, _ f: (inout IntervalStep) -> Void) {
        guard steps.indices.contains(i) else { return }
        f(&steps[i])
    }

    // MARK: 18번 · 기능성 운동 (웨이트)

    private var strengthBody: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label8("EXERCISES")
            ForEach(moves.indices, id: \.self) { i in
                moveRow(i)
            }
            if moves.count < 12 {
                Menu {
                    ForEach(StrengthMove.catalog, id: \.self) { n in
                        Button(n.l10n) { moves.append(StrengthMove(name: n, sets: 3, reps: 10, kg: 20)) }
                    }
                    Button("Custom".l10n) { moves.append(StrengthMove(name: "", sets: 3, reps: 10, kg: 20)) }
                } label: {
                    Label("Add exercise", systemImage: "plus").font(F.t(15, .semibold)).foregroundStyle(C.accent)
                }
                .accessibilityIdentifier("bonus.addMove")
            }
            Label8("REST BETWEEN SETS")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(Program.restChoices, id: \.self) { s in
                        chip(Fm.t(s), on: restSec == s) { restSec = s }
                    }
                }
            }
            Text("Set done → check reps and weight (filled in from last time) → rest timer. The watch does set done · rest · next only; change weights on iPhone.")
                .font(F.t(F.foot)).foregroundStyle(C.text2).fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .card8(16)
    }

    private func moveRow(_ i: Int) -> some View {
        let mv: StrengthMove = moves.indices.contains(i) ? moves[i] : StrengthMove(name: "", sets: 3, reps: 10, kg: 0)
        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                TextField("Exercise name".l10n,
                          text: Binding(get: { mv.name.l10n == mv.name ? mv.name : mv.name.l10n },
                                        set: { v in setMove(i) { $0.name = String(v.prefix(30)) } }))
                    .font(F.t(16, .semibold)).autocorrectionDisabled()
                Button { if moves.indices.contains(i) { moves.remove(at: i) } } label: {
                    Image(systemName: "trash").font(.system(size: 13, weight: .semibold)).foregroundStyle(C.bad)
                        .frame(width: 30, height: 30)
                }
                .buttonStyle(.plain)
            }
            HStack(spacing: 6) {
                MiniStepper(label: "SETS", value: mv.sets, text: "\(mv.sets)") { d in setMove(i) { $0.sets = max(1, min(10, $0.sets + d)) } }
                MiniStepper(label: "TARGET REPS", value: mv.reps, text: "\(mv.reps)") { d in setMove(i) { $0.reps = max(1, min(100, $0.reps + d)) } }
                MiniStepper(label: "KG", value: Int(mv.kg), text: StrengthMove.kgText(mv.kg)) { d in
                    setMove(i) { $0.kg = max(0, min(500, $0.kg + Double(d) * 2.5)) }
                }
            }
        }
        .padding(12)
        .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func setMove(_ i: Int, _ f: (inout StrengthMove) -> Void) {
        guard moves.indices.contains(i) else { return }
        f(&moves[i])
    }

    // MARK: 부품

    private func chip(_ t: String, on: Bool, _ act: @escaping () -> Void) -> some View {
        Button(action: act) {
            Text(t).font(F.t(13, .semibold)).foregroundStyle(on ? Color.black : Color.white)
                .lineLimit(1).minimumScaleFactor(0.75)
                .padding(.horizontal, 10)
                .frame(maxWidth: .infinity).frame(height: 36)
                .background(on ? C.accent : Color.white.opacity(0.10), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func intBinding(_ b: Binding<Int>) -> Binding<Double> {
        Binding(get: { Double(b.wrappedValue) }, set: { b.wrappedValue = Int($0.rounded()) })
    }

    // MARK: 동작

    private func saveQuietly() {
        store.save(program)
    }

    private func save() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        saveQuietly()
        r.bonus = nil
        // 새로 만들기(트레이닝 만들기 화면 · 종류 고르기)에서 왔으면 트레이닝 목록으로
        if req.existing == nil && r.scr == .builder {
            r.editId = nil
            r.go(.training)
        }
    }

    private func delete() {
        if let p = req.existing { store.deleteProgram(p.id) }
        r.bonus = nil
    }
}

/// 작은 − 값 + (세트 · 횟수 · 무게)
struct MiniStepper: View {
    let label: String
    let value: Int
    let text: String
    let change: (Int) -> Void

    var body: some View {
        VStack(spacing: 4) {
            Text(label.l10n).font(F.t(11, .semibold)).foregroundStyle(C.text2)
            HStack(spacing: 4) {
                button("minus") { change(-1) }
                Text(verbatim: text).font(F.num(15)).lineLimit(1).minimumScaleFactor(0.6).frame(maxWidth: .infinity)
                button("plus") { change(1) }
            }
        }
        .padding(.vertical, 8).padding(.horizontal, 6)
        .frame(maxWidth: .infinity)
        .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func button(_ sym: String, _ act: @escaping () -> Void) -> some View {
        Button(action: act) {
            Image(systemName: sym).font(.system(size: 11, weight: .bold)).foregroundStyle(.white)
                .frame(width: 26, height: 26)
                .background(Color.white.opacity(0.12), in: Circle())
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
    }
}
