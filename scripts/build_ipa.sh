#!/bin/bash
# Build Pitch Tracker .ipa for AltStore sideloading.
# Requires full Xcode (not Command Line Tools only).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT"

if ! xcodebuild -version >/dev/null 2>&1; then
  echo "ERROR: Install Xcode from the App Store and run: sudo xcode-select -s /Applications/Xcode.app/Contents/Developer"
  exit 1
fi

SCHEME="PitchTracker"
ARCHIVE="$ROOT/build/PitchTracker.xcarchive"
IPA_DIR="$ROOT/build/ipa"
TEAM="${DEVELOPMENT_TEAM:-}"

echo "==> Generating Xcode project"
if [ ! -d PitchTracker.xcodeproj ]; then
  if [ -x /tmp/xcodegen/xcodegen/bin/xcodegen ]; then
    /tmp/xcodegen/xcodegen/bin/xcodegen generate
  else
    echo "Run: curl -L https://github.com/yonaskolb/XcodeGen/releases/download/2.44.1/xcodegen.zip -o /tmp/xcodegen.zip && unzip -o /tmp/xcodegen.zip -d /tmp/xcodegen"
    echo "Then: /tmp/xcodegen/xcodegen/bin/xcodegen generate"
    exit 1
  fi
fi

mkdir -p build

XCB=(xcodebuild -project PitchTracker.xcodeproj -scheme "$SCHEME" -configuration Release)
if [ -n "$TEAM" ]; then
  XCB+=(-allowProvisioningUpdates DEVELOPMENT_TEAM="$TEAM")
fi

echo "==> Archive"
"${XCB[@]}" -archivePath "$ARCHIVE" archive

echo "==> Export IPA"
rm -rf "$IPA_DIR"
"${XCB[@]}" -exportArchive -archivePath "$ARCHIVE" -exportPath "$IPA_DIR" -exportOptionsPlist ExportOptions.plist

echo ""
echo "Done. IPA:"
find "$IPA_DIR" -name "*.ipa" -print
