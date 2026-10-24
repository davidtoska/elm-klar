module Main exposing (main)

{-| The showcase application: the shell around the pages.

`Main` owns what is shared by every page: routing, the in-memory backend, the
language, the sidebar, notifications (toasts), the command palette, the keyboard
shortcuts, and the developer tools that make the pretend network misbehave. It
only composes `Klar.*` components.

-}

import Api
import Api.Problem as Problem
import Api.Types as Types exposing (ApiError, Page)
import Browser
import Browser.Dom as Dom
import Browser.Navigation as Nav
import Html exposing (Html)
import Klar
import Klar.Alert as Alert
import Klar.AppShell as AppShell
import Klar.Badge as Badge
import Klar.Button as Button
import Klar.CommandPalette as CommandPalette
import Klar.Date exposing (Date)
import Klar.Drawer as Drawer
import Klar.Icon as Icon
import Klar.Ids as Ids exposing (Ids)
import Klar.Layout as Layout
import Klar.Link as Link
import Klar.Locale as Locale exposing (Locale)
import Klar.Menu as Menu
import Klar.Overlay as Overlay exposing (Overlay)
import Klar.Radio as Radio
import Klar.Remote as Remote exposing (Remote)
import Klar.SegmentedControl as SegmentedControl
import Klar.Settings as Settings exposing (Settings)
import Klar.Shortcut as Shortcut exposing (Shortcut)
import Klar.ShortcutHelp as ShortcutHelp
import Klar.SideNav as SideNav
import Klar.Text as Text
import Klar.Theme as Theme exposing (Density(..), Tone(..))
import Klar.Toast as Toast
import Page.Effect as Effect exposing (Effect(..))
import Page.Gallery as Gallery
import Page.Gallery.Catalog as Catalog
import Page.Orders as Orders
import Page.Overview as Overview
import Page.Products as Products
import Process
import Route exposing (Route(..))
import Showcase.Sample as Sample
import Task
import Time
import Url exposing (Url)


main : Program () Model Msg
main =
    Browser.application
        { init = init
        , view = view
        , update = update
        , subscriptions = subscriptions
        , onUrlRequest = UrlRequested
        , onUrlChange = AppShell.onUrlChange ShellMsg
        }



-- MODEL


type alias Model =
    { key : Nav.Key
    , route : Route
    , locale : Locale
    , settings : Settings
    , zoneChoice : ZoneChoice
    , browserZone : Maybe Time.Zone
    , today : Date
    , backend : Api.Backend
    , shell : AppShell.State String
    , userMenu : Menu.State
    , shortcuts : Shortcut.State
    , toasts : Toast.State Msg
    , palette : CommandPalette.State
    , orderHits : Remote (List (CommandPalette.Item Msg))
    , hitTicket : Int
    , help : ShortcutHelp.State
    , tools : Drawer.State
    , overview : Overview.Model
    , orders : Orders.Model
    , products : Products.Model
    , gallery : Gallery.Model
    }


init : () -> Url -> Nav.Key -> ( Model, Cmd Msg )
init _ url key =
    let
        route =
            Route.fromUrl url

        context =
            { locale = Locale.default, today = Sample.today, settings = Settings.default }

        backend =
            Api.init

        -- The pages start empty; their requests are not sent from here but by
        -- `enter`, for the page the address names.
        ( overview, backend1, _ ) =
            Overview.init context backend

        ( orders, backend2, _ ) =
            Orders.init context Nothing backend1

        ( products, backend3, _ ) =
            Products.init context backend2

        model =
            { key = key
            , route = route
            , locale = Locale.default
            , settings = Settings.default
            , zoneChoice = Browser
            , browserZone = Nothing
            , today = Sample.today
            , backend = backend3
            , shell = AppShell.init { id = shellId, key = key } |> AppShell.setPage menu (routeKey route)
            , userMenu = Menu.init "user-menu"
            , shortcuts = Shortcut.init
            , toasts = Toast.init |> Toast.maxVisible 3
            , palette = CommandPalette.init "palette"
            , orderHits = Remote.NotAsked
            , hitTicket = 0
            , help = ShortcutHelp.init "shortcut-help"
            , tools = Drawer.init "dev-tools"
            , overview = overview
            , orders = orders
            , products = products
            , gallery = Gallery.init
            }

        ( entered, enterCmd ) =
            enter route model
    in
    ( entered
    , Cmd.batch
        [ -- Only the page the address names fetches its data (in `enter`).
          -- The others start empty and fetch when they are visited.
          enterCmd
        , Time.here |> Task.perform GotZone
        , Cmd.map ShellMsg (AppShell.goToContent entered.shell)
        ]
    )


shellId : String
shellId =
    "app"


pageContext : Model -> Effect.Context
pageContext model =
    { locale = model.locale, today = model.today, settings = model.settings }



-- UPDATE


