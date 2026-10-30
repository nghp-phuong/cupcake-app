# V2 · Giai đoạn 4 — Nhân viên, tự làm trong level, thu nhập offline

Nhánh `v2`. Tiếp nối `phase3-spec.md` (mở khoá + `ShopSetup`). Ở GĐ3 các mục `staff_*` là "Sắp có"; GĐ4 bật chúng.

## 1. Mục tiêu
1. **5 nhân viên** (mỗi người một ảnh nhân vật vẽ tay Gemini, tên, vai trò, 2 chỉ số **Tốc độ** và **Tay nghề** cấp 1–5,
   nâng bằng xu): thuê bằng `buyUnlock(staff_*)` khi đã qua level mốc.
2. **Tự làm trong mọi level** sau khi thuê. Người chơi vẫn làm được mọi trạm; **đơn đặc biệt luôn do người chơi làm**
   (nhân viên không đụng).
3. **Quản lý** → thu nhập khi vắng nhà, có trần giờ, màn "Khi bạn vắng nhà" lúc mở app / quay lại app, nút x2 bằng quảng
   cáo thưởng (dịch vụ quảng cáo giả lập sẵn có, dùng chung giới hạn rewarded mỗi ngày).
4. 60 fps với 20+ khách và 10 nhân viên (test perf giả lập 10 nhân viên dù hiện chỉ có 5).

## 2. Nhân viên (dữ liệu ở `assets/config/unlocks.json`, mục `staff` mới — sửa không cần code)
| unlock id | Nhân vật (ảnh) | Tên en / vi | Vai trò | Mở sau L | Việc tự làm |
|---|---|---|---|---|---|
| `staff_cashier` | `staff_nora` | Nora / Nora | Thu ngân | 10 | Bán cho khách ở quầy |
| `staff_baker` | `staff_bao` | Bao / Bảo | Thợ bánh | 15 | Dây chuyền nướng riêng (làn 1) |
| `staff_waiter` | `staff_theo` | Theo / Theo | Phục vụ | 25 | Phục vụ khách đang chờ ở bàn (cần `cafe_tables`) |
| `staff_baker_2` | `staff_ami` | Ami / Ami | Thợ bánh | 28 | Dây chuyền nướng làn 2 |
| `staff_manager` | `staff_hanh` | Ms. Hanh / cô Hạnh | Quản lý | 32 | Thu nhập offline |

Thông số gợi ý (dev-core chỉnh theo bot; mọi số nằm trong JSON):
- **Thu ngân**: tiến độ chỉ chạy khi có khách mua được (đổi khách → làm lại từ 0); mỗi `cashierSec` (cấp tốc độ 1 → 5: 3.2 → 1.6 s) bán 1 cái cho khách đứng quầy lâu nhất mà món có trong tủ
  (như người chơi chạm, tính combo). Tay nghề: tip +4%/cấp trên lượt nó bán.
- **Thợ bánh** (mỗi làn): chỉ làm món mà khách đang trong tiệm muốn nhưng tủ + các mẻ đang làm còn thiếu (ưu tiên món ít
  nhất trong tủ; bỏ qua nếu tủ không còn chỗ cho cả mẻ), làm xong một mẻ sau `bakerSec` (1 → 5: 24 → 12 s), cho `batchSize` cái vào tủ. Tay nghề quyết định sao: cấp 1 chủ yếu 3★, cấp 5 chủ yếu
  5★ (ngẫu nhiên theo seed). Làn thợ **tách riêng** bếp nhanh của người chơi (không chiếm lò/khu chuẩn bị).
- **Phục vụ**: mỗi `waiterSec` (1 → 5: 4 → 2 s) bán cho khách đang chờ trong hàng (chưa tới quầy); khách đang chờ giảm kiên
  nhẫn chậm hơn `+5%/cấp tay nghề`.
- **Quản lý**: xu mỗi giờ vắng = `rate × thu nhập trung bình một level ở tiến trình hiện tại` (gợi ý rate 0.20 → 0.40 theo
  tốc độ), trần giờ 4 → 8 theo tay nghề, tối thiểu 10 phút mới tính. Không có việc trong level.
- Nâng cấp mỗi chỉ số: cấp 2..5, giá tăng dần (≈ 0.6–1.2 × thu nhập một level quanh mốc). `staff_training` (L41, chương 5)
  để sau: nâng trần cấp lên 7.

## 3. Hợp đồng API

