module Page.Gallery exposing (Model, Msg, ensure, init, subscriptions, update, view)

{-| The component gallery: the index and one page per component group. A page is
created the first time it is visited and then kept, so its state (filters, open
dialogs, typed text) survives navigating away.

Every page has the same shape (see `Page.Gallery.Foundations`): `Model`, `Msg`,
`init`, `update`, `view` and `subscriptions`, which is what keeps this module
mechanical.

-}

import Html exposing (Html)
import Klar.Locale exposing (Locale)
import Klar.Settings exposing (Settings)
import Page.Gallery.Access as Access
import Page.Gallery.Actions as Actions
import Page.Gallery.Arranging as Arranging
import Page.Gallery.Basics as Basics
import Page.Gallery.Catalog as Catalog exposing (Section(..))
import Page.Gallery.DataDisplay as DataDisplay
import Page.Gallery.DateTime as DateTime
import Page.Gallery.Examples as Examples
import Page.Gallery.Flow as Flow
import Page.Gallery.FormModel as FormModel
import Page.Gallery.Forms as Forms
import Page.Gallery.Foundations as Foundations
import Page.Gallery.Index as Index
import Page.Gallery.Markdown as Markdown
import Page.Gallery.Navigation as Navigation
import Page.Gallery.Overlays as Overlays
import Page.Gallery.Picking as Picking
import Page.Gallery.Recurring as Recurring
import Page.Gallery.Review as Review
import Page.Gallery.Rules as Rules
import Page.Gallery.Selects as Selects
import Page.Gallery.ServerLists as ServerLists
import Page.Gallery.StaleData as StaleData
import Page.Gallery.Structured as Structured
import Page.Gallery.Tables as Tables



-- MODEL


type alias Model =
    { index : Index.Model
    , foundations : Maybe Foundations.Model
    , basics : Maybe Basics.Model
    , selects : Maybe Selects.Model
    , tables : Maybe Tables.Model
    , forms : Maybe Forms.Model
    , formModel : Maybe FormModel.Model
    , dateTime : Maybe DateTime.Model
    , overlays : Maybe Overlays.Model
    , navigation : Maybe Navigation.Model
    , dataDisplay : Maybe DataDisplay.Model
    , rules : Maybe Rules.Model
    , arranging : Maybe Arranging.Model
    , actions : Maybe Actions.Model
    , flow : Maybe Flow.Model
    , markdown : Maybe Markdown.Model
    , review : Maybe Review.Model
    , structured : Maybe Structured.Model
    , picking : Maybe Picking.Model
    , access : Maybe Access.Model
    , recurring : Maybe Recurring.Model
    , staleData : Maybe StaleData.Model
    , serverLists : Maybe ServerLists.Model
    }


init : Model
init =
    { index = Index.init
    , foundations = Nothing
    , basics = Nothing
    , selects = Nothing
    , tables = Nothing
    , forms = Nothing
    , formModel = Nothing
    , dateTime = Nothing
    , overlays = Nothing
    , navigation = Nothing
    , dataDisplay = Nothing
    , rules = Nothing
    , arranging = Nothing
    , actions = Nothing
    , flow = Nothing
    , markdown = Nothing
    , review = Nothing
    , structured = Nothing
    , picking = Nothing
    , access = Nothing
    , recurring = Nothing
    , staleData = Nothing
    , serverLists = Nothing
    }



-- UPDATE


type Msg
    = IndexMsg Index.Msg
    | FoundationsMsg Foundations.Msg
    | BasicsMsg Basics.Msg
    | SelectsMsg Selects.Msg
    | TablesMsg Tables.Msg
    | FormsMsg Forms.Msg
    | FormModelMsg FormModel.Msg
    | DateTimeMsg DateTime.Msg
    | OverlaysMsg Overlays.Msg
    | NavigationMsg Navigation.Msg
    | DataDisplayMsg DataDisplay.Msg
    | RulesMsg Rules.Msg
    | ArrangingMsg Arranging.Msg
    | ActionsMsg Actions.Msg
    | FlowMsg Flow.Msg
    | MarkdownMsg Markdown.Msg
    | ReviewMsg Review.Msg
    | StructuredMsg Structured.Msg
    | PickingMsg Picking.Msg
    | AccessMsg Access.Msg
    | RecurringMsg Recurring.Msg
    | StaleDataMsg StaleData.Msg
    | ServerListsMsg ServerLists.Msg


