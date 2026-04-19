# iLockin v0.1

A macOS discipline dashboard. Auto-launches at login, shows your time-blocked
day, GitHub overview, habits, and built-in trainers (typing, workout,
programming practice). Designed in a NothingOS-inspired aesthetic: pure black,
vibrant orange, glyph-style icons.

- **Bundle ID:** `com.rogue.ilockin`
- **Min macOS:** 14.0 (Sonoma)
- **Stack:** SwiftUI + SwiftData
- **Persistence:** SwiftData
- **Secrets:** macOS Keychain (GitHub PAT)
- **Network:** URLSession (Aladhan + GitHub REST v3)

## Quick start

```bash
cd iLockin
./setup.sh           # installs XcodeGen if missing, then generates iLockin.xcodeproj
open iLockin.xcodeproj
```

In Xcode:

1. Select the `iLockin` target → **Signing & Capabilities** → choose your Team.
2. Build & Run (⌘R). The Dashboard opens in a 1280×800 window.
3. The first launch automatically registers iLockin as a Login Item via
   `SMAppService.mainApp.register()` so the next time you sign in it opens
   itself. You can toggle this in **Settings**.

## Configure

Open **Settings** (gear icon top-right of the dashboard):

- **GitHub** – paste a Personal Access Token (`repo` scope is enough). Stored
  in the macOS Keychain. Optionally set a public username if you don't want to
  use a token.
- **Prayer Times** – defaults to Dhaka, Bangladesh, ISNA method. Fetched daily
  from `https://api.aladhan.com/v1/timingsByCity` and cached for 24 hours.
- **Schedule Blocks** – add/remove/reorder blocks and edit start times,
  durations, and categories. Auto-generated prayer blocks are read-only.
- **Walk / Night Study** – tweak the durations of the post-Maghrib walk and
  post-Isha study blocks (auto-injected after prayer fetch).
- **Reset to Default Schedule** – wipes your blocks and re-seeds the default
  template.

## Project structure

```
iLockin/
├── project.yml            # XcodeGen spec
├── setup.sh               # one-shot generator
└── iLockin/
    ├── iLockinApp.swift           # @main – SwiftData container + login-item bootstrap
    ├── iLockin.entitlements       # app sandbox + network client
    ├── Info.plist
    ├── Models/                    # SwiftData @Model types
    │   ├── Habit.swift
    │   ├── DailyBlock.swift
    │   ├── PrayerTimes.swift
    │   ├── GitHubRepo.swift       # also defines GitHubIssue
    │   ├── Streak.swift           # also defines TypingSession / WorkoutSession / ProgrammingSession
    │   └── AppSettings.swift
    ├── Services/
    │   ├── PrayerService.swift    # Aladhan client
    │   ├── GitHubService.swift    # REST v3 client
    │   ├── KeychainService.swift  # PAT storage
    │   └── LaunchAtLoginService.swift  # SMAppService.mainApp wrapper
    ├── ViewModels/
    │   ├── DashboardViewModel.swift   # clock tick, seeding, default schedule
    │   ├── PrayerViewModel.swift      # fetch + sync prayer-derived blocks
    │   └── GitHubViewModel.swift      # 24h cache + refresh
    ├── Views/
    │   ├── DashboardView.swift           # main login screen (60/40 split)
    │   ├── ScheduleView.swift            # left column – time-blocked cards
    │   ├── HabitListView.swift           # bottom-bar habit chips
    │   ├── GitHubPanelView.swift         # right column – repos + tasks
    │   ├── TypingTrainerView.swift       # 20-min trainer + history graph
    │   ├── WorkoutRoutineView.swift      # exercise checklist + timer
    │   ├── ProgrammingPracticeView.swift # timer + notes
    │   └── SettingsView.swift            # full config + schedule editor
    ├── Theme/
    │   └── Theme.swift                   # colors, fonts, ILCard, glyphs, buttons
    ├── Resources/
    │   └── DefaultSchedule.json
    └── Assets.xcassets/
        ├── Colors/
        │   ├── ilockinOrange.colorset    # #FF6B00
        │   ├── ilockinBlack.colorset     # #000000
        │   ├── ilockinDark.colorset      # #1B1B1D
        │   └── ilockinTextSecondary.colorset
        └── AppIcon.appiconset            # add your PNGs here (Contents.json prepared)
```

## Notes

- The app is sandboxed; networking is allowlisted to `api.aladhan.com` and
  `api.github.com`. Your PAT is stored in the keychain under
  service `com.rogue.ilockin`, account `github.pat`.
- `LSUIElement` is **false** (the app is a regular foreground app and shows
  in the Dock when launched).
- The dashboard uses a `.hiddenTitleBar` window. Resize from the corners as
  usual; min size is 1280×800.
- Tested target: macOS 14+.

## Troubleshooting

- **GitHub panel empty / "token missing"** – open Settings, paste a PAT, hit
  *Save & Refresh*. Or set a public username and skip the token.
- **No prayer times** – check internet connection or your city/country
  spelling (must match Aladhan's geocoder).
- **Auto-launch not triggering** – go to System Settings → General → Login
  Items and verify *iLockin* is listed and enabled, or toggle it from
  Settings inside the app.