type Msg
    = NoOp
    | UrlRequested Browser.UrlRequest
    | GotZone Time.Zone
    | GoTo Route
      -- shell
    | ShellMsg AppShell.Msg
    | ToggleSidebarKey
    | FocusContent
    | UserMenuMsg Menu.Msg
    | ShortcutMsg Shortcut.Msg
    | ToastMsg Toast.Msg
    | SetLocale Locale
    | SetDensity Density
    | SetTheme String
    | SetColorMode String
    | SetZone ZoneChoice
    | ToggleLocale
      -- command palette
    | OpenPalette
    | PaletteMsg CommandPalette.Msg
    | PaletteAction Msg
    | HitsDebounced Int
    | HitsLoaded Int (Result ApiError (Page Types.Order))
    | RetryHits
      -- help and developer tools
    | OpenHelp
    | OpenHelpFrom String
    | HelpMsg ShortcutHelp.Msg
    | OpenTools
    | CloseTools
    | ToolsMsg Drawer.Msg
    | SetMode Api.Mode
    | SetLatency Api.Latency
    | SetDataset Api.Dataset
    | ResetPages
      -- pages
    | OverviewMsg Overview.Msg
    | OrdersMsg Orders.Msg
    | ProductsMsg Products.Msg
    | GalleryMsg Gallery.Msg



-- The one place that learns of a route change (see `AppShell.update`).


