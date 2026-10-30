import 'package:flutter/widgets.dart';

import '../../core/art/characters/character_sprites.dart';
import '../../core/game_state.dart';
import '../sugarleaf/sugarleaf.dart';

/// Nhân vật có trang phục lễ hội (gói `staffOutfits`): ảnh `<character>_fest_<biểu cảm>.webp`.
const kFestivalCharacters = {'staff_nora', 'staff_bao'};

/// Ảnh nhân vật đang dùng của [character]: bật trang phục lễ hội (đã mua) → `<character>_fest`.
String staffCharacterArt(GameState state, String character) =>
    state.outfitsEnabled && kFestivalCharacters.contains(character)
        ? '${character}_fest'
        : character;

/// Chân dung nhân viên cắt nửa người từ ảnh vẽ tay toàn thân `assets/characters/<character>_<expression>.webp`
/// (480×640): ảnh phóng sao cho phần trên (đầu → eo) lấp khung [width]×[height], canh giữa theo chiều ngang. Thiếu
/// ảnh (chưa vẽ xong) → ảnh của một khách sẵn có hợp dáng ([fallbackCharacter]); thiếu nốt → đĩa icon. Giải mã nhỏ
/// theo cỡ hiện (ResizeImage), không chặn luồng UI.
class StaffPortrait extends StatelessWidget {
  const StaffPortrait({
    super.key,
    required this.character,
    required this.width,
    required this.height,
    this.expression = 'smile',
    this.shown = 0.42,
  });

  /// Id ảnh nhân vật (`StaffData.character`, vd. `staff_nora`).
  final String character;
  final double width;
  final double height;
  final String expression;

  /// Phần ảnh (theo chiều cao, sau [_headroom]) hiện trong khung: 0.42 ≈ đầu → eo (nửa người, tỉ lệ 7,5 đầu); nhỏ hơn
  /// = cận mặt (vd. chân dung tròn nhỏ).
  final double shown;

  /// Khoảng trống phía trên đầu trong ảnh (tỉ lệ chiều cao; ảnh nhân viên: đỉnh đầu ở y ≈ 40/640) — bỏ đi cho đầu
  /// gần mép trên.
  static const _headroom = 0.055;

  static const _festSuffix = '_fest';

  /// Ảnh khách sẵn có thay cho ảnh nhân viên còn thiếu (cùng giới / dáng tuổi theo mô tả nhân vật).
  static String fallbackCharacter(String character) => switch (character) {
    'staff_nora' => 'regular_03',
    'staff_bao' => 'regular_07',
    'staff_theo' => 'regular_06',
    'staff_ami' => 'regular_04',
    'staff_hanh' => 'regular_09',
    _ => 'regular_00',
  };

  @override
  Widget build(BuildContext context) {
    var imgH = height / shown;
    if (imgH * 0.75 < width) imgH = width / 0.75;
    final imgW = imgH * 0.75;
    final px = (imgW * MediaQuery.devicePixelRatioOf(context)).round().clamp(1, 480);

    Widget image(String id, Widget Function() onError) => Image(
      image: ResizeImage(AssetImage(CharacterSprites.assetPath(id, expression)), width: px, policy: ResizeImagePolicy.fit),
      width: imgW,
      height: imgH,
      fit: BoxFit.contain,
      alignment: Alignment.topCenter,
      gaplessPlayback: true,
      excludeFromSemantics: true,
      errorBuilder: (context, error, stack) => onError(),
    );

    // Giữa phần khung nhìn thấy (phần trên của hộp ảnh).
    final icon = Align(
      alignment: Alignment(0, shown - 1),
      child: SLIconDisc('customer', size: height * 0.6, color: SLColors.paper, iconScale: 0.6, seed: 0x5AF0),
    );
    return SizedBox(
      width: width,
      height: height,
      child: ClipRect(
        child: Stack(
          clipBehavior: Clip.hardEdge,
          children: [
            Positioned(
              left: (width - imgW) / 2,
              top: -imgH * _headroom,
              width: imgW,
              height: imgH,
              // Trang phục lễ hội thiếu ảnh → ảnh thường của nhân viên → ảnh khách thay thế → đĩa icon.
              child: character.endsWith(_festSuffix)
                  ? image(character, () {
                      final base = character.substring(0, character.length - _festSuffix.length);
                      return image(base, () => image(fallbackCharacter(base), () => icon));
                    })
                  : image(character, () => image(fallbackCharacter(character), () => icon)),
            ),
          ],
        ),
      ),
    );
  }
}
