import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:sugarleaf_bakery/game/shop3d/chibi/chibi_actor.dart';
import 'package:sugarleaf_bakery/game/shop3d/chibi/chibi_cast.dart';
import 'package:sugarleaf_bakery/game/shop3d/chibi/chibi_characters.dart';
import 'package:sugarleaf_bakery/game/shop3d/chibi/chibi_regulars.dart';
import 'package:sugarleaf_bakery/game/shop3d/chibi/chibi_rig.dart';
import 'package:sugarleaf_bakery/game/shop3d/chibi/chibi_sizes.dart';
import 'package:sugarleaf_bakery/game/shop3d/interact/pilot.dart';
import 'package:sugarleaf_bakery/game/shop3d/interact/pilot_rules.dart';
import 'package:sugarleaf_bakery/game/shop3d/shop3d_layout.dart';
import 'package:sugarleaf_bakery/game/shop3d/talk/quarrel_director.dart';
import 'package:sugarleaf_bakery/l10n/gen/app_localizations_en.dart';

/// `Shop3dPilot.say` và `Shop3dPilot.locked` (G1, ca bán). Thế giới giả như pilot_test (không thermion).

const _dt = 1 / 60;
const _owned = {Shop3dRequires.cafeTables};

class _World implements Shop3dPilotWorld {
  _World(List<ChibiActor> actors) : director = ChibiDirector(actors);

  @override
  final ChibiDirector director;

  @override
  Set<String> get owned => _owned;

  final _models = <String, ChibiModel>{};

  @override
  ChibiModel? readyModel(String id) => _models[id];

  @override
  void prepareModels(List<String> ids) {
    for (final id in ids) {
      _models.putIfAbsent(id, () => ChibiSizes.fit(ChibiRegulars.build(id)));
    }
  }

  @override
  void addActor(ChibiActor a) => director.actors.add(a);

  @override
  void removeActor(ChibiActor a) => director.actors.remove(a);
}

void _step(Shop3dPilot p, _World w, double seconds) {
  for (var t = 0.0; t < seconds; t += _dt) {
    p.update(_dt);
    w.director.update(_dt, _owned);
    p.lateUpdate();
  }
}

