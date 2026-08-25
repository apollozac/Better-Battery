# Changelog

## 1.6.3

- Refines the Modern charging bolt to match the macOS 27 system battery
  indicator more closely while preserving the current battery-level fill.

## 1.6.2

- Shows macOS's reported time-to-full estimate while the battery is finishing
  its charge instead of hiding the estimate behind a generic status.

## 1.6.1

- Adds a Modern battery design that matches the macOS 27 menu bar style while
  keeping the percentage outside the icon for legibility.
- Keeps the Classic outlined battery available as an option.
- Shows the current battery level continuously in the Modern icon, including
  while charging with Battery Level + Bolt selected.

## 1.5.0

- Added secure automatic updates and a manual Check for Updates command using
  Sparkle.
- Prevented the menu from changing size after its glass surface is displayed.

## 1.4.0

- Adds percentage-matched battery fill levels.
- Distinguishes battery, charging, finishing-charge, fully charged, and
  external-power states.
- Adds a percentage-only display mode for use beside Apple's battery icon.
- Adds selectable charging-icon styles and percentage placement.
- Adds General and Battery Health settings.
- Adds Open at Login.
- Reduces background work with notification-driven updates and low-frequency
  safety refreshes.
