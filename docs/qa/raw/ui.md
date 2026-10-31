# QA giao diện (widget test) — ghi chép thô

Nhánh `v2`, ngày 2026-10-30. Người làm: QA (subagent, khu vực `test/ui/qa_*`). Không sửa code game.

## Test đã thêm

| File | Nội dung |
|---|---|
| `test/ui/qa_helpers.dart` | Helper dùng chung (không phải test): cỡ màn, bộ dò chữ chưa dịch / khoá thô / ★, bắt FlutterError, ván QA dựng sẵn, `qaBug()` |
| `test/ui/qa_smoke_test.dart` | Smoke: lần đầu → cảnh mở đầu có Bỏ qua → L1 → cảnh mở màn → Sẵn sàng → tự chơi → kết quả → bản đồ; "tắt app" và mở lại với cùng SharedPreferences giả → intro ngắn → bản đồ, tiến trình (xu, sao L1, cảnh đã xem, level cao nhất) giữ nguyên |
| `test/ui/qa_screens_matrix_test.dart` | 19 màn × (en, vi) × 5 cỡ ngang (1280×720, 1600×720, 3200×1440, 2048×1536, 1280×720 có tai thỏ 48): không FlutterError (tràn), không khoá thô, không chuỗi en khi đang vi, không glyph ★/☆, không widget Material lệch phong cách |
| `test/ui/qa_touch_targets_test.dart` | `androidTapTargetGuideline` theo khung tham chiếu và trên máy thật (dpr thật), `textContrastGuideline`, tai thỏ |
| `test/ui/qa_edge_cases_test.dart` | Bấm đúp mua / vào màn / Nhận offline, bấm khi đang chuyển cảnh, xu & kim cương = 0 và 999 999 999 |
| `test/ui/qa_ads_test.dart` | Rewarded bị huỷ thì không thưởng (×2 kết quả, kim cương miễn phí, x2 vắng nhà, +30 giây); interstitial không hiện ở Sẵn sàng / trong màn / hộp +30 giây, chỉ khi rời màn kết quả |

Test lộ lỗi đang để `skip: qaBug('QA-BUG: …')` (testWidgets chỉ nhận `skip` kiểu bool nên lý do nằm trong
`qaBug`). Chạy lại cả các test đó để tái hiện / kiểm sau khi sửa:

```
flutter test --dart-define=QA_RUN_BUGS=true test/ui/qa_edge_cases_test.dart test/ui/qa_touch_targets_test.dart test/ui/qa_ads_test.dart
flutter test --dart-define=QA_VERBOSE=true ...   # in đầy đủ FlutterError (widget gây tràn, file:dòng)
```

**Kết quả**: 81 test QA (71 qua, 10 skip vì lỗi đã ghi dưới đây); `flutter test test/ui` toàn bộ 285 qua / 10 skip;
`flutter analyze` sạch. Lỗi: Critical 0 · Major 3 (UI-01, UI-03, UI-05) · Minor 3 (UI-02, UI-04, UI-07) · Trivial 1 (UI-06).

## Đã kiểm, không có lỗi
- Không tràn / không lỗi dựng ở cả 19 màn × 2 ngôn ngữ × 5 cỡ (RefFrame giữ bố cục 1280×720 nên cỡ màn không ảnh hưởng bố cục).
- Không khoá ARB thô, không chuỗi tiếng Anh khi đang vi (so với mọi chuỗi en không tham số mà bản vi dịch khác), không còn glyph ★/☆.
- Không còn ElevatedButton / TextButton / AlertDialog / SnackBar / Switch / Checkbox / Slider / AppBar / TabBar / progress Material trên các màn đã thử (hộp quảng cáo giả mặc định của core dùng AlertDialog nhưng `main.dart` tiêm bản vẽ tay `showSLSimulatedAd`).
- Vùng chạm ≥ 48×48 theo khung tham chiếu (1280×720, dpr 1) ở mọi màn; `textContrastGuideline` đạt.
- Bấm đúp: nâng thiết bị (có khoảng nghỉ), mua mở rộng, "Màn tiếp", "Bản đồ" rồi "Chơi lại" trong lúc chuyển cảnh, "Nhận" ở hộp vắng nhà, Cửa hàng rồi Cài đặt khi đang mờ dần — đều chỉ một hành động. Hai lần chạm thật cách 80 ms ở hộp xác nhận mua: chỉ mua một lần (route đang đóng bỏ qua chạm).
- Rewarded bị huỷ: không cộng xu / kim cương / giờ; hộp vắng nhà ở lại, "Nhận" vẫn cộng đúng một lần.
- Interstitial (đủ điều kiện): không gọi ở thẻ Sẵn sàng, trong màn, hộp +30 giây, lúc màn kết quả mới mở; gọi đúng một lần khi bấm "Bản đồ" ở màn kết quả.
- Lưu / mở lại: tiến trình còn nguyên, lần mở sau vào intro ngắn.

