module Klar.RuleBuilder.Count exposing (view)

{-| The match count of `Klar.RuleBuilder` and `Klar.FilterBar`: "1,482 of 3,000
matches", from a `Remote Int`, in every state. The element tree is the same in
every state and the live region is in the page from the start, so the first
count is announced and a retry button keeps its place.

Internal to the rules group.

-}

import Html exposing (Html)
import Html.Attributes as Attr
import Klar.Button as Button
import Klar.Format as Format
import Klar.Icon as Icon
import Klar.Internal as Internal
import Klar.Internal.Freshness as Freshness
import Klar.Locale as Locale exposing (Locale)
import Klar.Remote exposing (Remote(..))
import Klar.Spinner as Spinner
import Klar.Theme as Theme


view :
    { locale : Locale
    , count : Remote Int
    , total : Maybe Int
    , onRetry : Maybe msg
    , retryId : String
    , classes : List String
    }
    -> Html msg
view config =
    let
        t =
            texts config.locale

        number =
            Format.int config.locale

        ( settled, freshness ) =
            Freshness.settle config.count

        counted n =
            case config.total of
                Just total ->
                    [ Html.strong [] [ Html.text (number n) ]
                    , Html.text (" " ++ t.of_ ++ " " ++ number total ++ " " ++ t.hits)
                    ]

                Nothing ->
                    [ Html.strong [] [ Html.text (number n) ]
                    , Html.text (" " ++ t.hits)
                    ]

        stale =
            case freshness of
                Freshness.Stale _ ->
                    True

                _ ->
                    False

        ( content, retry ) =
            case settled of
                Loading ->
                    ( [ Spinner.view [ Spinner.size Theme.Small ], Html.text t.counting ], False )

                Failed _ ->
                    ( [ Html.span [ Internal.cls [ "klar-rule-count__problem" ] ]
                            [ Icon.sized Icon.Small Icon.errorCircle, Html.text t.failed ]
                      ]
                    , True
                    )

                Loaded n ->
                    ( counted n
                        ++ (if Freshness.busy freshness then
                                [ Spinner.view [ Spinner.size Theme.Small ] ]

                            else
                                []
                           )
                        ++ (if stale then
                                [ Html.span [ Internal.cls [ "klar-rule-count__old" ] ] [ Html.text t.old ] ]

                            else
                                []
                           )
                    , stale
                    )

                _ ->
                    ( [], False )
    in
    Html.span
        [ Internal.cls
            ("klar-rule-count"
                :: (if Freshness.busy freshness then
                        "klar-rule-count--refreshing"

                    else
                        ""
                   )
                :: config.classes
            )
        ]
        [ Html.span
            [ Internal.cls [ "klar-rule-count__text", "klar-tabular" ]
            , Attr.attribute "aria-live" "polite"
            , Freshness.busyAttr freshness
            ]
            content
        , case ( retry, config.onRetry ) of
            ( True, Just msg ) ->
                Button.view [ Button.link, Button.id config.retryId, Button.onClick msg ] t.retry

            _ ->
                Html.text ""
        ]


type alias Texts =
    { of_ : String
    , hits : String
    , counting : String
    , failed : String
    , old : String
    , retry : String
    }


texts : Locale -> Texts
texts locale =
    Locale.pick locale
        { nb =
            { of_ = "av"
            , hits = "treff"
            , counting = "Teller ..."
            , failed = "Tellingen feilet"
            , old = "gammelt tall"
            , retry = "Prøv igjen"
            }
        , en =
            { of_ = "of"
            , hits = "matches"
            , counting = "Counting ..."
            , failed = "The count failed"
            , old = "old count"
            , retry = "Retry"
            }
        }
