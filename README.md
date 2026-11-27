# Shell

*(Formerly “Successful Life”. The repository and web address keep the old name for now.)*

A private, simple personal-development companion for Android (Flutter), plus an installable web app for iPhone: daily focus, journaling, genuine-connection prompts, at-home fitness and body tracking. Everything stays on your phone.

> **Status:** early test build (v0.3). It compiles in CI but has not been verified on a physical device yet. Signed with a debug key, for personal testing only.

## Download a test build

Install the latest APK from the [Releases page](../../releases). Install `successful-life-arm64.apk`, which works on almost every phone made since about 2017 (very old 32-bit phones are not supported). **iPhone:** use the web app at https://jbecher728.github.io/Successful-life/ (open in Safari, tap Share, then Add to Home Screen). A native iOS app is planned for later. Android will ask you to allow installs from your browser or file manager.

## Principles

- **Simple** and easy to follow.
- **No personal data collected.** No name, address, city, ZIP, phone or email. No account, no sign-in, no ads, no server.
- **Local forever.** Data lives only on the phone, encrypted, unless *you* choose to share an export zip or turn on the optional backup.
- **Your choice.** Tabs, PIN and backup are all optional and adjustable.

## Features

| Area | What it does |
|---|---|
| **Today** | Daily goal, 90-day timeline with weekly themes, progress view, daily shareable thought |
| **Goals** (inside Today) | Planner and to-do list: importance 1-10, start and done-by dates and times, goals that stretch over days or weeks, check boxes, encouraging reminders |
| **Journal** | Private journal with mood and energy ratings and history |
| **Connect** | Solo and two-person question cards: Ice Breakers, Confessions, Getting Deep, Challenge (2,500 prompts). Play one category or shuffle several |
| **Fitness** | 125+ at-home exercises, including a pull-up progression, in 7 categories, tailored to Male/Female, with a daily workout builder, timers and looping stick-figure form guides |
| **Body** | Height, weight and tape measurements; BMI, waist ratios and trends (screening only, not medical advice) |
| **Notifications** | Morning shareable thought, midday action, evening reflection, optional birthday greeting. All on-device |
| **Export / import** | Settings > Export builds a zip (CSV + JSON) with only the sections you pick; Import restores it on a new phone |

### Six areas of life

Physical, Intellectual, Emotional, Social, Occupational & financial, and Spiritual (purpose and values, not necessarily religion). A life-balance wheel in Progress compares how satisfied you feel (1 to 10) with what you actually did in the last 30 days. Goals can be tagged by area, exercises count as Physical and Connect questions as Social, Today suggests the quietest area with an idea, the daily journal prompt rotates through the areas, and the weekly review shows activity by area. Each area has eight very short lessons (a couple of sentences and one tiny action, with an optional "Explain" for the longer version), plus rating trends. Switch it off in Settings > Look and extras.

### Self-improvement extras (all optional, Settings > Look and extras)

- **Repeating goals** (daily, weekly or certain days) with forgiving streaks: one missed day never breaks a streak.
- **Weekly review** with a summary, three reflection questions and a shareable image card (numbers only, no personal text).
- **Hatching egg** progress, **mood patterns**, **"I am becoming..."** line and a **journal prompt** each day.
- **Calm** breathing timer, **rough-day mode** (gentler plan, 988 / findahelpline.com), **focus timer**, **7-day challenges**.
- **Letters to future me** delivered by notification on a date you pick.
- **Add to my goals** buttons on exercises and Connect questions, a monthly **backup reminder**, **dark mode** and larger text.

## Customization and safety

- **Tabs:** turn tabs on or off, drag to reorder, and choose which opens first (during setup or later in Settings). Settings, Privacy and About are in the small top-right menu.
- **Age check:** birth month and year (day optional, for a birthday greeting) decide the age group, on the device only.
  - **18+:** full app.
  - **13-17:** Teen mode with a parent/guardian approval step. No weight/BMI tracking, no advanced workouts or Deep Core Foundation exercises, no romantic prompts. Switches to Adult automatically at 18.
  - **Under 13:** not allowed. The app stays closed until their 13th birthday (remembered on the phone only).
- **App lock:** optional PIN and/or fingerprint/face unlock. Fully optional. There is no PIN recovery: "Forgot PIN" erases the app's data.
- **Encrypted storage:** data is saved in an AES-256-GCM encrypted file; the key is in the Android Keystore.
- **Optional Google backup (off by default):** an encrypted copy locked by a backup passphrase is uploaded by Android's built-in backup to your own Google account. Lose the passphrase and the backup cannot be opened. Apple iCloud is planned.

## Privacy

The app collects nothing and sends nothing. Exported zips are **not** encrypted, so share them deliberately. Full details are in the in-app Privacy notice and Terms of use (menu > About).

## Build

Pushes to `main` run the GitHub Actions workflow (`.github/workflows/android-apk.yml`). The Android job generates the Android scaffolding, applies `scripts/configure_android.py`, analyzes, builds small release APKs (arm64 only, well under 25 MB) and the web job builds the installable web app and publishes it to GitHub Pages. The native iOS job (`scripts/configure_ios.py`) is switched off for now to save build minutes.

To build locally you need Flutter and the Android SDK:

```sh
./build_local.sh
# APK: build/app/outputs/flutter-apk/app-debug.apk
```

## Project layout

- `lib/` app code: `main.dart` (home, settings), `store.dart` (encrypted storage and backup), `lock.dart`, `onboarding.dart`, `setup.dart`, `tabs.dart`, `cloud.dart`, `exercise.dart`, `body.dart`, `figure.dart`, `export.dart`, `about.dart`, `planner.dart` (goals), `review.dart`, `letters.dart`, `calm.dart`, `rough.dart`, `challenges.dart`, `extras_ui.dart`, `theme.dart`
- `assets/` questions, quotes, nudges, exercises and stick-figure motion data
- `scripts/configure_android.py` Android permissions, backup rules, biometrics and build fixes
- `scripts/configure_ios.py` iOS Face ID text, iPhone-only, notifications and backup exclusion

## Known limitations

- Not yet tested on a physical device (PIN, biometrics, backup/restore and notifications especially).
- Reminders are inexact and may be delayed by Android battery settings.
- The parent/guardian approval and age check cannot be verified, and clearing the app's data resets them.
- The Terms of use are a plain-language draft, not legal advice. Age ratings and children's privacy rules (COPPA, GDPR-K) need review before any store release.
- Play Store release still needs a permanent application ID, release signing and a contact address (currently the placeholder `support@email.com`).
- The native iOS app is paused (no Apple developer account yet); iPhone users use the web app. iCloud backup is not built yet. The web version has no notifications, Face ID or backup.

## Credits

Created in 2026 by Joel B. Not medical advice. If you need support, call or text 988 (US) or visit [findahelpline.com](https://findahelpline.com).

**Questions for someone close (v0.8):** 96 original questions (Light, Deeper, Honest; 32 each) for a partner, friend or family member. A weekly question appears on Today, with a shuffle that never repeats a question until the whole level has been seen, optional reminders (you choose the days and how many times a day; unticked days stay quiet), and a guided evening (three sets that get deeper, take turns, optional quiet pause). Nothing anyone answers is saved; only which questions were already shown. Switch it off in Settings > Look and extras.

**Growth check-ins (v0.9):** a two-minute, eight-statement self-reflection for each of the six areas, scored as a simple percentage with plain bands (Early days, Building, Steady, Strong), strengths, two areas to grow with one-tap goals, comparison with the last time, and an optional update of the area rating. Not a clinical or scientific test, and everything stays on the device. Switch it off in Settings > Look and extras.
