import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:share_plus/share_plus.dart';
import 'package:timezone/timezone.dart' as tz;
import 'areas.dart';
import 'common.dart';
import 'planner.dart';
import 'store.dart';

/// Set once at startup so screens can schedule notifications.
FlutterLocalNotificationsPlugin? notifier;

/// Optional extras, all on by default but switchable in Settings > Extras.
bool extraOn(Store p, String key, {bool def = true}) => p.getBool('x_$key') ?? def;

DateTime _mondayOf(DateTime d) => DateTime(d.year, d.month, d.day - (d.weekday - 1));

class WeekStats {
  int journalDays = 0, workouts = 0, goalsDone = 0, habitChecks = 0;
  double? mood, energy;
  DateTime from, to;
  WeekStats(this.from, this.to);
}

Map<String, dynamic> _entries(Store p) {
  try {
    return Map<String, dynamic>.from(jsonDecode(p.getString('entries') ?? '{}') as Map);
  } catch (_) {
    return {};
  }
}

WeekStats weekStats(Store p, DateTime to) {
  final from = DateTime(to.year, to.month, to.day - 6);
  final st = WeekStats(from, to);
  final keys = {for (var i = 0; i < 7; i++) dayKey(DateTime(from.year, from.month, from.day + i))};
  final e = _entries(p);
  final moods = <int>[], energies = <int>[];
  for (final k in keys) {
    final v = e[k];
    if (v is Map) {
      if ('${v['journal'] ?? ''}'.trim().isNotEmpty || v['mood'] != null) st.journalDays++;
      if (v['mood'] is num) moods.add((v['mood'] as num).toInt());
      if (v['energy'] is num) energies.add((v['energy'] as num).toInt());
    }
  }
  if (moods.isNotEmpty) st.mood = moods.reduce((a, b) => a + b) / moods.length;
  if (energies.isNotEmpty) st.energy = energies.reduce((a, b) => a + b) / energies.length;
  st.workouts = (p.getStringList('ex_log') ?? <String>[]).where(keys.contains).length;
  for (final g in loadGoals(p)) {
    if (g.repeats) {
      st.habitChecks += g.dones.where(keys.contains).length;
    } else if (g.done && keys.contains(g.doneOn)) {
      st.goalsDone++;
    }
  }
  return st;
}

String weekSummaryLine(WeekStats s) {
  final bits = <String>[];
  if (s.workouts > 0) bits.add('${s.workouts} ${s.workouts == 1 ? 'workout' : 'workouts'}');
  final g = s.goalsDone + s.habitChecks;
  if (g > 0) bits.add('$g goal ${g == 1 ? 'check' : 'checks'}');
  if (s.journalDays > 0) bits.add('${s.journalDays} ${s.journalDays == 1 ? 'day' : 'days'} of reflecting');
  if (bits.isEmpty) return 'A quiet week. A fresh start is always one small step away.';
  return 'You showed up: ${bits.join(', ')}.';
}

Map<String, dynamic> _reviews(Store p) {
  try {
    return Map<String, dynamic>.from(jsonDecode(p.getString('reviews') ?? '{}') as Map);
  } catch (_) {
    return {};
  }
}

// ------------------------------------------------------------------ notifications

const _extraDetails = NotificationDetails(
  android: AndroidNotificationDetails('extras', 'Gentle check-ins', channelDescription: 'Weekly review and backup reminders', importance: Importance.defaultImportance, priority: Priority.defaultPriority),
  iOS: DarwinNotificationDetails(),
);

/// Weekly review (Sunday evening, id 300) and monthly backup nudge (id 310).
Future<void> scheduleExtras(FlutterLocalNotificationsPlugin n, Store p) async {
  if (kIsWeb) return;
  try {
    await n.cancel(300);
    await n.cancel(310);
    final now = tz.TZDateTime.now(tz.local);
    if (extraOn(p, 'review')) {
      var t = tz.TZDateTime(tz.local, now.year, now.month, now.day, 18, 30);
      while (t.weekday != DateTime.sunday || !t.isAfter(now)) {
        t = t.add(const Duration(days: 1));
      }
      await n.zonedSchedule(300, 'Your week in review', 'Take two minutes to look back and set up next week.', t, _extraDetails,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
          matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime);
    }
    if (extraOn(p, 'backup') && !backupNudgeSilenced(p)) {
      var t = tz.TZDateTime(tz.local, now.year, now.month, now.day, 12, 0).add(const Duration(days: 30));
      await n.zonedSchedule(310, 'Back up your data?', 'Your data lives only on this phone. Export a copy so it is never lost.', t, _extraDetails,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime);
    }
  } catch (_) {}
}

bool backupNudgeSilenced(Store p) => p.cloudOn;

/// True when it has been 30+ days since the last export (or first use) and there is data worth saving.
bool backupDue(Store p) {
  if (!extraOn(p, 'backup') || backupNudgeSilenced(p)) return false;
  final snooze = p.getString('backup_snooze');
  if (snooze != null && snooze.compareTo(dayKey(DateTime.now())) > 0) return false;
  final base = p.getString('last_export') ?? p.getString('first_run');
  if (base == null) return false;
  final d = DateTime.tryParse(base);
  return d != null && DateTime.now().difference(d).inDays >= 30;
}

