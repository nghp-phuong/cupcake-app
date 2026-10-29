import 'dart:math' as math;
import 'dart:ui';

/// Điểm [p] có nằm trên mặt bánh (elip [cakeTop]) nới thêm [snap] px mỗi phía không.
bool isOnCake(Offset p, Rect cakeTop, double snap) {
  final a = cakeTop.width / 2 + math.max(0, snap);
  final b = cakeTop.height / 2 + math.max(0, snap);
  if (a <= 0 || b <= 0) return false;
  final dx = (p.dx - cakeTop.center.dx) / a;
  final dy = (p.dy - cakeTop.center.dy) / b;
  return dx * dx + dy * dy <= 1;
}

/// Kéo [p] vào trong elip [e] thu nhỏ theo hệ số [inset] (0..1) — điểm đã trong thì giữ nguyên.
Offset clampIntoEllipse(Offset p, Rect e, {double inset = 0.85}) {
  final a = e.width / 2 * inset;
  final b = e.height / 2 * inset;
  if (a <= 0 || b <= 0) return e.center;
  final dx = (p.dx - e.center.dx) / a;
  final dy = (p.dy - e.center.dy) / b;
  final k = math.sqrt(dx * dx + dy * dy);
  if (k <= 1) return p;
  return Offset(e.center.dx + dx / k * a, e.center.dy + dy / k * b);
}

/// Toạ độ chuẩn hoá trong elip (tâm = 0, mép = ±1) ↔ toạ độ thật. Dùng để vẽ lại topping đã đặt
/// ở đúng chỗ khi bánh được vẽ ở kích thước khác (trạm hộp, vé đơn).
Offset toEllipseUnit(Offset p, Rect e) =>
    Offset((p.dx - e.center.dx) / (e.width / 2), (p.dy - e.center.dy) / (e.height / 2));

Offset fromEllipseUnit(Offset u, Rect e) =>
    Offset(e.center.dx + u.dx * e.width / 2, e.center.dy + u.dy * e.height / 2);
