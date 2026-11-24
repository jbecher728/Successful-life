import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

const _torso = 24.0, _headOff = 8.0, _headR = 5.0, _ua = 12.0, _fa = 12.0, _th = 19.0, _sh = 19.0;

class Motion {
  final List<String> frames;
  final int ms;
  final String anchor;
  final double ax;
  final List<List<double>> props;
  Motion(this.frames, this.ms, this.anchor, this.ax, this.props);
}

class MotionLib {
  final double w, h, gy;
  final Map<String, Map<String, double>> poses;
  final Map<String, Motion> motions;
  MotionLib(this.w, this.h, this.gy, this.poses, this.motions);

  static Future<MotionLib>? _future;
  static Future<MotionLib> load() => _future ??= _load();

  static Future<MotionLib> _load() async {
    final j = jsonDecode(await rootBundle.loadString('assets/motions.json')) as Map<String, dynamic>;
    final c = (j['canvas'] as List).map((e) => (e as num).toDouble()).toList();
    final poses = <String, Map<String, double>>{};
    (j['poses'] as Map<String, dynamic>).forEach((k, v) {
      poses[k] = (v as Map<String, dynamic>).map((a, b) => MapEntry(a, (b as num).toDouble()));
    });
    final motions = <String, Motion>{};
    (j['motions'] as Map<String, dynamic>).forEach((k, v) {
      final m = v as Map<String, dynamic>;
      motions[k] = Motion(
        List<String>.from(m['frames'] as List),
        (m['ms'] as num).toInt(),
        m['anchor'] as String,
        (m['ax'] as num).toDouble(),
        (m['props'] as List).map((s) => (s as List).map((e) => (e as num).toDouble()).toList()).toList(),
      );
    });
    return MotionLib(c[0], c[1], c[2], poses, motions);
  }
}

Offset _vd(double a) {
  final r = a * pi / 180;
  return Offset(sin(r), cos(r));
}

Offset _vu(double a) {
  final r = a * pi / 180;
  return Offset(sin(r), -cos(r));
}

Map<String, Offset> _fk(Map<String, double> p) {
  const hip = Offset.zero;
  final neck = _vu(p['t']!) * _torso;
  final head = neck + _vu(p['h']!) * _headOff;
  final elA = neck + _vd(p['a1']!) * _ua;
  final haA = elA + _vd(p['a2']!) * _fa;
  final elB = neck + _vd(p['b1']!) * _ua;
  final haB = elB + _vd(p['b2']!) * _fa;
  final knA = hip + _vd(p['l1']!) * _th;
  final anA = knA + _vd(p['l2']!) * _sh;
  final knB = hip + _vd(p['m1']!) * _th;
  final anB = knB + _vd(p['m2']!) * _sh;
  return {'hip': hip, 'neck': neck, 'head': head, 'elA': elA, 'haA': haA, 'elB': elB, 'haB': haB, 'knA': knA, 'anA': anA, 'knB': knB, 'anB': anB};
}

const _anchorJoint = {'ankle': 'anA', 'ankle2': 'anB', 'hand': 'haA', 'hip': 'hip', 'head': 'head', 'neck': 'neck'};

class _FigurePainter extends CustomPainter {
  final MotionLib lib;
  final Motion motion;
  final double t;
  final Color color;
  _FigurePainter(this.lib, this.motion, this.t, this.color);

  Map<String, double> _pose() {
    final n = motion.frames.length;
    if (n == 1) return lib.poses[motion.frames[0]]!;
    final seg = t * n;
    final i = seg.floor() % n;
    final f = seg - seg.floor();
    var e = ((f - 0.15) / 0.7).clamp(0.0, 1.0);
    e = e * e * (3 - 2 * e);
    final a = lib.poses[motion.frames[i]]!;
    final b = lib.poses[motion.frames[(i + 1) % n]]!;
    return {for (final k in a.keys) k: a[k]! + (b[k]! - a[k]!) * e};
  }

  @override
  void paint(Canvas canvas, Size size) {
    final p = _pose();
    final j = _fk(p);
    var maxY = -1e9;
    for (final v in j.values) {
      if (v.dy > maxY) maxY = v.dy;
    }
    maxY = max(maxY, j['head']!.dy + _headR);
    final dy = lib.gy - p['lift']! - maxY;
    final dx = motion.ax - j[_anchorJoint[motion.anchor]!]!.dx;
    final scale = min(size.width / lib.w, size.height / lib.h);
    final ox = (size.width - lib.w * scale) / 2;
    final oy = (size.height - lib.h * scale) / 2;
    Offset m(Offset o) => Offset(ox + (o.dx + dx) * scale, oy + (o.dy + dy) * scale);
    Offset g(double x, double y) => Offset(ox + x * scale, oy + y * scale);

    final ground = Paint()
      ..color = const Color(0xFFBBBBBB)
      ..strokeWidth = 2;
    canvas.drawLine(g(0, lib.gy), g(lib.w, lib.gy), ground);
    final prop = Paint()
      ..color = const Color(0xFF9AA0A6)
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    for (final s in motion.props) {
      canvas.drawLine(g(s[0], s[1]), g(s[2], s[3]), prop);
    }
    final w = max(3.0, 3.2 * scale);
    final back = Paint()
      ..color = Color.lerp(color, Colors.white, 0.55)!
      ..strokeWidth = w
      ..strokeCap = StrokeCap.round;
    final front = Paint()
      ..color = color
      ..strokeWidth = w
      ..strokeCap = StrokeCap.round;
    void seg(String a, String b, Paint pt) => canvas.drawLine(m(j[a]!), m(j[b]!), pt);
    seg('hip', 'knB', back);
    seg('knB', 'anB', back);
    seg('neck', 'elB', back);
    seg('elB', 'haB', back);
    seg('hip', 'neck', front);
    seg('hip', 'knA', front);
    seg('knA', 'anA', front);
    seg('neck', 'elA', front);
    seg('elA', 'haA', front);
    canvas.drawCircle(m(j['head']!), _headR * scale, Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = w);
  }

  @override
  bool shouldRepaint(covariant _FigurePainter old) => old.t != t || old.motion != motion;
}

/// Looping stick-figure animation of an exercise (side or front view).
class ExerciseFigure extends StatefulWidget {
  final String motion;
  const ExerciseFigure({super.key, required this.motion});
  @override
  State<ExerciseFigure> createState() => _ExerciseFigureState();
}

class _ExerciseFigureState extends State<ExerciseFigure> with SingleTickerProviderStateMixin {
  late final AnimationController c;
  MotionLib? lib;

  @override
  void initState() {
    super.initState();
    c = AnimationController(vsync: this, duration: const Duration(milliseconds: 2000));
    MotionLib.load().then((l) {
      if (!mounted) return;
      final m = l.motions[widget.motion];
      if (m != null) {
        c.duration = Duration(milliseconds: m.ms);
        if (m.frames.length > 1) c.repeat();
      }
      setState(() => lib = l);
    });
  }

  @override
  void dispose() {
    c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = lib;
    final m = l?.motions[widget.motion];
    return Container(
      height: 190,
      width: double.infinity,
      decoration: BoxDecoration(color: const Color(0xFFF1F6F4), borderRadius: BorderRadius.circular(14)),
      child: (l == null || m == null)
          ? const SizedBox.shrink()
          : RepaintBoundary(
              child: AnimatedBuilder(
                animation: c,
                builder: (context, _) => CustomPaint(
                  size: Size.infinite,
                  painter: _FigurePainter(l, m, c.value, Theme.of(context).colorScheme.primary),
                ),
              ),
            ),
    );
  }
}
