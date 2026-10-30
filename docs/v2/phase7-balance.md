# V2 · Giai đoạn 7 — Kết quả cân bằng 50 màn

Ngày 30/10/2026, nhánh `v2`. Đặc tả: `docs/v2/phase7-spec.md`. Số liệu dưới đây là kết quả lần chạy
`flutter test tool/simulate.dart` mặc định: 200 người chơi giả mỗi kỹ năng, seed 0, thua tối đa 10 lần mỗi màn, không vắng
nhà, không vật phẩm, không quảng cáo và không IAP.

Tài liệu đã cập nhật sau **bản sửa 3 điểm lệch** (chương 2 quá khó, mốc 20★ mở chương 2, nâng nhân viên / dụng cụ mua
trễ). §4–§6 là số liệu sau khi sửa. §7 ghi trước → sau, các số đã đổi và lý do.

## 1. Cách chạy

```
flutter test tool/simulate.dart                                  # mặc định, khoảng 40 s (song song 11 isolate)
SIM_RUNS=50 SIM_SKILL=average flutter test tool/simulate.dart    # nhanh
SIM_BOOSTERS=1 SIM_OUT=build/sim.csv flutter test tool/simulate.dart
SIM_CALIBRATE=1 SIM_SKILL=average,good flutter test tool/simulate.dart                        # mốc sao màn nháp
SIM_CALIBRATE=1 SIM_CALIBRATE_FROM=10 SIM_SKILL=average,good flutter test tool/simulate.dart   # cả chương 2
```
Biến môi trường: `SIM_RUNS`, `SIM_SEED`, `SIM_SKILL` (`newbie`, `average`, `good`; ghi nhiều kỹ năng thì cách nhau dấu phẩy),
`SIM_BOOSTERS`, `SIM_OFFLINE_HOURS`, `SIM_OUT` (ghi thêm `<tên>_milestones.csv` và `<tên>_chapters.csv`), `SIM_CALIBRATE`
(in mốc sao gợi ý và `starsToUnlock` gợi ý mỗi chương), `SIM_CALIBRATE_FROM` (gợi ý mốc sao cho các màn có id lớn hơn số
này; mặc định là màn cuối của `levels.json`), `SIM_WORKERS`. Phải chạy bằng `flutter test` vì logic level dùng
`package:flutter/foundation.dart` và `dart:ui` (`Offset`), nên `dart run` không chạy được.

Mã nguồn:
- `lib/core/sim/progression_sim.dart`: mô phỏng tiến trình và mua sắm (`simShop`), dùng chung cho test và tool. Tệp này còn
  có `mergeLevelDraft`, hàm gộp `levels.json` với bản nháp.
- `lib/core/sim/sim_runner.dart`: người chơi giả, tham số `SIM_*` và phần chạy song song bằng isolate. Kết quả tất định
  theo seed, không phụ thuộc số isolate.
- `lib/core/sim/balance_report.dart`: các bảng, CSV, danh sách lệch mục tiêu (`SimTargets`), phần sinh mốc sao
  (`calibrateStars`) và gợi ý `starsToUnlock` (`suggestStarGates`).
- `tool/simulate.dart`: script chạy mô phỏng. `test/core/simulate_test.dart`: chạy rút gọn để kiểm tra (§6).

**Người chơi giả.** Mỗi người chơi giả chơi lần lượt từ L1 tới L50. Trước mỗi lượt, người chơi mua sắm theo `simShop`
(luật mới của bản sửa lệch, xem §7.3):
1. **Hàng để dành**: mọi món đang mua được của 5 nhóm (mở rộng, thuê nhân viên, nâng nhân viên lên cấp 2, thiết bị mới,
   dụng cụ) xếp chung một hàng theo level mở, món cũ trước. Nâng nhân viên cấp 2 lấy level thuê được nhân viên đó. Mở rộng
   tính sớm hơn 1 level, dụng cụ tính muộn hơn 1 level. Cùng level thì xếp theo thứ tự nhóm, rồi món rẻ trước. Món đầu
   hàng đủ xu thì mua và xét tiếp; chưa đủ xu thì để dành, không mua gì khác.
2. Hết hàng để dành thì mới nâng nhân viên cấp 3 trở lên (món rẻ trước), sau đó mua trang trí rẻ nhất.

Kim cương được cộng như trong game thật (lần đầu đạt 3★, hết chương).
- `newbie` = `BotSkill.newcomer` (độ chính xác 0.5, phản ứng 1.2 s) và `good` = `BotSkill.of(0.75)`, giống các test cân
  bằng GĐ1–6.
- `average` = `BotSkill.of(0.5)` (`SimPersona.averageSkill`). Mức 0.5 được chọn để chương 1 (đã cân từ trước, không
  sửa) cho tỉ lệ thắng lần đầu ≈ 80%. Kết quả thử: 0.4 → 66%, 0.45 → 77%, **0.5 → 82%**, 0.6 → 91%.

## 2. Nội dung L21–50 (`assets/config/levels_draft.json`)

Đây là bản nháp chỉ dùng cho mô phỏng. **Game chưa nạp tệp này**: `levels.json` vẫn có 20 màn, và có test kiểm tra điều
đó. Tuy vậy `pubspec.yaml` khai báo cả thư mục `assets/config/`, nên tệp vẫn được đóng gói vào app (khoảng 23 KB, không
màn nào đọc tới). Định dạng giống `levels.json`. Toàn bộ thông số sinh theo công thức ghi trong `_note`
(n = id − 20; i = vị trí trong chương, 1..10):

| Trường | Công thức |
|---|---|
| chương | 3 / 4 / 5, mỗi chương 10 màn. `starsToUnlock` = **28 / 40 / 53**: số sao mà khoảng 78% người chơi `average` có đủ ngay khi vừa qua hết chương trước lần đầu (`suggestStarGates`). Ảnh `chapter_3..5` chưa có |
| `durationSec` | 200 + 4i; i = 10 thì 240 (`special: true`, cuối chương) |
| mục tiêu | đếm khách khi i = 1 hoặc 6, còn lại là xu |
| `menu` | 4 món `P[(3n + 2k) mod 7]`, k = 0..3, với P là 7 món giá cao nhất (dâu, macaron, red velvet, matcha, cheesecake, sinh nhật, tart trứng). Không có món mới vì cả 10 món đã mở hết ở L12 |
| `patienceSec` | 26 − 0.12n (25.9 → 22.4) |
| `spawn` | `startEverySec` = 7.8 − 0.05n (7.75 → 6.3); `endEverySec` = start × 0.69; `rushEverySec` = start × 0.38; `rushAtPct` = 70 + 2(n mod 3) |
| `flexibleChance` | min(0.6, 0.45 + 0.005n) |
| khách đặc biệt | 1 khách (i lẻ), 2 khách (i chẵn), 3 khách (i = 10). Lần lượt là Hòa (tart trứng), Linh (macaron), Kenji (`menu[0]`), VIP (`menu[3]`, ảnh vip_01/02). `atSec` chia đều theo thời lượng màn |
| `stars` | 1★ = phân vị (1 − p) của giá trị mục tiêu ở **lượt đầu** của `average` trong mô phỏng tiến trình. Mục tiêu p: chương 3 = 0.62, chương 4 = 0.60, chương 5 = 0.57. Mục tiêu đếm khách là số nguyên nên tỉ lệ thắng lệch khỏi p; phần lệch được bù vào các màn mục tiêu xu cùng chương. 2★ / 3★ = phân vị 35% / 75% của `good`. Mỗi mốc lớn hơn mốc trước ít nhất 4% |

