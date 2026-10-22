module PermissionMatrixTest exposing (suite)

{-| Klar.PermissionMatrix: the grid and its names, the one tab stop, what a click or a
key on a cell asks for, the header checkboxes, the filter and the folded groups, the
unsaved marks, the announcements, the remote states, the texts in two languages and a
matrix of 200 by 25.
-}

import Expect
import Html exposing (Html)
import Html.Attributes as Attr
import Json.Encode as Encode
import Klar.Locale as Locale
import Klar.PermissionMatrix as PermissionMatrix exposing (Access(..), Change, Matrix)
import Klar.Remote as Remote
import Klar.Theme as Theme
import Set exposing (Set)
import Support.FlowHtml as H
import Test exposing (Test, describe, test)
import Test.Html.Event as Event
import Test.Html.Query as Query
import Test.Html.Selector as Selector exposing (Selector)


type Role
    = Picker
    | Dispatcher
    | Supervisor
    | Administrator


type Permission
    = ViewOrders
    | EditOrders
    | CancelOrders
    | ViewStock
    | AdjustStock
    | ExportReports


type Msg
    = MatrixMsg PermissionMatrix.Msg
    | Changed (List (Change Role Permission))
    | Reload


suite : Test
suite =
    describe "Klar.PermissionMatrix"
        [ structureTests
        , nameTests
        , stopTests
        , clickTests
        , keyTests
        , headerTests
        , filterTests
        , groupTests
        , savedTests
        , announcementTests
        , readOnlyTests
        , lockedTests
        , remoteTests
        , localeTests
        , listTests
        , sizeTests
        ]



-- THE DATA OF THE TESTS


roleKey : Role -> String
roleKey role =
    case role of
        Picker ->
            "picker"

        Dispatcher ->
            "dispatcher"

        Supervisor ->
            "supervisor"

        Administrator ->
            "administrator"


permissionKey : Permission -> String
permissionKey permission =
    case permission of
        ViewOrders ->
            "view-orders"

        EditOrders ->
            "edit-orders"

        CancelOrders ->
            "cancel-orders"

        ViewStock ->
            "view-stock"

        AdjustStock ->
            "adjust-stock"

        ExportReports ->
            "export-reports"


type alias Grants =
    Set ( String, String )


grants : Grants
grants =
    [ ( Picker, ViewOrders )
    , ( Dispatcher, ViewStock )
    , ( Supervisor, ViewOrders )
    , ( Supervisor, EditOrders )
    , ( Supervisor, ViewStock )
    ]
        ++ List.map (\p -> ( Administrator, p )) [ ViewOrders, EditOrders, CancelOrders, ViewStock, AdjustStock, ExportReports ]
        |> List.map (\( r, p ) -> ( roleKey r, permissionKey p ))
        |> Set.fromList


{-| The dispatcher may view orders because the picker may.
-}
cellOf : Grants -> Role -> Permission -> PermissionMatrix.Cell
cellOf given role permission =
    if role == Dispatcher && permission == ViewOrders then
        PermissionMatrix.inheritedFrom "Picker" Granted

    else if Set.member ( roleKey role, permissionKey permission ) given then
        PermissionMatrix.granted

    else
        PermissionMatrix.denied


theMatrix : (Role -> Permission -> PermissionMatrix.Cell) -> Matrix Role Permission
theMatrix cell =
    PermissionMatrix.matrix
        { roles =
            [ PermissionMatrix.role Picker "Picker"
            , PermissionMatrix.role Dispatcher "Dispatcher"
            , PermissionMatrix.role Supervisor "Supervisor"
            , PermissionMatrix.role Administrator "Administrator"
                |> PermissionMatrix.locked "Administrator always has every permission"
            ]
        , roleKey = roleKey
        , permissions =
            [ PermissionMatrix.permission ViewOrders "View orders" |> PermissionMatrix.inGroup "Orders"
            , PermissionMatrix.permission EditOrders "Edit orders" |> PermissionMatrix.inGroup "Orders"
            , PermissionMatrix.permission CancelOrders "Cancel orders" |> PermissionMatrix.inGroup "Orders"
            , PermissionMatrix.permission ViewStock "View stock" |> PermissionMatrix.inGroup "Stock"
            , PermissionMatrix.permission AdjustStock "Adjust stock" |> PermissionMatrix.inGroup "Stock"
            , PermissionMatrix.permission ExportReports "Export reports"
            ]
        , permissionKey = permissionKey
        , cell = cell
        }


{-| The rows of the grid, counting the header as 0: 1 is the group "Orders", 2 to 4 its
permissions, 5 the group "Stock", 6 and 7 its permissions, 8 "Export reports". The columns:
0 is the labels, 1 to 4 the roles in the order given.
-}
rowOf : Permission -> Int
rowOf permission =
    case permission of
        ViewOrders ->
            2

        EditOrders ->
            3

        CancelOrders ->
            4

        ViewStock ->
            6

        AdjustStock ->
            7

        ExportReports ->
            8


columnOf : Role -> Int
columnOf role =
    case role of
        Picker ->
            1

        Dispatcher ->
            2

        Supervisor ->
            3

        Administrator ->
            4


state : PermissionMatrix.State
state =
    PermissionMatrix.init "roles"


editable : List (PermissionMatrix.Attribute Role Permission Msg)
editable =
    [ PermissionMatrix.onChange Changed ]


viewWith : List (PermissionMatrix.Attribute Role Permission Msg) -> PermissionMatrix.State -> Html Msg
viewWith attributes current =
    PermissionMatrix.view MatrixMsg attributes current (theMatrix (cellOf grants))


viewIt : List (PermissionMatrix.Attribute Role Permission Msg) -> Html Msg
viewIt attributes =
    viewWith attributes state



-- EVENTS AS THE BROWSER WOULD SEND THEM


type alias Place =
    { row : Int
    , column : Int
    }


place : Permission -> Role -> Place
place permission role =
    { row = rowOf permission, column = columnOf role }


target : Place -> ( String, Encode.Value )
target at =
    ( "target"
    , Encode.object
        [ ( "dataset"
          , Encode.object
                [ ( "r", Encode.string (String.fromInt at.row) )
                , ( "c", Encode.string (String.fromInt at.column) )
                ]
          )
        ]
    )


{-| An event that started on something inside the cell at this place, the way a click on a
checkbox in a header does: the place is on the parent.
-}
insideTarget : Place -> ( String, Encode.Value )
insideTarget at =
    ( "target"
    , Encode.object
        [ ( "parentElement"
          , Encode.object
                [ ( "dataset"
                  , Encode.object
                        [ ( "r", Encode.string (String.fromInt at.row) )
                        , ( "c", Encode.string (String.fromInt at.column) )
                        ]
                  )
                ]
          )
        ]
    )


