#!/bin/zsh
# Makes a release: sets the version, builds the .dmg, signs it for Sparkle,
# and adds it to appcast.xml. Nothing is uploaded; the script prints what to do next.
#
#   ./release.sh 0.2.0           real release (edits config.sh and appcast.xml)
#   ./release.sh 0.2.0 --local   test build for http://localhost:8000 (writes only to build/local-feed)
#
# Release notes: the "## <version>" section of CHANGELOG.md, if there is one.
set -euo pipefail
cd "$(dirname "$0")"

NEW="${1:-}"
MODE="${2:-}"
if [[ ! "$NEW" =~ '^[0-9]+\.[0-9]+\.[0-9]+$' ]]; then
  echo "usage: ./release.sh <major.minor.patch> [--local]" >&2
  exit 1
fi
source ./config.sh

if [[ "$MODE" == "--local" ]]; then
  FEED_DIR=build/local-feed
  BASE_URL="http://localhost:8000"
  mkdir -p "$FEED_DIR"
  export FEED_URL="$BASE_URL/appcast.xml" BUILD_VERSION="$NEW"
  ./build.sh --dmg
  APPCAST="$FEED_DIR/appcast.xml"
  DOWNLOAD_URL="$BASE_URL/${APP_NAME}-${NEW}.dmg"
else
  if [[ -n "$(git status --porcelain 2>/dev/null)" ]]; then
    echo "Commit or stash your changes first, so the release matches a commit." >&2
    exit 1
  fi
  sed -i '' "s/^VERSION=\".*\"/VERSION=\"${NEW}\"/" config.sh
  ./build.sh --dmg
  APPCAST=appcast.xml
  DOWNLOAD_URL="https://github.com/${GITHUB_REPO}/releases/download/v${NEW}/${APP_NAME}-${NEW}.dmg"
fi

DMG="dist/${APP_NAME}-${NEW}.dmg"
BUILD_NUM=$(/usr/libexec/PlistBuddy -c "Print :CFBundleVersion" "build/${APP_NAME}.app/Contents/Info.plist")
SIG=$(vendor/Sparkle/bin/sign_update --account boardshot -p "$DMG" | tr -d '[:space:]')
LEN=$(stat -f %z "$DMG")
# Check the signature with the public key before it goes into the appcast.
if ! swift tools/verify_sig.swift "$SPARKLE_PUBLIC_KEY" "$SIG" "$DMG" >/dev/null; then
  echo "Signature check failed for $DMG; appcast not changed." >&2
  exit 1
fi

# Release notes from CHANGELOG.md -> simple HTML list
NOTES=$(mktemp)
if [[ -f CHANGELOG.md ]]; then
  awk -v v="$NEW" '
    $0 ~ "^## \\[?" v "\\]?" { on=1; next }
    on && /^## / { exit }
    on && /^[-*] / { sub(/^[-*] /, ""); print "<li>" $0 "</li>" }
  ' CHANGELOG.md | { echo "<ul>"; cat; echo "</ul>"; } > "$NOTES"
fi

python3 -I tools/appcast.py "$APPCAST" "$NEW" "$BUILD_NUM" "$DOWNLOAD_URL" "$LEN" "$SIG" "$NOTES" "$APP_NAME"
rm -f "$NOTES"

if [[ "$MODE" == "--local" ]]; then
  cp "$DMG" "$FEED_DIR/"
  echo "\nLocal feed ready. Serve it with:\n  python3 -m http.server 8000 --directory $FEED_DIR"
else
  echo "\nNext steps:"
  echo "  git commit -am \"Release ${NEW}\" && git tag v${NEW} && git push && git push --tags"
  echo "  Create a GitHub release v${NEW} and attach ${DMG}"
  echo "  (appcast.xml on main points to that file, so push both)"
fi
