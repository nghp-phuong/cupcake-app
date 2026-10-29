import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import 'paint/hand_drawn.dart';
import 'paint/sl_surface.dart';
import 'sl_name_tag.dart';
import 'sl_props.dart';
import 'sl_theme.dart';

/// Chất liệu panel.
enum SLPanelStyle {
  /// Một tờ giấy lớn.
  paper,

  /// Khung gỗ, lòng là giấy.
  wood,
}

/// Panel vẽ tay (giấy hoặc khung gỗ lòng giấy), bóng nâu mềm; [title] → [SLNameTag] gắn trên mép.
class SLPanel extends StatelessWidget {
  const SLPanel({
    super.key,
    required this.child,
    this.style = SLPanelStyle.paper,
    this.title,
    this.titleStyle = SLNameTagStyle.ribbon,
    this.titleColor,
    this.titleIcon,
    this.color,
    this.padding = const EdgeInsets.all(24),
    this.radius = SLMetrics.radiusPanel,
    this.seed,
  });

  final Widget child;
  final SLPanelStyle style;
  final String? title;
  final SLNameTagStyle titleStyle;
  final Color? titleColor;
  final String? titleIcon;

  /// Màu giấy (mặc định giấy ngà).
  final Color? color;
  final EdgeInsetsGeometry padding;
  final double radius;
  final int? seed;

  static const _tagHeight = 54.0;

  @override
  Widget build(BuildContext context) {
    final theme = SLTheme.of(context);
    final s = slSeed(seed: seed, key: key, content: title ?? 'panel');
    final paper = color ?? theme.paper;
    final hasTitle = title != null;
    final inner = Padding(
      padding: hasTitle ? const EdgeInsets.only(top: _tagHeight / 2) : EdgeInsets.zero,
      child: Padding(padding: padding, child: child),
    );
    Widget body;
    if (style == SLPanelStyle.wood) {
      body = SLSurface(
        spec: SLSurfaceSpec(
          shape: SLRoundRect(radius),
          material: SLMaterial.wood,
          color: SLColors.wood,
          ink: theme.ink,
          inkWidth: theme.inkWidth + 0.4,
          roughness: theme.roughness,
          seed: s,
        ),
        lift: SLMetrics.panelLift,
        padding: const EdgeInsets.all(12),
        child: SLSurface(
          spec: SLSurfaceSpec(
            shape: SLRoundRect(math.max(6, radius - 10)),
            color: paper,
            ink: theme.ink,
            inkWidth: theme.inkWidth * 0.8,
            roughness: theme.roughness,
            seed: s + 1,
          ),
          child: inner,
        ),
      );
    } else {
      body = SLSurface(
        spec: SLSurfaceSpec(
          shape: SLRoundRect(radius),
          color: paper,
          ink: theme.ink,
          inkWidth: theme.inkWidth + 0.3,
          roughness: theme.roughness,
          seed: s,
        ),
        lift: SLMetrics.panelLift,
        child: inner,
      );
    }
    body = RepaintBoundary(child: body);
    if (!hasTitle) return body;
    // passthrough: thân panel nhận đúng ràng buộc của cha như khi không có tiêu đề (Stack mặc định nới lỏng →
    // thân co theo nội dung, panel hẹp hơn khung được cấp).
    return Stack(
      clipBehavior: Clip.none,
      fit: StackFit.passthrough,
      children: [
        Padding(padding: const EdgeInsets.only(top: _tagHeight / 2), child: body),
        Positioned(
          left: 40,
          right: 40,
          top: 0,
          child: Center(
            child: SLNameTag(title!, style: titleStyle, color: titleColor, icon: titleIcon, seed: s + 2, height: _tagHeight),
          ),
        ),
      ],
    );
  }
}

/// Cách gắn thẻ giấy lên tường/bảng.
enum SLAttach { none, pin, tape, tapeCorners }

/// Thẻ giấy vẽ tay, có thể ghim (đinh ghim tròn) hoặc dán băng dính; [tilt] xoay nhẹ (radian) cho tự nhiên.
class SLPaperCard extends StatelessWidget {
  const SLPaperCard({
    super.key,
    required this.child,
    this.color,
    this.attach = SLAttach.none,
    this.tilt = 0,
    this.padding = const EdgeInsets.all(18),
    this.radius = 12,
    this.seed,
  });

  final Widget child;
  final Color? color;
  final SLAttach attach;
  final double tilt;
  final EdgeInsetsGeometry padding;
  final double radius;
  final int? seed;

