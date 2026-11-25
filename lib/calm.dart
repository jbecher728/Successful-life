import 'dart:async';
import 'package:flutter/material.dart';
import 'common.dart';
import 'store.dart';

/// A gentle guided breathing timer: inhale 4 seconds, exhale 6 seconds.
class CalmPage extends StatefulWidget {
  final Store? prefs;
  const CalmPage({super.key, this.prefs});
  @override
  State<CalmPage> createState() => _CalmPageState();
}

class _CalmPageState extends State<CalmPage> with SingleTickerProviderStateMixin {
  late final AnimationController _a = AnimationController(vsync: this, duration: const Duration(seconds: 10));
  Timer? _t;
  int total = 60, left = 60;
  bool running = false, finished = false;

  @override
  void dispose() {
    _t?.cancel();
    _a.dispose();
    super.dispose();
  }

  void _start() {
    setState(() {
      running = true;
      finished = false;
      left = total;
    });
    _a.repeat();
    _t = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      setState(() => left--);
      if (left <= 0) _stop(done: true);
    });
  }

  Future<void> _stop({bool done = false}) async {
    _t?.cancel();
    _a.stop();
    setState(() {
      running = false;
      finished = done;
    });
    if (done && widget.prefs != null) {
      final l = widget.prefs!.getStringList('calm_log') ?? <String>[];
      l.add(dayKey(DateTime.now()));
      await widget.prefs!.setStringList('calm_log', l);
    }
  }

  // 0..0.4 inhale (grow), 0.4..1 exhale (shrink)
  double get _scale {
    final v = _a.value;
    return v < 0.4 ? 0.55 + 0.45 * (v / 0.4) : 1.0 - 0.45 * ((v - 0.4) / 0.6);
  }

  String get _word => _a.value < 0.4 ? 'Breathe in' : 'Breathe out';

  @override
  Widget build(BuildContext context) {
    return ListView(padding: const EdgeInsets.all(18), children: [
      const Text('Calm', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
      const SizedBox(height: 4),
      const Text('A short pause to slow down. Breathe in for 4, out for 6.'),
      const SizedBox(height: 16),
      Center(
        child: SizedBox(
          height: 260,
          child: AnimatedBuilder(
            animation: _a,
            builder: (_, __) => Stack(alignment: Alignment.center, children: [
              Container(
                width: 240 * (running ? _scale : 0.7),
                height: 240 * (running ? _scale : 0.7),
                decoration: BoxDecoration(shape: BoxShape.circle, color: const Color(0xFF21877C).withValues(alpha: 0.18), border: Border.all(color: const Color(0xFF21877C), width: 3)),
              ),
              Column(mainAxisSize: MainAxisSize.min, children: [
                Text(running ? _word : (finished ? 'Well done' : 'Ready?'), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600)),
                if (running) Text('${left ~/ 60}:${(left % 60).toString().padLeft(2, '0')}', style: const TextStyle(color: Colors.grey)),
              ]),
            ]),
          ),
        ),
      ),
      if (!running) ...[
        Wrap(alignment: WrapAlignment.center, spacing: 8, children: [
          for (final m in [1, 2, 5]) ChoiceChip(label: Text('$m min'), selected: total == m * 60, onSelected: (_) => setState(() => total = m * 60)),
        ]),
        const SizedBox(height: 12),
        FilledButton.icon(onPressed: _start, icon: const Icon(Icons.self_improvement), label: Text(finished ? 'Again' : 'Begin')),
      ] else
        OutlinedButton(onPressed: () => _stop(), child: const Text('Stop')),
      if (finished) const Padding(padding: EdgeInsets.only(top: 14), child: Text('Notice how you feel now compared with a minute ago.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey))),
    ]);
  }
}

/// Opens the calm timer as its own page.
Future<void> openCalm(BuildContext context, Store? p) => Navigator.push(context, MaterialPageRoute(builder: (_) => Scaffold(appBar: AppBar(title: const Text('Calm')), body: CalmPage(prefs: p))));
