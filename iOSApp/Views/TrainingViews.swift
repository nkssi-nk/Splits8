import SwiftUI
import UniformTypeIdentifiers

// MARK: - I1 Training (위 고정 바가 제목을 맡음 — 큰 제목 없음)

struct TrainingView: View {
    let store = Store.shared
    let r = Router.shared
    /// 아이콘을 펼친 카드 (프로그램 id)
    @State private var expanded: Set<String> = []
    /// 5개가 꽉 찼을 때 안내
    @State private var limitAlert = false

    var body: some View {
        VStack(spacing: 10) {
            newButton
            if let f = store.friend { friendCard(f) }
            if !store.programs.isEmpty { listHeader }
            ForEach(store.programs) { p in
                SwipeDelete(corner: 20, press: true, menu: false, alertTitle: "Delete this training?",
                            alertMessage: "Records you've done with it stay in History.",
                            onTap: { if p.isOpen { r.bonus = BonusRequest(kind: p.kind ?? "run", existing: p) } else { r.edit(p) } },
                            onDelete: { store.deleteProgram(p.id) }) {
                    ProgramCard(p: p, expanded: expanded.contains(p.id)) {
                        withAnimation(.snappy(duration: 0.25)) {
                            if expanded.contains(p.id) { expanded.remove(p.id) } else { expanded.insert(p.id) }
                        }
                    }
                }
                .accessibilityIdentifier("training.card")
            }
            history
        }
        .padding(.horizontal, 16)
        .alert("You can save up to \(Program.freeLimit) trainings", isPresented: $limitAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Delete one to make a new training.")
        }
    }

    /// 노란 "New training" 카드 (radius 20, 16×18, 17/600, + 22). 5개가 꽉 차면 안내만 띄움
    private var newButton: some View {
        Button {
            if store.programs.count >= Program.freeLimit { limitAlert = true } else { r.newTraining() }
        } label: {
            HStack(spacing: 0) {
                Text("New training").font(F.t(17, .semibold)).tracking(-0.17)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Glyph("i_plus", 22, .black)
            }
            .foregroundStyle(.black)
            .padding(.vertical, 16).padding(.horizontal, 18)
            .yellowFill(20)
        }
        .buttonStyle(Press())
        .accessibilityIdentifier("training.new")
    }

    /// 소제목 "My Trainings" + 오른쪽에 개수 "3 / 5"
    private var listHeader: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            SectionText("MY TRAININGS")
            Spacer(minLength: 0)
            Text(verbatim: "\(store.programs.count) / \(Program.freeLimit)")
                .font(F.num(13)).foregroundStyle(store.programs.count >= Program.freeLimit ? C.accent : C.text2)
                .accessibilityIdentifier("training.count")
        }
        .padding(.top, 14).padding(.horizontal, 4)
    }

    private func friendCard(_ f: Friend) -> some View {
        HStack(spacing: 14) {
            Avatar8(size: 36, initial: f.ini, fontSize: 13)
            VStack(alignment: .leading, spacing: 2) {
                Label8("SPLIT TARGETS")
                Text("\(f.first)'s splits").font(F.t(15))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Pills8(items: [("mine", "Mine"), ("friend", f.first)], selected: store.settings.tgtSrc) {
                store.settings.tgtSrc = $0
            }
        }
        .padding(.vertical, 14).padding(.horizontal, 18)
        .card8()
    }

    @ViewBuilder
    private var history: some View {
        let recs: [Record] = store.records(.training)
        HistoryHeader()
        if !recs.isEmpty {
            PagedCard(ids: recs.map(\.id)) { i, last in
                let rec: Record = recs[i]
                HistoryRow(title: rec.kind != nil ? rec.title.l10n : "\(rec.title.l10n) × \(rec.sets)", sub: Fm.wdm.string(from: rec.date), subTracking: 0.26,
                           time: Fm.t(rec.total), last: last, pb: store.isPB(rec), flag: rec.flag, partner: rec.partner,
                           onDelete: { store.delete(rec) }) { r.open(rec, from: .training) }
            }
        } else {
            EmptyHistory()
        }
    }
}

