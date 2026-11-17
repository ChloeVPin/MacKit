# Capture brief: real macOS previews for MacKit

You are capturing real screenshots and short screen recordings of macOS settings on a clean macOS virtual machine. They will ship inside a Mac app called MacKit, where each setting has a preview that swaps as the user flips a control. Every capture must be the real operating system, never a mockup or an edited image.

Work through this brief top to bottom. Where a step can't be done, skip it, record why in the manifest, and keep going. A missing capture is fine. A wrong or faked one is not.

## 1. Rules

1. **Real only.** Do not draw, composite, retouch, or generate anything. Cropping and scaling are the only edits allowed.
2. **One variable at a time.** Within one setting, the captures for each option must be identical except for the effect of that setting: same window size and position, same files, same selection, same pointer position.
3. **Nothing personal on screen.** No Apple ID, no real names, no notifications, no other apps. If the VM's user name is not generic, say so in the manifest.
4. **Verify before you save.** After each capture, look at it and confirm the difference between options is actually visible. If the setting made no visible difference, do not save a pair that looks identical. Record it as "no visible effect" in the manifest.
5. **Change settings only with the commands in this brief**, then restart the named process. Do not change anything else.

## 2. Prepare the VM once

- Appearance: **Light**. Accent and highlight color: default. Wallpaper: the macOS default.
- Display: 1440×900 points, Retina (2x) if the VM supports it. Use the same resolution for every capture.
- Dock: default apps, default size, at the bottom, not hidden.
- Desktop: no icons, no open windows. Turn on Do Not Disturb.
- Quit every app except Finder before each capture session.
- Install nothing except what a step asks for.

Record in the manifest: macOS version and build, display resolution and scale, and the VM user's short name.

### Sample files

Run this once. It builds the folder every Finder capture uses.

```bash
mkdir -p ~/Documents/Studio/Archive ~/Documents/Studio/Projects/Website
cd ~/Documents/Studio
printf 'Things to do\n' > Notes.txt
printf 'item,cost\nrent,1200\n' > Budget.csv
printf '# Plan\n' > Plan.md
printf '# Report draft\n' > "Report draft.md"
printf 'node_modules\n' > .gitignore
printf 'export EDITOR=vim\n' > .zshrc
screencapture -x -R 0,0,400,300 Photo.png
printf '%%PDF-1.4\n' > Projects/Plan.pdf
```

Finder shows an extension even with "show all extensions" off, unless the file's own hide-extension flag is set. Set it on every sample file:

```bash
osascript -e 'tell application "Finder" to set extension hidden of every file of folder "Studio" of folder "Documents" of home to true'
```

### Standard Finder window

Unless a step says otherwise, a "standard Finder window" means:

- Showing `~/Documents/Studio`, in **list view**, sorted by Name ascending.
- Sidebar visible, toolbar visible, tab bar hidden, no item selected.
- Bounds: left 200, top 120, width 760, height 420 points.

```bash
open ~/Documents/Studio
osascript -e 'tell application "Finder" to set bounds of front window to {200, 120, 960, 540}'
```

## 3. How to capture

**Stills**

- A single window: capture that window only, without its shadow, as PNG.
  `screencapture -x -o -l <windowID> out.png`
- The whole desktop: `screencapture -x out.png`
- Move the pointer out of the frame first unless the step says where it goes.

**Videos** (only where the step says "video")

- Full display, 30 fps, no audio, H.264 `.mp4`, 3 to 6 seconds.
- Start from a resting state and end on a resting state, so the clip can loop.
- Also save a still of the final frame under the `.png` name. Every option needs a `.png` even when it has a video.

**After changing a setting**

| Setting lives in | Then run |
|---|---|
| `com.apple.finder`, or `AppleShowAllExtensions` | `killall Finder`, wait 3 s, reopen the standard window |
| `com.apple.dock` | `killall Dock`, wait 3 s |
| `com.apple.screencapture` | `killall SystemUIServer`, wait 2 s |
| `NSGlobalDomain` text and dialog keys | Quit and reopen the app being captured |
| `KeyRepeat`, `InitialKeyRepeat` | Log out and back in |

## 4. File names

Name every file `<setting id>.<option>.<ext>`, exactly as written in the shot list. Examples:

```
finder.hidden-files.off.png
finder.hidden-files.on.png
dock.minimize-effect.genie.png
dock.minimize-effect.genie.mp4
```

Put everything in one flat folder named `MacKitCaptures`.

## 5. Shot list

Each entry gives the setting id, the command for each option, and what to capture. "Stock" marks the macOS default.

### Finder

**finder.hidden-files** — `defaults write com.apple.finder AppleShowAllFiles -bool <true|false>`
- `off` (stock, false), `on` (true). Standard Finder window. With it on, `.gitignore` and `.zshrc` appear dimmed.

