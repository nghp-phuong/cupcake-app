import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sugarleaf_bakery/ui/sugarleaf/sl_theme.dart';

void main() {
  test('slContrastRatio đúng công thức WCAG', () {
    expect(slContrastRatio(const Color(0xFF000000), const Color(0xFFFFFFFF)), closeTo(21, 0.01));
    expect(slContrastRatio(const Color(0xFF777777), const Color(0xFFFFFFFF)), closeTo(4.48, 0.02));
  });

  // Cặp chữ/nền dùng thật trong bộ SL*: (tên, chữ, nền, cỡ lớn?). Chữ lớn (≥ 18,66px đậm) chỉ cần 3:1.
  final pairs = <(String, Color, Color, bool)>[
    ('mực / kem', SLColors.ink, SLColors.cream, false),
    ('mực / giấy', SLColors.ink, SLColors.paper, false),
    ('mực / giấy cũ (tab, ống tiến độ)', SLColors.ink, SLColors.paperShade, false),
    ('mực / gỗ sáng (bảng tên)', SLColors.ink, SLColors.woodLight, false),
    ('mực / hồng dâu (nút chính, ruy băng)', SLColors.ink, SLColors.strawberry, false),
    ('mực / hồng nhạt', SLColors.ink, SLColors.strawberryLight, false),
    ('mực / bạc hà', SLColors.ink, SLColors.mint, false),
    ('mực / bạc hà nhạt', SLColors.ink, SLColors.mintLight, false),
    ('mực / vàng bơ (VIP, nút)', SLColors.ink, SLColors.butter, false),
    ('mực / vàng bơ nhạt', SLColors.ink, SLColors.butterLight, false),
    ('mực / đỏ nhạt (nút nguy hiểm)', SLColors.ink, SLColors.dangerSoft, false),
    ('mực / xanh đúng', SLColors.ink, SLColors.good, false),
    ('mực phụ / kem', SLColors.inkSoft, SLColors.cream, false),
    ('mực phụ / giấy', SLColors.inkSoft, SLColors.paper, false),
    ('mực phụ / giấy cũ (thanh hiệu năng)', SLColors.inkSoft, SLColors.paperShade, false),
    ('kem / đỏ đậm (huy hiệu số)', SLColors.cream, SLColors.badDeep, false),
    ('xanh đúng đậm / giấy', SLColors.goodDeep, SLColors.paper, false),
    ('đỏ đậm / giấy (chữ lỗi)', SLColors.badDeep, SLColors.paper, false),
    // Trạng thái tắt: WCAG miễn trừ, vẫn giữ ≥ 3 cho dễ đọc.
    ('mực tắt / nền tắt', SLColors.disabledInk, SLColors.disabledFill, true),
  ];

  for (final (name, fg, bg, large) in pairs) {
    test('tương phản AA: $name', () {
      final r = slContrastRatio(fg, bg);
      expect(r, greaterThanOrEqualTo(large ? 3.0 : 4.5), reason: '$name = ${r.toStringAsFixed(2)}:1');
    });
  }

  test('màu nước: mực vẫn đạt AA ở vùng giữa nút (màu + vệt sáng/đậm ±10%)', () {
    for (final c in [SLColors.strawberry, SLColors.mint, SLColors.butter, SLColors.dangerSoft]) {
      final darker = Color.lerp(c, const Color(0xFF6B4532), 0.1 * 0.25)!; // vệt loang đậm (alpha ~0,1).
      expect(slContrastRatio(SLColors.ink, darker), greaterThanOrEqualTo(4.5), reason: '$c');
    }
  });
}
