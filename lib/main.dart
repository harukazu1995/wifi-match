import 'dart:async';
import 'dart:io' show File;
import 'dart:math' as math;

import 'package:flutter/material.dart' hide SelectableText, Text;
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter/services.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:image_picker/image_picker.dart';
import 'package:in_app_purchase/in_app_purchase.dart' show ProductDetails;
import 'package:shared_preferences/shared_preferences.dart';

import 'billing.dart';
import 'art.dart';
import 'board.dart';
import 'contact.dart';
import 'paywall.dart';
import 'radar_scope.dart';
import 'i18n.dart';
import 'mesh.dart';
import 'proximity.dart';

final mesh = MeshService();
final navKey = GlobalKey<NavigatorState>();
final messengerKey = GlobalKey<ScaffoldMessengerState>();
final prox = ProximityService();
final billing = Billing();
final homeTab = ValueNotifier<int>(0);

const kPrivacyUrl = 'https://github.com/harukazu1995/wifi-match/blob/main/PRIVACY.md';
const kContactUrl = 'https://github.com/harukazu1995/wifi-match/issues';

const _coral = Color(0xFFFF4D6D);
const _orange = Color(0xFFFF8A4C);
const _ink = Color(0xFF2B2430);
const _bg = Color(0xFFFFF8F3);
const _sharedColor = Color(0xFFFFE9A8);
const _brandGradient = LinearGradient(colors: [_coral, _orange], begin: Alignment.topLeft, end: Alignment.bottomRight);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await mesh.load();
  await Prefs.load();
  await prox.load();
  await billing.loadStored();
  unawaited(billing.init());
  if (mesh.me != null) unawaited(mesh.start());
  runApp(const WifiMatchApp());
}

class WifiMatchApp extends StatelessWidget {
  const WifiMatchApp({super.key});

  // 明るい配色に固定（端末のダークモードに引きずられて暗くならないようにする）
  ThemeData _theme() {
    final scheme = ColorScheme.fromSeed(seedColor: _coral, brightness: Brightness.light, primary: _coral).copyWith(
      surface: Colors.white,
      onSurface: _ink,
      primaryContainer: const Color(0xFFFFE3E8),
      onPrimaryContainer: const Color(0xFF7A1F33),
      surfaceContainerHighest: const Color(0xFFF6ECE6),
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: _bg,
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 3,
        shadowColor: const Color(0x22FF4D6D),
        surfaceTintColor: Colors.transparent,
        margin: const EdgeInsets.only(bottom: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: _bg,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        centerTitle: false,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: const StadiumBorder(),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(style: OutlinedButton.styleFrom(shape: const StadiumBorder())),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 12,
        shadowColor: const Color(0x33FF4D6D),
        indicatorColor: const Color(0xFFFFE3E8),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (s) => TextStyle(fontSize: 12, fontWeight: s.contains(WidgetState.selected) ? FontWeight.w800 : FontWeight.w500),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFFF0DED5))),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFFF0DED5))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: _coral, width: 2)),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: _ink,
        contentTextStyle: const TextStyle(color: Colors.white),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Meetory',
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      supportedLocales: const [Locale('ja'), Locale('en'), Locale('ko'), Locale('zh')],
      localeResolutionCallback: (locale, supported) {
        final code = locale?.languageCode;
        return Locale(code == 'ja' || code == 'ko' || code == 'zh' ? code! : 'en');
      },
      debugShowCheckedModeBanner: false,
      navigatorKey: navKey,
      scaffoldMessengerKey: messengerKey,
      theme: _theme(),
      themeMode: ThemeMode.light,
      home: const _AppGate(),
    );
  }
}

// ======================= 起動アニメーション =======================

/// アプリのロゴ（ガラスの吹き出しとWiFi）。progress(0〜1)で、電波が内側から描かれていく。
class WifiLogo extends StatelessWidget {
  const WifiLogo({super.key, this.progress = 1, this.size = 120});
  final double progress;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _LogoPainter(progress)),
    );
  }
}

class _LogoPainter extends CustomPainter {
  _LogoPainter(this.progress);
  final double progress;

  Path _bubble() {
    const x = 150.0, y = 210.0, w = 724.0, h = 520.0, r = 200.0;
    return Path()
      ..arcTo(Rect.fromLTWH(x, y, 2 * r, 2 * r), math.pi, math.pi / 2, false)
      ..arcTo(Rect.fromLTWH(x + w - 2 * r, y, 2 * r, 2 * r), -math.pi / 2, math.pi / 2, false)
      ..arcTo(Rect.fromLTWH(x + w - 2 * r, y + h - 2 * r, 2 * r, 2 * r), 0, math.pi / 2, false)
      ..lineTo(x + r + 100, y + h)
      ..lineTo(260, 880)
      ..lineTo(x + r - 30, y + h)
      ..arcTo(Rect.fromLTWH(x, y + h - 2 * r, 2 * r, 2 * r), math.pi / 2, math.pi / 2, false)
      ..close();
  }

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 1024);
    const full = Rect.fromLTWH(0, 0, 1024, 1024);
    canvas.save();
    canvas.clipRRect(RRect.fromRectAndRadius(full, const Radius.circular(230)));
    canvas.drawRect(
      full,
      Paint()
        ..shader = const LinearGradient(
          colors: [Color(0xFFFF3D6B), Color(0xFF5B3DFF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ).createShader(full),
    );
    void glow(Offset c, double r, Color col) {
      canvas.drawRect(
        full,
        Paint()
          ..shader = RadialGradient(colors: [col, col.withValues(alpha: 0)])
              .createShader(Rect.fromCircle(center: c, radius: r)),
      );
    }

    glow(const Offset(200, 180), 560, const Color(0xC8FFB347));
    glow(const Offset(860, 900), 560, const Color(0xBE29D6FF));
    glow(const Offset(800, 150), 380, const Color(0x78FF6AD5));
    canvas.restore();

    final bubble = _bubble();
    canvas.drawPath(
      bubble.shift(const Offset(0, 24)),
      Paint()
        ..color = const Color(0x402A0F5E)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 22),
    );
    const bb = Rect.fromLTWH(150, 210, 724, 670);
    canvas.drawPath(
      bubble,
      Paint()
        ..shader = const LinearGradient(
          colors: [Color(0x96FFFFFF), Color(0x32FFFFFF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ).createShader(bb),
    );
    canvas.drawPath(
      bubble,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6
        ..strokeJoin = StrokeJoin.round
        ..shader = const LinearGradient(
          colors: [Color(0xE6FFFFFF), Color(0x28FFFFFF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ).createShader(bb),
    );

    const center = Offset(512, 520);
    const radii = [70.0, 135.0, 200.0];
    final dot = Curves.easeOutBack.transform(((progress - 0.1) / 0.3).clamp(0.0, 1.0));
    canvas.drawCircle(center, 38 * dot, Paint()..color = Colors.white);
    for (var i = 0; i < 3; i++) {
      // 内側から順に、ふわっと現れる
      final a = ((progress - 0.3 - i * 0.14) / 0.22).clamp(0.0, 1.0);
      if (a <= 0) continue;
      final rect = Rect.fromCircle(center: center, radius: radii[i]);
      canvas.drawArc(
        rect.shift(const Offset(0, 10)),
        -math.pi * 3 / 4,
        math.pi / 2,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = 44
          ..color = const Color(0x55D02A4E).withValues(alpha: 0.33 * a)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, 8),
      );
      canvas.drawArc(
        rect,
        -math.pi * 3 / 4,
        math.pi / 2,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = 44
          ..color = Colors.white.withValues(alpha: a),
      );
    }
  }

  @override
  bool shouldRepaint(_LogoPainter old) => old.progress != progress;
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key, required this.onDone});
  final VoidCallback onDone;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 2600));

  @override
  void initState() {
    super.initState();
    _c.forward().whenComplete(() {
      if (mounted) widget.onDone();
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(colors: [Color(0xFFFFF8F3), Color(0xFFFFE3E8)], begin: Alignment.topCenter, end: Alignment.bottomCenter),
        ),
        child: Center(
          child: AnimatedBuilder(
            animation: _c,
            builder: (context, _) {
              final logo = Interval(0, 0.7, curve: Curves.easeOut).transform(_c.value);
              final text = Interval(0.55, 0.85, curve: Curves.easeOut).transform(_c.value);
              final sub = Interval(0.7, 1.0, curve: Curves.easeOut).transform(_c.value);
              return Column(mainAxisSize: MainAxisSize.min, children: [
                WifiLogo(progress: logo, size: 170),
                const SizedBox(height: 8),
                Opacity(
                  opacity: text,
                  child: Transform.translate(
                    offset: Offset(0, 14 * (1 - text)),
                    child: const Text.rich(TextSpan(children: [
                      TextSpan(text: 'Meet', style: TextStyle(color: _ink)),
                      TextSpan(text: 'ory', style: TextStyle(color: _coral)),
                    ]), style: TextStyle(fontSize: 34, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
                  ),
                ),
                const SizedBox(height: 8),
                Opacity(
                  opacity: sub,
                  child: Text('同じWiFiの人と、つながろう。', style: TextStyle(fontSize: 14, color: _ink.withValues(alpha: 0.6))),
                ),
              ]);
            },
          ),
        ),
      ),
    );
  }
}

