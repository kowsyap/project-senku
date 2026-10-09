#!/bin/sh
# Builds dist/Senku.ipa and dist/Senku-sidestore.ipa for sideloading.
#
# The archive is built unsigned — the sideloader re-signs with your own Apple
# ID — and then every bundle is signed ad hoc with its own entitlements. That
# second step is the point: SideStore and AltStore copy the entitlements they
# find in the app when they re-sign it, and an unsigned app carries none. Without
# it the installed app has no HealthKit (Apple Health cannot be switched on) and
# no App Group (the widgets and the watch see nothing).
#
#     sh Senku/make_ipas.sh            # from the repository root
set -eu

REPO=$(cd "$(dirname "$0")/.." && pwd)
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

cd "$REPO/Senku"
xcodebuild -project Senku.xcodeproj -scheme Senku -configuration Release \
  -destination 'generic/platform=iOS' -archivePath "$WORK/Senku.xcarchive" \
  -derivedDataPath "$WORK/dd" CODE_SIGNING_ALLOWED=NO archive \
  | grep -E "error:|ARCHIVE (SUCCEEDED|FAILED)" || true
test -d "$WORK/Senku.xcarchive/Products/Applications/Senku.app"

# Inside out: a bundle's signature covers what is inside it, so the innermost
# are signed first.
sign() {
  codesign --force --sign - --timestamp=none --generate-entitlement-der \
    --entitlements "$REPO/Senku/$2" "$1"
}

package() {
  name=$1 keep_watch=$2
  rm -rf "$WORK/ipa" && mkdir -p "$WORK/ipa/Payload"
  cp -R "$WORK/Senku.xcarchive/Products/Applications/Senku.app" "$WORK/ipa/Payload/"
  app="$WORK/ipa/Payload/Senku.app"
  if [ "$keep_watch" = yes ]; then
    sign "$app/Watch/SenkuWatch.app/PlugIns/SenkuWatchWidgets.appex" SenkuWatchWidgets-AppGroup.entitlements
    sign "$app/Watch/SenkuWatch.app" SenkuWatch-AppGroup.entitlements
  else
    rm -rf "$app/Watch"
  fi
  sign "$app/PlugIns/SenkuWidgets.appex" SenkuWidgets-AppGroup.entitlements
  sign "$app" Senku-AppGroup.entitlements
  rm -f "$REPO/dist/$name"
  (cd "$WORK/ipa" && zip -qry "$REPO/dist/$name" Payload)
  echo "$name: $(du -h "$REPO/dist/$name" | cut -f1)"
}

mkdir -p "$REPO/dist"
package Senku.ipa yes
package Senku-sidestore.ipa no
