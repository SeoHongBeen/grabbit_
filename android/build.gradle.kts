plugins {
    // Android Gradle Plugin은 flutter-gradle-plugin이 관리하므로 여기서 선언하지 않음
    // id("com.android.application") version "8.5.2" apply false  // ❌ 삭제
    // kotlin("android") version "1.9.x" apply false               // ❌ 삭제

    // Google Services만 버전 명시해서 제공
    id("com.google.gms.google-services") version "4.4.2" apply false
}

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory = rootProject.layout.buildDirectory.dir("../../build").get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}


