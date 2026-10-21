module Page.Orders exposing (Model, Msg, confirmLeave, init, reenter, routeLeft, subscriptions, takeEffects, update, view)

{-| Orders: the main data-entry page of the showcase.

The list is searched, filtered by status, sorted and paged on the server. Every
change in the table becomes a request that carries a ticket, and the page shows
loading, failure (with retry) and the previous rows, dimmed, while a new page is
on its way; an answer to an older request is ignored.

An order is created and edited in a drawer with the full form (`Page.Orders.Editor`).
The server's validation messages are shown on the fields and in a summary, and
closing the drawer with unsaved changes asks first. An order that has shipped is
shown, not edited. The row menu changes the status of an order, or deletes it; the
two things that cannot be undone ask first, and so does cancelling the selected
rows from the bulk bar.

`#/orders/ORD-10001` opens the editor of that order.

If you are here to see how a component is used:

  - the table in server mode: `columns` and `view`, and `toOrderQuery` and `fetch`
    for the road from what the table asked for to a request and back
  - the menu of a row: `rowActions`
  - the drawer and its form: `viewEditor` and `Page.Orders.Editor`
  - the dialogs: `viewDiscard` and `viewConfirm`
  - the shell around the page (the address, shortcuts that leave the page, the
    toasts): `init`, `reenter`, `confirmLeave`, `routeLeft` and the effects, which
    `Main` calls and carries out

-}

import Api exposing (Backend)
import Api.Problem as Problem
import Api.Types as Types exposing (ApiError(..), Lookups, Order, OrderId, OrderQuery, OrderStatus(..), Page)
import Html exposing (Html)
import Klar.Alert as Alert
import Klar.Button as Button
import Klar.ConfirmDialog as ConfirmDialog
import Klar.Date as Date exposing (Date)
import Klar.Drawer as Drawer
import Klar.EmptyState as EmptyState
import Klar.Form as Form
import Klar.Format as Format
import Klar.Icon as Icon
import Klar.Layout as Layout
import Klar.Menu as Menu
import Klar.PageHeader as PageHeader
import Klar.Remote as Remote exposing (Remote)
import Klar.Table as Table
import Klar.Theme exposing (Tone(..))
import Page.Effect as Effect exposing (Context, Effect(..))
import Page.Orders.Editor as Editor
import Route
import View.Labels as Labels



-- MODEL


type alias Model =
    { table : Table.State
    , rows : Remote (List Order)
    , total : Int
    , refreshing : Bool

    -- Counts the requests for rows. An answer carries the number it was asked
    -- with, and is dropped when a newer request has been made since.
    , ticket : Int
    , lookups : Remote Lookups
    , drawer : Drawer.State
    , editing : Maybe Editor.Editor

    -- The order the address asked for (`#/orders/ORD-10001`) while its editor
    -- is waiting to open or open. Closing it takes the address back to the list.
    , routeOpened : Maybe OrderId
    , discard : ConfirmDialog.State

    -- One dialog for the two things that cannot be undone. `pending` says which.
    , confirm : ConfirmDialog.State
    , pending : Maybe Pending

    -- The bulk action is looking up the rows behind "Select all N matching".
    , resolving : Bool
    , effects : Effect.Outbox
    }


{-| What the confirmation dialog is about.
-}
type Pending
    = Deleting Order
    | Cancelling Batch


{-| Orders to cancel, one request each, and the answers that have come back.
-}
type alias Batch =
    { ids : List OrderId
    , answers : List ( OrderId, Result ApiError () )
    }


tableId : String
tableId =
    "orders-table"


drawerId : String
drawerId =
    "order-editor"


newOrderButtonId : String
newOrderButtonId =
    "orders-new"


cancelSelectedId : String
cancelSelectedId =
    "orders-cancel-selected"


{-| Where focus goes when the editor closes after it was opened by the address:
nothing on the page opened it, so the start of the list, its search box.
`Klar.Table` makes the id from the id of the table (see `Table.init`).
-}
searchBoxId : String
searchBoxId =
    tableId ++ "-search"


{-| The table the first time: newest orders first, so that a new order is found at
the start of the list.
-}
initialTable : Table.State
initialTable =
    Table.init tableId
        |> Table.setSort [ ( Table.columnId "created", Table.Descending ) ]


init : Context -> Maybe OrderId -> Backend -> ( Model, Backend, Cmd Msg )
init context openId backend =
    start 1 initialTable context openId backend


{-| Coming back to the page: what the user chose in the table (search, filters,
sort order, page size and page) is still there, so the list looks the way it was
left. The rows and the reference data are fetched again, and no row stays selected.

The ticket goes on counting: an answer to a request from the last visit (which
may have asked for something else) must not be taken for the answer to this one.

-}
reenter : Context -> Maybe OrderId -> Backend -> Model -> ( Model, Backend, Cmd Msg )
reenter context openId backend previous =
    start (previous.ticket + 1) (Table.clearSelection previous.table) context openId backend


start : Int -> Table.State -> Context -> Maybe OrderId -> Backend -> ( Model, Backend, Cmd Msg )
start ticket table _ openId backend =
    let
        ( backend1, listCmd ) =
            Api.listOrders (toOrderQuery (Table.query table)) (Loaded ticket) backend

        ( backend2, lookupsCmd ) =
            Api.lookups LookupsLoaded backend1

        ( backend3, openCmd ) =
            case openId of
                Just id ->
                    Api.getOrder id (DeepLinkLoaded id) backend2

                Nothing ->
                    ( backend2, Cmd.none )
    in
    ( { table = table
      , rows = Remote.Loading
      , total = 0
      , refreshing = False
      , ticket = ticket
      , lookups = Remote.Loading
      , drawer = Drawer.init drawerId
      , editing = Nothing
      , routeOpened = openId
      , discard = ConfirmDialog.init "order-discard"
      , confirm = ConfirmDialog.init "order-confirm"
      , pending = Nothing
      , resolving = False
      , effects = Effect.empty
      }
    , backend3
    , Cmd.batch [ listCmd, lookupsCmd, openCmd ]
    )


