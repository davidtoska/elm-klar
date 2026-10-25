module Page.Gallery.Structured exposing (Model, Msg, init, subscriptions, update, view)

{-| Gallery page: structured input. Identifiers that have a fixed shape and a check
digit (IBAN, organisation number, bank account, postal code, phone number, a pattern of
your own), and exact money: amounts that are never a `Float`.
-}

import Html exposing (Html)
import Klar.Button as Button
import Klar.Layout as Layout
import Klar.Locale exposing (Locale)
import Klar.MaskedInput as MaskedInput
import Klar.Money as Money exposing (Currency, Money)
import Klar.MoneyInput as MoneyInput
import Klar.NumberInput as NumberInput
import Klar.Text as Text
import Showcase.Doc as Doc



-- MODEL


type alias Model =
    { iban : MaskedInput.State
    , orgnr : MaskedInput.State
    , account : MaskedInput.State
    , gtin : MaskedInput.State
    , postalNo : MaskedInput.State
    , postalNl : MaskedInput.State
    , postalCountry : String
    , phone : MaskedInput.State
    , sku : MaskedInput.State
    , nok : MoneyInput.State
    , jpy : MoneyInput.State
    , kwd : MoneyInput.State
    , signed : MoneyInput.State
    , shared : MoneyInput.State
    , parts : NumberInput.State
    }


type Msg
    = IbanMsg MaskedInput.Msg
    | OrgnrMsg MaskedInput.Msg
    | AccountMsg MaskedInput.Msg
    | GtinMsg MaskedInput.Msg
    | PostalNoMsg MaskedInput.Msg
    | PostalNlMsg MaskedInput.Msg
    | PostalCountryPicked String
    | PhoneMsg MaskedInput.Msg
    | SkuMsg MaskedInput.Msg
    | NokMsg MoneyInput.Msg
    | JpyMsg MoneyInput.Msg
    | KwdMsg MoneyInput.Msg
    | SignedMsg MoneyInput.Msg
    | SharedMsg MoneyInput.Msg
    | PartsMsg NumberInput.Msg


init : ( Model, Cmd Msg )
init =
    ( { iban = MaskedInput.init "structured-iban" MaskedInput.iban
      , orgnr = MaskedInput.init "structured-orgnr" MaskedInput.norwegianOrganisationNumber
      , account = MaskedInput.init "structured-account" MaskedInput.norwegianBankAccount
      , gtin = MaskedInput.init "structured-gtin" MaskedInput.ean13
      , postalNo = MaskedInput.init "structured-postal-no" MaskedInput.norwegianPostalCode
      , postalNl = MaskedInput.init "structured-postal-nl" (MaskedInput.postalCode "NL" |> Maybe.withDefault MaskedInput.norwegianPostalCode)
      , postalCountry = "NL"
      , phone = MaskedInput.init "structured-phone" MaskedInput.phone
      , sku = MaskedInput.init "structured-sku" skuMask
      , nok = MoneyInput.init "structured-nok" Money.nok
      , jpy = MoneyInput.init "structured-jpy" Money.jpy
      , kwd = MoneyInput.init "structured-kwd" kuwaitiDinar
      , signed = MoneyInput.init "structured-signed" Money.eur
      , shared = MoneyInput.setValue (Money.fromMinor Money.nok 10000) (MoneyInput.init "structured-shared" Money.nok)
      , parts = NumberInput.setValue (Just 3) (NumberInput.init "structured-parts")
      }
    , Cmd.none
    )


{-| A pattern that is known to be good. The application of a pattern that comes from
somewhere else handles the `Nothing`.
-}
skuMask : MaskedInput.Mask
skuMask =
    MaskedInput.pattern "@@-####" |> Maybe.withDefault MaskedInput.norwegianPostalCode


