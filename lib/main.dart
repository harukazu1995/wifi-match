import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'mesh.dart';

final mesh = MeshService();
final navKey = GlobalKey<NavigatorState>();
final messengerKey = GlobalKey<ScaffoldMessengerState>();

const _coral = Color(0xFFFF4D6D);
const _orange = Color(0xFFFF8A4C);
const _ink = Color(0xFF2B2430);
const _bg = Color(0xFFFFF8F3);
const _sharedColor = Color(0xFFFFE9A8);
const _brandGradient = LinearGradient(colors: [_coral, _orange], begin: Alignment.topLeft, end: Alignment.bottomRight);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await mesh.load();
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
      title: 'WiFi Match',
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

/// WiFiの電波と、ハートを組み合わせたロゴ。progress(0〜1)で描かれていく。
class WifiLogo extends StatelessWidget {
  const WifiLogo({super.key, this.progress = 1, this.size = 120});
  final double progress;
  final double size;

  @override
  Widget build(BuildContext context) {
    final heart = Curves.elasticOut.transform((progress / 0.45).clamp(0.0, 1.0));
    return SizedBox(
      width: size,
      height: size,
      child: Stack(alignment: Alignment.center, children: [
        CustomPaint(size: Size.square(size), painter: _ArcsPainter(progress)),
        Align(
          alignment: const Alignment(0, 0.44),
          child: Transform.scale(
            scale: heart,
            child: ShaderMask(
              shaderCallback: (r) => _brandGradient.createShader(r),
              child: Icon(Icons.favorite, size: size * 0.3, color: Colors.white),
            ),
          ),
        ),
      ]),
    );
  }
}

class _ArcsPainter extends CustomPainter {
  _ArcsPainter(this.progress);
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final center = Offset(w / 2, size.height * 0.72);
    for (var i = 0; i < 3; i++) {
      // 内側から順に、ふわっと現れる
      final a = ((progress - 0.3 - i * 0.14) / 0.22).clamp(0.0, 1.0);
      if (a <= 0) continue;
      final r = w * (0.2 + 0.17 * i);
      final rect = Rect.fromCircle(center: center, radius: r);
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = w * 0.07
        ..shader = LinearGradient(
          colors: [_coral.withValues(alpha: a), _orange.withValues(alpha: a)],
        ).createShader(Rect.fromLTWH(0, 0, w, size.height));
      canvas.drawArc(rect, -math.pi * 3 / 4, math.pi / 2, false, paint);
    }
  }

  @override
  bool shouldRepaint(_ArcsPainter old) => old.progress != progress;
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
                      TextSpan(text: 'WiFi', style: TextStyle(color: _ink)),
                      TextSpan(text: 'Match', style: TextStyle(color: _coral)),
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

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 450),
      child: _done
          ? ListenableBuilder(
              key: const ValueKey('app'),
              listenable: mesh,
              builder: (context, _) => mesh.me == null ? const OnboardingScreen() : const HomeScreen(),
            )
          : SplashScreen(key: const ValueKey('splash'), onDone: () => setState(() => _done = true)),
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
          decoration: BoxDecoration(color: cs.surfaceContainerHighest, shape: BoxShape.circle),
          child: Text(emoji, style: TextStyle(fontSize: size * 0.52)),
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
          TextSpan(text: t, style: const TextStyle(fontWeight: FontWeight.w700)),
          if (hint != null) TextSpan(text: '  $hint', style: TextStyle(fontSize: 12, color: Theme.of(context).hintColor)),
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
                child: Text(e, style: const TextStyle(fontSize: 22)),
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
        decoration: const InputDecoration(hintText: '例：窓際の席で作業してます。コーヒー好きな人と話したい', counterText: ''),
      ),
      _label('趣味・興味', 'スペース区切りで最大8個'),
      TextField(
        controller: _tags,
        onChanged: (_) => setState(() {}),
        decoration: const InputDecoration(hintText: 'カフェ 映画 ゲーム'),
      ),
      const SizedBox(height: 8),
      Wrap(spacing: 6, runSpacing: 6, children: [
        for (final s in _suggest)
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
  StreamSubscription<MeshEvent>? _sub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _sub = mesh.events.listen(_onEvent);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _sub?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (mesh.running) {
        mesh.announce();
      } else {
        mesh.start();
      }
    }
  }

  void _onEvent(MeshEvent e) {
    switch (e.type) {
      case MeshEventType.match:
        if (e.who != null) _showMatch(e.who!);
      case MeshEventType.liked:
        toast('💌 誰かがあなたにいいねしました');
      case MeshEventType.dm:
        if (ChatScreen.openWith != e.who?.id) toast('💬 ${e.who?.name ?? '誰か'} さんからメッセージ');
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
                TextSpan(text: 'WiFi', style: TextStyle(fontWeight: FontWeight.w900, color: _ink)),
                TextSpan(text: 'Match', style: TextStyle(fontWeight: FontWeight.w900, color: _coral)),
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
          body: IndexedStack(index: _tab, children: [PeopleTab(), MatchesTab(), PlazaTab(), MeTab()]),
          bottomNavigationBar: NavigationBar(
            selectedIndex: _tab,
            onDestinationSelected: (i) {
              setState(() => _tab = i);
              if (i == 2) mesh.markPlazaRead();
            },
            destinations: [
              const NavigationDestination(icon: Icon(Icons.people_outline), selectedIcon: Icon(Icons.people), label: 'みんな'),
              NavigationDestination(
                icon: Badge(isLabelVisible: mesh.unreadTotal > 0, label: Text('${mesh.unreadTotal}'), child: const Icon(Icons.favorite_border)),
                selectedIcon: const Icon(Icons.favorite),
                label: 'マッチ',
              ),
              NavigationDestination(
                icon: Badge(
                  isLabelVisible: mesh.unreadPlaza > 0 && _tab != 2,
                  label: Text('${mesh.unreadPlaza}'),
                  child: const Icon(Icons.forum_outlined),
                ),
                selectedIcon: const Icon(Icons.forum),
                label: '広場',
              ),
              const NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: '自分'),
            ],
          ),
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
      child: Text(m.text, style: TextStyle(color: mine ? Colors.white : null)),
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
            bubble,
          ]),
          if (!mine) ...[const SizedBox(width: 6), time],
        ],
      ),
    );
  }
}

