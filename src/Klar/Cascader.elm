module Klar.Cascader exposing
    ( State, init, Msg, update, view
    , value, setValue, setPath, clear
    , query, isOpen, open, close, loadRequests
    , Attribute, nodes, remote, onRetry, onRetryChildren, anyNode, separator
    , label, labelHidden, hint, error, errorMaybe, required, optionalText
    , placeholder, searchPlaceholder, clearable, valueText, disabled, readOnly, size, visibleRows, locale, settings
    )

{-| A field for choosing a path through levels: Region, Country, City; Category,
Subcategory, Product. The popup shows one column for each level, like a file
browser, and the closed field shows the path ("Europe / Norway / Oslo").

Use when: the user picks one value by drilling down through levels they know, such as country, region and city.
Do not use when: the user picks from a tree with check boxes (as `Klar.TreeSelect`) or from one flat list (as `Klar.Select`).
Quick path: `init`, `update`, `view`, `nodes`, `value`

See also [Klar.TreeSelect](Klar-TreeSelect) and [Klar.Select](Klar-Select).

    import Klar.Cascader as Cascader
    import Klar.Picking as Picking

    -- model: one State per field; the String is a DOM id, unique on the page
    type alias Model =
        { place : Cascader.State PlaceId }

    init =
        { place = Cascader.init "place" }

    -- update
    PlaceMsg inner ->
        let
            ( place, cmd ) =
                Cascader.update inner model.place
        in
        ( { model | place = place }, Cmd.map PlaceMsg cmd )

    -- view
    Cascader.view PlaceMsg
        [ Cascader.label "Place"
        , Cascader.nodes
            [ Picking.branch placeIds europe
                "Europe"
                [ Picking.branch placeIds norway "Norway" [ Picking.leaf placeIds oslo "Oslo" ] ]
            ]
        , Cascader.clearable
        ]
        model.place

    -- reading the value: the path from the top down
    Cascader.value model.place --> Maybe (List PlaceId)

The nodes are built with [Klar.Picking](Klar-Picking), the same as for a
[Klar.TreeSelect](Klar-TreeSelect), so one hierarchy serves both. The value is the
path of ids from the top level down to the node that was chosen: `Just [ europe,
norway, oslo ]`, or `Nothing` when nothing is chosen (an empty path cannot exist).
By default only a node without children can be chosen; `anyNode` also lets the user
choose a branch. As in every Klar field, the state holds the value and there are no
out-messages: compare `Cascader.value` before and after `update` to react.

A path that is not a path of the nodes you give (a place that was removed, a saved
path through a branch that is not loaded) is not dropped: the field shows the
labels it remembers from when the path was chosen or set with `setPath`, and
otherwise "Unknown value" (or what `valueText` writes).

Typing in the search box leaves the columns and shows a flat list of the full paths
that match ("oslo" finds "Europe / Norway / Oslo"), best match first; clearing the
text brings the columns back as they were. Only the rows on screen are drawn, in
every column and in the list of results (see [Klar.VirtualList](Klar-VirtualList)),
so a level with thousands of nodes stays fast.

Nodes can come from the backend, the top level as a `Remote` (`remote`) and the
children of a node with `Picking.lazy`. When the user opens a lazy node whose
children are `NotAsked`, `loadRequests` names it once (call it after every update);
mark it `Loading`, fetch it, and put the answer in the node the next time you build
the tree. A branch that failed shows the problem with a "Try again" button
(`onRetryChildren`). Data that is `Kept` stays on screen: a branch whose children
are refreshed is busy, and a column of old children starts with a row that says "Old
data from 14:05" with "Try again" (the top level says it above the columns; give
`settings` for the time zone).

Keyboard: on the closed field Enter, Space, ArrowDown, ArrowUp or a printable
character open the popup. The keyboard focus stays in the search box, and the
highlight is shown with `aria-activedescendant`. ArrowDown and ArrowUp move in the
column, Home and End go to its first and last node (in a text they move the caret,
and Ctrl or Cmd with them move in the column), PageUp and PageDown move a page. ArrowRight opens the highlighted branch and then moves into its column,
ArrowLeft closes the open branch and then moves back to its parent (in a text they
move the caret instead, until it is at the end or the start). Enter chooses the
highlighted node when it can be chosen, and otherwise opens the branch like
ArrowRight. Escape closes the popup and returns to the field, and Tab closes it and
moves on. In the list of search results ArrowDown, ArrowUp, Home, End and Enter
work on the results. Typing searches, so there is no separate type-ahead.

Accessibility: no standard pattern describes columns, so a cascader is a tree that
is drawn in columns. The field is a button with `role="combobox"` and
`aria-haspopup="tree"`; the popup is a `tree` whose `treeitem` rows have
`aria-level` (the column), `aria-setsize` and `aria-posinset` (among the nodes of
their column), `aria-expanded` (the opened branch) and `aria-selected` (the node
that is chosen, the end of the path). The nodes of each column after the first are
a `group` that the opened branch before it owns (`aria-owns`), so a screen reader
hears Oslo inside Norway inside Europe and not one column after the other. While
the user searches, the search box offers the `listbox` of results. The field also lists
the whole path for a screen reader when the visible path is shortened. The
built-in text follows `locale` and is English by default (see
[Klar.Locale](Klar-Locale)).

On a narrow screen the columns do not wrap: the popup scrolls sideways, and
opening a branch scrolls to its column. Right-to-left languages are not supported:
the arrow keys and the order of the columns assume left-to-right text.


# State

@docs State, init, Msg, update, view


# Value

@docs value, setValue, setPath, clear


# Popup and lazy nodes

@docs query, isOpen, open, close, loadRequests


# Attributes

Pass attributes to `view` in a list; later ones win over earlier ones.

@docs Attribute, nodes, remote, onRetry, onRetryChildren, anyNode, separator


# Field

The label, hint and error around the field work the same in every Klar form
control.

@docs label, labelHidden, hint, error, errorMaybe, required, optionalText


# Behavior and looks

@docs placeholder, searchPlaceholder, clearable, valueText, disabled, readOnly, size, visibleRows, locale, settings

-}

import Array exposing (Array)
import Browser.Dom as Dom
import Dict exposing (Dict)
import Html exposing (Html)
import Html.Attributes as Attr
import Html.Events as Events
import Html.Keyed as Keyed
import Json.Decode as Decode
import Klar.Button as Button
import Klar.Cascader.Columns as Columns exposing (Cell(..), Column)
import Klar.Field as Field
import Klar.Icon as Icon
import Klar.Ids as Ids exposing (Ids)
import Klar.Internal as Internal
import Klar.Internal.Freshness as Freshness exposing (Freshness)
import Klar.Locale as Locale exposing (Locale)
import Klar.Picking as Picking exposing (Node)
import Klar.Picking.Index as Index exposing (Index, Kids(..))
import Klar.Picking.Texts as Texts exposing (Texts)
import Klar.Picking.View as View
import Klar.Remote as Remote exposing (Remote(..))
import Klar.Search as Search
import Klar.Settings as Settings exposing (Settings)
import Klar.Spinner as Spinner
import Klar.Theme as Theme exposing (Size(..))
import Klar.VirtualList as VirtualList
import Set exposing (Set)
import Task



-- STATE


{-| Everything one cascader keeps track of: the chosen path, whether the popup is
open, the search text, which branches are open and which row is highlighted. Make
it with `init`, keep it in your model and pass it to `view` and `update`. The
`id` is the type of your ids.
-}
type State id
    = State (Data id)


type alias Data id =
    { id : String
    , open : Bool
    , query : String
    , path : List (Step id)
    , trail : List String
    , cursor : Maybe Pos
    , revealed : Bool
    , found : Maybe Int
    , lists : Dict Int VirtualList.State
    , results : VirtualList.State
    , cache : Maybe (Cache id)
    , requested : List id
    }


{-| One node of the chosen path: the id as the application gave it, its key, and
its label when the component has seen the node.
-}
type alias Step id =
    { id : id
    , key : String
    , label : Maybe String
    }


{-| A row that can be highlighted: a node, or the failure under a branch.
-}
type Pos
    = AtNode String
    | AtRetry String


type alias Cache id =
    { nodes : List (Node id)
    , anyNode : Bool
    , separator : String
    , index : Index id
    , searchables : Maybe (Array Columns.Searchable)
    , resultsFor : String
    , results : Array Columns.Result
    , columns : List Column
    }


{-| A closed cascader with nothing chosen. The `String` is the DOM id of the
field and must be unique on the page: the label points to it, and the ids of the
popup are derived from it (`place-search`, `place-tree`, `place-popup`).

    Cascader.init "place"

-}
init : String -> State id
init domId =
    State
        { id = domId
        , open = False
        , query = ""
        , path = []
        , trail = []
        , cursor = Nothing
        , revealed = False
        , found = Nothing
        , lists = Dict.empty
        , results = VirtualList.init (resultsId domId)
        , cache = Nothing
        , requested = []
        }


treeId : String -> String
treeId domId =
    domId ++ "-tree"


searchId : String -> String
searchId domId =
    domId ++ "-search"


popupId : String -> String
popupId domId =
    domId ++ "-popup"


resultsId : String -> String
resultsId domId =
    domId ++ "-results"


columnId : String -> Int -> String
columnId domId depth =
    domId ++ "-col-" ++ String.fromInt depth


