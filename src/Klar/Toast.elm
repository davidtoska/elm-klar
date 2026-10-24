module Klar.Toast exposing
    ( view
    , State, Msg, init, update, setMaxVisible, count, queued, focus
    , push, dismiss, dismissAll
    , Attribute, title, message, action, key
    , tone, duration, sticky
    , locale
    )

{-| Short notifications that appear in a corner of the window, stack up and go
away by themselves: "Order saved", "Could not send the invoice".

Use when: the user needs feedback about something they just did, which needs no decision.
Do not use when: a message must stay on the page (use `Klar.Alert`) or the user must answer a question (use `Klar.ConfirmDialog`).
Quick path: `init`, `push`, `update`, `view`, `dismissAll`

    import Klar.Theme exposing (Tone(..))
    import Klar.Toast as Toast

    -- model:   toasts : Toast.State Msg       (Toast.init "toasts")

    -- update
    OrderSaved ->
        let
            ( toasts, cmd ) =
                Toast.push
                    [ Toast.tone Success
                    , Toast.title "Order saved"
                    , Toast.message "Order 1042 was updated."
                    ]
                    model.toasts
        in
        ( { model | toasts = toasts }, Cmd.map ToastMsg cmd )

    ToastMsg m ->
        let
            ( toasts, cmd ) =
                Toast.update m model.toasts
        in
        ( { model | toasts = toasts }, Cmd.map ToastMsg cmd )

    -- view (once, in the list of overlays; it is fixed in the bottom right corner)
    Toast.view ToastMsg [] model.toasts

A toast can carry one action, typically "Undo". Clicking it sends the
application's message and dismisses the toast:

    Toast.push [ Toast.message "Order deleted.", Toast.action "Undo" UndoDelete ] model.toasts

The state holds the application's messages, hence `State msg`.

A keyboard user needs a quick way to the "Undo" before it goes away: bind a key to
`focus` with [Klar.Shortcut](Klar-Shortcut) (`F6` or `Alt+T` are the usual ones).
The timer of a toast stops while focus is in it.

    -- shortcuts
    Shortcut.shortcut (Shortcut.function 6) "General" "Go to the notifications" FocusToasts

    -- update
    FocusToasts ->
        ( model, Cmd.map ToastMsg (Toast.focus model.toasts) )


# View

Render the stack once, always, near the root of the application: it is the live
region that screen readers listen to. Put it in the list of overlays of
[`Overlay.host`](Klar-Overlay#host), so that the toasts stay usable while a dialog
is open: they move out of the corner (to the top of the window, or to the other side
of a drawer) and `Tab` reaches them after the footer of the dialog. New toasts are
announced politely, without interrupting what the screen reader is saying; a
`Danger` toast is announced at once. A toast that goes away is not announced, and
neither are the ones that stay. Every toast has a close button, and one with an
action has a button for it; both can be reached with `Tab`. When the toast that has
focus goes away (it was closed, its action ran, or the application dismissed it),
focus moves to the next toast, or back to where it was before it came into the
stack, never to the top of the page.

@docs view


# State

At most `setMaxVisible` (default 4) toasts are shown; the rest wait in a queue and
take their place, with a fresh timer, as toasts go away (or at once, when you
raise the limit).

@docs State, Msg, init, update, setMaxVisible, count, queued, focus


# Showing and removing toasts

@docs push, dismiss, dismissAll


# Content

@docs Attribute, title, message, action, key


# Tone and time

An `Info` toast (the default) goes away after 5 seconds, a `Success` toast after
4 and a `Warning` toast after 8; a `Danger` toast stays until it is closed. A
toast with an action stays at least 8 seconds. Change it with `duration` or
`sticky`. The timer stops while the pointer is over a toast or focus is inside
it, and starts over when the pointer leaves.

@docs tone, duration, sticky


# Texts

@docs locale

-}

import Html exposing (Html)
import Html.Attributes as Attr
import Html.Events as Events
import Html.Keyed as Keyed
import Json.Decode as Decode
import Klar.Button as Button
import Klar.Icon as Icon exposing (Icon)
import Klar.Internal as Internal
import Klar.Locale as Locale exposing (Locale)
import Klar.Overlay as Overlay exposing (Overlay)
import Klar.Overlay.Focus as Focus
import Klar.Theme exposing (Tone(..))
import Process
import Task



-- STATE


{-| The toasts on screen and the ones waiting in the queue. The type parameter is
your message type, because a toast can carry an action message. Create it with
`init`, keep it in your model, and change it with `push`, `dismissAll` and `update`.
-}
type State msg
    = State
        { id : String
        , visible : List (Item msg)
        , waiting : List (Item msg)
        , nextId : Int
        , max : Int

        -- The element that had focus before focus came into the stack: where it
        -- goes back to when the last toast with focus goes away.
        , cameFrom : String

        -- A toast that had focus went away, at this place in the stack: the guard
        -- of the stack brings focus back (to a toast or to `cameFrom`) if it fell
        -- to the page.
        , recover : Maybe Int
        }


type alias Item msg =
    { id : Int
    , token : Int
    , tone : Tone
    , title : Maybe String
    , message : String
    , action : Maybe ( String, msg )
    , key : Maybe String
    , duration : Maybe Int
    , hovered : Bool
    , focused : Bool

    -- Has the timer of the current token been started? `arm` starts it for a
    -- toast on screen that is not held; a toast that `setMaxVisible` moved up from
    -- the queue waits for the next `update` or `push` to do so.
    , armed : Bool
    }


{-| No toasts. The `String` is the DOM id of the stack: unique on the page, and the
ids of the toasts start with it. Up to four toasts are shown at once; change that
with `setMaxVisible`.

    Toast.init "toasts"

-}
init : String -> State msg
init id =
    State { id = id, visible = [], waiting = [], nextId = 1, max = 4, cameFrom = "", recover = Nothing }


{-| How many toasts are shown at once (at least 1; the default is 4). Set it when
you create the state, for example `Toast.init "toasts" |> Toast.setMaxVisible 3`.
Raising it later moves the toasts that are waiting in the queue up at once, and
their timers start with the next `push` or `update`; lowering it hides nothing.
-}
setMaxVisible : Int -> State msg -> State msg
setMaxVisible n (State state) =
    State (promote { state | max = max 1 n })


{-| The number of toasts on screen plus the ones in the queue.
-}
count : State msg -> Int
count (State state) =
    List.length state.visible + List.length state.waiting


{-| The number of toasts waiting in the queue because the most toasts that can be
shown are already on screen.
-}
queued : State msg -> Int
queued (State state) =
    List.length state.waiting


{-| Moves focus to the newest toast on screen: to its action ("Undo") if it has
one, else to its close button. Nothing happens when there is no toast. Bind it to a
key with [Klar.Shortcut](Klar-Shortcut), so that a keyboard user reaches a toast
before it goes away (its timer stops while focus is in it). When that toast goes
away, focus returns to where it was.
-}
focus : State msg -> Cmd Msg
focus (State state) =
    case List.reverse state.visible of
        newest :: _ ->
            Internal.focusFirst
                ((case newest.action of
                    Just _ ->
                        [ actionId state.id newest.id ]

                    Nothing ->
                        []
                 )
                    ++ [ closeId state.id newest.id ]
                )
                Noop

        [] ->
            Cmd.none


{-| Removes the toast with this key (see `key`), on screen or waiting, and lets the
next one in the queue take its place. A key that no toast has changes nothing, so it is
safe to call when the toast may already be gone. Call it from `update`, for example
when a retry succeeded and the failure toast of the first try is stale:

    Toast.dismiss "note-save" model.toasts

If that toast had focus, focus moves to the next toast or back to where it was.

-}
dismiss : String -> State msg -> State msg
dismiss wanted (State state) =
    State (promote (withoutKey wanted state))


{-| Take every toast with this key away, on screen or waiting, and remember the
place of one that had focus.
-}
withoutKey :
    String
    -> { state | visible : List (Item msg), waiting : List (Item msg), recover : Maybe Int }
    -> { state | visible : List (Item msg), waiting : List (Item msg), recover : Maybe Int }
withoutKey wanted state =
    let
        stays item =
            item.key /= Just wanted
    in
    { state
        | visible = List.filter stays state.visible
        , waiting = List.filter stays state.waiting
        , recover = recoverAfter stays state.visible state.recover
    }


{-| If the toast with focus is not among the ones that stay, the place it had.
-}
recoverAfter : (Item msg -> Bool) -> List (Item msg) -> Maybe Int -> Maybe Int
recoverAfter stays items recover =
    List.indexedMap Tuple.pair items
        |> List.filter (\( _, item ) -> item.focused && not (stays item))
        |> List.head
        |> Maybe.map Tuple.first
        |> (\found ->
                case found of
                    Just place ->
                        Just place

                    Nothing ->
                        recover
           )


{-| Removes every toast at once, the ones on screen and the ones in the queue. If
one of them had focus, focus goes back to where it was before it came into the
stack.
-}
dismissAll : State msg -> State msg
dismissAll (State state) =
    State
        { state
            | visible = []
            , waiting = []
            , recover = recoverAfter (\_ -> False) state.visible state.recover
        }


{-| The messages of the toast stack (timers, dismissing, and the pause while a
toast is hovered or focused). Wrap it in a constructor of your own message type,
such as `ToastMsg Toast.Msg`, and hand it to `update`.
-}
type Msg
    = Expire Int Int
    | Dismiss Int
    | Hover Int Bool
    | Focused Int Bool
    | Entered String
    | Lost
    | FocusChain (List String)
    | Noop


{-| Handles timers, dismissing and the pause while a toast is hovered or focused.
Map its command into your own message with `Cmd.map`.
-}
update : Msg -> State msg -> ( State msg, Cmd Msg )
update msg ((State state) as current) =
    case msg of
        FocusChain ids ->
            -- `Tab` went past the last toast: back to the start of the dialog.
            ( current, Internal.focusFirst ids Noop )

        Entered from ->
            ( State { state | cameFrom = from }, Cmd.none )

        Lost ->
            -- The toast that had focus went away and focus fell to the page: to the
            -- toast that took its place, the one before it, or where focus came from.
            case state.recover of
                Just place ->
                    ( State { state | recover = Nothing }
                    , Internal.focusFirst (recoverTargets place (State state)) Noop
                    )

                Nothing ->
                    ( current, Cmd.none )

        _ ->
            arm (step msg current)


recoverTargets : Int -> State msg -> List String
recoverTargets place (State state) =
    let
        closeOf index =
            List.drop index state.visible
                |> List.head
                |> Maybe.map (\item -> closeId state.id item.id)
    in
    List.filterMap identity
        [ closeOf place
        , if place > 0 then
            closeOf (place - 1)

          else
            Nothing
        , closeOf (List.length state.visible - 1)
        , Internal.nonEmpty state.cameFrom
        ]
        ++ [ Internal.pageStartId ]


step : Msg -> State msg -> State msg
step msg ((State state) as current) =
    case msg of
        Expire id token ->
            case findItem id state.visible of
                Just item ->
                    if item.token == token && not (isPaused item) then
                        remove id current

                    else
                        current

                Nothing ->
                    current

        Dismiss id ->
            remove id current

        Hover id on ->
            hold id (\item -> { item | hovered = on }) current

        Focused id on ->
            let
                (State held) =
                    hold id (\item -> { item | focused = on }) current
            in
            -- Focus is in a toast again: nothing to bring back.
            if on then
                State { held | recover = Nothing }

            else
                State held

        Entered _ ->
            current

        Lost ->
            current

        FocusChain _ ->
            current

        Noop ->
            current


{-| Adds a toast built from the attributes. The command starts its timer: map it
into your own message. When the most toasts that can be shown are already on
screen, the new one waits in the queue. A toast with the same `key` as one on
screen or in the queue replaces it.

    Toast.push [ Toast.tone Warning, Toast.message "Stock is running low." ] model.toasts

-}
push : List (Attribute msg) -> State msg -> ( State msg, Cmd Msg )
push attributes (State previous) =
    let
        config =
            configure attributes

        -- a toast with the same key is replaced, on screen or waiting
        state =
            case config.key of
                Just wanted ->
                    withoutKey wanted previous

                Nothing ->
                    previous

        item =
            { id = state.nextId
            , token = 0
            , tone = config.tone
            , title = config.title
            , message = config.message
            , action = config.action
            , key = config.key
            , duration = resolveDuration config
            , hovered = False
            , focused = False
            , armed = False
            }

        advanced =
            { state | nextId = state.nextId + 1 }
    in
    arm
        (State
            (if List.length state.visible < state.max then
                { advanced | visible = state.visible ++ [ item ] }

             else
                { advanced | waiting = state.waiting ++ [ item ] }
            )
        )


{-| Take a toast off the screen and let the next ones in the queue take its
place.
-}
remove : Int -> State msg -> State msg
remove id (State state) =
    let
        stays item =
            item.id /= id
    in
    State
        (promote
            { state
                | visible = List.filter stays state.visible
                , recover = recoverAfter stays state.visible state.recover
            }
        )


{-| Move toasts from the queue to the screen while there is room. Their timers
are not started here (see `arm`).
-}
promote :
    { state | visible : List (Item msg), waiting : List (Item msg), max : Int }
    -> { state | visible : List (Item msg), waiting : List (Item msg), max : Int }
promote state =
    let
        free =
            state.max - List.length state.visible
    in
    { state
        | visible = state.visible ++ List.take free state.waiting
        , waiting = List.drop free state.waiting
    }


{-| Start the timer of every toast on screen that has none that counts: a new
one, one that moved up from the queue, one that was let go after the pointer or
the focus left it. A toast that is held waits until it is let go.
-}
arm : State msg -> ( State msg, Cmd Msg )
arm (State state) =
    let
        ready item =
            not item.armed && not (isPaused item)
    in
    if List.any ready state.visible then
        ( State
            { state
                | visible =
                    List.map
                        (\item ->
                            if ready item then
                                { item | armed = True }

                            else
                                item
                        )
                        state.visible
            }
        , case List.filterMap startTimer (List.filter ready state.visible) of
            [] ->
                -- only toasts that stay until they are closed
                Cmd.none

            timers ->
                Cmd.batch timers
        )

    else
        ( State state, Cmd.none )


{-| Change the hover/focus flags of one toast. The running timer is cancelled
(its token no longer matches) when the toast becomes held or is let go; `arm`
starts a fresh one when it is let go.
-}
hold : Int -> (Item msg -> Item msg) -> State msg -> State msg
hold id change (State state) =
    case findItem id state.visible of
        Nothing ->
            State state

        Just before ->
            let
                changed =
                    change before

                after =
                    if isPaused changed /= isPaused before then
                        { changed | token = changed.token + 1, armed = False }

                    else
                        changed
            in
            State
                { state
                    | visible =
                        List.map
                            (\item ->
                                if item.id == id then
                                    after

                                else
                                    item
                            )
                            state.visible
                }


isPaused : Item msg -> Bool
isPaused item =
    item.hovered || item.focused


findItem : Int -> List (Item msg) -> Maybe (Item msg)
findItem id items =
    List.filter (\item -> item.id == id) items |> List.head


{-| The timer of a toast, if it goes away by itself.
-}
startTimer : Item msg -> Maybe (Cmd Msg)
startTimer item =
    Maybe.map
        (\ms ->
            Process.sleep (toFloat ms)
                |> Task.perform (\_ -> Expire item.id item.token)
        )
        item.duration


resolveDuration : Config msg -> Maybe Int
resolveDuration config =
    case config.duration of
        Just explicit ->
            explicit

        Nothing ->
            let
                base =
                    case config.tone of
                        Danger ->
                            Nothing

                        Warning ->
                            Just 8000

                        Success ->
                            Just 4000

                        _ ->
                            Just 5000
            in
            case ( config.action, base ) of
                ( Just _, Just ms ) ->
                    Just (max ms 8000)

                _ ->
                    base


toastId : String -> Int -> String
toastId stackId id =
    stackId ++ "-" ++ String.fromInt id


closeId : String -> Int -> String
closeId stackId id =
    toastId stackId id ++ "-close"


actionId : String -> Int -> String
actionId stackId id =
    toastId stackId id ++ "-action"



-- ATTRIBUTES


{-| A setting of a toast. Make them with the functions below and pass a list to
`push`; later attributes win over earlier ones. `view` takes the same list type
but only reads `locale`.
-}
type Attribute msg
    = Attribute (Config msg -> Config msg)


type alias Config msg =
    { tone : Tone
    , title : Maybe String
    , message : String
    , action : Maybe ( String, msg )
    , key : Maybe String
    , duration : Maybe (Maybe Int)
    , locale : Locale
    }


configure : List (Attribute msg) -> Config msg
configure attributes =
    List.foldl (\(Attribute change) config -> change config)
        { tone = Info
        , title = Nothing
        , message = ""
        , action = Nothing
        , key = Nothing
        , duration = Nothing
        , locale = Locale.default
        }
        attributes


{-| The tone of the toast (a [`Tone`](Klar-Theme#Tone)). It sets the icon, the
color of the accent and how long the toast stays on screen: `Info`, the default,
is a plain notice with a blue accent (5 seconds); `Success` something that went
well, with a green accent and a check mark (4 seconds); `Warning` something that
needs attention, with an amber accent and a warning sign (8 seconds); `Danger`
something that went wrong, with a red accent and an error sign, which stays until
the user closes it and is announced to screen readers at once. `Neutral` looks
like `Info` with a gray accent.

    Toast.push [ Toast.tone Danger, Toast.message "Could not send the invoice." ] model.toasts

-}
tone : Tone -> Attribute msg
tone value =
    Attribute (\config -> { config | tone = value })


{-| A bold first line above the message.
-}
title : String -> Attribute msg
title value =
    Attribute (\config -> { config | title = Just value })


{-| The text of the toast. It is empty by default, so give a `message`, a `title`
or both.
-}
message : String -> Attribute msg
message value =
    Attribute (\config -> { config | message = value })


{-| One button, usually "Undo". A click sends the message and dismisses the toast.
A toast with an action stays at least 8 seconds, unless you set `duration` or
`sticky`.

    Toast.action "Undo" UndoDelete

-}
action : String -> msg -> Attribute msg
action label msg =
    Attribute (\config -> { config | action = Just ( label, msg ) })


{-| Names the toast, so that the application can take it away from `update` with
`dismiss`, and so that a new toast with the same key replaces the old one instead of
stacking next to it (a second failed save shows one toast, not two).

    Toast.push [ Toast.tone Danger, Toast.key "note-save", Toast.title "Could not save the note" ] model.toasts

-}
key : String -> Attribute msg
key value =
    Attribute (\config -> { config | key = Just value })


{-| Dismiss after this many milliseconds, whatever the tone. The timer stops
while the pointer is over the toast or focus is inside it.
-}
duration : Int -> Attribute msg
duration ms =
    Attribute (\config -> { config | duration = Just (Just ms) })


{-| Stays until the user closes it, whatever the tone.
-}
sticky : Attribute msg
sticky =
    Attribute (\config -> { config | duration = Just Nothing })


{-| For `view`: the language of the built-in text, which is the label of the
stack for screen readers ("Notifications"), the note "+ 2 more waiting" and the
label of the close buttons ("Dismiss notification"). `push` ignores it. The
default is [`Locale.default`](Klar-Locale#default), which is English.
-}
locale : Locale -> Attribute msg
locale value =
    Attribute (\config -> { config | locale = value })



-- VIEW


{-| The stack of toasts, fixed in the bottom right corner above everything else.
Put it in the list of overlays of [`Overlay.host`](Klar-Overlay#host) (or
`AppShell.overlays`), always, even when there are no toasts: it is the live region
screen readers listen to. Of the attributes only `locale` has an effect here.

While a dialog is open the stack moves to the top of the window, so that it never
covers the footer buttons; beside a drawer it goes to the bottom of the other side of
the window, so that the title and the close button of the drawer stay in reach (on a
narrow screen, where the drawer fills the window, it is at the top). It becomes the last stop of the dialog's
`Tab` loop: after the footer, `Tab` goes through the toasts (the action and the
close button of each) and then to the first element of the dialog again.

-}
view : (Msg -> msg) -> List (Attribute msg) -> State msg -> Overlay msg
view toMsg attributes state =
    Overlay.toasts { render = \around -> viewStack toMsg attributes state around.trap }


viewStack : (Msg -> msg) -> List (Attribute msg) -> State msg -> Maybe (List String) -> Html msg
viewStack toMsg attributes (State state) trap =
    let
        config =
            configure attributes

        waiting =
            List.length state.waiting

        keyed item =
            ( String.fromInt item.id, viewItem toMsg config.locale state.id item )

        ( urgent, calm ) =
            List.partition (\item -> item.tone == Danger) state.visible
    in
    Html.div [ Internal.cls [ "klar-contents" ] ]
        [ Html.div
            [ Internal.cls
                [ "klar-toasts"
                , if state.recover == Nothing then
                    ""

                  else
                    "klar-toasts--recover"
                ]
            , Attr.id state.id
            , Events.on "focusin"
                (Decode.field "relatedTarget"
                    (Decode.map2 Tuple.pair (Focus.isInside state.id) (Decode.field "id" Decode.string))
                    |> Decode.andThen
                        (\( inside, from ) ->
                            if inside || from == "" then
                                Decode.fail "not from outside, or from an element without an id"

                            else
                                Decode.succeed (toMsg (Entered from))
                        )
                )
            ]
            [ -- Keyed, so that a toast that goes away takes its own node with it: the
              -- others keep theirs (with the pointer and the focus on them), and the
              -- screen reader hears no text change in them. Two live regions: a
              -- `Danger` toast is announced at once, the others politely.
              Keyed.node "div"
                [ Internal.cls [ "klar-toasts__alerts" ]
                , Attr.attribute "aria-live" "assertive"
                , Attr.attribute "aria-relevant" "additions"
                ]
                (List.map keyed urgent)

            -- A log, not a region: a region is a landmark, and an application can
            -- have two stacks (its own and one of a page) with the same name.
            , Keyed.node "div"
                [ Internal.cls [ "klar-toasts__log" ]
                , Attr.attribute "role" "log"
                , Attr.attribute "aria-label" (Locale.pick config.locale { nb = "Varsler", en = "Notifications" })
                , Attr.attribute "aria-live" "polite"
                , Attr.attribute "aria-relevant" "additions"
                ]
                (List.map keyed calm
                    ++ [ ( "more"
                         , if waiting > 0 then
                            Html.div [ Internal.cls [ "klar-toasts__more" ] ]
                                [ Html.text
                                    (Locale.pick config.locale
                                        { nb = "+ " ++ String.fromInt waiting ++ " til venter"
                                        , en = "+ " ++ String.fromInt waiting ++ " more waiting"
                                        }
                                    )
                                ]

                           else
                            Html.text ""
                         )
                       ]
                )

            -- A toast that had focus went away: if focus fell to the page, this
            -- brings it back to a toast or to where it came from.
            , Internal.viewIf (state.recover /= Nothing) (Focus.guard Focus.Idle (toMsg Lost))
            ]
        , case trap of
            Just ids ->
                -- A dialog is open and its loop of Tab stops ends here: after the
                -- last toast, Tab goes back to the first element of the dialog.
                Html.div
                    [ Internal.cls [ "klar-modal__sentinel" ]
                    , Attr.tabindex 0
                    , Events.onFocus (toMsg (FocusChain ids))
                    ]
                    []

            Nothing ->
                Html.text ""
        ]


viewItem : (Msg -> msg) -> Locale -> String -> Item msg -> Html msg
viewItem toMsg language stackId item =
    Html.div
        [ Internal.cls [ "klar-toast", "klar-toast--" ++ Internal.toneSuffix item.tone ]
        , Attr.id (toastId stackId item.id)
        , Events.onMouseEnter (toMsg (Hover item.id True))
        , Events.onMouseLeave (toMsg (Hover item.id False))
        , Events.on "focusin" (Decode.succeed (toMsg (Focused item.id True)))
        , Events.on "focusout" (Decode.succeed (toMsg (Focused item.id False)))
        ]
        [ Html.span [ Internal.cls [ "klar-toast__icon" ] ] [ Icon.sized Icon.Medium (iconFor item.tone) ]
        , Html.div [ Internal.cls [ "klar-toast__content" ] ]
            [ Internal.viewMaybe (\text -> Html.div [ Internal.cls [ "klar-toast__title" ] ] [ Html.text text ]) item.title
            , Internal.viewIf (item.message /= "") (Html.div [ Internal.cls [ "klar-toast__message" ] ] [ Html.text item.message ])
            , case item.action of
                Just ( label, msg ) ->
                    -- The click bubbles from the button to this wrapper, so one
                    -- click sends the application's message and dismisses.
                    Html.div
                        [ Internal.cls [ "klar-toast__actions" ]
                        , Events.onClick (toMsg (Dismiss item.id))
                        ]
                        [ Button.view [ Button.small, Button.id (actionId stackId item.id), Button.onClick msg ] label ]

                Nothing ->
                    Html.text ""
            ]
        , Button.iconOnly
            [ Button.ghost
            , Button.small
            , Button.id (closeId stackId item.id)
            , Button.onClick (toMsg (Dismiss item.id))
            ]
            Icon.close
            (Locale.pick language { nb = "Lukk varsel", en = "Dismiss notification" })
        ]


iconFor : Tone -> Icon
iconFor value =
    case value of
        Success ->
            Icon.checkCircle

        Warning ->
            Icon.warning

        Danger ->
            Icon.errorCircle

        _ ->
            Icon.info
