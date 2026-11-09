import 'package:flutter_test/flutter_test.dart';
import 'package:sugarleaf_bakery/game/shop3d/shop3d_texture_watch.dart';

/// Xin lại texture của ảnh 3D phố / cảnh mở đầu khi lần cấp trên web hỏng (shop3d_texture_watch.dart; lỗi "Failed to
/// size for canvas" sau cảnh mở đầu / khi đo `auto` hạ mức đồ hoạ). Dart thuần — phần widget kiểm bằng trình duyệt.
void main() {
  /// Kết quả [Shop3dTextureWatch.tick] của [n] nhịp liên tiếp.
  List<bool> ticks(Shop3dTextureWatch w, int n) => [for (var i = 0; i < n; i++) w.tick()];

  test('cấp được ngay: không bao giờ xin lại', () {
    final w = Shop3dTextureWatch()..want(1280, 720);
    expect(w.ready, isFalse);
    w.got(1280, 720);
    expect(w.ready, isTrue);
    expect(ticks(w, 10), everyElement(isFalse));
    expect(w.retries, 0);
  });

  test('lần xin hỏng: chờ trọn một nhịp rồi xin lại mỗi nhịp tới khi được', () {
    final w = Shop3dTextureWatch()..want(1280, 720);
    expect(w.tick(), isFalse, reason: 'nhịp đầu: lần xin của widget (100 ms) có thể còn đang chạy');
    expect(w.tick(), isTrue);
    expect(w.tick(), isTrue);
    expect(w.retries, 2);
    w.got(1280, 720);
    expect(ticks(w, 5), everyElement(isFalse));
    expect(w.retries, 2);
  });

  test('đổi cỡ: đếm lại từ đầu; texture cỡ cũ về muộn không tính là xong', () {
    final w = Shop3dTextureWatch()
      ..want(1280, 720)
      ..got(1280, 720);
    w.want(768, 432);
    expect(w.ready, isFalse);
    w.got(1280, 720);
    expect(w.ready, isFalse);
    expect(ticks(w, 3), [false, true, true]);
    w.want(900, 480);
    expect(w.retries, 0);
    expect(w.tick(), isFalse);
    w.got(900, 480);
    expect(w.ready, isTrue);
    expect(w.tick(), isFalse);
  });

  test('cùng cỡ gọi lại want (mỗi lần layout): không đặt lại bộ đếm', () {
    final w = Shop3dTextureWatch()..want(800, 450);
    expect(ticks(w, 2), [false, true]);
    w.want(800, 450);
    expect(w.tick(), isTrue);
    expect(w.retries, 2);
  });

  test('chưa có chỗ (cỡ 0) hoặc chưa layout: không xin', () {
    expect(ticks(Shop3dTextureWatch(), 4), everyElement(isFalse));
    final w = Shop3dTextureWatch()..want(0, 720);
    expect(ticks(w, 4), everyElement(isFalse));
  });

  test('hỏng mãi: dừng sau maxRetries lần, cỡ mới thì xin lại được', () {
    final w = Shop3dTextureWatch(maxRetries: 3)..want(1280, 720);
    expect(ticks(w, 10).where((r) => r).length, 3);
    expect(w.retries, 3);
    w.want(1300, 720);
    expect(ticks(w, 2), [false, true]);
  });
}
