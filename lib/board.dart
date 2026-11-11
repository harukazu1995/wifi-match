import 'package:flutter/material.dart';

import 'main.dart' show billing, homeTab, toast;

/// 全国掲示板（有料会員が投稿、見るのは全員）。
/// いまは「見た目の確認用」で、サンプルの投稿を表示します。サーバーにつなぐのはこの後です。
/// true の間は、無料でも投稿画面を試せます。課金を有効にするときに false にします。
const bool kBoardFreeBeta = true;

const _coral = Color(0xFFFF4D6D);
const _orange = Color(0xFFFF8A4C);
const _ink = Color(0xFF2B2430);

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
    required this.emoji,
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
  final String emoji;
  final int people;
  int want;
  bool wanted = false;
}

List<_Post> _sample() => [
      _Post(event: false, cat: 'テーマパーク', title: 'ディズニーに一緒に行ける人！', area: '関東', when: '来月の平日', body: '1人だと乗り物が寂しいので、一緒に回れる人を探しています。のんびり派です。', nick: 'ゆうき', emoji: '🐻', people: 2),
      _Post(event: false, cat: 'ライブ・フェス', title: '夏フェス、現地で合流したい', area: '全国', when: '8月の週末', body: '一人参戦です。ご飯だけ一緒でも大歓迎。', nick: 'はる', emoji: '🎧', people: 3),
      _Post(event: false, cat: 'グルメ', title: '大阪でたこ焼き巡りしませんか', area: '近畿', when: '今度の土曜', body: '有名店を3軒くらい食べ歩きしたいです。', nick: 'みお', emoji: '🐙', people: 3),
      _Post(event: false, cat: '旅行', title: '北海道の旅、道中だけ一緒に', area: '北海道・東北', when: '9月ごろ', body: 'レンタカーで回る予定です。景色が好きな人どうぞ。', nick: 'そら', emoji: '🚗', people: 2),
      _Post(event: false, cat: 'スポーツ', title: 'フットサル、人数が足りません', area: '中部', when: '毎週日曜 朝', body: '初心者OK。楽しくやりたい人だけ。', nick: 'かいと', emoji: '⚽', people: 5),
      _Post(event: true, cat: 'ライブ・フェス', title: '夏の音楽フェス(サンプル)', area: '関東', when: '8月第1週末', body: '野外の大型フェスの一例です。一緒に行く人を募集できます。', nick: 'Nearly編集部', emoji: '🎪', want: 24),
      _Post(event: true, cat: 'グルメ', title: '全国ご当地グルメ祭り(サンプル)', area: '全国', when: '各地で開催', body: '各地のご当地グルメが集まるイベントの例です。', nick: 'Nearly編集部', emoji: '🍜', want: 12),
      _Post(event: true, cat: 'テーマパーク', title: 'ハロウィンイベント(サンプル)', area: '関東', when: '10月中', body: 'テーマパークの季節イベントの例です。', nick: 'Nearly編集部', emoji: '🎃', want: 31),
      _Post(event: true, cat: '旅行', title: '紅葉ライトアップ(サンプル)', area: '近畿', when: '11月中旬', body: '夜の紅葉を見に行く仲間を探せます。', nick: 'Nearly編集部', emoji: '🍁', want: 9),
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

  bool get _canPost => billing.premium || kBoardFreeBeta;

  Future<void> _compose() async {
    if (!_canPost) {
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('投稿はプレミアム会員だけ'),
          content: const Text('見るのは無料です。「一緒に行きたい人」を募集するには、プレミアムが必要です。'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('あとで')),
            FilledButton(
              onPressed: () {
                Navigator.pop(ctx);
                homeTab.value = 4;
              },
              child: const Text('プレミアムを見る'),
            ),
          ],
        ),
      );
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

  @override
  Widget build(BuildContext context) {
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
              Text('🌏 全国掲示板', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900)),
              SizedBox(height: 4),
              Text('WiFiが同じじゃなくても、全国の人と。「一緒に行きたい人！」を見つけよう。', style: TextStyle(color: Colors.white, height: 1.35)),
              SizedBox(height: 8),
              Text('見るのは無料 / 投稿はプレミアム', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12.5)),
            ]),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(color: const Color(0xFFFFF1C9), borderRadius: BorderRadius.circular(12)),
            child: const Text('いまは見た目の確認用です。表示は、すべてサンプルです。', style: TextStyle(fontSize: 12.5)),
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
          for (final p in list) _PostCard(p, onChanged: () => setState(() {})),
        ],
      ),
    );
  }
}

class _PostCard extends StatelessWidget {
  const _PostCard(this.p, {required this.onChanged});
  final _Post p;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [BoxShadow(color: Color(0x14000000), blurRadius: 12, offset: Offset(0, 4))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          CircleAvatar(radius: 20, backgroundColor: const Color(0xFFFFE9EE), child: Text(p.emoji, style: const TextStyle(fontSize: 20))),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(p.title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: _ink)),
              const SizedBox(height: 2),
              Text(p.nick, style: const TextStyle(fontSize: 12, color: Colors.black54)),
            ]),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, size: 20),
            onSelected: (_) => toast('通報を受け付けました(サンプル)'),
            itemBuilder: (_) => const [PopupMenuItem(value: 'r', child: Text('通報する'))],
          ),
        ]),
        const SizedBox(height: 8),
        Wrap(spacing: 6, runSpacing: 6, children: [
          _chip(Icons.sell, p.cat),
          _chip(Icons.place, p.area),
          _chip(Icons.schedule, p.when),
          if (!p.event) _chip(Icons.group, '${p.people}人まで'),
        ]),
        const SizedBox(height: 8),
        Text(p.body, style: const TextStyle(height: 1.4)),
        const SizedBox(height: 10),
        Align(
          alignment: Alignment.centerRight,
          child: p.event
              ? OutlinedButton.icon(
                  onPressed: () {
                    p.wanted = !p.wanted;
                    p.want += p.wanted ? 1 : -1;
                    onChanged();
                  },
                  icon: Icon(p.wanted ? Icons.favorite : Icons.favorite_border, size: 18),
                  label: Text('行きたい ${p.want}'),
                )
              : FilledButton(
                  onPressed: () => toast('ここから話しかけられるようになります(接続前のサンプル)'),
                  child: const Text('話してみる'),
                ),
        ),
      ]),
    );
  }

  Widget _chip(IconData i, String t) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(color: const Color(0xFFF6F0F2), borderRadius: BorderRadius.circular(99)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(i, size: 13, color: Colors.black54),
          const SizedBox(width: 4),
          Text(t, style: const TextStyle(fontSize: 12)),
        ]),
      );
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
        nick: '自分',
        emoji: '🙂',
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
            child: const Text('電話番号・LINE・住所などは書かないでください。会うときは、昼間の人が多い場所で。18歳以上の方のみ。', style: TextStyle(fontSize: 12.5, height: 1.4)),
          ),
          const SizedBox(height: 12),
          SizedBox(width: double.infinity, child: FilledButton(onPressed: _submit, child: const Text('投稿する'))),
        ]),
      ),
    );
  }
}