/// 起動時にロゴのアニメーションを見せてから、本編の画面に切り替える。
class _AppGate extends StatefulWidget {
  const _AppGate();

  @override
  State<_AppGate> createState() => _AppGateState();
}

class _AppGateState extends State<_AppGate> {
  bool _done = false;
  bool _introSeen = Prefs.introSeen;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 450),
      child: _done && !_introSeen
          ? IntroScreen(
              key: const ValueKey('intro'),
              onDone: () {
                Prefs.markIntroSeen();
                setState(() => _introSeen = true);
              },
            )
          : _done
          ? ListenableBuilder(
              key: const ValueKey('app'),
              listenable: mesh,
              builder: (context, _) => mesh.me == null ? const OnboardingScreen() : const HomeScreen(),
            )
          : SplashScreen(key: const ValueKey('splash'), onDone: () => setState(() => _done = true)),
    );
  }
}

/// 端末に保存する小さな設定（最初の説明を見たか、通知のオン・オフ）
class Prefs {
  static bool introSeen = false;
  static final ValueNotifier<bool> promoHidden = ValueNotifier<bool>(false);
  static final ValueNotifier<bool> proxSeen = ValueNotifier<bool>(false);

  static Future<void> load() async {
    try {
      final p = await SharedPreferences.getInstance();
      introSeen = p.getBool('wm_intro_seen') ?? false;
      promoHidden.value = p.getBool('wm_promo_hidden') ?? false;
      proxSeen.value = p.getBool('wm_prox_seen') ?? false;
      Notifier.on.value = p.getBool('wm_notify') ?? true;
    } catch (_) {}
  }

  static Future<void> hidePromo() async {
    promoHidden.value = true;
    try {
      await (await SharedPreferences.getInstance()).setBool('wm_promo_hidden', true);
    } catch (_) {}
  }

  static Future<void> markProxSeen() async {
    if (proxSeen.value) return;
    proxSeen.value = true;
    try {
      await (await SharedPreferences.getInstance()).setBool('wm_prox_seen', true);
    } catch (_) {}
  }

  static Future<void> markIntroSeen() async {
    introSeen = true;
    try {
      await (await SharedPreferences.getInstance()).setBool('wm_intro_seen', true);
    } catch (_) {}
  }
}

/// メッセージなどが届いたときの通知（端末の中だけで出す。アプリを閉じている間のみ）
class Notifier {
  static const _ch = MethodChannel('wifimatch/net');
  static final ValueNotifier<bool> on = ValueNotifier<bool>(true);

  static Future<void> setEnabled(bool v) async {
    on.value = v;
    try {
      await (await SharedPreferences.getInstance()).setBool('wm_notify', v);
    } catch (_) {}
    if (v) await requestPermission();
  }

  static Future<void> requestPermission() async {
    try {
      await _ch.invokeMethod<void>('requestNotifPermission');
    } catch (_) {}
  }

  static Future<void> show(String title, String body) async {
    if (!on.value) return;
    try {
      await _ch.invokeMethod<void>('notify', {'title': tr(title), 'body': tr(body)});
    } catch (_) {}
  }
}

/// 最初に1回だけ出す、アプリの簡単な説明
class IntroScreen extends StatefulWidget {
  const IntroScreen({super.key, required this.onDone});
  final VoidCallback onDone;

  @override
  State<IntroScreen> createState() => _IntroScreenState();
}

class _IntroScreenState extends State<IntroScreen> {
  final _pc = PageController();
  int _i = 0;

  static const _pages = [
    ('📡', '同じWiFiの人が見つかる', 'アプリを入れた人どうしが、同じWiFiにいるときだけ、お互いを見つけられます。共通の趣味が多い人から順に表示されます。'),
    ('💞', 'いいねして、マッチ', 'お互いにいいねすると「マッチ」。マッチした人とだけ、1対1でチャットや写真を送り合えます。広場では、みんなと話せます。'),
    ('💎', 'プレミアムで、もっと広がる', '無料でも、近くの人とのマッチやチャット、全国の掲示板を見ることができます。プレミアムでは、WiFiがなくても近くの人に気づける「レーダー」と、掲示板への投稿・連絡が使えます。月額200円・年額1,680円の予定です（今は無料のベータ版です）。'),
    ('🛡️', '安心して使うために', 'サーバーは使わず、データはあなたのスマホの中だけ。不快な相手は、通報・ブロックできます。18歳以上の方のみご利用いただけます。'),
  ];

  @override
  void dispose() {
    _pc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final last = _i == _pages.length - 1;
    return Scaffold(
      body: SafeArea(
        child: Column(children: [
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(onPressed: widget.onDone, child: const Text('スキップ')),
          ),
          Expanded(
            child: PageView(
              controller: _pc,
              onPageChanged: (i) => setState(() => _i = i),
              children: [
                for (final (emoji, title, body) in _pages)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Text(emoji, style: const TextStyle(fontSize: 88)),
                      const SizedBox(height: 24),
                      Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 12),
                      Text(body,
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 16, height: 1.6, color: Theme.of(context).hintColor)),
                    ]),
                  ),
              ],
            ),
          ),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            for (var k = 0; k < _pages.length; k++)
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.all(4),
                width: k == _i ? 22 : 8,
                height: 8,
                decoration: BoxDecoration(color: k == _i ? _coral : const Color(0xFFE6D8D0), borderRadius: BorderRadius.circular(99)),
              ),
          ]),
          Padding(
            padding: const EdgeInsets.all(24),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () {
                  if (last) {
                    widget.onDone();
                  } else {
                    _pc.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
                  }
                },
                child: Text(last ? 'はじめる' : '次へ', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

void toast(String text) {
  messengerKey.currentState
    ?..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text), behavior: SnackBarBehavior.floating, duration: const Duration(seconds: 2)));
}

String hhmm(int ms) {
  final d = DateTime.fromMillisecondsSinceEpoch(ms);
  return '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
}

// ======================= 広告（Google AdMob） =======================

/// true の間は Google が用意したテスト広告を表示する（自分で広告を押しても問題ない）。
/// AdMob の審査が通って本番の広告に切り替えるときだけ false にする。
const bool kUseTestAds = false;
const String _bannerUnitTest = 'ca-app-pub-3940256099942544/6300978111';
const String _bannerUnitProd = 'ca-app-pub-6787171058926480/5616465700';
const String _interstitialUnitTest = 'ca-app-pub-3940256099942544/1033173712';
const String _interstitialUnitProd = 'ca-app-pub-6787171058926480/3264743884';

class AdService {
  static bool _started = false;
  static InterstitialAd? _inter;
  static bool _interLoading = false;
  static DateTime _lastInter = DateTime.now();
  static int _breaks = 0;

