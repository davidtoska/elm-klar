module Klar.CommandPalette exposing
    ( view
    , State, init, Msg, update
    , open, close, isOpen, openedFrom, query, setQuery
    , Item, item, withDescription, withIcon, withShortcut, withKeywords, withId
    , Section, section, remote, onRetry, emptyText
    , Attribute, sections, recent, placeholder, label, noResults, locale, zone
    )

{-| A command palette: one search box, usually opened with `Ctrl K`, for commands
("New order", "Go to invoices") and for content ("Ada Lovelace"). Type to narrow
the list, use the arrow keys to move, `Enter` to run and `Escape` to close.

Use when: the application needs one search box for its commands and places, usually opened with Ctrl K.
Do not use when: the user chooses one value in a form (use `Klar.Select`) or searches inside a page (use `Klar.SearchInput`).
Quick path: `init`, `open`, `update`, `view`, `close`, `isOpen`

    import Klar.CommandPalette as CommandPalette
    import Klar.Icon as Icon
    import Klar.Shortcut as Shortcut

    -- model
    { palette : CommandPalette.State } -- CommandPalette.init "palette"

    -- the shortcut (see Klar.Shortcut)
    Shortcut.shortcut (Shortcut.mod (Shortcut.char 'k')) "Navigation" "Open the command palette" OpenPalette
        |> Shortcut.inInputs

    -- update
    OpenPalette ->
        let
            ( palette, cmd ) =
                CommandPalette.open "" model.palette
        in
        ( { model | palette = palette }, Cmd.map PaletteMsg cmd )

    PaletteMsg m ->
        let
            ( palette, cmd ) =
                CommandPalette.update m model.palette
        in
        ( { model | palette = palette }, Cmd.map PaletteMsg cmd )

    -- view
    CommandPalette.view PaletteMsg
        [ CommandPalette.sections
            [ CommandPalette.section "Navigation"
                [ CommandPalette.item "Go to orders" (GoTo Orders)
                    |> CommandPalette.withIcon Icon.table
                    |> CommandPalette.withShortcut (Shortcut.sequence [ Shortcut.char 'g', Shortcut.char 'o' ])
                , CommandPalette.item "New order" NewOrder
                    |> CommandPalette.withIcon Icon.plus
                    |> CommandPalette.withKeywords [ "create", "add" ]
                ]
            , CommandPalette.remote "Customers" model.customerHits
                |> CommandPalette.onRetry SearchCustomers
            ]
        , CommandPalette.recent model.recentItems
        ]
        model.palette

Picking an item sends the item's own message and closes the palette. `Escape`
and a click outside close it without running anything. The palette is a modal
dialog: `view` returns an [`Overlay`](Klar-Overlay#Overlay), and while it is open
the page behind it is inert.
Pressing the shortcut again while the palette is open starts over with an empty
query; call `close` instead if you want the shortcut to toggle.

**Keyboard and screen readers**: the search box keeps focus. `ArrowDown` and
`ArrowUp` move the highlight (and wrap around), `PageDown` and `PageUp` move six
items, `Enter` runs the highlighted item. The highlighted item is the
`aria-activedescendant` of the search box, which is a combobox, and a polite
live region announces the number of results. Focus cannot leave the palette:
`Tab` only moves between the search box and the "Try again" button of a failed
section. `Escape` gives focus back to the element that had it before the palette
opened (if it has an id), or to the `opener` given to `open`.

**Text**: the built-in text (placeholder, headings, hints, the announcement of
the number of results) follows `locale`, which is English by default. The labels
of items and sections are yours.


# View

@docs view


# State

@docs State, init, Msg, update


# Opening, closing and the query

@docs open, close, isOpen, openedFrom, query, setQuery


# Items

An item is a command or a piece of content: a label, the message to send when it
is picked and, if you like, an icon, a description, the keys of its shortcut and
extra words it is found by. The palette keeps track of the highlighted item by
identity, so a result that arrives above it does not move the highlight. Give
items with identical labels a `withId`.

@docs Item, item, withDescription, withIcon, withShortcut, withKeywords, withId


# Sections

A section is a titled group of items. There are two kinds.

`section` takes items that you know in advance, such as the commands of the
application. The palette filters and ranks them with
[Klar.Search](Klar-Search) as the user types: case, diacritics and word order do
not matter, and every word has to match somewhere ("ne ord" finds "New order").
Sections without matches disappear. With an empty query everything is listed,
preceded by `recent` if you gave any.

`remote` takes a `Remote (List Item)` ([Klar.Remote](Klar-Remote)) that the
application fills, for example with the result of a search in the backend. The
palette shows a skeleton while it is `Loading`, a short failure message when it
is `Failed` (with a "Try again" button if the section has an `onRetry` and the
problem can be retried), "No results" when it is `Loaded []` (see `emptyText`),
and nothing while it is `NotAsked` and the search box is empty. Once the user has
typed, `NotAsked` also shows the skeleton (the request is about to start), so the
palette never says "No results" before the answer is there: set the section to
`Loading` or `NotAsked` only while a request is pending, and leave the section
out for a text that is too short to search for. Items that are `Kept` stay in the
list; when the last refresh failed a line "Old data from 14:05" stands above
them. The items of a remote section are not filtered again: the backend already
did that.

The query lives in the state, so the application watches it and starts the
request. Compare before and after the update, and debounce with a counter:

    PaletteMsg m ->
        let
            ( palette, cmd ) =
                CommandPalette.update m model.palette

            changed =
                CommandPalette.query palette /= CommandPalette.query model.palette
        in
        if changed then
            ( { model | palette = palette, hits = NotAsked, ticket = model.ticket + 1 }
            , Cmd.batch
                [ Cmd.map PaletteMsg cmd
                , Process.sleep 250 |> Task.perform (\_ -> Debounced (model.ticket + 1))
                ]
            )

        else
            ( { model | palette = palette }, Cmd.map PaletteMsg cmd )

    Debounced ticket ->
        if ticket == model.ticket && CommandPalette.query model.palette /= "" then
            ( { model | hits = Loading }, searchCustomers ticket (CommandPalette.query model.palette) )

        else
            ( model, Cmd.none )

    GotHits ticket result ->
        if ticket == model.ticket then
            ( { model | hits = Remote.fromResult result }, Cmd.none )

        else
            ( model, Cmd.none )

Results that arrive late for an old query are dropped by the ticket. Take a new
ticket when you open the palette too (`OpenPalette -> ... ticket = model.ticket + 1`,
and `hits = NotAsked`): a search that was still running when the palette was
closed would otherwise answer into the next opening, under an empty query.

@docs Section, section, remote, onRetry, emptyText


# Attributes

@docs Attribute, sections, recent, placeholder, label, noResults, locale, zone

-}

import Browser.Dom as Dom
import Dict
import Html exposing (Html)
import Html.Attributes as Attr
import Html.Events as Events
import Json.Decode as Decode exposing (Decoder)
import Klar.Button as Button
import Klar.EmptyState as EmptyState
import Klar.Icon as Icon exposing (Icon)
import Klar.Internal as Internal
import Klar.Internal.Freshness as Freshness
import Klar.Locale as Locale exposing (Locale)
import Klar.Overlay as Overlay exposing (Overlay)
import Klar.Remote as Remote exposing (Problem, Remote(..))
import Klar.Search as Search
import Klar.Shortcut as Shortcut
import Klar.Skeleton as Skeleton
import Klar.Text as Text
import Task
import Time



-- STATE


{-| The state of the palette: whether it is open, what the user has typed, which
item is highlighted and where focus goes back to. Make one with `init`, keep it
in your model and pass it to `view` and `update`.
-}
type State
    = State
        { id : String
        , open : Bool
        , query : String
        , active : Maybe String
        , opener : String
        }


{-| A closed palette. The `String` is the DOM id of the palette and must be
unique on the page; the ids of its parts (search box, list ...) start with it.

    CommandPalette.init "palette"

-}
init : String -> State
init id =
    State { id = id, open = False, query = "", active = Nothing, opener = "" }


{-| Is the palette open? The page is made inert by the overlay `view` returns;
this is for your own logic (a shortcut that toggles the palette, say).
-}
isOpen : State -> Bool
isOpen (State state) =
    state.open


{-| What the user has typed. Compare it before and after `update` to start
searches in the backend.
-}
query : State -> String
query (State state) =
    state.query


{-| The DOM id of the element the palette was opened from: the `opener` given to
`open`, or the element that had focus. It is `""` if there is none. `Escape`
gives focus back to it. Pass it as the opener of a dialog that an item opens:
the palette is gone by then, and the dialog should return to where the user was.
-}
openedFrom : State -> String
openedFrom (State state) =
    state.opener


{-| Replaces the query and clears the highlight, for example to open the palette
with a prefix. It does not open the palette, and `open` clears the query, so call
it after `open`.

    CommandPalette.open "" model.palette
        |> Tuple.mapFirst (CommandPalette.setQuery "customer ")

-}
setQuery : String -> State -> State
setQuery text (State state) =
    State { state | query = text, active = Nothing }


{-| A message from the palette. Wrap it in one of your own messages and pass it to
`update`.
-}
type Msg
    = Input String
    | Highlight Reveal
    | Hover String
    | Close
    | Picked
    | ClearQuery
    | CameFrom String
    | FocusRetry
    | FocusInput
    | Noop


{-| The highlighted entry and the part of the list that must be visible.
-}
type alias Reveal =
    { key : String
    , top : Int
    , bottom : Int
    }


{-| Handles typing, the highlight, closing and scrolling. The command moves focus
and scrolls the list, so map it with `Cmd.map`. Compare `query` before and after
to start searches.
-}
update : Msg -> State -> ( State, Cmd Msg )
update msg ((State state) as current) =
    case msg of
        Input text ->
            ( State { state | query = text, active = Nothing }
            , scrollList (listId state.id) 0
            )

        Highlight reveal ->
            ( State { state | active = Just reveal.key }
            , revealRange (listId state.id) reveal.top reveal.bottom
            )

        Hover key ->
            ( if state.active == Just key then
                current

              else
                State { state | active = Just key }
            , Cmd.none
            )

        Close ->
            close current

        Picked ->
            ( State { state | open = False }, Cmd.none )

        ClearQuery ->
            ( State { state | query = "", active = Nothing }
            , Cmd.batch [ Internal.focus (inputId state.id) Noop, scrollList (listId state.id) 0 ]
            )

        CameFrom id ->
            -- The search box got focus from this element (outside the palette):
            -- that is where `Escape` gives it back, unless `open` was told.
            if state.opener == "" && id /= "" && not (String.startsWith (state.id ++ "-") id) then
                ( State { state | opener = id }, Cmd.none )

            else
                ( current, Cmd.none )

        FocusRetry ->
            ( current, Internal.focus (retryId state.id) Noop )

        FocusInput ->
            ( current, Internal.focus (inputId state.id) Noop )

        Noop ->
            ( current, Cmd.none )


{-| Opens the palette with an empty query and focuses the search box. `opener`
is the DOM id of the element that gets focus back when the palette is closed
with `Escape`. With `""` (the usual case when it was opened with a shortcut)
focus returns to the element that had it, if that element has an id.

    CommandPalette.open "search-button" model.palette

-}
open : String -> State -> ( State, Cmd Msg )
open opener (State state) =
    ( State
        { state
            | open = True
            , query = ""
            , active = Nothing
            , opener =
                if state.open && opener == "" then
                    state.opener

                else
                    opener
        }
    , Internal.focus (inputId state.id) Noop
    )


{-| Closes the palette without running anything and returns focus to its opener
(see `openedFrom`). Picking an item closes the palette by itself.
-}
close : State -> ( State, Cmd Msg )
close (State state) =
    ( State { state | open = False }
    , if state.open then
        Internal.focusFirst (List.filter ((/=) "") [ state.opener ] ++ [ Internal.pageStartId ]) Noop

      else
        Cmd.none
    )


inputId : String -> String
inputId id =
    id ++ "-input"


listId : String -> String
listId id =
    id ++ "-list"


retryId : String -> String
retryId id =
    id ++ "-retry"


optionId : String -> Int -> String
optionId id index =
    id ++ "-option-" ++ String.fromInt index


scrollList : String -> Float -> Cmd Msg
scrollList id y =
    Dom.setViewportOf id 0 y
        |> Task.attempt (\_ -> Noop)


{-| Scroll the list just enough to show the range `top` to `bottom`.
-}
revealRange : String -> Int -> Int -> Cmd Msg
revealRange id top bottom =
    Dom.getViewportOf id
        |> Task.andThen
            (\found ->
                let
                    current =
                        found.viewport.y

                    next =
                        if toFloat top < current then
                            toFloat top

                        else if toFloat bottom > current + found.viewport.height then
                            toFloat bottom - found.viewport.height

                        else
                            current
                in
                if next == current then
                    Task.succeed ()

                else
                    Dom.setViewportOf id 0 next
            )
        |> Task.attempt (\_ -> Noop)



-- ITEMS


{-| One entry of the palette: a command or a piece of content, with the message
it sends when picked. Make one with `item` and add details with the `with...`
functions.
-}
type Item msg
    = Item
        { id : Maybe String
        , label : String
        , description : Maybe String
        , icon : Maybe Icon
        , shortcut : Maybe Shortcut.Keys
        , keywords : List String
        , onSelect : msg
        }


{-| A command or a piece of content. The first argument is the label that is
shown and searched, the second the message that is sent when the item is picked.

    CommandPalette.item "New order" NewOrder

-}
item : String -> msg -> Item msg
item text msg =
    Item
        { id = Nothing
        , label = text
        , description = Nothing
        , icon = Nothing
        , shortcut = Nothing
        , keywords = []
        , onSelect = msg
        }


{-| A second, quieter line of text after the label. It is searched too.

    CommandPalette.item "Order A-1001" (GoToOrder "A-1001")
        |> CommandPalette.withDescription "Ada Lovelace, 2026-10-20"

-}
withDescription : String -> Item msg -> Item msg
withDescription text =
    mapItem (\data -> { data | description = Just text })


{-| An icon before the label.
-}
withIcon : Icon -> Item msg -> Item msg
withIcon value =
    mapItem (\data -> { data | icon = Just value })


{-| The shortcut of the command, shown as key caps at the right. Write it in the
keys of [Klar.Shortcut](Klar-Shortcut): `mod (char 'k')`, `char '?'`. It is only
a hint: the palette does not listen for the keys, a `Shortcut` in your list does.
-}
withShortcut : Shortcut.Keys -> Item msg -> Item msg
withShortcut keys =
    mapItem (\data -> { data | shortcut = Just keys })


{-| Extra words the item is found by, without showing them. A match on a
keyword ranks below a match on the label.

    CommandPalette.item "New order" NewOrder
        |> CommandPalette.withKeywords [ "create", "add" ]

-}
withKeywords : List String -> Item msg -> Item msg
withKeywords words =
    mapItem (\data -> { data | keywords = words })


{-| A stable identity, for items with the same label (two customers called "Ada
Lovelace"). It keeps the highlight on the right item when the results change.
-}
withId : String -> Item msg -> Item msg
withId value =
    mapItem (\data -> { data | id = Just value })


mapItem : ({ id : Maybe String, label : String, description : Maybe String, icon : Maybe Icon, shortcut : Maybe Shortcut.Keys, keywords : List String, onSelect : msg } -> { id : Maybe String, label : String, description : Maybe String, icon : Maybe Icon, shortcut : Maybe Shortcut.Keys, keywords : List String, onSelect : msg }) -> Item msg -> Item msg
mapItem change (Item data) =
    Item (change data)



-- SECTIONS


{-| A titled group of items. Make one with `section` (items the palette filters
itself) or `remote` (items the application provides).
-}
type Section msg
    = StaticSection String (List (Item msg))
    | RemoteSection
        { title : String
        , remote : Remote (List (Item msg))
        , onRetry : Maybe msg
        , emptyText : Maybe String
        }


{-| A titled group of items that the palette filters and ranks itself as the
user types. The section is left out while no item matches.

    CommandPalette.section "Navigation" [ goToOrders, goToInvoices ]

-}
section : String -> List (Item msg) -> Section msg
section title items =
    StaticSection title items


{-| A titled group of items that the application provides, for example the result
of a search in the backend. It is not filtered again. Pair it with `onRetry`
and `emptyText`.

    CommandPalette.remote "Customers" model.customerHits
        |> CommandPalette.onRetry SearchCustomers

-}
remote : String -> Remote (List (Item msg)) -> Section msg
remote title data =
    RemoteSection { title = title, remote = data, onRetry = Nothing, emptyText = Nothing }


{-| The message that the "Try again" button of a failed remote section sends. The
button is only shown for a problem that is worth retrying (see
`Remote.isRetryable`). Does nothing to a section made with `section`.
-}
onRetry : msg -> Section msg -> Section msg
onRetry msg found =
    case found of
        RemoteSection data ->
            RemoteSection { data | onRetry = Just msg }

        other ->
            other


{-| What a remote section says when it has no items, for example "No customers
found". The default is "No results". Does nothing to a section made with
`section`.
-}
emptyText : String -> Section msg -> Section msg
emptyText text found =
    case found of
        RemoteSection data ->
            RemoteSection { data | emptyText = Just text }

        other ->
            other



-- ATTRIBUTES


{-| A setting of the palette. Make them with the functions below and pass a list
to `view`; later attributes win over earlier ones.
-}
type Attribute msg
    = Attribute (Config msg -> Config msg)


type alias Config msg =
    { sections : List (Section msg)
    , recent : List (Item msg)
    , placeholder : Maybe String
    , label : Maybe String
    , noResults : Maybe String
    , locale : Locale
    , zone : Time.Zone
    }


configure : List (Attribute msg) -> Config msg
configure attributes =
    List.foldl (\(Attribute change) config -> change config)
        { sections = []
        , recent = []
        , placeholder = Nothing
        , label = Nothing
        , noResults = Nothing
        , locale = Locale.default
        , zone = Time.utc
        }
        attributes


{-| The sections, in the order they are shown. The default is none.
-}
sections : List (Section msg) -> Attribute msg
sections value =
    Attribute (\config -> { config | sections = value })


{-| Items shown first, under the heading "Recent", while the query is empty:
the commands the user ran last, for example. The default is none.
-}
recent : List (Item msg) -> Attribute msg
recent value =
    Attribute (\config -> { config | recent = value })


{-| The hint in the empty search box. The default is "Search commands and
content ...".
-}
placeholder : String -> Attribute msg
placeholder value =
    Attribute (\config -> { config | placeholder = Just value })


{-| The accessible name of the dialog and of its list. The default is "Command
palette".
-}
label : String -> Attribute msg
label value =
    Attribute (\config -> { config | label = Just value })


{-| The text shown when nothing matches at all. The default is "No results". A
remote section that is empty has its own text, see `emptyText`.
-}
noResults : String -> Attribute msg
noResults value =
    Attribute (\config -> { config | noResults = Just value })


{-| The language of the built-in texts: the placeholder, the footer, the heading
of the recent items and the announcement of the number of results. The default
is `Locale.default`, which is `Locale.en`.
-}
locale : Locale -> Attribute msg
locale value =
    Attribute (\config -> { config | locale = value })


{-| The time zone of the time in "Old data from 14:05", the note at the top of a
remote section whose data is `Kept` after a failed refresh. The default is UTC.
-}
zone : Time.Zone -> Attribute msg
zone value =
    Attribute (\config -> { config | zone = value })



-- LAYOUT (heights in px; they must match overlay.css)


resultsPadding : Int
resultsPadding =
    4


headingHeight : Int
headingHeight =
    28


itemHeight : Int
itemHeight =
    36


noticeHeight : Int
noticeHeight =
    40


type alias Block msg =
    { key : String
    , title : String
    , body : List (Body msg)
    }


type Body msg
    = EntryBody (Item msg) String
    | LoadingBody
    | FailureBody Problem String (Maybe msg)
    | EmptyBody String


type alias PlacedBlock msg =
    { id : String
    , title : String
    , rows : List (PlacedRow msg)
    }


type PlacedRow msg
    = EntryRow (Placed msg)
    | LoadingRow
    | FailureRow Problem String (Maybe msg)
    | EmptyRow String


type alias Placed msg =
    { key : String
    , index : Int
    , item : Item msg
    , top : Int
    , revealTop : Int
    }


texts : Locale -> { placeholder : String, label : String, noResults : String, recent : String, retry : String, clear : String, navigate : String, select : String, close : String, searching : String }
texts language =
    { placeholder = Locale.pick language { nb = "Søk etter kommandoer og innhold ...", en = "Search commands and content ..." }
    , label = Locale.pick language { nb = "Kommandopalett", en = "Command palette" }
    , noResults = Locale.pick language { nb = "Ingen treff", en = "No results" }
    , recent = Locale.pick language { nb = "Nylig brukt", en = "Recent" }
    , retry = Locale.pick language { nb = "Prøv igjen", en = "Try again" }
    , clear = Locale.pick language { nb = "Tøm søket", en = "Clear search" }
    , navigate = Locale.pick language { nb = "Naviger", en = "Navigate" }
    , select = Locale.pick language { nb = "Velg", en = "Select" }
    , close = Locale.pick language { nb = "Lukk", en = "Close" }
    , searching = Locale.pick language { nb = "Søker ...", en = "Searching ..." }
    }


{-| The groups to show for this query: static sections filtered and ranked,
remote sections as the application gave them.
-}
buildBlocks : Config msg -> String -> List (Block msg)
buildBlocks config text =
    let
        words =
            String.trim text

        language =
            texts config.locale

        recentBlock =
            if words == "" && not (List.isEmpty config.recent) then
                [ { key = "recent", title = language.recent, body = keyedBody "recent" config.recent } ]

            else
                []

        blockFor index found =
            let
                key =
                    "s" ++ String.fromInt index
            in
            case found of
                StaticSection title items ->
                    let
                        matching =
                            rankItems words items
                    in
                    if List.isEmpty matching then
                        []

                    else
                        [ { key = key, title = title, body = keyedBody key matching } ]

                RemoteSection data ->
                    case Tuple.first (Freshness.settle data.remote) of
                        NotAsked ->
                            if words == "" then
                                []

                            else
                                [ { key = key, title = data.title, body = [ LoadingBody, LoadingBody, LoadingBody ] } ]

                        Loading ->
                            [ { key = key, title = data.title, body = [ LoadingBody, LoadingBody, LoadingBody ] } ]

                        Failed problem ->
                            [ { key = key, title = data.title, body = [ FailureBody problem (Remote.title config.locale problem) data.onRetry ] } ]

                        Loaded [] ->
                            [ { key = key, title = data.title, body = [ EmptyBody (Maybe.withDefault language.noResults data.emptyText) ] } ]

                        Loaded items ->
                            [ { key = key
                              , title = data.title
                              , body =
                                    (case Tuple.second (Freshness.settle data.remote) of
                                        Freshness.Stale old ->
                                            [ EmptyBody (Freshness.text config.locale config.zone old.at) ]

                                        _ ->
                                            []
                                    )
                                        ++ keyedBody key items
                              }
                            ]

                        Kept _ ->
                            []
    in
    recentBlock ++ List.concat (List.indexedMap blockFor config.sections)


{-| Give every item a key that is unique within the palette, also when labels
repeat.
-}
keyedBody : String -> List (Item msg) -> List (Body msg)
keyedBody sectionKey items =
    items
        |> List.foldl
            (\((Item data) as entry) ( seen, collected ) ->
                let
                    base =
                        Maybe.withDefault data.label data.id

                    times =
                        Dict.get base seen |> Maybe.withDefault 0
                in
                ( Dict.insert base (times + 1) seen
                , EntryBody entry (sectionKey ++ "|" ++ base ++ "|" ++ String.fromInt times) :: collected
                )
            )
            ( Dict.empty, [] )
        |> Tuple.second
        |> List.reverse


rankItems : String -> List (Item msg) -> List (Item msg)
rankItems words items =
    if words == "" then
        items

    else
        items
            |> List.filterMap (\entry -> Maybe.map (\points -> ( points, entry )) (scoreItem words entry))
            |> List.sortBy Tuple.first
            |> List.map Tuple.second


scoreItem : String -> Item msg -> Maybe Int
scoreItem words (Item data) =
    let
        byLabel =
            Search.score words data.label

        everything =
            String.join " " (data.label :: Maybe.withDefault "" data.description :: data.keywords)

        byAll =
            Search.score words everything |> Maybe.map (\points -> points + 4)
    in
    case ( byLabel, byAll ) of
        ( Just a, Just b ) ->
            Just (min a b)

        ( Just a, Nothing ) ->
            Just a

        ( Nothing, other ) ->
            other


{-| Number the entries and compute where each row sits in the scrolling
list, so the keyboard can keep the highlighted entry in view.
-}
place : String -> List (Block msg) -> ( List (PlacedBlock msg), List (Placed msg) )
place paletteId blocks =
    let
        placeBlock block done =
            let
                revealHeading =
                    if done.y <= resultsPadding then
                        0

                    else
                        done.y

                placeRow body cursor =
                    case body of
                        EntryBody entry key ->
                            let
                                placed =
                                    { key = key
                                    , index = cursor.index
                                    , item = entry
                                    , top = cursor.y
                                    , revealTop =
                                        if List.isEmpty cursor.rows then
                                            revealHeading

                                        else
                                            cursor.y
                                    }
                            in
                            { y = cursor.y + itemHeight
                            , index = cursor.index + 1
                            , rows = EntryRow placed :: cursor.rows
                            , entries = placed :: cursor.entries
                            }

                        LoadingBody ->
                            { cursor | y = cursor.y + itemHeight, rows = LoadingRow :: cursor.rows }

                        FailureBody problem title retry ->
                            { cursor | y = cursor.y + noticeHeight, rows = FailureRow problem title retry :: cursor.rows }

                        EmptyBody text ->
                            { cursor | y = cursor.y + noticeHeight, rows = EmptyRow text :: cursor.rows }

                finished =
                    List.foldl placeRow
                        { y = done.y + headingHeight, index = done.index, rows = [], entries = [] }
                        block.body
            in
            { y = finished.y
            , index = finished.index
            , blocks =
                { id = paletteId ++ "-group-" ++ block.key
                , title = block.title
                , rows = List.reverse finished.rows
                }
                    :: done.blocks
            , entries = finished.entries ++ done.entries
            }

        result =
            List.foldl placeBlock { y = resultsPadding, index = 0, blocks = [], entries = [] } blocks
    in
    ( List.reverse result.blocks, List.reverse result.entries )



-- VIEW


{-| The palette, centered near the top of the window above everything else.
Renders nothing while closed. Put it in the list of overlays of
[`Overlay.host`](Klar-Overlay#host) (or `AppShell.overlays`) so the page behind it
becomes inert. The first argument turns the palette's messages
into yours.

    CommandPalette.view PaletteMsg
        [ CommandPalette.sections [ navigation ] ]
        model.palette

-}
view : (Msg -> msg) -> List (Attribute msg) -> State -> Overlay msg
view toMsg attributes ((State state) as current) =
    Overlay.dialog
        { open = state.open
        , entry = Nothing
        , watch = Nothing
        , render = \_ -> viewPalette toMsg attributes current
        }


viewPalette : (Msg -> msg) -> List (Attribute msg) -> State -> Html msg
viewPalette toMsg attributes (State state) =
    if not state.open then
        Html.text ""

    else
        let
            config =
                configure attributes

            language =
                texts config.locale

            words =
                String.trim state.query

            ( blocks, entries ) =
                place state.id (buildBlocks config state.query)

            count =
                List.length entries

            activeEntry =
                case state.active of
                    Just key ->
                        case List.filter (\entry -> entry.key == key) entries of
                            found :: _ ->
                                Just found

                            [] ->
                                List.head entries

                    Nothing ->
                        List.head entries

            anyLoading =
                List.any (\block -> List.any isLoadingRow block.rows) blocks

            hasFailure =
                List.any (\block -> List.any isFailedRow block.rows) blocks

            hasRetry =
                List.any (\block -> List.any isRetryRow block.rows) blocks

            nothingToShow =
                List.isEmpty blocks

            moveTo delta =
                case activeEntry of
                    Just current ->
                        entries
                            |> List.drop (modBy count (current.index + delta))
                            |> List.head
                            |> Maybe.map (\target -> toMsg (Highlight { key = target.key, top = target.revealTop, bottom = target.top + itemHeight + resultsPadding }))

                    Nothing ->
                        Nothing

            moveClamped delta =
                case activeEntry of
                    Just current ->
                        entries
                            |> List.drop (clamp 0 (count - 1) (current.index + delta))
                            |> List.head
                            |> Maybe.map (\target -> toMsg (Highlight { key = target.key, top = target.revealTop, bottom = target.top + itemHeight + resultsPadding }))

                    Nothing ->
                        Nothing

            navigationKeys =
                List.filterMap identity
                    [ Maybe.map (\msg -> ( "ArrowDown", msg )) (moveTo 1)
                    , Maybe.map (\msg -> ( "ArrowUp", msg )) (moveTo -1)
                    , Maybe.map (\msg -> ( "PageDown", msg )) (moveClamped 6)
                    , Maybe.map (\msg -> ( "PageUp", msg )) (moveClamped -6)
                    ]

            runMsg =
                Maybe.map (\entry -> selectMsg entry.item) activeEntry

            statusText =
                if anyLoading then
                    language.searching

                else if count == 0 then
                    Maybe.withDefault language.noResults config.noResults

                else
                    resultCountText config.locale count
        in
        Html.div [ Internal.cls [ "klar-palette" ] ]
            [ Html.div [ Internal.cls [ "klar-modal-lock" ] ] []
            , Html.div
                [ Internal.cls [ "klar-palette__backdrop" ]
                , Internal.onMouseDownPrevent (toMsg Noop)
                , Events.onClick (toMsg Close)
                ]
                []
            , Html.div
                [ Internal.cls [ "klar-palette__panel" ]
                , Attr.attribute "role" "dialog"
                , Attr.attribute "aria-modal" "true"
                , Attr.attribute "aria-label" (Maybe.withDefault language.label config.label)

                -- One keydown handler only: a node keeps just the last handler
                -- for an event name. The input has its own Enter handler that
                -- runs the item; this one (on the panel) closes the palette.
                , Internal.onKeys
                    (navigationKeys
                        ++ [ ( "Escape", toMsg Close )
                           , ( "Tab", toMsg Noop )
                           , ( "Shift+Tab", toMsg Noop )
                           ]
                        ++ (case runMsg of
                                Just _ ->
                                    [ ( "Enter", toMsg Picked ) ]

                                Nothing ->
                                    []
                           )
                    )
                ]
                [ viewSearch toMsg config language state activeEntry (not nothingToShow || words /= "") runMsg hasRetry
                , Html.div
                    [ Internal.cls [ "klar-palette__results" ]
                    , Attr.id (listId state.id)
                    , Attr.attribute "role" "listbox"
                    , Attr.attribute "aria-label" (Maybe.withDefault language.label config.label)
                    , Internal.onMouseDownPrevent (toMsg Noop)
                    ]
                    (if nothingToShow then
                        [ viewNoResults config language words ]

                     else
                        List.map (viewBlock toMsg state language words activeEntry) blocks
                    )
                , viewFooter language
                , Html.div
                    [ Internal.cls [ "klar-sr-only" ]
                    , Attr.attribute "role" "status"
                    , Attr.attribute "aria-live" "polite"
                    ]
                    [ Html.text
                        (if hasFailure && count == 0 then
                            ""

                         else
                            statusText
                        )
                    ]
                ]
            ]


selectMsg : Item msg -> msg
selectMsg (Item data) =
    data.onSelect


isLoadingRow : PlacedRow msg -> Bool
isLoadingRow row =
    case row of
        LoadingRow ->
            True

        _ ->
            False


isFailedRow : PlacedRow msg -> Bool
isFailedRow row =
    case row of
        FailureRow _ _ _ ->
            True

        _ ->
            False


{-| A failure with a "Try again" button.
-}
isRetryRow : PlacedRow msg -> Bool
isRetryRow row =
    case row of
        FailureRow problem _ (Just _) ->
            Remote.isRetryable problem

        _ ->
            False


viewSearch :
    (Msg -> msg)
    -> Config msg
    -> { a | placeholder : String, clear : String }
    -> { b | id : String, query : String }
    -> Maybe (Placed msg)
    -> Bool
    -> Maybe msg
    -> Bool
    -> Html msg
viewSearch toMsg config language state activeEntry listShown runMsg hasRetry =
    Html.div [ Internal.cls [ "klar-palette__search" ] ]
        [ Html.span [ Internal.cls [ "klar-palette__search-icon" ] ] [ Icon.view Icon.search ]
        , Html.input
            ([ Internal.cls [ "klar-palette__input" ]
             , Attr.id (inputId state.id)
             , Attr.type_ "text"
             , Attr.value state.query
             , Attr.placeholder (Maybe.withDefault language.placeholder config.placeholder)
             , Attr.attribute "role" "combobox"
             , Attr.attribute "aria-autocomplete" "list"
             , Attr.attribute "aria-expanded"
                (if listShown then
                    "true"

                 else
                    "false"
                )
             , Attr.attribute "aria-controls" (listId state.id)
             , Attr.attribute "autocomplete" "off"
             , Attr.attribute "autocapitalize" "off"
             , Attr.attribute "spellcheck" "false"
             , Events.onInput (\text -> toMsg (Input text))

             -- The element that had focus before: where Escape gives it back.
             , Events.on "focusin" (Decode.at [ "relatedTarget", "id" ] Decode.string |> Decode.map (\id -> toMsg (CameFrom id)))
             ]
                ++ (case activeEntry of
                        Just entry ->
                            [ Attr.attribute "aria-activedescendant" (optionId state.id entry.index) ]

                        Nothing ->
                            []
                   )
                -- One keydown handler only (see the panel): Enter runs the
                -- item, Tab reaches the "Try again" button of a failed section.
                ++ (case
                        List.filterMap identity
                            [ Maybe.map (\msg -> ( "Enter", msg )) runMsg
                            , if hasRetry then
                                Just ( "Tab", toMsg FocusRetry )

                              else
                                Nothing
                            ]
                    of
                        [] ->
                            []

                        keys ->
                            [ Internal.onKeys keys ]
                   )
            )
            []
        , if state.query /= "" then
            Html.button
                [ Internal.cls [ "klar-palette__clear" ]
                , Attr.type_ "button"
                , Attr.tabindex -1
                , Attr.attribute "aria-label" language.clear
                , Events.onClick (toMsg ClearQuery)
                ]
                [ Icon.view Icon.close ]

          else
            Html.span [ Internal.cls [ "klar-palette__esc" ] ] [ Text.kbd "Esc" ]
        ]


viewBlock : (Msg -> msg) -> { a | id : String } -> { b | retry : String } -> String -> Maybe (Placed msg) -> PlacedBlock msg -> Html msg
viewBlock toMsg state language words activeEntry block =
    Html.div
        [ Internal.cls [ "klar-palette__group" ]
        , Attr.attribute "role" "group"
        , Attr.attribute "aria-labelledby" block.id
        ]
        (Html.div [ Internal.cls [ "klar-palette__heading" ], Attr.id block.id ] [ Html.text block.title ]
            :: List.map (viewRow toMsg state language words activeEntry) block.rows
        )


viewRow : (Msg -> msg) -> { a | id : String } -> { b | retry : String } -> String -> Maybe (Placed msg) -> PlacedRow msg -> Html msg
viewRow toMsg state language words activeEntry row =
    case row of
        EntryRow placed ->
            viewEntry toMsg state words (Maybe.map .key activeEntry == Just placed.key) placed

        LoadingRow ->
            Html.div [ Internal.cls [ "klar-palette__row" ], Attr.attribute "aria-hidden" "true" ]
                [ Html.div [ Internal.cls [ "klar-palette__item", "klar-palette__item--loading" ] ]
                    [ Skeleton.circle 16
                    , Html.span [ Internal.cls [ "klar-palette__text" ] ] [ Skeleton.line 45 ]
                    ]
                ]

        FailureRow problem title retry ->
            Html.div
                [ Internal.cls [ "klar-palette__notice", "klar-palette__notice--error" ]
                , Attr.attribute "role" "alert"

                -- After "Try again" the button is replaced by the loading rows:
                -- keep the focus in the palette, where Escape works.
                , Events.onClick (toMsg FocusInput)
                ]
                [ Html.span [ Internal.cls [ "klar-palette__notice-icon" ] ] [ Icon.view Icon.errorCircle ]
                , Html.span [ Internal.cls [ "klar-palette__notice-text", "klar-truncate" ] ] [ Html.text title ]
                , case ( retry, Remote.isRetryable problem ) of
                    ( Just msg, True ) ->
                        Button.view
                            [ Button.id (retryId state.id)
                            , Button.small
                            , Button.icon Icon.refresh
                            , Button.onClick msg
                            , Button.htmlAttrs [ retryKeys toMsg ]
                            ]
                            language.retry

                    _ ->
                        Html.text ""
                ]

        EmptyRow text ->
            Html.div [ Internal.cls [ "klar-palette__notice" ] ]
                [ Html.span [ Internal.cls [ "klar-palette__notice-text" ] ] [ Html.text text ] ]


{-| Keys on the "Try again" button. `Tab` goes back to the search box (focus
never leaves the palette); the arrows do too, and then move the highlight as
usual; `Enter` must reach the button, so it is kept from the palette's own
`Enter`, which would close the palette.
-}
retryKeys : (Msg -> msg) -> Html.Attribute msg
retryKeys toMsg =
    Events.custom "keydown"
        (Internal.keyEvent
            |> Decode.andThen
                (\event ->
                    case event.key of
                        "Tab" ->
                            Decode.succeed { message = toMsg FocusInput, stopPropagation = True, preventDefault = True }

                        "ArrowDown" ->
                            Decode.succeed { message = toMsg FocusInput, stopPropagation = False, preventDefault = False }

                        "ArrowUp" ->
                            Decode.succeed { message = toMsg FocusInput, stopPropagation = False, preventDefault = False }

                        "Enter" ->
                            Decode.succeed { message = toMsg Noop, stopPropagation = True, preventDefault = False }

                        _ ->
                            Decode.fail "not a key of the retry button"
                )
        )


viewEntry : (Msg -> msg) -> { a | id : String } -> String -> Bool -> Placed msg -> Html msg
viewEntry toMsg state words isActive placed =
    case placed.item of
        Item data ->
            -- The click goes first to the inner element (the application's
            -- message) and then bubbles to the outer one, which closes the
            -- palette.
            Html.div
                [ Internal.cls [ "klar-palette__row" ]
                , Attr.id (optionId state.id placed.index)
                , Attr.attribute "role" "option"
                , Attr.attribute "aria-selected"
                    (if isActive then
                        "true"

                     else
                        "false"
                    )
                , Events.onClick (toMsg Picked)
                ]
                [ Html.div
                    [ Internal.cls
                        [ "klar-palette__item"
                        , if isActive then
                            "klar-palette__item--active"

                          else
                            ""
                        ]
                    , Events.onClick data.onSelect
                    , Events.on "mousemove" (movedDecoder (toMsg (Hover placed.key)))
                    ]
                    [ Html.span [ Internal.cls [ "klar-palette__icon" ] ]
                        [ Internal.viewMaybe Icon.view data.icon ]
                    , Html.span [ Internal.cls [ "klar-palette__text" ] ]
                        [ Html.span [ Internal.cls [ "klar-palette__label", "klar-truncate" ] ] (Search.highlight words data.label)
                        , Internal.viewMaybe
                            (\text -> Html.span [ Internal.cls [ "klar-palette__description", "klar-truncate" ] ] [ Html.text text ])
                            data.description
                        ]
                    , Internal.viewMaybe viewShortcut data.shortcut
                    ]
                ]


{-| Pointer movement, not just a pointer that rests where the list scrolled to.
-}
movedDecoder : msg -> Decoder msg
movedDecoder msg =
    Decode.map2 (\dx dy -> ( dx, dy ))
        (Decode.oneOf [ Decode.field "movementX" Decode.float, Decode.succeed 1 ])
        (Decode.oneOf [ Decode.field "movementY" Decode.float, Decode.succeed 1 ])
        |> Decode.andThen
            (\( dx, dy ) ->
                if dx == 0 && dy == 0 then
                    Decode.fail "did not move"

                else
                    Decode.succeed msg
            )


viewShortcut : Shortcut.Keys -> Html msg
viewShortcut keys =
    Html.span [ Internal.cls [ "klar-palette__keys" ] ]
        (Shortcut.keycaps keys
            |> List.map Text.kbdCombo
        )


viewNoResults : Config msg -> { a | noResults : String } -> String -> Html msg
viewNoResults config language words =
    EmptyState.view
        [ EmptyState.compact
        , EmptyState.icon Icon.search
        , EmptyState.title (Maybe.withDefault language.noResults config.noResults)
        , if words == "" then
            EmptyState.description ""

          else
            EmptyState.description
                (Locale.pick config.locale
                    { nb = "Ingen treff for «" ++ words ++ "». Prøv et annet søkeord."
                    , en = "Nothing matches “" ++ words ++ "”. Try another word."
                    }
                )
        ]


viewFooter : { a | navigate : String, select : String, close : String } -> Html msg
viewFooter language =
    Html.div [ Internal.cls [ "klar-palette__footer" ] ]
        [ hint [ "↑", "↓" ] language.navigate
        , hint [ "↵" ] language.select
        , hint [ "Esc" ] language.close
        ]


hint : List String -> String -> Html msg
hint keys text =
    Html.span [ Internal.cls [ "klar-palette__hint" ] ]
        [ Text.kbdCombo keys
        , Html.text text
        ]


resultCountText : Locale -> Int -> String
resultCountText language count =
    Locale.pick language
        { nb = String.fromInt count ++ " treff"
        , en =
            if count == 1 then
                "1 result"

            else
                String.fromInt count ++ " results"
        }
