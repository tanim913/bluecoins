#!/usr/bin/env bash
# Audits a release APK before it ships. Fails on the first problem.
# Usage: tool/security_audit.sh build/app/outputs/flutter-apk/app-release.apk
# Checks: not debuggable, no cleartext traffic, cloud backup limited to the database, expected
# permissions only, no private keys or cloud secrets inside, Dart code obfuscated, one ABI, signed.
set -euo pipefail
apk="${1:?path to a release APK}"
sdk="${ANDROID_HOME:?ANDROID_HOME must be set}"
tools="$(ls -d "$sdk"/build-tools/* | sort -V | tail -1)"
aapt2="$tools/aapt2"
apksigner="$tools/apksigner"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
fail() { echo "FAIL: $*" >&2; exit 1; }
pass() { echo "ok   $*"; }

manifest="$("$aapt2" dump xmltree --file AndroidManifest.xml "$apk")"
grep -q 'android:debuggable.*=true' <<<"$manifest" && fail "debuggable"
pass "not debuggable"
grep -q 'android:usesCleartextTraffic.*=false' <<<"$manifest" || fail "cleartext traffic not disabled"
pass "cleartext traffic disabled"

# Auto Backup is on, but only for the database folder (see res/xml/backup_rules.xml): the sign-in
# session lives in preferences and must never reach a cloud backup.
grep -q 'android:fullBackupContent' <<<"$manifest" || fail "no backup rules"
grep -q 'android:dataExtractionRules' <<<"$manifest" || fail "no data extraction rules"
for f in android/app/src/main/res/xml/backup_rules.xml android/app/src/main/res/xml/data_extraction_rules.xml; do
  grep -q 'sharedpref' "$f" && fail "$f backs up preferences"
  grep -q 'domain="root" path="app_flutter"' "$f" || fail "$f does not scope backup to the database folder"
done
pass "backup limited to the database folder"

echo "     exported components:"
grep -B8 'android:exported.*=true' <<<"$manifest" | grep -o 'android:name(0x[0-9a-f]*)="[^"]*"' | sed 's/^/       /' || true

permissions="$("$aapt2" dump permissions "$apk" | grep -o "name='[^']*'" | sort -u)"
echo "     permissions:"; sed 's/^/       /' <<<"$permissions"
for unexpected in READ_CONTACTS ACCESS_FINE_LOCATION ACCESS_COARSE_LOCATION CAMERA RECORD_AUDIO \
  READ_EXTERNAL_STORAGE WRITE_EXTERNAL_STORAGE READ_PHONE_STATE READ_SMS RECEIVE_SMS; do
  grep -q "$unexpected" <<<"$permissions" && fail "unexpected permission $unexpected"
done
grep -q 'android.permission.INTERNET' <<<"$permissions" || fail "INTERNET missing: cloud sync would fail in release"
pass "only expected permissions"

python3 -m zipfile -e "$apk" "$work"
if grep -rlaE 'BEGIN (RSA |EC |OPENSSH |)PRIVATE KEY|storePassword|keyPassword|service_role|sb_secret_' "$work" >/dev/null; then
  fail "private key, signing secret or Supabase secret key inside the APK"
fi
pass "no private keys or cloud secrets"

libapp="$(find "$work/lib" -name libapp.so | head -1)"
[ -n "$libapp" ] || fail "libapp.so missing"
for symbol in SyncEngine SupabaseRemote BackupPreview; do
  grep -qa "$symbol" "$libapp" && fail "Dart symbols not obfuscated ($symbol)"
done
pass "Dart code obfuscated"

abis="$(ls "$work/lib")"
for abi in $abis; do case "$abi" in arm64-v8a|x86_64) ;; *) fail "unexpected ABI $abi" ;; esac; done
pass "ABIs: $(tr '\n' ' ' <<<"$abis")"

signer="$("$apksigner" verify --print-certs "$apk" | grep -m1 'Signer #1 certificate DN')" || fail "not signed"
if grep -q 'CN=Android Debug' <<<"$signer"; then
  [ "${STRICT:-0}" = 1 ] && fail "signed with the debug key"
  echo "WARN signed with the Android debug key: fine for testing, never publish it"
else
  pass "signed: $signer"
fi
echo "All checks passed for $apk"
