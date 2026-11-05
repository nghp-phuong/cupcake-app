import 'dart:math' as math;
import 'dart:typed_data';

import 'chibi_mesh.dart';

/// Khung xương đơn giản của nhân vật chibi — Dart thuần, không phụ thuộc engine.
///
/// Cây khớp: gốc (chân chạm sàn, quay theo yaw) → thân (khớp hông) → đầu (khớp cổ) → mắt (chớp) / phụ kiện đầu
/// (tai thỏ, đuôi ngựa); thân → tay T/P (khớp vai), → đuôi; gốc → chân T/P (khớp hông, không lắc theo thân để chân
/// không xuyên sàn). Mỗi bộ phận là một entity; ma trận thế giới tính hết ở Dart ([ChibiRig.compute]) rồi gửi
/// `setTransform` từng entity (không dùng cha-con của Filament: số lệnh mỗi khung như nhau vì khớp nào cũng động, mà
/// `setParent` của thermion là lệnh bất đồng bộ sang luồng render).
///
/// Mở rộng (chỉ thêm, mặc định giữ nguyên hành vi cũ): đồ cầm tay [ChibiPart.prop] ([ChibiHold]) đi theo bàn tay; thú
/// bốn chân ([ChibiRigSpec.quadruped], mèo Mochi) — tay = chân trước (dựng đứng dù thân ngả), chân sau gắn hông sau,
/// khớp thân ở hông sau ([ChibiRigSpec.hindZ]) để ngồi = ngả thân lên.
///
/// Ma trận 4×4 cột chính (column-major) trong `Float64List(16)`, cùng bố cục `Matrix4.storage` của vector_math → cảnh
/// chép thẳng vào `Matrix4` không cấp phát.

/// Bộ phận = một entity. Thứ tự cố định (chỉ số mảng ma trận).
///
/// Thú bốn chân ([ChibiRigSpec.quadruped]): [armL] / [armR] là hai chân trước, [legL] / [legR] hai chân sau, [extra]
/// là đuôi. [prop]: đồ cầm tay ([ChibiHold]) — gắn vào bàn tay, đi theo chuyển động tay.
enum ChibiPart { body, head, eyes, armL, armR, legL, legR, extra, prop }

/// Đồ cầm tay (bộ phận [ChibiPart.prop]): cây cán bột, khay, bìa kẹp hồ sơ, máy ảnh…
///
/// Lưới đồ dựng trong không gian tư thế nghỉ quanh điểm xoay ([x], [y], [z]) = tâm bàn tay mang đồ. Mỗi khung, vị trí
/// điểm xoay đi theo bàn tay ([side]); hướng thì [level] = chỉ quay theo hướng người (khay luôn nằm ngang, không
/// nghiêng theo tay), không [level] = xoay hẳn theo tay. [twoHands]: hai tay cùng một tư thế (đồ nằm giữa hai bàn
/// tay — cây cán bột, máy ảnh, khay bánh bao); vẫy / vui không giơ tay ra ngang (khoảng cách hai bàn tay giữ nguyên).
class ChibiHold {
  const ChibiHold({
    this.side = -1,
    this.twoHands = false,
    this.level = true,
    this.forward = 0.8,
    this.raise = 0.1,
    this.workForward,
    this.x = 0,
    this.y = 0,
    this.z = 0,
  });

  /// Tay mang lưới đồ: +1 trái (+x), −1 phải.
  final double side;
  final bool twoHands;
  final bool level;

  /// Góc tay khi cầm (đánh về trước / giơ ngang, rad) — thay cho góc đứng / đi của tay cầm đồ.
  final double forward, raise;

  /// Góc đánh về trước khi làm việc ([twoHands]: cả hai tay; ví dụ giơ máy ảnh lên mắt); null = [forward].
  final double? workForward;

  /// Điểm xoay (tâm bàn tay mang đồ ở tư thế nghỉ).
  final double x, y, z;

  ChibiHold scaled(double s) => ChibiHold(
      side: side,
      twoHands: twoHands,
      level: level,
      forward: forward,
      raise: raise,
      workForward: workForward,
      x: x * s,
      y: y * s,
      z: z * s);

