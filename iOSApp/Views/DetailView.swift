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

// MARK: - I5 / I6 기록 상세

struct DetailView: View {
    let store = Store.shared
    let r = Router.shared

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
        default: return "Race"
        }
    }

    private func content(_ rec: Record) -> some View {
        let vs = store.vs(rec)
        return VStack(spacing: 10) {
            BackLink(label: backLabel) { r.go(r.detailFrom) }

            // 머리
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 8) {
                    Text(rec.mode.name).font(F.t(11, .semibold)).foregroundStyle(.black)
                        .padding(.vertical, 3).padding(.horizontal, 8)
                        .background(C.accent, in: RoundedRectangle(cornerRadius: 6))
                    Label8(Fm.wdmy.string(from: rec.date))
                }
                Text(rec.title).font(F.t(34, .bold)).tracking(-1.02)
                    .padding(.top, 10)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 4).padding(.bottom, 8)

            // 타일 2×3
            let tiles: [(String, String, String, Color, Color)] = [
                ("TOTAL", Fm.t(rec.total), "", .white, .clear),
                (vs.word, vs.value.map(Fm.d) ?? "--:--", "", deltaColor(vs.value), .clear),
                ("AVG HR", rec.avgHR > 0 ? "\(rec.avgHR)" : "--", "BPM", .white, C.bad),
                ("MAX HR", rec.maxHR > 0 ? "\(rec.maxHR)" : "--", "BPM", .white, C.bad),
                ("CALORIES", grouped(rec.kcal), "KCAL", .white, C.text2),
                ("RUN PACE", rec.runPace.map { Fm.t($0) } ?? "--:--", "/KM", .white, C.text2),
            ]
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                ForEach(tiles.indices, id: \.self) { i in
                    let t = tiles[i]
                    VStack(alignment: .leading, spacing: 4) {
                        Label8(t.0, size: 10)
                        HStack(alignment: .firstTextBaseline, spacing: 3) {
                            Text(t.1).font(F.num(28)).tracking(-0.84).foregroundStyle(t.3)
                                .lineLimit(1).minimumScaleFactor(0.6)
                            if !t.2.isEmpty {
                                Text(t.2).font(F.t(11, .bold)).tracking(0.66).foregroundStyle(t.4)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 14).padding(.horizontal, 16)
                    .card8(18)
                }
            }

            // 공유
            Button { r.go(.share) } label: {
                HStack(spacing: 8) {
                    Icon8("shareUp", 18, .black)
                    Text("Share with photo").font(F.t(15, .semibold))
                }
                .foregroundStyle(.black)
                .frame(maxWidth: .infinity).frame(height: 52)
                .yellowFill(14)
            }
            .buttonStyle(Press(scale: 0.97))

            if let f = store.friend, let me = rec.splits16, f.splits.count == 16 {
                friendCard(rec, me: me, f: f)
            }
            if !rec.hr.isEmpty {
                hrCard(rec)
                zonesCard(rec)
            }
            if !rec.runs.isEmpty { paceCard(rec) }

            SectionLabel(text: "SPLITS", top: 20)
            splits(rec)
        }
        .padding(.horizontal, 16)
    }

    // MARK: VS 친구

    private func friendCard(_ rec: Record, me: [Int], f: Friend) -> some View {
        let up = f.first.uppercased()
        let frRuns = stride(from: 0, to: 16, by: 2).map { f.splits[$0] }.reduce(0, +)
        let frSt = stride(from: 1, to: 16, by: 2).map { f.splits[$0] }.reduce(0, +)
        let rows: [(String, Int, Int)] = [
            ("Total", rec.total, f.total),
            ("Runs", rec.runTotal, frRuns),
            ("Stations", rec.stationTotal, frSt),
            ("Roxzone", rec.roxTotal, 8 * Defaults.roxTarget),
        ]
        let fr: [CGFloat] = [1.2, 1, 1, 1]
        return VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                Label8("VS \(up)")
                Spacer()
                Text("\(f.div) · \(f.date)").font(F.t(11)).foregroundStyle(C.text3).lineLimit(1)
            }
            VStack(spacing: 6) {
                Cols(fr: fr, spacing: 8) {
                    Color.clear.frame(height: 1)
                    Label8("ME", size: 10, spacing: 0.08).frame(maxWidth: .infinity, alignment: .trailing)
                    Label8(up, size: 10, spacing: 0.08).frame(maxWidth: .infinity, alignment: .trailing)
                    Label8("DIFF", size: 10, spacing: 0.08).frame(maxWidth: .infinity, alignment: .trailing)
                }
                ForEach(rows.indices, id: \.self) { i in
                    let row = rows[i], d = row.1 - row.2
                    Cols(fr: fr, spacing: 8) {
                        Text(row.0).font(F.t(14)).frame(maxWidth: .infinity, alignment: .leading)
                        Text(Fm.t(row.1)).font(F.num(15)).frame(maxWidth: .infinity, alignment: .trailing)
                        Text(Fm.t(row.2)).font(F.num(15)).foregroundStyle(C.text2).frame(maxWidth: .infinity, alignment: .trailing)
                        Text(Fm.d(d)).font(F.num(15)).foregroundStyle(deltaColor(d)).frame(maxWidth: .infinity, alignment: .trailing)
                    }
                    .lineLimit(1).minimumScaleFactor(0.7)
                }
            }
            .padding(.top, 14)

            HStack(alignment: .bottom, spacing: 2) {
                ForEach(0..<16, id: \.self) { i in
                    HStack(alignment: .bottom, spacing: 1) {
                        Rectangle().fill(.white).frame(height: 44 * min(1, CGFloat(me[i]) / 340))
                        Rectangle().fill(C.g3A).frame(height: 44 * min(1, CGFloat(f.splits[i]) / 340))
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                }
            }
            .frame(height: 44)
            .padding(.top, 14)

            HStack(spacing: 14) {
                HStack(spacing: 4) { Rectangle().fill(.white).frame(width: 8, height: 8); Text("Me") }
                HStack(spacing: 4) { Rectangle().fill(C.g3A).frame(width: 8, height: 8); Text(f.first) }
                Spacer()
                Text("Run 1 → Wall Balls")
            }
            .font(F.t(10)).foregroundStyle(C.text3)
            .padding(.top, 8)
        }
        .padding(18)
        .card8()
    }

    // MARK: 심박 그래프

    private func hrCard(_ rec: Record) -> some View {
        let total = max(1, rec.total)
        // 구간 경계: Roxzone 뺀 구간이 끝나는 시점 (마지막 제외)
        var bounds: [Double] = []
        var acc = 0
        for (i, s) in rec.segs.enumerated() {
            acc += s.time
            if s.kind != .rox && i < rec.segs.count - 1 { bounds.append(Double(acc) / Double(total)) }
        }
        let main = rec.mainSegs.count
        if bounds.count > max(0, main - 1) { bounds = Array(bounds.prefix(max(0, main - 1))) }
        let pts = rec.hr.sorted { $0.t < $1.t }
        let step = max(1, pts.count / 240)
        let sample = stride(from: 0, to: pts.count, by: step).map { pts[$0] }
        let m3 = (total / 3) / 60 * 60, m6 = (total * 2 / 3) / 60 * 60
        let bands: [Color] = [C.bad.opacity(0.12), Color(hex: 0xFF9F0A, alpha: 0.10), C.good.opacity(0.08),
                              Color(hex: 0x0A84FF, alpha: 0.08), C.text2.opacity(0.08)]

        return VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                Label8("HEART RATE")
                Spacer()
                Text("점선 = 구간 경계").font(F.t(11)).foregroundStyle(C.text3)
            }
            ZStack {
                VStack(spacing: 0) { ForEach(0..<5, id: \.self) { i in bands[i] } }
                Canvas { ctx, size in
                    let w = size.width, h = size.height
                    for b in bounds {
                        var p = Path()
                        p.move(to: CGPoint(x: b * w, y: 0)); p.addLine(to: CGPoint(x: b * w, y: h))
                        ctx.stroke(p, with: .color(.white.opacity(0.14)), style: StrokeStyle(lineWidth: 1, dash: [2, 3]))
                    }
                    var line = Path()
                    for (i, q) in sample.enumerated() {
                        let x = min(1, Double(q.t) / Double(total)) * w
                        let y: CGFloat = min(h, max(0, h - CGFloat(Double(q.b) - 90) / 100 * h))
                        if i == 0 { line.move(to: CGPoint(x: x, y: y)) } else { line.addLine(to: CGPoint(x: x, y: y)) }
                    }
                    ctx.stroke(line, with: .color(C.hr), style: StrokeStyle(lineWidth: 1.6, lineJoin: .round))
                }
            }
            .frame(height: 140)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .padding(.top, 14)

            HStack {
                Text("0:00"); Spacer(); Text(Fm.t(m3)); Spacer(); Text(Fm.t(m6)); Spacer(); Text(Fm.t(rec.total))
            }
            .font(F.num(11, .regular)).foregroundStyle(C.text3)
            .padding(.top, 8)
        }
        .padding(18)
        .card8()
    }

    // MARK: 존별 시간

    private func zonesCard(_ rec: Record) -> some View {
        let z = rec.zoneSeconds(store.settings)
        let mx = max(1, z.max() ?? 1)
        return VStack(alignment: .leading, spacing: 12) {
            Label8("TIME IN ZONES")
            ForEach(0..<5, id: \.self) { i in
                HStack(spacing: 12) {
                    Text("Z\(i + 1)").font(F.t(12, .semibold)).foregroundStyle(C.d1).frame(width: 22, alignment: .leading)
                    GeometryReader { g in
                        ZStack(alignment: .leading) {
                            Rectangle().fill(C.btn1A)
                            Rectangle().fill(C.zones[i]).frame(width: g.size.width * CGFloat(z[i]) / CGFloat(mx))
                        }
                    }
                    .frame(height: 6)
                    Text(Fm.t(z[i])).font(F.num(14, .medium)).frame(width: 44, alignment: .trailing)
                        .lineLimit(1).minimumScaleFactor(0.7)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .card8()
    }

    // MARK: 러닝 페이스

    private func paceCard(_ rec: Record) -> some View {
        let paces = rec.runs.map { rec.pace($0) }
        let mn = paces.min() ?? 0, mx = paces.max() ?? 0
        return VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                Label8("RUN PACE")
                Spacer()
                Text("AVG \(rec.runPace.map { Fm.t($0) } ?? "--:--") /KM").font(F.num(14))
            }
            HStack(alignment: .bottom, spacing: 8) {
                ForEach(paces.indices, id: \.self) { i in
                    let p = paces[i]
                    let pct = 0.40 + Double(p - mn + 6) / Double(mx - mn + 6) * 0.55
                    VStack(spacing: 6) {
                        Text(Fm.t(p)).font(F.num(10, .medium)).foregroundStyle(C.aeb)
                            .lineLimit(1).minimumScaleFactor(0.6)
                        Rectangle().fill(p == mn ? C.accent : C.control)
                            .frame(height: min(110 * pct, 74))
                        Text("R\(i + 1)").font(F.t(10, .semibold)).foregroundStyle(C.text3).lineLimit(1)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                }
            }
            .frame(height: 110)
            .padding(.top, 16)
        }
        .padding(18)
        .card8()
    }

    // MARK: 구간 기록

    private func splits(_ rec: Record) -> some View {
        let segs = rec.mainSegs
        return VStack(spacing: 0) {
            ForEach(segs.indices, id: \.self) { i in
                let s = segs[i], d = s.time - s.target
                let sub = (s.kind == .run ? "\(Fm.t(rec.pace(s))) /KM" : s.detail) + " · \(s.hr.map(String.init) ?? "--") BPM"
                HStack(spacing: 12) {
                    Icon8(s.icon, 24, tint: s.kind == .run ? .white : .yellow)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(s.name).font(F.t(15, .medium)).lineLimit(1)
                        Text(sub).font(F.t(11, .medium)).monospacedDigit().tracking(0.22)
                            .foregroundStyle(C.text2).lineLimit(1)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    VStack(alignment: .trailing, spacing: 0) {
                        Text(Fm.t(s.time)).font(F.num(17)).tracking(-0.17)
                        Text(Fm.d(d)).font(F.num(11)).foregroundStyle(deltaColor(d))
                    }
                }
                .padding(.vertical, 11).padding(.horizontal, 18)
                .rowLine(i < segs.count - 1)
            }
        }
        .card8()
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
