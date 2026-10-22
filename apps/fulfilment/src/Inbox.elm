module Inbox exposing
    ( Env
    , Model
    , Msg
    , applyView
    , askNewView
    , focusTable
    , init
    , isBlocking
    , overlays
    , reload
    , searchOrders
    , update
    , view
    )

{-| The inbox of orders: a server-mode table with filters, saved views, selection
and bulk actions.
-}

import Api
import Backend exposing (Db, Request, Target(..))
import Domain exposing (..)
import Effect exposing (Effects)
import Html exposing (Html)
import Ids
import Klar.Button as Button
import Klar.ConfirmDialog as ConfirmDialog
import Klar.Date exposing (Date)
import Klar.EmptyState as EmptyState
import Klar.FilterBar as FilterBar
import Klar.Icon as Icon
import Klar.Layout as Layout
import Klar.Locale as Locale
import Klar.Modal as Modal
import Klar.Remote as Remote exposing (Problem, Remote(..))
import Klar.Rule as Rule
import Klar.SavedViews as SavedViews
import Klar.Select as Select
import Klar.Table as Table
import Klar.Text as Text
import Klar.TextInput as TextInput
import Klar.Theme as Theme
import Url


type alias Env =
    { net : Api.Net
    , db : Db
    , today : Date
    , baseUrl : String
    }


type alias Model =
    { table : Table.State OrderId
    , filters : FilterBar.State
    , views : SavedViews.State
    , rows : Remote (List Summary)
    , total : Int
    , refreshing : Bool
    , ticket : Int
    , requested : Request
    , packing : Bool
    , assign : ConfirmDialog.State
    , assignPerson : Select.State PersonId
    , assignTarget : Target
    , assignError : Maybe String
    , newView : Modal.State
    , newViewName : String
    , newViewError : Maybe String
    , share : Modal.State
    }


type Msg
    = TableMsg Table.Msg
    | FiltersMsg FilterBar.Msg
    | ViewsMsg SavedViews.Msg
    | GotPage Int (Result Problem Backend.Page)
    | Retry
    | Reload
    | ResetFilters
    | RowClicked Summary
    | PackSelected
    | Packed (Result Problem (Db -> ( Db, Backend.Packing )))
    | AskAssign
    | AssignSelectMsg (Select.Msg PersonId)
    | AssignDialogMsg ConfirmDialog.Msg
    | ConfirmAssign
    | CancelAssign
    | Assigned (Result Problem (Db -> Db))
    | ViewsSaved (Result Problem (Db -> Db))
    | NewViewMsg Modal.Msg
    | NewViewNameChanged String
    | SaveNewView
    | CancelNewView
    | ShareMsg Modal.Msg
    | AskShare
    | NoOp


rowIds : Table.RowIds OrderId
rowIds =
    Table.rowIds { toKey = orderIdToString, fromKey = orderIdFromString }


colNumber : Table.ColumnId
colNumber =
    Table.columnId "number"


colCustomer : Table.ColumnId
colCustomer =
    Table.columnId "customer"


colStatus : Table.ColumnId
colStatus =
    Table.columnId "status"


colCreated : Table.ColumnId
colCreated =
    Table.columnId "created"


colDue : Table.ColumnId
colDue =
    Table.columnId "due"


colTotal : Table.ColumnId
colTotal =
    Table.columnId "total"


colAssignee : Table.ColumnId
colAssignee =
    Table.columnId "assignee"


people : List Person
people =
    Backend.people



-- INIT


init : Env -> Maybe String -> ( Model, Cmd Msg )
init env viewName =
    let
        views0 =
            SavedViews.init Ids.views |> SavedViews.setViews env.db.views

        chosen =
            case viewName |> Maybe.andThen (viewNamed views0) of
                Just found ->
                    Just found

                Nothing ->
                    SavedViews.defaultView views0

        model =
            { table = Table.init Ids.orders |> Table.setPageSize 200
            , filters =
                FilterBar.init Ids.filters
                    |> FilterBar.setRule (chosen |> Maybe.map .rule |> Maybe.withDefault Rule.emptyGroup)
            , views = SavedViews.setActive (Maybe.map .name chosen) views0
            , rows = Loading
            , total = 0
            , refreshing = False
            , ticket = 0
            , requested = { rule = Rule.emptyGroup, search = "", sort = [], page = 1, pageSize = 200 }
            , packing = False
            , assign = ConfirmDialog.init Ids.assignDialog
            , assignPerson = Select.init Ids.assignPerson
            , assignTarget = Ids []
            , assignError = Nothing
            , newView = Modal.init Ids.newViewDialog
            , newViewName = ""
            , newViewError = Nothing
            , share = Modal.init Ids.shareDialog
            }
    in
    fetch env model


