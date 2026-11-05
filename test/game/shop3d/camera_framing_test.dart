import 'package:flutter_test/flutter_test.dart';
import 'package:sugarleaf_bakery/game/shop3d/camera_framing.dart';

void main() {
  FramePoint p(double x, double z, [double y = 0.9]) => (x: x, y: y, z: z);

  test('rỗng → null', () => expect(frameTargets(const []), isNull));

  test('một điểm: target = điểm, distance = tối thiểu', () {
    final r = frameTargets([p(2, 5, 0.9)])!;
    expect(r.target.x, 2);
    expect(r.target.z, 5);
    expect(r.distance, 5.2);
  });

  test('sự kiện: Mai + hai khách → trung điểm hộp bao, distance theo khoảng cách', () {
    final r = frameTargets([p(2.2, 4.8), p(1.75, 5.5), p(2.65, 5.5)])!;
    expect(r.target.x, closeTo(2.2, 1e-9));
    expect(r.target.z, closeTo(5.15, 1e-9));
    expect(r.distance, closeTo(5.2 + 1.1 * 0.9, 1e-9));
  });

  test('distance kẹp ở tối đa; y kẹp 0,6–1,2', () {
    final r = frameTargets([p(0, 0, 3), p(30, 0, 3)])!;
    expect(r.distance, 11);
    expect(r.target.y, 1.2);
    expect(frameTargets([p(0, 0, 0)])!.target.y, 0.6);
  });
}
