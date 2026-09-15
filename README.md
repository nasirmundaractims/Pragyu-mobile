# Pragyu Mobile

Separate Flutter workspace for Pragyu native apps. **Not** part of the website monorepo (`/var/www/html/Pragyu`).

Apps talk to the Pragyu backend only via HTTP API (`API_BASE_URL`).

## Structure

```text
Pragyu-Mobile/
  student/     # Student app
  faculty/     # (planned)
  parent/      # (planned)
```

## Toolchain (this machine)

```bash
source ~/development/pragyu-mobile-env.sh   # required once per terminal (also in ~/.bashrc)
flutter doctor -v
```

## Student app — quick start (Android)

```bash
source ~/development/pragyu-mobile-env.sh
cd /var/www/html/Pragyu-Mobile/student
flutter pub get
flutter emulators --launch Pragyu_API_34
flutter run
```

Full Android + iOS steps: see [`student/README.md`](student/README.md).

Website / web portals remain under `/var/www/html/Pragyu/apps/*-web`.