{-| A currency from a code that came from data: it can fail, and has three decimals.
-}
kuwaitiDinar : Currency
kuwaitiDinar =
    Money.currency "KWD" |> Maybe.withDefault Money.nok


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        IbanMsg inner ->
            masked inner model.iban (\state -> { model | iban = state }) IbanMsg

        OrgnrMsg inner ->
            masked inner model.orgnr (\state -> { model | orgnr = state }) OrgnrMsg

        AccountMsg inner ->
            masked inner model.account (\state -> { model | account = state }) AccountMsg

        GtinMsg inner ->
            masked inner model.gtin (\state -> { model | gtin = state }) GtinMsg

        PostalNoMsg inner ->
            masked inner model.postalNo (\state -> { model | postalNo = state }) PostalNoMsg

        PostalNlMsg inner ->
            masked inner model.postalNl (\state -> { model | postalNl = state }) PostalNlMsg

        PostalCountryPicked country ->
            -- the field keeps what was typed, written in the groups of the new country
            case MaskedInput.postalCode country of
                Just mask ->
                    ( { model | postalCountry = country, postalNl = MaskedInput.setMask mask model.postalNl }, Cmd.none )

                Nothing ->
                    ( model, Cmd.none )

        PhoneMsg inner ->
            masked inner model.phone (\state -> { model | phone = state }) PhoneMsg

        SkuMsg inner ->
            masked inner model.sku (\state -> { model | sku = state }) SkuMsg

        NokMsg inner ->
            money inner model.nok (\state -> { model | nok = state }) NokMsg

        JpyMsg inner ->
            money inner model.jpy (\state -> { model | jpy = state }) JpyMsg

        KwdMsg inner ->
            money inner model.kwd (\state -> { model | kwd = state }) KwdMsg

        SignedMsg inner ->
            money inner model.signed (\state -> { model | signed = state }) SignedMsg

        SharedMsg inner ->
            money inner model.shared (\state -> { model | shared = state }) SharedMsg

        PartsMsg inner ->
            let
                ( state, cmd ) =
                    NumberInput.update inner model.parts
            in
            ( { model | parts = state }, Cmd.map PartsMsg cmd )


masked : MaskedInput.Msg -> MaskedInput.State -> (MaskedInput.State -> Model) -> (MaskedInput.Msg -> Msg) -> ( Model, Cmd Msg )
masked inner state store toMsg =
    let
        ( next, cmd ) =
            MaskedInput.update inner state
    in
    ( store next, Cmd.map toMsg cmd )


money : MoneyInput.Msg -> MoneyInput.State -> (MoneyInput.State -> Model) -> (MoneyInput.Msg -> Msg) -> ( Model, Cmd Msg )
money inner state store toMsg =
    let
        ( next, cmd ) =
            MoneyInput.update inner state
    in
    ( store next, Cmd.map toMsg cmd )


subscriptions : Model -> Sub Msg
subscriptions _ =
    Sub.none



-- VIEW


view : Locale -> Model -> Html Msg
view locale model =
    Doc.page
        { title = "Structured input"
        , description = "Masked input for phone numbers, IBAN and the like, and exact money input."
        }
        [ viewIdentifiers locale model
        , viewCodes locale model
        , viewMoney locale model
        , viewSharing locale model
        ]


{-| Examples side by side, as many columns as fit.
-}
grid : List (Html msg) -> Html msg
grid children =
    Layout.grid [ Layout.minColumn 260, Layout.gap 5, Layout.alignStart ] children


{-| What the application knows about an identifier: the value, or why there is none.
-}
readout : MaskedInput.State -> Html msg
readout state =
    Text.caption
        (case MaskedInput.value state of
            Just identifier ->
                "Value: " ++ identifier

            Nothing ->
                if MaskedInput.isValid state then
                    "No value yet"

                else if MaskedInput.isComplete state then
                    "Complete, but the check digits are wrong: no value"

                else
                    "Not complete: no value"
        )



-- IDENTIFIERS WITH A CHECK DIGIT


