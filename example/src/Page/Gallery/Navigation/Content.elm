module Page.Gallery.Navigation.Content exposing
    ( Model
    , Msg
    , accordionSection
    , descriptionListSection
    , init
    , stepperSection
    , toolbarSection
    , update
    )

{-| What structures the content of a page: `Accordion`, `Toolbar`,
`DescriptionList` and `Stepper`.
-}

import Html exposing (Html)
import Klar.Accordion as Accordion
import Klar.Badge as Badge
import Klar.Button as Button
import Klar.ButtonGroup as ButtonGroup
import Klar.Card as Card
import Klar.DescriptionList as DescriptionList
import Klar.Format as Format
import Klar.Icon as Icon
import Klar.Ids as Ids exposing (Ids)
import Klar.Layout as Layout
import Klar.Locale exposing (Locale)
import Klar.Menu as Menu
import Klar.Stepper as Stepper
import Klar.Text as Text
import Klar.TextInput as TextInput
import Klar.Theme as Theme exposing (Size(..), Tone(..))
import Klar.Toolbar as Toolbar
import Page.Gallery.Navigation.Demo as Demo
import Showcase.Config as Config
import Showcase.Doc as Doc
import Showcase.Options as Options



-- MODEL


type alias Model =
    { -- accordion
      accSingle : Accordion.State CustomerSection
    , accMultiple : Accordion.State String
    , accFlush : Accordion.State String

    -- toolbar
    , toolbarMenu : Menu.State
    , search : String
    , lastAction : Maybe String

    -- stepper
    , step : Int
    }


init : Model
init =
    { accSingle = Accordion.init "nav-acc-single" |> Accordion.expand Contact
    , accMultiple = Accordion.init "nav-acc-multiple" |> Accordion.setMultiple True |> Accordion.setExpandedIds [ "items", "customs" ]
    , accFlush = Accordion.init "nav-acc-flush" |> Accordion.expand "general"
    , toolbarMenu = Menu.init "nav-toolbar-menu"
    , search = ""
    , lastAction = Nothing
    , step = 1
    }



-- UPDATE


type Msg
    = AccSingleMsg (Accordion.Msg CustomerSection)
    | AccMultipleMsg (Accordion.Msg String)
    | AccFlushMsg (Accordion.Msg String)
    | ExpandAll
    | CollapseAll
    | ToolbarMenuMsg Menu.Msg
    | SearchChanged String
    | Action String
    | SetStep Int


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        AccSingleMsg inner ->
            Accordion.update inner model.accSingle
                |> Tuple.mapBoth (\state -> { model | accSingle = state }) (Cmd.map AccSingleMsg)

        AccMultipleMsg inner ->
            Accordion.update inner model.accMultiple
                |> Tuple.mapBoth (\state -> { model | accMultiple = state }) (Cmd.map AccMultipleMsg)

        AccFlushMsg inner ->
            Accordion.update inner model.accFlush
                |> Tuple.mapBoth (\state -> { model | accFlush = state }) (Cmd.map AccFlushMsg)

        ExpandAll ->
            ( { model | accMultiple = Accordion.expandAll [ "items", "customs", "delivery" ] model.accMultiple }, Cmd.none )

        CollapseAll ->
            ( { model | accMultiple = Accordion.collapseAll model.accMultiple }, Cmd.none )

        ToolbarMenuMsg inner ->
            Menu.update inner model.toolbarMenu
                |> Tuple.mapBoth (\state -> { model | toolbarMenu = state }) (Cmd.map ToolbarMenuMsg)

        SearchChanged value ->
            ( { model | search = value }, Cmd.none )

        Action name ->
            ( { model | lastAction = Just name }, Cmd.none )

        SetStep value ->
            ( { model | step = value }, Cmd.none )



-- ACCORDION


{-| The sections of the first example, a type of the application's own.
-}
type CustomerSection
    = Contact
    | History
    | ChangeLog
    | Billing


customerSectionIds : Ids CustomerSection
customerSectionIds =
    Ids.list
        (\key ->
            case key of
                Contact ->
                    "contact"

                History ->
                    "history"

                ChangeLog ->
                    "change-log"

                Billing ->
                    "billing"
        )
        [ Contact, History, ChangeLog, Billing ]


