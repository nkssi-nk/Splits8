import SwiftUI

// MARK: - 운동 예약 시트 (Phase 2 · m3)
// PhoneRoot 가 Router.planRequest 가 있을 때 시트로 띄움 (배경 #1C1C1E 는 PhoneRoot 에서 지정)

struct PlanSheet: View {
    let request: PlanRequest

    private let store = Store.shared
    private let r = Router.shared

    @State private var mode: Mode
    @State private var programId: String?
    @State private var day: Date
    @State private var time: Date
    @State private var reminder: PlanReminder

    init(request: PlanRequest) {
        self.request = request
        let cal = Calendar.current
        let progs: [Program] = Store.shared.programs
        if let p = request.existing {
            _mode = State(initialValue: p.mode == .sim ? .sim : .training)
            _programId = State(initialValue: p.programId ?? progs.first?.id)
            _day = State(initialValue: p.date)
            _time = State(initialValue: p.date)
            _reminder = State(initialValue: p.reminder)
        } else {
            _mode = State(initialValue: request.mode == .sim ? .sim : .training)
            _programId = State(initialValue: progs.first?.id)
            _day = State(initialValue: request.date)
            // 시간이 0:00 (달력 날짜만) 이면 오전 7시로 시작
            let h: Int = cal.component(.hour, from: request.date)
            let m: Int = cal.component(.minute, from: request.date)
            let start: Date = cal.startOfDay(for: request.date)
            let t: Date = (h == 0 && m == 0)
                ? (cal.date(bySettingHour: 7, minute: 0, second: 0, of: start) ?? request.date)
                : request.date
            _time = State(initialValue: t)
            _reminder = State(initialValue: .dayBefore)
        }
    }

    private var isEdit: Bool { request.existing != nil }
    private var program: Program? { store.programs.first { $0.id == programId } }

    var body: some View {
        VStack(spacing: 0) {
            NavBar3(left: "Cancel", title: isEdit ? "Edit plan" : "Plan workout", right: "Save",
                    onLeft: { close() }, onRight: { save() }, edgeBack: false)
                .padding(.horizontal, 12)
                .padding(.top, 8)
            ScrollView {
                VStack(spacing: 10) {
                    SectionLabel(text: "TYPE", top: 10)
                    typeSeg
                    detailsCard
                    SectionLabel(text: "REMINDER")
                    reminderCard
                    Note8(text: "The first time you turn on a reminder, your iPhone will ask to allow notifications.")
                    if isEdit { deleteButton.padding(.top, 14) }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 30)
            }
            .scrollIndicators(.hidden)
        }
        .foregroundStyle(.white)
        .tint(C.accent)
        .presentationDragIndicator(.visible)
    }

    // MARK: 종류 (Training | Full Sim)

    private var typeSeg: some View {
        Seg8(items: [("training", "Training"), ("sim", "Full Sim")], selected: mode == .sim ? "sim" : "training") { k in
            withAnimation(.easeInOut(duration: 0.2)) { mode = k == "sim" ? .sim : .training }
        }
        .accessibilityIdentifier("plan.type")
    }

    // MARK: Program · Date · Time

    private var detailsCard: some View {
        VStack(spacing: 0) {
            if mode == .training { programRow }
            row(last: false) {
                Text("Date").font(F.t(17))
            } trailing: {
                DatePicker("", selection: $day, displayedComponents: .date)
                    .labelsHidden()
                    .datePickerStyle(.compact)
                    .accessibilityIdentifier("plan.date")
            }
            row(last: true) {
                Text("Time").font(F.t(17))
            } trailing: {
                DatePicker("", selection: $time, displayedComponents: .hourAndMinute)
                    .labelsHidden()
                    .datePickerStyle(.compact)
                    .accessibilityIdentifier("plan.time")
            }
        }
        .card8(14)
    }

    private var programRow: some View {
        row(last: false) {
            Text("Program").font(F.t(17))
        } trailing: {
            Menu {
                ForEach(store.programs) { p in
                    Button {
                        programId = p.id
                    } label: {
                        if p.id == programId { Label(p.name.l10n, systemImage: "checkmark") } else { Text(p.name.l10n) }
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Text((program?.name ?? "Choose").l10n).font(F.t(15)).foregroundStyle(C.text2).lineLimit(1)
                    Chevron8()
                }
                .contentShape(Rectangle())
            }
            .accessibilityIdentifier("plan.program")
        }
    }

    private func row<A: View, B: View>(last: Bool, @ViewBuilder leading: () -> A,
                                       @ViewBuilder trailing: () -> B) -> some View {
        HStack(spacing: 12) {
            leading()
            Spacer(minLength: 0)
            trailing()
        }
        .padding(.horizontal, 18)
        .frame(minHeight: 50)
        .rowLine(!last)
    }

    // MARK: 알림

    private var reminderCard: some View {
        let all: [PlanReminder] = PlanReminder.allCases
        return VStack(spacing: 0) {
            ForEach(Array(all.enumerated()), id: \.element.id) { i, x in
                reminderRow(x, last: i == all.count - 1)
            }
        }
        .card8(14)
    }

    private func reminderRow(_ x: PlanReminder, last: Bool) -> some View {
        Button { reminder = x } label: {
            HStack(spacing: 12) {
                Text(x.label.l10n).font(F.t(17)).frame(maxWidth: .infinity, alignment: .leading)
                if reminder == x { Check8(size: 18) }
            }
            .padding(.horizontal, 18)
            .frame(minHeight: 50)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .rowLine(!last)
        .accessibilityIdentifier("plan.reminder." + x.rawValue)
    }

    // MARK: 삭제

    private var deleteButton: some View {
        Button {
            if let p = request.existing { store.deletePlan(p.id) }
            close()
        } label: {
            Text("Delete plan").font(F.t(17)).foregroundStyle(C.bad)
                .frame(maxWidth: .infinity).frame(height: 50)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .card8(14)
        .accessibilityIdentifier("plan.delete")
    }

    // MARK: 저장

    /// 날짜(day)의 연·월·일 + 시간(time)의 시·분
    private var combinedDate: Date {
        let cal = Calendar.current
        let d: DateComponents = cal.dateComponents([.year, .month, .day], from: day)
        let t: DateComponents = cal.dateComponents([.hour, .minute], from: time)
        var c = DateComponents()
        c.year = d.year
        c.month = d.month
        c.day = d.day
        c.hour = t.hour
        c.minute = t.minute
        return cal.date(from: c) ?? day
    }

    private func save() {
        let isSim: Bool = mode == .sim
        let title: String = isSim ? "Full Simulation" : (program?.name ?? "Training")
        var p = PlannedWorkout(mode: isSim ? .sim : .training,
                               programId: isSim ? nil : programId,
                               title: title,
                               date: combinedDate,
                               reminder: reminder)
        if let old = request.existing { p.id = old.id }
        store.savePlan(p)
        close()
    }

    private func close() {
        r.planRequest = nil
    }
}
