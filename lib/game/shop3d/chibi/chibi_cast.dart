import 'dart:math' as math;

import '../shop3d_layout.dart';
import 'chibi_actor.dart';
import 'chibi_characters.dart';
import 'chibi_rig.dart';
import 'chibi_sizes.dart';

/// Dàn nhân vật chibi của cảnh tiệm mặc định (docs/v3/character-3d-procedural.md, mục "Bản thử") — Dart thuần.
///
/// - Khách Linh, ông Hòa, Kenji, bà Rosa (VIP, đi chậm): đi vòng cửa → hàng chờ → quầy (đứng gọi món, nhảy vui; Kenji
///   giơ máy ảnh chụp) → bàn (ngồi; cần `cafe_tables`) → ra cửa → lặp; lệch pha nhau (Linh bắt đầu ngoài cửa, bà Rosa
///   chờ ngoài cửa sau Linh, ông Hòa và Kenji đang ngồi bàn).
/// - Nora: đứng sau quầy thu ngân, thỉnh thoảng vẫy tay chào.
/// - Mai: nửa bếp phía đông — bàn trộn (nhào bột, quay mặt ra phòng), khay cupcake, tủ lạnh.
/// - Bao: nửa bếp phía tây — cán bột ở đầu bàn trộn (quay mặt ra phòng), lò (bưng khay), kệ nguyên liệu.
/// - Theo: bưng khay trà từ đầu quầy (lối nhân viên) ra hai bàn rồi quay lại.
/// - Mèo Mochi (tuỳ chọn, ngày mưa): vào cửa, nhảy lên ổ nằm, ngồi liếm chân, rồi ra.
///
/// Mọi đường đi dùng điểm của [Shop3dLayout] (cửa, hàng chờ, quầy, ghế, điểm trung gian) và điểm riêng ở đây — không
/// xuyên quầy / bàn; Mai và Bao chia hai nửa bếp nên không chắn đường nhau.
///
/// Nhân vật được đưa về kích thước trong cảnh ([ChibiSizes.fit]: thú nhỏ hơn Mai) và đứng trên bục trước / sau quầy
/// ([Shop3dLayout.floorHeightAt]).
abstract final class ChibiCast {
  /// Ghế của Linh (bàn giữa, ghế phải) và ông Hòa (bàn giữa, ghế trái) — hai người ngồi đối diện nhau khi trùng giờ.
  static const int linhSeat = 3;
  static const int hoaSeat = 2;

  /// Ghế của bà Rosa (bàn phải, ghế trái) và Kenji (bàn phải, ghế phải).
  static const int rosaSeat = 4;
  static const int kenjiSeat = 5;

  // ---- Điểm riêng của dàn nhân vật ---------------------------------------------------------------------------

  /// Đầu tây bàn trộn, phía lò (cạnh tô bột), quay mặt ra phòng — chỗ Bao cán bột.
  static const Shop3dSpot bakerIslandWest = Shop3dSpot('bakerIslandWest', -2.55, -2.82, 0);

  /// Góc rẽ giữa đầu tây bàn trộn và lò (tránh góc bàn trộn).
  static const Shop3dSpot bakerCorner = Shop3dSpot('bakerCorner', -3.4, -2.8, 0);

  /// Trước kệ nguyên liệu (quay vào tường trái).
  static const Shop3dSpot bakerShelf = Shop3dSpot('bakerShelf', -4.35, -2.1, -math.pi / 2);

  /// Trước tủ lạnh (quay vào tường bếp).
  static const Shop3dSpot fridgeFront = Shop3dSpot('fridgeFront', 1.6, -2.85, math.pi);

  /// Lối nhân viên sau đầu tây tủ kính: Theo nhận khay trà ở đây (quay về đầu tủ kính).
  static const Shop3dSpot waiterPickup = Shop3dSpot('waiterPickup', -3.5, -0.6, math.pi / 2);

  /// Trước bàn giữa / bàn phải, phía quầy: Theo đặt trà (quay vào bàn).
  static const Shop3dSpot serveTable2 = Shop3dSpot('serveTable2', -1.6, 1.95, 0);
  static const Shop3dSpot serveTable3 = Shop3dSpot('serveTable3', 0.6, 1.95, 0);