{-| The order the address names arrived (or could not be fetched).
-}
deepLinkLoaded : Context -> Result ApiError Order -> Backend -> Model -> ( Model, Backend, Cmd Msg )
deepLinkLoaded context result backend model =
    case result of
        Ok order ->
            let
                ( opened, cmd ) =
                    openEditor searchBoxId (Editor.ExistingOrder order) model
            in
            ( opened, backend, cmd )

        Err error ->
            -- The address names an order that cannot be shown: say why, and go
            -- back to the list so that the address matches what is on screen.
            let
                notice =
                    case error of
                        NotFound ->
                            Notify Danger "Order not found" "There is no order with that id, or it has been deleted."

                        _ ->
                            Notify Danger "Could not open the order" (reason context error ++ " Choose the order in the list to try again.")
            in
            ( { model
                | routeOpened = Nothing
                , effects = model.effects |> Effect.push notice |> Effect.push (Replace Route.Orders)
              }
            , backend
            , Cmd.none
            )


{-| The effects the last update left for `Main` to carry out.
-}
takeEffects : Model -> ( Model, Effect.Outbox )
takeEffects =
    Effect.take


{-| What the table asked for, as the server wants it. The status filter holds
status labels.
-}
toOrderQuery : Table.Query -> OrderQuery
toOrderQuery query =
    { search = query.search
    , statuses =
        query.filters
            |> List.filter (\( column, _ ) -> Table.columnName column == "status")
            |> List.concatMap
                (\( _, filter ) ->
                    case filter of
                        Table.OneOf labels ->
                            List.filter (\status -> List.member (Types.orderStatusLabel status) labels) Types.allOrderStatuses

                        _ ->
                            []
                )
    , sort =
        query.sort
            |> List.head
            |> Maybe.map (\( column, direction ) -> ( Table.columnName column, direction == Table.Ascending ))
    , page = query.page
    , pageSize = query.pageSize
    }



-- UPDATE


type Msg
    = Loaded Int (Result ApiError (Page Order))
    | LookupsLoaded (Result ApiError Lookups)
    | DeepLinkLoaded OrderId (Result ApiError Order)
    | Reload
    | RetryLookups
    | TableMsg Table.Msg
      -- the editor
    | NewClicked
    | EditClicked Order
    | DrawerMsg Drawer.Msg
    | EditorMsg Editor.Msg
    | RequestClose
    | DiscardMsg ConfirmDialog.Msg
    | DiscardConfirmed
    | DiscardCancelled
    | Submit
    | Retry
    | Saved (Result ApiError Order)
    | FocusField String
      -- from the row menu and the bulk bar
    | ChangeStatus Order OrderStatus
    | StatusChanged Order OrderStatus (Result ApiError Order)
    | AskDelete Order
    | AskCancel Order
    | CancelSelected
    | MatchingLoaded Int (List OrderId) (Result ApiError (Page Order))
    | ConfirmMsg ConfirmDialog.Msg
    | ConfirmAccepted
    | ConfirmDismissed
    | Deleted OrderId (Result ApiError ())
    | CancelAnswered OrderId (Result ApiError Order)
    | NoOp


