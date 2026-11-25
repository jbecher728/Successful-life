import 'dart:math';
import 'package:flutter/material.dart';
import 'calm.dart';
import 'common.dart';
import 'planner.dart';
import 'store.dart';

const _kind = [
  'You do not have to be at your best today. Showing up gently still counts.',
  'This feeling is real, and it will change. You have gotten through hard days before.',
  'Rest is not quitting. It is part of getting stronger.',
  'Be as kind to yourself as you would be to a good friend.',
  'One small thing is enough today.',
  'Hard days do not erase your progress.',
];

/// A softer version of the day for when things feel heavy.
class RoughDayPage extends StatefulWidget {
  final Store prefs;
  final Future<void> Function() onChanged;
  const RoughDayPage({super.key, required this.prefs, required this.onChanged});
  @override
  State<RoughDayPage> createState() => _RoughDayPageState();
}

class _RoughDayPageState extends State<RoughDayPage> {
  late final String line = _kind[Random().nextInt(_kind.length)];

  Future<void> _lighten() async {
    final t = DateTime.now();
    final today = DateTime(t.year, t.month, t.day);
    final goals = loadGoals(widget.prefs);
    final movable = goals.where((g) => !g.repeats && !g.done && g.imp < 8 && !DateTime.parse(g.start).isAfter(today) && (g.due.isEmpty || !DateTime.parse(g.due).isBefore(today))).toList();
    if (movable.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Nothing to move. Your list is already light.')));
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Lighten today?'),
        content: Text('Move ${movable.length} lower-priority ${movable.length == 1 ? 'goal' : 'goals'} to tomorrow? Top priorities stay.'),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Not now')), FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Move them'))],
      ),
    );
    if (ok != true) return;
    final tomorrow = DateTime(today.year, today.month, today.day + 1);
    for (final g in movable) {
      final hadSpan = g.due.isNotEmpty && g.due != g.start;
      if (!hadSpan) {
        g.start = dayKey(tomorrow);
        if (g.due.isNotEmpty) g.due = dayKey(tomorrow);
      } else {
        // keep long goals as they are; just skip pressure today
        continue;
      }
    }
    await saveGoals(widget.prefs, goals);
    await widget.onChanged();
    if (mounted) {
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Done. Tomorrow will hold them.')));
    }
  }

  Widget _step(IconData i, String t, String s, VoidCallback f) => Card(elevation: 0, child: ListTile(leading: Icon(i, color: const Color(0xFF21877C)), title: Text(t, style: const TextStyle(fontWeight: FontWeight.w600)), subtitle: Text(s), onTap: f));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('A gentler day')),
      body: ListView(padding: const EdgeInsets.all(18), children: [
        Text(line, style: const TextStyle(fontSize: 20, fontStyle: FontStyle.italic, height: 1.4)),
        const SizedBox(height: 14),
        const Text('Today, the plan is smaller. Pick whatever feels possible:'),
        const SizedBox(height: 8),
        _step(Icons.self_improvement, 'Breathe for a minute', 'A short guided pause.', () => openCalm(context, widget.prefs)),
        _step(Icons.water_drop_outlined, 'Do one basic thing', 'Drink water, eat something, step outside or stretch.', () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pick just one. That is enough.')))),
        _step(Icons.swap_horiz, 'Lighten my day', 'Move lower-priority goals to tomorrow.', _lighten),
        _step(Icons.chat_bubble_outline, 'Reach out to someone', 'Send one friend a simple “thinking of you.” You do not have to explain.', () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('A short text is plenty.')))),
        const SizedBox(height: 14),
        Card(
          elevation: 0,
          color: const Color(0xFFFFF3E8),
          child: const Padding(
            padding: EdgeInsets.all(14),
            child: Text('If you feel unsafe or are thinking about hurting yourself, please reach out right now. In the US you can call or text 988. Elsewhere, findahelpline.com lists free lines by country. In an emergency, call your local emergency number.', style: TextStyle(height: 1.4)),
          ),
        ),
      ]),
    );
  }
}
