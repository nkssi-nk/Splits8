import SwiftUI
import PhotosUI

// MARK: - 공유 카드에 들어갈 값

struct ShareData {
    struct Part { let t: Int; let run: Bool; let icon: String }
    struct Pair { let no: String; let icon: String; let sn: String; let rt: String; let st: String }
    var badge = ""          // Race · Open Men
    var place = ""          // Incheon
    var divName = ""        // Open Men
    var date = ""           // 13 Sep 2026
    var total = ""          // 1:15:03
    var avgHR = ""          // 164
    var rox = ""            // 4:48
    var kcal = ""           // 1,042
    var vsWord = ""         // VS GOAL
    var vsValue = ""        // −0:27
    var pb = false          // ★ PB
    var pairs: [Pair] = []
    var seq: [Part] = []
    var runTotal = ""
    var stationTotal = ""
    var partner = ""        // 더블 파트너 닉네임 (@ 없이) · 없으면 ""

    /// "with @jiho" · 파트너 없으면 ""
    var partnerText: String { partner.isEmpty ? "" : "with @" + partner }

    init() {}

    init(_ r: Record, store: Store) {
        let div = Division.of(r.division)
        badge = "\(r.mode.name) · \(div.name)"
        place = r.title
        divName = div.name
        date = ShareData.cardDate.string(from: r.date)     // 카드 그림은 영어 시안 그대로 (앱 언어와 상관없이)
        total = Fm.t(r.total)
        avgHR = r.avgHR > 0 ? "\(r.avgHR)" : "--"
        rox = Fm.t(r.roxTotal)
        kcal = ShareData.kcalText(r.kcal)
        let v = store.vs(r)
        vsWord = v.word
        vsValue = v.value.map(Fm.d) ?? "--:--"
        pb = store.isPB(r)
        let runs = r.runs
        let sts = r.segs.filter { $0.kind == .st }
        pairs = (0..<max(runs.count, sts.count)).map { i in
            Pair(no: String(format: "%02d", i + 1),
                 icon: i < sts.count ? sts[i].icon : "run",
                 sn: i < sts.count ? ShareData.short(sts[i].name) : "",
                 rt: i < runs.count ? Fm.t(runs[i].time) : "",
                 st: i < sts.count ? Fm.t(sts[i].time) : "")
        }
        seq = r.mainSegs.map { Part(t: $0.time, run: $0.kind == .run, icon: $0.icon) }
        runTotal = Fm.t(r.runTotal)
        stationTotal = Fm.t(r.stationTotal)
        partner = (r.partner ?? "").trimmingCharacters(in: .whitespaces)
    }

    static func short(_ n: String) -> String { n == "Farmers Carry" ? "Farmers" : n }

    /// 13 Sep 2026 — 공유 카드 전용 (영어 고정)
    static let cardDate: DateFormatter = {
        let f = DateFormatter(); f.locale = Locale(identifier: "en_GB"); f.dateFormat = "d MMM yyyy"; return f
    }()

    /// 1,042 (천 단위 쉼표) · 0 이면 "--"
    private static let kcalFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.locale = Locale(identifier: "en_US")
        return f
    }()
    static func kcalText(_ k: Int) -> String {
        guard k > 0 else { return "--" }
        return kcalFormatter.string(from: NSNumber(value: k)) ?? "\(k)"
    }
}

// MARK: - 공유 카드 (SplitsShare.dc.html) 360 × 640 (Story) / 360 × 450 (Post)

struct ShareCard: View {
    let d: ShareData
    var variant = "poster"          // poster / ticket / block
    var ratio = "story"             // story / post
    var showSplits = true
    var photo: UIImage?
    var placeholder = false
    /// Text color: Black (Poster 전체 · Ticket 사진 위 워드마크·닉네임). Block 은 무시
    var textBlack = false
    /// Black & white photo
    var mono = true
    /// Dark gradient (끄면 Poster 사진이 화면 전체 + 스플릿 표 뒤에 흐린 유리판)
    var gradient = true
    /// "" 이면 닉네임 숨김 (@ 없이 넘김)
    var nick = ""

    private var post: Bool { ratio == "post" }
    private var h: CGFloat { post ? 450 : 640 }
    private var hasNick: Bool { !nick.isEmpty }
    private var nickText: String { "@" + nick }

