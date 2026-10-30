part of 'upgrades_screen.dart';

// ==================================================================== Tab Nhân viên

/// Tên vai trò nhân viên.
String staffRoleLabel(AppLocalizations l, StaffRole role) => switch (role) {
  StaffRole.cashier => l.staffRoleCashier,
  StaffRole.baker => l.staffRoleBaker,
  StaffRole.waiter => l.staffRoleWaiter,
  StaffRole.manager => l.staffRoleManager,
};

/// Tên chỉ số.
String staffStatLabel(AppLocalizations l, StaffStat stat) => switch (stat) {
  StaffStat.speed => l.staffStatSpeed,
  StaffStat.skill => l.staffStatSkill,
};

/// Thông số dễ hiểu của một cấp chỉ số nhân viên (vd. "Bán mỗi 3,2 giây", "Tip +8% lượt mình bán"). [value] =
/// `StaffData.speedValues` / `skillValues` của cấp đó.
String staffStatText(BuildContext context, StaffRole role, StaffStat stat, num value) {
  final l = AppLocalizations.of(context);
  // Giây: số tròn không ghi ",0" ("24 giây", "3,5 giây").
  String sec() => value == value.roundToDouble() ? formatInt(context, value.round()) : formatDecimal1(context, value.toDouble());
  // Đơn vị theo vai trò / chỉ số (bảng ở `StaffData`), không đoán theo độ lớn: tip thu ngân và kiên nhẫn của phục
  // vụ là phần trăm nguyên (8 = 8%); tốc độ quản lý là tỉ lệ 0..1 (0,25 = 25%).
  int pct() => value.round();
  int ratioPct() => (value * 100).round();
  return switch ((role, stat)) {
    (StaffRole.cashier, StaffStat.speed) => l.staffCashierSpeed(sec()),
    (StaffRole.cashier, StaffStat.skill) => l.staffCashierSkill(pct()),
    (StaffRole.baker, StaffStat.speed) => l.staffBakerSpeed(sec()),
    (StaffRole.baker, StaffStat.skill) => l.staffBakerSkill(formatDecimal1(context, value.toDouble())),
    (StaffRole.waiter, StaffStat.speed) => l.staffWaiterSpeed(sec()),
    (StaffRole.waiter, StaffStat.skill) => l.staffWaiterSkill(pct()),
    (StaffRole.manager, StaffStat.speed) => l.staffManagerSpeed(ratioPct()),
    (StaffRole.manager, StaffStat.skill) => l.staffManagerSkill(value.round()),
  };
}

class _StaffTab extends StatelessWidget {
  const _StaffTab({
    super.key,
    required this.state,
    required this.config,
    required this.lang,
    required this.fresh,
    required this.focus,
    required this.keyFor,
  });

  final GameState state;
  final UnlockConfig config;
  final String lang;
  final Set<String> fresh;
  final String? focus;
  final GlobalKey Function(String) keyFor;

  @override
  Widget build(BuildContext context) {
    final staff = config.staff;
    if (staff.isEmpty) return const SizedBox.expand();
    // Lưới 2 cột (5 người → 3 hàng, cuộn); thứ tự theo unlocks.json (= theo màn mở).
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 6), // chừa chỗ huy hiệu "Mới" thò lên mép thẻ
      child: Wrap(
        spacing: 18,
        runSpacing: 14,
        children: [
          for (final s in staff)
            _StaffCard(
              key: keyFor(s.id),
              data: s,
              state: state,
              lang: lang,
              fresh: fresh.contains(s.id),
              focused: focus == s.id,
            ),
        ],
      ),
    );
  }
}

/// Thẻ ngang một nhân viên (580×262): chân dung nửa người bên trái; bên phải tên + vai trò, một câu giới thiệu, 2 dòng
/// chỉ số Tốc độ / Tay nghề (chấm cấp 1–5, thông số hiện tại → cấp sau, nút mũi tên + giá nâng từng chỉ số). Chưa
/// thuê → các dòng chỉ số chỉ xem trước cấp 1, chân thẻ giá + "Thuê"; chưa tới mốc → "Qua màn X để mở" (chân dung
/// mờ). Đã thuê → dấu mộc ✓ ở góc dưới chân dung (vừa thuê: nảy vào). Chạm đúp không mua hai lần (như thẻ thiết bị).
class _StaffCard extends StatefulWidget {
  const _StaffCard({
    super.key,
    required this.data,
    required this.state,
    required this.lang,
    required this.fresh,
    required this.focused,
  });

  final StaffData data;
  final GameState state;
  final String lang;
  final bool fresh;
  final bool focused;

  static const width = 580.0;
  static const height = 262.0;

  @override
  State<_StaffCard> createState() => _StaffCardState();
}

