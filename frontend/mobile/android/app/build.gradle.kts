import java.util.Properties

/*
 * La cle de publication, hors du depot.
 *
 * `android/key.properties` pointe sur un fichier .jks qui vit dans le dossier
 * personnel, pas dans le projet : un depot clone, une archive envoyee ou une
 * sauvegarde dans le nuage ne doit pas emporter de quoi signer l'application.
 * Les trois motifs sont deja dans `android/.gitignore`.
 *
 * Absent, la construction retombe sur la cle de debogage et le dit. C'est ce
 * qui permet a quelqu'un d'autre de compiler le projet sans detenir la cle —
 * son APK ne pourra simplement pas remplacer celui qu'on distribue.
 */
val keystoreProperties = Properties().apply {
    val fichier = rootProject.file("key.properties")
    if (fichier.exists()) fichier.inputStream().use { load(it) }
}
val hasReleaseKey = keystoreProperties.getProperty("storeFile") != null

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "gn.veriprof.app"
    compileSdk = flutter.compileSdkVersion

    // Pas de ndkVersion : aucune dependance de ce projet ne compile de code
    // natif pour Android. Drift s'appuie sur sqlite3_flutter_libs, qui fournit
    // une bibliotheque precompilee ; image_picker, secure_storage et les
    // autres plugins sont entierement en Java/Kotlin. A retablir si un plugin
    // a code natif est ajoute.

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        // Requis par flutter_local_notifications (API de dates modernes).
        isCoreLibraryDesugaringEnabled = true
    }

    defaultConfig {
        applicationId = "gn.veriprof.app"
        // Android 7.0 et plus : valeur par defaut de Flutter, compatible avec
        // les plugins utilises (drift, notifications, secure storage).
        minSdk = 24
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasReleaseKey) {
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
            /*
             * La cle de publication quand elle existe, celle de debogage sinon.
             *
             * Ce n'est pas une commodite : **deux APK signes par des cles
             * differentes ne se remplacent pas.** Android refuse la mise a jour
             * et demande de desinstaller d'abord, ce qui efface la base locale
             * de la personne. Pour une application qui circule par Bluetooth et
             * par Xender, c'est une rupture qu'on ne peut pas rattraper a
             * distance : il faut donc signer avec la meme cle des le premier
             * fichier distribue.
             */
            signingConfig = if (hasReleaseKey) {
                signingConfigs.getByName("release")
            } else {
                logger.warn(
                    "key.properties absent : APK signe avec la cle de debogage. " +
                        "Il ne pourra pas remplacer un APK de publication."
                )
                signingConfigs.getByName("debug")
            }
            isMinifyEnabled = false
            isShrinkResources = false
        }
    }

    packaging {
        resources {
            excludes += "/META-INF/{AL2.0,LGPL2.1}"
        }

        // Pas de x86_64 dans l'APK.
        //
        // Cette architecture ne sert qu'aux emulateurs : aucun telephone
        // Android vendu en Guinee ne l'execute. Elle pesait 27 Mo sur 82, et
        // l'application se distribue de main en main par Bluetooth ou Xender
        // — ces 27 Mo se paient en minutes de transfert, a chaque partage.
        //
        // Attention : cette exclusion prime sur `--target-platform`. Un build
        // lance avec `android-x64` produit quand meme un APK sans x86_64, et
        // rien ne le signale — verifie le 25/09. Pour en produire un, il faut
        // commenter la ligne ci-dessous, le temps du build.
        jniLibs {
            excludes += "lib/x86_64/**"
        }
    }

    // Neutralise le `forceNdkDownload` du plugin Gradle de Flutter.
    //
    // Flutter branche externalNativeBuild sur un CMakeLists.txt VIDE, dans le
    // seul but de convaincre AGP de telecharger le NDK (il s'en sert pour
    // retirer les symboles de debogage des .so). Aucun code natif n'est
    // compile ici. Sans le NDK (~1 Go), AGP echoue des la configuration.
    //
    // Ce bloc s'execute apres l'application des plugins mais avant que AGP ne
    // cree ses taches C/C++, donc effacer le chemin suffit a les supprimer.
    // Consequence assumee : les .so gardent leurs symboles, l'APK est un peu
    // plus gros. Sans effet sur le fonctionnement de l'application.
    externalNativeBuild {
        cmake {
            path = null
        }
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
