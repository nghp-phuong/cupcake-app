import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sugarleaf_bakery/core/catalog.dart';
import 'package:sugarleaf_bakery/core/level/level.dart';
import 'package:sugarleaf_bakery/core/models/ids.dart';

String _asset() => File(LevelConfigLoader.assetPath).readAsStringSync();

/// Sửa bản JSON thật rồi parse; trả thông điệp lỗi.
String _errorAfter(void Function(Map<String, dynamic> json) mutate) {
  final json = jsonDecode(_asset()) as Map<String, dynamic>;
  mutate(json);
  try {
    LevelConfigLoader.parse(jsonEncode(json));
  } on FormatException catch (e) {
    return e.message;
  }
  fail('parse phải ném FormatException');
}

Map<String, dynamic> _level(Map<String, dynamic> json, int id) =>
    (json['levels'] as List).cast<Map<String, dynamic>>().firstWhere((l) => l['id'] == id);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('levels.json thật', () {
    late LevelConfig config;
    setUpAll(() => config = LevelConfigLoader.parse(_asset()));

    test('đủ chương 1–5 và 50 level đúng bảng', () {
      expect(config.version, 1);
      expect(config.chapters.map((c) => c.id), [1, 2, 3, 4, 5]);
      expect(config.chapter(1)!.titleFor('vi'), 'Căn bếp của bà');
      expect(config.chapter(1)!.starsToUnlock, 0);
      expect(config.chapter(1)!.mapArt, 'chapter_1');
      expect(config.chapter(1)!.mapAssetPath, 'assets/art/map/chapter_1.webp');
      expect([for (final l in config.levels) l.id], [for (var i = 1; i <= 50; i++) i]);
      expect([for (final l in config.levelsInChapter(1)) l.id], [for (var i = 1; i <= 10; i++) i]);
      expect([for (final l in config.levelsInChapter(2)) l.id], [for (var i = 11; i <= 20; i++) i]);
      for (final l in config.levels) {
        expect(l.menu.length, inInclusiveRange(1, LevelConfigLoader.maxMenu));
        expect(l.titleFor('en'), isNotEmpty);
        expect(l.titleFor('vi'), isNotEmpty);
        expect(l.goal.stars, hasLength(3));
        expect(l.goal.stars[0] < l.goal.stars[1] && l.goal.stars[1] < l.goal.stars[2], isTrue);
      }
      expect(config.defaults.ovenSec, 7);
      expect(config.defaults.batchSize, 3);
      expect(config.defaults.slotCapacity, 6);
      expect(config.defaults.specialRewardMult, 2.0);

      final l1 = config.level(1);
      expect(l1.durationSec, 120);
      expect(l1.goal.type, GoalType.customers);
      expect(l1.menu, [RecipeId.cupcakeVanilla]);
      expect(l1.introScene, StorySceneId.prologue);
      expect(l1.specials, isEmpty);
      expect(l1.newRecipe, RecipeId.cupcakeVanilla);

      expect(config.level(2).specials.single.scene, StorySceneId.hoa1);
      expect(config.level(2).newRecipe, RecipeId.cupcakeChocolate);
      expect(config.level(3).goal.type, GoalType.coins);
      expect(config.level(5).caseSlots, 4);
      expect(config.level(8).newRecipe, isNull, reason: 'L8: 4 món xoay vòng, không có món mới');
      expect(config.level(9).newRecipe, RecipeId.matchaCake);

      final l10 = config.level(10);
      expect(l10.isSpecial, isTrue);
      expect(l10.goal.type, GoalType.specialOrders);
      expect(l10.goal.stars, [2, 3, 4]);
      // GĐ8: L10 kết bằng `ch1End`; lời kết cũ chuyển sang `ch2End` (L20); `finale` sau L50.
      expect(l10.outroScene, StorySceneId.ch1End);
      expect(l10.newRecipe, RecipeId.cheesecake);
      expect(
        [for (final s in l10.specials) s.who],
        [SpecialWho.kenji, SpecialWho.hoa, SpecialWho.linh, SpecialWho.vip],
      );
      expect(l10.specials.first.scene, StorySceneId.kenji3);
      expect(l10.specials.first.afterServed, 0);
      expect(l10.specials.last.look, 'vip_01', reason: 'vip_00 (bà Rosa) dành cho màn sau');
      expect(l10.specials.last.vipLookIndex, 1);
      // Khách quen sau chỉ tới khi tiệm đã đông khách (tăng dần).
      final gates = [for (final s in l10.specials.skip(1)) s.afterServed];
      expect(gates.first, greaterThan(0));
      expect(gates, orderedEquals([...gates]..sort()));
      for (final s in l10.specials.skip(1)) {
        expect(s.bySec, isNotNull);
        expect(s.bySec!, lessThanOrEqualTo(l10.durationSec));
      }
      expect(config.level(1).goal.stars, [6, 8, 10]);
      expect(config.next(10)!.id, 11);
      expect(config.next(20)!.id, 21);
      expect(config.next(50), isNull);
      expect(config.next(3)!.id, 4);
      expect(() => config.level(99), throwsArgumentError);
    });

    test('chương 2 "Tiệm đông khách": mở bằng ~16 sao, thêm bánh sinh nhật, L20 ★ Giờ cao điểm', () {
      final c2 = config.chapter(2)!;
      expect(c2.titleFor('en'), 'The Busy Bakery');
      expect(c2.titleFor('vi'), 'Tiệm đông khách');
      expect(c2.mapArt, 'chapter_2');
      // GĐ7: 20 → 16 — ~87% người chơi `average` đủ sao ngay khi qua L10 lần đầu (20★ chỉ 3%; 17★ là 57%).
      expect(c2.starsToUnlock, 16, reason: 'docs/v2/phase7-balance.md');
      expect(config.previousChapter(2)!.id, 1);
      expect(config.previousChapter(1), isNull);
      final ch2 = config.levelsInChapter(2);
      expect(config.firstLevelWithRecipe(RecipeId.birthdayCake)!.id, 12);
      expect(config.level(12).newRecipe, RecipeId.birthdayCake);
      expect(config.firstLevelWithRecipe(RecipeId.cupcakeVanilla)!.id, 1);
      for (final l in ch2) {
        expect(l.menu.length, LevelConfigLoader.maxMenu, reason: 'L${l.id}');
        expect(l.specials, isNotEmpty, reason: 'L${l.id}: khách quen/VIP ghé');
        expect(l.specials.every((s) => s.scene == null), isTrue, reason: 'L${l.id}: chương 2 chưa có cảnh truyện');
        expect(l.introScene, isNull);
        expect(l.outroScene, l.id == 20 ? StorySceneId.ch2End : null);
        expect(l.isSpecial, l.id == 20);
      }
      // Độ khó: kiên nhẫn không cao hơn level trước, thời lượng không giảm; dài hơn chương 1.
      for (var i = 1; i < ch2.length; i++) {
        expect(ch2[i].patienceSec, lessThanOrEqualTo(ch2[i - 1].patienceSec), reason: 'L${ch2[i].id}');
        expect(ch2[i].durationSec, greaterThanOrEqualTo(ch2[i - 1].durationSec), reason: 'L${ch2[i].id}');
      }
      expect(ch2.first.patienceSec, lessThanOrEqualTo(config.level(10).patienceSec));
      expect(ch2.first.durationSec, lessThan(ch2.last.durationSec));
      final l20 = config.level(20);
      expect(l20.titleFor('en'), 'Rush Hour');
      expect(l20.goal.type, GoalType.coins);
      expect(l20.durationSec, greaterThan(config.level(19).durationSec));
      // Giờ cao điểm dài hơn hẳn mọi level khác.
      for (final l in config.levels) {
        if (l.id != 20) expect(l20.spawn.rushAtPct, lessThan(l.spawn.rushAtPct - 15), reason: 'L${l.id}');
      }
    });

    test('chương 3–5 (GĐ8): món mới mở đúng màn kèm đơn giới thiệu, cảnh truyện đúng màn, bà Rosa ở L33 / L50', () {
      for (final (id, stars, art) in const [(3, 28, 'chapter_3'), (4, 40, 'chapter_4'), (5, 53, 'chapter_5')]) {
        expect(config.chapter(id)!.starsToUnlock, stars);
        expect(config.chapter(id)!.mapArt, art);
        expect([for (final l in config.levelsInChapter(id)) l.id], [for (var i = 1; i <= 10; i++) (id - 1) * 10 + i]);
      }
      for (final r in Catalog.recipes.skip(10)) {
        final first = config.firstLevelWithRecipe(r.id)!;
        expect(first.id, r.unlockLevel, reason: r.id.name);
        expect(first.newRecipe, r.id, reason: r.id.name);
        expect(first.specials.any((s) => s.recipe == r.id), isTrue, reason: '${r.id.name}: đơn đặc biệt giới thiệu');
      }
      for (final l in config.levels.where((l) => l.id > 20)) {
        expect(l.menu, hasLength(LevelConfigLoader.maxMenu), reason: 'L${l.id}');
        expect(l.titleFor('en'), isNot(contains('Draft')), reason: 'L${l.id}');
        expect(l.titleFor('vi'), isNotEmpty, reason: 'L${l.id}');
        for (final r in l.menu) {
          expect(Catalog.recipe(r).unlockLevel, lessThanOrEqualTo(l.id), reason: 'L${l.id}: ${r.name}');
        }
        expect(l.menu.any((r) => Catalog.recipe(r).unlockLevel > 20), isTrue, reason: 'L${l.id}: có món chương 3–5');
      }
      expect({for (final id in [21, 23, 31, 41]) id: config.level(id).introScene}, {
        21: StorySceneId.ch3Open,
        23: StorySceneId.mochi1,
        31: StorySceneId.ch4Open,
        41: StorySceneId.ch5Open,
      });
      SpecialVisit sceneVisit(int id) => config.level(id).specials.firstWhere((s) => s.scene != null);
      expect(sceneVisit(27).scene, StorySceneId.kenji4);
      expect(sceneVisit(37).scene, StorySceneId.linh4);
      expect(sceneVisit(46).scene, StorySceneId.hoa4);
      for (final (id, scene) in const [(33, StorySceneId.rosa1), (50, StorySceneId.rosa2)]) {
        final v = sceneVisit(id);
        expect(v.scene, scene);
        expect((v.who, v.look, v.vipLookIndex), (SpecialWho.vip, 'vip_00', SpecialVisit.reservedVipLook), reason: 'L$id: bà Rosa');
      }
      // Màn 50: bánh cưới = bánh sinh nhật nhiều tầng; khách VIP luôn đòi hộp quà.
      expect(sceneVisit(50).recipe, RecipeId.birthdayCake);
      // vip_00 (bà Rosa) chỉ ở hai màn của bà.
      expect([
        for (final l in config.levels)
          for (final s in l.specials)
            if (s.look == 'vip_00') l.id,
      ], [33, 50]);
      expect(config.level(20).outroScene, StorySceneId.ch2End);
      expect(config.level(50).outroScene, StorySceneId.finale);
      expect(config.level(50).isSpecial, isTrue);
    });

    test('mapPos: trong khung, chừa thanh trên, nút không chồng nhau, level ★ ở cuối chương', () {
      for (final c in config.chapters) {
        final levels = config.levelsInChapter(c.id);
        for (final l in levels) {
          expect(l.mapPos.dx, inInclusiveRange(0.04, 0.96), reason: 'L${l.id}');
          expect(l.mapPos.dy, inInclusiveRange(0.18, 0.96), reason: 'L${l.id}');
        }
        // Khoảng cách theo chiều ngang khung 1280×720 (dy quy về đơn vị chiều ngang).
        for (var i = 0; i < levels.length; i++) {
          for (var j = i + 1; j < levels.length; j++) {
            final a = levels[i].mapPos, b = levels[j].mapPos;
            final dx = a.dx - b.dx, dy = (a.dy - b.dy) * 720 / 1280;
            expect(dx * dx + dy * dy, greaterThanOrEqualTo(0.09 * 0.09), reason: 'L${levels[i].id}–L${levels[j].id}');
          }
        }
        expect(levels.last.isSpecial, isTrue, reason: 'chương ${c.id}');
        expect(levels.where((l) => l.isSpecial), hasLength(1));
      }
      expect(config.level(1).mapPos.dy, greaterThan(config.level(10).mapPos.dy), reason: 'đi từ dưới lên');
    });

    test('mỗi cảnh truyện xuất hiện đúng một lần (chương 1–5)', () {
      final scenes = <StorySceneId>[
        for (final l in config.levels) ...[
          if (l.introScene != null) l.introScene!,
          for (final s in l.specials)
            if (s.scene != null) s.scene!,
          if (l.outroScene != null) l.outroScene!,
        ],
      ];
      expect(scenes.toSet(), StorySceneId.values.toSet());
      expect(scenes.length, StorySceneId.values.length);
    });

    test('nạp qua AssetBundle (rootBundle) giống parse', () async {
      final loaded = await LevelConfigLoader.load(rootBundle);
      expect(loaded.levels.length, config.levels.length);
    });
  });

  group('lỗi parse ghi rõ level + trường', () {
    test('món không tồn tại', () {
      final msg = _errorAfter((j) => (_level(j, 2)['menu'] as List).add('donut'));
      expect(msg, allOf(contains('level 2'), contains('"menu"'), contains('donut')));
    });

    test('cảnh không tồn tại', () {
      final msg = _errorAfter((j) => ((_level(j, 4)['specials'] as List).first as Map)['scene'] = 'epilogue');
      expect(msg, allOf(contains('level 4'), contains('"scene"'), contains('epilogue')));
      final intro = _errorAfter((j) => _level(j, 1)['introScene'] = 'opening');
      expect(intro, allOf(contains('level 1'), contains('"introScene"')));
    });

    test('mốc sao không tăng dần / sai số lượng', () {
      expect(_errorAfter((j) => _level(j, 3)['stars'] = [500, 400, 600]),
          allOf(contains('level 3'), contains('"stars"'), contains('tăng dần')));
      expect(_errorAfter((j) => _level(j, 5)['stars'] = [1, 2]), allOf(contains('level 5'), contains('"stars"')));
    });

    test('thiếu trường', () {
      expect(_errorAfter((j) => _level(j, 6).remove('patienceSec')),
          allOf(contains('level 6'), contains('"patienceSec"'), contains('thiếu')));
      expect(_errorAfter((j) => (_level(j, 7)['spawn'] as Map).remove('rushEverySec')),
          allOf(contains('level 7'), contains('"rushEverySec"'), contains('thiếu')));
      expect(_errorAfter((j) => (_level(j, 2)['title'] as Map).remove('vi')),
          allOf(contains('level 2'), contains('"title"')));
      expect(_errorAfter((j) => (j['defaults'] as Map).remove('ovenSec')),
          allOf(contains('defaults'), contains('"ovenSec"')));
    });

    test('sai kiểu, trường lạ, mục tiêu đặc biệt vượt số khách, chương lạ, trùng id', () {
      expect(_errorAfter((j) => _level(j, 1)['durationSec'] = 'hai phút'), contains('"durationSec"'));
      expect(_errorAfter((j) => _level(j, 1)['patienceSecc'] = 30), contains('"patienceSecc"'));
      expect(_errorAfter((j) => _level(j, 10)['stars'] = [2, 3, 5]), allOf(contains('level 10'), contains('đặc biệt')));
      expect(_errorAfter((j) => ((_level(j, 10)['specials'] as List)[1] as Map)['afterServed'] = -1),
          allOf(contains('level 10'), contains('"afterServed"')));
      expect(_errorAfter((j) => ((_level(j, 10)['specials'] as List)[1] as Map)['bySec'] = 500),
          allOf(contains('level 10'), contains('"bySec"')));
      expect(_errorAfter((j) => ((_level(j, 10)['specials'] as List)[3] as Map)['look'] = 'vip_07'),
          allOf(contains('level 10'), contains('"look"'), contains('vip_07')));
      expect(_errorAfter((j) => ((_level(j, 10)['specials'] as List)[1] as Map)['look'] = 'vip_01'),
          allOf(contains('level 10'), contains('"look"')));
      expect(_errorAfter((j) => _level(j, 3)['chapter'] = 9), allOf(contains('level 3'), contains('"chapter"')));
      expect(_errorAfter((j) => _level(j, 3)['id'] = 2), contains('"id"'));
      expect(_errorAfter((j) => (_level(j, 2)['goal'] as Map)['type'] = 'tips'), contains('"type"'));
      expect(_errorAfter((j) => ((_level(j, 2)['specials'] as List).first as Map)['who'] = 'mai'), contains('"who"'));
      expect(() => LevelConfigLoader.parse('{oops'), throwsFormatException);
    });

    test('mapPos / mapArt', () {
      expect(_errorAfter((j) => _level(j, 4).remove('mapPos')),
          allOf(contains('level 4'), contains('"mapPos"'), contains('thiếu')));
      expect(_errorAfter((j) => _level(j, 4)['mapPos'] = [0.5]), allOf(contains('level 4'), contains('"mapPos"')));
      expect(_errorAfter((j) => _level(j, 4)['mapPos'] = [0.5, 'x']), contains('"mapPos"'));
      expect(_errorAfter((j) => _level(j, 4)['mapPos'] = [1.2, 0.5]), allOf(contains('"mapPos"'), contains('x')));
      expect(_errorAfter((j) => _level(j, 4)['mapPos'] = [0.5, 0.1]), allOf(contains('"mapPos"'), contains('thanh trên')));
      expect(_errorAfter((j) => ((j['chapters'] as List).first as Map)['mapArt'] = 'Chapter 1.webp'),
          allOf(contains('chương 1'), contains('"mapArt"')));
      final json = jsonDecode(_asset()) as Map<String, dynamic>;
      ((json['chapters'] as List)[1] as Map).remove('mapArt');
      expect(LevelConfigLoader.parse(jsonEncode(json)).chapter(2)!.mapArt, 'chapter_2', reason: 'thiếu → chapter_<id>');
    });

    test('level ghi đè defaults', () {
      final json = jsonDecode(_asset()) as Map<String, dynamic>;
      _level(json, 2)['ovenSec'] = 5;
      _level(json, 2)['maxQueue'] = 3;
      final config = LevelConfigLoader.parse(jsonEncode(json));
      final t = config.level(2).tuningWith(config.defaults);
      expect(t.ovenSec, 5);
      expect(t.maxQueue, 3);
      expect(t.batchSize, config.defaults.batchSize);
      expect(config.level(3).tuningWith(config.defaults).ovenSec, 7);
      expect(_errorAfter((j) => _level(j, 2)['batchSize'] = 0), allOf(contains('level 2'), contains('"batchSize"')));
    });
  });

  group('chế độ khoan dung (bản phát hành)', () {
    LevelConfig lenient(void Function(Map<String, dynamic> json) mutate, List<String> skipped) {
      final json = jsonDecode(_asset()) as Map<String, dynamic>;
      mutate(json);
      return LevelConfigLoader.parse(jsonEncode(json), strict: false, onSkip: skipped.add);
    }

    test('bỏ level hỏng, giữ phần còn lại, ghi lý do', () {
      final skipped = <String>[];
      final config = lenient((j) {
        (_level(j, 3)['menu'] as List).add('donut');
        _level(j, 6).remove('patienceSec');
      }, skipped);
      expect([for (final l in config.levels) l.id], [1, 2, 4, 5, for (var i = 7; i <= 50; i++) i]);
      expect(skipped, hasLength(2));
      expect(skipped[0], allOf(contains('level 3'), contains('donut')));
      expect(skipped[1], allOf(contains('level 6'), contains('"patienceSec"')));
      expect(config.next(2)!.id, 4);
      // Chế độ chặt vẫn ném lỗi.
      expect(_errorAfter((j) => (_level(j, 3)['menu'] as List).add('donut')), contains('level 3'));
    });

    test('chương hỏng → bỏ chương và các level của chương; defaults hỏng → mặc định của code', () {
      final skipped = <String>[];
      final config = lenient((j) {
        (j['chapters'] as List).add({
          'id': 6,
          'title': {'en': 'Harbor'},
          'starsToUnlock': 70,
        });
        (j['levels'] as List).add({..._level(j, 1), 'id': 51, 'chapter': 6});
        (j['defaults'] as Map)['ovenSec'] = 'bảy';
      }, skipped);
      expect(config.chapters.map((c) => c.id), [1, 2, 3, 4, 5]);
      expect(config.levels.length, 50);
      expect(config.defaults.ovenSec, const LevelDefaults().ovenSec);
      expect(skipped.any((m) => m.contains('chương 6')), isTrue);
      expect(skipped.any((m) => m.contains('level 51') && m.contains('"chapter"')), isTrue);
      expect(skipped.any((m) => m.contains('defaults')), isTrue);
    });

    test('thiếu mapPos → tự rải đều trong chương (không chồng nhau), ghi lý do', () {
      final skipped = <String>[];
      final config = lenient((j) {
        for (final l in (j['levels'] as List).cast<Map<String, dynamic>>()) {
          if (l['chapter'] == 2) l.remove('mapPos');
        }
      }, skipped);
      expect(config.levels.length, 50);
      expect(skipped.where((m) => m.contains('"mapPos"')), hasLength(10));
      final ch2 = config.levelsInChapter(2);
      for (var i = 0; i < ch2.length; i++) {
        expect(ch2[i].mapPos.dy, greaterThanOrEqualTo(LevelConfigLoader.minMapY));
        if (i > 0) expect(ch2[i].mapPos.dx - ch2[i - 1].mapPos.dx, greaterThanOrEqualTo(0.09));
      }
      expect(config.level(3).mapPos, LevelConfigLoader.parse(_asset()).level(3).mapPos, reason: 'chương 1 giữ nguyên');
    });

    test('mapPos sai dạng / sai miền → coi như thiếu: giữ level, rải lại nút, ghi lý do; chế độ chặt vẫn ném', () {
      final skipped = <String>[];
      final config = lenient((j) {
        _level(j, 4)['mapPos'] = [1.2, 0.5];
        _level(j, 5)['mapPos'] = 'giữa';
        _level(j, 6)['mapPos'] = [0.5];
        _level(j, 7)['mapPos'] = [0.5, 0.05];
      }, skipped);
      expect(config.levels.length, 50);
      expect(skipped, hasLength(4));
      for (final id in [4, 5, 6, 7]) {
        expect(skipped.any((m) => m.contains('level $id') && m.contains('"mapPos"') && m.contains('tự rải')), isTrue,
            reason: 'L$id');
        final pos = config.level(id).mapPos;
        expect(pos.dx, inInclusiveRange(0.0, 1.0), reason: 'L$id');
        expect(pos.dy, inInclusiveRange(LevelConfigLoader.minMapY, 1.0), reason: 'L$id');
      }
      expect(config.level(3).mapPos, LevelConfigLoader.parse(_asset()).level(3).mapPos, reason: 'level khác giữ nguyên');
      expect(_errorAfter((j) => _level(j, 5)['mapPos'] = 'giữa'), allOf(contains('level 5'), contains('"mapPos"')));
    });

    test('không còn level nào → vẫn ném lỗi', () {
      expect(
        () => lenient((j) {
          for (final l in (j['levels'] as List).cast<Map<String, dynamic>>()) {
            l.remove('menu');
          }
        }, <String>[]),
        throwsFormatException,
      );
      expect(() => LevelConfigLoader.parse('{oops', strict: false, onSkip: (_) {}), throwsFormatException);
    });
  });

  group('loadOrEmpty (main.dart): levels.json lỗi không làm app chết', () {
    test('thiếu asset / JSON hỏng / không còn level → LevelConfig rỗng', () async {
      for (final bundle in [
        _FakeBundle(null),
        _FakeBundle('{oops'),
        _FakeBundle('{"version": 1, "defaults": {}, "chapters": [], "levels": []}'),
      ]) {
        for (final strict in [true, false]) {
          final config = await LevelConfigLoader.loadOrEmpty(bundle, strict: strict);
          expect(config.isEmpty, isTrue);
          expect(config.levels, isEmpty);
          expect(config.chapters, isEmpty);
          expect(config.hasLevel(1), isFalse);
          expect(config.next(0), isNull);
        }
      }
    });

    test('file tốt → nạp đủ', () async {
      final config = await LevelConfigLoader.loadOrEmpty(_FakeBundle(_asset()));
      expect(config.levels.length, 50);
      expect(LevelConfig.empty().isEmpty, isTrue);
    });
  });
}

/// AssetBundle giả: [text] null → thiếu asset.
class _FakeBundle extends AssetBundle {
  _FakeBundle(this.text);

  final String? text;

  @override
  Future<ByteData> load(String key) => throw FlutterError('Unable to load asset: "$key".');

  @override
  Future<String> loadString(String key, {bool cache = true}) async =>
      text ?? (throw FlutterError('Unable to load asset: "$key".'));
}
