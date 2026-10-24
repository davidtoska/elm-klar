module Klar.Icon exposing
    ( Icon, Size(..), view, sized, labelled
    , fromSvg, custom, name, all
    , search, close, check, minus, plus, chevronDown, chevronUp, chevronLeft, chevronRight, chevronsLeft, chevronsRight, chevronsUpDown, arrowUp, arrowDown, arrowLeft, arrowRight, filter, moreHorizontal, moreVertical, grip, menu, sidebar, maximize, minimize, enter, arrowUpRight, arrowDownRight, arrowUpDown, arrowLeftRight, chevronsUp, chevronsDown, sortAscending, sortDescending, zoomIn, zoomOut, move, reply, forward, loader, power, toggleLeft, toggleRight
    , info, warning, errorCircle, checkCircle, xCircle, help, ban, wifiOff, server, alertOctagon, plusCircle, minusCircle, checkSquare, square, circle, checkCheck, asterisk
    , edit, trash, copy, save, download, upload, link, externalLink, print, refresh, undo, redo, send, play, pause, share, unlink, scissors, wrench
    , eye, eyeOff, lock, unlock, key, shield, shieldCheck
    , settings, sliders, columns, grid, list, layers, table, home, building, briefcase, database, layout, rows, dashboard, map, listTree
    , user, users, userPlus, mapPin, phone, mail, globe, logOut, logIn, userCheck, userX, userCircle, messageSquare
    , folder, file, fileText, paperclip, image, archive, inbox, clipboard, clipboardCheck, filePlus, fileMinus, folderPlus, folderOpen, book
    , calendar, calendarCheck, clock, history, hourglass
    , bell, bookmark, star, flag, tag, heart, activity, barChart, pieChart, trendUp, trendDown, zap, command, keyboard, code, terminal, hash, atSign, percent, text, pin, lightbulb, sigma, braces, gitBranch, gitCommit, sun, moon
    , wifi, cloud, hardDrive, monitor, smartphone, camera
    , bold, italic, underline, strikethrough, heading, alignLeft, alignCenter, alignRight, listOrdered
    , package, truck, warehouse, shoppingCart, shoppingBag, creditCard, dollarSign, receipt, barcode, calculator
    )