/// 저장된 트레이닝 카드 — 아래 기록 목록과 구분되게 옅은 노란 기운 + 노란 테두리 + 오른쪽 노란 › 버튼.
/// 아이콘 칩은 한 줄만 보이고 나머지는 "+13" (누르면 그 카드만 펼쳐지고, "Less" 를 누르면 접힘)
struct ProgramCard: View {
    let store = Store.shared
    let p: Program
    var expanded: Bool = false
    var onMore: () -> Void = {}
    private static let perRow: Int = 4
    private let cols: [GridItem] = Array(repeating: GridItem(.flexible(minimum: 0), spacing: 6), count: ProgramCard.perRow)

    /// 누르기·밀어서 삭제는 바깥 SwipeDelete 가 맡음
    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 20, style: .continuous)
        return VStack(alignment: .leading, spacing: 12) {
            header
            if p.isOpen {
                // HIIT · 러닝: 칩 대신 아이콘 하나
                HStack(spacing: 8) {
                    Icon8(p.isHIIT ? "hiit" : "run", 18, tint: .yellow)
                    Text(openLine).font(F.t(13, .semibold)).foregroundStyle(C.d1).lineLimit(1)
                }
                .padding(.horizontal, 10).frame(height: 34)
                .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            } else {
                chips
            }
        }
        .padding(.vertical, 16).padding(.horizontal, 18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            shape.fill(LinearGradient(stops: [.init(color: C.accent.opacity(0.15), location: 0),
                                              .init(color: Color.white.opacity(0.07), location: 0.55),
                                              .init(color: Color.white.opacity(0.05), location: 1)],
                                      startPoint: .topLeading, endPoint: .bottomTrailing))
        }
        .overlay(shape.strokeBorder(C.accent.opacity(0.28), lineWidth: 1))
        .clipShape(shape)
        .contentShape(Rectangle())
    }

    /// 접힌 상태: 3개 + "+N" / 펼친 상태: 전부 + "Less" / 4개 이하면 그대로
    private var chips: some View {
        let n: Int = p.seq.count
        let long: Bool = n > Self.perRow
        let collapsed: Bool = long && !expanded
        let shown: [ProgItem] = collapsed ? Array(p.seq.prefix(Self.perRow - 1)) : p.seq
        return LazyVGrid(columns: cols, spacing: 6) {
            ForEach(Array(shown.enumerated()), id: \.offset) { _, it in
                chip(it)
            }
            if collapsed {
                moreChip("+\(n - (Self.perRow - 1))")
            } else if long {
                moreChip("Less".l10n)
            }
        }
    }

    /// HIIT: "Intervals" / 러닝: "5 KM · Outdoor"
    private var openLine: String {
        if p.isHIIT { return "Intervals".l10n }
        let km: Int = p.runKm ?? 0
        let d: String = km > 0 ? "\(km) KM" : "Free run".l10n
        return d + " · " + ((p.indoor ?? false) ? "Indoor" : "Outdoor").l10n
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(p.cardMeta).font(F.t(13)).foregroundStyle(C.text2)
                Text(p.name.l10n).font(F.t(20, .semibold)).tracking(-0.4).lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            // "고르는 카드" 느낌: 노란 동그라미 안 ›
            Glyph("i_chevR", 13, .black)
                .frame(width: 30, height: 30)
                .background(C.accent, in: Circle())
        }
    }

    /// 칩 라벨: 상세의 " · " 앞부분, " REPS" 제거
    private func label(_ it: ProgItem) -> String {
        let first: String = it.detail(store.div).components(separatedBy: " · ").first ?? ""
        return first.replacingOccurrences(of: " REPS", with: "").replacingOccurrences(of: " KG", with: "KG")
    }

    private func chip(_ it: ProgItem) -> some View {
        HStack(spacing: 5) {
            Icon8(it.icon, 16, tint: .yellow)
            Text(label(it)).font(F.t(11, .semibold)).tracking(0.22).foregroundStyle(C.d1)
                .lineLimit(1).truncationMode(.tail)
        }
        .padding(.horizontal, 6)
        .frame(maxWidth: .infinity).frame(height: 34)
        .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    /// 점선 칩 ("+13" / "Less"). 카드 전체 누름(편집)보다 먼저 받음
    private func moreChip(_ text: String) -> some View {
        let shape = RoundedRectangle(cornerRadius: 10, style: .continuous)
        return Text(verbatim: text).font(F.t(12, .semibold)).foregroundStyle(C.aeb).lineLimit(1).minimumScaleFactor(0.8)
            .frame(maxWidth: .infinity).frame(height: 34)
            .overlay(shape.strokeBorder(Color.white.opacity(0.28), style: StrokeStyle(lineWidth: 1, dash: [3, 3])))
            .contentShape(Rectangle())
            .highPriorityGesture(TapGesture().onEnded { onMore() })
            .accessibilityAddTraits(.isButton)
            .accessibilityIdentifier("training.more")
    }
}

