module Page.Gallery.Forms.Typing exposing (Model, Msg, init, sections, update)

{-| The sections of the forms page for the controls you type into: text area,
number field, password field and search field.
-}

import Api.Types exposing (Order)
import Dict exposing (Dict)
import Html exposing (Html)
import Klar.Layout as Layout
import Klar.Locale as Locale exposing (Locale)
import Klar.NumberInput as NumberInput
import Klar.PasswordInput as PasswordInput
import Klar.Remote as Remote
import Klar.Search as Search
import Klar.SearchInput as SearchInput
import Klar.Shortcut as Shortcut
import Klar.TextArea as TextArea
import Klar.Theme exposing (Size(..))
import Page.Gallery.Forms.Common exposing (grid, readout, resultTable, showNumber, stack, yesNo)
import Process
import Showcase.Config as Config
import Showcase.Doc as Doc
import Showcase.Options as Options
import Showcase.Sample as Sample
import Task



-- MODEL


{-| The small examples only need to keep what the user does, so each control's
text or state is stored under the DOM id of the control.
-}
type alias Model =
    { texts : Dict String String
    , numbers : Dict String NumberInput.State
    , passwords : Dict String PasswordInput.State
    , searches : Dict String SearchInput.State

    -- the search with a delay, which counts what happens
    , search : SearchInput.State
    , keystrokes : Int
    , searchesStarted : Int
    , searching : Bool
    , hits : Maybe Int
    }


init : Model
init =
    { texts =
        Dict.fromList
            [ ( "ta-fixed", "Leave the parcel at the back door." )
            , ( "ta-small", "Short note" )
            , ( "ta-long", longNote )
            ]
    , numbers =
        Dict.fromList
            [ numberWith "num-total" 12500
            , numberWith "num-discount" 2.5
            , numberWith "num-value" 30
            , numberWith "num-small" 12
            , numberWith "num-large" 5.4
            , numberWith "num-plain" 1234567
            , numberWith "num-format-en" 1234.5
            , numberWith "num-format-nb" 1234.5
            ]
    , passwords =
        Dict.fromList
            [ ( "pw-new", PasswordInput.setValue "password123" (PasswordInput.init "pw-new") )
            , ( "pw-repeat", PasswordInput.reveal (PasswordInput.setValue "secret" (PasswordInput.init "pw-repeat")) )
            , ( "pw-small", PasswordInput.setValue "secret" (PasswordInput.init "pw-small") )
            ]
    , searches =
        Dict.fromList
            [ ( "search-loading", SearchInput.setValue "Fjord" (SearchInput.init "search-loading") ) ]
    , search = SearchInput.init "search-main"
    , keystrokes = 0
    , searchesStarted = 0
    , searching = False
    , hits = Nothing
    }


numberWith : String -> Float -> ( String, NumberInput.State )
numberWith key value =
    ( key, NumberInput.setValue (Just value) (NumberInput.init key) )


{-| A note just under the limit of its counter, which turns amber near the end.
-}
longNote : String
longNote =
    "Order received by phone on Monday. The customer wants delivery to the loading dock at the back of the building, between 8 and 10 in the morning. "
        ++ "Two pallets were picked in the main warehouse; the remaining three lines are on back order and follow when the supplier delivers on Thursday. "
        ++ "The customer has been told about the split shipment and accepted it. The invoice goes to the head office."


textOf : String -> Model -> String
textOf key model =
    Dict.get key model.texts |> Maybe.withDefault ""


numberOf : String -> Model -> NumberInput.State
numberOf key model =
    Dict.get key model.numbers |> Maybe.withDefault (NumberInput.init key)


passwordOf : String -> Model -> PasswordInput.State
passwordOf key model =
    Dict.get key model.passwords |> Maybe.withDefault (PasswordInput.init key)


searchOf : String -> Model -> SearchInput.State
searchOf key model =
    Dict.get key model.searches |> Maybe.withDefault (SearchInput.init key)



-- UPDATE


