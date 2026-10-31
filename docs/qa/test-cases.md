# Sugarleaf Bakery V2 — Bộ test case

Nhánh `v2`. Số liệu kết quả mong đợi lấy từ `assets/config/levels.json`, `unlocks.json`, `monetization.json`, `lib/core/economy.dart`,
`lib/core/level/level_session.dart`, `lib/core/game_state.dart`, `lib/core/monetization/booster.dart`, `lib/core/catalog.dart`.
Kế hoạch: `docs/qa/test-plan.md`. Checklist máy thật: `docs/qa/manual-checklist.md`.

**Quy ước**
- Ưu tiên: **P1** = chặn phát hành (crash, mất dữ liệu, sai tiền, kẹt tiến trình); **P2** = chức năng quan trọng; **P3** = hoàn thiện.
- Cột cuối: **Tự động** (ghi file test có sẵn, hoặc "cần viết" → `test/<khu>/qa_*` / `integration_test/`), **Thủ công**, hoặc cả hai.
- "Ván mới" = xoá dữ liệu (Cài đặt → Xoá dữ liệu, hoặc gỡ cài đặt) → coins 100, gems 5 (`Economy.startCoins/startGems`).
- Công thức một lượt bán (khách vãng lai): `round((giá × payMult[sao] + tip) × comboMult)`; payMult {1:0.5, 2:0.7, 3:0.85, 4:1.0,
  5:1.1}; tip = giá × tipRate {3:0.10, 4:0.20, 5:0.35} × (1 nếu kiên nhẫn ≥ 50%, 0.5 nếu 25–50%, 0 nếu < 25%) × (1 + %tip cộng thêm);
  comboMult = 1 + 0.1 × min(combo − 1, 10) (tối đa ×2.0). Giá cupcake vani = 30 xu.

## Tóm tắt

| Nhóm | Số case | P1 | P2 | P3 |
|---|---|---|---|---|
| SMK Smoke | 10 | 10 | 0 | 0 |
| GP Gameplay trong màn | 32 | 18 | 12 | 2 |
| PRG Tiến trình & mở khoá | 22 | 10 | 10 | 2 |
| ECO Kinh tế & cân bằng | 18 | 6 | 9 | 3 |
| SAV Lưu dữ liệu | 16 | 9 | 6 | 1 |
| ADS Quảng cáo & IAP | 22 | 10 | 11 | 1 |
| UI Giao diện & đa ngôn ngữ | 18 | 5 | 9 | 4 |
| PRF Hiệu năng | 10 | 4 | 4 | 2 |
| EDG Trường hợp biên | 20 | 7 | 10 | 3 |
| **Tổng** | **168** | **79** | **71** | **18** |

---

## 1. Smoke (SMK)

| ID | Nhóm | Tiền điều kiện | Các bước | Kết quả mong đợi | Ưu tiên | Tự động/Thủ công |
|---|---|---|---|---|---|---|
| SMK-01 | Smoke | APK debug mới build, máy chưa cài | Cài APK, mở app | App mở không crash, màn ngang, không đỏ lỗi; vào cảnh mở đầu (lần đầu) | P1 | Thủ công + Tự động (integration_test, cần viết) |
| SMK-02 | Smoke | Ván mới | Xem cảnh mở đầu tới hết (~22 s) | 4 cảnh: bếp → tủ kính → cửa (bảng lật "Mở cửa", chuông) → logo; xong vào thẳng thẻ Sẵn sàng L1 | P1 | Tự động (`test/ui/intro_test.dart`) + Thủ công |
| SMK-03 | Smoke | Ván mới | Ở cảnh mở đầu bấm **Bỏ qua** | Vào thẳng L1; `introSeen = true` (mở lại app không thấy intro dài) | P1 | Tự động (`intro_test.dart`) |
| SMK-04 | Smoke | Đã xem intro | Đóng hẳn app, mở lại | Intro ngắn 4 s (tủ kính + logo) rồi tự sang bản đồ; chạm bất kỳ → bản đồ ngay | P1 | Tự động (`intro_test.dart`) + Thủ công |
| SMK-05 | Smoke | Ván mới, ở thẻ Sẵn sàng L1 | Bấm Bắt đầu, làm theo hướng dẫn, chơi hết 120 s | Hướng dẫn L1 chạy đủ bước; hết giờ → màn kết quả có sao, xu, khách hài lòng/bỏ đi | P1 | Thủ công + Tự động (integration_test, cần viết) |
| SMK-06 | Smoke | Vừa thắng L1 (≥ 6 khách) | Ở màn kết quả bấm Bản đồ | Bản đồ chương 1: sao bay vào nút L1, ổ khoá L2 rơi, L2 ở trạng thái "đang tới" | P1 | Tự động (`test/ui/level_map_test.dart`) |
| SMK-07 | Smoke | Đã thắng L1 | Đóng app (vuốt khỏi đa nhiệm), mở lại | Sao L1, xu, L2 mở vẫn còn | P1 | Thủ công + Tự động (`save_test.dart`) |
| SMK-08 | Smoke | Ở bản đồ | Mở lần lượt: Nhiệm vụ, Quà, Sổ công thức, Nâng cấp, Trang trí, Cửa hàng, Thẻ mùa, Cài đặt; mỗi màn bấm Back | Mỗi màn mở và quay về bản đồ, không crash, không chồng màn | P1 | Tự động (`test/ui/screens_test.dart`, `navigation_guard_test.dart`) + Thủ công |
| SMK-09 | Smoke | Bất kỳ | Cài đặt → đổi ngôn ngữ en ↔ vi | Toàn bộ chữ đổi ngay, không còn chuỗi khoá thô | P1 | Tự động (`menu_settings_test.dart`) + Thủ công |
| SMK-10 | Smoke | Build web release | Mở `build/web` trên Chrome | App chạy như trên Android (intro → L1), không lỗi console | P1 | Thủ công |

## 2. Gameplay trong màn (GP)

