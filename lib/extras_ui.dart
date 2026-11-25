import 'dart:convert';
import 'package:flutter/material.dart';
import 'common.dart';
import 'planner.dart';
import 'review.dart';
import 'store.dart';
import 'theme.dart';

/// Settings > Extras: every extra can be switched off, plus appearance.
class ExtrasPanel extends StatefulWidget {
  final Store prefs;
  final Future<void> Function() onChanged;
  const ExtrasPanel({super.key, required this.prefs, required this.onChanged});
  @override
  State<ExtrasPanel> createState() => _ExtrasPanelState();
}

class _ExtrasPanelState extends State<ExtrasPanel> {
  static const items = <(String, String, String)>[
    ('review', 'Weekly review', 'A Sunday reminder and a weekly summary card'),
    ('backup', 'Backup reminder', 'A gentle monthly nudge to export your data'),
    ('identity', '“I am becoming…” line', 'One line shown at the top of Today'),
    ('prompt', 'Journal prompt of the day', 'A fresh question in the Journal'),
    ('letters', 'Letters to future me', 'Write to yourself and get them back later'),
    ('rough', 'Rough-day mode', 'A gentler plan for hard days'),
    ('calm', 'Calm timer', 'One-minute breathing under Fitness'),
    ('egg', 'Hatching egg', 'Shows your progress as an egg that slowly cracks'),
    ('mood', 'Mood patterns', 'Shows what goes with your better days'),
  ];

  Future<void> _flip(String k, bool v) async {
    await widget.prefs.setBool('x_$k', v);
    setState(() {});
    await widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.prefs;
    final mode = p.getString('theme_mode') ?? 'system';
    final scale = p.getDouble('text_scale') ?? 1.0;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Appearance', style: TextStyle(fontWeight: FontWeight.bold)),
      const SizedBox(height: 8),
      SegmentedButton<String>(
        segments: const [ButtonSegment(value: 'system', label: Text('Auto')), ButtonSegment(value: 'light', label: Text('Light')), ButtonSegment(value: 'dark', label: Text('Dark'))],
        selected: {mode},
        onSelectionChanged: (s) async {
          await p.setString('theme_mode', s.first);
          applyLook(p);
          setState(() {});
        },
      ),
      const SizedBox(height: 10),
      SegmentedButton<double>(
        segments: const [ButtonSegment(value: 1.0, label: Text('Normal')), ButtonSegment(value: 1.2, label: Text('Large')), ButtonSegment(value: 1.4, label: Text('Larger'))],
        selected: {[1.0, 1.2, 1.4].reduce((a, b) => (a - scale).abs() < (b - scale).abs() ? a : b)},
        onSelectionChanged: (s) async {
          await p.setDouble('text_scale', s.first);
          applyLook(p);
          setState(() {});
        },
      ),
      const SizedBox(height: 4),
      const Text('Text size', style: TextStyle(fontSize: 12, color: Colors.grey)),
      const Divider(height: 24),
      const Text('Extras (turn off anything you do not want)', style: TextStyle(fontWeight: FontWeight.bold)),
      for (final i in items) SwitchListTile(contentPadding: EdgeInsets.zero, title: Text(i.$2), subtitle: Text(i.$3), value: extraOn(p, i.$1), onChanged: (v) => _flip(i.$1, v)),
    ]);
  }
}

// ------------------------------------------------------------------ progress widgets

Set<String> _showUpDays(Store p) {
  final s = <String>{...(p.getStringList('ex_log') ?? <String>[])};
  try {
    final e = jsonDecode(p.getString('entries') ?? '{}') as Map;
    e.forEach((k, v) {
      if (v is Map && (v['completed'] == true || '${v['journal'] ?? ''}'.trim().isNotEmpty || v['mood'] != null)) s.add('$k');
    });
  } catch (_) {}
  for (final g in loadGoals(p)) {
    s.addAll(g.dones);
    s.addAll(g.worked);
    if (g.done && g.doneOn.isNotEmpty) s.add(g.doneOn);
  }
  s.addAll(p.getStringList('calm_log') ?? <String>[]);
  return s;
}

class HatchingEgg extends StatelessWidget {
  final Store prefs;
  const HatchingEgg({super.key, required this.prefs});

  static const marks = [1, 3, 7, 14, 21, 30, 45, 60, 90];

  @override
  Widget build(BuildContext context) {
    final n = _showUpDays(prefs).length;
    final stage = marks.where((m) => n >= m).length; // 0..9
    final next = marks.firstWhere((m) => m > n, orElse: () => 0);
    return Card(
      elevation: 0,
      color: cardBg(context),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(children: [
          SizedBox(height: 150, width: 150, child: CustomPaint(painter: _EggPainter(stage, isDark(context)))),
          const SizedBox(height: 8),
          Text('$n ${n == 1 ? 'day' : 'days'} showing up', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(next == 0 ? 'The shell is open. Look at what you built.' : 'The shell cracks a little more at $next days. Missed days never undo it.', textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey)),
        ]),
      ),
    );
  }
}

class _EggPainter extends CustomPainter {
  final int stage;
  final bool dark;
  _EggPainter(this.stage, this.dark);

