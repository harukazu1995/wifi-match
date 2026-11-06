// 同じWiFi内のスマホ同士が直接つながる P2P 通信の中核。
//
// しくみ:
//  1. 発見   … 各端末が3秒ごとに UDP ブロードキャスト（ポート47801）で
//               「自分のプロフィール＋自分のHTTPポート」を流す
//  2. 直接通信 … 各端末が小さなHTTPサーバーを持ち、いいね・DM・広場の投稿は
//               相手の端末へ直接 POST する（中央サーバーなし）
//  3. なりすまし対策 … 届いたリクエストの送信元IPが、その人のビーコンのIPと
//               一致しないものは拒否する
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

const int kDiscoveryPort = 47801;
const String kAppTag = 'wifimatch';
const int kProtocol = 1;
const Duration kBeaconEvery = Duration(seconds: 3);
const Duration kOfflineAfter = Duration(seconds: 12);

const List<String> kEmojis = [
  '🙂', '😎', '🐱', '🐶', '🦊', '🐼', '🐸', '🐧', '🌸', '🌙',
  '⭐', '🔥', '🍀', '🎧', '📚', '☕', '🎮', '⚽', '🎨', '🍜',
];

String clip(String s, int max) {
  final r = s.replaceAll(RegExp(r'[\x00-\x1f\x7f]'), ' ').trim();
  final runes = r.runes.toList();
  return runes.length <= max ? r : String.fromCharCodes(runes.take(max));
}

List<String> parseTags(String s) => s
    .split(RegExp(r'[\s,、，#＃]+'))
    .map((t) => clip(t, 16))
    .where((t) => t.isNotEmpty)
    .toSet()
    .take(8)
    .toList();

String _randomId() {
  final r = Random.secure();
  return List.generate(12, (_) => r.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
}

class Profile {
  Profile({required this.id, required this.name, required this.emoji, this.bio = '', List<String>? tags})
      : tags = tags ?? <String>[];

  final String id;
  final String name;
  final String emoji;
  final String bio;
  final List<String> tags;

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'emoji': emoji, 'bio': bio, 'tags': tags};

  static Profile? tryParse(Object? j) {
    if (j is! Map) return null;
    final id = j['id'];
    final name = j['name'];
    if (id is! String || id.isEmpty || id.length > 64) return null;
    if (name is! String || clip(name, 20).isEmpty) return null;
    final emoji = j['emoji'];
    final bio = j['bio'];
    final tags = j['tags'];
    return Profile(
      id: id,
      name: clip(name, 20),
      emoji: emoji is String && emoji.isNotEmpty ? clip(emoji, 4) : '🙂',
      bio: bio is String ? clip(bio, 160) : '',
      tags: tags is List
          ? tags.whereType<String>().map((t) => clip(t, 16)).where((t) => t.isNotEmpty).take(8).toList()
          : <String>[],
    );
  }
}

class Peer {
  Peer(this.profile, this.address, this.port, this.lastSeen);
  Profile profile;
  InternetAddress address;
  int port;
  DateTime lastSeen;
  bool get online => DateTime.now().difference(lastSeen) < kOfflineAfter;
}

class ChatMessage {
  ChatMessage({required this.id, required this.from, required this.text, required this.at, this.name = '', this.emoji = ''});
  final String id;
  final String from;
  final String text;
  final int at;
  final String name;
  final String emoji;

  Map<String, dynamic> toJson() => {'id': id, 'from': from, 'text': text, 'at': at, 'name': name, 'emoji': emoji};

  static ChatMessage? tryParse(Object? j) {
    if (j is! Map) return null;
    final id = j['id'], from = j['from'], text = j['text'], at = j['at'];
    if (id is! String || from is! String || text is! String || at is! int) return null;
    final t = clip(text, 500);
    if (t.isEmpty || id.length > 64) return null;
    return ChatMessage(
      id: id,
      from: from,
      text: t,
      at: at,
      name: j['name'] is String ? clip(j['name'] as String, 20) : '',
      emoji: j['emoji'] is String ? clip(j['emoji'] as String, 4) : '',
    );
  }
}

enum MeshEventType { match, liked, dm, plaza }

class MeshEvent {
  MeshEvent(this.type, {this.who, this.text});
  final MeshEventType type;
  final Profile? who;
  final String? text;
}

class MeshException implements Exception {
  MeshException(this.message);
  final String message;
  @override
  String toString() => message;
}

