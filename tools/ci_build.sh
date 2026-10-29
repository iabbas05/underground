#!/usr/bin/env bash
# Usage: tools/ci_build.sh <src_dir: app|customer_app> <project_name> <application_id> <label> <out_apk>
set -euo pipefail
SRC="$1"; NAME="$2"; APPID="$3"; LABEL="$4"; OUT="$5"
ROOT="$(pwd)"
rm -rf "build_$NAME"; mkdir -p "build_$NAME"; cd "build_$NAME"
flutter create --org com.underground --project-name "$NAME" "$NAME"
cd "$NAME"
cp "$ROOT/$SRC/pubspec.yaml" pubspec.yaml
rm -rf lib; cp -r "$ROOT/$SRC/lib" lib
python3 - "$APPID" "$LABEL" <<'PY'
import re, sys, glob
appid, label = sys.argv[1], sys.argv[2]
for f in glob.glob('android/app/build.gradle*'):
    s = open(f).read()
    s = re.sub(r'(applicationId\s*=?\s*)"[^"]*"', lambda m: m.group(1) + '"' + appid + '"', s)
    # AGP9 template: drop the kotlin { compilerOptions { jvmTarget } } block that fails to resolve
    s = re.sub(r'\nkotlin\s*\{[^{}]*(\{[^{}]*\}[^{}]*)*\}\s*', '\n', s)
    open(f, 'w').write(s)
m = 'android/app/src/main/AndroidManifest.xml'
s = open(m).read()
s = re.sub(r'android:label="[^"]*"', 'android:label="' + label + '"', s, count=1)
meta = '<meta-data android:name="io.flutter.embedding.android.EnableImpeller" android:value="false"/>'
if 'EnableImpeller' not in s:
    s = s.replace('</application>', '    ' + meta + '\n    </application>')
open(m, 'w').write(s)
PY
grep -n "applicationId" android/app/build.gradle* || true
flutter pub get
flutter build apk --release
mkdir -p "$ROOT/dist"
cp build/app/outputs/flutter-apk/app-release.apk "$ROOT/dist/$OUT"
echo "PACKAGE ID: $APPID  ->  dist/$OUT"
