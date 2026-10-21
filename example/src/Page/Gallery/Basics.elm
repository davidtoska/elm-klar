module Page.Gallery.Basics exposing (Model, Msg, init, subscriptions, update, view)

{-| Gallery page: buttons, menus, badges and tags, alerts, loading, empty and
error states, text fields and checkboxes.
-}

import Api.Types as Types
import Browser.Dom as Dom
import Dict exposing (Dict)
import Html exposing (Html)
import Klar.Alert as Alert
import Klar.Badge as Badge
import Klar.Button as Button
import Klar.Card as Card
import Klar.Checkbox as Checkbox
import Klar.EmptyState as EmptyState
import Klar.ErrorState as ErrorState
import Klar.Format as Format
import Klar.Icon as Icon
import Klar.Layout as Layout
import Klar.Locale as Locale exposing (Locale)
import Klar.Menu as Menu
import Klar.Remote as Remote exposing (Remote)
import Klar.Search as Search
import Klar.Skeleton as Skeleton
import Klar.Spinner as Spinner
import Klar.Tag as Tag
import Klar.Text as Text
import Klar.TextInput as TextInput
import Klar.Theme exposing (Size(..), Tone(..))
import Klar.Validate as Validate
import Process
import Showcase.Doc as Doc
import Showcase.Sample as Sample
import Task
import View.Labels as Labels



-- MODEL


type alias Model =
    { clicks : Int
    , saving : Bool
    , viewMode : ViewMode
    , menus : Dict String Menu.State
    , lastAction : String
    , tags : List Types.Warehouse
    , alertDismissed : Bool
    , alertRetries : Int
    , orders : Remote (List Types.Order)
    , scenario : Scenario
    , attempt : Int
    , ticket : Int
    , productSearch : String
    , retried : Maybe Remote.Kind
    , owner : String
    , email : String
    , search : String
    , amount : String
    , comment : String
    , sized : String
    , notify : Bool
    , terms : Bool
    , options : List Bool
    }


type ViewMode
    = AsList
    | AsGrid
    | AsColumns


{-| What the pretend server does when the orders are asked for.
-}
type Scenario
    = Works
    | FailsOnce
    | FailsAlways
    | NoOrders


type Msg
    = NoOp
    | Clicked
    | SaveClicked
    | Saved
    | ViewModeChosen ViewMode
    | MenuMsg String Menu.Msg
    | Picked String
    | TagRemoved String
    | TagsReset
    | DismissAlert
    | RestoreAlert
    | AlertRetried
    | Requested Scenario
    | Retried
    | Responded Int (Result Remote.Problem (List Types.Order))
    | ProductSearchChanged String
    | ProductSearchCleared
    | KindRetried Remote.Kind
    | OwnerChanged String
    | EmailChanged String
    | SearchChanged String
    | AmountChanged String
    | CommentChanged String
    | SizedChanged String
    | NotifyChanged Bool
    | TermsChanged Bool
    | OptionChanged Int Bool
    | AllOptionsChanged Bool


init : ( Model, Cmd Msg )
init =
    ( { clicks = 0
      , saving = False
      , viewMode = AsList
      , menus = Dict.empty
      , lastAction = "No action picked yet"
      , tags = initialTags
      , alertDismissed = False
      , alertRetries = 0
      , orders = Remote.Loading
      , scenario = Works
      , attempt = 1
      , ticket = 1
      , productSearch = "forklift"
      , retried = Nothing
      , owner = ""
      , email = "ada@"
      , search = ""
      , amount = "1250"
      , comment = ""
      , sized = ""
      , notify = True
      , terms = False
      , options = [ True, False, True ]
      }
    , respond 1 Works 1
    )


initialTags : List Types.Warehouse
initialTags =
    List.take 4 Sample.warehouses


{-| The warehouses behind the "select all" example.
-}
optionWarehouses : List Types.Warehouse
optionWarehouses =
    List.take 3 Sample.warehouses



-- DOM IDS


tagRemoveId : Types.Warehouse -> String
tagRemoveId warehouse =
    "basics-tag-remove-" ++ String.toLower warehouse.id


tagsResetId : String
tagsResetId =
    "basics-tags-reset"


alertRestoreId : String
alertRestoreId =
    "basics-alert-restore"


productSearchId : String
productSearchId =
    "basics-product-search"


actionsMenuId : String
actionsMenuId =
    "basics-menu-actions"


newMenuId : String
newMenuId =
    "basics-menu-new"


kebabMenuId : String
kebabMenuId =
    "basics-menu-kebab"


longMenuId : String
longMenuId =
    "basics-menu-long"


rowMenuId : Types.Order -> String
rowMenuId order =
    "basics-menu-row-" ++ order.id



-- UPDATE


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        NoOp ->
            ( model, Cmd.none )

        Clicked ->
            ( { model | clicks = model.clicks + 1 }, Cmd.none )

        SaveClicked ->
            -- a pretend request: the button ignores clicks until it is done
            ( { model | saving = True }, Process.sleep 1500 |> Task.perform (\_ -> Saved) )

        Saved ->
            ( { model | saving = False }, Cmd.none )

        ViewModeChosen mode ->
            ( { model | viewMode = mode }, Cmd.none )

        MenuMsg id inner ->
            let
                ( menu, cmd ) =
                    Menu.update inner (menuState id model)
            in
            ( { model | menus = Dict.insert id menu model.menus }, Cmd.map (MenuMsg id) cmd )

        Picked what ->
            ( { model | lastAction = "Picked: " ++ what }, Cmd.none )

        TagRemoved id ->
            let
                remaining =
                    List.filter (\warehouse -> warehouse.id /= id) model.tags

                position =
                    model.tags
                        |> List.indexedMap Tuple.pair
                        |> List.filter (\( _, warehouse ) -> warehouse.id == id)
                        |> List.head
                        |> Maybe.map Tuple.first
                        |> Maybe.withDefault 0

                -- The tag that was removed took the keyboard focus with it: the
                -- next tag gets it (or the last one, or the button that brings
                -- the tags back).
                target =
                    case List.drop position remaining of
                        next :: _ ->
                            tagRemoveId next

                        [] ->
                            case List.reverse remaining of
                                last :: _ ->
                                    tagRemoveId last

                                [] ->
                                    tagsResetId
            in
            ( { model | tags = remaining }, focus target )

        TagsReset ->
            ( { model | tags = initialTags }
            , case initialTags of
                first :: _ ->
                    focus (tagRemoveId first)

                [] ->
                    Cmd.none
            )

        DismissAlert ->
            -- The × that was pressed is gone: the button that brings the
            -- message back gets the focus.
            ( { model | alertDismissed = True }, focus alertRestoreId )

        RestoreAlert ->
            ( { model | alertDismissed = False }, Cmd.none )

        AlertRetried ->
            ( { model | alertRetries = model.alertRetries + 1 }, Cmd.none )

        Requested scenario ->
            request scenario 1 model

        Retried ->
            request model.scenario (model.attempt + 1) model

        Responded ticket result ->
            -- An answer to a request that has been replaced counts for nothing.
            if ticket == model.ticket then
                ( { model | orders = Remote.fromResult result }, Cmd.none )

            else
                ( model, Cmd.none )

        ProductSearchChanged value ->
            ( { model | productSearch = value }, Cmd.none )

        ProductSearchCleared ->
            -- The button that was pressed is gone: the search field gets the focus.
            ( { model | productSearch = "" }, focus productSearchId )

        KindRetried kind ->
            ( { model | retried = Just kind }, Cmd.none )

        OwnerChanged value ->
            ( { model | owner = value }, Cmd.none )

        EmailChanged value ->
            ( { model | email = value }, Cmd.none )

        SearchChanged value ->
            ( { model | search = value }, Cmd.none )

        AmountChanged value ->
            ( { model | amount = value }, Cmd.none )

        CommentChanged value ->
            ( { model | comment = value }, Cmd.none )

        SizedChanged value ->
            ( { model | sized = value }, Cmd.none )

        NotifyChanged value ->
            ( { model | notify = value }, Cmd.none )

        TermsChanged value ->
            ( { model | terms = value }, Cmd.none )

        OptionChanged index value ->
            ( { model
                | options =
                    List.indexedMap
                        (\i current ->
                            if i == index then
                                value

                            else
                                current
                        )
                        model.options
              }
            , Cmd.none
            )

        AllOptionsChanged value ->
            ( { model | options = List.map (always value) model.options }, Cmd.none )


