import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/constants.dart';
import 'paint/sl_random.dart';

/// Token màu của bộ SL* (phong cách vẽ tay: giấy, gỗ, vải, mực nâu, màu nước).
/// Cặp chữ/nền dùng thật đều đạt WCAG AA — xem `test/ui/sugarleaf/sl_contrast_test.dart`.
abstract final class SLColors {
  // Bảng màu gốc (CLAUDE.md).
  static const cream = AppColors.cream;
  static const strawberry = AppColors.strawberry;
  static const mint = AppColors.mint;
  static const butter = AppColors.butter;
  static const caramel = AppColors.caramel;
  static const ink = AppColors.chocolate;
  static const good = AppColors.good;
  static const bad = AppColors.bad;

  // Chất liệu.
  /// Giấy trắng ngà (thẻ, vé, bong bóng thoại).
  static const paper = Color(0xFFFFFAF1);

  /// Giấy cũ / mặt sau tab chưa chọn.
  static const paperShade = Color(0xFFF3E3CC);

  /// Gỗ sáng (bảng tên, mặt gỗ có chữ).
  static const woodLight = Color(0xFFE6BF8F);

  /// Gỗ khung panel.
  static const wood = Color(0xFFC99467);

  /// Vân gỗ / mép gỗ đậm.
  static const woodDark = Color(0xFF8E5F3E);

  /// Vải dải ruy băng mặc định.
  static const fabric = strawberry;

  // Sắc nhạt (nền chọn, nền nhẹ) — chữ mực trên các nền này đều > 7:1.
  static const strawberryLight = Color(0xFFFAD3DD);
  static const mintLight = Color(0xFFD7EFE5);
  static const butterLight = Color(0xFFFFE8B5);

  /// Nền nút nguy hiểm (xoá dữ liệu): đỏ nhạt để chữ mực vẫn đạt AA (đỏ gốc #E86A5C chỉ 3:1).
  static const dangerSoft = Color(0xFFF6B1A7);

  // Sắc đậm cho chữ/biểu tượng trên giấy.
  /// Chữ phụ (thay caramel — caramel trên kem chỉ 3:1, không đạt AA).
  static const inkSoft = Color(0xFF7A5442);

  /// Nét bút chì kẻ dòng ([SLRule]): mực nhạt 60%.
  static const pencil = Color(0x997A5442);

  /// Xanh đúng dạng chữ (đúng gốc trên kem chỉ 2,2:1).
  static const goodDeep = Color(0xFF3A7340);

  /// Đỏ huy hiệu / chữ lỗi; chữ kem trên nền này ≥ 5:1.
  static const badDeep = Color(0xFFB9382C);

  // Trạng thái tắt.
  static const disabledFill = Color(0xFFE8DDD0);
  static const disabledInk = Color(0xFF8C7A70);

  /// Bóng nâu mềm lệch xuống của nhãn dán.
  static const shadow = Color(0x405A3E36);

  /// Nền tối nhẹ sau hộp thoại.
  static const barrier = Color(0x735A3E36);
}

/// Khoảng cách, bo góc, độ lún, vùng chạm, thời lượng hiệu ứng.
abstract final class SLMetrics {
  static const space2 = 4.0;
  static const space4 = 8.0;
  static const space6 = 12.0;
  static const space8 = 16.0;
  static const space12 = 24.0;

  static const radiusSmall = 12.0;
  static const radiusButton = 18.0;
  static const radiusPanel = 26.0;

  /// Nút lún xuống khi nhấn (bóng thu lại tương ứng).
  static const pressDepth = 3.0;

  /// Độ lệch bóng nâu của nút khi chưa nhấn.
  static const buttonLift = 4.0;
  static const panelLift = 5.0;

  /// Vùng chạm tối thiểu.
  static const minTap = 48.0;

  static const inkWidth = 2.4;

  static const pressIn = Duration(milliseconds: 70);
  static const pressOut = Duration(milliseconds: 160);
  static const bounce = Duration(milliseconds: 280);
  static const dialogIn = Duration(milliseconds: 320);
  static const dialogOut = Duration(milliseconds: 180);
  static const toastShow = Duration(milliseconds: 2200);
  static const progress = Duration(milliseconds: 450);
}

/// Tham số chung đặt qua `ThemeData.extensions` (không đặt → [SLTheme.standard]).
@immutable
class SLTheme extends ThemeExtension<SLTheme> {
  const SLTheme({
    this.ink = SLColors.ink,
    this.inkSoft = SLColors.inkSoft,
    this.paper = SLColors.paper,
    this.roughness = 1,
    this.inkWidth = SLMetrics.inkWidth,
  });

  static const standard = SLTheme();

  /// Màu mực (viền + chữ).
  final Color ink;
  final Color inkSoft;
  final Color paper;

  /// Hệ số độ run của nét (0 = thẳng, 1 = chuẩn).
  final double roughness;
  final double inkWidth;

