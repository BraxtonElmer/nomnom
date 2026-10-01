# Scheduled reminders are saved as JSON by Gson using field names. Renamed
# fields differ between builds, so an update could not read the saved ones.
-keep class com.dexterous.** { *; }
-keepattributes Signature
-keep class com.google.gson.reflect.TypeToken { *; }
-keep class * extends com.google.gson.reflect.TypeToken
