import 'package:flutter/material.dart';
import 'store.dart';

/// Age group from the saved birth month/year (and optional day). If the day is unknown the
/// end of the month is assumed, so the app never treats someone as older than they are.
String? ageGroupFor(Store s, [DateTime? now]) {
  final y = s.getInt('birth_year'), m = s.getInt('birth_month');
  if (y == null || m == null) return null;
  return ageGroupOf(y, m, s.getInt('birth_day') ?? 0, now);
}

String ageGroupOf(int y, int m, int d, [DateTime? now]) {
  now ??= DateTime.now();
  final day = d > 0 ? d : DateTime(y, m + 1, 0).day;
  bool reached(int years) => !DateTime(y + years, m, day).isAfter(DateTime(now!.year, now.month, now.day));
  if (reached(18)) return 'adult';
  if (reached(13)) return 'teen';
  return 'child';
}

const _months = ['January','February','March','April','May','June','July','August','September','October','November','December'];

/// First-run screen. Only a birth month and year (and an optional day, for a birthday greeting) are kept, on this device.
class AgeGate extends StatefulWidget {
  final Store prefs;
  final void Function(String group) onDone;
  final bool blocked;
  const AgeGate({super.key, required this.prefs, required this.onDone, this.blocked = false});
  @override
  State<AgeGate> createState() => _AgeGateState();
}

class _AgeGateState extends State<AgeGate> {
  late int step = widget.blocked ? 2 : 0; // 0 birthday, 1 teen approval, 2 under 13
  bool approved = false;
  int? month, year, day;
  String? error;

  Future<void> _check() async {
    if (month == null || year == null) { setState(() => error = 'Please choose your birth month and year.'); return; }
    final d = day ?? 0;
    if (d > 0 && DateTime(year!, month! + 1, 0).day < d) { setState(() => error = 'That day does not exist in that month.'); return; }
    final g = ageGroupOf(year!, month!, d);
    setState(() => error = null);
    if (g == 'child') {
      // Remembered on this phone so the app stays closed until they turn 13.
      await widget.prefs.setInt('birth_year', year!);
      await widget.prefs.setInt('birth_month', month!);
      await widget.prefs.setInt('birth_day', d);
      await widget.prefs.setString('age_group', 'child');
      setState(() => step = 2);
    }
    else if (g == 'teen') { setState(() => step = 1); }
    else { await _finish('adult'); }
  }

  Future<void> _finish(String g) async {
    await widget.prefs.setInt('birth_year', year!);
    await widget.prefs.setInt('birth_month', month!);
    await widget.prefs.setInt('birth_day', day ?? 0);
    await widget.prefs.setString('age_group', g);
    widget.onDone(g);
  }

  @override
  Widget build(BuildContext context) {
    Widget body;
    if (step == 1) {
      body = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Parent or guardian approval', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        const Text('Shell is designed to be used by teens with a parent or guardian’s knowledge and approval. Please show them this app and the Privacy notice (in the menu at the top right of the app).'),
        const SizedBox(height: 12),
        const Text('For teens, the app is in Teen mode. It does not track weight or BMI, hides advanced workouts and the Deep Core Foundation exercises, and leaves out romantic prompts. Everything stays on this phone.'),
        const SizedBox(height: 12),
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
          value: approved,
          onChanged: (v) => setState(() => approved = v ?? false),
          title: const Text('A parent or guardian has looked at this app with me and said it is OK for me to use it.'),
        ),
        const SizedBox(height: 12),
        FilledButton(onPressed: approved ? () => _finish('teen') : null, child: const Text('Continue')),
        TextButton(onPressed: () => setState(() => step = 0), child: const Text('Back')),
      ]);
    } else if (step == 2) {
      body = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Sorry, you can’t use this app yet', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        const Text('Shell is only for people aged 13 and older, so we can’t let you in right now. This isn’t a punishment, it’s just to keep younger kids safe. The app remembers on this phone (and nowhere else) that you are not old enough yet, and it will open for you after your 13th birthday. Please ask a parent or guardian to help you find something that suits your age.'),
      ]);
    } else {
      final now = DateTime.now();
      body = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Welcome to Shell', style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Color(0xFF21877C))),
        const SizedBox(height: 12),
        const Text('To keep things safe and age-appropriate, please enter your birth month and year. It is checked on this phone only and never sent anywhere. No name, email or account is needed.'),
        const SizedBox(height: 16),
        DropdownButtonFormField<int>(
          decoration: const InputDecoration(labelText: 'Birth month', border: OutlineInputBorder()),
          value: month,
          items: [for (var i = 1; i <= 12; i++) DropdownMenuItem(value: i, child: Text(_months[i - 1]))],
          onChanged: (v) => setState(() => month = v),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<int>(
          decoration: const InputDecoration(labelText: 'Birth year', border: OutlineInputBorder()),
          value: year,
          items: [for (var y = now.year; y >= now.year - 100; y--) DropdownMenuItem(value: y, child: Text('$y'))],
          onChanged: (v) => setState(() => year = v),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<int>(
          decoration: const InputDecoration(labelText: 'Birth day (optional)', helperText: 'Only if you would like a birthday greeting from the app', border: OutlineInputBorder()),
          value: day,
          items: [const DropdownMenuItem<int>(value: null, child: Text('Skip')), for (var d = 1; d <= 31; d++) DropdownMenuItem(value: d, child: Text('$d'))],
          onChanged: (v) => setState(() => day = v),
        ),
        if (error != null) Padding(padding: const EdgeInsets.only(top: 10), child: Text(error!, style: const TextStyle(color: Colors.red))),
        const SizedBox(height: 20),
        FilledButton(onPressed: _check, child: const Text('Continue')),
      ]);
    }
    return Scaffold(
      body: SafeArea(child: Center(child: SingleChildScrollView(padding: const EdgeInsets.all(24), child: body))),
    );
  }
}
