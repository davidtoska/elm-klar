module Klar.Sortable exposing
    ( view, Item, item, fixed
    , State, Msg, init, update, lifted
    , reorder
    , Attribute, ariaLabel, horizontal, wholeItem, moveButtons, disabled, emptyText, locale
    )

{-| A list the user can put in a new order: by dragging an item by its handle, or
with the keyboard.

Use when: a short list has an order that matters, such as the steps of a pick sequence or the filters of a saved view.
Do not use when: the user only chooses which columns of a table to show (use `Table.columnChooser`); a table has no way to reorder its columns.
Quick path: `init`, `update`, `view`, `reorder`

    import Klar.Ids as Ids exposing (Ids)
    import Klar.Sortable as Sortable

    -- model: steps : List Step, sortable : Sortable.State StepId
    -- init:  Sortable.init "pick-steps"
    stepIds : Ids StepId
    stepIds =
        Ids.make { toKey = StepId.toString, fromKey = StepId.fromString }

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
    Sortable.view SortableMsg
        [ Sortable.ariaLabel "Pick sequence", Sortable.moveButtons ]
        model.sortable
        (List.map (\step -> Sortable.item stepIds step.id step.title (viewStep step)) model.steps)

Your list stays yours. You draw it in your own order, and the component only
remembers what the user is doing right now (which item is held and where it would
land). When the user lets go, `reorder` puts the item in its new place in your list,
in the same `update` that handled the message; if you do not call it, nothing has
moved, and the list springs back to what you draw. Items carry the id type of your
own (`StepId`), written as text once as a [Klar.Ids](Klar-Ids), so no `String` ids leak into
your code. Draw the items with whatever `Html` you like: the component wraps each in
a list item with a handle.

Dragging is not for everybody, and the guidelines for accessibility ask for another way
than a movement with the pointer (WCAG 2.5.7). The keyboard is one. For a person who
uses a pointer and cannot drag, `moveButtons` gives each item "Move up" and "Move down"
buttons. They move the item the same way a drop does (past no `fixed` item, announced,
put in place by `reorder`) and keep the focus on the button that was pressed, so there
is nothing to write for them.

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
the browser, so it works in Firefox and with a finger or a pen. It needs no
subscription: while the mouse drags, a transparent layer over the window receives
the events (and gives the window one cursor and no text selection), and a mouse that
is let go outside the window cancels the drag when it comes back. With `wholeItem` the
mouse can also take hold of the item anywhere except on buttons, links and fields; a
finger or a pen always uses the handle, so the rest of the item still scrolls the page.

Screen readers: the handle is named after the item (the label you give to `item`),
described as "sortable item" and told how to use it. A live region owned by the
component says what happens: "Scan the tote picked up, position 2 of 5", "Moved to
position 3 of 5", "Scan the tote dropped at position 3 of 5", "Cancelled". The text is
English or Norwegian Bokmål (see `locale`).

What the state remembers: the item that is held, the list as it was when the user
picked it up, where it would land, and, until the next drop, where the last drop put
its item (the keys of its neighbours, which `reorder` reads). Nothing else; the order
is yours, and `reorder` also works on a list that is not the one that was drawn.

Limits: lists are drawn in full (there is no windowing), so keep them to a few
hundred items. A drag with the pointer does not scroll the page or a box around the
list; the keyboard path scrolls the window, not a scrolling box. Right-to-left
languages are not mirrored yet. If the list that is drawn changes while an item is
held, the drop is cancelled instead of moving the item to a place that no longer
means the same; an item that is taken out of the list while it is held is let go
(the next time a handle gets the focus or is pressed, the state forgets it).


# View

@docs view, Item, item, fixed


# State and messages

@docs State, Msg, init, update, lifted


# Ids

The id type of your items (a `StepId`, plain text ...) is written as a key once, as a
[Klar.Ids](Klar-Ids), and given to `item`, `reorder` and `lifted`. The state is typed by
the id (`Sortable.State StepId`). The key becomes part of the DOM ids, so `toKey` must give
every id its own key; a list that holds the same key twice shows the first item only.


# Putting the list in the new order

@docs reorder


# Attributes

@docs Attribute, ariaLabel, horizontal, wholeItem, moveButtons, disabled, emptyText, locale

-}