viewIdentifiers : Locale -> Model -> Html Msg
viewIdentifiers locale model =
    Doc.section "Identifiers with a check digit"
        "The field writes the groups while the user types, and says what is wrong in words: the length of the IBAN of the country, the check digit, a character that does not belong. Separators can be typed or left out. Letters in a field for digits are not dropped; they stay and are reported. The value is Nothing until the identifier is complete and its check digits are right. Try the IBANs NO93 8601 1117 947 and DE89 3704 0044 0532 0130 00, and the organisation number 974 760 673. Errors that more typing cannot fix show at once; an unfinished value is an error when the field is left. An edit in the middle of the text is kept as typed until you type at the end or leave the field."
        [ Doc.example
            { title = "IBAN"
            , description = Just "The countries of the SWIFT IBAN registry, each with its length (a country that joined recently may be missing). The check digits are tested with modulus 97."
            , code = Just ibanCode
            }
            (Layout.stack [ Layout.gap 2 ]
                [ MaskedInput.view IbanMsg
                    [ MaskedInput.label "IBAN"
                    , MaskedInput.hint "For example NO93 8601 1117 947 or DE89 3704 0044 0532 0130 00."
                    , MaskedInput.locale locale
                    ]
                    model.iban
                , readout model.iban
                ]
            )
        , Doc.example
            { title = "Organisation number and bank account"
            , description = Just "Norwegian numbers with a check digit (modulus 11). The value is the digits; the groups are only for reading."
            , code = Just orgnrCode
            }
            (grid
                [ Layout.stack [ Layout.gap 2 ]
                    [ MaskedInput.view OrgnrMsg [ MaskedInput.label "Organisation number", MaskedInput.required, MaskedInput.locale locale ] model.orgnr
                    , readout model.orgnr
                    ]
                , Layout.stack [ Layout.gap 2 ]
                    [ MaskedInput.view AccountMsg [ MaskedInput.label "Bank account", MaskedInput.hint "For example 8601.11.17947.", MaskedInput.locale locale ] model.account
                    , readout model.account
                    ]
                ]
            )
        , Doc.example
            { title = "Product barcode"
            , description = Just "The GTIN-13 (EAN-13) under the barcode of a product, with its check digit (modulus 10). A scanner that types the number and Enter works too. Try 5901234123457."
            , code = Just "MaskedInput.init \"article-gtin\" MaskedInput.ean13"
            }
            (Layout.stack [ Layout.gap 2 ]
                [ MaskedInput.view GtinMsg [ MaskedInput.label "EAN-13", MaskedInput.locale locale ] model.gtin
                , readout model.gtin
                ]
            )
        ]


ibanCode : String
ibanCode =
    """MaskedInput.init "supplier-iban" MaskedInput.iban

MaskedInput.view IbanMsg
    [ MaskedInput.label "IBAN"
    , MaskedInput.hint "For example NO93 8601 1117 947."
    ]
    model.iban

-- Just "NO9386011117947" when it is complete and right
MaskedInput.value model.iban"""


orgnrCode : String
orgnrCode =
    """MaskedInput.init "supplier-orgnr" MaskedInput.norwegianOrganisationNumber
MaskedInput.init "supplier-account" MaskedInput.norwegianBankAccount

MaskedInput.view OrgnrMsg
    [ MaskedInput.label "Organisation number", MaskedInput.required ]
    model.orgnr"""



-- POSTAL CODES, PHONE NUMBERS AND A PATTERN OF YOUR OWN


viewCodes : Locale -> Model -> Html Msg
viewCodes locale model =
    Doc.section "Postal codes, phone numbers and codes of your own"
        "A postal code has no check digit, so the application knows which ones exist. The phone number is the international form with a country code (+47 912 34 567); it is a help for typing, not a phone number database. A pattern of your own is made with a tiny language, and an invalid pattern is a Nothing that the application sees at once."
        [ Doc.example
            { title = "Postal codes"
            , description = Just "Each country writes them in its own way: 0150 in Norway, 123 45 in Sweden, 1234 AB in the Netherlands (in capitals, with the space). The second field is the postal code of an address: when its country changes, setMask gives it the rule of the new country and keeps what was typed."
            , code = Just postalCode
            }
            (grid
                [ Layout.stack [ Layout.gap 2 ]
                    [ MaskedInput.view PostalNoMsg [ MaskedInput.label "Postal code (Norway)", MaskedInput.locale locale ] model.postalNo
                    , readout model.postalNo
                    ]
                , Layout.stack [ Layout.gap 2 ]
                    [ Layout.row [ Layout.gap 2, Layout.wrap ]
                        (List.map
                            (\( code, name ) ->
                                Button.view
                                    [ Button.small
                                    , Button.pressed (model.postalCountry == code)
                                    , Button.onClick (PostalCountryPicked code)
                                    ]
                                    name
                            )
                            [ ( "NO", "Norway" ), ( "SE", "Sweden" ), ( "NL", "The Netherlands" ) ]
                        )
                    , MaskedInput.view PostalNlMsg [ MaskedInput.label "Postal code of the address", MaskedInput.locale locale ] model.postalNl
                    , readout model.postalNl
                    ]
                ]
            )
        , Doc.example
            { title = "Phone number"
            , description = Just "+47 numbers have eight digits and are written 912 34 567 (mobile) or 22 12 34 56; others have 7 to 15 digits in groups of three. Spaces, hyphens and parentheses are not part of the value."
            , code = Just phoneCode
            }
            (Layout.stack [ Layout.gap 2 ]
                [ MaskedInput.view PhoneMsg [ MaskedInput.label "Phone", MaskedInput.hint "With the country code, like +47.", MaskedInput.locale locale ] model.phone
                , readout model.phone
                ]
            )
        , Doc.example
            { title = "A pattern of your own"
            , description = Just "@ is a letter, # a digit, * either, and any other character is written by the field and is not in the value: the SKU AB-1234 has the value AB1234 and the text AB-1234."
            , code = Just skuCode
            }
            (Layout.stack [ Layout.gap 2 ]
                [ MaskedInput.view SkuMsg [ MaskedInput.label "SKU", MaskedInput.hint "Two letters, a hyphen and four digits.", MaskedInput.locale locale ] model.sku
                , readout model.sku
                , Text.caption ("Text: " ++ MaskedInput.text model.sku)
                ]
            )
        ]