  static void _loadInterstitial() {
    if (_inter != null || _interLoading || !ready.value) return;
    _interLoading = true;
    InterstitialAd.load(
      adUnitId: kUseTestAds ? _interstitialUnitTest : _interstitialUnitProd,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _inter = ad;
          _interLoading = false;
        },
        onAdFailedToLoad: (error) {
          _interLoading = false;
        },
      ),
    );
  }

  /// 画面の切り替わりなど、自然な区切りで全画面広告を出す。出しすぎないよう、2分に1回まで。
  static void maybeShowInterstitial() {
    if (!ready.value) return;
    final ad = _inter;
    if (ad == null) {
      _loadInterstitial();
      return;
    }
    if (DateTime.now().difference(_lastInter) < const Duration(minutes: 2)) return;
    _inter = null;
    _lastInter = DateTime.now();
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (a) {
        a.dispose();
        _loadInterstitial();
      },
      onAdFailedToShowFullScreenContent: (a, e) {
        a.dispose();
        _loadInterstitial();
      },
    );
    ad.show();
  }

  /// タブを切り替えたときに数える。4回に1回、広告を出してよいか確かめる。
  static void tabChanged() {
    _breaks++;
    if (_breaks % 4 == 0) maybeShowInterstitial();
  }

  /// 広告を出してよい状態になったら true
  static final ValueNotifier<bool> ready = ValueNotifier<bool>(false);

  /// 利用者の同意を確認してから、広告の準備を始める。
  static Future<void> start() async {
    if (_started) return;
    _started = true;
    try {
      final done = Completer<void>();
      ConsentInformation.instance.requestConsentInfoUpdate(
        ConsentRequestParameters(tagForUnderAgeOfConsent: false),
        () {
          ConsentForm.loadAndShowConsentFormIfRequired((FormError? error) {
            if (!done.isCompleted) done.complete();
          });
        },
        (FormError error) {
          if (!done.isCompleted) done.complete();
        },
      );
      await done.future.timeout(const Duration(seconds: 30), onTimeout: () {});
      if (await ConsentInformation.instance.canRequestAds()) {
        await MobileAds.instance.updateRequestConfiguration(RequestConfiguration(
          tagForChildDirectedTreatment: TagForChildDirectedTreatment.no,
          tagForUnderAgeOfConsent: TagForUnderAgeOfConsent.no,
          maxAdContentRating: MaxAdContentRating.pg,
        ));
        await MobileAds.instance.initialize();
        ready.value = true;
        _loadInterstitial();
      }
    } catch (_) {
      // 広告の準備に失敗しても、アプリ本体は普通に使える
    }
  }
}

/// 画面の下に出す小さなバナー広告。広告が読み込めるまでは何も表示しない。
class AdBanner extends StatefulWidget {
  const AdBanner({super.key});

  @override
  State<AdBanner> createState() => _AdBannerState();
}

class _AdBannerState extends State<AdBanner> {
  BannerAd? _ad;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    AdService.ready.addListener(_maybeLoad);
    _maybeLoad();
  }

  void _maybeLoad() {
    if (_ad != null || !AdService.ready.value) return;
    final ad = BannerAd(
      adUnitId: kUseTestAds ? _bannerUnitTest : _bannerUnitProd,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) {
          if (mounted) setState(() => _loaded = true);
        },
        onAdFailedToLoad: (failed, error) {
          failed.dispose();
          if (mounted) {
            setState(() {
              _ad = null;
              _loaded = false;
            });
          }
        },
      ),
    );
    _ad = ad;
    ad.load();
  }

  @override
  void dispose() {
    AdService.ready.removeListener(_maybeLoad);
    _ad?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ad = _ad;
    if (!_loaded || ad == null) return const SizedBox.shrink();
    return Container(
      color: Colors.white,
      alignment: Alignment.center,
      width: double.infinity,
      height: AdSize.banner.height.toDouble(),
      child: SizedBox(width: AdSize.banner.width.toDouble(), height: AdSize.banner.height.toDouble(), child: AdWidget(ad: ad)),
    );
  }
}

// ======================= 共通パーツ =======================

class Avatar extends StatelessWidget {
  const Avatar(this.emoji, {super.key, this.online = false, this.size = 56});
  final String emoji;
  final bool online;
  final double size;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(children: [
        Container(
          width: size,
          height: size,
          alignment: Alignment.center,
          child: FaceAvatar(emoji, size: size),
        ),
        if (online)
          Positioned(
            right: 1,
            bottom: 1,
            child: Container(
              width: size * 0.24,
              height: size * 0.24,
              decoration: BoxDecoration(
                color: const Color(0xFF1FB57A),
                shape: BoxShape.circle,
                border: Border.all(color: Theme.of(context).scaffoldBackgroundColor, width: 2),
              ),
            ),
          ),
      ]),
    );
  }
}

class Pill extends StatelessWidget {
  const Pill(this.text, {super.key, this.color, this.bold = false, this.textColor});
  final String text;
  final Color? color;
  final Color? textColor;
  final bool bold;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
        decoration: BoxDecoration(
          color: color ?? Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(99),
        ),
        child: Text(text,
            style: TextStyle(fontSize: 12.5, fontWeight: bold ? FontWeight.w700 : FontWeight.w400, color: textColor)),
      );
}

class EmptyState extends StatelessWidget {
  const EmptyState(this.icon, this.text, {super.key});
  final String icon;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
        child: Column(children: [
          Text(icon, style: const TextStyle(fontSize: 44)),
          const SizedBox(height: 8),
          Text(text, textAlign: TextAlign.center, style: TextStyle(color: Theme.of(context).hintColor)),
        ]),
      );
}

// ======================= プロフィール入力 =======================

class ProfileForm extends StatefulWidget {
  const ProfileForm({super.key, this.initial, required this.submitLabel, this.askAdult = false});
  final Profile? initial;
  final String submitLabel;
  final bool askAdult;

  @override
  State<ProfileForm> createState() => _ProfileFormState();
}

class _ProfileFormState extends State<ProfileForm> {
  static const _suggest = ['カフェ', '映画', '音楽', 'ゲーム', '読書', 'アニメ', 'スポーツ', '旅行', '料理', '写真', 'プログラミング', 'お酒', '散歩', '筋トレ'];
  late String _emoji = widget.initial?.emoji ?? kEmojis.first;
  late final _name = TextEditingController(text: widget.initial?.name ?? '');
  late final _bio = TextEditingController(text: widget.initial?.bio ?? '');
  late final _tags = TextEditingController(text: widget.initial?.tags.join(' ') ?? '');
  bool _adult = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _bio.dispose();
    _tags.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (widget.askAdult && !_adult) {
      setState(() => _error = '18歳以上であることの確認が必要です');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await mesh.setProfile(name: _name.text, emoji: _emoji, bio: _bio.text, tags: parseTags(_tags.text));
      if (widget.initial != null) toast('保存しました');
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _label(String t, [String? hint]) => Padding(
        padding: const EdgeInsets.only(top: 18, bottom: 6),
        child: Text.rich(TextSpan(children: [
          TextSpan(text: tr(t), style: const TextStyle(fontWeight: FontWeight.w700)),
          if (hint != null) TextSpan(text: '  ${tr(hint)}', style: TextStyle(fontSize: 12, color: Theme.of(context).hintColor)),
        ])),
      );

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final current = parseTags(_tags.text);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _label('アイコン'),
      Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          for (final e in kEmojis)
            InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => setState(() => _emoji = e),
              child: Container(
                width: 42,
                height: 42,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: e == _emoji ? cs.primaryContainer : cs.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: e == _emoji ? cs.primary : Colors.transparent, width: 2),
                ),
                child: FaceAvatar(e, size: 34),
              ),
            ),
        ],
      ),
      _label('ニックネーム', '本名は避けましょう'),
      TextField(controller: _name, maxLength: 20, decoration: const InputDecoration(counterText: '')),
      _label('ひとこと', '160字まで'),
      TextField(
        controller: _bio,
        maxLength: 160,
        maxLines: 3,
        decoration: InputDecoration(hintText: tr('例：窓際の席で作業してます。コーヒー好きな人と話したい'), counterText: ''),
      ),
      _label('趣味・興味', 'スペース区切りで最大8個'),
      TextField(
        controller: _tags,
        onChanged: (_) => setState(() {}),
        decoration: InputDecoration(hintText: tr('カフェ 映画 ゲーム')),
      ),
      const SizedBox(height: 8),
      Wrap(spacing: 6, runSpacing: 6, children: [
        for (final s in _suggest.map(tr))
          FilterChip(
            label: Text(s),
            selected: current.contains(s),
            onSelected: (on) {
              final next = on ? [...current, s] : current.where((x) => x != s).toList();
              setState(() => _tags.text = next.take(8).join(' '));
            },
          ),
      ]),
      if (widget.askAdult) ...[
        const SizedBox(height: 12),
        CheckboxListTile(
          value: _adult,
          onChanged: (v) => setState(() => _adult = v ?? false),
          controlAffinity: ListTileControlAffinity.leading,
          contentPadding: EdgeInsets.zero,
          title: const Text('18歳以上です。連絡先や住所などの個人情報を安易に教えないことに同意します。', style: TextStyle(fontSize: 14)),
        ),
      ],
      if (_error != null)
        Padding(padding: const EdgeInsets.only(top: 8), child: Text(_error!, style: TextStyle(color: cs.error))),
      const SizedBox(height: 16),
      FilledButton(
        onPressed: _busy ? null : _submit,
        style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
        child: Text(widget.submitLabel, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
      ),
    ]);
  }
}

