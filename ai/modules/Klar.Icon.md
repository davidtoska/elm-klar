# Klar.Icon

Line icons.

Import: `import Klar.Icon as Icon` | Group: Foundations

Types: `Icon`, `Size`

## Signatures

```elm
-- Showing icons
type Icon  -- opaque: no constructors are exposed
type Size = ExtraSmall | Small | Medium | Large | ExtraLarge | Huge
view : Icon -> Html msg
sized : Size -> Icon -> Html msg
labelled : String -> Icon -> Html msg

-- Your own icons
fromSvg : String -> String -> Icon
custom : String -> Icon
name : Icon -> String
all : List Icon

-- Navigation and controls
search : Icon
close : Icon
check : Icon
minus : Icon
plus : Icon
chevronDown : Icon
chevronUp : Icon
chevronLeft : Icon
chevronRight : Icon
chevronsLeft : Icon
chevronsRight : Icon
chevronsUpDown : Icon
arrowUp : Icon
arrowDown : Icon
arrowLeft : Icon
arrowRight : Icon
filter : Icon
moreHorizontal : Icon
moreVertical : Icon
grip : Icon
menu : Icon
sidebar : Icon
maximize : Icon
minimize : Icon
enter : Icon
arrowUpRight : Icon
arrowDownRight : Icon
arrowUpDown : Icon
arrowLeftRight : Icon
chevronsUp : Icon
chevronsDown : Icon
sortAscending : Icon
sortDescending : Icon
zoomIn : Icon
zoomOut : Icon
move : Icon
reply : Icon
forward : Icon
loader : Icon
power : Icon
toggleLeft : Icon
toggleRight : Icon

-- Status
info : Icon
warning : Icon
errorCircle : Icon
checkCircle : Icon
xCircle : Icon
help : Icon
ban : Icon
wifiOff : Icon
server : Icon
alertOctagon : Icon
plusCircle : Icon
minusCircle : Icon
checkSquare : Icon
square : Icon
circle : Icon
checkCheck : Icon
asterisk : Icon

-- Actions
edit : Icon
trash : Icon
copy : Icon
save : Icon
download : Icon
upload : Icon
link : Icon
externalLink : Icon
print : Icon
refresh : Icon
undo : Icon
redo : Icon
send : Icon
play : Icon
pause : Icon
share : Icon
unlink : Icon
scissors : Icon
wrench : Icon

-- Visibility and security
eye : Icon
eyeOff : Icon
lock : Icon
unlock : Icon
key : Icon
shield : Icon
shieldCheck : Icon

-- Layout and objects
settings : Icon
sliders : Icon
columns : Icon
grid : Icon
list : Icon
layers : Icon
table : Icon
home : Icon
building : Icon
briefcase : Icon
database : Icon
layout : Icon
rows : Icon
dashboard : Icon
map : Icon
listTree : Icon

-- People and contact
user : Icon
users : Icon
userPlus : Icon
mapPin : Icon
phone : Icon
mail : Icon
globe : Icon
logOut : Icon
logIn : Icon
userCheck : Icon
userX : Icon
userCircle : Icon
messageSquare : Icon

-- Files
folder : Icon
file : Icon
fileText : Icon
paperclip : Icon
image : Icon
archive : Icon
inbox : Icon
clipboard : Icon
clipboardCheck : Icon
filePlus : Icon
fileMinus : Icon
folderPlus : Icon
folderOpen : Icon
book : Icon

-- Time
calendar : Icon
calendarCheck : Icon
clock : Icon
history : Icon
hourglass : Icon

-- Marks and miscellaneous
bell : Icon
bookmark : Icon
star : Icon
flag : Icon
tag : Icon
heart : Icon
activity : Icon
barChart : Icon
pieChart : Icon
trendUp : Icon
trendDown : Icon
zap : Icon
command : Icon
keyboard : Icon
code : Icon
terminal : Icon
hash : Icon
atSign : Icon
percent : Icon
text : Icon
pin : Icon
lightbulb : Icon
sigma : Icon
braces : Icon
gitBranch : Icon
gitCommit : Icon
sun : Icon
moon : Icon

-- Devices and network
wifi : Icon
cloud : Icon
hardDrive : Icon
monitor : Icon
smartphone : Icon
camera : Icon

-- Text formatting
bold : Icon
italic : Icon
underline : Icon
strikethrough : Icon
heading : Icon
alignLeft : Icon
alignCenter : Icon
alignRight : Icon
listOrdered : Icon

-- Commerce and logistics
package : Icon
truck : Icon
warehouse : Icon
shoppingCart : Icon
shoppingBag : Icon
creditCard : Icon
dollarSign : Icon
receipt : Icon
barcode : Icon
calculator : Icon
```

