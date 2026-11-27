import 'dart:convert';
import 'package:flutter/material.dart';
import 'common.dart';
import 'goal_actions.dart';
import 'growth_tests.dart';
import 'lessons.dart';
import 'planner.dart';
import 'store.dart';
import 'theme.dart';

const _social = Color(0xFFF2A516);

/// Eight short lessons on understanding other people (Social area).
const understandLessons = <Lesson>[
  Lesson('social', 'Listen to understand', 'Most of us listen in order to reply. Listen to learn what it is like to be them.', 'In your next conversation, let them finish, then say back what you heard.',
      'Listening to reply means you are already building your answer while they talk. Listening to understand means staying with their words, tone and pace until you could explain their point of view to them. Pausing a second before answering, and saying back what you heard ("So you are saying...?"), gives them a chance to correct you and shows you care about getting it right.'),
  Lesson('social', 'Empathy is not agreement', 'You can understand how someone feels without agreeing with them or fixing it.', 'Before giving any advice, say something like "That sounds really hard."',
      'Empathy means recognizing what another person feels and why it makes sense from where they stand. It does not mean you agree, or that you must solve the problem. Many people mainly want to feel heard first. Offering advice too early can sound like "you should not feel this way." Try naming the feeling, then asking if they want ideas or just company.'),
  Lesson('social', 'Ask open questions', 'Questions that start with what or how invite a story. Yes-or-no questions end the talk.', 'Ask one "what" or "how" question today, then stay quiet and listen.',
      'Compare "Did you have a bad day?" with "What was the hardest part of your day?" The second invites detail. Be careful with "why" questions, which can sound like blame ("Why did you do that?"). "What led to that?" or "How did that feel?" usually lands softer. Then leave a little silence, since people often say the most important thing after a pause.'),
  Lesson('social', 'Look for the need behind it', 'Behavior often points to an unmet need: to be heard, respected, safe or rested.', 'Think of a recent irritation and guess the need underneath it.',
      'Snapping, withdrawing or nagging are usually signals, not the whole story. Behind them there is often a need, like feeling appreciated, having space, or feeling safe. This is a guess, not a fact, so treat it as a question to check ("Are you feeling overlooked?"). Seeing the need makes it easier to respond to the person instead of reacting to the behavior.'),
  Lesson('social', 'Start with good intent', 'Try the most generous explanation that could be true. You will often be right, and you will argue less.', 'Next time someone irritates you, write down two innocent explanations.',
      'When we judge ourselves we point to our circumstances ("I was rushed"), but when we judge others we often point to their character ("they are rude"). Psychologists call this the fundamental attribution error. Offering the same benefit of the doubt you give yourself does not mean excusing everything. It just keeps you curious long enough to find out what happened.'),
  Lesson('social', 'Try their seat', 'Picture the same situation with their history, pressures and information.', 'Use "See it from their side" on a recent moment.',
      'People act on what they know, what they fear and what has happened to them, and that differs from your own. Imagine the same event from their seat: what was their day like, what did they want, what might they be worried about. You will never know for certain, so the aim is not to guess correctly. It is to loosen the first story you told yourself and to ask better questions.'),
  Lesson('social', 'Disagree without attacking', 'Describe what happened, how it affects you and what you need, not what is wrong with them.', 'Rewrite one complaint as: "When X happens, I feel Y, and I would like Z."',
      'Statements that start with "you always" or "you never" make people defend themselves, and then nobody is listening. Describing the specific event, your own feeling and a clear request keeps the focus on the problem instead of the person. It also gives them something they can actually do. Take turns, and repeat back their view before adding yours.'),
  Lesson('social', 'Same words, different meanings', 'Tone, culture, mood and habits change what words mean. What you heard may not be what they meant.', 'When something stings, ask "What did you mean by that?" before reacting.',
      'Some people are direct and some soften everything. Some use humor when stressed, and others go quiet. Jokes, sarcasm and short texts are especially easy to misread. Before assuming an insult, check the meaning: "Can I make sure I understood? What did you mean?" Asking often turns a fight into a clarification.'),
];

