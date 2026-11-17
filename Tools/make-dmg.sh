#!/bin/bash
# Packs a built MacKit.app into a disk image with a shortcut to Applications.
#
#   Tools/make-dmg.sh <path to MacKit.app> <output.dmg>
#
# The image is checked after it's made: it has to pass hdiutil's own
# verification, and the app inside has to keep a valid signature.
set -euo pipefail

app="${1:?path to MacKit.app}"
dmg="${2:?output .dmg path}"

[ -d "$app" ] || { echo "No app at $app" >&2; exit 1; }
codesign --verify --deep --strict "$app"

stage="$(mktemp -d)"
trap 'rm -rf "$stage"' EXIT

# ditto keeps the signature, extended attributes, and symlinks intact.
ditto "$app" "$stage/MacKit.app"
ln -s /Applications "$stage/Applications"

mkdir -p "$(dirname "$dmg")"
rm -f "$dmg"
# ULFO (lzfse) opens faster than the older zlib format and is about as small.
hdiutil create -quiet -volname "MacKit" -srcfolder "$stage" -fs APFS -format ULFO "$dmg"

hdiutil verify -quiet "$dmg"
mount="$(mktemp -d)"
hdiutil attach -quiet -nobrowse -readonly -mountpoint "$mount" "$dmg"
codesign --verify --deep --strict "$mount/MacKit.app"
version="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$mount/MacKit.app/Contents/Info.plist")"
hdiutil detach -quiet "$mount"
rmdir "$mount" 2>/dev/null || true

echo "Made $dmg (MacKit $version, $(du -h "$dmg" | cut -f1 | tr -d ' '))"