  /// Bản có điểm xoay mới (giữ tư thế cầm).
  ChibiHold at(double px, double py, double pz) => ChibiHold(
      side: side,
      twoHands: twoHands,
      level: level,
      forward: forward,
      raise: raise,
      workForward: workForward,
      x: px,
      y: py,
      z: pz);
}

/// Bộ phận phụ ([ChibiPart.extra]) gắn vào đâu và đung đưa thế nào.
enum ChibiExtraKind {
  /// Không có.
  none,

  /// Tai thỏ (gắn đầu, ve vẩy, nảy theo bước).
  ears,

  /// Đuôi (gắn thân, vẫy ngang).
  tail,

  /// Đuôi tóc (gắn đầu, lắc theo bước).
  ponytail,
}

/// Điểm khớp ở tư thế nghỉ (mét, không gian nhân vật: chân ở y = 0, mặt nhìn +z, bên trái nhân vật là +x).
class ChibiRigSpec {
  const ChibiRigSpec({
    this.hipY = 0.34,
    this.legX = 0.085,
    this.neckY = 0.70,
    this.shoulderX = 0.175,
    this.shoulderY = 0.635,
    required this.eyeY,
    required this.eyeZ,
    this.extraX = 0,
    this.extraY = 0,
    this.extraZ = 0,
    this.seatDrop = 0.26,
    this.neckZ = 0,
    this.hindZ = 0,
    this.shoulderZ = 0,
    this.quadruped = false,
    this.hold,
    this.crownY,
  });

  /// Độ cao khớp hông (gốc của thân và hai chân).
  final double hipY;

  /// Nửa khoảng cách hai chân.
  final double legX;

  /// Độ cao khớp cổ (gốc của đầu).
  final double neckY;

  /// Khớp vai (±[shoulderX], [shoulderY], 0).
  final double shoulderX, shoulderY;

  /// Đường tâm hai mắt (0, [eyeY], [eyeZ]): chớp mắt = co lưới mắt theo y quanh đường này.
  final double eyeY, eyeZ;

  /// Khớp bộ phận phụ (tai / đuôi / đuôi tóc).
  final double extraX, extraY, extraZ;

  /// Khoảng từ gốc tới đáy mông: khi ngồi, gốc đặt ở `mặt ghế − seatDrop`.
  final double seatDrop;

  /// Độ lệch z (về trước) của khớp cổ, khớp thân + chân sau ([hindZ]) và khớp vai ([shoulderZ]). Người: 0. Thú bốn
  /// chân: thân nằm ngang, khớp thân ở hông sau (ngồi = ngả thân quanh hông), vai ở phía trước.
  final double neckZ, hindZ, shoulderZ;

  /// Thú bốn chân: tay = chân trước, gắn thân nhưng luôn dựng đứng (không nghiêng theo thân khi ngồi); chân sau nhún
  /// cùng thân; đuôi vẫy ngang bằng Rz (đuôi dựng đứng).
  final bool quadruped;

  /// Đồ cầm tay (bộ phận [ChibiPart.prop]); null = không cầm gì.
  final ChibiHold? hold;

  /// Độ cao đỉnh sọ ở tư thế nghỉ (không tính tai / mũ / búi); null = chưa khai — `ChibiSizes` ước theo mắt (tâm mắt
  /// ở ~0,47 chiều cao đầu tính từ cằm, quy chuẩn cute A2).
  final double? crownY;

  /// Bản phóng đều [s] lần (mọi điểm khớp nhân [s]).
  ChibiRigSpec scaled(double s) => ChibiRigSpec(
        hipY: hipY * s,
        legX: legX * s,
        neckY: neckY * s,
        shoulderX: shoulderX * s,
        shoulderY: shoulderY * s,
        eyeY: eyeY * s,
        eyeZ: eyeZ * s,
        extraX: extraX * s,
        extraY: extraY * s,
        extraZ: extraZ * s,
        seatDrop: seatDrop * s,
        neckZ: neckZ * s,
        hindZ: hindZ * s,
        shoulderZ: shoulderZ * s,
        quadruped: quadruped,
        hold: hold?.scaled(s),
        crownY: crownY == null ? null : crownY! * s,
      );

