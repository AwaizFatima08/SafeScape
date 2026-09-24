#!/usr/bin/env bash
# Download the routine pictograms (Noto Color Emoji, Apache 2.0, Google) into
# assets/icons/. scripts/icons.txt maps our icon key to the emoji codepoint.
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p assets/icons
while read -r key code; do
  [ -z "$key" ] && continue
  curl -sfL "https://raw.githubusercontent.com/googlefonts/noto-emoji/main/2D/png/128/emoji_u$code.png" \
    -o "assets/icons/$key.png" || echo "FAILED: $key ($code)"
done < scripts/icons.txt
echo "icons: $(ls assets/icons | wc -l)"
