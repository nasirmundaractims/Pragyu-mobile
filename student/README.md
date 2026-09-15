# Pragyu Student Mobile

Flutter app for Pragyu students (Android + iOS). Lives in the **Pragyu-Mobile** project (`/var/www/html/Pragyu-Mobile/student`), not the website monorepo. Uses the existing Pragyu backend/API.

## Application identity (proposed)

| Platform | ID |
| --- | --- |
| Android `applicationId` | `com.pragyu.student` |
| iOS bundle ID | `com.pragyu.student` |
| Display name | Pragyu |

## Local toolchain (this machine)

```bash
source ~/development/pragyu-mobile-env.sh
flutter doctor -v
```

## Run (Android)

```bash
cd /var/www/html/Pragyu-Mobile/student
flutter pub get
flutter run            # requires emulator/device
# or verify compile:
flutter build apk --debug
```

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
    home/        # S-10
```

## Screens status

- **S-01…S-06** — auth entry complete
- **S-10 Home** — implemented (greeting, live/next class, due tests, unread strip, shortcuts + bottom tabs)
- **S-20 / S-40 / S-50 / S-70** — tab placeholders only

## iOS note

iOS project files are generated. Local simulator/build requires **macOS + Xcode**. On Linux, iOS verification is blocked by platform.
