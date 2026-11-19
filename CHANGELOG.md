# Changelog

`release.sh` turns the bullet list under each version into the release notes users see in the update window.

## 0.3.1

- Fixed: if your Mac was set to save screenshots to the clipboard, Preview or another app (⇧⌘5 → Options), they never reached Boardshot and the window stayed empty. Boardshot now saves them as files, and puts your choice back when you untick **Keep screenshots in Boardshot**.
- Turning Boardshot's screenshot folder on or off no longer restarts the menu bar, so screenshots keep working while it switches.

## 0.3.0

- A welcome window on first launch. Boardshot now asks before changing your screenshot settings, explains the two thumbnails so you can pick one, has you try a screenshot, and offers to open at login. See it again from Settings → Show Welcome Again.
- If you keep your current screenshot folder, the empty Boardshot window says so and offers to switch.
- Quitting Boardshot brings back the macOS thumbnail, so a screenshot taken while the app is closed no longer looks like it failed. Screenshots still go to `~/Pictures/Boardshot`. This also works if Boardshot crashes or is force quit.
- Ready for macOS 27, which is expected to read the screenshot folder from new settings.
- Fixed: with "Keep screenshots in Boardshot" off, each launch could reset a custom screenshot folder to the Desktop.

## 0.2.2

- ⌘A now selects every shot in the panel.

## 0.2.1

- Choose the thumbnail after capture (Settings → Screenshots): Boardshot's (file saved right away), the macOS one (with its Markup editor; the file arrives once the thumbnail goes away, and macOS may not show it for captures on a second display), or none.
- Opening a second copy of Boardshot now brings up the one already running instead of running both.

## 0.2.0

- New setting: turn off the larger preview that appears when you hover a shot (Settings → Panel).

## 0.1.2

- The installer window has an **Open Anyway** shortcut that jumps straight to System Settings → Privacy & Security.

## 0.1.1

- The installer window now shows how to install and what to do the first time macOS blocks the app.

## 0.1.0

- First beta release.
- Screenshots go to `~/Pictures/Boardshot`, with a quick panel to preview, drag, copy and delete them.
- Universal app for Apple Silicon and Intel, macOS 14 or later.
- Built-in updates.
