import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle, HapticFeedback;
import 'package:shared_preferences/shared_preferences.dart';
import 'body.dart';
import 'common.dart';

const exCats = <String>[
  'Military Calisthenics',
  'Deep Core Foundation',
  'Yoga',
  'Strength & Core',
  'Mobility & Posture',
  'Cardio',
  'Mind & Breath',
];
const exLevels = <String>['Beginner', 'Moderate', 'Advanced'];

class Exercise {
  final String id, name, equipment, dose, forWho, tip, emph;
  final int cat, level, seconds;
  final List<String> steps;
  Exercise.fromJson(Map<String, dynamic> j)
      : id = j['id'] as String,
        name = j['name'] as String,
        cat = j['cat'] as int,
        level = j['level'] as int,
        equipment = j['equipment'] as String,
        dose = j['dose'] as String,
        seconds = (j['seconds'] ?? 0) as int,
        forWho = (j['for'] ?? 'all') as String,
        tip = (j['tip'] ?? '') as String,
        emph = (j['emph'] ?? 'full') as String,
        steps = List<String>.from(j['steps'] as List);
}

Future<List<Exercise>> loadExercises() async {
  final raw = await rootBundle.loadString('assets/exercises.json');
  return (jsonDecode(raw) as List)
      .map((e) => Exercise.fromJson(Map<String, dynamic>.from(e as Map)))
      .toList();
}

/// Container with two sub-tabs: Workouts and Body.
class FitnessPage extends StatelessWidget {
  final SharedPreferences prefs;
  final String? sex;
  final Future<void> Function(String) onSex;
  const FitnessPage({super.key, required this.prefs, required this.sex, required this.onSex});
  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Column(children: [
        const TabBar(tabs: [Tab(text: 'Workouts'), Tab(text: 'Body')]),
        Expanded(
          child: TabBarView(children: [
            ExercisePage(prefs: prefs, sex: sex, onSex: onSex),
            BodyPage(prefs: prefs, sex: sex),
          ]),
        ),
      ]),
    );
  }
}

class ExercisePage extends StatefulWidget {
  final SharedPreferences prefs;
  final String? sex;
  final Future<void> Function(String) onSex;
  const ExercisePage({super.key, required this.prefs, required this.sex, required this.onSex});
  @override
  State<ExercisePage> createState() => _ExercisePageState();
}

class _ExercisePageState extends State<ExercisePage> {
  final _rng = Random();
  List<Exercise>? all;
  Set<int> cats = {0, 1, 2, 3, 4, 5, 6};
  int level = 0;
  List<String> session = [];
  Set<String> done = {};
  String get _today => dayKey(DateTime.now());

  @override
  void initState() {
    super.initState();
    final p = widget.prefs;
    final savedCats = p.getStringList('ex_cats');
    if (savedCats != null) {
      final s = savedCats.map((e) => int.tryParse(e)).whereType<int>().where((i) => i >= 0 && i < exCats.length).toSet();
      if (s.isNotEmpty) cats = s;
    }
    level = (p.getInt('ex_level') ?? 0).clamp(0, 2);
    session = p.getStringList('ex_session_$_today') ?? [];
    done = (p.getStringList('ex_done_$_today') ?? <String>[]).toSet();
    loadExercises().then((l) {
      if (mounted) setState(() => all = l);
    });
  }

  List<Exercise> _eligible() {
    final sex = widget.sex;
    return all!.where((e) => cats.contains(e.cat) && e.level <= level && (e.forWho == 'all' || e.forWho == sex)).toList();
  }

  double _w(Exercise e) {
    final s = widget.sex;
    double w = 1;
    if (s == 'male') {
      if (e.emph == 'upper') w = 2.2;
      if (e.emph == 'core') w = 1.4;
    } else if (s == 'female') {
      if (e.emph == 'lower') w = 2.2;
      if (e.emph == 'core') w = 1.4;
    }
    if (s != null && e.forWho == s) w *= 1.6;
    return w;
  }

