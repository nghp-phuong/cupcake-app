import 'package:flutter/widgets.dart';

import '../../core/level/level.dart';
import '../../core/routes.dart';

/// Tăng mỗi lần `goToMenu` đưa bản đồ (màn chính) có sẵn trở lại trên cùng. Bản đồ nghe để làm mới ngày lịch,
/// kiểm tra quà và chạy hoạt cảnh tiến trình: màn level bị `pushReplacement` bằng màn kết quả nên `pushNamed` của
/// bản đồ không chờ được tới lúc quay về.
final ValueNotifier<int> menuReturns = ValueNotifier<int>(0);

/// Tiến trình đã đổi nhưng bản đồ chưa chạy hoạt cảnh (sao bay vào nút, mở khoá level/chương): một mục mỗi level,
/// theo thứ tự chơi. Nhiều lượt liền nhau ("Chơi lại", "Màn tiếp") được gộp, không ghi đè.
final List<LevelProgressDelta> _pendingReveals = [];

/// Đưa [delta] vào hàng chờ hoạt cảnh của bản đồ (null → bỏ qua). Level đã có trong hàng chờ → gộp: sao từ mức
/// thấp nhất tới mức cao nhất, giữ level/chương đã mở và mọi mở khoá mới (`newUnlocks`, bỏ trùng).
void queueMapReveal(LevelProgressDelta? delta) {
  if (delta == null) return;
  final i = _pendingReveals.indexWhere((d) => d.levelId == delta.levelId);
  if (i < 0) {
    _pendingReveals.add(delta);
    return;
  }
  final old = _pendingReveals[i];
  _pendingReveals[i] = LevelProgressDelta(
    levelId: old.levelId,
    oldStars: old.oldStars < delta.oldStars ? old.oldStars : delta.oldStars,
    newStars: old.newStars > delta.newStars ? old.newStars : delta.newStars,
    newBest: old.newBest || delta.newBest,
    unlockedLevel: old.unlockedLevel ?? delta.unlockedLevel,
    unlockedChapter: old.unlockedChapter ?? delta.unlockedChapter,
    newUnlocks: [...old.newUnlocks, for (final id in delta.newUnlocks) if (!old.newUnlocks.contains(id)) id],
  );
}

/// Có hoạt cảnh đang chờ không.
bool get hasMapReveal => _pendingReveals.isNotEmpty;

/// Lấy (một lần) các hoạt cảnh đang chờ, theo thứ tự chơi; rỗng nếu không có.
List<LevelProgressDelta> takeMapReveals() {
  final out = List<LevelProgressDelta>.of(_pendingReveals);
  _pendingReveals.clear();
  return out;
}

/// Bỏ mọi hoạt cảnh đang chờ (vd. sau khi xoá dữ liệu: tiến trình cũ không còn).
void clearMapReveals() => _pendingReveals.clear();

/// Về bản đồ (màn chính): bỏ mọi màn phía trên; nếu bản đồ không nằm dưới cùng thì thay bằng bản đồ.
/// [reveal] = tiến trình vừa đổi, gộp vào hàng chờ hoạt cảnh (null → giữ nguyên hàng chờ, không xoá).
void goToMenu(BuildContext context, {LevelProgressDelta? reveal}) {
  queueMapReveal(reveal);
  final nav = Navigator.of(context);
  var menuBelow = false;
  nav.popUntil((route) {
    if (route.isFirst) menuBelow = route.settings.name == AppRoutes.menu;
    return route.isFirst;
  });
  if (menuBelow) {
    menuReturns.value++;
  } else {
    nav.pushReplacementNamed(AppRoutes.menu);
  }
}
