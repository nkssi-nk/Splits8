package com.nkssi.splits8.shared

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.time.Instant

/** 아이폰과 주고받는 글자 (백업 파일 · 공유 링크 · 번역) */
class CompatTest {

    /** 아이폰 JSONEncoder 가 만드는 모양 (null 칸 없음, 날짜 초 단위, 대문자 UUID) */
    private val iosBackup = """
        {"app":"SPLITS8","version":1,"exportedAt":"2026-10-12T05:00:00Z",
         "records":[{"id":"6F1C2A3B-1111-4000-8000-0000000000AA","mode":"sim","title":"Full Simulation","sets":1,
           "date":"2026-10-10T22:30:00Z","total":4321,
           "segs":[{"icon":"run","name":"Run 1","detail":"1KM","kind":"run","time":280,"target":270,"hr":150,"dist":1003.5,"cad":172},
                   {"icon":"roxzone","name":"Roxzone","detail":"TRANSITION","kind":"rox","time":31,"target":30}],
           "hr":[{"t":0,"b":90},{"t":5,"b":120}],"kcal":700,"avgHR":150,"maxHR":181,"division":"Open Men",
           "vsWord":"VS GOAL","complete":true,"route":[{"a":37.5,"o":127.0,"h":12.5,"t":3}],"futureField":42}],
         "programs":[{"id":"p1","name":"Sled Intervals","sets":1,"seq":[{"icon":"run","run":"1KM"},{"icon":"sledPush"}],
           "meta":"1 set · about 12 min","quick":false}]}
    """.trimIndent()

    @Test fun readsIosBackup() {
        val b = BackupFile.read(iosBackup)
        assertNotNull(b)
        val r = b!!.records[0]
        assertEquals(Mode.Sim, r.mode)
        assertEquals(Instant.parse("2026-10-10T22:30:00Z"), r.date)
        assertEquals(SegKind.Rox, r.segs[1].kind)
        assertEquals(172, r.segs[0].cad)
        assertEquals(12.5, r.route!![0].h!!, 0.0)
        assertNull(r.partner)
        assertEquals("sledPush", b.programs[0].seq[1].icon)
        assertNull(b.programs[0].seq[1].run)
    }

    @Test fun writesIosShape() {
        val b = BackupFile.read(iosBackup)!!
        val out = b.json()
        assertTrue(out.contains("\"exportedAt\":\"2026-10-12T05:00:00Z\""))
        assertTrue(out.contains("\"mode\":\"sim\""))
        assertTrue(out.contains("\"kind\":\"rox\""))
        assertFalse("null 칸은 쓰지 않음", out.contains("null"))
        assertFalse(out.contains("futureField"))
        // 다시 읽어도 같음
        assertEquals(b, BackupFile.read(out))
        // 소수 초는 버림 (아이폰이 못 읽음)
        val r = b.records[0].copy(date = Instant.parse("2026-10-10T22:30:00.750Z"))
        assertTrue(SplitsJson.encodeToString(Record.serializer(), r).contains("\"date\":\"2026-10-10T22:30:00Z\""))
    }

    @Test fun rejectsOtherApp() {
        assertNull(BackupFile.read(iosBackup.replace("\"SPLITS8\"", "\"OTHER\"")))
        assertNull(BackupFile.read("not json"))
    }

    @Test fun mergeAddsOnlyNew() {
        val b = BackupFile.read(iosBackup)!!
        val (out, added) = BackupFile.mergeRecords(b.records, b.records.map { it.copy(id = it.id.lowercase()) })
        assertEquals(0, added)
        assertEquals(1, out.size)
        val (progs, n) = BackupFile.mergePrograms(Program.presets(), b.programs, limit = 2)
        assertEquals(1, n)
        assertEquals(2, progs.size)
    }

    @Test fun settingsRoundTrip() {
        val s = Settings(nickname = "kim", doublesPlan = DoublesPlan().set(2, 70)).withGlow(GlowTheme.Purple)
        val j = SplitsJson.encodeToString(Settings.serializer(), s)
        assertFalse(j.contains("null"))
        assertEquals(s, SplitsJson.decodeFromString(Settings.serializer(), j))
        // 예전 아이폰 설정 파일(칸이 적음)도 읽힘
        val old = SplitsJson.decodeFromString(Settings.serializer(), """{"division":"proW","age":40}""")
        assertEquals("proW", old.division)
        assertEquals(180, old.maxHR)
    }

