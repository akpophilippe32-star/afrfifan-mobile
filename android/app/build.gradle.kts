plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android") // ✅ AJOUTÉ : C'est LE plugin manquant qui compile ton MainActivity.kt !
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.afrifan"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "27.0.12077973"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.example.afrifan"
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
}

flutter {
    source = "../.."
}