focus : String -> Cmd Msg
focus id =
    Task.attempt (\_ -> NoOp) (Dom.focus id)


menuState : String -> Model -> Menu.State
menuState id model =
    Dict.get id model.menus |> Maybe.withDefault (Menu.init id)


{-| Sends a pretend request for the orders. Every request gets a new ticket, and
only the answer to the latest one is used.
-}
request : Scenario -> Int -> Model -> ( Model, Cmd Msg )
request scenario attempt model =
    let
        ticket =
            model.ticket + 1
    in
    ( { model | orders = Remote.Loading, scenario = scenario, attempt = attempt, ticket = ticket }
    , respond ticket scenario attempt
    )


respond : Int -> Scenario -> Int -> Cmd Msg
respond ticket scenario attempt =
    Process.sleep 900
        |> Task.perform (\_ -> Responded ticket (backend scenario attempt))


{-| The pretend server: a pure function of what is asked and how many times it
was asked.
-}
backend : Scenario -> Int -> Result Remote.Problem (List Types.Order)
backend scenario attempt =
    case scenario of
        Works ->
            Ok (List.take 5 Sample.orders)

        FailsOnce ->
            if attempt < 2 then
                Err (failure Remote.network "ERR_NETWORK")

            else
                Ok (List.take 5 Sample.orders)

        FailsAlways ->
            Err (failure Remote.server "HTTP 503")

        NoOrders ->
            Ok []


failure : Remote.Kind -> String -> Remote.Problem
failure kind code =
    Remote.problem kind |> Remote.withCode code


subscriptions : Model -> Sub Msg
subscriptions _ =
    Sub.none



-- VIEW


view : Locale -> Model -> Html Msg
view locale model =
    Doc.page
        { title = "Basics"
        , description = "Buttons, menus, badges, messages, loading and error states, and the simplest form fields."
        }
        [ viewButtons model
        , viewMenus model
        , viewBadges locale model
        , viewAlerts locale model
        , viewLoading
        , viewStates locale model
        , viewInputs locale model
        ]



-- BUTTONS


viewButtons : Model -> Html Msg
viewButtons model =
    Doc.section "Buttons"
        "Four looks (primary, secondary, ghost and link) and the solid red danger button. Use only one primary button per area. Ghost is for toolbars and tables. Destructive actions exist in every look."
        [ Doc.example
            { title = "Looks and states"
            , description = Just "Button.disabled takes the button out of the tab order. Button.ariaDisabled dims it the same way but keeps the keyboard focus, for a button that becomes unavailable while the user is on it."
            , code = Just looksCode
            }
            (Layout.row [ Layout.gap 2, Layout.wrap ]
                [ Button.view [ Button.primary, Button.onClick Clicked ] ("Primary (" ++ String.fromInt model.clicks ++ ")")
                , Button.view [ Button.onClick Clicked ] "Secondary"
                , Button.view [ Button.ghost, Button.onClick Clicked ] "Ghost"
                , Button.view [ Button.danger, Button.onClick Clicked ] "Delete"
                , Button.view [ Button.link, Button.onClick Clicked ] "Link button"
                , Button.view [ Button.disabled True ] "Disabled"
                , Button.view [ Button.ariaDisabled True ] "Unavailable"
                ]
            )
        , Doc.example
            { title = "Destructive actions"
            , description = Just "Button.danger on its own (or together with Button.primary) is the solid red button: use it for the confirmation itself. Combined with secondary, ghost or link the button keeps its look and only the text turns red (secondary also gets a red border). The order of the attributes does not matter."
            , code = Just dangerCode
            }
            (Layout.stack [ Layout.gap 4 ]
                [ Layout.row [ Layout.gap 2, Layout.alignCenter, Layout.wrap ]
                    [ Button.view [ Button.danger, Button.icon Icon.trash, Button.onClick Clicked ] "Delete"
                    , Button.view [ Button.secondary, Button.danger, Button.icon Icon.trash, Button.onClick Clicked ] "Delete"
                    , Button.view [ Button.danger, Button.ghost, Button.icon Icon.trash, Button.onClick Clicked ] "Delete"
                    , Button.view [ Button.link, Button.danger, Button.onClick Clicked ] "Delete"
                    , Button.iconOnly [ Button.ghost, Button.danger, Button.onClick Clicked ] Icon.trash "Delete"
                    ]
                , Layout.row [ Layout.gap 2, Layout.alignCenter, Layout.wrap ]
                    [ Button.view [ Button.danger, Button.small, Button.onClick Clicked ] "Small"
                    , Button.view [ Button.secondary, Button.danger, Button.small, Button.onClick Clicked ] "Small"
                    , Button.view [ Button.ghost, Button.danger, Button.small, Button.onClick Clicked ] "Small"
                    , Button.view [ Button.danger, Button.disabled True ] "Disabled"
                    , Button.view [ Button.secondary, Button.danger, Button.disabled True ] "Disabled"
                    , Button.view [ Button.ghost, Button.danger, Button.disabled True ] "Disabled"
                    , Button.view [ Button.secondary, Button.danger, Button.loading True ] "Deleting ..."
                    ]
                ]
            )
        , Doc.example
            { title = "Sizes and icons"
            , description = Just "An icon goes before the label, after it (iconRight), or alone: an icon-only button needs a label, which becomes its accessible name and tooltip."
            , code = Just sizesCode
            }
            (Layout.row [ Layout.gap 2, Layout.alignCenter, Layout.wrap ]
                [ Button.view [ Button.small, Button.icon Icon.plus, Button.onClick Clicked ] "Small"
                , Button.view [ Button.icon Icon.plus, Button.primary, Button.onClick Clicked ] "New order"
                , Button.view [ Button.large, Button.icon Icon.download, Button.onClick Clicked ] "Large"
                , Button.view [ Button.iconRight Icon.arrowRight, Button.onClick Clicked ] "Next"
                , Button.iconOnly [ Button.onClick Clicked ] Icon.settings "Settings"
                , Button.iconOnly [ Button.ghost, Button.onClick Clicked ] Icon.refresh "Reload"
                , Button.iconOnly [ Button.ghost, Button.small, Button.onClick Clicked ] Icon.close "Close"
                , Button.iconOnly [ Button.primary, Button.onClick Clicked ] Icon.search "Search"
                ]
            )
        , Doc.example
            { title = "Loading state"
            , description = Just "A button with loading ignores clicks and shows a spinner instead of its icon. Use it while a request is on its way. Click it to send a pretend request."
            , code = Just loadingButtonCode
            }
            (Button.view [ Button.primary, Button.icon Icon.save, Button.loading model.saving, Button.onClick SaveClicked ]
                (if model.saving then
                    "Saving ..."

                 else
                    "Save"
                )
            )
        , Doc.example
            { title = "Button group"
            , description = Just "Button.group joins buttons into one segmented control. Button.pressed tells screen readers which one is on; here the active one also gets the primary look. For a real choice between views, Klar.SegmentedControl is the better fit: it also handles the arrow keys."
            , code = Just groupCode
            }
            (Button.group
                [ viewModeButton model AsList Icon.list "List"
                , viewModeButton model AsGrid Icon.grid "Grid"
                , viewModeButton model AsColumns Icon.columns "Columns"
                ]
            )
        , Doc.example
            { title = "Links and full width"
            , description = Just "A button with href is a real link, so it can be opened in a new tab, but it keeps the look of a button. Button.block fills its container."
            , code = Just linksCode
            }
            (Layout.stack [ Layout.gap 4 ]
                [ Layout.row [ Layout.gap 2, Layout.alignCenter, Layout.wrap ]
                    [ Button.view [ Button.href "#/components/forms", Button.iconRight Icon.arrowRight ] "Go to Forms"
                    , Button.view [ Button.href "#/orders", Button.newTab, Button.iconRight Icon.externalLink ] "Orders in a new tab"
                    , Button.view [ Button.link, Button.href "#/products" ] "Products"
                    ]
                , Layout.container [ Layout.maxWidth 360, Layout.alignStart ]
                    [ Button.view [ Button.primary, Button.block, Button.onClick Clicked ] "Place order" ]
                ]
            )
        ]


