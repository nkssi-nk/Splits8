import SwiftUI

// MARK: - I5 Settings

struct SettingsView: View {
    let store = Store.shared
    let r = Router.shared

    var body: some View {
        let s = store.settings
        let signed = store.signedIn
        VStack(spacing: 10) {
            LargeTitle(text: "Settings")
            Button { r.go(.account) } label: {
                HStack(spacing: 14) {
                    Avatar(photo: store.photo, ini: signed ? (s.nickname ?? "?").prefix(1).uppercased() : "?",
                           size: 44, font: 18, bg: signed ? C.accent : C.control, fg: signed ? .black : C.text2)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(signed ? "@\(s.nickname ?? "")" : "My profile").font(F.t(17, .semibold))
                        Text("\(store.div.name) · 사진·체급·심박\(signed ? "" : " · 가입 전")").font(F.t(12)).foregroundStyle(C.text2)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    Image(systemName: "chevron.right").font(.system(size: 12, weight: .bold)).foregroundStyle(C.chev)
                }
                .padding(.vertical, 14).padding(.horizontal, 18).contentShape(Rectangle())
                .card8()
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("settings.profile")
            .padding(.bottom, 10)

            VStack(spacing: 0) {
                SettingRow(title: "Running", value: RunModes.name(s.runMode)) { r.go(.setRun) }
                SettingRow(title: "Split goals", value: Fm.t(s.goals.reduce(0, +)), numeric: true, last: true) { r.go(.setGoals) }
            }
            .card8()

            SectionLabel(text: "FRIENDS", top: 14)
            VStack(spacing: 0) {
                SettingRow(title: "Friends", value: "\(store.friends.count)" + (store.friend.map { " · \($0.first) selected" } ?? ""), last: true) { r.go(.friends) }
            }
            .card8()

            SectionLabel(text: "DEVICE", top: 14)
            HStack(spacing: 12) {
                Icon8("deviceWatch", 22, .white)
                VStack(alignment: .leading, spacing: 1) {
                    Text("Apple Watch").font(F.t(16))
                    Text(store.watchPaired ? (store.watchInstalled ? "Splits8 installed" : "Paired") : "Not paired")
                        .font(F.t(12)).foregroundStyle(C.text2)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                let on = store.watchPaired && store.watchInstalled
                HStack(spacing: 6) {
                    Circle().fill(on ? C.good : C.text3).frame(width: 6, height: 6)
                    Text(on ? "Connected" : "Not connected")
                }
                .font(F.t(13, .semibold)).foregroundStyle(on ? C.good : C.text3)
            }
            .padding(.vertical, 14).padding(.horizontal, 18)
            .card8()
        }
        .padding(.horizontal, 16)
    }
}

// MARK: - I5a Division

struct SetDivView: View {
    let r = Router.shared
    var body: some View {
        VStack(spacing: 10) {
            BackLink(label: r.subBackLabel) { r.go(r.subFrom) }
            LargeTitle(text: "Division", top: 0)
            DivisionList(checkSize: 18)
            Text("체급을 바꾸면 Training·Full Simulation·Race의 모든 스테이션 무게와 횟수가 함께 바뀝니다. 무게는 시즌마다 조정될 수 있으니 공식 규정을 확인하세요.")
                .font(F.t(12)).foregroundStyle(C.text3).lineSpacing(6)
                .frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 4).padding(.top, 4)
        }
        .padding(.horizontal, 16)
    }
}

// MARK: - Running

struct SetRunView: View {
    let store = Store.shared
    let r = Router.shared
    var body: some View {
        VStack(spacing: 10) {
            BackLink(label: "Settings") { r.go(.settings) }
            LargeTitle(text: "Running", top: 0)
            VStack(spacing: 0) {
                ForEach(Array(RunModes.keys.enumerated()), id: \.offset) { i, k in
                    let on = store.settings.runMode == k
                    Button { store.settings.runMode = k } label: {
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(RunModes.name(k)).font(F.t(16, on ? .semibold : .regular))
                                Text(RunModes.spec(k)).font(F.t(12)).foregroundStyle(C.text3)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            if on { Check8(size: 18) }
                        }
                        .padding(.vertical, 14).padding(.horizontal, 18).contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .rowLine(i < RunModes.keys.count - 1)
                }
            }
            .card8()
            Text("Training과 Full Simulation에 적용됩니다. Race는 현장 러닝이라 GPS·모션을 자동으로 선택합니다. 트레드밀 거리는 기계 표시값으로 보정할 수 있습니다.")
                .font(F.t(12)).foregroundStyle(C.text3).lineSpacing(6)
                .frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 4).padding(.top, 4)
        }
        .padding(.horizontal, 16)
    }
}

// MARK: - I5c Max heart rate