  /// Bản có đồ cầm tay [h] (giữ mọi điểm khớp khác).
  ChibiRigSpec withHold(ChibiHold? h) => ChibiRigSpec(
        hipY: hipY,
        legX: legX,
        neckY: neckY,
        shoulderX: shoulderX,
        shoulderY: shoulderY,
        eyeY: eyeY,
        eyeZ: eyeZ,
        extraX: extraX,
        extraY: extraY,
        extraZ: extraZ,
        seatDrop: seatDrop,
        neckZ: neckZ,
        hindZ: hindZ,
        shoulderZ: shoulderZ,
        quadruped: quadruped,
        hold: h,
        crownY: crownY,
      );

  /// Điểm xoay của [part] ở tư thế nghỉ.
  (double, double, double) pivotOf(ChibiPart part) => switch (part) {
        ChibiPart.body => (0, hipY, hindZ),
        ChibiPart.head => (0, neckY, neckZ),
        ChibiPart.eyes => (0, eyeY, eyeZ),
        ChibiPart.armL => (shoulderX, shoulderY, shoulderZ),
        ChibiPart.armR => (-shoulderX, shoulderY, shoulderZ),
        ChibiPart.legL => (legX, hipY, hindZ),
        ChibiPart.legR => (-legX, hipY, hindZ),
        ChibiPart.extra => (extraX, extraY, extraZ),
        ChibiPart.prop => (hold?.x ?? 0, hold?.y ?? 0, hold?.z ?? 0),
      };
}

/// Dáng đi / tính cách chuyển động.
class ChibiGait {
  const ChibiGait({
    this.speed = 0.9,
    this.legSwing = 0.46,
    this.armSwing = 0.55,
    this.stride = 0.5,
    this.waddle = 0.07,
    this.bob = 0.035,
    this.lean = 0.0,
    this.cane = false,
    this.armUp,
  });

  /// Tốc độ đi (m/s).
  final double speed;

  /// Biên độ đánh chân / tay khi đi (rad).
  final double legSwing, armSwing;

  /// Quãng đường một chu kỳ bước (2 bước), m.
  final double stride;

  /// Lắc trái phải (rad) — lạch bạch.
  final double waddle;

  /// Nhún lên xuống (m), 2 lần mỗi chu kỳ.
  final double bob;

  /// Gù / nghiêng thân về trước thường trực (rad) — ông Hòa.
  final double lean;

  /// Chống gậy bằng tay phải: tay phải gần như đứng yên, chỉ nhích theo nhịp bước; vẫy / vui bằng tay trái.
  final bool cane;

  /// Góc giơ tay tối đa khi vui / vẫy (rad); null = mặc định của `ChibiActor` (~2,55). Đầu to hơn vai nhiều (thú
  /// nhỏ) thì giơ thấp hơn để bàn tay không cắm vào má.
  final double? armUp;

  /// Bản phóng đều [s] lần (bước dài và độ nhún theo kích thước; tốc độ giữ nguyên).
  ChibiGait scaled(double s) => ChibiGait(
      speed: speed,
      legSwing: legSwing,
      armSwing: armSwing,
      stride: stride * s,
      waddle: waddle,
      bob: bob * s,
      lean: lean,
      cane: cane,
      armUp: armUp);
}

/// Một nhân vật đã dựng: lưới từng bộ phận (không gian cục bộ của khớp) + khung xương + dáng đi.
class ChibiModel {
  ChibiModel({
    required this.id,
    required this.meshes,
    required this.rig,
    this.gait = const ChibiGait(),
    this.extraKind = ChibiExtraKind.none,
    this.radius = 0.27,
    this.fitted = false,
  }) : height = _height(meshes, rig);

  final String id;

  /// Lưới mỗi bộ phận; bộ phận không có (ví dụ [ChibiPart.extra] của ông Hòa) thì vắng.
  final Map<ChibiPart, ChibiMesh> meshes;
  final ChibiRigSpec rig;
  final ChibiGait gait;
  final ChibiExtraKind extraKind;

  /// Bán kính chiếm chỗ trên sàn (hộp chạm, tránh nhau).
  final double radius;

  /// Điểm cao nhất ở tư thế nghỉ (gồm tai / mũ).
  final double height;

  /// Đã đưa về kích thước trong cảnh theo bảng chiều cao so với Mai (`ChibiSizes.fit`); false = kích thước dựng gốc.
  final bool fitted;

