import SwiftUI
import AuthenticationServices
import CryptoKit
import PhotosUI

// MARK: - 계정 화면 공통 (padding 24, 뒤로 44)

private struct AuthFrame<Content: View>: View {
    var back: (String, () -> Void)?
    let title: String
    let sub: String
    @ViewBuilder var content: Content
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let back { BackLink(label: back.0, action: back.1) } else { Color.clear.frame(height: 44) }
            Text(title).font(F.t(34, .bold)).tracking(-1.02).padding(.top, 10)
            Text(sub).font(F.t(15)).foregroundStyle(C.text2).lineSpacing(15 * 0.45 - 3).padding(.bottom, 8)
                .fixedSize(horizontal: false, vertical: true)
            content
        }
        .padding(.horizontal, 24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}

/// 큰 버튼 (켜짐: 노랑 / 꺼짐: 흰 0.12)
private struct CTA: View {
    let title: String
    let on: Bool
    var busy = false
    let action: () -> Void
    var body: some View {
        Button(action: { if on && !busy { action() } }) {
            ZStack {
                Text(title).font(F.t(16, .semibold)).foregroundStyle(on ? .black : C.text3).opacity(busy ? 0 : 1)
                if busy { ProgressView().tint(.black) }
            }
            .frame(maxWidth: .infinity).frame(height: 54)
            .background(on ? C.accent : Color.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(Press())
    }
}

// MARK: - I0s 이메일

struct AuthView: View {
    let store = Store.shared
    @Bindable var r = Router.shared
    @State private var busy = false
    @State private var error: String?
    @State private var apple = AppleSignIn()

    private var emailOK: Bool {
        let e = r.email
        guard let at = e.firstIndex(of: "@") else { return false }
        return at > e.startIndex && e[e.index(after: at)...].contains(".")
    }
    private var backLabel: String {
        switch r.authReturn {
        case .ob1, .splash: return "Back"
        case .race: return "Race"
        case .friends: return "Friends"
        case .settings: return "Settings"
        case .account: return "Profile"
        default: return "Back"
        }
    }

    var body: some View {
        AuthFrame(back: (backLabel, { r.go(r.authReturn == .ob1 ? .splash : r.authReturn) }),
                  title: r.authMode == "signin" ? "Sign in" : "Create account",
                  sub: r.authMode == "signin" ? "가입한 이메일로 코드를 보내드려요." : "비밀번호 없이 이메일 코드로 가입합니다.") {
            TextField("", text: $r.email, prompt: Text("you@example.com").foregroundColor(C.text3))
                .font(F.t(17)).keyboardType(.emailAddress).textInputAutocapitalization(.never).autocorrectionDisabled()
                .padding(.vertical, 15).padding(.horizontal, 16).card8(14)
            CTA(title: "Continue with email", on: emailOK, busy: busy) { sendCode() }
            HStack(spacing: 12) {
                Rectangle().fill(Color.white.opacity(0.1)).frame(height: 1)
                Text("or").font(F.t(12)).foregroundStyle(C.text3)
                Rectangle().fill(Color.white.opacity(0.1)).frame(height: 1)
            }
            .padding(.vertical, 6)
            Button { signInApple() } label: {
                HStack(spacing: 8) {
                    Image(systemName: "apple.logo").font(.system(size: 19, weight: .medium))
                    Text("Sign in with Apple").font(F.t(16, .semibold))
                }
                .foregroundStyle(.black)
                .frame(maxWidth: .infinity).frame(height: 54)
                .background(Color.white, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .buttonStyle(Press())
            if let error { Text(error).font(F.t(12)).foregroundStyle(C.bad).padding(.horizontal, 4) }
            Spacer(minLength: 0)
            Text("가입 없이도 혼자 기록은 모두 쓸 수 있어요.\n친구 추가와 순위 비교에만 계정이 필요합니다.")
                .font(F.t(12)).foregroundStyle(C.text3).lineSpacing(6).multilineTextAlignment(.center)
                .frame(maxWidth: .infinity).padding(.bottom, 14)
        }
    }

    private func sendCode() {
        guard store.sb.isConfigured else { error = SBError.notConfigured.errorDescription; return }
        busy = true; error = nil
        Task {
            do { try await store.sb.sendCode(email: r.email.trimmingCharacters(in: .whitespaces)); r.code = ""; r.go(.code) }
            catch { self.error = error.localizedDescription }
            busy = false
        }
    }

    private func signInApple() {
        guard store.sb.isConfigured else { error = SBError.notConfigured.errorDescription; return }
        apple.start { result in
            switch result {
            case .failure(let e): if (e as NSError).code != ASAuthorizationError.canceled.rawValue { self.error = e.localizedDescription }
            case .success((let token, let nonce, let email)):
                busy = true
                Task {
                    do {
                        try await store.sb.signInWithApple(idToken: token, nonce: nonce)
                        store.settings.signMethod = "Apple"
                        store.settings.email = email ?? "Hidden · Apple ID"
                        await finish()
                    } catch { self.error = error.localizedDescription }
                    busy = false
                }
            }
        }
    }

    private func finish() async {
        if let p = await store.loadProfile(), p.nickname != nil { r.go(r.authReturn == .ob1 ? .training : r.authReturn) }
        else { r.nickDraft = ""; r.go(.nick) }
    }
}

/// Sign in with Apple (nonce 포함)
@Observable
final class AppleSignIn: NSObject, ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {
    private var nonce = ""
    private var done: ((Result<(String, String, String?), Error>) -> Void)?

    func start(_ cb: @escaping (Result<(String, String, String?), Error>) -> Void) {
        done = cb
        nonce = (0..<32).map { _ in "abcdefghijklmnopqrstuvwxyz0123456789".randomElement()! }.map(String.init).joined()
        let req = ASAuthorizationAppleIDProvider().createRequest()
        req.requestedScopes = [.email]
        req.nonce = SHA256.hash(data: Data(nonce.utf8)).map { String(format: "%02x", $0) }.joined()
        let c = ASAuthorizationController(authorizationRequests: [req])
        c.delegate = self; c.presentationContextProvider = self
        c.performRequests()
    }
    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization a: ASAuthorization) {
        guard let cred = a.credential as? ASAuthorizationAppleIDCredential, let d = cred.identityToken, let t = String(data: d, encoding: .utf8)
        else { done?(.failure(SBError.bad)); return }
        done?(.success((t, nonce, cred.email)))
    }
    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) { done?(.failure(error)) }
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        UIApplication.shared.connectedScenes.compactMap { ($0 as? UIWindowScene)?.keyWindow }.first ?? ASPresentationAnchor()
    }
}

// MARK: - I0t 코드 6자리

struct CodeView: View {
    let store = Store.shared
    @Bindable var r = Router.shared
    @State private var busy = false
    @State private var error: String?
    @State private var resent = false
    @FocusState private var focus: Bool

