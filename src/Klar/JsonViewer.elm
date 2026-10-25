module Klar.JsonViewer exposing
    ( view
    , State, init, Msg, update
    , isExpanded, expand, collapse, toggle, expandAll, collapseAll, expandedIds, setExpandedIds, path
    , Attribute, toolbar, rootLabel, ariaLabel, maxHeight, maxDepth, maxItems, maxStringLength, locale
    )

{-| A collapsible tree for looking at JSON: an API response, a stored document,
a request body.

Use when: the application shows a JSON value, such as an API response or a stored document, that the user needs to explore.
Do not use when: a short snippet is enough (`codeBlock` of `Klar.Text`); or the value is still on its way, put the viewer inside `Klar.RemoteView`.
Quick path: `init`, `update`, `view`

    import Json.Decode as Decode
    import Klar.JsonViewer as JsonViewer

    -- in your model
    { response : Decode.Value
    , viewer : JsonViewer.State -- JsonViewer.init "response-viewer"
    }

    -- in update
    ViewerMsg viewerMsg ->
        let
            ( viewer, cmd ) =
                JsonViewer.update viewerMsg model.viewer
        in
        ( { model | viewer = viewer }, Cmd.map ViewerMsg cmd )

    -- in view
    JsonViewer.view ViewerMsg
        [ JsonViewer.toolbar, JsonViewer.rootLabel "response" ]
        model.viewer
        model.response

The value is a `Json.Decode.Value`, for example the result of decoding a
response with `Json.Decode.value`. The viewer decodes it into a small tree of
its own (object, array, string, number, boolean, null) on every render, so the
value can change freely between renders. Keys are blue and values have muted
colors. Long strings are cut, with the start of the whole text in a tooltip, and
an object or array with more than `maxItems` entries shows the first rows and a
"Show 100 more" row. Thin gray lines follow the indentation.

The state remembers which nodes the user opened or closed, as paths like
`/users/0/address` (the root is the empty path; `path` writes one for you). By
default the root and its children are open.

The viewer is an ARIA tree (`role="tree"`, `treeitem`, `group`, `aria-expanded`,
`aria-level`) with one tab stop. The arrow keys move between the rows: Down and Up
to the next and previous row, Right opens a node (or goes to its first child),
Left closes it (or goes to its parent), Home and End to the first and the last
row, and Enter or Space opens and closes a node or shows more rows. The row that
had the focus keeps it when the value changes, as long as it is still there.

There is no copy button: copying takes JavaScript, and the text of every row,
keys included, is selectable. For a short snippet that does not need exploring,
`codeBlock` of [Klar.Text](Klar-Text) is simpler.

The value is shown as Elm decodes it: a number goes through a `Float`, so an
integer beyond 2^53 is rounded and `1.10` is written `1.1`, and the browser puts
keys that look like integers first. For an inspector that must show the text the
server sent byte for byte, show that text with `codeBlock` instead.


# View

@docs view


# State

@docs State, init, Msg, update


# Opening and closing

@docs isExpanded, expand, collapse, toggle, expandAll, collapseAll, expandedIds, setExpandedIds, path


# Attributes

@docs Attribute, toolbar, rootLabel, ariaLabel, maxHeight, maxDepth, maxItems, maxStringLength, locale

-}

import Array
import Dict exposing (Dict)
import Html exposing (Html)
import Html.Attributes as Attr
import Html.Events as Events
import Html.Keyed as Keyed
import Json.Decode as Decode exposing (Decoder, Value)
import Json.Encode as Encode
import Klar.Button as Button
import Klar.Format as Format
import Klar.Icon as Icon
import Klar.Internal as Internal
import Klar.Locale as Locale exposing (Locale)
import Set exposing (Set)



-- TREE


type Node
    = JObject (List ( String, Node ))
    | JArray (List Node)
    | JString String
    | JNumber Float
    | JBool Bool
    | JNull


nodeDecoder : Decoder Node
nodeDecoder =
    Decode.oneOf
        [ Decode.map JString Decode.string
        , Decode.map JNumber Decode.float
        , Decode.map JBool Decode.bool
        , Decode.null JNull
        , Decode.map JArray (Decode.list (Decode.lazy (\_ -> nodeDecoder)))
        , Decode.map JObject (Decode.keyValuePairs (Decode.lazy (\_ -> nodeDecoder)))
        ]



-- STATE


