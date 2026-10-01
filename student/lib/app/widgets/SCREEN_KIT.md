# Student App — Shared Screen Kit (Phase 4.1)

Canonical visual building blocks for secondary routes and (later) hub
refactors. Source of truth for look: remapped **Home / Learn / Practice /
AI Eval** chrome + `StudentHubColors`.

## Import

```dart
import 'package:student_mobile/app/widgets/student_screen_kit.dart';
```

## Components

| Widget | Use for |
| --- | --- |
| `StudentHubPage` + `StudentAppHeader` | Secondary route scaffold (back + title + body) |
| `StudentSectionHeader` | Section titles (`Recent marks`, `Upcoming`, …); optional trailing action |
| `AppLoadingState` | Full-body / list loading spinner (`scrollable: true` under `RefreshIndicator`) |
| `AppEmptyState` | Empty lists / capability gates (icon + title + message + optional CTA) |
| `AppErrorState` | Load failures (optional title + message + **Try again**) |
| `PrimaryButton` / `SecondaryButton` | Full-width primary / outline CTAs |
| `StudentHubColors` | Ink / muted / blue / pageBg / border / `cardRadius` |

## Do / don’t

- **Do** use kit widgets on new or touched secondary screens (Me, Settings,
  Help, Attendance, Calendar, Payments, Tutorials, …).
- **Do** keep hub private `_TopBar` / custom cards until a dedicated slice
  migrates that hub (4.2–4.4).
- **Don’t** invent a new empty/error/loading layout when the kit covers it.
- **Don’t** introduce a second palette — prefer `StudentHubColors` over
  legacy `AppColors` navy tokens on polished screens.

## Migration order (later slices)

1. ~~**4.2** Me + Settings + Help~~ ✅ (+ Notification preferences)
2. ~~**4.3** Practice + Exam Series + Workspace~~ ✅
3. ~~**4.4** Attendance, Calendar, Planner, Performance, Weak Topics,
   Announcements, Payments, Tutorials~~ ✅
4. ~~**4.5** Auth + Org association~~ ✅

Already on kit / hub palette: secondary hubs above plus **Sign-in**,
**Register**, **Forgot/Reset/Verify**, **Org picker**, **Org code**,
**Org association**.
