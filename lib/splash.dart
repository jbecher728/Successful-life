import 'dart:math' as math;
import 'package:flutter/material.dart';

const _bg = Color(0xFF21877C);
const _eggFill = Color(0xFFFFF3DA);
const _ink = Color(0xFF1B3B38);
const _inside = Color(0xFF0F3F3A);
const _skin = Color(0xFFF2C58E);

/// About 2.15 seconds: an egg drops, bounces three times, cracks, and a fist punches out.
/// Tap to skip. It can be turned off in Settings.
class SplashScreen extends StatefulWidget {
  final VoidCallback onDone;
  const SplashScreen({super.key, required this.onDone});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late final AnimationController c = AnimationController(vsync: this, duration: const Duration(milliseconds: 2150));
  bool done = false;

  void _finish() {
    if (done || !mounted) return;
    done = true;
    widget.onDone();
  }

  @override
  void initState() {
    super.initState();
    c.forward().whenComplete(_finish);
  }

  @override
  void dispose() {
    c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _finish,
        child: ColoredBox(
          color: _bg,
          child: SizedBox.expand(
            child: AnimatedBuilder(animation: c, builder: (_, __) => CustomPaint(painter: _EggPainter(c.value))),
          ),
        ),
      );
}

double _cl(double v) => v < 0 ? 0 : (v > 1 ? 1 : v);
double _easeOutBack(double x) {
  const c1 = 1.70158, c3 = c1 + 1;
  return 1 + c3 * math.pow(x - 1, 3).toDouble() + c1 * math.pow(x - 1, 2).toDouble();
}

class _EggPainter extends CustomPainter {
  final double t;
  _EggPainter(this.t);

  static Path _egg(double w, double h) {
    final p = Path()..moveTo(0, -h / 2);
    p.cubicTo(w * 0.34, -h / 2, w / 2, -h * 0.08, w / 2, h * 0.12);
    p.cubicTo(w / 2, h * 0.34, w * 0.3, h / 2, 0, h / 2);
    p.cubicTo(-w * 0.3, h / 2, -w / 2, h * 0.34, -w / 2, h * 0.12);
    p.cubicTo(-w / 2, -h * 0.08, -w * 0.34, -h / 2, 0, -h / 2);
    return p..close();
  }

