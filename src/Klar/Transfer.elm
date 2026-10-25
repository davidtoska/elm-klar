module Klar.Transfer exposing
    ( State, init, Msg, update, view
    , values, setValues, clear
    , Attribute, options, remote, onRetry, titles, Order, sourceOrder, movedOrder, order
    , label, labelHidden, hint, error, errorMaybe, required, optionalText
    , valueText, disabled, readOnly, visibleRows, locale
    )

{-| Two lists side by side, "Available" and "Chosen", and a way to move items
from one to the other.

Use when: the user assigns many things to one thing, such as products to a promotion, users to a group or columns to an export.
Do not use when: the user picks a few values from a list (as `Klar.MultiSelect`) or values in a hierarchy (as `Klar.TreeSelect`).
Quick path: `init`, `update`, `view`, `options`, `values`

See also [Klar.MultiSelect](Klar-MultiSelect) and [Klar.TreeSelect](Klar-TreeSelect).

    import Klar.Picking as Picking
    import Klar.Select as Select
    import Klar.Transfer as Transfer

    -- model: one State per field; the String is a DOM id, unique on the page
    type alias Model =
        { products : Transfer.State ProductId }

    init =
        { products = Transfer.init "promotion-products" }

    -- update
    ProductsMsg inner ->
        let
            ( products, cmd ) =
                Transfer.update inner model.products
        in
        ( { model | products = products }, Cmd.map ProductsMsg cmd )

    -- view
    Transfer.view ProductsMsg
        [ Transfer.label "Products in the promotion"
        , Transfer.options productIds
            (List.map (\p -> Select.option p.id p.name |> Select.withDescription p.sku) products)
        , Transfer.titles { available = "All products", chosen = "In the promotion" }
        ]
        model.products

    -- reading the value
    Transfer.values model.products --> List ProductId

The items are `Select.Option` values, made with `Select.option` (see
[Klar.Select](Klar-Select)): a value of your own id type, a label, an
optional description, and `disabledOption` for an item that cannot be moved.
Ids are compared through their key (see `Ids.make` in
[Klar.Picking](Klar-Picking)), which keeps thousands of items fast. As in every
Klar field, the state holds the value and there are no out-messages: compare
`Transfer.values` before and after `update` to react.

An item is in one of the lists and never in both: "Available" is the source without
what is chosen. The chosen ids are kept in the order of the source by default, so
the same set gives the same value; `order movedOrder` keeps them in the order the
user moved them in instead (for a list of columns, say). Only a move changes the
order of the value: marking, filtering and looking never do. Ids that you set with
`setValues` are put in the order of the items at once when the field has seen the
items (it has once it was looked at), and otherwise kept as you gave them until the
first move, so give them in the order of the items to have the same value from the
start. An id that the source no longer has stays in "Chosen" with the text
"Unknown value" (or what `valueText` writes) and can be taken out; it is never
dropped quietly. An item that is disabled and chosen is locked: it stays in
"Chosen".

Each list has a filter box above it and a header check box that marks everything
that is shown (a dash when only some are marked), with the count ("3 of 120
selected"). Items are marked with a click or Space and moved with the arrow
buttons between the lists (">" moves the marked items, ">>" all that are shown
after the filter), with a double click, or with the keyboard. The filter only
hides: an item that is marked and hidden by the filter stays marked, and is not
moved by ">" while it is hidden (the count says how many marked items are shown).
Both lists show only
the rows that are visible (see [Klar.VirtualList](Klar-VirtualList)), so a source
with many thousands of items stays fast. On a narrow space the lists are stacked
and the buttons sit between them (the field fills the width of its container, so
put it in one that has a width). Right-to-left languages are not supported: the
keys for moving between the lists assume left-to-right text.

Keyboard: Tab goes from the filter box to the list, to the buttons and on. In a
filter box Enter or ArrowDown moves on to the list (and never submits a form). In a
list ArrowDown and ArrowUp, Home and End, and PageUp and PageDown move the
highlight, and Shift with the arrows marks a range from where the last mark was
made (going back shrinks it). Space marks or unmarks the
highlighted item and Ctrl+A marks all that are shown. Enter moves the marked items
to the other list (the highlighted item when none is marked), Ctrl+ArrowRight in
"Available" and Ctrl+ArrowLeft in "Chosen" do the same, and with Shift they move
all that are shown. Typing letters jumps to the next item that starts with them
(an item that is disabled is skipped, as it is by the arrow keys).

Accessibility: the field is a `group` with the label; each list is a `listbox` with
`aria-multiselectable`, with the highlighted row named by `aria-activedescendant`,
and its rows are `option`s with `aria-selected` for the mark. The move buttons have
names ("Move selected to “Chosen”"). After a move, and after the filter changed, a
polite live region says what happened ("3 items moved to “Chosen”", "12 shown in
“Available”"). The built-in text follows `locale` and is
English by default (see [Klar.Locale](Klar-Locale)).


# State

@docs State, init, Msg, update, view


# Value

@docs values, setValues, clear


# Attributes

Pass attributes to `view` in a list; later ones win over earlier ones.

@docs Attribute, options, remote, onRetry, titles, Order, sourceOrder, movedOrder, order


# Field

The label, hint and error around the field work the same in every Klar form
control.

@docs label, labelHidden, hint, error, errorMaybe, required, optionalText


# Behavior and looks

@docs valueText, disabled, readOnly, visibleRows, locale

-}

import Array exposing (Array)
import Dict exposing (Dict)
import Html exposing (Html)
import Html.Attributes as Attr
import Html.Events as Events
import Json.Decode as Decode
import Klar.Button as Button
import Klar.Checkbox as Checkbox
import Klar.Field as Field
import Klar.Icon as Icon
import Klar.Ids as Ids exposing (Ids)
import Klar.Internal as Internal
import Klar.Internal.Freshness as Freshness
import Klar.Locale as Locale exposing (Locale)
import Klar.Picking as Picking
import Klar.Picking.Texts as Texts exposing (Texts)
import Klar.Picking.View as View
import Klar.Remote as Remote exposing (Remote(..))
import Klar.Search as Search
import Klar.Select exposing (Option)
import Klar.Transfer.Lists as Lists exposing (Chosen, PaneRow, Source)
import Klar.VirtualList as VirtualList
import Process
import Set exposing (Set)
import Task



-- STATE


{-| Everything one transfer keeps track of: the chosen ids, the marks and the
filter text of each list, and which row is highlighted. Make it with `init`, keep
it in your model and pass it to `view` and `update`. The `id` is the type of your
ids.
-}
type State id
    = State (Data id)


type Side
    = Available
    | ChosenSide


{-| One value for each list.
-}
type alias Both a =
    { available : a
    , chosen : a
    }


type alias Data id =
    { id : String
    , chosen : List (Chosen id)
    , chosenKeys : Set String
    , queries : Both String
    , marks : Both (Set String)
    , cursors : Both (Maybe String)
    , anchors : Both (Maybe String)
    , ranges : Both (Set String)
    , lists : Both VirtualList.State
    , typed : { buffer : String, seq : Int }
    , announcement : Maybe { text : String, tick : Int }
    , ticks : Int
    , cache : Maybe (Cache id)
    }


type alias Cache id =
    { options : List (Option id)
    , order : Lists.Order
    , source : Source id
    , rows : Both (Array (PaneRow id))
    , positions : Both (Dict String Int)
    }


pick : Side -> Both a -> a
pick side both =
    case side of
        Available ->
            both.available

        ChosenSide ->
            both.chosen


put : Side -> a -> Both a -> Both a
put side value_ both =
    case side of
        Available ->
            { both | available = value_ }

        ChosenSide ->
            { both | chosen = value_ }


other : Side -> Side
other side =
    case side of
        Available ->
            ChosenSide

        ChosenSide ->
            Available


{-| A transfer with nothing chosen. The `String` is the DOM id of the field and
must be unique on the page: the label points to it, and the ids of the lists, the
filter boxes and the rows are derived from it (`products-available`,
`products-chosen`, `products-available-filter` ...).

    Transfer.init "promotion-products"

-}
init : String -> State id
init domId =
    State
        { id = domId
        , chosen = []
        , chosenKeys = Set.empty
        , queries = { available = "", chosen = "" }
        , marks = { available = Set.empty, chosen = Set.empty }
        , cursors = { available = Nothing, chosen = Nothing }
        , anchors = { available = Nothing, chosen = Nothing }
        , ranges = { available = Set.empty, chosen = Set.empty }
        , lists = { available = VirtualList.init (listId domId Available), chosen = VirtualList.init (listId domId ChosenSide) }
        , typed = { buffer = "", seq = 0 }
        , announcement = Nothing
        , ticks = 0
        , cache = Nothing
        }


sideName : Side -> String
sideName side =
    case side of
        Available ->
            "available"

        ChosenSide ->
            "chosen"


listId : String -> Side -> String
listId domId side =
    domId ++ "-" ++ sideName side


filterId : String -> Side -> String
filterId domId side =
    listId domId side ++ "-filter"


rowDomId : String -> Side -> Int -> String
rowDomId domId side index =
    domId
        ++ "-"
        ++ (case side of
                Available ->
                    "a"

                ChosenSide ->
                    "c"
           )
        ++ "-"
        ++ String.fromInt index


{-| The chosen ids: in the order of the source (or the order of moving, see
`order`), and ids that the source does not have after the others. Ids set with
`setValues` are returned at once, also while the items are still loading.
-}
values : State id -> List id
values (State data) =
    List.map .id data.chosen


{-| Replaces the chosen ids from your code, for example to show a saved record.
Duplicates are dropped. An id that the items do not have is kept and shown as
"Unknown value".

    Transfer.setValues productIds [ sku1, sku2 ] model.products

-}
setValues : Ids id -> List id -> State id -> State id
setValues ids newValues (State data) =
    let
        ( chosen, _ ) =
            List.foldl
                (\id ( kept, seen ) ->
                    let
                        key =
                            Ids.toKey ids id
                    in
                    if Set.member key seen then
                        ( kept, seen )

                    else
                        ( { key = key, id = id, label = labelOf key data } :: kept, Set.insert key seen )
                )
                ( [], Set.empty )
                newValues

        given =
            List.reverse chosen

        -- once the component knows the items, what is set is put in order at
        -- once, so that the value is the same for the same set from the start
        ordered =
            case data.cache of
                Just cache ->
                    Lists.normalize cache.order cache.source given

                Nothing ->
                    given
    in
    State (settle { data | chosen = ordered, chosenKeys = Set.fromList (List.map .key ordered) })


labelOf : String -> Data id -> Maybe String
labelOf key data =
    data.cache
        |> Maybe.andThen (\cache -> Dict.get key cache.source.byKey)
        |> Maybe.map (\item -> item.option.label)


{-| Removes everything from "Chosen": `values` is empty again, without regard to
what is locked.
-}
clear : State id -> State id
clear (State data) =
    State (settle { data | chosen = [], chosenKeys = Set.empty })


{-| After the chosen ids changed from your code: the rows are worked out again from
what the component knows.
-}
settle : Data id -> Data id
settle data =
    case data.cache of
        Just cache ->
            rebuild { options = cache.options, source = cache.source, order = cache.order, visibleRows = 10, titles = { available = "", chosen = "" }, locale = Locale.default } data

        Nothing ->
            data



-- CACHE


{-| What the messages from the view hand over.
-}
type alias Env id =
    { options : List (Option id)
    , source : Source id
    , order : Lists.Order
    , visibleRows : Int
    , titles : Both String
    , locale : Locale
    }


{-| Works out the rows of both lists from the source, the chosen ids and the
filters. The chosen ids are put in order.
-}
rebuild : Env id -> Data id -> Data id
rebuild env data =
    let
        source =
            case data.cache of
                Just cache ->
                    if cache.options == env.options then
                        cache.source

                    else
                        env.source

                Nothing ->
                    env.source

        -- the order of the chosen ids changes only when the user moves items (or
        -- when ids are set from the code and the items are known): looking at the
        -- lists, marking and filtering never change the value
        remembered =
            List.map
                (\c ->
                    case Dict.get c.key source.byKey of
                        Just item ->
                            { c | label = Just item.option.label }

                        Nothing ->
                            c
                )
                data.chosen

        keys =
            Set.fromList (List.map .key remembered)

        availableRows =
            Lists.availableRows source keys (Lists.filterWords data.queries.available)

        chosenRows =
            Lists.chosenRows source remembered (Lists.filterWords data.queries.chosen)

        positions rows =
            rows
                |> Array.toList
                |> List.indexedMap (\i row -> ( row.key, i ))
                |> Dict.fromList
    in
    { data
        | chosen = remembered
        , chosenKeys = keys
        , cache =
            Just
                { options = env.options
                , order = env.order
                , source = source
                , rows = { available = availableRows, chosen = chosenRows }
                , positions = { available = positions availableRows, chosen = positions chosenRows }
                }
    }


ensure : Env id -> Data id -> Data id
ensure env data =
    case data.cache of
        Just cache ->
            if cache.options == env.options && cache.order == env.order then
                data

            else
                rebuild env data

        Nothing ->
            rebuild env data


rowsOf : Side -> Data id -> Array (PaneRow id)
rowsOf side data =
    case data.cache of
        Just cache ->
            pick side cache.rows

        Nothing ->
            Array.empty



-- UPDATE


{-| The messages a transfer sends. Wrap it in a constructor of your own message
type (`ProductsMsg Transfer.Msg`), give that constructor to `view`, and pass the
messages you get back to `update`.
-}
type Msg id
    = Mark Side (Env id) String Bool
    | MarkAll Side (Env id) Bool
    | MoveMarked Side (Env id)
    | MoveEverything Side (Env id)
    | MoveOne Side (Env id) String
    | QueryChanged Side (Env id) String
    | Key Side (Env id) Move
    | Typed Side (Env id) String
    | ClearTyped Int
    | FocusList Side
    | Warm (Env id)
    | ListMsg Side VirtualList.Msg
    | NoOp


type Move
    = Down
    | Up
    | PageDown
    | PageUp
    | First
    | Last
    | ExtendDown
    | ExtendUp
    | ToggleMark
    | MarkEverything
    | Enter
    | Transfer
    | TransferAll


{-| Handles a message of the transfer and returns the new state with a command
(scrolling a list, clearing the type-ahead letters after a pause). Map the command
into your own message type with `Cmd.map`.

    ProductsMsg inner ->
        let
            ( products, cmd ) =
                Transfer.update inner model.products
        in
        ( { model | products = products }, Cmd.map ProductsMsg cmd )

-}
update : Msg id -> State id -> ( State id, Cmd (Msg id) )
update msg (State data) =
    let
        ( next, cmd ) =
            advance msg data
    in
    ( State next, cmd )


advance : Msg id -> Data id -> ( Data id, Cmd (Msg id) )
advance msg data0 =
    case msg of
        Mark side env key extend ->
            let
                data =
                    ensure env data0
            in
            ( markItem side key extend data, Cmd.none )

        MarkAll side env on ->
            let
                data =
                    ensure env data0
            in
            ( markAll side on data, Cmd.none )

        MoveMarked side env ->
            let
                data =
                    ensure env data0
            in
            ( transfer env side (shownMarked side data) data, Cmd.none )

        MoveEverything side env ->
            let
                data =
                    ensure env data0
            in
            ( transfer env side (enabledKeys side data) data, Cmd.none )

        MoveOne side env key ->
            let
                data =
                    ensure env data0
            in
            ( transfer env side [ key ] data, Cmd.none )

        QueryChanged side env text ->
            let
                data =
                    ensure env data0

                changed =
                    rebuild env { data | queries = put side text data.queries, cursors = put side Nothing data.cursors }

                ( list, scroll ) =
                    VirtualList.scrollTo 0 (pick side changed.lists)

                shown =
                    Array.length (rowsOf side changed)

                announced =
                    if List.isEmpty (Lists.filterWords text) then
                        changed.announcement

                    else
                        Just
                            { text = (Texts.texts env.locale).filtered shown (pick side env.titles)
                            , tick = changed.ticks + 1
                            }
            in
            ( { changed
                | lists = put side list changed.lists
                , announcement = announced
                , ticks = changed.ticks + 1
              }
            , Cmd.map (ListMsg side) scroll
            )

        Key side env move ->
            keyMove side env move (ensure env data0)

        Typed side env char ->
            let
                data =
                    ensure env data0

                buffer =
                    data.typed.buffer ++ char

                rows =
                    rowsOf side data

                current =
                    cursorIndex side data

                target =
                    Lists.typeahead buffer
                        current
                        (Array.map
                            (\row ->
                                if row.option.disabled then
                                    ""

                                else
                                    row.labelNorm
                            )
                            rows
                        )

                sequence =
                    data.typed.seq + 1

                typedNow =
                    { buffer = buffer, seq = sequence }

                clearLater =
                    Process.sleep 700 |> Task.perform (\_ -> ClearTyped sequence)
            in
            case target of
                Just i ->
                    let
                        ( moved, scroll ) =
                            cursorTo env side i { data | typed = typedNow }
                    in
                    ( moved, Cmd.batch [ scroll, clearLater ] )

                Nothing ->
                    ( { data | typed = { buffer = "", seq = sequence } }, Cmd.none )

        ClearTyped sequence ->
            ( if sequence == data0.typed.seq then
                { data0 | typed = { buffer = "", seq = sequence } }

              else
                data0
            , Cmd.none
            )

        FocusList side ->
            ( data0, Internal.focus (listId data0.id side) NoOp )

        Warm env ->
            -- the first look at the field (the pointer or the focus comes in)
            -- works the lists out once, so that no later draw has to
            ( ensure env data0, Cmd.none )

        ListMsg side inner ->
            let
                ( list, cmd ) =
                    VirtualList.update inner (pick side data0.lists)
            in
            ( { data0 | lists = put side list data0.lists }, Cmd.map (ListMsg side) cmd )

        NoOp ->
            ( data0, Cmd.none )


rowIsEnabled : PaneRow id -> Bool
rowIsEnabled row =
    not row.option.disabled


{-| The keys of the rows of a list that can be marked and moved.
-}
enabledKeys : Side -> Data id -> List String
enabledKeys side data =
    rowsOf side data |> Array.toList |> List.filter rowIsEnabled |> List.map .key


{-| The marked keys that are on screen (the filter hides the others, which stay
marked).
-}
shownMarked : Side -> Data id -> List String
shownMarked side data =
    let
        marks =
            pick side data.marks
    in
    rowsOf side data
        |> Array.toList
        |> List.filter (\row -> rowIsEnabled row && Set.member row.key marks)
        |> List.map .key


markItem : Side -> String -> Bool -> Data id -> Data id
markItem side key extend data =
    case Dict.get key (positionsOf side data) of
        Nothing ->
            data

        Just index ->
            let
                enabled =
                    Array.get index (rowsOf side data) |> Maybe.map rowIsEnabled |> Maybe.withDefault False

                marks =
                    pick side data.marks
            in
            if not enabled then
                data

            else if extend && pick side data.anchors /= Nothing then
                extendRange side key data

            else
                { data
                    | marks =
                        put side
                            (if Set.member key marks then
                                Set.remove key marks

                             else
                                Set.insert key marks
                            )
                            data.marks
                    , cursors = put side (Just key) data.cursors
                    , anchors = put side (Just key) data.anchors
                    , ranges = put side Set.empty data.ranges
                }


{-| Marks the range from the anchor to a row (Shift+click, Shift+arrow). The range
is the only thing that grows or shrinks while the user goes on: what was marked
before it started stays marked, and what the previous step of the range marked
and this one does not is unmarked.
-}
extendRange : Side -> String -> Data id -> Data id
extendRange side key data =
    let
        positions =
            positionsOf side data

        rows =
            rowsOf side data

        marks =
            pick side data.marks

        previous =
            pick side data.ranges

        from =
            pick side data.anchors |> Maybe.andThen (\anchor -> Dict.get anchor positions)

        to =
            Dict.get key positions
    in
    case ( from, to ) of
        ( Just a, Just b ) ->
            let
                inRange =
                    rows
                        |> Array.toList
                        |> List.indexedMap Tuple.pair
                        |> List.filter (\( i, row ) -> i >= min a b && i <= max a b && rowIsEnabled row)
                        |> List.map (Tuple.second >> .key)
                        |> Set.fromList

                before =
                    Set.diff marks previous
            in
            { data
                | marks = put side (Set.union before inRange) data.marks
                , ranges = put side (Set.diff inRange before) data.ranges
                , cursors = put side (Just key) data.cursors
            }

        _ ->
            data


markAll : Side -> Bool -> Data id -> Data id
markAll side on data =
    let
        keys =
            enabledKeys side data

        marks =
            pick side data.marks
    in
    { data
        | marks =
            put side
                (if on then
                    List.foldl Set.insert marks keys

                 else
                    List.foldl Set.remove marks keys
                )
                data.marks
        , ranges = put side Set.empty data.ranges
    }


positionsOf : Side -> Data id -> Dict String Int
positionsOf side data =
    case data.cache of
        Just cache ->
            pick side cache.positions

        Nothing ->
            Dict.empty


{-| The row that the highlight is on: the one the user moved to, or the first one
that can be reached.
-}
cursorIndex : Side -> Data id -> Maybe Int
cursorIndex side data =
    case pick side data.cursors |> Maybe.andThen (\key -> Dict.get key (positionsOf side data)) of
        Just i ->
            Just i

        Nothing ->
            firstEnabled (rowsOf side data)


firstEnabled : Array (PaneRow id) -> Maybe Int
firstEnabled rows =
    seek 1 0 rows


seek : Int -> Int -> Array (PaneRow id) -> Maybe Int
seek direction from rows =
    case Array.get from rows of
        Nothing ->
            Nothing

        Just row ->
            if rowIsEnabled row then
                Just from

            else
                seek direction (from + direction) rows


rowHeight : Int
rowHeight =
    32


geometry : Int -> Int -> VirtualList.Geometry
geometry rowsVisible count =
    { rowHeight = rowHeight, height = rowsVisible * rowHeight, count = count, inset = 0 }


cursorTo : Env id -> Side -> Int -> Data id -> ( Data id, Cmd (Msg id) )
cursorTo env side i data =
    case Array.get i (rowsOf side data) of
        Just row ->
            let
                ( list, scroll ) =
                    VirtualList.ensureVisible (geometry env.visibleRows (Array.length (rowsOf side data))) i (pick side data.lists)
            in
            ( { data | cursors = put side (Just row.key) data.cursors, lists = put side list data.lists }
            , Cmd.map (ListMsg side) scroll
            )

        Nothing ->
            ( data, Cmd.none )


keyMove : Side -> Env id -> Move -> Data id -> ( Data id, Cmd (Msg id) )
keyMove side env move data =
    let
        rows =
            rowsOf side data

        count =
            Array.length rows

        current =
            cursorIndex side data

        page =
            max 1 (env.visibleRows - 1)

        stay =
            ( data, Cmd.none )

        toward direction from =
            seek direction from rows

        goTo target =
            case target of
                Just i ->
                    let
                        ( moved, scroll ) =
                            cursorTo env side i data
                    in
                    ( { moved
                        | anchors = put side (pick side moved.cursors) moved.anchors
                        , ranges = put side Set.empty moved.ranges
                      }
                    , scroll
                    )

                Nothing ->
                    stay

        near direction start =
            case toward direction start of
                Just i ->
                    Just i

                Nothing ->
                    toward (negate direction) start

        extendTo target =
            case target of
                Just i ->
                    case Array.get i rows of
                        Just row ->
                            let
                                anchored =
                                    if pick side data.anchors == Nothing then
                                        { data | anchors = put side (current |> Maybe.andThen (\c -> Array.get c rows) |> Maybe.map .key) data.anchors }

                                    else
                                        data

                                marked =
                                    markItem side row.key True anchored
                            in
                            cursorTo env side i marked

                        Nothing ->
                            stay

                Nothing ->
                    stay
    in
    if count == 0 then
        stay

    else
        case move of
            Down ->
                goTo (current |> Maybe.andThen (\c -> toward 1 (c + 1)) |> orElse current)

            Up ->
                goTo (current |> Maybe.andThen (\c -> toward -1 (c - 1)) |> orElse current)

            PageDown ->
                goTo (near 1 (min (count - 1) (Maybe.withDefault 0 current + page)))

            PageUp ->
                goTo (near -1 (max 0 (Maybe.withDefault 0 current - page)))

            First ->
                goTo (toward 1 0)

            Last ->
                goTo (toward -1 (count - 1))

            ExtendDown ->
                extendTo (current |> Maybe.andThen (\c -> toward 1 (c + 1)) |> orElse current)

            ExtendUp ->
                extendTo (current |> Maybe.andThen (\c -> toward -1 (c - 1)) |> orElse current)

            ToggleMark ->
                case current |> Maybe.andThen (\c -> Array.get c rows) of
                    Just row ->
                        ( markItem side row.key False data, Cmd.none )

                    Nothing ->
                        stay

            MarkEverything ->
                ( markAll side True data, Cmd.none )

            Enter ->
                case shownMarked side data of
                    [] ->
                        case current |> Maybe.andThen (\c -> Array.get c rows) of
                            Just row ->
                                ( transfer env side [ row.key ] data, Cmd.none )

                            Nothing ->
                                stay

                    keys ->
                        ( transfer env side keys data, Cmd.none )

            Transfer ->
                ( transfer env side (shownMarked side data) data, Cmd.none )

            TransferAll ->
                ( transfer env side (enabledKeys side data) data, Cmd.none )


orElse : Maybe Int -> Maybe Int -> Maybe Int
orElse fallback maybe =
    case maybe of
        Just i ->
            Just i

        Nothing ->
            fallback


{-| Moves the items with these keys out of a list into the other one, announces it,
and puts the highlight on the row that took the place of the first one that left.
-}
transfer : Env id -> Side -> List String -> Data id -> Data id
transfer env side keys data =
    let
        source =
            data.cache |> Maybe.map .source |> Maybe.withDefault env.source

        t =
            Texts.texts env.locale

        before =
            rowsOf side data

        firstGone =
            keys
                |> List.filterMap (\key -> Dict.get key (positionsOf side data))
                |> List.minimum
                |> Maybe.withDefault 0

        ( chosen, moved ) =
            case side of
                Available ->
                    let
                        items =
                            keys |> List.filterMap (\key -> Dict.get key source.byKey)

                        next =
                            Lists.moveIn env.order source items data.chosen
                    in
                    ( next, List.filter (\item -> not item.option.disabled) items |> List.map .key |> Set.fromList |> Set.size )

                ChosenSide ->
                    let
                        ( next, removed ) =
                            Lists.removeFrom source (Set.fromList keys) data.chosen
                    in
                    ( next, List.length removed )

        keyset =
            Set.fromList keys

        rebuilt =
            rebuild env
                { data
                    | chosen = chosen
                    , chosenKeys = Set.fromList (List.map .key chosen)
                    , marks =
                        { available = Set.diff data.marks.available keyset
                        , chosen = Set.diff data.marks.chosen keyset
                        }
                    , ranges = { available = Set.empty, chosen = Set.empty }
                }

        after =
            rowsOf side rebuilt

        landing =
            Array.get (min firstGone (Array.length after - 1)) after
                |> Maybe.map .key
    in
    if moved == 0 || Array.isEmpty before then
        data

    else
        { rebuilt
            | cursors = put side landing rebuilt.cursors
            , ticks = rebuilt.ticks + 1
            , announcement =
                Just
                    { text = t.movedTo moved (pick (other side) env.titles)
                    , tick = rebuilt.ticks + 1
                    }
        }



-- ATTRIBUTES


{-| A setting of a transfer. Make them with the functions below and pass a list to
`view`; later attributes win over earlier ones.
-}
type Attribute id msg
    = Attribute (Config id msg -> Config id msg)


type alias Config id msg =
    { field : Field.Config
    , items : Remote (List (Option id))
    , ids : Maybe (Ids id)
    , titles : Maybe (Both String)
    , order : Lists.Order
    , valueText : Maybe (id -> String)
    , disabled : Bool
    , readOnly : Bool
    , visibleRows : Int
    , locale : Locale
    , onRetry : Maybe msg
    }


configure : List (Attribute id msg) -> Config id msg
configure attributes =
    List.foldl (\(Attribute change) config -> change config)
        { field = Field.empty
        , items = Loaded []
        , ids = Nothing
        , titles = Nothing
        , order = Lists.SourceOrder
        , valueText = Nothing
        , disabled = False
        , readOnly = False
        , visibleRows = 10
        , locale = Locale.default
        , onRetry = Nothing
        }
        attributes


updateField : (Field.Config -> Field.Config) -> Attribute id msg
updateField change =
    Attribute (\config -> { config | field = change config.field })


{-| The items to choose from, as options of [Klar.Select](Klar-Select), with the
`Ids` that write their values as keys. The default is no items. Use `options` or
`remote`, not both: the later one wins.

    Transfer.options productIds [ Select.option sku1 "Coffee 1 kg", Select.option sku2 "Tea 500 g" ]

An option that is `disabledOption` can be seen but not moved. When two options have
the same key the first one is used.

-}
options : Ids id -> List (Option id) -> Attribute id msg
options ids list =
    Attribute (\config -> { config | items = Loaded list, ids = Just ids })


{-| The items from the backend, as a `Remote` (see [Klar.Remote](Klar-Remote)).
"Available" shows loading rows while the data is `Loading` or `NotAsked`, a compact
error with a retry button on `Failed` (see `onRetry`), and the items on `Loaded`.
"Chosen" keeps showing what is chosen, with "Loading ..." for the labels it does
not know yet.

    Transfer.remote productIds model.products

-}
remote : Ids id -> Remote (List (Option id)) -> Attribute id msg
remote ids data =
    Attribute (\config -> { config | items = Tuple.first (Freshness.settle data), ids = Just ids })


{-| The message to send when the user presses the "Try again" button of the error
shown when the items (`remote`) failed to load. The button appears only for
problems that are worth retrying (network trouble, timeouts, server errors).

    Transfer.onRetry ReloadProducts

-}
onRetry : msg -> Attribute id msg
onRetry msg =
    Attribute (\config -> { config | onRetry = Just msg })


{-| The titles of the two lists. The default is "Available" and "Chosen" (in the
language of `locale`). The titles name the lists for screen readers, label the
buttons and are used in the announcement after a move ("3 items moved to “In the
promotion”"), in quotes wherever a title is part of a sentence.

    Transfer.titles { available = "All products", chosen = "In the promotion" }

-}
titles : { available : String, chosen : String } -> Attribute id msg
titles both =
    Attribute (\config -> { config | titles = Just both })


{-| In which order the chosen ids are kept, given to `order`. It is one of
`sourceOrder` and `movedOrder`.
-}
type Order
    = Order Lists.Order


{-| The chosen ids are kept in the order of the items, whatever the order in which
the user moved them. This is the default: after a move the same set of ids is always
the same value, so comparing the value before and after an update tells whether
anything changed. The value changes order only when the user moves items (or when
ids are set from the code and the field knows the items).
-}
sourceOrder : Order
sourceOrder =
    Order Lists.SourceOrder


{-| The chosen ids are kept in the order in which the user moved them, the newest
last: that order is the value, and `setValues` keeps the order it is given. Use it
when the order means something, such as the columns of an export.
-}
movedOrder : Order
movedOrder =
    Order Lists.MovedOrder


{-| Sets the order of the chosen ids, see `Order`. The default is `sourceOrder`.

    Transfer.order Transfer.movedOrder

-}
order : Order -> Attribute id msg
order (Order inner) =
    Attribute (\config -> { config | order = inner })


{-| The label above the field. It names the group for screen readers.
-}
label : String -> Attribute id msg
label text =
    updateField (Field.setLabel text)


{-| Keeps the label for screen readers but does not draw it. It needs a `label`.
-}
labelHidden : Attribute id msg
labelHidden =
    updateField Field.setLabelHidden


{-| A short help text under the field. Screen readers read it with the group.
-}
hint : String -> Attribute id msg
hint text =
    updateField (Field.setHint text)


{-| Shows an error message under the field. The message is announced to screen
readers when it appears.
-}
error : String -> Attribute id msg
error text =
    updateField (Field.setError (Just text))


{-| Like `error`, but takes a `Maybe`: `Nothing` shows no error. Handy with a
validation result.
-}
errorMaybe : Maybe String -> Attribute id msg
errorMaybe maybe =
    updateField (Field.setError maybe)


{-| Marks the field as required: an asterisk after the label. It does not validate
anything; show a problem with `error`, for example when `values` is empty.
-}
required : Attribute id msg
required =
    updateField (Field.setRequired True)


{-| A text after the label of a field that is not `required`, such as
"(optional)".
-}
optionalText : String -> Attribute id msg
optionalText text =
    updateField (Field.setOptionalText text)


{-| How to write a chosen id that the items do not have, for example a product that
was removed. Without it the row says "Unknown value" (or the label that the
component saw when the id was moved).

    Transfer.valueText ProductId.toString

-}
valueText : (id -> String) -> Attribute id msg
valueText toText =
    Attribute (\config -> { config | valueText = Just toText })


{-| While `True` the field is dimmed and nothing can be marked or moved. The value
is kept. Pass a field of your model, for example while a form is saving. The
default is `False`.
-}
disabled : Bool -> Attribute id msg
disabled value_ =
    Attribute (\config -> { config | disabled = value_ })


{-| While `True` the field shows its lists but does not let the user change them,
and the lists can still be scrolled and read. Unlike `disabled` it is not dimmed.
The two are independent; with both set the field is disabled. The default is
`False`.
-}
readOnly : Bool -> Attribute id msg
readOnly value_ =
    Attribute (\config -> { config | readOnly = value_ })


{-| How many rows each list shows before it scrolls. The default is 10; numbers
below 4 or above 30 are brought into that range.
-}
visibleRows : Int -> Attribute id msg
visibleRows n =
    Attribute (\config -> { config | visibleRows = clamp 4 30 n })


{-| The language of the built-in text: the titles, the filter boxes, the counts,
the button names, the announcement after a move and the labels for screen readers.
The default is `Locale.default`, which is English. See [Klar.Locale](Klar-Locale).

    Transfer.locale Locale.nb

-}
locale : Locale -> Attribute id msg
locale value_ =
    Attribute (\config -> { config | locale = value_ })



-- VIEW


{-| The transfer. It takes the constructor that wraps the component's `Msg` in your
own message type, a list of attributes, and the state.

    Transfer.view ProductsMsg
        [ Transfer.label "Products in the promotion"
        , Transfer.options productIds productOptions
        ]
        model.products

Always give the field a `label`; `labelHidden` keeps it off the screen but
available to screen readers.

-}
view : (Msg id -> msg) -> List (Attribute id msg) -> State id -> Html msg
view toMsg attributes (State data) =
    let
        config =
            configure attributes

        field =
            Field.setId data.id config.field

        t =
            Texts.texts config.locale

        paneTitles =
            case config.titles of
                Just both ->
                    both

                Nothing ->
                    { available = t.available, chosen = t.chosen }

        items =
            Remote.withDefault [] config.items

        source =
            case ( config.ids, data.cache ) of
                ( Just ids, Just cache ) ->
                    if cache.options == items then
                        cache.source

                    else
                        Lists.buildSource ids items

                ( Just ids, Nothing ) ->
                    Lists.buildSource ids items

                ( Nothing, _ ) ->
                    Lists.emptySource

        env =
            { options = items
            , source = source
            , order = config.order
            , visibleRows = config.visibleRows
            , titles = paneTitles
            , locale = config.locale
            }

        -- the lists as they are for these items: the cache when it is for them
        current =
            case data.cache of
                Just cache ->
                    if cache.options == items && cache.order == config.order then
                        data

                    else
                        rebuild env data

                Nothing ->
                    rebuild env data

        interactive =
            not config.disabled && not config.readOnly

        fresh =
            case data.cache of
                Just cache ->
                    cache.options == items && cache.order == config.order

                Nothing ->
                    False
    in
    Field.viewGroup field
        (Html.fieldset
            (Field.describedByAttributes field
                ++ [ Attr.id (field.id ++ "-group")
                   , Internal.cls
                        [ "klar-transfer"
                        , if config.disabled then
                            "klar-transfer--disabled"

                          else
                            ""
                        , if field.error /= Nothing then
                            "klar-transfer--invalid"

                          else
                            ""
                        ]
                   , Attr.attribute "role" "group"
                   , Internal.attrIf (field.label /= Nothing) (Attr.attribute "aria-labelledby" (Field.labelId field))
                   ]
                ++ (if fresh then
                        []

                    else
                        -- the first time the pointer or the focus comes in, the lists
                        -- are worked out once and kept, so that later draws do not
                        -- have to (the field cannot do it before: it has no items
                        -- until it is drawn)
                        [ Events.on "mouseenter" (Decode.succeed (toMsg (Warm env)))
                        , Events.on "focusin" (Decode.succeed (toMsg (Warm env)))
                        ]
                   )
            )
            [ viewLegend field
            , Html.div
                [ Internal.cls [ "klar-transfer__box" ]
                , Internal.styleVars [ ( "--klar-transfer-rows", String.fromInt config.visibleRows ) ]
                ]
                [ Html.div [ Internal.cls [ "klar-transfer__panes" ] ]
                    [ viewPane toMsg config t env current interactive Available
                    , viewButtons toMsg config t env current interactive
                    , viewPane toMsg config t env current interactive ChosenSide
                    ]
                ]
            , Html.div
                [ Internal.cls [ "klar-sr-only" ]
                , Attr.attribute "role" "status"
                , Attr.attribute "aria-live" "polite"
                ]
                [ Html.text
                    (case data.announcement of
                        Just a ->
                            -- the text changes on every move, also when it is the same words
                            a.text
                                ++ (if modBy 2 a.tick == 0 then
                                        "\u{00A0}"

                                    else
                                        ""
                                   )

                        Nothing ->
                            ""
                    )
                ]
            ]
        )


viewLegend : Field.Config -> Html msg
viewLegend field =
    case field.label of
        Just text ->
            Html.legend
                [ Internal.cls
                    [ "klar-field__label"
                    , "klar-transfer__legend"
                    , if field.labelHidden then
                        "klar-sr-only"

                      else
                        ""
                    ]
                , Attr.id (Field.labelId field)
                ]
                [ Html.text text
                , Internal.viewIf field.required
                    (Html.span [ Internal.cls [ "klar-field__required" ], Attr.attribute "aria-hidden" "true" ] [ Html.text "*" ])
                , case ( field.required, field.optionalText ) of
                    ( False, Just optional ) ->
                        Html.span [ Internal.cls [ "klar-field__optional" ] ] [ Html.text optional ]

                    _ ->
                        Html.text ""
                ]

        Nothing ->
            Html.text ""



-- PANES


{-| The rows that a list draws, by the same arithmetic as `VirtualList`, so that
`aria-activedescendant` only names a row that exists.
-}
renderedRange : Int -> Int -> VirtualList.State -> ( Int, Int )
renderedRange count rowsVisible list =
    let
        viewport =
            min (rowsVisible * rowHeight) (count * rowHeight)

        -- the list keeps its scroll position inside its rows, so does this
        top =
            clamp 0 (toFloat (max 0 (count * rowHeight - viewport))) (VirtualList.scrollTop list)

        first =
            floor (top / toFloat rowHeight)

        visible =
            ceiling (toFloat viewport / toFloat rowHeight) + 1
    in
    ( max 0 (first - 6), min count (first + visible + 6) )


type alias RowConfig id msg =
    { toMsg : Msg id -> msg
    , config : Config id msg
    , t : Texts
    , env : Env id
    , data : Data id
    , side : Side
    , cursorKey : Maybe String
    , interactive : Bool
    }


viewPane : (Msg id -> msg) -> Config id msg -> Texts -> Env id -> Data id -> Bool -> Side -> Html msg
viewPane toMsg config t env data interactive side =
    let
        title =
            pick side env.titles

        rows =
            rowsOf side data

        shownCount =
            Array.length rows

        enabledCount =
            rows |> Array.toList |> List.filter rowIsEnabled |> List.length

        markedCount =
            List.length (shownMarked side data)

        query =
            pick side data.queries

        filtering =
            not (List.isEmpty (Lists.filterWords query))

        source =
            data.cache |> Maybe.map .source |> Maybe.withDefault Lists.emptySource

        paneTotal =
            case side of
                Available ->
                    Array.length source.items - List.length (List.filter (\c -> Dict.member c.key source.byKey) data.chosen)

                ChosenSide ->
                    List.length data.chosen

        count =
            if filtering then
                t.selectedOfFiltered markedCount shownCount paneTotal

            else
                t.selectedOf markedCount shownCount

        cursor =
            cursorIndex side data

        rc =
            { toMsg = toMsg
            , config = config
            , t = t
            , env = env
            , data = data
            , side = side
            , cursorKey = cursor |> Maybe.andThen (\i -> Array.get i rows) |> Maybe.map .key
            , interactive = interactive
            }

        cursorId =
            case cursor of
                Just i ->
                    let
                        ( from, to ) =
                            renderedRange shownCount config.visibleRows (pick side data.lists)
                    in
                    if i >= from && i < to then
                        Just (rowDomId data.id side i)

                    else
                        Nothing

                Nothing ->
                    Nothing

        toward =
            case side of
                Available ->
                    "ArrowRight"

                ChosenSide ->
                    "ArrowLeft"

        keys =
            if interactive then
                View.onTriggerKeys
                    [ ( "ArrowDown", toMsg (Key side env Down) )
                    , ( "ArrowUp", toMsg (Key side env Up) )
                    , ( "Shift+ArrowDown", toMsg (Key side env ExtendDown) )
                    , ( "Shift+ArrowUp", toMsg (Key side env ExtendUp) )
                    , ( "PageDown", toMsg (Key side env PageDown) )
                    , ( "PageUp", toMsg (Key side env PageUp) )
                    , ( "Home", toMsg (Key side env First) )
                    , ( "End", toMsg (Key side env Last) )
                    , ( " ", toMsg (Key side env ToggleMark) )
                    , ( "Ctrl+a", toMsg (Key side env MarkEverything) )
                    , ( "Ctrl+A", toMsg (Key side env MarkEverything) )
                    , ( "Enter", toMsg (Key side env Enter) )
                    , ( "Ctrl+" ++ toward, toMsg (Key side env Transfer) )
                    , ( "Ctrl+Shift+" ++ toward, toMsg (Key side env TransferAll) )
                    ]
                    (Just (\char -> toMsg (Typed side env char)))

            else
                Internal.noAttr

        body =
            case ( side, config.items ) of
                ( Available, Failed problem ) ->
                    View.viewFailure
                        { locale = config.locale
                        , onRetry = config.onRetry
                        , refocus = toMsg NoOp
                        , leave = toMsg NoOp
                        , noop = toMsg NoOp
                        }
                        problem

                ( Available, Loading ) ->
                    viewLoading t

                ( Available, NotAsked ) ->
                    viewLoading t

                _ ->
                    -- the list is always there, also with no rows, so that keyboard
                    -- focus in it survives moving the last item to the other list
                    Html.div []
                        [ VirtualList.view (ListMsg side >> toMsg)
                            [ VirtualList.rowHeight rowHeight
                            , VirtualList.height (config.visibleRows * rowHeight)
                            , VirtualList.htmlAttrs
                                [ Internal.cls [ "klar-select__list", "klar-transfer__list" ]
                                , Attr.attribute "role" "listbox"
                                , Attr.attribute "aria-multiselectable" "true"
                                , Attr.attribute "aria-label" title
                                , Attr.tabindex 0
                                , Internal.attrIf (not interactive) (Attr.attribute "aria-disabled" "true")
                                , Internal.attrMaybe (Attr.attribute "aria-activedescendant") cursorId
                                , keys
                                ]
                            ]
                            { items = rows, viewRow = viewRow rc }
                            (pick side data.lists)
                        , if shownCount == 0 then
                            View.viewEmpty
                                (if filtering then
                                    Icon.search

                                 else
                                    Icon.inbox
                                )
                                (if filtering then
                                    t.noMatches

                                 else
                                    t.noItems
                                )
                                Nothing

                          else
                            Html.text ""
                        ]

        allMarked =
            enabledCount > 0 && markedCount == enabledCount
    in
    Html.div [ Internal.cls [ "klar-transfer__pane" ] ]
        [ Html.div [ Internal.cls [ "klar-transfer__head" ] ]
            [ Checkbox.view
                [ Checkbox.ariaLabel (t.selectAllIn title)
                , Checkbox.checked allMarked
                , Checkbox.indeterminate (markedCount > 0 && not allMarked)
                , Checkbox.disabled (not interactive || enabledCount == 0)
                , Checkbox.onCheck (MarkAll side env >> toMsg)
                ]
            , Html.span [ Internal.cls [ "klar-transfer__title" ] ] [ Html.text title ]
            , Html.span [ Internal.cls [ "klar-transfer__count", "klar-tabular" ] ] [ Html.text count ]
            ]
        , Html.div [ Internal.cls [ "klar-select__search", "klar-transfer__filter" ] ]
            [ Html.span [ Internal.cls [ "klar-select__search-icon" ] ] [ Icon.view Icon.search ]
            , Html.input
                [ Internal.cls [ "klar-select__search-input" ]
                , Attr.id (filterId data.id side)
                , Attr.type_ "text"
                , Attr.value query
                , Attr.placeholder t.filterPlaceholder
                , Attr.attribute "aria-label" (t.filterLabel title)
                , Attr.attribute "autocomplete" "off"
                , Attr.spellcheck False
                , Attr.disabled config.disabled
                , Events.onInput (QueryChanged side env >> toMsg)

                -- Enter never submits a surrounding form: it goes on to the list
                , View.onKeydown
                    { handled = [ ( "Enter", toMsg (FocusList side) ), ( "ArrowDown", toMsg (FocusList side) ) ]
                    , passive = []
                    }
                ]
                []
            , if query /= "" then
                Html.button
                    [ Internal.cls [ "klar-input__clear" ]
                    , Attr.type_ "button"
                    , Attr.attribute "aria-label" t.clearQuery
                    , Attr.title t.clearQuery
                    , Events.onClick (toMsg (QueryChanged side env ""))
                    ]
                    [ Icon.view Icon.close ]

              else
                Html.text ""
            ]
        , Html.div [ Internal.cls [ "klar-transfer__body" ] ] [ body ]
        ]


viewLoading : Texts -> Html msg
viewLoading t =
    Html.div [ Attr.attribute "aria-busy" "true" ]
        [ View.viewSkeleton 5
        , View.viewFooter t.loading []
        ]


unknownLabel : Config id msg -> Texts -> PaneRow id -> String
unknownLabel config t row =
    if row.option.label /= "" then
        row.option.label

    else
        case config.valueText of
            Just toText ->
                toText row.option.value

            Nothing ->
                case config.items of
                    Loaded _ ->
                        t.unknownValue

                    Failed _ ->
                        t.unavailable

                    _ ->
                        t.loading


viewRow : RowConfig id msg -> Int -> PaneRow id -> Html msg
viewRow rc index row =
    let
        marks =
            pick rc.side rc.data.marks

        isMarked =
            Set.member row.key marks

        isCursor =
            rc.cursorKey == Just row.key

        disabledRow =
            row.option.disabled

        query =
            pick rc.side rc.data.queries

        count =
            Array.length (rowsOf rc.side rc.data)

        text =
            if row.known then
                row.option.label

            else
                unknownLabel rc.config rc.t row

        tooltip =
            case row.option.description of
                Just description ->
                    text ++ " – " ++ description

                Nothing ->
                    text

        clickMsg shift =
            rc.toMsg (Mark rc.side rc.env row.key shift)
    in
    Html.div
        ([ Internal.cls
            [ "klar-select__option"
            , "klar-transfer__row"
            , if isCursor then
                "klar-select__option--highlighted"

              else
                ""
            , if isMarked then
                "klar-transfer__row--marked"

              else
                ""
            , if disabledRow then
                "klar-select__option--disabled"

              else
                ""
            , if row.known then
                ""

              else
                "klar-transfer__row--unknown"
            ]
         , Attr.id (rowDomId rc.data.id rc.side index)
         , Attr.attribute "role" "option"
         , Attr.attribute "aria-selected"
            (if isMarked then
                "true"

             else
                "false"
            )
         , Internal.attrIf disabledRow (Attr.attribute "aria-disabled" "true")
         , Attr.attribute "aria-posinset" (String.fromInt (index + 1))
         , Attr.attribute "aria-setsize" (String.fromInt count)
         , Attr.title
            (if disabledRow && rc.side == ChosenSide then
                tooltip ++ " (" ++ rc.t.lockedItem ++ ")"

             else
                tooltip
            )
         ]
            ++ (if rc.interactive && not disabledRow then
                    [ Events.on "click" (Decode.map clickMsg (Decode.oneOf [ Decode.field "shiftKey" Decode.bool, Decode.succeed False ]))
                    , Events.on "dblclick" (Decode.succeed (rc.toMsg (MoveOne rc.side rc.env row.key)))
                    ]

                else
                    []
               )
        )
        [ Html.span [ Internal.cls [ "klar-select__checkbox" ], Attr.attribute "aria-hidden" "true" ]
            [ Checkbox.view [ Checkbox.checked isMarked, Checkbox.disabled disabledRow ] ]
        , Internal.viewMaybe (\icon -> Html.span [ Internal.cls [ "klar-select__option-icon" ] ] [ Icon.view icon ]) row.option.icon
        , Html.span [ Internal.cls [ "klar-select__option-label" ] ]
            (if row.known then
                Search.highlight query text

             else
                [ Html.text text ]
            )
        , Internal.viewMaybe
            (\description -> Html.span [ Internal.cls [ "klar-select__option-description" ] ] [ Html.text description ])
            row.option.description
        ]


viewButtons : (Msg id -> msg) -> Config id msg -> Texts -> Env id -> Data id -> Bool -> Html msg
viewButtons toMsg _ t env data interactive =
    let
        marked side =
            not (List.isEmpty (shownMarked side data))

        movable side =
            not (List.isEmpty (enabledKeys side data))

        button icon labelText msg available =
            Button.iconOnly
                [ Button.small
                , Button.secondary
                , Button.ariaDisabled (not (interactive && available))
                , Button.onClick msg
                , Button.htmlAttrs [ Internal.onMouseDownPrevent (toMsg NoOp) ]
                ]
                icon
                labelText
    in
    Html.div [ Internal.cls [ "klar-transfer__buttons" ] ]
        [ button Icon.chevronRight (t.moveSelected env.titles.chosen) (toMsg (MoveMarked Available env)) (marked Available)
        , button Icon.chevronsRight (t.moveAll env.titles.chosen) (toMsg (MoveEverything Available env)) (movable Available)
        , button Icon.chevronLeft (t.moveSelected env.titles.available) (toMsg (MoveMarked ChosenSide env)) (marked ChosenSide)
        , button Icon.chevronsLeft (t.moveAll env.titles.available) (toMsg (MoveEverything ChosenSide env)) (movable ChosenSide)
        ]