{-| The group of the nodes of a column after the first (owned by the open branch
before it).
-}
groupId : String -> Int -> String
groupId domId depth =
    domId ++ "-group-" ++ String.fromInt depth


itemDomId : String -> Int -> Int -> String
itemDomId domId depth index =
    domId ++ "-c" ++ String.fromInt depth ++ "-" ++ String.fromInt index


resultDomId : String -> Int -> String
resultDomId domId index =
    domId ++ "-r" ++ String.fromInt index


{-| The chosen path from the top down, or `Nothing` when nothing is chosen. A path
set with `setValue` is returned at once, also while the nodes are still loading.
-}
value : State id -> Maybe (List id)
value (State data) =
    case data.path of
        [] ->
            Nothing

        steps ->
            Just (List.map .id steps)


{-| Chooses a path from your code, for example to show a saved record. The labels
are looked up in the nodes when the field is shown; use `setPath` when the nodes
may not contain them (a branch that is not loaded). An empty list clears the
value.

    Cascader.setValue placeIds [ europe, norway, oslo ] model.place

-}
setValue : Ids id -> List id -> State id -> State id
setValue ids path (State data) =
    State (refreshCached { data | path = List.map (\id -> { id = id, key = Ids.toKey ids id, label = Nothing }) path })


{-| Chooses a path of nodes and remembers their labels, so the field shows the
path even when the nodes you give do not contain it. Only the nodes themselves are
used, not their children. An empty list clears the value.

    Cascader.setPath [ europeNode, norwayNode, osloNode ] model.place

-}
setPath : List (Node id) -> State id -> State id
setPath path (State data) =
    State
        (refreshCached
            { data
                | path = List.map (\node -> { id = Picking.id node, key = Picking.key node, label = Just (Picking.label node) }) path
            }
        )


{-| Removes the chosen path, so `value` is `Nothing` again.
-}
clear : State id -> State id
clear (State data) =
    State (refreshCached { data | path = [] })


{-| The text in the search box while the popup is open, and `""` when it is
closed.
-}
query : State id -> String
query (State data) =
    data.query


{-| Whether the popup is open.
-}
isOpen : State id -> Bool
isOpen (State data) =
    data.open


{-| Opens the popup with an empty search and moves focus into its search box, for
example from a button of your own. Map the command like the one from `update`.
-}
open : State id -> ( State id, Cmd (Msg id) )
open (State data) =
    ( State
        { data
            | open = True
            , query = ""
            , cursor = Nothing
            , found = Nothing

            -- as when the user opens the field: the columns open on the value
            -- (when the search box gets the focus) and start at the top
            , trail = []
            , revealed = False
            , lists = Dict.empty
            , results = VirtualList.reset data.results
            , requested = []
        }
    , Internal.focus (searchId data.id) NoOp
    )


{-| Closes the popup, forgets the search text, and gives focus back to the field
if the popup was open. Map the command like the one from `update`.
-}
close : State id -> ( State id, Cmd (Msg id) )
close (State data) =
    ( State { data | open = False, query = "", cursor = Nothing, found = Nothing }
    , if data.open then
        Internal.focus data.id NoOp

      else
        Cmd.none
    )


{-| The lazy nodes that the last `update` opened while their children are
`NotAsked`: the user opened them, or the popup opened on a value inside them.
Usually zero or one. Call it after every `update` of the field, set the children of
the nodes it names to `Loading` in your data and fetch them; the next time you
build the nodes they hold the answer. Each node is named once (scrolling a column
or another message does not name it again), so the wiring below never fetches
twice and needs no guard of its own.

    PlaceMsg inner ->
        let
            ( place, cmd ) =
                Cascader.update inner model.place

            requested =
                Cascader.loadRequests place
        in
        ( { model | place = place, areas = markLoading requested model.areas }
        , Cmd.batch (Cmd.map PlaceMsg cmd :: List.map fetchAreas requested)
        )

A node that you leave `NotAsked` is named again the next time the popup opens. If
you set an open node back to `NotAsked` yourself (to load it again), fetch it
yourself too. After a failure the user retries with the button that
`onRetryChildren` adds.

-}
loadRequests : State id -> List id
loadRequests (State data) =
    if data.open then
        data.requested

    else
        []


{-| The keys of the open branches of the open popup whose children are `NotAsked`.
-}
waitingKeys : Data id -> List String
waitingKeys data =
    case ( data.open, data.cache ) of
        ( True, Just cache ) ->
            List.filter (\key -> Maybe.map .kids (Index.get key cache.index) == Just Unloaded) data.trail

        _ ->
            []


{-| The nodes that wait for their children after a message and did not before it.
-}
newlyWaiting : Data id -> Data id -> List id
newlyWaiting before after =
    case ( waitingKeys after, after.cache ) of
        ( [], _ ) ->
            []

        ( keys, Just cache ) ->
            let
                old =
                    waitingKeys before
            in
            keys
                |> List.filter (\key -> not (List.member key old))
                |> List.filterMap (\key -> Index.get key cache.index |> Maybe.map (.node >> Picking.id))

        ( _, Nothing ) ->
            []



-- CACHE


{-| What the messages from the view hand over: the nodes and the settings that the
rules for choosing depend on.
-}
type alias Env id =
    { nodes : List (Node id)
    , anyNode : Bool
    , separator : String
    , visibleRows : Int
    , canRetry : Bool
    }


{-| Rebuilds what is worked out from the nodes, the open branches and the search
text. The index and the search texts are reused while the nodes are the same list.
-}
refreshWith : Env id -> Data id -> Data id
refreshWith env data0 =
    let
        reusable =
            case data0.cache of
                Just cache ->
                    if cache.nodes == env.nodes then
                        Just cache

                    else
                        Nothing

                Nothing ->
                    Nothing

        index =
            case reusable of
                Just cache ->
                    cache.index

                Nothing ->
                    Index.build env.nodes

        -- a field that opened before its nodes had arrived opens on its value as
        -- soon as they have
        data =
            reveal index data0

        searching =
            not (String.isEmpty (String.trim data.query))

        sameSearch =
            case reusable of
                Just cache ->
                    cache.anyNode == env.anyNode && cache.separator == env.separator

                Nothing ->
                    False

        searchables =
            case ( searching, reusable ) of
                ( False, Just cache ) ->
                    if sameSearch then
                        cache.searchables

                    else
                        Nothing

                ( False, Nothing ) ->
                    Nothing

                ( True, Just cache ) ->
                    if sameSearch then
                        case cache.searchables of
                            Just built ->
                                Just built

                            Nothing ->
                                Just (Columns.searchables env.anyNode env.separator index)

                    else
                        Just (Columns.searchables env.anyNode env.separator index)

                ( True, Nothing ) ->
                    Just (Columns.searchables env.anyNode env.separator index)

        ( resultsFor, results ) =
            case ( searching, searchables ) of
                ( True, Just built ) ->
                    case reusable of
                        Just cache ->
                            if sameSearch && cache.resultsFor == data.query then
                                ( cache.resultsFor, cache.results )

                            else
                                ( data.query, Columns.results data.query built )

                        Nothing ->
                            ( data.query, Columns.results data.query built )

                _ ->
                    ( "", Array.empty )

        trail =
            validTrail index data.trail

        cursor =
            case data.cursor of
                Just (AtNode key) ->
                    if Index.get key index /= Nothing then
                        data.cursor

                    else
                        Nothing

                Just (AtRetry key) ->
                    if Index.get key index /= Nothing then
                        data.cursor

                    else
                        Nothing

                Nothing ->
                    Nothing

        labelled =
            rememberLabels index data
    in
    { labelled
        | trail = trail
        , cursor = cursor
        , cache =
            Just
                { nodes = env.nodes
                , anyNode = env.anyNode
                , separator = env.separator
                , index = index
                , searchables = searchables
                , resultsFor = resultsFor
                , results = results
                , columns = Columns.columns index trail
                }
    }


{-| An open field shows its value: the branches above it are open and it is
highlighted. It happens once for each time the popup opens, as soon as the nodes
have the path (they may come from the backend after the popup opened).
-}
reveal : Index id -> Data id -> Data id
reveal index data =
    if data.revealed || not data.open then
        data

    else
        let
            pathKeys =
                List.map .key data.path
        in
        if List.isEmpty pathKeys then
            { data | revealed = True }

        else if Columns.isValidPath index pathKeys then
            { data
                | trail = List.take (List.length pathKeys - 1) pathKeys
                , cursor = Maybe.map AtNode (List.head (List.reverse pathKeys))
                , revealed = True
            }

        else
            data


refreshCached : Data id -> Data id
refreshCached data =
    case data.cache of
        Just cache ->
            refreshWith { nodes = cache.nodes, anyNode = cache.anyNode, separator = cache.separator, visibleRows = 8, canRetry = False } data

        Nothing ->
            data


{-| The longest start of a trail that is a trail of the tree: each node is a
branch and the child of the one before.
-}
validTrail : Index id -> List String -> List String
validTrail index trail =
    let
        go parent keys =
            case keys of
                [] ->
                    []

                key :: rest ->
                    case Index.get key index of
                        Just entry ->
                            if entry.parent == parent && entry.kids /= NoKids then
                                key :: go (Just key) rest

                            else
                                []

                        Nothing ->
                            []
    in
    go Nothing trail


