# V2 · Giai đoạn 5 — Chuỗi cảnh mở đầu / intro ngắn / hướng dẫn L1–L3 / Cài đặt (dev-ui) cho localizer

Dùng trong `lib/ui/intro/intro_screen.dart` (cảnh mở đầu), `lib/ui/intro/short_intro_screen.dart` (intro ngắn),
`lib/ui/level/level_screen.dart` (thẻ "Sẵn sàng" L3), `lib/ui/settings/settings_screen.dart`, các câu hướng dẫn trong
màn (bong bóng chữ của lớp hướng dẫn, truyền qua `LevelLabels` — xem `lib/game/level/level_play_view.dart`) và
`test/ui/*`; **chưa có trong `.arb`**. Thêm vào `lib/l10n/app_en.arb` (nguồn, kèm `@khoá` với `description` +
`placeholders`) và `lib/l10n/app_vi.arb`, rồi chạy `flutter pub get` (gen-l10n).

Thuật ngữ: "Level" = "Màn", "combo" giữ nguyên, "tip" giữ nguyên (như các chuỗi cũ). **Không dùng ký tự ★.**
Câu hướng dẫn hiện trong bong bóng nhỏ cạnh mục tiêu: giữ ngắn (≤ ~60 ký tự tiếng Anh).

Dùng lại khoá có sẵn (không thêm): `storySkip` ("Skip" / "Bỏ qua") cho nút Bỏ qua của cảnh mở đầu, `appTitle` cho logo.

## Cảnh mở đầu + intro ngắn

| Khoá | en | vi | Placeholder | Dùng ở |
|---|---|---|---|---|
| `introLineKitchen` | One morning in a little seaside town… | Một buổi sáng ở thị trấn ven biển… | — | Phụ đề cảnh 1 (bếp buổi sáng) |
| `introLineCase` | Grandma's cake case still shines like it always did. | Tủ bánh của bà vẫn sáng như ngày nào. | — | Phụ đề cảnh 2 (tủ kính) |
| `introLineDoor` | Mai flips the sign — Sugarleaf is open! | Mai lật tấm biển — tiệm Sugarleaf mở cửa! | — | Phụ đề cảnh 3 (cửa tiệm) |
| `introSignOpen` | Open | Mở cửa | — | Chữ vẽ trên tấm bảng gỗ treo cửa sau khi lật (ngắn, 1 dòng, chữ to) |
| `introTapToEnter` | Tap to enter the bakery | Chạm để vào tiệm | — | Dòng nhỏ nhấp nháy ở intro ngắn |
| `introSemantics` | Opening scene | Cảnh mở đầu | — | Nhãn đọc màn hình của cảnh mở đầu |

## Hướng dẫn trong màn (bong bóng chữ, qua `LevelLabels`)

| Khoá | en | vi | Placeholder | Dùng ở |
|---|---|---|---|---|
| `lvlTutServe` | This customer wants this treat. Tap them to sell! | Khách muốn bánh này. Chạm khách để bán! | — | L1 bước 1: chỉ khách đầu tiên |
| `lvlTutBake` | The case is almost empty. Tap to bake a new batch! | Tủ sắp hết. Chạm để làm mẻ mới! | — | L1 bước 2: chỉ thẻ bánh ở bếp |
| `lvlTutMould` | Pick the right mould | Chọn đúng khuôn | — | L1: trạm khuôn |
| `lvlTutMix` | Stir in circles to mix | Xoay tròn để trộn | — | L1: trạm trộn (chỉ bát) |
| `lvlTutOven` | Wait for the needle to hit the gold mark, then tap | Đợi kim tới vạch vàng rồi chạm | — | L1: lò |
| `lvlTutFrost` | Trace the frosting line | Vẽ theo đường kem | — | L1: trạm kem |
| `lvlTutTopping` | {count, plural, one{Tap the right jar once} other{Tap the right jar {count} times}} | {count, plural, other{Chạm hũ đúng {count} lần}} | `count`: int (số topping cần, L1 = 3) | L1: trạm topping |
| `lvlTutBox` | Pick the right box | Chọn hộp đúng | — | L1: trạm hộp |
| `lvlTutCaseReady` | Your treats are in the case. Now serve lots of customers! | Bánh đã lên tủ. Cứ thế phục vụ thật nhiều khách nhé! | — | L1 bước cuối (tự ẩn sau 3 giây) |
| `lvlTutCombo` | Sell back to back to grow your combo — more coins! | Bán liên tục để nhân combo — tiền nhiều hơn! | — | L2: chỉ đồng hồ combo trên HUD |
| `lvlTutNewTreat` | Each customer wants something different. | Mỗi khách muốn một món khác nhau. | — | L2: lần đầu có món thứ 2 ở bong bóng |
| `lvlTutPatience` | The colored ring is their patience. Serve fast for tips! | Vòng màu là sự kiên nhẫn. Phục vụ nhanh để được tip! | — | L3: vòng kiên nhẫn dưới 50% |
| `lvlTutWalkout` | Customers who wait too long will leave. | Khách chờ lâu quá sẽ bỏ đi. | — | L3: lần đầu có khách bỏ về |

## Thẻ "Sẵn sàng"

| Khoá | en | vi | Placeholder | Dùng ở |
|---|---|---|---|---|
| `levelReadyCoinsHint` | This level counts the coins you earn | Màn này tính theo xu kiếm được | — | Dòng nhắc dưới mục tiêu ở thẻ Sẵn sàng của màn có hướng dẫn "patience" (L3) |

## Cài đặt

| Khoá | en | vi | Placeholder | Dùng ở |
|---|---|---|---|---|
| `settingsGuide` | Getting started | Làm quen | — | Nhãn dòng cài đặt chứa 2 nút dưới |
| `settingsReplayIntro` | Replay opening | Xem lại cảnh mở đầu | — | Nút mở lại cảnh mở đầu (xong quay về Cài đặt) |
| `settingsReplayTutorials` | Replay tutorials | Hướng dẫn lại | — | Nút bật lại hướng dẫn L1–L3 |
| `settingsTutorialsReset` | Tutorials will show again in Levels 1–3 | Hướng dẫn sẽ hiện lại ở Màn 1–3 | — | Toast xác nhận sau khi bấm "Hướng dẫn lại" |
