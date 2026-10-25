module Page.Gallery.Forms.Validation exposing (Model, Msg, init, sections, update)

{-| The validation section of the forms page: what each validator says, in both
languages, and a field to try them on.
-}

import Api.Types exposing (orderId)
import Html exposing (Html)
import Html.Attributes as Attr
import Html.Events as Events
import Klar.Badge as Badge
import Klar.Field as Field
import Klar.Layout as Layout
import Klar.Locale as Locale exposing (Locale)
import Klar.Text as Text
import Klar.TextInput as TextInput
import Klar.Theme exposing (Tone(..))
import Klar.Validate as Validate
import Page.Gallery.Forms.Common exposing (stack)
import Showcase.Config as Config
import Showcase.Doc as Doc
import Showcase.Options as Options
import Showcase.Sample as Sample


type alias Model =
    { tryValue : String
    }


init : Model
init =
    { tryValue = "ada@" }


type Msg
    = TryChanged String


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        TryChanged value ->
            ( { model | tryValue = value }, Cmd.none )


sections : Config.Config -> Locale -> Model -> List (Html Msg)
sections playground lang model =
    [ Doc.configuredSection playground
        [ "Field" ]
        "Custom form controls"
        "Field connects a custom control to its label, hint and validation message."
        [ Doc.example
            { title = "A native input in a Klar field"
            , description = Just "Type an email address to try the same validation used by the built-in controls."
            , code = Just "Field.view config (Html.input (Field.controlAttributes config ++ [ onInput Changed ]) [])"
            }
            (let
                config =
                    Field.empty
                        |> Field.setId "custom-email"
                        |> Field.setLabel "Customer email"
                        |> Field.setHint "Used for order confirmations."
                        |> Field.setError (Validate.run lang Validate.email model.tryValue)
             in
             Field.view config
                (Html.input
                    (Field.controlAttributes config
                        ++ [ Attr.type_ "email", Attr.value model.tryValue, Events.onInput TryChanged ]
                    )
                    []
                )
            )
        ]
    , validation playground lang model
    ]



-- SAMPLES


{-| A validator with a message of its own that names the value, and a different
rule than the text alone: the order has to exist.
-}
orderExists : Validate.Validator
orderExists =
    Validate.customWith
        (\locale value ->
            case Sample.orderById (orderId (String.trim value)) of
                Just _ ->
                    Nothing

                Nothing ->
                    Just
                        (Locale.pick locale
                            { nb = "Fant ikke ordren " ++ String.trim value
                            , en = "There is no order " ++ String.trim value
                            }
                        )
        )


{-| The call as it is written, the validator and the value it is run on.
-}
validatorSamples : List ( String, Validate.Validator, String )
validatorSamples =
    [ ( "required", Validate.required, "" )
    , ( "required", Validate.required, "Ada" )
    , ( "minLength 3", Validate.minLength 3, "ab" )
    , ( "maxLength 5", Validate.maxLength 5, "Lovelace" )
    , ( "email", Validate.email, "ada@" )
    , ( "email", Validate.email, "ada@example.com" )
    , ( "phone", Validate.phone, "123" )
    , ( "phone", Validate.phone, "+44 20 7946 0958" )
    , ( "norwegianPhone", Validate.norwegianPhone, "123" )
    , ( "norwegianPhone", Validate.norwegianPhone, "+47 912 34 567" )
    , ( "integerBetween 1 100", Validate.integerBetween 1 100, "101" )
    , ( "integerBetween 1 100", Validate.integerBetween 1 100, "42" )
    , ( "sameAs \"secret\"", Validate.sameAs "secret", "secret2" )
    , ( "digits 9", Validate.digits 9, "91234567" )
    , ( "url", Validate.url, "example.com" )
    , ( "oneOf [ \"open\", \"paid\", \"void\" ]", Validate.oneOf [ "open", "paid", "void" ], "closed" )
    , ( "date", Validate.date, "31.02.2026" )
    , ( "date", Validate.date, "20.10.2026" )
    , ( "notInFuture today", Validate.notInFuture Sample.today, "21.10.2026" )
    , ( "custom (starts with ORD-)", Validate.custom (String.startsWith "ORD-") (\locale -> Locale.pick locale { nb = "Må starte med ORD-", en = "Must start with ORD-" }), "10412" )
    , ( "customWith (order exists)", orderExists, "ORD-99999" )
    , ( "customWith (order exists)", orderExists, "ORD-10001" )
    , ( "all [ required, email ]", Validate.all [ Validate.required, Validate.email ], "" )
    , ( "when False required", Validate.when False Validate.required, "" )
    , ( "required |> withMessage", Validate.required |> Validate.withMessage (\locale -> Locale.pick locale { nb = "Oppgi kundenavn", en = "Enter a customer name" }), " " )
    ]


