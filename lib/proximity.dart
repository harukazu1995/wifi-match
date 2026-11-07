// ふれあいレーダー（Bluetooth）。実際の発信と探索は Android 側（ProximityService.kt）が行い、
// ここでは、オン・オフの操作と、すれ違った人の一覧の読み込みをする。
import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'i18n.dart' show tr;
import 'mesh.dart';

class Encounter {
  Encounter({required this.token, required this.name, required this.emojiIdx, required this.at});
  final int token;
  final String name;
  final int emojiIdx;
  final int at;

  String get emoji => kEmojis[emojiIdx.clamp(0, kEmojis.length - 1)];
  String get signature => '$name|$emojiIdx';
}

class ProximityService extends ChangeNotifier {
  static const _ch = MethodChannel('wifimatch/ble');

  bool enabled = false; // 初期設定は、オフ
  bool supported = false;
  List<Encounter> encounters = [];
  List<String> blockedSigs = [];
  Timer? _poll;
  String? _lastRaw;
  Profile? _me;
  Iterable<String> _blockedIds = const [];

  bool isBlocked(Encounter e) => blockedSigs.contains(e.signature);

  Future<void> load() async {
    try {
      final p = await SharedPreferences.getInstance();
      enabled = p.getBool('wm_ble_on') ?? false;
      blockedSigs = p.getStringList('wm_ble_block') ?? [];
    } catch (_) {}
    try {
      supported = await _ch.invokeMethod<bool>('bleSupported') ?? false;
    } catch (_) {
      supported = false;
    }
    await refresh();
    _poll = Timer.periodic(const Duration(seconds: 10), (_) => refresh());
  }

  Future<void> _saveOn(bool v) async {
    try {
      await (await SharedPreferences.getInstance()).setBool('wm_ble_on', v);
    } catch (_) {}
  }

  Future<void> _config() async {
    final me = _me;
    if (me == null) return;
    final idx = kEmojis.indexOf(me.emoji);
    await _ch.invokeMethod<void>('bleConfig', {
      'profileId': me.id,
      'name': me.name,
      'emojiIdx': idx < 0 ? 0 : idx,
      'notifTitle': tr('📡 ふれあいレーダー'),
      'notifBody': tr('{name} さんが近くにいます'),
      'ongoing': tr('ふれあいレーダーがオンです'),
      'blockedIds': _blockedIds.toList(),
      'blockedSigs': blockedSigs,
    });
  }

  /// オンにする。結果は 'started' / 'denied' / 'bt_off' / 'unsupported'
  Future<String> turnOn(Profile me, Iterable<String> blockedIds) async {
    if (!supported) return 'unsupported';
    _me = me;
    _blockedIds = blockedIds;
    try {
      await _config();
      final r = await _ch.invokeMethod<String>('bleStart') ?? 'denied';
      if (r == 'started') {
        enabled = true;
        await _saveOn(true);
      }
      notifyListeners();
      return r;
    } catch (_) {
      return 'denied';
    }
  }

  Future<void> turnOff() async {
    try {
      await _ch.invokeMethod<void>('bleStop');
    } catch (_) {}
    enabled = false;
    await _saveOn(false);
    notifyListeners();
  }

  /// アプリを開いたときに、オンのままなら再開する（権限が外れていたら、オフに戻す）
  Future<void> resumeIfNeeded({required Profile? me, required Iterable<String> blockedIds, required bool allowed}) async {
    if (!enabled || me == null) return;
    if (!allowed) {
      await turnOff();
      return;
    }
    final r = await turnOn(me, blockedIds);
    if (r != 'started') {
      enabled = false;
      await _saveOn(false);
      notifyListeners();
    }
  }

  Future<void> refresh() async {
    try {
      final raw = await _ch.invokeMethod<String>('bleEncounters') ?? '[]';
      if (raw == _lastRaw) return;
      _lastRaw = raw;
      final list = <Encounter>[];
      final j = jsonDecode(raw);
      if (j is List) {
        for (final o in j) {
          if (o is! Map) continue;
          final token = o['token'], name = o['name'], idx = o['emojiIdx'], at = o['at'];
          if (token is! int || name is! String || idx is! int || at is! int) continue;
          final n = clip(name, 20);
          if (n.isEmpty) continue;
          list.add(Encounter(token: token, name: n, emojiIdx: idx, at: at));
        }
      }
      encounters = list.reversed.toList();
      notifyListeners();
    } catch (_) {}
  }

  /// この人を今後表示しない（名前とアイコンの組み合わせで覚える）
  Future<void> blockEncounter(Encounter e) async {
    if (!blockedSigs.contains(e.signature)) blockedSigs = [...blockedSigs, e.signature];
    try {
      await (await SharedPreferences.getInstance()).setStringList('wm_ble_block', blockedSigs);
    } catch (_) {}
    try {
      await _config();
    } catch (_) {}
    notifyListeners();
  }
}