class _StaffCardState extends State<_StaffCard> {
  /// Lần bấm hụt tiền (rung) của nút thuê / từng chỉ số.
  int _shortHire = 0;
  final Map<StaffStat, int> _shortStat = {};

  /// Vừa thuê trong lần mở này (dấu mộc nảy vào).
  bool _justHired = false;

  /// Vừa mua xong: bỏ qua lần bấm lại CÙNG nút trong [cooldown] (chạm đúp không mua hai lần). Khoá theo từng nút:
  /// [_hireKey] (thuê — chặn cả thẻ, vì nút chỉ số hiện ra ngay sau khi thuê) hoặc từng [StaffStat] (nâng Tốc độ
  /// xong vẫn bấm Tay nghề ngay được).
  final Map<Object, Timer> _cool = {};
  static const _hireKey = 'hire';

  /// Trạng thái lúc dựng gần nhất: chỉ mua khi khớp (lần bấm thứ hai trước khi thẻ dựng lại bị bỏ).
  bool _shownHired = false;
  final Map<StaffStat, int> _shownLevel = {};

  static const cooldown = Duration(milliseconds: 400);

  @override
  void dispose() {
    for (final t in _cool.values) {
      t.cancel();
    }
    super.dispose();
  }

  bool _cooling(Object key) => _cool[key]?.isActive ?? false;

  void _startCooldown(Object key) {
    _cool[key]?.cancel();
    _cool[key] = Timer(cooldown, () {});
  }

  void _hire() {
    final services = AppScope.read(context);
    final state = services.state;
    final id = widget.data.id;
    if (_cooling(_hireKey) || _shownHired || state.isStaffHired(id)) return;
    final l = AppLocalizations.of(context);
    final result = state.buyUnlock(id);
    switch (result) {
      case PurchaseResult.ok:
        services.audio.success();
        _startCooldown(_hireKey);
        setState(() => _justHired = true);
        showToast(context, l.staffHired);
      case PurchaseResult.notEnoughCoins:
        services.audio.fail();
        setState(() => _shortHire++);
        showToast(context, l.commonNotEnoughCoins, success: false);
      case PurchaseResult.notEnoughGems:
        services.audio.fail();
        setState(() => _shortHire++);
        showToast(context, l.commonNotEnoughGems, success: false);
      case _:
        break;
    }
  }