{-| Creates the page for a section if it has not been visited yet. Call it when
the route changes.
-}
ensure : Section -> Model -> ( Model, Cmd Msg )
ensure section model =
    case section of
        Foundations ->
            create model.foundations Foundations.init (\page -> { model | foundations = page }) FoundationsMsg model

        Basics ->
            create model.basics Basics.init (\page -> { model | basics = page }) BasicsMsg model

        Selects ->
            create model.selects Selects.init (\page -> { model | selects = page }) SelectsMsg model

        Tables ->
            create model.tables Tables.init (\page -> { model | tables = page }) TablesMsg model

        Forms ->
            create model.forms Forms.init (\page -> { model | forms = page }) FormsMsg model

        FormModel ->
            create model.formModel FormModel.init (\page -> { model | formModel = page }) FormModelMsg model

        DateTime ->
            create model.dateTime DateTime.init (\page -> { model | dateTime = page }) DateTimeMsg model

        Overlays ->
            create model.overlays Overlays.init (\page -> { model | overlays = page }) OverlaysMsg model

        Navigation ->
            create model.navigation Navigation.init (\page -> { model | navigation = page }) NavigationMsg model

        DataDisplay ->
            create model.dataDisplay DataDisplay.init (\page -> { model | dataDisplay = page }) DataDisplayMsg model

        Rules ->
            create model.rules Rules.init (\page -> { model | rules = page }) RulesMsg model

        Arranging ->
            create model.arranging Arranging.init (\page -> { model | arranging = page }) ArrangingMsg model

        Actions ->
            create model.actions Actions.init (\page -> { model | actions = page }) ActionsMsg model

        Flow ->
            create model.flow Flow.init (\page -> { model | flow = page }) FlowMsg model

        Markdown ->
            create model.markdown Markdown.init (\page -> { model | markdown = page }) MarkdownMsg model

        Review ->
            create model.review Review.init (\page -> { model | review = page }) ReviewMsg model

        Structured ->
            create model.structured Structured.init (\page -> { model | structured = page }) StructuredMsg model

        Picking ->
            create model.picking Picking.init (\page -> { model | picking = page }) PickingMsg model

        Access ->
            create model.access Access.init (\page -> { model | access = page }) AccessMsg model

        Recurring ->
            create model.recurring Recurring.init (\page -> { model | recurring = page }) RecurringMsg model

        StaleData ->
            create model.staleData StaleData.init (\page -> { model | staleData = page }) StaleDataMsg model

        ServerLists ->
            create model.serverLists ServerLists.init (\page -> { model | serverLists = page }) ServerListsMsg model

        Examples ->
            ( model, Cmd.none )