**finder.extensions** — `defaults write NSGlobalDomain AppleShowAllExtensions -bool <true|false>`
- `off` (stock), `on`. Standard Finder window. With it on, names read `Notes.txt`, `Budget.csv`, and so on.

**finder.extension-warning** — `defaults write com.apple.finder FXEnableExtensionChangeWarning -bool <true|false>`
- Set `AppleShowAllExtensions` to true for this entry only, then restore it.
- `on` (stock, true): select `Notes.txt`, press Return, change the name to `Notes.md`, press Return. Capture the window with the confirmation dialog showing.
- `off`: do the same rename. No dialog appears. Capture the window with `Notes.md` selected.
- Rename the file back to `Notes.txt` afterward.

**finder.library** — on: `chflags nohidden ~/Library` · off (stock): `chflags hidden ~/Library`
- `off`, `on`. Finder window showing the home folder (`open ~`), list view, same bounds as the standard window.

**finder.path-bar** — `defaults write com.apple.finder ShowPathbar -bool <true|false>`
- `off` (stock), `on`. Standard Finder window.

**finder.status-bar** — `defaults write com.apple.finder ShowStatusBar -bool <true|false>`
- `off` (stock), `on`. Standard Finder window.

**finder.folders-first** — `defaults write com.apple.finder _FXSortFoldersFirst -bool <true|false>`
- `off` (stock), `on`. Standard Finder window, sorted by Name. With it on, `Archive` and `Projects` lead the list.

**finder.default-view** — `defaults write com.apple.finder FXPreferredViewStyle -string <icnv|Nlsv|clmv|glyv>`
- `icon` (stock, icnv), `list` (Nlsv), `column` (clmv), `gallery` (glyv).
- Finder remembers a folder's view once it has been opened. Before each option run `find ~/Documents/Studio -name .DS_Store -delete`, then restart Finder and open the folder fresh. Do not click a view button.
- For `column`, select `Projects` so three columns show: Studio, Projects, Website.
- For `gallery`, select `Photo.png`.

**finder.search-scope** — `defaults write com.apple.finder FXDefaultSearchScope -string <SCev|SCcf|SCsp>`
- `mac` (stock, SCev), `folder` (SCcf), `previous` (SCsp).
- Standard Finder window. Click the search field, type `report`, wait 2 s. Capture the window with the scope bar ("This Mac" / "Studio") visible, showing which scope is selected.
- For `previous`: with SCsp set, search once and click "Studio" in the scope bar, close the window, reopen it, search again, and capture.

**finder.ds-store-network** — `defaults write com.apple.desktopservices DSDontWriteNetworkStores -bool <true|false>`
**finder.ds-store-usb** — `defaults write com.apple.desktopservices DSDontWriteUSBStores -bool <true|false>`
- `off` (stock), `on`. Needs a real network share or removable volume, and a logout between options. Turn on hidden files, open the volume, switch its view once so Finder would write `.DS_Store`, close and reopen it, and capture the window. Off shows a `.DS_Store` file. On shows none.
- Skip either one if the VM has no suitable volume. Say so in the manifest.

### Dock

For every Dock entry, open TextEdit with one new empty document titled "Untitled", sized about 520×320 and centered, so the desktop isn't empty. Capture the whole display.

**dock.autohide** — `defaults write com.apple.dock autohide -bool <true|false>`
- `off` (stock), `on`. Pointer in the middle of the screen. With it on, the Dock is not visible.

**dock.reveal-speed** — requires `autohide` true for this entry only.
- `standard` (stock): `defaults delete com.apple.dock autohide-delay; defaults delete com.apple.dock autohide-time-modifier`
- `fast`: `defaults write com.apple.dock autohide-delay -float 0; defaults write com.apple.dock autohide-time-modifier -float 0.4`
- `instant`: `defaults write com.apple.dock autohide-delay -float 0; defaults write com.apple.dock autohide-time-modifier -float 0`
- **Video** for each: pointer rests mid-screen for 0.5 s, moves straight down to the bottom edge in 0.3 s, waits 1.5 s while the Dock appears, moves back to mid-screen, waits 1 s while it hides. Use the same pointer path and timing for all three.
- Still: the Dock fully revealed.

**dock.position** — `defaults write com.apple.dock orientation -string <left|bottom|right>`
- `left`, `bottom` (stock), `right`.

**dock.recents** — `defaults write com.apple.dock show-recents -bool <true|false>`
- First open and quit Calculator, Stickies, and Chess, so there are recent apps to show.
- `on` (stock), `off`. With it on, the three apps appear in a separate section before the Trash.

**dock.minimize-effect** — `defaults write com.apple.dock mineffect -string <genie|scale|suck>`
- `genie` (stock), `scale`, `suck`.
- **Video** for each: 0.5 s at rest, click the TextEdit window's yellow button, hold until the animation finishes and 0.5 s after. Then click the minimized window in the Dock to restore it, off camera.
- Still: the frame halfway through the animation, where the shape of the effect is clearest.