  void _upgrade(StaffStat stat) {
    final services = AppScope.read(context);
    final state = services.state;
    final id = widget.data.id;
    if (_cooling(_hireKey) || _cooling(stat) || state.staffLevel(id, stat) != _shownLevel[stat]) return;
    final l = AppLocalizations.of(context);
    final result = state.upgradeStaff(id, stat);
    switch (result) {
      case PurchaseResult.ok:
        services.audio.success();
        _startCooldown(stat);
        setState(() {});
        showToast(context, l.upgradeDone);
      case PurchaseResult.notEnoughCoins:
        services.audio.fail();
        setState(() => _shortStat[stat] = (_shortStat[stat] ?? 0) + 1);
        showToast(context, l.commonNotEnoughCoins, success: false);
      case PurchaseResult.notEnoughGems:
        services.audio.fail();
        setState(() => _shortStat[stat] = (_shortStat[stat] ?? 0) + 1);
        showToast(context, l.commonNotEnoughGems, success: false);
      case _:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final styles = SLTextStyles.of(context);
    final s = widget.data;
    final state = widget.state;
    final unlock = state.unlockConfig.unlock(s.id);
    final status = state.unlockState(s.id);
    final hired = state.isStaffHired(s.id);
    _shownHired = hired;
    for (final stat in StaffStat.values) {
      _shownLevel[stat] = state.staffLevel(s.id, stat);
    }
    final seed = slSeed(content: s.id, salt: 0x5AF1);
    final dim = !hired && (status == UnlockState.locked || status == UnlockState.comingSoon);
    final accent = hired
        ? SLColors.mintLight
        : status == UnlockState.available
            ? SLColors.butterLight
            : SLColors.paperShade;
    // Đã qua mốc nhưng còn thiếu mục phải mua trước (vd. phục vụ cần bàn ghế quán) → chân thẻ ghi "Cần … trước"
    // thay cho "Qua màn X để mở".
    final passed = unlock != null && state.highestCompletedLevel >= unlock.level;
    final missing = state.staffRequirementMissing(s.id);
    final needs = missing == null ? null : state.unlockConfig.unlock(missing)?.name(widget.lang) ?? missing;

    final Widget? footer = hired
        ? null
        : switch (status) {
            UnlockState.locked when passed && needs != null => _RequiresLine(
              key: ValueKey('staff-requires-${s.id}'),
              text: l.staffRequires(needs),
            ),
            UnlockState.locked => _LockLine(key: ValueKey('staff-locked-${s.id}'), level: unlock?.level ?? 0),
            UnlockState.comingSoon || UnlockState.owned => SLChip(
              key: ValueKey('staff-soon-${s.id}'),
              label: l.upgComingSoon,
              icon: 'clock',
              selected: true,
              color: SLColors.paperShade,
            ),
            UnlockState.available => SLShake(
              trigger: _shortHire,
              child: Row(
                children: [
                  Expanded(
                    child: _Prices(coins: unlock?.price ?? 0, gems: unlock?.gemPrice ?? 0, state: state),
                  ),
                  const SizedBox(width: 8),
                  SLButton(
                    key: ValueKey('staff-hire-${s.id}'),
                    label: l.staffHire,
                    icon: 'customer',
                    color: SLColors.strawberry,
                    width: 170,
                    height: 50,
                    fontSize: 20,
                    onPressed: _hire,
                  ),
                ],
              ),
            ),
          };

    final portrait = SizedBox(
      width: 168,
      child: SLSurface(
        spec: SLSurfaceSpec(
          shape: const SLRoundRect(16),
          material: SLMaterial.wash,
          color: accent,
          inkWidth: 1.8,
          seed: seed + 1,
        ),
        padding: const EdgeInsets.all(4),
        child: LayoutBuilder(
          builder: (context, box) => SLHandClip(
            shape: const SLRoundRect(12),
            seed: seed + 2,
            child: Opacity(
              opacity: dim ? 0.55 : 1,
              child: StaffPortrait(
                key: ValueKey('staff-portrait-${s.id}'),
                character: staffCharacterArt(state, s.character),
                width: box.maxWidth,
                height: box.maxHeight,
              ),
            ),
          ),
        ),
      ),
    );

    final info = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Flexible(
              child: Text(
                s.name(widget.lang),
                key: ValueKey('staff-name-${s.id}'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: styles.heading.copyWith(fontSize: 26, height: 1.1),
              ),
            ),
            const SizedBox(width: 10),
            SLChip(
              label: staffRoleLabel(l, s.role),
              selected: true,
              color: hired ? SLColors.mint : SLColors.butterLight,
              seed: seed + 3,
            ),
          ],
        ),
        const SizedBox(height: 2),
        SizedBox(
          height: _bioHeight,
          child: Align(
            alignment: Alignment.centerLeft,
            child: _FitLines(
              s.bio(widget.lang),
              key: ValueKey('staff-bio-${s.id}'),
              maxLines: 2,
              minFontSize: 12,
              align: TextAlign.start,
              style: styles.body.copyWith(fontSize: 15, fontWeight: FontWeight.w700, height: 1.2, color: SLColors.inkSoft),
            ),
          ),
        ),
        const SizedBox(height: 4),
        for (final stat in StaffStat.values) ...[
          _StaffStatRow(
            key: ValueKey('staff-stat-${s.id}-${stat.name}'),
            data: s,
            stat: stat,
            level: hired ? state.staffLevel(s.id, stat) : 0,
            hired: hired,
            coins: state.coins,
            shortTries: _shortStat[stat] ?? 0,
            seed: seed + 10 + stat.index * 7,
            onUpgrade: () => _upgrade(stat),
          ),
          const SizedBox(height: 4),
        ],
        const Spacer(),
        if (footer != null) SizedBox(height: 50, child: Center(child: footer)),
      ],
    );

    final card = SLPaperCard(
      seed: seed,
      radius: 20,
      color: widget.focused ? SLColors.butterLight : null,
      padding: const EdgeInsets.fromLTRB(10, 10, 14, 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          portrait,
          const SizedBox(width: 12),
          Expanded(child: info),
        ],
      ),
    );

    return SizedBox(
      width: _StaffCard.width,
      height: _StaffCard.height,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(child: card),
          if (widget.fresh && !hired && status == UnlockState.available)
            Positioned(right: -6, top: -8, child: SLBadge.label(l.levelNewBadge, color: SLColors.mint, sparkle: true)),
          // Công tắc trang phục lễ hội (đã mua gói, Nora / Bảo): mẩu giấy nhỏ ở mép trên chân dung.
          if (state.outfitsOwned && kFestivalCharacters.contains(s.character))
            Positioned(left: 14, top: 14, child: _OutfitToggle(staffId: s.id, state: state)),
          // Dấu "đã thuê" ở góc dưới chân dung (không che mặt).
          if (hired)
            Positioned(
              left: 6,
              bottom: 6,
              child: _justHired ? const SLBounceIn(child: _BoughtStamp()) : const _BoughtStamp(sparkle: false),
            ),
        ],
      ),
    );
  }

  /// Chỗ cho hai dòng giới thiệu (cỡ 15 × cao dòng 1.2).
  static const _bioHeight = 38.0;
}

