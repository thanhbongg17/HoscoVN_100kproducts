// android/build.gradle.kts (PROJECT-LEVEL)

//plugins {
//    // ĐỂ FLUTTER QUẢN LÝ VERSION (đừng ghi version ở đây)
//    id("com.android.application") apply false
//    id("com.android.library") apply false
//    id("org.jetbrains.kotlin.android") apply false
//
//    // Google Services plugin: cần version
//    //id("com.google.gms.google-services") version "4.4.2" apply false
//
//    // Flutter Gradle plugin loader (apply false ở project)
//    id("dev.flutter.flutter-gradle-plugin") version "1.0.0" apply false
//}

//allprojects {
//    repositories {
//        google()
//        mavenCentral()
//    }
//}

// Tuỳ biến buildDir của bạn
val newBuildDir: Directory = rootProject.layout.buildDirectory.dir("../../build").get()
rootProject.layout.buildDirectory.value(newBuildDir)

// Gộp 2 block subprojects thành 1 và sửa dấu '{'
subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)

    // Đảm bảo dự án con phụ thuộc đánh giá từ :app
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
