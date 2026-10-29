import 'package:flutter/material.dart' show Icons;
import 'package:flutter/widgets.dart';

/// Ánh xạ tạm Material Icons → id [SLIcon] (Bước 3, đợt 1): widget chung còn nhận `IconData` (SugarButton,
/// RoundIconButton, PillChoice, TitleRibbon, TagChip, ArtIcon…) đổi qua đây để vẽ icon vẽ tay mà các màn chưa
/// phải sửa. Phủ mọi `Icons.*` đang dùng trong `lib/ui/**` và `lib/game/bake_session_view.dart` (test kiểm bằng
/// cách quét mã nguồn). Màn nào đã chuyển sang truyền id trực tiếp thì không cần bảng này nữa.
final Map<IconData, String> kSLIconForMaterial = {
  // Điều hướng.
  Icons.arrow_back_rounded: 'back',
  Icons.arrow_forward_rounded: 'forward',
  Icons.arrow_upward_rounded: 'arrow_up',
  Icons.arrow_downward_rounded: 'arrow_down',
  Icons.arrow_drop_down_rounded: 'arrow_down',
  Icons.fast_forward_rounded: 'skip',
  Icons.logout_rounded: 'exit',
  Icons.close_rounded: 'close',
  Icons.settings_rounded: 'settings',
  // Trạng thái.
  Icons.check_rounded: 'check',
  Icons.check_circle_rounded: 'check',
  Icons.task_alt_rounded: 'quest_board',
  Icons.lock_rounded: 'lock',
  Icons.info_rounded: 'info',
  Icons.science_rounded: 'info',
  Icons.warning_amber_rounded: 'warning',
  Icons.error_rounded: 'error',
  Icons.verified_rounded: 'medal_max',
  // Cài đặt.
  Icons.volume_up_rounded: 'sound_on',
  Icons.volume_off_rounded: 'sound_off',
  Icons.translate_rounded: 'language',
  Icons.phone_android_rounded: 'phone',
  Icons.delete_forever_rounded: 'trash',
  Icons.restart_alt_rounded: 'reset',
  // Quảng cáo.
  Icons.play_circle_fill_rounded: 'play_video',
  Icons.play_circle_outline: 'play_video',
  Icons.ondemand_video_rounded: 'play_video',
  Icons.block_rounded: 'no_ads',
  // Menu.
  Icons.storefront_rounded: 'storefront',
  Icons.shopping_bag_rounded: 'shop_bag',
  Icons.shopping_basket_rounded: 'basket',
  Icons.chair_rounded: 'decor_chair',
  Icons.chair_alt_rounded: 'decor_chair',
  Icons.menu_book_rounded: 'book',
  Icons.soup_kitchen_rounded: 'oven',
  Icons.card_giftcard_rounded: 'gift',
  Icons.receipt_long_rounded: 'ticket',
  Icons.eco_rounded: 'leaf_logo',
  // Ô trang trí.
  Icons.wallpaper_rounded: 'slot_wallpaper',
  Icons.grid_on_rounded: 'slot_floor',
  Icons.local_florist_rounded: 'slot_counter',
  Icons.window_rounded: 'slot_window',
  Icons.park_rounded: 'slot_plant',
  // Game.
  Icons.favorite_rounded: 'heart',
  Icons.workspace_premium_rounded: 'vip',
  Icons.people_alt_rounded: 'customer',
  Icons.wb_sunny_rounded: 'sun',
  Icons.umbrella_rounded: 'umbrella',
  Icons.water_drop_rounded: 'raindrop',
  Icons.pets_rounded: 'paw',
  Icons.bedtime_rounded: 'moon',
  Icons.local_fire_department_rounded: 'flame',
  Icons.auto_awesome_rounded: 'sparkle',
  Icons.emoji_events_rounded: 'trophy',
  Icons.celebration_rounded: 'confetti',
  Icons.schedule_rounded: 'clock',
  Icons.volunteer_activism_rounded: 'tip_jar',
  Icons.savings_rounded: 'coin',
  Icons.lightbulb_rounded: 'bulb',
  Icons.touch_app_rounded: 'tap',
  Icons.star_rounded: 'star',
  Icons.cake_rounded: 'cake_slice',
};

/// Id [SLIcon] của icon Material [icon]; chưa có trong bảng → null.
String? slIconIdOrNull(IconData icon) => kSLIconForMaterial[icon];

/// Id [SLIcon] của icon Material [icon]; chưa có trong bảng → 'sparkle' (hình trung tính, không bao giờ hiện
/// hình dự phòng chung vòng tròn + chữ cái).
String slIconIdFor(IconData icon) => kSLIconForMaterial[icon] ?? 'sparkle';