type Msg
    = NoOp
    | TextChanged String String
    | NumberMsg String NumberInput.Msg
    | PasswordMsg String PasswordInput.Msg
    | SearchMsg SearchInput.Msg
    | SearchDone String
    | SearchStateMsg String SearchInput.Msg


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        NoOp ->
            ( model, Cmd.none )

        TextChanged key value ->
            ( { model | texts = Dict.insert key value model.texts }, Cmd.none )

        NumberMsg key inner ->
            let
                ( state, cmd ) =
                    NumberInput.update inner (numberOf key model)
            in
            ( { model | numbers = Dict.insert key state model.numbers }, Cmd.map (NumberMsg key) cmd )

        PasswordMsg key inner ->
            let
                ( state, cmd ) =
                    PasswordInput.update inner (passwordOf key model)
            in
            ( { model | passwords = Dict.insert key state model.passwords }, Cmd.map (PasswordMsg key) cmd )

        SearchMsg inner ->
            let
                ( search, cmd ) =
                    SearchInput.update inner model.search

                query =
                    SearchInput.committed search

                started =
                    query /= SearchInput.committed model.search

                typed =
                    SearchInput.value search /= SearchInput.value model.search
            in
            ( { model
                | search = search
                , keystrokes =
                    if typed then
                        model.keystrokes + 1

                    else
                        model.keystrokes
                , searchesStarted =
                    if started then
                        model.searchesStarted + 1

                    else
                        model.searchesStarted
                , searching =
                    if started then
                        query /= ""

                    else
                        model.searching
                , hits =
                    if started && query == "" then
                        Nothing

                    else
                        model.hits
              }
            , Cmd.batch
                [ Cmd.map SearchMsg cmd
                , if started && query /= "" then
                    Process.sleep 700 |> Task.perform (\_ -> SearchDone query)

                  else
                    Cmd.none
                ]
            )

        SearchDone query ->
            -- an answer to an older search is ignored
            if query == SearchInput.committed model.search then
                ( { model | searching = False, hits = Just (List.length (findOrders query)) }, Cmd.none )

            else
                ( model, Cmd.none )

        SearchStateMsg key inner ->
            let
                ( state, cmd ) =
                    SearchInput.update inner (searchOf key model)
            in
            ( { model | searches = Dict.insert key state model.searches }, Cmd.map (SearchStateMsg key) cmd )


{-| The "backend" of the search example: a pure search through the customer names
of the 3,000 sample orders.
-}
findOrders : String -> List Order
findOrders query =
    Search.filter .customer query Sample.orders



-- VIEW


sections : Config.Config -> Locale -> Model -> List (Html Msg)
sections playground lang model =
    [ textAreas playground lang model
    , numbers playground lang model
    , passwords playground lang model
    , searches playground lang model
    ]



-- TEXT AREA


