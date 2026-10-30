# V2 · Giai đoạn 2 — Chuỗi giao diện bản đồ chương (dev-ui) cho localizer

Dùng trong `lib/ui/map/level_map_screen.dart` (bản đồ = màn chính), `lib/ui/level/level_result_screen.dart` (nút về bản
đồ) và `test/ui/level_map_test.dart`; **chưa có trong `.arb`**. Thêm vào `lib/l10n/app_en.arb` (nguồn, kèm `@khoá` với
`placeholders`) và `lib/l10n/app_vi.arb`, rồi chạy `flutter pub get` (gen-l10n).

Thuật ngữ giữ như GĐ1: "Level" = "Màn", "Chapter" = "Chương". **Không dùng ký tự ★ trong các chuỗi mới**: font đóng
gói (Nunito/Fredoka) không có glyph này (ảnh chụp hiện ô vuông) — UI tự vẽ hình ngôi sao cạnh chữ. Các nút thanh trên
dùng lại khoá có sẵn làm tooltip (`menuQuests`, `menuLoginGift`, `menuRecipeBook`, `menuUpgrades`, `menuDecor`,
`menuStore`, `menuSettings`), nhãn ngắn dưới nút: `mapQuestsShort`, `mapGiftShort`, còn lại dùng chính khoá cũ; băng tên
chương dùng `levelChapterLabel` + tên chương trong levels.json.

| Khoá | en | vi | Placeholder | Dùng ở |
|---|---|---|---|---|
| `mapStarsTotal` | `{count, plural, =1{1 star} other{{count} stars}}` | `{count} sao` | `count`: int | Nhãn đọc màn hình của ô tổng sao trên thanh trên |
| `mapQuestsShort` | Quests | Nhiệm vụ | — | Nhãn ngắn dưới nút Nhiệm vụ ngày (tooltip vẫn là `menuQuests`) |
| `mapGiftShort` | Gift | Quà | — | Nhãn ngắn dưới nút Quà hằng ngày (tooltip vẫn là `menuLoginGift`) |
| `mapPrevChapter` | Previous chapter | Chương trước | — | Tooltip nút ‹ |
| `mapNextChapter` | Next chapter | Chương sau | — | Tooltip nút › |
| `mapLevelLabel` | Level {level}: {stars} of 3 stars | Màn {level}: {stars}/3 sao | `level`: int, `stars`: int | Nhãn đọc màn hình của nút level đã mở; nút gợi ý chơi lại |
| `mapLevelLockedLabel` | Level {level}, locked | Màn {level}, chưa mở | `level`: int | Nhãn đọc màn hình của nút level khoá |
| `mapLevelLocked` | Finish the previous level to unlock this one! | Qua màn trước để mở màn này nhé! | — | Toast khi chạm nút level khoá |
| `mapChapterLockedTitle` | Chapter {chapter} is locked | Chương {chapter} chưa mở | `chapter`: int | Tiêu đề thẻ ổ khoá trên trang chương khoá |
| `mapChapterNeedStars` | Need {need} stars — you have {have} | Cần {need} sao — bạn đang có {have} | `need`: int, `have`: int | Dòng điều kiện sao trên trang chương khoá (đứng sau hình ngôi sao) |
| `mapChapterNeedFinish` | Finish chapter {chapter} first | Hãy hoàn thành chương {chapter} trước | `chapter`: int | Dòng điều kiện "qua level cuối chương trước" |
| `mapChapterReplayHint` | Replay levels with fewer stars to collect more | Chơi lại các màn ít sao để gom thêm sao | — | Gợi ý khi chưa đủ sao (kèm tối đa 3 nút level ít sao) |
| `mapChapterUnlockedTitle` | Chapter {chapter} unlocked! | Chương {chapter} đã mở! | `chapter`: int | Tiêu đề hộp thoại mở chương mới (sau hoạt cảnh) |
| `mapChapterUnlockedBody` | New recipes and new faces are waiting in this part of town. | Món mới và những vị khách mới đang chờ ở góc phố này. | — | Thân hộp thoại mở chương (dưới tên chương) |
| `mapChapterUnlockedGo` | Let's go! | Đi thôi! | — | Nút đóng hộp thoại mở chương |
| `mapBackToMap` | Map | Bản đồ | — | Nút ở màn kết quả level (thay `levelList`) |
| `mapLoadError` | The level map couldn't load. Please restart the game. | Không tải được bản đồ màn chơi. Hãy mở lại trò chơi nhé. | — | Lời nhắn khi levels.json nạp lỗi (cấu hình rỗng) |
| `mapUnlockAfterLevel` | Clear level {level} to unlock | Qua màn {level} để mở | `level`: int | Nút khoá ở màn Nâng cấp / Trang trí (thay `commonUnlockAtLevel` — "cấp tiệm" không còn hiện, quy đổi ra màn cần qua) |
| `mapRecipeFromLevel` | Missing page. Reach level {level} to find it | Trang còn thiếu. Tới màn {level} để tìm lại | `level`: int | Sổ công thức: món chưa mở (thay `recipesMissingPage`), `level` = màn đầu tiên có món |
| `mapRecipeLater` | Missing page. Coming in a later chapter | Trang còn thiếu. Sẽ tìm thấy ở chương sau | — | Sổ công thức: món chưa có trong level nào |

## Khoá cũ không còn dùng ở màn chơi
`levelList`, `commonUnlockAtLevel`, `recipesMissingPage` (thay bằng `mapBackToMap`, `mapUnlockAfterLevel`, `mapRecipe*`);
`menuPlay`, `menuDayLabel`, `menuTagline`, `menuShopLevel`, `menuXpProgress`, `menuXpMax`, `levelMenuButton` (menu cũ).
**Chưa xoá**: Gallery debug (`lib/ui/sugarleaf/gallery`) và test bộ SL còn dùng một số khoá menu làm chữ mẫu; khoá
`day*` / `summary*` còn được `order_ticket.dart`, `result_card.dart`, `mochi_visit.dart`, `level_screen.dart` dùng một
phần (vd. `dayStartBaking`). Dọn khoá thừa để sau khi cả nhóm xong GĐ2.
