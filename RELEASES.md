# Releases

**Download:** [github.com/Yuvraajrahman/Lockin/releases](https://github.com/Yuvraajrahman/Lockin/releases)

Each GitHub Release ships two **universal** (Apple Silicon + Intel) artifacts built from `main`:

| File | What it is |
| --- | --- |
| `iLockin-*-macos-universal.dmg` | Disk image — open it, drag **iLockin** into **Applications**. |
| `iLockin-*-macos-universal.zip` | Zipped `.app` — unzip, then drag **iLockin.app** into **Applications** (or run from anywhere). |

**Requirements:** macOS **14.0** (Sonoma) or later.

---

## First launch (ad-hoc / CI builds)

GitHub Actions builds use **ad-hoc code signing** so anyone can install without the maintainer’s Apple Developer certificate. On first open, macOS may block the app or show an “unidentified developer” warning.

1. **System Settings → Privacy & Security** — if macOS blocked the app, choose **Open Anyway** after you tried to open it once.  
2. Or **Control-click (right-click) iLockin → Open → Open** the first time.

For a smoother experience without that step, the maintainer can archive with a **Developer ID** certificate, **notarize** with Apple, and replace the CI assets (or add a second workflow) — that is optional and requires a paid Apple Developer account.

---

## For maintainers: publish a new version

1. **Bump versions** in [`iLockin/project.yml`](iLockin/project.yml) (`CFBundleShortVersionString` / `CFBundleVersion`) and in [`iLockin/iLockin/Info.plist`](iLockin/iLockin/Info.plist) if it does not track `project.yml` for those keys — keep them in sync with the tag you are about to ship.
2. **Commit and push** to `main`.
3. **Create and push an annotated tag** (example for `0.1`):

   ```bash
   git tag -a v0.1 -m "iLockin 0.1"
   git push origin v0.1
   ```

4. The workflow **[macOS release](.github/workflows/release-macos.yml)** runs on every `v*` tag, runs [`scripts/build-macos-release.sh`](scripts/build-macos-release.sh), and attaches the `.zip` and `.dmg` to the GitHub Release for that tag.

**Repo setting:** *Settings → Actions → General → Workflow permissions* should allow **Read and write** so `GITHUB_TOKEN` can upload release assets.

**Local dry run** (same artifacts as CI):

```bash
bash ./scripts/build-macos-release.sh
ls -lh dist/
```

---

## Changelog

### 0.1

- Initial public release pipeline: universal **Release** `.app`, **DMG**, and **ZIP** on GitHub Releases.
- macOS discipline dashboard: schedule blocks, habits, GitHub panel (token or public user), prayer times (Aladhan), trainers (typing, workout, programming practice), optional launch at login (`SMAppService`).
- SwiftUI + SwiftData; sandboxed; PAT in Keychain when used.
