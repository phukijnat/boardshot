# Changelog

`release.sh` turns the bullet list under each version into the release notes users see in the update window.

## 0.4.1

- Fixed: ⇧-clicking a screenshot in the Boardshot window added just that one, like ⌘-click. It now selects every screenshot from the one you last clicked to the one you ⇧-click, like in Finder.

## 0.4.0

- The corner thumbnail now does what the Mac's does. Click a screenshot to mark it up in the Mac's Markup (Done saves over the file), or click a screen recording to trim it.
- Right-click the corner thumbnail for the Mac's usual choices: save a copy to the Desktop, Documents or clipboard, open in Mail, Messages, Preview or Photos, show in Finder, or delete.
- Screenshots your Mac left in your old screenshot folder (usually the Desktop), for example ones taken while Boardshot was closed, can now be brought in: the Boardshot window shows "Import N from Desktop" when there are any, and the welcome window offers it too. Only files your Mac made by capturing the screen are moved.

## 0.3.3

- Quitting Boardshot now puts all your screenshot settings back, not only the thumbnail: screenshots taken while the app is closed go to your old folder (the Desktop by default), so you can tell Boardshot isn't running. Opening it again switches back to ~/Pictures/Boardshot. This also works if Boardshot crashes or is force quit.
- Fixed: hovering a screen recording showed only a file icon. The large preview now plays the video, muted and on a loop.

## 0.3.2

- The gear button in the Boardshot window opens Settings straight away, instead of a menu that repeated the folder button and Quit (still on ⌘Q and in Settings).

## 0.3.1

- Fixed: if your Mac was set to save screenshots to the clipboard, Preview or another app (⇧⌘5 → Options), they never reached Boardshot and the window stayed empty. Boardshot now saves them as files, and puts your choice back when you untick “Keep screenshots in Boardshot”.
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
