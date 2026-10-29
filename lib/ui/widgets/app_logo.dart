import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../theme/theme.dart';

/// Logo Toán Vận Động (design "Dấu cộng nhảy múa"): bạn nhỏ dang tay thành dấu cộng + chữ, "Vận Động" màu xanh.
class AppLogo extends StatelessWidget {
  const AppLogo({super.key, this.height = 44, this.showName = true});

  final double height;
  final bool showName;

  @override
  Widget build(BuildContext context) {
    final mark = SvgPicture.asset('assets/svg/brand/logo_mark.svg', width: height, height: height);
    if (!showName) return mark;
    // Theo design "Dấu cộng nhảy múa": biểu tượng bên trái, chữ hai dòng "Toán" / "Vận Động".
    final style = PhoneText.titleLarge.copyWith(fontSize: height * .42, height: 1.0);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        mark,
        SizedBox(width: height * .22),
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Toán', style: style),
            Text('Vận Động', style: style.copyWith(color: TvdColors.answerA)),
          ],
        ),
      ],
    );
  }
}
