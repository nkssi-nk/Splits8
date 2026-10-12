pluginManagement {
    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

dependencyResolutionManagement {
    repositoriesMode.set(RepositoriesMode.FAIL_ON_PROJECT_REPOS)
    repositories {
        google()
        mavenCentral()
    }
}

rootProject.name = "Splits8"

include(":shared") // 규칙 · 데이터 (아이폰 Shared 와 같은 역할)
include(":app")    // 폰
include(":wear")   // 갤럭시 워치 (Wear OS)
