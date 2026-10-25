module Klar.VirtualList exposing
    ( State, init, Msg, update, list
    , id, scrollTop, active, reveal
    , Attribute, density, onSelect, selected, height, htmlAttrs
    , view, viewGrouped, rowHeight, overscan
    , Geometry, ensureVisible, center, scrollTo, reset, viewportHeight, isDrawn
    )

{-| A list of thousands of rows that draws only the rows in view, and is a
list box for the keyboard.

Use when: a long, plain list of equal rows that people scan and pick from, such as a search result or 50 000 products.
Do not use when: the records have columns to sort, filter and compare (`Klar.Table` with `virtual`) or the list is short (`Klar.ListItem`).
Quick path: `init`, `update`, `list`, `active`

Use it for a long, plain list of equal rows that people scan and pick from: a
search result, an inbox, 50 000 products. For records with columns that people
sort, filter and compare, use [Klar.Table](Klar-Table) with `virtual`; for a short
list of things to open, [Klar.ListItem](Klar-ListItem).

    import Array exposing (Array)
    import Klar.ListItem as ListItem
    import Klar.VirtualList as VirtualList

    -- model: { orders : Array Order, picked : Maybe Int, list : VirtualList.State }
    init =
        { orders = Array.fromList allOrders
        , picked = Nothing
        , list = VirtualList.init "order-list"
        }

    -- update
    ListMsg inner ->
        let
            ( list, cmd ) =
                VirtualList.update inner model.list
        in
        ( { model | list = list }, Cmd.map ListMsg cmd )

    OrderPicked index ->
        ( { model | picked = Just index }, Cmd.none )

    -- view
    VirtualList.list ListMsg
        [ VirtualList.onSelect OrderPicked, VirtualList.selected model.picked ]
        { label = "Orders", items = model.orders, viewRow = viewOrder }
        model.list

    viewOrder : Order -> Html msg
    viewOrder order =
        ListItem.content [ ListItem.secondary order.customer, ListItem.meta order.date ] order.number

The list owns its rows: it makes the `ul` and the `li` of every row, gives every row
the same height (from the `density`, so you never write a height or a style) and
tells assistive technology which row of how many it is, although only the rows in
view are on the page. `viewRow` only says what is inside a row, and the content
should not be a button or a link, because the row itself is what is clicked.

**Keyboard.** With `onSelect` the list is a list box and one tab stop, not one for
every row: Tab reaches it, ArrowDown and ArrowUp move the active row, Home and End
go to the first and the last, PageDown and PageUp move by a screenful, and Enter
or Space picks the active row. The active row is marked and scrolled into view.
Without `onSelect` the list is just a scrolling list, and the keys scroll it.

The state holds the scroll offset and the active row, and reports every scroll
through the message you give to `list`. Read the active row with `active`, and
bring a row into view with `reveal` (for example the `selected` row, 40 000 rows
down, when the list is shown).

Components that draw their own rows (the options of [Klar.Select](Klar-Select)) use
the low-level `view` instead, where each row is a `div` of your own that must be
exactly `rowHeight` pixels high and the component handles the keys itself.


# State

@docs State, init, Msg, update, list


# Reading the state

@docs id, scrollTop, active, reveal


# Attributes

@docs Attribute, density, onSelect, selected, height, htmlAttrs


# Rows of your own

`view` and `viewGrouped` draw a list whose rows you make yourself. Every row must
be exactly `rowHeight` pixels high and the list has no keyboard handling of its own:
the component that owns it handles the keys and calls `ensureVisible` to keep the
active row on screen, which works out the new offset from the row heights, without
measuring the page, so that the right rows are drawn in the same frame. A list with a
`role` should tell assistive technology how many rows there are: give every row
`aria-posinset` and `aria-setsize`, as the select components do, and point
`aria-activedescendant` only at a row that `isDrawn`. Add the `role` and the other
attributes with `htmlAttrs`.

@docs view, viewGrouped, rowHeight, overscan


# Scrolling

@docs Geometry, ensureVisible, center, scrollTo, reset, viewportHeight, isDrawn

-}

import Array exposing (Array)
import Browser.Dom as Dom
import Html exposing (Html)
import Html.Attributes as Attr
import Html.Events as Events
import Html.Keyed
import Json.Decode as Decode exposing (Decoder)
import Klar.Internal as Internal
import Klar.Internal.Window as Window
import Klar.Theme exposing (Density(..))
import Task



-- STATE


