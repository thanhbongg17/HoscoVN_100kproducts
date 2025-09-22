plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    id("com.google.gms.google-services")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.hoscocorp.notifications_app"
    compileSdk = flutter.compileSdkVersion

    // BẮT BUỘC: khớp với yêu cầu của firebase_* (NDK 27)
    ndkVersion = "27.0.12077973"

    defaultConfig {
        applicationId = "com.hoscocorp.notifications_app"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    // Java 17 + desugaring để fix lỗi AAR metadata
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = "17"
    }

    buildTypes {
        release {
            // tạm ký bằng debug để `flutter run --release` chạy được
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

dependencies {
    // BẮT BUỘC khi bật desugaring
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.4")
}

flutter {
    source = "../.."
}
