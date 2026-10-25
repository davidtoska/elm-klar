module Klar.StateMachine exposing (Machine, State, Transition, transition, view, Attribute, locale, onTransition)

{-| A small state machine diagram with enabled event buttons and explicit returns.

Use when: inspecting a step's lifecycle or letting a person trigger valid state events.
Do not use when: modelling a multi-step process; use `Klar.Workflow`.

    import Klar.StateMachine as Machine

    lifecycle =
        { states = [ { id = "draft", label = "Draft", terminal = False }, { id = "ready", label = "Ready", terminal = True } ]
        , transitions = [ { from = "draft", to = "ready", event = "Approve" } ]
        , current = "draft"
        }

    Machine.view [ Machine.onTransition SendEvent ] lifecycle

The host owns state and persistence. `transition` only accepts events from the
current nonterminal state with exactly one matching transition to a known state.

@docs Machine, State, Transition, transition, view, Attribute, locale, onTransition

-}

import Html exposing (Html)
import Html.Attributes as Attr
import Klar.Button as Button
import Klar.Locale as Locale exposing (Locale)


{-| Application-owned states, transitions and the current state identifier.
-}
type alias Machine id =
    { states : List (State id), transitions : List (Transition id), current : id }


{-| A named state. Terminal states do not offer events.
-}
type alias State id =
    { id : id, label : String, terminal : Bool }


{-| An event-labelled arrow between states.
-}
type alias Transition id =
    { from : id, to : id, event : String }


{-| Return the new machine for a valid, unambiguous event, otherwise `Nothing`.
-}
transition : String -> Machine id -> Maybe (Machine id)
transition event machine =
    let
        active =
            List.filter (\s -> s.id == machine.current) machine.states
    in
    case ( active, List.filter (\t -> t.from == machine.current && t.event == event) machine.transitions ) of
        ( [ state ], [ t ] ) ->
            if not state.terminal && List.length (List.filter (\s -> s.id == t.to) machine.states) == 1 then
                Just { machine | current = t.to }

            else
                Nothing

        _ ->
            Nothing


{-| Language and event callback settings.
-}
type Attribute msg
    = Attribute (Config msg -> Config msg)


type alias Config msg =
    { locale : Locale, onTransition : Maybe (String -> msg) }


{-| Built-in language, English by default.
-}
locale : Locale -> Attribute msg
locale value =
    Attribute (\c -> { c | locale = value })


{-| Receive an enabled event name. The host validates and applies it.
-}
onTransition : (String -> msg) -> Attribute msg
onTransition value =
    Attribute (\c -> { c | onTransition = Just value })


{-| Draw the states in a wrapping strip, outgoing arrows and enabled events.
State names, arrow destinations and current/terminal markers are visible text.
-}
view : List (Attribute msg) -> Machine id -> Html msg
view attributes machine =
    let
        c =
            List.foldl (\(Attribute f) acc -> f acc) { locale = Locale.default, onTransition = Nothing } attributes

        tr en nb =
            Locale.pick c.locale { en = en, nb = nb }

        labelOf id =
            List.filter (\s -> s.id == id) machine.states |> List.head |> Maybe.map .label |> Maybe.withDefault "?"

        stateView state =
            Html.li
                ([ Attr.classList [ ( "klar-state-machine__state", True ), ( "klar-state-machine__state--current", state.id == machine.current ) ] ]
                    ++ (if state.id == machine.current then
                            [ Attr.attribute "aria-current" "step" ]

                        else
                            []
                       )
                )
                [ Html.strong [] [ Html.text state.label ]
                , Html.small []
                    [ Html.text
                        (if state.terminal then
                            tr "Terminal" "Sluttilstand"

                         else if state.id == machine.current then
                            tr "Current state" "Gjeldende tilstand"

                         else
                            ""
                        )
                    ]
                , Html.div [ Attr.class "klar-state-machine__events" ]
                    (List.filter (\t -> t.from == state.id) machine.transitions
                        |> List.map
                            (\t ->
                                Button.view
                                    ([ Button.ghost, Button.small, Button.disabled (state.id /= machine.current || transition t.event machine == Nothing || c.onTransition == Nothing) ] ++ (c.onTransition |> Maybe.map (\send -> Button.onClick (send t.event)) |> Maybe.map List.singleton |> Maybe.withDefault []))
                                    (t.event ++ " → " ++ labelOf t.to)
                            )
                    )
                ]
    in
    Html.section [ Attr.class "klar-state-machine", Attr.attribute "aria-label" (tr "State machine" "Tilstandsmaskin") ]
        [ Html.p [ Attr.attribute "role" "status", Attr.attribute "aria-live" "polite" ] [ Html.text (tr "Current state: " "Gjeldende tilstand: " ++ labelOf machine.current) ]
        , Html.ol [ Attr.class "klar-state-machine__states" ] (List.map stateView machine.states)
        ]