  @override
  void paint(Canvas canvas, Size s) {
    final ew = math.min(s.width * 0.44, 190.0), eh = ew * 1.3;
    final ground = s.height * 0.70, rest = ground - eh / 2, cx = s.width / 2;

    // ---- motion of the whole egg
    double y = rest, lift = 0, sx = 1, sy = 1, ang = 0;
    const starts = [0.26, 0.42, 0.53], durs = [0.16, 0.11, 0.07], fr = [0.22, 0.11, 0.05], amp = [1.0, 0.7, 0.45];
    double squash(double k, double a) {
      sy = 1 - 0.14 * k * a;
      sx = 1 + 0.10 * k * a;
      return 0;
    }
    if (t < 0.26) {
      final u = t / 0.26;
      y = -eh + (rest + eh) * u * u;
      if (u > 0.88) squash((u - 0.88) / 0.12, 1.0);
    } else if (t < 0.60) {
      for (var i = 0; i < 3; i++) {
        if (t >= starts[i] && t < starts[i] + durs[i]) {
          final u = (t - starts[i]) / durs[i];
          lift = 4 * u * (1 - u) * s.height * fr[i];
          y = rest - lift;
          final k = math.max(0.0, 1 - math.min(u, 1 - u) / 0.12);
          squash(k, amp[i]);
        }
      }
    } else if (t < 0.64) {
      squash(1 - (t - 0.60) / 0.04, 0.3);
    }
    double shake = 0;
    if (t >= 0.62 && t < 0.76) {
      final q = (t - 0.62) / 0.14;
      ang = math.sin(q * math.pi * 5) * 0.07 * (1 - q * 0.3);
      shake = math.sin(q * math.pi * 14) * ew * 0.008;
    }

    // ---- shadow
    final sh = 0.95 - 0.35 * _cl(lift / (s.height * 0.2));
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx, ground + 4), width: ew * sh, height: ew * 0.14),
      Paint()..color = Colors.black.withValues(alpha: 0.22),
    );

    canvas.save();
    canvas.translate(cx + shake, y + eh / 2);
    canvas.rotate(ang);
    canvas.scale(sx, sy);
    canvas.translate(0, -eh / 2);

    final egg = _egg(ew, eh);
    final line = Paint()..style = PaintingStyle.stroke..strokeWidth = 3.5..strokeJoin = StrokeJoin.round..strokeCap = StrokeCap.round..color = _ink;
    canvas.drawPath(egg, Paint()..color = _eggFill);
    canvas.drawOval(Rect.fromCenter(center: Offset(-ew * 0.18, -eh * 0.24), width: ew * 0.16, height: eh * 0.22), Paint()..color = Colors.white.withValues(alpha: 0.45));

    final hc = Offset(0, -eh * 0.12); // where the fist breaks out
    final tp = _cl((t - 0.76) / 0.24);

    // ---- cracks
    final cp = _cl((t - 0.64) / 0.12);
    if (cp > 0) {
      for (final pts in [
        [hc, Offset(-ew * .10, -eh * .02), Offset(-ew * .04, eh * .08), Offset(-ew * .20, eh * .20)],
        [hc, Offset(ew * .12, -eh * .20), Offset(ew * .06, -eh * .30), Offset(ew * .20, -eh * .36)],
        [hc, Offset(ew * .16, eh * .01), Offset(ew * .26, eh * .10)],
      ]) {
        final path = Path()..moveTo(pts[0].dx, pts[0].dy);
        for (final p in pts.skip(1)) {
          path.lineTo(p.dx, p.dy);
        }
        for (final m in path.computeMetrics()) {
          canvas.drawPath(m.extractPath(0, m.length * cp), line..strokeWidth = 2.6);
        }
      }
    }

    // ---- hole, arm, fist
    if (tp > 0) {
      final hp = _cl(tp / 0.3);
      final r = ew * 0.33 * hp;
      final hole = Path();
      const n = 9;
      for (var i = 0; i < n * 2; i++) {
        final a = i / (n * 2) * math.pi * 2 + 0.2;
        final rr = (i.isEven ? 1.0 : 0.62) * r * (1 + 0.12 * math.sin(i * 2.3));
        final p = Offset(hc.dx + math.cos(a) * rr, hc.dy + math.sin(a) * rr * 1.1);
        if (i == 0) {
          hole.moveTo(p.dx, p.dy);
        } else {
          hole.lineTo(p.dx, p.dy);
        }
      }
      hole.close();
      canvas.drawPath(hole, Paint()..color = _inside);
      canvas.drawPath(hole, line..strokeWidth = 3.0);

      final fp = _cl((tp - 0.1) / 0.6);
      if (fp > 0) {
        final fw = ew * 0.50, fh = fw * 0.95;
        final sc = 0.15 + 0.9 * _easeOutBack(fp);
        final up = -ew * 0.24 * (1 - math.pow(1 - fp, 2).toDouble());
        final fc = Offset(hc.dx, hc.dy + up);
        // forearm, visible only inside the hole
        canvas.save();
        canvas.clipPath(hole);
        canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(fc.dx, fc.dy + fh * sc * 0.9), width: fw * 0.62 * sc, height: fh * 1.2 * sc), const Radius.circular(8)), Paint()..color = _skin);
        canvas.restore();
        // fist
        canvas.save();
        canvas.translate(fc.dx, fc.dy);
        canvas.scale(sc, sc);
        final body = RRect.fromRectAndRadius(Rect.fromCenter(center: Offset.zero, width: fw, height: fh), Radius.circular(fw * 0.22));
        canvas.drawRRect(body, Paint()..color = _skin);
        final f = line..strokeWidth = 3.0 / sc.clamp(0.5, 2.0);
        canvas.drawRRect(body, f);
        for (var i = 1; i < 4; i++) {
          final x = -fw / 2 + i * fw / 4;
          canvas.drawLine(Offset(x, -fh / 2 + 2), Offset(x, -fh * 0.04), f);
        }
        canvas.drawLine(Offset(-fw / 2 + 3, -fh * 0.04), Offset(fw / 2 - 3, -fh * 0.04), f);
        final thumb = RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(0, fh * 0.22), width: fw * 0.80, height: fw * 0.27), Radius.circular(fw * 0.13));
        canvas.save();
        canvas.rotate(-0.12);
        canvas.drawRRect(thumb, Paint()..color = _skin);
        canvas.drawRRect(thumb, f);
        canvas.restore();
        canvas.restore();
      }

      // ---- flying shell pieces
      final q = _cl(tp / 0.9);
      for (var i = 0; i < 7; i++) {
        final a = i / 7 * math.pi * 2 + 0.3;
        final d = Offset(math.cos(a), math.sin(a));
        final pos = hc + d * (ew * 0.2 + ew * 1.1 * q) + Offset(0, ew * 1.6 * q * q);
        final sz = ew * (0.06 + 0.02 * (i % 3));
        canvas.save();
        canvas.translate(pos.dx, pos.dy);
        canvas.rotate(a + q * 6);
        final shard = Path()..moveTo(-sz, sz * 0.7)..lineTo(sz * 1.1, 0)..lineTo(-sz * 0.4, -sz)..close();
        canvas.drawPath(shard, Paint()..color = _eggFill.withValues(alpha: 1 - q));
        canvas.drawPath(shard, Paint()..style = PaintingStyle.stroke..strokeWidth = 2.2..color = _ink.withValues(alpha: 1 - q));
        canvas.restore();
      }
    }

    canvas.drawPath(egg, line..strokeWidth = 3.5);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_EggPainter old) => old.t != t;
}
