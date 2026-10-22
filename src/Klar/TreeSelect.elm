module Klar.TreeSelect exposing
    ( State, init, Msg, update, view
    , Mode, Single, Multiple, single, multiple
    , value, setValue, setNode, values, setValues, setNodes, leaves, clear
    , query, isOpen, open, close, loadRequests
    , Attribute, nodes, remote, onRetry, onRetryChildren
    , label, labelHidden, hint, error, errorMaybe, required, optionalText
    , placeholder, searchPlaceholder, clearable, valueText, disabled, readOnly, size, visibleRows, maxVisibleChips, locale
    )

{-| A field that opens a popup with a tree and lets the user choose one node, or
several with check boxes. Use it for a hierarchy that is too big for a plain list
(regions and warehouses, product categories, an organisation); for a short flat
list use [Klar.Select](Klar-Select) or [Klar.MultiSelect](Klar-MultiSelect), to
drill down through levels like a file browser [Klar.Cascader](Klar-Cascader), and
to show a tree on the page itself [Klar.Tree](Klar-Tree).

    import Klar.Picking as Picking
    import Klar.TreeSelect as TreeSelect

    -- how a SiteId is written as a key, once
    siteIds : Picking.Ids SiteId
    siteIds =
        Picking.ids SiteId.toString

    -- model: one State per field; the String is a DOM id, unique on the page
    type alias Model =
        { site : TreeSelect.State TreeSelect.Single SiteId }

    init =
        { site = TreeSelect.init TreeSelect.single "site" }

    -- update
    SiteMsg inner ->
        let
            ( site, cmd ) =
                TreeSelect.update inner model.site
        in
        ( { model | site = site }, Cmd.map SiteMsg cmd )

    -- view
    TreeSelect.view SiteMsg
        [ TreeSelect.label "Warehouse"
        , TreeSelect.nodes
            [ Picking.branch siteIds oslo "Oslo" [ Picking.leaf siteIds hall3 "Hall 3" ] ]
        , TreeSelect.clearable
        ]
        model.site

    -- reading the value
    TreeSelect.value model.site --> Maybe SiteId

The mode is the one choice you make when you create the field: `single` for one
node, `multiple` for any number. It is part of the type, so `value` only works on
a single field and `values` on a multiple one. As in every Klar field, the state
holds the value, and there are no out-messages: compare the value before and after
`update` to react (`TreeSelect.value new /= TreeSelect.value old`).

**What a checked box means** (`multiple`). Checking a node chooses it and
everything below it, so checking "Europe" puts one id, `europe`, in the value, also
when Europe holds a thousand warehouses and some of them are not loaded yet. A node
with only some of its nodes checked shows a dash. The value is kept as short as it
can be: when all the children of a node are checked they are replaced by the node,
and when the user unchecks one node of a checked branch, the branch is replaced by
what is left of it. A node that is `disabled` is never chosen: checking its parent
chooses the nodes around it one by one, and the parent shows a check when all of
them are chosen. To get the warehouses and not the regions, ask for `leaves`.

That promise has one price: with a `disabled` node somewhere under "Europe", checking
"Europe" cannot say `europe` (it would include the disabled node), so the value is
one id for each part of Europe that has nothing disabled inside it, which can be
many. Without disabled nodes below it, a checked branch is always one id.

Typing in the search box filters the tree: it keeps the nodes that contain every
word, with the nodes above them, opened and with the matching text highlighted.
When the text is cleared the tree is as the user left it. Only nodes that are in
your data are searched, so the children of a lazy node that is not loaded are not.
Only the rows on screen are drawn (see [Klar.VirtualList](Klar-VirtualList)), so
a tree of many thousands of nodes stays fast.

Nodes can come from the backend: the top level as a `Remote` (`remote`), and the
children of a node with `Picking.lazy`. When the user opens a lazy node that is
`NotAsked`, `loadRequests` names it (call it after every update), so that you can
mark it `Loading` and fetch it; a failed branch shows the problem and a "Try again" button
(`onRetryChildren`) and does not block the rest of the tree. Nothing else is
loaded behind your back.

Keyboard: on the closed field Enter, Space, ArrowDown, ArrowUp or a printable
character open the popup (the character starts the search). The keyboard focus
stays in the search box while the popup is open, and the arrow keys move a
highlight (`aria-activedescendant`): ArrowDown and ArrowUp, Home and End, PageUp
and PageDown. ArrowRight opens a closed node and then moves into it, ArrowLeft
closes an open node and then moves to its parent; in a text they move the caret
instead, until it is at the end (right) or the start (left). Enter chooses the
highlighted node (in a multiple field it checks or unchecks it and the popup stays
open), and Space does the same while the search box is empty. `*` opens all nodes
on the highlighted level while the search box is empty. Escape closes the popup and
returns to the field, and Tab closes it and moves on. Typing letters searches
instead of jumping to the next node whose name starts with them: the search is the
type-ahead.

Accessibility: the field is a button with `role="combobox"` and
`aria-haspopup="tree"`. The open popup is a `tree` of `treeitem` rows with
`aria-level`, `aria-setsize`, `aria-posinset` and `aria-expanded`, and
`aria-selected` (single) or `aria-checked` (multiple, with `mixed` for the dash, and
`aria-multiselectable` on the tree). The counts under the tree are announced politely. The built-in text follows
`locale` and is English by default (see [Klar.Locale](Klar-Locale)).

Limits: a node must have a unique id in the whole tree, ids are compared through
their key (see [Klar.Picking](Klar-Picking)), and a value that is not in the tree
you give is shown as "Unknown value" unless you say how to write it (`valueText`)
or give the component its node (`setNode`, `setNodes`). On the closed field of a
multiple field Backspace removes the last chosen id, which can be a whole branch
(the Select family does the same for its chips). Right-to-left languages are not
supported: the arrow keys and the indents assume left-to-right text.


# State

@docs State, init, Msg, update, view


# Single or multiple

@docs Mode, Single, Multiple, single, multiple


# Value

@docs value, setValue, setNode, values, setValues, setNodes, leaves, clear


# Popup and lazy nodes

@docs query, isOpen, open, close, loadRequests


# Attributes

Pass attributes to `view` in a list; later ones win over earlier ones.

@docs Attribute, nodes, remote, onRetry, onRetryChildren


# Field

The label, hint and error around the field work the same in every Klar form
control.

@docs label, labelHidden, hint, error, errorMaybe, required, optionalText


# Behavior and looks

@docs placeholder, searchPlaceholder, clearable, valueText, disabled, readOnly, size, visibleRows, maxVisibleChips, locale

-}

import Array
import Dict exposing (Dict)
import Html exposing (Html)
import Html.Attributes as Attr
import Html.Events as Events
import Json.Decode as Decode
import Klar.Button as Button
import Klar.Checkbox as Checkbox
import Klar.Field as Field
import Klar.Icon as Icon
import Klar.Internal as Internal
import Klar.Internal.Freshness as Freshness
import Klar.Locale as Locale exposing (Locale)
import Klar.Picking as Picking exposing (Ids, Node)
import Klar.Picking.Cover as Cover exposing (Check(..))
import Klar.Picking.Index as Index exposing (Index, Kids(..), Row(..))
import Klar.Picking.Texts as Texts exposing (Texts)
import Klar.Picking.View as View
import Klar.Remote as Remote exposing (Remote(..))
import Klar.Search as Search
import Klar.Spinner as Spinner
import Klar.Tag as Tag
import Klar.Theme as Theme exposing (Size(..), Tone(..))
import Klar.VirtualList as VirtualList
import Set exposing (Set)



-- MODE


{-| The kind of a field that chooses one node. It only exists as the first
argument of `State`: `TreeSelect.State TreeSelect.Single SiteId`.
-}
type Single
    = Single


{-| The kind of a field that chooses any number of nodes with check boxes:
`TreeSelect.State TreeSelect.Multiple SiteId`.
-}
type Multiple
    = Multiple


{-| Whether the field chooses one node or several, given once to `init`. Make it
with `single` or `multiple`. It is a type of its own rather than a flag, so that
the functions that only make sense for one kind do not compile for the other.
-}
type Mode mode
    = Mode Bool


{-| The field chooses one node, or none. Read it with `value`.
-}
single : Mode Single
single =
    Mode False


{-| The field chooses any number of nodes, each with a check box. Read it with
`values`.
-}
multiple : Mode Multiple
multiple =
    Mode True



-- STATE


