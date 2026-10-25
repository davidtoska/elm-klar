module Page.Gallery.Flow exposing (Model, Msg, init, subscriptions, update, view)

{-| Gallery page: pages and flow. Result pages, the bulk action bar, the leave
guard and the undo history, each with a small working scene around it.

The leave guard asks inside an `Overlay.host`, which makes the page behind the dialog
inert; the undo shortcuts are listened to by the same host, so they work as soon as
focus is anywhere in this page.

-}

import Api.Types as Types
import Browser.Dom as Dom
import Html exposing (Html)
import Html.Attributes as Attr
import Klar
import Klar.Alert as Alert
import Klar.Badge as Badge
import Klar.BulkBar as BulkBar
import Klar.Button as Button
import Klar.Checkbox as Checkbox
import Klar.Form.Layout as FormLayout
import Klar.Format as Format
import Klar.History as History exposing (History)
import Klar.Icon as Icon
import Klar.Layout as Layout
import Klar.LeaveGuard as LeaveGuard exposing (Answer(..))
import Klar.Link as Link
import Klar.Locale as Locale exposing (Locale)
import Klar.Menu as Menu
import Klar.Modal as Modal
import Klar.Overlay as Overlay
import Klar.Remote as Remote
import Klar.Shortcut as Shortcut exposing (Shortcut)
import Klar.Spinner as Spinner
import Klar.StatusPage as StatusPage
import Klar.Text as Text
import Klar.TextArea as TextArea
import Klar.TextInput as TextInput
import Klar.Theme as Theme
import Klar.Toolbar as Toolbar
import Process
import Set exposing (Set)
import Showcase.Doc as Doc
import Showcase.Sample as Sample
import Task
import Time



-- MODEL


type Route
    = Orders
    | Customers
    | Settings


type Form
    = NoteForm
    | AddressForm


type Field
    = Quantity
    | Note


type alias Draft =
    { quantity : String
    , note : String
    }


type alias Model =
    { shortcuts : Shortcut.State

    -- status pages
    , problem : Remote.Kind
    , retries : Int
    , customer : String
    , created : Bool

    -- bulk bar
    , search : String
    , picked : Set String
    , everything : Bool
    , moreMenu : Menu.State
    , outcome : Maybe String

    -- leave guard
    , route : Route
    , guard : LeaveGuard.Guard Form Route
    , note : String
    , noteSaved : String
    , address : String
    , addressSaved : String
    , offerSave : Bool
    , saving : Maybe Route

    -- undo history
    , history : History Field Draft
    }


type Msg
    = ShortcutMsg Shortcut.Msg
    | NoOp
      -- status pages
    | ProblemPicked Remote.Kind
    | Retried
    | CustomerTyped String
    | CreateOrder
    | CreateAnother
      -- bulk bar
    | SearchTyped String
    | RowToggled String Bool
    | PageToggled Bool
    | SelectEverything
    | ClearSelection
    | Exported
    | Deleted
    | MoreMenuMsg Menu.Msg
    | Assigned
      -- leave guard
    | Navigate Route
    | GuardMsg LeaveGuard.Msg
    | NoteTyped String
    | AddressTyped String
    | SaveNote
    | SaveAddress
    | OfferSaveToggled Bool
    | SavedThenGo Route
      -- undo history
    | QuantityTyped String
    | HistoryNoteTyped String
    | FieldLeft
    | UndoPressed
    | RedoPressed
    | MarkSaved
    | DiscardChanges


init : ( Model, Cmd Msg )
init =
    ( { shortcuts = Shortcut.init
      , problem = Remote.server
      , retries = 0
      , customer = ""
      , created = False
      , search = ""
      , picked = Set.empty
      , everything = False
      , moreMenu = Menu.init "flow-more-menu"
      , outcome = Nothing
      , route = Orders
      , guard = LeaveGuard.init "flow-leave-dialog"
      , note = "Leave at the loading dock."
      , noteSaved = "Leave at the loading dock."
      , address = "Dock 4, 12 Harbour Road"
      , addressSaved = "Dock 4, 12 Harbour Road"
      , offerSave = True
      , saving = Nothing
      , history = History.init { quantity = "12", note = "" }
      }
    , Cmd.none
    )



-- THE ID OF THE PAGE THAT REPLACES THE FORM: one place, so that `id` and `Klar.focus` agree


createdId : String
createdId =
    "flow-created"



-- SAMPLE DATA


{-| The orders on the page the bulk bar demo shows, and how many orders match in all.
-}
pageOrders : List Types.Order
pageOrders =
    List.take 8 Sample.orders


matching : Int
matching =
    1240


orderKey : Types.Order -> String
orderKey order =
    Types.orderIdText order.id


selectedCount : Model -> Int
selectedCount model =
    if model.everything then
        matching

    else
        Set.size model.picked


isPicked : Model -> Types.Order -> Bool
isPicked model order =
    model.everything || Set.member (orderKey order) model.picked


pageKeys : Set String
pageKeys =
    Set.fromList (List.map orderKey pageOrders)



