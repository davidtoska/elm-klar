module ToggleGroupTest exposing (suite)

import Expect exposing (Expectation)
import Fuzz exposing (Fuzzer)
import Html exposing (Html)
import Html.Attributes as Attr
import Klar
import Klar.Icon as Icon
import Klar.Theme exposing (Size(..))
import Klar.ToggleGroup as ToggleGroup
import Klar.ToggleGroup.Ids as Ids
import Klar.ToggleGroup.Selection as Selection
import Support.ActionsQuery as ActionsQuery
import Support.Css as Css
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
        , fieldTests
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


singleGroup : List (ToggleGroup.Attribute Msg) -> Maybe Status -> Html Msg
singleGroup attributes selected =
    ToggleGroup.single (ToggleGroup.label "Status" :: attributes) { selected = selected, onChange = Chose } statusOptions


multipleGroup : List (ToggleGroup.Attribute Msg) -> List Status -> Html Msg
multipleGroup attributes selected =
    ToggleGroup.multiple (ToggleGroup.label "Status" :: attributes) { selected = selected, onChange = Changed } statusOptions


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
                        [ Query.has [ attribute "aria-labelledby" (statusId ++ "-label") ]
                        , ActionsQuery.count [ Selector.tag "button" ] >> Expect.equal 3
                        ]
        , test "the label that names the group exists, and says the label" <|
            \_ ->
                singleGroup [] Nothing
                    |> Query.fromHtml
                    |> Query.find [ Selector.id (statusId ++ "-label") ]
                    |> Query.has [ Selector.exactText "Status" ]
        , test "the label is shown, unless it is hidden" <|
            \_ ->
                Expect.all
                    [ \_ -> singleGroup [] Nothing |> Query.fromHtml |> Query.find [ Selector.id (statusId ++ "-label") ] |> Query.has [ Selector.class "klar-field__label" ]
                    , \_ -> singleGroup [] Nothing |> Query.fromHtml |> Query.find [ Selector.id (statusId ++ "-label") ] |> Query.hasNot [ Selector.class "klar-sr-only" ]
                    , \_ -> singleGroup [ ToggleGroup.labelHidden ] Nothing |> Query.fromHtml |> Query.find [ Selector.id (statusId ++ "-label") ] |> Query.has [ Selector.class "klar-sr-only" ]
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
                    , \_ -> singleGroup [] Nothing |> Query.fromHtml |> Query.find [ Selector.id statusId ] |> Query.has [ role "group" ]
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
        , test "the whole group can be disabled, and enabled again, and stays in the tab order" <|
            \_ ->
                Expect.all
                    [ \_ -> singleGroup [ ToggleGroup.disabled True ] Nothing |> Query.fromHtml |> Query.findAll [ Selector.tag "button" ] |> Query.each (Query.has [ Selector.attribute (Attr.attribute "aria-disabled" "true"), Selector.disabled False ])
                    , \_ -> singleGroup [ ToggleGroup.disabled True, ToggleGroup.disabled False ] Nothing |> Query.fromHtml |> Query.findAll [ Selector.tag "button" ] |> Query.each (Query.hasNot [ Selector.attribute (Attr.attribute "aria-disabled" "true") ])
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
        , test "a group that does not fit goes onto a second line, and its words are not cut down" <|
            \_ ->
                [ ".klar-toggle-group{flex-wrap: wrap}"
                , ".klar-toggle-group:not(.klar-toggle-group--full) > .klar-button{flex: 0 0 auto}"
                ]
                    |> List.map (\rule -> String.contains rule Css.rules)
                    |> Expect.equal [ True, True ]
        , test "in Windows high contrast a switched on button is marked by a frame, not by a background" <|
            \_ ->
                Css.rules
                    |> String.contains ".klar-button[aria-pressed=\"true\"]::before{"
                    |> Expect.equal True
        , test "the buttons of a full width group have little padding, so that seven short day names fit on a phone" <|
            \_ ->
                Css.rules
                    |> String.contains ".klar-toggle-group--full > .klar-button:not(.klar-button--icon-only){padding-inline: var(--klar-space-1)}"
                    |> Expect.equal True
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
                ToggleGroup.single [ ToggleGroup.label "Status" ] { selected = Nothing, onChange = Chose } [ ToggleGroup.option Open "Open" |> ToggleGroup.disabledOption ]
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
                ToggleGroup.single [ ToggleGroup.label "Status" ] { selected = Nothing, onChange = Chose } [ ToggleGroup.option Open "Open" |> ToggleGroup.withIcon Icon.circle ]
                    |> Query.fromHtml
                    |> optionButton "Open"
                    |> Query.has [ Selector.containing [ Selector.class "klar-icon--circle" ], Selector.containing [ Selector.text "Open" ] ]
        , describe "an option with only an icon"
            [ test "is named for the screen reader and has the tooltip, so the name cannot be forgotten" <|
                \_ ->
                    ToggleGroup.multiple [ ToggleGroup.label "Text style" ] { selected = [], onChange = Changed } [ ToggleGroup.iconOption Open Icon.bold "Bold" ]
                        |> Query.fromHtml
                        |> Query.find [ Selector.tag "button" ]
                        |> Query.has [ attribute "aria-label" "Bold", attribute "data-tip" "Bold" ]
            , test "shows no text and shows the icon" <|
                \_ ->
                    ToggleGroup.multiple [ ToggleGroup.label "Text style" ] { selected = [], onChange = Changed } [ ToggleGroup.iconOption Open Icon.bold "Bold" ]
                        |> Query.fromHtml
                        |> Query.find [ Selector.tag "button" ]
                        |> Expect.all
                            [ Query.has [ Selector.containing [ Selector.class "klar-icon--bold" ] ]
                            , ActionsQuery.absent [ Selector.class "klar-button__label" ]
                            ]
            , test "withIcon replaces the icon and keeps it icon-only" <|
                \_ ->
                    ToggleGroup.multiple [ ToggleGroup.label "Text style" ] { selected = [], onChange = Changed } [ ToggleGroup.iconOption Open Icon.bold "Bold" |> ToggleGroup.withIcon Icon.italic ]
                        |> Query.fromHtml
                        |> Query.find [ Selector.tag "button" ]
                        |> Expect.all
                            [ Query.has [ Selector.containing [ Selector.class "klar-icon--italic" ], attribute "aria-label" "Bold" ]
                            , ActionsQuery.absent [ Selector.class "klar-icon--bold" ]
                            ]
            ]
        , test "a disabled option is disabled" <|
            \_ ->
                ToggleGroup.single [ ToggleGroup.label "Status" ] { selected = Nothing, onChange = Chose } [ ToggleGroup.option Open "Open", ToggleGroup.option Shipped "Shipped" |> ToggleGroup.disabledOption ]
                    |> Query.fromHtml
                    |> Expect.all
                        [ optionButton "Shipped" >> Query.has [ Selector.attribute (Attr.attribute "aria-disabled" "true"), Selector.disabled False ]
                        , optionButton "Open" >> Query.hasNot [ Selector.attribute (Attr.attribute "aria-disabled" "true") ]
                        ]
        ]


statusId : String
statusId =
    Ids.groupId "Status" [ "Open", "Shipped", "Cancelled" ]


labelTests : Test
labelTests =
    describe "the id of a group that was not given one"
        [ fuzz2 Fuzz.string (Fuzz.list Fuzz.string) "is valid in the page whatever the label and the options say" <|
            \label options ->
                let
                    id =
                        Ids.groupId label options
                in
                Expect.all
                    [ \_ -> String.startsWith "klar-toggle-" id |> Expect.equal True
                    , \_ -> String.all (\c -> (Char.isAlphaNum c && Char.toCode c < 128) || c == '-' || c == '_') id |> Expect.equal True
                    ]
                    ()
        , test "says what the group is, as far as the label can be written in an id" <|
            \_ ->
                Ids.groupId "Order status" [ "Open" ]
                    |> String.startsWith "klar-toggle-order__status-"
                    |> Expect.equal True
        , test "a label of dashes only (or no label) reads 'group', and other scripts are written as their codes" <|
            \_ ->
                Expect.all
                    [ \_ -> Ids.groupId "" [] |> String.startsWith "klar-toggle-group-" |> Expect.equal True
                    , \_ -> Ids.groupId "日本語" [] |> String.startsWith "klar-toggle-_65e5__672c__8a9e_-" |> Expect.equal True
                    , \_ -> Ids.groupId "---" [] |> String.startsWith "klar-toggle-group-" |> Expect.equal True
                    ]
                    ()
        , test "labels that look alike once the letters are gone still get different ids" <|
            \_ ->
                Expect.all
                    [ \_ -> Expect.notEqual (Ids.groupId "日本語" []) (Ids.groupId "中文字" [])
                    , \_ -> Expect.notEqual (Ids.groupId "Størrelse" []) (Ids.groupId "Sørrelse" [])
                    , \_ -> Expect.notEqual (Ids.groupId "" []) (Ids.groupId "日本語" [])
                    ]
                    ()
        , test "the same label with other options is another id; the same label and options is the same id" <|
            \_ ->
                Expect.all
                    [ \_ -> Expect.notEqual (Ids.groupId "Status" [ "Open", "Shipped" ]) (Ids.groupId "Status" [ "Open", "Cancelled" ])
                    , \_ -> Expect.equal (Ids.groupId "Status" [ "Open", "Shipped" ]) (Ids.groupId "Status" [ "Open", "Shipped" ])
                    ]
                    ()
        , fuzz Fuzz.string "the group uses it, and its label has the id that the group refers to" <|
            \label ->
                let
                    id =
                        Ids.groupId label [ "Open", "Shipped", "Cancelled" ]
                in
                ToggleGroup.single [ ToggleGroup.label label ] { selected = Nothing, onChange = Chose } statusOptions
                    |> Query.fromHtml
                    |> Expect.all
                        [ Query.find [ role "group" ] >> Query.has [ Selector.id id, Selector.attribute (Attr.attribute "aria-labelledby" (id ++ "-label")) ]
                        , Query.find [ Selector.id (id ++ "-label") ] >> Query.has [ Selector.class "klar-field__label" ]
                        ]
        ]



-- THE LABEL, REQUIRED AND OPTIONAL


fieldTests : Test
fieldTests =
    describe "label, required and optional"
        [ test "the label is shown and names the group" <|
            \_ ->
                singleGroup [] Nothing
                    |> Query.fromHtml
                    |> Query.has [ Selector.class "klar-field__label", Selector.text "Status" ]
        , test "required puts a mark after the label, hidden from screen readers" <|
            \_ ->
                singleGroup [ ToggleGroup.required ] Nothing
                    |> Query.fromHtml
                    |> Query.find [ Selector.class "klar-field__required" ]
                    |> Query.has [ Selector.text "*", Selector.attribute (Attr.attribute "aria-hidden" "true") ]
        , test "optionalText is shown when the group is not required" <|
            \_ ->
                Expect.all
                    [ \_ -> singleGroup [ ToggleGroup.optionalText "(optional)" ] Nothing |> Query.fromHtml |> Query.has [ Selector.class "klar-field__optional", Selector.text "(optional)" ]
                    , \_ -> singleGroup [ ToggleGroup.optionalText "(optional)", ToggleGroup.required ] Nothing |> Query.fromHtml |> Query.findAll [ Selector.class "klar-field__optional" ] |> Query.count (Expect.equal 0)
                    ]
                    ()
        , test "a group of many options works the selection out on the click" <|
            \_ ->
                let
                    many =
                        List.range 1 300
                in
                ToggleGroup.multiple [ ToggleGroup.label "Codes" ]
                    { selected = [ 2 ], onChange = identity }
                    (List.map (\n -> ToggleGroup.option n (String.fromInt n)) many)
                    |> Query.fromHtml
                    |> Query.find [ Selector.tag "button", Selector.containing [ Selector.text "300" ] ]
                    |> Event.simulate Event.click
                    |> Event.expect [ 2, 300 ]
        ]
