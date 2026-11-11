
import 'package:flutter/material.dart';

import 'art.dart';
import 'billing.dart';
import 'main.dart' show billing, navKey;

const _coral = Color(0xFFBFA77A);
const _orange = Color(0xFFD8C7A4);
const _ink = Color(0xFF2B2430);
const _gradA = Color(0xFF8F7A52);
const _gradB = Color(0xFF6F5D3E);

/// 有料画面を開く。why を渡すと、上に理由が出る。
void openPaywall([String? why]) {
  final nav = navKey.currentState;
  if (nav == null) return;
  nav.push(MaterialPageRoute<void>(fullscreenDialog: true, builder: (_) => PaywallScreen(why: why)));
}

/// 「自分」「レーダー」に置く、有料の案内カード。
class PremiumPromoCard extends StatelessWidget {
  const PremiumPromoCard({super.key});

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: billing,
        builder: (context, _) {
          if (billing.premium) {
            return Container(
              margin: const EdgeInsets.only(bottom: 14),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [_gradA, _gradB], begin: Alignment.topLeft, end: Alignment.bottomRight),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Row(children: [
                Icon(Icons.workspace_premium, color: Colors.white),
                SizedBox(width: 10),
                Expanded(
                  child: Text('プレミアムをご利用中です。ありがとうございます！',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
                ),
              ]),
            );
          }
          return Container(
            margin: const EdgeInsets.only(bottom: 14),
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [_gradA, _gradB], begin: Alignment.topLeft, end: Alignment.bottomRight),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(color: _orange, borderRadius: BorderRadius.circular(99)),
                child: const Text('Meetory プレミアム', style: TextStyle(color: Color(0xFF151515), fontSize: 11, fontWeight: FontWeight.w700)),
              ),
              const SizedBox(height: 8),
              const Text('全国の「行きたい」が、見つかる。',
                  style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900, height: 1.3)),
              const SizedBox(height: 4),
              const Text('掲示板への投稿・連絡と、ふれあいレーダーが使えます。', style: TextStyle(color: Colors.white, fontSize: 13.5)),
              if (kProximityFreeBeta)
                const Padding(
                  padding: EdgeInsets.only(top: 6),
                  child: Text('ベータ期間中は、無料で使えます', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12.5)),
                ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: openPaywall,
                style: FilledButton.styleFrom(backgroundColor: _orange, foregroundColor: Color(0xFF151515)),
                child: const Text('くわしく見る', style: TextStyle(fontWeight: FontWeight.w800)),
              ),
            ]),
          );
        },
      );
}

