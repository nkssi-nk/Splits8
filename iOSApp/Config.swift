import Foundation

/// 서버 설정. 계정·친구·순위표에만 쓰입니다. 비워 두면 앱은 계정 없이 동작합니다.
/// Supabase 대시보드 → Project Settings → API 에서 복사해 넣으세요.
enum Config {
    static let supabaseURL = "https://hzkixqmtpillcaqsouwr.supabase.co"          // 예: https://abcdefgh.supabase.co
    static let supabaseAnonKey = "sb_publishable_U2rt8t0plmtMDsE-KLb4Pw_Ku0JLOno"      // 예: eyJhbGciOi...
    /// Instagram 스토리 공유용 (Meta 개발자 앱 ID). 비우면 iOS 공유 창으로 대신 보냅니다.
    static let facebookAppID = ""

    /// 홈페이지 · 개인정보처리방침 (깃허브 페이지)
    static let homeURL = "https://nkssi-nk.github.io/splits8/"
    static let privacyURL = "https://nkssi-nk.github.io/splits8/privacy.html"
    /// 이용약관 (가입 화면 · 설정에서 엶)
    static let termsURL = "https://nkssi-nk.github.io/splits8/terms.html"
    /// 문의 · 신고 받는 메일 (홈페이지·개인정보 처리방침에 공개된 주소와 같음)
    static let supportEmail = "nkssi1981@gmail.com"

    static var hasSupabase: Bool { !supabaseURL.isEmpty && !supabaseAnonKey.isEmpty }
}
