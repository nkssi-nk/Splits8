package com.nkssi.splits8.shared

import kotlinx.serialization.KSerializer
import kotlinx.serialization.Serializable
import kotlinx.serialization.builtins.serializer
import kotlinx.serialization.descriptors.SerialDescriptor
import kotlinx.serialization.encoding.Decoder
import kotlinx.serialization.encoding.Encoder
import kotlinx.serialization.json.JsonArray
import kotlinx.serialization.json.JsonDecoder
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.booleanOrNull
import kotlinx.serialization.json.contentOrNull
import kotlinx.serialization.json.doubleOrNull
import kotlinx.serialization.json.intOrNull

// 교대 계획 (아이폰 빌드 27 Shared/DoublesPlan.swift 와 같은 규칙 · 같은 링크 글자)

/**
 * 더블에서 스테이션 8개를 파트너와 "몇 m(개)씩 번갈아 할지, 누가 먼저 할지" 적어 두는 계획.
 * 스테이션마다 chunk(한 번에 하는 양)와 meFirst(내가 먼저 하는지)를 가짐. 러닝은 둘이 같이 뛰므로 나누지 않음.
 * 예전(빌드 23) 저장 파일에는 shares(몫 %)만 있음 → 읽을 때 무시하고 기본값으로 채움. 워치에서도 씀.
 */
