// ふれあいレーダーの課金（Google Play の定期購入。月額と年額）。
// サーバーは使わないので、購入の状態は端末の中に覚える。購入や復元のたびに、期間を延ばす。
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// true の間は、ふれあいレーダーを無料で使える（GitHub で配る、ベータ版のAPK用）。
/// Google Play に出す版（AAB）は、ビルド時に PROXIMITY_FREE_BETA=false を渡して、課金を有効にする。
const bool kProximityFreeBeta = bool.fromEnvironment('PROXIMITY_FREE_BETA', defaultValue: true);

/// Play Console で作る、定期購入の「商品ID」（月額と年額）
const String kProductMonthly = 'wifimatch_proximity_monthly';
const String kProductYearly = 'wifimatch_proximity_yearly';

class Billing extends ChangeNotifier {
  bool premium = false;
  bool available = false;
  bool busy = false;
  String? error;
  ProductDetails? monthly;
  ProductDetails? yearly;
  String selected = kProductYearly;
  StreamSubscription<List<PurchaseDetails>>? _sub;

  ProductDetails? get selectedProduct {
    final p = selected == kProductYearly ? yearly : monthly;
    return p ?? monthly ?? yearly;
  }

  String get effectiveSelected => selectedProduct?.id ?? selected;

  /// 年額が、月額の12か月ぶんより何％安いか（両方の価格が分かるときだけ）
  int? get yearlySavingPercent {
    final m = monthly, y = yearly;
    if (m == null || y == null || m.rawPrice <= 0) return null;
    final pct = ((1 - y.rawPrice / (m.rawPrice * 12)) * 100).round();
    return pct > 0 ? pct : null;
  }

  void select(String id) {
    selected = id;
    notifyListeners();
  }

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
        final r = await InAppPurchase.instance.queryProductDetails({kProductMonthly, kProductYearly});
        for (final d in r.productDetails) {
          if (d.id == kProductMonthly) monthly = d;
          if (d.id == kProductYearly) yearly = d;
        }
        await InAppPurchase.instance.restorePurchases();
      }
    } catch (e) {
      error = '$e';
    }
    notifyListeners();
  }

  Future<void> buy() async {
    final pd = selectedProduct;
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
      if (d.productID != kProductMonthly && d.productID != kProductYearly) continue;
      if (d.status == PurchaseStatus.purchased || d.status == PurchaseStatus.restored) {
        await _grant(d.productID == kProductYearly ? 370 : 35);
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

  Future<void> _grant(int days) async {
    premium = true;
    try {
      final p = await SharedPreferences.getInstance();
      final until = DateTime.now().add(Duration(days: days)).millisecondsSinceEpoch;
      final old = p.getInt('wm_premium_until') ?? 0;
      await p.setInt('wm_premium_until', until > old ? until : old);
    } catch (_) {}
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
