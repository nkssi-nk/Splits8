package com.nkssi.splits8.shared

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import java.time.Instant

// 아이폰 Shared/Models.swift 를 그대로 옮긴 것.
// 숫자 · 이름 · JSON 칸 이름을 바꾸면 순위표 · 백업 파일 · 공유 링크가 아이폰과 어긋나므로 아이폰과 함께 바꿀 것.

// MARK: 디비전

/** 디비전. 서버 · 기록에는 key 가 아니라 name("Open Men")으로 저장 */
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

// MARK: 스테이션

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

/** 기본 구간 목표 (Split goals 초기값) */
object Defaults {
    val stationGoals = listOf(240, 200, 270, 250, 265, 115, 270, 330)
    val goals: List<Int> get() = (0 until 8).flatMap { listOf(270, stationGoals[it]) }
    const val goalTime = 4320          // 1:12:00
    val runs = listOf("200M", "400M", "800M", "1KM")
    const val roxTarget = 30
}

// MARK: 목표 시간 → 구간별 목표 나누기

/** 총 목표 시간을 러닝 8개 · 종목 8개(16칸)로 나눔. Roxzone 은 빼고 나눔 */
object GoalSplit {
    val styles = listOf("keep", "balanced", "runner", "strong", "best")

    fun name(k: String): String =
        mapOf("keep" to "Current", "balanced" to "Balanced", "runner" to "Runner", "strong" to "Strong", "best" to "My best")[k]
            ?: "Balanced"

    fun note(k: String): String = mapOf(
        "keep" to "Keeps the ratio of your current split goals.",
        "balanced" to "Real race medians at your goal time.",
        "runner" to "Faster runs, a little more time on stations.",
        "strong" to "Faster stations, a little more time on runs.",
        "best" to "Follows the ratio of your best Full Simulation.",
    )[k] ?: ""

    /** 16칸 비율. balanced · runner · strong 은 같은 완주 시간대 실제 중간값에서 출발 */
    fun weights(
        style: String, current: List<Int>, best: List<Int>?,
        total: Int = Defaults.goalTime, division: String = "openM", rox: Int = Defaults.roxTarget,
    ): List<Double> {
        val base = HyroxBench.splits16(total, division, rox).map { it.toDouble() }
        fun tilt(run: Double, st: Double) = base.mapIndexed { i, v -> if (i % 2 == 0) v * run else v * st }
        return when (style) {
            "runner" -> tilt(0.96, 1.0)
            "strong" -> tilt(1.0, 0.96)
            "best" -> if (best != null && best.size == 16 && best.sum() > 0) best.map { it.toDouble() } else base
            "keep" -> if (current.size == 16 && current.sum() > 0) current.map { it.toDouble() } else base
            else -> base
        }
    }

    /** 16칸 목표(초). 5초 단위, 칸마다 최소 30초, 합계 = (총 목표 − Roxzone) 을 5초 단위로 맞춘 값 */
    fun split(
        total: Int, style: String, current: List<Int>, best: List<Int>?,
        division: String = "openM", rox: Int = Defaults.roxTarget,
    ): List<Int> {
        val w = weights(style, current, best, total, division, rox)
        val sumW = maxOf(1.0, w.sum())
        val raw = maxOf(16 * 30, total - 8 * rox)
        val target = (raw / 5.0).r() * 5
        val exact = w.map { it / sumW * target }
        val out = exact.map { maxOf(30, (it / 5).r() * 5) }.toMutableList()
        var diff = target - out.sum()
        var guard = 0
        while (diff != 0 && guard < 200) {
            guard++
            val step = if (diff > 0) 5 else -5
            var pick = -1
            var bestErr = -Double.MAX_VALUE
            for (i in out.indices) {
                if (step < 0 && out[i] - 5 < 30) continue
                val err = (exact[i] - out[i]) * (if (step > 0) 1 else -1)
                if (err > bestErr) { bestErr = err; pick = i }
            }
            if (pick < 0) break
            out[pick] += step
            diff -= step
        }
        return out
    }
}

// MARK: 모드

/** 순서 = 화면에 나오는 순서: Training → PFT → Full Simulation → Race */
@Serializable
enum class Mode(val title: String, val icon: String, val calendarHex: Long) {
    @SerialName("training") Training("Training", "modeTraining", 0xFFE600),
    @SerialName("pft") Pft("PFT", "modePFT", 0xBF5AF2),
    @SerialName("sim") Sim("Full Simulation", "modeSim", 0x64D2FF),
    @SerialName("race") Race("Race", "modeRace", 0xFF9F0A);

    /** 서버 · 백업 파일에 쓰는 이름 ("training") */
    val raw: String get() = name.lowercase()

    companion object {
        fun of(raw: String): Mode? = entries.firstOrNull { it.raw == raw }
    }
}

// MARK: PFT

/** 등급: Gold 22:00 미만 · Silver 22:00–26:00 · Bronze 26:00 초과 (SPLITS8 자체 기준) */
@Serializable
/**
 * 등급: Gold 22:00 미만 · Silver 22:00–26:00 · Bronze 26:00 초과–30:00 · Iron 30:00 초과–35:00 · Unranked 35:00 초과 (남녀 같음).
 * Gold · Silver · Bronze 는 공식 기준 그대로, Iron · Unranked 는 SPLITS8 이 덧붙인 단계 (아이폰 빌드 26).
 */
