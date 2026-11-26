import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'challenges.dart';
import 'common.dart';
import 'review.dart';
import 'theme.dart';
import 'store.dart';

const _wd = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
const _mo = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

DateTime _today() {
  final n = DateTime.now();
  return DateTime(n.year, n.month, n.day);
}

DateTime _pd(String s) => DateTime.parse(s);
DateTime _addDays(DateTime d, int n) => DateTime(d.year, d.month, d.day + n);
String _fmtDate(DateTime d) => '${_wd[d.weekday - 1]} ${_mo[d.month - 1]} ${d.day}';
String _fmtTime(String hhmm) {
  final p = hhmm.split(':');
  var h = int.parse(p[0]);
  final ap = h >= 12 ? 'PM' : 'AM';
  h = h % 12;
  if (h == 0) h = 12;
  return '$h:${p[1]} $ap';
}

String _hhmm(TimeOfDay t) => '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
TimeOfDay _tod(String s) {
  final p = s.split(':');
  return TimeOfDay(hour: int.parse(p[0]), minute: int.parse(p[1]));
}

/// A goal: can be for one day, or stretch over days or weeks.
class Goal {
  String id, title, note, start, stime, due, dtime, doneOn;
  int imp;
  bool done;
  List<String> worked, dones;
  String rep; // '' (one time), 'daily', 'weekly', 'days'
  List<int> rdays; // weekdays 1=Mon..7=Sun for rep == 'days'
  Goal({required this.id, required this.title, this.note = '', required this.start, this.stime = '', this.due = '', this.dtime = '', this.doneOn = '', this.imp = 5, this.done = false, List<String>? worked, List<String>? dones, this.rep = '', List<int>? rdays})
      : worked = worked ?? [],
        dones = dones ?? [],
        rdays = rdays ?? [];

  Map<String, dynamic> toJson() => {
        'id': id, 'title': title, 'note': note, 'importance': imp, 'start': start, 'start_time': stime,
        'due': due, 'due_time': dtime, 'done': done, 'done_on': doneOn, 'worked': worked,
        'repeat': rep, 'repeat_days': rdays, 'done_dates': dones,
      };

  factory Goal.fromJson(Map<String, dynamic> j) => Goal(
        id: '${j['id'] ?? ''}', title: '${j['title'] ?? ''}', note: '${j['note'] ?? ''}',
        imp: ((j['importance'] ?? 5) as num).toInt().clamp(1, 10), start: '${j['start'] ?? dayKey(_today())}',
        stime: '${j['start_time'] ?? ''}', due: '${j['due'] ?? ''}', dtime: '${j['due_time'] ?? ''}',
        done: j['done'] == true, doneOn: '${j['done_on'] ?? ''}', worked: List<String>.from((j['worked'] ?? const []) as List),
        rep: '${j['repeat'] ?? ''}', rdays: List<int>.from(((j['repeat_days'] ?? const []) as List).map((e) => (e as num).toInt())),
        dones: List<String>.from((j['done_dates'] ?? const []) as List),
      );

  bool get multi => rep.isEmpty && due.isNotEmpty && due != start;
  bool get repeats => rep.isNotEmpty;

  bool scheduledOn(DateTime d) {
    if (!repeats || _pd(start).isAfter(d)) return false;
    if (rep == 'daily') return true;
    if (rep == 'weekly') return d.weekday == _pd(start).weekday;
    return rdays.contains(d.weekday);
  }

  bool doneOnDay(DateTime d) => repeats ? dones.contains(dayKey(d)) : (done && doneOn == dayKey(d));

  /// Forgiving streak: one missed scheduled day never breaks it, two in a row do.
  int streak(DateTime today) {
    if (!repeats) return 0;
    var n = 0, miss = 0;
    for (var i = 0; i < 400; i++) {
      final d = _addDays(today, -i);
      if (_pd(start).isAfter(d)) break;
      if (!scheduledOn(d)) continue;
      if (dones.contains(dayKey(d))) {
        n++;
        miss = 0;
      } else if (i == 0) {
        continue;
      } else if (++miss >= 2) {
        break;
      }
    }
    return n;
  }