    @Test fun linkToken() {
        val p = Program("u1", "Sled / Wall", 3, listOf(ProgItem("run", "400M"), ProgItem("sledPush"), ProgItem("wallBalls")))
        val tok = ProgramLink.token(p)!!
        val json = String(java.util.Base64.getDecoder().decode(
            tok.drop(2).replace('-', '+').replace('_', '/').let { it + "=".repeat((4 - it.length % 4) % 4) }))
        // 아이폰 JSONEncoder(sortedKeys) 와 같은 글자
        assertEquals("""{"n":"Sled \/ Wall","q":["run:400M","sledPush","wallBalls"],"s":3}""", json)
        val back = ProgramLink.program(tok)!!
        assertEquals("Sled / Wall", back.name)
        assertEquals(3, back.sets)
        assertEquals(p.seq, back.seq)
        assertTrue(back.id.startsWith("s."))
        assertEquals(tok, ProgramLink.token("splits8://t?d=$tok"))
        assertEquals(tok, ProgramLink.token("https://nkssi-nk.github.io/splits8/t.html#$tok"))
    }

    @Test fun linkRejectsBad() {
        fun enc(j: String) = "1." + java.util.Base64.getEncoder().encodeToString(j.toByteArray())
            .replace('+', '-').replace('/', '_').replace("=", "")
        assertNull(ProgramLink.program(enc("""{"n":"x","q":["run:5KM"],"s":1}""")))
        assertNull(ProgramLink.program(enc("""{"n":"x","q":["laser"],"s":1}""")))
        assertNull(ProgramLink.program(enc("""{"n":"x","q":["row"],"s":21}""")))
        assertNull(ProgramLink.program(enc("""{"n":"x","q":[],"s":1}""")))
        assertNull(ProgramLink.program("2.abc"))
        assertEquals("Shared training", ProgramLink.program(enc("""{"n":"\n ","q":["row"],"s":1}"""))!!.name)
    }

    @Test fun l10nFormat() {
        assertEquals("a 3 b x", L10n.format("a %lld b %@", arrayOf<Any?>(3, "x")))
        assertEquals("x 1–2", L10n.format("%3\$@ %1\$lld–%2\$lld", arrayOf<Any?>(1, 2, "x")))
        assertEquals("100%", L10n.format("100%%", arrayOf<Any?>()))
        L10n.lang = "ko"
        assertEquals("1세트 · 8구간", Program.setsText(1, 8))
        L10n.lang = "en"
        assertEquals("2 sets · 8 segments", Program.setsText(2, 8))
    }

    @Test fun koreanHasKeysUsedHere() {
        // 이 모듈 코드가 쓰는 번역 열쇠가 아이폰 한국어 표에 다 있는지
        val keys = listOf(
            "1 set · %lld segments", "%lld sets · %lld segments",
            "You %lld · Partner %lld reps", "You %lld m · Partner %lld m",
            "me %lld / you %lld reps", "me %lld m / you %lld m", "SPLITS8 Doubles plan", "Runs: together",
            "Saved. A few splits look off.", "Ended early. All the way next time.",
            "Your first record. Welcome to SPLITS8.", "Day one. Every split counts from here.",
            "Goal beaten by %@. Great race.", "Race done. You did it.", "That's a race in the books.",
            "New personal best!", "Faster than ever. −%@.", "All 16 splits. Your first full sim.",
            "New best on %@.", "%@ faster than last time.", "%lld km done.", "%lld rounds. Strong finish.",
            "%lld days to race day. Stay sharp.", "Welcome back.", "Good to see you again.",
            "%lld days in a row. Keep it going.", "Workout %lld this week.", "Early start. Nice work.",
            "Late session done. Rest well.", "Over an hour. Serious work.", "That was a tough one.",
            "You pushed hard today.", "Nice work.", "Another one in the books.", "Good start.", "Short, but it counts.",
            "Gold on your first try. Impressive.", "Silver on your first try. Strong start.",
            "Bronze on your first try. Not bad at all.", "Gold. Well earned.", "Up to %@. Gold is next.",
            "%@ — just %llds from %@.", "Still %@, but %@ faster.", "Gold again. Consistent.",
            "%@ this time. Every test counts.", "%@. Nice work.",
            "Gold", "Silver", "Bronze",
        )
        val missing = keys.filter { L10nKo.get(it) == null }
        assertTrue("한국어 표에 없음: $missing", missing.isEmpty())
        assertTrue(L10nKo.size > 600)
    }
}

/** shared 코드가 쓰는 모든 번역 열쇠가 아이폰 한국어 표에 있는지 (오타가 있으면 한국어 화면에 영어가 나옴) */
class L10nKeysTest {
    @Test fun allKeysExist() {
        val dir = java.io.File("src/main/kotlin")
        val re = Regex("""\b(?:L10n\.)?t\(\s*"((?:[^"\\]|\\.)*)"""")
        val keys = dir.walkTopDown().filter { it.isFile && it.extension == "kt" && it.name != "L10nKo.kt" }
            .flatMap { f -> re.findAll(f.readText()).map { it.groupValues[1].replace("\\\"", "\"").replace("\\$", "$") } }
            .toSet()
        val missing = keys.filter { L10nKo.get(it) == null }
        assertTrue("열쇠 ${keys.size}개 중 한국어 표에 없음: $missing", missing.isEmpty())
        assertTrue(keys.size > 100)
    }
}
