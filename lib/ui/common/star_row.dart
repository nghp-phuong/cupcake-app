import 'package:flutter/material.dart';

import 'art.dart';

/// Hàng sao (đầy/rỗng). [animate] → sao bật lần lượt.
class StarRow extends StatelessWidget {
  const StarRow({super.key, required this.stars, this.max = 5, this.size = 28, this.spacing = 2, this.animate = false});

  final int stars;
  final int max;
  final double size;
  final double spacing;
  final bool animate;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$stars/$max',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < max; i++)
            Padding(
              padding: EdgeInsets.symmetric(horizontal: spacing / 2),
              child: animate && i < stars
                  ? TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: 1),
                      duration: Duration(milliseconds: 380 + i * 160),
                      curve: Interval(i * 0.12, 1, curve: Curves.elasticOut),
                      builder: (context, t, child) => Transform.scale(scale: t, child: child),
                      child: StarIcon(size: size),
                    )
                  : StarIcon(size: size, filled: i < stars),
            ),
        ],
      ),
    );
  }
}
