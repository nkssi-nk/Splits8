import SwiftUI
import UIKit

// MARK: - 빌드 27 · 앱 평가 요청 (App Store 별점)
// 운동 끝 카드를 닫았을 때, 좋은 순간(기록 3개 이상 · PB · PFT 등급 상승 · 새 배지)에만.
// 같은 버전에서는 한 번만, 그리고 60일에 한 번 이하. 운동 중 · 처음 켰을 때는 묻지 않음.

enum ReviewAsk {
    private static let lastKey = "review.lastAsk"
    private static let versionKey = "review.lastVersion"
    private static let minGap: TimeInterval = 60 * 24 * 3600

    static var appVersion: String {
        (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) ?? ""
    }

    /// 마지막으로 물어본 때 · 버전 (UserDefaults)
    static var lastReviewAsk: Date? {
        get { UserDefaults.standard.object(forKey: lastKey) as? Date }
        set { UserDefaults.standard.set(newValue, forKey: lastKey) }
    }
    static var lastReviewVersion: String? {
        get { UserDefaults.standard.string(forKey: versionKey) }
        set { UserDefaults.standard.set(newValue, forKey: versionKey) }
    }

    /// 지금 물어봐도 되는지 (버전 · 간격)
    static var allowed: Bool {
        if Demo.enabled { return false }
        if let v = lastReviewVersion, v == appVersion { return false }
        if let d = lastReviewAsk, Date().timeIntervalSince(d) < minGap { return false }
        return true
    }

    static func markAsked() {
        lastReviewAsk = Date()
        lastReviewVersion = appVersion
    }

    /// 이 기록의 카드를 닫은 지금이 좋은 순간인지
    static func goodMoment(_ rec: Record) -> Bool {
        let store = Store.shared
        guard rec.counts, rec.isComplete else { return false }
        let countsN: Int = store.records.filter { $0.counts && $0.isComplete }.count
        if countsN >= 3 { return true }
        if store.isPB(rec) { return true }
        if !Badges.new(with: rec, in: store.records).isEmpty { return true }
        if rec.mode == .pft && rec.pftSplits != nil {
            let prev: [Record] = store.records.filter { $0.id != rec.id && $0.mode == .pft && $0.counts && $0.pftSplits != nil }
            if let best = prev.map({ PFT.grade($0.total).rank }).max(), PFT.grade(rec.total).rank > best { return true }
        }
        return false
    }
}

// MARK: - 빌드 27 · 앱을 열 때 받은 응원 · 친구 요청 알림 (위쪽 작은 띠, 4초 뒤 사라짐)

struct AppNotice: Equatable, Identifiable {
    let id: UUID = UUID()
    let text: String
}

extension Router {
    /// 앱이 앞으로 올 때 한 번: 로그인해 있으면 받은 응원 · 친구 요청을 확인하고, 있으면 띠를 띄움
    @MainActor
    func checkNotice() async {
        let store = Store.shared
        guard !Demo.enabled, store.signedIn else { return }
        await store.refreshSocial()
        let cheers: Int = store.unseenCheers
        let reqs: Int = store.incoming.count
        guard cheers > 0 || reqs > 0 else { return }
        // 운동 중 · 가입 · 온보딩 · 운동 끝 카드 · 이미 친구 화면이면 띄우지 않음
        guard scr.showsTabs, scr != .friends, finish == nil, phoneRun == nil, !liveMirror else { return }
        var parts: [String] = []
        if cheers > 0 {
            parts.append(cheers == 1 ? String(localized: "1 new cheer") : String(localized: "\(cheers) new cheers"))
        }
        if reqs > 0 {
            parts.append(reqs == 1 ? String(localized: "1 friend request") : String(localized: "\(reqs) friend requests"))
        }
        let n = AppNotice(text: (cheers > 0 ? "🔥 " : "👋 ") + parts.joined(separator: " · "))
        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) { notice = n }
        let id: UUID = n.id
        DispatchQueue.main.asyncAfter(deadline: .now() + 4) { [weak self] in
            guard let self, self.notice?.id == id else { return }
            withAnimation(.easeOut(duration: 0.3)) { self.notice = nil }
        }
    }

    /// 띠를 누름 → 친구 화면
    func openNotice() {
        withAnimation(.easeOut(duration: 0.2)) { notice = nil }
        friendsFrom = scr == .home ? .home : .settings
        go(.friends)
    }
}