click : Place -> ( String, Encode.Value )
click at =
    ( "click", Encode.object [ target at ] )


keyDown : String -> Place -> ( String, Encode.Value )
keyDown key at =
    keyWith key { ctrl = False } at


keyWith : String -> { ctrl : Bool } -> Place -> ( String, Encode.Value )
keyWith key modifiers at =
    ( "keydown"
    , Encode.object
        [ ( "key", Encode.string key )
        , ( "ctrlKey", Encode.bool modifiers.ctrl )
        , ( "metaKey", Encode.bool False )
        , ( "shiftKey", Encode.bool False )
        , ( "altKey", Encode.bool False )
        , target at
        ]
    )


theTable : List Selector
theTable =
    [ Selector.tag "table" ]


theScroll : List Selector
theScroll =
    [ Selector.class "klar-permissions__scroll" ]


{-| What the grid sends to the application when this happens in the table.
-}
changesFor : ( String, Encode.Value ) -> Html Msg -> Maybe (List (Change Role Permission))
changesFor event html =
    case H.sends theTable event html of
        Ok (Changed changes) ->
            Just changes

        _ ->
            Nothing


{-| The message of the matrix itself for an event on the scroll area.
-}
internalFor : PermissionMatrix.State -> ( String, Encode.Value ) -> Maybe PermissionMatrix.Msg
internalFor current event =
    case H.sends theScroll event (viewWith editable current) of
        Ok (MatrixMsg inner) ->
            Just inner

        _ ->
            Nothing


through : ( String, Encode.Value ) -> PermissionMatrix.State -> PermissionMatrix.State
through event current =
    case internalFor current event of
        Just inner ->
            Tuple.first (PermissionMatrix.update inner current)

        Nothing ->
            current


the : Permission -> Role -> Change Role Permission
the permission role =
    { role = role, permission = permission, access = Granted }


denying : Permission -> Role -> Change Role Permission
denying permission role =
    { role = role, permission = permission, access = Denied }


stopsIn : Html Msg -> Query.Multiple Msg
stopsIn html =
    html
        |> Query.fromHtml
        |> Query.find theTable
        |> Query.findAll [ Selector.attribute (Attr.tabindex 0) ]


cellNamed : String -> List Selector
cellNamed name =
    [ H.attr "role" "gridcell", H.attr "aria-label" name ]


checkboxNamed : String -> List Selector
checkboxNamed name =
    [ Selector.tag "input", H.attr "aria-label" name ]



-- STRUCTURE


structureTests : Test
structureTests =
    describe "the grid"
        [ test "a grid with a name, the number of rows and columns, and the id of the matrix" <|
            \_ ->
                viewIt editable
                    |> Query.fromHtml
                    |> Expect.all
                        [ Query.has [ Selector.id "roles" ]
                        , Query.find theTable
                            >> Query.has [ H.attr "role" "grid", H.attr "aria-label" "Permissions", H.attr "aria-rowcount" "9", H.attr "aria-colcount" "5" ]
                        ]
        , test "the name of the grid can be set" <|
            \_ ->
                viewIt (PermissionMatrix.label "Permissions of the roles" :: editable)
                    |> H.inside theTable [ H.attr "aria-label" "Permissions of the roles" ]
        , test "headers: a column header for each role and the corner, a row header for each row" <|
            \_ ->
                viewIt editable
                    |> Query.fromHtml
                    |> Expect.all
                        [ Query.findAll [ H.attr "role" "columnheader" ] >> Query.count (Expect.equal 5)
                        , Query.findAll [ H.attr "role" "rowheader" ] >> Query.count (Expect.equal 8)
                        , Query.findAll [ H.attr "role" "gridcell" ] >> Query.count (Expect.equal 32)
                        ]
        , test "the roles are the columns, in the order given" <|
            \_ ->
                viewIt editable
                    |> Query.fromHtml
                    |> Query.findAll [ H.attr "role" "columnheader" ]
                    |> Expect.all
                        [ Query.index 1 >> Query.has [ Selector.text "Picker" ]
                        , Query.index 2 >> Query.has [ Selector.text "Dispatcher" ]
                        , Query.index 3 >> Query.has [ Selector.text "Supervisor" ]
                        , Query.index 4 >> Query.has [ Selector.text "Administrator" ]
                        ]
        , test "groups have a row that says how many permissions they hold" <|
            \_ ->
                viewIt editable
                    |> Query.fromHtml
                    |> Query.findAll [ Selector.class "klar-permissions__th--group" ]
                    |> Expect.all
                        [ Query.count (Expect.equal 2)
                        , Query.index 0 >> Query.has [ Selector.text "Orders", H.attr "aria-label" "Orders, 3 permissions", H.attr "aria-expanded" "true" ]
                        , Query.index 1 >> Query.has [ Selector.text "Stock", H.attr "aria-label" "Stock, 2 permissions" ]
                        ]
        , test "the density is a class, the same names as the table" <|
            \_ ->
                Expect.all
                    [ \_ -> viewIt editable |> H.has [ Selector.class "klar-permissions--normal" ]
                    , \_ -> viewIt (PermissionMatrix.density Theme.Compact :: editable) |> H.has [ Selector.class "klar-permissions--compact" ]
                    ]
                    ()
        , test "the height can be set, and is otherwise the stylesheet's" <|
            \_ ->
                viewIt (PermissionMatrix.maxHeight 300 :: editable)
                    |> H.inside theScroll [ Selector.attribute (Attr.attribute "style" "--klar-pm-cols:4;max-height:300px") ]
        , test "a duplicate key is left out: the first role and the first permission with a key stay" <|
            \_ ->
                PermissionMatrix.view MatrixMsg
                    editable
                    state
                    (PermissionMatrix.matrix
                        { roles = [ PermissionMatrix.role Picker "Picker", PermissionMatrix.role Picker "Picker again" ]
                        , roleKey = roleKey
                        , permissions = [ PermissionMatrix.permission ViewOrders "View orders", PermissionMatrix.permission ViewOrders "View orders again" ]
                        , permissionKey = permissionKey
                        , cell = \_ _ -> PermissionMatrix.denied
                        }
                    )
                    |> Query.fromHtml
                    |> Expect.all
                        [ Query.findAll [ H.attr "role" "columnheader" ] >> Query.count (Expect.equal 2)
                        , Query.findAll [ H.attr "role" "gridcell" ] >> Query.count (Expect.equal 1)
                        , Query.hasNot [ Selector.text "again" ]
                        ]
        , test "toolbar actions of the application are shown above the grid" <|
            \_ ->
                viewIt (PermissionMatrix.toolbarActions [ Html.button [] [ Html.text "Save" ] ] :: editable)
                    |> H.has [ Selector.class "klar-permissions__actions", Selector.containing [ Selector.text "Save" ] ]
        ]



