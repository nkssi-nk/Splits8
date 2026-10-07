import SwiftUI

// MARK: - I5f Friends (위 고정 바: ‹ Settings · Friends)

struct FriendsView: View {
    let store = Store.shared
    let r = Router.shared
    @State private var query = ""
    @State private var hit: RemoteProfile?
    /// 찾기 결과 안내: "" 없음 / searching / none / error
    @State private var searchState = ""
    /// 차단 확인창에 띄울 사람
    @State private var blockAsk: BlockedUser?
    /// 메일 앱을 열 수 없을 때 주소 안내
    @State private var mailFail = false

    var body: some View {
        VStack(spacing: 10) {
            if store.signedIn {
                // 이메일 전체 또는 닉네임 전체를 정확히 넣어야 나옴 (앞 글자만으로는 안 나옴 — 모르는 사람을 훑어볼 수 없게)
                SearchField8(placeholder: "Email or nickname", text: $query)
                    .keyboardType(.emailAddress)
                    .onChange(of: query) { _, v in search(v) }
                    .padding(.top, 4)
                    .accessibilityIdentifier("friends.search")
                if let h = hit, let n = h.nickname { hitCard(h, n) }
                else if searchState == "none" {
                    Note8(text: "No one found. Enter the full email or the full nickname.", color: C.text2)
                        .accessibilityIdentifier("friends.none")
                } else if searchState == "error" {
                    Note8(text: "Couldn't search right now. Check your connection and try again.", color: C.text2)
                }
                Note8(text: "Friends who signed up with Apple and hid their email can only be found by nickname.")
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
            blockedSection
        }
        .padding(.horizontal, 16)
        .task { await store.refreshSocial() }
        .alert("Block this user?", isPresented: Binding(get: { blockAsk != nil }, set: { if !$0 { blockAsk = nil } })) {
            Button("Block user", role: .destructive) {
                if let b = blockAsk {
                    if hit?.id == b.id { hit = nil }
                    withAnimation(.easeOut(duration: 0.25)) { store.block(id: b.id, name: b.name) }
                }
                blockAsk = nil
            }
            Button("Cancel", role: .cancel) { blockAsk = nil }
        } message: {
            Text("They are removed from your friends and hidden from your search and rankings. You can unblock them here later.")
        }
        .alert("Report by email", isPresented: $mailFail) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(verbatim: Config.supportEmail)
        }
    }

    // MARK: 신고 · 차단 (다른 사용자의 닉네임 · 사진이 보이는 곳)

    /// ··· 메뉴: Report (운영자에게 메일) · Block
    private func moreMenu(id: String, name: String) -> some View {
        Menu {
            Button { report(id: id, name: name) } label: { Label("Report", systemImage: "flag") }
            Button(role: .destructive) { blockAsk = BlockedUser(id: id, name: name) } label: {
                Label("Block user", systemImage: "hand.raised")
            }
        } label: {
            Image(systemName: "ellipsis").font(.system(size: 15, weight: .semibold))
                .foregroundStyle(C.text2)
                .frame(width: 36, height: 44)
                .contentShape(Rectangle())
        }
        .accessibilityIdentifier("friends.more")
    }

    /// 신고: 메일 앱을 열어 운영자에게 보냄 (누구를 신고하는지 미리 적어 둠). 메일 앱이 없으면 주소를 알려 줌
    private func report(id: String, name: String) {
        let subject: String = "[SPLITS8] Report @" + name
        let body: String = "Reported user: @\(name)\nUser ID: \(id)\n\n" + String(localized: "Tell us what is wrong (nickname, photo or records):") + "\n"
        var c = URLComponents()
        c.scheme = "mailto"
        c.path = Config.supportEmail
        c.queryItems = [URLQueryItem(name: "subject", value: subject), URLQueryItem(name: "body", value: body)]
        guard let u = c.url else { mailFail = true; return }
        UIApplication.shared.open(u) { ok in if !ok { mailFail = true } }
    }