Mốc sao được sinh bằng `SIM_CALIBRATE=1`, lặp tới khi ổn định (lần lặp cuối chỉ lệch ≤ 50 xu ở vài màn). Sau bản sửa lệch,
luật mua và giá đổi nên mốc sao L21–50 đã được sinh lại. Mốc 1★ tăng dần: khoảng 4–6 nghìn xu ở chương 3, 4.7–8.2 nghìn
ở chương 4, 6.4–10 nghìn ở chương 5. Tiêu đề màn tạm đặt dạng "Chương 3 · Bản nháp 21". Khi đưa vào game cần thay tiêu
đề, `mapPos`, cảnh truyện và ảnh bản đồ.

## 3. Số đã đổi (tổng hợp)

| Tệp | Lần đầu GĐ7 | Bản sửa lệch (§7) |
|---|---|---|
| `assets/config/levels_draft.json` | (chưa có) → 30 màn L21–50 + chương 3–5 | `starsToUnlock` chương 4: 42 → 40, chương 5: 55 → 53; mốc sao L21–50 sinh lại |
| `assets/config/levels.json` | không đổi | `starsToUnlock` chương 2: 20 → 16; mốc 1★ L12–L20 |
| `assets/config/unlocks.json` | không đổi | giá mở rộng / thuê / thiết bị chương 2, dụng cụ, nâng nhân viên cấp 2 |
| `lib/core/economy.dart` | không đổi | `ovenTiers` / `toolTiers` (bản sao giá lò vùng vàng + dụng cụ) |
| `lib/core/sim/progression_sim.dart` | chuyển từ `test/core/progression_sim.dart`, hành vi giữ nguyên | luật mua `simShop` mới |

Bản nháp đầu tiên (mốc sao ước lượng tay: 1★ ≈ 5000 + 100n) bị kẹt nhiều và dồn xu (chương 3: thắng lần đầu 26%, kẹt
46%). Sau đó menu được đổi sang 7 món giá cao nhất, và nhịp khách được đổi thành 7.8 − 0.05n.

## 4. Kết quả cuối (sau bản sửa lệch)

### 4.1 Tổng kết chương (thắng lần đầu là trung bình các màn trong chương)

```
=== newbie ===
ch | màn     | thắng lần 1 TB | lần thử TB | kẹt TB | sao TB | xu cuối chương | kim cương | đủ sao mở | sao TV / cần
 1 | L1–10   |            62% |       1.75 |     0% |   1.55 |           5342 |      31.3 |      100% |            —
 2 | L11–20  |            64% |       1.56 |     0% |   1.24 |           9724 |      15.1 |       50% |      16 / 16
 3 | L21–30  |            63% |       1.63 |     0% |   1.22 |          10098 |      12.3 |       60% |      28 / 28
 4 | L31–40  |            58% |       1.78 |     0% |   1.37 |          10779 |      12.5 |       56% |      40 / 40
 5 | L41–50  |            52% |       2.06 |     0% |   1.14 |          26925 |      12.2 |       64% |      54 / 53
=== average ===
 1 | L1–10   |            82% |       1.22 |     0% |   1.69 |           5145 |      31.1 |      100% |            —
 2 | L11–20  |            71% |       1.38 |     0% |   1.26 |           9542 |      15.6 |       87% |      17 / 16
 3 | L21–30  |            61% |       1.63 |     0% |   1.20 |          10945 |      12.3 |       82% |      29 / 28
 4 | L31–40  |            60% |       1.68 |     0% |   1.38 |          10248 |      12.7 |       76% |      42 / 40
 5 | L41–50  |            57% |       1.81 |     0% |   1.15 |          17856 |      12.2 |       80% |      55 / 53
=== good ===
 1 | L1–10   |            97% |       1.03 |     0% |   2.22 |           7023 |      34.4 |      100% |            —
 2 | L11–20  |            99% |       1.01 |     0% |   2.14 |           9278 |      17.8 |      100% |      22 / 16
 3 | L21–30  |            90% |       1.16 |     0% |   1.74 |          15988 |      14.1 |      100% |      43 / 28
 4 | L31–40  |            82% |       1.31 |     0% |   1.80 |          10929 |      14.3 |      100% |      61 / 40
 5 | L41–50  |            92% |       1.10 |     0% |   1.74 |          15330 |      14.1 |      100% |      80 / 53
```
Cột "đủ sao mở" là tỉ lệ người chơi giả có đủ tổng sao để mở chương này ngay khi vừa qua màn cuối chương trước, tính trên
lần chơi đầu và không chơi lại để lấy thêm sao. Cột "sao TV / cần" là trung vị tổng sao lúc đó so với `starsToUnlock`.

### 4.2 Mốc mở khoá (`average`)

Cột trễ = trung vị (số màn đã qua lúc mua) − màn mở. Với nâng nhân viên cấp 2, màn mở là màn thuê được nhân viên đó. Ký
hiệu ✗: trễ > 3 màn (dụng cụ > 4 màn), hoặc mua ngay mà còn dư > 2 × giá. Lần chạy cuối không có mốc nào bị ✗.

