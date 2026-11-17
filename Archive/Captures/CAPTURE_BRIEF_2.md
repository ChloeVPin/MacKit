# Capture brief 2: more real macOS previews for MacKit

You are capturing real screenshots of macOS settings on a clean macOS virtual machine. They ship inside a Mac app called MacKit. Each setting in MacKit has a page, and the page shows a real screenshot of macOS that swaps as the user picks an option. An earlier pass covered 25 settings. This pass covers 97 more.

Take as long as you need. Hours are fine. Quality matters far more than speed: a setting with a sloppy or mismatched set of pictures can't be used at all, so it is better to finish 50 settings perfectly than 97 carelessly.

Work through the shot list in section 6 from top to bottom. Where a step can't be done, skip that setting, write down why in the manifest, and keep going. A missing capture is fine. A wrong or faked one is not.

## 1. What makes a set usable

MacKit shows the pictures for one setting on top of each other and fades between them. That only works when:

1. **Every option has a picture.** A setting with four options needs four pictures. If one option can't be captured, drop the whole setting and say so in the manifest.
2. **The frames line up exactly.** Same display, same window position and size, same files, same selection, same pointer position. The only thing that differs between two pictures of one setting is the effect of the setting.
3. **The difference is visible.** After each capture, open the pictures for that setting and compare them. If you can't see the difference at a glance, the capture has failed. Either find a view that shows it, or record the setting under `noVisibleEffect`.
4. **The setting really was in that state.** After every change, read the value back (`defaults read <domain> <key>`, or look at the switch in System Settings) before you capture. Record a failed read in the manifest.

## 2. Rules

1. **Real only.** Do not draw, composite, retouch, or generate anything. Do not crop or scale either: hand over the raw captures, and record where the interesting part is (section 5).
2. **Stills only.** No videos this time. The app can't show them.
3. **Light appearance only**, except where an entry says otherwise.
4. **Nothing personal on screen.** No Apple ID, no real names, no notifications, no other apps. Don't sign in to any account, including iCloud.
5. **Stay on the machine.** The only website you may open is `https://example.com`. Install nothing.
6. **One setting at a time.** Before starting an entry, every other setting is at its stock value. After finishing it, put it back to stock, restart the process the entry names, and confirm.
7. **Change settings with the command in section 8** unless the entry says to use a switch. If a command has no effect even after the restart step it names, use the matching control in System Settings or the app's own Settings window, and note that in the manifest. Some values are only read at login: logging out and back in is allowed and expected.
8. **Never capture a pair that looks identical**, with one exception: an option named `auto` or `region` may match another option of the same setting.

## 3. Prepare the VM once

- Appearance: Light. Accent and highlight color: default (Multicolor). Wallpaper: the macOS default.
- Display: the same resolution as the first pass (1600×1200 if that is what the VM offers). Never change it during the pass. Record it.
- Dock: default apps, default size, at the bottom, not hidden.
- Desktop: no icons, no widgets, no open windows. Turn on Do Not Disturb.
- Quit every app except Finder before each entry.
- Give your terminal (or whatever process runs your commands) **Full Disk Access** in System Settings ▸ Privacy & Security, then restart it. Without it, commands for Safari, TextEdit, Calendar, Preview, and Accessibility silently do nothing. If you can't grant it, change those settings with the controls in each app's Settings window.
- Back up the stock state once, so you can always return to it:
  `mkdir -p ~/StockPrefs && cp -R ~/Library/Preferences ~/StockPrefs/`

### Sample files

