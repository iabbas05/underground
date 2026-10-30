#!/usr/bin/env bash
# Usage: tools/ci_build_ios.sh <src_dir: app|customer_app> <project_name> <bundle_id> <label> <out_ipa>
# Builds an UNSIGNED .ipa (for sideloading with Sideloadly / AltStore, or for signing later).
set -euo pipefail
SRC="$1"; NAME="$2"; APPID="$3"; LABEL="$4"; OUT="$5"
BUILD="${BUILD:-$(date +%y%m%d%H)}"
ROOT="$(pwd)"
rm -rf "build_$NAME"; mkdir -p "build_$NAME"; cd "build_$NAME"
flutter create --org com.underground --project-name "$NAME" --platforms ios "$NAME"
cd "$NAME"
cp "$ROOT/$SRC/pubspec.yaml" pubspec.yaml
rm -rf lib; cp -r "$ROOT/$SRC/lib" lib
echo "const int appBuild = $BUILD;" > lib/build_info.dart
PB=ios/Runner.xcodeproj/project.pbxproj
sed -i '' "s/PRODUCT_BUNDLE_IDENTIFIER = com.underground.$NAME;/PRODUCT_BUNDLE_IDENTIFIER = $APPID;/g" "$PB"
grep -n "PRODUCT_BUNDLE_IDENTIFIER" "$PB" || true
PL=ios/Runner/Info.plist
PBUDDY=/usr/libexec/PlistBuddy
$PBUDDY -c "Set :CFBundleDisplayName $LABEL" "$PL" || $PBUDDY -c "Add :CFBundleDisplayName string $LABEL" "$PL"
$PBUDDY -c "Set :CFBundleName $LABEL" "$PL" || true
$PBUDDY -c "Add :NSCameraUsageDescription string 'UNDERGROUND uses the camera to scan your pass QR code.'" "$PL" || true
$PBUDDY -c "Add :LSApplicationQueriesSchemes array" "$PL" || true
$PBUDDY -c "Add :LSApplicationQueriesSchemes:0 string tel" "$PL" || true
$PBUDDY -c "Add :LSApplicationQueriesSchemes:1 string https" "$PL" || true
mkdir -p "$ROOT/logs"
flutter pub get
flutter build ios --release --no-codesign 2>&1 | tee "$ROOT/logs/$NAME.ios.txt"
APP="build/ios/iphoneos/Runner.app"
test -d "$APP"
rm -rf Payload; mkdir Payload; cp -R "$APP" Payload/
mkdir -p "$ROOT/dist_ios"
zip -qry "$ROOT/dist_ios/$OUT" Payload
ls -l "$ROOT/dist_ios/$OUT"
