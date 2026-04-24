# Lockin

**Lockin** is the home of **iLockin**, a macOS discipline dashboard: a time-blocked day view, GitHub overview, habits, prayer times, and built-in trainers (typing, workout, programming practice). The UI follows a Nothing-inspired palette—black, orange, and minimal chrome.

| | |
| --- | --- |
| **Platform** | macOS 14.0 (Sonoma) or later |
| **Stack** | SwiftUI, SwiftData, sandboxed app |
| **Bundle ID** | `com.rogue.ilockin` |

## Download

Installers are on **[GitHub Releases](https://github.com/Yuvraajrahman/Lockin/releases)**:

- **`iLockin-*-macos-universal.dmg`** — open the disk image, drag **iLockin** into **Applications**.
- **`iLockin-*-macos-universal.zip`** — unzip, move **iLockin.app** to **Applications** (or run in place).

CI builds are **ad-hoc signed**; the first launch may require **System Settings → Privacy & Security → Open Anyway**, or **Control-click → Open**. See **[RELEASES.md](RELEASES.md)** for details and maintainer steps.

To ship a release after changing version numbers in the project, push a **`v*`** tag; **[`.github/workflows/release-macos.yml`](.github/workflows/release-macos.yml)** builds and uploads the `.dmg` and `.zip` for that tag. Local dry run: `bash ./scripts/build-macos-release.sh` (outputs under `dist/`).

## Run from source

You need **Xcode** and (unless XcodeGen is already installed) **Homebrew** for the setup script.

```bash
cd iLockin
./setup.sh          # generates iLockin.xcodeproj via XcodeGen
open iLockin.xcodeproj
```

In Xcode: pick your **Team** under Signing for the `iLockin` target, then **Product → Run** (⌘R). See **[iLockin/README.md](iLockin/README.md)** for configuration (GitHub token, prayer times, schedule, login item) and troubleshooting.

## Repository layout

| Path | Purpose |
| --- | --- |
| [`iLockin/`](iLockin/) | macOS app (Swift), XcodeGen `project.yml`, `setup.sh` |
| [`scripts/build-macos-release.sh`](scripts/build-macos-release.sh) | Release **.zip** + **.dmg** (same script GitHub Actions uses) |
| [`web/`](web/) | Static marketing page (deploy on Vercel with **Root Directory** set to `web`) |
| [`RELEASES.md`](RELEASES.md) | Release download notes, changelog, and maintainer checklist |
| [`Notes.md`](Notes.md) | Project notes |

## Website

The [`web/`](web/) folder is a small static site. Connect this repo to [Vercel](https://vercel.com), set the project **Root Directory** to `web`, and deploy with no build command. Primary calls-to-action point at this repo and its Releases page.

## Contributing

Issues and pull requests are welcome on **[github.com/Yuvraajrahman/Lockin](https://github.com/Yuvraajrahman/Lockin)**.
