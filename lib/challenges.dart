import 'package:flutter/material.dart';
import 'planner.dart';
import 'store.dart';

const challengeArea = {'Movement': 'physical', 'Focus': 'intellectual', 'Mind': 'intellectual', 'Connection': 'social', 'Body': 'physical', 'Home': 'work', 'Rest': 'emotional'};

const challenges = <(String, String, String)>[
  ('Move every day', 'Walk or stretch for at least 10 minutes.', 'Movement'),
  ('Phone-free first hour', 'Skip your phone for the first hour after waking.', 'Focus'),
  ('Listen first', 'Listen for a full minute, say back what you heard, then ask one follow-up question.', 'Connection'),
  ('Assume good intent', 'When someone irritates you, write one innocent explanation for what they did.', 'Connection'),
  ('Daily gratitude', 'Write down three things you are grateful for.', 'Mind'),
  ('Reach out', 'Message one person you care about each day.', 'Connection'),
  ('Water first', 'Drink a full glass of water before anything else.', 'Body'),
  ('Tidy ten', 'Spend 10 minutes tidying one small space.', 'Home'),
  ('Read a little', 'Read ten pages or ten minutes.', 'Mind'),
  ('Lights out on time', 'Go to bed at your planned time.', 'Rest'),
];

class ChallengesPage extends StatelessWidget {
  final Store prefs;
  final Future<void> Function() onChanged;
  const ChallengesPage({super.key, required this.prefs, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('7-day challenges')),
      body: ListView(padding: const EdgeInsets.all(18), children: [
        const Text('Pick one small challenge for a week. It is added to your goals, and you can tick each day.'),
        const SizedBox(height: 10),
        for (final c in challenges)
          Card(
            elevation: 0,
            child: ListTile(
              title: Text(c.$1, style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text(c.$2),
              trailing: FilledButton.tonal(
                onPressed: () async {
                  await addGoal(prefs, title: '7 days: ${c.$1}', note: c.$2, imp: 6, days: 7, area: challengeArea[c.$3] ?? '');
                  await onChanged();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Started: ${c.$1}. Find it under Goals.')));
                    Navigator.pop(context);
                  }
                },
                child: const Text('Start'),
              ),
            ),
          ),
      ]),
    );
  }
}
