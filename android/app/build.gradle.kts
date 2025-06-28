// android/app/build.gradle.kts
plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

android {
    namespace = "com.example.vito_app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "27.0.12077973"
    
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_1_8
        targetCompatibility = JavaVersion.VERSION_1_8
        isCoreLibraryDesugaringEnabled = true
    }
    
    kotlinOptions {
        jvmTarget = "1.8"
    }
    
    defaultConfig {
        applicationId = "com.vito.habits"
        
        // CORRECCIÓN FINAL: Se aumenta la versión mínima de Android a 23.
        // Esto satisface el requisito de la librería de Firebase Auth.
        minSdk = 23
        
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        
        // IMPORTANTE: Agregar soporte para múltiples arquitecturas
        ndk {
            abiFilters += listOf("x86", "x86_64", "armeabi-v7a", "arm64-v8a")
        }
    }
    
    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
        }
        debug {
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.4")
}

// SOLUCIÓN PERMANENTE PARA EL ERROR DE APK NO ENCONTRADO
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
            // 1. Ruta donde Gradle genera el .aab
            val sourceAab = file("build/outputs/bundle/release/app-release.aab")
            // 2. Ruta donde la herramienta de Flutter lo busca
            val destDir = file("../../build/app/outputs/bundle/release")

            if (sourceAab.exists()) {
                // 3. Creamos la carpeta de destino si no existe
                destDir.mkdirs()
                // 4. Copiamos el archivo
                sourceAab.copyTo(
                    file("${destDir}/app-release.aab"),
                    overwrite = true
                )
                println("AAB de Release copiado a: ${destDir}/app-release.aab")
            } else {
                // Un mensaje por si algo sale mal en el futuro
                println("ADVERTENCIA: No se encontró app-release.aab en la ruta de origen.")
            }
        }
    }

    // 5. Le decimos a Gradle que ejecute nuestra tarea justo después de crear el bundle
    tasks.findByName("bundleRelease")?.finalizedBy("copyFlutterAabRelease")
}

