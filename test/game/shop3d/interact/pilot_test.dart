import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:sugarleaf_bakery/game/shop3d/chibi/chibi_actor.dart';
import 'package:sugarleaf_bakery/game/shop3d/chibi/chibi_cast.dart';
import 'package:sugarleaf_bakery/game/shop3d/chibi/chibi_characters.dart';
import 'package:sugarleaf_bakery/game/shop3d/chibi/chibi_regulars.dart';
import 'package:sugarleaf_bakery/game/shop3d/chibi/chibi_rig.dart';
import 'package:sugarleaf_bakery/game/shop3d/chibi/chibi_sizes.dart';
import 'package:sugarleaf_bakery/game/shop3d/interact/item_meshes.dart';
import 'package:sugarleaf_bakery/game/shop3d/interact/pilot.dart';
import 'package:sugarleaf_bakery/game/shop3d/interact/pilot_rules.dart';
import 'package:sugarleaf_bakery/game/shop3d/interact/shop3d_items.dart';
import 'package:sugarleaf_bakery/game/shop3d/shop3d_layout.dart';
import 'package:sugarleaf_bakery/game/shop3d/talk/quarrel_director.dart';
import 'package:sugarleaf_bakery/l10n/gen/app_localizations_en.dart';
import 'package:sugarleaf_bakery/l10n/gen/app_localizations_vi.dart';

/// Bộ điều phối tương tác (V3, docs/v3/interaction-spec.md) — Dart thuần, thế giới giả (không thermion).

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

void _step(Shop3dPilot p, _World w, double seconds, {bool Function()? until}) {
  for (var t = 0.0; t < seconds; t += _dt) {
    p.update(_dt);
    w.director.update(_dt, _owned);
    p.lateUpdate();
    if (until != null && until()) return;
  }
}

/// Chạy hết hội thoại đang mở: chọn lựa chọn [choice] ở mọi lần hỏi.
void _finishTalk(Shop3dPilot p, _World w, {int choice = 0}) {
  for (var guard = 0; guard < 200 && p.talk.value != null; guard++) {
    final line = p.talk.value!;
    if (line.choices.isNotEmpty) {
      p.talkChoose(math.min(choice, line.choices.length - 1));
    } else {
      p.talkNext();
    }
    _step(p, w, 0.05);
  }
}

