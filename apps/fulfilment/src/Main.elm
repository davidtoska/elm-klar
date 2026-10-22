module Main exposing (main)

import Api
import Backend exposing (Db)
import Browser
import Browser.Dom
import Browser.Navigation as Nav
import Detail
import Domain exposing (..)
import Effect exposing (Effects)
import Html exposing (Html)
import Ids
import Inbox
import Klar
import Klar.AppShell as AppShell
import Klar.Button as Button
import Klar.CommandPalette as CommandPalette
import Klar.Date as Date exposing (Date)
import Klar.EmptyState as EmptyState
import Klar.Format as Format
import Klar.Icon as Icon
import Klar.Locale as Locale
import Klar.Menu as Menu
import Klar.PageHeader as PageHeader
import Klar.Remote as Remote exposing (Problem, Remote(..))
import Klar.Shortcut as Shortcut
import Klar.ShortcutHelp as ShortcutHelp
import Klar.SideNav as SideNav
import Klar.Toast as Toast
import Process
import Task
import Time
import Url exposing (Url)


main : Program () Model Msg
main =
    Browser.application
        { init = \_ url key -> ( Booting key url, Task.perform identity (Task.map2 GotClock Time.here Time.now) )
        , view = view
        , update = update
        , subscriptions = subscriptions
        , onUrlRequest = LinkClicked
        , onUrlChange = UrlChanged
        }



-- MODEL


type Model
    = Booting Nav.Key Url
    | Ready Loaded


type alias Loaded =
    { key : Nav.Key
    , url : Url
    , zone : Time.Zone
    , now : Time.Posix
    , today : Date
    , db : Db
    , net : Api.Net
    , inbox : Inbox.Model
    , detail : Detail.Model
    , sideNav : SideNav.State String
    , netMenu : Menu.State
    , sidebarCollapsed : Bool
    , drawerOpen : Bool
    , toasts : Toast.State Msg
    , shortcuts : Shortcut.State
    , palette : CommandPalette.State
    , hits : Remote (List Summary)
    , hitsTicket : Int
    , help : ShortcutHelp.State
    , returnToTable : Bool
    }


type Route
    = InboxRoute (Maybe String)
    | OrderRoute OrderId
    | NotFound


type Setting
    = Slow
    | ReadsFail
    | SavesFail


type Msg
    = GotClock Time.Zone Time.Posix
    | Tick Time.Posix
    | LinkClicked Browser.UrlRequest
    | UrlChanged Url
    | InboxMsg Inbox.Msg
    | DetailMsg Detail.Msg
    | SideNavMsg SideNav.Msg
    | NetMenuMsg Menu.Msg
    | Toggle Setting
    | ToggleSidebar
    | ToggleDrawer
    | CloseDrawer
    | SkipToContent
    | ToastMsg Toast.Msg
    | ShortcutMsg Shortcut.Msg
    | OpenPalette
    | PaletteMsg CommandPalette.Msg
    | Debounced Int
    | GotHits Int (Result Problem Backend.Page)
    | RetryHits
    | OpenHelp
    | HelpMsg ShortcutHelp.Msg
    | GoToOrder OrderId
    | GoToInbox
    | FocusSearch
    | NewSavedView
    | ReloadInbox
    | NoOp



-- ROUTES


parseRoute : Url -> Route
parseRoute url =
    case url.fragment of
        Nothing ->
            InboxRoute Nothing

        Just fragment ->
            let
                ( path, query ) =
                    case String.split "?" fragment of
                        [ p ] ->
                            ( p, "" )

                        p :: rest ->
                            ( p, String.join "?" rest )

                        [] ->
                            ( "", "" )
            in
            case List.filter (not << String.isEmpty) (String.split "/" path) of
                [] ->
                    InboxRoute Nothing

                [ "orders" ] ->
                    InboxRoute (viewParam query)

                [ "orders", id ] ->
                    orderIdFromString id |> Maybe.map OrderRoute |> Maybe.withDefault NotFound

                _ ->
                    NotFound


