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
    PREVIOUS_OUTPUT="$PROJECT_ROOT/dist/$PACKAGE_NAME.previous.zip"
    [[ ! -e "$PREVIOUS_OUTPUT" ]] || {
        printf 'Refusing to overwrite existing archives: %s and %s\n' "$OUTPUT" "$PREVIOUS_OUTPUT" >&2
        exit 1
    }
    mv "$OUTPUT" "$PREVIOUS_OUTPUT"
fi

ditto -c -k --sequesterRsrc --keepParent "$PACKAGE_DIR" "$OUTPUT"
printf 'Created %s\n' "$OUTPUT"
shasum -a 256 "$OUTPUT"
