package com.nkssi.splits8.screens

import android.content.Intent
import android.net.Uri
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.PickVisualMediaRequest
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.animation.animateColorAsState
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import com.nkssi.splits8.Ask
import com.nkssi.splits8.Router
import com.nkssi.splits8.Scr
import com.nkssi.splits8.Store
import com.nkssi.splits8.shared.BackupFile
import com.nkssi.splits8.shared.Division
import com.nkssi.splits8.shared.GlowTheme
import com.nkssi.splits8.shared.L10n
import com.nkssi.splits8.shared.RunModes
import com.nkssi.splits8.shared.l10n
import com.nkssi.splits8.ui.Avatar8
import com.nkssi.splits8.ui.C
import com.nkssi.splits8.ui.Check8
import com.nkssi.splits8.ui.Chevron8
import com.nkssi.splits8.ui.F
import com.nkssi.splits8.ui.Glyph
import com.nkssi.splits8.ui.Label8
import com.nkssi.splits8.ui.Note8
import com.nkssi.splits8.ui.PageSide
import com.nkssi.splits8.ui.Scroll8
import com.nkssi.splits8.ui.SectionLabel
import com.nkssi.splits8.ui.Seg8
import com.nkssi.splits8.ui.SettingRow
import com.nkssi.splits8.ui.Stepper8
import com.nkssi.splits8.ui.T
import com.nkssi.splits8.ui.Toggle8
import com.nkssi.splits8.ui.W400
import com.nkssi.splits8.ui.W500
import com.nkssi.splits8.ui.W600
import com.nkssi.splits8.ui.YellowPill
import com.nkssi.splits8.ui.card8
import com.nkssi.splits8.ui.hex
import com.nkssi.splits8.ui.press
import com.nkssi.splits8.ui.rowLine
import com.nkssi.splits8.ui.tap

// 아이폰 SettingsViews.swift (설정 · Division · 러닝 · 최대 심박), AuthViews.swift 의 AccountView (프로필),
// ProfileViews.swift 의 ProfileAboutCard · ProfileText, Components.swift 의 GlowSwatches, OnboardingViews.swift 의 DivisionList

private const val HOME_URL = "https://nkssi-nk.github.io/splits8/"
private const val TERMS_URL = "https://nkssi-nk.github.io/splits8/terms.html"
private const val PRIVACY_URL = "https://nkssi-nk.github.io/splits8/privacy.html"

// MARK: - I5 설정 (위 고정 바: SPLITS8 · Settings)