routeChanged : Url -> Model -> ( Model, Cmd Msg )
routeChanged url model =
    let
        route =
            Route.fromUrl url

        next =
            { model
                | route = route
                , shell = AppShell.setPage menu (routeKey route) model.shell
            }
    in
    -- Closing an order opened by link (`#/orders/ORD-10001` back to
    -- `#/orders`) keeps the list as it is. When the browser's back
    -- button did it, the editor closes too.
    case ( model.route, route ) of
        ( OrderDetail _, Orders ) ->
            let
                ( orders, ordersCmd ) =
                    Orders.routeLeft next.orders
            in
            ( { next | orders = orders }, Cmd.map OrdersMsg ordersCmd )

        _ ->
            enter route next


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        NoOp ->
            ( model, Cmd.none )

        UrlRequested (Browser.Internal url) ->
            -- Only `#/path` fragments are routes. Anything else (`#field-id`
            -- anchors inside a component) must not change the page.
            if isRouteFragment url then
                ( model, goTo model.key model.route (Route.fromUrl url) (Url.toString url) )

            else
                ( model, Cmd.none )

        UrlRequested (Browser.External href) ->
            ( model, Nav.load href )

        ShellMsg inner ->
            let
                ( shell, shellCmd, changed ) =
                    AppShell.update inner model.shell

                next =
                    { model | shell = shell }
            in
            case changed of
                Just url ->
                    let
                        ( entered, cmd ) =
                            routeChanged url next
                    in
                    ( entered, Cmd.batch [ cmd, Cmd.map ShellMsg shellCmd ] )

                Nothing ->
                    ( next, Cmd.map ShellMsg shellCmd )

        GotZone zone ->
            -- The time zone is the visitor's, but the day is the one the dummy backend
            -- pretends it is (see `Backend.Generate.today`): the data is made relative to
            -- it, so "overdue" means the same thing on every load and in every page.
            ( applyZone { model | browserZone = Just zone }, Cmd.none )

        GoTo route ->
            -- A shortcut or the command palette must not throw away an order
            -- being edited: the page asks first, and the user goes again.
            let
                held =
                    case model.route of
                        Orders ->
                            heldOrders model

                        OrderDetail _ ->
                            heldOrders model

                        _ ->
                            Nothing
            in
            case held of
                Just stay ->
                    stay

                Nothing ->
                    -- The palette gives focus back to the element that had it,
                    -- which the old page takes with it: a moment later the new
                    -- page gets focus, so the keyboard does not end up nowhere.
                    ( model
                    , Cmd.batch
                        [ goTo model.key model.route route (Route.path route)
                        , case route of
                            -- An order opens its own editor, which takes focus.
                            OrderDetail _ ->
                                Cmd.none

                            _ ->
                                Process.sleep 60 |> Task.perform (\_ -> FocusContent)
                        ]
                    )

        ToggleSidebarKey ->
            -- `[` hides the sidebar on a wide screen and opens or closes the drawer
            -- on a narrow one (below 900 px, see `Klar.AppShell`).
            ( model, Cmd.map ShellMsg (AppShell.toggleSidebar model.shell) )

        FocusContent ->
            ( model, Cmd.map ShellMsg (AppShell.goToContent model.shell) )

        UserMenuMsg inner ->
            let
                ( menuState, cmd ) =
                    Menu.update inner model.userMenu
            in
            ( { model | userMenu = menuState }, Cmd.map UserMenuMsg cmd )

        ShortcutMsg inner ->
            let
                ( state, fired ) =
                    Shortcut.update shortcuts inner model.shortcuts
            in
            case fired of
                Just next ->
                    update next { model | shortcuts = state }

                Nothing ->
                    ( { model | shortcuts = state }, Cmd.none )

        ToastMsg inner ->
            let
                ( toasts, cmd ) =
                    Toast.update inner model.toasts
            in
            ( { model | toasts = toasts }, Cmd.map ToastMsg cmd )

        SetLocale locale ->
            ( { model | locale = locale }, Cmd.none )

        SetDensity density ->
            ( { model | settings = Settings.withDensity density model.settings }, Cmd.none )

        SetTheme key ->
            ( { model | settings = Settings.withTheme (Theme.fromKey key |> Maybe.withDefault Theme.klar) model.settings }, Cmd.none )

        SetColorMode key ->
            ( { model | settings = Settings.withMode (colorModeFromKey key) model.settings }, Cmd.none )

        SetZone choice ->
            ( applyZone { model | zoneChoice = choice }, Cmd.none )

        ToggleLocale ->
            ( { model
                | locale = Locale.pick model.locale { nb = Locale.en, en = Locale.nb }
              }
            , Cmd.none
            )

        OpenPalette ->
            let
                ( palette, cmd ) =
                    CommandPalette.open "" model.palette
            in
            -- A new ticket: an answer to a search from the last time the palette
            -- was open must not show up under the empty query.
            ( { model | palette = palette, orderHits = Remote.NotAsked, hitTicket = model.hitTicket + 1 }, Cmd.map PaletteMsg cmd )

        PaletteMsg inner ->
            let
                ( palette, cmd ) =
                    CommandPalette.update inner model.palette

                query =
                    String.trim (CommandPalette.query palette)

                changed =
                    CommandPalette.query palette /= CommandPalette.query model.palette
            in
            if changed && query /= "" then
                -- Loading from the first key press, so the palette says "Searching ..."
                -- during the debounce instead of flashing "No results".
                ( { model | palette = palette, orderHits = Remote.Loading, hitTicket = model.hitTicket + 1 }
                , Cmd.batch
                    [ Cmd.map PaletteMsg cmd
                    , Process.sleep 250 |> Task.perform (\_ -> HitsDebounced (model.hitTicket + 1))
                    ]
                )

            else if changed then
                ( { model | palette = palette, orderHits = Remote.NotAsked, hitTicket = model.hitTicket + 1 }, Cmd.map PaletteMsg cmd )

            else
                ( { model | palette = palette }, Cmd.map PaletteMsg cmd )

        PaletteAction inner ->
            -- An action that moves no focus of its own (a switch, a setting): the palette
            -- has closed, so focus goes back to where it was before the palette opened.
            let
                ( next, cmd ) =
                    update inner model

                opener =
                    CommandPalette.openedFrom model.palette
            in
            ( next
            , Cmd.batch
                [ cmd
                , if opener == "" then
                    Cmd.none

                  else
                    Dom.focus opener |> Task.attempt (\_ -> NoOp)
                ]
            )

        HitsDebounced ticket ->
            if ticket == model.hitTicket && String.trim (CommandPalette.query model.palette) /= "" then
                searchOrders ticket { model | orderHits = Remote.Loading }

            else
                ( model, Cmd.none )

        HitsLoaded ticket result ->
            if ticket == model.hitTicket then
                ( { model
                    | orderHits =
                        case result of
                            Ok page ->
                                Remote.Loaded (List.map orderHit page.rows)

                            Err error ->
                                Remote.Failed (Problem.toProblem error)
                  }
                , Cmd.none
                )

            else
                ( model, Cmd.none )

        RetryHits ->
            searchOrders model.hitTicket { model | orderHits = Remote.Loading }

        OpenHelp ->
            -- Opened by `?` or from the palette: focus goes back to wherever it was.
            update (OpenHelpFrom "") model

        OpenHelpFrom opener ->
            let
                ( help, cmd ) =
                    ShortcutHelp.open opener model.help
            in
            ( { model | help = help }, Cmd.map HelpMsg cmd )

        HelpMsg inner ->
            let
                ( help, cmd ) =
                    ShortcutHelp.update inner model.help
            in
            ( { model | help = help }, Cmd.map HelpMsg cmd )

        OpenTools ->
            let
                ( tools, cmd ) =
                    Drawer.open toolsOpenerId model.tools
            in
            ( { model | tools = tools }, Cmd.map ToolsMsg cmd )

        CloseTools ->
            let
                ( tools, cmd ) =
                    Drawer.close model.tools
            in
            ( { model | tools = tools }, Cmd.map ToolsMsg cmd )

        ToolsMsg inner ->
            let
                ( tools, cmd ) =
                    Drawer.update inner model.tools
            in
            ( { model | tools = tools }, Cmd.map ToolsMsg cmd )

        SetMode mode ->
            ( { model | backend = Api.setMode mode model.backend }, Cmd.none )

        SetLatency latency ->
            ( { model | backend = Api.setLatency latency model.backend }, Cmd.none )

        SetDataset dataset ->
            resetPages { model | backend = Api.setDataset dataset model.backend }

        ResetPages ->
            resetPages model

        OverviewMsg inner ->
            let
                ( page, backend, cmd ) =
                    Overview.update (pageContext model) inner model.backend model.overview

                ( drained, effects ) =
                    Overview.takeEffects page
            in
            applyEffects effects { model | overview = drained, backend = backend } (Cmd.map OverviewMsg cmd)

        OrdersMsg inner ->
            let
                ( page, backend, cmd ) =
                    Orders.update (pageContext model) inner model.backend model.orders

                ( drained, effects ) =
                    Orders.takeEffects page

                -- An answer that arrives after the user went to another page
                -- (an order opened by link that could not be loaded) may still
                -- say so, but must not take the user back.
                onScreen =
                    case model.route of
                        Orders ->
                            True

                        OrderDetail _ ->
                            True

                        _ ->
                            False

                allowed =
                    if onScreen then
                        effects

                    else
                        List.filter
                            (\effect ->
                                case effect of
                                    Notify _ _ _ ->
                                        True

                                    _ ->
                                        False
                            )
                            effects
            in
            applyEffects allowed { model | orders = drained, backend = backend } (Cmd.map OrdersMsg cmd)

        ProductsMsg inner ->
            let
                ( page, backend, cmd ) =
                    Products.update (pageContext model) inner model.backend model.products

                ( drained, effects ) =
                    Products.takeEffects page
            in
            applyEffects effects { model | products = drained, backend = backend } (Cmd.map ProductsMsg cmd)

        GalleryMsg inner ->
            let
                ( gallery, cmd ) =
                    Gallery.update inner model.gallery
            in
            ( { model | gallery = gallery }, Cmd.map GalleryMsg cmd )


