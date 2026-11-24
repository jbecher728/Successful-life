import 'package:flutter/material.dart';

const _teal = Color(0xFF21877C);

Widget _h(String t) => Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 6),
      child: Text(t, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
    );

Widget _p(String t) => Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(t, style: const TextStyle(height: 1.4)));

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('About', style: TextStyle(fontWeight: FontWeight.bold))),
      body: SafeArea(
        child: ListView(padding: const EdgeInsets.all(20), children: [
          const SizedBox(height: 8),
          const Text('Successful Life', style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold, color: _teal)),
          const SizedBox(height: 4),
          const Text('A private 90-day companion for body, mind and relationships.', style: TextStyle(fontSize: 15)),
          const SizedBox(height: 14),
          const Text('Version 0.1 (test build)', style: TextStyle(color: Colors.grey)),
          const Text('Created in 2026 by Joel B.', style: TextStyle(fontWeight: FontWeight.w600)),
          const Text('© 2026 Joel B.', style: TextStyle(color: Colors.grey)),
          _h('What this app is'),
          _p('A daily journal, guided questions, at-home workouts, body tracking and small daily thoughts, all designed to help you grow at your own pace. It works offline and keeps your information on your phone.'),
          _h('Not medical advice'),
          _p('Successful Life offers general wellness and fitness information. It is not medical, mental health or professional advice, and it does not diagnose or treat anything. Talk to a doctor before starting an exercise program, especially if you are pregnant, injured or have a health condition. Stop any exercise that causes pain, dizziness or distress.'),
          _h('Need support?'),
          _p('This app is not a crisis service. If you are in immediate danger, call your local emergency number. In the United States you can call or text 988 (Suicide & Crisis Lifeline) at any time. Outside the US, findahelpline.com lists services by country. Reaching out to someone you trust, or a licensed professional, is a strong thing to do.'),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: () => Navigator.push(context, MaterialPageRoute<void>(builder: (_) => const PrivacyPage())),
            icon: const Icon(Icons.lock_outline),
            label: const Text('Privacy notice'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => showLicensePage(context: context, applicationName: 'Successful Life', applicationVersion: '0.1'),
            icon: const Icon(Icons.description_outlined),
            label: const Text('Open-source licenses'),
          ),
          const SizedBox(height: 24),
        ]),
      ),
    );
  }
}

class PrivacyPage extends StatelessWidget {
  const PrivacyPage({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Privacy notice', style: TextStyle(fontWeight: FontWeight.bold))),
      body: SafeArea(
        child: ListView(padding: const EdgeInsets.all(20), children: [
          const Text('Last updated: November 2026', style: TextStyle(color: Colors.grey)),
          _h('In short'),
          _p('Your information stays on your phone. This app does not have accounts, servers or analytics, and it does not send your data anywhere on its own.'),
          _h('What the app never asks for'),
          _p('Your full name, address, city, ZIP or postal code, phone number, email address, location, contacts or photos. You never need to create an account or sign in.'),
          _h('What you may choose to enter'),
          _p('Journal text, mood and energy ratings, your Male/Female choice, height, weight and body measurements, workout logs and reflections. This is stored only in the app’s private storage on your device. The app does not encrypt it, so keep your phone protected with a screen lock.'),
          _h('No tracking'),
          _p('The app contains no analytics, tracking or crash-reporting tools. Reminders and daily quotes are scheduled on your device and do not use a server.'),
          _h('Sharing is always your choice'),
          _p('Information leaves your phone only when you use a Share or Export button. These open your phone’s share menu, and whichever app you pick receives what you chose to send. "Share with AI" sends only the text shown, to the app you select. An export zip contains only the sections you tick. Treat it as private, and share it only with people you trust, such as a coach, doctor or therapist.'),
          _h('Backups and new phones'),
          _p('Automatic cloud backup is turned off for this app so your data is not copied elsewhere without you knowing. To move to a new phone, use Settings > Export, then Import on the new phone.'),
          _h('Advertising'),
          _p('This version of the app contains no advertising. If advertising is added in a future version, advertising companies may collect information such as device identifiers and ad interactions under their own privacy policies. That collection would be outside the app developer’s control. This notice would be updated before any ads appear.'),
          _h('Your control'),
          _p('You can delete everything at any time with Settings > Delete all my data, or by uninstalling the app. Uninstalling removes the app’s data from your phone, so export first if you want to keep it.'),
          _h('Age'),
          _p('This app is intended for adults aged 18 and over.'),
          _h('Changes'),
          _p('If this notice changes, the new version will appear on this page with an updated date.'),
          const SizedBox(height: 24),
        ]),
      ),
    );
  }
}
