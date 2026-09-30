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
    var vsWord = ""         // VS GOAL
    var vsValue = ""        // −0:27
    var pairs: [Pair] = []
    var seq: [Part] = []
    var runTotal = ""
    var stationTotal = ""

    init() {}

    init(_ r: Record, store: Store) {
        let div = Division.of(r.division)
        badge = "\(r.mode.name) · \(div.name)"
        place = r.title
        divName = div.name
        date = Fm.dmy.string(from: r.date)
        total = Fm.t(r.total)
        avgHR = r.avgHR > 0 ? "\(r.avgHR)" : "--"
        rox = Fm.t(r.roxTotal)
        let v = store.vs(r)
        vsWord = v.word
        vsValue = v.value.map(Fm.d) ?? "--:--"
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
    }

    static func short(_ n: String) -> String { n == "Farmers Carry" ? "Farmers" : n }
}

// MARK: - 공유 카드 (SplitsShare.dc.html) 360 × 640 (Story) / 360 × 450 (Post)

struct ShareCard: View {
    let d: ShareData
    var variant = "poster"          // poster / ticket / block
    var ratio = "story"             // story / post
    var showSplits = true
    var photo: UIImage?
    var placeholder = false

    private var post: Bool { ratio == "post" }
    private var h: CGFloat { post ? 450 : 640 }

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color.black
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