{-| Goes to a page. Asking for the page the user is already on (the sidebar link of
the current page, say) reloads it like any visit, but does not add another entry
to the history: the Back button would otherwise need as many presses as there were
clicks.
-}
goTo : Nav.Key -> Route -> Route -> String -> Cmd Msg
goTo key current wanted url =
    if wanted == current then
        Nav.replaceUrl key url

    else
        Nav.pushUrl key url


isRouteFragment : Url -> Bool
isRouteFragment url =
    case url.fragment of
        Nothing ->
            True

        Just fragment ->
            fragment == "" || String.startsWith "/" fragment


{-| The orders page, asked before it is left: with unsaved changes in the editor
it opens its "Discard changes?" dialog and the user stays.
-}
heldOrders : Model -> Maybe ( Model, Cmd Msg )
heldOrders model =
    Orders.confirmLeave model.orders
        |> Maybe.map
            (\( orders, cmd ) ->
                ( { model | orders = orders }, Cmd.map OrdersMsg cmd )
            )


{-| Runs what the route needs when the user arrives on it: real pages load their
data again, gallery pages are created the first time.
-}
enter : Route -> Model -> ( Model, Cmd Msg )
enter route model =
    case route of
        Overview ->
            let
                ( page, backend, cmd ) =
                    Overview.init (pageContext model) model.backend
            in
            ( { model | overview = page, backend = backend }, Cmd.map OverviewMsg cmd )

        Orders ->
            let
                -- The table keeps what the user chose (search, filters, sort).
                ( page, backend, cmd ) =
                    Orders.reenter (pageContext model) Nothing model.backend model.orders
            in
            ( { model | orders = page, backend = backend }, Cmd.map OrdersMsg cmd )

        OrderDetail id ->
            let
                ( page, backend, cmd ) =
                    Orders.reenter (pageContext model) (Just id) model.backend model.orders
            in
            ( { model | orders = page, backend = backend }, Cmd.map OrdersMsg cmd )

        Products ->
            let
                ( page, backend, cmd ) =
                    Products.init (pageContext model) model.backend
            in
            ( { model | products = page, backend = backend }, Cmd.map ProductsMsg cmd )

        Components maybeSlug ->
            case maybeSlug |> Maybe.andThen Catalog.fromSlug of
                Just section ->
                    let
                        ( gallery, cmd ) =
                            Gallery.ensure section model.gallery
                    in
                    ( { model | gallery = gallery }, Cmd.map GalleryMsg cmd )

                Nothing ->
                    ( model, Cmd.none )

        NotFound ->
            ( model, Cmd.none )


{-| After the data volume changed, every page loads its data again.
-}
resetPages : Model -> ( Model, Cmd Msg )
resetPages model =
    enter model.route model


applyEffects : List Effect -> Model -> Cmd Msg -> ( Model, Cmd Msg )
applyEffects effects model cmd =
    List.foldl
        (\effect ( current, cmds ) ->
            case effect of
                Notify tone title message ->
                    let
                        -- The pages report failures of an action the user just
                        -- took. A danger toast would stay until closed, on top
                        -- of the buttons of an open drawer or dialog.
                        lasting =
                            if tone == Danger then
                                [ Toast.duration 12000 ]

                            else
                                []

                        ( toasts, toastCmd ) =
                            Toast.push ([ toneAttribute tone, Toast.title title, Toast.message message, Toast.locale current.locale ] ++ lasting) current.toasts
                    in
                    ( { current | toasts = toasts }, Cmd.map ToastMsg toastCmd :: cmds )

                Go route ->
                    ( current, Nav.pushUrl current.key (Route.path route) :: cmds )

                Replace route ->
                    ( current, Nav.replaceUrl current.key (Route.path route) :: cmds )
        )
        ( model, [ cmd ] )
        effects
        |> Tuple.mapSecond Cmd.batch


toneAttribute : Tone -> Toast.Attribute Msg
toneAttribute tone =
    case tone of
        Success ->
            Toast.success

        Warning ->
            Toast.warning

        Danger ->
            Toast.danger

        _ ->
            Toast.info


searchOrders : Int -> Model -> ( Model, Cmd Msg )
searchOrders ticket model =
    let
        query =
            { search = CommandPalette.query model.palette
            , statuses = []
            , sort = Just ( "customer", True )
            , page = 1
            , pageSize = 6
            }

        ( backend, cmd ) =
            Api.listOrders query (HitsLoaded ticket) model.backend
    in
    ( { model | backend = backend }, cmd )


orderHit : Types.Order -> CommandPalette.Item Msg
orderHit order =
    CommandPalette.item (Types.orderIdText order.id ++ " · " ++ order.customer) (GoTo (OrderDetail order.id))
        |> CommandPalette.withIcon Icon.clipboard
        |> CommandPalette.withDescription (Types.orderStatusLabel order.status)
        |> CommandPalette.withId ("order-" ++ Types.orderIdText order.id)



-- SHORTCUTS


