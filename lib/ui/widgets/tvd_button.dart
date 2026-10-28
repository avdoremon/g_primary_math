import 'package:flutter/material.dart';

import '../theme/theme.dart';

enum TvdButtonKind { primary, secondary, text }

/// Nút điện thoại theo design system: cao 56 (tối thiểu 48), viên thuốc,
/// bóng phẳng lệch 4px. Truyền [onPressed] = null để hiện trạng thái khoá ("Sắp ra mắt").
class TvdButton extends StatefulWidget {
  const TvdButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.kind = TvdButtonKind.primary,
    this.icon,
    this.expand = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final TvdButtonKind kind;
  final IconData? icon;
  final bool expand;

  @override
  State<TvdButton> createState() => _TvdButtonState();
}

class _TvdButtonState extends State<TvdButton> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null;
    late Color bg, fg, shadow;
    Border? border;
    switch (widget.kind) {
      case TvdButtonKind.primary:
        bg = enabled ? TvdColors.answerA : TvdColors.line;
        fg = enabled ? TvdColors.white : TvdColors.inkSoft;
        shadow = enabled ? TvdColors.answerADark : TvdColors.line;
      case TvdButtonKind.secondary:
        bg = TvdColors.white;
        fg = enabled ? TvdColors.ink : TvdColors.inkSoft;
        shadow = enabled ? TvdColors.ink : TvdColors.line;
        border = Border.all(color: enabled ? TvdColors.ink : TvdColors.line, width: 2);
      case TvdButtonKind.text:
        bg = Colors.transparent;
        fg = enabled ? TvdColors.answerA : TvdColors.inkSoft;
        shadow = Colors.transparent;
    }
    final pressedOffset = _down && enabled ? 4.0 : 0.0;

    final content = Row(
      mainAxisSize: widget.expand ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (widget.icon != null) ...[Icon(widget.icon, color: fg, size: 22), const SizedBox(width: TvdSpace.s2)],
        Flexible(
          child: Text(widget.label, style: PhoneText.button.copyWith(color: fg), overflow: TextOverflow.ellipsis),
        ),
      ],
    );

    return Semantics(
      button: true,
      enabled: enabled,
      label: widget.label,
      child: GestureDetector(
        onTapDown: enabled ? (_) => setState(() => _down = true) : null,
        onTapCancel: enabled ? () => setState(() => _down = false) : null,
        onTapUp: enabled ? (_) => setState(() => _down = false) : null,
        onTap: widget.onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 80),
          height: 56,
          constraints: const BoxConstraints(minHeight: 48),
          margin: EdgeInsets.only(top: pressedOffset, bottom: 4 - pressedOffset),
          padding: const EdgeInsets.symmetric(horizontal: TvdSpace.s5),
          decoration: BoxDecoration(
            color: bg,
            border: border,
            borderRadius: BorderRadius.circular(TvdRadius.pill),
            boxShadow: widget.kind == TvdButtonKind.text || pressedOffset > 0 ? null : TvdShadow.phone(shadow),
          ),
          child: content,
        ),
      ),
    );
  }
}
