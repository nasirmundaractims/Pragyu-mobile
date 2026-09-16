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
    catalog/     # S-29
    calendar/    # S-30
    tests/       # S-40 … S-49
    alerts/      # S-50 / S-51
    ai_mentor/   # S-60
    weak_topics/ # S-61
    study_planner/ # S-62
    recommendations/ # S-63
    notes_bookmarks/ # S-64
    analytics/   # S-65
    exam_workspace/ # S-66
    exam_series/ # S-67
    attendance/  # S-68
    settings/    # S-71
    me/          # S-70
```

## Screens status

- **S-01…S-06** — auth entry complete
- **S-10 Home** — implemented
- **S-11 Today detail** — implemented
- **S-12 Quick search** — implemented (sheet: courses / tests / materials)
- **S-20 My learning** — implemented (Learn tab: enrolled courses)
- **S-21 Course detail** — implemented (modules, progress, Continue, Lectures, Materials)
- **S-22 Lesson player** — text + in-app media resources + mark complete
- **S-23 Lectures list** — implemented (live / upcoming / recorded)
- **S-24 Live lobby** — implemented (countdown, check-in / join)
- **S-25 Live room** — LiveKit media + chat + heartbeat
- **S-26 Recorded player** — in-app video player + progress posts
- **S-27 Study materials list** — implemented (course PDFs/notes)
- **S-28 Material viewer** — in-app PDF/video preview + open/copy
- **S-29 Catalog / browse** — marketplace catalog list + detail
- **S-30 Calendar** — implemented (14-day agenda: live classes + test deadlines)
- **S-40 Tests hub** — implemented (Tests tab: published assessments list + filters)
- **S-41 Assessment detail** — overview, results, entry to instructions
- **S-42 Attempt instructions** — timer/rules accept → starts attempt → S-43
- **S-43 Attempt player** — MCQ / T-F / short text, palette, autosave, timer
- **S-44 Submit confirm** — sheet: unanswered/marked review → finalize
- **S-45 Submission status** — poll processing / AI evaluating / ready → S-46
- **S-46 Result / feedback** — score, per-question breakdown, AI feedback
- **S-47 Deep feedback** — suggestions, AI rewrite / improved answer, model answer
- **S-48 Essay / media answers** — long subjective text, handwritten page upload, OCR-aware submit status
- **S-49 Past results hub** — attempts tracker + score reports (opens S-45 / S-46)
- **S-50 Alerts** — notification + engagement inbox, mark read / mark all, tab badge
- **S-51 Alert deep links** — tap alert → assessment / result / lesson / course / calendar / materials
- **S-60 AI Mentor** — coach chat (sessions + messages), weak-topic chips, Me + Home entry
- **S-61 Weak Topics** — mastery focus list (needs work / improving), Ask Mentor CTA, Me entry
- **S-62 Study Planner** — weekly plans, day sessions, goals, generate week, Me entry
- **S-63 Recommendations** — AI next actions, filters, save/dismiss, refresh generate, Me entry
- **S-64 Notes & Bookmarks** — notes CRUD, content bookmarks, AI feedback library, Me entry
- **S-65 My Performance** — analytics KPIs, AI insights, subject analysis, score trend, Me entry
- **S-66 Exam Workspace** — practice hub, readiness, pattern-aware assessments, Me entry
- **S-67 Question Bank** — exam series packs hub + detail (rank, Take test), Me entry
- **S-68 My Attendance** — rate, present/absent/late/excused, recent marks, Me entry
- **S-70 Me** — profile summary, email/study prefs, switch institute, sign out
- **S-71 Settings** — password, sessions, language/timezone, trusted devices, Me entry

## Troubleshooting

| Issue | Fix |
| --- | --- |
| `No space left on device` | Free disk (Gradle/Flutter caches under `~/.gradle`, `student/build`). Aim for **≥5 GB** free before `flutter build` / emulator. |
| Emulator slow / won’t start | Ensure KVM: `ls -l /dev/kvm`, then `sudo usermod -aG kvm $USER` and re-login. |
| API calls fail on emulator | Confirm API on `:8000` and `API_BASE_URL=http://10.0.2.2:8000/api/v1`. |
| Cleartext / network blocked | Android manifest allows cleartext for local hosts; rebuild after env changes. |
| Multiple `adb` warnings | Prefer SDK adb: `source ~/development/pragyu-mobile-env.sh` (uses `~/Android/Sdk/platform-tools`). |
