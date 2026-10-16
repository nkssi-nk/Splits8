import SwiftUI
import HealthKit

// MARK: - 빌드 23 가입 프로필 (성별 · 키/몸무게 · 태어난 해 · 대회 경험 → 닉네임)
// 이메일 · Apple 로 처음 가입할 때 닉네임 전에, 이미 로그인해 있던 사람은 업데이트 뒤 앱을 켤 때 한 번.
// 프로필 화면(Settings › Profile)에서 한 항목씩 다시 고칠 수 있음. 값은 이 기기 + 서버의 본인만 보는 표(profile_private)에 저장.

/// 건강 앱에서 키 · 몸무게 · 성별 · 생년월일 읽기 (사용자가 허락한 것만 읽힘)
enum HealthProfile {
    static var readTypes: Set<HKObjectType> {
        var s: Set<HKObjectType> = [HKQuantityType(.height), HKQuantityType(.bodyMass)]
        if let t = HKObjectType.characteristicType(forIdentifier: .biologicalSex) { s.insert(t) }
        if let t = HKObjectType.characteristicType(forIdentifier: .dateOfBirth) { s.insert(t) }
        return s
    }

    struct Values {
        var sex: String? = nil
        var heightCm: Int? = nil
        var weightKg: Double? = nil
        var birthYear: Int? = nil
    }

    /// 처음이면 건강 앱 허락 창이 뜸 (이미 답했으면 바로 읽음). 건강 앱이 없는 기기는 빈 값
    static func read() async -> Values {
        var v = Values()
        guard HKHealthStore.isHealthDataAvailable() else { return v }
        let hs = HKHealthStore()
        try? await hs.requestAuthorization(toShare: [], read: readTypes)
        if let s = try? hs.biologicalSex().biologicalSex {
            v.sex = s == .male ? "M" : s == .female ? "W" : nil
        }
        if let y = (try? hs.dateOfBirthComponents())?.year { v.birthYear = y }
        if let h = await latest(hs, .height, HKUnit.meterUnit(with: .centi)) { v.heightCm = Int(h.rounded()) }
        if let w = await latest(hs, .bodyMass, HKUnit.gramUnit(with: .kilo)) { v.weightKg = w.rounded() }
        return v
    }

    /// 가장 최근 값 하나
    private static func latest(_ hs: HKHealthStore, _ id: HKQuantityTypeIdentifier, _ unit: HKUnit) async -> Double? {
        await withCheckedContinuation { (c: CheckedContinuation<Double?, Never>) in
            let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
            let q = HKSampleQuery(sampleType: HKQuantityType(id), predicate: nil, limit: 1, sortDescriptors: [sort]) { _, samples, _ in
                c.resume(returning: (samples?.first as? HKQuantitySample)?.quantity.doubleValue(for: unit))
            }
            hs.execute(q)
        }
    }
}

/// 프로필 값 ↔ 보여 줄 글자
enum ProfileText {
    static func sex(_ s: String?) -> String {
        switch s {
        case "M": return "Men"
        case "W": return "Women"
        default: return "Not set"
        }
    }

    /// HYROX 나이대 (그해 나이 = 올해 − 태어난 해): 16–24, 25–29 … 65–69, 70+
    static func ageGroup(_ year: Int) -> String {
        let age: Int = Calendar.current.component(.year, from: Date()) - year
        if age < 25 { return "16–24" }
        if age >= 70 { return "70+" }
        let lo: Int = age / 5 * 5
        return "\(lo)–\(lo + 4)"
    }

    static func body(_ h: Int?, _ w: Double?) -> String {
        var parts: [String] = []
        if let h { parts.append("\(h) cm") }
        if let w { parts.append("\(Int(w.rounded())) kg") }
        return parts.isEmpty ? "Not set" : parts.joined(separator: " · ")
    }

    /// 대회 경험 줄: "No" / "Pro Women" / "Relay"
    static func race(_ raced: Bool?, _ div: String?) -> String {
        guard let raced else { return "Not set" }
        guard raced else { return "No" }
        guard let div else { return "Yes" }
        if div == "relay" { return "Relay" }
        return Division.all.first { $0.key == div }?.name ?? "Yes"
    }
}

extension Router {
    /// 가입 프로필 처음부터 (끝나면 next 로). offset = 앞에 닉네임 단계가 있었으면 1 (점이 5개)
    func startProfile(next: Scr, offset: Int = 0) {
        profileStep = 1; profileEdit = false; profileNext = next; profileDotOffset = offset
        go(.profileSetup)
    }

