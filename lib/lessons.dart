import 'package:flutter/material.dart';
import 'areas.dart';
import 'common.dart';
import 'goal_actions.dart';
import 'lessons_data.dart';
import 'store.dart';
import 'theme.dart';

export 'lessons_data.dart';

List<Lesson> lessonsFor(String area) => lessons.where((l) => l.area == area).toList();

/// Entries look like "area:Title|yyyy-MM-dd".
Map<String, String> lessonsDone(Store p) {
  final m = <String, String>{};
  for (final s in p.getStringList('lessons_done') ?? <String>[]) {
    final i = s.lastIndexOf('|');
    if (i > 0) m[s.substring(0, i)] = s.substring(i + 1);
  }
  return m;
}

Future<void> setLessonDone(Store p, Lesson l, bool done) async {
  final m = lessonsDone(p);
  if (done) {
    m[l.id] = dayKey(DateTime.now());
  } else {
    m.remove(l.id);
  }
  await p.setStringList('lessons_done', [for (final e in m.entries) '${e.key}|${e.value}']);
}

Lesson? nextLesson(Store p, String area) {
  final d = lessonsDone(p);
  for (final l in lessonsFor(area)) {
    if (!d.containsKey(l.id)) return l;
  }
  return null;
}

/// Short lesson card in a bottom sheet. "Explain" reveals the longer version.
Future<void> showLesson(BuildContext context, Store p, Lesson l, {VoidCallback? onChanged}) async {
  final a = areaById(l.area);
  var more = false;
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setS) {
        final done = lessonsDone(p).containsKey(l.id);
        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.85),
            child: ListView(padding: const EdgeInsets.fromLTRB(20, 0, 20, 20), children: [
              Row(children: [Icon(a.icon, color: a.color, size: 18), const SizedBox(width: 6), Text(a.name.toUpperCase(), style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: a.color))]),
              const SizedBox(height: 6),
              Text(l.title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              Text(l.short, style: const TextStyle(fontSize: 17, height: 1.4)),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: tint(ctx, Color.lerp(Colors.white, a.color, 0.14)!), borderRadius: BorderRadius.circular(12)),
                child: Text.rich(TextSpan(children: [const TextSpan(text: 'Try this: ', style: TextStyle(fontWeight: FontWeight.bold)), TextSpan(text: l.action)]), style: const TextStyle(height: 1.4)),
              ),
              if (more) ...[
                const SizedBox(height: 14),
                Text(l.explain, style: const TextStyle(height: 1.5)),
                if (l.area == 'emotional' || l.area == 'work' || l.area == 'physical')
                  const Padding(padding: EdgeInsets.only(top: 8), child: Text('General education only, not medical, mental health or financial advice.', style: TextStyle(fontSize: 12, color: Colors.grey))),
              ],
              const SizedBox(height: 14),
              Wrap(spacing: 8, runSpacing: 4, children: [
                if (!more) OutlinedButton(onPressed: () => setS(() => more = true), child: const Text('Explain')),
                OutlinedButton.icon(
                  onPressed: () async {
                    await addToGoalsSheet(ctx, p, l.action, area: l.area);
                    onChanged?.call();
                  },
                  icon: const Icon(Icons.flag_outlined),
                  label: const Text('Add to my goals'),
                ),
                FilledButton.icon(
                  onPressed: () async {
                    await setLessonDone(p, l, !done);
                    setS(() {});
                    onChanged?.call();
                    if (!done && ctx.mounted) Navigator.pop(ctx);
                  },
                  icon: Icon(done ? Icons.undo : Icons.check),
                  label: Text(done ? 'Mark as not learned' : 'Got it'),
                ),
              ]),
            ]),
          ),
        );
      },
    ),
  );
}