void main() {
  final models = {for (final id in ChibiCharacters.allIds) id: ChibiCharacters.build(id)};

  (Shop3dPilot, _World) make({bool mochi = false, QuarrelDirector? quarrel}) {
    final w = _World(ChibiCast.build(models: models, mochi: mochi));
    final p = Shop3dPilot(w, rng: math.Random(7), events: false, quarrel: quarrel);
    return (p, w);
  }

  ChibiActor actor(_World w, String id) => w.director.actors.firstWhere((a) => a.id == id);

  /// Dời nhân vật đang lái tới (x, z) (giả lập đã đi tới đó).
  void teleport(ChibiActor a, double x, double z, {double? yaw}) {
    a.driveMove(x, z, yaw);
    if (yaw != null) a.pose.yaw = yaw;
  }

  group('hàm thuần', () {
    test('hướng đi theo camera: jx·right + (−jy)·forward', () {
      // yaw 0: camera ở +z nhìn về −z → đẩy cần lên = đi về −z; sang phải = +x.
      var (x, z) = Shop3dPilot.stickToWorld(0, -1, 0);
      expect(x, closeTo(0, 1e-9));
      expect(z, closeTo(-1, 1e-9));
      (x, z) = Shop3dPilot.stickToWorld(1, 0, 0);
      expect(x, closeTo(1, 1e-9));
      expect(z, closeTo(0, 1e-9));
      // yaw π/2: camera ở +x nhìn về −x → đẩy lên = đi về −x.
      (x, z) = Shop3dPilot.stickToWorld(0, -1, math.pi / 2);
      expect(x, closeTo(-1, 1e-9));
      expect(z, closeTo(0, 1e-9));
    });

    test('tốc độ: vùng chết, đi 0,35–1,0, chạy 1,6, bao bột 0,7 không chạy', () {
      expect(Shop3dPilot.speedFactor(0.1), 0);
      expect(Shop3dPilot.speedFactor(0.15), closeTo(0.35, 1e-9));
      expect(Shop3dPilot.speedFactor(0.8), closeTo(1.0, 1e-9));
      expect(Shop3dPilot.speedFactor(1.0, running: true), closeTo(1.6, 1e-9));
      expect(Shop3dPilot.speedFactor(1.0, running: true, canRun: false, carryFactor: 0.7), closeTo(0.7, 1e-9));
    });

    test('nhân viên: mai, staff_*, *_fest', () {
      for (final id in ['mai', 'staff_nora', 'staff_bao', 'staff_theo', 'staff_nora_fest']) {
        expect(Shop3dPilot.isStaffId(id), isTrue, reason: id);
      }
      for (final id in ['linh', 'hoa', 'kenji', 'vip_00', 'mochi', 'regular_04']) {
        expect(Shop3dPilot.isStaffId(id), isFalse, reason: id);
      }
    });

    test('chuỗi phần thưởng (en / vi)', () {
      expect(pilotRewardText(AppLocalizationsEn(), 2, 10), contains('2'));
      expect(pilotRewardText(AppLocalizationsVi(), 1, 0), isNot(contains('·')));
      expect(pilotRewardText(AppLocalizationsVi(), 0, 0), isEmpty);
    });

    test('lưới 3 vật: có tam giác, đáy ở y = 0, vừa bán kính va chạm', () {
      for (final k in ItemKind.values) {
        final m = Shop3dItemMeshes.of(k);
        expect(m.triangleCount, greaterThan(20), reason: '$k');
        expect(m.minY, closeTo(0, 0.03), reason: '$k');
        final r = ItemSpec.of(k).radius;
        expect(m.maxX, lessThan(r * 1.6), reason: '$k');
      }
    });
  });

  group('điều khiển', () {
    test('Mai đi bằng joystick: không bao giờ vào ô chặn, quay mặt theo hướng đi, chạy nhanh hơn đi', () {
      final (p, w) = make();
      final mai = actor(w, 'mai');
      expect(p.control('mai'), isTrue);
      expect(p.hud.value.pilotId, 'mai');
      expect(mai.driven, isTrue);
      final r = math.min(mai.model.radius, Shop3dPilot.maxNavRadius);
      final x0 = mai.pose.x;
      // Đẩy sang phải (yaw camera 0 → +x) 2 s.
      p.setStick(0.7, 0, active: true);
      for (var t = 0.0; t < 2; t += _dt) {
        _step(p, w, _dt);
        expect(p.nav.canStand(mai.pose.x, mai.pose.z, r - 1e-6), isTrue, reason: '(${mai.pose.x}, ${mai.pose.z})');
      }
      final walked = mai.pose.x - x0;
      expect(walked, greaterThan(0.8));
      expect(mai.pose.yaw, closeTo(math.pi / 2, 0.15));
      // Đi lung tung 12 s theo nhiều hướng: vẫn không xuyên vật.
      final rng = math.Random(3);
      for (var i = 0; i < 24; i++) {
        p.setStick(rng.nextDouble() * 2 - 1, rng.nextDouble() * 2 - 1, running: rng.nextBool(), active: true);
        for (var t = 0.0; t < 0.5; t += _dt) {
          _step(p, w, _dt);
          expect(p.nav.canStand(mai.pose.x, mai.pose.z, r - 1e-6), isTrue);
        }
      }
      // Chạy nhanh hơn đi.
      final (p2, w2) = make();
      final mai2 = actor(w2, 'mai');
      p2.control('mai');
      p2.setStick(1, 0, running: true, active: true);
      final xr = mai2.pose.x;
      _step(p2, w2, 1);
      expect(mai2.pose.x - xr, greaterThan(walked / 2 * 1.3));
    });

    test('thôi điều khiển: đi A* về kịch bản rồi chạy tiếp; chỉ một người được điều khiển', () {
      final (p, w) = make();
      final mai = actor(w, 'mai'), nora = actor(w, 'staff_nora');
      p.control('mai');
      p.setStick(1, 0, active: true);
      _step(p, w, 1.5);
      p.setStick(0, 0);
      p.control('staff_nora');
      expect(mai.driven, isFalse);
      expect(nora.driven, isTrue);
      expect(mai.routing, isTrue, reason: 'Mai tự đi về kịch bản');
      _step(p, w, 15, until: () => !mai.routing);
      expect(mai.routing, isFalse);
      final step0 = mai.stepIndex;
      _step(p, w, 15);
      expect(mai.stepIndex != step0 || mai.isWalking, isTrue, reason: 'kịch bản chạy tiếp');
      expect(mai.pose.z, lessThan(-1.2), reason: 'Mai vẫn ở trong bếp');
      p.release();
      expect(p.hud.value.pilotId, isNull);
      expect(nora.driven, isFalse);
    });

    test('nhặt hộp bánh (phía nhân viên), thôi điều khiển thì đặt xuống trước chân', () {
      final (p, w) = make();
      final mai = actor(w, 'mai');
      p.control('mai');
      teleport(mai, 3.6, -1.32, yaw: math.pi);
      _step(p, w, 0.3);
      expect(p.decision.action, PilotAction.pickUp);
      p.pressA();
      final held = p.items.heldBy('mai');
      expect(held, isNotNull);
      expect(held!.kind, ItemKind.cakeBox);
      expect(mai.carry, ChibiCarry.leftHand);
      _step(p, w, 0.5);
      // Vật bám bàn tay (cách tâm người ≤ 0,6 m, cao hơn sàn).
      expect(math.sqrt(math.pow(held.x - mai.pose.x, 2) + math.pow(held.z - mai.pose.z, 2)), lessThan(0.6));
      expect(held.y, greaterThan(0.1));
      // Bấm Q với hộp bánh: không ném, bong bóng "Bánh phải mời tận tay chứ!".
      p.throwTap();
      expect(held.phase, ItemPhase.held);
      expect(p.bubbles.any((b) => b.actorId == 'mai'), isTrue);
      p.release();
      expect(held.phase, ItemPhase.rest);
      expect(held.surfaceId, isNull);
      expect(mai.carry, ChibiCarry.none);
    });

    test('nhặt cuộn len rồi ném: bay, dừng trên sàn trong vùng đi được', () {
      final (p, w) = make();
      final mai = actor(w, 'mai');
      p.control('mai');
      teleport(mai, 3.3, 1.6, yaw: math.pi / 2);
      _step(p, w, 0.3);
      expect(p.decision, const PilotDecision(PilotAction.pickUp, 'yarn'));
      p.pressA();
      expect(p.hud.value.showThrow, isTrue);
      _step(p, w, 0.5);
      p.throwCharged(1);
      _step(p, w, 0.4);
      final yarn = p.items.byId('yarn')!;
      expect(yarn.phase, ItemPhase.flying);
      expect(mai.carry, ChibiCarry.none);
      _step(p, w, 6, until: () => yarn.phase == ItemPhase.rest);
      expect(yarn.phase, ItemPhase.rest);
      expect(p.nav.canStand(yarn.x, yarn.z, ItemPhysics.restRadius), isTrue);
    });

    test('vẫy chào: hồi chiêu 8 s', () {
      final (p, w) = make();
      p.control('staff_nora');
      _step(p, w, 0.2);
      p.wave();
      _step(p, w, 0.1);
      expect(p.waveCooldown.value, greaterThan(0.9));
      _step(p, w, 8.2);
      expect(p.waveCooldown.value, 0);
    });
  });

  group('nói chuyện', () {
    test('Mai — ông Hòa: tự đi tới cạnh khách, truyện T1, lựa chọn C2 = +1♥ +5 xu; lần sau chuyện phiếm', () {
      final (p, w) = make();
      final hoa = actor(w, 'hoa');
      _step(p, w, 1.0); // ông Hòa ngồi hẳn xuống ghế
      expect(hoa.isSeated, isTrue);
      expect(p.talkCandidates('mai'), contains('hoa'));
      expect(p.startTalk('mai', 'hoa'), isTrue);
      _step(p, w, 8, until: () => p.talk.value != null);
      expect(p.talk.value, isNotNull, reason: 'Mai tới nơi, khung thoại mở');
      expect(hoa.paused, isTrue);
      expect(hoa.isSeated, isTrue, reason: 'đang ngồi thì giữ ngồi');
      _finishTalk(p, w, choice: 1);
      expect(p.talk.value, isNull);
      expect(p.hearts.value, 1);
      expect(p.coins.value, 5);
      expect(p.ledger.storySeen('owl'), isTrue);
      expect(hoa.paused, isFalse);
      expect(p.takeNotices(), isNotEmpty);
      // Lần 2: chuyện phiếm (+1♥).
      _step(p, w, 0.5);
      if (hoa.isSeated && p.startTalk('mai', 'hoa')) {
        _step(p, w, 8, until: () => p.talk.value != null);
        expect(p.talk.value!.choices, isEmpty);
        _finishTalk(p, w);
        expect(p.hearts.value, 2);
      }
    });

    test('nhân viên khác Mai: chuyện phiếm, câu mở riêng; không có ai rảnh → toast', () {
      final (p, w) = make();
      _step(p, w, 1.0);
      p.control('staff_theo');
      final c = p.talkCandidates('staff_theo');
      expect(c, isNotEmpty);
      expect(c.length, lessThanOrEqualTo(3));
      expect(p.startTalk('staff_theo', c.first), isTrue);
      _step(p, w, 8, until: () => p.talk.value != null);
      expect(p.talk.value, isNotNull);
      expect(p.hud.value.controlsVisible, isFalse, reason: 'mở khung thoại thì ẩn joystick / cụm nút');
      _finishTalk(p, w);
      expect(p.hud.value.controlsVisible, isTrue);
      expect(actor(w, 'staff_theo').driven, isTrue, reason: 'nói xong vẫn đang điều khiển');
    });

    test('khách đang đi: không mở nói chuyện', () {
      final (p, w) = make();
      final linh = actor(w, 'linh');
      _step(p, w, 0.5);
      expect(linh.isBusyMoving, isTrue);
      expect(p.startTalk('mai', 'linh'), isFalse);
    });
  });

  group('sự kiện cãi nhau', () {
    test('hết giờ 45 s: hai khách phụng phịu bỏ đi, toast, sự kiện kết thúc', () {
      final (p, w) = make();
      expect(p.forceEvent('lastCake'), isTrue);
      expect(p.eventPair, ('regular_04', 'regular_01'));
      _step(p, w, 6.5);
      expect(p.quarrel.phase, QuarrelPhase.arguing);
      expect(p.banner.value, isTrue);
      final a = actor(w, 'regular_04');
      expect((a.pose.x - Shop3dPilot.eventA.$1).abs(), lessThan(0.3), reason: 'A tới chỗ cãi');
      expect(a.action, ChibiAction.argue);
      p.takeNotices();
      _step(p, w, 46);
      expect(p.banner.value, isFalse);
      expect(p.takeNotices(), isNotEmpty, reason: 'toast hết giờ');
      _step(p, w, 40, until: () => p.eventPair == null);
      expect(p.eventPair, isNull);
      expect(p.quarrel.phase, QuarrelPhase.waiting);
      expect(w.director.actors.any((x) => x.id == 'regular_04'), isFalse);
    });

    test('Mai can ngăn (nút A): hội thoại 3 lựa chọn, A = +2♥ +10 xu, hai khách vào tiệm; mở T7 cho Bạn Sóc', () {
      final (p, w) = make();
      p.forceEvent('lastCake');
      _step(p, w, 6.5);
      final mai = actor(w, 'mai');
      p.control('mai');
      teleport(mai, Shop3dPilot.eventMai.$1, Shop3dPilot.eventMai.$2, yaw: 0);
      _step(p, w, 0.3);
      expect(p.decision.action, PilotAction.intervene);
      p.pressA();
      expect(p.talk.value, isNotNull);
      expect(p.quarrel.phase, QuarrelPhase.intervening);
      // Bỏ qua tới lựa chọn: phải dừng ở lựa chọn (3 nút).
      p.talkSkip();
      expect(p.talk.value!.choices.length, 3);
      _finishTalk(p, w, choice: 0);
      expect(p.hearts.value, 2);
      expect(p.coins.value, 10);
      expect(p.quarrel.phase, QuarrelPhase.aftermath);
      // Hai khách đi vào cửa → vỉa hè trống → sự kiện kết thúc, toast "yên bình".
      _step(p, w, 40, until: () => p.quarrel.phase == QuarrelPhase.waiting);
      expect(p.quarrel.phase, QuarrelPhase.waiting);
      final squirrel = actor(w, 'regular_04');
      expect(squirrel.pose.z, lessThan(Shop3dPilot.sidewalkZ));
      // Trong tiệm: Mai nói chuyện với Bạn Sóc lúc khách đứng yên → truyện T7 (mở sau Q1).
      var opened = false;
      p.release();
      for (var i = 0; i < 120 && !opened; i++) {
        _step(p, w, 0.5);
        if (!squirrel.done && !squirrel.isBusyMoving && !squirrel.isHopping) opened = p.startTalk('mai', 'regular_04');
      }
      expect(opened, isTrue);
      _step(p, w, 10, until: () => p.talk.value != null);
      _finishTalk(p, w, choice: 1);
      expect(p.ledger.storySeen('nut'), isTrue);
    });

    test('"Mai ra xem": Mai tự đi từ bếp ra vỉa hè, tới nơi tự mở hội thoại', () {
      final (p, w) = make();
      p.forceEvent('first');
      _step(p, w, 6.5);
      p.sendMai();
      expect(p.banner.value, isFalse);
      _step(p, w, 40, until: () => p.talk.value != null);
      expect(p.talk.value, isNotNull);
      final mai = actor(w, 'mai');
      final d = math.sqrt(math.pow(mai.pose.x - Shop3dPilot.eventX, 2) + math.pow(mai.pose.z - Shop3dPilot.eventZ, 2));
      expect(d, lessThanOrEqualTo(QuarrelDirector.interveneRange + 1e-6));
      _finishTalk(p, w, choice: 2);
      expect(p.hearts.value, 3);
      _step(p, w, 30);
      expect(mai.pose.z, lessThan(Shop3dPilot.sidewalkZ), reason: 'Mai về lại tiệm');
    });
  });

  group('ChibiActor (mở rộng V3)', () {
    final m = ChibiSizes.fit(models['linh']!);

    test('tạm dừng / chạy tiếp kịch bản; lộ trình riêng rồi về kịch bản', () {
      final a = ChibiActor(m, const [ChibiStep.walk([(0, 6)])], x: 0, z: 0);
      for (var t = 0.0; t < 1; t += _dt) {
        a.update(_dt, const {});
      }
      final z1 = a.pose.z;
      a.pauseScript(faceYaw: math.pi);
      for (var t = 0.0; t < 1; t += _dt) {
        a.update(_dt, const {});
      }
      expect(a.pose.z, closeTo(z1, 1e-9));
      expect(a.isBusyMoving, isFalse);
      a.resumeScript(route: [(1, z1)]);
      expect(a.routing, isTrue);
      for (var t = 0.0; t < 3; t += _dt) {
        a.update(_dt, const {});
      }
      expect(a.routing, isFalse);
      expect(a.pose.z, greaterThan(z1 + 0.3), reason: 'đi tiếp kịch bản sau lộ trình');
    });

    test('hành động tạm: cúi khựng 0,35 s; phụng phịu không khựng khi đang đi', () {
      final a = ChibiActor(m, const [ChibiStep.walk([(0, 6)])], x: 0, z: 0);
      a.perform(ChibiAction.bend, 0.35);
      expect(a.frozen, isTrue);
      for (var t = 0.0; t < 0.3; t += _dt) {
        a.update(_dt, const {});
      }
      expect(a.pose.z, closeTo(0, 1e-9));
      for (var t = 0.0; t < 0.5; t += _dt) {
        a.update(_dt, const {});
      }
      expect(a.frozen, isFalse);
      a.perform(ChibiAction.pout, 5, freeze: 0);
      final z = a.pose.z;
      for (var t = 0.0; t < 0.5; t += _dt) {
        a.update(_dt, const {});
      }
      expect(a.pose.z, greaterThan(z + 0.1));
      expect(a.action, ChibiAction.pout);
    });

    test('kịch bản một vòng: xong thì done', () {
      final a = ChibiActor(m, const [ChibiStep.act(ChibiAction.stand, 1)], x: 0, z: 0);
      a.setScript(const [ChibiStep.act(ChibiAction.argue, 0.5), ChibiStep.walk([(0, 0.5)])], once: true);
      for (var t = 0.0; t < 3; t += _dt) {
        a.update(_dt, const {});
      }
      expect(a.done, isTrue);
      expect(a.isBusyMoving, isFalse);
    });

    test('tâm bàn tay ở đầu dưới cánh tay, đi theo người', () {
      final a = ChibiActor(ChibiSizes.fit(models['mai']!), const [ChibiStep.act(ChibiAction.stand, 10)], x: 1, z: 2);
      a.update(_dt, const {});
      final out = [0.0, 0.0, 0.0];
      a.handWorld(1, out);
      // Mai cao ~1,24 m: bàn tay buông ở tầm hông.
      expect(out[1], inInclusiveRange(0.2, 0.7));
      expect(math.sqrt(math.pow(out[0] - 1, 2) + math.pow(out[2] - 2, 2)), lessThan(0.45));
    });

    test('lái tay: NPC bị chắn 2 s → "Cho mình qua với!", 4 s → đi xuyên', () {
      final driver = ChibiActor(ChibiSizes.fit(models['mai']!), const [ChibiStep.act(ChibiAction.stand, 100)],
          x: 0, z: 1.5);
      final npc = ChibiActor(m, const [ChibiStep.walk([(0, 4)])], x: 0, z: 0.9);
      driver.startDriving();
      final d = ChibiDirector([driver, npc]);
      var excused = false;
      for (var t = 0.0; t < 3; t += _dt) {
        d.update(_dt, const {});
        if (d.excuseMe.contains(npc)) excused = true;
      }
      expect(excused, isTrue);
      expect(npc.pose.z, lessThan(1.2));
      for (var t = 0.0; t < 6; t += _dt) {
        d.update(_dt, const {});
      }
      expect(npc.pose.z, greaterThan(2.5), reason: 'được đi xuyên sau 4 s');
    });
  });
}
