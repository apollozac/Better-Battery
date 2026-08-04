# Better Battery

A deliberately conventional macOS menu bar battery indicator:

- a percentage-matched SF Symbols battery icon and percentage by default, with
  a bolt whenever external power is connected;
- an optional compact percentage-only display designed to sit beside Apple's
  battery item;
- a native General settings pane for display mode and Open at Login;
- a dedicated Battery Health settings pane;
- clock-matching 13-point SF Pro numerals with stable tabular spacing;
- system-matching power-source language plus charging detail in the tooltip;
- cached battery health, maximum capacity, and cycle count;
- state-appropriate charging and remaining-time estimates;
- immediate refresh after wake plus a public system time-estimate fallback;
- an Icon Composer app icon with current and fallback macOS resources;
- no Dock icon and no account, analytics, or network access.

Better Battery updates from macOS power-source change notifications. Its safety
refresh runs every five minutes while battery state is active and every 15
minutes when fully charged on power. Recent readings are reused when the menu is
reopened within five seconds. Battery health is queried only when its Settings
pane is opened and remains cached for an hour, even after the Settings window is
released.

## Build and run

```sh
./script/build_and_run.sh
```

The Run action in Codex uses the same script. The app requires macOS 27 or later
and builds against the macOS 27 SDK.

To build the release app ZIP in `outputs/`:

```sh
./script/package_release.sh
```

Release packages use the locally installed Developer ID identity by default.
Set `BETTER_BATTERY_SIGN_IDENTITY` to override the signing identity.

The scripts use a project-local compiler cache and disable SwiftPM's nested
sandbox so they also work from inside Codex's managed workspace.

After launching Better Battery, you can hide Apple's battery item in System
Settings so only this replacement remains visible.
