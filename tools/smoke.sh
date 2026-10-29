#!/usr/bin/env bash
# Runs on an Android emulator in CI: installs each APK, launches it, reports whether it survived and prints the crash log.
mkdir -p smoke
for pair in "UNDERGROUND-Staff.apk:com.underground.staff" "UNDERGROUND-Member.apk:com.underground.member"; do
  apk="${pair%%:*}"; pkg="${pair##*:}"
  echo "=================== $pkg ==================="
  adb install -r "dist/$apk" || echo "INSTALL FAILED"
  adb logcat -c
  adb shell monkey -p "$pkg" -c android.intent.category.LAUNCHER 1
  sleep 20
  if adb shell pidof "$pkg" >/dev/null; then echo "RESULT $pkg: RUNNING after 20s (no crash)"; else echo "RESULT $pkg: CRASHED / NOT RUNNING"; fi
  adb exec-out screencap -p > "smoke/$pkg.png" || true
  adb logcat -d -b main,crash,system | grep -E "AndroidRuntime|FATAL|Fatal signal|flutter|libflutter|$pkg|UnsatisfiedLink|ClassNotFound|SecurityException" | head -120 | tee "smoke/$pkg.log"
done
exit 0