class MeshService extends ChangeNotifier {
  Profile? me;
  final Map<String, Peer> peers = {};
  final Map<String, Profile> known = {}; // いいね・マッチした相手のプロフィール（オフラインでも表示するため保存）
  final Set<String> likesOut = {};
  final Set<String> likesIn = {};
  final Set<String> blocked = {};
  final Map<String, List<ChatMessage>> dms = {};
  final List<ChatMessage> plaza = [];
  final Map<String, int> unread = {};
  int unreadPlaza = 0;
  List<String> localIps = [];
  bool running = false;
  String? startError;

  final _events = StreamController<MeshEvent>.broadcast();
  Stream<MeshEvent> get events => _events.stream;

  RawDatagramSocket? _udp;
  HttpServer? _http;
  Timer? _beaconTimer;
  Timer? _pruneTimer;
  final Set<String> _seenPlaza = {};
  Set<String> _lastOnline = {};
  final HttpClient _client = HttpClient()..connectionTimeout = const Duration(seconds: 4);
  SharedPreferences? _prefs;

  // ---------------- 状態 ----------------
  bool isMatch(String id) => likesOut.contains(id) && likesIn.contains(id) && !blocked.contains(id);

  bool isOnline(String id) => peers[id]?.online ?? false;

  Profile? profileOf(String id) => peers[id]?.profile ?? known[id];

  List<String> sharedTags(Profile p) => me == null ? [] : p.tags.where(me!.tags.contains).toList();

  List<Peer> get onlinePeers {
    final list = peers.values.where((p) => p.online && !blocked.contains(p.profile.id)).toList();
    list.sort((a, b) {
      final s = sharedTags(b.profile).length.compareTo(sharedTags(a.profile).length);
      return s != 0 ? s : a.profile.name.compareTo(b.profile.name);
    });
    return list;
  }

  List<Profile> get matches {
    final ids = likesOut.where(isMatch).toList();
    final list = ids.map(profileOf).whereType<Profile>().toList();
    list.sort((a, b) {
      final o = (isOnline(b.id) ? 1 : 0).compareTo(isOnline(a.id) ? 1 : 0);
      return o != 0 ? o : _lastAt(b.id).compareTo(_lastAt(a.id));
    });
    return list;
  }

  int _lastAt(String id) => dms[id]?.isNotEmpty == true ? dms[id]!.last.at : 0;

  int get likedMeCount => likesIn.where((id) => !likesOut.contains(id) && !blocked.contains(id)).length;

  int get unreadTotal => unread.values.fold(0, (a, b) => a + b);

  // ---------------- 保存 ----------------
  Future<void> load() async {
    _prefs = await SharedPreferences.getInstance();
    final raw = _prefs!.getString('wm_state');
    if (raw == null) return;
    try {
      final j = jsonDecode(raw) as Map<String, dynamic>;
      me = Profile.tryParse(j['me']);
      for (final p in (j['known'] as List? ?? const [])) {
        final pr = Profile.tryParse(p);
        if (pr != null) known[pr.id] = pr;
      }
      likesOut.addAll((j['likesOut'] as List? ?? const []).whereType<String>());
      likesIn.addAll((j['likesIn'] as List? ?? const []).whereType<String>());
      blocked.addAll((j['blocked'] as List? ?? const []).whereType<String>());
      final d = j['dms'];
      if (d is Map) {
        d.forEach((k, v) {
          if (k is String && v is List) dms[k] = v.map(ChatMessage.tryParse).whereType<ChatMessage>().toList();
        });
      }
    } catch (_) {
      // 壊れたデータは無視して新規扱い
    }
  }

  Future<void> _save() async {
    final prefs = _prefs ??= await SharedPreferences.getInstance();
    await prefs.setString(
      'wm_state',
      jsonEncode({
        'me': me?.toJson(),
        'known': known.values.map((p) => p.toJson()).toList(),
        'likesOut': likesOut.toList(),
        'likesIn': likesIn.toList(),
        'blocked': blocked.toList(),
        'dms': dms.map((k, v) => MapEntry(k, v.skip(max(0, v.length - 300)).map((m) => m.toJson()).toList())),
      }),
    );
  }

