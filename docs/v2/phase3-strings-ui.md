# V2 · Giai đoạn 3 — Chuỗi giao diện Nâng cấp 2 tab / thông báo mở khoá (dev-ui) cho localizer

Dùng trong `lib/ui/upgrades/upgrades_screen.dart` (màn Nâng cấp 2 tab), `lib/ui/upgrades/unlock_notice.dart` (thẻ "Mở khoá
mới!" trên bản đồ), `lib/ui/level/level_screen.dart` (dòng tóm tắt tiệm trên thẻ "Sẵn sàng") và `test/ui/*`; **chưa có
trong `.arb`**. Thêm vào `lib/l10n/app_en.arb` (nguồn, kèm `@khoá` với `description` + `placeholders`) và
`lib/l10n/app_vi.arb`, rồi chạy `flutter pub get` (gen-l10n).

Thuật ngữ: "Level" = "Màn", "Chapter" = "Chương", "Tier" (cấp thiết bị) = "Cấp", gems = "kim cương". **Không dùng ký tự ★**.
Tên + mô tả từng mở khoá / thiết bị nằm trong `assets/config/unlocks.json` (en + vi), không phải `.arb`.

| Khoá | en | vi | Placeholder | Dùng ở |
|---|---|---|---|---|
| `upgTabExpansion` | Expand the bakery | Mở rộng tiệm | — | Tab 1 của màn Nâng cấp |
| `upgTabEquipment` | Equipment | Thiết bị | — | Tab 2 của màn Nâng cấp |
| `upgOwned` | Owned | Đã có | — | Nhãn trạng thái thẻ mở rộng đã mua |
| `upgComingSoon` | Coming soon | Sắp có | — | Nhãn thẻ nhân viên / bộ trang trí hiếm (chưa có ở bản này) |
| `upgExpansionDone` | Added to your bakery! | Đã thêm vào tiệm! | — | Toast khi mua mở rộng thành công |
| `upgTierOf` | Tier {current}/{max} | Cấp {current}/{max} | `current`: int, `max`: int | Dòng cấp của thiết bị (thay `upgradeLevelOf` — chữ "Level" dễ nhầm với màn) |
| `upgStatOvenSec` | Bakes in {seconds}s | Nướng {seconds} giây | `seconds`: String (số đã định dạng, vd "6.3" / "6,3") | Thông số lò nhanh (trước → sau) |
| `upgStatBatch` | `{count, plural, =1{1 cake per tray} other{{count} cakes per tray}}` | `{count} bánh mỗi khay` | `count`: int | Thông số khay lớn |
| `upgStatCaseSlot` | `{count, plural, =1{1 cake per case slot} other{{count} cakes per case slot}}` | `{count} bánh mỗi ô tủ` | `count`: int | Thông số tủ rộng |
| `upgStatMixZone` | Green zone {percent}% | Vùng xanh {percent}% | `percent`: int | Thông số phới lồng (vùng trộn chuẩn) |
| `upgStatStroke` | Frosting stroke {size} | Nét kem cỡ {size} | `size`: int | Thông số túi bắt kem |
| `upgStatSnap` | Snap range {size} | Tầm hút {size} | `size`: int | Thông số kẹp gắp |
| `upgStatSnapNone` | No snapping | Chưa hút topping | — | Kẹp gắp cấp 1 (tầm hút = 0) |
| `upgStatNext` | Next: {stat} | Cấp sau: {stat} | `stat`: String (một chuỗi `upgStat*`) | Nhãn đọc màn hình của mũi tên "→" giữa thông số hiện tại và cấp sau |
| `unlockNoticeTitle` | New unlock! | Mở khoá mới! | — | Tiêu đề thẻ thông báo sau hoạt cảnh bản đồ |
| `unlockNoticeBody` | `{count, plural, =1{Something new is ready for your bakery.} other{{count} new things are ready for your bakery.}}` | `{count} mục mới đã sẵn sàng cho tiệm của bạn.` | `count`: int | Dòng dẫn dưới tiêu đề thẻ thông báo |
| `unlockNoticeView` | Take a look | Xem | — | Nút mở màn Nâng cấp đúng tab/thẻ |
| `unlockNoticeLater` | Later | Để sau | — | Nút đóng thẻ (chấm đỏ trên nút Nâng cấp vẫn còn) |
| `unlockNoticeTier` | Tier {tier} unlocked | Mở cấp {tier} | `tier`: int | Dòng phụ cho mục thiết bị lên cấp mới trong thẻ thông báo |
| `unlockNoticeMore` | `{count, plural, =1{+1 more} other{+{count} more}}` | `và {count} mục khác` | `count`: int | Cuối danh sách khi có hơn 3 mục |
| `levelShopCase` | `{count, plural, =1{1 case slot} other{{count} case slots}}` | `Tủ {count} ô` | `count`: int | Thẻ "Sẵn sàng": tóm tắt tiệm (nối bằng " · ") |
| `levelShopOvens` | `{count, plural, =1{1 oven} other{{count} ovens}}` | `{count} lò` | `count`: int | Thẻ "Sẵn sàng" |
| `levelShopTray` | `{count, plural, =1{Tray of 1} other{Tray of {count}}}` | `Khay {count} bánh` | `count`: int | Thẻ "Sẵn sàng" |

## Khoá cũ dùng lại (không đổi)
`menuUpgrades`, `upgradesTitle`, `upgradeBuy` (nút nâng thiết bị), `upgradeMaxed`, `upgradeDone`, `upgradeOvenPerfectZone`
(thông số lò vùng vàng), `commonBuy`, `commonNotEnoughCoins`, `commonNotEnoughGems`, `mapUnlockAfterLevel` ("Qua màn X để
mở"), `levelChapterLabel`, `mapChapterLockedTitle` (chương chưa mở), `levelNewBadge` (huy hiệu "Mới" trên thẻ vừa khả dụng).

## Khoá cũ ở màn Nâng cấp
- Không còn dùng: `upgradeLevelOf` (thay bằng `upgTierOf`).
- Chỉ còn dùng khi unlocks.json nạp lỗi (bảng dự phòng lò/dụng cụ V1): `upgradeOven`, `upgradeOvenDesc`, `upgradeWhisk*`,
  `upgradePipingBag*`, `upgradeTongs*` (qua `toolName`/`toolDesc`). Bình thường tên/mô tả lấy từ `unlocks.json`.
