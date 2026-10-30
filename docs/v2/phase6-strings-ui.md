# V2 · Giai đoạn 6 — Chuỗi vật phẩm hỗ trợ / ×2 xu / cửa hàng V2 / Thẻ mùa / trang phục / khôi phục (dev-ui) cho localizer

Dùng trong `lib/ui/level/level_screen.dart` (thẻ "Sẵn sàng"), `lib/ui/level/level_result_screen.dart`,
`lib/ui/store/store_screen.dart`, `lib/ui/season/season_pass_screen.dart` (mới), `lib/ui/map/level_map_screen.dart`
(nút thanh trên), `lib/ui/upgrades/staff_tab.dart`, `lib/ui/settings/settings_screen.dart` và `test/ui/*`; **chưa có
trong `.arb`**. Thêm vào `lib/l10n/app_en.arb` (nguồn, kèm `@khoá` với `description` + `placeholders`) và
`lib/l10n/app_vi.arb`, rồi chạy `flutter pub get` (gen-l10n).

Thuật ngữ: kim cương = gems, "Level" = "Màn", vật phẩm hỗ trợ = booster(s), Thẻ mùa = Season pass. **Không dùng ký tự ★.**
Tên + mô tả từng vật phẩm lấy từ `assets/config/monetization.json` (`BoosterData.name/desc(lang)`), không cần khoá.

Dùng lại khoá có sẵn (không thêm): `commonNotEnoughGems`, `commonWatchAd`, `commonClaim`, `commonClaimed`,
`commonLocked`, `adsLimitReached`, `adRewardGranted`, `storeOwned`, `storeSimulatedNotice`, `commonGems`.

## Thẻ "Sẵn sàng" — vật phẩm hỗ trợ

| Khoá | en | vi | Placeholder | Dùng ở |
|---|---|---|---|---|
| `lvlBoosterTitle` | Boosters | Vật phẩm hỗ trợ | — | Nhãn nhỏ trên hàng 3 ô vật phẩm |
| `lvlBoosterAdFree` | Watch ad: 1 free | Xem quảng cáo: 1 miễn phí | — | Nút nhỏ cạnh hàng vật phẩm (một lần mỗi lượt) |
| `lvlBoosterFree` | Free | Miễn phí | — | Nhãn trên ô vật phẩm được trả bằng lượt quảng cáo (thay giá) |
| `lvlBoosterPickFree` | Pick a booster — one is free! | Chọn một vật phẩm — miễn phí một cái! | — | Dòng gợi ý sau khi xem quảng cáo mà chưa chọn ô nào |
| `lvlBoosterIntro` | New! Boosters make a level easier. Here's one to try for free. | Mới! Vật phẩm hỗ trợ giúp màn chơi dễ hơn. Tặng bạn một cái để thử. | — | Chú thích giới thiệu lần đầu tới L4 (bong bóng cạnh hàng vật phẩm) |
| `lvlBoosterSelected` | {name}, selected | {name}, đã chọn | `name`: String (tên vật phẩm) | Nhãn đọc màn hình của ô đang chọn |

## Màn kết quả

| Khoá | en | vi | Placeholder | Dùng ở |
|---|---|---|---|---|
| `levelResultDoubleCoins` | ×2 coins (watch ad) | ×2 xu (xem quảng cáo) | — | Nút một lần ở màn kết quả (chỉ khi xu > 0) |
| `levelResultDoubled` | Coins doubled! +{coins} | Đã nhân đôi xu! +{coins} | `coins`: int (xu cộng thêm, đã định dạng số) | Toast sau khi xem xong |

## Cửa hàng V2

Tên + mô tả gói V2 lấy từ `monetization.json` (`IapProduct.name/desc(lang)`); các khoá mô tả dưới đây chỉ là dự phòng khi file thiếu chữ. Không cần khoá tên gói mới.

