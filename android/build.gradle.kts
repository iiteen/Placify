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

    project.afterEvaluate {
        tasks.withType(org.jetbrains.kotlin.gradle.tasks.KotlinCompile::class).configureEach {
            compilerOptions {
                // --- THE EXCEPTION LIST ---
                // "device_calendar" is still on Java 1.8, so we add it here.
                // If "receive_sharing_intent" fails later, add it to this list too.
                val legacyPlugins = setOf("device_calendar", "receive_sharing_intent", "workmanager_android")

                if (legacyPlugins.contains(project.name)) {
                    // Force these plugins to use 1.8 (matches their internal Java config)
                    jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_1_8)
                } else {
                    // Force everything else (app, workmanager, etc.) to use 17
                    jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17)
                }
            }
        }
    }
}

subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
