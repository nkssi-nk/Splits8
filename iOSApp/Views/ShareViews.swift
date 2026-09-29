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

// MARK: - 공유 카드 (SplitsShare.dc.html) 360 × 640 / 450

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
        .environment(\.colorScheme, .dark)
    }

    // 워드마크 20pt heavy
    private func mark(shadow: Bool = false) -> some View {
        HStack(spacing: 1.6) {
            Text("SPLITS").foregroundStyle(.white)
            Text("8").foregroundStyle(C.accent)
        }
        .font(.system(size: 20, weight: .heavy)).tracking(-0.6)
        .shadow(color: shadow ? .black.opacity(0.5) : .clear, radius: 3, y: 1)
    }

    /// 노란 빛 (radial-gradient rx% ry% at cx% cy%)
    private func glow(_ a: Double, rx: CGFloat, ry: CGFloat, cx: CGFloat, cy: CGFloat) -> some View {
        AmbientLayer(a: Ambient(hex: 0xFFE600, alpha: a, rx: rx, ry: ry, cx: cx, cy: cy))
    }

    private var glass: some ShapeStyle { Color.white.opacity(0.07) }

    @ViewBuilder private func photoView() -> some View {
        if let photo {
            Image(uiImage: photo).resizable().scaledToFill()
        } else {
            ZStack {
                Color(hex: 0x1A1A1A)
                if placeholder {
                    VStack(spacing: 6) {
                        Image(systemName: "photo").font(.system(size: 26))
                        Text("탭해서 사진 고르기").font(F.t(13, .medium))
                    }
                    .foregroundStyle(C.text2)
                    .frame(maxHeight: .infinity, alignment: .center)
                    .padding(.bottom, variant == "poster" ? (post ? 90 : 120) : 0)
                }
            }
        }
    }

    private func big(_ s: String, _ size: CGFloat, _ w: Font.Weight, lh: CGFloat, track: CGFloat, color: Color) -> some View {
        Text(s).font(.system(size: size, weight: w)).monospacedDigit().tracking(track * size)
            .foregroundStyle(color).lineLimit(1).minimumScaleFactor(0.5)
            .frame(height: size * lh)
    }

    private func stat(_ label: String, _ value: String, valueColor: Color) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(label).font(.system(size: 8, weight: .semibold)).tracking(0.96).foregroundStyle(.white.opacity(0.55)).lineLimit(1)
            Text(value).font(.system(size: 18, weight: .semibold)).monospacedDigit().tracking(-0.18)
                .foregroundStyle(valueColor).lineLimit(1).minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: Poster

    private var poster: some View {
        let photoH = h * (post ? 0.52 : 0.64)
        let scrim: [Gradient.Stop] = post
            ? [.init(color: .black.opacity(0.5), location: 0), .init(color: .clear, location: 0.18), .init(color: .clear, location: 0.26),
               .init(color: .black.opacity(0.92), location: 0.46), .init(color: .black, location: 0.58)]
            : [.init(color: .black.opacity(0.5), location: 0), .init(color: .clear, location: 0.20), .init(color: .clear, location: 0.34),
               .init(color: .black.opacity(0.9), location: 0.60), .init(color: .black, location: 0.72)]
        let row: CGFloat = post ? 10 : 11
        let rowH: CGFloat = post ? 19 : 23
        return ZStack(alignment: .topLeading) {
            photoView().frame(width: 360, height: photoH).clipped().grayscale(1).contrast(1.05)
            LinearGradient(stops: scrim, startPoint: .top, endPoint: .bottom)
            glow(0.30, rx: 0.9, ry: 0.45, cx: 0.85, cy: 1.0)
            glow(0.12, rx: 0.7, ry: 0.35, cx: 0, cy: 0.6)
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    mark()
                    Spacer()
                    Text(d.badge).font(.system(size: 11, weight: .semibold)).foregroundStyle(C.accent).lineLimit(1)
                        .padding(.vertical, 5).padding(.horizontal, 10)
                        .background(glass, in: Capsule())
                        .overlay(Capsule().strokeBorder(Color.white.opacity(0.10), lineWidth: 1))
                }
                Spacer(minLength: 0)
                Text("\(d.place) · \(d.date)").font(.system(size: 13, weight: .medium)).foregroundStyle(.white.opacity(0.75)).lineLimit(1)
                big(d.total, post ? 64 : 76, .semibold, lh: 0.95, track: -0.045, color: .white).padding(.top, 6)
                HStack(alignment: .top, spacing: 12) {
                    stat("AVG HR", d.avgHR, valueColor: .white)
                    stat("ROXZONE", d.rox, valueColor: .white)
                    stat(d.vsWord, d.vsValue, valueColor: C.accent)
                }
                .padding(.top, 14)
                if showSplits && !d.pairs.isEmpty {
                    VStack(spacing: 0) {
                        HStack(spacing: 8) {
                            Color.clear.frame(width: 20, height: 1)
                            Text("STATION").frame(maxWidth: .infinity, alignment: .leading)
                            Text("RUN").frame(width: 40, alignment: .trailing)
                            Text("STN").frame(width: 40, alignment: .trailing)
                        }
                        .font(.system(size: 8, weight: .semibold)).tracking(0.96).foregroundStyle(.white.opacity(0.45))
                            .padding(.bottom, 6)
                            .overlay(alignment: .bottom) { Rectangle().fill(Color.white.opacity(0.16)).frame(height: 1) }
                        ForEach(d.pairs.indices, id: \.self) { i in
                            let p = d.pairs[i]
                            HStack(spacing: 8) {
                                Text(p.no).font(.system(size: 10, weight: .heavy)).monospacedDigit().foregroundStyle(C.accent).frame(width: 20, alignment: .leading)
                                Text(p.sn).font(.system(size: row, weight: .medium)).foregroundStyle(.white).lineLimit(1)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                Text(p.rt).font(.system(size: row, weight: .medium)).monospacedDigit().foregroundStyle(.white.opacity(0.55)).frame(width: 40, alignment: .trailing)
                                Text(p.st).font(.system(size: row, weight: .semibold)).monospacedDigit().foregroundStyle(.white).frame(width: 40, alignment: .trailing)
                            }
                            .frame(height: rowH)
                            .overlay(alignment: .bottom) { if i < d.pairs.count - 1 { Rectangle().fill(Color.white.opacity(0.07)).frame(height: 1) } }
                        }
                    }
                    .padding(.top, 16)
                }
            }
            .padding(.top, 22).padding(.horizontal, 22).padding(.bottom, 24)
            .frame(width: 360, height: h, alignment: .topLeading)
        }
    }

    // MARK: Ticket

    private var ticket: some View {
        let mx = CGFloat(max(1, d.seq.map(\.t).max() ?? 1))
        let stripH: CGFloat = post ? 32 : 56
        return ZStack(alignment: .topLeading) {
            glow(0.22, rx: 0.9, ry: 0.4, cx: 0.5, cy: 1.0)
            VStack(spacing: 0) {
                photoView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity).clipped()
                    .overlay(alignment: .topLeading) { mark(shadow: true).padding(14) }
                    .clipShape(UnevenRoundedRectangle(topLeadingRadius: 18, bottomLeadingRadius: 4,
                                                      bottomTrailingRadius: 4, topTrailingRadius: 18, style: .continuous))
                ZStack {
                    Path { p in p.move(to: CGPoint(x: 12, y: 7.5)); p.addLine(to: CGPoint(x: 316, y: 7.5)) }
                        .stroke(Color.white.opacity(0.18), style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
                    HStack {
                        Circle().fill(Color.black).frame(width: 16, height: 16).offset(x: -24)
                        Spacer()
                        Circle().fill(Color.black).frame(width: 16, height: 16).offset(x: 24)
                    }
                }
                .frame(height: 16)
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 8) {
                        Text("\(d.place) · \(d.divName)").lineLimit(1)
                        Spacer(minLength: 0)
                        Text(d.date).fixedSize()
                    }
                    .font(.system(size: 12, weight: .medium)).foregroundStyle(C.text2)
                    HStack(alignment: .bottom) {
                        big(d.total, post ? 48 : 56, .semibold, lh: 0.95, track: -0.04, color: .white)
                        Spacer(minLength: 8)
                        VStack(alignment: .trailing, spacing: 0) {
                            Text(d.vsValue).foregroundStyle(C.accent)
                            Text("\(d.avgHR) BPM").foregroundStyle(C.text2)
                        }
                        .font(.system(size: 14, weight: .semibold)).monospacedDigit()
                    }
                    if showSplits && !d.seq.isEmpty {
                        HStack(alignment: .bottom, spacing: 2) {
                            ForEach(d.seq.indices, id: \.self) { i in
                                let s = d.seq[i]
                                UnevenRoundedRectangle(topLeadingRadius: 2, topTrailingRadius: 2)
                                    .fill(s.run ? Color.white.opacity(0.18) : C.accent)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: max(2, stripH * CGFloat(s.t) / mx))
                            }
                        }
                        .frame(height: stripH, alignment: .bottom)
                        HStack {
                            Text("RUN \(d.runTotal)"); Spacer(); Text("STATIONS \(d.stationTotal)"); Spacer(); Text("ROX \(d.rox)")
                        }
                        .font(.system(size: 8, weight: .semibold)).tracking(0.8).foregroundStyle(C.text3)
                    }
                }
                .padding(.top, 16).padding(.horizontal, 18).padding(.bottom, 18)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background {
                    ZStack {
                        Color.white.opacity(0.07)
                        AmbientLayer(a: Ambient(hex: 0xFFE600, alpha: 0.30, rx: 0.9, ry: 0.9, cx: 0.9, cy: 1.1))
                    }
                }
                .clipShape(UnevenRoundedRectangle(topLeadingRadius: 4, bottomLeadingRadius: 18,
                                                  bottomTrailingRadius: 18, topTrailingRadius: 4, style: .continuous))
                .overlay(UnevenRoundedRectangle(topLeadingRadius: 4, bottomLeadingRadius: 18,
                                                bottomTrailingRadius: 18, topTrailingRadius: 4, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.10), lineWidth: 1))
            }
            .padding(16)
            .frame(width: 360, height: h)
        }
    }

    // MARK: Block

    private var block: some View {
        let size: CGFloat = post ? 56 : 76
        let rowH: CGFloat = post ? 18 : 34
        let rowSize: CGFloat = post ? 11 : 14
        let numSize: CGFloat = post ? 13 : 17
        return ZStack(alignment: .topLeading) {
            glow(0.34, rx: 0.9, ry: 0.55, cx: 0.85, cy: 0)
            glow(0.14, rx: 0.8, ry: 0.45, cx: 0, cy: 1.0)
            VStack(alignment: .leading, spacing: 0) {
                mark()
                Text(d.badge).font(.system(size: 13, weight: .semibold)).padding(.top, 14).lineLimit(1)
                Text("\(d.place) · \(d.date)").font(.system(size: 13, weight: .medium)).foregroundStyle(.white.opacity(0.65)).padding(.top, 3).lineLimit(1)
                Spacer(minLength: 0)
                big(d.total, size, .bold, lh: 0.95, track: -0.045, color: .white)
                HStack(spacing: 6) {
                    tile(d.vsWord, d.vsValue, color: C.accent)
                    tile("AVG HR", d.avgHR, color: .white)
                    tile("ROXZONE", d.rox, color: .white)
                }
                .padding(.top, 14)
                if showSplits && !d.pairs.isEmpty {
                    VStack(spacing: 0) {
                        HStack(spacing: 8) {
                            Color.clear.frame(width: 20, height: 1)
                            Color.clear.frame(width: 16, height: 1)
                            Text("STATION").frame(maxWidth: .infinity, alignment: .leading)
                            Text("RUN").frame(width: 40, alignment: .trailing)
                            Text("STN").frame(width: 44, alignment: .trailing)
                        }
                        .font(.system(size: 8, weight: .semibold)).tracking(0.96).foregroundStyle(.white.opacity(0.5))
                        .frame(height: 22)
                        .overlay(alignment: .bottom) { Rectangle().fill(Color.white.opacity(0.10)).frame(height: 1) }
                        ForEach(d.pairs.indices, id: \.self) { i in
                            let p = d.pairs[i]
                            HStack(spacing: 8) {
                                Text(p.no).font(.system(size: 11, weight: .heavy)).monospacedDigit().foregroundStyle(C.accent).frame(width: 20, alignment: .leading)
                                Icon8(p.icon, 14, .white).opacity(0.9).frame(width: 16)
                                Text(p.sn).font(.system(size: rowSize, weight: .medium)).lineLimit(1).frame(maxWidth: .infinity, alignment: .leading)
                                Text(p.rt).font(.system(size: rowSize, weight: .medium)).monospacedDigit().foregroundStyle(.white.opacity(0.5)).frame(width: 40, alignment: .trailing)
                                Text(p.st).font(.system(size: numSize, weight: .semibold)).monospacedDigit().frame(width: 44, alignment: .trailing)
                            }
                            .frame(height: rowH)
                            .overlay(alignment: .bottom) { if i < d.pairs.count - 1 { Rectangle().fill(Color.white.opacity(0.07)).frame(height: 1) } }
                        }
                    }
                    .padding(.vertical, 4).padding(.horizontal, 12)
                    .background(glass, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(Color.white.opacity(0.10), lineWidth: 1))
                    .padding(.top, post ? 10 : 20)
                }
            }
            .foregroundStyle(.white)
            .padding(24)
            .frame(width: 360, height: h, alignment: .topLeading)
        }
    }

    private func tile(_ label: String, _ value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label).font(.system(size: 8, weight: .semibold)).tracking(0.96).foregroundStyle(.white.opacity(0.55)).lineLimit(1)
            Text(value).font(.system(size: 18, weight: .semibold)).monospacedDigit().foregroundStyle(color).lineLimit(1).minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 10).padding(.horizontal, 12)
        .background(glass, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Color.white.opacity(0.10), lineWidth: 1))
    }
}

