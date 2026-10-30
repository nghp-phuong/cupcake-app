import 'level/level_progress.dart';
import 'level/level_result.dart';

abstract final class AppRoutes {
  /// Màn chính = bản đồ chương.
  static const menu = '/';
  static const upgrades = '/upgrades';
  static const decor = '/decor';
  static const recipes = '/recipes';
  static const store = '/store';
  static const settings = '/settings';
  static const levels = '/levels';
  static const level = '/level'; // arguments: LevelArgs
  static const levelResult = '/level/result'; // arguments: LevelResultArgs

  /// Cảnh mở đầu (lần đầu mở app, hoặc "Xem lại" trong Cài đặt) → vào thẳng L1.
  static const intro = '/intro';

  /// Intro ngắn 3–5 s (các lần mở sau) → bản đồ.
  static const shortIntro = '/splash';

  /// Route khi mở app: chưa xem cảnh mở đầu → [intro], đã xem → [shortIntro].
  static String initialFor({required bool introSeen}) => introSeen ? shortIntro : intro;

  /// [intro] hoặc [shortIntro].
  static bool isIntro(String name) => name == intro || name == shortIntro;
}

class LevelArgs {
  const LevelArgs(this.levelId);

  final int levelId;
}

class LevelResultArgs {
  const LevelResultArgs(this.result, {this.progress});

  final LevelResult result;

  /// Tiến trình đổi sau lượt này (`GameState.applyLevelResult`), để màn kết quả / bản đồ chạy hoạt cảnh.
  final LevelProgressDelta? progress;
}