/// 기록 줄 (이름 17/500 · 날짜 13 · 시간 20/600) — 왼쪽으로 밀면 삭제
struct HistoryRow: View {
    let title: String
    let sub: String
    var subColor: Color
    var subTracking: CGFloat
    let time: String
    var delta: String?
    var deltaColor: Color
    var last: Bool
    var pb: Bool
    var flag: RecordFlag?
    /// PFT 등급 뱃지 (제목 옆)
    var grade: PFTGrade?
    var onDelete: (() -> Void)?
    let action: () -> Void

    /// partner: 더블 파트너 닉네임 (@ 없이) — 있으면 아래 줄 끝에 " · with @닉네임"
    init(title: String, sub: String, subColor: Color = C.text2, subTracking: CGFloat = 0, time: String, delta: String? = nil,
         deltaColor: Color = C.good, last: Bool = false, pb: Bool = false, flag: RecordFlag? = nil,
         grade: PFTGrade? = nil, partner: String? = nil,
         onDelete: (() -> Void)? = nil, action: @escaping () -> Void) {
        let nick: String = (partner ?? "").trimmingCharacters(in: .whitespaces)
        self.title = title; self.sub = nick.isEmpty ? sub : sub + " · " + String(localized: "with @\(nick)")
        self.subColor = subColor; self.subTracking = subTracking; self.time = time
        self.delta = delta; self.deltaColor = deltaColor; self.last = last; self.pb = pb; self.flag = flag
        self.grade = grade
        self.onDelete = onDelete; self.action = action
    }

    @ViewBuilder
    var body: some View {
        if let onDelete {
            SwipeDelete(alertTitle: "Delete this record?", onTap: action, onDelete: onDelete) { rowContent }
                .rowLine(!last)
        } else {
            Button(action: action) { rowContent }
                .buttonStyle(.plain)
                .rowLine(!last)
        }
    }

    private var rowContent: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 8) {
                    Text(title).font(F.t(17, .medium)).lineLimit(1)
                    if let grade { PFTBadge(grade: grade) }
                    if pb { PBPill() }
                    if let flag { FlagPill(flag: flag) }
                }
                Text(sub).font(F.t(13)).tracking(subTracking).monospacedDigit().foregroundStyle(subColor).lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            VStack(alignment: .trailing, spacing: 0) {
                Text(time).font(F.num(20)).tracking(-0.4).lineLimit(1)
                if let delta {
                    Text(delta).font(F.num(13)).foregroundStyle(deltaColor).lineLimit(1)
                }
            }
            .fixedSize()
        }
        .padding(.vertical, 14).padding(.horizontal, 18)
        .background(Color.black.opacity(0.001))
        .contentShape(Rectangle())
    }
}

// MARK: - I2 New / Edit training (자체 머리줄 Cancel · 제목 · Save)

struct BuilderView: View {
    let store = Store.shared
    @Bindable var r = Router.shared
    private let cols: [GridItem] = Array(repeating: GridItem(.flexible(minimum: 0), spacing: 8), count: 4)
    /// 한 세트 최대 구간 수
    static let maxSeq = 16

