module Main exposing (main)

{-| Supplier onboarding: a five-step flow (company, contacts, delivery terms, pricing rules,
review) built on `Klar.Form`, with price rules in the rule builder, a save that can be refused
by the server (problems tied to fields, a version conflict), a leave guard, and a detail page
where some fields are edited in place.
-}

import Api
import Backend exposing (Named)
import Browser
import Browser.Navigation as Nav
import Domain exposing (..)
import Html exposing (Html)
import Klar
import Klar.Alert as Alert
import Klar.AppShell as AppShell
import Klar.Badge as Badge
import Klar.Button as Button
import Klar.Card as Card
import Klar.ConfirmDialog as ConfirmDialog
import Klar.DescriptionList as DescriptionList
import Klar.EmptyState as EmptyState
import Klar.ErrorState as ErrorState
import Klar.FileDrop as FileDrop
import Klar.Form as Form
import Klar.Form.Layout as FormLayout
import Klar.Icon as Icon
import Klar.Ids as Ids
import Klar.InlineEdit as InlineEdit
import Klar.Layout as Layout
import Klar.LeaveGuard as LeaveGuard exposing (Answer(..))
import Klar.Locale as Locale
import Klar.MultiSelect as MultiSelect
import Klar.Overlay exposing (Overlay)
import Klar.PageHeader as PageHeader
import Klar.Remote as Remote exposing (Remote(..))
import Klar.RemoteView as RemoteView
import Klar.Rule as Rule
import Klar.Select as Select
import Klar.SideNav as SideNav
import Klar.Skeleton as Skeleton
import Klar.Switch as Switch
import Klar.Table as Table
import Klar.Text as Text
import Klar.Theme as Theme
import Klar.Toast as Toast
import PriceRules
import SupplierForm exposing (Fields, Step(..))
import Url exposing (Url)



-- PAGES AND ROUTES


type Page
    = Suppliers
    | NewSupplier
    | SupplierDetail SupplierId
    | EditSupplier SupplierId
    | UnknownPage


pageToPath : Page -> String
pageToPath page =
    case page of
        Suppliers ->
            "#/suppliers"

        NewSupplier ->
            "#/suppliers/new"

        SupplierDetail id ->
            "#/suppliers/" ++ supplierIdToString id

        EditSupplier id ->
            "#/suppliers/" ++ supplierIdToString id ++ "/edit"

        UnknownPage ->
            "#/"


pageFromUrl : Url -> Page
pageFromUrl url =
    case url.fragment |> Maybe.withDefault "" |> String.split "/" |> List.filter (not << String.isEmpty) of
        [] ->
            Suppliers

        [ "suppliers" ] ->
            Suppliers

        [ "suppliers", "new" ] ->
            NewSupplier

        [ "suppliers", id ] ->
            supplierIdFromString id |> Maybe.map SupplierDetail |> Maybe.withDefault UnknownPage

        [ "suppliers", id, "edit" ] ->
            supplierIdFromString id |> Maybe.map EditSupplier |> Maybe.withDefault UnknownPage

        _ ->
            UnknownPage


{-| The entry of the side navigation that a page belongs to.
-}
navPage : Page -> Page
navPage page =
    case page of
        NewSupplier ->
            NewSupplier

        _ ->
            Suppliers


pageKeys : SideNav.Keys Page
pageKeys =
    SideNav.keys
        (\page ->
            case page of
                Suppliers ->
                    "suppliers"

                NewSupplier ->
                    "new"

                SupplierDetail id ->
                    "supplier-" ++ supplierIdToString id

                EditSupplier id ->
                    "edit-" ++ supplierIdToString id

                UnknownPage ->
                    "unknown"
        )


navigation : List (SideNav.Entry Page msg)
navigation =
    [ SideNav.item pageKeys { key = Suppliers, label = "Suppliers", href = pageToPath Suppliers } |> SideNav.withIcon Icon.truck
    , SideNav.item pageKeys { key = NewSupplier, label = "Onboard a supplier", href = pageToPath NewSupplier } |> SideNav.withIcon Icon.plus
    ]



-- THE FORM


declaration : Form.Form Step Fields Profile
declaration =
    SupplierForm.form


f : Fields
f =
    SupplierForm.f


{-| The one source of unsaved changes: the onboarding form and its price rules together.
-}
type Source
    = Onboarding


type Target
    = Create
    | Edit SupplierId (Remote Supplier)


type alias Flow =
    { target : Target
    , form : Form.State Step
    , prices : PriceRules.State
    , status : FormLayout.Status
    , expected : Int
    , conflict : Maybe Supplier
    }


freshFlow : Target -> Flow
freshFlow target =
    { target = target
    , form = Form.init declaration
    , prices = PriceRules.init
    , status = FormLayout.Idle
    , expected = 0
    , conflict = Nothing
    }



-- MODEL


type alias Model =
    { key : Nav.Key
    , page : Page
    , sideNav : SideNav.State Page
    , db : Backend.Db
    , countries : Remote (List (Named CountryId))
    , categories : Remote (List (Named CategoryId))
    , terms : Remote (List (Named PaymentTermsId))
    , suppliers : Remote (List Supplier)
    , table : Table.State SupplierId
    , detail : Remote Supplier
    , detailStale : Maybe Supplier
    , tradingName : InlineEdit.State
    , website : InlineEdit.State
    , flow : Flow
    , guard : LeaveGuard.Guard Source Page
    , confirm : ConfirmDialog.State
    , toasts : Toast.State Msg
    }


type PatchField
    = TradingNameField
    | WebsiteField


