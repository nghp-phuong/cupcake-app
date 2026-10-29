/// Bộ design system vẽ tay Sugarleaf (SL*): giấy, gỗ, vải, viền mực run tay, màu nước.
/// Mọi hình vẽ bằng CustomPainter với seed cố định, cache Picture/Path trong LRU (`paint/sl_cache.dart`).
library;

// Hình + tiện ích vẽ tay dùng ở màn khác (màn không import thẳng `paint/*.dart`).
export 'paint/hand_drawn.dart' show SLCircle, SLRibbon, SLRoundRect, SLShape, SLTail, SLTicket, dashPath, extractFraction, wobblePath;
export 'paint/sl_random.dart' show SLRandom;
export 'paint/sl_surface.dart' show SLMaterial, SLSurface, SLSurfacePainter, SLSurfaceSpec;
export 'sl_badge.dart';
export 'sl_button.dart';
export 'sl_chip.dart';
export 'sl_dialog.dart';
export 'sl_effects.dart';
export 'sl_icon.dart';
export 'sl_icon_map.dart';
export 'sl_name_tag.dart';
export 'sl_panel.dart';
export 'sl_pressable.dart';
export 'sl_progress_bar.dart';
export 'sl_props.dart';
export 'sl_rule.dart';
export 'sl_speech_bubble.dart';
export 'sl_theme.dart';
export 'sl_toast.dart';
export 'sl_toggle.dart';
export 'sl_tooltip.dart';
export 'sl_top_bar.dart';
