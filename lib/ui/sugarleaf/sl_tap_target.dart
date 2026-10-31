import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import '../../core/constants.dart';

/// Vùng chạm tối thiểu theo chuẩn Android (dp thật trên máy).
const double kSLMinTapDp = 48;

/// Vùng chạm ≥ 48 dp thật dù khung 1280×720 bị co (UI-01): điện thoại ngang ~360–411 dp cao → hệ số 0,5–0,57,
/// nút 54 px tham chiếu chỉ còn 27–31 dp. Không phóng to hình nút (giữ bố cục): [SLTapTarget] chỉ nới VÙNG CHẠM —
/// semantics (rect nút đọc màn hình) và hit test qua [SLTapTargetScope] ở gốc cây.
///
/// Cỡ cần nới tính theo phép biến đổi thật từ nút lên scope (scope nằm ngoài RefFrame, toạ độ = dp). Scope còn đọc cỡ màn
/// thật (`min(w/1280, h/720)`) để báo nút tính lại semantics khi cỡ màn / mật độ đổi.
class SLTapTargetScope extends StatelessWidget {
  const SLTapTargetScope({super.key, required this.child});

  final Widget child;

  /// Số px tham chiếu cần để đạt [kSLMinTapDp] dp thật (1 dp = `scale` px tham chiếu sau co). Không có scope → 48.
  static double minRefSizeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_SLTapScale>()?.minRefSize ?? kSLMinTapDp;

  /// Đã có scope phía trên (SLScope bên trong khung không đặt lại — MediaQuery ở đó là 1280×720 giả).
  static bool isInstalled(BuildContext context) => context.getInheritedWidgetOfExactType<_SLTapScale>() != null;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.maybeSizeOf(context);
    var scale = 1.0;
    if (size != null && size.width > 0 && size.height > 0) {
      scale = math.min(size.width / kRefSize.width, size.height / kRefSize.height);
    }
    // +1% để không rơi sát ngưỡng vì sai số làm tròn.
    final minRef = kSLMinTapDp * 1.01 / scale;
    return _SLTapScale(
      minRefSize: minRef,
      child: _SLTapHitScope(child: child),
    );
  }
}

class _SLTapScale extends InheritedWidget {
  const _SLTapScale({required this.minRefSize, required super.child});

  final double minRefSize;

  @override
  bool updateShouldNotify(_SLTapScale oldWidget) => oldWidget.minRefSize != minRefSize;
}

/// Bọc một nút: hình giữ nguyên cỡ, vùng chạm (semantics + hit test) nới đều hai phía tới ≥ 48 dp thật.
/// Nút đã đủ lớn thì không nới. Nút tắt ([enabled] false) không nhận chạm nới (không giành chạm của nút bên cạnh).
class SLTapTarget extends SingleChildRenderObjectWidget {
  const SLTapTarget({super.key, this.enabled = true, required super.child});

  final bool enabled;

  @override
  RenderSLTapTarget createRenderObject(BuildContext context) =>
      RenderSLTapTarget(minSize: SLTapTargetScope.minRefSizeOf(context), enabled: enabled);

  @override
  void updateRenderObject(BuildContext context, RenderSLTapTarget renderObject) {
    renderObject
      ..minSize = SLTapTargetScope.minRefSizeOf(context)
      ..enabled = enabled;
  }
}

/// Vùng không được nới chạm từ nút bên cạnh (vd. sân Flame: chạm nhanh ở bếp gần nút HUD không được thành bấm nút).
class SLNoTapExpand extends SingleChildRenderObjectWidget {
  const SLNoTapExpand({super.key, required super.child});

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderNoTapExpand();
}

class _RenderNoTapExpand extends RenderProxyBox {}

/// Các nút đang gắn vào cây (để scope tìm nút gần nhất). Vài chục phần tử, chỉ duyệt khi chạm trượt khỏi mọi nút.
final Set<RenderSLTapTarget> _targets = {};

class RenderSLTapTarget extends RenderProxyBox {
  RenderSLTapTarget({required double minSize, bool enabled = true}) : _minSize = minSize, _enabled = enabled;

  bool _enabled;
  bool get enabled => _enabled;
  set enabled(bool v) {
    if (v == _enabled) return;
    _enabled = v;
    if (!attached) return;
    if (v) {
      _targets.add(this);
    } else {
      _targets.remove(this);
    }
  }

  double _minSize;
  double get minSize => _minSize;
  set minSize(double v) {
    if (v == _minSize) return;
    _minSize = v;
    // Rect của node do node cha tính (geometry) → đánh dấu cả cha để tính lại.
    markNeedsSemanticsUpdate();
    parent?.markNeedsSemanticsUpdate();
  }

