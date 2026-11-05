# Đặc tả: điều khiển nhân vật, thao tác, nói chuyện với khách, sự kiện gây gổ (V3 3D)

pm viết ngày 03/11/2026, trưởng phòng ghi lại. Trạng thái: SẴN SÀNG. Phạm vi: cảnh thử `lib/main_shop3d.dart` (chạy trên web và Android).

## Những điều đọc trong code ảnh hưởng tới đặc tả
- Cảnh 3D là bản thử của GĐ a, chưa nối `LevelSession`. `MaterialApp` chưa có `localizationsDelegates`, chưa lưu game. Vì vậy phần thưởng chỉ tính trong phiên (Q1).
- Cột nút bên phải hiện có là nút debug: góc trên phải, 5 nút × 52 dp, chiếm y 12–312. Cụm nút thao tác đặt ở góc dưới phải.
- `ChibiPart.prop` được dựng liền vào model. Vật nhặt được phải là entity riêng, gắn vào tay bằng ma trận tính ở Dart và cập nhật qua `transformManager.setTransform` đồng bộ.
- Đồ đang cầm sẵn trong model:
  - Mai, Nora: tay trống.
  - Bảo: cây cán bột, hai tay.
  - Theo: khay trà, tay phải.
  - Ami: khay, hai tay.
  - Hạnh: bìa kẹp.
- Lưới `walk` trong `shop3d_scene.dart` đã có vỉa hè: z ∈ [4,3; 6,9], x ∈ [−7; 7]. Camera mặc định (yaw 0,4, pitch 34°, dist 9) không nhìn thấy vỉa hè, nên khi có sự kiện camera phải lia ra.
- Thoại theo mẫu `StoryLine(speaker, String Function(AppLocalizations) text)`.
- Xưng hô giữ như v2:
  - Hòa: ông / cháu.
  - Linh: em / chị Mai.
  - Kenji: tôi / cô.
  - Rosa: bà / cháu.
- Mochi là mèo xám. Khách thường chưa có tên riêng.

## 1. Mục tiêu và phạm vi
Chạm vào nhân viên bán hàng (Mai, Nora, Bảo, Theo; Ami và Hạnh nếu có trong cảnh) thì hiện 2 lựa chọn:
- **Điều khiển:** joystick tròn bên trái, cụm nút thao tác theo ngữ cảnh bên phải.
- **Nói chuyện với khách:** chọn khách, mở hộp thoại có lựa chọn.

Thỉnh thoảng có sự kiện khách gây gổ trước quán. Mai ra can và chọn 1 trong 3 cách giải quyết.

**Làm trong vòng 1:**
- Joystick:
  - va chạm với tường, quầy, bàn, ghế, cửa, vỉa hè;
  - đi trên bục theo `floorHeightAt`;
  - chạy khi đẩy hết cần;
  - camera bám nhân vật.
- Thao tác: Nhặt (sau đó ở trạng thái Cầm), Đặt xuống / Đặt lên, Ném, Mời bánh, Nói chuyện, Vẫy chào, Vuốt ve (Mochi), Can ngăn.
- 3 loại vật tương tác: cuộn len, hộp bánh (2 cái), bao bột (nên có).
- Menu khi chạm nhân viên, chọn khách để nói chuyện, khung hội thoại có lựa chọn.
- 8 mẩu chuyện, chuyện phiếm, 3 sự kiện gây gổ.
- "Thiện cảm ♥" và "xu thử" chỉ tính trong phiên.
- Mọi chuỗi qua AppLocalizations (en + vi), thêm l10n cho `main_shop3d.dart`.
- Test cho phần Dart thuần.

**Không làm (để GĐ b):**
- Nối kết quả vào kinh tế thật.
- Lưu truyện đã xem.
- Giới hạn sự kiện theo chương.
- Tạm dừng việc bán tự động khi đang điều khiển.
- Chạm sàn để đi tới; đường ngắm khi ném.
- Theo mời trà.
- Truyện cho Ami, Hạnh và các khách thường khác.
- Kéo co hộp bánh (nên có).

**Giai đoạn:**
- 1a: song song với việc sửa lỗi đứng hình, chỉ tạo file mới và sửa file arb.
- 1b: nối vào các file shop3d có sẵn, sau khi sửa xong lỗi đứng hình.
- 1c: `/quality-gate`.

## 2. Đặc tả

### 2.1 Joystick
Khung tham chiếu 1280×720; `s = chiều cao màn / 720`, kẹp trong khoảng 0,85–1,4.

**Hình dạng và vị trí:**
- Đế Ø136·s, nền kem 70%, viền nâu caramel 2 px.
- Núm Ø56·s, màu vàng bơ, viền nâu.
- Tâm đế tại (150, H−150)·s, cộng `MediaQuery.systemGestureInsets` và padding an toàn. Mép đế cách cạnh trái ≥ 80 dp.
- Chỉ hiện khi đang điều khiển; hiện và ẩn mờ dần trong 150 ms.

**Nhận chạm:**
- Vùng nhận là hình tròn bán kính 120·s. Ngón đặt ngoài vùng này vẫn xoay camera.
- Ngón đã bắt joystick thì giữ joystick cho tới khi nhấc lên.
- Ngón thứ hai chạm vào joystick bị bỏ qua.

**Hành trình và tốc độ:**
- Hành trình 52·s, đầu ra nằm trong [−1; 1]².
- Vùng chết: độ lớn < 0,15.
- Đi: độ lớn 0,15–0,8 ứng với 0,35–1,0 × `gait.speed` (Mai khoảng 0,9 m/s).
- Chạy:
  - độ lớn ≥ 0,8 thì chạy với 1,6 × tốc độ đi; độ lớn < 0,75 thì thôi chạy.
  - khi chạy (nên có): núm chuyển hồng dâu, thân ngả +0,08 rad, tay vung ×1,3.
- Cầm bao bột thì tốc độ tối đa 0,7 ×, không chạy được.

**Hướng đi theo camera:**
- `forward = (−sin yaw, −cos yaw)`, `right = (cos yaw, −sin yaw)`.
- Hướng = `jx·right + (−jy)·forward`. Đẩy cần lên thì đi ra xa camera.

**Quay người:** dùng `_turnToward`, hệ số tốc độ `max(0,35, cos lệch)`.

**Va chạm** (file mới `shop3d_nav.dart`, Dart thuần):
- Lưới ô 0,1 m, gồm 3 vùng đi được:
  - trong phòng: x ∈ [−5; 5], z ∈ [−4; 4];
  - khe cửa: x ∈ [3,05; 4,15], z ∈ [4,0; 4,2];
  - vỉa hè: x ∈ [−6,5; 6,5], z ∈ [4,45; 6,7].
- Ô bị chặn:
  - mọi `Shop3dPart` không flat có `minY < 1,4`, nên đèn thả 1,95 m không chặn;
  - tường;
  - ổ mèo.