{-| The sections of the second example: plain text keys.
-}
multipleSections : Config.Config -> List (Accordion.Section String Msg)
multipleSections playground =
    [ Accordion.section Ids.string
        "items"
        "Line items"
        [ Text.paragraph "40 x Hex bolt M8, 12 x Washer M8." ]
        |> Accordion.withCount 2
    , Accordion.section Ids.string
        "customs"
        "Customs"
        [ Text.paragraph "Held at the border: the commercial invoice is missing." ]
        |> Accordion.withBadge (Options.badgeView playground (Options.klarBadge playground (List.concat [ Config.keep playground "Badge" "tone" (Badge.tone Danger), Config.keep playground "Badge" "size" (Badge.size Small) ])) "Held")
    , Accordion.section Ids.string
        "delivery"
        "Delivery"
        [ Text.paragraph "Collected by the carrier on Monday, expected on Thursday." ]
        |> Accordion.withBadge (Options.badgeView playground (Options.klarBadge playground (List.concat [ Config.keep playground "Badge" "tone" (Badge.tone Success), Config.keep playground "Badge" "size" (Badge.size Small) ])) "On time")
    ]


accordionSection : Config.Config -> Locale -> Model -> Html Msg
accordionSection playground locale model =
    Doc.configuredSection playground
        [ "Accordion" ]
        "Accordion"
        "Sections that open and close, keyed by a type of the application's own. By default opening a section closes the others; setMultiple True on the state lets several stay open. The body of a closed section stays in the page, hidden until found: press Ctrl+F and search for \"Rotterdam\" or \"invoice\" with the sections closed, and the browser opens the section (Chrome and Edge). A lazySection is not in the page while it is closed. A header is a button with aria-expanded, inside a heading. Keyboard: Enter and Space open and close the section, Arrow Up and Down move between the headers (wrapping around), Home and End to the first and last."
        [ Doc.configuredExample playground
            [ "Accordion" ]
            { title = "Bordered, one open at a time"
            , description = Just "The default. A disabled section is skipped by the arrow keys. The change log is built only when it is opened (lazySection)."
            , code = Just accordionCode
            }
            (Accordion.view AccSingleMsg
                (Options.klarAccordion playground (List.concat [ Config.keep playground "Accordion" "headingLevel" (Accordion.headingLevel 4) ]))
                model.accSingle
                [ Accordion.section customerSectionIds
                    Contact
                    "Contact details"
                    [ DescriptionList.view (Options.klarDescriptionList playground (List.concat [ Config.keep playground "DescriptionList" "columns" (DescriptionList.columns 2), Config.keep playground "DescriptionList" "locale" (DescriptionList.locale locale) ]))
                        [ DescriptionList.text "Email" "purchasing@northwind.example"
                        , DescriptionList.text "Phone" "+31 20 555 0100"
                        , DescriptionList.text "Address" "Harbor Road 12, 3011 AA Rotterdam"
                        , DescriptionList.maybe "Alternate contact" Nothing
                        ]
                    ]
                    |> Accordion.withIcon Icon.mail
                , Accordion.section customerSectionIds
                    History
                    "History"
                    [ Text.paragraph "Three events last month." ]
                    |> Accordion.withIcon Icon.history
                    |> Accordion.withCount 3
                , Accordion.lazySection customerSectionIds
                    ChangeLog
                    "Change log"
                    (\_ -> [ Text.paragraph "Built only when the section is opened (lazySection)." ])
                    |> Accordion.withIcon Icon.clock
                    |> Accordion.withSubtitle "Last 30 days"
                , Accordion.section customerSectionIds Billing "Billing" [ Text.paragraph "Not available." ]
                    |> Accordion.disabledSection
                    |> Accordion.withIcon Icon.fileText
                ]
            )
        , Doc.configuredExample playground
            [ "Accordion" ]
            { title = "Several open, with badges"
            , description = Just "setMultiple True on the state. The count and the status badges sit at the right of the header. The buttons change the state from the application (expandAll, collapseAll)."
            , code = Just accordionMultipleCode
            }
            (Layout.stack (Options.klarLayout playground (List.concat [ Config.keep playground "Layout" "gap" (Layout.gap 3) ]))
                [ Layout.row (Options.klarLayout playground (List.concat [ Config.keep playground "Layout" "gap" (Layout.gap 2), Config.keep playground "Layout" "alignCenter" Layout.alignCenter, Config.keep playground "Layout" "wrap" Layout.wrap ]))
                    [ Options.buttonView playground (Options.klarButton playground (List.concat [ Config.keep playground "Button" "small" Button.small, Config.keep playground "Button" "onClick" (Button.onClick ExpandAll) ])) "Expand all"
                    , Options.buttonView playground (Options.klarButton playground (List.concat [ Config.keep playground "Button" "small" Button.small, Config.keep playground "Button" "onClick" (Button.onClick CollapseAll) ])) "Collapse all"
                    , Text.caption (String.fromInt (List.length (Accordion.expandedIds model.accMultiple)) ++ " of " ++ String.fromInt (List.length (multipleSections playground)) ++ " sections open")
                    ]
                , Accordion.view AccMultipleMsg (Options.klarAccordion playground (List.concat [ Config.keep playground "Accordion" "headingLevel" (Accordion.headingLevel 4) ])) model.accMultiple (multipleSections playground)
                ]
            )
        , Doc.configuredExample playground
            [ "Accordion" ]
            { title = "Without a frame"
            , description = Just "flush: only a line between the sections, for use inside cards and drawers. Here also small."
            , code = Just accordionFlushCode
            }
            (Card.view (Options.klarCard playground (List.concat [ Config.keep playground "Card" "title" (Card.title "Settings") ]))
                [ Accordion.view AccFlushMsg
                    (Options.klarAccordion playground (List.concat [ Config.keep playground "Accordion" "headingLevel" (Accordion.headingLevel 4), Config.keep playground "Accordion" "flush" Accordion.flush, Config.keep playground "Accordion" "small" Accordion.small ]))
                    model.accFlush
                    [ Accordion.section Ids.string "general" "General" [ Text.paragraph "Language, time zone and date format." ]
                    , Accordion.section Ids.string "notifications" "Notifications" [ Text.paragraph "Which events you are told about." ]
                    , Accordion.section Ids.string "privacy" "Privacy" [ Text.paragraph "Who can see your data." ]
                    ]
                ]
            )
        ]


