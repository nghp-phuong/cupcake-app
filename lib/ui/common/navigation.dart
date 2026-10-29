import 'package:flutter/widgets.dart';

import '../../core/routes.dart';

/// Tăng mỗi lần `goToMenu` đưa menu có sẵn trở lại trên cùng. Menu nghe để làm mới ngày lịch/kiểm tra quà:
/// màn ngày bị `pushReplacement` bằng tổng kết nên `pushNamed` của menu không chờ được tới lúc quay về.
final ValueNotifier<int> menuReturns = ValueNotifier<int>(0);

/// Về menu chính: bỏ mọi màn phía trên; nếu menu không nằm dưới cùng thì thay bằng menu.
void goToMenu(BuildContext context) {
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
