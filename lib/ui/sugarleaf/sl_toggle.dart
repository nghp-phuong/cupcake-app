import 'package:flutter/widgets.dart';

import 'paint/hand_drawn.dart';
import 'paint/sl_surface.dart';
import 'sl_icon.dart';
import 'sl_pressable.dart';
import 'sl_theme.dart';

/// Công tắc vẽ tay: rãnh viên thuốc (bạc hà khi bật, giấy cũ khi tắt) + núm giấy tròn trượt kiểu nảy.
/// Vùng chạm 80×48; Semantics toggled + nhãn [semanticLabel]. [onChanged] null → tắt.
class SLToggle extends StatelessWidget {
  const SLToggle({super.key, required this.value, required this.onChanged, this.semanticLabel, this.seed});

  final bool value;
  final ValueChanged<bool>? onChanged;
  final String? semanticLabel;
  final int? seed;

  @override
  Widget build(BuildContext context) {
    final theme = SLTheme.of(context);
    final enabled = onChanged != null;
    final s = slSeed(seed: seed, key: key, content: semanticLabel ?? 'toggle');
    final ink = enabled ? theme.ink : SLColors.disabledInk;
    final track = SLSurfaceSpec(
      shape: const SLRoundRect(19),
      material: SLMaterial.wash,
      color: !enabled ? SLColors.disabledFill : (value ? SLColors.mint : SLColors.paperShade),
      ink: ink,
      inkWidth: theme.inkWidth - 0.2,
      roughness: theme.roughness,
      seed: s,
    );
    final knob = SLSurfaceSpec(
      shape: const SLCircle(),
      material: SLMaterial.wash,
      color: SLColors.paper,
      ink: ink,
      inkWidth: theme.inkWidth - 0.2,
      roughness: theme.roughness,
      sticker: true,
      seed: s + 1,
    );
    return RepaintBoundary(
      child: SizedBox(
        width: 80,
        height: SLMetrics.minTap,
        child: SLPressable(
          onPressed: enabled ? () => onChanged!(!value) : null,
          semanticLabel: semanticLabel,
          toggled: value,
          isButton: false,
          bounce: false,
          builder: (context, press) => Center(
            child: SizedBox(
              width: 74,
              height: 38,
              child: SLSurface(
                spec: track,
                child: AnimatedAlign(
                  alignment: value ? Alignment.centerRight : Alignment.centerLeft,
                  duration: slReduceMotion(context) ? Duration.zero : SLMetrics.bounce,
                  curve: Curves.easeOutBack,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: SizedBox.square(
                      dimension: 30,
                      child: SLSurface(
                        spec: knob,
                        lift: 2.5,
                        press: press,
                        pressDepth: 1.5,
                        child: value ? Center(child: SLIcon('check', size: 18, color: ink)) : null,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