update : Context -> Msg -> Backend -> Model -> ( Model, Backend, Cmd Msg )
update context msg backend model =
    case msg of
        NoOp ->
            ( model, backend, Cmd.none )

        Loaded ticket result ->
            if ticket /= model.ticket then
                ( model, backend, Cmd.none )

            else
                case result of
                    Ok page ->
                        ( { model
                            | rows = Remote.Success page.rows
                            , total = page.total
                            , refreshing = False

                            -- The server shows the last page when asked for one
                            -- past the end (after the last row of a page was
                            -- deleted, say): the table follows.
                            , table = Table.setPage page.page model.table
                          }
                        , backend
                        , Cmd.none
                        )

                    Err error ->
                        ( { model | rows = Remote.Failure (Problem.toProblem error), refreshing = False }
                        , backend
                        , Cmd.none
                        )

        LookupsLoaded result ->
            ( { model | lookups = Remote.fromResult (Result.mapError Problem.toProblem result) }
            , backend
            , Cmd.none
            )

        DeepLinkLoaded id result ->
            if model.routeOpened == Just id && not (isEditing model) then
                deepLinkLoaded context result backend model

            else
                -- The answer to an address from an earlier visit, or to one that
                -- was opened in the meantime: the address no longer asks for it.
                ( model, backend, Cmd.none )

        Reload ->
            let
                ( fetched, backend1, listCmd ) =
                    fetch backend model

                ( withLookups, backend2, lookupsCmd ) =
                    loadMissingLookups backend1 fetched
            in
            ( withLookups, backend2, Cmd.batch [ listCmd, lookupsCmd ] )

        RetryLookups ->
            let
                ( backend1, cmd ) =
                    Api.lookups LookupsLoaded backend
            in
            ( { model | lookups = Remote.Loading }
            , backend1
            , if isEditing model then
                -- A select in the form asked: it looks after its own focus.
                cmd

              else
                -- The button of the notice above the table is about to go away
                -- with the notice: focus waits in the table.
                Cmd.batch [ cmd, Cmd.map TableMsg (Table.focus model.table) ]
            )

        TableMsg inner ->
            let
                ( table, cmd ) =
                    Table.update inner model.table

                next =
                    { model | table = table }
            in
            -- Sorting, paging, searching and filtering change the query. Anything
            -- else (a menu, the column chooser, a selection) does not.
            if Table.query table /= Table.query model.table then
                let
                    ( fetched, backend1, fetchCmd ) =
                        fetch backend next
                in
                ( fetched, backend1, Cmd.batch [ Cmd.map TableMsg cmd, fetchCmd ] )

            else
                ( next, backend, Cmd.map TableMsg cmd )

        NewClicked ->
            let
                ( opened, cmd ) =
                    openEditor newOrderButtonId Editor.NewOrder model
            in
            ( opened, backend, cmd )

        EditClicked order ->
            let
                ( opened, cmd ) =
                    openEditor (rowDomId model order.id) (Editor.ExistingOrder order) model
            in
            ( opened, backend, cmd )

        DrawerMsg inner ->
            let
                ( drawer, cmd ) =
                    Drawer.update inner model.drawer
            in
            ( { model | drawer = drawer }, backend, Cmd.map DrawerMsg cmd )

        EditorMsg inner ->
            case model.editing of
                Just editor ->
                    let
                        ( next, cmd ) =
                            Editor.update inner editor
                    in
                    ( { model | editing = Just next }, backend, Cmd.map EditorMsg cmd )

                Nothing ->
                    ( model, backend, Cmd.none )

        RequestClose ->
            -- The close button, Escape, the backdrop and "Cancel".
            case model.editing of
                Just editor ->
                    if Editor.isDirty editor then
                        let
                            ( asked, cmd ) =
                                askDiscard model
                        in
                        ( asked, backend, cmd )

                    else
                        let
                            ( closed, cmd ) =
                                closeEditor model
                        in
                        ( closed, backend, cmd )

                Nothing ->
                    ( model, backend, Cmd.none )

        DiscardMsg inner ->
            let
                ( discard, cmd ) =
                    ConfirmDialog.update inner model.discard
            in
            ( { model | discard = discard }, backend, Cmd.map DiscardMsg cmd )

        DiscardConfirmed ->
            let
                -- The drawer goes too, so focus goes where the drawer sends it,
                -- not back into the drawer: the command of the dialog is dropped.
                ( discard, _ ) =
                    ConfirmDialog.close model.discard

                ( closed, cmd ) =
                    closeEditor { model | discard = discard }
            in
            ( closed, backend, cmd )

        DiscardCancelled ->
            let
                ( discard, cmd ) =
                    ConfirmDialog.close model.discard
            in
            ( { model | discard = discard }, backend, Cmd.map DiscardMsg cmd )

        Submit ->
            case model.editing of
                Just editor ->
                    submit context backend editor model

                Nothing ->
                    ( model, backend, Cmd.none )

        Retry ->
            -- "Try again" in the status line is replaced by "Saving ..." the
            -- moment it is pressed: focus moves to the status line, which stays.
            let
                ( next, backend1, cmd ) =
                    update context Submit backend model
            in
            ( next, backend1, Cmd.batch [ cmd, Form.focusStatus Editor.formId NoOp ] )

        Saved (Ok order) ->
            let
                created =
                    model.editing |> Maybe.map Editor.isNew |> Maybe.withDefault False

                ( closed, closeCmd ) =
                    closeEditor model

                -- A new order is found at the start of the list.
                table =
                    if created then
                        Table.setPage 1 closed.table

                    else
                        closed.table

                ( fetched, backend1, fetchCmd ) =
                    fetch backend { closed | table = table }

                notice =
                    if created then
                        Notify Success "Order created" (order.id ++ " was added as a draft for " ++ order.customer ++ ".")

                    else
                        Notify Success "Order saved" (order.id ++ " was updated.")
            in
            -- `fetched` keeps the effects of `closeEditor` (back to the list
            -- when the order was opened by its address).
            ( { fetched | effects = Effect.push notice fetched.effects }
            , backend1
            , Cmd.batch [ closeCmd, fetchCmd ]
            )

        Saved (Err error) ->
            case ( model.editing, error ) of
                ( Just _, ValidationFailed errors ) ->
                    -- The server's messages go to the fields they are about and
                    -- into the summary, which takes the focus.
                    ( editWith (\editor -> { editor | submit = Form.Idle, errors = errors }) model
                    , backend
                    , Form.focusSummary Editor.formId NoOp
                    )

                ( Just _, _ ) ->
                    -- The status line in the footer says what went wrong, and
                    -- offers to try again.
                    ( editWith (\editor -> { editor | submit = Form.Failed (Problem.toProblem error) }) model
                    , backend
                    , Cmd.none
                    )

                ( Nothing, _ ) ->
                    -- The editor was gone before the answer came.
                    ( { model | effects = Effect.push (Notify Danger "The order was not saved" (reason context error)) model.effects }
                    , backend
                    , Cmd.none
                    )

        FocusField id ->
            ( model, backend, Form.focusField id NoOp )

        ChangeStatus order status ->
            let
                ( backend1, cmd ) =
                    Api.changeStatus order.id status (StatusChanged order status) backend
            in
            ( model, backend1, cmd )

        StatusChanged order status (Ok _) ->
            let
                ( fetched, backend1, cmd ) =
                    fetch backend model

                notice =
                    Notify Success "Status changed" (order.id ++ " is now " ++ String.toLower (Types.orderStatusLabel status) ++ ".")
            in
            ( { fetched | effects = Effect.push notice fetched.effects }, backend1, cmd )

        StatusChanged order _ (Err error) ->
            let
                notice =
                    Notify Danger ("Could not change " ++ order.id) (reason context error)
            in
            -- The server refuses what the order's status does not allow. That
            -- means the row on screen is out of date: show the real one.
            if isOutOfDate error then
                let
                    ( fetched, backend1, cmd ) =
                        fetch backend model
                in
                ( { fetched | effects = Effect.push notice fetched.effects }, backend1, cmd )

            else
                ( { model | effects = Effect.push notice model.effects }, backend, Cmd.none )

        AskDelete order ->
            let
                ( asked, cmd ) =
                    openConfirm (rowDomId model order.id) (Deleting order) model
            in
            ( asked, backend, cmd )

        AskCancel order ->
            let
                ( asked, cmd ) =
                    askCancel (rowDomId model order.id) [ order.id ] model
            in
            ( asked, backend, cmd )

        CancelSelected ->
            if model.resolving then
                ( model, backend, Cmd.none )

            else
                case Table.selection model.table of
                    Table.Selected ids ->
                        let
                            ( asked, cmd ) =
                                askCancel cancelSelectedId ids model
                        in
                        ( asked, backend, cmd )

                    Table.AllMatching { except } ->
                        -- "Select all N matching": the table never received
                        -- those rows, so ask the server for all of them.
                        let
                            query =
                                toOrderQuery (Table.query model.table)

                            ( backend1, cmd ) =
                                Api.listOrders { query | page = 1, pageSize = max 1 model.total } (MatchingLoaded model.ticket except) backend
                        in
                        ( { model | resolving = True }, backend1, cmd )

        MatchingLoaded ticket except result ->
            let
                released =
                    { model | resolving = False }
            in
            if ticket /= model.ticket then
                -- The table asked for other rows meanwhile: these are not the
                -- ones the user chose.
                ( released, backend, Cmd.none )

            else
                case result of
                    Ok page ->
                        let
                            ids =
                                page.rows
                                    |> List.map .id
                                    |> List.filter (\id -> not (List.member id except))

                            ( asked, cmd ) =
                                askCancel cancelSelectedId ids released
                        in
                        ( asked, backend, cmd )

                    Err error ->
                        ( { released | effects = Effect.push (Notify Danger "Could not select the orders" (reason context error)) released.effects }
                        , backend
                        , Cmd.none
                        )

        ConfirmMsg inner ->
            let
                ( confirm, cmd ) =
                    ConfirmDialog.update inner model.confirm
            in
            ( { model | confirm = confirm }, backend, Cmd.map ConfirmMsg cmd )

        ConfirmAccepted ->
            -- "Delete order", "Cancel orders", and "Try again" after a failure.
            case model.pending of
                Just (Deleting order) ->
                    let
                        ( backend1, cmd ) =
                            Api.deleteOrder order.id (Deleted order.id) backend
                    in
                    ( { model | confirm = ConfirmDialog.setBusy model.confirm }, backend1, cmd )

                Just (Cancelling batch) ->
                    -- One request for each order, all at once.
                    let
                        ( backend1, cmds ) =
                            List.foldl
                                (\id ( current, sent ) ->
                                    let
                                        ( next, cmd ) =
                                            Api.changeStatus id Cancelled (CancelAnswered id) current
                                    in
                                    ( next, cmd :: sent )
                                )
                                ( backend, [] )
                                batch.ids
                    in
                    ( { model
                        | confirm = ConfirmDialog.setBusy model.confirm
                        , pending = Just (Cancelling { batch | answers = [] })
                      }
                    , backend1
                    , Cmd.batch cmds
                    )

                Nothing ->
                    ( model, backend, Cmd.none )

        ConfirmDismissed ->
            -- The button, the close button, Escape and the backdrop. Nothing
            -- can close the dialog while a request runs, but an event from the
            -- frame before it was drawn that way can still arrive.
            if ConfirmDialog.isBusy model.confirm then
                ( model, backend, Cmd.none )

            else
                let
                    ( confirm, cmd ) =
                        ConfirmDialog.close model.confirm

                    closed =
                        { model | confirm = confirm, pending = Nothing }
                in
                case ConfirmDialog.problem model.confirm of
                    Just problem ->
                        -- A refusal means that the data changed in the meantime:
                        -- let the list show how things are now.
                        if Remote.isRetryable problem then
                            ( closed, backend, Cmd.map ConfirmMsg cmd )

                        else
                            let
                                ( fetched, backend1, fetchCmd ) =
                                    fetch backend closed
                            in
                            ( fetched, backend1, Cmd.batch [ Cmd.map ConfirmMsg cmd, fetchCmd ] )

                    Nothing ->
                        ( closed, backend, Cmd.map ConfirmMsg cmd )

        Deleted id (Ok ()) ->
            let
                -- The row is gone, and with it the button the dialog would
                -- give focus back to: focus goes to the table instead.
                ( confirm, _ ) =
                    ConfirmDialog.close model.confirm

                -- A deleted order cannot stay selected.
                table =
                    Table.setSelected [ id ] False model.table

                ( fetched, backend1, fetchCmd ) =
                    fetch backend { model | confirm = confirm, pending = Nothing, table = table }
            in
            ( { fetched | effects = Effect.push (Notify Success "Order deleted" (id ++ " was removed.")) fetched.effects }
            , backend1
            , Cmd.batch [ fetchCmd, Cmd.map TableMsg (Table.focus fetched.table) ]
            )

        Deleted _ (Err error) ->
            -- The reason (a refusal says what is wrong with the order) is shown
            -- inside the dialog, which stays open.
            ( { model | confirm = ConfirmDialog.setFailed (Problem.toProblem error) model.confirm }
            , backend
            , Cmd.none
            )

        CancelAnswered id result ->
            case model.pending of
                Just (Cancelling batch) ->
                    let
                        answered =
                            { batch | answers = ( id, Result.map (\_ -> ()) result ) :: batch.answers }
                    in
                    if List.length answered.answers < List.length answered.ids then
                        ( { model | pending = Just (Cancelling answered) }, backend, Cmd.none )

                    else
                        finishCancelling context answered backend model

                _ ->
                    ( model, backend, Cmd.none )


