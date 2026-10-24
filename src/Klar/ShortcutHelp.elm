module Klar.ShortcutHelp exposing
    ( view
    , State, init, Msg, update
    , open, close, isOpen
    , Attribute, title, locale
    )

{-| The cheat sheet of keyboard shortcuts: a dialog that lists every shortcut of
the application, grouped, with key caps and a small filter box.

Use when: the user needs a cheat sheet of the keyboard shortcuts the application listens to.
Do not use when: you only need to show one shortcut next to a control (use `Klar.Tooltip`).
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

The shortcuts are listed under their `group`, in the order in which the groups
first appear, each with its label and its keys as key caps (a sequence such as
`g o` reads "G then O"). The filter box matches the label, the group and the
keys. A shortcut that also works while the user types in a field (`inInputs`) is
marked "works in fields"; a note at the bottom says that the others do not. The
`mod` in the keys of a shortcut is Ctrl, or Cmd on a Mac, depending on the
keyboard, but the sheet always writes it as "Ctrl". The built-in text follows
`locale`, which is English by default; the groups and labels come from your
shortcuts.


# View

@docs view


# State

@docs State, init, Msg, update


# Opening and closing

@docs open, close, isOpen


# Attributes

@docs Attribute, title, locale

-}

import Html exposing (Html)
import Klar.Button as Button
import Klar.EmptyState as EmptyState
import Klar.Icon as Icon
import Klar.Internal as Internal
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
    , locale : Locale
    }


configure : List (Attribute msg) -> Config
configure attributes =
    List.foldl (\(Attribute change) config -> change config)
        { title = Nothing, locale = Locale.default }
        attributes


{-| The heading of the dialog, which is also its accessible name. The default is
"Keyboard shortcuts".
-}
title : String -> Attribute msg
title value =
    Attribute (\config -> { config | title = Just value })


{-| The language of the built-in texts: the heading, the filter box, the notes and
the Close button. The default is `Locale.default`, which is `Locale.en`. The groups and
labels of the shortcuts come from the application.
-}
locale : Locale -> Attribute msg
locale value =
    Attribute (\config -> { config | locale = value })



-- VIEW


{-| The sheet for these shortcuts: give it the same list as `Shortcut.listen`.
Renders nothing while closed. The first argument turns the sheet's messages into
yours. A `mod` in the keys of a shortcut (Ctrl, or Cmd on a Mac) is always
written as "Ctrl" on the sheet.

    ShortcutHelp.view HelpMsg [ ShortcutHelp.title "Keys" ] shortcuts model.help

-}
view : (Msg -> msg) -> List (Attribute msg) -> List (Shortcut a) -> State -> Overlay msg
view toMsg attributes shortcuts (State state) =
    let
        config =
            configure attributes

        words =
            String.trim state.filter

        matching =
            List.filter (matches words) shortcuts

        groups =
            groupsOf matching

        language =
            { title = Locale.pick config.locale { nb = "Hurtigtaster", en = "Keyboard shortcuts" }
            , filter = Locale.pick config.locale { nb = "Filtrer hurtigtaster", en = "Filter shortcuts" }
            , placeholder = Locale.pick config.locale { nb = "Filtrer hurtigtaster ...", en = "Filter shortcuts ..." }
            , none = Locale.pick config.locale { nb = "Ingen hurtigtaster samsvarer", en = "No shortcuts match" }
            , noneHint = Locale.pick config.locale { nb = "Prøv et annet søkeord.", en = "Try another word." }
            , close = Locale.pick config.locale { nb = "Lukk", en = "Close" }
            , then_ = Locale.pick config.locale { nb = "deretter", en = "then" }
            , inFields = Locale.pick config.locale { nb = "virker også i felt", en = "works in fields" }
            , note = Locale.pick config.locale { nb = "Hurtigtaster virker ikke mens du skriver i et felt, med mindre noe annet er oppgitt.", en = "Shortcuts do not work while you type in a field, unless stated otherwise." }
            }
    in
    Modal.view (\inner -> toMsg (ModalMsg inner))
        [ Modal.title (Maybe.withDefault language.title config.title)
        , Modal.medium
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
                    (List.map (viewGroup language) groups)
            ]
        ]


viewGroup : { a | then_ : String, inFields : String } -> ( String, List (Shortcut b) ) -> Html msg
viewGroup language ( name, members ) =
    Html.section [ Internal.cls [ "klar-shortcuts__group" ] ]
        [ Text.overline name
        , Html.ul [ Internal.cls [ "klar-shortcuts__list" ] ]
            (List.map (viewShortcut language) members)
        ]


viewShortcut : { a | then_ : String, inFields : String } -> Shortcut b -> Html msg
viewShortcut language entry =
    Html.li [ Internal.cls [ "klar-shortcuts__row" ] ]
        [ Html.span [ Internal.cls [ "klar-shortcuts__label" ] ]
            [ Html.text (Shortcut.labelOf entry)
            , Internal.viewIf (Shortcut.firesInInputs entry)
                (Html.span [ Internal.cls [ "klar-shortcuts__note" ] ] [ Html.text language.inFields ])
            ]
        , Html.span [ Internal.cls [ "klar-shortcuts__keys" ] ]
            (Shortcut.keycaps (Shortcut.keysOf entry)
                |> List.map Internal.kbdCombo
                |> List.intersperse (Html.span [ Internal.cls [ "klar-shortcuts__then" ] ] [ Html.text language.then_ ])
            )
        ]


{-| Group by `group`, in the order the groups first appear.
-}
groupsOf : List (Shortcut a) -> List ( String, List (Shortcut a) )
groupsOf shortcuts =
    let
        names =
            List.foldl
                (\entry seen ->
                    if List.member (Shortcut.groupOf entry) seen then
                        seen

                    else
                        seen ++ [ Shortcut.groupOf entry ]
                )
                []
                shortcuts
    in
    List.map (\name -> ( name, List.filter (\entry -> Shortcut.groupOf entry == name) shortcuts )) names


matches : String -> Shortcut a -> Bool
matches words entry =
    if words == "" then
        True

    else
        Search.matches words
            (String.join " "
                [ Shortcut.labelOf entry
                , Shortcut.groupOf entry
                , Shortcut.keycaps (Shortcut.keysOf entry) |> List.map (String.join " ") |> String.join " "
                ]
            )
