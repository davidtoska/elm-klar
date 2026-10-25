module Page.Gallery.NextComponents.CodeQuantity exposing (Model, Msg, init, subscriptions, update, view)

{-| Exact source inspection and explicit unit-bearing input.
-}

import Html exposing (Html)
import Klar.Alert as Alert
import Klar.Button as Button
import Klar.Card as Card
import Klar.CodeBlock as Code
import Klar.Ids as Ids exposing (Ids)
import Klar.Layout as Layout
import Klar.Locale exposing (Locale)
import Klar.QuantityInput as Quantity
import Klar.Settings exposing (Settings)
import Klar.Text as Text
import Klar.TextArea as TextArea
import Klar.Theme exposing (Tone(..))


type UnitId
    = Kilograms
    | Grams
    | Percent


unitIds : Ids UnitId
unitIds =
    Ids.list
        (\id ->
            case id of
                Kilograms ->
                    "kg"

                Grams ->
                    "g"

                Percent ->
                    "percent"
        )
        [ Kilograms, Grams, Percent ]


type alias Model =
    { quantity : Quantity.State
    , discount : Quantity.State
    , source : String
    , preview : Bool
    , kilogramsAvailable : Bool
    , submitted : Maybe String
    }


type Msg
    = QuantityMsg Quantity.Msg
    | DiscountMsg Quantity.Msg
    | Source String
    | TogglePreview
    | ToggleUnit
    | Submit
    | Reset


init : ( Model, Cmd Msg )
init =
    ( { quantity = Quantity.init "shipment-mass" |> Quantity.setUnit unitIds Kilograms |> Quantity.setValue "12.50"
      , discount = Quantity.init "shipment-discount" |> Quantity.setUnit unitIds Percent |> Quantity.setValue "25"
      , source = "{\n  \"order\": \"ORD-1042\",\n  \"mass\": { \"amount\": 12.5, \"unit\": \"kg\" },\n  \"discount\": 25,\n  \"approved\": false,\n  \"note\": \"<script> is data here, never executable HTML\"\n}\n"
      , preview = False
      , kilogramsAvailable = True
      , submitted = Nothing
      }
    , Cmd.none
    )


attributes : Locale -> List (Quantity.Attribute msg)
attributes locale =
    [ Quantity.label "Shipment mass"
    , Quantity.required
    , Quantity.hint "Change kg to g: the number stays exactly as typed. Conversion is a separate business decision."
    , Quantity.locale locale
    ]
        ++ (Quantity.between 0 500 |> Maybe.map (Quantity.limits >> List.singleton) |> Maybe.withDefault [])


catalogue : Model -> { ids : Ids UnitId, units : List (Quantity.Unit UnitId) }
catalogue model =
    { ids = unitIds
    , units =
        (if model.kilogramsAvailable then
            [ Quantity.unit Kilograms "Kilograms" "kg" ]

         else
            []
        )
            ++ [ Quantity.unit Grams "Grams" "g" ]
    }


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        QuantityMsg inner ->
            let
                ( quantity, cmd ) =
                    Quantity.update inner model.quantity
            in
            ( { model | quantity = quantity, submitted = Nothing }, Cmd.map QuantityMsg cmd )

        DiscountMsg inner ->
            let
                ( discount, cmd ) =
                    Quantity.update inner model.discount
            in
            ( { model | discount = discount }, Cmd.map DiscountMsg cmd )

        Source source ->
            ( { model | source = source }, Cmd.none )

        TogglePreview ->
            ( { model | preview = not model.preview }, Cmd.none )

        ToggleUnit ->
            ( { model | kilogramsAvailable = not model.kilogramsAvailable, submitted = Nothing }, Cmd.none )

        Submit ->
            ( { model | quantity = Quantity.touch model.quantity, discount = Quantity.touch model.discount, submitted = Just "Validation requested. The live results below use the current locale, limits and unit catalogue." }, Cmd.none )

        Reset ->
            init


subscriptions : Model -> Sub Msg
subscriptions _ =
    Sub.none


view : Settings -> Locale -> Model -> Html Msg
view _ locale model =
    let
        status result =
            case result of
                Err message ->
                    Alert.view [ Alert.tone Warning, Alert.compact ] message

                Ok Nothing ->
                    Text.secondary "No quantity entered."

                Ok (Just quantity) ->
                    Text.code ("{ amount = " ++ String.fromFloat quantity.amount ++ ", unit = " ++ Ids.toKey unitIds quantity.unit ++ " }")

        discountCatalogue =
            { ids = unitIds, units = [ Quantity.unit Percent "Percent" "%" ] }

        discountAttributes =
            [ Quantity.label "Discount", Quantity.locale locale, Quantity.required ] ++ (Quantity.between 0 100 |> Maybe.map (Quantity.limits >> List.singleton) |> Maybe.withDefault [])
    in
    Layout.stack [ Layout.gap 6 ]
        [ Card.view [ Card.title "QuantityInput: exact text, explicit units", Card.headingLevel 2 ]
            [ Layout.stack [ Layout.gap 4 ]
                [ Quantity.view QuantityMsg (attributes locale) (catalogue model) model.quantity
                , Text.secondary ("Raw input: " ++ Quantity.raw model.quantity)
                , status (Quantity.value (attributes locale) (catalogue model) model.quantity)
                , Quantity.view DiscountMsg discountAttributes discountCatalogue model.discount
                , status (Quantity.value discountAttributes discountCatalogue model.discount)
                , Layout.row [ Layout.gap 2, Layout.wrap ]
                    [ Button.view [ Button.onClick ToggleUnit ]
                        (if model.kilogramsAvailable then
                            "Remove kg from catalogue"

                         else
                            "Restore kg to catalogue"
                        )
                    , Button.view [ Button.primary, Button.onClick Submit ] "Validate quantities"
                    , Button.view [ Button.onClick Reset ] "Reset examples"
                    ]
                , case model.submitted of
                    Just message ->
                        Text.secondary message

                    Nothing ->
                        Html.text ""
                ]
            ]
        , Card.view [ Card.title "CodeBlock: inspect and download the exact source", Card.headingLevel 2 ]
            [ Layout.stack [ Layout.gap 4 ]
                [ TextArea.view [ TextArea.label "Payload to inspect", TextArea.value model.source, TextArea.onInput Source, TextArea.rows 6 ]
                , Button.view [ Button.onClick TogglePreview, Button.pressed model.preview ] "Limit preview to three lines"
                , Code.view
                    ([ Code.language Code.json, Code.lineNumbers True, Code.highlightLines [ 3, 4 ], Code.maxHeight 300, Code.download "order-payload.json", Code.locale locale ]
                        ++ (if model.preview then
                                [ Code.maxLines 3 ]

                            else
                                []
                           )
                    )
                    { id = "inspected-payload", label = "Order payload", source = model.source }
                , Code.view [ Code.language Code.elm, Code.lineNumbers True, Code.locale locale ]
                    { id = "elm-source-example", label = "Elm: nested comments and strings", source = "{- Shipping policy\n   {- Internal note: review exceptions. -}\n-}\npolicy order =\n    if order.total > 500 then\n        \"Review required\"\n    else\n        \"Ready\"\n" }
                ]
            ]
        ]