**dock.minimize-to-app** — `defaults write com.apple.dock minimize-to-application -bool <true|false>`
- `off` (stock), `on`. Minimize the TextEdit window, wait for the animation, then capture. Off shows a window thumbnail at the right of the Dock. On shows none.

**dock.launch-animation** — `defaults write com.apple.dock launchanim -bool <true|false>`
- `on` (stock), `off`. Make sure Calculator is in the Dock and not running.
- **Video** for each: 0.5 s at rest, click Calculator in the Dock, record until its window appears. Quit Calculator afterward.
- Still for `on`: the icon at the top of a bounce. Still for `off`: the icon at rest just after the click.

**dock.rearrange-spaces** — `defaults write com.apple.dock mru-spaces -bool <true|false>`
- `on` (stock), `off`.
- Create three desktops in Mission Control. Put TextEdit on Desktop 1, Calculator on Desktop 2, Stickies on Desktop 3.
- For each option: start on Desktop 1, click Stickies in the Dock to jump to Desktop 3, then open Mission Control and capture the display with the Spaces bar expanded.
- With it on, the desktop holding Stickies has moved next to Desktop 1. With it off, the order is unchanged.

### Screenshots

**screenshot.format** — `defaults write com.apple.screencapture type -string <png|jpg|heic|pdf|tiff>`
- `png` (stock), `jpg`, `heic`, `pdf`, `tiff`.
- For each: empty the Desktop folder, take one full-screen screenshot with ⇧⌘3, wait for it to save. Open `~/Desktop` as a standard-size Finder window in list view with the Kind column visible and "show all extensions" on. Capture the window showing the one file with its extension and kind.

**screenshot.location** — `defaults write com.apple.screencapture location -string <path>`
- `desktop` (stock, `~/Desktop`), `downloads` (`~/Downloads`), `pictures` (`~/Pictures`). Use the full path, not `~`.
- For each: empty all three folders, take one screenshot with ⇧⌘3, open the target folder as a standard-size Finder window in icon view, and capture the window showing the new file.

**screenshot.shadow** — `defaults write com.apple.screencapture disable-shadow -bool <true|false>`
- `on` (stock, false), `off` (true). Note the inversion: the option is "window shadow", the key is "disable shadow".
- For each: press ⇧⌘4, then Space, and click the TextEdit window. **The saved screenshot file itself is the capture.** Convert it to PNG if needed, keeping transparency, and rename it. Do not screenshot the screenshot.

**screenshot.thumbnail** — `defaults write com.apple.screencapture show-thumbnail -bool <true|false>`
- `on` (stock), `off`.
- For each: press ⇧⌘3, and one second later capture the whole display with a second tool or a delayed `screencapture -T 1`. On shows the floating thumbnail in the bottom-right corner. Off shows none.

### Keyboard

Use TextEdit with one empty plain-text document, font size 36, window about 620×260 and centered. Capture the TextEdit window only for stills. Record the whole display for videos.

TextEdit has its own switches under Edit ▸ Substitutions and Edit ▸ Spelling and Grammar that override the system setting. Before each entry, confirm they still match the system default. If TextEdit does not follow the system setting, use Notes instead and say so in the manifest.

**keyboard.press-and-hold** — `defaults write NSGlobalDomain ApplePressAndHoldEnabled -bool <true|false>`
- `on` (stock), `off`.
- **Video** for each: hold the `e` key for 2 s, release, wait 0.5 s. On shows the accent menu. Off shows the letter repeating.
- Still: the moment 1.5 s into the hold.

**keyboard.repeat-rate** — `defaults write NSGlobalDomain KeyRepeat -int <6|2|1>`
- `standard` (stock, 6), `fast` (2), `fastest` (1). Log out and in after each change.
- **Video** for each: hold the `a` key for exactly 2 s, release, wait 0.5 s. Keep `InitialKeyRepeat` at 25 throughout.
- Still: the document just after release.

**keyboard.repeat-delay** — `defaults write NSGlobalDomain InitialKeyRepeat -int <25|15|10>`
- `standard` (stock, 25), `short` (15), `shortest` (10). Log out and in after each change.
- **Video** for each: hold the `a` key for exactly 1 s, release, wait 0.5 s. Keep `KeyRepeat` at 6 throughout.
- Still: the document just after release.

For the five entries below, quit and reopen TextEdit after each change. Type the phrase at a natural pace, about 6 characters per second. **Video** the typing. Still: the document 1 s after the last keystroke. All five are `on` (stock, true) and `off` (false).

