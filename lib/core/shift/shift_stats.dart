/// Thống kê tiệm của bà qua các ca (khoá `bakery` của save v3, docs/v3/city-gd3-spec.md §3): bản chụp bất biến, so
/// sánh bằng `==`. Đọc / kẹp giá trị ở `CitySave.decode`; ghi theo [ShiftStats.toJson].
library;

import 'package:flutter/foundation.dart';

class ShiftStats {
  ShiftStats({
    this.shifts = 0,
    this.orders = 0,
    this.stars = 0,
    this.five = 0,
    this.coins = 0,
    this.best = 0,
    Set<String> tutorial = const {},
    this.recipeSeen = 0,
    this.adDay = 0,
  }) : tutorial = Set.unmodifiable(tutorial);

  /// Số ca đã đóng (hết ca hoặc đóng sớm).
  final int shifts;

  /// Số đơn đã tính, tổng sao, số đơn 5★.
  final int orders, stars, five;

  /// Tổng xu kiếm từ ca (gồm x2 quảng cáo); kỷ lục xu của một ca hết khách (không tính x2).
  final int coins, best;

  /// Tên `StationId` đã xem hướng dẫn (giữ cả chuỗi lạ).
  final Set<String> tutorial;

  /// Cấp Mai đã báo "Mở mới!" (1..30); 0 = chưa có mốc: lấy cấp hiện tại, không báo bù.
  final int recipeSeen;

  /// `dayNumber` của lần interstitial gần nhất (0 = chưa có).
  final int adDay;

  Map<String, Object?> toJson() => {
    'shifts': shifts,
    'orders': orders,
    'stars': stars,
    'five': five,
    'coins': coins,
    'best': best,
    'tutorial': tutorial.toList()..sort(),
    'recipeSeen': recipeSeen,
    'adDay': adDay,
  };

  /// Bản sao đổi vài trường (null = giữ).
  ShiftStats copyWith({
    int? shifts,
    int? orders,
    int? stars,
    int? five,
    int? coins,
    int? best,
    Set<String>? tutorial,
    int? recipeSeen,
    int? adDay,
  }) => ShiftStats(
    shifts: shifts ?? this.shifts,
    orders: orders ?? this.orders,
    stars: stars ?? this.stars,
    five: five ?? this.five,
    coins: coins ?? this.coins,
    best: best ?? this.best,
    tutorial: tutorial ?? this.tutorial,
    recipeSeen: recipeSeen ?? this.recipeSeen,
    adDay: adDay ?? this.adDay,
  );

  @override
  bool operator ==(Object other) =>
      other is ShiftStats &&
      other.shifts == shifts &&
      other.orders == orders &&
      other.stars == stars &&
      other.five == five &&
      other.coins == coins &&
      other.best == best &&
      setEquals(other.tutorial, tutorial) &&
      other.recipeSeen == recipeSeen &&
      other.adDay == adDay;

  @override
  int get hashCode => Object.hash(
    shifts,
    orders,
    stars,
    five,
    coins,
    best,
    Object.hashAllUnordered(tutorial),
    recipeSeen,
    adDay,
  );

  @override
  String toString() => 'ShiftStats(${toJson()})';
}
