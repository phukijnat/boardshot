#!/bin/zsh
# Makes a drag-to-install .dmg with the instructions background.
#   tools/make_dmg.sh <path/to/App.app> <out.dmg> <volume name>
# Window layout must match tools/make_dmg_background.swift.
# Uses Finder (AppleScript) to save the window layout, so macOS may ask once
# to allow controlling Finder.
set -euo pipefail
APP="$1"; DMG="$2"; VOL="$3"
APP_FILE="$(basename "$APP")"
BG="Resources/dmg-background.tiff"
[[ -f "$BG" ]] || { echo "Missing $BG (run: swift tools/make_dmg_background.swift)" >&2; exit 1; }

if [[ -d "/Volumes/$VOL" ]]; then
  echo "/Volumes/$VOL is already mounted; eject it first." >&2
  exit 1
fi

mkdir -p "$(dirname "$DMG")"
work=$(mktemp -d)
trap 'hdiutil detach -quiet "/Volumes/$VOL" 2>/dev/null || true; rm -rf "$work"' EXIT

mkdir -p "$work/stage/.background"
ditto "$APP" "$work/stage/$APP_FILE"
ln -s /Applications "$work/stage/Applications"
cp "$BG" "$work/stage/.background/background.tiff"

# Writable image first, so Finder can store the layout in .DS_Store.
hdiutil create -quiet -volname "$VOL" -srcfolder "$work/stage" -fs HFS+ -format UDRW -size 60m "$work/rw.dmg"
hdiutil attach -quiet -noautoopen "$work/rw.dmg"

osascript <<EOF
tell application "Finder"
  -- Finder can take a few seconds to notice a freshly attached disk.
  repeat 30 times
    if exists disk "$VOL" then exit repeat
    delay 0.5
  end repeat
  tell disk "$VOL"
    open
    set current view of container window to icon view
    set toolbar visible of container window to false
    set statusbar visible of container window to false
    set the bounds of container window to {200, 120, 860, 588}
    set opts to the icon view options of container window
    set arrangement of opts to not arranged
    set icon size of opts to 112
    set text size of opts to 13
    set background picture of opts to file ".background:background.tiff"
    set position of item "$APP_FILE" of container window to {165, 150}
    set position of item "Applications" of container window to {495, 150}
    update without registering applications
    delay 1
    close
  end tell
end tell
EOF

sync
rm -rf "/Volumes/$VOL/.fseventsd"
hdiutil detach -quiet "/Volumes/$VOL"
rm -f "$DMG"
hdiutil convert -quiet "$work/rw.dmg" -format UDZO -imagekey zlib-level=9 -o "$DMG"
echo "Made $DMG"
