module Klar exposing (stylesheet, css)

{-| **Klar** (Norwegian for "clear" and "ready") is a toolkit of interface
components for data-intensive applications: tables with thousands of rows,
searchable lists with thousands of options, filters, rules, dates, forms, dialogs.
It is calm, small-typed and exact, and it never leaves the user wondering what
state the data is in. It is plain Elm and plain CSS: besides the official `elm/*`
packages it needs nothing, and it has no ports and no JavaScript.


# Start here

Install the package, then render the stylesheet once, anywhere in your view:

    import Html exposing (Html)
    import Klar
    import Klar.Button as Button

    view : Model -> Html Msg
    view model =
        Html.div []
            [ Klar.stylesheet
            , Button.view [ Button.primary, Button.onClick Save ] "Save"
            ]

That is all the setup there is. The stylesheet is part of the package, so there is
nothing to link and nothing to bundle. It brings a small reset (box sizing, the page
font and background, links, tables, focus rings) and every rule of every component,
so Klar assumes that it owns the page. If your content security policy forbids inline
styles, copy `css/klar.css` from the package repository into your static files, link
it from your page, and leave `stylesheet` out. (A `nonce` of your own can go on the
element made from `css`.)

Build a whole application from the parts: [Klar.AppShell](Klar-AppShell) is the
frame (top bar, side navigation, scrolling content), [Klar.PageHeader](Klar-PageHeader)
the top of a page, [Klar.Table](Klar-Table) the list of records,
[Klar.Drawer](Klar-Drawer) and [Klar.Form](Klar-Form) their editor.


# How the components work

**Attributes.** A component is drawn by a function that takes a list of attributes,
like `Html`, and what it must have:

    Button.view [ Button.primary, Button.icon Icon.save, Button.onClick Save ] "Save"

    Badge.view [ Badge.tone Success ] "Shipped"

The attributes are values of an opaque type that belongs to the module. Later
attributes win over earlier ones, so a list can be built from defaults and
overrides.

**Components with state.** A component that has a state of its own (a select that is
open, a table that is sorted, a date field with half-typed text) comes with `State`,
`Msg`, `update` and `view`, and is wired like any child in the Elm Architecture. The
state holds the value too; read it with a function and compare before and after
`update` to react to a change. There are no out-messages. Clicks and other things
that are not changes of the state are plain messages of your own:

    -- model
    { country : Select.State CountryCode } -- Select.init "country"

    -- update
    CountryMsg m ->
        let
            ( country, cmd ) =
                Select.update m model.country
        in
        ( { model | country = country }, Cmd.map CountryMsg cmd )

    -- view
    Select.view CountryMsg
        [ Select.label "Country", Select.options countries ]
        model.country

    -- reading the value
    Select.value model.country -- Maybe CountryCode, the id of the chosen option

**Ids.** The `String` given to `init` is the DOM id of the component and must be
unique on the page: labels, error messages and focus management are built on it,
and the ids inside the component are derived from it (`country-search`,
`country-listbox`). Two components with the same id on one page silently point at
each other's elements, and Elm cannot check that for you. Keep the ids in one
place, as values with a name, so that a page cannot use one twice by accident:

    -- Ids.elm (or a record at the top of the page module)
    country : String
    country =
        "order-country"