  /// Lối đi của mèo Mochi bên phải hàng chờ, và ổ nằm (mặt trên đệm cao 0,18 m).
  static const Shop3dSpot catLane = Shop3dSpot('catLane', 4.1, 3.0, 0);
  static const Shop3dSpot catBedSide = Shop3dSpot('catBedSide', 4.25, 2.1, 0);
  static const Shop3dSpot catBed = Shop3dSpot('catBed', 4.4, 1.5, 0.3, y: 0.18);

  /// Các điểm đứng trên sàn của dàn nhân vật (để kiểm tra).
  static List<Shop3dSpot> get walkSpots => [
        bakerIslandWest,
        bakerCorner,
        bakerShelf,
        fridgeFront,
        waiterPickup,
        serveTable2,
        serveTable3,
        catLane,
        catBedSide,
      ];

  /// Hướng mặt khi đứng gọi món sau khi nhìn quầy: quay nửa người về phía camera mặc định (yaw ~0,4).
  static const double orderFaceYaw = 0.75;

  // ---- Kịch bản ---------------------------------------------------------------------------------------------

  /// Kịch bản một vòng của khách ngồi ghế [seat], gọi món ở chỗ quầy [counter]. [photo]: sau khi vui thì giơ máy ảnh
  /// chụp (quay ra phòng) trong ngần ấy giây.
  static List<ChibiStep> customerLoop(
    Shop3dSpot counter,
    Shop3dSpot seat, {
    double orderTime = 2.6,
    double sitTime = 9,
    double photo = 0,
  }) {
    const tables = Shop3dRequires.cafeTables;
    final q = Shop3dLayout.queue;
    return [
      ChibiStep.walk([
        (Shop3dLayout.doorOutside.x, Shop3dLayout.doorOutside.z),
        (Shop3dLayout.entrance.x, Shop3dLayout.entrance.z),
        for (var i = q.length - 1; i >= 1; i--) (q[i].x, q[i].z),
      ]),
      const ChibiStep.act(ChibiAction.stand, 1.0, jitter: 0.6, faceYaw: math.pi),
      ChibiStep.walk([(q[0].x, q[0].z), (counter.x, counter.z)]),
      // Gọi món: nhìn quầy một chút rồi quay nửa người về phía phòng (camera mặc định ở +z, lệch phải) — mặt đọc
      // được từ góc nhìn mặc định.
      ChibiStep.act(ChibiAction.stand, 0.9, jitter: 0.3, faceYaw: counter.facingYaw),
      ChibiStep.act(ChibiAction.stand, orderTime, jitter: 0.8, faceYaw: orderFaceYaw),
      // Vui: quay ra phòng (về phía camera mặc định) rồi nhảy.
      const ChibiStep.act(ChibiAction.happy, 1.5, faceYaw: 0.25),
      if (photo > 0) ChibiStep.act(ChibiAction.work, photo, faceYaw: 0.35),
      ChibiStep.walk([(seat.x, Shop3dLayout.seatAisleZ), (seat.x, Shop3dLayout.seatApproachZ)], requires: tables),
      ChibiStep.sit(seat, sitTime, jitter: 3, requires: tables),
      ChibiStep.walk([(seat.x, Shop3dLayout.seatAisleZ)], requires: tables),
      ChibiStep.walk([
        (Shop3dLayout.exitAisle.x, Shop3dLayout.exitAisle.z),
        (Shop3dLayout.exitInside.x, Shop3dLayout.exitInside.z),
        (Shop3dLayout.exitOutside.x, Shop3dLayout.exitOutside.z),
      ]),
      const ChibiStep.act(ChibiAction.stand, 2.0, jitter: 1.5, faceYaw: math.pi),
    ];
  }

  // ---- Khách nền trong ca bán (docs/v3/city-gd3-spec.md) ------------------------------------------------------

  /// Khách nền của tiệm (ông Hòa, Linh, Kenji, bà Rosa): trong ca bán họ ngồi yên làm nền, không phải khách có đơn.
  static const List<String> ambientGuestIds = [
    ChibiCharacters.linh,
    ChibiCharacters.hoa,
    ChibiCharacters.kenji,
    ChibiCharacters.rosa,
  ];

