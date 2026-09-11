# The Xcode project

The project lives at `Senku/Senku.xcodeproj`. The packages hold everything real,
so the app targets are thin shells.

## Done

- [x] Multiplatform app project, created at `Senku/`
- [x] `SenkuCore` and `SenkuUI` added as local packages
- [x] Both linked to the **Senku** target — adding a local package does *not*
      link it; the product has to be added to the target as well
- [x] Template `ContentView.swift` and `Item.swift` removed, entry point
      replaced with one that presents `RootView()`
- [x] Builds and runs on the iOS simulator

### The widget extension — done

`SenkuWidgets` was added by hand rather than through the template. Two things
about it are worth knowing before editing the project:

- The extension's `Info.plist` is **outside** the synchronized folder, at
  `SenkuWidgets-Info.plist`. A file inside a synchronized folder is also added
  to that target's Resources, which collides with its own `Info.plist`.
- `INFOPLIST_KEY_*` build settings only ever set a **top-level** key, and
  WidgetKit needs `NSExtensionPointIdentifier` *nested* inside an `NSExtension`
  dict. So the plist has to be a real file; the build setting silently produces
  an extension that builds and never registers.

## Remaining

### Turn on Mac

Select the **Senku** target ▸ **General** ▸ *Supported Destinations* ▸ **+** ▸
**Mac (Mac Catalyst)**. Then build with the scheme set to *My Mac*.

### Add the watch app

1. **File ▸ New ▸ Target… ▸ watchOS ▸ App**, named **Senku Watch**.
2. Delete the generated `ContentView.swift` and app entry file.
3. Move `App/Watch/SenkuWatchApp.swift` into the new target's folder.
4. Add `SenkuCore` and `SenkuUI` to that target under **General** ▸ *Frameworks,
   Libraries, and Embedded Content*.

### Signing

Project ▸ each target ▸ **Signing & Capabilities** ▸ set **Team** to your Apple
ID. A free account runs on the simulator and your own devices; a paid account is
only needed to ship.

## How sources are organised

The project uses Xcode 16+ **synchronized folders**: every file inside
`Senku/Senku/` is automatically part of the target, with no project file entry.
Adding a screen means dropping a file in — though in practice screens belong in
the `SenkuUI` package, where they can be built and tested for all three
platforms at once.

## Building and testing from the command line

```sh
# Core logic
cd SenkuCore && swift run senku verify && swift test

# UI package, on each platform
cd ../SenkuUI && swift test
xcodebuild -scheme SenkuUI -destination 'generic/platform=iOS' build
xcodebuild -scheme SenkuUI -destination 'generic/platform=watchOS' build

# Screens as PNG, without a simulator
swift run senku-render /tmp/senku-shots

# The app itself
cd ../Senku
xcodebuild -project Senku.xcodeproj -scheme Senku \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build
```

## Running on the simulator

```sh
xcrun simctl boot "iPhone 17 Pro"
open -a Simulator
xcrun simctl install booted <path to Senku.app>
xcrun simctl launch booted pk.Senku
xcrun simctl io booted screenshot shot.png
```

Seeding a profile into the simulator from outside the app does **not** work.
`defaults write` against the container path is discarded by the preference
daemon, and `simctl spawn booted /usr/bin/defaults write` is refused by the
sandbox ("Could not write domain"). Save a profile through the app's own Quick
calc tab, and test persistence through `SenkuUIUnitTests`.