accordionCode : String
accordionCode =
    """-- type CustomerSection = Contact | History | ChangeLog | Billing
-- sectionIds = Ids.list sectionToString [ Contact, History, ChangeLog, Billing ]
-- model:  accordion : Accordion.State CustomerSection      (Accordion.init "customer-sections" |> Accordion.expand Contact)
-- update: AccordionMsg m -> let ( accordion, cmd ) = Accordion.update m model.accordion in ...

Accordion.view AccordionMsg
    [ Accordion.headingLevel 4 ] -- the level of the heading around each header (default 3)
    model.accordion
    [ Accordion.section sectionIds Contact "Contact details" [ contactView model ]
        |> Accordion.withIcon Icon.mail
    , Accordion.section sectionIds History "History" [ historyView model ]
        |> Accordion.withCount 3
    , Accordion.lazySection sectionIds ChangeLog "Change log" (\\_ -> [ logView model ])
    , Accordion.section sectionIds Billing "Billing" [ billingView model ]
        |> Accordion.disabledSection
    ]"""


accordionMultipleCode : String
accordionMultipleCode =
    """-- init: Accordion.init "shipment-sections" |> Accordion.setMultiple True

Accordion.view AccordionMsg [] model.accordion (shipmentSections model)

shipmentSections model =
    [ Accordion.section Ids.string "items" "Line items" [ itemsView model ]
        |> Accordion.withCount 2
    , Accordion.section Ids.string "customs" "Customs" [ customsView model ]
        |> Accordion.withBadge (Badge.view [ Badge.tone Danger, Badge.size Small ] "Held")
    ]

-- the application can change the state too:
--   Accordion.expandAll [ "items", "customs" ] model.accordion
--   Accordion.collapseAll model.accordion"""


accordionFlushCode : String
accordionFlushCode =
    """Accordion.view AccordionMsg
    [ Accordion.flush, Accordion.small ]
    model.accordion
    [ Accordion.section Ids.string "general" "General" [ generalView model ]
    , Accordion.section Ids.string "privacy" "Privacy" [ privacyView model ]
    ]"""



-- TOOLBAR