{-| What the viewer remembers: which nodes the user opened or closed, and how
many extra rows of long objects and arrays were revealed. Make one with `init`,
keep it in your model and give it to `view` and `update`.
-}
type State
    = State
        { id : String
        , openDepth : Int
        , flipped : Set String
        , revealed : Dict String Int

        -- the row that is the tab stop: a path, or "+" and a path for the
        -- "Show more" row of that node
        , focused : Maybe String

        -- the long strings that are shown in full
        , fullStrings : Set String
        }


{-| A state with the first two levels open: the root and its direct children.
The `String` is the DOM id of the viewer and the prefix of the ids of its
buttons, so it must be unique on the page.

    JsonViewer.init "response-viewer"

-}
init : String -> State
init id =
    State { id = id, openDepth = 2, flipped = Set.empty, revealed = Dict.empty, focused = Nothing, fullStrings = Set.empty }


{-| Is the node at this path open? The root is `""`, a child of the root is
`"/name"` and an array item is `"/items/0"`. In a key, `~` is written `~0` and
`/` is written `~1`, as in JSON Pointer; `path` does that for you.
-}
isExpanded : String -> State -> Bool
isExpanded at (State state) =
    openAt state.openDepth state.flipped at (pathDepth at)


{-| The path of a node, from the keys and array positions that lead to it, with
`~` and `/` in a key written as JSON Pointer wants them.

    JsonViewer.path [ "items", "3", "error" ] -- "/items/3/error"

    JsonViewer.path [ "a/b" ] -- "/a~1b"

    JsonViewer.path [] -- "", the root

-}
path : List String -> String
path names =
    List.foldl (\name parent -> pathOf parent name) "" names


{-| Opens the node at this path and every node above it, so that it can be seen.
Nothing else changes.

    JsonViewer.expand (JsonViewer.path [ "items", "3", "error" ]) state

-}
expand : String -> State -> State
expand at (State state) =
    let
        ancestors =
            ancestorsOf at

        openOne p flipped =
            if openAt state.openDepth flipped p (pathDepth p) then
                flipped

            else if Set.member p flipped then
                Set.remove p flipped

            else
                Set.insert p flipped
    in
    State { state | flipped = List.foldl openOne state.flipped (ancestors ++ [ at ]) }


{-| Closes the node at this path. Nothing else changes.
-}
collapse : String -> State -> State
collapse at ((State state) as current) =
    if isExpanded at current then
        toggle at current

    else
        State state


{-| The paths above a node, from the root down: `"/a/b/c"` has `""`, `"/a"` and
`"/a/b"`.
-}
ancestorsOf : String -> List String
ancestorsOf at =
    let
        parts =
            String.split "/" at |> List.drop 1
    in
    List.range 0 (List.length parts - 1)
        |> List.map (\n -> List.take n parts |> List.map (\part -> "/" ++ part) |> String.concat)


openAt : Int -> Set String -> String -> Int -> Bool
openAt openDepth flipped at depth =
    (depth < openDepth) /= Set.member at flipped


pathDepth : String -> Int
pathDepth at =
    if at == "" then
        0

    else
        List.length (String.indexes "/" at)


{-| Opens exactly these nodes and closes all others. Include the root (`""`) if
it should stay open; use `expand` to open a deep node with everything above it.

    JsonViewer.setExpandedIds [ "", "/items" ] state

-}
setExpandedIds : List String -> State -> State
setExpandedIds paths (State state) =
    State { state | openDepth = 0, flipped = Set.fromList paths, revealed = state.revealed }


{-| The paths of the open objects and arrays of this value, in document order:
what to keep when the application stores the view, and to give back with
`setExpandedIds`. The value is needed because a fresh state opens nodes by their
depth (the first two levels, after `init`; every level, after `expandAll`) rather
than by name. A node inside a closed one counts if it is open itself, as with
`isExpanded`.

    JsonViewer.setExpandedIds (JsonViewer.expandedIds value state) state -- the same view

-}
expandedIds : Value -> State -> List String
expandedIds value (State state) =
    let
        walk at depth node =
            case node of
                JObject fields ->
                    openHere at depth
                        ++ List.concatMap (\( key, child ) -> walk (pathOf at key) (depth + 1) child) fields

                JArray items ->
                    openHere at depth
                        ++ List.concat (List.indexedMap (\i child -> walk (pathOf at (String.fromInt i)) (depth + 1) child) items)

                _ ->
                    []

        openHere at depth =
            if openAt state.openDepth state.flipped at depth then
                [ at ]

            else
                []
    in
    case Decode.decodeValue nodeDecoder value of
        Ok node ->
            walk "" 0 node

        Err _ ->
            []


