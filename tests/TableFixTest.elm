module TableFixTest exposing (suite)

{-| Regression tests for fixes in `Klar.Table`.

  - A row that is `rowDisabled` is inert. Its checkbox, expand button and actions
    button are disabled and send nothing, and the keys on the row (Enter, Space,
    ArrowRight, ArrowLeft, the menu key, Shift+F10) and a click do nothing. The
    arrow keys still move focus onto it.
  - The two reset buttons do what their labels say. "Reset filters" in the filter
    summary clears the column filters and keeps the search text. "Clear search
    and filters" in the "No matches" state clears both. Both send
    `onResetFilters`.
  - What the documentation of `Filter`, `filterSelect` and `page` says.

Every test draws the table, finds a control the way a user would, simulates the
event on it and gives the message that the control sends to `Table.update`. A
control that is not there at all is a failure, so that a mistake in a selector
does not look like a control that does nothing.

-}

import Expect exposing (Expectation)
import Html exposing (Html)
import Html.Attributes as Attr
import Json.Encode as Encode
import Klar.Locale as Locale
import Klar.Menu as Menu
import Klar.Remote exposing (Remote(..))
import Klar.Table as Table exposing (Filter(..))
import Test exposing (Test, describe, test)
import Test.Html.Event as Event
import Test.Html.Query as Query
import Test.Html.Selector as Selector exposing (Selector)


suite : Test
suite =
    describe "Klar.Table fixes"
        [ columnIdTests
        , disabledRowTests
        , resetButtonTests
        , filterDocumentationTests
        ]



-- THE TABLE UNDER TEST


type Msg
    = TableMsg Table.Msg
    | FiltersReset
    | Clicked String
    | Picked String


type alias Order =
    { number : String
    , customer : String
    , city : String
    , items : Int
    , weight : Maybe Float
    , locked : Bool
    }


{-| The second order is the locked one; the table is told to disable it.
-}
orders : List Order
orders =
    [ { number = "A-1", customer = "Acme Supplies", city = "Oslo", items = 3, weight = Just 1.5, locked = False }
    , { number = "A-2", customer = "Globex", city = "Bergen", items = 12, weight = Nothing, locked = True }
    , { number = "A-3", customer = "Initech", city = "Oslo", items = 7, weight = Just 20, locked = False }
    , { number = "A-4", customer = "Éclair Foods", city = "Trondheim", items = 1, weight = Nothing, locked = False }
    ]


columns : List (Table.Column Order Msg)
columns =
    [ Table.text (Table.columnId "customer") "Customer" .customer [ Table.filterText ]
    , Table.text (Table.columnId "city") "City" .city [ Table.filterSelect ]
    , Table.int (Table.columnId "items") "Items" .items [ Table.filterRange ]
    , Table.text (Table.columnId "weight") "Weight" (\order -> order.weight |> Maybe.map String.fromFloat |> Maybe.withDefault "") [ Table.sortMaybeNumber .weight ]
    ]


start : Table.State
start =
    Table.init "orders"


render : List (Table.Attribute Order Msg) -> Table.State -> Html Msg
render attributes state =
    Table.view TableMsg
        ([ Table.columns columns
         , Table.rows (Success orders)
         , Table.rowId .number
         , Table.label "Orders"
         ]
            ++ attributes
        )
        state


page : List (Table.Attribute Order Msg) -> Table.State -> Query.Single Msg
page attributes state =
    Query.fromHtml (render attributes state)


applyMsg : Msg -> Table.State -> Table.State
applyMsg msg state =
    case msg of
        TableMsg tableMsg ->
            Tuple.first (Table.update tableMsg state)

        _ ->
            state



-- WHAT THE USER POINTS AT


{-| The first row, which is enabled, and the second, which is locked.
-}
openIndex : Int
openIndex =
    0


lockedIndex : Int
lockedIndex =
    1


customerOf : Int -> String
customerOf index =
    if index == lockedIndex then
        "Globex"

    else
        "Acme Supplies"


rowDomId : Int -> String
rowDomId index =
    "orders-row-" ++ String.fromInt index


ariaLabelled : String -> List Selector
ariaLabelled label =
    [ Selector.attribute (Attr.attribute "aria-label" label) ]


row : List (Table.Attribute Order Msg) -> Table.State -> Int -> Query.Single Msg
row attributes state index =
    page attributes state
        |> Query.find [ Selector.id (rowDomId index) ]


