import 'package:flutter/widgets.dart';

import '../common/navigation.dart';
import '../sugarleaf/sugarleaf.dart';

/// Mã ngôn ngữ dùng cho tên level/chương lấy từ levels.json (`titleFor`).
String levelLang(BuildContext context) => Localizations.localeOf(context).languageCode == 'vi' ? 'vi' : 'en';

/// Màn level không dựng được (levels.json nạp lỗi → cấu hình rỗng, level không tồn tại, route `/levels` cũ):
/// vẽ nền kem rồi sau khung hình đầu về bản đồ. Không ném lỗi.
class LevelRedirect extends StatefulWidget {
  const LevelRedirect({super.key});

  @override
  State<LevelRedirect> createState() => _LevelRedirectState();
}

class _LevelRedirectState extends State<LevelRedirect> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) goToMenu(context);
    });
  }

  @override
  Widget build(BuildContext context) => const ColoredBox(color: SLColors.cream, child: SizedBox.expand());
}
