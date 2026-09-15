# Pragyu Student Mobile

Flutter app for Pragyu students (Android + iOS). Lives in the **Pragyu-Mobile** project (`/var/www/html/Pragyu-Mobile/student`), not the website monorepo. Uses the existing Pragyu backend/API.

## Application identity

| Platform | ID |
| --- | --- |
| Android `applicationId` | `com.pragyu.student` |
| iOS bundle ID | `com.pragyu.student` |
| Display name | Pragyu |

---

## 0. One-time environment (this Linux machine)

Flutter is installed at `~/development/flutter`, but it is **not** on PATH until you load the env script (also auto-loaded from `~/.bashrc` in new terminals):

```bash
source ~/development/pragyu-mobile-env.sh
which flutter   # should print .../development/flutter/bin/flutter
flutter doctor -v
```

Expected: Flutter ✓, Android toolchain ✓.  
**iOS ✗ on Linux** — needs a Mac (see below).

Installed for this machine:

- Flutter `3.47.x` at `~/development/flutter`
- JDK 17 at `~/development/jdk/...`
- Android SDK at `~/Android/Sdk`
- Emulator AVD: **`Pragyu_API_34`** (Android 14 / Google APIs x86_64)

Optional (faster emulator): add your user to the `kvm` group, then log out/in:

```bash
sudo usermod -aG kvm "$USER"
```

---

## 1. Backend API (required for sign-in)

The app calls Pragyu at `API_BASE_URL` from `assets/env/.env.development`.

Default for the **Android emulator**:

```text
API_BASE_URL=http://10.0.2.2:8000/api/v1
```

(`10.0.2.2` is the emulator’s alias for the host machine’s localhost.)

Start the Laravel API on the host (example):

```bash
cd /var/www/html/Pragyu
php artisan serve --host=0.0.0.0 --port=8000
```

**Physical Android phone on the same Wi‑Fi:** set `API_BASE_URL` to your PC’s LAN IP, e.g. `http://192.168.1.20:8000/api/v1`, then `flutter pub get` is not required for env assets (they are bundled as assets — rebuild/run after editing).

---

## 2. Run on Android (emulator)

```bash
source ~/development/pragyu-mobile-env.sh
cd /var/www/html/Pragyu-Mobile/student

flutter pub get

# Start the AVD (first boot can take a few minutes)
flutter emulators --launch Pragyu_API_34
# wait until `flutter devices` shows an android emulator

flutter devices
flutter run -d emulator-5554   # or the device id shown
```

Useful alternatives:

```bash
# Build only (no device)
flutter build apk --debug
# APK: build/app/outputs/flutter-apk/app-debug.apk

# Install on a USB phone (enable Developer options → USB debugging)
flutter devices
flutter run -d <device_id>
```

---

## 3. Run on iOS (macOS only)

This workspace is **Linux**, so iOS Simulator / Xcode builds **cannot** run here. On a Mac:

1. Install **Xcode** (App Store) + open once to accept license.
2. Install CocoaPods: `sudo gem install cocoapods` (or Homebrew `brew install cocoapods`).
3. Install Flutter and put it on `PATH` (same project via git/rsync).
4. Then:

```bash
cd /path/to/Pragyu-Mobile/student
flutter pub get
cd ios && pod install && cd ..
open -a Simulator
flutter devices
flutter run -d ios
```

Local API from the iOS Simulator usually uses the Mac’s localhost:

```bash
flutter run -d ios --dart-define=API_BASE_URL=http://127.0.0.1:8000/api/v1
```

`Info.plist` already allows local networking (`NSAllowsLocalNetworking`) for HTTP to a local API.

---

## Environments

| Env | Asset / override |
| --- | --- |
| Development | `assets/env/.env.development` |
| Staging | `assets/env/.env.staging` |
| Production | CI `--dart-define` / secure secrets (see `.env.production.example`) |

Examples:

```bash
flutter run --dart-define=APP_ENV=staging --dart-define=API_BASE_URL=https://staging.example/api/v1
```

Never commit production secrets.

## Architecture (foundation)

```text
lib/
  app/           # bootstrap, theme, router, shell
  core/          # config, network, session
  features/
    splash/      # S-01
    welcome/     # S-02
    auth/        # S-03 / S-04
    organization/# S-05
    onboarding/  # S-06
    home/        # S-10 / S-11
    search/      # S-12
    learn/       # S-20 / S-21 / S-22
    lectures/    # S-23 … S-26
    materials/   # S-27 / S-28
    calendar/    # S-30
```

## Screens status

- **S-01…S-06** — auth entry complete
- **S-10 Home** — implemented
- **S-11 Today detail** — implemented
- **S-12 Quick search** — implemented (sheet: courses / tests / materials)
- **S-20 My learning** — implemented (Learn tab: enrolled courses)
- **S-21 Course detail** — implemented (modules, progress, Continue, Lectures, Materials)
- **S-22 Lesson player** — implemented (text/HTML, resources, mark complete)
- **S-23 Lectures list** — implemented (live / upcoming / recorded)
- **S-24 Live lobby** — implemented (countdown, check-in / join)
- **S-25 Live room** — implemented (stub media, chat, heartbeat, leave)
- **S-26 Recorded player** — implemented (progress, playback link, mark complete)
- **S-27 Study materials list** — implemented (course PDFs/notes)
- **S-28 Material viewer** — implemented (open/copy link; library + lesson resource)
- **S-30 Calendar** — implemented (14-day agenda: live classes + test deadlines)
- **S-40 / S-50 / S-70** — tab placeholders only

## Troubleshooting

| Issue | Fix |
| --- | --- |
| `No space left on device` | Free disk (Gradle/Flutter caches under `~/.gradle`, `student/build`). Aim for **≥5 GB** free before `flutter build` / emulator. |
| Emulator slow / won’t start | Ensure KVM: `ls -l /dev/kvm`, then `sudo usermod -aG kvm $USER` and re-login. |
| API calls fail on emulator | Confirm API on `:8000` and `API_BASE_URL=http://10.0.2.2:8000/api/v1`. |
| Cleartext / network blocked | Android manifest allows cleartext for local hosts; rebuild after env changes. |
| Multiple `adb` warnings | Prefer SDK adb: `source ~/development/pragyu-mobile-env.sh` (uses `~/Android/Sdk/platform-tools`). |