  Exercise? _pick(List<Exercise> pool) {
    if (pool.isEmpty) return null;
    final total = pool.fold<double>(0, (a, e) => a + _w(e));
    var r = _rng.nextDouble() * total;
    for (final e in pool) {
      r -= _w(e);
      if (r <= 0) return e;
    }
    return pool.last;
  }

  Future<void> _build() async {
    final pool = _eligible();
    List<Exercise> inCat(Set<int> cs) => pool.where((e) => cs.contains(e.cat)).toList();
    final out = <Exercise>[];
    final warm = _pick(inCat({4}));
    if (warm != null) out.add(warm);
    final main = <Exercise>[];
    final mainPool = inCat({0, 3, 5});
    for (var i = 0; i < 4; i++) {
      final c = _pick(mainPool.where((e) => !main.contains(e)).toList());
      if (c == null) break;
      main.add(c);
    }
    main.sort((a, b) => (a.cat == 5 ? 0 : 1).compareTo(b.cat == 5 ? 0 : 1));
    out.addAll(main);
    final core = _pick(inCat({1}));
    if (core != null) out.add(core);
    final flow = _pick(inCat({2}));
    if (flow != null) out.add(flow);
    final mind = _pick(inCat({6}));
    if (mind != null) out.add(mind);
    setState(() {
      session = out.map((e) => e.id).toList();
      done = {};
    });
    await widget.prefs.setStringList('ex_session_$_today', session);
    await widget.prefs.setStringList('ex_done_$_today', <String>[]);
  }

  Future<void> _toggleDone(String id) async {
    setState(() {
      if (!done.remove(id)) done.add(id);
    });
    await widget.prefs.setStringList('ex_done_$_today', done.toList());
  }

