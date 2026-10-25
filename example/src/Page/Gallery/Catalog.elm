module Page.Gallery.Catalog exposing
    ( Section(..)
    , all
    , componentCount
    , componentSlug
    , components
    , description
    , fromSlug
    , group
    , icon
    , owner
    , pages
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
    | Ai
    | Processes
    | Component String


all : List Section
all =
    [ Examples, Foundations, Basics, Selects, Tables, Forms, FormModel, DateTime, Overlays, Navigation, DataDisplay, Rules, Arranging, Actions, Flow, Markdown, Review, Structured, Picking, Access, Recurring, StaleData, ServerLists, Workbench, NextComponents, Ai, Processes ]


slug : Section -> String
slug section =
    case section of
        Component name ->
            componentSlug name

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

        Ai ->
            "ai"

        Processes ->
            "processes"


fromSlug : String -> Maybe Section
fromSlug value =
    (pages ++ all) |> List.filter (\section -> slug section == value) |> List.head


title : Section -> String
title section =
    case section of
        Component name ->
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

        Ai ->
            "AI workspace"

        Processes ->
            "Processes & state"


icon : Section -> Icon
icon section =
    case section of
        Component name ->
            icon (owner name)

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

        Ai ->
            Icon.zap

        Processes ->
            Icon.gitBranch


description : Section -> String
description section =
    case section of
        Component name ->
            "Configure Klar." ++ name ++ " and explore its states and compositions."

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

        Ai ->
            "Server-generated AI proposals, sources, revision-bound approval, statement discussions and streaming chat."

        Processes ->
            "Visual workflows, AI tasks, human checkpoints, bounded loops, execution state and state machines."


{-| The components shown on each page.
-}
components : Section -> List String
components section =
    case section of
        Component name ->
            [ name ]

        Foundations ->
            [ "Klar", "Layout", "Card", "Text", "Icon", "Icon.Library", "Icon.Arrows", "Icon.Business", "Icon.Calendar", "Icon.Communication", "Icon.Data", "Icon.Developer", "Icon.Devices", "Icon.Documents", "Icon.Editor", "Icon.Interface", "Icon.Logistics", "Icon.Media", "Icon.Nature", "Icon.People", "Icon.Science", "Theme", "Color", "Settings", "Locale", "Format" ]

        Basics ->
            [ "Button", "Menu", "Badge", "Tag", "Alert", "Spinner", "Skeleton", "EmptyState", "ErrorState", "TextInput", "Checkbox" ]

        Selects ->
            [ "Select", "MultiSelect", "Autocomplete" ]

        Tables ->
            [ "Table", "Budget", "Pagination", "VirtualList" ]

        Forms ->
            [ "TextArea", "NumberInput", "PasswordInput", "Radio", "CheckboxGroup", "Switch", "Slider", "SegmentedControl", "SearchInput", "TagInput", "FileDrop", "InlineEdit", "Form.Layout", "Field", "Validate", "Search" ]

        FormModel ->
            [ "Form", "Form.Spec", "Form.Check", "Ids" ]

        DateTime ->
            [ "Date", "DatePicker", "DateRangePicker", "TimePicker", "DateTimePicker", "Calendar" ]

        Overlays ->
            [ "Overlay", "Modal", "ConfirmDialog", "Drawer", "Toast", "Popover", "Tooltip", "ContextMenu", "CommandPalette", "ShortcutHelp" ]

        Navigation ->
            [ "AppShell", "SideNav", "PageHeader", "Breadcrumbs", "Tabs", "Accordion", "Toolbar", "DescriptionList", "Stepper" ]

        DataDisplay ->
            [ "Tree", "Timeline", "Stat", "Chart", "Avatar", "Progress", "ListItem", "JsonViewer" ]

        Rules ->
            [ "Rule", "RuleBuilder", "FilterBar", "SavedViews" ]

        Arranging ->
            [ "Sortable", "Splitter" ]

        Actions ->
            [ "Shortcut", "ButtonGroup", "ToggleGroup", "SplitButton", "Link", "Kbd" ]

        Flow ->
            [ "StatusPage", "BulkBar", "LeaveGuard", "History" ]

        Markdown ->
            [ "Markdown", "MarkdownEditor" ]

        Review ->
            [ "Diff", "Compare" ]

        Structured ->
            [ "MaskedInput", "Money", "MoneyInput" ]

        Picking ->
            [ "Picking", "TreeSelect", "Cascader", "Transfer" ]

        Access ->
            [ "PermissionMatrix", "ApprovalFlow" ]

        Recurring ->
            [ "Recurrence", "RecurrencePicker" ]

        StaleData ->
            [ "Remote", "RemoteView" ]

        ServerLists ->
            [ "ServerList" ]

        Examples ->
            [ "Inbox", "Edit form", "Confirm delete", "Dashboard", "Multi-step flow", "Command palette", "Review desk" ]

        Workbench ->
            [ "CardList", "WorkQueue", "ConflictResolver", "AuditLog", "NotificationCenter" ]

        NextComponents ->
            [ "Kanban", "CommentThread", "UploadQueue", "CodeBlock", "QuantityInput" ]

        Ai ->
            [ "AiReview", "AiChat" ]

        Processes ->
            [ "Workflow", "Workflow.Engine", "Workflow.Codec", "WorkflowNode", "WorkflowBuilder", "WorkflowRun", "StateMachine" ]


componentCount : Int
componentCount =
    List.length pages


{-| Every component has its own address. Sections remain as compatibility links.
-}
pages : List Section
pages =
    all |> List.filter ((/=) Examples) |> List.concatMap components |> List.map Component


owner : String -> Section
owner name =
    all |> List.filter (\section -> section /= Examples && List.member name (components section)) |> List.head |> Maybe.withDefault Foundations


group : Section -> Section
group section =
    case section of
        Component name ->
            owner name

        _ ->
            section


componentSlug : String -> String
componentSlug name =
    name
        |> String.toList
        |> List.indexedMap
            (\index char ->
                if char == '.' then
                    "-"

                else if Char.isUpper char && index > 0 && String.slice (index - 1) index name /= "." then
                    "-" ++ String.fromChar (Char.toLower char)

                else
                    String.fromChar (Char.toLower char)
            )
        |> String.concat
