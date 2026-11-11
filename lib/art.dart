import 'package:flutter/material.dart';

/// 名前（またはアイコンの文字）ごとに、見た目が決まる、イラストの顔アイコン。
class FaceAvatar extends StatelessWidget {
  const FaceAvatar(this.seed, {super.key, this.size = 48});
  final String seed;
  final double size;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: size,
        height: size,
        child: ClipOval(child: CustomPaint(painter: _FacePainter(seed))),
      );
}

int _hash(String s) {
  var h = 0;
  for (final u in s.codeUnits) {
    h = (h * 31 + u) & 0xFFFFFFFF;
  }
  h = ((h ^ (h >> 16)) * 0x45d9f3b) & 0xFFFFFFFF;
  h = ((h ^ (h >> 16)) * 0x45d9f3b) & 0xFFFFFFFF;
  return (h ^ (h >> 16)) & 0xFFFFFFFF;
}

const _bgs = [
  [Color(0xFFFFC8A2), Color(0xFFFF7E9D)],
  [Color(0xFFA9DCFF), Color(0xFF8A8CFF)],
  [Color(0xFFB6F0D2), Color(0xFF4FC3A8)],
  [Color(0xFFFFE08A), Color(0xFFFFA05A)],
  [Color(0xFFEBC6FF), Color(0xFF9C7BFF)],
];
const _hairs = [
  [Color(0xFF2B2430), Color(0xFF4A4050)],
  [Color(0xFF5A3A2A), Color(0xFF8A5C42)],
  [Color(0xFFB5651D), Color(0xFFE0974A)],
  [Color(0xFF3A4A8A), Color(0xFF5E73C4)],
  [Color(0xFF8A2F4A), Color(0xFFC25577)],
  [Color(0xFF1F1A24), Color(0xFF3B3342)],
];
const _skins = [
  [Color(0xFFFFE6D5), Color(0xFFFFD2B8)],
  [Color(0xFFFFD9BE), Color(0xFFF6BE9A)],
  [Color(0xFFF2C4A0), Color(0xFFE0A47C)],
  [Color(0xFFE8B48C), Color(0xFFCF946A)],
];
const _tops = [
  Color(0xFFFF4D6D),
  Color(0xFF3D6BFF),
  Color(0xFF2BB38A),
  Color(0xFFFFB347),
  Color(0xFF8F6BFF),
  Color(0xFF2B2430),
];

class _FacePainter extends CustomPainter {
  _FacePainter(this.seed);
  final String seed;