The first pass built `~/Documents/Studio`. If it's gone, rebuild it:

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
osascript -e 'tell application "Finder" to set extension hidden of every file of folder "Studio" of folder "Documents" of home to true'
```

Add these for this pass:

```bash
cd ~/Documents/Studio
# A page for Safari and TextEdit.
cat > Page.html <<'EOF'
<!doctype html><title>Sample Page</title>
<h1>Sample Page</h1><p>A short paragraph with <b>bold</b> text and a <a href="https://example.com/a/long/path/to/a/page.html">link to another page</a>.</p>
EOF
# A rich text file.
printf '{\\rtf1\\ansi{\\fonttbl\\f0\\fswiss Helvetica;}\\f0\\fs36 Sample \\b heading\\b0\\par\\fs24 A line of rich text.}' > Letter.rtf
# A plain text file with tabs, and one with 60 lines.
printf 'name\tsize\tkind\nNotes\t4 KB\ttext\nPhoto\t2 MB\timage\n' > Table.txt
for i in $(seq 1 60); do echo "Line $i of the sample document."; done > Long.txt
# A small disk image, for anything that needs an external disk.
hdiutil create -size 10m -fs APFS -volname Sample ~/Documents/Sample.dmg
```

Make a three-page PDF named `~/Documents/Studio/Pages.pdf`: open `Long.txt` in TextEdit at font size 24 and use File ▸ Export as PDF.

### Standard Finder window

Unless an entry says otherwise, "the standard Finder window" means `~/Documents/Studio` in list view, sorted by Name ascending, sidebar and toolbar visible, tab bar hidden, nothing selected, at left 200, top 120, width 760, height 420:

```bash
open ~/Documents/Studio
osascript -e 'tell application "Finder" to set bounds of front window to {200, 120, 960, 540}'
```

Finder remembers a folder's view. When an entry is about how a *new* window looks, run `find ~/Documents/Studio -name .DS_Store -delete`, restart Finder, and open the folder fresh.

### Standard TextEdit window

One document, window at left 400, top 200, width 620, height 360:

```bash
osascript -e 'tell application "TextEdit" to set bounds of front window to {400, 200, 1020, 560}'
```

## 4. How to capture

| The entry says | Do this |
|---|---|
| **Window** | That window only, with no shadow: `screencapture -x -o -l <windowID> out.png` |
| **Screen** | The whole display: `screencapture -x out.png` |
| **Screen with pointer** | The whole display including the pointer: `screencapture -x -C out.png` |
| **Menu open** | Open the menu with a real click, then capture the whole display after a delay: `screencapture -x -T 3 out.png`. Keep the menu open until the capture is taken. |

Move the pointer to the middle of the screen, away from everything, unless the entry says where it goes. For a set of pictures, the pointer is in the same place in each.

After changing a setting, do what section 8 lists under "after" for that setting (`killall Finder`, quit and reopen the app, log out and back in), wait three seconds, and put the window back to its standard bounds.

## 5. Names and the manifest

Name every file `<setting id>.<option>.png`, using the ids and option names exactly as written in section 8:

```
finder.sidebar.off.png
finder.sidebar.on.png
appearance.accent.purple.png
```

Settings in section 7 take a number rather than an option. Name those `<setting id>.v<number>.png`, for example `dock.size.v32.png`.

Put everything in one flat folder named `MacKitCaptures2`, with a `manifest.json`:

```json
{
  "macOS": "27.2 (build)",
  "display": "1600x1200 @1x",
  "user": "short name of the VM account",
  "fullDiskAccess": true,
  "captures": [
    {
      "id": "finder.sidebar",
      "kind": "window",
      "focus": { "x": 0, "y": 0, "width": 760, "height": 420 },
      "changedWith": "command",
      "notes": ""
    }
  ],
  "skipped": [
    { "id": "example.id", "reason": "Why it couldn't be captured" }
  ],
  "noVisibleEffect": [
    { "id": "example.id", "what": "What you tried and what you saw" }
  ]
}
```

`focus` is the rectangle, in pixels of the saved picture, that holds the part worth showing: the smallest box that contains everything that differs between the options, plus a comfortable margin of unchanged surroundings so it's clear what you're looking at. It is the same rectangle for every option of a setting. The pictures will be cropped to it later, so take care over it.

`changedWith` is `command`, or `settings` when you had to use a switch.

## 6. Shot list

Each entry names the setting, then what to set up and what to capture. The command for each option is in section 8. Options are listed as they appear there.

### Finder

**finder.library** · Window. A Finder window on the home folder (`open ~`), list view, standard bounds. On shows a Library folder.

**finder.quit** · Menu open. Click **Finder** in the menu bar. On adds Quit Finder at the bottom of the menu.

**finder.new-window** · Window. For each option, close every Finder window, then press ⌘N with Finder in front and set the standard bounds. Capture the new window. If the `icloud` option can't open without an account, skip the whole setting.

**finder.path-in-title** · Window. Standard Finder window. On shows the whole path as the title.

**finder.path-from-home** · Window. Turn the path bar on for this entry only (`defaults write com.apple.finder ShowPathbar -bool true`), then restore it. Off starts the path at the disk. On starts it at the home folder.

**finder.sidebar** · Window. Standard Finder window, with and without the sidebar.

**finder.preview-pane** · Window. Standard Finder window with `Photo.png` selected.

**finder.tab-bar** · Window. Standard Finder window with one tab.

**finder.sidebar-size** · Window. Standard Finder window. Log out and back in between options if the sidebar doesn't change.

**finder.group-by** · Window. A fresh standard Finder window for each of the ten options (delete `.DS_Store` first). Before starting, give two files a tag (right-click ▸ Tags) and open two of them once, so the groups have something to show.

**access.title-icons** · Window. Standard Finder window. On shows a folder icon beside the title.

**finder.trash-warning** · Screen. Put `~/Documents/Studio/Archive` copies in the Trash first (make a throwaway file and move it to the Trash each time). Choose Finder ▸ Empty Trash. On: capture with the confirmation showing. Off: capture two seconds after choosing it, with no dialog.

**finder.block-connect** · Menu open. Click **Go** in the menu bar. On dims Connect to Server.

**finder.block-go-to-folder** · Menu open. Click **Go**. On dims Go to Folder.

**finder.block-empty-trash** · Menu open. With one file in the Trash, click **Finder** in the menu bar. On dims Empty Trash.

**finder.block-eject** · Menu open. Mount `~/Documents/Sample.dmg`, select the Sample disk in a Finder window, click **File**. On dims Eject. Eject the disk afterward.

### Desktop

For these, put three things on the desktop first and leave them in the same places throughout: a folder named `Projects`, and files named `Notes.txt` and `Budget.csv`. Remove them when the section is done.

**desktop.items** · Screen. Off hides the three icons.

**desktop.finder-draws** · Screen. Off hides the icons too. Capture it anyway: it is a different setting.

**desktop.folders-first** · Screen. Right-click the desktop ▸ Sort By ▸ Name first. Add a file named `Apple.txt` so that a file would sort before the folder. On puts `Projects` first.

**desktop.hard-disks** · Screen. On shows the startup disk on the desktop.

**desktop.external-disks** · Screen. Mount `~/Documents/Sample.dmg`. On shows the Sample disk on the desktop. Off hides it.

**desktop.widgets** · Screen. Add one Clock widget and one Calendar widget to the desktop first (right-click the desktop ▸ Edit Widgets). Off hides them. Remove both afterward.

### Stage Manager

Open TextEdit (one document), Calculator, and the standard Finder window. Click TextEdit last so it is in front.

**stage.enabled** · Screen. Off is the three windows as they are. On moves the others into a strip at the left.

For the next three, Stage Manager is on. Turn it off again when the section is done.

**stage.recent-apps** · Screen. Off hides the strip.

**stage.desktop-items** · Screen. With the three desktop icons from the Desktop section in place. On keeps them visible.

**stage.widgets** · Screen. With one Clock widget on the desktop. Off hides it.

**stage.grouping** · Screen. Open a second TextEdit document so TextEdit has two windows, bring Calculator to the front, then click TextEdit in the strip. `all` brings both windows forward. `one` brings one.

### Dock

For every Dock entry, open TextEdit with one empty document in the standard TextEdit window, so the desktop isn't empty. Capture the Screen.

**dock.magnification** · Screen with pointer. Rest the pointer on the icon in the middle of the Dock. On enlarges the icons around it.

**dock.indicators** · Have TextEdit and Calculator running. Off removes the dots under them.

**dock.recent-count** · Open and quit ten apps first, in this order: Calculator, Stickies, Chess, Dictionary, Font Book, Preview, Maps, Notes, Reminders, Weather. Then capture each of the four options.

**dock.only-open-apps** · Have TextEdit and Calculator running. On leaves only Finder, the running apps, and the Trash.

**dock.stack-highlight** · Screen with pointer. Put six files in Downloads. Right-click the Downloads stack ▸ View content as ▸ Grid. Click the stack and rest the pointer on the second item. On draws a highlight behind it.

**activity.dock-icon** · Open Activity Monitor and minimize its window. Capture each of the five options ten seconds after launch, so the graphs have data.

### Mission Control

**mission.group-apps** · Screen. Open two TextEdit documents, two Finder windows, and Calculator, spread around the screen without overlapping much. Open Mission Control (Control-Up Arrow), wait two seconds, capture. On stacks each app's windows together.

### Windows

**tiling.margins** · Screen. Open TextEdit with one document and choose Window ▸ Move & Resize ▸ Left. On leaves a gap between the window and the screen edges.

**appearance.corners** · Window, **with** its shadow this time and a transparent background: `screencapture -x -l <windowID> out.png`. The standard TextEdit window, empty. Four options. If the corners look the same in all four, record it under `noVisibleEffect`.

**appearance.wallpaper-tint** · Screen. The standard Finder window over the default wallpaper. Off makes the window background a neutral gray.

**windows.print-expanded** · Window. TextEdit, `Notes.txt` open, press ⌘P. Capture the window with the print sheet open. If TextEdit remembers its own state, run `defaults delete com.apple.TextEdit` and try again.

**windows.restore** · Screen. Open `Notes.txt` and `Table.txt` side by side in TextEdit, quit with ⌘Q, reopen TextEdit, wait three seconds. On reopens both.

### Appearance

**appearance.mode** · Screen. The standard Finder window open. `light`, `dark`, and `auto` (which will match one of the other two).

**appearance.accent** · Window. System Settings ▸ Appearance. Nine options. Quit and reopen System Settings after each change so the whole window picks the color up.

**appearance.icon-style** · Screen. Nothing open. Nine options. If the command needs a logout to show, use System Settings ▸ Appearance ▸ Icon & widget style instead and confirm with `defaults read NSGlobalDomain AppleIconAppearanceTheme`.

**appearance.icon-tint** · Screen. Set the icon style to Tinted for this entry only. Nine options.

**access.reduce-transparency** · Screen. The standard Finder window open, sitting over a colorful part of the wallpaper. On makes the menu bar, Dock, and sidebar solid.

**access.increase-contrast** · Window. Standard Finder window. On adds borders and darker text.

**access.button-shapes** · Window. Standard Finder window. On outlines the toolbar buttons.

### Menu bar

Capture the Screen for all of these. Only the top strip matters, so set `focus` to the right-hand part of the menu bar, about 700 pixels wide, unless the entry is about the left side.

**menubar.background** · On gives the menu bar a solid backing.

**menubar.autohide** · Pointer mid-screen. On hides the menu bar. `focus` is the full width of the top 80 pixels.

**menubar.text-size** · `focus` is the full width of the menu bar.

**menubar.spacing** · Three options. Log out and back in after each.

**menubar.spotlight** · Off removes the magnifying glass.

**menubar.input-menu** · On adds the input menu.

**menubar.siri** · Skip if the VM has no Siri.

**clock.style**, **clock.seconds**, **clock.date** (three options), **clock.weekday**, **clock.am-pm** · One set each. The time will differ between captures. That's fine.

**region.clock** · `region`, `24`, `12`. Log out and back in after each.

**safari.develop** · Open Safari on `Page.html`. On adds a Develop menu. `focus` is the left half of the menu bar.

### Typing

Use TextEdit with one empty plain-text document (Format ▸ Make Plain Text), font size 36, in the standard TextEdit window. Quit and reopen TextEdit after each change. Type with real key presses at a natural pace, then wait two seconds and capture the Window.

**text.autocorrect** · Type `teh quick fox ` with the trailing space. On corrects it to "the".

**text.spell-check** · Turn `text.autocorrect` off for this entry only, then restore it. Type `teh quikc fox `. On underlines the misspelled words in red.

**textedit.smart-links** · Rich text document. Type `www.example.com ` with the trailing space. On turns it into a link.

### Screenshots

**screenshot.date** · Window. For each option, empty the Desktop folder, press ⇧⌘3, wait for the file, and open `~/Desktop` as a standard-size Finder window in list view. On names the file with the date and time. Off names it "Screenshot".

**screenshot.pointer** · For each option, rest the pointer in the middle of an empty standard TextEdit window and press ⇧⌘3. **The saved screenshot is the capture.** Rename it. On includes the pointer. If ⇧⌘3 ignores the setting, try ⇧⌘5 ▸ Options ▸ Show Mouse Pointer and say so in the manifest.

### Safari

Open `~/Documents/Studio/Page.html` in Safari, except where an entry says otherwise. Window at left 200, top 120, width 900, height 520. Quit and reopen Safari after each change. Capture the Window. If Safari shows a start page with suggestions or a privacy report, that's fine as long as nothing personal appears.

**safari.full-url** · Open `https://example.com/` for this one. On shows the whole address.