viewParam : String -> Maybe String
viewParam query =
    query
        |> String.split "&"
        |> List.filterMap
            (\pair ->
                case String.split "=" pair of
                    [ "view", value ] ->
                        Url.percentDecode value

                    _ ->
                        Nothing
            )
        |> List.head


baseUrl : Url -> String
baseUrl url =
    Url.toString { url | fragment = Nothing, query = Nothing }


envOf : Loaded -> Inbox.Env
envOf loaded =
    { net = loaded.net, db = loaded.db, today = loaded.today, baseUrl = baseUrl loaded.url }



-- UPDATE


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case model of
        Booting key url ->
            case msg of
                GotClock zone now ->
                    start key url zone now

                _ ->
                    ( model, Cmd.none )

        Ready loaded ->
            updateLoaded msg loaded |> Tuple.mapFirst Ready


start : Nav.Key -> Url -> Time.Zone -> Time.Posix -> ( Model, Cmd Msg )
start key url zone now =
    let
        today =
            Date.fromPosix zone now

        db =
            Backend.init today now

        route =
            parseRoute url

        env =
            { net = Api.normal, db = db, today = today, baseUrl = baseUrl url }

        viewName =
            case route of
                InboxRoute name ->
                    name

                _ ->
                    Nothing

        ( inbox, inboxCmd ) =
            Inbox.init env viewName

        loaded0 =
            { key = key
            , url = url
            , zone = zone
            , now = now
            , today = today
            , db = db
            , net = Api.normal
            , inbox = inbox
            , detail = Detail.init
            , sideNav = SideNav.init Ids.mainNav
            , netMenu = Menu.init Ids.netMenu
            , sidebarCollapsed = False
            , drawerOpen = False
            , toasts = Toast.init
            , shortcuts = Shortcut.init
            , palette = CommandPalette.init Ids.palette
            , hits = NotAsked
            , hitsTicket = 0
            , help = ShortcutHelp.init Ids.help
            , returnToTable = False
            }

        ( loaded, routeCmd ) =
            case route of
                OrderRoute id ->
                    Detail.open env id loaded0.detail
                        |> Tuple.mapBoth (\d -> { loaded0 | detail = d }) (Cmd.map DetailMsg)

                _ ->
                    ( loaded0, Cmd.none )
    in
    ( Ready loaded, Cmd.batch [ Cmd.map InboxMsg inboxCmd, routeCmd ] )


