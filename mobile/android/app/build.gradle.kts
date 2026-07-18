plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val releaseSigning = mapOf(
    "storeFile" to System.getenv("MAYHEM_ANDROID_KEYSTORE_PATH"),
    "storePassword" to System.getenv("MAYHEM_ANDROID_KEYSTORE_PASSWORD"),
    "keyAlias" to System.getenv("MAYHEM_ANDROID_KEY_ALIAS"),
    "keyPassword" to System.getenv("MAYHEM_ANDROID_KEY_PASSWORD"),
)
val configuredReleaseSigningValues = releaseSigning.values.count { !it.isNullOrBlank() }
if (configuredReleaseSigningValues != 0 && configuredReleaseSigningValues != releaseSigning.size) {
    throw GradleException("Android release signing requires all MAYHEM_ANDROID_* variables")
}
val releaseSigningConfigured = configuredReleaseSigningValues == releaseSigning.size

android {
    namespace = "com.mayhem.social.mayhem_mobile"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.mayhem.social.mayhem_mobile"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        // flutter_secure_storage 10 uses Android Keystore APIs from API 23.
        minSdk = 23
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (releaseSigningConfigured) {
            create("release") {
                storeFile = file(releaseSigning.getValue("storeFile")!!)
                storePassword = releaseSigning.getValue("storePassword")
                keyAlias = releaseSigning.getValue("keyAlias")
                keyPassword = releaseSigning.getValue("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            if (releaseSigningConfigured) {
                signingConfig = signingConfigs.getByName("release")
            }
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
