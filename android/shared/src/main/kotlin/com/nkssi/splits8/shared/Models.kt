package com.nkssi.splits8.shared

// 아이폰 Shared/Models.swift 와 같은 값. 숫자·이름을 바꾸면 순위표가 어긋나므로 아이폰과 함께 바꿀 것.

/** 디비전. 서버에는 key 가 아니라 name("Open Men")으로 저장 */
data class Division(
    val key: String,
    val name: String,
    val push: Int, val pull: Int, val fc: Int, val sb: Int, val wb: Int, val wbReps: Int,
    val wbNote: String,
) {
    /** Push 152 · Pull 103 · FC 2×24 · SB 20 · WB 6KG */
    val spec: String get() = "Push $push · Pull $pull · FC 2×$fc · SB $sb · WB ${wb}KG"

    companion object {
        val all: List<Division> = listOf(
            Division("openM", "Open Men", 152, 103, 24, 20, 6, 100, ""),
            Division("openW", "Open Women", 102, 78, 16, 10, 4, 100, ""),
            Division("proM", "Pro Men", 202, 153, 32, 30, 9, 100, ""),
            Division("proW", "Pro Women", 152, 103, 24, 20, 6, 100, ""),
            Division("dblM", "Doubles Men", 152, 103, 24, 20, 6, 100, " · shared"),
            Division("dblMP", "Doubles Men Pro", 202, 153, 32, 30, 9, 100, " · shared"),
            Division("dblW", "Doubles Women", 102, 78, 16, 10, 4, 100, " · shared"),
            Division("dblWP", "Doubles Women Pro", 152, 103, 24, 20, 6, 100, " · shared"),
            Division("dblX", "Doubles Mixed", 152, 103, 24, 20, 6, 100, " · shared"),
        )

        /** 키("openM") 또는 이름("Open Men") 둘 다 받음 — 기록에는 이름이 저장돼 있음 */
        fun of(keyOrName: String): Division =
            all.firstOrNull { it.key == keyOrName }
                ?: all.firstOrNull { it.name.equals(keyOrName, ignoreCase = true) }
                ?: all[0]
    }
}

/** 스테이션 8개 (순서 고정) */
data class Station(val key: String, val name: String, val target: Int) {
    fun detail(d: Division): String = when (key) {
        "skiErg" -> "1K"
        "sledPush" -> "50M · ${d.push}KG"
        "sledPull" -> "50M · ${d.pull}KG"
        "burpeeBroadJump" -> "80M"
        "row" -> "1K"
        "farmersCarry" -> "200M · 2×${d.fc}KG"
        "sandbagLunges" -> "100M · ${d.sb}KG"
        "wallBalls" -> "${d.wbReps} REPS · ${d.wb}KG${d.wbNote}"
        else -> ""
    }

    companion object {
        val all: List<Station> = listOf(
            Station("skiErg", "SkiErg", 255),
            Station("sledPush", "Sled Push", 190),
            Station("sledPull", "Sled Pull", 270),
            Station("burpeeBroadJump", "BBJ", 250),
            Station("row", "Row", 265),
            Station("farmersCarry", "Farmers Carry", 110),
            Station("sandbagLunges", "Lunges", 270),
            Station("wallBalls", "Wall Balls", 330),
        )

        fun of(key: String): Station? = all.firstOrNull { it.key == key }
    }
}

/** 모드 4개. 서버·백업 파일에는 rawValue("training") 그대로 */
enum class Mode(val raw: String, val title: String, val icon: String, val calendarHex: Long) {
    Training("training", "Training", "modeTraining", 0xFFE600),
    Pft("pft", "PFT", "modePFT", 0xBF5AF2),
    Sim("sim", "Full Simulation", "modeSim", 0x64D2FF),
    Race("race", "Race", "modeRace", 0xFF9F0A);

    companion object {
        fun of(raw: String): Mode? = entries.firstOrNull { it.raw == raw }
    }
}
