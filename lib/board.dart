import 'package:flutter/material.dart';

import 'art.dart';
import 'billing.dart';
import 'main.dart' show billing, mesh, toast;
import 'paywall.dart';

/// 全国掲示板。見るのは無料。投稿と連絡は、プレミアム（ベータ期間中は、無料）。
/// いまは「見た目の確認用」で、サンプルの投稿を表示します。サーバーにつなぐのはこの後です。
const _coral = Color(0xFFFF4D6D);
const _orange = Color(0xFFFF8A4C);

const List<String> _areas = ['全国', '北海道・東北', '関東', '中部', '近畿', '中国・四国', '九州・沖縄'];
const List<String> _cats = ['テーマパーク', 'ライブ・フェス', '旅行', 'グルメ', 'スポーツ', '趣味・その他'];

class _Post {
  _Post({
    required this.event,
    required this.cat,
    required this.title,
    required this.area,
    required this.when,
    required this.body,
    required this.nick,
    this.month = '',
    this.people = 0,
    this.want = 0,
  });
  final bool event;
  final String cat;
  final String title;
  final String area;
  final String when;
  final String body;
  final String nick;
  final String month;
  final int people;
  int want;
  bool wanted = false;
}

List<_Post> _sample() => [
      _Post(event: false, cat: 'テーマパーク', title: 'ディズニーに一緒に行ける人！', area: '関東', when: '来月の平日', body: '1人だと乗り物が寂しいので、一緒に回れる人を探しています。のんびり派です。', nick: 'ゆうき', people: 2),
      _Post(event: false, cat: 'ライブ・フェス', title: '夏フェス、現地で合流したい', area: '全国', when: '8月の週末', body: '一人参戦です。ご飯だけ一緒でも大歓迎。', nick: 'はる', people: 3),
      _Post(event: false, cat: 'グルメ', title: '大阪でたこ焼き巡りしませんか', area: '近畿', when: '今度の土曜', body: '有名店を3軒くらい食べ歩きしたいです。', nick: 'みお', people: 3),
      _Post(event: false, cat: '旅行', title: '北海道の旅、道中だけ一緒に', area: '北海道・東北', when: '9月ごろ', body: 'レンタカーで回る予定です。景色が好きな人どうぞ。', nick: 'そら', people: 2),
      _Post(event: false, cat: 'スポーツ', title: 'フットサル、人数が足りません', area: '中部', when: '毎週日曜 朝', body: '初心者OK。楽しくやりたい人だけ。', nick: 'かいと', people: 5),
      _Post(event: true, cat: 'ライブ・フェス', title: '夏の音楽フェス(サンプル)', area: '関東', when: '8月第1週末', month: '8', body: '野外の大型フェスの一例です。一緒に行く人を募集できます。', nick: 'Meetory編集部', want: 24),
      _Post(event: true, cat: 'テーマパーク', title: 'ハロウィンイベント(サンプル)', area: '関東', when: '10月中', month: '10', body: 'テーマパークの季節イベントの例です。', nick: 'Meetory編集部', want: 31),
      _Post(event: true, cat: '旅行', title: '紅葉ライトアップ(サンプル)', area: '近畿', when: '11月中旬', month: '11', body: '夜の紅葉を見に行く仲間を探せます。', nick: 'Meetory編集部', want: 9),
      _Post(event: true, cat: 'グルメ', title: '全国ご当地グルメ祭り(サンプル)', area: '全国', when: '各地で開催', month: '全国', body: '各地のご当地グルメが集まるイベントの例です。', nick: 'Meetory編集部', want: 12),
      _Post(event: true, cat: 'スポーツ', title: '市民マラソン大会(サンプル)', area: '中部', when: '11月下旬', month: '11', body: '一緒に走る仲間や、応援に行く仲間を探せます。', nick: 'Meetory編集部', want: 15),
      _Post(event: true, cat: '旅行', title: '冬のイルミネーション(サンプル)', area: '九州・沖縄', when: '12月', month: '12', body: '夜景を見に行く仲間を探せます。', nick: 'Meetory編集部', want: 18),
      _Post(event: true, cat: '旅行', title: '雪と氷の祭典(サンプル)', area: '北海道・東北', when: '2月', month: '2', body: '冬の北国を楽しむ仲間を探せます。', nick: 'Meetory編集部', want: 27),
    ];

class BoardTab extends StatefulWidget {
  const BoardTab({super.key});

  @override
  State<BoardTab> createState() => _BoardTabState();
}

class _BoardTabState extends State<BoardTab> {
  static final List<_Post> _posts = _sample();
  bool _event = false;
  String _area = '全国';
  String _cat = 'すべて';

  bool get _canPost => billing.premium || kProximityFreeBeta;

