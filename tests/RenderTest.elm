module RenderTest exposing (suite)

import Expect exposing (Expectation)
import Html exposing (Html)
import Html.Attributes as Attr
import Json.Encode as Encode
import Klar.Alert as Alert
import Klar.Button as Button
import Klar.ButtonGroup as ButtonGroup
import Klar.Checkbox as Checkbox
import Klar.EmptyState as EmptyState
import Klar.Field as Field
import Klar.Icon as Icon
import Klar.Link as Link
import Klar.Locale as Locale exposing (Locale)
import Klar.Menu as Menu
import Klar.Pagination as Pagination
import Klar.Remote as Remote exposing (Remote(..))
import Klar.Table as Table
import Klar.Tabs as Tabs
import Klar.TextInput as TextInput
import Klar.Theme as Theme
import Support.Ids as Ids
import Support.Orders as Orders
import Test exposing (Test, describe, test)
import Test.Html.Event as Event
import Test.Html.Query as Query
import Test.Html.Selector as Selector exposing (Selector)
import Test.Runner


orders : Link.Target
orders =
    Link.internal "#/orders"


suite : Test
suite =
    describe "Rendered output (accessibility)"
        [ referenceHelperTests
        , buttonTests
        , textInputTests
        , fieldTests
        , checkboxTests
        , alertTests
        , tabsTests
        , paginationTests
        , tableTests
        ]



-- THE HELPER: EVERY ID THAT IS NAMED EXISTS
--
-- `Test.Html.Query` can ask questions about HTML but cannot list what is in it.
-- When a query fails it prints the HTML it looked at, so the helper makes a
-- query that fails on purpose, reads the printed tree and picks the tags and
-- attributes out of it. That is enough to find the ids and the references.


type alias Tag =
    { name : String
    , attributes : List ( String, String )
    }


{-| The HTML as the test library prints it for a failed query.
-}
printed : Html msg -> String
printed html =
    case Test.Runner.getFailureReason (Query.has [ Selector.text "\u{0001}" ] (Query.fromHtml html)) of
        Just reason ->
            reason.description
                |> String.split "\n\n▼ Query.has"
                |> List.head
                |> Maybe.withDefault ""

        Nothing ->
            ""


{-| How deep the first input is in the printed tree: the spaces in front of its line.
-}
inputDepth : Html msg -> Maybe Int
inputDepth html =
    printed html
        |> String.lines
        |> List.filter (\line -> String.startsWith "<input" (String.trim line))
        |> List.head
        |> Maybe.map (\line -> String.length line - String.length (String.trimLeft line))


{-| The tags of the HTML, in order. Attribute values are printed without any
escaping, so the helper is for HTML whose values have no quotes in them.
-}
tagsOf : Html msg -> Result String (List Tag)
tagsOf html =
    let
        text =
            printed html
    in
    if String.contains "Internal Error" text then
        Err text

    else
        Ok (text |> String.split "<" |> List.drop 1 |> List.filterMap tagFrom)


tagFrom : String -> Maybe Tag
tagFrom piece =
    if String.startsWith "/" piece then
        Nothing

    else
        let
            inTag =
                untilClosing piece

            name =
                inTag |> String.words |> List.head |> Maybe.withDefault ""
        in
        Just { name = name, attributes = pairs (String.split "\"" (String.dropLeft (String.length name) inTag)) }


{-| The text up to the `>` that ends the tag: a `>` inside quotes does not.
-}
untilClosing : String -> String
untilClosing piece =
    let
        go parts soFar =
            case parts of
                [] ->
                    soFar

                part :: rest ->
                    let
                        candidate =
                            if soFar == "" then
                                part

                            else
                                soFar ++ ">" ++ part
                    in
                    if modBy 2 (List.length (String.indexes "\"" candidate)) == 0 then
                        candidate

                    else
                        go rest candidate
    in
    go (String.split ">" piece) ""


{-| `a="1" b="2"` split at the quotes is `a=`, `1`, `b=`, `2`.
-}
pairs : List String -> List ( String, String )
pairs parts =
    case parts of
        before :: value :: more ->
            ( before |> String.trim |> String.split " " |> List.reverse |> List.head |> Maybe.withDefault "" |> String.dropRight 1, value ) :: pairs more

        _ ->
            []


attribute : String -> Tag -> Maybe String
attribute name tag =
    tag.attributes |> List.filter (\( key, _ ) -> key == name) |> List.head |> Maybe.map Tuple.second


referencingAttributes : List String
referencingAttributes =
    [ "aria-controls", "aria-labelledby", "aria-describedby", "aria-owns", "aria-activedescendant", "aria-details", "aria-errormessage", "htmlFor" ]


labelable : List String
labelable =
    [ "input", "select", "textarea", "button", "meter", "output", "progress" ]


{-| Every id that a tag names in a reference (`for`, `aria-controls`,
`aria-labelledby`, `aria-describedby` ...) and that no tag has.
-}
danglingReferences : List Tag -> List String
danglingReferences tags =
    let
        ids =
            List.filterMap (attribute "id") tags
    in
    tags
        |> List.concatMap
            (\tag ->
                referencingAttributes
                    |> List.concatMap
                        (\name ->
                            attribute name tag
                                |> Maybe.map String.words
                                |> Maybe.withDefault []
                                |> List.filter (\target -> not (List.member target ids))
                                |> List.map (\target -> "<" ++ tag.name ++ "> " ++ name ++ " names \"" ++ target ++ "\", which no element has")
                        )
            )


{-| Ids that two tags have.
-}
duplicateIds : List Tag -> List String
duplicateIds tags =
    let
        ids =
            List.filterMap (attribute "id") tags
    in
    ids
        |> List.filter (\id -> List.length (List.filter ((==) id) ids) > 1)
        |> unique
        |> List.map (\id -> "the id \"" ++ id ++ "\" is used more than once")


{-| Labels (`for`) that point at something a label cannot belong to.
-}
labelsForNothingLabelable : List Tag -> List String
labelsForNothingLabelable tags =
    tags
        |> List.filterMap
            (\tag ->
                attribute "htmlFor" tag
                    |> Maybe.andThen
                        (\target ->
                            tags
                                |> List.filter (\other -> attribute "id" other == Just target)
                                |> List.head
                                |> Maybe.andThen
                                    (\found ->
                                        if List.member found.name labelable then
                                            Nothing

                                        else
                                            Just ("a label is for \"" ++ target ++ "\", which is a <" ++ found.name ++ ">")
                                    )
                        )
            )


unique : List String -> List String
unique items =
    List.foldr
        (\item kept ->
            if List.member item kept then
                kept

            else
                item :: kept
        )
        []
        items


problemsIn : List Tag -> List String
problemsIn tags =
    danglingReferences tags ++ duplicateIds tags ++ labelsForNothingLabelable tags


{-| The rendered HTML names only ids that exist, uses no id twice and has labels
only for things that can be labelled.
-}
expectWellWired : Html msg -> Expectation
expectWellWired html =
    case tagsOf html of
        Err problem ->
            Expect.fail problem

        Ok tags ->
            Expect.equal [] (problemsIn tags)


referenceHelperTests : Test
referenceHelperTests =
    let
        problems tree =
            tagsOf tree |> Result.map problemsIn
    in
    describe "the check that every id that is named exists (the check itself)"
        [ test "finds the tags and their attributes" <|
            \_ ->
                tagsOf (Html.div [ Attr.id "a", Attr.class "b c" ] [ Html.input [ Attr.type_ "text", Attr.disabled True ] [] ])
                    |> Result.map (List.map (\tag -> ( tag.name, tag.attributes )))
                    |> Expect.equal (Ok [ ( "div", [ ( "class", "b c" ), ( "id", "a" ) ] ), ( "input", [ ( "type", "text" ) ] ) ])
        , test "accepts a label that is for an input that exists" <|
            \_ ->
                problems (Html.div [] [ Html.label [ Attr.for "name" ] [ Html.text "Name" ], Html.input [ Attr.id "name" ] [] ])
                    |> Expect.equal (Ok [])
        , test "finds a label that is for an id that does not exist" <|
            \_ ->
                problems (Html.div [] [ Html.label [ Attr.for "nme" ] [ Html.text "Name" ], Html.input [ Attr.id "name" ] [] ])
                    |> Expect.equal (Ok [ "<label> htmlFor names \"nme\", which no element has" ])
        , test "finds a reference to an id that is not there, in a list of ids" <|
            \_ ->
                problems (Html.div [] [ Html.input [ Attr.id "x", Attr.attribute "aria-describedby" "x-hint x-error" ] [], Html.p [ Attr.id "x-hint" ] [] ])
                    |> Expect.equal (Ok [ "<input> aria-describedby names \"x-error\", which no element has" ])
        , test "accepts a list of ids that all exist" <|
            \_ ->
                problems (Html.div [] [ Html.input [ Attr.id "x", Attr.attribute "aria-describedby" "x-hint x-error" ] [], Html.p [ Attr.id "x-hint" ] [], Html.p [ Attr.id "x-error" ] [] ])
                    |> Expect.equal (Ok [])
        , test "checks aria-controls and aria-labelledby too" <|
            \_ ->
                problems (Html.div [] [ Html.button [ Attr.attribute "aria-controls" "panel" ] [], Html.div [ Attr.attribute "aria-labelledby" "title" ] [] ])
                    |> Expect.equal (Ok [ "<button> aria-controls names \"panel\", which no element has", "<div> aria-labelledby names \"title\", which no element has" ])
        , test "finds an id that is used twice" <|
            \_ ->
                problems (Html.div [] [ Html.span [ Attr.id "same" ] [], Html.span [ Attr.id "same" ] [], Html.span [ Attr.id "other" ] [] ])
                    |> Expect.equal (Ok [ "the id \"same\" is used more than once" ])
        , test "finds a label for something that cannot be labelled" <|
            \_ ->
                problems (Html.div [] [ Html.label [ Attr.for "x" ] [], Html.div [ Attr.id "x" ] [] ])
                    |> Expect.equal (Ok [ "a label is for \"x\", which is a <div>" ])
        , test "is not confused by a > inside an attribute value" <|
            \_ ->
                problems (Html.div [] [ Html.span [ Attr.title "a > b", Attr.id "x" ] [], Html.label [ Attr.for "x" ] [] ])
                    |> Expect.equal (Ok [ "a label is for \"x\", which is a <span>" ])
        , test "sees the attributes after a value with spaces in it" <|
            \_ ->
                problems (Html.div [] [ Html.span [ Attr.title "two words", Attr.attribute "aria-controls" "missing" ] [] ])
                    |> Expect.equal (Ok [ "<span> aria-controls names \"missing\", which no element has" ])
        , test "skips closing tags and text" <|
            \_ ->
                tagsOf (Html.p [] [ Html.text "x", Html.b [] [ Html.text "y" ] ])
                    |> Result.map (List.map .name)
                    |> Expect.equal (Ok [ "p", "b" ])
        ]



-- HELPERS


type Msg
    = Clicked
    | Changed String
    | Checked Bool
    | Dismissed
    | Entered
    | TabsMsg (Tabs.Msg OrderTab)
    | Page Int
    | PageSize Int


