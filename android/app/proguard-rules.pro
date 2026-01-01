# Flutter Wrapper
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Firebase
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.internal.** { *; }
-keep class com.google.android.gms.common.internal.safeparcel.SafeParcelable {
    public static final *** NULL;
}
-keepnames class * extends com.google.android.gms.common.internal.safeparcel.SafeParcelable
-keepclassmembers class * extends com.google.android.gms.common.internal.safeparcel.SafeParcelable {
    public static final *** CREATOR;
}

# Google Play Services / Core
-dontwarn com.google.android.play.core.**
-keep class com.google.android.play.core.** { *; }

# Excel / JNI
-dontwarn com.google.android.play.core.splitcompat.SplitCompatApplication