const _prompts = [
  'Think of someone who frustrated you this week. What might have been going on for them?',
  'Who in your life might feel unheard right now? What could you do to show you are listening?',
  'Recall a recent disagreement. What was the strongest point in the other person\'s view?',
  'What does someone close to you worry about that you rarely ask about?',
  'Who did you judge quickly this week? What else could be true?',
  'When were you last misunderstood? What do you wish the other person had asked?',
  'Think of someone you find difficult. What do they seem to need that they are not getting?',
  'What is one thing about a friend that you have never asked them about?',
  'Who might be having a harder time than they show?',
  'What do you wish people understood about you, and how could you offer that to someone else?',
  'Think of someone from a different background or generation. What might life look like from their position?',
  'When did you last change your mind about someone? What caused it?',
];

String weeklyUnderstandPrompt() {
  final w = DateTime.now().difference(DateTime(2024, 1, 1)).inDays ~/ 7;
  return _prompts[w % _prompts.length];
}

// ------------------------------------------------------------------ saved reflections

List<Map<String, dynamic>> loadSide(Store p) {
  try {
    return [for (final e in jsonDecode(p.getString('side_notes') ?? '[]') as List) Map<String, dynamic>.from(e as Map)];
  } catch (_) {
    return [];
  }
}

Future<void> saveSide(Store p, List<Map<String, dynamic>> l) => p.setString('side_notes', jsonEncode(l));

const _roles = ['Partner', 'Parent', 'Child', 'Sibling', 'Friend', 'Coworker', 'Boss', 'Other'];

// ------------------------------------------------------------------ main page

class UnderstandPage extends StatefulWidget {
  final Store prefs;
  const UnderstandPage({super.key, required this.prefs});
  @override
  State<UnderstandPage> createState() => _UnderstandPageState();
}

class _UnderstandPageState extends State<UnderstandPage> {
  @override
  Widget build(BuildContext context) {
    final p = widget.prefs;
    final done = lessonsDone(p);
    final doneCount = understandLessons.where((l) => done.containsKey(l.id)).length;
    Lesson? nextL;
    for (final l in understandLessons) {
      if (!done.containsKey(l.id)) {
        nextL = l;
        break;
      }
    }
    final saved = loadSide(p).length;
    final hist = loadGrowth(p)['understand'] ?? [];
    final last = hist.isEmpty ? null : hist.last;
    final lastPct = last == null ? null : scorePercent([for (final x in (last['a'] as List)) (x as num).toInt()]);
    return Scaffold(
      appBar: AppBar(title: const Text('Understanding others')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        const Text('Understanding someone starts with curiosity, not mind reading. The best way to know what another person thinks or feels is to ask them. These tools help you practice.'),
        const SizedBox(height: 12),
        Card(
          elevation: 0,
          color: tint(context, _social.withValues(alpha: 0.14)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Think about this week', style: TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF854F0B))),
              const SizedBox(height: 6),
              Text(weeklyUnderstandPrompt(), style: const TextStyle(fontSize: 17, height: 1.4)),
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: () async {
                  await Navigator.push(context, MaterialPageRoute(builder: (_) => SideViewEditor(prefs: p)));
                  if (mounted) setState(() {});
                },
                icon: const Icon(Icons.edit_outlined),
                label: const Text('Reflect on it'),
              ),
            ]),
          ),
        ),
        const SizedBox(height: 14),
        Text('Lessons  •  $doneCount of ${understandLessons.length} done', style: const TextStyle(fontWeight: FontWeight.w700)),
        for (final l in understandLessons)
          ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: Icon(done.containsKey(l.id) ? Icons.check_circle : (nextL == l ? Icons.play_circle_fill : Icons.circle_outlined), color: _social, size: 22),
            title: Text(l.title, style: TextStyle(fontWeight: nextL == l ? FontWeight.w700 : null)),
            subtitle: nextL == l ? Text(l.short) : null,
            onTap: () => showLesson(context, p, l, onChanged: () => setState(() {})),
          ),
        const Divider(height: 28),
        Card(
          elevation: 0,
          color: cardBg(context),
          child: ListTile(
            leading: const Icon(Icons.swap_horiz, color: _social),
            title: const Text('See it from their side', style: TextStyle(fontWeight: FontWeight.w700)),
            subtitle: Text(saved == 0 ? 'Walk through a recent moment from the other person\'s view.' : 'Walk through a recent moment. $saved saved on this device.'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () async {
              await Navigator.push(context, MaterialPageRoute(builder: (_) => SideViewPage(prefs: p)));
              if (mounted) setState(() {});
            },
          ),
        ),
        Card(
          elevation: 0,
          color: cardBg(context),
          child: ListTile(
            leading: const Icon(Icons.hearing, color: _social),
            title: const Text('7-day listening challenge', style: TextStyle(fontWeight: FontWeight.w700)),
            subtitle: const Text('Once a day: listen for a full minute, say back what you heard, then ask one follow-up question.'),
            trailing: FilledButton.tonal(
              onPressed: () async {
                await addGoal(p, title: '7 days: Listen first', note: 'Listen for a full minute, say back what you heard, then ask one follow-up question.', imp: 6, days: 7, area: 'social');
                if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Started: Listen first. Find it under Goals.')));
              },
              child: const Text('Start'),
            ),
          ),
        ),
        Card(
          elevation: 0,
          color: cardBg(context),
          child: ListTile(
            leading: const Icon(Icons.fact_check_outlined, color: _social),
            title: const Text('Understanding others check-in', style: TextStyle(fontWeight: FontWeight.w700)),
            subtitle: Text(lastPct == null ? 'Eight statements, about two minutes.' : '${bandFor(lastPct)}  •  $lastPct%  •  ${last!['d']}'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () async {
              await Navigator.push(context, MaterialPageRoute(builder: (_) => GrowthTestPage(prefs: p, areaId: 'understand')));
              if (mounted) setState(() {});
            },
          ),
        ),
        const SizedBox(height: 8),
        const Text('For your own reflection. This cannot tell you what another person thinks or feels, and it does not diagnose anyone.', style: TextStyle(fontSize: 12, color: Colors.grey)),
      ]),
    );
  }
}

