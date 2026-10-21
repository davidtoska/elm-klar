module Klar.JsonViewer exposing
    ( view
    , State, init, Msg, update
    , isExpanded, toggle, expandAll, collapseAll, setExpanded
    , Attribute, toolbar, rootLabel, ariaLabel, maxHeight, maxDepth, maxItems, maxStringLength, locale
    )

{-| A collapsible tree for looking at JSON: an API response, a stored document,
a request body.

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
`/users/0/address` (the root is the empty path). By default the root and its
children are open. Every toggle is a real button with `aria-expanded`, so the
keyboard works with `Tab` and `Enter`. The tree is a nested list of buttons, not
an ARIA tree, so the arrow keys do not move between nodes.

There is no copy button: copying takes JavaScript, and the text is selectable.
For a short snippet that does not need exploring, `codeBlock` of
[Klar.Text](Klar-Text) is simpler.


# View

@docs view


# State

@docs State, init, Msg, update


# Opening and closing

@docs isExpanded, toggle, expandAll, collapseAll, setExpanded


# Attributes

@docs Attribute, toolbar, rootLabel, ariaLabel, maxHeight, maxDepth, maxItems, maxStringLength, locale

-}

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
        }


{-| A state with the first two levels open: the root and its direct children.
The `String` is the DOM id of the viewer and the prefix of the ids of its
buttons, so it must be unique on the page.

    JsonViewer.init "response-viewer"

-}
init : String -> State
init id =
    State { id = id, openDepth = 2, flipped = Set.empty, revealed = Dict.empty }


{-| Is the node at this path open? The root is `""`, a child of the root is
`"/name"` and an array item is `"/items/0"`. In a key, `~` is written `~0` and
`/` is written `~1`, as in JSON Pointer.
-}
isExpanded : String -> State -> Bool
isExpanded path (State state) =
    openAt state.openDepth state.flipped path (pathDepth path)


openAt : Int -> Set String -> String -> Int -> Bool
openAt openDepth flipped path depth =
    (depth < openDepth) /= Set.member path flipped


pathDepth : String -> Int
pathDepth path =
    if path == "" then
        0

    else
        List.length (String.indexes "/" path)


{-| Opens exactly these nodes and closes all others. Include the root (`""`) if
it should stay open.

    JsonViewer.setExpanded [ "", "/items" ] state

-}
setExpanded : List String -> State -> State
setExpanded paths (State state) =
    State { state | openDepth = 0, flipped = Set.fromList paths, revealed = state.revealed }


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
toggle path (State state) =
    State
        { state
            | flipped =
                if Set.member path state.flipped then
                    Set.remove path state.flipped

                else
                    Set.insert path state.flipped
        }


{-| The messages of the viewer. Wrap them in a message of your own, give them to
`update` and use the same wrapper in `view`.
-}
type Msg
    = Toggle String
    | ExpandAll
    | CollapseAll
    | ShowMore String Int Int
    | Noop


{-| Handles opening and closing, "expand all", "collapse all" and "show more".
After "show more" it returns a command that puts the focus back on a button, so
map the command with `Cmd.map`.
-}
update : Msg -> State -> ( State, Cmd Msg )
update msg ((State state) as current) =
    case msg of
        Toggle path ->
            ( toggle path current, Cmd.none )

        ExpandAll ->
            ( expandAll current, Cmd.none )

        CollapseAll ->
            ( collapseAll current, Cmd.none )

        ShowMore path step remaining ->
            -- The rows that appear push the button that was pressed down, and
            -- the browser drops the focus of an element that is moved. Put it
            -- back; when nothing is left to show, the button is gone and the
            -- focus goes to the node that was opened up.
            ( State
                { state
                    | revealed =
                        Dict.update path (\count -> Just (Maybe.withDefault 0 count + step)) state.revealed
                }
            , Internal.focus
                (domId state.id
                    (if remaining > 0 then
                        "more"

                     else
                        "toggle"
                    )
                    path
                )
                Noop
            )

        Noop ->
            ( current, Cmd.none )


