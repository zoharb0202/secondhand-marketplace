# ProGuard / R8 keep rules.
# Applied on release builds together with proguard-android-optimize.txt
# (see android/app/build.gradle.kts).

# --- General ---
-keepattributes *Annotation*
-keepattributes Signature
-keepattributes SourceFile,LineNumberTable
-keep public class * extends java.lang.Exception

# --- Flutter engine + embedding ---
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-dontwarn io.flutter.embedding.**

# --- Firebase / Google Play services ---
# (firebase_core/auth/firestore/storage/messaging/app_check/performance/crashlytics,
#  google_sign_in)
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.firebase.**
-dontwarn com.google.android.gms.**

# Crashlytics: keep readable stack traces
-keepattributes LineNumberTable,SourceFile
-keep public class * extends java.lang.Throwable

# --- Stripe (flutter_stripe) ---
-keep class com.stripe.android.** { *; }
# Push-provisioning classes are referenced by the SDK but not bundled unless the
# optional push-provisioning artifact is added — silence the missing-class errors.
-dontwarn com.stripe.android.pushProvisioning.**
-keep class com.reactnativestripesdk.** { *; }
-dontwarn com.reactnativestripesdk.**

# --- Google Maps (google_maps_flutter) ---
-keep class com.google.android.gms.maps.** { *; }
-keep interface com.google.android.gms.maps.** { *; }
-keep class com.google.maps.** { *; }
-dontwarn com.google.maps.**

# --- Play Core / deferred components (referenced by Flutter engine) ---
-keep class com.google.android.play.** { *; }
-dontwarn com.google.android.play.core.**

# --- Gson (used transitively by several plugins) ---
-dontwarn sun.misc.**
-keep class com.google.gson.** { *; }
-keep class * implements com.google.gson.TypeAdapter
-keep class * implements com.google.gson.TypeAdapterFactory
-keep class * implements com.google.gson.JsonSerializer
-keep class * implements com.google.gson.JsonDeserializer

# --- OkHttp / Okio (transitive: http stacks, Stripe) ---
-dontwarn okhttp3.**
-dontwarn okio.**
-dontwarn javax.annotation.**

# --- Local auth / biometrics (local_auth) ---
-keep class androidx.biometric.** { *; }

# --- flutter_local_notifications ---
-keep class com.dexterous.flutterlocalnotifications.** { *; }

# --- flutter_secure_storage ---
-keep class com.it_nomads.fluttersecurestorage.** { *; }

# --- video_thumbnail ---
-keep class xyz.justsoft.video_thumbnail.** { *; }

# --- Kotlin coroutines (safe no-ops if absent) ---
-dontwarn kotlinx.coroutines.**
