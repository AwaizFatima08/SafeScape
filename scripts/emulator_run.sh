#!/usr/bin/env bash
# One CPU-lane job (run it through jobq): boot SafeScape's own emulator, run the
# on-device tests and capture store screenshots, then shut everything down.
#   jobq run --name safescape-emulator -- bash scripts/emulator_run.sh [out-dir]
# Follows ~/.claude/heavy-jobs.md: own AVD and port, 3 GB / 3 cores (CLAUDE.md),
# swangle_indirect (no GPU X server yet), cleanup straight after.
set -uo pipefail
cd "$(dirname "$0")/.."
OUT="${1:-build/emulator-run}"
mkdir -p "$OUT"
export ANDROID_AVD_HOME=/mnt/storage/projects/android-avd
export JAVA_HOME="$HOME/jdks/jdk-21.0.12.1+1"
export PATH="$JAVA_HOME/bin:/mnt/storage/projects/flutter/bin:$HOME/Android/Sdk/platform-tools:$PATH"
PORT=5570
DEV="emulator-$PORT"

avail=$(free -g | awk '/Mem:/{print $7}')
if [ "$avail" -lt 6 ]; then
  echo "NOT STARTED: only ${avail} GiB RAM available (need 6)."
  ps -eo pid,rss,comm --sort=-rss | head -6
  exit 2
fi

"$HOME/Android/Sdk/emulator/emulator" -avd safescape_api35 -port "$PORT" -no-window -memory 3072 -cores 3 \
  -no-snapshot-save -no-audio -no-boot-anim -gpu swangle_indirect > "$OUT/emulator.log" 2>&1 &
EMU=$!
cleanup() {
  adb -s "$DEV" emu kill > /dev/null 2>&1
  wait "$EMU" 2> /dev/null
  (cd android && ./gradlew --stop > /dev/null 2>&1)
  echo "emulator stopped, Gradle daemon stopped"
}
trap cleanup EXIT

adb -s "$DEV" wait-for-device
for _ in $(seq 1 120); do
  [ "$(adb -s "$DEV" shell getprop sys.boot_completed 2> /dev/null | tr -d '\r')" = "1" ] && break
  sleep 5
done
sleep 20
echo "graphics: $(adb -s "$DEV" shell dumpsys SurfaceFlinger | grep -m1 GLES)"

result=0
# SHOTS_ONLY=1 skips the flow tests and only captures the screenshots.
[ "${SHOTS_ONLY:-0}" = "1" ] && TESTS="" || TESTS="app_flow_test learning_flow_test"
for t in $TESTS; do
  echo "=== $t $(date +%T)"
  timeout 30m flutter test "integration_test/$t.dart" -d "$DEV" > "$OUT/$t.log" 2>&1
  grep -E "All tests passed|Some tests failed|CLEANED" "$OUT/$t.log" | tail -2
  grep -q "All tests passed" "$OUT/$t.log" || result=1
done

echo "=== screenshots $(date +%T)"
adb -s "$DEV" shell cmd statusbar collapse > /dev/null 2>&1
bash scripts/take_screenshots.sh "$DEV" "$OUT/screenshots" > "$OUT/screenshots.log" 2>&1
echo "captured: $(grep -c '>> captured' "$OUT/screenshots.log")"
grep -q "All tests passed" "$OUT/screenshots.log" || result=1
exit $result