| ID | Nhóm | Tiền điều kiện | Các bước | Kết quả mong đợi | Ưu tiên | Tự động/Thủ công |
|---|---|---|---|---|---|---|
| GP-01 | Gameplay | L1 (tutorial đã xong), vừa Bắt đầu | Quan sát tủ kính | Tủ 3 ô, có sẵn 3 cupcake vani 3★ (`startStock` 3) | P1 | Tự động (`level_session_test.dart`) |
| GP-02 | Gameplay | L1 | Quan sát khách đầu tiên | Khách đầu tới sau ~1.5 s; L1 khoảng cách 14 s → 10 s, cao điểm từ 85% thời gian (7 s/khách) | P2 | Tự động (`level_session_test.dart` SpawnCurve) |
| GP-03 | Gameplay | Khách ở quầy muốn món có trong tủ | Chạm khách | Bán được: lấy bánh sao cao nhất của món đó, khách rời vui, +xu theo công thức, số khách +1 | P1 | Tự động (`level_session_test.dart`) + Thủ công |
| GP-04 | Gameplay | Khách ở quầy muốn món tủ không có | Chạm khách | Không bán, khách lắc nhẹ (`notInCase`), không mất bánh | P1 | Tự động |
| GP-05 | Gameplay | Khách đang trong hàng chờ (chưa tới quầy), không có phục vụ bàn | Chạm khách | Không bán được (chỉ bán khách ở quầy) | P2 | Tự động |
| GP-06 | Gameplay | Quầy 3 chỗ + hàng chờ, `maxQueue` 5 | Không phục vụ, để khách dồn | Tổng đứng quầy + chờ tối đa 5; khách thứ 6 quay đi ngay ở cửa, `lost +1`, combo về 0 | P1 | Tự động (`level_session_test.dart`) |
| GP-07 | Gameplay | Khách ở quầy, L1 kiên nhẫn 40 s | Không phục vụ | Vòng kiên nhẫn bạc hà → vàng → đỏ; ở quầy giảm 100%, trong hàng chờ 50%; về 0 → khách bỏ đi, `lost +1`, combo về 0 | P1 | Tự động |
| GP-08 | Gameplay | Vừa bán 1 khách | Bán khách thứ 2 trong ≤ 6 s; khách thứ 3 sau > 6 s | Lần 2: combo ×1.1; lần 3: combo về 1 (×1.0); HUD hiện combo | P1 | Tự động |
| GP-09 | Gameplay | Combo đang chạy | Bán liên tục 12 khách, mỗi lần cách < 6 s | comboMult tăng 0.1 mỗi lần, dừng ở ×2.0 từ lượt bán thứ 11 | P2 | Tự động (cần viết qa_) |
| GP-10 | Gameplay | Đầu màn, khu chuẩn bị trống | Chạm thẻ món ở cột trái | Mẻ mới vào trạm Khuôn; chạm thẻ thứ 2 khi khu chuẩn bị bận → không nhận | P1 | Tự động + Thủ công |
| GP-11 | Gameplay | Mẻ ở trạm Khuôn (3 khuôn: 1 đúng + 2 nhiễu) | Chọn khuôn sai, rồi khuôn đúng | Khuôn sai: ở lại, đếm lỗi (trừ điểm); khuôn đúng → sang Trộn | P2 | Tự động |
| GP-12 | Gameplay | Mẻ ở trạm Trộn | Xoay ngón ~1 vòng quanh âu rồi nhấc tay | Sang Lò; trộn đúng 1.0 vòng được điểm cao, lệch nhiều điểm thấp | P1 | Thủ công + Tự động (`test/game/logic_test.dart`) |
| GP-13 | Gameplay | Mẻ trong lò (ovenSec 7 s, chưa nâng cấp) | Chạm lò đúng lúc kim ở vạch vàng | Kim tới `bakeTarget` đúng 7 s; lấy trong vùng hoàn hảo (±5%) → điểm nướng tối đa, `perfectBakes +1` | P1 | Tự động (`level_session_test.dart`) + Thủ công |
| GP-14 | Gameplay | Mẻ trong lò | Không chạm | Kim chạy tới 1.0 → tự lấy ra, mẻ cháy, sự kiện `burnt`, sao thấp | P1 | Tự động |
| GP-15 | Gameplay | Mẻ đã nướng, khu hoàn thiện đang bận | Chạm lò | Mẻ dừng nướng, nằm chờ trong lò (không cháy thêm) tới khi khu hoàn thiện trống | P2 | Tự động |
| GP-16 | Gameplay | Mẻ ở trạm Kem | Quẹt phủ kem theo đường gợi ý | % phủ quyết định điểm; xong sang Topping | P2 | Thủ công |
| GP-17 | Gameplay | Mẻ ở trạm Topping (1 hũ đúng + 1 nhiễu) | Chạm hũ đúng 3 lần | Tự sang Hộp sau lần thứ 3; chạm hũ nhiễu nhiều nhất → bánh ghi topping nhiễu, sao thấp hơn | P2 | Tự động (`booster_session_test.dart`) |
| GP-18 | Gameplay | Mẻ ở trạm Hộp | Chọn hộp đúng | 3 bánh (batchSize 3) cùng sao vào tủ: vào ô cùng món còn chỗ, không thì ô trống | P1 | Tự động |
| GP-19 | Gameplay | Tủ đầy (mọi ô đầy hoặc khác món, sức chứa 6/ô) | Hoàn tất trạm Hộp | Báo "Tủ đầy", mẻ nằm chờ ở trạm Hộp; bán bớt → mẻ tự vào tủ | P1 | Tự động |
| GP-20 | Gameplay | Đang chuẩn bị mẻ | Bấm huỷ mẻ | Mẻ bị bỏ, khu chuẩn bị trống, chạm thẻ món mới được | P3 | Tự động |
| GP-21 | Gameplay | L2, giây 40 | Chờ ông Hòa tới chỗ đặc biệt, chạm ông | Màn tự dừng (giờ, kiên nhẫn không chạy); lần đầu chiếu cảnh `hoa1` → vé đơn → 6 trạm đầy đủ → thẻ kết quả | P1 | Tự động (`level_session_test.dart`) + Thủ công |
| GP-22 | Gameplay | Vừa xong đơn đặc biệt | Bấm tiếp ở thẻ kết quả | Xu = (tiền + tip) × 2.0 cộng vào màn; `specialsDone +1`; giờ chạy tiếp | P1 | Tự động |
| GP-23 | Gameplay | Khách đặc biệt đang chờ (90 s) | Ở vé đơn bấm "Để sau"; hoặc đang làm 6 trạm bấm Back → xác nhận thoát | Khách vẫn chờ, giờ chạy lại; hết 90 s kiên nhẫn → khách rời, `specialsMissed +1`, không mất combo | P2 | Tự động (`cancelSpecial`) |
| GP-24 | Gameplay | L10 (mục tiêu đơn đặc biệt, mốc 2/3/4) | Làm đơn Kenji (giây 20) chỉ đạt 2★ | Đơn tính `specialsDone` nhưng **không** tính vào mục tiêu (chỉ ≥ 3★) | P1 | Tự động (`level_session_test.dart`) |
| GP-25 | Gameplay | L10 | Phục vụ < 19 khách tới giây 115 | Lượt ghé ông Hòa bị bỏ (`specialsSkipped +1`), toast báo tên khách; lượt Linh (≥ 26 khách trước 140 s), VIP (≥ 41 khách trước 170 s) xét tiếp | P2 | Tự động (bySec) + Thủ công |
| GP-26 | Gameplay | Bất kỳ màn mục tiêu xu, đã vượt mốc 3★ trước giờ | Tiếp tục chơi | Màn **không** kết thúc sớm; chạy tới hết giờ | P2 | Tự động |
| GP-27 | Gameplay | Hết giờ, chưa đạt 1★, còn lượt rewarded | Hộp "Thêm 30 giây?" → Xem quảng cáo | Quảng cáo giả 2 s → +30 s, chơi tiếp; hết giờ lần 2 → không hỏi lại, vào kết quả | P1 | Tự động (`level_screens_test.dart`) + Thủ công |
| GP-28 | Gameplay | Hết giờ, đã đạt ≥ 1★ | — | Không hỏi +30 giây; vào thẳng kết quả (thắng) | P2 | Tự động |
| GP-29 | Gameplay | Đang chơi | Bấm ⏸ → Tiếp tục / Chơi lại / Thoát | Tạm dừng: giờ, kiên nhẫn, lò đứng yên. Chơi lại: màn mới từ đầu. Thoát: về bản đồ, **không** cộng xu lượt đó | P1 | Tự động + Thủ công |
| GP-30 | Gameplay | Ván mới, L1–L3 lần đầu | Chơi L1 (basics), L2 (combo), L3 (patience) | Bước chặn: không sinh khách, kiên nhẫn và đồng hồ dừng; tay chỉ đúng mục tiêu; xong lưu `tutorialsDone`; chơi lại không hiện; thoát giữa chừng → lần sau hiện lại từ đầu | P1 | Tự động (`tutorial_test.dart`, `tutorial_level_test.dart`) |
| GP-31 | Gameplay | Đã thuê thu ngân Nora (cấp 1) | Chơi màn có khách ở quầy, món có trong tủ | Nora bán 1 khách mỗi 3.2 s (khách đứng lâu nhất), tính combo, +4% tip; thợ Bảo (cấp 1) làm mẻ món khách đang cần mỗi 24 s, cho 3 bánh vào tủ; đơn đặc biệt nhân viên không đụng | P2 | Tự động (`staff_test.dart`, `level_staff_test.dart`) |
| GP-32 | Gameplay | Đã mua `cafe_tables` + thuê Theo | Chơi màn đông khách | Theo bán khách trong hàng chờ mỗi 4 s; kiên nhẫn hàng chờ giảm chậm hơn 5% | P3 | Tự động (`staff_test.dart`) |

