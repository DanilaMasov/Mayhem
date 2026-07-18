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
    namespace = "com.danilamasov.mayhem"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.danilamasov.mayhem"
        minSdk = 29
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    flavorDimensions += "environment"
    productFlavors {
        create("production") {
            dimension = "environment"
            manifestPlaceholders["appLabel"] = "MAYHEM"
        }
        create("staging") {
            dimension = "environment"
            applicationIdSuffix = ".staging"
            versionNameSuffix = "-staging"
            manifestPlaceholders["appLabel"] = "MAYHEM STAGING"
        }
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
