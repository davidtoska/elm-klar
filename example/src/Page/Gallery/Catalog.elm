module Page.Gallery.Catalog exposing
    ( Section(..)
    , all
    , componentCount
    , components
    , description
    , fromSlug
    , icon
    , slug
    , title
    )

{-| The list of gallery pages and the components each one covers. Drives the
component index, the sidebar and the search.
-}

import Klar.Icon as Icon exposing (Icon)


type Section
    = Foundations
    | Basics
    | Selects
    | Tables
    | Forms
    | DateTime
    | Overlays
    | Navigation
    | DataDisplay
    | Rules


all : List Section
all =
    [ Foundations, Basics, Selects, Tables, Forms, DateTime, Overlays, Navigation, DataDisplay, Rules ]


slug : Section -> String
slug section =
    case section of
        Foundations ->
            "foundations"

        Basics ->
            "basics"

        Selects ->
            "choosing"

        Tables ->
            "tables"

        Forms ->
            "forms"

        DateTime ->
            "date-and-time"

        Overlays ->
            "overlays"

        Navigation ->
            "navigation"

        DataDisplay ->
            "data-display"

        Rules ->
            "rules"


fromSlug : String -> Maybe Section
fromSlug value =
    all |> List.filter (\section -> slug section == value) |> List.head


title : Section -> String
title section =
    case section of
        Foundations ->
            "Foundations"

        Basics ->
            "Basics"

        Selects ->
            "Choosing"

        Tables ->
            "Tables"

        Forms ->
            "Forms"

        DateTime ->
            "Date and time"

        Overlays ->
            "Dialogs and overlays"

        Navigation ->
            "Navigation and structure"

        DataDisplay ->
            "Data display"

        Rules ->
            "Rules and filters"


icon : Section -> Icon
icon section =
    case section of
        Foundations ->
            Icon.layers

        Basics ->
            Icon.grid

        Selects ->
            Icon.chevronsUpDown

        Tables ->
            Icon.table

        Forms ->
            Icon.clipboardCheck

        DateTime ->
            Icon.calendar

        Overlays ->
            Icon.maximize

        Navigation ->
            Icon.sidebar

        DataDisplay ->
            Icon.barChart

        Rules ->
            Icon.sliders


description : Section -> String
description section =
    case section of
        Foundations ->
            "Colors, typography, icons and layout."

        Basics ->
            "Buttons, menus, badges, messages, loading and error states."

        Selects ->
            "Searchable selects that cope with thousands of options."

        Tables ->
            "Tables with sorting, filters, selection, paging and server mode."

        Forms ->
            "Form fields, validation and form layout."

        DateTime ->
            "Date, period and time pickers, and the calendar."

        Overlays ->
            "Modals, confirmations, drawers, toasts, the command palette and shortcuts."

        Navigation ->
            "The application shell, side navigation, tabs, breadcrumbs and steps."

        DataDisplay ->
            "Trees, timelines, key figures, charts, avatars and progress."

        Rules ->
            "The rule builder, the filter bar and saved views."


{-| The components shown on each page.
-}
components : Section -> List String
components section =
    case section of
        Foundations ->
            [ "Layout (Stack, Row, Grid)", "Card", "Text", "Icon" ]

        Basics ->
            [ "Button", "Menu", "Badge", "Tag", "Alert", "Spinner", "Skeleton", "EmptyState", "ErrorState", "TextInput", "Checkbox" ]

        Selects ->
            [ "Select", "MultiSelect", "Autocomplete", "VirtualList" ]

        Tables ->
            [ "Table", "Pagination" ]

        Forms ->
            [ "TextArea", "NumberInput", "PasswordInput", "Radio", "CheckboxGroup", "Switch", "Slider", "SegmentedControl", "SearchInput", "TagInput", "FileDrop", "InlineEdit", "Form" ]

        DateTime ->
            [ "DatePicker", "DateRangePicker", "TimePicker", "DateTimePicker", "Calendar" ]

        Overlays ->
            [ "Modal", "ConfirmDialog", "Drawer", "Toast", "Popover", "Tooltip", "ContextMenu", "CommandPalette", "ShortcutHelp" ]

        Navigation ->
            [ "AppShell", "SideNav", "PageHeader", "Breadcrumbs", "Tabs", "Accordion", "Toolbar", "DescriptionList", "Stepper" ]

        DataDisplay ->
            [ "Tree", "Timeline", "Stat", "Chart (line, bar, donut, gauge)", "Avatar", "Progress", "ListItem", "JsonViewer" ]

        Rules ->
            [ "RuleBuilder", "FilterBar", "SavedViews" ]


componentCount : Int
componentCount =
    all |> List.map (components >> List.length) |> List.sum