viewModeButton : Model -> ViewMode -> Icon.Icon -> String -> Html Msg
viewModeButton model mode icon label =
    let
        active =
            model.viewMode == mode
    in
    Button.view
        [ Button.icon icon
        , Button.pressed active
        , Button.onClick (ViewModeChosen mode)
        , if active then
            Button.primary

          else
            Button.secondary
        ]
        label



-- MENUS


viewMenus : Model -> Html Msg
viewMenus model =
    Doc.section "Menus"
        "Dropdown menus for actions that do not deserve a button of their own. Keyboard: ArrowDown on the button opens the menu, the arrow keys move the highlight, Home and End jump to the first and last item, Enter or Space picks an item, and Escape or Tab closes the menu. The menu opens above everything else and is never clipped by tables or dialogs. The text on the right of a row (Menu.withHint) only shows a shortcut; the application connects the shortcut itself with Klar.Shortcut."
        [ Doc.example
            { title = "Menus and triggers"
            , description = Just model.lastAction
            , code = Just menuCode
            }
            (Layout.row [ Layout.gap 4, Layout.alignCenter, Layout.wrap ]
                [ viewMenu model
                    actionsMenuId
                    [ Menu.label "Actions"
                    , Menu.items
                        [ Menu.heading "Order"
                        , Menu.item "Edit" (Picked "Edit") |> Menu.withIcon Icon.edit |> Menu.withHint "E"
                        , Menu.item "Duplicate" (Picked "Duplicate") |> Menu.withIcon Icon.copy |> Menu.withHint "Ctrl D"
                        , Menu.item "Export" (Picked "Export") |> Menu.withIcon Icon.download |> Menu.disabledItem
                        , Menu.separator
                        , Menu.item "Delete" (Picked "Delete") |> Menu.withIcon Icon.trash |> Menu.danger
                        ]
                    ]
                , viewMenu model
                    newMenuId
                    [ Menu.label "New"
                    , Menu.trigger [ Button.primary, Button.icon Icon.plus ]
                    , Menu.items
                        [ Menu.item "Order" (Picked "New order") |> Menu.withIcon Icon.fileText
                        , Menu.item "Customer" (Picked "New customer") |> Menu.withIcon Icon.building
                        , Menu.item "Product" (Picked "New product") |> Menu.withIcon Icon.tag
                        ]
                    ]
                , viewMenu model
                    kebabMenuId
                    [ Menu.kebab "More actions"
                    , Menu.alignEnd
                    , Menu.items
                        [ Menu.item "Open" (Picked "Open") |> Menu.withIcon Icon.externalLink
                        , Menu.item "Archive" (Picked "Archive") |> Menu.withIcon Icon.archive
                        ]
                    ]
                ]
            )
        , Doc.example
            { title = "A long menu scrolls"
            , description = Just ("A menu is never taller than about 26 rem (or the window): the rest scrolls. Home and End jump to the first and last item. " ++ model.lastAction)
            , code = Just longMenuCode
            }
            (viewMenu model
                longMenuId
                [ Menu.label "Open customer"
                , Menu.items
                    (List.map
                        (\customer -> Menu.item customer (Picked customer) |> Menu.withIcon Icon.building)
                        (List.take 40 Sample.customers)
                    )
                ]
            )
        , Doc.example
            { title = "Row actions in a scrolling list"
            , description = Just ("The list scrolls, but the menu is not clipped by it: it opens over the edge of the list and, where the browser supports CSS anchor positioning, flips above its button when there is no room below. Cancel is disabled for orders that have shipped. " ++ model.lastAction)
            , code = Just rowMenuCode
            }
            (Card.view [ Card.flush ]
                [ Layout.stack [ Layout.gap 0, Layout.maxHeight 168 ]
                    (List.intersperse Layout.divider (List.map (viewRowWithMenu model) (List.take 8 Sample.orders)))
                ]
            )
        ]


viewMenu : Model -> String -> List (Menu.Attribute Msg) -> Html Msg
viewMenu model id attributes =
    Menu.view (MenuMsg id) attributes (menuState id model)


viewRowWithMenu : Model -> Types.Order -> Html Msg
viewRowWithMenu model order =
    Layout.row [ Layout.gap 3, Layout.padding 2 ]
        [ Text.mono order.id
        , Text.text order.customer
        , Layout.spacer
        , Labels.statusBadge order.status
        , viewMenu model
            (rowMenuId order)
            [ Menu.kebab ("Actions for " ++ order.id)
            , Menu.alignEnd
            , Menu.items (rowMenuItems order)
            ]
        ]