{-| A control in the row, found by what it says to a screen reader.
-}
control : List (Table.Attribute Order Msg) -> Table.State -> Int -> List Selector -> Query.Single Msg
control attributes state index selectors =
    row attributes state index
        |> Query.find selectors


checkboxLabel : Int -> List Selector
checkboxLabel index =
    ariaLabelled ("Select " ++ customerOf index)


expandLabel : Int -> List Selector
expandLabel index =
    ariaLabelled ("Show details for " ++ customerOf index)


menuLabel : Int -> List Selector
menuLabel index =
    ariaLabelled ("Actions for " ++ customerOf index)


menuPopup : List Selector
menuPopup =
    [ Selector.attribute (Attr.attribute "role" "menu") ]



-- EVENTS


{-| A key pressed while the row has the focus.
-}
keyEvent : { shift : Bool } -> Int -> String -> ( String, Encode.Value )
keyEvent modifiers index key =
    Event.custom "keydown"
        (Encode.object
            [ ( "key", Encode.string key )
            , ( "ctrlKey", Encode.bool False )
            , ( "metaKey", Encode.bool False )
            , ( "altKey", Encode.bool False )
            , ( "shiftKey", Encode.bool modifiers.shift )
            , ( "target", Encode.object [ ( "id", Encode.string (rowDomId index) ) ] )
            ]
        )


plainKey : Int -> String -> ( String, Encode.Value )
plainKey =
    keyEvent { shift = False }


{-| The event that the menu key sends to the page in some browsers: `button` is 0
for the keyboard and 2 for a right click.
-}
contextMenuEvent : Int -> ( String, Encode.Value )
contextMenuEvent button =
    Event.custom "contextmenu" (Encode.object [ ( "button", Encode.int button ) ])


{-| A click on a cell of the row (not on a control).
-}
clickOnCell : ( String, Encode.Value )
clickOnCell =
    Event.custom "click" (Encode.object [ ( "target", Encode.object [ ( "tagName", Encode.string "TD" ) ] ) ])



-- EXPECTATIONS


expectOk : (a -> Expectation) -> Result String a -> Expectation
expectOk toExpectation result =
    case result of
        Ok value ->
            toExpectation value

        Err problem ->
            Expect.fail problem


{-| The control is there, and the event sends no message.
-}
expectInert : Query.Single Msg -> ( String, Encode.Value ) -> Expectation
expectInert target event =
    Expect.all
        [ \_ -> Query.has [] target
        , \_ ->
            case target |> Event.simulate event |> Event.toResult of
                Ok _ ->
                    Expect.fail "The event sent a message, but it should do nothing."

                Err _ ->
                    Expect.pass
        ]
        ()


{-| The event sends a message, and the check says what should come of it.
-}
expectSends : Query.Single Msg -> ( String, Encode.Value ) -> (Msg -> Expectation) -> Expectation
expectSends target event check =
    target
        |> Event.simulate event
        |> Event.toResult
        |> expectOk check


{-| What a user does to the locked row and to the first (enabled) row. The locked
row ignores it. On the enabled row the message does what the check says (it gets
the state from before the message).
-}
lockedRowIgnores :
    String
    -> Table.State
    -> (Int -> Query.Single Msg)
    -> (Int -> ( String, Encode.Value ))
    -> (Msg -> Table.State -> Expectation)
    -> Test
lockedRowIgnores name state target event works =
    describe name
        [ test "does nothing on the disabled row" <|
            \_ -> expectInert (target lockedIndex) (event lockedIndex)
        , test "works on an enabled row" <|
            \_ -> expectSends (target openIndex) (event openIndex) (\msg -> works msg state)
        ]


{-| An event on the row itself.
-}
onRow :
    String
    -> List (Table.Attribute Order Msg)
    -> Table.State
    -> (Int -> ( String, Encode.Value ))
    -> (Msg -> Table.State -> Expectation)
    -> Test
onRow name attributes state event works =
    lockedRowIgnores name state (row attributes state) event works


{-| An event on a control in the row. The selectors say which control, by the
index of the row.
-}
onControl :
    String
    -> List (Table.Attribute Order Msg)
    -> Table.State
    -> (Int -> List Selector)
    -> ( String, Encode.Value )
    -> (Msg -> Table.State -> Expectation)
    -> Test
onControl name attributes state selectors event works =
    lockedRowIgnores name state (\index -> control attributes state index (selectors index)) (\_ -> event) works


isSelected : String -> Msg -> Table.State -> Expectation
isSelected id msg state =
    Expect.equal True (Table.isSelected id (applyMsg msg state))