    Select.init Ids.country

A page that can be on screen twice (two drawers with the same form) needs a
different prefix for each. A text field that is given no `id` takes one from its
`label` (`Customer` becomes `klar-input-customer`), so two fields with the same
label on one page need an `id` each. A column of a [Klar.Table](Klar-Table) is
named with `Table.columnId`, and the same advice holds: name it once.

**Data from a backend.** Components that show data take a [Klar.Remote](Klar-Remote)
(`NotAsked | Loading | Failure | Success`) and draw the loading skeleton, the failure
with a retry button and the empty state themselves. A screen is correct in every
state without you writing the four cases every time.

**Forms.** Every input accepts the same field attributes (`label`, `hint`, `error`,
`required` ...) and wraps itself in a [Klar.Field](Klar-Field). Validators in
[Klar.Validate](Klar-Validate) are plain functions; [Klar.Form](Klar-Form) lays out
sections, shows an error summary and the state of the submit.

**Language.** Built-in text (placeholders, labels read by screen readers, month
names) is English by default and Norwegian Bokmål with `locale Locale.nb`; see
[Klar.Locale](Klar-Locale). Your own text always comes from your application.

**Honest with input.** Nothing changes what the user typed behind their back. A
number outside its range stays in the field with an error; only an explicit action
moves it into range.

**Accessible by design.** Keyboard support and ARIA roles, properties and live
regions are built into every component, and focus never ends up nowhere after an
action. Where a component needs your help (a name for an icon-only button, an `id`
for a field) the documentation says so.


# Styling

The look is made of design tokens: CSS custom properties such as `--klar-primary`
and `--klar-space-3` that components use instead of fixed colors and sizes. Define
them again after Klar's CSS to restyle everything at once; they are listed in
[Klar.Theme](Klar-Theme), which also holds the vocabulary components share
(`Tone`, `Size`, `Density`).


# The modules

