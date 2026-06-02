# Proguard rules untuk Kawal PE

# Flutter
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Supabase / Ktor
-keep class io.ktor.** { *; }
-keep class kotlinx.** { *; }
-dontwarn io.ktor.**

# Geolocator
-keep class com.baseflow.geolocator.** { *; }

# image_picker
-keep class io.flutter.plugins.imagepicker.** { *; }

# Cloudinary (via http)
-dontwarn okhttp3.**
-dontwarn okio.**