// ------------------------------------------------------------------ saved list

class SideViewPage extends StatefulWidget {
  final Store prefs;
  const SideViewPage({super.key, required this.prefs});
  @override
  State<SideViewPage> createState() => _SideViewPageState();
}

class _SideViewPageState extends State<SideViewPage> {
  static const _labels = [
    ('feel', 'They might have felt'),
    ('need', 'They might need or fear'),
    ('unknown', 'What I might not know'),
    ('mypart', 'My part in it'),
    ('ask', 'A question I could ask'),
  ];

  void _open(Map<String, dynamic> n) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.85),
          child: ListView(padding: const EdgeInsets.fromLTRB(20, 0, 20, 20), children: [
            Text('${n['who']}  •  ${n['d']}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF854F0B))),
            const SizedBox(height: 6),
            Text('${n['what']}', style: const TextStyle(fontSize: 17, height: 1.4, fontWeight: FontWeight.w600)),
            for (final l in _labels)
              if ('${n[l.$1] ?? ''}'.trim().isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(l.$2, style: const TextStyle(fontWeight: FontWeight.w700)),
                Text('${n[l.$1]}', style: const TextStyle(height: 1.4)),
              ],
            const SizedBox(height: 16),
            Row(children: [
              TextButton.icon(
                onPressed: () async {
                  final all = loadSide(widget.prefs)..removeWhere((x) => x['id'] == n['id']);
                  await saveSide(widget.prefs, all);
                  if (ctx.mounted) Navigator.pop(ctx);
                  if (mounted) setState(() {});
                },
                icon: const Icon(Icons.delete_outline),
                label: const Text('Delete'),
              ),
              const Spacer(),
              if ('${n['ask'] ?? ''}'.trim().isNotEmpty)
                OutlinedButton(onPressed: () => addToGoalsSheet(ctx, widget.prefs, 'Ask: ${n['ask']}', area: 'social'), child: const Text('Add question to goals')),
            ]),
          ]),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final notes = loadSide(widget.prefs).reversed.toList();
    return Scaffold(
      appBar: AppBar(title: const Text('See it from their side')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        const Text('Pick a recent moment with someone and walk through it from their point of view. These are guesses to loosen your first story, not facts. Use a role, not a name. Reflections are saved only on this device, and you can delete them any time.'),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: () async {
            await Navigator.push(context, MaterialPageRoute(builder: (_) => SideViewEditor(prefs: widget.prefs)));
            if (mounted) setState(() {});
          },
          icon: const Icon(Icons.add),
          label: const Text('New reflection'),
        ),
        const SizedBox(height: 14),
        if (notes.isEmpty) const Text('Nothing saved yet.', style: TextStyle(color: Colors.grey)),
        for (final n in notes)
          Card(
            elevation: 0,
            color: cardBg(context),
            child: ListTile(
              title: Text('${n['who']}  •  ${n['d']}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
              subtitle: Text('${n['what']}', maxLines: 2, overflow: TextOverflow.ellipsis),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _open(n),
            ),
          ),
      ]),
    );
  }
}