isExpanded : String -> Msg -> Table.State -> Expectation
isExpanded id msg state =
    Expect.equal True (Table.isExpanded id (applyMsg msg state))


{-| The row menu is open after the message.
-}
opensMenu : List (Table.Attribute Order Msg) -> Msg -> Table.State -> Expectation
opensMenu attributes msg state =
    page attributes (applyMsg msg state)
        |> Query.has menuPopup


sends : Msg -> Msg -> Table.State -> Expectation
sends expected msg _ =
    Expect.equal expected msg


movesFocus : Msg -> Table.State -> Expectation
movesFocus _ _ =
    Expect.pass



-- A DISABLED ROW IS INERT


withMenu : List (Table.Attribute Order Msg)
withMenu =
    [ Table.rowDisabled .locked
    , Table.rowActions (\order -> [ Menu.item "Open" (Picked order.number) ])
    ]


withCheckboxes : List (Table.Attribute Order Msg)
withCheckboxes =
    [ Table.rowDisabled .locked
    , Table.selectable
    ]


withDetails : List (Table.Attribute Order Msg)
withDetails =
    [ Table.rowDisabled .locked
    , Table.expandedRow (\order -> Html.text ("Details of " ++ order.number))
    ]


withClick : List (Table.Attribute Order Msg)
withClick =
    [ Table.rowDisabled .locked
    , Table.onRowClick (\order -> Clicked order.number)
    ]


{-| Everything at once: each control is on the page next to the others.
-}
withEverything : List (Table.Attribute Order Msg)
withEverything =
    [ Table.rowDisabled .locked
    , Table.selectable
    , Table.expandedRow (\order -> Html.text ("Details of " ++ order.number))
    , Table.rowActions (\order -> [ Menu.item "Open" (Picked order.number) ])
    , Table.onRowClick (\order -> Clicked order.number)
    ]


disabledRowTests : Test
disabledRowTests =
    describe "a rowDisabled row is inert"
        [ markupTests
        , keyTests
        , clickTests
        , menuTests
        , selectAllTests
        ]


markupTests : Test
markupTests =
    let
        expectOn index selectors expectation =
            \_ -> expectation (control withEverything start index selectors)
    in
    describe "its controls are disabled, those of other rows are not"
        [ test "the row is marked aria-disabled" <|
            \_ ->
                row withEverything start lockedIndex
                    |> Query.has [ Selector.attribute (Attr.attribute "aria-disabled" "true") ]
        , test "an enabled row is not" <|
            \_ ->
                row withEverything start openIndex
                    |> Query.hasNot [ Selector.attribute (Attr.attribute "aria-disabled" "true") ]
        , test "its checkbox is disabled" <|
            expectOn lockedIndex (checkboxLabel lockedIndex) (Query.has [ Selector.disabled True ])
        , test "the checkbox of an enabled row is not" <|
            expectOn openIndex (checkboxLabel openIndex) (Query.has [ Selector.disabled False ])
        , test "its expand button is disabled" <|
            expectOn lockedIndex (expandLabel lockedIndex) (Query.has [ Selector.disabled True ])
        , test "the expand button of an enabled row is not" <|
            expectOn openIndex (expandLabel openIndex) (Query.has [ Selector.disabled False ])
        , test "its actions button is disabled" <|
            expectOn lockedIndex (menuLabel lockedIndex) (Query.has [ Selector.disabled True ])
        , test "the actions button of an enabled row is not" <|
            expectOn openIndex (menuLabel openIndex) (Query.has [ Selector.disabled False ])
        ]


