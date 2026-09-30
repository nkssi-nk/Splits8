import SwiftUI

// MARK: - I1h Home (시안 SplitsPhone.dc.html · isHomeTab / homeVals)

struct HomeView: View {
    let store = Store.shared
    let r = Router.shared

    var body: some View {
        VStack(spacing: 10) {
            profileCard
            SectionLabel(text: "NEXT RACE")
            nextRace
            SectionLabel(text: "START")
            startTiles
            SectionLabel(text: "PERSONAL BESTS")
            bests
            let rec = recent
            if !rec.isEmpty {
                SectionLabel(text: "RECENT")
                VStack(spacing: 0) {
                    ForEach(Array(rec.enumerated()), id: \.element.id) { i, x in
                        recentRow(x, last: i == rec.count - 1)
                    }
                }
                .card8()
            }
            SectionLabel(text: "FRIENDS")
            friends
        }
        .padding(.top, 6)
        .padding(.horizontal, 16)
    }

    // 프로필: 52 원, @nick 17/600, 체급 13 회색, Edit 알약
    private var profileCard: some View {
        let signed = store.signedIn, nick = store.settings.nickname ?? ""
        return HStack(spacing: 14) {
            Avatar8(size: 52, photo: store.photo, initial: signed ? String(nick.prefix(1)).uppercased() : "?",
                    bg: signed ? C.accent : C.control, fg: signed ? .black : C.text2, fontSize: 20)
            VStack(alignment: .leading, spacing: 2) {
                Text(signed ? "@" + nick : "My profile").font(F.t(17, .semibold)).tracking(-0.17).lineLimit(1)
                Text(store.div.name).font(F.t(13)).foregroundStyle(C.text2).lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            GrayPill(title: "Edit", icon: "i_pencil") { r.go(.account) }
                .accessibilityIdentifier("home.edit")
        }
        .padding(.vertical, 14).padding(.horizontal, 16)
        .card8()
    }

    // 다음 대회: 이름 20/600 · 장소·날짜·시간 13 · D-day 28/600 노랑 · 체급 11
    @ViewBuilder private var nextRace: some View {
        let ev = store.settings.event
        if ev.isSet {
            Button { r.go(.race) } label: {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(ev.name).font(F.t(20, .semibold)).tracking(-0.2).lineLimit(1)
                        Text(eventSub(ev)).font(F.t(13)).foregroundStyle(C.text2).lineLimit(1)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    VStack(alignment: .trailing, spacing: 4) {
                        Text(dday(ev.date)).font(F.num(28)).tracking(-0.84).foregroundStyle(C.accent).lineLimit(1)
                        Text(store.div.name).font(F.t(11)).foregroundStyle(C.text2)
                    }
                    .fixedSize()
                }
                .padding(.vertical, 16).padding(.horizontal, 18)
                .card8()
                .contentShape(Rectangle())
            }
            .buttonStyle(Press())
        } else {
            HStack(spacing: 12) {
                Text("등록한 대회가 없어요. 대회를 등록하면 워치 Race에서 바로 시작할 수 있어요.")
                    .font(F.t(13)).foregroundStyle(C.text2).lineSpacing(13 * 0.45 - 3)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
                YellowPill(title: "Add event") { r.evDraft = store.settings.event; r.go(.findEvent) }
            }
            .padding(.vertical, 16).padding(.horizontal, 18)
            .card8()
        }
    }

    // 시작: 3칸 86 높이
    private var startTiles: some View {
        HStack(spacing: 8) {
            startTile("Training", to: .training) { Icon8("modeTraining", 28, C.accent) }
            startTile("Full Sim", to: .sim) { Glyph("i_startSim", 26, C.accent) }
            startTile("Race", to: .race) { Glyph("i_startRace", 26, C.accent) }
        }
    }
    private func startTile<I: View>(_ label: String, to: Scr, @ViewBuilder icon: () -> I) -> some View {
        Button { r.go(to) } label: {
            VStack(spacing: 8) {
                icon()
                Text(label).font(F.t(13, .semibold)).lineLimit(1)
            }
            .frame(maxWidth: .infinity).frame(height: 86)
            .card8()
            .contentShape(Rectangle())
        }
        .buttonStyle(Press(scale: 0.97))
        .accessibilityIdentifier("home.start." + label)
    }

