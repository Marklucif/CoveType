#!/bin/zsh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SOURCE_APP="$PROJECT_ROOT/dist/CoveType.app"

[[ "$(uname -s)" == "Darwin" ]] || {
    printf 'This packaging script must run on macOS.\n' >&2
    exit 1
}
[[ -d "$SOURCE_APP" ]] || {
    printf 'Build dist/CoveType.app before creating the installer.\n' >&2
    exit 1
}

codesign --verify --deep --strict "$SOURCE_APP"
EXPECTED_TEAM_ID="595SXP7Y3V"
ACTUAL_TEAM_ID="$(codesign -dv --verbose=4 "$SOURCE_APP" 2>&1 | sed -n 's/^TeamIdentifier=//p')"
if [[ "$ACTUAL_TEAM_ID" != "$EXPECTED_TEAM_ID" && "${ALLOW_UNNOTARIZED_PREVIEW:-0}" != "1" ]]; then
    printf 'Refusing to package an app not signed by the CoveType release team.\n' >&2
    exit 1
fi
if ! xcrun stapler validate "$SOURCE_APP" >/dev/null 2>&1 \
    && [[ "${ALLOW_UNNOTARIZED_PREVIEW:-0}" != "1" ]]; then
    printf 'Refusing to publish an app without a stapled Apple notarization ticket.\n' >&2
    printf 'Set ALLOW_UNNOTARIZED_PREVIEW=1 only for a private test archive.\n' >&2
    exit 1
fi
VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$SOURCE_APP/Contents/Info.plist")"
PACKAGE_NAME="CoveType-$VERSION-macOS-AppleSilicon-Installer"
OUTPUT="$PROJECT_ROOT/dist/$PACKAGE_NAME.zip"
TEMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/covetype-package.XXXXXX")"

cleanup() {
    if [[ -n "${TEMP_DIR:-}" && "$TEMP_DIR" == *covetype-package.* && -d "$TEMP_DIR" ]]; then
        find "$TEMP_DIR" -depth -delete
    fi
}
trap cleanup EXIT INT TERM

PACKAGE_DIR="$TEMP_DIR/$PACKAGE_NAME"
mkdir -p "$PACKAGE_DIR"
ditto "$SOURCE_APP" "$PACKAGE_DIR/CoveType.app"
cp "$SCRIPT_DIR/install_macos.command" "$PACKAGE_DIR/Install CoveType.command"
cp "$SCRIPT_DIR/requirements-macos.txt" "$PACKAGE_DIR/requirements-macos.txt"
cp "$PROJECT_ROOT/docs/MACOS_AUTOMATED_INSTALL.md" "$PACKAGE_DIR/安装说明.md"
chmod +x "$PACKAGE_DIR/Install CoveType.command"

if [[ -e "$OUTPUT" ]]; then
    printf 'Refusing to overwrite the existing release archive: %s\n' "$OUTPUT" >&2
    exit 1
fi

ditto -c -k --sequesterRsrc --keepParent "$PACKAGE_DIR" "$OUTPUT"
printf 'Created %s\n' "$OUTPUT"
shasum -a 256 "$OUTPUT"
