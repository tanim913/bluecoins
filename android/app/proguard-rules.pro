# R8 rules for Bluecoins release builds. Flutter's own keep rules come from the Flutter Gradle plugin.

# Strip verbose/debug/info logging from release bytecode.
-assumenosideeffects class android.util.Log {
    public static int v(...);
    public static int d(...);
    public static int i(...);
}

# Several Flutter plugins are called from Dart through JNI or Pigeon by method name. R8 would rename or
# remove those methods, and the app then dies at startup (NoSuchMethodError in shared_preferences).
-keep class io.flutter.plugins.** { *; }
-keep class dev.flutter.** { *; }
-keep class dev.fluttercommunity.** { *; }
-keep class com.github.dart_lang.jni.** { *; }
-keep class com.dexterous.flutterlocalnotifications.** { *; }

# The JNI/Pigeon lookups name Kotlin's own types in method signatures, e.g. suspend functions end
# with Lkotlin/coroutines/Continuation;. R8 renamed that type, so getAll(...) was "not found".
-keepnames class kotlin.** { *; }
-keepnames class kotlinx.coroutines.** { *; }
-keep class kotlin.coroutines.Continuation { *; }
