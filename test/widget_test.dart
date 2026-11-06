import 'package:flutter_test/flutter_test.dart';
import 'package:wifi_match/mesh.dart';

void main() {
  test('プロフィールの検証と切り詰め', () {
    final p = Profile.tryParse({
      'id': 'abc',
      'name': '  とても長い名前とても長い名前とても長い名前  ',
      'emoji': '🐱',
      'bio': 'hi',
      'tags': ['映画', '', 1, 'カフェ'],
    })!;
    expect(p.name.runes.length, 20);
    expect(p.tags, ['映画', 'カフェ']);
    expect(Profile.tryParse({'id': '', 'name': 'x'}), isNull);
    expect(Profile.tryParse('not a map'), isNull);
  });

  test('趣味タグの分割', () {
    expect(parseTags('カフェ 映画、#ゲーム,カフェ'), ['カフェ', '映画', 'ゲーム']);
  });

  test('マッチ判定', () {
    final m = MeshService();
    m.likesOut.add('b');
    expect(m.isMatch('b'), isFalse);
    m.likesIn.add('b');
    expect(m.isMatch('b'), isTrue);
    m.blocked.add('b');
    expect(m.isMatch('b'), isFalse);
  });
}
