import 'package:flutter/material.dart';

import '../../core/constants.dart';
import '../sugarleaf/sugarleaf.dart';

/// Bong bóng thoại giấy viền mực run tay ([SLSpeechBubble]), đuôi ở cạnh dưới lệch theo [tailX] (0..1).
/// Bề ngang theo chỗ được cấp (không giới hạn thêm).
class SpeechBubble extends StatelessWidget {
  const SpeechBubble({super.key, required this.text, this.tailX = 0.25, this.fontSize = 22, this.color = Colors.white});

  final String text;
  final double tailX;
  final double fontSize;

  /// Màu giấy; `Colors.white` = giấy ngà.
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SLSpeechBubble(
      tail: SLTail.bottom,
      tailAt: tailX.clamp(0.0, 1.0),
      tailSize: 18,
      color: color == Colors.white ? null : color,
      maxWidth: double.infinity,
      padding: const EdgeInsets.fromLTRB(22, 14, 22, 12),
      seed: slSeed(content: text),
      child: Text(
        text,
        style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.w700, color: AppColors.chocolate, height: 1.3),
      ),
    );
  }
}