-- SHORTCUTS


{-| The undo shortcuts of the history demo. They are marked `inInputs` because the
history records every key typed in the two fields: `Ctrl Z` there undoes the
history, not the text of one field.
-}
pageShortcuts : Locale -> List (Shortcut Msg)
pageShortcuts locale =
    History.shortcuts [ History.locale locale ] { onUndo = UndoPressed, onRedo = RedoPressed }
        |> List.map Shortcut.inInputs



-- UPDATE


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        ShortcutMsg inner ->
            let
                ( state, fired ) =
                    -- the language only changes the names in the sheet, not the keys
                    Shortcut.update (pageShortcuts Locale.default) inner model.shortcuts
            in
            case fired of
                Just next ->
                    update next { model | shortcuts = state }

                Nothing ->
                    ( { model | shortcuts = state }, Cmd.none )

        NoOp ->
            ( model, Cmd.none )

        -- STATUS PAGES
        ProblemPicked kind ->
            ( { model | problem = kind, retries = 0 }, Cmd.none )

        Retried ->
            ( { model | retries = model.retries + 1 }, Cmd.none )

        CustomerTyped text ->
            ( { model | customer = text }, Cmd.none )

        CreateOrder ->
            -- the form is gone in the next frame, and so is the focused button:
            -- the title of the page that replaces it takes focus
            ( { model | created = True }, Klar.focus createdId NoOp )

        CreateAnother ->
            ( { model | created = False, customer = "" }
            , Task.attempt (\_ -> NoOp) (Dom.focus "flow-customer")
            )

        -- BULK BAR
        SearchTyped text ->
            ( { model | search = text }, Cmd.none )

        RowToggled key checked ->
            let
                base =
                    if model.everything then
                        pageKeys

                    else
                        model.picked
            in
            ( { model
                | everything = False
                , picked =
                    if checked then
                        Set.insert key base

                    else
                        Set.remove key base
                , outcome = Nothing
              }
            , Cmd.none
            )

        PageToggled checked ->
            ( { model
                | everything = False
                , picked =
                    if checked then
                        pageKeys

                    else
                        Set.empty
                , outcome = Nothing
              }
            , Cmd.none
            )

        SelectEverything ->
            -- the button the user pressed stays where it is, as an inactive button: no focus to move
            ( { model | everything = True, outcome = Nothing }, Cmd.none )

        ClearSelection ->
            clearSelection model Nothing

        Exported ->
            ( { model | outcome = Just (String.fromInt (selectedCount model) ++ " orders exported (nothing leaves this demo).") }, Cmd.none )

        Deleted ->
            clearSelection model (Just (String.fromInt (selectedCount model) ++ " orders deleted (they come back when you reload the page)."))

        Assigned ->
            ( { model | outcome = Just (String.fromInt (selectedCount model) ++ " orders assigned to you.") }, Cmd.none )

        MoreMenuMsg inner ->
            let
                ( menu, cmd ) =
                    Menu.update inner model.moreMenu
            in
            ( { model | moreMenu = menu }, Cmd.map MoreMenuMsg cmd )

        -- LEAVE GUARD
        Navigate route ->
            case LeaveGuard.request route model.guard of
                Proceed target ->
                    ( { model | route = target }, Cmd.none )

                Hold guard cmd ->
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
                    let
                        route =
                            LeaveGuard.destination answer
                    in
                    if LeaveGuard.savesFirst answer then
                        -- the save takes a moment; the route travels in the message that comes back
                        ( { next | saving = Just route }
                        , Cmd.batch
                            [ Cmd.map GuardMsg cmd
                            , Task.perform (\_ -> SavedThenGo route) (Process.sleep 700)
                            ]
                        )

                    else
                        -- the changes are given up: the drafts go back to what was saved
                        ( { next | route = route, note = model.noteSaved, address = model.addressSaved }
                        , Cmd.map GuardMsg cmd
                        )

        NoteTyped text ->
            ( dirtied { model | note = text }, Cmd.none )

        AddressTyped text ->
            ( dirtied { model | address = text }, Cmd.none )

        SaveNote ->
            ( dirtied { model | noteSaved = model.note }, Cmd.none )

        SaveAddress ->
            ( dirtied { model | addressSaved = model.address }, Cmd.none )

        OfferSaveToggled checked ->
            ( { model | offerSave = checked }, Cmd.none )

        SavedThenGo route ->
            let
                saved =
                    dirtied { model | noteSaved = model.note, addressSaved = model.address, saving = Nothing, route = route }

                -- a click on another link while it saved may have opened a question
                -- about a place the user is no longer going to: withdraw it
                ( guard, cmd ) =
                    LeaveGuard.dismiss saved.guard
            in
            ( { saved | guard = guard }, Cmd.map GuardMsg cmd )

        -- UNDO HISTORY
        QuantityTyped text ->
            let
                draft =
                    History.present model.history
            in
            ( { model
                | history =
                    History.record
                        [ History.label "Changed quantity", History.coalesce Quantity ]
                        { draft | quantity = text }
                        model.history
              }
            , Cmd.none
            )

        HistoryNoteTyped text ->
            let
                draft =
                    History.present model.history
            in
            ( { model
                | history =
                    History.record
                        [ History.label "Changed note", History.coalesce Note ]
                        { draft | note = text }
                        model.history
              }
            , Cmd.none
            )

        FieldLeft ->
            ( { model | history = History.endBurst model.history }, Cmd.none )

        UndoPressed ->
            ( { model | history = History.undo model.history }, Cmd.none )

        RedoPressed ->
            ( { model | history = History.redo model.history }, Cmd.none )

        MarkSaved ->
            ( { model | history = History.markSaved model.history }, Cmd.none )

        DiscardChanges ->
            ( { model
                | history = History.record [ History.label "Discarded changes" ] (History.saved model.history) model.history
              }
            , Cmd.none
            )


