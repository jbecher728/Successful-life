import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'common.dart';
import 'goal_actions.dart';
import 'planner.dart';
import 'review.dart';
import 'store.dart';
import 'theme.dart';

class Area {
  final String id, name, short, blurb;
  final IconData icon;
  final Color color;
  final List<String> ideas, prompts;
  const Area(this.id, this.name, this.short, this.blurb, this.icon, this.color, this.ideas, this.prompts);
}

const areas = <Area>[
  Area('physical', 'Physical', 'Body', 'Health and fitness: movement, sleep, food and rest.', Icons.fitness_center, Color(0xFFE4572E), [
    'Take a 20-minute walk outside.',
    'Do one workout from the Fitness tab.',
    'Go to bed 30 minutes earlier tonight.',
    'Drink water with every meal today.',
    'Stretch for 10 minutes.',
    'Cook one simple, healthy meal.',
    'Book an overdue check-up.',
    'Try a new kind of movement this week.',
  ], [
    'How does my body feel today, and what does it need?',
    'What is one healthy habit I want to keep for a year?',
    'When do I feel strongest and most energetic?',
  ]),
  Area('intellectual', 'Intellectual', 'Mind', 'Knowledge and learning: curiosity, skills and ideas.', Icons.menu_book, Color(0xFF3A7BD5), [
    'Read ten pages of a book.',
    'Learn one new thing and explain it to someone.',
    'Spend 20 minutes practicing a skill.',
    'Watch or listen to a talk on a topic you know little about.',
    'Write down three questions you are curious about.',
    'Pick one course or tutorial to start this month.',
    'Try a puzzle or brain game.',
    'Teach someone something you know.',
  ], [
    'What am I curious about right now?',
    'What skill would change my life most if I got better at it?',
    'What did I learn recently that surprised me?',
  ]),
  Area('emotional', 'Emotional', 'Feelings', 'Feelings and mental well-being: awareness, calm and resilience.', Icons.favorite_border, Color(0xFFD6619A), [
    'Name what you feel, out loud or on paper.',
    'Do a one-minute breathing break in Calm.',
    'Write a few lines in your journal tonight.',
    'Do something just because it brings you joy.',
    'Spend 30 minutes away from screens.',
    'Say no to one thing that drains you.',
    'Notice one thing you handled well today.',
    'Talk to someone you trust about how you really are.',
  ], [
    'What feeling has shown up most this week, and what is it telling me?',
    'What helps me calm down when I am stressed?',
    'What am I being too hard on myself about?',
  ]),
  Area('social', 'Social', 'People', 'Friendships, family and romantic relationships.', Icons.people_outline, Color(0xFFF2A516), [
    'Message a friend you have not talked to in a while.',
    'Ask a family member a real question and listen.',
    'Plan a coffee, walk or call with someone.',
    'Thank someone specifically for something they did.',
    'Use a Connect question with a friend or partner.',
    'Put your phone away during a meal with others.',
    'Make amends or clear the air with someone.',
    'Say yes to an invitation you would normally skip.',
  ], [
    'Who makes my life better, and have they heard that from me?',
    'Which relationship needs more of my attention right now?',
    'How do I show up for the people I love?',
  ]),
  Area('work', 'Occupational & financial', 'Work & money', 'Career, money and stability.', Icons.work_outline, Color(0xFF5B8E23), [
    'Write down this month’s income and spending.',
    'Set one money goal and one small step toward it.',
    'Spend 30 minutes on a project that moves your career forward.',
    'Update your resume or a work profile.',
    'Cancel one subscription you do not use.',
    'Ask for feedback from someone you work with.',
    'Move a little money into savings.',
    'Learn one thing about budgeting or investing.',
  ], [
    'Am I building the work life I actually want?',
    'What is one money habit I want to change?',
    'What would make me feel more secure and stable?',
  ]),
  Area('spiritual', 'Spiritual', 'Purpose', 'Purpose, values and beliefs. It does not have to be religion.', Icons.spa_outlined, Color(0xFF8E5BD0), [
    'Write down your top three values.',
    'Spend ten quiet minutes in stillness, prayer or reflection.',
    'Spend time in nature without a screen.',
    'Do something kind for someone with no credit.',
    'Write what a meaningful life looks like to you.',
    'Volunteer or give to a cause you believe in.',
    'Read something that challenges or inspires your beliefs.',
    'Check one choice today against your values.',
  ], [
    'What do I value most, and does my week reflect it?',
    'What gives my life meaning and purpose?',
    'What do I want to be remembered for?',
  ]),
];