    // 글자색 (시안 tc / acc / tcLine / pillBg)
    private var tc: Color { textBlack ? Color.black : Color.white }
    private var acc: Color { textBlack ? Color.black : C.accent }
    private var tcLine: Color { textBlack ? Color.black.opacity(0.18) : Color.white.opacity(0.16) }
    private var pillBg: Color { textBlack ? Color.white.opacity(0.55) : Color.white.opacity(0.07) }

    private var cardBg: Color { (textBlack && variant == "poster") ? Color.white : Color.black }

    var body: some View {
        ZStack(alignment: .topLeading) {
            cardBg
            switch variant {
            case "ticket": ticket
            case "block": block
            default: poster
            }
        }
        .frame(width: 360, height: h)
        .clipped()
        .foregroundStyle(.white)
        .environment(\.colorScheme, .dark)
    }

    // MARK: 공통

    /// SPLITS8 워드마크 20, 자간 −0.03em. 검은 글자 모드면 전체 검정 (wordmark-black)
    private func mark(black: Bool, shadow: Bool = false) -> some View {
        Wordmark(size: 20, eightColor: black ? Color.black : C.accent,
                 color: black ? Color.black : Color.white, tracking: -0.03)
            .shadow(color: shadow ? Color.black.opacity(0.5) : Color.clear, radius: 3, y: 1)
    }

    /// 노란 빛 radial-gradient(rx% ry% at cx% cy%, rgba(255,230,0,a), transparent 70%)
    private func glow(_ a: Double, rx: CGFloat, ry: CGFloat, cx: CGFloat, cy: CGFloat) -> some View {
        AmbientLayer(a: Ambient(hex: 0xFFE600, alpha: a, rx: rx, ry: ry, cx: cx, cy: cy))
    }

    /// 반투명 유리 (rgba 255 0.07 + inset 1px rgba 255 0.10)
    private static let glass = Color.white.opacity(0.07)
    private static let glassRing = Color.white.opacity(0.10)

    @ViewBuilder private func photoView() -> some View {
        if let photo {
            Image(uiImage: photo).resizable().scaledToFill()
        } else {
            ZStack {
                Color(hex: 0x0B0B0B)
                if placeholder {
                    VStack(spacing: 6) {
                        Image(systemName: "photo").font(F.t(24))
                        Text("Tap to choose a photo").font(F.t(13, .medium))
                    }
                    .foregroundStyle(C.text2)
                }
            }
        }
    }

    /// Black & white photo: grayscale(1) contrast(1.05) · 아니면 원본
    @ViewBuilder private func filteredPhoto() -> some View {
        if mono {
            photoView().grayscale(1).contrast(1.05)
        } else {
            photoView()
        }
    }

    /// 큰 시간 (line-height 0.95, 한 줄)
    private func big(_ s: String, _ size: CGFloat, track: CGFloat, color: Color = .white) -> some View {
        Text(s).font(F.num(size, .semibold)).tracking(track * size)
            .foregroundStyle(color)
            .lineLimit(1).minimumScaleFactor(0.5)
            .frame(height: size * 0.95)
    }

    /// 8 / 600, 자간 0.12em
    private func tinyLabel(_ s: String, color: Color) -> some View {
        Text(s).font(F.t(8, .semibold)).tracking(0.12 * 8)
            .foregroundStyle(color).lineLimit(1)
    }

    /// ★ PB 알약 (22 높이, 둥근 알약, 11 / 600, 별 10)
    private func pbPill(fill: Color, ring: Color, fg: Color) -> some View {
        HStack(spacing: 3) {
            Image(systemName: "star.fill").font(F.t(9, .semibold))
            Text("PB").font(F.t(11, .semibold))
        }
        .foregroundStyle(fg)
        .padding(.horizontal, 8)
        .frame(height: 22)
        .background(fill, in: Capsule())
        .overlay(Capsule().strokeBorder(ring, lineWidth: 1))
        .fixedSize()
    }

    /// Ticket · Block 용 노란 PB (fill 0.14, 링 0.5)
    private var yellowPB: some View {
        pbPill(fill: C.accent.opacity(0.14), ring: C.accent.opacity(0.5), fg: C.accent)
    }

    // MARK: Poster

    private static let cardSpace = "shareCard"

