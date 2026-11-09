/// Theo dõi texture của ảnh 3D ([Shop3dSurface]) để xin lại khi lần cấp hỏng (Dart thuần, test được).
///
/// Web: `ThermionWidget` xin texture 100 ms sau lần layout đầu / đổi cỡ và tìm canvas trong DOM. Canvas nằm trong
/// platform view; platform view vừa tạo (lần chèn đầu, hoặc widget bị gỡ rồi dựng lại) thì canvas rời DOM tới khi khung
/// có platform view được ghép — luồng chính bận (dựng cảnh, Filament dịch shader, GL phần mềm) quá 100 ms là lần xin
/// hỏng ("Failed to size for canvas" + lỗi null), và widget không tự xin lại cho tới lần dựng lại sau: cảnh trống, hoặc
/// canvas giữ cỡ cũ (ảnh bị cắt / phóng to). Lớp này giữ cỡ đang xin / đã cấp; [tick] theo nhịp báo khi nào nên dựng
/// lại widget để nó xin lại (canvas lúc đó đã vào DOM).
class Shop3dTextureWatch {
  Shop3dTextureWatch({this.maxRetries = 20});

  /// Một cỡ xin lại tối đa chừng này lần (≈ 10 s ở nhịp 0,5 s) rồi thôi — không xả lỗi ra console mãi.
  final int maxRetries;

  (int, int)? _want;
  (int, int)? _got;
  int _waited = 0;
  int _retries = 0;

  /// Cỡ ảnh (điểm ảnh thật) widget đang xin — như `ThermionWidget`: ceil(cỡ logic × devicePixelRatio). Cỡ mới → đếm
  /// lại từ đầu.
  void want(int width, int height) {
    final w = (width, height);
    if (w == _want) return;
    _want = w;
    _waited = 0;
    _retries = 0;
  }

  /// Texture cỡ này đã được cấp.
  void got(int width, int height) => _got = (width, height);

  /// Texture đúng cỡ đang xin đã được cấp.
  bool get ready => _want != null && _want == _got;

  /// Số lần đã xin lại cho cỡ đang xin.
  int get retries => _retries;

  /// Gọi mỗi nhịp: true = cỡ đang xin vẫn chưa được cấp sau trọn một nhịp chờ (lần xin của widget đã chạy và hỏng) →
  /// dựng lại widget để xin lại; sau đó mỗi nhịp một lần tới khi được hoặc hết [maxRetries]. Cỡ 0 (chưa có chỗ) không
  /// xin.
  bool tick() {
    final w = _want;
    if (w == null || w.$1 <= 0 || w.$2 <= 0 || ready || _retries >= maxRetries) return false;
    if (++_waited < 2) return false;
    _retries++;
    return true;
  }
}
