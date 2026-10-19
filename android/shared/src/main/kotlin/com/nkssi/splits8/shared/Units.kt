package com.nkssi.splits8.shared

// 단위 설정 (kg · km / lb · mi) — 아이폰 빌드 27 Shared/Units.swift 와 같음.
// 화면에 보일 때만 바꿈, 저장 값은 그대로 미터법. 스테이션 거리(50M · 1000M 등)는 하이록스 규정이 미터라 그대로.
// 무게(kg)와 러닝 거리(km)만 바꿈.

object Units {
    const val lbPerKg = 2.20462
    const val mPerMile = 1609.344

    /** 페이스 단위 글자: "/KM" 또는 "/MI" */
    fun paceUnit(imperial: Boolean) = if (imperial) "/MI" else "/KM"

    /** 거리 단위 글자: "KM" 또는 "MI" */
    fun distUnit(imperial: Boolean) = if (imperial) "MI" else "KM"

    /** 1 km 당 초 → 1 mi 당 초 (미터법이면 그대로) */
    fun pace(secPerKm: Int, imperial: Boolean): Int =
        if (!imperial) secPerKm else (secPerKm * mPerMile / 1000).r()

    /** 미터 → 보여 줄 거리 숫자 (km 또는 mi) */
    fun distValue(meters: Double, imperial: Boolean): Double = if (imperial) meters / mPerMile else meters / 1000

    /** 미터 → "%.2f" 문자열 (km 또는 mi) */
    fun dist(meters: Double, imperial: Boolean): String = "%.2f".format(java.util.Locale.US, distValue(meters, imperial))

    /** kg → 보여 줄 무게 문자열 ("152" 또는 "335") */
    fun weight(kg: Double, imperial: Boolean): String {
        if (imperial) return (kg * lbPerKg).r().toString()
        if (kg == kotlin.math.floor(kg)) return kg.toInt().toString()
        return kg.toString()
    }

    private val rx = Regex("(\\d+(?:\\.\\d+)?)(\\s?)(KG|kg|Kg|KM|km|Km)(?![A-Za-z])")

    /**
     * 세부 글자를 화면용으로: "50M · 152KG" → "50M · 335LB", "2×24KG" → "2×53LB", "1KM" → "0.62MI".
     * 미터("1000M", "50M")는 그대로. 미터법이면 받은 글자 그대로 돌려줌.
     */
    fun detail(s: String, imperial: Boolean): String {
        if (!imperial || s.isEmpty()) return s
        return rx.replace(s) { m ->
            val v = m.groupValues[1].toDoubleOrNull() ?: return@replace m.value
            val space = m.groupValues[2]
            val unit = m.groupValues[3]
            val lower = unit == unit.lowercase()
            if (unit.uppercase() == "KG") {
                (v * lbPerKg).r().toString() + space + (if (lower) "lb" else "LB")
            } else {
                trimmed(v * 1000 / mPerMile) + space + (if (lower) "mi" else "MI")
            }
        }
    }

    /** 0.62 / 3.11 / 6.2 처럼 소수 둘째 자리까지, 끝의 0 은 뺌 */
    private fun trimmed(v: Double): String {
        var t = "%.2f".format(java.util.Locale.US, v)
        while (t.contains('.') && (t.endsWith('0') || t.endsWith('.'))) t = t.dropLast(1)
        return t
    }
}