`lib/core` (dev-core):
```dart
// lib/core/staff/staff.dart
enum StaffRole { cashier, baker, waiter, manager }
class StaffData { String id /* = unlock id */; String character; StaffRole role; String name(String lang); String bio(String lang);
  List<num> speedValues; List<num> skillValues; List<int> speedPrices; List<int> skillPrices; int maxLevel; }
class StaffMember { final String id; final StaffRole role; final String character; final int speed; final int skill; } // đã thuê
// UnlockConfig thêm: List<StaffData> staff; StaffData? staffById(String id);

// ShopSetup thêm: final List<StaffMember> staff;   // nhân viên đã thuê (thứ tự cố định), LevelSession đọc từ đây

// LevelSession: nhân viên tự làm trong advance(); đọc được để vẽ:
class StaffState { final StaffMember member; double progress /*0..1 tới lần làm tiếp*/; RecipeId? working /*thợ*/;
  int? targetCustomer /*thu ngân/phục vụ*/; int actions; }
List<StaffState> get staff;
// SessionEvent mới (thêm CUỐI enum): staffSold (customer, staffIndex), staffBatchReady (recipe, stars, count, staffIndex)
// LevelResult thêm: int staffSales; int staffBakes.

// GameState
int staffLevel(String id, StaffStat stat);           // enum StaffStat { speed, skill }; 0 = chưa thuê
PurchaseResult upgradeStaff(String id, StaffStat stat);
bool isStaffHired(String id);
OfflineEarnings? get pendingOffline;                  // tính lúc load / resume, null nếu không có
void claimOffline({bool doubled = false});            // cộng xu, xoá pending, lưu
void markActive();                                    // ghi mốc thời gian hoạt động (lưu cùng save)
class OfflineEarnings { final Duration away; final Duration counted /*đã cắt theo trần*/; final int coins; final int capHours; }
// AdPlacement thêm CUỐI: offlineDouble.
```
- Bản lưu (`v: 2`): `staff: {"staff_cashier": {"speed": 1, "skill": 1}, ...}` (thuê = có trong `shop.owned`), `lastActive`
  (epoch ms). Đồng hồ lùi (now < lastActive) → không tính, đặt lại mốc. Không I/O chặn UI.
- Mục `staff_*` không còn `comingSoon` (trừ `staff_training`); `newUnlocks` lại gồm nhân viên mua được.
- Bot: `LevelBot` / mô phỏng tiến trình thuê nhân viên khi đủ xu (ưu tiên: mở rộng → nhân viên → thiết bị → dụng cụ →
  trang trí) và nâng chỉ số. Cân lại L10–L20 để độ khó ~GĐ3 khi đã có nhân viên kỳ vọng. In bảng: level thuê từng người,
  xu/level, tỉ lệ thắng lần đầu, phần bán do nhân viên (%).

`lib/game` (dev-game):
- Vẽ nhân viên trong cảnh tiệm (ảnh `assets/characters/<character>_<neutral|smile>.webp`, giải mã 352 px × hệ số màn như khách; khách ở quầy và thu ngân phóng 1.45× theo góp ý tỉ lệ của chủ dự án):
  thu ngân đứng sau quầy cạnh máy tính tiền; thợ bánh ở phía sau bên trái (cửa bếp/kệ) có vòng tiến độ trên đầu, xong mẻ thì
  bánh bay vào tủ; phục vụ đi giữa hàng chờ và bàn. Khi nhân viên bán: hiệu ứng nhỏ (đồng xu bay) từ nhân viên. Dùng
  `smile` lúc vừa làm xong. Không che bong bóng / tủ / khách đặc biệt.
- Nạp sẵn ảnh nhân viên đã thuê (`LevelPlayView.preload`). Thiếu ảnh → hình dự phòng sẵn có (CharacterPainter) như khách.
- Perf: 25 khách + 10 nhân viên giả lập, avg < 1 ms/khung.

`lib/ui` (dev-ui):
- **Màn Nâng cấp thêm tab "Nhân viên"** (hoặc màn riêng nếu gọn hơn — giữ nút thanh trên như hiện có): thẻ mỗi người: chân
  dung (cắt nửa người từ ảnh `smile`), tên, vai trò, 1 câu giới thiệu, 2 thanh chỉ số (pip 1–5) và giá nâng từng chỉ số; chưa
  thuê → giá thuê + "Thuê"; chưa tới mốc → "Qua màn X để mở". Thông báo mở khoá "Xem" với nhân viên → tab này.
- **Hộp "Khi bạn vắng nhà"** trên bản đồ khi `pendingOffline != null`: chân dung quản lý, thời gian vắng (ghi rõ đã cắt
  theo trần), số xu, nút "Nhận" và "x2 (xem quảng cáo)" (rewarded, hết lượt thì ẩn). Thứ tự hộp trên bản đồ: lời chào →
  vắng nhà → quà đăng nhập → hoạt cảnh/thông báo. Cũng hiện khi app quay lại từ nền (AppLifecycle) nếu đủ điều kiện.
- Thẻ "Sẵn sàng": hàng chân dung nhỏ các nhân viên sẽ làm trong màn.
- Chuỗi mới ghi ở `docs/v2/phase4-strings-ui.md`.

## 4. Ảnh (trưởng phòng, Gemini)
`assets/characters/staff_{nora,bao,theo,ami,hanh}_{neutral,smile}.webp` (480×640, nền trong suốt), STYLE ở
`docs/design/character-prompts.md` với câu tỉ lệ 7.5 đầu.

## 5. Chia việc
| Ai | Khu vực | Việc |
|---|---|---|
| dev-core | lib/core, main.dart, assets/config, test/core | §2–3 phần core, bot, cân bằng, ids ảnh nhân vật |
| dev-game | lib/game, test/game | vẽ nhân viên trong cảnh, perf |
| dev-ui | lib/ui, test/ui, tool/screens | tab Nhân viên, hộp vắng nhà, thẻ Sẵn sàng |
| localizer | .arb | chuỗi ở `docs/v2/phase4-strings-ui.md` |
| trưởng phòng | assets/characters | 10 ảnh §4 |