postalCode : String
postalCode =
    """MaskedInput.norwegianPostalCode

-- Nothing for a country that is not in the list
MaskedInput.postalCode "NL" -- Just (a mask for 1234 AB)

-- the country of the address changed: the same field, the new rule
case MaskedInput.postalCode country of
    Just mask ->
        { model | postal = MaskedInput.setMask mask model.postal }

    Nothing ->
        model"""


phoneCode : String
phoneCode =
    """MaskedInput.init "contact-phone" MaskedInput.phone

MaskedInput.view PhoneMsg [ MaskedInput.label "Phone" ] model.phone

-- Just "+4791234567"
MaskedInput.value model.phone"""


skuCode : String
skuCode =
    """case MaskedInput.pattern "@@-####" of
    Just sku ->
        MaskedInput.init "article-sku" sku

    Nothing ->
        -- a pattern that makes no sense
        ..."""



-- MONEY


viewMoney : Locale -> Model -> Html Msg
viewMoney locale model =
    Doc.section "Money"
        "An amount is a whole number of minor units and a currency, never a Float. The field reads 1 234,50 and 1,234.50 and 'kr 1 234,50'; it writes the amount with the decimals of the currency when it is left; it never rounds what was typed. More decimals than the currency has is an error (try 12.505 in NOK), and so is an amount outside the limits, which stays in the field as typed. In Norwegian, 10.000 is refused as unclear rather than read as ten, since many people write ten thousand that way. The currency code stands at the end of the field."
        [ Doc.example
            { title = "NOK, JPY and KWD"
            , description = Just "Two decimals, none, and three. Each has a minimum and a maximum. Try 12,5 and 12.505 in NOK, 1500 and 1.5 in JPY, and 1.234 in KWD."
            , code = Just moneyCode
            }
            (grid
                [ moneyField locale NokMsg model.nok "Price (NOK)" (limits Money.nok 1000 500000)
                , moneyField locale JpyMsg model.jpy "Price (JPY)" (limits Money.jpy 100 500000)
                , moneyField locale KwdMsg model.kwd "Price (KWD)" (limits kuwaitiDinar 500 1000000)
                ]
            )
        , Doc.example
            { title = "A negative amount"
            , description = Just "Refused by default, because most amounts are not negative; allowNegative accepts a minus sign and parentheses: (100,50) is -100.50."
            , code = Just negativeCode
            }
            (Layout.stack [ Layout.gap 2 ]
                [ MoneyInput.view SignedMsg
                    [ MoneyInput.label "Credit note"
                    , MoneyInput.allowNegative
                    , MoneyInput.alignRight
                    , MoneyInput.locale locale
                    ]
                    model.signed
                , readoutMoney locale model.signed
                ]
            )
        ]


{-| The smallest and the largest amount, in minor units of a currency.
-}
limits : Currency -> Int -> Int -> ( Money, Money )
limits cur low high =
    ( Money.fromMinor cur low |> Maybe.withDefault (Money.zero cur)
    , Money.fromMinor cur high |> Maybe.withDefault (Money.zero cur)
    )


