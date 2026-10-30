import '../game_state.dart';
import '../models/ids.dart';

export '../monetization/monetization_config.dart' show IapCatalog, IapKind, IapProduct;

abstract class IapService {
  /// Gói hiện ở cửa hàng V2 (thứ tự hiển thị; không gồm gói V1 ẩn `pantryS/M/L`, `decorSetSeaside`).
  List<IapProduct> get products;

  /// Gói [id] (kể cả gói V1 ẩn).
  IapProduct product(IapProductId id);

  /// Gói một lần đã mua; thẻ mùa: đã mua cao cấp của mùa hiện tại.
  bool isOwned(IapProductId id);

  /// Mua được lúc này (`GameState.canBuyIap`: thẻ mùa cần mùa đang diễn ra; gói một lần chưa sở hữu).
  bool canBuy(IapProductId id);

  /// fake: chờ [FakeIapService.delay] rồi trao qua `GameState.grantIap` (đúng một lần với gói một lần / thẻ mùa), trả
  /// true. Không mua được → false, không trao.
  Future<bool> buy(IapProductId id);

  /// Khôi phục giao dịch (nút trong Cài đặt): áp lại quyền của gói một lần đã mua. Trả số gói một lần đang sở hữu
  /// (0 = không có gì để khôi phục).
  Future<int> restore();
}

/// Cửa hàng giả lập: không SDK, không trừ tiền thật. Danh mục theo `monetization.json` (`GameState.monetizationConfig`;
/// không nạp được → [IapCatalog.v2]).
class FakeIapService implements IapService {
  FakeIapService(this.state, {this.delay = const Duration(milliseconds: 600)});

  final GameState state;
  final Duration delay;

  /// Danh mục trong code: gói V2 rồi gói V1 ẩn.
  static final List<IapProduct> catalog = [...IapCatalog.v2, ...IapCatalog.legacy];

  @override
  List<IapProduct> get products {
    final fromConfig = state.monetizationConfig.products;
    return fromConfig.isNotEmpty ? fromConfig : IapCatalog.v2;
  }

  @override
  IapProduct product(IapProductId id) => state.monetizationConfig.product(id);

  @override
  bool isOwned(IapProductId id) => switch (product(id).kind) {
        IapKind.consumable => false,
        IapKind.oneTime => state.ownedIap.contains(id),
        IapKind.season => state.seasonPremium,
      };

  @override
  bool canBuy(IapProductId id) => state.canBuyIap(id);

  @override
  Future<bool> buy(IapProductId id) async {
    if (!canBuy(id)) return false;
    await Future<void>.delayed(delay);
    return state.grantIap(id);
  }

  @override
  Future<int> restore() async {
    await Future<void>.delayed(delay);
    return state.restoreIap();
  }
}