class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListView(padding: const EdgeInsets.all(20), children: [
          const SizedBox(height: 16),
          const Center(child: WifiLogo(size: 110)),
          const SizedBox(height: 8),
          const Text('同じWiFiの人と、つながろう。',
              textAlign: TextAlign.center, style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text('アプリを入れた人同士が、同じWiFiにいるときだけお互いを見つけられます。サーバーは使いません。',
              textAlign: TextAlign.center, style: TextStyle(color: Theme.of(context).hintColor)),
          const SizedBox(height: 8),
          const ProfileForm(submitLabel: 'はじめる', askAdult: true),
        ]),
      ),
    );
  }
}

// ======================= ホーム =======================

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  int _tab = 0;
  bool _bg = false; // アプリが裏に回っている間は、通知で知らせる
  StreamSubscription<MeshEvent>? _sub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _sub = mesh.events.listen(_onEvent);
    unawaited(AdService.start());
    if (Notifier.on.value) unawaited(Notifier.requestPermission());
    homeTab.addListener(_onHomeTab);
    unawaited(prox.resumeIfNeeded(me: mesh.me, blockedIds: mesh.blocked, allowed: billing.premium || kProximityFreeBeta));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    homeTab.removeListener(_onHomeTab);
    _sub?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _bg = state == AppLifecycleState.paused;
    if (state == AppLifecycleState.resumed) {
      if (mesh.running) {
        mesh.announce();
      } else {
        mesh.start();
      }
    }
  }

  void _onHomeTab() {
    if (mounted && _tab != homeTab.value) setState(() => _tab = homeTab.value);
  }

  void _onEvent(MeshEvent e) {
    switch (e.type) {
      case MeshEventType.match:
        if (e.who != null) _showMatch(e.who!);
        if (_bg) Notifier.show('💞 マッチしました', '${e.who?.name ?? '誰か'} さんとお互いにいいねしました');
      case MeshEventType.liked:
        toast('💌 誰かがあなたにいいねしました');
        if (_bg) Notifier.show('💌 いいねが届きました', '誰かがあなたにいいねしました');
      case MeshEventType.dm:
        if (ChatScreen.openWith != e.who?.id) toast('💬 ${e.who?.name ?? '誰か'} さんからメッセージ');
        if (_bg) Notifier.show('💬 ${e.who?.name ?? '誰か'} さんからメッセージ', e.text ?? '');
      case MeshEventType.plaza:
        break;
    }
  }

  void _showMatch(Profile p) {
    final ctx = navKey.currentContext;
    if (ctx == null) return;
    showDialog<void>(
      context: ctx,
      builder: (ctx) => AlertDialog(
        contentPadding: const EdgeInsets.fromLTRB(24, 28, 24, 12),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('${mesh.me?.emoji ?? ''}${p.emoji}', style: const TextStyle(fontSize: 56)),
          const SizedBox(height: 8),
          const Text('マッチしました！', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: _coral)),
          const SizedBox(height: 6),
          Text('${p.name} さんとお互いにいいねしました', textAlign: TextAlign.center),
        ]),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('あとで')),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              ChatScreen.open(p.id);
            },
            child: const Text('メッセージを送る'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: mesh,
      builder: (context, _) {
        final online = mesh.onlinePeers.length;
        if (_tab == 2 && mesh.unreadPlaza > 0) {
          WidgetsBinding.instance.addPostFrameCallback((_) => mesh.markPlazaRead());
        }
        return Scaffold(
          appBar: AppBar(
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            title: const Row(mainAxisSize: MainAxisSize.min, children: [
              WifiLogo(size: 34),
              SizedBox(width: 8),
              Text.rich(TextSpan(children: [
                TextSpan(text: 'Meet', style: TextStyle(fontWeight: FontWeight.w900, color: _ink)),
                TextSpan(text: 'ory', style: TextStyle(fontWeight: FontWeight.w900, color: _coral)),
              ])),
            ]),
            actions: [
              Container(
                margin: const EdgeInsets.only(right: 16),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: mesh.running ? const Color(0xFFE3F8EE) : const Color(0xFFEFEFEF),
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.circle, size: 9, color: mesh.running ? const Color(0xFF1FB57A) : Colors.grey),
                  const SizedBox(width: 6),
                  Text(
                    mesh.running ? '近くに $online人' : '停止中',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: mesh.running ? const Color(0xFF127A52) : Colors.black54),
                  ),
                ]),
              ),
            ],
          ),
          // const にしないことで、通信状態が変わるたびに各タブを描き直す
          body: IndexedStack(index: _tab, children: [PeopleTab(), MatchesTab(), PlazaTab(), ProximityTab(), MeTab(), BoardTab()]),
          bottomNavigationBar: Column(mainAxisSize: MainAxisSize.min, children: [
            const AdBanner(),
            NavigationBar(
            selectedIndex: _tab,
            onDestinationSelected: (i) {
              if (i == 3) Prefs.markProxSeen();
              setState(() => _tab = i);
              homeTab.value = i;
              AdService.tabChanged();
              if (i == 2) mesh.markPlazaRead();
            },
            destinations: [
              NavigationDestination(icon: const Icon(Icons.people_outline), selectedIcon: const Icon(Icons.people), label: tr('みんな')),
              NavigationDestination(
                icon: Badge(isLabelVisible: mesh.unreadTotal > 0, label: Text('${mesh.unreadTotal}'), child: const Icon(Icons.favorite_border)),
                selectedIcon: const Icon(Icons.favorite),
                label: tr('マッチ'),
              ),
              NavigationDestination(
                icon: Badge(
                  isLabelVisible: mesh.unreadPlaza > 0 && _tab != 2,
                  label: Text('${mesh.unreadPlaza}'),
                  child: const Icon(Icons.forum_outlined),
                ),
                selectedIcon: const Icon(Icons.forum),
                label: tr('広場'),
              ),
              NavigationDestination(
                icon: Badge(
                  isLabelVisible: !Prefs.proxSeen.value,
                  label: const Text('NEW'),
                  child: const Icon(Icons.directions_walk),
                ),
                selectedIcon: const Icon(Icons.directions_walk),
                label: tr('レーダー'),
              ),
              NavigationDestination(icon: const Icon(Icons.person_outline), selectedIcon: const Icon(Icons.person), label: tr('自分')),
              NavigationDestination(icon: const Icon(Icons.campaign_outlined), selectedIcon: const Icon(Icons.campaign), label: tr('掲示板')),
            ],
          ),
          ]),
        );
      },
    );
  }
}

