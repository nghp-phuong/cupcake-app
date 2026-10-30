# V2 · Giai đoạn 6 — Vật phẩm hỗ trợ, quảng cáo, mua trong app (chế độ thử)

Nhánh `v2`. Quảng cáo và IAP vẫn **giả lập** (`FakeAdService`, `FakeIapService`), chưa nối SDK thật; UI cửa hàng ghi rõ
"Chế độ thử". Đối tượng 13+, không ép mua: mọi thứ mua bằng tiền thật đều kiếm được (chậm hơn) trong game, trừ đồ trang
phục và bỏ quảng cáo.

## 1. Vật phẩm hỗ trợ trước màn (booster)
Chọn trên thẻ "Sẵn sàng" (0–3 loại, mỗi loại tối đa 1 cho một lượt). Dữ liệu ở `assets/config/monetization.json`.
| id | Tên en / vi | Hiệu ứng trong màn | Giá kim cương | Xem quảng cáo |
|---|---|---|---|---|
| `fullCase` | Full case / Tủ đầy bánh | Bắt đầu với tủ đầy: mỗi ô một món trong menu, đủ sức chứa, bánh 4★ | 8 | ✓ |
| `patience` | Patient customers / Khách kiên nhẫn | Kiên nhẫn mọi khách vãng lai ×1.3 cả màn | 6 | ✓ |
| `ovenBoost` | Oven ×2 / Lò ×2 | `ovenSec` ×0.5 cả màn (bếp nhanh; đơn đặc biệt không đổi) | 8 | ✓ |
- Kho vật phẩm (`boosters: {id: n}`): có từ gói khởi đầu / thẻ mùa / quà; chọn thì ưu tiên dùng kho, hết kho mới trả kim
  cương. "Xem quảng cáo" cho **một** vật phẩm miễn phí mỗi lượt chơi (dùng chung giới hạn rewarded/ngày).
- Trừ khi bấm **Bắt đầu** (thoát ở thẻ Sẵn sàng không mất). Thua không hoàn lại. Không có ở L1–L3 (đang hướng dẫn) — mở
  từ L4, thẻ Sẵn sàng giới thiệu lần đầu bằng 1 vật phẩm miễn phí (`patience` ×1 vào kho khi tới L4).
- Kết quả màn ghi vật phẩm đã dùng (cho thống kê/cân bằng). Bot cân bằng mặc định **không** dùng vật phẩm; thêm một bảng
  "với vật phẩm" để xem mức dễ hơn.

## 2. Quảng cáo thưởng (rewarded, chỉ khi người chơi bấm)
| Chỗ | Thưởng | Ghi chú |
|---|---|---|
| Sắp thua (sẵn có) | +30 s | một lần mỗi lượt, chỉ khi đang không đạt 1★ lúc hết giờ |
| Màn kết quả | ×2 xu của lượt | một lần mỗi kết quả, chỉ khi xu > 0; thắng hay thua đều được |
| Vắng nhà (sẵn có) | ×2 thu nhập vắng nhà | |
| Thẻ Sẵn sàng | 1 vật phẩm miễn phí | một lần mỗi lượt |
| Cửa hàng (sẵn có) | +1 kim cương | |
- Giới hạn chung `maxRewardedPerDay` 8 → **12** (ngày lịch). Hết lượt → nút ẩn hoặc mờ kèm "Hết lượt hôm nay".

## 3. Quảng cáo xen kẽ (interstitial)
- **Chỉ** khi rời màn kết quả (về bản đồ / màn tiếp / chơi lại), **không bao giờ** trong lúc chơi, thẻ Sẵn sàng, hướng dẫn
  hay cảnh mở đầu.
- Tối đa **1 lần mỗi 3 lượt chơi xong** (đếm lượt kết thúc màn, cả thắng lẫn thua), chỉ từ khi đã qua L5.
- Không hiện nếu: đã mua Bỏ quảng cáo; vừa xem rewarded ở chính màn kết quả đó; lượt vừa rồi mở chương mới (để người chơi
  thấy hoạt cảnh).
- Thay cơ chế theo "ngày" của V1 (`lastInterstitialDay`): trường mới `playsSinceInterstitial`.

## 4. Mua trong app (giả lập)
| IapProductId (thêm CUỐI enum) | Giá | Loại | Nội dung |
|---|---|---|---|
| `gemsS` | $0.99 | tiêu hao | 80 kim cương |
| `gemsM` | $4.99 | tiêu hao | 450 kim cương |
| `gemsL` | $9.99 | tiêu hao | 1000 kim cương |
| `starterPack` (sẵn có, đổi nội dung) | $1.99 | một lần | 8000 xu + 120 kim cương + mỗi vật phẩm ×3; hiện nổi bật từ L4 tới khi mua |
| `removeAds` (sẵn có) | $3.99 | một lần | không còn interstitial; rewarded vẫn dùng được để nhận thưởng |
| `staffOutfits` | $2.99 | một lần | Trang phục lễ hội cho Nora và Bảo (chỉ đổi hình, không tăng chỉ số); bật/tắt ở tab Nhân viên |
| `seasonPass` | $4.99 | theo mùa | mở hàng thưởng cao cấp của Thẻ mùa hiện tại |
- `pantryS/M/L` (gói xu V1) và `decorSetSeaside`: ẩn khỏi cửa hàng V2, giữ enum + quyền sở hữu cũ (không xoá dữ liệu).
- Khôi phục giao dịch (Restore) cho đồ một lần: nút trong Cài đặt (giả lập: đọc lại `ownedIap`).