| Khoá | en | vi | Placeholder | Dùng ở |
|---|---|---|---|---|
| `storeTestMode` | Test mode | Chế độ thử | — | Con dấu nổi bật ở góc trên cửa hàng (cạnh dải thông báo) |
| `storeGemsDesc` | {gems} gems | {gems} kim cương | `gems`: int | Mô tả gói kim cương S/M/L |
| `storeStarterPackDescV2` | {coins} coins + {gems} gems + every booster ×{count} | {coins} xu + {gems} kim cương + mỗi vật phẩm ×{count} | `coins`, `gems`, `count`: int | Mô tả gói khởi đầu V2 |
| `storeStarterBadge` | Best deal | Ưu đãi nhất | — | Nhãn nổi bật trên thẻ gói khởi đầu |
| `storeRemoveAdsDescV2` | No more ads between levels. Reward ads stay optional. | Không còn quảng cáo giữa các màn. Quảng cáo nhận thưởng vẫn tuỳ bạn. | — | Mô tả gói Bỏ quảng cáo (V2) |
| `storeStaffOutfitsDesc` | Festival looks for Nora and Bao. Looks only — switch it in Staff. | Trang phục lễ hội cho Nora và Bảo. Chỉ đổi hình — bật/tắt ở tab Nhân viên. | — | Mô tả gói trang phục |
| `storeSeasonPassDesc` | Unlock the premium rewards of this season. | Mở hàng thưởng cao cấp của mùa này. | — | Mô tả gói thẻ mùa |

## Thẻ mùa

| Khoá | en | vi | Placeholder | Dùng ở |
|---|---|---|---|---|
| `seasonTitle` | Season pass | Thẻ mùa | — | Tiêu đề màn Thẻ mùa; tooltip nút trên bản đồ |
| `mapSeasonShort` | Season | Thẻ mùa | — | Nhãn ngắn dưới nút tròn trên thanh bản đồ (≤ ~8 ký tự) |
| `seasonTimeLeft` | Ends in {time} | Còn {time} | `time`: String (từ `seasonDaysHours` / `seasonHoursMinutes`) | Đồng hồ còn lại |
| `seasonDaysHours` | {days}d {hours}h | {days} ngày {hours} giờ | `days`, `hours`: int | Thời gian còn ≥ 1 ngày |
| `seasonHoursMinutes` | {hours}h {minutes}m | {hours} giờ {minutes} phút | `hours`, `minutes`: int | Thời gian còn < 1 ngày |
| `seasonPoints` | {points}/{need} points | {points}/{need} điểm | `points`, `need`: int | Thanh tiến độ tới bậc kế |
| `seasonPointsMax` | {points} points · all tiers reached | {points} điểm · đã đạt mọi bậc | `points`: int | Thanh tiến độ khi đã đạt bậc cuối |
| `seasonHowTo` | +{star} points for each new star, +{win} for each win | +{star} điểm mỗi sao mới, +{win} điểm mỗi lần thắng | `star`, `win`: int | Dòng nhỏ dưới tiêu đề |
| `seasonTierLabel` | Tier {tier} | Bậc {tier} | `tier`: int | Nhãn từng cột bậc (+ đọc màn hình) |
| `seasonFreeRow` | Free | Miễn phí | — | Nhãn đầu hàng thưởng miễn phí |
| `seasonPremiumRow` | Premium | Cao cấp | — | Nhãn đầu hàng thưởng cao cấp |
| `seasonClaimAll` | Claim all | Nhận tất cả | — | Nút nhận mọi thưởng đang chờ |
| `seasonClaimedToast` | {count, plural, =1{Reward claimed!} other{{count} rewards claimed!}} | {count, plural, other{Đã nhận {count} phần thưởng!}} | `count`: int | Toast sau khi nhận |
| `seasonBuyPremium` | Unlock premium · {price} | Mở cao cấp · {price} | `price`: String (giá cố định, vd. `$4.99`) | Nút mua cao cấp |
| `seasonPremiumActive` | Premium unlocked | Đã mở cao cấp | — | Nhãn thay nút mua khi đã có |
| `seasonPremiumHint` | Unlock premium to claim | Mở cao cấp để nhận | — | Nhãn đọc màn hình / tooltip ô cao cấp khi chưa mua |
| `seasonEnded` | The season has ended. Your unclaimed rewards were added automatically. | Mùa đã kết thúc. Thưởng chưa nhận đã được tự động cộng cho bạn. | — | Hộp thoại/toast khi mùa kết thúc |
| `seasonNone` | No season is running right now. | Hiện chưa có mùa nào. | — | Màn Thẻ mùa khi không có dữ liệu mùa |
| `seasonRewardFrame` | Portrait frame | Khung chân dung | — | Tên thưởng khung chân dung trang trí (tooltip ô thưởng) |
| `seasonRewardBooster` | {name} ×{count} | {name} ×{count} | `name`: String (tên vật phẩm), `count`: int | Tooltip ô thưởng vật phẩm |