{-| The element at the root of the HTML has all these.
-}
rootHas : List Selector -> Html Msg -> Expectation
rootHas selectors html =
    html |> Query.fromHtml |> Query.has selectors


rootLacks : List Selector -> Html Msg -> Expectation
rootLacks selectors html =
    html |> Query.fromHtml |> Query.hasNot selectors


{-| The one element inside the root that matches `find` has all these.
-}
inside : List Selector -> List Selector -> Html Msg -> Expectation
inside find selectors html =
    html |> Query.fromHtml |> Query.find find |> Query.has selectors


none : List Selector -> Html Msg -> Expectation
none find html =
    html |> Query.fromHtml |> Query.findAll find |> Query.count (Expect.equal 0)


count : Int -> List Selector -> Html Msg -> Expectation
count n find html =
    html |> Query.fromHtml |> Query.findAll find |> Query.count (Expect.equal n)


attr : String -> String -> Selector
attr name value =
    Selector.attribute (Attr.attribute name value)


{-| The message that an element sends for an event, or why it sends none.
-}
sends : List Selector -> ( String, Encode.Value ) -> Html Msg -> Result String Msg
sends find event html =
    html
        |> Query.fromHtml
        |> Query.find find
        |> Event.simulate event
        |> Event.toResult


sendsFromRoot : ( String, Encode.Value ) -> Html Msg -> Result String Msg
sendsFromRoot event html =
    html
        |> Query.fromHtml
        |> Event.simulate event
        |> Event.toResult


keyEvent : String -> ( String, Encode.Value )
keyEvent key =
    Event.custom "keydown"
        (Encode.object
            [ ( "key", Encode.string key )
            , ( "ctrlKey", Encode.bool False )
            , ( "metaKey", Encode.bool False )
            , ( "shiftKey", Encode.bool False )
            , ( "altKey", Encode.bool False )
            ]
        )


sendsNothing : Result String Msg -> Expectation
sendsNothing result =
    case result of
        Err _ ->
            Expect.pass

        Ok msg ->
            Expect.fail "The element sent a message, but it should send none."



-- BUTTONS


buttonTests : Test
buttonTests =
    let
        plain =
            Button.view [] "Save"
    in
    describe "Button"
        [ test "is a button of type 'button' with its label" <|
            \_ -> rootHas [ Selector.tag "button", Selector.attribute (Attr.type_ "button"), Selector.text "Save" ] plain
        , test "has no state attributes unless it is given some" <|
            \_ ->
                plain
                    |> Expect.all
                        [ rootLacks [ attr "aria-busy" "true" ]
                        , rootLacks [ attr "aria-disabled" "true" ]
                        , rootLacks [ attr "aria-pressed" "true" ]
                        , rootLacks [ attr "aria-pressed" "false" ]
                        , rootLacks [ attr "aria-expanded" "true" ]
                        , rootLacks [ attr "aria-expanded" "false" ]
                        , rootLacks [ Selector.disabled True ]
                        ]
        , test "the default look is secondary, and medium" <|
            \_ -> rootHas [ Selector.classes [ "klar-button", "klar-button--secondary", "klar-button--md" ] ] plain
        , test "primary" <|
            \_ -> rootHas [ Selector.class "klar-button--primary" ] (Button.view [ Button.primary ] "Save")
        , test "danger on its own is the solid red button" <|
            \_ -> rootHas [ Selector.class "klar-button--danger" ] (Button.view [ Button.danger ] "Delete")
        , test "danger with ghost keeps the quiet look and only changes the tone" <|
            \_ -> rootHas [ Selector.classes [ "klar-button--ghost", "klar-button--tone-danger" ] ] (Button.view [ Button.ghost, Button.danger ] "Delete")
        , test "the order of danger and ghost does not matter" <|
            \_ -> rootHas [ Selector.classes [ "klar-button--ghost", "klar-button--tone-danger" ] ] (Button.view [ Button.danger, Button.ghost ] "Delete")
        , test "danger with primary is solid red" <|
            \_ -> rootHas [ Selector.class "klar-button--danger" ] (Button.view [ Button.primary, Button.danger ] "Delete")
        , test "later attributes win: ghost after primary" <|
            \_ -> rootHas [ Selector.class "klar-button--ghost" ] (Button.view [ Button.primary, Button.ghost ] "x")
        , test "small" <|
            \_ -> rootHas [ Selector.class "klar-button--sm" ] (Button.view [ Button.small ] "x")
        , test "large" <|
            \_ -> rootHas [ Selector.class "klar-button--lg" ] (Button.view [ Button.large ] "x")
        , test "submit makes it a submit button" <|
            \_ -> rootHas [ Selector.attribute (Attr.type_ "submit") ] (Button.view [ Button.submit ] "Send")
        , test "a button that is loading never submits" <|
            \_ -> rootHas [ Selector.attribute (Attr.type_ "button") ] (Button.view [ Button.submit, Button.loading True ] "Send")
        , test "nor does a button that is disabled" <|
            \_ -> rootHas [ Selector.attribute (Attr.type_ "button") ] (Button.view [ Button.submit, Button.disabled True ] "Send")
        , test "nor does one that is aria-disabled" <|
            \_ -> rootHas [ Selector.attribute (Attr.type_ "button") ] (Button.view [ Button.submit, Button.ariaDisabled True ] "Send")
        , test "disabled uses the HTML attribute and says so for assistive technology" <|
            \_ -> rootHas [ Selector.disabled True, attr "aria-disabled" "true" ] (Button.view [ Button.disabled True ] "Save")
        , test "disabled False is not disabled" <|
            \_ -> rootHas [ Selector.disabled False ] (Button.view [ Button.disabled False ] "Save")
        , test "ariaDisabled keeps the button in the tab order: it is not disabled for the browser" <|
            \_ -> rootHas [ Selector.disabled False, attr "aria-disabled" "true", Selector.class "klar-button--disabled" ] (Button.view [ Button.ariaDisabled True ] "Save")
        , test "loading is busy and says it is disabled" <|
            \_ -> rootHas [ attr "aria-busy" "true", attr "aria-disabled" "true", Selector.class "klar-button--loading" ] (Button.view [ Button.loading True ] "Save")
        , test "loading shows a spinner instead of the icon" <|
            \_ ->
                Button.view [ Button.loading True, Button.icon Icon.plus ] "Save"
                    |> Expect.all
                        [ count 1 [ Selector.class "klar-spinner" ]
                        , none [ Selector.class "klar-icon--plus" ]
                        ]
        , test "the label stays while loading" <|
            \_ -> rootHas [ Selector.text "Save" ] (Button.view [ Button.loading True ] "Save")
        , test "an icon comes before the label" <|
            \_ -> count 1 [ Selector.class "klar-icon--plus" ] (Button.view [ Button.icon Icon.plus ] "New")
        , test "an icon on the right" <|
            \_ -> count 1 [ Selector.class "klar-icon--chevron-down" ] (Button.view [ Button.iconRight Icon.chevronDown ] "More")
        , test "pressed True" <|
            \_ -> rootHas [ attr "aria-pressed" "true" ] (Button.view [ Button.pressed True ] "Archived")
        , test "pressed False is still a toggle" <|
            \_ -> rootHas [ attr "aria-pressed" "false" ] (Button.view [ Button.pressed False ] "Archived")
        , test "expanded True" <|
            \_ -> rootHas [ attr "aria-expanded" "true" ] (Button.view [ Button.expanded True ] "Menu")
        , test "expanded False" <|
            \_ -> rootHas [ attr "aria-expanded" "false" ] (Button.view [ Button.expanded False ] "Menu")
        , test "the id, the title and the accessible name" <|
            \_ ->
                rootHas [ Selector.id "save", Selector.attribute (Attr.title "Save now"), attr "aria-label" "Save the order" ]
                    (Button.view [ Button.id "save", Button.title "Save now", Button.ariaLabel "Save the order" ] "Save")
        , test "block" <|
            \_ -> rootHas [ Selector.class "klar-button--block" ] (Button.view [ Button.block ] "Save")
        , test "an icon-only button is named by its label, shows it as a Klar tooltip, and has no text of its own" <|
            \_ ->
                Button.iconOnly [ Button.ghost ] Icon.refresh "Reload"
                    |> Expect.all
                        [ rootHas [ attr "aria-label" "Reload", attr "data-tip" "Reload", Selector.class "klar-button--icon-only" ]
                        , rootLacks [ Selector.attribute (Attr.title "Reload") ]
                        , none [ Selector.class "klar-button__label" ]
                        ]
        , test "the title of an icon-only button is the text of its tooltip, not a second, native one" <|
            \_ ->
                Button.iconOnly [ Button.title "Reload the list" ] Icon.refresh "Reload"
                    |> Expect.all
                        [ rootHas [ attr "data-tip" "Reload the list", attr "aria-label" "Reload" ]
                        , rootLacks [ Selector.attribute (Attr.title "Reload the list") ]
                        ]
        , test "a button with a label has no tooltip of its own" <|
            \_ -> rootLacks [ attr "data-tip" "Save" ] (Button.view [] "Save")
        , test "htmlAttrs adds raw attributes" <|
            \_ -> rootHas [ attr "data-test" "x" ] (Button.view [ Button.htmlAttrs [ Attr.attribute "data-test" "x" ] ] "x")
        , test "a group is a group" <|
            \_ -> rootHas [ attr "role" "group" ] (ButtonGroup.view [] "Period" [ Button.view [] "Day", Button.view [] "Week" ])
        , describe "as a link"
            [ test "href makes it an anchor" <|
                \_ -> rootHas [ Selector.tag "a", Selector.attribute (Attr.href "#/orders"), Selector.text "Orders" ] (Button.view [ Button.href orders ] "Orders")
            , test "with the look of a button" <|
                \_ -> rootHas [ Selector.classes [ "klar-button", "klar-button--primary" ] ] (Button.view [ Button.href orders, Button.primary ] "Orders")
            , test "an anchor is not a button" <|
                \_ -> rootLacks [ Selector.tag "button" ] (Button.view [ Button.href orders ] "Orders")
            , test "newTab opens a new tab safely, and says so to a screen reader" <|
                \_ ->
                    Button.view [ Button.href orders, Button.newTab ] "Orders"
                        |> Expect.all
                            [ rootHas [ Selector.attribute (Attr.target "_blank"), Selector.attribute (Attr.rel "noopener noreferrer") ]
                            , rootHas [ Selector.class "klar-sr-only", Selector.text "(opens in a new tab)" ]
                            ]
            , test "the text for a new tab follows the locale" <|
                \_ -> rootHas [ Selector.class "klar-sr-only", Selector.text "(åpnes i en ny fane)" ] (Button.view [ Button.href orders, Button.newTab, Button.locale Locale.nb ] "Ordrer")
            , test "a link to another site opens in a new tab by itself" <|
                \_ ->
                    case Link.external "https://example.com/docs" of
                        Just docs ->
                            rootHas [ Selector.attribute (Attr.target "_blank"), Selector.attribute (Attr.href "https://example.com/docs") ] (Button.view [ Button.href docs ] "Docs")

                        Nothing ->
                            Expect.fail "a web address is a target"
            , test "an icon-only link that opens a tab says so in its name" <|
                \_ -> rootHas [ attr "aria-label" "Orders (opens in a new tab)" ] (Button.iconOnly [ Button.href orders, Button.newTab ] Icon.externalLink "Orders")
            , test "without newTab there is no target" <|
                \_ -> rootLacks [ Selector.attribute (Attr.target "_blank") ] (Button.view [ Button.href orders ] "x")
            , test "a download is a data address with the file name" <|
                \_ ->
                    Button.view [ Button.href (Link.download { fileName = "orders.csv", mimeType = "text/csv", content = "id" }) ] "Export"
                        |> rootHas [ Selector.attribute (Attr.href "data:text/csv;charset=utf-8,id"), attr "download" "orders.csv" ]
            , test "a button without href and a file to save never say they open a tab" <|
                \_ ->
                    Expect.all
                        [ \_ -> Button.view [ Button.newTab ] "Save" |> rootLacks [ Selector.class "klar-sr-only" ]
                        , \_ ->
                            Button.view [ Button.newTab, Button.href (Link.download { fileName = "a.csv", mimeType = "text/csv", content = "a" }) ] "Export"
                                |> Expect.all
                                    [ rootLacks [ Selector.attribute (Attr.target "_blank") ]
                                    , rootLacks [ Selector.class "klar-sr-only" ]
                                    ]
                        ]
                        ()
            , test "a link is never pressed or expanded" <|
                \_ ->
                    Button.view [ Button.href orders, Button.pressed True, Button.expanded True ] "Orders"
                        |> Expect.all
                            [ rootLacks [ attr "aria-pressed" "true" ]
                            , rootLacks [ attr "aria-expanded" "true" ]
                            ]
            , test "a link that is disabled has no href, says so, and leaves the tab order like a disabled button" <|
                \_ ->
                    Button.view [ Button.href orders, Button.disabled True ] "Orders"
                        |> Expect.all
                            [ rootLacks [ Selector.attribute (Attr.href "#/orders") ]
                            , rootHas [ attr "aria-disabled" "true", attr "role" "link" ]
                            , rootLacks [ Selector.attribute (Attr.tabindex 0) ]
                            ]
            , test "a link that is loading or ariaDisabled has no href but keeps its place in the tab order" <|
                \_ ->
                    Expect.all
                        [ \_ -> Button.view [ Button.href orders, Button.loading True ] "Orders" |> rootLacks [ Selector.attribute (Attr.href "#/orders") ]
                        , \_ -> Button.view [ Button.href orders, Button.loading True ] "Orders" |> rootHas [ Selector.attribute (Attr.tabindex 0), attr "role" "link" ]
                        , \_ -> Button.view [ Button.href orders, Button.ariaDisabled True ] "Orders" |> rootHas [ Selector.attribute (Attr.tabindex 0), attr "aria-disabled" "true" ]
                        ]
                        ()
            , test "an inactive link is marked so that Browser.application leaves its click alone" <|
                \_ -> rootHas [ attr "target" "_self" ] (Button.view [ Button.href orders, Button.ariaDisabled True ] "Orders")
            ]
        , describe "clicks"
            [ test "a click sends the message" <|
                \_ -> Expect.equal (Ok Clicked) (sendsFromRoot Event.click (Button.view [ Button.onClick Clicked ] "x"))
            , test "a button that is disabled sends nothing" <|
                \_ -> sendsNothing (sendsFromRoot Event.click (Button.view [ Button.onClick Clicked, Button.disabled True ] "x"))
            , test "a button that is loading sends nothing" <|
                \_ -> sendsNothing (sendsFromRoot Event.click (Button.view [ Button.onClick Clicked, Button.loading True ] "x"))
            , test "a button that is aria-disabled sends nothing" <|
                \_ -> sendsNothing (sendsFromRoot Event.click (Button.view [ Button.onClick Clicked, Button.ariaDisabled True ] "x"))
            , test "it works again when loading ends" <|
                \_ -> Expect.equal (Ok Clicked) (sendsFromRoot Event.click (Button.view [ Button.onClick Clicked, Button.loading False ] "x"))
            , test "a button without a message sends nothing" <|
                \_ -> sendsNothing (sendsFromRoot Event.click (Button.view [] "x"))
            ]
        , test "no id is used twice" <|
            \_ -> expectWellWired (Button.view [ Button.id "a", Button.expanded False, Button.icon Icon.plus ] "x")
        ]



