module Klar.Splitter exposing
    ( view, Pane, pane, minSize, maxSize, minPixels, maxPixels, collapsible
    , State, Msg, init, update, sizes, setSizes, isDragging
    , Share, percent, toPercent
    , Attribute, stacked, height, fillRest, locale
    )

{-| Two or more panes side by side (or one above the other) that the user can make
larger and smaller by moving the separators between them, with the mouse, a finger
or the keyboard.

Use when: the user should resize a master and its detail, a navigator beside a work area or an editor above a preview.
Do not use when: the layout is fixed, use `Klar.Layout`, or when sections only open and close, use `Klar.Accordion`.
Quick path: `init`, `update`, `view`, `sizes`

    import Klar.Splitter as Splitter

    -- model: split : Splitter.State
    -- init:  Splitter.init "orders-split" [ Splitter.percent 35, Splitter.percent 65 ]

    -- update
    SplitterMsg m ->
        let
            ( split, cmd ) =
                Splitter.update m model.split
        in
        ( { model | split = split }, Cmd.map SplitterMsg cmd )

    -- view
    Splitter.view SplitterMsg
        [ Splitter.height 420 ]
        model.split
        [ Splitter.pane "Orders" (viewOrderList model) |> Splitter.minPixels 240
        , Splitter.pane "Details" (viewOrderDetail model) |> Splitter.minPixels 320
        ]

Use it for a master and its detail, a navigator beside a work area, an editor above
a preview. Panes can hold another splitter. For a page with a fixed layout that the
user does not change, use [Klar.Layout](Klar-Layout); for sections that open and
close, [Klar.Accordion](Klar-Accordion).

The state keeps the sizes, as shares of the room the panes have together (the
width of the container without the separators), from 0 to 100 percent, always
adding up to 100. Shares, not pixels, are kept, so a layout follows the window when
it is resized. Read them with `sizes` and give them back with `setSizes` to save and
restore the layout of the user. The number of sizes should be the number of panes;
when it is not (a detail pane that comes and goes), the panes that have no size get
an equal share and the others keep their proportions. Panes are matched by place:
the first pane is the first size.

Each pane has a name, which names its separator for screen readers ("Resize
Orders"). A pane can have a smallest and a largest size, in percent of the room or in
pixels, and can be `collapsible`. The panes scroll inside themselves when their
content is larger than they are; a pane that has nothing in it that can take the focus
is scrolled with the keyboard in current Chrome and Firefox, which make a scrolling
box focusable, but not in every browser, so give such a pane a button or a link if it
matters. The container needs a height (give the parent one, or use `height`).

Keyboard: a separator is a tab stop. `Left` and `Right` move it by 1 percent (`Up`
and `Down` when the panes are `stacked`), with `Shift` by 10 percent, `Home` and
`End` give the pane before it its smallest and its largest size. `Enter` (and a
double click) folds a `collapsible` pane away and opens it again. `Escape` cancels a
drag. The separator has the role `separator` with its value in percent, so a screen
reader says "Resize Orders, separator, 40 percent" and nothing else: no
announcements of ours.

Pointer: press a separator and drag; the panes follow at once. The separator never
goes beyond what the two panes beside it allow, and the others keep their size. A
mouse that is let go outside the window ends the drag when it comes back. The
component uses pointer events (and not the HTML5 drag and drop), so a finger or a
pen works too. It needs no subscription: once the mouse has moved, a transparent
layer over the window receives the events and gives the window one cursor and no
text selection.

Limits: a limit in pixels is checked against the container as it was when the user
last pressed or focused a separator; between then and the next time, the stylesheet
keeps the panes from being drawn smaller than their `minPixels` (and larger than
their `maxPixels`), but the sizes that `sizes` gives are the last ones that the
user's own movement set. Only the two panes beside a separator change when it
moves, and the content of every pane is drawn all the time, also in a pane that is
folded away. Right-to-left languages are not mirrored yet.


# View

@docs view, Pane, pane, minSize, maxSize, minPixels, maxPixels, collapsible


# State and messages

@docs State, Msg, init, update, sizes, setSizes, isDragging


# Shares

@docs Share, percent, toPercent


# Attributes

@docs Attribute, stacked, height, fillRest, locale

-}

import Html exposing (Html)
import Html.Attributes as Attr
import Html.Events as Events
import Json.Decode as Decode exposing (Decoder)
import Klar.Internal as Internal
import Klar.Locale as Locale exposing (Locale)
import Klar.Splitter.Layout as Layout exposing (Request)
import Klar.Splitter.Machine as Machine exposing (Device(..))



-- SIZES


{-| A share of the room that the panes have together, from 0 to 100 percent. Make
one with `percent`.
-}
type Share
    = Share Float


{-| A share in percent. A number below 0 counts as 0, above 100 as 100, and what is
not a number as 0.

    Splitter.percent 35

-}
percent : Float -> Share
percent value =
    if isNaN value then
        Share 0

    else
        Share (clamp 0 100 value)


{-| The share in percent, from 0 to 100.
-}
toPercent : Share -> Float
toPercent (Share value) =
    value



-- PANES


{-| One pane: a name and what to draw. Refine it with `minSize`, `maxSize`,
`minPixels`, `maxPixels` and `collapsible`.
-}
type Pane msg
    = Pane
        { label : String
        , content : Html msg
        , request : Request
        , collapsible : Bool
        }


{-| A pane. The name is what screen readers call it and what names the separator
after it ("Resize Orders"), so it is required. The `Html` is drawn inside the pane,
which scrolls when the content is larger than it.

    Splitter.pane "Orders" (viewOrderList model)

-}
pane : String -> Html msg -> Pane msg
pane label content =
    Pane
        { label = label
        , content = content
        , request = { minShare = 0, maxShare = 1, minPixels = 0, maxPixels = Nothing }
        , collapsible = False
        }


{-| The smallest share of the room the pane may have. The default is no smallest
size. With `minPixels` as well, the larger of the two counts. A smallest size that is
above the largest (`maxSize`, `maxPixels`) wins: the largest is raised to it, so a
pane can never be asked for something that cannot be.
-}
minSize : Share -> Pane msg -> Pane msg
minSize (Share value) (Pane data) =
    Pane { data | request = withRequest (\request -> { request | minShare = value / 100 }) data.request }


{-| The largest share of the room the pane may have. The default is no largest
size. With `maxPixels` as well, the smaller of the two counts. When it is below the
smallest size, the smallest size wins.
-}
maxSize : Share -> Pane msg -> Pane msg
maxSize (Share value) (Pane data) =
    Pane { data | request = withRequest (\request -> { request | maxShare = value / 100 }) data.request }


{-| The smallest width (the smallest height in a `stacked` splitter) of the pane in
pixels. A number below 0 counts as 0.
-}
minPixels : Int -> Pane msg -> Pane msg
minPixels pixels (Pane data) =
    Pane { data | request = withRequest (\request -> { request | minPixels = toFloat (Basics.max 0 pixels) }) data.request }


{-| The largest width (height when `stacked`) of the pane in pixels. A number below
0 counts as 0.
-}
maxPixels : Int -> Pane msg -> Pane msg
maxPixels pixels (Pane data) =
    Pane { data | request = withRequest (\request -> { request | maxPixels = Just (toFloat (Basics.max 0 pixels)) }) data.request }


withRequest : (Request -> Request) -> Request -> Request
withRequest change request =
    change request


{-| The pane can be folded away. `Enter` on the separator next to it, or a double
click, folds it (its room goes to the pane on the other side of the separator) and
opens it again. A folded pane has no room at all and is hidden from the keyboard and
from screen readers; its size is 0 in `sizes`, so a saved layout comes back folded.
A pane that is open keeps at least 2 percent of the room, so that it can not be
dragged shut by accident. A pane that is not `collapsible` never has no room, except
when it is given none.
-}
collapsible : Pane msg -> Pane msg
collapsible (Pane data) =
    Pane { data | collapsible = True }



-- ATTRIBUTES


{-| A setting of the splitter. Make them with the functions below and pass a list to
`view`; later attributes win over earlier ones.
-}
type Attribute
    = Attribute (Config -> Config)


type alias Config =
    { stacked : Bool
    , height : Maybe Int
    , fillRest : Bool
    , locale : Locale
    }


configure : List Attribute -> Config
configure attributes =
    List.foldl (\(Attribute change) config -> change config)
        { stacked = False, height = Nothing, fillRest = False, locale = Locale.default }
        attributes


{-| The panes lie one above the other, with horizontal separators, instead of side
by side. The keyboard then moves a separator with `Up` and `Down`. The default is
side by side.
-}
stacked : Attribute
stacked =
    Attribute (\config -> { config | stacked = True })


{-| The height of the splitter in pixels. Without it the splitter is as high as its
parent, which must then have a height of its own; a splitter inside a pane of
another splitter does not need one. A `stacked` splitter needs a height to be able
to divide anything.
-}
height : Int -> Attribute
height pixels =
    Attribute (\config -> { config | height = Just (Basics.max 0 pixels) })


{-| Makes the splitter as high as the room that is left in its parent, instead of
as high as the parent (which must have a height of its own) or a number of pixels.
Use it in a `Layout.stack [ Layout.fillRest ]`, so that a navigator beside a work
area fills the window under the page header with no pixel height; see
`Layout.fillRest`. It overrides `height`.

    Layout.stack [ Layout.fillRest ]
        [ PageHeader.view [ PageHeader.title "Stock" ]
        , Splitter.view SplitterMsg [ Splitter.fillRest ] model.split panes
        ]

-}
fillRest : Attribute
fillRest =
    Attribute (\config -> { config | fillRest = True })


{-| The language of the built-in text: "Resize" in the name of a separator and the
value ("40 percent"). The default is `Locale.default`, which is English. See
[Klar.Locale](Klar-Locale).
-}
locale : Locale -> Attribute
locale value =
    Attribute (\config -> { config | locale = value })



-- TEXT


type alias Texts =
    { resize : String -> String
    , value : Int -> String
    , folded : String
    }


texts : Locale -> Texts
texts loc =
    let
        pick nb en =
            Locale.pick loc { nb = nb, en = en }
    in
    { resize = \label -> pick "Endre størrelse på " "Resize " ++ label
    , value = \number -> String.fromInt number ++ pick " prosent" " percent"
    , folded = pick "Skjult" "Folded away"
    }



-- STATE


{-| The sizes of the panes and what the user is doing with a separator right now.
Make one with `init`, keep it in your model, pass every `Msg` through `update`, and
read the sizes with `sizes`.
-}
type State
    = State Machine.State


{-| A splitter with these sizes, one for each pane. The sizes are shares of the room
and are scaled to add up to 100 percent, whatever they add up to now: 30 and 30
become 50 and 50. A size that is 0 gives a pane that is folded away (if it is
`collapsible`) or has no room. The `String` is a DOM id prefix and must be unique on
the page: the container, the panes and the separators get ids that start with it.

    Splitter.init "orders-split" [ Splitter.percent 35, Splitter.percent 65 ]

-}
init : String -> List Share -> State
init domId initial =
    State (Machine.init domId (List.map toPercent initial))


{-| The sizes of the panes now, in percent, adding up to 100. Compare them before and
after an `update` to save them when the user has moved a separator. While a
separator is dragged they change with every movement; `isDragging` tells when it is
done. A list that is shorter or longer than the number of panes is only brought in
line when the user moves a separator.
-}
sizes : State -> List Share
sizes (State s) =
    List.map (\fraction -> Share (fraction * 100)) s.sizes


{-| Sets the sizes of all the panes, for example to restore a saved layout, or
`[ percent 0, percent 100 ]` to fold the first pane away. They are scaled to add up
to 100 percent, like those of `init`.
-}
setSizes : List Share -> State -> State
setSizes values (State s) =
    State (Machine.setSizes (List.map toPercent values) s)


{-| Is a separator being dragged with the mouse, a finger or a pen right now?
-}
isDragging : State -> Bool
isDragging (State s) =
    case s.drag of
        Just _ ->
            True

        Nothing ->
            False


{-| A message of the splitter. Wrap it in a constructor of your own message type
(`SplitterMsg`), pass that to `view`, and hand the messages you get back to
`update`.
-}
type Msg
    = Msg Machine.Msg


{-| Follows the user: a separator that is pressed, dragged, moved with the keys or
folded away. The command measures the container when a drag begins or a separator
gets the focus, and moves the focus to the separator that is pressed, so map it
with `Cmd.map` like any other child. To react to the new sizes, compare `sizes`
before and after.
-}
update : Msg -> State -> ( State, Cmd Msg )
update (Msg msg) (State s) =
    let
        ( next, cmd ) =
            Machine.update msg s
    in
    ( State next, Cmd.map Msg cmd )



-- VIEW


{-| The splitter. It takes the constructor that wraps the messages, the attributes,
the state and the panes, in order. One pane is drawn on its own; no panes give an
empty splitter.

    Splitter.view SplitterMsg
        [ Splitter.height 420 ]
        model.split
        [ Splitter.pane "Orders" ordersView
        , Splitter.pane "Details" detailView |> Splitter.collapsible
        ]

-}
view : (Msg -> msg) -> List Attribute -> State -> List (Pane msg) -> Html msg
view toMsg attributes (State s) panes =
    let
        config =
            configure attributes

        t =
            texts config.locale

        send =
            toMsg << Msg

        count =
            List.length panes

        layout =
            { requests = List.map (\(Pane data) -> data.request) panes
            , collapsible = List.map (\(Pane data) -> data.collapsible) panes
            , stacked = config.stacked
            }

        raw =
            Layout.fit count s.sizes

        sizeList =
            Machine.effective layout s

        limits =
            Machine.limitsFor layout s raw

        activeSeparator =
            s.drag

        viewPane index (Pane data) =
            let
                size =
                    List.drop index sizeList |> List.head |> Maybe.withDefault 0

                folded =
                    Machine.isFolded layout sizeList index

                pixelStyles =
                    if folded then
                        []

                    else
                        (if data.request.minPixels > 0 then
                            [ ( "--klar-min", String.fromFloat data.request.minPixels ++ "px" ) ]

                         else
                            []
                        )
                            ++ (case data.request.maxPixels of
                                    Just pixels ->
                                        [ ( "--klar-max", String.fromFloat pixels ++ "px" ) ]

                                    Nothing ->
                                        []
                               )
            in
            Html.div
                [ Internal.cls
                    [ "klar-splitter__pane"
                    , if folded then
                        "klar-splitter__pane--folded"

                      else
                        ""
                    ]
                , Attr.id (Machine.paneDomId s.domId index)
                , Attr.attribute "role" "group"
                , Attr.attribute "aria-label" data.label
                , Internal.styleVars (( "--klar-grow", String.fromFloat (size * 100) ) :: pixelStyles)
                ]
                [ data.content ]

        viewSeparator index =
            viewSeparatorAt send config t s layout panes sizeList limits index
    in
    Html.div
        ([ Internal.cls
            [ "klar-splitter"
            , if config.stacked then
                "klar-splitter--stacked"

              else
                ""
            , if isDragging (State s) then
                "klar-splitter--dragging"

              else
                ""
            , if config.fillRest then
                "klar-fill-rest"

              else
                ""
            , if config.fillRest then
                "klar-splitter--fill-rest"

              else
                ""
            ]
         , Attr.id s.domId
         ]
            ++ (case ( config.fillRest, config.height ) of
                    ( True, _ ) ->
                        []

                    ( False, Just pixels ) ->
                        [ Internal.styleVars [ ( "--klar-split-h", String.fromInt pixels ++ "px" ) ] ]

                    ( False, Nothing ) ->
                        []
               )
            ++ (case activeSeparator of
                    Just drag ->
                        -- the whole box follows the pointer, and the click that
                        -- follows a drag lands on it: it is ours
                        (if drag.moved then
                            [ Events.stopPropagationOn "click" (Decode.succeed ( send Machine.Noop, True )) ]

                         else
                            []
                        )
                            ++ (case drag.device of
                                    Mouse ->
                                        mouseTracking send

                                    Touch ->
                                        [ Events.on "pointermove" (Decode.map (send << Machine.PointerMoved) sampleDecoder)
                                        , Events.on "pointerup" (Decode.succeed (send Machine.Release))
                                        , Events.on "pointercancel" (Decode.succeed (send Machine.Cancel))
                                        ]
                               )

                    Nothing ->
                        []
               )
        )
        (List.concat
            (List.indexedMap
                (\index paneAt ->
                    if index < count - 1 then
                        [ viewPane index paneAt, viewSeparator index ]

                    else
                        [ viewPane index paneAt ]
                )
                panes
            )
            ++ (case activeSeparator of
                    Just drag ->
                        if drag.moved && drag.device == Mouse then
                            [ Html.div [ Internal.cls [ "klar-splitter__layer" ] ] [] ]

                        else
                            []

                    Nothing ->
                        []
               )
        )


viewSeparatorAt :
    (Machine.Msg -> msg)
    -> Config
    -> Texts
    -> Machine.State
    -> Machine.Layout
    -> List (Pane msg)
    -> List Float
    -> List Layout.Limits
    -> Int
    -> Html msg
viewSeparatorAt send config t s layout panes sizeList limits index =
    let
        labelAt i =
            panes |> List.drop i |> List.head |> Maybe.map (\(Pane data) -> data.label) |> Maybe.withDefault ""

        sizeAt i =
            sizeList |> List.drop i |> List.head |> Maybe.withDefault 0

        canFold i =
            panes |> List.drop i |> List.head |> Maybe.map (\(Pane data) -> data.collapsible) |> Maybe.withDefault False

        ( lowest, highest ) =
            Layout.range index limits sizeList

        foldsSomething =
            canFold index || canFold (index + 1)

        dragHere =
            case s.drag of
                Just drag ->
                    if drag.separator == index then
                        Just drag

                    else
                        Nothing

                Nothing ->
                    Nothing

        now =
            round (sizeAt index * 100)

        ( backward, forward ) =
            if config.stacked then
                ( "ArrowUp", "ArrowDown" )

            else
                ( "ArrowLeft", "ArrowRight" )

        bindings =
            case dragHere of
                Just _ ->
                    [ ( "Escape", Machine.Cancel ) ]

                Nothing ->
                    [ ( backward, Machine.Nudge layout index -0.01 )
                    , ( forward, Machine.Nudge layout index 0.01 )
                    , ( "Shift+" ++ backward, Machine.Nudge layout index -0.1 )
                    , ( "Shift+" ++ forward, Machine.Nudge layout index 0.1 )
                    , ( "Home", Machine.Edge layout index False )
                    , ( "End", Machine.Edge layout index True )
                    ]
                        ++ (if foldsSomething then
                                [ ( "Enter", Machine.Toggle layout index ) ]

                            else
                                []
                           )
    in
    Html.div
        ([ Internal.cls
            [ "klar-splitter__separator"
            , if dragHere /= Nothing then
                "klar-splitter__separator--active"

              else
                ""
            ]
         , Attr.id (Machine.separatorDomId s.domId index)
         , Attr.attribute "role" "separator"
         , Attr.tabindex 0
         , Attr.attribute "aria-orientation"
            (if config.stacked then
                "horizontal"

             else
                "vertical"
            )
         , Attr.attribute "aria-label" (t.resize (labelAt index))
         , Attr.attribute "aria-controls" (Machine.paneDomId s.domId index ++ " " ++ Machine.paneDomId s.domId (index + 1))
         , Attr.attribute "aria-valuenow" (String.fromInt now)
         , Attr.attribute "aria-valuemin" (String.fromInt (round (lowest * 100)))
         , Attr.attribute "aria-valuemax" (String.fromInt (round (highest * 100)))
         , Attr.attribute "aria-valuetext"
            (if Machine.isFolded layout sizeList index then
                t.folded

             else
                t.value now
            )
         , Events.stopPropagationOn "pointerdown" (pointerDown send layout index)
         , Events.preventDefaultOn "mousedown" (mouseDown send)
         , Events.on "focus" (Decode.succeed (send (Machine.Focused layout)))
         , Events.custom "keydown" (keyDecoder send bindings)
         ]
            ++ (if foldsSomething then
                    [ Events.on "dblclick" (Decode.succeed (send (Machine.Toggle layout index))) ]

                else
                    []
               )
        )
        []


mouseTracking : (Machine.Msg -> msg) -> List (Html.Attribute msg)
mouseTracking send =
    [ Events.on "mousemove" (Decode.map (send << Machine.PointerMoved) sampleDecoder)
    , Events.on "mouseup" (Decode.succeed (send Machine.Release))
    ]



-- EVENTS


sampleDecoder : Decoder Machine.Sample
sampleDecoder =
    Decode.map3 Machine.Sample
        (Decode.field "pageX" Decode.float)
        (Decode.field "pageY" Decode.float)
        (Decode.oneOf [ Decode.field "buttons" Decode.int, Decode.succeed 1 ])


{-| A press of the main button, or of a finger or pen.
-}
pointerDown : (Machine.Msg -> msg) -> Machine.Layout -> Int -> Decoder ( msg, Bool )
pointerDown send layout index =
    Decode.map4
        (\kind button primary sample ->
            ( send (Machine.Press layout index (deviceOf kind) sample), button == 0 && primary )
        )
        (Decode.field "pointerType" Decode.string)
        (Decode.field "button" Decode.int)
        (Decode.oneOf [ Decode.field "isPrimary" Decode.bool, Decode.succeed True ])
        sampleDecoder
        |> Decode.andThen
            (\( message, ok ) ->
                if ok then
                    Decode.succeed ( message, True )

                else
                    Decode.fail "not the main button"
            )


deviceOf : String -> Device
deviceOf kind =
    if kind == "mouse" then
        Mouse

    else
        Touch


{-| Keeps the browser from starting a text selection or a native drag when the
main mouse button goes down on a separator.
-}
mouseDown : (Machine.Msg -> msg) -> Decoder ( msg, Bool )
mouseDown send =
    Decode.field "button" Decode.int
        |> Decode.andThen
            (\button ->
                if button == 0 then
                    Decode.succeed ( send Machine.Noop, True )

                else
                    Decode.fail "not the main button"
            )


{-| The keys of a separator. Keys with `Ctrl`, `Alt` or `Meta` are left to the
browser; `Shift` is part of the name of the key (`Shift+ArrowLeft`).
-}
keyDecoder : (Machine.Msg -> msg) -> List ( String, Machine.Msg ) -> Decoder { message : msg, stopPropagation : Bool, preventDefault : Bool }
keyDecoder send bindings =
    Internal.keyEvent
        |> Decode.andThen
            (\event ->
                if event.ctrl || event.meta || event.alt then
                    Decode.fail "left to the browser"

                else
                    let
                        name =
                            if event.shift then
                                "Shift+" ++ event.key

                            else
                                event.key
                    in
                    case List.filter (\( key, _ ) -> key == name) bindings of
                        ( _, message ) :: _ ->
                            Decode.succeed { message = send message, stopPropagation = True, preventDefault = True }

                        [] ->
                            Decode.fail "not a key of the separator"
            )
