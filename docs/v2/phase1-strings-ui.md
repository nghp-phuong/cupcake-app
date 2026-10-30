# V2 · Giai đoạn 1 — Chuỗi giao diện mới của `lib/ui/level/` (cho localizer)

dev-ui đã dùng các khoá dưới đây trong `lib/ui/level/*.dart`, `lib/ui/menu/main_menu_screen.dart` và
`test/ui/level_screens_test.dart`; **chưa có trong `.arb`** → app chưa biên dịch được tới khi thêm. Thêm vào
`lib/l10n/app_en.arb` (nguồn) và `lib/l10n/app_vi.arb`. Tên level/chương KHÔNG qua ARB (lấy từ `levels.json` qua
`titleFor`).

Khoá có placeholder cần mục `@khoá` với `placeholders` đúng kiểu ghi ở cột "Placeholder".

| Khoá | en | vi | Placeholder | Dùng ở |
|---|---|---|---|---|
| `levelMenuButton` | Levels | Màn chơi | — | Nút lớn ở menu chính |
| `levelChapterLabel` | Chapter {chapter} | Chương {chapter} | `chapter`: int | Dưới dải tên chương (danh sách level) |
| `levelNumber` | Level {level} | Màn {level} | `level`: int | Dải "Màn N" ở thẻ Sẵn sàng, tạm dừng, kết quả, nhãn đọc màn hình ô level |
| `levelNewBadge` | New | Mới | — | Huy hiệu món mới (ô level, thẻ Sẵn sàng) |
| `levelSpecialBadge` | Special | Đặc biệt | — | Huy hiệu ô level ★ |
| `levelGoalLabel` | Goal | Mục tiêu | — | Thẻ Sẵn sàng: "Mục tiêu: …" |
| `levelGoalCoins` | `{count, plural, =1{Earn 1 coin} other{Earn {count} coins}}` | `{count, plural, other{Kiếm {count} xu}}` | `count`: int | Mục tiêu loại xu (mốc 1★) |
| `levelGoalCustomers` | `{count, plural, =1{Serve 1 customer} other{Serve {count} customers}}` | `{count, plural, other{Phục vụ {count} khách}}` | `count`: int | Mục tiêu loại khách |
| `levelGoalSpecials` | `{count, plural, =1{Finish 1 special order (3★+)} other{Finish {count} special orders (3★+)}}` | `{count, plural, other{Hoàn thành {count} đơn đặc biệt (từ 3★)}}` | `count`: int | Mục tiêu loại đơn đặc biệt (chỉ đơn ≥3★ được tính) |
| `levelTimeLabel` | Time | Thời gian | — | Nhãn đọc màn hình của đồng hồ ở thẻ Sẵn sàng |
| `levelMenuLabel` | On the menu | Thực đơn hôm nay | — | Thẻ Sẵn sàng, trên hàng ảnh món |
| `levelStart` | Start | Bắt đầu | — | Nút thẻ Sẵn sàng |
| `levelPause` | Pause | Tạm dừng | — | Tooltip nút ⏸ ở HUD |
| `levelRush` | Rush hour! | Giờ cao điểm! | — | Nhãn cạnh đồng hồ HUD |
| `levelGoalProgress` | {value}/{target} | {value}/{target} | `value`: int, `target`: int | Chữ trên thanh mục tiêu HUD, dòng mục tiêu ở kết quả |
| `levelCombo` | Combo ×{mult} | Combo ×{mult} | `mult`: String (đã định dạng, vd. "1.3" / "1,3") | Nhãn combo HUD |
| `levelPauseTitle` | Paused | Tạm dừng | — | Tiêu đề hộp thoại tạm dừng |
| `levelPauseBody` | Take a breather — your customers will wait. | Nghỉ tay chút nhé — khách sẽ đợi bạn. | — | Nội dung hộp thoại tạm dừng |
| `levelQuit` | Quit | Thoát | — | Nút hộp thoại tạm dừng (về danh sách, không tính kết quả) |
| `levelReplay` | Play again | Chơi lại | — | Hộp thoại tạm dừng + màn kết quả |
| `levelTimeUp` | Time's up! | Hết giờ! | — | Dải hiện khi hết giờ |
| `levelExtraTimeTitle` | +{seconds} seconds? | Thêm {seconds} giây? | `seconds`: int | Tiêu đề hộp thoại +30 giây |
| `levelExtraTimeBody` | So close! Watch a short ad to keep the shop open a little longer. | Sắp đạt rồi! Xem một quảng cáo ngắn để mở tiệm thêm chút nữa. | — | Nội dung hộp thoại +30 giây |
| `levelExtraTimeWatch` | Watch ad (+{seconds}s) | Xem quảng cáo (+{seconds} giây) | `seconds`: int | Nút đồng ý |
| `levelExtraTimeNo` | No thanks | Thôi | — | Nút từ chối |
| `levelSpecialLater` | Later | Để sau | — | Vé đơn đặc biệt: bỏ qua, khách vẫn đợi |
| `levelSpecialQuitTitle` | Leave this order? | Bỏ dở đơn này? | — | Hộp xác nhận + tooltip nút thoát khi đang làm đơn đặc biệt |
| `levelSpecialQuitBody` | The customer will keep waiting — you can come back to it. | Khách vẫn đợi — bạn có thể quay lại làm sau. | — | Nội dung hộp xác nhận |
| `levelResultWinTitle` | Level complete! | Hoàn thành màn! | — | Tiêu đề kết quả khi thắng |
| `levelResultLoseTitle` | So close — let's try again! | Suýt nữa thôi — thử lại nhé! | — | Tiêu đề an ủi khi thua |
| `levelResultGoal` | Goal: {progress} | Mục tiêu: {progress} | `progress`: String (chuỗi `levelGoalProgress`) | Dòng dưới hàng sao ở kết quả |
| `levelResultCoins` | Coins earned | Xu kiếm được | — | Kết quả |
| `levelResultServed` | Happy customers | Khách hài lòng | — | Kết quả |
| `levelResultLost` | Customers who left | Khách bỏ đi | — | Kết quả |
| `levelResultSpecials` | Special orders | Đơn đặc biệt | — | Kết quả (mọi đơn đặc biệt đã làm) |
| `levelResultBestCombo` | Best combo | Combo cao nhất | — | Kết quả |
| `levelResultFiveStar` | 5★ treats | Bánh 5★ | — | Kết quả |
| `levelNext` | Next level | Màn tiếp | — | Kết quả khi thắng (nếu còn level sau) |
| `levelList` | Level list | Danh sách | — | Kết quả |

Khoá cũ dùng lại (không cần thêm): `commonBack`, `commonContinue`, `commonCoins`, `adsLimitReached`, `dayStartBaking`,
`dayNextCustomer` (nút của `ResultCard`), `orderLineText`/`recipeName` (qua `l10n_lookup.dart`).

Lưu ý: `levelUpTitle` đã có sẵn (lên cấp tiệm) — không trùng các khoá trên.
