# Flutter-specific rules
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Keep flutter_secure_storage classes
-keep class com.it_nomads.fluttersecurestorage.** { *; }

# Keep Google ML Kit classes (face detection)
-keep class com.google.mlkit.** { *; }

# Prevent stripping of annotations
-keepattributes *Annotation*
