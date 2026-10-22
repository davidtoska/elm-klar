module Main exposing (main)

{-| The standard shape of a Klar application: one `Browser.application`, an `AppShell` with a
`SideNav` typed by the application's own `Page`, one page per route, `Remote` for what a
backend sends, and one list of overlays (a confirmation and the toasts).

Copy this folder, rename things, replace `fetchOrders` with a real request.

-}

import Browser
import Browser.Navigation as Nav
import Html exposing (Html)
import Klar
import Klar.AppShell as AppShell
import Klar.Button as Button
import Klar.ConfirmDialog as ConfirmDialog
import Klar.Icon as Icon
import Klar.Overlay exposing (Overlay)
import Klar.PageHeader as PageHeader
import Klar.Remote as Remote exposing (Remote(..))
import Klar.SideNav as SideNav
import Klar.Table as Table
import Klar.Toast as Toast
import Process
import Task
import Url exposing (Url)



-- MODEL


type Page
    = Orders
    | Settings


type alias Order =
    { id : String
    , customer : String
    , total : Float
    }


type alias Model =
    { page : Page
    , shell : AppShell.State Page
    , table : Table.State String
    , orders : Remote (List Order)
    , clearDialog : ConfirmDialog.State
    , toasts : Toast.State Msg
    }


type Msg
    = ShellMsg AppShell.Msg
    | TableMsg Table.Msg
    | ToastMsg Toast.Msg
    | DialogMsg ConfirmDialog.Msg
    | GotOrders (Result Remote.Problem (List Order))
    | Reload
    | AskClear
    | ConfirmClear
    | CancelClear
    | Cleared


main : Program () Model Msg
main =
    Browser.application
        { init = init
        , update = update
        , view = view
        , subscriptions = \_ -> Sub.none
        , onUrlRequest = AppShell.onUrlRequest ShellMsg
        , onUrlChange = AppShell.onUrlChange ShellMsg
        }


init : () -> Url -> Nav.Key -> ( Model, Cmd Msg )
init _ url key =
    let
        page =
            pageFromUrl url
    in
    ( { page = page
      , shell = AppShell.init { id = shellId, key = key } |> AppShell.setPage navigation page
      , table = Table.init "orders"
      , orders = Loading
      , clearDialog = ConfirmDialog.init "clear-dialog"
      , toasts = Toast.init
      }
    , fetchOrders
    )



-- BACKEND (a stand-in: replace it with Http.get and Result.mapError toProblem)


fetchOrders : Cmd Msg
fetchOrders =
    Process.sleep 600
        |> Task.map (\_ -> Ok [ Order "1042" "Aurora Logistics Ltd" 1250.5, Order "1043" "Fjord Foods" 310 ])
        |> Task.perform GotOrders


clearOrders : Cmd Msg
clearOrders =
    Process.sleep 500 |> Task.perform (\_ -> Cleared)



-- UPDATE


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        ShellMsg m ->
            let
                ( shell, cmd, address ) =
                    AppShell.update m model.shell
            in
            case address of
                Just url ->
                    -- the one place that learns of a new route
                    let
                        page =
                            pageFromUrl url
                    in
                    ( { model | page = page, shell = AppShell.setPage navigation page shell }
                    , Cmd.map ShellMsg cmd
                    )

                Nothing ->
                    ( { model | shell = shell }, Cmd.map ShellMsg cmd )

        TableMsg m ->
            let
                ( table, cmd ) =
                    Table.update m model.table
            in
            ( { model | table = table }, Cmd.map TableMsg cmd )

        ToastMsg m ->
            let
                ( toasts, cmd ) =
                    Toast.update m model.toasts
            in
            ( { model | toasts = toasts }, Cmd.map ToastMsg cmd )

        DialogMsg m ->
            let
                ( dialog, cmd ) =
                    ConfirmDialog.update m model.clearDialog
            in
            ( { model | clearDialog = dialog }, Cmd.map DialogMsg cmd )

        GotOrders result ->
            ( { model | orders = Remote.fromResult result }, Cmd.none )

        Reload ->
            ( { model | orders = Loading }, fetchOrders )

        AskClear ->
            let
                ( dialog, cmd ) =
                    ConfirmDialog.open clearButtonId model.clearDialog
            in
            ( { model | clearDialog = dialog }, Cmd.map DialogMsg cmd )

        ConfirmClear ->
            ( { model | clearDialog = ConfirmDialog.setBusy model.clearDialog }, clearOrders )

        CancelClear ->
            if ConfirmDialog.isBusy model.clearDialog then
                ( model, Cmd.none )

            else
                closeClearDialog model

        Cleared ->
            let
                ( closed, closeCmd ) =
                    closeClearDialog { model | orders = Loaded [] }

                ( toasts, toastCmd ) =
                    Toast.push [ Toast.success, Toast.message "All orders cleared." ] closed.toasts
            in
            ( { closed | toasts = toasts }
            , Cmd.batch [ closeCmd, Cmd.map ToastMsg toastCmd ]
            )


