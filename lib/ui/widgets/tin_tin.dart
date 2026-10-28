import 'package:flutter/widgets.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Trạng thái và tư thế của linh vật Tin Tin (gấu trúc đỏ).
/// Tư thế mẫu theo chiều gương: "Left" = bên trái màn hình.
enum TinTinState {
  hello('Chào', 'Màn mở đầu, chọn hồ sơ, bắt đầu level'),
  happy('Vui', 'Hoàn thành level, đạt 3 sao'),
  praise('Khen', 'Trả lời đúng, chuỗi đúng liên tiếp'),
  encourage('Động viên', 'Trả lời chưa đúng, hiện đáp án đúng'),
  wait('Chờ', 'Tạm dừng, chờ bé vào khung, đang tải'),
  raiseLeft('Giơ tay trái', 'Tư thế mẫu G7'),
  raiseRight('Giơ tay phải', 'Tư thế mẫu G7'),
  raiseBoth('Giơ hai tay', 'Tư thế mẫu G7, bắt đầu chơi'),
  stepLeft('Bước sang trái', 'Tư thế mẫu G7'),
  stepRight('Bước sang phải', 'Tư thế mẫu G7');

  const TinTinState(this.label, this.when);

  final String label;
  final String when;

  String get asset => 'assets/svg/mascot/tintin_$name.svg';
}

/// Linh vật Tin Tin. Tỉ lệ khung 200×224 theo design.
/// Chuyển động (thở 2,4 giây, vẫy, nhảy…) sẽ thêm ở hạng mục G1.
class TinTin extends StatelessWidget {
  const TinTin({super.key, this.state = TinTinState.hello, this.size = 200});

  final TinTinState state;

  /// Chiều rộng; chiều cao = size × 1,12.
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size * 224 / 200,
      child: SvgPicture.asset(state.asset, fit: BoxFit.contain),
    );
  }
}