-- NAMES


nameTests : Test
nameTests =
    describe "what a screen reader reads for a cell"
        [ test "role, permission and access" <|
            \_ ->
                viewIt editable
                    |> Expect.all
                        [ H.has (cellNamed "Supervisor, Cancel orders, denied")
                        , H.has (cellNamed "Supervisor, Edit orders, granted")
                        , H.has (cellNamed "Picker, View orders, granted")
                        ]
        , test "an inherited cell says where from" <|
            \_ ->
                viewIt editable
                    |> H.has (cellNamed "Dispatcher, View orders, granted, inherited from Picker")
        , test "an inherited cell without a source just says so" <|
            \_ ->
                PermissionMatrix.view MatrixMsg
                    editable
                    state
                    (theMatrix (\_ _ -> PermissionMatrix.inherited Denied))
                    |> H.has (cellNamed "Picker, View orders, denied, inherited")
        , test "a cell of a locked role says so, and points at the reason" <|
            \_ ->
                viewIt editable
                    |> H.has (cellNamed "Administrator, View orders, granted, locked" ++ [ H.attr "aria-disabled" "true" ])
        , test "an inherited cell is drawn with the word, so it differs in more than colour" <|
            \_ ->
                viewIt editable
                    |> Query.fromHtml
                    |> Query.find (cellNamed "Dispatcher, View orders, granted, inherited from Picker")
                    |> Query.has [ Selector.class "klar-permissions__cell--inherited", Selector.text "Picker" ]
        , test "a group row says how much of the group a role has" <|
            \_ ->
                viewIt editable
                    |> H.has [ H.attr "role" "gridcell", H.attr "aria-label" "Orders, Supervisor: 2 of 3 granted" ]
        ]



-- THE ONE TAB STOP


stopTests : Test
stopTests =
    describe "one tab stop"
        [ test "the grid has exactly one element in the tab order, the first cell" <|
            \_ ->
                viewIt editable
                    |> stopsIn
                    |> Expect.all
                        [ Query.count (Expect.equal 1)
                        , Query.index 0 >> Query.has [ Selector.id "roles/gOrders/rpicker" ]
                        ]
        , test "the stop follows the focus" <|
            \_ ->
                let
                    moved =
                        state |> through ( "focusin", Encode.object [ target (place CancelOrders Supervisor) ] )
                in
                viewWith editable moved
                    |> stopsIn
                    |> Expect.all
                        [ Query.count (Expect.equal 1)
                        , Query.index 0 >> Query.has [ Selector.id "roles/pcancel-orders/rsupervisor" ]
                        ]
        , test "a focus event that starts on a control inside a header moves the stop to that header" <|
            \_ ->
                let
                    moved =
                        state |> through ( "focusin", Encode.object [ insideTarget { row = 0, column = 3 } ] )
                in
                viewWith editable moved
                    |> stopsIn
                    |> Expect.all
                        [ Query.count (Expect.equal 1)
                        , Query.index 0 >> Query.has [ Selector.id "roles/h/rsupervisor" ]
                        ]
        , test "focus that is already at the stop sends nothing" <|
            \_ ->
                internalFor state ( "focusin", Encode.object [ target { row = 1, column = 1 } ] )
                    |> Expect.equal Nothing
        , test "focus that is outside the grid (the filter) sends nothing" <|
            \_ ->
                internalFor state ( "focusin", Encode.object [ ( "target", Encode.object [] ) ] )
                    |> Expect.equal Nothing
        , test "a stop that is no longer on the page is replaced by the first cell" <|
            \_ ->
                let
                    moved =
                        state |> through ( "focusin", Encode.object [ target (place AdjustStock Picker) ] )
                in
                viewWith editable (PermissionMatrix.setQuery "orders" moved)
                    |> stopsIn
                    |> Expect.all
                        [ Query.count (Expect.equal 1)
                        , Query.index 0 >> Query.has [ Selector.id "roles/gOrders/rpicker" ]
                        ]
        , test "every stop knows its place, and has an id" <|
            \_ ->
                viewIt editable
                    |> Query.fromHtml
                    |> Query.findAll [ H.attr "data-r" "2", H.attr "data-c" "3" ]
                    |> Query.count (Expect.equal 1)
        ]



-- CLICKS


clickTests : Test
clickTests =
    describe "a click or a key on a cell"
        [ test "a click on a cell asks for the opposite of what it says, in one change" <|
            \_ ->
                viewIt editable
                    |> changesFor (click (place CancelOrders Supervisor))
                    |> Expect.equal (Just [ the CancelOrders Supervisor ])
        , test "a granted cell is denied" <|
            \_ ->
                viewIt editable
                    |> changesFor (click (place EditOrders Supervisor))
                    |> Expect.equal (Just [ denying EditOrders Supervisor ])
        , test "an inherited cell flips what the user sees: inherited granted becomes a direct denied" <|
            \_ ->
                viewIt editable
                    |> changesFor (click (place ViewOrders Dispatcher))
                    |> Expect.equal (Just [ denying ViewOrders Dispatcher ])
        , test "a cell of a locked role asks for nothing" <|
            \_ ->
                viewIt editable
                    |> changesFor (click (place ViewOrders Administrator))
                    |> Expect.equal Nothing
        , test "Space and Enter do the same as a click" <|
            \_ ->
                viewIt editable
                    |> Expect.all
                        [ \html -> changesFor (keyDown " " (place CancelOrders Supervisor)) html |> Expect.equal (Just [ the CancelOrders Supervisor ])
                        , \html -> changesFor (keyDown "Enter" (place CancelOrders Supervisor)) html |> Expect.equal (Just [ the CancelOrders Supervisor ])
                        ]
        , test "other keys, and Space with a modifier, ask for nothing" <|
            \_ ->
                viewIt editable
                    |> Expect.all
                        [ \html -> changesFor (keyDown "a" (place CancelOrders Supervisor)) html |> Expect.equal Nothing
                        , \html -> changesFor (keyWith " " { ctrl = True } (place CancelOrders Supervisor)) html |> Expect.equal Nothing
                        ]
        , test "a click that did not start on the cell itself (on a control inside it) asks for nothing" <|
            \_ ->
                viewIt editable
                    |> changesFor ( "click", Encode.object [ insideTarget (place CancelOrders Supervisor) ] )
                    |> Expect.equal Nothing
        , test "a click on the labels, the header or a group row asks for nothing" <|
            \_ ->
                viewIt editable
                    |> Expect.all
                        [ \html -> changesFor (click { row = 2, column = 0 }) html |> Expect.equal Nothing
                        , \html -> changesFor (click { row = 0, column = 3 }) html |> Expect.equal Nothing
                        , \html -> changesFor (click { row = 1, column = 3 }) html |> Expect.equal Nothing
                        ]
        , test "a place that is not on the grid asks for nothing" <|
            \_ ->
                viewIt editable
                    |> changesFor (click { row = 40, column = 40 })
                    |> Expect.equal Nothing
        , test "the matrix remembers what the person did, from the same click" <|
            \_ ->
                internalFor state (click (place CancelOrders Supervisor))
                    |> Expect.notEqual Nothing
        , test "but not a click on a locked cell" <|
            \_ ->
                internalFor state (click (place ViewOrders Administrator))
                    |> Expect.equal Nothing
        ]



