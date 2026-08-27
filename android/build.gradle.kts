allprojects {
    repositories {
        google()
        mavenCentral()
    }
    afterEvaluate {
        val androidExt = extensions.findByName("android")
        if (androidExt is com.android.build.gradle.BaseExtension) {
            androidExt.compileSdkVersion(36)
            androidExt.ndkVersion = "27.0.12077973"
            androidExt.buildToolsVersion = "36.0.0"
        }
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}

subprojects {
    plugins.withId("com.android.library") {
        val androidExt = extensions.findByType(com.android.build.gradle.LibraryExtension::class.java)
        androidExt?.ndkVersion = "27.0.12077973"
    }
    plugins.withId("com.android.application") {
        val androidExt = extensions.findByType(com.android.build.gradle.AppExtension::class.java)
        androidExt?.ndkVersion = "27.0.12077973"
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
