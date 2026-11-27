import 'package:flutter/material.dart';
import 'evening.dart';
import 'goal_actions.dart';
import 'questions_data.dart';
import 'review.dart';
import 'store.dart';
import 'theme.dart';

/// Compact Today card: this week's question for someone close.
class QuestionCard extends StatefulWidget {
  final Store prefs;
  final VoidCallback onChanged;
  const QuestionCard({super.key, required this.prefs, required this.onChanged});
  @override
  State<QuestionCard> createState() => _QuestionCardState();
}

class _QuestionCardState extends State<QuestionCard> {
  String? lv;
  int idx = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool fresh = false}) async {
    final r = await weeklyQuestion(widget.prefs, fresh: fresh);
    if (mounted) {
      setState(() {
        lv = r.$1;
        idx = r.$2;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (lv == null) return const SizedBox.shrink();
    final l = levelById(lv!);
    return Card(
      elevation: 0,
      color: tint(context, const Color(0xFFFFF1F3)),
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () async {
          await Navigator.push(context, MaterialPageRoute(builder: (_) => QuestionsPage(prefs: widget.prefs)));
          await _load();
          widget.onChanged();
        },
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(Icons.forum_outlined, color: l.color),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('A question for someone close  •  ${l.name}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text(l.q[idx], style: const TextStyle(fontSize: 16, height: 1.35)),
              ]),
            ),
            IconButton(tooltip: 'Another question', icon: const Icon(Icons.shuffle), onPressed: () => _load(fresh: true)),
          ]),
        ),
      ),
    );
  }
}

class QuestionsPage extends StatefulWidget {
  final Store prefs;
  const QuestionsPage({super.key, required this.prefs});
  @override
  State<QuestionsPage> createState() => _QuestionsPageState();
}

class _QuestionsPageState extends State<QuestionsPage> {
  String? lv;
  int idx = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool fresh = false}) async {
    final r = await weeklyQuestion(widget.prefs, fresh: fresh);
    if (mounted) {
      setState(() {
        lv = r.$1;
        idx = r.$2;
      });
    }
  }

  Future<void> _setLevel(String id) async {
    await widget.prefs.setString('cq_level', id);
    await _load();
  }

  Future<void> _remind(bool v) async {
    await widget.prefs.setBool('x_qremind', v);
    final n = notifier;
    if (n != null) await scheduleExtras(n, widget.prefs);
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.prefs;
    final cur = lv;
    if (cur == null) return Scaffold(appBar: AppBar(title: const Text('Questions for someone close')), body: const SizedBox.shrink());
    final l = levelById(cur);
    final seen = seenQuestions(p, cur).length;
    return Scaffold(
      appBar: AppBar(title: const Text('Questions for someone close')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        const Text('One good question a week keeps a relationship alive. Ask a partner, friend or family member, then listen without defending. Skip any question you like.'),
        const SizedBox(height: 14),
        Wrap(spacing: 8, children: [
          for (final x in qLevels)
            ChoiceChip(
              avatar: Icon(x.icon, size: 18, color: x.color),
              label: Text(x.name),
              selected: x.id == cur,
              onSelected: (_) => _setLevel(x.id),
            ),
        ]),
        const SizedBox(height: 4),
        Text(l.blurb, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        const SizedBox(height: 12),
        Card(
          elevation: 0,
          color: tint(context, l.color.withValues(alpha: 0.14)),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('This week', style: TextStyle(fontWeight: FontWeight.w700, color: l.color)),
              const SizedBox(height: 8),
              Text(l.q[idx], style: const TextStyle(fontSize: 20, height: 1.4, fontWeight: FontWeight.w600)),
            ]),
          ),
        ),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: OutlinedButton.icon(onPressed: () => _load(fresh: true), icon: const Icon(Icons.shuffle), label: const Text('Another question'))),
          const SizedBox(width: 12),
          Expanded(
            child: FilledButton.icon(
              onPressed: () => addToGoalsSheet(context, p, 'Ask: ${l.q[idx]}', area: 'social'),
              icon: const Icon(Icons.add_task),
              label: const Text('Add to goals'),
            ),
          ),
        ]),
        const SizedBox(height: 6),
        Text('Seen $seen of ${l.q.length} in ${l.name}. You will not see a repeat until you have been through them all.', style: const TextStyle(fontSize: 12, color: Colors.grey)),
        if (cur == 'honest')
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text('Pick a calm moment for these. If a topic feels too heavy, it is okay to stop, and a counselor can help with hard ones.', style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic)),
          ),
        const Divider(height: 32),
        Card(
          elevation: 0,
          color: cardBg(context),
          child: ListTile(
            leading: const Icon(Icons.nightlight_outlined, color: Color(0xFF7B4EA3)),
            title: const Text('Guided evening', style: TextStyle(fontWeight: FontWeight.w700)),
            subtitle: const Text('Three sets from light to deep, taking turns, with an optional quiet pause.'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => EveningPage(prefs: p))),
          ),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Saturday reminder'),
          subtitle: const Text('A gentle nudge at 10 am (app versions only)'),
          value: extraOn(p, 'qremind', def: false),
          onChanged: _remind,
        ),
        const SizedBox(height: 4),
        const Text('Nothing you or anyone else answers is saved. Only which questions you have already seen is kept, on this device.', style: TextStyle(fontSize: 12, color: Colors.grey)),
      ]),
    );
  }
}
