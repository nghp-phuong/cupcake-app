# V2 · Giai đoạn 8 — Chương 3–5 vào game, 8 món mới, truyện mới

Nhánh `v2`. Chủ dự án chọn (30/10/2026): **thêm đủ 8 món còn lại** của GDD (lên 18 món) và **truyện mới theo GDD**
cho chương 3–5. Không đổi định dạng lưu game theo cách làm mất dữ liệu; enum chỉ thêm giá trị ở CUỐI.

Chia 3 bước, mỗi bước kết thúc bằng `flutter analyze` + `flutter test`:
- **8A — 8 món mới** (dữ liệu, 6 trạm, ảnh).
- **8B — chương 3–5 chơi được** (màn 21–50, bản đồ, truyện, chỗ tiêu xu).
- **8C — cân bằng lại + kiểm tra** (`tool/simulate.dart`, chụp màn hình, `/quality-gate`).

---

## 1. 8 món mới (8A)

Thêm vào `RecipeId` (CUỐI enum, đúng thứ tự dưới). Giá/chi phí là đề xuất ban đầu, dev-core cân lại ở 8C theo mô phỏng.

| id | Tên en / vi | Mở ở màn | Khuôn | Bột | Kem / lớp phủ | Topping | Hộp | Giá / chi phí |
|---|---|---|---|---|---|---|---|---|
| `croissant` | Croissant / Bánh sừng bò | 21 | `pastryTray` | `laminated` | `butterGlaze` | `almondFlakes`, `powderedSugar` | small | 64 / 16 |
| `painAuChocolat` | Pain au chocolat / Bánh mì sô-cô-la | 24 | `pastryTray` | `laminated` | `chocolateGanache` | `chocolateChips`, `powderedSugar` | small | 68 / 17 |
| `madeleine` | Madeleine / Bánh madeleine | 27 | `shellMould` | `butter` | `butterGlaze` | `powderedSugar`, `sugarPearl` | small | 58 / 15 |
| `eclair` | Éclair / Bánh éclair | 31 | `eclairTray` | `choux` | `chocolateGanache`, `custard` | `almondFlakes`, `sprinkles` | small | 74 / 19 |
| `fruitTart` | Fruit tart / Tart trái cây | 34 | `tartShell` | `butter` | `custard` | `strawberry`, `blueberry`, `kiwi`, `mintLeaf` | cake | 82 / 21 |
| `applePie` | Apple pie / Bánh táo nướng | 38 | `piePan` | `butter` | `appleFilling` | `powderedSugar`, `mintLeaf` | cake | 86 / 22 |
| `mooncake` | Mooncake / Bánh Trung thu | 43 | `mooncakeMould` | `mooncake` | `lotusPaste` | `sesame`, `sugarPearl` | gift | 92 / 23 |
| `bucheDeNoel` | Bûche de Noël / Bánh khúc cây Giáng sinh | 47 | `logPan` | `chocolate` | `chocolateGanache` | `meringueMushroom`, `powderedSugar`, `cherry`, `mintLeaf` | cake | 98 / 25 |

**Kiểu mới (thêm CUỐI enum):**
- `MouldType`: `pastryTray`, `shellMould`, `eclairTray`, `piePan`, `mooncakeMould`, `logPan`.
- `BatterType`: `laminated` (bột cán bơ nhiều lớp), `choux`, `mooncake` (vỏ bánh nướng).
- `FrostingId`: `butterGlaze` (quét bơ trứng bóng), `appleFilling` (nhân táo), `lotusPaste` (nhân sen).
- `ToppingId`: `almondFlakes`, `powderedSugar`, `kiwi`, `sesame`, `meringueMushroom`.

**Món theo mùa:** bánh Trung thu và Bûche de Noël mở bình thường theo màn (chương 5 là "Lễ hội ven biển"), **không
khoá theo lịch thật** để không chặn tiến trình. Sự kiện theo mùa để sau.

**Ảnh đế nướng:** croissant và pain au chocolat cùng khuôn + bột nhưng hình khác nhau → ảnh đế nướng tra theo thứ tự
`baked/<recipeId>` → `baked/<mould>_<batter>` → `baked/<mould>` (thêm bước đầu vào `ArtSprites`/`CakeArt`).

**Hình vẽ code dự phòng** (`CakeArt`, `game_paint.dart`, `mix_station.dart`): mỗi khuôn/bột/kem/topping mới có nhánh
vẽ dự phòng đơn giản (switch phải đầy đủ), như các món cũ. Hệ số kích thước trong `game_paint.dart` cho khuôn mới.