{-| Everything the server said about cancelling the orders has arrived.

If not one order was cancelled, the dialog stays and shows why. Otherwise it
closes, the orders that are still not cancelled because the request failed stay
selected (the others are not selectable any more or were refused for good), and a
notice tells how it went.

-}
finishCancelling : Context -> Batch -> Backend -> Model -> ( Model, Backend, Cmd Msg )
finishCancelling context batch backend model =
    let
        cancelled =
            List.filterMap
                (\( id, result ) ->
                    case result of
                        Ok () ->
                            Just id

                        Err _ ->
                            Nothing
                )
                batch.answers

        errors =
            List.filterMap
                (\( id, result ) ->
                    case result of
                        Err error ->
                            Just ( id, error )

                        Ok () ->
                            Nothing
                )
                batch.answers

        -- The server said no, and would say it again: the order has shipped or
        -- is gone. Everything else (no contact, a server error) may work next time.
        refused =
            List.filter (\( _, error ) -> isOutOfDate error) errors

        failed =
            List.filter (\( _, error ) -> not (isOutOfDate error)) errors
    in
    case ( cancelled, errors ) of
        ( [], ( _, error ) :: _ ) ->
            ( { model | confirm = ConfirmDialog.setFailed (Problem.toProblem error) model.confirm }
            , backend
            , Cmd.none
            )

        _ ->
            let
                -- The bulk bar goes with the selection and takes the button that
                -- opened the dialog with it: focus goes to the table.
                ( confirm, _ ) =
                    ConfirmDialog.close model.confirm

                table =
                    model.table
                        |> Table.clearSelection
                        |> Table.setSelected (List.map Tuple.first failed) True

                ( fetched, backend1, fetchCmd ) =
                    fetch backend { model | confirm = confirm, pending = Nothing, table = table }
            in
            ( { fetched | effects = Effect.push (cancelNotice context cancelled (List.length refused) (List.length failed)) fetched.effects }
            , backend1
            , Cmd.batch [ fetchCmd, Cmd.map TableMsg (Table.focus fetched.table) ]
            )


