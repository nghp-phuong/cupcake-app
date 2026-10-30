import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show AssetBundle;

import '../config_reader.dart';
import '../models/ids.dart';
import 'booster.dart';
import 'monetization_config.dart';
import 'season.dart';

/// Đọc + kiểm tra `assets/config/monetization.json`. Lỗi → [FormatException] ghi rõ id + trường.
///
/// Chế độ chặt (mặc định ở bản debug, `kDebugMode`): lỗi đầu tiên → ném; phải có đủ mọi [BoosterId]. Chế độ khoan dung
/// (bản phát hành): vật phẩm hỏng / thiếu → bản dự phòng [BoosterData.fallback], gói IAP hỏng bị bỏ khỏi cửa hàng,
/// mùa hỏng → không có thẻ mùa (ghi `debugPrint` lý do); chỉ ném khi JSON hỏng.
abstract final class MonetizationConfigLoader {
  static const assetPath = 'assets/config/monetization.json';

  static final _artPattern = RegExp(r'^[a-z_]+/[A-Za-z0-9_]+$');
  static final _idPattern = RegExp(r'^[a-z0-9_]+$');

  /// [strict] null → theo `kDebugMode`.
  static Future<MonetizationConfig> load(AssetBundle bundle, {bool? strict}) async =>
      parse(await bundle.loadString(assetPath), strict: strict);

  /// Như [load] nhưng không bao giờ ném: thiếu asset / JSON hỏng → `debugPrint` + [MonetizationConfig.empty] (vật phẩm
  /// theo giá dự phòng, cửa hàng theo danh mục code, không có thẻ mùa). Dùng ở main.dart.
  static Future<MonetizationConfig> loadOrEmpty(AssetBundle bundle, {bool? strict}) async {
    try {
      return await load(bundle, strict: strict);
    } catch (e) {
      debugPrint('MonetizationConfigLoader: không nạp được $assetPath, dùng bản dự phòng ($e)');
      return MonetizationConfig.empty();
    }
  }

  /// [strict] null → theo `kDebugMode`; [onSkip] nhận lý do mỗi phần bị bỏ ở chế độ khoan dung (mặc định debugPrint).
  static MonetizationConfig parse(String json, {bool? strict, void Function(String reason)? onSkip}) {
    final isStrict = strict ?? kDebugMode;
    final report = onSkip ?? (String reason) => debugPrint('MonetizationConfigLoader: bỏ qua — $reason');

    T? guard<T>(T Function() read) {
      if (isStrict) return read();
      try {
        return read();
      } on FormatException catch (e) {
        report(e.message);
        return null;
      }
    }

    final Object? root;
    try {
      root = jsonDecode(json);
    } on FormatException catch (e) {
      throw FormatException('monetization.json: JSON không hợp lệ (${e.message})');
    }
    if (root is! Map<String, dynamic>) throw const FormatException('monetization.json: gốc phải là object');
    final top = ConfigReader(root, 'monetization.json');
    final version = guard(() => top.integer('version', min: 1)) ?? 1;

    final boosters = <BoosterData>[];
    final rawBoosters = guard(() => top.list('boosters')) ?? const <dynamic>[];
    for (var i = 0; i < rawBoosters.length; i++) {
      final b = guard(() => _booster(rawBoosters[i], i, boosters));
      if (b != null) boosters.add(b);
    }
    for (final id in BoosterId.values) {
      if (boosters.any((b) => b.id == id)) continue;
      final missing = guard<BoosterData>(() => top.fail('boosters', 'thiếu vật phẩm "${id.name}"'));
      boosters.add(missing ?? BoosterData.fallback.firstWhere((b) => b.id == id));
    }

    final season = top.has('season') ? guard(() => _season(top.object('season'), 'season')) : null;
    // Khoan dung: phần mùa hỏng → báo cờ để GameState giữ nguyên dữ liệu mùa trong bản lưu (không coi là hết mùa).
    var seasonInvalid = top.has('season') && season == null;
    final previous = <SeasonData>[];
    final rawPreviousOrNull = top.has('previousSeasons') ? guard(() => top.list('previousSeasons')) : const <dynamic>[];
    if (rawPreviousOrNull == null) seasonInvalid = true;
    final rawPrevious = rawPreviousOrNull ?? const <dynamic>[];
    for (var i = 0; i < rawPrevious.length; i++) {
      final s = guard(() => _season(_map(rawPrevious[i], 'previousSeasons[$i]'), 'previousSeasons[$i]'));
      if (s == null) {
        seasonInvalid = true;
        continue;
      }
      if (s.id == season?.id || previous.any((p) => p.id == s.id)) {
        guard<void>(() => throw FormatException('monetization.json: previousSeasons[$i]: trùng id mùa "${s.id}"'));
        continue;
      }
      previous.add(s);
    }

    final products = <IapProduct>[];
    final rawProducts = guard(() => top.list('products')) ?? const <dynamic>[];
    for (var i = 0; i < rawProducts.length; i++) {
      final p = guard(() => _product(rawProducts[i], i, products));
      if (p != null) products.add(p);
    }
    guard(() => top.rejectUnknown(const {'version', 'boosters', 'season', 'previousSeasons', 'products'}));
    return MonetizationConfig(
      version: version,
      boosters: boosters,
      season: season,
      previousSeasons: previous,
      seasonInvalid: seasonInvalid,
      products: products,
    );
  }