viewNamed : SavedViews.State -> String -> Maybe SavedViews.SavedView
viewNamed views name =
    SavedViews.views views
        |> List.filter (\v -> String.toLower v.name == String.toLower (String.trim name))
        |> List.head


{-| Puts keyboard focus back on the table, for when the drawer closed.
-}
focusTable : Model -> Cmd Msg
focusTable model =
    Cmd.map TableMsg (Table.focus model.table)


{-| Opens the saved view with this name (from a link), if there is one.
-}
applyView : Env -> String -> Model -> ( Model, Cmd Msg )
applyView env name model =
    case viewNamed model.views name of
        Nothing ->
            ( model, Cmd.none )

        Just found ->
            sync env
                { model
                    | views = SavedViews.setActive (Just found.name) model.views
                    , filters = FilterBar.setRule found.rule model.filters
                    , table = Table.setPage 1 model.table
                }



-- REQUESTS


request : Model -> Request
request model =
    let
        query =
            Table.query model.table
    in
    { rule = FilterBar.rule model.filters
    , search = query.search
    , sort = List.map (\( column, direction ) -> ( Table.columnName column, direction == Table.Ascending )) query.sort
    , page = query.page
    , pageSize = query.pageSize
    }


fetch : Env -> Model -> ( Model, Cmd Msg )
fetch env model =
    let
        ticket =
            model.ticket + 1

        wanted =
            request model
    in
    ( { model
        | ticket = ticket
        , requested = wanted
        , refreshing = Remote.isSuccess model.rows
        , rows =
            if Remote.isSuccess model.rows then
                model.rows

            else
                Loading
      }
    , Api.search env.net env.db wanted (GotPage ticket)
    )


{-| Fetches again when the table, the filters or the search no longer say what
was asked for.
-}
sync : Env -> Model -> ( Model, Cmd Msg )
sync env model =
    if request model == model.requested then
        ( model, Cmd.none )

    else
        fetch env model


reload : Env -> Model -> ( Model, Cmd Msg )
reload =
    fetch


searchOrders : Env -> String -> (Result Problem Backend.Page -> msg) -> Cmd msg
searchOrders env term toMsg =
    Api.search env.net
        env.db
        { rule = Rule.emptyGroup, search = term, sort = [], page = 1, pageSize = 6 }
        toMsg


target : Model -> Target
target model =
    case Table.selection rowIds model.table of
        Table.Selected ids ->
            Ids ids

        Table.AllMatching { except } ->
            AllMatching model.requested except


{-| Opens the dialog that asks for the name of a new saved view.

-- KLAR GAP: SavedViews cannot open its own "Save current view ..." form from a
shortcut or a command, so the application has a form of its own.

-}
askNewView : Model -> ( Model, Cmd Msg )
askNewView model =
    let
        ( dialog, cmd ) =
            Modal.openWith { opener = "", focus = [ Ids.newViewName ] } model.newView
    in
    ( { model | newView = dialog, newViewName = "", newViewError = Nothing }, Cmd.map NewViewMsg cmd )



-- UPDATE


