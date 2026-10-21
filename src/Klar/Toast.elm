module Klar.Toast exposing
    ( view
    , State, Msg, init, update, maxVisible, count, queued
    , push, clear, dismissAll
    , Attribute, title, message, action
    , tone, info, success, warning, danger, duration, sticky
    , locale
    )

{-| Short notifications that appear in a corner of the window, stack up and go
away by themselves: "Order saved", "Could not send the invoice".

Use a toast for feedback about something the user just did, which needs no
decision. For a message that has to stay on the page use a
[Klar.Alert](Klar-Alert), and for a question a
[Klar.ConfirmDialog](Klar-ConfirmDialog).

    -- model:   toasts : Toast.State Msg       (Toast.init)

    -- update
    OrderSaved ->
        let
            ( toasts, cmd ) =
                Toast.push
                    [ Toast.success
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

    -- view (once, anywhere; it is fixed in the bottom right corner)
    Toast.view ToastMsg [] model.toasts

A toast can carry one action, typically "Undo". Clicking it sends the
application's message and dismisses the toast:

    Toast.push [ Toast.info, Toast.message "Order deleted.", Toast.action "Undo" UndoDelete ] model.toasts

The state holds the application's messages, hence `State msg`.


# View

Render the stack once, always, near the root of the application: it is the live
region that screen readers listen to. Put it in the `overlays` of
[`Modal.host`](Klar-Modal#host) so that the toasts stay usable while a dialog is
open. New toasts are announced politely, without interrupting what the screen
reader is saying; a `danger` toast is announced at once (`role="alert"`). Every
toast has a close button, and one with an action has a button for it; both can
be reached with `Tab`.

@docs view


# State

At most `maxVisible` (default 4) toasts are shown; the rest wait in a queue and
take their place, with a fresh timer, as toasts go away (or at once, when you
raise `maxVisible`).

@docs State, Msg, init, update, maxVisible, count, queued


# Showing and removing toasts

@docs push, clear, dismissAll


# Content

@docs Attribute, title, message, action


# Tone and time

An `info` toast (the default) goes away after 5 seconds, a `success` toast after
4 and a `warning` toast after 8; a `danger` toast stays until it is closed. A
toast with an action stays at least 8 seconds. Change it with `duration` or
`sticky`. The timer stops while the pointer is over a toast or focus is inside
it, and starts over when the pointer leaves.

@docs tone, info, success, warning, danger, duration, sticky


# Texts

@docs locale

-}

import Html exposing (Html)
import Html.Attributes as Attr
import Html.Events as Events
import Json.Decode as Decode
import Klar.Button as Button
import Klar.Icon as Icon exposing (Icon)
import Klar.Internal as Internal
import Klar.Locale as Locale exposing (Locale)
import Klar.Theme as Theme exposing (Tone(..))
import Process
import Task



-- STATE


{-| The toasts on screen and the ones waiting in the queue. The type parameter is
your message type, because a toast can carry an action message. Create it with
`init`, keep it in your model, and change it with `push`, `clear` and `update`.
-}
type State msg
    = State
        { visible : List (Item msg)
        , waiting : List (Item msg)
        , nextId : Int
        , max : Int
        }


type alias Item msg =
    { id : Int
    , token : Int
    , tone : Tone
    , title : Maybe String
    , message : String
    , action : Maybe ( String, msg )
    , duration : Maybe Int
    , hovered : Bool
    , focused : Bool

    -- Has the timer of the current token been started? `arm` starts it for a
    -- toast on screen that is not held; a toast that `maxVisible` moved up from
    -- the queue waits for the next `update` or `push` to do so.
    , armed : Bool
    }


{-| No toasts. Up to four are shown at once; change that with `maxVisible`.
-}
init : State msg
init =
    State { visible = [], waiting = [], nextId = 1, max = 4 }


{-| How many toasts are shown at once (at least 1; the default is 4). Set it when
you create the state, for example `Toast.init |> Toast.maxVisible 3`. Raising it
later moves the toasts that are waiting in the queue up at once, and their
timers start with the next `push` or `update`; lowering it hides nothing.
-}
maxVisible : Int -> State msg -> State msg
maxVisible n (State state) =
    State (promote { state | max = max 1 n })


{-| The number of toasts on screen plus the ones in the queue.
-}
count : State msg -> Int
count (State state) =
    List.length state.visible + List.length state.waiting


{-| The number of toasts waiting in the queue because `maxVisible` toasts are
already on screen.
-}
queued : State msg -> Int
queued (State state) =
    List.length state.waiting


{-| Removes every toast at once, the ones on screen and the ones in the queue.
-}
clear : State msg -> State msg
clear (State state) =
    State { state | visible = [], waiting = [] }


{-| Same as `clear`.
-}
dismissAll : State msg -> State msg
dismissAll =
    clear


{-| The messages of the toast stack (timers, dismissing, and the pause while a
toast is hovered or focused). Wrap it in a constructor of your own message type,
such as `ToastMsg Toast.Msg`, and hand it to `update`.
-}
type Msg
    = Expire Int Int
    | Dismiss Int
    | Hover Int Bool
    | Focus Int Bool


{-| Handles timers, dismissing and the pause while a toast is hovered or focused.
Map its command into your own message with `Cmd.map`.
-}
update : Msg -> State msg -> ( State msg, Cmd Msg )
update msg state =
    arm (step msg state)


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

        Focus id on ->
            hold id (\item -> { item | focused = on }) current


{-| Adds a toast built from the attributes. The command starts its timer: map it
into your own message. When `maxVisible` toasts are already on screen, the new
one waits in the queue.

    Toast.push [ Toast.warning, Toast.message "Stock is running low." ] model.toasts

-}
push : List (Attribute msg) -> State msg -> ( State msg, Cmd Msg )
push attributes (State state) =
    let
        config =
            configure attributes

        item =
            { id = state.nextId
            , token = 0
            , tone = config.tone
            , title = config.title
            , message = config.message
            , action = config.action
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
    State (promote { state | visible = List.filter (\item -> item.id /= id) state.visible })


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
        , Cmd.batch (List.map startTimer (List.filter ready state.visible))
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


startTimer : Item msg -> Cmd Msg
startTimer item =
    case item.duration of
        Just ms ->
            Process.sleep (toFloat ms)
                |> Task.perform (\_ -> Expire item.id item.token)

        Nothing ->
            Cmd.none


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
        , duration = Nothing
        , locale = Locale.default
        }
        attributes


{-| The tone of the toast: `Info` (the default), `Success`, `Warning` or `Danger`.
It sets the icon, the color of the accent and how long the toast stays on
screen. `info`, `success`, `warning` and `danger` are shorthands.
-}
tone : Tone -> Attribute msg
tone value =
    Attribute (\config -> { config | tone = value })


{-| A plain notice with a blue accent. Goes away after 5 seconds. This is the
default.
-}
info : Attribute msg
info =
    tone Info


{-| Something went well: a green accent and a check mark. Goes away after 4
seconds.
-}
success : Attribute msg
success =
    tone Success


{-| Something needs attention: an amber accent and a warning sign. Goes away
after 8 seconds.
-}
warning : Attribute msg
warning =
    tone Warning


{-| Something went wrong: a red accent and an error sign. Stays until the user
closes it, and is announced to screen readers at once (`role="alert"`).
-}
danger : Attribute msg
danger =
    tone Danger


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
Render it once, always, even when there are no toasts (it is the live region
screen readers listen to). Of the attributes only `locale` has an effect here.
-}
view : (Msg -> msg) -> List (Attribute msg) -> State msg -> Html msg
view toMsg attributes (State state) =
    let
        config =
            configure attributes

        waiting =
            List.length state.waiting
    in
    Html.div
        [ Internal.cls [ "klar-toasts" ]
        , Attr.attribute "role" "region"
        , Attr.attribute "aria-label" (Locale.pick config.locale { nb = "Varsler", en = "Notifications" })
        , Attr.attribute "aria-live" "polite"
        , Attr.attribute "aria-relevant" "additions text"
        ]
        (List.map (viewItem toMsg config.locale) state.visible
            ++ [ if waiting > 0 then
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
               ]
        )


viewItem : (Msg -> msg) -> Locale -> Item msg -> Html msg
viewItem toMsg language item =
    Html.div
        ([ Internal.cls [ "klar-toast", "klar-toast--" ++ Theme.toneSuffix item.tone ]
         , Events.onMouseEnter (toMsg (Hover item.id True))
         , Events.onMouseLeave (toMsg (Hover item.id False))
         , Events.on "focusin" (Decode.succeed (toMsg (Focus item.id True)))
         , Events.on "focusout" (Decode.succeed (toMsg (Focus item.id False)))
         ]
            ++ (if item.tone == Danger then
                    [ Attr.attribute "role" "alert" ]

                else
                    []
               )
        )
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
                        [ Button.view [ Button.small, Button.onClick msg ] label ]

                Nothing ->
                    Html.text ""
            ]
        , Button.iconOnly
            [ Button.ghost
            , Button.small
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