  /// Ghế của khách nền [id] (id lạ → [ArgumentError]).
  static Shop3dSpot seatOf(String id) => switch (id) {
        ChibiCharacters.linh => Shop3dLayout.seats[linhSeat],
        ChibiCharacters.hoa => Shop3dLayout.seats[hoaSeat],
        ChibiCharacters.kenji => Shop3dLayout.seats[kenjiSeat],
        ChibiCharacters.rosa => Shop3dLayout.seats[rosaSeat],
        _ => throw ArgumentError.value(id, 'id', 'not an ambient guest'),
      };

  /// Vòng khách thường của khách nền [id] (đúng kịch bản của [build]); id lạ → [ArgumentError].
  static List<ChibiStep> loopFor(String id) => switch (id) {
        ChibiCharacters.linh => customerLoop(Shop3dLayout.counterSpots[1], seatOf(id)),
        ChibiCharacters.hoa => customerLoop(Shop3dLayout.counterSpots[2], seatOf(id), orderTime: 3.2, sitTime: 11),
        ChibiCharacters.kenji => customerLoop(Shop3dLayout.counterSpots[0], seatOf(id), sitTime: 7, photo: 2.2),
        ChibiCharacters.rosa => customerLoop(Shop3dLayout.counterSpots[1], seatOf(id), orderTime: 3.6, sitTime: 12),
        _ => throw ArgumentError.value(id, 'id', 'not an ambient guest'),
      };

  /// Chỉ số bước ngồi của [script] (-1 nếu không có).
  static int sitIndex(List<ChibiStep> script) => script.indexWhere((x) => x.action == ChibiAction.sit);

  /// Phần còn lại của đường [chain] tính từ chỗ đứng (x, z): chiếu (x, z) lên đoạn gần nhất rồi lấy các điểm sau đoạn đó
  /// (không quay lại điểm đã đi qua).
  static List<(double, double)> pathFrom(List<(double, double)> chain, double x, double z) {
    if (chain.length < 2) return chain;
    var best = 0;
    var bestD = double.infinity;
    for (var k = 0; k < chain.length - 1; k++) {
      final (ax, az) = chain[k];
      final (bx, bz) = chain[k + 1];
      final dx = bx - ax, dz = bz - az;
      final len2 = dx * dx + dz * dz;
      final t = len2 < 1e-12 ? 0.0 : (((x - ax) * dx + (z - az) * dz) / len2).clamp(0.0, 1.0);
      final px = ax + dx * t - x, pz = az + dz * t - z;
      final d = px * px + pz * pz;
      if (d < bestD) {
        bestD = d;
        best = k;
      }
    }
    return chain.sublist(best + 1);
  }

  /// Kịch bản ngồi yên của khách nền [id] suốt ca: đi (từ chỗ đang đứng [fromX], [fromZ]; mặc định từ ngoài cửa) tới
  /// ghế rồi ngồi (3600 s). Chưa có bàn ghế thì đứng yên. Hết ca trả lại [loopFor] (xem `ShiftStage`).
  static List<ChibiStep> seatedIdle(String id, {double? fromX, double? fromZ}) {
    const tables = Shop3dRequires.cafeTables;
    final seat = seatOf(id);
    final chain = <(double, double)>[
      (Shop3dLayout.doorOutside.x, Shop3dLayout.doorOutside.z),
      (Shop3dLayout.entrance.x, Shop3dLayout.entrance.z),
      (Shop3dLayout.exitAisle.x, Shop3dLayout.exitAisle.z),
      (seat.x, Shop3dLayout.seatAisleZ),
      (seat.x, Shop3dLayout.seatApproachZ),
    ];
    return [
      ChibiStep.walk(
        fromX == null || fromZ == null ? chain.sublist(1) : pathFrom(chain, fromX, fromZ),
        requires: tables,
      ),
      ChibiStep.sit(seat, 3600, requires: tables),
      ChibiStep.act(ChibiAction.stand, 3600, faceYaw: seat.facingYaw),
    ];
  }

  /// Nora: đứng gõ máy tính tiền / chờ khách, thỉnh thoảng vẫy tay chào.
  static List<ChibiStep> cashierLoop() => const [
        ChibiStep.act(ChibiAction.stand, 3.5, jitter: 2.5, faceYaw: 0),
        ChibiStep.act(ChibiAction.wave, 1.8, faceYaw: 0.15),
        ChibiStep.act(ChibiAction.work, 2.2, jitter: 1.5, faceYaw: 0),
        ChibiStep.act(ChibiAction.stand, 2.5, jitter: 2, faceYaw: 0),
      ];

