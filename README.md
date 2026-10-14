# Glim

Glim is a lightweight native macOS display color editor. It changes each display’s Core Graphics RGB transfer curve, so adjustments happen below the app and do not require an overlay, screen capture, or background renderer.

**Current release:** `0.2.0` · macOS 14 or later · Apple Silicon build

## Download

Download [`Glim-0.2.0.zip`](https://github.com/Duncanyu/gcalt/releases/download/v0.2.0/Glim-0.2.0.zip), unzip it, and move `Glim.app` to Applications. The build is ad hoc signed for development and evaluation; macOS may ask you to approve it the first time it opens.

## What it does

- Shows a compact control panel from the menu bar, with a full editor available when you need more room.
- Supports beginner and professional modes.
- Controls apparent brightness, contrast, gamma, warmth, green–magenta balance, tint, and independent RGB gain, gamma, and lift.
- Shows live tone and color previews, numeric values, slider ranges, neutral values, and reset controls.
- Supports multiple displays and stores settings per display when macOS exposes a stable display identity.
- Uses the supplied Glim active and deactivated icons. Menu bar images are AppKit templates, so macOS adapts their foreground contrast to the current menu bar appearance.
- Offers Dock or menu bar placement. In menu bar mode, click the Glim icon to open the popover.
- Provides the global toggle shortcut **Control–Option–Command–C**, configurable in Settings.

## Build from source

Requires macOS 14 or later, Xcode Command Line Tools, `rsvg-convert`, and `iconutil`.

```sh
swift test
./scripts/build-app.sh
open "dist/Glim.app"
```

To regenerate the supplied icon assets after editing their SVG sources:

```sh
./scripts/generate-icons.sh
```

The source icons are in [`Resources/source`](Resources/source). The packaged application is written to `dist/Glim.app`.

## How the display backend works

Glim saves the existing transfer table for each display, applies changes only when a control changes, and restores the saved table when adjustments are paused or the app quits. If another utility changes a display while Glim is running, Glim treats that newer table as the current baseline instead of restoring over it.

The automatic-adjustment bridge is present in the model but has no content analyzer yet. It can receive future adjustments without changing the display backend or the manual controls.

## Limits

The backend uses three independent one-dimensional RGB curves. It supports tone, apparent dimming, white balance, tint, and per-channel gain, gamma, and lift. It does not provide arbitrary hue rotation, saturation editing, selective colors, or 3D LUTs. Brightness is apparent brightness and does not reduce panel backlight power.

Some Macs accept gamma API calls without visibly changing a display. Verify the result on each target Mac, especially with HDR, external displays, and display utilities that also manage transfer curves. Apple does not guarantee capture behavior for every display path, so verify screenshots and recordings before relying on capture invisibility.

Two identical external displays with no serial number can be controlled separately during a session, but their individual settings cannot be reliably persisted across launches.

## Project status

Glim is pre-1.0 and under active development. The next releases may change the control layout, automatic mode, packaging, and display measurement features while the project is being refined.

## License

No license has been selected yet. All rights are reserved by default.