  String get repLabel {
    if (rep == 'daily') return 'Every day';
    if (rep == 'weekly') return 'Every week';
    if (rep == 'days') return rdays.isEmpty ? 'Repeats' : (List<int>.from(rdays)..sort()).map((d) => _wd[d - 1]).join(' ');
    return '';
  }
}

/// Adds a goal from elsewhere in the app (exercises, Connect, challenges).
Future<void> addGoal(Store p, {required String title, String note = '', int imp = 5, String rep = '', List<int>? rdays, int? days, DateTime? start}) async {
  final t = start ?? _today();
  final g = Goal(id: '${DateTime.now().microsecondsSinceEpoch}${title.hashCode.abs()}', title: title, note: note, imp: imp, start: dayKey(t), rep: rep, rdays: rdays);
  if (days != null && days > 1) g.due = dayKey(_addDays(t, days - 1));
  final all = loadGoals(p)..add(g);
  await saveGoals(p, all);
}

List<Goal> loadGoals(Store p) {
  try {
    final l = jsonDecode(p.getString('goals') ?? '[]') as List;
    return [for (final e in l) Goal.fromJson(Map<String, dynamic>.from(e as Map))];
  } catch (_) {
    return [];
  }
}

Future<void> saveGoals(Store p, List<Goal> g) => p.setString('goals', jsonEncode([for (final x in g) x.toJson()]));

bool _overdue(Goal g, DateTime t) => !g.repeats && !g.done && g.due.isNotEmpty && _pd(g.due).isBefore(t);
bool _activeToday(Goal g, DateTime t) => g.repeats ? g.scheduledOn(t) : !g.done && !_pd(g.start).isAfter(t) && (g.due.isEmpty || !_pd(g.due).isBefore(t));
bool _upcoming(Goal g, DateTime t) => !g.done && _pd(g.start).isAfter(t);

int _cmp(Goal a, Goal b) {
  final c = b.imp.compareTo(a.imp);
  if (c != 0) return c;
  if (a.due.isEmpty != b.due.isEmpty) return a.due.isEmpty ? 1 : -1;
  final d = a.due.compareTo(b.due);
  return d != 0 ? d : a.stime.compareTo(b.stime);
}

/// (finished today, total for today) for the summary card on the Today page.
(int, int) goalsSummary(Store p) {
  final t = _today();
  final g = loadGoals(p);
  final open = g.where((x) => !x.repeats && (_activeToday(x, t) || _overdue(x, t))).length;
  final done = g.where((x) => !x.repeats && x.done && x.doneOn == dayKey(t)).length;
  final rp = g.where((x) => x.scheduledOn(t)).toList();
  final rd = rp.where((x) => x.dones.contains(dayKey(t))).length;
  return (done + rd, open + done + rp.length);
}

Color _impColor(int i) => Color.lerp(const Color(0xFF21877C), const Color(0xFFD9480F), (i - 1) / 9)!;
String _impLabel(int i) => i <= 2 ? 'Nice to do' : i <= 4 ? 'Worth doing' : i <= 6 ? 'Important' : i <= 8 ? 'Very important' : 'Top priority';

// ------------------------------------------------------------------ reminders