@Composable
fun SettingsView() {
    val s = Store.settings
    val ctx = LocalContext.current
    fun openWeb(u: String) = runCatching { ctx.startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(u))) }

    // 백업: 파일 만들기 (아이폰 공유 시트 대신 안드로이드 "파일로 저장")
    val saveFile = rememberLauncherForActivityResult(ActivityResultContracts.CreateDocument("application/json")) { uri ->
        if (uri == null) return@rememberLauncherForActivityResult
        val ok = runCatching { ctx.contentResolver.openOutputStream(uri)?.use { it.write(Store.backupJson().toByteArray()) } != null }.getOrDefault(false)
        if (!ok) Router.ask = Ask("Backup", "Couldn't make the backup file. Please try again.".l10n, cancel = null)
    }
    val openFile = rememberLauncherForActivityResult(ActivityResultContracts.OpenDocument()) { uri ->
        if (uri == null) return@rememberLauncherForActivityResult
        val text = runCatching { ctx.contentResolver.openInputStream(uri)?.use { it.readBytes().decodeToString() } }.getOrNull()
        Router.ask = Ask("Backup", restoreMessage(text), cancel = null)
    }

    Scroll8 {
        Column(Modifier.padding(horizontal = PageSide), verticalArrangement = Arrangement.spacedBy(10.dp)) {
            ProfileCard()
            Column(Modifier.fillMaxWidth().card8()) {
                // 구간 목표는 Race 탭의 "Split targets" 한 곳에서만 고침
                SettingRow("Running", RunModes.name(s.runMode).l10n, Modifier.testTag("settings.running"), last = true) { Router.go(Scr.SetRun) }
            }

            SectionLabel("FRIENDS")
            Column(Modifier.fillMaxWidth().card8()) {
                SettingRow("Friends", friendsValue(), Modifier.testTag("settings.friends"), last = true, badge = Store.incoming.size) {
                    Router.friendsFrom = Scr.Settings; Router.go(Scr.Friends)
                }
            }

            SectionLabel("VIBRATION")
            Column(Modifier.fillMaxWidth().card8()) {
                ToggleRow("Heart rate zone change", null, s.hapticZone, false, "settings.hapticZone") { v -> Store.update { it.withHapticZone(v) } }
                ToggleRow("Behind target pace", "Race · Full Sim", s.hapticPace, true, "settings.hapticPace") { v -> Store.update { it.withHapticPace(v) } }
            }
            Note8("Your watch alerts you with a vibration during workouts.")

            // 언어: 기본은 폰 언어. 안드로이드는 앱을 다시 켜지 않아도 바로 바뀜
            SectionLabel("LANGUAGE")
            Seg8(listOf("system" to "System", "ko" to "한국어", "en" to "English"), s.lang ?: "system", Modifier.fillMaxWidth().testTag("settings.language"),
                height = 34.dp, radius = 11.dp, fontSize = 14) { k -> Store.update { it.copy(lang = if (k == "system") null else k) } }
            Note8("Follows your phone language unless you pick one here.")

            ThemeSection()

            SectionLabel("DEVICE")
            Column(Modifier.fillMaxWidth().card8()) {
                // 워치 연결 (아이폰 deviceCard): 워치가 연결돼 있고 SPLITS8 워치 앱이 깔려 있으면 "Connected"
                val ws = com.nkssi.splits8.WatchSync.state
                val on = ws == com.nkssi.splits8.WatchSync.State.Ready
                val sub = when (ws) {
                    com.nkssi.splits8.WatchSync.State.Ready -> "Splits8 installed"
                    com.nkssi.splits8.WatchSync.State.NoApp -> "Splits8 not installed"
                    else -> "Not paired"
                }
                Row(Modifier.fillMaxWidth().rowLine(true).padding(vertical = 14.dp, horizontal = 18.dp).testTag("settings.device"),
                    verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                    Glyph("i_device", 22.dp)
                    Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(1.dp)) {
                        T("Watch", F.t(17), maxLines = 1)
                        T(sub, F.t(13, color = C.text2), maxLines = 1)
                    }
                    Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                        Box(Modifier.size(6.dp).clip(CircleShape).background(if (on) C.good else C.text3))
                        T(if (on) "Connected" else "Not connected", F.t(13, W600, if (on) C.good else C.text3), maxLines = 1)
                    }
                }
                ToggleRow("Show on phone", "Watch workouts, live", s.mirror, true, "settings.mirror") { v -> Store.update { it.withMirror(v) } }
            }
            Note8("Shows your watch workout on this phone and on the lock screen while you train. You can control it from either device.")

            SectionLabel("ABOUT")
            Column(Modifier.fillMaxWidth().card8()) {
                SettingRow("Website", "", Modifier.testTag("settings.website")) { openWeb(HOME_URL) }
                SettingRow("Terms of Use", "", Modifier.testTag("settings.terms")) { openWeb(TERMS_URL) }
                SettingRow("Privacy Policy", "", Modifier.testTag("settings.privacy"), last = true) { openWeb(PRIVACY_URL) }
            }

            SectionLabel("DATA")
            Column(Modifier.fillMaxWidth().card8()) {
                SettingRow("Back up records", L10n.t("%lld records", Store.records.size), Modifier.testTag("settings.backup")) {
                    saveFile.launch(BackupFile.fileName(Store.now()))
                }
                SettingRow("Restore from backup", "", Modifier.testTag("settings.restore"), last = true) {
                    openFile.launch(arrayOf("application/json", "text/plain", "application/octet-stream"))
                }
            }
            Note8("Records are kept only on this phone and are deleted with the app. Save a backup file to your files or Google Drive before you delete the app or change phones.")

            if (Store.signedIn) {
                SectionLabel("ACCOUNT")
                Row(Modifier.fillMaxWidth().card8().tap { askSignOut() }.testTag("settings.signout").padding(vertical = 14.dp, horizontal = 18.dp),
                    verticalAlignment = Alignment.CenterVertically) {
                    T("Sign out", F.t(17), Modifier.weight(1f), maxLines = 1)
                    T("@" + (s.nickname ?: ""), F.t(15, color = C.text2), maxLines = 1, translate = false)
                }
            }
        }
    }
}

