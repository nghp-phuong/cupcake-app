/// Tham số chạy thử của bản thành phố (docs/v3/city-gd2-spec.md §3). Web: query của URL; Android: query của route ban
/// đầu (`--es route '/?…'`).
///
/// - `save=memory`: lưu trong bộ nhớ, không đụng save thật. Có `coins=`, `xp=`, `level=` hoặc `day=` (kể cả giá trị
///   hỏng) thì tự bật `save=memory`.
/// - `level=<n>` (kẹp 1..30) → XP tối thiểu của cấp đó; có cả `xp=` thì `xp` thắng.
/// - `day=<n>` (≥ 1) → số ngày đã chơi (`dayNumber`, thử interstitial; GĐ3 §7).
/// - `intro=0|1` (bỏ / ép intro), `lang=vi|en` (chỉ trong phiên, không lưu), `spawn=<x>,<z>`, `debug=1|0` (mặc định
///   [kDebugMode]), `log=1`, `mochi=1`.
/// - Đồ hoạ (`quality`, `scale`, `fps`, `shadows`, `smap`, `post`, `aa`, `blob`, `soft`, `ibl`, `tm`, `maxpx`), ánh
///   sáng (`sun`, `amb`, `fill`, `sky`, `ambi`), `tex`: core không hiểu, tầng game đọc từ [CityDebugParams.raw].
library;

import 'dart:ui' show Locale, PlatformDispatcher;

import 'package:flutter/foundation.dart';

import 'city/city_game.dart';
import 'city/player_level.dart';

class CityDebugParams {
  const CityDebugParams({
    this.memorySave = false,
    this.coins,
    this.xp,
    this.level,
    this.day,
    this.intro,
    this.locale,
    this.spawn,
    this.showDebug = kDebugMode,
    this.verbose = false,
    this.mochi = false,
    this.raw = const {},
  });

  /// Không có tham số nào.
  static const none = CityDebugParams();

  /// Đọc từ nền tảng: web `Uri.base`, native route ban đầu. Query hỏng → như không có tham số.
  factory CityDebugParams.fromPlatform() {
    Map<String, String> q;
    try {
      q = kIsWeb
          ? Uri.base.queryParameters
          : Uri.tryParse(
                  PlatformDispatcher.instance.defaultRouteName,
                )?.queryParameters ??
                const {};
    } catch (e) {
      debugPrint('CityDebugParams: query hỏng, bỏ qua ($e)');
      q = const {};
    }
    return CityDebugParams.fromQuery(q);
  }

  factory CityDebugParams.fromQuery(Map<String, String> q) {
    int? asInt(String k) => int.tryParse(q[k] ?? '');
    final level = asInt('level')?.clamp(1, PlayerLevel.maxLevel);
    return CityDebugParams(
      memorySave:
          q['save'] == 'memory' ||
          q.containsKey('coins') ||
          q.containsKey('xp') ||
          q.containsKey('level') ||
          q.containsKey('day'),
      coins: asInt('coins'),
      xp: asInt('xp') ?? (level == null ? null : PlayerLevel.xpToReach(level)),
      level: level,
      day: asInt('day')?.clamp(1, _dayCap),
      intro: switch (q['intro']) {
        '0' => false,
        '1' => true,
        _ => null,
      },
      locale: switch (q['lang']) {
        'vi' => const Locale('vi'),
        'en' => const Locale('en'),
        _ => null,
      },
      spawn: switch (q['spawn']?.split(',').map(double.tryParse).toList()) {
        [final x?, final z?] when x.isFinite && z.isFinite => (x: x, z: z),
        _ => null,
      },
      showDebug: switch (q['debug']) {
        '1' => true,
        '0' => false,
        _ => kDebugMode,
      },
      verbose: q['log'] == '1',
      mochi: q['mochi'] == '1',
      raw: Map.unmodifiable(q),
    );
  }

  /// Lưu trong bộ nhớ (`MemoryCitySaveRepository`) thay vì save thật.
  final bool memorySave;

  /// Xu / XP đặt lúc khởi động (chỉ áp khi [memorySave]); null = giữ theo save.
  final int? coins, xp;

  /// `level=` đã kẹp 1..30 (đã quy ra [xp]); null = không đặt.
  final int? level;

  /// Số ngày đã chơi đặt lúc khởi động (kẹp ≥ 1; chỉ áp khi [memorySave]); null = giữ theo save.
  final int? day;

  /// true = ép chạy intro, false = bỏ intro, null = theo save (`introSeen`).
  final bool? intro;

  /// Ngôn ngữ ép trong phiên (không lưu vào cài đặt); null = theo cài đặt.
  final Locale? locale;

  /// Chỗ Mai xuất hiện (toạ độ lớp phố); null = trước cửa tiệm của bà.
  final ({double x, double z})? spawn;

  /// Chip debug trên cảnh.
  final bool showDebug;

  /// `log=1`: in tiến độ dựng cảnh.
  final bool verbose;

  /// `mochi=1`: mèo Mochi trong tiệm.
  final bool mochi;

  /// Toàn bộ query (chỉ đọc), cho tham số đồ hoạ / ánh sáng / `tex` mà tầng game tự đọc.
  final Map<String, String> raw;

  /// Áp [coins] / [xp] / [day] vào ví (chỉ khi [memorySave], để không bao giờ sửa save thật). Không đổi ngôn ngữ (xem
  /// [locale]) và không đổi `levelSeen`.
  void applyTo(CityGame game) {
    if (!memorySave || (coins == null && xp == null && day == null)) return;
    game.restore(game.toSave().copyWith(coins: coins, xp: xp, dayNumber: day));
  }
}

/// Trần `day=` (2^31 − 1, như `day.n` của save).
const int _dayCap = 2147483647;
