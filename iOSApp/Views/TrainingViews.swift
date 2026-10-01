import SwiftUI
import UniformTypeIdentifiers

// MARK: - I1 Training (위 고정 바가 제목을 맡음 — 큰 제목 없음)

struct TrainingView: View {
    let store = Store.shared
    let r = Router.shared
    var body: some View {
        VStack(spacing: 10) {
            newButton
            if let f = store.friend { friendCard(f) }
            ForEach(store.programs) { p in
                SwipeDelete(corner: 20, press: true, alertTitle: "Delete this training?",
                            alertMessage: "Records you've done with it stay in History.",
                            onTap: { r.edit(p) },
                            onDelete: { store.deleteProgram(p.id) }) {
                    ProgramCard(p: p)
                }
                .accessibilityIdentifier("training.card")
            }
            history
        }
        .padding(.horizontal, 16)
    }

    /// 노란 "New training" 카드 (radius 20, 16×18, 17/600, + 22)
    private var newButton: some View {
        Button { r.newTraining() } label: {
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
            VStack(spacing: 0) {
                ForEach(Array(recs.enumerated()), id: \.element.id) { i, rec in
                    HistoryRow(title: "\(rec.title.l10n) × \(rec.sets)", sub: Fm.wdm.string(from: rec.date), subTracking: 0.26,
                               time: Fm.t(rec.total), last: i == recs.count - 1, pb: store.isPB(rec), flag: rec.flag, partner: rec.partner,
                               onDelete: { store.delete(rec) }) { r.open(rec, from: .training) }
                }
            }
            .card8()
        } else {
            EmptyHistory()
        }
    }
}

/// 저장된 트레이닝 카드 (padding 18, gap 16)
struct ProgramCard: View {
    let store = Store.shared
    let p: Program
    private let cols: [GridItem] = Array(repeating: GridItem(.flexible(minimum: 0), spacing: 6), count: 4)

    /// 누르기·밀어서 삭제는 바깥 SwipeDelete 가 맡음
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header
            LazyVGrid(columns: cols, spacing: 6) {
                ForEach(Array(p.seq.enumerated()), id: \.offset) { _, it in
                    chip(it)
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .card8()
        .contentShape(Rectangle())
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(p.cardMeta).font(F.t(13)).foregroundStyle(C.text2)
                Text(p.name.l10n).font(F.t(20, .semibold)).tracking(-0.4).lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            // 폰에서는 카드를 누르면 편집 → 시작 버튼처럼 보이지 않게 작은 회색 ›
            Chevron8()
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
    var onDelete: (() -> Void)?
    let action: () -> Void

    /// partner: 더블 파트너 닉네임 (@ 없이) — 있으면 아래 줄 끝에 " · with @닉네임"
    init(title: String, sub: String, subColor: Color = C.text2, subTracking: CGFloat = 0, time: String, delta: String? = nil,
         deltaColor: Color = C.good, last: Bool = false, pb: Bool = false, flag: RecordFlag? = nil, partner: String? = nil,
         onDelete: (() -> Void)? = nil, action: @escaping () -> Void) {
        let nick: String = (partner ?? "").trimmingCharacters(in: .whitespaces)
        self.title = title; self.sub = nick.isEmpty ? sub : sub + " · " + String(localized: "with @\(nick)")
        self.subColor = subColor; self.subTracking = subTracking; self.time = time
        self.delta = delta; self.deltaColor = deltaColor; self.last = last; self.pb = pb; self.flag = flag
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

    var body: some View {
        VStack(spacing: 22) {
            NavBar3(left: "Cancel", title: r.editId == nil ? "New training" : "Edit training", right: "Save",
                    rightColor: r.draftSeq.isEmpty ? C.g3A : C.accent,
                    onLeft: { r.editId = nil; r.go(.training) },
                    onRight: { save() })

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

    // MARK: RUN

    private var runSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label8("RUN").padding(.horizontal, 4)
            LazyVGrid(columns: cols, spacing: 8) {
                ForEach(Defaults.runs, id: \.self) { d in
                    Button { add(ProgItem(icon: "run", run: d)) } label: {
                        Text(d).font(F.num(15)).foregroundStyle(.white)
                            .frame(maxWidth: .infinity).frame(height: 46)
                            .card8(12)
                    }
                    .buttonStyle(Press(scale: 0.95))
                    .accessibilityIdentifier("builder.run." + d)
                }
            }
        }
    }

    // MARK: STATIONS (4×2, 비율 1 : 1.08)

    private var stationSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label8("STATIONS").padding(.horizontal, 4)
            LazyVGrid(columns: cols, spacing: 8) {
                ForEach(Station.all, id: \.key) { s in
                    Button { add(ProgItem(icon: s.key)) } label: { stationTile(s) }
                        .buttonStyle(Press(scale: 0.95))
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
                Label8(String(localized: "SEQUENCE · \(r.draftSeq.count)/\(Self.maxSeq)")).lineLimit(1)
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

    private func add(_ it: ProgItem) {
        guard r.draftSeq.count < Self.maxSeq else { return }
        withAnimation(.easeOut(duration: 0.15)) { r.draftSeq.append(it) }
    }

    private func remove(_ i: Int) {
        guard r.draftSeq.indices.contains(i) else { return }
        withAnimation { _ = r.draftSeq.remove(at: i) }
    }

    /// Save: 바로 저장. 이름이 비면 "Training N"
    private func save() {
        guard !r.draftSeq.isEmpty else { return }
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        let typed = r.draftName.trimmingCharacters(in: .whitespaces)
        let name = typed.isEmpty ? String(localized: "Training \(store.programs.count + 1)") : typed
        let old = store.programs.first { $0.id == r.editId }
        let p = Program(id: r.editId ?? "u\(Int(Date().timeIntervalSince1970))", name: name, sets: r.draftSets,
                        seq: r.draftSeq, meta: nil, quick: old?.quick ?? false)
        store.save(p)
        r.saveOpen = false
        r.editId = nil
        r.draftName = ""
        r.go(.training)
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
