# V2 · Giai đoạn 5 — Cảnh mở đầu, intro ngắn, hướng dẫn L1–3 lần đầu

Nhánh `v2`. Tiếp nối GĐ1–4. Chỉ chạy ngang, khung 1280×720, mọi chữ qua AppLocalizations (en, vi).

## 1. Luồng khởi động
| Lần mở | Luồng |
|---|---|
| Lần đầu (chưa có `introSeen`) | Cảnh mở đầu 15–25 s (nút **Bỏ qua** luôn hiện) → vào thẳng **L1** (thẻ Sẵn sàng → hướng dẫn) |
| Các lần sau | Intro ngắn 3–5 s (tủ kính lấp lánh + logo) → chạm bất kỳ / hết giờ → **bản đồ** |
| Người chơi cũ quy đổi từ v1 | Coi như đã xem cảnh mở đầu (`introSeen = true`), hướng dẫn L1–3 coi như xong |
- Bỏ qua cảnh mở đầu vẫn đánh dấu đã xem. Cài đặt có nút "Xem lại cảnh mở đầu" và "Hướng dẫn lại L1–3".
- Không chặn UI bằng I/O: ảnh cảnh nạp trước khi bắt đầu từng cảnh; thiếu ảnh → nền giấy SL + chữ, không crash.
- Hộp trên bản đồ (lời chào / vắng nhà / quà) chạy sau intro như hiện nay.

## 2. Cảnh mở đầu (dev-ui, Flutter: parallax, ánh sáng, hạt lấp lánh, hơi nước — vẽ code; ảnh từ Gemini)
| # | Thời lượng | Ảnh | Chuyển động | Chữ (phụ đề nhỏ, tuỳ chọn) |
|---|---|---|---|---|
| 1 | ~6 s | `scenes/intro_kitchen.webp` (bếp buổi sáng, lò gạch đỏ lửa, nắng xiên) | phóng chậm 1.0→1.08 + trượt nhẹ; tia nắng (gradient) nhấp nháy chậm; hạt bụi nắng; **hơi nước** bốc từ miệng lò (hạt mờ vẽ code) | "Một buổi sáng ở thị trấn ven biển…" |
| 2 | ~6 s | `shop/shop_base.webp` (tủ kính đầy bánh, có sẵn) | máy quay lia từ trái sang tủ kính (pan 2 lớp: nền + lớp đèn) rồi phóng vào tủ; lấp lánh trên kính | "Tủ bánh của bà vẫn sáng như ngày nào." |
| 3 | ~7 s | `scenes/intro_door.webp` (cửa kính tiệm nhìn từ trong, không có bảng/chuông) + `level/open_sign.webp` + `level/door_bell.webp` + Mai (`characters/mai_smile`, `mai_joy`) | Mai bước vào khung (trượt + nhún), bảng treo **lật** (scaleX 1→0→1, mặt sau hiện chữ "Mở cửa"/"Open" vẽ bằng Fredoka trên bảng trống) → chuông **lắc** (xoay ±12° tắt dần) + `audio.success()` + vòng sóng nhỏ; Mai đổi `joy` | "Mai lật tấm biển — tiệm Sugarleaf mở cửa!" |
| 4 | ~3 s | logo | logo hiện (phóng 0.9→1 + mờ dần vào), lấp lánh | — |
- Logo: chữ "Sugarleaf Bakery" (`appTitle`, Fredoka, viền nâu) + `level/logo_emblem.webp` (huy hiệu tròn bánh + lá, không chữ). Không có ảnh logo chữ.
- Tổng ~22 s. Chuyển cảnh: mờ chéo 400 ms. Tôn trọng "giảm chuyển động" của hệ thống (rút ngắn, bỏ pan/hạt).
- 60 fps: hạt dùng bể cố định, không cấp phát mỗi khung; ảnh giải mã đúng cỡ màn.