```
mốc                         | nhóm      | mở sau L | giá   | màn TV mua | trễ  | chưa mua | xu dư TV |
eq:goldenOven:2             | dụng cụ   |        2 |   500 |        2.0 |  0.0 |        0 |      108 |
eq:fastOven:2               | thiết bị  |        3 |  1400 |        4.0 |  1.0 |        0 |      140 |
eq:tongs:2                  | dụng cụ   |        3 |   400 |        4.0 |  1.0 |        0 |      301 |
eq:whisk:2                  | dụng cụ   |        4 |   400 |        6.0 |  2.0 |        0 |      434 |
case_stand                  | mở rộng   |        5 |  4200 |        6.0 |  1.0 |        0 |      585 |
eq:goldenOven:3             | dụng cụ   |        6 |   900 |        9.0 |  3.0 |        0 |      373 |
eq:pipingBag:2              | dụng cụ   |        6 |   800 |        8.0 |  2.0 |        0 |      332 |
eq:wideCase:2               | thiết bị  |        7 |  2800 |        8.0 |  1.0 |        0 |      709 |
eq:fastOven:3               | thiết bị  |        8 |  3500 |       10.0 |  2.0 |        0 |          |
eq:bigTray:2                | thiết bị  |        9 |  4000 |       11.0 |  2.0 |        0 |      699 |
staff_cashier               | nhân viên |       10 |  5000 |       12.0 |  2.0 |        0 |      569 |
eq:tongs:3                  | dụng cụ   |       10 |  1400 |       14.0 |  4.0 |        0 |          |
staff:staff_cashier:speed:2 | nâng NV   |       10 |  1600 |       12.0 |  2.0 |        0 |          |
staff:staff_cashier:skill:2 | nâng NV   |       10 |  1400 |       12.0 |  2.0 |        0 |          |
eq:goldenOven:4             | dụng cụ   |       11 |  1700 |       15.0 |  4.0 |        0 |          |
oven_2                      | mở rộng   |       12 | 10500 |       14.0 |  2.0 |        0 |      777 |
eq:whisk:3                  | dụng cụ   |       13 |  1600 |       15.0 |  2.0 |        0 |     1262 |
eq:fastOven:4               | thiết bị  |       14 |  5400 |       15.0 |  1.0 |        0 |     1221 |
staff_baker                 | nhân viên |       15 |  7500 |       17.0 |  2.0 |        0 |     1238 |
eq:pipingBag:3              | dụng cụ   |       15 |  1800 |       19.0 |  4.0 |        0 |     1163 |
staff:staff_baker:speed:2   | nâng NV   |       15 |  2600 |       17.0 |  2.0 |        0 |      828 |
staff:staff_baker:skill:2   | nâng NV   |       15 |  2400 |       17.0 |  2.0 |        0 |     2000 |
eq:wideCase:3               | thiết bị  |       16 |  5400 |       18.0 |  2.0 |        0 |      533 |
eq:bigTray:3                | thiết bị  |       17 |  5100 |       20.0 |  3.0 |        0 |      667 |
cafe_tables                 | mở rộng   |       18 | 10000 |       20.0 |  2.0 |        0 |     2208 |
eq:goldenOven:5             | dụng cụ   |       19 |  2800 |       21.0 |  2.0 |        0 |     2485 |
kitchen_2                   | sắp có    |       22 | 12000 |          — |    — |      200 |          | (không bán)
staff_waiter                | nhân viên |       25 | 13000 |       26.0 |  1.0 |        0 |     1959 |
staff:staff_waiter:speed:2  | nâng NV   |       25 |  3800 |       27.0 |  2.0 |        0 |     1882 |
staff:staff_waiter:skill:2  | nâng NV   |       25 |  3400 |       26.0 |  1.0 |        0 |     1894 |
staff_baker_2               | nhân viên |       28 | 15000 |       29.0 |  1.0 |        0 |     1515 |
staff:staff_baker_2:speed:2 | nâng NV   |       28 |  4400 |       30.0 |  2.0 |        0 |     2238 |
staff:staff_baker_2:skill:2 | nâng NV   |       28 |  4000 |       30.0 |  2.0 |        0 |     1773 |
garden                      | mở rộng   |       30 | 16000 |       32.0 |  2.0 |        0 |     1833 |
staff_manager               | nhân viên |       32 | 18000 |       34.0 |  2.0 |        0 |     3739 |
staff:staff_manager:speed:2 | nâng NV   |       32 |  5000 |       35.0 |  3.0 |        0 |          |
staff:staff_manager:skill:2 | nâng NV   |       32 |  4500 |       35.0 |  3.0 |        0 |     3538 |
floor_2                     | mở rộng   |       35 | 20000 |       37.0 |  2.0 |        0 |     2352 |
staff_training              | sắp có    |       41 | 22000 |          — |    — |      200 |          | (không bán)
rare_decor                  | sắp có    |       45 | 25000 |          — |    — |      200 |          | (không bán)
```
Người chơi `good` (không chơi lại, ít xu hơn) có 2 mốc trễ 4 màn: `eq:bigTray:3` và `staff:staff_manager:speed:2`. Mục tiêu
chỉ tính cho `average`. `newbie` không có mốc nào trễ.

### 4.3 Mỗi màn (`average`)

