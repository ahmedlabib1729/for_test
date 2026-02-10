plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.emplyee_app_att"
    compileSdk = 36
    ndkVersion = "27.0.12077973"

    compileOptions {
        // تفعيل core library desugaring
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        applicationId = "com.example.emplyee_app_att"
        minSdk = 21  // تغيير مهم: يجب أن يكون 21 أو أكثر
        targetSdk = 34  // تغيير مهم: يجب أن يكون 33 أو أكثر
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        // إضافة اختيارية للتطبيقات الكبيرة
        multiDexEnabled = true
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Create a keystore and reference it here before publishing.
            // See: https://developer.android.com/studio/publish/app-signing
            signingConfig = signingConfigs.getByName("debug")

            // Enable R8/ProGuard for code shrinking and obfuscation
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    // إضافة مهمة لـ flutter_local_notifications
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.4")
}