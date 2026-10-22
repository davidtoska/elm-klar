module Main exposing (main)

{-| A confirmation before delete, with a toast and an Undo, and the focus kept right.

One row (menu "Delete...") or many (the bulk bar of the selection) go through the same
`ConfirmDialog`: open, busy, failed (try again), closed. The dummy backend refuses the first
request, so the failure and "Try again" can be seen. After a delete a toast offers Undo.
No focus code is written here: the overlay layer returns focus to where the user was, and
`Table.focus` takes it to the table when the bulk bar has gone.

-}

import Browser
import Html exposing (Html)
import Klar
import Klar.Button as Button
import Klar.ConfirmDialog as ConfirmDialog
import Klar.Icon as Icon
import Klar.Menu as Menu
import Klar.Overlay as Overlay
import Klar.PageHeader as PageHeader
import Klar.Remote as Remote exposing (Remote(..))
import Klar.Table as Table
import Klar.Toast as Toast
import Process
import Task



-- MODEL


type ItemId
    = ItemId Int


type alias Item =
    { id : ItemId
    , name : String
    , warehouse : String
    }


type alias Model =
    { items : List Item
    , table : Table.State ItemId
    , dialog : ConfirmDialog.State
    , pending : List ItemId
    , removed : List Item
    , attempts : Int
    , toasts : Toast.State Msg
    }


type Msg
    = TableMsg Table.Msg
    | DialogMsg ConfirmDialog.Msg
    | ToastMsg Toast.Msg
    | AskDelete (List ItemId)
    | ConfirmDelete
    | CancelDelete
    | Deleted (Result Remote.Problem ())
    | Undo
    | NoOp


main : Program () Model Msg
main =
    Browser.document
        { init = \_ -> ( init, Cmd.none )
        , update = update
        , view = \model -> { title = "Confirm before delete", body = [ view model ] }
        , subscriptions = \_ -> Sub.none
        }


init : Model
init =
    { items =
        [ Item (ItemId 1) "Pallet wrap, 500 mm" "Oslo"
        , Item (ItemId 2) "Euro pallet" "Oslo"
        , Item (ItemId 3) "Label printer ribbon" "Bergen"
        , Item (ItemId 4) "Cable ties, 300 mm" "Bergen"
        , Item (ItemId 5) "Safety gloves, size 9" "Trondheim"
        ]
    , table = Table.init "items"
    , dialog = ConfirmDialog.init "delete-dialog"
    , pending = []
    , removed = []
    , attempts = 0
    , toasts = Toast.init
    }


itemIds : Table.RowIds ItemId
itemIds =
    Table.rowIds { toKey = \(ItemId n) -> String.fromInt n, fromKey = \s -> Maybe.map ItemId (String.toInt s) }



-- BACKEND (a stand-in: the first request fails, the others work)


deleteRequest : Int -> Cmd Msg
deleteRequest attempt =
    Process.sleep 700
        |> Task.map
            (\_ ->
                if attempt == 1 then
                    Err (Remote.problem Remote.server |> Remote.withDetail "The server could not delete the items. Nothing was changed.")

                else
                    Ok ()
            )
        |> Task.perform Deleted



