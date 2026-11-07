plugins {
    id("com.android.application")
}

android {
    namespace = "com.example.ironfrontline"
    compileSdk = 36

    defaultConfig {
        applicationId = "com.example.ironfrontline"
        minSdk = 24
        targetSdk = 36
        versionCode = 1
        versionName = "1.0"
    }

    buildTypes {
        release {
            isMinifyEnabled = false
            isShrinkResources = false
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
}
