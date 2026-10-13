package com.nkssi.splits8.screens

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.focus.focusRequester
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextDecoration
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.core.content.ContextCompat
import com.nkssi.splits8.Accounts
import com.nkssi.splits8.NicknameTaken
import com.nkssi.splits8.ProfileLoad
import com.nkssi.splits8.R
import com.nkssi.splits8.Router
import com.nkssi.splits8.Scr
import com.nkssi.splits8.Store
import com.nkssi.splits8.shared.Division
import com.nkssi.splits8.shared.Fm
import com.nkssi.splits8.shared.GoalSplit
import com.nkssi.splits8.shared.HyroxBench
import com.nkssi.splits8.shared.L10n
import com.nkssi.splits8.shared.NickFilter
import com.nkssi.splits8.shared.l10n
import com.nkssi.splits8.ui.C
import com.nkssi.splits8.ui.Check8
import com.nkssi.splits8.ui.F
import com.nkssi.splits8.ui.Glyph
import com.nkssi.splits8.ui.Label8
import com.nkssi.splits8.ui.LargeTitle
import com.nkssi.splits8.ui.Note8
import com.nkssi.splits8.ui.Seg8
import com.nkssi.splits8.ui.T
import com.nkssi.splits8.ui.W500
import com.nkssi.splits8.ui.W600
import com.nkssi.splits8.ui.Wheel8
import com.nkssi.splits8.ui.YellowButton
import com.nkssi.splits8.ui.card8
import com.nkssi.splits8.ui.navBottom
import com.nkssi.splits8.ui.press
import com.nkssi.splits8.ui.rowLine
import com.nkssi.splits8.ui.statusTop
import com.nkssi.splits8.ui.tap
import com.nkssi.splits8.ui.yellowFill
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import java.time.Year

// 아이폰 OnboardingViews.swift (시작 3단계) · AuthViews.swift (이메일 · 코드 · 닉네임) ·
// ProfileViews.swift 의 가입 프로필 — 단, 가입 프로필은 빌드 24 순서로 (인계-최신 3.2):
// 새 계정: 닉네임 → ① 대회 경험 (+ 최고 완주 시간) → ② 내 디비전 → ③ 태어난 해 → ④ 키 · 몸무게 (1 / 5)
// 닉네임이 이미 있으면 ①~④ (1 / 4). 모든 단계 건너뛰기 가능.

// MARK: - 공통 틀

/**
 * 가입 · 시작 화면 틀: 좌우 24, 위 4(상태 줄 아래), 아래 버튼 자리. 내용이 짧으면 버튼이 화면 아래에 붙고, 길면 스크롤.
 * 키보드가 올라오면 키보드 바로 위까지
 */
@Composable
fun Page8(spacing: Dp = 10.dp, content: @Composable ColumnScope.() -> Unit) {
    BoxWithConstraints(Modifier.fillMaxSize().imePadding()) {
        val top = statusTop() + 4.dp
        val bottom = maxOf(24.dp, navBottom() + 16.dp)
        val minH = this.maxHeight
        Column(Modifier.fillMaxSize().verticalScroll(rememberScrollState())) {
            Column(
                Modifier.fillMaxWidth().heightIn(min = minH).padding(horizontal = 24.dp).padding(top = top, bottom = bottom),
                verticalArrangement = Arrangement.spacedBy(spacing),
                content = content,
            )
        }
    }
}

/** h1 아래 회색 설명 (15, 줄간 1.45) */
@Composable
fun PageSub(text: String, modifier: Modifier = Modifier) {
    T(text, F.t(15, color = C.text2).copy(lineHeight = 21.75.sp), modifier.fillMaxWidth())
}

/** 진행 점 (지금 22×6 노랑, 나머지 6×6) + "1 / 3" */
@Composable
private fun StepDots(step: Int, total: Int) {
    Row(Modifier.fillMaxWidth().height(44.dp), verticalAlignment = Alignment.CenterVertically) {
        Row(Modifier.weight(1f), horizontalArrangement = Arrangement.spacedBy(6.dp)) {
            for (n in 1..total) {
                Box(Modifier.size(if (n == step) 22.dp else 6.dp, 6.dp).clip(RoundedCornerShape(3.dp)).background(if (n == step) C.accent else C.control))
            }
        }
        T("$step / $total", F.t(13, W600, C.text2, tracking = 1.3f), Modifier.testTag("dots"), maxLines = 1, translate = false)
    }
}

/** ‹ 뒤로 (노랑, 44 높이) */
@Composable
fun BackLink(label: String, onClick: () -> Unit) {
    Row(Modifier.height(44.dp).tap(onClick = onClick).testTag("back"), verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(2.dp)) {
        Glyph("i_chevL", 22.dp, C.accent)
        T(label, F.t(17, color = C.accent), maxLines = 1)
    }
}