toolbarSection : Config.Config -> Locale -> Model -> Html Msg
toolbarSection playground locale model =
    Doc.configuredSection playground
        [ "Toolbar" ]
        "Toolbar"
        "A horizontal bar of grouped controls for the whole view, separators and flexible space. It is a group of controls (role=\"group\", labelled with Toolbar.ariaLabel) and wraps onto a new line when there is no room; scroll keeps it on one line and scrolls sideways instead. The size (size, small, large) sets the height of every control inside, so buttons and fields line up without extra work. Every control is reached with Tab; the arrow keys are not used. Actions for selected items are not a toolbar: BulkBar covers the toolbar while something is selected, and a Table draws its own bar (Table.bulkActions)."
        [ Doc.configuredExample playground
            [ "Toolbar" ]
            { title = "Groups, separators and space"
            , description = Just (Demo.actionText model.lastAction ++ ". Buttons in groups, a separator, flexible space, a label, and then a search field and a menu. The last button of the second group is disabled.")
            , code = Just toolbarCode
            }
            (Toolbar.view (Options.klarToolbar playground (List.concat [ Config.keep playground "Toolbar" "ariaLabel" (Toolbar.ariaLabel "Orders") ]))
                [ Toolbar.group
                    [ Options.buttonView playground (Options.klarButton playground (List.concat [ Config.keep playground "Button" "primary" Button.primary, Config.keep playground "Button" "icon" (Button.icon Icon.plus), Config.keep playground "Button" "onClick" (Button.onClick (Action "New order")) ])) "New order"
                    , Options.buttonView playground (Options.klarButton playground (List.concat [ Config.keep playground "Button" "icon" (Button.icon Icon.download), Config.keep playground "Button" "onClick" (Button.onClick (Action "Export")) ])) "Export"
                    ]
                , Toolbar.separator
                , Toolbar.group
                    [ Options.buttonView playground (Options.klarButton playground (List.concat [ Config.keep playground "Button" "ghost" Button.ghost, Config.keep playground "Button" "icon" (Button.icon Icon.filter), Config.keep playground "Button" "onClick" (Button.onClick (Action "Filter")) ])) "Filter"
                    , Options.buttonView playground (Options.klarButton playground (List.concat [ Config.keep playground "Button" "ghost" Button.ghost, Config.keep playground "Button" "icon" (Button.icon Icon.columns), Config.keep playground "Button" "onClick" (Button.onClick (Action "Columns")) ])) "Columns"
                    , Options.buttonView playground (Options.klarButton playground (List.concat [ Config.keep playground "Button" "ghost" Button.ghost, Config.keep playground "Button" "icon" (Button.icon Icon.layers), Config.keep playground "Button" "disabled" (Button.disabled True) ])) "Group by"
                    ]
                , Toolbar.spacer
                , Toolbar.label (Format.int locale 1482 ++ " orders")
                , TextInput.view
                    (Options.klarTextInput playground
                        (List.concat
                            [ Config.keep playground "TextInput" "search" TextInput.search
                            , Config.keep playground "TextInput" "labelHidden" TextInput.labelHidden
                            , Config.keep playground "TextInput" "label" (TextInput.label "Search orders")
                            , Config.keep playground "TextInput" "placeholder" (TextInput.placeholder "Search ...")
                            , Config.keep playground "TextInput" "clearable" TextInput.clearable
                            , Config.keep playground "TextInput" "value" (TextInput.value model.search)
                            , Config.keep playground "TextInput" "onInput" (TextInput.onInput SearchChanged)
                            , Config.keep playground "TextInput" "id" (TextInput.id "nav-toolbar-search")
                            , Config.keep playground "TextInput" "locale" (TextInput.locale locale)
                            ]
                        )
                    )
                , Menu.view ToolbarMenuMsg
                    (Options.klarMenu playground
                        (List.concat
                            [ Config.keep playground "Menu" "kebab" (Menu.kebab "More actions")
                            , Config.keep playground "Menu" "alignEnd" Menu.alignEnd
                            , Config.keep playground
                                "Menu"
                                "items"
                                (Menu.items
                                    [ Menu.item "Print" (Action "Print") |> Menu.withIcon Icon.print
                                    , Menu.item "Download as CSV" (Action "CSV") |> Menu.withIcon Icon.download
                                    ]
                                )
                            ]
                        )
                    )
                    model.toolbarMenu
                ]
            )
        , Doc.configuredExample playground
            [ "Toolbar" ]
            { title = "Sizes"
            , description = Just "small, standard and large. The buttons follow the height without being marked as small or large."
            , code = Just toolbarSizesCode
            }
            (Layout.stack (Options.klarLayout playground (List.concat [ Config.keep playground "Layout" "gap" (Layout.gap 3) ]))
                (List.map
                    (\( attributes, label ) ->
                        Toolbar.view (Toolbar.ariaLabel (label ++ " toolbar") :: attributes)
                            [ Toolbar.group
                                [ Options.buttonView playground (Options.klarButton playground (List.concat [ Config.keep playground "Button" "icon" (Button.icon Icon.plus) ])) label
                                , Options.buttonView playground (Options.klarButton playground (List.concat [ Config.keep playground "Button" "icon" (Button.icon Icon.filter) ])) "Filter"
                                ]
                            , Toolbar.separator
                            , Toolbar.groupLabelled "View"
                                [ ButtonGroup.view []
                                    "View"
                                    [ Options.buttonView playground (Options.klarButton playground (List.concat [ Config.keep playground "Button" "icon" (Button.icon Icon.list) ])) "List"
                                    , Options.buttonView playground (Options.klarButton playground (List.concat [ Config.keep playground "Button" "icon" (Button.icon Icon.grid) ])) "Grid"
                                    ]
                                ]
                            , Toolbar.spacer
                            , Toolbar.label (Format.int locale 1482 ++ " rows")
                            ]
                    )
                    [ ( Options.klarToolbar playground (List.concat [ Config.keep playground "Toolbar" "small" Toolbar.small ]), "Small" )
                    , ( [], "Standard" )
                    , ( Options.klarToolbar playground (List.concat [ Config.keep playground "Toolbar" "large" Toolbar.large ]), "Large" )
                    ]
                )
            )
        , Doc.configuredExample playground
            [ "Toolbar" ]
            { title = "Wraps and scrolls"
            , description = Just "The same content in a narrow space: on the left the groups wrap onto a new line, on the right the bar scrolls sideways (scroll)."
            , code = Just "Toolbar.view [ Toolbar.scroll, Toolbar.ariaLabel \"Actions\" ]\n    [ Toolbar.group [ Button.view [ Button.icon Icon.plus ] \"New\" ]\n    , Toolbar.separator\n    , Toolbar.group [ Button.view [ Button.ghost, Button.icon Icon.trash ] \"Delete\" ]\n    ]"
            }
            (Layout.row (Options.klarLayout playground (List.concat [ Config.keep playground "Layout" "gap" (Layout.gap 6), Config.keep playground "Layout" "alignStart" Layout.alignStart, Config.keep playground "Layout" "wrap" Layout.wrap ]))
                [ Layout.container (Options.klarLayout playground (List.concat [ Config.keep playground "Layout" "maxWidth" (Layout.maxWidth 300), Config.keep playground "Layout" "alignStart" Layout.alignStart ]))
                    [ Toolbar.view (Options.klarToolbar playground (List.concat [ Config.keep playground "Toolbar" "ariaLabel" (Toolbar.ariaLabel "Wraps") ])) (narrowToolbarItems playground) ]
                , Layout.container (Options.klarLayout playground (List.concat [ Config.keep playground "Layout" "maxWidth" (Layout.maxWidth 300), Config.keep playground "Layout" "alignStart" Layout.alignStart ]))
                    [ Toolbar.view (Options.klarToolbar playground (List.concat [ Config.keep playground "Toolbar" "scroll" Toolbar.scroll, Config.keep playground "Toolbar" "ariaLabel" (Toolbar.ariaLabel "Scrolls") ])) (narrowToolbarItems playground) ]
                ]
            )
        , Doc.configuredExample playground
            [ "Toolbar" ]
            { title = "Plain, inside a card"
            , description = Just "plain: no border, background or padding, for a bar that sits inside another surface such as a card header."
            , code = Just toolbarPlainCode
            }
            (Card.view
                (Options.klarCard playground
                    (List.concat
                        [ Config.keep playground "Card" "title" (Card.title "Open orders")
                        , Config.keep playground
                            "Card"
                            "actions"
                            (Card.actions
                                [ Toolbar.view (Options.klarToolbar playground (List.concat [ Config.keep playground "Toolbar" "plain" Toolbar.plain, Config.keep playground "Toolbar" "small" Toolbar.small, Config.keep playground "Toolbar" "ariaLabel" (Toolbar.ariaLabel "Card actions") ]))
                                    [ Options.buttonView playground (Options.klarButton playground (List.concat [ Config.keep playground "Button" "ghost" Button.ghost, Config.keep playground "Button" "icon" (Button.icon Icon.refresh), Config.keep playground "Button" "onClick" (Button.onClick (Action "Refresh")) ])) "Refresh"
                                    , Options.buttonView playground (Options.klarButton playground (List.concat [ Config.keep playground "Button" "ghost" Button.ghost, Config.keep playground "Button" "icon" (Button.icon Icon.download), Config.keep playground "Button" "onClick" (Button.onClick (Action "Export open orders")) ])) "Export"
                                    ]
                                ]
                            )
                        ]
                    )
                )
                [ Text.paragraph "The actions in the header of this card are a toolbar without a frame of its own." ]
            )
        ]


