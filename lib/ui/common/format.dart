import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';

/// Phiên bản hiển thị ở cài đặt (chuỗi cố định, đặc tả mục 8.14).
const kAppVersionLabel = '0.1.0-alpha';

String _lang(BuildContext context) => Localizations.localeOf(context).languageCode == 'vi' ? 'vi' : 'en';

/// Số nguyên có phân tách hàng nghìn theo ngôn ngữ (1,800 / 1.800).
String formatInt(BuildContext context, int value) => NumberFormat.decimalPattern(_lang(context)).format(value);

/// Số thập phân 1 chữ số theo ngôn ngữ (4.5 / 4,5).
String formatDecimal1(BuildContext context, double value) => NumberFormat('0.0', _lang(context)).format(value);

/// Số có dấu (+12 / -8).
String formatSigned(BuildContext context, int value) =>
    value < 0 ? '-${formatInt(context, -value)}' : '+${formatInt(context, value)}';