{-| Everything one field keeps track of: the chosen nodes, whether the popup is
open, the search text, which nodes are open and which row is highlighted. Make
it with `init`, keep it in your model and pass it to `view` and `update`. The
`mode` is `Single` or `Multiple`, and `id` the type of your ids.
-}
type State mode id
    = State (Data id)


type alias Data id =
    { id : String
    , multiple : Bool
    , open : Bool
    , query : String
    , highlighted : Maybe Pos
    , revealed : Bool
    , expanded : Set String
    , flips : Set String
    , chosen : Dict String (Chosen id)
    , cover : Set String
    , next : Int
    , list : VirtualList.State
    , cache : Maybe (Cache id)
    }


{-| A node the user chose: the id as the application gave it, the place in the
order of choosing, and the label when the component has seen the node.
-}
type alias Chosen id =
    { id : id
    , order : Int
    , label : Maybe String
    }


{-| A row that can be highlighted: a node, or the failure under a node.
-}
type Pos
    = AtNode String
    | AtRetry String


{-| What the component works out from the nodes, so that it happens once per
change (a key press, a keystroke) and not on every draw.
-}
type alias Cache id =
    { nodes : List (Node id)
    , index : Index id
    , filterOf : String
    , filter : Maybe Index.Filter
    , derivedFor : Set String
    , derived : Cover.Derived
    , rows : Index.Rows id
    }