class _Header extends StatelessWidget {
  const _Header(this.title, this.sub);
  final String title;
  final String sub;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
          const SizedBox(height: 2),
          Text(sub, style: TextStyle(color: Theme.of(context).hintColor, fontSize: 14)),
        ]),
      );
}

class _Notice extends StatelessWidget {
  const _Notice(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: Theme.of(context).colorScheme.primaryContainer, borderRadius: BorderRadius.circular(14)),
        child: Text(text, style: const TextStyle(fontSize: 14)),
      );
}

// ======================= みんな =======================

class PeopleTab extends StatelessWidget {
  const PeopleTab({super.key});

  @override
  Widget build(BuildContext context) {
    final people = mesh.onlinePeers;
    return RefreshIndicator(
      onRefresh: () async {
        mesh.announce();
        await Future<void>.delayed(const Duration(seconds: 2));
      },
      child: ListView(padding: const EdgeInsets.all(16), children: [
        const _Header('いまここにいる人', '同じWiFiにいるアプリ利用者。共通の趣味が多い順'),
        const PromoCard(),
        if (mesh.startError != null) _Notice('⚠️ ${mesh.startError}'),
        if (mesh.running && mesh.localIps.isEmpty) const _Notice('📵 WiFiに接続されていないようです。WiFiをオンにしてください。'),
        if (mesh.likedMeCount > 0) _Notice('💌 ${mesh.likedMeCount}人があなたにいいねしています。気になる人にいいねを返すとマッチします。'),
        if (people.isEmpty)
          const EmptyState('📡', 'まだ誰も見つかっていません。\n同じWiFiの人にこのアプリを入れてもらいましょう。\n\n※カフェや大学などの公衆WiFiは端末同士の通信が禁止されていることがあります。'),
        for (final p in people) PersonCard(p.profile),
      ]),
    );
  }
}

class PersonCard extends StatelessWidget {
  const PersonCard(this.p, {super.key});
  final Profile p;

  Future<void> _like() async {
    try {
      if (mesh.likesOut.contains(p.id)) {
        await mesh.unlike(p.id);
      } else {
        final matched = await mesh.like(p.id);
        if (!matched) toast('${p.name} さんにいいねしました');
      }
    } catch (e) {
      toast(e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final shared = mesh.sharedTags(p);
    final match = mesh.isMatch(p.id);
    final liked = mesh.likesOut.contains(p.id);
    final cs = Theme.of(context).colorScheme;
    return Card(
      color: cs.surface,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Avatar(p.emoji, online: mesh.isOnline(p.id)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Wrap(spacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
                Text(p.name, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                if (match) Pill('マッチ', color: cs.primaryContainer, bold: true),
                if (shared.isNotEmpty) Pill('共通 ${shared.length}', color: _sharedColor, bold: true, textColor: Colors.black87),
              ]),
              const SizedBox(height: 4),
              Text(p.bio.isEmpty ? '（ひとことなし）' : p.bio,
                  style: TextStyle(color: p.bio.isEmpty ? Theme.of(context).hintColor : null)),
              if (p.tags.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(spacing: 6, runSpacing: 6, children: [
                  for (final t in p.tags)
                    shared.contains(t)
                        ? Pill('#$t', color: _sharedColor, bold: true, textColor: Colors.black87)
                        : Pill('#$t'),
                ]),
              ],
              const SizedBox(height: 10),
              Row(children: [
                if (match)
                  FilledButton.icon(onPressed: () => ChatScreen.open(p.id), icon: const Icon(Icons.chat_bubble_outline, size: 18), label: const Text('話す'))
                else if (liked)
                  FilledButton.tonalIcon(onPressed: _like, icon: const Icon(Icons.favorite, size: 18), label: const Text('いいね済み'))
                else
                  FilledButton.icon(onPressed: _like, icon: const Icon(Icons.favorite_border, size: 18), label: const Text('いいね')),
                const Spacer(),
                TextButton(onPressed: () => reportUser(context, p), child: Text('通報', style: TextStyle(color: Theme.of(context).hintColor))),
                TextButton(onPressed: () => confirmBlock(context, p), child: Text('ブロック', style: TextStyle(color: Theme.of(context).hintColor))),
              ]),
            ]),
          ),
        ]),
      ),
    );
  }
}

Future<bool> confirmBlock(BuildContext context, Profile p) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text('${p.name} さんをブロック'),
      content: const Text('お互いに表示されなくなり、メッセージも届かなくなります。'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('キャンセル')),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('ブロック')),
      ],
    ),
  );
  if (ok == true) {
    await mesh.block(p.id);
    toast('ブロックしました');
    return true;
  }
  return false;
}

Future<bool> reportUser(BuildContext context, Profile p) async {
  const reasons = ['不適切な内容・言葉', '嫌がらせ・しつこい迷惑行為', '18歳未満の疑い', '勧誘・宣伝・詐欺の疑い', 'その他'];
  var reason = reasons.first;
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setLocal) => AlertDialog(
        title: Text('${p.name} さんを通報'),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('理由を選んでください。通報すると、この人をブロックし、通報の内容がコピーされます。', style: TextStyle(fontSize: 13)),
          const SizedBox(height: 10),
          Wrap(spacing: 6, runSpacing: 6, children: [
            for (final r in reasons)
              ChoiceChip(label: Text(r), selected: reason == r, onSelected: (_) => setLocal(() => reason = r)),
          ]),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('キャンセル')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('通報してブロック')),
        ],
      ),
    ),
  );
  if (ok != true) return false;
  final report = 'Meetory 通報\n相手: ${p.name} (${p.id})\n理由: $reason\n日時: ${DateTime.now().toIso8601String()}';
  await Clipboard.setData(ClipboardData(text: report));
  await mesh.block(p.id);
  final nav = navKey.currentContext;
  if (nav != null && nav.mounted) {
    await showDialog<void>(
      context: nav,
      builder: (ctx) => AlertDialog(
        title: const Text('通報してブロックしました'),
        content: SelectableText('この人は表示されなくなりました。\n運営にも知らせる場合は、コピーされた通報の内容を、次のページに貼り付けてください。\n$kContactUrl'),
        actions: [FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('閉じる'))],
      ),
    );
  }
  return true;
}

// ======================= マッチ =======================

class MatchesTab extends StatelessWidget {
  const MatchesTab({super.key});

  @override
  Widget build(BuildContext context) {
    final ms = mesh.matches;
    return ListView(padding: const EdgeInsets.all(16), children: [
      const _Header('マッチ', 'お互いにいいねした人とだけ1対1で話せます'),
      if (ms.isEmpty) const EmptyState('💞', 'まだマッチはありません。\n「みんな」から気になる人にいいねしよう。'),
      for (final p in ms)
        Card(
          color: Theme.of(context).colorScheme.surface,
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            leading: Avatar(p.emoji, online: mesh.isOnline(p.id), size: 48),
            title: Text(p.name, style: const TextStyle(fontWeight: FontWeight.w700)),
            subtitle: Text(
              mesh.dms[p.id]?.isNotEmpty == true ? mesh.dms[p.id]!.last.text : (mesh.isOnline(p.id) ? 'オンライン' : 'オフライン'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: (mesh.unread[p.id] ?? 0) > 0 ? Badge(label: Text('${mesh.unread[p.id]}')) : null,
            onTap: () => ChatScreen.open(p.id),
          ),
        ),
    ]);
  }
}

// ======================= チャット部品 =======================

class Bubble extends StatelessWidget {
  const Bubble(this.m, {super.key, this.showWho = false});
  final ChatMessage m;
  final bool showWho;

