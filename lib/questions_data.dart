import 'dart:math';
import 'package:flutter/material.dart';
import 'common.dart';
import 'store.dart';

/// One depth level of questions to ask someone close (partner, friend or family).
class QLevel {
  final String id, name, blurb;
  final IconData icon;
  final Color color;
  final List<String> q;
  const QLevel(this.id, this.name, this.blurb, this.icon, this.color, this.q);
}

QLevel levelById(String id) => qLevels.firstWhere((l) => l.id == id, orElse: () => qLevels.first);

String currentLevel(Store p) => p.getString('cq_level') ?? 'light';

Set<int> seenQuestions(Store p, String lv) {
  final n = levelById(lv).q.length;
  final out = <int>{};
  for (final s in p.getStringList('cq_used_$lv') ?? <String>[]) {
    final i = int.tryParse(s);
    if (i != null && i >= 0 && i < n) out.add(i);
  }
  return out;
}

/// Picks a random question that has not come up yet this round. When every
/// question at a level has been seen, a fresh round starts. [avoid] keeps the
/// same question from showing twice in a row.
Future<int> drawQuestion(Store p, String lv, {int? avoid}) async {
  final n = levelById(lv).q.length;
  var seen = seenQuestions(p, lv);
  if (seen.length >= n) seen = <int>{};
  var pool = <int>[for (var i = 0; i < n; i++) if (!seen.contains(i)) i];
  if (avoid != null && pool.length > 1) pool = pool.where((i) => i != avoid).toList();
  final pick = pool[Random().nextInt(pool.length)];
  seen.add(pick);
  await p.setStringList('cq_used_$lv', <String>[for (final i in seen) '$i']);
  return pick;
}

String weekKey(DateTime d) => dayKey(DateTime(d.year, d.month, d.day - (d.weekday - 1)));

/// This week's question for the chosen level. Stays the same all week unless
/// [fresh] is true (the shuffle button) or the level changes.
Future<(String, int)> weeklyQuestion(Store p, {bool fresh = false}) async {
  final lv = currentLevel(p);
  final now = weekKey(DateTime.now());
  final parts = (p.getString('cq_week') ?? '').split('|');
  final stored = parts.length == 3 && parts[1] == lv ? int.tryParse(parts[2]) : null;
  if (!fresh && parts.length == 3 && parts[0] == now && stored != null && stored < levelById(lv).q.length) {
    return (lv, stored);
  }
  final i = await drawQuestion(p, lv, avoid: stored);
  await p.setString('cq_week', '$now|$lv|$i');
  return (lv, i);
}

Future<void> logEvening(Store p) async {
  final l = p.getStringList('cq_evening') ?? <String>[];
  l.add(dayKey(DateTime.now()));
  await p.setStringList('cq_evening', l);
}

