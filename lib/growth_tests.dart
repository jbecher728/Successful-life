import 'dart:convert';
import 'package:flutter/material.dart';
import 'areas.dart';
import 'common.dart';
import 'goal_actions.dart';
import 'store.dart';
import 'theme.dart';

class GStatement {
  final String text, action;
  const GStatement(this.text, this.action);
}

/// Eight self-reflection statements per life area, each with one tiny action.
const growthStatements = <String, List<GStatement>>{
  'physical': [
    GStatement('I move my body in a way I enjoy on most days.', 'Take a 15-minute walk today.'),
    GStatement('I usually get enough sleep to feel rested.', 'Pick a wind-down time tonight and keep it.'),
    GStatement('Most of my meals include real, whole foods.', 'Add one vegetable or fruit to your next meal.'),
    GStatement('I drink enough water through the day.', 'Keep a water bottle next to you today.'),
    GStatement('I have the energy to do the things that matter to me.', 'Notice when your energy dips and plan a short break there.'),
    GStatement('I look after aches, illness and check-ups instead of ignoring them.', 'Book or plan one overdue check-up.'),
    GStatement('I can give my body both effort and real rest.', 'Plan one proper rest day this week.'),
    GStatement('I feel strong and capable in my body.', 'Do one workout from the Fitness tab.'),
  ],
  'intellectual': [
    GStatement('I regularly learn something new.', 'Spend 10 minutes on something you are curious about.'),
    GStatement('I read or listen to things that stretch my thinking.', 'Pick one book or podcast and start it.'),
    GStatement('I ask questions when I do not understand something.', 'Write down one question and look it up.'),
    GStatement('I can change my mind when I see good evidence.', 'Read one viewpoint that differs from yours.'),
    GStatement('I set aside time to focus deeply without distractions.', 'Do one 25-minute focus session with your phone away.'),
    GStatement('I use what I learn in real life.', 'Pick one lesson and try it this week.'),
    GStatement('I feel curious more often than bored.', 'Try one new thing today, however small.'),
    GStatement('I keep my mind active with projects, puzzles or skills.', 'Choose a small skill and practice it for 10 minutes.'),
  ],
  'emotional': [
    GStatement('I can name what I am feeling most of the time.', 'Make a mood entry in the Journal today.'),
    GStatement('I have healthy ways to calm down when I am stressed.', 'Try the one-minute Calm timer.'),
    GStatement('I can sit with a hard feeling without being swept away.', 'Take three slow breaths the next time a feeling rises.'),
    GStatement('I am kind to myself when I make mistakes.', 'Say to yourself what you would say to a friend.'),
    GStatement('I recover from setbacks in a reasonable time.', 'Write down one thing a recent setback taught you.'),
    GStatement('I let myself enjoy good things too.', 'Note three good things tonight.'),
    GStatement('I ask for support when I need it.', 'Tell one person how you are really doing.'),
    GStatement('I generally feel at peace with who I am.', 'Write a short list of things you accept about yourself.'),
  ],
  'social': [
    GStatement('I have people I can really be myself with.', 'Reach out to one of them today.'),
    GStatement('I stay in touch with the people who matter to me.', 'Message someone you have not spoken to lately.'),
    GStatement('I listen well without rushing to fix or defend.', 'Listen for one full minute in your next conversation.'),
    GStatement('I say what I need clearly and kindly.', 'Ask for one specific thing this week.'),
    GStatement('I show appreciation to the people in my life.', 'Tell someone one thing you appreciate about them.'),
    GStatement('I can handle disagreements without damaging the relationship.', 'In your next disagreement, restate their view before replying.'),
    GStatement('I give time and attention to my closest relationships.', 'Plan a call or visit this week.'),
    GStatement('I feel that I belong somewhere.', 'Join or revisit a group or activity you enjoy.'),
  ],
  'work': [
    GStatement('My work gives me a sense of purpose or progress.', 'Write down one thing you want from your work this year.'),
    GStatement('I am building skills that matter for my career.', 'Pick one skill and schedule 30 minutes for it.'),
    GStatement('I roughly know what I earn and spend each month.', 'List this month\'s main expenses.'),
    GStatement('I set aside some money for the future, even if it is small.', 'Move a small amount into savings.'),
    GStatement('I have a plan for unexpected expenses.', 'Start or add to an emergency cushion.'),
    GStatement('I keep a healthy boundary between work and rest.', 'Pick a daily end-of-work time and keep it.'),
    GStatement('I am handling debt and big bills calmly.', 'Write down what you owe and the next step.'),
    GStatement('I feel stable and confident about my near-term future.', 'Name your biggest money or job worry and one step toward it.'),
  ],
  'understand': [
    GStatement('I let people finish speaking before I respond.', 'Let the next person finish fully, then pause a second before answering.'),
    GStatement('I notice when someone is upset, even if they do not say so.', 'Notice one person\'s tone or body language today.'),
    GStatement('I ask questions to understand before I assume.', 'Ask one "what" or "how" question in your next conversation.'),
    GStatement('I can see a situation from the other person\'s side, even when I disagree.', 'Use "See it from their side" on a recent moment.'),
    GStatement('I assume good intent more often than bad.', 'Write two innocent explanations for a recent irritation.'),
    GStatement('I say back what I heard to check that I got it right.', 'Say "So what you are saying is..." once today.'),
    GStatement('I stay calm when someone sees things differently from me.', 'Take one slow breath before replying to a disagreement.'),
    GStatement('People tell me when something is bothering them.', 'Ask someone, "Is there anything on your mind lately?"'),
  ],
  'spiritual': [
    GStatement('I know what matters most to me.', 'Write down your top three values.'),
    GStatement('My daily choices mostly match those values.', 'Pick one choice today that reflects a value.'),
    GStatement('I make time for quiet, reflection or prayer, in whatever form suits me.', 'Take five quiet minutes today.'),
    GStatement('I feel part of something larger than myself.', 'Spend time in nature or give time to a cause.'),
    GStatement('I have a sense of purpose that carries me through hard times.', 'Write one sentence about what your life is for.'),
    GStatement('I practice gratitude.', 'Note three things you are grateful for.'),
    GStatement('I forgive myself and others, or I am working toward it.', 'Write a letter you will not send, or one you will.'),
    GStatement('I am at peace with the big questions, or at ease not knowing.', 'Journal on one big question for five minutes.'),
  ],
};

