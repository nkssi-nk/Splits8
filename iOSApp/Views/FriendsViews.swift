import SwiftUI

// MARK: - Race › FRIENDS 순위표 (로그인 상태)

struct Leaderboard: View {
    let store = Store.shared
    let r = Router.shared

    var body: some View {
        let s = store.settings
        let rows = store.leaderboard
        let meT = rows.first { $0.user_id == store.sb.userId }?.t
        VStack(spacing: 10) {
            Seg8(items: [("sim", "Full Sim"), ("race", "Race"), ("stations", "Stations")], selected: s.lbTab) {
                store.settings.lbTab = $0
                Task { await store.refreshLeaderboard() }
            }
            if s.lbTab == "stations" {
                Flow(spacing: 6) {
                    ForEach(Station.all, id: \.key) { st in
                        let on = s.lbStation == st.key
                        Button {
                            store.settings.lbStation = st.key
                            Task { await store.refreshLeaderboard() }
                        } label: {
                            HStack(spacing: 6) {
                                Icon8(st.key, 14, on ? .black : C.accent)
                                Text(st.name == "Farmers Carry" ? "Farmers" : st.name).font(F.t(12, .semibold))
                            }
                            .foregroundStyle(on ? Color.black : Color.white)
                            .padding(.horizontal, 12).frame(height: 34)
                            .background(on ? C.accent : Color.white.opacity(0.08), in: Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            HStack {
                Text(caption).font(F.t(12)).foregroundStyle(C.text2)
                Spacer()
                Button(s.lbAllDivisions ? "All divisions" : store.div.name) {
                    store.settings.lbAllDivisions.toggle()
                    Task { await store.refreshLeaderboard() }
                }
                .font(F.t(12, .semibold)).foregroundStyle(C.accent).buttonStyle(.plain)
            }
            .padding(.horizontal, 4)

            VStack(spacing: 0) {
                if rows.isEmpty {
                    Text("아직 기록이 없어요. Full Simulation을 한 번 완료하면 여기에 나와요.")
                        .font(F.t(13)).foregroundStyle(C.text2).multilineTextAlignment(.center).lineSpacing(5)
                        .frame(maxWidth: .infinity).padding(.vertical, 22).padding(.horizontal, 18)
                }
                ForEach(Array(rows.enumerated()), id: \.element.id) { i, row in
                    let me = row.user_id == store.sb.userId
                    Button { open(row) } label: {
                        HStack(spacing: 12) {
                            Text("\(i + 1)").font(F.num(17, .bold)).foregroundStyle(i == 0 ? C.accent : .white)
                                .frame(width: 22, alignment: .leading)
                            Avatar(photo: me ? store.photo : nil, url: me ? nil : row.avatar_url, ini: row.nickname.prefix(1).uppercased(),
                                   size: 34, font: 14, bg: me ? C.accent : C.control, fg: me ? .black : .white)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(me ? "@\(row.nickname) (you)" : "@\(row.nickname)")
                                    .font(F.t(15, me ? .bold : .medium)).foregroundStyle(me ? C.accent : .white).lineLimit(1)
                                Text(row.division).font(F.t(12)).foregroundStyle(C.text2)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            VStack(alignment: .trailing, spacing: 0) {
                                Text(Fm.t(row.t)).font(F.num(18)).tracking(-0.36)
                                if !me, let meT {
                                    Text(Fm.d(row.t - meT)).font(F.num(12)).foregroundStyle(row.t < meT ? C.bad : C.good)
                                }
                            }
                        }
                        .padding(.vertical, 12).padding(.horizontal, 18)
                        .background(me ? C.accent.opacity(0.08) : Color.clear)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .rowLine(i < rows.count - 1)
                }
            }
            .card8()

            Button("+ Add friends") { r.go(.friends) }
                .font(F.t(14, .semibold)).foregroundStyle(C.accent).buttonStyle(.plain).padding(6)
        }
        .task { await store.refreshLeaderboard() }
    }

    private var caption: String {
        switch store.settings.lbTab {
        case "sim": return "Best Full Simulation · All time"
        case "race": return "Best race time · All events"
        default:
            let n = Station.of(store.settings.lbStation)?.name ?? ""
            return "Best \(n == "Farmers Carry" ? "Farmers" : n) split · All time"
        }
    }

    /// 친구를 누르면 Full Simulation 에서 그 친구와 비교
    private func open(_ row: LBRow) {
        guard row.user_id != store.sb.userId else { return }
        if let f = store.friends.first(where: { $0.id == row.user_id }) {
            var s = store.settings
            s.friendId = f.id
            s.simCmp = "friend"
            store.settings = s
            r.go(.sim)
        }
    }
}

// MARK: - I5f Friends

struct FriendsView: View {
    let store = Store.shared
    let r = Router.shared
    @State private var query = ""
    @State private var hit: RemoteProfile?

    var body: some View {
        let myBest = store.simBest?.total
        VStack(spacing: 10) {
            BackLink(label: "Settings") { r.go(.settings) }

            if store.signedIn {
                HStack(spacing: 8) {
                    Text("@").font(F.t(16)).foregroundStyle(C.text2)
                    TextField("", text: $query, prompt: Text("Search nickname").foregroundColor(C.text3))
                        .font(F.t(16)).textInputAutocapitalization(.never).autocorrectionDisabled()
                        .padding(.vertical, 11)
                        .onChange(of: query) { _, v in search(v) }
                }
                .padding(.horizontal, 12)
                .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .padding(.top, 4)

                if let h = hit, let n = h.nickname {
                    let req = store.requested.contains(h.id) || store.friends.contains { $0.id == h.id }
                    HStack(spacing: 12) {
                        Avatar(url: h.avatar_url, ini: n.prefix(1).uppercased())
                        VStack(alignment: .leading, spacing: 0) {
                            Text("@\(n)").font(F.t(15, .semibold))
                            Text(h.division ?? "").font(F.t(12)).foregroundStyle(C.text2)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        Button { add(h) } label: {
                            Text(req ? "Requested" : "Add").font(F.t(13, .semibold))
                                .foregroundStyle(req ? C.text2 : .black)
                                .padding(.horizontal, 14).frame(height: 32)
                                .background(req ? Color.white.opacity(0.12) : C.accent, in: Capsule())
                        }
                        .buttonStyle(.plain).disabled(req)
                    }
                    .padding(.vertical, 12).padding(.horizontal, 18)
                    .card8()
                }
            } else {
                HStack(spacing: 12) {
                    Text("닉네임으로 친구를 찾고 기록을 비교하려면 가입이 필요해요.")
                        .font(F.t(13)).foregroundStyle(C.text2).lineSpacing(5)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    PillButton("Sign up") { r.toAuth(from: .friends) }
                }
                .padding(.vertical, 14).padding(.horizontal, 18)
                .card8()
                .padding(.top, 4)
            }

            LargeTitle(text: "Friends", top: 0)
            Text("선택한 친구의 기록이 Full Simulation의 비교 대상과 Training 구간 목표로 쓰입니다.")
                .font(F.t(13)).foregroundStyle(C.text2).lineSpacing(6)
                .frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 4).padding(.bottom, 4)
            if !store.friends.isEmpty {
                VStack(spacing: 0) {
                    ForEach(Array(store.friends.enumerated()), id: \.element.id) { i, f in
                        let on = store.settings.friendId == f.id
                        let d = (myBest != nil && f.hasSplits) ? f.total - myBest! : nil
                        Button { if f.hasSplits { store.toggleFriend(f) } } label: {
                            HStack(spacing: 14) {
                                Avatar(url: f.avatarUrl, ini: f.ini, size: 40, font: 15)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(f.name).font(F.t(16, on ? .semibold : .regular))
                                    Text(f.hasSplits ? "\(f.div) · \(f.date)" : "\(f.div) · Full Simulation 기록 없음")
                                        .font(F.t(12)).foregroundStyle(C.text2)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                VStack(alignment: .trailing, spacing: 0) {
                                    Text(f.hasSplits ? Fm.t(f.total) : "--:--").font(F.num(18)).tracking(-0.36)
                                    if let d {
                                        Text(Fm.d(d)).font(F.num(11)).foregroundStyle(d > 0 ? C.good : d < 0 ? C.bad : C.text2)
                                    }
                                }
                                if on { Check8() } else { Color.clear.frame(width: 20) }
                            }
                            .padding(.vertical, 14).padding(.horizontal, 18).contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .rowLine(i < store.friends.count - 1)
                    }
                }
                .card8()
            }
            Text("탭하면 비교 대상으로 선택 · 다시 탭하면 해제 · VS 값은 내 최고 기록 기준")
                .font(F.t(12)).foregroundStyle(C.text3)
                .frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 4)
        }
        .padding(.horizontal, 16)
        .task { await store.refreshSocial() }
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