- Bục (flat) vẫn đi được.
- Bán kính nhân vật = `model.radius`. Khi va thì trượt theo trục còn đi được.
- Gặp NPC thì coi NPC là hình tròn và trượt vòng qua.
- NPC theo kịch bản bị chắn đường (`ChibiDirector.blocked`):
  - sau 2 s hiện "Cho mình qua với!";
  - sau 4 s NPC được đi xuyên qua trong 1,5 s.
- `findPath`: A* có khoảng hở r = 0,3 m, rồi làm thẳng đường (string pulling).
- Nhân vật đứng sẵn trong ô chặn thì dời ra ô trống gần nhất.

**Camera khi điều khiển:**
- Bám nhân vật mượt (hệ số 6/s) ở độ cao `top.y × 0,62`.
- Vuốt, chụm, chạm đúp vẫn hoạt động như trước, nhưng tâm vẫn bám nhân vật.
- Không tự xoay ra sau lưng nhân vật.
- Khi nhân vật ra vỉa hè (z > 4,2): kéo mượt yaw về |yaw| ≤ 80°.

**Thôi điều khiển:**
- Bấm nút "Xong" (`commonDone`).
- Nhân vật đi A* về điểm đầu của bước kịch bản đang dở rồi chạy tiếp kịch bản.
- Đang cầm đồ thì đặt xuống trước chân.

**Bàn phím web (nên có):** WASD hoặc phím mũi tên để đi, Shift để chạy, E = nút A, Q = ném, Esc = Xong.

### 2.2 Cụm nút thao tác
Đặt ở góc dưới phải. Tọa độ nhân với s, cộng padding an toàn.

| Nút | Vị trí, cỡ | Khi hiện | Vai trò |
|---|---|---|---|
| A (chính) | tâm (W−128, H−128), Ø96 | luôn hiện | Theo ngữ cảnh; không có việc thì mờ, icon bàn tay |
| B "Ném" | tâm (W−236, H−200), Ø68 | đang cầm đồ ném được | Chạm nhanh: ném 2,5 m. Giữ 0,2–0,8 s: nạp lực 1,5 → 4,0 m, có vòng hồng dâu. Huỷ ngón thì không ném |
| C "Vẫy chào" | tâm (W−252, H−92), Ø60 | luôn hiện | Vẫy tay |
| "Xong" | 96×40 tại (W−128, H−250) | luôn hiện | Thôi điều khiển |

- Kiểu nút: nền vàng bơ, viền nâu 2 px, bo tròn, bóng mềm.
- Nhãn: Nunito đậm 13, 1 dòng.
- Vùng chạm ≥ 48 dp. Có `Semantics` lấy từ l10n.
- Đích của nút A (vật hoặc người) có mũi tên nhỏ nhấp nhô trên đầu.

**Nút A** (xét từ trên xuống, dùng dòng đầu tiên thoả điều kiện):
| # | Điều kiện | Nhãn | Kết quả |
|---|---|---|---|
| 1 | Là Mai, đang có sự kiện, cách tâm sự kiện ≤ 1,6 m | Can ngăn | Mở hội thoại sự kiện |
| 2 | Cầm hộp bánh, có khách không đang đi cách ≤ 2,0 m (tính cả qua quầy) | Mời bánh | Khách nhảy vui, nói "Cảm ơn nha!", +1♥ +5 xu. Hộp biến mất, 8 s sau hiện lại trên bàn đóng hộp. Mỗi khách nhận tối đa 1 lần / 60 s; quá thì khách nói "Mình no rồi, cảm ơn nha!" |
| 3 | Đang cầm đồ, mặt hướng vào mặt đặt được cách ≤ 0,6 m (bàn đóng hộp, quầy thấp, bàn trộn, bàn khách) | Đặt lên | Đặt lên mặt đó. Bao bột đặt lên bàn trộn: Bảo hoặc Mai nói "Cảm ơn nha!", 10 s sau bao bột về lại kệ |
| 4 | Đang cầm đồ | Đặt xuống | Đặt lên sàn, cách 0,4 m trước mặt |
| 5 | Tay trống, là Mai hoặc Nora, có vật cách ≤ 0,9 m | Nhặt | Cúi 0,35 s. Đồ nhẹ cầm tay trái; bao bột cầm hai tay |
| 6 | Có khách không đang đi cách ≤ 2,2 m | Nói chuyện | Mở hội thoại |
| 7 | Mochi cách ≤ 1,0 m, tay trống | Vuốt ve (`mochiPet`) | Mochi rù rù, hiện "Rừ rừ…", +1♥ ở lần đầu mỗi phiên |
| 8 | Không thoả dòng nào | (mờ) | — |

- Bảo, Theo, Ami, Hạnh bỏ qua các dòng 2–5 và không có nút B.
- **Vẫy chào:**
  - khách không đang đi trong bán kính 3 m vẫy lại (`react`);
  - lần đầu với mỗi khách trong phiên được +1♥;
  - hồi chiêu 8 s.

**Vật tương tác:** lưới `ChibiMeshBuilder` màu đỉnh, dùng chung material chibi. Mỗi vật là 1 entity, transform đồng bộ.
| Vật | Chỗ ban đầu | Cầm | Ném | Ghi chú |
|---|---|---|---|---|
| Cuộn len Ø0,14 m, hồng dâu | sàn cạnh ổ Mochi (4,0; 1,6) | 1 tay | được | Có Mochi thì Mochi chạy tới, vồ, rồi ngồi |
| Hộp bánh ×2, bạc hà, ruy băng kem | bàn đóng hộp (3,55 và 3,95; y 0,72; z −0,5), lấy từ phía nhân viên | 1 tay | không; bấm Q hiện "Bánh phải mời tận tay chứ!" | Dùng để Mời bánh |
| Bao bột (nên có) | kệ dưới (−4,8; −1,9), lấy từ `bakerShelf` | 2 tay, tốc độ ≤ 0,7× | không | Đặt lên bàn trộn |

**Vật lý khi ném** (Dart thuần):
- Bay parabol, g = 9,8, góc 30°, rời tay ở độ cao khoảng 0,8 m. Vận tốc suy từ quãng ném d ∈ [1,5; 4,0] m.
- Va prop hoặc tường thì bật ngang ×0,3 rồi rơi.
- Chạm sàn nảy 1 lần (hệ số 0,35), lăn tối đa 0,5 m.
- Vật luôn dừng trên sàn hoặc vỉa hè, trong biên. Rơi vào bên trong prop thì đẩy ra ô trống gần nhất.
- Mochi không bao giờ bị trúng.

**Ném trúng khách** (giữ cozy):
- Va chạm tính giữa hình cầu (vật) và hình trụ (khách).
- Khách `surprised` (nhảy nhỏ, giơ hai tay 0,5 s), hiện "Ơ!" rồi cười. Không bị trừ gì.
- Khách đang đi thì dừng 0,6 s.
- Nên có: len trúng khách thì 50% khách tung len trả lại.
- Một khách bị trúng ≥ 3 lần trong 30 s: hiện "Thôi mà!", khách `pout` 20 s (khoanh tay, quay mặt đi), −1♥.
- Trúng nhân viên: hiện "Ơ!", vật rơi xuống.

