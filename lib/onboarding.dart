import 'package:flutter/material.dart';
import 'store.dart';

/// First-run screen. Nothing is collected: only an age group is kept, on this device.
class AgeGate extends StatefulWidget {
  final Store prefs;
  final void Function(String group) onDone;
  const AgeGate({super.key, required this.prefs, required this.onDone});
  @override
  State<AgeGate> createState() => _AgeGateState();
}

class _AgeGateState extends State<AgeGate> {
  int step = 0; // 0 choose, 1 teen approval, 2 under 13
  bool approved = false;

  Future<void> _finish(String g) async {
    await widget.prefs.setString('age_group', g);
    widget.onDone(g);
  }

  @override
  Widget build(BuildContext context) {
    Widget body;
    if (step == 1) {
      body = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Parent or guardian approval', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        const Text('Successful Life is designed to be used by teens with a parent or guardian’s knowledge and approval. Please show them this app and the Privacy notice (in the menu at the top right of the app).'),
        const SizedBox(height: 12),
        const Text('For teens, the app is in Teen mode. It does not track weight or BMI, hides advanced workouts and the Deep Core Foundation exercises, and leaves out romantic prompts. Everything stays on this phone.'),
        const SizedBox(height: 12),
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
          value: approved,
          onChanged: (v) => setState(() => approved = v ?? false),
          title: const Text('A parent or guardian has looked at this app with me and said it is OK for me to use it.'),
        ),
        const SizedBox(height: 12),
        FilledButton(onPressed: approved ? () => _finish('teen') : null, child: const Text('Continue')),
        TextButton(onPressed: () => setState(() => step = 0), child: const Text('Back')),
      ]);
    } else if (step == 2) {
      body = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Not just yet', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        const Text('Successful Life is for ages 13 and up. Please ask a parent or guardian to help you find something that suits your age. Thank you for being honest.'),
        const SizedBox(height: 16),
        TextButton(onPressed: () => setState(() => step = 0), child: const Text('Back')),
      ]);
    } else {
      body = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Welcome to Successful Life', style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Color(0xFF21877C))),
        const SizedBox(height: 12),
        const Text('To keep things safe and age-appropriate, please choose the option that fits you. No name, email or account is needed. Your choice stays on this phone.'),
        const SizedBox(height: 20),
        FilledButton(onPressed: () => _finish('adult'), child: const Text('I am 18 or older')),
        const SizedBox(height: 10),
        OutlinedButton(onPressed: () => setState(() => step = 1), child: const Text('I am 13 to 17')),
        const SizedBox(height: 10),
        OutlinedButton(onPressed: () => setState(() => step = 2), child: const Text('I am under 13')),
      ]);
    }
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAF8),
      body: SafeArea(child: Center(child: SingleChildScrollView(padding: const EdgeInsets.all(24), child: body))),
    );
  }
}