  Future<void> _compose() async {
    if (!_canPost) {
      openPaywall('掲示板に投稿するには、プレミアムが必要です');
      return;
    }
    final p = await showModalBottomSheet<_Post>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => _ComposeSheet(event: _event),
    );
    if (p != null) {
      setState(() => _posts.insert(0, p));
      toast('投稿しました(いまはサンプル表示です)');
    }
  }

  void _talk() {
    if (!_canPost) {
      openPaywall('掲示板の人に連絡するには、プレミアムが必要です');
      return;
    }
    toast('ここから話しかけられるようになります(接続前のサンプル)');
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final list = _posts
        .where((p) => p.event == _event && (_area == '全国' || p.area == '全国' || p.area == _area) && (_cat == 'すべて' || p.cat == _cat))
        .toList();
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _compose,
        backgroundColor: _coral,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.edit),
        label: Text(_event ? 'イベントを載せる' : '仲間を募集する'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [_coral, _orange], begin: Alignment.topLeft, end: Alignment.bottomRight),
              borderRadius: BorderRadius.circular(22),
            ),
            child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('全国掲示板', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900)),
              SizedBox(height: 4),
              Text('WiFiが同じじゃなくても、全国の人と。「一緒に行きたい人！」を見つけよう。', style: TextStyle(color: Colors.white, height: 1.35)),
              SizedBox(height: 8),
              Text('見るのは無料 / 投稿・連絡はプレミアム', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12.5)),
            ]),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(color: const Color(0xFFFFF1C9), borderRadius: BorderRadius.circular(12)),
            child: const Text('いまは見た目の確認用です。表示は、すべてサンプルです。', style: TextStyle(fontSize: 12.5, color: Color(0xFF2B2430))),
          ),
          const SizedBox(height: 12),
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(value: false, label: Text('仲間募集'), icon: Icon(Icons.groups)),
              ButtonSegment(value: true, label: Text('イベント一覧'), icon: Icon(Icons.event)),
            ],
            selected: {_event},
            onSelectionChanged: (s) => setState(() => _event = s.first),
          ),
          if (_event)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text('全国のイベントの日付と場所を、公式の公開情報から毎日自動で集めて載せる予定です(いまはサンプル)。',
                  style: TextStyle(fontSize: 12.5, color: cs.onSurface.withValues(alpha: 0.65))),
            ),
          const SizedBox(height: 8),
          Row(children: [
            const Icon(Icons.place, size: 18, color: _coral),
            const SizedBox(width: 6),
            DropdownButton<String>(
              value: _area,
              underline: const SizedBox.shrink(),
              items: [for (final a in _areas) DropdownMenuItem(value: a, child: Text(a))],
              onChanged: (v) => setState(() => _area = v ?? '全国'),
            ),
          ]),
          SizedBox(
            height: 44,
            child: ListView(scrollDirection: Axis.horizontal, children: [
              for (final c in ['すべて', ..._cats])
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(label: Text(c), selected: _cat == c, onSelected: (_) => setState(() => _cat = c)),
                ),
            ]),
          ),
          const SizedBox(height: 8),
          if (list.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Center(child: Text('この条件の投稿はまだありません。\n最初の1件を載せてみよう！', textAlign: TextAlign.center)),
            ),
          for (final p in list) _PostCard(p, onTalk: _talk, onChanged: () => setState(() {})),
        ],
      ),
    );
  }
}

