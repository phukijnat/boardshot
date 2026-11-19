#!/bin/zsh
# Builds the app into ./build (universal: Apple Silicon + Intel).
#   tools/build.sh            build only
#   tools/build.sh --install  also copy to /Applications and relaunch
#   tools/build.sh --dmg      also make dist/<Name>-<version>.dmg
set -euo pipefail
cd "$(dirname "$0")/.."
source tools/config.sh
VERSION="${BUILD_VERSION:-$VERSION}"   # release.sh --local overrides this
./tools/fetch_sparkle.sh

APP="build/${APP_NAME}.app"
BIN="$APP/Contents/MacOS/${APP_NAME}"
rm -rf "$APP" build/obj
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" "$APP/Contents/Frameworks" build/obj

# Info.plist: template + values from config.sh
PLIST="$APP/Contents/Info.plist"
cp Resources/Info.plist "$PLIST"
set_key() { /usr/libexec/PlistBuddy -c "Set :$1 $2" "$PLIST" 2>/dev/null || /usr/libexec/PlistBuddy -c "Add :$1 string $2" "$PLIST"; }
set_key CFBundleName "$APP_NAME"
set_key CFBundleDisplayName "$APP_NAME"
set_key CFBundleExecutable "$APP_NAME"
set_key CFBundleIdentifier "$BUNDLE_ID"
set_key CFBundleShortVersionString "$VERSION"
# Build number must only go up; derive it from the version (1.2.3 -> 10203).
IFS=. read -r MAJ MIN PAT <<< "$VERSION"
set_key CFBundleVersion "$(( MAJ * 10000 + MIN * 100 + ${PAT:-0} ))"
set_key SUFeedURL "$FEED_URL"
set_key SUPublicEDKey "$SPARKLE_PUBLIC_KEY"

cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"   # regenerate with: swift tools/make_icon.swift
ditto vendor/Sparkle/Sparkle.framework "$APP/Contents/Frameworks/Sparkle.framework"

for arch in arm64 x86_64; do
  swiftc -O -swift-version 5 \
    -target "${arch}-apple-macos14.0" \
    Sources/*.swift \
    -F vendor/Sparkle -framework Sparkle \
    -framework AppKit -framework AVFoundation -framework AVKit -framework Carbon -framework QuickLookThumbnailing -framework ServiceManagement \
    -Xlinker -rpath -Xlinker @executable_path/../Frameworks \
    -module-cache-path build/obj/cache \
    -o "build/obj/${APP_NAME}-${arch}"
done
lipo -create "build/obj/${APP_NAME}-arm64" "build/obj/${APP_NAME}-x86_64" -output "$BIN"

# Ad-hoc signature, inside out (Sparkle's helpers first, then the app).
codesign --force --sign - --deep "$APP/Contents/Frameworks/Sparkle.framework"
codesign --force --sign - "$APP"
echo "Built $APP ($VERSION, $(lipo -archs "$BIN"))"

for arg in "$@"; do
  case "$arg" in
    --install)
      pkill -x "$APP_NAME" 2>/dev/null && sleep 1 || true
      rm -rf "/Applications/${APP_NAME}.app"
      ditto "$APP" "/Applications/${APP_NAME}.app"
      open "/Applications/${APP_NAME}.app"
      echo "Installed to /Applications/${APP_NAME}.app"
      ;;
    --dmg)
      ./tools/make_dmg.sh "$APP" "dist/${APP_NAME}-${VERSION}.dmg" "$APP_NAME"
      ;;
  esac
done
