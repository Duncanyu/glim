# Glim

Glim is a native macOS display color editor for adjusting the look of each connected display with a lightweight menu bar control panel.

[Download the Apple Silicon preview](https://github.com/Duncanyu/glim/releases/tag/v0.3.0) · [Install](#download-and-install) · [Use](#use) · [Features](#features) · [Changelog](CHANGELOG.md)

## Download and install

Download **Glim-0.3.0.zip** from the [0.3.0 preview release](https://github.com/Duncanyu/glim/releases/tag/v0.3.0). It requires an Apple Silicon Mac running macOS 14 or later.

1. Unzip the download and move **Glim.app** into **Applications**.
2. Open Glim from Applications. This preview is ad hoc signed and **not notarized**. macOS may block the first launch with a security warning. Open it once, then go to **System Settings → Privacy & Security → Open Anyway** and confirm. Only bypass this warning for a copy downloaded from this repository.
3. Glim appears in the menu bar. Click the Glim icon to open the control panel. Use **Settings** to switch between menu bar and Dock placement.

The release includes a SHA-256 checksum file. Place it beside the ZIP and run:

```sh
shasum -a 256 -c Glim-0.3.0.zip.sha256
```

## Use

- Press **Control–Option–Command–C** from any app to pause or resume adjustments. Change or disable the shortcut in Settings.
- Open the full settings window from the control panel. Press **Command–W** to close that window; Glim stays available in the menu bar or Dock.
- In **General → Updates**, choose whether Glim should check GitHub for updates automatically. It checks once a day while running and asks before installing. The setting is on by default. Updates replace the app in its current folder, so Glim needs write access there.
- Choose **Beginner** for brightness, contrast, gamma, warmth, and tint controls.
- Choose **Professional** for gamma and independent RGB controls.
- Edit the number beside a slider for a precise value. Each slider includes a reset control and range labels.
- Choose a display from the display menu before editing it.

## Features

- Menu bar popover with a full editor when more room is needed.
- Per-display settings and reset controls.
- Apparent brightness, contrast, gamma, warmth, green–magenta balance, tint, and independent RGB gain, gamma, and lift.
- Illustrative tone and color preview that follows the selected controls. It is not a hardware measurement.
- Active and deactivated Glim icons that adapt to the menu bar appearance.
- A model bridge for future automatic adjustments.
- A native GitHub release updater that verifies the ZIP checksum and downloaded app before installation.

## How it works

Glim saves each display’s existing Core Graphics RGB transfer table, applies changes when a control changes, and restores the saved table when adjustments are paused or the app quits. If another display utility changes the table while Glim is running, Glim treats that newer table as the current baseline.

The adjustment happens through display transfer curves. Glim does not use an overlay, screen capture, polling loop, background renderer, or third-party library.

## Limits

The backend uses three independent one-dimensional RGB curves. It supports tone, apparent dimming, white balance, tint, and per-channel gain, gamma, and lift. It does not provide arbitrary hue rotation, saturation editing, selective colors, or 3D LUTs. Brightness is apparent brightness and does not reduce panel backlight power.

Some Macs accept gamma API calls without visibly changing a display. Verify the result on each target Mac, especially with HDR, external displays, and display utilities that also manage transfer curves. Apple does not guarantee capture behavior for every display path, so verify screenshots and recordings before relying on capture invisibility.

Two identical external displays with no serial number can be controlled separately during a session, but their individual settings cannot be reliably persisted across launches.

## Build from source

Requires macOS 14 or later, Xcode Command Line Tools, `rsvg-convert`, and `iconutil`.

```sh
swift test
./scripts/build-app.sh
open "dist/Glim.app"
```

To regenerate the icons after editing their SVG sources:

```sh
./scripts/generate-icons.sh
```

The source icons are in [`Resources/source`](Resources/source). The packaged application is written to `dist/Glim.app`.

## Project status

Glim is pre-1.0 and under active development. The control layout, automatic mode, packaging, and display support may change while the project is being refined.

## License

No license has been selected yet. All rights are reserved by default.