type Msg
    = LinkClicked Browser.UrlRequest
    | UrlChanged Url
    | SideNavMsg SideNav.Msg
    | TableMsg Table.Msg
    | ToastMsg Toast.Msg
    | GuardMsg LeaveGuard.Msg
    | ConfirmMsg ConfirmDialog.Msg
    | GotCountries (Result Backend.Failure (List (Named CountryId)))
    | GotCategories (Result Backend.Failure (List (Named CategoryId)))
    | GotTerms (Result Backend.Failure (List (Named PaymentTermsId)))
    | ReloadRefs
    | GotSuppliers (Result Backend.Failure (List Supplier))
    | ReloadSuppliers
    | GotDetail (Result Backend.Failure Supplier)
    | ReloadDetail SupplierId
    | GotEditBase (Result Backend.Failure Supplier)
    | ReloadEdit SupplierId
    | FormMsg Form.Msg
    | PricesMsg PriceRules.Msg
    | Next
    | Retry
    | Back
    | GoToStep Step
    | Saved (Api.Reply Supplier)
    | OverwriteWithMine
    | AskTakeTheirs
    | ConfirmTakeTheirs
    | TradingNameMsg InlineEdit.Msg
    | WebsiteMsg InlineEdit.Msg
    | Patched PatchField (Api.Reply Supplier)
    | UseTheirs
    | SetOffline Bool
    | OtherUserEdits SupplierId
    | SkipToContent
    | NoOp


main : Program () Model Msg
main =
    Browser.application
        { init = init
        , update = update
        , view = view
        , subscriptions = \_ -> Sub.none
        , onUrlRequest = LinkClicked
        , onUrlChange = UrlChanged
        }


init : () -> Url -> Nav.Key -> ( Model, Cmd Msg )
init _ url key =
    let
        page =
            pageFromUrl url

        model =
            { key = key
            , page = page
            , sideNav = SideNav.init "main-nav" |> SideNav.reveal (navPage page) navigation
            , db = Backend.init
            , countries = Loading
            , categories = Loading
            , terms = Loading
            , suppliers = NotAsked
            , table = Table.init "suppliers"
            , detail = NotAsked
            , detailStale = Nothing
            , tradingName = InlineEdit.init "inline-trading-name" ""
            , website = InlineEdit.init "inline-website" ""
            , flow = freshFlow Create
            , guard = LeaveGuard.initAt "leave-dialog" key url
            , confirm = ConfirmDialog.init "take-theirs-dialog"
            , toasts = Toast.init
            }

        ( entered, cmd ) =
            enter page model
    in
    ( entered, Cmd.batch [ cmd, loadRefs ] )


loadRefs : Cmd Msg
loadRefs =
    Cmd.batch [ Api.countries GotCountries, Api.categories GotCategories, Api.paymentTerms GotTerms ]


{-| Show a page: start what it needs. A flow always starts clean when it is entered.
-}
enter : Page -> Model -> ( Model, Cmd Msg )
enter page model =
    let
        base =
            { model | page = page, sideNav = SideNav.reveal (navPage page) navigation model.sideNav }

        done cmd =
            ( syncGuard (syncFlow base), Cmd.batch [ cmd, AppShell.resetScroll "shell" NoOp, AppShell.focusContent "shell" NoOp ] )
    in
    case page of
        Suppliers ->
            { base | suppliers = Loading, flow = freshFlow Create } |> (\m -> ( syncGuard (syncFlow m), Cmd.batch [ Api.loadSuppliers m.db GotSuppliers, AppShell.resetScroll "shell" NoOp, AppShell.focusContent "shell" NoOp ] ))

        NewSupplier ->
            { base | flow = freshFlow Create } |> (\m -> ( syncGuard (syncFlow m), Cmd.batch [ AppShell.resetScroll "shell" NoOp, AppShell.focusContent "shell" NoOp ] ))

        SupplierDetail id ->
            { base | detail = Loading, detailStale = Nothing, flow = freshFlow Create }
                |> (\m -> ( syncGuard (syncFlow m), Cmd.batch [ Api.loadSupplier m.db id GotDetail, AppShell.resetScroll "shell" NoOp, AppShell.focusContent "shell" NoOp ] ))

        EditSupplier id ->
            { base | flow = freshFlow (Edit id Loading) }
                |> (\m -> ( syncGuard (syncFlow m), Cmd.batch [ Api.loadSupplier m.db id GotEditBase, AppShell.resetScroll "shell" NoOp, AppShell.focusContent "shell" NoOp ] ))

        UnknownPage ->
            done Cmd.none


failureProblem : Backend.Failure -> Remote.Problem
failureProblem failure =
    case failure of
        Backend.Down ->
            Remote.problem Remote.server

        Backend.Invalid _ ->
            Remote.problem Remote.validation

        Backend.Conflict _ ->
            Remote.problem Remote.conflict

        Backend.Gone ->
            Remote.problem Remote.notFound


remote : Result Backend.Failure a -> Remote a
remote =
    Result.mapError failureProblem >> Remote.fromResult


{-| Keep the parts that live outside the form in step with it: the problems of the price rules
go into the form, the price rules show their issues once their step was tried, and the leave
guard knows whether anything is unsaved.
-}
syncFlow : Model -> Model
syncFlow model =
    let
        flow =
            model.flow

        attempted =
            Form.attempted declaration Pricing flow.form

        prices =
            PriceRules.setAttempted attempted flow.prices

        form =
            Form.outside declaration (PriceRules.problems Locale.default (ruleFields model) prices) flow.form
    in
    { model
        | flow = { flow | prices = prices, form = form }
    }


ruleFields : Model -> List (Rule.Field ())
ruleFields model =
    PriceRules.fieldsFor
        { categories = Remote.withDefault [] (optionsOf model.categories)
        , countries = Remote.withDefault [] (optionsOf model.countries)
        }


optionsOf : Remote (List (Named id)) -> Remote (List (Select.Option id))
optionsOf =
    Remote.map (List.map (\named -> Select.option named.id named.name))


nameOf : Remote (List (Named id)) -> id -> String
nameOf refs id =
    Remote.withDefault [] refs
        |> List.filter (\named -> named.id == id)
        |> List.head
        |> Maybe.map .name
        |> Maybe.withDefault "…"



-- UPDATE


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    updateInner msg model
        |> Tuple.mapFirst
            (\next ->
                if changesFlow msg then
                    syncGuard (syncFlow next)

                else
                    syncFlow next
            )