-- TEXT INPUTS


textInputTests : Test
textInputTests =
    let
        full =
            TextInput.view
                [ TextInput.id "email"
                , TextInput.label "Email"
                , TextInput.hint "We never share it."
                , TextInput.error "Not an address"
                , TextInput.required
                , TextInput.value "ada@"
                ]

        input =
            [ Selector.tag "input" ]
    in
    describe "TextInput (the label, the hint and the error)"
        [ test "the label is for the input and the input has the id" <|
            \_ ->
                full
                    |> Expect.all
                        [ inside [ Selector.tag "label" ] [ Selector.attribute (Attr.for "email"), Selector.id "email-label", Selector.text "Email" ]
                        , inside input [ Selector.id "email" ]
                        ]
        , test "the input points at the hint and the error message" <|
            \_ -> inside input [ attr "aria-describedby" "email-hint email-error" ] full
        , test "and they exist" <|
            \_ ->
                full
                    |> Expect.all
                        [ inside [ Selector.id "email-hint" ] [ Selector.text "We never share it." ]
                        , inside [ Selector.id "email-error" ] [ Selector.text "Not an address" ]
                        ]
        , test "an error is announced when it appears" <|
            \_ -> inside [ Selector.id "email-error" ] [ attr "role" "alert" ] full
        , test "an error marks the input invalid" <|
            \_ -> inside input [ attr "aria-invalid" "true" ] full
        , test "a required input says so, and the star is hidden from screen readers" <|
            \_ ->
                full
                    |> Expect.all
                        [ inside input [ attr "aria-required" "true" ]
                        , inside [ Selector.class "klar-field__required" ] [ attr "aria-hidden" "true", Selector.text "*" ]
                        ]
        , test "everything points at an element that exists" <|
            \_ -> expectWellWired full
        , test "with a hint only, the input points at the hint only" <|
            \_ ->
                TextInput.view [ TextInput.id "x", TextInput.label "X", TextInput.hint "h" ]
                    |> Expect.all
                        [ inside input [ attr "aria-describedby" "x-hint" ]
                        , none [ Selector.id "x-error" ]
                        ]
        , test "with an error only, the input points at the error only" <|
            \_ -> inside input [ attr "aria-describedby" "x-error" ] (TextInput.view [ TextInput.id "x", TextInput.label "X", TextInput.error "e" ])
        , test "with neither it points at nothing, and is not invalid" <|
            \_ ->
                TextInput.view [ TextInput.id "x", TextInput.label "X" ]
                    |> Expect.all
                        [ inside input [ Selector.id "x" ]
                        , none [ Selector.tag "input", attr "aria-invalid" "true" ]
                        , none [ Selector.tag "input", Selector.attribute (Attr.attribute "aria-describedby" "x-hint") ]
                        , expectWellWired
                        ]
        , test "errorMaybe Nothing is no error" <|
            \_ ->
                TextInput.view [ TextInput.id "x", TextInput.label "X", TextInput.errorMaybe Nothing ]
                    |> Expect.all [ none [ Selector.id "x-error" ], none [ attr "aria-invalid" "true" ] ]
        , test "errorMaybe Just is an error" <|
            \_ -> inside [ Selector.id "x-error" ] [ Selector.text "bad" ] (TextInput.view [ TextInput.id "x", TextInput.label "X", TextInput.errorMaybe (Just "bad") ])
        , test "the optional text follows the label of a field that is not required" <|
            \_ -> inside [ Selector.tag "label" ] [ Selector.text "(optional)" ] (TextInput.view [ TextInput.id "x", TextInput.label "X", TextInput.optionalText "(optional)" ])
        , test "but never the label of a required one" <|
            \_ -> none [ Selector.class "klar-field__optional" ] (TextInput.view [ TextInput.id "x", TextInput.label "X", TextInput.optionalText "(optional)", TextInput.required ])
        , test "a hidden label is still there, for screen readers" <|
            \_ -> inside [ Selector.tag "label" ] [ Selector.class "klar-sr-only", Selector.text "Search" ] (TextInput.view [ TextInput.id "x", TextInput.label "Search", TextInput.labelHidden ])
        , test "without an id the id is made from the label, and the label is for it" <|
            \_ ->
                TextInput.view [ TextInput.label "Customer name" ]
                    |> Expect.all
                        [ inside input [ Selector.id "klar-input-customer__name" ]
                        , inside [ Selector.tag "label" ] [ Selector.attribute (Attr.for "klar-input-customer__name") ]
                        , expectWellWired
                        ]
        , test "without a label the id is made from the placeholder" <|
            \_ -> inside input [ Selector.id "klar-input-search__orders" ] (TextInput.view [ TextInput.placeholder "Search orders", TextInput.hint "h" ])
        , test "without a label or a placeholder the id is made from the hint" <|
            \_ -> inside input [ Selector.id "klar-input-h" ] (TextInput.view [ TextInput.hint "h" ])
        , test "an input with nothing to say is inside the field too, so that it does not move when an error comes" <|
            \_ ->
                TextInput.view [ TextInput.id "x", TextInput.value "v" ]
                    |> Expect.all [ rootHas [ Selector.class "klar-field" ], inside [ Selector.tag "input" ] [ Selector.id "x" ] ]
        , test "the input is as deep in the tree with an error as without one: it does not move" <|
            \_ ->
                Expect.all
                    [ \depths -> Expect.equal (Tuple.first depths) (Tuple.second depths)
                    , \depths -> Expect.notEqual Nothing (Tuple.first depths)
                    ]
                    ( inputDepth (TextInput.view [ TextInput.id "x" ]), inputDepth (TextInput.view [ TextInput.id "x", TextInput.error "e" ]) )
        , test "the value, the placeholder and the type" <|
            \_ ->
                inside input
                    [ Selector.attribute (Attr.value "Ada"), Selector.attribute (Attr.placeholder "Name"), Selector.attribute (Attr.type_ "email") ]
                    (TextInput.view [ TextInput.id "x", TextInput.value "Ada", TextInput.placeholder "Name", TextInput.email ])
        , test "the default type is text" <|
            \_ -> inside input [ Selector.attribute (Attr.type_ "text") ] (TextInput.view [ TextInput.id "x" ])
        , test "tel sets the type" <|
            \_ -> inside input [ Selector.attribute (Attr.type_ "tel") ] (TextInput.view [ TextInput.id "x", TextInput.tel ])
        , test "url sets the type" <|
            \_ -> inside input [ Selector.attribute (Attr.type_ "url") ] (TextInput.view [ TextInput.id "x", TextInput.url ])
        , test "disabled" <|
            \_ -> inside input [ Selector.disabled True ] (TextInput.view [ TextInput.id "x", TextInput.disabled True ])
        , test "read-only" <|
            \_ -> inside input [ Selector.attribute (Attr.readonly True) ] (TextInput.view [ TextInput.id "x", TextInput.readOnly True ])
        , test "maxLength shows a counter and does not cut the text" <|
            \_ ->
                TextInput.view [ TextInput.id "x", TextInput.value "Ada", TextInput.maxLength 20 ]
                    |> Expect.all
                        [ inside [ Selector.class "klar-counter" ] [ Selector.text "3/20" ]
                        , inside input [ attr "aria-describedby" "x-counter" ]
                        , none [ Selector.attribute (Attr.maxlength 20) ]
                        ]
        , test "the browser hints" <|
            \_ ->
                inside input
                    [ Selector.attribute (Attr.name "email"), attr "autocomplete" "email", attr "inputmode" "email" ]
                    (TextInput.view [ TextInput.id "x", TextInput.name "email", TextInput.autocomplete "email", TextInput.inputMode "email" ])
        , test "search puts a magnifying glass in front and asks for the search keyboard" <|
            \_ ->
                TextInput.view [ TextInput.id "x", TextInput.search ]
                    |> Expect.all
                        [ inside [ Selector.class "klar-input__prefix", Selector.containing [ Selector.class "klar-icon--search" ] ] []
                        , inside input [ attr "inputmode" "search" ]
                        ]
        , test "prefix and suffix text" <|
            \_ ->
                TextInput.view [ TextInput.id "x", TextInput.prefixText "kr", TextInput.suffixText "per kg" ]
                    |> Expect.all
                        [ inside [ Selector.class "klar-input__prefix" ] [ Selector.text "kr" ]
                        , inside [ Selector.class "klar-input__suffix" ] [ Selector.text "per kg" ]
                        ]
        , describe "the clear button"
            [ test "is there while there is text and the input can be changed" <|
                \_ -> inside [ Selector.class "klar-input__clear" ] [ attr "aria-label" "Clear field" ] (TextInput.view [ TextInput.id "x", TextInput.value "a", TextInput.clearable, TextInput.onInput Changed ])
            , test "is named in the language of the input" <|
                \_ -> inside [ Selector.class "klar-input__clear" ] [ attr "aria-label" "Tøm feltet" ] (TextInput.view [ TextInput.id "x", TextInput.value "a", TextInput.clearable, TextInput.onInput Changed, TextInput.locale Locale.nb ])
            , test "is not in the tab order" <|
                \_ -> inside [ Selector.class "klar-input__clear" ] [ Selector.attribute (Attr.tabindex -1), Selector.attribute (Attr.type_ "button") ] (TextInput.view [ TextInput.id "x", TextInput.value "a", TextInput.clearable, TextInput.onInput Changed ])
            , test "is not there without text" <|
                \_ -> none [ Selector.class "klar-input__clear" ] (TextInput.view [ TextInput.id "x", TextInput.value "", TextInput.clearable, TextInput.onInput Changed ])
            , test "is not there when the input is disabled" <|
                \_ -> none [ Selector.class "klar-input__clear" ] (TextInput.view [ TextInput.id "x", TextInput.value "a", TextInput.clearable, TextInput.onInput Changed, TextInput.disabled True ])
            , test "is not there when the input is read only" <|
                \_ -> none [ Selector.class "klar-input__clear" ] (TextInput.view [ TextInput.id "x", TextInput.value "a", TextInput.clearable, TextInput.onInput Changed, TextInput.readOnly True ])
            , test "is not there without onInput, which it would send its empty text to" <|
                \_ -> none [ Selector.class "klar-input__clear" ] (TextInput.view [ TextInput.id "x", TextInput.value "a", TextInput.clearable ])
            , test "sends the empty text when clicked" <|
                \_ -> Expect.equal (Ok (Changed "")) (sends [ Selector.class "klar-input__clear" ] Event.click (TextInput.view [ TextInput.id "x", TextInput.value "a", TextInput.clearable, TextInput.onInput Changed ]))
            ]
        , describe "events"
            [ test "typing sends the whole text" <|
                \_ -> Expect.equal (Ok (Changed "Ada")) (sends input (Event.input "Ada") (TextInput.view [ TextInput.id "x", TextInput.onInput Changed ]))
            , test "Enter sends the message of onEnter" <|
                \_ -> Expect.equal (Ok Entered) (sends input (keyEvent "Enter") (TextInput.view [ TextInput.id "x", TextInput.onEnter Entered ]))
            , test "and keeps the browser from submitting a form" <|
                \_ ->
                    TextInput.view [ TextInput.id "x", TextInput.onEnter Entered ]
                        |> Query.fromHtml
                        |> Query.find input
                        |> Event.simulate (keyEvent "Enter")
                        |> Event.expectPreventDefault
            , test "another key sends nothing" <|
                \_ -> sendsNothing (sends input (keyEvent "a") (TextInput.view [ TextInput.id "x", TextInput.onEnter Entered ]))
            , test "without onEnter, Enter is left to the browser" <|
                \_ -> sendsNothing (sends input (keyEvent "Enter") (TextInput.view [ TextInput.id "x" ]))
            , test "blur" <|
                \_ -> Expect.equal (Ok Clicked) (sends input Event.blur (TextInput.view [ TextInput.id "x", TextInput.onBlur Clicked, TextInput.onFocus Entered ]))
            , test "focus" <|
                \_ -> Expect.equal (Ok Entered) (sends input Event.focus (TextInput.view [ TextInput.id "x", TextInput.onBlur Clicked, TextInput.onFocus Entered ]))
            ]
        ]



