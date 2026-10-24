module Page.Gallery.Actions.Groups exposing
    ( Model
    , Msg
    , buttonGroupSection
    , init
    , toggleGroupSection
    , update
    )

{-| The button group and the toggle group of the gallery page "Actions and links".
The toggle groups are bound to real state, and the status filter counts the
orders of the sample data.
-}

import Api.Types as Types exposing (OrderStatus)
import Html exposing (Html)
import Klar.Button as Button
import Klar.ButtonGroup as ButtonGroup
import Klar.Icon as Icon
import Klar.Layout as Layout
import Klar.Link as Link
import Klar.Locale exposing (Locale)
import Klar.Menu as Menu
import Klar.Text as Text
import Klar.Theme exposing (Size(..))
import Klar.ToggleGroup as ToggleGroup
import Klar.Toolbar as Toolbar
import Showcase.Doc as Doc
import Showcase.Sample as Sample



-- MODEL


type alias Model =
    { last : Maybe String
    , menu : Menu.State
    , disabled : Bool
    , styles : List Style
    , status : Maybe OrderStatus
    , statuses : List OrderStatus
    , days : List Weekday
    , toolbarStyles : List Style
    }


type Style
    = Bold
    | Italic
    | Underline


type Weekday
    = Mon
    | Tue
    | Wed
    | Thu
    | Fri
    | Sat
    | Sun


init : Model
init =
    { last = Nothing
    , menu = Menu.init "actions-group-menu"
    , disabled = False
    , styles = [ Bold ]
    , status = Just Types.Shipped
    , statuses = [ Types.Confirmed, Types.Picking ]
    , days = [ Mon, Wed, Fri ]
    , toolbarStyles = []
    }


type Msg
    = Did String
    | MenuMsg Menu.Msg
    | DisabledChanged Bool
    | StylesChanged (List Style)
    | StatusChanged (Maybe OrderStatus)
    | StatusesChanged (List OrderStatus)
    | DaysChanged (List Weekday)
    | ToolbarStylesChanged (List Style)


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        Did what ->
            ( { model | last = Just what }, Cmd.none )

        MenuMsg inner ->
            Menu.update inner model.menu
                |> Tuple.mapBoth (\menu -> { model | menu = menu }) (Cmd.map MenuMsg)

        DisabledChanged value ->
            ( { model | disabled = value }, Cmd.none )

        StylesChanged styles ->
            ( { model | styles = styles }, Cmd.none )

        StatusChanged status ->
            ( { model | status = status }, Cmd.none )

        StatusesChanged statuses ->
            ( { model | statuses = statuses }, Cmd.none )

        DaysChanged days ->
            ( { model | days = days }, Cmd.none )

        ToolbarStylesChanged styles ->
            ( { model | toolbarStyles = styles }, Cmd.none )



-- BUTTON GROUP