**safari.status-bar** · Screen with pointer, pointer resting on the link in the page. On shows the link's address along the bottom of the window.

**safari.favorites-bar** · On adds a row under the address bar.

**safari.tab-layout** · Open two tabs (`Page.html` and an empty tab). `separate` and `compact`.

### TextEdit

Quit and reopen TextEdit after each change. Capture the Window at the standard TextEdit bounds.

**textedit.format** · A new empty document (⌘N). `rich` has a formatting toolbar. `plain` doesn't.

**textedit.ruler** · A new rich text document.

**textedit.wrap-to-page** · Open `Long.txt`.

**textedit.html-as-code** · Open `Page.html`. Off shows the formatted page. On shows the HTML.

**textedit.rtf-as-code** · Open `Letter.rtf`. Off shows formatted text. On shows the RTF source.

**textedit.tab-width** · Open `Table.txt`. Three options.

**textedit.spelling** · Plain text document at size 36, with correction off for this entry. Type `teh quikc fox `.

### Other apps

**terminal.line-marks** · Window. Terminal, window about 720×400. Run `echo one`, `echo two`, `echo three`. Off removes the brackets in the margin.

**calendar.week-numbers** · Window. Calendar in Month view, about 1000×640. Don't add accounts or events.

**calendar.days** · Window. Calendar in Week view. `7` and `5`.

**calendar.hours-shown** · Window. Calendar in Week view. Five options.

**diskutility.all-devices** · Window. Disk Utility. On shows whole disks above their volumes.

**preview.sidebar** · Window. Open `Pages.pdf` in Preview, about 900×600. Close and reopen the file after each change.

### Firewall

These need the administrator password. Use the switches in System Settings, not commands. Turn the firewall on first, open System Settings ▸ Network ▸ Firewall ▸ Options, and capture the Window with the sheet open. Turn the firewall off again afterward.

**security.block-all**, **security.allow-built-in**, **security.allow-signed** · One set each, the switch off and on.

### Crash reports

**privacy.crash-dialog** · Screen. Four options. For each, open TextEdit, run `killall -SEGV TextEdit`, wait five seconds, and capture. `none` shows nothing. Dismiss the dialog without sending a report.

### Login window

Only if you can capture the VM's display from outside the VM (from the host), because nothing inside the session can photograph the login window. Otherwise skip all of these. They need the administrator password. Log out to see each one.

**login.display** · `list` and `name`.

**login.power-buttons** · Off removes Sleep, Restart, and Shut Down.

**login.input-menu** · On adds the input menu.

### Second attempts

The first pass didn't produce usable pictures for these. Try each once more as a **still**. If the VM still can't show it, skip it.

**dock.rearrange-spaces** · Create three desktops. Put TextEdit on Desktop 1, Calculator on Desktop 2, Stickies on Desktop 3. For each option: start on Desktop 1, click Stickies in the Dock, open Mission Control, and capture the Screen with the row of desktops expanded. On moves the Stickies desktop next to Desktop 1.

**dock.minimize-effect** · Three options. Hold Shift while clicking the TextEdit window's yellow button so the animation runs slowly, and capture the Screen about a third of the way through. Take several and keep the frame where the shape is clearest. The three pictures should catch the window at about the same point.

**keyboard.press-and-hold** · Typing setup. Hold the `e` key for two seconds with a real key press and capture the Window while it is held. On shows the accent menu. Off shows a row of e's.

## 7. Settings that take a number

These are sliders in MacKit. Capture each value listed, name the files `<id>.v<number>.png`, and keep the frames aligned like any other set.

**dock.size** · Screen, TextEdit open as in the Dock section. `defaults write com.apple.dock tilesize -int <n>; killall Dock` for 16, 32, 48, 64, 96, 128. Stock is 48.

**dock.magnified-size** · Screen with pointer. Magnification on for this entry, pointer resting on the middle Dock icon. `defaults write com.apple.dock largesize -int <n>; killall Dock` for 48, 64, 96, 128. Stock is 64.

**access.pointer-size** · Screen with pointer, pointer in the middle of an empty standard TextEdit window. `defaults write com.apple.universalaccess mouseDriverCursorSize -float <n>`, then log out and back in, for 1, 2, 3, 4. If the pointer isn't in the saved picture, skip.

**appearance.glass-tint** · Screen, standard Finder window over a colorful part of the wallpaper. `defaults write NSGlobalDomain NSGlassTintAmount -float <n>`, then log out and back in, for 0, 0.25, 0.5, 0.75, 1. Name them `v0`, `v25`, `v50`, `v75`, `v100`. Stock is 0.5.

**textedit.font-size** · Window. Open `Notes.txt` after each change. `defaults write com.apple.TextEdit NSFixedPitchFontSize -int <n>` for 9, 11, 14, 18, 24, 36. Stock is 11.