shortcuts : List (Shortcut Msg)
shortcuts =
    [ Shortcut.shortcut (Shortcut.mod (Shortcut.char 'k')) "Navigation" "Open the command palette and search" OpenPalette
        |> Shortcut.inInputs
    , Shortcut.shortcut (Shortcut.sequence [ Shortcut.char 'g', Shortcut.char 'h' ]) "Navigation" "Go to the overview" (GoTo Overview)
    , Shortcut.shortcut (Shortcut.sequence [ Shortcut.char 'g', Shortcut.char 'o' ]) "Navigation" "Go to the orders" (GoTo Orders)
    , Shortcut.shortcut (Shortcut.sequence [ Shortcut.char 'g', Shortcut.char 'p' ]) "Navigation" "Go to the products" (GoTo Products)
    , Shortcut.shortcut (Shortcut.sequence [ Shortcut.char 'g', Shortcut.char 'c' ]) "Navigation" "Go to the component gallery" (GoTo (Components Nothing))
    , Shortcut.shortcut (Shortcut.char '[') "View" "Show or hide the sidebar" ToggleSidebarKey
    , Shortcut.shortcut (Shortcut.alt (Shortcut.char 'l')) "View" "Switch the language of the components" ToggleLocale
    , Shortcut.shortcut (Shortcut.sequence [ Shortcut.char 'g', Shortcut.char 'd' ]) "Tools" "Open the developer tools" OpenTools
    , Shortcut.shortcut (Shortcut.char '?') "Help" "Show keyboard shortcuts" OpenHelp
    ]



-- NAVIGATION MENU


routeKey : Route -> String
routeKey route =
    case route of
        Overview ->
            "overview"

        Orders ->
            "orders"

        OrderDetail _ ->
            "orders"

        Products ->
            "products"

        Components Nothing ->
            "components"

        Components (Just slug) ->
            "components-" ++ slug

        NotFound ->
            ""


{-| The title of the browser tab: the name of the page.
-}
routeTitle : Route -> String
routeTitle route =
    case route of
        Components (Just slug) ->
            -- Each component page has a name of its own.
            case Catalog.fromSlug slug of
                Just section ->
                    Catalog.title section

                Nothing ->
                    Route.title route

        _ ->
            Route.title route


menu : List (SideNav.Entry String Msg)
menu =
    [ SideNav.section "Workspace"
        [ SideNav.item Ids.string { key = "overview", label = "Overview", href = Route.path Overview }
            |> SideNav.withIcon Icon.home
        , SideNav.item Ids.string { key = "orders", label = "Orders", href = Route.path Orders }
            |> SideNav.withIcon Icon.clipboard
        , SideNav.item Ids.string { key = "products", label = "Products", href = Route.path Products }
            |> SideNav.withIcon Icon.database
        ]
    , SideNav.section "Component library"
        [ SideNav.item Ids.string { key = "components", label = "Overview", href = Route.path (Components Nothing) }
            |> SideNav.withIcon Icon.layers
        , SideNav.group Ids.string
            { key = "components-pages", label = "Components" }
            (List.map
                (\section ->
                    SideNav.item Ids.string
                        { key = "components-" ++ Catalog.slug section
                        , label = Catalog.title section
                        , href = Route.path (Components (Just (Catalog.slug section)))
                        }
                )
                Catalog.all
            )
            |> SideNav.withIcon Icon.grid
        ]
    ]



-- SUBSCRIPTIONS


subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.batch
        [ Shortcut.subscription ShortcutMsg shortcuts model.shortcuts
        , case model.route of
            Overview ->
                Sub.map OverviewMsg (Overview.subscriptions model.overview)

            Orders ->
                Sub.map OrdersMsg (Orders.subscriptions model.orders)

            OrderDetail _ ->
                Sub.map OrdersMsg (Orders.subscriptions model.orders)

            Products ->
                Sub.map ProductsMsg (Products.subscriptions model.products)

            Components maybeSlug ->
                Sub.map GalleryMsg
                    (Gallery.subscriptions (maybeSlug |> Maybe.andThen Catalog.fromSlug) model.gallery)

            NotFound ->
                Sub.none
        ]



-- VIEW


view : Model -> Browser.Document Msg
view model =
    let
        page =
            viewPage model

        overlays =
            page.overlays
                ++ [ viewPalette model
                   , ShortcutHelp.view HelpMsg [ ShortcutHelp.locale model.locale ] shortcuts model.help
                   , viewTools model
                   , Toast.view ToastMsg [ Toast.locale model.locale ] model.toasts
                   ]
    in
    { title = routeTitle model.route ++ " – Klar showcase"
    , body =
        [ -- The stylesheet of the library. It is part of the package, so there is
          -- nothing to link or bundle.
          Klar.stylesheetFor model.settings
        , AppShell.view
            ([ AppShell.state ShellMsg model.shell
             , AppShell.locale model.locale
             , AppShell.settings model.settings
             , AppShell.brand (AppShell.brandLink { name = "Klar", href = Route.path Overview, logo = Just (Icon.sized Icon.Large Icon.layers) })
             , AppShell.sidebar (AppShell.sideNav ShellMsg [ SideNav.entries menu, SideNav.locale model.locale ] model.shell)
             , AppShell.onSearch OpenPalette
             , AppShell.searchPlaceholder "Search orders, pages and components ..."
             , AppShell.actions (topBarActions model)
             , AppShell.userName "Demo user"
             , AppShell.userRole "Operations"
             , AppShell.userMenu (viewUserMenu model)
             , AppShell.onStrayDrop NoOp
             , AppShell.shortcuts (Shortcut.listen ShortcutMsg shortcuts model.shortcuts)
             , AppShell.overlays overlays
             ]
                ++ contentWidth model.route
            )
            [ page.content ]
        ]
    }


