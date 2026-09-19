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

### The App Group is on

The widget reads the profile and the running rest out of `group.pk.Senku`,
because a widget is a separate process and cannot see the app's `UserDefaults`.

**This works on a free Apple ID.** It did not use to — the note here previously
said App Groups needed the paid programme — but Xcode now issues personal-team
profiles carrying the group, verified on all four bundles:

```
Senku.app                ['group.pk.Senku']
SenkuWidgets.appex       ['group.pk.Senku']
SenkuWatch.app           ['group.pk.Senku']
SenkuWatchWidgets.appex  ['group.pk.Senku']
```

So `SENKU_ENTITLEMENTS = AppGroup` is the default. `Free` still exists and still
builds, for a machine whose Apple ID will not issue the group.

`SenkuStorage.migrateIfNeeded` carries a profile saved before the group into it,
so turning this on costs nobody their numbers.

### iCloud is *not* available on a free account

Unlike App Groups. Adding `com.apple.developer.ubiquity-kvstore-identifier`
fails at signing:

```
error: Personal development teams, including "…", do not support the
       iCloud capability.
```

That rules out `NSUbiquitousKeyValueStore`, CloudKit and iCloud-backed
SwiftData until the paid membership. Phone-to-watch sync therefore goes over
**WatchConnectivity**, which needs no entitlement — see `ProfileSync`.

Also worth knowing: `codesign -d --entitlements` prints an empty dict for
simulator builds even when an entitlement is live. The check that works is
`xcrun simctl get_app_container <device> pk.Senku groups`, or reading
`embedded.mobileprovision` out of a device build.

## The four targets

| Target | Bundle id | What it is |
| --- | --- | --- |
| `Senku` | `pk.Senku` | the iPhone app |
| `SenkuWidgets` | `pk.Senku.SenkuWidgets` | Home Screen widgets, Live Activity, Control Center |
| `SenkuWatch` | `pk.Senku.watchkitapp` | the watch app |
| `SenkuWatchWidgets` | `pk.Senku.watchkitapp.widgets` | the rest-timer complication |

All four link `SenkuCore` and `SenkuUI` as local packages and carry
`group.pk.Senku`. There is **no Mac target**: the packages declare `.macOS(.v14)`
only so `swift test` runs on the host.

### Signing

Project ▸ each target ▸ **Signing & Capabilities** ▸ set **Team** to your Apple
ID. A free account runs on the simulator and your own devices; a paid account is
only needed to ship.

## How sources are organised

The project uses Xcode 16+ **synchronized folders**: every file inside
`Senku/Senku/` is automatically part of the target, with no project file entry.
Adding a screen means dropping a file in — though in practice screens belong in
the `SenkuUI` package, where they can be built and tested for both platforms at
once.

## Building and testing from the command line

```sh
# Core logic
cd SenkuCore && swift run senku verify && swift test

# UI package, on each platform
cd ../SenkuUI && swift test
xcodebuild -scheme SenkuUI -destination 'generic/platform=iOS' build
xcodebuild -scheme SenkuUI -destination 'generic/platform=watchOS' build

# The app itself. Note the *generic* destination — see below.
cd ../Senku
xcodebuild -project Senku.xcodeproj -scheme Senku \
  -destination 'generic/platform=iOS Simulator' build
```

### Build with a generic destination, not a named device

Naming a concrete device — `platform=iOS Simulator,name=iPhone 17` — makes the
watch app fail to link:

```
ld: building for 'watchOS-simulator', but linking in object file
(…/Debug-iphonesimulator/SenkuCore.o) built for 'iOS-simulator'
```

The build system specialises the local packages for the **primary** destination
and then hands those iOS-built objects to `SenkuWatch`, which is watchOS. A
generic destination leaves the packages unspecialised, each platform builds its
own, and the watch app links and embeds correctly:

```sh
xcodebuild ... -destination 'generic/platform=iOS Simulator' build   # works
xcodebuild ... -destination 'generic/platform=iOS' build             # works
xcodebuild ... archive                                               # works
xcodebuild ... -destination 'platform=iOS Simulator,name=iPhone 17'  # fails
```

Nothing in the project is wrong, and there is nothing to fix in it — pass a
generic destination and install to the named device afterwards with `simctl` or
`devicectl`. Xcode's own Run button is unaffected.

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

## The debug hooks

Both are `#if DEBUG` and both are read at launch, so they go on the scheme's
environment or on `simctl launch`:

```sh
SIMCTL_CHILD_SENKU_SAMPLE=1 xcrun simctl launch booted pk.Senku
```

| Variable | Effect |
| --- | --- |
| `SENKU_SAMPLE` | loads `Senku/Senku/sample-data.json` through the real importer — three weeks of workouts, weigh-ins, water, food and anime |
| `SENKU_SCREEN` | opens the app directly on one screen (`water`, `food`, `records`…), for screenshots |

## Running the watch app

The watch app needs its phone: pair the simulators once, install both, and run
the phone first so `PhoneSync` is up before the watch asks it for a refresh.

```sh
xcrun simctl list pairs                      # find or create a pair
xcrun simctl boot "iPhone 17 Pro"
xcrun simctl boot "Apple Watch Series 11 (46mm)"
xcrun simctl install booted <path to SenkuWatch.app>
xcrun simctl launch booted pk.Senku.watchkitapp
```
