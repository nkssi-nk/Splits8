import SwiftUI
import UniformTypeIdentifiers

// MARK: - I1 Training

struct TrainingView: View {
    let store = Store.shared
    let r = Router.shared

    var body: some View {
        VStack(spacing: 10) {
            LargeTitle(text: "Training")

            Button { r.newTraining() } label: {
                HStack {
                    Text("New training").font(F.t(17, .semibold)).tracking(-0.17)
                    Spacer()
                    Image(systemName: "plus").font(.system(size: 20, weight: .medium))
                }
                .foregroundStyle(.black)
                .padding(.vertical, 16).padding(.horizontal, 18)
                .background(C.accent, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            }
            .buttonStyle(Press())

            if let f = store.friend {
                HStack(spacing: 14) {
                    Text(String(f.name.prefix(1))).font(F.t(13, .semibold))
                        .frame(width: 36, height: 36).background(C.control, in: Circle())
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

            ForEach(store.programs) { p in
                ProgramCard(p: p) { r.edit(p) }
            }

            let recs = store.records(.training)
            if !recs.isEmpty {
                SectionLabel(text: "HISTORY")
                VStack(spacing: 0) {
                    ForEach(Array(recs.enumerated()), id: \.element.id) { i, rec in
                        HistoryRow(title: "\(rec.title) × \(rec.sets)", sub: Fm.wdm.string(from: rec.date),
                                   time: Fm.t(rec.total), last: i == recs.count - 1) { r.open(rec, from: .training) }
                    }
                }
                .card8()
            }
        }
        .padding(.horizontal, 16)
    }
}

struct ProgramCard: View {
    let store = Store.shared
    let p: Program
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(p.cardMeta).font(F.t(13)).foregroundStyle(C.text2)
                        Text(p.name).font(F.t(22, .semibold)).tracking(-0.44).lineLimit(1)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    Icon8("play", 14, .black)
                        .frame(width: 40, height: 40)
                        .background(C.accent, in: Circle())
                }
                Flow(spacing: 6) {
                    ForEach(Array(p.seq.prefix(5).enumerated()), id: \.offset) { _, it in
                        HStack(spacing: 6) {
                            Icon8(it.icon, 18, tint: .yellow)
                            Text(it.detail(store.div).components(separatedBy: " · ").first ?? "")
                                .font(F.t(11, .semibold)).tracking(0.66).foregroundStyle(C.d1).lineLimit(1)
                        }
                        .padding(.vertical, 6).padding(.leading, 8).padding(.trailing, 10)
                        .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
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
}

/// 기록 줄 (이름·날짜·시간)
struct HistoryRow: View {
    let title: String
    let sub: String
    var subColor: Color = C.text2
    let time: String
    var delta: String? = nil
    var deltaColor: Color = C.good
    var last = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(F.t(16, .medium)).lineLimit(1)
                    Text(sub).font(F.t(12)).tracking(0.24).monospacedDigit().foregroundStyle(subColor)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                VStack(alignment: .trailing, spacing: 0) {
                    Text(time).font(F.num(20)).tracking(-0.4)
                    if let delta { Text(delta).font(F.num(12)).foregroundStyle(deltaColor) }
                }
            }
            .padding(.vertical, 14).padding(.horizontal, 18)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .rowLine(!last)
    }
}

// MARK: - I2 New / Edit training

struct BuilderView: View {
    let store = Store.shared
    @Bindable var r = Router.shared
    private let cols = Array(repeating: GridItem(.flexible(), spacing: 8), count: 4)

    var body: some View {
        VStack(spacing: 22) {
            NavBar3(left: "Cancel", title: r.editId == nil ? "New training" : "Edit training", right: "Save",
                    rightColor: r.draftSeq.isEmpty ? C.g3A : C.accent,
                    onLeft: { r.go(.training) },
                    onRight: { if !r.draftSeq.isEmpty { withAnimation(.easeOut(duration: 0.25)) { r.saveOpen = true } } })

            Field8(placeholder: "Training name", text: $r.draftName)

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
                    }
                }
            }

            VStack(alignment: .leading, spacing: 10) {
                Label8("STATIONS").padding(.horizontal, 4)
                LazyVGrid(columns: cols, spacing: 8) {
                    ForEach(Station.all, id: \.key) { s in
                        Button { add(ProgItem(icon: s.key)) } label: {
                            VStack(spacing: 8) {
                                Icon8(s.key, 32, tint: .yellow)
                                Text(s.name).font(F.t(10, .semibold)).tracking(0.1).multilineTextAlignment(.center)
                                    .foregroundStyle(.white).lineLimit(2)
                            }
                            .padding(6)
                            .frame(maxWidth: .infinity)
                            .aspectRatio(1 / 1.08, contentMode: .fit)
                            .card8(16)
                        }
                        .buttonStyle(Press(scale: 0.95))
                    }
                }
            }

            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .firstTextBaseline) {
                    Label8("SEQUENCE · \(r.draftSeq.count)")
                    Spacer()
                    Button("Clear all") { withAnimation { r.draftSeq = [] } }
                        .font(F.t(12, .semibold)).foregroundStyle(C.bad).buttonStyle(.plain)
                }
                .padding(.horizontal, 4)
                VStack(spacing: 0) {
                    if r.draftSeq.isEmpty {
                        Text("위에서 러닝과 스테이션을 누르면\n여기에 순서대로 쌓입니다")
                            .font(F.t(13)).foregroundStyle(C.text3).multilineTextAlignment(.center).lineSpacing(6)
                            .frame(maxWidth: .infinity).padding(.vertical, 22).padding(.horizontal, 16)
                    }
                    ForEach(Array(r.draftSeq.enumerated()), id: \.offset) { i, it in
                        seqRow(i, it)
                    }
                }
                .card8()
            }

            HStack {
                Text("Sets").font(F.t(15))
                Spacer()
                Stepper8(value: "\(r.draftSets)", down: { r.draftSets = max(1, r.draftSets - 1) },
                         up: { r.draftSets = min(20, r.draftSets + 1) })
            }
            .padding(.vertical, 12).padding(.horizontal, 16)
            .card8()

            if let id = r.editId {
                Button {
                    store.deleteProgram(id)
                    r.go(.training)
                } label: {
                    Text("Delete training").font(F.t(16, .semibold)).foregroundStyle(C.bad)
                        .frame(maxWidth: .infinity).frame(height: 50).card8(14)
                }
                .buttonStyle(Press())
            }
        }
        .padding(.horizontal, 16)
    }

    private func add(_ it: ProgItem) {
        withAnimation(.easeOut(duration: 0.15)) { r.draftSeq.append(it) }
    }

    private func seqRow(_ i: Int, _ it: ProgItem) -> some View {
        HStack(spacing: 12) {
            Text("\(i + 1)").font(F.num(13, .regular)).foregroundStyle(C.text3).frame(width: 18, alignment: .leading)
            Icon8(it.icon, 24, tint: .yellow)
            VStack(alignment: .leading, spacing: 1) {
                Text(it.name()).font(F.t(16))
                Text(it.detail(store.div)).font(F.t(11, .semibold)).tracking(0.66).foregroundStyle(C.text2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Button { withAnimation { _ = r.draftSeq.remove(at: i) } } label: {
                ZStack {
                    Circle().fill(Color(hex: 0x2A2A2A))
                    Capsule().fill(C.bad).frame(width: 7, height: 1.9)
                }
                .frame(width: 17, height: 17).frame(width: 20, height: 20)
            }
            .buttonStyle(.plain)
            VStack(spacing: 4.5) {
                Capsule().fill(C.g3A).frame(width: 12, height: 1.5)
                Capsule().fill(C.g3A).frame(width: 12, height: 1.5)
            }
            .frame(width: 18, height: 18)
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
}

// MARK: - Save 시트

struct SaveSheet: View {
    let store = Store.shared
    @Bindable var r = Router.shared

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.black.opacity(0.6).ignoresSafeArea()
                .onTapGesture { withAnimation { r.saveOpen = false } }
            VStack(alignment: .leading, spacing: 16) {
                Capsule().fill(C.g3A).frame(width: 36, height: 5).frame(maxWidth: .infinity)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Save training").font(F.t(22, .semibold)).tracking(-0.44)
                    Text("\(r.draftSeq.count) segments · \(r.draftSets) sets").font(F.t(14)).foregroundStyle(C.text2)
                }
                TextField("", text: $r.draftName, prompt: Text("Training name").foregroundColor(C.text3))
                    .font(F.t(17))
                    .padding(.vertical, 14).padding(.horizontal, 16)
                    .background(Color.black, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(C.control, lineWidth: 1))
                let ok = !r.draftName.trimmingCharacters(in: .whitespaces).isEmpty
                Button { save() } label: {
                    Text("Save").font(F.t(16, .semibold)).foregroundStyle(ok ? .black : C.text3)
                        .frame(maxWidth: .infinity).frame(height: 52)
                        .background(ok ? C.accent : C.control, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(Press())
                .disabled(!ok)
            }
            .padding(.top, 14).padding(.horizontal, 20).padding(.bottom, 44)
            .background(Color(hex: 0x141414), in: UnevenRoundedRectangle(topLeadingRadius: 28, topTrailingRadius: 28))
            .transition(.move(edge: .bottom))
        }
        .ignoresSafeArea(edges: .bottom)
    }

    private func save() {
        let name = r.draftName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        let old = store.programs.first { $0.id == r.editId }
        let p = Program(id: r.editId ?? "u\(Int(Date().timeIntervalSince1970))", name: name, sets: r.draftSets,
                        seq: r.draftSeq, meta: nil, quick: old?.quick ?? false)
        store.save(p)
        r.saveOpen = false
        r.editId = nil
        r.go(.training)
    }
}
