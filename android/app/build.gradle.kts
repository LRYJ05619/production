plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.production"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.example.production"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
        }
    }

    applicationVariants.all {
        val variant = this
        variant.outputs
            .map { it as com.android.build.gradle.internal.api.BaseVariantOutputImpl }
            .forEach { output ->
                if (variant.buildType.name == "release") {
                    output.outputFileName = "生产管理软件V${variant.versionName}.apk"
                }
            }
    }
}

// Flutter release构建完成后自动重命名APK
tasks.whenTaskAdded {
    if (name == "assembleRelease") {
        doLast {
            val apkDir = file("${buildDir}/outputs/flutter-apk")
            val src = File(apkDir, "app-release.apk")
            val versionName = android.defaultConfig.versionName ?: "unknown"
            val dst = File(apkDir, "生产管理软件V${versionName}.apk")
            if (src.exists()) {
                src.copyTo(dst, overwrite = true)
                src.delete()
            }
        }
    }
}

flutter {
    source = "../.."
}
