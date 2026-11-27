import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'store.dart';
import 'theme.dart';

class UpdateNote {
  final String id, title, body;
  const UpdateNote(this.id, this.title, this.body);
}

/// Newest first. Only the latest five are shown.
const updateNotes = <UpdateNote>[
  UpdateNote('u0.8', 'Questions for someone close', '96 original questions at three depths (Light, Deeper, Honest) for a partner, friend or family member. A weekly question with a shuffle that never repeats until you have seen them all, plus a guided evening with an optional quiet pause. Optional reminders on any days you choose, any number of times a day.'),
  UpdateNote('u0.7', 'Short lessons for each life area', '48 quick lessons (6 areas, 8 each). Each is a couple of sentences plus one small action. Tap Explain for the longer version.'),
  UpdateNote('u0.6', 'Six areas of life', 'New life-balance wheel for Physical, Intellectual, Emotional, Social, Occupational & financial, and Spiritual. Rate each area, tag goals by area, and get ideas and prompts for the one that needs attention.'),
  UpdateNote('u0.5.2', 'Text size options', 'Added Smaller and Small text sizes in Settings > Look and extras, for fitting more on screen.'),
  UpdateNote('u0.5.1', 'Focus timer and gentler days', 'Focus sessions now notify you when time is up (app versions). “Lighten my day” also pushes back multi-day goals.'),
  UpdateNote('u0.5', 'Big self-improvement update', 'Repeating goals, weekly review and share card, hatching egg, mood patterns, Calm timer, rough-day mode, letters to future you, focus timer, 7-day challenges, journal prompts, dark mode. Every extra can be switched off in Settings.'),
  UpdateNote('u0.4', 'Goals planner', 'Plan goals with importance levels and multi-day goals, add pull-ups, and an optional opening animation. The app is now called Shell.'),
  UpdateNote('u0.3', 'Customize your tabs', 'Choose, reorder and hide tabs, pick your start tab, and export or import your data as a zip.'),
];

/// Always points at the newest release (each build is published as the latest release).
const apkUrl = 'https://github.com/jbecher728/Successful-life/releases/latest/download/successful-life-arm64.apk';

const dataNoteText =
    'This web version saves everything only in this browser, on this device. Nothing is sent to any server, so no one else can see it, and it also cannot be recovered for you.\n\n'
    'Your data can be lost if you clear browser or site data, use a private window, switch browsers or phones, or (on iPhone) leave the site unused for a while without adding it to your Home Screen.\n\n'
    'To keep it safe:\n'
    '• Add this page to your Home Screen (Share > Add to Home Screen).\n'
    '• Use the menu ⋮ > Settings > Export regularly and keep the zip file somewhere you trust.\n'
    '• To restore or move to another device, use Import in the same place.\n\n'
    'The Android app also has notifications, app lock and optional encrypted backup.';

Set<String> _cleared(Store p) => (p.getStringList('notes_cleared') ?? <String>[]).toSet();

const _dlNote = UpdateNote('dl', 'Have Android? Download the native app', 'The Android app adds reminders, app lock and optional encrypted backup.');

List<UpdateNote> _visible(Store p) {
  final c = _cleared(p);
  return [if (kIsWeb) _dlNote, ...updateNotes.take(5)].where((n) => !c.contains(n.id)).toList();
}

int noteCount(Store p) => _visible(p).length + (kIsWeb ? 1 : 0); // +1 for the permanent data note (web only)

/// Bell button with a red count, for the top-left of the web app.
class NotesButton extends StatelessWidget {
  final Store prefs;
  final VoidCallback onChanged;
  const NotesButton({super.key, required this.prefs, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final n = noteCount(prefs);
    return IconButton(
      tooltip: 'Notifications',
      onPressed: () async {
        await showModalBottomSheet<void>(
          context: context,
          isScrollControlled: true,
          showDragHandle: true,
          builder: (_) => NotesSheet(prefs: prefs),
        );
        onChanged();
      },
      icon: Stack(clipBehavior: Clip.none, children: [
        const Icon(Icons.notifications_outlined),
        if (n > 0) Positioned(
          right: -6,
          top: -5,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
            decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(10)),
            child: Text('$n', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
          ),
        ),
      ]),
    );
  }
}

class NotesSheet extends StatefulWidget {
  final Store prefs;
  const NotesSheet({super.key, required this.prefs});
  @override
  State<NotesSheet> createState() => _NotesSheetState();
}

class _NotesSheetState extends State<NotesSheet> {
  bool get _min => widget.prefs.getBool('data_note_min') ?? false;

  Future<void> _clear(String id) async {
    final c = _cleared(widget.prefs)..add(id);
    await widget.prefs.setStringList('notes_cleared', c.toList());
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final list = _visible(widget.prefs);
    final dark = isDark(context);
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.8),
        child: ListView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 16), children: [
          Row(children: [
            const Expanded(child: Text('Notifications', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold))),
            if (list.isNotEmpty)
              TextButton(
                onPressed: () async {
                  final c = _cleared(widget.prefs)..addAll(list.map((e) => e.id));
                  await widget.prefs.setStringList('notes_cleared', c.toList());
                  setState(() {});
                },
                child: const Text('Clear updates'),
              ),
          ]),
          // Permanent note: can be minimized, never removed.
          if (kIsWeb) Card(
            elevation: 0,
            color: tint(context, const Color(0xFFFFF8D6)),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                InkWell(
                  onTap: () async {
                    await widget.prefs.setBool('data_note_min', !_min);
                    setState(() {});
                  },
                  child: Row(children: [
                    Container(width: 12, height: 12, decoration: const BoxDecoration(color: Color(0xFFF5B800), shape: BoxShape.circle)),
                    const SizedBox(width: 10),
                    const Expanded(child: Text('How your data is stored on the web', style: TextStyle(fontWeight: FontWeight.w700))),
                    Icon(_min ? Icons.expand_more : Icons.expand_less),
                  ]),
                ),
                if (!_min) Padding(padding: const EdgeInsets.only(top: 10), child: Text(dataNoteText, style: TextStyle(height: 1.4, color: dark ? null : Colors.black87))),
              ]),
            ),
          ),
          for (final n in list)
            Card(
              elevation: 0,
              color: cardBg(context),
              child: ListTile(
                leading: const Icon(Icons.new_releases_outlined, color: Color(0xFF21877C)),
                title: Text(n.title, style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: n.id == 'dl'
                    ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(n.body),
                        TextButton.icon(onPressed: () => launchUrl(Uri.parse(apkUrl), mode: LaunchMode.externalApplication), icon: const Icon(Icons.download), label: const Text('Download the latest Android app')),
                      ])
                    : Text(n.body),
                isThreeLine: true,
                trailing: IconButton(tooltip: 'Clear', icon: const Icon(Icons.close), onPressed: () => _clear(n.id)),
              ),
            ),
          if (list.isEmpty) const Padding(padding: EdgeInsets.only(top: 12), child: Text('No new updates.', style: TextStyle(color: Colors.grey))),
        ]),
      ),
    );
  }
}