    /// 검은 글자 = 흰 스크림, 흰 글자 = 검은 스크림
    private var posterScrim: [Gradient.Stop] {
        let c: Color = textBlack ? Color.white : Color.black
        let top: Double = textBlack ? 0.45 : 0.5
        if post {
            return [.init(color: c.opacity(top), location: 0), .init(color: c.opacity(0), location: 0.18),
                    .init(color: c.opacity(0), location: 0.26), .init(color: c.opacity(0.92), location: 0.46),
                    .init(color: c, location: 0.58)]
        }
        return [.init(color: c.opacity(top), location: 0), .init(color: c.opacity(0), location: 0.20),
                .init(color: c.opacity(0), location: 0.34), .init(color: c.opacity(0.9), location: 0.60),
                .init(color: c, location: 0.72)]
    }

    private var posterPhotoH: CGFloat {
        if !gradient { return h }
        return h * (post ? 0.52 : 0.64)
    }

    private var poster: some View {
        let glowA: Double = textBlack ? 0.45 : 0.30
        let glowB: Double = textBlack ? 0.22 : 0.12
        return ZStack(alignment: .topLeading) {
            filteredPhoto()
                .frame(width: 360, height: posterPhotoH).clipped()
            if gradient {
                LinearGradient(stops: posterScrim, startPoint: .top, endPoint: .bottom)
                    .allowsHitTesting(false)
            }
            glow(glowA, rx: 0.9, ry: 0.45, cx: 0.85, cy: 1.0)
            glow(glowB, rx: 0.7, ry: 0.35, cx: 0, cy: 0.6)
            posterContent
                .padding(.top, 22).padding(.horizontal, 22).padding(.bottom, 24)
                .frame(width: 360, height: h, alignment: .topLeading)
        }
        .frame(width: 360, height: h)
        .coordinateSpace(NamedCoordinateSpace.named(ShareCard.cardSpace))
    }

