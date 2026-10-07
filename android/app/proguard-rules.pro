# Older Firebase SDKs rely on reflection to instantiate their component
# registrars. With R8 full mode the no-arg constructors get stripped, which
# makes Crashlytics/Installations "not present" at runtime.
-keep class * implements com.google.firebase.components.ComponentRegistrar { <init>(); }
-keep class * implements com.google.firebase.components.ComponentRegistrar
-keep class com.google.firebase.provider.FirebaseInitProvider

# WorkManager (pulled in transitively by Firebase) uses Room, which loads its
# generated *_Impl database classes by name via reflection at runtime. R8
# renaming/stripping them causes "Failed to create an instance of
# androidx.work.impl.WorkDatabase" and a startup crash in
# androidx.startup.InitializationProvider.
-keep class * extends androidx.room.RoomDatabase
-keep @androidx.room.Database class * { *; }
-keepclassmembers class * extends androidx.room.RoomDatabase {
    <init>();
}
-keep class androidx.work.impl.WorkDatabase
-keep class androidx.work.impl.WorkDatabase_Impl { *; }
-dontwarn androidx.room.**
