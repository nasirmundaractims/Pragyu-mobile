# Pragyu Mobile

Separate Flutter workspace for Pragyu native apps. **Not** part of the website monorepo (`/var/www/html/Pragyu`).

Apps talk to the Pragyu backend only via HTTP API (`API_BASE_URL`).

## Structure

```text
Pragyu-Mobile/
  student/     # Student app (Android + iOS) — S-01…S-04 done
  faculty/     # (planned)
  parent/      # (planned)
```

## Toolchain (this machine)

```bash
source ~/development/pragyu-mobile-env.sh
flutter doctor -v
```

## Student app

```bash
cd /var/www/html/Pragyu-Mobile/student
flutter pub get
flutter test
flutter build apk --debug   # or: flutter run
```

Website / web portals remain under `/var/www/html/Pragyu/apps/*-web`.