{-| The messages after which the leave guard has to be told again whether something is unsaved.
Not after every message: "Leave" makes the guard forget what was dirty, and telling it again
before the page has changed would make it ask a second time.
-}
changesFlow : Msg -> Bool
changesFlow msg =
    case msg of
        FormMsg _ ->
            True

        PricesMsg _ ->
            True

        GotEditBase _ ->
            True

        ReloadEdit _ ->
            True

        ConfirmTakeTheirs ->
            True

        Saved _ ->
            True

        _ ->
            False


syncGuard : Model -> Model
syncGuard model =
    { model
        | guard =
            LeaveGuard.setDirty Onboarding
                (Form.isDirty model.flow.form || PriceRules.isDirty model.flow.prices)
                model.guard
    }


mapFlow : (Flow -> Flow) -> Model -> Model
mapFlow change model =
    { model | flow = change model.flow }


updateInner : Msg -> Model -> ( Model, Cmd Msg )
updateInner msg model =
    case msg of
        LinkClicked (Browser.Internal url) ->
            case LeaveGuard.request (pageFromUrl url) model.guard of
                Proceed page ->
                    ( model, Nav.pushUrl model.key (pageToPath page) )

                Hold guard cmd ->
                    ( { model | guard = guard }, Cmd.map GuardMsg cmd )

        LinkClicked (Browser.External href) ->
            ( model, Nav.load href )

        UrlChanged url ->
            -- also the browser's Back and Forward: with unsaved input the guard keeps the page and asks
            case LeaveGuard.onUrlChange pageFromUrl url model.guard of
                ( guard, cmd, Just page ) ->
                    enter page { model | guard = guard }
                        |> Tuple.mapSecond (\enterCmd -> Cmd.batch [ Cmd.map GuardMsg cmd, enterCmd ])

                ( guard, cmd, Nothing ) ->
                    ( { model | guard = guard }, Cmd.map GuardMsg cmd )

        GuardMsg inner ->
            let
                ( guard, cmd, decision ) =
                    LeaveGuard.update inner model.guard

                next =
                    { model | guard = guard }
            in
            case decision of
                Nothing ->
                    ( next, Cmd.map GuardMsg cmd )

                Just answer ->
                    -- "Leave": the changes are given up
                    ( { next | flow = freshFlow Create }
                    , Cmd.batch [ Cmd.map GuardMsg cmd, Nav.pushUrl model.key (pageToPath (LeaveGuard.destination answer)) ]
                    )

        SideNavMsg inner ->
            let
                ( sideNav, cmd ) =
                    SideNav.update inner model.sideNav
            in
            ( { model | sideNav = sideNav }, Cmd.map SideNavMsg cmd )

        TableMsg inner ->
            let
                ( table, cmd ) =
                    Table.update inner model.table
            in
            ( { model | table = table }, Cmd.map TableMsg cmd )

        ToastMsg inner ->
            let
                ( toasts, cmd ) =
                    Toast.update inner model.toasts
            in
            ( { model | toasts = toasts }, Cmd.map ToastMsg cmd )

        ConfirmMsg inner ->
            let
                ( confirm, cmd ) =
                    ConfirmDialog.update inner model.confirm
            in
            ( { model | confirm = confirm }, Cmd.map ConfirmMsg cmd )

        SkipToContent ->
            ( model, AppShell.focusContent "shell" NoOp )

        GotCountries result ->
            ( { model | countries = remote result }, Cmd.none )

        GotCategories result ->
            ( { model | categories = remote result }, Cmd.none )

        GotTerms result ->
            ( { model | terms = remote result }, Cmd.none )

        ReloadRefs ->
            ( { model | countries = Loading, categories = Loading, terms = Loading }, loadRefs )

        GotSuppliers result ->
            ( { model | suppliers = remote result }, Cmd.none )

        ReloadSuppliers ->
            ( { model | suppliers = Loading }, Api.loadSuppliers model.db GotSuppliers )

        GotDetail result ->
            case result of
                Ok supplier ->
                    ( showDetail supplier model, Cmd.none )

                Err failure ->
                    ( { model | detail = Failed (failureProblem failure) }, Cmd.none )

        ReloadDetail id ->
            ( { model | detail = Loading, detailStale = Nothing }, Cmd.batch [ Api.loadSupplier model.db id GotDetail, AppShell.focusContent "shell" NoOp ] )

        UseTheirs ->
            case model.detailStale of
                Just theirs ->
                    ( showDetail theirs { model | detailStale = Nothing }, FormLayout.focusField "inline-trading-name-display" NoOp )

                Nothing ->
                    ( model, Cmd.none )

        GotEditBase result ->
            case ( result, model.flow.target ) of
                ( Ok supplier, Edit id _ ) ->
                    if id == supplier.id then
                        ( mapFlow (loadSupplierInto supplier) model, Cmd.none )

                    else
                        ( model, Cmd.none )

                ( Err failure, Edit id _ ) ->
                    ( mapFlow (\flow -> { flow | target = Edit id (Failed (failureProblem failure)) }) model, Cmd.none )

                _ ->
                    ( model, Cmd.none )

        ReloadEdit id ->
            ( mapFlow (\flow -> { flow | target = Edit id Loading }) model, Cmd.batch [ Api.loadSupplier model.db id GotEditBase, AppShell.focusContent "shell" NoOp ] )

        FormMsg inner ->
            let
                ( form, cmd ) =
                    Form.update declaration inner model.flow.form
            in
            ( mapFlow (\flow -> { flow | form = form, status = idleUnlessBusy flow.status }) model, Cmd.map FormMsg cmd )

        PricesMsg inner ->
            let
                ( prices, cmd ) =
                    PriceRules.update inner model.flow.prices
            in
            ( mapFlow (\flow -> { flow | prices = prices, status = idleUnlessBusy flow.status }) model, Cmd.map PricesMsg cmd )

        Next ->
            if model.flow.status == FormLayout.Submitting then
                ( model, Cmd.none )

            else
                let
                    next =
                        Form.advance declaration (syncFlow model).flow.form
                in
                case next.submit of
                    Just profile ->
                        ( mapFlow (\flow -> { flow | form = next.state, status = FormLayout.Submitting }) model
                        , Cmd.batch [ Cmd.map FormMsg next.cmd, send model profile ]
                        )

                    Nothing ->
                        ( mapFlow (\flow -> { flow | form = next.state }) model, Cmd.map FormMsg next.cmd )

        Retry ->
            let
                ( next, cmd ) =
                    updateInner Next model
            in
            ( next, Cmd.batch [ cmd, FormLayout.focusStatus "supplier-form" NoOp ] )

        Back ->
            let
                ( form, cmd ) =
                    Form.back declaration model.flow.form
            in
            ( mapFlow (\flow -> { flow | form = form }) model, Cmd.map FormMsg cmd )

        GoToStep step ->
            let
                ( form, cmd ) =
                    Form.goTo declaration step model.flow.form
            in
            ( mapFlow (\flow -> { flow | form = form }) model, Cmd.map FormMsg cmd )

        Saved reply ->
            savedReply reply { model | db = reply.db }

        OverwriteWithMine ->
            case model.flow.conflict of
                Just theirs ->
                    -- the input stays as it is; only the version it is based on moves
                    updateInner Next (mapFlow (\flow -> { flow | expected = theirs.version, conflict = Nothing }) model)

                Nothing ->
                    ( model, Cmd.none )

        AskTakeTheirs ->
            let
                ( confirm, cmd ) =
                    ConfirmDialog.open "take-theirs" model.confirm
            in
            ( { model | confirm = confirm }, Cmd.map ConfirmMsg cmd )

        ConfirmTakeTheirs ->
            let
                ( confirm, cmd ) =
                    ConfirmDialog.close model.confirm

                ( toasts, toastCmd ) =
                    Toast.push [ Toast.info, Toast.message "Loaded the other version. Your changes were discarded." ] model.toasts
            in
            case model.flow.conflict of
                Just theirs ->
                    ( mapFlow (loadSupplierInto theirs) { model | confirm = confirm, toasts = toasts }
                    , Cmd.batch [ Cmd.map ConfirmMsg cmd, Cmd.map ToastMsg toastCmd ]
                    )

                Nothing ->
                    ( { model | confirm = confirm }, Cmd.map ConfirmMsg cmd )

        TradingNameMsg inner ->
            let
                ( state, cmd ) =
                    InlineEdit.update inner model.tradingName

                starts =
                    InlineEdit.isSaving state && not (InlineEdit.isSaving model.tradingName)
            in
            ( { model | tradingName = state }
            , Cmd.batch
                [ Cmd.map TradingNameMsg cmd
                , case ( starts, InlineEdit.pending state ) of
                    ( True, Just text ) ->
                        patch model TradingNameField (Backend.SetTradingName (nonBlank text))

                    _ ->
                        Cmd.none
                ]
            )

        WebsiteMsg inner ->
            let
                ( state, cmd ) =
                    InlineEdit.update inner model.website

                starts =
                    InlineEdit.isSaving state && not (InlineEdit.isSaving model.website)
            in
            ( { model | website = state }
            , Cmd.batch
                [ Cmd.map WebsiteMsg cmd
                , case ( starts, InlineEdit.pending state ) of
                    ( True, Just text ) ->
                        patch model WebsiteField (Backend.SetWebsite (nonBlank text))

                    _ ->
                        Cmd.none
                ]
            )

        Patched field reply ->
            patchedReply field reply { model | db = reply.db }

        SetOffline offline ->
            ( { model | db = Backend.setOffline offline model.db }, Cmd.none )

        OtherUserEdits id ->
            let
                ( toasts, cmd ) =
                    Toast.push [ Toast.warning, Toast.message "Another user changed this supplier on the server." ] model.toasts
            in
            ( { model | db = Backend.otherUserEdits id model.db, toasts = toasts }, Cmd.map ToastMsg cmd )

        NoOp ->
            ( model, Cmd.none )