buttonGroupSection : Locale -> Model -> Html Msg
buttonGroupSection _ model =
    Doc.section "Button group"
        "Buttons that belong together, joined into one block with shared borders and only the outer corners rounded. The children are ordinary Button.view buttons, so nothing about them changes; the group adds the shape and a name for screen readers. It never wraps."
        [ Doc.example
            { title = "Joined actions"
            , description = Just (lastText model.last)
            , code = Just groupCode
            }
            (Layout.row [ Layout.gap 4, Layout.alignCenter, Layout.wrap ]
                [ ButtonGroup.view [] "Order actions" (orderActions model)
                , ButtonGroup.view [ ButtonGroup.disabled True ] "Order actions (not available)" (List.take 2 (orderActions model) ++ [ Button.view [ Button.href (Link.internal "#links/open") ] "Open" ])
                ]
            )
        , Doc.example
            { title = "Sizes"
            , description = Just "The size is for the buttons that have none of their own: the group sets it for them, and a button made with Button.small or Button.large keeps the size it has."
            , code = Just groupSizesCode
            }
            (Layout.row [ Layout.gap 4, Layout.alignCenter, Layout.wrap ]
                [ ButtonGroup.view [ ButtonGroup.size Small ] "Pages (small)" (pager "Small")
                , ButtonGroup.view [] "Pages (medium)" (pager "Medium")
                , ButtonGroup.view [ ButtonGroup.size Large ] "Pages (large)" (pager "Large")
                ]
            )
        , Doc.example
            { title = "Solid buttons and a menu"
            , description = Just "Two solid buttons keep a pale line between them. The button of a Klar.Menu can be the last one in the group: the menu opens below it."
            , code = Nothing
            }
            (Layout.row [ Layout.gap 4, Layout.alignCenter, Layout.wrap ]
                [ ButtonGroup.view []
                    "Decision"
                    [ Button.view [ Button.primary, Button.onClick (Did "Approve") ] "Approve"
                    , Button.view [ Button.danger, Button.onClick (Did "Reject") ] "Reject"
                    ]
                , ButtonGroup.view []
                    "Export"
                    [ Button.view [ Button.icon Icon.download, Button.onClick (Did "Export CSV") ] "Export"
                    , Menu.view MenuMsg
                        [ Menu.kebab "More export formats"
                        , Menu.alignEnd
                        , Menu.trigger [ Button.secondary ]
                        , Menu.items
                            [ Menu.item "Export as Excel" (Did "Export Excel")
                            , Menu.item "Export as PDF" (Did "Export PDF")
                            ]
                        ]
                        model.menu
                    ]
                ]
            )
        , Doc.example
            { title = "Inside a toolbar"
            , description = Just "A toolbar sets the size of everything in it, groups included. Next to it a toggle group with a hidden label."
            , code = Just toolbarCode
            }
            (Toolbar.view [ Toolbar.ariaLabel "Description editor", Toolbar.small ]
                [ ButtonGroup.view []
                    "History"
                    [ Button.iconOnly [ Button.onClick (Did "Undo") ] Icon.undo "Undo"
                    , Button.iconOnly [ Button.onClick (Did "Redo") ] Icon.redo "Redo"
                    ]
                , Toolbar.separator
                , ToggleGroup.multiple [ ToggleGroup.labelHidden, ToggleGroup.id "actions-toolbar-styles" ]
                    { label = "Text style", selected = model.toolbarStyles, onChange = ToolbarStylesChanged }
                    styleOptions
                ]
            )
        ]


orderActions : Model -> List (Html Msg)
orderActions _ =
    [ Button.view [ Button.icon Icon.edit, Button.onClick (Did "Edit") ] "Edit"
    , Button.view [ Button.icon Icon.copy, Button.onClick (Did "Duplicate") ] "Duplicate"
    , Button.iconOnly [ Button.onClick (Did "Print") ] Icon.print "Print"
    ]


pager : String -> List (Html Msg)
pager size =
    [ Button.iconOnly [ Button.onClick (Did ("Previous (" ++ size ++ ")")) ] Icon.chevronLeft "Previous"
    , Button.view [ Button.onClick (Did ("Page 2 (" ++ size ++ ")")) ] "Page 2"
    , Button.iconOnly [ Button.onClick (Did ("Next (" ++ size ++ ")")) ] Icon.chevronRight "Next"
    ]


lastText : Maybe String -> String
lastText last =
    case last of
        Just what ->
            "Last action: " ++ what

        Nothing ->
            "No action yet. Tab moves between the buttons; Enter or Space presses one."



-- TOGGLE GROUP


styleOptions : List (ToggleGroup.Option Style)
styleOptions =
    [ ToggleGroup.iconOption Bold Icon.bold "Bold"
    , ToggleGroup.iconOption Italic Icon.italic "Italic"
    , ToggleGroup.iconOption Underline Icon.underline "Underline"
    ]


weekdayOptions : List (ToggleGroup.Option Weekday)
weekdayOptions =
    [ ToggleGroup.option Mon "Mon"
    , ToggleGroup.option Tue "Tue"
    , ToggleGroup.option Wed "Wed"
    , ToggleGroup.option Thu "Thu"
    , ToggleGroup.option Fri "Fri"
    , ToggleGroup.option Sat "Sat"
    , ToggleGroup.option Sun "Sun"
    ]


styleName : Style -> String
styleName style =
    case style of
        Bold ->
            "bold"

        Italic ->
            "italic"

        Underline ->
            "underline"


weekdayName : Weekday -> String
weekdayName day =
    case day of
        Mon ->
            "Monday"

        Tue ->
            "Tuesday"

        Wed ->
            "Wednesday"

        Thu ->
            "Thursday"

        Fri ->
            "Friday"

        Sat ->
            "Saturday"

        Sun ->
            "Sunday"