{-| What one virtual list keeps track of: the DOM id of its scrolling element, its
scroll offset and the active row. Make it with `init`, keep it in your model and
pass it to `list` and `update`.
-}
type State
    = State
        { id : String
        , top : Float
        , active : Maybe Int
        }


{-| A list scrolled to the top. The `String` is the DOM id of the scrolling
element and must be unique on the page: the scrolling commands find the element
by it.

    VirtualList.init "order-list"

-}
init : String -> State
init domId =
    State { id = domId, top = 0, active = Nothing }


{-| The DOM id of the scrolling element, as given to `init`.
-}
id : State -> String
id (State state) =
    state.id


{-| The current scroll offset in pixels, as last reported by the browser or set
by `scrollTo`, `ensureVisible` and `center`.
-}
scrollTop : State -> Float
scrollTop (State state) =
    state.top


{-| The row (counting from 0) that the keyboard is on, or that the user last
pressed with the mouse. `Nothing` until the user has moved or pressed. A list with
`onSelect` shows it as the active row; it starts on the `selected` row, or the first.
-}
active : State -> Maybe Int
active (State state) =
    state.active


{-| Scrolls a `list` so that row `row` (counting from 0) is in view, to the middle
of the list when it was out of view, and makes it the active row, so the keys go on
from there. Give it the attributes and the number of rows you give `list`: the
height of the rows comes from the same `density`, so there is no height to repeat.
Use it when a list opens on its `selected` row, or to show a row the application
found. Like `scrollTo`, it needs the list on the page by the time the command runs.

    ShowOrder index ->
        let
            ( list, cmd ) =
                VirtualList.reveal listAttributes { row = index, count = Array.length model.orders } model.list
        in
        ( { model | list = list }, Cmd.map ListMsg cmd )

-}
reveal : List (Attribute msg) -> { row : Int, count : Int } -> State -> ( State, Cmd Msg )
reveal attributes target (State state) =
    if target.count <= 0 then
        ( State state, Cmd.none )

    else
        let
            config =
                configure attributes

            rowH =
                listRowHeight config.density

            geometry =
                { rowHeight = rowH, height = config.height, count = target.count, inset = 0 }

            index =
                clamp 0 (target.count - 1) target.row

            top =
                clampTop geometry state.top

            rowTop =
                toFloat (index * rowH)

            inView =
                rowTop >= top && rowTop + toFloat rowH <= top + toFloat (viewportHeight geometry)

            withActive =
                State { state | active = Just index }
        in
        if inView then
            ( withActive, Cmd.none )

        else
            center geometry index withActive


{-| The messages a virtual list sends; it reports every scroll. Wrap it in a
constructor of your own message type (`ListMsg VirtualList.Msg`), give that
constructor to `view`, and pass the messages you get back to `update`.
-}
type Msg
    = Scrolled Float
    | Moved Int Geometry
    | Pointed Int
    | NoOp


{-| Handles a message of the list by storing the scroll offset. Like every
`update` of the package it returns a command, which you map into your own
message type with `Cmd.map`.

    ListMsg inner ->
        let
            ( list, cmd ) =
                VirtualList.update inner model.list
        in
        ( { model | list = list }, Cmd.map ListMsg cmd )

-}
update : Msg -> State -> ( State, Cmd Msg )
update msg (State state) =
    case msg of
        Scrolled top ->
            ( State { state | top = top }, Cmd.none )

        Moved index geometry ->
            ensureVisible geometry index (State { state | active = Just index })

        Pointed index ->
            ( State { state | active = Just index }, Cmd.none )

        NoOp ->
            ( State state, Cmd.none )


{-| Goes back to the top without touching the page. Use it when the list
element is about to be created again, such as a popup that opens: the new
element starts at the top, and the state has to agree.
-}
reset : State -> State
reset (State state) =
    State { state | top = 0 }


{-| Scrolls to an offset in pixels (a negative offset counts as 0). The offset is
stored at once, and the command scrolls the element, which has to be on the page
by then.
-}
scrollTo : Float -> State -> ( State, Cmd Msg )
scrollTo top (State state) =
    let
        target =
            max 0 top
    in
    ( State { state | top = target }
    , Dom.setViewportOf state.id 0 target |> Task.attempt (\_ -> NoOp)
    )