idleUnlessBusy : FormLayout.Status -> FormLayout.Status
idleUnlessBusy status =
    if status == FormLayout.Submitting then
        status

    else
        FormLayout.Idle


nonBlank : String -> Maybe String
nonBlank text =
    if String.isEmpty (String.trim text) then
        Nothing

    else
        Just (String.trim text)


loadSupplierInto : Supplier -> Flow -> Flow
loadSupplierInto supplier flow =
    { flow
        | target = Edit supplier.id (Loaded supplier)
        , form = SupplierForm.fill supplier.profile (Form.init declaration)
        , prices = PriceRules.load supplier.priceRules PriceRules.init
        , status = FormLayout.Idle
        , expected = supplier.version
        , conflict = Nothing
    }


showDetail : Supplier -> Model -> Model
showDetail supplier model =
    { model
        | detail = Loaded supplier
        , tradingName = InlineEdit.setValue (Maybe.withDefault "" supplier.profile.tradingName) model.tradingName
        , website = InlineEdit.setValue (Maybe.withDefault "" supplier.profile.website) model.website
    }


{-| Send the record the form produced: a new supplier, or a save of an existing one that starts
from the version the user loaded.
-}
send : Model -> Profile -> Cmd Msg
send model profile =
    case model.flow.target of
        Create ->
            Api.createSupplier model.db profile (PriceRules.rules model.flow.prices) Saved

        Edit id _ ->
            Api.updateSupplier model.db id model.flow.expected profile (PriceRules.rules model.flow.prices) Saved


patch : Model -> PatchField -> Backend.Patch -> Cmd Msg
patch model field change =
    case model.detail of
        Loaded supplier ->
            Api.patchSupplier model.db supplier.id supplier.version change (Patched field)

        _ ->
            Cmd.none


