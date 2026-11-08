# Tape

Tape is a unit converter for iPhone that works with no signal. Type one number, pick its unit, and you see it in every other unit of that category at once.

It comes from the same place as [Pocket](https://github.com/akintola4/pocket): small phone tools that keep working offline. Tape has no network code at all. It also knows the unit people around me actually buy land in, the plot.

It isn't on the App Store. You clone it, open it in Xcode and run it on your own phone.

## Screenshots

| Area (light) | Area (dark) | Length |
|---|---|---|
| ![One plot in every area unit, light mode](docs/screenshots/area-light.png) | ![One plot in every area unit, dark mode](docs/screenshots/area-dark.png) | ![1.83 m in every length unit, with feet and inches](docs/screenshots/length-light.png) |

| An acre in plots | Temperature | Copied |
|---|---|---|
| ![One acre is 6.05 plots](docs/screenshots/acre-to-plots.png) | ![37 °C in Fahrenheit and Kelvin](docs/screenshots/temperature-dark.png) | ![The copied toast after tapping a row](docs/screenshots/copied-dark.png) |

| Settings (light) | Settings (dark) |
|---|---|
| ![Settings: plot size, decimals, haptics](docs/screenshots/settings-light.png) | ![Settings in dark mode](docs/screenshots/settings-dark.png) |

`scripts/screenshots.sh` takes all of these in the Simulator using the launch arguments below.

## What it does

- Six categories: length, area, weight, volume, temperature and cooking.
- Under the number, a drawing pictures the amount with something you already know the size of: plots of land, 50 kg bags of rice, a person next to a door, cups, a thermometer. It picks the object by size, so a few grams are Maggi cubes and a few tonnes are cars, and it redraws as you type.
- Every other unit in the category is listed below that, most useful first (plots when you type acres, pounds when you type kilograms, centimetres when you type feet), and updates as you type. Number formatting follows your phone's region.
- Tap a row to copy it with its unit, for example "668.9 m²". A small toast confirms it, and you get a light tap if haptics are on. Long-press a row to type in that unit instead.
- Rounding keeps four significant figures without rounding away whole numbers: 668.9 m², 7,200 ft², 0.1653 ac. Float noise like 0.30000000000000004 never reaches the screen. In Settings you can switch to a fixed 0, 2 or 4 decimal places.
- Length has a feet-and-inches row, so 1.83 m reads as 6′ 0″.
- Temperature uses the real formulas with their offsets, so 0 °C is 32 °F and not 0 °F. A ± key handles values below zero, since the number pad has no minus.
- Tape remembers the last category you used, plus the unit and amount for each category.

### Units

| Category | Units |
|---|---|
| Length | mm, cm, m, km, in, ft, yd, mi, and feet and inches |
| Area | m², ft², yd², acres, hectares, plots |
| Weight | g, kg, lb, oz, stone, tonnes |
| Volume | mL, L, US gallons, UK gallons, US fl oz, m³ |
| Temperature | °C, °F, K |
| Cooking | cups (240 ml), tablespoons (15 ml), teaspoons (5 ml), mL, L, US fl oz |

Conversions go through Foundation's `Dimension` units. Foundation rounds a few of its coefficients, for example the pound as 0.453592 kg, so Tape defines those with their exact legal values: 0.45359237 kg to the pound, 3.785411784 L to the US gallon.

## A note on plots

In Lagos and Abuja a plot of land is usually 60 × 120 ft. That's 7,200 ft², or 668.9 m². I kept seeing websites say a plot is 648 m², and for a 60 × 120 ft plot that's wrong: 648 m² is the metric 18 × 36 m plot, about 21 m² smaller. Tape gets this right by default.

Plots aren't the same size everywhere, so you can change it in Settings:

- 60 × 120 ft, 668.9 m² (Lagos and Abuja; the default)
- 50 × 100 ft, 464.5 m²
- 18 × 36 m, 648 m²
- Custom, any width × length in feet or metres

On the default plot, an acre is 6.05 plots and a plot is 0.1653 acres.

## Build and run

You need Xcode 27 and a phone or simulator on iOS 26.1 or later. There are no packages and no API keys.

```bash
git clone https://github.com/akintola4/tape.git
cd tape
open Tape.xcodeproj
```

Pick the Tape scheme and a simulator (I use iPhone 17 Pro), then press Run. You don't need to set up signing for the Simulator.

### On your own iPhone

1. Create `Config/Local.xcconfig`. It's git-ignored, so your details stay out of the repo:

   ```
   TAPE_BUNDLE_PREFIX = com.yourname
   DEVELOPMENT_TEAM = YOURTEAMID
   ```

   `Config/Tape.xcconfig` includes it if it exists. You can also edit `Tape.xcconfig` directly, or leave the team empty and choose it under Signing & Capabilities.
2. Plug in your phone, select it and press Run. The first time, go to Settings › General › VPN & Device Management on the phone and trust your developer certificate.

With a free Apple ID, an app you install from Xcode stops opening after 7 days. Run it from Xcode again to get another 7. Your settings survive the reinstall. With a paid Apple Developer Program membership the install lasts a year.

### Tests

```bash
xcodebuild test -scheme Tape -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.1'
```

The 90 tests in `TapeTests` cover the pure logic in `Shared/`:

- round trips between every pair of units in every category
- the exact definitions
- temperature offsets
- the plot presets (60 × 120 ft is 668.9 m², 18 × 36 m is 648 m², an acre is 6.05 plots)
- custom and zero-sized plots
- rounding and formatting in en_GB, fr_FR and de_DE
- the feet-and-inches split, including carrying 11.96″ up to the next foot
- parsing and cleaning typed input
- what's remembered between launches
- which object the drawing uses at each size, the friendly rounding (½, ¼, ¾), how many plots are drawn for each plot size, and the order of the list

Locales are pinned so the tests pass on any machine. Leave out `OS=26.1` if your iPhone 17 Pro simulator runs a newer iOS.

### Launch arguments (Debug builds)

A few are in the scheme, switched off. Turn them on under Product › Scheme › Edit Scheme › Run › Arguments, or pass them to `xcrun simctl launch`.

- `-TapeCategory area` opens on a category: `length`, `area`, `weight`, `volume`, `temperature` or `cooking`.
- `-TapeUnit plot` sets the input unit by its id, as listed in `Shared/UnitCatalog.swift`.
- `-TapeAmount 2.5` sets the amount.
- `-TapeOpenSettings` opens Settings on launch.
- `-TapeDemoToast` shows the "Copied" toast for the first row and leaves it up.
- `-TapeDemoTyping "2.5<<<80"` types into the amount field one key at a time (`<` deletes), for recording the drawing as it changes.

None of them save anything. They only change what the app opens on.

## Project layout

```
Tape/              the app: ConverterView, PictureCard and its shapes, SettingsView, AppSettings
Shared/            the pure logic: UnitsLogic, UnitCatalog, PictureLogic, PlotSize, TapePersistence, Theme, Tokens
TapeTests/         Swift Testing suites for Shared/
Config/            Tape.xcconfig (bundle prefix, team), Info.plist
scripts/           make-icon.py (draws the app icon), screenshots.sh
```

The app icon is drawn by `scripts/make-icon.py`. Run `python3 scripts/make-icon.py` to regenerate it (it needs Pillow).

## Colour

The main colour is baby blue, `#8FD3FF`. Dark mode uses it as it is. In light mode, `#8FD3FF` on white is only 1.6:1, which is too faint for text and icons, so the accent there is a deeper `#1874B0`. That's 5.0:1 on white and 4.5:1 on the grey cards. The active category chip stays light blue in both modes, with navy text on it.

## License

MIT. See [LICENSE](LICENSE).

Made by DevAkintola.