narrowToolbarItems : Config.Config -> List (Html msg)
narrowToolbarItems playground =
    [ Toolbar.group
        [ Options.buttonView playground (Options.klarButton playground (List.concat [ Config.keep playground "Button" "primary" Button.primary, Config.keep playground "Button" "icon" (Button.icon Icon.plus) ])) "New"
        , Options.buttonView playground (Options.klarButton playground (List.concat [ Config.keep playground "Button" "icon" (Button.icon Icon.download) ])) "Export"
        , Options.buttonView playground (Options.klarButton playground (List.concat [ Config.keep playground "Button" "icon" (Button.icon Icon.print) ])) "Print"
        ]
    , Toolbar.separator
    , Toolbar.group
        [ Options.buttonView playground (Options.klarButton playground (List.concat [ Config.keep playground "Button" "ghost" Button.ghost, Config.keep playground "Button" "icon" (Button.icon Icon.archive) ])) "Archive"
        , Options.buttonView playground (Options.klarButton playground (List.concat [ Config.keep playground "Button" "ghost" Button.ghost, Config.keep playground "Button" "icon" (Button.icon Icon.trash) ])) "Delete"
        ]
    ]


toolbarCode : String
toolbarCode =
    """Toolbar.view [ Toolbar.ariaLabel "Orders" ]
    [ Toolbar.group
        [ Button.view [ Button.primary, Button.icon Icon.plus ] "New order"
        , Button.view [ Button.icon Icon.download ] "Export"
        ]
    , Toolbar.separator
    , Toolbar.group [ Button.view [ Button.ghost, Button.icon Icon.filter ] "Filter" ]
    , Toolbar.spacer
    , Toolbar.label "1,482 orders"
    , TextInput.view
        [ TextInput.search
        , TextInput.labelHidden
        , TextInput.label "Search orders"
        , TextInput.value model.query
        , TextInput.onInput QueryChanged
        ]
    , Menu.view MenuMsg [ Menu.kebab "More actions", Menu.alignEnd, Menu.items [ Menu.item "Print" Print ] ] model.menu
    ]"""