class PaywallScreen extends StatelessWidget {
  const PaywallScreen({super.key, this.why});
  final String? why;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      body: ListenableBuilder(
        listenable: billing,
        builder: (context, _) {
          final yearlySel = billing.effectiveSelected == kProductYearly;
          final save = billing.yearlySavingPercent;
          final ypr = billing.yearly?.price ?? '1,680円';
          final mpr = billing.monthly?.price ?? '200円';
          final sel = billing.selectedProduct;
          return Column(children: [
            Expanded(
              child: ListView(padding: EdgeInsets.zero, children: [
                _Hero(why: why),
                Transform.translate(
                  offset: const Offset(0, -30),
                  child: Container(
                    decoration: BoxDecoration(color: Theme.of(context).scaffoldBackgroundColor, borderRadius: const BorderRadius.vertical(top: Radius.circular(30))),
                    padding: const EdgeInsets.fromLTRB(16, 22, 16, 8),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const _Feature(Icons.campaign, _coral, _orange, '掲示板に投稿・連絡', '「ディズニーに行きたい」「フェスで合流したい」。全国の人に募集をかけて、気になる人に連絡できます。見るだけなら無料です。'),
                      const _Feature(Icons.directions_walk, Color(0xFF8F6BFF), Color(0xFF3DB8FF), 'ふれあいレーダー', 'WiFiがなくても、Bluetoothで通りすがりの人に気づけます。あとから一覧で見返せます。'),
                      const _Feature(Icons.shield, Color(0xFF2BB38A), Color(0xFF7BE0B0), '安心のしくみ', '毎日変わる識別番号、通報、ブロック。18歳以上の方だけが使えます。'),
                      const SizedBox(height: 14),
                      const Text('無料との違い', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
                      const SizedBox(height: 10),
                      const _Compare(),
                      const SizedBox(height: 22),
                      const Text('プランを選ぶ', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
                      const SizedBox(height: 16),
                      Row(children: [
                        Expanded(child: _Plan('年額', ypr, save != null ? '1か月あたり 約${_perMonth(billing.yearly)}円' : '1年ごと', save != null ? '$save% おトク' : 'おすすめ', yearlySel, () => billing.select(kProductYearly))),
                        const SizedBox(width: 10),
                        Expanded(child: _Plan('月額', mpr, '1か月ごと', null, !yearlySel, () => billing.select(kProductMonthly))),
                      ]),
                      const SizedBox(height: 14),
                      Text(
                        'お支払いは Google Play のアカウントに請求されます。定期購入は、期間が終わる24時間前までに解約しない限り、自動で更新されます。解約は Google Play の「定期購入」から、いつでもできます。',
                        style: TextStyle(fontSize: 11, height: 1.55, color: cs.onSurface.withValues(alpha: 0.6)),
                      ),
                    ]),
                  ),
                ),
              ]),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  if (billing.premium)
                    const Text('プレミアムをご利用中です', style: TextStyle(fontWeight: FontWeight.w800, color: _coral))
                  else
                    SizedBox(
                      width: double.infinity,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: _coral,
                          borderRadius: BorderRadius.circular(99),
                        ),
                        child: FilledButton(
                          onPressed: sel == null || billing.busy ? null : billing.buy,
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            disabledBackgroundColor: const Color(0x66BFA77A),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          child: billing.busy
                              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF151515)))
                              : Text(sel == null ? 'じゅんび中です' : (yearlySel ? '年額 $ypr で始める' : '月額 $mpr で始める'),
                                  style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.w700, color: Color(0xFF151515))),
                        ),
                      ),
                    ),
                  TextButton(onPressed: billing.restore, child: const Text('購入を復元', style: TextStyle(fontSize: 12.5))),
                ]),
              ),
            ),
          ]);
        },
      ),
    );
  }

  static String _perMonth(dynamic pd) {
    try {
      final v = (pd.rawPrice as double) / 12;
      return v.round().toString();
    } catch (_) {
      return '140';
    }
  }
}

class _Hero extends StatelessWidget {
  const _Hero({this.why});
  final String? why;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF151515),
        border: Border(bottom: BorderSide(color: Color(0xFF2A2A2A))),
      ),
      padding: EdgeInsets.fromLTRB(16, MediaQuery.of(context).padding.top + 8, 16, 52),
      child: Column(children: [
        Align(
          alignment: Alignment.centerLeft,
          child: IconButton(
            onPressed: () => Navigator.of(context).maybePop(),
            icon: const Icon(Icons.close, color: Colors.white),
            style: IconButton.styleFrom(backgroundColor: const Color(0xFF242424)),
          ),
        ),
        SizedBox(width: 280, height: 170, child: CustomPaint(painter: _GemPainter())),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(99),
            border: Border.all(color: const Color(0xFF5A5242)),
          ),
          child: const Text('PREMIUM', style: TextStyle(color: _orange, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 2.2)),
        ),
        const SizedBox(height: 10),
        const Text('全国の「行きたい」を、\nひとつの場所に。',
            textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontSize: 25, fontWeight: FontWeight.w900, height: 1.3)),
        const SizedBox(height: 6),
        Text(why ?? '掲示板への投稿・連絡と、ふれあいレーダーが使えます。',
            textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 14)),
      ]),
    );
  }
}