@Serializable(with = DoublesPlanSerializer::class)
data class DoublesPlan(
    /** 경기 순서대로 스테이션마다 한 번에 하는 양 (m 또는 개) */
    val chunks: List<Double> = defaultChunks,
    /** 경기 순서대로 스테이션마다 내가 먼저 하는지 */
    val firsts: List<Boolean> = List(8) { true },
    /** 파트너 이름 (비어 있으면 "Partner") */
    val partnerName: String? = null,
    /** 친구 목록에서 고른 파트너의 user id (직접 적었으면 null) */
    val partnerId: String? = null,
    /**
     * 1.2.1: 스테이션마다 손으로 고친 차례 양 (고정 줄만. 총량에서 모자란 만큼은 늘 "나머지" 줄로 계산).
     * null = 한 번 양(chunk) 방식 그대로. 옛 앱은 이 값을 몰라서 한 번 양 방식으로 보임
     */
    val turns: List<List<Double>?> = List(8) { null },
) {
    // MARK: 읽기 · 쓰기

    /** i번째 스테이션의 한 번 양 (고를 수 없는 값이면 기본값) */
    fun chunk(i: Int): Double {
        if (i !in 0 until 8) return 10.0
        val v = chunks.getOrNull(i)
        return if (v != null && options[i].contains(v)) v else defaultChunks[i]
    }

    fun meFirst(i: Int): Boolean = firsts.getOrNull(i) ?: true

    fun setChunk(i: Int, v: Double): DoublesPlan {
        if (i !in 0 until 8 || !options[i].contains(v)) return this
        val c = (0 until 8).map { chunk(it) }.toMutableList()
        c[i] = v
        return copy(chunks = c)
    }

    fun setMeFirst(i: Int, v: Boolean): DoublesPlan {
        if (i !in 0 until 8) return this
        val f = (0 until 8).map { meFirst(it) }.toMutableList()
        f[i] = v
        return copy(firsts = f)
    }

    /** 기본 계획 그대로인지 (양 · 순서 · 파트너 · 차례 모두 기본) */
    val isDefault: Boolean
        get() = (0 until 8).all { chunk(it) == defaultChunks[it] && meFirst(it) } && partnerName == null && partnerId == null && !hasTurns

    // MARK: 1.2.1 차례 목록 (아이폰 DoublesPlan.swift 와 같은 규칙)
    //  · 고정 줄(turns) 뒤에 늘 "나머지" 줄 = 총량 − 고정 줄 합 (0 이면 없음). 늘릴 수 없고, 줄이면 그 뒤에 새 줄이 생김.
    //  · 고정 줄을 늘리면 나머지가 줄고, 줄이면 나머지가 늘어남 → 모자람 · 넘침이 생길 수 없음.
    //  · 한 줄 최소 = 단위 1칸. 사람은 늘 번갈아 (줄 번호 + 먼저 하는 사람).

    /** 손으로 고친 차례가 하나라도 있는지 */
    val hasTurns: Boolean get() = (0 until 8).any { turnsRaw(it) != null }
    /** i번째 스테이션이 손으로 고쳐졌는지 (빠르게 채운 모양과 다를 때만) */
    fun isEdited(i: Int): Boolean = turnsRaw(i) != null
    /** 저장용: 빠르게 채운 모양과 같으면 null 로 정리 */
    fun turnsRaw(i: Int): List<Double>? {
        val t = turns.getOrNull(i) ?: return null
        if (!validTurns(i, t)) return null
        return if (sameList(t, quickFill(i, chunk(i)))) null else t
    }
    /** 고정 줄 (손으로 고친 게 없으면 빠르게 채운 모양) */
    fun fixedTurns(i: Int): List<Double> = turnsRaw(i) ?: quickFill(i, chunk(i))
    /** 나머지 줄 양 (0 이면 없음) */
    fun remainder(i: Int): Double = maxOf(0.0, total(i) - fixedTurns(i).sum())

    fun setTurns(i: Int, t: List<Double>?): DoublesPlan {
        if (i !in 0 until 8) return this
        val arr = (0 until 8).map { turns.getOrNull(it) }.toMutableList()
        arr[i] = if (t != null && validTurns(i, t)) t else null
        return copy(turns = arr)
    }
    /** 한 번 양을 다시 고르면 고친 차례는 지움 (화면에서 먼저 확인 창) */
    fun resetTurns(i: Int): DoublesPlan = setTurns(i, null)

    fun canPlus(i: Int, k: Int): Boolean = remainder(i) >= unit(i) - EPS && k in fixedTurns(i).indices
    fun canMinus(i: Int, k: Int): Boolean { val t = fixedTurns(i); return k in t.indices && t[k] > unit(i) + EPS }
    /** 나머지 줄을 줄일 수 있는지 (2칸 이상 남았을 때 — 줄이면 그 뒤에 새 줄이 생김) */
    fun canSplitRemainder(i: Int): Boolean = remainder(i) >= 2 * unit(i) - EPS

    fun plus(i: Int, k: Int): DoublesPlan {
        if (!canPlus(i, k)) return this
        val t = fixedTurns(i).toMutableList(); t[k] = t[k] + unit(i); return setTurns(i, t)
    }
    fun minus(i: Int, k: Int): DoublesPlan {
        if (!canMinus(i, k)) return this
        val t = fixedTurns(i).toMutableList(); t[k] = t[k] - unit(i); return setTurns(i, t)
    }
    /** 나머지 줄 − : 나머지에서 한 칸 뺀 만큼을 고정 줄로 굳히고, 그 뒤에 한 칸짜리 새 나머지가 생김 */
    fun splitRemainder(i: Int): DoublesPlan {
        if (!canSplitRemainder(i)) return this
        val t = fixedTurns(i).toMutableList(); t.add(remainder(i) - unit(i)); return setTurns(i, t)
    }

    // MARK: 번갈아 하는 순서

    data class Turn(val me: Boolean, val amount: Double)

    /** i번째 스테이션을 번갈아 하는 순서 = 고정 줄 + 나머지 줄. 사람은 먼저 하는 사람부터 번갈아 */
    fun sequence(i: Int): List<Turn> {
        val amounts = ArrayList(fixedTurns(i))
        val r = remainder(i)
        if (r > EPS) amounts.add(r)
        val out = ArrayList<Turn>()
        var me = meFirst(i)
        for (a in amounts) { out.add(Turn(me, a)); me = !me }
        return out
    }
    /** 마지막 줄이 "나머지" 줄인지 (화면에서 회색으로) */
    fun lastIsRemainder(i: Int): Boolean = remainder(i) > EPS

    /** i번째 스테이션에서 내가 하는 양 */
    fun mine(i: Int): Double = sequence(i).filter { it.me }.sumOf { it.amount }
    /** i번째 스테이션에서 파트너가 하는 양 */
    fun partners(i: Int): Double = sequence(i).filter { !it.me }.sumOf { it.amount }
    fun myTurns(i: Int): Int = sequence(i).count { it.me }
    fun partnerTurns(i: Int): Int = sequence(i).count { !it.me }
    fun turns(i: Int): Int = sequence(i).size

    // MARK: 글자

    /** 파트너 이름 (비었으면 "Partner" 번역) */
    val partnerShown: String
        get() {
            val n = (partnerName ?: "").trim()
            return n.ifEmpty { L10n.t("Partner") }
        }

    /** 받은 계획: 보낸 사람 입장의 계획을 내 입장으로 (먼저 하는 사람을 바꾸고 파트너 = 보낸 사람) */
    fun swapped(sender: String?): DoublesPlan =
        copy(      // 차례 양(turns)은 그대로 — 사람은 줄 번호 + 먼저 하는 사람으로 정해지므로 뒤집기만 하면 맞음
            chunks = (0 until 8).map { chunk(it) },
            firsts = (0 until 8).map { !meFirst(it) },
            partnerName = cleanName(sender),
            partnerId = null,
        )

    companion object {
        /** 스테이션별 전체 양 — Ski 1000 · Push 50 · Pull 50 · BBJ 80 · Row 1000 · FC 200 · Lunges 100 (m) · Wall Balls 100 (개) */
        val totals: List<Double> = listOf(1000.0, 50.0, 50.0, 80.0, 1000.0, 200.0, 100.0, 100.0)

        /** 스테이션별 고를 수 있는 한 번 양 */
        val options: List<List<Double>> = listOf(
            listOf(100.0, 150.0, 200.0, 250.0), // SkiErg
            listOf(6.25, 12.5, 25.0),           // Sled Push (반 · 한 · 두 바퀴씩) — 1.2.1: 6.25 · 25 추가
            listOf(6.25, 12.5, 25.0),           // Sled Pull
            listOf(10.0, 20.0, 40.0),           // BBJ
            listOf(100.0, 150.0, 200.0, 250.0), // Row
            listOf(50.0, 100.0),                // Farmers Carry
            listOf(25.0, 50.0),                 // Lunges
            listOf(10.0, 15.0, 20.0, 25.0),     // Wall Balls (개)
        )
        val defaultChunks: List<Double> = listOf(250.0, 12.5, 12.5, 20.0, 250.0, 50.0, 25.0, 20.0)

        /** 1.2.1: 차례 양을 고칠 때 한 칸 (총량이 모두 이 값의 배수라 나머지도 늘 단위에 맞음) */
        val units: List<Double> = listOf(50.0, 6.25, 6.25, 10.0, 50.0, 25.0, 12.5, 5.0)
        const val EPS = 0.001

        /** 월볼(마지막)만 개수, 나머지는 미터 */
        fun isReps(i: Int) = i == 7

        /** 슬레드 (양을 "반 바퀴 · 한 바퀴 · 두 바퀴"로 보여 줌) */
        fun isSled(i: Int) = i == 1 || i == 2

        /** 예전 이름 (1.2.0 까지 슬레드는 12.5 하나뿐이었음). 이제 고를 수 있으므로 늘 false */
        fun isFixed(i: Int) = false

        fun total(i: Int): Double = totals.getOrElse(i) { 100.0 }
        fun unit(i: Int): Double = units.getOrElse(i) { 1.0 }

        /** v 가 단위의 배수인지 */
        fun onUnit(v: Double, i: Int): Boolean { val q = v / unit(i); return kotlin.math.abs(q - kotlin.math.round(q)) < EPS }

        private fun sameList(a: List<Double>, b: List<Double>): Boolean =
            a.size == b.size && a.indices.all { kotlin.math.abs(a[it] - b[it]) < EPS }

        /** 한 번 양으로 빠르게 채운 고정 줄: c × n. 남는 양은 마지막 두 차례에 반씩 (반이 단위에 맞을 때 — Ski · Row 150, Wall Balls 15) */
        fun quickFill(i: Int, c: Double): List<Double> {
            val tot = total(i)
            val step = maxOf(unit(i), c)
            val n = kotlin.math.floor(tot / step + EPS).toInt().coerceIn(1, 200)
            val arr = MutableList(n) { step }
            val r = tot - n * step
            if (r > EPS && n >= 2 && onUnit(r / 2, i)) { arr[n - 1] += r / 2; arr[n - 2] += r / 2 }
            return arr
        }

        /** 차례 목록이 쓸 만한지 (단위 배수 · 최소 1칸 · 합이 총량 이하 · 40줄 이하) */
        fun validTurns(i: Int, t: List<Double>): Boolean {
            if (t.isEmpty() || t.size > 40) return false
            if (!t.all { it >= unit(i) - EPS && onUnit(it, i) }) return false
            return t.sum() <= total(i) + EPS
        }

        /** 150 / 12.5 / 6.25 (소수점은 필요할 때만. 1.2.1: 둘째 자리까지 — 예전엔 6.25 가 "6.2") */
        fun num(v: Double): String = when {
            kotlin.math.abs(v - v.r()) < 0.001 -> v.r().toString()
            kotlin.math.abs(v * 10 - (v * 10).r()) < 0.001 -> "%.1f".format(java.util.Locale.US, v)
            else -> "%.2f".format(java.util.Locale.US, v)
        }

        /** "150 m" / "20 reps" */
        fun amountText(i: Int, v: Double): String =
            if (isReps(i)) L10n.t("%@ reps", num(v)) else num(v) + " m"

        /** 이름 정리: 줄바꿈 · 조종 글자를 빼고 20자까지. 비면 null */
        fun cleanName(s: String?): String? {
            if (s == null) return null
            val kept = s.filter { !Character.isISOControl(it) && it != '\n' && it != '\r' && it != ' ' && it != ' ' }
            val t = kept.trim { it == ' ' || it == '\t' }.take(20)
            return t.ifEmpty { null }
        }
    }
}

