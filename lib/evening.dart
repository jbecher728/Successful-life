import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'questions_data.dart';
import 'store.dart';
import 'theme.dart';

/// A guided evening: three sets (Light, Deeper, Honest) of a few questions each,
/// then an optional quiet pause. The person can stop after any set.
class EveningPage extends StatefulWidget {
  final Store prefs;
  const EveningPage({super.key, required this.prefs});
  @override
  State<EveningPage> createState() => _EveningPageState();
}

class _EveningPageState extends State<EveningPage> {
  // 0 intro, 1 asking, 2 between sets, 3 quiet pause, 4 done
  int stage = 0;
  int perSet = 4, pauseMin = 2, setIdx = 0, n = 1, cur = 0, remain = 0;
  Timer? _t;

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  QLevel get lvl => qLevels[setIdx];

  Future<void> _begin() async {
    setIdx = 0;
    n = 1;
    final i = await drawQuestion(widget.prefs, lvl.id);
    if (!mounted) return;
    setState(() {
      cur = i;
      stage = 1;
    });
  }

  Future<void> _swap() async {
    final i = await drawQuestion(widget.prefs, lvl.id, avoid: cur);
    if (mounted) setState(() => cur = i);
  }

  Future<void> _next() async {
    if (n < perSet) {
      final i = await drawQuestion(widget.prefs, lvl.id, avoid: cur);
      if (!mounted) return;
      setState(() {
        n++;
        cur = i;
      });
    } else if (setIdx < 2) {
      setState(() => stage = 2);
    } else {
      await _finishSets();
    }
  }

  Future<void> _deeper() async {
    setIdx++;
    n = 1;
    final i = await drawQuestion(widget.prefs, lvl.id);
    if (!mounted) return;
    setState(() {
      cur = i;
      stage = 1;
    });
  }

  Future<void> _finishSets() async {
    if (pauseMin > 0) {
      _t?.cancel();
      setState(() {
        stage = 3;
        remain = pauseMin * 60;
      });
      _t = Timer.periodic(const Duration(seconds: 1), (t) {
        if (!mounted) return;
        setState(() => remain--);
        if (remain <= 0) {
          t.cancel();
          HapticFeedback.mediumImpact();
          _done();
        }
      });
    } else {
      await _done();
    }
  }

  Future<void> _done() async {
    _t?.cancel();
    await logEvening(widget.prefs);
    if (mounted) setState(() => stage = 4);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Guided evening')),
      body: ListView(padding: const EdgeInsets.all(20), children: _body(context)),
    );
  }

  Widget _bigCard(BuildContext context, Color c, String text) => Card(
        elevation: 0,
        color: tint(context, c.withValues(alpha: 0.14)),
        child: Padding(padding: const EdgeInsets.all(22), child: Text(text, style: const TextStyle(fontSize: 21, height: 1.4, fontWeight: FontWeight.w600))),
      );

  List<Widget> _body(BuildContext context) {
    switch (stage) {
      case 0:
        return [
          const Text('An evening for the two of you', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          const Text('Set aside 30 to 45 minutes with someone close. Put phones away and find a quiet spot. The questions start light and get deeper, and you can stop after any set.'),
          const SizedBox(height: 12),
          const Text('• One person reads the question and answers, then the other answers the same one.\n• Listen without defending or fixing.\n• Skip any question you like.\n• If something feels too heavy, it is fine to stop.', style: TextStyle(height: 1.5)),
          const SizedBox(height: 18),
          const Text('Questions per set', style: TextStyle(fontWeight: FontWeight.w600)),
          Wrap(spacing: 8, children: [
            for (final v in const [3, 4, 6]) ChoiceChip(label: Text('$v'), selected: perSet == v, onSelected: (_) => setState(() => perSet = v)),
          ]),
          const SizedBox(height: 12),
          const Text('Quiet pause at the end', style: TextStyle(fontWeight: FontWeight.w600)),
          Wrap(spacing: 8, children: [
            for (final v in const [0, 1, 2, 4]) ChoiceChip(label: Text(v == 0 ? 'None' : '$v min'), selected: pauseMin == v, onSelected: (_) => setState(() => pauseMin = v)),
          ]),
          const SizedBox(height: 4),
          const Text('A few minutes of looking at each other, saying nothing.', style: TextStyle(fontSize: 12, color: Colors.grey)),
          const SizedBox(height: 22),
          FilledButton.icon(onPressed: _begin, icon: const Icon(Icons.play_arrow), label: const Text('Begin')),
        ];
      case 1:
        return [
          Text('Set ${setIdx + 1} of 3: ${lvl.name}  •  Question $n of $perSet', style: TextStyle(fontWeight: FontWeight.w700, color: lvl.color)),
          const SizedBox(height: 4),
          LinearProgressIndicator(value: (setIdx * perSet + n - 1) / (3 * perSet), minHeight: 6, borderRadius: BorderRadius.circular(6), color: lvl.color),
          const SizedBox(height: 16),
          _bigCard(context, lvl.color, lvl.q[cur]),
          const SizedBox(height: 10),
          const Text('Take turns. Both of you answer this one.', style: TextStyle(color: Colors.grey)),
          const SizedBox(height: 18),
          Row(children: [
            Expanded(child: OutlinedButton.icon(onPressed: _swap, icon: const Icon(Icons.shuffle), label: const Text('Different one'))),
            const SizedBox(width: 12),
            Expanded(child: FilledButton(onPressed: _next, child: Text(n < perSet ? 'Next' : 'Done with set'))),
          ]),
          const SizedBox(height: 8),
          Align(alignment: Alignment.centerLeft, child: TextButton(onPressed: _finishSets, child: const Text('Stop here'))),
        ];
      case 2:
        final nxt = qLevels[setIdx + 1];
        return [
          const Icon(Icons.spa_outlined, size: 40, color: Color(0xFF21877C)),
          const SizedBox(height: 10),
          Text('${lvl.name} set done.', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text('Take a breath. Want to go a little deeper? The next set is ${nxt.name.toLowerCase()}: ${nxt.blurb.toLowerCase()}.'),
          const SizedBox(height: 20),
          FilledButton(onPressed: _deeper, child: Text('Go to the ${nxt.name} set')),
          const SizedBox(height: 8),
          OutlinedButton(onPressed: _finishSets, child: const Text('Finish here')),
        ];
      case 3:
        final m = (remain ~/ 60).toString();
        final s = (remain % 60).toString().padLeft(2, '0');
        return [
          const SizedBox(height: 30),
          const Center(child: Text('Look at each other, quietly.', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold))),
          const SizedBox(height: 12),
          const Center(child: Text('No talking. Just be here together.', style: TextStyle(color: Colors.grey))),
          const SizedBox(height: 30),
          Center(child: Text('$m:$s', style: const TextStyle(fontSize: 54, fontWeight: FontWeight.w300))),
          const SizedBox(height: 30),
          Center(child: TextButton(onPressed: _done, child: const Text('Skip'))),
        ];
      default:
        return [
          const SizedBox(height: 20),
          const Icon(Icons.favorite, size: 44, color: Color(0xFFB4475F)),
          const SizedBox(height: 12),
          const Center(child: Text('Thank you for making the time.', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold), textAlign: TextAlign.center)),
          const SizedBox(height: 10),
          const Text('Small, honest conversations are what keep a relationship close. Nothing from tonight is saved except that it happened.', textAlign: TextAlign.center),
          const SizedBox(height: 24),
          FilledButton(onPressed: () => Navigator.pop(context), child: const Text('Done')),
        ];
    }
  }
}