  Future<void> setProfile({required String name, required String emoji, required String bio, required List<String> tags}) async {
    final n = clip(name, 20);
    if (n.isEmpty) throw MeshException('ニックネームを入力してください');
    me = Profile(
      id: me?.id ?? _randomId(),
      name: n,
      emoji: kEmojis.contains(emoji) ? emoji : kEmojis.first,
      bio: clip(bio, 160),
      tags: tags.take(8).toList(),
    );
    await _save();
    notifyListeners();
    if (!running) {
      await start();
    } else {
      unawaited(_sendBeacon());
    }
  }

  Future<void> resetAll() async {
    for (final p in peers.values.where((p) => p.online)) {
      unawaited(_post(p, '/block', {'from': me?.id}).catchError((_) => <String, dynamic>{}));
    }
    await stop();
    me = null;
    peers.clear();
    known.clear();
    likesOut.clear();
    likesIn.clear();
    blocked.clear();
    dms.clear();
    plaza.clear();
    unread.clear();
    unreadPlaza = 0;
    await (_prefs ??= await SharedPreferences.getInstance()).remove('wm_state');
    notifyListeners();
  }

  // ---------------- 起動・停止 ----------------
  Future<void> start() async {
    if (running || me == null) return;
    startError = null;
    try {
      // Android: WiFiのブロードキャスト受信を有効にする（MainActivity.kt 側で実装）
      try {
        await const MethodChannel('wifimatch/net').invokeMethod('acquireMulticast');
      } catch (_) {}

      _http = await HttpServer.bind(InternetAddress.anyIPv4, 0);
      _http!.listen(_handle, onError: (_) {});

      _udp = await RawDatagramSocket.bind(InternetAddress.anyIPv4, kDiscoveryPort, reuseAddress: true);
      _udp!.broadcastEnabled = true;
      _udp!.listen((ev) {
        if (ev != RawSocketEvent.read) return;
        while (true) {
          final d = _udp?.receive();
          if (d == null) break;
          _onDatagram(d);
        }
      }, onError: (_) {});

      running = true;
      _beaconTimer = Timer.periodic(kBeaconEvery, (_) => _sendBeacon());
      _pruneTimer = Timer.periodic(const Duration(seconds: 4), (_) => _checkOnline());
      await _sendBeacon();
    } catch (e) {
      startError = '通信を開始できませんでした: $e';
      await stop();
    }
    notifyListeners();
  }

  Future<void> stop() async {
    _beaconTimer?.cancel();
    _pruneTimer?.cancel();
    _udp?.close();
    await _http?.close(force: true);
    _udp = null;
    _http = null;
    running = false;
  }

  /// アプリが前面に戻ったときなど、すぐに存在を知らせる
  void announce() => unawaited(_sendBeacon());

  // ---------------- 発見（UDPビーコン） ----------------
  Future<void> _sendBeacon() async {
    final p = me, udp = _udp, http = _http;
    if (p == null || udp == null || http == null) return;
    final data = utf8.encode(jsonEncode({'app': kAppTag, 'v': kProtocol, 'port': http.port, 'p': p.toJson()}));
    for (final target in await _broadcastTargets()) {
      try {
        udp.send(data, target, kDiscoveryPort);
      } catch (_) {}
    }
    // 自動テスト用: 決まった宛先（IP → ポート）にも直接送る
    debugTargets.forEach((host, port) {
      try {
        udp.send(data, InternetAddress(host), port);
      } catch (_) {}
    });
  }

  /// 自動テスト用の追加の送り先。通常のアプリでは空のまま。
  static final Map<String, int> debugTargets = {};

  Future<List<InternetAddress>> _broadcastTargets() async {
    final targets = <String>{'255.255.255.255'};
    final ips = <String>[];
    try {
      final ifaces = await NetworkInterface.list(type: InternetAddressType.IPv4);
      for (final ni in ifaces) {
        for (final a in ni.addresses) {
          if (a.isLoopback) continue;
          ips.add(a.address);
          final parts = a.address.split('.');
          if (parts.length == 4) targets.add('${parts[0]}.${parts[1]}.${parts[2]}.255');
        }
      }
    } catch (_) {}
    if (!listEquals(ips, localIps)) {
      localIps = ips;
      notifyListeners();
    }
    return targets.map((t) => InternetAddress(t)).toList();
  }