  static SLTheme of(BuildContext context) => Theme.of(context).extension<SLTheme>() ?? standard;

  @override
  SLTheme copyWith({Color? ink, Color? inkSoft, Color? paper, double? roughness, double? inkWidth}) => SLTheme(
        ink: ink ?? this.ink,
        inkSoft: inkSoft ?? this.inkSoft,
        paper: paper ?? this.paper,
        roughness: roughness ?? this.roughness,
        inkWidth: inkWidth ?? this.inkWidth,
      );

  @override
  SLTheme lerp(SLTheme? other, double t) {
    if (other == null) return this;
    return SLTheme(
      ink: Color.lerp(ink, other.ink, t)!,
      inkSoft: Color.lerp(inkSoft, other.inkSoft, t)!,
      paper: Color.lerp(paper, other.paper, t)!,
      roughness: roughness + (other.roughness - roughness) * t,
      inkWidth: inkWidth + (other.inkWidth - inkWidth) * t,
    );
  }
}

/// Kiểu chữ SL*: lấy font từ `Theme.of(context).textTheme` (tiêu đề = titleLarge/headline*, nội dung =
/// bodyMedium/labelLarge — font do theme của app quyết định theo ngôn ngữ), tô màu mực.
@immutable
class SLTextStyles {
  const SLTextStyles._(this.title, this.heading, this.body, this.label, this.caption, this.number);

  factory SLTextStyles.of(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final ink = SLTheme.of(context).ink;
    TextStyle s(TextStyle? base, double size, FontWeight weight) =>
        (base ?? const TextStyle()).copyWith(fontSize: size, fontWeight: weight, color: ink, height: 1.2);
    return SLTextStyles._(
      // Tiêu đề giữ độ đậm của theme (font tiêu đề chỉ đóng gói một số weight).
      s(t.titleLarge, 24, t.titleLarge?.fontWeight ?? FontWeight.w700),
      s(t.headlineSmall, 30, t.headlineSmall?.fontWeight ?? FontWeight.w700),
      s(t.bodyMedium, 17, FontWeight.w600),
      s(t.labelLarge, 19, FontWeight.w800),
      s(t.bodyMedium, 14, FontWeight.w700),
      s(t.labelLarge, 18, FontWeight.w800),
    );
  }

  /// Tiêu đề hộp thoại, bảng tên, dải ruy băng.
  final TextStyle title;

  /// Tiêu đề lớn (màn, số tiền to).
  final TextStyle heading;

  /// Nội dung.
  final TextStyle body;

  /// Chữ trên nút, chip, tab.
  final TextStyle label;

  /// Chữ nhỏ (huy hiệu, chú thích).
  final TextStyle caption;

  /// Số trên thanh trên (tiền, đá quý).
  final TextStyle number;
}

/// Tắt hiệu ứng theo cài đặt trợ năng của máy.
bool slReduceMotion(BuildContext context) => MediaQuery.maybeDisableAnimationsOf(context) ?? false;

/// Seed mặc định ổn định: [seed] → giá trị của `ValueKey` → nội dung (nhãn, tiêu đề) → hằng số theo loại widget.
/// Không bao giờ ngẫu nhiên theo lần dựng.
int slSeed({int? seed, Key? key, Object? content, int salt = 0}) {
  if (seed != null) return seed;
  if (key is ValueKey) return SLRandom.hashString('${key.value}') ^ salt;
  if (content != null) return SLRandom.hashString('$content') ^ salt;
  return 0x5EED ^ salt;
}

/// Bọc chung cho cây dùng SL*: đặt DefaultTextStyle (mực nâu + font nội dung) và IconTheme màu mực — để chữ
/// vẫn đúng kiểu khi không có `Scaffold`/`Material` phía trên.
class SLScope extends StatelessWidget {
  const SLScope({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final styles = SLTextStyles.of(context);
    return DefaultTextStyle(
      style: styles.body,
      child: IconTheme(data: IconThemeData(color: SLTheme.of(context).ink), child: child),
    );
  }
}

/// Độ chói tương đối (WCAG 2.x) của màu đặc.
double slLuminance(Color c) {
  double ch(double v) => v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * ch(c.r) + 0.7152 * ch(c.g) + 0.0722 * ch(c.b);
}

/// Tỉ lệ tương phản WCAG giữa chữ [fg] (có thể trong suốt — trộn lên [bg]) và nền đặc [bg]. AA: ≥ 4,5
/// (chữ thường), ≥ 3 (chữ lớn ≥ 18,66px đậm).
double slContrastRatio(Color fg, Color bg) {
  final f = fg.a >= 1 ? fg : Color.alphaBlend(fg, bg);
  final a = slLuminance(f), b = slLuminance(bg);
  return (math.max(a, b) + 0.05) / (math.min(a, b) + 0.05);
}