{-| Clearing the selection removes the bar and the button that has focus: the box
that the toolbar and the bar share, which is always on the page, takes it.
-}
clearSelection : Model -> Maybe String -> ( Model, Cmd Msg )
clearSelection model outcome =
    ( { model | picked = Set.empty, everything = False, outcome = outcome }
    , Klar.focus "flow-bulk" NoOp
    )


{-| Tells the guard what is dirty now. Called after every change of a draft.
-}
dirtied : Model -> Model
dirtied model =
    { model
        | guard =
            model.guard
                |> LeaveGuard.setDirty NoteForm (model.note /= model.noteSaved)
                |> LeaveGuard.setDirty AddressForm (model.address /= model.addressSaved)
    }


subscriptions : Model -> Sub Msg
subscriptions model =
    Shortcut.subscription ShortcutMsg (pageShortcuts Locale.default) model.shortcuts



-- VIEW


view : Locale -> Model -> Html Msg
view locale model =
    Overlay.host
        { attributes = [ Shortcut.listen ShortcutMsg (pageShortcuts locale) model.shortcuts ]
        , page =
            [ Doc.page
                { title = "Pages and flow"
                , description = "The page for a result, the bar of actions for a selection, the question that stops a user from losing unsaved work, and undo and redo. Each has a small working scene around it. The language switch in the top bar changes the built-in texts."
                }
                [ statusSection locale model
                , bulkSection locale model
                , guardSection locale model
                , historySection locale model
                ]
            ]
        , overlays = [ LeaveGuard.view GuardMsg (guardAttributes locale model) model.guard ]
        }


{-| A box with a height, like the region of an application shell: a status page
fills the box it is in.
-}
frame : Int -> Html msg -> Html msg
frame height content =
    Html.div
        [ Attr.style "height" (String.fromInt height ++ "px")
        , Attr.style "overflow" "auto"
        , Attr.style "border" "1px solid var(--klar-border)"
        , Attr.style "border-radius" "var(--klar-radius-lg)"
        , Attr.style "background" "var(--klar-bg)"
        ]
        [ content ]



-- STATUS PAGES