// MARK: - I7 공유 화면

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

    var body: some View {
        let post = ratio == "post"
        let scale: CGFloat = post ? 0.86 : 0.72
        let pw: CGFloat = post ? 310 : 259, ph: CGFloat = post ? 387 : 461
        VStack(spacing: 14) {
            ZStack {
                Text("Share").font(F.t(17, .semibold))
                HStack {
                    Button("Close") { r.go(.detail) }.font(F.t(17)).foregroundStyle(C.text2).accessibilityIdentifier("nav.left")
                    Spacer()
                    Color.clear.frame(width: 40)
                }
            }
            .buttonStyle(.plain)
            .frame(height: 44).padding(.horizontal, 4)

            PhotosPicker(selection: $pick, matching: .images) {
                card(placeholder: true)
                    .scaleEffect(scale, anchor: .topLeading)
                    .frame(width: pw, height: ph, alignment: .topLeading)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .background(RoundedRectangle(cornerRadius: 15, style: .continuous).fill(Color(hex: 0x262626)).padding(-1))
            }
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity)
            .animation(.easeInOut(duration: 0.2), value: ratio)
            .onChange(of: pick) { _, item in
                Task {
                    if let item, let data = try? await item.loadTransferable(type: Data.self), let img = UIImage(data: data) {
                        photo = img
                    }
                }
            }

            Seg8(items: [("story", "Story 9:16"), ("post", "Post 4:5")], selected: ratio,
                 fontSize: 12, track: Color(hex: 0x141414), tracking: 0.48) { ratio = $0 }

            HStack(spacing: 8) {
                let vs = [("poster", "Poster"), ("ticket", "Ticket"), ("block", "Block")]
                ForEach(vs.indices, id: \.self) { i in
                    let k = vs[i].0, l = vs[i].1
                    let on = variant == k
                    Button { variant = k } label: {
                        Text(l).font(F.t(13, .semibold)).foregroundStyle(on ? C.accent : C.aeb)
                            .frame(maxWidth: .infinity).frame(height: 38)
                            .background(Color(hex: 0x111111), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .strokeBorder(on ? C.accent : Color(hex: 0x1C1C1C), lineWidth: on ? 1.5 : 1))
                    }
                    .buttonStyle(.plain)
                }
            }

            HStack {
                Text("Split times").font(F.t(15))
                Spacer()
                Toggle8(on: $splits, w: 50, h: 30)
            }
            .padding(.vertical, 10).padding(.horizontal, 16)
            .card8(14)

            HStack(spacing: 10) {
                Button { instagram() } label: {
                    Text("Instagram").font(F.t(15, .semibold)).foregroundStyle(.black)
                        .frame(maxWidth: .infinity).frame(height: 50)
                        .yellowFill(14)
                }
                .buttonStyle(Press())
                Button { save() } label: {
                    Text(saved ? "Saved" : "Save image").font(F.t(15, .semibold)).foregroundStyle(.white)
                        .frame(maxWidth: .infinity).frame(height: 50)
                        .background(C.btn1A, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(Press())
            }
        }
        .padding(.horizontal, 16)
    }

    private func card(placeholder: Bool) -> ShareCard {
        ShareCard(d: data, variant: variant, ratio: ratio, showSplits: splits, photo: photo, placeholder: placeholder)
    }

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