contentWidth : Route -> List (AppShell.Attribute Msg)
contentWidth route =
    case route of
        Orders ->
            []

        OrderDetail _ ->
            []

        Products ->
            []

        _ ->
            [ AppShell.contentMaxWidth 1280 ]


viewPage : Model -> Effect.View Msg
viewPage model =
    let
        mapView toMsg pageView =
            { content = Html.map toMsg pageView.content
            , overlays = List.map (Overlay.map toMsg) pageView.overlays
            }

        plain content =
            { content = content, overlays = [] }
    in
    case model.route of
        Overview ->
            mapView OverviewMsg (Overview.view (pageContext model) model.overview)

        Orders ->
            mapView OrdersMsg (Orders.view (pageContext model) model.orders)

        OrderDetail _ ->
            mapView OrdersMsg (Orders.view (pageContext model) model.orders)

        Products ->
            mapView ProductsMsg (Products.view (pageContext model) model.products)

        Components maybeSlug ->
            plain
                (Html.map GalleryMsg
                    (Gallery.view model.settings model.locale (maybeSlug |> Maybe.andThen Catalog.fromSlug) model.gallery)
                )

        NotFound ->
            plain
                (Layout.stack [ Layout.gap 4 ]
                    [ Text.title (routeTitle NotFound)
                    , Alert.view [ Alert.tone Warning ]
                        "The address does not exist. Use the menu, or press Ctrl K to search."
                    , Layout.row [ Layout.gap 2 ]
                        [ Button.view
                            [ Button.primary, Button.icon Icon.home, Button.href (Link.internal (Route.path Overview)) ]
                            "Go to the overview"
                        ]
                    ]
                )


topBarActions : Model -> List (Html Msg)
topBarActions model =
    [ viewDensitySwitch model
    , viewZoneSwitch model
    , SegmentedControl.view
        [ SegmentedControl.ariaLabel "Language of the components"
        , SegmentedControl.size Theme.Small
        , SegmentedControl.options
            [ SegmentedControl.option "en" "EN"
            , SegmentedControl.option "nb" "NO"
            ]
        , SegmentedControl.selected (Just (Locale.toCode model.locale))
        , SegmentedControl.onSelect
            (\code -> Locale.fromCode code |> Maybe.map SetLocale |> Maybe.withDefault NoOp)
        ]
    , Button.iconOnly
        [ Button.ghost
        , Button.id toolsOpenerId
        , Button.onClick OpenTools
        , Button.pressed (Drawer.isOpen model.tools)
        ]
        Icon.sliders
        "Developer tools (g d)"
    , Button.iconOnly
        [ Button.ghost, Button.id helpOpenerId, Button.onClick (OpenHelpFrom helpOpenerId) ]
        Icon.keyboard
        "Keyboard shortcuts (?)"
    ]


{-| The two settings of the application, in the top bar of every page: how tightly
the components are packed, and the time zone of the times they write. Nothing on
a page is told about either: the shell carries the density, and the zone is in
the `Moment`s that the pages make with the settings.
-}
viewDensitySwitch : Model -> Html Msg
viewDensitySwitch model =
    SegmentedControl.view
        [ SegmentedControl.ariaLabel "Density of the components"
        , SegmentedControl.size Theme.Small
        , SegmentedControl.options
            [ SegmentedControl.option "compact" "Compact"
            , SegmentedControl.option "normal" "Normal"
            , SegmentedControl.option "comfortable" "Roomy"
            ]
        , SegmentedControl.selected (Just (densityCode (Settings.density model.settings)))
        , SegmentedControl.onSelect (densityFromCode >> SetDensity)
        ]


densityCode : Density -> String
densityCode density =
    case density of
        Compact ->
            "compact"

        Normal ->
            "normal"

        Comfortable ->
            "comfortable"


densityFromCode : String -> Density
densityFromCode code =
    case code of
        "compact" ->
            Compact

        "comfortable" ->
            Comfortable

        _ ->
            Normal


{-| Where the visitor is, or somewhere else, to see the times move.
-}
type ZoneChoice
    = Browser
    | Utc
    | Tokyo


viewZoneSwitch : Model -> Html Msg
viewZoneSwitch model =
    SegmentedControl.view
        [ SegmentedControl.ariaLabel "Time zone of the times"
        , SegmentedControl.size Theme.Small
        , SegmentedControl.options
            [ SegmentedControl.option "browser" "Local"
            , SegmentedControl.option "utc" "UTC"
            , SegmentedControl.option "tokyo" "Tokyo"
            ]
        , SegmentedControl.selected
            (Just
                (case model.zoneChoice of
                    Browser ->
                        "browser"

                    Utc ->
                        "utc"

                    Tokyo ->
                        "tokyo"
                )
            )
        , SegmentedControl.onSelect (zoneFromCode >> SetZone)
        ]


zoneFromCode : String -> ZoneChoice
zoneFromCode code =
    case code of
        "utc" ->
            Utc

        "tokyo" ->
            Tokyo

        _ ->
            Browser


{-| Puts the chosen zone into the settings. `Browser` waits for `Time.here`: until
it has answered, the settings have no zone and every time says "UTC".
-}
applyZone : Model -> Model
applyZone model =
    let
        settings =
            case ( model.zoneChoice, model.browserZone ) of
                ( Browser, Just zone ) ->
                    Settings.withZone zone model.settings

                ( Browser, Nothing ) ->
                    model.settings

                ( Utc, _ ) ->
                    Settings.withZone Time.utc model.settings

                ( Tokyo, _ ) ->
                    Settings.withZone (Time.customZone 540 []) model.settings
    in
    { model | settings = settings }