statusSection : Locale -> Model -> Html Msg
statusSection locale model =
    Doc.section "Status page"
        "A result that is the whole page, where Klar.EmptyState and Klar.ErrorState are the versions that live inside a table or a card. The kind of page chooses the icon, the color and the text; the actions are your buttons. There is exactly one h1, no live region (a page that arrives with a navigation is content, not an alert) and nothing takes focus by itself. The pages below fill their frames the way they fill the content of an application shell."
        [ Doc.example
            { title = "The kinds"
            , description = Just "Success, not found, no access, signed out, server error, offline and maintenance. Each has a built-in text in English and Norwegian Bokmål, which the title and description attributes replace."
            , code = Just kindsCode
            }
            (Layout.grid [ Layout.minColumn 320, Layout.gap 4 ]
                [ labelled "StatusPage.success" (frame 380 (StatusPage.view [ StatusPage.locale locale, StatusPage.actions [ Button.view [ Button.href (Link.internal "#/components/flow") ] "Back to orders" ] ] StatusPage.success))
                , labelled "StatusPage.pageNotFound" (frame 380 (StatusPage.view [ StatusPage.locale locale, StatusPage.actions [ Button.view [ Button.primary, Button.href (Link.internal "#/orders") ] "Go to orders" ] ] StatusPage.pageNotFound))
                , labelled "StatusPage.forbidden" (frame 380 (StatusPage.view [ StatusPage.locale locale, StatusPage.actions [ Button.view [ Button.href (Link.internal "#/") ] "Home" ] ] StatusPage.forbidden))
                , labelled "StatusPage.unauthorized" (frame 380 (StatusPage.view [ StatusPage.locale locale, StatusPage.actions [ Button.view [ Button.primary, Button.href (Link.internal "#/") ] "Sign in" ] ] StatusPage.unauthorized))
                , labelled "StatusPage.server" (frame 380 (StatusPage.view [ StatusPage.locale locale, StatusPage.onRetry NoOp, StatusPage.reference "req-7f3a-91c2" ] StatusPage.server))
                , labelled "StatusPage.network" (frame 380 (StatusPage.view [ StatusPage.locale locale, StatusPage.onRetry NoOp ] StatusPage.network))
                , labelled "StatusPage.retrying True: the button is busy where it is and keeps focus" (frame 380 (StatusPage.view [ StatusPage.locale locale, StatusPage.onRetry NoOp, StatusPage.retrying True ] StatusPage.network))
                , labelled "StatusPage.maintenance" (frame 380 (StatusPage.view [ StatusPage.locale locale, StatusPage.onRetry NoOp ] StatusPage.maintenance))
                , labelled "StatusPage.maintenance with backAt (UTC without settings)" (frame 380 (StatusPage.view [ StatusPage.locale locale, StatusPage.onRetry NoOp, StatusPage.backAt (Time.millisToPosix 52200000) ] StatusPage.maintenance))
                ]
            )
        , Doc.example
            { title = "For a failed request"
            , description = Just "fromProblem picks the icon and the color from the kind of the problem and takes the texts of the problem, so Remote.withTitle and friends change them. Try again is offered only when trying again can help. The reference is selected by one click (copying needs JavaScript), so Ctrl C copies it."
            , code = Just problemCode
            }
            (Layout.stack [ Layout.gap 3 ]
                [ Layout.row [ Layout.gap 2, Layout.wrap ]
                    (List.map (problemButton model)
                        [ ( "Server", Remote.server )
                        , ( "Network", Remote.network )
                        , ( "Timeout", Remote.timeout )
                        , ( "Not found", Remote.notFound )
                        , ( "Forbidden", Remote.forbidden )
                        , ( "Signed out", Remote.unauthorized )
                        , ( "Conflict", Remote.conflict )
                        ]
                    )
                , frame 380
                    (StatusPage.view
                        [ StatusPage.locale locale
                        , StatusPage.onRetry Retried
                        , StatusPage.reference "req-7f3a-91c2"
                        , StatusPage.actions [ Button.view [ Button.href (Link.internal "#/orders") ] "Go to orders" ]
                        ]
                        (StatusPage.fromProblem (Remote.problem model.problem |> Remote.withCode "503"))
                    )
                , Text.caption ("Try again was pressed " ++ String.fromInt model.retries ++ " times.")
                ]
            )
        , Doc.example
            { title = "Replacing a form, with focus"
            , description = Just "The form is replaced by the result without a navigation, so the button that was pressed is gone and focus would fall to the page. The page has an id and the update calls Klar.focus with it: the title takes focus, and a screen reader reads the result. Create another order takes focus back to the field."
            , code = Just focusCode
            }
            (frame 380
                (if model.created then
                    StatusPage.view
                        [ StatusPage.locale locale
                        , StatusPage.id createdId
                        , StatusPage.title ("Order created for " ++ model.customer)
                        , StatusPage.description "A confirmation was sent to the customer."
                        , StatusPage.icon Icon.package
                        , StatusPage.actions
                            [ Button.view [ Button.primary, Button.onClick CreateAnother ] "Create another order"
                            , Button.view [ Button.href (Link.internal "#/orders") ] "Open orders"
                            ]
                        , StatusPage.reference "ORD-1042"
                        ]
                        StatusPage.success

                 else
                    Html.div [ Attr.style "padding" "var(--klar-space-6)", Attr.style "max-width" "420px" ]
                        [ Layout.stack [ Layout.gap 3 ]
                            [ Text.heading "New order"
                            , TextInput.view
                                [ TextInput.id "flow-customer"
                                , TextInput.label "Customer"
                                , TextInput.value model.customer
                                , TextInput.onInput CustomerTyped
                                , TextInput.onEnter CreateOrder
                                , TextInput.locale locale
                                ]
                            , Button.view
                                [ Button.id "flow-create-order"
                                , Button.primary
                                , Button.disabled (String.isEmpty (String.trim model.customer))
                                , Button.onClick CreateOrder
                                ]
                                "Create order"
                            ]
                        ]
                )
            )
        ]


labelled : String -> Html msg -> Html msg
labelled name content =
    Html.div [ Attr.style "min-width" "0" ]
        [ Html.div [ Attr.style "margin-bottom" "var(--klar-space-1)" ] [ Text.mono name ]
        , content
        ]


problemButton : Model -> ( String, Remote.Kind ) -> Html Msg
problemButton model ( name, kind ) =
    Button.view
        [ Button.small
        , Button.pressed (model.problem == kind)
        , Button.onClick (ProblemPicked kind)
        ]
        name



-- BULK BAR


