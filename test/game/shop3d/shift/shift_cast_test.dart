import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:sugarleaf_bakery/game/shop3d/chibi/chibi_actor.dart';
import 'package:sugarleaf_bakery/game/shop3d/chibi/chibi_cast.dart';
import 'package:sugarleaf_bakery/game/shop3d/chibi/chibi_characters.dart';
import 'package:sugarleaf_bakery/game/shop3d/chibi/chibi_regulars.dart';
import 'package:sugarleaf_bakery/game/shop3d/chibi/chibi_sizes.dart';
import 'package:sugarleaf_bakery/game/shop3d/shift/shift_cast.dart';
import 'package:sugarleaf_bakery/game/shop3d/shop3d_layout.dart';

/// Chọn chibi khách của ca bán (G1) và kịch bản khách nền. Dart thuần.
void main() {
  group('castFor', () {
    test('khách thường: id regular_* không trùng nhau, không trùng khách nền', () {
      for (var seed = 0; seed < 200; seed++) {
        for (final n in [4, 5, 6, 15]) {
          final ids = castFor(n, random: math.Random(seed));
          expect(ids.length, n);
          expect(ids.toSet().length, n, reason: 'seed $seed n $n: $ids');
          for (final id in ids) {
            expect(ChibiRegulars.ids, contains(id));
            expect(ChibiCast.ambientGuestIds, isNot(contains(id)));
          }
        }
      }
    });

    test('VIP chỉ là vip_01 / vip_02 (không phải vip_00 của bà Rosa); hết thì dùng khách thường', () {
      for (var seed = 0; seed < 50; seed++) {
        final one = castFor(1, vip: true, random: math.Random(seed));
        expect(['vip_01', 'vip_02'], contains(one.single));
        final two = castFor(2, vip: true, random: math.Random(seed));
        expect(two.toSet(), {'vip_01', 'vip_02'});
        final four = castFor(4, vip: true, random: math.Random(seed));
        expect(four.toSet().length, 4);
        expect(four.where((id) => id.startsWith('vip_')).toSet(), {'vip_01', 'vip_02'});
        expect(four.where((id) => !id.startsWith('vip_')).every(ChibiRegulars.ids.contains), isTrue);
      }
      expect(shiftVipIds, isNot(contains(ChibiCharacters.rosa)));
    });

    test('castForShift: theo cờ VIP từng khách, không trùng, cùng thứ tự', () {
      for (var seed = 0; seed < 100; seed++) {
        final flags = [false, true, false, true, true, false];
        final ids = castForShift(flags, random: math.Random(seed));
        expect(ids.length, flags.length);
        expect(ids.toSet().length, flags.length, reason: '$ids');
        for (var i = 0; i < flags.length; i++) {
          if (!flags[i]) expect(ids[i], startsWith('regular_'));
        }
        // Hai VIP đầu dùng vip_01 / vip_02; VIP thứ ba rơi về khách thường.
        expect(ids.where((id) => id.startsWith('vip_')).toSet(), {'vip_01', 'vip_02'});
        for (final id in ids) {
          expect(isShiftGuestId(id), isTrue);
          expect(ChibiCast.ambientGuestIds, isNot(contains(id)));
        }
      }
    });

    test('đếm 0 → rỗng; quá số khách có thể → ArgumentError; cùng seed cùng kết quả', () {
      expect(castFor(0), isEmpty);
      expect(castFor(-1), isEmpty);
      expect(() => castFor(16), throwsArgumentError);
      expect(castFor(5, random: math.Random(9)), castFor(5, random: math.Random(9)));
    });

    test('mọi id dựng được model (regular_* và vip_01 / vip_02), model.id khớp', () {
      for (final id in [...shiftRegularIds, ...shiftVipIds]) {
        expect(isShiftGuestId(id), isTrue, reason: id);
        final m = ChibiSizes.fit(buildShiftGuest(id));
        expect(m.id, id);
      }
      expect(shiftRegularIds.length, 15);
      for (final id in [...ChibiCast.ambientGuestIds, 'mai', 'staff_nora', 'mochi', 'regular_15']) {
        expect(isShiftGuestId(id), isFalse, reason: id);
      }
    });
  });

  group('khách nền', () {
    test('ambientGuestIds = linh, hoa, kenji, vip_00; loopFor khớp kịch bản của build', () {
      expect(ChibiCast.ambientGuestIds, ['linh', 'hoa', 'kenji', 'vip_00']);
      final built = {for (final a in ChibiCast.build()) a.id: a};
      for (final id in ChibiCast.ambientGuestIds) {
        final loop = ChibiCast.loopFor(id);
        final script = built[id]!.script;
        expect(loop.length, script.length, reason: id);
        for (var i = 0; i < loop.length; i++) {
          expect(loop[i].action, script[i].action, reason: '$id #$i');
          expect(loop[i].duration, script[i].duration, reason: '$id #$i');
        }
        expect(ChibiCast.sitIndex(loop), greaterThan(0));
      }
      expect(() => ChibiCast.loopFor('mai'), throwsArgumentError);
      expect(() => ChibiCast.seatedIdle('regular_00'), throwsArgumentError);
    });

    test('seatedIdle: đi tới đúng ghế rồi ngồi rất lâu (không có vòng lặp)', () {
      for (final id in ChibiCast.ambientGuestIds) {
        final seat = ChibiCast.seatOf(id);
        final s = ChibiCast.seatedIdle(id);
        final walk = s.firstWhere((x) => x.action == ChibiAction.walk);
        expect(walk.path.last, (seat.x, Shop3dLayout.seatApproachZ));
        final sit = s.firstWhere((x) => x.action == ChibiAction.sit);
        expect(sit.seat, same(seat));
        expect(sit.duration, greaterThanOrEqualTo(3600));
        // Từ giữa tiệm (đang ở quầy): không quay ra cửa rồi vào lại.
        final fromCounter = ChibiCast.seatedIdle(id, fromX: 0.2, fromZ: 0.45);
        expect(fromCounter.first.path.length, lessThan(walk.path.length + 1));
        expect(fromCounter.first.path.first, isNot((Shop3dLayout.entrance.x, Shop3dLayout.entrance.z)));
      }
    });

    test('pathFrom: chiếu lên đoạn gần nhất, không quay lại điểm đã qua', () {
      const chain = [(0.0, 0.0), (4.0, 0.0), (4.0, 4.0)];
      expect(ChibiCast.pathFrom(chain, 0.0, 0.1), [(4.0, 0.0), (4.0, 4.0)]);
      expect(ChibiCast.pathFrom(chain, 2.0, 0.1), [(4.0, 0.0), (4.0, 4.0)]);
      expect(ChibiCast.pathFrom(chain, 4.1, 2.0), [(4.0, 4.0)]);
      expect(ChibiCast.pathFrom(chain, 4.0, 5.0), [(4.0, 4.0)]);
      expect(ChibiCast.pathFrom(const [(1.0, 1.0)], 0, 0), [(1.0, 1.0)]);
    });
  });
}