{-| Line icons. An icon takes the text color of its parent and scales with its
`Size`, so it follows disabled, hover and danger states without extra work.

Use when: a button, menu item or message needs a small line icon that follows the text color.
Do not use when: you need one of the rarer icons, which live in the `Klar.Icon.*` modules, or a picture (use an `img`).

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
stylesheet (see [`Klar`](Klar)).

This module has the icons that components and applications use all the time. The
rest of the library, more than 300 icons, is in the modules
`Klar.Icon.Arrows`, `Klar.Icon.Business`, `Klar.Icon.Calendar` and so on; they are
listed in `Klar.Icon.Library`. All icons are one family: a 24 by 24 grid, a 2 pixel
stroke, round ends and corners, no fill.

The built-in icons are based on [Feather](https://feathericons.com) and
[Lucide](https://lucide.dev); their license texts are in the `LICENSE` file of the package.


# Showing icons

@docs Icon, Size, view, sized, labelled


# Your own icons

@docs fromSvg, custom, name, all


# Navigation and controls

@docs search, close, check, minus, plus, chevronDown, chevronUp, chevronLeft, chevronRight, chevronsLeft, chevronsRight, chevronsUpDown, arrowUp, arrowDown, arrowLeft, arrowRight, filter, moreHorizontal, moreVertical, grip, menu, sidebar, maximize, minimize, enter, arrowUpRight, arrowDownRight, arrowUpDown, arrowLeftRight, chevronsUp, chevronsDown, sortAscending, sortDescending, zoomIn, zoomOut, move, reply, forward, loader, power, toggleLeft, toggleRight


# Status

@docs info, warning, errorCircle, checkCircle, xCircle, help, ban, wifiOff, server, alertOctagon, plusCircle, minusCircle, checkSquare, square, circle, checkCheck, asterisk


# Actions

@docs edit, trash, copy, save, download, upload, link, externalLink, print, refresh, undo, redo, send, play, pause, share, unlink, scissors, wrench


# Visibility and security

@docs eye, eyeOff, lock, unlock, key, shield, shieldCheck


# Layout and objects

@docs settings, sliders, columns, grid, list, layers, table, home, building, briefcase, database, layout, rows, dashboard, map, listTree


# People and contact

@docs user, users, userPlus, mapPin, phone, mail, globe, logOut, logIn, userCheck, userX, userCircle, messageSquare


# Files

@docs folder, file, fileText, paperclip, image, archive, inbox, clipboard, clipboardCheck, filePlus, fileMinus, folderPlus, folderOpen, book


# Time

@docs calendar, calendarCheck, clock, history, hourglass


# Marks and miscellaneous

@docs bell, bookmark, star, flag, tag, heart, activity, barChart, pieChart, trendUp, trendDown, zap, command, keyboard, code, terminal, hash, atSign, percent, text, pin, lightbulb, sigma, braces, gitBranch, gitCommit, sun, moon


# Devices and network

@docs wifi, cloud, hardDrive, monitor, smartphone, camera


# Text formatting

@docs bold, italic, underline, strikethrough, heading, alignLeft, alignCenter, alignRight, listOrdered


# Commerce and logistics

@docs package, truck, warehouse, shoppingCart, shoppingBag, creditCard, dollarSign, receipt, barcode, calculator

-}

import Html exposing (Html)
import Html.Attributes as Attr
import Klar.Internal as Internal


{-| One icon. Take it from the list below, or make your own with `fromSvg`.
-}
type Icon
    = Icon { name : String, style : String }


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
        (Internal.cls [ "klar-icon", "klar-icon--" ++ name icon, sizeClass size ]
            :: Attr.attribute "aria-hidden" "true"
            :: drawing icon
        )
        []


{-| An icon that carries meaning on its own: it gets an accessible name.

    Icon.labelled "Overdue" Icon.warning

-}
labelled : String -> Icon -> Html msg
labelled label icon =
    Html.span
        (Internal.cls [ "klar-icon", "klar-icon--" ++ name icon ]
            :: Attr.attribute "role" "img"
            :: Attr.attribute "aria-label" label
            :: drawing icon
        )
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



-- The drawing of an icon is a custom property on its element, which the stylesheet
-- uses as a mask. An icon from `custom` has none: its rule is the app's own.


drawing : Icon -> List (Html.Attribute msg)
drawing (Icon icon) =
    if String.isEmpty icon.style then
        []

    else
        [ Attr.attribute "style" icon.style ]


{-| An icon you draw yourself, from the inside of an SVG. Give it a name and the
shapes, drawn on a 24 by 24 grid with strokes only (the mask turns them into the
text color):

    invoice : Icon
    invoice =
        Icon.fromSvg "invoice"
            "<path d='M6 2h9l5 5v15H6z'/><path d='M9 13h8M9 17h8'/>"

Use single quotes inside the markup. The icons of this library are made the same
way, with a 2 pixel stroke and round ends and corners (`stroke-width`,
`stroke-linecap` and `stroke-linejoin` are set for you), so yours will fit in.

-}
fromSvg : String -> String -> Icon
fromSvg iconName shapes =
    Icon
        { name = iconName
        , style =
            "--klar-icon:url(\"data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' fill='none' stroke='black' stroke-width='2' stroke-linecap='round' stroke-linejoin='round'>"
                ++ (shapes
                        |> String.replace "\"" "'"
                        |> String.replace "%" "%25"
                        |> String.replace "#" "%23"
                   )
                ++ "</svg>\")"
        }


{-| An icon whose drawing is in your own stylesheet. `custom "invoice"` renders the
CSS class `klar-icon--invoice`; define the shape there as a mask image on the
custom property `--klar-icon`:

    .klar-icon--invoice {
      --klar-icon: url("data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24'>...</svg>");
    }

Use a 24 by 24 view box and draw with black strokes. Until the rule exists the
icon shows as a dashed box, so a missing shape is easy to spot. Prefer `fromSvg`
when you can: it needs no stylesheet.

-}
custom : String -> Icon
custom iconName =
    Icon { name = iconName, style = "" }


{-| The name of an icon. The class of an icon is `klar-icon--<name>`.

    Icon.name Icon.chevronDown --> "chevron-down"

-}
name : Icon -> String
name (Icon icon) =
    icon.name


{-| Every icon of this module, in the order of the groups below. For galleries and
tests. `Klar.Icon.Library.all` has the whole library.
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
    , arrowUpRight
    , arrowDownRight
    , arrowUpDown
    , arrowLeftRight
    , chevronsUp
    , chevronsDown
    , sortAscending
    , sortDescending
    , zoomIn
    , zoomOut
    , move
    , reply
    , forward
    , loader
    , power
    , toggleLeft
    , toggleRight
    , info
    , warning
    , errorCircle
    , checkCircle
    , xCircle
    , help
    , ban
    , wifiOff
    , server
    , alertOctagon
    , plusCircle
    , minusCircle
    , checkSquare
    , square
    , circle
    , checkCheck
    , asterisk
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
    , share
    , unlink
    , scissors
    , wrench
    , eye
    , eyeOff
    , lock
    , unlock
    , key
    , shield
    , shieldCheck
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
    , layout
    , rows
    , dashboard
    , map
    , listTree
    , user
    , users
    , userPlus
    , mapPin
    , phone
    , mail
    , globe
    , logOut
    , logIn
    , userCheck
    , userX
    , userCircle
    , messageSquare
    , folder
    , file
    , fileText
    , paperclip
    , image
    , archive
    , inbox
    , clipboard
    , clipboardCheck
    , filePlus
    , fileMinus
    , folderPlus
    , folderOpen
    , book
    , calendar
    , calendarCheck
    , clock
    , history
    , hourglass
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
    , pin
    , lightbulb
    , sigma
    , braces
    , gitBranch
    , gitCommit
    , sun
    , moon
    , wifi
    , cloud
    , hardDrive
    , monitor
    , smartphone
    , camera
    , bold
    , italic
    , underline
    , strikethrough
    , heading
    , alignLeft
    , alignCenter
    , alignRight
    , listOrdered
    , package
    , truck
    , warehouse
    , shoppingCart
    , shoppingBag
    , creditCard
    , dollarSign
    , receipt
    , barcode
    , calculator
    ]



-- THE ICONS


{-| A magnifying glass.
-}
search : Icon
search =
    fromSvg "search" "<circle cx='11' cy='11' r='8'/><line x1='21' y1='21' x2='16.65' y2='16.65'/>"


{-| A cross, for closing or removing.
-}
close : Icon
close =
    fromSvg "close" "<line x1='18' y1='6' x2='6' y2='18'/><line x1='6' y1='6' x2='18' y2='18'/>"


{-| A check mark.
-}
check : Icon
check =
    fromSvg "check" "<polyline points='20 6 9 17 4 12'/>"


{-| A minus sign.
-}
minus : Icon
minus =
    fromSvg "minus" "<line x1='5' y1='12' x2='19' y2='12'/>"


{-| A plus sign.
-}
plus : Icon
plus =
    fromSvg "plus" "<line x1='12' y1='5' x2='12' y2='19'/><line x1='5' y1='12' x2='19' y2='12'/>"


{-| A chevron pointing down.
-}
chevronDown : Icon
chevronDown =
    fromSvg "chevron-down" "<polyline points='6 9 12 15 18 9'/>"


{-| A chevron pointing up.
-}
chevronUp : Icon
chevronUp =
    fromSvg "chevron-up" "<polyline points='18 15 12 9 6 15'/>"


{-| A chevron pointing left.
-}
chevronLeft : Icon
chevronLeft =
    fromSvg "chevron-left" "<polyline points='15 18 9 12 15 6'/>"


{-| A chevron pointing right.
-}
chevronRight : Icon
chevronRight =
    fromSvg "chevron-right" "<polyline points='9 18 15 12 9 6'/>"


{-| A double chevron pointing left (first page).
-}
chevronsLeft : Icon
chevronsLeft =
    fromSvg "chevrons-left" "<polyline points='11 17 6 12 11 7'/><polyline points='18 17 13 12 18 7'/>"


{-| A double chevron pointing right (last page).
-}
chevronsRight : Icon
chevronsRight =
    fromSvg "chevrons-right" "<polyline points='13 17 18 12 13 7'/><polyline points='6 17 11 12 6 7'/>"


{-| Chevrons pointing up and down, for sortable and selectable fields.
-}
chevronsUpDown : Icon
chevronsUpDown =
    fromSvg "chevrons-up-down" "<polyline points='7 15 12 20 17 15'/><polyline points='7 9 12 4 17 9'/>"


{-| An arrow pointing up.
-}
arrowUp : Icon
arrowUp =
    fromSvg "arrow-up" "<line x1='12' y1='19' x2='12' y2='5'/><polyline points='5 12 12 5 19 12'/>"


{-| An arrow pointing down.
-}
arrowDown : Icon
arrowDown =
    fromSvg "arrow-down" "<line x1='12' y1='5' x2='12' y2='19'/><polyline points='19 12 12 19 5 12'/>"


{-| An arrow pointing left.
-}
arrowLeft : Icon
arrowLeft =
    fromSvg "arrow-left" "<line x1='19' y1='12' x2='5' y2='12'/><polyline points='12 19 5 12 12 5'/>"


{-| An arrow pointing right.
-}
arrowRight : Icon
arrowRight =
    fromSvg "arrow-right" "<line x1='5' y1='12' x2='19' y2='12'/><polyline points='12 5 19 12 12 19'/>"


{-| A funnel.
-}
filter : Icon
filter =
    fromSvg "filter" "<polygon points='22 3 2 3 10 12.46 10 19 14 21 14 12.46 22 3'/>"


{-| Three horizontal dots.
-}
moreHorizontal : Icon
moreHorizontal =
    fromSvg "more-horizontal" "<circle cx='12' cy='12' r='1'/><circle cx='19' cy='12' r='1'/><circle cx='5' cy='12' r='1'/>"


{-| Three vertical dots.
-}
moreVertical : Icon
moreVertical =
    fromSvg "more-vertical" "<circle cx='12' cy='12' r='1'/><circle cx='12' cy='5' r='1'/><circle cx='12' cy='19' r='1'/>"


{-| A grid of dots, used as a drag handle.
-}
grip : Icon
grip =
    fromSvg "grip" "<circle cx='9' cy='6' r='1'/><circle cx='15' cy='6' r='1'/><circle cx='9' cy='12' r='1'/><circle cx='15' cy='12' r='1'/><circle cx='9' cy='18' r='1'/><circle cx='15' cy='18' r='1'/>"


{-| Three horizontal bars (the menu icon).
-}
menu : Icon
menu =
    fromSvg "menu" "<line x1='3' y1='12' x2='21' y2='12'/><line x1='3' y1='6' x2='21' y2='6'/><line x1='3' y1='18' x2='21' y2='18'/>"


{-| A window with a sidebar on the left.
-}
sidebar : Icon
sidebar =
    fromSvg "sidebar" "<rect x='3' y='3' width='18' height='18' rx='2'/><path d='M9 3v18'/>"


{-| Arrows pointing out to the corners.
-}
maximize : Icon
maximize =
    fromSvg "maximize" "<polyline points='15 3 21 3 21 9'/><polyline points='9 21 3 21 3 15'/><line x1='21' y1='3' x2='14' y2='10'/><line x1='3' y1='21' x2='10' y2='14'/>"


{-| Arrows pointing in towards the center.
-}
minimize : Icon
minimize =
    fromSvg "minimize" "<polyline points='4 14 10 14 10 20'/><polyline points='20 10 14 10 14 4'/><line x1='14' y1='10' x2='21' y2='3'/><line x1='3' y1='21' x2='10' y2='14'/>"


{-| The arrow of the Enter key.
-}
enter : Icon
enter =
    fromSvg "enter" "<polyline points='9 10 4 15 9 20'/><path d='M20 4v7a4 4 0 0 1-4 4H4'/>"


{-| An arrow pointing to the upper right.
-}
arrowUpRight : Icon
arrowUpRight =
    fromSvg "arrow-up-right" "<line x1='7' y1='17' x2='17' y2='7'/><polyline points='7 7 17 7 17 17'/>"


{-| An arrow pointing to the lower right.
-}
arrowDownRight : Icon
arrowDownRight =
    fromSvg "arrow-down-right" "<line x1='7' y1='7' x2='17' y2='17'/><polyline points='17 7 17 17 7 17'/>"


{-| Two arrows, one up and one down.
-}
arrowUpDown : Icon
arrowUpDown =
    fromSvg "arrow-up-down" "<path d='m21 16-4 4-4-4'/><path d='M17 20V4'/><path d='m3 8 4-4 4 4'/><path d='M7 4v16'/>"


{-| Two arrows, one left and one right: swap or transfer.
-}
arrowLeftRight : Icon
arrowLeftRight =
    fromSvg "arrow-left-right" "<path d='M8 3 4 7l4 4'/><path d='M4 7h16'/><path d='m16 21 4-4-4-4'/><path d='M20 17H4'/>"


{-| A double chevron pointing up.
-}
chevronsUp : Icon
chevronsUp =
    fromSvg "chevrons-up" "<polyline points='17 11 12 6 7 11'/><polyline points='17 18 12 13 7 18'/>"


{-| A double chevron pointing down.
-}
chevronsDown : Icon
chevronsDown =
    fromSvg "chevrons-down" "<polyline points='7 13 12 18 17 13'/><polyline points='7 6 12 11 17 6'/>"


{-| Bars growing longer with an arrow pointing up: sorted ascending.
-}
sortAscending : Icon
sortAscending =
    fromSvg "sort-ascending" "<path d='m3 8 4-4 4 4'/><path d='M7 4v16'/><path d='M11 12h4'/><path d='M11 16h7'/><path d='M11 20h10'/>"


{-| Bars growing shorter with an arrow pointing down: sorted descending.
-}
sortDescending : Icon
sortDescending =
    fromSvg "sort-descending" "<path d='m3 16 4 4 4-4'/><path d='M7 20V4'/><path d='M11 4h10'/><path d='M11 8h7'/><path d='M11 12h4'/>"


{-| A magnifying glass with a plus sign.
-}
zoomIn : Icon
zoomIn =
    fromSvg "zoom-in" "<circle cx='11' cy='11' r='8'/><line x1='21' y1='21' x2='16.65' y2='16.65'/><line x1='11' y1='8' x2='11' y2='14'/><line x1='8' y1='11' x2='14' y2='11'/>"


{-| A magnifying glass with a minus sign.
-}
zoomOut : Icon
zoomOut =
    fromSvg "zoom-out" "<circle cx='11' cy='11' r='8'/><line x1='21' y1='21' x2='16.65' y2='16.65'/><line x1='8' y1='11' x2='14' y2='11'/>"


{-| Four arrows pointing out: move or pan.
-}
move : Icon
move =
    fromSvg "move" "<polyline points='5 9 2 12 5 15'/><polyline points='9 5 12 2 15 5'/><polyline points='15 19 12 22 9 19'/><polyline points='19 9 22 12 19 15'/><line x1='2' y1='12' x2='22' y2='12'/><line x1='12' y1='2' x2='12' y2='22'/>"


{-| An arrow curving back: reply.
-}
reply : Icon
reply =
    fromSvg "reply" "<polyline points='9 17 4 12 9 7'/><path d='M20 18v-2a4 4 0 0 0-4-4H4'/>"


{-| An arrow curving forward: forward or pass on.
-}
forward : Icon
forward =
    fromSvg "forward" "<polyline points='15 17 20 12 15 7'/><path d='M4 18v-2a4 4 0 0 1 4-4h12'/>"


{-| Eight spokes, for something in progress. Static: it does not spin by itself.
-}
loader : Icon
loader =
    fromSvg "loader" "<line x1='12' y1='2' x2='12' y2='6'/><line x1='12' y1='18' x2='12' y2='22'/><line x1='4.93' y1='4.93' x2='7.76' y2='7.76'/><line x1='16.24' y1='16.24' x2='19.07' y2='19.07'/><line x1='2' y1='12' x2='6' y2='12'/><line x1='18' y1='12' x2='22' y2='12'/><line x1='4.93' y1='19.07' x2='7.76' y2='16.24'/><line x1='16.24' y1='7.76' x2='19.07' y2='4.93'/>"


{-| The power symbol.
-}
power : Icon
power =
    fromSvg "power" "<path d='M18.36 6.64a9 9 0 1 1-12.73 0'/><line x1='12' y1='2' x2='12' y2='12'/>"


{-| A switch in the off position.
-}
toggleLeft : Icon
toggleLeft =
    fromSvg "toggle-left" "<rect x='1' y='5' width='22' height='14' rx='7'/><circle cx='8' cy='12' r='3'/>"


{-| A switch in the on position.
-}
toggleRight : Icon
toggleRight =
    fromSvg "toggle-right" "<rect x='1' y='5' width='22' height='14' rx='7'/><circle cx='16' cy='12' r='3'/>"


{-| A circle with an i.
-}
info : Icon
info =
    fromSvg "info" "<circle cx='12' cy='12' r='10'/><line x1='12' y1='16' x2='12' y2='12'/><line x1='12' y1='8' x2='12.01' y2='8'/>"


{-| A triangle with an exclamation mark.
-}
warning : Icon
warning =
    fromSvg "warning" "<path d='M10.29 3.86L1.82 18a2 2 0 0 0 1.71 3h16.94a2 2 0 0 0 1.71-3L13.71 3.86a2 2 0 0 0-3.42 0z'/><line x1='12' y1='9' x2='12' y2='13'/><line x1='12' y1='17' x2='12.01' y2='17'/>"


{-| A circle with an exclamation mark.
-}
errorCircle : Icon
errorCircle =
    fromSvg "error-circle" "<circle cx='12' cy='12' r='10'/><line x1='12' y1='8' x2='12' y2='12'/><line x1='12' y1='16' x2='12.01' y2='16'/>"


{-| A circle with a check mark.
-}
checkCircle : Icon
checkCircle =
    fromSvg "check-circle" "<path d='M22 11.08V12a10 10 0 1 1-5.93-9.14'/><polyline points='22 4 12 14.01 9 11.01'/>"


{-| A circle with a cross.
-}
xCircle : Icon
xCircle =
    fromSvg "x-circle" "<circle cx='12' cy='12' r='10'/><line x1='15' y1='9' x2='9' y2='15'/><line x1='9' y1='9' x2='15' y2='15'/>"


{-| A circle with a question mark.
-}
help : Icon
help =
    fromSvg "help" "<circle cx='12' cy='12' r='10'/><path d='M9.09 9a3 3 0 0 1 5.83 1c0 2-3 3-3 3'/><line x1='12' y1='17' x2='12.01' y2='17'/>"


{-| A circle with a diagonal line: not allowed.
-}
ban : Icon
ban =
    fromSvg "ban" "<circle cx='12' cy='12' r='10'/><line x1='4.93' y1='4.93' x2='19.07' y2='19.07'/>"


{-| A crossed-out wireless signal: offline.
-}
wifiOff : Icon
wifiOff =
    fromSvg "wifi-off" "<line x1='1' y1='1' x2='23' y2='23'/><path d='M16.72 11.06A10.94 10.94 0 0 1 19 12.55'/><path d='M5 12.55a10.94 10.94 0 0 1 5.17-2.39'/><path d='M10.71 5.05A16 16 0 0 1 22.58 9'/><path d='M1.42 9a15.91 15.91 0 0 1 4.7-2.88'/><path d='M8.53 16.11a6 6 0 0 1 6.95 0'/><line x1='12' y1='20' x2='12.01' y2='20'/>"


{-| A server rack.
-}
server : Icon
server =
    fromSvg "server" "<rect x='2' y='2' width='20' height='8' rx='2' ry='2'/><rect x='2' y='14' width='20' height='8' rx='2' ry='2'/><line x1='6' y1='6' x2='6.01' y2='6'/><line x1='6' y1='18' x2='6.01' y2='18'/>"


{-| An octagon with an exclamation mark: a stop or a serious error.
-}
alertOctagon : Icon
alertOctagon =
    fromSvg "alert-octagon" "<polygon points='7.86 2 16.14 2 22 7.86 22 16.14 16.14 22 7.86 22 2 16.14 2 7.86 7.86 2'/><line x1='12' y1='8' x2='12' y2='12'/><line x1='12' y1='16' x2='12' y2='16.01'/>"


{-| A circle with a plus sign.
-}
plusCircle : Icon
plusCircle =
    fromSvg "plus-circle" "<circle cx='12' cy='12' r='10'/><line x1='12' y1='8' x2='12' y2='16'/><line x1='8' y1='12' x2='16' y2='12'/>"


{-| A circle with a minus sign.
-}
minusCircle : Icon
minusCircle =
    fromSvg "minus-circle" "<circle cx='12' cy='12' r='10'/><line x1='8' y1='12' x2='16' y2='12'/>"


{-| A box with a check mark.
-}
checkSquare : Icon
checkSquare =
    fromSvg "check-square" "<polyline points='9 11 12 14 22 4'/><path d='M21 12v7a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h11'/>"


{-| An empty box.
-}
square : Icon
square =
    fromSvg "square" "<rect x='3' y='3' width='18' height='18' rx='2'/>"


{-| An empty circle.
-}
circle : Icon
circle =
    fromSvg "circle" "<circle cx='12' cy='12' r='10'/>"


{-| Two check marks: done and confirmed.
-}
checkCheck : Icon
checkCheck =
    fromSvg "check-check" "<path d='M18 6 7 17l-5-5'/><path d='m22 10-7.5 7.5L13 16'/>"


{-| An asterisk, for required fields.
-}
asterisk : Icon
asterisk =
    fromSvg "asterisk" "<path d='M12 6v12'/><path d='M17.196 9 6.804 15'/><path d='m6.804 9 10.392 6'/>"


{-| A pencil.
-}
edit : Icon
edit =
    fromSvg "edit" "<path d='M17 3a2.828 2.828 0 1 1 4 4L7.5 20.5 2 22l1.5-5.5L17 3z'/>"


{-| A trash can.
-}
trash : Icon
trash =
    fromSvg "trash" "<polyline points='3 6 5 6 21 6'/><path d='M19 6v14a2 2 0 0 1-2 2H7a2 2 0 0 1-2-2V6m3 0V4a2 2 0 0 1 2-2h4a2 2 0 0 1 2 2v2'/><line x1='10' y1='11' x2='10' y2='17'/><line x1='14' y1='11' x2='14' y2='17'/>"


{-| Two overlapping sheets.
-}
copy : Icon
copy =
    fromSvg "copy" "<rect x='9' y='9' width='13' height='13' rx='2' ry='2'/><path d='M5 15H4a2 2 0 0 1-2-2V4a2 2 0 0 1 2-2h9a2 2 0 0 1 2 2v1'/>"


{-| A floppy disk.
-}
save : Icon
save =
    fromSvg "save" "<path d='M19 21H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h11l5 5v11a2 2 0 0 1-2 2z'/><polyline points='17 21 17 13 7 13 7 21'/><polyline points='7 3 7 8 15 8'/>"


{-| A tray with an arrow pointing down.
-}
download : Icon
download =
    fromSvg "download" "<path d='M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4'/><polyline points='7 10 12 15 17 10'/><line x1='12' y1='15' x2='12' y2='3'/>"


{-| A tray with an arrow pointing up.
-}
upload : Icon
upload =
    fromSvg "upload" "<path d='M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4'/><polyline points='17 8 12 3 7 8'/><line x1='12' y1='3' x2='12' y2='15'/>"


{-| Two chain links.
-}
link : Icon
link =
    fromSvg "link" "<path d='M10 13a5 5 0 0 0 7.54.54l3-3a5 5 0 0 0-7.07-7.07l-1.72 1.71'/><path d='M14 11a5 5 0 0 0-7.54-.54l-3 3a5 5 0 0 0 7.07 7.07l1.71-1.71'/>"


{-| An arrow leaving a box: opens elsewhere.
-}
externalLink : Icon
externalLink =
    fromSvg "external-link" "<path d='M18 13v6a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V8a2 2 0 0 1 2-2h6'/><polyline points='15 3 21 3 21 9'/><line x1='10' y1='14' x2='21' y2='3'/>"


{-| A printer.
-}
print : Icon
print =
    fromSvg "print" "<polyline points='6 9 6 2 18 2 18 9'/><path d='M6 18H4a2 2 0 0 1-2-2v-5a2 2 0 0 1 2-2h16a2 2 0 0 1 2 2v5a2 2 0 0 1-2 2h-2'/><rect x='6' y='14' width='12' height='8'/>"


{-| Two arrows in a circle.
-}
refresh : Icon
refresh =
    fromSvg "refresh" "<polyline points='23 4 23 10 17 10'/><polyline points='1 20 1 14 7 14'/><path d='M3.51 9a9 9 0 0 1 14.85-3.36L23 10M1 14l4.64 4.36A9 9 0 0 0 20.49 15'/>"


{-| A curved arrow pointing back.
-}
undo : Icon
undo =
    fromSvg "undo" "<polyline points='1 4 1 10 7 10'/><path d='M3.51 15a9 9 0 1 0 2.13-9.36L1 10'/>"


{-| A curved arrow pointing forward.
-}
redo : Icon
redo =
    fromSvg "redo" "<polyline points='23 4 23 10 17 10'/><path d='M20.49 15a9 9 0 1 1-2.12-9.36L23 10'/>"


{-| A paper plane.
-}
send : Icon
send =
    fromSvg "send" "<line x1='22' y1='2' x2='11' y2='13'/><polygon points='22 2 15 22 11 13 2 9 22 2'/>"


{-| A play triangle.
-}
play : Icon
play =
    fromSvg "play" "<polygon points='5 3 19 12 5 21 5 3'/>"


{-| Two vertical bars.
-}
pause : Icon
pause =
    fromSvg "pause" "<rect x='6' y='4' width='4' height='16'/><rect x='14' y='4' width='4' height='16'/>"


{-| Three connected dots.
-}
share : Icon
share =
    fromSvg "share" "<circle cx='18' cy='5' r='3'/><circle cx='6' cy='12' r='3'/><circle cx='18' cy='19' r='3'/><line x1='8.59' y1='13.51' x2='15.42' y2='17.49'/><line x1='15.41' y1='6.51' x2='8.59' y2='10.49'/>"


{-| A broken chain.
-}
unlink : Icon
unlink =
    fromSvg "unlink" "<path d='m18.84 12.25 1.72-1.71h-.02a5.004 5.004 0 0 0-.12-7.07 5.006 5.006 0 0 0-6.95 0l-1.72 1.71'/><path d='m5.17 11.75-1.71 1.71a5.004 5.004 0 0 0 .12 7.07 5.006 5.006 0 0 0 6.95 0l1.71-1.71'/><line x1='8' y1='2' x2='8' y2='5'/><line x1='2' y1='8' x2='5' y2='8'/><line x1='16' y1='19' x2='16' y2='22'/><line x1='19' y1='16' x2='22' y2='16'/>"


{-| A pair of scissors.
-}
scissors : Icon
scissors =
    fromSvg "scissors" "<circle cx='6' cy='6' r='3'/><circle cx='6' cy='18' r='3'/><line x1='20' y1='4' x2='8.12' y2='15.88'/><line x1='14.47' y1='14.48' x2='20' y2='20'/><line x1='8.12' y1='8.12' x2='12' y2='12'/>"


{-| A wrench.
-}
wrench : Icon
wrench =
    fromSvg "wrench" "<path d='M14.7 6.3a1 1 0 0 0 0 1.4l1.6 1.6a1 1 0 0 0 1.4 0l3.77-3.77a6 6 0 0 1-7.94 7.94l-6.91 6.91a2.12 2.12 0 0 1-3-3l6.91-6.91a6 6 0 0 1 7.94-7.94l-3.76 3.76z'/>"


{-| An open eye.
-}
eye : Icon
eye =
    fromSvg "eye" "<path d='M1 12s4-8 11-8 11 8 11 8-4 8-11 8-11-8-11-8z'/><circle cx='12' cy='12' r='3'/>"


{-| A crossed-out eye.
-}
eyeOff : Icon
eyeOff =
    fromSvg "eye-off" "<path d='M17.94 17.94A10.07 10.07 0 0 1 12 20c-7 0-11-8-11-8a18.45 18.45 0 0 1 5.06-5.94M9.9 4.24A9.12 9.12 0 0 1 12 4c7 0 11 8 11 8a18.5 18.5 0 0 1-2.16 3.19m-6.72-1.07a3 3 0 1 1-4.24-4.24'/><line x1='1' y1='1' x2='23' y2='23'/>"


{-| A closed padlock.
-}
lock : Icon
lock =
    fromSvg "lock" "<rect x='3' y='11' width='18' height='11' rx='2' ry='2'/><path d='M7 11V7a5 5 0 0 1 10 0v4'/>"


{-| An open padlock.
-}
unlock : Icon
unlock =
    fromSvg "unlock" "<rect x='3' y='11' width='18' height='11' rx='2' ry='2'/><path d='M7 11V7a5 5 0 0 1 9.9-1'/>"


{-| A key.
-}
key : Icon
key =
    fromSvg "key" "<path d='M21 2l-2 2m-7.61 7.61a5.5 5.5 0 1 1-7.778 7.778 5.5 5.5 0 0 1 7.777-7.777zm0 0L15.5 7.5m0 0l3 3L22 7l-3-3m-3.5 3.5L19 4'/>"


{-| A shield.
-}
shield : Icon
shield =
    fromSvg "shield" "<path d='M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10z'/>"


{-| A shield with a check mark.
-}
shieldCheck : Icon
shieldCheck =
    fromSvg "shield-check" "<path d='M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10z'/><polyline points='9 12 11 14 15 10'/>"


{-| A cog wheel.
-}
settings : Icon
settings =
    fromSvg "settings" "<circle cx='12' cy='12' r='3'/><path d='M19.4 15a1.65 1.65 0 0 0 .33 1.82l.06.06a2 2 0 0 1 0 2.83 2 2 0 0 1-2.83 0l-.06-.06a1.65 1.65 0 0 0-1.82-.33 1.65 1.65 0 0 0-1 1.51V21a2 2 0 0 1-2 2 2 2 0 0 1-2-2v-.09A1.65 1.65 0 0 0 9 19.4a1.65 1.65 0 0 0-1.82.33l-.06.06a2 2 0 0 1-2.83 0 2 2 0 0 1 0-2.83l.06-.06a1.65 1.65 0 0 0 .33-1.82 1.65 1.65 0 0 0-1.51-1H3a2 2 0 0 1-2-2 2 2 0 0 1 2-2h.09A1.65 1.65 0 0 0 4.6 9a1.65 1.65 0 0 0-.33-1.82l-.06-.06a2 2 0 0 1 0-2.83 2 2 0 0 1 2.83 0l.06.06a1.65 1.65 0 0 0 1.82.33H9a1.65 1.65 0 0 0 1-1.51V3a2 2 0 0 1 2-2 2 2 0 0 1 2 2v.09a1.65 1.65 0 0 0 1 1.51 1.65 1.65 0 0 0 1.82-.33l.06-.06a2 2 0 0 1 2.83 0 2 2 0 0 1 0 2.83l-.06.06a1.65 1.65 0 0 0-.33 1.82V9a1.65 1.65 0 0 0 1.51 1H21a2 2 0 0 1 2 2 2 2 0 0 1-2 2h-.09a1.65 1.65 0 0 0-1.51 1z'/>"


{-| Horizontal sliders.
-}
sliders : Icon
sliders =
    fromSvg "sliders" "<line x1='4' y1='21' x2='4' y2='14'/><line x1='4' y1='10' x2='4' y2='3'/><line x1='12' y1='21' x2='12' y2='12'/><line x1='12' y1='8' x2='12' y2='3'/><line x1='20' y1='21' x2='20' y2='16'/><line x1='20' y1='12' x2='20' y2='3'/><line x1='1' y1='14' x2='7' y2='14'/><line x1='9' y1='8' x2='15' y2='8'/><line x1='17' y1='16' x2='23' y2='16'/>"


{-| Vertical columns, for choosing table columns.
-}
columns : Icon
columns =
    fromSvg "columns" "<path d='M12 3h7a2 2 0 0 1 2 2v14a2 2 0 0 1-2 2h-7m0-18H5a2 2 0 0 0-2 2v14a2 2 0 0 0 2 2h7m0-18v18'/>"


{-| A grid of four squares.
-}
grid : Icon
grid =
    fromSvg "grid" "<rect x='3' y='3' width='7' height='7'/><rect x='14' y='3' width='7' height='7'/><rect x='14' y='14' width='7' height='7'/><rect x='3' y='14' width='7' height='7'/>"


{-| A bulleted list.
-}
list : Icon
list =
    fromSvg "list" "<line x1='8' y1='6' x2='21' y2='6'/><line x1='8' y1='12' x2='21' y2='12'/><line x1='8' y1='18' x2='21' y2='18'/><line x1='3' y1='6' x2='3.01' y2='6'/><line x1='3' y1='12' x2='3.01' y2='12'/><line x1='3' y1='18' x2='3.01' y2='18'/>"


{-| Stacked layers.
-}
layers : Icon
layers =
    fromSvg "layers" "<polygon points='12 2 2 7 12 12 22 7 12 2'/><polyline points='2 17 12 22 22 17'/><polyline points='2 12 12 17 22 12'/>"


{-| A table.
-}
table : Icon
table =
    fromSvg "table" "<rect x='3' y='3' width='18' height='18' rx='2'/><path d='M3 9h18M3 15h18M9 3v18'/>"


{-| A house.
-}
home : Icon
home =
    fromSvg "home" "<path d='M3 9l9-7 9 7v11a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2z'/><polyline points='9 22 9 12 15 12 15 22'/>"


{-| An office building.
-}
building : Icon
building =
    fromSvg "building" "<rect x='4' y='2' width='16' height='20' rx='2'/><path d='M9 22v-4h6v4M8 6h.01M16 6h.01M12 6h.01M12 10h.01M12 14h.01M16 10h.01M16 14h.01M8 10h.01M8 14h.01'/>"


{-| A briefcase.
-}
briefcase : Icon
briefcase =
    fromSvg "briefcase" "<rect x='2' y='7' width='20' height='14' rx='2' ry='2'/><path d='M16 21V5a2 2 0 0 0-2-2h-4a2 2 0 0 0-2 2v16'/>"


{-| A database cylinder.
-}
database : Icon
database =
    fromSvg "database" "<ellipse cx='12' cy='5' rx='9' ry='3'/><path d='M21 12c0 1.66-4 3-9 3s-9-1.34-9-3'/><path d='M3 5v14c0 1.66 4 3 9 3s9-1.34 9-3V5'/>"


{-| A window with a header and a sidebar.
-}
layout : Icon
layout =
    fromSvg "layout" "<rect x='3' y='3' width='18' height='18' rx='2'/><line x1='3' y1='9' x2='21' y2='9'/><line x1='9' y1='21' x2='9' y2='9'/>"


{-| A box split into horizontal rows.
-}
rows : Icon
rows =
    fromSvg "rows" "<rect x='3' y='3' width='18' height='18' rx='2'/><line x1='3' y1='9' x2='21' y2='9'/><line x1='3' y1='15' x2='21' y2='15'/>"


{-| Four tiles of different sizes.
-}
dashboard : Icon
dashboard =
    fromSvg "dashboard" "<rect x='3' y='3' width='7' height='9'/><rect x='14' y='3' width='7' height='5'/><rect x='14' y='12' width='7' height='9'/><rect x='3' y='16' width='7' height='5'/>"


{-| A folded map.
-}
map : Icon
map =
    fromSvg "map" "<polygon points='1 6 1 22 8 18 16 22 23 18 23 2 16 6 8 2 1 6'/><line x1='8' y1='2' x2='8' y2='18'/><line x1='16' y1='6' x2='16' y2='22'/>"


{-| Lines of text hanging off a trunk: a tree view.
-}
listTree : Icon
listTree =
    fromSvg "list-tree" "<path d='M21 12h-8'/><path d='M21 6H8'/><path d='M21 18h-8'/><path d='M3 6v4c0 1.1.9 2 2 2h3'/><path d='M3 10v6c0 1.1.9 2 2 2h3'/>"


{-| A person.
-}
user : Icon
user =
    fromSvg "user" "<path d='M20 21v-2a4 4 0 0 0-4-4H8a4 4 0 0 0-4 4v2'/><circle cx='12' cy='7' r='4'/>"


{-| A group of people.
-}
users : Icon
users =
    fromSvg "users" "<path d='M17 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2'/><circle cx='9' cy='7' r='4'/><path d='M23 21v-2a4 4 0 0 0-3-3.87'/><path d='M16 3.13a4 4 0 0 1 0 7.75'/>"


{-| A person with a plus sign.
-}
userPlus : Icon
userPlus =
    fromSvg "user-plus" "<path d='M16 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2'/><circle cx='8.5' cy='7' r='4'/><line x1='20' y1='8' x2='20' y2='14'/><line x1='23' y1='11' x2='17' y2='11'/>"


{-| A map pin.
-}
mapPin : Icon
mapPin =
    fromSvg "map-pin" "<path d='M21 10c0 7-9 13-9 13s-9-6-9-13a9 9 0 0 1 18 0z'/><circle cx='12' cy='10' r='3'/>"


{-| A telephone handset.
-}
phone : Icon
phone =
    fromSvg "phone" "<path d='M22 16.92v3a2 2 0 0 1-2.18 2 19.79 19.79 0 0 1-8.63-3.07 19.5 19.5 0 0 1-6-6 19.79 19.79 0 0 1-3.07-8.67A2 2 0 0 1 4.11 2h3a2 2 0 0 1 2 1.72 12.84 12.84 0 0 0 .7 2.81 2 2 0 0 1-.45 2.11L8.09 9.91a16 16 0 0 0 6 6l1.27-1.27a2 2 0 0 1 2.11-.45 12.84 12.84 0 0 0 2.81.7A2 2 0 0 1 22 16.92z'/>"


{-| An envelope.
-}
mail : Icon
mail =
    fromSvg "mail" "<path d='M4 4h16c1.1 0 2 .9 2 2v12c0 1.1-.9 2-2 2H4c-1.1 0-2-.9-2-2V6c0-1.1.9-2 2-2z'/><polyline points='22,6 12,13 2,6'/>"


{-| A globe.
-}
globe : Icon
globe =
    fromSvg "globe" "<circle cx='12' cy='12' r='10'/><line x1='2' y1='12' x2='22' y2='12'/><path d='M12 2a15.3 15.3 0 0 1 4 10 15.3 15.3 0 0 1-4 10 15.3 15.3 0 0 1-4-10 15.3 15.3 0 0 1 4-10z'/>"


{-| An arrow leaving a door.
-}
logOut : Icon
logOut =
    fromSvg "log-out" "<path d='M9 21H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h4'/><polyline points='16 17 21 12 16 7'/><line x1='21' y1='12' x2='9' y2='12'/>"


{-| An arrow entering a door.
-}
logIn : Icon
logIn =
    fromSvg "log-in" "<path d='M15 3h4a2 2 0 0 1 2 2v14a2 2 0 0 1-2 2h-4'/><polyline points='10 17 15 12 10 7'/><line x1='15' y1='12' x2='3' y2='12'/>"


{-| A person with a check mark.
-}
userCheck : Icon
userCheck =
    fromSvg "user-check" "<path d='M16 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2'/><circle cx='8.5' cy='7' r='4'/><polyline points='17 11 19 13 23 9'/>"


{-| A person with a cross.
-}
userX : Icon
userX =
    fromSvg "user-x" "<path d='M16 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2'/><circle cx='8.5' cy='7' r='4'/><line x1='18' y1='8' x2='23' y2='13'/><line x1='23' y1='8' x2='18' y2='13'/>"


{-| A person in a circle: an avatar.
-}
userCircle : Icon
userCircle =
    fromSvg "user-circle" "<circle cx='12' cy='12' r='10'/><circle cx='12' cy='10' r='3'/><path d='M7 20.662V19a2 2 0 0 1 2-2h6a2 2 0 0 1 2 2v1.662'/>"


{-| A speech bubble.
-}
messageSquare : Icon
messageSquare =
    fromSvg "message-square" "<path d='M21 15a2 2 0 0 1-2 2H7l-4 4V5a2 2 0 0 1 2-2h14a2 2 0 0 1 2 2z'/>"


{-| A folder.
-}
folder : Icon
folder =
    fromSvg "folder" "<path d='M22 19a2 2 0 0 1-2 2H4a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h5l2 3h9a2 2 0 0 1 2 2z'/>"


{-| A blank sheet.
-}
file : Icon
file =
    fromSvg "file" "<path d='M13 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V9z'/><polyline points='13 2 13 9 20 9'/>"


{-| A sheet with lines of text.
-}
fileText : Icon
fileText =
    fromSvg "file-text" "<path d='M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z'/><polyline points='14 2 14 8 20 8'/><line x1='16' y1='13' x2='8' y2='13'/><line x1='16' y1='17' x2='8' y2='17'/><polyline points='10 9 9 9 8 9'/>"


{-| A paperclip.
-}
paperclip : Icon
paperclip =
    fromSvg "paperclip" "<path d='M21.44 11.05l-9.19 9.19a6 6 0 0 1-8.49-8.49l9.19-9.19a4 4 0 0 1 5.66 5.66l-9.2 9.19a2 2 0 0 1-2.83-2.83l8.49-8.48'/>"


{-| A picture.
-}
image : Icon
image =
    fromSvg "image" "<rect x='3' y='3' width='18' height='18' rx='2' ry='2'/><circle cx='8.5' cy='8.5' r='1.5'/><polyline points='21 15 16 10 5 21'/>"


{-| An archive box.
-}
archive : Icon
archive =
    fromSvg "archive" "<polyline points='21 8 21 21 3 21 3 8'/><rect x='1' y='3' width='22' height='5'/><line x1='10' y1='12' x2='14' y2='12'/>"


{-| An inbox tray.
-}
inbox : Icon
inbox =
    fromSvg "inbox" "<polyline points='22 12 16 12 14 15 10 15 8 12 2 12'/><path d='M5.45 5.11L2 12v6a2 2 0 0 0 2 2h16a2 2 0 0 0 2-2v-6l-3.45-6.89A2 2 0 0 0 16.76 4H7.24a2 2 0 0 0-1.79 1.11z'/>"


{-| A clipboard.
-}
clipboard : Icon
clipboard =
    fromSvg "clipboard" "<path d='M16 4h2a2 2 0 0 1 2 2v14a2 2 0 0 1-2 2H6a2 2 0 0 1-2-2V6a2 2 0 0 1 2-2h2'/><rect x='8' y='2' width='8' height='4' rx='1' ry='1'/>"


{-| A clipboard with a check mark.
-}
clipboardCheck : Icon
clipboardCheck =
    fromSvg "clipboard-check" "<rect x='8' y='2' width='8' height='4' rx='1' ry='1'/><path d='M16 4h2a2 2 0 0 1 2 2v14a2 2 0 0 1-2 2H6a2 2 0 0 1-2-2V6a2 2 0 0 1 2-2h2'/><path d='M9 14l2 2 4-4'/>"


{-| A sheet with a plus sign.
-}
filePlus : Icon
filePlus =
    fromSvg "file-plus" "<path d='M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z'/><polyline points='14 2 14 8 20 8'/><line x1='12' y1='18' x2='12' y2='12'/><line x1='9' y1='15' x2='15' y2='15'/>"


{-| A sheet with a minus sign.
-}
fileMinus : Icon
fileMinus =
    fromSvg "file-minus" "<path d='M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z'/><polyline points='14 2 14 8 20 8'/><line x1='9' y1='15' x2='15' y2='15'/>"


{-| A folder with a plus sign.
-}
folderPlus : Icon
folderPlus =
    fromSvg "folder-plus" "<path d='M22 19a2 2 0 0 1-2 2H4a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h5l2 3h9a2 2 0 0 1 2 2z'/><line x1='12' y1='11' x2='12' y2='17'/><line x1='9' y1='14' x2='15' y2='14'/>"


{-| An open folder.
-}
folderOpen : Icon
folderOpen =
    fromSvg "folder-open" "<path d='m6 14 1.5-2.9A2 2 0 0 1 9.24 10H20a2 2 0 0 1 1.94 2.5l-1.54 6a2 2 0 0 1-1.95 1.5H4a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h3.9a2 2 0 0 1 1.69.9l.81 1.2a2 2 0 0 0 1.67.9H18a2 2 0 0 1 2 2v2'/>"


{-| A closed book.
-}
book : Icon
book =
    fromSvg "book" "<path d='M4 19.5A2.5 2.5 0 0 1 6.5 17H20'/><path d='M6.5 2H20v20H6.5A2.5 2.5 0 0 1 4 19.5v-15A2.5 2.5 0 0 1 6.5 2z'/>"


{-| A calendar.
-}
calendar : Icon
calendar =
    fromSvg "calendar" "<rect x='3' y='4' width='18' height='18' rx='2' ry='2'/><line x1='16' y1='2' x2='16' y2='6'/><line x1='8' y1='2' x2='8' y2='6'/><line x1='3' y1='10' x2='21' y2='10'/>"


{-| A calendar with a check mark.
-}
calendarCheck : Icon
calendarCheck =
    fromSvg "calendar-check" "<rect x='3' y='4' width='18' height='18' rx='2' ry='2'/><line x1='16' y1='2' x2='16' y2='6'/><line x1='8' y1='2' x2='8' y2='6'/><line x1='3' y1='10' x2='21' y2='10'/><path d='M9 16l2 2 4-4'/>"


{-| A clock face.
-}
clock : Icon
clock =
    fromSvg "clock" "<circle cx='12' cy='12' r='10'/><polyline points='12 6 12 12 16 14'/>"


{-| A clock with an arrow running counter-clockwise.
-}
history : Icon
history =
    fromSvg "history" "<path d='M3 3v5h5'/><path d='M3.05 13A9 9 0 1 0 6 5.3L3 8'/><path d='M12 7v5l4 2'/>"


{-| An hourglass.
-}
hourglass : Icon
hourglass =
    fromSvg "hourglass" "<path d='M5 22h14'/><path d='M5 2h14'/><path d='M17 22v-4.172a2 2 0 0 0-.586-1.414L12 12l-4.414 4.414A2 2 0 0 0 7 17.828V22'/><path d='M7 2v4.172a2 2 0 0 0 .586 1.414L12 12l4.414-4.414A2 2 0 0 0 17 6.172V2'/>"


{-| A bell.
-}
bell : Icon
bell =
    fromSvg "bell" "<path d='M18 8A6 6 0 0 0 6 8c0 7-3 9-3 9h18s-3-2-3-9'/><path d='M13.73 21a2 2 0 0 1-3.46 0'/>"


{-| A bookmark.
-}
bookmark : Icon
bookmark =
    fromSvg "bookmark" "<path d='M19 21l-7-5-7 5V5a2 2 0 0 1 2-2h10a2 2 0 0 1 2 2z'/>"


{-| A star.
-}
star : Icon
star =
    fromSvg "star" "<polygon points='12 2 15.09 8.26 22 9.27 17 14.14 18.18 21.02 12 17.77 5.82 21.02 7 14.14 2 9.27 8.91 8.26 12 2'/>"


{-| A flag.
-}
flag : Icon
flag =
    fromSvg "flag" "<path d='M4 15s1-1 4-1 5 2 8 2 4-1 4-1V3s-1 1-4 1-5-2-8-2-4 1-4 1z'/><line x1='4' y1='22' x2='4' y2='15'/>"


{-| A price tag.
-}
tag : Icon
tag =
    fromSvg "tag" "<path d='M20.59 13.41l-7.17 7.17a2 2 0 0 1-2.83 0L2 12V2h10l8.59 8.59a2 2 0 0 1 0 2.82z'/><line x1='7' y1='7' x2='7.01' y2='7'/>"


{-| A heart.
-}
heart : Icon
heart =
    fromSvg "heart" "<path d='M20.84 4.61a5.5 5.5 0 0 0-7.78 0L12 5.67l-1.06-1.06a5.5 5.5 0 0 0-7.78 7.78l1.06 1.06L12 21.23l7.78-7.78 1.06-1.06a5.5 5.5 0 0 0 0-7.78z'/>"


{-| A pulse line.
-}
activity : Icon
activity =
    fromSvg "activity" "<polyline points='22 12 18 12 15 21 9 3 6 12 2 12'/>"


{-| A bar chart.
-}
barChart : Icon
barChart =
    fromSvg "bar-chart" "<line x1='18' y1='20' x2='18' y2='10'/><line x1='12' y1='20' x2='12' y2='4'/><line x1='6' y1='20' x2='6' y2='14'/>"


{-| A pie chart.
-}
pieChart : Icon
pieChart =
    fromSvg "pie-chart" "<path d='M21.21 15.89A10 10 0 1 1 8 2.83'/><path d='M22 12A10 10 0 0 0 12 2v10z'/>"


{-| A line trending up.
-}
trendUp : Icon
trendUp =
    fromSvg "trend-up" "<polyline points='23 6 13.5 15.5 8.5 10.5 1 18'/><polyline points='17 6 23 6 23 12'/>"


{-| A line trending down.
-}
trendDown : Icon
trendDown =
    fromSvg "trend-down" "<polyline points='23 18 13.5 8.5 8.5 13.5 1 6'/><polyline points='17 18 23 18 23 12'/>"


{-| A lightning bolt.
-}
zap : Icon
zap =
    fromSvg "zap" "<polygon points='13 2 3 14 12 14 11 22 21 10 12 10 13 2'/>"


{-| The Command key symbol.
-}
command : Icon
command =
    fromSvg "command" "<path d='M18 3a3 3 0 0 0-3 3v12a3 3 0 0 0 3 3 3 3 0 0 0 3-3 3 3 0 0 0-3-3H6a3 3 0 0 0-3 3 3 3 0 0 0 3 3 3 3 0 0 0 3-3V6a3 3 0 0 0-3-3 3 3 0 0 0-3 3 3 3 0 0 0 3 3h12a3 3 0 0 0 3-3 3 3 0 0 0-3-3z'/>"


{-| A keyboard.
-}
keyboard : Icon
keyboard =
    fromSvg "keyboard" "<rect x='2' y='4' width='20' height='16' rx='2'/><path d='M6 8h.01M10 8h.01M14 8h.01M18 8h.01M8 12h.01M12 12h.01M16 12h.01M7 16h10'/>"


{-| Angle brackets.
-}
code : Icon
code =
    fromSvg "code" "<polyline points='16 18 22 12 16 6'/><polyline points='8 6 2 12 8 18'/>"


{-| A terminal prompt.
-}
terminal : Icon
terminal =
    fromSvg "terminal" "<polyline points='4 17 10 11 4 5'/><line x1='12' y1='19' x2='20' y2='19'/>"


{-| A hash sign.
-}
hash : Icon
hash =
    fromSvg "hash" "<line x1='4' y1='9' x2='20' y2='9'/><line x1='4' y1='15' x2='20' y2='15'/><line x1='10' y1='3' x2='8' y2='21'/><line x1='16' y1='3' x2='14' y2='21'/>"


{-| An at sign.
-}
atSign : Icon
atSign =
    fromSvg "at-sign" "<circle cx='12' cy='12' r='4'/><path d='M16 8v5a3 3 0 0 0 6 0v-1a10 10 0 1 0-3.92 7.94'/>"


{-| A percent sign.
-}
percent : Icon
percent =
    fromSvg "percent" "<line x1='19' y1='5' x2='5' y2='19'/><circle cx='6.5' cy='6.5' r='2.5'/><circle cx='17.5' cy='17.5' r='2.5'/>"


{-| The letter T, for text and typography.
-}
text : Icon
text =
    fromSvg "text" "<polyline points='4 7 4 4 20 4 20 7'/><line x1='9' y1='20' x2='15' y2='20'/><line x1='12' y1='4' x2='12' y2='20'/>"


{-| A push pin, for pinned items.
-}
pin : Icon
pin =
    fromSvg "pin" "<path d='M12 17v5'/><path d='M9 10.76a2 2 0 0 1-1.11 1.79l-1.78.9A2 2 0 0 0 5 15.24V16a1 1 0 0 0 1 1h12a1 1 0 0 0 1-1v-.76a2 2 0 0 0-1.11-1.79l-1.78-.9A2 2 0 0 1 15 10.76V7a1 1 0 0 1 1-1 2 2 0 0 0 0-4H8a2 2 0 0 0 0 4 1 1 0 0 1 1 1z'/>"


{-| A light bulb.
-}
lightbulb : Icon
lightbulb =
    fromSvg "lightbulb" "<path d='M15 14c.2-1 .7-1.7 1.5-2.5 1-.9 1.5-2.2 1.5-3.5A6 6 0 0 0 6 8c0 1 .2 2.2 1.5 3.5.7.7 1.3 1.5 1.5 2.5'/><path d='M9 18h6'/><path d='M10 22h4'/>"


{-| The sum sign, for totals and aggregates.
-}
sigma : Icon
sigma =
    fromSvg "sigma" "<path d='M18 7V5a1 1 0 0 0-1-1H6.5a.5.5 0 0 0-.4.8l4.5 6a2 2 0 0 1 0 2.4l-4.5 6a.5.5 0 0 0 .4.8H17a1 1 0 0 0 1-1v-2'/>"


{-| Curly braces, for JSON and objects.
-}
braces : Icon
braces =
    fromSvg "braces" "<path d='M8 3H7a2 2 0 0 0-2 2v5a2 2 0 0 1-2 2 2 2 0 0 1 2 2v5c0 1.1.9 2 2 2h1'/><path d='M16 21h1a2 2 0 0 0 2-2v-5c0-1.1.9-2 2-2a2 2 0 0 1-2-2V5a2 2 0 0 0-2-2h-1'/>"


{-| A line that forks.
-}
gitBranch : Icon
gitBranch =
    fromSvg "git-branch" "<line x1='6' y1='3' x2='6' y2='15'/><circle cx='18' cy='6' r='3'/><circle cx='6' cy='18' r='3'/><path d='M18 9a9 9 0 0 1-9 9'/>"


{-| A dot on a line: one step in a history.
-}
gitCommit : Icon
gitCommit =
    fromSvg "git-commit" "<circle cx='12' cy='12' r='4'/><line x1='1.05' y1='12' x2='7' y2='12'/><line x1='17.01' y1='12' x2='22.96' y2='12'/>"


{-| A sun.
-}
sun : Icon
sun =
    fromSvg "sun" "<circle cx='12' cy='12' r='5'/><line x1='12' y1='1' x2='12' y2='3'/><line x1='12' y1='21' x2='12' y2='23'/><line x1='4.22' y1='4.22' x2='5.64' y2='5.64'/><line x1='18.36' y1='18.36' x2='19.78' y2='19.78'/><line x1='1' y1='12' x2='3' y2='12'/><line x1='21' y1='12' x2='23' y2='12'/><line x1='4.22' y1='19.78' x2='5.64' y2='18.36'/><line x1='18.36' y1='5.64' x2='19.78' y2='4.22'/>"


{-| A crescent moon.
-}
moon : Icon
moon =
    fromSvg "moon" "<path d='M21 12.79A9 9 0 1 1 11.21 3 7 7 0 0 0 21 12.79z'/>"


{-| A wireless signal.
-}
wifi : Icon
wifi =
    fromSvg "wifi" "<path d='M5 12.55a11 11 0 0 1 14.08 0'/><path d='M1.42 9a16 16 0 0 1 21.16 0'/><path d='M8.53 16.11a6 6 0 0 1 6.95 0'/><line x1='12' y1='20' x2='12' y2='20.01'/>"


{-| A cloud.
-}
cloud : Icon
cloud =
    fromSvg "cloud" "<path d='M18 10h-1.26A8 8 0 1 0 9 20h9a5 5 0 0 0 0-10z'/>"


{-| A hard drive.
-}
hardDrive : Icon
hardDrive =
    fromSvg "hard-drive" "<line x1='22' y1='12' x2='2' y2='12'/><path d='M5.45 5.11L2 12v6a2 2 0 0 0 2 2h16a2 2 0 0 0 2-2v-6l-3.45-6.89A2 2 0 0 0 16.76 4H7.24a2 2 0 0 0-1.79 1.11z'/><line x1='6' y1='16' x2='6' y2='16.01'/><line x1='10' y1='16' x2='10' y2='16.01'/>"


{-| A desktop screen.
-}
monitor : Icon
monitor =
    fromSvg "monitor" "<rect x='2' y='3' width='20' height='14' rx='2'/><line x1='8' y1='21' x2='16' y2='21'/><line x1='12' y1='17' x2='12' y2='21'/>"


{-| A mobile phone.
-}
smartphone : Icon
smartphone =
    fromSvg "smartphone" "<rect x='5' y='2' width='14' height='20' rx='2'/><line x1='12' y1='18' x2='12' y2='18.01'/>"


{-| A camera.
-}
camera : Icon
camera =
    fromSvg "camera" "<path d='M23 19a2 2 0 0 1-2 2H3a2 2 0 0 1-2-2V8a2 2 0 0 1 2-2h4l2-3h6l2 3h4a2 2 0 0 1 2 2z'/><circle cx='12' cy='13' r='4'/>"


{-| A bold B.
-}
bold : Icon
bold =
    fromSvg "bold" "<path d='M6 4h8a4 4 0 0 1 4 4 4 4 0 0 1-4 4H6z'/><path d='M6 12h9a4 4 0 0 1 4 4 4 4 0 0 1-4 4H6z'/>"


{-| An italic I.
-}
italic : Icon
italic =
    fromSvg "italic" "<line x1='19' y1='4' x2='10' y2='4'/><line x1='14' y1='20' x2='5' y2='20'/><line x1='15' y1='4' x2='9' y2='20'/>"


{-| An underlined U.
-}
underline : Icon
underline =
    fromSvg "underline" "<path d='M6 3v7a6 6 0 0 0 6 6 6 6 0 0 0 6-6V3'/><line x1='4' y1='21' x2='20' y2='21'/>"


{-| A struck-through S.
-}
strikethrough : Icon
strikethrough =
    fromSvg "strikethrough" "<path d='M16 4H9a3 3 0 0 0-2.83 4'/><path d='M14 12a4 4 0 0 1 0 8H6'/><line x1='4' y1='12' x2='20' y2='12'/>"


{-| The letter H, for headings.
-}
heading : Icon
heading =
    fromSvg "heading" "<path d='M6 12h12'/><path d='M6 20V4'/><path d='M18 20V4'/>"


{-| Lines of text aligned to the left.
-}
alignLeft : Icon
alignLeft =
    fromSvg "align-left" "<line x1='17' y1='10' x2='3' y2='10'/><line x1='21' y1='6' x2='3' y2='6'/><line x1='21' y1='14' x2='3' y2='14'/><line x1='17' y1='18' x2='3' y2='18'/>"


{-| Lines of text centered.
-}
alignCenter : Icon
alignCenter =
    fromSvg "align-center" "<line x1='18' y1='10' x2='6' y2='10'/><line x1='21' y1='6' x2='3' y2='6'/><line x1='21' y1='14' x2='3' y2='14'/><line x1='18' y1='18' x2='6' y2='18'/>"


{-| Lines of text aligned to the right.
-}
alignRight : Icon
alignRight =
    fromSvg "align-right" "<line x1='21' y1='10' x2='7' y2='10'/><line x1='21' y1='6' x2='3' y2='6'/><line x1='21' y1='14' x2='3' y2='14'/><line x1='21' y1='18' x2='7' y2='18'/>"


{-| A numbered list.
-}
listOrdered : Icon
listOrdered =
    fromSvg "list-ordered" "<line x1='10' y1='6' x2='21' y2='6'/><line x1='10' y1='12' x2='21' y2='12'/><line x1='10' y1='18' x2='21' y2='18'/><path d='M4 6h1v4'/><path d='M4 10h2'/><path d='M6 18H4c0-1 2-2 2-3s-1-1.5-2-1'/>"


{-| A parcel.
-}
package : Icon
package =
    fromSvg "package" "<path d='M16.5 9.4l-9-5.19'/><path d='M21 16V8a2 2 0 0 0-1-1.73l-7-4a2 2 0 0 0-2 0l-7 4A2 2 0 0 0 3 8v8a2 2 0 0 0 1 1.73l7 4a2 2 0 0 0 2 0l7-4A2 2 0 0 0 21 16z'/><polyline points='3.27 6.96 12 12.01 20.73 6.96'/><line x1='12' y1='22.08' x2='12' y2='12'/>"


{-| A delivery truck.
-}
truck : Icon
truck =
    fromSvg "truck" "<rect x='1' y='3' width='15' height='13'/><polygon points='16 8 20 8 23 11 23 16 16 16 16 8'/><circle cx='5.5' cy='18.5' r='2.5'/><circle cx='18.5' cy='18.5' r='2.5'/>"


{-| A warehouse.
-}
warehouse : Icon
warehouse =
    fromSvg "warehouse" "<path d='M22 8.35V20a2 2 0 0 1-2 2H4a2 2 0 0 1-2-2V8.35A2 2 0 0 1 3.26 6.5l8-3.2a2 2 0 0 1 1.48 0l8 3.2A2 2 0 0 1 22 8.35Z'/><path d='M6 18h12'/><path d='M6 14h12'/><rect x='6' y='10' width='12' height='12'/>"


{-| A shopping cart.
-}
shoppingCart : Icon
shoppingCart =
    fromSvg "shopping-cart" "<circle cx='9' cy='21' r='1'/><circle cx='20' cy='21' r='1'/><path d='M1 1h4l2.68 13.39a2 2 0 0 0 2 1.61h9.72a2 2 0 0 0 2-1.61L23 6H6'/>"


{-| A shopping bag.
-}
shoppingBag : Icon
shoppingBag =
    fromSvg "shopping-bag" "<path d='M6 2L3 6v14a2 2 0 0 0 2 2h14a2 2 0 0 0 2-2V6l-3-4z'/><line x1='3' y1='6' x2='21' y2='6'/><path d='M16 10a4 4 0 0 1-8 0'/>"


{-| A payment card.
-}
creditCard : Icon
creditCard =
    fromSvg "credit-card" "<rect x='1' y='4' width='22' height='16' rx='2'/><line x1='1' y1='10' x2='23' y2='10'/>"


{-| A dollar sign, for money.
-}
dollarSign : Icon
dollarSign =
    fromSvg "dollar-sign" "<line x1='12' y1='1' x2='12' y2='23'/><path d='M17 5H9.5a3.5 3.5 0 0 0 0 7h5a3.5 3.5 0 0 1 0 7H6'/>"


{-| A receipt.
-}
receipt : Icon
receipt =
    fromSvg "receipt" "<path d='M4 2v20l2-1 2 1 2-1 2 1 2-1 2 1 2-1 2 1V2l-2 1-2-1-2 1-2-1-2 1-2-1-2 1Z'/><line x1='8' y1='9' x2='16' y2='9'/><line x1='8' y1='13' x2='16' y2='13'/><line x1='8' y1='17' x2='13' y2='17'/>"


{-| A barcode.
-}
barcode : Icon
barcode =
    fromSvg "barcode" "<path d='M3 5v14'/><path d='M7 5v14'/><path d='M10 5v14'/><path d='M14 5v14'/><path d='M17 5v14'/><path d='M21 5v14'/>"


{-| A calculator.
-}
calculator : Icon
calculator =
    fromSvg "calculator" "<rect x='4' y='2' width='16' height='20' rx='2'/><line x1='8' y1='6' x2='16' y2='6'/><line x1='16' y1='14' x2='16' y2='18'/><line x1='16' y1='10' x2='16' y2='10.01'/><line x1='12' y1='10' x2='12' y2='10.01'/><line x1='8' y1='10' x2='8' y2='10.01'/><line x1='12' y1='14' x2='12' y2='14.01'/><line x1='8' y1='14' x2='8' y2='14.01'/><line x1='12' y1='18' x2='12' y2='18.01'/><line x1='8' y1='18' x2='8' y2='18.01'/>"