update : Env -> Msg -> Model -> ( Model, Cmd Msg, Effects Msg )
update env msg model =
    case msg of
        NoOp ->
            plain ( model, Cmd.none )

        TableMsg m ->
            let
                ( table, cmd ) =
                    Table.update m model.table

                ( next, fetchCmd ) =
                    sync env { model | table = table }
            in
            plain ( next, Cmd.batch [ Cmd.map TableMsg cmd, fetchCmd ] )

        FiltersMsg m ->
            let
                ( filters, cmd ) =
                    FilterBar.update m model.filters

                changed =
                    FilterBar.rule filters /= FilterBar.rule model.filters

                ( next, fetchCmd ) =
                    sync env
                        { model
                            | filters = filters
                            , table =
                                if changed then
                                    Table.setPage 1 model.table

                                else
                                    model.table
                        }
            in
            plain ( next, Cmd.batch [ Cmd.map FiltersMsg cmd, fetchCmd ] )

        ViewsMsg m ->
            let
                ( views, cmd ) =
                    SavedViews.update m model.views

                applied =
                    if SavedViews.revision views /= SavedViews.revision model.views then
                        { model
                            | views = views
                            , filters =
                                FilterBar.setRule
                                    (SavedViews.active views |> Maybe.map .rule |> Maybe.withDefault Rule.emptyGroup)
                                    model.filters
                            , table = Table.setPage 1 model.table
                        }

                    else
                        { model | views = views }

                ( next, fetchCmd ) =
                    sync env applied

                save =
                    if SavedViews.views views /= SavedViews.views model.views then
                        Api.saveViews env.net (SavedViews.views views) ViewsSaved

                    else
                        Cmd.none
            in
            plain ( next, Cmd.batch [ Cmd.map ViewsMsg cmd, fetchCmd, save ] )

        GotPage ticket result ->
            if ticket /= model.ticket then
                plain ( model, Cmd.none )

            else
                case result of
                    Ok page ->
                        plain ( { model | rows = Success page.rows, total = page.total, refreshing = False }, Cmd.none )

                    Err problem ->
                        plain ( { model | rows = Failure problem, refreshing = False }, Cmd.none )

        Retry ->
            plain (fetch env { model | rows = Loading })

        Reload ->
            plain (fetch env model)

        ResetFilters ->
            let
                ( next, cmd ) =
                    sync env
                        { model
                            | filters = FilterBar.clear model.filters
                            , views = SavedViews.setActive Nothing model.views
                            , table = Table.setPage 1 model.table
                        }
            in
            plain ( next, cmd )

        RowClicked summary ->
            ( model, Cmd.none, { none | open = Just summary.id } )

        PackSelected ->
            ( { model | packing = True }
            , Api.pack env.net (target model) Packed
            , Effect.none
            )

        Packed (Ok change) ->
            let
                -- the change is applied by the application, the counts come with it
                ( _, counts ) =
                    change env.db

                text =
                    String.fromInt counts.changed
                        ++ plural counts.changed " order" " orders"
                        ++ " marked as packed"
                        ++ (if counts.skipped > 0 then
                                ", " ++ String.fromInt counts.skipped ++ " skipped because they were not being picked"

                            else
                                ""
                           )
            in
            ( { model | packing = False, table = Table.clearSelection model.table }
            , Cmd.map TableMsg (Table.focus model.table)
            , { none
                | notices = [ { tone = Theme.Success, title = "Packed", message = text, retry = Nothing } ]
                , change = Just (change >> Tuple.first)
              }
            )

        Packed (Err problem) ->
            ( { model | packing = False }
            , Cmd.none
            , Effect.notify
                { tone = Theme.Danger
                , title = "Could not mark as packed"
                , message = Remote.title Locale.default problem ++ ". The selection is kept."
                , retry = Just PackSelected
                }
            )

        AskAssign ->
            let
                ( dialog, cmd ) =
                    ConfirmDialog.open Ids.bulkAssign model.assign
            in
            plain
                ( { model | assign = dialog, assignTarget = target model, assignError = Nothing }
                , Cmd.map AssignDialogMsg cmd
                )

        AssignSelectMsg m ->
            let
                ( select, cmd ) =
                    Select.update m model.assignPerson
            in
            plain
                ( { model
                    | assignPerson = select
                    , assignError =
                        if Select.value select /= Select.value model.assignPerson then
                            Nothing

                        else
                            model.assignError
                  }
                , Cmd.map AssignSelectMsg cmd
                )

        AssignDialogMsg m ->
            let
                ( dialog, cmd ) =
                    ConfirmDialog.update m model.assign
            in
            plain ( { model | assign = dialog }, Cmd.map AssignDialogMsg cmd )

        ConfirmAssign ->
            case Select.value model.assignPerson of
                Nothing ->
                    plain ( { model | assignError = Just "Choose who the orders are assigned to." }, Cmd.none )

                Just person ->
                    plain
                        ( { model | assign = ConfirmDialog.setBusy model.assign }
                        , Api.assign env.net model.assignTarget person Assigned
                        )

        CancelAssign ->
            if ConfirmDialog.isBusy model.assign then
                plain ( model, Cmd.none )

            else
                let
                    ( dialog, cmd ) =
                        ConfirmDialog.close model.assign
                in
                plain ( { model | assign = dialog }, Cmd.map AssignDialogMsg cmd )

        Assigned (Ok change) ->
            let
                ( dialog, cmd ) =
                    ConfirmDialog.close model.assign
            in
            ( { model | assign = dialog, table = Table.clearSelection model.table, assignPerson = Select.clear model.assignPerson }
            , Cmd.batch [ Cmd.map AssignDialogMsg cmd, Cmd.map TableMsg (Table.focus model.table) ]
            , { none
                | notices = [ { tone = Theme.Success, title = "Assigned", message = "The orders were assigned.", retry = Nothing } ]
                , change = Just change
              }
            )

        Assigned (Err problem) ->
            ( { model | assign = ConfirmDialog.setFailed problem model.assign }
            , Cmd.none
            , Effect.notify
                { tone = Theme.Danger
                , title = "Could not assign"
                , message = "Nothing was changed."
                , retry = Nothing
                }
            )

        ViewsSaved (Ok change) ->
            ( model, Cmd.none, { none | change = Just change } )

        ViewsSaved (Err _) ->
            ( model
            , Cmd.none
            , Effect.notify
                { tone = Theme.Danger
                , title = "Could not save the views"
                , message = "Your views are still here, but they are not stored yet."
                , retry = Nothing
                }
            )

        NewViewMsg m ->
            let
                ( dialog, cmd ) =
                    Modal.update m model.newView
            in
            plain ( { model | newView = dialog }, Cmd.map NewViewMsg cmd )

        NewViewNameChanged text ->
            plain ( { model | newViewName = text, newViewError = Nothing }, Cmd.none )

        CancelNewView ->
            let
                ( dialog, cmd ) =
                    Modal.close model.newView
            in
            plain ( { model | newView = dialog }, Cmd.map NewViewMsg cmd )

        SaveNewView ->
            let
                name =
                    String.trim model.newViewName
            in
            if String.isEmpty name then
                plain ( { model | newViewError = Just "Give the view a name." }, Cmd.none )

            else if viewNamed model.views name /= Nothing then
                plain ( { model | newViewError = Just "A view with this name exists." }, Cmd.none )

            else
                let
                    all =
                        SavedViews.views model.views ++ [ SavedViews.savedView name (FilterBar.rule model.filters) ]

                    ( dialog, cmd ) =
                        Modal.close model.newView
                in
                plain
                    ( { model
                        | newView = dialog
                        , views = model.views |> SavedViews.setViews all |> SavedViews.setActive (Just name)
                      }
                    , Cmd.batch [ Cmd.map NewViewMsg cmd, Api.saveViews env.net all ViewsSaved ]
                    )

        AskShare ->
            let
                ( dialog, cmd ) =
                    Modal.open "" model.share
            in
            plain ( { model | share = dialog }, Cmd.map ShareMsg cmd )

        ShareMsg m ->
            let
                ( dialog, cmd ) =
                    Modal.update m model.share
            in
            plain ( { model | share = dialog }, Cmd.map ShareMsg cmd )


