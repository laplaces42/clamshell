#!/bin/sh
# Builds ClamshellToggle.app into ./build (ad-hoc signed). Pass --install to copy it to ~/Applications.
set -e
cd "$(dirname "$0")/.."
swift build -c release
APP=build/ClamshellToggle.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp "$(swift build -c release --show-bin-path)/ClamshellToggle" "$APP/Contents/MacOS/"
cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleIdentifier</key><string>local.clamshelltoggle</string>
  <key>CFBundleName</key><string>ClamshellToggle</string>
  <key>CFBundleExecutable</key><string>ClamshellToggle</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>1.0</string>
  <key>LSMinimumSystemVersion</key><string>13.0</string>
  <key>LSUIElement</key><true/>
</dict></plist>
PLIST
codesign --force --sign - "$APP"
if [ "$1" = "--install" ]; then
  mkdir -p ~/Applications
  rm -rf ~/Applications/ClamshellToggle.app
  cp -R "$APP" ~/Applications/
  echo "Installed to ~/Applications/ClamshellToggle.app"
fi
echo "Built $APP"
