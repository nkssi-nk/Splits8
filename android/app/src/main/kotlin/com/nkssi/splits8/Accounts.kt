package com.nkssi.splits8

/**
 * 계정 서버 (Supabase) 와 이야기하는 곳. 화면은 이 모양만 보고, 실제 서버 연결은 5단계에서 [Accounts.api] 에 넣음.
 * 지금은 [NotConnected] — 모든 요청이 "다음 빌드에" 안내로 끝남. 시험에서는 가짜 서버를 넣어 흐름을 확인.
 */
interface AccountApi {
    /** 서버 연결이 준비됐는지 */
    val ready: Boolean

    /** 이메일로 6자리 코드 보내기 */
    suspend fun sendCode(email: String)

    /** 코드 확인 (틀리면 예외) */
    suspend fun verify(email: String, code: String)

    /** 구글로 로그인. 성공하면 이메일 (취소하면 null) */
    suspend fun signInGoogle(): String?

    /** 닉네임을 쓸 수 있는지 (서버에 물어봄) */
    suspend fun nicknameAvailable(nick: String): Boolean

    /** 닉네임 저장 (이미 있으면 [NicknameTaken]) */
    suspend fun saveNickname(nick: String)

    /** 로그인한 계정의 프로필 읽기 */
    suspend fun loadProfile(): ProfileLoad
}

enum class ProfileLoad { Found, None, Failed }

class NicknameTaken : Exception()
class NotReady : Exception("Sign-in comes in a later Android build.")

/** 서버 연결 전 (5단계 전) */
object NotConnected : AccountApi {
    override val ready = false
    override suspend fun sendCode(email: String) = throw NotReady()
    override suspend fun verify(email: String, code: String) = throw NotReady()
    override suspend fun signInGoogle(): String? = throw NotReady()
    override suspend fun nicknameAvailable(nick: String): Boolean = throw NotReady()
    override suspend fun saveNickname(nick: String) = throw NotReady()
    override suspend fun loadProfile(): ProfileLoad = ProfileLoad.Failed
}

object Accounts {
    var api: AccountApi = NotConnected
}