keyTests : Test
keyTests =
    let
        shiftF10 index =
            keyEvent { shift = True } index "F10"

        bothOpen =
            start
                |> Table.setExpanded "A-1" True
                |> Table.setExpanded "A-2" True

        moves attributes index key =
            test (key ++ " on row " ++ String.fromInt index) <|
                \_ -> expectSends (row attributes start index) (plainKey index key) (\msg -> movesFocus msg start)
    in
    describe "keys on the row"
        [ onRow "Space" withCheckboxes start (\index -> plainKey index " ") (isSelected "A-1")
        , onRow "Enter, when the row has a menu and nothing else" withMenu start (\index -> plainKey index "Enter") (opensMenu withMenu)
        , onRow "Enter, when the row can expand" withDetails start (\index -> plainKey index "Enter") (isExpanded "A-1")
        , onRow "Enter, when the row has a click message" withClick start (\index -> plainKey index "Enter") (sends (Clicked "A-1"))
        , onRow "the menu key" withMenu start (\index -> plainKey index "ContextMenu") (opensMenu withMenu)
        , onRow "Shift+F10" withMenu start shiftF10 (opensMenu withMenu)
        , onRow "a context menu event from the keyboard" withMenu start (\_ -> contextMenuEvent 0) (opensMenu withMenu)
        , onRow "ArrowRight" withDetails start (\index -> plainKey index "ArrowRight") (isExpanded "A-1")
        , lockedRowIgnores "ArrowLeft, when the row is open"
            bothOpen
            (row withDetails bothOpen)
            (\index -> plainKey index "ArrowLeft")
            (\msg state -> Expect.equal False (Table.isExpanded "A-1" (applyMsg msg state)))
        , describe "the other arrow keys still move focus, onto the disabled row and off it"
            [ moves withEverything openIndex "ArrowDown"
            , moves withEverything 2 "ArrowUp"
            , moves withEverything lockedIndex "ArrowDown"
            , moves withEverything lockedIndex "ArrowUp"
            , moves withEverything lockedIndex "Home"
            , moves withEverything lockedIndex "End"
            ]
        ]


clickTests : Test
clickTests =
    describe "clicks"
        [ onRow "a click on the row, with a click message" withClick start (\_ -> clickOnCell) (sends (Clicked "A-1"))
        , onRow "a click on the row, which toggles the details" withDetails start (\_ -> clickOnCell) (isExpanded "A-1")
        , onControl "a click on the expand button" withDetails start expandLabel Event.click (isExpanded "A-1")
        , onControl "ticking the checkbox" withCheckboxes start checkboxLabel (Event.check True) (isSelected "A-1")
        , onControl "a click on the actions button" withMenu start menuLabel Event.click (opensMenu withMenu)
        ]


{-| The menu of a row that was open when the row became disabled.
-}
menuTests : Test
menuTests =
    let
        whileEnabled =
            [ Table.rowActions (\order -> [ Menu.item "Open" (Picked order.number) ]) ]

        afterLocking =
            [ Table.rowDisabled .locked
            , Table.rowActions (\order -> [ Menu.item "Open" (Picked order.number) ])
            ]

        withOpenMenu =
            row whileEnabled start lockedIndex
                |> Event.simulate (contextMenuEvent 0)
                |> Event.toResult
                |> Result.map (\msg -> applyMsg msg start)
    in
    describe "the menu of a row that becomes disabled while it is open"
        [ test "is open as long as the row is enabled" <|
            \_ ->
                withOpenMenu
                    |> expectOk (\state -> Query.has menuPopup (page whileEnabled state))
        , test "is closed once the row is disabled" <|
            \_ ->
                withOpenMenu
                    |> expectOk (\state -> Query.hasNot menuPopup (page afterLocking state))
        ]


selectAllTests : Test
selectAllTests =
    describe "'select all on this page'"
        [ test "leaves the disabled row out" <|
            \_ ->
                page withCheckboxes start
                    |> Query.find [ Selector.id "orders-select-page" ]
                    |> Event.simulate (Event.check True)
                    |> Event.toResult
                    |> expectOk (\msg -> Expect.equal [ "A-1", "A-3", "A-4" ] (Table.selectedIds (applyMsg msg start)))
        ]



-- THE RESET BUTTONS


{-| A filter on the city and a search, and two rows match both.
-}
filteredAndSearched : Table.State
filteredAndSearched =
    start
        |> Table.setFilter (Table.columnId "city") (Just (OneOf [ "Oslo" ]))
        |> Table.setSearch "e"


{-| The same filter, and a search that nothing matches.
-}
nothingMatches : Table.State
nothingMatches =
    start
        |> Table.setFilter (Table.columnId "city") (Just (OneOf [ "Oslo" ]))
        |> Table.setSearch "zzz"


withReset : List (Table.Attribute Order Msg)
withReset =
    [ Table.onResetFilters FiltersReset ]


{-| The small cross next to "1 filter active".
-}
summaryCross : List Selector
summaryCross =
    [ Selector.tag "button", Selector.attribute (Attr.attribute "aria-label" "Reset filters") ]


{-| A button with this text.
-}
buttonSaying : String -> List Selector
buttonSaying label =
    [ Selector.tag "button", Selector.containing [ Selector.text label ] ]