rowMenuItems : Types.Order -> List (Menu.Item Msg)
rowMenuItems order =
    let
        cancellable =
            List.member Types.Cancelled (Types.allowedNextStatuses order.status)

        cancel =
            Menu.item "Cancel order" (Picked ("Cancel " ++ order.id))
                |> Menu.withIcon Icon.ban
                |> Menu.danger
    in
    [ Menu.item "Open" (Picked ("Open " ++ order.id)) |> Menu.withIcon Icon.externalLink
    , Menu.item "Duplicate" (Picked ("Duplicate " ++ order.id)) |> Menu.withIcon Icon.copy
    , Menu.separator
    , if cancellable then
        cancel

      else
        Menu.disabledItem cancel
    ]



-- BADGES AND TAGS


viewBadges : Locale -> Model -> Html Msg
viewBadges locale model =
    Doc.section "Badges and tags"
        "Small labels for state. Use the tone for meaning, not decoration. A badge (Badge) shows a state; a tag (Tag) is something the user has chosen and can take away. Keyboard: Tab to the × on a tag, Enter or Space removes it."
        [ Doc.example
            { title = "Badges"
            , description = Just "A badge shows a state the user reads but does not change. The color is not announced by screen readers, so put the meaning in the text. Counts above 99 show as 99+."
            , code = Just badgeCode
            }
            (Layout.stack [ Layout.gap 3 ]
                [ Layout.row [ Layout.gap 2, Layout.wrap ]
                    [ Badge.view [] "Draft"
                    , Badge.view [ Badge.tone Info ] "Confirmed"
                    , Badge.view [ Badge.tone Primary ] "Shipped"
                    , Badge.view [ Badge.tone Warning ] "Picking"
                    , Badge.view [ Badge.tone Success ] "Delivered"
                    , Badge.view [ Badge.tone Danger ] "Cancelled"
                    ]
                , Layout.row [ Layout.gap 2, Layout.wrap ]
                    [ Badge.view [ Badge.tone Info, Badge.dot ] "With dot"
                    , Badge.view [ Badge.tone Success, Badge.icon Icon.check ] "With icon"
                    , Badge.count 7
                    , Badge.count 128
                    ]
                , Layout.row [ Layout.gap 2, Layout.wrap ]
                    [ Badge.view [ Badge.tone Primary, Badge.solid ] "Solid"
                    , Badge.view [ Badge.tone Success, Badge.solid ] "Solid"
                    , Badge.view [ Badge.tone Danger, Badge.solid ] "Solid"
                    , Badge.view [ Badge.tone Primary, Badge.outline ] "Outline"
                    , Badge.view [ Badge.tone Warning, Badge.outline ] "Outline"
                    , Badge.view [ Badge.size Small ] "Small"
                    , Badge.view [ Badge.size Large, Badge.tone Info ] "Large"
                    ]
                , Layout.row [ Layout.gap 5, Layout.wrap ]
                    [ Badge.status Success "In stock"
                    , Badge.status Warning "Low stock"
                    , Badge.status Danger "Out of stock"
                    , Badge.status Neutral "Archived"
                    , Badge.status Primary "New"
                    ]
                ]
            )
        , Doc.example
            { title = "Tags"
            , description = Just "For example selected filters. The × removes the tag; the text and tooltip of the × come from Tag.locale. When a tag is removed with the keyboard, the focus moves to the next tag (Tag.removeId gives the × an id that the application can send the focus to)."
            , code = Just tagCode
            }
            (Layout.stack [ Layout.gap 3 ]
                [ Layout.row [ Layout.gap 2, Layout.wrap, Layout.alignCenter ]
                    (if List.isEmpty model.tags then
                        [ Button.view [ Button.link, Button.id tagsResetId, Button.onClick TagsReset ] "Show the tags again" ]

                     else
                        List.map (viewRemovableTag locale) model.tags
                    )
                , Layout.row [ Layout.gap 2, Layout.wrap, Layout.alignCenter ]
                    [ Tag.view [] "Draft"
                    , Tag.view [ Tag.tone Success, Tag.icon Icon.check ] "Approved"
                    , Tag.view [ Tag.tone Warning ] "In review"
                    , Tag.view [ Tag.tone Danger ] "Rejected"
                    , Tag.view [ Tag.outline ] "Outline"
                    , Tag.view [ Tag.size Small ] "Small"
                    , Tag.view [ Tag.size Large ] "Large"
                    ]
                ]
            )
        , Doc.example
            { title = "Long labels"
            , description = Just "A label that does not fit its container is cut with an ellipsis. Labels longer than 18 characters (24 for Badge.status) carry the whole text as a tooltip."
            , code = Just longLabelCode
            }
            (Layout.container [ Layout.maxWidth 200, Layout.alignStart ]
                [ Layout.stack [ Layout.gap 2, Layout.alignStart ]
                    [ Badge.view [ Badge.tone Info ] "Awaiting confirmation from the customer"
                    , Tag.view [ Tag.tone Primary ] "Gothenburg Port, north terminal annex"
                    , Badge.status Warning "Waiting for the supplier to confirm the date"
                    ]
                ]
            )
        ]


viewRemovableTag : Locale -> Types.Warehouse -> Html Msg
viewRemovableTag locale warehouse =
    Tag.view
        [ Tag.tone Primary
        , Tag.locale locale
        , Tag.removeId (tagRemoveId warehouse)
        , Tag.onRemove (TagRemoved warehouse.id)
        ]
        warehouse.name



-- ALERTS


viewAlerts : Locale -> Model -> Html Msg
viewAlerts locale model =
    Doc.section "Messages"
        "Alerts and messages in four main tones (info, success, warning and danger), plus neutral and primary. Errors and warnings are announced by screen readers at once."
        [ Doc.example
            { title = "Tones"
            , description = Just "Actions go below the message. An alert does not hide itself: onDismiss only sends your message, and your update function stops showing the alert."
            , code = Just alertCode
            }
            (Layout.stack [ Layout.gap 3 ]
                [ Alert.view [ Alert.tone Info, Alert.title "For your information" ] "Orders in status Draft get an automatic reminder after 14 days."
                , Alert.view [ Alert.tone Success ] "The changes were saved."
                , Alert.view [ Alert.tone Warning, Alert.title "Remember to save" ] "You have changes that are not saved. They will be lost if you leave the page."
                , Alert.viewWith
                    [ Alert.tone Danger
                    , Alert.title "Could not save"
                    , Alert.actions [ Button.view [ Button.small, Button.onClick AlertRetried ] "Try again" ]
                    ]
                    [ Text.text (failedSaveText model.alertRetries) ]
                , if model.alertDismissed then
                    Layout.row []
                        [ Button.view [ Button.link, Button.id alertRestoreId, Button.onClick RestoreAlert ] "Show the dismissible message again" ]

                  else
                    Alert.view [ Alert.tone Neutral, Alert.onDismiss DismissAlert, Alert.compact, Alert.locale locale ] "A compact message that can be dismissed."
                ]
            )
        , Doc.example
            { title = "Banner, icon and polite"
            , description = Just "A banner is flat, for the top of a page or a panel. Alert.icon replaces the icon of the tone. Alert.polite makes a warning or an error wait for a pause in the screen reader: use it for notices that appear by themselves, never for the result of an action."
            , code = Just alertExtrasCode
            }
            (Layout.stack [ Layout.gap 3 ]
                [ Alert.view [ Alert.banner, Alert.tone Warning, Alert.title "Scheduled maintenance" ] "The warehouse system is read-only on Sunday between 02:00 and 04:00."
                , Alert.view [ Alert.tone Success, Alert.icon Icon.send ] "Order ORD-10001 was sent to the warehouse."
                , Alert.view [ Alert.tone Danger, Alert.compact, Alert.polite ] "The stock levels could not be refreshed. The last known values are shown."
                ]
            )
        ]


