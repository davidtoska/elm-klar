module Klar.Stepper exposing
    ( view, progress
    , Step, step, withDescription, failed, disabledStep
    , Attribute, current, onSelect, vertical, small, ariaLabel, locale
    )

{-| The steps of a wizard or a checkout flow, laid out horizontally or vertically.

Use when: the user needs to see where they are in the steps of a wizard or a checkout flow.
Do not use when: you need switchable views of the same thing (use `Klar.Tabs`) or a plain progress measure (use `Klar.Progress`).

    import Klar.Stepper as Stepper

    steps : List Stepper.Step
    steps =
        [ Stepper.step "Customer"
        , Stepper.step "Shipping"
            |> Stepper.withDescription "Address and carrier"
        , Stepper.step "Payment"
            |> Stepper.failed
        , Stepper.step "Review"
        ]

    -- in the view
    Stepper.view
        [ Stepper.current model.step
        , Stepper.onSelect GoToStep
        ]
        steps

The stepper only shows where the user is. It keeps no state and decides nothing:
your model holds the index of the current step, and `onSelect` reports a click on
another step.

Steps are numbered from 0. The step with the index given to `current` is the
current one, the steps before it are complete and the ones after it are upcoming.
Mark exceptions on the step itself: `failed` (validation did not pass) and
`disabledStep` (not available yet). With `onSelect` every step that is not
disabled becomes a button, so disable the steps that must not be visited yet.

The steps are an ordered list. The current step has `aria-current="step"`, and a
step that is complete, failed or disabled is also announced in words ("completed",
"has errors", "unavailable"), because the marker alone does not reach screen
readers.

`progress` is the matching one-line summary, "Step 2 of 5", a good companion on
narrow screens or above a form:

    Stepper.progress [ Stepper.current model.step ] steps

The built-in text follows `locale` (English by default).


# Views

@docs view, progress


# Steps

@docs Step, step, withDescription, failed, disabledStep


# Attributes

@docs Attribute, current, onSelect, vertical, small, ariaLabel, locale

-}

import Html exposing (Html)
import Html.Attributes as Attr
import Html.Events as Events
import Klar.Icon as Icon
import Klar.Internal as Internal
import Klar.Locale as Locale exposing (Locale)



-- STEPS


{-| One step of the flow. Make it with `step` and refine it with
`withDescription`, `failed` and `disabledStep`.
-}
type Step
    = Step
        { label : String
        , description : Maybe String
        , failed : Bool
        , disabled : Bool
        }


{-| A step with a label. Whether it is complete, current or upcoming follows from
its place in the list and from `current`. The marker shows the number of the step
(counting from 1), or a check mark once the step is complete.

    Stepper.step "Shipping"

-}
step : String -> Step
step label =
    Step { label = label, description = Nothing, failed = False, disabled = False }


{-| A line of small gray text under the label, for a hint about what the step
holds.
-}
withDescription : String -> Step -> Step
withDescription text (Step config) =
    Step { config | description = Just text }


{-| Marks the step as having a problem: a red marker with an exclamation mark, and
"has errors" read out for screen readers. The step keeps its red marker whether
it is before, at or after the current step, and the current step keeps
`aria-current="step"` even when it has failed.
-}
failed : Step -> Step
failed (Step config) =
    Step { config | failed = True }


{-| A step that cannot be opened (yet): drawn muted, with "unavailable" read out
for screen readers, and a disabled button when `onSelect` is used. It takes
precedence over `failed` and over the position of the step.
-}
disabledStep : Step -> Step
disabledStep (Step config) =
    Step { config | disabled = True }



-- ATTRIBUTES


{-| A setting of the stepper. Make them with the functions below and pass a list
to `view` or `progress`; later attributes win over earlier ones. The `msg` is
your message type, used by `onSelect`.
-}
type Attribute msg
    = Attribute (Config msg -> Config msg)


type alias Config msg =
    { current : Int
    , vertical : Bool
    , small : Bool
    , onSelect : Maybe (Int -> msg)
    , ariaLabel : Maybe String
    , locale : Locale
    }