  static const _boosterKeys = {'id', 'art', 'gemPrice', 'name', 'desc'};

  static BoosterData _booster(Object? raw, int index, List<BoosterData> seen) {
    final m = _map(raw, 'boosters[$index]');
    final id = ConfigReader(m, 'boosters #${index + 1}').enumValue('id', BoosterId.values, what: 'vật phẩm');
    final r = ConfigReader(m, 'vật phẩm ${id.name}');
    if (seen.any((b) => b.id == id)) r.fail('id', 'trùng id');
    final data = BoosterData(
      id: id,
      art: _art(r),
      gemPrice: r.integer('gemPrice', min: 1),
      names: r.title('name'),
      descs: r.title('desc'),
    );
    r.rejectUnknown(_boosterKeys);
    return data;
  }

  static const _seasonKeys = {'id', 'name', 'start', 'end', 'pointsPerNewStar', 'pointsPerWin', 'tiers'};

  static SeasonData _season(Map<String, dynamic> m, String field) {
    final rawId = ConfigReader(m, field).string('id');
    final r = ConfigReader(m, 'mùa $rawId');
    if (!_idPattern.hasMatch(rawId)) r.fail('id', 'chỉ dùng a-z, 0-9, "_", có "$rawId"');
    DateTime date(String key) {
      final v = r.string(key);
      final d = DateTime.tryParse(v);
      if (d == null) r.fail(key, 'phải là ngày ISO (vd. "2026-11-01T00:00:00"), có "$v"');
      // Có múi giờ ("Z", "+07:00") → DateTime.parse trả giờ UTC.
      if (d.isUtc) r.fail(key, 'dùng giờ máy (không ghi múi giờ), có "$v"');
      return d;
    }

    final start = date('start'), end = date('end');
    if (!end.isAfter(start)) r.fail('end', 'phải sau start');
    final rawTiers = r.list('tiers');
    if (rawTiers.isEmpty) r.fail('tiers', 'rỗng');
    final tiers = <SeasonTier>[];
    for (var i = 0; i < rawTiers.length; i++) {
      final t = ConfigReader(_map(rawTiers[i], 'mùa $rawId, tiers[$i]'), 'mùa $rawId, bậc ${i + 1}');
      final points = t.integer('points', min: 1);
      if (tiers.isNotEmpty && points <= tiers.last.points) t.fail('points', 'phải tăng dần theo bậc (cộng dồn)');
      tiers.add(SeasonTier(
        points: points,
        free: t.has('free') ? _reward(t.object('free'), '${t.where}, free') : Reward.none,
        premium: t.has('premium') ? _reward(t.object('premium'), '${t.where}, premium') : Reward.none,
      ));
      t.rejectUnknown(const {'points', 'free', 'premium'});
    }
    final data = SeasonData(
      id: rawId,
      start: start,
      end: end,
      tiers: List.unmodifiable(tiers),
      pointsPerNewStar: r.has('pointsPerNewStar') ? r.integer('pointsPerNewStar', min: 0) : 10,
      pointsPerWin: r.has('pointsPerWin') ? r.integer('pointsPerWin', min: 0) : 5,
      names: r.title('name'),
    );
    r.rejectUnknown(_seasonKeys);
    return data;
  }

