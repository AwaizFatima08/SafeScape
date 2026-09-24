#!/usr/bin/env bash
# Capture Play Store screenshots from the emulator.
#   bash scripts/take_screenshots.sh <device-id> <out-dir> [wm-size] [wm-density]
# e.g. phone:      bash scripts/take_screenshots.sh emulator-5554 store-assets/screenshots/phone
#      7" tablet:  ... store-assets/screenshots/tablet-7in 1200x1920 240
#      10" tablet: ... store-assets/screenshots/tablet-10in 1600x2560 320
# Runs integration_test/store_shots_test.dart (which WIPES the app's data) and
# grabs the screen each time the test prints SHOT:<name>.
set -uo pipefail
cd "$(dirname "$0")/.."
DEV="$1"; OUT="$2"; SIZE="${3:-}"; DENSITY="${4:-}"
mkdir -p "$OUT"
if [ -n "$SIZE" ]; then adb -s "$DEV" shell wm size "$SIZE"; adb -s "$DEV" shell wm density "$DENSITY"; fi
export JAVA_HOME="$HOME/jdks/jdk-21.0.12.1+1" PATH="$HOME/jdks/jdk-21.0.12.1+1/bin:/mnt/storage/projects/flutter/bin:$PATH"
flutter test integration_test/store_shots_test.dart -d "$DEV" 2>&1 | while IFS= read -r line; do
  echo "$line"
  case "$line" in
    *SHOT:*) name="${line##*SHOT:}"; name="${name%%[[:space:]]*}"
             adb -s "$DEV" exec-out screencap -p > "$OUT/$name.png" && echo ">> captured $OUT/$name.png" ;;
  esac
done
if [ -n "$SIZE" ]; then adb -s "$DEV" shell wm size reset; adb -s "$DEV" shell wm density reset; fi
