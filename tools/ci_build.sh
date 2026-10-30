#!/usr/bin/env bash
# Usage: tools/ci_build.sh <src_dir: app|customer_app> <project_name> <application_id> <label> <out_apk>
set -euo pipefail
SRC="$1"; NAME="$2"; APPID="$3"; LABEL="$4"; OUT="$5"; VJ="${6:-version.json}"
BUILD="${BUILD:-$(date +%y%m%d%H)}"
ROOT="$(pwd)"
rm -rf "build_$NAME"; mkdir -p "build_$NAME"; cd "build_$NAME"
flutter create --org com.underground --project-name "$NAME" "$NAME"
cd "$NAME"
cp "$ROOT/$SRC/pubspec.yaml" pubspec.yaml
rm -rf lib; cp -r "$ROOT/$SRC/lib" lib
UG_KEYSTORE="$ROOT/tools/ug.keystore" python3 - "$APPID" "$LABEL" <<'PY'
import re, sys, glob, os
appid, label = sys.argv[1], sys.argv[2]
for f in glob.glob('android/app/build.gradle*'):
    s = open(f).read()
    s = re.sub(r'(applicationId\s*=?\s*)"[^"]*"', lambda m: m.group(1) + '"' + appid + '"', s)
    # AGP9 template: drop the kotlin { compilerOptions { jvmTarget } } block that fails to resolve
    s = re.sub(r'\nkotlin\s*\{[^{}]*(\{[^{}]*\}[^{}]*)*\}\s*', '\n', s)
    # Sign every build with the same key so a new APK can update the one already installed (and in-app updates work)
    ks = os.environ['UG_KEYSTORE']
    if f.endswith('.kts'):
        block = 'signingConfigs {\n        getByName("debug") {\n            storeFile = file("' + ks + '")\n            storePassword = "ugunderground"\n            keyAlias = "ug"\n            keyPassword = "ugunderground"\n        }\n    }\n    '
    else:
        block = 'signingConfigs {\n        debug {\n            storeFile file("' + ks + '")\n            storePassword "ugunderground"\n            keyAlias "ug"\n            keyPassword "ugunderground"\n        }\n    }\n    '
    s = re.sub(r'(\nandroid\s*\{\n)', lambda m: m.group(1) + '    ' + block, s, count=1)
    assert 'storeFile' in s, 'could not add the signing key to ' + f
    # ota_update (in-app install) needs core library desugaring
    kts = f.endswith('.kts')
    flag = 'isCoreLibraryDesugaringEnabled = true' if kts else 'coreLibraryDesugaringEnabled true'
    dep = 'coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")' if kts else "coreLibraryDesugaring 'com.android.tools:desugar_jdk_libs:2.1.4'"
    if re.search(r'compileOptions\s*\{', s):
        s = re.sub(r'(compileOptions\s*\{)', lambda m: m.group(1) + '\n        ' + flag, s, count=1)
    else:
        s = re.sub(r'(\nandroid\s*\{\n)', lambda m: m.group(1) + '    compileOptions {\n        ' + flag + '\n    }\n', s, count=1)
    if re.search(r'\ndependencies\s*\{', s):
        s = re.sub(r'(\ndependencies\s*\{)', lambda m: m.group(1) + '\n    ' + dep, s, count=1)
    else:
        s += '\ndependencies {\n    ' + dep + '\n}\n'
    assert 'esugar' in s, 'could not enable desugaring in ' + f
    open(f, 'w').write(s)
m = 'android/app/src/main/AndroidManifest.xml'
s = open(m).read()
s = re.sub(r'android:label="[^"]*"', 'android:label="' + label + '"', s, count=1)
for perm in ('INTERNET', 'CAMERA', 'REQUEST_INSTALL_PACKAGES'):
    if 'android.permission.' + perm not in s:
        s = re.sub(r'(<manifest[^>]*>)', lambda m: m.group(1) + '\n    <uses-permission android:name="android.permission.' + perm + '"/>', s, count=1)
meta = '<meta-data android:name="io.flutter.embedding.android.EnableImpeller" android:value="false"/>'
if 'EnableImpeller' not in s:
    s = s.replace('</application>', '    ' + meta + '\n    </application>')
open(m, 'w').write(s)
PY
grep -n "applicationId\|storeFile" android/app/build.gradle* || true
echo "const int appBuild = $BUILD;" > lib/build_info.dart
mkdir -p "$ROOT/logs"
flutter pub get
flutter analyze --no-fatal-infos --no-fatal-warnings > "$ROOT/logs/$NAME.analyze.txt" 2>&1 || true
flutter build apk --release 2>&1 | tee "$ROOT/logs/$NAME.build.txt"
mkdir -p "$ROOT/dist"
cp build/app/outputs/flutter-apk/app-release.apk "$ROOT/dist/$OUT"
echo "{\"build\":$BUILD,\"notes\":\"${NOTES:-}\"}" > "$ROOT/dist/$VJ"
echo "PACKAGE ID: $APPID  ->  dist/$OUT"