const qLevels = <QLevel>[
  QLevel('light', 'Light', 'Warm-ups, good memories and small joys', Icons.wb_sunny_outlined, Color(0xFFF2A516), [
    "What's a small moment from this month that made you smile?",
    "What's a moment from our time together that you think of fondly?",
    "What's a first memory you have of the two of us?",
    "What's a meal you could happily eat again and again?",
    "If we had a free day with no plans, how would you spend it?",
    "What song takes you back to a happy time?",
    "What are you looking forward to right now?",
    "What's the best trip or outing you've ever had?",
    "What's a silly habit of yours that you're fond of?",
    "What did you love doing as a kid?",
    "Which of my habits makes you laugh?",
    "What's a place that makes you feel calm?",
    "What's something new you'd like to try this year?",
    "What's the best compliment you've ever received?",
    "Who or what made you laugh the hardest lately?",
    "What small thing would make your week better?",
    "What's a talent you wish you had?",
    "If you could learn any skill overnight, what would it be?",
    "What's a tradition you'd like us to start?",
    "What's your favorite way to spend a rainy day?",
    "What's a book, show or film that stayed with you?",
    "What's something ordinary that you're oddly grateful for?",
    "What do you think we do well together?",
    "When do you feel most like yourself on a normal day?",
    "What's an inside joke of ours that still makes you smile?",
    "What would your ideal morning look like?",
    "What's something you're proud of this season?",
    "What's a smell, taste or sound that feels like home?",
    "What's one thing we haven't done together that you'd like to?",
    "What's a kind thing someone did for you that you still remember?",
    "If you could spend an afternoon with your younger self, what would you do?",
    "What's the funniest thing that has happened to us?",
  ]),
  QLevel('deeper', 'Deeper', 'Values, needs and the future', Icons.explore_outlined, Color(0xFF21877C), [
    "Picture a good life five years from now. How does it feel, day to day?",
    "What do you value most in a close relationship?",
    "What do I do that makes you feel cared for?",
    "What does support look like for you when you're stressed?",
    "What's a dream you've put on hold?",
    "What does being there for someone mean to you?",
    "What would you like to be remembered for?",
    "When do you feel most connected to me?",
    "What's a belief you grew up with that you've questioned since?",
    "What part of your life do you wish I knew more about?",
    "What gives your days meaning beyond work and chores?",
    "What do you need more of in your life right now?",
    "How do you like to be comforted when you're upset?",
    "What's a lesson that took you a long time to learn?",
    "What are you working on in yourself?",
    "What does real rest look like for you?",
    "What do you wish people asked you about more often?",
    "How would you like us to handle disagreements?",
    "What's a decision you're glad you made?",
    "What does trust look like day to day?",
    "What would help you feel more appreciated?",
    "What are you hoping the next year brings?",
    "How has knowing me changed you?",
    "What's a boundary that matters to you?",
    "What do you think we should do more of together?",
    "What's something you'd like us to talk about more often?",
    "What does commitment mean to you?",
    "What kind of atmosphere do you want to come home to?",
    "What worries you about the future, and what helps with it?",
    "How do you want to grow over the next few years?",
    "What do you admire in how I handle hard things?",
    "What would a really good ordinary week look like for you?",
  ]),
  QLevel('honest', 'Honest', 'Unspoken needs and worries, said with care', Icons.favorite_border, Color(0xFFB4475F), [
    "What's something you've wanted to tell me but haven't?",
    "When do you feel least understood by me?",
    "What have you held back sharing because you weren't sure how I'd take it?",
    "What's a worry about us that you've kept to yourself?",
    "When have you felt lonely even though we were together?",
    "What do you miss about how things used to be between us?",
    "What's something I do that affects you more than I realize?",
    "What do you need from me that's hard to ask for?",
    "Is there a conversation we've been avoiding?",
    "When do you feel you have to hold back with me?",
    "What do you wish I noticed without you having to say it?",
    "What are you afraid I might think if I knew everything on your mind?",
    "When did you last feel let down by me, and did you say so?",
    "What would make it easier for you to be honest with me?",
    "What's something you feel ashamed of that you'd like to feel okay about?",
    "How do I react when you bring me a problem, and how do you wish I would?",
    "What part of yourself do you hide from most people?",
    "How have you needed care lately that I might have overlooked?",
    "What do you wish we could do differently when we're upset?",
    "What have you forgiven me for but still think about?",
    "Is there something you'd like to apologize for?",
    "When do you feel most insecure around me?",
    "What do you wish I'd ask about your life?",
    "What do you wish I'd let go of?",
    "What's something you're afraid to want?",
    "Which of my habits is hardest for you, and how could we ease it?",
    "What do you need to hear more often?",
    "What's a worry you've been carrying alone?",
    "If we stopped taking each other for granted, what would you want to change first?",
    "What would you want me to remember when we disagree?",
    "What does feeling safe with someone look like for you?",
    "What's one thing you'd like me to know that I might not?",
  ]),
];