## 3. Tiến trình & mở khoá (PRG)

| ID | Nhóm | Tiền điều kiện | Các bước | Kết quả mong đợi | Ưu tiên | Tự động/Thủ công |
|---|---|---|---|---|---|---|
| PRG-01 | Tiến trình | Ván mới | Mở bản đồ | Chỉ L1 mở; chương 1 mở; chương 2–5 khoá | P1 | Tự động (`level_progress_test.dart`) |
| PRG-02 | Tiến trình | Chưa qua L1 | Chạm nút L2 | Toast "khoá", không vào màn | P1 | Tự động (`level_map_test.dart`) |
| PRG-03 | Tiến trình | L1 | Kết thúc L1 với 5 khách (dưới mốc 6) | Thua: 0 sao, L2 vẫn khoá, vẫn nhận xu đã kiếm, `plays +1`, `firstWin` = false mãi | P1 | Tự động |
| PRG-04 | Tiến trình | Đã thắng L1 1★ | Chơi lại L1 đạt 3★ (≥ 10 khách), rồi lại 1★ | Sao lưu = max (3), best = max, plays tăng | P1 | Tự động |
| PRG-05 | Tiến trình | Đã qua L10 nhưng tổng sao = 15 | Mở trang chương 2 | Chương 2 khoá: tranh mờ + ổ khoá + "Cần 16 sao — bạn đang có 15" + gợi ý chơi lại màn ít sao | P1 | Tự động (`level_map_test.dart`) |
| PRG-06 | Tiến trình | Tổng sao ≥ 16 nhưng chưa qua L10 | Mở trang chương 2 | Vẫn khoá (cần qua màn cuối chương trước) | P1 | Tự động (`level_progress_test.dart`) |
| PRG-07 | Tiến trình | Đủ 15 sao, chưa thắng L10 | Thắng L10 làm tổng sao ≥ 16 | Hộp "Chương 2 đã mở!", bản đồ cuộn sang chương 2, L11 mở; +12 kim cương (hết chương lần đầu) | P1 | Tự động |
| PRG-08 | Tiến trình | Tiến trình đủ | Kiểm mốc mở chương 3/4/5 | Cần 28 / 40 / 53 sao + qua L20 / L30 / L40 | P2 | Tự động (`level_config_test.dart`) |
| PRG-09 | Mở khoá | Vừa thắng L5 lần đầu | Về bản đồ | Thẻ "Mở khoá mới!" (Kệ bánh nhiều tầng) + "Xem" / "Để sau"; nút Nâng cấp có chấm đỏ | P2 | Tự động (`upgrades_unlocks_test.dart`) |
| PRG-10 | Mở khoá | Đã qua L5, xu ≥ 4200 | Nâng cấp → Mở rộng tiệm → Kệ bánh nhiều tầng → Mua | Trừ 4200 xu; trạng thái "Đã có"; màn sau tủ thêm 1 ô, kệ bánh hiện trong tiệm | P1 | Tự động (`unlock_test.dart`, `level_shop_setup_test.dart`) |
| PRG-11 | Mở khoá | Đã qua L5, xu 4199 | Bấm Mua kệ bánh | Không mua, báo không đủ xu, xu giữ nguyên | P1 | Tự động |
| PRG-12 | Mở khoá | Chưa qua L12 | Xem thẻ Lò thứ hai | "Qua màn 12 để mở", không mua được | P2 | Tự động |
| PRG-13 | Mở khoá | Đã qua mốc | Mua lần lượt: oven_2 (L12, 10500), cafe_tables (L18, 10000), garden (L30, 16000), floor_2 (L35, 20000) | oven_2: 2 lò trong bếp; cafe_tables: kiên nhẫn ×1.15, hàng +2, bàn ghế hiện; garden: tip +5%, hàng +2; floor_2: +1 chỗ quầy, hàng +3, khách tới thường hơn 10% | P2 | Tự động (`unlock_test.dart`) + Thủ công (nhìn tiệm) |
| PRG-14 | Mở khoá | Đã qua L22 | Xem Bếp rộng (`kitchen_2`) | Hiện "Sắp có", không mua được (xem test-plan §8 điểm 1) | P2 | Tự động |
| PRG-15 | Mở khoá | Đã qua L41 / L45 | Xem Đào tạo nhân viên, Bộ trang trí hiếm | Cả hai "Sắp có" | P3 | Tự động |
| PRG-16 | Nhân viên | Đã qua L10, xu ≥ 5000 | Tab Nhân viên → Thuê Nora | Trừ 5000 xu, Nora cấp Tốc độ 1 / Tay nghề 1; thẻ Sẵn sàng hiện chân dung Nora | P1 | Tự động (`staff_offline_test.dart`) |
| PRG-17 | Nhân viên | Đã thuê Nora | Nâng Tốc độ lên cấp 2, 3, 4, 5 | Giá 1600 / 3800 / 4600 / 5400; thông số 3.2 → 2.8 → 2.4 → 2.0 → 1.6 s; cấp 5 hiện huy hiệu tối đa, không còn nút | P2 | Tự động |
| PRG-18 | Nhân viên | Đã qua L25, chưa mua `cafe_tables` | Xem thẻ Theo | "Cần có Bàn ghế quán trước", không thuê được; mua bàn ghế → thuê được (13000) | P2 | Tự động (`staff_offline_test.dart`) |
| PRG-19 | Thiết bị | Ván có xu đủ | Nâng Lò nướng nhanh cấp 2/3/4 | Cần qua L3 / L8 / L14, giá 1400 / 3500 / 5400; ovenSec 7 → 6.3 → 5.6 → 5.0 | P2 | Tự động (`unlock_test.dart`) |
| PRG-20 | Thiết bị | Ván có xu đủ | Nâng Khay lớn, Tủ kính rộng, Lò vùng vàng, Phới, Túi bắt kem, Kẹp | Khay: L9 4000 (4 bánh), L17 5100 (5). Tủ: L7 2800 (8/ô), L16 5400 (10). Lò vàng: L2 500, L6 900, L11 1700, L19 2800 (vùng ±5% → ±10%). Phới L4 400, L13 1600. Túi L6 800, L15 1800. Kẹp L3 400, L10 1400 | P2 | Tự động |
| PRG-21 | Bí quyết | Đã qua L41, xu ≥ 3600 | Sổ công thức → Cupcake vani → nâng bậc 1, 2, 3 | Giá 3600 / 9000 / 18000; giá bán +5% / +10% / +15% (30 → 32 → 33 → 35 xu, làm tròn); chưa qua L41 → khoá + dòng giải thích | P2 | Tự động (`phase8b_test.dart`) |
| PRG-22 | Truyện | Thắng L10, L20, L50 lần đầu | Quan sát | Cảnh kết `ch1End` sau L10, `ch2End` sau L20, `finale` sau L50; cảnh mở `ch3Open` L21, `mochi1` L23, `ch4Open` L31, `ch5Open` L41; mỗi cảnh xem 1 lần | P3 | Tự động (`phase8b_test.dart`) + Thủ công |

