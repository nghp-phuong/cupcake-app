# Bàn giao cho dev-game (chính): nối tính năng tương tác vào cảnh 3D

Đặc tả: `docs/v3/interaction-spec.md`. File này ghi API do các người làm trước để lại.

## dev-ui: widget lớp phủ (`lib/ui/shop3d/`, đã xong, `dart analyze` sạch)

**Quy ước chung:**
- Mọi widget tự trả về `Positioned` hoặc `Positioned.fill`, nên phải đặt làm con của `Stack` nằm trên `ThermionWidget`.
- Chỉ phần nhìn thấy của widget nhận chạm. Chạm vào chỗ trống đi xuống lớp camera.
- Thứ tự trong `Stack`: joystick, cụm nút, rồi đến menu, khung thoại, banner, toast.
- Widget không import `lib/game` hay thermion, chỉ nhận String đã dịch.

**Joystick** (`joystick.dart`)
```dart
Shop3dJoystickController()  // dispose()
  ValueListenable<Offset> value   // [-1,1]², y màn (đẩy lên = y âm), 0 trong vùng chết
  ValueListenable<bool> running   // vào ≥0,8, thôi <0,75
  ValueListenable<bool> active    // có ngón/bàn phím giữ → huỷ "Mai tự đi"
  void drive(Offset v)            // bàn phím web, chỉ khi không có ngón
  void reset();
Shop3dJoystickGeometry.of(Size, {EdgeInsets padding, EdgeInsets gestureInsets}) // contains(Offset): loại ngón khỏi phép chụm camera
const Shop3dJoystick({required Shop3dJoystickController controller, bool visible = true})
```
Hướng đi = `jx·right + (−jy)·forward`, với `jy = controller.value.value.dy`.

**Cụm nút** (`action_cluster.dart`)
```dart
const Shop3dActionCluster({required String primaryLabel, required IconData primaryIcon, required VoidCallback? onPrimary /*null = mờ*/,
  String? primarySemanticsLabel, bool showThrow = false, String throwLabel = '', IconData throwIcon,
  VoidCallback? onThrowTap, ValueChanged<double>? onThrowCharged /*lực 0..1*/, VoidCallback? onThrowChargeStart, VoidCallback? onThrowCancel,
  required String waveLabel, IconData waveIcon, required VoidCallback? onWave, ValueListenable<double>? waveCooldown /*1→0*/,
  required String doneLabel, required VoidCallback? onDone, bool visible = true})
```

**Menu nhân viên** (`staff_menu.dart`)
```dart
const Shop3dStaffMenu({Key? key, required Offset anchor /*đỉnh đầu, toạ độ màn*/, required String controlLabel, required String talkLabel,
  required VoidCallback onControl, required VoidCallback onTalk, required VoidCallback onDismiss,
  Duration autoClose = const Duration(seconds: 5)})
```
- Giữ nguyên `key` để menu bám theo đầu mà không bị đếm lại giờ.
- Bấm vào một nút thì menu không gọi `onDismiss`; người nối tự gỡ menu.

**Khung thoại** (`dialogue_panel.dart`)
```dart
const Shop3dDialoguePanel({required String? speaker /*null = lời dẫn*/, required String text, required String tapHint, required String skipLabel,
  List<String> choices = const [], VoidCallback? onNext, VoidCallback? onSkip /*null = không có nút*/, ValueChanged<int>? onChoice,
  Object? lineId /*phải khác nhau nếu hai câu liền nhau trùng chữ*/, Color speakerColor, double charsPerSecond = 40})
```

**Lớp phủ nhỏ** (`shop3d_toasts.dart`)
- `Shop3dEventBanner(message, primaryLabel, onPrimary, secondaryLabel, onSecondary, …)`
- `Shop3dToastController` (`show(String, {icon, duration})`) đi cùng `Shop3dToastHost(controller)`.
- `Shop3dHeadBubble(anchor, text, kind: speech|exclaim|puff|thinking)`. Dùng `thinking` để hiện dấu "…" trên đầu người đang nói.
- `Shop3dNameChip(anchor, label, onTap, highlighted)`
- `Shop3dTargetArrow(anchor)`: hoạt ảnh lặp vô hạn, nên test không được dùng `pumpAndSettle` khi mũi tên đang hiện.
- `Shop3dStyle` (hệ số s), `Shop3dPillButton`.