listOf : (a -> String) -> List a -> String
listOf name items =
    case items of
        [] ->
            "nothing"

        _ ->
            String.join ", " (List.map name items)


ordersWith : (OrderStatus -> Bool) -> Int
ordersWith wanted =
    Sample.orders
        |> List.filter (\order -> wanted order.status)
        |> List.length


toggleGroupSection : Locale -> Model -> Html Msg
toggleGroupSection _ model =
    let
        shown =
            case model.status of
                Just status ->
                    String.fromInt (ordersWith (\s -> s == status)) ++ " " ++ String.toLower (Types.orderStatusLabel status) ++ " orders"

                Nothing ->
                    "all " ++ String.fromInt (List.length Sample.orders) ++ " orders"

        shownMany =
            String.fromInt (ordersWith (\s -> List.member s model.statuses)) ++ " of " ++ String.fromInt (List.length Sample.orders) ++ " orders"
    in
    Doc.section "Toggle group"
        "A row of toggle buttons for choices that can be on or off. A group is either multiple (any number on) or single (none or one on; clicking the one that is on turns it off). Exactly one of a few views is a Klar.SegmentedControl. The ids are your own types, the label is required, and the message carries the whole new selection."
        [ Doc.example
            { title = "Many at once"
            , description = Just ("Selected: " ++ listOf styleName model.styles ++ ". Each button is a toggle button (aria-pressed). Tab moves between them, Space or Enter toggles. The icons need a text, which is the accessible name and the tooltip.")
            , code = Just multipleCode
            }
            (ToggleGroup.multiple []
                { label = "Text style", selected = model.styles, onChange = StylesChanged }
                styleOptions
            )
        , Doc.example
            { title = "None or one: a filter"
            , description = Just ("Showing " ++ shown ++ ". Click the shipped button again to show every order.")
            , code = Just singleCode
            }
            (ToggleGroup.single []
                { label = "Order status", selected = model.status, onChange = StatusChanged }
                (List.map (\status -> ToggleGroup.option status (Types.orderStatusLabel status)) Types.allOrderStatuses)
            )
        , Doc.example
            { title = "Several of many, with an icon and a disabled option"
            , description = Just ("Showing " ++ shownMany ++ ". A disabled option cannot be changed; if it is on it stays on.")
            , code = Just statusesCode
            }
            (ToggleGroup.multiple [ ToggleGroup.size Small ]
                { label = "Statuses to include", selected = model.statuses, onChange = StatusesChanged }
                (List.map statusOption Types.allOrderStatuses)
            )
        , Doc.example
            { title = "Days of the week: full width, hint and error"
            , description = Just ("Selected: " ++ listOf weekdayName model.days ++ ". With no day selected the group shows an error, joined to it for screen readers. The list is always in the order of the buttons, whatever the order of the clicks.")
            , code = Just daysCode
            }
            (Layout.container [ Layout.maxWidth 520, Layout.alignStart ]
                [ ToggleGroup.multiple
                    [ ToggleGroup.fullWidth
                    , ToggleGroup.hint "The days a shipment can leave the warehouse."
                    , ToggleGroup.errorMaybe
                        (if List.isEmpty model.days then
                            Just "Pick at least one day."

                         else
                            Nothing
                        )
                    ]
                    { label = "Shipping days", selected = model.days, onChange = DaysChanged }
                    weekdayOptions
                ]
            )
        , Doc.example
            { title = "Sizes and disabled"
            , description = Just "The size follows Button. The whole group can be disabled; the selection stays."
            , code = Nothing
            }
            (Layout.stack [ Layout.gap 3, Layout.alignStart ]
                [ ToggleGroup.multiple [ ToggleGroup.size Large, ToggleGroup.labelHidden ]
                    { label = "Large", selected = model.styles, onChange = StylesChanged }
                    styleOptions
                , ToggleGroup.multiple [ ToggleGroup.disabled model.disabled, ToggleGroup.labelHidden ]
                    { label = "Disabled when asked", selected = model.styles, onChange = StylesChanged }
                    styleOptions
                , Button.view [ Button.small, Button.pressed model.disabled, Button.onClick (DisabledChanged (not model.disabled)) ] "Disable the second group"
                , Text.caption "Both groups show the same selection."
                ]
            )
        ]