enum class PFTGrade(val hex1: Long, val hex2: Long, val inkHex: Long) {
    @SerialName("gold") Gold(0xFFE08A, 0xC9981E, 0x201600),
    @SerialName("silver") Silver(0xEEF1F4, 0x9098A1, 0x15181C),
    @SerialName("bronze") Bronze(0xE8A66E, 0x9A5A28, 0x1D0F04),
    @SerialName("iron") Iron(0xA9B6C6, 0x4A5868, 0x0E1318),
    @SerialName("unranked") Unranked(0x6E6E6A, 0x3A3A37, 0xB8B8B2);

    val label: String get() = name.uppercase()
    /** Gold / Silver / Bronze / Iron / Unranked (문장 안에서) */
    val word: String get() = name
    /** 높을수록 좋은 등급 (Gold 4 … Unranked 0) */
    val rank: Int get() = when (this) { Gold -> 4; Silver -> 3; Bronze -> 2; Iron -> 1; Unranked -> 0 }
    /** 한 단계 위 등급 (Gold 는 null) */
    val next: PFTGrade? get() = when (this) { Gold -> null; Silver -> Gold; Bronze -> Silver; Iron -> Bronze; Unranked -> Iron }
}

object PFT {
    const val title = "PFT"
    const val goldLimit = 22 * 60
    /** 이 시간 이하이면 Silver, 넘으면 Bronze */
    const val silverLimit = 26 * 60
    /** 이 시간 이하이면 Bronze, 넘으면 Iron */
    const val bronzeLimit = 30 * 60
    /** 이 시간 이하이면 Iron, 넘으면 Unranked */
    const val ironLimit = 35 * 60

    fun grade(total: Int): PFTGrade = when {
        total < goldLimit -> PFTGrade.Gold
        total <= silverLimit -> PFTGrade.Silver
        total <= bronzeLimit -> PFTGrade.Bronze
        total <= ironLimit -> PFTGrade.Iron
        else -> PFTGrade.Unranked
    }

    /** 그 등급 안에 들려면 이 시간 이하여야 함 (Gold 는 goldLimit - 1) */
    fun limit(g: PFTGrade): Int = when (g) {
        PFTGrade.Gold -> goldLimit - 1
        PFTGrade.Silver -> silverLimit
        PFTGrade.Bronze -> bronzeLimit
        PFTGrade.Iron -> ironLimit
        PFTGrade.Unranked -> Int.MAX_VALUE
    }

    /** 여자 체급은 월볼 4 kg, 그 외 6 kg */
    fun wallBallKg(d: Division): Int = if (d.key in listOf("openW", "proW", "dblW", "dblWP")) 4 else 6

    data class Item(val icon: String, val name: String, val long: String, val kind: SegKind, val target: Int)

    val items: List<Item> = listOf(
        Item("run", "Run", "Run", SegKind.Run, 285),
        Item("burpeeBroadJump", "BBJ", "Burpee Broad Jumps", SegKind.St, 225),
        Item("sandbagLunges", "Lunges", "Lunges", SegKind.St, 195),
        Item("row", "Row", "Row", SegKind.St, 240),
        Item("pushUp", "Push-Ups", "Push-Ups", SegKind.St, 75),
        Item("wallBalls", "Wall Balls", "Wall Balls", SegKind.St, 300),
    )

    fun detail(i: Int, d: Division): String = when (i) {
        0 -> "1KM"
        1 -> "50 REPS"
        2 -> "100 REPS"
        3 -> "1K"
        4 -> "30 REPS"
        else -> "100 REPS · ${wallBallKg(d)}KG"
    }

    fun amount(i: Int, d: Division): String = when (i) {
        0, 3 -> "1000 M"
        1 -> "50"
        2 -> "100"
        4 -> "30"
        else -> "100 · ${wallBallKg(d)} KG"
    }

    /** 구간 순서. targets = 내 최고 기록의 구간 시간 6개 (없으면 기본 목표) */
    fun seq(div: Division, targets: List<Int>? = null): List<Seg> = items.mapIndexed { i, it ->
        val t = if (targets?.size == items.size) targets[i] else it.target
        Seg(it.icon, it.name, detail(i, div), it.kind, t)
    }
}

// MARK: 구간

@Serializable
enum class SegKind {
    @SerialName("run") Run,
    @SerialName("st") St,
    @SerialName("rox") Rox,
}

/** 운동 중 구간 하나 */
@Serializable
data class Seg(
    val icon: String,
    val name: String,
    val detail: String,
    val kind: SegKind,
    val target: Int,
)

/** 러닝 거리 (m) */
fun runMeters(detail: String): Double {
    val s = detail.uppercase()
    if (s.endsWith("KM")) s.dropLast(2).toDoubleOrNull()?.let { return it * 1000 }
    if (s.endsWith("M")) s.dropLast(1).toDoubleOrNull()?.let { return it }
    return 1000.0
}

/** 기본 목표: 러닝은 1KM당 270초 */
fun defaultTarget(icon: String, detail: String): Int {
    if (icon == "run") return (runMeters(detail) / 1000 * 270).r()
    return Station.of(icon)?.target ?: 120
}

// MARK: 트레이닝 프로그램