/** 시스템 뒤로 가기가 누를 동작 */
@Composable
fun BackAction(f: (() -> Unit)?) {
    DisposableEffect(f) {
        Router.backAction = f
        onDispose { if (Router.backAction === f) Router.backAction = null }
    }
}

/** 오류 글 (13, 빨강) */
@Composable
private fun ErrorLine(text: String) {
    T(text, F.t(13, color = C.bad), Modifier.fillMaxWidth().padding(horizontal = 4.dp).testTag("error"), translate = false)
}

/** 큰 노란 버튼 + 진행 중이면 "…" */
@Composable
private fun BusyButton(title: String, busy: Boolean, enabled: Boolean, tag: String, onClick: () -> Unit) {
    YellowButton(if (busy) "…" else title, enabled = enabled && !busy, tag = tag, onClick = onClick)
}

// MARK: - 시작 3단계 (Division → 심박 존 → 워치 연결)

@Composable
private fun ObFrame(step: Int, title: String, sub: String, button: String, onButton: () -> Unit, content: @Composable ColumnScope.() -> Unit) {
    BackAction { Router.go(when (step) { 1 -> Scr.Splash; 2 -> Scr.Ob1; else -> Scr.Ob2 }) }
    Page8 {
        StepDots(step, 3)
        LargeTitle(title)
        PageSub(sub, Modifier.padding(bottom = 10.dp))
        content()
        Spacer(Modifier.weight(1f))
        YellowButton(button, Modifier.padding(bottom = 14.dp), tag = "ob.next", onClick = onButton)
    }
}

@Composable
fun Onboarding1() {
    ObFrame(1, "Your division", "This sets your default weights and reps. You can change it anytime in Settings.", "Continue", { Router.go(Scr.Ob2) }) {
        DivisionList(20.dp)
    }
}

@Composable
fun Onboarding2() {
    val s = Store.settings
    val age = s.hrMode == "age"
    fun bump(v: Int) = Store.update { if (it.hrMode == "age") it.copy(age = (it.age + v).coerceIn(10, 99)) else it.copy(manualHr = (it.manualHr + v).coerceIn(120, 230)) }
    ObFrame(2, "Heart rate zones", "Z1–Z5 are calculated from your max heart rate. Heart rate colors on your watch follow these ranges.", "Continue",
        { Router.go(Scr.Ob3) }) {
        Seg8(listOf("age" to "By age", "manual" to "Manual"), s.hrMode, Modifier.fillMaxWidth()) { k -> Store.update { it.copy(hrMode = k) } }
        Row(Modifier.fillMaxWidth().card8().padding(vertical = 18.dp, horizontal = 20.dp), verticalAlignment = Alignment.CenterVertically) {
            Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(4.dp)) {
                Label8(if (age) "AGE" else "MAX HEART RATE")
                T("${if (age) s.age else s.manualHr}", F.num(44, tracking = -1.32f), Modifier.testTag("ob.hrValue"), maxLines = 1, translate = false)
            }
            Box(Modifier.size(44.dp).clip(CircleShape).background(Color.White.copy(alpha = 0.14f)).press(0.94f, tag = "hr.down") { bump(-1) },
                contentAlignment = Alignment.Center) { T("−", F.t(20), translate = false) }
            Spacer(Modifier.width(8.dp))
            Box(Modifier.size(44.dp).yellowFill(CircleShape).press(0.94f, tag = "hr.up") { bump(1) }, contentAlignment = Alignment.Center) {
                T("+", F.t(20, color = Color.Black), translate = false)
            }
        }
        Row(Modifier.fillMaxWidth().padding(horizontal = 4.dp)) {
            T("Max heart rate", F.t(13, color = C.text2), Modifier.weight(1f), maxLines = 1)
            T("${s.maxHR} BPM", F.num(15), maxLines = 1, translate = false)
        }
        Row(Modifier.fillMaxWidth().height(8.dp).clip(RoundedCornerShape(4.dp)), horizontalArrangement = Arrangement.spacedBy(4.dp)) {
            for (i in 0 until 5) Box(Modifier.weight(1f).height(8.dp).background(C.zones[i]))
        }
    }
}

/**
 * 워치 연결: 안드로이드는 지금 위치 권한만 실제로 물어봄 (야외 러닝 페이스).
 * 갤럭시 워치 · Health Connect 연결은 워치 앱 (7단계) · 건강 앱 (6단계) 에서 붙임 — 그 줄은 그렇다고 알려 줌
 */
