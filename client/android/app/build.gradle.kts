plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "de.communityaccess.app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "de.communityaccess.app"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = maxOf(36, flutter.targetSdkVersion)
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (System.getenv("CA_ANDROID_KEYSTORE") != null) {
            create("storeUpload") {
                storeFile = file(System.getenv("CA_ANDROID_KEYSTORE"))
                storePassword = System.getenv("CA_ANDROID_STORE_PASSWORD")
                keyAlias = System.getenv("CA_ANDROID_KEY_ALIAS")
                keyPassword = System.getenv("CA_ANDROID_KEY_PASSWORD")
            }
        }
    }

    buildTypes {
        release {
            // An absent upload key produces an unsigned candidate, never a
            // release signed with the public development key.
            signingConfig = signingConfigs.findByName("storeUpload")
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
