plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// google-services.json is not committed. Apply the Firebase Gradle plugins only
// when it is present so builds without it (CI, fresh checkouts) keep working.
if (file("google-services.json").exists()) {
    apply(plugin = "com.google.gms.google-services")
    apply(plugin = "com.google.firebase.crashlytics")
    // The mapping-file upload needs Groovy XML classes (groovy.util.XmlSlurper)
    // that this Gradle version no longer ships, so it fails the release build.
    tasks.whenTaskAdded {
        if (name.startsWith("uploadCrashlyticsMappingFile")) {
            enabled = false
        }
    }
}

android {
    namespace = "com.yourwish.komovia_go"
    compileSdk = 36  // Updated to 36 to satisfy in_app_purchase_android and androidx dependency requirements
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // Unique Application ID for GoEn (碁縁)
        applicationId = "com.yourwish.komovia_go"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = 36  // Set to 36 to match compileSdk and plugin dependencies
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        // Release signing config - loads from environment or gradle.properties
        create("release") {
            // Resolved relative to this file's own directory (android/app/),
            // not the android/ project root -- so the path here must be
            // "komovia_go-release.keystore", not "app/komovia_go-release.keystore" (that
            // would double up to android/app/app/komovia_go-release.keystore).
            storeFile = file(
                System.getenv("ANDROID_KEYSTORE_PATH")
                    ?: project.findProperty("ANDROID_KEYSTORE_PATH") as String?
                    ?: "komovia_go-release.keystore"
            )
            storePassword = System.getenv("ANDROID_KEYSTORE_PASSWORD")
                ?: project.findProperty("ANDROID_KEYSTORE_PASSWORD") as String?
                ?: "changeme"
            keyAlias = System.getenv("ANDROID_KEY_ALIAS")
                ?: project.findProperty("ANDROID_KEY_ALIAS") as String?
                ?: "komovia_go-key"
            keyPassword = System.getenv("ANDROID_KEY_PASSWORD")
                ?: project.findProperty("ANDROID_KEY_PASSWORD") as String?
                ?: "changeme"
        }
    }

    buildTypes {
        release {
            // Sign with release keystore (from env vars or gradle.properties)
            signingConfig = signingConfigs.getByName("release")
            proguardFiles("proguard-rules.pro")
            // Older Crashlytics SDKs look up their build-id string resource by name,
            // which the resource shrinker removes.
            isMinifyEnabled = true
            isShrinkResources = false
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