## Documentation

Line icons. An icon takes the text color of its parent and scales with its
`Size`, so it follows disabled, hover and danger states without extra work.

    import Klar.Icon as Icon

    Icon.view Icon.search

    Icon.sized Icon.Large Icon.warning

    Icon.labelled "Delete" Icon.trash

Components take an `Icon` where they have room for one:

    Button.view [ Button.icon Icon.plus ] "New order"

Every icon is a plain value that carries its own drawing, so adding icons in later
versions never breaks existing code, and `elm make --optimize` leaves out every
icon your application does not use. An icon is drawn as a CSS mask over its SVG,
which is why the color comes from the text; the frame of that mask is in the
stylesheet (see [`Klar`](Klar.md)).

This module has the icons that components and applications use all the time. The
rest of the library, more than 300 icons, is in the modules
`Klar.Icon.Arrows`, `Klar.Icon.Business`, `Klar.Icon.Calendar` and so on; they are
listed in `Klar.Icon.Library`. All icons are one family: a 24 by 24 grid, a 2 pixel
stroke, round ends and corners, no fill.

The built-in icons are based on [Feather](https://feathericons.com) and
[Lucide](https://lucide.dev); see `THIRD-PARTY-NOTICES.md` in the repository.

## Showing icons

### `Icon`

```elm
type Icon  -- opaque: no constructors are exposed
```

One icon. Take it from the list below, or make your own with `fromSvg`.

### `Size`

```elm
type Size = ExtraSmall | Small | Medium | Large | ExtraLarge | Huge
```

The sizes of an icon: 12, 14, 16 (the default), 20, 24 and 32 pixels.

### `view`

```elm
view : Icon -> Html msg
```

A decorative icon (hidden from assistive technology), 16px.

Use it next to a text that says the same thing. An icon that stands alone needs
`labelled`.

### `sized`

```elm
sized : Size -> Icon -> Html msg
```

A decorative icon in a given size.

    Icon.sized Icon.ExtraLarge Icon.inbox

### `labelled`

```elm
labelled : String -> Icon -> Html msg
```

An icon that carries meaning on its own: it gets an accessible name.

    Icon.labelled "Overdue" Icon.warning

## Your own icons

### `fromSvg`

```elm
fromSvg : String -> String -> Icon
```

An icon you draw yourself, from the inside of an SVG. Give it a name and the
shapes, drawn on a 24 by 24 grid with strokes only (the mask turns them into the
text color):

    invoice : Icon
    invoice =
        Icon.fromSvg "invoice"
            "<path d='M6 2h9l5 5v15H6z'/><path d='M9 13h8M9 17h8'/>"

Use single quotes inside the markup. The icons of this library are made the same
way, with a 2 pixel stroke and round ends and corners (`stroke-width`,
`stroke-linecap` and `stroke-linejoin` are set for you), so yours will fit in.

### `custom`

```elm
custom : String -> Icon
```

An icon whose drawing is in your own stylesheet. `custom "invoice"` renders the
CSS class `klar-icon--invoice`; define the shape there as a mask image on the
custom property `--klar-icon`:

    .klar-icon--invoice {
      --klar-icon: url("data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24'>...</svg>");
    }

Use a 24 by 24 view box and draw with black strokes. Until the rule exists the
icon shows as a dashed box, so a missing shape is easy to spot. Prefer `fromSvg`
when you can: it needs no stylesheet.

### `name`

```elm
name : Icon -> String
```

The name of an icon. The class of an icon is `klar-icon--<name>`.

    Icon.name Icon.chevronDown --> "chevron-down"

### `all`

```elm
all : List Icon
```

Every icon of this module, in the order of the groups below. For galleries and
tests. `Klar.Icon.Library.all` has the whole library.

## Navigation and controls

### `search`

```elm
search : Icon
```

A magnifying glass.

### `close`

```elm
close : Icon
```

A cross, for closing or removing.

### `check`

```elm
check : Icon
```

A check mark.

### `minus`

```elm
minus : Icon
```

A minus sign.

### `plus`

```elm
plus : Icon
```

A plus sign.

### `chevronDown`

```elm
chevronDown : Icon
```

A chevron pointing down.

### `chevronUp`

```elm
chevronUp : Icon
```

A chevron pointing up.

### `chevronLeft`

```elm
chevronLeft : Icon
```

A chevron pointing left.

### `chevronRight`

```elm
chevronRight : Icon
```

A chevron pointing right.

### `chevronsLeft`

```elm
chevronsLeft : Icon
```

A double chevron pointing left (first page).

### `chevronsRight`

```elm
chevronsRight : Icon
```

A double chevron pointing right (last page).

### `chevronsUpDown`

```elm
chevronsUpDown : Icon
```

Chevrons pointing up and down, for sortable and selectable fields.

### `arrowUp`

```elm
arrowUp : Icon
```

An arrow pointing up.

### `arrowDown`

```elm
arrowDown : Icon
```

An arrow pointing down.

### `arrowLeft`

```elm
arrowLeft : Icon
```

An arrow pointing left.

### `arrowRight`

```elm
arrowRight : Icon
```

An arrow pointing right.

### `filter`

```elm
filter : Icon
```

A funnel.

### `moreHorizontal`

```elm
moreHorizontal : Icon
```

Three horizontal dots.

### `moreVertical`

```elm
moreVertical : Icon
```

Three vertical dots.

### `grip`

```elm
grip : Icon
```

A grid of dots, used as a drag handle.

### `menu`

```elm
menu : Icon
```

Three horizontal bars (the menu icon).

### `sidebar`

```elm
sidebar : Icon
```

A window with a sidebar on the left.

### `maximize`

```elm
maximize : Icon
```

Arrows pointing out to the corners.

### `minimize`

```elm
minimize : Icon
```

Arrows pointing in towards the center.

### `enter`

```elm
enter : Icon
```

The arrow of the Enter key.

### `arrowUpRight`

```elm
arrowUpRight : Icon
```

An arrow pointing to the upper right.

### `arrowDownRight`

```elm
arrowDownRight : Icon
```

An arrow pointing to the lower right.

### `arrowUpDown`

```elm
arrowUpDown : Icon
```

Two arrows, one up and one down.

### `arrowLeftRight`

```elm
arrowLeftRight : Icon
```

Two arrows, one left and one right: swap or transfer.

### `chevronsUp`

```elm
chevronsUp : Icon
```

A double chevron pointing up.

### `chevronsDown`

```elm
chevronsDown : Icon
```

A double chevron pointing down.

### `sortAscending`

```elm
sortAscending : Icon
```

Bars growing longer with an arrow pointing up: sorted ascending.

### `sortDescending`

```elm
sortDescending : Icon
```

Bars growing shorter with an arrow pointing down: sorted descending.

### `zoomIn`

```elm
zoomIn : Icon
```

A magnifying glass with a plus sign.

### `zoomOut`

```elm
zoomOut : Icon
```

A magnifying glass with a minus sign.

### `move`

```elm
move : Icon
```

Four arrows pointing out: move or pan.

### `reply`

```elm
reply : Icon
```

An arrow curving back: reply.

### `forward`

```elm
forward : Icon
```

An arrow curving forward: forward or pass on.

### `loader`

```elm
loader : Icon
```

Eight spokes, for something in progress. Static: it does not spin by itself.

### `power`

```elm
power : Icon
```

The power symbol.

### `toggleLeft`

```elm
toggleLeft : Icon
```

A switch in the off position.

### `toggleRight`

```elm
toggleRight : Icon
```

A switch in the on position.

## Status

### `info`

```elm
info : Icon
```

A circle with an i.

### `warning`

```elm
warning : Icon
```

A triangle with an exclamation mark.

### `errorCircle`

```elm
errorCircle : Icon
```

A circle with an exclamation mark.

### `checkCircle`

```elm
checkCircle : Icon
```

A circle with a check mark.

### `xCircle`

```elm
xCircle : Icon
```

A circle with a cross.

### `help`

```elm
help : Icon
```

A circle with a question mark.

### `ban`

```elm
ban : Icon
```

A circle with a diagonal line: not allowed.

### `wifiOff`

```elm
wifiOff : Icon
```

A crossed-out wireless signal: offline.

### `server`

```elm
server : Icon
```

A server rack.

### `alertOctagon`

```elm
alertOctagon : Icon
```

An octagon with an exclamation mark: a stop or a serious error.

### `plusCircle`

```elm
plusCircle : Icon
```

A circle with a plus sign.

### `minusCircle`

```elm
minusCircle : Icon
```

A circle with a minus sign.

### `checkSquare`

```elm
checkSquare : Icon
```

A box with a check mark.

### `square`

```elm
square : Icon
```

An empty box.

### `circle`

```elm
circle : Icon
```

An empty circle.

### `checkCheck`

```elm
checkCheck : Icon
```

Two check marks: done and confirmed.

### `asterisk`

```elm
asterisk : Icon
```

An asterisk, for required fields.

## Actions

### `edit`

```elm
edit : Icon
```

A pencil.

### `trash`

```elm
trash : Icon
```

A trash can.

### `copy`

```elm
copy : Icon
```

Two overlapping sheets.

### `save`

```elm
save : Icon
```

A floppy disk.

### `download`

```elm
download : Icon
```

A tray with an arrow pointing down.

### `upload`

```elm
upload : Icon
```

A tray with an arrow pointing up.

### `link`

```elm
link : Icon
```

Two chain links.

### `externalLink`

```elm
externalLink : Icon
```

An arrow leaving a box: opens elsewhere.

### `print`

```elm
print : Icon
```

A printer.

### `refresh`

```elm
refresh : Icon
```

Two arrows in a circle.

### `undo`

```elm
undo : Icon
```

A curved arrow pointing back.

### `redo`

```elm
redo : Icon
```

A curved arrow pointing forward.

### `send`

```elm
send : Icon
```

A paper plane.

### `play`

```elm
play : Icon
```

A play triangle.

### `pause`

```elm
pause : Icon
```

Two vertical bars.

### `share`

```elm
share : Icon
```

Three connected dots.

### `unlink`

```elm
unlink : Icon
```

A broken chain.

### `scissors`

```elm
scissors : Icon
```

A pair of scissors.

### `wrench`

```elm
wrench : Icon
```

A wrench.

## Visibility and security

### `eye`

```elm
eye : Icon
```

An open eye.

### `eyeOff`

```elm
eyeOff : Icon
```

A crossed-out eye.

### `lock`

```elm
lock : Icon
```

A closed padlock.

### `unlock`

```elm
unlock : Icon
```

An open padlock.

### `key`

```elm
key : Icon
```

A key.

### `shield`

```elm
shield : Icon
```

A shield.

### `shieldCheck`

```elm
shieldCheck : Icon
```

A shield with a check mark.

## Layout and objects

### `settings`

```elm
settings : Icon
```

A cog wheel.

### `sliders`

```elm
sliders : Icon
```

Horizontal sliders.

### `columns`

```elm
columns : Icon
```

Vertical columns, for choosing table columns.

### `grid`

```elm
grid : Icon
```

A grid of four squares.

### `list`

```elm
list : Icon
```

A bulleted list.

### `layers`

```elm
layers : Icon
```

Stacked layers.

### `table`

```elm
table : Icon
```

A table.

### `home`

```elm
home : Icon
```

A house.

### `building`

```elm
building : Icon
```

An office building.

### `briefcase`

```elm
briefcase : Icon
```

A briefcase.

### `database`

```elm
database : Icon
```

A database cylinder.

### `layout`

```elm
layout : Icon
```

A window with a header and a sidebar.

### `rows`

```elm
rows : Icon
```

A box split into horizontal rows.

### `dashboard`

```elm
dashboard : Icon
```

Four tiles of different sizes.

### `map`

```elm
map : Icon
```

A folded map.

### `listTree`

```elm
listTree : Icon
```

Lines of text hanging off a trunk: a tree view.

## People and contact

### `user`

```elm
user : Icon
```

A person.

### `users`

```elm
users : Icon
```

A group of people.

### `userPlus`

```elm
userPlus : Icon
```

A person with a plus sign.

### `mapPin`

```elm
mapPin : Icon
```

A map pin.

### `phone`

```elm
phone : Icon
```

A telephone handset.

### `mail`

```elm
mail : Icon
```

An envelope.

### `globe`

```elm
globe : Icon
```

A globe.

### `logOut`

```elm
logOut : Icon
```

An arrow leaving a door.

### `logIn`

```elm
logIn : Icon
```

An arrow entering a door.

### `userCheck`

```elm
userCheck : Icon
```

A person with a check mark.

### `userX`

```elm
userX : Icon
```

A person with a cross.

### `userCircle`

```elm
userCircle : Icon
```

A person in a circle: an avatar.

### `messageSquare`

```elm
messageSquare : Icon
```

A speech bubble.

## Files

### `folder`

```elm
folder : Icon
```

A folder.

### `file`

```elm
file : Icon
```

A blank sheet.

### `fileText`

```elm
fileText : Icon
```

A sheet with lines of text.

### `paperclip`

```elm
paperclip : Icon
```

A paperclip.

### `image`

```elm
image : Icon
```

A picture.

### `archive`

```elm
archive : Icon
```

An archive box.

### `inbox`

```elm
inbox : Icon
```

An inbox tray.

### `clipboard`

```elm
clipboard : Icon
```

A clipboard.

### `clipboardCheck`

```elm
clipboardCheck : Icon
```

A clipboard with a check mark.

### `filePlus`

```elm
filePlus : Icon
```

A sheet with a plus sign.

### `fileMinus`

```elm
fileMinus : Icon
```

A sheet with a minus sign.

### `folderPlus`

```elm
folderPlus : Icon
```

A folder with a plus sign.

### `folderOpen`

```elm
folderOpen : Icon
```

An open folder.

### `book`

```elm
book : Icon
```

A closed book.

## Time

### `calendar`

```elm
calendar : Icon
```

A calendar.

### `calendarCheck`

```elm
calendarCheck : Icon
```

A calendar with a check mark.

### `clock`

```elm
clock : Icon
```

A clock face.

### `history`

```elm
history : Icon
```

A clock with an arrow running counter-clockwise.

### `hourglass`

```elm
hourglass : Icon
```

An hourglass.

## Marks and miscellaneous

### `bell`

```elm
bell : Icon
```

A bell.

### `bookmark`

```elm
bookmark : Icon
```

A bookmark.

### `star`

```elm
star : Icon
```

A star.

### `flag`

```elm
flag : Icon
```

A flag.

### `tag`

```elm
tag : Icon
```

A price tag.

### `heart`

```elm
heart : Icon
```

A heart.

### `activity`

```elm
activity : Icon
```

A pulse line.

### `barChart`

```elm
barChart : Icon
```

A bar chart.

### `pieChart`

```elm
pieChart : Icon
```

A pie chart.

### `trendUp`

```elm
trendUp : Icon
```

A line trending up.

### `trendDown`

```elm
trendDown : Icon
```

A line trending down.

### `zap`

```elm
zap : Icon
```

A lightning bolt.

### `command`

```elm
command : Icon
```

The Command key symbol.

### `keyboard`

```elm
keyboard : Icon
```

A keyboard.

### `code`

```elm
code : Icon
```

Angle brackets.

### `terminal`

```elm
terminal : Icon
```

A terminal prompt.

### `hash`

```elm
hash : Icon
```

A hash sign.

### `atSign`

```elm
atSign : Icon
```

An at sign.

### `percent`

```elm
percent : Icon
```

A percent sign.

### `text`

```elm
text : Icon
```

The letter T, for text and typography.

### `pin`

```elm
pin : Icon
```

A push pin, for pinned items.

### `lightbulb`

```elm
lightbulb : Icon
```

A light bulb.

### `sigma`

```elm
sigma : Icon
```

The sum sign, for totals and aggregates.

### `braces`

```elm
braces : Icon
```

Curly braces, for JSON and objects.

### `gitBranch`

```elm
gitBranch : Icon
```

A line that forks.

### `gitCommit`

```elm
gitCommit : Icon
```

A dot on a line: one step in a history.

### `sun`

```elm
sun : Icon
```

A sun.

### `moon`

```elm
moon : Icon
```

A crescent moon.

## Devices and network

### `wifi`

```elm
wifi : Icon
```

A wireless signal.

### `cloud`

```elm
cloud : Icon
```

A cloud.

### `hardDrive`

```elm
hardDrive : Icon
```

A hard drive.

### `monitor`

```elm
monitor : Icon
```

A desktop screen.

### `smartphone`

```elm
smartphone : Icon
```

A mobile phone.

### `camera`

```elm
camera : Icon
```

A camera.

## Text formatting

### `bold`

```elm
bold : Icon
```

A bold B.

### `italic`

```elm
italic : Icon
```

An italic I.

### `underline`

```elm
underline : Icon
```

An underlined U.

### `strikethrough`

```elm
strikethrough : Icon
```

A struck-through S.

### `heading`

```elm
heading : Icon
```

The letter H, for headings.

### `alignLeft`

```elm
alignLeft : Icon
```

Lines of text aligned to the left.

### `alignCenter`

```elm
alignCenter : Icon
```

Lines of text centered.

### `alignRight`

```elm
alignRight : Icon
```

Lines of text aligned to the right.

### `listOrdered`

```elm
listOrdered : Icon
```

A numbered list.

## Commerce and logistics

### `package`

```elm
package : Icon
```

A parcel.

### `truck`

```elm
truck : Icon
```

A delivery truck.

### `warehouse`

```elm
warehouse : Icon
```

A warehouse.

### `shoppingCart`

```elm
shoppingCart : Icon
```

A shopping cart.

### `shoppingBag`

```elm
shoppingBag : Icon
```

A shopping bag.

### `creditCard`

```elm
creditCard : Icon
```

A payment card.

### `dollarSign`

```elm
dollarSign : Icon
```

A dollar sign, for money.

### `receipt`

```elm
receipt : Icon
```

A receipt.

### `barcode`

```elm
barcode : Icon
```

A barcode.

### `calculator`

```elm
calculator : Icon
```

A calculator.