class _GemPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // 細い線のダイヤ（静かな見た目）
    final c = Offset(size.width / 2, size.height / 2);
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round
      ..color = _coral;
    final fine = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..strokeJoin = StrokeJoin.round
      ..color = _coral.withValues(alpha: 0.7);
    final l = c + const Offset(-44, -14), r = c + const Offset(44, -14);
    final tl = c + const Offset(-24, -34), tr = c + const Offset(24, -34);
    final bottom = c + const Offset(0, 40);
    canvas.drawPath(Path()..moveTo(tl.dx, tl.dy)..lineTo(tr.dx, tr.dy)..lineTo(r.dx, r.dy)..lineTo(bottom.dx, bottom.dy)..lineTo(l.dx, l.dy)..close(), line);
    canvas.drawLine(l, r, fine);
    canvas.drawLine(tl, c + const Offset(-14, -14), fine);
    canvas.drawLine(c + const Offset(-14, -14), bottom, fine);
    canvas.drawLine(tr, c + const Offset(14, -14), fine);
    canvas.drawLine(c + const Offset(14, -14), bottom, fine);
    canvas.drawLine(c + const Offset(0, -34), c + const Offset(-14, -14), fine);
    canvas.drawLine(c + const Offset(0, -34), c + const Offset(14, -14), fine);
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

class _Feature extends StatelessWidget {
  const _Feature(this.icon, this.c1, this.c2, this.title, this.body);
  final IconData icon;
  final Color c1;
  final Color c2;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF2A2A2A)),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFF3A362C)),
          ),
          child: Icon(icon, color: _orange, size: 24),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800)),
            const SizedBox(height: 2),
            Text(body, style: TextStyle(fontSize: 13, height: 1.5, color: cs.onSurface.withValues(alpha: 0.65))),
          ]),
        ),
      ]),
    );
  }
}

class _Compare extends StatelessWidget {
  const _Compare();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    const rows = [
      ('同じWiFiの人と出会う', true),
      ('1対1のチャット・写真', true),
      ('全国掲示板を見る', true),
      ('ふれあいレーダー', false),
      ('掲示板に投稿・連絡する', false),
    ];
    Widget cell(bool ok, {bool pro = false}) => Container(
          width: 76,
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(vertical: 11),
          color: pro ? const Color(0x17BFA77A) : null,
          child: Icon(ok ? Icons.check : Icons.remove, size: 19, color: ok ? _coral : cs.onSurface.withValues(alpha: 0.35)),
        );
    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF2A2A2A)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(children: [
        Row(children: [
          const Expanded(child: SizedBox()),
          Container(width: 76, alignment: Alignment.center, padding: const EdgeInsets.symmetric(vertical: 10), child: Text('無料', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: cs.onSurface.withValues(alpha: 0.55)))),
          Container(width: 76, alignment: Alignment.center, padding: const EdgeInsets.symmetric(vertical: 10), color: const Color(0x17BFA77A), child: const Text('プレミアム', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: _coral))),
        ]),
        for (final r in rows)
          Container(
            decoration: BoxDecoration(border: Border(top: BorderSide(color: cs.onSurface.withValues(alpha: 0.08)))),
            child: Row(children: [
              Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 12), child: Text(r.$1, style: const TextStyle(fontSize: 13.5)))),
              cell(r.$2),
              cell(true, pro: true),
            ]),
          ),
      ]),
    );
  }
}

class _Plan extends StatelessWidget {
  const _Plan(this.title, this.price, this.sub, this.badge, this.selected, this.onTap);
  final String title;
  final String price;
  final String sub;
  final String? badge;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: Stack(clipBehavior: Clip.none, alignment: Alignment.topCenter, children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(8, 22, 8, 14),
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: selected ? _coral : const Color(0xFF333333), width: selected ? 1.5 : 1),
          ),
          child: Column(children: [
            Text(title, style: TextStyle(fontSize: 14, color: cs.onSurface.withValues(alpha: 0.6))),
            Text(price, style: TextStyle(fontSize: 28, fontWeight: FontWeight.w500, color: selected ? _orange : _inkOf(cs), height: 1.2)),
            Text(sub, textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: cs.onSurface.withValues(alpha: 0.6))),
          ]),
        ),
        if (badge != null)
          Positioned(
            top: -11,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
              decoration: BoxDecoration(color: _coral, borderRadius: BorderRadius.circular(99)),
              child: Text(badge!, style: const TextStyle(color: Color(0xFF151515), fontSize: 11.5, fontWeight: FontWeight.w800)),
            ),
          ),
      ]),
    );
  }

  Color _inkOf(ColorScheme cs) => cs.brightness == Brightness.dark ? Colors.white : _ink;
}

/// 呼び出し元から使う、小さな顔アイコン（ここで再エクスポート）
Widget faceOf(String seed, double size) => FaceAvatar(seed, size: size);
