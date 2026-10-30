import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show AssetBundle;

import '../config_reader.dart';
import 'unlock_config.dart';

/// Đọc + kiểm tra `assets/config/unlocks.json`. Lỗi → [FormatException] ghi rõ id + trường.
///
/// Chế độ chặt (mặc định ở bản debug, `kDebugMode`): lỗi đầu tiên → ném. Chế độ khoan dung (bản phát hành): bỏ mục hỏng
/// (ghi `debugPrint` lý do), khoá hiệu ứng / tham số lạ bị bỏ, thiết bị lạ vẫn giữ (không có hiệu ứng), nhân viên
/// không khớp mục mở khoá `kind: staff` bị bỏ; chỉ ném khi JSON hỏng.
abstract final class UnlockConfigLoader {
  static const assetPath = 'assets/config/unlocks.json';

  /// `art` = `nhóm/tên` dưới assets/art/ (hoặc rỗng).
  static final _artPattern = RegExp(r'^[a-z_]+/[A-Za-z0-9_]+$');

  /// Id không chứa ":" (khoá `eq:<id>:<cấp>`).
  static final _idPattern = RegExp(r'^[A-Za-z0-9_]+$');

  /// id ảnh nhân vật (`assets/characters/<id>_<nét mặt>.webp`).
  static final _characterPattern = RegExp(r'^[a-z0-9_]+$');

  /// [strict] null → theo `kDebugMode`.
  static Future<UnlockConfig> load(AssetBundle bundle, {bool? strict}) async =>
      parse(await bundle.loadString(assetPath), strict: strict);

  /// Như [load] nhưng không bao giờ ném: thiếu asset / JSON hỏng → `debugPrint` + [UnlockConfig.empty] (app vẫn chạy,
  /// không có mở rộng; lò/dụng cụ V1 nâng theo bảng dự phòng). Dùng ở main.dart.
  static Future<UnlockConfig> loadOrEmpty(AssetBundle bundle, {bool? strict}) async {
    try {
      return await load(bundle, strict: strict);
    } catch (e) {
      debugPrint('UnlockConfigLoader: không nạp được $assetPath, tắt mở rộng tiệm ($e)');
      return UnlockConfig.empty();
    }
  }

  /// [strict] null → theo `kDebugMode`; [onSkip] nhận lý do mỗi phần bị bỏ ở chế độ khoan dung (mặc định debugPrint).
  static UnlockConfig parse(String json, {bool? strict, void Function(String reason)? onSkip}) {
    final isStrict = strict ?? kDebugMode;
    final report = onSkip ?? (String reason) => debugPrint('UnlockConfigLoader: bỏ qua — $reason');

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
      throw FormatException('unlocks.json: JSON không hợp lệ (${e.message})');
    }
    if (root is! Map<String, dynamic>) throw const FormatException('unlocks.json: gốc phải là object');
    final top = ConfigReader(root, 'unlocks.json');
    final version = guard(() => top.integer('version', min: 1)) ?? 1;

    final unlocks = <UnlockData>[];
    RecipeSecretsData? secrets;
    final rawUnlocks = guard(() => top.list('unlocks')) ?? const <dynamic>[];
    for (var i = 0; i < rawUnlocks.length; i++) {
      final raw = rawUnlocks[i];
      if (raw is Map<String, dynamic> && raw['kind'] == recipeSecretsKind) {
        final had = secrets;
        secrets = guard(() => _recipeSecrets(raw, i, had, unlocks)) ?? had;
        continue;
      }
      final u = guard(() => _unlock(raw, i, unlocks, isStrict, report));
      if (u != null) unlocks.add(u);
    }

    final equipment = <EquipmentData>[];
    final rawEquipment = guard(() => top.list('equipment')) ?? const <dynamic>[];
    for (var i = 0; i < rawEquipment.length; i++) {
      final e = guard(() => _equipment(rawEquipment[i], i, equipment, isStrict, report));
      if (e != null) equipment.add(e);
    }