textAreas : Config.Config -> Locale -> Model -> Html Msg
textAreas playground lang model =
    let
        field key =
            Options.klarTextArea playground
                (List.concat
                    [ Config.keep playground "TextArea" "id" (TextArea.id key)
                    , Config.keep playground "TextArea" "value" (TextArea.value (textOf key model))
                    , Config.keep playground "TextArea" "onInput" (TextArea.onInput (TextChanged key))
                    , Config.keep playground "TextArea" "locale" (TextArea.locale lang)
                    ]
                )
    in
    Doc.configuredSection playground
        [ "TextArea" ]
        "Text area"
        "Multi-line text. The height is either fixed or grows with the content between a minimum and a maximum (CSS field-sizing, with a fallback for older browsers). A field with a limit shows a counter that turns amber near the end and red when the text is too long; nothing is ever cut, so paste a long text into \"Description\" and it stays, marked red. Tab moves in and out of the field; Enter inserts a new line, and Ctrl+Enter (Cmd+Enter) sends the message of onCtrlEnter."
        [ Doc.configuredExample playground
            [ "TextArea" ]
            { title = "Fixed and growing height"
            , description = Just "On the left four lines that can be dragged larger. On the right: starts at two lines, grows to six and scrolls after that."
            , code = Just """TextArea.view
    [ TextArea.label "Delivery note"
    , TextArea.rows 4
    , TextArea.value model.note
    , TextArea.onInput NoteChanged
    ]

TextArea.view
    [ TextArea.label "Description"
    , TextArea.minRows 2
    , TextArea.maxRows 6
    , TextArea.maxLength 280
    , TextArea.value model.description
    , TextArea.onInput DescriptionChanged
    ]"""
            }
            (grid playground
                320
                [ TextArea.view
                    (Options.klarTextArea playground
                        (List.concat
                            [ Config.keep playground "TextArea" "label" (TextArea.label "Delivery note")
                            , Config.keep playground "TextArea" "hint" (TextArea.hint "Fixed height, four lines. Drag the corner to resize.")
                            , Config.keep playground "TextArea" "rows" (TextArea.rows 4)
                            ]
                        )
                        ++ field "ta-fixed"
                    )
                , TextArea.view
                    (Options.klarTextArea playground
                        (List.concat
                            [ Config.keep playground "TextArea" "label" (TextArea.label "Description")
                            , Config.keep playground "TextArea" "hint" (TextArea.hint "Grows with the text.")
                            , Config.keep playground "TextArea" "placeholder" (TextArea.placeholder "Write several lines ...")
                            , Config.keep playground "TextArea" "minRows" (TextArea.minRows 2)
                            , Config.keep playground "TextArea" "maxRows" (TextArea.maxRows 6)
                            , Config.keep playground "TextArea" "maxLength" (TextArea.maxLength 280)
                            ]
                        )
                        ++ field "ta-grow"
                    )
                ]
            )
        , Doc.configuredExample playground
            [ "TextArea" ]
            { title = "States"
            , description = Just "Required, optional, with an error, read-only, disabled, small, with a long text and without the resize handle."
            , code = Just """TextArea.view [ TextArea.label "Reason", TextArea.required, TextArea.error "The reason must be filled in" ]
TextArea.view [ TextArea.label "Order history", TextArea.readOnly True, TextArea.value history ]
TextArea.view [ TextArea.label "Locked", TextArea.disabled True ]
TextArea.view [ TextArea.label "Fixed", TextArea.rows 3, TextArea.noResize ]"""
            }
            (grid playground
                300
                [ TextArea.view
                    (Options.klarTextArea playground
                        (List.concat
                            [ Config.keep playground "TextArea" "label" (TextArea.label "Reason for cancelling")
                            , Config.keep playground "TextArea" "required" TextArea.required
                            , Config.keep playground
                                "TextArea"
                                "errorMaybe"
                                (TextArea.errorMaybe
                                    (if String.trim (textOf "ta-required" model) == "" then
                                        Just "The reason must be filled in"

                                     else
                                        Nothing
                                    )
                                )
                            ]
                        )
                        ++ field "ta-required"
                    )
                , TextArea.view
                    (Options.klarTextArea playground
                        (List.concat
                            [ Config.keep playground "TextArea" "label" (TextArea.label "Comment")
                            , Config.keep playground "TextArea" "optionalText" (TextArea.optionalText "(optional)")
                            , Config.keep playground "TextArea" "placeholder" (TextArea.placeholder "An optional comment")
                            ]
                        )
                        ++ field "ta-optional"
                    )
                , TextArea.view
                    (Options.klarTextArea playground
                        (List.concat
                            [ Config.keep playground "TextArea" "label" (TextArea.label "Order history (read-only)")
                            , Config.keep playground "TextArea" "id" (TextArea.id "ta-readonly")
                            , Config.keep playground "TextArea" "readOnly" (TextArea.readOnly True)
                            , Config.keep playground "TextArea" "rows" (TextArea.rows 4)
                            , Config.keep playground "TextArea" "value" (TextArea.value longNote)
                            , Config.keep playground "TextArea" "locale" (TextArea.locale lang)
                            ]
                        )
                    )
                , TextArea.view
                    (Options.klarTextArea playground
                        (List.concat
                            [ Config.keep playground "TextArea" "label" (TextArea.label "Locked field")
                            , Config.keep playground "TextArea" "id" (TextArea.id "ta-disabled")
                            , Config.keep playground "TextArea" "disabled" (TextArea.disabled True)
                            , Config.keep playground "TextArea" "value" (TextArea.value "This field cannot be changed.")
                            , Config.keep playground "TextArea" "locale" (TextArea.locale lang)
                            ]
                        )
                    )
                , TextArea.view
                    (Options.klarTextArea playground
                        (List.concat
                            [ Config.keep playground "TextArea" "label" (TextArea.label "Small size")
                            , Config.keep playground "TextArea" "size" (TextArea.size Small)
                            , Config.keep playground "TextArea" "rows" (TextArea.rows 2)
                            ]
                        )
                        ++ field "ta-small"
                    )
                , TextArea.view
                    (Options.klarTextArea playground
                        (List.concat
                            [ Config.keep playground "TextArea" "label" (TextArea.label "Long text with counter")
                            , Config.keep playground "TextArea" "minRows" (TextArea.minRows 3)
                            , Config.keep playground "TextArea" "maxRows" (TextArea.maxRows 5)
                            , Config.keep playground "TextArea" "maxLength" (TextArea.maxLength 400)
                            , Config.keep playground "TextArea" "hint" (TextArea.hint "The height stops at five lines, then the text scrolls.")
                            ]
                        )
                        ++ field "ta-long"
                    )
                , TextArea.view
                    (Options.klarTextArea playground
                        (List.concat
                            [ Config.keep playground "TextArea" "label" (TextArea.label "Fixed, no resize handle")
                            , Config.keep playground "TextArea" "rows" (TextArea.rows 3)
                            , Config.keep playground "TextArea" "noResize" TextArea.noResize
                            ]
                        )
                        ++ field "ta-noresize"
                    )
                ]
            )
        ]



-- NUMBER


