val flutterSdkPath = run {
    val properties = java.util.Properties()
    file("local.properties").inputStream().use { properties.load(it) }
    properties.getProperty("flutter.sdk")
}
val engineVersion = file("$flutterSdkPath/bin/internal/engine.version").readText().trim()

allprojects {
    repositories {
        google()
        mavenCentral()
    }
    configurations.all {
        resolutionStrategy.eachDependency {
            if (requested.group == "io.flutter" && requested.name.startsWith("flutter_embedding")) {
                useVersion("1.0.0-$engineVersion")
            }
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

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