{-| Opens every node. This is what the "Expand all" button of the `toolbar`
does.
-}
expandAll : State -> State
expandAll (State state) =
    State { state | openDepth = 1000, flipped = Set.empty }


{-| Closes every node except the root. This is what the "Collapse all" button of
the `toolbar` does.
-}
collapseAll : State -> State
collapseAll (State state) =
    State { state | openDepth = 1, flipped = Set.empty }


{-| Opens the node at this path (see `isExpanded`) if it is closed and closes it
if it is open.
-}
toggle : String -> State -> State
toggle at (State state) =
    State
        { state
            | flipped =
                if Set.member at state.flipped then
                    Set.remove at state.flipped

                else
                    Set.insert at state.flipped
        }


{-| The messages of the viewer. Wrap them in a message of your own, give them to
`update` and use the same wrapper in `view`.
-}
type Msg
    = Toggle String
    | ExpandAll
    | CollapseAll
    | ShowMore String Int Int
    | FocusRow String
    | Focused String
    | ToggleString String
    | Noop


{-| Handles opening and closing, the arrow keys, "expand all", "collapse all" and
"show more". Moving with the keys and "show more" return a command that puts the
focus on a row, so map the command with `Cmd.map`.
-}
update : Msg -> State -> ( State, Cmd Msg )
update msg ((State state) as current) =
    case msg of
        Toggle at ->
            let
                (State toggled) =
                    toggle at current
            in
            ( State { toggled | focused = Just at }, Cmd.none )

        ExpandAll ->
            ( expandAll current, Cmd.none )

        CollapseAll ->
            ( collapseAll current, Cmd.none )

        ShowMore at step remaining ->
            -- The rows that appear push the row that was pressed down, and the
            -- browser drops the focus of an element that is moved. Put it back;
            -- when nothing is left to show, the row is gone and the focus goes
            -- to the node that was opened up.
            let
                target =
                    if remaining > 0 then
                        "+" ++ at

                    else
                        at
            in
            ( State
                { state
                    | revealed =
                        Dict.update at (\count -> Just (Maybe.withDefault 0 count + step)) state.revealed
                    , focused = Just target
                }
            , Internal.focus (rowDomId state.id target) Noop
            )

        FocusRow key ->
            ( State { state | focused = Just key }, Internal.focus (rowDomId state.id key) Noop )

        Focused key ->
            ( State { state | focused = Just key }, Cmd.none )

        ToggleString at ->
            ( State
                { state
                    | fullStrings =
                        if Set.member at state.fullStrings then
                            Set.remove at state.fullStrings

                        else
                            Set.insert at state.fullStrings
                    , focused = Just at
                }
            , Cmd.none
            )

        Noop ->
            ( current, Cmd.none )


{-| The DOM id of a row: a node by its path, a "Show more" row by "+" and the path
of its node.
-}
rowDomId : String -> String -> String
rowDomId viewerId key =
    if String.startsWith "+" key then
        domId viewerId "more" (String.dropLeft 1 key)

    else
        domId viewerId "row" key


{-| A DOM id for a button of the node at `path`: letters and digits stay, every
other character becomes `_` + its code point + `_`.
-}
domId : String -> String -> String -> String
domId viewerId kind at =
    viewerId
        ++ "-"
        ++ kind
        ++ "-"
        ++ (at
                |> String.toList
                |> List.map
                    (\c ->
                        if Char.isAlphaNum c && Char.toCode c < 128 then
                            String.fromChar c

                        else
                            "_" ++ String.fromInt (Char.toCode c) ++ "_"
                    )
                |> String.concat
           )



-- ATTRIBUTES


{-| A setting of the viewer. Make them with the functions below and pass a list
to `view`; later attributes win over earlier ones.
-}
type Attribute msg
    = Attribute (Config -> Config)


type alias Config =
    { toolbar : Bool
    , rootLabel : Maybe String
    , maxDepth : Int
    , maxItems : Int
    , maxStringLength : Int
    , maxHeight : Maybe Int
    , ariaLabel : Maybe String
    , locale : Locale
    }


configure : List (Attribute msg) -> Config
configure attributes =
    List.foldl (\(Attribute change) config -> change config)
        { toolbar = False
        , rootLabel = Nothing
        , maxDepth = 12
        , maxItems = 100
        , maxStringLength = 140
        , maxHeight = Nothing
        , ariaLabel = Nothing
        , locale = Locale.default
        }
        attributes


