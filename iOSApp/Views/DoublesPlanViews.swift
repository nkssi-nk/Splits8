import SwiftUI

// MARK: - 더블 구간 나누기 시트 (빌드 23) — Race 설정에서 디비전이 더블일 때만 열림. 폰에만 저장, 워치·서버로 안 보냄

struct DoublesPlanSheet: View {
    let store = Store.shared
    @Environment(\.dismiss) private var dismiss
    @State private var plan: DoublesPlan = Store.shared.settings.doublesPlan ?? DoublesPlan()

    var body: some View {
        VStack(spacing: 10) {
            NavBar3(left: "Cancel", title: "Doubles plan", right: "Save",
                    onLeft: { dismiss() }, onRight: save, edgeBack: false)
            ScrollView(showsIndicators: false) {
                VStack(spacing: 10) {
                    Note8(text: "Set how much of each station you take — your partner does the rest. 10% steps.")
                    stationsCard
                    HStack(spacing: 10) { resetButton; shareButton }
                    Note8(text: "In Doubles, you run all 8 runs together. Only stations are split.")
                        .padding(.bottom, 16)
                }
                .padding(.top, 4)
            }
        }
        .padding(.horizontal, 16)
        .background(Color(hex: 0x141414).ignoresSafeArea())
    }

    private func save() {
        // 반반이면 비워 둠 (예전 저장 파일과 같은 모양 유지)
        store.settings.doublesPlan = plan.isDefault ? nil : plan
        dismiss()
    }

    // MARK: 스테이션 8줄

    private var stationsCard: some View {
        VStack(spacing: 0) {
            ForEach(0..<8, id: \.self) { i in
                stationRow(i, last: i == 7)
            }
        }
        .card8()
    }

    /// 아이콘 + 이름 + "나 600 m · 파트너 400 m" + − 60% + 스테퍼 (10% 단위)
    private func stationRow(_ i: Int, last: Bool) -> some View {
        let s = Station.all[i]
        return HStack(spacing: 12) {
            Icon8(s.key, 20, C.accent)
            VStack(alignment: .leading, spacing: 3) {
                Text(s.name).font(F.t(15, .semibold))
                Text(plan.splitText(i)).font(F.t(13)).foregroundStyle(C.text2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Stepper8(value: "\(plan.share(i))%", minWidth: 48, fontSize: 15, button: 28, radius: 8, gap: 6,
                     down: { plan.set(i, plan.share(i) - 10) },
                     up: { plan.set(i, plan.share(i) + 10) })
        }
        .padding(.vertical, 12).padding(.horizontal, 16)
        .rowLine(!last)
        .accessibilityIdentifier("dbl." + s.key)
    }

    // MARK: 버튼

    private var resetButton: some View {
        Button { plan = DoublesPlan() } label: {
            Text("Reset 50:50".l10n).font(F.t(15, .semibold))
                .frame(maxWidth: .infinity).frame(height: 48)
                .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .contentShape(Rectangle())
        }
        .buttonStyle(Press())
        .accessibilityIdentifier("dbl.reset")
    }

    /// 계획을 글로 만들어 iOS 공유 시트로 파트너에게 보내기
    private var shareButton: some View {
        Button { ShareSheet.present([plan.shareText]) } label: {
            Text("Share as text".l10n).font(F.t(15, .semibold)).foregroundStyle(.black)
                .frame(maxWidth: .infinity).frame(height: 48)
                .background(C.accent, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .contentShape(Rectangle())
        }
        .buttonStyle(Press())
        .accessibilityIdentifier("dbl.share")
    }
}