failedSaveText : Int -> String
failedSaveText retries =
    if retries == 0 then
        "The server responded with an error (503). Your changes are not lost."

    else
        "The server still responds with an error (503) after "
            ++ String.fromInt retries
            ++ (if retries == 1 then
                    " retry."

                else
                    " retries."
               )
            ++ " Your changes are not lost."



-- LOADING


viewLoading : Html Msg
viewLoading =
    Doc.section "Loading"
        "Spinner for short waits, skeleton when the shape of the content is known. A skeleton is hidden from screen readers, so the area around it should say that content is on its way."
        [ Doc.example
            { title = "Spinner and skeleton"
            , description = Nothing
            , code = Just loadingCode
            }
            (Layout.grid [ Layout.minColumn 220, Layout.gap 6 ]
                [ Layout.row [ Layout.gap 3 ]
                    [ Spinner.view [ Spinner.size Small ]
                    , Spinner.view []
                    , Spinner.view [ Spinner.size Large, Spinner.label "Loading" ]
                    ]
                , Layout.stack [ Layout.gap 2 ] [ Skeleton.line 40, Skeleton.lines 3 ]
                , Layout.row [ Layout.gap 3 ]
                    [ Skeleton.circle 40
                    , Layout.stack [ Layout.gap 2, Layout.grow ] [ Skeleton.line 60, Skeleton.line 90 ]
                    ]
                , Layout.stack [ Layout.gap 2 ] [ Skeleton.block 64, Skeleton.paragraph 2 ]
                ]
            )
        , Doc.example
            { title = "Loading a panel"
            , description = Nothing
            , code = Just "Spinner.panel \"Loading orders ...\"\n"
            }
            (Spinner.panel "Loading orders ...")
        ]



-- EMPTY AND ERROR STATES


viewStates : Locale -> Model -> Html Msg
viewStates locale model =
    Doc.section "Empty and error states"
        "Every list and every table must be able to show three things in addition to data: that it is empty, that it is loading and that it failed. A failure can be retried when that may help."
        [ Doc.example
            { title = "Loading, failure and retry"
            , description = Just "Klar.Remote holds the four states of a request: not asked, loading, failed or here. The buttons send a pretend request. After “Network error once” the first attempt fails and Try again succeeds; “Server error” fails every time; “No orders” answers with an empty list."
            , code = Just remoteCode
            }
            (viewRemote locale model)
        , Doc.example
            { title = "Empty state"
            , description = Just "Say what is missing and what the user can do about it. Here the action really clears the search."
            , code = Just emptyCode
            }
            (viewProductSearch locale model)
        , Doc.example
            { title = "Compact empty state"
            , description = Just "Less space and a smaller icon, for tables and small panels."
            , code = Just compactEmptyCode
            }
            (Card.view []
                [ EmptyState.view
                    [ EmptyState.compact
                    , EmptyState.icon Icon.inbox
                    , EmptyState.title "No orders yet"
                    , EmptyState.description "Orders you create appear here."
                    , EmptyState.action (Button.view [ Button.primary, Button.href "#/orders" ] "Open orders")
                    ]
                ]
            )
        , Doc.example
            { title = "Error states"
            , description = Just ("Every Remote.Kind has its own icon and default text. Try again is shown only when it can help." ++ retryNote model.retried)
            , code = Just errorCode
            }
            (Layout.grid [ Layout.minColumn 280, Layout.gap 4 ]
                (List.map
                    (\kind ->
                        ErrorState.view [ ErrorState.compact, ErrorState.onRetry (KindRetried kind), ErrorState.locale locale ]
                            (Remote.problem kind |> Remote.withCode (kindCode kind))
                    )
                    allKinds
                )
            )
        ]


viewRemote : Locale -> Model -> Html Msg
viewRemote locale model =
    Layout.stack [ Layout.gap 4 ]
        [ Layout.row [ Layout.gap 2, Layout.wrap ]
            [ Button.view [ Button.icon Icon.refresh, Button.onClick (Requested Works) ] "Load orders"
            , Button.view [ Button.icon Icon.wifiOff, Button.onClick (Requested FailsOnce) ] "Network error once"
            , Button.view [ Button.icon Icon.server, Button.onClick (Requested FailsAlways) ] "Server error"
            , Button.view [ Button.icon Icon.inbox, Button.onClick (Requested NoOrders) ] "No orders"
            ]
        , Card.view [ Card.flush ]
            [ case model.orders of
                Remote.NotAsked ->
                    EmptyState.view [ EmptyState.compact, EmptyState.icon Icon.database, EmptyState.title "Nothing requested yet" ]

                Remote.Loading ->
                    Spinner.panel "Loading orders ..."

                Remote.Failure problem ->
                    ErrorState.view [ ErrorState.onRetry Retried, ErrorState.locale locale ] problem

                Remote.Success [] ->
                    EmptyState.view
                        [ EmptyState.icon Icon.inbox
                        , EmptyState.title "No orders to show"
                        , EmptyState.description "There are no orders yet."
                        , EmptyState.action (Button.view [ Button.onClick (Requested Works) ] "Load orders")
                        ]

                Remote.Success orders ->
                    Layout.stack [ Layout.gap 0 ]
                        (List.intersperse Layout.divider (List.map viewOrderRow orders))
            ]
        ]


viewOrderRow : Types.Order -> Html Msg
viewOrderRow order =
    Layout.row [ Layout.gap 3, Layout.padding 3 ]
        [ Text.mono order.id
        , Text.text order.customer
        , Layout.spacer
        , Labels.statusBadge order.status
        ]


viewProductSearch : Locale -> Model -> Html Msg
viewProductSearch locale model =
    let
        hits =
            Search.filter .name model.productSearch Sample.products
    in
    Layout.stack [ Layout.gap 4 ]
        [ TextInput.view
            [ TextInput.label "Search products"
            , TextInput.locale locale
            , TextInput.search
            , TextInput.clearable
            , TextInput.value model.productSearch
            , TextInput.onInput ProductSearchChanged
            , TextInput.placeholder "Search products ..."
            , TextInput.id productSearchId
            ]
        , Card.view [ Card.flush ]
            [ if List.isEmpty hits then
                EmptyState.view
                    [ EmptyState.icon Icon.search
                    , EmptyState.title "No matching products"
                    , EmptyState.description ("No product matches “" ++ model.productSearch ++ "”. Try another search, or clear it.")
                    , EmptyState.action (Button.view [ Button.onClick ProductSearchCleared ] "Clear search")
                    ]

              else
                Layout.stack [ Layout.gap 0 ]
                    (List.intersperse Layout.divider (List.map viewProductRow (List.take 5 hits)))
            ]
        , Text.muted ("Showing " ++ String.fromInt (min 5 (List.length hits)) ++ " of " ++ Format.int locale (List.length hits) ++ " products")
        ]