@Composable
fun Onboarding3() {
    val ctx = LocalContext.current
    var asked by remember { mutableStateOf(false) }
    fun locOK() = ContextCompat.checkSelfPermission(ctx, Manifest.permission.ACCESS_FINE_LOCATION) == PackageManager.PERMISSION_GRANTED ||
        ContextCompat.checkSelfPermission(ctx, Manifest.permission.ACCESS_COARSE_LOCATION) == PackageManager.PERMISSION_GRANTED
    var loc by remember { mutableStateOf(locOK()) }
    val ask = rememberLauncherForActivityResult(ActivityResultContracts.RequestMultiplePermissions()) { r ->
        loc = r.values.any { it } || locOK(); asked = true
    }
    fun finish() {
        Store.update { it.copy(hasOnboarded = true) }
        Router.go(Scr.Home)
    }
    ObFrame(3, "Connect your watch", "Workouts and heart rate are measured on your watch. Allow location for outdoor run pace.",
        if (asked || loc) "Start training" else "Allow & connect",
        { if (asked || loc) finish() else ask.launch(arrayOf(Manifest.permission.ACCESS_FINE_LOCATION, Manifest.permission.ACCESS_COARSE_LOCATION)) }) {
        Column(Modifier.fillMaxWidth().card8()) {
            PermRow("i_permWatch", "Watch", "Connects with the watch app", false, false)
            PermRow("i_permHealth", "Health data", "Connects with the watch app", false, false)
            PermRow("i_permLoc", "Location", if (loc) "Allowed · outdoor runs" else "Outdoor run pace (optional)", loc, true)
        }
        Note8("No account needed. Records are saved only on this device.")
    }
}

/** 36 사각 아이콘 (허용 전 #2C2C2E / 후 초록 0.15) · 이름 17/500 · 설명 13 · 초록 체크 */
@Composable
private fun PermRow(icon: String, name: String, sub: String, on: Boolean, last: Boolean) {
    Row(Modifier.fillMaxWidth().rowLine(!last).padding(vertical = 16.dp, horizontal = 18.dp), verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(14.dp)) {
        Box(Modifier.size(36.dp).clip(RoundedCornerShape(10.dp)).background(if (on) C.good.copy(alpha = 0.15f) else C.control), contentAlignment = Alignment.Center) {
            Glyph(icon, 18.dp, if (on) C.good else Color.White)
        }
        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
            T(name, F.t(17, W500), maxLines = 1)
            T(sub, F.t(13, color = C.text2), maxLines = 1)
        }
        if (on) Check8(C.good, 20.dp)
    }
}

// MARK: - 이메일 (가입 · 로그인)

