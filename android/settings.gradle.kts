pluginManagement {
    val flutterSdkPath = run {
        val props = java.util.Properties()
        file("local.properties").inputStream().use { props.load(it) }
        val path = props.getProperty("flutter.sdk")
            ?: error("flutter.sdk not set in local.properties")
        path
    }

    includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")

    repositories {
        // ƯU TIÊN 2 cái này trước để tải plugin ổn định
        gradlePluginPortal()
        google()
        mavenCentral()
        // Kho Flutter engine (bắt buộc để tải io.flutter:*)
        maven {
            val base = System.getenv("FLUTTER_STORAGE_BASE_URL") ?: "https://storage.googleapis.com"
            url = uri("$base/download.flutter.io")
        }

        // Mirrors cho mavenCentral (OK)
        maven { url = uri("https://maven-central.storage-download.googleapis.com/maven2") }
        maven { url = uri("https://repo1.maven.org/maven2") }
        maven { url = uri("https://repo.huaweicloud.com/repository/maven/") }

        // ❌ Không dùng Aliyun ở đây (nếu cần, để CUỐI và chỉ bật khi bắt buộc)
        // maven { url = uri("https://maven.aliyun.com/repository/gradle-plugin") }
    }

    // Map plugin -> module để có thể tải thẳng từ Google Maven/Plugin Portal
    resolutionStrategy {
        eachPlugin {
            if (requested.id.id.startsWith("org.jetbrains.kotlin")) {
                useModule("org.jetbrains.kotlin:kotlin-gradle-plugin:1.8.22")
            }
            if (requested.id.id == "com.android.application") {
                useModule("com.android.tools.build:gradle:${requested.version}")
            }
            if (requested.id.id == "com.google.gms.google-services") {
                useModule("com.google.gms:google-services:${requested.version}")
            }
        }
    }
}


plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    id("com.android.application") version "8.7.0" apply false
    // START: FlutterFire Configuration
    id("com.google.gms.google-services") version ("4.3.15") apply false
    // END: FlutterFire Configuration
    id("org.jetbrains.kotlin.android") version "1.8.22" apply false
}

dependencyResolutionManagement {
    repositoriesMode.set(RepositoriesMode.PREFER_SETTINGS)
    repositories {
        google()
        mavenCentral()
        // Kho Flutter engine (bắt buộc để tải io.flutter:*)
        maven {
            val base = System.getenv("FLUTTER_STORAGE_BASE_URL") ?: "https://storage.googleapis.com"
            url = uri("$base/download.flutter.io")
        }


        // Mirrors trước
        maven { url = uri("https://maven-central.storage-download.googleapis.com/maven2") }
        maven { url = uri("https://repo1.maven.org/maven2") }
        maven { url = uri("https://repo.huaweicloud.com/repository/maven/") }
        // maven { url = uri("https://maven.aliyun.com/repository/central") }
        maven { url = uri("https://storage.googleapis.com/download.flutter.io") }

        // Fallback cuối
        //mavenCentral()
    }
}

include(":app")
