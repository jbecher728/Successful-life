import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:cryptography/cryptography.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show SystemNavigator;
import 'package:local_auth/local_auth.dart';
import 'store.dart';

/// Optional PIN and biometric lock. Data lives in Keystore-backed secure storage.
class AppLock {
  static Future<bool> hasPin() async => (await secure.read(key: 'pin_hash')) != null;
  static Future<int> pinLength() async => int.tryParse(await secure.read(key: 'pin_len') ?? '') ?? 4;
  static Future<bool> bioEnabled() async => (await secure.read(key: 'lock_bio')) == '1';
  static Future<void> setBio(bool v) async {
    if (v) {
      await secure.write(key: 'lock_bio', value: '1');
    } else {
      await secure.delete(key: 'lock_bio');
    }
  }

  static Future<String> _hash(String pin, String salt) async {
    final kdf = Pbkdf2(macAlgorithm: Hmac.sha256(), iterations: 10000, bits: 256);
    final k = await kdf.deriveKeyFromPassword(password: pin, nonce: base64Decode(salt));
    return base64Encode(await k.extractBytes());
  }

  static Future<void> setPin(String pin) async {
    final r = Random.secure();
    final salt = base64Encode(List<int>.generate(16, (_) => r.nextInt(256)));
    await secure.write(key: 'pin_salt', value: salt);
    await secure.write(key: 'pin_hash', value: await _hash(pin, salt));
    await secure.write(key: 'pin_len', value: '${pin.length}');
    await secure.delete(key: 'pin_fails');
    await secure.delete(key: 'pin_until');
  }

  static Future<bool> verify(String pin) async {
    final salt = await secure.read(key: 'pin_salt');
    final h = await secure.read(key: 'pin_hash');
    if (salt == null || h == null) return false;
    return (await _hash(pin, salt)) == h;
  }

  static Future<void> clearPin() async {
    for (final k in ['pin_hash', 'pin_salt', 'pin_len', 'lock_bio', 'pin_fails', 'pin_until']) {
      await secure.delete(key: k);
    }
  }