  @override
  Widget build(BuildContext context) {
    final mine = m.from == mesh.me?.id;
    final who = !mine ? mesh.profileOf(m.from) : null;
    final cs = Theme.of(context).colorScheme;
    final bubble = Container(
      constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.68),
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
      decoration: BoxDecoration(
        color: mine ? null : cs.surface,
        gradient: mine ? _brandGradient : null,
        boxShadow: const [BoxShadow(color: Color(0x14000000), blurRadius: 6, offset: Offset(0, 2))],
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(18),
          topRight: const Radius.circular(18),
          bottomLeft: Radius.circular(mine ? 18 : 6),
          bottomRight: Radius.circular(mine ? 6 : 18),
        ),
      ),
      child: m.img != null ? PhotoTile(m, mine: mine) : Text(m.text, style: TextStyle(color: mine ? Colors.white : null)),
    );
    final time = Text(hhmm(m.at), style: TextStyle(fontSize: 11, color: Theme.of(context).hintColor));
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment: mine ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!mine && showWho) ...[Avatar(m.emoji, size: 36), const SizedBox(width: 8)],
          if (mine) ...[time, const SizedBox(width: 6)],
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (!mine && showWho)
              Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 2),
                child: Text(m.name, style: TextStyle(fontSize: 12, color: Theme.of(context).hintColor)),
              ),
            who == null ? bubble : GestureDetector(onLongPress: () => reportUser(context, who), child: bubble),
          ]),
          if (!mine) ...[const SizedBox(width: 6), time],
        ],
      ),
    );
  }
}

class Composer extends StatefulWidget {
  const Composer({super.key, required this.hint, required this.onSend, this.onPhoto});
  final String hint;
  final Future<void> Function(String text) onSend;
  final Future<void> Function()? onPhoto;

  @override
  State<Composer> createState() => _ComposerState();
}

class _ComposerState extends State<Composer> {
  final _c = TextEditingController();
  bool _busy = false;

  Future<void> _photo() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await widget.onPhoto?.call();
    } catch (e) {
      toast(e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _send() async {
    final t = _c.text.trim();
    if (t.isEmpty || _busy) return;
    setState(() => _busy = true);
    try {
      await widget.onSend(t);
      _c.clear();
    } catch (e) {
      toast(e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
          child: Row(children: [
            if (widget.onPhoto != null)
              IconButton(onPressed: _busy ? null : _photo, icon: const Icon(Icons.photo_outlined), tooltip: tr('写真を送る')),
            Expanded(
              child: TextField(
                controller: _c,
                maxLength: 500,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _send(),
                decoration: InputDecoration(
                  hintText: tr(widget.hint),
                  counterText: '',
                  contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(99), borderSide: BorderSide.none),
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(onPressed: _busy ? null : _send, icon: const Icon(Icons.send)),
          ]),
        ),
      );
}

class PhotoTile extends StatefulWidget {
  const PhotoTile(this.m, {super.key, required this.mine});
  final ChatMessage m;
  final bool mine;

  @override
  State<PhotoTile> createState() => _PhotoTileState();
}

class _PhotoTileState extends State<PhotoTile> {
  late bool _shown = widget.mine; // 届いた写真は、タップするまで表示しない

  void _open(File f) {
    showDialog<void>(
      context: context,
      builder: (ctx) => Dialog.fullscreen(
        backgroundColor: Colors.black,
        child: Stack(children: [
          Positioned.fill(child: InteractiveViewer(child: Image.file(f, fit: BoxFit.contain))),
          Positioned(
            top: 8,
            right: 8,
            child: IconButton(onPressed: () => Navigator.pop(ctx), icon: const Icon(Icons.close, color: Colors.white)),
          ),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final f = mesh.imgFile(widget.m);
    if (f == null || !f.existsSync()) {
      return Text('（写真を表示できません）', style: TextStyle(color: widget.mine ? Colors.white : null));
    }
    if (!_shown) {
      return InkWell(
        onTap: () => setState(() => _shown = true),
        child: Container(
          width: 190,
          height: 110,
          alignment: Alignment.center,
          color: const Color(0xFFF1E9E4),
          child: const Text('📷 写真が届きました\nタップで表示', textAlign: TextAlign.center),
        ),
      );
    }
    return GestureDetector(
      onTap: () => _open(f),
      child: ClipRRect(borderRadius: BorderRadius.circular(10), child: Image.file(f, width: 200, fit: BoxFit.cover, cacheWidth: 600)),
    );
  }
}

Future<void> pickAndSendPhoto(Profile p) async {
  final x = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 1024, maxHeight: 1024, imageQuality: 70);
  if (x == null) return;
  final bytes = await x.readAsBytes();
  final nav = navKey.currentContext;
  if (nav == null || !nav.mounted) return;
  final ok = await showDialog<bool>(
    context: nav,
    builder: (ctx) => AlertDialog(
      title: Text('${p.name} さんに写真を送る'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        ClipRRect(borderRadius: BorderRadius.circular(10), child: Image.memory(bytes, height: 220, fit: BoxFit.contain)),
        const SizedBox(height: 10),
        const Text('不適切な写真は禁止です。相手が通報すると、ブロックされます。', style: TextStyle(fontSize: 12)),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('キャンセル')),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('送る')),
      ],
    ),
  );
  if (ok != true) return;
  await mesh.sendImage(p.id, bytes);
}

// ======================= 1対1チャット =======================

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key, required this.peerId});
  final String peerId;

  static String? openWith;

  static void open(String id) {
    navKey.currentState?.push(MaterialPageRoute<void>(builder: (_) => ChatScreen(peerId: id))).then((_) => AdService.maybeShowInterstitial());
  }

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  @override
  void initState() {
    super.initState();
    ChatScreen.openWith = widget.peerId;
    WidgetsBinding.instance.addPostFrameCallback((_) => mesh.markRead(widget.peerId));
  }

  @override
  void dispose() {
    if (ChatScreen.openWith == widget.peerId) ChatScreen.openWith = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: mesh,
      builder: (context, _) {
        final p = mesh.profileOf(widget.peerId);
        if ((mesh.unread[widget.peerId] ?? 0) > 0) {
          WidgetsBinding.instance.addPostFrameCallback((_) => mesh.markRead(widget.peerId));
        }
        if (p == null || !mesh.isMatch(widget.peerId)) {
          return Scaffold(appBar: AppBar(), body: const EmptyState('🚫', 'この相手とは話せなくなりました'));
        }
        final online = mesh.isOnline(p.id);
        final msgs = (mesh.dms[p.id] ?? const <ChatMessage>[]).reversed.toList();
        return Scaffold(
          appBar: AppBar(
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            titleSpacing: 0,
            title: Row(children: [
              Avatar(p.emoji, online: online, size: 38),
              const SizedBox(width: 10),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(p.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                Text(online ? 'オンライン' : 'オフライン（同じWiFiに戻ると話せます）',
                    style: TextStyle(fontSize: 12, color: Theme.of(context).hintColor)),
              ]),
            ]),
            actions: [
              TextButton(
                onPressed: () async {
                  if (await reportUser(context, p) && context.mounted) Navigator.pop(context);
                },
                child: Text('通報', style: TextStyle(color: Theme.of(context).hintColor)),
              ),
              TextButton(
                onPressed: () async {
                  if (await confirmBlock(context, p) && context.mounted) Navigator.pop(context);
                },
                child: Text('ブロック', style: TextStyle(color: Theme.of(context).hintColor)),
              ),
            ],
          ),
          body: Column(children: [
            Expanded(
              child: msgs.isEmpty
                  ? EmptyState(p.emoji, '${p.name} さんとマッチしました。\n共通の話題からあいさつしてみよう。')
                  : ListView.builder(
                      reverse: true,
                      padding: const EdgeInsets.all(16),
                      itemCount: msgs.length,
                      itemBuilder: (_, i) => Bubble(msgs[i]),
                    ),
            ),
            const AdBanner(),
            Composer(
              hint: online ? 'メッセージ…' : '相手がオフラインです',
              onSend: (t) => mesh.sendDm(p.id, t),
              onPhoto: online ? () => pickAndSendPhoto(p) : null,
            ),
          ]),
        );
      },
    );
  }
}

