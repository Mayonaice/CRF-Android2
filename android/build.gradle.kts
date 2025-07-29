allprojects {
    repositories {
        google()
        mavenCentral()
    }
    
    // Fix for android_id plugin namespace issue
    project.afterEvaluate {
        if (project.hasProperty('android')) {
            if (project.name == 'android_id' && !project.android.hasProperty('namespace')) {
                project.android.namespace = "io.flutter.plugins.androidid"
            }
        }
    }
    
    // Force specific versions for compatibility
    configurations.all {
        resolutionStrategy {
            force("androidx.core:core:1.9.0")
            force("androidx.core:core-ktx:1.9.0")
        }
    }
}

val newBuildDir: Directory = rootProject.layout.buildDirectory.dir("../../build").get()
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
