import 'dart:convert';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:sugarleaf_bakery/core/day_controller.dart';
import 'package:sugarleaf_bakery/core/economy.dart';
import 'package:sugarleaf_bakery/core/game_state.dart';
import 'package:sugarleaf_bakery/core/models/bake.dart';
import 'package:sugarleaf_bakery/core/models/ids.dart';
import 'package:sugarleaf_bakery/core/models/mochi.dart';
import 'package:sugarleaf_bakery/core/models/order.dart';
import 'package:sugarleaf_bakery/core/weather.dart';

DateTime _clock() => DateTime(2026, 10, 28, 10);

BakeOutcome _perfectFor(Order o) => BakeOutcome(
      wrongMouldDrops: 0,
      mixTurns: o.recipeData.mixTurns.toDouble(),
      bakeRelease: o.recipeData.bakeTarget,
      frostCoverage: 1,
      toppingsPlaced: {for (final t in o.toppings) t.topping: t.count},
      boxChosen: o.box,
    );

/// Ván mới đã xem mọi cảnh truyện, đang ở ngày [day].
GameState _stateAtDay(int day) {
  final s = GameState.newGame(clock: _clock);
  for (final id in StorySceneId.values) {
    s.markSceneSeen(id);
  }
  for (var d = 1; d < day; d++) {
    s.completeDay();
  }
  return s;
}

void _serveOne(DayController c) => c.commit(c.evaluate(_perfectFor(c.currentOrder)));

