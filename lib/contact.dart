import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import 'main.dart' show toast;

/// お問い合わせの送り先（メール）。変えたいときは、ここだけ直す。
const String kContactEmail = 'harukazu1995@gmail.com';

/// 設定の画面から開く、お問い合わせの窓口。
/// 種類と内容を書くと、メールアプリが開き、送り先と件名が入った状態になる。
void openContact(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
      child: const _ContactSheet(),
    ),
  );
}

class _ContactSheet extends StatefulWidget {
  const _ContactSheet();

  @override
  State<_ContactSheet> createState() => _ContactSheetState();
}

class _ContactSheetState extends State<_ContactSheet> {
  static const _kinds = ['不具合・困りごと', 'ご要望', '通報・相談', '課金・お支払い', 'その他'];
  String _kind = _kinds.first;
  final _text = TextEditingController();

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final body = _text.text.trim();
    if (body.isEmpty) {
      toast('内容を書いてください');
      return;
    }
    final full = '$body\n\n--\n種類: $_kind\nアプリ: Meetory';
    final subject = '【Meetory】$_kind';
    final uri = Uri.parse('mailto:$kContactEmail?subject=${Uri.encodeComponent(subject)}&body=${Uri.encodeComponent(full)}');
    var ok = false;
    try {
      ok = await launchUrl(uri);
    } catch (_) {}
    if (!mounted) return;
    if (ok) {
      Navigator.pop(context);
    } else {
      await Clipboard.setData(ClipboardData(text: full));
      toast('メールアプリを開けませんでした。内容をコピーしたので、$kContactEmail に送ってください');
    }
  }

  @override
  Widget build(BuildContext context) {
    final hint = Theme.of(context).hintColor;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        const Text('お問い合わせ', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        Text('不具合やご要望、通報などを、運営に送れます。', style: TextStyle(fontSize: 13.5, color: hint)),
        const SizedBox(height: 14),
        Wrap(spacing: 8, runSpacing: 4, children: [
          for (final k in _kinds)
            ChoiceChip(label: Text(k), selected: _kind == k, onSelected: (_) => setState(() => _kind = k)),
        ]),
        const SizedBox(height: 12),
        TextField(
          controller: _text,
          minLines: 4,
          maxLines: 8,
          maxLength: 1000,
          decoration: const InputDecoration(border: OutlineInputBorder(), hintText: '内容を書いてください'),
        ),
        Text(
          '「送る」を押すと、メールアプリが開きます。送るのは、ここに書いた内容だけです。電話番号や住所など、知られたくない情報は書かないでください。返信には数日かかることがあります。',
          style: TextStyle(fontSize: 12, color: hint),
        ),
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: _send,
            style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
            child: const Text('送る', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
          ),
        ),
      ]),
    );
  }
}