| Id | Key (in `NSGlobalDomain`) | Type exactly |
|---|---|---|
| `text.autocorrect` | `NSAutomaticSpellingCorrectionEnabled` | `teh quick fox ` (with the trailing space) |
| `text.capitalize` | `NSAutomaticCapitalizationEnabled` | `hello. how are you` |
| `text.period` | `NSAutomaticPeriodSubstitutionEnabled` | `Done`, two spaces, `Next` |
| `text.smart-quotes` | `NSAutomaticQuoteSubstitutionEnabled` | `"hello" it's` |
| `text.smart-dashes` | `NSAutomaticDashSubstitutionEnabled` | `wait--what` |

### Windows

Use TextEdit. Quit and reopen it after each change.

**windows.save-expanded** — set both keys together:
`defaults write NSGlobalDomain NSNavPanelExpandedStateForSaveMode -bool <v>; defaults write NSGlobalDomain NSNavPanelExpandedStateForSaveMode2 -bool <v>`
- `off` (stock), `on`. New document, type `Hello`, press ⌘S. Capture the TextEdit window with the save sheet open.
- macOS also remembers the last state per app. If the sheet doesn't follow the setting, run `defaults delete com.apple.TextEdit` and try again.

**windows.print-expanded** — set both keys together:
`defaults write NSGlobalDomain PMPrintingExpandedStateForPrint -bool <v>; defaults write NSGlobalDomain PMPrintingExpandedStateForPrint2 -bool <v>`
- `off` (stock), `on`. Same document, press ⌘P. Capture the window with the print sheet open. If no printer is set up, "Save as PDF" is enough for the sheet to appear.

**windows.save-to-icloud** — `defaults write NSGlobalDomain NSDocumentSaveNewDocumentsToCloud -bool <true|false>`
- `on` (stock), `off`. Needs an Apple ID with iCloud Drive signed in, which a clean VM should not have. **Skip** unless a throwaway test account is already signed in. Do not sign in with a real account.

**windows.confirm-close** — `defaults write NSGlobalDomain NSCloseAlwaysConfirmsChanges -bool <true|false>`
- `off` (stock), `on`. Open a saved document (`~/Documents/Letter.txt`), type a word, press ⌘W.
- `on`: capture the window with the "keep changes?" dialog showing.
- `off`: **video** only, showing the window closing with no dialog. Still: the frame just before the window closes, with "Edited" in its title.

**windows.scroll-bars** — `defaults write NSGlobalDomain AppleShowScrollBars -string <Automatic|WhenScrolling|Always>`
- `automatic` (stock), `scrolling`, `always`.
- Open a document with 60 lines of text, scrolled to the top. Wait 3 s without touching anything, then capture the window. Always shows a scroll bar. When Scrolling shows none at rest. Automatic depends on the pointing device, so note which device the VM reports.

**windows.restore** — `defaults write NSGlobalDomain NSQuitAlwaysKeepsWindows -bool <true|false>`
- `off` (stock), `on`. Open two saved documents side by side, quit TextEdit with ⌘Q, reopen it, wait 2 s, and capture the whole display. On reopens both. Off opens none or one new window.

### System

These need an administrator password. Capture the relevant pane of System Settings, window only, with the switch in each state. Change the setting with the switch in System Settings, not with a command.

**security.firewall** — System Settings ▸ Network ▸ Firewall
- `off` (stock), `on`.

**security.stealth** — System Settings ▸ Network ▸ Firewall ▸ Options…, "Enable stealth mode"
- `off` (stock), `on`. The firewall must be on for the option to be available. Capture the window with the Options sheet open.

**startup.chime** — System Settings ▸ Sound, "Play sound on startup"
- `on` (stock), `off`.

## 6. Optional second pass: Dark

If time allows, switch Appearance to Dark and repeat every still (not the videos). Add `.dark` before the extension: `finder.hidden-files.on.dark.png`. Keep everything else identical to the Light pass.

## 7. Clean up after each entry

Put the setting back to its stock value before starting the next entry, and restart the relevant process. Captures for one setting must not carry over a change from another.

## 8. Deliver

1. The flat `MacKitCaptures` folder.
2. `manifest.json` inside it:

```json
{
  "macOS": "27.2 (build)",
  "display": "1440x900 @2x",
  "user": "short name of the VM account",
  "captures": [
    { "file": "finder.hidden-files.on.png", "window": "Finder", "notes": "" }
  ],
  "skipped": [
    { "id": "windows.save-to-icloud", "reason": "No iCloud account on the VM" }
  ],
  "noVisibleEffect": [
    { "id": "example.id", "option": "on", "what": "Describe what you tried and saw" }
  ]
}
```

3. A zip of the folder.

## 9. Final check before you hand over

- Every setting you captured has a `.png` for **every one** of its options. A setting with a missing option can't be used at all.
- Within each setting, the frames line up: same size, same window position.
- No file shows personal information, a notification, or another app.
- Every skipped or ineffective setting is in the manifest with a reason.