// ------------------------------------------------------------------ editor

class SideViewEditor extends StatefulWidget {
  final Store prefs;
  const SideViewEditor({super.key, required this.prefs});
  @override
  State<SideViewEditor> createState() => _SideViewEditorState();
}

class _SideViewEditorState extends State<SideViewEditor> {
  String who = 'Friend';
  final what = TextEditingController();
  final feel = TextEditingController();
  final need = TextEditingController();
  final unknown = TextEditingController();
  final mypart = TextEditingController();
  final ask = TextEditingController();

  @override
  void dispose() {
    for (final c in [what, feel, need, unknown, mypart, ask]) {
      c.dispose();
    }
    super.dispose();
  }

  Widget _field(String label, TextEditingController c, {int lines = 2}) => Padding(
        padding: const EdgeInsets.only(top: 14),
        child: TextField(controller: c, minLines: lines, maxLines: 6, textCapitalization: TextCapitalization.sentences, decoration: InputDecoration(labelText: label, border: const OutlineInputBorder(), alignLabelWithHint: true)),
      );

  Future<void> _save() async {
    if (what.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Describe the moment first, in a sentence or two.')));
      return;
    }
    final all = loadSide(widget.prefs);
    final n = <String, dynamic>{'id': DateTime.now().microsecondsSinceEpoch.toString(), 'd': dayKey(DateTime.now()), 'who': who, 'what': what.text.trim()};
    for (final e in {'feel': feel, 'need': need, 'unknown': unknown, 'mypart': mypart, 'ask': ask}.entries) {
      if (e.value.text.trim().isNotEmpty) n[e.key] = e.value.text.trim();
    }
    all.add(n);
    await saveSide(widget.prefs, all.length > 200 ? all.sublist(all.length - 200) : all);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Saved on this device.')));
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('New reflection')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        const Text('Who is this about?', style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        Wrap(spacing: 8, children: [for (final r in _roles) ChoiceChip(label: Text(r), selected: who == r, onSelected: (_) => setState(() => who = r))]),
        const Text('Use a role, not a name.', style: TextStyle(fontSize: 12, color: Colors.grey)),
        _field('What happened? (a sentence or two)', what),
        const Padding(
          padding: EdgeInsets.only(top: 18),
          child: Text('Now try their seat. These are guesses, and all are optional.', style: TextStyle(fontWeight: FontWeight.w600)),
        ),
        _field('What might they have been feeling?', feel),
        _field('What might they need, or be afraid of?', need),
        _field('What might I not know about their day or situation?', unknown),
        _field('What might they say my part was?', mypart),
        _field('One question I could ask them', ask, lines: 1),
        const SizedBox(height: 8),
        const Text('You cannot read minds. The best way to find out is to ask.', style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic)),
        const SizedBox(height: 14),
        FilledButton(onPressed: _save, child: const Text('Save')),
        const SizedBox(height: 8),
        OutlinedButton(
          onPressed: () {
            if (ask.text.trim().isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Write a question to ask first.')));
              return;
            }
            addToGoalsSheet(context, widget.prefs, 'Ask: ${ask.text.trim()}', area: 'social');
          },
          child: const Text('Add my question to goals'),
        ),
      ]),
    );
  }
}
