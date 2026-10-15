plugins {
    alias(libs.plugins.android.application)
    alias(libs.plugins.kotlin.compose)
    alias(libs.plugins.kotlin.serialization)
}

android {
    namespace = "com.nkssi.splits8.wear"
    compileSdk = 37

    defaultConfig {
        // 폰 앱과 같은 이름 (Wearable Data Layer 조건)
        applicationId = "com.nkssi.splits8"
        minSdk = 33          // Wear OS 4 (갤럭시 워치 4 이후)
        targetSdk = 36
        // 구글 플레이는 올릴 때마다 번호가 커져야 함 → GitHub 빌드 번호 × 10 + 2 (폰 끝자리 1, 워치 끝자리 2). 컴퓨터 빌드는 102
        versionCode = System.getenv("GITHUB_RUN_NUMBER")?.toIntOrNull()?.let { it * 10 + 2 } ?: 102
        versionName = "1.0.0"
    }
    // 폰과 같은 디버그 서명 키 (폰 ↔ 워치는 서명이 같아야 서로 주고받음)
    signingConfigs {
        getByName("debug") {
            storeFile = file("../app/debug.keystore")
            storePassword = "android"
            keyAlias = "androiddebugkey"
            keyPassword = "android"
        }
    }
    // 출시용 서명 (구글 플레이 업로드 키). GitHub 비밀값에서 받아 쓰고, 없으면 출시용 빌드는 서명 없이 만들어짐
    val upload = System.getenv("SPLITS8_UPLOAD_KEYSTORE")?.let { file(it) }?.takeIf { it.exists() }
    if (upload != null) {
        signingConfigs.create("release") {
            storeFile = upload
            storePassword = System.getenv("SPLITS8_UPLOAD_STORE_PASSWORD")
            keyAlias = System.getenv("SPLITS8_UPLOAD_KEY_ALIAS") ?: "upload"
            keyPassword = System.getenv("SPLITS8_UPLOAD_KEY_PASSWORD") ?: System.getenv("SPLITS8_UPLOAD_STORE_PASSWORD")
        }
    }
    buildTypes {
        debug { signingConfig = signingConfigs.getByName("debug") }
        release {
            isMinifyEnabled = false
            if (upload != null) signingConfig = signingConfigs.getByName("release")
        }
    }
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
    buildFeatures { compose = true }
    testOptions {
        unitTests.isIncludeAndroidResources = true
        unitTests.all {
            it.systemProperty("robolectric.graphicsMode", "NATIVE")
            it.systemProperty("roborazzi.test.record", "true")
        }
    }
}

/**
 * 그림 · 글꼴은 폰 앱 것을 그대로 씀 (스테이션 · 모드 · 메뉴 아이콘, Pretendard).
 * 저장소에 두 번 두지 않고 빌드할 때 폰 폴더에서 복사해 옴.
 */
abstract class CopyPhoneRes : DefaultTask() {
    @get:InputDirectory abstract val phoneRes: DirectoryProperty
    @get:OutputDirectory abstract val outputDir: DirectoryProperty

    @TaskAction
    fun run() {
        val out = outputDir.get().asFile
        out.deleteRecursively()
        val src = phoneRes.get().asFile
        // 워치에서 쓰지 않는 큰 그림은 뺌 (켤 때 사진 · 위젯 미리보기)
        // wordmark_yellow.png 은 워치 폴더에 이미 있음
        val skip = setOf("splash.jpg", "widget_dday_preview.png", "widget_week_preview.png", "wordmark_yellow.png")
        File(src, "drawable-nodpi").listFiles()?.filter { it.name !in skip }?.forEach { it.copyTo(File(out, "drawable-nodpi/${it.name}")) }
        File(src, "font").listFiles()?.forEach { it.copyTo(File(out, "font/${it.name}")) }
        listOf("sym_undo.xml", "sym_heart.xml").forEach { n -> File(src, "drawable/$n").takeIf { it.exists() }?.copyTo(File(out, "drawable/$n")) }
    }
}

val copyPhoneRes = tasks.register<CopyPhoneRes>("copyPhoneRes") {
    phoneRes.set(rootProject.layout.projectDirectory.dir("app/src/main/res"))
    outputDir.set(layout.buildDirectory.dir("generated/phoneRes"))
}

androidComponents {
    onVariants { v -> v.sources.res?.addGeneratedSourceDirectory(copyPhoneRes, CopyPhoneRes::outputDir) }
}

dependencies {
    // 예전 라이브러리가 끌고 오는 오래된 Fragment(1.2) 대신 새 것 — 권한 요청(registerForActivityResult)이 제대로 돌게 (출시용 빌드 검사)
    implementation(libs.androidx.fragment)
    implementation(project(":shared"))
    implementation(libs.androidx.core.ktx)
    implementation(libs.androidx.activity.compose)
    implementation(libs.androidx.lifecycle.runtime.compose)
    implementation(platform(libs.compose.bom))
    implementation(libs.compose.ui)
    implementation(libs.compose.foundation)
    implementation(libs.wear.compose.foundation)
    implementation(libs.wear.compose.material3)
    implementation(libs.compose.ui.tooling.preview)
    debugImplementation(libs.compose.ui.tooling)
    debugImplementation(libs.compose.ui.test.manifest)
    // 폰과 주고받기 (Wearable Data Layer)
    implementation(libs.play.wearable)
    implementation(libs.kotlinx.coroutines.play)
    // 운동 측정 (심박 · 칼로리 · 거리 · 걸음 · 위치)
    implementation(libs.health.services)
    // 어두운 화면(항상 켜진 화면) · 진행 중 운동 표시
    implementation(libs.androidx.wear)
    implementation(libs.wear.ongoing)
    // 시계 화면 칸 (다음 대회 D-day)
    implementation(libs.wear.complications)

    // 시험 · 화면 사진 (둥근 워치 화면): ./gradlew :wear:testDebugUnitTest
    testImplementation(libs.junit)
    testImplementation(libs.robolectric)
    testImplementation(libs.roborazzi)
    testImplementation(libs.roborazzi.compose)
    testImplementation(platform(libs.compose.bom))
    testImplementation(libs.compose.ui.test.junit4)
}
