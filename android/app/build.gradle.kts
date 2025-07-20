plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

// Importa las clases necesarias
import java.util.Properties
import java.io.FileInputStream

// Carga las propiedades del keystore de forma segura
val keystorePropertiesFile = rootProject.file("../keystore.properties")
val keystoreProperties = Properties()
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "com.vito.habits"
    compileSdk = 35
    ndkVersion = "27.0.12077973"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_1_8
        targetCompatibility = JavaVersion.VERSION_1_8
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = "1.8"
    }

    // --- CONFIGURACIÓN DE FIRMA ---
    // Se añade la configuración para 'release'
    signingConfigs {
        create("release") {
            storeFile = file(keystoreProperties.getProperty("storeFile", "../app/vito-key.jks"))
            storePassword = keystoreProperties.getProperty("storePassword")
            keyAlias = keystoreProperties.getProperty("keyAlias")
            keyPassword = keystoreProperties.getProperty("keyPassword")
        }
    }

    defaultConfig {
        applicationId = "com.vito.habits"
        minSdk = 23
        targetSdk = 35
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        ndk {
            abiFilters += listOf("x86", "x86_64", "armeabi-v7a", "arm64-v8a")
        }
    }

    buildTypes {
        release {
            // --- ASIGNACIÓN DE FIRMA ---
            // Se asigna la nueva firma de release
            signingConfig = signingConfigs.getByName("release")

            isMinifyEnabled = true
            isShrinkResources = true
            
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
        debug {
            signingConfig = signingConfigs.getByName("debug")
            isMinifyEnabled = false
            isShrinkResources = false
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    implementation("androidx.core:core-ktx:1.12.0")
    implementation("androidx.work:work-runtime-ktx:2.9.0")
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}

// Se mantiene tu bloque de tareas personalizadas
afterEvaluate {
    tasks.register("copyFlutterApk") {
        doLast {
            val sourceApk = file("build/outputs/apk/debug/app-debug.apk")
            val destDir = file("../../build/app/outputs/flutter-apk")
            
            if (sourceApk.exists()) {
                destDir.mkdirs()
                sourceApk.copyTo(
                    file("${destDir}/app-debug.apk"),
                    overwrite = true
                )
                println("APK copiado a: ${destDir}/app-debug.apk")
            }
        }
    }
    
    tasks.findByName("assembleDebug")?.finalizedBy("copyFlutterApk")
    
    // También para release
    tasks.register("copyFlutterApkRelease") {
        doLast {
            val sourceApk = file("build/outputs/apk/release/app-release.apk")
            val destDir = file("../../build/app/outputs/flutter-apk")
            
            if (sourceApk.exists()) {
                destDir.mkdirs()
                sourceApk.copyTo(
                    file("${destDir}/app-release.apk"),
                    overwrite = true
                )
                println("APK release copiado a: ${destDir}/app-release.apk")
            }
        }
    }
    
    tasks.findByName("assembleRelease")?.finalizedBy("copyFlutterApkRelease")

    tasks.register("copyFlutterAabRelease") {
        doLast {
            val sourceAab = file("build/outputs/bundle/release/app-release.aab")
            val destDir = file("../../build/app/outputs/bundle/release")

            if (sourceAab.exists()) {
                destDir.mkdirs()
                sourceAab.copyTo(
                    file("${destDir}/app-release.aab"),
                    overwrite = true
                )
                println("AAB de Release copiado a: ${destDir}/app-release.aab")
            } else {
                println("ADVERTENCIA: No se encontró app-release.aab en la ruta de origen.")
            }
        }
    }

    tasks.findByName("bundleRelease")?.finalizedBy("copyFlutterAabRelease")
}