#!/bin/zsh
# Crops the second batch of raw macOS captures (see CAPTURE_BRIEF_2.md) and
# writes them to MacKit/Resources/Previews as <setting id>.<option>.<ext>.
#
#   Tools/import-captures-2.sh <folder of raw captures> [output folder]
#
# Raw captures are 1600x1200 full-screen frames and window shots. Only the
# settings listed here are imported: a set whose frames don't line up, or
# that shows clutter, is left without a preview. Settings that take a number
# are saved as <setting id>.v<number>.<ext>. Needs ffmpeg.

set -euo pipefail

src=${1:?usage: import-captures-2.sh <folder of raw captures> [output folder]}
out=${2:-${0:A:h:h}/MacKit/Resources/Previews}
mkdir -p "$out"

# One capture. shot <ext> <id> <filter> <source option> [saved option]
shot() {
  local ext=$1 id=$2 filter=$3 from=$4 to=${5:-$4}
  local quality=()
  [[ $ext == jpg ]] && quality=(-q:v 3)
  ffmpeg -loglevel error -y -i "$src/$id.$from.png" -vf "$filter" -frames:v 1 $quality "$out/$id.$to.$ext"
}

# png|jpg <id> <crop w:h:x:y, "-" for the whole image, or a full filter> <option>...
png() { local id=$1 f=$2; shift 2; for o in "$@"; do shot png $id "$(filter $f)" $o; done }
jpg() { local id=$1 f=$2; shift 2; for o in "$@"; do shot jpg $id "$(filter $f)" $o; done }
filter() {
  case $1 in
    -) print null ;;
    *=*) print -- $1 ;;
    *) print "crop=$1" ;;
  esac
}

toggle=(off on)
whole="scale=1200:900"

# Finder windows are 760x420. The sidebar is cropped away where it doesn't
# matter, and its lower half always is: it names the account.
list=574:414:186:6
png access.increase-contrast 760:290:0:0 $toggle
png access.title-icons       566:300:186:6 $toggle
png finder.path-in-title     566:300:186:6 $toggle
png finder.path-from-home    $list $toggle
png finder.preview-pane      $list $toggle
png finder.tab-bar           566:300:186:6 $toggle
png finder.sidebar-size      430:270:0:0 small medium large
png finder.group-by          $list none name kind application opened added modified created size tags
png screenshot.date          566:200:186:6 $toggle

# Finder menus, from full-screen frames.
png finder.quit               250:300:0:0 $toggle
png finder.block-empty-trash  250:300:0:0 $toggle
png finder.block-connect      330:262:220:270 $toggle
png finder.block-go-to-folder 330:262:220:270 $toggle
png finder.block-eject        330:300:100:330 $toggle
jpg finder.trash-warning      800:440:180:110 $toggle

# The desktop: the top right corner, where icons collect.
jpg desktop.items          560:400:1040:0 $toggle
jpg desktop.finder-draws   560:400:1040:0 $toggle
jpg desktop.folders-first  560:500:1040:0 $toggle
jpg desktop.external-disks 560:520:1040:0 $toggle
jpg desktop.hard-disks     560:630:1040:0 $toggle

# Stage Manager, Mission Control and tiling need the whole screen.
jpg stage.enabled       $whole $toggle
jpg stage.recent-apps   $whole $toggle
jpg stage.desktop-items $whole $toggle
jpg stage.grouping      $whole all one
jpg mission.group-apps  $whole $toggle
jpg tiling.margins      700:500:0:0 $toggle

# The Dock.
jpg dock.indicators     760:130:120:1070 $toggle
jpg dock.magnification  900:300:350:900 $toggle
jpg dock.only-open-apps 1600:200:0:1000 $toggle
jpg dock.stack-highlight 620:420:980:780 $toggle
jpg appearance.icon-style 820:140:160:1060 default default-light dark clear clear-light clear-dark tinted tinted-light tinted-dark
jpg appearance.icon-tint  820:140:160:1060 hardware red orange yellow green blue purple pink graphite
jpg dock.size            1600:300:0:900 v16 v32 v48 v64 v96 v128
jpg dock.magnified-size  900:300:350:900 v48 v64 v96 v128

# Look.
png appearance.accent 723:440:0:0 multicolor blue purple pink red orange yellow green graphite
jpg access.pointer-size 700:440:360:160 v1 v2 v3 v4

# The menu bar: a strip, so nothing on the desktop below it shows.
bar=560:36:1040:0
for id in clock.style; do jpg $id $bar digital analog; done
for id in clock.seconds clock.weekday clock.am-pm menubar.spotlight menubar.input-menu; do jpg $id $bar $toggle; done
jpg clock.date      $bar auto always never
jpg region.clock    $bar region 24 12
jpg menubar.spacing $bar standard compact tight
jpg menubar.background 800:40:800:0 $toggle
jpg menubar.autohide   800:200:0:0 $toggle
jpg safari.develop     800:36:0:0 $toggle

# Typing, in a 620x360 TextEdit window.
text=620:200:0:0
for id in text.autocorrect text.spell-check textedit.ruler textedit.rtf-as-code textedit.smart-links textedit.spelling; do
  png $id $text $toggle
done
png textedit.html-as-code 620:240:0:0 $toggle
png textedit.format    $text rich plain
png textedit.tab-width $text 2 4 8
png textedit.font-size $text v9 v11 v14 v18 v24 v36
png textedit.wrap-to-page 1000:520:0:0 $toggle

# Other apps.
png safari.favorites-bar 900:260:0:0 $toggle
png safari.full-url      900:200:0:0 $toggle
png safari.tab-layout    900:260:0:0 separate compact
jpg safari.status-bar    940:560:190:100 $toggle
png preview.sidebar 620:420:0:0 $toggle
png calendar.week-numbers 520:420:0:0 $toggle
png calendar.days 1000:300:0:0 7 5
png calendar.hours-shown 600:420:0:0 6 8 10 12 16
jpg screenshot.pointer 660:400:380:180 $toggle

# The firewall's options sheet.
png security.block-all       484:290:120:60 $toggle
png security.allow-built-in  484:134:120:400 $toggle
png security.allow-signed    484:134:120:400 $toggle

print "Imported into $out"
