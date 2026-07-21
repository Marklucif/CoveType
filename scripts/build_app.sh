#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="$ROOT_DIR/.build/release"
APP_DIR="$ROOT_DIR/dist/CoveType.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
ENTITLEMENTS="$ROOT_DIR/App/CoveType.entitlements"
ZIP_PATH="$ROOT_DIR/dist/CoveType.app.zip"

find_codesign_identity() {
    if [ -n "${CODE_SIGN_IDENTITY:-}" ]; then
        printf '%s\n' "$CODE_SIGN_IDENTITY"
        return 0
    fi

    local identities preferred
    identities="$(security find-identity -v -p codesigning 2>/dev/null || true)"

    preferred="$(printf '%s\n' "$identities" | sed -n 's/.*"\(Developer ID Application:.*\)"/\1/p' | head -n 1)"
    if [ -n "$preferred" ]; then
        printf '%s\n' "$preferred"
        return 0
    fi

    preferred="$(printf '%s\n' "$identities" | sed -n 's/.*"\(Apple Development:.*\)"/\1/p' | head -n 1)"
    if [ -n "$preferred" ]; then
        printf '%s\n' "$preferred"
    fi
}

mkdir -p "$ROOT_DIR/dist"

echo "==> Building CoveType (Universal Binary: arm64 + x86_64)..."
swift build -c release --arch arm64 --arch x86_64 --package-path "$ROOT_DIR"

UNIVERSAL_BINARY="$ROOT_DIR/.build/apple/Products/Release/CoveType"

rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"

cp "$UNIVERSAL_BINARY" "$MACOS_DIR/CoveType"

echo "==> Verifying Universal Binary..."
lipo -info "$MACOS_DIR/CoveType"
cp "$ROOT_DIR/App/Info.plist" "$CONTENTS_DIR/Info.plist"

if [ -f "$ROOT_DIR/App/CoveType.icns" ]; then
    cp "$ROOT_DIR/App/CoveType.icns" "$RESOURCES_DIR/CoveType.icns"
fi

if [ -f "$ROOT_DIR/Resources/covetype_local_ai_worker.py" ]; then
    cp "$ROOT_DIR/Resources/covetype_local_ai_worker.py" "$RESOURCES_DIR/covetype_local_ai_worker.py"
fi

chmod +x "$MACOS_DIR/CoveType"

# --- Code Signing ---
CODE_SIGN_NAME="$(find_codesign_identity)"
if [ -n "$CODE_SIGN_NAME" ]; then
    echo "==> Signing with: $CODE_SIGN_NAME"
    codesign --force --sign "$CODE_SIGN_NAME" \
        --entitlements "$ENTITLEMENTS" \
        --options runtime \
        --timestamp \
        "$APP_DIR"

    echo "==> Verifying signature..."
    codesign --verify --verbose=2 "$APP_DIR"
    spctl --assess --type execute --verbose=2 "$APP_DIR" 2>&1 || true

    if [ -n "${NOTARY_KEYCHAIN_PROFILE:-}" ]; then
        echo "==> Creating zip for notarization..."
        rm -f "$ZIP_PATH"
        ditto -c -k --keepParent "$APP_DIR" "$ZIP_PATH"

        echo "==> Submitting for notarization with profile: $NOTARY_KEYCHAIN_PROFILE"
        xcrun notarytool submit "$ZIP_PATH" \
            --keychain-profile "$NOTARY_KEYCHAIN_PROFILE" \
            --wait

        echo "==> Stapling notarization ticket..."
        xcrun stapler staple "$APP_DIR"
        spctl --assess --type execute --verbose=2 "$APP_DIR" 2>&1
    else
        echo "NOTARY_KEYCHAIN_PROFILE is not set; creating a signed, unnotarized preview build."
    fi
else
    echo "No Developer ID signing identity found; falling back to ad-hoc signature."
    echo "Accessibility and microphone permissions may need to be re-granted after each rebuild."
    codesign --force --sign - --timestamp=none "$APP_DIR"
fi

rm -f "$ZIP_PATH"
ditto -c -k --keepParent "$APP_DIR" "$ZIP_PATH"
echo "==> Built: $APP_DIR"
echo "==> Distribution zip: $ZIP_PATH"