@Serializable
data class ProgItem(
    /** run 또는 스테이션 key */
    val icon: String,
    /** 러닝 거리 라벨 (200M/400M/800M/1KM) */
    val run: String? = null,
) {
    fun name(): String = if (icon == "run") "Run" else (Station.of(icon)?.name ?: icon)
    fun detail(d: Division): String = if (icon == "run") (run ?: "1KM") else (Station.of(icon)?.detail(d) ?: "")
}

@Serializable
data class Program(
    val id: String,
    val name: String,
    val sets: Int,
    val seq: List<ProgItem>,
    val meta: String? = null,
    val quick: Boolean = false,
    /** null = 하이록스 트레이닝 / "hiit" / "run" */
    val kind: String? = null,
    /** 러닝 총거리 km (0 = 자유) */
    val runKm: Int? = null,
    /** 러닝: 실내(러닝머신) */
    val indoor: Boolean? = null,
) {
    val isHIIT: Boolean get() = kind == "hiit"
    val isRun: Boolean get() = kind == "run"
    val isOpen: Boolean get() = isHIIT || isRun

    /** 카드 설명 */
    val cardMeta: String get() = meta?.l10n ?: watchMeta
    /** 워치 목록 설명 */
    val watchMeta: String get() = if (isOpen) (meta ?: "").l10n else setsText(sets, seq.size)

    companion object {
        /** 만들어 둘 수 있는 트레이닝 개수 (기본 카드 · HIIT · 러닝 카드 포함) */
        const val freeLimit = 5
        val runChoices = listOf(3, 5, 10, 21, 0)

        /** "Run 5K" / "Free run" (번역 키) */
        fun runName(km: Int): String = if (km > 0) "Run ${km}K" else "Free run"

        fun hiit(): Program = Program(
            id = "hiit." + newId().take(6), name = "HIIT", sets = 1, seq = listOf(ProgItem("hiit")),
            meta = "Intervals · heart rate · calories", kind = "hiit",
        )

        fun run(km: Int, indoor: Boolean, id: String? = null): Program = Program(
            id = id ?: ("run." + newId().take(6)), name = runName(km), sets = 1,
            seq = listOf(ProgItem("run", "1KM")),
            meta = if (indoor) "Indoor · 1 km splits" else "Outdoor · 1 km splits",
            kind = "run", runKm = km, indoor = indoor,
        )

        fun presets(): List<Program> = listOf(
            Program(
                "p1", "Sled Intervals", 1,
                listOf(ProgItem("run", "1KM"), ProgItem("sledPush"), ProgItem("run", "1KM"), ProgItem("sledPull")),
                meta = "1 set · about 12 min",
            ),
            Program(
                "p2", "Wall Ball Run", 1,
                listOf(ProgItem("run", "1KM"), ProgItem("wallBalls"), ProgItem("sandbagLunges")),
                meta = "1 set · about 14 min",
            ),
        )

        /** 1 set · 8 segments (번역됨) */
        fun setsText(sets: Int, segs: Int): String =
            if (sets == 1) L10n.t("1 set · %lld segments", segs) else L10n.t("%lld sets · %lld segments", sets, segs)
    }
}

// MARK: 트레이닝 링크 공유

/**
 * 트레이닝 구성을 링크 글자에 담아 보냄 (서버 없이). 아이폰과 같은 글자 → 서로 열 수 있음.
 * 링크 = base + "#" + token,  앱 주소 = splits8://t?d=token,  token = "1." + base64url(JSON)
 * JSON: {"n": 이름, "q": ["run:1KM", "sledPush", …], "s": 세트 수} (칸 이름 순서대로)
 */
object ProgramLink {
    const val base = "https://nkssi-nk.github.io/splits8/t.html"
    const val scheme = "splits8"
    const val maxName = 40
    const val maxSeq = 16
    const val maxSets = 20

    @Serializable
    private data class Payload(val n: String, val q: List<String>, val s: Int)

    fun canShare(p: Program): Boolean = !p.isOpen && p.seq.isNotEmpty()

    fun token(p: Program): String? {
        if (!canShare(p)) return null
        val q = p.seq.take(maxSeq).map { if (it.icon == "run") "run:" + (it.run ?: "1KM") else it.icon }
        // 아이폰 JSONEncoder(sortedKeys) 와 같은 글자: {"n":"…","q":[…],"s":1}, "/" 는 "\/"
        val json = SplitsJson.encodeToString(Payload.serializer(), Payload(p.name.take(maxName), q, p.sets.coerceIn(1, maxSets)))
            .replace("/", "\\/")
        val b64 = java.util.Base64.getEncoder().encodeToString(json.toByteArray(Charsets.UTF_8))
            .replace('+', '-').replace('/', '_').replace("=", "")
        return "1.$b64"
    }

    fun webUrl(p: Program): String? = token(p)?.let { "$base#$it" }

