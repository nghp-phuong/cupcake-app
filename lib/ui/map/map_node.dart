import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../common/art.dart';
import '../sugarleaf/sugarleaf.dart';
import 'map_art.dart';

/// Trạng thái hiển thị của một nút level trên bản đồ.
enum MapNodeState { locked, open, completed }

/// Kích thước + vị trí các phần của nút level (dùng chung cho nút và lớp hoạt cảnh sao bay / ổ khoá rơi).
abstract final class MapNodeGeometry {
  /// Khoảng dành cho lá cờ phía trên đĩa.
  static const flagSpace = 34.0;

  static double disc(bool special) => special ? 98 : 76;
  static double star(bool special) => special ? 32 : 28;

  /// Hộp của cả nút (cờ + đĩa + hàng sao đè mép dưới đĩa), tâm đĩa ở [discCenter].
  static Size box(bool special) => Size(disc(special) + 56, flagSpace + disc(special) + star(special) * 0.6 + 6);

  static Offset discCenter(bool special) => Offset(box(special).width / 2, flagSpace + disc(special) / 2);

  /// Tâm ngôi sao thứ [i] (0..2) so với tâm đĩa: hàng sao vắt ngang mép dưới đĩa (gọn, nút sát mép màn vẫn đủ
  /// chỗ), sao giữa nhô cao hơn một chút.
  static Offset starOffset(int i, bool special) {
    final s = star(special);
    return Offset((i - 1) * s, disc(special) / 2 + s * 0.02 - (i == 1 ? s * 0.2 : 0));
  }
}

/// Nút level tròn vẽ tay: đĩa màu nước (khoá: giấy xám + ổ khoá; mở: vàng bơ; đã qua: bạc hà; level đặc biệt: hồng
/// dâu, to hơn, vành vàng bơ, sao lớn đính góc), số level, 3 sao nhỏ trên mẩu giấy (đạt / chưa). Nút "đang tới"
/// ([current]) nhịp to-nhỏ vài lần mỗi khi [pulseKey] đổi rồi đứng yên (không lặp vô hạn) + lá cờ cắm cạnh.
/// Nhịp chỉ vẽ lại phần nút (AnimatedBuilder cục bộ trong RepaintBoundary), không dựng lại bản đồ.
class MapLevelNode extends StatelessWidget {
  const MapLevelNode({
    super.key,
    required this.levelId,
    required this.state,
    required this.stars,
    required this.special,
    required this.current,
    required this.semanticLabel,
    required this.onPressed,
    this.pulseKey = 0,
    this.popKey,
  });

  final int levelId;
  final MapNodeState state;
  final int stars;
  final bool special;
  final bool current;
  final String semanticLabel;
  final VoidCallback onPressed;

  /// Đổi → nhịp lại (nút đang tới).
  final int pulseKey;

  /// Khác null và đổi → nảy một lần (sao mới vừa đáp / vừa mở khoá).
  final Object? popKey;

  static const pulseCycles = 5;

  /// Độ mờ đĩa màn chưa mở.
  static const lockedOpacity = 0.72;

  /// Bề rộng vòng sáng quanh đĩa màn đang tới.
  static const glow = 14.0;
  static const pulsePeriod = Duration(milliseconds: 1100);

  @override
  Widget build(BuildContext context) {
    final box = MapNodeGeometry.box(special);
    final center = MapNodeGeometry.discCenter(special);
    final d = MapNodeGeometry.disc(special);
    final s = MapNodeGeometry.star(special);
    final locked = state == MapNodeState.locked;
    final seed = 0x4A90 + levelId * 7;

    Widget disc = SLPressable(
      onPressed: onPressed,
      semanticLabel: semanticLabel,
      builder: (context, press) => _Disc(
        levelId: levelId,
        state: state,
        special: special,
        size: d,
        seed: seed,
        press: press,
      ),
    );
    if (popKey != null && !slReduceMotion(context)) {
      disc = TweenAnimationBuilder<double>(
        key: ValueKey(popKey),
        tween: Tween(begin: 1.22, end: 1),
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeOutBack,
        builder: (context, t, child) => Transform.scale(scale: t, child: child),
        child: disc,
      );
    }
    final pulse = current && !locked;
    if (pulse) disc = _Pulse(pulseKey: pulseKey, child: disc);
    // Màn chưa mở: mờ hơn để màn đã mở / đang tới nổi bật trên ảnh bản đồ.
    if (locked) disc = Opacity(opacity: MapLevelNode.lockedOpacity, child: disc);

    return SizedBox(
      width: box.width,
      height: box.height,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Màn đang tới: vòng sáng vàng bơ nhẹ (tĩnh) quanh đĩa.
          if (pulse)
            Positioned(
              left: center.dx - d / 2 - MapLevelNode.glow,
              top: center.dy - d / 2 - MapLevelNode.glow,
              width: d + MapLevelNode.glow * 2,
              height: d + MapLevelNode.glow * 2,
              child: const IgnorePointer(
                child: DecoratedBox(
                  key: ValueKey('map-node-glow'),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [Color(0xCCFFE8B5), Color(0x99FFD27A), Color(0x00FFD27A)],
                      stops: [0.55, 0.72, 1],
                    ),
                  ),
                ),
              ),
            ),
          Positioned(left: center.dx - d / 2, top: center.dy - d / 2, width: d, height: d, child: disc),
          if (!locked)
            Positioned(
              left: center.dx + MapNodeGeometry.starOffset(0, special).dx - s / 2 - _StarStrip.pad,
              top: center.dy + MapNodeGeometry.starOffset(0, special).dy - s / 2 - _StarStrip.padTop,
              child: IgnorePointer(child: ExcludeSemantics(child: _StarStrip(stars: stars, special: special, seed: seed))),
            ),
          if (special)
            Positioned(
              left: center.dx - d / 2 - 10,
              top: center.dy - d / 2 - 12,
              child: IgnorePointer(
                child: Transform.rotate(angle: -0.25, child: StarIcon(size: 40, filled: !locked)),
              ),
            ),
          if (pulse)
            Positioned(
              left: center.dx + d * 0.18,
              top: center.dy - d / 2 - MapNodeGeometry.flagSpace + 4,
              child: IgnorePointer(child: _Pulse(pulseKey: pulseKey, bob: true, child: const MapFlag())),
            ),
        ],
      ),
    );
  }
}