    private var posterHeader: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 3) {
                mark(black: textBlack)
                if hasNick {
                    Text(nickText).font(F.t(12, .semibold)).foregroundStyle(tc).lineLimit(1)
                }
            }
            Spacer(minLength: 10)
            HStack(spacing: 6) {
                if d.pb {
                    pbPill(fill: pillBg, ring: tcLine, fg: acc)
                }
                Text(d.badge).font(F.t(11, .semibold)).foregroundStyle(acc).lineLimit(1)
                    .padding(.vertical, 5).padding(.horizontal, 10)
                    .background(pillBg, in: Capsule())
                    .overlay(Capsule().strokeBorder(tcLine, lineWidth: 1))
            }
        }
    }

    private var posterContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            posterHeader
            Spacer(minLength: 0)
            Text("\(d.place) · \(d.date)").font(F.t(13, .medium))
                .foregroundStyle(tc).lineLimit(1)
            if !d.partner.isEmpty {
                Text(d.partnerText).font(F.t(12, .medium))
                    .foregroundStyle(tc.opacity(0.75)).lineLimit(1).padding(.top, 2)
            }
            big(d.total, post ? 64 : 76, track: -0.045, color: tc).padding(.top, 6)
            HStack(alignment: .top, spacing: 12) {
                posterStat("AVG HR", d.avgHR)
                posterStat("ROXZONE", d.rox)
                posterStat("KCAL", d.kcal)
            }
            .padding(.top, 14)
            if showSplits && !d.pairs.isEmpty {
                posterTableBox.padding(.top, 16)
            }
        }
    }

    private func posterStat(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            tinyLabel(label, color: tc)
            Text(value).font(F.num(18, .semibold)).tracking(-0.01 * 18)
                .foregroundStyle(tc).lineLimit(1).minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Dark gradient 끄면: 흐린 유리판 (padding 6 12 4, radius 16)
    @ViewBuilder private var posterTableBox: some View {
        if gradient {
            posterTable
        } else {
            let shape = RoundedRectangle(cornerRadius: 16, style: .continuous)
            posterTable
                .padding(.top, 6).padding(.horizontal, 12).padding(.bottom, 4)
                .background { panelBackdrop }
                .clipShape(shape)
                .overlay(shape.strokeBorder(panelRing, lineWidth: 1))
        }
    }

    private var panelTint: Color { textBlack ? Color.white.opacity(0.62) : Color.black.opacity(0.48) }
    private var panelRing: Color { textBlack ? Color.black.opacity(0.08) : Color.white.opacity(0.14) }

    /// backdrop-filter: blur(18px) saturate(140%) — ImageRenderer 에서도 보이도록
    /// 같은 사진을 흐리게 해서 판 위치만큼 옮겨 깔고, 그 위에 색을 덮음
    private var panelBackdrop: some View {
        GeometryReader { g in
            let f: CGRect = g.frame(in: CoordinateSpace.named(ShareCard.cardSpace))
            ZStack(alignment: .topLeading) {
                blurredPhoto
                    .frame(width: 360, height: h)
                    .offset(x: -f.minX, y: -f.minY)
                panelTint
                    .frame(width: g.size.width, height: g.size.height)
            }
            .frame(width: g.size.width, height: g.size.height, alignment: .topLeading)
            .clipped()
        }
    }

    @ViewBuilder private var blurredPhoto: some View {
        if mono {
            filteredPhoto().frame(width: 360, height: h).clipped()
                .blur(radius: 18, opaque: true)
        } else {
            filteredPhoto().frame(width: 360, height: h).clipped()
                .saturation(1.4)
                .blur(radius: 18, opaque: true)
        }
    }

    // grid 20px | 1fr | 40px | 40px, column-gap 8 (아이콘 없음)
    private var posterTable: some View {
        let size: CGFloat = post ? 10 : 11
        let rowH: CGFloat = post ? 19 : 23
        return VStack(spacing: 0) {
            HStack(alignment: .bottom, spacing: 8) {
                Color.clear.frame(width: 20, height: 1)
                tinyLabel("STATION", color: tc).frame(maxWidth: .infinity, alignment: .leading)
                tinyLabel("RUN", color: tc).frame(width: 40, alignment: .trailing)
                tinyLabel("STN", color: tc).frame(width: 40, alignment: .trailing)
            }
            .padding(.bottom, 6)
            .overlay(alignment: .bottom) { Rectangle().fill(tcLine).frame(height: 1) }
            ForEach(d.pairs.indices, id: \.self) { i in
                posterRow(d.pairs[i], size: size, last: i == d.pairs.count - 1)
                    .frame(height: rowH)
            }
        }
    }

    private func posterRow(_ p: ShareData.Pair, size: CGFloat, last: Bool) -> some View {
        let line: Color = textBlack ? Color.black.opacity(0.10) : Color.white.opacity(0.07)
        return HStack(spacing: 8) {
            Text(p.no).font(F.num(10, .semibold)).foregroundStyle(acc)
                .frame(width: 20, alignment: .leading)
            Text(p.sn).font(F.t(size, .medium)).foregroundStyle(tc).lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(p.rt).font(F.num(size, .medium)).foregroundStyle(tc).lineLimit(1)
                .frame(width: 40, alignment: .trailing)
            Text(p.st).font(F.num(size, .semibold)).foregroundStyle(tc).lineLimit(1)
                .frame(width: 40, alignment: .trailing)
        }
        .frame(maxHeight: .infinity)
        .overlay(alignment: .bottom) {
            if !last { Rectangle().fill(line).frame(height: 1) }
        }
    }

    // MARK: Ticket

    private var ticketTop: UnevenRoundedRectangle {
        UnevenRoundedRectangle(topLeadingRadius: 18, bottomLeadingRadius: 4, bottomTrailingRadius: 4,
                               topTrailingRadius: 18, style: .continuous)
    }
    private var ticketBottom: UnevenRoundedRectangle {
        UnevenRoundedRectangle(topLeadingRadius: 4, bottomLeadingRadius: 18, bottomTrailingRadius: 18,
                               topTrailingRadius: 4, style: .continuous)
    }

    private var ticket: some View {
        ZStack(alignment: .topLeading) {
            glow(0.22, rx: 0.9, ry: 0.4, cx: 0.5, cy: 1.0)
            VStack(spacing: 0) {
                photoView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity).clipped()
                    .overlay(alignment: .topLeading) { mark(black: textBlack, shadow: !textBlack).padding(14) }
                    .overlay(alignment: .topTrailing) { ticketNick }
                    .clipShape(ticketTop)
                ticketCut
                ticketPanel
            }
            .padding(16)
            .frame(width: 360, height: h)
        }
    }

    /// 사진 오른쪽 위 @닉네임 (right 14, top 18, 12 / 600)
    @ViewBuilder private var ticketNick: some View {
        if hasNick {
            Text(nickText).font(F.t(12, .semibold)).foregroundStyle(tc).lineLimit(1)
                .shadow(color: textBlack ? Color.clear : Color.black.opacity(0.5), radius: 3, y: 1)
                .padding(.top, 18).padding(.trailing, 14)
        }
    }

    /// 절취선 (16 높이, 양 끝 검은 원 16, 점선 rgba 255 0.18)
    private var ticketCut: some View {
        GeometryReader { g in
            ZStack(alignment: .topLeading) {
                Path { p in
                    p.move(to: CGPoint(x: 12, y: 7.5))
                    p.addLine(to: CGPoint(x: g.size.width - 12, y: 7.5))
                }
                .stroke(Color.white.opacity(0.18), style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
                Circle().fill(Color.black).frame(width: 16, height: 16).offset(x: -24)
                Circle().fill(Color.black).frame(width: 16, height: 16).offset(x: g.size.width + 8)
            }
        }
        .frame(height: 16)
    }

    private var ticketPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 8) {
                    Text("\(d.place) · \(d.divName)").lineLimit(1)
                    Spacer(minLength: 0)
                    HStack(spacing: 8) {
                        if d.pb { yellowPB }
                        Text(d.date).lineLimit(1).fixedSize()
                    }
                }
                if !d.partner.isEmpty {
                    Text(d.partnerText).lineLimit(1)
                }
            }
            .font(F.t(12, .medium)).foregroundStyle(C.text2)
            HStack(alignment: .bottom) {
                big(d.total, post ? 48 : 56, track: -0.04)
                Spacer(minLength: 8)
                VStack(alignment: .trailing, spacing: 3) {
                    Text(d.vsValue).foregroundStyle(C.accent)
                    Text("\(d.avgHR) BPM").foregroundStyle(C.text2)
                }
                .font(F.num(14, .semibold)).lineLimit(1).fixedSize()
            }
            if showSplits && !d.seq.isEmpty {
                ticketStrip
                HStack {
                    Text("RUN \(d.runTotal)")
                    Spacer(minLength: 4)
                    Text("STATIONS \(d.stationTotal)")
                    Spacer(minLength: 4)
                    Text("ROX \(d.rox)")
                }
                .font(F.num(8, .semibold)).tracking(0.1 * 8).foregroundStyle(C.text3).lineLimit(1)
            }
        }
        .padding(.top, 16).padding(.horizontal, 18).padding(.bottom, 18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            ZStack {
                ShareCard.glass
                glow(0.30, rx: 0.9, ry: 0.9, cx: 0.9, cy: 1.1)
            }
        }
        .clipShape(ticketBottom)
        .overlay(ticketBottom.strokeBorder(ShareCard.glassRing, lineWidth: 1))
    }

    /// 16구간 막대 (러닝 rgba 255 0.18, 스테이션 노랑, gap 2, 위 모서리 2)
    private var ticketStrip: some View {
        let mx = CGFloat(max(1, d.seq.map(\.t).max() ?? 1))
        let stripH: CGFloat = post ? 32 : 56
        return HStack(alignment: .bottom, spacing: 2) {
            ForEach(d.seq.indices, id: \.self) { i in
                let s = d.seq[i]
                UnevenRoundedRectangle(topLeadingRadius: 2, topTrailingRadius: 2)
                    .fill(s.run ? Color.white.opacity(0.18) : C.accent)
                    .frame(maxWidth: .infinity)
                    .frame(height: max(2, stripH * CGFloat(s.t) / mx))
            }
        }
        .frame(height: stripH, alignment: .bottom)
    }

    // MARK: Block (사진 없음 · 글자색 무시)

    private var block: some View {
        ZStack(alignment: .topLeading) {
            glow(0.34, rx: 0.9, ry: 0.55, cx: 0.85, cy: 0)
            glow(0.14, rx: 0.8, ry: 0.45, cx: 0, cy: 1.0)
            blockContent
                .padding(24)
                .frame(width: 360, height: h, alignment: .topLeading)
        }
    }

    private var blockHeader: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 0) {
                mark(black: false)
                HStack(spacing: 8) {
                    Text(d.badge).font(F.t(13, .semibold)).lineLimit(1)
                    if d.pb { yellowPB }
                }
                .padding(.top, 14)
                Text("\(d.place) · \(d.date)").font(F.t(13, .medium))
                    .foregroundStyle(Color.white.opacity(0.65)).lineLimit(1).padding(.top, 3)
                if !d.partner.isEmpty {
                    Text(d.partnerText).font(F.t(12, .medium))
                        .foregroundStyle(Color.white.opacity(0.65)).lineLimit(1).padding(.top, 2)
                }
            }
            Spacer(minLength: 0)
            if hasNick {
                Text(nickText).font(F.t(13, .semibold)).foregroundStyle(C.accent).lineLimit(1)
                    .padding(.top, 3)
            }
        }
    }

    private var blockContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            blockHeader
            Spacer(minLength: 0)
            big(d.total, post ? 56 : 76, track: -0.045)
            HStack(spacing: 6) {
                blockTile(d.vsWord, d.vsValue, color: C.accent)
                blockTile("AVG HR", d.avgHR, color: .white)
                blockTile("ROXZONE", d.rox, color: .white)
            }
            .padding(.top, 14)
            if showSplits && !d.pairs.isEmpty {
                blockTable.padding(.top, post ? 10 : 20)
            }
        }
    }

    private func blockTile(_ label: String, _ value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            tinyLabel(label, color: Color.white.opacity(0.55))
            Text(value).font(F.num(18, .semibold)).foregroundStyle(color).lineLimit(1).minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 10).padding(.horizontal, 12)
        .background(ShareCard.glass, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(ShareCard.glassRing, lineWidth: 1))
    }

    // grid 20px | 16px | 1fr | 40px | 44px, column-gap 8
    private var blockTable: some View {
        let rowH: CGFloat = post ? 18 : 34
        return VStack(spacing: 0) {
            HStack(spacing: 8) {
                Color.clear.frame(width: 20, height: 1)
                Color.clear.frame(width: 16, height: 1)
                tinyLabel("STATION", color: Color.white.opacity(0.5)).frame(maxWidth: .infinity, alignment: .leading)
                tinyLabel("RUN", color: Color.white.opacity(0.5)).frame(width: 40, alignment: .trailing)
                tinyLabel("STN", color: Color.white.opacity(0.5)).frame(width: 44, alignment: .trailing)
            }
            .frame(height: 22)
            .overlay(alignment: .bottom) { Rectangle().fill(Color.white.opacity(0.10)).frame(height: 1) }
            ForEach(d.pairs.indices, id: \.self) { i in
                blockRow(d.pairs[i], last: i == d.pairs.count - 1)
                    .frame(height: rowH)
            }
        }
        .padding(.vertical, 4).padding(.horizontal, 12)
        .background(ShareCard.glass, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(ShareCard.glassRing, lineWidth: 1))
    }

    private func blockRow(_ p: ShareData.Pair, last: Bool) -> some View {
        let size: CGFloat = post ? 11 : 14
        let num: CGFloat = post ? 13 : 17
        return HStack(spacing: 8) {
            Text(p.no).font(F.num(11, .semibold)).foregroundStyle(C.accent)
                .frame(width: 20, alignment: .leading)
            Icon8(p.icon, 14, .white).opacity(0.9).frame(width: 16)
            Text(p.sn).font(F.t(size, .medium)).lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(p.rt).font(F.num(size, .medium)).foregroundStyle(Color.white.opacity(0.5)).lineLimit(1)
                .frame(width: 40, alignment: .trailing)
            Text(p.st).font(F.num(num, .semibold)).lineLimit(1).minimumScaleFactor(0.8)
                .frame(width: 44, alignment: .trailing)
        }
        .frame(maxHeight: .infinity)
        .overlay(alignment: .bottom) {
            if !last { Rectangle().fill(Color.white.opacity(0.07)).frame(height: 1) }
        }
    }
}