    /// 차단한 사람 목록 (Unblock 으로 풂)
    @ViewBuilder private var blockedSection: some View {
        let list: [BlockedUser] = store.settings.blocked
        if !list.isEmpty {
            SectionLabel(text: "BLOCKED", top: 14)
            VStack(spacing: 0) {
                ForEach(Array(list.enumerated()), id: \.element.id) { i, b in
                    HStack(spacing: 12) {
                        Text("@" + b.name).font(F.t(17)).foregroundStyle(C.text2).lineLimit(1)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Button { withAnimation(.easeOut(duration: 0.2)) { store.unblock(b.id) } } label: {
                            Text("Unblock").font(F.t(13, .semibold)).foregroundStyle(.white)
                                .padding(.horizontal, 14).frame(height: 32)
                                .background(Color.white.opacity(0.12), in: Capsule())
                                .contentShape(Capsule())
                        }
                        .buttonStyle(Press(scale: 0.96))
                        .accessibilityIdentifier("friends.unblock")
                    }
                    .padding(.vertical, 11).padding(.horizontal, 18)
                    .rowLine(i < list.count - 1)
                }
            }
            .card8()
        }
    }

    /// 가입 전: 설명 13 회색 + Sign up 노란 알약 (padding 14×18, margin-top 4)
    private var signUpCard: some View {
        HStack(spacing: 12) {
            Text("Sign up to find friends by email or nickname and compare records.")
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
            moreMenu(id: h.id, name: n)
        }
        .padding(.vertical, 12).padding(.leading, 18).padding(.trailing, 6)
        .card8()
    }

    /// padding 14×18, gap 14: 40 원 (15/600) · 이름 17 (선택 600) + 13 회색 · 시간 17/600 + 차이 11/600 · 체크 20 (없으면 20 빈칸)
    private func friendRow(_ f: Friend, last: Bool) -> some View {
        let on = store.settings.friendId == f.id
        let myBest = store.simBest?.total
        let d: Int? = (myBest != nil && f.hasSplits) ? f.total - (myBest ?? 0) : nil
        return HStack(spacing: 0) {
          Button { if f.hasSplits { store.toggleFriend(f) } } label: {
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
            .padding(.vertical, 14).padding(.leading, 18).padding(.trailing, 4).contentShape(Rectangle())
          }
          .buttonStyle(.plain)
          .accessibilityIdentifier("friend." + f.name)
          moreMenu(id: f.id, name: f.name)
              .padding(.trailing, 6)
        }
        .rowLine(!last)
    }

    /// Open Men · 13 Sep 2026  /  Open Men · No Full Simulation record
    private func friendSub(_ f: Friend) -> String {
        let tail: String = f.hasSplits ? f.date : "No Full Simulation record".l10n
        return f.div + " · " + tail
    }

    /// 찾을 글자: 앞뒤 빈칸을 빼고 소문자로. 닉네임 앞의 @ 는 뺌 (이메일 안의 @ 는 그대로)
    private static func clean(_ v: String) -> String {
        let t: String = v.trimmingCharacters(in: .whitespaces).lowercased()
        return t.hasPrefix("@") ? String(t.dropFirst()) : t
    }
    /// 이메일 모양이거나 닉네임 모양(3–16자)일 때만 서버에 물어봄
    private static func searchable(_ q: String) -> Bool {
        q.range(of: "^[^@\\s]+@[^@\\s]+\\.[^@\\s]+$", options: .regularExpression) != nil
            || q.range(of: "^[a-z0-9_]{3,16}$", options: .regularExpression) != nil
    }

    private func search(_ v: String) {
        let q: String = Self.clean(v)
        hit = nil
        guard Self.searchable(q) else { searchState = ""; return }
        searchState = "searching"
        Task {
            try? await Task.sleep(nanoseconds: 500_000_000)
            guard q == Self.clean(query) else { return }
            let found: RemoteProfile?
            do { found = try await store.sb.findUser(q) } catch {
                // 못 찾은 것과 물어보지 못한 것(네트워크 등)을 구분
                if q == Self.clean(query) { hit = nil; searchState = "error" }
                return
            }
            guard q == Self.clean(query) else { return }
            if let p = found, p.id != store.sb.userId, !store.isBlocked(p.id) {
                hit = p; searchState = ""
            } else {
                hit = nil; searchState = "none"
            }
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
