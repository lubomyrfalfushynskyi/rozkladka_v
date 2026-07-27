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

// Деякі старіші плагіни (напр. file_picker) хардкодять власний
// compileSdkVersion у своєму build.gradle, нижчий за той, що вимагають їхні
// ж транзитивні залежності. Примусово піднімаємо compileSdk для всіх
// Android-підпроєктів до 36, щоб уникнути конфлікту AAR-метаданих. Має бути
// зареєстровано ДО evaluationDependsOn нижче, інакше деякі підпроєкти вже
// встигають обчислитись і afterEvaluate падає з "already evaluated".
subprojects {
    afterEvaluate {
        extensions.findByName("android")?.withGroovyBuilder {
            setProperty("compileSdkVersion", 36)
        }
    }
}

subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