```
màn  | ch | xu TB  | xu TV  | xu tích luỹ | thắng lần 1 | lần thử | kẹt  | sao TB | NV bán
L1   |  1 |    380 |    378 |         380 |        100% |    1.00 |   0% |   3.00 |     0%
L2   |  1 |    526 |    528 |         906 |        100% |    1.00 |   0% |   3.00 |     0%
L3   |  1 |    992 |    735 |        1898 |         67% |    1.46 |   0% |   1.30 |     0%
L4   |  1 |   1169 |    921 |        3066 |         63% |    1.56 |   0% |   1.61 |     0%
L5   |  1 |   1921 |   1778 |        4988 |         91% |    1.10 |   0% |   1.35 |     0%
L6   |  1 |   1862 |   1765 |        6850 |         95% |    1.07 |   0% |   1.03 |     0%
L7   |  1 |   2644 |   2818 |        9494 |         29% |    1.79 |   0% |   1.02 |     0%
L8   |  1 |   2128 |   1947 |       11622 |         88% |    1.13 |   0% |   1.68 |     0%
L9   |  1 |   2641 |   2533 |       14263 |         95% |    1.05 |   0% |   1.00 |     0%
L10  |  1 |   3667 |   3488 |       17930 |         95% |    1.05 |   0% |   1.89 |     0%
L11  |  2 |   2874 |   2190 |       20804 |         68% |    1.42 |   0% |   1.62 |     0%
L12  |  2 |   7477 |   7616 |       28281 |         50% |    1.62 |   0% |   1.00 |     4%
L13  |  2 |   6356 |   4969 |       34637 |         74% |    1.39 |   0% |   1.16 |    23%
L14  |  2 |   5974 |   4661 |       40611 |         74% |    1.36 |   0% |   1.30 |    19%
L15  |  2 |   7015 |   5502 |       47626 |         75% |    1.33 |   0% |   1.23 |    21%
L16  |  2 |   6387 |   5015 |       54013 |         74% |    1.36 |   0% |   1.26 |    19%
L17  |  2 |   6919 |   5556 |       60932 |         75% |    1.33 |   0% |   1.31 |    19%
L18  |  2 |   5765 |   4570 |       66697 |         74% |    1.34 |   0% |   1.25 |    16%
L19  |  2 |   6668 |   5269 |       73365 |         74% |    1.35 |   0% |   1.30 |    15%
L20  |  2 |   7347 |   5873 |       80712 |         75% |    1.31 |   0% |   1.12 |    16%
L21  |  3 |   9814 |   8338 |       90527 |         49% |    2.08 |   0% |   1.00 |    17%
L22  |  3 |   7135 |   5229 |       97662 |         64% |    1.49 |   0% |   1.26 |    17%
L23  |  3 |   6465 |   4453 |      104128 |         63% |    1.57 |   0% |   1.21 |    20%
L24  |  3 |   9250 |   6103 |      113378 |         63% |    1.65 |   0% |   1.25 |    21%
L25  |  3 |   8387 |   5821 |      121765 |         62% |    1.56 |   0% |   1.29 |    24%
L26  |  3 |   8147 |   5627 |      129912 |         62% |    1.55 |   0% |   1.00 |    25%
L27  |  3 |   7480 |   5118 |      137392 |         62% |    1.61 |   0% |   1.20 |    25%
L28  |  3 |   9728 |   6582 |      147120 |         62% |    1.64 |   0% |   1.27 |    25%
L29  |  3 |   9149 |   6703 |      156269 |         65% |    1.49 |   0% |   1.31 |    28%
L30  |  3 |   8825 |   5639 |      165094 |         64% |    1.70 |   0% |   1.23 |    26%
L31  |  4 |  11912 |  10548 |      177006 |         45% |    2.18 |   0% |   1.00 |    27%
L32  |  4 |   9008 |   6431 |      186014 |         66% |    1.50 |   0% |   1.26 |    28%
L33  |  4 |   7536 |   5422 |      193550 |         65% |    1.52 |   0% |   1.27 |    29%
L34  |  4 |   7640 |   5295 |      201190 |         64% |    1.59 |   0% |   1.25 |    27%
L35  |  4 |  10444 |   7104 |      211634 |         64% |    1.62 |   0% |   1.25 |    29%
L36  |  4 |  13527 |  11928 |      225160 |         43% |    2.14 |   0% |   1.13 |    28%
L37  |  4 |   8092 |   5718 |      233252 |         64% |    1.57 |   0% |   1.56 |    30%
L38  |  4 |  12814 |   9553 |      246066 |         63% |    1.52 |   0% |   1.96 |    32%
L39  |  4 |  13128 |   9120 |      259194 |         65% |    1.56 |   0% |   1.85 |    35%
L40  |  4 |  12144 |   8095 |      271338 |         64% |    1.63 |   0% |   1.25 |    35%
L41  |  5 |   9433 |   6671 |      280771 |         61% |    1.57 |   0% |   1.00 |    38%
L42  |  5 |  14963 |   9235 |      295734 |         54% |    1.93 |   0% |   1.24 |    37%
L43  |  5 |  13012 |   9018 |      308746 |         54% |    1.74 |   0% |   1.35 |    37%
L44  |  5 |  12039 |   7508 |      320785 |         53% |    1.86 |   0% |   1.15 |    39%
L45  |  5 |  17074 |  10111 |      337859 |         54% |    1.99 |   0% |   1.17 |    38%
L46  |  5 |  10988 |   9113 |      348847 |         80% |    1.25 |   0% |   1.00 |    37%
L47  |  5 |  15489 |   8895 |      364336 |         54% |    1.98 |   0% |   1.13 |    40%
L48  |  5 |  14464 |   8729 |      378800 |         54% |    1.92 |   0% |   1.16 |    38%
L49  |  5 |  18440 |  10641 |      397240 |         54% |    1.99 |   1% |   1.13 |    39%
L50  |  5 |  19126 |  11888 |      416366 |         54% |    1.89 |   0% |   1.19 |    38%
```
Cột "xu TB" cộng mọi lượt chơi của màn, kể cả lượt thua.

### 4.4 Với vật phẩm (`SIM_BOOSTERS=1`, `average`)

Người chơi không trả tiền: có vật phẩm trong kho thì dùng, hết thì mua bằng kim cương kiếm trong game.

```
ch | thắng lần 1 TB | lần thử TB | xu cuối chương | kim cương | đủ sao mở | vật phẩm/màn
 1 |            86% |       1.18 |           5924 |      33.0 |      100% |         0.47
 2 |            74% |       1.33 |           9294 |      17.4 |       87% |         0.29
 3 |            62% |       1.61 |          10568 |      13.7 |       86% |         0.25
 4 |            61% |       1.67 |          10561 |      15.7 |       79% |         0.31
 5 |            58% |       1.79 |          18218 |      12.2 |       84% |         0.28
```
Từ chương 2 trở đi, người chơi dùng khoảng 1 vật phẩm mỗi 3–4 màn. Vật phẩm chủ yếu giúp chương 1 (vì có quà tặng vật
phẩm từ L4) và chương 2 (+3 điểm).

## 5. Mục tiêu đạt / chưa đạt (`average`, 200 người chơi giả)

| Mục tiêu | Kết quả | |
|---|---|---|
| Chương 1 thắng lần đầu ≈ 80% | 82% | đạt |
| Chương 2 ≈ 68–74% (nằm giữa chương 1 và chương 4) | 71% | đạt |
| Không màn nào trong L11–20 dưới ~45% | thấp nhất L12 50%, các màn khác 68–75% | đạt |
| Chương 3 nằm giữa chương 1 và chương 4 | 61% (dưới chương 4 1 điểm, trong dung sai ±8) | đạt |
| Chương 4 ≈ 60% | 60% | đạt |
| Chương 5 ≤ chương 4 | 57% ≤ 60% | đạt |
| ~70–85% đủ sao mở chương kế ngay sau lượt đầu | chương 2: 87%; chương 3: 82%; chương 4: 76%; chương 5: 80% | chương 2 hơi cao, xem dưới |
| Mở rộng / nhân viên / thiết bị mua trong 1–3 màn, không quá rẻ | trễ 1–3 màn; không mốc nào mua ngay mà dư > 2 × giá | đạt |
| Nâng nhân viên cấp 2 ≤ 3 màn sau khi thuê được | trễ 1–3 màn (cả 10 mốc, 5 nhân viên) | đạt |
| Dụng cụ ≤ 4 màn sau khi mở | trễ 0–4 màn | đạt (`tongs:3`, `goldenOven:4`, `pipingBag:3` vừa chạm 4) |
| Kẹt (thua 10 lần liền) | ≤ 1% mọi màn, cả ba kỹ năng | — |

Các điểm còn lệch hoặc cần chủ dự án quyết định:
1. **Chương 2 có 87% đủ sao**, cao hơn 85% một chút. Sao là số nguyên: 16★ cho 87%, còn 17★ chỉ cho 57%. Tôi chọn 16★ vì
   mục tiêu là không phải cày lại. `SimTargets.starGate` cho phép tới 88% và có ghi lý do.
