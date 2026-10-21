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
import Page.Gallery.Basics as Basics
import Page.Gallery.Catalog as Catalog exposing (Section(..))
import Page.Gallery.DataDisplay as DataDisplay
import Page.Gallery.DateTime as DateTime
import Page.Gallery.Forms as Forms
import Page.Gallery.Foundations as Foundations
import Page.Gallery.Index as Index
import Page.Gallery.Navigation as Navigation
import Page.Gallery.Overlays as Overlays
import Page.Gallery.Rules as Rules
import Page.Gallery.Selects as Selects
import Page.Gallery.Tables as Tables



-- MODEL


type alias Model =
    { index : Index.Model
    , foundations : Maybe Foundations.Model
    , basics : Maybe Basics.Model
    , selects : Maybe Selects.Model
    , tables : Maybe Tables.Model
    , forms : Maybe Forms.Model
    , dateTime : Maybe DateTime.Model
    , overlays : Maybe Overlays.Model
    , navigation : Maybe Navigation.Model
    , dataDisplay : Maybe DataDisplay.Model
    , rules : Maybe Rules.Model
    }


init : Model
init =
    { index = Index.init
    , foundations = Nothing
    , basics = Nothing
    , selects = Nothing
    , tables = Nothing
    , forms = Nothing
    , dateTime = Nothing
    , overlays = Nothing
    , navigation = Nothing
    , dataDisplay = Nothing
    , rules = Nothing
    }



-- UPDATE


type Msg
    = IndexMsg Index.Msg
    | FoundationsMsg Foundations.Msg
    | BasicsMsg Basics.Msg
    | SelectsMsg Selects.Msg
    | TablesMsg Tables.Msg
    | FormsMsg Forms.Msg
    | DateTimeMsg DateTime.Msg
    | OverlaysMsg Overlays.Msg
    | NavigationMsg Navigation.Msg
    | DataDisplayMsg DataDisplay.Msg
    | RulesMsg Rules.Msg


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


view : Locale -> Maybe Section -> Model -> Html Msg
view locale maybeSection model =
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

                DateTime ->
                    show DateTimeMsg (DateTime.view locale) model.dateTime

                Overlays ->
                    show OverlaysMsg (Overlays.view locale) model.overlays

                Navigation ->
                    show NavigationMsg (Navigation.view locale) model.navigation

                DataDisplay ->
                    show DataDisplayMsg (DataDisplay.view locale) model.dataDisplay

                Rules ->
                    show RulesMsg (Rules.view locale) model.rules


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


sub : (pageMsg -> Msg) -> (page -> Sub pageMsg) -> Maybe page -> Sub Msg
sub toMsg subscriptionsOf maybePage =
    case maybePage of
        Just page ->
            Sub.map toMsg (subscriptionsOf page)

        Nothing ->
            Sub.none
