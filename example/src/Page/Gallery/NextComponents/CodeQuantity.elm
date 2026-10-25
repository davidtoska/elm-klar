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
import Showcase.Config as Config
import Showcase.Options as Options


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


attributes : Config.Config -> Locale -> List (Quantity.Attribute msg)
attributes playground locale =
    Options.klarQuantityInput playground
        (List.concat
            [ Config.keep playground "QuantityInput" "label" (Quantity.label "Shipment mass")
            , Config.keep playground "QuantityInput" "required" Quantity.required
            , Config.keep playground "QuantityInput" "hint" (Quantity.hint "Change kg to g: the number stays exactly as typed. Conversion is a separate business decision.")
            , Config.keep playground "QuantityInput" "locale" (Quantity.locale locale)
            ]
        )
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


view : Config.Config -> Settings -> Locale -> Model -> Html Msg
view playground _ locale model =
    let
        status result =
            case result of
                Err message ->
                    Options.alertView playground (Options.klarAlert playground (List.concat [ Config.keep playground "Alert" "tone" (Alert.tone Warning), Config.keep playground "Alert" "compact" Alert.compact ])) message

                Ok Nothing ->
                    Text.secondary "No quantity entered."

                Ok (Just quantity) ->
                    Text.code ("{ amount = " ++ String.fromFloat quantity.amount ++ ", unit = " ++ Ids.toKey unitIds quantity.unit ++ " }")

        discountCatalogue =
            { ids = unitIds, units = [ Quantity.unit Percent "Percent" "%" ] }

        discountAttributes =
            Options.klarQuantityInput playground (List.concat [ Config.keep playground "QuantityInput" "label" (Quantity.label "Discount"), Config.keep playground "QuantityInput" "locale" (Quantity.locale locale), Config.keep playground "QuantityInput" "required" Quantity.required ]) ++ (Quantity.between 0 100 |> Maybe.map (Quantity.limits >> List.singleton) |> Maybe.withDefault [])
    in
    Layout.stack (Options.klarLayout playground (List.concat [ Config.keep playground "Layout" "gap" (Layout.gap 6) ]))
        [ Config.only playground
            [ "QuantityInput" ]
            (Card.view (Options.klarCard playground (List.concat [ Config.keep playground "Card" "title" (Card.title "QuantityInput: exact text, explicit units"), Config.keep playground "Card" "headingLevel" (Card.headingLevel 2) ]))
                [ Layout.stack (Options.klarLayout playground (List.concat [ Config.keep playground "Layout" "gap" (Layout.gap 4) ]))
                    [ Quantity.view QuantityMsg (attributes playground locale) (catalogue model) model.quantity
                    , Text.secondary ("Raw input: " ++ Quantity.raw model.quantity)
                    , status (Quantity.value (attributes playground locale) (catalogue model) model.quantity)
                    , Quantity.view DiscountMsg discountAttributes discountCatalogue model.discount
                    , status (Quantity.value discountAttributes discountCatalogue model.discount)
                    , Layout.row (Options.klarLayout playground (List.concat [ Config.keep playground "Layout" "gap" (Layout.gap 2), Config.keep playground "Layout" "wrap" Layout.wrap ]))
                        [ Options.buttonView playground
                            (Options.klarButton playground (List.concat [ Config.keep playground "Button" "onClick" (Button.onClick ToggleUnit) ]))
                            (if model.kilogramsAvailable then
                                "Remove kg from catalogue"

                             else
                                "Restore kg to catalogue"
                            )
                        , Options.buttonView playground (Options.klarButton playground (List.concat [ Config.keep playground "Button" "primary" Button.primary, Config.keep playground "Button" "onClick" (Button.onClick Submit) ])) "Validate quantities"
                        , Options.buttonView playground (Options.klarButton playground (List.concat [ Config.keep playground "Button" "onClick" (Button.onClick Reset) ])) "Reset examples"
                        ]
                    , case model.submitted of
                        Just message ->
                            Text.secondary message

                        Nothing ->
                            Html.text ""
                    ]
                ]
            )
        , Config.only playground
            [ "CodeBlock" ]
            (Card.view (Options.klarCard playground (List.concat [ Config.keep playground "Card" "title" (Card.title "CodeBlock: inspect and download the exact source"), Config.keep playground "Card" "headingLevel" (Card.headingLevel 2) ]))
                [ Layout.stack (Options.klarLayout playground (List.concat [ Config.keep playground "Layout" "gap" (Layout.gap 4) ]))
                    [ TextArea.view (Options.klarTextArea playground (List.concat [ Config.keep playground "TextArea" "label" (TextArea.label "Payload to inspect"), Config.keep playground "TextArea" "value" (TextArea.value model.source), Config.keep playground "TextArea" "onInput" (TextArea.onInput Source), Config.keep playground "TextArea" "rows" (TextArea.rows 6) ]))
                    , Options.buttonView playground (Options.klarButton playground (List.concat [ Config.keep playground "Button" "onClick" (Button.onClick TogglePreview), Config.keep playground "Button" "pressed" (Button.pressed model.preview) ])) "Limit preview to three lines"
                    , Code.view
                        (Options.klarCodeBlock playground (List.concat [ Config.keep playground "CodeBlock" "language" (Code.language Code.json), Config.keep playground "CodeBlock" "lineNumbers" (Code.lineNumbers True), Config.keep playground "CodeBlock" "highlightLines" (Code.highlightLines [ 3, 4 ]), Config.keep playground "CodeBlock" "maxHeight" (Code.maxHeight 300), Config.keep playground "CodeBlock" "download" (Code.download "order-payload.json"), Config.keep playground "CodeBlock" "locale" (Code.locale locale) ])
                            ++ (if model.preview then
                                    Options.klarCodeBlock playground (List.concat [ Config.keep playground "CodeBlock" "maxLines" (Code.maxLines 3) ])

                                else
                                    []
                               )
                        )
                        { id = "inspected-payload", label = "Order payload", source = model.source }
                    , Code.view (Options.klarCodeBlock playground (List.concat [ Config.keep playground "CodeBlock" "language" (Code.language Code.elm), Config.keep playground "CodeBlock" "lineNumbers" (Code.lineNumbers True), Config.keep playground "CodeBlock" "locale" (Code.locale locale) ]))
                        { id = "elm-source-example", label = "Elm: nested comments and strings", source = "{- Shipping policy\n   {- Internal note: review exceptions. -}\n-}\npolicy order =\n    if order.total > 500 then\n        \"Review required\"\n    else\n        \"Ready\"\n" }
                    ]
                ]
            )
        ]
