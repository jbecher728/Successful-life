import 'theme.dart';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'store.dart';
import 'common.dart';

/// Measurement fields stored in centimeters.
const bodyFields = <List<String>>[
  ['neck', 'Neck'],
  ['shoulders', 'Shoulders (around, widest point)'],
  ['chest', 'Chest / bust'],
  ['waist', 'Waist (at navel)'],
  ['hips', 'Hips (widest point)'],
  ['arm_l', 'Upper arm, left'],
  ['arm_r', 'Upper arm, right'],
  ['thigh_l', 'Thigh, left'],
  ['thigh_r', 'Thigh, right'],
  ['calf', 'Calf'],
];

const _kgPerLb = 0.45359237;
const _cmPerIn = 2.54;

double? _parse(String s) => double.tryParse(s.trim().replaceAll(',', '.'));

class BodyPage extends StatefulWidget {
  final Store prefs;
  final String? sex;
  final bool teen;
  final Future<void> Function(String) onSex;
  const BodyPage({super.key, required this.prefs, required this.sex, required this.teen, required this.onSex});
  @override
  State<BodyPage> createState() => _BodyPageState();
}

class _BodyPageState extends State<BodyPage> {
  bool metric = true;
  double? heightCm;
  List<Map<String, dynamic>> log = [];
  final weightC = TextEditingController();
  final heightC = TextEditingController();
  final feetC = TextEditingController();
  final inchC = TextEditingController();
  final Map<String, TextEditingController> mc = {for (final f in bodyFields) f[0]: TextEditingController()};