@Composable
fun AuthView() {
    val scope = rememberCoroutineScope()
    val ctx = LocalContext.current
    var busy by remember { mutableStateOf(false) }
    var error by remember { mutableStateOf<String?>(null) }
    val signin = Router.authMode == "signin"
    val emailOK = Regex(".+@.+\\..+").matches(Router.email.trim())
    val backLabel = when (Router.authReturn) {
        Scr.Race -> "Race"; Scr.Friends -> "Friends"; Scr.Settings -> "Settings"; Scr.Account -> "Profile"; else -> "Back"
    }
    fun back() { Router.authMode = "signup"; Router.go(if (Router.authReturn == Scr.Ob1) Scr.Splash else Router.authReturn) }
    BackAction(::back)

    fun sendCode() {
        if (!Accounts.api.ready) { error = "Sign-in comes in a later Android build.".l10n; return }
        busy = true; error = null
        scope.launch {
            try { Accounts.api.sendCode(Router.email.trim()); Router.code = ""; Router.go(Scr.Code) }
            catch (e: Exception) { error = e.message ?: "Error" }
            busy = false
        }
    }
    fun google() {
        if (!Accounts.api.ready) { error = "Sign-in comes in a later Android build.".l10n; return }
        busy = true; error = null
        scope.launch {
            try {
                val mail = Accounts.api.signInGoogle()
                if (mail != null) {
                    Store.update { it.copy(signMethod = "Google", email = mail) }
                    when (Accounts.api.loadProfile()) {
                        ProfileLoad.Found -> Router.afterSignIn(false)
                        ProfileLoad.None -> Router.afterSignIn(true)
                        ProfileLoad.Failed -> error = "Signed in, but we couldn't load your profile. Check your connection and try again.".l10n
                    }
                }
            } catch (e: Exception) { error = e.message ?: "Error" }
            busy = false
        }
    }

    Page8(12.dp) {
        BackLink(backLabel, ::back)
        LargeTitle(if (signin) "Sign in" else "Create account")
        PageSub(if (signin) "We'll send a code to the email you signed up with." else "Sign up with an email code. No password needed.",
            Modifier.padding(bottom = 8.dp))
        Box(Modifier.fillMaxWidth().card8(14.dp).padding(vertical = 15.dp, horizontal = 16.dp)) {
            if (Router.email.isEmpty()) T("you@example.com", F.t(17, color = C.text3), translate = false)
            BasicTextField(Router.email, { Router.email = it.trim() }, Modifier.fillMaxWidth().testTag("auth.field"), textStyle = F.t(17), singleLine = true,
                cursorBrush = SolidColor(C.accent), keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Email))
        }
        BusyButton("Continue with email", busy, emailOK, "auth.email") { sendCode() }
        Row(Modifier.fillMaxWidth().padding(vertical = 6.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
            Box(Modifier.weight(1f).height(1.dp).background(Color.White.copy(alpha = 0.1f)))
            T("or", F.t(13, color = C.text3))
            Box(Modifier.weight(1f).height(1.dp).background(Color.White.copy(alpha = 0.1f)))
        }
        // 흰 버튼 54 + 구글 G (아이폰의 "Sign in with Apple" 자리)
        Row(Modifier.fillMaxWidth().height(54.dp).clip(RoundedCornerShape(16.dp)).background(Color.White).press(tag = "auth.google") { google() },
            verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp, Alignment.CenterHorizontally)) {
            Image(painterResource(R.drawable.google_g), null, Modifier.size(20.dp))
            T("Continue with Google", F.t(17, W600, Color.Black), maxLines = 1)
        }
        error?.let { ErrorLine(it) }
        Spacer(Modifier.weight(1f))
        T("You can record everything on your own without an account.\nYou only need one to add friends and compare rankings.",
            F.t(13, color = C.text3).copy(lineHeight = 19.5.sp), Modifier.fillMaxWidth(), align = TextAlign.Center)
        T("By continuing, you agree to the Terms of Use and Privacy Policy. Offensive nicknames or photos are not allowed.",
            F.t(12, color = C.text3).copy(lineHeight = 16.sp), Modifier.fillMaxWidth().padding(top = 2.dp), align = TextAlign.Center)
        Row(Modifier.fillMaxWidth().padding(bottom = 8.dp), horizontalArrangement = Arrangement.spacedBy(18.dp, Alignment.CenterHorizontally)) {
            for ((t, u, tag) in listOf(Triple("Terms of Use", "https://nkssi-nk.github.io/splits8/terms.html", "auth.terms"),
                Triple("Privacy Policy", "https://nkssi-nk.github.io/splits8/privacy.html", "auth.privacy"))) {
                T(t, F.t(13, W600, C.text2).copy(textDecoration = TextDecoration.Underline),
                    Modifier.heightIn(min = 32.dp).tap { runCatching { ctx.startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(u))) } }.testTag(tag).padding(top = 8.dp),
                    maxLines = 1)
            }
        }
    }
}

// MARK: - 코드 6자리

@Composable
fun CodeView() {
    val scope = rememberCoroutineScope()
    var busy by remember { mutableStateOf(false) }
    var error by remember { mutableStateOf<String?>(null) }
    var resent by remember { mutableStateOf(false) }
    var verified by remember { mutableStateOf(false) }
    val focus = remember { FocusRequester() }
    BackAction { Router.go(Scr.Auth) }

    fun verify() {
        if (Router.code.length != 6 || busy) return
        busy = true; error = null
        scope.launch {
            try {
                // 코드는 한 번만 쓸 수 있음 → 이미 확인됐으면(프로필 읽기만 실패했던 경우) 다시 확인하지 않음
                if (!verified) { Accounts.api.verify(Router.email, Router.code); verified = true }
                Store.update { it.copy(signMethod = "Email code", email = Router.email) }
                when (Accounts.api.loadProfile()) {
                    ProfileLoad.Found -> Router.afterSignIn(false)
                    ProfileLoad.None -> Router.afterSignIn(true)
                    ProfileLoad.Failed -> error = "Signed in, but we couldn't load your profile. Check your connection and try again.".l10n
                }
            } catch (e: Exception) { error = "That code doesn't match. Please check and try again.".l10n }
            busy = false
        }
    }

    Page8(12.dp) {
        BackLink("Email") { Router.go(Scr.Auth) }
        LargeTitle("Check your email")
        PageSub(L10n.t("Enter the 6-digit code we sent to %@.", Router.email.ifEmpty { "you@example.com" }), Modifier.padding(bottom = 8.dp))
        Box(Modifier.fillMaxWidth().height(60.dp).tap { runCatching { focus.requestFocus() } }) {
            // 숨은 입력칸 하나 (숫자 키패드) + 6칸
            BasicTextField(Router.code, { v ->
                val d = v.filter { it.isDigit() }.take(6)
                Router.code = d
                if (d.length == 6) verify()
            }, Modifier.fillMaxWidth().height(60.dp).focusRequester(focus).testTag("code.field"), textStyle = F.t(1, color = Color.Transparent),
                cursorBrush = SolidColor(Color.Transparent), singleLine = true, keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.NumberPassword))
            Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                for (i in 0 until 6) {
                    val ch = Router.code.getOrNull(i)?.toString() ?: ""
                    val active = i == Router.code.length
                    Box(Modifier.weight(1f).height(60.dp).clip(RoundedCornerShape(14.dp)).background(C.card)
                        .border(if (active) 1.5.dp else 1.dp, if (active) C.accent else C.cardBorder, RoundedCornerShape(14.dp)),
                        contentAlignment = Alignment.Center) { T(ch, F.num(28), translate = false) }
                }
            }
        }
        Row(Modifier.fillMaxWidth().padding(horizontal = 2.dp), verticalAlignment = Alignment.CenterVertically) {
            T(if (resent) "Code sent again" else "The code is valid for 10 minutes", F.t(13, color = C.text3), Modifier.weight(1f), maxLines = 1)
            T("Resend", F.t(13, W600, C.accent), Modifier.tap {
                scope.launch { runCatching { Accounts.api.sendCode(Router.email) }; Router.code = ""; resent = true; verified = false }
            }.testTag("code.resend"), maxLines = 1)
        }
        error?.let { ErrorLine(it) }
        Spacer(Modifier.weight(1f))
        Box(Modifier.padding(bottom = 14.dp)) { BusyButton("Verify", busy, Router.code.length == 6, "code.verify") { verify() } }
    }
    LaunchedEffect(Unit) { runCatching { focus.requestFocus() } }
}