{-| The wrapper that sends the application's `onResetFilters` when the click
bubbles up to it.
-}
wrapperOf : List Selector -> List Selector
wrapperOf inner =
    [ Selector.class "klar-table__reset", Selector.containing inner ]


{-| Click the button, and see what the table has after the message.
-}
afterClicking : List (Table.Attribute Order Msg) -> Table.State -> List Selector -> Result String Table.State
afterClicking attributes state selectors =
    page attributes state
        |> Query.find selectors
        |> Event.simulate Event.click
        |> Event.toResult
        |> Result.map (\msg -> applyMsg msg state)


expectCleared : { search : String, filters : List ( String, Filter ) } -> Result String Table.State -> Expectation
expectCleared expected =
    expectOk (\state -> Expect.equal expected { search = Table.search state, filters = List.map (Tuple.mapFirst Table.columnName) (Table.filters state) })


expectWrapperSends : List (Table.Attribute Order Msg) -> Table.State -> List Selector -> Expectation
expectWrapperSends attributes state selectors =
    expectSends (page attributes state |> Query.find (wrapperOf selectors)) Event.click (Expect.equal FiltersReset)


{-| The table after the user opened the list of active filters.
-}
openedSummary : Result String Table.State
openedSummary =
    page withReset filteredAndSearched
        |> Query.find [ Selector.id "orders-trigger-filters" ]
        |> Event.simulate Event.click
        |> Event.toResult
        |> Result.map (\msg -> applyMsg msg filteredAndSearched)


resetButtonTests : Test
resetButtonTests =
    describe "the reset buttons do what their labels say"
        [ describe "'Reset filters' in the filter summary"
            [ test "is there, next to the number of active filters" <|
                \_ ->
                    page withReset filteredAndSearched
                        |> Expect.all
                            [ Query.has [ Selector.text "1 filter active" ]
                            , Query.find summaryCross >> Query.has []
                            ]
            , test "clears the column filters and keeps the search text" <|
                \_ ->
                    afterClicking withReset filteredAndSearched summaryCross
                        |> expectCleared { search = "e", filters = [] }
            , test "keeps the search text in the search box" <|
                \_ ->
                    afterClicking (Table.searchable :: withReset) filteredAndSearched summaryCross
                        |> expectOk
                            (\state ->
                                page [ Table.searchable ] state
                                    |> Query.find [ Selector.id "orders-search" ]
                                    |> Query.has [ Selector.attribute (Attr.value "e") ]
                            )
            , test "also sends onResetFilters" <|
                \_ -> expectWrapperSends withReset filteredAndSearched summaryCross
            , describe "the button in the list of active filters"
                [ test "clears the column filters and keeps the search text" <|
                    \_ ->
                        openedSummary
                            |> expectOk
                                (\state ->
                                    afterClicking withReset state (buttonSaying "Reset filters")
                                        |> expectCleared { search = "e", filters = [] }
                                )
                , test "also sends onResetFilters" <|
                    \_ ->
                        openedSummary
                            |> expectOk (\state -> expectWrapperSends withReset state (buttonSaying "Reset filters"))
                ]
            ]
        , describe "'Clear search and filters' in the 'No matches' state"
            [ test "is the label of the button there" <|
                \_ ->
                    page withReset nothingMatches
                        |> Expect.all
                            [ Query.has [ Selector.text "No matches" ]
                            , Query.find (buttonSaying "Clear search and filters") >> Query.has []
                            ]
            , test "the state does not say 'Reset filters', which would be less than the button does" <|
                \_ ->
                    page withReset nothingMatches
                        |> Query.find [ Selector.class "klar-state" ]
                        |> Query.hasNot [ Selector.text "Reset filters" ]
            , test "clears the search and the column filters" <|
                \_ ->
                    afterClicking withReset nothingMatches (buttonSaying "Clear search and filters")
                        |> expectCleared { search = "", filters = [] }
            , test "does what Table.clearFilters does" <|
                \_ ->
                    afterClicking withReset nothingMatches (buttonSaying "Clear search and filters")
                        |> expectOk (\state -> Expect.equal (Table.query (Table.clearFilters nothingMatches)) (Table.query state))
            , test "also sends onResetFilters" <|
                \_ -> expectWrapperSends withReset nothingMatches (buttonSaying "Clear search and filters")
            , test "has the same label when only the search matches nothing" <|
                \_ ->
                    page withReset (Table.setSearch "zzz" start)
                        |> Query.find (buttonSaying "Clear search and filters")
                        |> Query.has []
            , test "has the same label when only a filter matches nothing" <|
                \_ ->
                    page withReset (Table.setFilter (Table.columnId "city") (Just (OneOf [ "Nowhere" ])) start)
                        |> Query.find (buttonSaying "Clear search and filters")
                        |> Query.has []
            , test "is there in server mode too, and clears the search" <|
                \_ ->
                    let
                        server =
                            [ Table.server { total = 0 }, Table.rows (Success []), Table.onResetFilters FiltersReset ]
                    in
                    afterClicking server (Table.setSearch "zzz" start) (buttonSaying "Clear search and filters")
                        |> expectCleared { search = "", filters = [] }
            , test "is there when only filters outside the table hide the rows, and tells the application" <|
                \_ ->
                    let
                        outside =
                            [ Table.rowFilter (always False), Table.activeExternalFilters 1, Table.onResetFilters FiltersReset ]
                    in
                    Expect.all
                        [ \_ -> page outside start |> Query.find (buttonSaying "Clear search and filters") |> Query.has []
                        , \_ -> expectWrapperSends outside start (buttonSaying "Clear search and filters")
                        ]
                        ()
            ]
        , describe "in Norwegian"
            [ test "the summary says 'Nullstill filtre'" <|
                \_ ->
                    page [ Table.locale Locale.nb ] filteredAndSearched
                        |> Query.find [ Selector.tag "button", Selector.attribute (Attr.attribute "aria-label" "Nullstill filtre") ]
                        |> Query.has []
            , test "the 'No matches' state says 'Nullstill søk og filtre'" <|
                \_ ->
                    page [ Table.locale Locale.nb ] nothingMatches
                        |> Query.find (buttonSaying "Nullstill søk og filtre")
                        |> Query.has []
            ]
        ]



