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
builds — Mac Catalyst is pinned to it via `CODE_SIGN_ENTITLEMENTS[sdk=macosx*]`,
because a Mac app carrying an App Group demands a provisioning profile and there
is no widget on Catalyst to share with.

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