{-| What the scroll helpers need to know about a list, the same numbers you give
to `view`: `rowHeight` is the height of a row in pixels, `height` the maximum
height of the list, `count` the number of rows, and `inset` the number of pixels
at the top that are covered by a pinned heading (see `viewGrouped`), else 0.
-}
type alias Geometry =
    { rowHeight : Int
    , height : Int
    , count : Int
    , inset : Int
    }


{-| Scrolls as little as possible so that row `index` (counting from 0) is fully
visible, for example the row a keyboard user has just moved to. The new offset is
known right away, so the rows around it are rendered in the same frame.

    VirtualList.ensureVisible
        { rowHeight = 32, height = 320, count = 500, inset = 0 }
        42
        model.list

-}
ensureVisible : Geometry -> Int -> State -> ( State, Cmd Msg )
ensureVisible geometry index ((State state) as current) =
    let
        rowH =
            toFloat (max 1 geometry.rowHeight)

        viewport =
            toFloat (viewportHeight geometry)

        inset =
            toFloat geometry.inset

        top =
            clampTop geometry state.top

        rowTop =
            toFloat index * rowH

        rowBottom =
            rowTop + rowH

        next =
            if rowTop < top + inset then
                rowTop - inset

            else if rowBottom > top + viewport then
                rowBottom - viewport

            else
                top
    in
    if clampTop geometry next == state.top then
        ( current, Cmd.none )

    else
        scrollTo (clampTop geometry next) current


{-| Scrolls so that row `index` (counting from 0) is in the middle of the list,
as far as the ends of the list allow. The select components use it when the list
opens on the chosen option. Like `scrollTo`, it needs the element on the page by
the time the command runs.
-}
center : Geometry -> Int -> State -> ( State, Cmd Msg )
center geometry index current =
    let
        rowH =
            max 1 geometry.rowHeight

        target =
            toFloat (index * rowH) - toFloat (viewportHeight geometry - rowH) / 2
    in
    scrollTo (clampTop geometry target) current


{-| The height in pixels that the list takes: the height of all rows, but at most
`height`. It works on a `Geometry` or any record with these three fields.

    VirtualList.viewportHeight { rowHeight = 32, height = 320, count = 3 } --> 96

-}
viewportHeight : { a | rowHeight : Int, height : Int, count : Int } -> Int
viewportHeight geometry =
    min geometry.height (geometry.count * max 1 geometry.rowHeight)


{-| Whether row `index` (counting from 0) is in view now, and so on the page
whatever the `overscan`: `view` and `viewGrouped` draw the rows in view and a few
around them, so after the user scrolled away with the wheel a row the keyboard was
on may be gone. The answer is safe rather than exact: a row drawn only as part of
the overscan counts as not drawn. Point `aria-activedescendant` at a row only
while this is `True`, since an id that is not on the page names nothing. Give it
the same numbers as `view`.

    VirtualList.isDrawn { rowHeight = 32, height = 320, count = 500, inset = 0 } 42 model.list

-}
isDrawn : Geometry -> Int -> State -> Bool
isDrawn geometry index (State state) =
    let
        rowH =
            max 1 geometry.rowHeight

        top =
            clampTop geometry state.top

        -- the same arithmetic as `render`, without the overscan rows, which
        -- `render` always adds on both sides
        firstVisible =
            floor (top / toFloat rowH)

        visible =
            ceiling (toFloat (viewportHeight geometry) / toFloat rowH) + 1
    in
    index >= firstVisible && index < min geometry.count (firstVisible + visible)


clampTop : Geometry -> Float -> Float
clampTop geometry top =
    let
        maxTop =
            geometry.count * max 1 geometry.rowHeight - viewportHeight geometry
    in
    clamp 0 (toFloat (max 0 maxTop)) top



-- ATTRIBUTES


{-| A setting of a virtual list. Make them with the functions below and pass a
list to `view` or `viewGrouped`; later attributes win over earlier ones, except
that `htmlAttrs` adds up.
-}
type Attribute msg
    = Attribute (Config msg -> Config msg)


type alias Config msg =
    { rowHeight : Int
    , height : Int
    , overscan : Int
    , density : Density
    , onSelect : Maybe (Int -> msg)
    , selected : Maybe Int
    , extra : List (Html.Attribute msg)
    }


configure : List (Attribute msg) -> Config msg
configure attributes =
    List.foldl (\(Attribute change) config -> change config)
        { rowHeight = 32
        , height = 320
        , overscan = 6
        , density = Normal
        , onSelect = Nothing
        , selected = Nothing
        , extra = []
        }
        attributes


