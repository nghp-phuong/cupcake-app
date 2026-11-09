/// Tham số chạy thử của bản thành phố (docs/v3/city-gd2-spec.md §3). Web: query của URL; Android: query của route ban
/// đầu (`--es route '/?…'`).
///
/// - `save=memory`: lưu trong bộ nhớ, không đụng save thật. Có `coins=`, `xp=`, `level=`, `day=`, `branches=`,
///   `staff=`, `till=` hoặc `away=` (kể cả giá trị hỏng) thì tự bật `save=memory`.
/// - `level=<n>` (kẹp 1..30) → XP tối thiểu của cấp đó; có cả `xp=` thì `xp` thắng.
/// - `day=<n>` (≥ 1) → số ngày đã chơi (`dayNumber`, thử interstitial; GĐ3 §7).
/// - Chi nhánh (GĐ4 §7-13): `branches=s1:3,s3:1` (lô:cấp, thiếu cấp = 1), `staff=ami@s1,hanh@s3`, `till=full` (két
///   mọi chi nhánh đầy), `away=<giờ>` (lùi mốc két, như vừa vắng nhà chừng ấy giờ).
/// - `intro=0|1` (bỏ / ép intro), `lang=vi|en` (chỉ trong phiên, không lưu), `spawn=<x>,<z>`, `debug=1|0` (mặc định
///   [kDebugMode]), `log=1`, `mochi=1`.
/// - Đồ hoạ (`quality`, `scale`, `fps`, `shadows`, `smap`, `post`, `aa`, `blob`, `soft`, `ibl`, `tm`, `maxpx`), ánh
///   sáng (`sun`, `amb`, `fill`, `sky`, `ambi`), `tex`: core không hiểu, tầng game đọc từ [CityDebugParams.raw].
library;

import 'dart:ui' show Locale, PlatformDispatcher;

import 'package:flutter/foundation.dart';

import 'branch/branch_economy.dart';
import 'branch/branch_state.dart';
import 'branch/staff.dart';
import 'city/city_config.dart';
import 'city/city_game.dart';
import 'city/player_level.dart';

class CityDebugParams {
  const CityDebugParams({
    this.memorySave = false,
    this.coins,
    this.xp,
    this.level,
    this.day,
    this.branches,
    this.staff,
    this.tillFull = false,
    this.away,
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
          q.containsKey('day') ||
          q.containsKey('branches') ||
          q.containsKey('staff') ||
          q.containsKey('till') ||
          q.containsKey('away'),
      coins: asInt('coins'),
      xp: asInt('xp') ?? (level == null ? null : PlayerLevel.xpToReach(level)),
      level: level,
      day: asInt('day')?.clamp(1, _dayCap),
      branches: _lotLevels(q['branches']),
      staff: _staffLots(q['staff']),
      tillFull: q['till'] == 'full',
      away: switch (double.tryParse(q['away'] ?? '')) {
        final h? when h.isFinite && h > 0 => h.clamp(0, _awayCap).toDouble(),
        _ => null,
      },
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

  /// Chi nhánh đặt lúc khởi động (chỉ áp khi [memorySave]): lô → cấp (kẹp 1..5); null = giữ theo save.
  final Map<String, int>? branches;

  /// Nhân viên → lô (chỉ áp khi [memorySave]; id lạ / lô chưa mua bị bỏ); null = giữ theo save.
  final Map<String, String>? staff;

  /// `till=full`: két mọi chi nhánh đầy (chỉ áp khi [memorySave]).
  final bool tillFull;

  /// `away=<giờ>`: lùi mốc két chừng ấy giờ, lần `resume` kế tiếp bù như vừa vắng nhà (chỉ áp khi [memorySave]).
  final double? away;

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

  /// Áp [coins] / [xp] / [day] vào ví và [branches] / [staff] / [tillFull] / [away] vào chi nhánh (chỉ khi
  /// [memorySave], để không bao giờ sửa save thật). Không đổi ngôn ngữ (xem [locale]) và không đổi `levelSeen`. [now]:
  /// giờ máy (mặc định `DateTime.now()`; test truyền giờ giả).
  void applyTo(CityGame game, {DateTime? now}) {
    final branchParams =
        branches != null || staff != null || tillFull || away != null;
    if (!memorySave ||
        (coins == null && xp == null && day == null && !branchParams)) {
      return;
    }
    final save = game.toSave();
    game.restore(
      save.copyWith(
        coins: coins,
        xp: xp,
        dayNumber: day,
        branches: branchParams
            ? _branchBook(save.branches, now ?? DateTime.now())
            : null,
      ),
    );
  }

  BranchBook _branchBook(BranchBook b, DateTime now) {
    final ms = now.millisecondsSinceEpoch;
    final lots = {...b.lots};
    branches?.forEach((id, level) {
      if (_branchLot(id) == null) return;
      lots[id] = (lots[id] ?? BranchState(lotId: id, boughtAt: ms)).copyWith(
        level: level,
      );
    });
    final members = [...b.staff];
    staff?.forEach((id, lot) {
      if (StaffRoster.byId(id) == null || !lots.containsKey(lot)) return;
      members
        ..removeWhere((m) => m.id == id)
        ..add(StaffMember(id: id, lotId: lot, since: ms));
    });
    if (tillFull) {
      for (final id in lots.keys.toList()) {
        var bonus = 0;
        for (final m in members) {
          if (m.lotId == id) bonus += StaffRoster.byId(m.id)!.bonusPct;
        }
        lots[id] = lots[id]!.copyWith(
          tillMilli: BranchEconomy.capMilli(
            _branchLot(id)!,
            lots[id]!.level,
            bonusPct: bonus,
          ),
        );
      }
    }
    final clock = away != null
        ? ms - (away! * 3600000).round()
        : (b.clock > 0 ? b.clock : ms);
    return BranchBook(
      clock: clock < 1 ? 1 : clock,
      lots: lots,
      staff: members,
      extraLots: b.extraLots,
      extraStaff: b.extraStaff,
    );
  }

  /// `s1:3,s3:1` → {s1: 3, s3: 1}; thiếu / hỏng cấp → 1, kẹp 1..5. Không có mục nào → null.
  static Map<String, int>? _lotLevels(String? v) {
    if (v == null) return null;
    final out = <String, int>{};
    for (final part in v.split(',')) {
      final [id, ...rest] = part.trim().split(':');
      if (id.isEmpty) continue;
      final level = rest.isEmpty ? null : int.tryParse(rest.first);
      out[id] = (level ?? 1).clamp(1, BranchEconomy.maxLevel);
    }
    return out.isEmpty ? null : out;
  }

  /// `ami@s1,hanh@s3` → {ami: s1, hanh: s3}. Không có mục nào → null.
  static Map<String, String>? _staffLots(String? v) {
    if (v == null) return null;
    final out = <String, String>{};
    for (final part in v.split(',')) {
      if (part.trim().split('@') case [
        final id,
        final lot,
      ] when id.isNotEmpty && lot.isNotEmpty) {
        out[id] = lot;
      }
    }
    return out.isEmpty ? null : out;
  }

  /// Lô chi nhánh theo id (mọi quận của [CityConfig.alpha]).
  static LotDef? _branchLot(String id) {
    for (final d in CityConfig.alpha.districts) {
      for (final l in d.lots) {
        if (l.id == id && l.baseIncome > 0) return l;
      }
    }
    return null;
  }
}

/// Trần `day=` (2^31 − 1, như `day.n` của save).
const int _dayCap = 2147483647;

/// Trần `away=` (giờ): 10 năm, quá mức két đầy từ lâu.
const int _awayCap = 87600;
