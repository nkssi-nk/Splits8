// 자동 생성 — 직접 고치지 말 것. android/tools/gen_from_ios.py
// 원본: Widgets/ko.lproj/Localizable.strings (아이폰 위젯)
package com.nkssi.splits8.shared

/** 홈 화면 위젯 한국어 (앱 표보다 먼저 봄) */
object WidgetKo {
    private val map: Map<String, String> = hashMapOf(
        "Add a race" to "대회 추가",
        "Automatic" to "자동",
        "BEST" to "최고",
        "Background" to "바탕",
        "Black" to "검정",
        "CALORIES" to "칼로리",
        "Choose the widget background." to "위젯 바탕색을 골라요.",
        "Count down to race day." to "대회 날까지 남은 날을 보여 줘요.",
        "DAYS" to "일 남음",
        "Days to your next race." to "다음 대회까지 남은 날.",
        "Full Simulation" to "풀 시뮬레이션",
        "GOAL" to "목표",
        "HYROX RACE" to "HYROX 대회",
        "NEXT" to "다음",
        "NEXT RACE" to "다음 대회",
        "Next race" to "다음 대회",
        "RACE" to "대회",
        "RACE DAY" to "대회 날",
        "RUN" to "러닝",
        "Race" to "레이스",
        "Reconnecting…" to "다시 연결 중…",
        "Start your first one" to "첫 운동을 시작해 봐요",
        "THIS WEEK" to "이번 주",
        "TIME" to "시간",
        "TOTAL" to "전체",
        "Theme color" to "테마 색",
        "This week" to "이번 주",
        "Today" to "오늘",
        "Training" to "트레이닝",
        "WORKOUTS" to "운동",
        "White" to "흰색",
        "Workouts, time and calories this week." to "이번 주 운동 횟수 · 시간 · 칼로리.",
        "workouts" to "회 운동",
    )

    /** 위젯 글자: 한국어면 위젯 표 → 앱 표 */
    fun t(key: String): String = if (L10n.isKorean) map[key] ?: L10n.t(key) else L10n.t(key)
}
