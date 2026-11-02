#!/usr/bin/env bash
# One-time setup for macOS or Linux. Run from the app folder: bash tool/setup_dev.sh
set -euo pipefail

if ! command -v flutter >/dev/null 2>&1; then
  echo "Flutter was not found. Install Flutter 3.47.8 and add its bin folder to PATH first (see README)." >&2
  exit 1
fi

if [ -d android ]; then
  echo "The android folder already exists, skipping the create step."
else
  flutter create --org app.aaspaas --project-name aaspaas_app --platforms=android --no-pub _shell
  mv _shell/android android
  rm -rf _shell
fi

dart tool/prepare_android.dart
flutter pub get
echo
echo "Done. Pick a device at the bottom right of VS Code, then press F5."
