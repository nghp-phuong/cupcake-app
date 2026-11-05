/// Số liệu kinh tế của ca bán trong tiệm (docs/v3/city-gd3-spec.md §3–§4).
library;

import '../economy.dart';

abstract final class ShiftEconomy {
  /// Hệ số nhân xu (tiền khách trả, tip, chi phí nguyên liệu) so với bảng giá của `Catalog`.
  static const coinMult = 4;

  /// XP thưởng khi phục vụ hết khách của ca.
  static const completeBonusXp = 30;

  /// % tip cộng thêm khi có buff "No bụng" (truyền vào `Scoring.evaluate` qua `decorTipBonusPct`).
  static const buffTipPct = 10;

  /// Khách chưa tới quầy sau thời gian này thì đặt thẳng vào quầy.
  static const arriveTimeout = Duration(seconds: 12);

  /// Số khách mỗi ca theo cấp Mai: 4 (cấp 1–3), 5 (cấp 4–9), 6 (từ cấp 10).
  static int customersFor(int maiLevel) => Economy.customersPerDay(maiLevel);
}
