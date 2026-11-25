import 'package:flutter/material.dart';
import 'planner.dart';
import 'store.dart';

/// "Add to my goals" from exercises and Connect questions.
Future<void> addToGoalsSheet(BuildContext context, Store p, String title, {String note = ''}) async {
  final pick = await showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    builder: (ctx) => SafeArea(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Padding(padding: const EdgeInsets.fromLTRB(20, 0, 20, 8), child: Text('Add to my goals:\n$title', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600))),
        ListTile(leading: const Icon(Icons.today), title: const Text('Today'), onTap: () => Navigator.pop(ctx, 'today')),
        ListTile(leading: const Icon(Icons.event), title: const Text('Tomorrow'), onTap: () => Navigator.pop(ctx, 'tomorrow')),
        ListTile(leading: const Icon(Icons.repeat), title: const Text('Every day'), onTap: () => Navigator.pop(ctx, 'daily')),
        ListTile(leading: const Icon(Icons.date_range), title: const Text('Three days a week (Mon, Wed, Fri)'), onTap: () => Navigator.pop(ctx, 'mwf')),
      ]),
    ),
  );
  if (pick == null) return;
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  switch (pick) {
    case 'today':
      await addGoal(p, title: title, note: note);
    case 'tomorrow':
      await addGoal(p, title: title, note: note, start: DateTime(today.year, today.month, today.day + 1));
    case 'daily':
      await addGoal(p, title: title, note: note, rep: 'daily');
    default:
      await addGoal(p, title: title, note: note, rep: 'days', rdays: [1, 3, 5]);
  }
  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Added. Find it under Today > Goals.')));
  }
}
