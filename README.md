# Toán Vận Động (g_primary_math)

Game học Toán tiểu học (lớp 1–5) bằng chuyển động: điện thoại Android đặt cạnh TV làm "mắt" (camera + MediaPipe Pose), hình ảnh game phản chiếu lên TV qua Wifi hoặc HDMI. Có đủ chương trình Toán lớp 1–5, miễn phí, không đăng nhập, chạy offline.

- Kế hoạch, đặc tả design system và bảng theo dõi hạng mục: [tài liệu kế hoạch](https://claude.ai/artifact/8GRLmbNDUrbsaY53Lda1pm)
- Design: [design system đợt 1](https://claude.ai/artifact/5bj3W11TUcPUbcjaFfee4A) · [mini game G7](https://claude.ai/artifact/H5F5wgzw7AUvDQH5gHtzBY) · [màn TV, điện thoại, Góc tay, Tia số](https://claude.ai/artifact/UpRDNXouS3FKFGk3cCiNva)

## Trạng thái

Đã có (giai đoạn Nền tảng và phần lớn giai đoạn Mini game):

| Hạng mục | Nội dung |
| --- | --- |
| F1 | Cấu trúc dự án, lint, script dựng project Android |
| F2 | Lớp nhận diện Kotlin (CameraX + MediaPipe Pose), cầu nối Flutter, bộ lọc One Euro, cơ chế chạm đáp án; chế độ TV tự xoay ngang |
| F3–F5 | Motion Engine: hiệu chỉnh theo từng bé (giơ hai tay 1 giây), bước trái/phải (B), đếm nhảy / ngồi xổm / vỗ tay (Đ), tạo dáng tay và Đồng hồ người (T); theo dõi mất hình > 2 giây |
| F6 | Bộ giả lập khung xương (`PoseSimulator`) và ghi/phát lại (`PoseRecording`, JSON Lines) để test không cần camera |
| F7–F8 | Content Engine: chương trình lớp 1 và lớp 2, mỗi chủ đề 5 level; 18 dạng bài có lời giải thích khi sai; luật tính điểm |
| F9 | Lưu tiến độ bằng SQLite: nhiều hồ sơ trên một máy, sao và điểm cao nhất mỗi level, lịch sử trả lời, cài đặt phụ huynh |
| F10 | Âm thanh: đọc đề và lời giải thích (ghép đoạn ghi âm sẵn, thiếu thì dùng giọng tiếng Việt của máy), hiệu ứng giữ chỗ |
| F11 | Luồng màn hình: hồ sơ → chủ đề → level → màn chơi trên TV → tổng kết; nhắc nghỉ, giới hạn thời gian, khu phụ huynh |
| F12 (một phần) | Token màu, kiểu chữ, khoảng cách theo design system; font Baloo 2 + Nunito; khung TV 1920×1080; linh vật Tin Tin và asset G7 dạng SVG |
| G1 | Khung mini game: HUD chung theo design (Câu x/10, mức gợi ý, điểm, chuỗi, thẻ đề có loa và từ khoá, thanh thời gian), mỗi mini game chỉ khai báo cảnh và vùng chạm |
| G2–G6 | Bóng bay phép tính, Bên nào lớn hơn / Đúng hay sai, Nhảy đếm, Đồng hồ người, Săn hình (hình phẳng, hình khối, tờ tiền) |
| G7 | Con nói, con làm theo 10 màn design: tạo dáng dễ/khó, chạm đồ vật (kệ, cây, bàn, hộp), bước chân, lệnh ghép, phản hồi đúng/chưa đúng |
| G11 | Chương trình theo đúng mục lục SGK: Toán 1 (10 chủ đề), Toán 2 (14 chủ đề), gồm cả các chủ đề ôn tập |
| Lớp 3–5 | Toán 3 (16 chủ đề), Toán 4 (13), Toán 5 (12) theo SGK Kết nối tri thức: 20 dạng bài mới (số nhiều chữ số, làm tròn, số La Mã, tìm thành phần chưa biết, nhân chia có dư, biểu thức, bài toán nhiều bước, phân số, số thập phân, tỉ số phần trăm, tỉ lệ bản đồ, chu vi/diện tích/thể tích, góc, đổi đơn vị, nhiệt độ, tiền, thời gian, chuyển động đều, bảng và biểu đồ); hình minh hoạ vẽ bằng code, phân số viết chồng |
| Mini game mới | Góc tay (lớp 4: hai tay tạo góc nhọn/vuông/tù/bẹt, giữ 0,8 giây) và Tia số (đáp án xếp tăng dần trên tia số; bé đi ngang tới ô đúng rồi giơ tay) |

Logo: hướng "Dấu cộng nhảy múa" theo [design logo](https://claude.ai/artifact/1jkaxLLfLZhNr3LCVFSiqg) (`assets/svg/brand/`, bản 512 px trong `docs/brand/`); biểu tượng app nằm trong `android_overlay/app/src/main/res/` (có biểu tượng thích ứng cho Android 8+). Ô đáp án và bóng bay theo design system: nền trắng, viền màu theo vị trí, chữ số màu mực, hình nhận dạng ở góc (cho trẻ mù màu). Lớp cảnh của từng mini game nằm trong `lib/screens/play/views/`.

CI (GitHub Actions) mỗi lần push: `dart analyze`, `flutter test` (gồm widget test chạy trọn luồng app không cần camera), và build APK release. Lỗi hiện thành annotation trên GitHub.

**Cài thử không cần build:** vào tab Actions của repo → lần chạy CI mới nhất → mục Artifacts → tải `toan-van-dong-apk` (file zip chứa `app-release.apk`), giải nén rồi cài lên điện thoại (cho phép cài ứng dụng không rõ nguồn).

**Cài đè bản cập nhật:** CI ký APK bằng một khoá cố định lấy từ GitHub Secrets (`ANDROID_KEYSTORE_BASE64` = file `.jks` mã base64, `ANDROID_KEYSTORE_PASSWORD`; alias `toanvandong`), số phiên bản tăng theo số lần chạy CI. Có đủ hai secret thì bản mới cài đè lên bản cũ và giữ tiến độ của bé; thiếu thì APK ký bằng khoá debug tạm (phải gỡ bản cũ). Khoá không bao giờ nằm trong repo (`*.jks`, `key.properties` đã bị bỏ qua). Build trên máy: đặt `android/key.properties` (storeFile, storePassword, keyAlias, keyPassword) nếu muốn ký giống CI.

**Camera:** mặc định camera trước (đổi ở khu phụ huynh), nút đổi camera ở góc dưới màn chơi; đổi giữa lượt thì game tạm dừng và đo lại khi bé giơ hai tay. Nhận diện chạy bằng CPU (GPU bật ở công cụ phát triển). Nếu app từng bị dừng khi bật camera, lần sau không tự bật lại mà hiện nút "Thử lại camera"; khu phụ huynh có mục "Báo lỗi lần trước" để sao chép lỗi gửi đội phát triển.

## Nội dung học

- Chương trình nằm trong `assets/content/grade1.json` … `grade5.json` (10, 14, 16, 13, 12 chủ đề; tổng 325 level), sinh từ `tool/build_content.py` (sửa file Python rồi chạy `python3 tool/build_content.py`).
- Mỗi level chọn một dạng bài (`generator`), tham số (`params`), số đáp án, thời gian mỗi câu và mini game.
- Level 1–3 dùng gợi ý dễ (nhãn TRÁI/PHẢI, linh vật làm mẫu, tô từ khoá), level 4–5 gợi ý khó.
- Điểm: 100 mỗi câu đúng + thưởng tốc độ (tối đa 50) + thưởng chuỗi (20 mỗi câu liên tiếp, tối đa 100). Câu sai không trừ điểm: báo "Chưa đúng", giải thích đáp án đúng bằng chữ và giọng đọc rồi sang câu sau. Sao: 6/10 câu = 1 sao (mở level sau), 8/10 = 2 sao, 10/10 = 3 sao.
- Tên và thứ tự chủ đề theo SGK Toán 1–5 Kết nối tri thức với cuộc sống (đã đối chiếu mục lục / kế hoạch dạy học của bộ sách ngày 29/10/2026).
- Số viết như sách: dấu phẩy thập phân (2,05), nhóm nghìn bằng dấu cách (1 250 000). Phân số và số thập phân tính chính xác (`lib/content/numbers.dart`), không dùng số thực nên không có đáp án kiểu 0,30000000004.
- Đề đọc thành tiếng tự đổi ký hiệu: "3 m = ? cm" → "ba mét bằng mấy xăng-ti-mét", "3/4" → "ba phần tư", "2,05" → "hai phẩy không năm".

## Luồng chơi và quy tắc

- Không đăng nhập. Mỗi bé một hồ sơ (tên, lớp, màu), lưu trên máy. Giữ lâu vào hồ sơ để sửa.
- Mọi chủ đề đều mở; trong chủ đề, level 1 luôn mở, level sau mở khi level trước được ít nhất 1 sao.
- Vào level: màn hình xoay ngang. Bé giơ hai tay 1 giây để hiệu chỉnh và bắt đầu. Không có camera thì chạm màn hình.
- Mất hình hơn 2 giây: tạm dừng, đồng hồ đứng yên.
- Hết level: chọn "Chơi lại / Level sau / Về menu" bằng cách giữ tay lên ô (hoặc chạm).
- Phụ huynh (nút bánh răng, qua cổng phép nhân): giới hạn mỗi ngày (mặc định 30 phút), nhắc nghỉ (mặc định sau 15 phút chơi liên tục, nghỉ 2 phút), bật/tắt giọng đọc và hiệu ứng, chế độ luyện tập (không đếm giờ), xem lịch sử trả lời, xoá hồ sơ, công cụ phát triển. Giới hạn và nhắc nghỉ chỉ áp dụng giữa hai level, không cắt ngang khi đang chơi.

## Âm thanh

- Giọng đọc: mỗi câu được ghép từ các đoạn ghi âm sẵn trong `assets/audio/voice/` nếu đủ đoạn; thiếu thì cả câu đọc bằng TTS tiếng Việt của Android (cần cài "Dịch vụ chuyển văn bản thành giọng nói của Google" và giọng Tiếng Việt).
- Thêm ghi âm: đặt file `.m4a` tên viết kiểu Telex (`bảy` → `bayr.m4a`, `bằng mấy` → `bawngf_maays.m4a`, `mười` → `muwowif.m4a`) vào `assets/audio/voice/`, rồi thêm cụm từ vào danh sách `clips` trong `manifest.json`.
- Hiệu ứng (`assets/audio/sfx/*.wav`) hiện là âm giữ chỗ sinh bằng `python3 tool/make_placeholder_sfx.py`; thay file cùng tên khi có âm thanh thật.

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
assets/audio/      sfx/ (hiệu ứng giữ chỗ), voice/ (ghi âm giọng đọc + manifest.json)
assets/content/    grade1.json, grade2.json
lib/app/           app, dịch vụ dùng chung (AppServices, AppScope), chế độ TV
lib/pose/          cầu nối native, PoseFrame (33 điểm, đã lật gương)
lib/motion/        MotionEngine, BodySnapshot, Calibrator, One Euro, HandTracker, DwellSelector (C)
lib/motion/detectors/  StepDetector (B), RepCounter (Đ), ArmPoseMatcher + HumanClock (T)
lib/motion/sim/    PoseSimulator, PoseRecording
lib/content/       Question, Curriculum (Grade/Topic/Level), Scoring, VietnameseNumber
lib/content/generators/  18 dạng bài và registry
lib/game/          GameSession (một lượt chơi), AnswerMechanic (C/B/Đ/T), lời phản hồi, PlayGuard (nhắc nghỉ, giới hạn)
lib/progress/      ProgressStore (SQLite, bộ nhớ), Profile, LevelRecord, luật mở khoá, cài đặt phụ huynh
lib/audio/         AudioService, SpeechPlanner (ghép ghi âm), TTS + audioplayers
lib/screens/       hồ sơ, chủ đề, level, phụ huynh
lib/screens/play/  màn chơi TV: HUD, bóng người, hình minh hoạ; views/ (cảnh từng mini game)
lib/ui/theme/      TvdColors, TvText / PhoneText, TvdSpace, TvLayout
lib/ui/widgets/    TvStage (khung 1920×1080), TinTin, TvdButton
lib/dev/           công cụ phát triển: khung xương, đo độ trễ, bóng bay PoC, xem design system
tool/              build_content.py, make_placeholder_sfx.py
test/              flutter test
```
Ảnh camera chỉ nằm trong `PoseEngine.kt`; phía Flutter chỉ nhận toạ độ điểm khớp. Không ghi hình, không gửi dữ liệu ra ngoài.

## Quy ước

- Màn TV vẽ trong `TvStage` theo pixel của khung 1920×1080 như design; dùng `TvText`, `TvLayout`.
- Màn điện thoại dùng theme Material từ `buildTvdTheme()` và `PhoneText`.
- Toạ độ khung xương đã lật gương: tay phải của bé nằm bên phải màn hình.
- Màn chơi bọc trong `TvModeScope` để tự xoay ngang khi vào và trả về dọc khi ra.