/** 아이폰 Codable 과 같은 모양 {chunks, firsts, partnerName?, partnerId?}. 예전 파일 · 이상한 값도 안전하게 읽음 */
object DoublesPlanSerializer : KSerializer<DoublesPlan> {
    @Serializable
    private data class Wire(
        val chunks: List<Double>,
        val firsts: List<Boolean>,
        val partnerName: String? = null,
        val partnerId: String? = null,
        /** 1.2.1: 스테이션별 고친 차례 (없으면 생략 → 옛 앱도 그대로 읽음) */
        val turns: List<List<Double>?>? = null,
    )

    override val descriptor: SerialDescriptor = Wire.serializer().descriptor

    override fun serialize(encoder: Encoder, value: DoublesPlan) {
        encoder.encodeSerializableValue(
            Wire.serializer(),
            Wire((0 until 8).map { value.chunk(it) }, (0 until 8).map { value.meFirst(it) }, value.partnerName, value.partnerId,
                if (value.hasTurns) (0 until 8).map { value.turnsRaw(it) } else null),
        )
    }

    override fun deserialize(decoder: Decoder): DoublesPlan {
        val jd = decoder as? JsonDecoder
        if (jd == null) {
            val w = decoder.decodeSerializableValue(Wire.serializer())
            return build(w.chunks, w.firsts, w.partnerName, w.partnerId, w.turns)
        }
        val o = jd.decodeJsonElement() as? JsonObject ?: return DoublesPlan()
        val ch = (o["chunks"] as? JsonArray)?.map { (it as? JsonPrimitive)?.doubleOrNull } ?: emptyList()
        val fs = (o["firsts"] as? JsonArray)?.map { (it as? JsonPrimitive)?.booleanOrNull ?: (it as? JsonPrimitive)?.intOrNull?.let { n -> n == 1 } } ?: emptyList()
        val pn = (o["partnerName"] as? JsonPrimitive)?.contentOrNull
        val id = (o["partnerId"] as? JsonPrimitive)?.contentOrNull
        val ts = (o["turns"] as? JsonArray)?.map { st -> (st as? JsonArray)?.mapNotNull { (it as? JsonPrimitive)?.doubleOrNull } }
        return build(ch, fs, pn, id, ts)
    }

