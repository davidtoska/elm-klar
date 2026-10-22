module ToggleGroupTest exposing (suite)

import Expect exposing (Expectation)
import Fuzz exposing (Fuzzer)
import Html exposing (Html)
import Html.Attributes as Attr
import Klar.Icon as Icon
import Klar.Theme exposing (Size(..))
import Klar.ToggleGroup as ToggleGroup
import Klar.ToggleGroup.Selection as Selection
import Support.ActionsQuery as ActionsQuery
import Test exposing (Test, describe, fuzz, fuzz2, fuzz3, test)
import Test.Html.Event as Event
import Test.Html.Query as Query
import Test.Html.Selector as Selector exposing (Selector)
import Test.Runner


suite : Test
suite =
    describe "Klar.ToggleGroup"
        [ selectionTests
        , propertyTests
        , renderTests
        , singleTests
        , multipleTests
        , optionTests
        , labelTests
        ]



-- THE APPLICATION'S OWN TYPES


type Status
    = Open
    | Shipped
    | Cancelled
    | Archived


type Msg
    = Chose (Maybe Status)
    | Changed (List Status)


allStatuses : List Status
allStatuses =
    [ Open, Shipped, Cancelled, Archived ]



-- THE LOGIC OF A CLICK


selectionTests : Test
selectionTests =
    describe "what a click does to the selection"
        [ describe "single"
            [ test "an option that is off is turned on" <|
                \_ -> Selection.toggleOne Open Nothing |> Expect.equal (Just Open)
            , test "the option that is on is turned off" <|
                \_ -> Selection.toggleOne Open (Just Open) |> Expect.equal Nothing
            , test "another option takes over" <|
                \_ -> Selection.toggleOne Shipped (Just Open) |> Expect.equal (Just Shipped)
            ]
        , describe "multiple"
            [ test "an option is added, in the order of the options and not the order of the clicks" <|
                \_ ->
                    Selection.toggleMany allStatuses Open [ Cancelled ]
                        |> Expect.equal [ Open, Cancelled ]
            , test "an option is taken out" <|
                \_ ->
                    Selection.toggleMany allStatuses Shipped [ Open, Shipped, Cancelled ]
                        |> Expect.equal [ Open, Cancelled ]
            , test "the first click on an empty selection" <|
                \_ ->
                    Selection.toggleMany allStatuses Cancelled []
                        |> Expect.equal [ Cancelled ]
            , test "an id that no option has stays, after the others" <|
                \_ ->
                    Selection.toggleMany [ Open, Shipped ] Open [ Archived, Shipped ]
                        |> Expect.equal [ Open, Shipped, Archived ]
            , test "an id is never in the list twice" <|
                \_ ->
                    Selection.toggleMany allStatuses Shipped [ Open, Open, Cancelled, Cancelled ]
                        |> Expect.equal [ Open, Shipped, Cancelled ]
            , test "options with the same id do not duplicate it" <|
                \_ ->
                    Selection.toggleMany [ Open, Open, Shipped ] Open []
                        |> Expect.equal [ Open ]
            ]
        ]


anyStatuses : Fuzzer (List Status)
anyStatuses =
    Fuzz.list (Fuzz.oneOfValues allStatuses)


anyStatus : Fuzzer Status
anyStatus =
    Fuzz.oneOfValues allStatuses


{-| The selection the way a click leaves it: in the order of the options, each id
once, and the ids that no option has after those.
-}
normalized : List Status -> List Status -> List Status
normalized optionIds selected =
    List.filter (\id -> List.member id selected) (unique optionIds)
        ++ unique (List.filter (\id -> not (List.member id optionIds)) selected)


unique : List Status -> List Status
unique =
    List.foldl
        (\id kept ->
            if List.member id kept then
                kept

            else
                kept ++ [ id ]
        )
        []


propertyTests : Test
propertyTests =
    describe "for any selection"
        [ fuzz3 anyStatuses anyStatuses anyStatus "toggling the same option twice gives the selection back (as the clicks leave it)" <|
            \options selected id ->
                if List.member id options then
                    selected
                        |> Selection.toggleMany options id
                        |> Selection.toggleMany options id
                        |> Expect.equal (normalized options selected)

                else
                    Expect.pass
        , fuzz3 anyStatuses anyStatuses anyStatus "the option clicked is on afterwards exactly when it was off before" <|
            \options selected id ->
                Selection.toggleMany options id selected
                    |> List.member id
                    |> Expect.equal (not (List.member id selected))
        , fuzz3 anyStatuses anyStatuses anyStatus "no other option changes" <|
            \options selected id ->
                let
                    after =
                        Selection.toggleMany options id selected
                in
                allStatuses
                    |> List.filter (\other -> other /= id)
                    |> List.all (\other -> List.member other after == List.member other selected)
                    |> Expect.equal True
        , fuzz3 anyStatuses anyStatuses anyStatus "an id is never twice in the result" <|
            \options selected id ->
                Selection.toggleMany options id selected
                    |> (\after -> List.length after == List.length (unique after))
                    |> Expect.equal True
        , fuzz2 anyStatus (Fuzz.maybe anyStatus) "single: clicking twice gives the choice back" <|
            \id selected ->
                selected
                    |> Selection.toggleOne id
                    |> Selection.toggleOne id
                    |> Expect.equal
                        (if selected == Just id then
                            Just id

                         else
                            Nothing
                        )
        ]



