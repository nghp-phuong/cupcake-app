import 'package:flutter_test/flutter_test.dart';
import 'package:sugarleaf_bakery/game/shop3d/interact/pilot_rules.dart';
import 'package:sugarleaf_bakery/game/shop3d/interact/shop3d_items.dart';

ShopItem _item(String id) => ItemBoard.defaultItems().firstWhere((i) => i.id == id);

ShopItem _held(String id) => _item(id)
  ..phase = ItemPhase.held
  ..holderId = 'mai';

const _event = PilotEventInfo('lastCake', 2.2, 5.5, canIntervene: true);

PilotSnapshot _snap({
  PilotRole role = PilotRole.mai,
  double x = 0,
  double z = 1.2,
  ShopItem? held,
  List<PilotGuest> guests = const [],
  List<ShopItem> items = const [],
  double? mochiX,
  double? mochiZ,
  PilotEventInfo? event,
  String? placeSurfaceId,
}) =>
    PilotSnapshot(
      role: role,
      x: x,
      z: z,
      held: held,
      guests: guests,
      items: items,
      mochiX: mochiX,
      mochiZ: mochiZ,
      event: event,
      placeSurfaceId: placeSurfaceId,
    );

void main() {
  group('vai nhân vật', () {
    test('ofId', () {
      expect(PilotRole.ofId('mai'), PilotRole.mai);
      expect(PilotRole.ofId('mai_fest'), PilotRole.mai);
      expect(PilotRole.ofId('staff_nora'), PilotRole.nora);
      expect(PilotRole.ofId('staff_nora_fest'), PilotRole.nora);
      expect(PilotRole.ofId('staff_bao'), PilotRole.other);
      expect(PilotRole.ofId('staff_theo'), PilotRole.other);
      expect(PilotRole.ofId('staff_ami'), PilotRole.other);
      expect(PilotRole.ofId('staff_hanh'), PilotRole.other);
      expect(PilotRole.mai.canHandle && PilotRole.nora.canHandle, isTrue);
      expect(PilotRole.other.canHandle, isFalse);
    });
  });

  group('nút A — dòng 1: Can ngăn', () {
    test('Mai cách tâm sự kiện ≤ 1,6 m và đang cãi', () {
      final d = PilotRules.decideA(_snap(x: 2.2, z: 4.0, event: _event)); // cách 1,5 m
      expect(d, const PilotDecision(PilotAction.intervene, 'lastCake'));
      expect(d.enabled, isTrue);
    });

    test('xa hơn 1,6 m, hoặc không còn cãi, hoặc không phải Mai: không can ngăn', () {
      expect(PilotRules.decideA(_snap(x: 2.2, z: 3.8, event: _event)).action, PilotAction.none);
      const calm = PilotEventInfo('lastCake', 2.2, 5.5, canIntervene: false);
      expect(PilotRules.decideA(_snap(x: 2.2, z: 5.0, event: calm)).action, PilotAction.none);
      expect(PilotRules.decideA(_snap(role: PilotRole.nora, x: 2.2, z: 5.0, event: _event)).action, PilotAction.none);
    });

    test('ưu tiên hơn mọi dòng khác (đang cầm hộp bánh cạnh khách)', () {
      final d = PilotRules.decideA(_snap(
          x: 2.2, z: 5.0, event: _event, held: _held('cakeBox0'), guests: const [PilotGuest('g', 2.2, 5.5)]));
      expect(d.action, PilotAction.intervene);
    });
  });

  group('nút A — dòng 2: Mời bánh', () {
    test('cầm hộp bánh, khách không đi cách ≤ 2,0 m (chọn khách gần nhất)', () {
      final d = PilotRules.decideA(_snap(held: _held('cakeBox0'), guests: const [
        PilotGuest('far', 0, 3.0), // 1,8 m
        PilotGuest('near', 1.0, 1.2), // 1,0 m
      ]));
      expect(d, const PilotDecision(PilotAction.offerCake, 'near'));
    });

    test('khách đang đi hoặc xa hơn 2,0 m: không mời', () {
      final h = _held('cakeBox0');
      expect(PilotRules.decideA(_snap(held: h, guests: const [PilotGuest('w', 0.5, 1.2, walking: true)])).action,
          PilotAction.putDown);
      expect(PilotRules.decideA(_snap(held: h, guests: const [PilotGuest('far', 0, 3.3)])).action, PilotAction.putDown);
    });

    test('thắng dòng 3 (đặt lên) khi có khách; cầm cuộn len thì không mời', () {
      expect(
          PilotRules.decideA(_snap(
                  held: _held('cakeBox0'), placeSurfaceId: 'packingCounter', guests: const [PilotGuest('g', 0, 2)]))
              .action,
          PilotAction.offerCake);
      expect(PilotRules.decideA(_snap(held: _held('yarn'), guests: const [PilotGuest('g', 0, 2)])).action,
          PilotAction.putDown);
    });

    test('nhân viên khác (Bảo) bỏ qua dòng 2', () {
      final d = PilotRules.decideA(
          _snap(role: PilotRole.other, held: _held('cakeBox0'), guests: const [PilotGuest('g', 0.5, 1.2)]));
      expect(d.action, PilotAction.talk);
    });
  });

  group('nút A — dòng 3: Đặt lên', () {
    test('đang cầm đồ và hướng vào mặt đặt được', () {
      final d = PilotRules.decideA(_snap(held: _held('flour'), placeSurfaceId: 'mixingIsland'));
      expect(d, const PilotDecision(PilotAction.placeOn, 'mixingIsland'));
    });

    test('không hướng vào mặt nào thì rơi xuống dòng 4', () {
      expect(PilotRules.decideA(_snap(held: _held('flour'))).action, PilotAction.putDown);
    });

    test('tay trống thì không có "đặt lên"', () {
      expect(PilotRules.decideA(_snap(placeSurfaceId: 'mixingIsland')).action, PilotAction.none);
    });
  });

  group('nút A — dòng 4: Đặt xuống', () {
    test('đang cầm đồ, không có gì khác', () {
      expect(PilotRules.decideA(_snap(held: _held('yarn'))), const PilotDecision(PilotAction.putDown, 'yarn'));
    });

    test('thắng dòng nói chuyện / vuốt ve khi đang cầm', () {
      final d = PilotRules.decideA(
          _snap(held: _held('yarn'), guests: const [PilotGuest('g', 0.5, 1.2)], mochiX: 0.3, mochiZ: 1.2));
      expect(d.action, PilotAction.putDown);
    });
  });

  group('nút A — dòng 5: Nhặt', () {
    test('Mai và Nora, tay trống, vật cách ≤ 0,9 m', () {
      final yarn = _item('yarn');
      for (final role in [PilotRole.mai, PilotRole.nora]) {
        final d = PilotRules.decideA(_snap(role: role, x: 3.6, z: 1.6, items: [yarn]));
        expect(d, const PilotDecision(PilotAction.pickUp, 'yarn'));
      }
    });

    test('chọn vật gần nhất', () {
      final c0 = _item('cakeBox0'), c1 = _item('cakeBox1');
      final d = PilotRules.decideA(_snap(x: 3.9, z: -1.2, items: [c0, c1]));
      expect(d.targetId, 'cakeBox1');
    });

    test('xa hơn 0,9 m, vật đang bay / đã ẩn, hoặc sai phía quầy: không nhặt', () {
      final yarn = _item('yarn');
      expect(PilotRules.decideA(_snap(x: 2.9, z: 1.6, items: [yarn])).action, PilotAction.none);
      yarn.phase = ItemPhase.flying;
      expect(PilotRules.decideA(_snap(x: 3.9, z: 1.6, items: [yarn])).action, PilotAction.none);
      final cake = _item('cakeBox0');
      expect(PilotRules.decideA(_snap(x: 3.55, z: 0.3, items: [cake])).action, PilotAction.none); // phía khách
    });

    test('Bảo, Theo, Ami, Hạnh bỏ qua dòng 5', () {
      final d = PilotRules.decideA(_snap(role: PilotRole.other, x: 3.6, z: 1.6, items: [_item('yarn')]));
      expect(d.action, PilotAction.none);
    });

    test('thắng dòng nói chuyện', () {
      final d = PilotRules.decideA(
          _snap(x: 3.6, z: 1.6, items: [_item('yarn')], guests: const [PilotGuest('g', 3.6, 2.5)]));
      expect(d.action, PilotAction.pickUp);
    });
  });

  group('nút A — dòng 6: Nói chuyện', () {
    test('khách không đi cách ≤ 2,2 m', () {
      final d = PilotRules.decideA(_snap(guests: const [PilotGuest('g', 0, 3.3)])); // 2,1 m
      expect(d, const PilotDecision(PilotAction.talk, 'g'));
    });

    test('đang đi hoặc xa hơn 2,2 m thì không', () {
      expect(PilotRules.decideA(_snap(guests: const [PilotGuest('g', 0, 3.5)])).action, PilotAction.none);
      expect(PilotRules.decideA(_snap(guests: const [PilotGuest('g', 0, 2.0, walking: true)])).action,
          PilotAction.none);
    });

    test('nhân viên nào cũng nói chuyện được; chọn khách gần nhất', () {
      final d = PilotRules.decideA(_snap(
          role: PilotRole.other, guests: const [PilotGuest('far', 0, 3.0), PilotGuest('near', 0.4, 1.2)]));
      expect(d, const PilotDecision(PilotAction.talk, 'near'));
    });

    test('thắng dòng vuốt ve', () {
      final d = PilotRules.decideA(_snap(guests: const [PilotGuest('g', 0, 2.0)], mochiX: 0.3, mochiZ: 1.2));
      expect(d.action, PilotAction.talk);
    });
  });

  group('nút A — dòng 7: Vuốt ve Mochi', () {
    test('Mochi cách ≤ 1,0 m, tay trống', () {
      expect(PilotRules.decideA(_snap(mochiX: 0.8, mochiZ: 1.2)), const PilotDecision(PilotAction.petMochi, 'mochi'));
      expect(PilotRules.decideA(_snap(role: PilotRole.other, mochiX: 0.5, mochiZ: 1.2)).action, PilotAction.petMochi);
    });

    test('xa hơn 1,0 m hoặc không có Mochi thì không', () {
      expect(PilotRules.decideA(_snap(mochiX: 1.2, mochiZ: 1.2)).action, PilotAction.none);
      expect(PilotRules.decideA(_snap()).action, PilotAction.none);
    });

    test('đang cầm đồ thì không vuốt', () {
      expect(PilotRules.decideA(_snap(held: _held('yarn'), mochiX: 0.2, mochiZ: 1.2)).action, PilotAction.putDown);
    });
  });

  group('nút A — dòng 8: mờ', () {
    test('không thoả dòng nào', () {
      final d = PilotRules.decideA(_snap());
      expect(d, PilotDecision.none);
      expect(d.enabled, isFalse);
      expect(d.targetId, isNull);
    });
  });

  group('nút B và tốc độ', () {
    test('B chỉ hiện khi Mai / Nora cầm vật ném được (cuộn len)', () {
      expect(PilotRules.throwVisible(PilotRole.mai, _held('yarn')), isTrue);
      expect(PilotRules.throwVisible(PilotRole.nora, _held('yarn')), isTrue);
      expect(PilotRules.throwVisible(PilotRole.other, _held('yarn')), isFalse);
      expect(PilotRules.throwVisible(PilotRole.mai, null), isFalse);
      expect(PilotRules.throwVisible(PilotRole.mai, _held('cakeBox0')), isFalse);
      expect(PilotRules.throwVisible(PilotRole.mai, _held('flour')), isFalse);
    });

    test('bấm ném khi cầm hộp bánh → nhắc "Bánh phải mời tận tay chứ!"', () {
      expect(PilotRules.checkThrow(PilotRole.mai, _held('yarn')), ThrowCheck.ok);
      expect(PilotRules.checkThrow(PilotRole.mai, _held('cakeBox1')), ThrowCheck.cakeNotThrowable);
      expect(PilotRules.checkThrow(PilotRole.mai, _held('flour')), ThrowCheck.nothing);
      expect(PilotRules.checkThrow(PilotRole.mai, null), ThrowCheck.nothing);
      expect(PilotRules.checkThrow(PilotRole.other, _held('yarn')), ThrowCheck.nothing);
    });

    test('bao bột: 0,7× và không chạy', () {
      expect(PilotRules.speedFactor(_held('flour')), 0.7);
      expect(PilotRules.canRun(_held('flour')), isFalse);
      expect(PilotRules.speedFactor(null), 1.0);
      expect(PilotRules.canRun(_held('yarn')), isTrue);
    });
  });

  group('hồi chiêu', () {
    test('mời bánh: mỗi khách 1 lần / 60 s', () {
      final c = PilotCooldowns();
      expect(c.offer('g1', 0), OfferResult.thanks);
      expect(c.offer('g1', 30), OfferResult.full);
      expect(c.offer('g1', 59.9), OfferResult.full);
      expect(c.offer('g2', 30), OfferResult.thanks); // khách khác không bị ảnh hưởng
      expect(c.offer('g1', 60), OfferResult.thanks);
      expect(PilotCooldowns.offerHearts, 1);
      expect(PilotCooldowns.offerCoins, 5);
    });

    test('vẫy chào: hồi chiêu 8 s, khách không đi trong 3 m vẫy lại, ♥ lần đầu mỗi khách', () {
      final c = PilotCooldowns();
      const guests = [
        PilotGuest('a', 1, 1.2),
        PilotGuest('b', 2.5, 1.2),
        PilotGuest('walker', 0.5, 1.2, walking: true),
        PilotGuest('far', 5, 1.2),
      ];
      final w1 = c.wave(0, 0, 1.2, guests)!;
      expect(w1.reacting, ['a', 'b']);
      expect(w1.hearts, 2);
      expect(c.wave(7.9, 0, 1.2, guests), isNull);
      expect(c.waveReady(7.9), isFalse);
      expect(c.waveReady(8), isTrue);
      final w2 = c.wave(8, 0, 1.2, guests)!;
      expect(w2.reacting, ['a', 'b']);
      expect(w2.hearts, 0); // đã vẫy rồi
      final w3 = c.wave(16, 0, 1.2, const [PilotGuest('c', 0, 2)])!;
      expect(w3.hearts, 1);
    });

    test('vuốt ve: ♥ chỉ ở lần đầu mỗi phiên', () {
      final c = PilotCooldowns();
      expect(c.pet(), isTrue);
      expect(c.pet(), isFalse);
      c.reset();
      expect(c.pet(), isTrue);
    });
  });
}