{-| Shows "Expand all" and "Collapse all" buttons above the tree. There is no
toolbar by default.
-}
toolbar : Attribute msg
toolbar =
    Attribute (\config -> { config | toolbar = True })


{-| A name for the root node, shown as its key: `"response": { ... }`.
-}
rootLabel : String -> Attribute msg
rootLabel text =
    Attribute (\config -> { config | rootLabel = Just text })


{-| Objects and arrays nested deeper than this are shown as `{ ... }` or
`[ ... ]` and cannot be opened. The default is 12, and the value is kept between
1 and 100.
-}
maxDepth : Int -> Attribute msg
maxDepth n =
    Attribute (\config -> { config | maxDepth = clamp 1 100 n })


{-| How many entries of one object or array are shown before a "Show N more"
row. The default is 100, and the value is kept between 5 and 5000.
-}
maxItems : Int -> Attribute msg
maxItems n =
    Attribute (\config -> { config | maxItems = clamp 5 5000 n })


{-| Strings longer than this many characters are cut and end in "...", followed
by "Show all": a click on it, or Enter on the row, shows the whole string. The
tooltip has the start of the whole string (at most 4000 characters). The default
is 140, and the value is kept between 10 and 5000.
-}
maxStringLength : Int -> Attribute msg
maxStringLength n =
    Attribute (\config -> { config | maxStringLength = clamp 10 5000 n })


{-| Scrolls inside the viewer when the tree gets taller than this many pixels.
By default the viewer grows with its content. The keyboard scrolls it by moving
from row to row: the row with the focus is always scrolled into view.
-}
maxHeight : Int -> Attribute msg
maxHeight pixels =
    Attribute (\config -> { config | maxHeight = Just pixels })


{-| The accessible name of the tree, for example "API response". The default is
"JSON". Give one when the page has more than one viewer.
-}
ariaLabel : String -> Attribute msg
ariaLabel text =
    Attribute (\config -> { config | ariaLabel = Just text })


{-| The language of the built-in text: the toolbar buttons, the "Show N more"
row, the counts of keys and items, and the messages. The default is
`Locale.default`, which is English.
-}
locale : Locale -> Attribute msg
locale value =
    Attribute (\config -> { config | locale = value })



-- TEXT


type alias Texts =
    { expandAll : String
    , collapseAll : String
    , key : Int -> String
    , item : Int -> String
    , showMore : Int -> String
    , cannotShow : String
    , tooDeep : String
    , json : String
    , showAll : String
    , showLess : String
    }


texts : Locale -> Texts
texts loc =
    let
        pick nb en =
            Locale.pick loc { nb = nb, en = en }
    in
    { expandAll = pick "Utvid alle" "Expand all"
    , collapseAll = pick "Skjul alle" "Collapse all"
    , key = \n -> Format.int loc n ++ " " ++ Format.plural loc n { one = pick "nøkkel" "key", other = pick "nøkler" "keys" }
    , item = \n -> Format.int loc n ++ " " ++ Format.plural loc n { one = pick "element" "item", other = pick "elementer" "items" }
    , showMore = \n -> pick ("Vis " ++ Format.int loc n ++ " flere") ("Show " ++ Format.int loc n ++ " more")
    , cannotShow = pick "Verdien kan ikke vises." "The value cannot be shown."
    , tooDeep = pick "for dypt til å vises" "too deep to show"
    , json = "JSON"
    , showAll = pick "Vis alt" "Show all"
    , showLess = pick "Vis mindre" "Show less"
    }



-- VIEW


type alias Context msg =
    { toMsg : Msg -> msg
    , state : State
    , config : Config
    , t : Texts

    -- the key of the row that is the tab stop
    , stop : String
    }


