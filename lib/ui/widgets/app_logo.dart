import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../theme/theme.dart';

/// Logo Toán Vận Động: biểu tượng (bạn nhỏ dang tay thành dấu cộng) + chữ, "Vận Động" màu xanh.
class AppLogo extends StatelessWidget {
  const AppLogo({super.key, this.height = 44, this.showName = true});

  final double height;
  final bool showName;

  @override
  Widget build(BuildContext context) {
    final mark = SvgPicture.asset('assets/svg/brand/logo_mark.svg', width: height, height: height);
    if (!showName) return mark;
    final style = PhoneText.titleLarge.copyWith(fontSize: height * .72, height: 1.1);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        mark,
        SizedBox(width: height * .25),
        Flexible(
          child: Text.rich(
            TextSpan(
              style: style,
              children: [
                const TextSpan(text: 'Toán '),
                TextSpan(text: 'Vận Động', style: style.copyWith(color: TvdColors.answerA)),
              ],
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