/// Schedules friendly reminders for open goals (next two weeks). Safe to call any time.
Future<void> schedulePlanner(FlutterLocalNotificationsPlugin n, Store p) async {
  if (kIsWeb) return;
  try {
    for (final s in p.getStringList('plan_nids') ?? <String>[]) {
      final id = int.tryParse(s);
      if (id != null) await n.cancel(id);
    }
    final goals = loadGoals(p).where((g) => !g.done).toList();
    final now = tz.TZDateTime.now(tz.local);
    final today = DateTime(now.year, now.month, now.day);
    final last = _addDays(today, 13);
    final items = <(tz.TZDateTime, String, String)>[];
    void add(DateTime day, int h, int m, String title, String body) {
      final w = tz.TZDateTime(tz.local, day.year, day.month, day.day, h, m);
      if (w.isAfter(now) && !items.any((e) => e.$1 == w && e.$2 == title)) items.add((w, title, body));
    }
    (int, int) hm(String s, int dh, int dm) {
      if (s.isEmpty) return (dh, dm);
      final q = s.split(':');
      return (int.parse(q[0]), int.parse(q[1]));
    }

    for (final g in goals) {
      if (g.repeats) {
        final (rh, rm) = hm(g.stime, 9, 0);
        for (var day = today; !day.isAfter(_addDays(today, 6)); day = _addDays(day, 1)) {
          if (g.scheduledOn(day) && !g.dones.contains(dayKey(day))) {
            final k = g.streak(today);
            add(day, rh, rm, g.title, k >= 2 ? '$k in a row. Keep it going, gently.' : 'Time for this one. A small step counts.');
          }
        }
        continue;
      }
      final s = _pd(g.start);
      final d = g.due.isEmpty ? null : _pd(g.due);
      final (sh, sm) = hm(g.stime, 9, 0);
      if (d != null && d.isAfter(s)) {
        final total = d.difference(s).inDays + 1;
        for (var day = s.isBefore(today) ? today : s; !day.isAfter(d) && !day.isAfter(last); day = _addDays(day, 1)) {
          final idx = day.difference(s).inDays;
          if (g.stime.isNotEmpty || idx == 0 || idx.isEven) {
            add(day, sh, sm, g.title, idx == 0 ? 'Starting today. Take the first small step.' : 'Day ${idx + 1} of $total. A little progress today counts.');
          }
        }
      } else if (!s.isBefore(today) && !s.isAfter(last)) {
        add(s, sh, sm, g.title, g.stime.isNotEmpty ? 'Time to get started. You’ve got this.' : 'On your list today.');
      }
      if (d != null && !d.isBefore(today) && !d.isAfter(last)) {
        if (g.dtime.isNotEmpty) {
          final (dh, dm) = hm(g.dtime, 17, 0);
          add(DateTime(d.year, d.month, d.day), dh - 1, dm, g.title, 'Due in about an hour. You can finish this.');
        } else if (d != s || g.stime.isNotEmpty) {
          add(d, 9, 0, g.title, 'Due today. You can finish this.');
        }
        if (g.imp >= 8) {
          add(_addDays(d, -1), 18, 0, 'Tomorrow: ${g.title}', 'This one matters to you. A little prep tonight helps.');
          add(d, 18, 0, 'Still on your list: ${g.title}', 'There is still time to finish it today.');
        }
      }
      if (d != null && d.isBefore(today) && g.imp >= 5) {
        add(now.hour < 9 ? today : _addDays(today, 1), 9, 0, 'Still on your list: ${g.title}', 'No pressure. One small step today counts.');
      }
    }
    items.sort((a, b) => a.$1.compareTo(b.$1));
    const details = NotificationDetails(
      android: AndroidNotificationDetails('planner', 'Goals and reminders', channelDescription: 'Reminders for your goals', importance: Importance.high, priority: Priority.high),
      iOS: DarwinNotificationDetails(),
    );
    final ids = <String>[];
    for (var i = 0; i < items.length && i < 40; i++) {
      await n.zonedSchedule(2000 + i, items[i].$2, items[i].$3, items[i].$1, details,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime);
      ids.add('${2000 + i}');
    }
    await p.setStringList('plan_nids', ids);
  } catch (_) {}
}

// ------------------------------------------------------------------ screen

class PlannerPage extends StatefulWidget {
  final Store prefs;
  final Future<void> Function() onChanged;
  const PlannerPage({super.key, required this.prefs, required this.onChanged});
  @override
  State<PlannerPage> createState() => _PlannerPageState();
}

