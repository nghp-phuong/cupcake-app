# Bước 1 – Khảo sát UI hiện tại (2026-10-28)

Mục tiêu: biết mọi widget UI đang dùng trước khi làm lại theo phong cách vẽ tay (giấy, gỗ, vải, viền nâu run tay,
màu nước). Số dòng ghi theo code lúc khảo sát.

## Tóm tắt

- 25 file trong `lib/ui`. Thêm 6 file UI nằm ngoài: `app.dart`, `core/theme.dart`, `core/ref_frame.dart`,
  `game/bake_session_view.dart`, `core/services/ad_service.dart`, và phần HUD vẽ canvas trong `game_paint.dart` cùng
  6 trạm.
- **86 chỗ `Icons.*` (57 icon khác nhau)** — đây là phần lệch phong cách rõ nhất.
- Khoảng **36 chỗ widget Material mặc định**: `MaterialApp`, `Scaffold` ×4, `Material`+`Ink`+`InkWell` ×6 (ripple),
  `Dialog`, `AlertDialog` (quảng cáo giả), `SnackBar` (toast), `ElevatedButton`/`FilledButton` (nút Xong, Đã hiểu
  ở màn làm bánh), `CircularProgressIndicator`, `Divider` ×3, `Tooltip` ×3, `CircleAvatar`.
- Không dùng: `AppBar`, `Card`, `ListTile`, `Chip`, `TabBar`, `Switch`, `Slider`, `Checkbox`, `LinearProgressIndicator`.
  Tab và toggle hiện là `PillChoice`.
- Phần lớn component đã tự viết (`SugarButton`, `Panel`, `TitleRibbon`…) nhưng **vẽ kiểu app phẳng**: gradient số,
  viền thẳng 2px, bo góc đều, ripple Material.

## Component tự viết hiện có → sẽ thay bằng

| Hiện tại | File | Dùng ở | Thay bằng (Bước 2) |
|---|---|---|---|
| `SugarButton` (gradient, viền 2px, InkWell) | `common/sugar_button.dart:11` | 21 chỗ, mọi màn | `SLButton` primary/secondary |
| `RoundIconButton` (tròn, Tooltip, chấm báo) | `sugar_button.dart:118` | menu, Back, Close, thoát ngày | `SLButton.icon` + `SLBadge` |
| `PillChoice` | `sugar_button.dart:202` | cài đặt (ngôn ngữ, âm thanh), tab trang trí | `SLChip` / `SLTabBar` / `SLToggle` |
| `Panel`, `AppTheme.panelDecoration` | `common/panel.dart:9` | 14 + 18 chỗ | `SLPanel`, `SLPaperCard` |
| `TitleRibbon`, `_TitleSign`, `_NameTag` | `panel.dart:40`, menu, day | 7 + 2 chỗ | `SLNameTag` (bảng gỗ / dải vải) |
| `TagChip`, `customerBadge`, `_Reward`, `_ToppingChip` | `panel.dart:70`, order_ticket, result_card | nhiều màn | `SLChip`, `SLBadge` |
| `SugarProgressBar`, `_LevelPips`, `_StepDot` | `panel.dart:101`, upgrades, bake | menu XP, nhiệm vụ, nâng cấp, làm bánh | `SLProgressBar` |
| `SugarDialog`, `showConfirmDialog` | `common/dialogs.dart:21,96` | quà, nhiệm vụ, xác nhận | `SLDialog` |
| `SimulatedAdDialog` (AlertDialog) | `core/services/ad_service.dart:105` | quảng cáo giả | `SLDialog` |
| `showToast` (SnackBar), `_Toast` game | `dialogs.dart:140`, `bake_session_view.dart:440` | 15 chỗ gọi | toast giấy dán (Overlay) |
| `CurrencyBar`, `CurrencyChip`, `PriceTag`, `_TopBar`, `_hud`, `_StepBar` | `currency_bar.dart`, menu, day, bake | thanh trên mọi màn | `SLTopBar` (nhãn giấy dán) |
| `AwningPainter` + `SugarScreen` + `CozyBackground` | `sugar_screen.dart`, `panel.dart:159,188` | 6 màn phụ | khung màn mới, nền ảnh `tiles`/`scenes` |
| `SpeechBubble` | `common/speech_bubble.dart` | quầy, kết quả | `SLSpeechBubble` (viền run tay) |
| `OrderTicket` (lớn) + `_OrderTicket` (nhỏ, trùng) | `day/order_ticket.dart:22`, `bake_session_view.dart:288` | quầy, làm bánh | `SLOrderTicket` (gộp 1) |
| `ResultCard` | `day/result_card.dart:40` | kết quả | `SLPaperCard` |
| Nút Xong, Đã hiểu (Material, chữ trắng) | `bake_session_view.dart:173,495` | làm bánh | `SLButton` |
| `CoinIcon`, `GemIcon`, `StarIcon`, `StarRow`, `ToolArt` | `common/art.dart:151`, `upgrades/tool_art.dart` | mọi màn | ảnh `assets/art/items/*` |