    var body: some View {
        let code = r.code
        AuthFrame(back: ("Email", { r.go(.auth) }), title: "Check your email",
                  sub: "\(r.email)으로 보낸 6자리 코드를 입력하세요.") {
            ZStack {
                HStack(spacing: 8) {
                    ForEach(0..<6, id: \.self) { i in
                        let ch = i < code.count ? String(code[code.index(code.startIndex, offsetBy: i)]) : ""
                        let active = i == code.count
                        Text(ch).font(F.num(28))
                            .frame(maxWidth: .infinity).frame(height: 60)
                            .background(C.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .strokeBorder(active ? C.accent : C.cardBorder, lineWidth: active ? 1.5 : 1))
                    }
                }
                TextField("", text: $r.code)
                    .keyboardType(.numberPad).textContentType(.oneTimeCode)
                    .focused($focus)
                    .opacity(0.02)
                    .onChange(of: r.code) { _, v in
                        let d = String(v.filter(\.isNumber).prefix(6))
                        if d != v { r.code = d }
                        if d.count == 6 { verify() }
                    }
            }
            .contentShape(Rectangle())
            .onTapGesture { focus = true }
            HStack {
                Text(resent ? "다시 보냈어요" : "코드는 10분간 유효합니다").font(F.t(13)).foregroundStyle(C.text3)
                Spacer()
                Button("Resend") { resend() }.font(F.t(13, .semibold)).foregroundStyle(C.accent).buttonStyle(.plain)
            }
            .padding(.horizontal, 2)
            if let error { Text(error).font(F.t(12)).foregroundStyle(C.bad).padding(.horizontal, 4) }
            Spacer(minLength: 0)
            CTA(title: "Verify", on: code.count == 6, busy: busy) { verify() }.padding(.bottom, 14)
        }
        .onAppear { focus = true }
    }

