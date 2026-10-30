# V2 · Giai đoạn 7 — Script mô phỏng cân bằng 50 màn (không UI)

Nhánh `v2`. Dùng lại `LevelSession` + `LevelBot` + logic mua sắm của `test/core/progression_sim.dart` (cùng một mã với
màn chơi thật). Không đổi UI, không đổi lưu game.

## 1. Nội dung màn 21–50 (bản nháp chỉ cho mô phỏng)
`levels.json` hiện có 20 màn (chương 1–2). Mốc mở khoá chạy tới L45 (`kitchen_2` 22, `staff_waiter` 25, `staff_baker_2`
28, `garden` 30, `staff_manager` 32, `floor_2` 35, `staff_training` 41, `rare_decor` 45), nên cần dữ liệu L21–50:
- Viết vào **`assets/config/levels_draft.json`** (cùng định dạng; chương 3, 4, 5 mỗi chương 10 màn; menu dùng món đã mở
  theo `unlocks`/catalog; độ khó tăng dần: khách/phút, kiên nhẫn, mục tiêu xu, đơn đặc biệt). **Game chưa nạp file này**
  (bản đồ chưa có ảnh chương 3–5) — chỉ script mô phỏng gộp `levels.json` + `levels_draft.json`.
- Mục tiêu xu từng màn cân theo thu nhập bot kỳ vọng ở tiến trình đó (không chỉnh tay từng số nếu có thể sinh theo công
  thức; ghi công thức trong `_note`).

## 2. Script `tool/simulate.dart`
- Chạy: `flutter test tool/simulate.dart` (hoặc `dart run` nếu không phụ thuộc Flutter), tham số qua biến môi trường:
  `SIM_RUNS` (số người chơi giả, mặc định 200), `SIM_SEED`, `SIM_SKILL` (`newbie` | `average` | `good`, mặc định cả 3),
  `SIM_BOOSTERS` (0/1, mặc định 0 — bảng "với vật phẩm" in thêm khi 1), `SIM_OUT` (đường dẫn CSV, tuỳ chọn).
- Người chơi giả: chơi L1→L50 theo thứ tự; thua thì chơi lại (tối đa 10 lần, quá thì ghi "kẹt"); sau mỗi lượt mua sắm
  theo ưu tiên sẵn có (mở rộng → nhân viên → thiết bị → dụng cụ → nâng nhân viên → trang trí); không quảng cáo, không IAP;
  cộng kim cương trong game như thật; tính cả thu nhập vắng nhà giả định (tắt mặc định, `SIM_OFFLINE_HOURS`).
- **In ra** (stdout, bảng chữ dễ đọc; kèm CSV nếu có `SIM_OUT`):
  1. Mỗi màn: chương, xu kiếm trung bình / trung vị, xu tích luỹ, tỉ lệ thắng lần đầu, số lần thử trung bình, % kẹt,
     sao trung bình, % bán do nhân viên.
  2. Mỗi mốc mở khoá (cả thiết bị, nhân viên, nâng chỉ số chính): màn mở, giá, **màn trung vị mua được**, độ trễ (màn) —
     đánh dấu ✗ nếu trễ > 3 hoặc mua ngay lúc mở mà còn dư > 2 lần giá (quá rẻ).
  3. Tổng kết mỗi chương: tỉ lệ thắng lần đầu trung bình, số lần thử, xu cuối chương.
  4. Danh sách lệch mục tiêu.
- Mục tiêu: mỗi mốc mua được trong **1–3 màn** sau khi mở; thắng lần đầu ≈ **80% ở chương 1**, ≈ **60% ở chương 4**
  (người chơi `average`); chương 2–3 nằm giữa, chương 5 ≤ chương 4.

## 3. Cân bằng
dev-core chỉnh số trong `levels_draft.json`, `unlocks.json` (giá) và nếu cần L11–20 trong `levels.json` cho tới khi đạt
mục tiêu với `average`; không đổi L1–10 trừ khi lệch rõ (đã cân ở GĐ1–5). Ghi bảng kết quả cuối vào
`docs/v2/phase7-balance.md` (trước/sau, các số đã đổi và lý do).

## 4. Test
- `test/core/simulate_test.dart`: chạy rút gọn (`SIM_RUNS` nhỏ) để kiểm tra script không lỗi, tất định theo seed, và
  khẳng định các mục tiêu §2 ở mức có dung sai (±8 điểm %).
- Các test cân bằng cũ (`level_balance_test`, `progression_sim_test`, `booster_balance_test`) vẫn qua.