    /** 받은 글자에서 트레이닝을 만듦. 모르는 종목·이상한 값이 하나라도 있으면 null */
    fun program(token: String): Program? {
        if (!token.startsWith("1.") || token.length > 4000) return null
        var b64 = token.drop(2).replace('-', '+').replace('_', '/')
        while (b64.length % 4 != 0) b64 += "="
        val bytes = runCatching { java.util.Base64.getDecoder().decode(b64) }.getOrNull() ?: return null
        val pay = runCatching { SplitsJson.decodeFromString(Payload.serializer(), String(bytes, Charsets.UTF_8)) }.getOrNull()
            ?: return null
        if (pay.q.isEmpty() || pay.q.size > maxSeq || pay.s < 1 || pay.s > maxSets) return null
        val seq = ArrayList<ProgItem>()
        for (x in pay.q) {
            if (x.startsWith("run:")) {
                val label = x.drop(4)
                if (label !in Defaults.runs) return null
                seq.add(ProgItem("run", label))
            } else {
                if (Station.of(x) == null) return null
                seq.add(ProgItem(x))
            }
        }
        val cleaned = pay.n.filter { !Character.isISOControl(it) && it != '\n' && it != '\r' && it != ' ' && it != ' ' }
        val name = cleaned.trim().take(maxName)
        return Program(
            id = "s." + newId().take(8).lowercase(),
            name = name.ifEmpty { "Shared training" },
            sets = pay.s, seq = seq,
        )
    }

    /** splits8://t?d=token  또는  https://…/t.html#token  에서 token 꺼내기 */
    fun token(fromUrl: String): String? {
        val u = runCatching { java.net.URI(fromUrl) }.getOrNull() ?: return null
        if (u.scheme?.lowercase() == scheme) {
            val q = u.rawQuery ?: return null
            return q.split('&').firstNotNullOfOrNull { kv ->
                val i = kv.indexOf('=')
                if (i > 0 && kv.substring(0, i) == "d") java.net.URLDecoder.decode(kv.substring(i + 1), "UTF-8") else null
            }
        }
        val f = u.rawFragment
        return if (f != null && f.startsWith("1.")) f else null
    }
}

// MARK: 대회

@Serializable
data class RaceEvent(
    val name: String = "",
    val loc: String = "",
    @Serializable(with = InstantIso::class) val date: Instant = Fm.ymdParse("2026-09-13") ?: Instant.now(),
    /** 출발 시각 "HH:mm". 비어 있으면 아직 모름 */
    val time: String = "",
    @Serializable(with = InstantIso::class) val dateEnd: Instant? = null,
) {
    val hasTime: Boolean get() = time.split(":").mapNotNull { it.toIntOrNull() }.size == 2
    val isSet: Boolean get() = name.isNotBlank()
}

// MARK: 친구

@Serializable
data class Friend(
    /** 상대 user id */
    val id: String,
    /** 닉네임 */
    val name: String,
    /** Open Men */
    val div: String,
    /** 13 Sep 2026 (최고 Full Sim 날짜) */
    val date: String,
    /** 16개 (Run1, SkiErg, Run2, …) — 없으면 빈 목록 */
    val splits: List<Int>,
    val avatarUrl: String? = null,
) {
    val first: String get() = name
    val ini: String get() = name.take(1).uppercase()
    val total: Int get() = splits.sum() + 8 * Defaults.roxTarget
    val hasSplits: Boolean get() = splits.size == 16
}

// MARK: 대회 목록 (서버 목록이 없을 때 쓰는 기본값)

@Serializable
data class EventItem(
    val city: String,
    val venue: String,
    /** korea / asia / europe / americas */
    val region: String,
    /** yyyy-MM-dd */
    val start: String,
    val end: String,
) {
    val id: String get() = city + start

    companion object {
        val regions = listOf("all" to "All", "korea" to "Korea", "asia" to "Asia-Pacific", "europe" to "Europe", "americas" to "Americas")
        val bundled: List<EventItem> = listOf(
            listOf("Seoul", "KINTEX, Goyang", "korea", "2026-11-13", "2026-11-15"),
            listOf("Incheon", "Songdo Convensia", "korea", "2027-05-13", "2027-05-16"),
            listOf("Shanghai", "China", "asia", "2026-10-31", "2026-11-01"),
            listOf("Guangzhou", "China", "asia", "2026-11-21", "2026-11-22"),
            listOf("Singapore", "Singapore", "asia", "2026-11-26", "2026-11-29"),
            listOf("Sanya", "China", "asia", "2026-12-05", "2026-12-06"),
            listOf("Melbourne", "Australia", "asia", "2026-12-09", "2026-12-13"),
            listOf("Kuala Lumpur", "Malaysia", "asia", "2026-12-10", "2026-12-13"),
            listOf("Hong Kong", "Hong Kong", "asia", "2027-01-07", "2027-01-10"),
            listOf("Osaka", "Japan", "asia", "2027-01-21", "2027-01-25"),
            listOf("Auckland", "New Zealand", "asia", "2027-02-04", "2027-02-07"),
            listOf("Bangkok", "Thailand", "asia", "2027-02-11", "2027-02-14"),
            listOf("Taipei", "Chinese Taipei", "asia", "2027-03-12", "2027-03-14"),
            listOf("Brisbane", "Australia", "asia", "2027-03-31", "2027-04-04"),
            listOf("Nagoya", "Japan", "asia", "2027-04-16", "2027-04-18"),
            listOf("World Championships", "AsiaWorld-Expo, Hong Kong", "asia", "2027-06-10", "2027-06-13"),
            listOf("Hamburg", "Germany", "europe", "2026-10-28", "2026-11-01"),
            listOf("Barcelona", "Spain", "europe", "2026-11-11", "2026-11-15"),
            listOf("London", "ExCeL London", "europe", "2026-12-02", "2026-12-06"),
            listOf("Stockholm", "Sweden", "europe", "2026-12-10", "2026-12-13"),
            listOf("Paris", "France", "europe", "2026-12-12", "2026-12-20"),
            listOf("Amsterdam", "Netherlands", "europe", "2027-01-22", "2027-01-31"),
            listOf("Dallas", "USA", "americas", "2026-11-18", "2026-11-22"),
            listOf("Anaheim", "USA", "americas", "2026-12-03", "2026-12-06"),
            listOf("Chicago", "USA", "americas", "2027-02-11", "2027-02-15"),
        ).map { EventItem(it[0], it[1], it[2], it[3], it[4]) }
    }
}

