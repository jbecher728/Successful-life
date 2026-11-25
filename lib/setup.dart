import 'theme.dart';
import 'package:flutter/material.dart';
import 'cloud.dart';
import 'store.dart';
import 'tabs.dart';

/// One-time setup after the age check: choose your tabs and optional Google backup.
class SetupPage extends StatelessWidget {
  final Store prefs;
  final VoidCallback onDone;
  const SetupPage({super.key, required this.prefs, required this.onDone});

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          child: ListView(padding: const EdgeInsets.all(22), children: [
            const Text('Make it yours', style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Color(0xFF21877C))),
            const SizedBox(height: 8),
            const Text('Choose the tabs you want, put them in your order and pick which opens first. You can change all of this later in Settings.'),
            const SizedBox(height: 14),
            Card(elevation: 0, color: cardBg(context), child: Padding(padding: const EdgeInsets.all(14), child: TabsEditor(prefs: prefs))),
            const SizedBox(height: 18),
            const Text('Backup (optional)', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Card(elevation: 0, color: cardBg(context), child: Padding(padding: const EdgeInsets.all(14), child: CloudBackupPanel(prefs: prefs))),
            const SizedBox(height: 18),
            FilledButton(
              onPressed: () async {
                await prefs.setBool('setup_done', true);
                onDone();
              },
              child: const Text('Start'),
            ),
          ]),
        ),
      );
}