class _PostCard extends StatelessWidget {
  const _PostCard(this.p, {required this.onTalk, required this.onChanged});
  final _Post p;
  final VoidCallback onTalk;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final sub = cs.onSurface.withValues(alpha: 0.62);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [BoxShadow(color: Color(0x14000000), blurRadius: 12, offset: Offset(0, 4))],
      ),
      child: p.event ? _event(context, sub) : _recruit(context, sub),
    );
  }

  Widget _chip(BuildContext context, String t) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(99)),
        child: Text(t, style: const TextStyle(fontSize: 12)),
      );

  Widget _recruit(BuildContext context, Color sub) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
        FaceAvatar(p.nick, size: 52),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(p.title, style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800)),
            Text(p.nick, style: TextStyle(fontSize: 12, color: sub)),
          ]),
        ),
        CategoryIcon(p.cat),
      ]),
      const SizedBox(height: 8),
      Wrap(spacing: 6, runSpacing: 6, children: [
        _chip(context, p.cat),
        _chip(context, p.area),
        _chip(context, p.when),
        _chip(context, '${p.people}人まで'),
      ]),
      const SizedBox(height: 8),
      Text(p.body, style: const TextStyle(height: 1.4)),
      const SizedBox(height: 10),
      Align(alignment: Alignment.centerRight, child: FilledButton(onPressed: onTalk, child: const Text('話してみる'))),
    ]);
  }

  Widget _event(BuildContext context, Color sub) {
    final numeric = int.tryParse(p.month) != null;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 58,
          padding: const EdgeInsets.fromLTRB(4, 8, 4, 7),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [_coral, _orange], begin: Alignment.topLeft, end: Alignment.bottomRight),
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [BoxShadow(color: Color(0x4DFF4D6D), blurRadius: 10, offset: Offset(0, 4))],
          ),
          child: Column(children: [
            Text(p.month, style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: numeric ? 26 : 16, height: 1.1)),
            Text(numeric ? '月' : ' ', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
          ]),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(p.title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            const SizedBox(height: 3),
            Row(children: [
              Icon(Icons.place_outlined, size: 15, color: sub),
              const SizedBox(width: 3),
              Flexible(child: Text('${p.area}・${p.when}', style: TextStyle(fontSize: 13, color: sub))),
            ]),
            const SizedBox(height: 6),
            Row(children: [CategoryIcon(p.cat, size: 26), const SizedBox(width: 6), _chip(context, p.cat)]),
          ]),
        ),
      ]),
      const SizedBox(height: 10),
      Text(p.body, style: TextStyle(color: sub, fontSize: 13)),
      const SizedBox(height: 8),
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text('出どころ: 公式の公開情報', style: TextStyle(fontSize: 12, color: sub)),
        OutlinedButton.icon(
          onPressed: () {
            p.wanted = !p.wanted;
            p.want += p.wanted ? 1 : -1;
            onChanged();
          },
          icon: Icon(p.wanted ? Icons.favorite : Icons.favorite_border, size: 18),
          label: Text('行きたい ${p.want}'),
        ),
      ]),
    ]);
  }
}

class _ComposeSheet extends StatefulWidget {
  const _ComposeSheet({required this.event});
  final bool event;

  @override
  State<_ComposeSheet> createState() => _ComposeSheetState();
}

class _ComposeSheetState extends State<_ComposeSheet> {
  final _title = TextEditingController();
  final _when = TextEditingController();
  final _body = TextEditingController();
  String _area = '関東';
  String _cat = 'テーマパーク';
  int _people = 2;

  @override
  void dispose() {
    _title.dispose();
    _when.dispose();
    _body.dispose();
    super.dispose();
  }

  void _submit() {
    if (_title.text.trim().isEmpty) {
      toast('タイトルを入れてください');
      return;
    }
    Navigator.pop(
      context,
      _Post(
        event: widget.event,
        cat: _cat,
        title: _title.text.trim(),
        area: _area,
        when: _when.text.trim().isEmpty ? 'いつでも' : _when.text.trim(),
        body: _body.text.trim(),
        nick: mesh.me?.name ?? '自分',
        month: '',
        people: _people,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, MediaQuery.of(context).viewInsets.bottom + 16),
      child: SingleChildScrollView(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Text(widget.event ? 'イベントを載せる' : '仲間を募集する', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
          const SizedBox(height: 12),
          TextField(controller: _title, maxLength: 40, decoration: const InputDecoration(labelText: 'タイトル(例: ディズニーに行きたい)', border: OutlineInputBorder())),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(
              child: DropdownButton<String>(
                isExpanded: true,
                value: _area,
                items: [for (final a in _areas.skip(1)) DropdownMenuItem(value: a, child: Text(a))],
                onChanged: (v) => setState(() => _area = v ?? _area),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: DropdownButton<String>(
                isExpanded: true,
                value: _cat,
                items: [for (final c in _cats) DropdownMenuItem(value: c, child: Text(c))],
                onChanged: (v) => setState(() => _cat = v ?? _cat),
              ),
            ),
          ]),
          const SizedBox(height: 8),
          TextField(controller: _when, decoration: const InputDecoration(labelText: 'いつ(例: 来月の週末)', border: OutlineInputBorder())),
          if (!widget.event) ...[
            const SizedBox(height: 8),
            Row(children: [
              const Text('何人まで: '),
              DropdownButton<int>(
                value: _people,
                items: [for (var n = 1; n <= 10; n++) DropdownMenuItem(value: n, child: Text('$n人'))],
                onChanged: (v) => setState(() => _people = v ?? _people),
              ),
            ]),
          ],
          const SizedBox(height: 8),
          TextField(controller: _body, maxLines: 3, maxLength: 200, decoration: const InputDecoration(labelText: 'ひとこと', border: OutlineInputBorder())),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: const Color(0xFFFFF1C9), borderRadius: BorderRadius.circular(12)),
            child: const Text('電話番号・LINE・住所などは書かないでください。会うときは、昼間の人が多い場所で。18歳以上の方のみ。',
                style: TextStyle(fontSize: 12.5, height: 1.4, color: Color(0xFF2B2430))),
          ),
          const SizedBox(height: 12),
          SizedBox(width: double.infinity, child: FilledButton(onPressed: _submit, child: const Text('投稿する'))),
        ]),
      ),
    );
  }
}