    // 순서 바꾸기 (손잡이를 잡고 위아래로 끌면 다른 칸이 실시간으로 밀려남)
    @State private var dragFrom: Int? = nil
    @State private var dragY: CGFloat = 0
    @State private var dragTo: Int = 0
    @State private var rowH: CGFloat = 58
    /// 방금 누른 버튼 (노란 테두리 반짝)
    @State private var flashKey: String? = nil

    var body: some View {
        VStack(spacing: 22) {
            // Cancel · 제목 · Save 는 BuilderBar (맨 위 고정, PhoneRoot 가 맨 앞에 올림)
            Field8(placeholder: "Training name", text: $r.draftName)
                .submitLabel(.done)
                .onSubmit { save() }
                .accessibilityIdentifier("builder.name")

            if let id = r.editId, let prog = store.programs.first(where: { $0.id == id }) {
                StartOnPhoneButton(mode: .training, program: prog)   // 저장된 트레이닝을 아이폰으로 바로 시작
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }

            runSection
            stationSection
            sequenceSection
            setsCard

            if r.editId == nil {
                bonusCards
            }

            if let id = r.editId {
                Button {
                    store.deleteProgram(id)
                    r.editId = nil
                    r.go(.training)
                } label: {
                    Text("Delete training").font(F.t(17, .semibold)).foregroundStyle(C.bad)
                        .frame(maxWidth: .infinity).frame(height: 50).card8(14)
                }
                .buttonStyle(Press())
                .accessibilityIdentifier("builder.delete")
            }
        }
        .padding(.horizontal, 16)
    }

    // MARK: HIIT · 러닝 카드 (새로 만들 때만, 맨 아래)

    private var bonusCards: some View {
        HStack(spacing: 10) {
            bonusCard(kind: "hiit", icon: "hiit", title: "HIIT", sub: "High-intensity intervals")
            bonusCard(kind: "run", icon: "run", title: "Running", sub: "Distance · 1 km splits")
        }
        .padding(.top, 8)
    }

