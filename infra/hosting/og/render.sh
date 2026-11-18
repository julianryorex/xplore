#!/usr/bin/env bash
# Renders og-invite.html to ../public/og-invite.png (1200x630) and the icons
# from the app icon, using headless Chrome and macOS `sips`.
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
chrome="${CHROME:-/Applications/Google Chrome.app/Contents/MacOS/Google Chrome}"

"$chrome" --headless=new --disable-gpu --hide-scrollbars --force-device-scale-factor=1 \
  --window-size=1200,630 --virtual-time-budget=5000 \
  --screenshot="$here/../public/og-invite.png" "file://$here/og-invite.html"

icon="$here/../../../ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-1024x1024@1x.png"
sips -z 180 180 "$icon" --out "$here/../public/apple-touch-icon.png" >/dev/null
sips -z 64 64 "$icon" --out "$here/../public/favicon.png" >/dev/null
