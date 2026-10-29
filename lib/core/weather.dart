/// Thời tiết theo ngày game: hàm thuần, xác định (không dùng `Random` của phiên) nên lưu/nạp lại ra cùng kết quả.
abstract final class Weather {
  /// Ngày mưa đầu tiên (luôn mưa, lần đầu gặp mèo Mochi).
  static const firstRainyDay = 5;

  /// Ngày 1–4 tạnh; ngày 5 mưa; từ ngày 6 mưa khi `(day * 37 + 11) % 4 == 0`,
  /// trừ khi ngày trước đã mưa (không bao giờ mưa hai ngày liền).
  static bool isRainy(int day) {
    if (day < firstRainyDay) return false;
    // Lặp từ ngày 5, nhớ kết quả ngày trước → không đệ quy sâu, O(day) phép tính số nguyên.
    var previous = true; // ngày 5
    for (var d = firstRainyDay + 1; d <= day; d++) {
      previous = !previous && _formula(d);
    }
    return previous;
  }

  static bool _formula(int day) => (day * 37 + 11) % 4 == 0;
}