## Màn hình

| Màn | File | Widget chính |
|---|---|---|
| Menu chính | `menu/main_menu_screen.dart` | biển tên, Mai, thanh trên (cấp, XP, tiền, cài đặt), 5 SugarButton, 2 nút tròn có nhãn |
| Quà đăng nhập | `menu/login_gift_dialog.dart` | SugarDialog, 7 ô quà, nút Nhận |
| Truyện | `day/story_overlay.dart` | 2 nhân vật, khung thoại, ribbon tên, chấm tiến độ, Bỏ qua |
| Giới thiệu ngày | `day/day_screen.dart:366` | Panel + ribbon "Ngày N" + hàng khách |
| Quầy gọi món | `day/day_screen.dart`, `day/order_ticket.dart` | khách, bong bóng, bảng tên, vé đơn, nút Bắt đầu, HUD |
| 6 trạm làm bánh | `game/bake_session_view.dart`, `game/stations/*` | thanh bước, vé nhỏ, gợi ý, toast, nút Xong; trên canvas: ô chọn + nhãn, nút "Giữ", thanh đo |
| Kết quả vui/buồn | `day/result_card.dart` | thẻ kết quả, sao, bong bóng, dòng chê, 3 phần thưởng, 2 nút |
| Tổng kết ngày | `summary/day_summary_screen.dart` | nền chấm bi, ribbon, danh sách đơn, thống kê, băng lên cấp, 2 nút |
| Nâng cấp | `upgrades/upgrades_screen.dart` | 4 thẻ (hình code), pips cấp, giá, nút |
| Trang trí | `decor/decor_screen.dart` | xem trước, dải % tip, 5 CircleAvatar, 5 PillChoice, danh sách đồ |
| Sổ công thức | `recipes/recipe_book_screen.dart` | lưới 5×2, trang giấy kẻ |
| Nhiệm vụ | `menu/quests_dialog.dart` | SugarDialog, 3 dòng nhiệm vụ, thanh tiến độ, nút Nhận |
| Cửa hàng | `store/store_screen.dart` | băng "test store", lưới 3 cột sản phẩm, spinner |
| Cài đặt | `settings/settings_screen.dart` | Panel, 3 dòng (ngôn ngữ, âm thanh, reset), Divider |
| Khác | `dialogs.dart`, `ad_service.dart`, `core/ref_frame.dart` | xác nhận, quảng cáo giả, nhắc xoay máy, toast |

## Icon

**Thay được ngay bằng ảnh vẽ tay đã có** (`assets/art/items/`):

| Icon trong app | Thay bằng |
|---|---|
| xu, đá quý, sao | `coin`, `gem`, `star_on`/`star_off` |
| sổ công thức (`menu_book`) | `book` |
| quà (`card_giftcard`) | `gift_daily` |
| vé đơn (`receipt_long`) | `ticket` |
| lò, dụng cụ ở màn nâng cấp | `oven_1..5`, `tool_*` |
| icon "Nâng cấp" (`soup_kitchen`) | `oven_1` hoặc `bowl` |

