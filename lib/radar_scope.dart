import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'art.dart';

/// 近くの人を探す、レーダーの画面。オンの間は、探索の光が回り、中心から波が広がる。
class RadarScope extends StatefulWidget {
  const RadarScope({super.key, required this.active, required this.me, this.others = const []});
  final bool active;
  final String me;

  /// 近くにいた人（表示名の文字、距離の目安の文字）
  final List<({String seed, String label})> others;

  @override
  State<RadarScope> createState() => _RadarScopeState();
}

class _RadarScopeState extends State<RadarScope> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(seconds: 4))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  Offset _spot(String seed, int i) {
    var h = 7;
    for (final u in seed.codeUnits) {
      h = (h * 31 + u) & 0xFFFFFF;
    }
    final a = i * 2.4 + (h % 100) / 100;
    final r = 0.40 + ((i * 37 + h) % 40) / 100;
    return Offset(math.cos(a) * r, math.sin(a) * r);
  }
  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1,
      child: LayoutBuilder(
        builder: (context, box) {
          final w = box.maxWidth;
          return Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: (widget.active ? const Color(0x55FF4D6D) : const Color(0x33281446)),
                  blurRadius: 40,
                  offset: const Offset(0, 14),
                ),
              ],
            ),
            child: ClipOval(
              child: AnimatedBuilder(
                animation: _c,
                builder: (context, _) {
                  final t = _c.value;
                  final shown = widget.others.take(5).toList();
                  return Stack(alignment: Alignment.center, children: [
                    Positioned.fill(child: CustomPaint(painter: _ScopePainter(t, widget.active))),
                    if (widget.active)
                      for (var i = 0; i < shown.length; i++)
                        Builder(builder: (context) {
                          final s = _spot(shown[i].seed, i);
                          final blink = 0.55 + 0.45 * ((math.sin((t * 2 + i * 0.37) * math.pi * 2) + 1) / 2);
                          return Positioned(
                            left: w / 2 + s.dx * w / 2 - 20,
                            top: w / 2 + s.dy * w / 2 - 20,
                            width: 40,
                            child: Opacity(
                              opacity: blink,
                              child: Column(mainAxisSize: MainAxisSize.min, children: [
                                Container(
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.white, width: 2),
                                    boxShadow: const [BoxShadow(color: Color(0x99FF7896), blurRadius: 16)],
                                  ),
                                  child: FaceAvatar(shown[i].seed, size: 34),
                                ),
                                const SizedBox(height: 2),
                                Text(shown[i].label,
                                    maxLines: 1,
                                    overflow: TextOverflow.visible,
                                    softWrap: false,
                                    style: const TextStyle(color: Colors.white, fontSize: 9.5, shadows: [Shadow(color: Colors.black54, blurRadius: 3)])),
                              ]),
                            ),
                          );
                        }),
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 3),
                        boxShadow: [
                          BoxShadow(color: widget.active ? const Color(0xCCFF4D6D) : const Color(0x55FFFFFF), blurRadius: 24, spreadRadius: 4),
                        ],
                      ),
                      child: FaceAvatar(widget.me, size: 46),
                    ),
                  ]);
                },
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ScopePainter extends CustomPainter {
  _ScopePainter(this.t, this.active);
  final double t;
  final bool active;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2;
    final rect = Rect.fromCircle(center: c, radius: r);
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(0, -0.1),
          colors: [Color(0xFF4B2A78), Color(0xFF2A1650), Color(0xFF1B0F38)],
          stops: [0, 0.55, 1],
        ).createShader(rect),
    );
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..color = const Color(0x33FFFFFF);
    for (final f in [0.98, 0.64, 0.30]) {
      canvas.drawCircle(c, r * f, line);
    }
    final thin = Paint()
      ..strokeWidth = 1
      ..color = const Color(0x1AFFFFFF);
    canvas.drawLine(Offset(c.dx - r * 0.97, c.dy), Offset(c.dx + r * 0.97, c.dy), thin);
    canvas.drawLine(Offset(c.dx, c.dy - r * 0.97), Offset(c.dx, c.dy + r * 0.97), thin);
    void label(String s, double f) {
      final tp = TextPainter(
        text: TextSpan(text: s, style: const TextStyle(color: Color(0x8CFFFFFF), fontSize: 9.5)),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(c.dx + 4, c.dy - r * f + 2));
    }

    label('10m', 0.30);
    label('50m', 0.64);
    label('100m', 0.98);

    if (active) {
      canvas.save();
      canvas.translate(c.dx, c.dy);
      canvas.rotate(t * math.pi * 2);
      canvas.drawCircle(
        Offset.zero,
        r,
        Paint()
          ..shader = const SweepGradient(
            colors: [Color(0x00FF4D6D), Color(0x00FF4D6D), Color(0x80FF6E8C), Color(0xE6FFC8D2)],
            stops: [0, 0.69, 0.995, 1],
          ).createShader(Rect.fromCircle(center: Offset.zero, radius: r)),
      );
      canvas.restore();
      for (var k = 0; k < 3; k++) {
        final p = (t * 1.1 + k / 3) % 1.0;
        canvas.drawCircle(
          c,
          r * (0.10 + 0.9 * p),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2
            ..color = Color.fromRGBO(255, 140, 170, (1 - p) * 0.8),
        );
      }
    }
    canvas.drawCircle(
      c,
      r - 1,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = const Color(0x24FFFFFF),
    );
  }

  @override
  bool shouldRepaint(_ScopePainter old) => old.t != t || old.active != active;
}
