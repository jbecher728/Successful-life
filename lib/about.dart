import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

const _teal = Color(0xFF21877C);
const appVersion = '0.2 (test build)';

/// Add a feedback email address here when one is set up. It is shown on the About page.
const contactEmail = 'support@email.com';

Widget _h(String t) => Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 6),
      child: Text(t, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
    );

Widget _p(String t) => Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(t, style: const TextStyle(height: 1.4)));

Widget _page(BuildContext context, String title, List<Widget> children) => Scaffold(
      appBar: AppBar(title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold))),
      body: SafeArea(child: ListView(padding: const EdgeInsets.all(20), children: [...children, const SizedBox(height: 24)])),
    );

void _open(BuildContext context, Widget page) => Navigator.push(context, MaterialPageRoute<void>(builder: (_) => page));

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});
  @override
  Widget build(BuildContext context) {
    return _page(context, 'About', [
      const SizedBox(height: 8),
      const Text('Successful Life', style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold, color: _teal)),
      const SizedBox(height: 4),
      const Text('A private 90-day companion for body, mind and relationships.', style: TextStyle(fontSize: 15)),
      const SizedBox(height: 14),
      const Text('Version $appVersion', style: TextStyle(color: Colors.grey)),
      const Text('Created in 2026 by Joel B.', style: TextStyle(fontWeight: FontWeight.w600)),
      const Text('© 2026 Joel B.', style: TextStyle(color: Colors.grey)),
      _h('What this app is'),
      _p('A daily journal, guided questions, at-home workouts, body tracking and small daily thoughts, all designed to help you grow at your own pace. It works offline and keeps your information on your phone, encrypted.'),
      _h('Not medical advice'),
      _p('Successful Life offers general wellness and fitness information. It is not medical, mental health or professional advice, and it does not diagnose or treat anything. Talk to a doctor before starting an exercise program, especially if you are pregnant, injured or have a health condition. Stop any exercise that causes pain, dizziness or distress.'),
      _h('Need support?'),
      _p('This app is not a crisis service. If you are in immediate danger, call your local emergency number. In the United States you can call or text 988 (Suicide & Crisis Lifeline) at any time. Outside the US, findahelpline.com lists services by country. Reaching out to someone you trust, or a licensed professional, is a strong thing to do.'),
      _h('For parents and guardians'),
      _p('Teens aged 13 to 17 can use Successful Life with a parent or guardian’s knowledge and approval. In Teen mode the app does not track weight or BMI, hides advanced workouts and the Deep Core Foundation exercises, and leaves out romantic prompts. The app has no accounts, no ads and no tracking, and nothing leaves the phone unless your teen chooses to share it. The journal is your teen’s private space, so we suggest talking openly about how they use it. The app is not for children under 13.'),
      _h('What’s new'),
      _p('Version 0.3: choose, reorder and hide tabs, pick your start tab, optional Google backup, optional PIN and fingerprint/face lock, encrypted on-device storage, Teen mode with parent or guardian approval, stick-figure exercise guides, Fitness and Body tabs, daily thoughts, and zip export/import.'),
      _h('Contact and feedback'),
      if (contactEmail.isNotEmpty) SelectableText(contactEmail, style: const TextStyle(fontWeight: FontWeight.w600)),
      _p('Ideas and bug reports are welcome. Please do not include private journal text. The button below opens your phone’s share menu so you choose where to send a note.'),
      OutlinedButton.icon(
        onPressed: () => Share.share('Successful Life feedback (version $appVersion):\n\n'),
        icon: const Icon(Icons.feedback_outlined),
        label: const Text('Send feedback'),
      ),
      const SizedBox(height: 14),
      FilledButton.icon(onPressed: () => _open(context, const PrivacyPage()), icon: const Icon(Icons.lock_outline), label: const Text('Privacy notice')),
      const SizedBox(height: 8),
      OutlinedButton.icon(onPressed: () => _open(context, const TermsPage()), icon: const Icon(Icons.gavel_outlined), label: const Text('Terms of use')),
      const SizedBox(height: 8),
      OutlinedButton.icon(
        onPressed: () => showLicensePage(context: context, applicationName: 'Successful Life', applicationVersion: appVersion),
        icon: const Icon(Icons.description_outlined),
        label: const Text('Open-source licenses'),
      ),
    ]);
  }
}