    // 최고 기록: 3칸
    private var bests: some View {
        let sim = store.simBest, race = store.raceBest
        let pace = (store.records(.sim) + store.records(.race)).compactMap(\.runPace).min()
        return HStack(spacing: 8) {
            bestTile("FULL SIM", sim.map { Fm.t($0.total) } ?? "--", sim.map { Fm.dm.string(from: $0.date) } ?? "No record")
            bestTile("RACE", race.map { Fm.t($0.total) } ?? "--", race?.title ?? "No record")
            bestTile("RUN AVG", pace.map { Fm.t($0) } ?? "--", "per km")
        }
    }
    private func bestTile(_ label: String, _ value: String, _ sub: String) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Label8(label, spacing: 0.08)
            Text(value).font(F.num(20)).tracking(-0.4).lineLimit(1).minimumScaleFactor(0.8).padding(.top, 6)
            Text(sub).font(F.t(11)).foregroundStyle(C.text3).lineLimit(1).padding(.top, 2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 14).padding(.horizontal, 12)
        .card8()
    }

    // 최근 3개
    private var recent: [Record] { Array(store.records.sorted { $0.date > $1.date }.prefix(3)) }
    private func recentRow(_ x: Record, last: Bool) -> some View {
        let d = Fm.wdm.string(from: x.date)
        let sub: String = x.mode == .training ? "Training · " + d : x.mode == .race ? "Race · " + d : d
        let title = x.mode == .sim ? "Full Simulation" : x.title
        return Button { r.go(x.mode == .training ? .training : x.mode == .sim ? .sim : .race) } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(F.t(15, .semibold)).lineLimit(1)
                    Text(sub).font(F.t(13)).foregroundStyle(C.text2).lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Text(Fm.t(x.total)).font(F.num(17)).tracking(-0.34).lineLimit(1)
                Chevron8()
            }
            .padding(.horizontal, 18).frame(minHeight: 56)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .rowLine(!last)
    }

    // 친구: 가입 전 카드 / 순위 3줄
    @ViewBuilder private var friends: some View {
        if !store.signedIn {
            HStack(spacing: 12) {
                Text("가입하면 친구와 기록을 비교하고 순위를 볼 수 있어요.")
                    .font(F.t(13)).foregroundStyle(C.text2).lineSpacing(13 * 0.45 - 3)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
                YellowPill(title: "Sign up") { r.toAuth(from: .home) }
            }
            .padding(.vertical, 16).padding(.horizontal, 18)
            .card8()
        } else {
            let rows = Array(store.leaderboard.sorted { $0.t < $1.t }.prefix(3))
            VStack(spacing: 0) {
                if rows.isEmpty {
                    Text("아직 친구 기록이 없어요").font(F.t(13)).foregroundStyle(C.text2)
                        .frame(maxWidth: .infinity).frame(minHeight: 52)
                }
                ForEach(Array(rows.enumerated()), id: \.element.id) { i, x in
                    let me = x.nickname == store.settings.nickname
                    HStack(spacing: 12) {
                        Text("\(i + 1)").font(F.num(15)).foregroundStyle(i == 0 ? C.accent : .white).frame(width: 22, alignment: .leading)
                        Text("@" + x.nickname + (me ? " (you)" : "")).font(F.t(15, me ? .semibold : .medium))
                            .foregroundStyle(me ? C.accent : .white).lineLimit(1)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Text(Fm.t(x.t)).font(F.num(17)).tracking(-0.34)
                    }
                    .padding(.horizontal, 18).frame(minHeight: 52)
                    .background(me ? Color(red: 1, green: 230 / 255, blue: 0, opacity: 0.08) : .clear)
                    .rowLine(i < rows.count - 1)
                }
            }
            .card8()
        }
    }

    // 장소 · 13 Sep · 9:00 AM
    private func eventSub(_ ev: RaceEvent) -> String {
        [ev.loc, Fm.dm.string(from: ev.date), Self.hm12(ev.time)].filter { !$0.isEmpty }.joined(separator: " · ")
    }
    static func hm12(_ t: String) -> String {
        let p = t.split(separator: ":").compactMap { Int($0) }
        guard p.count == 2 else { return "" }
        let h = p[0] % 12 == 0 ? 12 : p[0] % 12
        return "\(h):" + String(format: "%02d", p[1]) + (p[0] >= 12 ? " PM" : " AM")
    }
    private func dday(_ d: Date) -> String {
        let cal = Calendar.current
        let n = cal.dateComponents([.day], from: cal.startOfDay(for: Date()), to: cal.startOfDay(for: d)).day ?? 0
        return n == 0 ? "D-DAY" : n > 0 ? "D-\(n)" : "D+\(-n)"
    }
}
