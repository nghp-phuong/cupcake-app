import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/constants.dart';
import '../../core/models/ids.dart';
import '../../l10n/gen/app_localizations.dart';
import '../common/format.dart' show kAppVersionLabel;
import '../shop3d/shop3d_toasts.dart';
import '../sugarleaf/sugarleaf.dart';

/// Bảng cài đặt 2D đặt trên cảnh 3D: ngôn ngữ (theo máy / English / Tiếng Việt), âm thanh, xoá dữ liệu (xác nhận 2
/// bước ngay trong bảng), phiên bản + ghi chú alpha. Phủ cả màn (nền tối); chạm ngoài thẻ hoặc Esc → [onClose]
/// (không đóng khi đang xác nhận xoá hoặc đang xoá). Trạng thái ngôn ngữ/âm thanh do nơi gọi giữ.
class CitySettingsSheet extends StatefulWidget {
  const CitySettingsSheet({
    super.key,
    required this.language,
    required this.sound,
    required this.onLanguage,
    required this.onSound,
    required this.onReset,
    required this.onClose,
    this.version = kAppVersionLabel,
  });

  final LanguagePref language;
  final bool sound;
  final ValueChanged<LanguagePref> onLanguage;
  final ValueChanged<bool> onSound;

  /// Gọi sau khi người chơi xác nhận bước 2.
  final Future<void> Function() onReset;
  final VoidCallback onClose;
  final String version;

  @override
  State<CitySettingsSheet> createState() => _CitySettingsSheetState();
}

class _CitySettingsSheetState extends State<CitySettingsSheet> {
  bool _confirming = false;
  bool _busy = false;

  bool get _canDismiss => !_confirming && !_busy;

  void _dismiss() {
    if (_canDismiss) widget.onClose();
  }

  Future<void> _reset() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await widget.onReset();
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _confirming = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final size = MediaQuery.sizeOf(context);
    final s = Shop3dStyle.scaleOf(size);
    final label = Shop3dStyle.title(context, 18 * s);
    return CallbackShortcuts(
      bindings: {const SingleActivator(LogicalKeyboardKey.escape): _dismiss},
      child: Focus(
        autofocus: true,
        child: Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _dismiss,
                child: const ColoredBox(color: Color(0x73000000)),
              ),
            ),
            Center(
              // Chạm vào thẻ không đóng.
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {},
                child: Container(
                  width: math.min(560 * s, size.width - 48),
                  constraints: BoxConstraints(maxHeight: size.height - 24),
                  padding: EdgeInsets.all(16 * s),
                  decoration: Shop3dStyle.box(
                    color: AppColors.cream,
                    radius: 22,
                  ),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          l.settingsTitle,
                          textAlign: TextAlign.center,
                          style: Shop3dStyle.title(context, 26 * s),
                        ),
                        SizedBox(height: 12 * s),
                        Text(l.settingsLanguage, style: label),
                        SizedBox(height: 6 * s),
                        Row(
                          children: [
                            for (final (i, p) in LanguagePref.values.indexed)
                              Expanded(
                                child: Padding(
                                  padding: EdgeInsets.only(
                                    left: i == 0 ? 0 : 8,
                                  ),
                                  child: Shop3dPillButton(
                                    key: ValueKey('lang-${p.name}'),
                                    label: _langLabel(l, p),
                                    color: widget.language == p
                                        ? AppColors.mint
                                        : AppColors.cream,
                                    width: double.infinity,
                                    maxLines: 2,
                                    fontSize: 15,
                                    height: 52,
                                    onPressed: _confirming
                                        ? null
                                        : () => widget.onLanguage(p),
                                  ),
                                ),
                              ),
                          ],
                        ),
                        SizedBox(height: 14 * s),
                        Row(
                          children: [
                            Expanded(
                              child: Text(l.settingsSound, style: label),
                            ),
                            Shop3dPillButton(
                              key: const ValueKey('sound-toggle'),
                              label: widget.sound
                                  ? l.settingsOn
                                  : l.settingsOff,
                              icon: widget.sound
                                  ? Icons.volume_up_rounded
                                  : Icons.volume_off_rounded,
                              color: widget.sound
                                  ? AppColors.mint
                                  : AppColors.cream,
                              width: 150,
                              onPressed: _confirming
                                  ? null
                                  : () => widget.onSound(!widget.sound),
                            ),
                          ],
                        ),
                        SizedBox(height: 14 * s),
                        if (!_confirming)
                          Shop3dPillButton(
                            key: const ValueKey('reset-start'),
                            label: l.settingsResetData,
                            icon: Icons.delete_outline_rounded,
                            color: AppColors.cream,
                            width: double.infinity,
                            maxLines: 2,
                            onPressed: () =>
                                setState(() => _confirming = true),
                          )
                        else
                          _ResetConfirm(
                            title: l.settingsResetConfirmTitle,
                            body: l.settingsResetConfirmBody,
                            cancel: l.commonCancel,
                            confirm: l.commonConfirm,
                            busy: _busy,
                            scale: s,
                            onCancel: () =>
                                setState(() => _confirming = false),
                            onConfirm: _reset,
                          ),
                        SizedBox(height: 12 * s),
                        Text(
                          l.settingsVersion(widget.version),
                          textAlign: TextAlign.center,
                          style: Shop3dStyle.body(14 * s),
                        ),
                        Text(
                          l.settingsAlphaNote,
                          textAlign: TextAlign.center,
                          style: Shop3dStyle.body(
                            13 * s,
                            weight: FontWeight.w600,
                          ),
                        ),
                        SizedBox(height: 10 * s),
                        Center(
                          child: Shop3dPillButton(
                            key: const ValueKey('settings-close'),
                            label: l.commonClose,
                            width: 160,
                            fontSize: 18,
                            onPressed: _canDismiss ? widget.onClose : null,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _langLabel(AppLocalizations l, LanguagePref p) => switch (p) {
    LanguagePref.system => l.settingsLanguageSystem,
    LanguagePref.en => l.settingsLanguageEn,
    LanguagePref.vi => l.settingsLanguageVi,
  };
}

/// Bước 2 của xoá dữ liệu: cảnh báo + Huỷ / Xác nhận.
class _ResetConfirm extends StatelessWidget {
  const _ResetConfirm({
    required this.title,
    required this.body,
    required this.cancel,
    required this.confirm,
    required this.busy,
    required this.scale,
    required this.onCancel,
    required this.onConfirm,
  });

  final String title, body, cancel, confirm;
  final bool busy;
  final double scale;
  final VoidCallback onCancel;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('reset-confirm'),
      padding: EdgeInsets.all(12 * scale),
      decoration: Shop3dStyle.box(
        color: Colors.white,
        radius: 16,
        shadow: false,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            textAlign: TextAlign.center,
            style: Shop3dStyle.title(
              context,
              18 * scale,
              color: SLColors.badDeep,
            ),
          ),
          SizedBox(height: 6 * scale),
          Text(
            body,
            textAlign: TextAlign.center,
            style: Shop3dStyle.body(14 * scale),
          ),
          SizedBox(height: 10 * scale),
          Row(
            children: [
              Expanded(
                child: Shop3dPillButton(
                  key: const ValueKey('reset-cancel'),
                  label: cancel,
                  color: AppColors.cream,
                  onPressed: busy ? null : onCancel,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Shop3dPillButton(
                  key: const ValueKey('reset-confirm-yes'),
                  label: confirm,
                  color: AppColors.bad,
                  onPressed: busy ? null : onConfirm,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
