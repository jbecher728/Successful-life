import 'package:flutter/material.dart';
import 'export.dart';
import 'letters.dart';
import 'review.dart';
import 'store.dart';
import 'theme.dart';

const _teal = Color(0xFF21877C);

const journalPrompts = [
  'What is one thing I am proud of lately?',
  'Who made my day easier recently, and how can I thank them?',
  'What would I do today if I were not afraid of failing?',
  'What drained me this week, and what gave me energy?',
  'Describe a small moment today that I want to remember.',
  'What is one habit I would like to carry for the next year?',
  'What did I avoid today, and what is one tiny step toward it?',
  'Which of my strengths helped me recently?',
  'What would I tell a close friend who felt the way I do right now?',
  'What am I grateful for that I usually overlook?',
  'What is one thing I can forgive myself for?',
  'What does a good day look like for me?',
  'Where do I feel stuck, and what is one different way to look at it?',
  'Who do I want to be closer to, and what is one way to start?',
  'What did I learn from a recent mistake?',
  'What do I need more of in my life? What do I need less of?',
  'What is something I did that was hard but worth it?',
  'Which promise to myself do I most want to keep this week?',
  'What are three small wins from the past few days?',
  'What is my body telling me today?',
  'What would make tomorrow feel like a success?',
  'What am I looking forward to?',
  'What is one boundary that would help me?',
  'When did I feel most like myself recently?',
  'What would my future self thank me for doing today?',
  'What is one kind thing I can do for someone this week?',
  'What worry can I set down for tonight?',
  'What did I do today that I would do again?',
  'What is one thing I want to get better at, and why?',
  'What would I like to be remembered for?',
  'What is a simple pleasure I should make time for?',
];

String journalPromptFor(DateTime d) {
  final doy = d.difference(DateTime(d.year, 1, 1)).inDays;
  return journalPrompts[doy % journalPrompts.length];
}

Widget _card(BuildContext ctx, Color c, Widget child) => Card(elevation: 0, color: tint(ctx, c), margin: const EdgeInsets.only(top: 10), child: child);

/// "I am becoming..." one-liner at the top of Today.
class IdentityLine extends StatelessWidget {
  final Store prefs;
  final VoidCallback onChanged;
  const IdentityLine({super.key, required this.prefs, required this.onChanged});

  Future<void> _edit(BuildContext context) async {
    final c = TextEditingController(text: prefs.getString('identity') ?? '');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Who are you becoming?'),
        content: TextField(controller: c, autofocus: true, maxLength: 80, textCapitalization: TextCapitalization.sentences, decoration: const InputDecoration(hintText: 'A calm, strong, kind person')),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save'))],
      ),
    );
    if (ok == true) {
      await prefs.setString('identity', c.text.trim());
      onChanged();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!extraOn(prefs, 'identity')) return const SizedBox.shrink();
    final v = (prefs.getString('identity') ?? '').trim();
    return InkWell(
      onTap: () => _edit(context),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.only(top: 8),
        child: v.isEmpty
            ? const Text('Tap to write who you are becoming', style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic))
            : Text.rich(TextSpan(children: [const TextSpan(text: 'I am becoming ', style: TextStyle(color: Colors.grey)), TextSpan(text: v, style: const TextStyle(fontWeight: FontWeight.w600, color: _teal))])),
      ),
    );
  }
}

/// Weekly review and backup nudges, only when relevant.
class TodayNudges extends StatelessWidget {
  final Store prefs;
  final VoidCallback onChanged;
  const TodayNudges({super.key, required this.prefs, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final w = <Widget>[];
    if (extraOn(prefs, 'review') && (now.weekday >= DateTime.friday || now.weekday == DateTime.monday)) {
      w.add(_card(
        context,
        const Color(0xFFFFF8E6),
        ListTile(
          leading: const Icon(Icons.insights, color: Color(0xFFB7791F)),
          title: const Text('Your week in review', style: TextStyle(fontWeight: FontWeight.w700)),
          subtitle: const Text('See how the week went and plan the next.'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () async {
            await Navigator.push(context, MaterialPageRoute(builder: (_) => WeeklyReviewPage(prefs: prefs)));
            onChanged();
          },
        ),
      ));
    }
    if (extraOn(prefs, 'letters') && unopenedLetters(prefs) > 0) {
      w.add(_card(
        context,
        const Color(0xFFF3EAFB),
        ListTile(
          leading: const Icon(Icons.mark_email_unread_outlined, color: Color(0xFF7B4EA3)),
          title: const Text('A letter from past you has arrived', style: TextStyle(fontWeight: FontWeight.w700)),
          trailing: const Icon(Icons.chevron_right),
          onTap: () async {
            await Navigator.push(context, MaterialPageRoute(builder: (_) => LettersPage(prefs: prefs, onChanged: () async {})));
            onChanged();
          },
        ),
      ));
    }
    if (backupDue(prefs)) {
      w.add(_card(
        context,
        const Color(0xFFEEF1FB),
        Padding(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Back up your data', style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            const Text('Everything lives only on this phone. A quick export keeps a copy safe.'),
            Row(children: [
              TextButton(
                onPressed: () async {
                  await prefs.setString('backup_snooze', DateTime.now().add(const Duration(days: 14)).toIso8601String().substring(0, 10));
                  onChanged();
                },
                child: const Text('Not now'),
              ),
              const Spacer(),
              FilledButton(
                onPressed: () async {
                  await showExportDialog(context, prefs);
                  onChanged();
                },
                child: const Text('Export now'),
              ),
            ]),
          ]),
        ),
      ));
    }
    return Column(children: w);
  }
}