bulkSection : Locale -> Model -> Html Msg
bulkSection locale model =
    let
        count =
            selectedCount model

        pageSelected =
            List.all (isPicked model) pageOrders
    in
    Doc.section "Bulk action bar"
        "Appears when a selection is not empty: the count, the actions for it and Clear selection. It does not push anything: the bar takes the place of the toolbar, in the same box, and the toolbar underneath keeps its state (type in the search field, then select a row). The count is announced politely by one region that is always on the page. It never takes focus by itself, and Escape does nothing here: whether Escape clears is the application's decision."
        [ Doc.example
            { title = "A selectable list of orders"
            , description = Just "Tick a row, then the box in the header. When the whole page is selected and more orders match, the bar offers Select all 1,240 matching and says 8 of 1,240 orders selected (itemName names the items). Select all stays in its place as an inactive button, so focus is never lost. Clear selection and Delete take the bar away with the button that has focus, and the update calls Klar.focus with the id of the bar: focus goes to the toolbar box, and Tab reaches its first control."
            , code = Just bulkCode
            }
            (Layout.stack [ Layout.gap 3 ]
                [ BulkBar.view
                    [ BulkBar.id "flow-bulk"
                    , BulkBar.locale locale
                    , BulkBar.itemName (Locale.pick locale { en = { one = "order", other = "orders" }, nb = { one = "ordre", other = "ordrer" } })
                    , BulkBar.selectAllMatching { total = matching, onPage = List.length pageOrders, onSelectAll = SelectEverything }
                    ]
                    { toolbar =
                        Toolbar.view [ Toolbar.ariaLabel "Orders" ]
                            [ Toolbar.label "Orders"
                            , Toolbar.spacer
                            , TextInput.view
                                [ TextInput.search
                                , TextInput.label "Search orders"
                                , TextInput.labelHidden
                                , TextInput.placeholder "Search orders"
                                , TextInput.value model.search
                                , TextInput.onInput SearchTyped
                                , TextInput.locale locale
                                ]
                            , Button.view [ Button.primary, Button.icon Icon.plus ] "New order"
                            ]
                    , selected = count
                    , onClear = ClearSelection
                    }
                    [ Button.view [ Button.icon Icon.download, Button.onClick Exported ] "Export"
                    , Menu.view MoreMenuMsg
                        [ Menu.label "More actions"
                        , Menu.alignEnd
                        , Menu.items
                            [ Menu.item "Assign to me" Assigned |> Menu.withIcon Icon.user
                            ]
                        ]
                        model.moreMenu
                    , Button.view [ Button.danger, Button.icon Icon.trash, Button.onClick Deleted ] "Delete"
                    ]
                , Html.div
                    [ Attr.style "border" "1px solid var(--klar-border)"
                    , Attr.style "border-radius" "var(--klar-radius-lg)"
                    , Attr.style "background" "var(--klar-surface)"
                    ]
                    (Html.div
                        [ Attr.style "padding" "var(--klar-space-2) var(--klar-space-3)"
                        , Attr.style "border-bottom" "1px solid var(--klar-border-subtle)"
                        ]
                        [ Checkbox.view
                            [ Checkbox.ariaLabel "Select all orders on this page"
                            , Checkbox.checked pageSelected
                            , Checkbox.indeterminate (count > 0 && not pageSelected)
                            , Checkbox.onCheck PageToggled
                            ]
                        ]
                        :: List.map (orderRow locale model) pageOrders
                    )
                , case model.outcome of
                    Just text ->
                        Alert.view [ Alert.compact, Alert.polite, Alert.locale locale ] text

                    Nothing ->
                        Text.caption ("Showing " ++ String.fromInt (List.length pageOrders) ++ " of " ++ Format.int locale matching ++ " matching orders.")
                ]
            )
        ]


orderRow : Locale -> Model -> Types.Order -> Html Msg
orderRow locale model order =
    Html.div
        [ Attr.style "display" "flex"
        , Attr.style "align-items" "center"
        , Attr.style "gap" "var(--klar-space-3)"
        , Attr.style "padding" "var(--klar-space-2) var(--klar-space-3)"
        , Attr.style "border-bottom" "1px solid var(--klar-border-subtle)"
        ]
        [ Checkbox.view
            [ Checkbox.ariaLabel ("Select order " ++ orderKey order)
            , Checkbox.checked (isPicked model order)
            , Checkbox.onCheck (RowToggled (orderKey order))
            ]
        , Html.span [ Attr.style "min-width" "7ch" ] [ Text.mono (orderKey order) ]
        , Html.span [ Attr.style "flex" "1" ] [ Html.text order.customer ]
        , Html.span [ Attr.class "klar-tabular" ] [ Html.text (Format.currency locale "$" 2 order.total) ]
        ]



-- LEAVE GUARD


guardAttributes : Locale -> Model -> List (LeaveGuard.Attribute Msg)
guardAttributes locale model =
    LeaveGuard.locale locale
        :: (if model.offerSave then
                [ LeaveGuard.saveAndLeave ]

            else
                []
           )


