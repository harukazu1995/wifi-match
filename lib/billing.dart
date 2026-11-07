// すれ違い通信の課金（Google Play の定期購入）。
// サーバーは使わないので、購入の状態は端末の中に覚える。購入や復元のたびに、35日ぶん延ばす。
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// true の間は、すれ違い通信を無料で使える（GitHub で配る、ベータ版のAPK用）。
/// Google Play に出す版では false にする。
const bool kProximityFreeBeta = true;

/// Play Console で作る、定期購入の「商品ID」
const String kProductId = 'wifimatch_proximity_monthly';

class Billing extends ChangeNotifier {
  bool premium = false;
  bool available = false;
  bool busy = false;
  String? error;
  ProductDetails? product;
  StreamSubscription<List<PurchaseDetails>>? _sub;

  /// 端末に覚えてある購入の状態を読む（すぐ終わる）
  Future<void> loadStored() async {
    try {
      final p = await SharedPreferences.getInstance();
      final until = p.getInt('wm_premium_until') ?? 0;
      premium = DateTime.now().millisecondsSinceEpoch < until;
    } catch (_) {}
  }

  /// Google Play に商品を問い合わせ、購入の状態を復元する
  Future<void> init() async {
    try {
      _sub = InAppPurchase.instance.purchaseStream.listen(_onPurchases, onError: (Object _) {});
      available = await InAppPurchase.instance.isAvailable();
      if (available) {
        final r = await InAppPurchase.instance.queryProductDetails({kProductId});
        if (r.productDetails.isNotEmpty) product = r.productDetails.first;
        await InAppPurchase.instance.restorePurchases();
      }
    } catch (e) {
      error = '$e';
    }
    notifyListeners();
  }

  Future<void> buy() async {
    final pd = product;
    if (pd == null || busy) return;
    busy = true;
    error = null;
    notifyListeners();
    try {
      await InAppPurchase.instance.buyNonConsumable(purchaseParam: PurchaseParam(productDetails: pd));
    } catch (e) {
      error = '$e';
      busy = false;
      notifyListeners();
    }
  }

  Future<void> restore() async {
    try {
      await InAppPurchase.instance.restorePurchases();
    } catch (e) {
      error = '$e';
      notifyListeners();
    }
  }

  Future<void> _onPurchases(List<PurchaseDetails> list) async {
    for (final d in list) {
      if (d.productID != kProductId) continue;
      if (d.status == PurchaseStatus.purchased || d.status == PurchaseStatus.restored) {
        await _grant();
      } else if (d.status == PurchaseStatus.error) {
        error = d.error?.message;
      }
      if (d.pendingCompletePurchase) {
        try {
          await InAppPurchase.instance.completePurchase(d);
        } catch (_) {}
      }
    }
    busy = false;
    notifyListeners();
  }

  Future<void> _grant() async {
    premium = true;
    try {
      final p = await SharedPreferences.getInstance();
      await p.setInt('wm_premium_until', DateTime.now().add(const Duration(days: 35)).millisecondsSinceEpoch);
    } catch (_) {}
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
