import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sugarleaf_bakery/core/game_state.dart';
import 'package:sugarleaf_bakery/core/level/level.dart';
import 'package:sugarleaf_bakery/core/models/ids.dart';

DateTime _clock() => DateTime(2026, 10, 27, 10);

final _config = LevelConfigLoader.parse(File(LevelConfigLoader.assetPath).readAsStringSync());

GameState _fresh() => GameState.newGame(clock: _clock)..attachLevelConfig(_config);

LevelResult _play(int id, {int stars = 0, int goal = 0}) => LevelResult(
      levelId: id,
      won: stars > 0,
      stars: stars,
      coins: 10,
      served: 1,
      lost: 0,
      specialsDone: 0,
      bestCombo: 0,
      perfectBakes: 0,
      recipeStars: const {},
      goalValue: goal,
    );

/// Qua L1..[last] lần lượt, mỗi level [stars]★.
void _clear(GameState s, int last, {int stars = 1}) {
  for (var id = 1; id <= last; id++) {
    s.applyLevelResult(_play(id, stars: stars, goal: 1));
  }
}

void main() {
  final chapter2 = _config.chapter(2)!;

  test('ván mới: chỉ L1 mở, chương 1 mở, chương 2 khoá; món theo menu level đã mở', () {
    final s = _fresh();
    expect(s.isLevelUnlocked(1), isTrue);
    expect(s.isLevelUnlocked(2), isFalse);
    expect(s.isLevelUnlocked(999), isFalse);
    expect(s.isChapterUnlocked(1), isTrue);
    expect(s.isChapterUnlocked(2), isFalse);
    expect(s.isChapterUnlocked(9), isFalse);
    expect(s.currentLevelId, 1);
    expect(s.highestCompletedLevel, 0);
    expect(s.totalStars, 0);
    expect(s.unlockedRecipes, [RecipeId.cupcakeVanilla]);
    expect(s.isRecipeUnlocked(RecipeId.cupcakeChocolate), isFalse);
    expect(s.isToppingUnlocked(ToppingId.blueberry), isFalse);
  });

  test('applyLevelResult: kỷ lục (sao = max, best = max, plays++, firstWin) + delta mở level', () {
    final s = _fresh();
    var notified = 0;
    s.addListener(() => notified++);

    final d1 = s.applyLevelResult(_play(1, stars: 2, goal: 8));
    expect(notified, 1);
    expect((d1.levelId, d1.oldStars, d1.newStars, d1.newBest), (1, 0, 2, false));
    expect(d1.gainedStars, 2);
    expect(d1.unlockedLevel, 2);
    expect(d1.unlockedChapter, isNull);
    expect(s.levelRecord(1), const LevelRecord(stars: 2, best: 8, plays: 1, firstWin: true));
    expect(s.levelRecord(1)!.completed, isTrue);
    expect(s.currentLevelId, 2);
    expect(s.isRecipeUnlocked(RecipeId.cupcakeChocolate), isTrue, reason: 'L2 đã mở → món của L2 mở');

    final d2 = s.applyLevelResult(_play(1, stars: 3, goal: 10));
    expect((d2.oldStars, d2.newStars, d2.newBest, d2.unlockedLevel), (2, 3, true, null));
    final d3 = s.applyLevelResult(_play(1, goal: 4)); // thua
    expect((d3.oldStars, d3.newStars, d3.newBest), (3, 3, false));
    expect(s.levelRecord(1), const LevelRecord(stars: 3, best: 10, plays: 3, firstWin: true));
    expect(s.totalStars, 3);
    expect(s.starsInChapter(1), 3);
    expect(s.starsInChapter(2), 0);
  });

  test('thua lượt đầu → firstWin = false mãi; thua không mở level sau', () {
    final s = _fresh();
    final lose = s.applyLevelResult(_play(1, goal: 3));
    expect(lose.unlockedLevel, isNull);
    expect(s.isLevelUnlocked(2), isFalse);
    expect(s.levelRecord(1), const LevelRecord(stars: 0, best: 3, plays: 1));
    expect(s.levelRecord(1)!.completed, isFalse);
    s.applyLevelResult(_play(1, stars: 1, goal: 6));
    expect(s.levelRecord(1)!.firstWin, isFalse);
    expect(s.isLevelUnlocked(2), isTrue);
  });

  test('chương 2 cần qua L10 VÀ đủ sao; mở chương → delta báo chương + level', () {
    expect(chapter2.starsToUnlock, inInclusiveRange(15, 25));
    final s = _fresh();
    _clear(s, 10); // 10 sao < starsToUnlock
    expect(s.totalStars, 10);
    expect(s.highestCompletedLevel, 10);
    expect(s.isChapterUnlocked(2), isFalse);
    expect(s.isLevelUnlocked(11), isFalse);
    expect(s.currentLevelId, 10, reason: 'chờ đủ sao: level mở cao nhất');

    // Chơi lại lấy sao tới khi đủ.
    LevelProgressDelta? opened;
    for (var id = 1; id <= 10 && opened == null; id++) {
      final d = s.applyLevelResult(_play(id, stars: 3, goal: 99));
      if (d.unlockedChapter != null) opened = d;
    }
    expect(opened, isNotNull);
    expect(opened!.unlockedChapter, 2);
    expect(opened.unlockedLevel, 11);
    expect(s.totalStars, greaterThanOrEqualTo(chapter2.starsToUnlock));
    expect(s.isChapterUnlocked(2), isTrue);
    expect(s.currentLevelId, 11);
    expect(s.isRecipeUnlocked(RecipeId.birthdayCake), _config.level(11).menu.contains(RecipeId.birthdayCake));
  });

  test('đủ sao nhưng chưa qua L10 → chương 2 vẫn khoá', () {
    final s = _fresh();
    _clear(s, 9, stars: 3); // 27 sao
    expect(s.totalStars, greaterThanOrEqualTo(chapter2.starsToUnlock));
    expect(s.isChapterUnlocked(2), isFalse);
    final d = s.applyLevelResult(_play(10, stars: 1, goal: 2));
    expect(d.unlockedChapter, 2);
    expect(d.unlockedLevel, 11);
  });

  test('qua hết → currentLevelId = level cao nhất; món, topping theo level mở', () {
    final s = _fresh();
    _clear(s, _config.levels.length, stars: 3);
    expect(s.currentLevelId, _config.levels.last.id);
    expect(s.highestCompletedLevel, _config.levels.last.id);
    expect(s.unlockedRecipes.toSet(), {for (final l in _config.levels) ...l.menu});
    expect(s.isToppingUnlocked(ToppingId.candle), isTrue);
  });

  test('id không có trong config: giữ trong bản lưu nhưng không tính sao / mốc mở khoá', () {
    final s = GameState.fromJson({
      'v': 2,
      'progress': {
        'levels': {
          '1': {'stars': 2, 'best': 5, 'plays': 1, 'firstWin': true},
          '500': {'stars': 3, 'best': 1, 'plays': 1, 'firstWin': true},
        },
      },
    }, clock: _clock);
    // Chưa gắn config: tính mọi id.
    expect(s.totalStars, 5);
    expect(s.highestCompletedLevel, 500);
    s.attachLevelConfig(_config);
    expect(s.totalStars, 2);
    expect(s.highestCompletedLevel, 1);
    expect(s.levelRecord(500), isNotNull);
    expect(((s.toJson()['progress'] as Map)['levels'] as Map).keys, ['1', '500']);
  });

  test('cấu hình rỗng: không level nào mở, app vẫn chạy (món như V1 theo số level đã qua)', () {
    final s = GameState.newGame(clock: _clock)..attachLevelConfig(LevelConfig.empty());
    expect(s.isLevelUnlocked(1), isFalse);
    expect(s.isChapterUnlocked(1), isFalse);
    expect(s.currentLevelId, 1);
    expect(s.totalStars, 0);
    expect(s.unlockedRecipes, [RecipeId.cupcakeVanilla, RecipeId.cupcakeChocolate]);
    final d = s.applyLevelResult(_play(1, stars: 2, goal: 1));
    expect(d.unlockedLevel, isNull);
    expect(s.totalStars, 2);
  });

  test('attachLevelConfig: cùng cấu hình → không notify', () {
    final s = _fresh();
    var notified = 0;
    s.addListener(() => notified++);
    s.attachLevelConfig(_config);
    expect(notified, 0);
  });
}
