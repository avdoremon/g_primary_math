# Toán Vận Động – giữ lớp MediaPipe khi build release (R8 thu gọn mã).
# MediaPipe gọi lớp Java từ mã native (JNI) và đọc cấu hình bằng protobuf,
# nên R8 không thấy được chỗ dùng; bỏ đi sẽ làm nhận diện không chạy trên bản release.
-keep class com.google.mediapipe.** { *; }
-keep class com.google.protobuf.** { *; }
-keepclassmembers class * extends com.google.protobuf.GeneratedMessageLite { <fields>; }
-dontwarn com.google.mediapipe.**
-dontwarn com.google.protobuf.**
-dontwarn javax.annotation.**
-dontwarn javax.lang.model.**
-dontwarn com.google.auto.value.**
-dontwarn org.checkerframework.**

# Flogger (MediaPipe dùng để ghi log) nạp backend bằng reflection; bị cắt sẽ gây
# "NoClassDefFoundError: Could not initialize class ...FluentLogger" khi tạo PoseLandmarker.
-keep class com.google.common.flogger.** { *; }
-dontwarn com.google.common.flogger.**
-keep class com.google.android.odml.** { *; }
-dontwarn com.google.android.odml.**
