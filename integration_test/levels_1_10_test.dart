import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:sugarleaf_bakery/core/game_state.dart';
import 'package:sugarleaf_bakery/core/level/level.dart';
import 'package:sugarleaf_bakery/core/level/level_bot.dart';
import 'package:sugarleaf_bakery/core/models/ids.dart';
import 'package:sugarleaf_bakery/core/save_repository.dart';
import 'package:sugarleaf_bakery/core/unlock/unlock.dart';

/// QA việc 7: chơi tự động Level 1 → 10 bằng `LevelBot` trên `GameState` thật (cấu hình nạp qua rootBundle như app),
/// mỗi lượt: tạo session từ tiệm hiện tại → bot chơi → applyLevelResult → interstitial theo luật → mua đồ mở được.
///
/// Chạy trên thiết bị: `flutter test integration_test -d <thiết bị>`; không có thiết bị: `flutter test
/// integration_test/levels_1_10_test.dart` (headless, cùng logic).
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  levels1To10Tests();
}

/// Phần thân (cũng chạy headless từ `test/core/qa_levels_1_10_headless_test.dart`).
void levels1To10Tests() {
  testWidgets('bot chơi L1 → L10: qua hết, mở đúng level kế, chương 2 theo sao, lưu/đọc khớp', (tester) async {
    final levels = await LevelConfigLoader.load(rootBundle, strict: true);
    final unlocks = await UnlockConfigLoader.load(rootBundle, strict: true);
    final monetization = await MonetizationConfigLoader.load(rootBundle, strict: true);
    final repo = MemorySaveRepository();
    final gs = GameState.newGame(clock: () => DateTime(2026, 10, 30, 9))
      ..attachLevelConfig(levels)
      ..attachUnlockConfig(unlocks)
      ..attachMonetizationConfig(monetization)
      ..attachAutosave(repo);

    final log = <String>[];
    var plays = 0, interstitials = 0;
    for (var id = 1; id <= 10; id++) {
      expect(gs.isLevelUnlocked(id), isTrue, reason: 'L$id phải mở sau khi qua L${id - 1}');
      expect(gs.currentLevelId, id);
      LevelResult? r;
      for (var attempt = 1; attempt <= 8; attempt++) {
        final level = levels.level(id);
        final session = LevelSession(
          level: level,
          defaults: levels.defaults,
          modifiers: gs.bakeModifiers,
          decorTipBonusPct: gs.decorTipBonusPct,
          setup: gs.shopSetup,
          random: math.Random(id * 100 + attempt),
        );
        r = LevelBot(BotSkill.of(0.8), random: math.Random(id * 7919 + attempt)).play(session);
        session.dispose();
        plays++;
        final coinsBefore = gs.coins;
        final delta = gs.applyLevelResult(r);
        expect(gs.coins, coinsBefore + r.coins);
        gs.registerLevelPlayEnded();
        if (gs.shouldShowInterstitialAfterResult(
            watchedRewardedHere: false, unlockedChapter: delta.unlockedChapter != null)) {
          expect(gs.highestCompletedLevel, greaterThanOrEqualTo(5));
          gs.registerInterstitialShown();
          interstitials++;
        }
        log.add('L$id lần $attempt: $r');
        if (r.won) {
          if (id < 10) expect(delta.unlockedLevel, id + 1);
          break;
        }
      }
      expect(r!.won, isTrue, reason: 'bot 0.8 phải qua L$id trong 8 lượt\n${log.join('\n')}');
      expect(gs.levelRecord(id)!.stars, inInclusiveRange(1, 3));
      // Mua như người chơi: mở rộng / nhân viên / thiết bị vừa mở và đủ xu.
      for (final u in unlocks.unlocks) {
        if (gs.unlockState(u.id) == UnlockState.available) gs.buyUnlock(u.id);
      }
      for (final e in unlocks.equipment) {
        while (gs.buyEquipment(e.id) == PurchaseResult.ok) {}
      }
      expect(gs.coins, greaterThanOrEqualTo(0));
    }

    expect(gs.highestCompletedLevel, 10);
    expect(gs.isChapterUnlocked(2), gs.totalStars >= levels.chapter(2)!.starsToUnlock);
    expect(gs.isLevelUnlocked(11), gs.isChapterUnlocked(2));
    expect(gs.boosterGiftReceived, isTrue, reason: 'qua L3 → quà vật phẩm');
    if (plays >= 8) expect(interstitials, greaterThan(0));

    await gs.flush();
    final again = await GameState.load(repo, clock: () => DateTime(2026, 10, 30, 9))
      ..attachLevelConfig(levels)
      ..attachUnlockConfig(unlocks)
      ..attachMonetizationConfig(monetization);
    expect(jsonEncode(again.toJson()), jsonEncode(gs.toJson()));
    // ignore: avoid_print
    print('L1–L10: $plays lượt, ${gs.totalStars} sao, ${gs.coins} xu, $interstitials interstitial, '
        'chương 2 ${gs.isChapterUnlocked(2) ? 'mở' : 'khoá'}\n${log.join('\n')}');
    gs.dispose();
    again.dispose();
  });
}
