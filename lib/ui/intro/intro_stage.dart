import 'package:flutter/widgets.dart';

/// Dựng lớp 3D nằm dưới phụ đề / logo của cảnh mở đầu. Bản app: `IntroStage3d.new` (intro_stage3d.dart), gán vào
/// `IntroScreen.stageBuilder` ở main.dart. Tách riêng để `IntroScreen` (và test giao diện) không import thermion.
typedef IntroStageBuilder = Widget Function(IntroStageHost host);

/// Mốc của cảnh 3 "Mai chào" (giây tính từ đầu cảnh), dùng chung cho lớp 3D và tiếng chuông của `IntroScreen`.
abstract final class IntroBeats {
  /// Mai quay lưng khỏi tiệm, nhìn ra phố (về phía máy quay).
  static const turn = 0.2;

  /// Mai nhảy vui (giảm chuyển động: vẫy tay) + tiếng chuông cửa.
  static const joy = 0.9;

  /// Mai vẫy tay (không có khi giảm chuyển động).
  static const wave = 2.6;
}

/// Cầu nối `IntroScreen` ↔ lớp 3D: đồng hồ của cảnh mở đầu, mốc các cảnh, báo dựng xong / hỏng, và chỗ lớp 3D đăng ký
/// hàm gỡ viewer.
class IntroStageHost {
  IntroStageHost({
    required this.time,
    required this.starts,
    required this.reduceMotion,
    required VoidCallback onReady,
    required VoidCallback onFailed,
  })  : _onReady = onReady,
        _onFailed = onFailed;

  /// Giây tính từ đầu cảnh mở đầu (0 tới khi bắt đầu chạy). Lớp 3D đọc `value` trong vòng cập nhật của nó, không nghe.
  final Animation<double> time;

  /// Giây bắt đầu của 4 cảnh (phố buổi sáng, tiệm của bà, Mai chào, logo) + mốc kết thúc (phần tử cuối).
  final List<double> starts;

  /// Máy bật giảm chuyển động: máy quay đứng yên từng cảnh (cắt cảnh), Mai đứng sẵn trước cửa, không nhảy.
  final bool reduceMotion;

  final VoidCallback _onReady;
  final VoidCallback _onFailed;

  /// Cảnh 3D đã dựng xong và đang vẽ: `IntroScreen` bỏ nền giấy, chạy đồng hồ.
  void ready() => _onReady();

  /// Không dựng được cảnh 3D: `IntroScreen` chạy tiếp trên nền giấy.
  void failed() => _onFailed();

  /// Lớp 3D gán: gỡ cảnh + huỷ viewer, Future xong khi đã huỷ. `IntroScreen` chờ (có giới hạn) rồi mới sang phố — phố
  /// tạo viewer của riêng nó, không để hai viewer chồng nhau.
  Future<void> Function()? release;
}