closeClearDialog : Model -> ( Model, Cmd Msg )
closeClearDialog model =
    let
        ( dialog, cmd ) =
            ConfirmDialog.close model.clearDialog
    in
    ( { model | clearDialog = dialog }, Cmd.map DialogMsg cmd )



-- VIEW


view : Model -> Browser.Document Msg
view model =
    { title = "Acme Operations"
    , body =
        [ Klar.stylesheet
        , AppShell.view
            [ AppShell.state ShellMsg model.shell
            , AppShell.brand (AppShell.brandLink { name = "Acme Operations", href = "#/", logo = Nothing })
            , AppShell.sidebar (AppShell.sideNav ShellMsg [ SideNav.entries navigation ] model.shell)
            , AppShell.overlays (overlays model)
            ]
            [ viewPage model ]
        ]
    }


{-| Every overlay, always, also while it is closed: the layer keeps focus and the opener.
-}
overlays : Model -> List (Overlay Msg)
overlays model =
    [ ConfirmDialog.view DialogMsg
        [ ConfirmDialog.danger
        , ConfirmDialog.title "Clear all orders?"
        , ConfirmDialog.message "The list will be empty."
        , ConfirmDialog.confirmLabel "Clear orders"
        , ConfirmDialog.onConfirm ConfirmClear
        , ConfirmDialog.onCancel CancelClear
        ]
        model.clearDialog
    , Toast.view ToastMsg [] model.toasts
    ]


viewPage : Model -> Html Msg
viewPage model =
    case model.page of
        Orders ->
            Html.div []
                [ PageHeader.view
                    [ PageHeader.title "Orders"
                    , PageHeader.actions
                        [ Button.view [ Button.onClick Reload ] "Reload"
                        , Button.view [ Button.id clearButtonId, Button.danger, Button.onClick AskClear ] "Clear"
                        ]
                    ]
                , Table.view TableMsg
                    [ Table.columns
                        [ Table.text (Table.columnId "id") "Order" .id [ Table.pinned ]
                        , Table.text (Table.columnId "customer") "Customer" .customer [ Table.filterText ]
                        , Table.float (Table.columnId "total") "Total" 2 .total [ Table.footerSum ]
                        ]
                    , Table.rows model.orders
                    , Table.rowId Table.stringIds .id
                    , Table.onRetry Reload
                    ]
                    model.table
                ]

        Settings ->
            PageHeader.view [ PageHeader.title "Settings", PageHeader.subtitle "Nothing to set yet." ]



-- NAVIGATION


shellId : String
shellId =
    "app-shell"


clearButtonId : String
clearButtonId =
    "clear-orders"


pageToString : Page -> String
pageToString page =
    case page of
        Orders ->
            "orders"

        Settings ->
            "settings"


pageKeys : SideNav.Keys Page
pageKeys =
    SideNav.keys pageToString


navigation : List (SideNav.Entry Page msg)
navigation =
    [ SideNav.item pageKeys { key = Orders, label = "Orders", href = "#/orders" }
        |> SideNav.withIcon Icon.clipboardCheck
    , SideNav.item pageKeys { key = Settings, label = "Settings", href = "#/settings" }
        |> SideNav.withIcon Icon.settings
    ]


pageFromUrl : Url -> Page
pageFromUrl url =
    case url.fragment of
        Just "/settings" ->
            Settings

        _ ->
            Orders