const _choices = ['Not like me', 'A little like me', 'Somewhat like me', 'Mostly like me', 'Very much like me'];

Area _area(String id) => areas.firstWhere((a) => a.id == (id == 'understand' ? 'social' : id));

/// Saved results: area id -> list of {d: date, a: [answers 1..5]}, oldest first.
Map<String, List<Map<String, dynamic>>> loadGrowth(Store p) {
  try {
    final m = jsonDecode(p.getString('growth_tests') ?? '{}') as Map;
    return {
      for (final e in m.entries) e.key.toString(): [for (final r in e.value as List) Map<String, dynamic>.from(r as Map)],
    };
  } catch (_) {
    return {};
  }
}

int scorePercent(List<int> a) {
  if (a.isEmpty) return 0;
  final s = a.fold<int>(0, (t, x) => t + (x - 1));
  return (s * 100 / (a.length * 4)).round();
}

String bandFor(int pct) => pct < 35 ? 'Early days' : pct < 55 ? 'Building' : pct < 75 ? 'Steady' : 'Strong';

List<int> _answers(Map<String, dynamic> r) => [for (final x in (r['a'] as List)) (x as num).toInt()];

Future<void> saveGrowth(Store p, String id, List<int> answers) async {
  final m = loadGrowth(p);
  final l = m[id] ?? [];
  l.add({'d': dayKey(DateTime.now()), 'a': answers});
  m[id] = l.length > 20 ? l.sublist(l.length - 20) : l;
  await p.setString('growth_tests', jsonEncode(m));
}

// ------------------------------------------------------------------ list