  int get entityCount => meshes.length;
  int get triangleCount => meshes.values.fold(0, (s, m) => s + m.triangleCount);

  static double _height(Map<ChibiPart, ChibiMesh> meshes, ChibiRigSpec rig) {
    var top = 0.0;
    for (final e in meshes.entries) {
      final (_, py, _) = rig.pivotOf(e.key);
      top = math.max(top, py + e.value.maxY);
    }
    return top;
  }
}

/// Tư thế của một khung: vị trí gốc + góc các khớp (rad). Cảnh / máy trạng thái ghi vào, [ChibiRig] đọc ra.
class ChibiPose {
  double x = 0, y = 0, z = 0, yaw = 0;

  /// Thân: nhún (m), lắc ngang (Rz), cúi (Rx, dương = cúi về trước), co giãn theo y (thở / nhún).
  double bob = 0, roll = 0, lean = 0, bodyScaleY = 1;

  /// Đầu: quay (Ry), gật (Rx, dương = cúi), nghiêng (Rz).
  double headYaw = 0, headNod = 0, headTilt = 0;

  /// Độ mở mắt (1 = mở, ~0,1 = nhắm).
  double eyeOpen = 1;

  /// Tay: đánh về trước (dương = ra trước), giơ sang ngang (dương = giơ ra ngoài / lên).
  double armSwingL = 0, armSwingR = 0, armRaiseL = 0, armRaiseR = 0;

  /// Chân: đánh về trước (dương = ra trước).
  double legSwingL = 0, legSwingR = 0;

  /// Bộ phận phụ: hai góc (ý nghĩa theo [ChibiExtraKind]).
  double extraA = 0, extraB = 0;
}

/// Phép toán ma trận 4×4 cột chính trên `Float64List(16)`, sửa tại chỗ — không cấp phát.
abstract final class ChibiM4 {
  static Float64List create() => Float64List(16)
    ..[0] = 1
    ..[5] = 1
    ..[10] = 1
    ..[15] = 1;

  static void identity(Float64List m) {
    m.fillRange(0, 16, 0);
    m[0] = m[5] = m[10] = m[15] = 1;
  }

  static void copy(Float64List dst, Float64List src) => dst.setRange(0, 16, src);

  /// m = m · T(x, y, z).
  static void translate(Float64List m, double x, double y, double z) {
    m[12] += m[0] * x + m[4] * y + m[8] * z;
    m[13] += m[1] * x + m[5] * y + m[9] * z;
    m[14] += m[2] * x + m[6] * y + m[10] * z;
  }

  /// m = m · Rx(a) (cùng chiều `Matrix4.rotationX`: +y quay về +z).
  static void rotateX(Float64List m, double a) {
    if (a == 0) return;
    final c = math.cos(a), s = math.sin(a);
    for (var i = 0; i < 3; i++) {
      final y = m[4 + i], z = m[8 + i];
      m[4 + i] = c * y + s * z;
      m[8 + i] = -s * y + c * z;
    }
  }

  /// m = m · Ry(a) (+z quay về +x).
  static void rotateY(Float64List m, double a) {
    if (a == 0) return;
    final c = math.cos(a), s = math.sin(a);
    for (var i = 0; i < 3; i++) {
      final x = m[i], z = m[8 + i];
      m[i] = c * x - s * z;
      m[8 + i] = s * x + c * z;
    }
  }

  /// m = m · Rz(a) (+x quay về +y).
  static void rotateZ(Float64List m, double a) {
    if (a == 0) return;
    final c = math.cos(a), s = math.sin(a);
    for (var i = 0; i < 3; i++) {
      final x = m[i], y = m[4 + i];
      m[i] = c * x + s * y;
      m[4 + i] = -s * x + c * y;
    }
  }

  /// m = m · S(x, y, z).
  static void scale(Float64List m, double x, double y, double z) {
    for (var i = 0; i < 3; i++) {
      m[i] *= x;
      m[4 + i] *= y;
      m[8 + i] *= z;
    }
  }

  /// Áp m lên điểm (x, y, z).
  static (double, double, double) transformPoint(Float64List m, double x, double y, double z) => (
        m[0] * x + m[4] * y + m[8] * z + m[12],
        m[1] * x + m[5] * y + m[9] * z + m[13],
        m[2] * x + m[6] * y + m[10] * z + m[14]
      );
}

