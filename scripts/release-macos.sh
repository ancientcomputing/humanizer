#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
MACOS_APP_DIR="$REPO_ROOT/macos-app"

APP_NAME="Humanizer"
VERSION="${VERSION:-VERSION_NEEDED}"
APP_IDENTITY="${APP_IDENTITY:-${SIGN_IDENTITY:-}}"
KEYCHAIN_PROFILE="${KEYCHAIN_PROFILE:-${NOTARY_PROFILE:-}}"
DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
TEAM_ID="${TEAM_ID:-}"
NOTARIZE_APP="${NOTARIZE_APP:-1}"
NOTARIZE_DMG="${NOTARIZE_DMG:-1}"
ICON_PYTHON="${ICON_PYTHON:-${PYTHON:-python3}}"

DIST_DIR="$REPO_ROOT/dist"
BUILD_DIR="$REPO_ROOT/build/macos-release"
APP_DIR="$DIST_DIR/${APP_NAME}.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
DMG_STAGE_DIR="$BUILD_DIR/dmg-stage"
APP_ZIP="$BUILD_DIR/${APP_NAME}-${VERSION}.zip"
DMG_PATH="$DIST_DIR/${APP_NAME}-${VERSION}-arm64.dmg"
ICON_BUILD_DIR="$BUILD_DIR/icon"
APPICONSET_PATH="$MACOS_APP_DIR/Resources/Assets.xcassets/AppIcon.appiconset"

export DEVELOPER_DIR

require_env() {
  local name="$1"
  local value="$2"
  if [[ -z "$value" ]]; then
    echo "$name is required" >&2
    exit 1
  fi
}

require_command() {
  local command_name="$1"
  if ! command -v "$command_name" >/dev/null 2>&1; then
    echo "$command_name is required" >&2
    exit 1
  fi
}

generate_app_icon() {
  echo "Generating macOS app icon..."
  if ! "$ICON_PYTHON" "$MACOS_APP_DIR/Resources/generate_app_icon.py" "$APPICONSET_PATH"; then
    echo "Failed to generate app icon images with ICON_PYTHON=$ICON_PYTHON" >&2
    echo "Install Pillow for that Python, or set ICON_PYTHON to a Python that can import PIL." >&2
    exit 1
  fi
  mkdir -p "$ICON_BUILD_DIR"
  xcrun actool --output-format human-readable-text --notices --warnings --errors \
    --app-icon AppIcon \
    --output-partial-info-plist "$ICON_BUILD_DIR/partial.plist" \
    --platform macosx --minimum-deployment-target 13.0 \
    --compile "$ICON_BUILD_DIR" \
    "$MACOS_APP_DIR/Resources/Assets.xcassets"
}

notarize_and_wait() {
  local artifact="$1"
  echo "Submitting for notarization: $artifact"
  if ! xcrun notarytool history --keychain-profile "$KEYCHAIN_PROFILE" >/dev/null 2>&1; then
    echo "KEYCHAIN_PROFILE became unavailable before notarizing: $artifact" >&2
    echo "Try unlocking the login keychain or recreating the profile with xcrun notarytool store-credentials." >&2
    exit 1
  fi
  if [[ -n "$TEAM_ID" ]]; then
    xcrun notarytool submit "$artifact" \
      --keychain-profile "$KEYCHAIN_PROFILE" \
      --team-id "$TEAM_ID" \
      --wait
  else
    xcrun notarytool submit "$artifact" \
      --keychain-profile "$KEYCHAIN_PROFILE" \
      --wait
  fi
}

require_env APP_IDENTITY "$APP_IDENTITY"
if [[ "$NOTARIZE_APP" == "1" || "$NOTARIZE_DMG" == "1" ]]; then
  require_env KEYCHAIN_PROFILE "$KEYCHAIN_PROFILE"
fi

require_command swift
require_command codesign
require_command ditto
require_command hdiutil
require_command shasum
require_command spctl
require_command xcrun

if ! security find-identity -v -p codesigning | grep -F "$APP_IDENTITY" >/dev/null 2>&1; then
  echo "APP_IDENTITY is not installed or is not valid for codesigning: $APP_IDENTITY" >&2
  security find-identity -v -p codesigning || true
  exit 1
fi