class PrivacyPage extends StatelessWidget {
  const PrivacyPage({super.key});
  @override
  Widget build(BuildContext context) {
    return _page(context, 'Privacy notice', [
      const Text('Last updated: November 2026', style: TextStyle(color: Colors.grey)),
      _h('In short'),
      _p('Your information stays on your phone. This app does not have accounts, servers or analytics, and it does not send your data anywhere on its own.'),
      _h('What the app never asks for'),
      _p('Your full name, address, city, ZIP or postal code, phone number, email address, location, contacts or photos. You never need to create an account or sign in. The only profile details are choices you make in the app: birth month and year (and your birth day only if you choose to add it, for a birthday greeting), Male/Female, and optional height, weight and measurements.'),
      _h('What you may choose to enter'),
      _p('Journal text, mood and energy ratings, your birthday details and Male/Female choice, height, weight and body measurements, workout logs and reflections. This is stored on your device in an encrypted file (and in an encrypted Google backup only if you turn that on). The encryption key is kept in the Android Keystore, which is protected by your phone’s hardware and screen lock.'),
      _h('App lock'),
      _p('You can optionally turn on a PIN and fingerprint or face unlock in Settings. The PIN is never stored in readable form. If you forget your PIN, your data cannot be recovered, and the only option is to erase everything and start over. Using no PIN is also fine; it is your choice.'),
      _h('No tracking'),
      _p('The app contains no analytics, tracking or crash-reporting tools. Reminders and daily quotes are scheduled on your device and do not use a server.'),
      _h('Sharing is always your choice'),
      _p('Information leaves your phone only when you use a Share or Export button. These open your phone’s share menu, and whichever app you pick receives what you chose to send. "Share with AI" sends only the text shown, to the app you select. An export zip contains only the sections you tick, and it is not encrypted, so treat it as private and share it only with people you trust, such as a coach, doctor or therapist.'),
      _h('Backups and new phones'),
      _p('Google backup is off by default, and nothing is copied anywhere unless you turn it on in Settings. If you do, you choose a backup passphrase and the app creates an encrypted copy that only that passphrase can open. Your phone’s built-in Android backup then uploads it to your own Google account; the app developer never receives it, and Google cannot read it. If you forget the passphrase the backup cannot be opened. You can turn the backup off at any time. You can also move to a new phone with Settings > Export, then Import.'),
      _h('Advertising'),
      _p('This version of the app contains no advertising. If advertising is added in a future version, advertising companies may collect information such as device identifiers and ad interactions under their own privacy policies. That collection would be outside the app developer’s control. This notice would be updated before any ads appear.'),
      _h('Teens and children'),
      _p('Teens aged 13 to 17 should use the app with a parent or guardian’s knowledge and approval. Teen mode turns off weight and BMI tracking, advanced workouts, the Deep Core Foundation exercises and romantic prompts. The app is not for children under 13 and does not store anything about them.'),
      _h('Your control'),
      _p('You can delete everything at any time with Settings > Delete all my data, or by uninstalling the app. Uninstalling removes the app’s data from your phone, so export first if you want to keep it.'),
      _h('Changes'),
      _p('If this notice changes, the new version will appear on this page with an updated date.'),
    ]);
  }
}

class TermsPage extends StatelessWidget {
  const TermsPage({super.key});
  @override
  Widget build(BuildContext context) {
    return _page(context, 'Terms of use', [
      const Text('Last updated: November 2026', style: TextStyle(color: Colors.grey)),
      _h('Using the app'),
      _p('Successful Life is provided for personal, non-commercial use. By using it you agree to these terms. Adults may use it freely. Teens aged 13 to 17 may use it only with a parent or guardian’s knowledge and approval. It is not for children under 13.'),
      _h('Not professional advice'),
      _p('The app gives general wellness, fitness and self-reflection content. It is not medical, psychological or other professional advice and is not a substitute for a doctor, therapist or coach. Always consult a qualified professional about your health. If you are in crisis, contact local emergency services.'),
      _h('Exercise at your own risk'),
      _p('Physical activity carries risk. You are responsible for choosing exercises that suit your health and ability, using safe surroundings and stopping if something hurts. Stick-figure guides are simplified illustrations.'),
      _h('Your content and data'),
      _p('What you write stays on your device and belongs to you. You are responsible for keeping your device secure, your PIN safe and your backups.'),
      _h('No warranty'),
      _p('The app is provided “as is” and “as available”, without warranties of any kind. It is a test version and may contain errors. To the fullest extent allowed by law, the creator is not liable for any loss or harm arising from use of the app.'),
      _h('Content you share'),
      _p('Quotes and prompts in the app are original to Successful Life. You are welcome to share them with friends and family for personal, positive use.'),
      _h('Changes'),
      _p('These terms may be updated. Continued use after an update means you accept the new terms.'),
    ]);
  }
}