  - **Foundations**: [Klar.Theme](Klar-Theme), [Klar.Locale](Klar-Locale),
    [Klar.Layout](Klar-Layout), [Klar.Card](Klar-Card), [Klar.Text](Klar-Text),
    [Klar.Icon](Klar-Icon)
  - **Actions**: [Klar.Button](Klar-Button), [Klar.Menu](Klar-Menu),
    [Klar.ButtonGroup](Klar-ButtonGroup), [Klar.ToggleGroup](Klar-ToggleGroup),
    [Klar.SplitButton](Klar-SplitButton), [Klar.Link](Klar-Link), [Klar.Kbd](Klar-Kbd)
  - **Status and feedback**: [Klar.Badge](Klar-Badge), [Klar.Tag](Klar-Tag),
    [Klar.Alert](Klar-Alert), [Klar.Spinner](Klar-Spinner),
    [Klar.Skeleton](Klar-Skeleton), [Klar.Progress](Klar-Progress),
    [Klar.EmptyState](Klar-EmptyState), [Klar.ErrorState](Klar-ErrorState)
  - **Forms and inputs**: [Klar.Form](Klar-Form), [Klar.Field](Klar-Field),
    [Klar.Validate](Klar-Validate), [Klar.TextInput](Klar-TextInput),
    [Klar.TextArea](Klar-TextArea), [Klar.NumberInput](Klar-NumberInput),
    [Klar.PasswordInput](Klar-PasswordInput), [Klar.SearchInput](Klar-SearchInput),
    [Klar.TagInput](Klar-TagInput), [Klar.FileDrop](Klar-FileDrop),
    [Klar.InlineEdit](Klar-InlineEdit), [Klar.Checkbox](Klar-Checkbox),
    [Klar.CheckboxGroup](Klar-CheckboxGroup), [Klar.Radio](Klar-Radio),
    [Klar.Switch](Klar-Switch), [Klar.Slider](Klar-Slider),
    [Klar.SegmentedControl](Klar-SegmentedControl),
    [Klar.MaskedInput](Klar-MaskedInput), [Klar.Money](Klar-Money),
    [Klar.MoneyInput](Klar-MoneyInput)
  - **Choosing**: [Klar.Select](Klar-Select), [Klar.MultiSelect](Klar-MultiSelect),
    [Klar.Autocomplete](Klar-Autocomplete), [Klar.VirtualList](Klar-VirtualList),
    [Klar.TreeSelect](Klar-TreeSelect), [Klar.Cascader](Klar-Cascader),
    [Klar.Transfer](Klar-Transfer), [Klar.Picking](Klar-Picking)
  - **Date and time**: [Klar.Date](Klar-Date), [Klar.DatePicker](Klar-DatePicker),
    [Klar.DateRangePicker](Klar-DateRangePicker), [Klar.TimePicker](Klar-TimePicker),
    [Klar.DateTimePicker](Klar-DateTimePicker), [Klar.Calendar](Klar-Calendar),
    [Klar.Recurrence](Klar-Recurrence), [Klar.RecurrencePicker](Klar-RecurrencePicker)
  - **Tables and lists**: [Klar.Table](Klar-Table),
    [Klar.Pagination](Klar-Pagination), [Klar.ListItem](Klar-ListItem),
    [Klar.Tree](Klar-Tree)
  - **Overlays**: [Klar.Modal](Klar-Modal), [Klar.ConfirmDialog](Klar-ConfirmDialog),
    [Klar.Drawer](Klar-Drawer), [Klar.Toast](Klar-Toast),
    [Klar.Popover](Klar-Popover), [Klar.Tooltip](Klar-Tooltip),
    [Klar.ContextMenu](Klar-ContextMenu),
    [Klar.CommandPalette](Klar-CommandPalette),
    [Klar.ShortcutHelp](Klar-ShortcutHelp)
  - **Navigation and structure**: [Klar.AppShell](Klar-AppShell),
    [Klar.SideNav](Klar-SideNav), [Klar.PageHeader](Klar-PageHeader),
    [Klar.Breadcrumbs](Klar-Breadcrumbs), [Klar.Tabs](Klar-Tabs),
    [Klar.Stepper](Klar-Stepper), [Klar.Accordion](Klar-Accordion),
    [Klar.Toolbar](Klar-Toolbar), [Klar.DescriptionList](Klar-DescriptionList)
  - **Arranging**: [Klar.Sortable](Klar-Sortable), [Klar.Splitter](Klar-Splitter)
  - **Pages and flow**: [Klar.StatusPage](Klar-StatusPage), [Klar.BulkBar](Klar-BulkBar),
    [Klar.LeaveGuard](Klar-LeaveGuard), [Klar.History](Klar-History)
  - **Text and change**: [Klar.Markdown](Klar-Markdown),
    [Klar.MarkdownEditor](Klar-MarkdownEditor), [Klar.Diff](Klar-Diff),
    [Klar.Compare](Klar-Compare)
  - **Access and approval**: [Klar.PermissionMatrix](Klar-PermissionMatrix),
    [Klar.ApprovalFlow](Klar-ApprovalFlow)
  - **Data display**: [Klar.Stat](Klar-Stat), [Klar.Chart](Klar-Chart),
    [Klar.Timeline](Klar-Timeline), [Klar.Avatar](Klar-Avatar),
    [Klar.JsonViewer](Klar-JsonViewer)
  - **Rules and filters**: [Klar.Rule](Klar-Rule),
    [Klar.RuleBuilder](Klar-RuleBuilder), [Klar.FilterBar](Klar-FilterBar),
    [Klar.SavedViews](Klar-SavedViews)
  - **Data and utilities**: [Klar.Remote](Klar-Remote), [Klar.Search](Klar-Search),
    [Klar.Format](Klar-Format), [Klar.Shortcut](Klar-Shortcut)


# The stylesheet

@docs stylesheet, css

-}

import Html exposing (Html)
import Klar.Internal.Css as Css


{-| The stylesheet of the package as an element: render it once, anywhere in your
view (`Browser.document` and `Browser.application` put it in the body). It is a
constant, so Elm skips it when it compares two renderings of the view.

    Browser.document
        { title = "Orders"
        , body = [ Klar.stylesheet, viewPage model ]
        }

-}
stylesheet : Html msg
stylesheet =
    Html.node "style" [] [ Html.text Css.css ]


{-| The same rules as text. Use it where the ready-made element does not fit: to
give the `<style>` element a `nonce` of your own, or to put the rules into a shadow
root.

    Html.node "style" [ Html.Attributes.attribute "nonce" model.nonce ] [ Html.text Klar.css ]

-}
css : String
css =
    Css.css
