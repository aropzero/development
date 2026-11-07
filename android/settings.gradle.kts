pluginManagement {
    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
        // Optional local offline mirror (e.g. for sandbox builds). Set via:
        //   gradle -PofflineMaven=/path/to/maven-repo
        val offline = providers.gradleProperty("offlineMaven").orNull
        if (offline != null) {
            maven { url = uri(offline) }
        }
    }
}

dependencyResolutionManagement {
    repositoriesMode.set(RepositoriesMode.FAIL_ON_PROJECT_REPOS)
    repositories {
        google()
        mavenCentral()
        val offline = providers.gradleProperty("offlineMaven").orNull
        if (offline != null) {
            maven { url = uri(offline) }
        }
    }
}

rootProject.name = "IronFrontline"
include(":app")
