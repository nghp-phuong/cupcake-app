import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../core/city/city_config.dart';
import '../../core/constants.dart';
import '../../l10n/gen/app_localizations.dart';
import '../shop3d/shop3d_toasts.dart';

/// Màu lô theo loại (dùng chung minimap và bản đồ lớn).
Color townLotColor(LotKind k) => switch (k) {
  LotKind.home => AppColors.strawberry,
  LotKind.restaurant => AppColors.butter,
  LotKind.salon => const Color(0xFFC9B3E6),
  LotKind.realty => const Color(0xFF9CC7E8),
  LotKind.park => AppColors.good,
  LotKind.branch => const Color(0xFFD9CBBE),
};

/// Vẽ quận nhìn từ trên: nền, vỉa hè, lòng đường, lô, chấm Mai. x → phải, z → xuống (bắc ở trên).
/// Vị trí/hướng Mai đọc từ ValueListenable khi vẽ; `repaint` quyết định lúc nào vẽ lại.
class TownMapPainter extends CustomPainter {
  TownMapPainter({
    required this.district,
    required this.maiPos,
    this.maiYaw,
    this.dotRadius = 5,
    this.playerLevel,
    this.cornerLock = false,
    super.repaint,
  });

  final DistrictDef district;
  final ValueListenable<Offset> maiPos;
  final ValueListenable<double>? maiYaw;
  final double dotRadius;

  /// Cấp của Mai: lô có `requiresLevel` cao hơn bị tô nhạt và vẽ ổ khoá. null = không phân biệt (hành vi cũ).
  final int? playerLevel;

  /// true: ổ khoá nhỏ (~22% cạnh ngắn) ở góc trên phải lô, để không đè chữ (bản đồ lớn). false: to, giữa lô (minimap).
  final bool cornerLock;

  /// Khung (px) của ổ khoá trong lô [r] — dùng khi vẽ và khi kiểm tra không đè chữ.
  static Rect lockBounds(Rect r, {bool corner = false}) {
    final u = r.shortestSide * (corner ? 0.22 : 0.45);
    final c = corner ? Offset(r.right - u * 0.7, r.top + u * 0.75) : r.center;
    return Rect.fromCenter(center: c, width: u * 0.8, height: u * 1.1);
  }

  /// Hình chữ nhật (px) của lô [l] trong khung [size].
  static Rect lotRect(DistrictDef d, LotDef l, Size size) {
    final a = toPx(d, Offset(l.minX, l.minZ), size);
    final b = toPx(d, Offset(l.maxX, l.maxZ), size);
    return Rect.fromPoints(a, b);
  }

  /// Mét (x, z) → px.
  static Offset toPx(DistrictDef d, Offset m, Size size) => Offset(
    (m.dx - d.minX) / (d.maxX - d.minX) * size.width,
    (m.dy - d.minZ) / (d.maxZ - d.minZ) * size.height,
  );

  @override
  void paint(Canvas canvas, Size size) {
    final d = district;
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFFE9F3E0),
    );
    final sw = Rect.fromPoints(
      toPx(d, Offset(d.minX, -d.sidewalkOuter), size),
      toPx(d, Offset(d.maxX, d.sidewalkOuter), size),
    );
    canvas.drawRect(sw, Paint()..color = const Color(0xFFF1E4D2));
    final road = Rect.fromPoints(
      toPx(d, Offset(d.minX, -d.roadHalfWidth), size),
      toPx(d, Offset(d.maxX, d.roadHalfWidth), size),
    );
    canvas.drawRect(road, Paint()..color = const Color(0xFFB8A99B));
    final dash = Paint()
      ..color = AppColors.cream
      ..strokeWidth = 1.5;
    final y = size.height / 2;
    for (var x = 0.0; x < size.width; x += 12) {
      canvas.drawLine(Offset(x, y), Offset(x + 6, y), dash);
    }
    final fill = Paint();
    final edge = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = AppColors.caramel;
    for (final l in d.lots) {
      final r = lotRect(d, l, size).deflate(1);
      final rr = RRect.fromRectAndRadius(r, const Radius.circular(3));
      final locked = playerLevel != null && l.requiresLevel > playerLevel!;
      final base = townLotColor(l.kind);
      canvas.drawRRect(rr, fill..color = locked ? base.withValues(alpha: 0.55) : base);
      canvas.drawRRect(rr, edge);
      if (locked) _paintLock(canvas, r, cornerLock);
    }
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = AppColors.caramel,
    );
    // Chấm Mai (+ mũi hướng nhìn: yaw 0 = quay về +z, như cửa lô).
    final p = toPx(d, maiPos.value, size);
    final yaw = maiYaw?.value;
    if (yaw != null) {
      final dir = Offset(math.sin(yaw), math.cos(yaw));
      final tip = p + dir * (dotRadius + 6);
      final side = Offset(-dir.dy, dir.dx) * (dotRadius * 0.7);
      final base = p + dir * (dotRadius * 0.4);
      canvas.drawPath(
        Path()
          ..moveTo(tip.dx, tip.dy)
          ..lineTo(base.dx + side.dx, base.dy + side.dy)
          ..lineTo(base.dx - side.dx, base.dy - side.dy)
          ..close(),
        Paint()..color = AppColors.bad,
      );
    }
    canvas.drawCircle(p, dotRadius, Paint()..color = AppColors.bad);
    canvas.drawCircle(
      p,
      dotRadius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = Colors.white,
    );
  }

  /// Ổ khoá bằng path ở giữa [r]: cỡ ~45% cạnh ngắn của lô (thân bo tròn + quai nửa vòng).
  static void _paintLock(Canvas canvas, Rect r, bool corner) {
    final u = r.shortestSide * (corner ? 0.22 : 0.45);
    final c = lockBounds(r, corner: corner).center;
    final body = RRect.fromRectAndRadius(
      Rect.fromCenter(center: c + Offset(0, u * 0.18), width: u * 0.8, height: u * 0.6),
      Radius.circular(u * 0.12),
    );
    final shackleR = u * 0.2;
    final shackleY = body.top;
    final shackle = Path()
      ..moveTo(c.dx - shackleR, shackleY)
      ..lineTo(c.dx - shackleR, shackleY - shackleR * 0.4)
      ..arcToPoint(
        Offset(c.dx + shackleR, shackleY - shackleR * 0.4),
        radius: Radius.circular(shackleR),
      )
      ..lineTo(c.dx + shackleR, shackleY);
    canvas.drawPath(
      shackle,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1.5, u * 0.1)
        ..strokeCap = StrokeCap.round
        ..color = AppColors.chocolate,
    );
    canvas.drawRRect(body, Paint()..color = AppColors.chocolate);
    canvas.drawCircle(body.center, u * 0.07, Paint()..color = AppColors.cream);
  }

  @override
  bool shouldRepaint(TownMapPainter old) =>
      old.playerLevel != playerLevel ||
      old.cornerLock != cornerLock ||
      old.district != district ||
      old.maiPos != maiPos ||
      old.maiYaw != maiYaw ||
      old.dotRadius != dotRadius;
}

