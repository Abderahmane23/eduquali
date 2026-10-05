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

// Aligne tous les plugins sur compileSdk 36.
//
// Les plugins declarent chacun leur propre compileSdk et ne sont pas coherents
// entre eux : certains compilent en 34 alors qu'ils dependent de
// flutter_plugin_android_lifecycle, qui exige 36. AGP refuse alors de lier les
// deux. Compiler contre une API plus recente est retro-compatible, donc tout
// remonter a 36 est sans risque.
//
// Ce bloc doit rester AVANT `evaluationDependsOn(":app")` : cet appel force
// l'evaluation immediate des sous-projets, apres quoi Gradle refuse tout
// nouvel afterEvaluate (« project is already evaluated »).
//
// Passage par reflexion : selon la version d'AGP l'extension expose
// setCompileSdk(Integer) ou setCompileSdkVersion(int), et aucun de ces types
// n'est sur le classpath de ce script.
fun Project.forceCompileSdk36() {
    val androidExt = extensions.findByName("android") ?: return
    val methods = androidExt.javaClass.methods
    val setter =
        methods.firstOrNull {
            it.name == "setCompileSdk" &&
                it.parameterTypes.size == 1 &&
                it.parameterTypes[0] == Integer::class.java
        }
            ?: methods.firstOrNull {
                it.name == "setCompileSdkVersion" &&
                    it.parameterTypes.size == 1 &&
                    it.parameterTypes[0] == Int::class.javaPrimitiveType
            }
    runCatching { setter?.invoke(androidExt, 36) }
}

subprojects {
    // Un sous-projet deja evalue ne peut plus recevoir d'afterEvaluate :
    // on le configure alors directement.
    if (state.executed) {
        forceCompileSdk36()
    } else {
        afterEvaluate { forceCompileSdk36() }
    }
}

subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
