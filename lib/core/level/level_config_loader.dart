import 'dart:convert';
import 'dart:ui' show Offset;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show AssetBundle;

import '../config_reader.dart';
import '../models/ids.dart';
import 'level_data.dart';

/// Đọc + kiểm tra `assets/config/levels.json`. Lỗi → [FormatException] ghi rõ level id + trường.
///
/// Chế độ chặt (mặc định ở bản debug, `kDebugMode`): lỗi đầu tiên → ném. Chế độ khoan dung (bản phát hành): bỏ chương /
/// level hỏng (ghi `debugPrint` lý do), `defaults` hỏng → giá trị mặc định của code; chỉ ném khi không còn level nào.
abstract final class LevelConfigLoader {
  static const assetPath = 'assets/config/levels.json';

  static const maxMenu = 4;

  /// `mapPos.y` nhỏ nhất (chừa thanh trên của bản đồ).
  static const minMapY = 0.14;

  /// [strict] null → theo `kDebugMode`.
  static Future<LevelConfig> load(AssetBundle bundle, {bool? strict}) async =>
      parse(await bundle.loadString(assetPath), strict: strict);

  /// Như [load] nhưng không bao giờ ném: thiếu asset / JSON hỏng / không còn level → `debugPrint` + [LevelConfig.empty]
  /// (app vẫn khởi động, chỉ ẩn màn chơi). Dùng ở main.dart.
  static Future<LevelConfig> loadOrEmpty(AssetBundle bundle, {bool? strict}) async {
    try {
      return await load(bundle, strict: strict);
    } catch (e) {
      debugPrint('LevelConfigLoader: không nạp được $assetPath, tắt màn chơi ($e)');
      return LevelConfig.empty();
    }
  }

  /// [strict] null → theo `kDebugMode`; [onSkip] nhận lý do mỗi phần bị bỏ ở chế độ khoan dung (mặc định debugPrint).
  static LevelConfig parse(String json, {bool? strict, void Function(String reason)? onSkip}) {
    final isStrict = strict ?? kDebugMode;
    final report = onSkip ?? (String reason) => debugPrint('LevelConfigLoader: bỏ qua — $reason');

    /// Chặt: ném; khoan dung: ghi lý do, trả null.
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
      throw FormatException('levels.json: JSON không hợp lệ (${e.message})');
    }
    final top = ConfigReader(_map(root, 'levels.json', 'gốc'), 'levels.json');
    final version = guard(() => top.integer('version', min: 1)) ?? 1;
    final defaults = guard(() => _defaults(top.object('defaults'))) ?? const LevelDefaults();

    final chapters = <ChapterData>[];
    final chapterIds = <int>{};
    final rawChapters = guard(() {
          final list = top.list('chapters');
          if (list.isEmpty) throw const FormatException('levels.json: "chapters" rỗng');
          return list;
        }) ??
        const <dynamic>[];
    for (var i = 0; i < rawChapters.length; i++) {
      final chapter = guard(() {
        final r = ConfigReader(_map(rawChapters[i], 'levels.json', 'chapters[$i]'), 'chương #${i + 1}');
        final id = r.integer('id', min: 1);
        final c = ConfigReader(r.json, 'chương $id');
        if (chapterIds.contains(id)) c.fail('id', 'trùng id chương');
        String? mapArt;
        if (c.has('mapArt')) {
          mapArt = c.string('mapArt');
          if (!RegExp(r'^[a-z0-9_]+$').hasMatch(mapArt)) c.fail('mapArt', 'chỉ dùng a-z, 0-9, "_" (tên file ảnh)');
        }
        final data = ChapterData(
          id: id,
          title: c.title('title'),
          starsToUnlock: c.integer('starsToUnlock', min: 0),
          mapArt: mapArt,
        );
        c.rejectUnknown(const {'id', 'title', 'starsToUnlock', 'mapArt'});
        return data;
      });
      if (chapter == null) continue;
      chapterIds.add(chapter.id);
      chapters.add(chapter);
    }