    final staff = <StaffData>[];
    final rawStaff = top.has('staff') ? guard(() => top.list('staff')) ?? const <dynamic>[] : const <dynamic>[];
    for (var i = 0; i < rawStaff.length; i++) {
      final st = guard(() => _staff(rawStaff[i], i, staff, unlocks, isStrict, report));
      if (st != null) staff.add(st);
    }
    guard(() => top.rejectUnknown(const {'version', 'unlocks', 'equipment', 'staff'}));
    return UnlockConfig(
      version: version,
      unlocks: List.unmodifiable(unlocks),
      equipment: List.unmodifiable(equipment),
      staff: List.unmodifiable(staff),
      recipeSecrets: secrets,
    );
  }

  /// `kind` của mục "Bí quyết của bà" (GĐ8) — đọc riêng thành `UnlockConfig.recipeSecrets`, không phải `UnlockKind`.
  static const recipeSecretsKind = 'recipeSecrets';

  static const _secretKeys = {'id', 'chapter', 'level', 'kind', 'tiers', 'name', 'desc'};

  /// Mục `kind: "recipeSecrets"`: chỉ một mục; `tiers` = [{pricePct, costMult}], % tăng dần, hệ số giá tăng dần.
  static RecipeSecretsData _recipeSecrets(Map<String, dynamic> m, int index, RecipeSecretsData? had, List<UnlockData> seen) {
    final id = _id(ConfigReader(m, 'unlocks #${index + 1}'));
    final r = ConfigReader(m, 'mở khoá $id');
    if (had != null) r.fail('kind', 'chỉ được một mục "$recipeSecretsKind" (đã có "${had.id}")');
    if (seen.any((u) => u.id == id)) r.fail('id', 'trùng id');
    final rawTiers = r.list('tiers');
    if (rawTiers.isEmpty) r.fail('tiers', 'rỗng');
    final tiers = <RecipeSecretTier>[];
    for (var i = 0; i < rawTiers.length; i++) {
      final t = ConfigReader(_map(rawTiers[i], 'mở khoá $id, tiers[$i]'), 'mở khoá $id, bậc ${i + 1}');
      final tier = RecipeSecretTier(pricePct: t.integer('pricePct', min: 1), costMult: t.integer('costMult', min: 1));
      if (tiers.isNotEmpty && tier.pricePct <= tiers.last.pricePct) t.fail('pricePct', 'phải tăng dần theo bậc');
      if (tiers.isNotEmpty && tier.costMult <= tiers.last.costMult) t.fail('costMult', 'phải tăng dần theo bậc');
      t.rejectUnknown(const {'pricePct', 'costMult'});
      tiers.add(tier);
    }
    final data = RecipeSecretsData(
      id: id,
      chapter: r.integer('chapter', min: 1),
      level: r.integer('level', min: 1),
      tiers: List.unmodifiable(tiers),
      names: r.title('name'),
      descs: r.title('desc'),
    );
    r.rejectUnknown(_secretKeys);
    return data;
  }

  static const _staffKeys = {'id', 'character', 'role', 'name', 'bio', 'speed', 'skill', 'requires', 'params'};

  /// Một nhân viên: id phải là mục mở khoá `kind: staff` đã đọc; `speed` / `skill` = {"values": [cấp 1..N],
  /// "prices": [giá lên cấp 2..N]}, hai chỉ số cùng N ≥ 1; giá ≥ 1 không giảm.
  static StaffData _staff(
    Object? raw,
    int index,
    List<StaffData> seen,
    List<UnlockData> unlocks,
    bool strict,
    void Function(String) report,
  ) {
    final m = _map(raw, 'staff[$index]');
    final id = _id(ConfigReader(m, 'staff #${index + 1}'));
    final r = ConfigReader(m, 'nhân viên $id');
    if (seen.any((s) => s.id == id)) r.fail('id', 'trùng id');
    final unlock = unlocks.where((u) => u.id == id).firstOrNull;
    if (unlock == null || unlock.kind != UnlockKind.staff) r.fail('id', 'không có mục mở khoá "kind": "staff" cùng id');
    final character = r.string('character');
    if (!_characterPattern.hasMatch(character)) r.fail('character', 'chỉ dùng a-z, 0-9, "_", có "$character"');
    final role = r.enumValue('role', StaffRole.values, what: 'vai trò');

    (List<num>, List<int>) stat(String key) {
      final s = ConfigReader(r.object(key), 'nhân viên $id, $key');
      final rawValues = s.list('values');
      if (rawValues.isEmpty) s.fail('values', 'rỗng');
      final values = <num>[];
      for (var i = 0; i < rawValues.length; i++) {
        final v = rawValues[i];
        if (v is! num || !v.isFinite || v < 0) s.fail('values', 'cấp ${i + 1} phải là số ≥ 0, có $v');
        final needsPositive = key == 'speed' || role == StaffRole.manager;
        if (needsPositive && v <= 0) s.fail('values', 'cấp ${i + 1} phải > 0, có $v');
        if (role == StaffRole.baker && key == 'skill' && (v < 1 || v > 5)) {
          s.fail('values', 'cấp ${i + 1}: sao trung bình phải trong 1..5, có $v');
        }
        values.add(v);
      }
      final rawPrices = s.list('prices');
      if (rawPrices.length != values.length - 1) {
        s.fail('prices', 'cần ${values.length - 1} giá (lên cấp 2..${values.length}), có ${rawPrices.length}');
      }
      final prices = <int>[];
      for (var i = 0; i < rawPrices.length; i++) {
        final v = rawPrices[i];
        if (v is! num || v != v.toInt() || v < 1) s.fail('prices', 'giá lên cấp ${i + 2} phải là số nguyên ≥ 1, có $v');
        if (prices.isNotEmpty && v < prices.last) s.fail('prices', 'giá lên cấp ${i + 2} phải không giảm');
        prices.add(v.toInt());
      }
      s.rejectUnknown(const {'values', 'prices'});
      return (List.unmodifiable(values), List.unmodifiable(prices));
    }

    final (speedValues, speedPrices) = stat('speed');
    final (skillValues, skillPrices) = stat('skill');
    if (skillValues.length != speedValues.length) {
      r.fail('skill', 'phải cùng số cấp với speed (${speedValues.length}), có ${skillValues.length}');
    }
    String? requires;
    if (r.has('requires')) {
      requires = r.string('requires');
      if (!unlocks.any((u) => u.id == requires)) r.fail('requires', 'mục mở khoá "$requires" không tồn tại');
    }
    final params = <String, num>{};
    if (r.has('params')) {
      final p = ConfigReader(r.object('params'), 'nhân viên $id, params');
      for (final k in p.json.keys) {
        if (k.startsWith('_')) continue;
        if (!StaffParams.all.contains(k)) {
          if (strict) p.fail(k, 'tham số lạ (gõ sai tên?)');
          report('nhân viên $id, params: bỏ tham số lạ "$k"');
          continue;
        }
        params[k] = p.number(k, min: 0);
      }
    }
    final data = StaffData(
      id: id,
      character: character,
      role: role,
      names: r.title('name'),
      bios: r.title('bio'),
      speedValues: speedValues,
      skillValues: skillValues,
      speedPrices: speedPrices,
      skillPrices: skillPrices,
      requires: requires,
      params: Map.unmodifiable(params),
    );
    r.rejectUnknown(_staffKeys);
    return data;
  }

  static const _unlockKeys = {'id', 'chapter', 'level', 'kind', 'price', 'gemPrice', 'effect', 'art', 'name', 'desc'};

  static UnlockData _unlock(
    Object? raw,
    int index,
    List<UnlockData> seen,
    bool strict,
    void Function(String) report,
  ) {
    final m = _map(raw, 'unlocks[$index]');
    final id = _id(ConfigReader(m, 'unlocks #${index + 1}'));
    final r = ConfigReader(m, 'mở khoá $id');
    if (seen.any((u) => u.id == id)) r.fail('id', 'trùng id');
    final kind = r.enumValue('kind', UnlockKind.values, what: 'loại');
    final effect = <String, num>{};
    if (r.has('effect')) {
      final e = ConfigReader(r.object('effect'), 'mở khoá $id, effect');
      for (final k in e.json.keys) {
        if (k.startsWith('_')) continue;
        if (!UnlockEffects.all.contains(k)) {
          if (strict) e.fail(k, 'hiệu ứng lạ (gõ sai tên?)');
          report('mở khoá $id, effect: bỏ hiệu ứng lạ "$k"');
          continue;
        }
        final v = e.number(k);
        if (k == UnlockEffects.patienceMult && v <= 0) e.fail(k, 'phải > 0, có $v');
        if (k == UnlockEffects.spawnRatePct && v <= -100) e.fail(k, 'phải > -100, có $v');
        if (k != UnlockEffects.patienceMult && k != UnlockEffects.spawnRatePct && v != v.roundToDouble()) {
          e.fail(k, 'phải là số nguyên, có $v');
        }
        effect[k] = k == UnlockEffects.patienceMult ? v : v.round();
      }
    }
    final data = UnlockData(
      id: id,
      chapter: r.integer('chapter', min: 1),
      level: r.integer('level', min: 1),
      kind: kind,
      price: r.integer('price', min: 0),
      gemPrice: r.has('gemPrice') ? r.integer('gemPrice', min: 0) : 0,
      effect: Map.unmodifiable(effect),
      art: _art(r),
      names: r.title('name'),
      descs: r.title('desc'),
    );
    r.rejectUnknown(_unlockKeys);
    return data;
  }

  static const _equipmentKeys = {'id', 'art', 'name', 'desc', 'tiers'};

  static EquipmentData _equipment(
    Object? raw,
    int index,
    List<EquipmentData> seen,
    bool strict,
    void Function(String) report,
  ) {
    final m = _map(raw, 'equipment[$index]');
    final id = _id(ConfigReader(m, 'equipment #${index + 1}'));
    final r = ConfigReader(m, 'thiết bị $id');
    if (seen.any((e) => e.id == id)) r.fail('id', 'trùng id');
    if (!EquipmentIds.known.contains(id)) {
      if (strict) r.fail('id', 'thiết bị lạ (code chưa có hiệu ứng)');
      report('thiết bị $id: code chưa có hiệu ứng, chỉ hiển thị');
    }
    final rawTiers = r.list('tiers');
    if (rawTiers.isEmpty) r.fail('tiers', 'rỗng');
    final tiers = <EquipmentTier>[];
    for (var i = 0; i < rawTiers.length; i++) {
      final t = ConfigReader(_map(rawTiers[i], 'thiết bị $id, tiers[$i]'), 'thiết bị $id, cấp ${i + 1}');
      final tier = EquipmentTier(
        level: t.integer('level', min: 0),
        price: t.integer('price', min: 0),
        value: t.number('value'),
      );
      if (i == 0 && (tier.level != 0 || tier.price != 0)) t.fail('level', 'cấp 1 có sẵn: level 0, price 0');
      if (i > 0) {
        if (tier.level < 1) t.fail('level', 'phải ≥ 1');
        if (tier.price < 1) t.fail('price', 'phải ≥ 1');
        if (tier.level < tiers.last.level) t.fail('level', 'phải không giảm theo cấp');
      }
      t.rejectUnknown(const {'level', 'price', 'value'});
      tiers.add(tier);
    }
    final data = EquipmentData(
      id: id,
      art: _art(r),
      names: r.title('name'),
      descs: r.title('desc'),
      tiers: List.unmodifiable(tiers),
    );
    r.rejectUnknown(_equipmentKeys);
    return data;
  }

  static String _id(ConfigReader r) {
    final id = r.string('id');
    if (!_idPattern.hasMatch(id)) r.fail('id', 'chỉ dùng A-Z, a-z, 0-9, "_", có "$id"');
    return id;
  }

  static String _art(ConfigReader r) {
    final v = r.json['art'];
    if (v == null || v == '') return '';
    if (v is! String || !_artPattern.hasMatch(v)) r.fail('art', 'phải là "nhóm/tên" (vd. "level/case_stand") hoặc ""');
    return v;
  }

  static Map<String, dynamic> _map(Object? v, String field) {
    if (v is Map<String, dynamic>) return v;
    throw FormatException('unlocks.json: "$field" phải là object');
  }
}
