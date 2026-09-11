import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

android {
    namespace = "com.example.marketplace"
    // Pinned explicitly (highest installed platform) instead of flutter.compileSdkVersion
    // so plugin bumps don't silently change the compile target.
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        applicationId = "com.example.marketplace"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        // Pinned for Google Play target-API compliance (API 35 required from Aug 2025).
        targetSdk = 35
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        resValue("string", "app_name", "Secondhand Marketplace")

        // Google Maps key is injected from local.properties (untracked) rather
        // than committed in AndroidManifest.xml. Add `MAPS_API_KEY=...` to
        // android/local.properties. Restrict this key in Google Cloud Console.
        val mapsKey: String = run {
            val props = Properties()
            val f = rootProject.file("local.properties")
            if (f.exists()) f.inputStream().use { props.load(it) }
            props.getProperty("MAPS_API_KEY") ?: ""
        }
        manifestPlaceholders["MAPS_API_KEY"] = mapsKey
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")

            // R8 code shrinking + resource shrinking for smaller release APKs.
            // Keep rules live in proguard-rules.pro.
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
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.4")
    implementation("androidx.appcompat:appcompat:1.6.1")
}
