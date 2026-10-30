plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "dev.uwa.dracinreels"
    // compileSdk 36: file_picker's flutter_plugin_android_lifecycle
    // dependency requires consumers to compile against API 36+.
    // minSdk stays 21 so the 32-bit phone can still install.
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "dev.uwa.dracinreels"
        minSdk = 21
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    // Keystore RILIS permanen (bukan debug): dibaca dari environment
    // yang diisi workflow dari repo secrets. Rilis lama memakai
    // signingConfig debug — keystore debug runner dibuat baru tiap
    // run, jadi tiap rilis punya tanda tangan berbeda dan Android
    // menolak update ("paket bentrok"). Bila environment kosong,
    // build release GAGAL dengan jelas (tidak diam-diam memakai
    // debug) — rilis hanya boleh ditandatangani keystore permanen.
    signingConfigs {
        create("release") {
            val keystorePath = System.getenv("ANDROID_KEYSTORE_PATH")
            if (!keystorePath.isNullOrEmpty()) {
                storeFile = file(keystorePath)
                storePassword = System.getenv("ANDROID_KEYSTORE_PASSWORD")
                keyAlias = System.getenv("ANDROID_KEY_ALIAS")
                keyPassword = System.getenv("ANDROID_KEY_PASSWORD")
            }
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