toolbarSizesCode : String
toolbarSizesCode =
    """Toolbar.view [ Toolbar.small, Toolbar.ariaLabel "Filters" ]
    [ Toolbar.group
        [ Button.view [ Button.icon Icon.plus ] "New"
        , Button.view [ Button.icon Icon.filter ] "Filter"
        ]
    , Toolbar.separator
    , Toolbar.groupLabelled "View"
        [ ButtonGroup.view [] "View"
            [ Button.view [ Button.icon Icon.list ] "List"
            , Button.view [ Button.icon Icon.grid ] "Grid"
            ]
        ]
    , Toolbar.spacer
    , Toolbar.label "1,482 rows"
    ]"""


toolbarPlainCode : String
toolbarPlainCode =
    """Card.view
    [ Card.title "Open orders"
    , Card.actions
        [ Toolbar.view [ Toolbar.plain, Toolbar.small, Toolbar.ariaLabel "Card actions" ]
            [ Button.view [ Button.ghost, Button.icon Icon.refresh ] "Refresh"
            , Button.view [ Button.ghost, Button.icon Icon.download ] "Export"
            ]
        ]
    ]
    [ orderList model ]"""



-- DESCRIPTION LIST


descriptionItems : List (DescriptionList.Item msg)
descriptionItems =
    [ DescriptionList.text "Customer number" "100482"
    , DescriptionList.text "Name" "Northwind Traders"
    , DescriptionList.html "Status" (Badge.status Success "Active")
    , DescriptionList.maybe "Phone" Nothing
    , DescriptionList.maybe "Email" (Just "purchasing@northwind.example")
    , DescriptionList.text "Address" ""
    , DescriptionList.values "Sales channels"
        [ Badge.view [] "Web shop"
        , Badge.view [] "Wholesale"
        ]
    , DescriptionList.text "Delivery note" "The customer asked to be contacted by email, not by phone. No calls before ten in the morning, and never on weekends. This is a long text, there to show that a field can use the whole width."
        |> DescriptionList.fullWidth
    ]


