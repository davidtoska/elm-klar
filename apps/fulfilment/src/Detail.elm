module Detail exposing
    ( Model
    , Msg
    , close
    , init
    , isBlocking
    , isOpen
    , open
    , overlays
    , reload
    , update
    , view
    )

{-| One order in a drawer: its facts, the steps it can take, lines, history and notes.
-}

import Api
import Backend exposing (Db)
import Dict exposing (Dict)
import Domain exposing (..)
import Effect exposing (Effects)
import Html exposing (Html)
import Ids
import Inbox exposing (Env)
import Klar.Alert as Alert
import Klar.Badge as Badge
import Klar.Button as Button
import Klar.Card as Card
import Klar.ConfirmDialog as ConfirmDialog
import Klar.DescriptionList as DescriptionList
import Klar.Drawer as Drawer
import Klar.ErrorState as ErrorState
import Klar.Format as Format
import Klar.Layout as Layout
import Klar.Locale as Locale
import Klar.Remote as Remote exposing (Problem, Remote(..))
import Klar.Skeleton as Skeleton
import Klar.Spinner as Spinner
import Klar.Table as Table
import Klar.Tabs as Tabs
import Klar.Text as Text
import Klar.TextArea as TextArea
import Klar.Theme as Theme
import Klar.Timeline as Timeline
import Time


type alias Model =
    { drawer : Drawer.State
    , order : Maybe OrderId
    , detail : Remote Detail
    , ticket : Int
    , tabs : Tabs.State
    , linesTable : Table.State ()
    , confirm : ConfirmDialog.State
    , pending : Maybe Status
    , changing : Maybe Status
    , drafts : Dict String String
    , savingNote : Bool
    , failure : Maybe Fault
    }


{-| A failed change, shown in the drawer too: a toast cannot be reached with the
keyboard while the drawer holds focus.
-}
type alias Fault =
    { title : String
    , detail : String
    , retry : Msg
    }


type Msg
    = DrawerMsg Drawer.Msg
    | TabsMsg Tabs.Msg
    | LinesTableMsg Table.Msg
    | GotDetail Int Bool (Result Problem Detail)
    | RetryDetail
    | RequestClose
    | ChangeStatus Status
    | ConfirmMsg ConfirmDialog.Msg
    | ConfirmStatus
    | CancelStatus
    | StatusChanged Status (Result Problem (Db -> Db))
    | NoteChanged String
    | AddNote
    | NoteSaved (Result Problem (Db -> Db))
    | DismissFailure


init : Model
init =
    { drawer = Drawer.init Ids.drawer
    , order = Nothing
    , detail = NotAsked
    , ticket = 0
    , tabs = Tabs.init Ids.tabs "lines"
    , linesTable = Table.init Ids.linesTable
    , confirm = ConfirmDialog.init Ids.statusDialog
    , pending = Nothing
    , changing = Nothing
    , drafts = Dict.empty
    , savingNote = False
    , failure = Nothing
    }


isOpen : Model -> Bool
isOpen model =
    Drawer.isOpen model.drawer


isBlocking : Model -> Bool
isBlocking model =
    Drawer.isOpen model.drawer || ConfirmDialog.isOpen model.confirm


{-| Opens the drawer on an order and loads it.
-}
open : Env -> OrderId -> Model -> ( Model, Cmd Msg )
open env id model =
    if model.order == Just id && Drawer.isOpen model.drawer then
        ( model, Cmd.none )

    else
        let
            ( drawer, drawerCmd ) =
                Drawer.open "" model.drawer

            ( next, fetchCmd ) =
                fetch env False { model | drawer = drawer, order = Just id, detail = Loading, tabs = Tabs.setActive "lines" model.tabs }
        in
        ( next, Cmd.batch [ Cmd.map DrawerMsg drawerCmd, fetchCmd ] )


close : Model -> ( Model, Cmd Msg )
close model =
    if Drawer.isOpen model.drawer then
        let
            ( drawer, cmd ) =
                Drawer.close model.drawer
        in
        ( { model | drawer = drawer, order = Nothing }, Cmd.map DrawerMsg cmd )

    else
        ( { model | order = Nothing }, Cmd.none )


{-| Loads the order again after something changed, and keeps showing the old one meanwhile.
-}
reload : Env -> Model -> ( Model, Cmd Msg )
reload env model =
    fetch env True model


fetch : Env -> Bool -> Model -> ( Model, Cmd Msg )
fetch env quiet model =
    case model.order of
        Nothing ->
            ( model, Cmd.none )

        Just id ->
            let
                ticket =
                    model.ticket + 1
            in
            ( { model | ticket = ticket }
            , Api.getOrder env.net env.db id (GotDetail ticket quiet)
            )