{-| A closed field with nothing chosen. The first argument is `single` or
`multiple`; the `String` is the DOM id of the field and must be unique on the
page: the label points to it, and the ids of the popup are derived from it
(`site-search`, `site-tree`, `site-popup`).

    TreeSelect.init TreeSelect.single "site"

-}
init : Mode mode -> String -> State mode id
init (Mode isMultiple) domId =
    State
        { id = domId
        , multiple = isMultiple
        , open = False
        , query = ""
        , highlighted = Nothing
        , revealed = False
        , expanded = Set.empty
        , flips = Set.empty
        , chosen = Dict.empty
        , cover = Set.empty
        , next = 0
        , list = VirtualList.init (treeId domId)
        , cache = Nothing
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


rowDomId : String -> Int -> String
rowDomId domId index =
    domId ++ "-row-" ++ String.fromInt index


{-| The chosen node of a single field, or `Nothing` when nothing is chosen. A
value set with `setValue` is returned at once, also while the nodes are still
loading.
-}
value : State Single id -> Maybe id
value state =
    List.head (chosenIds state)


{-| The chosen nodes of a multiple field, in the order they were chosen. A node
that stands for a branch is one id: see "What a checked box means" above. Ids set
with `setValues` are returned at once, also while the nodes are still loading.
-}
values : State Multiple id -> List id
values state =
    chosenIds state


chosenIds : State mode id -> List id
chosenIds (State data) =
    data.chosen
        |> Dict.values
        |> List.sortBy .order
        |> List.map .id


{-| Chooses a node of a single field from your code, for example to show a saved
record. The label is looked up in the nodes when they are shown; use `setNode`
when the node may not be among them (it is inside a branch that is not loaded).

    TreeSelect.setValue siteIds hall3 model.site

-}
setValue : Ids id -> id -> State Single id -> State Single id
setValue ids id (State data) =
    State (refreshCached (replaceChosen [ { id = id, key = Picking.toKey ids id, label = Nothing } ] data))


{-| Chooses a node of a single field and remembers its label, so the field shows
it even when the nodes you give do not contain it. Only the node itself is used,
not its children.
-}
setNode : Node id -> State Single id -> State Single id
setNode node (State data) =
    State (refreshCached (replaceChosen [ fromNode node ] data))


{-| Replaces the chosen nodes of a multiple field from your code. Duplicates are
dropped. The labels are looked up in the nodes when they are shown; use `setNodes`
when they may not be among them. The value is taken as you give it as long as the
field does not know the nodes (`europe` and `oslo` together are two ids, and the
field draws what that means: Oslo inside a checked Europe is simply checked, and
Norway with Oslo and Bergen checked is checked); once the field has seen the nodes
(its popup has been open) it puts what you set in its shortest form, like what the
user checks.

    TreeSelect.setValues siteIds [ europe, asia ] model.sites

-}
setValues : Ids id -> List id -> State Multiple id -> State Multiple id
setValues ids ids_ (State data) =
    State
        (refreshCached
            (normalizeCover (replaceChosen (List.map (\id -> { id = id, key = Picking.toKey ids id, label = Nothing }) ids_) data))
        )


{-| Replaces the chosen nodes of a multiple field with these nodes and remembers
their labels. Only the nodes themselves are used, not their children.
-}
setNodes : List (Node id) -> State Multiple id -> State Multiple id
setNodes nodes_ (State data) =
    State (refreshCached (normalizeCover (replaceChosen (List.map fromNode nodes_) data)))


{-| Puts the chosen nodes in their shortest form, when the field knows the nodes
(it does once its popup has been open). Without nodes the value is kept as it was
given, and the boxes are drawn right all the same.
-}
normalizeCover : Data id -> Data id
normalizeCover data =
    case data.cache of
        Just cache ->
            let
                shortest =
                    Cover.normalize cache.index data.cover
            in
            if shortest == data.cover then
                data

            else
                setCover cache.index shortest data

        Nothing ->
            data


type alias Pick id =
    { id : id
    , key : String
    , label : Maybe String
    }


fromNode : Node id -> Pick id
fromNode node =
    { id = Picking.id node, key = Picking.key node, label = Just (Picking.label node) }


replaceChosen : List (Pick id) -> Data id -> Data id
replaceChosen picks data =
    let
        ( chosen, next ) =
            List.foldl
                (\pick ( dict, n ) ->
                    if Dict.member pick.key dict then
                        ( dict, n )

                    else
                        ( Dict.insert pick.key { id = pick.id, order = n, label = pick.label } dict, n + 1 )
                )
                ( Dict.empty, data.next )
                picks
    in
    { data | chosen = chosen, cover = Set.fromList (Dict.keys chosen), next = next }


{-| The chosen nodes of a multiple field written out as the nodes that have no
children: every node below a chosen branch, in the order of the tree, without the
ones that are `disabled`. A node whose children are not loaded stays as it is, and
so does a chosen id that is not in the nodes. Give it the same nodes that you give
to `view`.

    TreeSelect.leaves nodes model.sites --> the halls, not the regions

-}
leaves : List (Node id) -> State Multiple id -> List id
leaves nodes_ (State data) =
    let
        index =
            Index.build nodes_

        byKey key =
            case Index.get key index of
                Just entry ->
                    Just (Picking.id entry.node)

                Nothing ->
                    Dict.get key data.chosen |> Maybe.map .id
    in
    Cover.leaves index data.cover |> List.filterMap byKey


{-| Removes the chosen node or nodes, so that `value` is `Nothing` and `values`
is empty again.
-}
clear : State mode id -> State mode id
clear (State data) =
    State (refreshCached (replaceChosen [] data))


{-| The text in the search box while the popup is open, and `""` when it is
closed.
-}
query : State mode id -> String
query (State data) =
    data.query


{-| Whether the popup is open.
-}
isOpen : State mode id -> Bool
isOpen (State data) =
    data.open


{-| Opens the popup with an empty search and moves focus into its search box, for
example from a button of your own. Map the command like the one from `update`.
-}
open : State mode id -> ( State mode id, Cmd (Msg id) )
open (State data) =
    ( State { data | open = True, query = "", highlighted = Nothing, flips = Set.empty, list = VirtualList.reset data.list }
    , Internal.focus (searchId data.id) NoOp
    )


{-| Closes the popup, forgets the search text, and gives focus back to the field
if the popup was open. Map the command like the one from `update`.
-}
close : State mode id -> ( State mode id, Cmd (Msg id) )
close (State data) =
    ( State { data | open = False, query = "", highlighted = Nothing, flips = Set.empty }
    , if data.open then
        Internal.focus data.id NoOp

      else
        Cmd.none
    )


{-| The lazy nodes whose children somebody is waiting for: the open nodes of the
open popup whose children are `NotAsked`. Usually zero or one; `*` on the keyboard
can open several. Call it after every `update` of the field. Set the children of
the nodes it names to `Loading` in your data and fetch them; the next time you
build the nodes they hold the answer. Asking again is harmless, because a node you
have marked `Loading` is not named any more.

    SiteMsg inner ->
        let
            ( site, cmd ) =
                TreeSelect.update inner model.site

            requested =
                TreeSelect.loadRequests site
        in
        ( { model | site = site, zones = markLoading requested model.zones }
        , Cmd.batch (Cmd.map SiteMsg cmd :: List.map fetchZones requested)
        )

The answer is worked out from the nodes of the last message the field got, so if
you set a node back to `NotAsked` yourself (to load it again), you also fetch it
yourself: the field asks again only after its next message. After a failure the
user retries with the button that `onRetryChildren` adds.

-}
loadRequests : State mode id -> List id
loadRequests (State data) =
    case ( data.open, data.cache ) of
        ( True, Just cache ) ->
            cache.rows.rows
                |> Array.toList
                |> List.filterMap
                    (\entryRow ->
                        case entryRow of
                            LoadingRow r ->
                                case Index.get r.parent cache.index of
                                    Just entry ->
                                        case entry.kids of
                                            Unloaded ->
                                                Just (Picking.id entry.node)

                                            _ ->
                                                Nothing

                                    Nothing ->
                                        Nothing

                            _ ->
                                Nothing
                    )

        _ ->
            []


{-| The keys of the nodes that are open now: what the user opened, or while a
filter is active the nodes with matches below, turned around by what the user
flipped.
-}
openKeys : Data id -> Set String
openKeys data =
    case data.cache |> Maybe.andThen .filter of
        Just f ->
            Set.union (Set.diff f.forced data.flips) (Set.diff data.flips f.forced)

        Nothing ->
            data.expanded



-- CACHE


{-| What the component needs to know about the nodes in one place, so that
messages from the view hand it over.
-}
type alias Env id =
    { nodes : List (Node id)
    , visibleRows : Int
    , canRetry : Bool
    }


{-| Rebuilds what is worked out from the nodes, the open nodes, the search text
and the chosen nodes. The index is reused while the nodes are the same list.
-}
refreshWith : List (Node id) -> Data id -> Data id
refreshWith nodes_ data0 =
    let
        ( index, reusable ) =
            case data0.cache of
                Just cache ->
                    if cache.nodes == nodes_ then
                        ( cache.index, Just cache )

                    else
                        ( Index.build nodes_, Nothing )

                Nothing ->
                    ( Index.build nodes_, Nothing )

        -- a single field that opened before its nodes had arrived opens on its
        -- value as soon as they have
        data =
            reveal index data0

        ( filterOf, filter ) =
            case reusable of
                Just cache ->
                    if cache.filterOf == data.query then
                        ( cache.filterOf, cache.filter )

                    else
                        ( data.query, Index.filter data.query index )

                Nothing ->
                    ( data.query, Index.filter data.query index )

        ( derivedFor, derived ) =
            case reusable of
                Just cache ->
                    if cache.derivedFor == data.cover then
                        ( cache.derivedFor, cache.derived )

                    else
                        ( data.cover, Cover.derive index data.cover )

                Nothing ->
                    ( data.cover, Cover.derive index data.cover )

        rows =
            Index.rows { expanded = data.expanded, flips = data.flips, filter = filter } index

        labelled =
            rememberLabels index data
    in
    { labelled
        | cache =
            Just
                { nodes = nodes_
                , index = index
                , filterOf = filterOf
                , filter = filter
                , derivedFor = derivedFor
                , derived = derived
                , rows = rows
                }
    }


{-| An open single field shows its value: the nodes above it are opened and it is
highlighted. It happens once for each time the popup opens, as soon as the nodes
have the value (they may come from the backend after the popup opened).
-}
reveal : Index id -> Data id -> Data id
reveal index data =
    if data.revealed || not data.open || data.multiple then
        data

    else
        case Dict.keys data.chosen of
            key :: _ ->
                if Index.get key index == Nothing then
                    data

                else
                    { data
                        | expanded = List.foldl Set.insert data.expanded (Index.ancestors key index)
                        , highlighted = Just (AtNode key)
                        , revealed = True
                    }

            [] ->
                { data | revealed = True }


refreshCached : Data id -> Data id
refreshCached data =
    case data.cache of
        Just cache ->
            refreshWith cache.nodes data

        Nothing ->
            data


{-| A chosen node whose label is not known yet gets it from the tree, so that the
closed field does not have to look for it again.
-}
rememberLabels : Index id -> Data id -> Data id
rememberLabels index data =
    if List.all (\c -> c.label /= Nothing) (Dict.values data.chosen) then
        data

    else
        { data
            | chosen =
                Dict.map
                    (\key c ->
                        case c.label of
                            Just _ ->
                                c

                            Nothing ->
                                { c | label = Index.get key index |> Maybe.map .label }
                    )
                    data.chosen
        }


{-| Sets the chosen nodes to this cover. New members are numbered after the
others, in the order of the tree, and get their label from the tree.
-}
setCover : Index id -> Set String -> Data id -> Data id
setCover index cover data =
    let
        known =
            Set.toList cover |> List.filter (\key -> Dict.member key data.chosen)

        fresh =
            Set.toList cover
                |> List.filter (\key -> not (Dict.member key data.chosen))
                |> List.filterMap (\key -> Index.get key index)
                |> List.sortBy .position

        kept =
            List.filterMap (\key -> Dict.get key data.chosen |> Maybe.map (Tuple.pair key)) known

        ( chosen, next ) =
            List.foldl
                (\entry ( dict, n ) ->
                    ( Dict.insert entry.key { id = Picking.id entry.node, order = n, label = Just entry.label } dict, n + 1 )
                )
                ( Dict.fromList kept, data.next )
                fresh
    in
    { data | chosen = chosen, cover = Set.fromList (Dict.keys chosen), next = next }



-- UPDATE


{-| The messages a field sends. Wrap it in a constructor of your own message type
(`SiteMsg TreeSelect.Msg`), give that constructor to `view`, and pass the messages
you get back to `update`.
-}
type Msg id
    = Open (Env id) String
    | Close
    | Dismiss
    | QueryChanged (Env id) String
    | Backspace (Env id)
    | Key (Env id) Move
    | Hover (Env id) Pos
    | Choose (Env id) String
    | ToggleOpen (Env id) String
    | Remove String
    | RemoveLast
    | Clear
    | FocusSearch
    | ListMsg VirtualList.Msg
    | NoOp


{-| A key that moves through the rows.
-}
type Move
    = Down
    | Up
    | PageDown
    | PageUp
    | First
    | Last
    | Enter
    | Space
    | Right
    | Left
    | Star


{-| Handles a message of the field and returns the new state with a command
(moving focus, scrolling the list). Map the command into your own message type
with `Cmd.map`.

    SiteMsg inner ->
        let
            ( site, cmd ) =
                TreeSelect.update inner model.site
        in
        ( { model | site = site }, Cmd.map SiteMsg cmd )

-}
update : Msg id -> State mode id -> ( State mode id, Cmd (Msg id) )
update msg (State data) =
    let
        ( next, cmd ) =
            step msg data
    in
    ( State next, cmd )


step : Msg id -> Data id -> ( Data id, Cmd (Msg id) )
step msg data =
    case msg of
        Open env text ->
            if data.open then
                -- characters typed on the field before focus reached the search box
                if text == "" then
                    ( data, Cmd.none )

                else
                    step (QueryChanged env (data.query ++ text)) data

            else
                openWith env text data

        Backspace env ->
            if not data.open then
                ( data, Cmd.none )

            else if data.query == "" && data.multiple then
                step RemoveLast data

            else
                step (QueryChanged env (String.dropRight 1 data.query)) data

        Close ->
            closeWith data

        Dismiss ->
            ( { data | open = False, query = "", highlighted = Nothing, flips = Set.empty }, Cmd.none )

        QueryChanged env text ->
            let
                changed =
                    refreshWith env.nodes { data | query = text, flips = Set.empty, highlighted = Nothing }

                ( list, scroll ) =
                    VirtualList.scrollTo 0 changed.list
            in
            ( { changed | list = list }, Cmd.map ListMsg scroll )

        Key env move ->
            if data.open then
                moveBy env move (refreshWith env.nodes data)

            else
                ( data, Cmd.none )

        Hover env pos ->
            -- the view hands over the nodes, so that after they changed the next
            -- draw uses a cache that is up to date and not a new one for every row
            ( { data | highlighted = Just pos } |> refreshFor env.nodes, Cmd.none )

        Choose env key ->
            choose key (refreshWith env.nodes data)

        ToggleOpen env key ->
            ( setOpen (not (isOpenNow data key)) key (refreshWith env.nodes data) |> refreshCached, Cmd.none )

        Remove key ->
            ( remove key data
            , if data.open then
                Cmd.none

              else
                Internal.focus data.id NoOp
            )

        RemoveLast ->
            case List.reverse (Dict.toList data.chosen |> List.sortBy (Tuple.second >> .order)) of
                ( key, _ ) :: _ ->
                    ( remove key data, Cmd.none )

                [] ->
                    ( data, Cmd.none )

        Clear ->
            ( refreshCached (replaceChosen [] data)
            , if data.open then
                Internal.focus (searchId data.id) NoOp

              else
                Internal.focus data.id NoOp
            )

        FocusSearch ->
            ( data, Internal.focus (searchId data.id) NoOp )

        ListMsg inner ->
            let
                ( list, cmd ) =
                    VirtualList.update inner data.list
            in
            ( { data | list = list }, Cmd.map ListMsg cmd )

        NoOp ->
            ( data, Cmd.none )


closeWith : Data id -> ( Data id, Cmd (Msg id) )
closeWith data =
    ( { data | open = False, query = "", highlighted = Nothing, flips = Set.empty }
    , if data.open then
        Internal.focus data.id NoOp

      else
        Cmd.none
    )


remove : String -> Data id -> Data id
remove key data =
    case data.cache of
        Just cache ->
            setCover cache.index (Cover.uncheck cache.index data.cover key) data |> refreshCached

        Nothing ->
            replaceKeys (Set.remove key data.cover) data


{-| Keeps only the chosen nodes with these keys.
-}
replaceKeys : Set String -> Data id -> Data id
replaceKeys keys data =
    let
        chosen =
            Dict.filter (\key _ -> Set.member key keys) data.chosen
    in
    { data | chosen = chosen, cover = Set.fromList (Dict.keys chosen) }


openWith : Env id -> String -> Data id -> ( Data id, Cmd (Msg id) )
openWith env text data =
    let
        prepared =
            refreshWith env.nodes
                { data
                    | open = True
                    , query = text
                    , flips = Set.empty
                    , highlighted = Nothing
                    , list = VirtualList.reset data.list
                    , revealed = text /= ""
                }

        final =
            prepared

        ( list, scroll ) =
            case highlightIndex env.canRetry final of
                Just i ->
                    VirtualList.center (geometry env.visibleRows final) i final.list

                Nothing ->
                    ( final.list, Cmd.none )
    in
    ( { final | list = list }
    , Cmd.batch [ Internal.focus (searchId data.id) NoOp, Cmd.map ListMsg scroll ]
    )


rowsOf : Data id -> Maybe (Index.Rows id)
rowsOf data =
    Maybe.map .rows data.cache


geometry : Int -> Data id -> VirtualList.Geometry
geometry rowsVisible data =
    { rowHeight = rowHeight
    , height = rowsVisible * rowHeight
    , count = rowsOf data |> Maybe.map (.rows >> Array.length) |> Maybe.withDefault 0
    , inset = 0
    }


rowHeight : Int
rowHeight =
    32


navigable : Bool -> Row id -> Bool
navigable canRetry row =
    case row of
        NodeRow _ ->
            True

        FailedRow r ->
            canRetry && Remote.isRetryable r.problem

        LoadingRow _ ->
            False


indexOfPos : Pos -> Index.Rows id -> Maybe Int
indexOfPos pos rows =
    case pos of
        AtNode key ->
            Index.rowIndex key rows

        AtRetry key ->
            Index.failureIndex key rows


posOfRow : Row id -> Maybe Pos
posOfRow row =
    case row of
        NodeRow item ->
            Just (AtNode item.entry.key)

        FailedRow r ->
            Just (AtRetry r.parent)

        LoadingRow _ ->
            Nothing


{-| The row that is highlighted: the one the user moved to, or while there is none
the first match (when filtering) or the first row.
-}
highlightIndex : Bool -> Data id -> Maybe Int
highlightIndex canRetry data =
    case data.cache of
        Nothing ->
            Nothing

        Just cache ->
            case data.highlighted |> Maybe.andThen (\pos -> indexOfPos pos cache.rows) of
                Just i ->
                    Just i

                Nothing ->
                    let
                        isMatch row =
                            case row of
                                NodeRow item ->
                                    item.matched

                                _ ->
                                    False
                    in
                    if cache.rows.filtering then
                        case firstWhere isMatch cache.rows of
                            Just i ->
                                Just i

                            Nothing ->
                                firstWhere (navigable canRetry) cache.rows

                    else
                        firstWhere (navigable canRetry) cache.rows


firstWhere : (Row id -> Bool) -> Index.Rows id -> Maybe Int
firstWhere accept rows =
    case Array.get 0 rows.rows of
        Just row ->
            if accept row then
                Just 0

            else
                Index.nextRow accept 0 rows

        Nothing ->
            Nothing


highlightAt : Env id -> Int -> Data id -> ( Data id, Cmd (Msg id) )
highlightAt env i data =
    case data.cache |> Maybe.andThen (\cache -> Index.rowAt i cache.rows) |> Maybe.andThen posOfRow of
        Just pos ->
            let
                ( list, scroll ) =
                    VirtualList.ensureVisible (geometry env.visibleRows data) i data.list
            in
            ( { data | highlighted = Just pos, list = list }, Cmd.map ListMsg scroll )

        Nothing ->
            ( data, Cmd.none )


isOpenNow : Data id -> String -> Bool
isOpenNow data key =
    Set.member key (openKeys data)


{-| Opens or closes a node. While a filter is active the nodes with matches below
are open by themselves, so what the user does is remembered as a difference from
that, and forgotten when the text changes.
-}
setOpen : Bool -> String -> Data id -> Data id
setOpen wanted key data =
    case data.cache |> Maybe.andThen .filter of
        Just f ->
            { data
                | flips =
                    if Set.member key f.forced == wanted then
                        Set.remove key data.flips

                    else
                        Set.insert key data.flips
            }

        Nothing ->
            { data
                | expanded =
                    if wanted then
                        Set.insert key data.expanded

                    else
                        Set.remove key data.expanded
            }


moveBy : Env id -> Move -> Data id -> ( Data id, Cmd (Msg id) )
moveBy env move data =
    case ( data.cache, highlightIndex env.canRetry data ) of
        ( Just cache, Just current ) ->
            let
                rows =
                    cache.rows

                accept =
                    navigable env.canRetry

                stay =
                    ( data, Cmd.none )

                go target =
                    case target of
                        Just i ->
                            highlightAt env i data

                        Nothing ->
                            stay

                currentRow =
                    Index.rowAt current rows

                page =
                    max 1 (env.visibleRows - 1)
            in
            case move of
                Down ->
                    go (Index.nextRow accept current rows |> orElse current)

                Up ->
                    go (Index.previousRow accept current rows |> orElse current)

                PageDown ->
                    go (nearest accept 1 (min (Array.length rows.rows - 1) (current + page)) rows |> orElse current)

                PageUp ->
                    go (nearest accept -1 (max 0 (current - page)) rows |> orElse current)

                First ->
                    go (firstWhere accept rows |> orElse current)

                Last ->
                    go (Index.lastRow accept rows |> orElse current)

                Right ->
                    case currentRow of
                        Just (NodeRow item) ->
                            if item.open then
                                case Index.rowAt (current + 1) rows of
                                    Just next ->
                                        if accept next then
                                            highlightAt env (current + 1) data

                                        else
                                            stay

                                    Nothing ->
                                        stay

                            else if item.expandable then
                                ( refreshCached (setOpen True item.entry.key data), Cmd.none )

                            else
                                stay

                        _ ->
                            stay

                Left ->
                    case currentRow of
                        Just (NodeRow item) ->
                            if item.open then
                                ( refreshCached (setOpen False item.entry.key data), Cmd.none )

                            else
                                go (Index.parentRow current rows)

                        Just _ ->
                            go (Index.parentRow current rows)

                        Nothing ->
                            stay

                Star ->
                    case currentRow of
                        Just (NodeRow item) ->
                            let
                                siblings =
                                    rows.rows
                                        |> Array.toList
                                        |> List.filterMap
                                            (\row ->
                                                case row of
                                                    NodeRow other ->
                                                        if other.entry.parent == item.entry.parent && other.expandable && not other.open then
                                                            Just other.entry.key

                                                        else
                                                            Nothing

                                                    _ ->
                                                        Nothing
                                            )
                            in
                            ( refreshCached (List.foldl (setOpen True) data siblings), Cmd.none )

                        _ ->
                            stay

                Enter ->
                    chooseRow current data

                Space ->
                    chooseRow current data

        _ ->
            ( data, Cmd.none )


orElse : Int -> Maybe Int -> Maybe Int
orElse fallback maybe =
    case maybe of
        Just i ->
            Just i

        Nothing ->
            Just fallback


{-| The nearest row to `from` in a direction that the predicate accepts.
-}
nearest : (Row id -> Bool) -> Int -> Int -> Index.Rows id -> Maybe Int
nearest accept direction from rows =
    let
        forward =
            if direction > 0 then
                firstFrom accept 1 from rows

            else
                firstFrom accept -1 from rows
    in
    case forward of
        Just i ->
            Just i

        Nothing ->
            firstFrom accept (negate direction) from rows


firstFrom : (Row id -> Bool) -> Int -> Int -> Index.Rows id -> Maybe Int
firstFrom accept direction from rows =
    case Array.get from rows.rows of
        Nothing ->
            Nothing

        Just row ->
            if accept row then
                Just from

            else
                firstFrom accept direction (from + direction) rows


{-| Enter or Space on the highlighted row.
-}
chooseRow : Int -> Data id -> ( Data id, Cmd (Msg id) )
chooseRow current data =
    case data.cache |> Maybe.andThen (\cache -> Index.rowAt current cache.rows) of
        Just (NodeRow item) ->
            choose item.entry.key data

        _ ->
            ( data, Cmd.none )


{-| A node was picked, with the pointer or the keyboard. A node that is disabled
cannot be chosen, but it can be opened or closed.
-}
choose : String -> Data id -> ( Data id, Cmd (Msg id) )
choose key data =
    case data.cache |> Maybe.andThen (\cache -> Index.get key cache.index |> Maybe.map (Tuple.pair cache)) of
        Just ( cache, entry ) ->
            if entry.disabled then
                case entry.kids of
                    NoKids ->
                        ( data, Cmd.none )

                    _ ->
                        ( refreshCached (setOpen (not (isOpenNow data key)) key data), Cmd.none )

            else if data.multiple then
                ( setCover cache.index (Cover.toggle cache.index data.cover cache.derived key) data |> refreshCached
                , Cmd.none
                )

            else
                ( { data
                    | chosen = Dict.singleton key { id = Picking.id entry.node, order = data.next, label = Just entry.label }
                    , cover = Set.singleton key
                    , next = data.next + 1
                    , open = False
                    , query = ""
                    , highlighted = Nothing
                    , flips = Set.empty
                  }
                    |> refreshCached
                , Internal.focus data.id NoOp
                )

        Nothing ->
            ( data, Cmd.none )



-- ATTRIBUTES


{-| A setting of a field. Make them with the functions below and pass a list to
`view`; later attributes win over earlier ones.
-}
type Attribute id msg
    = Attribute (Config id msg -> Config id msg)


type alias Config id msg =
    { field : Field.Config
    , nodes : Remote (List (Node id))
    , placeholder : Maybe String
    , searchPlaceholder : Maybe String
    , clearable : Bool
    , valueText : Maybe (id -> String)
    , disabled : Bool
    , readOnly : Bool
    , size : Size
    , visibleRows : Int
    , maxVisibleChips : Int
    , locale : Locale
    , onRetry : Maybe msg
    , onRetryChildren : Maybe (id -> msg)
    }


configure : List (Attribute id msg) -> Config id msg
configure attributes =
    List.foldl (\(Attribute change) config -> change config)
        { field = Field.empty
        , nodes = Loaded []
        , placeholder = Nothing
        , searchPlaceholder = Nothing
        , clearable = False
        , valueText = Nothing
        , disabled = False
        , readOnly = False
        , size = Medium
        , visibleRows = 8
        , maxVisibleChips = 3
        , locale = Locale.default
        , onRetry = Nothing
        , onRetryChildren = Nothing
        }
        attributes


updateField : (Field.Config -> Field.Config) -> Attribute id msg
updateField change =
    Attribute (\config -> { config | field = change config.field })


{-| The top level of the tree, built with `Picking.leaf`, `Picking.branch` and
`Picking.lazy`. The default is no nodes. Use `nodes` or `remote`, not both: the
later one wins.

    TreeSelect.nodes [ Picking.branch siteIds oslo "Oslo" [ Picking.leaf siteIds hall3 "Hall 3" ] ]

-}
nodes : List (Node id) -> Attribute id msg
nodes list =
    Attribute (\config -> { config | nodes = Loaded list })


{-| The top level of the tree from the backend, as a `Remote` (see
[Klar.Remote](Klar-Remote)). The popup shows loading rows while the data is
`Loading` or `NotAsked`, a compact error with a retry button on `Failed` (see
`onRetry`), the empty state on `Loaded []`, and the tree on `Loaded`.

    TreeSelect.remote model.sites

-}
remote : Remote (List (Node id)) -> Attribute id msg
remote data =
    Attribute (\config -> { config | nodes = Tuple.first (Freshness.settle data) })


{-| The message to send when the user presses the "Try again" button of the error
shown when the top level (`remote`) failed to load. The button appears only for
problems that are worth retrying (network trouble, timeouts, server errors); while
it is shown, Enter in the search box sends the message as well.

    TreeSelect.onRetry ReloadSites

-}
onRetry : msg -> Attribute id msg
onRetry msg =
    Attribute (\config -> { config | onRetry = Just msg })


{-| The message to send, given the node id, when the user presses "Try again" on
a lazy node whose children failed to load (Enter does the same while that row is
highlighted). The button is only shown for problems that are worth retrying. Set
the children of that node to `Loading` again and fetch them; the rest of the tree
keeps working meanwhile.

    TreeSelect.onRetryChildren ReloadZones

-}
onRetryChildren : (id -> msg) -> Attribute id msg
onRetryChildren toMsg =
    Attribute (\config -> { config | onRetryChildren = Just toMsg })


{-| The label above the field. It names the field for screen readers.
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


{-| Shows a small x in the field that removes the chosen node or nodes. In a
single field Backspace and Delete do the same on the focused field. Nothing is
shown while nothing is chosen.
-}
clearable : Attribute id msg
clearable =
    Attribute (\config -> { config | clearable = True })


{-| How to write an id that is in none of the nodes you give, for example a saved
value inside a branch that is not loaded. Without it the field says "Unknown
value". The label of a node the field knows about is always its own.

    TreeSelect.valueText SiteId.toString

-}
valueText : (id -> String) -> Attribute id msg
valueText toText =
    Attribute (\config -> { config | valueText = Just toText })


{-| While `True` the field is dimmed, cannot be focused or opened, and has no
clear button. The value is kept. Pass a field of your model, for example while a
form is saving. The default is `False`.
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


{-| How many rows the open popup shows before it scrolls. The default is 8;
numbers below 3 or above 20 are brought into that range.
-}
visibleRows : Int -> Attribute id msg
visibleRows n =
    Attribute (\config -> { config | visibleRows = clamp 3 20 n })


{-| How many chosen nodes a multiple field writes out as chips. The default is 3.
When more nodes are chosen, the field shows one chip "40 selected" instead, which
has the remove button of the whole choice, so that the field does not grow with the
choice. The most is 20.
-}
maxVisibleChips : Int -> Attribute id msg
maxVisibleChips n =
    Attribute (\config -> { config | maxVisibleChips = clamp 0 20 n })


{-| The language of the built-in text: the placeholders, the search box, the
counts, the loading and error states and the labels for screen readers. The
default is `Locale.default`, which is English. See [Klar.Locale](Klar-Locale).

    TreeSelect.locale Locale.nb

-}
locale : Locale -> Attribute id msg
locale value_ =
    Attribute (\config -> { config | locale = value_ })



-- VIEW


{-| The field. It takes the constructor that wraps the component's `Msg` in your
own message type, a list of attributes, and the state.

    TreeSelect.view SiteMsg
        [ TreeSelect.label "Warehouse"
        , TreeSelect.nodes sites
        , TreeSelect.required
        ]
        model.site

Always give the field a `label`; `labelHidden` keeps it off the screen but
available to screen readers.

-}
view : (Msg id -> msg) -> List (Attribute id msg) -> State mode id -> Html msg
view toMsg attributes (State data) =
    let
        config =
            configure attributes

        field =
            Field.setId data.id config.field

        t =
            Texts.texts config.locale

        topNodes =
            Remote.withDefault [] config.nodes

        env =
            { nodes = topNodes
            , visibleRows = config.visibleRows
            , canRetry = View.isJust config.onRetryChildren
            }

        interactive =
            not config.disabled && not config.readOnly

        -- what the popup works from: the cache when it is for these nodes, or
        -- one built now (the first draw after the nodes changed)
        current =
            if data.open && interactive then
                refreshFor topNodes data

            else
                data
    in
    Field.viewStable field
        (Html.div
            [ Internal.cls
                [ "klar-anchor"
                , "klar-anchor--block"
                , "klar-select"
                , "klar-tree-select"
                , if data.multiple then
                    "klar-select--multi klar-tree-select--multiple"

                  else
                    ""
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


{-| The data as it is for these nodes: as it is when its cache is for them, else
with the cache built now.
-}
refreshFor : List (Node id) -> Data id -> Data id
refreshFor nodes_ data =
    case data.cache of
        Just cache ->
            if cache.nodes == nodes_ && cache.derivedFor == data.cover && cache.filterOf == data.query then
                data

            else
                refreshWith nodes_ data

        Nothing ->
            refreshWith nodes_ data


{-| What the closed field shows for a chosen node.
-}
type Shown
    = Labelled String
    | NotLoadedYet
    | LoadFailed
    | Unknown


shownFor : Config id msg -> Dict String String -> List ( String, Chosen id ) -> List ( String, Chosen id, Shown )
shownFor config fresh chosen =
    let
        unlabelled c =
            case config.nodes of
                Loaded _ ->
                    case config.valueText of
                        Just toText ->
                            Labelled (toText c.id)

                        Nothing ->
                            Unknown

                Failed _ ->
                    LoadFailed

                _ ->
                    NotLoadedYet

        labelOf ( key, c ) =
            -- the label that the nodes have now wins over the one remembered when
            -- the node was chosen (the application may have renamed it)
            case firstOf [ Dict.get key fresh, c.label ] of
                Just text ->
                    Labelled text

                Nothing ->
                    unlabelled c
    in
    List.map (\entry -> ( Tuple.first entry, Tuple.second entry, labelOf entry )) chosen


firstOf : List (Maybe a) -> Maybe a
firstOf options =
    case options of
        [] ->
            Nothing

        (Just found) :: _ ->
            Just found

        Nothing :: rest ->
            firstOf rest


shownText : Texts -> Shown -> String
shownText t shown =
    case shown of
        Labelled text ->
            text

        NotLoadedYet ->
            t.loading

        LoadFailed ->
            t.unavailable

        Unknown ->
            t.unknownValue


{-| The chosen nodes in the order they were chosen, each with what the field
shows for it. The label is the one that the nodes you give have now (the
application may have renamed a node since it was chosen): from the index when the
field has one of exactly these nodes, otherwise by one walk of the tree that
stops when everything is found. A field that has never seen the nodes (no popup
was open) shows the label it remembers, and walks the tree only for a node it has
no label for.
-}
resolveChosen : Config id msg -> Data id -> Int -> List ( String, Chosen id, Shown )
resolveChosen config data limit =
    let
        shown =
            Dict.toList data.chosen |> List.sortBy (Tuple.second >> .order) |> List.take limit

        nodes_ =
            Remote.withDefault [] config.nodes

        wanted =
            shown |> List.map Tuple.first |> Set.fromList

        unlabelled =
            shown
                |> List.filter (\( _, c ) -> c.label == Nothing)
                |> List.map Tuple.first
                |> Set.fromList

        fresh =
            case data.cache of
                Just cache ->
                    if cache.nodes == nodes_ then
                        wanted
                            |> Set.toList
                            |> List.filterMap (\key -> Index.get key cache.index |> Maybe.map (\entry -> ( key, entry.label )))
                            |> Dict.fromList

                    else
                        Index.findLabels wanted nodes_

                Nothing ->
                    Index.findLabels unlabelled nodes_
    in
    shownFor config fresh shown


{-| The path to a chosen node as a tooltip (several nodes can have the same
label), when the field has an index of the nodes you give.
-}
pathOf : Config id msg -> Data id -> String -> Maybe String
pathOf config data key =
    case data.cache of
        Just cache ->
            if cache.nodes == Remote.withDefault [] config.nodes then
                case Index.labelPath key cache.index of
                    [] ->
                        Nothing

                    path ->
                        Just (String.join " / " path)

            else
                Nothing

        Nothing ->
            Nothing


viewControl : (Msg id -> msg) -> Config id msg -> Field.Config -> Texts -> Env id -> Data id -> Html msg
viewControl toMsg config field t env data =
    let
        interactive =
            not config.disabled && not config.readOnly

        count =
            Dict.size data.chosen

        openMsg =
            toMsg (Open env "")

        showClear =
            config.clearable && interactive && count > 0

        typed =
            Just (\char -> toMsg (Open env char))

        triggerKeys =
            if interactive && not data.open then
                View.onTriggerKeys
                    ([ ( "Enter", openMsg ), ( " ", openMsg ), ( "ArrowDown", openMsg ), ( "ArrowUp", openMsg ) ]
                        ++ (if count > 0 && data.multiple then
                                [ ( "Backspace", toMsg RemoveLast ) ]

                            else if showClear then
                                [ ( "Backspace", toMsg Clear ), ( "Delete", toMsg Clear ) ]

                            else
                                []
                           )
                    )
                    typed

            else if interactive then
                -- keys typed after the popup opened but before focus reached its
                -- search box still belong to the search
                View.onWindowKeys
                    { typed = \char -> toMsg (Open env char)
                    , backspace = toMsg (Backspace env)
                    , move = \move -> toMsg (Key env (fromViewMove move))
                    , close = toMsg Close
                    , leave = toMsg Dismiss
                    }

            else
                Internal.noAttr

        triggerAttributes extra =
            Field.controlAttributes field
                ++ [ Attr.type_ "button"
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
                   , triggerKeys
                   ]
                ++ extra

        controlClasses =
            [ "klar-input"
            , "klar-input--" ++ Theme.sizeSuffix config.size
            , "klar-select__control"
            , if data.multiple then
                "klar-select__control--multi"

              else
                ""
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
    in
    if data.multiple then
        viewMultipleControl toMsg config t data controlClasses triggerAttributes openMsg showClear interactive

    else
        let
            shown =
                resolveChosen config data 1 |> List.head
        in
        Html.div
            [ Internal.cls controlClasses
            , if interactive then
                Events.onClick openMsg

              else
                Internal.noAttr
            ]
            [ Html.button
                (triggerAttributes
                    [ Internal.cls [ "klar-select__trigger" ]
                    , case shown of
                        Just ( _, _, Labelled text ) ->
                            Attr.title (pathTitle data text)

                        _ ->
                            Internal.noAttr
                    ]
                )
                (case shown of
                    Just ( _, _, status ) ->
                        [ Html.span
                            [ Internal.cls
                                (case status of
                                    Labelled _ ->
                                        [ "klar-select__value" ]

                                    _ ->
                                        [ "klar-select__value", "klar-select__value--unknown" ]
                                )
                            ]
                            [ Html.text (shownText t status) ]
                        ]

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


{-| The tooltip of a single field: the path to the node, when the component knows
the tree.
-}
pathTitle : Data id -> String -> String
pathTitle data text =
    case ( Dict.keys data.chosen, data.cache ) of
        ( key :: _, Just cache ) ->
            case Index.labelPath key cache.index of
                [] ->
                    text

                path ->
                    String.join " / " path

        _ ->
            text


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


{-| A click that started on a chip's remove button must not open the popup.
-}
fromRemoveButton : Decode.Decoder Bool
fromRemoveButton =
    let
        hasClass path =
            Decode.oneOf
                [ Decode.at (path ++ [ "className" ]) Decode.string |> Decode.map (String.contains "klar-tag__remove")
                , Decode.succeed False
                ]
    in
    Decode.map2 (||) (hasClass [ "target" ]) (hasClass [ "target", "parentElement" ])


viewMultipleControl :
    (Msg id -> msg)
    -> Config id msg
    -> Texts
    -> Data id
    -> List String
    -> (List (Html.Attribute msg) -> List (Html.Attribute msg))
    -> msg
    -> Bool
    -> Bool
    -> Html msg
viewMultipleControl toMsg config t data controlClasses triggerAttributes openMsg showClear interactive =
    let
        count =
            Dict.size data.chosen

        chipLimit =
            config.maxVisibleChips

        asChips =
            count <= chipLimit

        resolved =
            resolveChosen config data (min count (max chipLimit 10))

        tagSize =
            if config.size == Small then
                Small

            else
                Medium

        chip ( key, _, status ) =
            case status of
                Labelled text ->
                    Html.span [ Internal.cls [ "klar-select__chip" ], Attr.title (Maybe.withDefault text (pathOf config data key)) ]
                        [ Tag.view
                            ([ Tag.size tagSize, Tag.locale config.locale ]
                                ++ (if interactive then
                                        [ Tag.onRemove (toMsg (Remove key)) ]

                                    else
                                        []
                                   )
                            )
                            text
                        ]

                _ ->
                    Html.span [ Internal.cls [ "klar-select__chip", "klar-select__chip--unknown" ] ]
                        [ Tag.view [ Tag.size tagSize, Tag.outline, Tag.locale config.locale ] (shownText t status) ]

        -- the same chip as a Tag draws, with a remove button that is named for
        -- what it does ("Clear the selection"), not "Remove 40 selected"
        summaryChip =
            Html.span [ Internal.cls [ "klar-select__chip" ] ]
                [ Html.span
                    [ Internal.cls
                        [ "klar-tag"
                        , "klar-tag--" ++ Theme.toneSuffix Neutral
                        , "klar-tag--" ++ Theme.sizeSuffix tagSize
                        ]
                    ]
                    [ Html.span [ Internal.cls [ "klar-tag__label" ] ] [ Html.text (t.selected count) ]
                    , if interactive then
                        Html.button
                            [ Internal.cls [ "klar-tag__remove" ]
                            , Attr.type_ "button"
                            , Attr.attribute "aria-label" t.clearChosen
                            , Attr.title t.clearChosen
                            , Events.onClick (toMsg Clear)
                            ]
                            [ Icon.sized Icon.ExtraSmall Icon.close ]

                      else
                        Html.text ""
                    ]
                ]

        summary =
            if count == 0 then
                Maybe.withDefault t.placeholder config.placeholder

            else
                t.selected count
                    ++ ": "
                    ++ String.join ", " (List.map (\( _, _, status ) -> shownText t status) (List.take 10 resolved))
                    ++ (if count > 10 then
                            ", …"

                        else
                            ""
                       )
    in
    Html.div
        [ Internal.cls controlClasses
        , if interactive then
            Events.on "click"
                (fromRemoveButton
                    |> Decode.andThen
                        (\isRemove ->
                            if isRemove then
                                Decode.fail "chip removed"

                            else
                                Decode.succeed openMsg
                        )
                )

          else
            Internal.noAttr
        ]
        [ Html.button
            (triggerAttributes [ Internal.cls [ "klar-select__trigger", "klar-select__trigger--overlay" ] ])
            [ Html.span [ Internal.cls [ "klar-sr-only" ] ] [ Html.text summary ] ]
        , Html.div [ Internal.cls [ "klar-select__chips" ] ]
            (if count == 0 then
                [ Html.span [ Internal.cls [ "klar-select__placeholder" ], Attr.attribute "aria-hidden" "true" ]
                    [ Html.text (Maybe.withDefault t.placeholder config.placeholder) ]
                ]

             else if asChips then
                List.map chip resolved

             else
                [ summaryChip ]
            )
        , if showClear && asChips then
            View.viewClearButton t.clearAll (toMsg Clear)

          else
            Html.text ""
        , if config.readOnly then
            Html.text ""

          else
            View.viewChevron
        ]



-- POPUP


{-| The rows that are rendered by the virtual list: the same arithmetic as
`VirtualList`, so that `aria-activedescendant` only names a row that exists.
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

        content =
            case ( data.cache, loaded ) of
                ( Just cache, True ) ->
                    Just cache

                _ ->
                    Nothing

        rowCount =
            content |> Maybe.map (.rows >> .rows >> Array.length) |> Maybe.withDefault 0

        highlighted =
            if loaded then
                highlightIndex env.canRetry data

            else
                Nothing

        inRange i =
            let
                ( from, to ) =
                    renderedRange rowCount config.visibleRows data.list
            in
            i >= from && i < to

        highlightedRow =
            case ( content, highlighted ) of
                ( Just cache, Just i ) ->
                    Index.rowAt i cache.rows |> Maybe.map (Tuple.pair i)

                _ ->
                    Nothing

        retryRowMsg =
            case ( highlightedRow, content ) of
                ( Just ( _, FailedRow r ), Just cache ) ->
                    case ( config.onRetryChildren, Index.get r.parent cache.index ) of
                        ( Just toRetry, Just entry ) ->
                            if Remote.isRetryable r.problem then
                                Just (toRetry (Picking.id entry.node))

                            else
                                Nothing

                        _ ->
                            Nothing

                _ ->
                    Nothing

        emptyQuery =
            data.query == ""

        keys =
            View.onSearchKeys
                { handled =
                    (if loaded && highlighted /= Nothing then
                        [ View.plain "ArrowDown" (toMsg (Key env Down))
                        , View.plain "ArrowUp" (toMsg (Key env Up))
                        , View.plain "PageDown" (toMsg (Key env PageDown))
                        , View.plain "PageUp" (toMsg (Key env PageUp))
                        , View.plain "Home" (toMsg (Key env First))
                        , View.plain "End" (toMsg (Key env Last))
                        , View.atEnd "ArrowRight" (toMsg (Key env Right))
                        , View.atStart "ArrowLeft" (toMsg (Key env Left))
                        , View.whenEmpty " " (toMsg (Key env Space))
                        , View.whenEmpty "*" (toMsg (Key env Star))
                        , View.plain "Enter"
                            (case retryRowMsg of
                                Just retryMsg ->
                                    retryMsg

                                Nothing ->
                                    toMsg (Key env Enter)
                            )
                        ]

                     else
                        [ View.plain "Enter" (Maybe.withDefault (toMsg NoOp) retry) ]
                    )
                        ++ [ View.plain "Escape" (toMsg Close) ]
                        ++ (if data.multiple && emptyQuery && not (Dict.isEmpty data.chosen) then
                                [ View.whenEmptyFresh "Backspace" (toMsg RemoveLast) ]

                            else
                                []
                           )
                , passive =
                    if View.isJust retry then
                        [ View.plain "Shift+Tab" (toMsg Dismiss) ]

                    else if data.multiple && not (Dict.isEmpty data.chosen) && loaded then
                        [ View.plain "Shift+Tab" (toMsg Dismiss) ]

                    else
                        [ View.plain "Tab" (toMsg Dismiss), View.plain "Shift+Tab" (toMsg Dismiss) ]
                }

        body =
            case topLevel of
                Loaded _ ->
                    case content of
                        Just cache ->
                            if cache.rows.shown == 0 then
                                if Index.size cache.index == 0 then
                                    View.viewEmpty Icon.inbox t.noOptions Nothing

                                else
                                    View.viewEmpty Icon.search t.noMatches (Just (t.noMatchesFor (String.trim data.query)))

                            else
                                Html.div []
                                    [ viewTree toMsg config t env data cache highlighted inRange
                                    , viewFooter toMsg config t data cache
                                    ]

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

        hasRows =
            loaded && rowCount > 0
    in
    View.viewLayer (toMsg Close)
        (Html.div
            [ Internal.cls [ "klar-popup", "klar-select__popup", "klar-tree-select__popup" ]
            , Attr.id (popupId data.id)
            , Internal.onClickStop (toMsg NoOp)
            , View.holdSearchFocus (toMsg NoOp)
            ]
            [ View.viewSearch
                { id = searchId data.id
                , controls =
                    if hasRows then
                        Just (treeId data.id)

                    else
                        Nothing
                , popup = "tree"
                , query = data.query
                , placeholder = Maybe.withDefault t.searchPlaceholder config.searchPlaceholder
                , label = t.searchLabel
                , activeDescendant =
                    case highlighted of
                        Just i ->
                            if hasRows && inRange i then
                                Just (rowDomId data.id i)

                            else
                                Nothing

                        Nothing ->
                            Nothing
                , onInput = QueryChanged env >> toMsg
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


viewFooter : (Msg id -> msg) -> Config id msg -> Texts -> Data id -> Cache id -> Html msg
viewFooter toMsg _ t data cache =
    let
        rows =
            cache.rows

        count =
            Dict.size data.chosen

        base =
            if rows.filtering then
                t.matches rows.matchCount rows.total

            else
                t.options rows.total

        status =
            if data.multiple then
                base ++ " · " ++ t.selected count

            else
                base

        actions =
            if data.multiple then
                [ Button.view
                    [ Button.small
                    , Button.ghost
                    , Button.disabled (count == 0)
                    , Button.onClick (toMsg Clear)
                    , Button.htmlAttrs
                        (Internal.onMouseDownPrevent (toMsg NoOp)
                            :: (if count > 0 then
                                    [ View.onKeydown { handled = [], passive = [ ( "Tab", toMsg Dismiss ) ] } ]

                                else
                                    []
                               )
                        )
                    ]
                    t.clearAll
                ]

            else
                []
    in
    View.viewFooter status actions


viewTree : (Msg id -> msg) -> Config id msg -> Texts -> Env id -> Data id -> Cache id -> Maybe Int -> (Int -> Bool) -> Html msg
viewTree toMsg config t env data cache highlighted _ =
    let
        rowConfig =
            { toMsg = toMsg
            , config = config
            , t = t
            , env = env
            , data = data
            , cache = cache
            , highlighted = highlighted
            }

        listAttributes =
            [ VirtualList.rowHeight rowHeight
            , VirtualList.height (config.visibleRows * rowHeight)
            , VirtualList.htmlAttrs
                [ Internal.cls [ "klar-select__list", "klar-tree-select__tree" ]
                , Attr.attribute "role" "tree"
                , Internal.attrIf data.multiple (Attr.attribute "aria-multiselectable" "true")
                , Internal.attrMaybe (Attr.attribute "aria-label") config.field.label

                -- dragging the scrollbar must not take focus from the search box
                , Internal.onMouseDownPrevent (toMsg NoOp)
                ]
            ]
    in
    VirtualList.view (ListMsg >> toMsg)
        listAttributes
        { items = cache.rows.rows, viewRow = viewRow rowConfig }
        data.list


type alias RowConfig id msg =
    { toMsg : Msg id -> msg
    , config : Config id msg
    , t : Texts
    , env : Env id
    , data : Data id
    , cache : Cache id
    , highlighted : Maybe Int
    }


viewRow : RowConfig id msg -> Int -> Row id -> Html msg
viewRow rc index row =
    case row of
        NodeRow item ->
            viewNodeRow rc index item

        LoadingRow r ->
            Html.div
                [ Internal.cls [ "klar-select__option", "klar-tree-select__row", "klar-tree-select__row--status" ]
                , Attr.id (rowDomId rc.data.id index)
                , Attr.attribute "role" "treeitem"
                , Attr.attribute "aria-level" (String.fromInt (r.depth + 1))
                , Attr.attribute "aria-disabled" "true"
                , Attr.attribute "aria-busy" "true"
                , Internal.styleVars [ ( "--klar-depth", String.fromInt r.depth ) ]
                ]
                [ Html.span [ Internal.cls [ "klar-tree-select__spacer" ] ] []
                , Spinner.view []
                , Html.span [ Internal.cls [ "klar-tree-select__status-text" ] ] [ Html.text rc.t.loadingChildren ]
                ]

        FailedRow r ->
            viewFailedRow rc index r


viewFailedRow : RowConfig id msg -> Int -> { parent : String, depth : Int, problem : Remote.Problem } -> Html msg
viewFailedRow rc index r =
    let
        retryMsg =
            case ( rc.config.onRetryChildren, Index.get r.parent rc.cache.index ) of
                ( Just toRetry, Just entry ) ->
                    if Remote.isRetryable r.problem then
                        Just (toRetry (Picking.id entry.node))

                    else
                        Nothing

                _ ->
                    Nothing

        isHighlighted =
            rc.highlighted == Just index
    in
    Html.div
        ([ Internal.cls
            [ "klar-select__option"
            , "klar-tree-select__row"
            , "klar-tree-select__row--status"
            , "klar-tree-select__row--failed"
            , if isHighlighted then
                "klar-select__option--highlighted"

              else
                ""
            ]
         , Attr.id (rowDomId rc.data.id index)
         , Attr.attribute "role" "treeitem"
         , Attr.attribute "aria-level" (String.fromInt (r.depth + 1))
         , Internal.styleVars [ ( "--klar-depth", String.fromInt r.depth ) ]
         , Internal.onMouseDownPrevent (rc.toMsg NoOp)
         ]
            ++ (case retryMsg of
                    Just _ ->
                        [ Events.on "mousemove"
                            (if isHighlighted then
                                Decode.fail "already highlighted"

                             else
                                Decode.succeed (rc.toMsg (Hover rc.env (AtRetry r.parent)))
                            )
                        ]

                    Nothing ->
                        [ Attr.attribute "aria-disabled" "true" ]
               )
        )
        [ Html.span [ Internal.cls [ "klar-tree-select__spacer" ] ] []
        , Html.span [ Internal.cls [ "klar-tree-select__status-text", "klar-tree-select__status-text--error" ] ] [ Html.text rc.t.couldNotLoadChildren ]
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


viewNodeRow : RowConfig id msg -> Int -> Index.Item id -> Html msg
viewNodeRow rc index item =
    let
        entry =
            item.entry

        data =
            rc.data

        isHighlighted =
            rc.highlighted == Just index

        node =
            entry.node

        state =
            if data.multiple then
                Cover.stateOf rc.cache.index data.cover rc.cache.derived entry.key

            else
                Unchecked

        isChosen =
            if data.multiple then
                state == Checked

            else
                Set.member entry.key data.cover

        searchText =
            data.query

        descriptionQuery =
            case Picking.description node of
                Just _ ->
                    if Index.matches (rc.cache.filter |> Maybe.map .words |> Maybe.withDefault []) (Search.normalize entry.label) then
                        ""

                    else
                        searchText

                Nothing ->
                    ""

        tooltip =
            case Picking.description node of
                Just description ->
                    entry.label ++ " – " ++ description

                Nothing ->
                    entry.label
    in
    Html.div
        [ Internal.cls
            [ "klar-select__option"
            , "klar-tree-select__row"
            , if isHighlighted then
                "klar-select__option--highlighted"

              else
                ""
            , if isChosen && not data.multiple then
                "klar-tree-select__row--chosen"

              else
                ""
            , if entry.disabled then
                "klar-select__option--disabled"

              else
                ""
            ]
        , Attr.id (rowDomId data.id index)
        , Attr.attribute "role" "treeitem"
        , Attr.attribute "aria-level" (String.fromInt (entry.depth + 1))
        , Attr.attribute "aria-setsize" (String.fromInt item.setSize)
        , Attr.attribute "aria-posinset" (String.fromInt item.posInSet)
        , Internal.attrIf item.expandable
            (Attr.attribute "aria-expanded"
                (if item.open then
                    "true"

                 else
                    "false"
                )
            )
        , if data.multiple then
            Attr.attribute "aria-checked"
                (case state of
                    Checked ->
                        "true"

                    Partial ->
                        "mixed"

                    Unchecked ->
                        "false"
                )

          else
            Attr.attribute "aria-selected"
                (if isChosen then
                    "true"

                 else
                    "false"
                )
        , Internal.attrIf entry.disabled (Attr.attribute "aria-disabled" "true")
        , Attr.title tooltip
        , Internal.styleVars [ ( "--klar-depth", String.fromInt entry.depth ) ]
        , Internal.onMouseDownPrevent (rc.toMsg NoOp)
        , Events.on "mousemove"
            (if isHighlighted then
                Decode.fail "already highlighted"

             else
                Decode.succeed (rc.toMsg (Hover rc.env (AtNode entry.key)))
            )
        , Internal.onClickPrevent (rc.toMsg (Choose rc.env entry.key))
        ]
        [ if item.expandable then
            Html.span
                [ Internal.cls
                    [ "klar-tree-select__toggle"
                    , if item.open then
                        "klar-tree-select__toggle--open"

                      else
                        ""
                    ]
                , Attr.attribute "aria-hidden" "true"
                , Internal.onClickStop (rc.toMsg (ToggleOpen rc.env entry.key))
                ]
                [ Icon.view Icon.chevronRight ]

          else
            Html.span [ Internal.cls [ "klar-tree-select__spacer" ] ] []
        , if data.multiple then
            Html.span [ Internal.cls [ "klar-select__checkbox" ], Attr.attribute "aria-hidden" "true" ]
                [ Checkbox.view
                    [ Checkbox.checked (state == Checked)
                    , Checkbox.indeterminate (state == Partial)
                    , Checkbox.disabled entry.disabled
                    ]
                ]

          else
            Html.text ""
        , Internal.viewMaybe (\icon -> Html.span [ Internal.cls [ "klar-select__option-icon" ] ] [ Icon.view icon ]) (Picking.icon node)
        , Html.span [ Internal.cls [ "klar-select__option-label" ] ] (Search.highlight searchText entry.label)
        , Internal.viewMaybe
            (\description ->
                Html.span [ Internal.cls [ "klar-select__option-description" ] ] (Search.highlight descriptionQuery description)
            )
            (Picking.description node)
        ]