/// Đĩa tròn của nút: vành vàng bơ (level đặc biệt) + đĩa màu nước + số / ổ khoá.
class _Disc extends StatelessWidget {
  const _Disc({
    required this.levelId,
    required this.state,
    required this.special,
    required this.size,
    required this.seed,
    required this.press,
  });

  final int levelId;
  final MapNodeState state;
  final bool special;
  final double size;
  final int seed;
  final Animation<double> press;

  @override
  Widget build(BuildContext context) {
    final locked = state == MapNodeState.locked;
    final color = switch (state) {
      MapNodeState.locked => SLColors.disabledFill,
      _ when special => SLColors.strawberry,
      MapNodeState.open => SLColors.butter,
      MapNodeState.completed => SLColors.mint,
    };
    final inner = special ? size - 14 : size;
    final face = SizedBox.square(
      dimension: inner,
      child: SLSurface(
        spec: SLSurfaceSpec(shape: const SLCircle(), material: SLMaterial.wash, color: color, sticker: !special, seed: seed),
        lift: special ? 0 : SLMetrics.buttonLift,
        press: special ? null : press,
        // Số nhích lên trên một chút: hàng sao vắt ngang mép dưới đĩa.
        child: Align(
          alignment: locked ? Alignment.center : const Alignment(0, -0.28),
          child: locked
              ? SLIcon('lock', size: inner * 0.46, color: SLColors.inkSoft)
              : Text(
                  '$levelId',
                  style: SLTextStyles.of(context).number.copyWith(
                        fontSize: inner * (levelId >= 10 ? 0.38 : 0.44),
                        fontWeight: FontWeight.w900,
                        height: 1,
                      ),
                ),
        ),
      ),
    );
    if (!special) return face;
    return SLSurface(
      spec: SLSurfaceSpec(
        shape: const SLCircle(),
        material: SLMaterial.wash,
        color: locked ? SLColors.paperShade : SLColors.butter,
        sticker: true,
        seed: seed + 1,
      ),
      lift: SLMetrics.buttonLift,
      press: press,
      child: Center(child: face),
    );
  }
}

/// Mẩu giấy nhỏ mang 3 sao (đạt / chưa) dưới đĩa.
class _StarStrip extends StatelessWidget {
  const _StarStrip({required this.stars, required this.special, required this.seed});

  final int stars;
  final bool special;
  final int seed;

  static const pad = 6.0;
  static const padTop = 3.0;

  @override
  Widget build(BuildContext context) {
    final s = MapNodeGeometry.star(special);
    final first = MapNodeGeometry.starOffset(0, special);
    return SizedBox(
      width: MapNodeGeometry.starOffset(2, special).dx - first.dx + s + pad * 2,
      height: s + padTop * 2,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: SLSurface(
              spec: SLSurfaceSpec(shape: SLRoundRect(s / 2 + 3), color: SLColors.paper, inkWidth: 1.6, seed: seed + 2),
            ),
          ),
          for (var i = 0; i < 3; i++)
            Positioned(
              left: pad + MapNodeGeometry.starOffset(i, special).dx - first.dx,
              top: padTop + MapNodeGeometry.starOffset(i, special).dy - first.dy,
              child: StarIcon(size: s, filled: i < stars),
            ),
        ],
      ),
    );
  }
}

/// Nhịp to-nhỏ (hoặc nhún lên xuống khi [bob]) [MapLevelNode.pulseCycles] lần mỗi khi [pulseKey] đổi rồi dừng ở
/// trạng thái gốc. Tắt hiệu ứng → đứng yên.
class _Pulse extends StatefulWidget {
  const _Pulse({required this.pulseKey, required this.child, this.bob = false});

  final int pulseKey;
  final bool bob;
  final Widget child;

  @override
  State<_Pulse> createState() => _PulseState();
}

class _PulseState extends State<_Pulse> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: MapLevelNode.pulsePeriod * MapLevelNode.pulseCycles,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _restart();
  }

  @override
  void didUpdateWidget(_Pulse old) {
    super.didUpdateWidget(old);
    if (old.pulseKey != widget.pulseKey) _restart();
  }

  void _restart() {
    if (slReduceMotion(context)) {
      _c
        ..stop()
        ..value = 1;
    } else if (!_c.isAnimating) {
      _c.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RepaintBoundary(
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, child) {
            final w = math.sin(_c.value * MapLevelNode.pulseCycles * math.pi);
            if (widget.bob) return Transform.translate(offset: Offset(0, -4 * w.abs()), child: child);
            return Transform.scale(scale: 1 + 0.08 * w * w, child: child);
          },
          child: widget.child,
        ),
      );
}
