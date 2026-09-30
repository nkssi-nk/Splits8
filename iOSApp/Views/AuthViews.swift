import SwiftUI
import AuthenticationServices
import CryptoKit
import PhotosUI

// MARK: - 가입 화면 공통 (padding 0 24, gap 12, 위 44 뒤로 줄)

/// 시안 h1 + 회색 설명 (margin-bottom 8)
private struct AuthHead: View {
    let title: String
    let sub: String
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            LargeTitle(text: title, top: 10)
            PageSub(text: sub).padding(.bottom, 8)
        }
    }
}

/// 버튼 글자 + 진행 중 표시
private struct BusyLabel: View {
    let title: String
    let busy: Bool
    var body: some View {
        ZStack {
            Text(title).opacity(busy ? 0 : 1)
            if busy { ProgressView().tint(.black) }
        }
    }
}

/// 오류 글 (13, 빨강)
private struct ErrorLine: View {
    let text: String
    var body: some View {
        Text(text).font(F.t(13)).foregroundStyle(C.bad)
            .frame(maxWidth: .infinity, alignment: .leading)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 4)
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
        let e = r.email.trimmingCharacters(in: .whitespaces)
        return e.range(of: ".+@.+\\..+", options: .regularExpression) != nil
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
        Page8(spacing: 12) {
            BackLink(label: backLabel) { r.authMode = "signup"; r.go(r.authReturn == .ob1 ? .splash : r.authReturn) }
            AuthHead(title: r.authMode == "signin" ? "Sign in" : "Create account",
                     sub: r.authMode == "signin" ? "가입한 이메일로 코드를 보내드려요." : "비밀번호 없이 이메일 코드로 가입합니다.")
            emailField
            YellowButton(enabled: emailOK, action: { if !busy { sendCode() } }) {
                BusyLabel(title: "Continue with email", busy: busy)
            }
            .accessibilityIdentifier("auth.email")
            orLine
            appleButton
            if let error { ErrorLine(text: error) }
            Spacer(minLength: 0)
            Text("가입 없이도 혼자 기록은 모두 쓸 수 있어요.\n친구 추가와 순위 비교에만 계정이 필요합니다.")
                .font(F.t(13)).foregroundStyle(C.text3).lineSpacing(13 * 0.5 - 3).multilineTextAlignment(.center)
                .frame(maxWidth: .infinity).padding(.bottom, 14)
        }
    }

    /// radius 14 카드, padding 15×16, 17pt · 이메일 키보드
    private var emailField: some View {
        TextField("", text: $r.email, prompt: Text("you@example.com").foregroundColor(C.text3))
            .font(F.t(17)).foregroundStyle(.white)
            .keyboardType(.emailAddress).textContentType(.emailAddress)
            .textInputAutocapitalization(.never).autocorrectionDisabled()
            .submitLabel(.continue)
            .onSubmit { if emailOK && !busy { sendCode() } }
            .padding(.vertical, 15).padding(.horizontal, 16)
            .card8(14)
            .accessibilityIdentifier("auth.field")
    }

    /// ── or ── (선 rgba 255 0.1, 13 #6E6E73, margin 6 0)
    private var orLine: some View {
        HStack(spacing: 12) {
            Rectangle().fill(Color.white.opacity(0.1)).frame(height: 1)
            Text("or").font(F.t(13)).foregroundStyle(C.text3)
            Rectangle().fill(Color.white.opacity(0.1)).frame(height: 1)
        }
        .padding(.vertical, 6)
    }

    /// 흰 버튼 54, radius 16, 17/600 검정, 사과 17×20, gap 8
    private var appleButton: some View {
        Button { signInApple() } label: {
            HStack(spacing: 8) {
                Glyph("i_apple", 20, .black)
                Text("Sign in with Apple").font(F.t(17, .semibold))
            }
            .foregroundStyle(.black)
            .frame(maxWidth: .infinity).frame(height: 54)
            .background(Color.white, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(Press())
        .accessibilityIdentifier("auth.apple")
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
        if let p = await store.loadProfile(), p.nickname != nil { r.go(r.authReturn) }
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

    private var emailShown: String { r.email.isEmpty ? "you@example.com" : r.email }

    var body: some View {
        Page8(spacing: 12) {
            BackLink(label: "Email") { r.go(.auth) }
            AuthHead(title: "Check your email", sub: "\(emailShown)으로 보낸 6자리 코드를 입력하세요.")
            codeBoxes
            HStack {
                Text(resent ? "다시 보냈어요" : "코드는 10분간 유효합니다").foregroundStyle(C.text3)
                Spacer()
                Button { resend() } label: {
                    Text("Resend").font(F.t(13, .semibold)).foregroundStyle(C.accent)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("code.resend")
            }
            .font(F.t(13))
            .padding(.horizontal, 2)
            if let error { ErrorLine(text: error) }
            Spacer(minLength: 0)
            YellowButton(enabled: r.code.count == 6, action: { verify() }) {
                BusyLabel(title: "Verify", busy: busy)
            }
            .padding(.bottom, 14)
            .accessibilityIdentifier("code.verify")
        }
        .onAppear { focus = true }
    }

    /// 6칸 (60 높이, radius 14, gap 8, 28/600) 뒤에 숨은 입력칸 하나 (숫자 키패드 · oneTimeCode)
    private var codeBoxes: some View {
        ZStack {
            TextField("", text: $r.code)
                .keyboardType(.numberPad).textContentType(.oneTimeCode)
                .focused($focus)
                .foregroundStyle(.clear).tint(.clear)
                .frame(maxWidth: .infinity).frame(height: 60)
                .opacity(0.02)
                .onChange(of: r.code) { _, v in
                    let d = String(v.filter(\.isNumber).prefix(6))
                    if d != v { r.code = d }
                    if d.count == 6 { verify() }
                }
                .accessibilityIdentifier("code.field")
            HStack(spacing: 8) {
                ForEach(0..<6, id: \.self) { i in box(i) }
            }
            .allowsHitTesting(false)
        }
        .contentShape(Rectangle())
        .onTapGesture { focus = true }
    }

    private func box(_ i: Int) -> some View {
        let code = Array(r.code)
        let ch = i < code.count ? String(code[i]) : ""
        let active = i == code.count
        return Text(ch).font(F.num(28))
            .frame(maxWidth: .infinity).frame(height: 60)
            .background(C.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(active ? C.accent : C.cardBorder, lineWidth: active ? 1.5 : 1))
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
                if let p = await store.loadProfile(), p.nickname != nil { r.go(r.authReturn) }
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

    private var ring: Color { nd.isEmpty ? C.cardBorder : ok ? C.good.opacity(0.6) : C.bad.opacity(0.6) }
    private var msgColor: Color { nd.isEmpty ? C.text2 : ok ? C.good : (checking && valid ? C.text2 : C.bad) }

    var body: some View {
        Page8(spacing: 12) {
            Color.clear.frame(height: 44)
            AuthHead(title: "Pick a nickname", sub: "친구가 이 이름으로 나를 찾고, 순위표에 표시됩니다.")
            field
            Text(msg).font(F.t(13, .medium)).foregroundStyle(msgColor).padding(.horizontal, 4)
            Text("영문 소문자·숫자·밑줄(_), 3–16자. 나중에 Settings에서 바꿀 수 있어요.")
                .font(F.t(13)).foregroundStyle(C.text3).padding(.horizontal, 4)
                .fixedSize(horizontal: false, vertical: true)
            if let error { ErrorLine(text: error) }
            Spacer(minLength: 0)
            YellowButton(enabled: ok && !nd.isEmpty, action: { if !busy { save() } }) {
                BusyLabel(title: editing ? "Save" : "Continue", busy: busy)
            }
            .padding(.bottom, 14)
            .accessibilityIdentifier("nick.save")
        }
        .onAppear {
            if let n = store.settings.nickname, r.nickDraft.isEmpty { r.nickDraft = n }
            if editing { Router.shared.backAction = { Router.shared.go(.account) } }
        }
    }

    /// @ · 입력 · 초록 체크 (radius 14, 테두리 상태색)
    private var field: some View {
        HStack(spacing: 0) {
            Text("@").font(F.t(17)).foregroundStyle(C.text3)
            TextField("", text: $r.nickDraft, prompt: Text("nickname").foregroundColor(C.text3))
                .font(F.t(17)).foregroundStyle(.white)
                .keyboardType(.asciiCapable)
                .textInputAutocapitalization(.never).autocorrectionDisabled()
                .submitLabel(.done)
                .onSubmit { if ok && !nd.isEmpty && !busy { save() } }
                .padding(.vertical, 15).padding(.horizontal, 4)
                .onChange(of: r.nickDraft) { _, v in
                    let c = filtered(v)
                    if c != v { r.nickDraft = c; return }
                    check(c)
                }
                .accessibilityIdentifier("nick.field")
            if ok && !nd.isEmpty { Check8(color: C.good, size: 20) }
        }
        .padding(.horizontal, 16)
        .background(C.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(ring, lineWidth: 1))
    }

    /// 영문 소문자·숫자·_ 만, 16자까지
    private func filtered(_ v: String) -> String {
        let allowed = Set("abcdefghijklmnopqrstuvwxyz0123456789_")
        return String(v.lowercased().filter { allowed.contains($0) }.prefix(16))
    }

    private var msg: String {
        if nd.isEmpty { return " " }
        if taken { return "@\(nd) is taken" }
        if !valid { return "3–16자, 영문 소문자·숫자·_만 가능" }
        if checking { return "확인 중…" }
        return "@\(nd) is available"
    }

    /// 입력이 멈추고 0.3초 뒤 서버에서 사용 가능 여부 확인
    private func check(_ n: String) {
        taken = false
        guard n.range(of: "^[a-z0-9_]{3,16}$", options: .regularExpression) != nil, n != store.settings.nickname else {
            checking = false; return
        }
        checking = true
        Task {
            try? await Task.sleep(nanoseconds: 300_000_000)
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
                r.go(editing ? .account : r.authReturn)
            } catch {
                if case SBError.http(409, _) = error { taken = true } else { self.error = error.localizedDescription }
            }
            busy = false
        }
    }
}

// MARK: - I5a 프로필 (위 고정 바: ‹ Settings · Profile)

struct AccountView: View {
    let store = Store.shared
    let r = Router.shared
    @State private var pick: PhotosPickerItem?
    @State private var confirmDelete = false

    var body: some View {
        VStack(spacing: 10) {
            photoBlock
            SectionLabel(text: "ATHLETE", top: 14)
            athleteCard
            Note8(text: "체급은 스테이션 무게에, 심박은 존 계산에 쓰여요. 친구에게는 사진·닉네임·체급만 보입니다.")
            if store.signedIn { accountBlock } else { signUpCard }
        }
        .padding(.horizontal, 16)
        .onChange(of: pick) { _, item in
            Task {
                if let item, let d = try? await item.loadTransferable(type: Data.self), let img = UIImage(data: d) {
                    store.setPhoto(Store.square320(img))
                }
                pick = nil
            }
        }
        .confirmationDialog("계정을 삭제할까요?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Delete account", role: .destructive) { Task { await store.deleteAccount() } }
            Button("Cancel", role: .cancel) {}
        } message: { Text("서버의 닉네임·친구·공유 기록이 지워집니다.") }
    }

    private var nick: String { store.settings.nickname ?? "" }
    private var emailShown: String {
        let e = store.settings.email ?? ""
        return e.isEmpty ? "you@example.com" : e
    }
    private var initial: String {
        if store.photo != nil { return "" }
        return store.signedIn ? String(nick.prefix(1)).uppercased() : "?"
    }

    /// 104 원 (40/600) + 카메라 32 (#2C2C2E, 검정 3px 테두리) · Add photo / Remove (15/600) · 이름 20/600 · 설명 13
    private var photoBlock: some View {
        let signed = store.signedIn
        return VStack(spacing: 10) {
            PhotosPicker(selection: $pick, matching: .images) {
                ZStack(alignment: .bottomTrailing) {
                    Avatar8(size: 104, photo: store.photo, initial: initial,
                            bg: signed ? C.accent : C.control, fg: signed ? .black : C.text2, fontSize: 40)
                    Glyph("i_camera", 16, .white)
                        .frame(width: 32, height: 32)
                        .background(C.control, in: Circle())
                        .background(Circle().fill(Color.black).padding(-3))
                }
                .frame(width: 104, height: 104)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("profile.photo")
            HStack(spacing: 16) {
                PhotosPicker(selection: $pick, matching: .images) {
                    Text(store.photo == nil ? "Add photo" : "Change photo").foregroundStyle(C.accent)
                }
                .buttonStyle(.plain)
                if store.photo != nil {
                    Button { store.setPhoto(nil) } label: { Text("Remove").foregroundStyle(C.text2) }
                        .buttonStyle(.plain)
                }
            }
            .font(F.t(15, .semibold))
            VStack(spacing: 2) {
                Text(signed ? "@\(nick)" : "My profile").font(F.t(20, .semibold)).tracking(-0.02 * 20).lineLimit(1)
                Text(signed ? emailShown : "가입 전 · 이 기기에만 저장")
                    .font(F.t(13)).foregroundStyle(C.text2).lineLimit(1)
            }
            .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 6).padding(.bottom, 8)
    }

    private var athleteCard: some View {
        let s = store.settings
        let hr = (s.hrMode == "age" ? "Age \(s.age) · " : "") + "\(s.maxHR) BPM"
        return VStack(spacing: 0) {
            SettingRow(title: "Division", value: store.div.name) { r.sub(.setDiv, from: .account) }
                .accessibilityIdentifier("profile.division")
            SettingRow(title: "Age · Max heart rate", value: hr, numeric: true, last: true) { r.sub(.setHr, from: .account) }
                .accessibilityIdentifier("profile.hr")
        }
        .card8()
    }

    /// 가입 전: 설명 13 회색 + Sign up 노란 알약 (padding 16×18, margin-top 10)
    private var signUpCard: some View {
        HStack(spacing: 12) {
            Text("가입하면 닉네임이 생기고, 이 사진이 친구 목록과 순위표에 표시돼요.")
                .font(F.t(13)).foregroundStyle(C.text2).lineSpacing(13 * 0.45 - 3)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
            YellowPill(title: "Sign up") { r.toAuth(from: .account) }
                .accessibilityIdentifier("profile.signup")
        }
        .padding(.vertical, 16).padding(.horizontal, 18)
        .card8()
        .padding(.top, 10)
    }

    @ViewBuilder private var accountBlock: some View {
        let s = store.settings
        SectionLabel(text: "ACCOUNT", top: 14)
        VStack(spacing: 0) {
            SettingRow(title: "Nickname", value: "@\(nick)") { r.nickDraft = nick; r.go(.nick) }
                .accessibilityIdentifier("profile.nickname")
            HStack(spacing: 12) {
                Text("Sign-in").font(F.t(17)).frame(maxWidth: .infinity, alignment: .leading)
                Text(s.signMethod ?? "Email code").font(F.t(15)).foregroundStyle(C.text2).lineLimit(1)
            }
            .padding(.vertical, 14).padding(.horizontal, 18)
        }
        .card8()

        SectionLabel(text: "WHO CAN SEE MY RECORDS", top: 14)
        Seg8(items: [("friends", "Friends"), ("public", "Public"), ("private", "Only me")], selected: s.visibility, height: 34) {
            store.settings.visibility = $0
            Task { await store.syncProfile() }
        }
        Note8(text: visNote(s.visibility))

        VStack(spacing: 0) {
            Button { Task { await store.signOut() } } label: {
                Text("Sign out").font(F.t(17)).foregroundStyle(.white).frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 14).padding(.horizontal, 18).contentShape(Rectangle())
            }
            .buttonStyle(.plain).rowLine(true)
            .accessibilityIdentifier("profile.signout")
            Button { confirmDelete = true } label: {
                Text("Delete account").font(F.t(17)).foregroundStyle(C.bad).frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 14).padding(.horizontal, 18).contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("profile.delete")
        }
        .card8()
        .padding(.top, 14)
        Note8(text: "계정을 삭제하면 서버의 닉네임·친구·공유 기록이 지워집니다. 이 기기의 기록과 건강 데이터는 남아요.")
    }

    private func visNote(_ v: String) -> String {
        switch v {
        case "public": return "닉네임을 아는 누구나 내 최고 기록을 볼 수 있어요."
        case "private": return "순위표에 나타나지 않고, 기록은 나만 봅니다."
        default: return "친구로 추가된 사람만 내 기록과 순위를 볼 수 있어요."
        }
    }
}