-- UPDATE


update : Env -> Msg -> Model -> ( Model, Cmd Msg, Effects Msg )
update env msg model =
    case msg of
        DrawerMsg m ->
            let
                ( drawer, cmd ) =
                    Drawer.update m model.drawer
            in
            plain ( { model | drawer = drawer }, Cmd.map DrawerMsg cmd )

        TabsMsg m ->
            let
                ( tabs, cmd ) =
                    Tabs.update m model.tabs
            in
            plain ( { model | tabs = tabs }, Cmd.map TabsMsg cmd )

        LinesTableMsg m ->
            let
                ( table, cmd ) =
                    Table.update m model.linesTable
            in
            plain ( { model | linesTable = table }, Cmd.map LinesTableMsg cmd )

        GotDetail ticket quiet result ->
            if ticket /= model.ticket then
                plain ( model, Cmd.none )

            else
                case result of
                    Ok detail ->
                        plain ( { model | detail = Success detail }, Cmd.none )

                    Err problem ->
                        if quiet && Remote.isSuccess model.detail then
                            plain ( model, Cmd.none )

                        else
                            plain ( { model | detail = Failure problem }, Cmd.none )

        DismissFailure ->
            plain ( { model | failure = Nothing }, Cmd.none )

        RetryDetail ->
            let
                ( next, cmd ) =
                    fetch env False { model | detail = Loading }
            in
            plain ( next, Cmd.batch [ cmd, Cmd.map DrawerMsg (Drawer.refocus model.drawer) ] )

        RequestClose ->
            ( model, Cmd.none, { none | close = True } )

        ChangeStatus to ->
            case model.detail of
                Success detail ->
                    if cannotBeUndone detail.summary.status to then
                        let
                            ( confirm, cmd ) =
                                ConfirmDialog.open (Ids.statusButton (statusKey to)) model.confirm
                        in
                        plain ( { model | confirm = confirm, pending = Just to }, Cmd.map ConfirmMsg cmd )

                    else
                        plain (send env to model)

                _ ->
                    plain ( model, Cmd.none )

        ConfirmMsg m ->
            let
                ( confirm, cmd ) =
                    ConfirmDialog.update m model.confirm
            in
            plain ( { model | confirm = confirm }, Cmd.map ConfirmMsg cmd )

        ConfirmStatus ->
            case model.pending of
                Just to ->
                    plain (send env to { model | confirm = ConfirmDialog.setBusy model.confirm })

                Nothing ->
                    plain ( model, Cmd.none )

        CancelStatus ->
            if ConfirmDialog.isBusy model.confirm then
                plain ( model, Cmd.none )

            else
                let
                    ( confirm, cmd ) =
                        ConfirmDialog.close model.confirm
                in
                plain ( { model | confirm = confirm, pending = Nothing }, Cmd.map ConfirmMsg cmd )

        StatusChanged to (Ok change) ->
            let
                ( confirm, cmd ) =
                    ConfirmDialog.close model.confirm
            in
            ( { model | confirm = confirm, pending = Nothing, changing = Nothing }
            , Cmd.batch [ Cmd.map ConfirmMsg cmd, Cmd.map DrawerMsg (Drawer.refocus model.drawer) ]
            , { none
                | change = Just change
                , notices =
                    [ { tone = Theme.Success
                      , title = "Status changed"
                      , message = "The order is now " ++ String.toLower (statusLabel to) ++ "."
                      , retry = Nothing
                      }
                    ]
              }
            )

        StatusChanged to (Err problem) ->
            ( { model
                | changing = Nothing
                , failure =
                    if ConfirmDialog.isOpen model.confirm then
                        Nothing

                    else
                        Just { title = "Could not change the status", detail = Remote.title Locale.default problem, retry = ChangeStatus to }
                , confirm =
                    if ConfirmDialog.isOpen model.confirm then
                        ConfirmDialog.setFailed problem model.confirm

                    else
                        model.confirm
              }
            , Cmd.none
            , Effect.notify
                { tone = Theme.Danger
                , title = "Could not change the status"
                , message = Remote.title Locale.default problem
                , retry = Just (ChangeStatus to)
                }
            )

        NoteChanged text ->
            case model.order of
                Just id ->
                    plain ( { model | drafts = Dict.insert (orderIdToString id) text model.drafts }, Cmd.none )

                Nothing ->
                    plain ( model, Cmd.none )

        AddNote ->
            case model.order of
                Just id ->
                    let
                        text =
                            Dict.get (orderIdToString id) model.drafts |> Maybe.withDefault ""
                    in
                    if String.isEmpty (String.trim text) then
                        plain ( model, Cmd.none )

                    else
                        plain
                            ( { model | savingNote = True, failure = Nothing }
                            , Api.addNote env.net env.db id text NoteSaved
                            )

                Nothing ->
                    plain ( model, Cmd.none )

        NoteSaved (Ok change) ->
            ( { model
                | savingNote = False
                , failure = Nothing
                , drafts =
                    case model.order of
                        Just id ->
                            Dict.remove (orderIdToString id) model.drafts

                        Nothing ->
                            model.drafts
              }
            , Cmd.map DrawerMsg (Drawer.refocus model.drawer)
            , { none
                | change = Just change
                , notices = [ { tone = Theme.Success, title = "Note added", message = "", retry = Nothing } ]
              }
            )

        NoteSaved (Err _) ->
            ( { model
                | savingNote = False
                , failure = Just { title = "Could not save the note", detail = "What you wrote is still in the note field.", retry = AddNote }
              }
            , Cmd.none
            , Effect.notify
                { tone = Theme.Danger
                , title = "Could not save the note"
                , message = "What you wrote is still in the note field."
                , retry = Just AddNote
                }
            )


