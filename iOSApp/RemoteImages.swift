import SwiftUI
import UIKit
import CryptoKit

/// 14번: 친구 사진 받기 (안드로이드 `RemoteImages` 와 같은 방식)
/// - URL → 메모리 + 파일 저장(Caches/avatars). 주소의 `?v=` 까지 이름에 넣어서 사진을 바꾸면 새로 받음.
/// - URLSession 으로 받고, 실패하면 한 번 더. 같은 주소를 동시에 두 번 안 받음.
/// - 받은 사진은 관찰 가능한 값 → 화면이 다시 그려져도 받기가 취소되지 않음 (AsyncImage 문제).
@MainActor @Observable
final class RemoteImages {
    static let shared = RemoteImages()

    private(set) var images: [String: UIImage] = [:]
    @ObservationIgnored private var loading: Set<String> = []
    @ObservationIgnored private var failedAt: [String: Date] = [:]

    private let dir: URL = {
        let d = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("avatars", isDirectory: true)
        try? FileManager.default.createDirectory(at: d, withIntermediateDirectories: true)
        return d
    }()

    /// 화면에서 부르는 곳: 있으면 바로 주고, 없으면 받기 시작 (다 받으면 화면이 다시 그려짐)
    func image(_ url: String?) -> UIImage? {
        guard let url, !url.isEmpty else { return nil }
        if let img = images[url] { return img }
        load(url)
        return nil
    }

    private func file(_ url: String) -> URL {
        let h = SHA256.hash(data: Data(url.utf8)).prefix(12).map { String(format: "%02x", $0) }.joined()
        return dir.appendingPathComponent(h + ".jpg")
    }

    private func load(_ url: String) {
        guard !loading.contains(url) else { return }
        // 실패한 주소는 1분 동안 다시 안 받음 (화면이 그려질 때마다 계속 받지 않게)
        if let t = failedAt[url], Date().timeIntervalSince(t) < 60 { return }
        loading.insert(url)
        let f = file(url)
        Task.detached(priority: .utility) {
            var img: UIImage? = nil
            if let d = try? Data(contentsOf: f) { img = UIImage(data: d) }
            if img == nil, let u = URL(string: url) {
                for attempt in 0..<2 {
                    if attempt > 0 { try? await Task.sleep(nanoseconds: 800_000_000) }
                    if let got = try? await URLSession.shared.data(from: u),
                       ((got.1 as? HTTPURLResponse)?.statusCode ?? 200) < 300,
                       let i = UIImage(data: got.0) {
                        img = Self.thumb(i)
                        if let jpg = img?.jpegData(compressionQuality: 0.85) { try? jpg.write(to: f, options: .atomic) }
                        break
                    }
                }
            }
            let done = img
            await MainActor.run {
                self.loading.remove(url)
                if let done { self.images[url] = done } else { self.failedAt[url] = Date() }
            }
        }
    }

    /// 목록 동그라미용으로 줄여서 저장 (최대 256px)
    nonisolated private static func thumb(_ i: UIImage) -> UIImage {
        let m: CGFloat = 256
        let s = max(i.size.width, i.size.height)
        guard s > m else { return i }
        let k = m / s
        let size = CGSize(width: (i.size.width * k).rounded(), height: (i.size.height * k).rounded())
        let fmt = UIGraphicsImageRendererFormat.default(); fmt.scale = 1
        return UIGraphicsImageRenderer(size: size, format: fmt).image { _ in i.draw(in: CGRect(origin: .zero, size: size)) }
    }
}