// ======================= 広場 =======================

class PlazaTab extends StatelessWidget {
  const PlazaTab({super.key});

  @override
  Widget build(BuildContext context) {
    final msgs = mesh.plaza.reversed.toList();
    return Column(children: [
      Expanded(
        child: msgs.isEmpty
            ? ListView(padding: const EdgeInsets.all(16), children: const [
                _Header('広場', 'このWiFiにいる全員が見られるチャット'),
                EmptyState('👋', '最初のひとことを送ってみよう'),
              ])
            : ListView.builder(
                reverse: true,
                padding: const EdgeInsets.all(16),
                itemCount: msgs.length,
                itemBuilder: (_, i) => Bubble(msgs[i], showWho: true),
              ),
      ),
      Composer(
        hint: 'みんなに話しかける…',
        onSend: (t) async {
          final n = await mesh.sendPlaza(t);
          if (n == 0) toast('まだ近くに誰もいないので、自分だけに表示されています');
        },
      ),
    ]);
  }
}

// ======================= ふれあいレーダー =======================

/// 「みんな」タブの上に出す、新機能の宣伝カード（×で消せる。オンにすると出なくなる）
class PromoCard extends StatelessWidget {
  const PromoCard({super.key});

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: Listenable.merge([prox, Prefs.promoHidden]),
        builder: (context, _) {
          if (Prefs.promoHidden.value || prox.enabled) return const SizedBox.shrink();
          return Container(
            margin: const EdgeInsets.only(bottom: 14),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(gradient: _brandGradient, borderRadius: BorderRadius.circular(22)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                const Expanded(
                  child: Text('📡 新機能：ふれあいレーダー', style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w800)),
                ),
                IconButton(
                  onPressed: Prefs.hidePromo,
                  icon: const Icon(Icons.close, color: Colors.white),
                  visualDensity: VisualDensity.compact,
                ),
              ]),
              const Text('WiFiがなくても、Bluetoothで近くの人に気づける新機能。最初はオフです。', style: TextStyle(color: Colors.white)),
              const SizedBox(height: 10),
              FilledButton(
                onPressed: () => homeTab.value = 3,
                style: FilledButton.styleFrom(backgroundColor: Colors.white, foregroundColor: _coral),
                child: const Text('くわしく見る'),
              ),
            ]),
          );
        },
      );
}

Future<void> reportEncounter(Encounter e) async {
  final nav = navKey.currentContext;
  if (nav == null) return;
  final ok = await showDialog<bool>(
    context: nav,
    builder: (ctx) => AlertDialog(
      title: Text('${e.name} さんを通報'),
      content: const Text('この人を通報して、今後は表示しません。通報の内容がコピーされます。'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('キャンセル')),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('通報して非表示')),
      ],
    ),
  );
  if (ok != true) return;
  final at = DateTime.fromMillisecondsSinceEpoch(e.at).toIso8601String();
  await Clipboard.setData(ClipboardData(text: 'Meetory 通報(レーダー)\n相手: ${e.name}\n日時: $at'));
  await prox.blockEncounter(e);
  toast('通報して、非表示にしました');
}

/// 広がる電波の輪（オンの間は動く）
class RadarView extends StatefulWidget {
  const RadarView({super.key, required this.active, this.size = 120});
  final bool active;
  final double size;

  @override
  State<RadarView> createState() => _RadarViewState();
}

class _RadarViewState extends State<RadarView> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(seconds: 3))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SizedBox(
        width: widget.size,
        height: widget.size,
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, _) => CustomPaint(painter: _RadarPainter(_c.value, widget.active)),
        ),
      );
}

class _RadarPainter extends CustomPainter {
  _RadarPainter(this.t, this.active);
  final double t;
  final bool active;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final maxR = size.width / 2;
    for (var k = 0; k < 3; k++) {
      final p = active ? (t + k / 3) % 1.0 : 0.35 + k * 0.22;
      final a = active ? (1 - p) : 0.55 - k * 0.15;
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = Color.fromRGBO(255, 255, 255, (a * 0.9).clamp(0.0, 1.0));
      canvas.drawCircle(c, maxR * (0.25 + 0.75 * p), paint);
    }
    canvas.drawCircle(c, maxR * 0.16, Paint()..color = Colors.white);
    if (active) {
      final blip = (math.sin(t * 2 * math.pi) + 1) / 2;
      final fill = Paint()..color = Color.fromRGBO(255, 255, 255, 0.4 + 0.6 * blip);
      canvas.drawCircle(c + Offset(math.cos(0.8) * maxR * 0.62, math.sin(0.8) * maxR * 0.62), 5, fill);
      canvas.drawCircle(c + Offset(math.cos(3.9) * maxR * 0.5, math.sin(3.9) * maxR * 0.5), 4, fill);
    }
  }

  @override
  bool shouldRepaint(_RadarPainter old) => old.t != t || old.active != active;
}

/// 料金のカード。購入前は、特典・プラン（年額／月額）・購入ボタンを見せる
class PaywallCard extends StatelessWidget {
  const PaywallCard({super.key});

  Widget _benefit(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Icon(Icons.check_circle, color: Colors.white, size: 20),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 14.5, height: 1.3))),
        ]),
      );

  Widget _plan(String id, String title, ProductDetails? pd, String per, String? badge) {
    final sel = billing.effectiveSelected == id;
    final fg = sel ? _coral : Colors.white;
    return Expanded(
      child: GestureDetector(
        onTap: pd == null ? null : () => billing.select(id),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          padding: const EdgeInsets.fromLTRB(10, 12, 10, 14),
          decoration: BoxDecoration(
            color: sel ? Colors.white : const Color(0x33FFFFFF),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: sel ? Colors.white : const Color(0x66FFFFFF), width: 2),
          ),
          child: Column(children: [
            SizedBox(
              height: 24,
              child: badge == null
                  ? null
                  : Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(color: sel ? _coral : Colors.white, borderRadius: BorderRadius.circular(99)),
                      child: Text(badge, style: TextStyle(color: sel ? Colors.white : _coral, fontSize: 11.5, fontWeight: FontWeight.w800)),
                    ),
            ),
            const SizedBox(height: 4),
            Text(title, style: TextStyle(color: fg, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(pd?.price ?? '準備中', style: TextStyle(color: fg, fontSize: 22, fontWeight: FontWeight.w900)),
            const SizedBox(height: 2),
            Text(per, style: TextStyle(color: fg, fontSize: 12)),
          ]),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: billing,
        builder: (context, _) {
          if (billing.premium) {
            return Container(
              margin: const EdgeInsets.only(bottom: 14),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(gradient: _brandGradient, borderRadius: BorderRadius.circular(22)),
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
          final save = billing.yearlySavingPercent;
          return Container(
            margin: const EdgeInsets.only(bottom: 14),
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: _brandGradient,
              borderRadius: BorderRadius.circular(26),
              boxShadow: const [BoxShadow(color: Color(0x40FF4D6D), blurRadius: 24, offset: Offset(0, 10))],
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Row(children: [
                Icon(Icons.workspace_premium, color: Colors.white, size: 26),
                SizedBox(width: 8),
                Expanded(
                  child: Text('Meetory プレミアム', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
                ),
              ]),
              const SizedBox(height: 6),
              const Text('通りすがりの出会いを、見逃さない。',
                  style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900, height: 1.25)),
              if (kProximityFreeBeta)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(99)),
                    child: const Text('ベータ期間中は、無料で使えます', style: TextStyle(color: _coral, fontWeight: FontWeight.w800, fontSize: 13)),
                  ),
                ),
              const SizedBox(height: 14),
              _benefit('Bluetoothで、近くの人にすぐ気づく'),
              _benefit('WiFiがなくても、どこでも使える'),
              _benefit('近くにいた人を、一覧であとから見返せる'),
              _benefit('毎日変わる識別番号で、つきまといを防止'),
              _benefit('いつでも解約できる'),
              const SizedBox(height: 8),
              Row(children: [
                _plan(kProductYearly, '年額プラン', billing.yearly, '1年ごと', save != null ? '$save% おトク' : 'おすすめ'),
                _plan(kProductMonthly, '月額プラン', billing.monthly, '1か月ごと', null),
              ]),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: billing.selectedProduct == null || billing.busy ? null : billing.buy,
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: _coral,
                    disabledBackgroundColor: const Color(0x66FFFFFF),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: billing.busy
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('プレミアムを始める', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                ),
              ),
              Center(
                child: TextButton(onPressed: billing.restore, child: const Text('購入を復元', style: TextStyle(color: Colors.white))),
              ),
              const Text(
                'お支払いは Google Play のアカウントに請求されます。定期購入は、期間が終わる24時間前までに解約しない限り、自動で更新されます。解約は、Google Play の「定期購入」から、いつでもできます。',
                style: TextStyle(color: Color(0xCCFFFFFF), fontSize: 11, height: 1.4),
              ),
            ]),
          );
        },
      );
}

