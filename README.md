# Color Editor

A small native macOS display color editor. “Color Editor” is a temporary name; no custom icon or branding is included.

## Build and run

Requires macOS 14 or newer and Xcode command-line tools.

```sh
swift test
./scripts/build-app.sh
open "dist/Color Editor.app"
```

The app starts in the menu bar. Settings can switch it to a Dock app and hide the menu bar item, or switch back. Closing the editor window leaves adjustments running; quitting restores the display curves that were in place when the app started. Reset controls are always available in the editor.

## What the display backend can do

The editor writes each display's public Core Graphics RGB gamma table. It saves the existing table, applies changes only when a control changes, and restores the saved table when adjustments are paused or the app quits. It uses no overlay, screen capture, polling, third-party library, or background renderer. A future automatic adjustment source can feed `submitAutomaticAdjustment` without changing the display backend.

If another display utility or macOS changes a gamma table while this app is running, the editor detects the change at its next adjustment. It then treats that newer table as the baseline, and it does not restore over a later change it no longer owns.

These are three independent one-dimensional channel curves. They provide apparent dimming, tone, white balance, tint, and per-channel gain/gamma/lift. They **cannot** provide arbitrary hue rotation, saturation, selective colors, or a 3D LUT. Dimming does not lower panel backlight power. Some recent Macs accept gamma API calls without visibly changing the display; the app cannot detect that from the API response. Verify the result by eye on each display. Because Apple does not guarantee capture behavior for every path, verify screenshots and recordings on the target Mac before relying on capture invisibility.

A small output floor keeps the editor visible when several controls are minimized at once.

The app is currently unsigned for distribution (the build script applies local ad-hoc signing). A release build needs a permanent bundle identifier, developer signature, and hardware testing across SDR, HDR, built-in, and external displays.

Two identical external monitors that report no serial number can be controlled separately during a session, but their individual settings are not saved across launches because macOS does not provide a reliable identity for that case through the APIs used here.