updateLoaded : Msg -> Loaded -> ( Loaded, Cmd Msg )
updateLoaded msg loaded =
    case msg of
        GotClock _ _ ->
            ( loaded, Cmd.none )

        Tick now ->
            ( { loaded | now = now }, Cmd.none )

        NoOp ->
            ( loaded, Cmd.none )

        LinkClicked (Browser.Internal url) ->
            ( loaded, Nav.pushUrl loaded.key (Url.toString url) )

        LinkClicked (Browser.External href) ->
            ( loaded, Nav.load href )

        UrlChanged url ->
            let
                env =
                    envOf { loaded | url = url }

                next =
                    { loaded | url = url, drawerOpen = False }
            in
            case parseRoute url of
                OrderRoute id ->
                    let
                        ( detail, cmd ) =
                            Detail.open env id loaded.detail
                    in
                    ( { next | detail = detail }, Cmd.map DetailMsg cmd )

                InboxRoute (Just name) ->
                    let
                        ( detail, detailCmd ) =
                            Detail.close loaded.detail

                        ( inbox, inboxCmd ) =
                            Inbox.applyView env name loaded.inbox
                    in
                    ( { next | detail = detail, inbox = inbox }
                    , Cmd.batch [ Cmd.map DetailMsg detailCmd, Cmd.map InboxMsg inboxCmd ]
                    )

                _ ->
                    let
                        ( detail, cmd ) =
                            Detail.close loaded.detail
                    in
                    ( { next | detail = detail, returnToTable = False }
                    , Cmd.batch
                        [ Cmd.map DetailMsg cmd
                        , AppShell.resetScroll Ids.shell NoOp
                        , if Detail.isOpen loaded.detail && loaded.returnToTable then
                            Cmd.map InboxMsg (Inbox.focusTable loaded.inbox)

                          else
                            Cmd.none
                        ]
                    )

        InboxMsg m ->
            let
                ( inbox, cmd, effects ) =
                    Inbox.update (envOf loaded) m loaded.inbox
            in
            applyEffects (Effect.map InboxMsg effects) ( { loaded | inbox = inbox }, Cmd.map InboxMsg cmd )

        DetailMsg m ->
            let
                ( detail, cmd, effects ) =
                    Detail.update (envOf loaded) m loaded.detail
            in
            applyEffects (Effect.map DetailMsg effects) ( { loaded | detail = detail }, Cmd.map DetailMsg cmd )

        SideNavMsg m ->
            let
                ( sideNav, cmd ) =
                    SideNav.update m loaded.sideNav
            in
            ( { loaded | sideNav = sideNav }, Cmd.map SideNavMsg cmd )

        NetMenuMsg m ->
            let
                ( menu, cmd ) =
                    Menu.update m loaded.netMenu
            in
            ( { loaded | netMenu = menu }, Cmd.map NetMenuMsg cmd )

        Toggle setting ->
            let
                net =
                    loaded.net
            in
            ( { loaded
                | net =
                    case setting of
                        Slow ->
                            { net | slow = not net.slow }

                        ReadsFail ->
                            { net | readsFail = not net.readsFail }

                        SavesFail ->
                            { net | savesFail = not net.savesFail }
              }
            , Cmd.none
            )

        ToggleSidebar ->
            ( { loaded | sidebarCollapsed = not loaded.sidebarCollapsed }, Cmd.none )

        ToggleDrawer ->
            if loaded.drawerOpen then
                ( { loaded | drawerOpen = False }, AppShell.focusMenuButton Ids.shell NoOp )

            else
                ( { loaded | drawerOpen = True }
                , SideNav.focusLink SideNav.stringKeys "orders" loaded.sideNav NoOp
                )

        CloseDrawer ->
            ( { loaded | drawerOpen = False }, AppShell.focusMenuButton Ids.shell NoOp )

        SkipToContent ->
            ( loaded, AppShell.focusContent Ids.shell NoOp )

        ToastMsg m ->
            let
                ( toasts, cmd ) =
                    Toast.update m loaded.toasts
            in
            ( { loaded | toasts = toasts }, Cmd.map ToastMsg cmd )

        ShortcutMsg m ->
            let
                ( shortcuts, fired ) =
                    Shortcut.update shortcutList m loaded.shortcuts

                next =
                    { loaded | shortcuts = shortcuts }
            in
            case fired of
                Just fire ->
                    updateLoaded fire next

                Nothing ->
                    ( next, Cmd.none )

        OpenPalette ->
            let
                ( palette, cmd ) =
                    CommandPalette.open "" loaded.palette
            in
            ( { loaded | palette = palette, hits = NotAsked, hitsTicket = loaded.hitsTicket + 1 }
            , Cmd.map PaletteMsg cmd
            )

        PaletteMsg m ->
            let
                ( palette, cmd ) =
                    CommandPalette.update m loaded.palette

                changed =
                    CommandPalette.query palette /= CommandPalette.query loaded.palette
            in
            if changed then
                ( { loaded | palette = palette, hits = NotAsked, hitsTicket = loaded.hitsTicket + 1 }
                , Cmd.batch
                    [ Cmd.map PaletteMsg cmd
                    , Process.sleep 250 |> Task.perform (\_ -> Debounced (loaded.hitsTicket + 1))
                    ]
                )

            else
                ( { loaded | palette = palette }, Cmd.map PaletteMsg cmd )

        Debounced ticket ->
            let
                term =
                    orderTerm (CommandPalette.query loaded.palette)
            in
            if ticket == loaded.hitsTicket && term /= "" then
                ( { loaded | hits = Loading }
                , Inbox.searchOrders (envOf loaded) term (GotHits ticket)
                )

            else
                ( loaded, Cmd.none )

        RetryHits ->
            let
                ticket =
                    loaded.hitsTicket + 1
            in
            ( { loaded | hits = Loading, hitsTicket = ticket }
            , Inbox.searchOrders (envOf loaded) (orderTerm (CommandPalette.query loaded.palette)) (GotHits ticket)
            )

        GotHits ticket result ->
            if ticket == loaded.hitsTicket then
                ( { loaded | hits = result |> Result.map .rows |> Remote.fromResult }, Cmd.none )

            else
                ( loaded, Cmd.none )

        OpenHelp ->
            let
                ( help, cmd ) =
                    ShortcutHelp.open "" loaded.help
            in
            ( { loaded | help = help }, Cmd.map HelpMsg cmd )

        HelpMsg m ->
            let
                ( help, cmd ) =
                    ShortcutHelp.update m loaded.help
            in
            ( { loaded | help = help }, Cmd.map HelpMsg cmd )

        GoToOrder id ->
            -- the palette was opened from a shortcut: no element with an id to return focus to
            ( { loaded | returnToTable = CommandPalette.openedFrom loaded.palette == "" }
            , Nav.pushUrl loaded.key ("#/orders/" ++ orderIdToString id)
            )

        GoToInbox ->
            ( loaded
            , Cmd.batch
                [ Nav.pushUrl loaded.key "#/orders"
                , Browser.Dom.focus Ids.ordersSearch |> Task.attempt (\_ -> NoOp)
                ]
            )

        FocusSearch ->
            ( loaded, Browser.Dom.focus Ids.ordersSearch |> Task.attempt (\_ -> NoOp) )

        NewSavedView ->
            let
                ( inbox, cmd ) =
                    Inbox.askNewView loaded.inbox
            in
            ( { loaded | inbox = inbox }, Cmd.map InboxMsg cmd )

        ReloadInbox ->
            let
                ( inbox, cmd ) =
                    Inbox.reload (envOf loaded) loaded.inbox
            in
            ( { loaded | inbox = inbox }, Cmd.map InboxMsg cmd )