class ProximityTab extends StatelessWidget {
  const ProximityTab({super.key});

  bool get _allowed => billing.premium || kProximityFreeBeta;

  Future<void> _toggle(bool v) async {
    if (!v) {
      await prox.turnOff();
      toast('ふれあいレーダーをオフにしました');
      return;
    }
    final me = mesh.me;
    if (me == null) {
      toast('プロフィールを先に作ってください');
      return;
    }
    if (!_allowed) {
      toast('プレミアムが必要です（下の購入ボタンから）');
      return;
    }
    final r = await prox.turnOn(me, mesh.blocked);
    if (r == 'started') {
      toast('ふれあいレーダーをオンにしました');
    } else if (r == 'bt_off') {
      toast('Bluetoothをオンにしてください');
    } else if (r == 'unsupported') {
      toast('この端末は、Bluetooth LE に対応していません');
    } else {
      toast('Bluetoothの許可が必要です');
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([prox, billing, mesh]),
      builder: (context, _) {
        final shown = prox.encounters.where((e) => !prox.isBlocked(e)).toList();
        final hint = Theme.of(context).hintColor;
        return RefreshIndicator(
          onRefresh: prox.refresh,
          child: ListView(padding: const EdgeInsets.all(16), children: [
            const _Header('ふれあいレーダー', 'Bluetoothで、WiFiがなくても、近くの人に気づける'),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 4),
              child: RadarScope(
                active: prox.enabled,
                me: mesh.me?.emoji ?? 'あなた',
                others: [for (final e in shown.take(5)) (seed: e.emoji, label: hhmm(e.at))],
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.circle, size: 10, color: prox.enabled ? const Color(0xFF1FB57A) : Colors.grey),
                const SizedBox(width: 8),
                Text(prox.enabled ? '探索中 ・ 近くに${shown.length}人' : 'オフ ・ 探していません', style: const TextStyle(fontWeight: FontWeight.w800)),
              ]),
            ),
            const SizedBox(height: 14),

            if (!prox.supported) const _Notice('この端末は、Bluetooth LE に対応していません'),
            Card(
              child: SwitchListTile(
                value: prox.enabled,
                onChanged: prox.supported ? _toggle : null,
                contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
                title: const Text('ふれあいレーダー', style: TextStyle(fontWeight: FontWeight.w800)),
                subtitle: const Text('オンにすると、アプリを閉じていても、近くの人を探します（電池を使います）'),
              ),
            ),
            const PremiumPromoCard(),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('📡 ふれあいレーダー', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 8),
                  const Text('・近くにいた人を、通知と一覧でお知らせ'),
                  const Text('・WiFiがなくても動きます（Bluetooth）'),
                  const Text('・オフで始まり、いつでも切れます'),
                  const Text('・ブロックした人には、表示されません'),
                ]),
              ),
            ),
            Text(
              'あなたのニックネームとアイコンが、Bluetoothで近くの端末に発信されます。発信する識別番号は毎日変わります。つきまといを防ぐため、初期設定はオフです。',
              style: TextStyle(fontSize: 12.5, color: hint),
            ),
            const SizedBox(height: 16),
            const Text('ふれあった人', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            if (shown.isEmpty) const EmptyState('📡', 'まだ誰とも、ふれあっていません。\nオンにして、外に出かけてみよう。'),
            for (final e in shown)
              Card(
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  leading: Avatar(e.emoji, online: false, size: 48),
                  title: Text(e.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text('${hhmm(e.at)} に近くにいました'),
                  trailing: TextButton(
                    onPressed: () => reportEncounter(e),
                    child: Text('通報', style: TextStyle(color: hint)),
                  ),
                ),
              ),
          ]),
        );
      },
    );
  }
}

// ======================= 自分 =======================

class MeTab extends StatelessWidget {
  const MeTab({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(padding: const EdgeInsets.all(16), children: [
      const PremiumPromoCard(),
      const _Header('プロフィール', '保存すると数秒で近くの人の画面に反映されます'),
      Card(
        color: Theme.of(context).colorScheme.surface,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: ProfileForm(key: ValueKey(mesh.me?.id), initial: mesh.me, submitLabel: '保存する'),
        ),
      ),
      ValueListenableBuilder<bool>(
        valueListenable: Notifier.on,
        builder: (context, v, child) => SwitchListTile(
          value: v,
          onChanged: Notifier.setEnabled,
          contentPadding: EdgeInsets.zero,
          title: const Text('メッセージの通知'),
          subtitle: const Text('アプリを閉じている間に、メッセージやマッチをお知らせします'),
        ),
      ),
      const SizedBox(height: 8),
      OutlinedButton(
        onPressed: () async {
          final ok = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('データをすべて削除'),
              content: const Text('プロフィール・マッチ・メッセージがこの端末から削除されます。'),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('キャンセル')),
                FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('削除する')),
              ],
            ),
          );
          if (ok == true) await mesh.resetAll();
        },
        style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
        child: const Text('退出してデータを削除'),
      ),
      const SizedBox(height: 16),
      Text(
        'プロフィールやメッセージは、この端末の中だけに保存されます。やり取りは同じWiFi内の端末同士で直接行われ、運営のサーバーには送られません。'
        '広告の表示のため、広告サービス（Google AdMob）が端末の情報を利用することがあります。',
        style: TextStyle(fontSize: 12.5, color: Theme.of(context).hintColor),
      ),
      const SizedBox(height: 10),
      Text(
        '【ご利用ルール】18歳以上の方のみご利用いただけます。わいせつな内容、嫌がらせ、勧誘や詐欺、金銭の要求、18歳未満の方への接触は禁止です。不快な相手は「通報」「ブロック」ができます（広場では相手のメッセージを長押し）。',
        style: TextStyle(fontSize: 12.5, color: Theme.of(context).hintColor),
      ),
      const SizedBox(height: 8),
      Align(
        alignment: Alignment.centerLeft,
        child: FilledButton.tonalIcon(
          onPressed: () => openContact(context),
          icon: const Icon(Icons.mail_outline),
          label: const Text('お問い合わせ'),
        ),
      ),
      const SizedBox(height: 8),
      SelectableText(
        'プライバシーポリシー: $kPrivacyUrl\nお問い合わせ: $kContactUrl',
        style: TextStyle(fontSize: 12, color: Theme.of(context).hintColor),
      ),
      FutureBuilder<PrivacyOptionsRequirementStatus>(
        future: ConsentInformation.instance.getPrivacyOptionsRequirementStatus(),
        builder: (context, snap) => snap.data == PrivacyOptionsRequirementStatus.required
            ? Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: () => ConsentForm.showPrivacyOptionsForm((FormError? error) {}),
                  child: const Text('広告とプライバシーの設定'),
                ),
              )
            : const SizedBox.shrink(),
      ),
      if (mesh.localIps.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text('この端末のIP: ${mesh.localIps.join(', ')}', style: TextStyle(fontSize: 12, color: Theme.of(context).hintColor)),
        ),
    ]);
  }
}