    /// SPLITS8 워드마크 20 / 800, 자간 −0.03em
    private func mark(shadow: Bool = false) -> some View {
        Wordmark(size: 20, tracking: -0.03)
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
                        Text("탭해서 사진 고르기").font(F.t(13, .medium))
                    }
                    .foregroundStyle(C.text2)
                }
            }
        }
    }

    /// 큰 시간 (line-height 0.95, 한 줄)
    private func big(_ s: String, _ size: CGFloat, track: CGFloat) -> some View {
        Text(s).font(F.num(size, .semibold)).tracking(track * size)
            .foregroundStyle(.white)
            .lineLimit(1).minimumScaleFactor(0.5)
            .frame(height: size * 0.95)
    }

    /// 8 / 600, 자간 0.12em
    private func tinyLabel(_ s: String, opacity: Double) -> some View {
        Text(s).font(F.t(8, .semibold)).tracking(0.12 * 8)
            .foregroundStyle(Color.white.opacity(opacity)).lineLimit(1)
    }

    // MARK: Poster

    private var posterScrim: [Gradient.Stop] {
        if post {
            return [.init(color: .black.opacity(0.5), location: 0), .init(color: .clear, location: 0.18),
                    .init(color: .clear, location: 0.26), .init(color: .black.opacity(0.92), location: 0.46),
                    .init(color: .black, location: 0.58)]
        }
        return [.init(color: .black.opacity(0.5), location: 0), .init(color: .clear, location: 0.20),
                .init(color: .clear, location: 0.34), .init(color: .black.opacity(0.9), location: 0.60),
                .init(color: .black, location: 0.72)]
    }

    private var poster: some View {
        let photoH: CGFloat = h * (post ? 0.52 : 0.64)
        return ZStack(alignment: .topLeading) {
            photoView()
                .frame(width: 360, height: photoH).clipped()
                .grayscale(1).contrast(1.05)
            LinearGradient(stops: posterScrim, startPoint: .top, endPoint: .bottom)
                .allowsHitTesting(false)
            glow(0.30, rx: 0.9, ry: 0.45, cx: 0.85, cy: 1.0)
            glow(0.12, rx: 0.7, ry: 0.35, cx: 0, cy: 0.6)
            posterContent
                .padding(.top, 22).padding(.horizontal, 22).padding(.bottom, 24)
                .frame(width: 360, height: h, alignment: .topLeading)
        }
    }

    private var posterContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .center) {
                mark()
                Spacer(minLength: 10)
                Text(d.badge).font(F.t(11, .semibold)).foregroundStyle(C.accent).lineLimit(1)
                    .padding(.vertical, 5).padding(.horizontal, 10)
                    .background(ShareCard.glass, in: Capsule())
                    .overlay(Capsule().strokeBorder(ShareCard.glassRing, lineWidth: 1))
            }
            Spacer(minLength: 0)
            Text("\(d.place) · \(d.date)").font(F.t(13, .medium))
                .foregroundStyle(Color.white.opacity(0.75)).lineLimit(1)
            big(d.total, post ? 64 : 76, track: -0.045).padding(.top, 6)
            HStack(alignment: .top, spacing: 12) {
                posterStat("AVG HR", d.avgHR, color: .white)
                posterStat("ROXZONE", d.rox, color: .white)
                posterStat(d.vsWord, d.vsValue, color: C.accent)
            }
            .padding(.top, 14)
            if showSplits && !d.pairs.isEmpty {
                posterTable.padding(.top, 16)
            }
        }
    }

    private func posterStat(_ label: String, _ value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            tinyLabel(label, opacity: 0.55)
            Text(value).font(F.num(18)).tracking(-0.01 * 18)
                .foregroundStyle(color).lineLimit(1).minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // grid 20px | 1fr | 40px | 40px, column-gap 8
    private var posterTable: some View {
        let size: CGFloat = post ? 10 : 11
        let rowH: CGFloat = post ? 19 : 23
        return VStack(spacing: 0) {
            HStack(alignment: .bottom, spacing: 8) {
                Color.clear.frame(width: 20, height: 1)
                tinyLabel("STATION", opacity: 0.45).frame(maxWidth: .infinity, alignment: .leading)
                tinyLabel("RUN", opacity: 0.45).frame(width: 40, alignment: .trailing)
                tinyLabel("STN", opacity: 0.45).frame(width: 40, alignment: .trailing)
            }
            .padding(.bottom, 6)
            .overlay(alignment: .bottom) { Rectangle().fill(Color.white.opacity(0.16)).frame(height: 1) }
            ForEach(d.pairs.indices, id: \.self) { i in
                posterRow(d.pairs[i], size: size, last: i == d.pairs.count - 1)
                    .frame(height: rowH)
            }
        }
    }

    private func posterRow(_ p: ShareData.Pair, size: CGFloat, last: Bool) -> some View {
        HStack(spacing: 8) {
            Text(p.no).font(F.num(10, .semibold)).foregroundStyle(C.accent)
                .frame(width: 20, alignment: .leading)
            Text(p.sn).font(F.t(size, .medium)).foregroundStyle(.white).lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(p.rt).font(F.num(size, .medium)).foregroundStyle(Color.white.opacity(0.55)).lineLimit(1)
                .frame(width: 40, alignment: .trailing)
            Text(p.st).font(F.num(size, .semibold)).foregroundStyle(.white).lineLimit(1)
                .frame(width: 40, alignment: .trailing)
        }
        .frame(maxHeight: .infinity)
        .overlay(alignment: .bottom) {
            if !last { Rectangle().fill(Color.white.opacity(0.07)).frame(height: 1) }
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
                    .overlay(alignment: .topLeading) { mark(shadow: true).padding(14) }
                    .clipShape(ticketTop)
                ticketCut
                ticketPanel
            }
            .padding(16)
            .frame(width: 360, height: h)
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
            HStack(spacing: 8) {
                Text("\(d.place) · \(d.divName)").lineLimit(1)
                Spacer(minLength: 0)
                Text(d.date).lineLimit(1).fixedSize()
            }
            .font(F.t(12, .medium)).foregroundStyle(C.text2)
            HStack(alignment: .bottom) {
                big(d.total, post ? 48 : 56, track: -0.04)
                Spacer(minLength: 8)
                VStack(alignment: .trailing, spacing: 3) {
                    Text(d.vsValue).foregroundStyle(C.accent)
                    Text("\(d.avgHR) BPM").foregroundStyle(C.text2)
                }
                .font(F.num(14)).lineLimit(1).fixedSize()
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

    // MARK: Block

    private var block: some View {
        ZStack(alignment: .topLeading) {
            glow(0.34, rx: 0.9, ry: 0.55, cx: 0.85, cy: 0)
            glow(0.14, rx: 0.8, ry: 0.45, cx: 0, cy: 1.0)
            blockContent
                .padding(24)
                .frame(width: 360, height: h, alignment: .topLeading)
        }
    }

    private var blockContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            mark()
            Text(d.badge).font(F.t(13, .semibold)).lineLimit(1).padding(.top, 14)
            Text("\(d.place) · \(d.date)").font(F.t(13, .medium))
                .foregroundStyle(Color.white.opacity(0.65)).lineLimit(1).padding(.top, 3)
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
            tinyLabel(label, opacity: 0.55)
            Text(value).font(F.num(18)).foregroundStyle(color).lineLimit(1).minimumScaleFactor(0.7)
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
                tinyLabel("STATION", opacity: 0.5).frame(maxWidth: .infinity, alignment: .leading)
                tinyLabel("RUN", opacity: 0.5).frame(width: 40, alignment: .trailing)
                tinyLabel("STN", opacity: 0.5).frame(width: 44, alignment: .trailing)
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
    @State private var pick: PhotosPickerItem?
    @State private var photo: UIImage?
    @State private var saved = false

    private var data: ShareData { r.detail.map { ShareData($0, store: store) } ?? ShareData() }
    private var post: Bool { ratio == "post" }

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
            splitsRow
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
            Text(l).font(F.t(13, .semibold)).foregroundStyle(on ? C.accent : C.aeb)
                .frame(maxWidth: .infinity).frame(height: 38)
                .background(Color(hex: 0x111111), in: shape)
                .overlay(shape.strokeBorder(on ? C.accent : Color(hex: 0x1C1C1C), lineWidth: on ? 1.5 : 1))
                .contentShape(shape)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(l)
    }

    // Split times (카드 radius 14, padding 10×16, 토글 50×30)
    private var splitsRow: some View {
        HStack {
            Text("Split times").font(F.t(15))
            Spacer()
            Toggle8(on: $splits, w: 50, h: 30)
                .accessibilityIdentifier("share.splits")
        }
        .padding(.vertical, 10).padding(.horizontal, 16)
        .card8(14)
    }

    // Instagram (노란 유리) · Save image (#1A1A1A): 50 높이, radius 14, 15/600, gap 10
    private var actionButtons: some View {
        HStack(spacing: 10) {
            Button { instagram() } label: {
                Text("Instagram").font(F.t(15, .semibold)).foregroundStyle(.black)
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
        ShareCard(d: data, variant: variant, ratio: ratio, showSplits: splits, photo: photo, placeholder: placeholder)
    }

    /// 360pt 너비 시안을 3배로 → 1080 너비
    @MainActor private func image() -> UIImage? {
        let rr = ImageRenderer(content: card(placeholder: false))
        rr.scale = 3
        return rr.uiImage
    }

    /// Instagram 스토리로 바로 보내기 (앱 ID 있을 때) · 아니면 iOS 공유 창
    private func instagram() {
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