## Lỗi

### UI-01 — Nút bấm nhỏ hơn 48 dp trên máy thật (khung 1280×720 co theo dp)
- **Mức độ**: Major (khả năng tiếp cận; Pre-launch report của Play sẽ gắn cờ) — cần BA/PO xác nhận hướng sửa.
- **Màn hình**: mọi màn (bản đồ, kết quả, nâng cấp, trang trí, sổ công thức, cửa hàng, vé mùa, cài đặt).
- **Bước tái hiện**: máy 720×1600 dpr 2 (ngang 800×360 dp), hoặc 1080×2400 dpr 2,625 (~914×411 dp), hoặc tablet 2048×1536 dpr 2 (1024×768 dp); mở các màn trên; chạy `androidTapTargetGuideline` (`qa_touch_targets_test.dart`, nhóm "vùng chạm trên máy thật").
- **Mong đợi**: mọi vùng chạm ≥ 48×48 dp.
- **Thực tế** (720×1600 @2): nút tròn thanh trên bản đồ 27×27 dp, nút level 38×38, nút Quay lại 28×28, "Mua" 65×25 / 61×24, nút kết quả 115×34, hàng chọn ngôn ngữ ở Cài đặt cao 24 dp, bật/tắt Âm thanh 40×24. Máy 1080×2400: 31–47 dp. Tablet 1024×768 dp: nút thanh trên bản đồ 43×43, Quay lại 45×45, "Mua" cao 38–40, hàng Cài đặt cao 38–42.
- **Gợi ý nguyên nhân**: `lib/core/ref_frame.dart:33-36` (`FittedBox(fit: BoxFit.contain)` co cả khung theo cỡ logic: hệ số ≈ 0,5 trên điện thoại 360 dp cao, 0,57 trên 411 dp, 0,8 trên tablet) trong khi kích thước nút được thiết kế bằng px tham chiếu như thể là dp: `_MapAction` `size: 54` (`lib/ui/map/level_map_screen.dart:1051-1057`), `RoundIconButton` Quay lại (`lib/ui/common/sugar_screen.dart:60-64`), nút bí quyết `height: 48` (`lib/ui/recipes/recipe_book_screen.dart:581`), nút trang trí `height: 48` (`lib/ui/decor/decor_screen.dart:415`). Muốn ≥ 48 dp trên điện thoại 360 dp cao thì nút cần ~96 px tham chiếu, hoặc nới vùng chạm (padding trong suốt) cho nút nhỏ.