  /// Vùng chạm (toạ độ của nút): hình nút nới đều hai phía tới ≥ 48 dp thật. Cỡ cần tính theo phép biến đổi thật từ
  /// nút lên scope (khung co + FittedBox co chữ… ở giữa); không có scope → [minSize] px. Phần nới bị cắt bởi khung /
  /// vùng clip (vd. nút sát mép khung 1280×720) thì dồn sang phía còn lại, vẫn phủ hình nút.
  Rect get touchRect {
    final base = Offset.zero & size;
    var needW = _minSize, needH = _minSize;
    final scope = _scope();
    if (scope != null) {
      final unit = MatrixUtils.transformRect(getTransformTo(scope), const Rect.fromLTWH(0, 0, 1, 1));
      if (unit.width <= 1e-6 || unit.height <= 1e-6) return base;
      needW = kSLMinTapDp * 1.01 / unit.width;
      needH = kSLMinTapDp * 1.01 / unit.height;
    }
    final dx = math.max(0.0, (needW - size.width) / 2);
    final dy = math.max(0.0, (needH - size.height) / 2);
    if (dx == 0 && dy == 0) return base;
    var r = Rect.fromLTRB(-dx, -dy, size.width + dx, size.height + dy);
    final clip = scope == null ? null : _clipRect(scope);
    if (clip != null) {
      double shift(double lo, double hi, double clipLo, double clipHi, double extent) {
        if (hi - lo > clipHi - clipLo) return 0;
        final want = lo < clipLo ? clipLo - lo : (hi > clipHi ? clipHi - hi : 0.0);
        // Vẫn phủ hình nút: lo + d ≤ 0, hi + d ≥ extent.
        return want.clamp(extent - hi, -lo).toDouble();
      }

      r = r.translate(
        shift(r.left, r.right, clip.left, clip.right, size.width),
        shift(r.top, r.bottom, clip.top, clip.bottom, size.height),
      );
    }
    return r;
  }

  RenderObject? _scope() {
    for (var p = parent; p != null; p = p.parent) {
      if (p is _RenderSLTapHitScope) return p;
    }
    return null;
  }

  /// Giao các vùng clip (vẽ + semantics, vd. khung cuộn) của tổ tiên tới scope, quy về toạ độ của nút.
  Rect? _clipRect(RenderObject scope) {
    Rect? clip;
    RenderObject child = this;
    for (var p = parent; p != null; p = p.parent) {
      for (final c in [p.describeApproximatePaintClip(child), p.describeSemanticsClip(child)]) {
        if (c == null) continue;
        final local = MatrixUtils.inverseTransformRect(getTransformTo(p), c);
        clip = clip?.intersect(local) ?? local;
      }
      if (identical(p, scope)) break;
      child = p;
    }
    return clip;
  }

  @override
  Rect get semanticBounds => touchRect;

  @override
  void describeSemanticsConfiguration(SemanticsConfiguration config) {
    super.describeSemanticsConfiguration(config);
    // Một node riêng cho nút (gộp nhãn/hành động của Semantics bên trong) → rect node = vùng chạm đã nới.
    config.isSemanticBoundary = true;
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    if (_enabled) _targets.add(this);
  }

  @override
  void detach() {
    _targets.remove(this);
    super.detach();
  }
}

class _SLTapHitScope extends SingleChildRenderObjectWidget {
  const _SLTapHitScope({required super.child});

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderSLTapHitScope();
}

/// Chạm không trúng nút nào nhưng rơi vào vùng chạm nới của một nút → nút đó nhận chạm (đứng ĐẦU đường hit test để
/// thắng các tap khác như nền hộp thoại), các widget bên dưới vẫn nhận sự kiện như thường (cuộn, kéo).
/// Nhiều vùng nới chồng nhau → nút có hình gần điểm chạm nhất (bằng nhau → tâm gần hơn).
class _RenderSLTapHitScope extends RenderProxyBox {
  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    if (_targets.isNotEmpty && size.contains(position)) {
      final probe = BoxHitTestResult();
      super.hitTest(probe, position: position);
      if (!probe.path.any((e) => e.target is RenderSLTapTarget || e.target is _RenderNoTapExpand)) {
        final t = _nearest(position);
        if (t != null) {
          result.addWithPaintTransform(
            transform: t.getTransformTo(this),
            position: position,
            // Kẹp điểm chạm vào trong hình nút.
            hitTest: (r, local) => t.hitTest(
              r,
              position: Offset(
                local.dx.clamp(0.0, math.max(0.0, t.size.width - 0.01)),
                local.dy.clamp(0.0, math.max(0.0, t.size.height - 0.01)),
              ),
            ),
          );
        }
      }
    }
    return super.hitTest(result, position: position);
  }

  RenderSLTapTarget? _nearest(Offset position) {
    RenderSLTapTarget? best;
    var bestEdge = double.infinity, bestCenter = double.infinity;
    for (final t in _targets.toList()) {
      if (!t.attached || !t.hasSize || t.size.isEmpty || !_isAncestorOf(t)) continue;
      final m = t.getTransformTo(this);
      if (!MatrixUtils.transformRect(m, t.touchRect).contains(position)) continue;
      final box = MatrixUtils.transformRect(m, Offset.zero & t.size);
      final edge = _distance(box, position);
      final center = (box.center - position).distance;
      if (edge > bestEdge || (edge == bestEdge && center >= bestCenter)) continue;
      // Nút phải thật sự chạm được ở tâm (không bị hộp thoại / route khác che, không Offstage / IgnorePointer).
      final check = BoxHitTestResult();
      super.hitTest(check, position: box.center);
      if (!check.path.any((e) => identical(e.target, t))) continue;
      best = t;
      bestEdge = edge;
      bestCenter = center;
    }
    return best;
  }

  bool _isAncestorOf(RenderObject node) {
    for (RenderObject? p = node.parent; p != null; p = p.parent) {
      if (identical(p, this)) return true;
    }
    return false;
  }

  static double _distance(Rect r, Offset p) {
    final dx = math.max(0.0, math.max(r.left - p.dx, p.dx - r.right));
    final dy = math.max(0.0, math.max(r.top - p.dy, p.dy - r.bottom));
    return math.sqrt(dx * dx + dy * dy);
  }
}