## 3. Intro ngắn (dev-ui)
`shop/shop_base.webp` phóng chậm vào tủ kính + lấp lánh + logo + dòng nhỏ "Chạm để vào tiệm" nhấp nháy. 4 s tự sang bản
đồ; chạm bất kỳ lúc nào → bản đồ ngay. Dùng như "splash" sau màn khởi động gốc của Flutter.

## 4. Hướng dẫn L1–L3 lần đầu
Kịch bản (bước, điều kiện xong, chỗ chỉ tay). Trong lúc một bước đang hiện: **không sinh khách mới, kiên nhẫn của khách
không giảm, đồng hồ màn dừng** (nhưng thao tác người chơi vẫn chạy). Mỗi bước: tay chỉ (`level/tutorial_hand.webp`, nhún
nhẹ), vùng sáng quanh mục tiêu (phần còn lại tối mờ 45%), bong bóng chữ ngắn cạnh mục tiêu. Chạm sai chỗ không bị chặn
(trừ khi bước yêu cầu), chỉ nhấp nháy lại tay chỉ.

- **L1** (`tutorial: "basics"`):
  1. Khách đầu tiên tới quầy muốn cupcake vani → chỉ bong bóng/khách: "Khách muốn bánh này. Chạm khách để bán!" — xong khi bán.
  2. Khi tủ còn ≤ 1 cupcake: chỉ thẻ bánh ở bếp: "Tủ sắp hết. Chạm để làm mẻ mới!" — xong khi `startBatch`.
  3. Khuôn: "Chọn đúng khuôn" (chỉ khuôn đúng) → Trộn: "Xoay tròn để trộn" (chỉ bát, hình tay xoay) → Lò: "Đợi kim tới vạch vàng rồi chạm" (chỉ lò, chỉ hiện khi kim gần vạch) → Kem: "Vẽ theo đường kem" → Topping: "Chạm hũ đúng 3 lần" → Hộp: "Chọn hộp đúng" — mỗi bước xong khi thao tác tương ứng xong.
  4. Mẻ vào tủ: "Bánh đã lên tủ. Cứ thế phục vụ thật nhiều khách nhé!" (tự ẩn sau 3 s) → màn chạy bình thường.
- **L2** (`tutorial: "combo"`): khi bán lượt 2 liên tiếp trong cửa sổ combo → chỉ đồng hồ combo ở HUD: "Bán liên tục để
  nhân combo — tiền nhiều hơn!"; khi có món thứ 2 (chocolate) lần đầu ở bong bóng → "Mỗi khách muốn một món khác nhau."
- **L3** (`tutorial: "patience"`): khách đầu tiên có vòng kiên nhẫn dưới 50% → "Vòng màu là sự kiên nhẫn. Phục vụ nhanh để
  được tip!"; khi lần đầu có khách bỏ về → "Khách chờ lâu quá sẽ bỏ đi." (không dừng). Mục tiêu xu: thẻ Sẵn sàng có dòng
  nhắc "Màn này tính theo xu kiếm được".
- `levels.json`: trường tuỳ chọn `tutorial` (id kịch bản) trên level; kịch bản nằm trong code core (không cần sửa JSON).
- Hướng dẫn xong một lần (kể cả thua giữa chừng sau khi xong bước cuối) → lưu `tutorialsDone`; chơi lại không hiện. Thoát
  giữa chừng → lần sau hiện lại từ đầu.
- Bot cân bằng chạy **không** hướng dẫn (giữ số liệu cũ).

