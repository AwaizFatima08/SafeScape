#!/usr/bin/env bash
# One CPU-lane job (run it through jobq): build the signed release, then test
# on a real phone and leave the release installed.
#   jobq run --name safescape-release -- bash scripts/release_and_device.sh <adb-serial> [--replace-installed]
# SKIP_BUILD=1 reuses the release in releases/ if no app source changed since it was built.
# --replace-installed uninstalls an existing (e.g. Play-signed) SafeScape first:
# that ERASES its on-phone data, so only pass it with the owner's OK.
set -uo pipefail
cd "$(dirname "$0")/.."
DEV="$1"; REPLACE="${2:-}"
export JAVA_HOME="$HOME/jdks/jdk-21.0.12.1+1"
export PATH="$JAVA_HOME/bin:/mnt/storage/projects/flutter/bin:$HOME/Android/Sdk/platform-tools:$PATH"
VER="$(grep -m1 '^version:' pubspec.yaml | awk '{print $2}' | tr '+' '-')"
REL="releases/v$VER"
OUT="build/device-run"
mkdir -p "$OUT" "$REL"
PKG=com.homilabs.safescape
ADB="$(command -v adb)"
# Wireless adb can drop mid-job: no adb call may hang the CPU lane for long.
adb() { local t=120; case "$*" in *" install "*) t=600 ;; *" monkey "*) t=1200 ;; esac; timeout "$t" "$ADB" "$@"; }

avail=$(free -g | awk '/Mem:/{print $7}')
if [ "$avail" -lt 4 ]; then echo "NOT STARTED: only ${avail} GiB RAM available (need 4)."; exit 2; fi

BUILT="$(awk '/^commit:/{print $2}' "$REL/BUILD_INFO" 2>/dev/null)"
if [ "${SKIP_BUILD:-0}" = "1" ] && [ -f "$REL/safescape-$VER.apk" ] && [ -n "$BUILT" ] &&
   git diff --quiet "$BUILT" HEAD -- lib assets android pubspec.yaml pubspec.lock && git diff --quiet -- lib assets android pubspec.yaml; then
  echo "=== reusing the release built from this commit"; cat "$REL/BUILD_INFO"
else
echo "=== release build $VER $(date +%T)"
flutter build appbundle --release > "$OUT/build.log" 2>&1 && flutter build apk --release >> "$OUT/build.log" 2>&1 || {
  echo "BUILD FAILED"; tail -20 "$OUT/build.log"; (cd android && ./gradlew --stop > /dev/null 2>&1); exit 1; }
cp build/app/outputs/bundle/release/app-release.aab "$REL/safescape-$VER.aab"
cp build/app/outputs/flutter-apk/app-release.apk "$REL/safescape-$VER.apk"
(cd "$REL" && sha256sum ./*.aab ./*.apk > SHA256SUMS)
{ echo "version: $VER"; echo "commit: $(git rev-parse --short HEAD)"; echo "built: $(date -Is)";
  "$HOME/Android/Sdk/build-tools/36.0.0/apksigner" verify --print-certs "$REL/safescape-$VER.apk" | grep -m1 SHA-1; } > "$REL/BUILD_INFO"
cat "$REL/BUILD_INFO"
fi

if ! adb -s "$DEV" get-state > /dev/null 2>&1; then
  echo "PHONE $DEV NOT CONNECTED: release built, device tests skipped."
  (cd android && ./gradlew --stop > /dev/null 2>&1); exit 3
fi
adb -s "$DEV" shell svc power stayon true > /dev/null 2>&1
adb -s "$DEV" shell input keyevent KEYCODE_WAKEUP; adb -s "$DEV" shell wm dismiss-keyguard
if adb -s "$DEV" shell pm list packages | grep -q "$PKG"; then
  if [ "$REPLACE" = "--replace-installed" ]; then
    echo "uninstalling the installed SafeScape ($(adb -s "$DEV" shell dumpsys package $PKG | grep -m1 versionName | tr -d ' '))"
    adb -s "$DEV" uninstall "$PKG"
  else
    echo "SafeScape is already installed on $DEV; pass --replace-installed (erases its data) to test here."; exit 4
  fi
fi

result=0
for t in app_flow_test learning_flow_test; do
  echo "=== $t $(date +%T)"
  adb -s "$DEV" shell input keyevent KEYCODE_WAKEUP
  timeout 30m flutter test "integration_test/$t.dart" -d "$DEV" > "$OUT/$t.log" 2>&1
  grep -E "All tests passed|Some tests failed|CLEANED" "$OUT/$t.log" | tail -2
  grep -q "All tests passed" "$OUT/$t.log" || result=1
done

echo "=== release on the phone $(date +%T)"
adb -s "$DEV" uninstall "$PKG" > /dev/null 2>&1
adb -s "$DEV" install "$REL/safescape-$VER.apk" | tail -1
adb -s "$DEV" logcat -c
adb -s "$DEV" shell monkey -p "$PKG" --pct-syskeys 0 --ignore-timeouts --throttle 120 -s 12 -v 3000 2>&1 | grep -E "Events injected|CRASH|aborted"
adb -s "$DEV" logcat -d | grep -E "FATAL EXCEPTION|ANR in $PKG|E/flutter" | head -5
echo "alive: $(adb -s "$DEV" shell pidof $PKG)"
adb -s "$DEV" shell am force-stop "$PKG"
for _ in 1 2 3; do adb -s "$DEV" shell am start -W -n "$PKG/.MainActivity" 2>&1 | grep TotalTime; sleep 3; adb -s "$DEV" shell am force-stop "$PKG"; sleep 2; done
adb -s "$DEV" shell svc power stayon false > /dev/null 2>&1
(cd android && ./gradlew --stop > /dev/null 2>&1)
echo "release $VER left installed on $DEV; Gradle daemon stopped"
exit $result
