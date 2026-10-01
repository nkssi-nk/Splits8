import SwiftUI

// MARK: - 기록 계산 (상세 · 공유 같이 씀)

extension Store {
    /// 비교 이름과 차이(초). Race = VS GOAL, Full Simulation = VS LAST, Training = VS BEST
    func vs(_ r: Record) -> (word: String, value: Int?) {
        switch r.mode {
        case .race:
            let g = r.goal ?? r.vsTarget
            return ("VS GOAL", g.map { r.total - $0 })
        case .sim:
            return ("VS LAST", previous(for: r).map { r.total - $0.total })
        case .training:
            return ("VS BEST", previousBest(for: r).map { r.total - $0 })
        }
    }
}

extension Record {
    /// Roxzone 뺀 구간
    var mainSegs: [SegResult] { segs.filter { $0.kind != .rox } }

    /// 러닝 1KM당 페이스(초)
    func pace(_ s: SegResult) -> Int {
        let m = s.dist ?? runMeters(s.detail)
        guard m > 0 else { return s.time }
        return Int((Double(s.time) / m * 1000).rounded())
    }

    /// 심박 존별 시간(초) Z1…Z5
    func zoneSeconds(_ st: Settings) -> [Int] {
        var z = [0, 0, 0, 0, 0]
        let p = hr.sorted { $0.t < $1.t }
        guard p.count > 1 else { return z }
        for i in 0..<(p.count - 1) {
            let dt = min(30, max(0, p[i + 1].t - p[i].t))
            z[st.zone(Double(p[i].b)) - 1] += dt
        }
        return z
    }
}

func deltaColor(_ v: Int?) -> Color {
    guard let v else { return C.text2 }
    return v < 0 ? C.good : v > 0 ? C.bad : C.text2
}

/// 1,042
func grouped(_ n: Int) -> String {
    let f = NumberFormatter()
    f.numberStyle = .decimal
    f.locale = Locale(identifier: "en_US")
    return f.string(from: NSNumber(value: n)) ?? "\(n)"
}

// MARK: - I6 기록 상세 (시안 isDetail)

/// 타일 한 칸 (라벨 · 값 · 단위)
private struct DetailTile {
    let label: String
    let value: String
    let unit: String
    let color: Color
    let unitColor: Color
}

struct DetailView: View {
    let store = Store.shared
    let r = Router.shared
    @State private var askDelete = false
    @State private var partnerSheet = false

    var body: some View {
        if let rec = r.detail {
            content(rec)
        } else {
            BackLink(label: backLabel) { r.go(r.detailFrom) }.padding(.horizontal, 16)
        }
    }

    private var backLabel: String {
        switch r.detailFrom {
        case .training: return "Training"
        case .sim: return "Full Simulation"
        case .home: return "Home"
        default: return "Race"
        }
    }

    // 시안: flex column, gap 10, padding 0 16
    private func content(_ rec: Record) -> some View {
        VStack(spacing: 10) {
            BackLink(label: backLabel) { r.go(r.detailFrom) }
            header(rec)
            tilesGrid(rec)
            if showsPartner(rec) {
                SectionLabel(text: "PARTNER", top: 20)
                partnerRow(rec)
            }
            shareButton
            if let f = store.friend, let me = rec.splits16, f.splits.count == 16 {
                friendCard(rec, me: me, f: f)
            }
            if !rec.hr.isEmpty {
                hrCard(rec)
                zonesCard(rec)
            }
            Group {
                if !rec.runs.isEmpty { paceCard(rec) }
                if rec.mode == .sim, let f = Fatigue.analyze([rec], limit: 1) {
                    SectionLabel(text: "RUN FATIGUE", top: 20)
                    RunFatigueCard(result: f, footnote: "Based on this Full Sim")
                }
            }
            Group {
                // SPLITS 라벨: margin 20px 4px 0
                SectionLabel(text: "SPLITS", top: 20)
                splits(rec)
            }

            deleteCard(rec).padding(.top, 10)
        }
        .padding(.horizontal, 16)
        .alert("Delete this record?", isPresented: $askDelete) {
            Button("Delete", role: .destructive) { deleteRecord(rec) }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This can't be undone.")
        }
        .sheet(isPresented: $partnerSheet) {
            PartnerSheet(current: rec.partner) { nick in setPartner(rec, nick) }
                .presentationDetents([.medium, .large])
                .presentationBackground(Color(hex: 0x1C1C1E))
        }
    }

