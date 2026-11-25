#!/bin/bash
# Crée build/Unarchiever.app avec Vendor/7zz embarqué.
set -euo pipefail
cd "$(dirname "$0")"

APP=build/Unarchiever.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
swiftc -O -swift-version 5 -parse-as-library -target "$(uname -m)-apple-macos13" Sources/*.swift -o "$APP/Contents/MacOS/Unarchiever"
cp Vendor/7zz "$APP/Contents/MacOS/7zz"
cp Vendor/7zz-License.txt "$APP/Contents/Resources/"
cp Resources/Info.plist "$APP/Contents/"
xattr -cr "$APP"  # codesign refuse les attributs étendus
codesign --force --sign - "$APP/Contents/MacOS/7zz"
codesign --force --sign - "$APP"
echo "OK : $APP"