// MARK: - 닉네임 (가입 흐름의 1 / 5, 또는 프로필에서 바꾸기)

/** 영문 소문자 · 숫자 · _ 만, 16자까지 (대문자는 소문자로) */
fun nickFiltered(v: String): String = v.lowercase().filter { it in 'a'..'z' || it in '0'..'9' || it == '_' }.take(16)

@Composable
fun NickView() {
    val scope = rememberCoroutineScope()
    val editing = Store.settings.nickname != null && !Router.signupFlow
    var taken by remember { mutableStateOf(false) }
    var checking by remember { mutableStateOf(false) }
    var checkFailed by remember { mutableStateOf(false) }
    var busy by remember { mutableStateOf(false) }
    var error by remember { mutableStateOf<String?>(null) }
    LaunchedEffect(Unit) { if (Router.nickDraft.isEmpty()) Store.settings.nickname?.let { Router.nickDraft = it } }
    val nd = Router.nickDraft
    val valid = Regex("^[a-z0-9_]{3,16}$").matches(nd)
    val clean = NickFilter.allowed(nd)
    val ok = valid && clean && !taken && !checking && !checkFailed
    BackAction(if (editing) ({ Router.go(Scr.Account) }) else null)

    // 입력이 멈추고 0.3초 뒤 서버에 물어봄 (내 지금 닉네임이면 안 물음)
    LaunchedEffect(nd) {
        taken = false; checkFailed = false
        if (!valid || nd == Store.settings.nickname) { checking = false; return@LaunchedEffect }
        checking = true
        delay(300)
        try { taken = !Accounts.api.nicknameAvailable(nd) } catch (e: Exception) { checkFailed = true }
        checking = false
    }

    fun save() {
        busy = true; error = null
        scope.launch {
            try {
                Accounts.api.saveNickname(nd)
                Store.update { it.copy(nickname = nd) }
                if (editing) Router.go(Scr.Account) else Router.afterNick()
            } catch (e: NicknameTaken) { taken = true } catch (e: Exception) { error = e.message }
            busy = false
        }
    }

    val msg = when {
        nd.isEmpty() -> " "
        taken -> L10n.t("@%@ is taken", nd)
        !valid -> "3–16 characters: lowercase letters, numbers and _ only".l10n
        !clean -> "Please choose a different nickname".l10n
        checking -> "Checking…".l10n
        checkFailed -> "Couldn't check this nickname. Check your connection and type it again.".l10n
        else -> L10n.t("@%@ is available", nd)
    }
    val msgColor = when { nd.isEmpty() -> C.text2; ok -> C.good; checking && valid -> C.text2; else -> C.bad }
    val ring = when { nd.isEmpty() -> C.cardBorder; ok -> C.good.copy(alpha = 0.6f); else -> C.bad.copy(alpha = 0.6f) }

    Page8(12.dp) {
        if (Router.signupFlow) StepDots(1, 5) else if (editing) BackLink("Profile") { Router.go(Scr.Account) } else Spacer(Modifier.height(44.dp))
        LargeTitle("Pick a nickname")
        PageSub("Friends find you by this name, and it appears on leaderboards.", Modifier.padding(bottom = 8.dp))
        Row(Modifier.fillMaxWidth().clip(RoundedCornerShape(14.dp)).background(C.card).border(1.dp, ring, RoundedCornerShape(14.dp)).padding(horizontal = 16.dp),
            verticalAlignment = Alignment.CenterVertically) {
            T("@", F.t(17, color = C.text3), translate = false)
            Box(Modifier.weight(1f).padding(vertical = 15.dp, horizontal = 4.dp)) {
                if (nd.isEmpty()) T("nickname", F.t(17, color = C.text3))
                BasicTextField(nd, { Router.nickDraft = nickFiltered(it) }, Modifier.fillMaxWidth().testTag("nick.field"), textStyle = F.t(17), singleLine = true,
                    cursorBrush = SolidColor(C.accent), keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Ascii, autoCorrectEnabled = false))
            }
            if (ok && nd.isNotEmpty()) Check8(C.good, 20.dp)
        }
        T(msg, F.t(13, W500, msgColor), Modifier.padding(horizontal = 4.dp).testTag("nick.msg"), translate = false)
        T("Lowercase letters, numbers and underscores (_), 3–16 characters. You can change it later in Settings.", F.t(13, color = C.text3),
            Modifier.padding(horizontal = 4.dp))
        error?.let { ErrorLine(it) }
        Spacer(Modifier.weight(1f))
        Box(Modifier.padding(bottom = 14.dp)) { BusyButton(if (editing) "Save" else "Continue", busy, ok && nd.isNotEmpty(), "nick.save") { save() } }
    }
}