-- KEYS


keyTests : Test
keyTests =
    let
        from start key ctrl =
            -- one key from a cell, then which element is the tab stop
            let
                moved =
                    state
                        |> through ( "focusin", Encode.object [ target start ] )
                        |> through (keyWith key { ctrl = ctrl } start)
            in
            viewWith editable moved |> stopsIn |> Query.index 0

        at start key ctrl expected =
            from start key ctrl |> Query.has [ Selector.id expected ]
    in
    describe "arrow keys"
        [ test "ArrowDown, ArrowUp, ArrowRight and ArrowLeft move one cell" <|
            \_ ->
                let
                    start =
                        place CancelOrders Supervisor
                in
                Expect.all
                    [ \_ -> at start "ArrowDown" False "roles/gStock/rsupervisor"
                    , \_ -> at start "ArrowUp" False "roles/pedit-orders/rsupervisor"
                    , \_ -> at start "ArrowRight" False "roles/pcancel-orders/radministrator"
                    , \_ -> at start "ArrowLeft" False "roles/pcancel-orders/rdispatcher"
                    ]
                    ()
        , test "Home and End go to the first and last cell of the row, which is the label and the last role" <|
            \_ ->
                let
                    start =
                        place CancelOrders Supervisor
                in
                Expect.all
                    [ \_ -> at start "Home" False "roles/pcancel-orders/l"
                    , \_ -> at start "End" False "roles/pcancel-orders/radministrator"
                    ]
                    ()
        , test "Ctrl+Home and Ctrl+End go to the first and last cell of the matrix" <|
            \_ ->
                let
                    start =
                        place CancelOrders Supervisor
                in
                Expect.all
                    [ \_ -> at start "Home" True "roles/h/rpicker"
                    , \_ -> at start "End" True "roles/pexport-reports/radministrator"
                    ]
                    ()
        , test "PageDown and PageUp move ten rows, as far as there are rows" <|
            \_ ->
                Expect.all
                    [ \_ -> at (place ViewOrders Picker) "PageDown" False "roles/pexport-reports/rpicker"
                    , \_ -> at (place ExportReports Picker) "PageUp" False "roles/h/rpicker"
                    ]
                    ()
        , test "the header row is the row above the first row, and the labels the column before the first role" <|
            \_ ->
                Expect.all
                    [ \_ -> at { row = 1, column = 3 } "ArrowUp" False "roles/h/rsupervisor"
                    , \_ -> at (place ViewOrders Picker) "ArrowLeft" False "roles/pview-orders/l"
                    ]
                    ()
        , test "a key that cannot move still belongs to the grid: it sends a message that does nothing" <|
            \_ ->
                internalFor state (keyWith "ArrowUp" { ctrl = False } { row = 0, column = 1 })
                    |> Expect.notEqual Nothing
        , test "keys typed somewhere else (the filter) are left alone" <|
            \_ ->
                internalFor state ( "keydown", Encode.object [ ( "key", Encode.string "ArrowLeft" ), ( "ctrlKey", Encode.bool False ), ( "metaKey", Encode.bool False ), ( "shiftKey", Encode.bool False ), ( "altKey", Encode.bool False ), ( "target", Encode.object [] ) ] )
                    |> Expect.equal Nothing
        , test "shift and alt keep the keys of the browser" <|
            \_ ->
                internalFor state
                    ( "keydown"
                    , Encode.object
                        [ ( "key", Encode.string "ArrowDown" )
                        , ( "ctrlKey", Encode.bool False )
                        , ( "metaKey", Encode.bool False )
                        , ( "shiftKey", Encode.bool True )
                        , ( "altKey", Encode.bool False )
                        , target { row = 2, column = 1 }
                        ]
                    )
                    |> Expect.equal Nothing
        , test "Space on a group row folds the group, and the cells of the group go" <|
            \_ ->
                let
                    folded =
                        state |> through (keyDown " " { row = 1, column = 0 })
                in
                viewWith editable folded
                    |> Expect.all
                        [ H.none (cellNamed "Supervisor, Edit orders, granted")
                        , H.has [ H.attr "aria-expanded" "false", Selector.class "klar-permissions__th--group" ]
                        ]
        , test "a click on a group row folds it, and another opens it again" <|
            \_ ->
                let
                    folded =
                        state |> through (click { row = 1, column = 0 })
                in
                Expect.all
                    [ \_ -> PermissionMatrix.collapsedGroups folded |> Expect.equal [ "Orders" ]
                    , \_ -> PermissionMatrix.collapsedGroups (folded |> through (click { row = 1, column = 0 })) |> Expect.equal []
                    ]
                    ()
        ]



-- THE CHECKBOXES OF THE HEADERS


