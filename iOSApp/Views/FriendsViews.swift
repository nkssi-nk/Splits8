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
    /// 빌드 24: 친구 10명이 다 참
    @State private var limitAlert = false
    /// 빌드 24: 응원 보낼 친구 (시트)
    @State private var cheerTo: Friend?

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

            requestsSection
            cheersSection

            if store.signedIn {
                HStack(alignment: .firstTextBaseline) {
                    SectionText("MY FRIENDS")
                    Spacer(minLength: 0)
                    Text(verbatim: "\(store.friendCount) / \(Friend.freeLimit)")
                        .font(F.num(13)).foregroundStyle(store.friendsFull ? C.accent : C.text2)
                        .accessibilityIdentifier("friends.count")
                }
                .padding(.top, 14).padding(.horizontal, 4)
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
            sentSection
            blockedSection
        }
        .padding(.horizontal, 16)
        .task { await store.refreshSocial() }
        .onAppear {
            // 받은 응원은 화면을 열고 잠깐 뒤 읽음으로 (빨간 점이 바로 사라지지 않게)
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) { store.markCheersSeen() }
        }
        .sheet(item: $cheerTo) { f in
            CheerSheet(friend: f)
                .presentationDetents([.height(430)])
                .presentationBackground(Color(hex: 0x1C1C1E))
        }
        .alert(String(localized: "You can add up to \(Friend.freeLimit) friends"), isPresented: $limitAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Remove a friend or cancel a request to add someone new.")
        }
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

    // MARK: 친구 요청 (빌드 22) — 수락해야 친구가 되고, 그 뒤에만 서로 기록이 보임

    /// 받은 요청: Accept (노랑) · Decline (흰 0.12)
    @ViewBuilder private var requestsSection: some View {
        let list: [FriendReq] = store.incoming
        if store.signedIn && !list.isEmpty {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                SectionText("REQUESTS")
                CountBadge(n: list.count)
                Spacer(minLength: 0)
            }
            .padding(.top, 14).padding(.horizontal, 4)
            VStack(spacing: 0) {
                ForEach(Array(list.enumerated()), id: \.element.id) { i, q in
                    HStack(spacing: 12) {
                        FriendAvatar(url: q.avatarUrl, ini: String(q.name.prefix(1)).uppercased(), size: 34)
                        VStack(alignment: .leading, spacing: 0) {
                            Text("@" + q.name).font(F.t(15, .semibold)).lineLimit(1)
                            Text(q.div).font(F.t(13)).foregroundStyle(C.text2).lineLimit(1)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        pill("Decline", yellow: false) { withAnimation(.easeOut(duration: 0.2)) { store.respond(q, accept: false) } }
                            .accessibilityIdentifier("friends.decline")
                        pill("Accept", yellow: true) {
                            if store.friendsFull { limitAlert = true; return }
                            withAnimation(.easeOut(duration: 0.2)) { store.respond(q, accept: true) }
                        }
                            .accessibilityIdentifier("friends.accept")
                    }
                    .padding(.vertical, 12).padding(.horizontal, 18)
                    .rowLine(i < list.count - 1)
                }
            }
            .card8()
            Note8(text: "Records are shared only after you accept.")
        }
    }

    /// 빌드 24: 받은 응원 (최근 8개) — 누가 · 뭘 · 언제
    @ViewBuilder private var cheersSection: some View {
        let list: [CheerRow] = Array(store.cheers.prefix(8))
        if store.signedIn && !list.isEmpty {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                SectionText("CHEERS")
                if store.unseenCheers > 0 {
                    Circle().fill(C.bad).frame(width: 8, height: 8).accessibilityIdentifier("friends.cheerDot")
                }
                Spacer(minLength: 0)
            }
            .padding(.top, 14).padding(.horizontal, 4)
            VStack(spacing: 0) {
                ForEach(Array(list.enumerated()), id: \.element.id) { i, c in
                    let k: CheerKind = CheerKind(rawValue: c.kind) ?? .clap
                    HStack(spacing: 12) {
                        FriendAvatar(url: c.avatar_url, ini: String(c.nickname.prefix(1)).uppercased(), size: 34)
                        VStack(alignment: .leading, spacing: 1) {
                            Text("@" + c.nickname).font(F.t(15, .semibold)).lineLimit(1)
                            Text(k.isEmoji ? String(localized: "Sent you \(k.emoji)") : k.emoji + " " + k.line.l10n)
                                .font(F.t(13)).foregroundStyle(c.seen ? C.text2 : .white).lineLimit(1)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        Text(Self.ago(c.created_at)).font(F.t(12)).foregroundStyle(C.text3).lineLimit(1)
                        if !c.seen { Circle().fill(C.bad).frame(width: 6, height: 6) }
                    }
                    .padding(.vertical, 11).padding(.horizontal, 18)
                    .rowLine(i < list.count - 1)
                }
            }
            .card8()
        }
    }

    /// 방금 · 5분 · 3시간 · 2일
    static func ago(_ d: Date) -> String {
        let s: Int = max(0, Int(Date().timeIntervalSince(d)))
        if s < 60 { return String(localized: "now") }
        if s < 3600 { return String(localized: "\(s / 60)m") }
        if s < 86400 { return String(localized: "\(s / 3600)h") }
        return String(localized: "\(s / 86400)d")
    }

    /// 보낸 요청: 상대가 수락할 때까지 기다림 · Cancel 로 취소
    @ViewBuilder private var sentSection: some View {
        let list: [FriendReq] = store.outgoing
        if store.signedIn && !list.isEmpty {
            SectionLabel(text: "SENT", top: 14)
            VStack(spacing: 0) {
                ForEach(Array(list.enumerated()), id: \.element.id) { i, q in
                    HStack(spacing: 12) {
                        FriendAvatar(url: q.avatarUrl, ini: String(q.name.prefix(1)).uppercased(), size: 34)
                        VStack(alignment: .leading, spacing: 0) {
                            Text("@" + q.name).font(F.t(15, .semibold)).lineLimit(1)
                            Text(q.div + " · " + "Requested".l10n).font(F.t(13)).foregroundStyle(C.text2).lineLimit(1)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        pill("Cancel", yellow: false) { withAnimation(.easeOut(duration: 0.2)) { store.cancelRequest(q) } }
                            .accessibilityIdentifier("friends.cancelRequest")
                    }
                    .padding(.vertical, 12).padding(.horizontal, 18)
                    .rowLine(i < list.count - 1)
                }
            }
            .card8()
            Note8(text: "They'll see your request in Friends. Records are shared once they accept.")
        }
    }

    /// 32 높이 알약 버튼
    private func pill(_ title: String, yellow: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title.l10n).font(F.t(13, .semibold))
                .foregroundStyle(yellow ? Color.black : .white)
                .padding(.horizontal, 14).frame(height: 32)
                .background(yellow ? C.accent : Color.white.opacity(0.12), in: Capsule())
                .contentShape(Capsule())
        }
        .buttonStyle(Press(scale: 0.96))
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
        let isFriend: Bool = store.friends.contains { $0.id == h.id }
        let got: FriendReq? = store.incoming.first { $0.id == h.id }
        let req = store.requested.contains(h.id) || isFriend || store.outgoing.contains { $0.id == h.id }
        let title: String = got != nil ? "Accept" : isFriend ? "Friends" : req ? "Requested" : "Add"
        let yellow: Bool = got != nil || !req
        return HStack(spacing: 12) {
            FriendAvatar(url: h.avatar_url, ini: String(n.prefix(1)).uppercased(), size: 34)
                .photoTap(h.avatar_url.map { PhotoItem(url: $0, title: "@" + n, sub: h.division ?? "") })
            VStack(alignment: .leading, spacing: 0) {
                Text("@\(n)").font(F.t(15, .semibold)).lineLimit(1)
                Text(h.division ?? "").font(F.t(13)).foregroundStyle(C.text2).lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Button {
                if store.friendsFull { limitAlert = true; return }
                if let got { store.respond(got, accept: true) } else { add(h) }
            } label: {
                Text(title.l10n).font(F.t(13, .semibold))
                    .foregroundStyle(yellow ? Color.black : C.text2)
                    .padding(.horizontal, 14).frame(height: 32)
                    .background(yellow ? C.accent : Color.white.opacity(0.12), in: Capsule())
                    .contentShape(Capsule())
            }
            .buttonStyle(Press(scale: 0.96))
            .disabled(got == nil && req)
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
          // 빌드 24: 응원 보내기 (정해진 이모지 · 문구만)
          Button { cheerTo = f } label: {
              Image(systemName: "hands.clap.fill").font(.system(size: 15, weight: .semibold))
                  .foregroundStyle(C.accent)
                  .frame(width: 36, height: 44)
                  .contentShape(Rectangle())
          }
          .buttonStyle(Press(scale: 0.9))
          .accessibilityIdentifier("friends.cheer")
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

/// 받은 친구 요청 개수 (노란 동그라미, 검은 숫자)
struct CountBadge: View {
    let n: Int
    var body: some View {
        if n > 0 {
            Text("\(n)").font(F.num(12, .semibold)).foregroundStyle(.black)
                .padding(.horizontal, 6).frame(minWidth: 20, minHeight: 20)
                .background(C.accent, in: Capsule())
                .fixedSize()
                .accessibilityIdentifier("friends.badge")
        }
    }
}

/// 빌드 24: 응원 고르기 (이모지 3개 + 문구 4개). 누르면 바로 보냄
struct CheerSheet: View {
    let friend: Friend
    let store = Store.shared
    @Environment(\.dismiss) private var dismiss
    @State private var sending = false
    @State private var sent = false
    @State private var error: String?

    var body: some View {
        VStack(spacing: 14) {
            Capsule().fill(Color.white.opacity(0.25)).frame(width: 36, height: 5).padding(.top, 8)
            Text(String(localized: "Cheer @\(friend.name)")).font(F.t(20, .semibold)).lineLimit(1)
            if sent {
                Spacer()
                Check8(color: C.good, size: 44)
                Text("Sent!").font(F.t(17, .semibold))
                Spacer()
            } else {
                HStack(spacing: 12) {
                    ForEach(CheerKind.allCases.filter(\.isEmoji)) { k in
                        Button { send(k) } label: {
                            Text(k.emoji).font(.system(size: 34))
                                .frame(maxWidth: .infinity).frame(height: 72)
                                .background(C.card, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                        }
                        .buttonStyle(Press(scale: 0.94))
                        .accessibilityIdentifier("cheer.\(k.rawValue)")
                    }
                }
                VStack(spacing: 0) {
                    let lines = CheerKind.allCases.filter { !$0.isEmoji }
                    ForEach(Array(lines.enumerated()), id: \.element) { i, k in
                        Button { send(k) } label: {
                            HStack(spacing: 10) {
                                Text(k.emoji).font(.system(size: 18))
                                Text(k.line.l10n).font(F.t(16)).foregroundStyle(.white)
                                Spacer()
                            }
                            .padding(.vertical, 12).padding(.horizontal, 16)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .rowLine(i < lines.count - 1)
                        .accessibilityIdentifier("cheer.\(k.rawValue)")
                    }
                }
                .card8()
                if let error { Text(error).font(F.t(13)).foregroundStyle(C.bad).multilineTextAlignment(.center) }
                Spacer(minLength: 0)
            }
        }
        .padding(.horizontal, 20)
        .disabled(sending)
    }

    private func send(_ k: CheerKind) {
        sending = true; error = nil
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        Task {
            let e: String? = await store.sendCheer(k, to: friend)
            sending = false
            if let e { error = e; return }
            withAnimation(.spring(duration: 0.3)) { sent = true }
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            try? await Task.sleep(nanoseconds: 900_000_000)
            dismiss()
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