{-| "go to order 10482" and "order 10482" both look for 10482.
-}
orderTerm : String -> String
orderTerm query =
    query
        |> String.words
        |> List.filter (\w -> not (List.member (String.toLower w) [ "go", "to", "order", "open" ]))
        |> String.join " "


applyEffects : Effects Msg -> ( Loaded, Cmd Msg ) -> ( Loaded, Cmd Msg )
applyEffects effects ( loaded, cmd ) =
    let
        ( toasts, toastCmds ) =
            List.foldl
                (\notice ( state, cmds ) ->
                    let
                        ( next, c ) =
                            Toast.push (toastAttributes notice) state
                    in
                    ( next, Cmd.map ToastMsg c :: cmds )
                )
                ( loaded.toasts, [] )
                effects.notices

        changed =
            case effects.change of
                Just change ->
                    { loaded | db = change loaded.db, toasts = toasts }

                Nothing ->
                    { loaded | toasts = toasts }

        env =
            envOf changed

        ( inbox, inboxCmd ) =
            if effects.change /= Nothing then
                Inbox.reload env changed.inbox

            else
                ( changed.inbox, Cmd.none )

        ( detail, detailCmd ) =
            if effects.change /= Nothing then
                Detail.reload env changed.detail

            else
                ( changed.detail, Cmd.none )

        navigate =
            case ( effects.open, effects.close ) of
                ( Just id, _ ) ->
                    Nav.pushUrl loaded.key ("#/orders/" ++ orderIdToString id)

                ( Nothing, True ) ->
                    Nav.pushUrl loaded.key "#/orders"

                _ ->
                    Cmd.none
    in
    ( { changed | inbox = inbox, detail = detail }
    , Cmd.batch
        ([ cmd, navigate, Cmd.map InboxMsg inboxCmd, Cmd.map DetailMsg detailCmd ] ++ toastCmds)
    )