struct SetHrView: View {
    let store = Store.shared
    let r = Router.shared
    var body: some View {
        let s = store.settings
        let mx = s.maxHR
        VStack(spacing: 10) {
            BackLink(label: r.subBackLabel) { r.go(r.subFrom) }
            LargeTitle(text: "Max heart rate", top: 0)
            VStack(spacing: 16) {
                HStack(alignment: .bottom) {
                    VStack(alignment: .leading, spacing: 4) {
                        Label8("MAX HEART RATE")
                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Text("\(mx)").font(F.num(44)).tracking(-1.76)
                            Text("BPM").font(F.t(13, .bold)).tracking(0.78).foregroundStyle(C.hr)
                        }
                    }
                    Spacer()
                    Text(s.hrMode == "age" ? "220 − \(s.age)세" : "직접 입력").font(F.t(12)).foregroundStyle(C.text2)
                }
                Seg8(items: [("age", "By age"), ("manual", "Manual")], selected: s.hrMode) { store.settings.hrMode = $0 }
                HStack {
                    Text(s.hrMode == "age" ? "Age" : "Max heart rate").font(F.t(15))
                    Spacer()
                    Stepper8(value: "\(s.hrMode == "age" ? s.age : s.manualHr)", minWidth: 40, fontSize: 22,
                             down: { bump(-1) }, up: { bump(1) })
                }
            }
            .padding(18)
            .card8()

            SectionLabel(text: "ZONES", top: 14)
            VStack(spacing: 0) {
                ForEach(0..<5, id: \.self) { i in
                    let p = [50, 60, 70, 80, 90][i]
                    HStack(spacing: 12) {
                        RoundedRectangle(cornerRadius: 2).fill(C.zones[i]).frame(width: 4, height: 22)
                        Text("Z\(i + 1)").font(F.t(14, .semibold)).frame(width: 28, alignment: .leading)
                        Text(i == 4 ? "90%+" : "\(p)–\(p + 10)%").font(F.t(13)).foregroundStyle(C.text2)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Text(i == 4 ? "\(Int((Double(mx) * 0.9).rounded()))+"
                                    : "\(Int((Double(mx * p) / 100).rounded()))–\(Int((Double(mx * (p + 10)) / 100).rounded()) - 1)")
                            .font(F.num(16, .medium))
                    }
                    .padding(.vertical, 13).padding(.horizontal, 18)
                    .rowLine(i < 4)
                }
            }
            .card8()
            Text("최대 심박에서 자동 계산됩니다. 워치의 심박 색과 Z1–Z5 표시가 이 범위를 따릅니다.")
                .font(F.t(12)).foregroundStyle(C.text3).lineSpacing(6)
                .frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 4)
        }
        .padding(.horizontal, 16)
    }
    private func bump(_ v: Int) {
        if store.settings.hrMode == "age" { store.settings.age += v } else { store.settings.manualHr += v }
    }
}

// MARK: - I5b Split goals

struct SetGoalsView: View {
    let store = Store.shared
    let r = Router.shared
    var body: some View {
        let g = store.settings.goals
        VStack(spacing: 10) {
            BackLink(label: "Settings") { r.go(.settings) }
            LargeTitle(text: "Split goals", top: 0)
            HStack(spacing: 0) {
                Spacer()
                Text("TOTAL ").font(F.t(11, .semibold)).tracking(0.66).foregroundStyle(C.text2)
                Text(Fm.t(g.reduce(0, +))).font(F.num(11)).tracking(0.66).foregroundStyle(C.accent)
            }
            .padding(.horizontal, 4).padding(.bottom, 6)
            VStack(spacing: 0) {
                Text("Full Simulation과 Race에서 구간별 목표로 쓰입니다. 5초 단위로 조절.")
                    .font(F.t(13)).foregroundStyle(C.text2).lineSpacing(5)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 12).padding(.horizontal, 18).rowLine(true)
                ForEach(0..<16, id: \.self) { i in
                    let run = i % 2 == 0
                    let st = Station.all[i / 2]
                    HStack(spacing: 12) {
                        Icon8(run ? "run" : st.key, 20, tint: run ? .white : .yellow)
                        VStack(alignment: .leading, spacing: 0) {
                            Text(run ? "Run \(i / 2 + 1)" : st.name).font(F.t(15, .medium)).lineLimit(1)
                            Text(run ? "1KM" : st.detail(store.div)).font(F.t(11)).monospacedDigit().foregroundStyle(C.text2)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        Stepper8(value: Fm.t(g.indices.contains(i) ? g[i] : 0), minWidth: 46, fontSize: 16, button: 30, radius: 9, gap: 0,
                                 down: { change(i, -5) }, up: { change(i, 5) })
                    }
                    .padding(.vertical, 9).padding(.leading, 18).padding(.trailing, 12)
                    .rowLine(i < 15)
                }
            }
            .card8()
        }
        .padding(.horizontal, 16)
    }
    private func change(_ i: Int, _ v: Int) {
        var s = store.settings
        guard s.goals.indices.contains(i) else { return }
        s.goals[i] = max(30, s.goals[i] + v)
        s.goalTime = s.goals.reduce(0, +) + 8 * Defaults.roxTarget
        store.settings = s
    }
}