// ------------------------------------------------------------------ page

class WeeklyReviewPage extends StatefulWidget {
  final Store prefs;
  const WeeklyReviewPage({super.key, required this.prefs});
  @override
  State<WeeklyReviewPage> createState() => _WeeklyReviewPageState();
}

class _WeeklyReviewPageState extends State<WeeklyReviewPage> {
  final _cardKey = GlobalKey();
  late final WeekStats st;
  late final String wk;
  final c = List.generate(3, (_) => TextEditingController());
  static const qs = ['What went well this week?', 'What was hard?', 'One thing I will do next week'];
  static const ks = ['well', 'hard', 'next'];

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    st = weekStats(widget.prefs, DateTime(now.year, now.month, now.day));
    wk = dayKey(_mondayOf(now));
    final saved = _reviews(widget.prefs)[wk];
    if (saved is Map) {
      for (var i = 0; i < 3; i++) {
        c[i].text = '${saved[ks[i]] ?? ''}';
      }
    }
  }

  Future<void> _save() async {
    final all = _reviews(widget.prefs);
    all[wk] = {for (var i = 0; i < 3; i++) ks[i]: c[i].text.trim()};
    await widget.prefs.setString('reviews', jsonEncode(all));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Saved on this device.')));
  }

  Future<void> _share() async {
    try {
      final b = _cardKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final img = await b.toImage(pixelRatio: 3);
      final data = await img.toByteData(format: ui.ImageByteFormat.png);
      final bytes = Uint8List.view(data!.buffer);
      await Share.shareXFiles([XFile.fromData(bytes, mimeType: 'image/png', name: 'my-week.png')], text: 'My week, in Shell');
    } catch (_) {
      await Share.share('My week in Shell: ${weekSummaryLine(st)}');
    }
  }

  Widget _stat(IconData i, String big, String small) => Expanded(
        child: Column(children: [
          Icon(i, color: const Color(0xFF21877C)),
          const SizedBox(height: 4),
          Text(big, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          Text(small, textAlign: TextAlign.center, style: const TextStyle(fontSize: 11, color: Colors.grey)),
        ]),
      );

  String _moodWord(double? m) => m == null ? '–' : m >= 4.2 ? 'Great' : m >= 3.4 ? 'Good' : m >= 2.6 ? 'Okay' : 'Low';

  @override
  Widget build(BuildContext context) {
    final g = st.goalsDone + st.habitChecks;
    return Scaffold(
      appBar: AppBar(title: const Text('Weekly review')),
      body: ListView(padding: const EdgeInsets.all(18), children: [
        RepaintBoundary(
          key: _cardKey,
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: const Color(0xFFE8F4F2), borderRadius: BorderRadius.circular(18)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('MY WEEK  •  SHELL', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2, color: Color(0xFF21877C))),
              const SizedBox(height: 14),
              Row(children: [
                _stat(Icons.fitness_center, '${st.workouts}', 'workouts'),
                _stat(Icons.check_circle_outline, '$g', 'goal checks'),
                _stat(Icons.edit_note, '${st.journalDays}', 'days reflected'),
                _stat(Icons.mood, _moodWord(st.mood), 'average mood'),
              ]),
              const SizedBox(height: 14),
              Text(weekSummaryLine(st), style: const TextStyle(fontSize: 16, height: 1.4)),
              if (extraOn(widget.prefs, 'areas') && areaWeekLine(widget.prefs).isNotEmpty) Padding(padding: const EdgeInsets.only(top: 8), child: Text(areaWeekLine(widget.prefs), style: const TextStyle(height: 1.4))),
            ]),
          ),
        ),
        Align(alignment: Alignment.centerRight, child: TextButton.icon(onPressed: _share, icon: const Icon(Icons.ios_share), label: const Text('Share this card'))),
        const Text('The card shows only these numbers. No names, no notes.', style: TextStyle(fontSize: 12, color: Colors.grey)),
        const SizedBox(height: 18),
        for (var i = 0; i < 3; i++) ...[
          Text(qs[i], style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          TextField(controller: c[i], maxLines: 3, minLines: 2, textCapitalization: TextCapitalization.sentences, decoration: const InputDecoration(border: OutlineInputBorder())),
          const SizedBox(height: 14),
        ],
        FilledButton(onPressed: _save, child: const Text('Save my review')),
        const SizedBox(height: 18),
        Builder(builder: (_) {
          final past = _reviews(widget.prefs).entries.where((e) => e.key != wk).toList()..sort((a, b) => b.key.compareTo(a.key));
          if (past.isEmpty) return const SizedBox.shrink();
          return ExpansionTile(
            tilePadding: EdgeInsets.zero,
            title: const Text('Past reviews', style: TextStyle(fontWeight: FontWeight.bold)),
            children: [
              for (final e in past.take(12))
                ListTile(
                  title: Text('Week of ${e.key}'),
                  subtitle: Text([for (var i = 0; i < 3; i++) if ('${(e.value as Map)[ks[i]] ?? ''}'.isNotEmpty) '${['Went well', 'Hard', 'Next'][i]}: ${(e.value as Map)[ks[i]]}'].join('\n')),
                ),
            ],
          );
        }),
      ]),
    );
  }
}