{-| A chosen step whose label is not known yet gets it from the tree, when the
tree has it.
-}
rememberLabels : Index id -> Data id -> Data id
rememberLabels index data =
    if List.all (\step -> step.label /= Nothing) data.path then
        data

    else if Columns.isValidPath index (List.map .key data.path) then
        { data
            | path =
                List.map
                    (\step ->
                        case step.label of
                            Just _ ->
                                step

                            Nothing ->
                                { step | label = Index.get step.key index |> Maybe.map .label }
                    )
                    data.path
        }

    else
        data



-- UPDATE


{-| The messages a cascader sends. Wrap it in a constructor of your own message
type (`PlaceMsg Cascader.Msg`), give that constructor to `view`, and pass the
messages you get back to `update`.
-}
type Msg id
    = Open (Env id) String
    | Close
    | Dismiss
    | QueryChanged (Env id) String
    | Backspace (Env id)
    | Key (Env id) Move
    | Pick (Env id) String
    | Choose (Env id) String
    | Clear
    | FocusSearch
    | SearchFocused (Env id)
    | ColumnList Int VirtualList.Msg
    | ResultsList VirtualList.Msg
    | NoOp


type Move
    = Down
    | Up
    | PageDown
    | PageUp
    | First
    | Last
    | Enter
    | Right
    | Left


{-| Handles a message of the cascader and returns the new state with a command
(moving focus, scrolling the columns). Map the command into your own message type
with `Cmd.map`.

    PlaceMsg inner ->
        let
            ( place, cmd ) =
                Cascader.update inner model.place
        in
        ( { model | place = place }, Cmd.map PlaceMsg cmd )

-}
update : Msg id -> State id -> ( State id, Cmd (Msg id) )
update msg (State data) =
    let
        ( next, cmd ) =
            advance msg data
    in
    ( State { next | requested = newlyWaiting data next }, cmd )


advance : Msg id -> Data id -> ( Data id, Cmd (Msg id) )
advance msg data =
    case msg of
        Open env text ->
            if data.open then
                if text == "" then
                    ( data, Cmd.none )

                else
                    advance (QueryChanged env (data.query ++ text)) data

            else
                openWith env text data

        Backspace env ->
            if data.open then
                advance (QueryChanged env (String.dropRight 1 data.query)) data

            else
                ( data, Cmd.none )

        Close ->
            closeWith data

        Dismiss ->
            ( { data | open = False, query = "", cursor = Nothing, found = Nothing }, Cmd.none )

        QueryChanged env text ->
            let
                changed =
                    refreshWith env { data | query = text, found = Nothing }

                ( results, scroll ) =
                    VirtualList.scrollTo 0 changed.results

                withFound =
                    { changed
                        | results = results
                        , found =
                            case changed.cache of
                                Just cache ->
                                    if Array.isEmpty cache.results then
                                        Nothing

                                    else
                                        Just 0

                                Nothing ->
                                    Nothing
                    }
            in
            ( withFound, Cmd.map ResultsList scroll )

        Key env move ->
            if data.open then
                moveBy env move (refreshWith env data)

            else
                ( data, Cmd.none )

        Pick env key ->
            pick env key (refreshWith env data)

        Choose env key ->
            choose env key (refreshWith env data)

        Clear ->
            ( refreshCached { data | path = [] }
            , Internal.focus
                (if data.open then
                    searchId data.id

                 else
                    data.id
                )
                NoOp
            )

        FocusSearch ->
            ( data, Internal.focus (searchId data.id) NoOp )

        SearchFocused env ->
            -- the popup has its nodes from the first moment, also when it was
            -- opened with `open`: it opens on the value and centres the columns
            if not data.open then
                ( data, Cmd.none )

            else if data.revealed then
                ( refreshWith env data, Cmd.none )

            else
                centerAll env (refreshWith env data)

        ColumnList depth inner ->
            let
                ( list, cmd ) =
                    VirtualList.update inner (listAt data depth)
            in
            ( { data | lists = Dict.insert depth list data.lists }, Cmd.map (ColumnList depth) cmd )

        ResultsList inner ->
            let
                ( list, cmd ) =
                    VirtualList.update inner data.results
            in
            ( { data | results = list }, Cmd.map ResultsList cmd )

        NoOp ->
            ( data, Cmd.none )


closeWith : Data id -> ( Data id, Cmd (Msg id) )
closeWith data =
    ( { data | open = False, query = "", cursor = Nothing, found = Nothing }
    , if data.open then
        Internal.focus data.id NoOp

      else
        Cmd.none
    )


listAt : Data id -> Int -> VirtualList.State
listAt data depth =
    Dict.get depth data.lists |> Maybe.withDefault (VirtualList.init (columnId data.id depth))


geometry : Int -> Int -> VirtualList.Geometry
geometry rowsVisible count =
    { rowHeight = View.rowHeight, height = rowsVisible * View.rowHeight, count = count, inset = 0 }


columnAt : Int -> Data id -> Maybe Column
columnAt depth data =
    data.cache |> Maybe.andThen (\cache -> List.drop depth cache.columns |> List.head)


{-| The popup opens on the value: the branches above the chosen node are open and
the node is highlighted, and every column is scrolled to show it. Without a value
the first node of the top level is highlighted.
-}
openWith : Env id -> String -> Data id -> ( Data id, Cmd (Msg id) )
openWith env text data =
    let
        revealed =
            refreshWith env
                { data
                    | open = True
                    , query = text
                    , found = Nothing
                    , cursor = Nothing
                    , trail = []
                    , revealed = text /= ""
                    , lists = Dict.empty
                    , results = VirtualList.reset data.results
                }

        ( final, scrolls ) =
            centerAll env revealed
    in
    ( final
    , Cmd.batch [ Internal.focus (searchId data.id) NoOp, scrolls, scrollColumnsToEnd data.id ]
    )


{-| Scrolls every column so that the node of the trail (or the highlighted one) is
in view.
-}
centerAll : Env id -> Data id -> ( Data id, Cmd (Msg id) )
centerAll env data =
    let
        targets =
            List.indexedMap
                (\depth col ->
                    let
                        wanted =
                            case List.drop depth data.trail |> List.head of
                                Just key ->
                                    Just key

                                Nothing ->
                                    case data.cursor of
                                        Just (AtNode key) ->
                                            Just key

                                        _ ->
                                            Nothing
                    in
                    ( depth, col, wanted |> Maybe.andThen (\key -> Columns.indexOfKey key col) )
                )
                (data.cache |> Maybe.map .columns |> Maybe.withDefault [])
    in
    List.foldl
        (\( depth, col, found ) ( current, cmds ) ->
            case found of
                Just i ->
                    let
                        ( list, cmd ) =
                            VirtualList.center (geometry env.visibleRows (Array.length col.cells)) i (listAt current depth)
                    in
                    ( { current | lists = Dict.insert depth list current.lists }, Cmd.map (ColumnList depth) cmd :: cmds )

                Nothing ->
                    ( current, cmds )
        )
        ( data, [] )
        targets
        |> (\( d, cmds ) -> ( d, Cmd.batch cmds ))


{-| Scrolls the columns sideways so that the last one is in view (on a narrow
screen they do not all fit).
-}
scrollColumnsToEnd : String -> Cmd (Msg id)
scrollColumnsToEnd domId =
    Dom.getViewportOf (treeId domId)
        |> Task.andThen (\viewport -> Dom.setViewportOf (treeId domId) (viewport.scene.width - viewport.viewport.width) 0)
        |> Task.attempt (\_ -> NoOp)


navigable : Bool -> Cell -> Bool
navigable canRetry cell =
    case cell of
        ItemCell _ _ _ ->
            True

        FailedCell _ problem ->
            canRetry && Remote.isRetryable problem

        StaleCell _ stale ->
            canRetry && Remote.isRetryable stale.problem

        PendingCell _ ->
            False


posOfCell : Cell -> Maybe Pos
posOfCell cell =
    case cell of
        ItemCell key _ _ ->
            Just (AtNode key)

        FailedCell parent _ ->
            Just (AtRetry parent)

        StaleCell parent _ ->
            Just (AtRetry parent)

        PendingCell _ ->
            Nothing


{-| The depth of the column that holds the cursor.
-}
cursorDepth : Index id -> Pos -> Maybe Int
cursorDepth index pos =
    case pos of
        AtNode key ->
            Index.get key index |> Maybe.map .depth

        AtRetry parent ->
            Index.get parent index |> Maybe.map (\entry -> entry.depth + 1)


{-| Where the cursor is: its column and its place in it. Without a cursor of its
own, the first node that can be reached in the top level.
-}
cursorAt : Bool -> Data id -> Maybe ( Column, Int )
cursorAt canRetry data =
    case data.cache of
        Nothing ->
            Nothing

        Just cache ->
            let
                found =
                    data.cursor
                        |> Maybe.andThen
                            (\pos ->
                                cursorDepth cache.index pos
                                    |> Maybe.andThen (\depth -> List.drop depth cache.columns |> List.head)
                                    |> Maybe.andThen
                                        (\col ->
                                            (case pos of
                                                AtNode key ->
                                                    Columns.indexOfKey key col

                                                AtRetry parent ->
                                                    col.cells
                                                        |> Array.toList
                                                        |> List.indexedMap Tuple.pair
                                                        |> List.filter (\( _, cell ) -> posOfCell cell == Just (AtRetry parent))
                                                        |> List.head
                                                        |> Maybe.map Tuple.first
                                            )
                                                |> Maybe.map (Tuple.pair col)
                                        )
                            )

                -- a "Try again" row that went away (the children are loading
                -- again) hands the cursor to its branch, so the user keeps their place
                onBranch =
                    case data.cursor of
                        Just (AtRetry parent) ->
                            Index.get parent cache.index
                                |> Maybe.andThen (\entry -> List.drop entry.depth cache.columns |> List.head)
                                |> Maybe.andThen (\col -> Columns.indexOfKey parent col |> Maybe.map (Tuple.pair col))

                        _ ->
                            Nothing
            in
            case ( found, onBranch ) of
                ( Just here, _ ) ->
                    Just here

                ( Nothing, Just branch ) ->
                    Just branch

                ( Nothing, Nothing ) ->
                    List.head cache.columns
                        |> Maybe.andThen
                            (\col ->
                                Columns.firstItem (navigable canRetry) col |> Maybe.map (Tuple.pair col)
                            )


