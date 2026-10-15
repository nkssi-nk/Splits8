// Maven Central 이 가끔 받기를 막음(GitHub 빌드 #24 실패) → 같은 내용의 구글 미러를 뒤에 하나 더 둠 (앞에서 못 찾으면 여기서)
val centralMirror = "https://maven-central.storage-download.googleapis.com/maven2/"

pluginManagement {
    repositories {
        google()
        mavenCentral()
        maven("https://maven-central.storage-download.googleapis.com/maven2/")
        gradlePluginPortal()
    }
}

dependencyResolutionManagement {
    repositoriesMode.set(RepositoriesMode.FAIL_ON_PROJECT_REPOS)
    repositories {
        google()
        mavenCentral()
        maven(centralMirror)
    }
}

rootProject.name = "Splits8"

include(":shared") // 규칙 · 데이터 (아이폰 Shared 와 같은 역할)
include(":app")    // 폰
include(":wear")   // 갤럭시 워치 (Wear OS)