-- FIELD (for controls of your own)


fieldTests : Test
fieldTests =
    let
        config =
            Field.empty
                |> Field.setId "qty"
                |> Field.setLabel "Quantity"
                |> Field.setHint "Whole units"
                |> Field.setError (Just "Too many")
                |> Field.setRequired True

        control =
            Html.input (Field.controlAttributes config) []

        bareConfig =
            Field.empty |> Field.setId "x"
    in
    describe "Field"
        [ test "controlAttributes: the id, what describes the control, invalid and required" <|
            \_ ->
                Field.view config control
                    |> inside [ Selector.tag "input" ] [ Selector.id "qty", attr "aria-describedby" "qty-hint qty-error", attr "aria-invalid" "true", attr "aria-required" "true" ]
        , test "the ids of the parts" <|
            \_ -> Expect.equal ( "qty-label", "qty-hint" ) ( Field.labelId config, Field.hintId config )
        , test "everything is wired" <|
            \_ -> expectWellWired (Field.view config control)
        , test "the wrapper is drawn also without a label, a hint and an error" <|
            \_ ->
                Field.view bareConfig (Html.input (Field.controlAttributes bareConfig) [])
                    |> Expect.all [ rootHas [ Selector.class "klar-field" ], inside [ Selector.tag "input" ] [ Selector.id "x" ] ]
        , test "the control keeps its place when the first error comes (view and viewGroup)" <|
            \_ ->
                let
                    place wrap fieldConfig =
                        wrap fieldConfig (Html.input [ Attr.id "x" ] [])
                            |> Query.fromHtml
                            |> Query.children []
                            |> Query.index 1
                            |> Query.has [ Selector.id "x" ]
                in
                Expect.all
                    [ \_ -> place Field.view bareConfig
                    , \_ -> place Field.view (bareConfig |> Field.setError (Just "Too many"))
                    , \_ -> place Field.viewGroup bareConfig
                    , \_ -> place Field.viewGroup (bareConfig |> Field.setError (Just "Too many"))
                    , \_ -> place Field.viewGroup (bareConfig |> Field.setLabel "Quantity" |> Field.setHint "Whole units")
                    ]
                    ()
        , test "a blank error or hint counts as none: no empty alert, nothing invalid" <|
            \_ ->
                let
                    blank =
                        bareConfig |> Field.setError (Just "") |> Field.setHint "  "
                in
                Field.view blank (Html.input (Field.controlAttributes blank) [])
                    |> Expect.all
                        [ none [ Selector.attribute (Attr.attribute "role" "alert") ]
                        , none [ Selector.class "klar-field__hint" ]
                        , rootLacks [ Selector.class "klar-field--invalid" ]
                        , \html ->
                            Query.fromHtml html
                                |> Query.find [ Selector.tag "input" ]
                                |> Expect.all
                                    [ Query.hasNot [ attr "aria-invalid" "true" ]
                                    , Query.hasNot [ Selector.attribute (Attr.attribute "aria-describedby" "x-hint x-error") ]
                                    ]
                        ]
        , test "a field without an error is not marked invalid" <|
            \_ ->
                Field.view (bareConfig |> Field.setLabel "X") (Html.input (Field.controlAttributes bareConfig) [])
                    |> Expect.all [ none [ Selector.id "x-error" ], rootLacks [ Selector.class "klar-field--invalid" ] ]
        , test "an error marks the whole field" <|
            \_ -> rootHas [ Selector.class "klar-field--invalid" ] (Field.view config control)
        , test "viewWithAside puts something small under the control, level with the hint" <|
            \_ ->
                Field.viewWithAside config (Html.text "5/20") control
                    |> Expect.all
                        [ inside [ Selector.class "klar-field__foot" ] [ Selector.text "5/20" ]
                        , inside [ Selector.class "klar-field__messages" ] [ Selector.text "Whole units", Selector.text "Too many" ]
                        ]
        , test "viewGroup leaves the label to the control, which gives its element the label id" <|
            \_ ->
                Field.viewGroup config (Html.div [ Attr.id (Field.labelId config) ] [ Html.text "Quantity" ])
                    |> Expect.all [ none [ Selector.tag "label" ], inside [ Selector.id "qty-label" ] [ Selector.text "Quantity" ] ]
        , test "viewGroup without a label is the same as view" <|
            \_ -> Expect.equal (printed (Field.view bareConfig (Html.text "c"))) (printed (Field.viewGroup bareConfig (Html.text "c")))
        , test "viewGroup draws the hint and the error of the group" <|
            \_ ->
                Field.viewGroup config (Html.div [ Attr.id (Field.labelId config) ] [ Html.text "Quantity" ])
                    |> Expect.all [ inside [ Selector.id "qty-hint" ] [ Selector.text "Whole units" ], inside [ Selector.id "qty-error" ] [ Selector.text "Too many" ] ]
        ]



-- CHECKBOXES