    /// 로그인 · 가입 직후 (빌드 24 순서): 새 계정이면 닉네임 → 프로필 4단계 → 원래 화면
    func afterSignIn(newAccount: Bool) {
        let done: Bool = Store.shared.settings.profileDone == true
        if done {
            // 가입 전에 이 기기에서 프로필을 채워 둔 경우 → 서버에도 올림
            Task { await Store.shared.syncPrivate() }
        }
        if newAccount {
            nickDraft = ""
            profileDotOffset = done ? 0 : 1
            go(.nick)
        } else if done {
            go(authReturn)
        } else {
            startProfile(next: authReturn)
        }
    }

    /// 닉네임을 정한 뒤 (가입 흐름): 프로필을 아직 안 했으면 이어서
    func afterNick() {
        if profileDotOffset == 1 && Store.shared.settings.profileDone != true {
            startProfile(next: authReturn, offset: 1)
        } else {
            profileDotOffset = 0
            go(authReturn)
        }
    }

    /// 프로필 화면에서 한 항목만 고치기 (저장하면 프로필 화면으로)
    func editProfile(step: Int) {
        profileStep = step; profileEdit = true; profileNext = .account
        go(.profileSetup)
    }

    /// 업데이트 전부터 로그인해 있던 사람: 앱을 켤 때 한 번만 묻기 (다른 기기에서 이미 답했으면 서버 값을 가져오고 안 물음)
    @MainActor
    func askProfileIfNeeded() async {
        let store = Store.shared
        guard !Demo.enabled, store.signedIn, store.settings.hasOnboarded, store.settings.profileDone != true else { return }
        // "다음에" 를 눌렀던 사람에게는 앱을 켤 때마다 다시 묻지 않음 (프로필 화면에서 직접 채울 수 있음)
        guard !UserDefaults.standard.bool(forKey: "profileAsked2") else { return }
        await store.loadPrivate()
        guard store.signedIn, store.settings.profileDone != true else { return }
        // 운동 중 · 다른 일 하는 중에는 끼어들지 않음
        guard [Scr.home, .training, .sim, .race, .settings].contains(scr) else { return }
        startProfile(next: scr)
    }
}

// MARK: - 화면 (빌드 24: 대회 경험 → 내 디비전 → 태어난 해 → 키 · 몸무게)
// 새 계정은 닉네임이 1단계라 점이 5개(닉네임 화면 = 1 / 5), 닉네임이 이미 있으면 4개.
// 모든 단계에 Skip — 누르면 "나중에 설정 › 프로필에서 언제든" 안내가 잠깐 뜨고 다음으로.

struct ProfileSetupView: View {
    let store = Store.shared
    let r = Router.shared

    @State private var step: Int
    @State private var raced: Bool?
    /// 최고 완주 시간 (나가 봤어요 일 때, 선택)
    @State private var hasBest: Bool
    @State private var bestH: Int
    @State private var bestM: Int
    @State private var bestS: Int
    /// 고른 Division 키 (nil = 아직)
    @State private var division: String?
    /// Doubles Mixed 일 때만 묻는 본인 성별
    @State private var sex: String?
    @State private var year: Int
    @State private var height: Int
    @State private var weight: Int
    @State private var hasBody: Bool
    /// 건너뛴 단계 (저장할 때 그 값은 안 바꿈)
    @State private var skipped: Set<Int> = []
    /// "괜찮아요! 나중에…" 안내
    @State private var toast = false
    /// Skip 을 누른 뒤 다음 단계로 넘어가기 전 (두 번 눌림 막기)
    @State private var skipping = false
    /// 건강 앱에서 채운 값이 있음 (안내 한 줄)
    @State private var fromHealth = false
    /// 빌드 27: 온보딩에서 디비전을 이미 골랐으면 가입 흐름에서 디비전 단계를 건너뜀 (Mixed 는 성별을 물어야 해서 보여 줌)
    @State private var skipDiv: Bool

    /// 빌드 27: 가입 흐름에서 디비전 단계를 건너뛰는지 (프로필 화면에서 고칠 때는 항상 보임)
    static func skipsDivision(_ s: Settings) -> Bool {
        s.divPicked == true && s.division != "dblX"
    }
    /// 가입 흐름 단계 수 (닉네임 제외)
    static func stepCount(_ s: Settings) -> Int { skipsDivision(s) ? 3 : 4 }

