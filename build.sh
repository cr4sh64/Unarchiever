#!/bin/bash
# Crée build/Unarchiever.app avec Vendor/7zz embarqué.
set -euo pipefail
cd "$(dirname "$0")"

APP=build/Unarchiever.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
swiftc -O -swift-version 5 -parse-as-library -target "$(uname -m)-apple-macos13" Sources/*.swift -o "$APP/Contents/MacOS/Unarchiever"
cp Vendor/7zz "$APP/Contents/MacOS/7zz"
# Icône : dessinée par Resources/icon.swift, déclinée aux tailles d'un .icns.
ICONSET=build/AppIcon.iconset
rm -rf "$ICONSET" && mkdir -p "$ICONSET"
swift Resources/icon.swift build/icon.png
for s in 16 32 128 256 512; do
  sips -z $s $s build/icon.png --out "$ICONSET/icon_${s}x${s}.png" >/dev/null
  sips -z $((s * 2)) $((s * 2)) build/icon.png --out "$ICONSET/icon_${s}x${s}@2x.png" >/dev/null
done
iconutil -c icns "$ICONSET" -o "$APP/Contents/Resources/AppIcon.icns"
cp Vendor/7zz-License.txt "$APP/Contents/Resources/"
cp Resources/Info.plist "$APP/Contents/"
xattr -cr "$APP"  # codesign refuse les attributs étendus
codesign --force --sign - "$APP/Contents/MacOS/7zz"
codesign --force --sign - "$APP"
echo "OK : $APP"
