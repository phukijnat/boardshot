# Single place for the app's identity. build.sh and release.sh read this file.
# To rename the app, change APP_NAME (and BUNDLE_ID / GITHUB_REPO if needed).

APP_NAME="Boardshot"
BUNDLE_ID="io.github.phukijnat.boardshot"
GITHUB_REPO="phukijnat/boardshot"

# Version shown to users (CFBundleShortVersionString). release.sh updates this line.
VERSION="0.1.1"

# Where the app looks for updates. Can be overridden for local testing:
#   FEED_URL=http://localhost:8000/appcast.xml ./build.sh
FEED_URL="${FEED_URL:-https://raw.githubusercontent.com/${GITHUB_REPO}/main/appcast.xml}"

# Sparkle (update framework). tools/fetch_sparkle.sh downloads it into vendor/.
SPARKLE_VERSION="2.10.1"
SPARKLE_SHA256="1a856d2a9edb8e628de88121d7be04cf0e2167f8641650b78fca00b14244cf27"

# Public half of the update-signing key (private half lives in your Keychain).
# Generate with: vendor/Sparkle/bin/generate_keys
SPARKLE_PUBLIC_KEY="c2oPdQwnkwcgIR/i6fcoGC6Hj7gHfBVxuC1bT4qtDho="