import Html exposing (Html)
import Html.Attributes as Attr
import Html.Events as Events
import Html.Keyed as Keyed
import Json.Decode as Decode exposing (Decoder)
import Klar.Icon as Icon
import Klar.Ids as Ids exposing (Ids)
import Klar.Internal as Internal
import Klar.Locale as Locale exposing (Locale)
import Klar.Sortable.Machine as Machine exposing (Note(..))
import Klar.Sortable.Order as Order
import Klar.Sortable.Session exposing (Device(..), Input(..), Layout, Point, Session)
import Set exposing (Set)



-- ITEMS


{-| One item of the list. Make it with `item` and, if it must stay in its place,
`fixed`.
-}
type Item id msg
    = Item
        { key : String
        , label : String
        , content : Html msg
        , fixed : Bool
        }


{-| An item: the `Ids` of your id type, its id, its label and what to draw.

    Sortable.item stepIds step.id step.title (Html.text step.title)

The label names the item for screen readers (the handle is called after it, and the
announcements use it: "Scan the tote picked up"), so it is required and should be
plain text that tells the items apart. The `Html` is drawn as it is next to the
handle.

-}
item : Ids id -> id -> String -> Html msg -> Item id msg
item ids id label content =
    Item { key = Ids.toKey ids id, label = label, content = content, fixed = False }


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


entriesOf : List (Item id msg) -> List (Entry msg)
entriesOf items =
    items
        |> List.foldl
            (\(Item data) ( seen, kept ) ->
                if Set.member data.key seen then
                    ( seen, kept )

                else
                    ( Set.insert data.key seen
                    , { key = data.key, label = data.label, content = data.content, fixed = data.fixed } :: kept
                    )
            )
            ( Set.empty, [] )
        |> Tuple.second
        |> List.reverse



-- ATTRIBUTES


{-| A setting of the list. Make them with the functions below and pass a list to
`view`; later attributes win over earlier ones.
-}
type Attribute msg
    = Attribute (Config -> Config)


type alias Config =
    { label : Maybe String
    , horizontal : Bool
    , wholeItem : Bool
    , moveButtons : Bool
    , disabled : Bool
    , emptyText : Maybe String
    , locale : Locale
    }


configure : List (Attribute msg) -> Config
configure attributes =
    List.foldl (\(Attribute change) config -> change config)
        { label = Nothing
        , horizontal = False
        , wholeItem = False
        , moveButtons = False
        , disabled = False
        , emptyText = Nothing
        , locale = Locale.default
        }
        attributes


{-| The accessible name of the list, for example "Pick sequence". Give every list
on a page its own name; without it the list has none.
-}
ariaLabel : String -> Attribute msg
ariaLabel text =
    Attribute (\config -> { config | label = Just text })


{-| The items run side by side (a chip list) instead of one below the other, and
wrap onto more lines when they do not fit. The keyboard moves an item with the
`Left` and `Right` arrow keys instead of `Up` and `Down`. The default is a
vertical list.
-}
horizontal : Attribute msg
horizontal =
    Attribute (\config -> { config | horizontal = True })


{-| Lets the mouse take hold of an item anywhere, not only by its handle, except
on buttons, links, fields and other things that react to a press themselves. A
finger or pen still uses the handle only, so that the rest of the item scrolls the
page. The handle stays: it is how the keyboard and screen readers reach the item.
The default is the handle only.
-}
wholeItem : Attribute msg
wholeItem =
    Attribute (\config -> { config | wholeItem = True })


{-| Gives every item that can move two small buttons at its end, "Move up" and
"Move down" ("Move left" and "Move right" in a `horizontal` list): the way to
reorder for a person who uses a pointer and cannot drag (WCAG 2.5.7). A press moves
the item one place, past no `fixed` item, and lands in `reorder` like a drop; the
live region says where it went, and the focus stays on the button. At the end of
the list the button is dimmed, and a press says that the item cannot move further.
The buttons are named after the item ("Move Scan the tote up"). There are none by
default.
-}
moveButtons : Attribute msg
moveButtons =
    Attribute (\config -> { config | moveButtons = True })