## localizer
- Đủ khoá của mục 3 và mục 5 trong đặc tả, đã chạy `flutter gen-l10n`.
- Các vai "dẫn truyện", "khách", "người thắng", "người thua" không có chuỗi tên riêng. Người nói lấy tên từ `char*` / `npc*`.

## dev-game (phụ): Dart thuần (`lib/game/shop3d/interact/`, `talk/`); `dart analyze` sạch; 123 test chạy qua bằng giả lập `flutter_test`

**Lưới va chạm và tìm đường** (`shop3d_nav.dart`)
- `Shop3dNav.fromLayout({owned, floorHeight})` tự đọc `Shop3dLayout.props`: bỏ prop flat và prop có minY ≥ 1,4. Phải dựng lại khi `owned` đổi.
- Hàm:
  - `canStand(x, z, r)`;
  - `slide(x, z, dx, dz, r, {out, others: List<NavCircle>})` → `NavMove{x, z, blocked}`;
  - `nearestFree`;
  - `findPath(fromX, fromZ, toX, toZ, {clearance: 0.3})`: kết quả không gồm điểm xuất phát; đích bị chặn thì trả ô trống gần đích nhất;
  - `floorHeight`, `sphereBlocked`.
- Khe cửa thông tới z = 4,45 (`walkMinZ`).

**Vật** (`shop3d_items.dart`)
- `ItemBoard(nav, {owned})`, các vật có id: yarn, cakeBox0, cakeBox1, flour.
- Hàm:
  - `pickUp`, `putDown`, `findPlaceTarget`;
  - `placeOn`: trả true khi đặt bao bột lên bàn trộn, lúc đó cho nhân vật nói "Cảm ơn nha!";
  - `consume`: tặng hộp bánh, 8 s sau hiện lại;
  - `throwItem(item, x, z, yaw, distance)`, quãng ném lấy từ `ItemPhysics.distanceForHold(giây giữ)`;
  - `update(dt, List<ItemTarget>)` → `List<ItemEvent>` (hitTarget | landed);
  - `reset()`.
- Khi vật ở trạng thái `held`, người nối tự ghi x/y/z theo điểm bàn tay. `y` là độ cao đáy vật.
- `ThrowHitTracker.register(guestId, now)` → surprised | pout | alreadyPouting. Trả `pout` thì trừ 1♥.

**Nút A** (`pilot_rules.dart`)
- `PilotRules.decideA(PilotSnapshot)` → `PilotDecision{action, targetId, enabled}`.
- `PilotSnapshot` nhận:
  - `role`, `x`, `z`, `held`;
  - `guests: List<PilotGuest(id, x, z, walking)>`;
  - `items`, `mochiX`, `mochiZ`;
  - `event: PilotEventInfo(id, x, z, canIntervene)`;
  - `placeSurfaceId`: lấy từ `ItemBoard.findPlaceTarget`.
- Hàm khác:
  - `PilotRole.ofId`;
  - `throwVisible`, `checkThrow`, `speedFactor`, `canRun`;
  - `PilotCooldowns.offer` / `wave` / `pet`.

**Hội thoại**
- `talk_model.dart`: `TalkLine(who, text, {anim, alt})`. `alt` là câu thay thế, dùng cho Q3 khi không có ông Hòa. `TalkStory.validate()` kiểm tra cấu trúc truyện.
- `TalkRunner(story, {useAlt})`:
  - `advance`, `choose`, `skip`;
  - trạng thái `phase` (line | choice | done);
  - `line`, `choices`, `labelOf`, `totals`.
- `TalkLedger.pick(guestId, byMai, stories, world, now)` → `TalkPick`. `finishStory` áp trần 3♥ cho mỗi khách.

**Sự kiện gây gổ** (`QuarrelDirector({rng, eventIds, enabled})`)
- `update(dt, {dialogueOpen})` trả về: gatherStarted | arguingStarted | timedOut | ended.
- Hàm điều khiển:
  - `forceStart`;
  - `beginIntervention`, `cancelIntervention`;
  - `resolve`, `endAftermath`, `abort`;
  - `requestSendMai`, `cancelSendMai`, `maiArrived`.
- Getter: `canIntervene`, `nextEventId` (để dựng sẵn cặp khách), `timeoutRemaining`.
- Thời gian 45 s tính từ lúc bắt đầu cãi. Hội thoại can ngăn tạm dừng đồng hồ.

