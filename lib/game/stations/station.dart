import 'dart:ui';

import 'package:flame/components.dart';

import '../../core/models/ids.dart';
import '../bakery_game.dart';
import '../components/game_paint.dart';

/// Một trạm làm bánh. Vẽ trực tiếp bằng canvas trong toạ độ khung 1280×720; nhận con trỏ từ game.
abstract class Station extends Component {
  Station(this.game, this.id) : super(priority: 10);

  final BakeryGame game;
  final StationId id;

  static const double enterSeconds = 0.45;
  static const double leaveSeconds = 0.4;

  /// Thời gian từ lúc vào trạm.
  double time = 0;
  double _leaveT = -1;
  bool _done = false;

  bool get leaving => _leaveT >= 0;

  /// Đã xong phần thao tác (đang chạy hoạt cảnh mừng).
  bool get isDone => _done;

  bool get acceptsInput => time >= enterSeconds * 0.7 && !leaving && !_done;

  /// Trạm dùng nút Xong.
  bool get usesDone => false;

  /// Nút Xong được bấm lúc này.
  bool get canDone => false;

  void pointerDown(Offset p) {}
  void pointerMove(Offset p) {}
  void pointerUp(Offset p) {}
  void pointerCancel() {}

  /// Bấm nút Xong.
  void done() {}

  /// Vẽ nội dung trạm (đã dịch chuyển theo hoạt cảnh vào/ra).
  void paintStation(Canvas canvas);

  /// Vẽ phần gắn với ảnh nền (vd. ô kính lò có sẵn trong ảnh nền trạm nướng): không trượt theo hoạt cảnh
  /// vào/ra, chỉ mờ dần cùng trạm. Vẽ trước [paintStation].
  void paintFixed(Canvas canvas) {}

  /// Đánh dấu xong; game chuyển trạm sau [delay] giây.
  void finish({double delay = 0.8}) {
    if (_done) return;
    _done = true;
    game.stationFinished(delay: delay);
  }

  void leave() {
    if (!leaving) _leaveT = 0;
  }

  @override
  void update(double dt) {
    time += dt;
    if (leaving) {
      _leaveT += dt;
      if (_leaveT >= leaveSeconds) removeFromParent();
    }
  }

  @override
  void render(Canvas canvas) {
    // Vào: trượt từ phải sang; ra: trượt sang trái + mờ dần.
    double dx = 0;
    double alpha = 1;
    if (leaving) {
      final t = easeInOut(_leaveT / leaveSeconds);
      dx = -kPlayArea.width * 0.6 * t;
      alpha = 1 - t;
    } else if (time < enterSeconds) {
      final t = easeOutCubic(time / enterSeconds);
      dx = kPlayArea.width * 0.6 * (1 - t);
      alpha = t;
    }
    if (alpha <= 0) return;
    canvas.save();
    canvas.clipRect(const Rect.fromLTWH(0, 72, 1280, 648));
    if (alpha < 1) {
      canvas.saveLayer(const Rect.fromLTWH(0, 72, 1280, 648), Paint()..color = Color.fromRGBO(0, 0, 0, alpha));
    }
    paintFixed(canvas);
    canvas.translate(dx, 0);
    paintStation(canvas);
    if (alpha < 1) canvas.restore();
    canvas.restore();
  }
}