void main() {
  group('Weather', () {
    test('ngày 1–4 tạnh, ngày 5 mưa', () {
      for (var d = -2; d <= 4; d++) {
        expect(Weather.isRainy(d), isFalse, reason: 'ngày $d');
      }
      expect(Weather.isRainy(5), isTrue);
      expect(Weather.isRainy(6), isFalse);
    });

    test('từ ngày 6 theo công thức, không bao giờ mưa hai ngày liền', () {
      for (var d = 6; d <= 400; d++) {
        final formula = (d * 37 + 11) % 4 == 0;
        final expected = formula && !Weather.isRainy(d - 1);
        expect(Weather.isRainy(d), expected, reason: 'ngày $d');
        if (Weather.isRainy(d)) expect(Weather.isRainy(d - 1), isFalse, reason: 'ngày $d');
      }
    });

    test('khoảng 25% trên 400 ngày, gọi lại ra cùng kết quả', () {
      final first = [for (var d = 1; d <= 400; d++) Weather.isRainy(d)];
      final second = [for (var d = 1; d <= 400; d++) Weather.isRainy(d)];
      expect(second, first);
      final rainy = first.where((r) => r).length;
      expect(rainy / 400, closeTo(0.25, 0.03));
    });
  });

  group('Mochi', () {
    test('ngày tạnh: không ghé', () {
      final c = DayController(state: _stateAtDay(4), random: Random(1));
      expect(c.isRainy, isFalse);
      expect(c.mochiVisitAfterIndex, isNull);
      while (!c.isFinished) {
        expect(c.shouldShowMochi, isFalse);
        _serveOne(c);
      }
      expect(c.shouldShowMochi, isFalse);
      expect(c.petMochi(), isNull);
      expect(c.finishDay().isRainy, isFalse);
    });

    test('ngày 5: ghé đúng sau khách thứ total ~/ 2, một lần, không đổi luồng ngày', () {
      final state = _stateAtDay(5);
      final c = DayController(state: state, random: Random(3));
      expect(c.isRainy, isTrue);
      expect(c.mochiVisitAfterIndex, c.total ~/ 2 - 1);
      expect(c.isFirstMochiVisit, isTrue);

      final orders = List.of(c.orders);
      var shown = 0;
      while (!c.isFinished) {
        expect(c.shouldShowMochi, isFalse, reason: 'trước khi phục vụ khách ${c.index}');
        _serveOne(c);
        if (c.shouldShowMochi) {
          shown++;
          expect(c.index, c.total ~/ 2);
          final coins = state.coins;
          final gems = state.gems;
          final gift = c.petMochi();
          expect(gift, const MochiGift(coins: Economy.mochiPetCoins, gems: Economy.mochiFirstPetGems));
          expect(state.coins, coins + 30);
          expect(state.gems, gems + 5);
          expect(c.shouldShowMochi, isFalse);
          expect(c.mochiVisitAfterIndex, isNull);
          expect(c.petMochi(), isNull);
          expect(state.coins, coins + 30);
        }
      }
      expect(shown, 1);
      expect(c.orders, orders);
      expect(state.mochiVisits, 1);
      expect(state.mochiPets, 1);
      expect(state.lastMochiDay, 5);
      final summary = c.finishDay();
      expect(summary.isRainy, isTrue);
      expect(summary.records.length, c.total);
    });

    test('để Mochi nghỉ: ghi lượt ghé, không quà', () {
      final state = _stateAtDay(5);
      final c = DayController(state: state, random: Random(4));
      for (var i = 0; i < c.total ~/ 2; i++) {
        _serveOne(c);
      }
      expect(c.shouldShowMochi, isTrue);
      final coins = state.coins;
      final gems = state.gems;
      c.restMochi();
      expect(state.coins, coins);
      expect(state.gems, gems);
      expect(state.mochiVisits, 1);
      expect(state.mochiPets, 0);
      expect(state.lastMochiDay, 5);
      expect(c.shouldShowMochi, isFalse);
    });

    test('lần vuốt ve sau không có đá quý; lời dẫn "lại ghé"', () {
      final state = _stateAtDay(5);
      expect(state.petMochi(), const MochiGift(coins: 30, gems: 5));
      // Ngày mưa tiếp theo.
      var day = 6;
      while (!Weather.isRainy(day)) {
        day++;
      }
      while (state.dayNumber < day) {
        state.completeDay();
      }
      final c = DayController(state: state, random: Random(5));
      expect(c.isRainy, isTrue);
      expect(c.isFirstMochiVisit, isFalse);
      for (var i = 0; i < c.total ~/ 2; i++) {
        _serveOne(c);
      }
      final gems = state.gems;
      expect(c.petMochi(), const MochiGift(coins: Economy.mochiPetCoins, gems: 0));
      expect(state.gems, gems);
      expect(state.mochiVisits, 2);
      expect(state.mochiPets, 2);
    });

    test('lưu/nạp giữa ngày: Mochi không ghé lại, không cho quà lại', () {
      final state = _stateAtDay(5);
      final c = DayController(state: state, random: Random(6));
      for (var i = 0; i < c.total ~/ 2; i++) {
        _serveOne(c);
      }
      c.petMochi();

      final json = jsonDecode(jsonEncode(state.toJson())) as Map<String, dynamic>;
      expect(json['mochiVisits'], 1);
      expect(json['mochiPets'], 1);
      expect(json['lastMochiDay'], 5);
      final back = GameState.fromJson(json, clock: _clock);
      expect(back.toJson(), state.toJson());

      final again = DayController(state: back, random: Random(7));
      expect(again.isRainy, isTrue);
      expect(again.mochiVisitAfterIndex, isNull);
      final coins = back.coins;
      while (!again.isFinished) {
        expect(again.shouldShowMochi, isFalse);
        _serveOne(again);
      }
      expect(back.petMochi(day: 5), isNull);
      expect(back.restMochi(day: 5), isFalse);
      expect(back.mochiVisits, 1);
      expect(back.coins, greaterThan(coins)); // chỉ tiền đơn hàng
    });

    test('save cũ thiếu khoá Mochi → 0, Mochi vẫn ghé ngày mưa', () {
      final s = GameState.fromJson({'v': 1, 'day': 5, 'coins': 200}, clock: _clock);
      expect(s.mochiVisits, 0);
      expect(s.mochiPets, 0);
      expect(s.lastMochiDay, 0);
      expect(DayController(state: s, random: Random(1)).mochiVisitAfterIndex, isNotNull);
      // Sai kiểu → trường đó về mặc định.
      final bad = GameState.fromJson({'v': 1, 'mochiVisits': 'x', 'mochiPets': 2, 'lastMochiDay': -3}, clock: _clock);
      expect(bad.mochiVisits, 0);
      expect(bad.mochiPets, 2);
      expect(bad.lastMochiDay, 0);
    });
  });
}
