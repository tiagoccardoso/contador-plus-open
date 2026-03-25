// android/app/build.gradle.kts

import java.util.Properties

// Carrega key.properties, se existir (para assinar release)
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(keystorePropertiesFile.inputStream())
}

plugins {
    id("com.android.application")
    kotlin("android")
    // O plugin do Flutter deve vir após os plugins de Android e Kotlin
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    // Ajuste para o seu pacote final (ex.: br.com.suaempresa.contador_plus)
    namespace = "com.tiagoccardoso.contadorplus"

    // Use os valores do Flutter (expostos pelo plugin)
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "27.0.12077973"

    defaultConfig {
        applicationId = "com.tiagoccardoso.contadorplus" // ajuste se necessário
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    // AGP/Flutter recentes requerem Java 17
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
    kotlinOptions {
        jvmTarget = "17"
    }

    signingConfigs {
        // Cria a config de release apenas se houver key.properties
        if (keystorePropertiesFile.exists()) {
            create("release") {
                storeFile = file(keystoreProperties.getProperty("storeFile"))
                storePassword = keystoreProperties.getProperty("storePassword")
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            isMinifyEnabled = true
            // ProGuard padrão + arquivo do projeto (crie "android/app/proguard-rules.pro" se ainda não existir)
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )

            // Se não houver keystore de release, usa a de debug para não travar o build
            signingConfig = signingConfigs.findByName("release")
                ?: signingConfigs.getByName("debug")
        }
        debug {
            isMinifyEnabled = false
        }
    }

    // Evita conflitos de licenças/recursos
    packaging {
        resources {
            excludes += "/META-INF/{AL2.0,LGPL2.1}"
        }
    }
}

// Bloco do Flutter — aponta para a raiz do projeto Dart/Flutter
flutter {
    source = "../.."
}
