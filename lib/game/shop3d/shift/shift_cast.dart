import 'dart:math' as math;

import '../chibi/chibi_cast.dart';
import '../chibi/chibi_characters.dart';
import '../chibi/chibi_regulars.dart';
import '../chibi/chibi_rig.dart';

/// Chọn chibi cho khách của ca bán (docs/v3/city-gd3-spec.md): khách thường dùng `regular_*`, khách VIP dùng
/// `vip_01` / `vip_02` (`vip_00` là bà Rosa, khách nền). Dart thuần — không import thermion.

/// Id VIP dùng cho khách có đơn (không gồm bà Rosa `vip_00`, khách nền).
const List<String> shiftVipIds = [ChibiCharacters.stag, ChibiCharacters.lamb];

/// Id khách thường dùng cho khách có đơn: 15 `regular_*` (không trùng khách nền [ChibiCast.ambientGuestIds]).
List<String> get shiftRegularIds => [
      for (final id in ChibiRegulars.ids)
        if (!ChibiCast.ambientGuestIds.contains(id)) id,
    ];

/// [id] có thể là khách của ca (lớp cảnh dựng sẵn model cho các id này — `Shop3dScene.prepareModels`).
bool isShiftGuestId(String id) => shiftRegularIds.contains(id) || shiftVipIds.contains(id);

/// Dựng model (chưa [ChibiSizes.fit]) của khách ca [id].
ChibiModel buildShiftGuest(String id) =>
    shiftVipIds.contains(id) ? ChibiCharacters.build(id) : ChibiRegulars.build(id);

/// [count] id chibi khách cho một ca: không trùng nhau, không trùng khách nền.
/// - [vip] false: toàn `regular_*`.
/// - [vip] true: lấy từ `vip_01` / `vip_02` (xáo ngẫu nhiên); quá 2 thì phần còn lại là `regular_*`.
///
/// [count] vượt số khách thường (15) → [ArgumentError]. Ca có cả khách thường lẫn VIP: dùng [castForShift] để id không
/// trùng giữa hai nhóm.
List<String> castFor(int count, {bool vip = false, math.Random? random}) =>
    castForShift(List.filled(math.max(0, count), vip), random: random);

/// Id chibi cho từng khách của ca, theo [vipFlags] (true = khách VIP): VIP lấy `vip_01` / `vip_02` trước, hết thì lấy
/// `regular_*`; mọi id không trùng nhau và không trùng khách nền. Kết quả cùng thứ tự với [vipFlags].
List<String> castForShift(List<bool> vipFlags, {math.Random? random}) {
  final rng = random ?? math.Random();
  final regular = shiftRegularIds..shuffle(rng);
  final vips = [...shiftVipIds]..shuffle(rng);
  final needRegular = vipFlags.length - math.min(vips.length, vipFlags.where((v) => v).length);
  if (needRegular > regular.length) {
    throw ArgumentError.value(vipFlags.length, 'count', 'too many guests for one shift');
  }
  return [
    for (final isVip in vipFlags)
      if (isVip && vips.isNotEmpty) vips.removeLast() else regular.removeLast(),
  ];
}