numbers : Config.Config -> Locale -> Model -> Html Msg
numbers playground lang model =
    let
        readValue key =
            readout ("Value: " ++ showNumber (NumberInput.value (numberOf key model)))
    in
    Doc.configuredSection playground
        [ "NumberInput" ]
        "Number field"
        "The number field remembers the text you type and turns it into a number. Comma and point both work as the decimal separator, spaces are ignored. Arrow up and down change the value by one step (Shift or Page Up/Down: ten steps), and the + and − buttons do the same with the mouse. Leaving the field rounds the number to the decimals (1.005 with two decimals is 1.01, as Klar.Format rounds) and formats it, and Escape brings back the number from before the typing. In Norwegian \"10.000\" is ten thousand, and a pasted \"12 kg\" in a field with the unit kg is 12. A number outside min and max is never moved into the range behind your back: it stays as typed and the field says \"Must be between ...\"; only stepping stops at the limits. Text that is not a number gives the error \"Must be a number\"."
        [ Doc.configuredExample playground
            [ "NumberInput" ]
            { title = "Total, discount and quantity"
            , description = Just "Try \"1 234,5\", \"1.234,50\" or \"1,234.5\" and press Tab. Try the arrow keys with and without Shift. Type 55 as the discount and press Tab: the field keeps 55 and shows the error, it is not changed to 50 for you."
            , code = Just """-- model: { total : NumberInput.State }   NumberInput.init "order-total"
NumberInput.view TotalMsg
    [ NumberInput.label "Order total"
    , NumberInput.min 0
    , NumberInput.max 1000000
    , NumberInput.step 100
    , NumberInput.decimals 2
    , NumberInput.grouped
    , NumberInput.prefixText "$"
    ]
    model.total

NumberInput.value model.total -- Maybe Float
NumberInput.isValid model.total -- False when the number is outside min and max"""
            }
            (grid playground
                260
                [ stack playground
                    [ NumberInput.view (NumberMsg "num-total")
                        (Options.klarNumberInput playground
                            (List.concat
                                [ Config.keep playground "NumberInput" "label" (NumberInput.label "Order total")
                                , Config.keep playground "NumberInput" "hint" (NumberInput.hint "Between 0 and 1\u{00A0}000\u{00A0}000. Steps of 100.")
                                , Config.keep playground "NumberInput" "min" (NumberInput.min 0)
                                , Config.keep playground "NumberInput" "max" (NumberInput.max 1000000)
                                , Config.keep playground "NumberInput" "step" (NumberInput.step 100)
                                , Config.keep playground "NumberInput" "decimals" (NumberInput.decimals 2)
                                , Config.keep playground "NumberInput" "grouped" NumberInput.grouped
                                , Config.keep playground "NumberInput" "prefixText" (NumberInput.prefixText "$")
                                , Config.keep playground "NumberInput" "alignRight" NumberInput.alignRight
                                , Config.keep playground "NumberInput" "locale" (NumberInput.locale lang)
                                ]
                            )
                        )
                        (numberOf "num-total" model)
                    , readValue "num-total"
                    ]
                , stack playground
                    [ NumberInput.view (NumberMsg "num-discount")
                        (Options.klarNumberInput playground
                            (List.concat
                                [ Config.keep playground "NumberInput" "label" (NumberInput.label "Discount")
                                , Config.keep playground "NumberInput" "hint" (NumberInput.hint "0 to 50 %, in steps of 0.5. A higher number is kept and shown as an error.")
                                , Config.keep playground "NumberInput" "min" (NumberInput.min 0)
                                , Config.keep playground "NumberInput" "max" (NumberInput.max 50)
                                , Config.keep playground "NumberInput" "step" (NumberInput.step 0.5)
                                , Config.keep playground "NumberInput" "decimals" (NumberInput.decimals 1)
                                , Config.keep playground "NumberInput" "suffixText" (NumberInput.suffixText "%")
                                , Config.keep playground "NumberInput" "required" NumberInput.required
                                , Config.keep playground "NumberInput" "locale" (NumberInput.locale lang)
                                ]
                            )
                        )
                        (numberOf "num-discount" model)
                    , readValue "num-discount"
                    ]
                , stack playground
                    [ NumberInput.view (NumberMsg "num-quantity")
                        (Options.klarNumberInput playground
                            (List.concat
                                [ Config.keep playground "NumberInput" "label" (NumberInput.label "Quantity")
                                , Config.keep playground "NumberInput" "hint" (NumberInput.hint "Whole numbers from 1 to 20.")
                                , Config.keep playground "NumberInput" "min" (NumberInput.min 1)
                                , Config.keep playground "NumberInput" "max" (NumberInput.max 20)
                                , Config.keep playground "NumberInput" "decimals" (NumberInput.decimals 0)
                                , Config.keep playground "NumberInput" "suffixText" (NumberInput.suffixText "pcs")
                                , Config.keep playground "NumberInput" "placeholder" (NumberInput.placeholder "1–20")
                                , Config.keep playground "NumberInput" "optionalText" (NumberInput.optionalText "(optional)")
                                , Config.keep playground "NumberInput" "locale" (NumberInput.locale lang)
                                ]
                            )
                        )
                        (numberOf "num-quantity" model)
                    , readValue "num-quantity"
                    ]
                ]
            )
        , Doc.configuredExample playground
            [ "NumberInput" ]
            { title = "States and sizes"
            , description = Just "An error from the application, disabled, read-only, small, large, without + and −, and with a prefix."
            , code = Just """NumberInput.view OrderValueMsg [ NumberInput.label "Order value", NumberInput.errorMaybe (belowMinimum model.orderValue) ] model.orderValue
NumberInput.view (always NoOp) [ NumberInput.label "Locked", NumberInput.disabled True ] state
NumberInput.view PriceMsg [ NumberInput.noSteppers, NumberInput.prefixText "USD" ] model.price"""
            }
            (grid playground
                240
                [ NumberInput.view (NumberMsg "num-value")
                    (Options.klarNumberInput playground
                        (List.concat
                            [ Config.keep playground "NumberInput" "label" (NumberInput.label "Order value")
                            , Config.keep playground "NumberInput" "prefixText" (NumberInput.prefixText "$")
                            , Config.keep playground
                                "NumberInput"
                                "errorMaybe"
                                (NumberInput.errorMaybe
                                    (if (NumberInput.value (numberOf "num-value" model) |> Maybe.withDefault 0) < 50 then
                                        Just "Orders below $50 are not accepted"

                                     else
                                        Nothing
                                    )
                                )
                            , Config.keep playground "NumberInput" "locale" (NumberInput.locale lang)
                            ]
                        )
                    )
                    (numberOf "num-value" model)
                , NumberInput.view (always NoOp)
                    (Options.klarNumberInput playground
                        (List.concat
                            [ Config.keep playground "NumberInput" "label" (NumberInput.label "Disabled")
                            , Config.keep playground "NumberInput" "disabled" (NumberInput.disabled True)
                            , Config.keep playground "NumberInput" "suffixText" (NumberInput.suffixText "kg")
                            , Config.keep playground "NumberInput" "locale" (NumberInput.locale lang)
                            ]
                        )
                    )
                    (NumberInput.setValue (Just 82.5) (NumberInput.init "num-disabled"))
                , NumberInput.view (always NoOp)
                    (Options.klarNumberInput playground
                        (List.concat
                            [ Config.keep playground "NumberInput" "label" (NumberInput.label "Read-only")
                            , Config.keep playground "NumberInput" "readOnly" (NumberInput.readOnly True)
                            , Config.keep playground "NumberInput" "suffixText" (NumberInput.suffixText "cm")
                            , Config.keep playground "NumberInput" "locale" (NumberInput.locale lang)
                            ]
                        )
                    )
                    (NumberInput.setValue (Just 181) (NumberInput.init "num-readonly"))
                , NumberInput.view (NumberMsg "num-small")
                    (Options.klarNumberInput playground
                        (List.concat
                            [ Config.keep playground "NumberInput" "label" (NumberInput.label "Small")
                            , Config.keep playground "NumberInput" "size" (NumberInput.size Small)
                            , Config.keep playground "NumberInput" "suffixText" (NumberInput.suffixText "%")
                            , Config.keep playground "NumberInput" "locale" (NumberInput.locale lang)
                            ]
                        )
                    )
                    (numberOf "num-small" model)
                , NumberInput.view (NumberMsg "num-large")
                    (Options.klarNumberInput playground
                        (List.concat
                            [ Config.keep playground "NumberInput" "label" (NumberInput.label "Large")
                            , Config.keep playground "NumberInput" "size" (NumberInput.size Large)
                            , Config.keep playground "NumberInput" "suffixText" (NumberInput.suffixText "m³")
                            , Config.keep playground "NumberInput" "decimals" (NumberInput.decimals 1)
                            , Config.keep playground "NumberInput" "locale" (NumberInput.locale lang)
                            ]
                        )
                    )
                    (numberOf "num-large" model)
                , NumberInput.view (NumberMsg "num-plain")
                    (Options.klarNumberInput playground
                        (List.concat
                            [ Config.keep playground "NumberInput" "label" (NumberInput.label "No steppers")
                            , Config.keep playground "NumberInput" "prefixText" (NumberInput.prefixText "USD")
                            , Config.keep playground "NumberInput" "noSteppers" NumberInput.noSteppers
                            , Config.keep playground "NumberInput" "grouped" NumberInput.grouped
                            , Config.keep playground "NumberInput" "locale" (NumberInput.locale lang)
                            ]
                        )
                    )
                    (numberOf "num-plain" model)
                ]
            )
        , Doc.configuredExample playground
            [ "NumberInput" ]
            { title = "The language sets the number format"
            , description = Just "The same number in an English and in a Norwegian field: the decimal separator follows the locale of the field, whatever the language of the page. What you type is read in the same way in both."
            , code = Just """NumberInput.view PriceMsg
    [ NumberInput.label "Price"
    , NumberInput.decimals 2
    , NumberInput.grouped
    , NumberInput.locale Locale.nb
    ]
    model.price -- shows 1 234,50 for 1234.5"""
            }
            (grid playground
                240
                [ NumberInput.view (NumberMsg "num-format-en")
                    (Options.klarNumberInput playground
                        (List.concat
                            [ Config.keep playground "NumberInput" "label" (NumberInput.label "English format")
                            , Config.keep playground "NumberInput" "decimals" (NumberInput.decimals 2)
                            , Config.keep playground "NumberInput" "grouped" NumberInput.grouped
                            , Config.keep playground "NumberInput" "locale" (NumberInput.locale Locale.en)
                            ]
                        )
                    )
                    (numberOf "num-format-en" model)
                , NumberInput.view (NumberMsg "num-format-nb")
                    (Options.klarNumberInput playground
                        (List.concat
                            [ Config.keep playground "NumberInput" "label" (NumberInput.label "Norwegian format")
                            , Config.keep playground "NumberInput" "decimals" (NumberInput.decimals 2)
                            , Config.keep playground "NumberInput" "grouped" NumberInput.grouped
                            , Config.keep playground "NumberInput" "locale" (NumberInput.locale Locale.nb)
                            ]
                        )
                    )
                    (numberOf "num-format-nb" model)
                ]
            )
        , Doc.configuredExample playground
            [ "NumberInput" ]
            { title = "How the text is read"
            , description = Just "NumberInput.parse: a single separator is always the decimal separator, several equal separators are thousands separators. So \"1.234\" is one and 234 thousandths, not 1234."
            , code = Just """NumberInput.parse "1 234,56" -- Just 1234.56
NumberInput.parse "1.234,56" -- Just 1234.56
NumberInput.parse "1.234" -- Just 1.234
NumberInput.parse "abc" -- Nothing"""
            }
            (resultTable playground
                [ "Text", "Number" ]
                (List.map
                    (\text -> ( "\"" ++ text ++ "\"", showNumber (NumberInput.parse text) ))
                    [ "12", "12,5", "12.5", "1 234,56", "1.234,56", "1,234.56", "1.234.567", "1.234", "-3,5", "−3,5", ",5", "12,", "abc", "1,2,3", "" ]
                )
            )
        ]