plain : ( Model, Cmd Msg ) -> ( Model, Cmd Msg, Effects Msg )
plain ( model, cmd ) =
    ( model, cmd, Effect.none )


none : Effects Msg
none =
    Effect.none


plural : Int -> String -> String -> String
plural n one other =
    if n == 1 then
        one

    else
        other



-- VIEW


view : Env -> Model -> Html Msg
view env model =
    Layout.stack [ Layout.gap 3 ]
        [ Layout.row [ Layout.gap 2, Layout.wrap ]
            [ SavedViews.view ViewsMsg
                [ SavedViews.current (FilterBar.rule model.filters), SavedViews.size Theme.Small ]
                model.views
            , Button.iconOnly
                [ Button.ghost
                , Button.small
                , Button.disabled (SavedViews.active model.views == Nothing)
                , Button.onClick AskShare
                ]
                Icon.share
                "Share this view"
            , FilterBar.view FiltersMsg
                [ FilterBar.fields (fields env.today people)
                , FilterBar.today env.today
                , FilterBar.label "Order filters"
                , FilterBar.counting model.refreshing
                , FilterBar.matchCount
                    (if Remote.isSuccess model.rows then
                        Just model.total

                     else
                        Nothing
                    )
                ]
                model.filters
            ]
        , Table.view TableMsg (tableAttributes env model) model.table
        ]


