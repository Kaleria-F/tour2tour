allprojects {
    repositories {
        google()
        mavenCentral()
        maven("https://maven.yandex.ru/repo/maps-mobile/")
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
    configurations.all {
        resolutionStrategy.eachDependency {
            if (requested.group == "com.yandex.android" && requested.name == "maps.mobile") {
                useTarget("com.yandex.maps:maps.mobile:4.33.1-beta-full-flutter")
                because("Flutter Yandex MapKit full requires flutter-specific maps.mobile artifact")
            }
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
