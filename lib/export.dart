import 'dart:convert';
import 'package:archive/archive.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'platform.dart';
import 'store.dart';
import 'body.dart';
import 'common.dart';
import 'exercise.dart';
import 'planner.dart';

const _sections = <List<String>>[
  ['journal', 'Journal and daily check-ins'],
  ['body', 'Weight and body measurements'],
  ['exercise', 'Workout log'],
  ['connect', 'Connect reflections'],
  ['goals', 'Goals and planner'],
  ['profile', 'Profile settings (Male/Female, units, height)'],
];

Map<String, dynamic> _readEntries(Store p) {
  try {
    return Map<String, dynamic>.from(jsonDecode(p.getString('entries') ?? '{}') as Map);
  } catch (_) {
    return {};
  }
}

List<Map<String, dynamic>> _readBody(Store p) {
  try {
    return (jsonDecode(p.getString('body_log') ?? '[]') as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
  } catch (_) {
    return [];
  }
}

List<Map<String, dynamic>> _readConnect(Store p) {
  final out = <Map<String, dynamic>>[];
  for (final s in p.getStringList('connect_notes') ?? <String>[]) {
    try {
      out.add(Map<String, dynamic>.from(jsonDecode(s) as Map));
    } catch (_) {}
  }
  return out;
}

Map<String, List<String>> _readDone(Store p) {
  final out = <String, List<String>>{};
  for (final k in p.getKeys()) {
    if (k.startsWith('ex_done_')) {
      out[k.substring('ex_done_'.length)] = p.getStringList(k) ?? <String>[];
    }
  }
  return out;
}

Future<void> showExportDialog(BuildContext context, Store p) async {
  final picked = {for (final s in _sections) s[0]: true};
  final go = await showDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setS) => AlertDialog(
        title: const Text('Export my data'),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Choose what goes into the zip file. Nothing leaves your phone unless you share the file.', style: TextStyle(fontSize: 13)),
            const SizedBox(height: 8),
            ..._sections.map((s) => CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  value: picked[s[0]],
                  title: Text(s[1]),
                  onChanged: (v) => setS(() => picked[s[0]] = v ?? false),
                )),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Create zip')),
        ],
      ),
    ),
  );
  if (go != true) return;
  try {
    final names = <String, String>{};
    try {
      for (final e in await loadExercises()) {
        names[e.id] = e.name;
      }
    } catch (_) {}
    final archive = Archive();
    void add(String name, String content) {
      final b = utf8.encode(content);
      archive.addFile(ArchiveFile(name, b.length, b));
    }

    final data = <String, dynamic>{};
    if (picked['journal'] == true) {
      final entries = _readEntries(p);
      data['journal'] = {'start': p.getString('start'), 'entries': entries};
      final keys = entries.keys.toList()..sort();
      final sb = StringBuffer('﻿')..writeln(csvRow(['date', 'program_day', 'priority', 'mood_1_to_5', 'energy_1_to_5', 'action_completed', 'journal']));
      for (final k in keys) {
        final e = Map<String, dynamic>.from(entries[k] as Map);
        sb.writeln(csvRow([k, e['day'], e['priority'], e['mood'], e['energy'], e['completed'], e['journal']]));
      }
      add('journal.csv', sb.toString());
    }
    if (picked['body'] == true) {
      final log = _readBody(p);
      data['body'] = {'body_log': log};
      final sb = StringBuffer('﻿')..writeln(csvRow(['date', 'weight_kg', ...bodyFields.map((f) => '${f[0]}_cm')]));
      for (final e in log) {
        sb.writeln(csvRow([e['date'], e['weight_kg'], ...bodyFields.map((f) => e['${f[0]}_cm'])]));
      }
      add('body_measurements.csv', sb.toString());
    }
    if (picked['exercise'] == true) {
      final fin = p.getStringList('ex_log') ?? <String>[];
      final done = _readDone(p);
      data['exercise'] = {'workouts_finished': fin, 'exercises_done': done};
      final dates = {...fin, ...done.keys}.toList()..sort();
      final sb = StringBuffer('﻿')..writeln(csvRow(['date', 'workout_finished', 'exercises_done']));
      for (final d in dates) {
        sb.writeln(csvRow([d, fin.contains(d), (done[d] ?? <String>[]).map((id) => names[id] ?? id).join('; ')]));
      }
      add('workout_log.csv', sb.toString());
    }
    if (picked['connect'] == true) {
      final notes = _readConnect(p);
      data['connect'] = {'notes': notes};
      final sb = StringBuffer('﻿')..writeln(csvRow(['date', 'category', 'question', 'reflection']));
      for (final n in notes) {
        sb.writeln(csvRow([n['date'], n['category'], n['question'], n['note']]));
      }
      add('connect_reflections.csv', sb.toString());
    }
    if (picked['goals'] == true) {
      final goals = loadGoals(p);
      data['goals'] = {'goals': [for (final g in goals) g.toJson()]};
      final sb = StringBuffer('﻿')..writeln(csvRow(['title', 'importance_1_to_10', 'start_date', 'start_time', 'due_date', 'due_time', 'done', 'done_on', 'days_worked_on', 'notes']));
      for (final g in goals) {
        sb.writeln(csvRow([g.title, g.imp, g.start, g.stime, g.due, g.dtime, g.done, g.doneOn, g.worked.length, g.note]));
      }
      add('goals.csv', sb.toString());
    }
    if (picked['profile'] == true) {
      final prof = {'sex': p.getString('sex'), 'units': p.getString('units'), 'height_cm': p.getDouble('height_cm')};
      data['profile'] = prof;
      add('profile.json', const JsonEncoder.withIndent('  ').convert(prof));
    }
    final now = DateTime.now();
    add('data.json', const JsonEncoder.withIndent('  ').convert({
      'format': 'successful_life_export',
      'version': 1,
      'exported_on': dayKey(now),
      'sections': data,
    }));
    add('README.txt', '''Shell data export (${dayKey(now)})

This zip contains only what you chose to include. The app never collects your name, address, city, ZIP code, phone number or email, and this file contains none of those unless you typed them into your own journal.

Files:
- data.json: everything in one file. Use it to restore into Shell on a new phone (Settings > Import).
- journal.csv, body_measurements.csv, workout_log.csv, connect_reflections.csv, goals.csv: spreadsheet-friendly (open in Excel, Google Sheets, Numbers).
- profile.json: your Male/Female setting, units and height, if included.

Units: weights are in kilograms and measurements in centimeters. Dates are YYYY-MM-DD.

Share this file only with people you trust, such as a coach, doctor or therapist, and only if you choose to.
''');
    final bytes = ZipEncoder().encode(archive);
    if (bytes == null) throw Exception('zip failed');
    await saveDownload('shell_export_${dayKey(now)}.zip', bytes, 'application/zip', 'Shell data export');
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Export failed: $e')));
    }
  }
}