  static Future<bool> bioAvailable() async {
    try {
      final a = LocalAuthentication();
      return (await a.canCheckBiometrics) && (await a.getAvailableBiometrics()).isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> authBio() async {
    try {
      return await LocalAuthentication().authenticate(
        localizedReason: 'Unlock Successful Life',
        options: const AuthenticationOptions(biometricOnly: true, stickyAuth: true),
      );
    } catch (_) {
      return false;
    }
  }
}

/// Shows the app, covering it with a lock screen when a PIN is set.
class LockGate extends StatefulWidget {
  final Widget child;
  const LockGate({super.key, required this.child});
  @override
  State<LockGate> createState() => _LockGateState();
}

class _LockGateState extends State<LockGate> with WidgetsBindingObserver {
  bool? locked;
  DateTime? pausedAt;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    AppLock.hasPin().then((v) {
      if (mounted) setState(() => locked = v);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    if (s == AppLifecycleState.paused) {
      pausedAt = DateTime.now();
    } else if (s == AppLifecycleState.resumed) {
      final p = pausedAt;
      pausedAt = null;
      if (p != null && DateTime.now().difference(p).inSeconds > 30) {
        AppLock.hasPin().then((v) {
          if (v && mounted) setState(() => locked = true);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(children: [
      widget.child,
      if (locked == null)
        const Positioned.fill(child: ColoredBox(color: Color(0xFFF8FAF8), child: Center(child: CircularProgressIndicator())))
      else if (locked == true)
        Positioned.fill(child: LockScreen(onUnlocked: () => setState(() => locked = false))),
    ]);
  }
}

class LockScreen extends StatefulWidget {
  final VoidCallback onUnlocked;
  const LockScreen({super.key, required this.onUnlocked});
  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  String entry = '';
  int len = 4;
  bool bio = false;
  String? msg;
  int waitLeft = 0;
  Timer? timer;
  bool busy = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    len = await AppLock.pinLength();
    bio = await AppLock.bioEnabled() && await AppLock.bioAvailable();
    await _checkWait();
    if (mounted) setState(() {});
    if (bio && waitLeft == 0) _tryBio();
  }

  Future<void> _checkWait() async {
    final until = int.tryParse(await secure.read(key: 'pin_until') ?? '') ?? 0;
    final left = ((until - DateTime.now().millisecondsSinceEpoch) / 1000).ceil();
    waitLeft = left > 0 ? left : 0;
    timer?.cancel();
    if (waitLeft > 0) {
      timer = Timer.periodic(const Duration(seconds: 1), (t) {
        if (!mounted) return;
        setState(() {
          waitLeft--;
          if (waitLeft <= 0) {
            waitLeft = 0;
            t.cancel();
            msg = null;
          }
        });
      });
    }
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  Future<void> _tryBio() async {
    if (await AppLock.authBio()) widget.onUnlocked();
  }

  Future<void> _press(String d) async {
    if (busy || waitLeft > 0 || entry.length >= 6) return;
    setState(() {
      entry += d;
      msg = null;
    });
    if (entry.length == len) await _submit();
  }

  Future<void> _submit() async {
    busy = true;
    final ok = await AppLock.verify(entry);
    if (ok) {
      await secure.delete(key: 'pin_fails');
      await secure.delete(key: 'pin_until');
      busy = false;
      widget.onUnlocked();
      return;
    }
    final fails = (int.tryParse(await secure.read(key: 'pin_fails') ?? '') ?? 0) + 1;
    await secure.write(key: 'pin_fails', value: '$fails');
    if (fails >= 5) {
      final secs = 30 * (fails - 4);
      await secure.write(key: 'pin_until', value: '${DateTime.now().millisecondsSinceEpoch + secs * 1000}');
      await _checkWait();
    }
    busy = false;
    if (mounted) {
      setState(() {
        entry = '';
        msg = fails >= 5 ? 'Too many tries. Please wait.' : 'Incorrect PIN';
      });
    }
  }

  Future<void> _forgot() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Forgot your PIN?'),
        content: const Text('Your data is encrypted and there is no way to recover a forgotten PIN. The only option is to erase everything on this phone and start fresh. This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Erase everything')),
        ],
      ),
    );
    if (ok != true) return;
    await Store.wipeEverything();
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Data erased'),
        content: const Text('Open the app again to start fresh.'),
        actions: [TextButton(onPressed: () => SystemNavigator.pop(), child: const Text('Close app'))],
      ),
    );
  }

  Widget _key(String label, {VoidCallback? onTap, IconData? icon}) {
    return SizedBox(
      width: 78,
      height: 64,
      child: TextButton(
        onPressed: onTap,
        child: icon != null ? Icon(icon, size: 26) : Text(label, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w500)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFF8FAF8),
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.lock_outline, size: 40, color: Color(0xFF21877C)),
              const SizedBox(height: 12),
              const Text('Successful Life', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              const Text('Enter your PIN'),
              const SizedBox(height: 18),
              Row(mainAxisSize: MainAxisSize.min, children: List<Widget>.generate(len, (i) => Container(
                    margin: const EdgeInsets.symmetric(horizontal: 6),
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: i < entry.length ? const Color(0xFF21877C) : Colors.transparent,
                      border: Border.all(color: const Color(0xFF21877C), width: 2),
                    ),
                  ))),
              const SizedBox(height: 10),
              SizedBox(
                height: 22,
                child: Text(waitLeft > 0 ? 'Try again in ${waitLeft}s' : (msg ?? ''), style: const TextStyle(color: Colors.redAccent)),
              ),
              const SizedBox(height: 6),
              for (final row in const [['1', '2', '3'], ['4', '5', '6'], ['7', '8', '9']])
                Row(mainAxisSize: MainAxisSize.min, children: row.map((d) => _key(d, onTap: () => _press(d))).toList()),
              Row(mainAxisSize: MainAxisSize.min, children: [
                bio ? _key('', icon: Icons.fingerprint, onTap: _tryBio) : const SizedBox(width: 78, height: 64),
                _key('0', onTap: () => _press('0')),
                _key('', icon: Icons.backspace_outlined, onTap: () => setState(() {
                      if (entry.isNotEmpty) entry = entry.substring(0, entry.length - 1);
                    })),
              ]),
              const SizedBox(height: 12),
              TextButton(onPressed: _forgot, child: const Text('Forgot PIN?')),
            ]),
          ),
        ),
      ),
    );
  }
}