    private fun build(ch: List<Double?>, fs: List<Boolean?>, pn: String?, id: String?, ts: List<List<Double>?>?): DoublesPlan {
        var p = DoublesPlan()
        for (i in 0 until 8) {
            ch.getOrNull(i)?.let { p = p.setChunk(i, it) }
            fs.getOrNull(i)?.let { p = p.setMeFirst(i, it) }
        }
        // 1.2.1: 차례 목록 — 이상한 값(단위 안 맞음 · 총량 넘음)은 버리고 한 번 양 방식으로 (setTurns 가 검사)
        if (ts != null) for (i in 0 until minOf(8, ts.size)) p = p.setTurns(i, ts[i])
        return p.copy(partnerName = DoublesPlan.cleanName(pn), partnerId = id)
    }
}

// MARK: 교대 계획 링크

/**
 * 교대 계획을 링크 글자에 담아 보냄 (서버 없이). ProgramLink 와 같은 방식, 아이폰과 한 글자까지 같음.
 * 앱 주소 = splits8://d?d=token,  홈페이지 = ProgramLink.base + "#" + token,  token = "d1." + base64url(JSON)
 * JSON: {"c": [한 번 양 8개], "f": [먼저 1/0 8개], "n": 보낸 사람 닉네임}
 */
object DoublesLink {
    const val host = "d"
    const val prefix = "d1."

    @Serializable
    private data class Payload(val c: List<Double>, val f: List<Int>, val n: String? = null, val t: List<List<Double>?>? = null)

