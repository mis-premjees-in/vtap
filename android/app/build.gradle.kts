plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

android {

    namespace = "com.premjees.vtap"

    compileSdk = 36

    ndkVersion = "28.2.13676358"

    defaultConfig {

        applicationId = "com.premjees.vtap"

        minSdk = flutter.minSdkVersion

        targetSdk = 36

        versionCode = 1

        versionName = "1.0"
    }

    compileOptions {

        isCoreLibraryDesugaringEnabled = true

        sourceCompatibility = JavaVersion.VERSION_17

        targetCompatibility = JavaVersion.VERSION_17
    }

    buildFeatures {
        buildConfig = true
    }

    kotlinOptions {
        jvmTarget = "17"
    }

    buildTypes {

        release {

            signingConfig = signingConfigs.getByName("debug")

            isMinifyEnabled = true

            isShrinkResources = true

            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }
    // Add this block to rename the output APK
    applicationVariants.all {
        val variant = this
        outputs.all {
            val output = this as com.android.build.gradle.internal.api.BaseVariantOutputImpl
            // This will name it something like: MyCustomAppName-release.apk
            output.outputFileName = "VTAP-${variant.buildType.name}.apk"
        }
    }
}

flutter {
    source = "../.."
}

dependencies {

    coreLibraryDesugaring(
        "com.android.tools:desugar_jdk_libs:2.1.4"
    )

    implementation(
        "androidx.core:core-ktx:1.13.1"
    )

    implementation(
        "androidx.activity:activity-ktx:1.9.3"
    )
}