viewProductRow : Types.Product -> Html Msg
viewProductRow product =
    Layout.row [ Layout.gap 3, Layout.padding 3 ]
        [ Text.mono product.sku
        , Text.text product.name
        , Layout.spacer
        , Text.muted (String.join " / " product.category)
        ]


allKinds : List Remote.Kind
allKinds =
    [ Remote.network
    , Remote.timeout
    , Remote.server
    , Remote.notFound
    , Remote.forbidden
    , Remote.unauthorized
    , Remote.validation
    , Remote.conflict
    , Remote.unknown
    ]


kindInfo : List ( Remote.Kind, { name : String, code : String } )
kindInfo =
    [ ( Remote.network, { name = "Network", code = "ERR_NETWORK" } )
    , ( Remote.timeout, { name = "Timeout", code = "ETIMEDOUT" } )
    , ( Remote.server, { name = "Server", code = "HTTP 503" } )
    , ( Remote.notFound, { name = "NotFound", code = "HTTP 404" } )
    , ( Remote.forbidden, { name = "Forbidden", code = "HTTP 403" } )
    , ( Remote.unauthorized, { name = "Unauthorized", code = "HTTP 401" } )
    , ( Remote.validation, { name = "Validation", code = "HTTP 422" } )
    , ( Remote.conflict, { name = "Conflict", code = "HTTP 409" } )
    , ( Remote.unknown, { name = "Unknown", code = "ERR_UNKNOWN" } )
    ]


kindName : Remote.Kind -> String
kindName kind =
    kindInfo
        |> List.filter (\( k, _ ) -> k == kind)
        |> List.head
        |> Maybe.map (Tuple.second >> .name)
        |> Maybe.withDefault "Unknown"


kindCode : Remote.Kind -> String
kindCode kind =
    kindInfo
        |> List.filter (\( k, _ ) -> k == kind)
        |> List.head
        |> Maybe.map (Tuple.second >> .code)
        |> Maybe.withDefault "ERR_UNKNOWN"


retryNote : Maybe Remote.Kind -> String
retryNote retried =
    case retried of
        Just kind ->
            " You pressed Try again on: " ++ kindName kind ++ "."

        Nothing ->
            ""



-- TEXT FIELDS AND CHECKBOXES


viewInputs : Locale -> Model -> Html Msg
viewInputs locale model =
    let
        allChecked =
            List.all identity model.options

        someChecked =
            List.any identity model.options
    in
    Doc.section "Text fields and checkboxes"
        "The fields are owned by the application (controlled input). The label, the hint and the error message are connected to the field for screen readers."
        [ Doc.example
            { title = "Text fields"
            , description = Just "The email field is checked by a validator on every keystroke: edit the address to make the error go away."
            , code = Just textInputCode
            }
            (Layout.grid [ Layout.minColumn 260, Layout.gap 4 ]
                [ TextInput.view
                    [ TextInput.label "Owner"
                    , TextInput.required
                    , TextInput.hint "First and last name"
                    , TextInput.value model.owner
                    , TextInput.onInput OwnerChanged
                    , TextInput.placeholder "Maya Patel"
                    , TextInput.id "basics-owner"
                    ]
                , TextInput.view
                    [ TextInput.label "Customer email"
                    , TextInput.email
                    , TextInput.prefixIcon Icon.mail
                    , TextInput.value model.email
                    , TextInput.onInput EmailChanged
                    , TextInput.errorMaybe (Validate.run locale Validate.email model.email)
                    , TextInput.id "basics-email"
                    ]
                , TextInput.view
                    [ TextInput.label "Search"
                    , TextInput.locale locale
                    , TextInput.search
                    , TextInput.clearable
                    , TextInput.value model.search
                    , TextInput.onInput SearchChanged
                    , TextInput.placeholder "Search orders ..."
                    , TextInput.id "basics-search"
                    ]
                , TextInput.view
                    [ TextInput.label "Amount"
                    , TextInput.suffixText "EUR"
                    , TextInput.value model.amount
                    , TextInput.onInput AmountChanged
                    , TextInput.optionalText "(optional)"
                    , TextInput.id "basics-amount"
                    ]
                , TextInput.view
                    [ TextInput.label "Comment"
                    , TextInput.maxLength 60
                    , TextInput.value model.comment
                    , TextInput.onInput CommentChanged
                    , TextInput.id "basics-comment"
                    ]
                , TextInput.view
                    [ TextInput.label "Order number"
                    , TextInput.readOnly True
                    , TextInput.value "ORD-10001"
                    , TextInput.id "basics-readonly"
                    ]
                , TextInput.view
                    [ TextInput.label "Disabled"
                    , TextInput.disabled True
                    , TextInput.value "Cannot be changed"
                    , TextInput.id "basics-disabled"
                    ]
                ]
            )
        , Doc.example
            { title = "Sizes"
            , description = Just "Small (26 px), medium (32 px) and large (40 px), the same heights as the buttons. The three fields share one value."
            , code = Just sizedCode
            }
            (Layout.grid [ Layout.minColumn 220, Layout.gap 4 ]
                (List.map
                    (\( name, fieldSize ) ->
                        TextInput.view
                            [ TextInput.label name
                            , TextInput.size fieldSize
                            , TextInput.prefixIcon Icon.mapPin
                            , TextInput.value model.sized
                            , TextInput.onInput SizedChanged
                            , TextInput.placeholder "City"
                            , TextInput.id ("basics-size-" ++ String.toLower name)
                            ]
                    )
                    [ ( "Small", Small ), ( "Medium", Medium ), ( "Large", Large ) ]
                )
            )
        , Doc.example
            { title = "Checkboxes"
            , description = Just "A tri-state “Select all” with indeterminate: a click on an indeterminate box selects everything."
            , code = Just checkboxCode
            }
            (Layout.stack [ Layout.gap 3, Layout.alignStart ]
                [ Checkbox.view
                    [ Checkbox.label "Send email notifications"
                    , Checkbox.hint "You get an email when an order changes status."
                    , Checkbox.checked model.notify
                    , Checkbox.onCheck NotifyChanged
                    ]
                , Checkbox.view
                    ([ Checkbox.label "I accept the terms of delivery"
                     , Checkbox.checked model.terms
                     , Checkbox.onCheck TermsChanged
                     ]
                        ++ (if model.terms then
                                []

                            else
                                [ Checkbox.error "You must accept the terms" ]
                           )
                    )
                , Checkbox.view [ Checkbox.label "Disabled", Checkbox.disabled True ]
                , Checkbox.view [ Checkbox.label "Disabled and checked", Checkbox.checked True, Checkbox.disabled True ]
                , Layout.divider
                , Checkbox.view
                    [ Checkbox.label "Select all warehouses"
                    , Checkbox.checked allChecked
                    , Checkbox.indeterminate (someChecked && not allChecked)
                    , Checkbox.onCheck AllOptionsChanged
                    ]
                , Layout.stack [ Layout.gap 2, Layout.alignStart ]
                    (List.indexedMap
                        (\index ( warehouse, checked ) ->
                            Checkbox.view
                                [ Checkbox.label warehouse.name
                                , Checkbox.checked checked
                                , Checkbox.onCheck (OptionChanged index)
                                ]
                        )
                        (List.map2 Tuple.pair optionWarehouses model.options)
                    )
                ]
            )
        ]