descriptionListSection : Config.Config -> Locale -> Html msg
descriptionListSection playground locale =
    Doc.configuredSection playground
        [ "DescriptionList" ]
        "Description list"
        "Names and values for detail views, as a semantic dl. The label sits above the value by default, or in a column on the left (labelBeside). The number of columns is a maximum: the grid drops to fewer columns when there is no room (a column is never narrower than 200 px). A missing value is shown as a muted dash with \"Not provided\" for screen readers, so a row never disappears without explanation."
        [ Doc.configuredExample playground
            [ "DescriptionList" ]
            { title = "One and two columns"
            , description = Just "Label above value. The delivery note uses the whole row. Phone and address are missing."
            , code = Just descriptionListCode
            }
            (Layout.stack (Options.klarLayout playground (List.concat [ Config.keep playground "Layout" "gap" (Layout.gap 6) ]))
                [ DescriptionList.view (Options.klarDescriptionList playground (List.concat [ Config.keep playground "DescriptionList" "locale" (DescriptionList.locale locale) ])) (List.take 5 descriptionItems)
                , Layout.divider
                , DescriptionList.view (Options.klarDescriptionList playground (List.concat [ Config.keep playground "DescriptionList" "columns" (DescriptionList.columns 2), Config.keep playground "DescriptionList" "locale" (DescriptionList.locale locale) ])) descriptionItems
                ]
            )
        , Doc.configuredExample playground
            [ "DescriptionList" ]
            { title = "Label beside, with lines"
            , description = Just "Above: labelBeside and bordered, with a narrower label column. Below: three columns (as many as there is room for), compact and bordered."
            , code = Just "DescriptionList.view\n    [ DescriptionList.labelBeside\n    , DescriptionList.bordered\n    , DescriptionList.labelWidth 120\n    ]\n    items"
            }
            (Layout.stack (Options.klarLayout playground (List.concat [ Config.keep playground "Layout" "gap" (Layout.gap 6) ]))
                [ DescriptionList.view
                    (Options.klarDescriptionList playground
                        (List.concat
                            [ Config.keep playground "DescriptionList" "labelBeside" DescriptionList.labelBeside
                            , Config.keep playground "DescriptionList" "bordered" DescriptionList.bordered
                            , Config.keep playground "DescriptionList" "labelWidth" (DescriptionList.labelWidth 120)
                            , Config.keep playground "DescriptionList" "columns" (DescriptionList.columns 1)
                            , Config.keep playground "DescriptionList" "locale" (DescriptionList.locale locale)
                            ]
                        )
                    )
                    (List.take 6 descriptionItems)
                , DescriptionList.view
                    (Options.klarDescriptionList playground
                        (List.concat
                            [ Config.keep playground "DescriptionList" "columns" (DescriptionList.columns 3)
                            , Config.keep playground "DescriptionList" "density" (DescriptionList.density Theme.Compact)
                            , Config.keep playground "DescriptionList" "bordered" DescriptionList.bordered
                            , Config.keep playground "DescriptionList" "locale" (DescriptionList.locale locale)
                            ]
                        )
                    )
                    (List.take 6 descriptionItems)
                ]
            )
        ]


descriptionListCode : String
descriptionListCode =
    """DescriptionList.view [ DescriptionList.columns 2 ]
    [ DescriptionList.text "Customer number" "100482"
    , DescriptionList.maybe "Phone" model.phone -- Nothing gives a muted dash
    , DescriptionList.html "Status" (Badge.status Success "Active")
    , DescriptionList.values "Sales channels" [ Badge.view [] "Web shop", Badge.view [] "Wholesale" ]
    , DescriptionList.text "Delivery note" model.note |> DescriptionList.fullWidth
    ]"""



-- STEPPER


steps : List Stepper.Step
steps =
    [ Stepper.step "Customer" |> Stepper.withDescription "Name and customer number"
    , Stepper.step "Delivery" |> Stepper.withDescription "Address and carrier"
    , Stepper.step "Documents" |> Stepper.withDescription "Upload attachments"
    , Stepper.step "Summary"
    , Stepper.step "Submit"
    ]


