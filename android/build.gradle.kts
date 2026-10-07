allprojects {
    repositories {
        google()
        mavenCentral()
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
// Older Firebase plugins are compiled against android-33, but their AndroidX
// dependencies require API 34+, which fails checkReleaseAarMetadata.
subprojects {
    afterEvaluate {
        extensions
            .findByType(com.android.build.api.dsl.LibraryExtension::class.java)
            ?.let { it.compileSdk = 36 }
    }
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
