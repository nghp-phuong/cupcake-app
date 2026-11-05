import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:sugarleaf_bakery/game/shop3d/interact/shop3d_nav.dart';
import 'package:sugarleaf_bakery/game/shop3d/shop3d_layout.dart';

/// Bán kính nhân vật điều khiển (Mai ~0,27 m).
const _r = 0.27;

/// Đi thẳng [dist] mét theo hướng (dx, dz) bằng nhiều bước nhỏ như từng khung hình; trả (x, z) cuối.
({double x, double z, bool blocked}) _walk(
  Shop3dNav nav,
  double x,
  double z,
  double dx,
  double dz,
  double dist, {
  double step = 0.03,
  List<NavCircle>? others,
}) {
  final len = math.sqrt(dx * dx + dz * dz);
  final ux = dx / len, uz = dz / len;
  final m = NavMove();
  var blocked = false;
  var travelled = 0.0;
  while (travelled < dist) {
    nav.slide(x, z, ux * step, uz * step, _r, out: m, others: others);
    x = m.x;
    z = m.z;
    blocked = blocked || m.blocked;
    travelled += step;
  }
  return (x: x, z: z, blocked: blocked);
}

void main() {
  final nav = Shop3dNav.fromLayout(owned: Shop3dRequires.all);
  final navBare = Shop3dNav.fromLayout();

  group('canStand', () {
    test('giữa phòng, vỉa hè, khe cửa đứng được', () {
      expect(nav.canStand(0, 1.2, _r), isTrue);
      expect(nav.canStand(0, 5.5, _r), isTrue);
      expect(nav.canStand(3.6, 4.2, _r), isTrue);
      expect(nav.canStand(2.2, 5.5, _r), isTrue); // tâm sự kiện
    });

    test('mặt tiền ngoài cửa (P3): chậu hoa / ghế băng chặn, nhưng khe cửa, lối vào / ra và chỗ sự kiện vẫn thông', () {
      expect(nav.canStand(2.8, 4.47, _r), isFalse); // chậu trái cửa
      expect(nav.canStand(4.42, 4.47, _r), isFalse); // chậu phải cửa
      expect(nav.canStand(5.1, 4.55, _r), isFalse); // ghế băng
      // toàn bộ khe cửa từ trong ra vỉa hè (làn vào x = 3,6, làn ra x = 3,4) + điểm khách xuất hiện / rời đi
      for (final x in [3.4, 3.6, 3.8]) {
        for (var z = 3.7; z <= 5.6; z += 0.1) {
          expect(nav.canStand(x, z, _r), isTrue, reason: '($x, $z)');
        }
      }
      for (final s in [Shop3dLayout.doorOutside, Shop3dLayout.exitOutside, Shop3dLayout.entrance]) {
        expect(nav.canStand(s.x, s.z, _r), isTrue, reason: s.id);
      }
      // cặp khách cãi nhau (1,75; 5,5) / (2,65; 5,5) và Mai (2,2; 4,8) + đường dọc vỉa hè ra hai đầu
      for (final (x, z) in const [(1.75, 5.5), (2.65, 5.5), (2.2, 4.8), (2.2, 5.5)]) {
        expect(nav.canStand(x, z, _r), isTrue, reason: '($x, $z)');
      }
      for (var x = -6.0; x <= 6.0; x += 0.2) {
        expect(nav.canStand(x, 5.5, _r), isTrue, reason: 'vỉa hè ($x, 5,5)');
      }
    });

    test('trong quầy, bàn, tủ kính, lò, tường, ngoài biên: không đứng được', () {
      expect(nav.canStand(0.2, -0.5, _r), isFalse); // quầy thu ngân
      expect(nav.canStand(3.6, -0.5, _r), isFalse); // bàn đóng hộp
      expect(nav.canStand(-1.6, -0.5, _r), isFalse); // tủ kính
      expect(nav.canStand(-2.0, -2.15, _r), isFalse); // bàn trộn
      expect(nav.canStand(-4.0, -3.5, _r), isFalse); // lò
      expect(nav.canStand(-4.9, 0, _r), isFalse); // sát tường trái
      expect(nav.canStand(0, -3.9, _r), isFalse); // sát tường sau
      expect(nav.canStand(0, 4.1, _r), isFalse); // trong tường trước
      expect(nav.canStand(-6.4, 5.5, _r), isFalse); // mép vỉa hè
      expect(nav.canStand(0, 6.6, _r), isFalse);
      expect(nav.canStand(20, 0, _r), isFalse);
      expect(nav.canStand(4.4, 1.5, _r), isFalse); // ổ Mochi
    });

    test('đèn thả (đáy 1,95 m) không chặn, bục flat đi được', () {
      // Dưới đèn thả ở (−3,8; 2,7) có bàn nên chọn chỗ gần bàn nhưng ngoài thân bàn: chỉ cần đèn không tạo vùng chặn lớn.
      expect(nav.canStand(-3.8, 1.75, _r), isTrue);
      expect(nav.canStand(-0.25, 0.4, _r), isTrue); // trên bục khách
      expect(nav.floorHeight(-0.25, 0.4), closeTo(Shop3dLayout.customerStepHeight, 1e-9));
      expect(nav.floorHeight(0, 2), 0);
    });

    test('vật mở rộng chỉ chặn khi đã sở hữu', () {
      expect(nav.canStand(-3.8, 2.7, 0.2), isFalse); // bàn khách
      expect(navBare.canStand(-3.8, 2.7, 0.2), isTrue);
      expect(nav.canStand(-2.7, -3.5, _r), isFalse); // lò 2
      expect(navBare.canStand(-2.7, -3.4, _r), isTrue);
    });

    test('khe cửa vừa đúng: rộng 1,1 m', () {
      expect(nav.canStand(3.6, 4.3, _r), isTrue);
      expect(nav.canStand(3.05 + _r - 0.01, 4.3, _r), isFalse);
      expect(nav.canStand(4.15 - _r + 0.01, 4.3, _r), isFalse);
      expect(nav.canStand(3.35, 4.3, _r), isTrue);
    });
  });

  group('slide: không xuyên vật cản', () {
    test('không xuyên quầy thu ngân từ phía khách', () {
      final e = _walk(nav, 0.2, 1.0, 0, -1, 3);
      expect(e.blocked, isTrue);
      expect(e.z, greaterThanOrEqualTo(-0.03 + _r - 1e-6));
      expect(nav.canStand(e.x, e.z, _r), isTrue);
    });

    test('không xuyên tủ kính, bàn đóng hộp, bàn trộn, lò, tường', () {
      var e = _walk(nav, -1.6, 1.0, 0, -1, 3);
      expect(e.z, greaterThanOrEqualTo(-0.05 + _r - 1e-6));
      e = _walk(nav, 3.6, 1.0, 0, -1, 3);
      expect(e.z, greaterThanOrEqualTo(-0.03 + _r - 1e-6));
      e = _walk(nav, -2.0, -1.45, 0, -1, 3); // từ sau quầy lên bàn trộn
      expect(e.z, greaterThanOrEqualTo(-1.8 + _r - 1e-6));
      e = _walk(nav, -4.0, -2.0, 0, -1, 3); // vào lò
      expect(e.z, greaterThanOrEqualTo(-3.1 + _r - 1e-6));
      e = _walk(nav, 0, 1.0, -1, 0, 8); // sang trái tới tường
      expect(e.x, greaterThanOrEqualTo(-5.0 + _r - 1e-6));
      e = _walk(nav, 0, 1.0, 1, 0, 8);
      expect(e.x, lessThanOrEqualTo(5.0 - _r + 1e-6));
      e = _walk(nav, 0, 1.0, 0, -1, 8); // lên quầy rồi nằm yên
      expect(nav.canStand(e.x, e.z, _r), isTrue);
    });

    test('một bước lớn (khung giật) không xuyên vật mỏng / tường', () {
      final m = nav.slide(0.2, 1.0, 0, -4, _r);
      expect(m.z, greaterThanOrEqualTo(-0.03 + _r - 1e-6));
      final w = nav.slide(0, 1.0, -9, 0, _r);
      expect(w.x, greaterThanOrEqualTo(-5.0 + _r - 1e-6));
    });

    test('trượt dọc theo vật cản: đi chéo vào quầy vẫn tiến theo trục còn lại', () {
      final e = _walk(nav, -0.6, 0.4, 1, -0.6, 2.0);
      expect(e.x, greaterThan(-0.6 + 1.0));
      expect(e.z, greaterThanOrEqualTo(-0.03 + _r - 1e-6));
    });

    test('mọi bước trượt ngẫu nhiên kết thúc ở chỗ đứng được (fuzz)', () {
      final rng = math.Random(7);
      final m = NavMove();
      var x = 0.0, z = 1.0;
      for (var i = 0; i < 6000; i++) {
        final dx = (rng.nextDouble() - 0.5) * 1.6, dz = (rng.nextDouble() - 0.5) * 1.6;
        nav.slide(x, z, dx, dz, _r, out: m);
        expect(nav.canStand(m.x, m.z, _r), isTrue, reason: 'bước $i từ ($x,$z) +($dx,$dz) → (${m.x},${m.z})');
        x = m.x;
        z = m.z;
        if (i % 500 == 499) {
          x = 0;
          z = 1;
        }
      }
    });
  });

  group('đi qua lối hẹp', () {
    test('qua khe cửa ra vỉa hè và ngược lại', () {
      final out = _walk(nav, 3.6, 3.2, 0, 1, 3.5);
      expect(out.z, greaterThan(6.0));
      expect(out.x, closeTo(3.6, 1e-6));
      final back = _walk(nav, 3.6, 6.0, 0, -1, 3.5);
      expect(back.z, lessThan(3.0));
    });

    test('tường cạnh cửa chặn', () {
      final e = _walk(nav, 2.0, 3.0, 0, 1, 3);
      expect(e.z, lessThanOrEqualTo(4.0 - _r + 1e-6));
    });

    test('lối nhân viên qua quầy (x ∈ [−4,6; −2,8])', () {
      final e = _walk(nav, -3.7, -1.0, 0, 1, 3);
      expect(e.z, greaterThan(1.5));
      expect(e.x, closeTo(-3.7, 1e-6));
      final back = _walk(nav, -3.7, 1.5, 0, -1, 3);
      expect(back.z, lessThan(-0.5));
    });
  });

  group('NPC là hình tròn: đi vòng', () {
    test('đi vòng qua NPC giữa vỉa hè', () {
      final npc = [NavCircle(0, 5.5, 0.27, id: 'npc')];
      final e = _walk(nav, -2, 5.55, 1, 0, 6, others: npc);
      expect(e.x, greaterThan(1.0));
      final dx = e.x - 0, dz = e.z - 5.5;
      expect(math.sqrt(dx * dx + dz * dz), greaterThanOrEqualTo(0.54 - 1e-6));
    });

    test('không đi xuyên NPC khi đi thẳng', () {
      final npc = [NavCircle(0, 5.5, 0.27)];
      final m = NavMove();
      var x = -2.0;
      for (var i = 0; i < 300; i++) {
        nav.slide(x, 5.5, 0.02, 0, _r, out: m, others: npc);
        x = m.x;
        final d = math.sqrt(x * x + (m.z - 5.5) * (m.z - 5.5));
        expect(d, greaterThanOrEqualTo(0.54 - 1e-6));
      }
    });
  });

  group('nearestFree', () {
    test('đang đứng trong quầy: dời ra ô trống gần nhất', () {
      final p = nav.nearestFree(0.2, -0.5, _r)!;
      expect(nav.canStand(p.x, p.z, _r), isTrue);
      expect(math.sqrt(math.pow(p.x - 0.2, 2) + math.pow(p.z + 0.5, 2)), lessThan(1.0));
    });

    test('đang ở chỗ trống thì giữ nguyên; ngoài biên thì kéo về trong', () {
      final p = nav.nearestFree(0, 1.2, _r)!;
      expect(p.x, 0);
      expect(p.z, 1.2);
      final q = nav.nearestFree(-5.0, 0.0, _r)!;
      expect(nav.canStand(q.x, q.z, _r), isTrue);
      expect(nav.nearestFree(50, 50, _r, maxDist: 2), isNull);
    });
  });

  group('findPath (A*)', () {
    /// Mọi đoạn của đường đi (kể từ điểm xuất phát) đi được với bán kính [_r].
    void expectWalkable(Shop3dNav n, double fx, double fz, List<NavPoint> path) {
      var px = fx, pz = fz;
      for (final p in path) {
        final len = math.sqrt(math.pow(p.x - px, 2) + math.pow(p.z - pz, 2));
        final steps = math.max(1, (len / 0.05).ceil());
        for (var i = 1; i <= steps; i++) {
          final t = i / steps;
          final x = px + (p.x - px) * t, z = pz + (p.z - pz) * t;
          expect(n.canStand(x, z, _r), isTrue, reason: 'đoạn tới $p: ($x, $z) bị chặn');
        }
        px = p.x;
        pz = p.z;
      }
    }

    for (final owned in [Shop3dRequires.all, const <String>{}]) {
      test('từ staffMixerFar ra tâm sự kiện (2,2; 5,5) — owned=${owned.length}', () {
        final n = Shop3dNav.fromLayout(owned: owned);
        const s = Shop3dLayout.staffMixerFar;
        final path = n.findPath(s.x, s.z, 2.2, 5.5);
        expect(path, isNotNull);
        expect(path!.last.x, closeTo(2.2, 1e-6));
        expect(path.last.z, closeTo(5.5, 1e-6));
        expectWalkable(n, s.x, s.z, path);
        // Phải đi qua khe cửa.
        var crossed = false;
        var px = s.x, pz = s.z;
        for (final p in path) {
          for (var i = 0; i <= 20; i++) {
            final t = i / 20;
            final x = px + (p.x - px) * t, z = pz + (p.z - pz) * t;
            if (z >= 4.0 && z <= 4.45 && x >= 3.05 && x <= 4.15) crossed = true;
          }
          px = p.x;
          pz = p.z;
        }
        expect(crossed, isTrue);
      });
    }

    test('đường thẳng được làm thẳng: ít điểm trung gian', () {
      final path = nav.findPath(-1, 1.2, 1, 1.2)!;
      expect(path.length, 1);
    });

    test('đi từ chỗ nhân viên sau quầy ra hàng chờ và về bếp', () {
      const a = Shop3dLayout.staffCashier;
      final path = nav.findPath(a.x, a.z, 3.5, 2.55)!;
      expectWalkable(nav, a.x, a.z, path);
      final back = nav.findPath(3.5, 2.55, Shop3dLayout.staffOven1.x, Shop3dLayout.staffOven1.z)!;
      expectWalkable(nav, 3.5, 2.55, back);
    });

    test('đích nằm trong vật cản: dời tới ô trống gần nhất', () {
      final path = nav.findPath(0, 1.2, 0.2, -0.5)!;
      expect(nav.canStand(path.last.x, path.last.z, _r), isTrue);
    });

    test('đích trùng điểm đi: một điểm', () {
      final path = nav.findPath(0, 1.2, 0, 1.2)!;
      expect(path.length, 1);
    });

    test('không có đường: null', () {
      final split = Shop3dNav([const NavBox(-5, 5, 0, 0.4)]);
      expect(split.findPath(0, -2, 0, 2), isNull);
    });

    test('từ chỗ bị kẹt vẫn tìm được đường', () {
      final path = nav.findPath(0.2, -0.5, 3.6, 5.0);
      expect(path, isNotNull);
    });
  });
}