Area areaById(String id) => areas.firstWhere((a) => a.id == id, orElse: () => areas.first);
bool hasArea(String id) => areas.any((a) => a.id == id);

/// The prompt of the day, rotating through the six areas.
(Area, String) areaPromptFor(DateTime d) {
  final doy = d.difference(DateTime(d.year, 1, 1)).inDays;
  final a = areas[doy % areas.length];
  return (a, a.prompts[(doy ~/ areas.length) % a.prompts.length]);
}

(Area, String) areaIdeaFor(Area a, DateTime d) {
  final doy = d.difference(DateTime(d.year, 1, 1)).inDays;
  return (a, a.ideas[(doy + areas.indexOf(a)) % a.ideas.length]);
}

// ------------------------------------------------------------------ data

Map<String, List<List<dynamic>>> _ratings(Store p) {
  try {
    final m = jsonDecode(p.getString('area_ratings') ?? '{}') as Map;
    return {for (final e in m.entries) '${e.key}': [for (final r in e.value as List) List<dynamic>.from(r as List)]};
  } catch (_) {
    return {};
  }
}

int? ratingOf(Store p, String id) {
  final l = _ratings(p)[id];
  if (l == null || l.isEmpty) return null;
  return (l.last[1] as num).toInt();
}

String? ratingDate(Store p) {
  String? best;
  for (final l in _ratings(p).values) {
    if (l.isNotEmpty) {
      final d = '${l.last[0]}';
      if (best == null || d.compareTo(best) > 0) best = d;
    }
  }
  return best;
}

Future<void> setRating(Store p, String id, int v) async {
  final m = _ratings(p);
  final today = dayKey(DateTime.now());
  final l = m[id] ?? [];
  if (l.isNotEmpty && l.last[0] == today) {
    l.last[1] = v;
  } else {
    l.add([today, v]);
  }
  m[id] = l.length > 60 ? l.sublist(l.length - 60) : l;
  await p.setString('area_ratings', jsonEncode(m));
}

/// How many things you did for each area in the last [days] days.
Map<String, int> areaActivity(Store p, {int days = 30}) {
  final now = DateTime.now();
  final keys = {for (var i = 0; i < days; i++) dayKey(DateTime(now.year, now.month, now.day - i))};
  final r = {for (final a in areas) a.id: 0};
  void add(String id, int n) {
    if (r.containsKey(id)) r[id] = r[id]! + n;
  }
  for (final g in loadGoals(p)) {
    var n = g.dones.where(keys.contains).length + g.worked.where(keys.contains).length;
    if (!g.repeats && g.done && keys.contains(g.doneOn)) n++;
    add(g.area, n);
  }
  add('physical', (p.getStringList('ex_log') ?? <String>[]).where(keys.contains).length);
  add('emotional', (p.getStringList('calm_log') ?? <String>[]).where(keys.contains).length);
  try {
    final e = jsonDecode(p.getString('entries') ?? '{}') as Map;
    e.forEach((k, v) {
      if (keys.contains('$k') && v is Map && ('${v['journal'] ?? ''}'.trim().isNotEmpty || v['mood'] != null)) add('emotional', 1);
    });
  } catch (_) {}
  for (final s in p.getStringList('connect_notes') ?? <String>[]) {
    try {
      if (keys.contains('${(jsonDecode(s) as Map)['date']}')) add('social', 1);
    } catch (_) {}
  }
  try {
    for (final l in jsonDecode(p.getString('letters') ?? '[]') as List) {
      if (keys.contains('${(l as Map)['written']}')) add('spiritual', 1);
    }
  } catch (_) {}
  return r;
}

/// The area that has had the least attention lately (ties go to the lowest rating).
Area quietestArea(Store p) {
  final act = areaActivity(p);
  final sorted = [...areas]..sort((a, b) {
      final c = act[a.id]!.compareTo(act[b.id]!);
      if (c != 0) return c;
      return (ratingOf(p, a.id) ?? 5).compareTo(ratingOf(p, b.id) ?? 5);
    });
  return sorted.first;
}

bool ratingsStale(Store p) {
  final d = ratingDate(p);
  if (d == null) return true;
  final t = DateTime.tryParse(d);
  return t == null || DateTime.now().difference(t).inDays >= 30;
}