## 4. Kinh tế & cân bằng (ECO)

| ID | Nhóm | Tiền điều kiện | Các bước | Kết quả mong đợi | Ưu tiên | Tự động/Thủ công |
|---|---|---|---|---|---|---|
| ECO-01 | Kinh tế | Không trang trí, combo 1 | Bán cupcake vani 3★, khách còn ≥ 50% kiên nhẫn | +29 xu (25.5 + 3 = 28.5 → 29) | P1 | Tự động (`level_session_test.dart`) |
| ECO-02 | Kinh tế | Như trên | Bán cupcake vani 5★, kiên nhẫn ≥ 50% | +44 xu (33 + 10.5) | P1 | Tự động (cần viết qa_) |
| ECO-03 | Kinh tế | Như trên | Bán cupcake vani 3★ khi kiên nhẫn 25–50% / < 25% | +27 xu (nửa tip) / +26 xu (không tip) | P2 | Tự động (cần viết qa_) |
| ECO-04 | Kinh tế | Như trên | Bán cupcake vani 1★ / 2★ | +15 / +21 xu (dưới 3★ không tip) | P2 | Tự động (cần viết qa_) |
| ECO-05 | Kinh tế | Combo đang ×2.0 | Bán cupcake vani 5★ | +87 xu (43.5 × 2) | P2 | Tự động (cần viết qa_) |
| ECO-06 | Kinh tế | Trang trí + `garden` + thu ngân tay nghề cao | Bán | Tổng % tip cộng thêm không vượt 40% (`tipBonusCapPct`); trang trí riêng ≤ 30% | P2 | Tự động (`staff_test.dart`) |
| ECO-07 | Kinh tế | Kết thúc màn (thắng hoặc thua) | Về bản đồ | Xu ván = xu cũ + xu của lượt; thoát giữa màn → không cộng | P1 | Tự động (`level_progress_test.dart`) |
| ECO-08 | Kim cương | Ván mới (5 kim cương) | Lần đầu đạt 3★ L1; lần đầu qua L10 | +1 kim cương mỗi màn lần đầu 3★; +12 khi lần đầu qua màn cuối chương; đạt lại 3★ không cộng nữa | P1 | Tự động (`monetization_test.dart`) |
| ECO-09 | Quà đăng nhập | Ngày 1 → 7 liên tiếp (đổi ngày lịch) | Nhận quà mỗi ngày | 50 xu / 80 xu / 3 kim cương / 120 xu / 150 xu / 5 kim cương / 300 xu + 10 kim cương; mỗi ngày nhận 1 lần | P2 | Tự động (`daily_test.dart`) + Thủ công |
| ECO-10 | Nhiệm vụ ngày | Ngày mới | Mở Nhiệm vụ | Đúng 3 nhiệm vụ khác loại; tiến độ cộng từ màn chơi (vd. phục vụ 8 khách → 60 xu; kiếm 250 xu → 2 kim cương); nhận 1 lần | P2 | Tự động (`daily_test.dart`) |
| ECO-11 | Vắng nhà | Đã thuê Cô Hạnh (cấp 1/1); ghi lại xu TB X của 5 lượt chơi gần nhất (bản lưu `offline.recentCoins`; chưa có lượt nào → X = 6000 `fallbackIncome`, chỉ dựng được bằng bản lưu sửa tay / test) | Đóng app 8 giờ, mở lại | Hộp "Khi bạn vắng nhà": vắng 8 giờ, tính 4 giờ (trần cấp 1), xu = round(0.20 × X × 4) (X = 6000 → 4800); "Nhận" cộng 1 lần | P1 | Tự động (`staff_offline_test.dart`) + Thủ công |
| ECO-12 | Vắng nhà | Đã thuê quản lý | Vắng 9 phút / 10 phút | 9 phút: không có hộp; 10 phút: có thu nhập (tỉ lệ × xu TB 5 màn gần nhất × 1/6 giờ) | P2 | Tự động (cần viết qa_) |
| ECO-13 | Vắng nhà | Chưa thuê quản lý | Vắng 8 giờ | Không có hộp vắng nhà | P2 | Tự động |
| ECO-14 | Vắng nhà | Quản lý tay nghề cấp 5 | Vắng 10 giờ | Tính tối đa 8 giờ; hộp ghi rõ đã cắt theo trần | P3 | Tự động |
| ECO-15 | Cân bằng | Máy dev | `flutter test tool/simulate.dart` (mặc định 200 người chơi, 3 kỹ năng) | `average`: thắng lần đầu chương 1–5 ≈ 82 / 70 / 63 / 62 / 61% (±8); không màn < 45%; kẹt ≤ 5%; danh sách lệch mục tiêu = 0 | P1 | Tự động (`tool/simulate.dart`, `simulate_test.dart`) |
| ECO-16 | Cân bằng | Máy dev | Chạy mô phỏng, đọc bảng mốc mở khoá | Mỗi mốc (mở rộng, nhân viên, thiết bị) mua được trung vị trong 1–3 màn sau khi mở; dụng cụ ≤ 4; không mốc "quá rẻ" (dư > 2 lần giá lúc mở) | P2 | Tự động |
| ECO-17 | Cân bằng | Máy dev | `SIM_OFFLINE_HOURS=8 flutter test tool/simulate.dart` | Xu còn lại sau L50 (sau Bí quyết) ≤ 60 nghìn; mục tiêu theo chương chỉ in "Tham khảo" | P3 | Tự động |
| ECO-18 | Cân bằng | Máy dev | `SIM_BOOSTERS=1` | Bảng "với vật phẩm" in thêm; người chơi dùng ~1 vật phẩm mỗi 3–4 màn từ chương 2; không lỗi | P3 | Tự động |

