# Toán Vận Động (g_primary_math)

Game học Toán tiểu học (lớp 1–5) bằng chuyển động: điện thoại Android đặt cạnh TV làm "mắt" (camera + MediaPipe Pose), hình ảnh game phản chiếu lên TV qua Wifi hoặc HDMI. Bản đầu (MVP): Toán lớp 1–2, miễn phí, không đăng nhập, chạy offline.

- Kế hoạch, đặc tả design system và bảng theo dõi hạng mục: [tài liệu kế hoạch](https://claude.ai/artifact/8GRLmbNDUrbsaY53Lda1pm)
- Design: [design system đợt 1](https://claude.ai/artifact/5bj3W11TUcPUbcjaFfee4A) · [mini game G7](https://claude.ai/artifact/H5F5wgzw7AUvDQH5gHtzBY)

## Trạng thái

Giai đoạn 1 – Nền tảng. Đã có:

| Hạng mục | Nội dung |
| --- | --- |
| F1 | Cấu trúc dự án, lint, script dựng project Android |
| F2 | Lớp nhận diện Kotlin (CameraX + MediaPipe Pose), cầu nối Flutter, bộ lọc One Euro, cơ chế chạm đáp án; chế độ TV tự xoay ngang |
| F3–F5 | Motion Engine: hiệu chỉnh theo từng bé (giơ hai tay 1 giây), bước trái/phải (B), đếm nhảy / ngồi xổm / vỗ tay (Đ), tạo dáng tay và Đồng hồ người (T); theo dõi mất hình > 2 giây |
| F6 | Bộ giả lập khung xương (`PoseSimulator`) và ghi/phát lại (`PoseRecording`, JSON Lines) để test không cần camera |
| F7–F8 | Content Engine: chương trình lớp 1 (8 chủ đề) và lớp 2 (12 chủ đề), mỗi chủ đề 5 level; 18 dạng bài có lời giải thích khi sai; luật tính điểm |
| F12 (một phần) | Token màu, kiểu chữ, khoảng cách theo design system; font Baloo 2 + Nunito; khung TV 1920×1080; linh vật Tin Tin và asset G7 dạng SVG |

Màn hình chính hiện là menu phát triển: khung xương, bóng bay PoC, đo độ trễ TV, xem design system.

CI (GitHub Actions) chạy `dart analyze` và `flutter test` mỗi lần push; lỗi hiện thành annotation trên GitHub.

## Nội dung học

- Chương trình nằm trong `assets/content/grade1.json`, `grade2.json`, sinh từ `tool/build_content.py` (sửa file Python rồi chạy `python3 tool/build_content.py`).
- Mỗi level chọn một dạng bài (`generator`), tham số (`params`), số đáp án, thời gian mỗi câu và mini game.
- Level 1–3 dùng gợi ý dễ (nhãn TRÁI/PHẢI, linh vật làm mẫu, tô từ khoá), level 4–5 gợi ý khó.
- Điểm: 100 mỗi câu đúng + thưởng tốc độ (tối đa 50) + thưởng chuỗi (20 mỗi câu liên tiếp, tối đa 100). Câu sai không trừ điểm: báo "Chưa đúng", giải thích đáp án đúng bằng chữ và giọng đọc rồi sang câu sau. Sao: 6/10 câu = 1 sao (mở level sau), 8/10 = 2 sao, 10/10 = 3 sao.
- Thứ tự chủ đề theo SGK Toán Kết nối tri thức với cuộc sống; cần đối chiếu lại với mục lục bản 2026–2027.

## Cài đặt

Cần: Flutter stable ≥ 3.27, Android Studio (Android SDK), JDK 17, điện thoại Android 9 trở lên bật Gỡ lỗi USB.

```powershell
# Windows
powershell -ExecutionPolicy Bypass -File .\setup.ps1
flutter run --release
```

```bash
# macOS / Linux
bash setup.sh
flutter run --release
```

`setup` tạo thư mục `android/` bằng `flutter create`, chép lớp nhận diện từ `android_overlay/`, thêm MediaPipe Tasks Vision 0.10.26 + CameraX, đặt `minSdk = 28`, tải 2 mô hình pose (lite, full). Chạy lại nhiều lần không sao. Sau lần chạy đầu có thể commit thư mục `android/` (mô hình `.task` đã được bỏ qua trong `.gitignore`).

Đo hiệu năng luôn dùng `--release`.

## Cấu trúc

```
android_overlay/   Kotlin: MainActivity (kênh tvd/pose), PoseEngine (CameraX → MediaPipe); chép vào android/ khi setup
assets/fonts/      Baloo 2, Nunito (OFL), đã cắt còn Latin + tiếng Việt
assets/svg/        mascot/ (Tin Tin 10 trạng thái), g7/ (đồ vật, bàn tay, bàn chân)
lib/app/           app, chế độ TV (xoay ngang, ẩn thanh hệ thống, giữ màn hình sáng)
lib/pose/          cầu nối native, PoseFrame (33 điểm, đã lật gương)
lib/motion/        MotionEngine, BodySnapshot, Calibrator, One Euro, HandTracker, DwellSelector (C)
lib/motion/detectors/  StepDetector (B), RepCounter (Đ), ArmPoseMatcher + HumanClock (T)
lib/motion/sim/    PoseSimulator, PoseRecording
lib/content/       Question, Curriculum (Grade/Topic/Level), Scoring, VietnameseNumber
lib/content/generators/  18 dạng bài và registry
assets/content/    grade1.json, grade2.json
tool/              build_content.py
lib/ui/theme/      TvdColors, TvText / PhoneText, TvdSpace, TvLayout
lib/ui/widgets/    TvStage (khung 1920×1080), TinTin, TvdButton
lib/dev/           công cụ phát triển: khung xương, đo độ trễ, bóng bay PoC, xem design system
lib/screens/       màn hình (hiện là menu phát triển)
test/              flutter test
```

Ảnh camera chỉ nằm trong `PoseEngine.kt`; phía Flutter chỉ nhận toạ độ điểm khớp. Không ghi hình, không gửi dữ liệu ra ngoài.

## Quy ước

- Màn TV vẽ trong `TvStage` theo pixel của khung 1920×1080 như design; dùng `TvText`, `TvLayout`.
- Màn điện thoại dùng theme Material từ `buildTvdTheme()` và `PhoneText`.
- Toạ độ khung xương đã lật gương: tay phải của bé nằm bên phải màn hình.
- Màn chơi bọc trong `TvModeScope` để tự xoay ngang khi vào và trả về dọc khi ra.
