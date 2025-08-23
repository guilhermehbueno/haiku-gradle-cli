plugins {
    alias(libs.plugins.jvm)
    alias(libs.plugins.haiku.plugin)
    application
}

group = "${PROJECT_PACKAGE}"
version = "1.0.0"

repositories {
    mavenCentral()
}

haiku {
    sourceDir.set(layout.projectDirectory.dir("src/main/haiku"))
    outputDir.set(layout.buildDirectory.dir("generated/haiku"))
    packageName.set("${PROJECT_PACKAGE}.generated")
}

dependencies {
    implementation(libs.haiku.core)

    testImplementation(libs.kotlin.test.junit5)
    testImplementation(libs.junit.jupiter.engine)
    testRuntimeOnly(libs.junit.platform.launcher)
}

application {
    mainClass.set("${PROJECT_PACKAGE}.AppKt")
}

tasks.withType<Test> {
    useJUnitPlatform()
}

tasks.named("run") {
    dependsOn("processHaiku")
}