checkboxTests : Test
checkboxTests =
    let
        box =
            [ Selector.tag "input" ]

        described =
            Checkbox.view [ Checkbox.id "terms", Checkbox.label "I accept the terms", Checkbox.hint "Read them first.", Checkbox.error "You must accept" ]
    in
    describe "Checkbox"
        [ test "is a native checkbox inside a label, so a click on the text toggles it" <|
            \_ ->
                Checkbox.view [ Checkbox.label "Send me the newsletter" ]
                    |> Expect.all
                        [ rootHas [ Selector.tag "label" ]
                        , inside box [ Selector.attribute (Attr.type_ "checkbox") ]
                        , inside [ Selector.class "klar-check__label" ] [ Selector.text "Send me the newsletter" ]
                        ]
        , test "is unchecked by default" <|
            \_ -> inside box [ Selector.checked False ] (Checkbox.view [ Checkbox.label "x" ])
        , test "checked" <|
            \_ -> inside box [ Selector.checked True ] (Checkbox.view [ Checkbox.label "x", Checkbox.checked True ])
        , test "the drawn box is hidden from screen readers" <|
            \_ -> inside [ Selector.class "klar-check__box" ] [ attr "aria-hidden" "true" ] (Checkbox.view [ Checkbox.label "x" ])
        , test "a checkbox with a label only has nothing that describes it" <|
            \_ ->
                Checkbox.view [ Checkbox.label "x" ]
                    |> Expect.all
                        [ none [ Selector.tag "input", Selector.attribute (Attr.attribute "aria-describedby" "klar-check-x-description") ]
                        , rootLacks [ Selector.class "klar-check--bare" ]
                        ]
        , test "a bare checkbox is named by ariaLabel" <|
            \_ ->
                Checkbox.view [ Checkbox.ariaLabel "Select order 1042" ]
                    |> Expect.all [ inside box [ attr "aria-label" "Select order 1042" ], rootHas [ Selector.class "klar-check--bare" ] ]
        , test "a hint is drawn under the label and joins the checkbox with aria-describedby" <|
            \_ ->
                Checkbox.view [ Checkbox.id "terms", Checkbox.label "x", Checkbox.hint "At most one email a month." ]
                    |> Expect.all
                        [ inside [ Selector.class "klar-check__hint" ] [ Selector.id "terms-description", Selector.text "At most one email a month." ]
                        , inside box [ attr "aria-describedby" "terms-description" ]
                        ]
        , test "an error too, and it is announced when it appears" <|
            \_ ->
                Checkbox.view [ Checkbox.id "terms", Checkbox.label "x", Checkbox.error "Choose one" ]
                    |> Expect.all
                        [ inside [ Selector.class "klar-check__error" ] [ Selector.id "terms-error", Selector.text "Choose one", attr "role" "alert" ]
                        , inside box [ attr "aria-describedby" "terms-error", attr "aria-invalid" "true" ]
                        ]
        , test "with both, the checkbox points at both, the hint first" <|
            \_ -> inside box [ attr "aria-describedby" "terms-description terms-error" ] described
        , test "and the name of the checkbox stays the label alone" <|
            \_ ->
                described
                    |> Expect.all
                        [ inside box [ attr "aria-labelledby" "terms-label" ]
                        , inside [ Selector.id "terms-label" ] [ Selector.text "I accept the terms" ]
                        ]
        , test "the ids come from the label when there is no id" <|
            \_ -> inside box [ attr "aria-describedby" "klar-check-send__me__the__newsletter-description" ] (Checkbox.view [ Checkbox.label "Send me the newsletter", Checkbox.hint "h" ])
        , test "a hint and an error are drawn without a label too, but the checkbox needs a name" <|
            \_ ->
                Checkbox.view [ Checkbox.id "agree", Checkbox.ariaLabel "I agree", Checkbox.hint "h", Checkbox.error "e" ]
                    |> Expect.all
                        [ inside [ Selector.class "klar-check__hint" ] [ Selector.text "h" ]
                        , inside [ Selector.class "klar-check__error" ] [ Selector.text "e" ]
                        , inside box [ attr "aria-label" "I agree", attr "aria-describedby" "agree-description agree-error" ]
                        ]
        , test "an empty hint is no hint" <|
            \_ ->
                Checkbox.view [ Checkbox.id "x", Checkbox.label "x", Checkbox.hint "" ]
                    |> Expect.all [ none [ Selector.class "klar-check__hint" ], none [ Selector.tag "input", Selector.attribute (Attr.attribute "aria-describedby" "x-description") ] ]
        , test "an empty error is no error, so there is never a red box without a message" <|
            \_ ->
                Checkbox.view [ Checkbox.id "x", Checkbox.label "x", Checkbox.error "" ]
                    |> Expect.all [ none [ Selector.class "klar-check__error" ], rootLacks [ Selector.class "klar-check--invalid" ], none [ attr "aria-invalid" "true" ] ]
        , test "an error marks the checkbox invalid" <|
            \_ -> Expect.all [ inside box [ attr "aria-invalid" "true" ], rootHas [ Selector.class "klar-check--invalid" ] ] (Checkbox.view [ Checkbox.label "x", Checkbox.error "e" ])
        , test "indeterminate is the native indeterminate state (announced as mixed), and is not checked" <|
            \_ -> inside box [ Selector.attribute (Attr.property "indeterminate" (Encode.bool True)), Selector.checked False ] (Checkbox.view [ Checkbox.ariaLabel "all", Checkbox.checked True, Checkbox.indeterminate True ])
        , test "indeterminate is not written as aria-checked, which a native checkbox does not take" <|
            \_ -> none [ attr "aria-checked" "mixed" ] (Checkbox.view [ Checkbox.ariaLabel "all", Checkbox.indeterminate True ])
        , test "disabled" <|
            \_ -> Expect.all [ inside box [ Selector.disabled True ], rootHas [ Selector.class "klar-check--disabled" ] ] (Checkbox.view [ Checkbox.label "x", Checkbox.disabled True ])
        , test "the id and the tab index" <|
            \_ -> inside box [ Selector.id "terms", Selector.attribute (Attr.tabindex -1) ] (Checkbox.view [ Checkbox.label "x", Checkbox.id "terms", Checkbox.tabIndex -1 ])
        , test "a click sends the new value" <|
            \_ -> Expect.equal (Ok (Checked True)) (sends box (Event.check True) (Checkbox.view [ Checkbox.label "x", Checkbox.onCheck Checked ]))
        , test "and unchecking sends False" <|
            \_ -> Expect.equal (Ok (Checked False)) (sends box (Event.check False) (Checkbox.view [ Checkbox.label "x", Checkbox.checked True, Checkbox.onCheck Checked ]))
        , test "a click on an indeterminate box sends True, whatever the browser says" <|
            \_ -> Expect.equal (Ok (Checked True)) (sends box (Event.check False) (Checkbox.view [ Checkbox.label "x", Checkbox.indeterminate True, Checkbox.onCheck Checked ]))
        , test "without onCheck it sends nothing" <|
            \_ -> sendsNothing (sends box (Event.check True) (Checkbox.view [ Checkbox.label "x" ]))
        , test "its parts are wired" <|
            \_ -> expectWellWired described
        , test "the parts of a checkbox without an id are wired too" <|
            \_ -> expectWellWired (Checkbox.view [ Checkbox.label "Send me the newsletter", Checkbox.hint "h", Checkbox.error "e" ])
        ]



-- ALERTS


alertTests : Test
alertTests =
    let
        alert tone attributes =
            Alert.view (Alert.tone tone :: attributes) "Message"
    in
    describe "Alert"
        [ test "an error is announced at once" <|
            \_ -> rootHas [ attr "role" "alert" ] (alert Theme.Danger [])
        , test "a warning is announced at once" <|
            \_ -> rootHas [ attr "role" "alert" ] (alert Theme.Warning [])
        , test "information waits for a pause" <|
            \_ -> rootHas [ attr "role" "status" ] (alert Theme.Info [])
        , test "success waits for a pause" <|
            \_ -> rootHas [ attr "role" "status" ] (alert Theme.Success [])
        , test "neutral waits for a pause" <|
            \_ -> rootHas [ attr "role" "status" ] (alert Theme.Neutral [])
        , test "primary waits for a pause" <|
            \_ -> rootHas [ attr "role" "status" ] (alert Theme.Primary [])
        , test "the default tone is information" <|
            \_ -> Alert.view [] "Message" |> Expect.all [ rootHas [ attr "role" "status" ], rootHas [ Selector.class "klar-alert--info" ] ]
        , test "polite turns an error into a status" <|
            \_ -> rootHas [ attr "role" "status" ] (alert Theme.Danger [ Alert.polite ])
        , test "and a warning" <|
            \_ -> rootHas [ attr "role" "status" ] (alert Theme.Warning [ Alert.polite ])
        , test "the message" <|
            \_ -> inside [ Selector.class "klar-alert__message" ] [ Selector.text "Message" ] (alert Theme.Info [])
        , test "the title comes above it" <|
            \_ -> inside [ Selector.class "klar-alert__title" ] [ Selector.text "Unsaved changes" ] (alert Theme.Warning [ Alert.title "Unsaved changes" ])
        , test "no title unless given" <|
            \_ -> none [ Selector.class "klar-alert__title" ] (alert Theme.Info [])
        , test "a message made of HTML" <|
            \_ -> count 1 [ Selector.class "klar-alert__message", Selector.containing [ Selector.tag "a" ] ] (Alert.viewWith [] [ Html.text "See the ", Html.a [ Attr.href "#" ] [ Html.text "rules" ] ])
        , test "actions below the message" <|
            \_ -> inside [ Selector.class "klar-alert__actions" ] [ Selector.containing [ Selector.tag "button" ] ] (Alert.viewWith [ Alert.actions [ Button.view [] "Try again" ] ] [ Html.text "x" ])
        , test "no actions area without actions" <|
            \_ -> none [ Selector.class "klar-alert__actions" ] (alert Theme.Info [])
        , test "the icon follows the tone (danger)" <|
            \_ -> count 1 [ Selector.class "klar-icon--error-circle" ] (alert Theme.Danger [])
        , test "the icon follows the tone (warning)" <|
            \_ -> count 1 [ Selector.class "klar-icon--warning" ] (alert Theme.Warning [])
        , test "the icon follows the tone (success)" <|
            \_ -> count 1 [ Selector.class "klar-icon--check-circle" ] (alert Theme.Success [])
        , test "the icon follows the tone (information)" <|
            \_ -> count 1 [ Selector.class "klar-icon--info" ] (alert Theme.Info [])
        , test "another icon replaces it" <|
            \_ -> count 1 [ Selector.class "klar-icon--plus" ] (alert Theme.Info [ Alert.icon Icon.plus ])
        , test "the classes follow the tone, banner and compact" <|
            \_ -> rootHas [ Selector.classes [ "klar-alert--danger", "klar-alert--banner", "klar-alert--compact" ] ] (alert Theme.Danger [ Alert.banner, Alert.compact ])
        , test "there is no close button unless onDismiss is given" <|
            \_ -> none [ Selector.tag "button" ] (alert Theme.Info [])
        , test "the close button has a name" <|
            \_ -> inside [ Selector.tag "button" ] [ attr "aria-label" "Close", Selector.attribute (Attr.type_ "button") ] (alert Theme.Info [ Alert.onDismiss Dismissed ])
        , test "in Norwegian" <|
            \_ -> inside [ Selector.tag "button" ] [ attr "aria-label" "Lukk" ] (alert Theme.Info [ Alert.onDismiss Dismissed, Alert.locale Locale.nb ])
        , test "the close button sends the message" <|
            \_ -> Expect.equal (Ok Dismissed) (sends [ Selector.tag "button" ] Event.click (alert Theme.Info [ Alert.onDismiss Dismissed ]))
        ]



-- TABS


type OrderTab
    = OverviewTab
    | HistoryTab
    | FilesTab
    | BillingTab
    | NoSuchTab