  void _onDatagram(Datagram d) {
    if (d.data.length > 4096) return;
    Object? j;
    try {
      j = jsonDecode(utf8.decode(d.data));
    } catch (_) {
      return;
    }
    if (j is! Map || j['app'] != kAppTag || j['v'] != kProtocol) return;
    final p = Profile.tryParse(j['p']);
    final port = j['port'];
    if (p == null || port is! int || port <= 0 || port > 65535) return;
    if (p.id == me?.id || blocked.contains(p.id)) return;

    final old = peers[p.id];
    final changed = old == null ||
        !old.online ||
        old.address.address != d.address.address ||
        old.port != port ||
        jsonEncode(old.profile.toJson()) != jsonEncode(p.toJson());
    peers[p.id] = Peer(p, d.address, port, DateTime.now());
    if (known.containsKey(p.id)) known[p.id] = p;
    if (changed) {
      _lastOnline = onlinePeers.map((x) => x.profile.id).toSet();
      notifyListeners();
    }
  }

  void _checkOnline() {
    final now = onlinePeers.map((x) => x.profile.id).toSet();
    if (!setEquals(now, _lastOnline)) {
      _lastOnline = now;
      notifyListeners();
    }
  }

  // ---------------- 受信（自分のHTTPサーバー） ----------------
  Future<void> _handle(HttpRequest req) async {
    final res = req.response;
    var status = 200;
    Map<String, dynamic> out = {'ok': true};
    try {
      if (req.method != 'POST') throw _Http(404, 'not found');
      final bytes = <int>[];
      await for (final chunk in req.timeout(const Duration(seconds: 5))) {
        bytes.addAll(chunk);
        if (bytes.length > 16384) throw _Http(413, 'too large');
      }
      final body = jsonDecode(utf8.decode(bytes));
      if (body is! Map) throw _Http(400, 'bad body');
      final ip = req.connectionInfo?.remoteAddress.address;

      // 送信者の確認: ビーコンで見えている端末のIPからのリクエストだけ受け付ける
      String verify(Object? id) {
        if (id is! String) throw _Http(400, 'no sender');
        final peer = peers[id];
        if (peer == null || peer.address.address != ip) throw _Http(409, 'unknown sender');
        if (blocked.contains(id)) throw _Http(403, 'blocked');
        return id;
      }

      switch (req.uri.path) {
        case '/like': {
          final p = Profile.tryParse(body['from']);
          if (p == null) throw _Http(400, 'bad profile');
          final id = verify(p.id);
          final wasMatch = isMatch(id);
          likesIn.add(id);
          known[id] = p;
          if (isMatch(id) && !wasMatch) {
            _events.add(MeshEvent(MeshEventType.match, who: p));
          } else if (!likesOut.contains(id)) {
            _events.add(MeshEvent(MeshEventType.liked));
          }
          out = {'likedYou': likesOut.contains(id)};
        }
        case '/unlike': {
          likesIn.remove(verify(body['from']));
        }
        case '/block': {
          final id = verify(body['from']);
          blocked.add(id);
          likesOut.remove(id);
          likesIn.remove(id);
          peers.remove(id);
        }
        case '/dm': {
          final id = verify(body['from']);
          if (!isMatch(id)) throw _Http(403, 'not matched');
          final m = ChatMessage.tryParse({...body, 'from': id});
          if (m == null) throw _Http(400, 'bad message');
          final list = dms.putIfAbsent(id, () => []);
          if (!list.any((x) => x.id == m.id)) {
            list.add(m);
            unread[id] = (unread[id] ?? 0) + 1;
            _events.add(MeshEvent(MeshEventType.dm, who: profileOf(id), text: m.text));
          }
        }
        case '/plaza': {
          final id = verify(body['from']);
          final p = peers[id]!.profile;
          final m = ChatMessage.tryParse({...body, 'from': id, 'name': p.name, 'emoji': p.emoji});
          if (m == null) throw _Http(400, 'bad message');
          if (_seenPlaza.add(m.id)) {
            _addPlaza(m);
            unreadPlaza++;
            _events.add(MeshEvent(MeshEventType.plaza, who: p, text: m.text));
          }
        }
        default: {
          throw _Http(404, 'not found');
        }
      }
      unawaited(_save());
      notifyListeners();
    } on _Http catch (e) {
      status = e.status;
      out = {'error': e.message};
    } catch (_) {
      status = 400;
      out = {'error': 'bad request'};
    }
    try {
      res.statusCode = status;
      res.headers.contentType = ContentType.json;
      res.write(jsonEncode(out));
      await res.close();
    } catch (_) {}
  }

