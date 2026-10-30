import '../../core/models/ids.dart';

/// Chuỗi vẽ trên canvas của màn chơi level (sân tiệm + bếp nhanh). `LevelPlayView` dựng từ `AppLocalizations`
/// (khoá `lvl…` + khoá sẵn có: tên trạm, khuôn, hộp, "Xong").
class LevelLabels {
  const LevelLabels({
    required this.caseFull,
    required this.rushHour,
    required this.combo,
    required this.done,
    required this.waitOven,
    required this.waiting,
    required this.pickTreat,
    required this.burnt,
    required this.takeOut,
    required this.stirHint,
    required this.swipeHint,
    required this.station,
    required this.mould,
    required this.box,
    this.tutorial = fallbackTutorial,
  });

  /// "Tủ đầy!" — mẻ đã đóng hộp nhưng tủ kính hết chỗ.
  final String caseFull;

  /// "Giờ cao điểm!" — băng rôn khi bắt đầu giờ cao điểm.
  final String rushHour;

  /// "Combo ×N".
  final String Function(int n) combo;

  /// Nút xong ở trạm kem.
  final String done;

  /// Trạm trộn: mẻ đã trộn xong, chờ lò trống.
  final String waitOven;

  /// Lò: đã lấy ra nhưng khu hoàn thiện đang bận.
  final String waiting;

  /// Trạm khuôn khi chưa có mẻ: chạm thẻ món bên trái.
  final String pickTreat;

  /// Lò: mẻ bị cháy.
  final String burnt;

  /// Lò: kim trong vùng vàng — chạm để lấy ra.
  final String takeOut;

  /// Trạm trộn: khuấy 1 vòng.
  final String stirHint;

  /// Trạm kem: quẹt ngang qua bánh.
  final String swipeHint;

  final String Function(StationId s) station;
  final String Function(MouldType m) mould;
  final String Function(BoxType b) box;

  /// Chữ ngắn của bước hướng dẫn L1–L3 theo id bước (`TutorialStep.id`, xem `TutorialSteps` của core); chuỗi rỗng → không vẽ nhãn.
  /// ui truyền chuỗi đã dịch qua `LevelPlayView.tutorialText`.
  final String Function(String step) tutorial;

  /// Chữ tiếng Anh dự phòng của các bước hướng dẫn (test / khi ui chưa truyền chuỗi).
  static String fallbackTutorial(String step) => switch (step) {
        'basicsSell' => 'This customer wants this treat. Tap them to sell!',
        'basicsBake' => 'The case is running low. Tap to bake a new batch!',
        'basicsMould' => 'Pick the right mould',
        'basicsMix' => 'Swirl around to mix',
        'basicsOven' => 'Wait for the needle to reach the gold mark, then tap',
        'basicsFrost' => 'Swipe along the frosting line',
        'basicsTopping' => 'Tap the right jar 3 times',
        'basicsBox' => 'Pick the right box',
        'basicsDone' => 'Your treats are in the case. Keep serving lots of customers!',
        'comboMeter' => 'Sell back-to-back to build a combo — more coins!',
        'comboVariety' => 'Each customer wants a different treat.',
        'patienceRing' => 'The ring is their patience. Serve fast to earn tips!',
        'patienceWalkout' => 'Customers who wait too long will leave.',
        _ => '',
      };

  /// Dự phòng khi chưa có l10n (test; không hiện cho người chơi trong app thật).
  static final fallback = LevelLabels(
    caseFull: 'Case full!',
    rushHour: 'Rush hour!',
    combo: (n) => 'Combo ×$n',
    done: 'Done',
    waitOven: 'Waiting for oven',
    waiting: 'Waiting…',
    pickTreat: 'Tap a treat',
    burnt: 'Burnt!',
    takeOut: 'Take out!',
    stirHint: 'Stir 1 turn',
    swipeHint: 'Swipe across',
    station: (s) => s.name,
    mould: (m) => m.name,
    box: (b) => b.name,
  );
}
