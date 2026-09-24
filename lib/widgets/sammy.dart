// Sammy the Turtle, drawn in code (L9). Moods from the PDD: idle, sleeping,
// celebrating and shell-tuck. [breath] (0..1) lets Sammy breathe with the
// Flow Canvas ring.

import 'dart:math';

import 'package:flutter/material.dart';

enum SammyMood { idle, sleeping, celebrating, tuck }

class Sammy extends StatefulWidget {
  final double size;
  final SammyMood mood;

  /// External breath phase 0..1; when null Sammy breathes on its own slowly.
  final double? breath;

  /// Gentle bob and blink; off in Low Motion.
  final bool animate;

  const Sammy({super.key, this.size = 160, this.mood = SammyMood.idle, this.breath, this.animate = true});

  @override
  State<Sammy> createState() => _SammyState();
}

class _SammyState extends State<Sammy> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(seconds: 10));
  double _head = 1;

  @override
  void initState() {
    super.initState();
    _head = widget.mood == SammyMood.tuck ? 0.15 : 1;
    if (widget.animate) _c.repeat();
  }

  @override
  void didUpdateWidget(Sammy old) {
    super.didUpdateWidget(old);
    if (widget.animate && !_c.isAnimating) _c.repeat();
    if (!widget.animate && _c.isAnimating) _c.stop();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Sammy the Turtle',
      image: true,
      child: TweenAnimationBuilder<double>(
        tween: Tween(end: widget.mood == SammyMood.tuck ? 0.15 : 1.0),
        duration: const Duration(milliseconds: 900),
        curve: Curves.easeInOut,
        builder: (context, head, _) {
          _head = head;
          return AnimatedBuilder(
            animation: _c,
            builder: (context, _) {
              final t = _c.value; // 0..1 over 10 s
              final breath = widget.breath ?? (0.5 - 0.5 * cos(2 * pi * t));
              // Blink briefly twice per cycle (never while asleep).
              final blink = widget.animate && ((t > 0.30 && t < 0.315) || (t > 0.78 && t < 0.795));
              return CustomPaint(
                size: Size(widget.size, widget.size * 0.72),
                painter: _SammyPainter(
                  mood: widget.mood,
                  breath: breath,
                  headOut: _head,
                  blink: blink,
                  sparkle: widget.mood == SammyMood.celebrating ? t : null,
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _SammyPainter extends CustomPainter {
  final SammyMood mood;
  final double breath;
  final double headOut;
  final bool blink;
  final double? sparkle;

  _SammyPainter({required this.mood, required this.breath, required this.headOut, required this.blink, this.sparkle});

  static const skin = Color(0xFFA9D8A6);
  static const skinDark = Color(0xFF86BF86);
  static const shell = Color(0xFF7FC8A9);
  static const plate = Color(0xFF63AE90);
  static const rim = Color(0xFFE8D39A);
  static const ink = Color(0xFF2B2D3A);
  static const blush = Color(0xFFF2B8A0);

  @override
  void paint(Canvas canvas, Size size) {
    // Design space is 200 x 144; the artwork spans x 18..208, so shift left.
    final s = size.width / 200;
    canvas.scale(s);
    canvas.translate(-9, 0);
    final p = Paint()..isAntiAlias = true;

    // Soft ground shadow.
    p.color = const Color(0x33000000);
    canvas.drawOval(const Rect.fromLTWH(30, 124, 150, 14), p);

    // Legs (drawn first; the shell covers their tops).
    p.color = skinDark;
    for (final x in [52.0, 132.0]) {
      canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(x, 100, 26, 28), const Radius.circular(12)), p);
    }
    p.color = skin;
    for (final x in [68.0, 148.0]) {
      canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(x, 102, 26, 28), const Radius.circular(12)), p);
    }
    // Tail.
    final tail = Path()
      ..moveTo(40, 104)
      ..quadraticBezierTo(22, 108, 18, 116)
      ..quadraticBezierTo(32, 116, 46, 112)
      ..close();
    canvas.drawPath(tail, p);

    // Head and neck: slides out from under the shell (headOut 0..1).
    final hx = 150 + 34 * headOut;
    final hy = 78 - 6 * headOut;
    p.color = skin;
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(hx - 34, hy + 4, 40, 26), const Radius.circular(13)), p);
    canvas.drawCircle(Offset(hx, hy), 24, p);

    // Face.
    if (headOut > 0.5) {
      final eye = Offset(hx + 8, hy - 5);
      final line = Paint()
        ..color = ink
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round;
      if (mood == SammyMood.sleeping || blink) {
        canvas.drawArc(Rect.fromCenter(center: eye, width: 11, height: 8), 0.2, pi - 0.4, false, line);
      } else if (mood == SammyMood.celebrating) {
        canvas.drawArc(Rect.fromCenter(center: eye.translate(0, 3), width: 11, height: 10), pi + 0.3, pi - 0.6, false, line);
      } else {
        p.color = ink;
        canvas.drawCircle(eye, 4.6, p);
        p.color = const Color(0xFFF7F4EA);
        canvas.drawCircle(eye.translate(1.5, -1.6), 1.6, p);
      }
      p.color = blush.withValues(alpha: 0.8);
      canvas.drawOval(Rect.fromCenter(center: Offset(hx + 2, hy + 7), width: 10, height: 6), p);
      final smileW = mood == SammyMood.celebrating ? 14.0 : 10.0;
      canvas.drawArc(Rect.fromCenter(center: Offset(hx + 13, hy + 6), width: smileW, height: smileW * 0.8), 0.2, pi * 0.7, false, line);
      if (mood == SammyMood.sleeping) {
        final zs = TextPainter(
          text: const TextSpan(text: 'z z', style: TextStyle(color: Color(0xFF9D8DF1), fontSize: 16, fontWeight: FontWeight.bold)),
          textDirection: TextDirection.ltr,
        )..layout();
        zs.paint(canvas, Offset(hx + 10, hy - 42 - 6 * breath));
      }
    }

    // Shell: a dome that rises a little with each breath.
    canvas.save();
    canvas.translate(0, 110);
    canvas.scale(1, 1 + 0.06 * breath);
    canvas.translate(0, -110);
    final dome = Path()
      ..moveTo(34, 108)
      ..cubicTo(34, 40, 166, 40, 166, 108)
      ..close();
    p.color = shell;
    canvas.drawPath(dome, p);
    canvas.save();
    canvas.clipPath(dome);
    p.color = plate;
    for (final c in const [Offset(100, 62), Offset(68, 88), Offset(132, 88), Offset(100, 100)]) {
      canvas.drawPath(_hex(c, c.dy < 70 ? 17 : 15), p);
    }
    // Highlight.
    p.color = const Color(0x33FFFFFF);
    canvas.drawOval(const Rect.fromLTWH(58, 50, 50, 16), p);
    canvas.restore();
    p.color = rim;
    canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(28, 102, 144, 12), const Radius.circular(6)), p);
    canvas.restore();

    // Celebration: a few slow, small stars (no screen-wide burst, L16).
    final sp = sparkle;
    if (sp != null) {
      p.color = const Color(0xFFF4E4BA);
      for (var i = 0; i < 5; i++) {
        final a = -pi / 2 + (i - 2) * 0.5;
        final r = 70 + 18 * sin(2 * pi * (sp + i / 5));
        _star(canvas, Offset(100 + r * cos(a), 92 + r * sin(a)), 5 + 1.5 * sin(2 * pi * (sp * 2 + i / 5)), p);
      }
    }
  }

  static Path _hex(Offset c, double r) {
    final path = Path();
    for (var i = 0; i < 6; i++) {
      final a = pi / 6 + i * pi / 3;
      final pt = c + Offset(r * cos(a), r * sin(a));
      i == 0 ? path.moveTo(pt.dx, pt.dy) : path.lineTo(pt.dx, pt.dy);
    }
    return path..close();
  }

  static void _star(Canvas canvas, Offset c, double r, Paint p) {
    final path = Path();
    for (var i = 0; i < 10; i++) {
      final rr = i.isEven ? r : r * 0.45;
      final a = -pi / 2 + i * pi / 5;
      final pt = c + Offset(rr * cos(a), rr * sin(a));
      i == 0 ? path.moveTo(pt.dx, pt.dy) : path.lineTo(pt.dx, pt.dy);
    }
    canvas.drawPath(path..close(), p);
  }

  @override
  bool shouldRepaint(_SammyPainter o) =>
      o.breath != breath || o.headOut != headOut || o.blink != blink || o.mood != mood || o.sparkle != sparkle;
}