  /// Mai: bàn trộn → khay cupcake → tủ lạnh → bàn trộn (nửa bếp phía đông).
  static List<ChibiStep> bakerLoop() {
    const mix = Shop3dLayout.staffMixerFar;
    const tray = Shop3dLayout.staffPrepTray;
    return [
      ChibiStep.act(ChibiAction.work, 4.0, jitter: 1.5, faceYaw: mix.facingYaw),
      ChibiStep.walk([(tray.x, tray.z)]),
      ChibiStep.act(ChibiAction.carry, 2.8, jitter: 1, faceYaw: tray.facingYaw),
      ChibiStep.walk([(mix.x, mix.z)]),
      ChibiStep.act(ChibiAction.work, 3.0, jitter: 1, faceYaw: mix.facingYaw),
      const ChibiStep.act(ChibiAction.happy, 1.0, faceYaw: 0),
      ChibiStep.walk([(tray.x, tray.z)]),
      ChibiStep.act(ChibiAction.work, 2.5, jitter: 1, faceYaw: tray.facingYaw),
      ChibiStep.walk([(fridgeFront.x, fridgeFront.z)]),
      ChibiStep.act(ChibiAction.work, 2.0, jitter: 0.8, faceYaw: fridgeFront.facingYaw),
      ChibiStep.walk([(mix.x, mix.z)]),
    ];
  }

  /// Bao: cán bột ở đầu tây bàn trộn (quay ra phòng) → lò (bưng khay) → kệ nguyên liệu → lại cán bột (nửa bếp tây).
  static List<ChibiStep> ovenLoop() {
    const island = bakerIslandWest;
    const oven = Shop3dLayout.staffOven1;
    return [
      ChibiStep.act(ChibiAction.work, 5.0, jitter: 2, faceYaw: island.facingYaw),
      ChibiStep.walk([(bakerCorner.x, bakerCorner.z), (oven.x, oven.z)]),
      ChibiStep.act(ChibiAction.carry, 2.6, jitter: 1, faceYaw: oven.facingYaw),
      ChibiStep.walk([(bakerCorner.x, bakerCorner.z), (island.x, island.z)]),
      ChibiStep.act(ChibiAction.work, 4.0, jitter: 1.5, faceYaw: island.facingYaw),
      const ChibiStep.act(ChibiAction.happy, 1.2, faceYaw: 0),
      ChibiStep.walk([(bakerCorner.x, bakerCorner.z), (bakerShelf.x, bakerShelf.z)]),
      ChibiStep.act(ChibiAction.work, 2.2, jitter: 0.8, faceYaw: bakerShelf.facingYaw),
      ChibiStep.walk([(bakerCorner.x, bakerCorner.z), (island.x, island.z)]),
    ];
  }

  /// Theo: nhận khay trà ở lối nhân viên → bàn giữa (đặt trà) → bàn phải → quay lại (khay luôn trên tay phải).
  static List<ChibiStep> waiterLoop() {
    const pickup = waiterPickup;
    const passage = (-3.6, 0.8);
    const aisle = Shop3dLayout.seatAisleZ;
    return [
      ChibiStep.act(ChibiAction.stand, 2.0, jitter: 1, faceYaw: pickup.facingYaw),
      ChibiStep.walk([passage, (serveTable2.x, aisle), (serveTable2.x, serveTable2.z)]),
      ChibiStep.act(ChibiAction.work, 1.8, jitter: 0.6, faceYaw: serveTable2.facingYaw),
      const ChibiStep.act(ChibiAction.wave, 1.2, faceYaw: 0.3),
      ChibiStep.walk([(serveTable2.x, aisle), (serveTable3.x, aisle), (serveTable3.x, serveTable3.z)]),
      ChibiStep.act(ChibiAction.work, 1.8, jitter: 0.6, faceYaw: serveTable3.facingYaw),
      ChibiStep.walk([(serveTable3.x, aisle), passage, (pickup.x, pickup.z)]),
    ];
  }