## 5. Lưu dữ liệu (SAV)

| ID | Nhóm | Tiền điều kiện | Các bước | Kết quả mong đợi | Ưu tiên | Tự động/Thủ công |
|---|---|---|---|---|---|---|
| SAV-01 | Lưu | Bất kỳ | Thay đổi (mua đồ, nhận quà) rồi đợi 0.5 s, tắt app | Dữ liệu còn (autosave sau 300 ms) | P1 | Tự động (`save_test.dart`) + Thủ công |
| SAV-02 | Lưu | Đang ở bản đồ | Bấm Home (app vào nền) rồi buộc dừng app trong Cài đặt hệ thống | Mọi thay đổi trước đó còn (flush khi `onHide`/`onPause`) | P1 | Thủ công |
| SAV-03 | Lưu | Bất kỳ | Round-trip `toJson` → `fromJson` | Mọi trường giữ nguyên (xu, kim cương, sao, đồ, nhân viên, vật phẩm, mùa, Bí quyết…) | P1 | Tự động (`save_test.dart`) |
| SAV-04 | Lưu | Bản lưu JSON hỏng (chuỗi không phải JSON) | Mở app | Ván mới, chuỗi gốc chép sang `sugarleaf_save_v1_corrupt`, không crash | P1 | Tự động |
| SAV-05 | Lưu | Bản lưu có 1 trường sai kiểu (vd. `coins: "abc"`) | Mở app | Chỉ trường đó về mặc định, các trường khác giữ; có bản dự phòng | P1 | Tự động |
| SAV-06 | Lưu | Bản lưu `v: 3` (app mới hơn) | Mở app, chơi, tắt | Phiên khoá ghi: bản lưu gốc không bị ghi đè; Xoá dữ liệu trong Cài đặt mở khoá ghi | P1 | Tự động |
| SAV-07 | Quy đổi | Bản lưu V1 ngày 6 | Cài bản V2 đè lên, mở app | Qua L1–L5 mỗi màn 2★; +500 xu, +20 kim cương; hộp "Chào mừng trở lại" 1 lần; không intro dài, không hướng dẫn L1–3; chép `sugarleaf_save_v1_pre_v2` | P1 | Tự động (`save_migration_test.dart`) + Thủ công |
| SAV-08 | Quy đổi | Bản V1 ngày 30 | Mở app | Tối đa L1–L9 (2★); quà không lặp lại ở lần mở sau | P2 | Tự động |
| SAV-09 | Quy đổi | Đã có `pre_v2` | Mở lại app | `pre_v2` không bị ghi đè lần 2 | P2 | Tự động |
| SAV-10 | Quy đổi | Bản lưu đã xem `finale` cũ, chưa thắng L50 | Mở app, thắng L10, L20 | Không chiếu lại `ch1End`/`ch2End`; `finale` vẫn chiếu sau L50 | P2 | Tự động (`phase8b_test.dart`) |
| SAV-11 | Lưu | Đang trong màn (đã bán vài khách) | Tắt app đột ngột (vuốt khỏi đa nhiệm) | Mở lại: không cộng xu lượt dở, vật phẩm đã trừ không hoàn, không hỏng lưu | P1 | Thủ công |
| SAV-12 | Lưu | Bất kỳ | Cài đặt → Xoá dữ liệu → xác nhận | Về ván mới (100 xu, 5 kim cương); lần mở sau thấy intro dài | P1 | Tự động (`save_test.dart`) |
| SAV-13 | Lưu | Có id màn lạ trong `progress.levels` (vd. "99") | Mở app | Giữ trong JSON, không tính sao / mốc | P3 | Tự động |
| SAV-14 | Lưu | Bộ nhớ đầy / không ghi được | Chơi bình thường | Không crash, chỉ log lỗi lưu | P2 | Tự động (`save_test.dart`) + Thủ công |
| SAV-15 | Lưu | Bản lưu có `boosters` 5000 và `recipeSecrets` 20 | Mở app | Vật phẩm kẹp 999; bậc Bí quyết kẹp theo số bậc (3) | P2 | Tự động (cần viết qa_) |
| SAV-16 | Lưu | Cập nhật app (cài đè cùng chữ ký) | Cài bản mới lên bản cũ có tiến trình | Tiến trình, mua IAP giả lập, cài đặt ngôn ngữ còn nguyên | P2 | Thủ công |

## 6. Quảng cáo & IAP (ADS)

