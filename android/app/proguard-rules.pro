# Keep calendar provider classes
-keep class android.provider.CalendarContract** { *; }

# Keep device_calendar plugin models
-keep class com.builttoroam.devicecalendar** { *; }

# Prevent R8 from stripping annotations
-keepattributes *Annotation*