    /** 아이폰 JSONEncoder(sortedKeys): 숫자 250 → "250", 12.5 → "12.5", "/" → "\/". 키 순서 c · f · n · t */
    private fun json(p: Payload): String {
        val c = p.c.joinToString(",") { DoublesPlan.num(it) }
        val f = p.f.joinToString(",")
        val sb = StringBuilder("{\"c\":[").append(c).append("],\"f\":[").append(f).append("]")
        if (p.n != null) {
            val n = kotlinx.serialization.json.Json.encodeToString(String.serializer(), p.n).replace("/", "\\/")
            sb.append(",\"n\":").append(n)
        }
        if (p.t != null) {
            // 1.2.1: [[150,150,200],null,…] — 옛 앱은 이 키를 몰라서 무시
            sb.append(",\"t\":[").append(p.t.joinToString(",") { st -> st?.joinToString(",", "[", "]") { DoublesPlan.num(it) } ?: "null" }).append("]")
        }
        return sb.append("}").toString()
    }

    fun token(p: DoublesPlan, sender: String?): String {
        val pay = Payload((0 until 8).map { p.chunk(it) }, (0 until 8).map { if (p.meFirst(it)) 1 else 0 }, DoublesPlan.cleanName(sender),
            if (p.hasTurns) (0 until 8).map { p.turnsRaw(it) } else null)
        val b64 = java.util.Base64.getEncoder().encodeToString(json(pay).toByteArray(Charsets.UTF_8))
            .replace('+', '-').replace('/', '_').replace("=", "")
        return prefix + b64
    }

    /** 앱 전용 주소 splits8://d?d=token */
    fun appUrl(p: DoublesPlan, sender: String?): String = ProgramLink.scheme + "://" + host + "?d=" + token(p, sender)

    /** 홈페이지 주소 (t.html 이 d1. 글자를 받아 앱으로 넘김) */
    fun webUrl(p: DoublesPlan, sender: String?): String = ProgramLink.base + "#" + token(p, sender)

    /** 받은 글자에서 (보낸 사람 입장의) 계획과 보낸 사람 이름을 꺼냄. 이상한 값이 하나라도 있으면 null */
    fun read(token: String): Pair<DoublesPlan, String?>? {
        if (!token.startsWith(prefix) || token.length > 2000) return null
        var b64 = token.drop(prefix.length).replace('-', '+').replace('_', '/')
        while (b64.length % 4 != 0) b64 += "="
        val bytes = runCatching { java.util.Base64.getDecoder().decode(b64) }.getOrNull() ?: return null
        val pay = runCatching { SplitsJson.decodeFromString(Payload.serializer(), String(bytes, Charsets.UTF_8)) }.getOrNull()
            ?: return null
        if (pay.c.size != 8 || pay.f.size != 8) return null
        var plan = DoublesPlan()
        for (i in 0 until 8) {
            if (!DoublesPlan.options[i].contains(pay.c[i]) || (pay.f[i] != 0 && pay.f[i] != 1)) return null
            plan = plan.setChunk(i, pay.c[i]).setMeFirst(i, pay.f[i] == 1)
        }
        pay.t?.let { t ->
            if (t.size != 8) return null
            for (i in 0 until 8) {
                val a = t[i]
                if (a != null && !DoublesPlan.validTurns(i, a)) return null   // 이상한 차례면 링크 전체를 거절
                plan = plan.setTurns(i, a)
            }
        }
        return plan to DoublesPlan.cleanName(pay.n)
    }

    /** splits8://d?d=token  또는  https://…/t.html#d1.token  에서 token 꺼내기 */
    fun token(url: String): String? {
        val lower = url.lowercase()
        if (lower.startsWith(ProgramLink.scheme + "://")) {
            val rest = url.substring(ProgramLink.scheme.length + 3)
            val h = rest.substringBefore('?').substringBefore('/').lowercase()
            if (h != host) return null
            val q = rest.substringAfter('?', "")
            return q.split('&').firstOrNull { it.startsWith("d=") }?.substring(2)
                ?.let { runCatching { java.net.URLDecoder.decode(it, "UTF-8") }.getOrDefault(it) }
        }
        val frag = url.substringAfter('#', "")
        return frag.takeIf { it.startsWith(prefix) }
    }

    /** 이 주소가 교대 계획 링크인지 */
    fun isDoubles(url: String): Boolean {
        val lower = url.lowercase()
        if (lower.startsWith(ProgramLink.scheme + "://")) {
            val h = url.substring(ProgramLink.scheme.length + 3).substringBefore('?').substringBefore('/').lowercase()
            return h == host
        }
        return url.substringAfter('#', "").startsWith(prefix)
    }
}
