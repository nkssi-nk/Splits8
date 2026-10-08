import SwiftUI
import UniformTypeIdentifiers

// MARK: - I5 Settings (위 고정 바: SPLITS8 · Settings)

struct SettingsView: View {
    let store = Store.shared
    let r = Router.shared
    /// 백업 파일 고르기 · 결과 안내 · 로그아웃 확인
    @State private var importing = false
    @State private var backupMessage: String?
    @State private var confirmSignOut = false

    var body: some View {
        VStack(spacing: 10) {
            profileCard
            VStack(spacing: 0) {
                // 구간 목표는 Race 탭의 "Split targets" 한 곳에서만 고침 (빌드 20)
                SettingRow(title: "Running", value: RunModes.name(store.settings.runMode), last: true) { r.go(.setRun) }
                    .accessibilityIdentifier("settings.running")
            }
            .card8()

            SectionLabel(text: "FRIENDS", top: 14)
            VStack(spacing: 0) {
                SettingRow(title: "Friends", value: friendsValue, last: true, badge: store.incoming.count) { r.friendsFrom = .settings; r.go(.friends) }
                    .accessibilityIdentifier("settings.friends")
            }
            .card8()

            SectionLabel(text: "VIBRATION", top: 14)
            VStack(spacing: 0) {
                hapticRow("Heart rate zone change", sub: nil, on: zoneBinding, last: false)
                    .accessibilityIdentifier("settings.hapticZone")
                hapticRow("Behind target pace", sub: "Race · Full Sim", on: paceBinding, last: true)
                    .accessibilityIdentifier("settings.hapticPace")
            }
            .card8()
            Note8(text: "Apple Watch alerts you with a vibration during workouts.")

            languageSection

            Group {
                themeSection

                SectionLabel(text: "DEVICE", top: 14)
                VStack(spacing: 0) {
                    deviceCard
                    hapticRow("Show on iPhone", sub: "Watch workouts, live", on: mirrorBinding, last: true)
                        .accessibilityIdentifier("settings.mirror")
                }
                .card8()
                Note8(text: "Shows your watch workout on this iPhone and on the Lock Screen while you train. You can control it from either device.")

                SectionLabel(text: "ABOUT", top: 14)
                VStack(spacing: 0) {
                    SettingRow(title: "Website", value: "") { openWeb(Config.homeURL) }
                        .accessibilityIdentifier("settings.website")
                    SettingRow(title: "Terms of Use", value: "") { openWeb(Config.termsURL) }
                        .accessibilityIdentifier("settings.terms")
                    SettingRow(title: "Privacy Policy", value: "", last: true) { openWeb(Config.privacyURL) }
                        .accessibilityIdentifier("settings.privacy")
                }
                .card8()
            }

            Group {
                dataSection
                if store.signedIn { signOutSection }
            }
        }
        .padding(.horizontal, 16)
        .fileImporter(isPresented: $importing, allowedContentTypes: [UTType.json]) { result in
            restore(result)
        }
        .alert("Backup", isPresented: Binding(get: { backupMessage != nil }, set: { if !$0 { backupMessage = nil } })) {
            Button("OK", role: .cancel) { backupMessage = nil }
        } message: {
            Text(backupMessage ?? "")
        }
        .confirmationDialog("Sign out?", isPresented: $confirmSignOut, titleVisibility: .visible) {
            Button("Sign out", role: .destructive) { Task { await store.signOut() } }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Your records stay on this iPhone.")
        }
    }

    // MARK: 기록 백업 (파일로 내보내기 · 가져오기)

    private var dataSection: some View {
        VStack(spacing: 10) {
            SectionLabel(text: "DATA", top: 14)
            VStack(spacing: 0) {
                SettingRow(title: "Back up records", value: String(localized: "\(store.records.count) records")) { backUp() }
                    .accessibilityIdentifier("settings.backup")
                SettingRow(title: "Restore from backup", value: "", last: true) { importing = true }
                    .accessibilityIdentifier("settings.restore")
            }
            .card8()
            Note8(text: "Records are kept only on this iPhone and are deleted with the app. Save a backup file to Files or iCloud Drive before you delete the app or change phones.")
        }
    }