// MARK: - 가입 프로필 (빌드 24): ① 대회 경험 → ② 내 디비전 → ③ 태어난 해 → ④ 키 · 몸무게

private val singles = listOf("openM", "openW", "proM", "proW")
private val doubles = listOf("dblM", "dblW", "dblX", "dblMP", "dblWP")
/** 처음이라면 추천 (더블 Open) */
private val recommended = setOf("dblM", "dblW", "dblX")

/** 디비전 → 성별 (Doubles Mixed 는 따로 고름) */
private fun sexOf(div: String): String? = when {
    div == "dblX" -> null
    div.contains("W") -> "W"
    else -> "M"
}

/** 나이대 (그해 나이 = 올해 − 태어난 해): 16–24, 25–29 … 65–69, 70+ */
fun ageGroup(year: Int, thisYear: Int = Year.now().value): String {
    val age = thisYear - year
    if (age < 25) return "16–24"
    if (age >= 70) return "70+"
    val lo = age / 5 * 5
    return "$lo–${lo + 4}"
}

@Composable
fun ProfileSetupView() {
    val s0 = Store.settings
    val editing = Router.profileEdit
    val withNick = Router.signupFlow
    val thisYear = remember { Year.now().value }
    var step by remember { mutableIntStateOf(Router.profileStep.coerceIn(1, 4)) }
    var raced by remember { mutableStateOf(s0.raced) }
    var bh by remember { mutableIntStateOf((s0.bestFinish ?: 4800) / 3600) }
    var bm by remember { mutableIntStateOf(((s0.bestFinish ?: 4800) % 3600) / 60) }
    var bs by remember { mutableIntStateOf((s0.bestFinish ?: 4800) % 60) }
    var div by remember { mutableStateOf(if (s0.divPicked == true || s0.raceDivision != null) s0.division else null) }
    var mixedSex by remember { mutableStateOf(s0.sex ?: "M") }
    var year by remember { mutableIntStateOf(s0.birthYear ?: 1990) }
    var height by remember { mutableIntStateOf(s0.heightCm ?: if (s0.sex == "W") 163 else 175) }
    var weight by remember { mutableIntStateOf(kotlin.math.round(s0.weightKg ?: if (s0.sex == "W") 58.0 else 75.0).toInt()) }

    BackAction(if (editing) ({ Router.go(Scr.Account) }) else if (step > 1) ({ step -= 1 }) else null)

    /** 이 단계 값을 저장 (withTime = 최고 완주 시간도) */
    fun saveStep(withTime: Boolean = true) {
        when (step) {
            1 -> Store.update { st ->
                var n = st.copy(raced = raced, bestFinish = if (raced == true && withTime) bh * 3600 + bm * 60 + bs else if (raced == false) null else st.bestFinish)
                // 최고 완주 시간 → 목표 시간 기본값 · 구간 나누기 (실제 중간값 비율)
                val best = n.bestFinish
                if (best != null && best > 600 && withTime) {
                    val rox = HyroxBench.roxEach(best, n.division)
                    n = n.copy(goalTime = best, roxGoal = rox, goals = GoalSplit.split(best, "balanced", n.goals, null, n.division, rox))
                }
                n
            }
            2 -> div?.let { d -> Store.update { it.copy(division = d, divPicked = true, sex = sexOf(d) ?: mixedSex, raceDivision = if (it.raced == true) d else null) } }
            3 -> Store.update { it.copy(birthYear = year, age = (thisYear - year).coerceIn(10, 99)) }   // 설정의 나이는 태어난 해로 계산
            4 -> Store.update { it.copy(heightCm = height, weightKg = weight.toDouble()) }
        }
    }
    fun finish() {
        Store.update { it.copy(profileDone = true) }
        if (editing) Router.go(Scr.Account) else Router.finishProfile()
    }
    fun next(withTime: Boolean = true) {
        saveStep(withTime)
        if (editing || step == 4) finish() else step += 1
    }
    fun skip() {
        Router.toast = "No problem! You can fill this in anytime from Settings › Profile."
        if (editing) Router.go(Scr.Account) else if (step == 4) finish() else step += 1
    }

    val title = when (step) { 1 -> "Race experience"; 2 -> "My division"; 3 -> "Birth year"; else -> "Height and weight" }
    val sub = when (step) {
        1 -> "Have you raced HYROX before?"
        2 -> "Weights and record comparisons follow this."
        3 -> "Used to compare you with your age group. Only you can see your birth year."
        else -> "Optional. Only you can see this."
    }
    val canGo = when (step) { 1 -> raced != null; 2 -> div != null; else -> true }

    Page8 {
        if (editing) BackLink("Profile") { Router.go(Scr.Account) }
        else if (withNick) StepDots(step + 1, 5) else StepDots(step, 4)
        LargeTitle(title)
        PageSub(sub, Modifier.padding(bottom = 10.dp))
        when (step) {
            1 -> {
                // 큰 버튼 두 개
                Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                    BigChoice("Yes, I've raced", raced == true, Modifier.weight(1f), "profile.raced.yes") { raced = true }
                    BigChoice("Not yet", raced == false, Modifier.weight(1f), "profile.raced.no") { raced = false }
                }
                if (raced == true) {
                    Column(Modifier.fillMaxWidth().card8().padding(top = 14.dp, bottom = 6.dp, start = 12.dp, end = 12.dp)) {
                        Label8("BEST FINISH TIME", Modifier.padding(start = 6.dp))
                        Row(Modifier.padding(top = 6.dp), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                            Wheel8((0..2).toList(), bh, Modifier.weight(1f), { "$it " + unit("unit.h", "h") }, "best.h") { bh = it }
                            Wheel8((0..59).toList(), bm, Modifier.weight(1f), { "$it " + unit("unit.m", "m") }, "best.m") { bm = it }
                            Wheel8((0..59).toList(), bs, Modifier.weight(1f), { "$it " + unit("unit.s", "s") }, "best.s") { bs = it }
                        }
                    }
                    Note8("We use it for your default goal time, split targets and predicted finish.")
                }
            }
            2 -> {
                if (raced == false) {
                    Row(Modifier.fillMaxWidth().clip(RoundedCornerShape(14.dp)).background(Color(0x1AFFE600)).padding(vertical = 12.dp, horizontal = 14.dp)
                        .testTag("profile.recommend")) {
                        T("New to HYROX? We recommend Doubles (Open). You share the work with a friend, so it's easier.", F.t(15).copy(lineHeight = 21.sp))
                    }
                }
                Label8("SINGLE", Modifier.padding(start = 4.dp, top = 4.dp))
                DivChips(singles, div, raced == false) { div = it }
                Label8("DOUBLES", Modifier.padding(start = 4.dp, top = 8.dp))
                DivChips(doubles, div, raced == false) { div = it }
                if (div == "dblX") {
                    Row(Modifier.padding(top = 6.dp).fillMaxWidth().card8().padding(vertical = 10.dp, horizontal = 16.dp), verticalAlignment = Alignment.CenterVertically) {
                        T("Your gender", F.t(17), Modifier.weight(1f), maxLines = 1)
                        Seg8(listOf("M" to "Men", "W" to "Women"), mixedSex, Modifier.testTag("profile.mixedSex"), height = 30.dp, minWidth = 64.dp) { mixedSex = it }
                    }
                }
            }
            3 -> {
                Column(Modifier.fillMaxWidth().card8()) {
                    Wheel8(((thisYear - 10) downTo 1930).toList(), year, Modifier.padding(horizontal = 40.dp, vertical = 10.dp), { "$it" }, "profile.year") { year = it }
                    Row(Modifier.fillMaxWidth().rowLine(false).padding(vertical = 14.dp, horizontal = 18.dp)) {
                        T("Age group", F.t(15, color = C.text2), Modifier.weight(1f), maxLines = 1)
                        T(ageGroup(year, thisYear), F.num(17), Modifier.testTag("profile.ageGroup"), maxLines = 1, translate = false)
                    }
                }
            }
            else -> {
                Row(Modifier.fillMaxWidth().card8().padding(vertical = 14.dp, horizontal = 12.dp), horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                    Column(Modifier.weight(1f), horizontalAlignment = Alignment.CenterHorizontally) {
                        Label8("HEIGHT")
                        Wheel8((120..220).toList(), height, Modifier.padding(top = 6.dp), { "$it cm" }, "profile.height") { height = it }
                    }
                    Column(Modifier.weight(1f), horizontalAlignment = Alignment.CenterHorizontally) {
                        Label8("WEIGHT")
                        Wheel8((30..200).toList(), weight, Modifier.padding(top = 6.dp), { "$it kg" }, "profile.weight") { weight = it }
                    }
                }
            }
        }
        Spacer(Modifier.weight(1f))
        T("You can change this later in Settings.", F.t(13, color = C.text3), Modifier.fillMaxWidth(), align = TextAlign.Center)
        // 대회 경험에서 "나가 봤어요"면 시간만 건너뛰기, 그 밖에는 이 단계 건너뛰기
        if (step == 1 && raced == true) {
            T("Skip the time", F.t(17, W600, C.text2), Modifier.fillMaxWidth().height(44.dp).tap { next(withTime = false) }.testTag("profile.skipTime").padding(top = 10.dp),
                align = TextAlign.Center, maxLines = 1)
        } else {
            T(if (editing) "Cancel" else "Not now", F.t(17, W600, C.text2), Modifier.fillMaxWidth().height(44.dp).tap { skip() }.testTag("profile.skip").padding(top = 10.dp),
                align = TextAlign.Center, maxLines = 1)
        }
        YellowButton(if (editing) "Save" else "Continue", Modifier.padding(bottom = 14.dp), enabled = canGo, tag = "profile.next") { next() }
    }
}