guardSection : Locale -> Model -> Html Msg
guardSection locale model =
    Doc.section "Leave guard"
        "Asks \"Leave without saving?\" when the user navigates inside the application while something is not saved. Every navigation goes through LeaveGuard.request: a clean guard answers Proceed with the value, a dirty one answers Hold and opens the dialog, and the held value comes back as data when the user chooses. Several forms are independent sources, and the guard is clean only when all are. The browser's Back and Forward buttons are answered by one more function, LeaveGuard.onUrlChange (second example). Closing the tab, reloading and typing another address cannot be intercepted without JavaScript."
        [ Doc.example
            { title = "A fake application with two forms"
            , description = Just "Change the note or the address, then press Customers or Settings. Focus goes to Stay, Escape means Stay, and focus returns to the button you pressed. Save the forms, or undo the edit by hand, and the next move is free. Save and leave saves for a moment and then goes."
            , code = Just guardCode
            }
            (Layout.stack [ Layout.gap 3 ]
                [ Layout.row [ Layout.gap 2, Layout.wrap, Layout.alignCenter ]
                    [ routeButton model Orders "Orders"
                    , routeButton model Customers "Customers"
                    , routeButton model Settings "Settings"
                    , Layout.spacer
                    , Checkbox.view
                        [ Checkbox.label "Offer Save and leave"
                        , Checkbox.checked model.offerSave
                        , Checkbox.onCheck OfferSaveToggled
                        ]
                    ]
                , Html.div
                    [ Attr.style "border" "1px solid var(--klar-border)"
                    , Attr.style "border-radius" "var(--klar-radius-lg)"
                    , Attr.style "padding" "var(--klar-space-4)"
                    , Attr.style "background" "var(--klar-surface)"
                    ]
                    [ case model.route of
                        Orders ->
                            Layout.stack [ Layout.gap 4 ]
                                [ Text.heading "Order 1042"
                                , Layout.grid [ Layout.minColumn 280, Layout.gap 4 ]
                                    [ Layout.stack [ Layout.gap 2 ]
                                        [ TextArea.view
                                            [ TextArea.id "flow-note"
                                            , TextArea.label "Delivery note"
                                            , TextArea.value model.note
                                            , TextArea.rows 3
                                            , TextArea.onInput NoteTyped
                                            , TextArea.locale locale
                                            ]
                                        , Layout.row [ Layout.gap 2, Layout.alignCenter ]
                                            [ Button.view [ Button.small, Button.onClick SaveNote, Button.disabled (model.note == model.noteSaved) ] "Save note"
                                            , FormLayout.unsavedFlag [ FormLayout.locale locale ] (model.note /= model.noteSaved)
                                            ]
                                        ]
                                    , Layout.stack [ Layout.gap 2 ]
                                        [ TextInput.view
                                            [ TextInput.id "flow-address"
                                            , TextInput.label "Shipping address"
                                            , TextInput.value model.address
                                            , TextInput.onInput AddressTyped
                                            , TextInput.locale locale
                                            ]
                                        , Layout.row [ Layout.gap 2, Layout.alignCenter ]
                                            [ Button.view [ Button.small, Button.onClick SaveAddress, Button.disabled (model.address == model.addressSaved) ] "Save address"
                                            , FormLayout.unsavedFlag [ FormLayout.locale locale ] (model.address /= model.addressSaved)
                                            ]
                                        ]
                                    ]
                                ]

                        Customers ->
                            Layout.stack [ Layout.gap 2 ]
                                [ Text.heading "Customers"
                                , Text.paragraph "You are on another page. Go back to Orders to change the forms again."
                                ]

                        Settings ->
                            Layout.stack [ Layout.gap 2 ]
                                [ Text.heading "Settings"
                                , Text.paragraph "You are on another page. Go back to Orders to change the forms again."
                                ]
                    ]
                , Layout.row [ Layout.gap 3, Layout.wrap, Layout.alignCenter ]
                    [ if LeaveGuard.isDirty model.guard then
                        Badge.view [ Badge.tone Theme.Warning ] "Unsaved"

                      else
                        Badge.view [ Badge.tone Theme.Success ] "Everything saved"
                    , Text.caption ("Dirty sources: " ++ dirtyText (LeaveGuard.dirtySources model.guard))
                    , case model.saving of
                        Just route ->
                            Layout.row [ Layout.gap 2, Layout.alignCenter ]
                                [ Spinner.view []
                                , Text.caption ("Saving, then going to " ++ routeName route ++ " ...")
                                ]

                        Nothing ->
                            Html.text ""
                    ]
                ]
            )
        , Doc.example
            { title = "The Back and Forward buttons"
            , description = Just "This page keeps its route in its own model, so the buttons of your browser do not reach it. The wiring below is for an application with addresses. To try it for real, open the multi-step flow on the Examples page, which is an application with addresses: make the form dirty and press Back. Back asks with the address bar already at the page you wanted, Stay puts the address right, Leave goes there."
            , code = Just guardBrowserCode
            }
            (Layout.stack [ Layout.gap 2 ]
                [ Text.paragraph "Back while something is dirty: the page stays, the question opens, the address bar is already at the page you pressed Back to."
                , Text.paragraph "Stay pushes the address of the page that is shown. Leave shows the page you wanted. A second Back after Stay asks again."
                , Text.caption "The guard never moves in the history to undo a button, which is what looped in the first recipe."
                ]
            )
        ]