savedReply : Api.Reply Supplier -> Model -> ( Model, Cmd Msg )
savedReply reply model =
    if model.flow.status /= FormLayout.Submitting then
        ( model, Cmd.none )

    else
        case reply.result of
            Ok supplier ->
                let
                    ( toasts, toastCmd ) =
                        Toast.push [ Toast.success, Toast.message "Supplier saved." ] model.toasts
                in
                ( mapFlow
                    (\flow ->
                        { flow
                            | form = Form.markClean flow.form
                            , prices = PriceRules.markClean flow.prices
                            , status = FormLayout.Idle
                            , conflict = Nothing
                        }
                    )
                    { model | toasts = toasts }
                , Cmd.batch [ Cmd.map ToastMsg toastCmd, Nav.pushUrl model.key (pageToPath (SupplierDetail supplier.id)) ]
                )

            Err (Backend.Invalid problems) ->
                let
                    synced =
                        syncFlow model

                    flow =
                        synced.flow

                    priceErrors =
                        List.filterMap
                            (\p ->
                                case p.field of
                                    Backend.PriceDiscount i ->
                                        Just ( i, p.message )

                                    _ ->
                                        Nothing
                            )
                            problems

                    prices =
                        PriceRules.serverProblems priceErrors flow.prices

                    outsideProblems =
                        PriceRules.problems Locale.default (ruleFields model) prices

                    withOutside =
                        Form.outside declaration outsideProblems flow.form

                    formProblems =
                        List.filterMap (toFormProblem withOutside) problems

                    ( form, cmd ) =
                        case ( formProblems, outsideProblems ) of
                            ( [], first :: _ ) ->
                                Form.goToProblem declaration first withOutside

                            _ ->
                                Form.rejected formProblems declaration withOutside
                in
                ( { synced | flow = { flow | prices = prices, form = form, status = FormLayout.Idle } }
                , Cmd.map FormMsg cmd
                )

            Err (Backend.Conflict theirs) ->
                ( mapFlow (\flow -> { flow | status = FormLayout.Idle, conflict = Just theirs }) model
                , FormLayout.focusField "conflict-overwrite" NoOp
                )

            Err failure ->
                ( mapFlow (\flow -> { flow | status = FormLayout.Failed (failureProblem failure) }) model, Cmd.none )


toFormProblem : Form.State Step -> Backend.Problem -> Maybe (Form.Problem Step)
toFormProblem state problem =
    case problem.field of
        Backend.LegalName ->
            Just (Form.problem f.legalName problem.message)

        Backend.TradingName ->
            Just (Form.problem f.tradingName problem.message)

        Backend.OrgNumber ->
            Just (Form.problem f.orgNumber problem.message)

        Backend.Website ->
            Just (Form.problem f.website problem.message)

        Backend.ContactEmail position ->
            Form.rowFields f.contacts state
                |> List.drop position
                |> List.head
                |> Maybe.map (\row -> Form.problem row.email problem.message)

        Backend.PriceDiscount _ ->
            Nothing


patchedReply : PatchField -> Api.Reply Supplier -> Model -> ( Model, Cmd Msg )
patchedReply field reply model =
    let
        failWith problem =
            case field of
                TradingNameField ->
                    { model | tradingName = InlineEdit.failed problem model.tradingName }

                WebsiteField ->
                    { model | website = InlineEdit.failed problem model.website }
    in
    case reply.result of
        Ok supplier ->
            let
                settled =
                    case field of
                        TradingNameField ->
                            { model | tradingName = InlineEdit.saved model.tradingName }

                        WebsiteField ->
                            { model | website = InlineEdit.saved model.website }
            in
            ( { settled | detail = Loaded supplier }, Cmd.none )

        Err (Backend.Invalid (first :: _)) ->
            ( failWith (Remote.problem Remote.validation |> Remote.withTitle first.message), Cmd.none )

        Err (Backend.Conflict theirs) ->
            let
                failed =
                    failWith conflictProblem
            in
            ( { failed | detailStale = Just theirs }, Cmd.none )

        Err failure ->
            ( failWith (failureProblem failure), Cmd.none )


conflictProblem : Remote.Problem
conflictProblem =
    Remote.problem Remote.conflict |> Remote.withTitle "Someone else changed this supplier. Load their version to continue."



-- VIEW


view : Model -> Browser.Document Msg
view model =
    { title = "Supplier onboarding"
    , body =
        [ Klar.stylesheet
        , AppShell.view
            [ AppShell.id "shell"
            , AppShell.brand (AppShell.brandLink { name = "Supplier onboarding", href = "#/", logo = Nothing })
            , AppShell.sidebar (SideNav.view SideNavMsg [ SideNav.entries navigation, SideNav.current (navPage model.page) ] model.sideNav)
            , AppShell.onSkipToContent SkipToContent
            , AppShell.onStrayDrop NoOp
            , AppShell.overlays (overlays model)
            ]
            [ viewPage model ]
        ]
    }


overlays : Model -> List (Overlay Msg)
overlays model =
    [ LeaveGuard.view GuardMsg
        [ LeaveGuard.title "Leave without saving?"
        , LeaveGuard.message "The supplier you are filling in is not saved. What you have typed is lost."
        ]
        model.guard
    , ConfirmDialog.view ConfirmMsg
        [ ConfirmDialog.danger
        , ConfirmDialog.title "Discard your changes?"
        , ConfirmDialog.message "Your input is replaced by the version someone else saved."
        , ConfirmDialog.confirmLabel "Load their version"
        , ConfirmDialog.onConfirm ConfirmTakeTheirs
        ]
        model.confirm
    , Toast.view ToastMsg [] model.toasts
    ]


viewPage : Model -> Html Msg
viewPage model =
    case model.page of
        Suppliers ->
            viewSuppliers model

        NewSupplier ->
            viewFlow model

        SupplierDetail id ->
            viewDetail id model

        EditSupplier _ ->
            case model.flow.target of
                Edit _ (Loaded _) ->
                    viewFlow model

                Edit id (Failed problem) ->
                    Layout.stack []
                        [ PageHeader.view [ PageHeader.title "Edit supplier" ]
                        , ErrorState.view [ ErrorState.onRetry (ReloadEdit id) ] problem
                        ]

                _ ->
                    Layout.stack []
                        [ PageHeader.view [ PageHeader.title "Edit supplier" ]
                        , Card.view [] [ Skeleton.lines 6 ]
                        ]

        UnknownPage ->
            Layout.stack []
                [ PageHeader.view [ PageHeader.title "Page not found" ]
                , Button.view [ Button.href (pageToPath Suppliers) ] "Back to the suppliers"
                ]