{-| The key of the node at the cursor, if it is a node.
-}
cursorKey : Bool -> Data id -> Maybe String
cursorKey canRetry data =
    case cursorAt canRetry data of
        Just ( col, i ) ->
            case Array.get i col.cells of
                Just (ItemCell key _ _) ->
                    Just key

                _ ->
                    Nothing

        Nothing ->
            Nothing


{-| Moves the cursor to a cell of a column. Moving to another node than the one
that is open in that column closes the columns to the right of it.
-}
cursorTo : Env id -> Column -> Int -> Data id -> ( Data id, Cmd (Msg id) )
cursorTo env col i data =
    case Array.get i col.cells |> Maybe.andThen posOfCell of
        Just pos ->
            let
                opened =
                    List.drop col.depth data.trail |> List.head

                newTrail =
                    case pos of
                        AtNode key ->
                            if opened == Just key then
                                data.trail

                            else
                                List.take col.depth data.trail

                        AtRetry _ ->
                            data.trail

                moved =
                    refreshWith env { data | cursor = Just pos, trail = newTrail, lists = keepLists data.trail newTrail data.lists }

                ( list, scroll ) =
                    VirtualList.ensureVisible (geometry env.visibleRows (Array.length col.cells)) i (listAt moved col.depth)
            in
            ( { moved | lists = Dict.insert col.depth list moved.lists }, Cmd.map (ColumnList col.depth) scroll )

        Nothing ->
            ( data, Cmd.none )


{-| The scroll positions of the columns that still show the same nodes after the
trail changed: the columns up to the first place where the trails differ.
-}
keepLists : List String -> List String -> Dict Int VirtualList.State -> Dict Int VirtualList.State
keepLists old new lists =
    let
        common =
            commonLength old new
    in
    Dict.filter (\depth _ -> depth <= common) lists


commonLength : List String -> List String -> Int
commonLength a b =
    case ( a, b ) of
        ( x :: xs, y :: ys ) ->
            if x == y then
                1 + commonLength xs ys

            else
                0

        _ ->
            0


{-| Opens a branch: the trail now ends with it, and the column of its children
appears to the right.
-}
drill : Env id -> Int -> String -> Data id -> ( Data id, Cmd (Msg id) )
drill env depth key data =
    let
        newTrail =
            List.take depth data.trail ++ [ key ]
    in
    ( refreshWith env { data | trail = newTrail, lists = keepLists data.trail newTrail data.lists }
    , scrollColumnsToEnd data.id
    )


moveBy : Env id -> Move -> Data id -> ( Data id, Cmd (Msg id) )
moveBy env move data =
    if not (String.isEmpty (String.trim data.query)) then
        moveInResults env move data

    else
        moveInColumns env move data


moveInColumns : Env id -> Move -> Data id -> ( Data id, Cmd (Msg id) )
moveInColumns env move data =
    case ( data.cache, cursorAt env.canRetry data ) of
        ( Just cache, Just ( col, i ) ) ->
            let
                accept =
                    navigable env.canRetry

                stay =
                    ( data, Cmd.none )

                goTo target =
                    case target of
                        Just j ->
                            cursorTo env col j data

                        Nothing ->
                            stay

                page =
                    max 1 (env.visibleRows - 1)

                cell =
                    Array.get i col.cells

                entry =
                    case cell of
                        Just (ItemCell key _ _) ->
                            Index.get key cache.index

                        _ ->
                            Nothing
            in
            case move of
                Down ->
                    goTo (Columns.nextItem accept i col |> Maybe.withDefault i |> Just)

                Up ->
                    goTo (Columns.previousItem accept i col |> Maybe.withDefault i |> Just)

                PageDown ->
                    goTo (nearest accept 1 (min (Array.length col.cells - 1) (i + page)) col |> Maybe.withDefault i |> Just)

                PageUp ->
                    goTo (nearest accept -1 (max 0 (i - page)) col |> Maybe.withDefault i |> Just)

                First ->
                    goTo (Columns.firstItem accept col |> Maybe.withDefault i |> Just)

                Last ->
                    goTo (Columns.lastItem accept col |> Maybe.withDefault i |> Just)

                Right ->
                    case entry of
                        Just e ->
                            intoBranch env col e data

                        Nothing ->
                            stay

                Left ->
                    case entry of
                        Just e ->
                            if List.drop col.depth data.trail |> List.head |> (==) (Just e.key) then
                                -- the node is open: close it
                                let
                                    newTrail =
                                        List.take col.depth data.trail
                                in
                                ( refreshWith env { data | trail = newTrail, lists = keepLists data.trail newTrail data.lists }, Cmd.none )

                            else
                                toParent env col data

                        Nothing ->
                            toParent env col data

                Enter ->
                    case entry of
                        Just e ->
                            if e.disabled then
                                intoBranch env col e data

                            else if Columns.choosable env.anyNode e then
                                choose env e.key data

                            else
                                intoBranch env col e data

                        Nothing ->
                            stay

        _ ->
            ( data, Cmd.none )


{-| ArrowRight on a node: a branch that is not open is opened; one that is open
gives the cursor to the first node of its column.
-}
intoBranch : Env id -> Column -> Index.Entry id -> Data id -> ( Data id, Cmd (Msg id) )
intoBranch env col entry data =
    case entry.kids of
        NoKids ->
            ( data, Cmd.none )

        _ ->
            if List.drop col.depth data.trail |> List.head |> (==) (Just entry.key) then
                case data.cache |> Maybe.andThen (\cache -> List.drop (col.depth + 1) cache.columns |> List.head) of
                    Just next ->
                        case Columns.firstItem (navigable env.canRetry) next of
                            Just j ->
                                cursorTo env next j data

                            Nothing ->
                                ( data, Cmd.none )

                    Nothing ->
                        ( data, Cmd.none )

            else
                let
                    ( opened, cmd ) =
                        drill env col.depth entry.key data
                in
                ( { opened | cursor = Just (AtNode entry.key) }, cmd )


toParent : Env id -> Column -> Data id -> ( Data id, Cmd (Msg id) )
toParent env col data =
    case List.drop (col.depth - 1) data.trail |> List.head of
        Just parentKey ->
            if col.depth > 0 then
                case data.cache |> Maybe.andThen (\cache -> List.drop (col.depth - 1) cache.columns |> List.head) of
                    Just parentColumn ->
                        case Columns.indexOfKey parentKey parentColumn of
                            Just j ->
                                -- the cursor goes back; the column it leaves stays open
                                let
                                    moved =
                                        { data | cursor = Just (AtNode parentKey) }

                                    ( list, scroll ) =
                                        VirtualList.ensureVisible (geometry env.visibleRows (Array.length parentColumn.cells)) j (listAt moved parentColumn.depth)
                                in
                                ( { moved | lists = Dict.insert parentColumn.depth list moved.lists }, Cmd.map (ColumnList parentColumn.depth) scroll )

                            Nothing ->
                                ( data, Cmd.none )

                    Nothing ->
                        ( data, Cmd.none )

            else
                ( data, Cmd.none )

        Nothing ->
            ( data, Cmd.none )


nearest : (Cell -> Bool) -> Int -> Int -> Column -> Maybe Int
nearest accept direction from col =
    let
        search dir start =
            case Array.get start col.cells of
                Nothing ->
                    Nothing

                Just cell ->
                    if accept cell then
                        Just start

                    else
                        search dir (start + dir)
    in
    case search direction from of
        Just j ->
            Just j

        Nothing ->
            search (negate direction) from


moveInResults : Env id -> Move -> Data id -> ( Data id, Cmd (Msg id) )
moveInResults env move data =
    case data.cache of
        Just cache ->
            let
                count =
                    Array.length cache.results

                current =
                    Maybe.withDefault 0 data.found

                page =
                    max 1 (env.visibleRows - 1)

                goTo j =
                    let
                        target =
                            clamp 0 (count - 1) j

                        ( list, scroll ) =
                            VirtualList.ensureVisible (geometry env.visibleRows count) target data.results
                    in
                    ( { data | found = Just target, results = list }, Cmd.map ResultsList scroll )
            in
            if count == 0 then
                ( data, Cmd.none )

            else
                case move of
                    Down ->
                        goTo (current + 1)

                    Up ->
                        goTo (current - 1)

                    PageDown ->
                        goTo (current + page)

                    PageUp ->
                        goTo (current - page)

                    First ->
                        goTo 0

                    Last ->
                        goTo (count - 1)

                    Enter ->
                        case Array.get current cache.results of
                            Just result ->
                                choose env result.key data

                            Nothing ->
                                ( data, Cmd.none )

                    _ ->
                        ( data, Cmd.none )

        Nothing ->
            ( data, Cmd.none )


