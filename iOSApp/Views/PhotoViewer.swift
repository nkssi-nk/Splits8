import SwiftUI

// MARK: - 프로필·친구 사진 크게 보기

/// 크게 볼 사진 (내 사진은 image, 친구 사진은 서버 주소 url)
struct PhotoItem: Equatable {
    var image: UIImage? = nil
    var url: String? = nil
    var title: String
    var sub: String = ""
}

extension View {
    /// 사진이 있을 때만 눌러서 크게 보기 (사진 없이 글자만이면 반응 없음 → 바깥 버튼이 그대로 동작)
    func photoTap(_ item: PhotoItem?) -> some View {
        highPriorityGesture(item == nil ? nil : TapGesture().onEnded {
            if let item { Router.shared.photoView = item }
        })
    }
}

/// 검은 화면 위에 사진을 화면 폭만큼 크게. 두 손가락으로 확대, 아래로 쓸어내리거나 바깥·X 누르면 닫힘
struct PhotoViewer: View {
    let item: PhotoItem
    @State private var scale: CGFloat = 1
    @State private var lastScale: CGFloat = 1
    @State private var drag: CGFloat = 0

    private func close() { Router.shared.photoView = nil }

    var body: some View {
        GeometryReader { g in
            let side: CGFloat = max(0, g.size.width - 32)
            ZStack {
                Color.black.opacity(0.94 * (1 - min(1, drag / 400)))
                    .ignoresSafeArea()
                    .onTapGesture { close() }
                VStack(spacing: 14) {
                    photo
                        .frame(width: side, height: side)
                        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                        .scaleEffect(scale)
                        .gesture(zoom)
                        .onTapGesture(count: 2) { withAnimation(.snappy) { scale = 1; lastScale = 1 } }
                    VStack(spacing: 2) {
                        Text(item.title).font(F.t(F.body, .semibold)).lineLimit(1)
                        if !item.sub.isEmpty {
                            Text(item.sub).font(F.t(F.foot)).foregroundStyle(C.text2).lineLimit(1)
                        }
                    }
                    .opacity(scale > 1.05 ? 0 : 1)
                }
                .offset(y: drag)
                .gesture(swipeDown)
                VStack {
                    HStack {
                        Spacer()
                        Button { close() } label: {
                            Image(systemName: "xmark").font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(.white)
                                .frame(width: 36, height: 36)
                                .background(Color.white.opacity(0.14), in: Circle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("photo.close")
                    }
                    Spacer()
                }
                .padding(.horizontal, 16).padding(.top, 8)
            }
        }
        .accessibilityIdentifier("photo.viewer")
    }

    @ViewBuilder
    private var photo: some View {
        if let img = item.image {
            Image(uiImage: img).resizable().scaledToFill()
        } else if let s = item.url, let u = URL(string: s) {
            AsyncImage(url: u) { ph in
                switch ph {
                case .success(let img): img.resizable().scaledToFill()
                default: ZStack { C.control; ProgressView().tint(.white) }
                }
            }
        } else {
            C.control
        }
    }

    private var zoom: some Gesture {
        MagnificationGesture()
            .onChanged { v in scale = min(4, max(1, lastScale * v)) }
            .onEnded { _ in
                lastScale = scale
                if scale < 1.05 { withAnimation(.snappy) { scale = 1; lastScale = 1 } }
            }
    }

    private var swipeDown: some Gesture {
        DragGesture(minimumDistance: 10)
            .onChanged { v in if scale <= 1.01 { drag = max(0, v.translation.height) } }
            .onEnded { v in
                if scale <= 1.01 && (v.translation.height > 120 || v.predictedEndTranslation.height > 300) {
                    close()
                } else {
                    withAnimation(.snappy) { drag = 0 }
                }
            }
    }
}