/// Bản đồ nhỏ ở góc màn hình; chạm → [onTap] (mở [TownMapSheet]). Vị trí/hướng Mai lấy từ ValueListenable, chỉ vẽ
/// lại tối đa 10 lần/giây ([interval]); không dựng lại cây widget.
class TownMinimap extends StatefulWidget {
  const TownMinimap({
    super.key,
    required this.district,
    required this.maiPos,
    this.maiYaw,
    required this.onTap,
    this.playerLevel,
    this.width = 168,
    this.interval = const Duration(milliseconds: 100),
  });

  final DistrictDef district;

  /// Vị trí Mai (x, z) tính bằng mét.
  final ValueListenable<Offset> maiPos;
  final ValueListenable<double>? maiYaw;
  final VoidCallback onTap;

  /// Cấp của Mai; đổi thì vẽ lại (lô còn khoá có ổ khoá). null = không vẽ khoá.
  final ValueListenable<int>? playerLevel;

  /// Bề ngang (px); bề cao theo tỉ lệ quận.
  final double width;

  /// Khoảng cách tối thiểu giữa hai lần vẽ lại.
  final Duration interval;

  @override
  State<TownMinimap> createState() => _TownMinimapState();
}

class _TownMinimapState extends State<TownMinimap> {
  static final _noLevel = ValueNotifier<int>(0);
  final _tick = ValueNotifier<int>(0);
  final _clock = Stopwatch()..start();
  Timer? _pending;
  Duration _last = const Duration(days: -1);

  @override
  void initState() {
    super.initState();
    _attach(widget);
  }

  void _attach(TownMinimap w) {
    w.maiPos.addListener(_onChange);
    w.maiYaw?.addListener(_onChange);
    w.playerLevel?.addListener(_onLevel);
  }

  void _detach(TownMinimap w) {
    w.maiPos.removeListener(_onChange);
    w.maiYaw?.removeListener(_onChange);
    w.playerLevel?.removeListener(_onLevel);
  }

  void _onLevel() => _tick.value++;

  @override
  void didUpdateWidget(TownMinimap old) {
    super.didUpdateWidget(old);
    if (old.maiPos != widget.maiPos || old.maiYaw != widget.maiYaw || old.playerLevel != widget.playerLevel) {
      _detach(old);
      _attach(widget);
      _tick.value++;
    }
  }

  void _onChange() {
    if (_pending != null) return;
    final wait = widget.interval - (_clock.elapsed - _last);
    if (wait <= Duration.zero) {
      _fire();
    } else {
      _pending = Timer(wait, () {
        _pending = null;
        _fire();
      });
    }
  }

  void _fire() {
    _last = _clock.elapsed;
    _tick.value++;
  }

  @override
  void dispose() {
    _pending?.cancel();
    _detach(widget);
    _tick.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.district;
    final aspect = (d.maxX - d.minX) / (d.maxZ - d.minZ);
    final w = widget.width;
    final h = w / aspect;
    final l = AppLocalizations.of(context);
    return Semantics(
      button: true,
      label: l.townOpenMap,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: Container(
          width: w,
          height: h,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            boxShadow: Shop3dStyle.box().boxShadow,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: RepaintBoundary(
              child: ValueListenableBuilder<int>(
                valueListenable:
                    widget.playerLevel ?? _noLevel,
                builder: (context, level, _) => CustomPaint(
                  painter: TownMapPainter(
                    district: d,
                    maiPos: widget.maiPos,
                    maiYaw: widget.maiYaw,
                    playerLevel: widget.playerLevel == null ? null : level,
                    repaint: _tick,
                  ),
                  size: Size(w, h),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