-- WHAT IS DRAWN


statusOptions : List (ToggleGroup.Option Status)
statusOptions =
    [ ToggleGroup.option Open "Open"
    , ToggleGroup.option Shipped "Shipped"
    , ToggleGroup.option Cancelled "Cancelled"
    ]


singleGroup : List ToggleGroup.Attribute -> Maybe Status -> Html Msg
singleGroup attributes selected =
    ToggleGroup.single attributes { label = "Status", selected = selected, onChange = Chose } statusOptions


multipleGroup : List ToggleGroup.Attribute -> List Status -> Html Msg
multipleGroup attributes selected =
    ToggleGroup.multiple attributes { label = "Status", selected = selected, onChange = Changed } statusOptions


role : String -> Selector
role name =
    Selector.attribute (Attr.attribute "role" name)


attribute : String -> String -> Selector
attribute name value =
    Selector.attribute (Attr.attribute name value)


optionButton : String -> Query.Single Msg -> Query.Single Msg
optionButton text =
    Query.find [ Selector.tag "button", Selector.containing [ Selector.text text ] ]


pressedOf : Html Msg -> List String
pressedOf html =
    [ "Open", "Shipped", "Cancelled" ]
        |> List.filter
            (\text ->
                Query.fromHtml html
                    |> optionButton text
                    |> hasSelector (attribute "aria-pressed" "true")
            )


hasSelector : Selector -> Query.Single Msg -> Bool
hasSelector selector single =
    Test.Runner.getFailureReason (Query.has [ selector ] single) == Nothing


renderTests : Test
renderTests =
    describe "the group"
        [ test "is a named group of buttons" <|
            \_ ->
                singleGroup [] Nothing
                    |> Query.fromHtml
                    |> Query.find [ role "group" ]
                    |> Expect.all
                        [ Query.has [ attribute "aria-labelledby" "klar-toggle-status-label" ]
                        , ActionsQuery.count [ Selector.tag "button" ] >> Expect.equal 3
                        ]
        , test "the label that names the group exists, and says the label" <|
            \_ ->
                singleGroup [] Nothing
                    |> Query.fromHtml
                    |> Query.find [ Selector.id "klar-toggle-status-label" ]
                    |> Query.has [ Selector.exactText "Status" ]
        , test "the label is shown, unless it is hidden" <|
            \_ ->
                Expect.all
                    [ \_ -> singleGroup [] Nothing |> Query.fromHtml |> Query.find [ Selector.id "klar-toggle-status-label" ] |> Query.has [ Selector.class "klar-field__label" ]
                    , \_ -> singleGroup [] Nothing |> Query.fromHtml |> Query.find [ Selector.id "klar-toggle-status-label" ] |> Query.hasNot [ Selector.class "klar-sr-only" ]
                    , \_ -> singleGroup [ ToggleGroup.labelHidden ] Nothing |> Query.fromHtml |> Query.find [ Selector.id "klar-toggle-status-label" ] |> Query.has [ Selector.class "klar-sr-only" ]
                    ]
                    ()
        , test "the buttons are not submit buttons" <|
            \_ ->
                singleGroup [] Nothing
                    |> Query.fromHtml
                    |> Query.findAll [ Selector.tag "button" ]
                    |> Query.each (Query.has [ attribute "type" "button" ])
        , test "the id is given, or made from the label" <|
            \_ ->
                Expect.all
                    [ \_ -> singleGroup [ ToggleGroup.id "order-status" ] Nothing |> Query.fromHtml |> Query.find [ Selector.id "order-status" ] |> Query.has [ role "group" ]
                    , \_ -> singleGroup [ ToggleGroup.id "order-status" ] Nothing |> Query.fromHtml |> Query.find [ Selector.id "order-status-label" ] |> Query.has [ Selector.text "Status" ]
                    , \_ -> singleGroup [] Nothing |> Query.fromHtml |> Query.find [ Selector.id "klar-toggle-status" ] |> Query.has [ role "group" ]
                    ]
                    ()
        , test "a hint and an error are joined to the group, and exist" <|
            \_ ->
                singleGroup [ ToggleGroup.id "status", ToggleGroup.hint "Pick one to filter", ToggleGroup.error "Pick a status" ] Nothing
                    |> Query.fromHtml
                    |> Expect.all
                        [ Query.find [ role "group" ] >> Query.has [ attribute "aria-describedby" "status-hint status-error" ]
                        , Query.find [ Selector.id "status-hint" ] >> Query.has [ Selector.text "Pick one to filter" ]
                        , Query.find [ Selector.id "status-error" ] >> Query.has [ Selector.text "Pick a status", role "alert" ]
                        , Query.find [ role "group" ] >> Query.has [ Selector.class "klar-toggle-group--invalid" ]
                        ]
        , test "without a hint or an error there is nothing to describe the group" <|
            \_ ->
                singleGroup [ ToggleGroup.id "status" ] Nothing
                    |> Query.fromHtml
                    |> Query.find [ role "group" ]
                    |> Query.hasNot [ Selector.attribute (Attr.attribute "aria-describedby" "status-hint status-error") ]
        , test "errorMaybe Nothing shows no error" <|
            \_ ->
                singleGroup [ ToggleGroup.errorMaybe Nothing ] Nothing
                    |> Query.fromHtml
                    |> ActionsQuery.absent [ role "alert" ]
        , test "the whole group can be disabled, and enabled again" <|
            \_ ->
                Expect.all
                    [ \_ -> singleGroup [ ToggleGroup.disabled True ] Nothing |> Query.fromHtml |> Query.findAll [ Selector.tag "button" ] |> Query.each (Query.has [ Selector.disabled True ])
                    , \_ -> singleGroup [ ToggleGroup.disabled True, ToggleGroup.disabled False ] Nothing |> Query.fromHtml |> Query.findAll [ Selector.tag "button" ] |> Query.each (Query.has [ Selector.disabled False ])
                    ]
                    ()
        , test "the size reaches the buttons" <|
            \_ ->
                singleGroup [ ToggleGroup.size Small ] Nothing
                    |> Query.fromHtml
                    |> Query.findAll [ Selector.tag "button" ]
                    |> Query.each (Query.has [ Selector.class "klar-button--sm" ])
        , test "full width" <|
            \_ ->
                singleGroup [ ToggleGroup.fullWidth ] Nothing
                    |> Query.fromHtml
                    |> Query.find [ role "group" ]
                    |> Query.has [ Selector.class "klar-toggle-group--full" ]
        ]