    private func resend() {
        Task { try? await store.sb.sendCode(email: r.email); r.code = ""; resent = true }
    }

    private func verify() {
        guard r.code.count == 6, !busy else { return }
        busy = true; error = nil
        Task {
            do {
                try await store.sb.verify(email: r.email, code: r.code)
                store.settings.signMethod = "Email code"
                store.settings.email = r.email
                if let p = await store.loadProfile(), p.nickname != nil { r.go(r.authReturn == .ob1 ? .training : r.authReturn) }
                else { r.nickDraft = ""; r.go(.nick) }
            } catch { self.error = "코드가 맞지 않아요. 다시 확인해 주세요." }
            busy = false
        }
    }
}

// MARK: - I0u 닉네임

struct NickView: View {
    let store = Store.shared
    @Bindable var r = Router.shared
    @State private var taken = false
    @State private var checking = false
    @State private var busy = false
    @State private var error: String?

    private var nd: String { r.nickDraft }
    private var valid: Bool { nd.range(of: "^[a-z0-9_]{3,16}$", options: .regularExpression) != nil }
    private var ok: Bool { valid && !taken && !checking }
    private var editing: Bool { store.settings.nickname != nil }

    var body: some View {
        AuthFrame(back: nil, title: "Pick a nickname", sub: "친구가 이 이름으로 나를 찾고, 순위표에 표시됩니다.") {
            HStack(spacing: 0) {
                Text("@").font(F.t(17)).foregroundStyle(C.text3)
                TextField("", text: $r.nickDraft, prompt: Text("nickname").foregroundColor(C.text3))
                    .font(F.t(17)).textInputAutocapitalization(.never).autocorrectionDisabled()
                    .padding(.vertical, 15).padding(.horizontal, 4)
                    .onChange(of: r.nickDraft) { _, v in
                        let c = String(v.lowercased().filter { $0.isLetter && $0.isASCII || $0.isNumber || $0 == "_" }.prefix(16))
                        if c != v { r.nickDraft = c }
                        check(c)
                    }
                if ok && !nd.isEmpty { Check8(color: C.good) }
            }
            .padding(.horizontal, 16)
            .background(C.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(nd.isEmpty ? C.cardBorder : ok ? C.good.opacity(0.6) : C.bad.opacity(0.6), lineWidth: 1))
            Text(msg).font(F.t(13, .medium)).foregroundStyle(nd.isEmpty ? C.text2 : ok ? C.good : C.bad).padding(.horizontal, 4)
            Text("영문 소문자·숫자·밑줄(_), 3–16자. 나중에 Settings에서 바꿀 수 있어요.")
                .font(F.t(12)).foregroundStyle(C.text3).padding(.horizontal, 4)
            if let error { Text(error).font(F.t(12)).foregroundStyle(C.bad).padding(.horizontal, 4) }
            Spacer(minLength: 0)
            CTA(title: editing ? "Save" : "Continue", on: ok && !nd.isEmpty, busy: busy) { save() }.padding(.bottom, 14)
        }
        .onAppear { if let n = store.settings.nickname, r.nickDraft.isEmpty { r.nickDraft = n } }
    }