**Hành động mới của `ChibiActor`:**
- `bend`;
- `throwAnim`: lấy đà 0,15 s, ném 0,2 s;
- `surprised`;
- `pout`;
- `argue`: quay vào nhau, ngả về trước, tay vung 6 Hz, nhảy nhỏ, gật nhanh;
- `talk`: gật nhẹ, tay khua nhẹ.

### 2.3 Menu khi chạm nhân viên
- Chạm vào chibi có id thuộc {`mai`, `staff_nora`, `staff_bao`, `staff_theo`, `staff_ami`, `staff_hanh`, `*_fest`}:
  - nhân vật vẫn hop/react như cũ;
  - nhãn id được thay bằng 2 nút 168×48 xếp chồng trên đầu nhân vật: "Điều khiển" (`directions_walk`) và "Nói chuyện với khách" (`chat_bubble`).
  - Vị trí 2 nút chiếu bằng `_basis.project` như `_label`, bám theo đầu.
- Chạm ra ngoài thì đóng menu; tự đóng sau 5 s.
- Chạm vào khách: giữ như cũ. Nếu đang điều khiển nhân viên và khách cách ≤ 2,5 m thì mở luôn Nói chuyện.
- Chọn Điều khiển một người khác: người đang điều khiển được thả về kịch bản. Mỗi lúc chỉ điều khiển 1 người.

**Nói chuyện với khách:**
- Ứng viên là khách không đang đi: ở quầy, đang xếp hàng, đang ngồi, hoặc Mochi đang ngồi.
- Hiện chip tên cho tối đa 3 ứng viên gần nhất, kèm toast "Chọn khách để trò chuyện".
  - Chỉ có 1 ứng viên thì vào luôn.
  - Không có ai thì toast "Chưa có vị khách nào rảnh để trò chuyện."
- Khi đã chọn khách:
  - khách `pauseScript` (đang ngồi thì giữ ngồi) và quay về phía nhân viên;
  - nhân viên xa hơn 3,5 m thì tự đi A* tới cạnh khách, tối đa khoảng 5 s;
  - hai người quay mặt vào nhau;
  - nên có: camera bao khung cả hai người, tâm ở trung điểm, dist 5, yaw vuông góc với đường nối.
- Nói xong: khách `resumeScript`, camera trả về như trước.

### 2.4 Hệ hội thoại
`lib/game/shop3d/talk/talk_model.dart` (Dart thuần):
```dart
typedef TalkText = String Function(AppLocalizations l);
enum TalkRole { mai, a, b, staff, hoa, narrator }      // a/b = khách 1/2; hoa = nói vọng ra
class TalkLine   { final TalkRole who; final TalkText text; final TalkAnim? anim; }
class TalkChoice { final TalkText label; final String next; final TalkOutcome outcome; final TalkText? altLabel; }
class TalkNode   { final String id; final List<TalkLine> lines; final List<TalkChoice> choices; final String? next; }
class TalkOutcome{ final int hearts; final int coins; final Map<TalkRole, TalkMood> mood; final Set<TalkRole> leave;
                   final Set<TalkRole> joinQueue; final TalkSideEffect? effect; }  // mochiChaseYarn, randomWinner…
class TalkStory  { final String id; final Set<String> cast; final TalkCondition? when;
                   final String start; final Map<String, TalkNode> nodes; }
```
- `talk_runner.dart`: máy trạng thái câu → lựa chọn → node tiếp → kết thúc, cộng dồn kết quả. Không gọi `text`.
- `talk_stories.dart`: 8 mẩu chuyện và chuyện phiếm.
- `quarrel_events.dart`: 3 sự kiện.

**Luật chọn truyện:**
- Mỗi khách có 1 truyện, mỗi truyện chạy 1 lần mỗi phiên.
- Khách đã xem truyện hoặc không có truyện: Mai nói chuyện phiếm (1 câu của Mai + 1 câu đáp ngẫu nhiên của khách), +1♥, hồi chiêu 45 s mỗi khách.
- Nhân viên khác Mai: câu mở riêng của nhân viên + 1 câu đáp ngẫu nhiên, tối đa 1♥ mỗi khách / 60 s.
- Nói chuyện cộng tối đa 3♥ mỗi khách mỗi phiên. Sự kiện không tính vào trần này.

**Khung thoại** (`lib/ui/shop3d/dialogue_panel.dart`):
- Ở đáy màn, rộng `min(960, W−64)`, cao 168–200, nền kem, viền nâu 2 px, bo 20.
- Chip tên người nói dùng Fredoka.
- Câu thoại Nunito 22, tối đa 3 dòng, chữ hiện dần 40 ký tự/s.
- Chạm lần đầu hiện hết câu, chạm lần nữa sang câu sau. Gợi ý dùng `storyTapToContinue`.
- `storySkip` nhảy tới lựa chọn kế tiếp hoặc tới cuối. Không bao giờ bỏ qua lựa chọn.
- Lựa chọn: 2–3 nút xếp dọc ở cột phải rộng 320, mỗi nút cao ≥ 56.
- Nên có: dấu "…" trên đầu người đang nói.
- Khi hội thoại mở: ẩn joystick và cụm nút. Camera vẫn xoay được.
- Kết thúc: toast "+n thiện cảm · +m xu".

### 2.5 Sự kiện gây gổ
- Dữ liệu ở `quarrel_events.dart`. Lịch và máy trạng thái ở `quarrel_director.dart` (Dart thuần).

**Lịch:**
- Sự kiện đầu tiên sau 75 ± 15 s.
- Các sự kiện sau cách 150–210 s, tính từ lúc sự kiện trước kết thúc.
- Tối đa 1 sự kiện cùng lúc. 3 sự kiện chạy xoay vòng.
- Không bắt đầu khi đang có hội thoại.
- Tắt ở lineup, billboard và `actors=0`.
- Ép chạy để test: `?event=lastCake|first|tart`, `?events=0`, nút debug "event".

**Dựng nhân vật sự kiện:** cặp khách thường (`ChibiRegulars.build`) của sự kiện kế tiếp được dựng sẵn lúc rảnh bằng `Future.wait`, để ngoài scene (`removeFromScene`) và chỉ thêm vào khi tới giờ. Xong sự kiện thì gỡ.

**Vị trí:**
- Tâm sự kiện (2,2; 5,5).
- A đứng (1,75; 5,5), quay về +x. B đứng (2,65; 5,5), quay về −x.
- Mai đứng can ở (2,2; 4,8), quay về +z.
- A đi vào từ (−6,5; 6,2), B đi vào từ (6,5; 6,2).

**Máy trạng thái:**
1. Hai khách kéo tới, khoảng 6 s.
2. Cãi nhau: `argue` lặp lại, có "!" hoặc đám mây phồng trên đầu. Banner "Có chuyện ồn ào trước cửa tiệm!" kèm 2 nút:
   - "Xem": camera lia tới tâm (2,2; 0,9; 5,5), yaw 0,4, dist 7, pitch 30°, trong 2 s.
   - "Mai ra xem": Mai tự đi A* tới chỗ can. Người chơi đẩy joystick thì huỷ tự đi.
   - Nên có: mũi tên ở mép màn chỉ về sự kiện.