send : Env -> Status -> Model -> ( Model, Cmd Msg )
send env to model =
    case model.order of
        Just id ->
            ( { model | changing = Just to, failure = Nothing }
            , Api.changeStatus env.net env.db id to (StatusChanged to)
            )

        Nothing ->
            ( model, Cmd.none )


plain : ( Model, Cmd Msg ) -> ( Model, Cmd Msg, Effects Msg )
plain ( model, cmd ) =
    ( model, cmd, Effect.none )


none : Effects Msg
none =
    Effect.none



-- VIEW


view : Time.Zone -> Time.Posix -> Model -> Html Msg
view zone now model =
    let
        number =
            model.order |> Maybe.map orderIdToString |> Maybe.withDefault ""
    in
    Drawer.view DrawerMsg
        [ Drawer.title ("Order " ++ number)
        , Drawer.subtitle (model.detail |> Remote.toMaybe |> Maybe.map (.summary >> .customer) |> Maybe.withDefault "")
        , Drawer.large
        , Drawer.onRequestClose RequestClose
        , Drawer.footer [ Button.view [ Button.onClick RequestClose ] "Close" ]
        ]
        model.drawer
        [ -- KLAR GAP: Remote has no view function, so the four states are written out by hand
          case model.detail of
            Success detail ->
                viewDetail zone now model detail

            Failure problem ->
                ErrorState.view [ ErrorState.onRetry RetryDetail ] problem

            _ ->
                Layout.stack [ Layout.gap 4 ]
                    [ Spinner.panel "Loading order ..."
                    , Skeleton.lines 6
                    ]
        ]


viewDetail : Time.Zone -> Time.Posix -> Model -> Detail -> Html Msg
viewDetail zone now model detail =
    let
        summary =
            detail.summary

        draft =
            model.order |> Maybe.andThen (\id -> Dict.get (orderIdToString id) model.drafts) |> Maybe.withDefault ""
    in
    Layout.stack [ Layout.gap 5 ]
        [ viewFailure model.failure
        , DescriptionList.view [ DescriptionList.columns 2, DescriptionList.compact ]
            [ DescriptionList.text "Customer" summary.customer
            , DescriptionList.html "Status" (Badge.view [ Badge.tone (statusTone summary.status) ] (statusLabel summary.status))
            , DescriptionList.maybe "Assigned to"
                (summary.assignee |> Maybe.map (\p -> assigneeName Backend.people (Just p)))
            , DescriptionList.text "Total" (Format.currency Locale.default "€" 2 summary.total)
            , DescriptionList.text "Created" (Format.date Locale.default summary.created)
            , DescriptionList.text "Due" (Format.date Locale.default summary.due)
            ]
        , statusSteps model summary
        , Layout.stack [ Layout.gap 3 ]
            [ Tabs.view TabsMsg
                [ Tabs.ariaLabel "Order sections"
                , Tabs.tabs
                    [ Tabs.tab "lines" "Lines" |> Tabs.withCount (List.length detail.lines)
                    , Tabs.tab "history" "History" |> Tabs.withCount (List.length detail.history)
                    , Tabs.tab "notes" "Notes" |> Tabs.withCount (List.length detail.notes)
                    ]
                ]
                model.tabs
            , Tabs.panel model.tabs "lines" (\_ -> viewLines model detail)
            , Tabs.panel model.tabs "history" (\_ -> viewHistory zone now detail)
            , Tabs.panel model.tabs "notes" (\_ -> viewNotes zone model draft detail)
            ]
        ]



-- KLAR GAP: a toast with an action cannot be reached with the keyboard while the drawer
-- holds focus, so a failed save is also shown here