// MARK: 기록

@Serializable
data class SegResult(
    val icon: String,
    val name: String,
    val detail: String,
    val kind: SegKind,
    val time: Int,
    val target: Int,
    val hr: Int? = null,
    /** 러닝 거리(m) */
    val dist: Double? = null,
    /** 워치가 팔 움직임으로 센 횟수 (참고용) */
    val reps: Int? = null,
    /** 러닝 구간 평균 케이던스 (분당 걸음) */
    val cad: Int? = null,
    /** 러닝 구간에서 오른 높이(m) */
    val up: Double? = null,
)

/** 스키 · 로잉 · 월볼 횟수 요약 (기록 화면 카드용) */
data class RepSummary(val icon: String, val count: Int, val seconds: Int) {
    /** 분당 횟수 */
    val perMin: Int get() = if (seconds <= 0) 0 else (count * 60.0 / seconds).r()
}

/** 경로 한 점 */
@Serializable
data class RoutePt(
    /** latitude */
    val a: Double,
    /** longitude */
    val o: Double,
    /** 높이(m, 해발) */
    val h: Double? = null,
    /** 운동 시작부터 초 (일시정지 뺀 시간) */
    val t: Int? = null,
)

@Serializable
data class HRPoint(
    /** 시작부터 초 */
    val t: Int,
    /** bpm */
    val b: Int,
)

enum class RecordFlag(val label: String) {
    /** 끝까지 안 하고 End */
    Incomplete("Incomplete"),
    /** 말이 안 되게 빠름 */
    Check("Check"),
}

@Serializable
data class Record(
    val id: String = newId(),
    val mode: Mode,
    /** 프로그램 이름 / 대회 이름 / Full Simulation */
    val title: String,
    val sets: Int = 1,
    @Serializable(with = InstantIso::class) val date: Instant,
    val total: Int,
    val segs: List<SegResult>,
    val hr: List<HRPoint>,
    val kcal: Int,
    val avgHR: Int,
    val maxHR: Int,
    val division: String,
    /** 레이스 목표 시간 */
    val goal: Int? = null,
    /** VS GOAL / VS BEST / VS JIHO */
    val vsWord: String,
    /** 비교 기준 총 시간 */
    val vsTarget: Int? = null,
    /** 더블 파트너 닉네임 (@ 없이) — 기기에만 */
    val partner: String? = null,
    /** "phone" = 워치 없이 폰으로 기록. null = 워치 */
    val source: String? = null,
    /** 끝까지 다 했는지 */
    val complete: Boolean? = null,
    @Serializable(with = InstantIso::class) val endDate: Instant? = null,
    /** 동네 이름 — 기기에만 */
    val place: String? = null,
    /** 실외 러닝 경로 — 기기에만 */
    val route: List<RoutePt>? = null,
    /** "hiit" / "run" */
    val kind: String? = null,
    /** 평균 케이던스 (분당 걸음) */
    val cadence: Int? = null,
    /** 평균 보폭(m) */
    val stride: Double? = null,
    /** 오른 높이 합계(m) */
    val ascent: Double? = null,
) {
    val end: Instant get() = endDate ?: date.plusSeconds(total.toLong())
    val isHIIT: Boolean get() = kind == "hiit"
    val isRunKind: Boolean get() = kind == "run"

    /** 러닝·스테이션 16개 (Roxzone 제외) */
    val splits16: List<Int>?
        get() = segs.filter { it.kind != SegKind.Rox }.map { it.time }.takeIf { it.size == 16 }

    /** PFT 구간 6개 */
    val pftSplits: List<Int>?
        get() = if (mode != Mode.Pft) null
        else segs.filter { it.kind != SegKind.Rox }.map { it.time }.takeIf { it.size == PFT.items.size }

    /** PFT 등급 (끝까지 한 정상 기록만) */
    val pftGrade: PFTGrade? get() = if (mode == Mode.Pft && counts) PFT.grade(total) else null

    val roxTotal: Int get() = segs.filter { it.kind == SegKind.Rox }.sumOf { it.time }
    val runs: List<SegResult> get() = segs.filter { it.kind == SegKind.Run }
    val runTotal: Int get() = runs.sumOf { it.time }
    val stationTotal: Int get() = segs.filter { it.kind == SegKind.St }.sumOf { it.time }

    /** 평균 러닝 페이스 (초/km) */
    val runPace: Int?
        get() {
            val r = runs
            if (r.isEmpty()) return null
            val meters = r.sumOf { it.dist ?: runMeters(it.detail) }
            if (meters <= 0) return null
            return (runTotal / meters * 1000).r()
        }

    /** 횟수가 기록된 종목만 (스키 → 로잉 → 월볼 순서) */
    val repSummaries: List<RepSummary>
        get() = listOf("skiErg", "row", "wallBalls").mapNotNull { k ->
            val ss = segs.filter { it.icon == k && (it.reps ?: 0) > 0 }
            if (ss.isEmpty()) null else RepSummary(k, ss.sumOf { it.reps ?: 0 }, ss.sumOf { it.time })
        }

    val isDoubles: Boolean get() = division.lowercase().startsWith("doubles") || division.startsWith("dbl")

    /** 끝까지 했는지 (예전 기록: Full Sim·Race 는 16구간이 다 있으면 끝까지 한 것으로 봄) */
    val isComplete: Boolean
        get() {
            complete?.let { return it }
            if (mode == Mode.Pft) return pftSplits != null
            return if (mode == Mode.Training) true else splits16 != null
        }

    /** null = 정상 */
    val flag: RecordFlag?
        get() {
            if (!isComplete) return RecordFlag.Incomplete
            if (mode == Mode.Training) return null
            if (mode == Mode.Pft) {
                if (total < MIN_PFT) return RecordFlag.Check
                for (s in segs) {
                    if (s.kind == SegKind.Run && s.time < MIN_RUN) return RecordFlag.Check
                    if (s.kind == SegKind.St && s.time < MIN_PFT_STATION) return RecordFlag.Check
                }
                return null
            }
            if (total < (if (isDoubles) MIN_DOUBLES else MIN_SOLO)) return RecordFlag.Check
            for (s in segs) {
                if (s.kind == SegKind.Run && s.time < MIN_RUN) return RecordFlag.Check
                if (s.kind == SegKind.St && s.time < MIN_STATION) return RecordFlag.Check
            }
            return null
        }

    /** PB·최고 기록·비교 기준에 넣어도 되는 기록인지 */
    val counts: Boolean get() = flag == null

    companion object {
        /** 개인 50분, 더블 45분보다 빠르면 확인 필요 */
        const val MIN_SOLO = 50 * 60
        const val MIN_DOUBLES = 45 * 60
        /** 1km 런 2:30, 스테이션 30초보다 빠르면 확인 필요 */
        const val MIN_RUN = 150
        const val MIN_STATION = 30
        const val MIN_PFT = 10 * 60
        const val MIN_PFT_STATION = 15
    }
}