-- WHAT THE DOCUMENTATION OF Filter, filterSelect AND page SAYS


expectRows : Int -> List (Table.Attribute Order Msg) -> Table.State -> Expectation
expectRows count attributes state =
    page attributes state
        |> Query.findAll [ Selector.class "klar-table__row" ]
        |> Query.count (Expect.equal count)


filterDocumentationTests : Test
filterDocumentationTests =
    describe "Filter, filterSelect and page, as the documentation says"
        [ describe "Contains"
            [ test "looks for the text as one piece" <|
                \_ -> expectRows 1 [] (Table.setFilter (Table.columnId "customer") (Just (Contains "acme supp")) start)
            , test "does not look for each word separately, as the search box does" <|
                \_ ->
                    Expect.all
                        [ \_ -> expectRows 0 [] (Table.setFilter (Table.columnId "customer") (Just (Contains "supplies acme")) start)
                        , \_ -> expectRows 1 [] (Table.setSearch "supplies acme" start)
                        ]
                        ()
            , test "ignores case and accents" <|
                \_ -> expectRows 1 [] (Table.setFilter (Table.columnId "customer") (Just (Contains "ECLAIR")) start)
            ]
        , describe "OneOf"
            [ test "compares the whole text, case included" <|
                \_ ->
                    Expect.all
                        [ \_ -> expectRows 0 [] (Table.setFilter (Table.columnId "city") (Just (OneOf [ "oslo" ])) start)
                        , \_ -> expectRows 0 [] (Table.setFilter (Table.columnId "city") (Just (OneOf [ "Osl" ])) start)
                        , \_ -> expectRows 2 [] (Table.setFilter (Table.columnId "city") (Just (OneOf [ "Oslo" ])) start)
                        , \_ -> expectRows 3 [] (Table.setFilter (Table.columnId "city") (Just (OneOf [ "Oslo", "Bergen" ])) start)
                        ]
                        ()
            ]
        , describe "Between"
            [ test "includes the bounds" <|
                \_ -> expectRows 2 [] (Table.setFilter (Table.columnId "items") (Just (Between (Just 3) (Just 7))) start)
            , test "a Nothing bound is open" <|
                \_ ->
                    Expect.all
                        [ \_ -> expectRows 3 [] (Table.setFilter (Table.columnId "items") (Just (Between (Just 3) Nothing)) start)
                        , \_ -> expectRows 3 [] (Table.setFilter (Table.columnId "items") (Just (Between Nothing (Just 7))) start)
                        , \_ -> expectRows 4 [] (Table.setFilter (Table.columnId "items") (Just (Between Nothing Nothing)) start)
                        ]
                        ()
            , test "a row without a number does not match" <|
                \_ -> expectRows 2 [] (Table.setFilter (Table.columnId "weight") (Just (Between (Just 0) Nothing)) start)
            , test "on a column that has no numbers at all every row matches" <|
                \_ -> expectRows 4 [] (Table.setFilter (Table.columnId "city") (Just (Between (Just 5) (Just 6))) start)
            ]
        , choiceListTests
        , pageTests
        ]