    // MARK: 더블 파트너

    private func division(of rec: Record) -> Division? {
        Division.all.first { $0.key == rec.division || $0.name == rec.division }
    }

    private func isDoubles(_ rec: Record) -> Bool {
        division(of: rec)?.key.hasPrefix("dbl") ?? false
    }

    private func partnerNick(_ rec: Record) -> String? {
        let n: String = (rec.partner ?? "").trimmingCharacters(in: .whitespaces)
        return n.isEmpty ? nil : n
    }

    private func showsPartner(_ rec: Record) -> Bool {
        isDoubles(rec) || partnerNick(rec) != nil
    }

    /// 제목 아래 알약: (M) with @minji · Doubles Mixed
    private func partnerChip(_ rec: Record, nick: String) -> some View {
        let divName: String = isDoubles(rec) ? (division(of: rec)?.name ?? "") : ""
        return HStack(spacing: 6) {
            Avatar8(size: 22, initial: String(nick.prefix(1)).uppercased(),
                    bg: PartnerSheet.color(for: nick), fg: .black, fontSize: 12)
            Text("with @\(nick)").font(F.t(15, .semibold)).lineLimit(1)
            if !divName.isEmpty {
                Text("· \(divName)").font(F.t(13)).foregroundStyle(C.text2).lineLimit(1)
            }
        }
        .padding(.vertical, 5).padding(.leading, 5).padding(.trailing, 10)
        .background(Color.white.opacity(0.10), in: Capsule())
        .fixedSize()
        .padding(.top, 8)
    }