void main() {
  final models = {for (final id in ChibiCharacters.allIds) id: ChibiCharacters.build(id)};

  (Shop3dPilot, _World) make({QuarrelDirector? quarrel}) {
    final w = _World(ChibiCast.build(models: models));
    return (Shop3dPilot(w, rng: math.Random(7), events: false, quarrel: quarrel), w);
  }

  ChibiActor actor(_World w, String id) => w.director.actors.firstWhere((a) => a.id == id);

  group('say', () {
    test('hiện bong bóng chữ trên đầu nhân vật, thay bong bóng cũ, hết hạn thì biến mất', () {
      final (p, w) = make();
      final rev = p.bubblesRevision.value;
      p.say('hoa', 'Một cupcake nhé!');
      expect(p.bubblesRevision.value, greaterThan(rev));
      expect(p.bubbles.length, 1);
      final b = p.bubbles.single;
      expect(b.actorId, 'hoa');
      expect(b.text(AppLocalizationsEn()), 'Một cupcake nhé!');
      expect(b.kind, PilotBubbleKind.speech);
      // Người khác thêm bong bóng; cùng người thì thay.
      p.say('linh', 'Xin chào', duration: 5);
      p.say('hoa', 'Cảm ơn!', duration: 1);
      expect(p.bubbles.length, 2);
      expect(p.bubbles.firstWhere((x) => x.actorId == 'hoa').text(AppLocalizationsEn()), 'Cảm ơn!');
      _step(p, w, 1.5);
      expect(p.bubbles.map((x) => x.actorId), ['linh']);
      _step(p, w, 4);
      expect(p.bubbles, isEmpty);
    });

    test('mặc định 2,4 s; kind tuỳ chọn', () {
      final (p, w) = make();
      p.say('mai', '!', kind: PilotBubbleKind.exclaim);
      expect(p.bubbles.single.kind, PilotBubbleKind.exclaim);
      expect(p.bubbles.single.until, closeTo(p.now + 2.4, 1e-9));
      _step(p, w, 2.0);
      expect(p.bubbles, isNotEmpty);
      _step(p, w, 0.5);
      expect(p.bubbles, isEmpty);
    });
  });

  group('locked', () {
    test('khoá: ẩn joystick / cụm nút; mở khoá thì hiện lại', () {
      final (p, _) = make();
      expect(p.locked, isFalse);
      expect(p.control('mai'), isTrue);
      expect(p.hud.value.controlsVisible, isTrue);
      p.locked = true;
      expect(p.locked, isTrue);
      expect(p.hud.value.locked, isTrue);
      expect(p.hud.value.pilotId, 'mai');
      expect(p.hud.value.controlsVisible, isFalse);
      p.locked = false;
      expect(p.hud.value.controlsVisible, isTrue);
    });

    test('khoá khi chưa điều khiển ai: cờ vẫn lưu', () {
      final (p, _) = make();
      p.locked = true;
      expect(p.hud.value.locked, isTrue);
      expect(p.hud.value.controlsVisible, isFalse);
    });

    test('cần điều khiển bị bỏ qua (kể cả cần đang đẩy dở lúc khoá)', () {
      final (p, w) = make();
      final mai = actor(w, 'mai');
      p.control('mai');
      p.setStick(1, 0, active: true);
      _step(p, w, 0.5);
      final moved = mai.pose.x;
      expect(moved, isNot(closeTo(-1.3, 1e-6)));
      p.locked = true;
      final x = mai.pose.x, z = mai.pose.z;
      _step(p, w, 1);
      expect(mai.pose.x, x);
      expect(mai.pose.z, z);
      // Đẩy cần mới khi đang khoá: vẫn đứng yên.
      p.setStick(-1, 0, running: true, active: true);
      _step(p, w, 1);
      expect(mai.pose.x, x);
      expect(mai.pose.z, z);
      // Mở khoá: cần mới có tác dụng, cần cũ không "dội lại".
      p.locked = false;
      _step(p, w, 0.5);
      expect(mai.pose.x, x);
      p.setStick(-1, 0, active: true);
      _step(p, w, 0.5);
      expect(mai.pose.x, lessThan(x - 0.2));
    });

    test('nút A, Ném, Vẫy bị bỏ qua khi khoá', () {
      final (p, w) = make();
      final mai = actor(w, 'mai');
      p.control('mai');
      // Cạnh hộp bánh: A = nhặt.
      mai.driveMove(3.6, -1.32, null);
      mai.pose.yaw = math.pi;
      _step(p, w, 0.3);
      expect(p.decision.action, PilotAction.pickUp);
      p.locked = true;
      p.pressA();
      expect(p.items.heldBy('mai'), isNull);
      p.wave();
      expect(p.waveCooldown.value, 0);
      expect(mai.performing, isNull);
      p.throwTap();
      p.throwCharged(1);
      p.throwHeld(1);
      expect(mai.performing, isNull);
      // Mở khoá: A nhặt được.
      p.locked = false;
      _step(p, w, 0.3);
      p.pressA();
      expect(p.items.heldBy('mai'), isNotNull);
    });

    test('chạm vào nhân vật (nói chuyện, đổi người điều khiển) bị bỏ qua khi khoá', () {
      final (p, w) = make();
      final mai = actor(w, 'mai');
      p.control('mai');
      final hoa = actor(w, 'hoa');
      _step(p, w, 1);
      // Mai đứng cạnh ông Hòa đang ngồi.
      mai.driveMove(hoa.pose.x, hoa.pose.z - 1.0, null);
      expect(hoa.isSeated, isTrue);
      p.locked = true;
      expect(p.tapGuest('hoa'), isFalse);
      expect(p.startTalk('mai', 'hoa'), isFalse);
      p.talkFrom('mai');
      expect(p.pick.value, isNull);
      expect(p.takeNotices(), isEmpty);
      expect(p.dialogueOpen, isFalse);
      // Chạm nhân viên khác: không đổi người điều khiển.
      expect(p.control('staff_nora'), isFalse);
      expect(p.pilotId, 'mai');
      // Mở khoá: nói chuyện được.
      p.locked = false;
      expect(p.tapGuest('hoa'), isTrue);
    });

    test('khoá thì sự kiện cãi nhau không tự bắt đầu', () {
      final quarrel = QuarrelDirector(rng: math.Random(1), firstDelay: 2, firstJitter: 0);
      final (p, w) = make(quarrel: quarrel);
      p.control('mai');
      p.locked = true;
      _step(p, w, 6);
      expect(quarrel.active, isFalse);
      p.locked = false;
      _step(p, w, 1);
      expect(quarrel.active, isTrue);
    });
  });
}
