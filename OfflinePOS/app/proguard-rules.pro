# OfflinePOS v11 ProGuard Rules

# Keep MainActivity
-keep class com.offlinepos.accounts.MainActivity {
    *;
}

# Keep Javascript Interface methods
-keepclassmembers class * {
    @android.webkit.JavascriptInterface <methods>;
}

# Keep WebView related classes
-keep class android.webkit.** { *; }

# Keep application classes
-keep class com.offlinepos.accounts.** {
    *;
}
