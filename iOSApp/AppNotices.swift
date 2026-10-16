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