## Tab Nhân viên

| Khoá | en | vi | Placeholder | Dùng ở |
|---|---|---|---|---|
| `staffOutfitFestival` | Festival outfit | Trang phục lễ hội | — | Nhãn công tắc trên thẻ Nora / Bảo (khi đã mua gói trang phục) |

## Cài đặt

| Khoá | en | vi | Placeholder | Dùng ở |
|---|---|---|---|---|
| `settingsPurchases` | Purchases | Giao dịch | — | Nhãn dòng cài đặt mới |
| `settingsRestore` | Restore purchases | Khôi phục giao dịch | — | Nút gọi `iap.restore()` |
| `settingsRestoreDone` | {count, plural, =1{Restored 1 purchase} other{Restored {count} purchases}} | {count, plural, other{Đã khôi phục {count} giao dịch}} | `count`: int (≥ 1) | Toast thành công |
| `settingsRestoreNone` | Nothing to restore | Không có giao dịch nào để khôi phục | — | Toast khi không có gì |
| `settingsRestoreFailed` | Couldn't restore right now. Please try again later. | Chưa khôi phục được. Bạn thử lại sau nhé. | — | Toast khi lỗi |

## Bổ sung sau review

| Khoá | en | vi | Placeholder | Dùng ở |
|---|---|---|---|---|
| `storePurchaseFailed` | The purchase didn't go through. | Giao dịch chưa thành công. | — | Toast khi `iap.buy` trả false (cửa hàng, nút mua cao cấp ở Thẻ mùa) |
| `storeSeasonNone` | No season is running right now. Check back soon! | Hiện chưa có mùa mới. Quay lại sau nhé! | — | Thay mô tả trên thẻ "Thẻ mùa" khi không mua được (không có mùa / đã mua) |
| `levelResultSeasonPoints` | +{points} season points | +{points} điểm mùa | `points`: int | Màn kết quả: hàng thưởng thêm (điểm Thẻ mùa của lượt) |
| `levelResultBoosterGift` | Gift: {name} ×1 | Quà: {name} ×1 | `name`: String (tên vật phẩm) | Màn kết quả: quà vật phẩm giới thiệu (lần đầu tới L4) |
| `levelPauseBoosterLost` | Boosters used in this run won't be refunded. | Vật phẩm đã dùng ở lượt này sẽ không được hoàn lại. | — | Hộp tạm dừng khi đã dùng vật phẩm và đã bán ít nhất một món |
| `levelPauseBoosterRefund` | Quit or replay now and your boosters go back to your bag. | Thoát hoặc chơi lại lúc này, vật phẩm sẽ được trả lại vào kho. | — | Hộp tạm dừng khi đã dùng vật phẩm nhưng chưa bán món nào |
| `levelBoostersRefunded` | Boosters returned to your bag. | Đã trả vật phẩm vào kho. | — | Toast nhỏ khi Thoát / Chơi lại trước lần bán đầu tiên (đã hoàn vật phẩm) |