Put each one back to stock afterward (`defaults delete <domain> <key>`).

## 8. Commands

One block per setting: where it lives in MacKit, what it does, what to do after changing it, and the command for every option. `(stock)` marks the macOS default. Where a command reads `defaults delete`, an error saying the key doesn't exist is fine. Lines marked `[admin]` need `sudo`; lines marked `[FDA]` need Full Disk Access (section 3).

### access.button-shapes
Accessibility > Display > Show toolbar button shapes [FDA]
Draw an outline around toolbar buttons.
After: quit and reopen the app
- off (stock) "Off": defaults write com.apple.universalaccess showToolbarButtonShapes -bool false
- on "On": defaults write com.apple.universalaccess showToolbarButtonShapes -bool true

### access.increase-contrast
Accessibility > Display > Increase contrast [FDA]
Add stronger borders and darker text.
After: nothing
- off (stock) "Off": defaults write com.apple.universalaccess increaseContrast -bool false
- on "On": defaults write com.apple.universalaccess increaseContrast -bool true

### access.reduce-transparency
Accessibility > Display > Reduce transparency [FDA]
Make glass and see-through surfaces solid.
After: nothing
- off (stock) "Off": defaults write com.apple.universalaccess reduceTransparency -bool false
- on "On": defaults write com.apple.universalaccess reduceTransparency -bool true

### access.title-icons
Accessibility > Display > Show window title icons [FDA]
Always show the folder or document icon in window titles.
After: killall Finder
- off (stock) "Off": defaults write com.apple.universalaccess showWindowTitlebarIcons -bool false
- on "On": defaults write com.apple.universalaccess showWindowTitlebarIcons -bool true

### activity.dock-icon
Apps > Activity Monitor > Dock icon shows
Turn the Dock icon into a live graph.
After: quit and reopen the app
- app (stock) "App Icon": defaults write com.apple.ActivityMonitor IconType -int 0
- cpu "CPU Usage": defaults write com.apple.ActivityMonitor IconType -int 5
- cpu-history "CPU History": defaults write com.apple.ActivityMonitor IconType -int 6
- network "Network Usage": defaults write com.apple.ActivityMonitor IconType -int 2
- disk "Disk Activity": defaults write com.apple.ActivityMonitor IconType -int 3

### appearance.accent
Appearance > Colors > Accent color
The color of buttons, switches, and selections.
After: quit and reopen the app
- multicolor (stock) "Multicolor": defaults delete NSGlobalDomain AppleAccentColor
- blue "Blue": defaults write NSGlobalDomain AppleAccentColor -int 4
- purple "Purple": defaults write NSGlobalDomain AppleAccentColor -int 5
- pink "Pink": defaults write NSGlobalDomain AppleAccentColor -int 6
- red "Red": defaults write NSGlobalDomain AppleAccentColor -int 0
- orange "Orange": defaults write NSGlobalDomain AppleAccentColor -int 1
- yellow "Yellow": defaults write NSGlobalDomain AppleAccentColor -int 2
- green "Green": defaults write NSGlobalDomain AppleAccentColor -int 3
- graphite "Graphite": defaults write NSGlobalDomain AppleAccentColor -int -1

### appearance.corners
Appearance > Liquid Glass > Window corners
How rounded window corners are. There's no switch for this in System Settings.
After: quit and reopen the app
- square "Slightly Rounded": defaults write NSGlobalDomain NSConvolutionOverride1 -int 10
- medium "Rounded": defaults write NSGlobalDomain NSConvolutionOverride1 -int 15
- standard (stock) "Standard": defaults write NSGlobalDomain NSConvolutionOverride1 -int 20
- round "Extra Rounded": defaults write NSGlobalDomain NSConvolutionOverride1 -int 26

### appearance.icon-style
Appearance > Icons and Widgets > Icon and widget style
The look of app icons, folders, and widgets.
After: log out and back in
- default (stock) "Default": defaults write NSGlobalDomain AppleIconAppearanceTheme -string RegularAutomatic
- default-light "Default, Light": defaults write NSGlobalDomain AppleIconAppearanceTheme -string RegularLight
- dark "Dark": defaults write NSGlobalDomain AppleIconAppearanceTheme -string RegularDark
- clear "Clear": defaults write NSGlobalDomain AppleIconAppearanceTheme -string ClearAutomatic
- clear-light "Clear, Light": defaults write NSGlobalDomain AppleIconAppearanceTheme -string ClearLight
- clear-dark "Clear, Dark": defaults write NSGlobalDomain AppleIconAppearanceTheme -string ClearDark
- tinted "Tinted": defaults write NSGlobalDomain AppleIconAppearanceTheme -string TintedAutomatic
- tinted-light "Tinted, Light": defaults write NSGlobalDomain AppleIconAppearanceTheme -string TintedLight
- tinted-dark "Tinted, Dark": defaults write NSGlobalDomain AppleIconAppearanceTheme -string TintedDark

### appearance.icon-tint
Appearance > Icons and Widgets > Icon tint color
The color used when the icon style is Tinted.
After: log out and back in
- hardware (stock) "Match This Mac": defaults write NSGlobalDomain AppleIconAppearanceTintColor -string Hardware
- red "Red": defaults write NSGlobalDomain AppleIconAppearanceTintColor -string Red
- orange "Orange": defaults write NSGlobalDomain AppleIconAppearanceTintColor -string Orange
- yellow "Yellow": defaults write NSGlobalDomain AppleIconAppearanceTintColor -string Yellow
- green "Green": defaults write NSGlobalDomain AppleIconAppearanceTintColor -string Green
- blue "Blue": defaults write NSGlobalDomain AppleIconAppearanceTintColor -string Blue
- purple "Purple": defaults write NSGlobalDomain AppleIconAppearanceTintColor -string Purple
- pink "Pink": defaults write NSGlobalDomain AppleIconAppearanceTintColor -string Pink
- graphite "Graphite": defaults write NSGlobalDomain AppleIconAppearanceTintColor -string Graphite

### appearance.mode
Appearance > Colors > Appearance
Light, dark, or changing with the time of day.
After: log out and back in
- light (stock) "Light": defaults delete NSGlobalDomain AppleInterfaceStyle ; defaults delete NSGlobalDomain AppleInterfaceStyleSwitchesAutomatically
- dark "Dark": defaults write NSGlobalDomain AppleInterfaceStyle -string Dark ; defaults delete NSGlobalDomain AppleInterfaceStyleSwitchesAutomatically
- auto "Auto": defaults delete NSGlobalDomain AppleInterfaceStyle ; defaults write NSGlobalDomain AppleInterfaceStyleSwitchesAutomatically -bool true

### appearance.wallpaper-tint
Appearance > Liquid Glass > Tint windows with the wallpaper
Let window backgrounds pick up a little color from the desktop picture.
After: quit and reopen the app
- off "Off": defaults write NSGlobalDomain AppleReduceDesktopTinting -bool true
- on (stock) "On": defaults write NSGlobalDomain AppleReduceDesktopTinting -bool false

### calendar.days
Apps > Calendar > Days per week [FDA]
Show a full week or just weekdays.
After: quit and reopen the app
- 7 (stock) "7": defaults write com.apple.iCal 'n days of week' -int 7
- 5 "5": defaults write com.apple.iCal 'n days of week' -int 5