tabsTests : Test
tabsTests =
    let
        tabs =
            [ Tabs.tab OverviewTab "Overview" |> Tabs.withPanel (\_ -> Html.text "The overview")
            , Tabs.tab HistoryTab "History" |> Tabs.withCount 12 |> Tabs.withPanel (\_ -> Html.text "The history")
            , Tabs.tab FilesTab "Files" |> Tabs.withIcon Icon.paperclip
            , Tabs.tab BillingTab "Billing" |> Tabs.disabledTab |> Tabs.withTitle "Available once the order is confirmed"
            ]

        -- the strip and the panel of the active tab, from one call
        page attributes state =
            Tabs.view TabsMsg (Tabs.ariaLabel "Order sections" :: Tabs.tabs tabs :: attributes) state

        start =
            Tabs.init "order-tabs" OverviewTab

        -- the DOM ids follow the place of the tab in the strip
        tab index =
            [ Selector.id ("order-tabs-tab-" ++ String.fromInt index) ]

        after message state =
            case message of
                Ok (TabsMsg tabsMsg) ->
                    Tuple.first (Tabs.update tabsMsg state)

                _ ->
                    state

        pressed attributes state index name =
            after (page attributes state |> sends (tab index) (keyEvent name)) state

        clicked index =
            after (page [] start |> sends (tab index) Event.click) start
    in
    describe "Tabs"
        [ test "a strip of tabs with a name" <|
            \_ -> inside [ attr "role" "tablist" ] [ attr "aria-label" "Order sections" ] (page [] start)
        , test "every tab is a tab" <|
            \_ -> count 4 [ attr "role" "tab" ] (page [] start)
        , test "the active tab is selected and the others are not" <|
            \_ ->
                page [] start
                    |> Expect.all
                        [ inside (tab 0) [ attr "aria-selected" "true" ]
                        , inside (tab 1) [ attr "aria-selected" "false" ]
                        , inside (tab 2) [ attr "aria-selected" "false" ]
                        , inside (tab 3) [ attr "aria-selected" "false" ]
                        ]
        , test "the active tab names its panel, and the panel is there and is named by the tab" <|
            \_ ->
                page [] start
                    |> Expect.all
                        [ inside (tab 0) [ attr "aria-controls" "order-tabs-panel-0" ]
                        , inside [ Selector.id "order-tabs-panel-0" ] [ attr "role" "tabpanel", attr "aria-labelledby" "order-tabs-tab-0", Selector.text "The overview" ]
                        ]
        , test "the other tabs do not name a panel, because their panels are not there" <|
            \_ -> none [ Selector.id "order-tabs-tab-1", attr "aria-controls" "order-tabs-panel-1" ] (page [] start)
        , test "only the panel of the active tab is drawn" <|
            \_ -> none [ Selector.text "The history" ] (page [] start)
        , test "the panel can be focused, so that Tab goes from the tab into it" <|
            \_ -> inside [ Selector.id "order-tabs-panel-0" ] [ Selector.attribute (Attr.tabindex 0) ] (page [] start)
        , test "only the active tab is in the tab order" <|
            \_ ->
                page [] start
                    |> Expect.all
                        [ inside (tab 0) [ Selector.attribute (Attr.tabindex 0) ]
                        , inside (tab 1) [ Selector.attribute (Attr.tabindex -1) ]
                        , inside (tab 2) [ Selector.attribute (Attr.tabindex -1) ]
                        ]
        , test "a disabled tab is disabled, and has its title" <|
            \_ -> inside (tab 3) [ Selector.disabled True, Selector.attribute (Attr.title "Available once the order is confirmed") ] (page [] start)
        , test "a count" <|
            \_ -> inside (tab 1) [ Selector.containing [ Selector.class "klar-tabs__count", Selector.text "12" ] ] (page [] start)
        , test "a count is grouped the way the language writes numbers" <|
            \_ ->
                Tabs.view TabsMsg [ Tabs.locale Locale.nb, Tabs.tabs [ Tabs.tab OverviewTab "Notes" |> Tabs.withCount 12345 ] ] start
                    |> inside (tab 0) [ Selector.containing [ Selector.class "klar-tabs__count", Selector.text "12\u{00A0}345" ] ]
        , test "an icon" <|
            \_ -> inside (tab 2) [ Selector.containing [ Selector.class "klar-icon--paperclip" ] ] (page [] start)
        , test "tabs are buttons that do not submit a form" <|
            \_ -> inside (tab 0) [ Selector.tag "button", Selector.attribute (Attr.type_ "button") ] (page [] start)
        , test "everything that is named exists" <|
            \_ -> expectWellWired (page [] start)
        , test "everything that is named exists after another tab was chosen" <|
            \_ -> expectWellWired (page [] (Tabs.setActive HistoryTab start))
        , test "the panel follows the state" <|
            \_ -> inside [ Selector.id "order-tabs-panel-1" ] [ Selector.text "The history", attr "aria-labelledby" "order-tabs-tab-1" ] (page [] (Tabs.setActive HistoryTab start))
        , test "a tab without a panel claims none" <|
            \_ -> none [ Selector.attribute (Attr.attribute "aria-controls" "order-tabs-panel-2") ] (page [] (Tabs.setActive FilesTab start))
        , test "a strip without panels leaves out aria-controls and the panel" <|
            \_ ->
                Tabs.view TabsMsg [ Tabs.tabs [ Tabs.tab OverviewTab "Overview", Tabs.tab HistoryTab "History" ] ] start
                    |> Expect.all
                        [ none [ Selector.attribute (Attr.attribute "aria-controls" "order-tabs-panel-0") ]
                        , none [ attr "role" "tabpanel" ]
                        , expectWellWired
                        ]
        , test "boxed, small and fill are classes" <|
            \_ -> inside [ Selector.class "klar-tabs" ] [ Selector.classes [ "klar-tabs--boxed", "klar-tabs--sm", "klar-tabs--fill" ] ] (page [ Tabs.boxed, Tabs.small, Tabs.fill ] start)
        , test "a vertical strip says so" <|
            \_ -> inside [ attr "role" "tablist" ] [ attr "aria-orientation" "vertical" ] (page [ Tabs.vertical ] start)
        , describe "clicking and keys"
            [ test "a click chooses a tab" <|
                \_ -> Expect.equal HistoryTab (Tabs.active (clicked 1))
            , test "a disabled tab sends nothing" <|
                \_ -> sendsNothing (page [] start |> sends (tab 3) Event.click)
            , test "ArrowRight moves to the next tab and chooses it" <|
                \_ -> Expect.equal HistoryTab (Tabs.active (pressed [] start 0 "ArrowRight"))
            , test "ArrowLeft wraps around to the last tab that can be chosen: the disabled one is skipped" <|
                \_ -> Expect.equal FilesTab (Tabs.active (pressed [] start 0 "ArrowLeft"))
            , test "ArrowRight from the last enabled tab wraps to the first" <|
                \_ -> Expect.equal OverviewTab (Tabs.active (pressed [] (Tabs.setActive FilesTab start) 2 "ArrowRight"))
            , test "Home goes to the first tab" <|
                \_ -> Expect.equal OverviewTab (Tabs.active (pressed [] (Tabs.setActive HistoryTab start) 1 "Home"))
            , test "End goes to the last tab that can be chosen" <|
                \_ -> Expect.equal FilesTab (Tabs.active (pressed [] start 0 "End"))
            , test "a vertical strip moves with ArrowDown" <|
                \_ -> Expect.equal HistoryTab (Tabs.active (pressed [ Tabs.vertical ] start 0 "ArrowDown"))
            , test "a vertical strip does not move with ArrowRight" <|
                \_ -> sendsNothing (page [ Tabs.vertical ] start |> sends (tab 0) (keyEvent "ArrowRight"))
            , test "with manual activation the arrow keys only move the focus" <|
                \_ -> Expect.equal OverviewTab (Tabs.active (pressed [ Tabs.manual ] start 0 "ArrowRight"))
            , test "with manual activation the selected tab stays the one in the tab order" <|
                \_ ->
                    page [ Tabs.manual ] (pressed [ Tabs.manual ] start 0 "ArrowRight")
                        |> Expect.all
                            [ inside (tab 0) [ Selector.attribute (Attr.tabindex 0), attr "aria-selected" "true" ]
                            , inside (tab 1) [ Selector.attribute (Attr.tabindex -1), attr "aria-selected" "false" ]
                            ]
            , test "another key sends nothing" <|
                \_ -> sendsNothing (page [] start |> sends (tab 0) (keyEvent "x"))
            ]
        , -- When the key given to `init` or `setActive` is not the key of an enabled tab, the
          -- strip selects the first enabled tab and shows its panel.
          test "a state whose key is no tab shows the first enabled tab and its panel" <|
            \_ ->
                page [] (Tabs.init "order-tabs" NoSuchTab)
                    |> Expect.all
                        [ inside (tab 0) [ attr "aria-selected" "true" ]
                        , inside [ Selector.id "order-tabs-panel-0" ] [ Selector.text "The overview" ]
                        , expectWellWired
                        ]
        , -- The same for a tab that is disabled (a route that points at a disabled tab).
          test "a state whose key is a disabled tab still names only panels that exist" <|
            \_ -> expectWellWired (page [] (Tabs.init "order-tabs" BillingTab))
        , test "the strip and the panel keep their place when another tab is chosen" <|
            \_ ->
                page [] (Tabs.setActive HistoryTab start)
                    |> Query.fromHtml
                    |> Expect.all
                        [ Query.has [ Selector.class "klar-tabs-layout" ]
                        , Query.children [] >> Query.count (Expect.equal 2)
                        , Query.children [] >> Query.index 1 >> Query.has [ Selector.class "klar-tabs__panel" ]
                        ]
        ]



-- PAGINATION