2. **L12 cố ý khó hơn chương (50%)**. L12 phụ thuộc đồ nhiều nhất: `average` chơi L12 khi chưa thuê thu ngân (thuê sau
   L12). Nếu hạ 1★ để L12 ≈ 71% (khoảng 3800–4000 xu), thì người mới có "bộ đồ kỳ vọng" của `level_balance_test` thắng
   74–84%, và bot 0.3 thắng 50–56%. Hai số này vượt khung test. Vì vậy L12 có mục tiêu riêng 0.50
   (`SimTargets.levelFirstWin`), phần thiếu được bù vào các màn khác (74–75%).
3. **Người chơi khá thiếu xu cuối chương 2.** Người chơi này không chơi lại nên ít xu hơn. Với luật mới, dụng cụ và nâng
   nhân viên cấp 2 được mua đúng lúc. Vì vậy `bigTray:3` (L17) và `cafe_tables` (L18) thường chỉ mua được sau L20: trong
   mô phỏng 50 màn, `bigTray:3` trễ 4 màn. Người chơi này vẫn thắng lần đầu 99% ở chương 2. `progression_sim_test` không
   còn đòi người chơi khá mua kịp các món mở từ L17 trong cửa sổ L1–20.
4. **Màn mục tiêu đếm khách** (L21, 26, 31, 36, 41, 46) cho tỉ lệ thắng 43–80%, vì mốc là số nguyên trong một phân bố hẹp
   (không đổi so với lần đầu).
5. **Thu nhập khi vắng nhà**: với `SIM_OFFLINE_HOURS=8`, xu cuối chương 5 của `average` khoảng 187 nghìn (trước khoảng 116
   nghìn, vì nâng nhân viên rẻ hơn nên quản lý được nâng sớm hơn). Tỉ lệ thắng gần như không đổi (chương 4: 64%), và không
   mốc nào lệch. Sau L35 không còn gì để mua bằng xu ngoài nâng nhân viên, nên vẫn nên có thêm món để tiêu xu ở chương 5
   (`staff_training`, `rare_decor` đang "sắp có").

## 6. Test

`test/core/simulate_test.dart` (13 test, khoảng 10 s):
- Kiểm tra dữ liệu gộp: 50 màn, 5 chương, màn cuối chương là màn đặc biệt; `levels.json` vẫn 20 màn; màn nháp không có
  món mới; kiên nhẫn giảm và nhịp khách dày dần qua các chương.
- `SimOptions.fromEnv`.
- Chạy rút gọn đủ mọi bảng (vật phẩm, vắng nhà, CSV, gợi ý mốc sao). Kết quả tất định: cùng seed cho cùng kết quả dù chạy
  1 hay 3 isolate; seed khác cho kết quả khác.
- Mục tiêu với 48 người chơi `average`: chương 1 ≈ 80% và chương 4 ≈ 60% (±8 điểm); chương 2–3 nằm giữa, chương 5 ≤ chương
  4; **mới**: chương 2 trong 68–74%, không màn chương 2 nào dưới 45%, đủ sao mở chương 2–5 trong 70–88% (khoảng của mục
  tiêu ±6 điểm, vì chỉ có 48 người chơi giả); mốc mở rộng / nhân viên / thiết bị ≤ 3 màn, nâng nhân viên cấp 2 ≤ 3 màn,
  dụng cụ ≤ 4 màn (cộng 1 màn dung sai trung vị); không màn nào kẹt quá 5%;
  `deviations(rateSlack: 0.06, lagSlack: 1)` rỗng. Lần chạy test: 84 / 68 / 60 / 60 / 57%, đủ sao 85 / 71 / 69 / 79%.

Các test cân bằng cũ đã sửa cho khớp luật mua và số mới (lý do ghi trong comment của từng test):
- `level_config_test`: `starsToUnlock` chương 2 = 16.
- `level_balance_test`: khung người mới ở chương 2 đổi từ 25–55% thành 25–65%. Trung bình chương 2 được dễ hơn chương 1
  tối đa 6 điểm (trước là 2 điểm).
- `progression_sim_test`: giá nâng nhân viên cấp 2 ≥ 0.25 × xu một màn (trước là 0.4). Thêm điều kiện nâng nhân viên cấp
  2 trong ≤ 3 màn sau khi thuê được (cả người mới và người chơi khá). Người chơi khá không bị kiểm mua kịp / không bỏ lỡ
  với các mục mở từ L17 (chỉ còn ≤ 3 màn trong cửa sổ L1–20).
- `booster_balance_test`, `economy_test` (`Economy` khớp `unlocks.json`): không sửa test, vẫn qua.

## 7. Bản sửa 3 điểm lệch: trước → sau

### 7.1 Kết quả (`average`, 200 người chơi giả)

| Chỉ số | Trước | Sau |
|---|---|---|
| Chương 1 / 2 / 3 / 4 / 5 thắng lần đầu | 82 / 57 / 62 / 60 / 57% | 82 / **71** / 61 / 60 / 57% |
| Màn chương 2 thấp nhất | L12 12% (các màn khác 52–80%) | L12 50% (các màn khác 68–75%) |
| Đủ sao mở chương 2 / 3 / 4 / 5 ngay sau lượt đầu | **3%** / 86 / 62 / 56% | **87** / 82 / 76 / 80% |
| Nâng nhân viên cấp 2: trễ | 7–14 màn | 1–3 màn |
| Dụng cụ: trễ | 0–7 màn | 0–4 màn |
| Mở rộng / nhân viên / thiết bị: trễ | 0–2 màn | 1–3 màn |
| Xu cuối chương 2 / 5 | 9624 / 15957 | 9542 / 17856 |
| Người mới: chương 1 / 2 thắng lần đầu | 61 / 54% | 62 / 64% |

### 7.2 Số đã đổi

`assets/config/levels.json`:

| Mục | Trước → sau |
|---|---|
| chương 2 `starsToUnlock` | 20 → 16 |
| 1★ L12 / L13 / L14 / L15 / L16 | 4600 → 4380 · 4310 → 4320 · 4230 → 4140 · 5090 → 4950 · 4640 → 4410 |
| 1★ L17 / L18 / L19 / L20 | 5040 → 4870 · 4230 → 4000 · 4780 → 4620 · 5080 → 5170 |
| L11 (34 khách), mốc 2★ / 3★ L11–20, nhịp khách, kiên nhẫn | không đổi |

`assets/config/levels_draft.json`: `starsToUnlock` chương 4: 42 → 40, chương 5: 55 → 53 (chương 3 giữ 28). Mốc sao
L21–50 được sinh lại (đa số lệch ≤ 2%; L37–L39 lệch tới 12% ở 2★ / 3★).

`assets/config/unlocks.json`, kèm bản sao giá lò / dụng cụ trong `lib/core/economy.dart`:

| Nhóm | Trước → sau |
|---|---|
| mở rộng / thuê (chương 2) | `oven_2` 12500 → 10500 · `cafe_tables` 12000 → 10000 · `staff_baker` 9000 → 7500 |
| thiết bị (chương 2) | `fastOven` cấp 4 6000 → 5400 · `wideCase` cấp 3 6400 → 5400 · `bigTray` cấp 3 6000 → 5100 |
| lò vùng vàng | cấp 3 1300 → 900 · cấp 4 3000 → 1700 · cấp 5 5000 → 2800 (cấp 2 giữ 500) |
| dụng cụ | `whisk` 600 → 400, 2800 → 1600 · `pipingBag` 1200 → 800, 3200 → 1800 · `tongs` 600 → 400, 2400 → 1400 |
| nâng nhân viên lên cấp 2 (tốc độ / tay nghề) | thu ngân 3000 / 2600 → 1600 / 1400 · thợ bánh 4200 / 3800 → 2600 / 2400 · phục vụ 6500 / 5800 → 3800 / 3400 · thợ bánh 2 7500 / 6800 → 4400 / 4000 · quản lý 9000 / 8000 → 5000 / 4500 |
| cấp 3–5 nhân viên, giá thuê nhân viên chương 1 / 3–4, mở rộng chương 3–4, thiết bị chương 1 | không đổi |

Mã: `simShop` (§1, luật mới), `SimTargets` thêm `chapter2FirstWin` (0.68–0.74), `minLevelFirstWin` (0.45, chương 2),
`starGate` (0.70–0.88), `starGateTarget` (0.78), `maxToolLag` (4), `maxStaffUpgradeLag` (3), `levelFirstWin` ({12: 0.50}),
`draftFirstWin[2]` (0.71). Nhóm dụng cụ / nâng NV giờ tính vào mục tiêu trễ, nhưng "quá rẻ" ở hai nhóm này chỉ báo cáo
(△). `calibrateStars` nhận màn có p riêng. Thêm `suggestStarGates` và `SIM_CALIBRATE_FROM`. Bảng chương có thêm cột "sao
TV / cần", CSV chương có thêm `stars_median_before` và `stars_to_unlock`. Hàm `deviations` có dung sai tuỳ chọn.

**Không đổi định dạng lưu game.** Chương mở được tính lại mỗi lần từ `totalStars >= starsToUnlock`, nên hạ mốc sao thì
người đã mở chương vẫn mở. Hạ giá không ảnh hưởng món đã mua.

### 7.3 Lý do và các cách đã thử

1. **Nâng nhân viên / dụng cụ mua trễ.** Theo luật cũ, mở rộng, nhân viên và thiết bị luôn được ưu tiên. Món đầu của các
   nhóm này chưa đủ xu thì người chơi để dành, nên dụng cụ và nâng nhân viên chỉ được mua khi không còn gì phải để dành.
   Ở chương 2 có món lớn mở gần như mỗi màn, nên tình huống đó hầu như không xảy ra. Ngoài ra, nâng nhân viên mua món rẻ
   nhất trước, nên cấp 3–5 của thu ngân / thợ bánh chặn cấp 2 của nhân viên mới. Các cách đã thử:
   - "Món rẻ ≤ X% xu hiện có thì mua dù đang để dành" (X = 0.25 / 0.33 / 0.4): với X = 0.4, thiết bị và mở rộng chương 2
     trễ 4–5 màn. Với X = 0.3, dụng cụ vẫn trễ 7–9 màn.
   - Xếp nâng cấp 2 ngay sau thuê nhân viên, giữ thứ tự nhóm: `bigTray:2`, `wideCase:3`, `bigTray:3` trễ 4–5 màn.
   - **Chọn**: một hàng để dành chung, xếp theo level mở (§1). Mở rộng tính sớm hơn 1 level để bàn ghế L18 không phải
     chờ thiết bị L16–L17. Dụng cụ tính muộn hơn 1 level để kệ bánh L5 không bị dụng cụ L3–L4 giành xu (nếu không, người
     chơi khá thắng lần đầu L7 chỉ 60%). Đã thử thêm "thuê nhân viên tính sớm hơn 2 level": thu ngân mua đúng L10,
     nhưng `fastOven:3` trễ 4 màn.
   - Luật mới làm người chơi mua thêm khoảng 10 nghìn xu đồ trong chương 1–2 (trước đây phần này được hoãn sang chương 3).
     Nếu không hạ giá, mở rộng / thiết bị chương 2 trễ 4 màn. Vì vậy tôi hạ giá dụng cụ 31–44%, nâng cấp 2 37–47%
     (≈ 0.3 × xu một màn), và giá mở rộng / thuê / thiết bị chương 2 10–17%. Tỉ lệ giá / thu nhập vẫn trong khung của
     `progression_sim_test` (mở rộng 1.56–1.63×, thiết bị 0.81–0.94×, thuê 0.91–1.15×).
2. **Chương 2 quá khó.** Mốc 1★ L11–20 được sinh bằng `calibrateStars` (`SIM_CALIBRATE_FROM=10`) với p = 0.71 cho chương
   2, sau khi đã đổi luật mua (vì luật mua đổi bộ đồ lúc vào màn). Tôi lặp tới khi ổn định (3 lần, lệch ≤ 30 xu). Chỉ đổi
   1★; 2★ / 3★ giữ nguyên để giữ mục tiêu người chơi khá của `level_balance_test` (sao TB 1.8–2.5). L11 là màn đếm khách:
   34 khách cho 68%, nên giữ nguyên. Vì chương 2 dễ hơn nên người chơi chơi lại ít hơn và kiếm ít xu hơn (thu nhập chương
   2 giảm từ khoảng 78 nghìn xuống 63 nghìn). Đây là lý do thứ hai phải hạ giá chương 2.
3. **Mốc sao mở chương.** `starsToUnlock` chọn theo phân bố tổng sao thực tế của `average` ngay khi qua hết chương trước
   lần đầu (trung vị: 17 / 29 / 42 / 55), nhắm khoảng 78% đủ sao. Chương 3 giữ 28★ (82%).

## 8. GĐ8 — cân bằng lại với dữ liệu thật 50 màn (8C)

Ngày 30/10/2026, cập nhật sau quality-gate GĐ8. Đặc tả: `docs/v2/phase8-spec.md` §3. Từ GĐ8, `levels.json` có đủ L1–L50
(chương 3–5 lấy từ bản nháp, menu có 8 món mới, giá 58–98 xu). Không còn `levels_draft.json` / `mergeLevelDraft`: sim đọc
thẳng `levels.json`; `SIM_CALIBRATE_FROM` mặc định 20. Số liệu: `flutter test tool/simulate.dart`, 200 người chơi giả mỗi
kỹ năng, seed 0, không vắng nhà (trừ dòng ghi "vắng nhà 8 giờ").

### 8.1 Trước → sau (`average`)

"Trước" = 8B: menu mới, mốc sao vẫn của bản nháp (sinh cho menu cũ, rẻ hơn), Bí quyết +8 / 16 / 25%.