    private static let thisYear: Int = Calendar.current.component(.year, from: Date())
    private static let years: [Int] = Array((1930...(ProfileSetupView.thisYear - 10)).reversed())

    init() {
        let s = Store.shared.settings
        _step = State(initialValue: min(4, max(1, Router.shared.profileStep)))
        _raced = State(initialValue: s.raced)
        _hasBest = State(initialValue: s.bestFinish != nil)
        let b: Int = s.bestFinish ?? 5400
        _bestH = State(initialValue: b / 3600)
        _bestM = State(initialValue: b % 3600 / 60)
        _bestS = State(initialValue: b % 60)
        _division = State(initialValue: s.divPicked == true || s.profileDone == true ? s.division : nil)
        _sex = State(initialValue: s.sex)
        _year = State(initialValue: s.birthYear ?? 1990)
        _height = State(initialValue: s.heightCm ?? (s.sex == "W" ? 163 : 175))
        _weight = State(initialValue: Int((s.weightKg ?? (s.sex == "W" ? 58 : 75)).rounded()))
        _hasBody = State(initialValue: s.heightCm != nil || s.weightKg != nil)
        let skip: Bool = !Router.shared.profileEdit && ProfileSetupView.skipsDivision(s)
        _skipDiv = State(initialValue: skip)
        // 건너뛰는 단계에서 시작하라고 하면 다음 단계로
        if skip && Router.shared.profileStep == 2 { _step = State(initialValue: 3) }
    }

    /// 이번 흐름에서 보여 줄 단계 (1 대회 경험 · 2 디비전 · 3 태어난 해 · 4 키/몸무게)
    private var flow: [Int] { skipDiv ? [1, 3, 4] : [1, 2, 3, 4] }
    /// 지금 단계가 흐름에서 몇 번째인지 (1부터)
    private var stepIndex: Int { (flow.firstIndex(of: step) ?? 0) + 1 }

    private var editing: Bool { r.profileEdit }
    /// 점 단계: 새 계정이면 닉네임이 1번이라 하나 밀림
    private var offset: Int { editing ? 0 : r.profileDotOffset }