/** 백업 파일을 읽은 결과 문구 */
internal fun restoreMessage(text: String?): String {
    if (text == null) return "Couldn't open the file. If it's in Google Drive, wait for it to download and try again.".l10n
    val added = Store.importBackup(text) ?: return "This file isn't a SPLITS8 backup.".l10n
    if (added.first == 0 && added.second == 0) return "Nothing new to restore. Everything in this file is already here.".l10n
    return L10n.t("Restored %lld records and %lld trainings.", added.first, added.second)
}

private fun askSignOut() {
    Router.ask = Ask("Sign out?", "Your records stay on this phone.".l10n, ok = "Sign out", destructive = true) { Store.signOut() }
}

/** "2" 또는 "2 · Jiho selected" */
private fun friendsValue(): String {
    val n = "${Store.friends.size}"
    val f = Store.friend ?: return n
    return n + " · " + L10n.t("%@ selected", f.name.split(" ").first())
}

/** 44 원 · @닉네임 17/600 · Open Men (· Not signed up) · › */
@Composable
private fun ProfileCard() {
    val signed = Store.signedIn
    val nick = Store.settings.nickname ?: ""
    val ini = if (Store.photo != null) "" else if (signed) nick.take(1).uppercase() else "?"
    Row(
        Modifier.padding(bottom = 10.dp).fillMaxWidth().card8().press(tag = "settings.profile") { Router.go(Scr.Account) }
            .padding(vertical = 14.dp, horizontal = 18.dp),
        verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(14.dp),
    ) {
        Avatar8(44.dp, ini, photo = Store.photo, bg = if (signed) C.accent else C.control, fg = if (signed) Color.Black else C.text2)
        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
            T(if (signed) "@$nick" else "My profile".l10n, F.t(17, W600), maxLines = 1, translate = false)
            val sub = listOf(Store.settings.div.name) + if (signed) emptyList() else listOf("Not signed up".l10n)
            T(sub.joinToString(" · "), F.t(13, color = C.text2), maxLines = 1, translate = false)
        }
        Chevron8()
    }
}

/** 제목 17 · 설명 13 회색 · 토글 */
@Composable
private fun ToggleRow(title: String, sub: String?, on: Boolean, last: Boolean, tag: String, onChange: (Boolean) -> Unit) {
    Row(Modifier.fillMaxWidth().rowLine(!last).padding(vertical = if (sub == null) 10.dp else 11.dp, horizontal = 18.dp),
        verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
            T(title, F.t(17), maxLines = 1)
            if (sub != null) T(sub, F.t(13, color = C.text2), maxLines = 1)
        }
        Toggle8(on, Modifier.testTag(tag), onChange = onChange)
    }
}