  @override
  void initState() {
    super.initState();
    final p = widget.prefs;
    metric = (p.getString('units') ?? 'metric') == 'metric';
    heightCm = p.getDouble('height_cm');
    try {
      log = (jsonDecode(p.getString('body_log') ?? '[]') as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } catch (_) {
      log = [];
    }
    _fillHeight();
  }

  @override
  void dispose() {
    weightC.dispose();
    heightC.dispose();
    feetC.dispose();
    inchC.dispose();
    for (final c in mc.values) {
      c.dispose();
    }
    super.dispose();
  }

  String _wUnit() => metric ? 'kg' : 'lb';
  String _lUnit() => metric ? 'cm' : 'in';
  double _wOut(double kg) => metric ? kg : kg / _kgPerLb;
  double _lOut(double cm) => metric ? cm : cm / _cmPerIn;
  double _wIn(double v) => metric ? v : v * _kgPerLb;
  double _lIn(double v) => metric ? v : v * _cmPerIn;
  String _f(double v) => v.toStringAsFixed(1);

  void _fillHeight() {
    final h = heightCm;
    heightC.text = h == null ? '' : _f(h);
    if (h != null) {
      final totalIn = h / _cmPerIn;
      feetC.text = (totalIn ~/ 12).toString();
      inchC.text = _f(totalIn - (totalIn ~/ 12) * 12);
    } else {
      feetC.text = '';
      inchC.text = '';
    }
  }

  Future<void> _setUnits(bool m) async {
    setState(() {
      metric = m;
      weightC.clear();
      for (final c in mc.values) {
        c.clear();
      }
      _fillHeight();
    });
    await widget.prefs.setString('units', m ? 'metric' : 'imperial');
  }

  Future<void> _saveHeight() async {
    double? cm;
    if (metric) {
      cm = _parse(heightC.text);
    } else {
      final ft = _parse(feetC.text) ?? 0;
      final inch = _parse(inchC.text) ?? 0;
      cm = (ft * 12 + inch) * _cmPerIn;
    }
    if (cm == null || cm < 100 || cm > 250) {
      _msg('Please enter a realistic adult height.');
      return;
    }
    setState(() => heightCm = cm);
    await widget.prefs.setDouble('height_cm', cm);
    _msg('Height saved on this device.');
  }

  void _msg(String t) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t)));
  }

  Future<void> _persist() async {
    log.sort((a, b) => (a['date'] as String).compareTo(b['date'] as String));
    await widget.prefs.setString('body_log', jsonEncode(log));
  }

  Future<void> _saveEntry() async {
    final entry = <String, dynamic>{'date': dayKey(DateTime.now())};
    final w = _parse(weightC.text);
    if (w != null && w > 0) entry['weight_kg'] = double.parse(_wIn(w).toStringAsFixed(2));
    for (final f in bodyFields) {
      final v = _parse(mc[f[0]]!.text);
      if (v != null && v > 0) entry['${f[0]}_cm'] = double.parse(_lIn(v).toStringAsFixed(1));
    }
    if (entry.length == 1) {
      _msg('Enter at least one number to save.');
      return;
    }
    setState(() {
      final i = log.indexWhere((e) => e['date'] == entry['date']);
      if (i >= 0) {
        log[i] = {...log[i], ...entry};
      } else {
        log.add(entry);
      }
    });
    await _persist();
    _msg("Saved today's entry on this device.");
  }

  Future<void> _delete(String date) async {
    setState(() => log.removeWhere((e) => e['date'] == date));
    await _persist();
  }

  double? _latest(String key) {
    for (var i = log.length - 1; i >= 0; i--) {
      final v = log[i][key];
      if (v is num) return v.toDouble();
    }
    return null;
  }

  double? _first(String key) {
    for (final e in log) {
      final v = e[key];
      if (v is num) return v.toDouble();
    }
    return null;
  }

  int _count(String key) => log.where((e) => e[key] is num).length;

  Widget _card(Widget child) => Card(elevation: 0, color: cardBg(context), child: Padding(padding: const EdgeInsets.all(16), child: child));

  Widget _h(String t) => Padding(padding: const EdgeInsets.only(top: 18, bottom: 8), child: Text(t, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)));

  Widget _profile() {
    final w = _latest('weight_kg');
    final h = heightCm;
    final lines = <String>[];
    if (w != null && h != null) {
      final m = h / 100;
      final bmi = w / (m * m);
      final cat = bmi < 18.5 ? 'below the typical range' : bmi < 25 ? 'in the typical range' : bmi < 30 ? 'above the typical range' : 'well above the typical range';
      lines.add('BMI ${_f(bmi)}: $cat for adults.');
    }
    final waist = _latest('waist_cm');
    if (waist != null && h != null) {
      final r = waist / h;
      final cat = r < 0.4 ? 'low' : r < 0.5 ? 'healthy' : r < 0.6 ? 'elevated' : 'high';
      lines.add('Waist-to-height ${r.toStringAsFixed(2)}: $cat. Keeping your waist under half your height is a common guideline.');
    }
    final hips = _latest('hips_cm');
    final sex = widget.sex;
    if (waist != null && hips != null && sex != null) {
      final r = waist / hips;
      final limit = sex == 'male' ? 0.90 : 0.85;
      lines.add('Waist-to-hip ${r.toStringAsFixed(2)}: ${r <= limit ? 'within' : 'above'} the common guideline of ${limit.toStringAsFixed(2)}.');
    }
    final top = _latest('shoulders_cm') ?? _latest('chest_cm');
    if (top != null && hips != null && waist != null) {
      String shape;
      if (top > hips * 1.05) {
        shape = 'Upper-body dominant (broader shoulders or chest than hips)';
      } else if (hips > top * 1.05) {
        shape = 'Lower-body dominant (broader hips than shoulders or chest)';
      } else if (waist / hips < 0.78) {
        shape = 'Balanced with a defined waist';
      } else {
        shape = 'Balanced and straight';
      }
      lines.add('Body shape: $shape.');
    }
    return _card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('YOUR BODY PROFILE', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF21877C))),
      const SizedBox(height: 8),
      if (lines.isEmpty)
        const Text('Add your height and a weigh-in, and measure your waist and hips, to see your profile.')
      else
        ...lines.map((l) => Padding(padding: const EdgeInsets.only(bottom: 6), child: Text(l))),
      const SizedBox(height: 6),
      const Text('These are screening guides, not a diagnosis. BMI does not separate muscle from fat, and body types such as "ectomorph" are not precisely measurable. Use trends over weeks, not single numbers. If tracking numbers makes you anxious, feel free to skip it.', style: TextStyle(fontSize: 12, color: Colors.grey)),
    ]));
  }

  Widget _progress() {
    final rows = <Widget>[];
    void add(String label, String key, bool weight) {
      if (_count(key) < 2) return;
      final a = _first(key)!;
      final b = _latest(key)!;
      final d = weight ? _wOut(b) - _wOut(a) : _lOut(b) - _lOut(a);
      final unit = weight ? _wUnit() : _lUnit();
      rows.add(Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(children: [
          Expanded(child: Text(label)),
          Text('${weight ? _f(_wOut(b)) : _f(_lOut(b))} $unit  (${d >= 0 ? '+' : ''}${_f(d)})'),
        ]),
      ));
    }

    add('Weight', 'weight_kg', true);
    for (final f in bodyFields) {
      add(f[1].split(' (').first, '${f[0]}_cm', false);
    }
    final weights = log.where((e) => e['weight_kg'] is num).map((e) => _wOut((e['weight_kg'] as num).toDouble())).toList();
    return _card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (weights.length >= 2) ...[
        const Text('Weight trend', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        SizedBox(height: 110, width: double.infinity, child: CustomPaint(painter: _LinePainter(weights, const Color(0xFF21877C)))),
        const SizedBox(height: 12),
      ],
      if (rows.isEmpty)
        const Text('Log at least two entries to see how your numbers change over time.')
      else ...[
        const Text('Change since your first entry', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        ...rows,
      ],
    ]));
  }

  @override
  Widget build(BuildContext context) {
    if (widget.teen) {
      return ListView(padding: const EdgeInsets.all(18), children: [
        const Text('Body', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        _card(const Text('Teen bodies grow and change at very different speeds, and that is completely normal. So Teen mode does not track weight, BMI or body measurements. Focus on how you feel: energy, strength, sleep and mood. If you have questions about growth or health, a doctor can check it properly with growth charts. You can still use Workouts and the journal.', style: TextStyle(height: 1.4))),
      ]);
    }
    if (widget.sex == null) {
      return SexGate(onSex: widget.onSex, message: 'Body tracking and guidance are tailored to the male or female body. Choose one to continue.');
    }
    final last = log.isEmpty ? null : log.last;
    return ListView(padding: const EdgeInsets.all(18), children: [
      const Text('Body', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
      const SizedBox(height: 4),
      const Text('Optional. Everything stays on this device.'),
      const SizedBox(height: 12),
      SegmentedButton<bool>(
        segments: const [
          ButtonSegment<bool>(value: true, label: Text('Metric (kg, cm)')),
          ButtonSegment<bool>(value: false, label: Text('Imperial (lb, in)')),
        ],
        selected: {metric},
        onSelectionChanged: (s) => _setUnits(s.first),
      ),
      _h('Height'),
      _card(Row(children: [
        if (metric)
          Expanded(child: TextField(controller: heightC, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Height (cm)', border: OutlineInputBorder())))
        else ...[
          Expanded(child: TextField(controller: feetC, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Feet', border: OutlineInputBorder()))),
          const SizedBox(width: 8),
          Expanded(child: TextField(controller: inchC, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Inches', border: OutlineInputBorder()))),
        ],
        const SizedBox(width: 8),
        FilledButton(onPressed: _saveHeight, child: const Text('Save')),
      ])),
      _h("Today's weigh-in"),
      _card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('For the most consistent numbers, weigh yourself in the morning after using the bathroom and before eating or drinking, in similar clothing, on the same scale.', style: TextStyle(fontSize: 12, color: Colors.grey)),
        const SizedBox(height: 10),
        TextField(
          controller: weightC,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: 'Weight (${_wUnit()})',
            hintText: _latest('weight_kg') == null ? null : 'Last: ${_f(_wOut(_latest('weight_kg')!))}',
            border: const OutlineInputBorder(),
          ),
        ),
        ExpansionTile(
          tilePadding: EdgeInsets.zero,
          title: const Text('Body measurements (optional)'),
          subtitle: const Text('Measure with a soft tape, relaxed, not pulled tight.', style: TextStyle(fontSize: 12)),
          children: [
            ...bodyFields.map((f) {
              final prev = _latest('${f[0]}_cm');
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: TextField(
                  controller: mc[f[0]],
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: '${f[1]} (${_lUnit()})',
                    hintText: prev == null ? null : 'Last: ${_f(_lOut(prev))}',
                    border: const OutlineInputBorder(),
                  ),
                ),
              );
            }),
          ],
        ),
        const SizedBox(height: 6),
        FilledButton.icon(onPressed: _saveEntry, icon: const Icon(Icons.save_outlined), label: const Text("Save today's entry")),
      ])),
      _h('Profile'),
      _profile(),
      _h('Progress'),
      _progress(),
      if (log.isNotEmpty) ...[
        _h('History'),
        ...log.reversed.map((e) => Card(
              child: ListTile(
                title: Text(e['date'] as String),
                subtitle: Text(e['weight_kg'] is num ? '${_f(_wOut((e['weight_kg'] as num).toDouble()))} ${_wUnit()}' : 'Measurements only'),
                trailing: IconButton(icon: const Icon(Icons.delete_outline), onPressed: () => _delete(e['date'] as String)),
              ),
            )),
      ],
      if (last == null) const SizedBox(height: 4),
    ]);
  }
}

class _LinePainter extends CustomPainter {
  final List<double> v;
  final Color color;
  _LinePainter(this.v, this.color);
  @override
  void paint(Canvas c, Size s) {
    if (v.length < 2) return;
    final mn = v.reduce(min);
    final mx = v.reduce(max);
    final span = (mx - mn) == 0 ? 1.0 : (mx - mn);
    final line = Paint()
      ..color = color
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final dot = Paint()..color = color;
    final path = Path();
    for (var i = 0; i < v.length; i++) {
      final x = s.width * i / (v.length - 1);
      final y = s.height - 8 - (v[i] - mn) / span * (s.height - 16);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    c.drawPath(path, line);
    for (var i = 0; i < v.length; i++) {
      final x = s.width * i / (v.length - 1);
      final y = s.height - 8 - (v[i] - mn) / span * (s.height - 16);
      c.drawCircle(Offset(x, y), 3.5, dot);
    }
  }

  @override
  bool shouldRepaint(covariant _LinePainter old) => old.v != v;
}