/// App lock controls for the Settings page.
class LockSettingsPanel extends StatefulWidget {
  const LockSettingsPanel({super.key});
  @override
  State<LockSettingsPanel> createState() => _LockSettingsPanelState();
}

class _LockSettingsPanelState extends State<LockSettingsPanel> {
  bool hasPin = false;
  bool bio = false;
  bool bioAvail = false;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final h = await AppLock.hasPin();
    final b = await AppLock.bioEnabled();
    final a = await AppLock.bioAvailable();
    if (mounted) {
      setState(() {
        hasPin = h;
        bio = b;
        bioAvail = a;
      });
    }
  }

  Future<String?> _ask(String title, {String hint = '4 to 6 digits'}) {
    final c = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: c,
          autofocus: true,
          obscureText: true,
          keyboardType: TextInputType.number,
          maxLength: 6,
          decoration: InputDecoration(hintText: hint, counterText: ''),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, c.text), child: const Text('OK')),
        ],
      ),
    );
  }

  void _toast(String t) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t)));
  }

  bool _validPin(String? p) => p != null && RegExp(r'^\d{4,6}$').hasMatch(p);

  Future<bool> _verifyCurrent() async {
    final cur = await _ask('Enter your current PIN');
    if (cur == null) return false;
    if (await AppLock.verify(cur)) return true;
    _toast('Incorrect PIN');
    return false;
  }

  Future<void> _newPin() async {
    final p1 = await _ask('Choose a PIN');
    if (p1 == null) return;
    if (!_validPin(p1)) {
      _toast('Use 4 to 6 digits.');
      return;
    }
    final p2 = await _ask('Enter it again');
    if (p2 != p1) {
      _toast('The PINs did not match.');
      return;
    }
    await AppLock.setPin(p1);
    _toast('PIN set.');
    await _refresh();
  }

  Future<void> _setUp() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Before you set a PIN'),
        content: const Text('If you forget your PIN there is no way to recover your data, because it is encrypted on this phone. You would have to erase everything and start over. Export a backup first if you want a safety copy.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Continue')),
        ],
      ),
    );
    if (ok == true) await _newPin();
  }

  Future<void> _change() async {
    if (await _verifyCurrent()) await _newPin();
  }

  Future<void> _turnOff() async {
    if (!await _verifyCurrent()) return;
    await AppLock.clearPin();
    _toast('PIN turned off. The app now opens without a PIN.');
    await _refresh();
  }

  Future<void> _toggleBio(bool v) async {
    if (v) {
      if (!await AppLock.authBio()) {
        _toast('Biometric check failed.');
        return;
      }
    }
    await AppLock.setBio(v);
    await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('App lock', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Text(hasPin
              ? 'On. A PIN is needed to open the app (after 30 seconds away).'
              : 'Off. The app opens without a PIN. That is entirely your choice, and you can turn it on any time.'),
          const SizedBox(height: 10),
          if (!hasPin)
            FilledButton.icon(onPressed: _setUp, icon: const Icon(Icons.pin_outlined), label: const Text('Set a PIN'))
          else ...[
            Row(children: [
              Expanded(child: OutlinedButton(onPressed: _change, child: const Text('Change PIN'))),
              const SizedBox(width: 8),
              Expanded(child: OutlinedButton(onPressed: _turnOff, child: const Text('Turn off PIN'))),
            ]),
            if (bioAvail)
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Unlock with fingerprint or face'),
                value: bio,
                onChanged: _toggleBio,
              ),
          ],
        ]),
      ),
    );
  }
}