    private var msg: String {
        if nd.isEmpty { return " " }
        if taken { return "@\(nd) is taken" }
        if !valid { return "3–16자, 영문 소문자·숫자·_만 가능" }
        if checking { return "확인 중…" }
        return "@\(nd) is available"
    }

    private func check(_ n: String) {
        taken = false
        guard valid, n != store.settings.nickname else { return }
        checking = true
        Task {
            try? await Task.sleep(nanoseconds: 350_000_000)
            guard n == r.nickDraft else { return }
            if let a = try? await store.sb.nicknameAvailable(n) { taken = !a }
            checking = false
        }
    }

    private func save() {
        busy = true; error = nil
        Task {
            do {
                try await store.saveNickname(nd)
                r.go(editing ? .account : (r.authReturn == .ob1 ? .training : r.authReturn))
            } catch {
                if case SBError.http(409, _) = error { taken = true } else { self.error = error.localizedDescription }
            }
            busy = false
        }
    }
}

// MARK: - I5a 프로필

struct AccountView: View {
    let store = Store.shared
    let r = Router.shared
    @State private var pick: PhotosPickerItem?
    @State private var confirmDelete = false

    var body: some View {
        let s = store.settings
        let signed = store.signedIn
        VStack(spacing: 10) {
            BackLink(label: "Settings") { r.go(.settings) }

            VStack(spacing: 10) {
                PhotosPicker(selection: $pick, matching: .images) {
                    ZStack(alignment: .bottomTrailing) {
                        Avatar(photo: store.photo, ini: signed ? (s.nickname ?? "?").prefix(1).uppercased() : "?",
                               size: 104, font: 40, bg: signed ? C.accent : C.control, fg: signed ? .black : C.text2)
                        Image(systemName: "camera.fill").font(.system(size: 14, weight: .medium)).foregroundStyle(.white)
                            .frame(width: 32, height: 32).background(C.control, in: Circle())
                            .overlay(Circle().stroke(Color.black, lineWidth: 3))
                    }
                }
                .buttonStyle(.plain)
                HStack(spacing: 16) {
                    PhotosPicker(selection: $pick, matching: .images) {
                        Text(store.photo == nil ? "Add photo" : "Change photo").foregroundStyle(C.accent)
                    }
                    .buttonStyle(.plain)
                    if store.photo != nil {
                        Button("Remove") { store.setPhoto(nil) }.foregroundStyle(C.text2).buttonStyle(.plain)
                    }
                }
                .font(F.t(14, .semibold))
                VStack(spacing: 2) {
                    Text(signed ? "@\(s.nickname ?? "")" : "My profile").font(F.t(24, .bold)).tracking(-0.48)
                    Text(signed ? (s.email ?? "") : "가입 전 · 이 기기에만 저장").font(F.t(13)).foregroundStyle(C.text2)
                }
            }
            .padding(.top, 6).padding(.bottom, 8)
            .onChange(of: pick) { _, item in
                Task {
                    if let item, let d = try? await item.loadTransferable(type: Data.self), let img = UIImage(data: d) {
                        store.setPhoto(Store.square320(img))
                    }
                    pick = nil
                }
            }

            SectionLabel(text: "ATHLETE", top: 14)
            VStack(spacing: 0) {
                SettingRow(title: "Division", value: store.div.name) { r.sub(.setDiv, from: .account) }
                SettingRow(title: "Age · Max heart rate",
                           value: (s.hrMode == "age" ? "Age \(s.age) · " : "") + "\(s.maxHR) BPM", numeric: true, last: true) { r.sub(.setHr, from: .account) }
            }
            .card8()
            Note("체급은 스테이션 무게에, 심박은 존 계산에 쓰여요. 친구에게는 사진·닉네임·체급만 보입니다.")

            if !signed {
                HStack(spacing: 12) {
                    Text("가입하면 닉네임이 생기고, 이 사진이 친구 목록과 순위표에 표시돼요.")
                        .font(F.t(13)).foregroundStyle(C.text2).lineSpacing(5)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    PillButton("Sign up") { r.toAuth(from: .account) }
                }
                .padding(.vertical, 16).padding(.horizontal, 18)
                .card8()
                .padding(.top, 10)
            } else {
                SectionLabel(text: "ACCOUNT", top: 14)
                VStack(spacing: 0) {
                    SettingRow(title: "Nickname", value: "@\(s.nickname ?? "")") { r.nickDraft = s.nickname ?? ""; r.go(.nick) }
                    HStack(spacing: 12) {
                        Text("Sign-in").font(F.t(16)).frame(maxWidth: .infinity, alignment: .leading)
                        Text(s.signMethod ?? "Email code").font(F.t(15)).foregroundStyle(C.text2)
                    }
                    .padding(.vertical, 14).padding(.horizontal, 18)
                }
                .card8()

                SectionLabel(text: "WHO CAN SEE MY RECORDS", top: 14)
                Seg8(items: [("friends", "Friends"), ("public", "Public"), ("private", "Only me")], selected: s.visibility, height: 34) {
                    store.settings.visibility = $0
                    Task { await store.syncProfile() }
                }
                Note(["friends": "친구로 추가된 사람만 내 기록과 순위를 볼 수 있어요.",
                      "public": "닉네임을 아는 누구나 내 최고 기록을 볼 수 있어요.",
                      "private": "순위표에 나타나지 않고, 기록은 나만 봅니다."][s.visibility] ?? "")

                VStack(spacing: 0) {
                    Button { Task { await store.signOut() } } label: {
                        Text("Sign out").font(F.t(16)).frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 14).padding(.horizontal, 18).contentShape(Rectangle())
                    }
                    .buttonStyle(.plain).rowLine(true)
                    Button { confirmDelete = true } label: {
                        Text("Delete account").font(F.t(16)).foregroundStyle(C.bad).frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 14).padding(.horizontal, 18).contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
                .card8()
                .padding(.top, 14)
                Note("계정을 삭제하면 서버의 닉네임·친구·공유 기록이 지워집니다. 이 기기의 기록과 건강 데이터는 남아요.")
            }
        }
        .padding(.horizontal, 16)
        .confirmationDialog("계정을 삭제할까요?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Delete account", role: .destructive) { Task { await store.deleteAccount() } }
            Button("Cancel", role: .cancel) {}
        } message: { Text("서버의 닉네임·친구·공유 기록이 지워집니다.") }
    }
}

