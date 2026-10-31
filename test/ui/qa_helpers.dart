import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sugarleaf_bakery/core/game_state.dart';
import 'package:sugarleaf_bakery/core/models/ids.dart';

import 'ui_test_helpers.dart';

/// Helper dùng chung cho các test QA giao diện (`qa_*_test.dart`). Không phải file test (không có `main`).

/// `--dart-define=QA_RUN_BUGS=true` → chạy cả các test đang skip vì lỗi đã biết (để tái hiện / kiểm khi đã sửa).
const qaRunBugs = bool.fromEnvironment('QA_RUN_BUGS');

/// `skip:` cho test lộ ra lỗi thật đã ghi ở docs/qa/raw/ui.md: [reason] = "QA-BUG: mô tả lỗi" (testWidgets chỉ nhận
/// `bool`, nên lý do ghi ở đây + tên test). true = bỏ qua (mặc định).
bool qaBug(String reason) => !qaRunBugs;

/// Cỡ màn hình ngang cần thử: tên, kích thước vật lý, mật độ điểm ảnh, padding tai thỏ (logic).
class QaViewport {
  const QaViewport(this.name, this.physical, {this.dpr = 1, this.notch = 0});

  final String name;
  final Size physical;
  final double dpr;
  final double notch;

  Size get logical => physical / dpr;

  void apply(WidgetTester tester) {
    tester.view.physicalSize = physical;
    tester.view.devicePixelRatio = dpr;
    tester.view.padding = FakeViewPadding(left: notch * dpr, right: notch * dpr);
    tester.view.viewPadding = FakeViewPadding(left: notch * dpr, right: notch * dpr);
  }

  @override
  String toString() => name;
}

/// Các cỡ theo yêu cầu QA (đơn vị logic = vật lý, dpr 1) + một cỡ có tai thỏ.
const qaViewports = [
  QaViewport('1280x720', Size(1280, 720)),
  QaViewport('1600x720', Size(1600, 720)),
  QaViewport('3200x1440', Size(3200, 1440)),
  QaViewport('2048x1536', Size(2048, 1536)),
  QaViewport('1280x720+notch48', Size(1280, 720), notch: 48),
];

/// Máy thật (dpr thật): khung 1280×720 co lại theo cỡ logic → vùng chạm nhỏ đi.
const qaRealDevices = [
  // 720×1600 dọc, ~320 dpi (dpr 2) → ngang 800×360 dp.
  QaViewport('720x1600@2.0 (20:9 nhỏ)', Size(1600, 720), dpr: 2),
  // 1080×2400, dpr 2.625 → ngang ~914×411 dp (máy tầm trung phổ biến).
  QaViewport('1080x2400@2.625', Size(2400, 1080), dpr: 2.625),
  // Tablet 4:3 2048×1536 dpr 2 → 1024×768 dp.
  QaViewport('2048x1536@2.0 (tablet)', Size(2048, 1536), dpr: 2),
];

Map<String, dynamic> _arb(String lang) =>
    jsonDecode(File('lib/l10n/app_$lang.arb').readAsStringSync()) as Map<String, dynamic>;

final Map<String, dynamic> _en = _arb('en');
final Map<String, dynamic> _vi = _arb('vi');

/// Chuỗi tiếng Anh (không tham số) mà bản vi dịch khác — hiện nguyên văn khi đang vi = chưa dịch.
final Set<String> qaEnglishOnly = {
  for (final e in _en.entries)
    if (!e.key.startsWith('@') &&
        e.value is String &&
        !(e.value as String).contains('{') &&
        RegExp('[A-Za-z]{3,}').hasMatch(e.value as String) &&
        _vi[e.key] is String &&
        _vi[e.key] != e.value)
      e.value as String,
};

/// Tên khoá ARB (hiện thẳng tên khoá = lỗi tra chuỗi).
final Set<String> qaArbKeys = {
  for (final k in _en.keys)
    if (!k.startsWith('@')) k,
};

/// Mọi chuỗi đang hiện (RichText, không tính phần offstage).
List<String> qaVisibleTexts(WidgetTester tester) => [
      for (final w in tester.widgetList<RichText>(find.byType(RichText))) w.text.toPlainText(),
    ];

