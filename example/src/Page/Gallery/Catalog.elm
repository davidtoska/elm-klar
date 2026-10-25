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
    = Examples
    | Foundations
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
    | StaleData
    | ServerLists
    | Workbench
    | NextComponents
    | Processes
    | ProcessComponent String


all : List Section
all =
    [ Examples, Foundations, Basics, Selects, Tables, Forms, FormModel, DateTime, Overlays, Navigation, DataDisplay, Rules, Arranging, Actions, Flow, Markdown, Review, Structured, Picking, Access, Recurring, StaleData, ServerLists, Workbench, NextComponents, Processes ] ++ List.map ProcessComponent [ "Workflow", "Workflow.Engine", "Workflow.Codec", "WorkflowNode", "WorkflowBuilder", "WorkflowRun", "StateMachine" ]


slug : Section -> String
slug section =
    case section of
        Processes ->
            "processes"

        ProcessComponent name ->
            case name of
                "Workflow.Engine" ->
                    "workflow-engine"

                "Workflow.Codec" ->
                    "workflow-codec"

                "WorkflowNode" ->
                    "workflow-node"

                "WorkflowBuilder" ->
                    "workflow-builder"

                "WorkflowRun" ->
                    "workflow-run"

                "StateMachine" ->
                    "state-machine"

                _ ->
                    "workflow"

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

        StaleData ->
            "old-data"

        ServerLists ->
            "server-lists"

        Examples ->
            "examples"

        Workbench ->
            "workbench"

        NextComponents ->
            "workflow-toolkit"


fromSlug : String -> Maybe Section
fromSlug value =
    all |> List.filter (\section -> slug section == value) |> List.head


title : Section -> String
title section =
    case section of
        Processes ->
            "Processes & state"

        ProcessComponent name ->
            name

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

        StaleData ->
            "Old and refreshing data"

        ServerLists ->
            "Server lists"

        Examples ->
            "Examples"

        Workbench ->
            "Data workbench"

        NextComponents ->
            "Workflow toolkit"


icon : Section -> Icon
icon section =
    case section of
        Processes ->
            Icon.gitBranch

        ProcessComponent _ ->
            Icon.gitBranch

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

        StaleData ->
            Icon.clock

        ServerLists ->
            Icon.database

        Examples ->
            Icon.layout

        Workbench ->
            Icon.clipboardCheck

        NextComponents ->
            Icon.layers


description : Section -> String
description section =
    case section of
        Processes ->
            "Build and run visual AI/human workflows, approval and state machines."

        ProcessComponent name ->
            "Explore Klar." ++ name ++ " with a working process studio."

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

        StaleData ->
            "Data that is refreshed, or old because the last refresh failed: every data component draws it, from the Remote alone."

        ServerLists ->
            "A table, a filter bar and saved views over rows on a server, with no glue: tickets, page reset, saved views. Make the server slow, jumbled or failing."

        Examples ->
            "Seven complete applications, each one Elm file: an inbox, an edit form, delete with confirmation, a dashboard, a multi-step flow, a command palette and a review desk."

        Workbench ->
            "Cards, keyboard work queues, three-way conflict resolution, audit diffs and persistent notifications."

        NextComponents ->
            "Kanban work stages, threaded discussion, explicit file uploads, safe source code and typed quantities."


{-| The components shown on each page.
-}
components : Section -> List String
components section =
    case section of
        Processes ->
            []

        ProcessComponent name ->
            [ name ]

        Foundations ->
            [ "Layout (Stack, Row, Grid)", "Card", "Text", "Icon" ]

        Basics ->
            [ "Button", "Menu", "Badge", "Tag", "Alert", "Spinner", "Skeleton", "EmptyState", "ErrorState", "TextInput", "Checkbox" ]

        Selects ->
            [ "Select", "MultiSelect", "Autocomplete", "VirtualList" ]

        Tables ->
            [ "Table", "Budget", "Pagination" ]

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

        StaleData ->
            [ "Remote", "RemoteView" ]

        ServerLists ->
            [ "ServerList" ]

        Examples ->
            [ "Inbox", "Edit form", "Confirm delete", "Dashboard", "Multi-step flow", "Command palette" ]

        Workbench ->
            [ "CardList", "WorkQueue", "ConflictResolver", "AuditLog", "NotificationCenter" ]

        NextComponents ->
            [ "Kanban", "CommentThread", "UploadQueue", "CodeBlock", "QuantityInput" ]


componentCount : Int
componentCount =
    all |> List.map (components >> List.length) |> List.sum
