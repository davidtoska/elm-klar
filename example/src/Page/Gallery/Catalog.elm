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
    | FormModel
    | DateTime
    | Overlays
    | Navigation
    | DataDisplay
    | Rules
    | Arranging
    | Actions
    | Flow
    | Markdown
    | Review
    | Structured
    | Picking
    | Access
    | Recurring


all : List Section
all =
    [ Foundations, Basics, Selects, Tables, Forms, FormModel, DateTime, Overlays, Navigation, DataDisplay, Rules, Arranging, Actions, Flow, Markdown, Review, Structured, Picking, Access, Recurring ]


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

        FormModel ->
            "form-model"

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

        Arranging ->
            "arranging"

        Actions ->
            "actions"

        Flow ->
            "flow"

        Markdown ->
            "markdown"

        Review ->
            "review"

        Structured ->
            "structured-input"

        Picking ->
            "picking"

        Access ->
            "access"

        Recurring ->
            "recurrence"


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

        FormModel ->
            "Form model"

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

        Arranging ->
            "Arranging and resizing"

        Actions ->
            "Actions and links"

        Flow ->
            "Pages and flow"

        Markdown ->
            "Markdown"

        Review ->
            "Diff and compare"

        Structured ->
            "Structured input"

        Picking ->
            "Picking from trees and lists"

        Access ->
            "Roles and approvals"

        Recurring ->
            "Recurring dates"


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

        FormModel ->
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

        Arranging ->
            Icon.move

        Actions ->
            Icon.zap

        Flow ->
            Icon.flag

        Markdown ->
            Icon.fileText

        Review ->
            Icon.gitBranch

        Structured ->
            Icon.keyboard

        Picking ->
            Icon.listTree

        Access ->
            Icon.shieldCheck

        Recurring ->
            Icon.refresh


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

        FormModel ->
            "A form declared once: values, validation, dirty check and server problems in one state."

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

        Arranging ->
            "Drag or key a list into a new order, and resize panes by dragging or with the keyboard."

        Actions ->
            "Button groups, toggle groups, split buttons, links and keyboard keys."

        Flow ->
            "Result pages, the bulk action bar, the leave guard and undo history."

        Markdown ->
            "A safe Markdown renderer that copes with unfinished text, and an editor with preview."

        Review ->
            "What changed: text, JSON and record diffs, and records side by side."

        Structured ->
            "Masked input for phone numbers, IBAN and the like, and exact money input."

        Picking ->
            "Pick from a tree, drill down through columns, or move items between two lists."

        Access ->
            "A permission matrix for roles and an approval flow with owners and status."

        Recurring ->
            "Rules like every second Tuesday: occurrences, a plain-language description and a picker."


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
            [ "TextArea", "NumberInput", "PasswordInput", "Radio", "CheckboxGroup", "Switch", "Slider", "SegmentedControl", "SearchInput", "TagInput", "FileDrop", "InlineEdit", "Form.Layout" ]

        FormModel ->
            [ "Form", "Form.Spec", "Form.Check", "Ids" ]

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

        Arranging ->
            [ "Sortable", "Splitter" ]

        Actions ->
            [ "ButtonGroup", "ToggleGroup", "SplitButton", "Link", "Kbd" ]

        Flow ->
            [ "StatusPage", "BulkBar", "LeaveGuard", "History" ]

        Markdown ->
            [ "Markdown", "MarkdownEditor" ]

        Review ->
            [ "Diff", "Compare" ]

        Structured ->
            [ "MaskedInput", "Money", "MoneyInput" ]

        Picking ->
            [ "TreeSelect", "Cascader", "Transfer" ]

        Access ->
            [ "PermissionMatrix", "ApprovalFlow" ]

        Recurring ->
            [ "Recurrence", "RecurrencePicker" ]


componentCount : Int
componentCount =
    all |> List.map (components >> List.length) |> List.sum
