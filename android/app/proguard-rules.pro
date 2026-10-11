# flutter_local_notifications uses Gson with generic types.
-keep class com.dexterous.** { *; }
-keepattributes Signature
-keepattributes *Annotation*
-keep class com.google.gson.** { *; }

# just_audio / audio_service
-keep class com.ryanheise.** { *; }

# pdfrx (PDFium JNI)
-keep class jp.espresso3389.** { *; }

# Google Play Core (referenced by the Flutter embedding for deferred components)
-dontwarn com.google.android.play.core.**
