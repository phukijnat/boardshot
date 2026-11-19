#!/bin/zsh
# Downloads the pinned Sparkle release into vendor/Sparkle and checks its hash.
set -euo pipefail
cd "$(dirname "$0")/.."
source tools/config.sh

if [[ -f vendor/Sparkle/.version && "$(cat vendor/Sparkle/.version)" == "$SPARKLE_VERSION" ]]; then
  exit 0
fi

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
url="https://github.com/sparkle-project/Sparkle/releases/download/${SPARKLE_VERSION}/Sparkle-${SPARKLE_VERSION}.tar.xz"
echo "Downloading Sparkle ${SPARKLE_VERSION}…"
curl -fsSL -o "$tmp/sparkle.tar.xz" "$url"

actual=$(shasum -a 256 "$tmp/sparkle.tar.xz" | awk '{print $1}')
if [[ "$actual" != "$SPARKLE_SHA256" ]]; then
  echo "Sparkle download hash mismatch: got $actual" >&2
  exit 1
fi

rm -rf vendor/Sparkle
mkdir -p vendor/Sparkle
tar -xf "$tmp/sparkle.tar.xz" -C vendor/Sparkle
echo "$SPARKLE_VERSION" > vendor/Sparkle/.version
echo "Sparkle ${SPARKLE_VERSION} ready in vendor/Sparkle"