// MARK: 기록 백업 파일

/** 기록 · 트레이닝을 파일 하나로 내보내고 다시 가져옴. 아이폰 파일과 같은 모양 → 서로 가져올 수 있음 */
@Serializable
data class BackupFile(
    val app: String = "SPLITS8",
    val version: Int = 1,
    @Serializable(with = InstantIso::class) val exportedAt: Instant,
    val records: List<Record>,
    val programs: List<Program>,
) {
    fun json(): String = SplitsJson.encodeToString(serializer(), this)

    companion object {
        fun fileName(date: Instant): String = "SPLITS8-backup-" + Fm.ymd(date) + ".json"

        fun read(text: String): BackupFile? {
            if (text.length > 60_000_000) return null
            val b = runCatching { SplitsJson.decodeFromString(serializer(), text) }.getOrNull() ?: return null
            return if (b.app == "SPLITS8") b else null
        }

        /** 가져오기: 이미 있는 기록(같은 id)은 건너뛰고 없는 것만 더함 */
        fun mergeRecords(incoming: List<Record>, current: List<Record>): Pair<List<Record>, Int> {
            val ids = current.map { it.id.uppercase() }.toMutableSet()
            val out = current.toMutableList()
            var added = 0
            for (r in incoming) {
                if (!ids.add(r.id.uppercase())) continue
                out.add(r); added++
            }
            return out to added
        }

        /** 트레이닝: 같은 id 는 건너뛰고, 전체가 limit 을 넘지 않는 만큼만 더함 */
        fun mergePrograms(incoming: List<Program>, current: List<Program>, limit: Int): Pair<List<Program>, Int> {
            val ids = current.map { it.id }.toMutableSet()
            val out = current.toMutableList()
            var added = 0
            for (p in incoming) {
                if (p.id in ids) continue
                if (out.size >= limit) break
                ids.add(p.id); out.add(p); added++
            }
            return out to added
        }
    }
}

// MARK: 배경 빛 색 (테마)

/** 화면 뒤에 비치는 빛의 색. 노란 강조색은 그대로 */
enum class GlowTheme(val raw: String, val hex: Long, val gain: Double, val label: String) {
    Yellow("yellow", 0xFFE600, 1.0, "Yellow"),
    Orange("orange", 0xFF8C1A, 1.0, "Orange"),
    Red("red", 0xFF453A, 1.1, "Red"),
    Blue("blue", 0x338CFF, 1.3, "Blue"),
    Purple("purple", 0xBF5AF2, 1.2, "Purple"),
    White("white", 0xFFFFFF, 0.8, "White");

    companion object {
        fun of(raw: String?): GlowTheme = entries.firstOrNull { it.raw == raw } ?: Yellow
    }
}

// MARK: 설정 (폰이 원본, 워치로 전달)

/** 차단한 사용자 (id = 서버 user id, name = 차단할 때의 닉네임) */
@Serializable
data class BlockedUser(val id: String, val name: String)