{-| The height of every row in pixels (at least 1), for `view` and `viewGrouped`.
The default is 32, the `--klar-option-h` token. The rows that `viewRow` returns must
be exactly this high. `list` takes the height of its rows from the `density`.
-}
rowHeight : Int -> Attribute msg
rowHeight px =
    Attribute (\config -> { config | rowHeight = max 1 px })


{-| The maximum height of the list in pixels. The default is 320. A list with
fewer rows is only as high as its rows.
-}
height : Int -> Attribute msg
height px =
    Attribute (\config -> { config | height = max 0 px })


{-| How many rows are rendered above and below the visible ones. The default is
6, so that fast scrolling does not show empty space.
-}
overscan : Int -> Attribute msg
overscan rows =
    Attribute (\config -> { config | overscan = max 0 rows })


{-| The height of the rows of a `list`: `Compact` 32 pixels, `Normal` 44 (the
default, the height of a `ListItem.content` row with a second line) or
`Comfortable` 56. A row is exactly this high, and what does not fit is cut.
-}
density : Density -> Attribute msg
density value =
    Attribute (\config -> { config | density = value })


{-| Makes a `list` a list box that the keyboard moves through, and says what to
tell when the user picks a row (clicks it, or presses Enter or Space on the active
row). The message gets the number of the row, counting from 0, in the `Array` you
gave to `list`.
-}
onSelect : (Int -> msg) -> Attribute msg
onSelect toMsg =
    Attribute (\config -> { config | onSelect = Just toMsg })


{-| The row that is picked now (it is marked, and is where the active row starts), or
`Nothing`. The list does not keep it: you set it from the message of `onSelect`.
-}
selected : Maybe Int -> Attribute msg
selected value =
    Attribute (\config -> { config | selected = value })


{-| Extra attributes for the scrolling element: a `role`, `aria-*` attributes,
key handlers, an extra class. They are added to the ones the list sets itself,
and using `htmlAttrs` more than once adds all of them.

    VirtualList.htmlAttrs
        [ Attr.attribute "role" "listbox"
        , Attr.attribute "aria-label" "Orders"
        ]

-}
htmlAttrs : List (Html.Attribute msg) -> Attribute msg
htmlAttrs value =
    Attribute (\config -> { config | extra = config.extra ++ value })



-- VIEW


{-| A list whose rows you make yourself, for a component that draws its own
options (see "Rows of your own" above; for a list of records, use `list`).
`toMsg` wraps the scroll messages into your own message type, `items` are all the
rows (an `Array`, so that the visible slice is cheap to take) and `viewRow` turns the
absolute index of a row and its item into HTML that is exactly `rowHeight` pixels high.

    VirtualList.view ListMsg
        [ VirtualList.rowHeight 32, VirtualList.height 320 ]
        { items = model.orders, viewRow = viewOrder }
        model.list

-}
view :
    (Msg -> msg)
    -> List (Attribute msg)
    -> { items : Array a, viewRow : Int -> a -> Html msg }
    -> State
    -> Html msg
view toMsg attributes rows state =
    render toMsg (configure attributes) rows.items rows.viewRow Nothing state


{-| Like `view`, for lists with section headings. `viewHeader` returns the
pinned version of a heading row (and `Nothing` for ordinary rows); it is shown
on top of the list for the section the first visible row belongs to. Give the
pinned copy no `id`: it is a visual duplicate, hidden from screen readers.

    VirtualList.viewGrouped ListMsg
        [ VirtualList.rowHeight 32 ]
        { items = model.rows
        , viewRow = viewRow
        , viewHeader = pinnedHeading
        }
        model.list

    pinnedHeading : Row -> Maybe (Html msg)
    pinnedHeading row =
        case row of
            Heading name ->
                Just (Html.div [] [ Html.text name ])

            Item _ ->
                Nothing

-}
viewGrouped :
    (Msg -> msg)
    -> List (Attribute msg)
    -> { items : Array a, viewRow : Int -> a -> Html msg, viewHeader : a -> Maybe (Html msg) }
    -> State
    -> Html msg
viewGrouped toMsg attributes rows state =
    render toMsg (configure attributes) rows.items rows.viewRow (Just rows.viewHeader) state