/** 테마: 화면 뒤에 비치는 빛의 색 6가지. 고른 색이 줄 오른쪽에 은은하게 비침 */
@Composable
private fun ThemeSection() {
    val t = Store.settings.glow
    val tint by animateColorAsState(hex(t.hex, minOf(0.3f, 0.16f * t.gain.toFloat())), label = "glow")
    SectionLabel("THEME")
    Row(
        Modifier.fillMaxWidth().card8().background(Brush.horizontalGradient(listOf(tint.copy(alpha = 0f), tint)), RoundedCornerShape(20.dp))
            .padding(vertical = 8.dp, horizontal = 18.dp),
        verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        T("Glow color", F.t(17), Modifier.weight(1f), maxLines = 1)
        GlowSwatches(t, "settings.theme") { g -> Store.update { it.withGlow(g) } }
    }
    Note8("Changes the glow behind each screen. Yellow buttons and the logo stay the same.")
}

/** 동그란 색 6개 (24 + 테두리). 고른 색은 흰 2 테두리 */
@Composable
fun GlowSwatches(selected: GlowTheme, tagPrefix: String = "glow", size: androidx.compose.ui.unit.Dp = 24.dp, onPick: (GlowTheme) -> Unit) {
    Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
        for (g in GlowTheme.entries) {
            val on = g == selected
            Box(
                Modifier.size(size + 8.dp).clip(CircleShape)
                    .border(if (on) 2.dp else 1.dp, if (on) Color.White else Color.White.copy(alpha = 0.14f), CircleShape)
                    .tap { onPick(g) }.testTag("$tagPrefix.${g.raw}"),
                contentAlignment = Alignment.Center,
            ) { Box(Modifier.size(size).clip(CircleShape).background(hex(g.hex))) }
        }
    }
}

// MARK: - I5a Division (위 고정 바: ‹ Profile · Division)

@Composable
fun SetDivView() {
    Scroll8 {
        Column(Modifier.padding(horizontal = PageSide), verticalArrangement = Arrangement.spacedBy(10.dp)) {
            DivisionList(18.dp)
            Note8("Changing your division updates every station weight and rep count in Training, Full Simulation and Race. Weights can change each season, so check the official rules.",
                Modifier.padding(top = 4.dp))
        }
    }
}

/** 디비전 목록 (이름 17 · 무게 13 · 노란 체크). 시작 화면에서도 씀 */
@Composable
fun DivisionList(checkSize: androidx.compose.ui.unit.Dp = 20.dp) {
    Column(Modifier.fillMaxWidth().card8()) {
        Division.all.forEachIndexed { i, d ->
            val on = Store.settings.division == d.key
            Row(Modifier.fillMaxWidth().rowLine(i < Division.all.size - 1).tap { Store.update { it.copy(division = d.key, divPicked = true) } }
                .testTag("div." + d.key).padding(vertical = 14.dp, horizontal = 18.dp),
                verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
                    T(d.name, F.t(17, if (on) W600 else W400), maxLines = 1, translate = false)
                    T(d.spec, F.num(13, W400, C.text2), maxLines = 1, translate = false)
                }
                if (on) Check8(size = checkSize)
            }
        }
    }
}

// MARK: - 러닝 (위 고정 바: ‹ Settings · Running)

@Composable
fun SetRunView() {
    Scroll8 {
        Column(Modifier.padding(horizontal = PageSide), verticalArrangement = Arrangement.spacedBy(10.dp)) {
            Column(Modifier.fillMaxWidth().card8()) {
                RunModes.keys.forEachIndexed { i, k ->
                    val on = Store.settings.runMode == k
                    Row(Modifier.fillMaxWidth().rowLine(i < RunModes.keys.size - 1).tap { Store.update { it.copy(runMode = k) } }
                        .testTag("run.$k").padding(vertical = 14.dp, horizontal = 18.dp),
                        verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
                            T(RunModes.name(k), F.t(17, if (on) W600 else W400), maxLines = 1)
                            T(RunModes.spec(k), F.t(13, color = C.text3), maxLines = 1)
                        }
                        if (on) Check8(size = 18.dp)
                    }
                }
            }
            Note8("Applies to Training and Full Simulation. Race runs are on site, so GPS or motion is chosen automatically. Indoors, distance and pace are estimated from arm motion and may differ from the machine.",
                Modifier.padding(top = 4.dp))
        }
    }
}