  void _addPlaza(ChatMessage m) {
    plaza.add(m);
    plaza.sort((a, b) => a.at.compareTo(b.at));
    if (plaza.length > 200) plaza.removeAt(0);
  }

  // ---------------- 送信 ----------------
  Future<Map<String, dynamic>> _post(Peer peer, String path, Map<String, dynamic> body) async {
    final req = await _client.post(peer.address.address, peer.port, path).timeout(const Duration(seconds: 5));
    req.headers.contentType = ContentType.json;
    req.write(jsonEncode(body));
    final resp = await req.close().timeout(const Duration(seconds: 5));
    final text = await utf8.decodeStream(resp).timeout(const Duration(seconds: 5));
    if (resp.statusCode == 409) throw MeshException('相手の端末がまだあなたを見つけていません。数秒後にもう一度試してください');
    if (resp.statusCode == 403) throw MeshException('この相手には送れません');
    if (resp.statusCode != 200) throw MeshException('相手の端末に届きませんでした（${resp.statusCode}）');
    final j = jsonDecode(text);
    return j is Map<String, dynamic> ? j : <String, dynamic>{};
  }

  Peer _onlinePeer(String id) {
    final p = peers[id];
    if (p == null || !p.online) throw MeshException('相手がオフラインです');
    return p;
  }

  Future<bool> like(String id) async {
    final peer = _onlinePeer(id);
    final wasMatch = isMatch(id);
    likesOut.add(id);
    known[id] = peer.profile;
    notifyListeners();
    try {
      final r = await _post(peer, '/like', {'from': me!.toJson()});
      if (r['likedYou'] == true) likesIn.add(id);
    } catch (e) {
      likesOut.remove(id);
      notifyListeners();
      throw e is MeshException ? e : MeshException('相手の端末に届きませんでした');
    }
    final nowMatch = isMatch(id);
    if (nowMatch && !wasMatch) _events.add(MeshEvent(MeshEventType.match, who: peer.profile));
    await _save();
    notifyListeners();
    return nowMatch;
  }

  Future<void> unlike(String id) async {
    likesOut.remove(id);
    await _save();
    notifyListeners();
    final p = peers[id];
    if (p != null && p.online) unawaited(_post(p, '/unlike', {'from': me!.id}).catchError((_) => <String, dynamic>{}));
  }

  Future<void> block(String id) async {
    final p = peers[id];
    if (p != null && p.online) {
      try {
        await _post(p, '/block', {'from': me!.id});
      } catch (_) {}
    }
    blocked.add(id);
    likesOut.remove(id);
    likesIn.remove(id);
    peers.remove(id);
    await _save();
    notifyListeners();
  }

  Future<void> sendDm(String id, String text) async {
    final t = clip(text, 500);
    if (t.isEmpty) return;
    if (!isMatch(id)) throw MeshException('マッチした相手とだけ話せます');
    final peer = _onlinePeer(id);
    final m = ChatMessage(id: _randomId(), from: me!.id, text: t, at: DateTime.now().millisecondsSinceEpoch);
    await _post(peer, '/dm', {'from': me!.id, 'id': m.id, 'text': m.text, 'at': m.at});
    dms.putIfAbsent(id, () => []).add(m);
    await _save();
    notifyListeners();
  }

  Future<int> sendPlaza(String text) async {
    final t = clip(text, 500);
    if (t.isEmpty) return 0;
    final m = ChatMessage(id: _randomId(), from: me!.id, text: t, at: DateTime.now().millisecondsSinceEpoch, name: me!.name, emoji: me!.emoji);
    _seenPlaza.add(m.id);
    _addPlaza(m);
    notifyListeners();
    final results = await Future.wait(onlinePeers.map((p) => _post(p, '/plaza', {'from': me!.id, 'id': m.id, 'text': m.text, 'at': m.at})
        .then((_) => true)
        .catchError((_) => false)));
    return results.where((ok) => ok).length;
  }

  void markRead(String id) {
    if ((unread[id] ?? 0) == 0) return;
    unread[id] = 0;
    notifyListeners();
  }

  void markPlazaRead() {
    if (unreadPlaza == 0) return;
    unreadPlaza = 0;
    notifyListeners();
  }
}

class _Http implements Exception {
  _Http(this.status, this.message);
  final int status;
  final String message;
}
