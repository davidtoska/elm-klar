module Klar.VirtualList exposing
    ( State, init, Msg, update, view, viewGrouped
    , id, scrollTop
    , Attribute, rowHeight, height, overscan, htmlAttrs
    , Geometry, ensureVisible, center, scrollTo, reset, viewportHeight
    )

{-| A scrolling list that renders only the rows that are visible, plus a few
above and below, so lists with thousands of rows stay fast. Every row has the
same fixed height. The rows that are not rendered are replaced by two spacer
elements, so the scrollbar keeps the right size.

[Klar.Select](Klar-Select), [Klar.MultiSelect](Klar-MultiSelect) and
[Klar.Autocomplete](Klar-Autocomplete) draw their options with it. Use it
directly for a long, plain list of equal rows of your own; for records that
people search, sort and act on, see [Klar.Table](Klar-Table).

    import Array exposing (Array)
    import Klar.VirtualList as VirtualList

    -- model: { orders : Array Order, list : VirtualList.State }
    init =
        { orders = Array.fromList allOrders
        , list = VirtualList.init "order-list"
        }

    -- update
    ListMsg inner ->
        let
            ( list, cmd ) =
                VirtualList.update inner model.list
        in
        ( { model | list = list }, Cmd.map ListMsg cmd )

    -- view
    VirtualList.view ListMsg
        [ VirtualList.rowHeight 32, VirtualList.height 320 ]
        { items = model.orders, viewRow = viewOrder }
        model.list

    viewOrder : Int -> Order -> Html msg
    viewOrder _ order =
        Html.div [ Attr.style "height" "32px" ] [ Html.text order.number ]

The row function receives the absolute index and the item. The element it
returns must be exactly `rowHeight` pixels high, which the row has to make sure
of itself. Use `viewGrouped` when some rows are section headings: the heading of
the section at the top stays pinned while the rows below it scroll.

The state holds the scroll offset, which the list reports on every scroll
through the message you give to `view`. The list has no keyboard handling or
selection of its own: the component that owns it handles the keys and calls
`ensureVisible` to keep the active row on screen. That works out the new offset
from the row heights, without measuring the page, so the right rows are rendered
in the same frame.

Rows that are not rendered are not on the page, so a list that has a `role`
should tell assistive technology how many rows there are: give every row
`aria-posinset` and `aria-setsize`, as the select components do. Add the `role`
and the other attributes with `htmlAttrs`.


# State

@docs State, init, Msg, update, view, viewGrouped


# Reading the state

@docs id, scrollTop


# Attributes

@docs Attribute, rowHeight, height, overscan, htmlAttrs


# Scrolling

@docs Geometry, ensureVisible, center, scrollTo, reset, viewportHeight

-}

import Array exposing (Array)
import Browser.Dom as Dom
import Html exposing (Html)
import Html.Attributes as Attr
import Html.Events as Events
import Json.Decode as Decode
import Klar.Internal as Internal
import Task



-- STATE


{-| What one virtual list keeps track of: the DOM id of its scrolling element and
its scroll offset. Make it with `init`, keep it in your model and pass it to
`view` and `update`.
-}
type State
    = State
        { id : String
        , top : Float
        }


{-| A list scrolled to the top. The `String` is the DOM id of the scrolling
element and must be unique on the page: the scrolling commands find the element
by it.

    VirtualList.init "order-list"

-}
init : String -> State
init domId =
    State { id = domId, top = 0 }


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


{-| The messages a virtual list sends; it reports every scroll. Wrap it in a
constructor of your own message type (`ListMsg VirtualList.Msg`), give that
constructor to `view`, and pass the messages you get back to `update`.
-}
type Msg
    = Scrolled Float
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
    , extra : List (Html.Attribute msg)
    }


configure : List (Attribute msg) -> Config msg
configure attributes =
    List.foldl (\(Attribute change) config -> change config)
        { rowHeight = 32
        , height = 320
        , overscan = 6
        , extra = []
        }
        attributes


{-| The height of every row in pixels (at least 1). The default is 32, the
`--klar-option-h` token. The rows that `viewRow` returns must be exactly this
high.
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


{-| The list. `toMsg` wraps the scroll messages into your own message type,
`items` are all the rows (an `Array`, so that the visible slice is cheap to take)
and `viewRow` turns the absolute index of a row and its item into HTML that is
exactly `rowHeight` pixels high.

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
