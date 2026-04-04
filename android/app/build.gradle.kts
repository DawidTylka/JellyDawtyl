import java.util.Properties
import java.io.FileInputStream

// --- Wczytywanie pliku .env (do reklam) ---
val envProperties = Properties()
val envFile = rootProject.file("../.env")
if (envFile.exists()) {
    envProperties.load(FileInputStream(envFile))
}

// --- Wczytywanie pliku key.properties (do podpisania apki) ---
val keystoreProperties = Properties()
val keystorePropertiesFile = project.file("key.properties") 
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.flutter_application_1"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = "17"
    }

    // KONFIGURACJA PODPISYWANIA
    signingConfigs {
        create("release") {
            val alias = keystoreProperties["keyAlias"] as String?
            val password = keystoreProperties["keyPassword"] as String?
            val storeFilePath = keystoreProperties["storeFile"] as String?
            val storePassword = keystoreProperties["storePassword"] as String?

            if (alias != null && password != null && storeFilePath != null && storePassword != null) {
                keyAlias = alias
                keyPassword = password
                storeFile = file(storeFilePath)
                this.storePassword = storePassword
            }
        }
    }

    defaultConfig {
        applicationId = "com.example.flutter_application_1"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        
        val admobId = envProperties.getProperty("ADMOB_APP_ID_ANDROID") ?: "ca-app-pub-3940256099942544~3347511713"
        manifestPlaceholders["admobAppId"] = admobId
    }

    buildTypes {
        release {
            // Ustawienie podpisu release
            signingConfig = signingConfigs.getByName("release")
            
            isMinifyEnabled = false 
            isShrinkResources = false 
            
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