    private func bonusCard(kind: String, icon: String, title: String, sub: String) -> some View {
        Button { r.bonus = BonusRequest(kind: kind) } label: {
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .top) {
                    Icon8(icon, 28, tint: .yellow)
                    Spacer(minLength: 0)
                    Chevron8()
                }
                Text(title.l10n).font(F.t(17, .semibold)).lineLimit(1).padding(.top, 12)
                Text(sub.l10n).font(F.t(13)).foregroundStyle(C.text2).lineLimit(1).minimumScaleFactor(0.85).padding(.top, 3)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .card8()
            .contentShape(Rectangle())
        }
        .buttonStyle(Press())
        .accessibilityIdentifier("builder.bonus." + kind)
    }

    // MARK: RUN

    private var runSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionText("RUN").padding(.horizontal, 4)
            LazyVGrid(columns: cols, spacing: 8) {
                ForEach(Defaults.runs, id: \.self) { d in
                    Button { add(ProgItem(icon: "run", run: d), key: "run|" + d) } label: {
                        Text(d).font(F.num(15)).foregroundStyle(.white)
                            .frame(maxWidth: .infinity).frame(height: 46)
                            .card8(12)
                            .modifier(TapMark(count: count(run: d), flash: flashKey == "run|" + d, radius: 12))
                    }
                    .buttonStyle(TileTap(radius: 12))
                    .accessibilityIdentifier("builder.run." + d)
                }
            }
        }
    }

    // MARK: STATIONS (4×2, 비율 1 : 1.08)

    private var stationSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionText("STATIONS").padding(.horizontal, 4)
            LazyVGrid(columns: cols, spacing: 8) {
                ForEach(Station.all, id: \.key) { s in
                    Button { add(ProgItem(icon: s.key), key: s.key) } label: {
                        stationTile(s)
                            .modifier(TapMark(count: count(station: s.key), flash: flashKey == s.key, radius: 16))
                    }
                        .buttonStyle(TileTap(radius: 16))
                        .accessibilityIdentifier("builder.st." + s.key)
                }
            }
        }
    }

    private func stationTile(_ s: Station) -> some View {
        Color.clear
            .aspectRatio(1 / 1.08, contentMode: .fit)
            .frame(maxWidth: .infinity)
            .overlay {
                VStack(spacing: 8) {
                    Icon8(s.key, 32, tint: .yellow)
                    Text(s.key == "farmersCarry" ? "Carry" : s.name).font(F.t(11, .semibold)).tracking(0.11)   // 버튼에서만 짧게
                        .multilineTextAlignment(.center).lineSpacing(1)
                        .foregroundStyle(.white)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(6)
            }
            .card8(16)
            .contentShape(Rectangle())
    }

    // MARK: SEQUENCE

    private var sequenceSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                SectionText(String(localized: "SEQUENCE · \(r.draftSeq.count)/\(Self.maxSeq)"))
                Spacer()
                Button("Clear all") { withAnimation { r.draftSeq = [] } }
                    .font(F.t(13, .semibold)).foregroundStyle(C.bad).buttonStyle(.plain)
                    .accessibilityIdentifier("builder.clear")
            }
            .padding(.horizontal, 4)
            if r.draftSeq.count >= Self.maxSeq {
                Text("A set can have up to 16 segments. To repeat more, increase Sets below.")
                    .font(F.t(13)).foregroundStyle(C.text2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 4).padding(.top, -4)
            }
            VStack(spacing: 0) {
                if r.draftSeq.isEmpty {
                    Text("Tap runs and stations above\nto add them here in order")
                        .font(F.t(13)).foregroundStyle(C.text3).multilineTextAlignment(.center).lineSpacing(3)
                        .frame(maxWidth: .infinity).padding(.vertical, 22).padding(.horizontal, 16)
                }
                ForEach(previewOrder, id: \.self) { i in
                    if r.draftSeq.indices.contains(i) {
                        seqRow(i, r.draftSeq[i])
                    }
                }
            }
            .card8()
        }
    }

    /// 끄는 중이면 놓일 자리 기준으로 미리 정렬한 순서 (원래 번호 목록)
    private var previewOrder: [Int] {
        var o = Array(r.draftSeq.indices)
        if let f = dragFrom, o.indices.contains(f) {
            let x = o.remove(at: f)
            o.insert(x, at: min(max(dragTo, 0), o.count))
        }
        return o
    }

    private func seqRow(_ i: Int, _ it: ProgItem) -> some View {
        let dragging: Bool = dragFrom == i
        let slot: Int = previewOrder.firstIndex(of: i) ?? i
        return HStack(spacing: 12) {
            Text("\(slot + 1)").font(F.num(13, .regular)).foregroundStyle(C.text3).frame(width: 18, alignment: .leading)
            Icon8(it.icon, 24, tint: .yellow)
            VStack(alignment: .leading, spacing: 1) {
                Text(it.name()).font(F.t(17)).lineLimit(1)
                Text(it.detail(store.div)).font(F.t(11, .semibold)).tracking(0.66).foregroundStyle(C.text2).lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Button { remove(i) } label: { removeIcon }
                .buttonStyle(.plain)
                .accessibilityIdentifier("builder.remove.\(i)")
            dragHandle
                .highPriorityGesture(reorderGesture(i))
                .accessibilityIdentifier("builder.handle.\(i)")
        }
        .padding(.vertical, 11).padding(.horizontal, 16)
        .background(GeometryReader { g in
            Color.clear.onAppear { if g.size.height > 20 { rowH = g.size.height } }
        })
        .background(dragging ? Color(hex: 0x2C2C2E) : Color.black.opacity(0.001))
        .rowLine(!dragging && slot < r.draftSeq.count - 1)
        .clipShape(RoundedRectangle(cornerRadius: dragging ? 14 : 0, style: .continuous))
        .scaleEffect(dragging ? 1.03 : 1)
        .shadow(color: .black.opacity(dragging ? 0.5 : 0), radius: 12, y: 6)
        .offset(y: dragging ? dragY - CGFloat(slot - i) * rowH : 0)
        .zIndex(dragging ? 1 : 0)
        .animation(.easeOut(duration: 0.15), value: dragging)
    }

    private func reorderGesture(_ i: Int) -> some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .global)
            .onChanged { v in
                if dragFrom == nil {
                    dragFrom = i; dragTo = i; dragY = 0
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                }
                guard dragFrom == i else { return }
                dragY = v.translation.height
                let steps: Int = Int((dragY / max(rowH, 1)).rounded())
                let t: Int = min(max(i + steps, 0), r.draftSeq.count - 1)
                if t != dragTo {
                    // 다른 칸이 부드럽게 밀려나도록 (끄는 칸은 자리 이동과 offset 보정이 같이 움직여 손가락에 붙어 있음)
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.85)) { dragTo = t }
                    UISelectionFeedbackGenerator().selectionChanged()
                }
            }
            .onEnded { _ in finishDrag() }
    }

    private func finishDrag() {
        guard let f = dragFrom else { return }
        let t: Int = min(max(dragTo, 0), r.draftSeq.count - 1)
        var tx = Transaction(); tx.disablesAnimations = true
        withTransaction(tx) {
            if f != t, r.draftSeq.indices.contains(f) {
                let x = r.draftSeq.remove(at: f)
                r.draftSeq.insert(x, at: t)
            }
            dragFrom = nil; dragY = 0; dragTo = 0
        }
    }

    /// 빼기 원 (지름 20 중 원 r=10/24 → 16.7, #2A2A2A + 빨간 −)
    private var removeIcon: some View {
        ZStack {
            Circle().fill(Color(hex: 0x2A2A2A)).frame(width: 16.7, height: 16.7)
            Capsule().fill(C.bad).frame(width: 6.7, height: 1.85)
        }
        .frame(width: 20, height: 20)
        .contentShape(Rectangle())
    }

    /// 끌기 손잡이 (두 줄 #3A3A3C, 18)
    private var dragHandle: some View {
        VStack(spacing: 4.5) {
            Capsule().fill(C.g3A).frame(width: 12, height: 1.5)
            Capsule().fill(C.g3A).frame(width: 12, height: 1.5)
        }
        .frame(width: 18, height: 18)
        .frame(width: 40, height: 40)
        .contentShape(Rectangle())
        .padding(.vertical, -11)
        .padding(.trailing, -11)
    }

    // MARK: Sets

    private var setsCard: some View {
        HStack {
            Text("Sets").font(F.t(15))
            Spacer()
            Stepper8(value: "\(r.draftSets)", down: { r.draftSets = max(1, r.draftSets - 1) },
                     up: { r.draftSets = min(20, r.draftSets + 1) })
        }
        .padding(.vertical, 12).padding(.horizontal, 16)
        .card8()
    }

    // MARK: 동작

    /// 버튼 눌러 추가: 가벼운 진동 + 노란 테두리 0.3초. 16구간 꽉 차면 추가 안 하고 다른 진동
    private func add(_ it: ProgItem, key: String) {
        guard r.draftSeq.count < Self.maxSeq else {
            UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
            return
        }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        withAnimation(.easeOut(duration: 0.15)) { r.draftSeq.append(it) }
        flashKey = key
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            if flashKey == key { withAnimation(.easeOut(duration: 0.25)) { flashKey = nil } }
        }
    }

    /// 순서에 몇 번 들어갔는지 (버튼 오른쪽 위 숫자)
    private func count(run d: String) -> Int { r.draftSeq.filter { $0.icon == "run" && ($0.run ?? "1KM") == d }.count }
    private func count(station k: String) -> Int { r.draftSeq.filter { $0.icon == k }.count }

    private func remove(_ i: Int) {
        guard r.draftSeq.indices.contains(i) else { return }
        withAnimation { _ = r.draftSeq.remove(at: i) }
    }

    /// Save: 바로 저장 (Router.saveDraft)
    private func save() { r.saveDraft() }
}

