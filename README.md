# Boardshot

A small menu bar app that keeps your Mac screenshots in one place: take a shot with the usual keys, then find, preview, drag out or delete it from a quick panel.

[ภาษาไทย](README.th.md)

> **Beta.** Boardshot is new and still being tested. Things may break. Please [report bugs or ideas](https://github.com/phukijnat/boardshot/issues/new/choose).

<!-- TODO: add a screenshot or GIF of the panel: docs/screenshot.png -->

- Screenshots taken with the usual shortcuts (`⌘⇧3`, `⌘⇧4`, `⌘⇧5`) go to `~/Pictures/Boardshot` instead of the Desktop.
- The system's floating thumbnail is replaced by Boardshot's own, so the file is saved right away.
- Built-in updates: the app tells you when a new version is out and installs it for you.
- Thai and English UI.

Requires macOS 14 or later, on Apple Silicon or Intel.

## Install

1. Download the newest `Boardshot-x.y.z.dmg` from [Releases](https://github.com/phukijnat/boardshot/releases).
2. Open it and drag **Boardshot** into **Applications**.
3. Open Boardshot from Applications.

### "Apple could not verify Boardshot…"
Boardshot isn't notarized by Apple (that needs a paid developer account), so macOS blocks it the first time. You only need to do this once:

- **macOS 15 or later:** click **Done**, open **System Settings → Privacy & Security**, scroll down and click **Open Anyway** next to Boardshot, then confirm.
- **macOS 14:** right-click Boardshot in Applications, choose **Open**, then click **Open** again.

Updates installed from inside the app don't need this step again.

## How to use

| Action | How |
|---|---|
| Open / close the panel | `⇧⌘Space` (change it in Settings) or click the camera icon in the menu bar |
| Preview a shot larger | Hover over it |
| Select several | `⌘`-click, `⇧`-click, `⌘A`, or drag over empty space |
| Use a shot | Drag it into another app; the panel closes by itself |
| Copy | `⌘C` |
| Open in Preview | Double-click or `Return` |
| Move to Trash | `⌫` |
| Delete all | Trash button in the panel header (asks first) |
| Move the panel | Drag the header |
| Close | `Esc` or click elsewhere |

## Settings

Open from the menu bar icon → **Settings…**, the **⋯** button in the panel, or `⌘,` while the panel is open.

- Shortcut to open the panel (must include `⌘`, `⌃` or `⌥`)
- Language: Thai / English
- Keep screenshots in Boardshot: on / off
- Corner thumbnail after capture
- Open at login
- Show the menu bar icon
- Check for updates automatically, or **Check Now**

## What Boardshot changes on your Mac

To redirect screenshots, Boardshot changes two system settings (`com.apple.screencapture`: `location` and `show-thumbnail`). It remembers your original values and puts them back when you untick **Keep screenshots in Boardshot**. Quitting the app does not undo this.

## Uninstall

1. Settings… → untick **Keep screenshots in Boardshot**.
2. Quit Boardshot and move `/Applications/Boardshot.app` to the Trash.

If you already deleted the app, restore the macOS defaults with:

```bash
defaults delete com.apple.screencapture location; defaults delete com.apple.screencapture show-thumbnail; killall SystemUIServer
```

Your screenshots stay in `~/Pictures/Boardshot`.

## Build from source

Needs Xcode Command Line Tools (`xcode-select --install`).

```bash
./build.sh --install
```

This downloads Sparkle (the update framework) into `vendor/`, builds a universal app into `build/`, and installs it to `/Applications`. `./build.sh --dmg` also makes `dist/Boardshot-<version>.dmg`.

App name, bundle ID, version and update feed all live in [`config.sh`](config.sh). See [CONTRIBUTING.md](CONTRIBUTING.md) for how releases are made.

## License

[MIT](LICENSE)