create : Maybe page -> ( page, Cmd pageMsg ) -> (Maybe page -> Model) -> (pageMsg -> Msg) -> Model -> ( Model, Cmd Msg )
create existing ( page, cmd ) store toMsg model =
    case existing of
        Just _ ->
            ( model, Cmd.none )

        Nothing ->
            ( store (Just page), Cmd.map toMsg cmd )


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        IndexMsg inner ->
            ( { model | index = Index.update inner model.index }, Cmd.none )

        FoundationsMsg inner ->
            step model.foundations (Foundations.update inner) (\page -> { model | foundations = page }) FoundationsMsg model

        BasicsMsg inner ->
            step model.basics (Basics.update inner) (\page -> { model | basics = page }) BasicsMsg model

        SelectsMsg inner ->
            step model.selects (Selects.update inner) (\page -> { model | selects = page }) SelectsMsg model

        TablesMsg inner ->
            step model.tables (Tables.update inner) (\page -> { model | tables = page }) TablesMsg model

        FormsMsg inner ->
            step model.forms (Forms.update inner) (\page -> { model | forms = page }) FormsMsg model

        FormModelMsg inner ->
            step model.formModel (FormModel.update inner) (\page -> { model | formModel = page }) FormModelMsg model

        DateTimeMsg inner ->
            step model.dateTime (DateTime.update inner) (\page -> { model | dateTime = page }) DateTimeMsg model

        OverlaysMsg inner ->
            step model.overlays (Overlays.update inner) (\page -> { model | overlays = page }) OverlaysMsg model

        NavigationMsg inner ->
            step model.navigation (Navigation.update inner) (\page -> { model | navigation = page }) NavigationMsg model

        DataDisplayMsg inner ->
            step model.dataDisplay (DataDisplay.update inner) (\page -> { model | dataDisplay = page }) DataDisplayMsg model

        RulesMsg inner ->
            step model.rules (Rules.update inner) (\page -> { model | rules = page }) RulesMsg model

        ArrangingMsg inner ->
            step model.arranging (Arranging.update inner) (\page -> { model | arranging = page }) ArrangingMsg model

        ActionsMsg inner ->
            step model.actions (Actions.update inner) (\page -> { model | actions = page }) ActionsMsg model

        FlowMsg inner ->
            step model.flow (Flow.update inner) (\page -> { model | flow = page }) FlowMsg model

        MarkdownMsg inner ->
            step model.markdown (Markdown.update inner) (\page -> { model | markdown = page }) MarkdownMsg model

        ReviewMsg inner ->
            step model.review (Review.update inner) (\page -> { model | review = page }) ReviewMsg model

        StructuredMsg inner ->
            step model.structured (Structured.update inner) (\page -> { model | structured = page }) StructuredMsg model

        PickingMsg inner ->
            step model.picking (Picking.update inner) (\page -> { model | picking = page }) PickingMsg model

        AccessMsg inner ->
            step model.access (Access.update inner) (\page -> { model | access = page }) AccessMsg model

        RecurringMsg inner ->
            step model.recurring (Recurring.update inner) (\page -> { model | recurring = page }) RecurringMsg model

        StaleDataMsg inner ->
            step model.staleData (StaleData.update inner) (\page -> { model | staleData = page }) StaleDataMsg model

        ServerListsMsg inner ->
            step model.serverLists (ServerLists.update inner) (\page -> { model | serverLists = page }) ServerListsMsg model


{-| Runs a page's update on its model, if the page exists.
-}
step : Maybe page -> (page -> ( page, Cmd pageMsg )) -> (Maybe page -> Model) -> (pageMsg -> Msg) -> Model -> ( Model, Cmd Msg )
step existing change store toMsg model =
    case existing of
        Just page ->
            let
                ( next, cmd ) =
                    change page
            in
            ( store (Just next), Cmd.map toMsg cmd )

        Nothing ->
            ( model, Cmd.none )



-- VIEW