{-| A click on a row: a node that can be chosen is chosen, a branch is opened.
-}
pick : Env id -> String -> Data id -> ( Data id, Cmd (Msg id) )
pick env key data =
    case data.cache |> Maybe.andThen (\cache -> Index.get key cache.index) of
        Just entry ->
            case entry.kids of
                NoKids ->
                    if entry.disabled then
                        ( data, Cmd.none )

                    else
                        choose env key data

                _ ->
                    let
                        ( opened, cmd ) =
                            drill env entry.depth key data
                    in
                    ( { opened | cursor = Just (AtNode key) }, cmd )

        Nothing ->
            ( data, Cmd.none )


{-| Chooses the node: the path to it becomes the value and the popup closes.
-}
choose : Env id -> String -> Data id -> ( Data id, Cmd (Msg id) )
choose env key data =
    case data.cache of
        Just cache ->
            case Index.get key cache.index of
                Just entry ->
                    if entry.disabled || not (Columns.choosable env.anyNode entry) then
                        ( data, Cmd.none )

                    else
                        ( refreshCached
                            { data
                                | path =
                                    Index.pathTo key cache.index
                                        |> List.filterMap (\k -> Index.get k cache.index)
                                        |> List.map (\e -> { id = Picking.id e.node, key = e.key, label = Just e.label })
                                , open = False
                                , query = ""
                                , cursor = Nothing
                                , found = Nothing
                            }
                        , Internal.focus data.id NoOp
                        )

                Nothing ->
                    ( data, Cmd.none )

        Nothing ->
            ( data, Cmd.none )



-- ATTRIBUTES


{-| A setting of a cascader. Make them with the functions below and pass a list to
`view`; later attributes win over earlier ones.
-}
type Attribute id msg
    = Attribute (Config id msg -> Config id msg)


type alias Config id msg =
    { field : Field.Config
    , nodes : Remote (List (Node id))
    , freshness : Freshness
    , settings : Settings
    , anyNode : Bool
    , separator : String
    , placeholder : Maybe String
    , searchPlaceholder : Maybe String
    , clearable : Bool
    , valueText : Maybe (id -> String)
    , disabled : Bool
    , readOnly : Bool
    , size : Size
    , visibleRows : Int
    , locale : Locale
    , onRetry : Maybe msg
    , onRetryChildren : Maybe (id -> msg)
    }


configure : List (Attribute id msg) -> Config id msg
configure attributes =
    List.foldl (\(Attribute change) config -> change config)
        { field = Field.empty
        , nodes = Loaded []
        , freshness = Freshness.Fresh
        , settings = Settings.default
        , anyNode = False
        , separator = " / "
        , placeholder = Nothing
        , searchPlaceholder = Nothing
        , clearable = False
        , valueText = Nothing
        , disabled = False
        , readOnly = False
        , size = Medium
        , visibleRows = 8
        , locale = Locale.default
        , onRetry = Nothing
        , onRetryChildren = Nothing
        }
        attributes


updateField : (Field.Config -> Field.Config) -> Attribute id msg
updateField change =
    Attribute (\config -> { config | field = change config.field })


{-| The top level of the hierarchy, built with `Picking.leaf`, `Picking.branch` and
`Picking.lazy`. The default is no nodes. Use `nodes` or `remote`, not both: the
later one wins.

    Cascader.nodes [ Picking.branch placeIds europe "Europe" [ Picking.leaf placeIds oslo "Oslo" ] ]

-}
nodes : List (Node id) -> Attribute id msg
nodes list =
    Attribute (\config -> { config | nodes = Loaded list, freshness = Freshness.Fresh })


{-| The top level of the hierarchy from the backend, as a `Remote` (see
[Klar.Remote](Klar-Remote)). The popup shows loading rows while the data is
`Loading` or `NotAsked`, a compact error with a retry button on `Failed` (see
`onRetry`), the empty state on `Loaded []`, and the columns on `Loaded`.

    Cascader.remote model.places

-}
remote : Remote (List (Node id)) -> Attribute id msg
remote data =
    let
        ( current, freshness ) =
            Freshness.settle data
    in
    Attribute (\config -> { config | nodes = current, freshness = freshness })


{-| The message to send when the user presses the "Try again" button of the error
shown when the top level (`remote`) failed to load. The button appears only for
problems that are worth retrying (network trouble, timeouts, server errors); while
it is shown, Enter in the search box sends the message as well.
-}
onRetry : msg -> Attribute id msg
onRetry msg =
    Attribute (\config -> { config | onRetry = Just msg })


{-| The message to send, given the node id, when the user presses "Try again" on a
branch whose children failed to load (Enter does the same while that row is
highlighted). The button is only shown for problems that are worth retrying. Set
the children of that node to `Loading` again and fetch them.

    Cascader.onRetryChildren ReloadAreas

-}
onRetryChildren : (id -> msg) -> Attribute id msg
onRetryChildren toMsg =
    Attribute (\config -> { config | onRetryChildren = Just toMsg })


{-| Lets the user choose a node that has children as well as a node without. The
default is that only a node without children can be chosen, which is what a path of
levels usually means (a city, not a country). With `anyNode`, ArrowRight and a
click open a branch and Enter, a double click or the button under the columns
choose it; the value is then a shorter path.
-}
anyNode : Attribute id msg
anyNode =
    Attribute (\config -> { config | anyNode = True })


{-| The text between the labels of a path, in the field and in the list of search
results. The default is `" / "`.

    Cascader.separator " > "

-}
separator : String -> Attribute id msg
separator text =
    Attribute (\config -> { config | separator = text })


{-| The label above the field. It names the cascader for screen readers.
-}
label : String -> Attribute id msg
label text =
    updateField (Field.setLabel text)


{-| Keeps the label for screen readers but does not draw it. It needs a `label`.
-}
labelHidden : Attribute id msg
labelHidden =
    updateField Field.setLabelHidden


{-| A short help text under the field. Screen readers read it with the field.
-}
hint : String -> Attribute id msg
hint text =
    updateField (Field.setHint text)


