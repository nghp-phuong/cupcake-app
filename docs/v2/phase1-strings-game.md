# V2 · Giai đoạn 1 — Chuỗi giao diện của màn chơi level (dev-game → localizer)

Dùng ở `lib/game/level/level_play_view.dart` (dựng `LevelLabels`, vẽ trên canvas Flame). Thêm vào `lib/l10n/app_en.arb`
(nguồn) và `lib/l10n/app_vi.arb`. Chữ hiện trên nhãn giấy nhỏ trong ô trạm rộng ~150 px tham chiếu: giữ ngắn.

| Khoá | en | vi | Mô tả / ràng buộc |
|---|---|---|---|
| `lvlCaseFull` | Case full! | Tủ đầy! | Mẻ đã đóng hộp nhưng tủ kính hết chỗ; hiện nhấp nháy ở trạm Hộp và bay lên ở tủ. ≤ 14 ký tự. |
| `lvlRushHour` | Rush hour! | Giờ cao điểm! | Băng rôn lớn giữa sân tiệm khi bắt đầu giờ cao điểm. |
| `lvlCombo` | Combo ×{count} | Combo ×{count} | Nhãn bay lên cạnh khách khi bán liên tiếp. Placeholder `count`: `int` (≥ 2). |
| `lvlWaitOven` | Waiting for oven | Chờ lò | Trạm Trộn: mẻ đã trộn xong, lò đang bận. ≤ 18 ký tự. |
| `lvlWaiting` | Waiting… | Đang chờ… | Lò: đã lấy bánh ra nhưng trạm Kem còn bận mẻ trước. ≤ 14 ký tự. |
| `lvlPickTreat` | Tap a treat | Chạm chọn món | Trạm Khuôn khi chưa có mẻ: gợi ý chạm thẻ món ở cột trái (kèm mũi tên). ≤ 16 ký tự. |
| `lvlBurnt` | Burnt! | Cháy rồi! | Lò: mẻ để quá, bị cháy. |
| `lvlTakeOut` | Take out! | Lấy ra! | Lò: kim đang trong vùng vàng — chạm lò để lấy bánh. ≤ 12 ký tự. |
| `lvlStirHint` | Stir 1 turn | Khuấy 1 vòng | Trạm Trộn: kéo ngón tay một vòng quanh âu. ≤ 16 ký tự. |
| `lvlSwipeHint` | Swipe across | Quẹt ngang | Trạm Kem: quẹt ngang qua bánh để phủ kem. ≤ 16 ký tự. |

Khoá sẵn có được dùng lại (không cần thêm): `commonDone` (nút Xong ở trạm Kem), `stationName` / `mouldName` / `boxName`
qua `l10n_lookup.dart` (tên ô trạm, tên khuôn, tên hộp).

Mẫu ARB (en):
```json
"lvlCaseFull": "Case full!",
"@lvlCaseFull": { "description": "Level play: the display case has no room for the boxed batch." },
"lvlRushHour": "Rush hour!",
"@lvlRushHour": { "description": "Level play: banner when rush hour starts." },
"lvlCombo": "Combo ×{count}",
"@lvlCombo": { "description": "Level play: consecutive sales combo label.", "placeholders": { "count": { "type": "int" } } },
"lvlWaitOven": "Waiting for oven",
"@lvlWaitOven": { "description": "Level play, mix station: batch mixed, oven busy. Keep short." },
"lvlWaiting": "Waiting…",
"@lvlWaiting": { "description": "Level play, oven: taken out, frosting station still busy. Keep short." },
"lvlPickTreat": "Tap a treat",
"@lvlPickTreat": { "description": "Level play, mould station idle: tap a recipe card on the left. Keep short." },
"lvlBurnt": "Burnt!",
"@lvlBurnt": { "description": "Level play, oven: the batch burnt." },
"lvlTakeOut": "Take out!",
"@lvlTakeOut": { "description": "Level play, oven: needle in the golden zone, tap to take out. Keep short." },
"lvlStirHint": "Stir 1 turn",
"@lvlStirHint": { "description": "Level play, mix station hint: drag one full circle around the bowl. Keep short." },
"lvlSwipeHint": "Swipe across",
"@lvlSwipeHint": { "description": "Level play, frosting station hint: swipe across the cake. Keep short." }
```
