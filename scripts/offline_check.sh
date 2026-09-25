#!/usr/bin/env bash
# Runs integration_test/offline_test.dart with the phone's Wi-Fi and mobile
# data switched off, then restores them exactly as they were.
#   bash scripts/offline_check.sh <device-id>
set -uo pipefail
cd "$(dirname "$0")/.."
D="$1"
export JAVA_HOME="$HOME/jdks/jdk-21.0.12.1+1" PATH="$HOME/jdks/jdk-21.0.12.1+1/bin:/mnt/storage/projects/flutter/bin:$PATH"

WIFI=$(adb -s "$D" shell settings get global wifi_on | tr -d '\r')
DATA=$(adb -s "$D" shell settings get global mobile_data | tr -d '\r')
echo "network before: wifi_on=$WIFI mobile_data=$DATA"
restore() {
  [ "$WIFI" != "0" ] && adb -s "$D" shell svc wifi enable
  [ "$DATA" = "1" ] && adb -s "$D" shell svc data enable
  sleep 3
  echo "network restored: wifi_on=$(adb -s "$D" shell settings get global wifi_on | tr -d '\r') mobile_data=$(adb -s "$D" shell settings get global mobile_data | tr -d '\r')"
}
trap restore EXIT

# Build and install first (needs no network on the phone), then go offline.
flutter build apk --debug --target integration_test/offline_test.dart > /dev/null
adb -s "$D" uninstall com.homilabs.safescape > /dev/null 2>&1
adb -s "$D" shell svc wifi disable
adb -s "$D" shell svc data disable
sleep 4
adb -s "$D" shell ping -c 1 -W 2 8.8.8.8 > /dev/null 2>&1 && echo "WARNING: phone still online" || echo "phone is offline"
adb -s "$D" shell input keyevent KEYCODE_WAKEUP
timeout 900 flutter test integration_test/offline_test.dart -d "$D" 2>&1 | grep -E "OFFLINE|All tests passed|Some tests failed|\[E\]|Expected|Actual|offline_test.dart:[0-9]+"