/// 만들기 화면 머리줄 (Cancel · 제목 · Save) — 스크롤해도 맨 위에 고정.
/// 스크롤 내용 안에 있을 때는 다른 것에 가려 안 눌리는 일이 있어 PhoneRoot 맨 앞 층으로 옮김
struct BuilderBar: View {
    let r = Router.shared
    var body: some View {
        VStack(spacing: 0) {
            NavBar3(left: "Cancel", title: r.editId == nil ? "New training" : "Edit training", right: "Save",
                    rightColor: r.draftSeq.isEmpty ? C.g3A : C.accent,
                    onLeft: { r.cancelDraft() },
                    onRight: { r.saveDraft() })
                .padding(.horizontal, 16)
                .background {
                    ZStack {
                        Rectangle().fill(.ultraThinMaterial)
                        Rectangle().fill(Color.black.opacity(0.55))
                    }
                    .ignoresSafeArea(edges: .top)
                }
                .overlay(alignment: .bottom) { Rectangle().fill(Color.white.opacity(0.06)).frame(height: 1) }
            Spacer(minLength: 0)
        }
    }
}

// MARK: - Save 시트 (v3: 쓰지 않음 — Save 가 바로 저장. PhoneApp 이 참조하므로 남겨 둠)

struct SaveSheet: View {
    let r = Router.shared
    var body: some View {
        Color.clear
            .frame(width: 0, height: 0)
            .onAppear { r.saveOpen = false }
    }
}