{-| Shows a JSON value as a collapsible tree. The first argument wraps the
viewer's messages in one of yours. The state remembers what is open and which row
has the focus; the value can change freely between renders. A value that cannot
be shown at all gives a short message instead ("The value cannot be shown." in
English).
-}
view : (Msg -> msg) -> List (Attribute msg) -> State -> Value -> Html msg
view toMsg attributes ((State state) as current) value =
    let
        config =
            configure attributes

        t =
            texts config.locale
    in
    case Decode.decodeValue nodeDecoder value of
        Err _ ->
            Html.div [ Internal.cls [ "klar-json", "klar-json--error" ], Attr.attribute "role" "alert" ] [ Html.text t.cannotShow ]

        Ok root ->
            let
                rows =
                    rowsOf config state "" 0 Nothing root

                -- The row that had the focus stays the tab stop while it is
                -- there; otherwise the first row is.
                stop =
                    case state.focused of
                        Just key ->
                            if List.any (\row -> row.key == key) rows then
                                key

                            else
                                ""

                        Nothing ->
                            ""

                context =
                    { toMsg = toMsg, state = current, config = config, t = t, stop = stop }
            in
            Html.div
                [ Internal.cls [ "klar-json" ]
                , Attr.id state.id
                ]
                [ if config.toolbar then
                    Html.div [ Internal.cls [ "klar-json__toolbar" ] ]
                        [ Button.view [ Button.small, Button.ghost, Button.icon Icon.maximize, Button.onClick (toMsg ExpandAll) ] t.expandAll
                        , Button.view [ Button.small, Button.ghost, Button.icon Icon.minimize, Button.onClick (toMsg CollapseAll) ] t.collapseAll
                        ]

                  else
                    Html.text ""
                , Html.div
                    [ Internal.cls [ "klar-json__scroll" ]
                    , case config.maxHeight of
                        Just pixels ->
                            Internal.styleVars [ ( "max-height", Internal.px pixels ) ]

                        Nothing ->
                            Internal.noAttr
                    ]
                    [ Html.ul
                        [ Internal.cls [ "klar-json__tree" ]
                        , Attr.attribute "role" "tree"
                        , Attr.attribute "aria-label" (Maybe.withDefault t.json config.ariaLabel)
                        , keyHandler toMsg state.id rows
                        ]
                        [ viewNode context "" 0 (Maybe.map (\label -> ( label, False )) config.rootLabel) True root ]
                    ]
                ]



-- KEYBOARD


{-| A visible row of the tree, in the order they are shown.
-}
type alias Row =
    { key : String
    , parent : Maybe String
    , firstChild : Maybe String
    , expandable : Bool
    , open : Bool
    , showMore : Maybe Msg
    }


{-| The rows that are shown, in order: the same walk as `viewNode`.
-}
rowsOf :
    Config
    -> { r | openDepth : Int, flipped : Set String, revealed : Dict String Int }
    -> String
    -> Int
    -> Maybe String
    -> Node
    -> List Row
rowsOf config state at depth parent node =
    let
        leaf =
            [ { key = at, parent = parent, firstChild = Nothing, expandable = False, open = False, showMore = Nothing } ]

        container children =
            let
                count =
                    List.length children
            in
            if count == 0 || depth >= config.maxDepth then
                leaf

            else if not (openAt state.openDepth state.flipped at depth) then
                [ { key = at, parent = parent, firstChild = Nothing, expandable = True, open = False, showMore = Nothing } ]

            else
                let
                    limit =
                        config.maxItems + (Dict.get at state.revealed |> Maybe.withDefault 0)

                    shown =
                        List.take limit children

                    hiddenCount =
                        count - List.length shown

                    step =
                        min hiddenCount config.maxItems
                in
                { key = at
                , parent = parent
                , firstChild = List.head shown |> Maybe.map Tuple.first
                , expandable = True
                , open = True
                , showMore = Nothing
                }
                    :: List.concatMap (\( childPath, child ) -> rowsOf config state childPath (depth + 1) (Just at) child) shown
                    ++ (if hiddenCount > 0 then
                            [ { key = "+" ++ at
                              , parent = Just at
                              , firstChild = Nothing
                              , expandable = False
                              , open = False
                              , showMore = Just (ShowMore at step (hiddenCount - step))
                              }
                            ]

                        else
                            []
                       )
    in
    case node of
        JObject members ->
            container (List.map (\( name, child ) -> ( pathOf at name, child )) members)

        JArray items ->
            container (List.indexedMap (\i child -> ( pathOf at (String.fromInt i), child )) items)

        JString text ->
            if String.length text > config.maxStringLength then
                [ { key = at, parent = parent, firstChild = Nothing, expandable = False, open = False, showMore = Just (ToggleString at) } ]

            else
                leaf

        _ ->
            leaf


