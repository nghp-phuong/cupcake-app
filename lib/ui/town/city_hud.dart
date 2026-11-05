import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/city/city_wallet.dart';
import '../../core/city/player_level.dart';
import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../l10n/gen/app_localizations.dart';
import '../common/art.dart';
import '../common/format.dart';
import '../shop3d/shop3d_toasts.dart';
import '../sugarleaf/sugarleaf.dart';

@immutable
class _HudFx {
  const _HudFx(this.id, this.xp, this.levelUp);

  final int id;

  /// XP vừa cộng (0 nếu chỉ đổi xu).
  final int xp;
  final bool levelUp;
}

/// HUD thành phố: xu, cấp Mai, thanh XP (tiến độ trong cấp, [PlayerLevel.progress]). Khi ví đổi: cộng XP → chữ
/// "+N XP" bay lên; lên cấp → nhãn "Lên cấp!" nảy một lần (hiệu ứng hữu hạn ~1,6 s). Chỉ phần số/thanh dựng lại
/// theo ví ([ListenableBuilder]); đặt làm con của `Stack` (nơi gọi tự đặt vị trí bằng `Positioned`).
class CityHud extends StatefulWidget {
  const CityHud(this.wallet, {super.key, this.width = 230});

  final CityWallet wallet;
  final double width;

  @override
  State<CityHud> createState() => _CityHudState();
}

class _CityHudState extends State<CityHud> {
  final _fx = ValueNotifier<_HudFx?>(null);
  Timer? _timer;
  int _seq = 0;
  late int _xp;
  late int _level;

  @override
  void initState() {
    super.initState();
    _xp = widget.wallet.xp;
    _level = widget.wallet.level;
    widget.wallet.addListener(_onWallet);
  }

  @override
  void didUpdateWidget(CityHud old) {
    super.didUpdateWidget(old);
    if (old.wallet != widget.wallet) {
      old.wallet.removeListener(_onWallet);
      widget.wallet.addListener(_onWallet);
      _xp = widget.wallet.xp;
      _level = widget.wallet.level;
    }
  }

  void _onWallet() {
    final w = widget.wallet;
    final gained = w.xp - _xp;
    final up = w.level > _level;
    _xp = w.xp;
    _level = w.level;
    if (gained <= 0 && !up) return;
    _timer?.cancel();
    _fx.value = _HudFx(++_seq, gained > 0 ? gained : 0, up);
    _timer = Timer(const Duration(milliseconds: 1600), () => _fx.value = null);
  }

  @override
  void dispose() {
    _timer?.cancel();
    widget.wallet.removeListener(_onWallet);
    _fx.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final s = Shop3dStyle.scaleOf(MediaQuery.sizeOf(context));
    return RepaintBoundary(
      child: SizedBox(
        width: widget.width * s,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            ListenableBuilder(
              listenable: widget.wallet,
              builder: (context, _) {
                final w = widget.wallet;
                final progress = PlayerLevel.progress(w.xp);
                return Semantics(
                  container: true,
                  label:
                      '${l.commonCoins(w.coins)}, ${l.cityMaiLevel(w.level)}',
                  excludeSemantics: true,
                  child: Container(
                    padding: EdgeInsets.fromLTRB(12 * s, 8 * s, 12 * s, 10 * s),
                    decoration: Shop3dStyle.box(
                      color: AppColors.cream,
                      radius: 18,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            CoinIcon(size: 28 * s),
                            SizedBox(width: 6 * s),
                            Expanded(
                              child: Text(
                                formatInt(context, w.coins),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Shop3dStyle.title(context, 22 * s),
                              ),
                            ),
                            SizedBox(width: 6 * s),
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 10 * s,
                                vertical: 3 * s,
                              ),
                              decoration: Shop3dStyle.box(
                                color: AppColors.strawberry,
                                radius: 12,
                                shadow: false,
                              ),
                              child: Text(
                                l.cityMaiLevel(w.level),
                                maxLines: 1,
                                style: Shop3dStyle.body(
                                  15 * s,
                                  weight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 6 * s),
                        _XpBar(value: progress, height: 12 * s),
                      ],
                    ),
                  ),
                );
              },
            ),
            ValueListenableBuilder<_HudFx?>(
              valueListenable: _fx,
              builder: (context, fx, _) => fx == null
                  ? const SizedBox.shrink()
                  : Positioned(
                      left: 0,
                      right: 0,
                      top: 0,
                      child: IgnorePointer(
                        child: _FxView(key: ValueKey(fx.id), fx: fx, scale: s),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _XpBar extends StatelessWidget {
  const _XpBar({required this.value, required this.height});

  final double value;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(height),
        border: const Border.fromBorderSide(AppTheme.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: TweenAnimationBuilder<double>(
        tween: Tween(end: value.clamp(0.0, 1.0)),
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOut,
        builder: (context, v, _) => Align(
          alignment: Alignment.centerLeft,
          child: FractionallySizedBox(
            widthFactor: v,
            heightFactor: 1,
            child: const ColoredBox(color: AppColors.good),
          ),
        ),
      ),
    );
  }
}

/// "+N XP" bay lên và mờ dần; lên cấp thì thêm nhãn "Lên cấp!" nảy một lần.
class _FxView extends StatelessWidget {
  const _FxView({super.key, required this.fx, required this.scale});

  final _HudFx fx;
  final double scale;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final reduce = slReduceMotion(context);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 1500),
      builder: (context, t, _) {
        final fade = t < 0.7 ? 1.0 : (1 - (t - 0.7) / 0.3);
        final rise = reduce ? 0.0 : Curves.easeOut.transform(t) * 18 * scale;
        final pop = reduce
            ? 1.0
            : (t < 0.2 ? Curves.easeOutBack.transform(t / 0.2) : 1.0);
        return Opacity(
          opacity: fade.clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(0, 64 * scale - rise),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (fx.levelUp)
                  Transform.scale(
                    scale: pop,
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 14 * scale,
                        vertical: 4 * scale,
                      ),
                      decoration: Shop3dStyle.box(
                        color: AppColors.butter,
                        radius: 14,
                      ),
                      child: Text(
                        l.cityLevelUp,
                        style: Shop3dStyle.title(context, 20 * scale),
                      ),
                    ),
                  ),
                if (fx.xp > 0)
                  Text(
                    l.cityXpGain(fx.xp),
                    style:
                        Shop3dStyle.title(
                          context,
                          20 * scale,
                          color: const Color(0xFF3F8A44),
                        ).copyWith(
                          shadows: const [
                            Shadow(color: Colors.white, blurRadius: 3),
                            Shadow(color: Colors.white, blurRadius: 3),
                          ],
                        ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