3. Mai tới cách ≤ 1,6 m: nút A đổi thành "Can ngăn". Nếu Mai tới bằng "Mai ra xem" thì hội thoại tự mở. Hội thoại có 3 lựa chọn.
4. Giải quyết:
   - Khách vui vào tiệm, đi một vòng `customerLoop` rồi ẩn. Trong lúc ở trong tiệm, nói chuyện với họ được (mở T6–T8).
   - Khách phụng phịu đi về một đầu vỉa hè rồi ẩn.

**Hết giờ:** sau 45 s chưa can thì hai khách phụng phịu bỏ đi, toast "Hai vị khách phụng phịu bỏ đi mất rồi…". Không trừ gì.

**Giới hạn:**
- Chỉ Mai can được.
- Mức độ: chỉ hài (cãi, giành, phồng má, khoanh tay, giậm chân). Không đánh nhau, không ngã đau, không xúc phạm.

### 2.6 Ca biên
- **Đổi người điều khiển:**
  - vật đang bay vẫn bay tiếp;
  - người cũ đặt đồ xuống và về kịch bản.
- **Khách đang đi:**
  - không nói chuyện được, không mời bánh được;
  - bị ném trúng thì dừng 0,6 s.
- **`pauseScript`:**
  - giữ nguyên bước kịch bản; đang ngồi thì giữ ngồi;
  - khách đang nhảy lên hoặc xuống ghế thì không phải ứng viên.
- **Thôi điều khiển khi đang đi tới khách:** huỷ cuộc nói chuyện.
- **Sự kiện tới lúc đang nói chuyện:**
  - sự kiện chờ hội thoại xong mới bắt đầu;
  - khi sự kiện đang diễn ra, Mai vẫn nói chuyện được với khách, nhưng đồng hồ hết giờ vẫn chạy.
- **Lineup, billboard, `actors=0`:** tắt hết.
- **Đa chạm:**
  - joystick và vuốt camera dùng song song được;
  - `Stack` chỉ dừng hit-test ở con đầu tiên trúng;
  - chụm chỉ tính các ngón ngoài joystick.
- **App vào nền hoặc pointer bị huỷ:** joystick về 0; đang nạp lực ném thì huỷ.
- **Web:**
  - mọi lớp nhận chạm nằm trên `ThermionWidget`;
  - không dùng `View.pick`;
  - bàn phím cần `Focus`;
  - con lăn chuột vẫn zoom.
- **Android:**
  - joystick cách mép ≥ 80 dp;
  - chế độ `immersiveSticky`: lần vuốt mép đầu tiên không bị bắt vào joystick;
  - màn rộng 1280–1600.
- **Máy yếu (PowerVR):**
  - không có lệnh Filament bất đồng bộ nào chạy mỗi khung;
  - vật không đổ bóng khi `softShadows=false`;
  - joystick vẽ bằng `CustomPainter`, có repaint notifier và `RepaintBoundary`;
  - bong bóng và chip dùng `ValueListenableBuilder`;
  - A* chỉ chạy khi cần.
  - Mục tiêu: FPS giảm ≤ 3; `chibi xf` tăng ≤ 0,15 ms khi không có sự kiện, ≤ 0,3 ms khi có.
- **Kẹt:**
  - nhân vật đứng trong ô chặn thì dời ra ô trống gần nhất;
  - A* không tìm ra đường thì đi thẳng có trượt; sau 3 s chưa tới thì dời thẳng tới đích;
  - có nút debug "reset items".

## 3. Nội dung
**Tên người nói:**
- Khoá có sẵn: `charMai`, `charHoa`, `charLinh`, `charKenji`, `charRosa`, `mochiName`.
- Khoá mới: `charNora` (Nora / Nora), `charBao` (Bảo / Bao), `charTheo` (Theo / Theo).

**Khách thường** (gọi theo loài):
| Khoá | vi | en | id |
|---|---|---|---|
| npcSquirrel | Bạn Sóc | Squirrel | regular_04 |
| npcHamster | Bé Hamster | Hamster | regular_01 |
| npcShiba | Cậu Shiba | Shiba | regular_05 |
| npcBlackCat | Bạn Mèo Mun | Black Cat | regular_06 |
| npcWalrus | Bác Hải Mã | Mr. Walrus | regular_13 |
| npcLion | Bác Sư Tử | Mr. Lion | regular_14 |

Ký hiệu: L = câu thoại, C = lựa chọn, R = câu đáp sau lựa chọn. Câu L đứng sau các nhánh C/R thì chạy sau cả hai nhánh.

### Mẩu chuyện Mai–khách
**T1 "Cú dậy sớm"** (`hoa`). Kết quả: C1 +1♥; C2 +1♥ +5 xu.
| Khoá | Ai | vi | en |
|---|---|---|---|
| talkHoaOwlL1 | Hòa | Người ta bảo cú thức đêm. Ông thì năm giờ sáng đã đứng trước cửa tiệm cháu rồi. | They say owls are night birds. Yet here I am at your door by five every morning. |
| talkHoaOwlL2 | Mai | Ông ơi, tiệm mở lúc bảy giờ mà! | But Mr. Hoa, we open at seven! |
| talkHoaOwlL3 | Hòa | Ông biết. Hai tiếng đó là để ngửi mùi bơ bay qua khe cửa. | I know. Those two hours are for smelling the butter through the door. |
| talkHoaOwlC1 | C | Mai mốt cháu mở cửa sớm cho ông nhé! | I'll open early for you, then! |
| talkHoaOwlR1 | Hòa | Đừng, đừng. Chờ đợi là một nửa cái ngon của tart trứng. | No, no. Waiting is half the flavour of an egg tart. |
| talkHoaOwlC2 | C | Vậy cháu nướng thơm hơn nữa, ông ngồi nhà cũng ngửi thấy! | Then I'll bake so well you can smell it from home! |
| talkHoaOwlR2 | Hòa | Thế thì ông hết cớ dậy sớm mất. Được, ông chịu. | Then I'd lose my excuse to wake up early. Very well, deal. |
| talkHoaOwlL4 | Mai | Vậy mai, chiếc tart đầu lò là của ông ạ. | Then tomorrow, the first tart out of the oven is yours. |