// MARK: - I5c 최대 심박 (위 고정 바: ‹ Profile · Max heart rate)

@Composable
fun SetHrView() {
    val s = Store.settings
    val age = s.hrMode == "age"
    fun bump(v: Int) = Store.update { if (it.hrMode == "age") it.copy(age = (it.age + v).coerceIn(10, 99)) else it.copy(manualHr = (it.manualHr + v).coerceIn(120, 230)) }
    Scroll8 {
        Column(Modifier.padding(horizontal = PageSide), verticalArrangement = Arrangement.spacedBy(10.dp)) {
            Column(Modifier.fillMaxWidth().card8().padding(18.dp), verticalArrangement = Arrangement.spacedBy(16.dp)) {
                Row(verticalAlignment = Alignment.Bottom) {
                    Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(4.dp)) {
                        Label8("MAX HEART RATE")
                        Row(verticalAlignment = Alignment.Bottom, horizontalArrangement = Arrangement.spacedBy(4.dp)) {
                            T("${s.maxHR}", F.num(44, tracking = -1.76f), Modifier.testTag("hr.value"), maxLines = 1, translate = false)
                            T("BPM", F.t(13, W600, C.hr, tracking = 0.78f), Modifier.padding(bottom = 9.dp), maxLines = 1, translate = false)
                        }
                    }
                    T(if (age) L10n.t("220 − %lld yrs", s.age) else "Manual entry".l10n, F.t(13, color = C.text2),
                        align = TextAlign.End, translate = false)
                }
                Seg8(listOf("age" to "By age", "manual" to "Manual"), s.hrMode, Modifier.fillMaxWidth().testTag("hr.mode")) { k ->
                    Store.update { it.copy(hrMode = k) }
                }
                Row(verticalAlignment = Alignment.CenterVertically) {
                    T(if (age) "Age" else "Max heart rate", F.t(15), Modifier.weight(1f), maxLines = 1)
                    Stepper8("${if (age) s.age else s.manualHr}", Modifier.testTag("hr.stepper"), minWidth = 40.dp, down = { bump(-1) }, up = { bump(1) })
                }
            }
            SectionLabel("ZONES")
            Column(Modifier.fillMaxWidth().card8()) {
                val mx = s.maxHR.toDouble()
                for (i in 0 until 5) {
                    val p = listOf(50, 60, 70, 80, 90)[i]
                    val pct = if (i == 4) "90%+" else "$p–${p + 10}%"
                    val lo = kotlin.math.round(mx * p / 100).toInt()
                    val hi = kotlin.math.round(mx * (p + 10) / 100).toInt() - 1
                    val range = if (i == 4) "${kotlin.math.round(mx * 0.9).toInt()}+" else "$lo–$hi"
                    Row(Modifier.fillMaxWidth().rowLine(i < 4).padding(vertical = 13.dp, horizontal = 18.dp),
                        verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                        Box(Modifier.size(4.dp, 22.dp).clip(RoundedCornerShape(2.dp)).background(C.zones[i]))
                        T("Z${i + 1}", F.t(15, W600), Modifier.width(28.dp), maxLines = 1, translate = false)
                        T(pct, F.t(13, color = C.text2), Modifier.weight(1f), maxLines = 1, translate = false)
                        T(range, F.num(17, W500), Modifier.testTag("hr.z${i + 1}"), maxLines = 1, translate = false)
                    }
                }
            }
            Note8("Calculated automatically from your max heart rate. Heart rate colors and Z1–Z5 on your watch follow these ranges.")
        }
    }
}

// MARK: - 프로필 (위 고정 바: ‹ Settings · Profile)

