#!/usr/bin/env bash
# Installs the release APK on the connected phone or emulator, starts it and fails if it logs a
# crash. Release builds shrink code (R8), which can break plugins in ways tests never see.
# Usage: tool/smoke_release.sh [apk]   (default: the newest APK in dist/)
set -euo pipefail
cd "$(dirname "$0")/.."
apk="${1:-$(ls -t dist/v*/*.apk | head -1)}"
pkg=com.tanimaziz.bluecoins
adb get-state >/dev/null 2>&1 || { echo "No phone or emulator connected (adb devices)." >&2; exit 1; }
adb install -r "$apk" >/dev/null
adb shell pm clear "$pkg" >/dev/null
adb logcat -c
adb shell monkey -p "$pkg" -c android.intent.category.LAUNCHER 1 >/dev/null 2>&1
sleep 25
pid="$(adb shell pidof "$pkg" | tr -d '\r')"
[ -n "$pid" ] || { echo "FAIL: the app is not running (it crashed or was killed)" >&2; adb logcat -d | grep -E "FATAL|AndroidRuntime" | head -5; exit 1; }
if adb logcat -d --pid="$pid" | grep -E "Unhandled Exception|NoSuchMethodError|FATAL EXCEPTION|UnsatisfiedLinkError"; then
  echo "FAIL: the app logged an error at startup" >&2; exit 1
fi
echo "ok   $apk starts without errors"