view : Settings -> Locale -> Maybe Section -> Model -> Html Msg
view settings locale maybeSection model =
    case maybeSection of
        Nothing ->
            Html.map IndexMsg (Index.view locale model.index)

        Just section ->
            case section of
                Foundations ->
                    show FoundationsMsg (Foundations.view locale) model.foundations

                Basics ->
                    show BasicsMsg (Basics.view locale) model.basics

                Selects ->
                    show SelectsMsg (Selects.view locale) model.selects

                Tables ->
                    show TablesMsg (Tables.view locale) model.tables

                Forms ->
                    show FormsMsg (Forms.view locale) model.forms

                FormModel ->
                    show FormModelMsg (FormModel.view locale) model.formModel

                DateTime ->
                    show DateTimeMsg (DateTime.view locale) model.dateTime

                Overlays ->
                    show OverlaysMsg (Overlays.view locale) model.overlays

                Navigation ->
                    show NavigationMsg (Navigation.view locale) model.navigation

                DataDisplay ->
                    show DataDisplayMsg (DataDisplay.view settings locale) model.dataDisplay

                Rules ->
                    show RulesMsg (Rules.view locale) model.rules

                Arranging ->
                    show ArrangingMsg (Arranging.view locale) model.arranging

                Actions ->
                    show ActionsMsg (Actions.view locale) model.actions

                Flow ->
                    show FlowMsg (Flow.view locale) model.flow

                Markdown ->
                    show MarkdownMsg (Markdown.view locale) model.markdown

                Review ->
                    show ReviewMsg (Review.view locale) model.review

                Structured ->
                    show StructuredMsg (Structured.view locale) model.structured

                Picking ->
                    show PickingMsg (Picking.view locale) model.picking

                Access ->
                    show AccessMsg (Access.view settings locale) model.access

                Recurring ->
                    show RecurringMsg (Recurring.view locale) model.recurring

                StaleData ->
                    show StaleDataMsg (StaleData.view settings locale) model.staleData

                ServerLists ->
                    show ServerListsMsg (ServerLists.view locale) model.serverLists

                Examples ->
                    Examples.view


show : (pageMsg -> Msg) -> (page -> Html pageMsg) -> Maybe page -> Html Msg
show toMsg viewPage maybePage =
    case maybePage of
        Just page ->
            Html.map toMsg (viewPage page)

        Nothing ->
            Html.text ""



-- SUBSCRIPTIONS


{-| Only the page on screen listens.
-}
subscriptions : Maybe Section -> Model -> Sub Msg
subscriptions maybeSection model =
    case maybeSection of
        Nothing ->
            Sub.none

        Just section ->
            case section of
                Foundations ->
                    sub FoundationsMsg Foundations.subscriptions model.foundations

                Basics ->
                    sub BasicsMsg Basics.subscriptions model.basics

                Selects ->
                    sub SelectsMsg Selects.subscriptions model.selects

                Tables ->
                    sub TablesMsg Tables.subscriptions model.tables

                Forms ->
                    sub FormsMsg Forms.subscriptions model.forms

                FormModel ->
                    sub FormModelMsg FormModel.subscriptions model.formModel

                DateTime ->
                    sub DateTimeMsg DateTime.subscriptions model.dateTime

                Overlays ->
                    sub OverlaysMsg Overlays.subscriptions model.overlays

                Navigation ->
                    sub NavigationMsg Navigation.subscriptions model.navigation

                DataDisplay ->
                    sub DataDisplayMsg DataDisplay.subscriptions model.dataDisplay

                Rules ->
                    sub RulesMsg Rules.subscriptions model.rules

                Arranging ->
                    sub ArrangingMsg Arranging.subscriptions model.arranging

                Actions ->
                    sub ActionsMsg Actions.subscriptions model.actions

                Flow ->
                    sub FlowMsg Flow.subscriptions model.flow

                Markdown ->
                    sub MarkdownMsg Markdown.subscriptions model.markdown

                Review ->
                    sub ReviewMsg Review.subscriptions model.review

                Structured ->
                    sub StructuredMsg Structured.subscriptions model.structured

                Picking ->
                    sub PickingMsg Picking.subscriptions model.picking

                Access ->
                    sub AccessMsg Access.subscriptions model.access

                Recurring ->
                    sub RecurringMsg Recurring.subscriptions model.recurring

                StaleData ->
                    sub StaleDataMsg StaleData.subscriptions model.staleData

                ServerLists ->
                    sub ServerListsMsg ServerLists.subscriptions model.serverLists

                Examples ->
                    Sub.none


sub : (pageMsg -> Msg) -> (page -> Sub pageMsg) -> Maybe page -> Sub Msg
sub toMsg subscriptionsOf maybePage =
    case maybePage of
        Just page ->
            Sub.map toMsg (subscriptionsOf page)

        Nothing ->
            Sub.none