Future<void> importFromZip(BuildContext context, Store p) async {
  try {
    final res = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['zip'], withData: true);
    if (res == null || res.files.isEmpty) return;
    final bytes = res.files.single.bytes;
    if (bytes == null) throw Exception('could not read the file');
    final archive = ZipDecoder().decodeBytes(bytes);
    final f = archive.findFile('data.json');
    if (f == null) throw Exception('data.json not found. Use a zip made by this app.');
    final root = jsonDecode(utf8.decode(f.content as List<int>)) as Map;
    if (root['format'] != 'successful_life_export') throw Exception('not a Shell export');
    final sec = Map<String, dynamic>.from(root['sections'] as Map);
    if (!context.mounted) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Import data?'),
        content: Text('This will replace the matching data on this device with: ${sec.keys.join(', ')}.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Import')),
        ],
      ),
    );
    if (ok != true) return;
    if (sec['journal'] is Map) {
      final j = Map<String, dynamic>.from(sec['journal'] as Map);
      if (j['start'] != null) await p.setString('start', j['start'] as String);
      await p.setString('entries', jsonEncode(j['entries'] ?? {}));
    }
    if (sec['body'] is Map) {
      await p.setString('body_log', jsonEncode((sec['body'] as Map)['body_log'] ?? []));
    }
    if (sec['exercise'] is Map) {
      final ex = Map<String, dynamic>.from(sec['exercise'] as Map);
      await p.setStringList('ex_log', List<String>.from(ex['workouts_finished'] ?? []));
      final done = Map<String, dynamic>.from((ex['exercises_done'] ?? {}) as Map);
      for (final k in done.keys) {
        await p.setStringList('ex_done_$k', List<String>.from(done[k] as List));
      }
    }
    if (sec['connect'] is Map) {
      final notes = ((sec['connect'] as Map)['notes'] ?? []) as List;
      await p.setStringList('connect_notes', notes.map((n) => jsonEncode(n)).toList());
    }
    if (sec['goals'] is Map) {
      await p.setString('goals', jsonEncode((sec['goals'] as Map)['goals'] ?? []));
    }
    if (sec['profile'] is Map) {
      final pr = Map<String, dynamic>.from(sec['profile'] as Map);
      if (pr['sex'] != null) await p.setString('sex', pr['sex'] as String);
      if (pr['units'] != null) await p.setString('units', pr['units'] as String);
      if (pr['height_cm'] != null) await p.setDouble('height_cm', (pr['height_cm'] as num).toDouble());
    }
    if (context.mounted) {
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Import complete'),
          content: const Text('Close the app completely and open it again to see your restored data.'),
          actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK'))],
        ),
      );
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Import failed: $e')));
    }
  }
}
