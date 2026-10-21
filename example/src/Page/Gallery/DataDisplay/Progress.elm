module Page.Gallery.DataDisplay.Progress exposing (Model, Msg, init, update, view)

{-| The progress section: bars, steps and rings.
-}

import Html exposing (Html)
import Klar.Button as Button
import Klar.Layout as Layout
import Klar.Locale exposing (Locale)
import Klar.Progress as Progress
import Klar.Theme exposing (Size(..), Tone(..))
import Showcase.Doc as Doc


type alias Model =
    { value : Float
    }


type Msg
    = SetValue Float


init : Model
init =
    { value = 62 }


update : Msg -> Model -> Model
update msg model =
    case msg of
        SetValue value ->
            { model | value = clamp 0 100 value }


view : Locale -> Model -> Html Msg
view locale model =
    let
        bar attributes =
            Progress.view (Progress.locale locale :: attributes)

        ring attributes =
            Progress.ring (Progress.locale locale :: attributes)
    in
    Doc.section "Progress"
        "Bars, steps and rings. All of them are role=progressbar with aria-valuenow (left out when the length is unknown) and a text for screen readers. The track is a lighter step of the color of the bar."
        [ Doc.example
            { title = "Bar"
            , description = Just "The value is a percentage. outOf 3 5 sets the value and the text to “3 of 5”."
            , code = Just """Progress.view [ Progress.label "Upload", Progress.value 62, Progress.showValue ]

Progress.view [ Progress.label "Importing orders", Progress.indeterminate ]

Progress.view
    [ Progress.label "Checkout"
    , Progress.outOf 3 5
    , Progress.segments 5
    , Progress.showValue
    ]"""
            }
            (Layout.stack [ Layout.gap 5 ]
                [ Layout.stack [ Layout.gap 2 ]
                    [ bar [ Progress.label "Order import", Progress.value model.value, Progress.showValue ]
                    , Layout.row [ Layout.gap 2 ]
                        [ Button.view [ Button.small, Button.onClick (SetValue (model.value - 10)) ] "-10%"
                        , Button.view [ Button.small, Button.onClick (SetValue (model.value + 10)) ] "+10%"
                        ]
                    ]
                , bar [ Progress.label "Importing orders", Progress.indeterminate ]
                , bar [ Progress.label "Checkout", Progress.outOf 3 5, Progress.segments 5, Progress.showValue ]
                , bar [ Progress.label "Striped", Progress.value 45, Progress.striped, Progress.tone Success, Progress.showValue ]
                ]
            )
        , Doc.example
            { title = "Tones and thicknesses"
            , description = Nothing
            , code = Just "Progress.view [ Progress.tone Warning, Progress.size Large, Progress.value 80 ]"
            }
            (Layout.grid [ Layout.minColumn 260, Layout.gap 5 ]
                [ bar [ Progress.label "Primary, thin", Progress.value 30, Progress.size Small, Progress.showValue ]
                , bar [ Progress.label "Neutral", Progress.value 55, Progress.tone Neutral, Progress.showValue ]
                , bar [ Progress.label "Success", Progress.value 100, Progress.tone Success, Progress.showValue ]
                , bar [ Progress.label "Warning, thick", Progress.value 80, Progress.tone Warning, Progress.size Large, Progress.showValue ]
                , bar [ Progress.label "Danger", Progress.value 96, Progress.tone Danger, Progress.showValue ]
                , bar [ Progress.label "Own text", Progress.value 30, Progress.valueText "12 of 40 hours" ]
                , bar [ Progress.label "Outside 0-100 is clipped", Progress.value 140, Progress.showValue ]
                , bar [ Progress.ariaLabel "Without a visible label", Progress.value 70 ]
                ]
            )
        , Doc.example
            { title = "Ring"
            , description = Just "The text in the middle is the value, and a short label when there is room for it."
            , code = Just "Progress.ring [ Progress.value 80, Progress.tone Success, Progress.label \"Done\" ]"
            }
            (Layout.row [ Layout.gap 6, Layout.alignCenter, Layout.wrap ]
                [ ring [ Progress.value model.value, Progress.size Small ]
                , ring [ Progress.value model.value, Progress.label "Import" ]
                , ring [ Progress.value 80, Progress.tone Success, Progress.label "Done" ]
                , ring [ Progress.value 35, Progress.tone Warning, Progress.size Large, Progress.label "Capacity" ]
                , ring [ Progress.value 96, Progress.tone Danger, Progress.size Large, Progress.label "Filled" ]
                , ring [ Progress.indeterminate, Progress.ariaLabel "Loading" ]
                , ring [ Progress.indeterminate, Progress.size Large, Progress.ariaLabel "Loading" ]
                ]
            )
        ]
