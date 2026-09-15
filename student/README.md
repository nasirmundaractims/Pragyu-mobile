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
  app/           # bootstrap, theme, router, shared widgets
  core/          # config, network
  features/
    splash/      # S-01
    welcome/     # S-02
    auth/        # S-03 Sign in, S-04 Forgot password
    organization/# S-05 Org picker + tenant storage
```

## Screens status

- **S-01 Splash** — implemented
- **S-02 Welcome** — implemented
- **S-03 Sign in** — implemented (`POST /auth/login`, MFA step, secure tokens)
- **S-04 Forgot password** — implemented (`POST /auth/forgot-password`)
- **S-05 Org picker** — implemented (`GET /organizations`, stores `X-Organization-Id`)
- **S-06 Onboarding tips** — not started (post-auth stub)

## iOS note

iOS project files are generated. Local simulator/build requires **macOS + Xcode**. On Linux, iOS verification is blocked by platform.