{-| Shows an error message under the field and marks the field invalid
(`aria-invalid`). The message is announced to screen readers when it appears.
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


{-| Marks the field as required: an asterisk after the label and `aria-required`.
It does not validate anything; show a problem with `error`.
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


{-| The text shown while nothing is chosen. Default "Select ..." (in the language
of `locale`).
-}
placeholder : String -> Attribute id msg
placeholder text =
    Attribute (\config -> { config | placeholder = Just text })


{-| The placeholder of the search box in the open popup. Default "Search ...".
-}
searchPlaceholder : String -> Attribute id msg
searchPlaceholder text =
    Attribute (\config -> { config | searchPlaceholder = Just text })


{-| Shows a small x in the field that removes the chosen path. Backspace and
Delete do the same on the focused field. Nothing is shown while no path is chosen.
-}
clearable : Attribute id msg
clearable =
    Attribute (\config -> { config | clearable = True })


{-| How to write an id when the field cannot find the labels of the chosen path:
the path is not a path of the nodes you give and the field has not seen the nodes
itself. The ids are written with this function and joined by the `separator`.
Without it the field says "Unknown value".

    Cascader.valueText PlaceId.toString

-}
valueText : (id -> String) -> Attribute id msg
valueText toText =
    Attribute (\config -> { config | valueText = Just toText })


{-| While `True` the field is dimmed, cannot be focused or opened, and has no
clear button. The value is kept. The default is `False`.
-}
disabled : Bool -> Attribute id msg
disabled value_ =
    Attribute (\config -> { config | disabled = value_ })


{-| While `True` the field shows its value but does not let the user change it:
the popup does not open, and there is no chevron or clear button. Unlike
`disabled`, a read-only field can be focused. The two are independent; with both
set the field is disabled. The default is `False`.
-}
readOnly : Bool -> Attribute id msg
readOnly value_ =
    Attribute (\config -> { config | readOnly = value_ })


{-| The height of the field: `Small`, `Medium` or `Large` from
[Klar.Theme](Klar-Theme). The default is `Medium`.
-}
size : Size -> Attribute id msg
size value_ =
    Attribute (\config -> { config | size = value_ })


{-| How many rows a column shows before it scrolls. The default is 8; numbers
below 3 or above 20 are brought into that range.
-}
visibleRows : Int -> Attribute id msg
visibleRows n =
    Attribute (\config -> { config | visibleRows = clamp 3 20 n })


{-| The settings of the application (`Klar.Settings`): the time zone of the time in
"Old data from 14:05", for the top level (`remote`) and for lazy nodes. Without
it the time is written in UTC and ends in "UTC".

    Cascader.settings model.settings

-}
settings : Settings -> Attribute id msg
settings given =
    Attribute (\config -> { config | settings = given })


{-| The language of the built-in text: the placeholders, the search box, the
counts, the loading and error states and the labels for screen readers. The
default is `Locale.default`, which is English. See [Klar.Locale](Klar-Locale).

    Cascader.locale Locale.nb

-}
locale : Locale -> Attribute id msg
locale value_ =
    Attribute (\config -> { config | locale = value_ })



-- VIEW


{-| The cascader. It takes the constructor that wraps the component's `Msg` in
your own message type, a list of attributes, and the state.

    Cascader.view PlaceMsg
        [ Cascader.label "Place"
        , Cascader.nodes places
        , Cascader.required
        ]
        model.place

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

        env =
            { nodes = Remote.withDefault [] config.nodes
            , anyNode = config.anyNode
            , separator = config.separator
            , visibleRows = config.visibleRows
            , canRetry = View.isJust config.onRetryChildren
            }

        interactive =
            not config.disabled && not config.readOnly

        current =
            if data.open && interactive then
                refreshFor env data

            else
                data
    in
    Field.viewStable field
        (Html.div
            [ Internal.cls
                [ "klar-anchor"
                , "klar-anchor--block"
                , "klar-select"
                , "klar-cascader"
                , if data.open && interactive then
                    "klar-select--open"

                  else
                    ""
                ]
            ]
            [ viewControl toMsg config field t env data
            , if data.open && interactive then
                viewPopup toMsg config t env current

              else
                Html.text ""
            ]
        )


refreshFor : Env id -> Data id -> Data id
refreshFor env data =
    case data.cache of
        Just cache ->
            if cache.nodes == env.nodes && cache.anyNode == env.anyNode && cache.separator == env.separator && cache.resultsFor == resultsKey data then
                data

            else
                refreshWith env data

        Nothing ->
            refreshWith env data


resultsKey : Data id -> String
resultsKey data =
    if String.isEmpty (String.trim data.query) then
        ""

    else
        data.query


{-| What the closed field shows for the chosen path.
-}
type Shown
    = Path (List String)
    | NotLoadedYet
    | LoadFailed
    | Unknown


shownPath : Config id msg -> Data id -> Maybe Shown
shownPath config data =
    case data.path of
        [] ->
            Nothing

        steps ->
            let
                remembered =
                    List.filterMap .label steps
            in
            -- the labels that the nodes have now win over the ones remembered
            -- when the path was chosen; only the nodes along the path are walked
            case Index.followPath (List.map .key steps) (Remote.withDefault [] config.nodes) of
                Just labels ->
                    Just (Path labels)

                Nothing ->
                    if List.length remembered == List.length steps then
                        Just (Path remembered)

                    else
                        case config.valueText of
                            Just toText ->
                                Just (Path (List.map (\s -> Maybe.withDefault (toText s.id) s.label) steps))

                            Nothing ->
                                case config.nodes of
                                    Loaded _ ->
                                        Just Unknown

                                    Failed _ ->
                                        Just LoadFailed

                                    _ ->
                                        Just NotLoadedYet


{-| A long path with its middle left out: the top, "…", and the last label.
-}
shorten : String -> List String -> String
shorten separator_ labels =
    let
        full =
            String.join separator_ labels
    in
    case labels of
        first :: rest ->
            if String.length full <= 44 || List.length rest < 2 then
                full

            else
                String.join separator_ [ first, "…", List.reverse rest |> List.head |> Maybe.withDefault "" ]

        [] ->
            full


viewControl : (Msg id -> msg) -> Config id msg -> Field.Config -> Texts -> Env id -> Data id -> Html msg
viewControl toMsg config field t env data =
    let
        interactive =
            not config.disabled && not config.readOnly

        shown =
            shownPath config data

        showClear =
            config.clearable && interactive && data.path /= []

        openMsg =
            toMsg (Open env "")

        typed =
            Just (\char -> toMsg (Open env char))

        triggerKeys =
            if interactive && not data.open then
                View.onTriggerKeys
                    ([ ( "Enter", openMsg ), ( " ", openMsg ), ( "ArrowDown", openMsg ), ( "ArrowUp", openMsg ) ]
                        ++ (if showClear then
                                [ ( "Backspace", toMsg Clear ), ( "Delete", toMsg Clear ) ]

                            else
                                []
                           )
                    )
                    typed

            else if interactive then
                View.onWindowKeys
                    { typed = \char -> toMsg (Open env char)
                    , backspace = toMsg (Backspace env)
                    , move = \move -> toMsg (Key env (fromViewMove move))
                    , close = toMsg Close
                    , leave = toMsg Dismiss
                    }

            else
                Internal.noAttr
    in
    Html.div
        [ Internal.cls
            [ "klar-input"
            , "klar-input--" ++ Internal.sizeSuffix config.size
            , "klar-select__control"
            , if field.error /= Nothing then
                "klar-input--invalid"

              else
                ""
            , if config.disabled then
                "klar-input--disabled"

              else
                ""
            , if config.readOnly then
                "klar-input--readonly"

              else
                ""
            ]
        , if interactive then
            Events.onClick openMsg

          else
            Internal.noAttr
        ]
        [ Html.button
            (Field.controlAttributes field
                ++ [ Internal.cls [ "klar-select__trigger" ]
                   , Attr.type_ "button"
                   , Attr.attribute "role" "combobox"
                   , Attr.attribute "aria-haspopup" "tree"
                   , Attr.attribute "aria-expanded"
                        (if data.open && interactive then
                            "true"

                         else
                            "false"
                        )
                   , Internal.attrIf (data.open && interactive) (Attr.attribute "aria-controls" (popupId data.id))
                   , Attr.disabled config.disabled
                   , Internal.attrIf config.readOnly (Attr.attribute "aria-readonly" "true")
                   , case shown of
                        Just (Path labels) ->
                            Attr.title (String.join config.separator labels)

                        _ ->
                            Internal.noAttr
                   , triggerKeys
                   ]
            )
            (case shown of
                Just (Path labels) ->
                    [ Html.span [ Internal.cls [ "klar-select__value" ], Attr.attribute "aria-hidden" "true" ]
                        [ Html.text (shorten config.separator labels) ]
                    , Html.span [ Internal.cls [ "klar-sr-only" ] ] [ Html.text (String.join config.separator labels) ]
                    ]

                Just NotLoadedYet ->
                    [ Html.span [ Internal.cls [ "klar-select__value", "klar-select__value--unknown" ] ] [ Html.text t.loading ] ]

                Just LoadFailed ->
                    [ Html.span [ Internal.cls [ "klar-select__value", "klar-select__value--unknown" ] ] [ Html.text t.unavailable ] ]

                Just Unknown ->
                    [ Html.span [ Internal.cls [ "klar-select__value", "klar-select__value--unknown" ] ] [ Html.text t.unknownValue ] ]

                Nothing ->
                    [ Html.span [ Internal.cls [ "klar-select__placeholder" ] ]
                        [ Html.text (Maybe.withDefault t.placeholder config.placeholder) ]
                    ]
            )
        , if showClear then
            View.viewClearButton t.clearSelection (toMsg Clear)

          else
            Html.text ""
        , if config.readOnly then
            Html.text ""

          else
            View.viewChevron
        ]


fromViewMove : View.Move -> Move
fromViewMove move =
    case move of
        View.MoveDown ->
            Down

        View.MoveUp ->
            Up

        View.MovePageDown ->
            PageDown

        View.MovePageUp ->
            PageUp

        View.MoveFirst ->
            First

        View.MoveLast ->
            Last

        View.MoveChoose ->
            Enter



-- POPUP


viewPopup : (Msg id -> msg) -> Config id msg -> Texts -> Env id -> Data id -> Html msg
viewPopup toMsg config t env data =
    let
        topLevel =
            config.nodes

        loaded =
            case topLevel of
                Loaded _ ->
                    True

                _ ->
                    False

        retry =
            case topLevel of
                Failed problem ->
                    View.retryFor problem config.onRetry

                _ ->
                    Nothing

        searching =
            not (String.isEmpty (String.trim data.query))

        -- old data at the top level: its Try again is the next stop after the
        -- search box, so Tab goes there instead of closing the popup
        staleRetry =
            if loaded then
                View.staleRetry config.freshness config.onRetry

            else
                Nothing

        cache =
            if loaded then
                data.cache

            else
                Nothing

        resultCount =
            cache |> Maybe.map (.results >> Array.length) |> Maybe.withDefault 0

        cursor =
            if searching then
                Nothing

            else
                cursorAt env.canRetry data

        retryRowMsg =
            case ( cursor, cache ) of
                ( Just ( col, i ), Just c ) ->
                    case Array.get i col.cells of
                        Just (FailedCell parent problem) ->
                            retryChildren config c parent problem

                        Just (StaleCell parent stale) ->
                            retryChildren config c parent stale.problem

                        _ ->
                            Nothing

                _ ->
                    Nothing

        cursorId =
            case cursor of
                Just ( col, i ) ->
                    let
                        ( from, to ) =
                            View.renderedRange { visibleRows = config.visibleRows, count = Array.length col.cells } (listAt data col.depth)
                    in
                    if i >= from && i < to then
                        Just (itemDomId data.id col.depth i)

                    else
                        Nothing

                Nothing ->
                    Nothing

        foundId =
            case data.found of
                Just i ->
                    let
                        ( from, to ) =
                            View.renderedRange { visibleRows = config.visibleRows, count = resultCount } data.results
                    in
                    if i >= from && i < to && i < resultCount then
                        Just (resultDomId data.id i)

                    else
                        Nothing

                Nothing ->
                    Nothing

        hasRows =
            loaded
                && (if searching then
                        resultCount > 0

                    else
                        cursor /= Nothing
                   )

        keys =
            View.onSearchKeys
                { handled =
                    (if loaded && hasRows then
                        [ View.plain "ArrowDown" (toMsg (Key env Down))
                        , View.plain "ArrowUp" (toMsg (Key env Up))
                        , View.plain "PageDown" (toMsg (Key env PageDown))
                        , View.plain "PageUp" (toMsg (Key env PageUp))
                        , View.whenEmpty "Home" (toMsg (Key env First))
                        , View.plain "Mod+Home" (toMsg (Key env First))
                        , View.whenEmpty "End" (toMsg (Key env Last))
                        , View.plain "Mod+End" (toMsg (Key env Last))
                        , View.plain "Enter"
                            (case retryRowMsg of
                                Just retryMsg ->
                                    retryMsg

                                Nothing ->
                                    toMsg (Key env Enter)
                            )
                        ]
                            ++ (if searching then
                                    []

                                else
                                    [ View.atEnd "ArrowRight" (toMsg (Key env Right))
                                    , View.atStart "ArrowLeft" (toMsg (Key env Left))
                                    ]
                               )

                     else
                        [ View.plain "Enter" (Maybe.withDefault (toMsg NoOp) retry) ]
                    )
                        ++ [ View.plain "Escape" (toMsg Close) ]
                , passive =
                    if View.isJust retry || View.isJust staleRetry || actionKey data config env /= Nothing then
                        [ View.plain "Shift+Tab" (toMsg Dismiss) ]

                    else
                        [ View.plain "Tab" (toMsg Dismiss), View.plain "Shift+Tab" (toMsg Dismiss) ]
                }

        staleNotice =
            View.viewNotice
                { locale = config.locale
                , settings = config.settings
                , onRetry = config.onRetry
                , refocus = toMsg FocusSearch
                , leave =
                    if not searching && actionKey data config env /= Nothing then
                        -- the action in the footer is the next stop
                        Nothing

                    else
                        Just (toMsg Dismiss)
                , noop = toMsg NoOp
                }
                config.freshness

        body =
            case topLevel of
                Loaded _ ->
                    case cache of
                        Just c ->
                            -- the same elements while the data is fresh, refreshed
                            -- or old, around the columns, the results and the empty
                            -- states alike, so that the marker for old data stays
                            -- when nothing matches
                            Html.div
                                [ Internal.cls [ Freshness.className config.freshness ]
                                , Freshness.busyAttr config.freshness
                                ]
                                (staleNotice
                                    :: (if Index.size c.index == 0 then
                                            [ View.viewEmpty Icon.inbox t.noOptions Nothing ]

                                        else if searching then
                                            if resultCount == 0 then
                                                [ View.viewEmpty Icon.search t.noMatches (Just (t.noMatchesFor (String.trim data.query))) ]

                                            else
                                                [ viewResults toMsg config t env data c foundId
                                                , View.viewFooter (t.results resultCount) []
                                                ]

                                        else
                                            [ viewColumns toMsg config t env data c cursor cursorId
                                            , viewColumnsFooter toMsg config t env data c
                                            ]
                                       )
                                )

                        Nothing ->
                            viewLoading t

                Failed problem ->
                    View.viewFailure
                        { locale = config.locale
                        , onRetry = retry
                        , refocus = toMsg FocusSearch
                        , leave = toMsg Dismiss
                        , noop = toMsg NoOp
                        }
                        problem

                _ ->
                    viewLoading t
    in
    View.viewLayer (toMsg Close)
        (Html.div
            [ Internal.cls [ "klar-popup", "klar-cascader__popup" ]
            , Attr.id (popupId data.id)
            , Internal.onClickStop (toMsg NoOp)
            , View.holdSearchFocus (toMsg NoOp)
            ]
            [ View.viewSearch
                { id = searchId data.id
                , controls =
                    if hasRows then
                        Just
                            (if searching then
                                resultsId data.id

                             else
                                treeId data.id
                            )

                    else
                        Nothing
                , popup =
                    if searching then
                        "listbox"

                    else
                        "tree"
                , query = data.query
                , placeholder = Maybe.withDefault t.searchPlaceholder config.searchPlaceholder
                , label = t.searchLabel
                , activeDescendant =
                    if hasRows then
                        if searching then
                            foundId

                        else
                            cursorId

                    else
                        Nothing
                , onInput = QueryChanged env >> toMsg
                , onFocus = toMsg (SearchFocused env)
                , keys = keys
                , loading = Remote.isLoading topLevel
                , loadingLabel = t.loading
                , clearLabel = t.clearQuery
                , noop = toMsg NoOp
                }
            , body
            ]
        )


viewLoading : Texts -> Html msg
viewLoading t =
    Html.div [ Attr.attribute "aria-busy" "true" ]
        [ View.viewSkeleton 5
        , View.viewFooter t.loading []
        ]


{-| The node under the columns that a button can choose, when any node may be
chosen: the last open branch.
-}
actionKey : Data id -> Config id msg -> Env id -> Maybe String
actionKey data _ env =
    if env.anyNode then
        case ( List.reverse data.trail |> List.head, data.cache ) of
            ( Just key, Just cache ) ->
                case Index.get key cache.index of
                    Just entry ->
                        if Columns.choosable True entry then
                            Just key

                        else
                            Nothing

                    Nothing ->
                        Nothing

            _ ->
                Nothing

    else
        Nothing


viewColumnsFooter : (Msg id -> msg) -> Config id msg -> Texts -> Env id -> Data id -> Cache id -> Html msg
viewColumnsFooter toMsg config t env data cache =
    let
        pathText =
            case List.reverse data.trail |> List.head of
                Just key ->
                    String.join config.separator (Index.labelPath key cache.index)

                Nothing ->
                    ""
    in
    Html.div [ Internal.cls [ "klar-select__footer" ] ]
        [ Html.span [ Internal.cls [ "klar-select__status", "klar-tabular", "klar-truncate" ] ] [ Html.text pathText ]
        , case actionKey data config env of
            Just key ->
                Html.div [ Internal.cls [ "klar-select__actions" ] ]
                    [ Button.view
                        [ Button.small
                        , Button.ghost
                        , Button.onClick (toMsg (Choose env key))
                        , Button.htmlAttrs
                            [ Internal.onMouseDownPrevent (toMsg NoOp)
                            , View.onKeydown { handled = [], passive = [ ( "Tab", toMsg Dismiss ) ] }
                            ]
                        ]
                        (t.choose (Index.get key cache.index |> Maybe.map .label |> Maybe.withDefault ""))
                    ]

            Nothing ->
                Html.text ""
        ]


viewColumns : (Msg id -> msg) -> Config id msg -> Texts -> Env id -> Data id -> Cache id -> Maybe ( Column, Int ) -> Maybe String -> Html msg
viewColumns toMsg config t env data cache cursor _ =
    let
        cursorHere =
            Maybe.map (\( col, i ) -> ( col.depth, i )) cursor

        valueKeys =
            Set.fromList (List.map .key data.path)

        chosenKey =
            List.reverse data.path |> List.head |> Maybe.map .key

        rc =
            { toMsg = toMsg
            , config = config
            , t = t
            , env = env
            , data = data
            , cache = cache
            , cursor = cursorHere
            , valueKeys = valueKeys
            , chosenKey = chosenKey
            }

        columnView col =
            ( columnKey col
            , Html.div
                [ Internal.cls [ "klar-cascader__column" ]
                , Attr.attribute "role" "presentation"
                ]
                [ VirtualList.view (ColumnList col.depth >> toMsg)
                    [ VirtualList.rowHeight View.rowHeight
                    , VirtualList.overscan View.overscan
                    , VirtualList.height (config.visibleRows * View.rowHeight)
                    , VirtualList.htmlAttrs
                        [ Internal.cls [ "klar-select__list" ]

                        -- the nodes of a column after the first are the group of
                        -- the open branch before it, which owns them (aria-owns), so
                        -- that a screen reader hears the hierarchy and not the columns
                        , if col.depth == 0 then
                            Attr.attribute "role" "presentation"

                          else
                            Attr.attribute "role" "group"
                        , Internal.attrIf (col.depth > 0) (Attr.id (groupId data.id col.depth))
                        , Internal.onMouseDownPrevent (toMsg NoOp)
                        ]
                    ]
                    { items = col.cells, viewRow = viewCell rc col }
                    (listAt data col.depth)
                ]
            )
    in
    Keyed.node "div"
        [ Internal.cls [ "klar-cascader__columns" ]
        , Attr.id (treeId data.id)
        , Attr.attribute "role" "tree"
        , Internal.attrMaybe (Attr.attribute "aria-label") config.field.label
        ]
        (List.map columnView cache.columns)


columnKey : Column -> String
columnKey col =
    String.fromInt col.depth ++ ":" ++ Maybe.withDefault "" col.parent


type alias RowConfig id msg =
    { toMsg : Msg id -> msg
    , config : Config id msg
    , t : Texts
    , env : Env id
    , data : Data id
    , cache : Cache id
    , cursor : Maybe ( Int, Int )
    , valueKeys : Set String
    , chosenKey : Maybe String
    }


viewCell : RowConfig id msg -> Column -> Int -> Cell -> Html msg
viewCell rc col index cell =
    case cell of
        ItemCell key posInSet setSize ->
            case Index.get key rc.cache.index of
                Just entry ->
                    viewItem rc col index entry posInSet setSize

                Nothing ->
                    Html.text ""

        PendingCell _ ->
            Html.div
                [ Internal.cls [ "klar-select__option", "klar-cascader__item", "klar-cascader__item--status" ]
                , Attr.id (itemDomId rc.data.id col.depth index)
                , Attr.attribute "role" "treeitem"
                , Attr.attribute "aria-level" (String.fromInt (col.depth + 1))
                , Attr.attribute "aria-disabled" "true"
                , Attr.attribute "aria-busy" "true"
                ]
                [ Spinner.view []
                , Html.span [ Internal.cls [ "klar-tree-select__status-text" ] ] [ Html.text rc.t.loadingChildren ]
                ]

        StaleCell parent stale ->
            viewStaleCell rc col index parent stale

        FailedCell parent problem ->
            let
                retryMsg =
                    retryChildren rc.config rc.cache parent problem

                isCursor =
                    rc.cursor == Just ( col.depth, index )
            in
            Html.div
                [ Internal.cls
                    [ "klar-select__option"
                    , "klar-cascader__item"
                    , "klar-cascader__item--status"
                    , if isCursor then
                        "klar-select__option--highlighted"

                      else
                        ""
                    ]
                , Attr.id (itemDomId rc.data.id col.depth index)
                , Attr.attribute "role" "treeitem"
                , Attr.attribute "aria-level" (String.fromInt (col.depth + 1))
                , Internal.attrIf (retryMsg == Nothing) (Attr.attribute "aria-disabled" "true")
                , Internal.onMouseDownPrevent (rc.toMsg NoOp)
                ]
                [ Html.span [ Internal.cls [ "klar-tree-select__status-text", "klar-tree-select__status-text--error" ] ] [ Html.text rc.t.couldNotLoadChildren ]
                , case retryMsg of
                    Just msg ->
                        Button.view
                            [ Button.small
                            , Button.ghost
                            , Button.onClick msg
                            , Button.htmlAttrs [ Attr.tabindex -1, Internal.onMouseDownPrevent (rc.toMsg NoOp) ]
                            ]
                            rc.t.tryAgain

                    Nothing ->
                        Html.text ""
                ]


{-| The message that loads the children of a branch again, when the application
gave `onRetryChildren` and the problem is worth retrying.
-}
retryChildren : Config id msg -> Cache id -> String -> Remote.Problem -> Maybe msg
retryChildren config cache parent problem =
    case ( config.onRetryChildren, Index.get parent cache.index ) of
        ( Just toRetry, Just entry ) ->
            if Remote.isRetryable problem then
                Just (toRetry (Picking.id entry.node))

            else
                Nothing

        _ ->
            Nothing


{-| "Old data from 14:05" at the top of a column whose nodes stay on screen after
a refresh of them failed, with "Try again" (Enter while the cursor is on it).
-}
viewStaleCell : RowConfig id msg -> Column -> Int -> String -> Index.Stale -> Html msg
viewStaleCell rc col index parent stale =
    let
        retryMsg =
            retryChildren rc.config rc.cache parent stale.problem

        isCursor =
            rc.cursor == Just ( col.depth, index )
    in
    Html.div
        [ Internal.cls
            [ "klar-select__option"
            , "klar-cascader__item"
            , "klar-cascader__item--status"
            , "klar-cascader__item--stale"
            , if isCursor then
                "klar-select__option--highlighted"

              else
                ""
            ]
        , Attr.id (itemDomId rc.data.id col.depth index)
        , Attr.attribute "role" "treeitem"
        , Attr.attribute "aria-level" (String.fromInt (col.depth + 1))
        , Attr.title (String.trim (Remote.title rc.config.locale stale.problem))
        , Internal.attrIf (not (View.isJust retryMsg)) (Attr.attribute "aria-disabled" "true")
        , Internal.attrIf stale.refreshing (Attr.attribute "aria-busy" "true")
        , Internal.onMouseDownPrevent (rc.toMsg NoOp)
        ]
        [ Html.span [ Internal.cls [ "klar-tree-select__stale-icon" ], Attr.attribute "aria-hidden" "true" ] [ Icon.view Icon.clock ]
        , Html.span [ Internal.cls [ "klar-tree-select__status-text" ] ]
            [ Html.text (Freshness.text rc.config.locale rc.config.settings stale.at) ]
        , case retryMsg of
            Just msg ->
                Button.view
                    [ Button.small
                    , Button.ghost
                    , Button.loading stale.refreshing
                    , Button.onClick msg
                    , Button.htmlAttrs [ Attr.tabindex -1, Internal.onMouseDownPrevent (rc.toMsg NoOp) ]
                    ]
                    rc.t.tryAgain

            Nothing ->
                Html.text ""
        ]


viewItem : RowConfig id msg -> Column -> Int -> Index.Entry id -> Int -> Int -> Html msg
viewItem rc col index entry posInSet setSize =
    let
        node =
            entry.node

        isCursor =
            rc.cursor == Just ( col.depth, index )

        hasKids =
            entry.kids /= NoKids

        isOpened =
            List.drop col.depth rc.data.trail |> List.head |> (==) (Just entry.key)

        onValue =
            Set.member entry.key rc.valueKeys

        tooltip =
            case Picking.description node of
                Just description ->
                    entry.label ++ " – " ++ description

                Nothing ->
                    entry.label
    in
    Html.div
        ([ Internal.cls
            [ "klar-select__option"
            , "klar-cascader__item"
            , if isCursor then
                "klar-select__option--highlighted"

              else
                ""
            , if isOpened then
                "klar-cascader__item--opened"

              else
                ""
            , if onValue then
                "klar-cascader__item--chosen"

              else
                ""
            , if entry.disabled then
                "klar-select__option--disabled"

              else
                ""
            ]
         , Attr.id (itemDomId rc.data.id col.depth index)
         , Attr.attribute "role" "treeitem"
         , Attr.attribute "aria-level" (String.fromInt (col.depth + 1))
         , Attr.attribute "aria-setsize" (String.fromInt setSize)
         , Attr.attribute "aria-posinset" (String.fromInt posInSet)
         , Internal.attrIf hasKids
            (Attr.attribute "aria-expanded"
                (if isOpened then
                    "true"

                 else
                    "false"
                )
            )
         , Attr.attribute "aria-selected"
            (if rc.chosenKey == Just entry.key then
                "true"

             else
                "false"
            )
         , Internal.attrIf (isOpened && List.length rc.cache.columns > col.depth + 1)
            (Attr.attribute "aria-owns" (groupId rc.data.id (col.depth + 1)))
         , Internal.attrIf entry.disabled (Attr.attribute "aria-disabled" "true")

         -- children on screen that are being refreshed
         , Freshness.busyAttr entry.freshness
         , Attr.title tooltip
         , Internal.onMouseDownPrevent (rc.toMsg NoOp)
         , Internal.onClickPrevent (rc.toMsg (Pick rc.env entry.key))
         ]
            ++ (if hasKids && rc.env.anyNode && not entry.disabled then
                    [ Events.on "dblclick" (Decode.succeed (rc.toMsg (Choose rc.env entry.key))) ]

                else
                    []
               )
        )
        [ Internal.viewMaybe (\icon -> Html.span [ Internal.cls [ "klar-select__option-icon" ] ] [ Icon.view icon ]) (Picking.icon node)
        , Html.span [ Internal.cls [ "klar-select__option-label" ] ] [ Html.text entry.label ]
        , Internal.viewMaybe
            (\description -> Html.span [ Internal.cls [ "klar-select__option-description" ] ] [ Html.text description ])
            (Picking.description node)
        , if Freshness.busy entry.freshness then
            -- decoration: aria-busy on the item says it, and a live region in
            -- every busy item of a virtual list would come and go with the scroll
            Html.span [ Internal.cls [ "klar-cascader__next" ] ] [ Spinner.view [] ]

          else if hasKids then
            Html.span [ Internal.cls [ "klar-cascader__next" ], Attr.attribute "aria-hidden" "true" ] [ Icon.view Icon.chevronRight ]

          else
            Html.text ""
        ]


viewResults : (Msg id -> msg) -> Config id msg -> Texts -> Env id -> Data id -> Cache id -> Maybe String -> Html msg
viewResults toMsg config t _ data cache _ =
    let
        count =
            Array.length cache.results

        viewResult index result =
            let
                isFound =
                    data.found == Just index
            in
            Html.div
                [ Internal.cls
                    [ "klar-select__option"
                    , "klar-cascader__result"
                    , if isFound then
                        "klar-select__option--highlighted"

                      else
                        ""
                    ]
                , Attr.id (resultDomId data.id index)
                , Attr.attribute "role" "option"
                , Attr.attribute "aria-selected"
                    (if List.map .key data.path |> List.reverse |> List.head |> (==) (Just result.key) then
                        "true"

                     else
                        "false"
                    )
                , Attr.attribute "aria-posinset" (String.fromInt (index + 1))
                , Attr.attribute "aria-setsize" (String.fromInt count)
                , Attr.title result.text
                , Internal.onMouseDownPrevent (toMsg NoOp)
                , Internal.onClickPrevent (toMsg (Choose { nodes = cache.nodes, anyNode = cache.anyNode, separator = cache.separator, visibleRows = config.visibleRows, canRetry = False } result.key))
                ]
                [ Html.span [ Internal.cls [ "klar-select__option-label" ] ] (Search.highlight data.query result.text) ]
    in
    VirtualList.view (ResultsList >> toMsg)
        [ VirtualList.rowHeight View.rowHeight
        , VirtualList.overscan View.overscan
        , VirtualList.height (config.visibleRows * View.rowHeight)
        , VirtualList.htmlAttrs
            [ Internal.cls [ "klar-select__list" ]
            , Attr.attribute "role" "listbox"
            , Attr.attribute "aria-label" t.path
            , Internal.onMouseDownPrevent (toMsg NoOp)
            ]
        ]
        { items = cache.results, viewRow = viewResult }
        data.results
