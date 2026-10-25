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
import Showcase.Doc as Doc



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
multipleSections : List (Accordion.Section String Msg)
multipleSections =
    [ Accordion.section Ids.string
        "items"
        "Line items"
        [ Text.paragraph "40 x Hex bolt M8, 12 x Washer M8." ]
        |> Accordion.withCount 2
    , Accordion.section Ids.string
        "customs"
        "Customs"
        [ Text.paragraph "Held at the border: the commercial invoice is missing." ]
        |> Accordion.withBadge (Badge.view [ Badge.tone Danger, Badge.size Small ] "Held")
    , Accordion.section Ids.string
        "delivery"
        "Delivery"
        [ Text.paragraph "Collected by the carrier on Monday, expected on Thursday." ]
        |> Accordion.withBadge (Badge.view [ Badge.tone Success, Badge.size Small ] "On time")
    ]


accordionSection : Locale -> Model -> Html Msg
accordionSection locale model =
    Doc.section "Accordion"
        "Sections that open and close, keyed by a type of the application's own. By default opening a section closes the others; setMultiple True on the state lets several stay open. The body of a closed section stays in the page, hidden until found: press Ctrl+F and search for \"Rotterdam\" or \"invoice\" with the sections closed, and the browser opens the section (Chrome and Edge). A lazySection is not in the page while it is closed. A header is a button with aria-expanded, inside a heading. Keyboard: Enter and Space open and close the section, Arrow Up and Down move between the headers (wrapping around), Home and End to the first and last."
        [ Doc.example
            { title = "Bordered, one open at a time"
            , description = Just "The default. A disabled section is skipped by the arrow keys. The change log is built only when it is opened (lazySection)."
            , code = Just accordionCode
            }
            (Accordion.view AccSingleMsg
                [ Accordion.headingLevel 4 ]
                model.accSingle
                [ Accordion.section customerSectionIds
                    Contact
                    "Contact details"
                    [ DescriptionList.view [ DescriptionList.columns 2, DescriptionList.locale locale ]
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
        , Doc.example
            { title = "Several open, with badges"
            , description = Just "setMultiple True on the state. The count and the status badges sit at the right of the header. The buttons change the state from the application (expandAll, collapseAll)."
            , code = Just accordionMultipleCode
            }
            (Layout.stack [ Layout.gap 3 ]
                [ Layout.row [ Layout.gap 2, Layout.alignCenter, Layout.wrap ]
                    [ Button.view [ Button.small, Button.onClick ExpandAll ] "Expand all"
                    , Button.view [ Button.small, Button.onClick CollapseAll ] "Collapse all"
                    , Text.caption (String.fromInt (List.length (Accordion.expandedIds model.accMultiple)) ++ " of " ++ String.fromInt (List.length multipleSections) ++ " sections open")
                    ]
                , Accordion.view AccMultipleMsg [ Accordion.headingLevel 4 ] model.accMultiple multipleSections
                ]
            )
        , Doc.example
            { title = "Without a frame"
            , description = Just "flush: only a line between the sections, for use inside cards and drawers. Here also small."
            , code = Just accordionFlushCode
            }
            (Card.view [ Card.title "Settings" ]
                [ Accordion.view AccFlushMsg
                    [ Accordion.headingLevel 4, Accordion.flush, Accordion.small ]
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


toolbarSection : Locale -> Model -> Html Msg
toolbarSection locale model =
    Doc.section "Toolbar"
        "A horizontal bar of grouped controls for the whole view, separators and flexible space. It is a group of controls (role=\"group\", labelled with Toolbar.ariaLabel) and wraps onto a new line when there is no room; scroll keeps it on one line and scrolls sideways instead. The size (size, small, large) sets the height of every control inside, so buttons and fields line up without extra work. Every control is reached with Tab; the arrow keys are not used. Actions for selected items are not a toolbar: BulkBar covers the toolbar while something is selected, and a Table draws its own bar (Table.bulkActions)."
        [ Doc.example
            { title = "Groups, separators and space"
            , description = Just (Demo.actionText model.lastAction ++ ". Buttons in groups, a separator, flexible space, a label, and then a search field and a menu. The last button of the second group is disabled.")
            , code = Just toolbarCode
            }
            (Toolbar.view [ Toolbar.ariaLabel "Orders" ]
                [ Toolbar.group
                    [ Button.view [ Button.primary, Button.icon Icon.plus, Button.onClick (Action "New order") ] "New order"
                    , Button.view [ Button.icon Icon.download, Button.onClick (Action "Export") ] "Export"
                    ]
                , Toolbar.separator
                , Toolbar.group
                    [ Button.view [ Button.ghost, Button.icon Icon.filter, Button.onClick (Action "Filter") ] "Filter"
                    , Button.view [ Button.ghost, Button.icon Icon.columns, Button.onClick (Action "Columns") ] "Columns"
                    , Button.view [ Button.ghost, Button.icon Icon.layers, Button.disabled True ] "Group by"
                    ]
                , Toolbar.spacer
                , Toolbar.label (Format.int locale 1482 ++ " orders")
                , TextInput.view
                    [ TextInput.search
                    , TextInput.labelHidden
                    , TextInput.label "Search orders"
                    , TextInput.placeholder "Search ..."
                    , TextInput.clearable
                    , TextInput.value model.search
                    , TextInput.onInput SearchChanged
                    , TextInput.id "nav-toolbar-search"
                    , TextInput.locale locale
                    ]
                , Menu.view ToolbarMenuMsg
                    [ Menu.kebab "More actions"
                    , Menu.alignEnd
                    , Menu.items
                        [ Menu.item "Print" (Action "Print") |> Menu.withIcon Icon.print
                        , Menu.item "Download as CSV" (Action "CSV") |> Menu.withIcon Icon.download
                        ]
                    ]
                    model.toolbarMenu
                ]
            )
        , Doc.example
            { title = "Sizes"
            , description = Just "small, standard and large. The buttons follow the height without being marked as small or large."
            , code = Just toolbarSizesCode
            }
            (Layout.stack [ Layout.gap 3 ]
                (List.map
                    (\( attributes, label ) ->
                        Toolbar.view (Toolbar.ariaLabel (label ++ " toolbar") :: attributes)
                            [ Toolbar.group
                                [ Button.view [ Button.icon Icon.plus ] label
                                , Button.view [ Button.icon Icon.filter ] "Filter"
                                ]
                            , Toolbar.separator
                            , Toolbar.groupLabelled "View"
                                [ ButtonGroup.view []
                                    "View"
                                    [ Button.view [ Button.icon Icon.list ] "List"
                                    , Button.view [ Button.icon Icon.grid ] "Grid"
                                    ]
                                ]
                            , Toolbar.spacer
                            , Toolbar.label (Format.int locale 1482 ++ " rows")
                            ]
                    )
                    [ ( [ Toolbar.small ], "Small" )
                    , ( [], "Standard" )
                    , ( [ Toolbar.large ], "Large" )
                    ]
                )
            )
        , Doc.example
            { title = "Wraps and scrolls"
            , description = Just "The same content in a narrow space: on the left the groups wrap onto a new line, on the right the bar scrolls sideways (scroll)."
            , code = Just "Toolbar.view [ Toolbar.scroll, Toolbar.ariaLabel \"Actions\" ]\n    [ Toolbar.group [ Button.view [ Button.icon Icon.plus ] \"New\" ]\n    , Toolbar.separator\n    , Toolbar.group [ Button.view [ Button.ghost, Button.icon Icon.trash ] \"Delete\" ]\n    ]"
            }
            (Layout.row [ Layout.gap 6, Layout.alignStart, Layout.wrap ]
                [ Layout.container [ Layout.maxWidth 300, Layout.alignStart ]
                    [ Toolbar.view [ Toolbar.ariaLabel "Wraps" ] narrowToolbarItems ]
                , Layout.container [ Layout.maxWidth 300, Layout.alignStart ]
                    [ Toolbar.view [ Toolbar.scroll, Toolbar.ariaLabel "Scrolls" ] narrowToolbarItems ]
                ]
            )
        , Doc.example
            { title = "Plain, inside a card"
            , description = Just "plain: no border, background or padding, for a bar that sits inside another surface such as a card header."
            , code = Just toolbarPlainCode
            }
            (Card.view
                [ Card.title "Open orders"
                , Card.actions
                    [ Toolbar.view [ Toolbar.plain, Toolbar.small, Toolbar.ariaLabel "Card actions" ]
                        [ Button.view [ Button.ghost, Button.icon Icon.refresh, Button.onClick (Action "Refresh") ] "Refresh"
                        , Button.view [ Button.ghost, Button.icon Icon.download, Button.onClick (Action "Export open orders") ] "Export"
                        ]
                    ]
                ]
                [ Text.paragraph "The actions in the header of this card are a toolbar without a frame of its own." ]
            )
        ]


narrowToolbarItems : List (Html msg)
narrowToolbarItems =
    [ Toolbar.group
        [ Button.view [ Button.primary, Button.icon Icon.plus ] "New"
        , Button.view [ Button.icon Icon.download ] "Export"
        , Button.view [ Button.icon Icon.print ] "Print"
        ]
    , Toolbar.separator
    , Toolbar.group
        [ Button.view [ Button.ghost, Button.icon Icon.archive ] "Archive"
        , Button.view [ Button.ghost, Button.icon Icon.trash ] "Delete"
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


descriptionListSection : Locale -> Html msg
descriptionListSection locale =
    Doc.section "Description list"
        "Names and values for detail views, as a semantic dl. The label sits above the value by default, or in a column on the left (labelBeside). The number of columns is a maximum: the grid drops to fewer columns when there is no room (a column is never narrower than 200 px). A missing value is shown as a muted dash with \"Not provided\" for screen readers, so a row never disappears without explanation."
        [ Doc.example
            { title = "One and two columns"
            , description = Just "Label above value. The delivery note uses the whole row. Phone and address are missing."
            , code = Just descriptionListCode
            }
            (Layout.stack [ Layout.gap 6 ]
                [ DescriptionList.view [ DescriptionList.locale locale ] (List.take 5 descriptionItems)
                , Layout.divider
                , DescriptionList.view [ DescriptionList.columns 2, DescriptionList.locale locale ] descriptionItems
                ]
            )
        , Doc.example
            { title = "Label beside, with lines"
            , description = Just "Above: labelBeside and bordered, with a narrower label column. Below: three columns (as many as there is room for), compact and bordered."
            , code = Just "DescriptionList.view\n    [ DescriptionList.labelBeside\n    , DescriptionList.bordered\n    , DescriptionList.labelWidth 120\n    ]\n    items"
            }
            (Layout.stack [ Layout.gap 6 ]
                [ DescriptionList.view
                    [ DescriptionList.labelBeside
                    , DescriptionList.bordered
                    , DescriptionList.labelWidth 120
                    , DescriptionList.columns 1
                    , DescriptionList.locale locale
                    ]
                    (List.take 6 descriptionItems)
                , DescriptionList.view
                    [ DescriptionList.columns 3
                    , DescriptionList.density Theme.Compact
                    , DescriptionList.bordered
                    , DescriptionList.locale locale
                    ]
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


stepperSection : Locale -> Model -> Html Msg
stepperSection locale model =
    let
        count =
            List.length steps
    in
    Doc.section "Stepper"
        "The steps of a wizard, horizontal or vertical, with thin lines between them. A step is complete, current, upcoming, failed or disabled. The current step has aria-current=\"step\". With onSelect every step that is not disabled becomes a button; disable the steps that must not be visited yet. progress gives the short text \"Step 2 of 5\"."
        [ Doc.example
            { title = "Wizard"
            , description = Just "Click a step, or use the buttons. Completed steps are blue."
            , code = Just stepperCode
            }
            (Layout.stack [ Layout.gap 4 ]
                [ Stepper.view [ Stepper.current model.step, Stepper.onSelect SetStep, Stepper.locale locale ] steps
                , Layout.row [ Layout.gap 3, Layout.alignCenter ]
                    [ Button.view [ Button.icon Icon.arrowLeft, Button.disabled (model.step <= 0), Button.onClick (SetStep (model.step - 1)) ] "Previous"
                    , Button.view [ Button.primary, Button.iconRight Icon.arrowRight, Button.disabled (model.step >= count - 1), Button.onClick (SetStep (model.step + 1)) ] "Next"
                    , Stepper.progress [ Stepper.current model.step, Stepper.locale locale ] steps
                    ]
                ]
            )
        , Doc.example
            { title = "States"
            , description = Just "Complete, current, upcoming, with errors and unavailable."
            , code = Just stepperStatesCode
            }
            (Stepper.view [ Stepper.current 2, Stepper.locale locale ]
                [ Stepper.step "Complete"
                , Stepper.step "Also complete"
                , Stepper.step "Current"
                , Stepper.step "Upcoming"
                , Stepper.step "With errors" |> Stepper.failed
                , Stepper.step "Unavailable" |> Stepper.disabledStep
                ]
            )
        , Doc.example
            { title = "Vertical"
            , description = Just "For sidebars and long descriptions. On the right with small markers (small) and without onSelect."
            , code = Just "Stepper.view [ Stepper.vertical, Stepper.current 1 ] steps"
            }
            (Layout.grid [ Layout.columns 2, Layout.gap 8, Layout.alignStart ]
                [ Stepper.view [ Stepper.vertical, Stepper.current model.step, Stepper.onSelect SetStep, Stepper.locale locale ] steps
                , Stepper.view [ Stepper.vertical, Stepper.small, Stepper.current model.step, Stepper.locale locale ] steps
                ]
            )
        , Doc.example
            { title = "Narrow space"
            , description = Just "Long names are cut. The text \"Step 2 of 3\" often suits small screens better."
            , code = Nothing
            }
            (Layout.container [ Layout.maxWidth 420, Layout.alignStart ]
                [ Layout.stack [ Layout.gap 3 ]
                    [ Stepper.view [ Stepper.current 1, Stepper.locale locale ] narrowSteps
                    , Stepper.progress [ Stepper.current 1, Stepper.locale locale ] narrowSteps
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