{-| How it went: the orders that were cancelled, how many the server refused, and
how many did not get an answer.
-}
cancelNotice : Context -> List OrderId -> Int -> Int -> Effect
cancelNotice context cancelled refused failed =
    let
        count n =
            Format.int context.locale n
    in
    if refused == 0 && failed == 0 then
        case cancelled of
            [ id ] ->
                Notify Success "Order cancelled" (id ++ " was cancelled.")

            _ ->
                Notify Success
                    "Orders cancelled"
                    (count (List.length cancelled) ++ " orders cancelled.")

    else
        Notify Warning
            "Not every order was cancelled"
            (String.join " "
                (List.filterMap identity
                    [ Just (count (List.length cancelled) ++ " cancelled.")
                    , if refused > 0 then
                        Just (count refused ++ " could not be cancelled (shipped or finished).")

                      else
                        Nothing
                    , if failed > 0 then
                        Just
                            (count failed
                                ++ " failed because of a network or server problem; "
                                ++ (if failed == 1 then
                                        "it is"

                                    else
                                        "they are"
                                   )
                                ++ " still selected."
                            )

                      else
                        Nothing
                    ]
                )
            )


{-| The form was submitted: by "Save", or by Enter in a field.
-}
submit : Context -> Backend -> Editor.Editor -> Model -> ( Model, Backend, Cmd Msg )
submit context backend editor model =
    if editor.submit == Form.Submitting || not (Editor.isEditable editor) then
        -- Enter in a field while the save is under way, or in an order that
        -- cannot be changed.
        ( model, backend, Cmd.none )

    else
        let
            settled =
                Editor.settle context editor

            problems =
                Editor.localProblems settled
        in
        if not (List.isEmpty problems) then
            -- The controls already say what is wrong; there is nothing to ask
            -- the server. The summary covers them all, and takes the focus.
            ( { model | editing = Just { settled | errors = problems } }
            , backend
            , Form.focusSummary Editor.formId NoOp
            )

        else
            let
                input =
                    Editor.toInput settled

                ( backend1, cmd ) =
                    case settled.target of
                        Editor.NewOrder ->
                            Api.createOrder input Saved backend

                        Editor.ExistingOrder order ->
                            Api.updateOrder order.id input Saved backend
            in
            ( { model | editing = Just { settled | submit = Form.Submitting, errors = [] } }, backend1, cmd )


{-| Asks the server for the rows the table currently wants. Rows already on screen
stay (dimmed) until the answer arrives; an answer to an older question is ignored.
-}
fetch : Backend -> Model -> ( Model, Backend, Cmd Msg )
fetch backend model =
    let
        ticket =
            model.ticket + 1

        ( backend1, cmd ) =
            Api.listOrders (toOrderQuery (Table.query model.table)) (Loaded ticket) backend

        hasRows =
            Remote.isSuccess model.rows
    in
    ( { model
        | ticket = ticket
        , refreshing = hasRows
        , rows =
            if hasRows then
                model.rows

            else
                Remote.Loading
      }
    , backend1
    , cmd
    )


{-| Asks again for the reference data when it failed to load; what has loaded is
left alone.
-}
loadMissingLookups : Backend -> Model -> ( Model, Backend, Cmd Msg )
loadMissingLookups backend model =
    if Remote.isSuccess model.lookups then
        ( model, backend, Cmd.none )

    else
        let
            ( backend1, cmd ) =
                Api.lookups LookupsLoaded backend
        in
        ( { model | lookups = Remote.Loading }, backend1, cmd )


isEditing : Model -> Bool
isEditing model =
    case model.editing of
        Just _ ->
            True

        Nothing ->
            False


{-| A change by the user to the editor's state that is not a field (the status of
the submit, the server's complaints).
-}
editWith : (Editor.Editor -> Editor.Editor) -> Model -> Model
editWith change model =
    { model | editing = Maybe.map change model.editing }


{-| What to tell the user about a failed request: the server's own words when it
has some (a refusal says why), otherwise what kind of trouble it was.
-}
reason : Context -> ApiError -> String
reason context error =
    let
        problem =
            Problem.toProblem error
    in
    Maybe.withDefault (Remote.title context.locale problem) (Remote.detail context.locale problem)


{-| The server refused because of how things are now, not because the request was
lost: the order is in another status than the list says, or it is gone. Trying
again gives the same answer.
-}
isOutOfDate : ApiError -> Bool
isOutOfDate error =
    case error of
        Conflict _ ->
            True

        NotFound ->
            True

        _ ->
            False



-- EDITOR, DIALOGS AND FOCUS


