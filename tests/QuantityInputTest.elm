module QuantityInputTest exposing (suite)

import Expect
import Html.Attributes as Attr
import Json.Encode as Encode
import Klar.Ids as Ids
import Klar.Locale as Locale
import Klar.QuantityInput as Quantity
import Test exposing (Test, describe, test)
import Test.Html.Event as Event
import Test.Html.Query as Query
import Test.Html.Selector as S


type UnitId
    = Kilograms
    | Pounds
    | Percent


ids : Ids.Ids UnitId
ids =
    Ids.list
        (\id ->
            case id of
                Kilograms ->
                    "kg"

                Pounds ->
                    "lb"

                Percent ->
                    "percent"
        )
        [ Kilograms, Pounds, Percent ]


catalogue : { ids : Ids.Ids UnitId, units : List (Quantity.Unit UnitId) }
catalogue =
    { ids = ids, units = [ Quantity.unit Kilograms "Kilograms" "kg", Quantity.unit Pounds "Pounds" "lb", Quantity.unit Percent "Percent" "%" ] }


state : String -> Quantity.State
state text =
    Quantity.init "weight" |> Quantity.setUnit ids Kilograms |> Quantity.setValue text


read : List (Quantity.Attribute msg) -> String -> Result String (Maybe { amount : Float, unit : UnitId })
read attributes text =
    Quantity.value attributes catalogue (state text)


render : List (Quantity.Attribute Quantity.Msg) -> Quantity.State -> Query.Single Quantity.Msg
render attributes input =
    Quantity.view identity attributes catalogue input |> Query.fromHtml


edit : String -> Quantity.State -> Result String Quantity.State
edit text input =
    render [] input |> Query.find [ S.tag "input" ] |> Event.simulate (Event.input text) |> Event.toResult |> Result.map (\msg -> Quantity.update msg input |> Tuple.first)


limit : Float -> Float -> List (Quantity.Attribute msg)
limit low high =
    Quantity.between low high |> Maybe.map (Quantity.limits >> List.singleton) |> Maybe.withDefault []


