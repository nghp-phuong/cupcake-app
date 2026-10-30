# V2 · Giai đoạn 4 — Chuỗi giao diện Nhân viên / Khi bạn vắng nhà / thẻ "Sẵn sàng" (dev-ui) cho localizer

Dùng trong `lib/ui/upgrades/staff_tab.dart` (tab "Nhân viên" của màn Nâng cấp), `lib/ui/map/offline_dialog.dart` (hộp
"Khi bạn vắng nhà" trên bản đồ), `lib/ui/level/level_screen.dart` (hàng chân dung nhân viên trên thẻ "Sẵn sàng") và
`test/ui/*`; **chưa có trong `.arb`**. Thêm vào `lib/l10n/app_en.arb` (nguồn, kèm `@khoá` với `description` +
`placeholders`) và `lib/l10n/app_vi.arb`, rồi chạy `flutter pub get` (gen-l10n).

Thuật ngữ: "Level" = "Màn", gems = "kim cương", "Staff" = "Nhân viên". **Không dùng ký tự ★** (chữ "sao" / "stars").
Tên + câu giới thiệu từng nhân viên nằm trong `assets/config/unlocks.json` (mục `staff`, en + vi), không phải `.arb`.
Số thập phân (`seconds`, `stars`) đã định dạng theo ngôn ngữ trước khi truyền vào (vd. "3.2" / "3,2"; số tròn không có phần lẻ: "24").

## Tab Nhân viên

| Khoá | en | vi | Placeholder | Dùng ở |
|---|---|---|---|---|
| `upgTabStaff` | Staff | Nhân viên | — | Tab 3 của màn Nâng cấp |
| `staffRoleCashier` | Cashier | Thu ngân | — | Vai trò trên thẻ nhân viên |
| `staffRoleBaker` | Baker | Thợ bánh | — | Vai trò trên thẻ nhân viên |
| `staffRoleWaiter` | Server | Phục vụ | — | Vai trò trên thẻ nhân viên |
| `staffRoleManager` | Manager | Quản lý | — | Vai trò trên thẻ nhân viên |
| `staffStatSpeed` | Speed | Tốc độ | — | Nhãn dòng chỉ số 1 |
| `staffStatSkill` | Skill | Tay nghề | — | Nhãn dòng chỉ số 2 |
| `staffStatLevel` | {stat} level {level} of {max} | {stat} cấp {level}/{max} | `stat`: String (`staffStatSpeed` / `staffStatSkill`), `level`: int, `max`: int | Nhãn đọc màn hình của hàng chấm cấp |
| `staffHire` | Hire | Thuê | — | Nút thuê nhân viên (cạnh giá) |
| `staffHired` | Welcome to the team! | Chào mừng vào tiệm! | — | Toast khi thuê thành công |
| `staffUpgradeStat` | Upgrade {stat} | Nâng {stat} | `stat`: String (`staffStatSpeed` / `staffStatSkill`) | Nhãn đọc màn hình của nút nâng một chỉ số (nút chỉ hiện mũi tên + giá) |
| `staffCashierSpeed` | Sells every {seconds}s | Bán mỗi {seconds} giây | `seconds`: String | Thông số Tốc độ thu ngân (trước → sau) |
| `staffCashierSkill` | +{percent}% tips | Tip thêm {percent}% | `percent`: int | Thông số Tay nghề thu ngân (tip cộng thêm trên lượt Nora bán; ngắn vì hiện cặp "trước → sau") |
| `staffBakerSpeed` | A batch every {seconds}s | Một mẻ mỗi {seconds} giây | `seconds`: String | Thông số Tốc độ thợ bánh |
| `staffBakerSkill` | Cakes around {stars} stars | Bánh khoảng {stars} sao | `stars`: String | Thông số Tay nghề thợ bánh (sao trung bình) |
| `staffWaiterSpeed` | Serves every {seconds}s | Phục vụ mỗi {seconds} giây | `seconds`: String | Thông số Tốc độ phục vụ |
| `staffWaiterSkill` | Waiting guests +{percent}% patience | Khách chờ kiên nhẫn +{percent}% | `percent`: int | Thông số Tay nghề phục vụ |
| `staffManagerSpeed` | {percent}% of a level's coins per hour | {percent}% xu một màn mỗi giờ | `percent`: int | Thông số Tốc độ quản lý (thu nhập khi vắng; số đứng đầu để cặp "trước → sau" gọn: "20% → 25% xu một màn mỗi giờ") |
| `staffManagerSkill` | Counts up to {hours} hours away | Tính tối đa {hours} giờ vắng | `hours`: int | Thông số Tay nghề quản lý (trần giờ) |
| `staffRequires` | Needs {item} first | Cần có {item} trước | `item`: String (tên mục mở khoá từ unlocks.json, vd. "Café tables" / "Bàn ghế quán") | Chân thẻ nhân viên đã qua mốc nhưng chưa thuê được vì thiếu mục phải mua trước (phục vụ cần bàn ghế), thay cho "Qua màn X để mở" |