-- ZERO OR ONE


singleTests : Test
singleTests =
    describe "single"
        [ test "the chosen option is pressed, the others are not" <|
            \_ ->
                Expect.all
                    [ \_ -> pressedOf (singleGroup [] Nothing) |> Expect.equal []
                    , \_ -> pressedOf (singleGroup [] (Just Shipped)) |> Expect.equal [ "Shipped" ]
                    ]
                    ()
        , test "every button says whether it is pressed, also the ones that are not" <|
            \_ ->
                singleGroup [] (Just Open)
                    |> Query.fromHtml
                    |> Query.findAll [ Selector.tag "button" ]
                    |> Query.each (Query.has [ Selector.attribute (Attr.attribute "aria-pressed" "true") ] |> orElse (Query.has [ attribute "aria-pressed" "false" ]))
        , test "a click on an option that is off sends it" <|
            \_ ->
                singleGroup [] Nothing
                    |> clickOn "Shipped"
                    |> Event.expect (Chose (Just Shipped))
        , test "a click on another option moves the choice" <|
            \_ ->
                singleGroup [] (Just Open)
                    |> clickOn "Cancelled"
                    |> Event.expect (Chose (Just Cancelled))
        , test "a click on the option that is on turns it off: Nothing" <|
            \_ ->
                singleGroup [] (Just Open)
                    |> clickOn "Open"
                    |> Event.expect (Chose Nothing)
        , test "a disabled option cannot be clicked" <|
            \_ ->
                ToggleGroup.single [] { label = "Status", selected = Nothing, onChange = Chose } [ ToggleGroup.option Open "Open" |> ToggleGroup.disabledOption ]
                    |> clickOn "Open"
                    |> Event.toResult
                    |> Expect.err
        , test "a click in a disabled group sends nothing" <|
            \_ ->
                singleGroup [ ToggleGroup.disabled True ] Nothing
                    |> clickOn "Open"
                    |> Event.toResult
                    |> Expect.err
        ]


orElse : (a -> Expectation) -> (a -> Expectation) -> a -> Expectation
orElse second first value =
    case Test.Runner.getFailureReason (first value) of
        Nothing ->
            Expect.pass

        Just _ ->
            second value


clickOn : String -> Html Msg -> Event.Event Msg
clickOn text html =
    html
        |> Query.fromHtml
        |> optionButton text
        |> Event.simulate Event.click