{-| `opener` is the DOM id that gets focus back when the drawer closes.
-}
openEditor : String -> Editor.Target -> Model -> ( Model, Cmd Msg )
openEditor opener target model =
    let
        editor =
            Editor.init target

        -- An order that cannot be changed has no field to start in: the drawer
        -- itself takes focus, and a screen reader reads its title.
        focus =
            if Editor.isEditable editor then
                [ Editor.firstFieldId ]

            else
                []

        ( drawer, cmd ) =
            Drawer.openWith { opener = opener, focus = focus } model.drawer
    in
    ( { model | drawer = drawer, editing = Just editor }, Cmd.map DrawerMsg cmd )


closeEditor : Model -> ( Model, Cmd Msg )
closeEditor model =
    let
        ( drawer, cmd ) =
            Drawer.close model.drawer
    in
    ( { model
        | drawer = drawer
        , editing = Nothing
        , routeOpened = Nothing
        , effects =
            case model.routeOpened of
                Just _ ->
                    Effect.push (Go Route.Orders) model.effects

                Nothing ->
                    model.effects
      }
    , Cmd.map DrawerMsg cmd
    )


{-| "Discard changes?" From it, "Keep editing" gives focus back to the close
button of the drawer.
-}
askDiscard : Model -> ( Model, Cmd Msg )
askDiscard model =
    let
        ( discard, cmd ) =
            ConfirmDialog.open (Drawer.closeButtonId model.drawer) model.discard
    in
    ( { model | discard = discard }, Cmd.map DiscardMsg cmd )


openConfirm : String -> Pending -> Model -> ( Model, Cmd Msg )
openConfirm opener pending model =
    let
        ( confirm, cmd ) =
            ConfirmDialog.open opener model.confirm
    in
    ( { model | confirm = confirm, pending = Just pending }, Cmd.map ConfirmMsg cmd )


askCancel : String -> List OrderId -> Model -> ( Model, Cmd Msg )
askCancel opener ids model =
    case ids of
        [] ->
            ( model, Cmd.none )

        _ ->
            openConfirm opener (Cancelling { ids = ids, answers = [] }) model


{-| The table row that shows this order, so that focus can go back to it when a
dialog or the editor closes. `Klar.Table` gives row number `n` of the page (the
first is 0) the DOM id `<table id>-row-<n>`. Without the row on screen: `""`.
-}
rowDomId : Model -> OrderId -> String
rowDomId model id =
    case model.rows of
        Remote.Success rows ->
            rows
                |> List.indexedMap Tuple.pair
                |> List.filter (\( _, order ) -> order.id == id)
                |> List.head
                |> Maybe.map (\( index, _ ) -> tableId ++ "-row-" ++ String.fromInt index)
                |> Maybe.withDefault ""

        _ ->
            ""


{-| The application is about to leave the page (a keyboard shortcut, the command
palette). With unsaved changes in the editor it should stay: this asks "Discard
changes?" instead and returns the page to show. It also stays while a request is
on its way, and while a question is open.
-}
confirmLeave : Model -> Maybe ( Model, Cmd Msg )
confirmLeave model =
    if ConfirmDialog.isOpen model.confirm then
        Just ( model, Cmd.none )

    else
        case model.editing of
            Just editor ->
                if editor.submit == Form.Submitting then
                    Just ( model, Cmd.none )

                else if not (Editor.isDirty editor) then
                    Nothing

                else if ConfirmDialog.isOpen model.discard then
                    Just ( model, Cmd.none )

                else
                    Just (askDiscard model)

            Nothing ->
                Nothing