-- THE LIST


supplierRowIds : Table.RowIds SupplierId
supplierRowIds =
    Table.rowIds { toKey = supplierIdToString, fromKey = supplierIdFromString }


viewSuppliers : Model -> Html Msg
viewSuppliers model =
    Layout.stack []
        [ PageHeader.view
            [ PageHeader.title "Suppliers"
            , PageHeader.actions [ Button.view [ Button.primary, Button.icon Icon.plus, Button.href (pageToPath NewSupplier) ] "Onboard a supplier" ]
            ]
        , Table.view TableMsg
            [ Table.columns
                [ Table.text (Table.columnId "name") "Supplier" (.profile >> .legalName) [ Table.pinned, Table.filterText ]
                , Table.text (Table.columnId "country") "Country" (\s -> nameOf model.countries s.profile.country) [ Table.filterSelect ]
                , Table.text (Table.columnId "terms") "Payment terms" (\s -> nameOf model.terms s.profile.paymentTerms) []
                , Table.int (Table.columnId "contacts") "Contacts" (.profile >> .contacts >> List.length) []
                , Table.int (Table.columnId "rules") "Price rules" (.priceRules >> List.length) []
                , Table.int (Table.columnId "version") "Version" .version []
                , Table.actions (Table.columnId "open")
                    "Actions"
                    (\s -> [ Button.view [ Button.small, Button.ghost, Button.ariaLabel ("Open " ++ s.profile.legalName), Button.href (pageToPath (SupplierDetail s.id)) ] "Open" ])
                    [ Table.width 90 ]
                ]
            , Table.rows model.suppliers
            , Table.rowId supplierRowIds .id
            , Table.rowLabel (.profile >> .legalName)
            , Table.label "Suppliers"
            , Table.onRetry ReloadSuppliers
            , Table.searchable
            , Table.emptyState [ EmptyState.title "No suppliers yet", EmptyState.description "Onboard the first one." ]
            ]
            model.table
        , demoCard
            [ Switch.view
                [ Switch.id "demo-offline"
                , Switch.label "Simulate a server outage"
                , Switch.description "Requests and saves fail until you switch it off."
                , Switch.checked model.db.offline
                , Switch.onToggle SetOffline
                ]
            ]
        ]


demoCard : List (Html Msg) -> Html Msg
demoCard content =
    Card.view [ Card.title "Demo controls", Card.sunken, Card.headingLevel 2 ] [ Layout.stack [] content ]



-- THE DETAIL PAGE, with fields edited in place


viewDetail : SupplierId -> Model -> Html Msg
viewDetail id model =
    Layout.stack []
        (loadingHeader model.detail
            :: RemoteView.view [ RemoteView.onRetry (ReloadDetail id) ]
            model.detail
            (\supplier ->
                [ PageHeader.view
                    [ PageHeader.title supplier.profile.legalName
                    , PageHeader.subtitle ("Organisation number " ++ supplier.profile.orgNumber)
                    , PageHeader.badges [ Badge.view [ Badge.tone Theme.Neutral ] ("Version " ++ String.fromInt supplier.version) ]
                    , PageHeader.backLink { href = pageToPath Suppliers, label = "Suppliers" }
                    , PageHeader.actions [ Button.view [ Button.primary, Button.icon Icon.edit, Button.href (pageToPath (EditSupplier supplier.id)) ] "Edit supplier" ]
                    ]
                , case model.detailStale of
                    Just _ ->
                        Alert.view
                            [ Alert.tone Theme.Warning
                            , Alert.title "Someone else changed this supplier"
                            , Alert.actions [ Button.view [ Button.id "use-theirs", Button.onClick UseTheirs ] "Load their version" ]
                            ]
                            "Your edit was not saved. Load their version and edit again."

                    Nothing ->
                        Html.text ""
                , Card.view [ Card.title "Company", Card.headingLevel 2 ]
                    [ DescriptionList.view [ DescriptionList.columns 2 ]
                        [ DescriptionList.text "Legal name" supplier.profile.legalName
                        , DescriptionList.html "Trading name"
                            (InlineEdit.view TradingNameMsg
                                [ InlineEdit.label "Trading name"
                                , InlineEdit.emptyText "Add a trading name"
                                , InlineEdit.maxLength 80
                                ]
                                model.tradingName
                            )
                        , DescriptionList.text "Country" (nameOf model.countries supplier.profile.country)
                        , DescriptionList.html "Website"
                            (InlineEdit.view WebsiteMsg
                                [ InlineEdit.label "Website"
                                , InlineEdit.emptyText "Add a website"
                                , InlineEdit.validate websiteRule
                                ]
                                model.website
                            )
                        , DescriptionList.text "Categories" (names model.categories supplier.profile.categories)
                        , DescriptionList.text "Certifications" (listOrNone supplier.profile.certifications)
                        ]
                    ]
                , Card.view [ Card.title "Contacts", Card.headingLevel 2 ]
                    [ DescriptionList.view [ DescriptionList.columns 2 ]
                        (List.map
                            (\c ->
                                DescriptionList.text
                                    (c.name
                                        ++ (if c.primary then
                                                " (primary)"

                                            else
                                                ""
                                           )
                                    )
                                    (c.email ++ Maybe.withDefault "" (Maybe.map (\p -> ", " ++ p) c.phone))
                            )
                            supplier.profile.contacts
                        )
                    ]
                , Card.view [ Card.title "Delivery terms", Card.headingLevel 2 ]
                    [ DescriptionList.view [ DescriptionList.columns 2 ]
                        (deliveryItems model supplier.profile)
                    ]
                , Card.view [ Card.title "Price rules", Card.headingLevel 2 ]
                    [ priceRuleList model supplier.priceRules ]
                , demoCard
                    [ Button.view [ Button.id "demo-other-user", Button.onClick (OtherUserEdits supplier.id) ] "Simulate: someone else edits this supplier" ]
                ]
            )
        )


websiteRule : String -> Maybe String
websiteRule text =
    if text == "" || String.startsWith "http://" text || String.startsWith "https://" text then
        Nothing

    else
        Just "Start with http:// or https://"