-- PASSWORD


passwords : Config.Config -> Locale -> Model -> Html Msg
passwords playground lang model =
    Doc.configuredSection playground
        [ "PasswordInput" ]
        "Password"
        "A password field with a \"show password\" button (Tab to the button, Enter or Space toggles it), a Caps Lock warning (type a capital without Shift) and a simple strength meter. The state holds the password: read it with PasswordInput.value. The meter looks at the length first (a long passphrase is strong without digits), the mix of characters and obvious patterns; it is a guide, not a security guarantee."
        [ Doc.configuredExample playground
            [ "PasswordInput" ]
            { title = "Sign in and new password"
            , description = Just "On the right with a strength meter. Try \"password123\", \"Summer2026\" and \"Summer-2026!\": from weak to strong."
            , code = Just """PasswordInput.view LoginMsg
    [ PasswordInput.label "Password"
    , PasswordInput.currentPassword
    , PasswordInput.onEnter SignIn
    ]
    model.password

PasswordInput.view NewPasswordMsg
    [ PasswordInput.label "New password"
    , PasswordInput.newPassword
    , PasswordInput.strengthMeter
    ]
    model.newPassword

-- read it
PasswordInput.value model.password -- String"""
            }
            (grid playground
                300
                [ PasswordInput.view (PasswordMsg "pw-login")
                    (Options.klarPasswordInput playground
                        (List.concat
                            [ Config.keep playground "PasswordInput" "label" (PasswordInput.label "Password")
                            , Config.keep playground "PasswordInput" "currentPassword" PasswordInput.currentPassword
                            , Config.keep playground "PasswordInput" "hint" (PasswordInput.hint "The password of your account.")
                            , Config.keep playground "PasswordInput" "locale" (PasswordInput.locale lang)
                            ]
                        )
                    )
                    (passwordOf "pw-login" model)
                , PasswordInput.view (PasswordMsg "pw-new")
                    (Options.klarPasswordInput playground
                        (List.concat
                            [ Config.keep playground "PasswordInput" "label" (PasswordInput.label "New password")
                            , Config.keep playground "PasswordInput" "newPassword" PasswordInput.newPassword
                            , Config.keep playground "PasswordInput" "required" PasswordInput.required
                            , Config.keep playground "PasswordInput" "strengthMeter" PasswordInput.strengthMeter
                            , Config.keep playground "PasswordInput" "locale" (PasswordInput.locale lang)
                            ]
                        )
                    )
                    (passwordOf "pw-new" model)
                ]
            )
        , Doc.configuredExample playground
            [ "PasswordInput" ]
            { title = "States"
            , description = Just "With an error (until the two passwords are the same), disabled and small."
            , code = Just """PasswordInput.view RepeatMsg
    [ PasswordInput.label "Repeat password"
    , PasswordInput.errorMaybe
        (if PasswordInput.value model.repeat /= PasswordInput.value model.password then
            Just "The passwords do not match"

         else
            Nothing
        )
    ]
    model.repeat"""
            }
            (grid playground
                260
                [ PasswordInput.view (PasswordMsg "pw-repeat")
                    (Options.klarPasswordInput playground
                        (List.concat
                            [ Config.keep playground "PasswordInput" "label" (PasswordInput.label "Repeat password")
                            , Config.keep playground "PasswordInput" "hint" (PasswordInput.hint "Compared with \"New password\" above.")
                            , Config.keep playground
                                "PasswordInput"
                                "errorMaybe"
                                (PasswordInput.errorMaybe
                                    (if PasswordInput.value (passwordOf "pw-repeat" model) /= PasswordInput.value (passwordOf "pw-new" model) then
                                        Just "The passwords do not match"

                                     else
                                        Nothing
                                    )
                                )
                            , Config.keep playground "PasswordInput" "locale" (PasswordInput.locale lang)
                            ]
                        )
                    )
                    (passwordOf "pw-repeat" model)
                , PasswordInput.view (always NoOp)
                    (Options.klarPasswordInput playground
                        (List.concat
                            [ Config.keep playground "PasswordInput" "label" (PasswordInput.label "Disabled")
                            , Config.keep playground "PasswordInput" "disabled" (PasswordInput.disabled True)
                            , Config.keep playground "PasswordInput" "locale" (PasswordInput.locale lang)
                            ]
                        )
                    )
                    (PasswordInput.setValue "secret" (PasswordInput.init "pw-disabled"))
                , PasswordInput.view (PasswordMsg "pw-small")
                    (Options.klarPasswordInput playground
                        (List.concat
                            [ Config.keep playground "PasswordInput" "label" (PasswordInput.label "Small")
                            , Config.keep playground "PasswordInput" "size" (PasswordInput.size Small)
                            , Config.keep playground "PasswordInput" "locale" (PasswordInput.locale lang)
                            ]
                        )
                    )
                    (passwordOf "pw-small" model)
                ]
            )
        , Doc.configuredExample playground
            [ "PasswordInput" ]
            { title = "Password strength (0 to 4)"
            , description = Just "PasswordInput.strength can be used in the validation, for example \"at least 2\"."
            , code = Just """PasswordInput.strength "Summer2026" -- 3"""
            }
            (resultTable playground
                [ "Password", "Strength" ]
                (List.map
                    (\text -> ( "\"" ++ text ++ "\"", String.fromInt (PasswordInput.strength text) ))
                    [ "", "abc", "aaaaaaaa", "12345678", "password123", "Tiger1234", "summertime", "Summer2026", "Summer-2026!", "Blue-Falcon-Lamp-42" ]
                )
            )
        ]