{-| A DOM id for a button of the node at `path`: letters and digits stay, every
other character becomes `_` + its code point + `_`.
-}
domId : String -> String -> String -> String
domId viewerId kind path =
    viewerId
        ++ "-"
        ++ kind
        ++ "-"
        ++ (path
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
type Attribute
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


configure : List Attribute -> Config
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
toolbar : Attribute
toolbar =
    Attribute (\config -> { config | toolbar = True })


{-| A name for the root node, shown as its key: `"response": { ... }`.
-}
rootLabel : String -> Attribute
rootLabel text =
    Attribute (\config -> { config | rootLabel = Just text })


{-| Objects and arrays nested deeper than this are shown as `{ ... }` or
`[ ... ]` and cannot be opened. The default is 12, and the value is kept between
1 and 100.
-}
maxDepth : Int -> Attribute
maxDepth n =
    Attribute (\config -> { config | maxDepth = clamp 1 100 n })


{-| How many entries of one object or array are shown before a "Show N more"
row. The default is 100, and the value is kept between 5 and 5000.
-}
maxItems : Int -> Attribute
maxItems n =
    Attribute (\config -> { config | maxItems = clamp 5 5000 n })


{-| Strings longer than this many characters are cut and end in "...". The
tooltip has the start of the whole string (at most 4000 characters). The default
is 140, and the value is kept between 10 and 5000.
-}
maxStringLength : Int -> Attribute
maxStringLength n =
    Attribute (\config -> { config | maxStringLength = clamp 10 5000 n })


{-| Scrolls inside the viewer when the tree gets taller than this many pixels.
By default the viewer grows with its content.

A scrolling viewer can take the keyboard focus (`tabindex="0"`), so that
keyboard users can scroll it with the arrow keys. With an `ariaLabel` the scroll
area is also a `region` with that name.

-}
maxHeight : Int -> Attribute
maxHeight pixels =
    Attribute (\config -> { config | maxHeight = Just pixels })


{-| The accessible name of the tree, for example "API response". Give one when
nothing near the viewer names it. In a viewer with a `maxHeight` the name goes to
the scroll area as well, which then is a `region`.
-}
ariaLabel : String -> Attribute
ariaLabel text =
    Attribute (\config -> { config | ariaLabel = Just text })


{-| The language of the built-in text: the toolbar buttons, the "Show N more"
row, the counts of keys and items, and the messages. The default is
`Locale.default`, which is English.
-}
locale : Locale -> Attribute
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
    }



-- VIEW


type alias Context msg =
    { toMsg : Msg -> msg
    , state : State
    , config : Config
    , t : Texts
    }


{-| Shows a JSON value as a collapsible tree. The first argument wraps the
viewer's messages in one of yours. The state remembers what is open; the value
can change freely between renders. A value that cannot be shown at all gives a
short message instead ("The value cannot be shown." in English).
-}
view : (Msg -> msg) -> List Attribute -> State -> Value -> Html msg
view toMsg attributes ((State state) as current) value =
    let
        config =
            configure attributes

        t =
            texts config.locale

        context =
            { toMsg = toMsg, state = current, config = config, t = t }

        -- With a `maxHeight` the tree scrolls, and a scroll area must be
        -- reachable with the keyboard. A scroll area with a name is a region.
        scrolls =
            config.maxHeight /= Nothing
    in
    case Decode.decodeValue nodeDecoder value of
        Err _ ->
            Html.div [ Internal.cls [ "klar-json", "klar-json--error" ], Attr.attribute "role" "alert" ] [ Html.text t.cannotShow ]

        Ok root ->
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
                    , Internal.attrIf scrolls (Attr.tabindex 0)
                    , Internal.attrIf (scrolls && config.ariaLabel /= Nothing) (Attr.attribute "role" "region")
                    , Internal.attrIf scrolls (Internal.attrMaybe (Attr.attribute "aria-label") config.ariaLabel)
                    ]
                    [ -- A nested list of buttons, not an ARIA tree: the keys are
                      -- Tab and Enter, not the arrow keys a tree promises.
                      Html.ul
                        [ Internal.cls [ "klar-json__tree" ]
                        , Internal.attrMaybe (Attr.attribute "aria-label") config.ariaLabel
                        ]
                        [ viewNode context "" 0 (Maybe.map (\label -> ( label, False )) config.rootLabel) True root ]
                    ]
                ]


