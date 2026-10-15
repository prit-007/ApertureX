import com.android.build.gradle.api.ApkVariantOutput
import java.io.FileInputStream
import java.util.Properties

// Per-ABI version codes (F-Droid's required scheme, ADR 0004): base
// versionCode ×10 + ABI offset → base 1 = 11 (armeabi-v7a), 12 (arm64-v8a),
// 13 (x86_64). docs/fdroid-metadata.yml accepts them via VercodeOperation.
val abiCodes = mapOf("armeabi-v7a" to 1, "arm64-v8a" to 2, "x86_64" to 3)

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Release signing comes from android/key.properties (never committed). Without
// it, release builds fall back to the debug key so `flutter build` still works.
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "com.devparadise.tessera"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.devparadise.tessera"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (keystorePropertiesFile.exists()) {
            create("release") {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (keystorePropertiesFile.exists()) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

// F-Droid/Play ABI-split version codes, matching the `%c * 10 + {1,2,3}` scheme
// (ADR 0004): base versionCode 1 → 11 (armeabi-v7a), 12 (arm64-v8a), 13 (x86_64).
//
// This MUST be `applicationVariants.configureEach` (registered after the Flutter
// plugin's own configureEach in FlutterPlugin.kt, which sets `abi*1000+base`):
// configureEach actions run in registration order, so this block runs last and
// wins. `androidComponents.onVariants` runs at a different point in AGP 9 and
// ends up overwritten by the plugin's `abi*1000+base`.
@Suppress("DEPRECATION")
android.applicationVariants.configureEach {
    val variant = this
    variant.outputs.forEach { output ->
        val abiVersionCode =
            abiCodes[output.filters.find { it.filterType == "ABI" }?.identifier]
        if (abiVersionCode != null) {
            (output as ApkVariantOutput).versionCodeOverride =
                variant.versionCode * 10 + abiVersionCode
        }
    }
}

flutter {
    source = "../.."
}