{-| The address went back from `#/orders/ORD-10001` to `#/orders` (the browser's
back button, or the page's own return to the list): close the editor, unless that
would throw away changes; then it stays open and closing it later asks first, as
usual.
-}
routeLeft : Model -> ( Model, Cmd Msg )
routeLeft model =
    let
        unrouted =
            { model | routeOpened = Nothing }
    in
    case model.editing of
        Just editor ->
            if Editor.isDirty editor || editor.submit == Form.Submitting then
                ( unrouted, Cmd.none )

            else
                let
                    ( drawer, cmd ) =
                        Drawer.close model.drawer
                in
                ( { unrouted | drawer = drawer, editing = Nothing }, Cmd.map DrawerMsg cmd )

        Nothing ->
            ( unrouted, Cmd.none )


subscriptions : Model -> Sub Msg
subscriptions _ =
    Sub.none



-- VIEW


view : Context -> Model -> Effect.View Msg
view context model =
    let
        lookups =
            Remote.withDefault noLookups model.lookups
    in
    { content =
        Layout.stack [ Layout.gap 5 ]
            [ PageHeader.view
                [ PageHeader.title "Orders"
                , PageHeader.subtitle "Search, filter and sort the orders. Click a row to open it. Open orders past their due date have a red edge."
                , PageHeader.meta
                    [ PageHeader.metaItem "Results"
                        (case model.rows of
                            Remote.Success _ ->
                                Format.int context.locale model.total

                            -- Not "0" while the first answer is on its way or failed.
                            _ ->
                                "–"
                        )
                    ]
                , PageHeader.actions
                    [ Button.view
                        [ Button.primary
                        , Button.icon Icon.plus
                        , Button.id newOrderButtonId
                        , Button.onClick NewClicked
                        ]
                        "New order"
                    ]
                ]
            , viewLookupsProblem context model
            , Table.view TableMsg
                [ Table.label "Orders"
                , Table.locale context.locale
                , Table.columns (columns context lookups)
                , Table.rows model.rows
                , Table.server { total = model.total }
                , Table.refreshing model.refreshing
                , Table.rowId .id
                , Table.rowLabel (rowLabel context)
                , Table.rowTone (overdueTone context.today)
                , Table.searchPlaceholder "Search id, customer, city, email, owner or note"
                , Table.onRowClick EditClicked
                , Table.onRetry Reload
                , Table.onRefresh Reload
                , Table.rowActions rowActions
                , Table.bulkActions
                    [ Button.view
                        [ Button.small
                        , Button.secondary
                        , Button.danger
                        , Button.icon Icon.ban
                        , Button.id cancelSelectedId
                        , Button.loading model.resolving
                        , Button.onClick CancelSelected
                        ]
                        "Cancel orders"
                    ]
                , Table.exportCsv "orders.csv"
                , Table.columnChooser
                , Table.densityToggle
                , Table.emptyState
                    [ EmptyState.title "No orders yet"
                    , EmptyState.description "Create the first one with the New order button."
                    ]
                ]
                model.table
            ]
    , overlays =
        [ viewEditor context model
        , viewDiscard context model
        , viewConfirm context model
        ]
    , modalOpen =
        Drawer.isOpen model.drawer
            || ConfirmDialog.isOpen model.discard
            || ConfirmDialog.isOpen model.confirm
    }


{-| The table works without the reference data, but names of countries and
warehouses are missing, and so are the choices in the form. Say so, and offer to
try again.
-}
viewLookupsProblem : Context -> Model -> Html Msg
viewLookupsProblem context model =
    case ( model.rows, model.lookups ) of
        -- The table shows its own failure, and its retry loads the reference
        -- data too: one message is enough.
        ( Remote.Failure _, _ ) ->
            Html.text ""

        ( _, Remote.Failure problem ) ->
            Alert.view
                [ Alert.tone Warning
                , Alert.title "Some information is missing"
                , Alert.actions [ Button.view [ Button.small, Button.onClick RetryLookups ] "Try again" ]
                ]
                ("The names of countries and warehouses, and the choices in the order form, could not be loaded: " ++ String.toLower (Remote.title context.locale problem) ++ ".")

        _ ->
            Html.text ""


noLookups : Lookups
noLookups =
    { countries = [], warehouses = [], owners = [], customers = [] }



-- TABLE


columns : Context -> Lookups -> List (Table.Column Order Msg)
columns context lookups =
    [ -- The ids of the columns are the keys the server sorts by.
      Table.text (Table.columnId "id") "Order id" .id [ Table.pinned, Table.width 112 ]
    , Table.text (Table.columnId "customer") "Customer" .customer [ Table.minWidth 190 ]
    , Table.badge (Table.columnId "status")
        "Status"
        (\order -> ( Labels.statusTone order.status, Types.orderStatusLabel order.status ))
        [ Table.width 120

        -- The table only sees one page, so it cannot know the values in the
        -- column: it is told them.
        , Table.filterOptions (List.map Types.orderStatusLabel Types.allOrderStatuses)
        ]
    , Table.status (Table.columnId "priority")
        "Priority"
        (\order -> ( Labels.priorityTone order.priority, Types.priorityLabel order.priority ))
        [ Table.width 104 ]

    -- A blank text is shown as a dash.
    , Table.text (Table.columnId "owner") "Owner" (\order -> Maybe.withDefault "" order.owner) [ Table.width 136 ]
    , Table.text (Table.columnId "city") "City" .city [ Table.width 128 ]
    , Table.text (Table.columnId "country") "Country" (.country >> countryName lookups) [ Table.width 148 ]
    , Table.text (Table.columnId "warehouse") "Warehouse" (.warehouse >> warehouseName lookups) [ Table.width 148 ]
    , Table.date (Table.columnId "created") "Created" .created []
    , Table.date (Table.columnId "due") "Due" .due []
    , Table.int (Table.columnId "lines") "Lines" .lines [ Table.width 88 ]

    -- The text of the column (used for the CSV export) is the plain number; the
    -- cell shows it as money.
    , Table.float (Table.columnId "total")
        "Total"
        2
        .total
        [ Table.width 124
        , Table.cell (\order -> Html.text (Format.currency context.locale "$" 2 order.total))
        ]
    ]


{-| The orders store the code of the country and the id of the warehouse. Until
the reference data has arrived, the code is shown.
-}
countryName : Lookups -> String -> String
countryName lookups code =
    lookups.countries
        |> List.filter (\country -> country.code == code)
        |> List.head
        |> Maybe.map .name
        |> Maybe.withDefault code


warehouseName : Lookups -> String -> String
warehouseName lookups id =
    lookups.warehouses
        |> List.filter (\warehouse -> warehouse.id == id)
        |> List.head
        |> Maybe.map .name
        |> Maybe.withDefault id


{-| A red edge on open orders that should have been delivered by now.
-}
overdueTone : Date -> Order -> Maybe Tone
overdueTone today order =
    if isOverdue today order then
        Just Danger

    else
        Nothing


isOverdue : Date -> Order -> Bool
isOverdue today order =
    isOpen order.status && Date.compare order.due today == LT


{-| Not delivered and not cancelled (the Overview counts the same way).
-}
isOpen : OrderStatus -> Bool
isOpen status =
    status /= Delivered && status /= Cancelled


{-| How a screen reader names a row. The red edge is only seen, so the name says
it too.
-}
rowLabel : Context -> Order -> String
rowLabel context order =
    if isOverdue context.today order then
        order.id ++ ", overdue"

    else
        order.id


rowActions : Order -> List (Menu.Item Msg)
rowActions order =
    List.concat
        [ [ if Types.isEditable order.status then
                Menu.item "Edit order" (EditClicked order) |> Menu.withIcon Icon.edit

            else
                Menu.item "View order" (EditClicked order) |> Menu.withIcon Icon.eye
          ]
        , case Types.allowedNextStatuses order.status of
            [] ->
                []

            next ->
                Menu.separator :: Menu.heading "Change status" :: List.map (statusItem order) next
        , if canDelete order.status then
            [ Menu.separator
            , Menu.item "Delete order" (AskDelete order) |> Menu.danger |> Menu.withIcon Icon.trash
            ]

          else
            []
        ]


{-| The server only deletes drafts and cancelled orders.
-}
canDelete : OrderStatus -> Bool
canDelete status =
    status == Draft || status == Cancelled


statusItem : Order -> OrderStatus -> Menu.Item Msg
statusItem order status =
    case status of
        Draft ->
            Menu.item "Back to draft" (ChangeStatus order status) |> Menu.withIcon Icon.undo

        Confirmed ->
            Menu.item "Confirm order" (ChangeStatus order status) |> Menu.withIcon Icon.check

        Picking ->
            Menu.item "Start picking" (ChangeStatus order status) |> Menu.withIcon Icon.clipboard

        Shipped ->
            Menu.item "Mark as shipped" (ChangeStatus order status) |> Menu.withIcon Icon.send

        Delivered ->
            Menu.item "Mark as delivered" (ChangeStatus order status) |> Menu.withIcon Icon.checkCircle

        -- A cancelled order cannot be reopened: this one asks first.
        Cancelled ->
            Menu.item "Cancel order" (AskCancel order) |> Menu.danger |> Menu.withIcon Icon.ban



-- EDITOR


viewEditor : Context -> Model -> Html Msg
viewEditor context model =
    case model.editing of
        Nothing ->
            Drawer.view DrawerMsg [] model.drawer []

        Just editor ->
            let
                editable =
                    Editor.isEditable editor

                submitting =
                    editor.submit == Form.Submitting
            in
            Drawer.view DrawerMsg
                ([ Drawer.title (Editor.title editor)
                 , Drawer.subtitle (Editor.subtitle editor)
                 , Drawer.large

                 -- Nothing can close the drawer while the request runs.
                 , Drawer.busy submitting

                 -- The drawer never closes itself: the page decides, and asks
                 -- first when there is something to lose.
                 , Drawer.onRequestClose RequestClose
                 , Drawer.locale context.locale
                 ]
                    ++ (if editable then
                            [ Drawer.footer
                                [ Button.view [ Button.disabled submitting, Button.onClick RequestClose ] "Cancel"
                                , Button.view
                                    [ Button.primary
                                    , Button.icon Icon.save
                                    , Button.loading submitting
                                    , Button.onClick Submit
                                    ]
                                    "Save"
                                ]

                            -- The mark for unsaved changes lives here, where it
                            -- does not push the form down at the first keystroke,
                            -- and so does a failed save: at the end of a long form
                            -- it would be out of sight, and "Save" would seem to
                            -- do nothing.
                            , Drawer.footerStart [ viewSubmitStatus context editor ]
                            ]

                        else
                            [ Drawer.footer [ Button.view [ Button.onClick RequestClose ] "Close" ] ]
                       )
                )
                model.drawer
                [ Editor.view
                    { context = context
                    , lookups = model.lookups
                    , toMsg = EditorMsg
                    , onSubmit = Submit
                    , onFocusField = FocusField
                    , onRetryLookups = RetryLookups
                    }
                    editor
                ]


{-| Nothing to say, or the unsaved-changes mark, or where the save is. The status
line is one region from "Saving ..." to the answer, so focus can wait in it while
the "Try again" button is replaced.
-}
viewSubmitStatus : Context -> Editor.Editor -> Html Msg
viewSubmitStatus context editor =
    case editor.submit of
        Form.Idle ->
            Form.unsavedFlag [ Form.locale context.locale ] (Editor.isDirty editor)

        status ->
            Form.status [ Form.id Editor.formId, Form.onRetry Retry, Form.locale context.locale ] status


viewDiscard : Context -> Model -> Html Msg
viewDiscard context model =
    ConfirmDialog.view DiscardMsg
        [ ConfirmDialog.warning
        , ConfirmDialog.title "Discard changes?"
        , ConfirmDialog.message "You have unsaved changes to this order. If you close it now, they are lost."
        , ConfirmDialog.confirmLabel "Discard changes"
        , ConfirmDialog.cancelLabel "Keep editing"
        , ConfirmDialog.onConfirm DiscardConfirmed
        , ConfirmDialog.onCancel DiscardCancelled
        , ConfirmDialog.locale context.locale
        ]
        model.discard


{-| The question before a delete or a cancel. The dialog shows a failed request
itself, with the words of the server.
-}
viewConfirm : Context -> Model -> Html Msg
viewConfirm context model =
    let
        question =
            case model.pending of
                Just (Deleting order) ->
                    [ ConfirmDialog.danger
                    , ConfirmDialog.icon Icon.trash
                    , ConfirmDialog.title ("Delete order " ++ order.id ++ "?")
                    , ConfirmDialog.message ("The order of " ++ order.customer ++ " is removed from all lists. This cannot be undone.")
                    , ConfirmDialog.confirmLabel "Delete order"
                    ]

                Just (Cancelling batch) ->
                    let
                        count =
                            List.length batch.ids
                    in
                    [ ConfirmDialog.danger
                    , ConfirmDialog.icon Icon.ban
                    , ConfirmDialog.title
                        (case batch.ids of
                            [ id ] ->
                                "Cancel order " ++ id ++ "?"

                            _ ->
                                "Cancel " ++ String.fromInt count ++ " orders?"
                        )
                    , ConfirmDialog.message "A cancelled order cannot be reopened. It can only be deleted."
                    , ConfirmDialog.consequences
                        (if count > 1 then
                            [ "Orders that have already shipped or are finished cannot be cancelled. They stay as they are." ]

                         else
                            []
                        )
                    , ConfirmDialog.confirmLabel
                        (if count == 1 then
                            "Cancel order"

                         else
                            "Cancel orders"
                        )

                    -- "Cancel" would be the button that keeps the orders.
                    , ConfirmDialog.cancelLabel
                        (if count == 1 then
                            "Keep order"

                         else
                            "Keep orders"
                        )
                    ]

                Nothing ->
                    []
    in
    ConfirmDialog.view ConfirmMsg
        (question
            ++ [ ConfirmDialog.onConfirm ConfirmAccepted
               , ConfirmDialog.onCancel ConfirmDismissed
               , ConfirmDialog.locale context.locale
               ]
        )
        model.confirm
