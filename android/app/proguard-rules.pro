# Baidu Map SDK ProGuard rules
-keep class com.baidu.** { *; }
-keep class vi.com.gdi.** { *; }
-keep class com.baidu.mapapi.** { *; }
-keep class com.baidu.mapsdkplatform.** { *; }
-keep class com.baidu.location.** { *; }
-dontwarn com.baidu.**
-dontwarn vi.com.gdi.**

# Keep Flutter classes
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }
