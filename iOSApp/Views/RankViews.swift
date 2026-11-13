import SwiftUI
import PhotosUI
import Vision

// MARK: - 1.2.4 · 공식 기록 카드 · 공식 결과 넣기
// 안드로이드 screens/Rank.kt 와 같은 화면. 대략 상위 % 는 BenchViews (80번) 그대로

/// 공식 기록: OFFICIAL · 공식 시간 · 순위 (Rank (M/W) · Rank (AG)) · 참가 인원 넣으면 상위 %
struct OfficialCard: View {
    let rec: Record
    let o: OfficialResult

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Text("OFFICIAL").font(F.t(10, .bold)).foregroundStyle(.black)
                    .padding(.vertical, 2).padding(.horizontal, 7)
                    .background(C.accent, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                Text(verbatim: "\(o.event) · \(o.division.l10n)").font(F.t(13)).foregroundStyle(C.text2).lineLimit(1)
            }
            HStack(spacing: 14) {
                if let rk = o.rank {
                    stat(String(format: "#%d", rk), "Rank (M/W)")
                }
                if let ag = o.ageRank { stat(String(format: "#%d", ag), "Rank (AG)") }
                if let p = o.topPct { stat(String(format: "%.1f%%", p), "Top") }
            }
            .padding(.top, 4)
            Text("Official ranks are from the race results: Rank (M/W) is within your division and gender, Rank (AG) within your age group.")
                .font(F.t(11)).foregroundStyle(C.text3).fixedSize(horizontal: false, vertical: true).padding(.top, 4)
        }
        .padding(.vertical, 16).padding(.horizontal, 18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .card8()
        .accessibilityIdentifier("detail.official")
    }

    private func stat(_ v: String, _ label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(v).font(F.num(24)).foregroundStyle(C.accent)
            Text(label.l10n).font(F.t(11, .semibold)).foregroundStyle(C.text3)
        }
    }
}

// MARK: - 대회 화면 맨 아래: 공식 결과 넣기

/// 대회 화면(SetEventView) 맨 아래: 설명 + Add official result + Official results ↗
struct OfficialEntrySection: View {
    let ev: RaceEvent
    @State private var sheet = false
    static let resultsURL: URL = URL(string: "https://results.hyrox.com")!

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel(text: "OFFICIAL RESULT", top: 14)
            Text("After the race, take a screenshot of your result on the official results page and add it here. The photo is read only on this device. Your recorded workout stays as it is, and the official result is saved as one more record.")
                .font(F.t(13)).foregroundStyle(C.text2).fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 4)
            YellowButton(height: 48, radius: 24, enabled: ev.isSet, action: { sheet = true }) {
                Text("Add official result").font(F.t(16, .semibold))
            }
            .accessibilityIdentifier("ev.addOfficial")
            Link(destination: Self.resultsURL) {
                Text("Official results ↗").font(F.t(14, .semibold)).foregroundStyle(C.accent)
                    .frame(maxWidth: .infinity)
            }
            .accessibilityIdentifier("ev.officialResults")
        }
        .sheet(isPresented: $sheet) {
            OfficialImportView(ev: ev)
                .presentationDetents([.large])
                .presentationBackground(Color(hex: 0x141414))
        }
    }
}

/// 공식 결과 넣기: 캡처 고르기 → 이 기기 안에서 글자 읽기 → 표에서 확인 · 고치기 → Save → 공식 기록 하나 더
struct OfficialImportView: View {
    let ev: RaceEvent
    let store = Store.shared
    @Environment(\.dismiss) private var dismiss
    @State private var item: PhotosPickerItem? = nil
    @State private var reading = false
    @State private var readOnce = false
    @State private var note: String = ""
    // 칸 (글자) — 비어 있으면 못 읽은 칸 (노란 테두리)
    @State private var event: String = ""
    @State private var division: String = ""
    @State private var total: String = ""
    @State private var rank: String = ""
    @State private var ageRank: String = ""
    @State private var field: String = ""
    @State private var runs: [String] = Array(repeating: "", count: 8)
    @State private var st: [String] = Array(repeating: "", count: 8)
    @State private var rox: String = ""

