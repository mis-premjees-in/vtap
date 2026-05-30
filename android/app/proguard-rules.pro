# Proguard Rules for VTAP App Optimization

# Flutter wrapper classes
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.embedding.** { *; }
-keep class io.flutter.provider.** { *; }
-keep class io.flutter.plugins.** { *; }

# Firebase SDKs
-keep class com.google.firebase.** { *; }
-dontwarn com.google.firebase.**

# Keep Geolocator plugin
-keep class com.baseflow.geolocator.** { *; }

# Keep background services & kotlin custom bindings
-keep class com.premjees.vtap.** { *; }

# Keep serialization attributes
-keepattributes Signature
-keepattributes *Annotation*
-keepclassmembers class * {
    @com.google.gson.annotations.SerializedName <fields>;
}

# Ignore missing Google Play Store Core library references used by Flutter embedding
-dontwarn com.google.android.play.core.**