configure : List (Attribute msg) -> Config msg
configure attributes =
    List.foldl (\(Attribute change) config -> change config)
        { current = 0
        , vertical = False
        , small = False
        , onSelect = Nothing
        , ariaLabel = Nothing
        , locale = Locale.default
        }
        attributes


{-| The index of the current step, counting from 0 (default 0). The steps before
it are complete and the steps after it are upcoming. An index outside the list is
moved to the nearest step, in `view` and in `progress` alike, so an index past the
end makes the last step the current one.
-}
current : Int -> Attribute msg
current value =
    Attribute (\config -> { config | current = value })


{-| Stacks the steps from top to bottom, for sidebars and steps with long
descriptions. The default is a horizontal row.
-}
vertical : Attribute msg
vertical =
    Attribute (\config -> { config | vertical = True })


{-| Smaller markers, 20px instead of 26px, for tight spaces.
-}
small : Attribute msg
small =
    Attribute (\config -> { config | small = True })


{-| Turns the steps into buttons that send their index (counting from 0) when
they are clicked or activated with the keyboard. The current step is a button
too. Steps marked with `disabledStep` stay disabled; without `onSelect` no step
is clickable.

    Stepper.onSelect GoToStep

-}
onSelect : (Int -> msg) -> Attribute msg
onSelect toMsg =
    Attribute (\config -> { config | onSelect = Just toMsg })


{-| The accessible name of the list of steps. Default "Progress" (in the language
of `locale`).
-}
ariaLabel : String -> Attribute msg
ariaLabel value =
    Attribute (\config -> { config | ariaLabel = Just value })


{-| The language of the built-in text: the name of the list, the status read out
for a step ("completed", "has errors", "unavailable") and the "Step 2 of 5"
summary of `progress`. Default `Locale.en`.
-}
locale : Locale -> Attribute msg
locale value =
    Attribute (\config -> { config | locale = value })



-- VIEW


type Status
    = Complete
    | Current
    | Upcoming
    | Failed
    | Disabled


statusOf : Int -> Int -> Step -> Status
statusOf currentIndex index (Step config) =
    if config.disabled then
        Disabled

    else if config.failed then
        Failed

    else if index < currentIndex then
        Complete

    else if index == currentIndex then
        Current

    else
        Upcoming


statusSuffix : Status -> String
statusSuffix status =
    case status of
        Complete ->
            "complete"

        Current ->
            "current"

        Upcoming ->
            "upcoming"

        Failed ->
            "failed"

        Disabled ->
            "disabled"


{-| The steps, connected by thin lines, as an ordered list. In a horizontal row a
label that does not fit is cut with an ellipsis, and a row with very many steps
scrolls sideways (the row can take the keyboard focus, so that it can be scrolled
with the arrow keys); a vertical list wraps long labels and descriptions instead.
-}
view : List (Attribute msg) -> List Step -> Html msg
view attributes steps =
    let
        config =
            configure attributes

        total =
            List.length steps

        inList =
            { config | current = clampStep total config.current }
    in
    Html.ol
        [ Internal.cls
            [ "klar-stepper"
            , if config.vertical then
                "klar-stepper--vertical"

              else
                "klar-stepper--horizontal"
            , if config.small then
                "klar-stepper--sm"

              else
                ""
            ]
        , Attr.attribute "aria-label"
            (Maybe.withDefault (Locale.pick config.locale { nb = "Fremdrift", en = "Progress" }) config.ariaLabel)

        -- a row with very many steps scrolls sideways: it takes the focus, so that the
        -- arrow keys can scroll it
        , Internal.attrIf (not config.vertical) (Attr.tabindex 0)
        ]
        (List.indexedMap (viewStep inList total) steps)


{-| The index of the current step, moved into the list of `total` steps.
-}
clampStep : Int -> Int -> Int
clampStep total index =
    clamp 0 (max 0 (total - 1)) index


