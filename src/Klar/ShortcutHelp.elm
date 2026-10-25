module Klar.ShortcutHelp exposing
    ( view
    , State, init, Msg, update
    , open, close, isOpen
    , Attribute, title, platform, extra, locale
    )

{-| The cheat sheet of keyboard shortcuts: a dialog that lists every shortcut of
the application, grouped, with key caps and a small filter box.

Use when: the user needs a cheat sheet of the keyboard shortcuts the application listens to.
Do not use when: you only need to show one shortcut next to a control (use `Klar.Kbd`, or the shortcut of a `Klar.Tooltip`).
Quick path: `init`, `open`, `update`, `view`, `close`, `isOpen`

It is built from the same list of [Klar.Shortcut](Klar-Shortcut) shortcuts that
the application listens to, so the sheet always says what the keys really do.

    import Klar.Shortcut as Shortcut
    import Klar.ShortcutHelp as ShortcutHelp

    -- model
    { help : ShortcutHelp.State } -- ShortcutHelp.init "shortcut-help"

    -- one of the shortcuts, so that "?" opens the sheet
    Shortcut.shortcut (Shortcut.char '?') "Help" "Show the keyboard shortcuts" OpenHelp

    -- update
    OpenHelp ->
        let
            ( help, cmd ) =
                ShortcutHelp.open "" model.help
        in
        ( { model | help = help }, Cmd.map HelpMsg cmd )

    HelpMsg m ->
        let
            ( help, cmd ) =
                ShortcutHelp.update m model.help
        in
        ( { model | help = help }, Cmd.map HelpMsg cmd )

    -- view: the same list as you give to Shortcut.listen
    ShortcutHelp.view HelpMsg [] shortcuts model.help

The sheet is a [Klar.Modal](Klar-Modal): it moves focus to the filter box, keeps
`Tab` inside, closes with `Escape` or the "Close" button and returns focus to
where it came from. It returns an [`Overlay`](Klar-Overlay#Overlay): put it in
the list of overlays of the page, which makes the page behind it inert.

The shortcuts are listed under their `group` (a heading, so a screen reader can
jump between the groups), in the order in which the groups first appear, each
with its label and its keys drawn by [Klar.Kbd](Klar-Kbd): key caps for the eye
(a sequence such as `g o` reads "G then O") and one spoken phrase for a screen
reader ("Control plus K", "question mark"). The keys are written for the
`platform`: `Kbd.pc` (Ctrl, the default) or `Kbd.mac` (⌘). The filter box
matches the label, the group and the keys, also by their other names ("cmd",
"control", "escape", "pgup"), and a polite status says how many shortcuts match.
A shortcut that also works while the user types in a field (`inInputs`) is marked
"works in fields"; a note at the bottom says that the others do not, and that
only the shortcuts with Ctrl, Alt or Cmd work while a dialog is open. The
built-in text follows `locale`, which is English by default; the groups and
labels come from your shortcuts.


# View

@docs view


# State

@docs State, init, Msg, update


# Opening and closing

@docs open, close, isOpen


# Attributes

@docs Attribute, title, platform, extra, locale

-}

import Html exposing (Html)
import Html.Attributes as Attr
import Klar.Button as Button
import Klar.EmptyState as EmptyState
import Klar.Icon as Icon
import Klar.Internal as Internal
import Klar.Internal.Keys as Notation
import Klar.Kbd as Kbd
import Klar.Locale as Locale exposing (Locale)
import Klar.Modal as Modal
import Klar.Overlay exposing (Overlay)
import Klar.Search as Search
import Klar.Shortcut as Shortcut exposing (Shortcut)
import Klar.Text as Text
import Klar.TextInput as TextInput



-- STATE


{-| The state of the sheet: whether it is open, where focus goes back to, and
what is typed in the filter box. Make one with `init` and keep it in your model.
-}
type State
    = State
        { id : String
        , modal : Modal.State
        , filter : String
        }


{-| A closed sheet. The `String` is the DOM id of the dialog and must be unique
on the page; the ids of its filter box and Close button start with it.

    ShortcutHelp.init "shortcut-help"

-}
init : String -> State
init id =
    State { id = id, modal = Modal.init id, filter = "" }


{-| Is the sheet open? The page is made inert by the overlay the sheet returns, so
you need this for your own logic only (a shortcut that toggles the sheet, say).
-}
isOpen : State -> Bool
isOpen (State state) =
    Modal.isOpen state.modal


{-| A message from the sheet. Wrap it in one of your own messages and pass it to
`update`.
-}
type Msg
    = ModalMsg Modal.Msg
    | Filter String
    | Close


{-| Handles the filter box, closing and focus. The command moves keyboard focus,
so map it with `Cmd.map`.
-}
update : Msg -> State -> ( State, Cmd Msg )
update msg ((State state) as current) =
    case msg of
        ModalMsg inner ->
            let
                ( modal, cmd ) =
                    Modal.update inner state.modal
            in
            ( State { state | modal = modal }, Cmd.map ModalMsg cmd )

        Filter text ->
            ( State { state | filter = text }, Cmd.none )

        Close ->
            close current


{-| Opens the sheet with an empty filter and moves focus to the filter box.
`opener` is the DOM id of the element that gets focus back when the sheet closes.
With `""` (the usual case when a shortcut opened it) focus goes back to the
element that had it, if that element has an id.
-}
open : String -> State -> ( State, Cmd Msg )
open opener (State state) =
    let
        ( modal, cmd ) =
            Modal.openWith { opener = opener, focus = [ filterId state.id ] } state.modal
    in
    ( State { state | modal = modal, filter = "" }, Cmd.map ModalMsg cmd )


{-| Closes the sheet and gives focus back to its opener.
-}
close : State -> ( State, Cmd Msg )
close (State state) =
    let
        ( modal, cmd ) =
            Modal.close state.modal
    in
    ( State { state | modal = modal }, Cmd.map ModalMsg cmd )


filterId : String -> String
filterId id =
    id ++ "-filter"


closeButtonId : String -> String
closeButtonId id =
    id ++ "-done"



-- ATTRIBUTES


{-| A setting of the sheet. Make them with the functions below and pass a list to
`view`; later attributes win over earlier ones.
-}
type Attribute msg
    = Attribute (Config -> Config)


type alias Config =
    { title : Maybe String
    , platform : Kbd.Platform
    , extra : List { group : String, label : String, keys : Shortcut.Keys }
    , locale : Locale
    }


configure : List (Attribute msg) -> Config
configure attributes =
    List.foldl (\(Attribute change) config -> change config)
        { title = Nothing, platform = Kbd.pc, extra = [], locale = Locale.default }
        attributes


{-| The heading of the dialog, which is also its accessible name. The default is
"Keyboard shortcuts".
-}
title : String -> Attribute msg
title value =
    Attribute (\config -> { config | title = Just value })


{-| The keyboard to write the keys for, as in [Klar.Kbd](Klar-Kbd): `Kbd.pc` (the
default: Ctrl, Alt, Shift) or `Kbd.mac` (⌘, ⌥, ⇧ in the order a Mac writes them).
Read it once from the user agent with `Kbd.platformFromUserAgent`.

    ShortcutHelp.platform (Kbd.platformFromUserAgent flags.userAgent)

-}
platform : Kbd.Platform -> Attribute msg
platform value =
    Attribute (\config -> { config | platform = value })


{-| Keys worth knowing that are not shortcuts of the application: the keys of
Klar's own components (`Shift+F10` for the menu of a row, `Enter` to edit a cell)
or of your own widgets. They are listed under their group like the shortcuts,
after them, and found by the filter, but never listened to. The default is none.

    ShortcutHelp.extra
        [ { group = "Tables", label = "Open the menu of the row", keys = Shortcut.shift (Shortcut.function 10) }
        , { group = "Tables", label = "Edit the cell", keys = Shortcut.enter }
        ]

-}
extra : List { group : String, label : String, keys : Shortcut.Keys } -> Attribute msg
extra value =
    Attribute (\config -> { config | extra = value })


{-| The language of the built-in texts: the heading, the filter box, the notes,
the spoken names of the keys and the Close button. The default is `Locale.default`, which is `Locale.en`. The groups and
labels of the shortcuts come from the application.
-}
locale : Locale -> Attribute msg
locale value =
    Attribute (\config -> { config | locale = value })



-- VIEW


{-| The sheet for these shortcuts: give it the same list as `Shortcut.listen`.
Renders nothing while closed. The first argument turns the sheet's messages into
yours. A `mod` in the keys of a shortcut is written as Ctrl, or as ⌘ with
`platform Kbd.mac`.

    ShortcutHelp.view HelpMsg [ ShortcutHelp.title "Keys" ] shortcuts model.help

-}
view : (Msg -> msg) -> List (Attribute msg) -> List (Shortcut a) -> State -> Overlay msg
view toMsg attributes shortcuts (State state) =
    let
        config =
            configure attributes

        words =
            String.trim state.filter

        rows =
            List.map rowOf shortcuts
                ++ List.map (\known -> { group = known.group, label = known.label, keys = known.keys, inFields = False }) config.extra

        matching =
            List.filter (matches words) rows

        groups =
            groupsOf matching

        language =
            { title = Locale.pick config.locale { nb = "Hurtigtaster", en = "Keyboard shortcuts" }
            , filter = Locale.pick config.locale { nb = "Filtrer hurtigtaster", en = "Filter shortcuts" }
            , placeholder = Locale.pick config.locale { nb = "Filtrer hurtigtaster ...", en = "Filter shortcuts ..." }
            , none = Locale.pick config.locale { nb = "Ingen hurtigtaster samsvarer", en = "No shortcuts match" }
            , noneHint = Locale.pick config.locale { nb = "Prøv et annet søkeord.", en = "Try another word." }
            , close = Locale.pick config.locale { nb = "Lukk", en = "Close" }
            , inFields = Locale.pick config.locale { nb = "virker også i felt", en = "works in fields" }
            , note =
                Locale.pick config.locale
                    { nb = "Hurtigtaster virker ikke mens du skriver i et felt, med mindre noe annet er oppgitt. Mens en dialog er åpen, virker bare de med Ctrl, Alt eller Cmd."
                    , en = "Shortcuts do not work while you type in a field, unless stated otherwise. While a dialog is open, only the ones with Ctrl, Alt or Cmd work."
                    }
            , count =
                if words == "" then
                    ""

                else
                    countText config.locale (List.length matching)
            }
    in
    Modal.view (\inner -> toMsg (ModalMsg inner))
        [ Modal.medium
        , Modal.fullHeight
        , Modal.locale config.locale
        , Modal.lastFocus (closeButtonId state.id)
        , Modal.footerStart [ Text.caption language.note ]
        , Modal.footer
            [ Button.view
                [ Button.id (closeButtonId state.id)
                , Button.onClick (toMsg Close)
                ]
                language.close
            ]
        ]
        state.modal
        (Maybe.withDefault language.title config.title)
        [ Html.div [ Internal.cls [ "klar-shortcuts" ] ]
            [ Html.div [ Internal.cls [ "klar-shortcuts__filter" ] ]
                [ TextInput.view
                    [ TextInput.id (filterId state.id)
                    , TextInput.label language.filter
                    , TextInput.labelHidden
                    , TextInput.search
                    , TextInput.clearable
                    , TextInput.placeholder language.placeholder
                    , TextInput.value state.filter
                    , TextInput.onInput (\text -> toMsg (Filter text))
                    , TextInput.autocomplete "off"
                    , TextInput.locale config.locale
                    ]
                ]
            , if List.isEmpty groups then
                EmptyState.view
                    [ EmptyState.compact
                    , EmptyState.icon Icon.keyboard
                    , EmptyState.title language.none
                    , EmptyState.description language.noneHint
                    ]

              else
                Html.div [ Internal.cls [ "klar-shortcuts__groups" ] ]
                    (List.indexedMap (viewGroup config state.id language) groups)

            -- Always in the page, so that a change of its text is announced.
            , Html.div
                [ Internal.cls [ "klar-sr-only" ]
                , Attr.attribute "role" "status"
                , Attr.attribute "aria-live" "polite"
                , Attr.attribute "aria-atomic" "true"
                ]
                [ Html.text language.count ]
            ]
        ]


{-| One line of the sheet: a shortcut of the application, or a key of `extra`.
-}
type alias Row =
    { group : String
    , label : String
    , keys : Shortcut.Keys
    , inFields : Bool
    }


rowOf : Shortcut a -> Row
rowOf entry =
    { group = Shortcut.groupOf entry
    , label = Shortcut.labelOf entry
    , keys = Shortcut.keysOf entry
    , inFields = Shortcut.firesInInputs entry
    }


{-| A group: its name is a heading (the title of the dialog is the `h2`) that
names the list under it.
-}
viewGroup : Config -> String -> { a | inFields : String } -> Int -> ( String, List Row ) -> Html msg
viewGroup config sheetId language index ( name, members ) =
    let
        headingId =
            sheetId ++ "-group-" ++ String.fromInt index
    in
    Html.section [ Internal.cls [ "klar-shortcuts__group" ] ]
        [ Html.h3 [ Internal.cls [ "klar-text", "klar-text--overline", "klar-shortcuts__heading" ], Attr.id headingId ] [ Html.text name ]
        , Html.ul [ Internal.cls [ "klar-shortcuts__list" ], Attr.attribute "aria-labelledby" headingId ]
            (List.map (viewShortcut config language) members)
        ]


viewShortcut : Config -> { a | inFields : String } -> Row -> Html msg
viewShortcut config language entry =
    Html.li [ Internal.cls [ "klar-shortcuts__row" ] ]
        [ Html.span [ Internal.cls [ "klar-shortcuts__label" ] ]
            [ Html.text entry.label
            , Internal.viewIf entry.inFields
                (Html.span [ Internal.cls [ "klar-shortcuts__note" ] ] [ Html.text language.inFields ])
            ]
        , Html.span [ Internal.cls [ "klar-shortcuts__keys" ] ]
            [ Kbd.view [ Kbd.platform config.platform, Kbd.locale config.locale ] entry.keys ]
        ]


countText : Locale -> Int -> String
countText language count =
    Locale.pick language
        { nb =
            if count == 1 then
                "1 hurtigtast"

            else
                String.fromInt count ++ " hurtigtaster"
        , en =
            if count == 1 then
                "1 shortcut"

            else
                String.fromInt count ++ " shortcuts"
        }


{-| Group by `group`, in the order the groups first appear.
-}
groupsOf : List Row -> List ( String, List Row )
groupsOf shortcuts =
    let
        names =
            List.foldl
                (\entry seen ->
                    if List.member entry.group seen then
                        seen

                    else
                        seen ++ [ entry.group ]
                )
                []
                shortcuts
    in
    List.map (\name -> ( name, List.filter (\entry -> entry.group == name) shortcuts )) names


matches : String -> Row -> Bool
matches words entry =
    if words == "" then
        True

    else
        Search.matches words
            (String.join " "
                (entry.label
                    :: entry.group
                    :: List.concatMap (List.concatMap keyNames) (Notation.words entry.keys)
                )
            )


{-| A key cap and the other names a user may look for it by.
-}
keyNames : String -> List String
keyNames word =
    word
        :: (case word of
                "Ctrl" ->
                    [ "control", "cmd", "command", "⌘" ]

                "Alt" ->
                    [ "option", "⌥" ]

                "Shift" ->
                    [ "⇧" ]

                "Esc" ->
                    [ "escape" ]

                "Enter" ->
                    [ "return" ]

                "Delete" ->
                    [ "del" ]

                "PageUp" ->
                    [ "pgup", "page up" ]

                "PageDown" ->
                    [ "pgdn", "page down" ]

                "↑" ->
                    [ "up arrow" ]

                "↓" ->
                    [ "down arrow" ]

                "←" ->
                    [ "left arrow" ]

                "→" ->
                    [ "right arrow" ]

                "?" ->
                    [ "question mark" ]

                "/" ->
                    [ "slash" ]

                _ ->
                    []
           )
