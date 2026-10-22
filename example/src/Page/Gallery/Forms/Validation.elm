module Page.Gallery.Forms.Validation exposing (Model, Msg, init, sections, update)

{-| The validation section of the forms page: what each validator says, in both
languages, and a field to try them on.
-}

import Api.Types exposing (orderId)
import Html exposing (Html)
import Klar.Badge as Badge
import Klar.Layout as Layout
import Klar.Locale as Locale exposing (Locale)
import Klar.Text as Text
import Klar.TextInput as TextInput
import Klar.Theme exposing (Tone(..))
import Klar.Validate as Validate
import Page.Gallery.Forms.Common exposing (stack)
import Showcase.Doc as Doc
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


sections : Locale -> Model -> List (Html Msg)
sections lang model =
    [ validation lang model ]



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
    , ( "matches \"secret\"", Validate.matches "secret", "secret2" )
    , ( "oneOf [ \"open\", \"paid\", \"void\" ]", Validate.oneOf [ "open", "paid", "void" ], "closed" )
    , ( "date", Validate.date, "31.02.2026" )
    , ( "date", Validate.date, "20.10.2026" )
    , ( "notInFuture today", Validate.notInFuture Sample.today, "21.10.2026" )
    , ( "custom (starts with ORD-)", Validate.custom (String.startsWith "ORD-") { nb = "Må starte med ORD-", en = "Must start with ORD-" }, "10412" )
    , ( "customWith (order exists)", orderExists, "ORD-99999" )
    , ( "customWith (order exists)", orderExists, "ORD-10001" )
    , ( "all [ required, email ]", Validate.all [ Validate.required, Validate.email ], "" )
    , ( "when False required", Validate.when False Validate.required, "" )
    , ( "required |> withMessage", Validate.required |> Validate.withMessage { nb = "Oppgi kundenavn", en = "Enter a customer name" }, " " )
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


validation : Locale -> Model -> Html Msg
validation lang model =
    Doc.section "Validation"
        "Pure functions that give an error message in the chosen language, or nothing when the value is fine. All of them except \"required\" accept an empty value, so optional fields are easy. Validation is pure and can be tested without a browser; the table below is calculated while the page is shown."
        [ Doc.example
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
            (validatorTable
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
        , Doc.example
            { title = "Try it yourself"
            , description = Just "Type a value and see what each validator says."
            , code = Just """TextInput.view [ TextInput.label "Value", TextInput.value model.text, TextInput.onInput TextChanged ]"""
            }
            (stack
                [ TextInput.view
                    [ TextInput.label "Value"
                    , TextInput.id "try-value"
                    , TextInput.value model.tryValue
                    , TextInput.onInput TryChanged
                    , TextInput.clearable
                    , TextInput.locale lang
                    , TextInput.placeholder "Type something, for example an email address"
                    ]
                , validatorTable
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


validatorTable : List { call : String, value : String, nb : Maybe String, en : Maybe String } -> Html msg
validatorTable rows =
    Layout.grid [ Layout.columns 4, Layout.gap 2 ]
        (List.map Text.overline [ "Call", "Value", "Norwegian", "English" ]
            ++ List.concatMap
                (\row -> [ Text.mono row.call, Text.mono row.value, resultBadge row.nb, resultBadge row.en ])
                rows
        )


resultBadge : Maybe String -> Html msg
resultBadge result =
    case result of
        Nothing ->
            Layout.row [] [ Badge.view [ Badge.tone Success ] "OK" ]

        Just message ->
            Text.secondary message