  /// Mochi: vào cửa → lối bên phải hàng chờ → nhảy lên ổ nằm (ngồi, tự liếm chân) → ra cửa → ngồi chờ ngoài cửa.
  static List<ChibiStep> catLoop() => [
        ChibiStep.walk([
          (Shop3dLayout.doorOutside.x + 0.25, Shop3dLayout.doorOutside.z),
          (Shop3dLayout.entrance.x + 0.25, Shop3dLayout.entrance.z),
          (catLane.x, catLane.z),
          (catBedSide.x, catBedSide.z),
        ]),
        const ChibiStep.sit(catBed, 14, jitter: 4),
        ChibiStep.walk([
          (catLane.x, catLane.z),
          (Shop3dLayout.entrance.x + 0.25, Shop3dLayout.entrance.z),
          (Shop3dLayout.doorOutside.x + 0.25, Shop3dLayout.doorOutside.z),
        ]),
        const ChibiStep.act(ChibiAction.rest, 4, jitter: 2, faceYaw: math.pi),
      ];

  /// Dựng dàn nhân vật. Thứ tự: linh, hoa, staff_nora, mai, staff_bao, staff_theo, kenji, vip_00 (+ mochi nếu [mochi]).
  /// [models] cho phép dùng lại model đã dựng (chưa đưa về kích thước thì [ChibiSizes.fit] đưa).
  static List<ChibiActor> build({Map<String, ChibiModel>? models, bool mochi = false}) {
    ChibiModel m(String id) => ChibiSizes.fit(models?[id] ?? ChibiCharacters.build(id));
    const floor = Shop3dLayout.floorHeightAt;
    final hoaSeatSpot = Shop3dLayout.seats[hoaSeat];
    final kenjiSeatSpot = Shop3dLayout.seats[kenjiSeat];
    final linhLoop = loopFor(ChibiCharacters.linh);
    final hoaLoop = loopFor(ChibiCharacters.hoa);
    final kenjiLoop = loopFor(ChibiCharacters.kenji);
    final rosaLoop = loopFor(ChibiCharacters.rosa);
    const cashier = Shop3dLayout.staffCashierSide;
    const mix = Shop3dLayout.staffMixerFar;
    return [
      ChibiActor(m(ChibiCharacters.linh), linhLoop,
          x: Shop3dLayout.doorOutside.x, z: Shop3dLayout.doorOutside.z, yaw: math.pi, seed: 11, floor: floor),
      ChibiActor(m(ChibiCharacters.hoa), hoaLoop,
          x: hoaSeatSpot.x,
          z: Shop3dLayout.seatApproachZ,
          yaw: hoaSeatSpot.facingYaw,
          seed: 23,
          startStep: sitIndex(hoaLoop),
          floor: floor),
      ChibiActor(m(ChibiCharacters.nora), cashierLoop(),
          x: cashier.x, z: cashier.z, yaw: cashier.facingYaw, seed: 37, floor: floor),
      ChibiActor(m(ChibiCharacters.mai), bakerLoop(), x: mix.x, z: mix.z, yaw: mix.facingYaw, seed: 41, floor: floor),
      ChibiActor(m(ChibiCharacters.bao), ovenLoop(),
          x: bakerIslandWest.x, z: bakerIslandWest.z, yaw: bakerIslandWest.facingYaw, seed: 53, floor: floor),
      ChibiActor(m(ChibiCharacters.theo), waiterLoop(),
          x: waiterPickup.x, z: waiterPickup.z, yaw: waiterPickup.facingYaw, seed: 59, floor: floor),
      ChibiActor(m(ChibiCharacters.kenji), kenjiLoop,
          x: kenjiSeatSpot.x,
          z: Shop3dLayout.seatApproachZ,
          yaw: kenjiSeatSpot.facingYaw,
          seed: 67,
          startStep: sitIndex(kenjiLoop),
          floor: floor),
      // Bà Rosa chờ ngoài cửa (bước cuối của vòng) rồi vào sau Linh.
      ChibiActor(m(ChibiCharacters.rosa), rosaLoop,
          x: Shop3dLayout.exitOutside.x,
          z: Shop3dLayout.exitOutside.z,
          yaw: math.pi,
          seed: 71,
          startStep: rosaLoop.length - 1,
          floor: floor),
      if (mochi)
        ChibiActor(m(ChibiCharacters.mochi), catLoop(),
            x: Shop3dLayout.doorOutside.x + 0.25, z: Shop3dLayout.doorOutside.z, yaw: math.pi, seed: 83, floor: floor),
    ];
  }
}
