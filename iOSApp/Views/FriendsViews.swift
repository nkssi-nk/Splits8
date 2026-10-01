import SwiftUI

// MARK: - I5f Friends (위 고정 바: ‹ Settings · Friends)

struct FriendsView: View {
    let store = Store.shared
    let r = Router.shared
    @State private var query = ""
    @State private var hit: RemoteProfile?

    var body: some View {
        VStack(spacing: 10) {
            if store.signedIn {
                SearchField8(placeholder: "Search nickname", text: $query, prefix: "@")
                    .onChange(of: query) { _, v in search(v) }
                    .padding(.top, 4)
                    .accessibilityIdentifier("friends.search")
                if let h = hit, let n = h.nickname { hitCard(h, n) }
            } else {
                signUpCard
            }

            Note8(text: "The selected friend's records are used as the Full Simulation comparison and as Training split targets.", color: C.text2)
                .padding(.bottom, 4)
            if !store.friends.isEmpty {
                VStack(spacing: 0) {
                    ForEach(Array(store.friends.enumerated()), id: \.element.id) { i, f in
                        friendRow(f, last: i == store.friends.count - 1)
                    }
                }
                .card8()
            }
            Note8(text: "Tap to compare · Tap again to clear · VS is against your best")
        }
        .padding(.horizontal, 16)
        .task { await store.refreshSocial() }
    }

    /// 가입 전: 설명 13 회색 + Sign up 노란 알약 (padding 14×18, margin-top 4)
    private var signUpCard: some View {
        HStack(spacing: 12) {
            Text("Sign up to find friends by nickname and compare records.")
                .font(F.t(13)).foregroundStyle(C.text2).lineSpacing(13 * 0.45 - 3)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
            YellowPill(title: "Sign up") { r.toAuth(from: .friends) }
                .accessibilityIdentifier("friends.signup")
        }
        .padding(.vertical, 14).padding(.horizontal, 18)
        .card8()
        .padding(.top, 4)
    }

    /// 검색 결과: 34 원 · @닉네임 15/600 · 체급 13 · Add (32 높이 노랑) / Requested (흰 0.12, 회색)
    private func hitCard(_ h: RemoteProfile, _ n: String) -> some View {
        let req = store.requested.contains(h.id) || store.friends.contains { $0.id == h.id }
        return HStack(spacing: 12) {
            FriendAvatar(url: h.avatar_url, ini: String(n.prefix(1)).uppercased(), size: 34)
                .photoTap(h.avatar_url.map { PhotoItem(url: $0, title: "@" + n, sub: h.division ?? "") })
            VStack(alignment: .leading, spacing: 0) {
                Text("@\(n)").font(F.t(15, .semibold)).lineLimit(1)
                Text(h.division ?? "").font(F.t(13)).foregroundStyle(C.text2).lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Button { add(h) } label: {
                Text(req ? "Requested" : "Add").font(F.t(13, .semibold))
                    .foregroundStyle(req ? C.text2 : Color.black)
                    .padding(.horizontal, 14).frame(height: 32)
                    .background(req ? Color.white.opacity(0.12) : C.accent, in: Capsule())
                    .contentShape(Capsule())
            }
            .buttonStyle(Press(scale: 0.96))
            .disabled(req)
            .accessibilityIdentifier("friends.add")
        }
        .padding(.vertical, 12).padding(.horizontal, 18)
        .card8()
    }

    /// padding 14×18, gap 14: 40 원 (15/600) · 이름 17 (선택 600) + 13 회색 · 시간 17/600 + 차이 11/600 · 체크 20 (없으면 20 빈칸)
    private func friendRow(_ f: Friend, last: Bool) -> some View {
        let on = store.settings.friendId == f.id
        let myBest = store.simBest?.total
        let d: Int? = (myBest != nil && f.hasSplits) ? f.total - (myBest ?? 0) : nil
        return Button { if f.hasSplits { store.toggleFriend(f) } } label: {
            HStack(spacing: 14) {
                FriendAvatar(url: f.avatarUrl, ini: f.ini, size: 40)
                    .photoTap(f.avatarUrl.map { PhotoItem(url: $0, title: "@" + f.name, sub: f.div) })
                VStack(alignment: .leading, spacing: 2) {
                    Text(f.name).font(F.t(17, on ? .semibold : .regular)).foregroundStyle(.white).lineLimit(1)
                    Text(friendSub(f))
                        .font(F.t(13)).foregroundStyle(C.text2).lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                VStack(alignment: .trailing, spacing: 0) {
                    Text(f.hasSplits ? Fm.t(f.total) : "--:--").font(F.num(17)).tracking(-0.02 * 17).lineLimit(1)
                    if let d {
                        Text(Fm.d(d)).font(F.num(11)).foregroundStyle(d > 0 ? C.good : d < 0 ? C.bad : C.text2).lineLimit(1)
                    }
                }
                .fixedSize()
                if on { Check8(size: 20) } else { Color.clear.frame(width: 20, height: 20) }
            }
            .padding(.vertical, 14).padding(.horizontal, 18).contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .rowLine(!last)
        .accessibilityIdentifier("friend." + f.name)
    }

    /// Open Men · 13 Sep 2026  /  Open Men · No Full Simulation record
    private func friendSub(_ f: Friend) -> String {
        let tail: String = f.hasSplits ? f.date : "No Full Simulation record".l10n
        return f.div + " · " + tail
    }

    private func search(_ v: String) {
        let q = v.lowercased().replacingOccurrences(of: "@", with: "")
        guard q.count >= 2 else { hit = nil; return }
        Task {
            try? await Task.sleep(nanoseconds: 300_000_000)
            guard q == query.lowercased().replacingOccurrences(of: "@", with: "") else { return }
            let res = (try? await store.sb.searchProfiles(prefix: q)) ?? []
            hit = res.first { $0.id != store.sb.userId }
        }
    }

    private func add(_ p: RemoteProfile) {
        store.requested.insert(p.id)
        Task {
            try? await store.sb.addFriend(p.id)
            await store.refreshSocial()
        }
    }
}

/// 친구 원형 사진: 서버 사진이 있으면 사진, 없으면 #2C2C2E 바탕 첫 글자 (15/600)
private struct FriendAvatar: View {
    let url: String?
    let ini: String
    let size: CGFloat
    var body: some View {
        ZStack {
            Avatar8(size: size, initial: ini, fontSize: 15)
            if let url, let u = URL(string: url) {
                AsyncImage(url: u) { img in
                    img.resizable().scaledToFill()
                } placeholder: {
                    Color.clear
                }
                .frame(width: size, height: size)
                .clipShape(Circle())
            }
        }
        .frame(width: size, height: size)
    }
}