/// 위쪽 작은 알림 띠
struct NoticeBanner: View {
    let text: String
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 8) {
                Text(text).font(F.t(15, .semibold)).foregroundStyle(.black).lineLimit(1).minimumScaleFactor(0.8)
                Spacer(minLength: 4)
                Chevron8(color: .black)
            }
            .padding(.horizontal, 16).frame(height: 44)
            .background(C.accent, in: Capsule())
            .shadow(color: .black.opacity(0.4), radius: 10, y: 4)
            .contentShape(Capsule())
        }
        .buttonStyle(Press(scale: 0.97))
        .accessibilityIdentifier("notice.banner")
    }
}

// MARK: - 4번 · 앱 안 업데이트 안내 (홈 화면 위 띠)
// 앱을 켤 때 하루 한 번 App Store 최신 버전 조회 → 내 버전보다 높으면 홈 위에 띠 [Update] [×].
// × = 그 버전은 다시 안 띄움. TestFlight · 데모 · 처음 설치 안내 · 운동 중에는 안 띄움. 실패하면 조용히 넘어감.

enum AppUpdate {
    static let lookupURL = URL(string: "https://itunes.apple.com/lookup?bundleId=com.nkssi.splits8&country=kr")!
    static let storeURL = URL(string: "itms-apps://apps.apple.com/app/id6817286611")!
    private static let checkedKey = "update.checkedAt"
    private static let latestKey = "update.latest"
    private static let dismissedKey = "update.dismissed"

    /// TestFlight 로 설치한 빌드 (베타는 TestFlight 가 알림 · 업데이트 담당)
    static var isTestFlight: Bool {
        Bundle.main.appStoreReceiptURL?.lastPathComponent == "sandboxReceipt"
    }

    /// 숫자 단위 비교: a 가 b 보다 높으면 true (1.1.10 > 1.1.9)
    static func isNewer(_ a: String, than b: String) -> Bool {
        let x: [Int] = a.split(separator: ".").map { Int($0) ?? 0 }
        let y: [Int] = b.split(separator: ".").map { Int($0) ?? 0 }
        let n: Int = max(x.count, y.count)
        for i in 0..<n {
            let p: Int = i < x.count ? x[i] : 0
            let q: Int = i < y.count ? y[i] : 0
            if p != q { return p > q }
        }
        return false
    }

    /// 띄울 새 버전 (없으면 nil). 조회는 하루 한 번, 그 사이에는 저장해 둔 값을 씀
    static func available() async -> String? {
        let d = UserDefaults.standard
        var latest: String? = d.string(forKey: latestKey)
        let last: Date = (d.object(forKey: checkedKey) as? Date) ?? .distantPast
        if Date().timeIntervalSince(last) > 24 * 3600 {
            if let v = await fetchLatest() {
                latest = v
                d.set(v, forKey: latestKey)
            }
            d.set(Date(), forKey: checkedKey)
        }
        guard let v = latest, isNewer(v, than: ReviewAsk.appVersion) else { return nil }
        if d.string(forKey: dismissedKey) == v { return nil }
        return v
    }

    static func dismiss(_ version: String) {
        UserDefaults.standard.set(version, forKey: dismissedKey)
    }

    private struct Lookup: Decodable {
        struct Item: Decodable { let version: String? }
        let results: [Item]
    }

