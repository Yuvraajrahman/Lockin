#!/usr/bin/env bash
# Build a Release iLockin.app (universal), then produce .zip and .dmg under dist/.
# Uses ad-hoc signing so Gatekeeper may show "unidentified developer" until
# you ship Apple-notarized builds with your own Developer ID.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ILOCKIN="$REPO_ROOT/iLockin"
DIST="$REPO_ROOT/dist"
DERIVED="$ILOCKIN/build/DerivedData"
APP="iLockin.app"
PRODUCT_DIR="$DERIVED/Build/Products/Release"

cd "$ILOCKIN"
./setup.sh

rm -rf "$DERIVED"
mkdir -p "$DIST"

xcodebuild \
  -project iLockin.xcodeproj \
  -scheme iLockin \
  -configuration Release \
  -destination "generic/platform=macOS" \
  -derivedDataPath "$DERIVED" \
  CODE_SIGN_STYLE=Manual \
  CODE_SIGN_IDENTITY=- \
  DEVELOPMENT_TEAM= \
  CODE_SIGNING_ALLOWED=YES \
  build

if [[ ! -d "$PRODUCT_DIR/$APP" ]]; then
  echo "error: expected $PRODUCT_DIR/$APP" >&2
  exit 1
fi

VERSION="$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' "$PRODUCT_DIR/$APP/Contents/Info.plist")"
BUILD="$(/usr/libexec/PlistBuddy -c 'Print CFBundleVersion' "$PRODUCT_DIR/$APP/Contents/Info.plist")"
STEM="iLockin-${VERSION}"

ZIP_OUT="$DIST/${STEM}-macos-universal.zip"
DMG_OUT="$DIST/${STEM}-macos-universal.dmg"
rm -f "$ZIP_OUT" "$DMG_OUT"

ditto -c -k --sequesterRsrc --keepParent "$PRODUCT_DIR/$APP" "$ZIP_OUT"

# Single-window DMG: drag iLockin.app to Applications (optional symlink could be added later)
hdiutil create -volname "iLockin ${VERSION}" -srcfolder "$PRODUCT_DIR/$APP" -ov -format UDZO "$DMG_OUT" >/dev/null

echo ""
echo "Built:"
echo "  $ZIP_OUT"
echo "  $DMG_OUT"
echo "  Version ${VERSION} (${BUILD})"