{-| The list of values of a `filterSelect`: open the popover of the column.
-}
openedFilter : List (Table.Attribute Order Msg) -> String -> Table.State -> Result String Table.State
openedFilter attributes columnId state =
    page attributes state
        |> Query.find [ Selector.id ("orders-trigger-filter-" ++ columnId) ]
        |> Event.simulate Event.click
        |> Event.toResult
        |> Result.map (\msg -> applyMsg msg state)


{-| The options, top to bottom, each with its label and the count next to it
(`Nothing`: no count is shown).
-}
expectOptions : List ( String, Maybe String ) -> Query.Single Msg -> Expectation
expectOptions expected single =
    let
        options =
            Query.findAll [ Selector.class "klar-table__option" ] single

        optionAt index ( label, count ) _ =
            let
                option =
                    Query.index index options
            in
            Expect.all
                [ \_ -> Query.has [ Selector.text label ] option
                , \_ ->
                    case count of
                        Just text ->
                            option
                                |> Query.find [ Selector.class "klar-table__option-count" ]
                                |> Query.has [ Selector.exactText text ]

                        Nothing ->
                            option
                                |> Query.findAll [ Selector.class "klar-table__option-count" ]
                                |> Query.count (Expect.equal 0)
                ]
                ()
    in
    Expect.all
        ((\_ -> Query.count (Expect.equal (List.length expected)) options)
            :: List.indexedMap optionAt expected
        )
        ()


choiceListTests : Test
choiceListTests =
    let
        popover attributes state =
            openedFilter attributes "city" state
                |> Result.map (page attributes)

        filterOptionsOf values =
            Table.columns [ Table.text (Table.columnId "city") "City" .city [ Table.filterOptions values ] ]
    in
    describe "the values of filterSelect"
        [ test "client mode: the distinct values of all rows in alphabetical order, with the rows each would add" <|
            \_ ->
                popover [] start
                    |> expectOk (expectOptions [ ( "Bergen", Just "1" ), ( "Oslo", Just "2" ), ( "Trondheim", Just "1" ) ])
        , test "the counts follow the other filters and the search" <|
            \_ ->
                popover [] (Table.setFilter (Table.columnId "customer") (Just (Contains "acme")) start)
                    |> expectOk (expectOptions [ ( "Bergen", Just "0" ), ( "Oslo", Just "1" ), ( "Trondheim", Just "0" ) ])
        , test "the filter of the column itself does not count" <|
            \_ ->
                popover [] (Table.setFilter (Table.columnId "city") (Just (OneOf [ "Oslo" ])) start)
                    |> expectOk (expectOptions [ ( "Bergen", Just "1" ), ( "Oslo", Just "2" ), ( "Trondheim", Just "1" ) ])
        , test "blank values are not offered" <|
            \_ ->
                let
                    blank =
                        { number = "A-5", customer = "Hooli", city = "  ", items = 2, weight = Nothing, locked = False }
                in
                popover [ Table.rows (Success (orders ++ [ blank ])) ] start
                    |> expectOk (expectOptions [ ( "Bergen", Just "1" ), ( "Oslo", Just "2" ), ( "Trondheim", Just "1" ) ])
        , test "server mode, without filterOptions: only the values on the current page, and no counts" <|
            \_ ->
                let
                    server =
                        [ Table.server { total = 40 }, Table.rows (Success (List.take 2 orders)) ]
                in
                popover server start
                    |> expectOk (expectOptions [ ( "Bergen", Nothing ), ( "Oslo", Nothing ) ])
        , test "filterOptions replaces the values, in its order, and a chosen value that is not in it stays" <|
            \_ ->
                popover [ filterOptionsOf [ "Trondheim", "Oslo" ] ] (Table.setFilter (Table.columnId "city") (Just (OneOf [ "Gone" ])) start)
                    |> expectOk (expectOptions [ ( "Trondheim", Just "1" ), ( "Oslo", Just "2" ), ( "Gone", Just "0" ) ])
        , test "filterOptions in server mode: the given values, and no counts" <|
            \_ ->
                let
                    server =
                        [ Table.server { total = 40 }
                        , Table.rows (Success (List.take 2 orders))
                        , filterOptionsOf [ "Oslo", "Trondheim" ]
                        ]
                in
                popover server start
                    |> expectOk (expectOptions [ ( "Oslo", Nothing ), ( "Trondheim", Nothing ) ])
        , test "a search box appears above more than eight values" <|
            \_ ->
                let
                    cities count =
                        List.range 1 count |> List.map (\n -> "City " ++ String.fromInt n)

                    searchBoxes attributes =
                        popover attributes start
                            |> Result.map (Query.findAll [ Selector.id "orders-filter-city-search" ])
                in
                Expect.all
                    [ \_ -> searchBoxes [ filterOptionsOf (cities 9) ] |> expectOk (Query.count (Expect.equal 1))
                    , \_ -> searchBoxes [ filterOptionsOf (cities 8) ] |> expectOk (Query.count (Expect.equal 0))
                    ]
                    ()
        ]