{-| The keys of the row with this key (a path, or "+" and a path). Keys that lead nowhere (Up on the
first row) still do nothing, so that they never scroll the page.
-}
keyBindings : List Row -> String -> List ( String, Msg )
keyBindings rows stop =
    let
        keys =
            Array.fromList (List.map .key rows)

        index =
            rows
                |> List.indexedMap (\i row -> ( row.key, i ))
                |> List.filter (\( key, _ ) -> key == stop)
                |> List.head
                |> Maybe.map Tuple.second
                |> Maybe.withDefault 0

        current =
            List.drop index rows |> List.head

        go i =
            Array.get i keys |> Maybe.map FocusRow |> Maybe.withDefault Noop

        activate =
            case current of
                Just row ->
                    case row.showMore of
                        Just more ->
                            more

                        Nothing ->
                            if row.expandable then
                                Toggle row.key

                            else
                                Noop

                Nothing ->
                    Noop
    in
    [ ( "ArrowDown", go (index + 1) )
    , ( "ArrowUp", go (index - 1) )
    , ( "Home", go 0 )
    , ( "End", go (Array.length keys - 1) )
    , ( "ArrowRight"
      , case current of
            Just row ->
                if row.expandable && not row.open then
                    Toggle row.key

                else
                    Maybe.map FocusRow row.firstChild |> Maybe.withDefault Noop

            Nothing ->
                Noop
      )
    , ( "ArrowLeft"
      , case current of
            Just row ->
                if row.expandable && row.open then
                    Toggle row.key

                else
                    Maybe.map FocusRow row.parent |> Maybe.withDefault Noop

            Nothing ->
                Noop
      )
    , ( "Enter", activate )
    , ( " ", activate )
    ]


{-| One key handler on the tree. It acts for the row the key press came from (its
DOM id), not for the stored tab stop, so two presses before the next render (a
held arrow key, a key right after a click) each start from their own row. It only
takes key presses on a row, without Ctrl, Alt or Meta.
-}
keyHandler : (Msg -> msg) -> String -> List Row -> Html.Attribute msg
keyHandler toMsg viewerId rows =
    Events.preventDefaultOn "keydown"
        (Decode.map2 Tuple.pair (Decode.at [ "target", "id" ] Decode.string) Internal.keyEvent
            |> Decode.andThen
                (\( targetId, event ) ->
                    case List.filter (\row -> rowDomId viewerId row.key == targetId) rows |> List.head of
                        Just row ->
                            if event.ctrl || event.meta || event.alt then
                                Decode.fail "not a key of the tree"

                            else
                                case List.filter (\( key, _ ) -> key == event.key) (keyBindings rows row.key) |> List.head of
                                    Just ( _, msg ) ->
                                        Decode.succeed ( toMsg msg, True )

                                    Nothing ->
                                        Decode.fail "unhandled key"

                        Nothing ->
                            Decode.fail "not a row of the tree"
                )
        )


{-| The attributes that make an element a row of the tree: its id, its level, and
whether it is the one tab stop.
-}
rowAttributes : Context msg -> String -> Int -> List (Html.Attribute msg)
rowAttributes context key depth =
    let
        (State state) =
            context.state
    in
    [ Attr.id (rowDomId state.id key)
    , Attr.attribute "role" "treeitem"
    , Attr.attribute "aria-level" (String.fromInt (depth + 1))
    , Attr.tabindex
        (if key == context.stop then
            0

         else
            -1
        )
    , Events.on "focus" (Decode.succeed (context.toMsg (Focused key)))
    ]