-- UPDATE


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        TableMsg m ->
            let
                ( table, cmd ) =
                    Table.update m model.table
            in
            ( { model | table = table }, Cmd.map TableMsg cmd )

        DialogMsg m ->
            let
                ( dialog, cmd ) =
                    ConfirmDialog.update m model.dialog
            in
            ( { model | dialog = dialog }, Cmd.map DialogMsg cmd )

        ToastMsg m ->
            let
                ( toasts, cmd ) =
                    Toast.update m model.toasts
            in
            ( { model | toasts = toasts }, Cmd.map ToastMsg cmd )

        AskDelete ids ->
            -- "" as the opener: focus goes back to the element that had it (a row menu is gone by then)
            let
                ( dialog, cmd ) =
                    ConfirmDialog.open "" model.dialog
            in
            ( { model | dialog = dialog, pending = ids }, Cmd.map DialogMsg cmd )

        ConfirmDelete ->
            ( { model | dialog = ConfirmDialog.setBusy model.dialog, attempts = model.attempts + 1 }
            , deleteRequest (model.attempts + 1)
            )

        CancelDelete ->
            -- while the request runs nothing may close the dialog
            if ConfirmDialog.isBusy model.dialog then
                ( model, Cmd.none )

            else
                closeDialog { model | pending = [] }

        Deleted (Err problem) ->
            ( { model | dialog = ConfirmDialog.setFailed problem model.dialog }, Cmd.none )

        Deleted (Ok ()) ->
            let
                ( gone, kept ) =
                    List.partition (\item -> List.member item.id model.pending) model.items

                ( closed, closeCmd ) =
                    closeDialog
                        { model
                            | items = kept
                            , removed = gone
                            , pending = []
                            , table = Table.clearSelection model.table
                        }

                ( toasts, toastCmd ) =
                    Toast.push
                        [ Toast.success
                        , Toast.message (String.fromInt (List.length gone) ++ " item(s) deleted.")
                        , Toast.action "Undo" Undo
                        ]
                        closed.toasts
            in
            ( { closed | toasts = toasts }
            , Cmd.batch [ closeCmd, Cmd.map ToastMsg toastCmd, Cmd.map TableMsg (Table.focus closed.table) ]
            )

        Undo ->
            ( { model | items = List.sortBy (\item -> idNumber item.id) (model.items ++ model.removed), removed = [] }
            , Cmd.none
            )

        NoOp ->
            ( model, Cmd.none )


closeDialog : Model -> ( Model, Cmd Msg )
closeDialog model =
    let
        ( dialog, cmd ) =
            ConfirmDialog.close model.dialog
    in
    ( { model | dialog = dialog }, Cmd.map DialogMsg cmd )


idNumber : ItemId -> Int
idNumber (ItemId n) =
    n



-- VIEW


view : Model -> Html Msg
view model =
    Overlay.host
        { attributes = []
        , page = [ Klar.stylesheet, viewItems model ]
        , overlays = [ confirmDialog model, Toast.view ToastMsg [] model.toasts ]
        }


viewItems : Model -> Html Msg
viewItems model =
    Html.div []
        [ PageHeader.view [ PageHeader.title "Items" ]
        , Table.view TableMsg
            [ Table.columns
                [ Table.text (Table.columnId "name") "Item" (\item -> item.name) [ Table.filterText ]
                , Table.text (Table.columnId "warehouse") "Warehouse" (\item -> item.warehouse) []
                ]
            , Table.rows (Loaded model.items)
            , Table.rowId itemIds (\item -> item.id)
            , Table.selectable
            , Table.bulkActions
                [ Button.view
                    [ Button.danger
                    , Button.icon Icon.trash
                    , Button.small
                    , Button.onClick (AskDelete (Table.selectedIds itemIds model.table))
                    ]
                    "Delete"
                ]
            , Table.rowActions
                (\item -> [ Menu.item "Delete..." (AskDelete [ item.id ]) |> Menu.danger |> Menu.withIcon Icon.trash ])
            ]
            model.table
        ]


confirmDialog : Model -> Overlay.Overlay Msg
confirmDialog model =
    let
        count =
            List.length model.pending
    in
    ConfirmDialog.view DialogMsg
        [ ConfirmDialog.danger
        , ConfirmDialog.title
            (if count == 1 then
                "Delete this item?"

             else
                "Delete " ++ String.fromInt count ++ " items?"
            )
        , ConfirmDialog.message "They disappear from every list. You can undo this for a few seconds."
        , ConfirmDialog.confirmLabel "Delete"
        , ConfirmDialog.onConfirm ConfirmDelete
        , ConfirmDialog.onCancel CancelDelete
        ]
        model.dialog
