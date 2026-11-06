#!/usr/bin/env bash
# Builds Tape for the Simulator and takes the README screenshots in docs/screenshots/.
#
#   scripts/screenshots.sh [simulator name]     # default: iPhone 17 Pro
#
# Uses the Debug launch arguments (-TapeCategory, -TapeUnit, -TapeAmount,
# -TapeOpenSettings, -TapeDemoToast, -TapeNoSplash) so no tapping is needed.
set -euo pipefail

cd "$(dirname "$0")/.."
NAME="${1:-iPhone 17 Pro}"
UDID=$(xcrun simctl list devices available | grep -F "$NAME (" | head -1 | grep -oE '[0-9A-F-]{36}')
OUT=docs/screenshots
DERIVED=build/DerivedData

xcrun simctl boot "$UDID" 2>/dev/null || true
xcodebuild build -scheme Tape -destination "id=$UDID" -derivedDataPath "$DERIVED" -quiet
APP="$DERIVED/Build/Products/Debug-iphonesimulator/Tape.app"
BUNDLE=$(/usr/libexec/PlistBuddy -c "Print :CFBundleIdentifier" "$APP/Info.plist")
xcrun simctl install "$UDID" "$APP"
xcrun simctl status_bar "$UDID" override --time 9:41 --batteryState charged --batteryLevel 100 --cellularBars 4 --wifiBars 3

shot() { # appearance, file, launch arguments...
  local appearance=$1 file=$2; shift 2
  xcrun simctl ui "$UDID" appearance "$appearance"
  xcrun simctl launch --terminate-running-process "$UDID" "$BUNDLE" -TapeNoSplash "$@" >/dev/null
  sleep 2.5
  xcrun simctl io "$UDID" screenshot "$OUT/$file" >/dev/null 2>&1
  echo "wrote $OUT/$file"
}

mkdir -p "$OUT"
shot light area-light.png -TapeCategory area -TapeUnit plot -TapeAmount 1
shot dark area-dark.png -TapeCategory area -TapeUnit plot -TapeAmount 1
shot light length-light.png -TapeCategory length -TapeUnit m -TapeAmount 1.83
shot dark temperature-dark.png -TapeCategory temperature -TapeUnit c -TapeAmount 37
shot light acre-to-plots.png -TapeCategory area -TapeUnit acre -TapeAmount 1
shot dark copied-dark.png -TapeCategory cooking -TapeUnit cup -TapeAmount 1 -TapeDemoToast
shot light settings-light.png -TapeCategory area -TapeOpenSettings
shot dark settings-dark.png -TapeCategory area -TapeOpenSettings

xcrun simctl status_bar "$UDID" clear
xcrun simctl ui "$UDID" appearance light