    private func backUp() {
        guard let url = store.exportBackup() else {
            backupMessage = String(localized: "Couldn't make the backup file. Please try again.")
            return
        }
        ShareSheet.present([url])
    }

    private func restore(_ result: Result<URL, Error>) {
        guard case .success(let url) = result else { return }
        let scoped: Bool = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        guard let data = try? Data(contentsOf: url) else {
            backupMessage = String(localized: "Couldn't open the file. If it's in iCloud, wait for it to download and try again.")
            return
        }
        guard let added = store.importBackup(data) else {
            backupMessage = String(localized: "This file isn't a SPLITS8 backup.")
            return
        }
        if added.records == 0 && added.programs == 0 {
            backupMessage = String(localized: "Nothing new to restore. Everything in this file is already here.")
        } else {
            backupMessage = String(localized: "Restored \(added.records) records and \(added.programs) trainings.")
        }
    }

    // MARK: 로그아웃 (프로필 화면 맨 아래에도 있지만 찾기 쉽게 설정 맨 아래에도 둠)

    private var signOutSection: some View {
        VStack(spacing: 10) {
            SectionLabel(text: "ACCOUNT", top: 14)
            Button { confirmSignOut = true } label: {
                HStack(spacing: 12) {
                    Text("Sign out").font(F.t(17)).foregroundStyle(.white)
                    Spacer(minLength: 8)
                    Text(verbatim: "@" + (store.settings.nickname ?? "")).font(F.t(15)).foregroundStyle(C.text2).lineLimit(1)
                }
                .padding(.vertical, 14).padding(.horizontal, 18)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .card8()
            .accessibilityIdentifier("settings.signout")
        }
    }

    private func openWeb(_ s: String) {
        if let u = URL(string: s) { UIApplication.shared.open(u) }
    }

    // MARK: 언어 (기본: iPhone 언어를 따름. 고르면 이 앱만 그 언어로 — 앱을 다시 시작하면 적용)

    @AppStorage("appLanguage") private var appLanguage: String = "system"   // system / ko / en
    @State private var askRestart = false

    private var languageSection: some View {
        VStack(spacing: 10) {
            SectionLabel(text: "LANGUAGE", top: 14)
            Seg8(items: [("system", "System"), ("ko", "한국어"), ("en", "English")], selected: appLanguage,
                 height: 34, radius: 11, fontSize: 14) { k in setLanguage(k) }
                .accessibilityIdentifier("settings.language")
            Note8(text: "Follows your iPhone language unless you pick one here.")
        }
        .alert("Restart the app to apply the language.", isPresented: $askRestart) {
            Button("OK", role: .cancel) {}
        }
    }

    // MARK: 테마 (화면 뒤에 비치는 빛의 색. 노란 버튼 · 로고는 그대로) — 워치 화면도 같은 색을 따름

    private var themeSection: some View {
        VStack(spacing: 10) {
            SectionLabel(text: "THEME", top: 14)
            HStack(spacing: 8) {
                Text("Glow color").font(F.t(17)).lineLimit(1).minimumScaleFactor(0.8)
                Spacer(minLength: 4)
                GlowSwatches(selected: store.settings.glow, idPrefix: "settings.theme") { t in
                    store.settings.glow = t
                }
            }
            .padding(.vertical, 8).padding(.horizontal, 18)
            .card8()
            // 고른 색이 이 줄에 은은하게 비침 (설정 화면의 배경 빛은 흰색이라 여기서 바로 보이게)
            .overlay {
                let t: GlowTheme = store.settings.glow
                LinearGradient(stops: [.init(color: Color(hex: t.hex, alpha: 0), location: 0),
                                       .init(color: Color(hex: t.hex, alpha: min(0.3, 0.16 * t.gain)), location: 1)],
                               startPoint: .leading, endPoint: .trailing)
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .allowsHitTesting(false)
            }
            .animation(.easeInOut(duration: 0.3), value: store.settings.glow)
            Note8(text: "Changes the glow behind each screen. Yellow buttons and the logo stay the same.")
        }
    }

    private func setLanguage(_ k: String) {
        guard k != appLanguage else { return }
        appLanguage = k
        if k == "system" {
            UserDefaults.standard.removeObject(forKey: "AppleLanguages")   // iPhone 언어 따르기
        } else {
            UserDefaults.standard.set([k], forKey: "AppleLanguages")
        }
        askRestart = true
    }

    private var zoneBinding: Binding<Bool> {
        Binding(get: { store.settings.hapticZone }, set: { store.settings.hapticZone = $0 })
    }
    private var paceBinding: Binding<Bool> {
        Binding(get: { store.settings.hapticPace }, set: { store.settings.hapticPace = $0 })
    }

    /// 제목 17 · 설명 13 회색 · 토글 (padding 14×18 → 토글 높이 때문에 세로 10)
    private func hapticRow(_ title: String, sub: String?, on: Binding<Bool>, last: Bool) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title.l10n).font(F.t(17)).lineLimit(1)
                if let sub { Text(sub.l10n).font(F.t(13)).foregroundStyle(C.text2).lineLimit(1) }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Toggle8(on: on)
        }
        .padding(.vertical, sub == nil ? 10 : 11).padding(.horizontal, 18)
        .rowLine(!last)
    }

    /// "2" 또는 "2 · Jiho selected"
    private var friendsValue: String {
        let n = "\(store.friends.count)"
        guard let f = store.friend else { return n }
        let first = f.name.split(separator: " ").first.map(String.init) ?? f.name
        return n + " · " + String(localized: "\(first) selected")
    }

    /// 44 원 (17/600) · 제목 17/600 · 설명 13 회색 · › (padding 14×18, gap 14, margin-bottom 10)
    private var profileCard: some View {
        let signed = store.signedIn
        let nick = store.settings.nickname ?? ""
        let ini = store.photo != nil ? "" : (signed ? String(nick.prefix(1)).uppercased() : "?")
        return Button { r.go(.account) } label: {
            HStack(spacing: 14) {
                Avatar8(size: 44, photo: store.photo, initial: ini,
                        bg: signed ? C.accent : C.control, fg: signed ? .black : C.text2, fontSize: 17)
                VStack(alignment: .leading, spacing: 2) {
                    Text(signed ? "@\(nick)" : "My profile").font(F.t(17, .semibold)).foregroundStyle(.white).lineLimit(1)
                    Text(profileSub(signed))
                        .font(F.t(13)).foregroundStyle(C.text2).lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Chevron8()
            }
            .padding(.vertical, 14).padding(.horizontal, 18)
            .contentShape(Rectangle())
            .card8()
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("settings.profile")
        .padding(.bottom, 10)
    }

    /// Open Men (· Not signed up)
    private func profileSub(_ signed: Bool) -> String {
        var parts: [String] = [store.div.name]
        if !signed { parts.append("Not signed up".l10n) }
        return parts.joined(separator: " · ")
    }

    /// 워치 22 · Apple Watch 17 · 설명 13 · ● Connected (13/600 초록) / ● Not connected (회색)
    private var deviceCard: some View {
        let on = store.watchPaired && store.watchInstalled
        let sub = store.watchPaired ? (store.watchInstalled ? "Splits8 installed" : "Splits8 not installed") : "Not paired"
        return HStack(spacing: 12) {
            Glyph("i_device", 22, .white)
            VStack(alignment: .leading, spacing: 1) {
                Text("Apple Watch").font(F.t(17))
                Text(sub.l10n).font(F.t(13)).foregroundStyle(C.text2).lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            HStack(spacing: 6) {
                Circle().fill(on ? C.good : C.text3).frame(width: 6, height: 6)
                Text(on ? "Connected" : "Not connected").lineLimit(1)
            }
            .font(F.t(13, .semibold)).foregroundStyle(on ? C.good : C.text3)
            .fixedSize()
        }
        .padding(.vertical, 14).padding(.horizontal, 18)
        .rowLine(true)
        .accessibilityIdentifier("settings.device")
    }

    /// 52번: 워치 운동을 아이폰 화면 · 잠금 화면에 같이 보여 주기 (기본 켬)
    private var mirrorBinding: Binding<Bool> {
        Binding(get: { store.settings.mirror }, set: { store.settings.mirror = $0 })
    }
}

// MARK: - I5a Division (위 고정 바: ‹ Profile · Division)

struct SetDivView: View {
    var body: some View {
        VStack(spacing: 10) {
            DivisionList(checkSize: 18)
            Note8(text: "Changing your division updates every station weight and rep count in Training, Full Simulation and Race. Weights can change each season, so check the official rules.")
                .padding(.top, 4)
        }
        .padding(.horizontal, 16)
    }
}

// MARK: - Running (위 고정 바: ‹ Settings · Running)

struct SetRunView: View {
    let store = Store.shared

    var body: some View {
        VStack(spacing: 10) {
            VStack(spacing: 0) {
                ForEach(Array(RunModes.keys.enumerated()), id: \.offset) { i, k in
                    row(k, last: i == RunModes.keys.count - 1)
                }
            }
            .card8()
            Note8(text: "Applies to Training and Full Simulation. Race runs are on site, so GPS or motion is chosen automatically. Indoors, distance and pace are estimated from arm motion and may differ from the machine.")
                .padding(.top, 4)
        }
        .padding(.horizontal, 16)
    }

    /// 이름 17 (선택 600) · 설명 13 #6E6E73 · 노란 체크 18
    private func row(_ k: String, last: Bool) -> some View {
        let on = store.settings.runMode == k
        return Button { store.settings.runMode = k } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(RunModes.name(k).l10n).font(F.t(17, on ? .semibold : .regular)).foregroundStyle(.white)
                    Text(RunModes.spec(k).l10n).font(F.t(13)).foregroundStyle(C.text3)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                if on { Check8(size: 18) }
            }
            .padding(.vertical, 14).padding(.horizontal, 18).contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .rowLine(!last)
        .accessibilityIdentifier("run." + k)
    }
}

// MARK: - I5c Max heart rate (위 고정 바: ‹ Profile · Max heart rate)

struct SetHrView: View {
    let store = Store.shared

    var body: some View {
        VStack(spacing: 10) {
            hrCard
            SectionLabel(text: "ZONES", top: 14)
            VStack(spacing: 0) {
                ForEach(0..<5, id: \.self) { i in zoneRow(i) }
            }
            .card8()
            Note8(text: "Calculated automatically from your max heart rate. Heart rate colors and Z1–Z5 on your watch follow these ranges.")
        }
        .padding(.horizontal, 16)
    }

    /// padding 18, gap 16: 188 BPM (44/600 자간 −0.04em · BPM 13/600 빨강) + 220 − 32세 · By age|Manual · Age − 32 +
    private var hrCard: some View {
        let s = store.settings
        let age = s.hrMode == "age"
        return VStack(spacing: 16) {
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 4) {
                    Label8("MAX HEART RATE")
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text("\(s.maxHR)").font(F.num(44)).tracking(-0.04 * 44).lineLimit(1)
                        Text("BPM").font(F.t(13, .semibold)).tracking(0.06 * 13).foregroundStyle(C.hr)
                    }
                }
                Spacer()
                Text(age ? String(localized: "220 − \(s.age) yrs") : "Manual entry".l10n).font(F.t(13)).foregroundStyle(C.text2)
                    .multilineTextAlignment(.trailing)
            }
            Seg8(items: [("age", "By age"), ("manual", "Manual")], selected: s.hrMode) { store.settings.hrMode = $0 }
            HStack {
                Text(age ? "Age" : "Max heart rate").font(F.t(15))
                Spacer()
                Stepper8(value: "\(age ? s.age : s.manualHr)", minWidth: 40, fontSize: 20,
                         down: { bump(-1) }, up: { bump(1) })
            }
        }
        .padding(18)
        .card8()
    }

    /// padding 13×18: 색 막대 4×22 · Z1 (28폭 15/600) · 50–60% (13 회색) · 94–112 (17/500)
    private func zoneRow(_ i: Int) -> some View {
        let mx = Double(store.settings.maxHR)
        let p = [50, 60, 70, 80, 90][i]
        let pct = i == 4 ? "90%+" : "\(p)–\(p + 10)%"
        let lo = Int((mx * Double(p) / 100).rounded())
        let hi = Int((mx * Double(p + 10) / 100).rounded()) - 1
        let range = i == 4 ? "\(Int((mx * 0.9).rounded()))+" : "\(lo)–\(hi)"
        return HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 2).fill(C.zones[i]).frame(width: 4, height: 22)
            Text("Z\(i + 1)").font(F.t(15, .semibold)).frame(width: 28, alignment: .leading)
            Text(pct).font(F.t(13)).foregroundStyle(C.text2)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(range).font(F.num(17, .medium)).lineLimit(1)
        }
        .padding(.vertical, 13).padding(.horizontal, 18)
        .rowLine(i < 4)
    }

    private func bump(_ v: Int) {
        if store.settings.hrMode == "age" { store.settings.age += v } else { store.settings.manualHr += v }
    }
}