| ID | Nhóm | Tiền điều kiện | Các bước | Kết quả mong đợi | Ưu tiên | Tự động/Thủ công |
|---|---|---|---|---|---|---|
| ADS-01 | Rewarded | Kết quả có xu > 0 | Bấm "×2 xu (xem quảng cáo)" | Quảng cáo giả 2 s không đóng được bằng Back; xong +xu bằng xu của lượt; nút biến mất; dựng lại màn không nhân lần 2 | P1 | Tự động (`monetization_test.dart`, `phase6_test.dart`) |
| ADS-02 | Rewarded | Kết quả xu = 0 | Xem màn kết quả | Không có nút ×2 | P2 | Tự động |
| ADS-03 | Rewarded | Hộp vắng nhà | Bấm "x2" | Cộng gấp đôi, tính 1 lượt rewarded | P2 | Tự động (`staff_offline_test.dart`) |
| ADS-04 | Rewarded | Thẻ Sẵn sàng L4+ | Bấm xem quảng cáo nhận vật phẩm | Một vật phẩm miễn phí cho lượt (tự chọn món đắt nhất chưa có trong kho nếu chưa chọn); nút ẩn sau 1 lần | P2 | Tự động (`phase6_test.dart`) |
| ADS-05 | Rewarded | Cửa hàng | Bấm "+1 kim cương" | +1 kim cương, tính 1 lượt | P2 | Tự động (`store_test.dart`) |
| ADS-06 | Rewarded | Đã xem 12 quảng cáo thưởng hôm nay | Thử ×2 xu, +30 s, x2 vắng nhà, vật phẩm, kim cương | Nút ẩn/mờ hoặc toast "Hôm nay đã hết lượt nhận thưởng"; hết giờ chưa 1★ → không hỏi +30 s | P1 | Tự động (cần viết qa_) |
| ADS-07 | Rewarded | Đã xem 12 lượt | Đổi sang ngày lịch mới | Lượt về 0, xem lại được | P2 | Tự động (clock giả) |
| ADS-08 | Interstitial | Chưa qua L5 | Kết thúc 5 lượt chơi, rời kết quả | Không có interstitial | P1 | Tự động (`monetization_test.dart`) |
| ADS-09 | Interstitial | Đã qua L5, `playsSinceInterstitial` = 0 | Kết thúc lượt 1, 2, 3 (rời kết quả mỗi lần) | Interstitial hiện ở lần rời kết quả thứ 3, đếm lại 0 | P1 | Tự động |
| ADS-10 | Interstitial | Đủ điều kiện interstitial | Ở màn kết quả xem ×2 xu rồi rời | Không có interstitial lần này; lượt được giữ cho lần sau | P2 | Tự động |
| ADS-11 | Interstitial | Đủ điều kiện, lượt vừa rồi mở chương mới | Rời kết quả | Không interstitial (để thấy hoạt cảnh mở chương) | P2 | Tự động |
| ADS-12 | Interstitial | Bất kỳ | Theo dõi suốt: intro, thẻ Sẵn sàng, đang chơi, hướng dẫn, đơn đặc biệt | **Không bao giờ** có interstitial ngoài lúc rời màn kết quả | P1 | Thủ công + Tự động |
| ADS-13 | IAP | Cửa hàng | Xem danh sách | Nhãn "Chế độ thử"; 7 gói: Túi 80 kim cương $0.99, Hộp 450 $4.99, Rương 1000 $9.99, Gói khởi đầu $1.99, Bỏ quảng cáo $3.99, Trang phục lễ hội $2.99, Thẻ mùa $4.99; không hiện gói xu V1 | P1 | Tự động (`store_test.dart`) |
| ADS-14 | IAP | Cửa hàng | Mua Túi kim cương → xác nhận; lần 2 → Huỷ | +80 kim cương sau ~0.6 s; mua lại được nhiều lần; Huỷ không mua | P1 | Tự động |
| ADS-15 | IAP | Đã qua L3, chưa mua gói khởi đầu | Mở cửa hàng, mua Gói khởi đầu | Gói nổi bật từ L4; +8000 xu, +120 kim cương, mỗi vật phẩm +3; sau đó hiện "Đã có", không mua lại | P1 | Tự động |
| ADS-16 | IAP | Đã qua L5 | Mua Bỏ quảng cáo, chơi 3+ lượt | Không còn interstitial; rewarded vẫn xem được | P1 | Tự động |
| ADS-17 | IAP | Đã mua Trang phục lễ hội | Tab Nhân viên bật/tắt | Nora và Bảo đổi sang ảnh `_fest_`; chỉ đổi hình, chỉ số không đổi | P3 | Tự động (`monetization_test.dart`) + Thủ công |
| ADS-18 | Thẻ mùa | Giờ máy trong 15/10–15/12/2026 | Thắng L1 lần đầu 3★ | +35 điểm mùa (3 × 10 + 5) → đạt bậc 1 (30 điểm): nhận 300 xu (miễn phí); hàng cao cấp khoá tới khi mua | P2 | Tự động (`monetization_test.dart`) |
| ADS-19 | Thẻ mùa | Có thưởng chưa nhận, giờ máy sau 15/12/2026 | Mở app | Thưởng đã đạt tự nhận + thông báo; điểm/bậc về 0; mua Thẻ mùa không còn được | P2 | Tự động (clock giả) + Thủ công |
| ADS-20 | Khôi phục | Đã mua Bỏ quảng cáo | Cài đặt → Khôi phục giao dịch | Báo đã khôi phục 1 gói; không cộng lại xu/kim cương/vật phẩm | P2 | Tự động |
| ADS-21 | Vật phẩm | L4+, kim cương 20, kho trống | Chọn Tủ đầy (8) + Khách kiên nhẫn (6) → Bắt đầu | Trừ 14 kim cương lúc bấm Bắt đầu (thoát ở thẻ Sẵn sàng không mất); tủ đầy bánh 4★; kiên nhẫn khách vãng lai ×1.3 | P1 | Tự động (`booster_session_test.dart`, `monetization_test.dart`) |
| ADS-22 | Vật phẩm | L4+, kim cương 10, kho trống | Chọn Tủ đầy (8) rồi Lò ×2 (8) | Lần chọn thứ 2 báo "Không đủ kim cương" và mở cửa hàng; quay lại lựa chọn giữ nguyên | P2 | Tự động (cần viết qa_) |

## 7. Giao diện & đa ngôn ngữ (UI)

