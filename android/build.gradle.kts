buildscript {
    repositories {
        google()
        mavenCentral()
    }
    dependencies {
        // Se mantiene la versión del plugin de Android
        classpath("com.android.tools.build:gradle:8.10.0")
        // ¡CAMBIO SUTIL! Se ajusta la versión de Kotlin para máxima compatibilidad.
        classpath("org.jetbrains.kotlin:kotlin-gradle-plugin:2.1.20")
        // Se mantiene la versión del plugin de Google Services
        classpath("com.google.gms:google-services:4.4.1")
    }
}

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.buildDir)
}

