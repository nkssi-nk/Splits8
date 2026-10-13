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
        versionCode = 102
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
    buildTypes {
        debug { signingConfig = signingConfigs.getByName("debug") }
        release {
            isMinifyEnabled = false
        }
    }
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
    buildFeatures { compose = true }
}

dependencies {
    implementation(project(":shared"))
    implementation(libs.androidx.core.ktx)
    implementation(libs.androidx.activity.compose)
    implementation(platform(libs.compose.bom))
    implementation(libs.compose.ui)
    implementation(libs.wear.compose.foundation)
    implementation(libs.wear.compose.material3)
    implementation(libs.compose.ui.tooling.preview)
    debugImplementation(libs.compose.ui.tooling)
}
