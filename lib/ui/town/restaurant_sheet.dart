import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/city/city_wallet.dart';
import '../../core/city/restaurant_menu.dart';
import '../../core/constants.dart';
import '../../l10n/gen/app_localizations.dart';
import '../common/art.dart';
import '../shop3d/shop3d_toasts.dart';
import '../sugarleaf/sugarleaf.dart';
import 'town_l10n.dart';

/// Bảng thực đơn quán "Bếp Hải Đăng": panel bên phải màn hình. Mỗi món: icon vẽ bằng hình, tên, giá, XP; món đã ăn
/// hôm nay hiện "đã ăn" + XP giảm; không đủ xu → nút mờ + "Không đủ xu". Chạm "Gọi món" → [onOrder] (nơi gọi gọi
/// `wallet.eat`); nút X → [onClose]. Dựng lại theo ví ([ListenableBuilder]) nên xu/lần ăn đổi là cập nhật ngay.
/// Đặt làm con của `Stack` (tự bọc `Positioned` sát mép phải).
class RestaurantSheet extends StatelessWidget {
  const RestaurantSheet({
    super.key,
    required this.wallet,
    required this.onOrder,
    required this.onClose,
  });

  final CityWallet wallet;
  final void Function(Dish dish) onOrder;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final size = MediaQuery.sizeOf(context);
    final pad = MediaQuery.paddingOf(context);
    final s = Shop3dStyle.scaleOf(size);
    return Positioned(
      top: 10 + pad.top,
      bottom: 10 + pad.bottom,
      right: 10 + pad.right,
      width: math.min(430 * s, size.width * 0.62),
      child: RepaintBoundary(
        child: Container(
          padding: EdgeInsets.all(12 * s),
          decoration: Shop3dStyle.box(color: AppColors.cream, radius: 22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      l.cityMenuTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Shop3dStyle.title(context, 24 * s),
                    ),
                  ),
                  Tooltip(
                    message: l.commonClose,
                    child: Semantics(
                      button: true,
                      label: l.commonClose,
                      excludeSemantics: true,
                      onTap: onClose,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: onClose,
                        child: SizedBox(
                          width: SLMetrics.minTap,
                          height: SLMetrics.minTap,
                          child: Center(
                            child: Container(
                              width: 40,
                              height: 40,
                              decoration: Shop3dStyle.circle(
                                color: AppColors.butter,
                              ),
                              child: const Icon(
                                Icons.close_rounded,
                                color: AppColors.chocolate,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 6 * s),
              Expanded(
                child: ListenableBuilder(
                  listenable: wallet,
                  builder: (context, _) => ListView.separated(
                    padding: EdgeInsets.zero,
                    itemCount: RestaurantMenu.dishes.length,
                    separatorBuilder: (_, _) => SizedBox(height: 8 * s),
                    itemBuilder: (context, i) {
                      final dish = RestaurantMenu.dishes[i];
                      return _DishRow(
                        dish: dish,
                        timesEaten: wallet.timesEatenToday(dish.id),
                        affordable: wallet.canAfford(dish.price),
                        onOrder: () => onOrder(dish),
                        scale: s,
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DishRow extends StatelessWidget {
  const _DishRow({
    required this.dish,
    required this.timesEaten,
    required this.affordable,
    required this.onOrder,
    required this.scale,
  });

  final Dish dish;
  final int timesEaten;
  final bool affordable;
  final VoidCallback onOrder;
  final double scale;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final xp = RestaurantMenu.xpFor(dish, timesEaten);
    final ate = timesEaten > 0;
    return Container(
      constraints: BoxConstraints(minHeight: 76 * scale),
      padding: EdgeInsets.all(8 * scale),
      decoration: Shop3dStyle.box(
        color: Colors.white,
        radius: 16,
        shadow: false,
      ),
      child: Row(
        children: [
          SizedBox(
            width: 56 * scale,
            height: 56 * scale,
            child: CustomPaint(painter: DishIconPainter(dish.id)),
          ),
          SizedBox(width: 10 * scale),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  cityText(l, dish.nameKey),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Shop3dStyle.body(
                    16 * scale,
                    weight: FontWeight.w800,
                    height: 1.1,
                  ),
                ),
                SizedBox(height: 2 * scale),
                Wrap(
                  spacing: 10 * scale,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CoinIcon(size: 18 * scale),
                        const SizedBox(width: 3),
                        Text(
                          l.cityPrice(dish.price),
                          style: Shop3dStyle.body(
                            14 * scale,
                            weight: FontWeight.w800,
                            color: affordable
                                ? AppColors.chocolate
                                : SLColors.badDeep,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      l.cityXpGain(xp),
                      style: Shop3dStyle.body(
                        14 * scale,
                        weight: FontWeight.w800,
                        color: ate
                            ? AppColors.caramel
                            : const Color(0xFF3F8A44),
                      ),
                    ),
                  ],
                ),
                if (ate)
                  Text(
                    l.cityAteToday,
                    style: Shop3dStyle.body(
                      12 * scale,
                      weight: FontWeight.w700,
                      color: AppColors.caramel,
                      height: 1.1,
                    ),
                  ),
                if (!affordable)
                  Text(
                    l.cityNotEnoughCoins,
                    style: Shop3dStyle.body(
                      12 * scale,
                      weight: FontWeight.w800,
                      color: SLColors.badDeep,
                      height: 1.1,
                    ),
                  ),
              ],
            ),
          ),
          SizedBox(width: 8 * scale),
          Shop3dPillButton(
            label: l.cityOrderFood,
            onPressed: affordable ? onOrder : null,
            semanticsLabel: '${l.cityOrderFood}: ${cityText(l, dish.nameKey)}',
            fontSize: 15,
            height: 48,
          ),
        ],
      ),
    );
  }
}

/// Icon món vẽ bằng hình đơn giản (bát/đĩa + thức ăn, không vẽ mặt người). Khoá lạ → bát trống.
class DishIconPainter extends CustomPainter {
  const DishIconPainter(this.dishId);

  final String dishId;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final ink = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = AppColors.caramel;
    Paint fill(Color c) => Paint()..color = c;

    void bowl(Color food) {
      final top = Rect.fromLTWH(w * 0.1, h * 0.38, w * 0.8, h * 0.18);
      // Thức ăn nhô lên khỏi miệng bát.
      canvas.drawOval(top, fill(food));
      final body = Path()
        ..moveTo(w * 0.1, h * 0.47)
        ..quadraticBezierTo(w * 0.15, h * 0.88, w * 0.5, h * 0.88)
        ..quadraticBezierTo(w * 0.85, h * 0.88, w * 0.9, h * 0.47)
        ..close();
      canvas.drawPath(body, fill(const Color(0xFFF7F1E8)));
      canvas.drawPath(body, ink);
      canvas.drawOval(top, ink);
      canvas.drawLine(
        Offset(w * 0.3, h * 0.92),
        Offset(w * 0.7, h * 0.92),
        ink,
      );
    }

    void steam() {
      for (final x in [0.35, 0.5, 0.65]) {
        final p = Path()
          ..moveTo(w * x, h * 0.32)
          ..quadraticBezierTo(w * (x - 0.07), h * 0.22, w * x, h * 0.14)
          ..quadraticBezierTo(w * (x + 0.07), h * 0.06, w * x, h * 0.02);
        canvas.drawPath(
          p,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2
            ..strokeCap = StrokeCap.round
            ..color = const Color(0xFFCDBFB2),
        );
      }
    }

    switch (dishId) {
      case 'fish_soup':
        bowl(const Color(0xFFF2B26B));
        steam();
        // Miếng cá: thân + đuôi tam giác.
        canvas.drawOval(
          Rect.fromLTWH(w * 0.34, h * 0.4, w * 0.22, h * 0.1),
          fill(const Color(0xFFFFF4E6)),
        );
        canvas.drawPath(
          Path()
            ..moveTo(w * 0.55, h * 0.45)
            ..lineTo(w * 0.64, h * 0.39)
            ..lineTo(w * 0.64, h * 0.51)
            ..close(),
          fill(const Color(0xFFFFF4E6)),
        );
      case 'omelette_rice':
        // Đĩa phẳng + cơm trắng + trứng vàng.
        canvas.drawOval(
          Rect.fromLTWH(w * 0.04, h * 0.42, w * 0.92, h * 0.46),
          fill(const Color(0xFFF7F1E8)),
        );
        canvas.drawOval(
          Rect.fromLTWH(w * 0.04, h * 0.42, w * 0.92, h * 0.46),
          ink,
        );
        canvas.drawOval(
          Rect.fromLTWH(w * 0.2, h * 0.3, w * 0.6, h * 0.42),
          fill(Colors.white),
        );
        canvas.drawOval(
          Rect.fromLTWH(w * 0.16, h * 0.4, w * 0.68, h * 0.34),
          fill(AppColors.butter),
        );
        canvas.drawOval(
          Rect.fromLTWH(w * 0.16, h * 0.4, w * 0.68, h * 0.34),
          ink,
        );
        canvas.drawArc(
          Rect.fromLTWH(w * 0.34, h * 0.46, w * 0.3, h * 0.18),
          3.4,
          2.4,
          false,
          ink..strokeWidth = 1.5,
        );
      case 'veggie_curry':
        bowl(const Color(0xFFE0A33C));
        steam();
        canvas.drawCircle(
          Offset(w * 0.38, h * 0.44),
          w * 0.05,
          fill(AppColors.good),
        );
        canvas.drawCircle(
          Offset(w * 0.55, h * 0.46),
          w * 0.05,
          fill(const Color(0xFFE8803C)),
        );
        canvas.drawCircle(
          Offset(w * 0.68, h * 0.43),
          w * 0.04,
          fill(AppColors.good),
        );
      case 'seafood_noodles':
        bowl(const Color(0xFFF5DE9B));
        steam();
        // Sợi mì + con tôm (cung cam).
        for (final x in [0.3, 0.42, 0.54]) {
          canvas.drawArc(
            Rect.fromLTWH(w * x, h * 0.36, w * 0.2, h * 0.14),
            3.2,
            3.0,
            false,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2
              ..color = const Color(0xFFD9B35A),
          );
        }
        canvas.drawCircle(
          Offset(w * 0.7, h * 0.43),
          w * 0.07,
          fill(AppColors.bad),
        );
      default:
        bowl(const Color(0xFFE9DCCB));
    }
  }

  @override
  bool shouldRepaint(DishIconPainter old) => old.dishId != dishId;
}
