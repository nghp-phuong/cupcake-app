import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:sugarleaf_bakery/core/economy.dart';
import 'package:sugarleaf_bakery/core/game_state.dart';
import 'package:sugarleaf_bakery/core/models/mochi.dart';
import 'package:sugarleaf_bakery/core/weather.dart';

DateTime _clock() => DateTime(2026, 10, 28, 10);

/// Ván mới đang ở ngày game [day] (bộ đếm ngày giữ lại cho Mochi ở giai đoạn sau).
GameState _stateAtDay(int day) {
  final s = GameState.newGame(clock: _clock);
  for (var d = 1; d < day; d++) {
    s.completeDay();
  }
  return s;
}

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

  // Mochi tạm ngừng xuất hiện trong V2 (chưa có trong level); dữ liệu + quà vẫn giữ để đưa lại sau.
  group('Mochi (GameState)', () {
    test('vuốt ve: quà lần đầu có đá quý, mỗi ngày một lần', () {
      final state = _stateAtDay(5);
      final coins = state.coins;
      final gems = state.gems;
      expect(state.petMochi(), const MochiGift(coins: Economy.mochiPetCoins, gems: Economy.mochiFirstPetGems));
      expect(state.coins, coins + Economy.mochiPetCoins);
      expect(state.gems, gems + Economy.mochiFirstPetGems);
      expect(state.petMochi(), isNull);
      expect(state.restMochi(), isFalse);
      expect(state.mochiVisits, 1);
      expect(state.mochiPets, 1);
      expect(state.lastMochiDay, 5);
      // Ngày mưa sau: không còn đá quý.
      var day = 6;
      while (!Weather.isRainy(day)) {
        day++;
      }
      expect(state.petMochi(day: day), const MochiGift(coins: Economy.mochiPetCoins, gems: 0));
      expect(state.mochiVisits, 2);
      expect(state.mochiPets, 2);
    });

    test('để Mochi nghỉ: ghi lượt ghé, không quà', () {
      final state = _stateAtDay(5);
      final coins = state.coins;
      expect(state.restMochi(), isTrue);
      expect(state.coins, coins);
      expect(state.mochiVisits, 1);
      expect(state.mochiPets, 0);
      expect(state.petMochi(), isNull);
    });

    test('lưu/nạp: giữ lượt ghé, không cho quà lại', () {
      final state = _stateAtDay(5)..petMochi();
      final json = jsonDecode(jsonEncode(state.toJson())) as Map<String, dynamic>;
      expect(json['mochiVisits'], 1);
      expect(json['mochiPets'], 1);
      expect(json['lastMochiDay'], 5);
      final back = GameState.fromJson(json, clock: _clock);
      expect(back.toJson(), state.toJson());
      expect(back.petMochi(day: 5), isNull);
      expect(back.restMochi(day: 5), isFalse);
    });

    test('save thiếu khoá Mochi → 0; sai kiểu → trường đó về mặc định', () {
      final s = GameState.fromJson({'v': GameState.saveVersion, 'day': 5, 'coins': 200}, clock: _clock);
      expect(s.mochiVisits, 0);
      expect(s.mochiPets, 0);
      expect(s.lastMochiDay, 0);
      final bad = GameState.fromJson(
        {'v': GameState.saveVersion, 'mochiVisits': 'x', 'mochiPets': 2, 'lastMochiDay': -3},
        clock: _clock,
      );
      expect(bad.mochiVisits, 0);
      expect(bad.mochiPets, 2);
      expect(bad.lastMochiDay, 0);
    });
  });
}