/// Công tắc "Trang phục lễ hội" (bật/tắt chung cho Nora và Bảo; chỉ đổi hình).
class _OutfitToggle extends StatelessWidget {
  const _OutfitToggle({required this.staffId, required this.state});

  final String staffId;
  final GameState state;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return SLSurface(
      spec: SLSurfaceSpec(
        shape: const SLRoundRect(12),
        material: SLMaterial.wash,
        color: SLColors.paper,
        inkWidth: 1.6,
        seed: slSeed(content: staffId, salt: 0x0F17),
      ),
      lift: 2,
      padding: const EdgeInsets.fromLTRB(8, 4, 6, 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ExcludeSemantics(
            child: Text(
              l.staffOutfitFestival,
              style: SLTextStyles.of(context).caption.copyWith(fontSize: 12, fontWeight: FontWeight.w800, height: 1.1),
            ),
          ),
          const SizedBox(height: 2),
          SLToggle(
            key: ValueKey('staff-outfit-$staffId'),
            value: state.outfitsEnabled,
            semanticLabel: l.staffOutfitFestival,
            onChanged: state.setOutfitsEnabled,
          ),
        ],
      ),
    );
  }
}

/// Dòng "Cần có … trước" (icon thông tin + chữ), không phải nút.
class _RequiresLine extends StatelessWidget {
  const _RequiresLine({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      const SLIcon('info', size: 26, color: SLColors.inkSoft),
      const SizedBox(width: 6),
      Flexible(
        child: Text(
          text,
          maxLines: 2,
          textAlign: TextAlign.center,
          style: SLTextStyles.of(context).label.copyWith(fontSize: 16, color: SLColors.inkSoft, height: 1.1),
        ),
      ),
    ],
  );
}

/// Một dòng chỉ số: nhãn (Tốc độ / Tay nghề) + chấm cấp, thông số "hiện tại → cấp sau"; bên phải nút mũi tên lên +
/// giá (đã thuê, chưa tối đa) hoặc huy hiệu tối đa. Chưa thuê ([level] = 0) → chỉ xem trước thông số cấp 1, không nút.
class _StaffStatRow extends StatelessWidget {
  const _StaffStatRow({
    super.key,
    required this.data,
    required this.stat,
    required this.level,
    required this.hired,
    required this.coins,
    required this.shortTries,
    required this.seed,
    required this.onUpgrade,
  });

  final StaffData data;
  final StaffStat stat;

  /// Cấp hiện tại (1..max); 0 = chưa thuê.
  final int level;
  final bool hired;
  final int coins;
  final int shortTries;
  final int seed;
  final VoidCallback onUpgrade;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final styles = SLTextStyles.of(context);
    final values = data.values(stat);
    final max = math.max(1, values.length);
    final shown = level.clamp(1, max);
    final canGrow = hired && shown < max;
    final price = canGrow ? data.priceTo(stat, shown + 1) : null;
    final label = staffStatLabel(l, stat);
    final now = values.isEmpty ? '' : staffStatText(context, data.role, stat, values[shown - 1]);
    final next = canGrow ? staffStatText(context, data.role, stat, values[shown]) : null;

    final Widget? action;
    if (!hired) {
      action = null;
    } else if (!canGrow || price == null) {
      action = SLChip(
        key: ValueKey('staff-max-${data.id}-${stat.name}'),
        label: l.upgradeMaxed,
        icon: 'medal_max',
        selected: true,
        color: SLColors.butter,
      );
    } else {
      final affordable = coins >= price;
      action = SLShake(
        trigger: shortTries,
        child: SLButton(
          key: ValueKey('staff-up-${data.id}-${stat.name}'),
          label: formatInt(context, price),
          leading: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [SLIcon('arrow_up', size: 22), SizedBox(width: 2), CoinIcon(size: 24)],
          ),
          semanticLabel: '${l.staffUpgradeStat(label)}, ${l.commonCoins(price)}',
          color: affordable ? SLColors.strawberry : SLColors.paperShade,
          height: 48,
          fontSize: 18,
          onPressed: onUpgrade,
        ),
      );
    }

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Semantics(
                label: l.staffStatLevel(label, hired ? shown : 0, max),
                child: ExcludeSemantics(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          label,
                          style: styles.label.copyWith(fontSize: 16, fontWeight: FontWeight.w900, height: 1.1),
                        ),
                        const SizedBox(width: 8),
                        _LevelPips(
                          key: ValueKey('staff-pips-${data.id}-${stat.name}'),
                          level: hired ? shown : 0,
                          max: max,
                          seed: seed,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 2),
              Align(alignment: Alignment.centerLeft, child: _StatLine(now: now, next: next)),
            ],
          ),
        ),
        if (action != null) ...[const SizedBox(width: 8), action],
      ],
    );
  }
}