stepperSection : Config.Config -> Locale -> Model -> Html Msg
stepperSection playground locale model =
    let
        count =
            List.length steps
    in
    Doc.configuredSection playground
        [ "Stepper" ]
        "Stepper"
        "The steps of a wizard, horizontal or vertical, with thin lines between them. A step is complete, current, upcoming, failed or disabled. The current step has aria-current=\"step\". With onSelect the steps up to the current one become buttons, so the user can go back but not skip ahead; nonLinear makes every step that is not disabled a button. progress gives the short text \"Step 2 of 5\"."
        [ Doc.configuredExample playground
            [ "Stepper" ]
            { title = "Wizard"
            , description = Just "Click a step, or use the buttons. Completed steps are blue."
            , code = Just stepperCode
            }
            (Layout.stack (Options.klarLayout playground (List.concat [ Config.keep playground "Layout" "gap" (Layout.gap 4) ]))
                [ Stepper.view (Options.klarStepper playground (List.concat [ Config.keep playground "Stepper" "current" (Stepper.current model.step), Config.keep playground "Stepper" "onSelect" (Stepper.onSelect SetStep), Config.keep playground "Stepper" "locale" (Stepper.locale locale) ])) steps
                , Layout.row (Options.klarLayout playground (List.concat [ Config.keep playground "Layout" "gap" (Layout.gap 3), Config.keep playground "Layout" "alignCenter" Layout.alignCenter ]))
                    [ Options.buttonView playground (Options.klarButton playground (List.concat [ Config.keep playground "Button" "icon" (Button.icon Icon.arrowLeft), Config.keep playground "Button" "disabled" (Button.disabled (model.step <= 0)), Config.keep playground "Button" "onClick" (Button.onClick (SetStep (model.step - 1))) ])) "Previous"
                    , Options.buttonView playground (Options.klarButton playground (List.concat [ Config.keep playground "Button" "primary" Button.primary, Config.keep playground "Button" "iconRight" (Button.iconRight Icon.arrowRight), Config.keep playground "Button" "disabled" (Button.disabled (model.step >= count - 1)), Config.keep playground "Button" "onClick" (Button.onClick (SetStep (model.step + 1))) ])) "Next"
                    , Stepper.progress (Options.klarStepper playground (List.concat [ Config.keep playground "Stepper" "current" (Stepper.current model.step), Config.keep playground "Stepper" "locale" (Stepper.locale locale) ])) steps
                    ]
                ]
            )
        , Doc.configuredExample playground
            [ "Stepper" ]
            { title = "States"
            , description = Just "Complete, current, upcoming, with errors and unavailable."
            , code = Just stepperStatesCode
            }
            (Stepper.view (Options.klarStepper playground (List.concat [ Config.keep playground "Stepper" "current" (Stepper.current 2), Config.keep playground "Stepper" "locale" (Stepper.locale locale) ]))
                [ Stepper.step "Complete"
                , Stepper.step "Also complete"
                , Stepper.step "Current"
                , Stepper.step "Upcoming"
                , Stepper.step "With errors" |> Stepper.failed
                , Stepper.step "Unavailable" |> Stepper.disabledStep
                ]
            )
        , Doc.configuredExample playground
            [ "Stepper" ]
            { title = "Vertical"
            , description = Just "For sidebars and long descriptions. On the right with small markers (small) and without onSelect."
            , code = Just "Stepper.view [ Stepper.vertical, Stepper.current 1 ] steps"
            }
            (Layout.grid (Options.klarLayout playground (List.concat [ Config.keep playground "Layout" "columns" (Layout.columns 2), Config.keep playground "Layout" "gap" (Layout.gap 8), Config.keep playground "Layout" "alignStart" Layout.alignStart ]))
                [ Stepper.view (Options.klarStepper playground (List.concat [ Config.keep playground "Stepper" "vertical" Stepper.vertical, Config.keep playground "Stepper" "current" (Stepper.current model.step), Config.keep playground "Stepper" "onSelect" (Stepper.onSelect SetStep), Config.keep playground "Stepper" "locale" (Stepper.locale locale) ])) steps
                , Stepper.view (Options.klarStepper playground (List.concat [ Config.keep playground "Stepper" "vertical" Stepper.vertical, Config.keep playground "Stepper" "small" Stepper.small, Config.keep playground "Stepper" "current" (Stepper.current model.step), Config.keep playground "Stepper" "locale" (Stepper.locale locale) ])) steps
                ]
            )
        , Doc.configuredExample playground
            [ "Stepper" ]
            { title = "Narrow space"
            , description = Just "Long names are cut. The text \"Step 2 of 3\" often suits small screens better."
            , code = Nothing
            }
            (Layout.container (Options.klarLayout playground (List.concat [ Config.keep playground "Layout" "maxWidth" (Layout.maxWidth 420), Config.keep playground "Layout" "alignStart" Layout.alignStart ]))
                [ Layout.stack (Options.klarLayout playground (List.concat [ Config.keep playground "Layout" "gap" (Layout.gap 3) ]))
                    [ Stepper.view (Options.klarStepper playground (List.concat [ Config.keep playground "Stepper" "current" (Stepper.current 1), Config.keep playground "Stepper" "locale" (Stepper.locale locale) ])) narrowSteps
                    , Stepper.progress (Options.klarStepper playground (List.concat [ Config.keep playground "Stepper" "current" (Stepper.current 1), Config.keep playground "Stepper" "locale" (Stepper.locale locale) ])) narrowSteps
                    ]
                ]
            )
        ]


narrowSteps : List Stepper.Step
narrowSteps =
    [ Stepper.step "A step with a rather long name"
    , Stepper.step "Another long name"
    , Stepper.step "End"
    ]


stepperCode : String
stepperCode =
    """Stepper.view
    [ Stepper.current model.step -- counting from 0
    , Stepper.onSelect GoToStep
    ]
    steps


steps : List Stepper.Step
steps =
    [ Stepper.step "Customer" |> Stepper.withDescription "Name and customer number"
    , Stepper.step "Delivery"
    , Stepper.step "Documents"
    , Stepper.step "Submit"
    ]


-- the one-line summary: "Step 2 of 4"
Stepper.progress [ Stepper.current model.step ] steps"""


stepperStatesCode : String
stepperStatesCode =
    """Stepper.view [ Stepper.current 2 ]
    [ Stepper.step "Customer"
    , Stepper.step "Delivery"
    , Stepper.step "Documents" |> Stepper.failed
    , Stepper.step "Submit" |> Stepper.disabledStep
    ]"""