  @override
  Widget build(BuildContext context) {
    final theme = SLTheme.of(context);
    final s = slSeed(seed: seed, key: key, content: 'card');
    Widget card = SLSurface(
      spec: SLSurfaceSpec(
        shape: SLRoundRect(radius),
        color: color ?? theme.paper,
        ink: theme.ink,
        inkWidth: theme.inkWidth,
        roughness: theme.roughness,
        seed: s,
      ),
      lift: 3.5,
      padding: padding,
      child: child,
    );
    card = _withAttach(card, attach, s);
    if (tilt != 0) card = Transform.rotate(angle: tilt, child: card);
    return RepaintBoundary(child: card);
  }
}

/// Vé đơn hàng bằng giấy: cuống trên ([header], vd. tên khách) + hàng lỗ đục + thân ([child]) + mép răng cưa,
/// ghim ở trên. Chỉ là khung — nội dung do màn hình truyền vào.
class SLOrderTicket extends StatelessWidget {
  const SLOrderTicket({
    super.key,
    required this.child,
    this.header,
    this.width = 280,
    this.stub = 52,
    this.color,
    this.pinned = true,
    this.tilt = 0,
    this.seed,
  });

  final Widget child;
  final Widget? header;
  final double? width;

  /// Chiều cao cuống vé.
  final double stub;
  final Color? color;
  final bool pinned;
  final double tilt;
  final int? seed;

  static const _tooth = 12.0;

  @override
  Widget build(BuildContext context) {
    final theme = SLTheme.of(context);
    final s = slSeed(seed: seed, key: key, content: 'ticket');
    Widget ticket = SizedBox(
      width: width,
      child: SLSurface(
        spec: SLSurfaceSpec(
          shape: SLTicket(stub: stub, tooth: _tooth, seed: s),
          color: color ?? theme.paper,
          ink: theme.ink,
          inkWidth: theme.inkWidth,
          roughness: theme.roughness,
          seed: s,
        ),
        lift: 3.5,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: stub,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
                child: Center(child: header ?? const SizedBox.shrink()),
              ),
            ),
            Padding(padding: const EdgeInsets.fromLTRB(16, 12, 16, _tooth + 12), child: child),
          ],
        ),
      ),
    );
    if (pinned) ticket = _withAttach(ticket, SLAttach.pin, s);
    if (tilt != 0) ticket = Transform.rotate(angle: tilt, child: ticket);
    return RepaintBoundary(child: ticket);
  }
}

Widget _withAttach(Widget child, SLAttach attach, int seed) {
  switch (attach) {
    case SLAttach.none:
      return child;
    case SLAttach.pin:
      return Stack(
        clipBehavior: Clip.none,
        children: [child, Positioned(left: 0, right: 0, top: -12, child: Center(child: SLPushPin(seed: seed)))],
      );
    case SLAttach.tape:
      return Stack(
        clipBehavior: Clip.none,
        children: [
          child,
          Positioned(left: 0, right: 0, top: -10, child: Center(child: SLTapeStrip(angle: (seed % 7 - 3) * 0.02, seed: seed))),
        ],
      );
    case SLAttach.tapeCorners:
      return Stack(
        clipBehavior: Clip.none,
        children: [
          child,
          Positioned(left: -14, top: -6, child: SLTapeStrip(angle: -0.7, seed: seed)),
          Positioned(right: -14, top: -6, child: SLTapeStrip(angle: 0.7, seed: seed + 1, color: const Color(0xB3A8DCC8))),
        ],
      );
  }
}

/// Đinh ghim tròn (hồng dâu) có đốm sáng.
class SLPushPin extends StatelessWidget {
  const SLPushPin({super.key, this.color = SLColors.strawberry, this.size = 24, this.seed = 0});

  final Color color;
  final double size;
  final int seed;

  @override
  Widget build(BuildContext context) => SizedBox.square(
        dimension: size,
        child: SLSurface(
          spec: SLSurfaceSpec(shape: const SLCircle(), material: SLMaterial.wash, color: color, inkWidth: 1.8, seed: seed),
          lift: 2.5,
          child: Align(
            alignment: const Alignment(-0.35, -0.4),
            child: SizedBox.square(dimension: size * 0.22, child: SLInkDot(color: const Color(0xCCFFFFFF), seed: seed)),
          ),
        ),
      );
}

/// Mẩu băng dính trong mờ (mặc định vàng bơ), hai đầu xé răng cưa.
class SLTapeStrip extends StatelessWidget {
  const SLTapeStrip({super.key, this.angle = 0, this.width = 64, this.height = 20, this.color = const Color(0xB3FFD27A), this.seed = 0});

  final double angle;
  final double width;
  final double height;
  final Color color;
  final int seed;

  @override
  Widget build(BuildContext context) => Transform.rotate(
        angle: angle,
        child: SizedBox(
          width: width,
          height: height,
          child: SLSurface(spec: SLSurfaceSpec(shape: const SLTapeShape(), material: SLMaterial.tape, color: color, seed: seed)),
        ),
      );
}
