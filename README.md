# Successful Life • Android test build

This is a **build candidate**, not a verified compiled APK. It contains the original Flutter prototype and a GitHub Actions workflow that generates Android scaffolding and compiles an installable **debug APK**. It has not been compiled or run on a physical device in this environment.

## Easiest build, from your Android phone

1. Create a free GitHub account at https://github.com if needed.
2. Create a new **private** repository named `successful-life`. Do not add an auto-generated README.
3. Extract this ZIP. Upload the **contents** of the `successful_life_flutter` folder into the repository root. GitHub's web upload may omit hidden `.github` directories on some phone file pickers. Confirm the repository shows `.github/workflows/android-apk.yml`, `scripts/configure_android.py`, `lib/main.dart`, and `pubspec.yaml`. If hidden files are hard to upload, use the GitHub mobile web interface in desktop mode or a Git client.
4. Open the repository's **Actions** tab, choose **Build Android test APK**, and tap **Run workflow**. On the first upload to `main`, the workflow also runs automatically.
5. After the workflow finishes successfully, open the run, scroll to **Artifacts**, and download `successful-life-android-test-apk`. Unzip it and tap `app-debug.apk` to install. Android may require you to allow installs from your file manager/browser.
6. If the workflow fails, open the failed step and share its error log for a targeted fix. The first build can take several minutes.

**Important:** The APK is debug-signed, suitable for personal testing, not Play Store distribution. For Play Store release, configure your permanent application ID, signing keys, release build, privacy disclosures, subscriptions, and ad consent.

## Alternative: computer

Install Flutter SDK, Android Studio and Android SDK, then from this project folder:

```sh
flutter create --platforms=android --project-name successful_life --org com.successfullife .
python3 scripts/configure_android.py
flutter pub get
flutter build apk --debug
```

Find APK at `build/app/outputs/flutter-apk/app-debug.apk`.

## What's implemented

- Today dashboard, daily goal and completion
- 90-day timeline with weekly themes and basic tasks
- Private text journal, mood/energy ratings, history and progress
- Three local reminders with adjustable times
- Manual sharing of a selected journal entry to an installed AI app via Android Share
- Basic JSON export through Share
- No sign-in, ads, subscriptions or server database

## Known limitations before public release

- No native restore/import flow; export must be saved safely before uninstalling.
- `shared_preferences` is **not encrypted**; the journal is stored in app-private storage but should be migrated to an encrypted database before release.
- Not all 90 tasks are unique; later days rotate prompts by weekly theme.
- Discovery and Connect are planned, not implemented in this build.
- Notification permissions and delivery vary by Android settings; reminders are inexact and may be delayed.
- AI sharing requires explicit user action and sends selected text to a third-party app only if the user chooses to share.
- The project is not yet tested or verified on an Android phone or iOS.
- Android auto-backup and device transfer are disabled for local-only privacy.
- The `com.successfullife.successful_life` package ID is provisional; choose a permanent reverse-domain ID before publishing.