paginationTests : Test
paginationTests =
    let
        pages attributes model =
            Pagination.view (Pagination.id "orders-pages" :: Pagination.onPage Page :: Pagination.onPageSize PageSize :: attributes) model

        middle =
            { page = 6, pageSize = 25, total = 3000 }

        pageButton n =
            [ attr "aria-label" ("Page " ++ String.fromInt n) ]

        control name =
            [ attr "aria-label" name ]
    in
    describe "Pagination (the view)"
        [ test "is a navigation landmark with a name and the id" <|
            \_ -> rootHas [ Selector.tag "nav", attr "aria-label" "Pagination", Selector.id "orders-pages" ] (pages [] middle)
        , test "the name can be replaced" <|
            \_ -> rootHas [ attr "aria-label" "Order pages" ] (pages [ Pagination.ariaLabel "Order pages" ] middle)
        , test "the range is shown" <|
            \_ -> inside [ Selector.class "klar-pagination__summary" ] [ Selector.text "126–150 of 3,000" ] (pages [] middle)
        , test "in Norwegian" <|
            \_ ->
                pages [ Pagination.locale Locale.nb ] middle
                    |> Expect.all
                        [ inside [ Selector.class "klar-pagination__summary" ] [ Selector.text "126–150 av 3\u{00A0}000" ]
                        , rootHas [ attr "aria-label" "Sidenavigering" ]
                        ]
        , test "the current page is marked" <|
            \_ -> inside [ attr "aria-current" "page" ] [ Selector.text "6", attr "aria-label" "Page 6" ] (pages [] middle)
        , test "and only that one" <|
            \_ -> count 1 [ attr "aria-current" "page" ] (pages [] middle)
        , test "the pages around it are buttons" <|
            \_ -> inside (pageButton 7) [ Selector.tag "button", Selector.attribute (Attr.type_ "button"), Selector.text "7" ] (pages [] middle)
        , test "the gaps are hidden from screen readers" <|
            \_ -> count 2 [ Selector.class "klar-pagination__gap", attr "aria-hidden" "true" ] (pages [] middle)
        , test "the page numbers are in a list" <|
            \_ -> count 1 [ Selector.tag "ul", Selector.class "klar-pagination__pages" ] (pages [] middle)
        , test "the controls have names" <|
            \_ ->
                pages [] middle
                    |> Expect.all
                        [ inside (control "First page") []
                        , inside (control "Previous page") []
                        , inside (control "Next page") []
                        , inside (control "Last page") []
                        ]
        , test "on the first page 'first' and 'previous' look disabled but stay buttons that keep focus" <|
            \_ ->
                pages [] { page = 1, pageSize = 25, total = 3000 }
                    |> Expect.all
                        [ inside (control "Previous page") [ attr "aria-disabled" "true", Selector.disabled False ]
                        , inside (control "First page") [ attr "aria-disabled" "true", Selector.disabled False ]
                        , inside (control "Next page") [ Selector.disabled False ]
                        , \html -> sendsNothing (sends (control "Previous page") Event.click html)
                        , \html -> sendsNothing (sends (control "First page") Event.click html)
                        ]
        , test "on the last page 'next' and 'last' look disabled" <|
            \_ ->
                pages [] { page = 120, pageSize = 25, total = 3000 }
                    |> Expect.all
                        [ inside (control "Next page") [ attr "aria-disabled" "true" ]
                        , inside (control "Last page") [ attr "aria-disabled" "true" ]
                        , \html -> sendsNothing (sends (control "Last page") Event.click html)
                        ]
        , test "a page past the last is shown as the last" <|
            \_ -> inside [ attr "aria-current" "page" ] [ attr "aria-label" "Page 120" ] (pages [] { page = 999, pageSize = 25, total = 3000 })
        , test "a click on a page sends it" <|
            \_ -> Expect.equal (Ok (Page 7)) (sends (pageButton 7) Event.click (pages [] middle))
        , test "next sends the next page" <|
            \_ -> Expect.equal (Ok (Page 7)) (sends (control "Next page") Event.click (pages [] middle))
        , test "previous sends the previous page" <|
            \_ -> Expect.equal (Ok (Page 5)) (sends (control "Previous page") Event.click (pages [] middle))
        , test "first sends page 1" <|
            \_ -> Expect.equal (Ok (Page 1)) (sends (control "First page") Event.click (pages [] middle))
        , test "last sends the last page" <|
            \_ -> Expect.equal (Ok (Page 120)) (sends (control "Last page") Event.click (pages [] middle))
        , test "the current page cannot be clicked" <|
            \_ -> sendsNothing (sends (pageButton 6) Event.click (pages [] middle))
        , test "without onPage nothing is sent" <|
            \_ -> sendsNothing (sends (pageButton 7) Event.click (Pagination.view [] middle))
        , test "the number of rows per page: a select with a label that is for it" <|
            \_ ->
                pages [] middle
                    |> Expect.all
                        [ inside [ Selector.tag "label", Selector.containing [ Selector.text "Rows per page" ] ] [ Selector.attribute (Attr.for "orders-pages-size") ]
                        , inside [ Selector.tag "select" ] [ Selector.id "orders-pages-size" ]
                        , expectWellWired
                        ]
        , test "the choices are 10, 25, 50 and 100" <|
            \_ -> count 4 [ Selector.tag "option" ] (pages [] middle)
        , test "the size in use is selected" <|
            \_ -> inside [ Selector.tag "option", Selector.selected True ] [ Selector.text "25" ] (pages [] middle)
        , test "the size in use is always one of the choices" <|
            \_ -> inside [ Selector.tag "option", Selector.selected True ] [ Selector.text "37" ] (pages [] { page = 1, pageSize = 37, total = 3000 })
        , test "choosing a size sends it" <|
            \_ ->
                Expect.equal (Ok (PageSize 50))
                    (sends [ Selector.tag "select" ] (Event.custom "change" (Encode.object [ ( "target", Encode.object [ ( "value", Encode.string "50" ) ] ) ])) (pages [] middle))
        , test "there is no choice of size without onPageSize" <|
            \_ -> none [ Selector.tag "select" ] (Pagination.view [ Pagination.onPage Page ] middle)
        , test "jumpToPage adds a number input with a label" <|
            \_ ->
                pages [ Pagination.jumpToPage ] middle
                    |> Expect.all
                        [ inside [ Selector.id "orders-pages-jump" ] [ Selector.attribute (Attr.type_ "number"), Selector.attribute (Attr.min "1"), Selector.attribute (Attr.max "120"), Selector.attribute (Attr.value "6") ]
                        , inside [ Selector.class "klar-pagination__jump-label" ] [ Selector.attribute (Attr.for "orders-pages-jump"), Selector.text "Go to page" ]
                        , expectWellWired
                        ]
        , test "but not when there is only one page" <|
            \_ -> none [ Selector.id "orders-pages-jump" ] (pages [ Pagination.jumpToPage ] { page = 1, pageSize = 25, total = 10 })
        , test "compact: the range, previous and next" <|
            \_ ->
                pages [ Pagination.compact ] middle
                    |> Expect.all
                        [ inside [ Selector.class "klar-pagination__summary" ] [ Selector.text "126–150 of 3,000" ]
                        , inside (control "Next page") []
                        , inside (control "Previous page") []
                        ]
        , test "compact: and nothing else" <|
            \_ ->
                pages [ Pagination.compact ] middle
                    |> Expect.all
                        [ none [ Selector.class "klar-pagination__pages" ]
                        , none [ Selector.tag "select" ]
                        , none (control "Last page")
                        ]
        , test "disabled marks every control, and none of them loses the keyboard focus" <|
            \_ ->
                pages [ Pagination.disabled True, Pagination.jumpToPage ] middle
                    |> Expect.all
                        [ inside (control "Next page") [ attr "aria-disabled" "true" ]
                        , inside (pageButton 7) [ attr "aria-disabled" "true" ]
                        , inside [ Selector.tag "select" ] [ attr "aria-disabled" "true" ]
                        , inside [ Selector.id "orders-pages-jump" ] [ attr "aria-disabled" "true", Selector.attribute (Attr.readonly True) ]
                        , none [ Selector.tag "button", Selector.disabled True ]
                        , \html -> html |> Query.fromHtml |> Query.find [ Selector.id "orders-pages-jump" ] |> Query.hasNot [ Selector.disabled True ]
                        , rootHas [ Selector.class "klar-pagination--disabled" ]
                        ]
        , test "while disabled the buttons send nothing" <|
            \_ ->
                Expect.all
                    [ \html -> sendsNothing (html |> sends (control "Next page") Event.click)
                    , \html -> sendsNothing (html |> sends (pageButton 7) Event.click)
                    ]
                    (pages [ Pagination.disabled True ] middle)
        , test "while disabled the size select offers only the size it shows" <|
            \_ ->
                pages [ Pagination.disabled True ] middle
                    |> inside [ Selector.tag "option", Selector.attribute (Attr.value "50") ] [ Selector.disabled True ]
        , test "the page buttons have ids made of the id, for Klar.focus" <|
            \_ -> inside (pageButton 7) [ Selector.id "orders-pages-page-7" ] (pages [] middle)
        , test "the range is a polite live region" <|
            \_ -> inside [ Selector.class "klar-pagination__summary" ] [ attr "aria-live" "polite", attr "aria-atomic" "true" ] (pages [] middle)
        , test "summary replaces the range" <|
            \_ -> inside [ Selector.class "klar-pagination__summary" ] [ Selector.text "Loading ..." ] (pages [ Pagination.summary [ Html.text "Loading ..." ] ] middle)
        , test "an empty summary shows nothing" <|
            \_ -> none [ Selector.class "klar-pagination__summary" ] (pages [ Pagination.summary [] ] middle)
        , test "no rows: '0 of 0' and one page" <|
            \_ ->
                pages [] { page = 1, pageSize = 25, total = 0 }
                    |> Expect.all
                        [ inside [ Selector.class "klar-pagination__summary" ] [ Selector.text "0 of 0" ]
                        , inside [ attr "aria-current" "page" ] [ attr "aria-label" "Page 1" ]
                        ]
        , test "siblings widens the row" <|
            \_ -> inside (pageButton 8) [ Selector.text "8" ] (pages [ Pagination.siblings 2 ] middle)
        , test "the ids of the parts are made from the id of the navigation, and exist" <|
            \_ -> expectWellWired (pages [ Pagination.jumpToPage ] middle)
        ]



-- THE TABLE