  Future<void> _finish() async {
    final log = widget.prefs.getStringList('ex_log') ?? <String>[];
    if (!log.contains(_today)) log.add(_today);
    await widget.prefs.setStringList('ex_log', log);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Workout logged. Nice work showing up for yourself.')));
    }
  }

  Future<void> _saveFilters() async {
    await widget.prefs.setStringList('ex_cats', (cats.toList()..sort()).map((e) => '$e').toList());
    await widget.prefs.setInt('ex_level', level);
  }

  void _open(Exercise e) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: SingleChildScrollView(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(e.name, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text('${exCats[e.cat]}  •  ${exLevels[e.level]}', style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 12),
            Text('Dose: ${e.dose}', style: const TextStyle(fontWeight: FontWeight.w600)),
            Text('You need: ${e.equipment}'),
            const SizedBox(height: 12),
            ...List<Widget>.generate(e.steps.length, (i) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text('${i + 1}. ${e.steps[i]}'),
                )),
            if (e.tip.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('Tip: ${e.tip}', style: const TextStyle(fontStyle: FontStyle.italic)),
            ],
            if (e.seconds > 0) ...[
              const SizedBox(height: 14),
              FilledButton.icon(
                onPressed: () {
                  Navigator.pop(ctx);
                  showDialog<void>(context: context, builder: (_) => _TimerDialog(title: e.name, seconds: e.seconds));
                },
                icon: const Icon(Icons.timer_outlined),
                label: Text('Start ${e.seconds}-second timer'),
              ),
            ],
          ]),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final list = all;
    if (list == null) return const Center(child: CircularProgressIndicator());
    if (widget.sex == null) {
      return ListView(padding: const EdgeInsets.all(18), children: [
        const Text('Choose your body type', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        const Text('Exercises, including the Deep Core Foundation routines, are tailored to the male or female body. Choose one to continue.'),
        const SizedBox(height: 16),
        FilledButton.icon(onPressed: () => widget.onSex('male'), icon: const Icon(Icons.person_outline), label: const Text('Male')),
        const SizedBox(height: 10),
        FilledButton.icon(onPressed: () => widget.onSex('female'), icon: const Icon(Icons.person_outline), label: const Text('Female')),
        const SizedBox(height: 14),
        const Text('Saved on this device only. You can change it any time in Settings.', style: TextStyle(fontSize: 12, color: Colors.grey)),
      ]);
    }
    final byId = {for (final e in list) e.id: e};
    final browse = _eligible()
      ..sort((a, b) {
        final c = a.cat.compareTo(b.cat);
        return c != 0 ? c : a.level.compareTo(b.level);
      });
    final sex = widget.sex;
    final sessionEx = session.map((id) => byId[id]).whereType<Exercise>().toList();
    return ListView(padding: const EdgeInsets.all(18), children: [
      const Text('Workouts', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
      const SizedBox(height: 6),
      const Card(
        elevation: 0,
        color: Color(0xFFFFF7E6),
        child: Padding(
          padding: EdgeInsets.all(12),
          child: Text('General fitness information, not medical advice. Stop if you feel pain, dizziness or unwell. Check with a doctor first if you are pregnant, recovering from injury or have a health condition.', style: TextStyle(fontSize: 12)),
        ),
      ),
      const SizedBox(height: 10),
      Text('Tailored for: ${sex == 'male' ? 'Male' : 'Female'} body. Change in Settings.', style: const TextStyle(color: Colors.grey)),
      const SizedBox(height: 10),
      SegmentedButton<int>(
        segments: List<ButtonSegment<int>>.generate(3, (i) => ButtonSegment<int>(value: i, label: Text(exLevels[i]))),
        selected: {level},
        onSelectionChanged: (s) async {
          setState(() => level = s.first);
          await _saveFilters();
        },
      ),
      const SizedBox(height: 4),
      const Text('Shows exercises up to this level.', style: TextStyle(fontSize: 12, color: Colors.grey)),
      const SizedBox(height: 8),
      Wrap(spacing: 8, runSpacing: 4, children: List<Widget>.generate(exCats.length, (i) => FilterChip(
        label: Text(exCats[i]),
        selected: cats.contains(i),
        onSelected: (v) async {
          setState(() {
            if (v) {
              cats.add(i);
            } else if (cats.length > 1) {
              cats.remove(i);
            }
          });
          await _saveFilters();
        },
      ))),
      const SizedBox(height: 14),
      FilledButton.icon(onPressed: _build, icon: const Icon(Icons.auto_awesome), label: const Text("Build today's workout")),
      if (sessionEx.isNotEmpty) ...[
        const SizedBox(height: 14),
        const Text("Today's session", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        ...sessionEx.map((e) => Card(
              child: CheckboxListTile(
                value: done.contains(e.id),
                onChanged: (_) => _toggleDone(e.id),
                controlAffinity: ListTileControlAffinity.leading,
                title: Text(e.name),
                subtitle: Text(e.dose),
                secondary: IconButton(icon: const Icon(Icons.info_outline), onPressed: () => _open(e)),
              ),
            )),
        OutlinedButton.icon(onPressed: _finish, icon: const Icon(Icons.flag_outlined), label: Text('Finish workout (${done.length}/${sessionEx.length} done)')),
      ],
      const SizedBox(height: 18),
      Text('Browse (${browse.length})', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      ...browse.map((e) => ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(e.name),
            subtitle: Text('${exCats[e.cat]}  •  ${exLevels[e.level]}  •  ${e.dose}'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _open(e),
          )),
    ]);
  }
}

class _TimerDialog extends StatefulWidget {
  final String title;
  final int seconds;
  const _TimerDialog({required this.title, required this.seconds});
  @override
  State<_TimerDialog> createState() => _TimerDialogState();
}

class _TimerDialogState extends State<_TimerDialog> {
  late int left;
  Timer? t;
  bool running = false;
  @override
  void initState() {
    super.initState();
    left = widget.seconds;
  }

  void _start() {
    t?.cancel();
    setState(() {
      left = widget.seconds;
      running = true;
    });
    t = Timer.periodic(const Duration(seconds: 1), (x) {
      if (left <= 1) {
        x.cancel();
        HapticFeedback.heavyImpact();
        setState(() {
          left = 0;
          running = false;
        });
      } else {
        setState(() => left--);
      }
    });
  }

  @override
  void dispose() {
    t?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: Text(left == 0 ? 'Done!' : '$left s', textAlign: TextAlign.center, style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
        FilledButton(onPressed: _start, child: Text(running ? 'Restart' : 'Start')),
      ],
    );
  }
}
