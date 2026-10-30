import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:sugarleaf_bakery/core/art/art_sprites.dart';
import 'package:sugarleaf_bakery/core/art/customer_art.dart';
import 'package:sugarleaf_bakery/core/catalog.dart';
import 'package:sugarleaf_bakery/core/economy.dart';
import 'package:sugarleaf_bakery/core/game_state.dart';
import 'package:sugarleaf_bakery/core/l10n_lookup.dart';
import 'package:sugarleaf_bakery/core/level/level.dart';
import 'package:sugarleaf_bakery/core/level/level_bot.dart';
import 'package:sugarleaf_bakery/core/models/bake.dart';
import 'package:sugarleaf_bakery/core/models/ids.dart';
import 'package:sugarleaf_bakery/core/sim/progression_sim.dart';
import 'package:sugarleaf_bakery/core/unlock/unlock.dart';
import 'package:sugarleaf_bakery/l10n/gen/app_localizations.dart';

/// GĐ8B (docs/v2/phase8-spec.md §2): cảnh truyện chương 3–5 + `ch2End` / `finale`, nền cảnh mới, Bí quyết của bà.

DateTime _clock() => DateTime(2026, 10, 30, 10);

String _unlocksJson() => File(UnlockConfigLoader.assetPath).readAsStringSync();
final _levels = LevelConfigLoader.parse(File(LevelConfigLoader.assetPath).readAsStringSync(), strict: true);
final _unlocks = UnlockConfigLoader.parse(_unlocksJson(), strict: true);

LevelResult _win(int id) => LevelResult(
      levelId: id,
      won: true,
      stars: 3,
      coins: 0,
      served: 0,
      lost: 0,
      specialsDone: 0,
      bestCombo: 0,
      perfectBakes: 0,
      recipeStars: const {},
      goalValue: 1,
    );

GameState _fresh({int coins = 0, Map<String, dynamic> extra = const {}}) =>
    GameState.fromJson({'v': GameState.saveVersion, 'coins': coins, ...extra}, clock: _clock)
      ..attachLevelConfig(_levels)
      ..attachUnlockConfig(_unlocks);

void _clear(GameState s, int last) {
  for (var id = s.highestCompletedLevel + 1; id <= last; id++) {
    s.applyLevelResult(_win(id));
  }
}

/// Bản lưu đã thắng L1..[last] (3★).
Map<String, dynamic> _progress(int last) => {
      'progress': {
        'levels': {
          for (var id = 1; id <= last; id++) '$id': {'stars': 3, 'best': 1, 'plays': 1, 'firstWin': true},
        },
      },
    };