  @override
  void paint(Canvas c, Size s) {
    final w = s.width, h = s.height;
    Offset o(double x, double y) => Offset(x * w, y * h);
    final egg = Path()
      ..moveTo(0.5 * w, 0.04 * h)
      ..cubicTo(0.88 * w, 0.04 * h, 0.94 * w, 0.62 * h, 0.5 * w, 0.96 * h)
      ..cubicTo(0.06 * w, 0.62 * h, 0.12 * w, 0.04 * h, 0.5 * w, 0.04 * h)
      ..close();
    c.drawPath(egg, Paint()..color = dark ? const Color(0xFFE9DCC3) : const Color(0xFFF3E6CD));
    c.drawPath(egg, Paint()..style = PaintingStyle.stroke..strokeWidth = 3..color = const Color(0xFF21877C));
    if (stage >= 6) {
      // the fist pushing out at the top right
      final fist = RRect.fromRectAndRadius(Rect.fromCenter(center: o(0.68, 0.2), width: 0.26 * w, height: 0.22 * h), const Radius.circular(10));
      c.save();
      c.translate(o(0.68, 0.2).dx, o(0.68, 0.2).dy);
      c.rotate(0.5);
      c.translate(-o(0.68, 0.2).dx, -o(0.68, 0.2).dy);
      c.drawRRect(fist, Paint()..color = const Color(0xFFE0A66B));
      c.drawRRect(fist, Paint()..style = PaintingStyle.stroke..strokeWidth = 2..color = const Color(0xFF8A5A2B));
      c.restore();
    }
    final crack = Paint()..style = PaintingStyle.stroke..strokeWidth = 2.4..strokeCap = StrokeCap.round..strokeJoin = StrokeJoin.round..color = const Color(0xFF5B4A33);
    final lines = <List<Offset>>[
      [o(0.5, 0.5), o(0.44, 0.58), o(0.52, 0.64)],
      [o(0.5, 0.5), o(0.58, 0.42), o(0.54, 0.34)],
      [o(0.52, 0.64), o(0.46, 0.74), o(0.5, 0.82)],
      [o(0.58, 0.42), o(0.7, 0.46), o(0.76, 0.4)],
      [o(0.44, 0.58), o(0.32, 0.56), o(0.26, 0.64)],
      [o(0.54, 0.34), o(0.5, 0.24), o(0.56, 0.16)],
    ];
    final show = stage.clamp(0, 9);
    final count = show <= 0 ? 0 : (show * lines.length / 9).ceil().clamp(1, lines.length);
    for (var i = 0; i < count; i++) {
      final l = lines[i];
      c.drawPath(Path()..moveTo(l[0].dx, l[0].dy)..lineTo(l[1].dx, l[1].dy)..lineTo(l[2].dx, l[2].dy), crack);
    }
  }

  @override
  bool shouldRepaint(_EggPainter o) => o.stage != stage || o.dark != dark;
}

/// What tends to go with better days. Shown once there is enough data.
class MoodPatterns extends StatelessWidget {
  final Store prefs;
  const MoodPatterns({super.key, required this.prefs});

  @override
  Widget build(BuildContext context) {
    Map e = {};
    try {
      e = jsonDecode(prefs.getString('entries') ?? '{}') as Map;
    } catch (_) {}
    final moods = <String, int>{};
    final energies = <String, int>{};
    e.forEach((k, v) {
      if (v is Map && v['mood'] is num && (v['mood'] as num) > 0) moods['$k'] = (v['mood'] as num).toInt();
      if (v is Map && v['energy'] is num && (v['energy'] as num) > 0) energies['$k'] = (v['energy'] as num).toInt();
    });
    Widget shell(Widget child) => Card(elevation: 0, color: cardBg(context), child: Padding(padding: const EdgeInsets.all(18), child: child));
    if (moods.length < 7) {
      return shell(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('MOOD PATTERNS', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF21877C))),
        const SizedBox(height: 6),
        Text('Log your mood on 7 different days to see patterns. ${moods.length} so far.', style: const TextStyle(height: 1.4)),
      ]));
    }
    final workouts = (prefs.getStringList('ex_log') ?? <String>[]).toSet();
    final goalDays = <String>{};
    for (final g in loadGoals(prefs)) {
      goalDays.addAll(g.dones);
      if (g.done && g.doneOn.isNotEmpty) goalDays.add(g.doneOn);
    }
    final lines = <String>[];
    void compare(String label, Set<String> days, Map<String, int> data, String what) {
      final a = <int>[], b = <int>[];
      data.forEach((k, v) => (days.contains(k) ? a : b).add(v));
      if (a.length >= 3 && b.length >= 3) {
        final x = a.reduce((p, q) => p + q) / a.length, y = b.reduce((p, q) => p + q) / b.length;
        if ((x - y).abs() >= 0.2) {
          lines.add('$what is ${x > y ? 'higher' : 'lower'} on $label (${x.toStringAsFixed(1)} vs ${y.toStringAsFixed(1)}).');
        }
      }
    }
    compare('workout days', workouts, moods, 'Your mood');
    compare('workout days', workouts, energies, 'Your energy');
    compare('days you checked off goals', goalDays, moods, 'Your mood');
    final avg = moods.values.reduce((a, b) => a + b) / moods.length;
    return shell(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('MOOD PATTERNS', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF21877C))),
      const SizedBox(height: 6),
      Text('Average mood: ${avg.toStringAsFixed(1)} of 5 across ${moods.length} days.', style: const TextStyle(height: 1.4)),
      for (final l in lines) Padding(padding: const EdgeInsets.only(top: 6), child: Text(l, style: const TextStyle(height: 1.4))),
      if (lines.isEmpty) const Padding(padding: EdgeInsets.only(top: 6), child: Text('No clear pattern yet. Keep logging.', style: TextStyle(color: Colors.grey))),
      const SizedBox(height: 8),
      const Text('These are patterns, not causes.', style: TextStyle(fontSize: 12, color: Colors.grey)),
    ]));
  }
}
