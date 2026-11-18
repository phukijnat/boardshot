# Contributing

Bug reports, ideas and pull requests are welcome. Please open an issue first for larger changes, so we can agree on the approach.

## Build

```bash
./build.sh            # build into build/
./build.sh --install  # also install to /Applications and relaunch
./build.sh --dmg      # also make dist/Boardshot-<version>.dmg
```

No Xcode project: `build.sh` calls `swiftc` directly and downloads the pinned Sparkle release into `vendor/` on first run. The app's name, bundle ID, version and update feed are in `config.sh`.

Note: running the app changes your screenshot location (see the README). Untick **Keep screenshots in Boardshot** in Settings to restore it.

## Code layout

| File | What it does |
|---|---|
| `Sources/main.swift` | App delegate, menu bar menu |
| `Sources/Panel.swift` | The screenshot panel |
| `Sources/ShotStore.swift` | Watches the screenshot folder |
| `Sources/Onboarding.swift` | First-launch window (asks before changing settings, thumbnail choice, try a screenshot) |
| `Sources/ExitGuard.swift` | Puts the macOS thumbnail back if Boardshot crashes or is force quit |
| `Sources/CornerThumb.swift` | Corner thumbnail after a capture |
| `Sources/ScreencaptureSettings.swift` | Reads/writes `com.apple.screencapture` and restores originals |
| `Sources/SettingsWindow.swift` | Settings window |
| `Sources/Prefs.swift` | Preferences and the `tr(thai, english)` helper |
| `Sources/Updater.swift` | Sparkle updates |

All UI text goes through `tr("ไทย", "English")`, so please add both languages.

## First-launch window

To check how a step looks without resetting your settings, run the built binary with a preview state. It changes no setting and prints the window number for `screencapture -l`:

```bash
BOARDSHOT_ONBOARDING_PREVIEW=thumbnail BOARDSHOT_PREVIEW_LANG=th build/Boardshot.app/Contents/MacOS/Boardshot
```

States: `welcome`, `confirm`, `thumbnail`, `try`, `try-done`, `done`, `done-declined`, `done-approval`. Add `BOARDSHOT_PREVIEW_DARK=1` for dark mode. To go through it for real, use **Settings → Show Welcome Again**.

## README demo GIF

`docs/demo.gif` is generated, not recorded. If you change how the panel looks, rebuild it and commit the new GIF:

```bash
./tools/demo/make_demo.sh
```

The panel in the clip is drawn by the real `Panel.swift`; the desktop, windows and cursor around it come from `tools/demo/main.swift`. Still frames for checking land in `build/demo/`.

## Making a release (maintainers)

Needs the update-signing key in your Keychain (account `boardshot`, made with `vendor/Sparkle/bin/generate_keys --account boardshot`). **Back it up**: `vendor/Sparkle/bin/generate_keys --account boardshot -x boardshot-key.txt`, store the file somewhere safe and offline, then delete it. If the key is lost, existing users can no longer receive updates.

1. Add a `## x.y.z` section to `CHANGELOG.md` and commit.
2. `./release.sh x.y.z` — sets the version, builds the dmg, signs it and adds it to `appcast.xml`.
3. Create the GitHub release `vx.y.z` and attach both `dist/Boardshot-x.y.z.dmg` and `dist/Boardshot.dmg` (the README download button points at `Boardshot.dmg` in the latest release) **before** pushing `appcast.xml`, so the update link works when the app sees it.
4. Commit, tag and push (the script prints the commands).

To try an update end to end without publishing: `./release.sh x.y.z --local`, then serve `build/local-feed` on port 8000. Builds made this way point at `http://localhost:8000`, so reinstall a normal build afterwards.
