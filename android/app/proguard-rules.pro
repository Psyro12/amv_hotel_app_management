# Google ML Kit Text Recognition rules
-keep class com.google.mlkit.vision.text.** { *; }
-keep class com.google.android.gms.internal.mlkit_vision_text_common.** { *; }

# Flutter Play Store Split / Deferred Components
-dontwarn com.google.android.play.core.**
-keep class com.google.android.play.core.** { *; }

# General ProGuard rules for Flutter
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Ignore warnings for common libraries
-dontwarn android.window.**
-dontwarn com.google.android.gms.**
-dontwarn com.google.mlkit.**
-dontwarn io.flutter.embedding.engine.deferredcomponents.**

# Optimize for speed
-optimizations !code/simplification/arithmetic,!field/*,!class/merging/*
-allowaccessmodification
-dontpreverify