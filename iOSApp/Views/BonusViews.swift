import SwiftUI

// MARK: - HIIT · 러닝 설정 시트 (새 트레이닝 화면 맨 아래 카드 / 저장된 카드 누르면)

struct BonusSheet: View {
    let req: BonusRequest
    private let store = Store.shared
    private let r = Router.shared

    @State private var km: Int
    @State private var indoor: Bool
    /// 82번(빌드 28): 카드 이름 (비우면 기본 이름 "HIIT" · "Run 5K" · "Free run")
    @State private var name: String
    /// 새로 만들 때 쓸 id (저장·아이폰 시작이 같은 id 를 쓰게)
    @State private var fresh: String = String(UUID().uuidString.prefix(6))

    init(req: BonusRequest) {
        self.req = req
        _km = State(initialValue: req.existing?.runKm ?? 5)
        _indoor = State(initialValue: req.existing?.indoor ?? false)
        // 기본 이름 그대로면 칸은 비워 둠 (자리 글자로 기본 이름이 보임)
        let n: String = req.existing?.name ?? ""
        let isDefault: Bool = n == "HIIT" || n == "Free run" || n.hasPrefix("Run ") && n.hasSuffix("K")
        _name = State(initialValue: isDefault ? "" : n)
    }

    /// 지금 거리로 만든 기본 이름
    private var defaultName: String { isHIIT ? "HIIT" : Program.runName(km) }
    private var cleanName: String { String(name.trimmingCharacters(in: .whitespacesAndNewlines).prefix(24)) }

    private var isHIIT: Bool { req.kind == "hiit" }

    /// 지금 고른 값으로 만든 프로그램 (편집이면 같은 id)
    private var program: Program {
        var p: Program
        if isHIIT {
            if let e = req.existing { p = e } else { p = Program.hiit(); p.id = "hiit." + fresh }
        } else {
            p = Program.run(km: km, indoor: indoor, id: req.existing?.id ?? ("run." + fresh))
        }
        p.name = cleanName.isEmpty ? defaultName : cleanName
        return p
    }

    /// 지금 고른 설정과 같은 것이 이미 목록(= 워치 목록)에 있는지
    private var onWatch: Bool {
        if let e = req.existing {
            // 저장된 카드를 연 경우: 값을 바꾸지 않았으면 이미 있음
            return e.name == program.name && (isHIIT || (e.runKm == km && (e.indoor ?? false) == indoor))
        }
        return store.programs.contains { p in
            p.name == program.name && (isHIIT ? p.isHIIT : (p.isRun && p.runKm == km && (p.indoor ?? false) == indoor))
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 10) {
                    Icon8(isHIIT ? "hiit" : "run", 26, tint: .yellow)
                    Text((isHIIT ? "HIIT" : "Running").l10n).font(F.t(F.title3, .semibold))
                    Spacer(minLength: 0)
                    Button { r.bonus = nil } label: {
                        Image(systemName: "xmark").font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(C.text2)
                            .frame(width: 32, height: 32)
                            .background(Color.white.opacity(0.10), in: Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("bonus.close")
                }

                nameField
                if isHIIT { hiitBody } else { runBody }

                // 66번(빌드 25): 이미 워치 목록에 있는 것(같은 설정)이면 저장 버튼 대신 "워치 목록에 있음"
                if onWatch {
                    HStack(spacing: 8) {
                        Check8(color: C.good, size: 18)
                        Text("Already on your watch list").font(F.t(17, .semibold)).foregroundStyle(C.good)
                    }
                    .frame(maxWidth: .infinity).frame(height: 54)
                    .card8(16)
                    .accessibilityIdentifier("bonus.onWatch")
                } else {
                    YellowButton(action: save) {
                        Text((req.existing != nil ? "Save changes" : "Save (add to watch list)").l10n)
                    }
                    .accessibilityIdentifier("bonus.save")
                }

                HStack {
                    if req.existing != nil {
                        Button(role: .destructive) { delete() } label: {
                            Text("Delete").font(F.t(F.sub, .semibold)).foregroundStyle(C.bad)
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("bonus.delete")
                    }
                    Spacer(minLength: 0)
                    StartOnPhoneButton(mode: .training, program: program, before: { saveQuietly(); r.bonus = nil })
                }
            }
            .padding(.horizontal, 20).padding(.top, 22).padding(.bottom, 24)
        }
    }

    // MARK: 이름 (82번)

    private var nameField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label8("NAME")
            TextField(defaultName.l10n, text: $name)
                .font(F.t(17)).textInputAutocapitalization(.words).autocorrectionDisabled()
                .submitLabel(.done)
                .padding(.horizontal, 14).frame(height: 46)
                .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .accessibilityIdentifier("bonus.name")
        }
    }

    // MARK: HIIT

    private var hiitBody: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("When a round ends, swipe left or double-tap on the watch → next interval.")
                .font(F.t(F.sub)).fixedSize(horizontal: false, vertical: true)
            Text("Saved: time per round · average heart rate · calories")
                .font(F.t(F.foot)).foregroundStyle(C.text2).fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .card8(16)
    }

    // MARK: 러닝

    private var runBody: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label8("DISTANCE")
            HStack(spacing: 6) {
                ForEach(Program.runChoices, id: \.self) { k in
                    let on: Bool = km == k
                    Button { km = k } label: {
                        Text(k > 0 ? "\(k)K" : "Free".l10n)
                            .font(F.t(F.sub, .semibold)).foregroundStyle(on ? Color.black : Color.white)
                            .lineLimit(1).minimumScaleFactor(0.8)
                            .frame(maxWidth: .infinity).frame(height: 40)
                            .background(on ? C.accent : Color.white.opacity(0.10),
                                        in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("bonus.km.\(k)")
                }
            }
            Label8("PLACE")
            Seg8(items: [("out", "Outdoor (GPS)"), ("in", "Indoor (treadmill)")], selected: indoor ? "in" : "out",
                 height: 36, radius: 10, fontSize: 13) { v in indoor = v == "in" }
            Text("Saved: 1 km splits · pace · heart rate · route map outdoors")
                .font(F.t(F.foot)).foregroundStyle(C.text2).fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .card8(16)
    }

    // MARK: 동작

    private func saveQuietly() {
        store.save(program)
    }

    private func save() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        saveQuietly()
        r.bonus = nil
        // 새로 만들기(트레이닝 만들기 화면)에서 왔으면 트레이닝 목록으로
        if req.existing == nil && r.scr == .builder {
            r.editId = nil
            r.go(.training)
        }
    }

    private func delete() {
        if let p = req.existing { store.deleteProgram(p.id) }
        r.bonus = nil
    }
}