-- SEARCH


searches : Config.Config -> Locale -> Model -> Html Msg
searches playground lang model =
    let
        slow =
            searchOf "search-slow" model
    in
    Doc.configuredSection playground
        [ "SearchInput", "Search" ]
        "Search field"
        "The search field waits until you have stopped typing (300 ms) before the text becomes a search. Enter searches at once, Escape or the cross clears the field and searches (and Escape in a field with text is kept from closing a dialog around it). A space at the end starts no new search, and a word that an input method is still composing is not searched for. The application compares committed before and after each update to know when to start a search."
        [ Doc.configuredExample playground
            [ "SearchInput", "Search" ]
            { title = "Search with a delay"
            , description = Just "Count keystrokes against started searches: type \"logistics\" quickly and only one search starts. The hits come from a search through the customer names of 3,000 orders. The \"/\" in the field is only a hint for a shortcut; the application binds the key itself with Klar.Shortcut."
            , code = Just """SearchInput.view SearchMsg
    [ SearchInput.placeholder "Search orders ..."
    , SearchInput.shortcut (Shortcut.char '/')
    , SearchInput.remote model.orders
    ]
    model.search

-- update: start a search when the committed text changes
searchChanged =
    SearchInput.committed search /= SearchInput.committed model.search"""
            }
            (stack playground
                [ SearchInput.view SearchMsg
                    (Options.klarSearchInput playground
                        (List.concat
                            [ Config.keep playground "SearchInput" "placeholder" (SearchInput.placeholder "Search orders ...")
                            , Config.keep playground "SearchInput" "shortcut" (SearchInput.shortcut (Shortcut.char '/'))
                            , Config.keep playground
                                "SearchInput"
                                "remote"
                                (SearchInput.remote
                                    (Config.remote playground
                                        "SearchInput"
                                        "remote"
                                        (if model.searching then
                                            Remote.Loading

                                         else
                                            Remote.NotAsked
                                        )
                                    )
                                )
                            , Config.keep playground "SearchInput" "locale" (SearchInput.locale lang)
                            ]
                        )
                    )
                    model.search
                , Layout.row (Options.klarLayout playground (List.concat [ Config.keep playground "Layout" "gap" (Layout.gap 6), Config.keep playground "Layout" "wrap" Layout.wrap ]))
                    [ readout ("In the field: \"" ++ SearchInput.value model.search ++ "\"")
                    , readout ("Searching for: \"" ++ SearchInput.committed model.search ++ "\"")
                    , readout ("Keystrokes: " ++ String.fromInt model.keystrokes)
                    , readout ("Searches started: " ++ String.fromInt model.searchesStarted)
                    , readout
                        (case model.hits of
                            Just count ->
                                "Hits: " ++ String.fromInt count

                            Nothing ->
                                "Hits: –"
                        )
                    ]
                ]
            )
        , Doc.configuredExample playground
            [ "SearchInput", "Search" ]
            { title = "Sizes and states"
            , description = Just "Small, disabled, with a label and a hint, and loading."
            , code = Just """SearchInput.view SearchMsg [ SearchInput.size Small, SearchInput.placeholder "Filter ..." ] model.search"""
            }
            (grid playground
                260
                [ SearchInput.view (SearchStateMsg "search-small")
                    (Options.klarSearchInput playground
                        (List.concat
                            [ Config.keep playground "SearchInput" "size" (SearchInput.size Small)
                            , Config.keep playground "SearchInput" "placeholder" (SearchInput.placeholder "Filter ...")
                            , Config.keep playground "SearchInput" "ariaLabel" (SearchInput.ariaLabel "Filter the list")
                            , Config.keep playground "SearchInput" "locale" (SearchInput.locale lang)
                            ]
                        )
                    )
                    (searchOf "search-small" model)
                , SearchInput.view (always NoOp)
                    (Options.klarSearchInput playground
                        (List.concat
                            [ Config.keep playground "SearchInput" "placeholder" (SearchInput.placeholder "Search is switched off")
                            , Config.keep playground "SearchInput" "disabled" (SearchInput.disabled True)
                            , Config.keep playground "SearchInput" "locale" (SearchInput.locale lang)
                            ]
                        )
                    )
                    (SearchInput.init "search-disabled")
                , SearchInput.view (SearchStateMsg "search-labelled")
                    (Options.klarSearchInput playground
                        (List.concat
                            [ Config.keep playground "SearchInput" "label" (SearchInput.label "Search orders")
                            , Config.keep playground "SearchInput" "hint" (SearchInput.hint "Searches the customer names.")
                            , Config.keep playground "SearchInput" "placeholder" (SearchInput.placeholder "For example \"logistics\"")
                            , Config.keep playground "SearchInput" "locale" (SearchInput.locale lang)
                            ]
                        )
                    )
                    (searchOf "search-labelled" model)
                , SearchInput.view (SearchStateMsg "search-loading")
                    (Options.klarSearchInput playground
                        (List.concat
                            [ Config.keep playground "SearchInput" "placeholder" (SearchInput.placeholder "Loading ...")
                            , Config.keep playground "SearchInput" "remote" (SearchInput.remote (Config.remote playground "SearchInput" "remote" Remote.Loading))
                            , Config.keep playground "SearchInput" "locale" (SearchInput.locale lang)
                            ]
                        )
                    )
                    (searchOf "search-loading" model)
                ]
            )
        , Doc.configuredExample playground
            [ "SearchInput", "Search" ]
            { title = "Delay and pending text"
            , description = Just "debounce sets how long the field waits after the last keystroke (300 ms by default, 0 commits every keystroke). isPending is true while there is typed text that is not committed yet."
            , code = Just """SearchInput.view SearchMsg
    [ SearchInput.ariaLabel "Search orders"
    , SearchInput.debounce 1000
    ]
    model.search

SearchInput.isPending model.search -- True until the pause is over"""
            }
            (stack playground
                [ SearchInput.view (SearchStateMsg "search-slow")
                    (Options.klarSearchInput playground
                        (List.concat
                            [ Config.keep playground "SearchInput" "ariaLabel" (SearchInput.ariaLabel "Search with a long delay")
                            , Config.keep playground "SearchInput" "placeholder" (SearchInput.placeholder "Waits one second ...")
                            , Config.keep playground "SearchInput" "debounce" (SearchInput.debounce 1000)
                            , Config.keep playground "SearchInput" "locale" (SearchInput.locale lang)
                            ]
                        )
                    )
                    slow
                , Layout.row (Options.klarLayout playground (List.concat [ Config.keep playground "Layout" "gap" (Layout.gap 6), Config.keep playground "Layout" "wrap" Layout.wrap ]))
                    [ readout ("Pending: " ++ yesNo (SearchInput.isPending slow))
                    , readout ("Committed: \"" ++ SearchInput.committed slow ++ "\"")
                    ]
                ]
            )
        ]