## 5. Thẻ mùa (season pass)
- `monetization.json` mục `season`: id, ngày bắt đầu/kết thúc (ISO, giờ máy), 20 bậc, điểm mùa mỗi sao kiếm được (mỗi
  sao **mới** của màn = 10 điểm; mỗi lượt thắng = 5 điểm), điểm cần mỗi bậc, thưởng **miễn phí** và **cao cấp** mỗi bậc
  (xu / kim cương / vật phẩm / khung chân dung trang trí). Hết mùa: điểm và bậc về 0, thưởng chưa nhận của bậc đã đạt
  được nhận tự động lúc mùa kết thúc (thông báo).
- Màn **Thẻ mùa**: thanh bậc ngang cuộn, hai hàng thưởng, nút Nhận từng bậc / Nhận tất cả, nút mua cao cấp, đồng hồ còn
  lại. Vào từ nút mới trên thanh bản đồ (chấm đỏ khi có thưởng chờ nhận).

## 6. Hợp đồng API
`lib/core` (dev-core):
```dart
// lib/core/monetization/booster.dart, season.dart, monetization_config.dart (+ loader, loadOrEmpty)
enum BoosterId { fullCase, patience, ovenBoost }
class BoosterData { BoosterId id; String art; int gemPrice; String name(lang); String desc(lang); }
class SeasonTier { int points; Reward free; Reward premium; }  class Reward { int coins, gems; Map<BoosterId,int> boosters; String? frame; }
class SeasonData { String id; DateTime start, end; List<SeasonTier> tiers; int pointsPerNewStar, pointsPerWin; }
// ShopSetup / LevelSession: `Set<BoosterId> boosters` áp hiệu ứng §1 (LevelSession nhận qua tham số, không đọc GameState).
// GameState
int boosterCount(BoosterId id);
BoosterPayment? boosterPaymentFor(BoosterId id);   // inventory / gems / null (không đủ)
bool consumeBoosters(Set<BoosterId> ids, {BoosterId? adFree});   // gọi khi Bắt đầu; đúng một lần
bool shouldShowInterstitialAfterResult({required bool watchedRewardedHere, required bool unlockedChapter});
void registerLevelPlayEnded(); void registerInterstitialShown();
int get seasonPoints; int get seasonTier; bool get seasonPremium; List<int> get seasonClaimable /*bậc + hàng*/;
bool claimSeason(int tier, {required bool premium}); int claimAllSeason();
// applyLevelResult cộng điểm mùa + LevelProgressDelta.seasonPoints
// IapService: products mới, buy() trao thưởng qua GameState.grantIap(id); restore();
// AdPlacement thêm CUỐI: booster. Economy.maxRewardedPerDay = 12.
// Kim cương kiếm trong game: thêm thưởng nhỏ (vd lần đầu đạt 3★ một màn +2, hết chương +15) — dev-core cân để một
//   người chơi không trả tiền dùng được ~1 vật phẩm mỗi 2–3 màn.
```
- Bản lưu: `boosters`, `playsSinceInterstitial`, `season {id, points, claimedFree[], claimedPremium[], premium}`,
  `outfits {enabled}`; đọc độc lập; mùa đổi id → đặt lại phần mùa (sau khi tự nhận thưởng còn chờ).

`lib/game` (dev-game): `fullCase` — tủ hiện sẵn bánh lúc bắt đầu (hiệu ứng lấp lánh nhẹ); `ovenBoost` — lò có hiệu ứng
tia lửa/vòng sáng nhỏ; `patience` — vòng kiên nhẫn có viền vàng nhạt. Trang phục lễ hội: nhân viên dùng ảnh
`staff_<id>_fest_<expr>` khi bật. Biểu tượng vật phẩm đang dùng ở góc HUD trái (nhỏ) — vẽ trong game hoặc báo dev-ui.

`lib/ui` (dev-ui): thẻ Sẵn sàng có hàng chọn vật phẩm (ảnh, số trong kho / giá kim cương / nút quảng cáo); màn kết quả có nút
×2 xu (quảng cáo); interstitial khi rời màn kết quả theo §3; cửa hàng V2 (gói kim cương, gói khởi đầu nổi bật, bỏ quảng
cáo, trang phục, thẻ mùa) có nhãn "Chế độ thử"; màn Thẻ mùa + nút trên thanh bản đồ; tab Nhân viên bật/tắt trang phục;
Cài đặt "Khôi phục giao dịch". Chuỗi ở `docs/v2/phase6-strings-ui.md`.

## 7. Ảnh (trưởng phòng, Gemini)
- Vật phẩm: `level/booster_fullcase.webp` (khay bánh đầy), `level/booster_patience.webp` (đồng hồ cát có trái tim),
  `level/booster_oven.webp` (lò nhỏ có tia lửa vàng).
- Cửa hàng: `items/gem_pouch.webp`, `items/gem_box.webp`, `items/gem_chest.webp`, `items/season_ticket.webp`.
- Trang phục: `characters/staff_nora_fest_{neutral,smile}.webp`, `characters/staff_bao_fest_{neutral,smile}.webp`.

## 8. Chia việc
| Ai | Khu vực | Việc |
|---|---|---|
| dev-core | lib/core, main.dart, assets/config, test/core | §1–6 phần core, cân kim cương, bot |
| dev-game | lib/game, test/game | hiệu ứng vật phẩm + trang phục trong màn |
| dev-ui | lib/ui, test/ui, tool/screens | §1–5 phần UI |
| localizer | .arb | `docs/v2/phase6-strings-ui.md` |
| trưởng phòng | assets/art, assets/characters | 11 ảnh §7 |
