# QA tự động — phần logic core (nhánh v2, 2026-10-30)

Phạm vi: `lib/core/**` (LevelSession, kết quả màn, mở khoá, nhân viên, thu nhập offline, lưu dữ liệu, quảng cáo/IAP giả
lập) + chơi tự động L1→L10. Không sửa code game.

## File test đã thêm

| File | Nội dung | Số test |
|---|---|---|
| `test/core/qa_helpers.dart` | trợ giúp chung (không phải test) | – |
| `test/core/qa_level_session_test.dart` | mốc sao 50 level, biên xu/khách trên session thật, hết giờ, +30 s, combo trần, khách bỏ đi/quay đi, tip theo kiên nhẫn, nhịp khách L1–L10 theo levels.json, đơn đặc biệt sai từng trạm | 23 |
| `test/core/qa_unlock_staff_test.dart` | duyệt từng mục unlocks.json (14), từng thiết bị (7), mở chương 2–5 theo sao (biên −1 sao), nhân viên đúng vai trò trong màn, nâng cấp từng nhân viên (5) | 33 |
| `test/core/qa_offline_test.dart` | công thức 25 cặp cấp quản lý, biên 10 phút / trần giờ, đổi giờ tiến / lùi, bản lưu offline hỏng | 9 |
| `test/core/qa_save_test.dart` | fuzz mọi trường bản lưu × 6 kiểu rác, enum lạ, JSON cụt/BOM/mảng, quy đổi V1, thoát giữa màn, xu/kim cương 0 / 2^53 / tràn int | 11 (2 skip) |
| `test/core/qa_monetization_test.dart` | rewarded (lỗi giữa chừng, giới hạn ngày, đổi ngày), interstitial (tần suất, trước L5, thoát giữa màn), IAP (mua, mua lại, thẻ mùa ngoài mùa, xoá quảng cáo, khôi phục) | 12 |
| `integration_test/levels_1_10_test.dart` + `test/core/qa_levels_1_10_headless_test.dart` | bot chơi L1→L10 trên GameState thật, mua đồ, interstitial, lưu/đọc | 1 |

Tổng: 89 test (87 pass, 2 skip vì lỗi). `flutter test test/core`: 429 pass, 2 skip. `flutter analyze lib test/core
integration_test`: sạch.

Integration test: chưa chạy trên thiết bị — `-d windows` lỗi "No Windows desktop project configured" (dự án không có
thư mục `windows/`), `-d chrome` lỗi "Web devices are not supported for integration tests yet", `-d flutter-tester` lỗi
"Failed to build bundle". Phần thân chạy headless qua `flutter test test/core/qa_levels_1_10_headless_test.dart`: xanh,
bot 0.8 qua L1→L10 mỗi level lần đầu (10 lượt, 24 sao, chương 2 mở, 1 interstitial sau L5).

## Lỗi

### BUG-CORE-01 — Cộng xu / kim cương bị tràn int, số dư rất lớn về 0
| Mục | Nội dung |
|---|---|
| Mức độ | Minor (chỉ gặp khi bản lưu có số rất lớn — sửa tay / hỏng; nhưng hậu quả là mất sạch xu) |
| Khu vực | GameState: ví xu / kim cương |
| Bước tái hiện | `GameState.fromJson({'v':2,'coins': 9223372036854775797})` → `applyLevelResult(... coins: 100)` (hoặc `addCoins`, `addGems`) |
| Mong đợi | Số dư giữ ở trần (bão hoà), không giảm |
| Thực tế | Cộng tràn int 64-bit thành số âm, `math.max(0, …)` đưa về **0** |
| Log | `Expected: a value greater than or equal to <9223372036854775797>  Actual: <0>` |
| Test | `qa_save_test.dart` › "xu rất lớn (gần trần int 64-bit) + kiếm thêm → không được tràn về 0" (skip `QA-BUG`) |
| Gợi ý nguyên nhân | `lib/core/game_state.dart:1676` (`addCoins`), `:1681` (`addGems`), `:1757` (`applyLevelResult`), cùng các chỗ `_coins += …` (`claimOffline` :1576, `doubleResultCoins` :1840, `claimQuest` :1893…). Đề xuất: kẹp ví ở một trần (vd. 2^53 − 1, an toàn cả trên web) khi đọc và khi cộng. |

### BUG-CORE-02 — Bản lưu xu là số thực khổng lồ (1e300) được nhận nguyên thành 2^63−1
| Mục | Nội dung |
|---|---|
| Mức độ | Minor |
| Khu vực | GameState.fromJson (đọc bản lưu) |
| Bước tái hiện | `fromJson({'v':2,'coins':1e300})` → `addCoins(1)` |
| Mong đợi | Giá trị vô lý bị kẹp về trần hợp lý (hoặc coi là trường hỏng, chép dự phòng) |
| Thực tế | `(1e300).toInt()` = 9223372036854775807; cộng 1 xu → 0 (xem BUG-CORE-01). Trên web số > 2^53 còn mất chính xác. |
| Log | `Expected: a value greater than <0>  Actual: <0>` |
| Test | `qa_save_test.dart` › "bản lưu xu = 1e300 …" (skip `QA-BUG`) |
| Gợi ý nguyên nhân | `lib/core/game_state.dart:434-435` (`field('coins'/'gems', … asInt(v))` không có trần trên). |

Không tìm thấy lỗi Critical / Major trong phần core đã test: tính sao/xu, nhịp khách, kiên nhẫn, hàng chờ, chấm đơn đặc
biệt, mở khoá từng mục/thiết bị, mở chương, nhân viên, offline, fuzz bản lưu, quảng cáo/IAP giả lập đều đúng theo code.

