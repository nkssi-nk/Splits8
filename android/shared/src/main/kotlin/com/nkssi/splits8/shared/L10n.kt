package com.nkssi.splits8.shared

/**
 * 번역. 아이폰과 같은 방식: 영어 문장이 열쇠, 한국어 표는 아이폰 Localizable.strings 에서 자동으로 만든 것(L10nKo.kt).
 * 열쇠의 %@ · %lld · %1$@ 같은 자리표시도 아이폰과 같음.
 */
object L10n {
    /** "ko" 또는 "en". 앱이 켜질 때 · 설정에서 바꿀 때 넣음 */
    @Volatile var lang: String = "en"

    val isKorean: Boolean get() = lang.startsWith("ko")

    fun t(key: String, vararg args: Any?): String {
        // 18번: 숫자가 든 이름 ("Round 3" · "Interval timer 40/20") 은 표에 없으면 모양으로 번역
        val tmpl = if (isKorean) (L10nKo.get(key) ?: Bonus.koName(key) ?: key) else key
        return format(tmpl, args)
    }

    /** 스위프트 문자열 자리표시 채우기: %@ %d %ld %lld %u %% 와 순서 지정 %2$@ */
    fun format(tmpl: String, args: Array<out Any?>): String {
        if (!tmpl.contains('%')) return tmpl
        val sb = StringBuilder()
        var i = 0
        var next = 0
        while (i < tmpl.length) {
            val c = tmpl[i]
            if (c != '%' || i + 1 >= tmpl.length) { sb.append(c); i++; continue }
            if (tmpl[i + 1] == '%') { sb.append('%'); i += 2; continue }
            var j = i + 1
            var pos: Int? = null
            val numStart = j
            while (j < tmpl.length && tmpl[j].isDigit()) j++
            if (j < tmpl.length && tmpl[j] == '$' && j > numStart) {
                pos = tmpl.substring(numStart, j).toInt() - 1
                j++
            } else {
                j = numStart
            }
            while (j < tmpl.length && tmpl[j] == 'l') j++
            if (j < tmpl.length && tmpl[j] in "@duif") {
                val idx = pos ?: next++
                sb.append(args.getOrNull(idx)?.toString() ?: "")
                i = j + 1
            } else {
                sb.append(c); i++
            }
        }
        return sb.toString()
    }
}

/** "Wall Balls".l10n — 아이폰의 .l10n 과 같음 */
val String.l10n: String get() = L10n.t(this)
