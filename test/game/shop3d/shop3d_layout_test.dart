import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:sugarleaf_bakery/game/shop3d/shop3d_layout.dart';
import 'package:sugarleaf_bakery/game/shop3d/shop3d_math.dart';

const _eps = 1e-6;

/// Độ xuyên sâu (m) của hai khối theo mỗi trục; cả ba > [tol] mới tính là chồng lấn thật (chạm mặt = 0).
bool _overlaps(Shop3dPart a, Shop3dPart b, {double tol = 0.02}) {
  double pen(double aMin, double aMax, double bMin, double bMax) => math.min(aMax, bMax) - math.max(aMin, bMin);
  return pen(a.minX, a.maxX, b.minX, b.maxX) > tol &&
      pen(a.minY, a.maxY, b.minY, b.maxY) > tol &&
      pen(a.minZ, a.maxZ, b.minZ, b.maxZ) > tol;
}

/// Khoảng cách từ điểm (x,z) tới hình chữ nhật (AABB trên mặt phẳng xz) của khối; 0 nếu nằm trong.
double _distToPart(double x, double z, Shop3dPart p) {
  final dx = math.max(math.max(p.minX - x, x - p.maxX), 0.0);
  final dz = math.max(math.max(p.minZ - z, z - p.maxZ), 0.0);
  return math.sqrt(dx * dx + dz * dz);
}

/// Vật cản mà người đứng (cao 1,6 m) có thể đụng.
Iterable<Shop3dPart> _obstacles() sync* {
  for (final p in Shop3dLayout.props) {
    if (p.flat) continue;
    for (final part in p.parts) {
      if (part.minY < Shop3dLayout.personHeight + 0.1 && part.alpha > 0) yield part;
    }
  }
}