| ID | Nhóm | Tiền điều kiện | Các bước | Kết quả mong đợi | Ưu tiên | Tự động/Thủ công |
|---|---|---|---|---|---|---|
| UI-01 | Màn hình | Máy 1280×720 ngang (PO: 720×1280) | Duyệt mọi màn | Khung vừa khít, không viền, không cắt | P1 | Thủ công + Tự động (render 1280×720) |
| UI-02 | Màn hình | Máy 3200×1440 ngang (PO: 1440×3200) | Duyệt mọi màn | Khung 16:9 ở giữa, viền màu kem hai bên; chữ/ảnh sắc nét (không mờ do phóng) | P1 | Thủ công |
| UI-03 | Màn hình | Tablet 4:3 / 16:10 | Duyệt mọi màn | Viền kem trên/dưới; bố cục không lệch | P2 | Thủ công |
| UI-04 | Màn hình | Máy có tai thỏ/đục lỗ | Chơi một màn, mở thanh trên bản đồ | Không nút/chữ nào bị tai thỏ che (HUD, nút ⏸, xu) | P1 | Thủ công |
| UI-05 | Xoay | Đang ở bất kỳ màn nào | Xoay máy dọc (tắt khoá xoay) | Vẫn ngang (`sensorLandscape`); lật 180° ngang được | P2 | Thủ công |
| UI-06 | Xoay | Web, cửa sổ hẹp dọc | Mở app | Khung ngang + dòng nhắc xoay máy ở viền trên | P3 | Thủ công |
| UI-07 | Ngôn ngữ | Máy đặt tiếng Việt, Cài đặt "Theo hệ thống" | Mở app | Toàn bộ tiếng Việt có dấu, font Fredoka/Nunito hiển thị dấu đúng | P1 | Thủ công + Tự động (`level_map_test.dart` tiếng Việt) |
| UI-08 | Ngôn ngữ | Máy đặt tiếng Pháp, Cài đặt "Theo hệ thống" | Mở app | Rơi về tiếng Anh, không lỗi | P2 | Tự động (cần viết qa_) |
| UI-09 | Ngôn ngữ | Tiếng Việt | Duyệt: bản đồ, thẻ Sẵn sàng, HUD, kết quả, Nâng cấp 3 tab, Sổ công thức 18 món, cửa hàng, Thẻ mùa, Cài đặt, hộp vắng nhà | Không tràn chữ, không "…" cắt mất ý, không lẫn tiếng Anh | P2 | Tự động (`step3_c_screens_test.dart`, `screens_test.dart`) + Thủ công |
| UI-10 | Ngôn ngữ | Đang ở giữa màn chơi | Không có cách đổi ngôn ngữ giữa màn — đổi ở Cài đặt rồi vào màn | Nhãn hướng dẫn, bong bóng, tên món đúng ngôn ngữ mới | P3 | Thủ công |
| UI-11 | Định dạng | en và vi | Xem xu 1800 | en "1,800"; vi "1.800" | P2 | Tự động (cần viết qa_) |
| UI-12 | Định dạng | Truyện, tên màn, tên mở khoá | Đổi ngôn ngữ | Tên màn (`levels.json`), tên/mô tả mở khoá (`unlocks.json`), vật phẩm/gói (`monetization.json`) đúng ngôn ngữ | P2 | Thủ công |
| UI-13 | Điều hướng | Từng màn | Bấm nút Back Android | Bản đồ: không thoát app bất ngờ (theo thiết kế); trong màn: mở Tạm dừng; thẻ Sẵn sàng: về bản đồ; intro: = Bỏ qua; quảng cáo giả: không đóng được; kết quả: về bản đồ | P1 | Tự động (`intro_test.dart`, `staff_offline_test.dart`) + Thủ công |
| UI-14 | Hình ảnh | Thiếu một ảnh không phải nhân vật (đổi tên file thử trên bản debug) | Mở màn dùng ảnh đó | Hình vẽ code dự phòng, không crash | P3 | Tự động (`art_images_test.dart`) |
| UI-15 | Hình ảnh | Mọi nhân vật | Xem khách, khách quen, nhân viên, Mai | Luôn là ảnh vẽ tay, tỉ lệ hợp với tiệm (khách quầy, thu ngân phóng 1.45×) | P2 | Thủ công |
| UI-16 | Trợ năng | Bật "Xoá hiệu ứng động" (giảm chuyển động) trong Android | Mở intro dài, intro ngắn | Intro dài ~10 s, không pan/hạt, chuông vẫn kêu; intro ngắn đứng yên, vẫn tự sang bản đồ | P2 | Tự động (`intro_test.dart`) + Thủ công |
| UI-17 | Trợ năng | Đặt cỡ chữ hệ thống lớn nhất | Duyệt các màn | Chữ không phóng (khung khoá cỡ), bố cục không vỡ; ghi nhận cho PO | P3 | Thủ công |
| UI-18 | Bản đồ | Có level 3★, đặc biệt (★) | Xem nút level | 0–3 sao đúng; level đặc biệt (L10/20/30/40/50) to hơn, khác màu; nút "đang tới" nhịp nhẹ | P2 | Tự động (`level_map_test.dart`) |

## 8. Hiệu năng (PRF)

| ID | Nhóm | Tiền điều kiện | Các bước | Kết quả mong đợi | Ưu tiên | Tự động/Thủ công |
|---|---|---|---|---|---|---|
| PRF-01 | Hiệu năng | Máy dev | `flutter test test/game/level_play_perf_test.dart` | 25 khách: step+paint TB < 8 ms/khung; `advance` TB < 0.5 ms | P1 | Tự động |
| PRF-02 | Hiệu năng | Máy dev | `flutter test test/game/level_staff_test.dart`, `test/core/staff_test.dart` | 25 khách + 10 nhân viên giả lập + đồ đầy đủ: step+paint TB < 1 ms; không cấp phát theo khung | P1 | Tự động |
| PRF-03 | FPS | Máy chuẩn, bản profile/release | Chơi màn chương 4–5 giờ cao điểm (20+ khách, 2 lò, 4 nhân viên) | ≥ 55 FPS TB; không khung > 32 ms lặp lại (DevTools / `adb shell dumpsys gfxinfo`) | P1 | Thủ công |
| PRF-04 | FPS | Máy yếu (RAM 2–3 GB) | Như PRF-03 | ≥ 30 FPS TB, không giật quá 1 s, không ANR | P2 | Thủ công |
| PRF-05 | Khởi động | Máy chuẩn, app đã đóng hẳn | Đo từ chạm icon tới khung đầu của intro ngắn | Khởi động nguội < 4 s (máy yếu < 6 s); không màn trắng kéo dài | P2 | Thủ công |
| PRF-06 | Bộ nhớ | Máy chuẩn | Ghi RAM sau khi vào bản đồ; chơi liên tiếp 10 màn (Chơi lại/Màn tiếp), về bản đồ, ghi lại | RAM tăng ≤ 15% so với lúc đầu; không tăng đều qua mỗi màn (rò rỉ) | P1 | Thủ công (+ DevTools Memory) |
| PRF-07 | Bộ nhớ | Máy yếu | Duyệt bản đồ chương 1→5, mở intro dài từ Cài đặt | Không bị hệ thống giết app, không OOM | P2 | Thủ công |
| PRF-08 | Hiệu năng | Đơn đặc biệt | Làm 6 trạm (quẹt kem nhiều nét) | Kem vẽ mượt; số lệnh vẽ không tăng theo số nét | P2 | Tự động (`frost_perf_test.dart`) + Thủ công |
| PRF-09 | Pin/nhiệt | Máy chuẩn | Chơi liên tục 30 phút | Máy không nóng bất thường (> 45°C), pin tiêu hao hợp lý (≤ ~10%) | P3 | Thủ công |
| PRF-10 | Hiệu năng | Bản đồ | Để bản đồ đứng 1 phút | Nhịp nút "đang tới" không dựng lại cả trang (CPU thấp) | P3 | Tự động (`level_map_test.dart`) |