    private func partnerRow(_ rec: Record) -> some View {
        let nick: String? = partnerNick(rec)
        let shown: String = (nick.map { (n: String) -> String in "@" + n } ?? "") + " ›"
        return Button { partnerSheet = true } label: {
            HStack(spacing: 12) {
                Text(nick == nil ? "Add partner" : "Partner").font(F.t(15))
                    .foregroundStyle(nick == nil ? C.accent : Color.white)
                Spacer(minLength: 8)
                Text(shown).font(F.t(15)).foregroundStyle(C.text2).lineLimit(1)
            }
            .padding(.vertical, 14).padding(.horizontal, 18)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .card8()
        .accessibilityIdentifier("detail.partner")
    }

    private func setPartner(_ rec: Record, _ nick: String?) {
        var clean: String? = nil
        if let n = nick {
            var t: String = n.trimmingCharacters(in: .whitespacesAndNewlines)
            while t.hasPrefix("@") { t.removeFirst() }
            clean = t.isEmpty ? nil : t
        }
        store.updatePartner(rec.id, clean)
        if var d = r.detail, d.id == rec.id {
            d.partner = clean
            r.detail = d
        }
    }

    // MARK: 머리 (배지 · 날짜 · 큰 제목), padding 0 4 8

    private func header(_ rec: Record) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Text(rec.mode.name.l10n).font(F.t(11, .semibold)).foregroundStyle(.black)
                    .padding(.vertical, 3).padding(.horizontal, 8)
                    .background(C.accent, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                Label8(Fm.wdmy.string(from: rec.date))
                if let f = rec.flag { FlagPill(flag: f) }
            }
            LargeTitle(text: rec.title, top: 10)
                .fixedSize(horizontal: false, vertical: true)
            if let f = rec.flag {
                Text(f == .incomplete ? LocalizedStringKey("Ended early, so it doesn't count toward your PB.")
                                      : LocalizedStringKey("Faster than seems possible, so it doesn't count toward your PB. A tap may have been missed."))
                    .font(F.t(13)).foregroundStyle(C.text2)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 6)
            }
            if let nick = partnerNick(rec) {
                partnerChip(rec, nick: nick)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 4).padding(.bottom, 8)
        .background(alignment: .top) {
            if store.isPB(rec) {
                PBGlow()
                    .frame(height: 300)
                    .padding(.horizontal, -40)
                    .offset(y: -110)
                    .allowsHitTesting(false)
            }
        }
    }

    // MARK: 타일 2열 (gap 10, radius 18, padding 14×16)

    private func tiles(_ rec: Record) -> [DetailTile] {
        let vs = store.vs(rec)
        let pace: String = rec.runPace.map { Fm.t($0) } ?? "--:--"
        return [
            DetailTile(label: "TOTAL", value: Fm.t(rec.total), unit: "", color: .white, unitColor: .clear),
            DetailTile(label: vs.word, value: vs.value.map(Fm.d) ?? "--:--", unit: "", color: deltaColor(vs.value), unitColor: .clear),
            DetailTile(label: "AVG HR", value: rec.avgHR > 0 ? "\(rec.avgHR)" : "--", unit: "BPM", color: .white, unitColor: C.bad),
            DetailTile(label: "MAX HR", value: rec.maxHR > 0 ? "\(rec.maxHR)" : "--", unit: "BPM", color: .white, unitColor: C.bad),
            DetailTile(label: "CALORIES", value: grouped(rec.kcal), unit: "KCAL", color: .white, unitColor: C.text2),
            DetailTile(label: "RUN PACE", value: pace, unit: "/KM", color: .white, unitColor: C.text2),
        ]
    }

    private func tilesGrid(_ rec: Record) -> some View {
        let items: [DetailTile] = tiles(rec)
        let cols: [GridItem] = [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)]
        return LazyVGrid(columns: cols, spacing: 10) {
            ForEach(items.indices, id: \.self) { i in
                tileView(items[i])
            }
        }
    }

    private func tileView(_ t: DetailTile) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Label8(t.label)
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(t.value).font(F.num(28)).tracking(-0.03 * 28).foregroundStyle(t.color)
                    .lineLimit(1).minimumScaleFactor(0.6)
                if !t.unit.isEmpty {
                    Text(t.unit).font(F.t(11, .semibold)).tracking(0.06 * 11).foregroundStyle(t.unitColor)
                        .lineLimit(1).fixedSize()
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 14).padding(.horizontal, 16)
        .card8(18)
    }

    // MARK: Share with photo (노란 유리, 52 높이, radius 14, 15/600)

    private var shareButton: some View {
        Button { r.go(.share) } label: {
            HStack(spacing: 8) {
                Glyph("i_share", 18, .black)
                Text("Share with photo").font(F.t(15, .semibold))
            }
            .foregroundStyle(.black)
            .frame(maxWidth: .infinity).frame(height: 52)
            .yellowFill(14)
        }
        .buttonStyle(Press(scale: 0.97))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Share with photo")
        .accessibilityAddTraits(.isButton)
        .accessibilityIdentifier("Share with photo")
    }

    // MARK: VS 친구

    private func firstWord(_ s: String) -> String {
        String(s.split(separator: " ").first ?? Substring(s))
    }

    private func friendCard(_ rec: Record, me: [Int], f: Friend) -> some View {
        let name = firstWord(f.first)
        let up = name.uppercased()
        let fr: [CGFloat] = [1.2, 1, 1, 1]
        return VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                Label8("VS \(up)")
                Spacer(minLength: 8)
                Text("\(f.div) · \(f.date)").font(F.t(F.foot)).foregroundStyle(C.text3).lineLimit(1).minimumScaleFactor(0.85)
            }
            friendTable(rec, f: f, up: up, fr: fr)
                .padding(.top, 14)
            friendBars(me: me, f: f)
                .padding(.top, 14)
            friendLegend(name)
                .padding(.top, 8)
        }
        .padding(18)
        .card8()
    }

    private func friendRows(_ rec: Record, f: Friend) -> [(String, Int, Int)] {
        let frRuns = stride(from: 0, to: 16, by: 2).map { f.splits[$0] }.reduce(0, +)
        let frSt = stride(from: 1, to: 16, by: 2).map { f.splits[$0] }.reduce(0, +)
        return [
            ("Total", rec.total, f.total),
            ("Runs", rec.runTotal, frRuns),
            ("Stations", rec.stationTotal, frSt),
            ("Roxzone", rec.roxTotal, 8 * Defaults.roxTarget),
        ]
    }

    // grid 1.2fr 1fr 1fr 1fr, gap 6 8
    private func friendTable(_ rec: Record, f: Friend, up: String, fr: [CGFloat]) -> some View {
        let rows = friendRows(rec, f: f)
        return VStack(spacing: 6) {
            Cols(fr: fr, spacing: 8) {
                Color.clear.frame(height: 1)
                Label8("ME", spacing: 0.08).frame(maxWidth: .infinity, alignment: .trailing)
                Label8(up, spacing: 0.08).frame(maxWidth: .infinity, alignment: .trailing)
                Label8("DIFF", spacing: 0.08).frame(maxWidth: .infinity, alignment: .trailing)
            }
            ForEach(rows.indices, id: \.self) { i in
                friendRow(rows[i], fr: fr)
            }
        }
    }

    private func friendRow(_ row: (String, Int, Int), fr: [CGFloat]) -> some View {
        let d = row.1 - row.2
        return Cols(fr: fr, spacing: 8) {
            Text(row.0.l10n).font(F.t(15)).frame(maxWidth: .infinity, alignment: .leading)
            Text(Fm.t(row.1)).font(F.num(15)).frame(maxWidth: .infinity, alignment: .trailing)
            Text(Fm.t(row.2)).font(F.num(15)).foregroundStyle(C.text2).frame(maxWidth: .infinity, alignment: .trailing)
            Text(Fm.d(d)).font(F.num(15)).foregroundStyle(deltaColor(d)).frame(maxWidth: .infinity, alignment: .trailing)
        }
        .lineLimit(1).minimumScaleFactor(0.7)
    }

    // 16쌍 막대 (44 높이, gap 2, 쌍 안 gap 1, 340초 = 100%)
    private func friendBars(me: [Int], f: Friend) -> some View {
        HStack(alignment: .bottom, spacing: 2) {
            ForEach(0..<16, id: \.self) { i in
                HStack(alignment: .bottom, spacing: 1) {
                    Rectangle().fill(Color.white).frame(height: 44 * min(1, CGFloat(me[i]) / 340))
                    Rectangle().fill(C.g3A).frame(height: 44 * min(1, CGFloat(f.splits[i]) / 340))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
            }
        }
        .frame(height: 44)
    }

    private func friendLegend(_ name: String) -> some View {
        HStack(spacing: 14) {
            HStack(spacing: 4) { Rectangle().fill(Color.white).frame(width: 8, height: 8); Text("Me") }
            HStack(spacing: 4) { Rectangle().fill(C.g3A).frame(width: 8, height: 8); Text(name).lineLimit(1) }
            Spacer(minLength: 0)
            Text("Run 1 → Wall Balls").lineLimit(1)
        }
        .font(F.t(F.foot)).foregroundStyle(C.text3)
    }

    // MARK: 심박 그래프 (140 높이, 존 띠 5개, 점선 구간 경계, 빨간 1.6 선)

    private func hrBounds(_ rec: Record) -> [Double] {
        let total = Double(max(1, rec.total))
        var bounds: [Double] = []
        var acc = 0
        for (i, s) in rec.segs.enumerated() {
            acc += s.time
            if s.kind != .rox && i < rec.segs.count - 1 { bounds.append(Double(acc) / total) }
        }
        let limit = max(0, rec.mainSegs.count - 1)
        if bounds.count > limit { bounds = Array(bounds.prefix(limit)) }
        return bounds
    }

    private func hrSample(_ rec: Record) -> [HRPoint] {
        let pts = rec.hr.sorted { $0.t < $1.t }
        let step = max(1, pts.count / 240)
        return stride(from: 0, to: pts.count, by: step).map { pts[$0] }
    }

    private static let hrBands: [Color] = [
        Color(hex: 0xFF453A, alpha: 0.12), Color(hex: 0xFF9F0A, alpha: 0.10), Color(hex: 0x30D158, alpha: 0.08),
        Color(hex: 0x0A84FF, alpha: 0.08), Color(hex: 0x8E8E93, alpha: 0.08),
    ]

    private func hrCard(_ rec: Record) -> some View {
        let total = max(1, rec.total)
        let m3 = (total / 3) / 60 * 60, m6 = (total * 2 / 3) / 60 * 60
        return VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                Label8("HEART RATE")
                Spacer(minLength: 8)
                Text("Dotted lines = split boundaries").font(F.t(F.cap1)).foregroundStyle(C.text3).lineLimit(1)
            }
            hrChart(rec)
                .frame(height: 140)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .padding(.top, 14)
            HStack {
                Text("0:00"); Spacer(); Text(Fm.t(m3)); Spacer(); Text(Fm.t(m6)); Spacer(); Text(Fm.t(rec.total))
            }
            .font(F.num(11, .regular)).foregroundStyle(C.text3).lineLimit(1)
            .padding(.top, 8)
        }
        .padding(18)
        .card8()
    }

    private func hrChart(_ rec: Record) -> some View {
        let bounds = hrBounds(rec)
        let sample = hrSample(rec)
        let total = Double(max(1, rec.total))
        return ZStack {
            VStack(spacing: 0) {
                ForEach(0..<5, id: \.self) { i in DetailView.hrBands[i] }
            }
            Canvas { ctx, size in
                let w = size.width, h = size.height
                for b in bounds {
                    var p = Path()
                    let x: CGFloat = CGFloat(b) * w
                    p.move(to: CGPoint(x: x, y: 0))
                    p.addLine(to: CGPoint(x: x, y: h))
                    ctx.stroke(p, with: .color(Color.white.opacity(0.14)), style: StrokeStyle(lineWidth: 1, dash: [2, 3]))
                }
                var line = Path()
                for (i, q) in sample.enumerated() {
                    let x: CGFloat = CGFloat(min(1, Double(q.t) / total)) * w
                    let yv: CGFloat = h - CGFloat(Double(q.b) - 90) / 100 * h
                    let y: CGFloat = min(h, max(0, yv))
                    if i == 0 { line.move(to: CGPoint(x: x, y: y)) } else { line.addLine(to: CGPoint(x: x, y: y)) }
                }
                ctx.stroke(line, with: .color(C.hr), style: StrokeStyle(lineWidth: 1.6, lineJoin: .round))
            }
        }
    }

    // MARK: 존별 시간 (gap 12)

    private func zonesCard(_ rec: Record) -> some View {
        let z = rec.zoneSeconds(store.settings)
        let mx = max(1, z.max() ?? 1)
        return VStack(alignment: .leading, spacing: 12) {
            Label8("TIME IN ZONES")
            ForEach(0..<5, id: \.self) { i in
                zoneRow(i, sec: z[i], mx: mx)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .card8()
    }

    private func zoneRow(_ i: Int, sec: Int, mx: Int) -> some View {
        HStack(spacing: 12) {
            Text("Z\(i + 1)").font(F.t(13, .semibold)).foregroundStyle(C.d1)
                .frame(width: 22, alignment: .leading)
            GeometryReader { g in
                ZStack(alignment: .leading) {
                    Rectangle().fill(C.btn1A)
                    Rectangle().fill(C.zones[i]).frame(width: g.size.width * CGFloat(sec) / CGFloat(mx))
                }
            }
            .frame(height: 6)
            Text(Fm.t(sec)).font(F.num(15, .medium)).frame(width: 44, alignment: .trailing)
                .lineLimit(1).minimumScaleFactor(0.7)
        }
    }

    // MARK: 러닝 페이스 (막대 8개, 가장 빠른 것 노랑)

    private func paceCard(_ rec: Record) -> some View {
        let paces: [Int] = rec.runs.map { rec.pace($0) }
        let avg: String = rec.runPace.map { Fm.t($0) } ?? "--:--"
        return VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                Label8("RUN PACE")
                Spacer(minLength: 8)
                Text(String(localized: "AVG \(avg) /KM")).font(F.num(15)).lineLimit(1)
            }
            paceBars(paces)
                .frame(height: 110)
                .padding(.top, 16)
        }
        .padding(18)
        .card8()
    }

    private func paceBars(_ paces: [Int]) -> some View {
        let mn = paces.min() ?? 0, mx = paces.max() ?? 0
        return HStack(alignment: .bottom, spacing: 8) {
            ForEach(paces.indices, id: \.self) { i in
                paceBar(paces[i], index: i, mn: mn, mx: mx)
            }
        }
    }

    // 시안: height = 40% + (p − min + 6)/(max − min + 6) × 55% of 110, 위아래 글자 때문에 72에서 멈춤 (CSS flex-shrink)
    private func paceBar(_ p: Int, index i: Int, mn: Int, mx: Int) -> some View {
        let pct: Double = 0.40 + Double(p - mn + 6) / Double(mx - mn + 6) * 0.55
        let barH: CGFloat = min(110 * CGFloat(pct), 72)
        return VStack(spacing: 6) {
            Text(Fm.t(p)).font(F.num(11, .medium)).foregroundStyle(C.aeb)
                .lineLimit(1).minimumScaleFactor(0.7)
            Rectangle().fill(p == mn ? C.accent : C.control)
                .frame(height: barH)
            Text("R\(i + 1)").font(F.t(11, .semibold)).foregroundStyle(C.text3).lineLimit(1)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
    }

    // MARK: 구간 기록 (padding 11×18)

    private func splits(_ rec: Record) -> some View {
        let segs = rec.mainSegs
        return VStack(spacing: 0) {
            ForEach(segs.indices, id: \.self) { i in
                splitRow(rec, segs[i], last: i == segs.count - 1)
            }
        }
        .card8()
    }

    private func splitRow(_ rec: Record, _ s: SegResult, last: Bool) -> some View {
        let d = s.time - s.target
        let first: String = s.kind == .run ? "\(Fm.t(rec.pace(s))) /KM" : s.detail
        let bpm: String = s.hr.map { String($0) } ?? "--"
        let sub = "\(first) · \(bpm) BPM"
        return HStack(spacing: 12) {
            Icon8(s.icon, 24, tint: s.kind == .run ? .white : .yellow)
            VStack(alignment: .leading, spacing: 1) {
                Text(s.name).font(F.t(15, .medium)).lineLimit(1)
                Text(sub).font(F.num(11, .medium)).tracking(0.02 * 11)
                    .foregroundStyle(C.text2).lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            VStack(alignment: .trailing, spacing: 0) {
                Text(Fm.t(s.time)).font(F.num(17)).tracking(-0.01 * 17).lineLimit(1)
                Text(Fm.d(d)).font(F.num(11)).foregroundStyle(deltaColor(d)).lineLimit(1)
            }
            .fixedSize()
        }
        .padding(.vertical, 11).padding(.horizontal, 18)
        .rowLine(!last)
    }

    // MARK: 기록 지우기 (Delete training 과 같은 모양: 50 높이, radius 14 카드, 빨강 17/600)

    private func deleteCard(_ rec: Record) -> some View {
        Button { askDelete = true } label: {
            Text("Delete record").font(F.t(17, .semibold)).foregroundStyle(C.bad)
                .frame(maxWidth: .infinity).frame(height: 50)
                .card8(14)
                .contentShape(Rectangle())
        }
        .buttonStyle(Press())
        .accessibilityIdentifier("detail.delete")
    }

    private func deleteRecord(_ rec: Record) {
        let from = r.detailFrom
        r.go(from)
        withAnimation(.easeInOut(duration: 0.25)) {
            store.delete(rec)
        }
    }
}

/// 비율로 칸 나누기 (CSS grid 1.2fr 1fr 1fr 1fr)
struct Cols: Layout {
    var fr: [CGFloat]
    var spacing: CGFloat = 8
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let w = proposal.width ?? 300
        let ws = widths(w)
        let h = subviews.indices.map { subviews[$0].sizeThatFits(ProposedViewSize(width: ws[min($0, ws.count - 1)], height: nil)).height }.max() ?? 0
        return CGSize(width: w, height: h)
    }
    func placeSubviews(in b: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let ws = widths(b.width)
        var x = b.minX
        for (i, s) in subviews.enumerated() {
            let w = ws[min(i, ws.count - 1)]
            s.place(at: CGPoint(x: x, y: b.midY), anchor: .leading, proposal: ProposedViewSize(width: w, height: nil))
            x += w + spacing
        }
    }
    private func widths(_ total: CGFloat) -> [CGFloat] {
        let sum = fr.reduce(0, +)
        let free = max(0, total - spacing * CGFloat(max(0, fr.count - 1)))
        return fr.map { free * $0 / sum }
    }
}

