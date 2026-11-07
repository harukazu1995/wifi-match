// 表示する言語の切り替え。端末の言語が日本語なら日本語のまま、それ以外は英語で表示する。
//
// ソースコードの日本語の文字列は、そのまま「日本語の原文」として残してあり、
// 英語で表示するときだけ、下の対応表（_en）と、数字や名前が入る文の規則（_patterns）で置きかえる。
// 新しい言語を足すときは、この対応表と同じものを増やす。
import 'package:flutter/material.dart' as m;
import 'package:flutter/widgets.dart';

bool get isJapanese => WidgetsBinding.instance.platformDispatcher.locale.languageCode == 'ja';

/// 日本語の原文を、端末の言語に合わせた文字列にする。対応がないものは、そのまま返す。
String tr(String s) {
  if (isJapanese) return s;
  final direct = _en[s];
  if (direct != null) return direct;
  for (final (re, f) in _patterns) {
    final match = re.firstMatch(s);
    if (match != null) return f(match);
  }
  return s;
}

String _n(String s) => s == '誰か' ? 'Someone' : s;

final List<(RegExp, String Function(RegExpMatch))> _patterns = [
  (RegExp(r'^(.+) さんとお互いにいいねしました$'), (x) => '${_n(x[1]!)} and you liked each other'),
  (RegExp(r'^(💬 )?(.+) さんからメッセージ$'), (x) => '${x[1] ?? ''}New message from ${_n(x[2]!)}'),
  (RegExp(r'^近くに (\d+)人$'), (x) => '${x[1]} nearby'),
  (RegExp(r'^💌 (\d+)人があなたにいいねしています。気になる人にいいねを返すとマッチします。$'), (x) => '💌 ${x[1]} people liked you. Like someone back to match.'),
  (RegExp(r'^(.+) さんにいいねしました$'), (x) => 'You liked ${_n(x[1]!)}'),
  (RegExp(r'^共通 (\d+)$'), (x) => 'Shared ${x[1]}'),
  (RegExp(r'^(.+) さんをブロック$'), (x) => 'Block ${_n(x[1]!)}'),
  (RegExp(r'^(.+) さんを通報$'), (x) => 'Report ${_n(x[1]!)}'),
  (RegExp(r'^(.+) さんに写真を送る$'), (x) => 'Send a photo to ${_n(x[1]!)}'),
  (RegExp(r'^(.+) さんとマッチしました。\n共通の話題からあいさつしてみよう。$'), (x) => 'You matched with ${_n(x[1]!)}.\nSay hello about something you share.'),
  (
    RegExp(r'^この人は表示されなくなりました。\n運営にも知らせる場合は、コピーされた通報の内容を、次のページに貼り付けてください。\n([\s\S]*)$'),
    (x) => 'This person is now hidden.\nTo let us know too, paste the copied report on this page:\n${x[1]}',
  ),
  (RegExp(r'^プライバシーポリシー: (.*)\nお問い合わせ: (.*)$'), (x) => 'Privacy policy: ${x[1]}\nContact: ${x[2]}'),
  (RegExp(r'^この端末のIP: (.*)$'), (x) => 'This device IP: ${x[1]}'),
  (RegExp(r'^⚠️ 通信を開始できませんでした: (.*)$'), (x) => '⚠️ Could not start networking: ${x[1]}'),
  (RegExp(r'^通信を開始できませんでした: (.*)$'), (x) => 'Could not start networking: ${x[1]}'),
  (RegExp(r'^相手の端末に届きませんでした（(\d+)）$'), (x) => 'The message did not reach the other device (${x[1]})'),
];

/// Text と同じ使い方で、表示する文字を端末の言語に合わせる（main.dart は Material の Text のかわりにこれを使う）
class Text extends StatelessWidget {
  const Text(this.data, {super.key, this.style, this.textAlign, this.maxLines, this.overflow, this.softWrap}) : span = null;
  const Text.rich(this.span, {super.key, this.style, this.textAlign, this.maxLines, this.overflow, this.softWrap}) : data = null;

  final String? data;
  final InlineSpan? span;
  final TextStyle? style;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;
  final bool? softWrap;

  @override
  Widget build(BuildContext context) {
    final s = span;
    if (s != null) {
      return m.Text.rich(s, style: style, textAlign: textAlign, maxLines: maxLines, overflow: overflow, softWrap: softWrap);
    }
    return m.Text(tr(data!), style: style, textAlign: textAlign, maxLines: maxLines, overflow: overflow, softWrap: softWrap);
  }
}