| Chỉ số | Trước (8B) | Sau (8C) |
|---|---|---|
| Chương 1 / 2 / 3 / 4 / 5 thắng lần đầu | 83 / 70 / 65 / **81** / **93%** | 82 / 71 / 62 / 61 / 62% |
| Màn chương 3–5 thấp nhất | L22 11%, L28 21%, L24 22% | L34 51% (L48 57%; seed 1 / 2: 52 / 53%) |
| Đủ sao mở chương 2 / 3 / 4 / 5 ngay sau lượt đầu | 86 / 81 / **100** / **100%** | 87 / 82 / 75 / 81% |
| Sao TV lúc qua hết chương trước (ch 3 / 4 / 5) | 29 / 47 / 70 | 29 / 41 / 55 |
| Kẹt (thua 10 lần liền) | L28 12% | ≤ 1% mọi màn |
| Vắng nhà 8 giờ/màn: chương 4 / 5 thắng lần đầu | — | 67 / 74% |
| Vắng nhà 8 giờ/màn: xu còn lại sau L50 (sau mua sắm cuối) | — | 5330 (mục tiêu ≤ 60 nghìn) |

### 8.2 Tổng kết chương (sau, không vắng nhà)

| Kỹ năng | Thắng lần đầu ch 1–5 | Đủ sao mở ch 2–5 | Sao TV / cần (ch 2–5) | Xu cuối chương 5 | Xu còn lại sau L50 |
|---|---|---|---|---|---|
| newbie | 62 / 64 / 61 / 57 / 55% | 50 / 60 / 52 / 59% | 16/16 · 28/28 · 40/40 · 53/53 | 17218 | 2837 |
| average | 82 / 71 / 62 / 61 / 62% | 87 / 82 / 75 / 81% | 17/16 · 29/28 · 41/40 · 55/53 | 17068 | 2271 |
| good | 97 / 99 / 93 / 88 / 92% | 100% | 22 · 43 · 61 · 79 | 18926 | 1975 |

Vắng nhà 8 giờ mỗi màn (`SIM_OFFLINE_HOURS=8`, `average`): 82 / 71 / 62 / 67 / 74%, đủ sao mở chương 5 89%, xu cuối chương
5 (trước lần mua sắm cuối) khoảng 61,6 nghìn, xu còn lại sau mua sắm cuối 5330.

### 8.3 Mốc mở khoá chương 3–5 (`average`)

| Mốc | Mở sau L | Giá | Màn TV mua | Trễ |
|---|---|---|---|---|
| `staff_waiter` | 25 | 13000 | 26 | 1 |
| `staff_baker_2` | 28 | 15000 | 29 | 1 |
| `garden` | 30 | 16000 | 31 | 1 |
| `staff_manager` | 32 | 18000 | 33 | 1 |
| `floor_2` | 35 | 20000 | 36 | 1 |
| nâng nhân viên chương 3–4 lên cấp 2 | 25–32 | 3400–5000 | | 1–2 |
| Bí quyết của bà (`recipe_secrets`) | 41 | 3600–58800 / bậc | từ 41 | — |

Chương 1–2 không đổi so với §4.2, trừ `eq:bigTray:3` và `cafe_tables` (xem §8.6).

### 8.4 Số đã đổi

`assets/config/levels.json`:

| Mục | Trước (bản nháp) → sau |
|---|---|
| `starsToUnlock` chương 3 / 4 / 5 | 28 / 40 / 53 — giữ (đã thử 39 / 52: 82–85% / 87–93%, sát trần) |
| Mốc sao màn mục tiêu xu L22–L50 | sinh lại bằng `SIM_CALIBRATE=1` (lặp tới khi lệch ≤ 2% ở 1★), p = 0.62 / 0.60 / 0.57 cho chương 3 / 4 / 5, sàn p của màn xu 0.52. 1★ tăng 4–55% ở đa số màn (L22, L24, L28, L32 giảm 4–9%) vì menu có món mới đắt hơn |
| Màn mục tiêu đếm khách | L21 41 khách, `durationSec` 204 → 207 · L31 43 khách, 204 → 207 · L36 51 → 50 khách (2★ / 3★ cùng dịch) · L26, L41, L46 giữ |
| L1–L20, nhịp khách / kiên nhẫn chương 3–5 | không đổi |

`assets/config/unlocks.json`: Bí quyết của bà +8 / 16 / 25% → **+5 / 10 / 15%** (hệ số giá xu ×120 / 300 / 600 giữ).
Giá 8 món mới (64 / 68 / 58 / 74 / 82 / 86 / 92 / 98) giữ nguyên.

Mã: `SimTargets` thêm `chapter3FirstWin` (0.62), `chapter5FirstWin` (0.57), `maxEndSurplus` (60000, khi vắng nhà ≥
`surplusOfflineHours` = 8 giờ), `minCalibratedFirstWin` (0.52, sàn p của màn xu khi sinh mốc sao; trước 0.40);
`floorChapters` = {2, 3, 4, 5} (không màn nào dưới 45%). `deviations` kiểm thêm các mục này; `BalanceReport.endSurplus`;
bảng chương in thêm "xu còn lại sau L50". Bot mua Bí quyết của bà sau nâng nhân viên, trước trang trí (món trong menu màn
kế trước). `simulate_test`: bỏ 4 test tạm bỏ qua ở 8B, thêm kiểm chương 3 / 5, sàn 45% chương 3–5 và xu dư khi vắng nhà
8 giờ.

### 8.5 Còn lệch / cần quyết

Mục 1 và 2 đã được chủ dự án quyết (xem §8.6).

1. **`eq:bigTray:3` trễ 4 màn** (mở sau L17, mua trung vị sau L21; tối đa 3). Không do giá: trong hàng để dành,
   `cafe_tables` (L18, mở rộng tính sớm 1 level) đứng trước `bigTray:3` cùng mốc 17, nên người chơi dồn xu mua bàn ghế trước
   (khoảng sau L20) rồi mới mua khay. Đã thử:
   - hạ giá cấp 3 5100 → 4700 (−8%): vẫn trễ 4 màn, và tỉ lệ giá / thu nhập 0.74 dưới khung 0.8–1.5 của
     `progression_sim_test` → bỏ, giữ 5100;
   - mở cấp 3 sau L18: hết trễ (2 màn) nhưng bộ đồ kỳ vọng L19–L20 thiếu khay, `level_balance_test` chương 2 (bot 0.75)
     sao TB 1.78 < 1.8 → bỏ;
   - cùng mốc thì món rẻ trước (thay vì theo nhóm): hết trễ (`bigTray:3` 2, `cafe_tables` 3 màn), nhưng
     `progression_sim_test` lệch nhẹ (người chơi khá mua mở rộng TB 2.04 level > 2.0; thiết bị TB 3.1 > 3) → chưa áp.
   `simulate_test` có dung sai +1 màn nên vẫn đạt. Nếu chấp nhận nới hai ngưỡng trên thêm 0.1–0.2 level thì dùng cách thứ ba.
