# ═════════════════════════════════════════════════════════════
# ML Kit — OCR + Document Scanner
# ═════════════════════════════════════════════════════════════
-keep class com.google.mlkit.** { *; }
-keep class com.google.android.gms.internal.mlkit_vision_text** { *; }
-keep class com.google.android.gms.internal.mlkit_vision_common** { *; }
-keep class com.google.android.gms.internal.mlkit_vision_document_scanner** { *; }

# OCR — lenguajes
-keep class com.google.mlkit.vision.text.chinese.** { *; }
-keep class com.google.mlkit.vision.text.devanagari.** { *; }
-keep class com.google.mlkit.vision.text.japanese.** { *; }
-keep class com.google.mlkit.vision.text.korean.** { *; }
-keep class com.google.mlkit.vision.text.latin.** { *; }

-dontwarn com.google.mlkit.**

# ═════════════════════════════════════════════════════════════
# Play Core — deferred components de Flutter
# (no los usamos, pero el embedding los referencia)
# ═════════════════════════════════════════════════════════════
-keep class com.google.android.play.core.** { *; }
-keep class com.google.android.play.core.splitcompat.** { *; }
-keep class com.google.android.play.core.splitinstall.** { *; }
-keep class com.google.android.play.core.tasks.** { *; }

-dontwarn com.google.android.play.core.**
-dontwarn io.flutter.embedding.engine.deferredcomponents.**

# ═════════════════════════════════════════════════════════════
# Flutter plugins
# ═════════════════════════════════════════════════════════════
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-keep class vn.hunghd.flutter.plugins.imagecropper.** { *; }
-keep class com.yalantis.ucrop.** { *; }
-keep class com.baseflow.permissionhandler.** { *; }
-keep class dev.fluttercommunity.plus.share.** { *; }

# ═════════════════════════════════════════════════════════════
# Isar
# ═════════════════════════════════════════════════════════════
-keep class io.isar.** { *; }
-keep class dev.isar.** { *; }

# ═════════════════════════════════════════════════════════════
# Google Play Services
# ═════════════════════════════════════════════════════════════
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.android.gms.**

# ═════════════════════════════════════════════════════════════
# Generales
# ═════════════════════════════════════════════════════════════
-keepattributes *Annotation*
-keepattributes Signature
-keepattributes InnerClasses