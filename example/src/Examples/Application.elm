module Examples.Application exposing (main)

import Browser
import Browser.Navigation as Nav
import Html exposing (Html)
import Klar
import Klar.AppShell as AppShell
import Klar.Button as Button
import Klar.Icon as Icon
import Klar.Ids as Ids exposing (Ids)
import Klar.Money as Money exposing (Money)
import Klar.PageHeader as PageHeader
import Klar.Remote as Remote exposing (Remote(..))
import Klar.Settings as Settings exposing (Settings)
import Klar.SideNav as SideNav
import Klar.Table as Table
import Klar.Theme exposing (Tone(..))
import Klar.Toast as Toast
import Process
import Task
import Time
import Url exposing (Url)


type Page
    = Orders
    | Settings


type alias Order =
    { id : String, customer : String, total : Money }


type alias Model =
    { page : Page
    , shell : AppShell.State Page
    , settings : Settings
    , table : Table.State String
    , orders : Remote (List Order)
    , toasts : Toast.State Msg
    }


type Msg
    = ShellMsg AppShell.Msg
    | TableMsg Table.Msg
    | ToastMsg Toast.Msg
    | GotZone Time.Zone
    | GotOrders (Result Remote.Problem (List Order)) Time.Posix
    | Reload


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
      , shell = AppShell.init { id = "app-shell", key = key, url = url } |> AppShell.setPage navigation page
      , settings = Settings.default
      , table = Table.init "orders"
      , orders = Loading
      , toasts = Toast.init "toasts"
      }
    , Cmd.batch [ fetchOrders, Task.perform GotZone Time.here ]
    )


fetchOrders : Cmd Msg
fetchOrders =
    -- the first two lines stand for: Http.task { ... } |> Task.mapError toProblem |> Task.map Ok |> Task.onError (Err >> Task.succeed)
    Process.sleep 600
        |> Task.map (\_ -> Ok [ Order "1042" "Aurora Logistics" (kroner 125050), Order "1043" "Fjord Foods" (kroner 31000) ])
        |> Task.andThen (\result -> Task.map (GotOrders result) Time.now)
        |> Task.perform identity


kroner : Int -> Money
kroner ore =
    Money.fromMinor Money.nok ore |> Maybe.withDefault (Money.zero Money.nok)


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

        GotZone zone ->
            ( { model | settings = Settings.withZone zone model.settings }, Cmd.none )

        GotOrders result at ->
            -- a failed reload keeps the rows ("Old data from 14:05"); the table shows a failure itself
            case ( result, Remote.isRefreshing model.orders ) of
                ( Ok _, True ) ->
                    Toast.push [ Toast.tone Success, Toast.message "Orders updated." ] model.toasts
                        |> (\( toasts, cmd ) -> ( { model | orders = Remote.refreshWith model.orders result at, toasts = toasts }, Cmd.map ToastMsg cmd ))

                _ ->
                    ( { model | orders = Remote.refreshWith model.orders result at }, Cmd.none )

        Reload ->
            -- the rows stay on the screen, dimmed, until the answer comes
            ( { model | orders = Remote.refresh model.orders }, fetchOrders )


view : Model -> Browser.Document Msg
view model =
    { title = "Acme Operations"
    , body =
        [ Klar.stylesheetFor model.settings
        , AppShell.view
            [ AppShell.state ShellMsg model.shell
            , AppShell.settings model.settings
            , AppShell.brand (AppShell.brandLink { name = "Acme Operations", href = "#/", logo = Nothing })
            , AppShell.sidebar (AppShell.sideNav ShellMsg [ SideNav.entries navigation ] model.shell)
            , AppShell.overlays [ Toast.view ToastMsg [] model.toasts ]
            ]
            [ viewPage model ]
        ]
    }


viewPage : Model -> Html Msg
viewPage model =
    case model.page of
        Orders ->
            Html.div []
                [ PageHeader.view [ PageHeader.title "Orders", PageHeader.actions [ Button.view [ Button.onClick Reload ] "Reload" ] ]
                , Table.view TableMsg
                    [ Table.columns
                        [ Table.text (Table.columnId "id") "Order" .id [ Table.pinned ]
                        , Table.text (Table.columnId "customer") "Customer" .customer [ Table.filterText ]
                        , Table.money (Table.columnId "total") "Total" .total [ Table.footerSum ]
                        ]
                    , Table.remote model.orders
                    , Table.rowId Ids.string .id
                    , Table.ariaLabel "Orders"
                    , Table.onRetry Reload
                    , Table.settings model.settings
                    ]
                    model.table
                ]

        Settings ->
            PageHeader.view [ PageHeader.title "Settings" ]


pageKeys : Ids Page
pageKeys =
    Ids.list
        (\page ->
            case page of
                Orders ->
                    "orders"

                Settings ->
                    "settings"
        )
        [ Orders, Settings ]


navigation : List (SideNav.Entry Page msg)
navigation =
    [ SideNav.item pageKeys { key = Orders, label = "Orders", href = "#/orders" } |> SideNav.withIcon Icon.clipboardCheck
    , SideNav.item pageKeys { key = Settings, label = "Settings", href = "#/settings" } |> SideNav.withIcon Icon.settings
    ]


pageFromUrl : Url -> Page
pageFromUrl url =
    case url.fragment of
        Just "/settings" ->
            Settings

        _ ->
            Orders
