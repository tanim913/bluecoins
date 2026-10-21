# R8 rules for Bluecoins release builds. Flutter's own keep rules come from the Flutter Gradle plugin.

# Strip verbose/debug/info logging from release bytecode.
-assumenosideeffects class android.util.Log {
    public static int v(...);
    public static int d(...);
    public static int i(...);
}
