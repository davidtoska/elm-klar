module Klar.Internal.ChoicePopup exposing
    ( holdSearchFocus
    , retryFor
    , search
    , viewChevron
    , viewClearButton
    , viewEmpty
    , viewFooter
    , viewLayer
    , viewSkeleton
    )

{-| Shared DOM primitives for list and tree pickers. The callers own their
selection, keyboard decoders, ARIA targets and freshness regions. Search input
attributes retain the caller's order and popup semantics; the surrounding DOM
stays stable while loading and retry controls change.
-}

import Html exposing (Html)
import Html.Attributes as Attr
import Html.Events as Events
import Json.Decode as Decode
import Klar.EmptyState as EmptyState
import Klar.Icon as Icon exposing (Icon)
import Klar.Internal as Internal
import Klar.Remote as Remote
import Klar.Skeleton as Skeleton
import Klar.Spinner as Spinner


viewLayer : Html.Attribute msg -> msg -> Html msg -> Html msg
viewLayer keys close popup =
    Html.div
        [ Internal.cls [ "klar-layer" ]
        , Events.onClick close
        , keys
        ]
        [ popup ]


holdSearchFocus : msg -> Html.Attribute msg
holdSearchFocus msg =
    Events.preventDefaultOn "mousedown"
        (Decode.at [ "target", "tagName" ] Decode.string
            |> Decode.andThen
                (\tag ->
                    if tag == "INPUT" then
                        Decode.fail "the search box takes the press itself"

                    else
                        Decode.succeed ( msg, True )
                )
        )


viewChevron : Html msg
viewChevron =
    Html.span [ Internal.cls [ "klar-select__chevron" ], Attr.attribute "aria-hidden" "true" ] [ Icon.view Icon.chevronDown ]


viewClearButton : String -> msg -> Html msg
viewClearButton label msg =
    Html.button
        [ Internal.cls [ "klar-input__clear", "klar-select__clear" ]
        , Attr.type_ "button"
        , Attr.tabindex -1
        , Attr.attribute "aria-label" label
        , Attr.title label
        , Internal.onClickStop msg
        ]
        [ Icon.view Icon.close ]


search :
    { config
        | query : String
        , onInput : String -> msg
        , loading : Bool
        , loadingLabel : String
        , clearLabel : String
        , noop : msg
    }
    -> List (Html.Attribute msg)
    -> Html msg
search config attributes =
    Html.div [ Internal.cls [ "klar-select__search" ] ]
        [ Html.span [ Internal.cls [ "klar-select__search-icon" ] ] [ Icon.view Icon.search ]
        , Html.input attributes []
        , -- Keep the loading region in the DOM before its announcement changes.
          Html.span
            [ Internal.cls
                [ if config.loading then
                    "klar-select__search-spinner"

                  else
                    "klar-sr-only"
                ]
            ]
            [ Spinner.view [ Spinner.label config.loadingLabel, Spinner.loading config.loading ] ]
        , if config.loading then
            Html.text ""

          else if config.query /= "" then
            Html.button
                [ Internal.cls [ "klar-input__clear" ]
                , Attr.type_ "button"
                , Attr.tabindex -1
                , Attr.attribute "aria-label" config.clearLabel
                , Attr.title config.clearLabel
                , Internal.onMouseDownPrevent config.noop
                , Events.onClick (config.onInput "")
                ]
                [ Icon.view Icon.close ]

          else
            Html.text ""
        ]


viewFooter : String -> List (Html msg) -> Html msg
viewFooter status actions =
    Html.div [ Internal.cls [ "klar-select__footer" ] ]
        [ Html.span
            [ Internal.cls [ "klar-select__status", "klar-tabular", "klar-truncate" ]
            , Attr.attribute "role" "status"
            , Attr.attribute "aria-live" "polite"
            ]
            [ Html.text status ]
        , if List.isEmpty actions then
            Html.text ""

          else
            Html.div [ Internal.cls [ "klar-select__actions" ] ] actions
        ]


viewSkeleton : Int -> Html msg
viewSkeleton count =
    Html.div [ Internal.cls [ "klar-select__skeleton" ], Attr.attribute "aria-hidden" "true" ]
        (List.range 0 (max 1 count - 1)
            |> List.map
                (\i ->
                    Html.div [ Internal.cls [ "klar-select__skeleton-row" ] ]
                        [ Skeleton.line (Maybe.withDefault 60 (List.head (List.drop (modBy 5 i) [ 72, 48, 84, 60, 40 ]))) ]
                )
        )


viewEmpty : Icon -> String -> Maybe String -> Html msg
viewEmpty icon title description =
    Html.div [ Internal.cls [ "klar-select__state" ] ]
        [ EmptyState.view
            (List.filterMap identity
                [ Just EmptyState.compact
                , Just (EmptyState.icon icon)
                , Just (EmptyState.title title)
                , Maybe.map EmptyState.description description
                ]
            )
        ]


retryFor : Remote.Problem -> Maybe msg -> Maybe msg
retryFor problem onRetry =
    if Remote.isRetryable problem then
        onRetry

    else
        Nothing