@Serializable
data class Settings(
    val division: String = "openM",
    /** age / manual */
    val hrMode: String = "age",
    val age: Int = 32,
    val manualHr: Int = 190,
    /** outdoor / treadmill / curved */
    val runMode: String = "treadmill",
    val roxAuto: Boolean = true,
    val goals: List<Int> = Defaults.goals,
    val goalTime: Int = Defaults.goalTime,
    val event: RaceEvent = RaceEvent(),
    val friendId: String? = null,
    /** mine / friend */
    val tgtSrc: String = "mine",
    /** goal / last / friend */
    val simCmp: String = "goal",
    val hasOnboarded: Boolean = false,

    // 계정
    val nickname: String? = null,
    val email: String? = null,
    /** Email code / Google */
    val signMethod: String? = null,
    /** friends / public / private */
    val visibility: String = "friends",
    /** 순위표: sim / race / stations */
    val lbTab: String = "sim",
    val lbStation: String = "skiErg",
    val lbAllDivisions: Boolean = false,

    // 진동 (워치)
    val hapticZoneOpt: Boolean? = null,
    val hapticPaceOpt: Boolean? = null,
    val blockedOpt: List<BlockedUser>? = null,
    /** 배경 빛 색. 노랑이면 비워 둠 */
    val themeOpt: String? = null,
    /** 워치 운동을 폰에 같이 보여 주기. null = 켬 */
    val mirrorOpt: Boolean? = null,
    /** 앱 안에서 고른 언어(ko / en). null = 기기 언어 */
    val lang: String? = null,
    /** 이동(Roxzone) 1번 목표(초). null = 30초 */
    val roxGoal: Int? = null,

    // 가입 프로필 (모두 선택)
    /** "M" / "W" */
    val sex: String? = null,
    val heightCm: Int? = null,
    val weightKg: Double? = null,
    val birthYear: Int? = null,
    val raced: Boolean? = null,
    val raceDivision: String? = null,
    val profileDone: Boolean? = null,
    /** 대회 최고 완주 시간(초) — 가입 프로필 ① 에서 (빌드 24). 목표 시간 기본값에 씀 */
    val bestFinish: Int? = null,
    val divPicked: Boolean? = null,
    /** 더블 구간 나누기 계획 (폰에만). 반반이면 null */
    val doublesPlan: DoublesPlan? = null,
) {
    val hapticZone: Boolean get() = hapticZoneOpt ?: true
    val hapticPace: Boolean get() = hapticPaceOpt ?: true
    val blocked: List<BlockedUser> get() = blockedOpt ?: emptyList()
    val glow: GlowTheme get() = GlowTheme.of(themeOpt)
    /** 워치 운동을 폰에 같이 보여 주기 (기본 켬) */
    val mirror: Boolean get() = mirrorOpt ?: true
    /** 이동 목표 (없으면 30초) */
    val roxTarget: Int get() = roxGoal ?: Defaults.roxTarget
    val signedIn: Boolean get() = nickname != null
    val div: Division get() = Division.of(division)
    val maxHR: Int get() = if (hrMode == "age") 220 - age else manualHr

    fun withHapticZone(v: Boolean) = copy(hapticZoneOpt = v)
    fun withHapticPace(v: Boolean) = copy(hapticPaceOpt = v)
    fun withBlocked(v: List<BlockedUser>) = copy(blockedOpt = v.ifEmpty { null })
    fun withGlow(v: GlowTheme) = copy(themeOpt = if (v == GlowTheme.Yellow) null else v.raw)
    fun withMirror(v: Boolean) = copy(mirrorOpt = if (v) null else false)

    /** 1~5 */
    fun zone(bpm: Double): Int {
        val p = bpm / maxOf(1, maxHR)
        return when {
            p >= 0.9 -> 5
            p >= 0.8 -> 4
            p >= 0.7 -> 3
            p >= 0.6 -> 2
            else -> 1
        }
    }
}

/** 닉네임에 쓸 수 없는 말 거르기 (기본 욕설 · 운영자 사칭) */
object NickFilter {
    private val banned = listOf(
        "fuck", "shit", "bitch", "cunt", "nigg", "fagg", "pussy", "whore", "slut",
        "nazi", "hitler", "porn", "asshole", "bastard", "retard",
        "admin", "official", "splits8", "moderator",
        "ssibal", "sibal", "gaesaek", "byungsin",
    )
    private val leet = mapOf('0' to 'o', '1' to 'i', '3' to 'e', '4' to 'a', '5' to 's', '7' to 't', '8' to 'b')

    fun plain(n: String): String = n.lowercase().filter { it != '_' }.map { leet[it] ?: it }.joinToString("")

    /** 써도 되는 닉네임인지 */
    fun allowed(n: String): Boolean {
        val p = plain(n)
        val raw = n.lowercase().filter { it != '_' }
        return banned.none { p.contains(it) || raw.contains(it) }
    }

    /** 닉네임 모양: 소문자 · 숫자 · 밑줄 3~16자 (서버 규칙과 같음) */
    val pattern = Regex("^[a-z0-9_]{3,16}$")
}

object RunModes {
    val keys = listOf("outdoor", "treadmill", "curved")
    fun name(k: String): String =
        mapOf("outdoor" to "Outdoor", "treadmill" to "Treadmill", "curved" to "Curved treadmill")[k] ?: "Treadmill"
    fun spec(k: String): String = mapOf(
        "outdoor" to "GPS pace and distance",
        "treadmill" to "Motion estimate · may differ from the machine",
        "curved" to "Motion estimate · pace shown as approximate",
    )[k] ?: ""
}