  @override
  void paint(Canvas canvas, Size size) {
    final h = _hash(seed);
    final bg = _bgs[h % 5];
    final hr = _hairs[(h >> 3) % 6];
    final sk = _skins[(h >> 6) % 4];
    final st = (h >> 9) % 5;
    final ac = (h >> 12) % 4;
    final tp = _tops[(h >> 14) % 6];
    final op = (h >> 17) % 2 == 1;

    canvas.save();
    canvas.scale(size.width / 100, size.height / 100);

    Paint fill(Color c) => Paint()..color = c;
    final hairPaint = Paint()
      ..shader = LinearGradient(colors: [hr[1], hr[0]], begin: Alignment.topLeft, end: Alignment.bottomRight)
          .createShader(const Rect.fromLTWH(20, 8, 60, 80));
    final skinPaint = Paint()
      ..shader = RadialGradient(colors: [sk[0], sk[1]], center: const Alignment(0, -0.2), radius: 0.7)
          .createShader(const Rect.fromLTWH(29, 20, 42, 52));

    const full = Rect.fromLTWH(0, 0, 100, 100);
    canvas.drawRect(
      full,
      Paint()..shader = LinearGradient(colors: bg, begin: Alignment.topLeft, end: Alignment.bottomRight).createShader(full),
    );
    canvas.drawCircle(const Offset(82, 14), 24, fill(const Color(0x2EFFFFFF)));
    canvas.drawCircle(const Offset(10, 92), 20, fill(const Color(0x1FFFFFFF)));

    // 後ろ髪
    if (st == 2) {
      final p = Path()
        ..moveTo(26, 52)
        ..cubicTo(20, 24, 35, 10, 50, 10)
        ..cubicTo(65, 10, 80, 24, 74, 52)
        ..lineTo(78, 86)
        ..lineTo(62, 86)
        ..lineTo(62, 58)
        ..lineTo(38, 58)
        ..lineTo(38, 86)
        ..lineTo(22, 86)
        ..close();
      canvas.drawPath(p, hairPaint);
    }
    if (st == 3) {
      final p = Path()
        ..moveTo(25, 54)
        ..cubicTo(20, 24, 35, 10, 50, 10)
        ..cubicTo(65, 10, 80, 24, 75, 54)
        ..lineTo(75, 68)
        ..quadraticBezierTo(75, 76, 66, 74)
        ..lineTo(34, 74)
        ..quadraticBezierTo(25, 76, 25, 68)
        ..close();
      canvas.drawPath(p, hairPaint);
    }
    if (st == 4) canvas.drawCircle(const Offset(50, 9), 9, hairPaint);

    // からだ
    final body = Path()
      ..moveTo(6, 104)
      ..cubicTo(8, 82, 26, 73, 50, 73)
      ..cubicTo(74, 73, 92, 82, 94, 104)
      ..close();
    canvas.drawPath(body, fill(tp));
    final collar = Path()
      ..moveTo(40, 74)
      ..lineTo(50, 90)
      ..lineTo(60, 74)
      ..quadraticBezierTo(50, 70, 40, 74)
      ..close();
    canvas.drawPath(collar, fill(const Color(0xEBFFFFFF)));

    // 首・耳・顔
    canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(43, 60, 14, 20), const Radius.circular(6)), skinPaint);
    canvas.drawOval(Rect.fromCenter(center: const Offset(50, 73), width: 18, height: 8), fill(const Color(0x1A000000)));
    canvas.drawCircle(const Offset(30.5, 50), 5, skinPaint);
    canvas.drawCircle(const Offset(69.5, 50), 5, skinPaint);
    if (op) {
      canvas.drawCircle(const Offset(30, 56), 1.6, fill(const Color(0xFFFFD36B)));
      canvas.drawCircle(const Offset(70, 56), 1.6, fill(const Color(0xFFFFD36B)));
    }
    final face = Path()
      ..moveTo(29, 46)
      ..cubicTo(29, 27, 39, 20, 50, 20)
      ..cubicTo(61, 20, 71, 27, 71, 46)
      ..cubicTo(71, 62, 61, 72, 50, 72)
      ..cubicTo(39, 72, 29, 62, 29, 46)
      ..close();
    canvas.drawPath(face, skinPaint);

    // 前髪
    final f = Path();
    if (st == 0) {
      f
        ..moveTo(28, 48)
        ..cubicTo(25, 26, 37, 14, 50, 14)
        ..cubicTo(63, 14, 75, 26, 72, 48)
        ..cubicTo(70, 39, 66, 33, 60, 30)
        ..cubicTo(54, 35, 42, 35, 37, 30)
        ..cubicTo(33, 34, 30, 40, 28, 48)
        ..close();
    } else if (st == 1) {
      f
        ..moveTo(27, 50)
        ..cubicTo(22, 26, 37, 12, 54, 14)
        ..cubicTo(69, 16, 75, 30, 72, 50)
        ..cubicTo(70, 40, 65, 31, 55, 30)
        ..cubicTo(45, 30, 35, 36, 27, 50)
        ..close();
    } else if (st == 2) {
      f
        ..moveTo(28, 46)
        ..cubicTo(30, 28, 39, 20, 50, 20)
        ..cubicTo(61, 20, 70, 28, 72, 46)
        ..cubicTo(65, 37, 58, 31, 50, 31)
        ..cubicTo(42, 31, 35, 37, 28, 46)
        ..close();
    } else if (st == 3) {
      f
        ..moveTo(28, 42)
        ..cubicTo(30, 26, 39, 19, 50, 19)
        ..cubicTo(61, 19, 70, 26, 72, 42)
        ..cubicTo(62, 37, 56, 35, 50, 35)
        ..cubicTo(44, 35, 38, 37, 28, 42)
        ..close();
    } else {
      f
        ..moveTo(28, 48)
        ..cubicTo(26, 27, 37, 17, 50, 17)
        ..cubicTo(63, 17, 74, 27, 72, 48)
        ..cubicTo(69, 40, 65, 34, 59, 31)
        ..cubicTo(53, 36, 43, 36, 38, 31)
        ..cubicTo(33, 35, 30, 41, 28, 48)
        ..close();
    }
    canvas.drawPath(f, hairPaint);
    canvas.drawPath(
      Path()
        ..moveTo(36, 22)
        ..quadraticBezierTo(44, 15, 54, 16),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = 2.4
        ..color = const Color(0x47FFFFFF),
    );

    Paint stroke(Color c, double w) => Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = w
      ..color = c;

    // 眉・目
    canvas.drawPath(
      Path()
        ..moveTo(35.5, 41)
        ..quadraticBezierTo(40.5, 37.5, 45, 39.8)
        ..moveTo(55, 39.8)
        ..quadraticBezierTo(60, 37.5, 64.5, 41),
      stroke(hr[0], 2),
    );
    const ink = Color(0xFF2B2430);
    canvas.drawOval(Rect.fromCenter(center: const Offset(40.5, 49), width: 6.6, height: 8.6), fill(ink));
    canvas.drawOval(Rect.fromCenter(center: const Offset(59.5, 49), width: 6.6, height: 8.6), fill(ink));
    canvas.drawOval(Rect.fromCenter(center: const Offset(40.5, 51), width: 4.4, height: 4), fill(const Color(0x8C6A4B7A)));
    canvas.drawOval(Rect.fromCenter(center: const Offset(59.5, 51), width: 4.4, height: 4), fill(const Color(0x8C6A4B7A)));
    canvas.drawCircle(const Offset(41.7, 47.4), 1.4, fill(Colors.white));
    canvas.drawCircle(const Offset(60.7, 47.4), 1.4, fill(Colors.white));
    canvas.drawCircle(const Offset(39.3, 50.8), 0.7, fill(Colors.white));
    canvas.drawCircle(const Offset(58.3, 50.8), 0.7, fill(Colors.white));
    canvas.drawPath(
      Path()
        ..moveTo(37, 45.2)
        ..quadraticBezierTo(40.5, 42.8, 44, 45.2)
        ..moveTo(56, 45.2)
        ..quadraticBezierTo(59.5, 42.8, 63, 45.2),
      stroke(ink, 1.3),
    );
    canvas.drawPath(
      Path()
        ..moveTo(50, 53)
        ..quadraticBezierTo(48.2, 56.2, 50.8, 56.6),
      stroke(const Color(0xCCC98F6E), 1.2),
    );
    canvas.drawOval(Rect.fromCenter(center: const Offset(34.5, 58), width: 9, height: 5.6), fill(const Color(0x6BFF7E9D)));
    canvas.drawOval(Rect.fromCenter(center: const Offset(65.5, 58), width: 9, height: 5.6), fill(const Color(0x6BFF7E9D)));

    // くち
    if (h % 3 == 0) {
      canvas.drawPath(
        Path()
          ..moveTo(43, 61)
          ..quadraticBezierTo(50, 70, 57, 61)
          ..close(),
        fill(const Color(0xFFB5485A)),
      );
      canvas.drawPath(
        Path()
          ..moveTo(45.5, 66.5)
          ..quadraticBezierTo(50, 64.2, 54.5, 66.5)
          ..quadraticBezierTo(50, 69.5, 45.5, 66.5)
          ..close(),
        fill(const Color(0xFFFF8FA3)),
      );
    } else {
      canvas.drawPath(
        Path()
          ..moveTo(43.5, 61.5)
          ..quadraticBezierTo(50, 67.5, 56.5, 61.5),
        stroke(const Color(0xFFB5485A), 2),
      );
    }

    // こもの
    if (ac == 1) {
      final g = stroke(ink, 1.8);
      canvas.drawCircle(const Offset(40.5, 49), 7.5, fill(const Color(0x1FFFFFFF)));
      canvas.drawCircle(const Offset(59.5, 49), 7.5, fill(const Color(0x1FFFFFFF)));
      canvas.drawCircle(const Offset(40.5, 49), 7.5, g);
      canvas.drawCircle(const Offset(59.5, 49), 7.5, g);
      canvas.drawPath(
        Path()
          ..moveTo(48, 48.5)
          ..quadraticBezierTo(50, 46.9, 52, 48.5)
          ..moveTo(33, 47.5)
          ..lineTo(29.5, 45.5)
          ..moveTo(67, 47.5)
          ..lineTo(70.5, 45.5),
        g,
      );
    }
    if (ac == 2) {
      canvas.drawPath(
        Path()
          ..moveTo(27, 48)
          ..cubicTo(24, 24, 38, 12, 50, 12)
          ..cubicTo(62, 12, 76, 24, 73, 48),
        stroke(ink, 3.2),
      );
      canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(22.5, 44, 8, 14), const Radius.circular(4)), fill(const Color(0xFFFF4D6D)));
      canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(69.5, 44, 8, 14), const Radius.circular(4)), fill(const Color(0xFFFF4D6D)));
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_FacePainter old) => old.seed != seed;
}