// MARK: - I7 공유 화면 (시안 isShare)

struct ShareView: View {
    let store = Store.shared
    let r = Router.shared
    @State private var ratio = "story"
    @State private var variant = "poster"
    @State private var splits = true
    @State private var textColor = "white"     // white / black
    @State private var mono = true             // Black & white photo
    @State private var gradient = true         // Dark gradient
    @State private var nickOn = true           // Nickname
    @State private var pick: PhotosPickerItem?
    @State private var photo: UIImage?
    @State private var saved = false

    private var data: ShareData { r.detail.map { ShareData($0, store: store) } ?? ShareData() }
    private var post: Bool { ratio == "post" }

    /// 가입한 사람만 닉네임 (없으면 토글 꺼짐 + 안내 문구)
    private var nickName: String {
        guard store.signedIn, let n = store.settings.nickname else { return "" }
        return n
    }
    private var canNick: Bool { !nickName.isEmpty }
    private var shownNick: String { (canNick && nickOn) ? nickName : "" }

    // 시안: flex column, gap 14, padding 0 16
    var body: some View {
        VStack(spacing: 14) {
            NavBar3(left: "Close", title: "Share", onLeft: { r.go(.detail) })
            preview
            Seg8(items: [("story", "Story 9:16"), ("post", "Post 4:5")], selected: ratio,
                 fontSize: 13, track: Color(hex: 0x141414), tracking: 0.04 * 13) { k in
                withAnimation(.easeInOut(duration: 0.2)) { ratio = k }
            }
            variantButtons
            optionsCard
            actionButtons
        }
        .padding(.horizontal, 16)
    }

