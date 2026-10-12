import java.util.Properties
import org.gradle.api.logging.LogLevel

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Secrets live outside version control:
//  * android/local.properties  -> MAPS_API_KEY=...
//  * android/key.properties    -> storeFile, storePassword, keyAlias, keyPassword
val localProperties = Properties().apply {
    val file = rootProject.file("local.properties")
    if (file.exists()) file.inputStream().use { load(it) }
}
val keystoreProperties = Properties().apply {
    val file = rootProject.file("key.properties")
    if (file.exists()) file.inputStream().use { load(it) }
}
val hasReleaseKeystore = keystoreProperties.getProperty("storeFile") != null
// Blank counts as missing: an unset CI secret arrives as an empty string.
val mapsApiKey: String? =
    listOf(localProperties.getProperty("MAPS_API_KEY"), System.getenv("MAPS_API_KEY"))
        .firstOrNull { !it.isNullOrBlank() }
        ?.trim()

// Demo build (preview/main_preview.dart): pass -PjdDemo=true, or set the
// environment variable ORG_GRADLE_PROJECT_jdDemo=true as .github/workflows/
// build.yml does. The demo gets its own package name and launcher label, so it
// installs next to the real app and never replaces it. It is signed with the
// public demo-only key in demo-signing/, so each new demo APK installs as an
// update.
val isDemoBuild = findProperty("jdDemo")?.toString().equals("true", ignoreCase = true)
if (isDemoBuild) {
    // The demo never connects to Firebase and com.jetalpurdham.app.demo is not
    // registered there. Once `flutterfire configure` adds the Google Services
    // and Crashlytics Gradle plugins, their tasks would fail the demo build
    // ("No matching client found for package name"), so skip them. Until then
    // no task matches and this does nothing.
    tasks.configureEach {
        if (name.contains("GoogleServices") || name.contains("Crashlytics")) enabled = false
    }
}
val demoKeystore = file("demo-signing/demo.keystore")
if (hasReleaseKeystore &&
    file(keystoreProperties.getProperty("storeFile")).canonicalFile == demoKeystore.canonicalFile
) {
    throw GradleException(
        "android/key.properties points at the public demo key. Sign the real app " +
            "with the temple's upload key (docs/FIREBASE_SETUP.md, step 14).",
    )
}

// Release builds keep working without the secrets (CI, `flutter run --release`)
// but say so loudly, so nobody uploads or shares such a build by mistake.
val releaseWarnings = buildList {
    if (!isDemoBuild && !hasReleaseKeystore) {
        add(
            "android/key.properties is missing, so this release build is signed with the " +
                "DEBUG key. Google Play rejects it and testers cannot update it to a properly " +
                "signed build. Do not upload or share it (docs/FIREBASE_SETUP.md, step 14).",
        )
    }
    if (!isDemoBuild && mapsApiKey == null) {
        add(
            "MAPS_API_KEY is not set (android/local.properties or environment), so this " +
                "release build has a placeholder Google Maps key and the Prasadi map stays " +
                "blank (docs/FIREBASE_SETUP.md, step 8).",
        )
    }
}
if (gradle.startParameter.taskNames.any { it.contains("Release", ignoreCase = true) }) {
    // `flutter build` runs Gradle with -q, which hides logger.warn, so drop to
    // QUIET level there to stay visible. GitHub Actions also shows annotations.
    val level = if (logger.isWarnEnabled) LogLevel.WARN else LogLevel.QUIET
    releaseWarnings.forEach { message ->
        logger.log(level, "WARNING: $message")
        if (System.getenv("GITHUB_ACTIONS") == "true") {
            logger.quiet("::warning title=Android release build::$message")
        }
    }
    if (isDemoBuild) {
        logger.quiet("Demo build: com.jetalpurdham.app.demo, signed with the public demo key.")
    }
}

android {
    namespace = "com.jetalpurdham.app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        // Required by flutter_local_notifications.
        isCoreLibraryDesugaringEnabled = true
    }

    defaultConfig {
        applicationId = "com.jetalpurdham.app"
        if (isDemoBuild) applicationIdSuffix = ".demo"
        // 24 covers 99%+ of active Android devices and every plugin in use.
        minSdk = maxOf(24, flutter.minSdkVersion)
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        multiDexEnabled = true
        manifestPlaceholders["appLabel"] =
            if (isDemoBuild) "Jetalpur Dham Demo" else "Jetalpur Dham"
        manifestPlaceholders["mapsApiKey"] = mapsApiKey ?: "REPLACE_WITH_GOOGLE_MAPS_API_KEY"
    }

    signingConfigs {
        if (hasReleaseKeystore) {
            create("release") {
                storeFile = file(keystoreProperties.getProperty("storeFile"))
                storePassword = keystoreProperties.getProperty("storePassword")
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
            }
        }
        if (isDemoBuild) {
            // Public, demo-only key (see demo-signing/README.md). Never use it
            // for the real app.
            create("demo") {
                storeFile = demoKeystore
                storePassword = "jetalpur-demo"
                keyAlias = "jd-demo"
                keyPassword = "jetalpur-demo"
            }
        }
    }

    buildTypes {
        release {
            // The demo always uses the demo key. The real app falls back to
            // debug signing (with the warning above) so `flutter run --release`
            // and CI work before a release keystore is configured.
            signingConfig = when {
                isDemoBuild -> signingConfigs.getByName("demo")
                hasReleaseKeystore -> signingConfigs.getByName("release")
                else -> signingConfigs.getByName("debug")
            }
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5")
}

flutter {
    source = "../.."
}