if [[ "$NOTARIZE_APP" == "1" || "$NOTARIZE_DMG" == "1" ]] && ! xcrun notarytool history --keychain-profile "$KEYCHAIN_PROFILE" >/dev/null 2>&1; then
  echo "KEYCHAIN_PROFILE is not usable: $KEYCHAIN_PROFILE" >&2
  echo "Create it with: xcrun notarytool store-credentials $KEYCHAIN_PROFILE" >&2
  exit 1
fi

echo "Cleaning release artifacts..."
rm -rf "$BUILD_DIR" "$APP_DIR" "$DMG_PATH" "$DMG_PATH.sha256"
mkdir -p "$BUILD_DIR" "$DIST_DIR"
generate_app_icon

echo "Building arm64 Swift app..."
swift build \
  --package-path "$MACOS_APP_DIR" \
  -c release \
  --arch arm64 \
  --build-path "$BUILD_DIR/swift"

SWIFT_BINARY="$BUILD_DIR/swift/arm64-apple-macosx/release/HumanizerApp"
lipo -info "$SWIFT_BINARY"

echo "Creating app bundle..."
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"
cp "$MACOS_APP_DIR/Resources/Info.plist" "$CONTENTS_DIR/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $VERSION" "$CONTENTS_DIR/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $VERSION" "$CONTENTS_DIR/Info.plist"
cp "$ICON_BUILD_DIR/AppIcon.icns" "$RESOURCES_DIR/AppIcon.icns" 2>/dev/null || true
cp "$ICON_BUILD_DIR/Assets.car" "$RESOURCES_DIR/Assets.car"
cp "$SWIFT_BINARY" "$MACOS_DIR/$APP_NAME"
printf 'APPL????' > "$CONTENTS_DIR/PkgInfo"
chmod +x "$MACOS_DIR/$APP_NAME"

echo "Verifying arm64 app binary..."
lipo -info "$MACOS_DIR/$APP_NAME"

echo "Signing app bundle..."
codesign --force --options runtime --timestamp --entitlements "$MACOS_APP_DIR/Resources/Humanizer.entitlements" --sign "$APP_IDENTITY" "$MACOS_DIR/$APP_NAME"
codesign --force --deep --options runtime --timestamp --entitlements "$MACOS_APP_DIR/Resources/Humanizer.entitlements" --sign "$APP_IDENTITY" "$APP_DIR"

codesign --verify --deep --strict --verbose=2 "$APP_DIR"

echo "Creating app notarization zip..."
ditto -c -k --keepParent "$APP_DIR" "$APP_ZIP"

if [[ "$NOTARIZE_APP" == "1" ]]; then
  notarize_and_wait "$APP_ZIP"

  echo "Stapling app..."
  xcrun stapler staple "$APP_DIR"
  xcrun stapler validate "$APP_DIR"
  spctl -a -vv --type execute "$APP_DIR"
else
  echo "Skipping app notarization because NOTARIZE_APP=$NOTARIZE_APP"
fi

echo "Creating drag-to-Applications DMG..."
rm -rf "$DMG_STAGE_DIR"
mkdir -p "$DMG_STAGE_DIR"
cp -R "$APP_DIR" "$DMG_STAGE_DIR/${APP_NAME}.app"
ln -s /Applications "$DMG_STAGE_DIR/Applications"

hdiutil create \
  -volname "$APP_NAME" \
  -srcfolder "$DMG_STAGE_DIR" \
  -ov \
  -format UDZO \
  "$DMG_PATH"

echo "Signing DMG..."
codesign --force --timestamp --sign "$APP_IDENTITY" "$DMG_PATH"
codesign --verify --verbose=2 "$DMG_PATH"

if [[ "$NOTARIZE_DMG" == "1" ]]; then
  notarize_and_wait "$DMG_PATH"

  echo "Stapling DMG..."
  xcrun stapler staple "$DMG_PATH"
  xcrun stapler validate "$DMG_PATH"

  echo "Running Gatekeeper verification..."
  spctl --assess --type open --context context:primary-signature --verbose "$DMG_PATH"
else
  echo "Skipping DMG notarization because NOTARIZE_DMG=$NOTARIZE_DMG"
fi

shasum -a 256 "$DMG_PATH" > "$DMG_PATH.sha256"

echo "Release artifacts:"
echo "$APP_DIR"
echo "$DMG_PATH"
echo "$DMG_PATH.sha256"