viewStep : Config msg -> Int -> Int -> Step -> Html msg
viewStep config total index ((Step data) as theStep) =
    let
        status =
            statusOf config.current index theStep

        isCurrent =
            index == config.current

        isLast =
            index == total - 1

        marker =
            Html.span [ Internal.cls [ "klar-stepper__marker" ], Attr.attribute "aria-hidden" "true" ]
                [ case status of
                    Complete ->
                        Icon.sized Icon.Small Icon.check

                    Failed ->
                        Html.text "!"

                    _ ->
                        Html.text (String.fromInt (index + 1))
                ]

        statusText =
            case status of
                Complete ->
                    Just (Locale.pick config.locale { nb = "fullført", en = "completed" })

                Failed ->
                    Just (Locale.pick config.locale { nb = "har feil", en = "has errors" })

                Disabled ->
                    Just (Locale.pick config.locale { nb = "utilgjengelig", en = "unavailable" })

                _ ->
                    Nothing

        text =
            Html.span [ Internal.cls [ "klar-stepper__text" ] ]
                [ Html.span [ Internal.cls [ "klar-stepper__label" ] ]
                    [ Html.text data.label
                    , case statusText of
                        Just hidden ->
                            Html.span [ Internal.cls [ "klar-sr-only" ] ] [ Html.text (" (" ++ hidden ++ ")") ]

                        Nothing ->
                            Html.text ""
                    ]
                , Internal.viewMaybe
                    (\description -> Html.span [ Internal.cls [ "klar-stepper__description" ] ] [ Html.text description ])
                    data.description
                ]

        headClasses =
            Internal.cls [ "klar-stepper__head" ]

        head =
            case config.onSelect of
                Just toMsg ->
                    clickable toMsg index isCurrent headClasses data.label marker text (status == Disabled)

                Nothing ->
                    Html.div
                        [ headClasses
                        , Attr.title data.label
                        , Internal.attrIf isCurrent (Attr.attribute "aria-current" "step")
                        , Internal.attrIf (status == Disabled) (Attr.attribute "aria-disabled" "true")
                        ]
                        [ marker, text ]
    in
    Html.li
        [ Internal.cls
            [ "klar-stepper__step"
            , "klar-stepper__step--" ++ statusSuffix status
            , if isLast then
                "klar-stepper__step--last"

              else
                ""
            , if index < config.current then
                "klar-stepper__step--passed"

              else
                ""
            ]
        ]
        [ head
        , Internal.viewIf (not isLast) (Html.span [ Internal.cls [ "klar-stepper__line" ], Attr.attribute "aria-hidden" "true" ] [])
        ]


clickable : (Int -> msg) -> Int -> Bool -> Html.Attribute msg -> String -> Html msg -> Html msg -> Bool -> Html msg
clickable toMsg index isCurrent headClasses label marker text isDisabled =
    Html.button
        [ headClasses
        , Attr.title label
        , Attr.type_ "button"
        , Attr.disabled isDisabled
        , Internal.attrIf isCurrent (Attr.attribute "aria-current" "step")
        , Events.onClick (toMsg index)
        ]
        [ marker, text ]


{-| A one-line summary such as "Step 2 of 5", followed by the label of the current
step, as a polite live region so that screen readers announce the change. Takes
the same attributes and steps as `view`, but only `current` and `locale` matter;
a `current` outside the list is moved to the nearest step.

    Stepper.progress [ Stepper.current model.step ] steps

-}
progress : List (Attribute msg) -> List Step -> Html msg
progress attributes steps =
    let
        config =
            configure attributes

        total =
            List.length steps

        position =
            clampStep total config.current

        label =
            steps
                |> List.drop position
                |> List.head
                |> Maybe.map (\(Step data) -> data.label)
    in
    Html.p
        [ Internal.cls [ "klar-stepper-progress" ]
        , Attr.attribute "role" "status"
        , Attr.attribute "aria-live" "polite"
        ]
        [ Html.span [ Internal.cls [ "klar-stepper-progress__count", "klar-tabular" ] ]
            [ Html.text
                (Locale.pick config.locale { nb = "Steg ", en = "Step " }
                    ++ String.fromInt
                        (if total == 0 then
                            0

                         else
                            position + 1
                        )
                    ++ Locale.pick config.locale { nb = " av ", en = " of " }
                    ++ String.fromInt total
                )
            ]
        , Internal.viewMaybe
            (\text -> Html.span [ Internal.cls [ "klar-stepper-progress__label" ] ] [ Html.text text ])
            label
        ]