/// ★ PB 기록을 열면 머리 뒤에 큰 노란 빛 (시안 s8burst: 0 → 1 (0.43초) → 0.45 (2.4초까지))
struct PBGlow: View {
    @State private var phase = 0
    private var opacity: Double { phase == 0 ? 0 : (phase == 1 ? 1 : 0.45) }
    var body: some View {
        AmbientLayer(a: Ambient(hex: 0xFFE600, alpha: 0.55, rx: 0.6, ry: 0.65, cx: 0.5, cy: 0.3))
            .opacity(opacity)
            .onAppear {
                withAnimation(.easeOut(duration: 0.43)) { phase = 1 }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.43) {
                    withAnimation(.easeOut(duration: 1.97)) { phase = 2 }
                }
            }
    }
}

// MARK: - 파트너 고르기 시트 (친구 목록 · 직접 입력 · 빼기)

struct PartnerSheet: View {
    let current: String?
    let onSave: (String?) -> Void
    let store = Store.shared
    @Environment(\.dismiss) private var dismiss
    @State private var typing = false
    @State private var typed = ""
    @FocusState private var focused: Bool

    private static let palette: [UInt32] = [0x30D158, 0x0A84FF, 0xFF9F0A, 0xBF5AF2, 0x64D2FF, 0xFF375F]

