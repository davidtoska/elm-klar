module Klar.Sortable exposing
    ( view, Item, item, fixed
    , State, Msg, init, update, lifted
    , Ids, itemIds, stringIds, intIds
    , reorder, move
    , Attribute, ariaLabel, horizontal, wholeItem, disabled, emptyText, locale
    )

{-| A list the user can put in a new order: by dragging an item by its handle, or
with the keyboard.

    import Klar.Sortable as Sortable

    -- model: steps : List Step, sortable : Sortable.State StepId
    -- init:  Sortable.init "pick-steps"
    stepIds : Sortable.Ids StepId
    stepIds =
        Sortable.itemIds { toKey = StepId.toString, fromKey = StepId.fromString }

    -- update
    SortableMsg m ->
        let
            ( sortable, cmd ) =
                Sortable.update m model.sortable
        in
        ( { model
            | sortable = sortable
            , steps = Sortable.reorder stepIds .id model.sortable sortable model.steps
          }
        , Cmd.map SortableMsg cmd
        )

    -- view
    Sortable.view stepIds
        SortableMsg
        [ Sortable.ariaLabel "Pick sequence" ]
        model.sortable
        (List.map (\step -> Sortable.item step.id step.title (viewStep step)) model.steps)

Your list stays yours. You draw it in your own order, and the component only
remembers what the user is doing right now (which item is held and where it would
land). When the user lets go, `reorder` puts the item in its new place in your list,
in the same `update` that handled the message; if you do not call it, nothing has
moved, and the list springs back to what you draw. Items carry the id type of your
own (`StepId`), written as text once with `itemIds`, so no `String` ids leak into
your code. Draw the items with whatever `Html` you like: the component wraps each in
a list item with a handle.

Use it for a short list whose order matters: the steps of a pick sequence, the
filters of a saved view, a chip list. For a table whose columns can be moved, use
[Klar.Table](Klar-Table); for a tree, [Klar.Tree](Klar-Tree). An item that is
[fixed](#fixed) stays where it is and cannot be passed, so a "Scan the tote" step can
stay first. A list with `disabled True` cannot be changed.

Keyboard: every item has a handle, which is a button and a tab stop of its own.
`Space` or `Enter` picks the item up. Then the `Up` and `Down` arrow keys move it one
place (`Left` and `Right` in a `horizontal` list), `Home` and `End` jump to the ends,
`Space` or `Enter` drops it and `Escape` cancels. Leaving the handle with `Tab`
cancels too. While the item is held the list does not change: a line shows where the
item would land, and the page scrolls to it. Only when it is dropped does the list
move, and the handle keeps focus.

Pointer: press the handle and drag. A press that does not move 4 pixels is a plain
click and does nothing. The item stays where it is and is drawn as lifted, a line
shows where it would land, and its label follows the pointer. Let go to drop;
`Escape` cancels. The component uses pointer events, not the HTML5 drag and drop of
the browser, so it works in Firefox and with a finger or a pen. With `wholeItem` the
mouse can also take hold of the item anywhere except on buttons, links and fields; a
finger always uses the handle, so the rest of the item still scrolls the page.

Screen readers: the handle is named after the item (the label you give to `item`),
described as "sortable item" and told how to use it. A live region owned by the
component says what happens: "Scan the tote picked up, position 2 of 5", "Moved to
position 3 of 5", "Scan the tote dropped at position 3 of 5", "Cancelled". The text is
English or Norwegian Bokmål (see `locale`).

What the state remembers: the item that is held, the list as it was when the user
picked it up, and where it would land. Nothing else; the order is yours.

Limits: lists are drawn in full (there is no windowing), so keep them to a few
hundred items. A drag with the pointer does not scroll the page or a box around the
list; the keyboard path scrolls the window, not a scrolling box. Right-to-left
languages are not mirrored yet. If your list changes while an item is held, the drop
is cancelled instead of moving the item to a place that no longer means the same.


# View

@docs view, Item, item, fixed


# State and messages

@docs State, Msg, init, update, lifted


# Ids

@docs Ids, itemIds, stringIds, intIds


# Putting the list in the new order

@docs reorder, move


# Attributes

@docs Attribute, ariaLabel, horizontal, wholeItem, disabled, emptyText, locale

-}

import Html exposing (Html)
import Html.Attributes as Attr
import Html.Events as Events
import Html.Keyed as Keyed
import Json.Decode as Decode exposing (Decoder)
import Klar.Icon as Icon
import Klar.Internal as Internal
import Klar.Locale as Locale exposing (Locale)
import Klar.Sortable.Machine as Machine exposing (Note(..))
import Klar.Sortable.Order as Order
import Klar.Sortable.Session exposing (Device(..), Input(..), Layout, Point, Session)
import Set exposing (Set)



-- IDS


{-| How the id type of your items (a `StepId`, a `FilterId`, plain text ...) is
written as a key and read back. Declare one value for each kind of list, once, and
pass it to `view`, `reorder` and `lifted`. The state is typed by the id
(`Sortable.State StepId`), so a list of steps cannot be asked about filters.

    steps : Sortable.Ids StepId
    steps =
        Sortable.itemIds { toKey = StepId.toString, fromKey = StepId.fromString }

The key is what the state keeps, and it becomes part of the DOM ids, so `toKey`
must give every id its own key. A list that holds the same key twice shows the first
item only.

-}
type Ids id
    = Ids
        { toKey : id -> String
        , fromKey : String -> Maybe id
        }


{-| Makes the `Ids` of an id type, see there.
-}
itemIds : { toKey : id -> String, fromKey : String -> Maybe id } -> Ids id
itemIds =
    Ids


{-| Ids that are plain text, used as they are.
-}
stringIds : Ids String
stringIds =
    Ids { toKey = identity, fromKey = Just }


{-| Ids that are whole numbers.
-}
intIds : Ids Int
intIds =
    Ids { toKey = String.fromInt, fromKey = String.toInt }



-- ITEMS


{-| One item of the list. Make it with `item` and, if it must stay in its place,
`fixed`.
-}
type Item id msg
    = Item
        { id : id
        , label : String
        , content : Html msg
        , fixed : Bool
        }


{-| An item: its id, its label and what to draw.

    Sortable.item step.id step.title (Html.text step.title)

The label names the item for screen readers (the handle is called after it, and the
announcements use it: "Scan the tote picked up"), so it is required and should be
plain text that tells the items apart. The `Html` is drawn as it is next to the
handle.

-}
item : id -> String -> Html msg -> Item id msg
item id label content =
    Item { id = id, label = label, content = content, fixed = False }


{-| An item that stays where it is. It has no handle (a small lock takes its
place), the user cannot move it and no other item can be moved past it: it splits
the list in two parts that are arranged on their own. Put it first or last to keep
a step at the start or the end.
-}
fixed : Item id msg -> Item id msg
fixed (Item data) =
    Item { data | fixed = True }


type alias Entry msg =
    { key : String
    , label : String
    , content : Html msg
    , fixed : Bool
    }


entriesOf : Ids id -> List (Item id msg) -> List (Entry msg)
entriesOf (Ids ids) items =
    items
        |> List.foldl
            (\(Item data) ( seen, kept ) ->
                let
                    key =
                        ids.toKey data.id
                in
                if Set.member key seen then
                    ( seen, kept )

                else
                    ( Set.insert key seen
                    , { key = key, label = data.label, content = data.content, fixed = data.fixed } :: kept
                    )
            )
            ( Set.empty, [] )
        |> Tuple.second
        |> List.reverse



-- ATTRIBUTES


{-| A setting of the list. Make them with the functions below and pass a list to
`view`; later attributes win over earlier ones.
-}
type Attribute
    = Attribute (Config -> Config)


type alias Config =
    { label : Maybe String
    , horizontal : Bool
    , wholeItem : Bool
    , disabled : Bool
    , emptyText : Maybe String
    , locale : Locale
    }


configure : List Attribute -> Config
configure attributes =
    List.foldl (\(Attribute change) config -> change config)
        { label = Nothing
        , horizontal = False
        , wholeItem = False
        , disabled = False
        , emptyText = Nothing
        , locale = Locale.default
        }
        attributes


{-| The accessible name of the list, for example "Pick sequence". Give every list
on a page its own name; without it the list has none.
-}
ariaLabel : String -> Attribute
ariaLabel text =
    Attribute (\config -> { config | label = Just text })


{-| The items run side by side (a chip list) instead of one below the other, and
wrap onto more lines when they do not fit. The keyboard moves an item with the
`Left` and `Right` arrow keys instead of `Up` and `Down`. The default is a
vertical list.
-}
horizontal : Attribute
horizontal =
    Attribute (\config -> { config | horizontal = True })


{-| Lets the mouse take hold of an item anywhere, not only by its handle, except
on buttons, links, fields and other things that react to a press themselves. A
finger or pen still uses the handle only, so that the rest of the item scrolls the
page. The handle stays: it is how the keyboard and screen readers reach the item.
The default is the handle only.
-}
wholeItem : Attribute
wholeItem =
    Attribute (\config -> { config | wholeItem = True })


{-| Makes the whole list unchangeable: the handles are dimmed and cannot be used.
The default is `False`.
-}
disabled : Bool -> Attribute
disabled value =
    Attribute (\config -> { config | disabled = value })


{-| The text drawn when there are no items. The default is "No items".
-}
emptyText : String -> Attribute
emptyText text =
    Attribute (\config -> { config | emptyText = Just text })


{-| The language of the built-in text: the description of the handle, the
announcements, "Fixed position" and the empty text. The default is
`Locale.default`, which is English. See [Klar.Locale](Klar-Locale).
-}
locale : Locale -> Attribute
locale value =
    Attribute (\config -> { config | locale = value })



-- TEXT


type alias Texts =
    { roleDescription : String
    , help : Bool -> String
    , fixed : String
    , empty : String
    , itemFallback : String
    , pickedUp : String -> Int -> Int -> String
    , movedTo : Int -> Int -> String
    , atLimit : Int -> Int -> String
    , dropped : String -> Int -> Int -> String
    , cancelled : String -> Int -> Int -> String
    }


texts : Locale -> Texts
texts loc =
    let
        pick nb en =
            Locale.pick loc { nb = nb, en = en }

        place position total =
            String.fromInt position ++ " " ++ pick "av" "of" ++ " " ++ String.fromInt total
    in
    { roleDescription = pick "sorterbart element" "sortable item"
    , help =
        \isHorizontal ->
            if isHorizontal then
                pick
                    "Trykk mellomrom eller Enter for å løfte elementet. Bruk deretter piltastene venstre og høyre for å flytte det, Home og End for å hoppe til endene, mellomrom eller Enter for å slippe det og Escape for å avbryte."
                    "Press Space or Enter to pick up this item. Then use the Left and Right arrow keys to move it, Home and End to jump to the ends, Space or Enter to drop it, and Escape to cancel."

            else
                pick
                    "Trykk mellomrom eller Enter for å løfte elementet. Bruk deretter piltastene opp og ned for å flytte det, Home og End for å hoppe til endene, mellomrom eller Enter for å slippe det og Escape for å avbryte."
                    "Press Space or Enter to pick up this item. Then use the Up and Down arrow keys to move it, Home and End to jump to the ends, Space or Enter to drop it, and Escape to cancel."
    , fixed = pick "Fast plassering" "Fixed position"
    , empty = pick "Ingen elementer" "No items"
    , itemFallback = pick "Elementet" "The item"
    , pickedUp = \label position total -> label ++ pick " løftet, posisjon " " picked up, position " ++ place position total ++ "."
    , movedTo = \position total -> pick "Flyttet til posisjon " "Moved to position " ++ place position total ++ "."
    , atLimit = \position total -> pick "Posisjon " "Position " ++ place position total ++ pick ". Kan ikke flyttes lenger." ". It cannot move further."
    , dropped = \label position total -> label ++ pick " sluppet på posisjon " " dropped at position " ++ place position total ++ "."
    , cancelled = \label position total -> pick "Avbrutt. " "Cancelled. " ++ label ++ pick " er tilbake på posisjon " " is back at position " ++ place position total ++ "."
    }



-- STATE


{-| What the user is doing with a list right now: which item is held and where it
would land. Make one with `init`, keep it in your model, pass every `Msg` through
`update`, and read the result with `reorder`. The items and their order are not part
of it.
-}
type State id
    = State Machine.State


{-| A list in which nothing is held. The `String` is a DOM id prefix and must be
unique on the page: the items, the handles and the instructions get ids that start
with it.

    Sortable.init "pick-steps"

-}
init : String -> State id
init domId =
    State (Machine.init domId)


{-| The id of the item that is held (picked up with the keyboard, or dragged past
the first few pixels), or `Nothing`. Use it to show that something is going on, or
to hold back a refresh of the list.
-}
lifted : Ids id -> State id -> Maybe id
lifted (Ids ids) (State s) =
    case s.session of
        Just session ->
            if session.lifted then
                ids.fromKey session.source

            else
                Nothing

        Nothing ->
            Nothing


{-| A message of the list. Wrap it in a constructor of your own message type
(`SortableMsg`), pass that to `view`, and hand the messages you get back to
`update`.
-}
type Msg
    = Msg Machine.Msg


{-| Follows the user: picking an item up, moving it, dropping it or cancelling.
The command measures the items when a press begins, brings the target into view
while the keyboard moves it and puts the focus back on the handle after a drop, so
map it with `Cmd.map` like any other child. To react to a drop, call `reorder`.
-}
update : Msg -> State id -> ( State id, Cmd Msg )
update (Msg msg) (State s) =
    let
        ( next, cmd ) =
            Machine.update msg s
    in
    ( State next, Cmd.map Msg cmd )



-- REORDERING


{-| Puts your list in the order the user just chose. Give it the state before and
the state after an `update`, and your list; it moves the dropped item to its new
place and returns the list unchanged when nothing was dropped between the two
states. It finds the item with the id function you give (`.id`), so it also works
when your list is longer or shorter than the one that was drawn.

    Sortable.reorder steps .id model.sortable sortable model.steps

-}
reorder : Ids id -> (a -> id) -> State id -> State id -> List a -> List a
reorder (Ids ids) toId (State before) (State after) list =
    if after.drops == before.drops then
        list

    else
        case after.last of
            Just drop_ ->
                case Order.indexOf drop_.key (List.map (\element -> ids.toKey (toId element)) list) of
                    Just index ->
                        Order.move index drop_.to list

                    Nothing ->
                        list

            Nothing ->
                list


{-| Moves one element of a list from one place to another, counting from 0. The
place `to` is where the element ends up. A `to` beyond the ends counts as the
nearest end, and a `from` that is not in the list changes nothing. Use it for the
same move without dragging, for example for "Move up" and "Move down" buttons in a
menu, so that people who cannot drag have another way.

    Sortable.move { from = 0, to = 2 } [ "a", "b", "c", "d" ] --> [ "b", "c", "a", "d" ]

-}
move : { from : Int, to : Int } -> List a -> List a
move { from, to } list =
    Order.move from to list



-- VIEW


{-| The list. It takes the `Ids` of your item type, the constructor that wraps the
messages, the attributes, the state and the items in the order you want them
drawn.

    Sortable.view steps
        SortableMsg
        [ Sortable.ariaLabel "Pick sequence" ]
        model.sortable
        (List.map viewStep model.steps)

An empty list draws the `emptyText`. Reordering needs the same `Ids` in `reorder`.

-}
view : Ids id -> (Msg -> msg) -> List Attribute -> State id -> List (Item id msg) -> Html msg
view ids toMsg attributes (State s) items =
    let
        send =
            toMsg << Msg

        config =
            configure attributes

        t =
            texts config.locale

        entries =
            entriesOf ids items

        keys =
            List.map .key entries

        flags =
            List.map .fixed entries

        layout key =
            { source = key, order = keys, fixed = flags, horizontal = config.horizontal }

        heldNow =
            case s.session of
                Just session ->
                    session.lifted

                Nothing ->
                    False

        marker =
            case s.session of
                Just session ->
                    if session.lifted then
                        Order.indicator session.from session.to

                    else
                        Nothing

                Nothing ->
                    Nothing

        row index entry =
            ( entry.key
            , viewEntry send config t s keys (layout entry.key) marker index entry
            )

        list =
            if List.isEmpty entries then
                Html.div [ Internal.cls [ "klar-sortable__empty" ] ]
                    [ Html.text (Maybe.withDefault t.empty config.emptyText) ]

            else
                Keyed.ol
                    [ Internal.cls [ "klar-sortable__list" ]
                    , Attr.attribute "role" "list"
                    , Internal.attrMaybe (Attr.attribute "aria-label") config.label
                    ]
                    (List.indexedMap row entries)
    in
    Html.div
        ([ Internal.cls
            [ "klar-sortable"
            , if config.horizontal then
                "klar-sortable--horizontal"

              else
                ""
            , if config.disabled then
                "klar-sortable--disabled"

              else
                ""
            , if heldNow then
                "klar-sortable--dragging"

              else
                ""
            ]
         ]
            ++ pointerTracking send keys s.session
        )
        [ list
        , Html.div
            [ Internal.cls [ "klar-sr-only" ]
            , Attr.attribute "aria-live" "assertive"
            , Attr.attribute "aria-atomic" "true"
            ]
            [ Html.text (announcement t entries s.note) ]
        , Html.span [ Attr.id (Machine.helpDomId s.domId), Internal.cls [ "klar-sr-only" ] ]
            [ Html.text (t.help config.horizontal) ]
        , Html.div [ Internal.cls [ "klar-sortable__extras" ] ] (extras entries s.session)
        ]


viewEntry : (Machine.Msg -> msg) -> Config -> Texts -> Machine.State -> List String -> Layout -> Maybe Order.Indicator -> Int -> Entry msg -> Html msg
viewEntry toMsg config t s keys layout marker index entry =
    let
        mine =
            case s.session of
                Just session ->
                    if session.source == entry.key then
                        Just session

                    else
                        Nothing

                Nothing ->
                    Nothing

        isHeld =
            case mine of
                Just session ->
                    session.lifted

                Nothing ->
                    False

        markerHere =
            case marker of
                Just placed ->
                    if placed.index == index then
                        Just placed.after

                    else
                        Nothing

                Nothing ->
                    Nothing

        movable =
            not entry.fixed && not config.disabled

        handle =
            if entry.fixed then
                Html.span
                    [ Internal.cls [ "klar-sortable__lock" ]
                    , Attr.title t.fixed
                    ]
                    [ Icon.sized Icon.Small Icon.lock
                    , Html.span [ Internal.cls [ "klar-sr-only" ] ] [ Html.text t.fixed ]
                    ]

            else
                Html.button
                    ([ Internal.cls [ "klar-sortable__handle" ]
                     , Attr.id (Machine.handleDomId s.domId entry.key)
                     , Attr.type_ "button"
                     , Attr.disabled config.disabled
                     , Attr.attribute "aria-label" entry.label
                     , Attr.attribute "aria-roledescription" t.roleDescription
                     , Attr.attribute "aria-describedby" (Machine.helpDomId s.domId)
                     , Attr.attribute "aria-pressed"
                        (if isHeld then
                            "true"

                         else
                            "false"
                        )
                     ]
                        ++ (if config.disabled then
                                []

                            else
                                [ handleKeys toMsg config.horizontal keys layout mine
                                , Events.on "blur" (Decode.succeed (toMsg (Machine.Blurred entry.key)))
                                ]
                           )
                    )
                    [ Icon.view Icon.grip ]
    in
    Html.li
        ([ Internal.cls
            [ "klar-sortable__item"
            , if isHeld then
                "klar-sortable__item--lifted"

              else
                ""
            , case markerHere of
                Just True ->
                    "klar-sortable__item--drop-after"

                Just False ->
                    "klar-sortable__item--drop-before"

                Nothing ->
                    ""
            , if entry.fixed then
                "klar-sortable__item--fixed"

              else
                ""
            , if config.wholeItem && movable then
                "klar-sortable__item--grab"

              else
                ""
            ]
         , Attr.id (Machine.itemDomId s.domId entry.key)
         , Attr.attribute "role" "listitem"
         ]
            ++ (if movable then
                    [ Events.stopPropagationOn "pointerdown" (pointerDown config.wholeItem toMsg layout)
                    , Events.preventDefaultOn "mousedown" (mouseDown config.wholeItem toMsg)
                    ]

                else
                    []
               )
        )
        [ handle
        , Html.div [ Internal.cls [ "klar-sortable__content" ] ] [ entry.content ]
        ]


{-| While a press or a drag goes on, the whole list listens for the pointer, so that
a mouse that leaves the item is still followed and a finger (which the browser
gives to the element it touched) reports through the item. Once the item is lifted a
layer over the window takes the rest of the page, and the click that follows a drag
(it lands on this box, whose children the mouse went down and up on) is stopped
here.
-}
pointerTracking : (Machine.Msg -> msg) -> List String -> Maybe Session -> List (Html.Attribute msg)
pointerTracking toMsg keys maybeSession =
    case maybeSession of
        Just session ->
            case session.input of
                Pointing pointing ->
                    (if session.lifted then
                        [ Events.stopPropagationOn "click" (Decode.succeed ( toMsg Machine.Noop, True )) ]

                     else
                        []
                    )
                        ++ (case pointing.device of
                                Mouse ->
                                    [ Events.on "mousemove" (Decode.map (toMsg << Machine.PointerMoved) sampleDecoder)
                                    , Events.on "mouseup" (Decode.succeed (toMsg (Machine.Drop keys)))
                                    ]

                                Touch ->
                                    [ Events.on "pointermove" (Decode.map (toMsg << Machine.PointerMoved) sampleDecoder)
                                    , Events.on "pointerup" (Decode.succeed (toMsg (Machine.Drop keys)))
                                    , Events.on "pointercancel" (Decode.succeed (toMsg Machine.Cancel))
                                    ]
                           )

                Keyboard ->
                    []

        Nothing ->
            []


{-| What is drawn outside the list while the pointer holds an item: a layer over the
window that gives the mouse one cursor and keeps text from being selected, and the
label of the item beside the pointer.
-}
extras : List (Entry msg) -> Maybe Session -> List (Html msg)
extras entries maybeSession =
    case maybeSession of
        Just session ->
            case ( session.input, session.lifted ) of
                ( Pointing pointing, True ) ->
                    [ case pointing.device of
                        Mouse ->
                            Html.div [ Internal.cls [ "klar-sortable__layer" ] ] []

                        Touch ->
                            Html.text ""
                    , Html.div
                        [ Internal.cls
                            [ "klar-sortable__ghost"
                            , case pointing.device of
                                Touch ->
                                    "klar-sortable__ghost--touch"

                                Mouse ->
                                    ""
                            ]
                        , Internal.styleVars
                            [ ( "--klar-x", String.fromFloat pointing.client.x ++ "px" )
                            , ( "--klar-y", String.fromFloat pointing.client.y ++ "px" )
                            ]
                        , Attr.attribute "aria-hidden" "true"
                        ]
                        [ Html.text (labelOf entries session.source) ]
                    ]

                _ ->
                    []

        Nothing ->
            []


labelOf : List (Entry msg) -> String -> String
labelOf entries key =
    entries
        |> List.filter (\entry -> entry.key == key)
        |> List.head
        |> Maybe.map .label
        |> Maybe.withDefault ""


announcement : Texts -> List (Entry msg) -> Maybe Note -> String
announcement t entries note =
    let
        named key =
            case labelOf entries key of
                "" ->
                    t.itemFallback

                label ->
                    label
    in
    case note of
        Just (PickedUp key position total) ->
            t.pickedUp (named key) position total

        Just (MovedTo position total) ->
            t.movedTo position total

        Just (AtLimit position total) ->
            t.atLimit position total

        Just (Dropped key position total) ->
            t.dropped (named key) position total

        Just (Cancelled key position total) ->
            t.cancelled (named key) position total

        Nothing ->
            ""



-- EVENTS


{-| The keys of a handle. An idle handle picks up on `Space` and `Enter`; a held item
(by the keyboard) moves, jumps, drops and cancels. A key repeated by holding it down
does not pick up or drop, and keys with `Ctrl`, `Alt` or `Meta` are left to the
browser.
-}
handleKeys : (Machine.Msg -> msg) -> Bool -> List String -> Layout -> Maybe Session -> Html.Attribute msg
handleKeys toMsg isHorizontal keys layout mine =
    let
        ( backward, forward ) =
            if isHorizontal then
                ( "ArrowLeft", "ArrowRight" )

            else
                ( "ArrowUp", "ArrowDown" )

        bindings =
            case mine of
                Just session ->
                    case ( session.lifted, session.input ) of
                        ( True, Keyboard ) ->
                            [ ( " ", Machine.Drop keys )
                            , ( "Enter", Machine.Drop keys )
                            , ( "Escape", Machine.Cancel )
                            , ( backward, Machine.Step -1 )
                            , ( forward, Machine.Step 1 )
                            , ( "Home", Machine.Jump False )
                            , ( "End", Machine.Jump True )
                            ]

                        ( True, Pointing _ ) ->
                            [ ( "Escape", Machine.Cancel ) ]

                        _ ->
                            []

                Nothing ->
                    [ ( " ", Machine.Lift layout ), ( "Enter", Machine.Lift layout ) ]
    in
    Events.custom "keydown" (keyDecoder toMsg bindings)


keyDecoder : (Machine.Msg -> msg) -> List ( String, Machine.Msg ) -> Decoder { message : msg, stopPropagation : Bool, preventDefault : Bool }
keyDecoder toMsg bindings =
    Decode.map2 Tuple.pair
        Internal.keyEvent
        (Decode.oneOf [ Decode.field "repeat" Decode.bool, Decode.succeed False ])
        |> Decode.andThen
            (\( event, repeating ) ->
                if event.ctrl || event.meta || event.alt then
                    Decode.fail "left to the browser"

                else
                    case List.filter (\( key, _ ) -> key == event.key) bindings of
                        ( key, message ) :: _ ->
                            if repeating && (key == " " || key == "Enter") then
                                -- holding the key down must not pick up and drop again
                                Decode.succeed { message = toMsg Machine.Noop, stopPropagation = True, preventDefault = True }

                            else
                                Decode.succeed { message = toMsg message, stopPropagation = True, preventDefault = True }

                        [] ->
                            Decode.fail "not a key of the list"
            )


pointDecoder : String -> String -> Decoder Point
pointDecoder xField yField =
    Decode.map2 Point
        (Decode.field xField Decode.float)
        (Decode.field yField Decode.float)


sampleDecoder : Decoder Machine.Sample
sampleDecoder =
    Decode.map3 Machine.Sample
        (pointDecoder "pageX" "pageY")
        (pointDecoder "clientX" "clientY")
        (Decode.oneOf [ Decode.field "buttons" Decode.int, Decode.succeed 1 ])


guard : Decoder Bool -> Decoder ()
guard decoder =
    decoder
        |> Decode.andThen
            (\ok ->
                if ok then
                    Decode.succeed ()

                else
                    Decode.fail "not a press on a handle"
            )


primaryButton : Decoder Bool
primaryButton =
    Decode.map2 (\button primary -> button == 0 && primary)
        (Decode.field "button" Decode.int)
        (Decode.oneOf [ Decode.field "isPrimary" Decode.bool, Decode.succeed True ])


pointerDown : Bool -> (Machine.Msg -> msg) -> Layout -> Decoder ( msg, Bool )
pointerDown whole toMsg layout =
    Decode.field "pointerType" Decode.string
        |> Decode.andThen
            (\kind ->
                Decode.map4
                    (\_ _ page client ->
                        ( toMsg (Machine.Press layout (deviceOf kind) page client), True )
                    )
                    (guard primaryButton)
                    (guard (Decode.field "target" (reachesHandle (not whole || kind == "touch") 0)))
                    (pointDecoder "pageX" "pageY")
                    (pointDecoder "clientX" "clientY")
            )


deviceOf : String -> Device
deviceOf kind =
    if kind == "mouse" then
        Mouse

    else
        Touch


{-| Keeps the browser from starting a text selection or a native drag when the
mouse goes down on a handle (and, with `wholeItem`, on the item).
-}
mouseDown : Bool -> (Machine.Msg -> msg) -> Decoder ( msg, Bool )
mouseDown whole toMsg =
    Decode.map2 (\_ _ -> ( toMsg Machine.Noop, True ))
        (guard primaryButton)
        (guard (Decode.field "target" (reachesHandle (not whole) 0)))


{-| Walks up from the element that was pressed to the item. A press counts when it
is on the handle, or (unless only the handle counts) on the item without passing a
button, link, field or other element that reacts to a press itself.
-}
reachesHandle : Bool -> Int -> Decoder Bool
reachesHandle handleOnly depth =
    Decode.map3 (\tag name editable -> { tag = tag, name = name, editable = editable })
        (Decode.oneOf [ Decode.field "tagName" Decode.string, Decode.succeed "" ])
        (Decode.oneOf [ Decode.field "className" Decode.string, Decode.succeed "" ])
        (Decode.oneOf [ Decode.field "isContentEditable" Decode.bool, Decode.succeed False ])
        |> Decode.andThen
            (\element ->
                if String.contains "klar-sortable__handle" element.name then
                    Decode.succeed True

                else if String.contains "klar-sortable__item" element.name then
                    Decode.succeed (not handleOnly)

                else if not handleOnly && (element.editable || List.member element.tag interactive) then
                    Decode.succeed False

                else if depth > 24 then
                    Decode.succeed False

                else
                    Decode.oneOf
                        [ Decode.field "parentElement" (Decode.lazy (\_ -> reachesHandle handleOnly (depth + 1)))
                        , Decode.succeed False
                        ]
            )


interactive : List String
interactive =
    [ "A", "BUTTON", "INPUT", "SELECT", "TEXTAREA", "SUMMARY", "LABEL", "OPTION", "VIDEO", "AUDIO", "IFRAME" ]