String areaWeekLine(Store p) {
  final a = areaActivity(p, days: 7);
  final bits = [for (final x in areas) if (a[x.id]! > 0) '${x.short} ${a[x.id]}'];
  if (bits.isEmpty) return '';
  final quiet = areas.where((x) => a[x.id] == 0).map((x) => x.short).toList();
  return 'By area: ${bits.join(', ')}.${quiet.isEmpty ? '' : ' Quiet this week: ${quiet.join(', ')}.'}';
}

// ------------------------------------------------------------------ widgets

class _WheelPainter extends CustomPainter {
  final List<double> feel, doing;
  final bool dark;
  _WheelPainter(this.feel, this.doing, this.dark);

  @override
  void paint(Canvas c, Size s) {
    final ctr = Offset(s.width / 2, s.height / 2);
    final r = math.min(s.width, s.height) / 2 - 28;
    final n = areas.length;
    Offset pt(int i, double f) {
      final a = -math.pi / 2 + i * 2 * math.pi / n;
      return ctr + Offset(math.cos(a), math.sin(a)) * (r * f);
    }
    final grid = Paint()..style = PaintingStyle.stroke..strokeWidth = 1..color = Colors.grey.withValues(alpha: 0.4);
    for (final f in [0.33, 0.66, 1.0]) {
      final p = Path()..moveTo(pt(0, f).dx, pt(0, f).dy);
      for (var i = 1; i < n; i++) {
        p.lineTo(pt(i, f).dx, pt(i, f).dy);
      }
      c.drawPath(p..close(), grid);
    }
    for (var i = 0; i < n; i++) {
      c.drawLine(ctr, pt(i, 1), grid);
    }
    Path poly(List<double> v) {
      final p = Path()..moveTo(pt(0, v[0]).dx, pt(0, v[0]).dy);
      for (var i = 1; i < n; i++) {
        p.lineTo(pt(i, v[i]).dx, pt(i, v[i]).dy);
      }
      return p..close();
    }
    c.drawPath(poly(feel), Paint()..color = const Color(0xFF21877C).withValues(alpha: 0.28));
    c.drawPath(poly(feel), Paint()..style = PaintingStyle.stroke..strokeWidth = 2.5..color = const Color(0xFF21877C));
    c.drawPath(poly(doing), Paint()..style = PaintingStyle.stroke..strokeWidth = 2.5..color = const Color(0xFFE58A1F));
    for (var i = 0; i < n; i++) {
      final tp = TextPainter(text: TextSpan(text: areas[i].short, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: areas[i].color)), textDirection: TextDirection.ltr)..layout();
      final o = pt(i, 1.0 + 0.28) - Offset(tp.width / 2, tp.height / 2);
      tp.paint(c, o);
    }
  }

  @override
  bool shouldRepaint(_WheelPainter o) => true;
}

class LifeBalanceCard extends StatelessWidget {
  final Store prefs;
  final VoidCallback onChanged;
  const LifeBalanceCard({super.key, required this.prefs, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final act = areaActivity(prefs);
    final feel = [for (final a in areas) ((ratingOf(prefs, a.id) ?? 0) / 10).clamp(0.04, 1.0).toDouble()];
    final doing = [for (final a in areas) (act[a.id]! / 10).clamp(0.04, 1.0).toDouble()];
    return Card(
      elevation: 0,
      color: cardBg(context),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () async {
          await Navigator.push(context, MaterialPageRoute(builder: (_) => AreasPage(prefs: prefs)));
          onChanged();
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(children: [
            const Row(children: [
              Expanded(child: Text('LIFE BALANCE', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF21877C)))),
              Text('Open', style: TextStyle(color: Colors.grey)),
              Icon(Icons.chevron_right, color: Colors.grey),
            ]),
            SizedBox(height: 250, width: double.infinity, child: CustomPaint(painter: _WheelPainter(feel, doing, isDark(context)))),
            const Wrap(spacing: 16, children: [
              _Key(Color(0xFF21877C), 'How satisfied you feel'),
              _Key(Color(0xFFE58A1F), 'What you did (30 days)'),
            ]),
            const SizedBox(height: 6),
            Text(ratingDate(prefs) == null ? 'Tap to rate each area from 1 to 10 and see your balance.' : 'Quietest lately: ${quietestArea(prefs).name}.', textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey)),
          ]),
        ),
      ),
    );
  }
}

class _Key extends StatelessWidget {
  final Color c;
  final String t;
  const _Key(this.c, this.t);
  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [Container(width: 12, height: 4, color: c), const SizedBox(width: 6), Text(t, style: const TextStyle(fontSize: 12))]);
}