{-| The list: `ul` and `li` of its own, a height from the `density`, the window of
rows in view, and the keys of a list box when there is an `onSelect`. `toMsg` wraps
the list's messages into your own message type, `label` names the list for screen
readers, `items` are all the rows (an `Array`, so that the slice in view is cheap to
take) and `viewRow` makes what is inside one row.

    VirtualList.list ListMsg
        [ VirtualList.onSelect OrderPicked ]
        { label = "Orders", items = model.orders, viewRow = viewOrder }
        model.list

-}
list :
    (Msg -> msg)
    -> List (Attribute msg)
    -> { label : String, items : Array a, viewRow : a -> Html msg }
    -> State
    -> Html msg
list toMsg attributes rows (State state) =
    let
        config =
            configure attributes

        rowH =
            listRowHeight config.density

        count =
            Array.length rows.items

        geometry =
            { rowHeight = rowH, height = config.height, count = count, inset = 0 }

        viewport =
            viewportHeight geometry

        drawn =
            Window.window { overscan = config.overscan, chunk = 1 }
                { rowHeight = rowH, viewport = viewport, count = count }
                state.top

        picks =
            config.onSelect

        -- the row the keys are on: the one the user moved to, the picked one, or the first
        cursor =
            case picks of
                Just _ ->
                    if count == 0 then
                        Nothing

                    else
                        Just (clamp 0 (count - 1) (Maybe.withDefault 0 (firstOf state.active config.selected)))

                Nothing ->
                    Nothing

        rowDomId index =
            state.id ++ "-row-" ++ String.fromInt index

        viewItem index item =
            ( "row-" ++ String.fromInt index
            , Html.li
                ([ Internal.cls
                    [ "klar-vlist__item"
                    , if cursor == Just index then
                        "klar-vlist__item--active"

                      else
                        ""
                    , if config.selected == Just index then
                        "klar-vlist__item--selected"

                      else
                        ""
                    ]
                 , Attr.id (rowDomId index)
                 , Attr.attribute "aria-posinset" (String.fromInt (index + 1))
                 , Attr.attribute "aria-setsize" (String.fromInt count)
                 ]
                    ++ (case picks of
                            Just pick ->
                                [ Attr.attribute "role" "option"
                                , Attr.attribute "aria-selected"
                                    (if config.selected == Just index then
                                        "true"

                                     else
                                        "false"
                                    )
                                , Events.onMouseDown (toMsg (Pointed index))
                                , Events.onClick (pick index)
                                ]

                            Nothing ->
                                []
                       )
                )
                [ rows.viewRow item ]
            )

        shown =
            Array.slice drawn.first drawn.end rows.items
                |> Array.toIndexedList
                |> List.map (\( offset, item ) -> viewItem (drawn.first + offset) item)

        room place pixels =
            if pixels <= 0 then
                []

            else
                [ ( "room-" ++ place
                  , Html.li
                        [ Internal.cls [ "klar-vlist__spacer" ]
                        , Internal.styleVars [ ( "height", Internal.px pixels ) ]
                        , Attr.attribute "role" "presentation"
                        , Attr.attribute "aria-hidden" "true"
                        ]
                        []
                  )
                ]
    in
    Html.Keyed.node "ul"
        ([ Internal.cls
            [ "klar-vlist"
            , "klar-vlist--list"
            , if picks == Nothing then
                ""

              else
                "klar-vlist--interactive"
            ]
         , Attr.id state.id
         , Attr.tabindex 0
         , Attr.attribute "aria-label" rows.label
         , Internal.styleVars
            [ ( "height", Internal.px viewport )
            , ( "--klar-vlist-row", Internal.px rowH )
            ]
         , Events.on "scroll" (Decode.map (Scrolled >> toMsg) (Decode.at [ "target", "scrollTop" ] Decode.float))
         ]
            ++ (case ( picks, cursor ) of
                    ( Just pick, Just current ) ->
                        [ Attr.attribute "role" "listbox"
                        , -- the active row is always drawn when the keys move to it, but not
                          -- when the list was scrolled away from it by the wheel
                          Internal.attrIf (current >= drawn.first && current < drawn.end)
                            (Attr.attribute "aria-activedescendant" (rowDomId current))
                        , Events.preventDefaultOn "keydown" (listKeys toMsg pick current geometry)
                        ]

                    ( Just _, Nothing ) ->
                        [ Attr.attribute "role" "listbox" ]

                    _ ->
                        []
               )
            ++ config.extra
        )
        (room "top" drawn.before ++ shown ++ room "bottom" drawn.after)


firstOf : Maybe a -> Maybe a -> Maybe a
firstOf first second =
    case first of
        Just _ ->
            first

        Nothing ->
            second