tableTests : Test
tableTests =
    let
        start =
            Table.init "orders"

        table attributes =
            Orders.render attributes start

        withRetry =
            Table.onRetry Orders.Retried

        failure kind =
            Failed (Remote.problem kind)

        inTable : List Selector -> List Selector -> Html Orders.Msg -> Expectation
        inTable find selectors html =
            html |> Query.fromHtml |> Query.find find |> Query.has selectors

        noneInTable : List Selector -> Html Orders.Msg -> Expectation
        noneInTable find html =
            html |> Query.fromHtml |> Query.findAll find |> Query.count (Expect.equal 0)

        countInTable : Int -> List Selector -> Html Orders.Msg -> Expectation
        countInTable n find html =
            html |> Query.fromHtml |> Query.findAll find |> Query.count (Expect.equal n)

        header title =
            [ Selector.tag "th", Selector.containing [ Selector.text title ] ]

        button text =
            [ Selector.tag "button", Selector.containing [ Selector.text text ] ]
    in
    describe "Table (the states and what a screen reader hears)"
        [ describe "with rows"
            [ test "is a table in a labelled region" <|
                \_ ->
                    table []
                        |> Expect.all
                            [ inTable [ Selector.tag "table" ] [ attr "aria-label" "Orders" ]
                            , inTable [ Selector.id "orders-scroll" ] [ attr "role" "region", attr "aria-label" "Orders" ]
                            ]
            , test "every header cell is a column header" <|
                \_ -> countInTable 8 [ Selector.tag "th", Selector.attribute (Attr.scope "col") ] (table [])
            , test "a header that can be sorted says it is not sorted yet" <|
                \_ -> inTable (header "Customer") [ attr "aria-sort" "none" ] (table [])
            , test "the sort button names the column and says what a click does" <|
                \_ -> inTable (Orders.sortButton "Customer") [ Selector.attribute (Attr.title "Click to sort"), Selector.attribute (Attr.type_ "button") ] (table [])
            , test "a header that is sorted says in which direction" <|
                \_ -> inTable (header "Customer") [ attr "aria-sort" "descending" ] (Orders.render [] (Table.setSort [ ( Table.columnId "customer", Table.Descending ) ] start))
            , test "a header cell of a column that cannot be sorted has no aria-sort" <|
                \_ ->
                    Orders.render [ Table.columns [ Table.text (Table.columnId "number") "Order" .number [ Table.unsortable ] ] ] start
                        |> noneInTable [ Selector.tag "th", Selector.attribute (Attr.attribute "aria-sort" "none") ]
            , test "one row for each item" <|
                \_ -> countInTable 8 [ Selector.class "klar-table__row" ] (table [])
            , test "a cell for each column" <|
                \_ -> inTable [ Selector.id "orders-row-0" ] [ Selector.text "ORD-2001", Selector.text "Acme Supplies", Selector.text "120.50" ] (table [])
            , test "and nothing else in the row" <|
                \_ -> table [] |> Query.fromHtml |> Query.find [ Selector.id "orders-row-0" ] |> Query.findAll [ Selector.tag "td" ] |> Query.count (Expect.equal 8)
            , test "the table says how many rows and columns it has" <|
                \_ -> inTable [ Selector.tag "table" ] [ attr "aria-rowcount" "9", attr "aria-colcount" "8" ] (table [])
            , test "a yes and no cell has the word for screen readers" <|
                \_ -> inTable [ Selector.id "orders-row-1" ] [ Selector.containing [ Selector.class "klar-sr-only", Selector.text "No" ] ] (table [])
            , test "a live region announces the range" <|
                \_ -> inTable [ attr "role" "status" ] [ attr "aria-live" "polite", Selector.text "Showing 1–8 of 8 rows." ] (table [])
            , test "the pagination is in the footer" <|
                \_ -> inTable [ Selector.tag "nav" ] [ attr "aria-label" "Pages of Orders", Selector.id "orders-pagination" ] (table [])
            , test "everything that is named exists, and no id is used twice" <|
                \_ -> expectWellWired (table [])
            , test "also with selection, search, sorting, filters, density, columns, export, details and row actions" <|
                \_ ->
                    expectWellWired
                        (Orders.render
                            [ Table.selectable
                            , Table.searchable
                            , Table.densityToggle
                            , Table.columnChooser
                            , Table.exportCsv "orders.csv"
                            , Table.expandedRow (\order -> Html.text order.number)
                            , Table.rowActions (\order -> [ Menu.item "Open" (Orders.Opened order) ])
                            , Table.onRefresh Orders.Refreshed
                            ]
                            (start |> Table.select Ids.strings [ "ORD-2001" ] |> Table.expand Ids.strings "ORD-2002")
                        )
            , test "with a filter popup open everything is still wired" <|
                \_ ->
                    case Orders.press [] [ Selector.id "orders-trigger-filter-city" ] Event.click start of
                        Ok opened ->
                            expectWellWired (Orders.render [] opened)

                        Err problem ->
                            Expect.fail problem
            , test "with the export menu open everything is still wired" <|
                \_ ->
                    case Orders.press [ Table.exportCsv "orders.csv" ] [ Selector.id "orders-trigger-export" ] Event.click start of
                        Ok opened ->
                            expectWellWired (Orders.render [ Table.exportCsv "orders.csv" ] opened)

                        Err problem ->
                            Expect.fail problem
            , test "with the column chooser open everything is still wired" <|
                \_ ->
                    case Orders.press [ Table.columnChooser ] [ Selector.id "orders-trigger-columns" ] Event.click start of
                        Ok opened ->
                            expectWellWired (Orders.render [ Table.columnChooser ] opened)

                        Err problem ->
                            Expect.fail problem
            ]
        , describe "without rows"
            [ test "the empty state says there is no data" <|
                \_ -> inTable [ Selector.class "klar-state" ] [ Selector.text "No data", Selector.text "There are no rows to show." ] (table [ Table.remote (Loaded []) ])
            , test "it takes the whole width of the table" <|
                \_ -> inTable [ Selector.class "klar-table__state-cell" ] [ Selector.attribute (Attr.colspan 8) ] (table [ Table.remote (Loaded []) ])
            , test "the application can change it" <|
                \_ -> inTable [ Selector.class "klar-state" ] [ Selector.text "No orders yet" ] (table [ Table.remote (Loaded []), Table.emptyState [ EmptyState.title "No orders yet" ] ])
            , test "there is no pagination and no totals" <|
                \_ -> table [ Table.remote (Loaded []) ] |> Expect.all [ noneInTable [ Selector.tag "nav" ], noneInTable [ Selector.tag "tfoot" ] ]
            , test "the table says it has one row, the header" <|
                \_ -> inTable [ Selector.tag "table" ] [ attr "aria-rowcount" "1" ] (table [ Table.remote (Loaded []) ])
            , test "a search without results says 'No matches'" <|
                \_ -> inTable [ Selector.class "klar-state" ] [ Selector.text "No matches" ] (Orders.render [] (Table.setSearch "nothing like this" start))
            , test "and offers a way out" <|
                \_ -> inTable (button "Clear search and filters") [] (Orders.render [] (Table.setSearch "nothing like this" start))
            , test "the pagination stays when a search has no results" <|
                \_ -> inTable [ Selector.tag "nav" ] [ Selector.text "0 of 0" ] (Orders.render [] (Table.setSearch "nothing like this" start))
            , test "everything that is named exists" <|
                \_ -> expectWellWired (table [ Table.remote (Loaded []) ])
            ]
        , describe "while loading"
            [ test "shows skeleton rows, as many as a page" <|
                \_ -> countInTable 25 [ Selector.class "klar-table__row--skeleton" ] (table [ Table.remote Loading ])
            , test "as many as the page size says" <|
                \_ -> countInTable 7 [ Selector.class "klar-table__row--skeleton" ] (Orders.render [ Table.remote Loading ] (Table.setPageSize 7 start))
            , test "at most a hundred" <|
                \_ -> countInTable 100 [ Selector.class "klar-table__row--skeleton" ] (Orders.render [ Table.remote Loading ] (Table.setPageSize 500 start))
            , test "the skeleton is hidden from screen readers" <|
                \_ ->
                    table [ Table.remote Loading ]
                        |> Query.fromHtml
                        |> Query.findAll [ Selector.class "klar-table__row--skeleton" ]
                        |> Query.each (Query.has [ attr "aria-hidden" "true" ])
            , test "the table is busy and does not know how many rows it has" <|
                \_ -> inTable [ Selector.tag "table" ] [ attr "aria-busy" "true", attr "aria-rowcount" "-1" ] (table [ Table.remote Loading ])
            , test "a live region says it is loading" <|
                \_ -> inTable [ attr "role" "status" ] [ Selector.text "Loading ..." ] (table [ Table.remote Loading ])
            , test "NotAsked looks the same" <|
                \_ -> inTable [ Selector.tag "table" ] [ attr "aria-busy" "true" ] (table [ Table.remote NotAsked ])
            , test "so does a table that was never given rows" <|
                \_ -> Table.view Orders.TableMsg [ Table.columns Orders.columns ] start |> inTable [ Selector.tag "table" ] [ attr "aria-busy" "true" ]
            , test "there are no rows of data" <|
                \_ -> noneInTable [ Selector.id "orders-row-0" ] (table [ Table.remote Loading ])
            , test "a table that is not loading is not busy" <|
                \_ -> noneInTable [ attr "aria-busy" "true" ] (table [])
            , test "a table that is refreshing keeps its rows and is busy" <|
                \_ ->
                    table [ Table.remote (Remote.refresh (Loaded Orders.curated)) ]
                        |> Expect.all
                            [ inTable [ Selector.tag "table" ] [ attr "aria-busy" "true", attr "aria-rowcount" "9" ]
                            , inTable [ Selector.id "orders-row-0" ] [ Selector.text "ORD-2001" ]
                            ]
            , test "and shows a progress line, and says so" <|
                \_ ->
                    table [ Table.remote (Remote.refresh (Loaded Orders.curated)) ]
                        |> Expect.all
                            [ inTable [ Selector.class "klar-table__progress" ] [ attr "aria-hidden" "true" ]
                            , inTable [ attr "role" "status" ] [ Selector.text "Refreshing ..." ]
                            ]
            , test "refreshing is ignored while the first rows are loading" <|
                \_ -> noneInTable [ Selector.class "klar-table__progress" ] (table [ Table.remote (Remote.refresh Loading) ])
            , test "the refresh button is busy while loading" <|
                \_ -> inTable [ attr "aria-label" "Refresh" ] [ attr "aria-busy" "true" ] (table [ Table.remote Loading, Table.onRefresh Orders.Refreshed ])
            , test "everything that is named exists" <|
                \_ -> expectWellWired (table [ Table.remote Loading ])
            ]
        , describe "when the rows could not be fetched"
            [ test "shows the problem as an alert" <|
                \_ -> inTable [ Selector.class "klar-state--error" ] [ attr "role" "alert" ] (table [ Table.remote (failure Remote.network), withRetry ])
            , test "with its title and its detail" <|
                \_ ->
                    let
                        problem =
                            Remote.problem Remote.network
                    in
                    table [ Table.remote (failure Remote.network) ]
                        |> inTable [ Selector.class "klar-state--error" ] [ Selector.text (Remote.title Locale.en problem), Selector.text (Maybe.withDefault "?" (Remote.detail Locale.en problem)) ]
            , test "offers to try again, when the application listens" <|
                \_ -> inTable (button "Try again") [] (table [ Table.remote (failure Remote.network), withRetry ])
            , test "the retry button sends the message of the application" <|
                \_ ->
                    table [ Table.remote (failure Remote.timeout), withRetry ]
                        |> Query.fromHtml
                        |> Query.find (button "Try again")
                        |> Event.simulate Event.click
                        |> Event.toResult
                        |> Expect.equal (Ok Orders.Retried)
            , test "there is no button without a message to send" <|
                \_ -> noneInTable (button "Try again") (table [ Table.remote (failure Remote.network) ])
            , test "or for a problem that trying again would not help" <|
                \_ -> noneInTable (button "Try again") (table [ Table.remote (failure Remote.notFound), withRetry ])
            , test "nor for a missing permission" <|
                \_ -> noneInTable (button "Try again") (table [ Table.remote (failure Remote.forbidden), withRetry ])
            , test "the button is in the language of the table" <|
                \_ -> inTable (button "Prøv igjen") [] (table [ Table.remote (failure Remote.network), withRetry, Table.locale Locale.nb ])
            , test "the table does not know its row count" <|
                \_ -> inTable [ Selector.tag "table" ] [ attr "aria-rowcount" "-1" ] (table [ Table.remote (failure Remote.network) ])
            , test "there are no rows and no totals" <|
                \_ -> table [ Table.remote (failure Remote.network) ] |> Expect.all [ noneInTable [ Selector.id "orders-row-0" ], noneInTable [ Selector.tag "tfoot" ] ]
            , test "in client mode there is no pagination" <|
                \_ -> noneInTable [ Selector.tag "nav" ] (table [ Table.remote (failure Remote.network) ])
            , test "in server mode the pagination stays, so that another page can be tried" <|
                \_ -> inTable [ Selector.tag "nav" ] [ attr "aria-label" "Pages of Orders" ] (table [ Table.server { total = 120 }, Table.remote (failure Remote.network) ])
            , test "everything that is named exists" <|
                \_ -> expectWellWired (table [ Table.remote (failure Remote.network), withRetry ])
            ]
        ]
