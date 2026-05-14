// android/build.gradle.kts

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

// Custom build directory
val newBuildDir = rootProject.layout.buildDirectory.dir("../../build").get()

// Set root project build directory
rootProject.layout.buildDirectory.set(newBuildDir)

// Set subprojects build directories
subprojects {

    val newSubprojectBuildDir = newBuildDir.dir(project.name)

    project.layout.buildDirectory.set(newSubprojectBuildDir)

    project.evaluationDependsOn(":app")
}

// Clean task
tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}