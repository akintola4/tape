#!/bin/zsh
# Records the opening animation in the simulator so you can watch it on the Mac.
#
#   scripts/record-splash.sh                 build, then record at normal speed and 4x slow motion
#   scripts/record-splash.sh --no-build      record the build that's already there
#   scripts/record-splash.sh final           name the round: <time>-pull-final-normal.mp4
#
# SIM=<udid> picks a simulator other than the first iPhone 17 Pro, e.g. a fresh
# one when iOS keeps showing an old launch screen after the image changed.
#
# Videos land in ~/Movies/Tape splash/ as <time>-pull[-name]-normal.mp4 and
# -slow-4x.mp4; the normal-speed one opens in QuickTime. The first second or
# so of each is the debug build launching, not the animation.
set -euo pipefail

cd "$(dirname "$0")/.."
SIM_NAME="iPhone 17 Pro"
DEST="platform=iOS Simulator,name=$SIM_NAME,OS=26.1"
DERIVED=build/DerivedData
OUT="$HOME/Movies/Tape splash"
mkdir -p "$OUT"

BUILD=1
if [[ "${1:-}" == "--no-build" ]]; then BUILD=0; shift; fi
NAME=pull${1:+-$1}

SIM=${SIM:-$(xcrun simctl list devices available | grep -E "^ +$SIM_NAME \(" | head -1 | grep -oE '[0-9A-F-]{36}')}
xcrun simctl boot "$SIM" 2>/dev/null || true

if (( BUILD )); then
  xcodebuild build -scheme Tape -destination "$DEST" -derivedDataPath "$DERIVED" -quiet
fi
APP="$DERIVED/Build/Products/Debug-iphonesimulator/Tape.app"
BID=$(/usr/libexec/PlistBuddy -c "Print CFBundleIdentifier" "$APP/Info.plist")
xcrun simctl install "$SIM" "$APP"

STAMP=$(date +%H%M%S)
record() { # name, seconds, launch args...
  local name=$1 secs=$2; shift 2
  local raw="$OUT/.raw.mov" file="$OUT/$STAMP-$name.mp4"
  xcrun simctl terminate "$SIM" "$BID" 2>/dev/null || true
  xcrun simctl io "$SIM" recordVideo --codec h264 --force "$raw" >/dev/null 2>&1 &
  local rec=$!
  sleep 1.5
  xcrun simctl launch "$SIM" "$BID" "$@" >/dev/null
  sleep "$secs"
  kill -INT $rec; wait $rec 2>/dev/null || true
  # Keep it small and playable anywhere.
  ffmpeg -loglevel error -y -i "$raw" -vf "scale=-2:1280" -c:v libx264 -pix_fmt yuv420p "$file"
  rm -f "$raw"
  echo "$file"
}

NORMAL=$(record "$NAME-normal" 5)
record "$NAME-slow-4x" 12 -TapeSplashSlow
[[ -n "${NO_OPEN:-}" ]] || open -a "QuickTime Player" "$NORMAL"