### calendar.hours-shown
Apps > Calendar > Hours shown at once [FDA]
How much of the day fits without scrolling.
After: quit and reopen the app
- 6 "6": defaults write com.apple.iCal 'number of hours displayed' -int 6
- 8 "8": defaults write com.apple.iCal 'number of hours displayed' -int 8
- 10 "10": defaults write com.apple.iCal 'number of hours displayed' -int 10
- 12 (stock) "12": defaults write com.apple.iCal 'number of hours displayed' -int 12
- 16 "16": defaults write com.apple.iCal 'number of hours displayed' -int 16

### calendar.week-numbers
Apps > Calendar > Week numbers [FDA]
Show the number of each week.
After: quit and reopen the app
- off (stock) "Off": defaults write com.apple.iCal 'Show Week Numbers' -bool false
- on "On": defaults write com.apple.iCal 'Show Week Numbers' -bool true

### clock.am-pm
Menu Bar > Clock > Show AM and PM
Only matters with a 12-hour clock.
After: killall ControlCenter
- off "Off": defaults write com.apple.menuextra.clock ShowAMPM -bool false
- on (stock) "On": defaults write com.apple.menuextra.clock ShowAMPM -bool true

### clock.date
Menu Bar > Clock > Show the date
Whether the date sits beside the time.
After: killall ControlCenter
- auto (stock) "When Space Allows": defaults write com.apple.menuextra.clock ShowDate -int 0
- always "Always": defaults write com.apple.menuextra.clock ShowDate -int 1
- never "Never": defaults write com.apple.menuextra.clock ShowDate -int 2

### clock.seconds
Menu Bar > Clock > Show seconds
Count the seconds in the menu bar clock.
After: killall ControlCenter
- off (stock) "Off": defaults write com.apple.menuextra.clock ShowSeconds -bool false
- on "On": defaults write com.apple.menuextra.clock ShowSeconds -bool true

### clock.style
Menu Bar > Clock > Clock style
Numbers or a small clock face.
After: killall ControlCenter
- digital (stock) "Digital": defaults write com.apple.menuextra.clock IsAnalog -bool false
- analog "Analog": defaults write com.apple.menuextra.clock IsAnalog -bool true

### clock.weekday
Menu Bar > Clock > Show the day of the week
Put the day before the date and time.
After: killall ControlCenter
- off "Off": defaults write com.apple.menuextra.clock ShowDayOfWeek -bool false
- on (stock) "On": defaults write com.apple.menuextra.clock ShowDayOfWeek -bool true

### desktop.external-disks
Desktop > Disks on the Desktop > External disks
Show drives you plug in.
After: killall Finder
- off "Off": defaults write com.apple.finder ShowExternalHardDrivesOnDesktop -bool false
- on (stock) "On": defaults write com.apple.finder ShowExternalHardDrivesOnDesktop -bool true

### desktop.finder-draws
Desktop > Desktop > Let Finder manage the desktop
Turn off for a completely empty desktop: no icons, no right-click menu.
After: killall Finder
- off "Off": defaults write com.apple.finder CreateDesktop -bool false
- on (stock) "On": defaults write com.apple.finder CreateDesktop -bool true

### desktop.folders-first
Desktop > Desktop > Keep folders on top
Sort folders before files on the desktop.
After: killall Finder
- off (stock) "Off": defaults write com.apple.finder _FXSortFoldersFirstOnDesktop -bool false
- on "On": defaults write com.apple.finder _FXSortFoldersFirstOnDesktop -bool true

### desktop.hard-disks
Desktop > Disks on the Desktop > Hard disks
Show this Mac's built-in disk on the desktop.
After: killall Finder
- off (stock) "Off": defaults write com.apple.finder ShowHardDrivesOnDesktop -bool false
- on "On": defaults write com.apple.finder ShowHardDrivesOnDesktop -bool true

### desktop.items
Desktop > Desktop > Show items on the desktop
Files and folders you keep on the desktop.
After: killall WindowManager
- off "Off": defaults write com.apple.WindowManager StandardHideDesktopIcons -bool true
- on (stock) "On": defaults write com.apple.WindowManager StandardHideDesktopIcons -bool false

### desktop.widgets
Desktop > Desktop > Show widgets on the desktop
Widgets you've placed on the desktop.
After: killall WindowManager
- off "Off": defaults write com.apple.WindowManager StandardHideWidgets -bool true
- on (stock) "On": defaults write com.apple.WindowManager StandardHideWidgets -bool false

### diskutility.all-devices
Apps > Disk Utility > Show all devices
List whole disks, not only their volumes.
After: quit and reopen the app
- off (stock) "Off": defaults write com.apple.DiskUtility SidebarShowAllDevices -bool false
- on "On": defaults write com.apple.DiskUtility SidebarShowAllDevices -bool true

### dock.indicators
Dock > Appearance > Open-app dots
A dot under each app that is running.
After: killall Dock
- off "Off": defaults write com.apple.dock show-process-indicators -bool false
- on (stock) "On": defaults write com.apple.dock show-process-indicators -bool true

### dock.magnification
Dock > Appearance > Magnification
Enlarge icons as the pointer passes over them.
After: killall Dock
- off (stock) "Off": defaults write com.apple.dock magnification -bool false
- on "On": defaults write com.apple.dock magnification -bool true

### dock.minimize-effect
Dock > Windows and Apps > Minimize effect
Suck is built into macOS but missing from System Settings.
After: killall Dock
- genie (stock) "Genie": defaults write com.apple.dock mineffect -string genie
- scale "Scale": defaults write com.apple.dock mineffect -string scale
- suck "Suck": defaults write com.apple.dock mineffect -string suck

### dock.only-open-apps
Dock > Appearance > Show only open apps
Hide every pinned app and folder, leaving just what's running.
After: killall Dock
- off (stock) "Off": defaults write com.apple.dock static-only -bool false
- on "On": defaults write com.apple.dock static-only -bool true

### dock.rearrange-spaces
Mission Control > Spaces > Rearrange Spaces automatically
Let macOS reorder your desktops by recent use.
After: killall Dock
- off "Off": defaults write com.apple.dock mru-spaces -bool false
- on (stock) "On": defaults write com.apple.dock mru-spaces -bool true

### dock.recent-count
Dock > Appearance > Number of recent apps
How many apps the recent section holds.
After: killall Dock
- one "1": defaults write com.apple.dock show-recent-count -int 1
- three (stock) "3": defaults write com.apple.dock show-recent-count -int 3
- five "5": defaults write com.apple.dock show-recent-count -int 5
- ten "10": defaults write com.apple.dock show-recent-count -int 10

### dock.stack-highlight
Dock > Windows and Apps > Highlight items in stacks
Highlight the item under the pointer in a grid stack.
After: killall Dock
- off (stock) "Off": defaults write com.apple.dock mouse-over-hilite-stack -bool false
- on "On": defaults write com.apple.dock mouse-over-hilite-stack -bool true

### finder.block-connect
Finder > Restrictions > Block Connect to Server
Turn off Go > Connect to Server.
After: killall Finder
- off (stock) "Off": defaults write com.apple.finder ProhibitConnectTo -bool false
- on "On": defaults write com.apple.finder ProhibitConnectTo -bool true

