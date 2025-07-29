plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.advantage.crf_android"
    compileSdk = 34

    defaultConfig {
        applicationId = "com.advantage.crf_android"
        minSdk = 21
        targetSdk = 34
        versionCode = 1
        versionName = "1.0.0"
        multiDexEnabled = true
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = "17"
    }

    sourceSets {
        getByName("main").java.srcDirs("src/main/kotlin")
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
            isMinifyEnabled = false
            proguardFiles(getDefaultProguardFile("proguard-android.txt"), "proguard-rules.pro")
            isShrinkResources = false
        }
        debug {
            isMinifyEnabled = false
            isShrinkResources = false
        }
    }

    lint {
        disable.add("InvalidPackage")
        checkReleaseBuilds = false
        abortOnError = false
    }

    packaging {
        resources {
            excludes.add("META-INF/DEPENDENCIES")
            excludes.add("META-INF/LICENSE")
            excludes.add("META-INF/LICENSE.txt")
            excludes.add("META-INF/license.txt")
            excludes.add("META-INF/NOTICE")
            excludes.add("META-INF/NOTICE.txt")
            excludes.add("META-INF/notice.txt")
            excludes.add("META-INF/ASL2.0")
            excludes.add("META-INF/*.kotlin_module")
            pickFirsts.add("**/*.so")
        }
    }
}

dependencies {
    implementation("androidx.multidex:multidex:2.0.1")
}

flutter {
    source = "../.."
} 