    // 미리보기: Story 0.72 → 259×461, Post 0.86 → 310×387, radius 14, 바깥 1px #262626
    private var preview: some View {
        let scale: CGFloat = post ? 0.86 : 0.72
        let pw: CGFloat = post ? 310 : 259
        let ph: CGFloat = post ? 387 : 461
        return PhotosPicker(selection: $pick, matching: .images) {
            card(placeholder: true)
                .scaleEffect(scale, anchor: .topLeading)
                .frame(width: pw, height: ph, alignment: .topLeading)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .background(RoundedRectangle(cornerRadius: 15, style: .continuous).fill(Color(hex: 0x262626)).padding(-1))
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
        .accessibilityIdentifier("share.photo")
        .onChange(of: pick) { _, item in
            Task {
                if let item, let raw = try? await item.loadTransferable(type: Data.self), let img = UIImage(data: raw) {
                    photo = img
                }
            }
        }
    }

    // 3칸 (38 높이, radius 10, #111, 선택 1.5px 노랑 링 + 노랑 글자, 아니면 1px #1C1C1C + #AEAEB2)
    private var variantButtons: some View {
        let vs: [(String, String)] = [("poster", "Poster"), ("ticket", "Ticket"), ("block", "Block")]
        return HStack(spacing: 8) {
            ForEach(vs.indices, id: \.self) { i in
                variantButton(vs[i].0, vs[i].1)
            }
        }
    }

    private func variantButton(_ k: String, _ l: String) -> some View {
        let on = variant == k
        let shape = RoundedRectangle(cornerRadius: 10, style: .continuous)
        return Button { variant = k } label: {
            Text(l.l10n).font(F.t(13, .semibold)).foregroundStyle(on ? C.accent : C.aeb)
                .frame(maxWidth: .infinity).frame(height: 38)
                .background(Color(hex: 0x111111), in: shape)
                .overlay(shape.strokeBorder(on ? C.accent : Color(hex: 0x1C1C1C), lineWidth: on ? 1.5 : 1))
                .contentShape(shape)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(l)
    }

    // 옵션 카드 (radius 14, 줄 최소 48 높이, padding 0 16, 15pt, 줄 사이 1px rgba 255 0.08, 토글 50×30)
    private var optionsCard: some View {
        VStack(spacing: 0) {
            optionRow(last: false) {
                Text("Text color").font(F.t(15))
            } trailing: {
                textColorSeg
            }
            optionRow(last: false) {
                Text("Split times").font(F.t(15))
            } trailing: {
                Toggle8(on: $splits, w: 50, h: 30).accessibilityIdentifier("share.splits")
            }
            optionRow(last: false) {
                Text("Black & white photo").font(F.t(15))
            } trailing: {
                Toggle8(on: $mono, w: 50, h: 30).accessibilityIdentifier("share.mono")
            }
            optionRow(last: false) {
                Text("Dark gradient").font(F.t(15))
            } trailing: {
                Toggle8(on: $gradient, w: 50, h: 30).accessibilityIdentifier("share.gradient")
            }
            optionRow(last: true) {
                nickLabel
            } trailing: {
                nickToggle
            }
        }
        .card8(14)
    }

    private func optionRow<A: View, B: View>(last: Bool, @ViewBuilder leading: () -> A,
                                             @ViewBuilder trailing: () -> B) -> some View {
        HStack(spacing: 12) {
            leading()
            Spacer(minLength: 0)
            trailing()
        }
        .padding(.horizontal, 16).padding(.vertical, 8)
        .frame(minHeight: 48)
        .rowLine(!last)
    }

    // White / Black (트랙 #141414 radius 9 padding 2, 버튼 64×28 radius 7, 13/600 흰 글자, 선택 rgba 255 0.16)
    private var textColorSeg: some View {
        let items: [(String, String)] = [("white", "White"), ("black", "Black")]
        return HStack(spacing: 0) {
            ForEach(items.indices, id: \.self) { i in
                textColorButton(items[i].0, items[i].1)
            }
        }
        .padding(2)
        .background(Color(hex: 0x141414), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
    }

    private func textColorButton(_ k: String, _ l: String) -> some View {
        let on = textColor == k
        let shape = RoundedRectangle(cornerRadius: 7, style: .continuous)
        return Button { textColor = k } label: {
            Text(l.l10n).font(F.t(13, .semibold)).foregroundStyle(Color.white)
                .frame(width: 64, height: 28)
                .background(on ? Color.white.opacity(0.16) : Color.clear, in: shape)
                .contentShape(shape)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("share.text.\(k)")
    }

    private var nickLabel: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Nickname").font(F.t(15))
            if !canNick {
                Text("Sign up to add your nickname").font(F.t(12)).foregroundStyle(C.text2)
            }
        }
    }

    @ViewBuilder private var nickToggle: some View {
        if canNick {
            Toggle8(on: $nickOn, w: 50, h: 30).accessibilityIdentifier("share.nick")
        } else {
            Toggle8(on: .constant(false), w: 50, h: 30)
                .allowsHitTesting(false)
                .accessibilityIdentifier("share.nick")
        }
    }

    // Share (노란 유리) · Save image (#1A1A1A): 50 높이, radius 14, 15/600, gap 10
    private var actionButtons: some View {
        HStack(spacing: 10) {
            Button { share() } label: {
                Text("Share").font(F.t(15, .semibold)).foregroundStyle(.black)
                    .frame(maxWidth: .infinity).frame(height: 50)
                    .yellowFill(14)
            }
            .buttonStyle(Press())
            .accessibilityIdentifier("share.instagram")
            Button { save() } label: {
                Text(saved ? "Saved" : "Save image").font(F.t(15, .semibold)).foregroundStyle(.white)
                    .frame(maxWidth: .infinity).frame(height: 50)
                    .background(C.btn1A, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(Press())
            .accessibilityIdentifier("share.save")
        }
    }

    private func card(placeholder: Bool) -> ShareCard {
        ShareCard(d: data, variant: variant, ratio: ratio, showSplits: splits, photo: photo,
                  placeholder: placeholder, textBlack: textColor == "black", mono: mono,
                  gradient: gradient, nick: shownNick)
    }

    /// 360pt 너비 시안을 3배로 → 1080 너비
    @MainActor private func image() -> UIImage? {
        let rr = ImageRenderer(content: card(placeholder: false))
        rr.scale = 3
        return rr.uiImage
    }

    /// Share: Instagram 스토리로 바로 보내기 (앱 ID 있을 때) · 아니면 iOS 공유 창
    private func share() {
        guard let img = image() else { return }
        if !Config.facebookAppID.isEmpty, let url = URL(string: "instagram-stories://share?source_application=\(Config.facebookAppID)"),
           UIApplication.shared.canOpenURL(url), let png = img.pngData() {
            UIPasteboard.general.setItems([["com.instagram.sharedSticker.backgroundImage": png,
                                            "com.instagram.sharedSticker.appID": Config.facebookAppID]],
                                          options: [.expirationDate: Date().addingTimeInterval(300)])
            UIApplication.shared.open(url)
        } else {
            ShareSheet.present([img])
        }
    }

    private func save() {
        guard let img = image() else { return }
        UIImageWriteToSavedPhotosAlbum(img, nil, nil, nil)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        saved = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) { saved = false }
    }
}

/// iOS 공유 시트
enum ShareSheet {
    static func present(_ items: [Any]) {
        guard let scene = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).first,
              var top = scene.keyWindow?.rootViewController ?? scene.windows.first?.rootViewController
        else { return }
        while let p = top.presentedViewController { top = p }
        let vc = UIActivityViewController(activityItems: items, applicationActivities: nil)
        vc.popoverPresentationController?.sourceView = top.view
        top.present(vc, animated: true)
    }
}