viewFailure : Maybe Fault -> Html Msg
viewFailure failure =
    case failure of
        Nothing ->
            Html.text ""

        Just f ->
            Alert.view
                [ Alert.tone Theme.Danger
                , Alert.title f.title
                , Alert.actions [ Button.view [ Button.small, Button.onClick f.retry ] "Try again" ]
                , Alert.onDismiss DismissFailure
                ]
                f.detail


statusSteps : Model -> Summary -> Html Msg
statusSteps model summary =
    Card.view [ Card.title "Next step", Card.headingLevel 2 ]
        [ case allowedNext summary.status of
            [] ->
                Text.paragraph "This order is finished. It cannot change status."

            steps ->
                Layout.row [ Layout.gap 2, Layout.wrap ]
                    (List.map (stepButton model) steps)
        ]


stepButton : Model -> Status -> Html Msg
stepButton model to =
    Button.view
        [ Button.id (Ids.statusButton (statusKey to))
        , if to == Cancelled then
            Button.danger

          else
            Button.secondary
        , Button.loading (model.changing == Just to)
        , Button.disabled (model.changing /= Nothing)
        , Button.onClick (ChangeStatus to)
        ]
        ("Mark as " ++ String.toLower (statusLabel to))


viewLines : Model -> Detail -> Html Msg
viewLines model detail =
    Table.view LinesTableMsg
        [ Table.label "Order lines"
        , Table.columns
            [ Table.text (Table.columnId "sku") "SKU" .sku [ Table.width 100 ]
            , Table.text (Table.columnId "name") "Product" .name []
            , Table.int (Table.columnId "quantity") "Qty" .quantity [ Table.footerSum ]
            , Table.float (Table.columnId "price") "Unit price" 2 .unitPrice []
            , Table.float (Table.columnId "amount") "Amount" 2 (\l -> toFloat l.quantity * l.unitPrice) [ Table.footerSum ]
            ]
        , Table.rows (Success detail.lines)
        , Table.unpaged
        ]
        model.linesTable


viewHistory : Time.Zone -> Time.Posix -> Detail -> Html Msg
viewHistory zone now detail =
    Timeline.view
        [ Timeline.zone zone
        , Timeline.now now
        , Timeline.ariaLabel "Order history"
        ]
        (List.map
            (\h ->
                Timeline.event h.id h.at h.text
                    |> Timeline.withTone h.tone
                    |> Timeline.withAuthor h.by
            )
            detail.history
        )


viewNotes : Time.Zone -> Model -> String -> Detail -> Html Msg
viewNotes zone model draft detail =
    Layout.stack [ Layout.gap 3 ]
        [ TextArea.view
            [ TextArea.id Ids.noteField
            , TextArea.label "New note"
            , TextArea.value draft
            , TextArea.onInput NoteChanged
            , TextArea.minRows 2
            , TextArea.maxRows 8
            ]
        , Layout.row [ Layout.justifyEnd ]
            [ Button.view
                [ Button.primary
                , Button.loading model.savingNote
                , Button.disabled (String.isEmpty (String.trim draft))
                , Button.onClick AddNote
                ]
                "Add note"
            ]
        , case detail.notes of
            [] ->
                Text.paragraph "No notes yet."

            notes ->
                Layout.stack [ Layout.gap 2 ]
                    (List.map
                        (\note ->
                            Card.view [ Card.sunken, Card.headingLevel 3, Card.title note.by, Card.subtitle (Format.dateTime Locale.default zone note.at) ]
                                [ Text.paragraph note.text ]
                        )
                        notes
                    )
        ]


{-| The question that guards the steps that cannot be undone.
-}
overlays : Model -> List (Html Msg)
overlays model =
    let
        to =
            model.pending |> Maybe.withDefault Cancelled
    in
    [ ConfirmDialog.view ConfirmMsg
        [ if to == Cancelled then
            ConfirmDialog.danger

          else
            ConfirmDialog.warning
        , ConfirmDialog.title ("Mark the order as " ++ String.toLower (statusLabel to) ++ "?")
        , ConfirmDialog.message "This cannot be undone."
        , ConfirmDialog.consequences (consequences to)
        , ConfirmDialog.confirmLabel ("Mark as " ++ String.toLower (statusLabel to))
        , ConfirmDialog.onConfirm ConfirmStatus
        , ConfirmDialog.onCancel CancelStatus
        ]
        model.confirm
    ]


consequences : Status -> List String
consequences to =
    case to of
        Shipped ->
            [ "The customer is told that the order is on its way", "The lines can no longer be changed" ]

        Delivered ->
            [ "The order is closed" ]

        Cancelled ->
            [ "The reserved stock is released", "The customer is told that the order is canceled" ]

        _ ->
            []