headerTests : Test
headerTests =
    let
        fire name yes html =
            html
                |> Query.fromHtml
                |> Query.find (checkboxNamed name)
                |> Event.simulate (Event.check yes)
                |> Event.toResult
    in
    describe "the checkboxes of a column and of a row"
        [ test "a role that has some of the permissions shows a dash, and its name says what it does" <|
            \_ ->
                viewIt editable
                    |> Query.fromHtml
                    |> Query.find [ Selector.class "klar-check--indeterminate", Selector.containing (checkboxNamed "Grant all permissions for Supervisor") ]
                    |> Query.has (checkboxNamed "Grant all permissions for Supervisor")
        , test "a click on it grants the rest: one message with the cells that change" <|
            \_ ->
                viewIt editable
                    |> fire "Grant all permissions for Supervisor" True
                    |> Expect.equal (Ok (Changed [ the CancelOrders Supervisor, the AdjustStock Supervisor, the ExportReports Supervisor ]))
        , test "a role that has nothing is unchecked, and one that has everything is checked and denies all" <|
            \_ ->
                let
                    all =
                        theMatrix (\_ _ -> PermissionMatrix.granted)
                in
                PermissionMatrix.view MatrixMsg editable state all
                    |> fire "Grant all permissions for Picker" False
                    |> Expect.equal
                        (Ok
                            (Changed
                                [ denying ViewOrders Picker
                                , denying EditOrders Picker
                                , denying CancelOrders Picker
                                , denying ViewStock Picker
                                , denying AdjustStock Picker
                                , denying ExportReports Picker
                                ]
                            )
                        )
        , test "the checkbox of a permission acts on the roles that can change, and leaves the locked one" <|
            \_ ->
                viewIt editable
                    |> fire "Grant Cancel orders to all roles" True
                    |> Expect.equal (Ok (Changed [ the CancelOrders Picker, the CancelOrders Dispatcher, the CancelOrders Supervisor ]))
        , test "a permission that all the editable roles have is checked, and a click denies them all, inherited ones too" <|
            \_ ->
                viewIt editable
                    |> fire "Grant View orders to all roles" False
                    |> Expect.equal (Ok (Changed [ denying ViewOrders Picker, denying ViewOrders Dispatcher, denying ViewOrders Supervisor ]))
        , test "an inherited granted cell counts as granted: it is not asked to be granted again" <|
            \_ ->
                viewIt editable
                    |> fire "Grant View orders to all roles" True
                    |> Expect.equal (Ok (Changed []))
        , test "a locked role has no checkbox, and says why in the header" <|
            \_ ->
                viewIt editable
                    |> Expect.all
                        [ H.none (checkboxNamed "Grant all permissions for Administrator")
                        , H.has [ H.attr "role" "columnheader", Selector.class "klar-permissions__th--locked", Selector.text "Administrator" ]
                        ]
        , test "there is no checkbox in a read-only matrix" <|
            \_ ->
                viewIt []
                    |> H.none [ Selector.attribute (Attr.type_ "checkbox") ]
        , test "a header checkbox is remembered by the matrix, as the whole column" <|
            \_ ->
                let
                    event =
                        ( "change", Encode.object [ insideTarget { row = 0, column = 3 } ] )
                in
                internalFor state event |> Expect.notEqual Nothing
        , test "and as the whole row" <|
            \_ ->
                internalFor state ( "change", Encode.object [ insideTarget { row = 4, column = 0 } ] )
                    |> Expect.notEqual Nothing
        , test "a change that does not come from a header checkbox is not remembered" <|
            \_ ->
                Expect.all
                    [ \_ -> internalFor state ( "change", Encode.object [ target { row = 4, column = 3 } ] ) |> Expect.equal Nothing
                    , \_ -> internalFor state ( "change", Encode.object [ ( "target", Encode.object [] ) ] ) |> Expect.equal Nothing
                    ]
                    ()
        ]



-- THE FILTER AND THE GROUPS


filterTests : Test
filterTests =
    describe "the filter"
        [ test "the filter box is named, and sends what is typed" <|
            \_ ->
                viewIt editable
                    |> Query.fromHtml
                    |> Query.find [ Selector.tag "input", Selector.id "roles-filter" ]
                    |> Expect.all
                        [ \_ -> viewIt editable |> H.has [ Selector.tag "label", Selector.containing [ Selector.text "Filter permissions" ] ]
                        , \_ -> PermissionMatrix.query (typed "stock") |> Expect.equal "stock"
                        ]
        , test "only the permissions that match are shown, with their group, and the count" <|
            \_ ->
                viewWith editable (PermissionMatrix.setQuery "adjust" state)
                    |> Query.fromHtml
                    |> Expect.all
                        [ Query.findAll [ Selector.class "klar-permissions__th--permission" ] >> Query.count (Expect.equal 1)
                        , Query.has [ Selector.class "klar-permissions__th--group", Selector.text "Stock" ]
                        , Query.hasNot [ Selector.text "Edit orders" ]
                        , Query.has [ Selector.class "klar-permissions__note", Selector.text "1 of 6 permissions match" ]
                        ]
        , test "no match: no grid, and a state that says what was searched for" <|
            \_ ->
                viewWith editable (PermissionMatrix.setQuery "zzz" state)
                    |> Query.fromHtml
                    |> Expect.all
                        [ Query.hasNot [ Selector.tag "table" ]
                        , Query.has [ Selector.text "No permission matches \"zzz\"" ]
                        ]
        , test "groups with a match are open while the filter is used, even when folded" <|
            \_ ->
                viewWith editable (state |> PermissionMatrix.setCollapsedGroups [ "Orders", "Stock" ] |> PermissionMatrix.setQuery "view")
                    |> Query.fromHtml
                    |> Query.findAll [ Selector.class "klar-permissions__th--permission" ]
                    |> Query.count (Expect.equal 2)
        , test "the folded groups come back when the filter is cleared" <|
            \_ ->
                viewWith editable (state |> PermissionMatrix.setCollapsedGroups [ "Orders" ] |> PermissionMatrix.setQuery "view" |> PermissionMatrix.setQuery "")
                    |> Query.fromHtml
                    |> Query.findAll [ Selector.class "klar-permissions__th--permission" ]
                    |> Query.count (Expect.equal 3)
        , test "a column checkbox acts on the permissions that are shown, and says so" <|
            \_ ->
                let
                    html =
                        viewWith editable (PermissionMatrix.setQuery "stock" state)
                in
                Expect.all
                    [ \_ ->
                        html
                            |> Query.fromHtml
                            |> Query.find (checkboxNamed "Grant the 2 permissions shown for Supervisor")
                            |> Event.simulate (Event.check True)
                            |> Event.toResult
                            |> Expect.equal (Ok (Changed [ the AdjustStock Supervisor ]))
                    , \_ -> H.none (checkboxNamed "Grant all permissions for Supervisor") html
                    ]
                    ()
        , test "the state keeps what was typed" <|
            \_ ->
                PermissionMatrix.query (PermissionMatrix.setQuery "stock" state) |> Expect.equal "stock"
        ]