### UI-02 — RefFrame bỏ qua tai thỏ: nút sát mép nằm dưới tai thỏ trên máy 16:9
- **Mức độ**: Minor (máy 19,5:9 / 20:9 không bị vì viền kem rộng hơn tai thỏ; chỉ máy tỉ lệ ~16:9 có tai thỏ / đục lỗ).
- **Màn hình**: bản đồ, nâng cấp, trang trí, sổ công thức, cửa hàng, vé mùa, cài đặt.
- **Bước tái hiện**: cỡ 1280×720, `padding`/`viewPadding` trái-phải 48; mở các màn.
- **Mong đợi**: không vùng chạm nào có x < 48 hoặc x > 1232.
- **Thực tế**: nút Quay lại ở x = 20..76 (mọi màn có đầu trang); bản đồ: nút level / nút thanh trên ở x = 1192..1268, nút chương trước ở 14..74; trang trí: thẻ ở 822..1242; sổ công thức: thẻ món ở 38..153.
- **Gợi ý nguyên nhân**: `lib/core/ref_frame.dart:18-24` đặt `padding`/`viewPadding` = 0 cho bên trong và `lib/core/ref_frame.dart:31-37` căn giữa khung theo toàn màn, không trừ `MediaQuery.padding` của máy (không `SafeArea` quanh vùng khung). File này thuộc `dev-core`.

### UI-03 — Bấm đúp nút "Mua" mở hai hộp xác nhận chồng nhau (cửa hàng, vé mùa)
- **Mức độ**: Major (đồng ý ở cả hai hộp → mua hai lần; với IAP thật là trừ tiền hai lần nếu SDK không chặn).
- **Màn hình**: Cửa hàng (thẻ gói), Vé mùa (nút "Mở cao cấp").
- **Bước tái hiện**: hai lần chạm "Mua" trên thẻ gói lọt vào cùng một khung hình (hai ngón / máy chậm) — test gọi `onPressed` hai lần liền.
- **Mong đợi**: một hộp xác nhận.
- **Thực tế**: hai hộp "Simulated purchase" chồng nhau.
- **Gợi ý nguyên nhân**: `lib/ui/store/store_screen.dart:37-50` — `_buying` chỉ được đặt SAU `await showConfirmDialog`, trong lúc hộp đang mở chưa có cờ chặn; tương tự `lib/ui/season/season_pass_screen.dart:86-100`. Đặt cờ trước khi mở hộp xác nhận.

### UI-04 — Hai lần chạm "Mua"/"Huỷ" trong cùng khung hình ở hộp xác nhận đóng luôn màn bên dưới
- **Mức độ**: Minor (cần hai chạm cùng khung hình; hai chạm cách 80 ms thì không bị).
- **Màn hình**: Cửa hàng (và mọi chỗ dùng `showConfirmDialog`).
- **Bước tái hiện**: mở Cửa hàng → "Buy" gói kim cương M → ở hộp xác nhận gọi `onPressed` của "Buy" hai lần trong cùng khung hình.
- **Mong đợi**: mua một lần, vẫn ở Cửa hàng.
- **Thực tế**: mua một lần nhưng `pop` lần hai đóng luôn màn Cửa hàng (về bản đồ).
- **Gợi ý nguyên nhân**: `lib/ui/common/dialogs.dart:66` và `:72` — `Navigator.of(ctx).pop(...)` không kiểm route của hộp còn là route trên cùng (nên dùng cờ đã đóng, hoặc `if (ModalRoute.of(ctx)?.isCurrent ?? false)`).

### UI-05 — Nút "Học bí quyết" không chống chạm đúp: học 2 bậc, trừ xu 2 lần
- **Mức độ**: Major (mất xu ngoài ý muốn; thiết bị đã có khoảng nghỉ chống chạm đúp nhưng bí quyết thì không).
- **Màn hình**: Sổ công thức → khu Bí quyết của bà (mở từ L41).
- **Bước tái hiện**: qua L45, 20 000 xu, mở Sổ công thức (món chọn sẵn Cupcake vani) → chạm đúp "Learn".
- **Mong đợi**: lên 1 bậc, trừ đúng giá 1 bậc.
- **Thực tế**: lên 2 bậc (bậc 0 → 2) — mỗi lần `buyRecipeSecret` đều trừ giá bậc đó.
- **Gợi ý nguyên nhân**: `lib/ui/recipes/recipe_book_screen.dart:484-498` (`_SecretsSectionState._buy` gọi thẳng `buyRecipeSecret`, không cờ / khoảng nghỉ). So sánh `lib/ui/upgrades/upgrades_screen.dart:696-705` (thiết bị có `_cooling` + `_shownTier`).