### finder.block-eject
Finder > Restrictions > Block ejecting disks
Turn off the Eject command in Finder.
After: killall Finder
- off (stock) "Off": defaults write com.apple.finder ProhibitEject -bool false
- on "On": defaults write com.apple.finder ProhibitEject -bool true

### finder.block-empty-trash
Finder > Restrictions > Block emptying the Trash
Turn off Empty Trash, so nothing is deleted by accident.
After: killall Finder
- off (stock) "Off": defaults write com.apple.finder ProhibitEmptyTrash -bool false
- on "On": defaults write com.apple.finder ProhibitEmptyTrash -bool true

### finder.block-go-to-folder
Finder > Restrictions > Block Go to Folder
Turn off Go > Go to Folder.
After: killall Finder
- off (stock) "Off": defaults write com.apple.finder ProhibitGoToFolder -bool false
- on "On": defaults write com.apple.finder ProhibitGoToFolder -bool true

### finder.group-by
Finder > Windows > Group items by
How new windows group their contents.
After: killall Finder
- none (stock) "None": defaults write com.apple.finder FXPreferredGroupBy -string None
- name "Name": defaults write com.apple.finder FXPreferredGroupBy -string Name
- kind "Kind": defaults write com.apple.finder FXPreferredGroupBy -string Kind
- application "Application": defaults write com.apple.finder FXPreferredGroupBy -string Application
- opened "Date Last Opened": defaults write com.apple.finder FXPreferredGroupBy -string 'Date Last Opened'
- added "Date Added": defaults write com.apple.finder FXPreferredGroupBy -string 'Date Added'
- modified "Date Modified": defaults write com.apple.finder FXPreferredGroupBy -string 'Date Modified'
- created "Date Created": defaults write com.apple.finder FXPreferredGroupBy -string 'Date Created'
- size "Size": defaults write com.apple.finder FXPreferredGroupBy -string Size
- tags "Tags": defaults write com.apple.finder FXPreferredGroupBy -string Tags

### finder.library
Finder > Files > Show the Library folder
Where apps keep their settings, in your home folder.
After: nothing
- off (stock) "Off": chflags hidden ~/Library
- on "On": chflags nohidden ~/Library

### finder.new-window
Finder > Windows > New windows show
The folder a new Finder window opens to.
After: killall Finder
- recents (stock) "Recents": defaults write com.apple.finder NewWindowTarget -string PfAF
- home "Home": defaults write com.apple.finder NewWindowTarget -string PfHm
- desktop "Desktop": defaults write com.apple.finder NewWindowTarget -string PfDe
- documents "Documents": defaults write com.apple.finder NewWindowTarget -string PfDo
- icloud "iCloud Drive": defaults write com.apple.finder NewWindowTarget -string PfID
- computer "Computer": defaults write com.apple.finder NewWindowTarget -string PfCm
- disk "Startup Disk": defaults write com.apple.finder NewWindowTarget -string PfVo

### finder.path-from-home
Finder > Windows > Path bar starts at Home
Leave the disk and Users folders out of the path bar.
After: killall Finder
- off (stock) "Off": defaults write com.apple.finder PathBarRootAtHome -bool false
- on "On": defaults write com.apple.finder PathBarRootAtHome -bool true

### finder.path-in-title
Finder > Windows > Full path in the title
Show the whole folder path as the window title.
After: killall Finder
- off (stock) "Off": defaults write com.apple.finder _FXShowPosixPathInTitle -bool false
- on "On": defaults write com.apple.finder _FXShowPosixPathInTitle -bool true

### finder.preview-pane
Finder > Windows > Preview pane
A large preview of the selected file, on the right.
After: killall Finder
- off (stock) "Off": defaults write com.apple.finder ShowPreviewPane -bool false
- on "On": defaults write com.apple.finder ShowPreviewPane -bool true

### finder.quit
Finder > Files > Allow quitting Finder
Add Quit to the Finder menu. Desktop icons hide while Finder is closed.
After: killall Finder
- off (stock) "Off": defaults write com.apple.finder QuitMenuItem -bool false
- on "On": defaults write com.apple.finder QuitMenuItem -bool true

### finder.sidebar
Finder > Windows > Sidebar
The list of favorites and locations in each window.
After: killall Finder
- off "Off": defaults write com.apple.finder ShowSidebar -bool false
- on (stock) "On": defaults write com.apple.finder ShowSidebar -bool true

### finder.sidebar-size
Finder > Windows > Sidebar icon size
The size of sidebar icons and text, in Finder and other apps.
After: quit and reopen the app
- small "Small": defaults write NSGlobalDomain NSTableViewDefaultSizeMode -int 1
- medium (stock) "Medium": defaults write NSGlobalDomain NSTableViewDefaultSizeMode -int 2
- large "Large": defaults write NSGlobalDomain NSTableViewDefaultSizeMode -int 3

### finder.tab-bar
Finder > Windows > Always show the tab bar
Keep the tab bar visible with a single tab.
After: killall Finder
- off (stock) "Off": defaults write com.apple.finder ShowTabView -bool false
- on "On": defaults write com.apple.finder ShowTabView -bool true

### finder.trash-warning
Finder > Trash > Warn before emptying the Trash
Ask for confirmation first.
After: killall Finder
- off "Off": defaults write com.apple.finder WarnOnEmptyTrash -bool false
- on (stock) "On": defaults write com.apple.finder WarnOnEmptyTrash -bool true

### keyboard.press-and-hold
Keyboard > Keys > Accent menu on key hold
Turn off to make held keys repeat instead.
After: quit and reopen the app
- off "Off": defaults write NSGlobalDomain ApplePressAndHoldEnabled -bool false
- on (stock) "On": defaults write NSGlobalDomain ApplePressAndHoldEnabled -bool true

### login.display
Startup & Login > Login Window > Login window shows [admin]
Pick from a list of accounts, or type a name and password.
After: log out and back in
- list (stock) "List of Users": sudo defaults write /Library/Preferences/com.apple.loginwindow SHOWFULLNAME -bool false
- name "Name and Password": sudo defaults write /Library/Preferences/com.apple.loginwindow SHOWFULLNAME -bool true

### login.input-menu
Startup & Login > Login Window > Input menu [admin]
Let people choose a keyboard layout before logging in.
After: log out and back in
- off (stock) "Off": sudo defaults write /Library/Preferences/com.apple.loginwindow showInputMenu -bool false
- on "On": sudo defaults write /Library/Preferences/com.apple.loginwindow showInputMenu -bool true

### login.power-buttons
Startup & Login > Login Window > Sleep, Restart, and Shut Down buttons [admin]
Show the power buttons on the login window.
After: log out and back in
- off "Off": sudo defaults write /Library/Preferences/com.apple.loginwindow PowerOffDisabled -bool true
- on (stock) "On": sudo defaults write /Library/Preferences/com.apple.loginwindow PowerOffDisabled -bool false

### menubar.autohide
Menu Bar > Appearance > Hide the menu bar automatically
Keep the menu bar off screen until you move to the top.
After: log out and back in
- off (stock) "Off": defaults write NSGlobalDomain _HIHideMenuBar -bool false
- on "On": defaults write NSGlobalDomain _HIHideMenuBar -bool true