class Composer extends StatefulWidget {
  const Composer({super.key, required this.hint, required this.onSend});
  final String hint;
  final Future<void> Function(String text) onSend;

  @override
  State<Composer> createState() => _ComposerState();
}

class _ComposerState extends State<Composer> {
  final _c = TextEditingController();
  bool _busy = false;

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
            Expanded(
              child: TextField(
                controller: _c,
                maxLength: 500,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _send(),
                decoration: InputDecoration(
                  hintText: widget.hint,
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

// ======================= 1対1チャット =======================

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key, required this.peerId});
  final String peerId;

  static String? openWith;

  static void open(String id) {
    navKey.currentState?.push(MaterialPageRoute<void>(builder: (_) => ChatScreen(peerId: id)));
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
            Composer(hint: online ? 'メッセージ…' : '相手がオフラインです', onSend: (t) => mesh.sendDm(p.id, t)),
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

// ======================= 自分 =======================

class MeTab extends StatelessWidget {
  const MeTab({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(padding: const EdgeInsets.all(16), children: [
      const _Header('プロフィール', '保存すると数秒で近くの人の画面に反映されます'),
      Card(
        color: Theme.of(context).colorScheme.surface,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: ProfileForm(key: ValueKey(mesh.me?.id), initial: mesh.me, submitLabel: '保存する'),
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
        'データはこの端末の中だけに保存されます。通信は同じWiFi内の端末同士で直接行われ、外部のサーバーには送られません。',
        style: TextStyle(fontSize: 12.5, color: Theme.of(context).hintColor),
      ),
      if (mesh.localIps.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text('この端末のIP: ${mesh.localIps.join(', ')}', style: TextStyle(fontSize: 12, color: Theme.of(context).hintColor)),
        ),
    ]);
  }
}
