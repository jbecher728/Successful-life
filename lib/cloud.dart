import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'store.dart';

/// Turn the optional Google backup on or off. Off by default.
class CloudBackupPanel extends StatefulWidget {
  final Store prefs;
  const CloudBackupPanel({super.key, required this.prefs});
  @override
  State<CloudBackupPanel> createState() => _CloudBackupPanelState();
}

class _CloudBackupPanelState extends State<CloudBackupPanel> {
  bool busy = false;

  Future<void> _turnOn() async {
    final a = TextEditingController(), b = TextEditingController();
    String? err;
    final pass = await showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: const Text('Back up to Google'),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Your data is locked with a backup passphrase before it leaves this phone, so Google only stores scrambled data. You will need this passphrase to restore on a new phone. It cannot be recovered if you forget it, so write it down somewhere safe.', style: TextStyle(height: 1.4)),
              const SizedBox(height: 12),
              TextField(controller: a, obscureText: true, decoration: const InputDecoration(labelText: 'Backup passphrase (8+ characters)')),
              TextField(controller: b, obscureText: true, decoration: const InputDecoration(labelText: 'Type it again')),
              if (err != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(err!, style: const TextStyle(color: Colors.red))),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            FilledButton(
              onPressed: () {
                if (a.text.length < 8) {
                  setD(() => err = 'Use at least 8 characters.');
                } else if (a.text != b.text) {
                  setD(() => err = 'The passphrases do not match.');
                } else {
                  Navigator.pop(ctx, a.text);
                }
              },
              child: const Text('Turn on'),
            ),
          ],
        ),
      ),
    );
    if (pass == null) return;
    setState(() => busy = true);
    await widget.prefs.enableCloud(pass);
    if (mounted) setState(() => busy = false);
  }

  Future<void> _turnOff() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Turn off Google backup?'),
        content: const Text('The backup file is removed from this phone, and the copy in your Google account is replaced the next time Android backs up. Your data on this phone is not affected.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Turn off')),
        ],
      ),
    );
    if (ok != true) return;
    await widget.prefs.disableCloud();
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      return const Text('Backups are not available in the web version, and nothing is sent anywhere. Your data lives only in this browser on this device. Use Settings > Export regularly to save a copy to your Files, and Import to restore it.', style: TextStyle(height: 1.4));
    }
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return const Text('iCloud backup is planned for a later version. For now, your data stays only on this iPhone and is not included in iCloud or iTunes backups. To move to a new phone, use Settings > Export, then Import.', style: TextStyle(height: 1.4));
    }
    final on = widget.prefs.cloudOn;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text('Back up to my Google account'),
        subtitle: Text(on ? 'On. An encrypted copy is kept up to date and Android uploads it automatically.' : 'Off. Your data stays only on this phone.'),
        value: on,
        onChanged: busy ? null : (v) => v ? _turnOn() : _turnOff(),
      ),
      if (busy) const LinearProgressIndicator(),
      const SizedBox(height: 6),
      const Text('This uses your phone’s built-in Google backup, so “Backup by Google” must be on in your phone’s Settings. Android decides when to upload (usually overnight on Wi-Fi while charging). Apple iCloud backup is planned for a later version.', style: TextStyle(fontSize: 12, color: Colors.grey, height: 1.4)),
    ]);
  }
}

/// Shown on a fresh install when Android has restored a backup file from the user's Google account.
class RestoreScreen extends StatefulWidget {
  final Store prefs;
  final VoidCallback onDone;
  const RestoreScreen({super.key, required this.prefs, required this.onDone});
  @override
  State<RestoreScreen> createState() => _RestoreScreenState();
}

class _RestoreScreenState extends State<RestoreScreen> {
  final c = TextEditingController();
  bool busy = false;
  String? err;

  Future<void> _restore() async {
    setState(() { busy = true; err = null; });
    final ok = await widget.prefs.restoreFromCloud(c.text);
    if (!mounted) return;
    if (ok) {
      widget.onDone();
    } else {
      setState(() { busy = false; err = 'That passphrase did not work.'; });
    }
  }

  Future<void> _fresh() async {
    await Store.deleteCloudFile();
    widget.onDone();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: const Color(0xFFF8FAF8),
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Welcome back', style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Color(0xFF21877C))),
                const SizedBox(height: 12),
                const Text('A backup from your Google account was found. Enter your backup passphrase to restore your journal, progress and settings.'),
                const SizedBox(height: 16),
                TextField(controller: c, obscureText: true, decoration: const InputDecoration(labelText: 'Backup passphrase', border: OutlineInputBorder())),
                if (err != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(err!, style: const TextStyle(color: Colors.red))),
                const SizedBox(height: 16),
                FilledButton(onPressed: busy ? null : _restore, child: Text(busy ? 'Restoring…' : 'Restore')),
                if (busy) const Padding(padding: EdgeInsets.only(top: 10), child: LinearProgressIndicator()),
                TextButton(onPressed: busy ? null : _fresh, child: const Text('Start fresh instead (removes the old backup)')),
              ]),
            ),
          ),
        ),
      );
}