{-| One row, or one container with its children. The key is `Just (text,
isIndex)` for object members and array items.
-}
viewNode : Context msg -> String -> Int -> Maybe ( String, Bool ) -> Bool -> Node -> Html msg
viewNode context at depth key isLast node =
    let
        comma =
            if isLast then
                Html.text ""

            else
                Html.span [ Internal.cls [ "klar-json__punct" ] ] [ Html.text "," ]

        keyView =
            case key of
                Just ( text, True ) ->
                    Html.span [ Internal.cls [ "klar-json__index" ] ] [ Html.text text ]

                Just ( text, False ) ->
                    Html.span [ Internal.cls [ "klar-json__key" ] ] [ Html.text (Encode.encode 0 (Encode.string text)) ]

                Nothing ->
                    Html.text ""

        colon =
            case key of
                Just _ ->
                    Html.span [ Internal.cls [ "klar-json__punct" ] ] [ Html.text ": " ]

                Nothing ->
                    Html.text ""

        scalar content =
            Html.li (Internal.cls [ "klar-json__row" ] :: rowAttributes context at depth)
                [ keyView, colon, content, comma ]
    in
    case node of
        JString text ->
            let
                (State state) =
                    context.state
            in
            scalar (viewString context at (Set.member at state.fullStrings) text)

        JNumber number ->
            scalar (Html.span [ Internal.cls [ "klar-json__number" ] ] [ Html.text (numberText number) ])

        JBool flag ->
            scalar
                (Html.span [ Internal.cls [ "klar-json__boolean" ] ]
                    [ Html.text
                        (if flag then
                            "true"

                         else
                            "false"
                        )
                    ]
                )

        JNull ->
            scalar (Html.span [ Internal.cls [ "klar-json__null" ] ] [ Html.text "null" ])

        JObject members ->
            viewContainer context
                at
                depth
                keyView
                colon
                comma
                { open = "{"
                , close = "}"
                , count = List.length members
                , summary = context.t.key (List.length members)
                , preview = members |> List.map Tuple.first |> previewKeys
                }
                (List.map (\( name, child ) -> ( pathOf at name, Just ( name, False ), child )) members)

        JArray items ->
            viewContainer context
                at
                depth
                keyView
                colon
                comma
                { open = "["
                , close = "]"
                , count = List.length items
                , summary = context.t.item (List.length items)
                , preview = ""
                }
                (List.indexedMap (\i child -> ( pathOf at (String.fromInt i), Just ( String.fromInt i, True ), child )) items)


type alias Brackets =
    { open : String
    , close : String
    , count : Int
    , summary : String
    , preview : String
    }


viewContainer :
    Context msg
    -> String
    -> Int
    -> Html msg
    -> Html msg
    -> Html msg
    -> Brackets
    -> List ( String, Maybe ( String, Bool ), Node )
    -> Html msg
viewContainer context at depth keyView colon comma brackets children =
    let
        (State state) =
            context.state

        isOpen =
            openAt state.openDepth state.flipped at depth

        tooDeep =
            depth >= context.config.maxDepth

        punct text =
            Html.span [ Internal.cls [ "klar-json__punct" ] ] [ Html.text text ]
    in
    if brackets.count == 0 then
        Html.li (Internal.cls [ "klar-json__row" ] :: rowAttributes context at depth)
            [ keyView, colon, punct (brackets.open ++ brackets.close), comma ]

    else if tooDeep then
        Html.li (Internal.cls [ "klar-json__row" ] :: rowAttributes context at depth)
            [ keyView
            , colon
            , punct (brackets.open ++ " ")
            , Html.span [ Internal.cls [ "klar-json__hint" ], Attr.title context.t.tooDeep, Attr.attribute "aria-hidden" "true" ] [ Html.text "..." ]
            , Html.span [ Internal.cls [ "klar-sr-only" ] ] [ Html.text context.t.tooDeep ]
            , punct (" " ++ brackets.close)
            , comma
            ]

    else
        let
            revealed =
                Dict.get at state.revealed |> Maybe.withDefault 0

            limit =
                context.config.maxItems + revealed

            shown =
                List.take limit children

            shownCount =
                List.length shown

            lastShown =
                shownCount - 1

            hiddenCount =
                List.length children - shownCount

            step =
                min hiddenCount context.config.maxItems
        in
        Html.li
            ([ Internal.cls
                [ "klar-json__node"
                , if isOpen then
                    "klar-json__node--open"

                  else
                    ""
                ]
             , Attr.attribute "aria-expanded"
                (if isOpen then
                    "true"

                 else
                    "false"
                )

             -- The name of a node is its own line, not the text of its children.
             , Attr.attribute "aria-labelledby" (domId state.id "name" at)
             ]
                ++ rowAttributes context at depth
            )
            ([ -- A click opens and closes; the keys are on the row itself.
               Html.span
                [ Internal.cls [ "klar-json__toggle" ]
                , Events.onClick (context.toMsg (Toggle at))
                ]
                [ Html.span [ Internal.cls [ "klar-json__chevron" ], Attr.attribute "aria-hidden" "true" ] [ Icon.sized Icon.ExtraSmall Icon.chevronRight ]
                , Html.span [ Internal.cls [ "klar-json__text" ], Attr.id (domId state.id "name" at) ]
                    ([ keyView
                     , colon
                     , punct brackets.open
                     ]
                        ++ (if isOpen then
                                [ Html.span [ Internal.cls [ "klar-json__summary" ] ] [ Html.text brackets.summary ] ]

                            else
                                [ Html.span [ Internal.cls [ "klar-json__hint" ] ]
                                    [ Html.text
                                        (if brackets.preview == "" then
                                            " ... "

                                         else
                                            " " ++ brackets.preview ++ " "
                                        )
                                    ]
                                , punct brackets.close
                                , Html.span [ Internal.cls [ "klar-json__summary" ] ] [ Html.text brackets.summary ]
                                , comma
                                ]
                           )
                    )
                ]
             ]
                ++ (if isOpen then
                        [ Keyed.ul [ Internal.cls [ "klar-json__children" ], Attr.attribute "role" "group" ]
                            (List.indexedMap
                                (\i ( childPath, childKey, child ) ->
                                    ( childPath
                                    , viewNode context childPath (depth + 1) childKey (i == lastShown && hiddenCount == 0) child
                                    )
                                )
                                shown
                                ++ (if hiddenCount > 0 then
                                        [ ( "more"
                                          , Html.li (Internal.cls [ "klar-json__row", "klar-json__row--more" ] :: rowAttributes context ("+" ++ at) (depth + 1))
                                                [ Html.span
                                                    [ Internal.cls [ "klar-json__more" ]
                                                    , Events.onClick (context.toMsg (ShowMore at step (hiddenCount - step)))
                                                    ]
                                                    [ Html.text
                                                        (if step == hiddenCount then
                                                            context.t.showMore step

                                                         else
                                                            context.t.showMore step ++ " (" ++ Format.int context.config.locale hiddenCount ++ ")"
                                                        )
                                                    ]
                                                ]
                                          )
                                        ]

                                    else
                                        []
                                   )
                            )
                        , Html.div [ Internal.cls [ "klar-json__close" ] ] [ punct brackets.close, comma ]
                        ]

                    else
                        []
                   )
            )