    /// 닉네임마다 늘 같은 색
    static func color(for nick: String) -> Color {
        var h: Int = 0
        for u in nick.lowercased().unicodeScalars { h = (h &* 31 &+ Int(u.value)) & 0x7FFFFFFF }
        return Color(hex: palette[h % palette.count])
    }

    private var currentLower: String { (current ?? "").lowercased() }

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                NavBar3(left: "Cancel", title: "Partner", right: typing ? "Save" : nil,
                        rightColor: typed.trimmingCharacters(in: .whitespaces).isEmpty ? C.g3A : C.accent,
                        onLeft: { dismiss() }, onRight: { saveTyped() }, edgeBack: false)
                SectionLabel(text: "CHOOSE PARTNER", top: 10)
                VStack(spacing: 0) {
                    ForEach(store.friends) { f in
                        friendRow(f)
                    }
                    typeRow
                }
                .card8()
                if current != nil {
                    Button {
                        onSave(nil)
                        dismiss()
                    } label: {
                        Text("Remove partner").font(F.t(17, .semibold)).foregroundStyle(C.bad)
                            .frame(maxWidth: .infinity).frame(height: 50)
                            .card8(14)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(Press())
                    .padding(.top, 10)
                    .accessibilityIdentifier("partner.remove")
                }
            }
            .padding(.horizontal, 16).padding(.top, 8).padding(.bottom, 24)
        }
    }

    private func friendRow(_ f: Friend) -> some View {
        let on: Bool = f.name.lowercased() == currentLower
        return Button {
            onSave(f.name)
            dismiss()
        } label: {
            HStack(spacing: 12) {
                Avatar8(size: 30, initial: f.ini, bg: Self.color(for: f.name), fg: .black, fontSize: 13)
                Text("@\(f.name)").font(F.t(15)).lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if on { Check8(size: 18) }
            }
            .padding(.vertical, 12).padding(.horizontal, 18)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .rowLine(true)
    }

    @ViewBuilder
    private var typeRow: some View {
        if typing {
            HStack(spacing: 8) {
                Text("@").font(F.t(15)).foregroundStyle(C.text2)
                TextField("nickname", text: $typed)
                    .font(F.t(15))
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .submitLabel(.done)
                    .focused($focused)
                    .onSubmit { saveTyped() }
                    .accessibilityIdentifier("partner.field")
            }
            .padding(.vertical, 14).padding(.horizontal, 18)
            .onAppear { focused = true }
        } else {
            Button {
                let isFriend: Bool = store.friends.contains { $0.name.lowercased() == currentLower }
                typed = isFriend ? "" : (current ?? "")
                typing = true
            } label: {
                Text("＋ Type a name").font(F.t(15)).foregroundStyle(C.accent)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 14).padding(.horizontal, 18)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("partner.type")
        }
    }

    private func saveTyped() {
        let t: String = typed.trimmingCharacters(in: .whitespacesAndNewlines)
        guard typing, !t.isEmpty else { return }
        onSave(t)
        dismiss()
    }
}
