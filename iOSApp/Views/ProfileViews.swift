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
    /// 가입 프로필 처음부터 (끝나면 next 로. next 가 .nick 이면 닉네임 만들기)
    func startProfile(next: Scr) {
        profileStep = 1; profileEdit = false; profileNext = next
        go(.profileSetup)
    }

    /// 로그인 · 가입 직후: 프로필을 아직 안 했으면 프로필 → (새 계정이면) 닉네임 → 원래 화면
    func afterSignIn(newAccount: Bool) {
        let next: Scr = newAccount ? .nick : authReturn
        if Store.shared.settings.profileDone == true {
            // 가입 전에 이 기기에서 프로필을 채워 둔 경우 → 서버에도 올림
            Task { await Store.shared.syncPrivate() }
            if newAccount { nickDraft = "" }
            go(next)
        } else {
            startProfile(next: next)
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

// MARK: - 화면

struct ProfileSetupView: View {
    let store = Store.shared
    let r = Router.shared

    @State private var step: Int
    @State private var sex: String?
    @State private var height: Int
    @State private var weight: Int
    /// 키 · 몸무게를 저장할지 (Skip 이면 false)
    @State private var hasBody: Bool
    @State private var year: Int
    @State private var raced: Bool?
    /// 대회 종목: single / doubles / relay · 등급: open / pro · 더블 팀: M / W / X
    @State private var format: String
    @State private var level: String
    @State private var team: String
    /// 건강 앱에서 채운 값이 있음 (안내 한 줄)
    @State private var fromHealth = false

    private static let thisYear: Int = Calendar.current.component(.year, from: Date())
    private static let years: [Int] = Array((1930...(ProfileSetupView.thisYear - 10)).reversed())

    init() {
        let s = Store.shared.settings
        _step = State(initialValue: min(4, max(1, Router.shared.profileStep)))
        _sex = State(initialValue: s.sex)
        _height = State(initialValue: s.heightCm ?? (s.sex == "W" ? 163 : 175))
        _weight = State(initialValue: Int((s.weightKg ?? (s.sex == "W" ? 58 : 75)).rounded()))
        _hasBody = State(initialValue: s.heightCm != nil || s.weightKg != nil)
        _year = State(initialValue: s.birthYear ?? 1990)
        _raced = State(initialValue: s.raced)
        let rd: String = s.raceDivision ?? ""
        _format = State(initialValue: rd == "relay" ? "relay" : rd.hasPrefix("dbl") ? "doubles" : "single")
        _level = State(initialValue: rd.hasPrefix("pro") || rd.hasSuffix("P") ? "pro" : "open")
        _team = State(initialValue: rd == "dblX" ? "X" : rd.hasPrefix("dblW") ? "W" : rd.hasPrefix("dblM") ? "M" : (s.sex ?? "M"))
    }

    private var editing: Bool { r.profileEdit }

    var body: some View {
        Page8(spacing: 10) {
            header
            LargeTitle(text: title, top: 10)
            PageSub(text: sub).padding(.bottom, 10)
            content
            if fromHealth && step <= 3 { Note8(text: "Filled in from Apple Health. Change anything that isn't right.") }
            Spacer(minLength: 0)
            if step == 2 {
                Button { skipBody() } label: {
                    Text("Skip").font(F.t(17, .semibold)).foregroundStyle(C.text2)
                        .frame(maxWidth: .infinity).frame(height: 44).contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("profile.skip")
            }
            // 첫 단계에만: 지금은 안 하고 원래 화면으로 (다시 켤 때 또 묻지 않음)
            if step == 1 && !editing {
                Button { notNow() } label: {
                    Text("Not now").font(F.t(17, .semibold)).foregroundStyle(C.text2)
                        .frame(maxWidth: .infinity).frame(height: 44).contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("profile.notNow")
            }
            YellowButton(enabled: canGo, action: next) { Text((editing ? "Save" : "Continue").l10n) }
                .padding(.bottom, 14)
                .accessibilityIdentifier("profile.next")
        }
        .onAppear { setBack() }
        .onChange(of: step) { _, _ in setBack() }
        .task { await prefill() }
    }

    // MARK: 머리줄 (가입 중: 점 4개 · "1 / 4", 고치는 중: ‹ Profile)

    @ViewBuilder private var header: some View {
        if editing {
            BackLink(label: "Profile") { r.go(.account) }
        } else {
            HStack {
                HStack(spacing: 6) {
                    ForEach(1...4, id: \.self) { n in
                        RoundedRectangle(cornerRadius: 3, style: .continuous)
                            .fill(n == step ? C.accent : C.control)
                            .frame(width: n == step ? 22 : 6, height: 6)
                    }
                }
                Spacer()
                Text(verbatim: "\(step) / 4").font(F.t(13, .semibold)).tracking(0.1 * 13).foregroundStyle(C.text2).lineLimit(1)
            }
            .frame(height: 44)
        }
    }

    private func setBack() {
        if editing { r.backAction = { Router.shared.go(.account) }; return }
        r.backAction = step > 1 ? { withAnimation(.easeInOut(duration: 0.2)) { step -= 1 } } : nil
    }

    private var title: String {
        switch step {
        case 1: return "Gender"
        case 2: return "Height and weight"
        case 3: return "Birth year"
        default: return "Race experience"
        }
    }

    private var sub: String {
        switch step {
        case 1: return "Sets your default division and lets you compare with athletes in the same category."
        case 2: return "Optional. Only you can see this."
        case 3: return "Used to compare you with your age group. Only you can see your birth year."
        default: return "Have you raced HYROX? We'll set your division to match."
        }
    }

    // MARK: 단계별 내용

    @ViewBuilder private var content: some View {
        switch step {
        case 1: sexCard
        case 2: bodyCard
        case 3: yearCard
        default: raceBlock
        }
    }

    private var sexCard: some View {
        VStack(spacing: 0) {
            choiceRow("Men", on: sex == "M", last: false) { sex = "M"; if raced != true || format == "single" { team = "M" } }
                .accessibilityIdentifier("profile.sex.M")
            choiceRow("Women", on: sex == "W", last: true) { sex = "W"; if raced != true || format == "single" { team = "W" } }
                .accessibilityIdentifier("profile.sex.W")
        }
        .card8()
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

    /// 키 · 몸무게 바퀴 두 개
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

    @ViewBuilder private var raceBlock: some View {
        Seg8(items: [("yes", "Yes"), ("no", "No")], selected: raced == true ? "yes" : raced == false ? "no" : "", height: 34) {
            raced = $0 == "yes"
        }
        .accessibilityIdentifier("profile.raced")
        if raced == true {
            SectionLabel(text: "FORMAT", top: 10)
            Seg8(items: [("single", "Individual"), ("doubles", "Doubles"), ("relay", "Relay")], selected: format, height: 34) {
                format = $0
                if $0 != "doubles" { team = sex ?? "M" }
            }
            if format == "doubles" {
                SectionLabel(text: "TEAM", top: 10)
                Seg8(items: [("M", "Men"), ("W", "Women"), ("X", "Mixed")], selected: team, height: 34) { team = $0 }
            }
            if format != "relay" && !(format == "doubles" && team == "X") {
                SectionLabel(text: "CATEGORY", top: 10)
                Seg8(items: [("open", "Open"), ("pro", "Pro")], selected: level, height: 34) { level = $0 }
            }
            HStack {
                Text("Division").font(F.t(15)).foregroundStyle(C.text2)
                Spacer()
                Text(ProfileText.race(true, raceKey).l10n).font(F.t(15, .semibold))
            }
            .padding(.vertical, 14).padding(.horizontal, 18)
            .card8()
            .padding(.top, 6)
        }
    }

    /// 고른 대회 종목 → Division 키 (Relay 는 "relay")
    private var raceKey: String {
        let w: Bool = (format == "doubles" ? team : (sex ?? "M")) == "W"
        let pro: Bool = level == "pro"
        switch format {
        case "relay": return "relay"
        case "doubles":
            if team == "X" { return "dblX" }
            return w ? (pro ? "dblWP" : "dblW") : (pro ? "dblMP" : "dblM")
        default:
            return w ? (pro ? "proW" : "openW") : (pro ? "proM" : "openM")
        }
    }

    // MARK: 진행

    private var canGo: Bool {
        switch step {
        case 1: return sex != nil
        case 4: return raced != nil
        default: return true
        }
    }

    /// 다음에 하기: 아무것도 저장하지 않고 원래 가려던 화면으로. 다음에 앱을 켤 때 다시 묻지 않음
    private func notNow() {
        if !Demo.enabled { UserDefaults.standard.set(true, forKey: "profileAsked2") }
        if r.profileNext == .nick { r.nickDraft = "" }
        r.go(r.profileNext)
    }

    private func skipBody() {
        hasBody = false
        if editing { save() } else { advance() }
    }

    private func next() {
        if step == 2 { hasBody = true }
        if editing || step == 4 { save() } else { advance() }
    }

    private func advance() {
        withAnimation(.easeInOut(duration: 0.2)) { step += 1 }
    }

    /// 지금까지 고른 값을 저장하고 다음 화면으로
    private func save() {
        var s = store.settings
        switch editing ? step : 0 {
        case 1: s.sex = sex
        case 2: s.heightCm = hasBody ? height : nil; s.weightKg = hasBody ? Double(weight) : nil
        case 3: s.birthYear = year
        case 4: s.raced = raced; s.raceDivision = raced == true ? raceKey : nil
        default:
            // 가입 흐름: 네 단계 모두
            s.sex = sex
            s.heightCm = hasBody ? height : nil
            s.weightKg = hasBody ? Double(weight) : nil
            s.birthYear = year
            s.raced = raced
            s.raceDivision = raced == true ? raceKey : nil
        }
        s.profileDone = true
        store.saveProfile(s)
        if editing { r.go(.account); return }
        if r.profileNext == .nick { r.nickDraft = "" }
        r.go(r.profileNext)
    }

    /// 건강 앱 값으로 비어 있는 칸만 채움 (고치는 중에는 묻지 않음)
    private func prefill() async {
        guard !editing, !Demo.enabled, step == 1 else { return }
        let s = store.settings
        let v = await HealthProfile.read()
        var any = false
        if s.sex == nil, let x = v.sex { sex = x; team = x; any = true }
        if s.heightCm == nil, let x = v.heightCm, (120...220).contains(x) { height = x; any = true }
        if s.weightKg == nil, let x = v.weightKg, (30...200).contains(Int(x)) { weight = Int(x); any = true }
        if s.birthYear == nil, let x = v.birthYear, Self.years.contains(x) { year = x; any = true }
        if any { fromHealth = true }
    }
}

// MARK: - 프로필 화면(Settings › Profile)의 "ABOUT YOU" 카드

struct ProfileAboutCard: View {
    let store = Store.shared
    let r = Router.shared

    var body: some View {
        let s = store.settings
        VStack(spacing: 10) {
            SectionLabel(text: "ABOUT YOU", top: 14)
            VStack(spacing: 0) {
                SettingRow(title: "Gender", value: ProfileText.sex(s.sex)) { r.editProfile(step: 1) }
                    .accessibilityIdentifier("profile.about.sex")
                SettingRow(title: "Height · Weight", value: ProfileText.body(s.heightCm, s.weightKg), numeric: true) { r.editProfile(step: 2) }
                    .accessibilityIdentifier("profile.about.body")
                SettingRow(title: "Birth year", value: s.birthYear.map { String($0) } ?? "Not set", numeric: true) { r.editProfile(step: 3) }
                    .accessibilityIdentifier("profile.about.year")
                SettingRow(title: "Race experience", value: ProfileText.race(s.raced, s.raceDivision), last: true) { r.editProfile(step: 4) }
                    .accessibilityIdentifier("profile.about.race")
            }
            .card8()
            Note8(text: "Only you can see these. They're used for your division and age-group comparisons.")
        }
    }
}
