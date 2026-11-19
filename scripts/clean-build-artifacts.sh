#!/usr/bin/env bash
# Reclaims disk space taken by Flutter/Xcode build output on this Mac.
# Everything removed by default is regenerated on the next build; the opt-in
# flags remove things that cost real time (or test data) to get back.
#
# Usage: scripts/clean-build-artifacts.sh [--dry-run] [--erase-simulators] [--old-runtimes] [--all]
set -euo pipefail

DRY_RUN=0
ERASE_SIMULATORS=0
OLD_RUNTIMES=0

for arg in "$@"; do
  case "$arg" in
    -n | --dry-run) DRY_RUN=1 ;;
    --erase-simulators) ERASE_SIMULATORS=1 ;;
    --old-runtimes) OLD_RUNTIMES=1 ;;
    --all) ERASE_SIMULATORS=1 OLD_RUNTIMES=1 ;;
    -h | --help)
      sed -n '2,6p' "$0" | sed 's/^# \{0,1\}//'
      cat <<'EOF'

Default: project build/ and .dart_tool/, Xcode DerivedData, SwiftPM/Xcode/
CocoaPods/CoreSimulator caches, old iOS DeviceSupport symbols (newest kept per
device), and unavailable simulators.

  -n, --dry-run        Show what would be removed and how big it is.
  --erase-simulators   Erase every simulator's contents (apps, photos, sign-ins).
  --old-runtimes       Delete all but the newest iOS simulator runtime.
  --all                Both of the above.
EOF
      exit 0
      ;;
    *)
      echo "Unknown option: $arg (see --help)" >&2
      exit 2
      ;;
  esac
done

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
XCODE_DIR="$HOME/Library/Developer/Xcode"
total_kb=0

size_kb() { du -sk "$1" 2>/dev/null | awk '{print $1}'; }

human() {
  awk -v kb="$1" 'BEGIN {
    if (kb >= 1048576) printf "%.1fG", kb / 1048576;
    else if (kb >= 1024) printf "%.0fM", kb / 1024;
    else printf "%dK", kb }'
}

# Removes a path (file or directory) and adds its size to the running total.
remove() {
  local path="$1"
  [ -e "$path" ] || return 0
  local kb
  kb="$(size_kb "$path")"
  kb="${kb:-0}"
  total_kb=$((total_kb + kb))
  printf '  %8s  %s\n' "$(human "$kb")" "${path/#$HOME/~}"
  [ "$DRY_RUN" -eq 1 ] || rm -rf "$path"
}

run() {
  echo "  \$ $*"
  [ "$DRY_RUN" -eq 1 ] || "$@"
}

# Deleting DerivedData or build/ under a running build corrupts it, and other
# worktrees of this repo may be building right now.
if pgrep -xq xcodebuild || pgrep -fq 'flutter_tools.snapshot (build|run|test|drive)'; then
  echo "A build (xcodebuild or flutter build/run/test) is running. Stop it first." >&2
  exit 1
fi

if pgrep -xq Xcode; then
  echo "Note: Xcode is open, so it will re-index into DerivedData right away. Quit it first for a full cleanup."
fi

[ "$DRY_RUN" -eq 1 ] && echo "Dry run: nothing will be deleted."

echo "Project build output ($REPO_ROOT)"
for p in build .dart_tool ios/build macos/build; do
  remove "$REPO_ROOT/$p"
done

echo "Xcode DerivedData"
if [ -d "$XCODE_DIR/DerivedData" ]; then
  for p in "$XCODE_DIR/DerivedData"/*; do remove "$p"; done
fi

echo "Caches"
remove "$HOME/Library/Caches/org.swift.swiftpm"
remove "$HOME/Library/Caches/com.apple.dt.Xcode"
remove "$HOME/Library/Caches/CocoaPods"
remove "$HOME/Library/Developer/CoreSimulator/Caches"
remove "$HOME/Library/Logs/CoreSimulator"

# Xcode copies ~6 GB of symbols per iOS version a device has run. Only the
# newest version per device model is still useful; Xcode re-copies it if needed.
echo "iOS DeviceSupport (keeping newest per device)"
device_support="$XCODE_DIR/iOS DeviceSupport"
if [ -d "$device_support" ]; then
  models="$(ls "$device_support" | awk '{print $1}' | sort -u)"
  for model in $models; do
    while IFS= read -r p; do
      remove "$p"
    done < <(ls -d "$device_support/$model "* 2>/dev/null | sort -V | sed '$d')
  done
fi

echo "Simulators"
run xcrun simctl delete unavailable
if [ "$ERASE_SIMULATORS" -eq 1 ]; then
  run xcrun simctl shutdown all
  run xcrun simctl erase all
fi

if [ "$OLD_RUNTIMES" -eq 1 ]; then
  echo "Old iOS simulator runtimes (keeping newest)"
  xcrun simctl runtime list -j |
    /usr/bin/python3 -c '
import json, sys
images = [i for i in json.load(sys.stdin).values() if i.get("platformIdentifier", "").endswith("iphonesimulator")]
version = lambda i: [int(x) for x in i["version"].split(".")]
# Keep every image at the newest version: device-specific runtimes (e.g. iPhone Duo) share it.
newest = max(map(version, images), default=None)
for i in images:
    if version(i) == newest:
        continue
    print(i["identifier"], i["version"], i.get("build", ""), sep="\t")
' | while IFS=$'\t' read -r id version build; do
    echo "  iOS $version ($build)"
    run xcrun simctl runtime delete "$id"
  done
fi

echo
if [ "$DRY_RUN" -eq 1 ]; then
  echo "Would free at least $(human "$total_kb") (plus any simulator and runtime cleanup listed above)."
else
  echo "Freed at least $(human "$total_kb"). Run 'make get && make gen' before the next build."
fi