toastAttributes : Effect.Notice Msg -> List (Toast.Attribute Msg)
toastAttributes notice =
    List.concat
        [ [ Toast.tone notice.tone, Toast.title notice.title ]
        , if notice.message == "" then
            []

          else
            [ Toast.message notice.message ]
        , case notice.retry of
            Just retry ->
                [ Toast.action "Try again" retry ]

            Nothing ->
                []
        ]



-- SHORTCUTS AND SUBSCRIPTIONS


shortcutList : List (Shortcut.Shortcut Msg)
shortcutList =
    [ Shortcut.shortcut (Shortcut.mod (Shortcut.char 'k')) "Navigation" "Open the command palette" OpenPalette
        |> Shortcut.inInputs
    , Shortcut.shortcut (Shortcut.sequence [ Shortcut.char 'g', Shortcut.char 'i' ]) "Navigation" "Go to the inbox" GoToInbox
    , Shortcut.shortcut (Shortcut.char '/') "Navigation" "Search the orders" FocusSearch
    , Shortcut.shortcut (Shortcut.char 'r') "Orders" "Reload the orders" ReloadInbox
    , Shortcut.shortcut (Shortcut.char 'n') "Orders" "Save the filters as a new view" NewSavedView
    , Shortcut.shortcut (Shortcut.char '?') "Help" "Show the keyboard shortcuts" OpenHelp
    ]


subscriptions : Model -> Sub Msg
subscriptions model =
    case model of
        Booting _ _ ->
            Sub.none

        Ready loaded ->
            Sub.batch
                [ Shortcut.subscription ShortcutMsg shortcutList loaded.shortcuts
                , Time.every 60000 Tick
                ]



-- VIEW


view : Model -> Browser.Document Msg
view model =
    case model of
        Booting _ _ ->
            { title = "Fulfilment desk", body = [ Klar.stylesheet ] }

        Ready loaded ->
            { title = "Fulfilment desk"
            , body = [ Klar.stylesheet, viewShell loaded ]
            }


viewShell : Loaded -> Html Msg
viewShell loaded =
    let
        env =
            envOf loaded

        blocked =
            Inbox.isBlocking loaded.inbox
                || Detail.isBlocking loaded.detail
                || CommandPalette.isOpen loaded.palette
                || ShortcutHelp.isOpen loaded.help
    in
    AppShell.view
        [ AppShell.id Ids.shell
        , AppShell.brand
            (AppShell.brandLink
                { name = "Fulfilment desk"
                , href = "#/orders"
                , logo = Just (Icon.sized Icon.Large Icon.package)
                }
            )
        , AppShell.sidebar
            (SideNav.view SideNavMsg
                [ SideNav.entries navigation
                , SideNav.current "orders"
                , SideNav.collapsed loaded.sidebarCollapsed
                ]
                loaded.sideNav
            )
        , AppShell.sidebarCollapsed loaded.sidebarCollapsed
        , AppShell.onToggleSidebar ToggleSidebar
        , AppShell.drawerOpen loaded.drawerOpen
        , AppShell.onToggleDrawer ToggleDrawer
        , AppShell.onCloseDrawer CloseDrawer
        , AppShell.onSearch OpenPalette
        , AppShell.searchPlaceholder "Go to order, run a command ..."
        , AppShell.actions
            [ netMenu loaded
            , Button.iconOnly [ Button.ghost, Button.onClick OpenHelp ] Icon.keyboard "Keyboard shortcuts"
            ]
        , AppShell.userName "Ada Lovelace"
        , AppShell.userRole "Fulfilment"
        , AppShell.onSkipToContent SkipToContent
        , AppShell.onStrayDrop NoOp
        , AppShell.shortcuts (Shortcut.listen ShortcutMsg shortcutList loaded.shortcuts)
        , AppShell.modalOpen blocked
        , AppShell.overlays
            (List.concat
                [ List.map (Html.map InboxMsg) (Inbox.overlays env loaded.inbox)
                , [ Html.map DetailMsg (Detail.view loaded.zone loaded.now loaded.detail) ]
                , List.map (Html.map DetailMsg) (Detail.overlays loaded.detail)
                , [ viewPalette loaded
                  , ShortcutHelp.view HelpMsg [] shortcutList loaded.help
                  , Toast.view ToastMsg [] loaded.toasts
                  ]
                ]
            )
        ]
        [ viewPage loaded ]


