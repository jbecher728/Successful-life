#!/usr/bin/env bash
# Run on a computer with Flutter + Android SDK installed.
set -e
flutter create --platforms=android --project-name successful_life --org com.successfullife .
rm -rf test
python3 scripts/configure_android.py
flutter pub get
flutter build apk --debug
echo "APK: build/app/outputs/flutter-apk/app-debug.apk"
