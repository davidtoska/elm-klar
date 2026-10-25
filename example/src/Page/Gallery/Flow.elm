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
import Showcase.Config as Config
import Showcase.Doc as Doc
import Showcase.Options as Options
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
pageShortcuts : Config.Config -> Locale -> List (Shortcut Msg)
pageShortcuts playground locale =
    History.shortcuts (Options.klarHistory playground (List.concat [ Config.keep playground "History" "locale" (History.locale locale) ])) { onUndo = UndoPressed, onRedo = RedoPressed }
        |> List.map Shortcut.inInputs



-- UPDATE


update : Config.Config -> Msg -> Model -> ( Model, Cmd Msg )
update playground msg model =
    case msg of
        ShortcutMsg inner ->
            let
                ( state, fired ) =
                    -- the language only changes the names in the sheet, not the keys
                    Shortcut.update (pageShortcuts playground Locale.default) inner model.shortcuts
            in
            case fired of
                Just next ->
                    update playground next { model | shortcuts = state }

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


subscriptions : Config.Config -> Model -> Sub Msg
subscriptions playground model =
    Shortcut.subscription ShortcutMsg (pageShortcuts playground Locale.default) model.shortcuts



-- VIEW


view : Config.Config -> Locale -> Model -> Html Msg
view playground locale model =
    Overlay.host
        { attributes = [ Shortcut.listen ShortcutMsg (pageShortcuts playground locale) model.shortcuts ]
        , page =
            [ Doc.configuredPage playground
                { title = "Pages and flow"
                , description = "The page for a result, the bar of actions for a selection, the question that stops a user from losing unsaved work, and undo and redo. Each has a small working scene around it. The language switch in the top bar changes the built-in texts."
                }
                [ statusSection playground locale model
                , bulkSection playground locale model
                , guardSection playground locale model
                , historySection playground locale model
                ]
            ]
        , overlays = [ LeaveGuard.view GuardMsg (guardAttributes playground locale model) model.guard ]
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


statusSection : Config.Config -> Locale -> Model -> Html Msg
statusSection playground locale model =
    Doc.configuredSection playground
        [ "StatusPage" ]
        "Status page"
        "A result that is the whole page, where Klar.EmptyState and Klar.ErrorState are the versions that live inside a table or a card. The kind of page chooses the icon, the color and the text; the actions are your buttons. There is exactly one h1, no live region (a page that arrives with a navigation is content, not an alert) and nothing takes focus by itself. The pages below fill their frames the way they fill the content of an application shell."
        [ Doc.configuredExample playground
            [ "StatusPage" ]
            { title = "The kinds"
            , description = Just "Success, not found, no access, signed out, server error, offline and maintenance. Each has a built-in text in English and Norwegian Bokmål, which the title and description attributes replace."
            , code = Just kindsCode
            }
            (Layout.grid (Options.klarLayout playground (List.concat [ Config.keep playground "Layout" "minColumn" (Layout.minColumn 320), Config.keep playground "Layout" "gap" (Layout.gap 4) ]))
                [ labelled "StatusPage.success" (frame 380 (StatusPage.view (Options.klarStatusPage playground (List.concat [ Config.keep playground "StatusPage" "locale" (StatusPage.locale locale), Config.keep playground "StatusPage" "actions" (StatusPage.actions [ Options.buttonView playground (Options.klarButton playground (List.concat [ Config.keep playground "Button" "href" (Button.href (Link.internal "#/components/flow")) ])) "Back to orders" ]) ])) StatusPage.success))
                , labelled "StatusPage.pageNotFound" (frame 380 (StatusPage.view (Options.klarStatusPage playground (List.concat [ Config.keep playground "StatusPage" "locale" (StatusPage.locale locale), Config.keep playground "StatusPage" "actions" (StatusPage.actions [ Options.buttonView playground (Options.klarButton playground (List.concat [ Config.keep playground "Button" "primary" Button.primary, Config.keep playground "Button" "href" (Button.href (Link.internal "#/orders")) ])) "Go to orders" ]) ])) StatusPage.pageNotFound))
                , labelled "StatusPage.forbidden" (frame 380 (StatusPage.view (Options.klarStatusPage playground (List.concat [ Config.keep playground "StatusPage" "locale" (StatusPage.locale locale), Config.keep playground "StatusPage" "actions" (StatusPage.actions [ Options.buttonView playground (Options.klarButton playground (List.concat [ Config.keep playground "Button" "href" (Button.href (Link.internal "#/")) ])) "Home" ]) ])) StatusPage.forbidden))
                , labelled "StatusPage.unauthorized" (frame 380 (StatusPage.view (Options.klarStatusPage playground (List.concat [ Config.keep playground "StatusPage" "locale" (StatusPage.locale locale), Config.keep playground "StatusPage" "actions" (StatusPage.actions [ Options.buttonView playground (Options.klarButton playground (List.concat [ Config.keep playground "Button" "primary" Button.primary, Config.keep playground "Button" "href" (Button.href (Link.internal "#/")) ])) "Sign in" ]) ])) StatusPage.unauthorized))
                , labelled "StatusPage.server" (frame 380 (StatusPage.view (Options.klarStatusPage playground (List.concat [ Config.keep playground "StatusPage" "locale" (StatusPage.locale locale), Config.keep playground "StatusPage" "onRetry" (StatusPage.onRetry NoOp), Config.keep playground "StatusPage" "reference" (StatusPage.reference "req-7f3a-91c2") ])) StatusPage.server))
                , labelled "StatusPage.network" (frame 380 (StatusPage.view (Options.klarStatusPage playground (List.concat [ Config.keep playground "StatusPage" "locale" (StatusPage.locale locale), Config.keep playground "StatusPage" "onRetry" (StatusPage.onRetry NoOp) ])) StatusPage.network))
                , labelled "StatusPage.retrying True: the button is busy where it is and keeps focus" (frame 380 (StatusPage.view (Options.klarStatusPage playground (List.concat [ Config.keep playground "StatusPage" "locale" (StatusPage.locale locale), Config.keep playground "StatusPage" "onRetry" (StatusPage.onRetry NoOp), Config.keep playground "StatusPage" "retrying" (StatusPage.retrying True) ])) StatusPage.network))
                , labelled "StatusPage.maintenance" (frame 380 (StatusPage.view (Options.klarStatusPage playground (List.concat [ Config.keep playground "StatusPage" "locale" (StatusPage.locale locale), Config.keep playground "StatusPage" "onRetry" (StatusPage.onRetry NoOp) ])) StatusPage.maintenance))
                , labelled "StatusPage.maintenance with backAt (UTC without settings)" (frame 380 (StatusPage.view (Options.klarStatusPage playground (List.concat [ Config.keep playground "StatusPage" "locale" (StatusPage.locale locale), Config.keep playground "StatusPage" "onRetry" (StatusPage.onRetry NoOp), Config.keep playground "StatusPage" "backAt" (StatusPage.backAt (Time.millisToPosix 52200000)) ])) StatusPage.maintenance))
                ]
            )
        , Doc.configuredExample playground
            [ "StatusPage" ]
            { title = "For a failed request"
            , description = Just "fromProblem picks the icon and the color from the kind of the problem and takes the texts of the problem, so Remote.withTitle and friends change them. Try again is offered only when trying again can help. The reference is selected by one click (copying needs JavaScript), so Ctrl C copies it."
            , code = Just problemCode
            }
            (Layout.stack (Options.klarLayout playground (List.concat [ Config.keep playground "Layout" "gap" (Layout.gap 3) ]))
                [ Layout.row (Options.klarLayout playground (List.concat [ Config.keep playground "Layout" "gap" (Layout.gap 2), Config.keep playground "Layout" "wrap" Layout.wrap ]))
                    (List.map (problemButton playground model)
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
                        (Options.klarStatusPage playground
                            (List.concat
                                [ Config.keep playground "StatusPage" "locale" (StatusPage.locale locale)
                                , Config.keep playground "StatusPage" "onRetry" (StatusPage.onRetry Retried)
                                , Config.keep playground "StatusPage" "reference" (StatusPage.reference "req-7f3a-91c2")
                                , Config.keep playground "StatusPage" "actions" (StatusPage.actions [ Options.buttonView playground (Options.klarButton playground (List.concat [ Config.keep playground "Button" "href" (Button.href (Link.internal "#/orders")) ])) "Go to orders" ])
                                ]
                            )
                        )
                        (StatusPage.fromProblem (Remote.problem model.problem |> Remote.withCode "503"))
                    )
                , Text.caption ("Try again was pressed " ++ String.fromInt model.retries ++ " times.")
                ]
            )
        , Doc.configuredExample playground
            [ "StatusPage" ]
            { title = "Replacing a form, with focus"
            , description = Just "The form is replaced by the result without a navigation, so the button that was pressed is gone and focus would fall to the page. The page has an id and the update calls Klar.focus with it: the title takes focus, and a screen reader reads the result. Create another order takes focus back to the field."
            , code = Just focusCode
            }
            (frame 380
                (if model.created then
                    StatusPage.view
                        (Options.klarStatusPage playground
                            (List.concat
                                [ Config.keep playground "StatusPage" "locale" (StatusPage.locale locale)
                                , Config.keep playground "StatusPage" "id" (StatusPage.id createdId)
                                , Config.keep playground "StatusPage" "title" (StatusPage.title ("Order created for " ++ model.customer))
                                , Config.keep playground "StatusPage" "description" (StatusPage.description "A confirmation was sent to the customer.")
                                , Config.keep playground "StatusPage" "icon" (StatusPage.icon Icon.package)
                                , Config.keep playground
                                    "StatusPage"
                                    "actions"
                                    (StatusPage.actions
                                        [ Options.buttonView playground (Options.klarButton playground (List.concat [ Config.keep playground "Button" "primary" Button.primary, Config.keep playground "Button" "onClick" (Button.onClick CreateAnother) ])) "Create another order"
                                        , Options.buttonView playground (Options.klarButton playground (List.concat [ Config.keep playground "Button" "href" (Button.href (Link.internal "#/orders")) ])) "Open orders"
                                        ]
                                    )
                                , Config.keep playground "StatusPage" "reference" (StatusPage.reference "ORD-1042")
                                ]
                            )
                        )
                        StatusPage.success

                 else
                    Html.div [ Attr.style "padding" "var(--klar-space-6)", Attr.style "max-width" "420px" ]
                        [ Layout.stack (Options.klarLayout playground (List.concat [ Config.keep playground "Layout" "gap" (Layout.gap 3) ]))
                            [ Text.heading "New order"
                            , TextInput.view
                                (Options.klarTextInput playground
                                    (List.concat
                                        [ Config.keep playground "TextInput" "id" (TextInput.id "flow-customer")
                                        , Config.keep playground "TextInput" "label" (TextInput.label "Customer")
                                        , Config.keep playground "TextInput" "value" (TextInput.value model.customer)
                                        , Config.keep playground "TextInput" "onInput" (TextInput.onInput CustomerTyped)
                                        , Config.keep playground "TextInput" "onEnter" (TextInput.onEnter CreateOrder)
                                        , Config.keep playground "TextInput" "locale" (TextInput.locale locale)
                                        ]
                                    )
                                )
                            , Options.buttonView playground
                                (Options.klarButton playground
                                    (List.concat
                                        [ Config.keep playground "Button" "id" (Button.id "flow-create-order")
                                        , Config.keep playground "Button" "primary" Button.primary
                                        , Config.keep playground "Button" "disabled" (Button.disabled (String.isEmpty (String.trim model.customer)))
                                        , Config.keep playground "Button" "onClick" (Button.onClick CreateOrder)
                                        ]
                                    )
                                )
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


problemButton : Config.Config -> Model -> ( String, Remote.Kind ) -> Html Msg
problemButton playground model ( name, kind ) =
    Options.buttonView playground
        (Options.klarButton playground
            (List.concat
                [ Config.keep playground "Button" "small" Button.small
                , Config.keep playground "Button" "pressed" (Button.pressed (model.problem == kind))
                , Config.keep playground "Button" "onClick" (Button.onClick (ProblemPicked kind))
                ]
            )
        )
        name



-- BULK BAR


bulkSection : Config.Config -> Locale -> Model -> Html Msg
bulkSection playground locale model =
    let
        count =
            selectedCount model

        pageSelected =
            List.all (isPicked model) pageOrders
    in
    Doc.configuredSection playground
        [ "BulkBar" ]
        "Bulk action bar"
        "Appears when a selection is not empty: the count, the actions for it and Clear selection. It does not push anything: the bar takes the place of the toolbar, in the same box, and the toolbar underneath keeps its state (type in the search field, then select a row). The count is announced politely by one region that is always on the page. It never takes focus by itself, and Escape does nothing here: whether Escape clears is the application's decision."
        [ Doc.configuredExample playground
            [ "BulkBar" ]
            { title = "A selectable list of orders"
            , description = Just "Tick a row, then the box in the header. When the whole page is selected and more orders match, the bar offers Select all 1,240 matching and says 8 of 1,240 orders selected (itemName names the items). Select all stays in its place as an inactive button, so focus is never lost. Clear selection and Delete take the bar away with the button that has focus, and the update calls Klar.focus with the id of the bar: focus goes to the toolbar box, and Tab reaches its first control."
            , code = Just bulkCode
            }
            (Layout.stack (Options.klarLayout playground (List.concat [ Config.keep playground "Layout" "gap" (Layout.gap 3) ]))
                [ BulkBar.view
                    (Options.klarBulkBar playground
                        (List.concat
                            [ Config.keep playground "BulkBar" "id" (BulkBar.id "flow-bulk")
                            , Config.keep playground "BulkBar" "locale" (BulkBar.locale locale)
                            , Config.keep playground "BulkBar" "itemName" (BulkBar.itemName (Locale.pick locale { en = { one = "order", other = "orders" }, nb = { one = "ordre", other = "ordrer" } }))
                            , Config.keep playground "BulkBar" "selectAllMatching" (BulkBar.selectAllMatching { total = matching, onPage = List.length pageOrders, onSelectAll = SelectEverything })
                            ]
                        )
                    )
                    { toolbar =
                        Toolbar.view (Options.klarToolbar playground (List.concat [ Config.keep playground "Toolbar" "ariaLabel" (Toolbar.ariaLabel "Orders") ]))
                            [ Toolbar.label "Orders"
                            , Toolbar.spacer
                            , TextInput.view
                                (Options.klarTextInput playground
                                    (List.concat
                                        [ Config.keep playground "TextInput" "search" TextInput.search
                                        , Config.keep playground "TextInput" "label" (TextInput.label "Search orders")
                                        , Config.keep playground "TextInput" "labelHidden" TextInput.labelHidden
                                        , Config.keep playground "TextInput" "placeholder" (TextInput.placeholder "Search orders")
                                        , Config.keep playground "TextInput" "value" (TextInput.value model.search)
                                        , Config.keep playground "TextInput" "onInput" (TextInput.onInput SearchTyped)
                                        , Config.keep playground "TextInput" "locale" (TextInput.locale locale)
                                        ]
                                    )
                                )
                            , Options.buttonView playground (Options.klarButton playground (List.concat [ Config.keep playground "Button" "primary" Button.primary, Config.keep playground "Button" "icon" (Button.icon Icon.plus) ])) "New order"
                            ]
                    , selected = count
                    , onClear = ClearSelection
                    }
                    [ Options.buttonView playground (Options.klarButton playground (List.concat [ Config.keep playground "Button" "icon" (Button.icon Icon.download), Config.keep playground "Button" "onClick" (Button.onClick Exported) ])) "Export"
                    , Menu.view MoreMenuMsg
                        (Options.klarMenu playground
                            (List.concat
                                [ Config.keep playground "Menu" "label" (Menu.label "More actions")
                                , Config.keep playground "Menu" "alignEnd" Menu.alignEnd
                                , Config.keep playground
                                    "Menu"
                                    "items"
                                    (Menu.items
                                        [ Menu.item "Assign to me" Assigned |> Menu.withIcon Icon.user
                                        ]
                                    )
                                ]
                            )
                        )
                        model.moreMenu
                    , Options.buttonView playground (Options.klarButton playground (List.concat [ Config.keep playground "Button" "danger" Button.danger, Config.keep playground "Button" "icon" (Button.icon Icon.trash), Config.keep playground "Button" "onClick" (Button.onClick Deleted) ])) "Delete"
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
                            (Options.klarCheckbox playground
                                (List.concat
                                    [ Config.keep playground "Checkbox" "ariaLabel" (Checkbox.ariaLabel "Select all orders on this page")
                                    , Config.keep playground "Checkbox" "checked" (Checkbox.checked pageSelected)
                                    , Config.keep playground "Checkbox" "indeterminate" (Checkbox.indeterminate (count > 0 && not pageSelected))
                                    , Config.keep playground "Checkbox" "onCheck" (Checkbox.onCheck PageToggled)
                                    ]
                                )
                            )
                        ]
                        :: List.map (orderRow playground locale model) pageOrders
                    )
                , case model.outcome of
                    Just text ->
                        Options.alertView playground (Options.klarAlert playground (List.concat [ Config.keep playground "Alert" "compact" Alert.compact, Config.keep playground "Alert" "polite" Alert.polite, Config.keep playground "Alert" "locale" (Alert.locale locale) ])) text

                    Nothing ->
                        Text.caption ("Showing " ++ String.fromInt (List.length pageOrders) ++ " of " ++ Format.int locale matching ++ " matching orders.")
                ]
            )
        ]


orderRow : Config.Config -> Locale -> Model -> Types.Order -> Html Msg
orderRow playground locale model order =
    Html.div
        [ Attr.style "display" "flex"
        , Attr.style "align-items" "center"
        , Attr.style "gap" "var(--klar-space-3)"
        , Attr.style "padding" "var(--klar-space-2) var(--klar-space-3)"
        , Attr.style "border-bottom" "1px solid var(--klar-border-subtle)"
        ]
        [ Checkbox.view
            (Options.klarCheckbox playground
                (List.concat
                    [ Config.keep playground "Checkbox" "ariaLabel" (Checkbox.ariaLabel ("Select order " ++ orderKey order))
                    , Config.keep playground "Checkbox" "checked" (Checkbox.checked (isPicked model order))
                    , Config.keep playground "Checkbox" "onCheck" (Checkbox.onCheck (RowToggled (orderKey order)))
                    ]
                )
            )
        , Html.span [ Attr.style "min-width" "7ch" ] [ Text.mono (orderKey order) ]
        , Html.span [ Attr.style "flex" "1" ] [ Html.text order.customer ]
        , Html.span [ Attr.class "klar-tabular" ] [ Html.text (Format.currency locale "$" 2 order.total) ]
        ]



-- LEAVE GUARD


guardAttributes : Config.Config -> Locale -> Model -> List (LeaveGuard.Attribute Msg)
guardAttributes playground locale model =
    LeaveGuard.locale locale
        :: (if model.offerSave then
                Options.klarLeaveGuard playground (List.concat [ Config.keep playground "LeaveGuard" "saveAndLeave" LeaveGuard.saveAndLeave ])

            else
                []
           )


guardSection : Config.Config -> Locale -> Model -> Html Msg
guardSection playground locale model =
    Doc.configuredSection playground
        [ "LeaveGuard" ]
        "Leave guard"
        "Asks \"Leave without saving?\" when the user navigates inside the application while something is not saved. Every navigation goes through LeaveGuard.request: a clean guard answers Proceed with the value, a dirty one answers Hold and opens the dialog, and the held value comes back as data when the user chooses. Several forms are independent sources, and the guard is clean only when all are. The browser's Back and Forward buttons are answered by one more function, LeaveGuard.onUrlChange (second example). Closing the tab, reloading and typing another address cannot be intercepted without JavaScript."
        [ Doc.configuredExample playground
            [ "LeaveGuard" ]
            { title = "A fake application with two forms"
            , description = Just "Change the note or the address, then press Customers or Settings. Focus goes to Stay, Escape means Stay, and focus returns to the button you pressed. Save the forms, or undo the edit by hand, and the next move is free. Save and leave saves for a moment and then goes."
            , code = Just guardCode
            }
            (Layout.stack (Options.klarLayout playground (List.concat [ Config.keep playground "Layout" "gap" (Layout.gap 3) ]))
                [ Layout.row (Options.klarLayout playground (List.concat [ Config.keep playground "Layout" "gap" (Layout.gap 2), Config.keep playground "Layout" "wrap" Layout.wrap, Config.keep playground "Layout" "alignCenter" Layout.alignCenter ]))
                    [ routeButton playground model Orders "Orders"
                    , routeButton playground model Customers "Customers"
                    , routeButton playground model Settings "Settings"
                    , Layout.spacer
                    , Checkbox.view
                        (Options.klarCheckbox playground
                            (List.concat
                                [ Config.keep playground "Checkbox" "label" (Checkbox.label "Offer Save and leave")
                                , Config.keep playground "Checkbox" "checked" (Checkbox.checked model.offerSave)
                                , Config.keep playground "Checkbox" "onCheck" (Checkbox.onCheck OfferSaveToggled)
                                ]
                            )
                        )
                    ]
                , Html.div
                    [ Attr.style "border" "1px solid var(--klar-border)"
                    , Attr.style "border-radius" "var(--klar-radius-lg)"
                    , Attr.style "padding" "var(--klar-space-4)"
                    , Attr.style "background" "var(--klar-surface)"
                    ]
                    [ case model.route of
                        Orders ->
                            Layout.stack (Options.klarLayout playground (List.concat [ Config.keep playground "Layout" "gap" (Layout.gap 4) ]))
                                [ Text.heading "Order 1042"
                                , Layout.grid (Options.klarLayout playground (List.concat [ Config.keep playground "Layout" "minColumn" (Layout.minColumn 280), Config.keep playground "Layout" "gap" (Layout.gap 4) ]))
                                    [ Layout.stack (Options.klarLayout playground (List.concat [ Config.keep playground "Layout" "gap" (Layout.gap 2) ]))
                                        [ TextArea.view
                                            (Options.klarTextArea playground
                                                (List.concat
                                                    [ Config.keep playground "TextArea" "id" (TextArea.id "flow-note")
                                                    , Config.keep playground "TextArea" "label" (TextArea.label "Delivery note")
                                                    , Config.keep playground "TextArea" "value" (TextArea.value model.note)
                                                    , Config.keep playground "TextArea" "rows" (TextArea.rows 3)
                                                    , Config.keep playground "TextArea" "onInput" (TextArea.onInput NoteTyped)
                                                    , Config.keep playground "TextArea" "locale" (TextArea.locale locale)
                                                    ]
                                                )
                                            )
                                        , Layout.row (Options.klarLayout playground (List.concat [ Config.keep playground "Layout" "gap" (Layout.gap 2), Config.keep playground "Layout" "alignCenter" Layout.alignCenter ]))
                                            [ Options.buttonView playground (Options.klarButton playground (List.concat [ Config.keep playground "Button" "small" Button.small, Config.keep playground "Button" "onClick" (Button.onClick SaveNote), Config.keep playground "Button" "disabled" (Button.disabled (model.note == model.noteSaved)) ])) "Save note"
                                            , FormLayout.unsavedFlag (Options.klarFormLayout playground (List.concat [ Config.keep playground "Form.Layout" "locale" (FormLayout.locale locale) ])) (model.note /= model.noteSaved)
                                            ]
                                        ]
                                    , Layout.stack (Options.klarLayout playground (List.concat [ Config.keep playground "Layout" "gap" (Layout.gap 2) ]))
                                        [ TextInput.view
                                            (Options.klarTextInput playground
                                                (List.concat
                                                    [ Config.keep playground "TextInput" "id" (TextInput.id "flow-address")
                                                    , Config.keep playground "TextInput" "label" (TextInput.label "Shipping address")
                                                    , Config.keep playground "TextInput" "value" (TextInput.value model.address)
                                                    , Config.keep playground "TextInput" "onInput" (TextInput.onInput AddressTyped)
                                                    , Config.keep playground "TextInput" "locale" (TextInput.locale locale)
                                                    ]
                                                )
                                            )
                                        , Layout.row (Options.klarLayout playground (List.concat [ Config.keep playground "Layout" "gap" (Layout.gap 2), Config.keep playground "Layout" "alignCenter" Layout.alignCenter ]))
                                            [ Options.buttonView playground (Options.klarButton playground (List.concat [ Config.keep playground "Button" "small" Button.small, Config.keep playground "Button" "onClick" (Button.onClick SaveAddress), Config.keep playground "Button" "disabled" (Button.disabled (model.address == model.addressSaved)) ])) "Save address"
                                            , FormLayout.unsavedFlag (Options.klarFormLayout playground (List.concat [ Config.keep playground "Form.Layout" "locale" (FormLayout.locale locale) ])) (model.address /= model.addressSaved)
                                            ]
                                        ]
                                    ]
                                ]

                        Customers ->
                            Layout.stack (Options.klarLayout playground (List.concat [ Config.keep playground "Layout" "gap" (Layout.gap 2) ]))
                                [ Text.heading "Customers"
                                , Text.paragraph "You are on another page. Go back to Orders to change the forms again."
                                ]

                        Settings ->
                            Layout.stack (Options.klarLayout playground (List.concat [ Config.keep playground "Layout" "gap" (Layout.gap 2) ]))
                                [ Text.heading "Settings"
                                , Text.paragraph "You are on another page. Go back to Orders to change the forms again."
                                ]
                    ]
                , Layout.row (Options.klarLayout playground (List.concat [ Config.keep playground "Layout" "gap" (Layout.gap 3), Config.keep playground "Layout" "wrap" Layout.wrap, Config.keep playground "Layout" "alignCenter" Layout.alignCenter ]))
                    [ if LeaveGuard.isDirty model.guard then
                        Options.badgeView playground (Options.klarBadge playground (List.concat [ Config.keep playground "Badge" "tone" (Badge.tone Theme.Warning) ])) "Unsaved"

                      else
                        Options.badgeView playground (Options.klarBadge playground (List.concat [ Config.keep playground "Badge" "tone" (Badge.tone Theme.Success) ])) "Everything saved"
                    , Text.caption ("Dirty sources: " ++ dirtyText (LeaveGuard.dirtySources model.guard))
                    , case model.saving of
                        Just route ->
                            Layout.row (Options.klarLayout playground (List.concat [ Config.keep playground "Layout" "gap" (Layout.gap 2), Config.keep playground "Layout" "alignCenter" Layout.alignCenter ]))
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
            (Layout.stack (Options.klarLayout playground (List.concat [ Config.keep playground "Layout" "gap" (Layout.gap 2) ]))
                [ Text.paragraph "Back while something is dirty: the page stays, the question opens, the address bar is already at the page you pressed Back to."
                , Text.paragraph "Stay pushes the address of the page that is shown. Leave shows the page you wanted. A second Back after Stay asks again."
                , Text.caption "The guard never moves in the history to undo a button, which is what looped in the first recipe."
                ]
            )
        ]


routeButton : Config.Config -> Model -> Route -> String -> Html Msg
routeButton playground model route name =
    Options.buttonView playground
        (Options.klarButton playground
            (List.concat
                [ Config.keep playground "Button" "id" (Button.id ("flow-go-" ++ String.toLower name))
                , Config.keep playground "Button" "pressed" (Button.pressed (model.route == route))
                , Config.keep playground "Button" "onClick" (Button.onClick (Navigate route))
                ]
            )
        )
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


historySection : Config.Config -> Locale -> Model -> Html Msg
historySection playground locale model =
    let
        draft =
            History.present model.history
    in
    Doc.configuredSection playground
        [ "History" ]
        "Undo history"
        "Undo and redo as a plain value: the present, the steps before it and the steps after it. Typing in one field is one step (a burst) and ends when the field loses focus; every step has a label that a screen reader hears (\"Undid: Changed quantity\"). History does not listen to the keyboard: the page wires Ctrl Z and Ctrl Shift Z with Klar.Shortcut, marked inInputs because every key typed here is recorded. The saved point tells whether the value is still what was saved."
        [ Doc.configuredExample playground
            [ "History" ]
            { title = "Two fields with undo and redo"
            , description = Just "Type in the quantity, leave the field, type in the note, then press Ctrl Z or the Undo button. Mark saved sets the saved point; undoing past it makes the form dirty again, and redo comes back to it."
            , code = Just historyCode
            }
            (Layout.stack (Options.klarLayout playground (List.concat [ Config.keep playground "Layout" "gap" (Layout.gap 3) ]))
                [ Toolbar.view (Options.klarToolbar playground (List.concat [ Config.keep playground "Toolbar" "ariaLabel" (Toolbar.ariaLabel "Edit") ]))
                    [ History.controls (Options.klarHistory playground (List.concat [ Config.keep playground "History" "locale" (History.locale locale), Config.keep playground "History" "showShortcuts" History.showShortcuts ]))
                        { onUndo = UndoPressed, onRedo = RedoPressed }
                        model.history
                    , Toolbar.separator
                    , Options.buttonView playground (Options.klarButton playground (List.concat [ Config.keep playground "Button" "icon" (Button.icon Icon.save), Config.keep playground "Button" "onClick" (Button.onClick MarkSaved), Config.keep playground "Button" "disabled" (Button.disabled (History.isAtSavedPoint model.history)) ])) "Mark saved"
                    , Options.buttonView playground (Options.klarButton playground (List.concat [ Config.keep playground "Button" "icon" (Button.icon Icon.refresh), Config.keep playground "Button" "onClick" (Button.onClick DiscardChanges), Config.keep playground "Button" "disabled" (Button.disabled (History.isAtSavedPoint model.history)) ])) "Discard changes"
                    , Toolbar.spacer
                    , FormLayout.unsavedFlag (Options.klarFormLayout playground (List.concat [ Config.keep playground "Form.Layout" "locale" (FormLayout.locale locale) ])) (not (History.isAtSavedPoint model.history))
                    ]
                , Layout.grid (Options.klarLayout playground (List.concat [ Config.keep playground "Layout" "minColumn" (Layout.minColumn 240), Config.keep playground "Layout" "gap" (Layout.gap 4) ]))
                    [ TextInput.view
                        (Options.klarTextInput playground
                            (List.concat
                                [ Config.keep playground "TextInput" "id" (TextInput.id "flow-quantity")
                                , Config.keep playground "TextInput" "label" (TextInput.label "Quantity")
                                , Config.keep playground "TextInput" "value" (TextInput.value draft.quantity)
                                , Config.keep playground "TextInput" "onInput" (TextInput.onInput QuantityTyped)
                                , Config.keep playground "TextInput" "onBlur" (TextInput.onBlur FieldLeft)
                                , Config.keep playground "TextInput" "locale" (TextInput.locale locale)
                                ]
                            )
                        )
                    , TextArea.view
                        (Options.klarTextArea playground
                            (List.concat
                                [ Config.keep playground "TextArea" "id" (TextArea.id "flow-history-note")
                                , Config.keep playground "TextArea" "label" (TextArea.label "Note")
                                , Config.keep playground "TextArea" "value" (TextArea.value draft.note)
                                , Config.keep playground "TextArea" "rows" (TextArea.rows 3)
                                , Config.keep playground "TextArea" "onInput" (TextArea.onInput HistoryNoteTyped)
                                , Config.keep playground "TextArea" "onBlur" (TextArea.onBlur FieldLeft)
                                , Config.keep playground "TextArea" "locale" (TextArea.locale locale)
                                ]
                            )
                        )
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
      , guard = LeaveGuard.initAt "leave-dialog" key Route.fromUrl url
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
        ( guard, cmd, Enter route ) ->
            -- show this page, and move focus to its content
            enter route { model | guard = guard }
                |> addCmd (Cmd.map GuardMsg cmd)

        ( guard, cmd, SamePage address ) ->
            -- the page that is shown, at another address (a sort, a tab): apply it, keep the work
            ( applyQuery address { model | guard = guard }, Cmd.map GuardMsg cmd )

        ( guard, cmd, Unchanged ) ->
            -- asked, or nothing to do
            ( { model | guard = guard }, Cmd.map GuardMsg cmd )

-- every "Leave" hands the route back, after a link and after Back: reset what was
-- given up here; follow pushes a link and does nothing after Back (the address is there)
GuardMsg inner ->
    case LeaveGuard.update inner model.guard of
        ( guard, cmd, Just answer ) ->
            -- this dialog has no saveAndLeave; with it, check LeaveGuard.savesFirst first
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
