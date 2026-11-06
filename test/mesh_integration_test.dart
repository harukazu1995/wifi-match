// アプリ本体の通信コード（mesh.dart）を、テスト相手プログラム（tool/test_buddy.py）と
// 実際にネットワーク越しに通信させて、一連の流れが動くことを確かめる。
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wifi_match/mesh.dart';

Future<void> waitFor(bool Function() cond, String what, StringBuffer log, {int seconds = 25}) async {
  final end = DateTime.now().add(Duration(seconds: seconds));
  while (!cond()) {
    if (DateTime.now().isAfter(end)) fail('時間切れ: $what\n--- テスト相手のログ ---\n$log');
    await Future<void>.delayed(const Duration(milliseconds: 200));
  }
}

void main() {
  test('テスト相手と 発見→いいね→マッチ→DM→広場→ブロック', () async {
    HttpOverrides.global = null;
    SharedPreferences.setMockInitialValues({});

    final log = StringBuffer();
    final bot = await Process.start('python3', [
      'tool/test_buddy.py',
      '--listen-port', '47802',
      '--send-port', '47801',
      '--target', '127.0.0.1',
      '--no-broadcast',
      '--fast',
    ]);
    bot.stdout.transform(utf8.decoder).listen(log.write);
    bot.stderr.transform(utf8.decoder).listen(log.write);
    addTearDown(bot.kill);

    MeshService.debugTargets['127.0.0.1'] = 47802;
    final m = MeshService();
    final events = <MeshEventType>[];
    final sub = m.events.listen((e) => events.add(e.type));
    addTearDown(sub.cancel);

    await m.setProfile(name: 'テスター', emoji: '🐱', bio: 'CI', tags: ['映画', '読書']);
    expect(m.running, isTrue, reason: m.startError);

    // 1. 発見
    await waitFor(() => m.onlinePeers.isNotEmpty, 'テスト相手の発見', log);
    final buddy = m.onlinePeers.first.profile;
    expect(buddy.name, 'テスト相手');
    expect(m.sharedTags(buddy), ['映画']);

    // 2. 相手からのいいね（こちらはまだいいねしていない）
    await waitFor(() => m.likesIn.contains(buddy.id), 'テスト相手からのいいね', log);
    expect(m.likedMeCount, 1);
    expect(events, contains(MeshEventType.liked));
    expect(m.isMatch(buddy.id), isFalse);

    // 3. いいねを返してマッチ
    final matched = await m.like(buddy.id);
    expect(matched, isTrue);
    expect(events, contains(MeshEventType.match));
    expect(m.matches.map((p) => p.id), [buddy.id]);

    // 4. DM の送信と返信の受信
    await m.sendDm(buddy.id, 'こんにちは');
    await waitFor(() => (m.dms[buddy.id]?.length ?? 0) >= 2, 'DMの返信', log);
    expect(m.dms[buddy.id]!.last.from, buddy.id);
    expect(m.unread[buddy.id], 1);

    // 5. 広場
    final delivered = await m.sendPlaza('広場テスト');
    expect(delivered, 1);
    await waitFor(() => m.plaza.length >= 2, '広場の返事', log);
    expect(m.plaza.last.name, 'テスト相手');

    // 6. なりすまし: 見つけていない送信元からのいいねは拒否される
    final client = HttpClient();
    final req = await client.post('127.0.0.1', await _myHttpPort(m), '/like');
    req.headers.contentType = ContentType.json;
    req.write(jsonEncode({'from': {'id': 'fake-user', 'name': 'なりすまし', 'emoji': '😈', 'bio': '', 'tags': []}}));
    final res = await req.close();
    await res.drain<void>();
    expect(res.statusCode, 409);
    client.close(force: true);

    // 7. ブロック
    await m.block(buddy.id);
    expect(m.onlinePeers, isEmpty);
    expect(m.isMatch(buddy.id), isFalse);
    await waitFor(() => log.toString().contains('ブロックされました'), '相手側にブロックが届く', log);

    await m.stop();
  }, timeout: const Timeout(Duration(seconds: 120)));
}

/// テスト相手のログから、アプリ側のHTTPポートを探す代わりに、
/// アプリが送ったビーコンを受けて確かめる。
Future<int> _myHttpPort(MeshService m) async {
  final sock = await RawDatagramSocket.bind(InternetAddress.loopbackIPv4, 47803);
  MeshService.debugTargets['127.0.0.1'] = 47803;
  final completer = Completer<int>();
  sock.listen((ev) {
    final d = sock.receive();
    if (d == null || completer.isCompleted) return;
    final j = jsonDecode(utf8.decode(d.data));
    if (j is Map && j['port'] is int) completer.complete(j['port'] as int);
  });
  m.announce();
  final port = await completer.future.timeout(const Duration(seconds: 10));
  sock.close();
  MeshService.debugTargets['127.0.0.1'] = 47802;
  return port;
}
