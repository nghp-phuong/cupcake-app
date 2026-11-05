/// Ngày lịch của máy cho thành phố (bộ đếm ăn trong ngày, quảng cáo thưởng): dạng `yyyy-mm-dd`.
library;

/// `yyyy-mm-dd` theo các trường năm / tháng / ngày của [d] (giờ máy nếu [d] là giờ địa phương).
String cityDateKey(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

final _dateKey = RegExp(r'^\d{4}-(0[1-9]|1[0-2])-(0[1-9]|[12]\d|3[01])$');

/// [s] đúng dạng `yyyy-mm-dd` (tháng 01–12, ngày 01–31).
bool isCityDateKey(String s) => _dateKey.hasMatch(s);