### UI-06 — Thanh trên của bản đồ tràn khi xu rất lớn
- **Mức độ**: Trivial (cần ≥ ~100 triệu xu; chơi bình thường khó đạt).
- **Màn hình**: Bản đồ.
- **Bước tái hiện**: xu = 99 999 999 (kim cương 9 999) hoặc xu = kim cương = 999 999 999, en hoặc vi; mở bản đồ.
- **Mong đợi**: không tràn (số co lại / rút gọn).
- **Thực tế**: `A RenderFlex overflowed by 25 pixels on the right` (99 999 999 xu) / `48 pixels` (999 999 999 xu + kim cương); các màn khác (cửa hàng, nâng cấp, trang trí, sổ, vé mùa, thẻ Sẵn sàng, kết quả 999 999 999 xu) không tràn.
- **Gợi ý nguyên nhân**: `lib/ui/map/level_map_screen.dart:922` — `Row` gồm tổng sao + `CurrencyBar` + 8 nút `_MapAction` rộng cố định 76+4 px; chỉ phần tên chương là `Expanded`, nên khi chip xu/kim cương (`lib/ui/common/currency_bar.dart:26-30`, `minWidth` nhưng không giới hạn rộng) dài ra thì Row tràn.

### UI-07 — Huỷ quảng cáo thưởng báo nhầm "Hôm nay đã hết lượt nhận thưởng"
- **Mức độ**: Minor (alpha dùng quảng cáo giả không huỷ được; sẽ lộ ra khi nối SDK thật — người chơi đóng sớm / không tải được quảng cáo).
- **Màn hình**: Kết quả (×2 xu), Cửa hàng (kim cương miễn phí), thẻ Sẵn sàng (vật phẩm miễn phí), hộp +30 giây.
- **Bước tái hiện**: `AdService.showRewarded` trả `false` (đóng sớm) khi `canShowRewarded()` vẫn true; bấm "×2 coins (watch ad)".
- **Mong đợi**: không thưởng (đúng) và thông báo đúng lý do (vd. "Quảng cáo chưa xem xong") hoặc im lặng.
- **Thực tế**: toast "No more ad rewards today" / "Hôm nay đã hết lượt nhận thưởng" dù còn lượt.
- **Gợi ý nguyên nhân**: `lib/ui/level/level_result_screen.dart:90`, `lib/ui/store/store_screen.dart:80`, `lib/ui/level/level_screen.dart:289` và `:452` — nhánh `!watched` luôn dùng `l.adsLimitReached`. Cần một khoá chuỗi mới cho localizer (gợi ý `adNotCompleted`: en "The ad didn't finish — no reward this time" / vi "Quảng cáo chưa xem xong nên chưa có thưởng").

## Cần BA/PO xác nhận
- **Chuẩn vùng chạm (UI-01)**: khung 1280×720 có được coi là đơn vị dp không? Nếu chấp nhận nút ~30 dp trên điện thoại (phong cách game) thì hạ UI-01 xuống Minor; nếu theo chuẩn 48 dp của Android thì phải tăng cỡ / nới vùng chạm của gần như mọi nút.
- **Tai thỏ (UI-02)**: có hỗ trợ máy 16:9 có tai thỏ / đục lỗ không (ít gặp)?
- **"UI Gallery (debug)"** hiện trong Cài đặt ở bản debug (`kDebugMode`) — xác nhận không có trong bản release (test chạy ở debug nên không kiểm được).
- Hai chạm lọt cùng khung hình (UI-03, UI-04) — cách test hiện có của dự án (`navigation_guard_test.dart`) cũng coi đây là kịch bản cần chặn; xác nhận mức độ mong muốn.

## Chưa làm / giới hạn
- Không chụp ảnh golden (font test là Ahem nên ảnh không phản ánh thật); lỗi tái hiện bằng test.
- Màn chơi chỉ kiểm khung HUD sau khi bắt đầu (Flame chạy liên tục), không kiểm từng trạm bếp.
- Không thử bản release / thiết bị thật.