**T2 "Bức ký họa"** (`linh`). Kết quả: C1 +1♥; C2 +2♥.
| Khoá | Ai | vi | en |
|---|---|---|---|
| talkLinhSketchL1 | Linh | Chị Mai đứng yên chút nha! Em đang ký họa chị đó. | Mai, hold still! I'm sketching you. |
| talkLinhSketchL2 | Mai | Ơ, tóc chị đang dính đầy bột mà… | But I've got flour all over my hair… |
| talkLinhSketchL3 | Linh | Xong rồi! Chị xem nè. | Done! Take a look. |
| talkLinhSketchL4 | Mai | Linh ơi… sao chị lại thành cái bánh bao đeo tạp dề? | Linh… why am I a steamed bun wearing an apron? |
| talkLinhSketchL5 | Linh | Tại chị tròn tròn, mềm mềm, ấm ấm. Khen đó! | Because you're round, soft and warm. It's a compliment! |
| talkLinhSketchC1 | C | Vậy vẽ thêm cho chị cái nơ nhé! | Then give me a bow! |
| talkLinhSketchR1 | Linh | Hai cái luôn! Bánh bao xinh nhất thị trấn! | Two bows! The cutest bun in town! |
| talkLinhSketchC2 | C | Cho chị treo tranh cạnh quầy được không? | Can I hang it by the counter? |
| talkLinhSketchR2 | Linh | Thật hả? Chị nhìn nè, tai em dựng hết cả lên rồi! | Really? Look, my ears just shot straight up! |

**T3 "Đơn theo cảm xúc"** (`kenji`). Kết quả: C1 +1♥ +5 xu; C2 +1♥.
| Khoá | Ai | vi | en |
|---|---|---|---|
| talkKenjiCloudL1 | Kenji | Hôm nay tôi thấy mình như một đám mây định mưa… rồi đổi ý. | Today I feel like a cloud that meant to rain… then changed its mind. |
| talkKenjiCloudL2 | Mai | Một đám mây đổi ý… Để Mai nghĩ xem nào. | A cloud that changed its mind… Let me think. |
| talkKenjiCloudC1 | C | Bánh kem matcha: lúc đầu hơi đắng, rồi ngọt dần. | Matcha cake: a little bitter at first, then sweeter. |
| talkKenjiCloudR1 | Kenji | Đúng là đám mây đó. Tôi sẽ chụp nó trước khi ăn. | That's exactly the cloud. I'll photograph it before I eat. |
| talkKenjiCloudC2 | C | Cupcake vani, trắng và bông như mây. | A vanilla cupcake, white and fluffy like a cloud. |
| talkKenjiCloudR2 | Kenji | Hơi… theo nghĩa đen. Nhưng tôi thích sự thẳng thắn này. | A bit… literal. But I like your honesty. |
| talkKenjiCloudL3 | Kenji | Mỗi lần ghé đây, cuộn phim của tôi lại vơi đi một ít. | Every visit here, my film roll gets a little shorter. |

**T4 "Bí mật của quý bà"** (`vip_00` Rosa). Kết quả: C1 +1♥ +15 xu; C2 +2♥.
| Khoá | Ai | vi | en |
|---|---|---|---|
| talkRosaSecretL1 | Rosa | Cháu biết không, sáu mươi năm nay bà chỉ ăn bánh bằng nĩa bạc. | Do you know, dear, for sixty years I have eaten cake only with a silver fork. |
| talkRosaSecretL2 | Mai | Dạ… nhưng chóp mũi bà đang dính một chấm kem ạ. | Yes… but there's a dab of cream on the tip of your nose. |
| talkRosaSecretL3 | Rosa | Hừm. Chắc là… gió thổi vào. | Hmm. The wind must have blown it there. |
| talkRosaSecretL4 | Mai | Trong tiệm làm gì có gió ạ? | There's no wind indoors, though? |
| talkRosaSecretC1 | C | (Nháy mắt) Cháu không thấy gì đâu ạ. | (Wink) I didn't see a thing. |
| talkRosaSecretR1 | Rosa | Cô bé tinh ý. Đây, tip cho sự kín đáo. | Clever girl. Here's a tip for your discretion. |
| talkRosaSecretC2 | C | Bà nếm thử đi, kem hôm nay ngon lắm! | Go on, have a taste, today's cream is lovely! |
| talkRosaSecretR2 | Rosa | (Liếm thật nhanh) …Ngon thật. Đừng kể với ai nhé. | (A very quick lick) …It is lovely. Tell no one. |

