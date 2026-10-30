# V2 · Giai đoạn 2 — Bản đồ level theo chương, khoá chương bằng sao, lưu tiến trình

Nhánh `v2`. Tiếp nối `phase1-spec.md`. Chủ dự án đã duyệt 5 ảnh GĐ1 (đã chép vào `assets/art/shop/shop_base_empty.webp`
và `assets/art/level/{display_case,thought_bubble,special_badge,topping_jar}.webp`; pubspec đã khai báo
`assets/art/level/` và `assets/art/map/`).

## 1. Mục tiêu
1. **Bản đồ chương là màn chính** (route `/` = `AppRoutes.menu`): mỗi chương một trang ngang, vuốt/nút để đổi chương.
   Nền tranh thị trấn (`assets/art/map/chapter_<id>.webp`, thiếu ảnh → nền vẽ code), đường đi vẽ tay nối các nút level
   theo `mapPos` trong `levels.json`. Nút level: số, 0–3 sao đã đạt, trạng thái khoá / mở / đang tới (nhịp nhẹ), level
   đặc biệt (★) to hơn và khác màu. Chạm nút mở → thẻ "Sẵn sàng" (dùng lại của GĐ1) → `/level`.
2. **Thanh trên của bản đồ** thay menu cũ: xu, đá quý, tổng sao; nút Nhiệm vụ ngày, Quà đăng nhập (tự bật khi có quà
   như menu cũ), Sổ công thức, Nâng cấp, Trang trí, Cửa hàng, Cài đặt. Bỏ hiển thị "cấp tiệm / XP".
3. **Khoá chương bằng sao**: chương N mở khi (a) đã qua level cuối chương N−1 và (b) tổng sao ≥ `starsToUnlock`. Trang
   chương khoá: tranh mờ + ổ khoá + "Cần X ★ (bạn có Y)". Chưa đủ sao thì gợi ý chơi lại level ít sao.
4. **Lưu tiến trình** (save v2 + migration v1 → v2, xem mục 3). Kết thúc màn → về bản đồ, hoạt cảnh: sao mới bay vào
   nút, nút level sau mở khoá; mở chương mới → thông báo đẹp.
5. **Gỡ chế độ "ngày" V1** khỏi giao diện và code: `DayScreen`, `DaySummaryScreen`, `DayController`, `DaySummary`,
   route `/day`, `/summary`, menu chính cũ. Giữ các widget dùng lại (`StoryOverlay`, `OrderTicket`, `ResultCard`) và
   `OrderGenerator.makeOrder`. Mèo Mochi (ngày mưa) tạm ngừng xuất hiện — giữ code `mochi_visit.dart`, `weather.dart` và
   các trường lưu Mochi để đưa lại vào level ở giai đoạn sau.
6. **Chương 2 "Tiệm đông khách"** (L11–20) có đủ 10 level trong `levels.json` (thêm `birthdayCake`; L20 là màn đặc biệt
   "Giờ cao điểm"), `starsToUnlock` sao cho người chơi điển hình đủ sao sau một lượt chương 1 (~70% tổng sao chương 1).
   Cân bằng bằng bot như GĐ1 (chưa có nhân viên/lò thứ 2 — sẽ thêm ở GĐ3–4).
7. Cảnh chơi dùng 5 ảnh mới (dev-game).

## 2. Hợp đồng API (thêm, không đổi chữ ký cũ trừ khi ghi rõ)

`levels.json`: `ChapterData` thêm `mapArt` (tên ảnh, vd `"chapter_1"`), `LevelData` thêm `mapPos: [x, y]` (0..1 theo khung
1280×720 của trang chương, chừa vùng thanh trên y < 0.14).

`lib/core` (dev-core):
```dart
class LevelRecord { final int stars; final int best; final int plays; final bool firstWin; bool get completed => stars > 0; }
class LevelProgressDelta {          // trả về từ applyLevelResult
  final int levelId; final int oldStars; final int newStars; final bool newBest;
  final int? unlockedLevel;         // level vừa mở (null nếu không)
  final int? unlockedChapter;       // chương vừa mở
}
// GameState
void attachLevelConfig(LevelConfig cfg);   // main.dart gọi một lần sau khi nạp
LevelConfig get levelConfig;
LevelRecord? levelRecord(int id);
int get totalStars;
int starsInChapter(int chapter);
bool isLevelUnlocked(int id);
bool isChapterUnlocked(int chapter);
int get currentLevelId;                    // level mở thấp nhất chưa qua; qua hết → level cao nhất
int get highestCompletedLevel;             // 0 nếu chưa qua level nào
LevelProgressDelta applyLevelResult(LevelResult r);   // trước: void
```
- `isRecipeUnlocked` / `unlockedRecipes` tính theo tiến trình: món có trong menu của level đã mở.
- Nâng cấp lò/dụng cụ và đồ trang trí đang khoá theo "cấp tiệm" → tạm quy đổi từ `highestCompletedLevel` sao cho mở
  dần trong chương 1–2 (GĐ3 thay bằng `unlocks.json`). Không hiện XP ở đâu nữa; trường `xp` vẫn đọc/ghi.
- `AppRoutes`: bỏ `day`, `summary`, `DaySummaryArgs`. `AppRoutes.menu` = bản đồ.

## 3. Lưu game v2 + migration
- `saveVersion = 2`, cùng khoá `sugarleaf_save_v1`. Lần đầu đọc bản v1: chép nguyên chuỗi sang
  `sugarleaf_save_v1_pre_v2` (không bao giờ ghi đè), rồi quy đổi.
- Trường mới: `"progress": {"levels": {"<id>": {"stars", "best", "plays", "firstWin"}}, "migratedFromV1": bool}`. Đọc từng
  trường độc lập như hiện nay; id level không còn trong config → giữ nguyên trong JSON (không xoá), chỉ bỏ qua khi tính.
- Quy đổi v1: người chơi đã chơi tới ngày D (`day`) được tính đã qua L1..min(D−1, 9) mỗi level 2★, `plays = 1`,
  `firstWin = true`; quà chào mừng 500 xu + 20 đá quý (một lần, đánh dấu `migratedFromV1`). Mọi trường v1 giữ nguyên.
- App bản cũ (v1) đọc bản lưu v2 → tự khoá ghi (cơ chế sẵn có), không mất dữ liệu.
- Test: bản lưu v1 mẫu (mới, giữa game ngày 6, cuối game, hỏng một phần) → v2 → kiểm từng trường; ghi → đọc lại khớp;
  bản pre_v2 không bị ghi đè lần 2.

## 4. Chia việc
| Ai | Khu vực | Việc |
|---|---|---|
| dev-core | lib/core, lib/main.dart, assets/config, test/core | mục 2, 3, 6; xoá DayController/DaySummary + test của chúng; cập nhật routes |
| dev-ui | lib/ui, test/ui, tool/screens | mục 1–5: `LevelMapScreen` làm màn chính, bỏ `/levels` tạm (chuyển hướng về `/`), hoạt cảnh sau kết quả, thông báo mở chương; xoá DayScreen, DaySummaryScreen, MainMenuScreen + test liên quan |
| dev-game | lib/game, test/game | mục 7 |
| trưởng phòng | assets/art/map | tạo ảnh bản đồ chương 1–2 bằng Gemini |
| localizer | .arb | chuỗi mới (bảng do dev-ui/dev-core ghi ở `docs/v2/phase2-strings-*.md`) |