void main() {
  const room = Shop3dLayout.room;

  test('phòng ~10 × 8 × 3,2 m', () {
    expect(room.width, closeTo(10, _eps));
    expect(room.depth, closeTo(8, _eps));
    expect(room.height, closeTo(3.2, _eps));
    expect(room.minY, 0);
  });

  test('cờ requires khớp id mở khoá của v2', () {
    const known = {'case_stand', 'oven_2', 'cafe_tables', 'kitchen_2'};
    expect(Shop3dRequires.all, known);
    for (final p in [...Shop3dLayout.props, ...Shop3dLayout.floorProps]) {
      if (p.requires != null) expect(known, contains(p.requires), reason: p.id);
    }
    for (final s in [...Shop3dLayout.seats, ...Shop3dLayout.staffSpots]) {
      if (s.requires != null) expect(known, contains(s.requires), reason: s.id);
    }
  });

  test('id vật thể không trùng, mỗi vật có khối', () {
    final ids = [
      for (final p in [...Shop3dLayout.props, ...Shop3dLayout.floorProps]) p.id,
    ];
    expect(ids.toSet().length, ids.length);
    for (final p in [...Shop3dLayout.props, ...Shop3dLayout.floorProps]) {
      expect(p.parts, isNotEmpty, reason: p.id);
    }
  });

  test('các khu chính đều có mặt', () {
    final ids = {for (final p in Shop3dLayout.props) p.id};
    expect(ids, containsAll(['oven1', 'oven2', 'mixingIsland', 'pastryCase', 'cashierCounter']));
    expect(Shop3dLayout.props.where((p) => p.id.startsWith('seating')).length, 3);
    expect(Shop3dLayout.seats.length, 6);
    expect(Shop3dLayout.queue.length, 5);
    expect(Shop3dLayout.counterSpots.length, 3);
    expect(Shop3dLayout.caseSlotPositions().length, Shop3dLayout.caseSlotCount);
    expect(Shop3dLayout.walls.keys, containsAll(RoomWall.values));
  });

  test('tỉ lệ thật: quầy hai bậc (0,72 m phía khách, 0,95 m quanh máy tính tiền), bàn ~0,75 m, tủ kính < người', () {
    double top(String id, {Shop3dColor? color}) {
      final p = Shop3dLayout.props.firstWhere((p) => p.id == id);
      return p.parts.where((e) => color == null || e.color == color).map((e) => e.maxY).reduce(math.max);
    }

    final cashier = Shop3dLayout.props.firstWhere((p) => p.id == 'cashierCounter');
    expect(cashier.parts[1].maxY, closeTo(Shop3dLayout.serviceCounterTop, 1e-9));
    expect(cashier.parts[1].maxY, inInclusiveRange(0.7, 0.75));
    expect(cashier.parts[3].maxY, closeTo(Shop3dLayout.cashierStepTop, 1e-9));
    expect(Shop3dLayout.props.firstWhere((p) => p.id == 'packingCounter').parts[1].maxY, lessThan(0.95));
    expect(Shop3dLayout.props.firstWhere((p) => p.id == 'mixingIsland').parts[1].maxY, lessThanOrEqualTo(0.75));
    final table = Shop3dLayout.props.firstWhere((p) => p.id == 'seating1').parts[2];
    expect(table.maxY, closeTo(0.75, 0.05));
    expect(top('pastryCase'), lessThan(Shop3dLayout.personHeight));
    expect(top('fridge'), greaterThan(Shop3dLayout.personHeight));
  });

  test('mọi vật thể (kể cả bật hết) nằm trong phòng', () {
    for (final p in Shop3dLayout.props) {
      for (final part in p.parts) {
        const tol = 1e-6;
        expect(part.minX, greaterThanOrEqualTo(room.minX - tol), reason: '${p.id} minX');
        expect(part.maxX, lessThanOrEqualTo(room.maxX + tol), reason: '${p.id} maxX');
        expect(part.minZ, greaterThanOrEqualTo(room.minZ - tol), reason: '${p.id} minZ');
        expect(part.maxZ, lessThanOrEqualTo(room.maxZ + tol), reason: '${p.id} maxZ');
        expect(part.minY, greaterThanOrEqualTo(-tol), reason: '${p.id} minY');
        expect(part.maxY, lessThanOrEqualTo(room.maxY + tol), reason: '${p.id} maxY');
      }
    }
    for (final p in Shop3dLayout.floorProps) {
      for (final part in p.parts) {
        expect(part.minX, greaterThanOrEqualTo(room.minX - _eps), reason: p.id);
        expect(part.maxX, lessThanOrEqualTo(room.maxX + _eps), reason: p.id);
        expect(part.minZ, greaterThanOrEqualTo(room.minZ - _eps), reason: p.id);
        expect(part.maxZ, lessThanOrEqualTo(room.maxZ + _eps), reason: p.id);
      }
    }
  });

  test('khối tường nằm trong phòng + độ dày tường', () {
    const out = Shop3dLayout.roomWithWalls;
    Shop3dLayout.walls.forEach((wall, parts) {
      for (final p in parts) {
        expect(p.minX, greaterThanOrEqualTo(out.minX - _eps), reason: '$wall');
        expect(p.maxX, lessThanOrEqualTo(out.maxX + _eps), reason: '$wall');
        expect(p.minY, greaterThanOrEqualTo(out.minY - _eps), reason: '$wall');
        expect(p.maxY, lessThanOrEqualTo(out.maxY + _eps), reason: '$wall');
        expect(p.minZ, greaterThanOrEqualTo(out.minZ - _eps), reason: '$wall');
        expect(p.maxZ, lessThanOrEqualTo(out.maxZ + _eps), reason: '$wall');
      }
    });
  });

  test('đồ trang trí tường gắn sát mặt tường của nó (ẩn / hiện cùng tường khi camera nhìn xuyên)', () {
    // Khoảng cách tối đa từ khối tới mặt trong tường (mét, vào trong phòng): đủ cho kệ lọ, mái hiên mini, bệ cửa.
    const reach = 0.45;
    Shop3dLayout.walls.forEach((wall, parts) {
      for (final p in parts) {
        final inside = switch (wall) {
          RoomWall.back => p.maxZ - room.minZ,
          RoomWall.front => room.maxZ - p.minZ,
          RoomWall.left => p.maxX - room.minX,
          RoomWall.right => room.maxX - p.minX,
          RoomWall.ceiling => room.maxY - p.minY,
        };
        expect(inside, lessThanOrEqualTo(reach), reason: '$wall (${p.cx}, ${p.cy}, ${p.cz})');
      }
    });
  });

  test('bài trí không che nhân vật: đồ treo cao (đèn thả, mái hiên mini) trên 1,8 m; cờ đuôi nheo trên 2,4 m', () {
    final lamps = Shop3dLayout.props.firstWhere((p) => p.id == 'pendantLamps');
    expect(lamps.pickable, isFalse);
    for (final part in lamps.parts) {
      expect(part.minY, greaterThan(1.8));
      expect(part.maxY, lessThanOrEqualTo(room.maxY + _eps));
    }
    for (final wall in [RoomWall.back, RoomWall.left]) {
      // cờ = lăng trụ tam giác mũi xuống (đáy 0); các lăng trụ khác (hình vẽ phấn, hình bóng ảnh bà) không tính
      final flags = Shop3dLayout.walls[wall]!.where((p) => p.shape == Shop3dShape.prism && p.bottomScale == 0).toList();
      expect(flags.length, greaterThan(15), reason: '$wall');
      for (final f in flags) {
        expect(f.minY, greaterThan(2.4), reason: '$wall');
      }
    }
    for (final p in Shop3dLayout.walls[RoomWall.front]!) {
      if ((p.shape == Shop3dShape.prism || p.shape == Shop3dShape.scallop) && p.cz < room.maxZ - 0.1) {
        expect(p.minY, greaterThan(1.8), reason: '(${p.cx}, ${p.cy}, ${p.cz})');
      }
    }
  });

  test('P3: cây nhiều tông xanh, chậu treo trên 1,8 m, rèm gắn tường, hình bóng ảnh bà không có mặt', () {
    // cây: tán lớn + 3 cụm lá nhỏ, ít nhất 4 tông xanh (đậm / vừa / nhạt / bạc hà), chậu có viền
    for (final id in ['plantDoor', 'plantCorner']) {
      final plant = Shop3dLayout.props.firstWhere((p) => p.id == id);
      final balls = plant.parts.where((p) => p.shape == Shop3dShape.sphere).toList();
      expect(balls.length, 4, reason: id);
      expect(
        {for (final b in balls) b.color},
        {Shop3dColor.correct, Shop3dColor.leafDeep, Shop3dColor.leafLight, Shop3dColor.mint},
      );
      expect(plant.parts.where((p) => p.shape == Shop3dShape.cylinder && p.color == Shop3dColor.woodDark), isNotEmpty);
    }
    // đồ nhô khỏi tường trước quá 0,3 m (chậu treo, giá đỡ) chỉ ở trên đầu nhân vật
    for (final p in Shop3dLayout.walls[RoomWall.front]!) {
      if (p.minZ < room.maxZ - 0.3) expect(p.minY, greaterThan(1.8), reason: '(${p.cx}, ${p.cy}, ${p.cz})');
    }
    // rèm: 3 cửa × 2 bên, mỗi rèm hai lăng trụ chính; nằm trong bề dày 10 cm cạnh mặt tường
    final curtains = Shop3dLayout.walls[RoomWall.front]!
        .where((p) => p.shape == Shop3dShape.prism && p.sz == 0.03 && p.maxZ < room.maxZ)
        .toList();
    expect(curtains.length, 12);
    for (final c in curtains) {
      expect(room.maxZ - c.minZ, lessThan(0.1));
    }
    // ảnh bà: hình bóng (đầu, vai, búi tóc) toàn khối mảnh dán nổi 1 cm, không khối nào là cầu (không vẽ mặt)
    final leftWall = Shop3dLayout.walls[RoomWall.left]!;
    final silhouette = leftWall.where((p) => p.sx == 0.01 || (p.shape == Shop3dShape.prism && p.sz == 0.01)).toList();
    expect(silhouette.length, greaterThanOrEqualTo(7));
    for (final p in silhouette) {
      expect(p.shape, isNot(Shop3dShape.sphere));
      expect(p.color, anyOf(Shop3dColor.woodDark, Shop3dColor.chocolate));
    }
    // đèn hải đăng: ≥ 2 nón cụt sọc kem / hồng dâu chồng nhau + đỉnh vàng trên kệ trên cùng (1,86 m)
    final shelf = Shop3dLayout.props.firstWhere((p) => p.id == 'ingredientShelf');
    final cones =
        shelf.parts.where((p) => p.shape == Shop3dShape.cylinder && p.topScale != 1 && p.minY >= 1.86).toList();
    expect(cones.length, greaterThanOrEqualTo(3));
    expect({for (final c in cones) c.color}, containsAll([Shop3dColor.cream, Shop3dColor.strawberry]));
    expect(shelf.parts.where((p) => p.color == Shop3dColor.butter && p.minY >= 1.86), isNotEmpty);
  });

  test('P3: bảng phấn menu toàn khối mảnh (không chữ thật), mặt tiền ngoài cửa nằm ngoài phòng và thấp', () {
    final back = Shop3dLayout.walls[RoomWall.back]!;
    final chalk = back.where(
      (p) =>
          p.cx > 2.6 &&
          p.cx < 4.6 &&
          p.minY > 1.25 &&
          p.maxY < 2.15 &&
          p.shape != Shop3dShape.sphere && // quả dâu trên bánh
          p.color != Shop3dColor.chocolate && // nền bảng
          p.color != Shop3dColor.caramel,
    ); // khung
    expect(chalk.length, greaterThan(40));
    for (final p in chalk) {
      expect(p.sz, lessThanOrEqualTo(0.012), reason: '(${p.cx}, ${p.cy})'); // nét phấn mỏng
      expect(p.color, anyOf(Shop3dColor.cream, Shop3dColor.strawberry, Shop3dColor.butter, Shop3dColor.mint));
    }
    for (final prop in Shop3dLayout.outdoorProps) {
      expect(prop.flat || !prop.pickable, isTrue, reason: prop.id); // không chạm được
      for (final p in prop.parts) {
        expect(p.minZ, greaterThanOrEqualTo(room.maxZ - 0.2 - _eps), reason: prop.id);
        expect(p.maxZ, lessThanOrEqualTo(prop.flat ? 6.9 + _eps : 4.8), reason: prop.id);
        expect(p.maxY, lessThan(1.0), reason: prop.id); // đồ ngoài trời không che khách đứng ở cửa
        if (!prop.flat) {
          // chậu / ghế không lấn khe cửa x ∈ [3,05; 4,15]
          expect(p.maxX <= 3.05 + _eps || p.minX >= 4.15 - _eps, isTrue, reason: '${prop.id} (${p.cx}, ${p.cz})');
        }
      }
    }
  });

  test('tủ kính: nắp trong suốt (không còn tấm nắp đặc che bánh), kệ trên bằng kính', () {
    final c = Shop3dLayout.props.firstWhere((p) => p.id == 'pastryCase');
    // Khối đục phía trên 1,25 m chỉ là thanh khung mảnh / đèn nhỏ.
    for (final part in c.parts.where((e) => e.alpha == 1 && e.minY >= 1.25)) {
      expect(math.min(part.sx, part.sz), lessThanOrEqualTo(0.1), reason: '(${part.cx}, ${part.cy})');
    }
    final shelves = c.parts.where((e) => (e.maxY - Shop3dLayout.caseShelfUpperY).abs() < 1e-9 && e.sx > 2).toList();
    expect(shelves.single.alpha, lessThan(0.5));
  });

  test('các vật thể không chồng lấn nhau (bật hết mọi mở rộng)', () {
    final props = [
      for (final p in Shop3dLayout.props)
        if (!p.flat) p,
    ];
    for (var i = 0; i < props.length; i++) {
      for (var j = i + 1; j < props.length; j++) {
        for (final a in props[i].parts) {
          for (final b in props[j].parts) {
            expect(
              _overlaps(a, b),
              isFalse,
              reason: '${props[i].id} chồng ${props[j].id} (${a.cx},${a.cz}) vs (${b.cx},${b.cz})',
            );
          }
        }
      }
    }
  });

  test('vật thể bật theo owned', () {
    final base = {for (final p in Shop3dLayout.propsFor({})) p.id};
    expect(base, contains('oven1'));
    expect(base, isNot(contains('oven2')));
    expect(base, isNot(contains('seating1')));
    expect(base, isNot(contains('kitchen2Counter')));
    expect(base, isNot(contains('caseStand')));
    final full = {for (final p in Shop3dLayout.propsFor(Shop3dRequires.all)) p.id};
    expect(full, containsAll(['oven2', 'seating1', 'seating3', 'kitchen2Counter', 'kitchen2Island', 'caseStand']));
    expect(Shop3dLayout.seatsFor({}), isEmpty);
    expect(Shop3dLayout.seatsFor({'cafe_tables'}).length, 6);
  });

  test('điểm đứng của khách / nhân viên nằm trong phòng và trên sàn trống', () {
    const r = 0.2; // nửa vai
    final obstacles = _obstacles().toList();
    for (final s in Shop3dLayout.floorSpots) {
      expect(s.y, 0, reason: s.id);
      expect(s.x, inInclusiveRange(room.minX + r, room.maxX - r), reason: '${s.id} ngoài phòng');
      expect(s.z, inInclusiveRange(room.minZ + r, room.maxZ - r), reason: '${s.id} ngoài phòng');
      for (final o in obstacles) {
        expect(
          _distToPart(s.x, s.z, o),
          greaterThanOrEqualTo(r - _eps),
          reason: '${s.id} đụng vật cản tại (${o.cx}, ${o.cz})',
        );
      }
    }
  });

  test('điểm khách xuất hiện ở ngoài cửa, ngay trong cửa là trong phòng', () {
    expect(Shop3dLayout.doorOutside.z, greaterThan(room.maxZ));
    expect(Shop3dLayout.entrance.z, lessThan(room.maxZ));
    expect(Shop3dLayout.entrance.x, closeTo(3.6, 0.6)); // thẳng hàng với cửa
  });

  test('hàng chờ: cách nhau đủ rộng, không chồng chỗ đứng quầy', () {
    final pts = [...Shop3dLayout.queue, ...Shop3dLayout.counterSpots];
    for (var i = 0; i < pts.length; i++) {
      for (var j = i + 1; j < pts.length; j++) {
        final d = math.sqrt(math.pow(pts[i].x - pts[j].x, 2) + math.pow(pts[i].z - pts[j].z, 2));
        expect(d, greaterThanOrEqualTo(0.6), reason: '${pts[i].id} ~ ${pts[j].id}');
      }
    }
  });

  test('chỗ ngồi nằm trên mặt ghế và quay mặt về bàn', () {
    final chairSeats = <Shop3dPart>[];
    for (final p in Shop3dLayout.props.where((p) => p.id.startsWith('seating'))) {
      chairSeats.addAll(p.parts.where((e) => e.shape == Shop3dShape.box && e.sy < 0.07 && e.sx > 0.4));
    }
    expect(chairSeats.length, 6);
    for (final s in Shop3dLayout.seats) {
      final seat = chairSeats.where((c) => (c.cx - s.x).abs() < 0.01 && (c.cz - s.z).abs() < 0.01);
      expect(seat.length, 1, reason: s.id);
      expect(s.y, closeTo(seat.single.maxY, 0.05), reason: s.id);
      expect(room.contains(s.x, s.y, s.z), isTrue);
    }
    // quay về phía bàn (trục x): ghế trái nhìn +x, ghế phải nhìn -x
    for (var i = 0; i < Shop3dLayout.seats.length; i++) {
      final s = Shop3dLayout.seats[i];
      expect(math.sin(s.facingYaw), i.isEven ? 1.0 : -1.0, reason: s.id);
    }
  });

  test('ô tủ kính nằm trong tủ, trên mặt kệ', () {
    final c = Shop3dLayout.props.firstWhere((p) => p.id == 'pastryCase');
    final minX = c.parts.map((e) => e.minX).reduce(math.min);
    final maxX = c.parts.map((e) => e.maxX).reduce(math.max);
    final slots = Shop3dLayout.caseSlotPositions();
    expect(slots.length, 12);
    for (final s in slots) {
      expect(s.x, inInclusiveRange(minX, maxX));
      expect(s.z, closeTo(Shop3dLayout.caseCenterZ, _eps));
      expect(s.y, anyOf(closeTo(Shop3dLayout.caseShelfLowerY, _eps), closeTo(Shop3dLayout.caseShelfUpperY, _eps)));
    }
    // các ô không trùng nhau
    for (var i = 0; i < slots.length; i++) {
      for (var j = i + 1; j < slots.length; j++) {
        expect(slots[i].distanceTo(slots[j]), greaterThan(0.2));
      }
    }
  });

  test('cửa ra vào thông suốt: không khối tường nào chặn lối giữa cửa', () {
    final front = Shop3dLayout.walls[RoomWall.front]!;
    const x = 3.6;
    for (final p in front) {
      final blocksDoor = p.minX < x && p.maxX > x && p.minY < 2.0 && p.maxY > 0.05 && p.alpha == 1;
      expect(blocksDoor, isFalse, reason: 'khối tường chặn cửa tại (${p.cx}, ${p.cy})');
    }
  });

  test('bục đứng: khách trước quầy 0,15–0,20 m, nhân viên sau quầy thu ngân; floorHeightAt khớp bục', () {
    expect(Shop3dLayout.customerStepHeight, inInclusiveRange(0.15, 0.2));
    expect(Shop3dLayout.staffStepHeight, inInclusiveRange(0.15, 0.2));
    for (final s in Shop3dLayout.counterSpots) {
      expect(Shop3dLayout.floorHeightAt(s.x, s.z), Shop3dLayout.customerStepHeight, reason: s.id);
    }
    expect(
      Shop3dLayout.floorHeightAt(Shop3dLayout.staffCashierSide.x, Shop3dLayout.staffCashierSide.z),
      Shop3dLayout.staffStepHeight,
    );
    // Mai nhào bột sau bàn trộn đứng trên bục bếp.
    expect(
      Shop3dLayout.floorHeightAt(Shop3dLayout.staffMixerFar.x, Shop3dLayout.staffMixerFar.z),
      Shop3dLayout.kitchenStepHeight,
    );
    for (final s in [Shop3dLayout.entrance, ...Shop3dLayout.queue.skip(1), Shop3dLayout.exitAisle]) {
      expect(Shop3dLayout.floorHeightAt(s.x, s.z), 0, reason: s.id);
    }
    // Bục là lớp phủ sàn: không chồng lên quầy / tủ (mép bục chạm mép quầy).
    for (final step in Shop3dLayout.steps) {
      for (final p in Shop3dLayout.props.where((p) => !p.flat)) {
        for (final part in p.parts) {
          final ox = math.min(step.maxX, part.maxX) - math.max(step.minX, part.minX);
          final oz = math.min(step.maxZ, part.maxZ) - math.max(step.minZ, part.minZ);
          final oy = math.min(step.maxY, part.maxY) - math.max(step.minY, part.minY);
          expect(ox > 0.02 && oz > 0.02 && oy > 0.02, isFalse, reason: p.id);
        }
      }
    }
  });

  test('màu: khoá bảng màu CLAUDE.md đúng mã', () {
    expect(Shop3dColor.cream.argb, 0xFFFFF4E6);
    expect(Shop3dColor.strawberry.argb, 0xFFF49AB0);
    expect(Shop3dColor.mint.argb, 0xFFA8DCC8);
    expect(Shop3dColor.butter.argb, 0xFFFFD27A);
    expect(Shop3dColor.caramel.argb, 0xFFB9805A);
    expect(Shop3dColor.chocolate.argb, 0xFF5A3E36);
  });
}