/** 가입 프로필 값 글자 (아이폰 ProfileText) */
object ProfileText {
    fun sex(s: String?): String = when (s) { "M" -> "Men"; "W" -> "Women"; else -> "Not set" }

    fun body(h: Int?, w: Double?): String {
        val parts = listOfNotNull(h?.let { "$it cm" }, w?.let { "${kotlin.math.round(it).toInt()} kg" })
        return if (parts.isEmpty()) "Not set" else parts.joinToString(" · ")
    }

    /** 대회 경험 줄: "No" / "Pro Women" / "Relay" */
    fun race(raced: Boolean?, div: String?): String {
        if (raced == null) return "Not set"
        if (!raced) return "No"
        if (div == null) return "Yes"
        if (div == "relay") return "Relay"
        return Division.all.firstOrNull { it.key == div }?.name ?: "Yes"
    }
}

@Composable
fun AccountView() {
    val s = Store.settings
    val signed = Store.signedIn
    val nick = s.nickname ?: ""
    val ctx = LocalContext.current
    val pick = rememberLauncherForActivityResult(ActivityResultContracts.PickVisualMedia()) { uri ->
        if (uri == null) return@rememberLauncherForActivityResult
        val bmp = runCatching { ctx.contentResolver.openInputStream(uri)?.use { android.graphics.BitmapFactory.decodeStream(it) } }.getOrNull()
        if (bmp != null) Store.setPhoto(bmp)
    }
    fun pickPhoto() = pick.launch(PickVisualMediaRequest(ActivityResultContracts.PickVisualMedia.ImageOnly))

    Scroll8 {
        Column(Modifier.padding(horizontal = PageSide), verticalArrangement = Arrangement.spacedBy(10.dp)) {
            // 사진 104 + 카메라 32 · Add photo / Change photo · Remove · 이름 20/600 · 설명 13
            Column(Modifier.fillMaxWidth().padding(top = 6.dp, bottom = 8.dp), horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.spacedBy(10.dp)) {
                Box(Modifier.size(104.dp).tap { pickPhoto() }.testTag("profile.photo")) {
                    Avatar8(104.dp, if (Store.photo != null) "" else if (signed) nick.take(1).uppercase() else "?", photo = Store.photo,
                        bg = if (signed) C.accent else C.control, fg = if (signed) Color.Black else C.text2)
                    Box(Modifier.align(Alignment.BottomEnd).offset(x = 3.dp, y = 3.dp).size(38.dp).clip(CircleShape).background(Color.Black),
                        contentAlignment = Alignment.Center) {
                        Box(Modifier.size(32.dp).clip(CircleShape).background(C.control), contentAlignment = Alignment.Center) { Glyph("i_camera", 16.dp) }
                    }
                }
                Row(horizontalArrangement = Arrangement.spacedBy(16.dp)) {
                    T(if (Store.photo == null) "Add photo" else "Change photo", F.t(15, W600, C.accent), Modifier.tap { pickPhoto() }, maxLines = 1)
                    if (Store.photo != null) T("Remove", F.t(15, W600, C.text2), Modifier.tap { Store.setPhoto(null) }.testTag("profile.photoRemove"), maxLines = 1)
                }
                Column(horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(2.dp)) {
                    T(if (signed) "@$nick" else "My profile".l10n, F.t(20, W600, tracking = -0.4f), maxLines = 1, translate = false)
                    T(if (signed) (s.email ?: "you@example.com") else "Not signed up · Saved on this device only".l10n, F.t(13, color = C.text2),
                        maxLines = 1, translate = false)
                }
            }

            SectionLabel("ATHLETE")
            Column(Modifier.fillMaxWidth().card8()) {
                SettingRow("Division", s.div.name, Modifier.testTag("profile.division")) { Router.editProfile(2) }
                val hr = (if (s.hrMode == "age") L10n.t("Age %lld", s.age) + " · " else "") + "${s.maxHR} BPM"
                SettingRow("Age · Max heart rate", hr, Modifier.testTag("profile.hr"), numeric = true, last = true) { Router.sub(Scr.SetHr, Scr.Account) }
            }

            // 가입 프로필과 같은 구성 (빌드 24): 대회 경험 · 태어난 해 · 키 · 몸무게. 성별은 디비전에서 정해짐
            SectionLabel("ABOUT YOU")
            Column(Modifier.fillMaxWidth().card8()) {
                val race = ProfileText.race(s.raced, s.raceDivision).l10n + (s.bestFinish?.let { " · " + com.nkssi.splits8.shared.Fm.t(it) } ?: "")
                SettingRow("Race experience", race, Modifier.testTag("profile.about.race")) { Router.editProfile(1) }
                SettingRow("Birth year", s.birthYear?.let { "$it · " + ageGroup(it) } ?: "Not set".l10n, Modifier.testTag("profile.about.year"), numeric = true) { Router.editProfile(3) }
                SettingRow("Height · Weight", ProfileText.body(s.heightCm, s.weightKg).l10n, Modifier.testTag("profile.about.body"), numeric = true, last = true) { Router.editProfile(4) }
            }
            Note8("Only you can see these. They're used for your division and age-group comparisons.")

            if (signed) {
                SectionLabel("ACCOUNT")
                Column(Modifier.fillMaxWidth().card8()) {
                    SettingRow("Nickname", "@$nick", Modifier.testTag("profile.nickname")) { Router.go(Scr.Nick) }
                    Row(Modifier.fillMaxWidth().padding(vertical = 14.dp, horizontal = 18.dp), verticalAlignment = Alignment.CenterVertically) {
                        T("Sign-in", F.t(17), Modifier.weight(1f), maxLines = 1)
                        T(s.signMethod ?: "Email code", F.t(15, color = C.text2), maxLines = 1)
                    }
                }
                SectionLabel("WHO CAN SEE MY RECORDS")
                Seg8(listOf("friends" to "Friends", "public" to "Public", "private" to "Only me"), s.visibility, Modifier.fillMaxWidth().testTag("profile.visibility"),
                    height = 34.dp) { k -> Store.update { it.copy(visibility = k) } }   // 서버에 알리기는 5단계
                Note8(when (s.visibility) {
                    "public" -> "Anyone who knows your nickname can see your best records."
                    "private" -> "You won't appear on leaderboards, and only you can see your records."
                    else -> "Only people you've added as friends can see your records and rankings."
                })
                Column(Modifier.padding(top = 14.dp).fillMaxWidth().card8()) {
                    Box(Modifier.fillMaxWidth().rowLine(true).tap { askSignOut() }.testTag("profile.signout").padding(vertical = 14.dp, horizontal = 18.dp)) {
                        T("Sign out", F.t(17), maxLines = 1)
                    }
                    Box(Modifier.fillMaxWidth().tap {
                        Router.ask = Ask("Delete your account?", "Your nickname, friends and shared records will be deleted from the server.".l10n,
                            ok = "Delete account", destructive = true) { Router.deleteAccount() }
                    }.testTag("profile.delete").padding(vertical = 14.dp, horizontal = 18.dp)) {
                        T("Delete account", F.t(17, color = C.bad), maxLines = 1)
                    }
                }
                Note8("Deleting your account removes your nickname, friends and shared records from the server. Records and health data on this device stay.")
            } else {
                Row(Modifier.padding(top = 10.dp).fillMaxWidth().card8().padding(vertical = 16.dp, horizontal = 18.dp),
                    verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                    T("Sign up to get a nickname. This photo will appear in friend lists and leaderboards.", F.t(13, color = C.text2), Modifier.weight(1f))
                    YellowPill("Sign up", Modifier.testTag("profile.signup")) { Router.toAuth(Scr.Account) }
                }
            }
            Spacer(Modifier.height(4.dp))
        }
    }
}