{-| Makes the whole list unchangeable: the handles are dimmed and cannot be used.
The default is `False`.
-}
disabled : Bool -> Attribute msg
disabled value =
    Attribute (\config -> { config | disabled = value })


{-| The text drawn when there are no items. The default is "No items".
-}
emptyText : String -> Attribute msg
emptyText text =
    Attribute (\config -> { config | emptyText = Just text })


{-| The language of the built-in text: the description of the handle, the
announcements, "Fixed position", the names of the `moveButtons` and the empty text.
The default is `Locale.default`, which is English. See [Klar.Locale](Klar-Locale).
-}
locale : Locale -> Attribute msg
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
    , move : Bool -> Int -> String -> String
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
                    "Trykk mellomrom eller Enter for å løfte. Bruk deretter piltastene venstre og høyre for å flytte, mellomrom eller Enter for å slippe, Escape for å avbryte."
                    "Press Space or Enter to pick up. Then use the Left and Right arrow keys to move, Space or Enter to drop, Escape to cancel."

            else
                pick
                    "Trykk mellomrom eller Enter for å løfte. Bruk deretter piltastene opp og ned for å flytte, mellomrom eller Enter for å slippe, Escape for å avbryte."
                    "Press Space or Enter to pick up. Then use the Up and Down arrow keys to move, Space or Enter to drop, Escape to cancel."
    , fixed = pick "Fast plassering" "Fixed position"
    , empty = pick "Ingen elementer" "No items"
    , itemFallback = pick "Elementet" "The item"
    , pickedUp = \label position total -> label ++ pick " er løftet, posisjon " " picked up, position " ++ place position total ++ "."
    , movedTo = \position total -> pick "Flyttet til posisjon " "Moved to position " ++ place position total ++ "."
    , atLimit = \position total -> pick "Posisjon " "Position " ++ place position total ++ pick ". Kan ikke flyttes lenger." ". It cannot move further."
    , dropped = \label position total -> label ++ pick " er sluppet på posisjon " " dropped at position " ++ place position total ++ "."
    , cancelled = \label position total -> pick "Avbrutt. " "Cancelled. " ++ label ++ pick " er tilbake på posisjon " " is back at position " ++ place position total ++ "."
    , move =
        \isHorizontal delta label ->
            case ( isHorizontal, delta < 0 ) of
                ( False, True ) ->
                    pick ("Flytt " ++ label ++ " opp") ("Move " ++ label ++ " up")

                ( False, False ) ->
                    pick ("Flytt " ++ label ++ " ned") ("Move " ++ label ++ " down")

                ( True, True ) ->
                    pick ("Flytt " ++ label ++ " til venstre") ("Move " ++ label ++ " left")

                ( True, False ) ->
                    pick ("Flytt " ++ label ++ " til høyre") ("Move " ++ label ++ " right")
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
to hold back a refresh of the list. When the item has been taken out of your list
meanwhile it is still named here until the state forgets it (see the limits above),
though the page no longer shows it as held.
-}
lifted : Ids id -> State id -> Maybe id
lifted ids (State s) =
    case s.session of
        Just session ->
            if session.lifted then
                Ids.fromKey ids session.source

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
the state after the same `update` call, and your list.

    Sortable.reorder stepIds .id model.sortable sortable model.steps

When the user dropped an item in that `update`, the item moves to its new place and
the rest of the list stays as it is; otherwise the list is returned unchanged. The
two states must be those of one call: a drop is only applied when exactly one drop
happened between them, so a state that you kept from an earlier `update`, or the
same state twice, changes nothing and cannot move an item twice.

The list does not have to be the list that was drawn. The item is found by the id
function you give (`.id`; the first one when a list holds the same id twice). It is
put right behind the item that is above its new place among the items that were
drawn, or, at the top, right in front of the one below it. Items that were not
drawn (a filter hides them) keep their places in relation to each other, and an
item that has gone from your list in the meantime is skipped for the nearest one
that is still there. So hiding some items with a filter, or adding and removing
items while the user holds one, never puts the dropped item somewhere else than
among its new neighbours.