statusOption : OrderStatus -> ToggleGroup.Option OrderStatus
statusOption status =
    let
        base =
            ToggleGroup.option status (Types.orderStatusLabel status)
    in
    case status of
        Types.Delivered ->
            base |> ToggleGroup.withIcon Icon.checkCircle |> ToggleGroup.disabledOption

        Types.Cancelled ->
            base |> ToggleGroup.withIcon Icon.xCircle

        _ ->
            base



-- CODE


groupCode : String
groupCode =
    """ButtonGroup.view [] "Order actions"
    [ Button.view [ Button.icon Icon.edit, Button.onClick Edit ] "Edit"
    , Button.view [ Button.icon Icon.copy, Button.onClick Duplicate ] "Duplicate"
    , Button.iconOnly [ Button.onClick Print ] Icon.print "Print"
    ]

-- every button and link turned off at once (a fieldset that is disabled and inert)
ButtonGroup.view [ ButtonGroup.disabled True ] "Order actions" [ ... ]
"""


groupSizesCode : String
groupSizesCode =
    """ButtonGroup.view [ ButtonGroup.size Small ] "Pages"
    [ Button.iconOnly [ Button.onClick Previous ] Icon.chevronLeft "Previous"
    , Button.view [ Button.onClick (GoTo 2) ] "Page 2"
    , Button.iconOnly [ Button.onClick Next ] Icon.chevronRight "Next"
    ]
"""


toolbarCode : String
toolbarCode =
    """Toolbar.view [ Toolbar.ariaLabel "Description editor", Toolbar.small ]
    [ ButtonGroup.view [] "History"
        [ Button.iconOnly [ Button.onClick Undo ] Icon.undo "Undo"
        , Button.iconOnly [ Button.onClick Redo ] Icon.redo "Redo"
        ]
    , Toolbar.separator
    , ToggleGroup.multiple [ ToggleGroup.labelHidden, ToggleGroup.id "editor-styles" ]
        { label = "Text style", selected = model.styles, onChange = StylesChanged }
        [ ToggleGroup.iconOption Bold Icon.bold "Bold"
        , ToggleGroup.iconOption Italic Icon.italic "Italic"
        , ToggleGroup.iconOption Underline Icon.underline "Underline"
        ]
    ]
"""


multipleCode : String
multipleCode =
    """-- model:   styles : List Style     (type Style = Bold | Italic | Underline)

ToggleGroup.multiple []
    { label = "Text style"
    , selected = model.styles
    , onChange = StylesChanged
    }
    [ ToggleGroup.iconOption Bold Icon.bold "Bold"
    , ToggleGroup.iconOption Italic Icon.italic "Italic"
    , ToggleGroup.iconOption Underline Icon.underline "Underline"
    ]

-- update: the message already holds the new selection
StylesChanged styles ->
    ( { model | styles = styles }, Cmd.none )
"""


singleCode : String
singleCode =
    """-- model:   status : Maybe OrderStatus     (Nothing: every order)

ToggleGroup.single []
    { label = "Order status"
    , selected = model.status
    , onChange = StatusChanged        -- Maybe OrderStatus -> Msg
    }
    (List.map (\\status -> ToggleGroup.option status (orderStatusLabel status)) allOrderStatuses)
"""


statusesCode : String
statusesCode =
    """ToggleGroup.multiple [ ToggleGroup.size Small ]
    { label = "Statuses to include", selected = model.statuses, onChange = StatusesChanged }
    [ ToggleGroup.option Confirmed "Confirmed"
    , ToggleGroup.option Delivered "Delivered"
        |> ToggleGroup.withIcon Icon.checkCircle
        |> ToggleGroup.disabledOption
    , ToggleGroup.option Cancelled "Cancelled" |> ToggleGroup.withIcon Icon.xCircle
    ]
"""


daysCode : String
daysCode =
    """ToggleGroup.multiple
    [ ToggleGroup.fullWidth
    , ToggleGroup.hint "The days a shipment can leave the warehouse."
    , ToggleGroup.errorMaybe
        (if List.isEmpty model.days then
            Just "Pick at least one day."

         else
            Nothing
        )
    ]
    { label = "Shipping days", selected = model.days, onChange = DaysChanged }
    [ ToggleGroup.option Mon "Mon", ToggleGroup.option Tue "Tue", ToggleGroup.option Wed "Wed" ]
"""
