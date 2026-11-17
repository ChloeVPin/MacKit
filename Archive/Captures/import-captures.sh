#!/bin/zsh
# Crops raw macOS captures down to the part that shows each setting, and
# writes them to MacKit/Resources/Previews as <setting id>.<option>.<ext>.
#
#   Tools/import-captures.sh <folder of raw captures>
#
# Raw captures come from the brief in CAPTURE_BRIEF.md: 760x420 Finder
# windows, 1600x1200 full-screen frames, and window shots with a shadow
# margin (window at 56,38). Only settings listed here are imported; a
# setting whose capture doesn't show a clear difference is left without a
# preview. Needs ffmpeg.

set -euo pipefail

src=${1:?usage: import-captures.sh <folder of raw captures>}
out=${0:A:h:h}/MacKit/Resources/Previews
mkdir -p "$out"

# png <id> <crop w:h:x:y, or "-" for the whole image> <option>...
png() {
  local id=$1 crop=$2; shift 2
  for option in "$@"; do
    local filter="null"
    [[ $crop != "-" ]] && filter="crop=$crop"
    ffmpeg -loglevel error -y -i "$src/$id.$option.png" -vf "$filter" -frames:v 1 "$out/$id.$option.png"
  done
}

# Desktop photographs compress far better as JPEG.
# jpg <id> <filter> <option>...
jpg() {
  local id=$1 filter=$2; shift 2
  for option in "$@"; do
    ffmpeg -loglevel error -y -i "$src/$id.$option.png" -vf "$filter" -frames:v 1 -q:v 3 "$out/$id.$option.jpg"
  done
}

# Finder. The sidebar is cropped away: it never changes and it shows the
# account name.
png finder.hidden-files     566:300:186:6 off on
png finder.extensions       566:300:186:6 off on
png finder.folders-first    566:300:186:6 off on
png finder.extension-warning 566:410:186:6 off on
png finder.path-bar         566:410:186:6 off on
png finder.status-bar       566:410:186:6 off on
png finder.default-view     566:410:186:6 icon list column gallery
png finder.search-scope     566:300:186:6 mac folder previous

# Dock. A strip along the bottom of the screen, or the whole screen where
# the position is the point.
jpg dock.autohide        crop=1600:420:0:780 off on
jpg dock.recents         crop=1600:420:0:780 off on
jpg dock.minimize-to-app crop=1600:420:0:780 off on
jpg dock.position        scale=1200:900 left bottom right

# Screenshots.
png screenshot.format    566:200:186:6 png jpg heic pdf tiff
png screenshot.location  566:240:186:6 desktop downloads pictures
# The shadowless shot is padded to the size of the shadowed one, so the
# window sits in the same place in both.
png screenshot.shadow    - on
ffmpeg -loglevel error -y -i "$src/screenshot.shadow.off.png" -vf "format=rgba,pad=632:432:56:38:color=black@0" -frames:v 1 "$out/screenshot.shadow.off.png"
jpg screenshot.thumbnail crop=720:330:880:870 off on

# Typing. Just the note being typed, not the list of earlier notes.
for id in text.capitalize text.period text.smart-quotes text.smart-dashes; do
  png $id 476:220:572:44 off on
done

# Windows.
png windows.save-expanded - off
ffmpeg -loglevel error -y -i "$src/windows.save-expanded.on.png" -vf crop=880:448:0:68 -frames:v 1 "$out/windows.save-expanded.on.png"
png windows.scroll-bars 520:320:56:38 automatic scrolling always

# System. The part of System Settings that holds the switch.
png security.firewall 486:180:286:40 off on
png security.stealth  484:172:182:402 off on
png startup.chime     480:266:292:92 off on

print "Imported $(ls "$out" | wc -l | tr -d ' ') previews into $out"