    private static func fetchLatest() async -> String? {
        var req = URLRequest(url: lookupURL)
        req.timeoutInterval = 10
        req.cachePolicy = .reloadIgnoringLocalCacheData
        guard let got = try? await URLSession.shared.data(for: req),
              (got.1 as? HTTPURLResponse)?.statusCode == 200,
              let info = try? JSONDecoder().decode(Lookup.self, from: got.0) else { return nil }
        return info.results.first?.version
    }
}

extension Router {
    /// 앱이 앞으로 올 때: 새 버전이 있으면 홈 위 띠에 보일 버전을 정함
    @MainActor
    func checkUpdate() async {
        guard !Demo.enabled, !AppUpdate.isTestFlight, Store.shared.settings.hasOnboarded else { return }
        guard let v = await AppUpdate.available() else { return }
        // 운동 중이면 띄우지 않음 (다음에 앱을 열 때 다시)
        guard phoneRun == nil, !liveMirror else { return }
        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) { updateVersion = v }
    }

    func dismissUpdate() {
        if let v = updateVersion { AppUpdate.dismiss(v) }
        withAnimation(.easeOut(duration: 0.2)) { updateVersion = nil }
    }
}

/// 홈 화면 위 "새 버전" 띠: 글 · [Update] · [×]
struct UpdateBanner: View {
    let version: String
    let r = Router.shared

    var body: some View {
        HStack(spacing: 10) {
            Text("A new version is available (\(version))")
                .font(F.t(14, .semibold)).foregroundStyle(.black)
                .lineLimit(2).minimumScaleFactor(0.8)
                .frame(maxWidth: .infinity, alignment: .leading)
            Button {
                UIApplication.shared.open(AppUpdate.storeURL)
            } label: {
                Text("Update").font(F.t(14, .bold)).foregroundStyle(C.accent)
                    .padding(.horizontal, 14).frame(height: 32)
                    .background(Color.black, in: Capsule())
            }
            .buttonStyle(Press(scale: 0.95))
            .accessibilityIdentifier("update.open")
            Button {
                r.dismissUpdate()
            } label: {
                Image(systemName: "xmark").font(.system(size: 13, weight: .bold)).foregroundStyle(.black)
                    .frame(width: 32, height: 32)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text("Close"))
            .accessibilityIdentifier("update.close")
        }
        .padding(.leading, 16).padding(.trailing, 6).padding(.vertical, 8)
        .background(C.accent, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .transition(.move(edge: .top).combined(with: .opacity))
        .accessibilityIdentifier("update.banner")
    }
}

// MARK: - 16번 · 친구 숨긴 뒤 "Hidden · Undo" 띠 (4초 뒤 사라짐)

extension Router {
    func showHideUndo(_ u: HideUndo) {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) { hideUndo = u }
        let token: UUID = u.token
        DispatchQueue.main.asyncAfter(deadline: .now() + 4) { [weak self] in
            guard let self, self.hideUndo?.token == token else { return }
            withAnimation(.easeOut(duration: 0.3)) { self.hideUndo = nil }
        }
    }

    func undoHide(_ u: HideUndo) {
        withAnimation(.easeOut(duration: 0.25)) {
            Store.shared.undoHide(u)
            hideUndo = nil
        }
    }
}

struct HideUndoBanner: View {
    let onUndo: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Text("Hidden").font(F.t(15, .semibold)).foregroundStyle(.white).lineLimit(1)
            Spacer(minLength: 4)
            Button(action: onUndo) {
                Text("Undo").font(F.t(15, .semibold)).foregroundStyle(C.accent)
                    .padding(.horizontal, 10).frame(height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(Press(scale: 0.95))
            .accessibilityIdentifier("friends.undoHide")
        }
        .padding(.leading, 18).padding(.trailing, 8).frame(height: 48)
        .background(C.control, in: Capsule())
        .shadow(color: .black.opacity(0.4), radius: 10, y: 4)
    }
}