class SelectableText extends StatelessWidget {
  const SelectableText(this.data, {super.key, this.style, this.textAlign, this.maxLines});

  final String data;
  final TextStyle? style;
  final TextAlign? textAlign;
  final int? maxLines;

  @override
  Widget build(BuildContext context) => m.SelectableText(tr(data), style: style, textAlign: textAlign, maxLines: maxLines);
}

const Map<String, String> _en = {
  '同じWiFiの人と、つながろう。': 'Connect with people on the same WiFi.',
  '同じWiFiの人が見つかる': 'Find people on the same WiFi',
  'アプリを入れた人どうしが、同じWiFiにいるときだけ、お互いを見つけられます。共通の趣味が多い人から順に表示されます。': 'People with the app can see each other only while on the same WiFi. Those with more interests in common come first.',
  'いいねして、マッチ': 'Like, then match',
  'お互いにいいねすると「マッチ」。マッチした人とだけ、1対1でチャットや写真を送り合えます。広場では、みんなと話せます。': 'When you both like each other, it is a match. Only matches can chat one-on-one and send photos. Everyone can talk in the Plaza.',
  '安心して使うために': 'Stay safe',
  'サーバーは使わず、データはあなたのスマホの中だけ。不快な相手は、通報・ブロックできます。18歳以上の方のみご利用いただけます。': 'No servers: your data stays on your phone. You can report or block anyone who bothers you. For ages 18 and over only.',
  'スキップ': 'Skip',
  'はじめる': 'Get started',
  '次へ': 'Next',
  'カフェ': 'Cafe',
  '映画': 'Movies',
  '音楽': 'Music',
  'ゲーム': 'Games',
  '読書': 'Reading',
  'アニメ': 'Anime',
  'スポーツ': 'Sports',
  '旅行': 'Travel',
  '料理': 'Cooking',
  '写真': 'Photography',
  'プログラミング': 'Programming',
  'お酒': 'Drinks',
  '散歩': 'Walks',
  '筋トレ': 'Workouts',
  '18歳以上であることの確認が必要です': 'You must confirm that you are 18 or older',
  '保存しました': 'Saved',
  'アイコン': 'Icon',
  'ニックネーム': 'Nickname',
  '本名は避けましょう': 'Avoid your real name',
  'ひとこと': 'About me',
  '160字まで': 'Up to 160 characters',
  '例：窓際の席で作業してます。コーヒー好きな人と話したい': 'e.g. Working by the window. Want to chat with coffee lovers',
  '趣味・興味': 'Interests',
  'スペース区切りで最大8個': 'Separate with spaces, up to 8',
  'カフェ 映画 ゲーム': 'Cafe Movies Games',
  '18歳以上です。連絡先や住所などの個人情報を安易に教えないことに同意します。': 'I am 18 or older. I agree not to casually share personal information such as contact details or my address.',
  'アプリを入れた人同士が、同じWiFiにいるときだけお互いを見つけられます。サーバーは使いません。': 'People who have the app can find each other only while on the same WiFi. No servers are used.',
  '💞 マッチしました': '💞 It is a match',
  '💌 誰かがあなたにいいねしました': '💌 Someone liked you',
  '💌 いいねが届きました': '💌 You got a like',
  '誰かがあなたにいいねしました': 'Someone liked you',
  'マッチしました！': 'It is a match!',
  'あとで': 'Later',
  'メッセージを送る': 'Send a message',
  '停止中': 'Stopped',
  'みんな': 'People',
  'マッチ': 'Matches',
  '広場': 'Plaza',
  '自分': 'Me',
  'いまここにいる人': 'People here now',
  '同じWiFiにいるアプリ利用者。共通の趣味が多い順': 'App users on the same WiFi, sorted by shared interests',
  '📵 WiFiに接続されていないようです。WiFiをオンにしてください。': '📵 You do not seem to be connected to WiFi. Please turn WiFi on.',
  'まだ誰も見つかっていません。\n同じWiFiの人にこのアプリを入れてもらいましょう。\n\n※カフェや大学などの公衆WiFiは端末同士の通信が禁止されていることがあります。': 'No one found yet.\nAsk people on the same WiFi to install this app.\n\nNote: public WiFi at cafes or universities may block device-to-device connections.',
  '（ひとことなし）': '(No bio)',
  '話す': 'Chat',
  'いいね済み': 'Liked',
  'いいね': 'Like',
  '通報': 'Report',
  'ブロック': 'Block',
  'お互いに表示されなくなり、メッセージも届かなくなります。': 'You will no longer see each other, and messages will not be delivered.',
  'キャンセル': 'Cancel',
  'ブロックしました': 'Blocked',
  '不適切な内容・言葉': 'Inappropriate content or language',
  '嫌がらせ・しつこい迷惑行為': 'Harassment or persistent unwanted contact',
  '18歳未満の疑い': 'Suspected under 18',
  '勧誘・宣伝・詐欺の疑い': 'Suspected solicitation, ads or scams',
  'その他': 'Other',
  '理由を選んでください。通報すると、この人をブロックし、通報の内容がコピーされます。': 'Choose a reason. Reporting blocks this person and copies the report details.',
  '通報してブロック': 'Report and block',
  '通報してブロックしました': 'Reported and blocked',
  '閉じる': 'Close',
  'お互いにいいねした人とだけ1対1で話せます': 'Chat one-on-one only with people you both liked',
  'まだマッチはありません。\n「みんな」から気になる人にいいねしよう。': 'No matches yet.\nLike someone from "People".',
  'オンライン': 'Online',
  'オフライン': 'Offline',
  '写真を送る': 'Send a photo',
  '（写真を表示できません）': '(Photo cannot be displayed)',
  '📷 写真が届きました\nタップで表示': '📷 A photo arrived\nTap to view',
  '不適切な写真は禁止です。相手が通報すると、ブロックされます。': 'Inappropriate photos are prohibited. If the recipient reports you, you will be blocked.',
  '送る': 'Send',
  'この相手とは話せなくなりました': 'You can no longer talk with this person',
  'オフライン（同じWiFiに戻ると話せます）': 'Offline (you can talk again when back on the same WiFi)',
  'メッセージ…': 'Message…',
  '相手がオフラインです': 'The other person is offline',
  'このWiFiにいる全員が見られるチャット': 'A chat everyone on this WiFi can see',
  '最初のひとことを送ってみよう': 'Send the first message',
  'みんなに話しかける…': 'Talk to everyone…',
  'まだ近くに誰もいないので、自分だけに表示されています': 'No one is nearby yet, so only you can see this',
  'プロフィール': 'Profile',
  '保存すると数秒で近くの人の画面に反映されます': 'Saving updates your profile for nearby people within seconds',
  '保存する': 'Save',
  'メッセージの通知': 'Message notifications',
  'アプリを閉じている間に、メッセージやマッチをお知らせします': 'Get notified of messages and matches while the app is closed',
  'データをすべて削除': 'Delete all data',
  'プロフィール・マッチ・メッセージがこの端末から削除されます。': 'Your profile, matches and messages will be deleted from this device.',
  '削除する': 'Delete',
  '退出してデータを削除': 'Leave and delete data',
  '【ご利用ルール】18歳以上の方のみご利用いただけます。わいせつな内容、嫌がらせ、勧誘や詐欺、金銭の要求、18歳未満の方への接触は禁止です。不快な相手は「通報」「ブロック」ができます（広場では相手のメッセージを長押し）。': 'Rules: only people aged 18 and over may use this app. Sexual content, harassment, solicitation or scams, requests for money, and contact with minors are prohibited. You can report or block anyone who bothers you (in the Plaza, long-press their message).',
  '広告とプライバシーの設定': 'Ads and privacy settings',
  '写真を保存できません': 'Could not save the photo',
  'ニックネームを入力してください': 'Please enter a nickname',
  '相手の端末がまだあなたを見つけていません。数秒後にもう一度試してください': 'The other device has not found you yet. Please try again in a few seconds.',
  'この相手には送れません': 'You cannot send to this person',
  '相手の端末に届きませんでした': 'The message did not reach the other device',
  'マッチした相手とだけ話せます': 'You can only talk with people you matched with',
  'この形式の写真は送れません': 'This photo format cannot be sent',
  '写真が大きすぎます。別の写真を選んでください': 'The photo is too large. Please choose another one.',
  '📷 写真': '📷 Photo',
  'プロフィールやメッセージは、この端末の中だけに保存されます。やり取りは同じWiFi内の端末同士で直接行われ、運営のサーバーには送られません。広告の表示のため、広告サービス（Google AdMob）が端末の情報を利用することがあります。': 'Your profile and messages are stored only on this device. Communication happens directly between devices on the same WiFi and is not sent to any operator server. To show ads, the ad service (Google AdMob) may use information about your device.',
};