    final levels = <LevelData>[];
    final noMapPos = <int>{};
    final seenRecipes = <RecipeId>{};
    final rawLevels = guard(() => top.list('levels')) ?? const <dynamic>[];
    for (var i = 0; i < rawLevels.length; i++) {
      final level = guard(() {
        final m = _map(rawLevels[i], 'levels.json', 'levels[$i]');
        final id = ConfigReader(m, 'level #${i + 1}').integer('id', min: 1);
        final r = ConfigReader(m, 'level $id');
        if (levels.any((l) => l.id == id)) r.fail('id', 'trùng id level');
        if (levels.isNotEmpty && id <= levels.last.id) r.fail('id', 'level phải xếp theo id tăng dần');
        final data = _level(r, id, chapterIds, seenRecipes, strict: isStrict, report: report);
        if (!r.has('mapPos')) {
          if (isStrict) r.fail('mapPos', 'thiếu');
          report('level $id: trường "mapPos": thiếu, tự rải nút');
          noMapPos.add(id);
          return data;
        }
        // Khoan dung: `mapPos` sai dạng / sai miền coi như thiếu (giữ level, rải lại nút).
        try {
          return data.withMapPos(_mapPos(r));
        } on FormatException catch (e) {
          if (isStrict) rethrow;
          report('${e.message}, tự rải nút');
          noMapPos.add(id);
          return data;
        }
      });
      if (level == null) continue;
      seenRecipes.addAll(level.menu);
      levels.add(level);
    }
    if (levels.isEmpty) throw const FormatException('levels.json: không có level hợp lệ nào');
    if (noMapPos.isNotEmpty) _spreadMapPos(levels, noMapPos);
    guard(() => top.rejectUnknown(const {'version', 'defaults', 'chapters', 'levels'}));
    return LevelConfig(
      version: version,
      defaults: defaults,
      chapters: List.unmodifiable(chapters),
      levels: List.unmodifiable(levels),
    );
  }

  /// Chế độ khoan dung: level thiếu `mapPos` được rải đều theo thứ tự trong chương (x 0.08 → 0.92, y so le
  /// 0.74 / 0.48) — nút không chồng nhau, đường đi vẫn đi lên dần từ trái sang phải.
  static void _spreadMapPos(List<LevelData> levels, Set<int> ids) {
    final byChapter = <int, List<int>>{};
    for (var i = 0; i < levels.length; i++) {
      byChapter.putIfAbsent(levels[i].chapter, () => []).add(i);
    }
    for (final indices in byChapter.values) {
      final n = indices.length;
      for (var k = 0; k < n; k++) {
        final i = indices[k];
        if (!ids.contains(levels[i].id)) continue;
        final x = n == 1 ? 0.5 : 0.08 + 0.84 * k / (n - 1);
        levels[i] = levels[i].withMapPos(Offset(x, k.isEven ? 0.74 : 0.48));
      }
    }
  }

  static LevelDefaults _defaults(Map<String, dynamic> m) {
    final r = ConfigReader(m, 'defaults');
    final values = _tuning(r, required: true);
    r.rejectUnknown(LevelDefaults.keys.toSet());
    return const LevelDefaults().overriddenBy(values);
  }

  /// Đọc các trường thông số (`LevelDefaults.keys`); [required] → thiếu là lỗi.
  static Map<String, num> _tuning(ConfigReader r, {required bool required}) {
    final values = <String, num>{};
    for (final k in LevelDefaults.keys) {
      // Level: chỉ đọc trường có ghi; defaults: thiếu là lỗi, trừ vài trường có mặc định trong code.
      if (!r.has(k) && (!required || _optionalDefaults.contains(k))) continue;
      final isInt = LevelDefaults.intKeys.contains(k);
      final min = k == 'jitterPct' ? 0.0 : (isInt ? 1.0 : 0.001);
      values[k] = isInt ? r.integer(k, min: min.toInt()) : r.number(k, min: min);
    }
    if (values.containsKey('jitterPct') && values['jitterPct']! > 90) r.fail('jitterPct', 'phải ≤ 90');
    return values;
  }

  static const _optionalDefaults = {'ovens', 'counterSpots', 'patienceMult'};

  static const _levelKeys = {
    'id',
    'chapter',
    'title',
    'durationSec',
    'goal',
    'stars',
    'menu',
    'caseSlots',
    'startStock',
    'patienceSec',
    'spawn',
    'flexibleChance',
    'specials',
    'introScene',
    'outroScene',
    'special',
    'mapPos',
    'tutorial',
  };

  static LevelData _level(
    ConfigReader r,
    int id,
    Set<int> chapterIds,
    Set<RecipeId> seenRecipes, {
    required bool strict,
    required void Function(String reason) report,
  }) {
    final chapter = r.integer('chapter', min: 1);
    if (!chapterIds.contains(chapter)) r.fail('chapter', 'chương $chapter không tồn tại');
    final title = r.title('title');
    final duration = r.integer('durationSec', min: 10);

    final g = ConfigReader(r.object('goal'), 'level $id, goal');
    final type = g.enumValue('type', GoalType.values);
    g.rejectUnknown(const {'type', 'target'}); // `target` (nếu có) bỏ qua: mốc thắng = stars[0]
    final rawStars = r.list('stars');
    if (rawStars.length != 3) r.fail('stars', 'cần đúng 3 mốc, có ${rawStars.length}');
    final stars = <int>[];
    for (var i = 0; i < 3; i++) {
      final v = rawStars[i];
      if (v is! num || v != v.toInt()) r.fail('stars', 'mốc ${i + 1} không phải số nguyên: $v');
      final n = v.toInt();
      if (n < 1) r.fail('stars', 'mốc ${i + 1} phải ≥ 1');
      if (stars.isNotEmpty && n <= stars.last) r.fail('stars', 'mốc sao phải tăng dần: $rawStars');
      stars.add(n);
    }

    final rawMenu = r.list('menu');
    if (rawMenu.isEmpty) r.fail('menu', 'rỗng');
    if (rawMenu.length > maxMenu) r.fail('menu', 'tối đa $maxMenu món, có ${rawMenu.length}');
    final menu = <RecipeId>[];
    for (final name in rawMenu) {
      final recipe = enumByName(RecipeId.values, name) ?? r.fail('menu', 'món "$name" không tồn tại');
      if (menu.contains(recipe)) r.fail('menu', 'món "$name" bị lặp');
      menu.add(recipe);
    }
    RecipeId? newRecipe;
    for (final m in menu) {
      if (!seenRecipes.contains(m)) {
        newRecipe = m;
        break;
      }
    }

    final caseSlots = r.integer('caseSlots', min: 1);
    if (caseSlots > 8) r.fail('caseSlots', 'tối đa 8');
    final startStock = r.has('startStock') ? r.integer('startStock', min: 0) : 0;
    final patience = r.number('patienceSec', min: 1);

    final s = ConfigReader(r.object('spawn'), 'level $id, spawn');
    final spawn = SpawnCurve(
      startEverySec: s.number('startEverySec', min: 0.5),
      endEverySec: s.number('endEverySec', min: 0.5),
      rushAtPct: s.number('rushAtPct', min: 0),
      rushEverySec: s.number('rushEverySec', min: 0.5),
    );
    if (spawn.rushAtPct > 100) s.fail('rushAtPct', 'phải trong 0..100');
    s.rejectUnknown(const {'startEverySec', 'endEverySec', 'rushAtPct', 'rushEverySec'});

    final flexible = r.has('flexibleChance') ? r.number('flexibleChance', min: 0) : 0.0;
    if (flexible > 1) r.fail('flexibleChance', 'phải trong 0..1');

    final specials = <SpecialVisit>[];
    final rawSpecials = r.has('specials') ? r.list('specials') : const <dynamic>[];
    for (var i = 0; i < rawSpecials.length; i++) {
      final v = ConfigReader(_map(rawSpecials[i], 'level $id', 'specials[$i]'), 'level $id, specials[$i]');
      final at = v.number('atSec', min: 0);
      if (at >= duration) v.fail('atSec', 'phải nhỏ hơn durationSec ($duration)');
      specials.add(SpecialVisit(
        atSec: at,
        who: v.enumValue('who', SpecialWho.values),
        recipe: v.enumValue('recipe', RecipeId.values, what: 'món'),
        scene: v.optionalEnum('scene', StorySceneId.values, what: 'cảnh'),
        afterServed: v.has('afterServed') ? v.integer('afterServed', min: 0) : 0,
        look: v.has('look') ? v.string('look') : null,
        bySec: v.has('bySec') ? v.number('bySec', min: at) : null,
        box: v.optionalEnum('box', BoxType.values, what: 'hộp'),
      ));
      final visit = specials.last;
      if (visit.look != null) {
        if (visit.who != SpecialWho.vip) v.fail('look', 'chỉ dùng cho who = "vip"');
        if (visit.vipLookIndex == null) {
          v.fail('look', 'ảnh "${visit.look}" không tồn tại (vip_00..vip_0${SpecialVisit.vipLooks - 1})');
        }
      }
      if (visit.bySec != null && visit.bySec! > duration) v.fail('bySec', 'phải ≤ durationSec ($duration)');
      v.rejectUnknown(const {'atSec', 'who', 'recipe', 'scene', 'afterServed', 'look', 'bySec', 'box'});
    }
    specials.sort((a, b) => a.atSec != b.atSec ? a.atSec.compareTo(b.atSec) : a.afterServed.compareTo(b.afterServed));
    if (type == GoalType.specialOrders && stars.last > specials.length) {
      r.fail('stars', 'mục tiêu đơn đặc biệt ${stars.last} nhưng chỉ có ${specials.length} khách đặc biệt');
    }

    final isSpecial = r.has('special') ? r.boolean('special') : false;
    String? tutorial;
    if (r.has('tutorial')) {
      final t = r.json['tutorial'];
      if (t is String && TutorialIds.all.contains(t)) {
        tutorial = t;
      } else {
        // Id lạ: chặt → ném; khoan dung → giữ level, bỏ hướng dẫn.
        final reason = 'kịch bản hướng dẫn "$t" không tồn tại (${TutorialIds.all.join(', ')})';
        if (strict) r.fail('tutorial', reason);
        report('${r.where}: trường "tutorial": $reason, bỏ hướng dẫn');
      }
    }
    final overrides = _tuning(r, required: false);
    r.rejectUnknown({..._levelKeys, ...LevelDefaults.keys});

    return LevelData(
      id: id,
      chapter: chapter,
      title: title,
      durationSec: duration,
      goal: LevelGoal(type: type, stars: List.unmodifiable(stars)),
      menu: List.unmodifiable(menu),
      caseSlots: caseSlots,
      startStock: startStock,
      patienceSec: patience,
      spawn: spawn,
      flexibleChance: flexible,
      specials: List.unmodifiable(specials),
      introScene: r.optionalEnum('introScene', StorySceneId.values, what: 'cảnh'),
      outroScene: r.optionalEnum('outroScene', StorySceneId.values, what: 'cảnh'),
      isSpecial: isSpecial,
      newRecipe: newRecipe,
      overrides: Map.unmodifiable(overrides),
      mapPos: Offset.zero, // đọc riêng ở [_mapPos] (khoan dung: sai thì rải lại, không bỏ level)
      tutorial: tutorial,
    );
  }

  /// `mapPos` = [x, y]: x trong 0..1, y trong [minMapY]..1.
  static Offset _mapPos(ConfigReader r) {
    final raw = r.list('mapPos');
    if (raw.length != 2 || raw.any((v) => v is! num)) r.fail('mapPos', 'cần [x, y] là số, có $raw');
    final x = (raw[0] as num).toDouble(), y = (raw[1] as num).toDouble();
    if (x < 0 || x > 1) r.fail('mapPos', 'x phải trong 0..1, có $x');
    if (y < minMapY || y > 1) r.fail('mapPos', 'y phải trong $minMapY..1 (chừa thanh trên), có $y');
    return Offset(x, y);
  }

  static Map<String, dynamic> _map(Object? v, String where, String field) {
    if (v is Map<String, dynamic>) return v;
    throw FormatException('$where: "$field" phải là object');
  }
}