**Nhịp các trạm** (dữ liệu `Recipe`): `mixTurns` 4–5, `bakeTarget` 0.58–0.72; croissant/pain au chocolat/éclair nướng
nhạy hơn (vùng vàng hẹp hơn chút: target lệch khỏi 0.65), bûche phủ kem nhiều nhất. Trạm 1 (chọn khuôn) giờ có 13 khuôn:
vẫn chỉ hiện khuôn đúng + vài khuôn nhiễu như hiện tại.

---

## 2. Chương 3–5 vào game (8B)

### 2.1 Màn 21–50
- Chép `chapters` 3–5 và `levels` 21–50 từ `assets/config/levels_draft.json` sang `levels.json`; xoá
  `levels_draft.json` (và chỗ gộp trong `ProgressionSim` — sim đọc thẳng `levels.json`).
- Thay bằng dữ liệu thật: `title` en/vi từng màn, `mapPos` khớp ảnh bản đồ mới (chừa đường đi), `menu` đưa món mới vào
  từ màn mở của nó (món mới xuất hiện ngay màn mở + đơn đặc biệt giới thiệu), `specials.scene` trỏ cảnh truyện §2.3.
- Đơn đặc biệt màn 50: bà Rosa đặt **bánh cưới** = `birthdayCake` nhiều tầng có hộp `gift` (dữ liệu, không món mới).

### 2.2 Bản đồ
- `assets/art/map/chapter_3.webp`, `chapter_4.webp`, `chapter_5.webp` (trưởng phòng tạo bằng Gemini, §4).
- Màn bản đồ đã đọc chương từ `levels.json`; dev-ui kiểm cuộn/chuyển chương, biển tên chương, khoá chương theo sao
  (28 / 40 / 53) và hoạt cảnh mở chương cho 3–5.

### 2.3 Truyện
Thêm `StorySceneId` (CUỐI enum). Lời thoại do localizer viết en (nguồn) + vi theo ý dưới, 3–5 dòng mỗi cảnh, giọng ấm
áp như các cảnh cũ. Người nói: Mai, người dẫn chuyện, khách quen tương ứng.

| id | Màn | Nền | Ý chính |
|---|---|---|---|
| `ch3Open` | 21 | `story_garden` | Mai dọn khu vườn sau tiệm, tìm thấy trong nhà kho một trang sổ của bà: croissant. |
| `mochi1` | 23 | `rainy_day` (có sẵn) | Ngày mưa, mèo Mochi trú dưới mái hiên; Mai cho nó vào, từ đó Mochi hay ghé. |
| `kenji4` | 27 | `story_town` | Kenji gọi món "cho một ngày nhớ nhà"; Mai chọn madeleine. |
| `ch4Open` | 31 | `story_attic` | Tầng trên: hộp thư cũ của bà, trang sổ éclair và tart trái cây. |
| `rosa1` | 33 | `story_town` | Bà Rosa ghé, kể cháu gái sắp cưới, hẹn Mai sẽ đặt bánh. |
| `linh4` | 37 | `story_town` | Linh rủ Mai làm bánh táo cho hội chợ trường. |
| `ch5Open` | 41 | `story_festival` | Thị trấn chuẩn bị lễ hội ven biển: đèn lồng, bánh Trung thu. |
| `hoa4` | 46 | `story_festival` | Ông Hòa kể chuyện bà từng làm bûche cho cả phố mỗi mùa đông. |
| `rosa2` | 50 | `story_festival` | Bánh cưới cho cháu bà Rosa; trước đơn đặc biệt màn 50. |
| `finale` (sẵn có) | sau khi thắng 50 lần đầu | `story_town` | Sửa lời: sổ của bà đã đầy, tiệm sống lại; "Còn nhiều câu chuyện nữa…". |

- `finale` hiện chạy khi xong chương 1 (`GameState.chapter1Complete` dựa vào nó). Thêm cảnh `ch2End` (sau màn 20, dùng lời
  finale cũ, sửa dòng cuối thành "Chương mới đang chờ…") và chuyển `finale` về sau màn 50. Bản lưu cũ đã xem `finale`:
  không phát lại, không mất gì; `chapter1Complete` giữ nghĩa cũ (đã xem `finale` **hoặc** `ch2End`).
- **Đã làm (8B, chốt sau quality-gate):** thêm cảnh `ch1End` (2 dòng, nền `story_grandma_kitchen`) làm `outroScene` màn
  10. `GameState.chapter1Complete` = đã xem `ch1End` **hoặc** `ch2End` **hoặc** `finale` — nghĩa "đã xong chương 1" như
  trước GĐ8. Bản lưu cũ đã xem `finale` mà chưa thắng màn 50 (`GameState._migrateFinale`): `finale` đổi thành `ch2End` +
  `ch1End` (không chiếu lại ở màn 10 / 20), `finale` mới vẫn chiếu sau màn 50.