names : Remote (List (Named id)) -> List id -> String
names refs ids =
    ids |> List.map (nameOf refs) |> listOrNone


listOrNone : List String -> String
listOrNone items =
    if List.isEmpty items then
        "None"

    else
        String.join ", " items


deliveryItems : Model -> Profile -> List (DescriptionList.Item Msg)
deliveryItems model profile =
    [ DescriptionList.text "Payment terms" (nameOf model.terms profile.paymentTerms)
    , DescriptionList.text "Delivers to" (names model.countries profile.deliveryCountries)
    , DescriptionList.text "Lead time" (String.fromFloat profile.leadTimeDays ++ " days")
    , DescriptionList.text "Minimum order value" (profile.minOrderValue |> Maybe.map (\v -> String.fromFloat v ++ " EUR") |> Maybe.withDefault "None")
    , DescriptionList.text "Contract" profile.contract.name
    , DescriptionList.maybe "Notes" profile.notes
    ]


priceRuleList : Model -> List PriceRule -> Html Msg
priceRuleList model priceRules =
    if List.isEmpty priceRules then
        Text.secondary "No price rules."

    else
        Html.ul []
            (List.map (\r -> Html.li [] [ Text.text (PriceRules.sentence Locale.default (ruleFields model) r) ]) priceRules)



-- THE FLOW


viewFlow : Model -> Html Msg
viewFlow model =
    let
        flow =
            model.flow

        v =
            Form.bind Locale.default FormMsg declaration flow.form

        step =
            Form.currentStep declaration flow.form

        editing =
            flow.target /= Create

        attributes =
            [ FormLayout.id "supplier-form", FormLayout.onSubmit Next, FormLayout.onRetry Retry ]

        busy =
            flow.status == FormLayout.Submitting
    in
    Layout.stack []
        [ PageHeader.view
            [ PageHeader.title
                (if editing then
                    "Edit supplier"

                 else
                    "Onboard a supplier"
                )
            , PageHeader.backLink { href = pageToPath Suppliers, label = "Suppliers" }
            ]
        , Form.stepper v []
        , viewConflict model
        , Card.view []
            [ FormLayout.view attributes
                [ Form.summary v
                , case step of
                    Just Company ->
                        viewCompany model v

                    Just Contacts ->
                        viewContacts model v

                    Just Delivery ->
                        viewDelivery model v

                    Just Pricing ->
                        viewPricing model

                    _ ->
                        viewReview model
                , FormLayout.actions
                    [ Button.view [ Button.id "cancel-flow", Button.ghost, Button.href (pageToPath Suppliers) ] "Cancel"
                    , FormLayout.unsavedFlag [] (Form.isDirty flow.form || PriceRules.isDirty flow.prices)
                    , FormLayout.status attributes flow.status
                    , Layout.spacer
                    , if step == Just Company then
                        Html.text ""

                      else
                        Button.view [ Button.id "step-back", Button.disabled busy, Button.onClick Back ] "Back"
                    , Button.view
                        [ Button.id "step-next"
                        , Button.primary
                        , Button.submit
                        , Button.loading busy
                        ]
                        (if step == Just Review then
                            if editing then
                                "Save changes"

                            else
                                "Create supplier"

                         else
                            "Next"
                        )
                    ]
                ]
            ]
        , case flow.target of
            Edit id _ ->
                demoCard [ Button.view [ Button.id "demo-other-user", Button.onClick (OtherUserEdits id) ] "Simulate: someone else edits this supplier" ]

            Create ->
                Html.text ""
        ]


viewConflict : Model -> Html Msg
viewConflict model =
    case ( model.flow.conflict, model.flow.target ) of
        ( Just theirs, Edit _ (Loaded base) ) ->
            let
                changed =
                    changedByOthers base theirs
            in
            Alert.viewWith
                [ Alert.tone Theme.Danger
                , Alert.title "Someone else saved this supplier first"
                , Alert.actions
                    [ Button.view [ Button.id "conflict-overwrite", Button.primary, Button.onClick OverwriteWithMine ] "Save my version over theirs"
                    , Button.view [ Button.id "conflict-theirs", Button.onClick AskTakeTheirs ] "Load their version"
                    ]
                ]
                [ Text.paragraph
                    ("You started from version "
                        ++ String.fromInt base.version
                        ++ ", the saved record is at version "
                        ++ String.fromInt theirs.version
                        ++ ". Changed by them: "
                        ++ listOrNone changed
                        ++ ". Your input is still here."
                    )
                ]

        _ ->
            Html.text ""


changedByOthers : Supplier -> Supplier -> List String
changedByOthers a b =
    [ ( "legal name", a.profile.legalName /= b.profile.legalName )
    , ( "trading name", a.profile.tradingName /= b.profile.tradingName )
    , ( "organisation number", a.profile.orgNumber /= b.profile.orgNumber )
    , ( "country", a.profile.country /= b.profile.country )
    , ( "website", a.profile.website /= b.profile.website )
    , ( "categories", a.profile.categories /= b.profile.categories )
    , ( "certifications", a.profile.certifications /= b.profile.certifications )
    , ( "contacts", a.profile.contacts /= b.profile.contacts )
    , ( "payment terms", a.profile.paymentTerms /= b.profile.paymentTerms )
    , ( "delivery countries", a.profile.deliveryCountries /= b.profile.deliveryCountries )
    , ( "lead time", a.profile.leadTimeDays /= b.profile.leadTimeDays )
    , ( "minimum order value", a.profile.minOrderValue /= b.profile.minOrderValue )
    , ( "contract", a.profile.contract /= b.profile.contract )
    , ( "notes", a.profile.notes /= b.profile.notes )
    , ( "price rules", a.priceRules /= b.priceRules )
    ]
        |> List.filter Tuple.second
        |> List.map Tuple.first