{-| One row, or one container with its children. The key is `Just (text,
isIndex)` for object members and array items.
-}
viewNode : Context msg -> String -> Int -> Maybe ( String, Bool ) -> Bool -> Node -> Html msg
viewNode context path depth key isLast node =
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
            Html.li [ Internal.cls [ "klar-json__row" ] ]
                [ keyView, colon, content, comma ]
    in
    case node of
        JString text ->
            scalar (viewString context.config text)

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
                path
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
                (List.map (\( name, child ) -> ( pathOf path name, Just ( name, False ), child )) members)

        JArray items ->
            viewContainer context
                path
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
                (List.indexedMap (\i child -> ( pathOf path (String.fromInt i), Just ( String.fromInt i, True ), child )) items)


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
viewContainer context path depth keyView colon comma brackets children =
    let
        (State state) =
            context.state

        isOpen =
            openAt state.openDepth state.flipped path depth

        tooDeep =
            depth >= context.config.maxDepth

        punct text =
            Html.span [ Internal.cls [ "klar-json__punct" ] ] [ Html.text text ]
    in
    if brackets.count == 0 then
        Html.li [ Internal.cls [ "klar-json__row" ] ]
            [ keyView, colon, punct (brackets.open ++ brackets.close), comma ]

    else if tooDeep then
        Html.li [ Internal.cls [ "klar-json__row" ] ]
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
                Dict.get path state.revealed |> Maybe.withDefault 0

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

            togglePath =
                path
        in
        Html.li
            [ Internal.cls
                [ "klar-json__node"
                , if isOpen then
                    "klar-json__node--open"

                  else
                    ""
                ]
            ]
            ([ Html.button
                [ Internal.cls [ "klar-json__toggle" ]
                , Attr.type_ "button"
                , Attr.id (domId state.id "toggle" path)
                , Attr.attribute "aria-expanded"
                    (if isOpen then
                        "true"

                     else
                        "false"
                    )
                , Events.onClick (context.toMsg (Toggle togglePath))
                ]
                [ Html.span [ Internal.cls [ "klar-json__chevron" ] ] [ Icon.sized Icon.ExtraSmall Icon.chevronRight ]
                , Html.span [ Internal.cls [ "klar-json__text" ] ]
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
                        [ Keyed.ul [ Internal.cls [ "klar-json__children" ] ]
                            (List.indexedMap
                                (\i ( childPath, childKey, child ) ->
                                    ( String.fromInt i ++ "|" ++ childPath
                                    , viewNode context childPath (depth + 1) childKey (i == lastShown && hiddenCount == 0) child
                                    )
                                )
                                shown
                                ++ (if hiddenCount > 0 then
                                        [ ( "more"
                                          , Html.li [ Internal.cls [ "klar-json__row", "klar-json__row--more" ] ]
                                                [ Html.button
                                                    [ Internal.cls [ "klar-json__more" ]
                                                    , Attr.type_ "button"
                                                    , Attr.id (domId state.id "more" path)
                                                    , Events.onClick (context.toMsg (ShowMore path step (hiddenCount - step)))
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


viewString : Config -> String -> Html msg
viewString config text =
    let
        tooLong =
            String.length text > config.maxStringLength

        shown =
            if tooLong then
                safeLeft config.maxStringLength text ++ "..."

            else
                text

        encoded =
            Encode.encode 0 (Encode.string shown)
    in
    Html.span
        ([ Internal.cls
            [ "klar-json__string"
            , if tooLong then
                "klar-json__string--cut"

              else
                ""
            ]
         ]
            ++ (if tooLong then
                    [ Attr.title (safeLeft 4000 text) ]

                else
                    []
               )
        )
        [ Html.text encoded ]


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