// MARK: - I5b Split goals (위 고정 바: ‹ Race · Split goals) — Race 탭의 "Split targets" 에서 들어옴

struct SetGoalsView: View {
    let store = Store.shared
    @State private var goalSheet = false

    var body: some View {
        let g = store.settings.goals
        VStack(spacing: 10) {
            // 총 목표 시간을 넣고 유형을 고르면 아래 16칸이 한 번에 채워짐 (그 뒤 하나씩 고칠 수 있음)
            VStack(spacing: 0) {
                SettingRow(title: "Set from goal time", value: Fm.t(store.settings.goalTime), numeric: true, last: true) { goalSheet = true }
                    .accessibilityIdentifier("goals.auto")
            }
            .card8()
            .padding(.bottom, 4)
            HStack(spacing: 0) {
                Spacer()
                Text("TOTAL ").font(F.t(F.foot, .semibold)).foregroundStyle(C.text2)
                Text(Fm.t(g.reduce(0, +))).font(F.num(F.foot)).foregroundStyle(C.accent)
            }
            .tracking(0.06 * 13)
            .lineLimit(1)
            .padding(.horizontal, 4).padding(.bottom, 6)
            VStack(spacing: 0) {
                Text("Used as split targets in Race, and in Full Simulation when Compare with is set to Goal. Adjust in 5-second steps.")
                    .font(F.t(13)).foregroundStyle(C.text2).lineSpacing(13 * 0.45 - 3)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.vertical, 12).padding(.horizontal, 18).rowLine(true)
                ForEach(0..<16, id: \.self) { i in goalRow(i, g) }
            }
            .card8()
        }
        .padding(.horizontal, 16)
        .sheet(isPresented: $goalSheet) { GoalTimeSheet().presentationDetents([.height(GoalTimeSheet.height)]) }
    }

    /// padding 9 12 9 18, gap 12: 아이콘 20 · 이름 15/500 + 설명 11 · − (30, radius 9) 시간 46폭 17/600 +
    private func goalRow(_ i: Int, _ g: [Int]) -> some View {
        let run = i % 2 == 0
        let st = Station.all[i / 2]
        let t = g.indices.contains(i) ? g[i] : 0
        return HStack(spacing: 12) {
            Icon8(run ? "run" : st.key, 20, tint: run ? .white : .yellow)
            VStack(alignment: .leading, spacing: 0) {
                Text(run ? "Run \(i / 2 + 1)" : st.name).font(F.t(15, .medium)).lineLimit(1)
                Text(run ? "1KM" : st.detail(store.div)).font(F.num(11, .regular)).foregroundStyle(C.text2).lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Stepper8(value: Fm.t(t), minWidth: 46, fontSize: 17, button: 30, radius: 9, gap: 12,
                     down: { change(i, -5) }, up: { change(i, 5) })
        }
        .padding(.vertical, 9).padding(.leading, 18).padding(.trailing, 12)
        .rowLine(i < 15)
    }

    private func change(_ i: Int, _ v: Int) {
        var s = store.settings
        guard s.goals.indices.contains(i) else { return }
        s.goals[i] = max(30, s.goals[i] + v)
        s.goalTime = s.goals.reduce(0, +) + 8 * Defaults.roxTarget
        store.settings = s
    }
}