**T5 "Cái bẫy bụng mèo"** (`mochi`, chỉ khi có Mochi trong cảnh). Kết quả: C1 +1♥; C2 +1♥, kèm `mochiChaseYarn` (len lăn ra 1,5 m).
| Khoá | Ai | vi | en |
|---|---|---|---|
| talkMochiBellyL1 | Mochi | Meo. | Mrrp. |
| talkMochiBellyL2 | Mai | Hôm nay em lại ướt sũng à? Lò còn ấm đó, ra hong lông đi. | Soaked again? The oven's still warm, go dry off. |
| talkMochiBellyL3 | dẫn truyện | (Mochi lăn ra, chìa cái bụng tròn mềm.) | (Mochi flops over and shows a fluffy belly.) |
| talkMochiBellyL4 | Mai | Bẫy đấy, chị biết mà. Xoa bụng là bị cắn. | It's a trap. I know it. Belly rubs mean bites. |
| talkMochiBellyC1 | C | Xoa bụng | Rub the belly |
| talkMochiBellyR1 | dẫn truyện | (Mochi ôm chặt tay Mai bằng cả bốn chân… và rù rù.) | (Mochi hugs Mai's hand with all four paws… and purrs.) |
| talkMochiBellyC2 | C | Lăn cuộn len cho em | Roll the yarn ball |
| talkMochiBellyR2 | dẫn truyện | (Mochi lao theo cuộn len, trượt một vòng trên sàn gỗ.) | (Mochi chases the yarn and skids a full circle across the floor.) |
| talkMochiBellyL5 | Mai | Đúng là đồ mèo con nghịch ngợm. | You little rascal. |

**T6 "Con cá ngày càng to"** (`regular_13`, mở sau Q3). Kết quả: C1 +1♥ +5 xu; C2 +1♥.
| Khoá | Ai | vi | en |
|---|---|---|---|
| talkWalrusFishL1 | Hải Mã | Cháu đoán xem sáng nay bác câu được con cá to cỡ nào? | Guess how big the fish I caught this morning was? |
| talkWalrusFishL2 | Mai | To cỡ nào ạ? | How big? |
| talkWalrusFishL3 | Hải Mã | To bằng… cái lò nướng của cháu! | As big as… your oven! |
| talkWalrusFishC1 | C | Tuần trước bác bảo nó to bằng cái tủ lạnh mà. | Last week you said it was as big as the fridge. |
| talkWalrusFishR1 | Hải Mã | Thì… nó lớn lên chứ! Cá cũng ăn bánh của cháu mà. | Well… it's been growing! Even the fish eat your pastries. |
| talkWalrusFishC2 | C | Thế bác có mang nó về không ạ? | Did you bring it home? |
| talkWalrusFishR2 | Hải Mã | Nó xin bác tha, hứa mai quay lại… còn to hơn. | It begged to be let go. Promised to come back tomorrow… even bigger. |
| talkWalrusFishL4 | Mai | Vậy mai cháu chuẩn bị cái lò to hơn ạ. | Then I'd better get a bigger oven ready. |

**T7 "Trả bằng hạt dẻ"** (`regular_04`, mở sau Q1). Kết quả: C1 +1♥; C2 +2♥.
| Khoá | Ai | vi | en |
|---|---|---|---|
| talkSquirrelNutL1 | Sóc | Chị ơi, em trả bằng hạt dẻ được không? Em có cả một kho! | Can I pay in chestnuts? I've got a whole stash! |
| talkSquirrelNutL2 | Mai | Ơ… tiệm chị chỉ nhận xu thôi em. | Oh… we only take coins here. |
| talkSquirrelNutL3 | Sóc | Khoan, để em lục cái đuôi… | Wait, let me check my tail… |
| talkSquirrelNutL4 | Sóc | Đây rồi! Ba đồng xu, một cái cúc áo, và… một hạt dẻ dự phòng. | Here! Three coins, a button, and… one emergency chestnut. |
| talkSquirrelNutC1 | C | Chị nhận xu thôi, hạt dẻ em giữ nhé. | I'll take the coins, you keep the chestnut. |
| talkSquirrelNutR1 | Sóc | Chị tốt ghê! Em sẽ chôn nó trước tiệm, mọc thành cây cho chị. | You're the best! I'll bury it outside so a tree grows for you. |
| talkSquirrelNutC2 | C | Đưa chị hạt dẻ, chị làm bánh hạt dẻ cho em! | Give me the chestnut, I'll bake you something with it! |
| talkSquirrelNutR2 | Sóc | Thật á? Để em đi lấy thêm… ở chỗ nào đó em quên mất rồi. | Really? I'll fetch more… from wherever I buried them. I forgot where. |

**T8 "Má phồng"** (`regular_01`, mở sau Q1). Kết quả: C1 +1♥ +5 xu; C2 +1♥.
| Khoá | Ai | vi | en |
|---|---|---|---|
| talkHamsterCheeksL1 | Hamster | Chị ơi, cho em… ưm-ưm-mm… | Could I have… mmf-mm-mmf… |
| talkHamsterCheeksL2 | Mai | Em ơi, hai má em đang nhét đầy bánh quy rồi kìa. | Sweetie, your cheeks are already full of cookies. |
| talkHamsterCheeksL3 | Hamster | (Nuốt ực) Đó là bánh để dành. Cái này là bánh để ăn! | (Gulp) Those are for later. This one is for now! |
| talkHamsterCheeksC1 | C | Để chị gói cho em một hộp mang về nhé. | Let me box some up for you to take home. |
| talkHamsterCheeksR1 | Hamster | Hộp á! Vậy hôm nay má em được nghỉ rồi! | A box! My cheeks get the day off! |
| talkHamsterCheeksC2 | C | Thử nhét thêm một cái nữa xem nào? | Think you can fit one more? |
| talkHamsterCheeksR2 | Hamster | Thử thì thử! …Ưm… vừa khít luôn. | Challenge accepted! …Mmf… perfect fit. |

### Chuyện phiếm
| Khoá | Ai | vi | en |
|---|---|---|---|
| smallTalkNora | Nora | Hôm nay bạn dùng như mọi khi chứ? Mình nhớ rồi nha! | Your usual today? I remember! |
| smallTalkBao | Bảo | …Bánh vừa ra lò. Còn ấm. | …Fresh out of the oven. Still warm. |
| smallTalkTheo | Theo | Trà hôm nay pha bằng nụ cười đó, uống thử đi! | Today's tea is brewed with a smile, give it a try! |
| smallTalkMai1 | Mai | Hôm nay trời đẹp ghê, bạn ra biển chưa? | Lovely day! Been down to the beach yet? |
| smallTalkMai2 | Mai | Mẻ bánh sau có thêm chút quế, ghé lại thử nha! | The next batch has a pinch of cinnamon, come back and try it! |
| smallTalkReply1 | khách | Cảm ơn nha, dễ thương quá! | Aw, thank you! |
| smallTalkReply2 | khách | Ngon tuyệt, mai mình lại ghé! | Lovely, I'll be back tomorrow! |
| smallTalkReply3 | khách | Tiệm này lúc nào cũng thơm ghê. | This place always smells so good. |

### Sự kiện gây gổ
**Q1 "Chiếc cupcake dâu cuối cùng"**: A = Sóc (`regular_04`), B = Hamster (`regular_01`). Hai bạn giành nhau chiếc cupcake dâu cuối cùng.

Kết quả:
- A: cả hai vui, vào tiệm; +2♥ +10 xu.
- B: người thắng (ngẫu nhiên) vào tiệm, người thua phụng phịu bỏ về; +1♥ +10 xu.
- C: cả hai rất vui, chờ 30 s trước cửa rồi vào tiệm; +3♥ +20 xu.

| Khoá | Ai | vi | en |
|---|---|---|---|
| quarrelLastCakeL1 | Sóc | Chiếc cupcake dâu này của em! Em thấy nó trước! | This strawberry cupcake is mine! I saw it first! |
| quarrelLastCakeL2 | Hamster | Nhưng em mơ về nó từ hôm qua cơ! | But I've been dreaming about it since yesterday! |
| quarrelLastCakeL3 | Sóc | Mơ thì không tính! | Dreaming doesn't count! |
| quarrelLastCakeL4 | Mai | Hai em ơi, từ từ nào, bánh sắp bẹp rồi kìa! | Easy, you two, the cupcake's getting squished! |
| quarrelLastCakeA | C | Chia đôi chiếc bánh | Split it in half |
| quarrelLastCakeRA1 | Hamster | Nửa cái… vừa khít một bên má! | Half… fits perfectly in one cheek! |
| quarrelLastCakeRA2 | Sóc | Nửa của em nhiều kem hơn. Hihi. | My half has more frosting. Hehe. |
| quarrelLastCakeB | C | Oẳn tù tì, ai thắng được bánh | Rock-paper-scissors for it |
| quarrelLastCakeRB1 | Mai | Oẳn tù tì… ra cái gì ra cái này! | Rock, paper, scissors… shoot! |
| quarrelLastCakeRB2 | người thắng | Em thắng rồi! | I win! |
| quarrelLastCakeRB3 | người thua | Hừm… lần sau em ra búa. | Hmph… next time I'm going rock. |
| quarrelLastCakeC | C | Mẻ cupcake mới sắp ra lò, mỗi em một cái! | A fresh batch is almost out, one each! |
| quarrelLastCakeRC1 | Sóc | Mỗi đứa một cái á?! | One EACH?! |
| quarrelLastCakeRC2 | Hamster | Chị đúng là thiên thần bánh ngọt! | You're a pastry angel! |

**Q2 "Ai đến trước?"**: A = Shiba (`regular_05`), B = Mèo Mun (`regular_06`). Hai bạn cãi nhau xem ai được vào trước.

Kết quả:
- A: cả hai vào tiệm, tấm biển "mở cửa" bị lệch; +1♥.
- B: cả hai vào tiệm, mèo để lại tiền tip; +2♥ +5 xu.
- C: cả hai vào tiệm, các khách đang đứng trong bán kính 3 m cười theo (`react`); +3♥.

Câu RC1 bản vi chơi chữ "bị bơ", bản en dùng một câu đùa khác cùng ý; localizer giữ nguyên cả hai bản.
| Khoá | Ai | vi | en |
|---|---|---|---|
| quarrelFirstL1 | Shiba | Tôi đứng đây từ lúc mặt trời mọc! Tôi vào trước! | I've been here since sunrise! I go first! |
| quarrelFirstL2 | Mèo Mun | Còn tôi ngủ trước cửa từ tối qua. Mèo là phải thế. | I napped on this doorstep all night. That's what cats do. |
| quarrelFirstL3 | Shiba | Ngủ thì không phải xếp hàng! | Napping isn't queueing! |
| quarrelFirstL4 | Mèo Mun | Với mèo thì có. | For cats, it is. |
| quarrelFirstL5 | Mai | Hai bạn ơi, hít thở sâu nào! | Okay, okay, deep breaths! |
| quarrelFirstA | C | Mời cả hai cùng vào, cửa rộng mà! | Come in together, the door's wide enough! |
| quarrelFirstRA1 | Shiba | …Hơi chật. | …It's a bit tight. |
| quarrelFirstRA2 | Mèo Mun | Cậu hóp bụng vào. | Suck in your tummy. |
| quarrelFirstRA3 | dẫn truyện | (Cả hai kẹt cứng ở cửa một giây… rồi cùng bật cười.) | (They're stuck in the doorway for a second… then both burst out laughing.) |
| quarrelFirstB | C | Xem dấu chân trên thảm cửa | Check the paw prints on the doormat |
| quarrelFirstRB1 | Mai | Dấu chân mèo ở dưới… dấu chân shiba đè lên trên. | Cat prints underneath… shiba prints on top. |
| quarrelFirstRB2 | Shiba | Thì… tôi đứng lên dấu chân cậu ấy thật. | Well… I did stand on their paw prints. |
| quarrelFirstRB3 | Mèo Mun | Cảm ơn. Cậu dễ thương lắm, đi sau tôi nhé. | Thank you. You're adorable. After me. |
| quarrelFirstC | C | Ai kể chuyện cười hay hơn được vào trước | Best joke goes first |
| quarrelFirstRC1 | Shiba | Vì sao bánh mì lúc nào cũng buồn? Vì toàn bị… bơ! | Why did the croissant see a doctor? It was feeling flaky! |
| quarrelFirstRC2 | Mèo Mun | …Dở tệ. Mà tôi cười rồi. Cậu vào trước đi. | …That was awful. I laughed. You go first. |

**Q3 "Tart trứng hay pie táo?"**: A = Hải Mã (`regular_13`), B = Sư Tử (`regular_14`). Hai bác cãi nhau món nào ngon hơn.

Kết quả:
- A: cả hai vui, vào tiệm; +3♥ +30 xu.
- B: cả hai vào tiệm nhưng vẫn lườm nhau (`pout` 10 s); +0♥ +10 xu.
- C (hoặc CAlt): Hải Mã vui, vào tiệm; Sư Tử phồng má bỏ về; +2♥ +10 xu.

Nếu ông Hòa có trong cảnh thì dùng lựa chọn C, nếu không thì dùng CAlt.

| Khoá | Ai | vi | en |
|---|---|---|---|
| quarrelTartL1 | Hải Mã | Tart trứng là vua các loại bánh! Giòn, béo, vàng như mặt trời! | Egg tarts are the king of pastries! Crisp, rich, golden as the sun! |
| quarrelTartL2 | Sư Tử | Vua à? Vua là tôi đây. Và vua chọn pie táo. | King? I'm the king around here. And the king picks apple pie. |
| quarrelTartL3 | Hải Mã | Ông thì được mỗi cái bờm to! | All you've got is a big mane! |
| quarrelTartL4 | Sư Tử | Còn ông thì được mỗi cái bụng tròn! | And all you've got is a round belly! |
| quarrelTartL5 | Mai | Hai bác ơi, cả phố đang nhìn kìa! | Gentlemen, the whole street is watching! |
| quarrelTartA | C | Mời hai bác bịt mắt nếm thử cả hai | Blind taste test, try both! |
| quarrelTartRA1 | Hải Mã | Cái này… ngon hơn. Là pie táo à?! | This one's… better. It's the apple pie?! |
| quarrelTartRA2 | Sư Tử | Còn tôi chọn… tart trứng. Ôi không. | And I picked… the egg tart. Oh no. |
| quarrelTartRA3 | Hải Mã | Thôi, mua cả hai! | Fine, we'll buy both! |
| quarrelTartB | C | Bánh nào cũng ngon, hai bác bắt tay nhé! | Every pastry is delicious, shake hands! |
| quarrelTartRB1 | Sư Tử | Đúng là câu trả lời của nhà ngoại giao. | Spoken like a diplomat. |
| quarrelTartRB2 | Hải Mã | Nhạt như bột chưa nêm. | Bland as unseasoned dough. |
| quarrelTartC | C (có Hòa) | Gọi ông Hòa ra phân xử | Ask Mr. Hoa to settle it |
| quarrelTartCAlt | C (không Hòa) | Bắt chước giọng ông Hòa | Do your best Mr. Hoa impression |
| quarrelTartRC1 | Hòa (nói vọng ra) | Tart trứng. Bốn mươi năm rồi, không bàn cãi. | Egg tart. Forty years. Not up for debate. |
| quarrelTartRC1Alt | Mai (giọng ồm) | E hèm… Tart trứng. Bốn mươi năm rồi, không bàn cãi. | (Deep voice) Ahem… Egg tart. Forty years. Not up for debate. |
| quarrelTartRC2 | Hải Mã | Nghe chưa! Nghe chưa! | Hear that? Hear that! |
| quarrelTartRC3 | Sư Tử | Hừm. Hội người cao tuổi thiên vị. | Hmph. The seniors' club is biased. |

**Chuỗi chung của sự kiện:**
| Khoá | vi | en |
|---|---|---|
| quarrelBanner | Có chuyện ồn ào trước cửa tiệm! | There's a commotion outside! |
| quarrelLook | Xem | Look |
| quarrelSendMai | Mai ra xem | Send Mai |
| quarrelIntervene | Can ngăn | Step in |
| quarrelTimeout | Hai vị khách phụng phịu bỏ đi mất rồi… | The two customers stomped off in a huff… |
| quarrelPeace | Trước cửa tiệm lại yên bình. | Peace returns to the street. |

## 4. Bảng giao việc
| Người | File / khu vực | Việc | Tiêu chí xong | Phụ thuộc |
|---|---|---|---|---|
| localizer | `lib/l10n/app_en.arb`, `app_vi.arb` | Thêm mọi khoá ở mục 3 và mục 5 | Hai file có cùng tập khoá; placeholder khai báo trong en; chuỗi trên nút ≤ 14 ký tự | Chạy ngay |
| trưởng phòng | — | Chạy `flutter gen-l10n` | Có getter mới | Sau localizer |
| dev-ui | file mới `lib/ui/shop3d/joystick.dart`, `action_cluster.dart`, `staff_menu.dart`, `dialogue_panel.dart`, `shop3d_toasts.dart`; `test/ui/shop3d/*` | Widget thuần, nhận chuỗi, icon và callback qua tham số; không import `lib/game` hay thermion | Có widget test cho: vùng chết; chạy có trễ (hysteresis); bỏ qua ngón thứ hai; pointer bị huỷ thì về 0; nút B phân biệt chạm nhanh và giữ; khung thoại không bỏ qua lựa chọn | Chạy ngay |
| dev-game (phụ) | file mới `lib/game/shop3d/interact/shop3d_nav.dart`, `shop3d_items.dart`, `pilot_rules.dart`, `talk/talk_model.dart`, `talk_runner.dart`, `quarrel_director.dart`; test `test/game/shop3d/interact/*`, `talk/*` | Dart thuần, không import thermion | Không đi xuyên quầy, bàn, tường; qua được khe cửa và lối nhân viên; A* tìm được đường từ `staffMixerFar` ra tâm sự kiện; vật ném luôn dừng trên sàn hoặc vỉa hè; bảng nút A đủ 8 dòng; runner không bỏ qua lựa chọn, cộng dồn đúng; director chạy đúng lịch, hết giờ sau 45 s, không bắt đầu khi đang có hội thoại | Chạy ngay |
| dev-game (phụ) | file mới `talk/talk_stories.dart`, `talk/quarrel_events.dart` | Dữ liệu cho T1–T8, chuyện phiếm, Q1–Q3 | Mọi node đều tới được; lựa chọn nào cũng có kết quả | Sau gen-l10n |
| dev-game (chính) | `chibi/chibi_actor.dart`, `chibi_rig.dart`, `chibi_cast.dart`, `shop3d_scene.dart`, `shop3d_view.dart`, `lib/main_shop3d.dart`, file mới `interact/pilot.dart` | Nối toàn bộ (chi tiết ngay dưới bảng) | Web và APK chạy đủ các luồng; FPS giảm ≤ 3; test cũ vẫn qua; không còn chuỗi viết cứng | Sau khi sửa xong lỗi đứng hình, sau dev-ui và dev-game (phụ) |
| reviewer → tester / design / qa | — | `/quality-gate` | | Sau dev-game (chính) |

**dev-game (chính) – các phần cần nối:**
- `ChibiActor`:
  - `drive`;
  - `pauseScript` / `resumeScript`;
  - quay về kịch bản bằng A*;
  - các hành động mới;
  - tư thế cầm vật.
- `ChibiRig`: điểm bàn tay trong toạ độ thế giới.
- `ChibiDirector`:
  - biết đang điều khiển nhân vật nào;
  - luật nhường đường 2 s / 4 s.
- Scene:
  - entity vật;
  - hộp chạm;
  - cặp khách sự kiện dựng sẵn, ẩn/hiện;
  - API lái nhân vật.
- View:
  - lớp phủ dùng widget của dev-ui, đặt trên `ThermionWidget`;
  - menu chạm nhân viên;
  - camera bám, giới hạn yaw khi ra vỉa hè;
  - banner và nút Xem của sự kiện;
  - khung thoại;
  - toast ♥/xu;
  - phím tắt trên web.
- `main_shop3d`:
  - l10n delegates và `?lang=`;
  - `?event=`, `?events=0`;
  - nút debug "event" và "reset items".

## 5. Chuỗi giao diện mới
Gồm mọi khoá ở mục 3, thêm các khoá sau:
| Khoá | vi | en |
|---|---|---|
| staffMenuControl | Điều khiển | Control |
| staffMenuTalk | Nói chuyện với khách | Talk to a customer |
| actionPickUp | Nhặt | Pick up |
| actionPutDown | Đặt xuống | Put down |
| actionPlaceOn | Đặt lên | Place |
| actionGive | Mời bánh | Offer |
| actionThrow | Ném | Throw |
| actionTalk | Nói chuyện | Talk |
| actionWave | Vẫy chào | Wave |
| controlHint | Kéo vòng tròn bên trái để đi, bấm nút bên phải để thao tác. | Drag the left circle to walk, tap the right buttons to act. |
| talkPickCustomer | Chọn khách để trò chuyện | Pick a customer to chat with |
| talkNoCustomer | Chưa có vị khách nào rảnh để trò chuyện. | No customers are free to chat right now. |
| itemYarn | Cuộn len | Yarn ball |
| itemCakeBox | Hộp bánh | Cake box |
| itemFlour | Bao bột | Flour sack |
| reactOops | Ơ! | Oops! |
| reactStop | Thôi mà! | Hey, quit it! |
| reactThanks | Cảm ơn nha! | Thank you! |
| reactFull | Mình no rồi, cảm ơn nha! | I'm full, but thank you! |
| reactNoThrowCake | Bánh phải mời tận tay chứ! | Cake is handed, not thrown! |
| reactExcuseMe | Cho mình qua với! | Excuse me! |
| reactPurr | Rừ rừ… | Purr… |
| interactGoodwill | +{count} thiện cảm | +{count} goodwill (placeholder `count` int) |
| interactCoins | +{count} xu | {count, plural, =1{+1 coin} other{+{count} coins}} |

Dùng lại các khoá có sẵn: `commonDone`, `commonClose`, `storyTapToContinue`, `storySkip`, `mochiPet`, `mochiName`, `charMai`, `charHoa`, `charLinh`, `charKenji`, `charRosa`.

## 6. Rủi ro và quyết định tạm
**Rủi ro:**
1. Trùng file với việc sửa lỗi đứng hình, nên phần nối code phải làm sau.
2. Các lệnh `flutter` có thể tự chạy `pub get`; `flutter test` cần MSVC (ghi chú API mục 9.4). Trưởng phòng xếp lượt chạy các lệnh này.
3. Máy yếu có thể giật khi tạo nhân vật sự kiện, nên dựng sẵn từ trước.
4. Sửa `ChibiActor` có thể làm hỏng kịch bản cũ, nên giữ các test cũ.
5. Lưới va chạm có thể lệch so với mô hình (nên thêm `?nav=1`).
6. Chuỗi tiếng Việt dài, dễ tràn chỗ.
7. Nội dung phải nguyên bản, chỉ ở mức hài, hợp người chơi 13+.

**Quyết định tạm** (chủ dự án có thể đổi):
- Q1: phần thưởng là ♥ và xu thử, chỉ tính trong phiên.
- Q2: "trước quán" nghĩa là vỉa hè.
- Q3: "Cầm" là trạng thái sau khi Nhặt, không phải một nút riêng.
- Q4: chỉ Mai và Nora nhặt và ném được; chỉ Mai can được.
- Q5: ném trúng khách chỉ làm khách giật mình; trúng 3 lần trong 30 s thì −1♥.
- Q6: khách thường gọi theo loài.
- Q7: T6–T8 chỉ mở sau sự kiện.

KẾT LUẬN: SẴN SÀNG