routeButton : Model -> Route -> String -> Html Msg
routeButton model route name =
    Button.view
        [ Button.id ("flow-go-" ++ String.toLower name)
        , Button.pressed (model.route == route)
        , Button.onClick (Navigate route)
        ]
        name


routeName : Route -> String
routeName route =
    case route of
        Orders ->
            "Orders"

        Customers ->
            "Customers"

        Settings ->
            "Settings"


dirtyText : List Form -> String
dirtyText forms =
    if List.isEmpty forms then
        "none"

    else
        forms
            |> List.map
                (\form ->
                    case form of
                        NoteForm ->
                            "note"

                        AddressForm ->
                            "address"
                )
            |> String.join ", "



-- UNDO HISTORY


historySection : Locale -> Model -> Html Msg
historySection locale model =
    let
        draft =
            History.present model.history
    in
    Doc.section "Undo history"
        "Undo and redo as a plain value: the present, the steps before it and the steps after it. Typing in one field is one step (a burst) and ends when the field loses focus; every step has a label that a screen reader hears (\"Undid: Changed quantity\"). History does not listen to the keyboard: the page wires Ctrl Z and Ctrl Shift Z with Klar.Shortcut, marked inInputs because every key typed here is recorded. The saved point tells whether the value is still what was saved."
        [ Doc.example
            { title = "Two fields with undo and redo"
            , description = Just "Type in the quantity, leave the field, type in the note, then press Ctrl Z or the Undo button. Mark saved sets the saved point; undoing past it makes the form dirty again, and redo comes back to it."
            , code = Just historyCode
            }
            (Layout.stack [ Layout.gap 3 ]
                [ Toolbar.view [ Toolbar.ariaLabel "Edit" ]
                    [ History.controls [ History.locale locale, History.showShortcuts ]
                        { onUndo = UndoPressed, onRedo = RedoPressed }
                        model.history
                    , Toolbar.separator
                    , Button.view [ Button.icon Icon.save, Button.onClick MarkSaved, Button.disabled (History.isAtSavedPoint model.history) ] "Mark saved"
                    , Button.view [ Button.icon Icon.refresh, Button.onClick DiscardChanges, Button.disabled (History.isAtSavedPoint model.history) ] "Discard changes"
                    , Toolbar.spacer
                    , FormLayout.unsavedFlag [ FormLayout.locale locale ] (not (History.isAtSavedPoint model.history))
                    ]
                , Layout.grid [ Layout.minColumn 240, Layout.gap 4 ]
                    [ TextInput.view
                        [ TextInput.id "flow-quantity"
                        , TextInput.label "Quantity"
                        , TextInput.value draft.quantity
                        , TextInput.onInput QuantityTyped
                        , TextInput.onBlur FieldLeft
                        , TextInput.locale locale
                        ]
                    , TextArea.view
                        [ TextArea.id "flow-history-note"
                        , TextArea.label "Note"
                        , TextArea.value draft.note
                        , TextArea.rows 3
                        , TextArea.onInput HistoryNoteTyped
                        , TextArea.onBlur FieldLeft
                        , TextArea.locale locale
                        ]
                    ]
                , Text.caption
                    ("Undo: "
                        ++ Maybe.withDefault "nothing" (History.undoLabel model.history)
                        ++ " · Redo: "
                        ++ Maybe.withDefault "nothing" (History.redoLabel model.history)
                    )
                ]
            )
        ]



-- CODE


kindsCode : String
kindsCode =
    """StatusPage.view
    [ StatusPage.actions [ Button.view [ Button.primary, Button.href (Link.internal "#/orders") ] "Go to orders" ] ]
    StatusPage.pageNotFound

-- the others: success, forbidden, unauthorized, server, network, maintenance
-- (the failures have the names of Remote.Kind)
StatusPage.view
    [ StatusPage.onRetry ReloadOrders
    , StatusPage.retrying model.reloading -- busy in place while the request is on its way
    , StatusPage.reference "req-7f3a-91c2"
    ]
    StatusPage.server

-- a page that stands on its own, without an AppShell, is the main landmark
StatusPage.view [ StatusPage.standalone ] StatusPage.forbidden"""


problemCode : String
problemCode =
    """case model.order of
    Failed problem ->
        StatusPage.view
            [ StatusPage.onRetry ReloadOrder
            , StatusPage.reference requestId
            ]
            (StatusPage.fromProblem problem)

    _ ->
        viewOrder model

-- the texts of the problem are the texts of the page
Remote.problem Remote.notFound |> Remote.withTitle "Order not found" """


focusCode : String
focusCode =
    """CreateOrder ->
    ( { model | created = True }
    , Klar.focus "order-created" NoOp
    )

StatusPage.view
    [ StatusPage.id "order-created"
    , StatusPage.title ("Order created for " ++ model.customer)
    , StatusPage.actions [ Button.view [ Button.onClick CreateAnother ] "Create another order" ]
    ]
    StatusPage.success"""