/// Lỗi nội dung chữ: khoá thô, chuỗi en khi đang vi, sao ký tự ★/☆.
List<String> qaTextProblems(WidgetTester tester, {required bool vi}) {
  final out = <String>[];
  for (final t in qaVisibleTexts(tester)) {
    final s = t.trim();
    if (s.isEmpty) continue;
    if (qaArbKeys.contains(s)) out.add('khoá thô: "$s"');
    if (vi && qaEnglishOnly.contains(s)) out.add('chưa dịch (en khi đang vi): "$s"');
    if (s.contains('★') || s.contains('☆')) out.add('còn glyph sao: "$s"');
  }
  return out;
}

/// Widget Material lệch phong cách vẽ tay còn sót trên màn.
const qaMaterialTypes = <Type>[
  ElevatedButton,
  TextButton,
  OutlinedButton,
  FilledButton,
  FloatingActionButton,
  AlertDialog,
  SimpleDialog,
  SnackBar,
  Switch,
  Checkbox,
  Radio<Object>,
  Slider,
  AppBar,
  BottomNavigationBar,
  TabBar,
  LinearProgressIndicator,
  CircularProgressIndicator,
];

List<String> qaMaterialLeftovers() => [
      for (final t in qaMaterialTypes)
        if (find.byType(t).evaluate().isNotEmpty) '$t',
    ];

/// Bắt mọi FlutterError (overflow, ngoại lệ dựng) trong [body], trả về mô tả ngắn. Khôi phục `onError` trước khi
/// test kết thúc (binding kiểm tra). [where] = nhãn chỗ đang kiểm (ghi kèm lỗi, cùng widget tạo ra lỗi).
Future<List<String>> qaCatchErrors(Future<void> Function() body, {String Function()? where}) async {
  final errors = <String>[];
  final old = FlutterError.onError;
  FlutterError.onError = (d) {
    final at = where?.call();
    // `--dart-define=QA_VERBOSE=true` → in đầy đủ lỗi (widget gây tràn, file:dòng).
    if (const bool.fromEnvironment('QA_VERBOSE')) debugPrint(d.toString());
    final creator = (d.informationCollector?.call() ?? const <DiagnosticsNode>[])
        .map((n) => n.toString())
        .where((t) => t.contains('creator'))
        .join(' ');
    errors.add('${at == null ? '' : '[$at] '}${d.exceptionAsString().split('\n').first}'
        '${creator.isEmpty ? '' : ' — ${creator.split('\n').first}'}');
  };
  try {
    await body();
  } finally {
    FlutterError.onError = old;
  }
  return errors;
}

/// Bước khung thủ công (màn chơi Flame / cảnh mở đầu chạy liên tục).
Future<void> qaFrames(WidgetTester tester, [int n = 10, int ms = 50]) async {
  for (var i = 0; i < n; i++) {
    await tester.pump(Duration(milliseconds: ms));
  }
}

/// Đồng hồ giả cho ván QA (đổi được: vắng nhà).
DateTime qaNow = DateTime(2026, 10, 28, 10);

/// Ván QA: ngôn ngữ [lang], đã xem intro + cảnh mở màn, đã nhận quà ngày (trừ khi [claimLogin] = false), qua
/// L1..[cleared] 3★.
GameState qaState(
  LanguagePref lang, {
  int cleared = 1,
  bool claimLogin = true,
  bool prologueSeen = true,
  int coins = 320,
}) {
  final state = GameState.newGame(clock: () => qaNow)
    ..setLanguage(lang)
    ..markIntroSeen();
  if (prologueSeen) state.markSceneSeen(StorySceneId.prologue);
  if (claimLogin) state.claimLogin();
  testServices(state, levels: qaLevels); // gắn levels + unlocks + monetization như main.dart
  winLevels(state, [for (var id = 1; id <= cleared; id++) id], coins: coins);
  return state;
}

/// levels.json thật (đủ tới L50 nếu có; thiếu thì chép thêm chương thử).
final qaLevels = testExtendedLevelConfig(upTo: 45);

/// Ván đã thuê quản lý và đang có thu nhập vắng nhà chờ nhận (hộp "Khi bạn vắng nhà").
GameState qaStateWithOffline(LanguagePref lang) {
  final unlocks = testUnlockConfig();
  final u = unlocks.unlock(StaffIds.manager)!;
  final state = qaState(lang, cleared: u.level);
  state.addCoins(u.price);
  expect(state.buyUnlock(StaffIds.manager), PurchaseResult.ok);
  state.refreshOffline(qaNow);
  qaNow = qaNow.add(const Duration(hours: 3, minutes: 20));
  state.refreshOffline(qaNow);
  expect(state.pendingOffline, isNotNull);
  return state;
}