/// 둥근 아바타 (사진 또는 첫 글자)
struct Avatar: View {
    var photo: UIImage?
    var url: String? = nil
    let ini: String
    var size: CGFloat = 34
    var font: CGFloat = 14
    var bg: Color = C.control
    var fg: Color = .white
    var body: some View {
        ZStack {
            Circle().fill(bg)
            if let photo {
                Image(uiImage: photo).resizable().scaledToFill()
            } else if let url, let u = URL(string: url) {
                AsyncImage(url: u) { img in img.resizable().scaledToFill() } placeholder: {
                    Text(ini).font(F.t(font, .bold)).foregroundStyle(fg)
                }
            } else {
                Text(ini).font(F.t(font, .bold)).foregroundStyle(fg)
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
    }
}

/// 작은 회색 설명 글
struct Note: View {
    let text: String
    init(_ t: String) { text = t }
    var body: some View {
        Text(text).font(F.t(12)).foregroundStyle(C.text3).lineSpacing(6)
            .frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 4)
            .fixedSize(horizontal: false, vertical: true)
    }
}

/// 노란 알약 버튼 (Sign up)
struct PillButton: View {
    let title: String
    var height: CGFloat = 34
    let action: () -> Void
    init(_ t: String, height: CGFloat = 34, action: @escaping () -> Void) { title = t; self.height = height; self.action = action }
    var body: some View {
        Button(action: action) {
            Text(title).font(F.t(13, .semibold)).foregroundStyle(.black)
                .padding(.horizontal, 14).frame(height: height)
                .background(C.accent, in: Capsule())
        }
        .buttonStyle(Press(scale: 0.95))
    }
}
