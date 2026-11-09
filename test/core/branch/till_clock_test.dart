// §7-3 TillClock (docs/v3/city-gd4-spec.md §2 "Thời gian").
import 'package:flutter_test/flutter_test.dart';
import 'package:sugarleaf_bakery/core/branch/till_clock.dart';

const _min = 60000, _hour = 3600000;

void main() {
  final mark = DateTime.utc(2026, 11, 5, 9).millisecondsSinceEpoch;

  test('first: mốc 0 → không cộng, mốc = giờ máy', () {
    expect(
      TillClock.wall(markMs: 0, wallMs: mark),
      ClockStep(creditMs: 0, markMs: mark, anomaly: ClockAnomaly.first),
    );
  });

  test('chạy thường: cộng d, mốc = giờ máy', () {
    expect(TillClock.wall(markMs: mark, wallMs: mark + 3 * _hour), ClockStep(creditMs: 3 * _hour, markMs: mark + 3 * _hour));
    expect(TillClock.wall(markMs: mark, wallMs: mark), ClockStep(creditMs: 0, markMs: mark));
  });

  test('lùi trong 10 phút: không cộng, giữ mốc, không báo', () {
    for (final back in [1, 5 * _min, 10 * _min]) {
      expect(TillClock.wall(markMs: mark, wallMs: mark - back), ClockStep(creditMs: 0, markMs: mark), reason: '$back');
    }
  });

  test('behind (10 phút < lùi ≤ 72 giờ) rồi giờ máy đuổi kịp', () {
    for (final back in [10 * _min + 1, 2 * _hour, 72 * _hour]) {
      expect(
        TillClock.wall(markMs: mark, wallMs: mark - back),
        ClockStep(creditMs: 0, markMs: mark, anomaly: ClockAnomaly.behind),
        reason: '$back',
      );
    }
    // Giờ máy đuổi kịp và vượt mốc 30 phút → chỉ cộng 30 phút.
    expect(TillClock.wall(markMs: mark, wallMs: mark + 30 * _min), ClockStep(creditMs: 30 * _min, markMs: mark + 30 * _min));
  });

  test('rescued: lùi quá 72 giờ → đặt lại mốc, không cộng', () {
    final w = mark - 72 * _hour - 1;
    expect(TillClock.wall(markMs: mark, wallMs: w), ClockStep(creditMs: 0, markMs: w, anomaly: ClockAnomaly.rescued));
  });

  test('năm 1970 / trước 1970', () {
    final r = TillClock.wall(markMs: mark, wallMs: 5000);
    expect(r, const ClockStep(creditMs: 0, markMs: 5000, anomaly: ClockAnomaly.rescued));
    // Sửa lại giờ: cộng một khoảng rất lớn (két tự kẹp ở trần, xem city_branches_test).
    expect(TillClock.wall(markMs: 5000, wallMs: mark).creditMs, mark - 5000);
    // Giờ âm kẹp về 0 → mốc 0 (chưa đặt): lần sau là `first`, không cộng.
    final neg = TillClock.wall(markMs: mark, wallMs: -86400000);
    expect(neg, const ClockStep(creditMs: 0, markMs: 0, anomaly: ClockAnomaly.rescued));
    expect(TillClock.wall(markMs: neg.markMs, wallMs: mark).anomaly, ClockAnomaly.first);
    expect(TillClock.wall(markMs: neg.markMs, wallMs: mark).creditMs, 0);
  });

  test('trong phiên: đồng hồ đơn điệu cộng Δ', () {
    expect(TillClock.mono(markMs: mark, monoDeltaMs: 1500), ClockStep(creditMs: 1500, markMs: mark + 1500));
    expect(TillClock.mono(markMs: mark, monoDeltaMs: 0), ClockStep(creditMs: 0, markMs: mark));
    expect(TillClock.mono(markMs: mark, monoDeltaMs: -5), ClockStep(creditMs: 0, markMs: mark));
    // Chưa có mốc → không cộng.
    expect(TillClock.mono(markMs: 0, monoDeltaMs: 1000), const ClockStep(creditMs: 0, markMs: 0));
    // Không vượt 2^53 − 1.
    const top = 9007199254740991;
    expect(TillClock.mono(markMs: top - 10, monoDeltaMs: 100).markMs, top);
  });

  test('đổi múi giờ (cùng một thời điểm) → 0', () {
    final utc = DateTime.utc(2026, 11, 5, 3);
    final hcm = DateTime.parse('2026-11-05T10:00:00+07:00');
    final ny = DateTime.parse('2026-11-04T22:00:00-05:00');
    for (final d in [hcm, ny, utc.toLocal()]) {
      expect(
        TillClock.wall(markMs: utc.millisecondsSinceEpoch, wallMs: d.millisecondsSinceEpoch),
        ClockStep(creditMs: 0, markMs: utc.millisecondsSinceEpoch),
      );
    }
  });
}