class _PlannerPageState extends State<PlannerPage> {
  late List<Goal> goals = loadGoals(widget.prefs);

  Future<void> _save() async {
    await saveGoals(widget.prefs, goals);
    if (mounted) setState(() {});
    await widget.onChanged();
  }

  void _say(String m) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(m), duration: const Duration(seconds: 3)));
  }

  Future<void> _toggle(Goal g, bool v) async {
    final key = dayKey(_today());
    if (g.repeats) {
      v ? (g.dones.contains(key) ? null : g.dones.add(key)) : g.dones.remove(key);
    } else {
      g.done = v;
      g.doneOn = v ? key : '';
    }
    await _save();
    if (!v || !mounted) return;
    final (d, t) = goalsSummary(widget.prefs);
    const cheers = ['Nice work. That’s one off your list!', 'You did it. Small wins add up.', 'Done! That took follow-through.', 'Another step toward your best self.', 'Checked off. Be proud of that.'];
    if (t > 0 && d == t) {
      _say('Everything for today is done. Enjoy the rest of your day!');
    } else if (g.imp >= 8) {
      _say('Big one finished! That mattered, and you did it.');
    } else {
      final k = g.streak(_today());
      _say(g.repeats && k >= 2 ? '$k in a row. That’s a real habit forming.' : '${cheers[g.id.hashCode.abs() % cheers.length]} ($d of $t today)');
    }
  }

  Future<void> _worked(Goal g) async {
    final key = dayKey(_today());
    if (g.worked.contains(key)) {
      g.worked.remove(key);
    } else {
      g.worked.add(key);
      _say('Progress counts. You’ve worked on this ${g.worked.length} ${g.worked.length == 1 ? 'day' : 'days'}.');
    }
    await _save();
  }

  Future<void> _focus(Goal g) async {
    final mins = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Padding(padding: const EdgeInsets.fromLTRB(20, 0, 20, 8), child: Text('Focus on: ${g.title}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600))),
          for (final m in [15, 25, 45]) ListTile(leading: const Icon(Icons.timer_outlined), title: Text('$m minutes'), onTap: () => Navigator.pop(ctx, m)),
        ]),
      ),
    );
    if (mins == null || !mounted) return;
    try {
      if (!kIsWeb && notifier != null) {
        await notifier!.zonedSchedule(4000, 'Focus time is up', 'Nice. ${g.title} got your full attention.', tz.TZDateTime.now(tz.local).add(Duration(minutes: mins)),
            const NotificationDetails(android: AndroidNotificationDetails('focus', 'Focus sessions', channelDescription: 'Tells you when a focus session ends', importance: Importance.high, priority: Priority.high), iOS: DarwinNotificationDetails()),
            androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
            uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime);
      }
    } catch (_) {}
    final finished = await showDialog<bool>(context: context, barrierDismissible: false, builder: (_) => _FocusDialog(title: g.title, minutes: mins));
    try {
      if (!kIsWeb) await notifier?.cancel(4000);
    } catch (_) {}
    if (finished == true) {
      final key = dayKey(_today());
      if (!g.worked.contains(key)) g.worked.add(key);
      await _save();
      _say('Focus session done. That counts as working on it today.');
    }
  }

  Future<void> _edit(Goal? existing) async {
    final t = _today();
    final g = existing == null
        ? Goal(id: DateTime.now().microsecondsSinceEpoch.toString(), title: '', start: dayKey(t))
        : Goal.fromJson(existing.toJson());
    final titleC = TextEditingController(text: g.title), noteC = TextEditingController(text: g.note);
    String? err;
    final res = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setS) {
        Future<DateTime?> pick(DateTime init) => showDatePicker(context: ctx, initialDate: init, firstDate: _addDays(t, -30), lastDate: _addDays(t, 365 * 3));
        final s = _pd(g.start);
        final due = g.due.isEmpty ? null : _pd(g.due);
        void setDue(int? days) => setS(() => g.due = days == null ? '' : dayKey(_addDays(_pd(g.start), days)));
        final dueDays = due?.difference(s).inDays;
        return Padding(
          padding: EdgeInsets.fromLTRB(18, 0, 18, MediaQuery.of(ctx).viewInsets.bottom + 18),
          child: SingleChildScrollView(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(existing == null ? 'New goal' : 'Edit goal', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              TextField(controller: titleC, autofocus: existing == null, textCapitalization: TextCapitalization.sentences, decoration: InputDecoration(labelText: 'What do you want to get done?', border: const OutlineInputBorder(), errorText: err)),
              const SizedBox(height: 10),
              TextField(controller: noteC, maxLines: 2, textCapitalization: TextCapitalization.sentences, decoration: const InputDecoration(labelText: 'Notes (optional)', border: OutlineInputBorder())),
              const SizedBox(height: 14),
              Text('Importance: ${g.imp} of 10  •  ${_impLabel(g.imp)}', style: const TextStyle(fontWeight: FontWeight.w600)),
              Slider(min: 1, max: 10, divisions: 9, value: g.imp.toDouble(), label: '${g.imp}', activeColor: _impColor(g.imp), onChanged: (v) => setS(() => g.imp = v.round())),
              const SizedBox(height: 4),
              const Text('When do you want to do it?', style: TextStyle(fontWeight: FontWeight.w600)),
              Wrap(spacing: 8, children: [
                ChoiceChip(label: const Text('Today'), selected: g.start == dayKey(t), onSelected: (_) => setS(() => g.start = dayKey(t))),
                ChoiceChip(label: const Text('Tomorrow'), selected: g.start == dayKey(_addDays(t, 1)), onSelected: (_) => setS(() => g.start = dayKey(_addDays(t, 1)))),
                ActionChip(
                  avatar: const Icon(Icons.calendar_month, size: 18),
                  label: Text(_fmtDate(s)),
                  onPressed: () async {
                    final d = await pick(s);
                    if (d != null) setS(() => g.start = dayKey(d));
                  },
                ),
                ActionChip(
                  avatar: const Icon(Icons.schedule, size: 18),
                  label: Text(g.stime.isEmpty ? 'Add a time' : _fmtTime(g.stime)),
                  onPressed: () async {
                    final x = await showTimePicker(context: ctx, initialTime: g.stime.isEmpty ? const TimeOfDay(hour: 9, minute: 0) : _tod(g.stime));
                    if (x != null) setS(() => g.stime = _hhmm(x));
                  },
                ),
                if (g.stime.isNotEmpty) ActionChip(label: const Text('Clear time'), onPressed: () => setS(() => g.stime = '')),
              ]),
              const SizedBox(height: 12),
              const Text('Repeat', style: TextStyle(fontWeight: FontWeight.w600)),
              Wrap(spacing: 8, children: [
                ChoiceChip(label: const Text('Just once'), selected: !g.repeats, onSelected: (_) => setS(() => g.rep = '')),
                ChoiceChip(label: const Text('Every day'), selected: g.rep == 'daily', onSelected: (_) => setS(() {
                      g.rep = 'daily';
                      g.due = '';
                      g.dtime = '';
                    })),
                ChoiceChip(label: const Text('Every week'), selected: g.rep == 'weekly', onSelected: (_) => setS(() {
                      g.rep = 'weekly';
                      g.due = '';
                      g.dtime = '';
                    })),
                ChoiceChip(label: const Text('Certain days'), selected: g.rep == 'days', onSelected: (_) => setS(() {
                      g.rep = 'days';
                      g.due = '';
                      g.dtime = '';
                      if (g.rdays.isEmpty) g.rdays = [1, 3, 5];
                    })),
              ]),
              if (g.rep == 'days')
                Wrap(spacing: 6, children: [
                  for (var i = 1; i <= 7; i++)
                    FilterChip(
                      label: Text(_wd[i - 1]),
                      selected: g.rdays.contains(i),
                      onSelected: (v) => setS(() => v ? g.rdays.add(i) : g.rdays.remove(i)),
                    ),
                ]),
              if (g.repeats)
                const Padding(padding: EdgeInsets.only(top: 4), child: Text('Missing a day is okay. Your streak only resets after two missed days in a row.', style: TextStyle(fontSize: 12, color: Colors.grey))),
              if (!g.repeats) ...[
              const SizedBox(height: 12),
              const Text('Done by', style: TextStyle(fontWeight: FontWeight.w600)),
              Wrap(spacing: 8, children: [
                ChoiceChip(label: const Text('No deadline'), selected: g.due.isEmpty, onSelected: (_) => setDue(null)),
                ChoiceChip(label: const Text('Same day'), selected: dueDays == 0, onSelected: (_) => setDue(0)),
                ChoiceChip(label: const Text('3 days'), selected: dueDays == 2, onSelected: (_) => setDue(2)),
                ChoiceChip(label: const Text('1 week'), selected: dueDays == 6, onSelected: (_) => setDue(6)),
                ChoiceChip(label: const Text('2 weeks'), selected: dueDays == 13, onSelected: (_) => setDue(13)),
                ChoiceChip(label: const Text('1 month'), selected: dueDays == 29, onSelected: (_) => setDue(29)),
                ActionChip(
                  avatar: const Icon(Icons.event, size: 18),
                  label: Text(due == null ? 'Pick a date' : _fmtDate(due)),
                  onPressed: () async {
                    final d = await pick(due ?? s);
                    if (d != null) setS(() => g.due = dayKey(d));
                  },
                ),
                if (g.due.isNotEmpty)
                  ActionChip(
                    avatar: const Icon(Icons.schedule, size: 18),
                    label: Text(g.dtime.isEmpty ? 'Add a time' : 'by ${_fmtTime(g.dtime)}'),
                    onPressed: () async {
                      final x = await showTimePicker(context: ctx, initialTime: g.dtime.isEmpty ? const TimeOfDay(hour: 17, minute: 0) : _tod(g.dtime));
                      if (x != null) setS(() => g.dtime = _hhmm(x));
                    },
                  ),
                if (g.dtime.isNotEmpty) ActionChip(label: const Text('Clear time'), onPressed: () => setS(() => g.dtime = '')),
              ]),
              const SizedBox(height: 6),
              Text(g.multi ? 'This goal stretches over ${due!.difference(s).inDays + 1} days. You can mark progress on it each day.' : 'Pick a longer deadline for goals that take days or weeks.', style: const TextStyle(fontSize: 12, color: Colors.grey)),
              ],
              const SizedBox(height: 14),
              Row(children: [
                if (existing != null) TextButton(onPressed: () => Navigator.pop(ctx, 'delete'), child: const Text('Delete', style: TextStyle(color: Colors.red))),
                const Spacer(),
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: () {
                    if (titleC.text.trim().isEmpty) {
                      setS(() => err = 'Please write your goal.');
                      return;
                    }
                    Navigator.pop(ctx, 'save');
                  },
                  child: const Text('Save'),
                ),
              ]),
            ]),
          ),
        );
      }),
    );
    if (res == 'save') {
      g.title = titleC.text.trim();
      g.note = noteC.text.trim();
      if (g.due.isNotEmpty && _pd(g.due).isBefore(_pd(g.start))) g.due = g.start;
      if (g.rep == 'days' && g.rdays.isEmpty) g.rep = 'daily';
      if (existing == null) {
        goals.add(g);
      } else {
        goals[goals.indexWhere((x) => x.id == existing.id)] = g;
      }
      await _save();
    } else if (res == 'delete' && existing != null) {
      goals.removeWhere((x) => x.id == existing.id);
      await _save();
    }
  }

  Widget _tile(Goal g) {
    final t = _today();
    final over = _overdue(g, t);
    final s = _pd(g.start);
    final bits = <String>[];
    if (g.repeats) {
      bits.add(g.repLabel);
      final k = g.streak(t);
      if (k >= 2) bits.add('$k in a row');
    }
    if (g.multi) {
      final total = _pd(g.due).difference(s).inDays + 1;
      if (!s.isAfter(t)) bits.add('Day ${(t.difference(s).inDays + 1).clamp(1, total)} of $total');
    }
    if (s.isAfter(t)) {
      bits.add('Starts ${_fmtDate(s)}${g.stime.isEmpty ? '' : ' at ${_fmtTime(g.stime)}'}');
    } else if (g.stime.isNotEmpty && !g.multi) {
      bits.add('At ${_fmtTime(g.stime)}');
    }
    if (g.due.isNotEmpty && (g.multi || over || s.isAfter(t))) {
      bits.add('${over ? 'Was due' : 'Due'} ${_fmtDate(_pd(g.due))}${g.dtime.isEmpty ? '' : ' by ${_fmtTime(g.dtime)}'}');
    } else if (g.due.isNotEmpty && g.dtime.isNotEmpty) {
      bits.add('Due by ${_fmtTime(g.dtime)}');
    }
    if (g.worked.isNotEmpty && !g.done) bits.add('Worked on ${g.worked.length} ${g.worked.length == 1 ? 'day' : 'days'}');
    final activeMulti = g.multi && _activeToday(g, t);
    final total = g.multi ? _pd(g.due).difference(s).inDays + 1 : 1;
    final dayN = g.multi ? (t.difference(s).inDays + 1).clamp(1, total) : 1;
    return Card(
      elevation: 0,
      color: over ? tint(context, const Color(0xFFFFF3E8)) : cardBg(context),
      margin: const EdgeInsets.only(bottom: 8),
      child: Column(children: [
        ListTile(
          onTap: () => _edit(g),
          leading: Checkbox(value: g.repeats ? g.dones.contains(dayKey(t)) : g.done, onChanged: (v) => _toggle(g, v == true)),
          title: Text(g.title, style: TextStyle(fontWeight: FontWeight.w600, decoration: (g.repeats ? g.dones.contains(dayKey(t)) : g.done) ? TextDecoration.lineThrough : null, color: (g.repeats ? g.dones.contains(dayKey(t)) : g.done) ? Colors.grey : null)),
          subtitle: bits.isEmpty && g.note.isEmpty ? null : Text([...bits, if (g.note.isNotEmpty) g.note].join('  •  ')),
          trailing: Row(mainAxisSize: MainAxisSize.min, children: [
            if (!g.done && _activeToday(g, t)) IconButton(tooltip: 'Focus timer', icon: const Icon(Icons.timer_outlined), onPressed: () => _focus(g)),
            CircleAvatar(radius: 14, backgroundColor: _impColor(g.imp), child: Text('${g.imp}', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold))),
          ]),
        ),
        if (activeMulti)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Row(children: [
              Expanded(child: LinearProgressIndicator(value: dayN / total, minHeight: 6, borderRadius: BorderRadius.circular(6))),
              const SizedBox(width: 10),
              FilterChip(
                label: const Text('Worked on it today'),
                selected: g.worked.contains(dayKey(t)),
                onSelected: (_) => _worked(g),
              ),
            ]),
          ),
      ]),
    );
  }

  Widget _section(String title, List<Goal> list, {String? hint, Color? color}) {
    if (list.isEmpty) return const SizedBox.shrink();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(padding: const EdgeInsets.only(top: 14, bottom: 6), child: Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color))),
      if (hint != null) Padding(padding: const EdgeInsets.only(bottom: 6), child: Text(hint, style: const TextStyle(fontSize: 12, color: Colors.grey))),
      for (final g in list) _tile(g),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final t = _today();
    final overdue = goals.where((g) => _overdue(g, t)).toList()..sort(_cmp);
    final today = goals.where((g) => _activeToday(g, t)).toList()..sort(_cmp);
    final upcoming = goals.where((g) => _upcoming(g, t)).toList()..sort((a, b) => a.start != b.start ? a.start.compareTo(b.start) : _cmp(a, b));
    final other = goals.where((g) => g.repeats && !g.scheduledOn(t) && !_upcoming(g, t)).toList()..sort(_cmp);
    final done = goals.where((g) => g.done).toList()..sort((a, b) => b.doneOn.compareTo(a.doneOn));
    final (fin, total) = goalsSummary(widget.prefs);
    final msg = total == 0
        ? 'Add one thing you want to get done. Big or small, it counts.'
        : fin == total
            ? 'All done for today. Well done!'
            : fin == 0
                ? 'Pick the one that matters most and start there.'
                : 'Keep going. You’re ${(fin * 100 / total).round()}% there.';
    return ListView(padding: const EdgeInsets.all(18), children: [
      Card(
        elevation: 0,
        color: tint(context, const Color(0xFFE8F4F2)),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(total == 0 ? 'Your goals' : 'Today: $fin of $total done', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            if (total > 0) ...[const SizedBox(height: 8), LinearProgressIndicator(value: fin / total, minHeight: 8, borderRadius: BorderRadius.circular(8))],
            const SizedBox(height: 8),
            Text(msg),
          ]),
        ),
      ),
      const SizedBox(height: 12),
      FilledButton.icon(onPressed: () => _edit(null), icon: const Icon(Icons.add), label: const Text('Add a goal')),
      TextButton.icon(
        onPressed: () async {
          await Navigator.push(context, MaterialPageRoute(builder: (_) => ChallengesPage(prefs: widget.prefs, onChanged: widget.onChanged)));
          if (mounted) setState(() => goals = loadGoals(widget.prefs));
        },
        icon: const Icon(Icons.flag_outlined),
        label: const Text('Try a 7-day challenge'),
      ),
      _section('Still on your list', overdue, hint: 'These slipped past their date. No pressure. Finish them, or edit the date.', color: const Color(0xFFD9480F)),
      _section('Today', today),
      _section('Coming up', upcoming),
      _section('Repeating, not today', other),
      if (done.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(top: 10),
          child: ExpansionTile(
            tilePadding: EdgeInsets.zero,
            title: Text('Completed (${done.length})', style: const TextStyle(fontWeight: FontWeight.bold)),
            children: [for (final g in done.take(20)) _tile(g)],
          ),
        ),
      if (goals.isEmpty) const Padding(padding: EdgeInsets.only(top: 24), child: Text('Nothing here yet. Goals can be for today, or stretch over days or weeks. Higher importance gets a few extra gentle reminders.', style: TextStyle(color: Colors.grey, height: 1.4))),
    ]);
  }
}

class _FocusDialog extends StatefulWidget {
  final String title;
  final int minutes;
  const _FocusDialog({required this.title, required this.minutes});
  @override
  State<_FocusDialog> createState() => _FocusDialogState();
}

class _FocusDialogState extends State<_FocusDialog> {
  late int left = widget.minutes * 60;
  Timer? _t;

  @override
  void initState() {
    super.initState();
    _t = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      setState(() => left--);
      if (left <= 0) {
        t.cancel();
        Navigator.pop(context, true);
      }
    });
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title, maxLines: 2, overflow: TextOverflow.ellipsis),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        Text('${left ~/ 60}:${(left % 60).toString().padLeft(2, '0')}', style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        const Text('One thing. Keep this screen open and give it your attention.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Stop')),
        TextButton(onPressed: () => Navigator.pop(context, widget.minutes * 60 - left >= 300), child: const Text('Finish early')),
      ],
    );
  }
}
