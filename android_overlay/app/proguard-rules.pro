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