{-| The validators of the "try it yourself" table.
-}
tryValidators : List ( String, Validate.Validator )
tryValidators =
    [ ( "required", Validate.required )
    , ( "email", Validate.email )
    , ( "phone", Validate.phone )
    , ( "norwegianPhone", Validate.norwegianPhone )
    , ( "integerBetween 1 100", Validate.integerBetween 1 100 )
    , ( "date", Validate.date )
    , ( "minLength 5", Validate.minLength 5 )
    ]



-- VIEW


validation : Config.Config -> Locale -> Model -> Html Msg
validation playground lang model =
    Doc.configuredSection playground
        [ "Validate" ]
        "Validation"
        "Pure functions that give an error message in the chosen language, or nothing when the value is fine. All of them except \"required\" accept an empty value, so optional fields are easy. Validation is pure and can be tested without a browser; the table below is calculated while the page is shown."
        [ Doc.configuredExample playground
            [ "Validate" ]
            { title = "Examples"
            , description = Just "The call, the value, and the result in Norwegian and English. \"OK\" means that the validator finds nothing wrong."
            , code = Just """Validate.run Locale.en Validate.email "ada@"
-- Just "Invalid email address"

Validate.firstError Locale.en [ Validate.required, Validate.minLength 3 ] "ab"
-- Just "Must be at least 3 characters"

Validate.collect Locale.en
    [ ( "order-customer", [ Validate.required ], model.customer )
    , ( "order-email", [ Validate.required, Validate.email ], model.email )
    ]
-- List { field : String, message : String }"""
            }
            (validatorTable playground
                (List.map
                    (\( call, validator, value ) ->
                        { call = call
                        , value = "\"" ++ value ++ "\""
                        , nb = Validate.run Locale.nb validator value
                        , en = Validate.run Locale.en validator value
                        }
                    )
                    validatorSamples
                )
            )
        , Doc.configuredExample playground
            [ "Validate" ]
            { title = "Try it yourself"
            , description = Just "Type a value and see what each validator says."
            , code = Just """TextInput.view [ TextInput.label "Value", TextInput.value model.text, TextInput.onInput TextChanged ]"""
            }
            (stack playground
                [ TextInput.view
                    (Options.klarTextInput playground
                        (List.concat
                            [ Config.keep playground "TextInput" "label" (TextInput.label "Value")
                            , Config.keep playground "TextInput" "id" (TextInput.id "try-value")
                            , Config.keep playground "TextInput" "value" (TextInput.value model.tryValue)
                            , Config.keep playground "TextInput" "onInput" (TextInput.onInput TryChanged)
                            , Config.keep playground "TextInput" "clearable" TextInput.clearable
                            , Config.keep playground "TextInput" "locale" (TextInput.locale lang)
                            , Config.keep playground "TextInput" "placeholder" (TextInput.placeholder "Type something, for example an email address")
                            ]
                        )
                    )
                , validatorTable playground
                    (List.map
                        (\( call, validator ) ->
                            { call = call
                            , value = "\"" ++ model.tryValue ++ "\""
                            , nb = Validate.run Locale.nb validator model.tryValue
                            , en = Validate.run Locale.en validator model.tryValue
                            }
                        )
                        tryValidators
                    )
                ]
            )
        ]


validatorTable : Config.Config -> List { call : String, value : String, nb : Maybe String, en : Maybe String } -> Html msg
validatorTable playground rows =
    Layout.grid (Options.klarLayout playground (List.concat [ Config.keep playground "Layout" "columns" (Layout.columns 4), Config.keep playground "Layout" "gap" (Layout.gap 2) ]))
        (List.map Text.overline [ "Call", "Value", "Norwegian", "English" ]
            ++ List.concatMap
                (\row -> [ Text.mono row.call, Text.mono row.value, resultBadge playground row.nb, resultBadge playground row.en ])
                rows
        )


resultBadge : Config.Config -> Maybe String -> Html msg
resultBadge playground result =
    case result of
        Nothing ->
            Layout.row (Options.klarLayout playground []) [ Options.badgeView playground (Options.klarBadge playground (List.concat [ Config.keep playground "Badge" "tone" (Badge.tone Success) ])) "OK" ]

        Just message ->
            Text.secondary message