void main() {
  group('truyện', () {
    test('cảnh GĐ8: thứ tự enum, màn, nền, người nói; 3–5 dòng mỗi cảnh, đọc được ở en/vi', () {
      expect(Catalog.storyScenes.map((s) => s.id).toList(), StorySceneId.values);
      const gd8 = {
        StorySceneId.ch1End: (10, ArtScene.storyGrandmaKitchen),
        StorySceneId.ch2End: (20, ArtScene.storyTown),
        StorySceneId.ch3Open: (21, ArtScene.storyGarden),
        StorySceneId.mochi1: (23, ArtScene.rainyDay),
        StorySceneId.kenji4: (27, ArtScene.storyTown),
        StorySceneId.ch4Open: (31, ArtScene.storyAttic),
        StorySceneId.rosa1: (33, ArtScene.storyTown),
        StorySceneId.linh4: (37, ArtScene.storyTown),
        StorySceneId.ch5Open: (41, ArtScene.storyFestival),
        StorySceneId.hoa4: (46, ArtScene.storyFestival),
        StorySceneId.rosa2: (50, ArtScene.storyFestival),
        StorySceneId.finale: (50, ArtScene.storyTown),
      };
      for (final MapEntry(key: id, value: (level, backdrop)) in gd8.entries) {
        final scene = Catalog.storyScene(id);
        expect(scene.minLevel, level, reason: id.name);
        expect(scene.backdrop, backdrop, reason: id.name);
        expect(scene.lines.length, inInclusiveRange(id == StorySceneId.ch1End ? 2 : 3, 5), reason: id.name);
      }
      expect(Catalog.storyScene(StorySceneId.prologue).backdrop, ArtScene.storyTown);
      expect(Catalog.storyScene(StorySceneId.hoa1).backdrop, ArtScene.storyGrandmaKitchen);
      expect(Catalog.storyScene(StorySceneId.kenji4).featuredFriend, FriendId.kenji);
      expect(Catalog.storyScene(StorySceneId.linh4).featuredFriend, FriendId.linh);
      expect(Catalog.storyScene(StorySceneId.hoa4).featuredFriend, FriendId.hoa);
      for (final id in [StorySceneId.rosa1, StorySceneId.rosa2]) {
        expect(Catalog.storyScene(id).lines.any((l) => l.speaker == Speaker.rosa), isTrue, reason: id.name);
      }
      expect(Catalog.storyScene(StorySceneId.ch1End).lines.map((l) => l.speaker), [Speaker.narrator, Speaker.mai]);
      for (final locale in const [ui.Locale('en'), ui.Locale('vi')]) {
        final l = lookupAppLocalizations(locale);
        for (final scene in Catalog.storyScenes) {
          for (final line in scene.lines) {
            expect(line.text(l), isNotEmpty, reason: scene.id.name);
          }
        }
        expect(l.speakerName(Speaker.rosa), isNotEmpty);
      }
      // ch2End dùng lại hai dòng đầu của lời kết cũ.
      final en = lookupAppLocalizations(const ui.Locale('en'));
      final ch2End = Catalog.storyScene(StorySceneId.ch2End).lines;
      expect([ch2End[0].text(en), ch2End[1].text(en)], [en.storyFinaleLine1, en.storyFinaleLine2]);
      expect(Catalog.storyScene(StorySceneId.finale).lines.map((x) => x.text(en)), isNot(contains(en.storyFinaleLine3)));
    });

    test('bà Rosa nói bằng ảnh VIP vip_00 (có đủ nét mặt)', () {
      expect(CustomerArt.speakerSpriteId(Speaker.rosa), 'vip_00');
      expect(CustomerArt.speakerSpriteId(Speaker.rosa), 'vip_0${SpecialVisit.reservedVipLook}');
    });

    test('chapter1Complete: ch1End, ch2End hoặc finale', () {
      expect(_fresh().chapter1Complete, isFalse);
      expect((_fresh()..markSceneSeen(StorySceneId.ch1End)).chapter1Complete, isTrue);
      expect((_fresh()..markSceneSeen(StorySceneId.ch2End)).chapter1Complete, isTrue);
      final s = _fresh(extra: _progress(50))..markSceneSeen(StorySceneId.finale);
      expect(s.chapter1Complete, isTrue);
    });

    test('bản lưu cũ đã xem finale (lời kết cũ, chưa thắng L50) → ch1End + ch2End; finale mới vẫn chiếu sau L50', () {
      final old = _fresh(extra: {..._progress(14), 'scenes': ['prologue', 'hoa1', 'finale']});
      expect(old.seenScenes, {StorySceneId.prologue, StorySceneId.hoa1, StorySceneId.ch2End, StorySceneId.ch1End});
      expect(old.chapter1Complete, isTrue);
      // Ghi → đọc lại: giữ nguyên, không đổi lần hai.
      final back = GameState.fromJson(jsonDecode(jsonEncode(old.toJson())) as Map<String, dynamic>, clock: _clock);
      expect(back.seenScenes, old.seenScenes);
      expect(back.toJson()['scenes'], ['prologue', 'hoa1', 'ch2End', 'ch1End']);

      // Đã thắng L50 và xem finale mới → giữ finale.
      final done = _fresh(extra: {..._progress(50), 'scenes': ['finale', 'ch2End']});
      expect(done.seenScenes, {StorySceneId.finale, StorySceneId.ch2End});
      // Bản lưu chưa xem finale: không đổi gì.
      expect(_fresh(extra: {'scenes': ['prologue']}).seenScenes, {StorySceneId.prologue});
    });

    test('nền cảnh mới: có ảnh, thiếu ảnh (đọc lỗi) có cảnh thay sẵn có', () {
      for (final s in [ArtScene.storyGarden, ArtScene.storyAttic, ArtScene.storyFestival]) {
        final ref = ArtSprites.scene(s);
        expect(ArtSprites.ids[ArtGroup.scenes], contains(ref.id));
        expect(File(ref.assetPath).existsSync(), isTrue, reason: '$s');
        expect(s.fallback, isNotNull);
        expect(File(ArtSprites.scene(s.fallback!).assetPath).existsSync(), isTrue, reason: '$s');
      }
      expect(ArtScene.storyGarden.id, 'story_garden');
      expect(ArtScene.storyAttic.id, 'story_attic');
      expect(ArtScene.storyFestival.id, 'story_festival');
      expect(ArtScene.storyTown.fallback, isNull);
    });
  });

  group('đơn đặc biệt ghi hộp (bánh cưới L50)', () {
    test('levels.json: L50 bà Rosa đặt bánh sinh nhật nhiều tầng hộp quà; loader đọc / từ chối hộp lạ', () {
      final rosa = _levels.level(50).specials.firstWhere((v) => v.scene == StorySceneId.rosa2);
      expect((rosa.recipe, rosa.box, rosa.look), (RecipeId.birthdayCake, BoxType.gift, 'vip_00'));
      expect(_levels.level(2).specials.single.box, isNull);
      final j = jsonDecode(File(LevelConfigLoader.assetPath).readAsStringSync()) as Map<String, dynamic>;
      final l2 = (j['levels'] as List).cast<Map<String, dynamic>>().firstWhere((l) => l['id'] == 2);
      ((l2['specials'] as List).first as Map<String, dynamic>)['box'] = 'bag';
      expect(() => LevelConfigLoader.parse(jsonEncode(j), strict: true),
          throwsA(isA<FormatException>().having((e) => e.message, 'message', allOf(contains('level 2'), contains('"box"')))));
    });

    test('LevelSession: đơn dùng hộp của lượt ghé thay hộp chuẩn của món', () {
      LevelData level(BoxType? box) => LevelData(
            id: 50,
            chapter: 5,
            title: const {'en': 'Test', 'vi': 'Thử'},
            durationSec: 120,
            goal: const LevelGoal(type: GoalType.coins, stars: [10, 20, 30]),
            menu: const [RecipeId.croissant],
            caseSlots: 3,
            startStock: 0,
            patienceSec: 40,
            spawn: const SpawnCurve(startEverySec: 60, endEverySec: 60, rushAtPct: 100, rushEverySec: 60),
            specials: [SpecialVisit(atSec: 1, who: SpecialWho.hoa, recipe: RecipeId.croissant, box: box)],
            newRecipe: RecipeId.croissant,
          );
      BoxType boxOf(BoxType? box) {
        final s = LevelSession(
          level: level(box),
          defaults: const LevelDefaults(jitterPct: 0),
          modifiers: BakeModifiers.base,
          random: math.Random(3),
        );
        for (var i = 0; i < 30 * 5 && s.specialCustomer?.order == null; i++) {
          s.advance(LevelSession.step);
        }
        return s.specialCustomer!.order!.box;
      }

      expect(Catalog.recipe(RecipeId.croissant).box, BoxType.small);
      expect(boxOf(null), BoxType.small);
      expect(boxOf(BoxType.gift), BoxType.gift);
      expect(boxOf(BoxType.cake), BoxType.cake);
    });
  });

  group('Bí quyết của bà', () {
    test('unlocks.json: mục recipeSecrets L41, 3 bậc +5/10/15%, ×120/300/600; không nằm trong danh sách Nâng cấp', () {
      final cfg = _unlocks.recipeSecrets!;
      expect((cfg.id, cfg.chapter, cfg.level), ('recipe_secrets', 5, 41));
      expect([for (final t in cfg.tiers) (t.pricePct, t.costMult)], [(5, 120), (10, 300), (15, 600)]);
      expect(cfg.name('vi'), 'Bí quyết của bà');
      expect(cfg.name('en'), isNotEmpty);
      expect(_unlocks.unlock('recipe_secrets'), isNull);
      expect(_unlocks.unlocks.any((u) => u.id == 'recipe_secrets'), isFalse);
    });

    test('loader: bậc phải tăng dần, chỉ một mục, trường lạ bị từ chối', () {
      Map<String, dynamic> entry(Map<String, dynamic> j) =>
          (j['unlocks'] as List).cast<Map<String, dynamic>>().firstWhere((u) => u['kind'] == 'recipeSecrets');
      String error(void Function(Map<String, dynamic> j) mutate) {
        final j = jsonDecode(_unlocksJson()) as Map<String, dynamic>;
        mutate(j);
        try {
          UnlockConfigLoader.parse(jsonEncode(j), strict: true);
        } on FormatException catch (e) {
          return e.message;
        }
        fail('phải ném FormatException');
      }

      expect(error((j) => (entry(j)['tiers'] as List)[1] = {'pricePct': 5, 'costMult': 300}), contains('pricePct'));
      expect(error((j) => entry(j)['tiers'] = []), contains('tiers'));
      expect(error((j) => entry(j)['price'] = 10), contains('price'));
      expect(error((j) => (j['unlocks'] as List).add({...entry(j), 'id': 'secrets_2'})), contains('recipeSecrets'));
      // Khoan dung: mục hỏng → không có tính năng, phần còn lại vẫn đọc.
      final j = jsonDecode(_unlocksJson()) as Map<String, dynamic>;
      entry(j)['tiers'] = 'ba bậc';
      final skipped = <String>[];
      final lenient = UnlockConfigLoader.parse(jsonEncode(j), strict: false, onSkip: skipped.add);
      expect(lenient.recipeSecrets, isNull);
      expect(lenient.unlocks, hasLength(_unlocks.unlocks.length));
      expect(skipped, hasLength(1));
    });

    test('mở từ khi qua L41; giá round50(giá món × hệ số); mua lần lượt 3 bậc; hết bậc / chưa mở → null', () {
      expect(Economy.round50(30 * 120), 3600);
      expect(Economy.round50(98 * 120), 11750);
      expect(Economy.round50(98 * 600), 58800);

      final s = _fresh(coins: 200000);
      _clear(s, 40);
      expect(s.recipeSecretsUnlocked, isFalse);
      expect(s.recipeSecretPrice(RecipeId.cupcakeVanilla), isNull);
      expect(s.buyRecipeSecret(RecipeId.cupcakeVanilla), isFalse);
      _clear(s, 41);
      expect(s.recipeSecretsUnlocked, isTrue);
      expect(s.recipeSecretMaxTier, 3);
      // Món chưa mở (bánh Trung thu mở ở L43) → chưa mua được.
      expect(s.isRecipeUnlocked(RecipeId.mooncake), isFalse);
      expect(s.recipeSecretPrice(RecipeId.mooncake), isNull);

      const r = RecipeId.cupcakeVanilla; // giá 30
      expect([s.recipeSecretTier(r), s.recipeSecretPricePct(r), s.recipeSecretNextPricePct(r)], [0, 0, 5]);
      final coins0 = s.coins;
      for (final (price, pct) in const [(3600, 5), (9000, 10), (18000, 15)]) {
        expect(s.recipeSecretPrice(r), price);
        expect(s.buyRecipeSecret(r), isTrue);
        expect(s.recipeSecretPricePct(r), pct);
      }
      expect(s.coins, coins0 - 3600 - 9000 - 18000);
      expect(s.recipeSecretTier(r), 3);
      expect(s.recipeSecretPrice(r), isNull, reason: 'đã tối đa');
      expect(s.recipeSecretNextPricePct(r), isNull);
      expect(s.buyRecipeSecret(r), isFalse);
      expect(s.recipeSellPrice(r), (30 * 1.15).round());
      expect(s.shopSetup.recipePricePct, {r: 15});
      expect(s.shopSetup.priceMultOf(r), 1.15);
      expect(s.shopSetup.priceMultOf(RecipeId.croissant), 1.0);

      // Thiếu xu → false, không trừ.
      final poor = _fresh(coins: 100);
      _clear(poor, 41);
      final before = poor.coins;
      expect(poor.buyRecipeSecret(RecipeId.cupcakeVanilla), isFalse);
      expect(poor.coins, before);
      expect(poor.recipeSecretTier(RecipeId.cupcakeVanilla), 0);
    });

    test('bản lưu: recipeSecrets {món: bậc} đọc độc lập, thiếu → 0, hỏng không ảnh hưởng trường khác', () {
      final s = _fresh(extra: {
        'recipeSecrets': {'eggTart': 2, 'croissant': 1, 'ghost': 3, 'macaron': 99},
        'mastery': {'eggTart': 3},
      });
      expect(s.recipeSecretTier(RecipeId.eggTart), 2);
      expect(s.recipeSecretTier(RecipeId.croissant), 1);
      expect(s.recipeSecretTier(RecipeId.macaron), 3, reason: 'kẹp theo số bậc của config');
      expect(s.recipeSecretTier(RecipeId.cheesecake), 0);
      expect(s.recipeMastery(RecipeId.eggTart), 3, reason: 'khác sao sổ công thức');
      final json = s.toJson();
      expect((json['recipeSecrets'] as Map)['eggTart'], 2);
      expect((json['recipeSecrets'] as Map).keys, [for (final r in RecipeId.values) r.name]);
      final back = GameState.fromJson(jsonDecode(jsonEncode(json)) as Map<String, dynamic>, clock: _clock);
      expect(back.toJson(), json);
      // Không có trường → 0.
      expect(_fresh().recipeSecretTier(RecipeId.eggTart), 0);
      // Sai kiểu → trường đó về mặc định, trường khác giữ.
      final broken = _fresh(coins: 77, extra: {'recipeSecrets': 'hỏng'});
      expect(broken.coins, 77);
      expect(broken.recipeSecretTier(RecipeId.eggTart), 0);
    });

    test('LevelSession: giá bán (cả đơn đặc biệt) × hệ số bí quyết', () {
      final level = LevelData(
        id: 1,
        chapter: 1,
        title: const {'en': 'Test', 'vi': 'Thử'},
        durationSec: 120,
        goal: const LevelGoal(type: GoalType.customers, stars: [2, 4, 6]),
        menu: const [RecipeId.cupcakeVanilla],
        caseSlots: 3,
        startStock: 3,
        patienceSec: 40,
        spawn: const SpawnCurve(startEverySec: 8, endEverySec: 8, rushAtPct: 100, rushEverySec: 8),
        specials: const [SpecialVisit(atSec: 30, who: SpecialWho.hoa, recipe: RecipeId.cupcakeVanilla)],
        newRecipe: RecipeId.cupcakeVanilla,
      );
      const defaults = LevelDefaults(jitterPct: 0);
      final base = LevelBotStats.simulate(level, defaults, skill: 0.8, seeds: 6);
      final boosted = LevelBotStats.simulate(level, defaults,
          skill: 0.8, seeds: 6, setup: const ShopSetup(recipePricePct: {RecipeId.cupcakeVanilla: 25}));
      expect(boosted.avgServed, base.avgServed, reason: 'cùng seed → cùng diễn biến');
      expect(boosted.avgSpecials, base.avgSpecials);
      expect(base.avgSpecials, greaterThan(0));
      // Làm tròn xu mỗi lượt bán (giá 30 → 37,5) lệch vài phần trăm.
      expect(boosted.avgCoins / base.avgCoins, closeTo(1.25, 0.03));
    });

    test('bot mô phỏng mua bí quyết sau khi qua L41 (sau nhân viên, trước trang trí)', () {
      final run = ProgressionSim(_levels, _unlocks).run(BotSkill.of(0.75), 1);
      final secrets = {
        for (final e in run.boughtAt.entries)
          if (e.key.startsWith('secret:')) e.key: e.value,
      };
      expect(secrets, isNotEmpty);
      expect(secrets.values.every((passed) => passed >= 41), isTrue);
      expect(simSecretKey(RecipeId.croissant, 2), 'secret:croissant:2');
    });
  });
}
