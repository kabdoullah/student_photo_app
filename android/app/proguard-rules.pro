# ML Kit face detection relies on Google Play Services' Dynamite module
# loading and reflection internally. Without these keep rules, R8 strips
# classes it needs in release builds, causing:
#   PlatformException(InputImageConverterError, NullPointerException:
#   ... getClass() on a null object reference)
-keep class com.google.mlkit.** { *; }
-keep class com.google.android.gms.internal.mlkit_common.** { *; }
-keep class com.google.android.gms.internal.mlkit_vision_common.** { *; }
-keep class com.google.android.gms.internal.mlkit_vision_face.** { *; }
-keep class com.google.android.gms.internal.mlkit_vision_face_bundled.** { *; }
-dontwarn com.google.mlkit.**
-dontwarn com.google.android.gms.internal.mlkit_common.**
-dontwarn com.google.android.gms.internal.mlkit_vision_common.**
-dontwarn com.google.android.gms.internal.mlkit_vision_face.**
-dontwarn com.google.android.gms.internal.mlkit_vision_face_bundled.**
