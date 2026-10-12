package com.nkssi.splits8.shared

import kotlinx.serialization.Serializable

/**
 * 더블에서 스테이션 8개를 파트너와 어떻게 나눌지 적어 두는 계획 (폰에만 저장, 서버로 안 보냄).
 * shares = 경기 순서대로 스테이션마다 내가 맡는 몫(%) 0...100. 기본 50(반반). 러닝은 둘이 같이 뛰어서 나누지 않음.
 */
@Serializable
data class DoublesPlan(val shares: List<Int> = List(8) { 50 }) {

    /** i번째 스테이션에서 내가 맡는 몫(%) — 예전 저장 파일이 짧아도 안전하게 50 */
    fun share(i: Int): Int = shares.getOrNull(i)?.coerceIn(0, 100) ?: 50

    /** 몫(%) 바꾸기 (0...100 으로 자름, 목록이 짧으면 채움) */
    fun set(i: Int, v: Int): DoublesPlan {
        if (i !in 0 until 8) return this
        val s = shares.toMutableList()
        while (s.size < 8) s.add(50)
        s[i] = v.coerceIn(0, 100)
        return copy(shares = s)
    }

    /** 모두 반반인지 (반반이면 저장 안 하고 비워 둠) */
    val isDefault: Boolean get() = (0 until 8).all { share(it) == 50 }

    /** i번째 스테이션에서 내가 하는 양 (m 또는 개) */
    fun mine(i: Int): Int = (amounts.getOrElse(i) { 100 } * share(i) / 100.0).r()

    /** i번째 스테이션에서 파트너가 하는 양 */
    fun partners(i: Int): Int = amounts.getOrElse(i) { 100 } - mine(i)

    /** "나 600 m · 파트너 400 m" / "나 60 · 파트너 40개" */
    fun splitText(i: Int): String =
        if (isReps(i)) L10n.t("You %lld · Partner %lld reps", mine(i), partners(i))
        else L10n.t("You %lld m · Partner %lld m", mine(i), partners(i))

    /** 공유 문자열 한 줄 */
    fun shareLine(i: Int): String =
        if (isReps(i)) L10n.t("me %lld / you %lld reps", mine(i), partners(i))
        else L10n.t("me %lld m / you %lld m", mine(i), partners(i))

    /** 파트너에게 보낼 문자 전체 (지금 앱 언어로) */
    val shareText: String
        get() {
            val lines = mutableListOf(L10n.t("SPLITS8 Doubles plan"))
            for (i in 0 until 8) lines.add("${Station.all[i].name}: ${shareLine(i)}")
            lines.add(L10n.t("Runs: together"))
            return lines.joinToString("\n")
        }

    companion object {
        /** 스테이션별 전체 양 — Ski 1000 · Push 50 · Pull 50 · BBJ 80 · Row 1000 · FC 200 · Lunges 100 (m) · Wall Balls 100 (개) */
        val amounts = listOf(1000, 50, 50, 80, 1000, 200, 100, 100)

        /** 월볼(마지막)만 개수, 나머지는 미터 */
        fun isReps(i: Int) = i == 7
    }
}
