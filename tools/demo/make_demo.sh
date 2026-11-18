#!/bin/zsh
# Rebuilds docs/demo.gif. The panel in the clip is drawn by the app's own
# Panel.swift / ShotStore.swift; everything around it comes from main.swift.
#   ./tools/demo/make_demo.sh
set -euo pipefail
cd "$(dirname "$0")/../.."
WORK=build/demo
mkdir -p "$WORK"
swiftc -O -swift-version 5 \
  Sources/Panel.swift Sources/Prefs.swift Sources/ShotStore.swift Sources/AppInfo.swift Sources/MenuBarIcon.swift \
  tools/demo/main.swift \
  -framework AppKit -framework Carbon -framework QuickLookThumbnailing \
  -module-cache-path build/obj/cache -o "$WORK/boarddemo"
"$WORK/boarddemo" docs/demo.gif "$WORK"
echo "Wrote docs/demo.gif (stills in $WORK)"
