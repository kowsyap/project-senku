# Building and running

## Requirements

| | |
| --- | --- |
| macOS | Sonoma or later |
| Xcode | 26 |
| Swift | 6.0+ (packages build without Xcode) |
| Targets | iOS 26.5, watchOS 26.5 |
| Account | A free Apple ID is sufficient |

## Targets

| Target | Bundle identifier |
| --- | --- |
| Senku | `pk.Senku` |
| SenkuWidgets | `pk.Senku.SenkuWidgets` |
| SenkuWatch | `pk.Senku.watchkitapp` |
| SenkuWatchWidgets | `pk.Senku.watchkitapp.widgets` |

All four link `SenkuCore` and `SenkuUI` as local packages and carry the App
Group `group.pk.Senku`.

## In Xcode

1. `open Senku/Senku.xcodeproj`
2. For each target, **Signing & Capabilities** ▸ set **Team** to your Apple ID.
3. Select an iPhone simulator and run.

A free account runs on the simulator and on your own devices. A paid membership
is needed only to distribute.

## From the command line

```sh
# Packages, on the host
cd SenkuCore && swift test        # 171 tests
cd ../SenkuUI  && swift test      # 73 tests

# Package builds per platform
xcodebuild -scheme SenkuUI -destination 'generic/platform=iOS' build
xcodebuild -scheme SenkuUI -destination 'generic/platform=watchOS' build

# The app
cd ../Senku
xcodebuild -project Senku.xcodeproj -scheme Senku \
  -destination 'generic/platform=iOS Simulator' build
```

### Use a generic destination

Naming a concrete device makes the watch app fail to link:

```
ld: building for 'watchOS-simulator', but linking in object file
(…/Debug-iphonesimulator/SenkuCore.o) built for 'iOS-simulator'
```

The build system specialises local packages for the primary destination and then
hands those objects to the watch target. A generic destination leaves them
unspecialised and each platform builds its own.

| Destination | Result |
| --- | --- |
| `generic/platform=iOS Simulator` | ✅ |
| `generic/platform=iOS` | ✅ |
| `archive` | ✅ |
| `platform=iOS Simulator,name=iPhone 17` | ❌ |

Install to a named device afterwards with `simctl` or `devicectl`. Xcode's Run
button is unaffected.

## Running on a simulator

```sh
xcrun simctl boot "iPhone 17 Pro"
open -a Simulator
xcrun simctl install booted <path to Senku.app>
xcrun simctl launch booted pk.Senku
xcrun simctl io booted screenshot shot.png
```

### The watch app

The watch app requires its paired phone. Launch the phone app first so
`PhoneSync` is running before the watch requests a refresh.

```sh
xcrun simctl list pairs
xcrun simctl boot "iPhone 17 Pro"
xcrun simctl boot "Apple Watch Series 11 (46mm)"
xcrun simctl install booted <path to Senku.app/Watch/SenkuWatch.app>
xcrun simctl launch booted pk.Senku.watchkitapp
```

### Debug hooks

Both are `#if DEBUG`, read at launch, and set as environment variables:

| Variable | Effect |
| --- | --- |
| `SENKU_SAMPLE` | loads `Senku/Senku/sample-data.json` through the production importer — three weeks of workouts, weigh-ins, water, food and anime |
| `SENKU_SCREEN` | opens the app directly on one screen (`water`, `food`, `records`…) |
| `SENKU_REST` | watch only: starts a rest of N seconds at launch |

### Watching a rest land on a real watch

The end of a rest is the hardest thing in the app to observe — it happens on a
device that cannot hold a debugger, seconds after you have stopped looking at
it. `SENKU_REST` plus a bridged console makes it watchable:

```sh
xcrun devicectl device install app --device <watch udid> SenkuWatch.app
xcrun devicectl device process launch --device <watch udid> --console \
  --terminate-existing --environment-variables '{"SENKU_REST":"25"}' \
  pk.Senku.watchkitapp
```

Everything the alert does is traced under `SENKU/rest` — the audio route, the
landing, whether the chime actually played, and when the session is released.
A crash shows as `App terminated due to signal 6`.

```sh
SIMCTL_CHILD_SENKU_SAMPLE=1 xcrun simctl launch booted pk.Senku
```

Seeding a profile from outside the app does not work: `defaults write` against
the container is discarded by the preference daemon, and `simctl spawn defaults
write` is refused by the sandbox. Use the sample data or the Quick calc screen.

## Packaging an .ipa

For sideloading with SideStore, AltStore or similar. An `.ipa` is a zip with the
app inside a folder called `Payload`, so no export step is needed — the sideloader
strips the signature and re-signs with your own Apple ID anyway.

```sh
cd Senku
xcodebuild -project Senku.xcodeproj -scheme Senku \
  -configuration Release -destination 'generic/platform=iOS' \
  -archivePath /tmp/Senku.xcarchive -allowProvisioningUpdates archive

mkdir -p /tmp/ipa/Payload
cp -R /tmp/Senku.xcarchive/Products/Applications/Senku.app /tmp/ipa/Payload/
cd /tmp/ipa && zip -qry <repo>/dist/Senku.ipa Payload
```

`dist/` is ignored by git. The package carries the widgets, the watch app and
the watch complication, all four bundles signed with `group.pk.Senku`.

Two things to check after a sideloaded install:

- **Empty widgets** mean the App Group did not survive re-signing. It is the only
  place Senku keeps data, so the app will look fine and everything around it will
  look blank.
- **A watch app that never updates.** Sideloaders have a patchy record with
  embedded WatchKit apps and may quietly drop it. Installing straight to the watch
  with `devicectl` bypasses that entirely — see above.

## Entitlements

`SENKU_ENTITLEMENTS` selects the entitlement file. `AppGroup` is the default;
`Free` exists for an Apple ID that will not issue the group.

**App Groups work on a free account**, verified on all four bundles:

```
Senku.app                ['group.pk.Senku']
SenkuWidgets.appex       ['group.pk.Senku']
SenkuWatch.app           ['group.pk.Senku']
SenkuWatchWidgets.appex  ['group.pk.Senku']
```

`SenkuStorage.migrateIfNeeded` carries a profile saved before the group into it.

**iCloud does not.** Adding `com.apple.developer.ubiquity-kvstore-identifier`
fails at signing with *"Personal development teams … do not support the iCloud
capability"*, which rules out `NSUbiquitousKeyValueStore`, CloudKit and
iCloud-backed SwiftData. Phone-to-watch sync therefore uses WatchConnectivity,
which needs no entitlement.

To verify an entitlement on a simulator build, use
`xcrun simctl get_app_container <device> pk.Senku groups`. `codesign -d
--entitlements` prints an empty dictionary for simulator builds even when the
entitlement is live.

## Project conventions

- The project uses Xcode 16+ **synchronized folders**: files inside
  `Senku/Senku/` join the target automatically. Screens belong in `SenkuUI`,
  where they build and test for both platforms at once.
- `SenkuWidgets` keeps its `Info.plist` **outside** the synchronized folder, at
  `SenkuWidgets-Info.plist`. A file inside the folder is also added to
  Resources, which collides with its own plist.
- WidgetKit needs `NSExtensionPointIdentifier` nested inside an `NSExtension`
  dictionary. `INFOPLIST_KEY_*` build settings only set top-level keys, so the
  plist must be a real file — otherwise the extension builds and never
  registers.