- Mochi: cảnh `mochi1` bật cơ chế mèo ngày mưa sẵn có (nếu đã có điều kiện riêng thì giữ, chỉ thêm cảnh giới thiệu).

### 2.4 Chỗ tiêu xu chương 5 — "Bí quyết của bà"
(Không dùng chữ "mastery": bản lưu đã có `mastery` = sao sổ công thức 0–3.) Mỗi món có 3 bậc bí quyết mua bằng xu, mở từ
màn **41** (`recipe_secrets`, kind mới trong `unlocks.json`):
- Bậc 1/2/3: giá bán món đó **+8% / +16% / +25%**, giá xu = `round50(price × k)` với k = 120 / 300 / 600 (món 30 xu →
  3600 / 9000 / 18000; món 98 xu → ~11750 / 29400 / 58800). 18 món × 3 bậc ≈ 1,0 triệu xu → đủ hút xu dư của chương 5.
- Bản lưu: `recipeSecrets {recipeId: tier}`, đọc độc lập, thiếu → 0.
- UI: trong **Sổ công thức**, mỗi món có thanh 3 bậc + nút nâng (khoá tới màn 41, có dòng giải thích). Không ảnh 
  mới: dùng icon sao/huy hiệu vẽ tay sẵn có.
- Bot mô phỏng: mua bí quyết sau khi hết hàng chờ chính, trước trang trí, ưu tiên món đang có trong menu.

---

## 3. Cân bằng lại và kiểm tra (8C)
- Chạy `tool/simulate.dart` với dữ liệu thật; giữ mục tiêu GĐ7 (`SimTargets`, `phase7-balance.md`): chương 1–5 thắng lần
  đầu ≈ 82 / 71 / 62 / 60 / 57%, đủ sao mở chương 70–88%, mốc mua trễ 1–3 màn (dụng cụ ≤ 4).
- Thêm mục tiêu: xu dư cuối chương 5 (vắng nhà 8 giờ) **≤ 60 nghìn** sau khi bot mua bí quyết.
- Sinh lại mốc sao màn 21–50 (`SIM_CALIBRATE=1`) sau khi đổi menu/giá. Cập nhật `phase7-balance.md` (mục GĐ8).
- Kết thúc: analyze, test, build web, chụp màn hình bản đồ 3 chương mới, 8 món ở sổ công thức, 1 lượt làm mỗi món
  mới qua 6 trạm, 3 cảnh truyện; `/quality-gate`.

---

## 4. Ảnh (trưởng phòng, Gemini; prompt ghi vào `docs/design/asset-prompts.md` §11)
- Bánh thành phẩm `cakes/` ×8; đế nướng `baked/<recipeId>` ×8; khuôn rỗng `moulds/` ×6; bột trong âu `batter/` ×3;
  kem/nhân `frosting/` ×3; topping `toppings/` ×5 → **33 ảnh OBJECT** (khối OBJECT, nền tách).
- Bản đồ `map/chapter_3..5` ×3; nền truyện `scenes/story_garden`, `story_attic`, `story_festival` ×3 → **6 ảnh SCENE**.
- Tổng 39 ảnh ≈ 1 lượt Gemini. Thiếu ảnh → hình vẽ code dự phòng (riêng nhân vật vẫn phải là ảnh: dùng ảnh có sẵn).

## 5. Chia việc
| Ai | Khu vực | 8A | 8B | 8C |
|---|---|---|---|---|
| dev-core | lib/core, assets/config, test/core | enum, `Catalog` 8 món, art lookup, `CakeArt` dự phòng, test | levels 21–50, cảnh truyện (dữ liệu), `ch2End`/`finale`, bí quyết (state + config + bot) | sim, cân bằng, tài liệu |
| dev-game | lib/game, test/game | khuôn/bột/topping mới ở 6 trạm (`game_paint`, `mix_station`, `station_setup`), test | — | sửa lỗi nếu có |
| dev-ui | lib/ui, test/ui, tool/screens | sổ công thức hiện 18 món | bản đồ 3 chương, nền truyện mới, finale, UI bí quyết | chụp màn hình |
| localizer | .arb | tên 8 món + 17 tên nguyên liệu mới | lời thoại 10 cảnh, tên màn 21–50 (nếu đưa vào arb), chuỗi bí quyết | — |
| trưởng phòng | assets/art | 33 ảnh OBJECT | 6 ảnh SCENE | — |

Thứ tự: dev-core 8A trước (enum + catalog) → dev-game ∥ localizer ∥ ảnh → dev-ui. 8B tương tự (dev-core → localizer ∥
dev-ui). Hai người không sửa cùng file cùng lúc. Không commit.