    var body: some View {
        Page8(spacing: 10) {
            header
            LargeTitle(text: title, top: 10)
            PageSub(text: sub).padding(.bottom, 10)
            content
            if fromHealth && step >= 3 { Note8(text: "Filled in from Apple Health. Change anything that isn't right.") }
            Spacer(minLength: 0)
            if !editing {
                Text("You can change this later in Settings.")
                    .font(F.t(12)).foregroundStyle(C.text3)
                    .frame(maxWidth: .infinity)
                Button { skip() } label: {
                    Text("Skip").font(F.t(17, .semibold)).foregroundStyle(C.text2)
                        .frame(maxWidth: .infinity).frame(height: 44).contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("profile.skip")
            }
            YellowButton(enabled: canGo, action: next) { Text((editing || step == 4 ? (editing ? "Save" : "Done") : "Continue").l10n) }
                .padding(.bottom, 14)
                .accessibilityIdentifier("profile.next")
        }
        .overlay(alignment: .bottom) {
            if toast {
                Text("No problem! You can fill this in anytime from Settings › Profile.")
                    .font(F.t(14, .semibold)).foregroundStyle(.black)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 18).padding(.vertical, 12)
                    .background(C.accent, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .padding(.horizontal, 24).padding(.bottom, 150)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .accessibilityIdentifier("profile.toast")
            }
        }
        .onAppear { setBack() }
        .onChange(of: step) { _, _ in setBack() }
        .task { await prefill() }
    }

    // MARK: 머리줄 (가입 중: 점 · "2 / 5", 고치는 중: ‹ Profile)

    @ViewBuilder private var header: some View {
        if editing {
            BackLink(label: "Profile") { r.go(.account) }
        } else {
            ProfileDots(now: stepIndex + offset, total: flow.count + offset)
        }
    }

    private func setBack() {
        if editing { r.backAction = { Router.shared.go(.account) }; return }
        let i: Int = stepIndex - 1
        guard i > 0, i - 1 < flow.count else { r.backAction = nil; return }
        let prev: Int = flow[i - 1]
        r.backAction = { withAnimation(.easeInOut(duration: 0.2)) { step = prev } }
    }

    private var title: String {
        switch step {
        case 1: return "Race experience"
        case 2: return "My division"
        case 3: return "Birth year"
        default: return "Height and weight"
        }
    }

    private var sub: String {
        switch step {
        case 1: return "Have you raced HYROX before?"
        case 2: return "Weights and record comparisons follow this."
        case 3: return "Used for your max heart rate and age-group comparisons. Only you can see it."
        default: return "Optional. Only you can see this."
        }
    }

    // MARK: 단계별 내용

    @ViewBuilder private var content: some View {
        switch step {
        case 1: raceBlock
        case 2: divisionBlock
        case 3: yearCard
        default: bodyCard
        }
    }

    // 1 · 대회 경험 (+ 나가 봤으면 최고 완주 시간)

    @ViewBuilder private var raceBlock: some View {
        VStack(spacing: 0) {
            choiceRow("Yes, I've raced", on: raced == true, last: false) { raced = true }
                .accessibilityIdentifier("profile.raced.yes")
            choiceRow("Not yet", on: raced == false, last: true) { raced = false }
                .accessibilityIdentifier("profile.raced.no")
        }
        .card8()
        if raced == true {
            VStack(spacing: 0) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Best finish time").font(F.t(17))
                        Text("Optional").font(F.t(13)).foregroundStyle(C.text2)
                    }
                    Spacer()
                    Toggle8(on: $hasBest)
                        .accessibilityIdentifier("profile.best.toggle")
                }
                .padding(.vertical, 14).padding(.horizontal, 18)
                if hasBest {
                    HStack(spacing: 0) {
                        timeWheel($bestH, 0..<4, "h")
                        timeWheel($bestM, 0..<60, "m")
                        timeWheel($bestS, 0..<60, "s")
                    }
                    .frame(height: 150)
                    .overlay(alignment: .top) { Rectangle().fill(C.line).frame(height: 1) }
                }
            }
            .card8()
            .padding(.top, 6)
            if hasBest {
                Note8(text: "We'll use it for your default goal time and split targets.")
            }
        }
    }

    private func timeWheel(_ b: Binding<Int>, _ range: Range<Int>, _ unit: String) -> some View {
        Picker(unit, selection: b) {
            ForEach(range, id: \.self) { v in
                Text(verbatim: unit == "h" ? "\(v) h" : String(format: "%02d %@", v, unit)).font(F.num(20)).tag(v)
            }
        }
        .pickerStyle(.wheel)
        .frame(maxWidth: .infinity)
        .clipped()
    }

    private var bestSec: Int { bestH * 3600 + bestM * 60 + bestS }

    // 2 · 내 디비전 (9개 중 하나 → 성별 · 종목 · 등급 자동. Mixed 만 본인 성별 한 줄 더)

    private static let groups: [(String, [String])] = [
        ("OPEN", ["openM", "openW"]),
        ("PRO", ["proM", "proW"]),
        ("DOUBLES", ["dblM", "dblW", "dblX"]),
        ("DOUBLES PRO", ["dblMP", "dblWP"]),
    ]

    @ViewBuilder private var divisionBlock: some View {
        if raced == false {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "sparkles").font(.system(size: 15, weight: .semibold)).foregroundStyle(C.accent)
                Text("First race? We recommend Doubles (Open) — you share the work with a partner.")
                    .font(F.t(14, .medium)).foregroundStyle(.white)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(C.accent.opacity(0.12), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(C.accent.opacity(0.35), lineWidth: 1))
        }
        ForEach(Self.groups, id: \.0) { g in
            SectionLabel(text: g.0, top: 8)
            VStack(spacing: 0) {
                ForEach(Array(g.1.enumerated()), id: \.element) { i, k in
                    divRow(k, last: i == g.1.count - 1)
                }
            }
            .card8()
        }
        if division == "dblX" {
            SectionLabel(text: "YOUR GENDER", top: 8)
            Seg8(items: [("M", "Men"), ("W", "Women")], selected: sex ?? "", height: 34) { sex = $0 }
                .accessibilityIdentifier("profile.sex")
        }
    }

    private func divRow(_ key: String, last: Bool) -> some View {
        let d: Division = Division.of(key)
        let on: Bool = division == key
        let rec: Bool = raced == false && ["dblM", "dblW", "dblX"].contains(key)
        return Button {
            division = key
            if key != "dblX" { sex = Self.sexOf(key) }
        } label: {
            HStack(spacing: 10) {
                Text(d.name).font(F.t(17, on ? .semibold : .regular)).foregroundStyle(.white)
                if rec {
                    Text("RECOMMENDED").font(F.t(10, .bold)).tracking(0.5).foregroundStyle(.black)
                        .padding(.horizontal, 7).frame(height: 20)
                        .background(C.accent, in: Capsule())
                }
                Spacer()
                if on { Check8(size: 20) }
            }
            .padding(.vertical, 14).padding(.horizontal, 18)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .rowLine(!last)
        .accessibilityIdentifier("profile.div.\(key)")
    }

    /// Division 키 → 성별 (Mixed 는 nil)
    static func sexOf(_ key: String) -> String? {
        if key == "dblX" { return nil }
        return key.hasSuffix("W") || key.hasSuffix("WP") ? "W" : "M"
    }

    // 3 · 태어난 해

    private var yearCard: some View {
        VStack(spacing: 0) {
            Picker("Birth year".l10n, selection: $year) {
                ForEach(Self.years, id: \.self) { y in
                    Text(verbatim: String(y)).font(F.num(22)).tag(y)
                }
            }
            .pickerStyle(.wheel)
            .frame(height: 170)
            .clipped()
            HStack {
                Text("Age group").font(F.t(15)).foregroundStyle(C.text2)
                Spacer()
                Text(verbatim: ProfileText.ageGroup(year)).font(F.num(17))
            }
            .padding(.vertical, 14).padding(.horizontal, 18)
            .overlay(alignment: .top) { Rectangle().fill(C.line).frame(height: 1) }
        }
        .card8()
    }

    // 4 · 키 · 몸무게

    private var bodyCard: some View {
        HStack(spacing: 0) {
            wheel("HEIGHT", unit: "cm", values: Array(120...220), selection: $height)
            Rectangle().fill(C.line).frame(width: 1).padding(.vertical, 18)
            wheel("WEIGHT", unit: "kg", values: Array(30...200), selection: $weight)
        }
        .card8()
    }

    private func wheel(_ label: String, unit: String, values: [Int], selection: Binding<Int>) -> some View {
        VStack(spacing: 0) {
            Label8(label).padding(.top, 14)
            Picker(label.l10n, selection: selection) {
                ForEach(values, id: \.self) { v in
                    Text(verbatim: "\(v) \(unit)").font(F.num(20)).tag(v)
                }
            }
            .pickerStyle(.wheel)
            .frame(height: 160)
            .clipped()
        }
        .frame(maxWidth: .infinity)
    }

    private func choiceRow(_ title: String, on: Bool, last: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Text(title.l10n).font(F.t(17, on ? .semibold : .regular)).foregroundStyle(.white)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if on { Check8(size: 20) }
            }
            .padding(.vertical, 16).padding(.horizontal, 18)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .rowLine(!last)
    }

    // MARK: 진행

    private var canGo: Bool {
        switch step {
        case 1: return raced != nil && !(raced == true && hasBest && bestSec < 30 * 60)
        case 2: return division != nil && !(division == "dblX" && sex == nil)
        default: return true
        }
    }

    /// 건너뛰기: 친절한 안내를 잠깐 띄우고 다음 단계로 (마지막이면 끝)
    private func skip() {
        // 0.5초 안에 두 번 누르면 단계가 두 칸 넘어가지 않게
        guard !skipping else { return }
        skipping = true
        let at: Int = step
        skipped.insert(at)
        if at == 4 { hasBody = false }
        withAnimation(.spring(duration: 0.3)) { toast = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
            withAnimation(.easeOut(duration: 0.25)) { toast = false }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            skipping = false
            guard step == at else { return }
            if at == 4 { save() } else { advance() }
        }
    }

    private func next() {
        skipped.remove(step)
        if step == 4 { hasBody = true }
        if editing || step == 4 { save() } else { advance() }
    }

    private func advance() {
        let i: Int = stepIndex      // 다음 단계의 자리 (0부터 셈)
        let to: Int = i < flow.count ? flow[i] : 4
        withAnimation(.easeInOut(duration: 0.2)) { step = to }
    }

    /// 고른 값을 저장하고 다음 화면으로 (건너뛴 단계 값은 그대로 둠)
    private func save() {
        var s = store.settings
        let steps: [Int] = editing ? [step] : flow.filter { !skipped.contains($0) }
        for st in steps {
            switch st {
            case 1:
                s.raced = raced
                if raced == true && hasBest && bestSec >= 30 * 60 {
                    let fresh: Bool = s.bestFinish != bestSec
                    s.bestFinish = bestSec
                    // 목표 시간을 아직 안 정했으면 최고 기록을 목표 시간 기본값으로 + 구간 목표도 그 시간대 실제 중간값으로
                    if fresh && s.goalTime == Defaults.goalTime {
                        let rox: Int = HyroxBench.roxEach(goal: bestSec, division: division ?? s.division)
                        s.roxGoal = rox
                        s.goals = GoalSplit.split(total: bestSec, style: "balanced", current: s.goals, best: nil,
                                                  division: division ?? s.division, rox: rox)
                        s.goalTime = bestSec
                    }
                } else if raced != true || !hasBest {
                    s.bestFinish = nil
                }
            case 2:
                if let d = division {
                    s.division = d
                    s.divPicked = true
                    s.raceDivision = d
                    s.sex = d == "dblX" ? sex : Self.sexOf(d)
                }
            case 3:
                s.birthYear = year
            default:
                s.heightCm = hasBody ? height : nil
                s.weightKg = hasBody ? Double(weight) : nil
            }
        }
        // 빌드 27: 온보딩에서 고른 디비전으로 성별을 정함 (Mixed 가 아니면 묻지 않음)
        if !editing && skipDiv {
            if let x = Self.sexOf(s.division) { s.sex = x }
            if s.raceDivision == nil { s.raceDivision = s.division }
        }
        s.profileDone = true
        store.saveProfile(s)
        if editing { r.go(.account); return }
        r.profileDotOffset = 0
        r.go(r.profileNext)
    }

    /// 건강 앱 값으로 비어 있는 칸만 채움 (고치는 중에는 묻지 않음)
    private func prefill() async {
        guard !editing, !Demo.enabled, step == 1 else { return }
        let s = store.settings
        let v = await HealthProfile.read()
        var any = false
        if s.sex == nil, let x = v.sex { sex = x }
        if s.heightCm == nil, let x = v.heightCm, (120...220).contains(x) { height = x; any = true }
        if s.weightKg == nil, let x = v.weightKg, (30...200).contains(Int(x)) { weight = Int(x); any = true }
        if s.birthYear == nil, let x = v.birthYear, Self.years.contains(x) { year = x; any = true }
        if any { fromHealth = true }
    }
}

