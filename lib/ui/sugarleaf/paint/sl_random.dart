/// Bộ sinh số giả ngẫu nhiên tất định (xorshift32): cùng seed → cùng dãy số trên VM lẫn web (chỉ dùng phép
/// dịch/xor/nhân nhỏ, không vượt 2^53). Dùng cho mọi nét run tay — không bao giờ dùng `Random()` khi vẽ.
class SLRandom {
  SLRandom(int seed) : _s = _scramble(seed);

  int _s;

  static const _mask = 0xFFFFFFFF;

  static int _step(int x) {
    x ^= (x << 13) & _mask;
    x ^= x >> 17;
    x ^= (x << 5) & _mask;
    return x & _mask;
  }

  static int _scramble(int seed) {
    var x = (seed ^ 0x2545F491) & _mask;
    if (x == 0) x = 0x6C8E9CF5;
    for (var i = 0; i < 4; i++) {
      x = _step(x);
    }
    return x;
  }

  /// Trộn hai số thành seed con (vd. seed của widget + số thứ tự lớp vẽ).
  static int mix(int a, int b) => _scramble(((a & _mask) * 31 + (b & 0xFFFF) * 7919 + 1) & _mask);

  /// Băm ổn định của chuỗi (djb2, 32 bit) — khác `String.hashCode`, giữ nguyên giữa các lần chạy và nền tảng.
  static int hashString(String s) {
    var h = 5381;
    for (final c in s.codeUnits) {
      h = ((h * 33) ^ c) & _mask;
    }
    return h;
  }

  int nextInt32() => _s = _step(_s);

  /// Số thực trong [0, 1).
  double nextDouble() => nextInt32() / 4294967296.0;

  double range(double a, double b) => a + (b - a) * nextDouble();

  /// Số nguyên trong [0, max).
  int nextInt(int max) => max <= 1 ? 0 : (nextDouble() * max).floor().clamp(0, max - 1);

  /// -1 hoặc 1.
  double sign() => nextDouble() < 0.5 ? -1 : 1;
}
