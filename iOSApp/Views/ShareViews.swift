import SwiftUI
import PhotosUI
import Photos

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
    /// Smoke (Poster 만): 0 = 끔 · 0.6 = 옅게 · 1 = 짙게. 켜면 사진이 전체에 깔리고, 그라데이션·유리판 대신 연기가 글자 바탕이 됨
    var smoke: Double = 0
    /// Poster 글자 덩어리 자리 (끌어서 옮김)
    var layout = PosterLayout()
    /// 미리보기에서 끄는 중인 덩어리와 옮긴 거리
    var dragKey: String? = nil
    var dragOffset: CGSize = .zero

    private var smokeOn: Bool { smoke > 0 }
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

    /// 그 자리(0 위 · 1 가운데 · 2 아래)에 글자 덩어리가 있는지
    private func occupied(_ v: Int) -> Bool {
        layout.head == v || layout.time == v || (showSplits && !d.pairs.isEmpty && layout.table == v)
    }

    /// 검은 글자 = 흰 스크림, 흰 글자 = 검은 스크림. 글자가 있는 자리만 어둡게(밝게) 함.
    /// 기본 배치(위: 로고, 아래: 시간·표)에서는 예전과 같은 모양
    private var posterScrim: [Gradient.Stop] {
        let c: Color = textBlack ? Color.white : Color.black
        let top: Double = occupied(0) ? (textBlack ? 0.45 : 0.5) : 0
        let mid: Bool = occupied(1)
        let bot: Bool = occupied(2)
        var st: [Gradient.Stop] = [.init(color: c.opacity(top), location: 0)]
        if mid {
            st.append(.init(color: c.opacity(top > 0 ? 0.25 : 0), location: 0.18))
            st.append(.init(color: c.opacity(0.62), location: 0.32))
            st.append(.init(color: c.opacity(0.62), location: 0.62))
        } else {
            st.append(.init(color: c.opacity(0), location: post ? 0.18 : 0.20))
            st.append(.init(color: c.opacity(0), location: post ? 0.26 : 0.34))
        }
        if bot {
            if mid {
                st.append(.init(color: c.opacity(0.9), location: 0.68))
                st.append(.init(color: c, location: 0.76))
            } else {
                st.append(.init(color: c.opacity(post ? 0.92 : 0.9), location: post ? 0.46 : 0.60))
                st.append(.init(color: c, location: post ? 0.58 : 0.72))
            }
        } else {
            st.append(.init(color: c.opacity(0), location: mid ? 0.80 : 0.90))
        }
        return st
    }

    /// 그라데이션일 때 아래에 글자가 있으면 사진은 위쪽만 (아래는 단색), 아니면 사진이 전체
    private var posterPhotoH: CGFloat {
        if smokeOn || !gradient || !occupied(2) { return h }
        if occupied(1) { return h * 0.72 }
        return h * (post ? 0.52 : 0.64)
    }

    private var poster: some View {
        let glowA: Double = textBlack ? 0.45 : 0.30
        let glowB: Double = textBlack ? 0.22 : 0.12
        return ZStack(alignment: .topLeading) {
            posterPhoto
                .frame(width: 360, height: posterPhotoH).clipped()
            if smokeOn {
                // 영화 느낌: 옅은 안개 결 + 가장자리 어둡게 + 필름 입자
                SmokeHaze(strength: smoke)
                    .frame(width: 360, height: h)
                    .allowsHitTesting(false)
                if !textBlack {
                    RadialGradient(stops: [.init(color: .black.opacity(0), location: 0.45),
                                           .init(color: .black.opacity(0.42 * smoke), location: 1)],
                                   center: .center, startRadius: 0, endRadius: h * 0.72)
                        .allowsHitTesting(false)
                }
                FilmGrain(amount: 0.05 * smoke)
                    .frame(width: 360, height: h)
                    .allowsHitTesting(false)
            } else {
                if gradient {
                    LinearGradient(stops: posterScrim, startPoint: .top, endPoint: .bottom)
                        .allowsHitTesting(false)
                }
                glow(glowA, rx: 0.9, ry: 0.45, cx: 0.85, cy: 1.0)
                glow(glowB, rx: 0.7, ry: 0.35, cx: 0, cy: 0.6)
            }
            posterContent
                .padding(.top, 22).padding(.horizontal, 22).padding(.bottom, 24)
                .frame(width: 360, height: h, alignment: .topLeading)
                // 연기는 글자 덩어리 뒤에 더 짙게 모임 (덩어리를 옮기면 따라감). 모든 글자보다 아래에 그림
                .backgroundPreferenceValue(PosterBlockAnchors.self) { anchors in
                    if smokeOn {
                        GeometryReader { g in
                            ForEach(anchors.keys.sorted(), id: \.self) { k in
                                if let a = anchors[k] {
                                    let r: CGRect = g[a]
                                    SmokePuff(dark: !textBlack, strength: smoke * (k == "head" ? 0.55 : 1),
                                              bias: k == "time" ? layout.timeAlign : 1, seed: UInt64(k.count) &* 977 &+ 13)
                                        .frame(width: r.width + 76, height: r.height + 64)
                                        .position(x: r.midX, y: r.midY)
                                }
                            }
                        }
                        .allowsHitTesting(false)
                    }
                }
        }
        .frame(width: 360, height: h)
        .coordinateSpace(NamedCoordinateSpace.named(ShareCard.cardSpace))
    }

    /// 연기를 켜면 사진을 영화처럼 조금 눌러 줌 (채도 ↓ · 대비 ↑)
    @ViewBuilder private var posterPhoto: some View {
        if smokeOn {
            filteredPhoto().saturation(mono ? 1 : 0.86).contrast(1.08)
        } else {
            filteredPhoto()
        }
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

    /// 위 · 가운데 · 아래 세 자리에 덩어리를 나눠 놓음. 같은 자리에 여러 개면 로고 → 시간 → 표 순서
    private var posterContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            slot(0)
            Spacer(minLength: 10)
            slot(1)
            Spacer(minLength: 10)
            slot(2)
        }
    }

    @ViewBuilder private func slot(_ v: Int) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            if layout.head == v { posterBlock("head") { posterHeader } }
            if layout.time == v { posterBlock("time") { posterTime } }
            if showSplits && !d.pairs.isEmpty && layout.table == v { posterBlock("table") { posterTableBox } }
        }
    }

    /// 옮길 수 있는 덩어리: 자리(앵커)를 알리고, 끄는 동안은 손가락을 따라 움직임. 연기 위에서는 글자에 옅은 그림자
    private func posterBlock<V: View>(_ key: String, @ViewBuilder _ content: () -> V) -> some View {
        let lifted: Bool = dragKey == key
        return content()
            .shadow(color: smokeOn ? (textBlack ? Color.white : Color.black).opacity(0.5) : Color.clear, radius: 3, y: 1)
            .anchorPreference(key: PosterBlockAnchors.self, value: .bounds) { [key: $0] }
            .scaleEffect(lifted ? 1.03 : 1)
            .offset(lifted ? dragOffset : .zero)
            .opacity(lifted ? 0.85 : 1)
            .zIndex(lifted ? 1 : 0)
    }

    /// 장소·날짜 / 큰 시간 / 숫자 3개. 왼쪽 · 가운데 · 오른쪽 정렬
    private var posterTime: some View {
        let i: Int = max(0, min(2, layout.timeAlign))
        let ha: HorizontalAlignment = [HorizontalAlignment.leading, .center, .trailing][i]
        let fa: Alignment = [Alignment.leading, .center, .trailing][i]
        return VStack(alignment: ha, spacing: 0) {
            Text("\(d.place) · \(d.date)").font(F.t(13, .medium))
                .foregroundStyle(tc).lineLimit(1)
            if !d.partner.isEmpty {
                Text(d.partnerText).font(F.t(12, .medium))
                    .foregroundStyle(tc.opacity(0.75)).lineLimit(1).padding(.top, 2)
            }
            big(d.total, post ? 64 : 76, track: -0.045, color: tc).padding(.top, 6)
            HStack(alignment: .top, spacing: 12) {
                posterStat("AVG HR", d.avgHR, ha, fa)
                posterStat("ROXZONE", d.rox, ha, fa)
                posterStat("KCAL", d.kcal, ha, fa)
            }
            .padding(.top, 14)
        }
        .frame(maxWidth: .infinity, alignment: fa)
    }

    private func posterStat(_ label: String, _ value: String, _ ha: HorizontalAlignment = .leading,
                            _ fa: Alignment = .leading) -> some View {
        VStack(alignment: ha, spacing: 0) {
            tinyLabel(label, color: tc)
            Text(value).font(F.num(18, .semibold)).tracking(-0.01 * 18)
                .foregroundStyle(tc).lineLimit(1).minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: fa)
    }

    /// 그라데이션 위(아래 자리)나 연기 위에서는 표만, 사진 바로 위에서는 흐린 유리판 (padding 6 12 4, radius 16)
    @ViewBuilder private var posterTableBox: some View {
        if smokeOn || (gradient && layout.table == 2) {
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

// MARK: - Poster 글자 자리 · 연기

/// Poster 의 글자 덩어리 자리. 미리보기에서 끌어서 옮기면 가장 가까운 자리에 붙음
struct PosterLayout: Equatable {
    /// 로고 · 닉네임 줄: 0 위 / 2 아래
    var head = 0
    /// 장소 · 큰 시간 · 숫자: 0 위 / 1 가운데 / 2 아래
    var time = 2
    /// 그 덩어리의 정렬: 0 왼쪽 / 1 가운데 / 2 오른쪽
    var timeAlign = 0
    /// 구간 표: 0 위 / 1 가운데 / 2 아래
    var table = 2

    static let standard = PosterLayout()
}

/// 덩어리(head · time · table)의 자리
struct PosterBlockAnchors: PreferenceKey {
    static var defaultValue: [String: Anchor<CGRect>] = [:]
    static func reduce(value: inout [String: Anchor<CGRect>], nextValue: () -> [String: Anchor<CGRect>]) {
        value.merge(nextValue()) { $1 }
    }
}

/// 항상 같은 모양이 나오는 난수 (미리보기와 저장한 그림이 같아야 함)
struct SeededRandom: RandomNumberGenerator {
    private var state: UInt64
    init(seed: UInt64) { state = seed == 0 ? 0x9E3779B97F4A7C15 : seed }
    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z: UInt64 = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
    /// 0…1
    mutating func unit() -> Double { Double(next() >> 11) / Double(1 << 53) }
    /// 가운데에 몰린 0…1
    mutating func bell() -> Double { (unit() + unit() + unit()) / 3 }
}

/// 글자 덩어리 뒤에 모이는 연기. dark = 어두운 연기(흰 글자용) / 밝은 연기(검은 글자용).
/// bias = 연기가 몰리는 쪽 (0 왼쪽 · 1 가운데 · 2 오른쪽)
struct SmokePuff: View {
    let dark: Bool
    let strength: Double
    var bias: Int = 1
    var seed: UInt64 = 1

    var body: some View {
        Canvas { ctx, size in
            var rng = SeededRandom(seed: seed)
            let color: Color = dark ? Color.black : Color.white
            let w: Double = Double(size.width), h: Double = Double(size.height)
            let cx: Double = [0.36, 0.5, 0.64][max(0, min(2, bias))]
            let count: Int = 26 + Int(w * h / 5200)
            for _ in 0..<count {
                let x: Double = (cx + (rng.bell() - 0.5) * 1.5) * w
                let y: Double = (0.5 + (rng.bell() - 0.5) * 1.3) * h
                let r: Double = max(26, min(150, h * (0.32 + rng.unit() * 0.5)))
                let rx: Double = r * (1.1 + rng.unit() * 0.9)
                let a: Double = (0.10 + rng.unit() * 0.13) * strength
                let rect = CGRect(x: x - rx, y: y - r, width: rx * 2, height: r * 2)
                ctx.drawLayer { layer in
                    // 가로로 퍼진 뭉치: 원 모양 그라데이션을 옆으로 늘림
                    layer.translateBy(x: rect.midX, y: rect.midY)
                    layer.scaleBy(x: rx / r, y: 1)
                    let shade = GraphicsContext.Shading.radialGradient(
                        Gradient(stops: [.init(color: color.opacity(a), location: 0),
                                         .init(color: color.opacity(a * 0.55), location: 0.5),
                                         .init(color: color.opacity(0), location: 1)]),
                        center: .zero, startRadius: 0, endRadius: r)
                    layer.fill(Path(ellipseIn: CGRect(x: -r, y: -r, width: r * 2, height: r * 2)), with: shade)
                }
            }
        }
        .blur(radius: 9)
        // 가장자리는 저절로 사라지게 (네모난 끝이 보이지 않게)
        .mask {
            RoundedRectangle(cornerRadius: 46, style: .continuous)
                .padding(20)
                .blur(radius: 16)
        }
    }
}

/// 화면 전체에 깔리는 옅은 안개 결 (밝은 회색). 사진에 깊이를 주는 용도라 글자 바탕보다 훨씬 옅음
struct SmokeHaze: View {
    let strength: Double

    var body: some View {
        Canvas { ctx, size in
            var rng = SeededRandom(seed: 41)
            let w: Double = Double(size.width), h: Double = Double(size.height)
            for _ in 0..<16 {
                let x: Double = rng.unit() * w
                let y: Double = rng.unit() * h
                let r: Double = 70 + rng.unit() * 130
                let stretch: Double = 1.6 + rng.unit() * 1.6
                let a: Double = (0.035 + rng.unit() * 0.06) * strength
                ctx.drawLayer { layer in
                    layer.translateBy(x: x, y: y)
                    layer.scaleBy(x: stretch, y: 1)
                    let shade = GraphicsContext.Shading.radialGradient(
                        Gradient(stops: [.init(color: Color(white: 0.92).opacity(a), location: 0),
                                         .init(color: Color(white: 0.92).opacity(0), location: 1)]),
                        center: .zero, startRadius: 0, endRadius: r)
                    layer.fill(Path(ellipseIn: CGRect(x: -r, y: -r, width: r * 2, height: r * 2)), with: shade)
                }
            }
        }
        .blur(radius: 12)
    }
}

/// 필름 입자 (아주 옅은 흰·검은 점)
struct FilmGrain: View {
    let amount: Double

    var body: some View {
        Canvas { ctx, size in
            var rng = SeededRandom(seed: 7)
            let w: Double = Double(size.width), h: Double = Double(size.height)
            let n: Int = Int(w * h / 22)
            for i in 0..<n {
                let x: Double = rng.unit() * w
                let y: Double = rng.unit() * h
                let a: Double = amount * (0.4 + rng.unit() * 0.9)
                let c: Color = i % 2 == 0 ? Color.white : Color.black
                ctx.fill(Path(CGRect(x: x, y: y, width: 0.9, height: 0.9)), with: .color(c.opacity(a)))
            }
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
    @State private var mapOn = false           // 실외 러닝: 경로 지도를 배경으로
    @State private var saveFail: String? = nil  // 저장 실패 안내
    @State private var smoke = "off"           // Smoke: off / light / strong (Poster)
    @State private var layout = PosterLayout() // Poster 글자 자리
    // 미리보기에서 글자 덩어리 끌기
    @State private var blockRects: [String: CGRect] = [:]
    @State private var dragKey: String? = nil
    @State private var dragStart: CGRect = .zero
    @State private var dragOffset: CGSize = .zero

    private var smokeValue: Double { smoke == "strong" ? 1 : (smoke == "light" ? 0.6 : 0) }

    /// 화면 확인용 예시 사진 (--sharephoto): 밝고 복잡한 체육관 느낌의 그림. 연기·그라데이션 위 글자가 읽히는지 보려고
    static func demoPhoto() -> UIImage {
        let size = CGSize(width: 720, height: 1280)
        let fmt = UIGraphicsImageRendererFormat(); fmt.scale = 1
        return UIGraphicsImageRenderer(size: size, format: fmt).image { c in
            let g = c.cgContext
            let colors = [UIColor(white: 0.86, alpha: 1).cgColor, UIColor(red: 0.55, green: 0.60, blue: 0.66, alpha: 1).cgColor,
                          UIColor(white: 0.30, alpha: 1).cgColor] as CFArray
            if let grad = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 0.5, 1]) {
                g.drawLinearGradient(grad, start: .zero, end: CGPoint(x: 0, y: size.height), options: [])
            }
            var rng = SeededRandom(seed: 99)
            // 천장 조명 줄 · 기둥 · 바닥 선 · 사람 그림자 같은 덩어리
            for i in 0..<9 {
                UIColor(white: 1, alpha: 0.85).setFill()
                g.fill(CGRect(x: 40 + Double(i) * 78, y: 60 + rng.unit() * 30, width: 44, height: 10))
            }
            for _ in 0..<26 {
                let w: Double = 30 + rng.unit() * 150, h: Double = 60 + rng.unit() * 360
                UIColor(hue: 0.05 + rng.unit() * 0.6, saturation: 0.25 + rng.unit() * 0.4,
                        brightness: 0.25 + rng.unit() * 0.7, alpha: 0.75).setFill()
                g.fill(CGRect(x: rng.unit() * size.width - 40, y: 160 + rng.unit() * 980, width: w, height: h))
            }
            UIColor(white: 0.08, alpha: 0.9).setFill()
            g.fillEllipse(in: CGRect(x: 250, y: 330, width: 130, height: 130))          // 머리
            g.fill(CGRect(x: 215, y: 450, width: 200, height: 420))                     // 몸
            for i in 0..<14 {
                UIColor(white: 1, alpha: 0.5).setFill()
                g.fill(CGRect(x: 0, y: 900 + Double(i) * 28, width: size.width, height: 3))
            }
        }
    }

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
            if variant == "poster" { moveHint }
            Seg8(items: [("story", "Story 9:16"), ("post", "Post 4:5")], selected: ratio,
                 fontSize: 13, track: Color(hex: 0x141414), tracking: 0.04 * 13) { k in
                withAnimation(.easeInOut(duration: 0.2)) { ratio = k }
            }
            variantButtons
            optionsCard
            actionButtons
        }
        .padding(.horizontal, 16)
        .onAppear {
            if photo == nil && CommandLine.arguments.contains("--sharephoto") { photo = Self.demoPhoto(); mono = false }
        }
        .alert("Couldn't save", isPresented: Binding(get: { saveFail != nil }, set: { if !$0 { saveFail = nil } })) {
            Button("Open Settings") {
                if let u = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(u) }
            }
            Button("OK", role: .cancel) {}
        } message: {
            Text(saveFail ?? "")
        }
    }

    // 미리보기: Story 0.72 → 259×461, Post 0.86 → 310×387, radius 14, 바깥 1px #262626
    private var preview: some View {
        let scale: CGFloat = post ? 0.86 : 0.72
        let pw: CGFloat = post ? 310 : 259
        let ph: CGFloat = post ? 387 : 461
        return PhotosPicker(selection: $pick, matching: .images) {
            card(placeholder: true)
                // 덩어리 자리를 카드 좌표로 받아 둠 (끌기 시작할 때 어느 덩어리인지 찾음)
                .overlayPreferenceValue(PosterBlockAnchors.self) { anchors in
                    GeometryReader { g in
                        let rects: [String: CGRect] = anchors.mapValues { g[$0] }
                        Color.clear
                            .onAppear { if dragKey == nil { blockRects = rects } }
                            .onChange(of: rects) { _, v in if dragKey == nil { blockRects = v } }
                    }
                    .allowsHitTesting(false)
                }
                .scaleEffect(scale, anchor: .topLeading)
                .frame(width: pw, height: ph, alignment: .topLeading)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .background(RoundedRectangle(cornerRadius: 15, style: .continuous).fill(Color(hex: 0x262626)).padding(-1))
                .contentShape(Rectangle())
                // Poster: 글자 덩어리를 꾹 눌러 끌어서 옮김 (그냥 누르면 사진 고르기 · 쓸면 화면 넘기기)
                .highPriorityGesture(blockDrag(scale: scale), including: variant == "poster" ? .all : .subviews)
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
        .accessibilityIdentifier("share.photo")
        .onChange(of: mapOn) { _, on in
            if on, let rt = routeOf {
                Task {
                    let size = CGSize(width: 1080, height: post ? 1350 : 1920)
                    if let img = await RouteSnapshot.make(rt, size: size) {
                        photo = img
                        mono = false
                    }
                }
            } else if !on {
                photo = nil
            }
        }
        .onChange(of: pick) { _, item in
            Task {
                if let item, let raw = try? await item.loadTransferable(type: Data.self), let img = UIImage(data: raw) {
                    photo = img
                }
            }
        }
    }

    // MARK: 글자 덩어리 끌기 (Poster)

    /// 미리보기 위에서 꾹 누른 뒤 끌기: 손가락 아래의 덩어리(시간 · 표 · 로고)를 잡아 옮기고, 놓으면 가장 가까운 자리에 붙음.
    /// 그냥 쓸어 넘기면 화면이 내려가야 하므로 (미리보기가 화면의 대부분을 차지함) 꾹 눌러야만 잡힘
    private func blockDrag(scale: CGFloat) -> some Gesture {
        LongPressGesture(minimumDuration: 0.25, maximumDistance: 12)
            .sequenced(before: DragGesture(minimumDistance: 0))
            .onChanged { value in
                guard case .second(true, let drag?) = value else { return }
                if dragKey == nil {
                    let p = CGPoint(x: drag.startLocation.x / scale, y: drag.startLocation.y / scale)
                    // 겹치면 작은 덩어리부터 (표 위에 걸친 시간 덩어리를 잡기 쉽게)
                    let hits = blockRects.filter { $0.value.insetBy(dx: -6, dy: -8).contains(p) }
                    guard let k = hits.min(by: { $0.value.height < $1.value.height })?.key else { return }
                    dragKey = k
                    dragStart = blockRects[k] ?? .zero
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                }
                dragOffset = CGSize(width: drag.translation.width / scale, height: drag.translation.height / scale)
            }
            .onEnded { value in
                guard let k = dragKey else { return }
                guard case .second(true, let drag?) = value else {
                    withAnimation(.snappy(duration: 0.28)) { dragOffset = .zero; dragKey = nil }
                    return
                }
                let off = CGSize(width: drag.translation.width / scale, height: drag.translation.height / scale)
                let cardH: CGFloat = post ? 450 : 640
                let fy: CGFloat = (dragStart.midY + off.height) / cardH
                var l = layout
                switch k {
                case "head": l.head = fy < 0.5 ? 0 : 2
                case "table": l.table = fy < 0.36 ? 0 : (fy < 0.64 ? 1 : 2)
                default:
                    l.time = fy < 0.36 ? 0 : (fy < 0.64 ? 1 : 2)
                    // 옆으로 민 만큼 정렬을 한 칸 또는 두 칸 옮김
                    let step: Int = off.width > 130 ? 2 : (off.width > 44 ? 1 : (off.width < -130 ? -2 : (off.width < -44 ? -1 : 0)))
                    l.timeAlign = max(0, min(2, l.timeAlign + step))
                }
                let moved: Bool = l != layout
                withAnimation(.snappy(duration: 0.28)) {
                    layout = l
                    dragOffset = .zero
                    dragKey = nil
                }
                if moved { UIImpactFeedbackGenerator(style: .medium).impactOccurred() }
            }
    }

    /// 미리보기 아래 한 줄: 끌어서 옮길 수 있다는 안내 + (옮겼으면) 되돌리기
    private var moveHint: some View {
        HStack(spacing: 10) {
            Text("Press and hold the time, splits or logo to move it").font(F.t(12)).foregroundStyle(C.text3)
                .lineLimit(1).minimumScaleFactor(0.8)
            if layout != PosterLayout.standard {
                Button { withAnimation(.snappy(duration: 0.28)) { layout = PosterLayout.standard } } label: {
                    Text("Reset").font(F.t(12, .semibold)).foregroundStyle(C.accent)
                        .frame(minHeight: 28).contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("share.resetLayout")
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, -6)
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
    private var routeOf: [RoutePt]? {
        guard let rt = r.detail?.route, rt.count >= 2 else { return nil }
        return rt
    }

    private var optionsCard: some View {
        VStack(spacing: 0) {
            if routeOf != nil {
                optionRow(last: false) {
                    Text("Route map").font(F.t(15))
                } trailing: {
                    Toggle8(on: $mapOn, w: 50, h: 30).accessibilityIdentifier("share.map")
                }
            }
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
            // Smoke: 사진 위에 연기를 겹쳐 영화 느낌 + 글자 바탕 (Poster). 켜면 그라데이션 대신 연기를 씀
            optionRow(last: false) {
                Text("Smoke").font(F.t(15))
            } trailing: {
                smokeSeg
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

    // Off / Light / Strong (Text color 와 같은 모양, 버튼 56×28)
    private var smokeSeg: some View {
        let items: [(String, String)] = [("off", "Off"), ("light", "Light"), ("strong", "Heavy")]
        return HStack(spacing: 0) {
            ForEach(items.indices, id: \.self) { i in
                let k: String = items[i].0
                let on: Bool = smoke == k
                let shape = RoundedRectangle(cornerRadius: 7, style: .continuous)
                Button { withAnimation(.easeOut(duration: 0.2)) { smoke = k } } label: {
                    Text(items[i].1.l10n).font(F.t(13, .semibold)).foregroundStyle(Color.white)
                        .lineLimit(1).minimumScaleFactor(0.8)
                        .frame(width: 56, height: 28)
                        .background(on ? Color.white.opacity(0.16) : Color.clear, in: shape)
                        .contentShape(shape)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("share.smoke.\(k)")
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
                  gradient: gradient, nick: shownNick, smoke: smokeValue, layout: layout,
                  dragKey: placeholder ? dragKey : nil, dragOffset: placeholder ? dragOffset : .zero)
    }

    /// 360pt 너비 시안을 3배로 → 1080 너비
    @MainActor private func image() -> UIImage? {
        let rr = ImageRenderer(content: card(placeholder: false))
        rr.scale = 3
        if let img = rr.uiImage { return img }
        rr.scale = 2                      // 메모리 부족 등으로 실패하면 한 번 더 작게
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

    /// 사진 앱에 저장: 권한 확인 → 저장 → 성공일 때만 "Saved", 실패면 이유 안내
    private func save() {
        guard let img = image(), let data = img.pngData() else {
            saveFail = String(localized: "Couldn't create the image. Please try again.")
            return
        }
        PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
            guard status == .authorized || status == .limited else {
                DispatchQueue.main.async {
                    saveFail = String(localized: "Allow Splits8 to add photos: Settings > Splits8 > Photos > Add Photos Only.")
                }
                return
            }
            PHPhotoLibrary.shared().performChanges({
                let req = PHAssetCreationRequest.forAsset()
                req.addResource(with: .photo, data: data, options: nil)
            }) { ok, _ in
                DispatchQueue.main.async {
                    if ok {
                        UINotificationFeedbackGenerator().notificationOccurred(.success)
                        saved = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) { saved = false }
                    } else {
                        saveFail = String(localized: "Couldn't save to Photos. Please try again.")
                    }
                }
            }
        }
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