2. **Vắng nhà 8 giờ mỗi màn làm chương 5 dễ hơn** (74% so với 62% ở chế độ mặc định; đủ sao mở chương 5 89%). Giảm Bí
   quyết xuống +5 / 10 / 15% chưa đủ. Đo thêm (cùng mốc sao): +3 / 6 / 10% → 68%; gần như 0 (+1 / 2 / 3%) → 66%. Phần còn lại
   (khoảng +5 điểm) do thu nhập quản lý khi vắng nhà dồn vào nâng nhân viên cấp 3–5, không do bí quyết. Đề xuất (cần chủ dự
   án chọn): (a) chấp nhận — người chơi vắng nhà 8 giờ sau mỗi màn là trường hợp cực đoan, mục tiêu thắng lần đầu đo ở chế
   độ mặc định như GĐ7; (b) +3 / 6 / 10% và mục tiêu riêng cho chế độ vắng nhà (chương 5 ≤ 70%); (c) giới hạn thu nhập quản
   lý theo chương (`staff_manager` `params`).
3. **Màn đếm khách** (L21, 26, 31, 36, 41, 46) 66–83%: mốc nguyên trong phân bố hẹp (L21: 41 khách ở 204 giây 47%, 40
   khách 88%; kéo dài 3 giây và giữ 41 khách → 79%). Dễ hơn trung bình chương, đổi lại không màn nào dưới sàn 45%.
4. Người mới: chương 5 thắng lần đầu 55%, đủ sao mở chương 2–5 chỉ 50–60% (không chơi lại lấy sao). Như GĐ7, mục tiêu chỉ
   đặt cho `average`.

### 8.6 Quyết định của chủ dự án (30/10/2026) và kết quả

1. **Cùng mốc thì mua món rẻ trước** (cách thứ ba ở §8.5 mục 1). `simShop` (`lib/core/sim/progression_sim.dart`, dùng
   chung cho `tool/simulate.dart` và `test/core/progression_sim.dart`): hàng để dành xếp theo mốc (level mở + lệch), cùng
   mốc thì **giá thấp trước**, cùng giá mới theo thứ tự nhóm (trước: thứ tự nhóm trước, giá sau). Giữ giá `bigTray` cấp 3
   5100. `progression_sim_test` nới hai ngưỡng của người chơi khá (bot 0.75), mỗi ngưỡng +0.2 level, comment "GĐ8: cùng mốc
   mua món rẻ trước — chủ dự án duyệt":
   - mở rộng: trễ TB 0.5–**2.0 → 2.2** level (`oven_2` 2.04);
   - thiết bị mới: trễ TB ≤ **3 → 3.2** level (`wideCase:3` 3.125).
2. **Vắng nhà 8 giờ: chọn (a), chấp nhận.** Mục tiêu thắng lần đầu theo chương chỉ đo ở chế độ mặc định như GĐ7. Giữ Bí
   quyết +5 / 10 / 15%. Mã: khi `SIM_OFFLINE_HOURS` > 0, `BalanceReport.deviations` không tính các mục tiêu theo chương
   (thắng lần đầu chương 1–5, thứ tự chương, % đủ sao mở chương); các mục này in ở phần "Tham khảo" với ghi chú "chỉ tham
   khảo: vắng nhà … giờ/màn, mục tiêu theo chương chỉ đo ở chế độ mặc định". Sàn 45% mỗi màn, trễ mốc và xu dư sau L50
   vẫn tính. `simulate_test` (test vắng nhà 8 giờ) kiểm thêm: danh sách lệch không có mục theo chương.

Số liệu (`average`, 200 người chơi giả, seed 0):

| Chỉ số | Trước (8C, theo nhóm) | Sau (rẻ trước) |
|---|---|---|
| `eq:bigTray:3` (mở sau L17): màn TV mua / trễ | 21 / **4** | 19 / 2 |
| `cafe_tables` (mở sau L18): màn TV mua / trễ | 20 / 2 | 21 / 3 |
| Chương 1 / 2 / 3 / 4 / 5 thắng lần đầu | 82 / 71 / 62 / 61 / 62% | 82 / 70 / 63 / 62 / 61% |
| Màn chương 3–5 thấp nhất | L34 51% (L48 57%) | L33, L35, L40 55% (L48 58%) |
| Đủ sao mở chương 2 / 3 / 4 / 5 | 87 / 82 / 75 / 81% | 86 / 80 / 75 / 81% |
| Xu cuối chương 5 / xu còn lại sau L50 | 17068 / 2271 | 17050 / 2617 |
| Lệch mục tiêu (bảng `simulate`) | 1 (`bigTray:3` trễ 4) | 0 |
| Vắng nhà 8 giờ: chương 1–5 thắng lần đầu | 82 / 71 / 62 / 67 / 74% | 82 / 70 / 63 / 68 / 74% (chỉ tham khảo) |
| Vắng nhà 8 giờ: đủ sao mở chương 5 / xu cuối chương 5 / xu còn lại sau L50 | 89% / ~61,6 nghìn / 5330 | 89% / 61191 / 4931 (mục tiêu ≤ 60 nghìn) |
| Vắng nhà 8 giờ: lệch mục tiêu | 2 (chương 5 74%, đủ sao chương 5 89%) | 0 (2 mục chuyển sang tham khảo) |

**Còn lệch, cần chủ dự án quyết:** lần thử ở §8.5 chưa thấy vì test "mở rộng" dừng ở lỗi đầu tiên (`oven_2`). Sau khi
nới hai ngưỡng trên, cùng test lộ thêm: người mới (`BotSkill.newcomer`, 24 lượt L1→L20) **chưa mua `cafe_tables` trước hết
L20 ở 7/24 lượt** (`newcomer.missing == 0` hỏng; trễ TB vẫn 2.0 ≤ 3). Người mới phải dồn 15100 xu cho khay cấp 3 + bàn ghế
trong L17–L20; mua khay trước thì bàn ghế sang L21. Hạ giá bàn ghế 10000 → 9400 (tỉ lệ 1.51×, sát sàn 1.5) vẫn 7/24 → không
do giá. Trong mô phỏng 50 màn, `newbie` mua `cafe_tables` trung vị sau L20 (trễ 2), `average` sau L21 (trễ 3) — trong mục
tiêu. Lựa chọn: (a) với mốc mở từ L17 (`late`), người mới chỉ kiểm trễ TB ≤ 3, bỏ kiểm "không ai bỏ lỡ trong L1→L20" (đã
kiểm ở `simulate_test` 50 màn); (b) quay lại thứ tự theo nhóm (`bigTray:3` trễ 4).
