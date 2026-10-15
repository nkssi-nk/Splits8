plugins {
    alias(libs.plugins.android.application)
    alias(libs.plugins.kotlin.compose)
    alias(libs.plugins.kotlin.serialization)
}

android {
    namespace = "com.nkssi.splits8"
    compileSdk = 37

    defaultConfig {
        // 폰 · 워치 같은 이름, 같은 서명이어야 서로 주고받기가 됨
        applicationId = "com.nkssi.splits8"
        minSdk = 29          // Android 10
        targetSdk = 36
        // 워치와 겹치지 않게: 폰은 끝자리 1, 워치는 끝자리 2
        // 구글 플레이는 올릴 때마다 번호가 커져야 함 → GitHub 빌드 번호 × 10 + 1 (폰 끝자리 1, 워치 끝자리 2). 컴퓨터 빌드는 101
        versionCode = System.getenv("GITHUB_RUN_NUMBER")?.toIntOrNull()?.let { it * 10 + 1 } ?: 101
        versionName = "1.0.0"
        // 구글 지도 키: gradle.properties 의 splits8.mapsKey (또는 환경 변수 MAPS_API_KEY)
        val mapsKey = (providers.gradleProperty("splits8.mapsKey").orNull ?: "").ifBlank { System.getenv("MAPS_API_KEY") ?: "" }
        manifestPlaceholders["mapsKey"] = mapsKey
        buildConfigField("String", "MAPS_KEY", "\"$mapsKey\"")
    }
    // 고정 디버그 서명 키 (GitHub 빌드마다 키가 바뀌면 구글 로그인 등록(SHA-1)이 매번 안 맞음). 디버그용이라 비밀 아님
    signingConfigs {
        getByName("debug") {
            storeFile = file("debug.keystore")
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
            storePassword = System.getenv("SPLITS8_UPLOAD_STORE_PASSWORD")?.trim()
            keyAlias = System.getenv("SPLITS8_UPLOAD_KEY_ALIAS")?.trim()?.ifEmpty { null } ?: "upload"
            keyPassword = System.getenv("SPLITS8_UPLOAD_KEY_PASSWORD")?.trim()?.ifEmpty { null } ?: System.getenv("SPLITS8_UPLOAD_STORE_PASSWORD")?.trim()
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
    buildFeatures { compose = true; buildConfig = true }
    testOptions {
        unitTests.isIncludeAndroidResources = true
        unitTests.all {
            it.systemProperty("robolectric.graphicsMode", "NATIVE")
            it.systemProperty("roborazzi.test.record", "true")
        }
    }
}

dependencies {
    implementation(project(":shared"))
    implementation(libs.androidx.core.ktx)
    implementation(libs.androidx.activity.compose)
    implementation(libs.androidx.lifecycle.runtime.compose)
    implementation(platform(libs.compose.bom))
    implementation(libs.compose.ui)
    implementation(libs.compose.foundation)
    implementation(libs.compose.ui.tooling.preview)
    // 구글 로그인 (Credential Manager → 구글 ID 토큰 → Supabase)
    implementation(libs.androidx.credentials)
    implementation(libs.androidx.credentials.play)
    implementation(libs.googleid)
    implementation(libs.health.connect)
    // 러닝 경로 지도 (구글 지도)
    implementation(libs.maps.compose)
    // 갤럭시 워치와 주고받기 (Wearable Data Layer)
    implementation(libs.play.wearable)
    implementation(libs.kotlinx.coroutines.play)
    debugImplementation(libs.compose.ui.tooling)
    debugImplementation(libs.compose.ui.test.manifest)

    // 화면 사진 (에뮬레이터 없이 컴퓨터에서 그림): ./gradlew :app:testDebugUnitTest --tests '*Shots*'
    testImplementation(libs.junit)
    testImplementation(libs.robolectric)
    testImplementation(libs.roborazzi)
    testImplementation(libs.roborazzi.compose)
    testImplementation(platform(libs.compose.bom))
    testImplementation(libs.compose.ui.test.junit4)
}