**Chưa có ảnh, cần vẽ thêm** (gom trùng còn khoảng 35–40):
- **Điều hướng:** bánh răng, X đóng, quay lại, mũi tên tới, mũi tên lên/xuống, bỏ qua, cửa thoát.
- **Trạng thái:** dấu tích, khoá, thông tin, cảnh báo, lỗi, huy chương "tối đa".
- **Cài đặt:** loa bật/tắt, ngôn ngữ, điện thoại ("theo máy"), thùng rác, reset.
- **Quảng cáo:** nút play/video, "xoá quảng cáo".
- **Menu:** túi hàng/cửa tiệm, giỏ, bảng nhiệm vụ, ghế/trang trí.
- **5 ô trang trí:** giấy dán tường, sàn, quầy, cửa sổ, cây.
- **Game:** tim, huy hiệu VIP, khách, mặt trời, lửa, lấp lánh, cúp, pháo giấy, đồng hồ, tip, bóng đèn.
- **Khác:** logo lá, ghim vé đơn, chấm báo.

Danh sách kèm prompt Gemini sẽ có ở Bước 2.

## Kiểu Material cần bỏ

- `core/theme.dart:90-173`:
  - `useMaterial3`;
  - theme cho nút, dialog, card, snackbar, divider;
  - ripple mặc định (InkSparkle).
- `InkWell` + `Ink` + `Material` trong `SugarButton`, `RoundIconButton`, `PillChoice` và 3 màn khác.
- Gradient số:
  - `sugar_button.dart:79,159`;
  - `panel.dart:129`.
- Viền thẳng và bo góc đều:
  - 27 lần `Border.all`, 24 lần `BorderRadius.circular`;
  - `Divider`;
  - đường kẻ `Container(height: 2)`.
- Chữ trắng trên nền đặc:
  - nút Xong (`bake_session_view.dart:176`);
  - toast của game (`:456`);
  - dấu tích ở ô quà.

## Rủi ro đã thấy

1. **Font bản release Android:** app tải Fredoka/Nunito qua `google_fonts` lúc chạy, nhưng `android/app/src/main/AndroidManifest.xml` không có quyền INTERNET. Bản release vì vậy sẽ rơi về font hệ thống.
   - Cần đóng gói font vào app.
   - Fredoka thiếu dấu tiếng Việt; hiện tiêu đề tiếng Việt đang dùng Nunito.
2. **Test bám vào widget cũ:**
   - Một số test tìm theo tooltip ('Settings', 'Back', 'Close').
   - Có test tìm `SugarButton` theo chữ.
   - Có test kiểm `ElevatedButton` "Done".
   - Widget mới phải giữ tooltip/semantics, và các test này cần sửa theo.
3. **Font chữ đến từ `Scaffold`/`Dialog`:** 92 `TextStyle` không đặt font, chỉ thừa hưởng từ `Scaffold`/`Dialog`. Bỏ `Scaffold` hay `Material` thì phải bọc `DefaultTextStyle` ở một chỗ chung.
4. **Toạ độ tuyệt đối 1280×720** ở menu, quầy, làm bánh (`kPlayArea`). Khung giấy dày hơn có thể đè lên vùng chơi.
5. **Màu nền panel/nút đang mang nghĩa trạng thái** (đã nhận, đang chọn, khoá, VIP). Chất liệu giấy, gỗ, vải phải đổi được sắc, không dùng ảnh một màu cố định.
6. **Chữ tiếng Việt dài hơn 20–30%.** Các chỗ không có giới hạn dòng dễ tràn: `TagChip`, `storeFreeGem`, `_Reward`, tagline. Bộ chụp `tool/screens/render_screens_test.dart` dùng để kiểm cả en và vi.
7. **Ảnh icon nạp bất đồng bộ:** phải giữ hình vẽ bằng code làm dự phòng, nếu không icon sẽ chớp trống ở khung hình đầu.
8. **Hiệu năng viền run tay:** viền phải sinh từ seed cố định và cache theo kích thước, nhất là trong danh sách và lưới.

Ảnh "trước" của 26 màn hình: `docs/design/ui-before/`.