class AreasPage extends StatefulWidget {
  final Store prefs;
  const AreasPage({super.key, required this.prefs});
  @override
  State<AreasPage> createState() => _AreasPageState();
}

class _AreasPageState extends State<AreasPage> {
  @override
  Widget build(BuildContext context) {
    final p = widget.prefs;
    final act = areaActivity(p);
    final goals = loadGoals(p);
    final today = DateTime.now();
    return Scaffold(
      appBar: AppBar(title: const Text('Six areas of life')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        const Text('A full life has many sides. Rate how satisfied you are with each one from 1 to 10, then add small goals where you want to grow. There are no right answers.'),
        const SizedBox(height: 12),
        LifeBalanceCard(prefs: p, onChanged: () => setState(() {})),
        const SizedBox(height: 8),
        for (final a in areas)
          Card(
            elevation: 0,
            color: cardBg(context),
            child: ExpansionTile(
              shape: const Border(),
              leading: CircleAvatar(backgroundColor: a.color.withValues(alpha: 0.18), child: Icon(a.icon, color: a.color)),
              title: Text(a.name, style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text('${ratingOf(p, a.id) == null ? 'Not rated' : 'Satisfaction ${ratingOf(p, a.id)}/10'}  •  ${act[a.id]} in 30 days'),
              childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              expandedCrossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(a.blurb, style: const TextStyle(color: Colors.grey)),
                const SizedBox(height: 8),
                const Text('How satisfied are you?', style: TextStyle(fontWeight: FontWeight.w600)),
                Slider(
                  min: 1,
                  max: 10,
                  divisions: 9,
                  value: (ratingOf(p, a.id) ?? 5).toDouble(),
                  label: '${ratingOf(p, a.id) ?? 5}',
                  activeColor: a.color,
                  onChanged: (v) async {
                    await setRating(p, a.id, v.round());
                    setState(() {});
                  },
                ),
                for (final g in goals.where((g) => g.area == a.id && !g.done).take(5))
                  ListTile(dense: true, contentPadding: EdgeInsets.zero, leading: Icon(g.repeats ? Icons.repeat : Icons.flag_outlined, size: 18, color: a.color), title: Text(g.title)),
                const SizedBox(height: 4),
                const Text('Ideas to try', style: TextStyle(fontWeight: FontWeight.w600)),
                for (final idea in a.ideas.take(5))
                  ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text(idea),
                    trailing: IconButton(
                      tooltip: 'Add to my goals',
                      icon: const Icon(Icons.add_circle_outline),
                      onPressed: () async {
                        await addToGoalsSheet(context, p, idea, area: a.id);
                        if (mounted) setState(() {});
                      },
                    ),
                  ),
                const SizedBox(height: 4),
                Text('Reflect: ${areaPromptFor(today).$1.id == a.id ? areaPromptFor(today).$2 : a.prompts[today.day % a.prompts.length]}', style: const TextStyle(fontStyle: FontStyle.italic, height: 1.4)),
              ],
            ),
          ),
      ]),
    );
  }
}

/// Today card: nudge toward the quietest area, or a check-in when ratings are missing or old.
class AreaNudge extends StatelessWidget {
  final Store prefs;
  final VoidCallback onChanged;
  const AreaNudge({super.key, required this.prefs, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    if (!extraOn(prefs, 'areas')) return const SizedBox.shrink();
    final stale = ratingsStale(prefs);
    final q = quietestArea(prefs);
    final idea = areaIdeaFor(q, DateTime.now()).$2;
    Future<void> open() async {
      await Navigator.push(context, MaterialPageRoute(builder: (_) => AreasPage(prefs: prefs)));
      onChanged();
    }
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(top: 10),
      color: tint(context, Color.lerp(Colors.white, q.color, 0.14)!),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(q.icon, color: q.color),
            const SizedBox(width: 8),
            Expanded(child: Text(stale ? 'Check in on your six areas' : 'Area to nurture: ${q.name}', style: const TextStyle(fontWeight: FontWeight.w700))),
          ]),
          const SizedBox(height: 6),
          Text(stale ? 'Rate each part of your life from 1 to 10. It takes a minute and shows where to put your energy.' : idea),
          Row(children: [
            TextButton(onPressed: open, child: Text(stale ? 'Rate my areas' : 'See all areas')),
            const Spacer(),
            if (!stale)
              FilledButton.tonal(
                onPressed: () async {
                  await addToGoalsSheet(context, prefs, idea, area: q.id);
                  onChanged();
                },
                child: const Text('Add to goals'),
              ),
          ]),
        ]),
      ),
    );
  }
}
