#!/usr/bin/env bash
# Builds the release APK for the version in pubspec.yaml into dist/vX.Y.Z/ with its SHA-256 sum.
# Needs the signing key (~/.bluecoins-release/key.properties, or the file named by BLUECOINS_SIGNING)
# and, for cloud sign-in, config/env.json (copy config/env.example.json and fill it in).
set -euo pipefail
cd "$(dirname "$0")/.."

VERSION_LINE=$(grep -E '^version:' pubspec.yaml | head -1)
VERSION=$(echo "$VERSION_LINE" | sed -E 's/^version:[[:space:]]*([0-9]+\.[0-9]+\.[0-9]+)\+([0-9]+).*/\1/')
[[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || { echo "pubspec.yaml version must look like 1.2.3+4, found: $VERSION_LINE" >&2; exit 1; }

SIGNING=${BLUECOINS_SIGNING:-$HOME/.bluecoins-release/key.properties}
[ -f "$SIGNING" ] || { echo "No signing key at $SIGNING; refusing to build a debug-signed release." >&2; exit 1; }

ENV_ARGS=()
if [ -f config/env.json ]; then ENV_ARGS=(--dart-define-from-file=config/env.json); else echo "note: no config/env.json, cloud sign-in will be off in this build"; fi

dart run build_runner build -d
flutter build apk --release --target-platform android-arm64 --obfuscate --split-debug-info="build/symbols/v$VERSION" "${ENV_ARGS[@]}"

OUT="dist/v$VERSION"
rm -rf "$OUT"; mkdir -p "$OUT"
cp build/app/outputs/flutter-apk/app-release.apk "$OUT/bluecoins-v$VERSION-arm64-v8a.apk"
STRICT=1 tool/security_audit.sh "$OUT/bluecoins-v$VERSION-arm64-v8a.apk"
(cd "$OUT" && sha256sum ./*.apk | sed 's# \./# #' > "bluecoins-v$VERSION-sha256sums.txt")
echo; echo "Built v$VERSION in $OUT (keep build/symbols/v$VERSION to read crash traces):"; ls -lh "$OUT"