/// ★ PB 알약 (높이 20, 반경 6, 노랑 0.14 바탕, 노란 글자 11/600, 별 10)
struct PBPill: View {
    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: "star.fill").font(.system(size: 9, weight: .semibold))
            Text("PB").font(F.t(11, .semibold)).tracking(0.22)
        }
        .foregroundStyle(C.accent)
        .padding(.horizontal, 7)
        .frame(height: 20)
        .background(Color(red: 1, green: 230 / 255, blue: 0, opacity: 0.14), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
        .fixedSize()
    }
}

/// 미완료 / 확인 필요 회색 꼬리표 (이런 기록은 PB·최고 기록에서 빠짐)
struct FlagPill: View {
    let flag: RecordFlag
    var body: some View {
        Text(flag.label.l10n).font(F.t(11, .semibold)).tracking(0.22)
            .foregroundStyle(C.text2)
            .padding(.horizontal, 7)
            .frame(height: 20)
            .background(Color.white.opacity(0.10), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
            .fixedSize()
    }
}

/// 기록이 하나도 없을 때 (삭제 후 포함)
struct EmptyHistory: View {
    var body: some View {
        VStack(spacing: 4) {
            Text("No records yet").font(F.t(15, .semibold))
            Text("Start a workout on your watch and your records will show up here.").font(F.t(13)).foregroundStyle(C.text2)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 22).padding(.horizontal, 18)
        .card8()
    }
}


// MARK: - 트레이닝 만들기 버튼 눌림 표시

/// 누르는 동안: 살짝 작아지고 배경이 조금 밝아짐
struct TileTap: ButtonStyle {
    var radius: CGFloat
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .overlay {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(Color.white.opacity(configuration.isPressed ? 0.07 : 0))
                    .allowsHitTesting(false)
            }
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
            .animation(.easeOut(duration: 0.08), value: configuration.isPressed)
    }
}

/// 추가 직후 노란 테두리 + 오른쪽 위 숫자 (순서에 들어간 횟수)
struct TapMark: ViewModifier {
    let count: Int
    let flash: Bool
    let radius: CGFloat
    func body(content: Content) -> some View {
        content
            .overlay {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(C.accent, lineWidth: 1.5)
                    .opacity(flash ? 1 : 0)
                    .allowsHitTesting(false)
            }
            .overlay(alignment: .topTrailing) {
                if count > 0 {
                    Text("\(count)").font(F.num(12, .bold)).foregroundStyle(.black)
                        .padding(.horizontal, 5)
                        .frame(minWidth: 18, minHeight: 18)
                        .background(C.accent, in: Capsule())
                        .padding(5)
                        .transition(.scale.combined(with: .opacity))
                        .allowsHitTesting(false)
                }
            }
            .animation(.easeOut(duration: 0.15), value: count)
    }
}
