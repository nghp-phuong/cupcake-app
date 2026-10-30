/// Hướng dẫn lần đầu trong màn chơi (GĐ5): kiểu dữ liệu chung cho lớp vẽ (dev-game) và nhãn chuỗi (dev-ui).
///
/// Kịch bản (bước nào hiện khi nào, xong khi nào, chỉ vào đâu) chạy trong `LevelSession` (`tutorial_runner.dart`);
/// file này chỉ có các bước cố định + giao diện đọc [TutorialRunner]. Id kịch bản: `TutorialIds` (level_data.dart).
library;

import '../models/ids.dart';
import 'level_data.dart' show TutorialIds;

export 'level_data.dart' show TutorialIds;

/// Chỗ tay chỉ / vùng sáng của một bước.
enum TutorialTarget {
  /// Khách [TutorialRunner.targetCustomer] (bong bóng món + người).
  customer,

  /// Ô tủ kính đang chứa [TutorialRunner.targetRecipe].
  caseSlot,

  /// Thẻ bánh [TutorialRunner.targetRecipe] ở cột trái bếp nhanh.
  treatCard,

  /// Khuôn đúng [TutorialRunner.targetMould] ở trạm Khuôn.
  mould,

  /// Âu trộn (tay xoay tròn).
  mix,

  /// Lò [TutorialRunner.targetOven].
  oven,

  /// Bánh ở trạm Kem (đường kem gợi ý).
  frost,

  /// Hũ đúng [TutorialRunner.targetTopping].
  topping,

  /// Hộp đúng [TutorialRunner.targetBox].
  box,

  /// Ô combo ở HUD.
  comboMeter,

  /// Vòng kiên nhẫn của khách [TutorialRunner.targetCustomer].
  patienceRing,

  /// Không chỉ vào đâu (chỉ bong bóng chữ giữa màn).
  none,
}

/// Một bước hướng dẫn (bất biến). [id] = khoá để UI tra chuỗi (xem [TutorialSteps]).
class TutorialStep {
  const TutorialStep({required this.id, required this.target, this.blocking = true, this.autoHide});

  final String id;
  final TutorialTarget target;

  /// true → trong lúc bước hiện: không sinh khách, kiên nhẫn không giảm, đồng hồ màn dừng, nhân viên đứng chờ
  /// (lò, hoạt cảnh khách và thao tác của người chơi vẫn chạy).
  final bool blocking;

  /// Bước thông tin: tự ẩn sau chừng này (thời gian màn chơi chạy hoặc dừng đều tính, `paused` thì không), chạm bất kỳ
  /// đâu cũng ẩn (`LevelSession.dismissTutorialStep`). null = bước thao tác, xong khi người chơi làm đúng việc.
  final Duration? autoHide;

  /// Chạm để ẩn được (= có [autoHide]).
  bool get dismissible => autoHide != null;

  @override
  String toString() => 'TutorialStep($id → ${target.name}${blocking ? ', dừng giờ' : ''})';
}

/// Mọi bước của ba kịch bản, theo thứ tự hiện. Chuỗi UI nên đặt theo [TutorialStep.id].
abstract final class TutorialSteps {
  // ---- L1 `basics`
  /// "Khách muốn bánh này. Chạm khách để bán!" — xong khi bán.
  static const basicsSell = TutorialStep(id: 'basicsSell', target: TutorialTarget.customer);

  /// "Chạm thẻ bánh để làm mẻ mới nhé!" — tủ ≤ 1 hoặc 20 s sau bước Bán chưa làm mẻ; xong khi `startBatch`.
  static const basicsBake = TutorialStep(id: 'basicsBake', target: TutorialTarget.treatCard);

  /// "Chọn đúng khuôn".
  static const basicsMould = TutorialStep(id: 'basicsMould', target: TutorialTarget.mould);

  /// "Xoay tròn để trộn".
  static const basicsMix = TutorialStep(id: 'basicsMix', target: TutorialTarget.mix);

  /// "Đợi kim tới vạch vàng rồi chạm" — chỉ hiện khi kim gần vạch.
  static const basicsOven = TutorialStep(id: 'basicsOven', target: TutorialTarget.oven);

  /// "Vẽ theo đường kem".
  static const basicsFrost = TutorialStep(id: 'basicsFrost', target: TutorialTarget.frost);