## 5. Hợp đồng API
`lib/core` (dev-core):
```dart
// GameState
bool get introSeen; void markIntroSeen(); void resetIntro();
bool isTutorialDone(String id); void markTutorialDone(String id); void resetTutorials();
// LevelData: String? tutorial;   (L1 "basics", L2 "combo", L3 "patience")
// lib/core/level/tutorial.dart
enum TutorialTarget { customer, caseSlot, treatCard, mould, mix, oven, frost, topping, box, comboMeter, patienceRing, none }
class TutorialStep { final String id; final TutorialTarget target; final bool blocking /*dừng giờ/khách*/; final Duration? autoHide; }
class TutorialRunner {   // LevelSession sở hữu khi level.tutorial != null && chưa xong
  TutorialStep? get current; int? get targetCustomer; RecipeId? get targetRecipe; MouldType? get targetMould; …
  bool get finished; }
// LevelSession: TutorialRunner? tutorial; khi current?.blocking → không sinh khách, không giảm kiên nhẫn, không trừ giờ.
// SessionEvent mới (CUỐI enum): tutorialStep (bước mới hiện), tutorialDone.
// AppRoutes: intro ('/intro'), shortIntro ('/splash'); route đầu tiên do dev-ui chọn theo introSeen.
```
- Bản lưu: `introSeen` (bool), `tutorialsDone` (list), đọc độc lập; quy đổi v1 → introSeen = true, cả 3 hướng dẫn xong.
- Test: kịch bản chạy đúng thứ tự với thao tác giả; bước blocking dừng giờ/khách/kiên nhẫn; xong lưu; chơi lại không hiện;
  bot không bị ảnh hưởng.

`lib/game` (dev-game): vẽ lớp hướng dẫn trong `LevelPlayView` theo `session.tutorial.current`: tìm toạ độ mục tiêu (khách,
ô tủ, thẻ bánh, khuôn đúng, bát, lò, kem, hũ đúng, hộp đúng, ô combo HUD, vòng kiên nhẫn), vùng sáng + nền tối, tay chỉ
nhún, bong bóng chữ (chuỗi qua `LevelLabels` từ UI như các nhãn khác). Không chặn chạm ngoài vùng trừ khi cần. Test vị trí
mục tiêu cho từng bước, perf như cũ.

`lib/ui` (dev-ui): `IntroScreen` (cảnh mở đầu), `ShortIntroScreen`, chọn route đầu theo `introSeen`, sau cảnh mở đầu vào
thẳng L1, nhãn chuỗi hướng dẫn cho `LevelLabels`, nút Cài đặt "Xem lại cảnh mở đầu" / "Hướng dẫn lại". Chuỗi mới ở
`docs/v2/phase5-strings-ui.md`.

## 6. Ảnh (trưởng phòng, Gemini)
| File | Loại | Mô tả |
|---|---|---|
| `scenes/intro_kitchen.webp` | SCENE 1280×720 | bếp buổi sáng, lò gạch đỏ lửa có bánh mì, nắng xiên qua cửa sổ, không người |
| `scenes/intro_door.webp` | SCENE 1280×720 | cửa kính gỗ tiệm nhìn từ trong, phố sáng sớm bên ngoài; chừa móc treo trống và giá chuông trống |
| `level/open_sign.webp` | OBJECT | bảng gỗ treo dây, mặt kem trống (không chữ) |
| `level/door_bell.webp` | OBJECT | chuông đồng cửa tiệm trên giá uốn |
| `level/tutorial_hand.webp` | OBJECT | bàn tay chỉ hoạt hình, cổ tay áo kem |
| `level/logo_emblem.webp` | OBJECT | huy hiệu tròn: cupcake + lá, không chữ |
Âm thanh: chưa có tệp âm thanh trong dự án (AudioService giả lập) — chuông cửa dùng `success()`; ghi vào danh sách thiếu.

## 7. Chia việc
| Ai | Khu vực | Việc |
|---|---|---|
| dev-core | lib/core, main.dart, assets/config, test/core | §5 phần core, kịch bản, routes, lưu |
| dev-game | lib/game, test/game | lớp hướng dẫn trong màn chơi |
| dev-ui | lib/ui, test/ui, tool/screens | §1–3, nhãn hướng dẫn, Cài đặt |
| localizer | .arb | chuỗi `docs/v2/phase5-strings-ui.md` |
| trưởng phòng | assets/art | 6 ảnh §6 |