/// 가입 단계 점 (고른 칸만 길게) + "2 / 5"
struct ProfileDots: View {
    let now: Int
    let total: Int
    var body: some View {
        HStack {
            HStack(spacing: 6) {
                ForEach(1...max(1, total), id: \.self) { n in
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(n == now ? C.accent : (n < now ? C.accent.opacity(0.4) : C.control))
                        .frame(width: n == now ? 22 : 6, height: 6)
                }
            }
            Spacer()
            Text(verbatim: "\(now) / \(total)").font(F.t(13, .semibold)).tracking(0.1 * 13).foregroundStyle(C.text2).lineLimit(1)
        }
        .frame(height: 44)
    }
}

// MARK: - 프로필 화면(Settings › Profile)의 "ABOUT YOU" 카드 (가입 순서와 같게)

struct ProfileAboutCard: View {
    let store = Store.shared
    let r = Router.shared

    var body: some View {
        let s = store.settings
        VStack(spacing: 10) {
            SectionLabel(text: "ABOUT YOU", top: 14)
            VStack(spacing: 0) {
                SettingRow(title: "Race experience", value: raceText(s)) { r.editProfile(step: 1) }
                    .accessibilityIdentifier("profile.about.race")
                SettingRow(title: "Division", value: divText(s)) { r.editProfile(step: 2) }
                    .accessibilityIdentifier("profile.division")
                SettingRow(title: "Birth year", value: s.birthYear.map { String($0) } ?? "Not set", numeric: true) { r.editProfile(step: 3) }
                    .accessibilityIdentifier("profile.about.year")
                SettingRow(title: "Height · Weight", value: ProfileText.body(s.heightCm, s.weightKg), numeric: true, last: true) { r.editProfile(step: 4) }
                    .accessibilityIdentifier("profile.about.body")
            }
            .card8()
            Note8(text: "Only you can see these. They're used for your division and age-group comparisons.")
        }
    }

    private func raceText(_ s: Settings) -> String {
        guard let raced = s.raced else { return "Not set".l10n }
        guard raced else { return "Not yet".l10n }
        if let b = s.bestFinish { return "Best".l10n + " " + Fm.t(b) }
        return "Yes".l10n
    }

    private func divText(_ s: Settings) -> String {
        let n: String = s.div.name
        if s.division == "dblX", let x = s.sex { return n + " · " + ProfileText.sex(x).l10n }
        return n
    }
}