toolsOpenerId : String
toolsOpenerId =
    "tools-opener"


helpOpenerId : String
helpOpenerId =
    "help-opener"


viewUserMenu : Model -> Html Msg
viewUserMenu model =
    Menu.view UserMenuMsg
        [ Menu.kebab "User menu"
        , Menu.alignEnd
        , Menu.items
            [ Menu.heading "Demo user"
            , Menu.item "Switch language" ToggleLocale |> Menu.withIcon Icon.globe |> Menu.withShortcut (Shortcut.alt (Shortcut.char 'l'))
            , Menu.item "Keyboard shortcuts" (OpenHelpFrom (Menu.triggerId model.userMenu)) |> Menu.withIcon Icon.keyboard |> Menu.withShortcut (Shortcut.char '?')
            , Menu.item "Developer tools" OpenTools |> Menu.withIcon Icon.sliders |> Menu.withShortcut (Shortcut.sequence [ Shortcut.char 'g', Shortcut.char 'd' ])
            , Menu.separator
            , Menu.item "Sign out" NoOp |> Menu.withIcon Icon.logOut |> Menu.disabledItem
            ]
        ]
        model.userMenu


viewPalette : Model -> Overlay Msg
viewPalette model =
    let
        go label route icon keys =
            CommandPalette.item label (GoTo route)
                |> CommandPalette.withIcon icon
                |> (case keys of
                        Just k ->
                            CommandPalette.withShortcut k

                        Nothing ->
                            identity
                   )
    in
    CommandPalette.view PaletteMsg
        [ CommandPalette.locale model.locale
        , CommandPalette.placeholder "Search pages, actions and orders ..."
        , CommandPalette.sections
            [ CommandPalette.section "Navigation"
                ([ go "Overview" Overview Icon.home (Just (Shortcut.sequence [ Shortcut.char 'g', Shortcut.char 'h' ]))
                 , go "Orders" Orders Icon.clipboard (Just (Shortcut.sequence [ Shortcut.char 'g', Shortcut.char 'o' ]))
                 , go "Products" Products Icon.database (Just (Shortcut.sequence [ Shortcut.char 'g', Shortcut.char 'p' ]))
                 , go "Component library" (Components Nothing) Icon.layers (Just (Shortcut.sequence [ Shortcut.char 'g', Shortcut.char 'c' ]))
                 ]
                    ++ List.map
                        (\section ->
                            go (Catalog.title section) (Components (Just (Catalog.slug section))) (Catalog.icon section) Nothing
                        )
                        Catalog.all
                )
            , CommandPalette.section "Components"
                (List.concatMap
                    (\section ->
                        List.map
                            (\name ->
                                CommandPalette.item name (GoTo (Components (Just (Catalog.slug section))))
                                    |> CommandPalette.withIcon (Catalog.icon section)
                                    |> CommandPalette.withDescription (Catalog.title section)
                                    |> CommandPalette.withId (Catalog.slug section ++ "-" ++ name)
                            )
                            (Catalog.components section)
                    )
                    Catalog.all
                )
            , CommandPalette.section "Actions"
                [ CommandPalette.item "Switch language" (PaletteAction ToggleLocale)
                    |> CommandPalette.withIcon Icon.globe
                    |> CommandPalette.withShortcut (Shortcut.alt (Shortcut.char 'l'))
                , CommandPalette.item "Show keyboard shortcuts" (OpenHelpFrom (CommandPalette.openedFrom model.palette))
                    |> CommandPalette.withIcon Icon.keyboard
                    |> CommandPalette.withShortcut (Shortcut.char '?')
                , CommandPalette.item "Open developer tools" OpenTools
                    |> CommandPalette.withIcon Icon.sliders
                    |> CommandPalette.withShortcut (Shortcut.sequence [ Shortcut.char 'g', Shortcut.char 'd' ])
                , CommandPalette.item "Simulate a network failure" (PaletteAction (SetMode Api.Offline))
                    |> CommandPalette.withIcon Icon.wifiOff
                    |> CommandPalette.withKeywords [ "offline", "error", "disconnect" ]
                , CommandPalette.item "Restore the network" (PaletteAction (SetMode Api.Normal))
                    |> CommandPalette.withIcon Icon.refresh
                , CommandPalette.item "Use the large dataset (2,500 orders)" (PaletteAction (SetDataset Api.Large))
                    |> CommandPalette.withIcon Icon.database
                , CommandPalette.item "Use the small dataset (88 orders)" (PaletteAction (SetDataset Api.Small))
                    |> CommandPalette.withIcon Icon.database
                ]
            , CommandPalette.remote "Orders" model.orderHits
                |> CommandPalette.onRetry RetryHits
            ]
        ]
        model.palette



-- DEVELOPER TOOLS


themeOption : Theme.Theme -> Radio.Option
themeOption theme =
    Radio.option (Theme.key theme) (Theme.name theme)


colorModeKey : Theme.Mode -> String
colorModeKey mode =
    case mode of
        Theme.Light ->
            "light"

        Theme.Dark ->
            "dark"

        Theme.System ->
            "system"


