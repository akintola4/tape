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
xcrun simctl bootstatus "$UDID" >/dev/null
xcodebuild build -scheme Tape -destination "id=$UDID" -derivedDataPath "$DERIVED" -quiet
APP="$DERIVED/Build/Products/Debug-iphonesimulator/Tape.app"
BUNDLE=$(/usr/libexec/PlistBuddy -c "Print :CFBundleIdentifier" "$APP/Info.plist")
xcrun simctl install "$UDID" "$APP"
# A clean status bar: 9:41, full signal and Wi-Fi, a full battery. The
# screenshots so far come from a Simulator set to the Nigeria region, which
# uses a 24-hour clock, so the bar reads "09:41". Keep that for new ones.
xcrun simctl status_bar "$UDID" override --time 9:41 \
  --dataNetwork wifi --wifiMode active --wifiBars 3 \
  --cellularMode active --cellularBars 4 \
  --batteryState charged --batteryLevel 100

shot() { # appearance, file, launch arguments...
  local appearance=$1 file=$2; shift 2
  xcrun simctl ui "$UDID" appearance "$appearance"
  xcrun simctl launch --terminate-running-process "$UDID" "$BUNDLE" -TapeNoSplash "$@" >/dev/null
  sleep 3
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

# Picture it: the five everyday cases in both appearances, then a small and
# a large value per category to check the comparison switches.
mkdir -p "$OUT/picture-it"
for appearance in light dark; do
  shot $appearance picture-it/area-1acre-$appearance.png -TapeCategory area -TapeUnit acre -TapeAmount 1
  shot $appearance picture-it/weight-70kg-$appearance.png -TapeCategory weight -TapeUnit kg -TapeAmount 70
  shot $appearance picture-it/length-6ft-$appearance.png -TapeCategory length -TapeUnit ft -TapeAmount 6
  shot $appearance picture-it/cooking-1cup-$appearance.png -TapeCategory cooking -TapeUnit cup -TapeAmount 1
  shot $appearance picture-it/temperature-30c-$appearance.png -TapeCategory temperature -TapeUnit c -TapeAmount 30
done
shot light picture-it/area-2m2.png -TapeCategory area -TapeUnit m2 -TapeAmount 2
shot light picture-it/area-30ha.png -TapeCategory area -TapeUnit ha -TapeAmount 30
shot light picture-it/weight-10g.png -TapeCategory weight -TapeUnit g -TapeAmount 10
shot light picture-it/weight-100t.png -TapeCategory weight -TapeUnit t -TapeAmount 100
shot dark picture-it/length-5cm.png -TapeCategory length -TapeUnit cm -TapeAmount 5
shot dark picture-it/length-20km.png -TapeCategory length -TapeUnit km -TapeAmount 20
shot light picture-it/volume-5ml.png -TapeCategory volume -TapeUnit ml -TapeAmount 5
shot light picture-it/volume-1m3.png -TapeCategory volume -TapeUnit m3 -TapeAmount 1
shot dark picture-it/temperature-minus18c.png -TapeCategory temperature -TapeUnit c -TapeAmount -18
shot dark picture-it/temperature-180c.png -TapeCategory temperature -TapeUnit c -TapeAmount 180

xcrun simctl status_bar "$UDID" clear
xcrun simctl ui "$UDID" appearance light
