import '../game_state.dart';
import '../models/ids.dart';

class IapProduct {
  const IapProduct(this.id, this.displayPrice, {required this.consumable});

  final IapProductId id;

  /// Chuỗi cố định, không dịch.
  final String displayPrice;
  final bool consumable;
}

abstract class IapService {
  List<IapProduct> get products;

  /// Non-consumable đã mua.
  bool isOwned(IapProductId id);

  /// fake: chờ 600ms rồi trao qua `GameState.grantIap`, trả true.
  Future<bool> buy(IapProductId id);
}

/// Cửa hàng giả lập: không SDK, không trừ tiền thật.
class FakeIapService implements IapService {
  FakeIapService(this.state, {this.delay = const Duration(milliseconds: 600)});

  final GameState state;
  final Duration delay;

  static const List<IapProduct> catalog = [
    IapProduct(IapProductId.starterPack, r'$1.99', consumable: false),
    IapProduct(IapProductId.pantryS, r'$0.99', consumable: true),
    IapProduct(IapProductId.pantryM, r'$2.99', consumable: true),
    IapProduct(IapProductId.pantryL, r'$6.99', consumable: true),
    IapProduct(IapProductId.decorSetSeaside, r'$2.99', consumable: false),
    IapProduct(IapProductId.removeAds, r'$3.99', consumable: false),
  ];

  @override
  List<IapProduct> get products => catalog;

  IapProduct product(IapProductId id) => catalog.firstWhere((p) => p.id == id);

  @override
  bool isOwned(IapProductId id) => !product(id).consumable && state.ownedIap.contains(id);

  /// Gói 1 lần đã sở hữu → trả false, không trao lại.
  @override
  Future<bool> buy(IapProductId id) async {
    if (isOwned(id)) return false;
    await Future<void>.delayed(delay);
    if (isOwned(id)) return false;
    state.grantIap(id);
    return true;
  }
}
