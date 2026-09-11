# R8 / ProGuard rules for the release build.
#
# Referenced from build.gradle via:
#   proguardFiles getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro"
#
# Gradle fails the build if this file is missing, even when it is empty — the
# reference is resolved at configuration time.
#
# The Flutter Gradle Plugin already contributes the keep rules the engine and
# the plugin registrant need, so this file only carries project-specific rules.

# Keep annotations. Plugins that register themselves reflectively rely on these
# surviving shrinking.
-keepattributes *Annotation*

# Keep line numbers so release crash reports are readable, while still
# obfuscating the original file names.
-keepattributes SourceFile,LineNumberTable
-renamesourcefileattribute SourceFile

# Generic signatures are needed for any reflective inspection of generic types
# (JSON deserialisation that inspects type parameters, for example).
-keepattributes Signature

# Suppress notes about the two optional Play Core classes Flutter references for
# deferred components. They are absent unless deferred components are enabled,
# and R8 warns about them on every release build otherwise.
-dontwarn com.google.android.play.core.**
