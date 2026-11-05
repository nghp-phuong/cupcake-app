import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sugarleaf_bakery/ui/shop3d/dialogue_panel.dart';

/// Khung hội thoại cảnh 3D (đặc tả docs/v3/interaction-spec.md 2.4): chữ hiện dần 40 ký tự/s, chạm lần đầu hiện hết,
/// lần nữa sang câu sau; có lựa chọn thì chạm không gọi onNext và không có nút Bỏ qua.

class _Log {
  int next = 0, skip = 0;
  final choices = <int>[];
}

const _line =
    'Good morning, dear! The tart smells lovely today.'; // 49 ký tự → ~1,2 s

Future<_Log> _pump(
  WidgetTester tester, {
  String text = _line,
  List<String> choices = const [],
  bool withSkip = true,
  String? speaker = 'Mr. Hoa',
  Object? lineId,
}) async {
  tester.view.physicalSize = const Size(1280, 720);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final log = _Log();
  await tester.pumpWidget(
    MaterialApp(
      home: Stack(
        children: [
          Shop3dDialoguePanel(
            speaker: speaker,
            text: text,
            lineId: lineId,
            choices: choices,
            tapHint: 'Tap to continue',
            skipLabel: 'Skip',
            onNext: () => log.next++,
            onSkip: withSkip ? () => log.skip++ : null,
            onChoice: log.choices.add,
          ),
        ],
      ),
    ),
  );
  return log;
}

/// Phần chữ đang hiện (phần còn lại vẽ trong suốt để giữ bố cục).
String _shown(WidgetTester tester) {
  final t = tester.widget<Text>(find.byKey(Shop3dDialoguePanel.lineTextKey));
  final span = t.textSpan! as TextSpan;
  return (span.children!.first as TextSpan).text ?? '';
}

