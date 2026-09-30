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
                ProgramCard(p: p) { r.edit(p) }
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
        if !recs.isEmpty {
            SectionLabel(text: "HISTORY", top: 20)
            VStack(spacing: 0) {
                ForEach(Array(recs.enumerated()), id: \.element.id) { i, rec in
                    HistoryRow(title: "\(rec.title) × \(rec.sets)", sub: Fm.wdm.string(from: rec.date), subTracking: 0.26,
                               time: Fm.t(rec.total), last: i == recs.count - 1,
                               onDelete: { store.delete(rec) }) { r.open(rec, from: .training) }
                }
            }
            .card8()
        }
    }
}

/// 저장된 트레이닝 카드 (padding 18, gap 16)
struct ProgramCard: View {
    let store = Store.shared
    let p: Program
    let action: () -> Void
    private let cols: [GridItem] = Array(repeating: GridItem(.flexible(minimum: 0), spacing: 6), count: 4)

    var body: some View {
        Button(action: action) {
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
        .buttonStyle(Press())
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(p.cardMeta).font(F.t(13)).foregroundStyle(C.text2)
                Text(p.name).font(F.t(20, .semibold)).tracking(-0.4).lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Glyph("i_play", 14, .black)
                .frame(width: 40, height: 40)
                .yellowCapsule()
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
    var onDelete: (() -> Void)?
    let action: () -> Void

    @State private var offset: CGFloat = 0
    @State private var settled: CGFloat = 0
    @State private var ask = false
    private let reveal: CGFloat = 84

    init(title: String, sub: String, subColor: Color = C.text2, subTracking: CGFloat = 0, time: String, delta: String? = nil,
         deltaColor: Color = C.good, last: Bool = false, onDelete: (() -> Void)? = nil, action: @escaping () -> Void) {
        self.title = title; self.sub = sub; self.subColor = subColor; self.subTracking = subTracking; self.time = time
        self.delta = delta; self.deltaColor = deltaColor; self.last = last
        self.onDelete = onDelete; self.action = action
    }

    var body: some View {
        ZStack(alignment: .trailing) {
            if onDelete != nil && offset < 0 {
                Button { ask = true } label: {
                    VStack(spacing: 3) {
                        Image(systemName: "trash").font(.system(size: 17, weight: .semibold))
                        Text("삭제").font(F.t(11, .semibold))
                    }
                    .foregroundStyle(.white)
                    .frame(width: max(reveal, -offset))
                    .frame(maxHeight: .infinity)
                    .background(C.bad)
                }
                .buttonStyle(.plain)
            }
            Button {
                if settled != 0 { close() } else { action() }
            } label: {
                rowContent
            }
            .buttonStyle(.plain)
            .offset(x: offset)
        }
        .clipped()
        .rowLine(!last)
        .simultaneousGesture(onDelete == nil ? nil : swipe)
        .alert("기록을 삭제할까요?", isPresented: $ask) {
            Button("삭제", role: .destructive) {
                close()
                onDelete?()
            }
            Button("취소", role: .cancel) { close() }
        } message: {
            Text("삭제한 기록은 다시 볼 수 없어요.")
        }
    }

    private var rowContent: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(F.t(17, .medium)).lineLimit(1)
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

    private var swipe: some Gesture {
        DragGesture(minimumDistance: 20)
            .onChanged { v in
                guard abs(v.translation.width) > abs(v.translation.height) else { return }
                offset = min(0, settled + v.translation.width)
            }
            .onEnded { v in
                let horizontal = abs(v.translation.width) > abs(v.translation.height)
                let x = horizontal ? settled + v.translation.width : settled
                withAnimation(.snappy(duration: 0.25)) {
                    if x < -200 {
                        offset = -reveal; settled = -reveal; ask = true
                    } else if x < -reveal / 2 {
                        offset = -reveal; settled = -reveal
                    } else {
                        offset = 0; settled = 0
                    }
                }
            }
    }

    private func close() {
        withAnimation(.snappy(duration: 0.25)) { offset = 0; settled = 0 }
    }
}

// MARK: - I2 New / Edit training (자체 머리줄 Cancel · 제목 · Save)

struct BuilderView: View {
    let store = Store.shared
    @Bindable var r = Router.shared
    private let cols: [GridItem] = Array(repeating: GridItem(.flexible(minimum: 0), spacing: 8), count: 4)
    /// 한 세트 최대 구간 수
    static let maxSeq = 8

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
                    Text(s.name).font(F.t(11, .semibold)).tracking(0.11)
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
                Label8("SEQUENCE · \(r.draftSeq.count)/\(Self.maxSeq)").lineLimit(1)
                Spacer()
                Button("Clear all") { withAnimation { r.draftSeq = [] } }
                    .font(F.t(13, .semibold)).foregroundStyle(C.bad).buttonStyle(.plain)
                    .accessibilityIdentifier("builder.clear")
            }
            .padding(.horizontal, 4)
            if r.draftSeq.count >= Self.maxSeq {
                Text("한 세트는 최대 8개예요. 더 반복하려면 아래 Sets를 늘리세요.")
                    .font(F.t(13)).foregroundStyle(C.text2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 4).padding(.top, -4)
            }
            VStack(spacing: 0) {
                if r.draftSeq.isEmpty {
                    Text("위에서 러닝과 스테이션을 누르면\n여기에 순서대로 쌓입니다")
                        .font(F.t(13)).foregroundStyle(C.text3).multilineTextAlignment(.center).lineSpacing(3)
                        .frame(maxWidth: .infinity).padding(.vertical, 22).padding(.horizontal, 16)
                }
                ForEach(Array(r.draftSeq.enumerated()), id: \.offset) { i, it in
                    seqRow(i, it)
                }
            }
            .card8()
        }
    }

    private func seqRow(_ i: Int, _ it: ProgItem) -> some View {
        HStack(spacing: 12) {
            Text("\(i + 1)").font(F.num(13, .regular)).foregroundStyle(C.text3).frame(width: 18, alignment: .leading)
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
        }
        .padding(.vertical, 11).padding(.horizontal, 16)
        .background(Color.black.opacity(0.001))
        .rowLine(i < r.draftSeq.count - 1)
        .draggable(String(i))
        .dropDestination(for: String.self) { items, _ in
            guard let s = items.first, let from = Int(s), from != i, r.draftSeq.indices.contains(from) else { return false }
            withAnimation {
                let x = r.draftSeq.remove(at: from)
                r.draftSeq.insert(x, at: i)
            }
            return true
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
        let name = typed.isEmpty ? "Training \(store.programs.count + 1)" : typed
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