colorModeFromKey : String -> Theme.Mode
colorModeFromKey key =
    case key of
        "dark" ->
            Theme.Dark

        "system" ->
            Theme.System

        _ ->
            Theme.Light


viewTools : Model -> Overlay Msg
viewTools model =
    let
        sim =
            Api.simulation model.backend
    in
    Drawer.view ToolsMsg
        [ Drawer.title "Developer tools"
        , Drawer.subtitle "Control how the simulated network behaves"
        , Drawer.medium
        , Drawer.locale model.locale
        , Drawer.onRequestClose CloseTools
        , Drawer.footer [ Button.view [ Button.onClick CloseTools ] "Close" ]
        ]
        model.tools
        [ Layout.stack [ Layout.gap 5 ]
            [ Alert.view [ Alert.tone Info, Alert.compact ]
                "The backend is a synchronous dummy written in Elm. Every request still goes through a request/response layer with a delay, so you can see how the interface behaves when something goes wrong."
            , Radio.view
                [ Radio.label "Theme"
                , Radio.hint "One of the ten themes of Klar.Theme. An internal application picks one and leaves it."
                , Radio.horizontal
                , Radio.options (List.map themeOption Theme.all)
                , Radio.selected (Just (Theme.key (Settings.theme model.settings)))
                , Radio.onSelect SetTheme
                , Radio.id "tools-theme"
                ]
            , SegmentedControl.view
                [ SegmentedControl.label "Mode"
                , SegmentedControl.hint "System follows the operating system."
                , SegmentedControl.options
                    [ SegmentedControl.option "light" "Light"
                    , SegmentedControl.option "dark" "Dark"
                    , SegmentedControl.option "system" "System"
                    ]
                , SegmentedControl.selected (Just (colorModeKey (Settings.mode model.settings)))
                , SegmentedControl.onSelect SetColorMode
                , SegmentedControl.id "tools-color-mode"
                ]
            , Radio.view
                [ Radio.label "Network"
                , Radio.hint "Applies to the next requests. Try Offline, then reload the data with the button below."
                , Radio.options
                    [ Radio.option "normal" "Normal"
                        |> Radio.withDescription "Everything works."
                    , Radio.option "offline" "Offline"
                        |> Radio.withDescription "No contact with the service (network error)."
                    , Radio.option "server" "Server error"
                        |> Radio.withDescription "The server answers 503."
                    , Radio.option "timeout" "Timeout"
                        |> Radio.withDescription "The server does not answer in time."
                    , Radio.option "flaky" "Flaky"
                        |> Radio.withDescription "Every third request fails."
                    ]
                , Radio.selected (Just (modeKey sim.mode))
                , Radio.onSelect (\key -> SetMode (modeFromKey key))
                , Radio.id "tools-mode"
                ]
            , SegmentedControl.view
                [ SegmentedControl.label "Latency"
                , SegmentedControl.options
                    [ SegmentedControl.option "fast" "Fast"
                    , SegmentedControl.option "typical" "Typical"
                    , SegmentedControl.option "slow" "Slow"
                    ]
                , SegmentedControl.selected (Just (latencyKey sim.latency))
                , SegmentedControl.onSelect (\key -> SetLatency (latencyFromKey key))
                , SegmentedControl.id "tools-latency"
                ]
            , SegmentedControl.view
                [ SegmentedControl.label "Data volume"
                , SegmentedControl.hint "Large gives 2,500 orders, for trying search, sorting and paging. Edits are lost when you switch."
                , SegmentedControl.options
                    [ SegmentedControl.option "small" "Small (88 orders)"
                    , SegmentedControl.option "large" "Large (2,500 orders)"
                    ]
                , SegmentedControl.selected (Just (datasetKey sim.dataset))
                , SegmentedControl.onSelect (\key -> SetDataset (datasetFromKey key))
                , SegmentedControl.id "tools-dataset"
                ]
            , Layout.row [ Layout.gap 2, Layout.alignCenter ]
                [ Badge.view [ Badge.tone Neutral ] (String.fromInt (Api.requestCount model.backend))
                , Text.secondary "requests sent to the backend"
                ]
            , Button.view [ Button.icon Icon.refresh, Button.onClick ResetPages ] "Reload the data of the current page"
            ]
        ]


modeKey : Api.Mode -> String
modeKey mode =
    case mode of
        Api.Normal ->
            "normal"

        Api.Offline ->
            "offline"

        Api.ServerDown ->
            "server"

        Api.Timeouts ->
            "timeout"

        Api.Flaky ->
            "flaky"


modeFromKey : String -> Api.Mode
modeFromKey key =
    case key of
        "offline" ->
            Api.Offline

        "server" ->
            Api.ServerDown

        "timeout" ->
            Api.Timeouts

        "flaky" ->
            Api.Flaky

        _ ->
            Api.Normal


latencyKey : Api.Latency -> String
latencyKey latency =
    case latency of
        Api.Fast ->
            "fast"

        Api.Typical ->
            "typical"

        Api.Slow ->
            "slow"


latencyFromKey : String -> Api.Latency
latencyFromKey key =
    case key of
        "fast" ->
            Api.Fast

        "slow" ->
            Api.Slow

        _ ->
            Api.Typical


datasetKey : Api.Dataset -> String
datasetKey dataset =
    case dataset of
        Api.Small ->
            "small"

        Api.Large ->
            "large"


datasetFromKey : String -> Api.Dataset
datasetFromKey key =
    if key == "large" then
        Api.Large

    else
        Api.Small
