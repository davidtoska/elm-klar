module Klar.Icon exposing
    ( Icon, Size(..), view, sized, labelled
    , custom, name, all
    , search, close, check, minus, plus, chevronDown, chevronUp, chevronLeft, chevronRight, chevronsLeft, chevronsRight, chevronsUpDown, arrowUp, arrowDown, arrowLeft, arrowRight, filter, moreHorizontal, moreVertical, grip, menu, sidebar, maximize, minimize, enter
    , info, warning, errorCircle, checkCircle, xCircle, help, ban, wifiOff, server
    , edit, trash, copy, save, download, upload, link, externalLink, print, refresh, undo, redo, send, play, pause
    , eye, eyeOff, lock, unlock, key, shield
    , settings, sliders, columns, grid, list, layers, table, home, building, briefcase, database
    , user, users, userPlus, mapPin, phone, mail, globe, logOut, logIn
    , folder, file, fileText, paperclip, image, archive, inbox, clipboard, clipboardCheck
    , calendar, calendarCheck, clock, history
    , bell, bookmark, star, flag, tag, heart, activity, barChart, pieChart, trendUp, trendDown, zap, command, keyboard, code, terminal, hash, atSign, percent, text
    )

{-| Line icons, drawn by CSS. An icon takes the text color of its parent and
scales with its `Size`, so it follows disabled, hover and danger states without
extra work.

    import Klar.Icon as Icon

    Icon.view Icon.search

    Icon.sized Icon.Large Icon.warning

    Icon.labelled "Delete" Icon.trash

Components take an `Icon` where they have room for one:

    Button.view [ Button.icon Icon.plus ] "New order"

Every icon is a plain value, so adding icons in later versions never breaks
existing code. The shapes live in the stylesheet (see [`Klar`](Klar)): an icon is
a CSS mask over an inline SVG, which is why the color comes from the text.

The built-in icons are based on [Feather](https://feathericons.com) and
[Lucide](https://lucide.dev); see `THIRD-PARTY-NOTICES.md` in the repository.


# Showing icons

@docs Icon, Size, view, sized, labelled


# Your own icons

@docs custom, name, all


# Navigation and controls

@docs search, close, check, minus, plus, chevronDown, chevronUp, chevronLeft, chevronRight, chevronsLeft, chevronsRight, chevronsUpDown, arrowUp, arrowDown, arrowLeft, arrowRight, filter, moreHorizontal, moreVertical, grip, menu, sidebar, maximize, minimize, enter


# Status

@docs info, warning, errorCircle, checkCircle, xCircle, help, ban, wifiOff, server


# Actions

@docs edit, trash, copy, save, download, upload, link, externalLink, print, refresh, undo, redo, send, play, pause


# Visibility and security

@docs eye, eyeOff, lock, unlock, key, shield


# Layout and objects

@docs settings, sliders, columns, grid, list, layers, table, home, building, briefcase, database


# People and contact

@docs user, users, userPlus, mapPin, phone, mail, globe, logOut, logIn


# Files

@docs folder, file, fileText, paperclip, image, archive, inbox, clipboard, clipboardCheck


# Time

@docs calendar, calendarCheck, clock, history


# Marks and miscellaneous

@docs bell, bookmark, star, flag, tag, heart, activity, barChart, pieChart, trendUp, trendDown, zap, command, keyboard, code, terminal, hash, atSign, percent, text

-}

import Html exposing (Html)
import Html.Attributes as Attr
import Klar.Internal as Internal


{-| One icon. Take it from the list below, or make your own with `custom`.
-}
type Icon
    = Icon String


{-| The sizes of an icon: 12, 14, 16 (the default), 20, 24 and 32 pixels.
-}
type Size
    = ExtraSmall
    | Small
    | Medium
    | Large
    | ExtraLarge
    | Huge


{-| A decorative icon (hidden from assistive technology), 16px.

Use it next to a text that says the same thing. An icon that stands alone needs
`labelled`.

-}
view : Icon -> Html msg
view =
    sized Medium


{-| A decorative icon in a given size.

    Icon.sized Icon.ExtraLarge Icon.inbox

-}
sized : Size -> Icon -> Html msg
sized size icon =
    Html.span
        [ Internal.cls [ "klar-icon", "klar-icon--" ++ name icon, sizeClass size ]
        , Attr.attribute "aria-hidden" "true"
        ]
        []


{-| An icon that carries meaning on its own: it gets an accessible name.

    Icon.labelled "Overdue" Icon.warning

-}
labelled : String -> Icon -> Html msg
labelled label icon =
    Html.span
        [ Internal.cls [ "klar-icon", "klar-icon--" ++ name icon ]
        , Attr.attribute "role" "img"
        , Attr.attribute "aria-label" label
        ]
        []


sizeClass : Size -> String
sizeClass size =
    case size of
        ExtraSmall ->
            "klar-icon--xs"

        Small ->
            "klar-icon--sm"

        Medium ->
            ""

        Large ->
            "klar-icon--lg"

        ExtraLarge ->
            "klar-icon--xl"

        Huge ->
            "klar-icon--xxl"


{-| An icon you ship yourself. `custom "invoice"` renders the CSS class
`klar-icon--invoice`, so define the shape in your own stylesheet as a mask
image on the custom property `--klar-icon`:

    .klar-icon--invoice {
      --klar-icon: url("data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24'>...</svg>");
    }

Use a 24 by 24 view box and draw with black strokes; the mask turns them into
the text color. Until the rule exists the icon shows as a dashed box, so a
missing shape is easy to spot.

-}
custom : String -> Icon
custom iconName =
    Icon iconName


{-| The CSS name of an icon. The class of an icon is `klar-icon--<name>`.

    Icon.name Icon.chevronDown --> "chevron-down"

-}
name : Icon -> String
name (Icon iconName) =
    iconName


{-| Every built-in icon, in the order of the groups below. For galleries and
tests.
-}
all : List Icon
all =
    [ search
    , close
    , check
    , minus
    , plus
    , chevronDown
    , chevronUp
    , chevronLeft
    , chevronRight
    , chevronsLeft
    , chevronsRight
    , chevronsUpDown
    , arrowUp
    , arrowDown
    , arrowLeft
    , arrowRight
    , filter
    , moreHorizontal
    , moreVertical
    , grip
    , menu
    , sidebar
    , maximize
    , minimize
    , enter
    , info
    , warning
    , errorCircle
    , checkCircle
    , xCircle
    , help
    , ban
    , wifiOff
    , server
    , edit
    , trash
    , copy
    , save
    , download
    , upload
    , link
    , externalLink
    , print
    , refresh
    , undo
    , redo
    , send
    , play
    , pause
    , eye
    , eyeOff
    , lock
    , unlock
    , key
    , shield
    , settings
    , sliders
    , columns
    , grid
    , list
    , layers
    , table
    , home
    , building
    , briefcase
    , database
    , user
    , users
    , userPlus
    , mapPin
    , phone
    , mail
    , globe
    , logOut
    , logIn
    , folder
    , file
    , fileText
    , paperclip
    , image
    , archive
    , inbox
    , clipboard
    , clipboardCheck
    , calendar
    , calendarCheck
    , clock
    , history
    , bell
    , bookmark
    , star
    , flag
    , tag
    , heart
    , activity
    , barChart
    , pieChart
    , trendUp
    , trendDown
    , zap
    , command
    , keyboard
    , code
    , terminal
    , hash
    , atSign
    , percent
    , text
    ]



-- THE ICONS


{-| A magnifying glass.
-}
search : Icon
search =
    Icon "search"


{-| A cross, for closing or removing.
-}
close : Icon
close =
    Icon "close"


{-| A check mark.
-}
check : Icon
check =
    Icon "check"


{-| A minus sign.
-}
minus : Icon
minus =
    Icon "minus"


{-| A plus sign.
-}
plus : Icon
plus =
    Icon "plus"


{-| A chevron pointing down.
-}
chevronDown : Icon
chevronDown =
    Icon "chevron-down"


{-| A chevron pointing up.
-}
chevronUp : Icon
chevronUp =
    Icon "chevron-up"


{-| A chevron pointing left.
-}
chevronLeft : Icon
chevronLeft =
    Icon "chevron-left"


{-| A chevron pointing right.
-}
chevronRight : Icon
chevronRight =
    Icon "chevron-right"


{-| A double chevron pointing left (first page).
-}
chevronsLeft : Icon
chevronsLeft =
    Icon "chevrons-left"


{-| A double chevron pointing right (last page).
-}
chevronsRight : Icon
chevronsRight =
    Icon "chevrons-right"


{-| Chevrons pointing up and down, for sortable and selectable fields.
-}
chevronsUpDown : Icon
chevronsUpDown =
    Icon "chevrons-up-down"


{-| An arrow pointing up.
-}
arrowUp : Icon
arrowUp =
    Icon "arrow-up"


{-| An arrow pointing down.
-}
arrowDown : Icon
arrowDown =
    Icon "arrow-down"


{-| An arrow pointing left.
-}
arrowLeft : Icon
arrowLeft =
    Icon "arrow-left"


{-| An arrow pointing right.
-}
arrowRight : Icon
arrowRight =
    Icon "arrow-right"


{-| A funnel.
-}
filter : Icon
filter =
    Icon "filter"


{-| Three horizontal dots.
-}
moreHorizontal : Icon
moreHorizontal =
    Icon "more-horizontal"


{-| Three vertical dots.
-}
moreVertical : Icon
moreVertical =
    Icon "more-vertical"


{-| A grid of dots, used as a drag handle.
-}
grip : Icon
grip =
    Icon "grip"


{-| Three horizontal bars (the menu icon).
-}
menu : Icon
menu =
    Icon "menu"


{-| A window with a sidebar on the left.
-}
sidebar : Icon
sidebar =
    Icon "sidebar"


{-| Arrows pointing out to the corners.
-}
maximize : Icon
maximize =
    Icon "maximize"


{-| Arrows pointing in towards the center.
-}
minimize : Icon
minimize =
    Icon "minimize"


{-| The arrow of the Enter key.
-}
enter : Icon
enter =
    Icon "enter"


{-| A circle with an i.
-}
info : Icon
info =
    Icon "info"


{-| A triangle with an exclamation mark.
-}
warning : Icon
warning =
    Icon "warning"


{-| A circle with an exclamation mark.
-}
errorCircle : Icon
errorCircle =
    Icon "error-circle"


{-| A circle with a check mark.
-}
checkCircle : Icon
checkCircle =
    Icon "check-circle"


{-| A circle with a cross.
-}
xCircle : Icon
xCircle =
    Icon "x-circle"


{-| A circle with a question mark.
-}
help : Icon
help =
    Icon "help"


{-| A circle with a diagonal line: not allowed.
-}
ban : Icon
ban =
    Icon "ban"


{-| A crossed-out wireless signal: offline.
-}
wifiOff : Icon
wifiOff =
    Icon "wifi-off"


{-| A server rack.
-}
server : Icon
server =
    Icon "server"


{-| A pencil.
-}
edit : Icon
edit =
    Icon "edit"


{-| A trash can.
-}
trash : Icon
trash =
    Icon "trash"


{-| Two overlapping sheets.
-}
copy : Icon
copy =
    Icon "copy"


{-| A floppy disk.
-}
save : Icon
save =
    Icon "save"


{-| A tray with an arrow pointing down.
-}
download : Icon
download =
    Icon "download"


{-| A tray with an arrow pointing up.
-}
upload : Icon
upload =
    Icon "upload"


{-| Two chain links.
-}
link : Icon
link =
    Icon "link"


{-| An arrow leaving a box: opens elsewhere.
-}
externalLink : Icon
externalLink =
    Icon "external-link"


{-| A printer.
-}
print : Icon
print =
    Icon "print"


{-| Two arrows in a circle.
-}
refresh : Icon
refresh =
    Icon "refresh"


{-| A curved arrow pointing back.
-}
undo : Icon
undo =
    Icon "undo"


{-| A curved arrow pointing forward.
-}
redo : Icon
redo =
    Icon "redo"


{-| A paper plane.
-}
send : Icon
send =
    Icon "send"


{-| A play triangle.
-}
play : Icon
play =
    Icon "play"


{-| Two vertical bars.
-}
pause : Icon
pause =
    Icon "pause"


{-| An open eye.
-}
eye : Icon
eye =
    Icon "eye"


{-| A crossed-out eye.
-}
eyeOff : Icon
eyeOff =
    Icon "eye-off"


{-| A closed padlock.
-}
lock : Icon
lock =
    Icon "lock"


{-| An open padlock.
-}
unlock : Icon
unlock =
    Icon "unlock"


{-| A key.
-}
key : Icon
key =
    Icon "key"


{-| A shield.
-}
shield : Icon
shield =
    Icon "shield"


{-| A cog wheel.
-}
settings : Icon
settings =
    Icon "settings"


{-| Horizontal sliders.
-}
sliders : Icon
sliders =
    Icon "sliders"


{-| Vertical columns, for choosing table columns.
-}
columns : Icon
columns =
    Icon "columns"


{-| A grid of four squares.
-}
grid : Icon
grid =
    Icon "grid"


{-| A bulleted list.
-}
list : Icon
list =
    Icon "list"


{-| Stacked layers.
-}
layers : Icon
layers =
    Icon "layers"


{-| A table.
-}
table : Icon
table =
    Icon "table"


{-| A house.
-}
home : Icon
home =
    Icon "home"


{-| An office building.
-}
building : Icon
building =
    Icon "building"


{-| A briefcase.
-}
briefcase : Icon
briefcase =
    Icon "briefcase"


{-| A database cylinder.
-}
database : Icon
database =
    Icon "database"


{-| A person.
-}
user : Icon
user =
    Icon "user"


{-| A group of people.
-}
users : Icon
users =
    Icon "users"


{-| A person with a plus sign.
-}
userPlus : Icon
userPlus =
    Icon "user-plus"


{-| A map pin.
-}
mapPin : Icon
mapPin =
    Icon "map-pin"


{-| A telephone handset.
-}
phone : Icon
phone =
    Icon "phone"


{-| An envelope.
-}
mail : Icon
mail =
    Icon "mail"


{-| A globe.
-}
globe : Icon
globe =
    Icon "globe"


{-| An arrow leaving a door.
-}
logOut : Icon
logOut =
    Icon "log-out"


{-| An arrow entering a door.
-}
logIn : Icon
logIn =
    Icon "log-in"


{-| A folder.
-}
folder : Icon
folder =
    Icon "folder"


{-| A blank sheet.
-}
file : Icon
file =
    Icon "file"


{-| A sheet with lines of text.
-}
fileText : Icon
fileText =
    Icon "file-text"


{-| A paperclip.
-}
paperclip : Icon
paperclip =
    Icon "paperclip"


{-| A picture.
-}
image : Icon
image =
    Icon "image"


{-| An archive box.
-}
archive : Icon
archive =
    Icon "archive"


{-| An inbox tray.
-}
inbox : Icon
inbox =
    Icon "inbox"


{-| A clipboard.
-}
clipboard : Icon
clipboard =
    Icon "clipboard"


{-| A clipboard with a check mark.
-}
clipboardCheck : Icon
clipboardCheck =
    Icon "clipboard-check"


{-| A calendar.
-}
calendar : Icon
calendar =
    Icon "calendar"


{-| A calendar with a check mark.
-}
calendarCheck : Icon
calendarCheck =
    Icon "calendar-check"


{-| A clock face.
-}
clock : Icon
clock =
    Icon "clock"


{-| A clock with an arrow running counter-clockwise.
-}
history : Icon
history =
    Icon "history"


{-| A bell.
-}
bell : Icon
bell =
    Icon "bell"


{-| A bookmark.
-}
bookmark : Icon
bookmark =
    Icon "bookmark"


{-| A star.
-}
star : Icon
star =
    Icon "star"


{-| A flag.
-}
flag : Icon
flag =
    Icon "flag"


{-| A price tag.
-}
tag : Icon
tag =
    Icon "tag"


{-| A heart.
-}
heart : Icon
heart =
    Icon "heart"


{-| A pulse line.
-}
activity : Icon
activity =
    Icon "activity"


{-| A bar chart.
-}
barChart : Icon
barChart =
    Icon "bar-chart"


{-| A pie chart.
-}
pieChart : Icon
pieChart =
    Icon "pie-chart"


{-| A line trending up.
-}
trendUp : Icon
trendUp =
    Icon "trend-up"


{-| A line trending down.
-}
trendDown : Icon
trendDown =
    Icon "trend-down"


{-| A lightning bolt.
-}
zap : Icon
zap =
    Icon "zap"


{-| The Command key symbol.
-}
command : Icon
command =
    Icon "command"


{-| A keyboard.
-}
keyboard : Icon
keyboard =
    Icon "keyboard"


{-| Angle brackets.
-}
code : Icon
code =
    Icon "code"


{-| A terminal prompt.
-}
terminal : Icon
terminal =
    Icon "terminal"


{-| A hash sign.
-}
hash : Icon
hash =
    Icon "hash"


{-| An at sign.
-}
atSign : Icon
atSign =
    Icon "at-sign"


{-| A percent sign.
-}
percent : Icon
percent =
    Icon "percent"


{-| The letter T, for text and typography.
-}
text : Icon
text =
    Icon "text"