**Dữ liệu truyện** (phần 2 của dev-game phụ)
- `TalkStories.all`: 8 truyện có id owl, sketch, cloud, secret, belly, fish, nut, cheeks.
- `TalkSmallTalk.build({byMai, staffId, openIndex, replyIndex})`.
- `TalkNames.of(id)`: lấy tên người nói theo id.
- `QuarrelEvents.byId[eventId]`: eventId là lastCake, first hoặc tart.
- Vai `TalkRole.winner` / `TalkRole.loser`: sau khi bốc thăm `randomWinner`, ánh xạ hai vai này về a/b.
- Khách trong truyện luôn là vai `a`.
- Xong sự kiện thì thêm id sự kiện vào `TalkWorld.doneEvents`, để mở T6–T8.
- Hiệu ứng: `mochiChaseYarn`, `randomWinner`, `delayedEnter`, `signCrooked`, `catTip`, `crowdLaughs`, `glareAtEachOther`.

## dev-game (chính): đã nối (03–04/11)

**Điều phối** `lib/game/shop3d/interact/pilot.dart` — `Shop3dPilot(world, {rng, events, quarrel, stories})`, Dart thuần.
- `Shop3dPilotWorld` (cảnh cài đặt; test dùng bản giả): `director`, `owned`, `readyModel(id)`, `prepareModels(ids)`,
  `addActor` / `removeActor`.
- Mỗi lần cập nhật chibi (trong `Shop3dScene._updateChibis`): `update(dt)` → `ChibiDirector.update` → `lateUpdate()`.
- Đầu vào: `cameraYaw`, `setStick(jx, jy, running:, active:)`; thao tác: `control(id)`, `release()`, `pressA()`,
  `throwTap()`, `throwCharged(power)`, `throwHeld(seconds)` (phím Q), `wave()`, `talkFrom(staffId)`,
  `choosePick(id)`, `cancelPick()`, `tapGuest(id)`, `startTalk(staff, guest)`, `talkNext()`, `talkSkip()`,
  `talkChoose(i)`, `sendMai()`, `forceEvent([id])`, `resetItems()`, `setOwned(owned)`.
- Đầu ra (`ValueListenable`): `hud` (`PilotHud`: người đang điều khiển, quyết định nút A, hiện nút Ném, đang mở thoại),
  `talk` (`PilotTalkLine`), `pick` (chip tên), `banner`, `waveCooldown`, `hearts`, `coins`, `bubblesRevision` +
  `bubbles`; `takeNotices()` (toast); `followPoint()`, `onSidewalk`, `targetPoint()`, `eventPair`.
- Hàm thuần: `Shop3dPilot.stickToWorld`, `Shop3dPilot.speedFactor`, `Shop3dPilot.isStaffId`, `pilotRewardText`.

**`ChibiActor` (mở rộng, kịch bản cũ không đổi):** `startDriving` / `driveMove` / `driveFace` / `stopDriving(route:)`,
`driveRunning`; `pauseScript` / `resumeScript(route:)`; `followRoute(route, hold:, limit:)` / `cancelRoute`;
`perform(action, seconds, faceYaw:, freeze:)` với hành động mới `bend`, `throwAnim`, `surprised`, `pout`, `argue`,
`talk`; `setScript(steps, once:)` + `done`; `carry` (`ChibiCarry`); `handWorld(side, out)`; `isBusyMoving`,
`isHopping`, `scriptResumePoint`, `speedScale`. `ChibiDirector`: NPC bị người đang lái / người đang đứng nói chuyện chắn
2 s → `excuseMe` ("Cho mình qua với!"), 4 s → đi xuyên 1,5 s.

**Cảnh / view:** `Shop3dScene.attachPilot(pilot)` (entity 4 vật, lưới `interact/item_meshes.dart`), cặp khách sự kiện
dựng sẵn / ẩn hiện; `Shop3dView(interactive:, events:, forceEvent:, initialPilot:)` dựng lớp phủ của dev-ui, camera bám
nhân vật, lia camera "Xem", phím tắt web. Tham số URL: xem đầu `lib/main_shop3d.dart`.

**Lệch đặc tả / chưa làm (nên có):** chưa có camera bao khung khi nói chuyện, mũi tên mép màn chỉ sự kiện, len trúng
khách tung trả lại, `?nav=1`; tư thế lấy đà khi đang giữ nút Ném (chỉ diễn ném lúc thả). Bán kính va chạm của nhân vật
điều khiển kẹp ≤ 0,27 m (lưới nav kiểm theo 0,27; bếp hẹp). Vẫy / mời bánh / ném trúng không qua trần 3♥ của nói
chuyện (đặc tả chỉ đặt trần cho nói chuyện).
