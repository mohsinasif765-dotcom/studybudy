pluginManagement {
    val flutterSdkPath = try {
        val properties = java.util.Properties()
        file("local.properties").inputStream().use { properties.load(it) }
        properties.getProperty("flutter.sdk")
    } catch (e: Exception) {
        null
    }

    includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")

    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    // پرانا 8.2.1 تھا، اب نیا 8.6.0 کر دیا ہے
    id("com.android.application") version "8.6.0" apply false
    // پرانا 1.8.22 تھا، اب نیا 2.1.0 کر دیا ہے
    id("org.jetbrains.kotlin.android") version "2.1.0" apply false
}

include(":app")