/// Tính ma trận thế giới mọi bộ phận từ [ChibiPose]. Giữ sẵn bộ đệm — gọi mỗi khung không cấp phát.
class ChibiRig {
  ChibiRig(this.spec);

  final ChibiRigSpec spec;

  /// Ma trận thế giới theo thứ tự [ChibiPart] (đọc sau [compute]).
  final List<Float64List> world = List.generate(ChibiPart.values.length, (_) => ChibiM4.create());

  final Float64List _root = ChibiM4.create();
  final Float64List _body = ChibiM4.create();

  Float64List operator [](ChibiPart p) => world[p.index];

  void compute(ChibiPose p) {
    final s = spec;
    // Gốc.
    final root = _root;
    ChibiM4.identity(root);
    ChibiM4.translate(root, p.x, p.y, p.z);
    ChibiM4.rotateY(root, p.yaw);

    // Thân (không co giãn — khung cho đầu / tay / đuôi).
    final body = _body;
    ChibiM4.copy(body, root);
    ChibiM4.translate(body, 0, s.hipY + p.bob, s.hindZ);
    ChibiM4.rotateZ(body, p.roll);
    ChibiM4.rotateX(body, p.lean);
    final bodyMesh = world[ChibiPart.body.index];
    ChibiM4.copy(bodyMesh, body);
    ChibiM4.scale(bodyMesh, 1 + (1 - p.bodyScaleY) * 0.5, p.bodyScaleY, 1 + (1 - p.bodyScaleY) * 0.5);

    // Thân co giãn theo y → đầu / vai nhích theo (để đầu không chìm vào thân khi thở / nhún).
    final stretch = p.bodyScaleY;

    final head = world[ChibiPart.head.index];
    ChibiM4.copy(head, body);
    ChibiM4.translate(head, 0, (s.neckY - s.hipY) * stretch, s.neckZ - s.hindZ);
    ChibiM4.rotateY(head, p.headYaw);
    ChibiM4.rotateX(head, p.headNod);
    ChibiM4.rotateZ(head, p.headTilt);

    final eyes = world[ChibiPart.eyes.index];
    ChibiM4.copy(eyes, head);
    ChibiM4.translate(eyes, 0, s.eyeY - s.neckY, s.eyeZ - s.neckZ);
    ChibiM4.scale(eyes, 1, p.eyeOpen.clamp(0.05, 1.2), 1);

    _arm(world[ChibiPart.armL.index], body, 1, p.armSwingL, p.armRaiseL, stretch, p.lean);
    _arm(world[ChibiPart.armR.index], body, -1, p.armSwingR, p.armRaiseR, stretch, p.lean);
    _leg(world[ChibiPart.legL.index], root, 1, p.legSwingL, p.bob);
    _leg(world[ChibiPart.legR.index], root, -1, p.legSwingR, p.bob);

    final extra = world[ChibiPart.extra.index];
    ChibiM4.copy(extra, head);
    ChibiM4.translate(extra, s.extraX, s.extraY - s.neckY, s.extraZ - s.neckZ);
    ChibiM4.rotateX(extra, p.extraA);
    ChibiM4.rotateZ(extra, p.extraB);

    final hold = s.hold;
    if (hold != null) _prop(hold);
  }

  void _arm(Float64List m, Float64List body, double sign, double swing, double raise, double stretch, double lean) {
    final s = spec;
    ChibiM4.copy(m, body);
    ChibiM4.translate(m, sign * s.shoulderX, (s.shoulderY - s.hipY) * stretch, s.shoulderZ - s.hindZ);
    // Chân trước của thú bốn chân luôn dựng đứng: bù độ ngả của thân (ngồi = thân ngửa lên, chân trước vẫn chống
    // thẳng xuống sàn).
    if (s.quadruped) ChibiM4.rotateX(m, -lean);
    // Giơ ngang: tay trái (+x) quay +z, tay phải ngược lại. Rồi đánh trước / sau quanh trục x của tay.
    ChibiM4.rotateZ(m, sign * raise);
    ChibiM4.rotateX(m, -swing);
  }