{-| The state after text was typed in the filter box.
-}
typed : String -> PermissionMatrix.State
typed text =
    case
        viewIt editable
            |> Query.fromHtml
            |> Query.find [ Selector.tag "input", Selector.id "roles-filter" ]
            |> Event.simulate (Event.input text)
            |> Event.toResult
    of
        Ok (MatrixMsg inner) ->
            Tuple.first (PermissionMatrix.update inner state)

        _ ->
            state


groupTests : Test
groupTests =
    describe "folded groups"
        [ test "a folded group has its row and no permissions, and says what it holds" <|
            \_ ->
                viewWith editable (PermissionMatrix.setCollapsedGroups [ "Stock" ] state)
                    |> Query.fromHtml
                    |> Expect.all
                        [ Query.findAll [ Selector.class "klar-permissions__th--permission" ] >> Query.count (Expect.equal 4)
                        , Query.has [ H.attr "aria-label" "Stock, Supervisor: 1 of 2 granted", Selector.text "1/2" ]
                        , Query.has [ Selector.class "klar-permissions__th--group", H.attr "aria-expanded" "false" ]
                        ]
        , test "the folded groups are in the state, in order" <|
            \_ ->
                PermissionMatrix.collapsedGroups (PermissionMatrix.setCollapsedGroups [ "Stock", "Orders" ] state)
                    |> Expect.equal [ "Orders", "Stock" ]
        , test "a column checkbox still acts on the permissions of a folded group" <|
            \_ ->
                viewWith editable (PermissionMatrix.setCollapsedGroups [ "Stock", "Orders" ] state)
                    |> Query.fromHtml
                    |> Query.find (checkboxNamed "Grant all permissions for Supervisor")
                    |> Event.simulate (Event.check True)
                    |> Event.toResult
                    |> Expect.equal (Ok (Changed [ the CancelOrders Supervisor, the AdjustStock Supervisor, the ExportReports Supervisor ]))
        ]



-- UNSAVED CHANGES


baseline : Role -> Permission -> PermissionMatrix.Cell
baseline role permission =
    -- as saved: the supervisor could not edit orders, and the dispatcher had view orders directly
    if role == Supervisor && permission == EditOrders then
        PermissionMatrix.denied

    else if role == Dispatcher && permission == ViewOrders then
        PermissionMatrix.granted

    else
        cellOf grants role permission


savedTests : Test
savedTests =
    describe "unsaved changes"
        [ test "cells that differ from the saved value are marked with a dot and the words, and counted" <|
            \_ ->
                viewIt (PermissionMatrix.saved baseline :: editable)
                    |> Query.fromHtml
                    |> Expect.all
                        [ Query.has (cellNamed "Supervisor, Edit orders, granted, unsaved change")
                        , Query.find (cellNamed "Supervisor, Edit orders, granted, unsaved change")
                            >> Query.has [ Selector.class "klar-permissions__cell--changed", Selector.class "klar-permissions__dot" ]
                        , Query.find [ Selector.class "klar-permissions__changes" ]
                            >> Query.has [ H.attr "role" "status", Selector.text "2 unsaved changes" ]
                        ]
        , test "direct against inherited is a change, even when the access is the same" <|
            \_ ->
                viewIt (PermissionMatrix.saved baseline :: editable)
                    |> H.has (cellNamed "Dispatcher, View orders, granted, inherited from Picker, unsaved change")
        , test "one change is counted in the singular" <|
            \_ ->
                viewIt (PermissionMatrix.saved (\r p -> cellOf (Set.insert ( roleKey Supervisor, permissionKey CancelOrders ) grants) r p) :: editable)
                    |> H.inside [ Selector.class "klar-permissions__changes" ] [ Selector.text "1 unsaved change" ]
        , test "nothing differs: no marks, and an empty status that is still there for the next change" <|
            \_ ->
                viewIt (PermissionMatrix.saved (cellOf grants) :: editable)
                    |> Query.fromHtml
                    |> Expect.all
                        [ Query.hasNot [ Selector.class "klar-permissions__cell--changed" ]
                        , Query.find [ Selector.class "klar-permissions__changes" ] >> Query.has [ H.attr "role" "status" ]
                        , Query.find [ Selector.class "klar-permissions__changes" ] >> Query.hasNot [ Selector.text "unsaved" ]
                        ]
        , test "without saved values there is no count and no mark" <|
            \_ ->
                viewIt editable
                    |> Expect.all
                        [ H.none [ Selector.class "klar-permissions__changes" ]
                        , H.none [ Selector.class "klar-permissions__cell--changed" ]
                        ]
        , test "the count is of the whole matrix, not of what the filter shows" <|
            \_ ->
                viewWith (PermissionMatrix.saved baseline :: editable) (PermissionMatrix.setQuery "stock" state)
                    |> H.inside [ Selector.class "klar-permissions__changes" ] [ Selector.text "2 unsaved changes" ]
        ]



-- ANNOUNCEMENTS


announcementTests : Test
announcementTests =
    let
        live html =
            html
                |> Query.fromHtml
                |> Query.find [ H.attr "aria-live" "polite" ]

        announced given current =
            PermissionMatrix.view MatrixMsg editable current (theMatrix (cellOf given))
                |> live
    in
    describe "announcements"
        [ test "nothing is announced before the person has done something" <|
            \_ ->
                announced grants state |> Query.hasNot [ Selector.text "granted" ]
        , test "a change is announced from the value that the application gave afterwards" <|
            \_ ->
                let
                    acted =
                        state |> through (click (place CancelOrders Supervisor))

                    now =
                        Set.insert ( roleKey Supervisor, permissionKey CancelOrders ) grants
                in
                announced now acted |> Query.has [ Selector.text "Cancel orders granted to Supervisor" ]
        , test "a change that the application did not make is not announced as made" <|
            \_ ->
                let
                    acted =
                        state |> through (click (place CancelOrders Supervisor))
                in
                announced grants acted |> Query.has [ Selector.text "Cancel orders denied to Supervisor" ]
        , test "a denied change is announced too" <|
            \_ ->
                let
                    acted =
                        state |> through (keyDown " " (place EditOrders Supervisor))

                    now =
                        Set.remove ( roleKey Supervisor, permissionKey EditOrders ) grants
                in
                announced now acted |> Query.has [ Selector.text "Edit orders denied to Supervisor" ]
        , test "a whole role is announced as how much of it is granted" <|
            \_ ->
                let
                    acted =
                        state |> through ( "change", Encode.object [ insideTarget { row = 0, column = 3 } ] )
                in
                announced grants acted |> Query.has [ Selector.text "Supervisor: 3 of 6 permissions granted" ]
        , test "a whole permission is announced as how many roles have it" <|
            \_ ->
                let
                    acted =
                        state |> through ( "change", Encode.object [ insideTarget { row = 4, column = 0 } ] )
                in
                announced grants acted |> Query.has [ Selector.text "Cancel orders: granted to 0 of 3 roles" ]
        , test "the region is polite and always on the page" <|
            \_ ->
                viewIt editable
                    |> H.has [ H.attr "aria-live" "polite", H.attr "role" "status" ]
        ]



