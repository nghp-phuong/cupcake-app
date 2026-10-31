import 'package:flutter/material.dart';

import '../../core/constants.dart';
import '../../core/services/ad_service.dart';
import '../../l10n/gen/app_localizations.dart';
import '../sugarleaf/sugarleaf.dart';

/// Mở hộp thoại vẽ tay ([showSLDialog]: nền tối nhẹ màu mực, hộp nảy ra; nội dung trong [SLScope] — chữ mực nâu,
/// font nội dung). Không bọc `Material`: nội dung hộp thoại chỉ dùng SL* (không InkWell/TextField…); cần widget
/// Material thì tự bọc `Material(type: MaterialType.transparency)` trong [builder].
Future<T?> showSugarDialog<T>(BuildContext context, {required WidgetBuilder builder, bool dismissible = true}) =>
    showSLDialog<T>(context, dismissible: dismissible, builder: builder);

/// Hộp thoại chuẩn — tờ giấy vẽ tay + dải vải tiêu đề trên mép, nút đóng tròn (tuỳ chọn), hàng nút dưới
/// ([SLDialog]). Giữ API cũ.
class SugarDialog extends StatelessWidget {
  const SugarDialog({
    super.key,
    required this.title,
    required this.child,
    this.actions = const [],
    this.width = 560,
    this.showClose = false,
    this.titleColor = AppColors.strawberry,
  });

  final String title;
  final Widget child;
  final List<Widget> actions;
  final double width;
  final bool showClose;
  final Color titleColor;

  @override
  Widget build(BuildContext context) => SLDialog(
        title: title,
        titleColor: titleColor,
        width: width,
        showClose: showClose,
        actions: actions,
        child: child,
      );
}

/// Đóng hộp thoại chứa [context] đúng một lần: hai lần chạm lọt cùng một khung hình (hai ngón / máy chậm) thì lần
/// sau bỏ qua — route của hộp đã không còn hiện hành (đang đóng) nên không `pop` nhầm màn bên dưới.
void popDialogOnce<T>(BuildContext context, [T? result]) {
  final route = ModalRoute.of(context);
  if (route == null || !route.isCurrent) return;
  Navigator.of(context).pop<T>(result);
}

/// Hộp xác nhận Huỷ / Đồng ý. Trả true nếu người chơi đồng ý.
Future<bool> showConfirmDialog(
  BuildContext context, {
  required String title,
  required String body,
  String? confirmLabel,
  Color confirmColor = AppColors.strawberry,
  Color titleColor = AppColors.strawberry,
  Widget? illustration,
}) async {
  final result = await showSugarDialog<bool>(
    context,
    builder: (ctx) {
      final l = AppLocalizations.of(ctx);
      return SLDialog(
        title: title,
        titleColor: titleColor,
        actions: [
          SLButton(
            label: l.commonCancel,
            variant: SLButtonVariant.secondary,
            width: 180,
            onPressed: () => popDialogOnce(ctx, false),
          ),
          SLButton(
            label: confirmLabel ?? l.commonConfirm,
            color: confirmColor,
            width: 200,
            onPressed: () => popDialogOnce(ctx, true),
          ),
        ],
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (illustration != null) ...[illustration, const SizedBox(height: 12)],
            Text(body, textAlign: TextAlign.center, style: const TextStyle(fontSize: 20, height: 1.35)),
          ],
        ),
      );
    },
  );
  return result ?? false;
}

/// Thông báo ngắn ở dưới màn — mẩu giấy dán băng dính ([SLToast], qua Overlay, tự ẩn). [success] = dấu tích
/// xanh; false = icon thông tin.
void showToast(BuildContext context, String message, {bool success = true}) {
  SLToast.show(context, message, kind: success ? SLToastKind.success : SLToastKind.info);
}

/// Quảng cáo thưởng không trả thưởng (`showRewarded` false / lỗi): còn lượt hôm nay → người chơi đóng sớm hoặc SDK
/// lỗi ([AppLocalizations.adNotCompleted]); hết lượt thật → [AppLocalizations.adsLimitReached] (UI-07).
void showRewardedFailedToast(BuildContext context, AdService ads) {
  final l = AppLocalizations.of(context);
  showToast(context, ads.canShowRewarded() ? l.adNotCompleted : l.adsLimitReached, success: false);
}