/// 掲示板のカテゴリを表す、色つきの小さなアイコン。
class CategoryIcon extends StatelessWidget {
  const CategoryIcon(this.cat, {super.key, this.size = 38});
  final String cat;
  final double size;

  static const _defs = <String, List<Object>>{
    'テーマパーク': [Color(0xFF8F6BFF), Color(0xFFFF7EB0), Icons.attractions],
    'ライブ・フェス': [Color(0xFFFF4D6D), Color(0xFFFF9A4A), Icons.mic],
    '旅行': [Color(0xFF3DB8FF), Color(0xFF5B7BFF), Icons.landscape],
    'グルメ': [Color(0xFFFF9A4A), Color(0xFFFF5A5F), Icons.ramen_dining],
    'スポーツ': [Color(0xFF2BB38A), Color(0xFF1F8A6E), Icons.sports_soccer],
    '趣味・その他': [Color(0xFF8A6BFF), Color(0xFF3DB8FF), Icons.music_note],
  };

  @override
  Widget build(BuildContext context) {
    final d = _defs[cat] ?? _defs['趣味・その他']!;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 0.32),
        gradient: LinearGradient(colors: [d[0] as Color, d[1] as Color], begin: Alignment.topLeft, end: Alignment.bottomRight),
        boxShadow: const [BoxShadow(color: Color(0x2E280A1E), blurRadius: 8, offset: Offset(0, 3))],
      ),
      child: Icon(d[2] as IconData, color: Colors.white, size: size * 0.58),
    );
  }
}