moneyField : Locale -> (MoneyInput.Msg -> Msg) -> MoneyInput.State -> String -> ( Money, Money ) -> Html Msg
moneyField locale toMsg state label ( low, high ) =
    Layout.stack [ Layout.gap 2 ]
        [ MoneyInput.view toMsg
            [ MoneyInput.label label
            , MoneyInput.min low
            , MoneyInput.max high
            , MoneyInput.alignRight
            , MoneyInput.locale locale
            ]
            state
        , readoutMoney locale state
        ]


{-| What the application knows about an amount: the amount and its minor units.
-}
readoutMoney : Locale -> MoneyInput.State -> Html msg
readoutMoney locale state =
    Text.caption
        (case MoneyInput.value state of
            Just amount ->
                "Money: "
                    ++ Money.toString locale amount
                    ++ " = "
                    ++ String.fromInt (Money.toMinor amount)
                    ++ " minor units"
                    ++ (if MoneyInput.isValid state then
                            ""

                        else
                            " (not acceptable)"
                       )

            Nothing ->
                "No amount"
        )


moneyCode : String
moneyCode =
    """MoneyInput.init "line-price" Money.nok

MoneyInput.view PriceMsg
    [ MoneyInput.label "Price"
    , MoneyInput.min (Money.zero Money.nok)
    , MoneyInput.max maxPrice
    ]
    model.price

-- Maybe Money; Money.toMinor gives the minor units
MoneyInput.value model.price

-- a currency from data can fail
Money.currency "KWD" -- Just (3 decimals)"""


negativeCode : String
negativeCode =
    """MoneyInput.view CreditMsg
    [ MoneyInput.label "Credit note"
    , MoneyInput.allowNegative
    ]
    model.credit"""



-- SHARING AN AMOUNT


viewSharing : Locale -> Model -> Html Msg
viewSharing locale model =
    Doc.section "Exact arithmetic"
        "Splitting an amount never loses a minor unit, and a percentage is rounded half away from zero, as a person does by hand. Money of different currencies cannot be added: that is an Err, not a wrong sum."
        [ Doc.example
            { title = "Split an amount"
            , description = Just "100.00 in three is 33.34, 33.33 and 33.33: the unit that does not divide goes to the first part. The parts always add up to the amount."
            , code = Just splitCode
            }
            (Layout.stack [ Layout.gap 4 ]
                [ grid
                    [ MoneyInput.view SharedMsg
                        [ MoneyInput.label "Amount"
                        , MoneyInput.alignRight
                        , MoneyInput.locale locale
                        ]
                        model.shared
                    , NumberInput.view PartsMsg
                        [ NumberInput.label "Parts"
                        , NumberInput.min 1
                        , NumberInput.max 12
                        , NumberInput.decimals 0
                        , NumberInput.locale locale
                        ]
                        model.parts
                    ]
                , viewParts locale model
                ]
            )
        ]


viewParts : Locale -> Model -> Html msg
viewParts locale model =
    case ( MoneyInput.value model.shared, NumberInput.value model.parts ) of
        ( Just amount, Just parts ) ->
            case Money.split (round parts) amount of
                Ok shares ->
                    let
                        vat =
                            Money.percentOf 25 amount
                                |> Result.map (Money.toString locale)
                                |> Result.withDefault "too large"
                    in
                    Layout.stack [ Layout.gap 2 ]
                        [ Text.paragraphWith
                            [ Text.strong "Parts: "
                            , Text.mono (String.join ", " (List.map (Money.toAmountString locale) shares))
                            ]
                        , Text.caption
                            ("Sum of the parts: "
                                ++ (Money.sum (Money.currencyOf amount) shares
                                        |> Result.map (Money.toString locale)
                                        |> Result.withDefault "?"
                                   )
                                ++ ". Rounded half away from zero, 25 percent of the amount is "
                                ++ vat
                                ++ "."
                            )
                        ]

                Err problem ->
                    Text.caption (Money.problemText locale problem)

        _ ->
            Text.caption "Enter an amount and the number of parts."


splitCode : String
splitCode =
    """Money.split 3 amount
    --> Ok [ 33.34, 33.33, 33.33 ]   -- for 100.00

Money.allocate [ 50, 30, 20 ] amount
    --> Ok [ 50.00, 30.00, 20.00 ]

Money.percentOf 25 amount
    --> Ok 25.00                     -- half away from zero

Money.add nokAmount eurAmount
    --> Err (Cannot mix NOK and EUR)"""