tableAttributes : Env -> Model -> List (Table.Attribute OrderId Summary Msg)
tableAttributes env model =
    [ Table.label "Orders"
    , Table.columns columns
    , Table.rows model.rows
    , Table.server { total = model.total }
    , Table.refreshing model.refreshing
    , Table.rowId rowIds .id
    , Table.rowLabel (.id >> orderIdToString)
    , Table.rowTone
        (\order ->
            if isLate env.today order then
                Just Theme.Danger

            else
                Nothing
        )
    , Table.searchable
    , Table.searchPlaceholder "Search orders, customers, people ..."
    , Table.selectable
    , Table.bulkActions
        [ Button.view
            [ Button.small
            , Button.icon Icon.package
            , Button.loading model.packing
            , Button.onClick PackSelected
            ]
            "Mark as packed"
        , Button.view
            [ Button.small
            , Button.id Ids.bulkAssign
            , Button.icon Icon.userPlus
            , Button.onClick AskAssign
            ]
            "Assign to ..."
        ]
    , Table.exportCsv "orders.csv"
    , Table.onRowClick RowClicked
    , Table.onRetry Retry
    , Table.onRefresh Reload
    , Table.onResetFilters ResetFilters
    , Table.activeExternalFilters (Rule.conditionCount (FilterBar.rule model.filters))
    , Table.pageSizes [ 50, 100, 200 ]
    , Table.columnChooser
    , Table.densityToggle
    , Table.maxHeight 620
    , Table.emptyState
        [ EmptyState.title "No orders"
        , EmptyState.description "There are no orders to pick, pack or ship right now."
        ]
    ]


columns : List (Table.Column Summary Msg)
columns =
    [ Table.text colNumber "Order" (.id >> orderIdToString) [ Table.pinned, Table.width 120 ]
    , Table.text colCustomer "Customer" .customer [ Table.minWidth 180 ]
    , Table.badge colStatus
        "Status"
        (\order -> ( statusTone order.status, statusLabel order.status ))
        []
    , Table.date colCreated "Created" .created []
    , Table.date colDue "Due" .due []
    , Table.float colTotal "Total" 2 .total []
    , Table.text colAssignee "Assigned to" (.assignee >> assigneeName people) []
    ]


{-| The dialogs of the inbox, for the overlays of the shell.
-}
overlays : Env -> Model -> List (Html Msg)
overlays env model =
    [ ConfirmDialog.view AssignDialogMsg
        [ ConfirmDialog.title ("Assign " ++ selectionText model ++ "?")
        , ConfirmDialog.message "The person will see them in their own queue."
        , ConfirmDialog.body
            [ Select.view AssignSelectMsg
                [ Select.label "Assign to"
                , Select.options (List.map (\p -> Select.option p.id p.name) people)
                , Select.placeholder "Choose a person ..."
                , Select.errorMaybe model.assignError
                ]
                model.assignPerson
            ]
        , ConfirmDialog.confirmLabel "Assign"
        , ConfirmDialog.onConfirm ConfirmAssign
        , ConfirmDialog.onCancel CancelAssign
        ]
        model.assign
    , Modal.view NewViewMsg
        [ Modal.title "New saved view"
        , Modal.subtitle "Saves the filters that are on now."
        , Modal.small
        , Modal.footer
            [ Button.view [ Button.onClick CancelNewView ] "Cancel"
            , Button.view [ Button.primary, Button.onClick SaveNewView ] "Save view"
            ]
        ]
        model.newView
        [ TextInput.view
            [ TextInput.id Ids.newViewName
            , TextInput.label "Name"
            , TextInput.value model.newViewName
            , TextInput.onInput NewViewNameChanged
            , TextInput.onEnter SaveNewView
            , TextInput.errorMaybe model.newViewError
            ]
        ]
    , -- KLAR GAP: no way to copy a link without ports, and nothing in Klar shows a link for copying
      Modal.view ShareMsg
        [ Modal.title "Share this view"
        , Modal.small
        ]
        model.share
        [ case SavedViews.active model.views of
            Nothing ->
                Text.paragraph "Choose a saved view first."

            Just active ->
                Layout.stack [ Layout.gap 2 ]
                    [ Text.paragraph ("Anyone who opens this link gets the view \"" ++ active.name ++ "\".")
                    , Text.mono (env.baseUrl ++ "#/orders?view=" ++ Url.percentEncode active.name)
                    ]
        ]
    ]


selectionText : Model -> String
selectionText model =
    let
        n =
            Table.selectedCount model.total model.table
    in
    String.fromInt n ++ plural n " order" " orders"


{-| Is one of the inbox's dialogs open?
-}
isBlocking : Model -> Bool
isBlocking model =
    ConfirmDialog.isOpen model.assign || Modal.isOpen model.newView || Modal.isOpen model.share