viewCompany : Model -> Form.View Msg -> Html Msg
viewCompany model v =
    FormLayout.section "Company"
        "Who the supplier is and what it sells."
        [ FormLayout.grid 2
            [ Form.textInput v f.legalName []
            , Form.textInput v f.tradingName []
            , Form.textInput v f.orgNumber []
            , Form.select v f.country (optionsOf model.countries) [ Select.onRetry ReloadRefs ]
            , FormLayout.fullRow (Form.textInput v f.website [])
            , FormLayout.fullRow (Form.multiSelect v f.categories (optionsOf model.categories) [ MultiSelect.onRetry ReloadRefs ])
            , FormLayout.fullRow (Form.tagInput v f.certifications [])
            ]
        ]


viewContacts : Model -> Form.View Msg -> Html Msg
viewContacts model v =
    FormLayout.section "Contacts"
        "The people we talk to. Exactly one is the primary contact."
        [ Layout.stack []
            (List.indexedMap
                (\i row ->
                    Card.view
                        [ Card.title ("Contact " ++ String.fromInt (i + 1))
                        , Card.headingLevel 3
                        , Card.actions [ Form.removeRow v f.contacts i [] ]
                        ]
                        [ FormLayout.grid 2
                            [ Form.textInput v row.name []
                            , Form.textInput v row.email []
                            , Form.textInput v row.phone []
                            , Form.switch v row.primary []
                            ]
                        ]
                )
                (Form.rowFields f.contacts model.flow.form)
                ++ [ Form.addRow v f.contacts [ Button.icon Icon.plus ] "Add contact" ]
            )
        ]


viewDelivery : Model -> Form.View Msg -> Html Msg
viewDelivery model v =
    FormLayout.section "Delivery terms"
        "How the supplier delivers and gets paid."
        [ FormLayout.grid 2
            [ Form.select v f.paymentTerms (optionsOf model.terms) [ Select.onRetry ReloadRefs ]
            , Form.numberInput v f.leadTimeDays []
            , FormLayout.fullRow (Form.multiSelect v f.deliveryCountries (optionsOf model.countries) [ MultiSelect.onRetry ReloadRefs ])
            , Form.numberInput v f.minOrderValue []
            , FormLayout.fullRow
                (Form.fileDrop v
                    f.contract
                    [ FileDrop.accept [ "application/pdf" ], FileDrop.maxSize 5000000, FileDrop.maxFiles 1 ]
                )
            , FormLayout.fullRow (Form.textArea v f.notes [])
            ]
        ]


viewPricing : Model -> Html Msg
viewPricing model =
    FormLayout.section "Pricing rules"
        "Volume discounts: if an order matches the conditions, the supplier gives the discount."
        [ case ( model.categories, model.countries ) of
            ( Loaded _, Loaded _ ) ->
                PriceRules.view PricesMsg Locale.default (ruleFields model) model.flow.prices

            ( Failed problem, _ ) ->
                ErrorState.view [ ErrorState.compact, ErrorState.onRetry ReloadRefs ] problem

            ( _, Failed problem ) ->
                ErrorState.view [ ErrorState.compact, ErrorState.onRetry ReloadRefs ] problem

            _ ->
                Skeleton.lines 4
        ]


viewReview : Model -> Html Msg
viewReview model =
    let
        state =
            model.flow.form

        get field =
            Form.get field state

        section title step items =
            Card.view
                [ Card.title title
                , Card.headingLevel 2
                , Card.actions [ Button.view [ Button.small, Button.onClick (GoToStep step) ] ("Edit " ++ String.toLower title) ]
                ]
                [ items ]

        optional text =
            if String.isEmpty (String.trim text) then
                "None"

            else
                text
    in
    Layout.stack []
        [ Text.paragraph "Check everything before you save. Problems are listed above; each one takes you to the field."
        , section "Company"
            Company
            (DescriptionList.view [ DescriptionList.columns 2 ]
                [ DescriptionList.text "Legal name" (optional (get f.legalName))
                , DescriptionList.text "Trading name" (optional (get f.tradingName))
                , DescriptionList.text "Organisation number" (optional (get f.orgNumber))
                , DescriptionList.text "Country" (get f.country |> Maybe.map (nameOf model.countries) |> Maybe.withDefault "None")
                , DescriptionList.text "Website" (optional (get f.website))
                , DescriptionList.text "Categories" (names model.categories (get f.categories))
                , DescriptionList.text "Certifications" (listOrNone (get f.certifications))
                ]
            )
        , section "Contacts"
            Contacts
            (Html.ul []
                (Form.rowFields f.contacts state
                    |> List.map
                        (\row ->
                            Html.li []
                                [ Text.text
                                    (Form.get row.name state
                                        ++ ", "
                                        ++ Form.get row.email state
                                        ++ (if Form.get row.primary state then
                                                " (primary)"

                                            else
                                                ""
                                           )
                                    )
                                ]
                        )
                )
            )
        , section "Delivery terms"
            Delivery
            (DescriptionList.view [ DescriptionList.columns 2 ]
                [ DescriptionList.text "Payment terms" (get f.paymentTerms |> Maybe.map (nameOf model.terms) |> Maybe.withDefault "None")
                , DescriptionList.text "Delivers to" (names model.countries (get f.deliveryCountries))
                , DescriptionList.text "Lead time" (get f.leadTimeDays |> Maybe.map (\d -> String.fromFloat d ++ " days") |> Maybe.withDefault "None")
                , DescriptionList.text "Minimum order value" (get f.minOrderValue |> Maybe.map (\x -> String.fromFloat x ++ " EUR") |> Maybe.withDefault "None")
                , DescriptionList.text "Contract" (get f.contract |> List.map .name |> listOrNone)
                , DescriptionList.text "Notes" (optional (get f.notes))
                ]
            )
        , section "Pricing rules"
            Pricing
            (priceRuleList model (PriceRules.rules model.flow.prices))
        ]


{-| The page needs a title (an h1) also while the supplier is loading or failed.
-}
loadingHeader : Remote Supplier -> Html Msg
loadingHeader detail =
    case detail of
        Loaded _ ->
            Html.text ""

        Kept _ ->
            Html.text ""

        _ ->
            PageHeader.view [ PageHeader.title "Supplier", PageHeader.backLink { href = pageToPath Suppliers, label = "Suppliers" } ]