-}
reorder : Ids id -> (a -> id) -> State id -> State id -> List a -> List a
reorder ids toId (State before) (State after) list =
    if after.drops /= before.drops + 1 then
        list

    else
        case after.last of
            Just landing ->
                Order.place (\element -> Ids.toKey ids (toId element)) landing.key landing.to landing.placed list

            Nothing ->
                list



-- VIEW


{-| The list. It takes the constructor that wraps the messages, the attributes, the
state and the items in the order you want them drawn.

    Sortable.view SortableMsg
        [ Sortable.ariaLabel "Pick sequence" ]
        model.sortable
        (List.map (\step -> Sortable.item stepIds step.id step.title (viewStep step)) model.steps)

An empty list draws the `emptyText`. Reordering needs the same `Ids` in `reorder`.

-}
view : (Msg -> msg) -> List (Attribute msg) -> State id -> List (Item id msg) -> Html msg
view toMsg attributes (State drawn) items =
    let
        send =
            toMsg << Msg

        config =
            configure attributes

        t =
            texts config.locale

        entries =
            entriesOf items

        keys =
            List.map .key entries

        flags =
            List.map .fixed entries

        -- An item that is held and was taken out of the list meanwhile is not held
        -- any more as far as the page is concerned (no cursor, no lifted look); the
        -- state forgets it the next time a handle gets the focus or is pressed.
        s =
            case drawn.session of
                Just session ->
                    if List.member session.source keys then
                        drawn

                    else
                        { drawn | session = Nothing }

                Nothing ->
                    drawn

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
            [ Html.text
                (announcement t entries s.note
                    ++ (if s.echo then
                            "\u{00A0}"

                        else
                            ""
                       )
                )
            ]
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

        -- The handle that has just been dropped or cancelled gets the focus back at
        -- once, and the screen reader reads it out. The long instructions would cut
        -- or double what the live region says, so this one handle goes without them
        -- until something else happens.
        justFinished =
            case ( s.session, s.note ) of
                ( Nothing, Just (Dropped key _ _) ) ->
                    key == entry.key

                ( Nothing, Just (Cancelled key _ _) ) ->
                    key == entry.key

                _ ->
                    False

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
                     , Internal.attrIf (not justFinished) (Attr.attribute "aria-describedby" (Machine.helpDomId s.domId))
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
                                , Events.on "focus" (Decode.succeed (toMsg (Machine.Focused keys)))
                                ]
                           )
                    )
                    [ Icon.view Icon.grip ]

        moves =
            if config.moveButtons && movable then
                let
                    ( low, high ) =
                        Order.bounds layout.fixed index
                in
                Html.span [ Internal.cls [ "klar-sortable__moves" ] ]
                    [ moveButton toMsg config t s layout entry (index <= low) -1
                    , moveButton toMsg config t s layout entry (index >= high) 1
                    ]

            else
                Html.text ""
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
        , moves
        ]


{-| A "Move up" or "Move down" button of `moveButtons`. At the end of the list it
stays a button that can hold the focus (a press there says that the item cannot move
further), so the focus does not drop when the item reaches the end.
-}
moveButton : (Machine.Msg -> msg) -> Config -> Texts -> Machine.State -> Layout -> Entry msg -> Bool -> Int -> Html msg
moveButton toMsg config t s layout entry atEnd delta =
    let
        name =
            t.move config.horizontal delta entry.label

        glyph =
            case ( config.horizontal, delta < 0 ) of
                ( False, True ) ->
                    Icon.arrowUp

                ( False, False ) ->
                    Icon.arrowDown

                ( True, True ) ->
                    Icon.arrowLeft

                ( True, False ) ->
                    Icon.arrowRight
    in
    Html.button
        [ Internal.cls [ "klar-sortable__move" ]
        , Attr.id (Machine.moveDomId s.domId entry.key delta)
        , Attr.type_ "button"
        , Attr.attribute "aria-label" name
        , Attr.title name
        , Internal.attrIf atEnd (Attr.attribute "aria-disabled" "true")
        , Events.onClick (toMsg (Machine.MoveBy layout delta))
        ]
        [ Icon.sized Icon.Small glyph ]


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
                    (guard (Decode.field "target" (reachesHandle (not whole || kind /= "mouse") 0)))
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