// MARK: 구간 순서 만들기

object SeqBuilder {
    /** Full Simulation / Race: Run i, Roxzone, Station, Roxzone … (마지막 스테이션 뒤 Roxzone 없음) */
    fun full(div: Division, rox: Boolean, targets16: List<Int>, roxTarget: Int = Defaults.roxTarget): List<Seg> {
        val o = ArrayList<Seg>()
        for (i in 0 until 8) {
            o.add(Seg("run", "Run ${i + 1}", "1KM", SegKind.Run, targets16[i * 2]))
            if (rox) o.add(Seg("roxzone", "Roxzone", "Transition", SegKind.Rox, roxTarget))
            val s = Station.all[i]
            o.add(Seg(s.key, s.name, s.detail(div), SegKind.St, targets16[i * 2 + 1]))
            if (rox && i < 7) o.add(Seg("roxzone", "Roxzone", "Transition", SegKind.Rox, roxTarget))
        }
        return o
    }

    /** HIIT 라운드 (끝 없이 늘어남, 목표 없음) */
    fun hiitRound(n: Int) = Seg("hiit", "Round $n", "Interval", SegKind.St, 0)

    /** 러닝 1km 구간 */
    fun runKm(n: Int, target: Int = 0) = Seg("run", "KM $n", "1KM", SegKind.Run, target)

    /** 기본 목표 16개 */
    val defaultTargets16: List<Int> get() = (0 until 8).flatMap { listOf(270, Station.all[it].target) }

    /** 트레이닝: 순서 × 세트, Roxzone 없음 */
    fun training(p: Program, div: Division, bests: Map<String, Int>): List<Seg> {
        if (p.isHIIT) return listOf(hiitRound(1))
        if (p.isRun) {
            val n = maxOf(1, p.runKm ?: 0)
            return (1..n).map { runKm(it, bests[SegKey.of("run", "1KM")] ?: 0) }
        }
        val o = ArrayList<Seg>()
        repeat(maxOf(1, p.sets)) {
            for (it in p.seq) {
                val d = it.detail(div)
                o.add(Seg(it.icon, it.name(), d, if (it.icon == "run") SegKind.Run else SegKind.St, bests[SegKey.of(it.icon, d)] ?: 0))
            }
        }
        return o
    }
}

object SegKey {
    /** 러닝은 거리, 스테이션은 무게·거리까지 넣어 구분 (예: "sledPush|50M · 152KG") */
    fun of(icon: String, detail: String) = "$icon|$detail"

    /** 최고 기록으로 써도 되는 시간인지 (너무 빠른 시험용 탭은 빼기) */
    fun plausible(icon: String, detail: String, time: Int): Boolean {
        if (icon == "hiit") return false
        if (icon == "run") return time.toDouble() >= Record.MIN_RUN * runMeters(detail) / 1000
        return time >= Record.MIN_STATION
    }
}

// MARK: 폰 → 워치

@Serializable
data class WatchContext(
    val settings: Settings,
    val programs: List<Program>,
    val friend: Friend? = null,
    val simBest: List<Int>? = null,
    val simBestTotal: Int? = null,
    val segBests: Map<String, Int> = emptyMap(),
    val pftBest: List<Int>? = null,
    val pftBestTotal: Int? = null,
    val simLast: List<Int>? = null,
)

/** Full Simulation 구간 목표 16개와 비교 이름. "Compare with" 를 그대로 따름 */
object SimTarget {
    fun ok(a: List<Int>?): List<Int>? = a?.takeIf { it.size == 16 }

    /** cmp: goal / last / friend. 고른 기준의 기록이 없으면 마지막 기록 → 내 최고 → 기본값 */
    fun pick(
        cmp: String, goals: List<Int>, last: List<Int>?, friend: List<Int>?, friendFirst: String?, best: List<Int>?,
    ): Pair<List<Int>, String> {
        if (cmp == "goal") return (ok(goals) ?: Defaults.goals) to "VS GOAL"
        if (cmp == "friend") ok(friend)?.let { f ->
            val n = (friendFirst ?: "").uppercase()
            return f to (if (n.isEmpty()) "VS FRIEND" else "VS $n")
        }
        ok(last)?.let { return it to "VS LAST" }
        ok(best)?.let { return it to "VS BEST" }
        return SeqBuilder.defaultTargets16 to "VS BEST"
    }
}

/** 폰 ↔ 워치 주고받는 이름 (Data Layer 경로) */
object SyncKey {
    const val context = "/ctx"
    const val record = "/record"
    const val recordAck = "/record-ack"
    const val quick = "/quick"
    const val live = "/live"
}

// MARK: 운동 예약

@Serializable
enum class PlanReminder(val label: String, val short: String) {
    @SerialName("none") None("None", ""),
    @SerialName("hourBefore") HourBefore("1 hour before", "1 hour before"),
    @SerialName("dayBefore") DayBefore("Day before (8:00 PM)", "Day before"),
    @SerialName("weekBefore") WeekBefore("Week before", "Week before"),
}

/** 달력에 예약한 운동 (training / sim) */
@Serializable
data class PlannedWorkout(
    val id: String = newId(),
    val mode: Mode,
    val programId: String? = null,
    val title: String,
    @Serializable(with = InstantIso::class) val date: Instant,
    val reminder: PlanReminder = PlanReminder.DayBefore,
)
