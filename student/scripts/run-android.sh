#!/usr/bin/env bash
# Helper: run Pragyu Student app on a connected Android device/emulator.
set -euo pipefail

# shellcheck source=/dev/null
source "$HOME/development/pragyu-mobile-env.sh"

cd "$(dirname "$0")/.."

echo "==> Flutter: $(command -v flutter)"
flutter devices

if ! flutter devices 2>/dev/null | grep -qiE 'android|emulator-[0-9]+|sdk gphone|Pixel'; then
  cat <<'EOF'

No Android device detected.

This Linux host's Android emulator currently crashes on startup
(SIGSEGV in emulator libandroid-webrtc / tcmalloc — known tooling issue).

Use one of these:

1) Physical phone (recommended)
   - Enable Developer options → USB debugging
   - Plug in USB, accept the RSA prompt on the phone
   - Set API URL to your PC LAN IP in assets/env/.env.development, e.g.
       API_BASE_URL=http://192.168.1.20:8000/api/v1
   - Then:  adb devices && flutter run

2) Linux desktop (optional UI-only check)
   Install once:
     sudo apt-get install -y clang cmake ninja-build pkg-config libgtk-3-dev
   Then:
     flutter run -d linux --dart-define=API_BASE_URL=http://127.0.0.1:8000/api/v1

3) Fix emulator later
   Try after: sudo apt-get install -y libtcmalloc-minimal4
   and:     sudo usermod -aG kvm "$USER"   # then log out/in
   Then:    flutter emulators --launch Pragyu_API_34 && flutter run

EOF
  exit 1
fi

flutter pub get
flutter run "$@"