/** 큰 고르기 단추 (80 높이, 고르면 노란 테두리 + 노란 0.10 바탕) */
@Composable
private fun BigChoice(title: String, on: Boolean, modifier: Modifier, tag: String, onClick: () -> Unit) {
    val shape = RoundedCornerShape(16.dp)
    Box(modifier.height(80.dp).clip(shape).background(if (on) Color(0x1AFFE600) else C.card)
        .border(if (on) 1.5.dp else 1.dp, if (on) C.accent else C.cardBorder, shape).press(0.97f, tag = tag, onClick = onClick),
        contentAlignment = Alignment.Center) {
        T(title, F.t(17, W600, if (on) C.accent else Color.White), Modifier.padding(horizontal = 10.dp), align = TextAlign.Center, maxLines = 2)
    }
}

/** 디비전 칩 (고르면 노랑, 추천 칸에는 작은 "추천") */
@Composable
private fun DivChips(keys: List<String>, selected: String?, showRecommend: Boolean, onPick: (String) -> Unit) {
    FlowRow(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(8.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
        for (k in keys) {
            val on = selected == k
            Row(Modifier.height(40.dp).clip(CircleShape).background(if (on) C.accent else Color.White.copy(alpha = 0.08f))
                .tap { onPick(k) }.testTag("profile.div.$k").padding(horizontal = 14.dp), verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                T(Division.of(k).name, F.t(15, W600, if (on) Color.Black else Color.White), maxLines = 1, translate = false)
                if (showRecommend && k in recommended) {
                    Box(Modifier.clip(RoundedCornerShape(6.dp)).background(if (on) Color.Black.copy(alpha = 0.15f) else Color(0x29FFE600)).padding(horizontal = 6.dp, vertical = 2.dp)) {
                        T("Recommended", F.t(11, W600, if (on) Color.Black else C.accent), maxLines = 1)
                    }
                }
            }
        }
    }
}

// MARK: - 잠깐 뜨는 안내

@Composable
fun ToastHost() {
    val t = Router.toast
    var shown by remember { mutableStateOf("") }
    if (t != null) shown = t
    LaunchedEffect(t) { if (t != null) { delay(2500); if (Router.toast == t) Router.toast = null } }
    Box(Modifier.fillMaxSize().padding(bottom = navBottom() + 110.dp, start = 24.dp, end = 24.dp), contentAlignment = Alignment.BottomCenter) {
        AnimatedVisibility(t != null, enter = fadeIn(), exit = fadeOut()) {
            T(shown, F.t(15, W500).copy(lineHeight = 21.sp),
                Modifier.clip(RoundedCornerShape(14.dp)).background(Color(0xF22C2C2E)).padding(vertical = 12.dp, horizontal = 16.dp).testTag("toast"),
                align = TextAlign.Center)
        }
    }
}