  /// "Chạm hũ đúng 3 lần".
  static const basicsTopping = TutorialStep(id: 'basicsTopping', target: TutorialTarget.topping);

  /// "Chọn hộp đúng".
  static const basicsBox = TutorialStep(id: 'basicsBox', target: TutorialTarget.box);

  /// "Bánh đã lên tủ. Cứ thế phục vụ thật nhiều khách nhé!" — bước phụ (kịch bản đã xong khi mẻ vào tủ), tự ẩn sau
  /// 3 s, không dừng giờ.
  static const basicsDone = TutorialStep(
    id: 'basicsDone',
    target: TutorialTarget.caseSlot,
    blocking: false,
    autoHide: Duration(seconds: 3),
  );

  // ---- L2 `combo` (hai bước độc lập, bước nào tới trước hiện trước)
  /// "Bán liên tục để nhân combo — tiền nhiều hơn!" — khi combo lên 2.
  static const comboMeter = TutorialStep(
    id: 'comboMeter',
    target: TutorialTarget.comboMeter,
    autoHide: Duration(seconds: 4),
  );

  /// "Mỗi khách muốn một món khác nhau." — khi món mới của level lần đầu ở bong bóng khách đứng quầy.
  static const comboVariety = TutorialStep(
    id: 'comboVariety',
    target: TutorialTarget.customer,
    autoHide: Duration(seconds: 4),
  );

  // ---- L3 `patience`
  /// "Vòng màu là sự kiên nhẫn. Phục vụ nhanh để được tip!" — khách đứng quầy đầu tiên dưới 50% kiên nhẫn.
  static const patienceRing = TutorialStep(
    id: 'patienceRing',
    target: TutorialTarget.patienceRing,
    autoHide: Duration(seconds: 4),
  );

  /// "Khách chờ lâu quá sẽ bỏ đi." — lần đầu có khách bỏ về; không dừng giờ, tuỳ chọn (không có cũng xong kịch bản).
  static const patienceWalkout = TutorialStep(
    id: 'patienceWalkout',
    target: TutorialTarget.customer,
    blocking: false,
    autoHide: Duration(seconds: 3),
  );

  /// Bước của kịch bản [id] theo thứ tự (rỗng nếu id lạ).
  static List<TutorialStep> of(String id) => switch (id) {
        TutorialIds.basics => const [
            basicsSell,
            basicsBake,
            basicsMould,
            basicsMix,
            basicsOven,
            basicsFrost,
            basicsTopping,
            basicsBox,
            basicsDone,
          ],
        TutorialIds.combo => const [comboMeter, comboVariety],
        TutorialIds.patience => const [patienceRing, patienceWalkout],
        _ => const [],
      };
}

/// Trạng thái hướng dẫn của một lượt chơi (`LevelSession.tutorial`; null khi level không có hướng dẫn hoặc người
/// chơi đã xong). Chỉ đọc; lớp vẽ dựa vào [current] + các `target*`, đọc mỗi khung.
abstract interface class TutorialRunner {
  /// Id kịch bản (`TutorialIds`).
  String get id;

  /// Bước đang hiện (null = không có gì để vẽ lúc này).
  TutorialStep? get current;

  /// Thời gian bước [current] đã hiện (giây, không tính lúc `paused`).
  double get shownFor;

  /// Khách được chỉ (bước `customer` / `patienceRing`); null nếu không áp dụng hoặc khách đã rời cảnh.
  int? get targetCustomer;

  /// Món được chỉ (thẻ bánh, ô tủ, món trong bong bóng).
  RecipeId? get targetRecipe;

  /// Khuôn đúng của mẻ hướng dẫn (bước `mould`).
  MouldType? get targetMould;

  /// Lò chứa mẻ hướng dẫn (bước `oven`).
  int? get targetOven;

  /// Hũ topping đúng (bước `topping`).
  ToppingId? get targetTopping;

  /// Hộp đúng (bước `box`).
  BoxType? get targetBox;

  /// Đã xong phần bắt buộc của kịch bản (sự kiện `tutorialDone` đã phát → UI lưu `markTutorialDone`). Bước tuỳ chọn
  /// (L3 "khách bỏ đi") vẫn có thể hiện sau đó — lớp vẽ chỉ dựa vào [current].
  bool get finished;
}