### menubar.background
Menu Bar > Appearance > Menu bar background
Give the menu bar a solid backing instead of showing the wallpaper through it.
After: log out and back in
- off (stock) "Off": defaults write NSGlobalDomain SLSMenuBarUseBlurredAppearance -bool false
- on "On": defaults write NSGlobalDomain SLSMenuBarUseBlurredAppearance -bool true

### menubar.input-menu
Menu Bar > Items > Input menu
Switch keyboard layouts and open the emoji picker from the menu bar.
After: log out and back in
- off (stock) "Off": defaults write com.apple.TextInputMenu visible -bool false
- on "On": defaults write com.apple.TextInputMenu visible -bool true

### menubar.siri
Menu Bar > Items > Siri
The Siri icon in the menu bar.
After: killall SystemUIServer
- off "Off": defaults write com.apple.Siri StatusMenuVisible -bool false
- on (stock) "On": defaults write com.apple.Siri StatusMenuVisible -bool true

### menubar.spacing
Menu Bar > Appearance > Icon spacing
Pack menu bar icons closer together so more of them fit.
After: log out and back in
- standard (stock) "Standard": defaults -currentHost delete NSGlobalDomain NSStatusItemSpacing ; defaults -currentHost delete NSGlobalDomain NSStatusItemSelectionPadding
- compact "Compact": defaults -currentHost write NSGlobalDomain NSStatusItemSpacing -int 10 ; defaults -currentHost write NSGlobalDomain NSStatusItemSelectionPadding -int 8
- tight "Tight": defaults -currentHost write NSGlobalDomain NSStatusItemSpacing -int 6 ; defaults -currentHost write NSGlobalDomain NSStatusItemSelectionPadding -int 4

### menubar.spotlight
Menu Bar > Items > Spotlight
The magnifying glass in the menu bar.
After: log out and back in
- off "Off": defaults -currentHost write com.apple.Spotlight MenuItemHidden -bool true
- on (stock) "On": defaults -currentHost write com.apple.Spotlight MenuItemHidden -bool false

### menubar.text-size
Menu Bar > Appearance > Menu bar text size
Larger menu titles and status text.
After: log out and back in
- default (stock) "Default": defaults write NSGlobalDomain AppleMenuBarFontSize -string default
- large "Large": defaults write NSGlobalDomain AppleMenuBarFontSize -string large

### mission.group-apps
Mission Control > Mission Control > Group windows by app
Stack each app's windows together in Mission Control.
After: killall Dock
- off (stock) "Off": defaults write com.apple.dock expose-group-apps -bool false
- on "On": defaults write com.apple.dock expose-group-apps -bool true

### preview.sidebar
Apps > Preview > PDF sidebar [FDA]
Show the page sidebar when a PDF opens.
After: quit and reopen the app
- off "Off": defaults write com.apple.Preview PVPDFSuppressSidebarOnOpening -bool true
- on (stock) "On": defaults write com.apple.Preview PVPDFSuppressSidebarOnOpening -bool false

### privacy.crash-dialog
Privacy & Security > Analytics > When an app crashes
What macOS shows after an app quits unexpectedly.
After: nothing
- crashreport (stock) "Show a Report": defaults write com.apple.CrashReporter DialogType -string crashreport
- basic "Show a Short Notice": defaults write com.apple.CrashReporter DialogType -string basic
- developer "Show Technical Details": defaults write com.apple.CrashReporter DialogType -string developer
- none "Show Nothing": defaults write com.apple.CrashReporter DialogType -string none

### region.clock
Startup & Login > Language and Region > Time format
A 12-hour or 24-hour clock everywhere.
After: log out and back in
- region (stock) "Follow Region": defaults delete NSGlobalDomain AppleICUForce24HourTime ; defaults delete NSGlobalDomain AppleICUForce12HourTime
- 24 "24-Hour": defaults write NSGlobalDomain AppleICUForce24HourTime -bool true ; defaults delete NSGlobalDomain AppleICUForce12HourTime
- 12 "12-Hour": defaults delete NSGlobalDomain AppleICUForce24HourTime ; defaults write NSGlobalDomain AppleICUForce12HourTime -bool true

### safari.develop
Apps > Safari > Develop menu [FDA]
Tools for web developers, including Web Inspector.
After: quit and reopen the app
- off (stock) "Off": defaults write com.apple.Safari IncludeDevelopMenu -bool false ; defaults write com.apple.Safari WebKitDeveloperExtrasEnabledPreferenceKey -bool false ; defaults write com.apple.Safari WebKitPreferences.developerExtrasEnabled -bool false
- on "On": defaults write com.apple.Safari IncludeDevelopMenu -bool true ; defaults write com.apple.Safari WebKitDeveloperExtrasEnabledPreferenceKey -bool true ; defaults write com.apple.Safari WebKitPreferences.developerExtrasEnabled -bool true

### safari.favorites-bar
Apps > Safari > Favorites bar [FDA]
A row of your favorite sites under the address bar.
After: quit and reopen the app
- off (stock) "Off": defaults write com.apple.Safari ShowFavoritesBar-v2 -bool false
- on "On": defaults write com.apple.Safari ShowFavoritesBar-v2 -bool true

### safari.full-url
Apps > Safari > Show full website address [FDA]
Show the whole address, not just the site name.
After: quit and reopen the app
- off (stock) "Off": defaults write com.apple.Safari ShowFullURLInSmartSearchField -bool false
- on "On": defaults write com.apple.Safari ShowFullURLInSmartSearchField -bool true

### safari.status-bar
Apps > Safari > Status bar [FDA]
Show where a link goes when you point at it.
After: quit and reopen the app
- off (stock) "Off": defaults write com.apple.Safari ShowOverlayStatusBar -bool false
- on "On": defaults write com.apple.Safari ShowOverlayStatusBar -bool true

### safari.tab-layout
Apps > Safari > Tab layout [FDA]
Tabs in their own row, or merged into the address bar.
After: quit and reopen the app
- separate (stock) "Separate": defaults write com.apple.Safari ShowStandaloneTabBar -bool true
- compact "Compact": defaults write com.apple.Safari ShowStandaloneTabBar -bool false

### screenshot.date
Screenshots > Saving > Date and time in the name
Turn off for short names like Screenshot 1, Screenshot 2.
After: nothing
- off "Off": defaults write com.apple.screencapture include-date -bool false
- on (stock) "On": defaults write com.apple.screencapture include-date -bool true

### screenshot.pointer
Screenshots > Appearance > Show the pointer
Include the mouse pointer in captures.
After: nothing
- off (stock) "Off": defaults write com.apple.screencapture showsCursor -bool false
- on "On": defaults write com.apple.screencapture showsCursor -bool true

### security.allow-built-in
Privacy & Security > Network > Allow built-in software [admin]
Let Apple's own apps and services accept connections without asking.
After: nothing
- off "Off": sudo /usr/libexec/ApplicationFirewall/socketfilterfw --setallowsigned off
- on (stock) "On": sudo /usr/libexec/ApplicationFirewall/socketfilterfw --setallowsigned on

### security.allow-signed
Privacy & Security > Network > Allow downloaded signed software [admin]
Let apps from identified developers accept connections without asking.
After: nothing
- off "Off": sudo /usr/libexec/ApplicationFirewall/socketfilterfw --setallowsignedapp off
- on (stock) "On": sudo /usr/libexec/ApplicationFirewall/socketfilterfw --setallowsignedapp on

