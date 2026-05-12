plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

configurations.all {
    resolutionStrategy.dependencySubstitution {
        substitute(module("com.yandex.android:maps.mobile"))
            .using(module("com.yandex.maps:maps.mobile:4.33.1-beta-full-flutter"))
            .because("yandex_maps_mapkit (full) requires Flutter-specific native symbols")
    }
}

android {
    namespace = "com.example.tour2tour_app"
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
        applicationId = "com.example.tour2tour_app"
        minSdk = 26
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

dependencies {
    implementation("com.google.android.gms:play-services-location:21.1.0")
    implementation("androidx.work:work-runtime:2.9.0")
}