class GrowthListPage extends StatefulWidget {
  final Store prefs;
  const GrowthListPage({super.key, required this.prefs});
  @override
  State<GrowthListPage> createState() => _GrowthListPageState();
}

class _GrowthListPageState extends State<GrowthListPage> {
  @override
  Widget build(BuildContext context) {
    final p = widget.prefs;
    final all = loadGrowth(p);
    return Scaffold(
      appBar: AppBar(title: const Text('Growth check-ins')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        const Text('A short check-in for each area of life: eight statements, about two minutes. Answer honestly for how things are lately. These are for your own reflection, not scientific or clinical tests, and your answers stay on this device. Retake any time to see how you have changed.'),
        const SizedBox(height: 12),
        for (final a in areas)
          Builder(builder: (context) {
            final l = all[a.id] ?? [];
            final last = l.isEmpty ? null : l.last;
            final pct = last == null ? null : scorePercent(_answers(last));
            String sub = 'Not taken yet';
            if (last != null) {
              sub = '${bandFor(pct!)}  •  $pct%  •  ${last['d']}';
              if (l.length > 1) {
                final d = pct - scorePercent(_answers(l[l.length - 2]));
                sub += d == 0 ? '  •  same as before' : '  •  ${d > 0 ? '+' : ''}$d since before';
              }
            }
            return Card(
              elevation: 0,
              color: cardBg(context),
              child: ListTile(
                leading: CircleAvatar(backgroundColor: a.color.withValues(alpha: 0.18), child: Icon(a.icon, color: a.color)),
                title: Text(a.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Text(sub),
                trailing: const Icon(Icons.chevron_right),
                onTap: () async {
                  await Navigator.push(context, MaterialPageRoute(builder: (_) => GrowthTestPage(prefs: p, areaId: a.id)));
                  if (mounted) setState(() {});
                },
              ),
            );
          }),
      ]),
    );
  }
}

// ------------------------------------------------------------------ test

class GrowthTestPage extends StatefulWidget {
  final Store prefs;
  final String areaId;
  const GrowthTestPage({super.key, required this.prefs, required this.areaId});
  @override
  State<GrowthTestPage> createState() => _GrowthTestPageState();
}

class _GrowthTestPageState extends State<GrowthTestPage> {
  final List<int> ans = [];
  bool done = false;
  List<int>? before;

  List<GStatement> get qs => growthStatements[widget.areaId]!;