### security.block-all
Privacy & Security > Network > Block all incoming connections [admin]
Refuse everything except what basic internet service needs.
After: nothing
- off (stock) "Off": sudo /usr/libexec/ApplicationFirewall/socketfilterfw --setblockall off
- on "On": sudo /usr/libexec/ApplicationFirewall/socketfilterfw --setblockall on

### stage.desktop-items
Desktop > Stage Manager > Show desktop items
Keep desktop files visible while Stage Manager is on.
After: killall WindowManager
- off (stock) "Off": defaults write com.apple.WindowManager HideDesktop -bool true
- on "On": defaults write com.apple.WindowManager HideDesktop -bool false

### stage.enabled
Desktop > Stage Manager > Stage Manager
Keep one app in the middle and the rest in a strip at the side.
After: nothing
- off (stock) "Off": defaults write com.apple.WindowManager GloballyEnabled -bool false
- on "On": defaults write com.apple.WindowManager GloballyEnabled -bool true

### stage.grouping
Desktop > Stage Manager > Show an app's windows
Whether an app brings all of its windows forward or one.
After: killall WindowManager
- all (stock) "All at Once": defaults write com.apple.WindowManager AppWindowGroupingBehavior -int 1
- one "One at a Time": defaults write com.apple.WindowManager AppWindowGroupingBehavior -int 0

### stage.recent-apps
Desktop > Stage Manager > Show recent apps
Keep the strip of recent apps visible. Off hides it until you reach the edge.
After: killall WindowManager
- off "Off": defaults write com.apple.WindowManager AutoHide -bool true
- on (stock) "On": defaults write com.apple.WindowManager AutoHide -bool false

### stage.widgets
Desktop > Stage Manager > Show widgets
Keep desktop widgets visible while Stage Manager is on.
After: killall WindowManager
- off "Off": defaults write com.apple.WindowManager StageManagerHideWidgets -bool true
- on (stock) "On": defaults write com.apple.WindowManager StageManagerHideWidgets -bool false

### terminal.line-marks
Apps > Terminal > Line marks
Show the brackets that mark each command.
After: quit and reopen the app
- off "Off": defaults write com.apple.Terminal ShowLineMarks -bool false
- on (stock) "On": defaults write com.apple.Terminal ShowLineMarks -bool true

### text.autocorrect
Keyboard > Typing > Correct spelling
Replace misspelled words as you type.
After: quit and reopen the app
- off "Off": defaults write NSGlobalDomain NSAutomaticSpellingCorrectionEnabled -bool false
- on (stock) "On": defaults write NSGlobalDomain NSAutomaticSpellingCorrectionEnabled -bool true

### text.spell-check
Keyboard > Typing > Check spelling while typing
Underline misspelled words in every app.
After: quit and reopen the app
- off "Off": defaults write NSGlobalDomain NSAllowContinuousSpellChecking -bool false
- on (stock) "On": defaults write NSGlobalDomain NSAllowContinuousSpellChecking -bool true

### textedit.format
Apps > TextEdit > New documents are [FDA]
The format a new TextEdit document starts in.
After: quit and reopen the app
- rich (stock) "Rich Text": defaults write com.apple.TextEdit RichText -bool true
- plain "Plain Text": defaults write com.apple.TextEdit RichText -bool false

### textedit.html-as-code
Apps > TextEdit > Show HTML files as code [FDA]
Open web pages as their source, not formatted.
After: quit and reopen the app
- off (stock) "Off": defaults write com.apple.TextEdit IgnoreHTML -bool false
- on "On": defaults write com.apple.TextEdit IgnoreHTML -bool true

### textedit.rtf-as-code
Apps > TextEdit > Show RTF files as code [FDA]
Open rich text files as their source, not formatted.
After: quit and reopen the app
- off (stock) "Off": defaults write com.apple.TextEdit IgnoreRichText -bool false
- on "On": defaults write com.apple.TextEdit IgnoreRichText -bool true

### textedit.ruler
Apps > TextEdit > Ruler [FDA]
Show the ruler at the top of rich text documents.
After: quit and reopen the app
- off "Off": defaults write com.apple.TextEdit ShowRuler -bool false
- on (stock) "On": defaults write com.apple.TextEdit ShowRuler -bool true

### textedit.smart-links
Apps > TextEdit > Smart links [FDA]
Turn web addresses into links as you type.
After: quit and reopen the app
- off (stock) "Off": defaults write com.apple.TextEdit SmartLinks -bool false
- on "On": defaults write com.apple.TextEdit SmartLinks -bool true

### textedit.spelling
Apps > TextEdit > Check spelling as you type [FDA]
Underline misspelled words.
After: quit and reopen the app
- off "Off": defaults write com.apple.TextEdit CheckSpellingWhileTyping -bool false
- on (stock) "On": defaults write com.apple.TextEdit CheckSpellingWhileTyping -bool true

### textedit.tab-width
Apps > TextEdit > Tab width [FDA]
How many spaces wide a tab is in plain text.
After: quit and reopen the app
- 2 "2 Spaces": defaults write com.apple.TextEdit TabWidth -int 2
- 4 "4 Spaces": defaults write com.apple.TextEdit TabWidth -int 4
- 8 (stock) "8 Spaces": defaults write com.apple.TextEdit TabWidth -int 8

### textedit.wrap-to-page
Apps > TextEdit > Wrap to page [FDA]
Lay text out as printed pages instead of filling the window.
After: quit and reopen the app
- off (stock) "Off": defaults write com.apple.TextEdit ShowPageBreaks -bool false
- on "On": defaults write com.apple.TextEdit ShowPageBreaks -bool true

### tiling.margins
Windows > Tiling > Gaps around tiled windows
Leave a margin between tiled windows and the screen edges.
After: killall WindowManager
- off "Off": defaults write com.apple.WindowManager EnableTiledWindowMargins -bool false
- on (stock) "On": defaults write com.apple.WindowManager EnableTiledWindowMargins -bool true

### windows.print-expanded
Windows > Dialogs > Expanded print dialogs
Open print dialogs with every option showing.
After: quit and reopen the app
- off (stock) "Off": defaults write NSGlobalDomain PMPrintingExpandedStateForPrint -bool false ; defaults write NSGlobalDomain PMPrintingExpandedStateForPrint2 -bool false
- on "On": defaults write NSGlobalDomain PMPrintingExpandedStateForPrint -bool true ; defaults write NSGlobalDomain PMPrintingExpandedStateForPrint2 -bool true

### windows.restore
Windows > Behavior > Reopen windows
Apps bring back the windows you had open.
After: quit and reopen the app
- off (stock) "Off": defaults write NSGlobalDomain NSQuitAlwaysKeepsWindows -bool false
- on "On": defaults write NSGlobalDomain NSQuitAlwaysKeepsWindows -bool true

## 9. Final check before you hand over

- Every setting you captured has a picture for **every one** of its options, named exactly as in section 8.
- Open each set and flip between its pictures. The frames line up, and the difference is obvious.
- Every setting is back at its stock value. `defaults read` agrees.
- No picture shows personal information, a notification, or an app that isn't part of the entry.
- Every capture has a `focus` rectangle in the manifest.
- Every skipped or ineffective setting is in the manifest with a reason.
- Zip the `MacKitCaptures2` folder, manifest included, and hand over the zip.