{-| The height of a row of a `list` for a density.
-}
listRowHeight : Density -> Int
listRowHeight spacing =
    case spacing of
        Compact ->
            32

        Normal ->
            44

        Comfortable ->
            56


{-| The keys of a list box: they move the active row, or pick it. Keys with Ctrl,
Cmd or Alt are the browser's.
-}
listKeys : (Msg -> msg) -> (Int -> msg) -> Int -> Geometry -> Decoder ( msg, Bool )
listKeys toMsg pick current geometry =
    let
        last =
            geometry.count - 1

        page =
            Window.rowsPerScreen { rowHeight = geometry.rowHeight, viewport = viewportHeight geometry, count = geometry.count }

        moveTo index =
            Decode.succeed ( toMsg (Moved (clamp 0 last index) geometry), True )
    in
    Decode.map2 Tuple.pair
        (Decode.field "key" Decode.string)
        (Decode.map3 (\ctrl meta alt -> ctrl || meta || alt)
            (Decode.field "ctrlKey" Decode.bool)
            (Decode.field "metaKey" Decode.bool)
            (Decode.field "altKey" Decode.bool)
        )
        |> Decode.andThen
            (\( key, modified ) ->
                if modified then
                    Decode.fail "a key of the browser"

                else
                    case key of
                        "ArrowDown" ->
                            moveTo (current + 1)

                        "ArrowUp" ->
                            moveTo (current - 1)

                        "Home" ->
                            moveTo 0

                        "End" ->
                            moveTo last

                        "PageDown" ->
                            moveTo (current + page)

                        "PageUp" ->
                            moveTo (current - page)

                        "Enter" ->
                            Decode.succeed ( pick current, True )

                        " " ->
                            Decode.succeed ( pick current, True )

                        _ ->
                            Decode.fail "not a key of the list"
            )


render :
    (Msg -> msg)
    -> Config msg
    -> Array a
    -> (Int -> a -> Html msg)
    -> Maybe (a -> Maybe (Html msg))
    -> State
    -> Html msg
render toMsg config items viewRow viewHeader (State state) =
    let
        count =
            Array.length items

        geometry =
            { rowHeight = config.rowHeight, height = config.height, count = count, inset = 0 }

        viewport =
            viewportHeight geometry

        top =
            clampTop geometry state.top

        first =
            floor (top / toFloat config.rowHeight)

        visible =
            ceiling (toFloat viewport / toFloat config.rowHeight) + 1

        start =
            max 0 (first - config.overscan)

        end =
            min count (first + visible + config.overscan)

        rendered =
            Array.slice start end items
                |> Array.toIndexedList
                |> List.map (\( offset, item ) -> viewRow (start + offset) item)

        pinned =
            case viewHeader of
                Just toHeader ->
                    findHeader toHeader items first

                Nothing ->
                    Nothing
    in
    Html.div
        ([ Internal.cls [ "klar-vlist" ]
         , Attr.id state.id
         , Attr.tabindex -1
         , Internal.styleVars
            [ ( "height", Internal.px viewport )
            , ( "--klar-vlist-row", Internal.px config.rowHeight )
            ]
         , Events.on "scroll" (Decode.map (Scrolled >> toMsg) (Decode.at [ "target", "scrollTop" ] Decode.float))
         ]
            ++ config.extra
        )
        (Html.div
            [ Internal.cls
                [ "klar-vlist__pinned"
                , if pinned == Nothing then
                    ""

                  else
                    "klar-vlist__pinned--active"
                ]
            , Attr.attribute "aria-hidden" "true"
            ]
            [ Maybe.withDefault (Html.text "") pinned ]
            :: spacer (start * config.rowHeight)
            :: rendered
            ++ [ spacer ((count - end) * config.rowHeight) ]
        )


spacer : Int -> Html msg
spacer px =
    Html.div
        [ Internal.cls [ "klar-vlist__spacer" ]
        , Internal.styleVars [ ( "height", Internal.px px ) ]
        , Attr.attribute "aria-hidden" "true"
        ]
        []


{-| The heading of the section that row `index` belongs to: the nearest
heading row at or above it.
-}
findHeader : (a -> Maybe (Html msg)) -> Array a -> Int -> Maybe (Html msg)
findHeader toHeader items index =
    if index < 0 then
        Nothing

    else
        case Array.get index items |> Maybe.andThen toHeader of
            Just header ->
                Just header

            Nothing ->
                findHeader toHeader items (index - 1)