void main() {
  testWidgets('kích thước: rộng min(960, W−64), cao 168–200, ở đáy màn', (
    tester,
  ) async {
    await _pump(tester);
    // Chờ hiệu ứng trượt lên (0,25 × chiều cao) chạy xong rồi mới đo.
    await tester.pumpAndSettle();
    final r = tester.getRect(find.byKey(Shop3dDialoguePanel.panelKey));
    expect(r.width, 960);
    expect(r.height, inInclusiveRange(168, 200));
    expect(r.center.dx, 640);
    expect(r.bottom, lessThanOrEqualTo(720));
    expect(r.bottom, greaterThan(680));

    tester.view.physicalSize = const Size(800, 400);
    await tester.pump();
    expect(
      tester.getRect(find.byKey(Shop3dDialoguePanel.panelKey)).width,
      800 - 64,
    );
  });

  testWidgets('chữ hiện dần 40 ký tự/s rồi tự hiện hết', (tester) async {
    await _pump(tester);
    expect(_shown(tester), '');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    expect(_shown(tester).length, inInclusiveRange(9, 11));
    expect(_line.startsWith(_shown(tester)), isTrue);
    await tester.pump(const Duration(seconds: 2));
    expect(_shown(tester), _line);
  });

  testWidgets(
    'chạm lần đầu hiện hết câu (không gọi onNext), lần nữa gọi onNext',
    (tester) async {
      final log = await _pump(tester);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(_shown(tester).length, lessThan(_line.length));

      await tester.tap(find.byKey(Shop3dDialoguePanel.panelKey));
      await tester.pump();
      expect(_shown(tester), _line);
      expect(log.next, 0);

      await tester.tap(find.byKey(Shop3dDialoguePanel.panelKey));
      await tester.pump();
      expect(log.next, 1);
    },
  );

  testWidgets('chạm đúp trong cùng khung chỉ gọi onNext một lần', (
    tester,
  ) async {
    final log = await _pump(tester);
    await tester.pump(const Duration(seconds: 2));
    await tester.tap(find.byKey(Shop3dDialoguePanel.panelKey));
    await tester.tap(find.byKey(Shop3dDialoguePanel.panelKey));
    await tester.pump();
    expect(log.next, 1);
    await tester.tap(find.byKey(Shop3dDialoguePanel.panelKey));
    await tester.pump();
    expect(log.next, 2);
  });

  testWidgets('câu mới (đổi chữ hoặc lineId) chạy chữ lại từ đầu', (
    tester,
  ) async {
    await _pump(tester, lineId: 1);
    await tester.pump(const Duration(seconds: 2));
    expect(_shown(tester), _line);

    await _pump(tester, text: 'Next line.', lineId: 2);
    expect(_shown(tester), '');
    await tester.pump(const Duration(seconds: 1));
    expect(_shown(tester), 'Next line.');

    await _pump(tester, text: 'Next line.', lineId: 3);
    expect(
      _shown(tester),
      '',
      reason: 'trùng chữ nhưng khác lineId vẫn là câu mới',
    );
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('chữ tiếng Việt hiện theo cụm ký tự, không tách dấu', (
    tester,
  ) async {
    // "Ơ" dựng bằng chữ gốc + dấu kết hợp (2 code unit, 1 cụm).
    const text = 'Ơ! Cảm ơn nha.';
    await _pump(tester, text: text);
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 20));
      final s = _shown(tester);
      expect(s == 'O', isFalse, reason: 'không được hiện chữ gốc thiếu dấu');
    }
    await tester.pump(const Duration(seconds: 1));
    expect(_shown(tester), text);
  });

  testWidgets('nút Bỏ qua gọi onSkip, không gọi onNext', (tester) async {
    final log = await _pump(tester);
    expect(find.byKey(Shop3dDialoguePanel.skipKey), findsOneWidget);
    await tester.tap(find.byKey(Shop3dDialoguePanel.skipKey));
    await tester.pump();
    expect(log.skip, 1);
    expect(log.next, 0);
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('không truyền onSkip → không có nút Bỏ qua', (tester) async {
    await _pump(tester, withSkip: false);
    expect(find.byKey(Shop3dDialoguePanel.skipKey), findsNothing);
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets(
    'có lựa chọn: không có Bỏ qua, chạm khung không gọi onNext, chọn gọi onChoice',
    (tester) async {
      final log = await _pump(
        tester,
        choices: const ['Offer a cake', 'Tell a joke', 'Ask them to share'],
      );
      expect(find.byKey(Shop3dDialoguePanel.skipKey), findsNothing);
      expect(
        find.byKey(Shop3dDialoguePanel.choiceKey(0)),
        findsNothing,
        reason: 'lựa chọn hiện sau khi câu hiện hết',
      );

      await tester.tap(find.byKey(Shop3dDialoguePanel.panelKey));
      await tester.pumpAndSettle();
      expect(_shown(tester), _line);
      expect(log.next, 0);
      for (var i = 0; i < 3; i++) {
        final r = tester.getRect(find.byKey(Shop3dDialoguePanel.choiceKey(i)));
        expect(r.height, greaterThanOrEqualTo(56));
        expect(r.width, lessThanOrEqualTo(320));
      }
      expect(find.byKey(Shop3dDialoguePanel.skipKey), findsNothing);

      await tester.tap(find.byKey(Shop3dDialoguePanel.panelKey));
      await tester.pump();
      await tester.tap(find.byKey(Shop3dDialoguePanel.panelKey));
      await tester.pump();
      expect(log.next, 0, reason: 'không bao giờ bỏ qua lựa chọn');
      expect(log.skip, 0);

      await tester.tap(find.byKey(Shop3dDialoguePanel.choiceKey(1)));
      await tester.pump();
      expect(log.choices, [1]);
      expect(log.next, 0);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('lời dẫn (speaker = null) không có chip tên', (tester) async {
    await _pump(tester, speaker: null);
    expect(find.text('Mr. Hoa'), findsNothing);
    await tester.pump(const Duration(seconds: 2));
  });
}