{-| A page past the last one is drawn as the last page.
-}
pageTests : Test
pageTests =
    let
        twoPages =
            Table.setPageSize 2 start

        pastTheEnd =
            Table.setPage 99 twoPages

        currentPage attributes =
            page attributes pastTheEnd
                |> Query.find [ Selector.attribute (Attr.attribute "aria-current" "page") ]
    in
    describe "page"
        [ test "client mode: a page past the last one is drawn as the last page" <|
            \_ ->
                Expect.all
                    [ \_ -> currentPage [] |> Query.has [ Selector.attribute (Attr.attribute "aria-label" "Page 2") ]
                    , \_ -> expectRows 2 [] pastTheEnd
                    , \_ -> page [] pastTheEnd |> Query.has [ Selector.text "Initech" ]
                    ]
                    ()
        , test "server mode: the footer says the last page, the rows are the ones the application gave" <|
            \_ ->
                let
                    server =
                        [ Table.server { total = 4 }, Table.rows (Success (List.take 1 orders)) ]
                in
                Expect.all
                    [ \_ -> currentPage server |> Query.has [ Selector.attribute (Attr.attribute "aria-label" "Page 2") ]
                    , \_ -> page server pastTheEnd |> Query.has [ Selector.text "Acme Supplies" ]
                    ]
                    ()
        , test "Table.page keeps returning the number that was asked for" <|
            \_ -> Expect.equal 99 (Table.page pastTheEnd)
        ]



-- COLUMN IDS


columnIdTests : Test
columnIdTests =
    let
        customer =
            Table.columnId "customer"

        total =
            Table.columnId "total"
    in
    describe "column ids"
        [ test "a column id gives back the text it was made from" <|
            \_ -> Expect.equal "customer" (Table.columnName customer)
        , test "two ids made from the same text are equal" <|
            \_ -> Expect.equal customer (Table.columnId "customer")
        , test "the sort that was set is read back as the same ids" <|
            \_ ->
                Table.init "orders"
                    |> Table.setSort [ ( total, Table.Descending ), ( customer, Table.Ascending ) ]
                    |> Table.sort
                    |> Expect.equal [ ( total, Table.Descending ), ( customer, Table.Ascending ) ]
        , test "the filter that was set is read back under the same id" <|
            \_ ->
                Table.init "orders"
                    |> Table.setFilter customer (Just (Contains "acme"))
                    |> Table.filters
                    |> Expect.equal [ ( customer, Contains "acme" ) ]
        , test "a query carries ids, and can be put back with setQuery" <|
            \_ ->
                let
                    state =
                        Table.init "orders"
                            |> Table.setSort [ ( total, Table.Ascending ) ]
                            |> Table.setFilter customer (Just (Contains "acme"))
                in
                Table.init "orders"
                    |> Table.setQuery (Table.query state)
                    |> Table.query
                    |> Expect.equal (Table.query state)
        , test "the names for a backend come from the ids of the query" <|
            \_ ->
                Table.init "orders"
                    |> Table.setSort [ ( total, Table.Ascending ), ( customer, Table.Descending ) ]
                    |> Table.query
                    |> .sort
                    |> List.map (Tuple.first >> Table.columnName)
                    |> Expect.equal [ "total", "customer" ]
        , test "a column choice is remembered under the id" <|
            \_ ->
                Table.init "orders"
                    |> Table.setColumnVisible customer False
                    |> (\state -> ( Table.isColumnVisible customer state, Table.isColumnVisible total state ))
                    |> Expect.equal ( Just False, Nothing )
        ]