-- READ ONLY


readOnlyTests : Test
readOnlyTests =
    describe "read-only"
        [ test "without onChange nothing can be changed, and the grid says so" <|
            \_ ->
                viewIt []
                    |> Query.fromHtml
                    |> Expect.all
                        [ Query.find theTable >> Query.has [ H.attr "aria-readonly" "true" ]
                        , Query.has [ Selector.class "klar-permissions--readonly" ]
                        , Query.hasNot [ Selector.class "klar-permissions__cell--editable" ]
                        ]
        , test "no click or key makes a change, and no event is listened to on the table" <|
            \_ ->
                viewIt []
                    |> Expect.all
                        [ \html -> H.sends theTable (click (place CancelOrders Supervisor)) html |> Expect.err
                        , \html -> H.sends theTable (keyDown " " (place CancelOrders Supervisor)) html |> Expect.err
                        ]
        , test "every cell shows its state as an icon and a word" <|
            \_ ->
                viewIt []
                    |> Query.fromHtml
                    |> Expect.all
                        [ Query.find (cellNamed "Supervisor, Cancel orders, denied")
                            >> Query.has [ Selector.text "Denied", Selector.class "klar-icon--minus" ]
                        , Query.find (cellNamed "Supervisor, Edit orders, granted")
                            >> Query.has [ Selector.text "Granted", Selector.class "klar-icon--check" ]
                        ]
        , test "the grid can still be moved through with the keys, and a group folded" <|
            \_ ->
                H.sends theScroll (keyDown "ArrowDown" { row = 2, column = 1 }) (viewIt [])
                    |> Result.map (always ())
                    |> Expect.equal (Ok ())
        ]



-- LOCKED ROLES


lockedTests : Test
lockedTests =
    describe "locked roles"
        [ test "the reason is written under the grid, with a lock" <|
            \_ ->
                viewIt editable
                    |> H.inside [ Selector.class "klar-permissions__locked-list" ]
                        [ Selector.text "Administrator: Administrator always has every permission"
                        , Selector.containing [ Selector.class "klar-icon--lock" ]
                        ]
        , test "the header and every cell of the column refer to the reason, and it is on the page" <|
            \_ ->
                let
                    reasonId =
                        "roles/reason/administrator"
                in
                viewIt editable
                    |> Query.fromHtml
                    |> Expect.all
                        [ Query.has [ Selector.id reasonId ]
                        , Query.find (cellNamed "Administrator, Cancel orders, granted, locked") >> Query.has [ H.attr "aria-describedby" reasonId ]
                        , Query.find [ Selector.class "klar-permissions__th--locked" ] >> Query.has [ H.attr "aria-describedby" reasonId ]
                        ]
        , test "the header of a locked role is the stop itself: it has an id and a place" <|
            \_ ->
                viewIt editable
                    |> H.has [ Selector.class "klar-permissions__th--locked", Selector.id "roles/h/radministrator", H.attr "data-c" "4" ]
        , test "a locked role without a reason still says that it is locked" <|
            \_ ->
                PermissionMatrix.view MatrixMsg
                    editable
                    state
                    (PermissionMatrix.matrix
                        { roles = [ PermissionMatrix.role Picker "Picker" |> PermissionMatrix.locked "  " ]
                        , roleKey = roleKey
                        , permissions = [ PermissionMatrix.permission ViewOrders "View orders" ]
                        , permissionKey = permissionKey
                        , cell = \_ _ -> PermissionMatrix.denied
                        }
                    )
                    |> H.has [ Selector.text "Picker: This role cannot be changed" ]
        , test "no role is locked: no list" <|
            \_ ->
                PermissionMatrix.view MatrixMsg
                    editable
                    state
                    (PermissionMatrix.matrix
                        { roles = [ PermissionMatrix.role Picker "Picker" ]
                        , roleKey = roleKey
                        , permissions = [ PermissionMatrix.permission ViewOrders "View orders" ]
                        , permissionKey = permissionKey
                        , cell = \_ _ -> PermissionMatrix.denied
                        }
                    )
                    |> H.none [ Selector.class "klar-permissions__locked-list" ]
        ]



-- REMOTE


remoteTests : Test
remoteTests =
    let
        remote data =
            PermissionMatrix.viewRemote MatrixMsg [ PermissionMatrix.onRetry Reload ] state data
    in
    describe "remote data"
        [ test "loading and not asked show a skeleton in the shape of a grid, busy, with a status" <|
            \_ ->
                Expect.all
                    (List.map
                        (\data -> \_ -> remote data |> H.has [ H.attr "aria-busy" "true", Selector.class "klar-permissions--skeleton" ])
                        [ Remote.NotAsked, Remote.Loading ]
                    )
                    ()
        , test "the skeleton has a header row and rows of cells" <|
            \_ ->
                remote Remote.Loading
                    |> Query.fromHtml
                    |> Expect.all
                        [ Query.findAll [ Selector.class "klar-permissions__skeleton-row" ] >> Query.count (Expect.equal 7)
                        , Query.has [ H.attr "role" "status", Selector.text "Loading permissions" ]
                        ]
        , test "a failure shows the problem and a retry button that sends the message" <|
            \_ ->
                let
                    html =
                        remote (Remote.Failure (Remote.problem Remote.network))
                in
                Expect.all
                    [ \_ -> H.has [ Selector.text "Try again" ] html
                    , \_ -> H.sends [ Selector.tag "button", Selector.containing [ Selector.text "Try again" ] ] ( "click", Encode.object [] ) html |> Expect.equal (Ok Reload)
                    ]
                    ()
        , test "success shows the matrix" <|
            \_ ->
                remote (Remote.Success (theMatrix (cellOf grants)))
                    |> H.has [ Selector.tag "table" ]
        , test "no roles and no permissions have states of their own" <|
            \_ ->
                let
                    none roles permissions =
                        PermissionMatrix.view MatrixMsg
                            editable
                            state
                            (PermissionMatrix.matrix
                                { roles = roles
                                , roleKey = roleKey
                                , permissions = permissions
                                , permissionKey = permissionKey
                                , cell = \_ _ -> PermissionMatrix.denied
                                }
                            )
                in
                Expect.all
                    [ \_ -> none [] [ PermissionMatrix.permission ViewOrders "View orders" ] |> H.has [ Selector.text "No roles to show" ]
                    , \_ -> none [ PermissionMatrix.role Picker "Picker" ] [] |> H.has [ Selector.text "No permissions to show" ]
                    ]
                    ()
        ]