-- CODE SNIPPETS


looksCode : String
looksCode =
    """Button.view [ Button.primary, Button.onClick Save ] "Save"
Button.view [ Button.onClick Cancel ] "Cancel"
Button.view [ Button.ghost ] "More"
Button.view [ Button.danger ] "Delete"
Button.view [ Button.link ] "Read more"
Button.view [ Button.disabled True ] "Disabled"
Button.view [ Button.ariaDisabled True ] "Unavailable"
"""


dangerCode : String
dangerCode =
    """Button.view [ Button.danger ] "Delete"                    -- solid red
Button.view [ Button.secondary, Button.danger ] "Delete"  -- white, red text and border
Button.view [ Button.ghost, Button.danger ] "Delete"      -- quiet, red text
Button.view [ Button.link, Button.danger ] "Delete"       -- link, red text
Button.iconOnly [ Button.ghost, Button.danger ] Icon.trash "Delete"
"""


sizesCode : String
sizesCode =
    """Button.view [ Button.small, Button.icon Icon.plus ] "Small"
Button.view [ Button.primary, Button.icon Icon.plus ] "New order"
Button.view [ Button.large, Button.icon Icon.download ] "Large"
Button.view [ Button.iconRight Icon.arrowRight ] "Next"
Button.iconOnly [ Button.ghost ] Icon.refresh "Reload"
Button.iconOnly [ Button.primary ] Icon.search "Search"
"""


loadingButtonCode : String
loadingButtonCode =
    """-- view
Button.view [ Button.primary, Button.loading model.saving, Button.onClick Save ] "Save"

-- update: a pretend request
Save ->
    ( { model | saving = True }
    , Process.sleep 1500 |> Task.perform (\\_ -> Saved)
    )

Saved ->
    ( { model | saving = False }, Cmd.none )
"""


groupCode : String
groupCode =
    """-- model:   mode : ViewMode   (AsList | AsGrid | AsColumns)

viewModeButton model mode icon label =
    Button.view
        [ Button.icon icon
        , Button.pressed (model.mode == mode)
        , Button.onClick (ModeChosen mode)
        , if model.mode == mode then
            Button.primary

          else
            Button.secondary
        ]
        label

Button.group
    [ viewModeButton model AsList Icon.list "List"
    , viewModeButton model AsGrid Icon.grid "Grid"
    , viewModeButton model AsColumns Icon.columns "Columns"
    ]
"""


linksCode : String
linksCode =
    """Button.view [ Button.href "#/orders", Button.iconRight Icon.arrowRight ] "Go to orders"
Button.view [ Button.href "#/orders", Button.newTab, Button.iconRight Icon.externalLink ] "Orders in a new tab"
Button.view [ Button.primary, Button.block ] "Place order"
"""


menuCode : String
menuCode =
    """-- model:   actions : Menu.State   (Menu.init "order-actions")

-- update
MenuMsg inner ->
    let
        ( menu, cmd ) =
            Menu.update inner model.actions
    in
    ( { model | actions = menu }, Cmd.map MenuMsg cmd )

-- view
Menu.view MenuMsg
    [ Menu.label "Actions"
    , Menu.items
        [ Menu.heading "Order"
        , Menu.item "Edit" EditOrder |> Menu.withIcon Icon.edit |> Menu.withHint "E"
        , Menu.item "Duplicate" DuplicateOrder |> Menu.withIcon Icon.copy
        , Menu.item "Export" ExportOrder |> Menu.withIcon Icon.download |> Menu.disabledItem
        , Menu.separator
        , Menu.item "Delete" DeleteOrder |> Menu.withIcon Icon.trash |> Menu.danger
        ]
    ]
    model.actions

-- style the button that opens the menu (every menu has a State and a message of its own)
Menu.view CreateMenuMsg
    [ Menu.label "New"
    , Menu.trigger [ Button.primary, Button.icon Icon.plus ]
    , Menu.items [ Menu.item "Order" NewOrder ]
    ]
    model.create

-- an icon-only "more" button, aligned to the right edge of the menu
Menu.view MoreMenuMsg
    [ Menu.kebab "More actions"
    , Menu.alignEnd
    , Menu.items [ Menu.item "Archive" ArchiveOrder |> Menu.withIcon Icon.archive ]
    ]
    model.more
"""


longMenuCode : String
longMenuCode =
    """-- wired like the menu above: customerMenu : Menu.State, and a CustomerMenuMsg
Menu.view CustomerMenuMsg
    [ Menu.label "Open customer"
    , Menu.items
        (List.map
            (\\customer -> Menu.item customer (OpenCustomer customer) |> Menu.withIcon Icon.building)
            customers
        )
    ]
    model.customerMenu
"""


rowMenuCode : String
rowMenuCode =
    """-- model:   rowMenus : Dict OrderId Menu.State   (one menu per row, each with an id of its own)

menuOf : OrderId -> Model -> Menu.State
menuOf id model =
    Dict.get id model.rowMenus |> Maybe.withDefault (Menu.init ("row-" ++ id))

-- update
RowMenuMsg id inner ->
    let
        ( menu, cmd ) =
            Menu.update inner (menuOf id model)
    in
    ( { model | rowMenus = Dict.insert id menu model.rowMenus }
    , Cmd.map (RowMenuMsg id) cmd
    )

-- view: the list scrolls, the menus are not clipped by it
Layout.stack [ Layout.maxHeight 168 ] (List.map (viewRow model) orders)

viewRow model order =
    Layout.row [ Layout.gap 3 ]
        [ Text.mono order.id
        , Layout.spacer
        , Menu.view (RowMenuMsg order.id)
            [ Menu.kebab ("Actions for " ++ order.id)
            , Menu.alignEnd
            , Menu.items
                [ Menu.item "Open" (OpenOrder order.id)
                , Menu.item "Cancel order" (CancelOrder order.id)
                    |> Menu.danger
                    |> (if canCancel order then identity else Menu.disabledItem)
                ]
            ]
            (menuOf order.id model)
        ]
"""


badgeCode : String
badgeCode =
    """Badge.view [] "Draft"
Badge.view [ Badge.tone Success ] "Delivered"
Badge.view [ Badge.tone Info, Badge.dot ] "With dot"
Badge.view [ Badge.tone Success, Badge.icon Icon.check ] "With icon"
Badge.view [ Badge.tone Primary, Badge.solid ] "Solid"
Badge.view [ Badge.tone Warning, Badge.outline ] "Outline"
Badge.view [ Badge.size Large ] "Large"
Badge.status Danger "Out of stock"
Badge.count 128 -- shows 99+
"""