  void _leg(Float64List m, Float64List root, double sign, double swing, double bob) {
    final s = spec;
    ChibiM4.copy(m, root);
    // Thú bốn chân: chân sau hạ gần hết theo hông (ngồi = bob âm, đùi gập ra trước nằm trên sàn, không lún sâu).
    ChibiM4.translate(m, sign * s.legX, s.hipY + bob * (s.quadruped ? 0.8 : 0.6), s.hindZ);
    ChibiM4.rotateX(m, -swing);
  }

  /// Đồ cầm tay: điểm xoay đi theo bàn tay [ChibiHold.side]; [ChibiHold.level] = hướng chỉ theo yaw của gốc.
  void _prop(ChibiHold hold) {
    final s = spec;
    final arm = hold.side > 0 ? ChibiPart.armL : ChibiPart.armR;
    final m = world[ChibiPart.prop.index];
    ChibiM4.copy(m, world[arm.index]);
    final (ax, ay, az) = s.pivotOf(arm);
    ChibiM4.translate(m, hold.x - ax, hold.y - ay, hold.z - az);
    if (hold.level) {
      // Giữ vị trí, thay phần xoay bằng phần xoay của gốc (chỉ yaw).
      for (var i = 0; i < 3; i++) {
        m[i] = _root[i];
        m[4 + i] = _root[4 + i];
        m[8 + i] = _root[8 + i];
      }
    }
  }

  /// Ghi đè ma trận đuôi (gắn thân thay vì đầu): gọi sau [compute] cho [ChibiExtraKind.tail]. Người / thú hai chân:
  /// vẫy ngang bằng Ry (đuôi chĩa ra sau); thú bốn chân: Rz (đuôi dựng đứng).
  void attachExtraToBody(ChibiPose p) {
    final s = spec;
    final extra = world[ChibiPart.extra.index];
    ChibiM4.copy(extra, _body);
    ChibiM4.translate(extra, s.extraX, s.extraY - s.hipY, s.extraZ - s.hindZ);
    if (s.quadruped) {
      ChibiM4.rotateZ(extra, p.extraA);
    } else {
      ChibiM4.rotateY(extra, p.extraA);
    }
    ChibiM4.rotateX(extra, p.extraB);
  }
}

/// Hộp bao thế giới gần đúng của nhân vật tại [pose] (trụ bán kính [ChibiModel.radius], cao [ChibiModel.height]).
({double minX, double minY, double minZ, double maxX, double maxY, double maxZ}) chibiBounds(
        ChibiModel model, ChibiPose pose) =>
    (
      minX: pose.x - model.radius,
      minY: pose.y,
      minZ: pose.z - model.radius,
      maxX: pose.x + model.radius,
      maxY: pose.y + model.height * pose.bodyScaleY.clamp(1.0, 1.2) + pose.bob,
      maxZ: pose.z + model.radius
    );

/// Tiện ích dựng: ellipsoid dùng cho đặt chi tiết lên bề mặt (mắt, má, kính, túi tạp dề…).
class ChibiSurface {
  const ChibiSurface(this.cx, this.cy, this.cz, this.rx, this.ry, this.rz);

  final double cx, cy, cz, rx, ry, rz;

  /// Điểm trên bề mặt theo hướng góc phương vị [azDeg] (0 = +z, dương về +x — bên trái nhân vật) và góc cao [elDeg],
  /// nhô ra ngoài [lift] theo pháp tuyến. Trả về (điểm, cơ sở có z = pháp tuyến).
  (double, double, double, ChibiBasis) at(double azDeg, double elDeg, {double lift = 0}) {
    final az = azDeg * math.pi / 180, el = elDeg * math.pi / 180;
    final dx = math.sin(az) * math.cos(el), dy = math.sin(el), dz = math.cos(az) * math.cos(el);
    final t = 1 / math.sqrt(math.pow(dx / rx, 2) + math.pow(dy / ry, 2) + math.pow(dz / rz, 2));
    final px = dx * t, py = dy * t, pz = dz * t;
    var nx = px / (rx * rx), ny = py / (ry * ry), nz = pz / (rz * rz);
    final nl = math.sqrt(nx * nx + ny * ny + nz * nz);
    nx /= nl;
    ny /= nl;
    nz /= nl;
    return (cx + px + nx * lift, cy + py + ny * lift, cz + pz + nz * lift, ChibiBasis.facing(nx, ny, nz));
  }
}
