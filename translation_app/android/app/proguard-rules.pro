# Jusoor R8 rules — keep this minimal; add rules only when the release build
# breaks or a plugin feature regresses. Each rule documents why it exists.

# Flutter engine: the embedding engine looks up plugin/activity classes by
# name via reflection at startup.
-keep class io.flutter.embedding.** { *; }
-keep class io.flutter.plugin.** { *; }

# flutter_overlay_window registers receivers/views reflectively from Dart
# side method channel calls.
-keep class com.skydoves.flutter_overlay_window.** { *; }

# The Flutter engine's PlayStoreDeferredComponentManager and
# FlutterPlayStoreSplitApplication reference Play Core split-install/compat
# classes. Jusoor does not use deferred components, so Play Core is
# intentionally absent from the classpath — tell R8 the references are safe.
-dontwarn com.google.android.play.core.splitinstall.**
-dontwarn com.google.android.play.core.splitcompat.SplitCompatApplication
-dontwarn com.google.android.play.core.tasks.OnFailureListener
-dontwarn com.google.android.play.core.tasks.OnSuccessListener
-dontwarn com.google.android.play.core.tasks.Task

