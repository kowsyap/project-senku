# Creating the Xcode project

The packages hold everything real, so the Xcode targets are thin shells. This
only needs doing once.

Xcode has no command line for creating projects, so these steps are manual.

## 1. Create the app project

1. Xcode → **File ▸ New ▸ Project…**
2. **Multiplatform ▸ App**, then Next.
3. Product Name **Senku**, Interface **SwiftUI**, Language **Swift**,
   Storage **None**, Testing System **Swift Testing**.
4. Save it into this repository's root directory
   (`~/Documents/Projects/senku`). Uncheck "Create Git repository" — one
   already exists here.

## 2. Add the local packages

1. **File ▸ Add Package Dependencies…**
2. Click **Add Local…**, choose the `SenkuCore` folder, Add Package.
3. Repeat for the `SenkuUI` folder.
4. Select the **Senku** target ▸ **General** ▸ *Frameworks, Libraries, and
   Embedded Content*, and confirm both `SenkuCore` and `SenkuUI` are listed.

## 3. Replace the generated entry point

Xcode's template writes its own `SenkuApp.swift` and `ContentView.swift`.
Delete both, then drag `App/iOS/SenkuApp.swift` into the target.

That file is nine lines: it presents `RootView()` from `SenkuUI`.

## 4. Turn on Mac

Select the **Senku** target ▸ **General** ▸ *Supported Destinations* ▸ **+** ▸
**Mac (Mac Catalyst)**.

Build and run with the scheme set to *My Mac* to check it.

## 5. Add the watch app

1. **File ▸ New ▸ Target… ▸ watchOS ▸ App**, named **Senku Watch**.
2. Delete the generated `ContentView.swift` and app entry file.
3. Drag `App/Watch/SenkuWatchApp.swift` into the watch target.
4. Add `SenkuCore` and `SenkuUI` to that target's *Frameworks and Libraries*.

## 6. Signing

Select the project ▸ each target ▸ **Signing & Capabilities** ▸ set **Team** to
your Apple ID. A free account is enough to run on the simulator and your own
devices; a paid account is only needed to ship.

## What to commit

Commit `Senku.xcodeproj`. The `.gitignore` already excludes `xcuserdata/` and
build output, which are the parts that cause noise.

## Verifying without the project

The packages build and test on their own, which is worth keeping true:

```sh
cd SenkuCore && swift run senku verify && swift test
cd ../SenkuUI  && swift build
cd ../SenkuUI  && swift run senku-render /tmp/senku-shots
xcodebuild -scheme SenkuUI -destination 'generic/platform=iOS' build
xcodebuild -scheme SenkuUI -destination 'generic/platform=watchOS' build
```