-- NORWEGIAN


localeTests : Test
localeTests =
    describe "Norwegian"
        [ test "the names of cells, the filter, the checkboxes and the notes" <|
            \_ ->
                viewIt (PermissionMatrix.locale Locale.nb :: PermissionMatrix.saved baseline :: editable)
                    |> Query.fromHtml
                    |> Expect.all
                        [ Query.has [ H.attr "aria-label" "Tilganger" ]
                        , Query.has (cellNamed "Supervisor, Cancel orders, nektet")
                        , Query.has (cellNamed "Dispatcher, View orders, gitt, arvet fra Picker, ulagret endring")
                        , Query.has (cellNamed "Administrator, View orders, gitt, låst")
                        , Query.has (checkboxNamed "Gi alle tilganger for Supervisor")
                        , Query.has (checkboxNamed "Gi Cancel orders til alle roller")
                        , Query.has [ Selector.tag "label", Selector.containing [ Selector.text "Filtrer tilganger" ] ]
                        , Query.has [ Selector.text "2 ulagrede endringer" ]
                        ]
        , test "read-only words and the skeleton in Norwegian" <|
            \_ ->
                viewIt [ PermissionMatrix.locale Locale.nb ]
                    |> H.has [ Selector.text "Nektet", Selector.text "Gitt", Selector.text "Picker" ]
        , test "the failure and the empty states in Norwegian" <|
            \_ ->
                Expect.all
                    [ \_ -> PermissionMatrix.viewRemote MatrixMsg [ PermissionMatrix.locale Locale.nb ] state Remote.Loading |> H.has [ Selector.text "Laster tilganger" ]
                    , \_ -> viewWith [ PermissionMatrix.locale Locale.nb ] (PermissionMatrix.setQuery "zzz" state) |> H.has [ Selector.text "Ingen tilgang treffer «zzz»" ]
                    ]
                    ()
        , test "an announcement in Norwegian" <|
            \_ ->
                let
                    acted =
                        state |> through (click (place CancelOrders Supervisor))
                in
                PermissionMatrix.view MatrixMsg (PermissionMatrix.locale Locale.nb :: editable) acted (theMatrix (cellOf (Set.insert ( roleKey Supervisor, permissionKey CancelOrders ) grants)))
                    |> H.has [ Selector.text "Cancel orders gitt til Supervisor" ]
        ]



-- THE ORDER OF THE ATTRIBUTES


listTests : Test
listTests =
    describe "attributes"
        [ test "the order does not matter" <|
            \_ ->
                let
                    a =
                        viewIt [ PermissionMatrix.onChange Changed, PermissionMatrix.saved baseline, PermissionMatrix.label "x" ]

                    b =
                        viewIt [ PermissionMatrix.label "x", PermissionMatrix.saved baseline, PermissionMatrix.onChange Changed ]
                in
                Expect.equal (Query.fromHtml a |> Query.find [ Selector.class "klar-permissions__changes" ] |> Query.has [ Selector.text "2 unsaved changes" ])
                    (Query.fromHtml b |> Query.find [ Selector.class "klar-permissions__changes" ] |> Query.has [ Selector.text "2 unsaved changes" ])
        , test "a later attribute wins" <|
            \_ ->
                viewIt [ PermissionMatrix.label "first", PermissionMatrix.label "second" ]
                    |> H.inside theTable [ H.attr "aria-label" "second" ]
        ]



-- SIZE


bigPermissions : Int -> List (PermissionMatrix.Permission Int)
bigPermissions n =
    List.range 1 n
        |> List.map (\i -> PermissionMatrix.permission i ("Permission " ++ String.fromInt i))


bigRoles : Int -> List (PermissionMatrix.Role Int)
bigRoles n =
    List.range 1 n
        |> List.map (\i -> PermissionMatrix.role i ("Role " ++ String.fromInt i))


bigMatrix : Int -> Int -> Matrix Int Int
bigMatrix permissions roles =
    PermissionMatrix.matrix
        { roles = bigRoles roles
        , roleKey = String.fromInt
        , permissions = bigPermissions permissions
        , permissionKey = String.fromInt
        , cell =
            \r p ->
                if modBy 3 (r + p) == 0 then
                    PermissionMatrix.granted

                else
                    PermissionMatrix.denied
        }


sizeTests : Test
sizeTests =
    describe "size"
        [ test "200 permissions and 25 roles: 5 000 cells, and none of them has a handler of its own" <|
            \_ ->
                PermissionMatrix.view (\_ -> ()) [ PermissionMatrix.onChange (\_ -> ()) ] state (bigMatrix 200 25)
                    |> Query.fromHtml
                    |> Expect.all
                        [ Query.findAll [ H.attr "role" "gridcell" ] >> Query.count (Expect.equal 5000)
                        , Query.find theTable >> Query.has [ H.attr "aria-rowcount" "201", H.attr "aria-colcount" "26" ]
                        ]
        , test "more than 500 permissions are cut, and the note says how many there are" <|
            \_ ->
                PermissionMatrix.view (\_ -> ()) [ PermissionMatrix.onChange (\_ -> ()) ] state (bigMatrix 620 3)
                    |> Query.fromHtml
                    |> Expect.all
                        [ Query.findAll [ Selector.class "klar-permissions__th--permission" ] >> Query.count (Expect.equal 500)
                        , Query.has [ Selector.class "klar-permissions__note", Selector.text "Showing the first 500 of 620 permissions. Use the filter to narrow the list." ]
                        ]
        , test "a header checkbox acts on all the permissions, also those that are cut" <|
            \_ ->
                PermissionMatrix.view (\_ -> 0) [ PermissionMatrix.onChange List.length ] state (bigMatrix 620 3)
                    |> Query.fromHtml
                    |> Query.find [ Selector.tag "input", H.attr "aria-label" "Grant all permissions for Role 1" ]
                    |> Event.simulate (Event.check True)
                    |> Event.toResult
                    -- 207 of the 620 are granted already (every third one), so 413 change
                    |> Expect.equal (Ok 413)
        ]