    var body: some View {
        VStack(spacing: 0) {
            NavBar3(left: "Cancel", title: "Official result", right: "Save",
                    rightColor: canSave ? C.accent : C.g3A,
                    onLeft: { dismiss() }, onRight: save, edgeBack: false)
                .padding(.horizontal, 16).padding(.top, 8)
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    PhotosPicker(selection: $item, matching: .images) {
                        HStack(spacing: 8) {
                            Image(systemName: "photo").font(.system(size: 15, weight: .semibold))
                            Text(readOnce ? "Choose another screenshot" : "Choose screenshot").font(F.t(16, .semibold))
                        }
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity).frame(height: 48)
                        .background(C.accent, in: Capsule())
                    }
                    .accessibilityIdentifier("official.pick")
                    Text(reading ? "Reading the screenshot…".l10n : "🔒 " + "The photo is read only on this device.".l10n)
                        .font(F.t(12)).foregroundStyle(C.text2).frame(maxWidth: .infinity)
                    if !note.isEmpty {
                        Text(note).font(F.t(12)).foregroundStyle(Color(hex: 0xFF9F0A)).fixedSize(horizontal: false, vertical: true)
                    }

                    SectionLabel(text: "RESULT", top: 6)
                    VStack(spacing: 0) {
                        row("Event", $event, numeric: false)
                        divisionRow
                        row("Overall time", $total, placeholder: "1:21:30")
                        row("Rank (M/W)", $rank, placeholder: "123", digits: true)
                        row("Rank (AG)", $ageRank, placeholder: "15", digits: true)
                        row("Finishers (optional)", $field, placeholder: "—", digits: true, optional: true)
                    }
                    .card8()

                    SectionLabel(text: "SPLITS", top: 6)
                    VStack(spacing: 0) {
                        ForEach(0..<8, id: \.self) { i in
                            row(String(format: "Running %d".l10n, i + 1), $runs[i], placeholder: "4:30")
                            row(Station.all[i].name, $st[i], placeholder: "4:00")
                        }
                        row("Roxzone", $rox, placeholder: "7:00", optional: true)
                    }
                    .card8()
                    if let w = sumWarning {
                        Text(w).font(F.t(12)).foregroundStyle(Color(hex: 0xFF9F0A)).padding(.horizontal, 4)
                    }
                    Text("Only your own result is kept. Names in the screenshot are not saved.")
                        .font(F.t(11)).foregroundStyle(C.text3).padding(.horizontal, 4).padding(.bottom, 30)
                }
                .padding(.horizontal, 16).padding(.top, 10)
            }
        }
        .onAppear {
            if event.isEmpty { event = ev.name }
            if division.isEmpty { division = Division.of(store.settings.division).name }
        }
        .onChange(of: item) { _, it in
            guard let it else { return }
            Task { await read(it) }
        }
    }

    private var divisionRow: some View {
        HStack {
            Text("Division").font(F.t(15))
            Spacer(minLength: 8)
            Menu {
                ForEach(Division.all, id: \.key) { d in Button(d.name) { division = d.name } }
            } label: {
                Text(division).font(F.t(15)).foregroundStyle(C.accent)
            }
        }
        .padding(.vertical, 10).padding(.horizontal, 16)
    }

    private func row(_ label: String, _ v: Binding<String>, placeholder: String = "", numeric: Bool = true,
                     digits: Bool = false, optional: Bool = false) -> some View {
        let missing: Bool = readOnce && !optional && v.wrappedValue.trimmingCharacters(in: .whitespaces).isEmpty
        return HStack {
            Text(label.l10n).font(F.t(15)).lineLimit(1)
            Spacer(minLength: 8)
            TextField("", text: v, prompt: Text(placeholder).foregroundColor(C.text3))
                .font(numeric ? F.num(15, .medium) : F.t(15))
                .multilineTextAlignment(.trailing)
                .keyboardType(digits ? .numberPad : (numeric ? .numbersAndPunctuation : .default))
                .frame(width: numeric ? 96 : 180)
                .padding(.vertical, 5).padding(.horizontal, 8)
                .background(C.control, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(missing ? C.accent : .clear, lineWidth: 2))
        }
        .padding(.vertical, 6).padding(.horizontal, 16)
    }

    // MARK: 값

    private func secs(_ s: String) -> Int? {
        let t: String = s.trimmingCharacters(in: .whitespaces)
        guard !t.isEmpty else { return nil }
        let p: [Int] = t.split(separator: ":").compactMap { Int($0) }
        guard p.count == t.split(separator: ":").count else { return nil }
        switch p.count {
        case 3: return p[0] * 3600 + p[1] * 60 + p[2]
        case 2: return p[0] * 60 + p[1]
        default: return nil
        }
    }
    private var runSecs: [Int?] { runs.map(secs) }
    private var stSecs: [Int?] { st.map(secs) }

    private var canSave: Bool {
        guard let t = secs(total), t > 0, !event.trimmingCharacters(in: .whitespaces).isEmpty else { return false }
        return runSecs.allSatisfy { $0 != nil } && stSecs.allSatisfy { $0 != nil }
    }

    /// 구간 합과 완주 시간이 3초 넘게 다르면 경고 한 줄
    private var sumWarning: String? {
        guard let t = secs(total), runSecs.allSatisfy({ $0 != nil }), stSecs.allSatisfy({ $0 != nil }) else { return nil }
        let sum: Int = runSecs.compactMap { $0 }.reduce(0, +) + stSecs.compactMap { $0 }.reduce(0, +) + (secs(rox) ?? 0)
        guard abs(sum - t) > 3 else { return nil }
        return String(format: "⚠ The splits add up to %@, %@ off the overall time. Please check the boxes.".l10n, Fm.t(sum), Fm.t(abs(sum - t)))
    }

    private func save() {
        guard canSave, let t = secs(total) else { return }
        let o = OfficialResult(rank: Int(rank.trimmingCharacters(in: .whitespaces)),
                               ageRank: Int(ageRank.trimmingCharacters(in: .whitespaces)),
                               field: Int(field.trimmingCharacters(in: .whitespaces)),
                               time: t, event: event.trimmingCharacters(in: .whitespaces), division: division)
        let rec: Record = OfficialParse.record(runs: runSecs.compactMap { $0 }, st: stSecs.compactMap { $0 },
                                               rox: secs(rox) ?? 0, official: o, date: ev.date)
        store.add(rec)
        dismiss()
        Router.shared.open(rec, from: .race)
    }

    // MARK: 글자 읽기 (Vision, 기기 안에서만 · 사진은 저장 안 함)

    private func read(_ it: PhotosPickerItem) async {
        reading = true
        defer { reading = false; readOnce = true }
        guard let data = try? await it.loadTransferable(type: Data.self),
              let img = UIImage(data: data), let cg = img.cgImage else {
            note = "Could not open this image.".l10n
            return
        }
        let text: String = await Self.recognize(cg)
        let d: OfficialParse.Draft = OfficialParse.parse(text)
        if let v = d.total { total = Fm.t(v) }
        if let v = d.rank { rank = String(v) }
        if let v = d.ageRank { ageRank = String(v) }
        for i in 0..<8 {
            if let v = d.runs[i] { runs[i] = Fm.t(v) }
            if let v = d.st[i] { st[i] = Fm.t(v) }
        }
        if let v = d.rox { rox = Fm.t(v) }
        note = d.found == 0 ? "Could not find a result in this image. Try a sharper screenshot, or type the times in.".l10n
                            : String(format: "Filled %d boxes from the screenshot. Please check them.".l10n, d.found)
    }

    /// 화면 글자를 줄 단위로 (같은 높이의 조각을 왼쪽부터 이어 붙임 — 결과 표는 이름 · 시간 · 순위가 따로 읽힘)
    static func recognize(_ cg: CGImage) async -> String {
        await withCheckedContinuation { (cont: CheckedContinuation<String, Never>) in
            DispatchQueue.global(qos: .userInitiated).async {
                let req = VNRecognizeTextRequest()
                req.recognitionLevel = .accurate
                req.usesLanguageCorrection = false
                req.recognitionLanguages = ["en-US", "ko-KR"]
                try? VNImageRequestHandler(cgImage: cg, options: [:]).perform([req])
                let obs: [VNRecognizedTextObservation] = req.results ?? []
                cont.resume(returning: Self.joinLines(obs.compactMap { o in
                    o.topCandidates(1).first.map { (o.boundingBox, $0.string) }
                }))
            }
        }
    }

    static func joinLines(_ items: [(CGRect, String)]) -> String {
        // Vision 좌표: 아래가 0 → 위에서부터
        let sorted = items.sorted { $0.0.midY > $1.0.midY }
        var lines: [[(CGRect, String)]] = []
        for it in sorted {
            if let last = lines.last, let ref = last.first, abs(ref.0.midY - it.0.midY) < max(ref.0.height, it.0.height) * 0.6 {
                lines[lines.count - 1].append(it)
            } else {
                lines.append([it])
            }
        }
        return lines.map { $0.sorted { $0.0.minX < $1.0.minX }.map(\.1).joined(separator: "  ") }.joined(separator: "\n")
    }
}
