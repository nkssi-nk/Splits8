package com.nkssi.splits8

import com.nkssi.splits8.shared.L10n
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * 폰 화면 코드가 쓰는 번역 열쇠가 한국어 표에 다 있는지 (없으면 한국어 화면에 영어가 그대로 나옴).
 * T("…") · L10n.t("…") · "…".l10n · Label8/SectionLabel/Note8/YellowButton/NavBar3 등 첫 글자 칸을 읽음.
 * translate = false 인 줄과, 영어 그대로 두는 말(아래 keep)은 뺌
 */
class L10nAppTest {
    private val keep = setOf(
        "PFT", "HIIT", "SPLITS8", "Gold", "22:00 · Silver", "26:00 · Bronze", "--:--", "Division", "PB", "BBJ",
        "8 RUNS · 8 STATIONS", "Android · coming next",
        "SkiErg", "Sled Push", "Sled Pull", "Row", "Lunges", "Wall Balls", "Farmers Carry", "Carry", "Run", "TOTAL",
    )

    @Test fun appKeysExist() {
        val dir = java.io.File("src/main/kotlin")
        val call = Regex("""\b(?:T|L10n\.t|Label8|SectionLabel|Note8|YellowButton|YellowPill|GrayPill|Field8|SearchField8|SettingRow)\(\s*"((?:[^"\\$]|\\.)++)"([^\n]*)""")
        val ext = Regex(""""((?:[^"\\$]|\\.)++)"\.l10n""")
        val nav = Regex("""NavBar3\(\s*"([^"]+)",\s*"([^"]+)"""")
        val keys = HashSet<String>()
        dir.walkTopDown().filter { it.isFile && it.extension == "kt" }.forEach { f ->
            val s = f.readText()
            call.findAll(s).forEach { m -> if (!m.groupValues[2].contains("translate = false")) keys.add(m.groupValues[1]) }
            ext.findAll(s).forEach { keys.add(it.groupValues[1]) }
            nav.findAll(s).forEach { keys.add(it.groupValues[1]); keys.add(it.groupValues[2]) }
        }
        val clean = keys.map { it.replace("\\n", "\n").replace("\\\"", "\"") }
            .filter { k -> k !in keep && k.any { it.isLetter() } && !k.startsWith("i_") }
        L10n.lang = "ko"
        // SectionLabel 은 대문자 열쇠 → 없으면 첫 글자만 대문자로 보이므로, 대문자 열쇠는 한국어 표에 있어야 함
        val missing = clean.filter { L10n.t(it) == it }.sorted()
        L10n.lang = "en"
        assertTrue("한국어 표에 없음 (${missing.size}): $missing", missing.isEmpty())
    }
}
