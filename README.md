<div align="center">
  <img src="Resources/AppIcon-preview.png" width="128" alt="Boardshot icon">
  <h1>Boardshot</h1>
  <p><strong>Your recent screenshots, one shortcut away.</strong></p>

  <a href="https://github.com/phukijnat/boardshot/releases/latest/download/Boardshot.dmg"><img src="https://img.shields.io/badge/Download_for_macOS-Boardshot.dmg-0A84FF?style=for-the-badge&logo=apple&logoColor=white" alt="Download Boardshot for macOS" height="44"></a>

  [![Latest version](https://img.shields.io/github/v/release/phukijnat/boardshot?include_prereleases&label=version)](https://github.com/phukijnat/boardshot/releases)
  ![macOS 14+](https://img.shields.io/badge/macOS-14%2B-blue)
  [![License: MIT](https://img.shields.io/github/license/phukijnat/boardshot)](LICENSE)

  English · [ภาษาไทย](README.th.md)
</div>

<p align="center"><img src="docs/demo.gif" width="800" alt="Take a screenshot, press Shift-Command-Space, drag it into a chat"></p>

Take a screenshot the way you always do, press `⇧⌘Space`, and drag it straight into Slack, Figma, a chat or an issue. No digging through Finder. Boardshot lives in your menu bar, keeps every shot in one folder, and keeps your Desktop clean as a bonus.

> [!NOTE]
> **Beta.** Boardshot is new and still being tested. Things may break. Please [report bugs or ideas](https://github.com/phukijnat/boardshot/issues/new/choose).

## Features

- **Quick panel.** `⇧⌘Space` opens every shot: hover to preview, drag into any app, copy, or trash.
- **Same shortcuts, tidy Desktop.** `⌘⇧3`, `⌘⇧4` and `⌘⇧5` save to `~/Pictures/Boardshot` instead of the Desktop.
- **Instant files.** Boardshot's own corner thumbnail replaces the system one, so the file is saved right away. Prefer the Mac's Markup editor? Switch back to the macOS thumbnail in Settings.
- **Undo anytime.** Your original screenshot settings are saved and put back with one checkbox.
- **Updates itself.** Tells you when a new version is out and installs it.
- **Private.** No account, no analytics. The only network request is the update check.
- Thai and English UI. Universal app for Apple Silicon and Intel, macOS 14 or later.

## Install

1. [Download **Boardshot.dmg**](https://github.com/phukijnat/boardshot/releases/latest/download/Boardshot.dmg) (always the newest version). Older versions are on the [Releases](https://github.com/phukijnat/boardshot/releases) page.
2. Open it and drag **Boardshot** into **Applications**.
3. Open Boardshot from Applications.
4. A welcome window asks before Boardshot changes any screenshot setting, lets you pick the thumbnail, has you try one screenshot, and offers to open Boardshot at login. You can see it again from **Settings → Show Welcome Again**.

### "Apple could not verify Boardshot…"
Boardshot isn't notarized by Apple (that needs a paid developer account), so macOS blocks it the first time. Click **Done**, not Move to Trash:

<img src="docs/first-launch-done.png" width="260" alt="The 'Boardshot Not Opened' dialog with Done circled">

Then, once:

- **macOS 15 or later:** click **Done**, then double-click **Open Anyway** in the installer window (or open **System Settings → Privacy & Security**), scroll down and click **Open Anyway** next to Boardshot, then confirm.
- **macOS 14:** right-click Boardshot in Applications, choose **Open**, then click **Open** again.

Updates installed from inside the app don't need this step again.

## How to use

| Action | How |
|---|---|
| Open / close the panel | `⇧⌘Space` (change it in Settings) or click the camera icon in the menu bar |
| Preview a shot larger | Hover over it (can be turned off in Settings) |
| Select several | `⌘`-click, `⇧`-click, `⌘A`, or drag over empty space |
| Use a shot | Drag it into another app; the panel closes by itself |
| Copy | `⌘C` |
| Open in Preview | Double-click or `Return` |
| Move to Trash | `⌫` |
| Delete all | Trash button in the panel header (asks first) |
| Move the panel | Drag the header |
| Close | `Esc` or click elsewhere |

## Settings

Open from the menu bar icon → **Settings…**, the gear button in the panel, or `⌘,` while the panel is open.

- Shortcut to open the panel (must include `⌘`, `⌃` or `⌥`)
- Language: Thai / English
- Keep screenshots in Boardshot: on / off
- Thumbnail after capture: Boardshot's (instant file), macOS (Markup editor; the file arrives once the thumbnail goes away, and it may not appear on a second display), or none
- Larger preview when hovering a shot
- Open at login
- Show the menu bar icon
- Check for updates automatically, or **Check Now**
- **Show Welcome Again**: the first-launch window

## What Boardshot changes on your Mac

Only after you agree in the welcome window (or tick **Keep screenshots in Boardshot**), Boardshot changes system settings in `com.apple.screencapture`: the save folder (`location`, plus `location-screenshot` and `location-screenrecording`, which macOS 27 is expected to use), where captures are saved (`target`, `target-screenshot` and `target-screenrecording` set to a file, since Boardshot can't see captures sent to the clipboard or Preview) and `show-thumbnail`. Nothing is restarted, so screenshots keep working while this happens. It remembers your original values and puts them back when you untick **Keep screenshots in Boardshot**. Quitting the app, or the app crashing, puts them all back too, so while Boardshot is closed your Mac saves screenshots the way it did before; opening Boardshot again switches back to `~/Pictures/Boardshot`.

## FAQ

**Does it move the screenshots already on my Desktop?**
No. Only new screenshots go to `~/Pictures/Boardshot`. Move old ones there yourself if you want them in the panel.

**I already save screenshots to a custom folder. What happens to that setting?**
Boardshot remembers it and puts it back when you untick **Keep screenshots in Boardshot**.

**Does Boardshot send anything over the internet?**
Only the update check, which reads [`appcast.xml`](appcast.xml) from this repo. You can turn automatic checks off in Settings.

**Why isn't it notarized?**
Notarization needs a paid Apple developer account. The app is open source and you can [build it yourself](#build-from-source).

## Uninstall

1. Quit Boardshot (this puts your screenshot settings back).
2. Move `/Applications/Boardshot.app` to the Trash.

If you already deleted the app, restore the macOS defaults with:

```bash
for k in location location-screenshot location-screenrecording target target-screenshot target-screenrecording show-thumbnail; do defaults delete com.apple.screencapture $k; done
```

Your screenshots stay in `~/Pictures/Boardshot`.

## Build from source

Needs Xcode Command Line Tools (`xcode-select --install`).

```bash
./build.sh --install
```

This downloads Sparkle (the update framework) into `vendor/`, builds a universal app into `build/`, and installs it to `/Applications`. `./build.sh --dmg` also makes `dist/Boardshot-<version>.dmg`.

App name, bundle ID, version and update feed all live in [`config.sh`](config.sh). See [CONTRIBUTING.md](CONTRIBUTING.md) for how releases are made.

## Feedback & contributing

Found a bug or have an idea? [Open an issue](https://github.com/phukijnat/boardshot/issues/new/choose). Pull requests are welcome too; [CONTRIBUTING.md](CONTRIBUTING.md) explains how the project is built and released.

If Boardshot makes sharing screenshots feel instant, a ⭐ on the repo helps other people find it.

## Acknowledgements

- [Sparkle](https://sparkle-project.org) for in-app updates.

## License

Boardshot is free and open source under the [MIT License](LICENSE). © 2026 phukijnat