## Hộp "Khi bạn vắng nhà" (bản đồ)

| Khoá | en | vi | Placeholder | Dùng ở |
|---|---|---|---|---|
| `offlineTitle` | While you were away | Khi bạn vắng nhà | — | Tiêu đề hộp |
| `offlineBody` | {name} looked after the bakery for {duration}. | {name} đã trông tiệm giúp bạn {duration}. | `name`: String (tên quản lý từ JSON), `duration`: String (một chuỗi `offlineDuration*`) | Dòng dưới chân dung |
| `offlineCapped` | Counted {hours} hours (the manager's limit). | Chỉ tính {hours} giờ (giới hạn của quản lý). | `hours`: int | Dòng nhắc khi thời gian vắng bị cắt theo trần giờ |
| `offlineDurationMinutes` | `{minutes, plural, =1{1 minute} other{{minutes} minutes}}` | `{minutes} phút` | `minutes`: int | Thời gian vắng < 1 giờ |
| `offlineDurationHours` | `{hours, plural, =1{1 hour} other{{hours} hours}}` | `{hours} giờ` | `hours`: int | Thời gian vắng tròn giờ (< 1 ngày) |
| `offlineDurationHoursMinutes` | {hours} h {minutes} min | {hours} giờ {minutes} phút | `hours`: int, `minutes`: int | Thời gian vắng có lẻ phút (< 1 ngày) |
| `offlineDurationDays` | `{days, plural, =1{over a day} other{{days} days}}` | `{days, plural, =1{hơn một ngày} other{{days} ngày}}` | `days`: int | Thời gian vắng ≥ 1 ngày (làm tròn xuống) |
| `offlineEarned` | `{count, plural, =1{You earned 1 coin} other{You earned {count} coins}}` | `Bạn nhận được {count} xu` | `count`: int | Nhãn đọc màn hình của dòng số xu |
| `offlineClaim` | Collect | Nhận | — | Nút nhận xu |
| `offlineDouble` | x2 (watch ad) | x2 (xem quảng cáo) | — | Nút nhân đôi bằng quảng cáo thưởng (ẩn khi hết lượt) |
| `offlineDoubled` | Coins doubled! | Đã nhân đôi xu! | — | Toast sau khi xem quảng cáo xong |

## Thẻ "Sẵn sàng" (màn chơi)

| Khoá | en | vi | Placeholder | Dùng ở |
|---|---|---|---|---|
| `levelReadyStaff` | Helping this level | Phụ bạn màn này | — | Nhãn trước hàng chân dung nhân viên |
| `levelReadyStaffNames` | {names} will help this level | {names} sẽ phụ bạn màn này | `names`: String (tên nối bằng ", ") | Nhãn đọc màn hình của hàng chân dung |

## Khoá cũ dùng lại (không đổi)
`upgradeMaxed` (chỉ số đã tối đa), `upgradeDone` (toast nâng chỉ số), `commonNotEnoughCoins`, `commonNotEnoughGems`,
`mapUnlockAfterLevel` ("Qua màn X để mở"), `levelNewBadge` ("Mới"), `upgComingSoon`, `upgOwned`, `unlockNoticeView`.