  Future<void> _pick(int v) async {
    ans.add(v);
    if (ans.length == qs.length) {
      final prev = loadGrowth(widget.prefs)[widget.areaId] ?? [];
      before = prev.isEmpty ? null : _answers(prev.last);
      await saveGrowth(widget.prefs, widget.areaId, List<int>.from(ans));
      if (mounted) setState(() => done = true);
    } else {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final a = _area(widget.areaId);
    return Scaffold(
      appBar: AppBar(title: Text(widget.areaId == 'understand' ? 'Understanding others' : '${a.name} check-in')),
      body: ListView(padding: const EdgeInsets.all(20), children: done ? _result(context, a) : _question(context, a)),
    );
  }

  List<Widget> _question(BuildContext context, Area a) {
    final i = ans.length;
    return [
      Text('Statement ${i + 1} of ${qs.length}', style: TextStyle(fontWeight: FontWeight.w700, color: a.color)),
      const SizedBox(height: 6),
      LinearProgressIndicator(value: i / qs.length, minHeight: 6, borderRadius: BorderRadius.circular(6), color: a.color),
      const SizedBox(height: 20),
      Card(
        elevation: 0,
        color: tint(context, a.color.withValues(alpha: 0.12)),
        child: Padding(padding: const EdgeInsets.all(22), child: Text(qs[i].text, style: const TextStyle(fontSize: 20, height: 1.4, fontWeight: FontWeight.w600))),
      ),
      const SizedBox(height: 6),
      const Text('How true is this for you lately?', style: TextStyle(color: Colors.grey)),
      const SizedBox(height: 12),
      for (var v = 1; v <= 5; v++)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: OutlinedButton(onPressed: () => _pick(v), style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)), child: Text(_choices[v - 1])),
        ),
      if (i > 0) TextButton.icon(onPressed: () => setState(() => ans.removeLast()), icon: const Icon(Icons.arrow_back), label: const Text('Back')),
    ];
  }

  List<Widget> _result(BuildContext context, Area a) {
    final pct = scorePercent(ans);
    final order = [for (var i = 0; i < ans.length; i++) i]..sort((x, y) => ans[x] != ans[y] ? ans[x].compareTo(ans[y]) : x.compareTo(y));
    final grow = order.where((i) => ans[i] <= 3).take(2).toList();
    final strong = order.reversed.where((i) => ans[i] >= 4).take(2).toList();
    final prevPct = before == null ? null : scorePercent(before!);
    final rating = (pct / 10).round().clamp(1, 10);
    return [
      const SizedBox(height: 4),
      Icon(a.icon, size: 40, color: a.color),
      const SizedBox(height: 8),
      Center(child: Text(bandFor(pct), style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold))),
      const SizedBox(height: 4),
      Center(child: Text('$pct%', style: TextStyle(fontSize: 18, color: a.color, fontWeight: FontWeight.w700))),
      const SizedBox(height: 8),
      LinearProgressIndicator(value: pct / 100, minHeight: 10, borderRadius: BorderRadius.circular(8), color: a.color),
      if (prevPct != null) ...[
        const SizedBox(height: 8),
        Center(child: Text(pct == prevPct ? 'Same as last time ($prevPct%).' : 'Last time: $prevPct%. ${pct > prevPct ? 'Up' : 'Down'} ${(pct - prevPct).abs()} points.', style: const TextStyle(color: Colors.grey))),
      ],
      const SizedBox(height: 6),
      const Center(child: Text('A snapshot of how you see things right now, not a verdict.', style: TextStyle(fontSize: 12, color: Colors.grey))),
      if (strong.isNotEmpty) ...[
        const SizedBox(height: 18),
        const Text('Going well', style: TextStyle(fontWeight: FontWeight.w700)),
        for (final i in strong) Padding(padding: const EdgeInsets.only(top: 6), child: Text('• ${qs[i].text}')),
      ],
      if (grow.isNotEmpty) ...[
        const SizedBox(height: 18),
        const Text('Room to grow', style: TextStyle(fontWeight: FontWeight.w700)),
        for (final i in grow)
          Card(
            elevation: 0,
            color: cardBg(context),
            margin: const EdgeInsets.only(top: 8),
            child: ListTile(
              title: Text(qs[i].text),
              subtitle: Text('Try: ${qs[i].action}'),
              trailing: IconButton(tooltip: 'Add to my goals', icon: const Icon(Icons.add_circle_outline), onPressed: () => addToGoalsSheet(context, widget.prefs, qs[i].action, area: a.id)),
            ),
          ),
      ] else ...[
        const SizedBox(height: 18),
        const Text('Nothing stands out as a weak spot. Keep doing what works.'),
      ],
      const SizedBox(height: 18),
      if (widget.areaId != 'understand') OutlinedButton(
        onPressed: () async {
          await setRating(widget.prefs, a.id, rating);
          if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${a.name} satisfaction set to $rating/10.')));
        },
        child: Text('Use this as my ${a.name} rating ($rating/10)'),
      ),
      if (a.id == 'emotional')
        const Padding(
          padding: EdgeInsets.only(top: 12),
          child: Text('If you have felt low, anxious or overwhelmed for a while, talking with someone you trust or a counselor can really help. A check-in like this cannot tell you what is going on.', style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic)),
        ),
      const SizedBox(height: 14),
      const Text('Retaking this in a month or so shows how things are changing. Only your own answers on this device are used.', style: TextStyle(fontSize: 12, color: Colors.grey)),
      const SizedBox(height: 14),
      FilledButton(onPressed: () => Navigator.pop(context), child: const Text('Done')),
    ];
  }
}