## Cần BA/PO xác nhận

1. **Đổi giờ hệ thống → thu nhập offline ảo.** Lùi giờ, mở app (mốc hoạt động lùi theo), chỉnh lại giờ thật → được tính
   "vắng" bằng khoảng đã lùi (cắt trần giờ quản lý). Lặp chu kỳ tiến giờ → nhận → lùi giờ: 5 chu kỳ trong vài giây thật
   được 48.000 xu (quản lý cấp 1, x2 quảng cáo). Code chủ ý "đồng hồ lùi → đặt lại mốc" (`game_state.dart:1549-1568`, có
   test sẵn). Không có giờ máy chủ nên tiến giờ luôn ăn được một lần trần; PO quyết có chặn (vd. giữ mốc = max(mốc cũ,
   bây giờ)) hay chấp nhận. Test: `qa_offline_test.dart` › 2 test "CẦN PO".
2. **Lùi ngày hệ thống → thêm lượt rewarded trong ngày.** Xem 12 lượt, lùi 1 ngày xem thêm 12, chỉnh lại giờ → lại 12
   (36 lượt/ngày thật). Kết hợp `AdPlacement.freeGem` (+1 kim cương/lượt) = nuôi kim cương bằng đổi giờ. Test:
   `qa_monetization_test.dart` › "CẦN PO: lùi ngày hệ thống…".
3. **Vật phẩm miễn phí nhờ quảng cáo, thoát trước lần bán đầu → hoàn +1 vào kho.** Đổi được mỗi lượt quảng cáo thành
   một vật phẩm cất kho (tối đa 12/ngày). Code ghi rõ là chủ ý (`refundBoosters`, `game_state.dart:2082`).
4. **Khách đặc biệt bỏ đi không tính vào `lost`** (chỉ `specialsMissed`). Mô tả PO "khách bỏ đi được đếm" — xác nhận
   màn kết quả có cần hiện khách đặc biệt lỡ không.
5. **Sai hộp / trộn lệch / sai khuôn 2 lần vẫn 5★** (kèm lời chê đúng trạm), vì trọng số hộp 10, trộn 10, khuôn 0 (chỉ
   phạt 0.05/lần, tối đa 0.10). Sai topping hoàn toàn hoặc thiếu topping vẫn 4★ (chất lượng đúng 0.75). Xác nhận đúng ý
   đồ cân bằng.
6. **Xoá dữ liệu (Cài đặt › resetAll) → mất gói IAP đã mua**, "Khôi phục" giả lập trả 0 vì chỉ đọc bản lưu. Khi nối SDK
   thật phải khôi phục từ cửa hàng.
7. **Quảng cáo lỗi giữa chừng:** `AdService.showRewarded` không có kết quả "huỷ"; presenter ném lỗi → hàm ném ra (không
   thưởng, không tính lượt — đúng). UI `level_result_screen.dart:76` có bắt lỗi; các chỗ gọi khác (`level_screen.dart:273,
   440`, `offline_dialog.dart:112`, `store_screen.dart:72`) nên kiểm tra cũng bắt lỗi (ngoài khu vực core).

## Điểm code khác mô tả

- **Mở rộng bếp L22 (`kitchen_2`)**: có trong unlocks.json đúng L22 nhưng hiệu ứng `prepSlots` là khoá "reserved" →
  hiện "Sắp có", **chưa mua được**. Các mốc khác khớp mô tả: thu ngân L10, thợ L15, bàn ghế L18, phục vụ L25 (cần bàn ghế
  trước), quản lý + offline L32. Thêm: case_stand L5, oven_2 L12, staff_baker_2 L28, garden L30, floor_2 L35;
  staff_training L41 và rare_decor L45 cũng "Sắp có".
- **"Sai kem"**: chấm điểm không có loại kem — `BakeOutcome` không có trường kem, trạm kem chỉ tính % phủ (chê "kem loang").
  `Order.frosting` có nhưng không được chấm.
- **Rewarded**: tối đa 12 lượt/ngày lịch (`Economy.maxRewardedPerDay`), CLAUDE.md ghi 8/ngày. Giả lập không có nhánh
  huỷ (hộp thoại không đóng được, tự đóng) nên "huỷ không thưởng" chỉ kiểm được qua presenter ném lỗi.
- **Interstitial**: theo GĐ6 — sau khi đã qua L5, mỗi 3 lượt chơi xong, chỉ khi rời màn kết quả; không hiện khi vừa
  xem rewarded ở màn đó / vừa mở chương / đã mua xoá quảng cáo. CLAUDE.md ghi "từ ngày 4, tối đa 1 lần / 2 ngày". Core
  không có điểm gọi interstitial trong màn (LevelSession không đụng GameState); lượt bị thoát giữa màn không được đếm.
- **IAP giả lập**: chỉ có thành công hoặc "không mua được" (false); không có nhánh huỷ / lỗi thanh toán.
- **Thoát giữa màn**: không có lưu-tiếp-màn; khởi động lại thì lượt đó mất (xu kiếm dở không vào ví, vật phẩm đã trừ lúc
  Bắt đầu không hoàn — chỉ hoàn khi bấm Thoát/Chơi lại trước lần bán đầu).
- **L20** có `rushAtPct` 45 (giờ cao điểm sớm, level ★ "Giờ cao điểm"); các level khác ≥ 50.
- Bot cân bằng (`LevelBot`) giả lập đơn đặc biệt tức thì (giờ màn dừng), nên chơi tự động L1→L10 không đo được thời gian
  thật 2–4 phút của người chơi (thời lượng màn L1–L10 trong levels.json: 120–200 giây).