-- ANY NUMBER


multipleTests : Test
multipleTests =
    describe "multiple"
        [ test "every option in the selection is pressed" <|
            \_ ->
                pressedOf (multipleGroup [] [ Open, Cancelled ])
                    |> Expect.equal [ "Open", "Cancelled" ]
        , test "a click adds the option, in the order of the options" <|
            \_ ->
                multipleGroup [] [ Cancelled ]
                    |> clickOn "Open"
                    |> Event.expect (Changed [ Open, Cancelled ])
        , test "a click on an option that is on takes it out" <|
            \_ ->
                multipleGroup [] [ Open, Shipped ]
                    |> clickOn "Open"
                    |> Event.expect (Changed [ Shipped ])
        , test "a click works from the selection that the group was drawn with" <|
            \_ ->
                -- two clicks in the same frame both start from the drawn selection
                Expect.all
                    [ \_ -> multipleGroup [] [ Shipped ] |> clickOn "Open" |> Event.expect (Changed [ Open, Shipped ])
                    , \_ -> multipleGroup [] [ Shipped ] |> clickOn "Cancelled" |> Event.expect (Changed [ Shipped, Cancelled ])
                    ]
                    ()
        ]



-- THE OPTIONS


optionTests : Test
optionTests =
    describe "options"
        [ test "an option with an icon and a text shows both" <|
            \_ ->
                ToggleGroup.single [] { label = "Status", selected = Nothing, onChange = Chose } [ ToggleGroup.option Open "Open" |> ToggleGroup.withIcon Icon.circle ]
                    |> Query.fromHtml
                    |> optionButton "Open"
                    |> Query.has [ Selector.containing [ Selector.class "klar-icon--circle" ], Selector.containing [ Selector.text "Open" ] ]
        , describe "an option with only an icon"
            [ test "is named for the screen reader and has the tooltip, so the name cannot be forgotten" <|
                \_ ->
                    ToggleGroup.multiple [] { label = "Text style", selected = [], onChange = Changed } [ ToggleGroup.iconOption Open Icon.bold "Bold" ]
                        |> Query.fromHtml
                        |> Query.find [ Selector.tag "button" ]
                        |> Query.has [ attribute "aria-label" "Bold", Selector.attribute (Attr.title "Bold") ]
            , test "shows no text and shows the icon" <|
                \_ ->
                    ToggleGroup.multiple [] { label = "Text style", selected = [], onChange = Changed } [ ToggleGroup.iconOption Open Icon.bold "Bold" ]
                        |> Query.fromHtml
                        |> Query.find [ Selector.tag "button" ]
                        |> Expect.all
                            [ Query.has [ Selector.containing [ Selector.class "klar-icon--bold" ] ]
                            , ActionsQuery.absent [ Selector.class "klar-button__label" ]
                            ]
            , test "withIcon replaces the icon and keeps it icon-only" <|
                \_ ->
                    ToggleGroup.multiple [] { label = "Text style", selected = [], onChange = Changed } [ ToggleGroup.iconOption Open Icon.bold "Bold" |> ToggleGroup.withIcon Icon.italic ]
                        |> Query.fromHtml
                        |> Query.find [ Selector.tag "button" ]
                        |> Expect.all
                            [ Query.has [ Selector.containing [ Selector.class "klar-icon--italic" ], attribute "aria-label" "Bold" ]
                            , ActionsQuery.absent [ Selector.class "klar-icon--bold" ]
                            ]
            ]
        , test "a disabled option is disabled" <|
            \_ ->
                ToggleGroup.single [] { label = "Status", selected = Nothing, onChange = Chose } [ ToggleGroup.option Open "Open", ToggleGroup.option Shipped "Shipped" |> ToggleGroup.disabledOption ]
                    |> Query.fromHtml
                    |> Expect.all
                        [ optionButton "Shipped" >> Query.has [ Selector.disabled True ]
                        , optionButton "Open" >> Query.has [ Selector.disabled False ]
                        ]
        ]


labelTests : Test
labelTests =
    describe "ids"
        [ fuzz Fuzz.string "an id made from any label is safe in the page" <|
            \label ->
                ToggleGroup.single [] { label = label, selected = Nothing, onChange = Chose } statusOptions
                    |> Query.fromHtml
                    |> Query.find [ role "group" ]
                    |> Query.has [ Selector.attribute (Attr.attribute "aria-labelledby" (generatedId label ++ "-label")) ]
        ]


generatedId : String -> String
generatedId label =
    "klar-toggle-"
        ++ (String.toLower label
                |> String.map
                    (\c ->
                        if (Char.isAlphaNum c && Char.toCode c < 128) || c == '-' || c == '_' then
                            c

                        else
                            '-'
                    )
           )