bulkCode : String
bulkCode =
    """BulkBar.view
    [ BulkBar.id "orders-bulk"
    , BulkBar.itemName { one = "order", other = "orders" }
    , BulkBar.selectAllMatching { total = 1240, onPage = 8, onSelectAll = SelectEverything }
    ]
    { toolbar = Toolbar.view [ Toolbar.ariaLabel "Orders" ] [ searchField, newOrderButton ]
    , selected = Set.size model.picked
    , onClear = ClearSelection
    }
    [ Button.view [ Button.icon Icon.download, Button.onClick Exported ] "Export"
    , Button.view [ Button.danger, Button.icon Icon.trash, Button.onClick Deleted ] "Delete"
    ]

-- the bar and its focused button are gone in the next frame: the box that the toolbar
-- and the bar share is always on the page and takes focus
ClearSelection ->
    ( { model | picked = Set.empty }, Klar.focus "orders-bulk" NoOp )

-- the "Select all" button stays where it is (inactive): nothing to move
SelectEverything ->
    ( { model | everything = True }, Cmd.none )"""


guardCode : String
guardCode =
    """-- every navigation asks the guard
Navigate route ->
    case LeaveGuard.request route model.guard of
        Proceed target ->
            ( { model | route = target }, Cmd.none )

        Hold guard cmd ->
            ( { model | guard = guard }, Cmd.map GuardMsg cmd )

-- the forms say whether they are dirty
NoteTyped text ->
    ( { model
        | note = text
        , guard = LeaveGuard.setDirty NoteForm (text /= model.noteSaved) model.guard
      }
    , Cmd.none
    )

-- the user answers
GuardMsg inner ->
    let
        ( guard, cmd, decision ) =
            LeaveGuard.update inner model.guard
    in
    case decision of
        Just answer ->
            if LeaveGuard.savesFirst answer then
                ( { model | guard = guard }
                , Cmd.batch [ Cmd.map GuardMsg cmd, saveThenGo (LeaveGuard.destination answer) ]
                )

            else
                ( { model | guard = guard, route = LeaveGuard.destination answer }, Cmd.map GuardMsg cmd )

        Nothing ->
            ( { model | guard = guard }, Cmd.map GuardMsg cmd )

-- the save came back: go there, and withdraw a question about another place
SavedThenGo route ->
    let
        ( guard, cmd ) =
            LeaveGuard.dismiss (LeaveGuard.setDirty NoteForm False model.guard)
    in
    ( { model | guard = guard, route = route }, Cmd.map GuardMsg cmd )

-- view: the page is inert while the question is open
Overlay.host
    { attributes = []
    , page = [ page ]
    , overlays = [ LeaveGuard.view GuardMsg [ LeaveGuard.saveAndLeave ] model.guard ]
    }"""


guardBrowserCode : String
guardBrowserCode =
    """-- init: the guard knows the address of the page
init _ url key =
    ( { key = key
      , route = Route.fromUrl url
      , guard = LeaveGuard.initAt "leave-dialog" key url
      }
    , Cmd.none
    )

-- links and your own navigation still ask first
LinkClicked (Browser.Internal url) ->
    case LeaveGuard.request (Route.fromUrl url) model.guard of
        Proceed route ->
            ( model, Nav.pushUrl model.key (Route.toPath route) )

        Hold guard cmd ->
            ( { model | guard = guard }, Cmd.map GuardMsg cmd )

-- every change of the address, the Back and Forward buttons included
UrlChanged url ->
    case LeaveGuard.onUrlChange Route.fromUrl url model.guard of
        ( guard, cmd, Just route ) ->
            -- show this page, and move focus to its content
            enter route { model | guard = guard }
                |> addCmd (Cmd.map GuardMsg cmd)

        ( guard, cmd, Nothing ) ->
            -- asked, or nothing to do
            ( { model | guard = guard }, Cmd.map GuardMsg cmd )

-- every "Leave" hands the route back, after a link and after Back: reset what was
-- given up here; follow pushes a link and does nothing after Back (the address is there)
GuardMsg inner ->
    case LeaveGuard.update inner model.guard of
        ( guard, cmd, Just answer ) ->
            ( { model | guard = guard, note = model.noteSaved }
            , Cmd.batch [ Cmd.map GuardMsg cmd, LeaveGuard.follow Route.toPath answer guard ]
            )

        ( guard, cmd, Nothing ) ->
            ( { model | guard = guard }, Cmd.map GuardMsg cmd )"""


historyCode : String
historyCode =
    """History.record
    [ History.label "Changed quantity", History.coalesce Quantity ]
    { draft | quantity = text }
    model.history

FieldLeft ->
    ( { model | history = History.endBurst model.history }, Cmd.none )

History.controls [ History.showShortcuts ]
    { onUndo = UndoPressed, onRedo = RedoPressed }
    model.history

-- keys: the page listens, History only makes the shortcuts
Shortcut.listen ShortcutMsg
    (History.shortcuts [] { onUndo = UndoPressed, onRedo = RedoPressed }
        |> List.map Shortcut.inInputs
    )
    model.shortcuts

-- dirty is whether the value differs from what is saved
FormLayout.unsavedFlag [] (not (History.isAtSavedPoint model.history))"""
