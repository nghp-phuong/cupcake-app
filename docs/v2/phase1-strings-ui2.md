# V2 · Giai đoạn 1 — Chuỗi giao diện bổ sung (điều kiện khách đặc biệt) cho localizer

Dùng trong `lib/ui/level/level_screen.dart` (HUD + toast) và `test/ui/level_screens_test.dart`; **chưa có trong
`.arb`**. Thêm vào `lib/l10n/app_en.arb` (nguồn, kèm `@khoá` với `placeholders`) và `lib/l10n/app_vi.arb`.

`{who}` là tên khách đã dịch sẵn (dùng khoá có sẵn: `charHoa` "Mr. Hoa"/"Ông Hòa", `charLinh`, `charKenji`,
`customerVip` "VIP guest"/"Khách VIP"). `{time}` là mốc trên đồng hồ đếm ngược dạng `m:ss` (vd. "1:30").

| Khoá | en | vi | Placeholder | Dùng ở |
|---|---|---|---|---|
| `levelSpecialCondition` | {who} drops by if you serve {served}/{target} customers by {time} | {who} ghé nếu phục vụ {served}/{target} khách trước {time} | `who`: String, `served`: int, `target`: int, `time`: String | Nhãn nhỏ dưới thanh mục tiêu HUD (lượt ghé có hạn `bySec`) |
| `levelSpecialConditionNoTime` | {who} drops by after you serve {served}/{target} customers | {who} ghé khi bạn phục vụ {served}/{target} khách | `who`: String, `served`: int, `target`: int | Như trên, lượt ghé không có hạn |
| `levelSpecialSkipped` | {who} couldn't make it this time | {who} không ghé được rồi | `who`: String | Toast khi lượt ghé đặc biệt bị bỏ (quá hạn chưa đủ khách) |