suite : Test
suite =
    describe "Klar.QuantityInput"
        [ test "blank optional quantity has no value" <| \_ -> Quantity.value [] catalogue (Quantity.init "q") |> Expect.equal (Ok Nothing)
        , test "required blank quantity is rejected before blur" <| \_ -> read [ Quantity.required ] "" |> Expect.equal (Err "Enter a quantity")
        , test "a complete quantity carries the application's unit type" <| \_ -> read [] "12.5" |> Expect.equal (Ok (Just { amount = 12.5, unit = Kilograms }))
        , test "English comma grouping matches NumberInput" <| \_ -> read [ Quantity.locale Locale.en ] "1,234" |> Expect.equal (Ok (Just { amount = 1234, unit = Kilograms }))
        , test "Norwegian comma decimal matches NumberInput" <| \_ -> read [ Quantity.locale Locale.nb ] "1,234" |> Expect.equal (Ok (Just { amount = 1.234, unit = Kilograms }))
        , test "invalid input remains exact" <| \_ -> edit " 12 bananas " (state "1") |> Result.map Quantity.raw |> Expect.equal (Ok " 12 bananas ")
        , test "a trailing decimal separator is not accepted as a whole number" <| \_ -> read [] "12." |> Expect.equal (Err "Finish entering the number")
        , test "a trailing decimal comma remains incomplete" <| \_ -> read [ Quantity.locale Locale.nb ] "12," |> Expect.equal (Err "Skriv ferdig tallet")
        , test "sign-only input is rejected without being changed" <| \_ -> edit "-" (state "1") |> Result.map (Quantity.value [] catalogue) |> Expect.equal (Ok (Err "Must be a number"))
        , test "limits include their boundary values" <| \_ -> Expect.equal [ Ok (Just { amount = 0, unit = Kilograms }), Ok (Just { amount = 10, unit = Kilograms }) ] [ read (limit 0 10) "0", read (limit 0 10) "10" ]
        , test "out-of-range values are rejected rather than clamped" <| \_ -> read (limit 0 10) "11" |> Expect.equal (Err "Must be between 0 and 10")
        , test "reversed bounds cannot be constructed" <| \_ -> Quantity.between 10 0 |> Expect.equal Nothing
        , test "NaN bounds cannot be constructed" <| \_ -> Quantity.atLeast (0 / 0) |> Expect.equal Nothing
        , test "infinite bounds cannot be constructed" <| \_ -> Quantity.atMost (1 / 0) |> Expect.equal Nothing
        , test "huge parsed numbers must remain finite" <| \_ -> read [] (String.repeat 400 "9") |> Expect.equal (Err "Must be a finite number")
        , test "an external application error prevents value success" <| \_ -> read [ Quantity.error "Stock unavailable" ] "2" |> Expect.equal (Err "Stock unavailable")
        , test "a number cannot succeed without choosing a unit" <| \_ -> Quantity.init "q" |> Quantity.setValue "2" |> Quantity.value [] catalogue |> Expect.equal (Err "Choose a unit")
        , test "a removed unit is not silently replaced" <| \_ -> Quantity.value [] { catalogue | units = [] } (state "2") |> Expect.equal (Err "The selected unit is unavailable")
        , test "changing the unit preserves raw text without conversion" <|
            \_ ->
                state " 1 234,50 " |> Quantity.setUnit ids Pounds |> (\input -> ( Quantity.raw input, Quantity.selected ids input )) |> Expect.equal ( " 1 234,50 ", Just Pounds )
        , test "native unit selection decodes an application id" <|
            \_ ->
                render [] (state "25") |> Query.find [ S.tag "select" ] |> Event.simulate (Event.input "unit:percent") |> Event.toResult |> Result.map (\msg -> Quantity.update msg (state "25") |> Tuple.first |> Quantity.value [] catalogue) |> Expect.equal (Ok (Ok (Just { amount = 25, unit = Percent })))
        , test "an empty string is a valid application unit key" <|
            \_ ->
                let
                    input =
                        Quantity.init "empty-key" |> Quantity.setUnit Ids.string "" |> Quantity.setValue "3"
                in
                Quantity.value [] { ids = Ids.string, units = [ Quantity.unit "" "Unitless" "" ] } input |> Expect.equal (Ok (Just { amount = 3, unit = "" }))
        , test "blur never reformats a valid raw quantity" <|
            \_ ->
                let
                    input =
                        state " 1,234.500 "
                in
                render [] input |> Query.find [ S.tag "input" ] |> Event.simulate Event.blur |> Event.toResult |> Result.map (\msg -> Quantity.update msg input |> Tuple.first |> Quantity.raw) |> Expect.equal (Ok " 1,234.500 ")
        , test "composition is not returned as a valid quantity" <|
            \_ ->
                let
                    input =
                        state "12"
                in
                render [] input |> Query.find [ S.tag "input" ] |> Event.simulate (Event.custom "compositionstart" (Encode.object [])) |> Event.toResult |> Result.map (\msg -> Quantity.update msg input |> Tuple.first |> Quantity.value [] catalogue) |> Expect.equal (Ok (Err "Finish entering the number"))
        , test "untouched invalid input does not shout an error" <| \_ -> render [] (state "wrong") |> Query.findAll [ S.attribute (Attr.attribute "role" "alert") ] |> Query.count (Expect.equal 0)
        , test "touch displays the error with correct ARIA wiring" <| \_ -> render [ Quantity.hint "Shipping weight" ] (state "wrong" |> Quantity.touch) |> Expect.all [ Query.has [ S.id "weight-error", S.attribute (Attr.attribute "role" "alert") ], Query.has [ S.id "weight", S.attribute (Attr.attribute "aria-describedby" "weight-hint weight-error"), S.attribute (Attr.attribute "aria-invalid" "true") ] ]
        , test "both controls are disabled together" <| \_ -> render [ Quantity.disabled True ] (state "2") |> Query.findAll [ S.disabled True ] |> Query.count (Expect.equal 2)
        , test "read-only quantities retain a copyable number and a disabled unit" <| \_ -> render [ Quantity.readOnly True ] (state "2") |> Expect.all [ Query.has [ S.tag "input", S.attribute (Attr.readonly True) ], Query.has [ S.tag "select", S.disabled True ] ]
        , test "native field names are scoped" <| \_ -> render [ Quantity.name "mass" ] (state "2") |> Expect.all [ Query.has [ S.tag "input", S.attribute (Attr.name "mass") ], Query.has [ S.tag "select", S.attribute (Attr.name "mass-unit") ] ]
        , test "initial native option selection agrees with the typed unit" <|
            \_ ->
                render [] (state "2") |> Query.find [ S.tag "option", S.attribute (Attr.value "unit:kg") ] |> Query.has [ S.selected True ]
        , test "the unit selector announces its required status" <|
            \_ ->
                render [ Quantity.required ] (state "2") |> Query.find [ S.tag "select" ] |> Query.has [ S.attribute (Attr.attribute "aria-required" "true") ]
        , test "compositionend snapshots final text before any subsequent input event" <|
            \_ ->
                let
                    input =
                        state "1"
                in
                render [] input |> Query.find [ S.tag "input" ] |> Event.simulate (Event.custom "compositionend" (Encode.object [ ( "target", Encode.object [ ( "value", Encode.string "12.50" ) ] ) ])) |> Event.toResult |> Result.map (\msg -> Quantity.update msg input |> Tuple.first |> Quantity.value [] catalogue) |> Expect.equal (Ok (Ok (Just { amount = 12.5, unit = Kilograms })))
        , test "the default label is localized" <| \_ -> render [ Quantity.locale Locale.nb ] (state "2") |> Query.has [ S.tag "label", S.containing [ S.text "Mengde" ] ]
        , test "reset clears values and preserves the DOM id" <| \_ -> state "2" |> Quantity.reset |> render [] |> Query.has [ S.id "weight", S.attribute (Attr.value "") ]
        ]