navigation : List (SideNav.Entry String Msg)
navigation =
    [ SideNav.section "Fulfilment"
        [ SideNav.item SideNav.stringKeys { key = "orders", label = "Orders", href = "#/orders" }
            |> SideNav.withIcon Icon.inbox
        ]
    ]


viewPage : Loaded -> Html Msg
viewPage loaded =
    case parseRoute loaded.url of
        NotFound ->
            EmptyState.view
                [ EmptyState.title "This page does not exist"
                , EmptyState.description "The address is not one of the orders pages."
                , EmptyState.action (Button.view [ Button.href "#/orders" ] "Go to the inbox")
                ]

        _ ->
            Html.div []
                [ PageHeader.view
                    [ PageHeader.title "Orders"
                    , PageHeader.subtitle
                        ("Today is " ++ Format.dateLong Locale.default loaded.today ++ ". Press ? for the keyboard shortcuts.")
                    , PageHeader.actions
                        [ Button.view [ Button.icon Icon.plus, Button.onClick NewSavedView ] "New saved view" ]
                    ]
                , Html.map InboxMsg (Inbox.view (envOf loaded) loaded.inbox)
                ]


netMenu : Loaded -> Html Msg
netMenu loaded =
    let
        item label on setting =
            Menu.item label (Toggle setting)
                |> (if on then
                        Menu.withIcon Icon.check

                    else
                        identity
                   )
    in
    Menu.view NetMenuMsg
        [ Menu.label "Simulated network"
        , Menu.trigger [ Button.ghost, Button.small ]
        , Menu.alignEnd
        , Menu.items
            [ Menu.heading "Pretend that ..."
            , item "Everything is slow" loaded.net.slow Slow
            , item "Loading fails" loaded.net.readsFail ReadsFail
            , item "Saving fails" loaded.net.savesFail SavesFail
            ]
        ]
        loaded.netMenu


viewPalette : Loaded -> Html Msg
viewPalette loaded =
    CommandPalette.view PaletteMsg
        [ CommandPalette.placeholder "Go to order ..., or type a command"
        , CommandPalette.sections
            [ CommandPalette.section "Navigation"
                [ CommandPalette.item "Go to the inbox" GoToInbox
                    |> CommandPalette.withIcon Icon.inbox
                    |> CommandPalette.withShortcut (Shortcut.sequence [ Shortcut.char 'g', Shortcut.char 'i' ])
                ]
            , CommandPalette.section "Actions"
                [ CommandPalette.item "New saved view" NewSavedView
                    |> CommandPalette.withIcon Icon.plus
                    |> CommandPalette.withKeywords [ "create", "filter", "save" ]
                    |> CommandPalette.withShortcut (Shortcut.char 'n')
                , CommandPalette.item "Reload the orders" ReloadInbox
                    |> CommandPalette.withIcon Icon.refresh
                    |> CommandPalette.withShortcut (Shortcut.char 'r')
                , CommandPalette.item "Show the keyboard shortcuts" OpenHelp
                    |> CommandPalette.withIcon Icon.keyboard
                    |> CommandPalette.withShortcut (Shortcut.char '?')
                ]
            , CommandPalette.remote "Orders"
                (Remote.map
                    (List.map
                        (\order ->
                            CommandPalette.item ("Go to order " ++ orderIdToString order.id) (GoToOrder order.id)
                                |> CommandPalette.withDescription (order.customer ++ ", " ++ statusLabel order.status)
                                |> CommandPalette.withId (orderIdToString order.id)
                        )
                    )
                    loaded.hits
                )
                |> CommandPalette.onRetry RetryHits
                |> CommandPalette.emptyText "No orders found"
            ]
        ]
        loaded.palette