tagCode : String
tagCode =
    """Tag.view [ Tag.tone Primary, Tag.removeId "tag-rtm", Tag.onRemove (WarehouseRemoved "RTM") ] "Rotterdam Hub"
Tag.view [ Tag.tone Success, Tag.icon Icon.check ] "Approved"
Tag.view [ Tag.outline ] "Outline"

-- update: the removed tag took the focus with it, so give it to the next tag
WarehouseRemoved id ->
    ( { model | warehouses = List.filter (\\w -> w.id /= id) model.warehouses }
    , Task.attempt (\\_ -> NoOp) (Browser.Dom.focus "tag-ham")
    )
"""


longLabelCode : String
longLabelCode =
    """Layout.container [ Layout.maxWidth 200, Layout.alignStart ]
    [ Badge.view [ Badge.tone Info ] "Awaiting confirmation from the customer"
    , Tag.view [ Tag.tone Primary ] "Gothenburg Port, north terminal annex"
    , Badge.status Warning "Waiting for the supplier to confirm the date"
    ]
"""


alertCode : String
alertCode =
    """Alert.view [ Alert.tone Warning, Alert.title "Remember to save" ] "You have changes that are not saved."

Alert.viewWith
    [ Alert.tone Danger
    , Alert.title "Could not save"
    , Alert.actions [ Button.view [ Button.small, Button.onClick Retry ] "Try again" ]
    ]
    [ Text.text "The server responded with an error (503)." ]

-- the alert does not hide itself: stop showing it when your message arrives
Alert.view [ Alert.onDismiss Dismissed, Alert.compact ] "A message that can be dismissed."
"""


alertExtrasCode : String
alertExtrasCode =
    """Alert.view [ Alert.banner, Alert.tone Warning, Alert.title "Scheduled maintenance" ] "The warehouse system is read-only on Sunday."
Alert.view [ Alert.tone Success, Alert.icon Icon.send ] "Order ORD-10001 was sent to the warehouse."
Alert.view [ Alert.tone Danger, Alert.compact, Alert.polite ] "The stock levels could not be refreshed."
"""


loadingCode : String
loadingCode =
    """Spinner.view [ Spinner.size Small ]
Spinner.view [ Spinner.size Large, Spinner.label "Loading" ]
Skeleton.line 40
Skeleton.lines 3
Skeleton.circle 40
Skeleton.block 64
"""


remoteCode : String
remoteCode =
    """-- model:   orders : Remote (List Order)

case model.orders of
    Remote.NotAsked ->
        Text.muted "Nothing requested yet"

    Remote.Loading ->
        Spinner.panel "Loading orders ..."

    Remote.Failure problem ->
        ErrorState.view [ ErrorState.onRetry Retry ] problem

    Remote.Success [] ->
        EmptyState.view [ EmptyState.title "No orders to show" ]

    Remote.Success orders ->
        viewOrders orders

-- update: a ticket makes the answer to an old request count for nothing
Retry ->
    ( { model | orders = Remote.Loading, ticket = model.ticket + 1 }
    , fetchOrders (model.ticket + 1)
    )

Fetched ticket result ->
    if ticket == model.ticket then
        ( { model | orders = Remote.fromResult result }, Cmd.none )

    else
        ( model, Cmd.none )
"""


emptyCode : String
emptyCode =
    """EmptyState.view
    [ EmptyState.icon Icon.search
    , EmptyState.title "No matching products"
    , EmptyState.description "Try another search, or clear it."
    , EmptyState.action (Button.view [ Button.onClick ClearSearch ] "Clear search")
    ]
"""


compactEmptyCode : String
compactEmptyCode =
    """EmptyState.view
    [ EmptyState.compact
    , EmptyState.title "No orders yet"
    , EmptyState.description "Orders you create appear here."
    , EmptyState.action (Button.view [ Button.primary, Button.href "#/orders" ] "Open orders")
    ]
"""


errorCode : String
errorCode =
    """ErrorState.view [ ErrorState.onRetry Reload ] (Remote.problem Remote.network)

-- inside a table or a small panel, with a technical code
ErrorState.view
    [ ErrorState.compact, ErrorState.onRetry Reload ]
    (Remote.problem Remote.server |> Remote.withCode "HTTP 503")
"""


textInputCode : String
textInputCode =
    """TextInput.view
    [ TextInput.label "Owner"
    , TextInput.required
    , TextInput.hint "First and last name"
    , TextInput.value model.owner
    , TextInput.onInput OwnerChanged
    ]

-- Nothing means no error
TextInput.view
    [ TextInput.label "Customer email"
    , TextInput.email
    , TextInput.prefixIcon Icon.mail
    , TextInput.value model.email
    , TextInput.onInput EmailChanged
    , TextInput.errorMaybe (Validate.run Locale.default Validate.email model.email)
    ]

TextInput.view [ TextInput.label "Search", TextInput.search, TextInput.clearable, TextInput.value model.search, TextInput.onInput SearchChanged ]
TextInput.view [ TextInput.label "Amount", TextInput.suffixText "EUR", TextInput.optionalText "(optional)", TextInput.value model.amount, TextInput.onInput AmountChanged ]
TextInput.view [ TextInput.label "Comment", TextInput.maxLength 60, TextInput.value model.comment, TextInput.onInput CommentChanged ]
TextInput.view [ TextInput.label "Order number", TextInput.readOnly True, TextInput.value "ORD-10001" ]
TextInput.view [ TextInput.label "Disabled", TextInput.disabled True, TextInput.value "Cannot be changed" ]
"""


sizedCode : String
sizedCode =
    """TextInput.view
    [ TextInput.label "Small"
    , TextInput.size Small
    , TextInput.prefixIcon Icon.mapPin
    , TextInput.value model.city
    , TextInput.onInput CityChanged
    ]

TextInput.view [ TextInput.label "Medium", TextInput.value model.city, TextInput.onInput CityChanged ]
TextInput.view [ TextInput.label "Large", TextInput.size Large, TextInput.value model.city, TextInput.onInput CityChanged ]
"""


checkboxCode : String
checkboxCode =
    """Checkbox.view
    [ Checkbox.label "Send email notifications"
    , Checkbox.hint "You get an email when an order changes status."
    , Checkbox.checked model.notify
    , Checkbox.onCheck NotifyChanged
    ]

-- the error is only added while there is a problem
Checkbox.view
    ([ Checkbox.label "I accept the terms of delivery"
     , Checkbox.checked model.terms
     , Checkbox.onCheck TermsChanged
     ]
        ++ (if model.terms then [] else [ Checkbox.error "You must accept the terms" ])
    )

Checkbox.view [ Checkbox.label "Disabled", Checkbox.disabled True ]

Checkbox.view
    [ Checkbox.label "Select all warehouses"
    , Checkbox.checked allChecked
    , Checkbox.indeterminate (someChecked && not allChecked)
    , Checkbox.onCheck AllChanged
    ]
"""
