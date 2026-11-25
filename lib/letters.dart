import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'common.dart';
import 'store.dart';

List<Map<String, dynamic>> loadLetters(Store p) {
  try {
    return [for (final e in jsonDecode(p.getString('letters') ?? '[]') as List) Map<String, dynamic>.from(e as Map)];
  } catch (_) {
    return [];
  }
}

Future<void> saveLetters(Store p, List<Map<String, dynamic>> l) => p.setString('letters', jsonEncode(l));

bool _arrived(Map<String, dynamic> l) => '${l['deliver']}'.compareTo(dayKey(DateTime.now())) <= 0;

int unopenedLetters(Store p) => loadLetters(p).where((l) => _arrived(l) && l['opened'] != true).length;

/// Notification ids 3000+ for letters that have not arrived yet.
Future<void> scheduleLetters(FlutterLocalNotificationsPlugin n, Store p) async {
  if (kIsWeb) return;
  try {
    for (final s in p.getStringList('letter_nids') ?? <String>[]) {
      final id = int.tryParse(s);
      if (id != null) await n.cancel(id);
    }
    final ids = <String>[];
    final now = tz.TZDateTime.now(tz.local);
    var i = 0;
    for (final l in loadLetters(p)) {
      if (_arrived(l) || i >= 30) continue;
      final d = DateTime.parse('${l['deliver']}');
      final w = tz.TZDateTime(tz.local, d.year, d.month, d.day, 9, 0);
      if (!w.isAfter(now)) continue;
      await n.zonedSchedule(3000 + i, 'A letter from you', 'A letter you wrote to yourself has arrived. Open Shell to read it.', w,
          const NotificationDetails(android: AndroidNotificationDetails('letters', 'Letters to future me', channelDescription: 'Delivers letters you wrote to yourself', importance: Importance.high, priority: Priority.high), iOS: DarwinNotificationDetails()),
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime);
      ids.add('${3000 + i}');
      i++;
    }
    await p.setStringList('letter_nids', ids);
  } catch (_) {}
}

class LettersPage extends StatefulWidget {
  final Store prefs;
  final Future<void> Function() onChanged;
  const LettersPage({super.key, required this.prefs, required this.onChanged});
  @override
  State<LettersPage> createState() => _LettersPageState();
}

class _LettersPageState extends State<LettersPage> {
  late List<Map<String, dynamic>> letters = loadLetters(widget.prefs);

  Future<void> _save() async {
    await saveLetters(widget.prefs, letters);
    await widget.onChanged();
    if (mounted) setState(() {});
  }

  Future<void> _write() async {
    final c = TextEditingController();
    var days = 90;
    DateTime? custom;
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => Padding(
          padding: EdgeInsets.fromLTRB(18, 0, 18, MediaQuery.of(ctx).viewInsets.bottom + 18),
          child: SingleChildScrollView(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('A letter to future me', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              TextField(controller: c, maxLines: 8, minLines: 5, autofocus: true, textCapitalization: TextCapitalization.sentences, decoration: const InputDecoration(hintText: 'Dear me, here is where I am right now...', border: OutlineInputBorder())),
              const SizedBox(height: 12),
              const Text('Deliver it in', style: TextStyle(fontWeight: FontWeight.w600)),
              Wrap(spacing: 8, children: [
                for (final d in [30, 90, 365]) ChoiceChip(label: Text(d == 365 ? '1 year' : '$d days'), selected: custom == null && days == d, onSelected: (_) => setS(() { days = d; custom = null; })),
                ActionChip(
                  avatar: const Icon(Icons.event, size: 18),
                  label: Text(custom == null ? 'Pick a date' : dayKey(custom!)),
                  onPressed: () async {
                    final n = DateTime.now();
                    final d = await showDatePicker(context: ctx, initialDate: n.add(const Duration(days: 60)), firstDate: n.add(const Duration(days: 1)), lastDate: n.add(const Duration(days: 365 * 5)));
                    if (d != null) setS(() => custom = d);
                  },
                ),
              ]),
              const SizedBox(height: 12),
              Row(children: [
                const Spacer(),
                TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                const SizedBox(width: 8),
                FilledButton(onPressed: () => Navigator.pop(ctx, c.text.trim().isNotEmpty), child: const Text('Seal it')),
              ]),
            ]),
          ),
        ),
      ),
    );
    if (ok != true) return;
    final n = DateTime.now();
    final when = custom ?? DateTime(n.year, n.month, n.day + days);
    letters.add({'id': '${n.microsecondsSinceEpoch}', 'written': dayKey(n), 'deliver': dayKey(when), 'text': c.text.trim(), 'opened': false});
    await _save();
  }

  Future<void> _read(Map<String, dynamic> l) async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Written ${l['written']}'),
        content: SingleChildScrollView(child: Text('${l['text']}', style: const TextStyle(height: 1.4))),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close'))],
      ),
    );
    l['opened'] = true;
    await _save();
  }

  @override
  Widget build(BuildContext context) {
    final sorted = [...letters]..sort((a, b) => '${b['deliver']}'.compareTo('${a['deliver']}'));
    return Scaffold(
      appBar: AppBar(title: const Text('Letters to future me')),
      floatingActionButton: FloatingActionButton.extended(onPressed: _write, icon: const Icon(Icons.mail_outline), label: const Text('Write a letter')),
      body: ListView(padding: const EdgeInsets.fromLTRB(18, 18, 18, 90), children: [
        const Text('Write to the person you will be. It stays sealed on this phone until the day you choose, then you get a reminder.'),
        const SizedBox(height: 12),
        if (sorted.isEmpty) const Text('No letters yet.', style: TextStyle(color: Colors.grey)),
        for (final l in sorted)
          Card(
            elevation: 0,
            child: ListTile(
              leading: Icon(_arrived(l) ? (l['opened'] == true ? Icons.drafts_outlined : Icons.mark_email_unread_outlined) : Icons.lock_outline, color: const Color(0xFF21877C)),
              title: Text(_arrived(l) ? (l['opened'] == true ? 'Letter from ${l['written']}' : 'A letter has arrived!') : 'Sealed until ${l['deliver']}'),
              subtitle: Text('Written ${l['written']}'),
              onTap: _arrived(l) ? () => _read(l) : () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('It stays sealed until then. Future you will be glad.'))),
              trailing: IconButton(
                icon: const Icon(Icons.delete_outline),
                onPressed: () async {
                  letters.removeWhere((x) => x['id'] == l['id']);
                  await _save();
                },
              ),
            ),
          ),
      ]),
    );
  }
}