## 9. Trường hợp biên (EDG)

| ID | Nhóm | Tiền điều kiện | Các bước | Kết quả mong đợi | Ưu tiên | Tự động/Thủ công |
|---|---|---|---|---|---|---|
| EDG-01 | Bấm liên tục | Bản đồ | Bấm đúp / bấm 5 lần nhanh vào nút level, nút Nâng cấp | Chỉ mở 1 màn | P1 | Tự động (`navigation_guard_test.dart`) |
| EDG-02 | Bấm liên tục | Nâng cấp / Nhân viên | Bấm đúp "Mua" / "Thuê" / nâng chỉ số | Chỉ trừ tiền 1 lần | P1 | Tự động (`staff_offline_test.dart`) |
| EDG-03 | Bấm liên tục | Màn kết quả | Bấm đúp "Màn tiếp" / "Bản đồ" / "×2 xu" | Chỉ chuyển 1 lần; lượt chơi đếm 1 lần; ×2 xu tối đa 1 lần | P1 | Tự động (cần viết qa_) |
| EDG-04 | Nhiều ngón | Trong màn | Chạm 2–3 khách cùng lúc; vừa xoay trộn vừa chạm khách | Mỗi chạm xử lý đúng, không bán 2 lần một khách, không treo cử chỉ trộn | P2 | Thủ công |
| EDG-05 | Chuyển cảnh | Hết giờ | Bấm liên tục trong lúc chuyển sang màn kết quả | Không crash, không áp kết quả 2 lần | P1 | Thủ công + Tự động (cần viết qa_) |
| EDG-06 | Chuyển cảnh | Khách đặc biệt vừa tới đúng lúc hết giờ | Chạm khách đặc biệt khi `isOver` | Không vào đơn đặc biệt; vào kết quả bình thường | P2 | Tự động (cần viết qa_) |
| EDG-07 | Gián đoạn | Đang chơi | Có cuộc gọi đến, nghe 1 phút, cúp | Màn tự tạm dừng (hộp Tạm dừng), giờ không trôi; Tiếp tục chơi bình thường | P1 | Thủ công |
| EDG-08 | Gián đoạn | Đang làm 6 trạm đơn đặc biệt (kim lò đang chạy) | Chuyển app 30 s rồi quay lại | Không mất đơn, kim lò không chạy trong lúc ở nền (hoặc ghi lỗi nếu chạy), không crash | P2 | Thủ công |
| EDG-09 | Gián đoạn | Đang xem quảng cáo giả | Chuyển app rồi quay lại | Quảng cáo tự đóng đúng, thưởng trao 1 lần | P2 | Thủ công |
| EDG-10 | Gián đoạn | Thẻ Sẵn sàng / intro / bản đồ | Khoá màn hình rồi mở | Không crash; intro tiếp tục hoặc kết thúc hợp lý | P3 | Thủ công |
| EDG-11 | Mạng | Chế độ máy bay | Mở app, chơi, mở cửa hàng, mua giả lập, xem quảng cáo giả | Mọi thứ chạy (font đóng gói sẵn, không tải mạng) | P2 | Thủ công |
| EDG-12 | Vật phẩm | L4+, kho trống | Xem quảng cáo nhận vật phẩm → Bắt đầu → ⏸ → Thoát trước lần bán đầu | Hiện hành: vật phẩm +1 vào kho (toast "Đã trả vật phẩm vào kho") → có thể lặp để tích kho; **cần PO xác nhận** (test-plan §9 mục 5) | P2 | Tự động (`monetization_test.dart`) + Thủ công |
| EDG-13 | Đồng hồ | Đã nhận quà đăng nhập hôm nay | Chỉnh ngày máy +1, mở app | Nhận được quà ngày kế (game không chặn) — ghi nhận cho PO | P3 | Thủ công |
| EDG-14 | Đồng hồ | Đã thuê quản lý | Chỉnh giờ máy lùi 2 giờ, mở app | Không tính vắng nhà, không âm xu; mốc đặt lại | P1 | Tự động (cần viết qa_) |
| EDG-15 | Đồng hồ | Đã thuê quản lý | Chỉnh giờ máy tiến 60 ngày | Thời gian vắng lưu tối đa 30 ngày, tính theo trần giờ (≤ 8 giờ) | P2 | Tự động (cần viết qa_) |
| EDG-16 | Xu = 0 | Bản lưu xu 0, kim cương 0 | Duyệt Nâng cấp, thẻ Sẵn sàng (chọn vật phẩm), cửa hàng | Không mua được, báo thiếu; chơi màn vẫn được; không âm | P1 | Tự động (cần viết qa_) |
| EDG-17 | Xu rất lớn | Sửa bản lưu: xu 999 999 999, kim cương 999 999 | Mở bản đồ, cửa hàng, Nâng cấp | Số hiển thị đủ (phân tách hàng nghìn), không tràn thanh trên; mua trừ đúng | P2 | Thủ công + Tự động (cần viết qa_) |
| EDG-18 | Xu rất lớn | Sửa bản lưu: xu 9 007 199 254 740 000 (gần 2^53) | Mở trên Android và web, nhận thưởng | Không âm, không mất số; nếu tràn → ghi lỗi (xu không có trần trên) | P3 | Thủ công |
| EDG-19 | Cấu hình | `levels.json` hỏng (bản debug) | Mở app | Cấu hình rỗng: bản đồ báo lỗi nạp, không crash; bản lưu không bị xoá | P2 | Tự động (`level_progress_test.dart` cấu hình rỗng, `unlock_test.dart` loadOrEmpty) |
| EDG-20 | Web | Web | Gõ thẳng URL `/level` với id chưa mở, hoặc `/day` cũ | Về bản đồ, không chồng bản đồ, không mở màn khoá | P2 | Tự động (`level_map_test.dart`) |
