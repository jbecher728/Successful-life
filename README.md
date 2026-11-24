# Successful Life

A private, simple personal-development companion for Android: daily focus, journaling, genuine-connection prompts, at-home fitness and body tracking. Everything stays on your phone.

> **Status:** early test build (v0.3). It compiles in CI but has not been verified on a physical device yet. Debug-signed, for personal testing only.

## Download a test build

Install the latest APK from the [Releases page](../../releases) (`successful-life-test.apk`). Android will ask you to allow installs from your browser or file manager.

## Principles

- **Simple** and easy to follow.
- **No personal data collected.** No name, address, city, ZIP, phone or email. No account, no sign-in, no ads, no server.
- **Local forever.** Data lives only on the phone, encrypted, unless *you* choose to share an export zip or turn on the optional backup.
- **Your choice.** Tabs, PIN and backup are all optional and adjustable.

## Features

| Area | What it does |
|---|---|
| **Today** | Daily goal, 90-day timeline with weekly themes, progress view, daily shareable thought |
| **Journal** | Private journal with mood and energy ratings and history |
| **Connect** | Solo and two-person question cards: Ice Breakers, Confessions, Getting Deep, Challenge (2,500 prompts). Play one category or shuffle several |
| **Fitness** | 120+ at-home exercises in 7 categories, tailored to Male/Female, with a daily workout builder, timers and looping stick-figure form guides |
| **Body** | Height, weight and tape measurements; BMI, waist ratios and trends (screening only, not medical advice) |
| **Notifications** | Morning shareable thought, midday action, evening reflection, optional birthday greeting. All on-device |
| **Export / import** | Settings > Export builds a zip (CSV + JSON) with only the sections you pick; Import restores it on a new phone |

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

Pushes to `main` run the GitHub Actions workflow (`.github/workflows/android-apk.yml`), which generates the Android scaffolding, applies `scripts/configure_android.py`, analyzes, builds a debug APK and publishes it as a `test-build-N` release.

To build locally you need Flutter and the Android SDK:

```sh
./build_local.sh
# APK: build/app/outputs/flutter-apk/app-debug.apk
```

## Project layout

- `lib/` app code: `main.dart` (home, settings), `store.dart` (encrypted storage and backup), `lock.dart`, `onboarding.dart`, `setup.dart`, `tabs.dart`, `cloud.dart`, `exercise.dart`, `body.dart`, `figure.dart`, `export.dart`, `about.dart`
- `assets/` questions, quotes, nudges, exercises and stick-figure motion data
- `scripts/configure_android.py` Android permissions, backup rules, biometrics and build fixes

## Known limitations

- Not yet tested on a physical device (PIN, biometrics, backup/restore and notifications especially).
- Reminders are inexact and may be delayed by Android battery settings.
- The parent/guardian approval and age check cannot be verified, and clearing the app's data resets them.
- The Terms of use are a plain-language draft, not legal advice. Age ratings and children's privacy rules (COPPA, GDPR-K) need review before any store release.
- Play Store release still needs a permanent application ID, release signing and a contact address (currently the placeholder `support@email.com`).
- Android only for now.

## Credits

Created in 2026 by Joel B. Not medical advice. If you need support, call or text 988 (US) or visit [findahelpline.com](https://findahelpline.com).