  static Reward _reward(Map<String, dynamic> m, String where) {
    final r = ConfigReader(m, where);
    final boosters = <BoosterId, int>{};
    if (r.has('boosters')) {
      final b = ConfigReader(r.object('boosters'), '$where, boosters');
      for (final k in b.json.keys) {
        if (k.startsWith('_')) continue;
        final id = enumByName(BoosterId.values, k) ?? b.fail(k, 'vật phẩm "$k" không tồn tại');
        boosters[id] = b.integer(k, min: 1);
      }
    }
    String? frame;
    if (r.has('frame')) {
      frame = r.string('frame');
      if (!_idPattern.hasMatch(frame)) r.fail('frame', 'chỉ dùng a-z, 0-9, "_", có "$frame"');
    }
    final reward = Reward(
      coins: r.has('coins') ? r.integer('coins', min: 0) : 0,
      gems: r.has('gems') ? r.integer('gems', min: 0) : 0,
      boosters: Map.unmodifiable(boosters),
      frame: frame,
    );
    r.rejectUnknown(const {'coins', 'gems', 'boosters', 'frame'});
    if (reward.isEmpty) r.fail('coins', 'phần thưởng rỗng (bỏ hẳn trường nếu không có thưởng)');
    return reward;
  }

  static const _productKeys = {'id', 'price', 'kind', 'art', 'reward', 'name', 'desc'};

  static IapProduct _product(Object? raw, int index, List<IapProduct> seen) {
    final m = _map(raw, 'products[$index]');
    final id = ConfigReader(m, 'products #${index + 1}').enumValue('id', IapProductId.values, what: 'gói');
    final r = ConfigReader(m, 'gói ${id.name}');
    if (seen.any((p) => p.id == id)) r.fail('id', 'trùng id');
    if (IapCatalog.hidden.contains(id)) r.fail('id', 'gói V1 đã ẩn khỏi cửa hàng V2');
    final kind = r.enumValue('kind', IapKind.values, what: 'loại');
    final expected = IapCatalog.product(id).kind;
    if (kind != expected) r.fail('kind', 'gói ${id.name} phải là "${expected.name}"');
    final price = r.string('price');
    final reward = r.has('reward') ? _reward(r.object('reward'), 'gói ${id.name}, reward') : Reward.none;
    if (kind == IapKind.consumable && reward.isEmpty) r.fail('reward', 'gói tiêu hao phải có phần thưởng');
    final data = IapProduct(
      id,
      price,
      kind: kind,
      reward: reward,
      art: _art(r),
      names: r.title('name'),
      descs: r.title('desc'),
    );
    r.rejectUnknown(_productKeys);
    return data;
  }

  static String _art(ConfigReader r) {
    final v = r.json['art'];
    if (v == null || v == '') return '';
    if (v is! String || !_artPattern.hasMatch(v)) r.fail('art', 'phải là "nhóm/tên" (vd. "level/booster_oven") hoặc ""');
    return v;
  }

  static Map<String, dynamic> _map(Object? v, String field) {
    if (v is Map<String, dynamic>) return v;
    throw FormatException('monetization.json: "$field" phải là object');
  }
}
