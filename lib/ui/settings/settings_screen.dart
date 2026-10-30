import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../../core/app_scope.dart';
import '../../core/models/ids.dart';
import '../../core/routes.dart';
import '../../l10n/gen/app_localizations.dart';
import '../common/dialogs.dart';
import '../common/format.dart';
import '../common/navigation.dart';
import '../common/sugar_screen.dart';
import '../map/level_map_screen.dart';
import '../sugarleaf/sugarleaf.dart';
import '../ui_routes.dart';

/// Cài đặt: ngôn ngữ (theo máy / English / Tiếng Việt), âm thanh, làm quen (xem lại cảnh mở đầu, hướng dẫn lại
/// L1–L3), giao dịch (khôi phục gói một lần — giả lập), xoá dữ liệu; chân trang phiên bản.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _resetting = false;
  bool _restoring = false;

  /// Khôi phục giao dịch (gói một lần đã mua): giả lập đọc lại `ownedIap`; báo số gói khôi phục được.
  Future<void> _restore() async {
    if (_restoring) return;
    final services = AppScope.read(context);
    services.audio.tap();
    setState(() => _restoring = true);
    int? restored;
    try {
      restored = await services.iap.restore();
    } catch (e) {
      debugPrint('SettingsScreen: khôi phục giao dịch lỗi ($e)');
    }
    if (!mounted) return;
    setState(() => _restoring = false);
    final l = AppLocalizations.of(context);
    if (restored == null) {
      showToast(context, l.settingsRestoreFailed, success: false);
    } else if (restored <= 0) {
      showToast(context, l.settingsRestoreNone, success: false);
    } else {
      showToast(context, l.settingsRestoreDone(restored));
    }
  }

  Future<void> _reset() async {
    final l = AppLocalizations.of(context);
    final ok = await showConfirmDialog(
      context,
      title: l.settingsResetConfirmTitle,
      body: l.settingsResetConfirmBody,
      confirmLabel: l.settingsResetData,
      confirmColor: SLColors.dangerSoft,
      titleColor: SLColors.dangerSoft,
      illustration: const SLIconDisc('warning', size: 84, color: SLColors.butterLight, iconScale: 0.66, seed: 0x5E7A),
    );
    if (!ok || !mounted) return;
    setState(() => _resetting = true);
    final state = AppScope.read(context).state;
    await state.resetAll();
    if (!mounted) return;
    LevelMapScreen.giftShownThisSession = false;
    clearMapReveals(); // tiến trình cũ đã xoá: bỏ hoạt cảnh còn chờ
    // Sau khi xoá, ngôn ngữ về "theo máy" → lấy chuỗi theo locale mới ở khung hình kế.
    showToast(context, AppLocalizations.of(context).settingsResetDone);
    goToMenu(context);
  }

  /// Mở lại cảnh mở đầu; xong / bỏ qua thì cảnh tự quay về đây.
  void _replayIntro() {
    AppScope.read(context).audio.tap();
    Navigator.of(context).pushNamed(AppRoutes.intro);
  }

  /// Bật lại hướng dẫn lần đầu của L1–L3 (lần chơi kế tiếp mỗi màn hiện lại).
  void _replayTutorials() {
    final services = AppScope.read(context);
    services.audio.tap();
    services.state.resetTutorials();
    showToast(context, AppLocalizations.of(context).settingsTutorialsReset);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final state = AppScope.of(context).state;
    final styles = SLTextStyles.of(context);
    final footer = styles.body.copyWith(fontSize: 17, fontWeight: FontWeight.w800, color: SLColors.inkSoft);
    return SugarScreen(
      title: l.settingsTitle,
      titleIconId: 'settings',
      showCurrency: false,
      body: Center(
        child: SizedBox(
          width: 820,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SLPanel(
                radius: 26,
                seed: 0x5E77,
                padding: const EdgeInsets.fromLTRB(28, 14, 28, 14),
                child: Column(
                  children: [
                    _SettingRow(
                      icon: 'language',
                      label: l.settingsLanguage,
                      seed: 1,
                      child: Wrap(
                        spacing: 10,
                        runSpacing: 8,
                        children: [
                          for (final pref in LanguagePref.values)
                            SLChip(
                              label: switch (pref) {
                                LanguagePref.system => l.settingsLanguageSystem,
                                LanguagePref.en => l.settingsLanguageEn,
                                LanguagePref.vi => l.settingsLanguageVi,
                              },
                              icon: pref == LanguagePref.system ? 'phone' : null,
                              selected: state.language == pref,
                              onPressed: () => state.setLanguage(pref),
                            ),
                        ],
                      ),
                    ),
                    const _Rule(seed: 1),
                    _SettingRow(
                      icon: state.soundOn ? 'sound_on' : 'sound_off',
                      label: l.settingsSound,
                      seed: 2,
                      child: Row(
                        children: [
                          SLToggle(
                            value: state.soundOn,
                            semanticLabel: l.settingsSound,
                            onChanged: state.setSound,
                          ),
                          const SizedBox(width: 12),
                          // Chữ trạng thái (Bật/Tắt) cạnh công tắc; công tắc tự đọc trạng thái cho trình đọc màn hình.
                          ExcludeSemantics(
                            child: Text(
                              state.soundOn ? l.settingsOn : l.settingsOff,
                              style: styles.label.copyWith(fontSize: 19),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const _Rule(seed: 2),
                    _SettingRow(
                      icon: 'book',
                      label: l.settingsGuide,
                      seed: 4,
                      child: Wrap(
                        spacing: 12,
                        runSpacing: 8,
                        children: [
                          SLButton(
                            key: const ValueKey('settings-replay-intro'),
                            label: l.settingsReplayIntro,
                            icon: 'play_video',
                            variant: SLButtonVariant.secondary,
                            height: 52,
                            fontSize: 18,
                            onPressed: _replayIntro,
                          ),
                          SLButton(
                            key: const ValueKey('settings-replay-tutorials'),
                            label: l.settingsReplayTutorials,
                            icon: 'reset',
                            variant: SLButtonVariant.secondary,
                            height: 52,
                            fontSize: 18,
                            onPressed: _replayTutorials,
                          ),
                        ],
                      ),
                    ),
                    const _Rule(seed: 5),
                    _SettingRow(
                      icon: 'shop_bag',
                      label: l.settingsPurchases,
                      seed: 5,
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: SLButton(
                          key: const ValueKey('settings-restore'),
                          label: l.settingsRestore,
                          icon: 'reset',
                          variant: SLButtonVariant.secondary,
                          height: 52,
                          fontSize: 18,
                          loading: _restoring,
                          onPressed: _restoring ? null : _restore,
                        ),
                      ),
                    ),
                    const _Rule(seed: 3),
                    _SettingRow(
                      icon: 'trash',
                      label: l.settingsResetData,
                      seed: 3,
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: SLButton(
                          label: l.settingsResetData,
                          icon: 'reset',
                          color: SLColors.dangerSoft,
                          height: 52,
                          fontSize: 18,
                          onPressed: _resetting ? null : _reset,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Text(l.settingsVersion(kAppVersionLabel), style: footer),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SLIcon('heart', size: 22),
                  const SizedBox(width: 6),
                  Text(l.settingsAlphaNote, style: footer.copyWith(fontWeight: FontWeight.w700)),
                ],
              ),
              // Lối vào Gallery bộ design system — chỉ bản debug (chuỗi công cụ nội bộ, không dịch).
              if (kDebugMode) ...[
                const SizedBox(height: 14),
                SLButton(
                  label: 'UI Gallery (debug)',
                  variant: SLButtonVariant.secondary,
                  icon: 'sparkle',
                  height: 48,
                  onPressed: () => Navigator.of(context).pushNamed(UiDebugRoutes.gallery),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _SettingRow extends StatelessWidget {
  const _SettingRow({required this.icon, required this.label, required this.seed, required this.child});

  /// Id icon vẽ tay.
  final String icon;
  final String label;
  final int seed;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox.square(
          dimension: 54,
          child: SLSurface(
            spec: SLSurfaceSpec(shape: const SLCircle(), material: SLMaterial.wash, color: SLColors.mint, seed: 0x5E70 + seed),
            child: Center(child: SLIcon(icon, size: 32)),
          ),
        ),
        const SizedBox(width: 14),
        SizedBox(
          width: 200,
          child: Text(label, style: SLTextStyles.of(context).label.copyWith(fontSize: 21, fontWeight: FontWeight.w900)),
        ),
        const SizedBox(width: 12),
        Expanded(child: child),
      ],
    );
  }
}

/// Đường kẻ bút chì ngăn các dòng cài đặt: hai nét caramel nhạt chồng lệch (kẻ tay hai lần), cao 20.
class _Rule extends StatelessWidget {
  const _Rule({required this.seed});

  final int seed;

  @override
  Widget build(BuildContext context) => SLRule(
        height: 20,
        color: SLColors.caramel.withValues(alpha: 0.55),
        echo: SLRuleEcho.full,
        echoColor: SLColors.caramel.withValues(alpha: 0.3),
        amplitude: 1.6,
        inset: 4,
        seed: 0x9E1C + seed,
      );
}