{-| A string. A long one is cut, with "Show all" after it: a click on it, or Enter
on its row, shows the whole string (and "Show less" cuts it again).
-}
viewString : Context msg -> String -> Bool -> String -> Html msg
viewString context at full text =
    let
        config =
            context.config

        tooLong =
            String.length text > config.maxStringLength

        cut =
            tooLong && not full

        shown =
            if cut then
                safeLeft config.maxStringLength text ++ "..."

            else
                text

        encoded =
            Encode.encode 0 (Encode.string shown)
    in
    Html.span []
        [ Html.span
            ([ Internal.cls
                [ "klar-json__string"
                , if cut then
                    "klar-json__string--cut"

                  else
                    ""
                ]
             ]
                ++ (if cut then
                        [ Attr.title (safeLeft 4000 text) ]

                    else
                        []
                   )
            )
            [ Html.text encoded ]
        , if tooLong then
            -- Not a button: the row is the control (Enter), this is for the mouse.
            Html.span
                [ Internal.cls [ "klar-json__expand" ]
                , Events.onClick (context.toMsg (ToggleString at))
                ]
                [ Html.text
                    (if full then
                        context.t.showLess

                     else
                        context.t.showAll
                    )
                ]

          else
            Html.text ""
        ]


{-| `String.left` counts UTF-16 units: a cut must not leave the first half of an
emoji (a surrogate pair) at the end.
-}
safeLeft : Int -> String -> String
safeLeft count text =
    let
        cut =
            String.left count text

        lastChar =
            String.foldr
                (\c found ->
                    case found of
                        Nothing ->
                            Just c

                        Just _ ->
                            found
                )
                Nothing
                cut
    in
    case lastChar of
        Just c ->
            if Char.toCode c >= 0xD800 && Char.toCode c <= 0xDBFF then
                String.dropRight 1 cut

            else
                cut

        Nothing ->
            cut


numberText : Float -> String
numberText number =
    if isNaN number || isInfinite number then
        "null"

    else
        String.fromFloat number


{-| `{ id, name, status, ... }`: the first keys of a collapsed object.
-}
previewKeys : List String -> String
previewKeys names =
    let
        take =
            names |> List.take 4 |> String.join ", "

        more =
            if List.length names > 4 || String.length take > 48 then
                ", ..."

            else
                ""
    in
    (if String.length take > 48 then
        String.left 48 take

     else
        take
    )
        ++ more


pathOf : String -> String -> String
pathOf parent name =
    parent
        ++ "/"
        ++ (name
                |> String.replace "~" "~0"
                |> String.replace "/" "~1"
           )
