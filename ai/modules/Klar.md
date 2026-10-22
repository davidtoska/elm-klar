# Klar

Klar (Norwegian for "clear" and "ready") is a toolkit of interface components for data-intensive applications.

Import: `import Klar` | Group: Start here

## Signatures

```elm
-- The stylesheet
stylesheet : Html msg
css : String
```

## Documentation

**Klar** (Norwegian for "clear" and "ready") is a toolkit of interface
components for data-intensive applications: tables with thousands of rows,
searchable lists with thousands of options, filters, rules, dates, forms, dialogs.
It is calm, small-typed and exact, and it never leaves the user wondering what
state the data is in. It is plain Elm and plain CSS: besides the official `elm/*`
packages it needs nothing, and it has no ports and no JavaScript.

Use when: you start any application with Klar, to put its stylesheet on the page once.
Do not use when: you look for a component, each of which has its own module (`Klar.Button`, `Klar.Table`); this module holds only the stylesheet.
Quick path: `stylesheet`

## Start here

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

Build a whole application from the parts: [Klar.AppShell](Klar.AppShell.md) is the
frame (top bar, side navigation, scrolling content), [Klar.PageHeader](Klar.PageHeader.md)
the top of a page, [Klar.Table](Klar.Table.md) the list of records,
[Klar.Drawer](Klar.Drawer.md) and [Klar.Form](Klar.Form.md) their editor.

## How the components work

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

    -- PageIds.elm (or a record at the top of the page module)
    country : String
    country =
        "order-country"

    Select.init PageIds.country

A page that can be on screen twice (two drawers with the same form) needs a
different prefix for each. A text field that is given no `id` takes one from its
`label` (`Customer` becomes `klar-input-customer`), so two fields with the same
label on one page need an `id` each. A column of a [Klar.Table](Klar.Table.md) is
named with `Table.columnId`, and the same advice holds: name it once.

**Data from a backend.** Components that show data take a [Klar.Remote](Klar.Remote.md)
(`NotAsked | Loading | Loaded a | Failed Problem`) and draw the loading skeleton, the failure
with a retry button and the empty state themselves. A screen is correct in every
state without you writing the four cases every time. Data you already have stays on
the screen while it is refreshed (`Remote.refresh`), and when a refresh fails it is
marked "Old data from 14:05" with a retry (`Remote.refreshWith`), in every data
component. The body of a card, dialog or drawer does the same with
[Klar.RemoteView](Klar.RemoteView.md).

**Forms.** Every input accepts the same field attributes (`label`, `hint`, `error`,
`required` ...) and wraps itself in a [Klar.Field](Klar.Field.md). Validators in
[Klar.Validate](Klar.Validate.md) are plain functions. [Klar.Form](Klar.Form.md) holds a whole
form in one state (declared once with [Klar.Form.Spec](Klar.Form.Spec.md)): the values, the
rows of a repeating group, the step, what the server refused and whether anything changed.
[Klar.Form.Layout](Klar.Form.Layout.md) lays out sections, shows an error summary and the state
of the submit, for a form you wire by hand.

**Language.** Built-in text (placeholders, labels read by screen readers, month
names) is English by default and Norwegian Bokmål with `locale Locale.nb`; see
[Klar.Locale](Klar.Locale.md). Your own text always comes from your application.

**Honest with input.** Nothing changes what the user typed behind their back. A
number outside its range stays in the field with an error; only an explicit action
moves it into range.

**Accessible by design.** Keyboard support and ARIA roles, properties and live
regions are built into every component, and focus never ends up nowhere after an
action. Where a component needs your help (a name for an icon-only button, an `id`
for a field) the documentation says so.

## Styling

The look is made of design tokens: CSS custom properties such as `--klar-primary`
and `--klar-space-3` that components use instead of fixed colors and sizes. Define
them again after Klar's CSS to restyle everything at once; they are listed in
[Klar.Theme](Klar.Theme.md), which also holds the vocabulary components share
(`Tone`, `Size`, `Density`).

## The modules

  - **Foundations**: [Klar.Theme](Klar.Theme.md), [Klar.Locale](Klar.Locale.md),
    [Klar.Layout](Klar.Layout.md), [Klar.Card](Klar.Card.md), [Klar.Text](Klar.Text.md),
    [Klar.Icon](Klar.Icon.md)
  - **Actions**: [Klar.Button](Klar.Button.md), [Klar.Menu](Klar.Menu.md),
    [Klar.ButtonGroup](Klar.ButtonGroup.md), [Klar.ToggleGroup](Klar.ToggleGroup.md),
    [Klar.SplitButton](Klar.SplitButton.md), [Klar.Link](Klar.Link.md), [Klar.Kbd](Klar.Kbd.md)
  - **Status and feedback**: [Klar.Badge](Klar.Badge.md), [Klar.Tag](Klar.Tag.md),
    [Klar.Alert](Klar.Alert.md), [Klar.Spinner](Klar.Spinner.md),
    [Klar.Skeleton](Klar.Skeleton.md), [Klar.Progress](Klar.Progress.md),
    [Klar.EmptyState](Klar.EmptyState.md), [Klar.ErrorState](Klar.ErrorState.md)
  - **Forms and inputs**: [Klar.Form](Klar.Form.md), [Klar.Form.Spec](Klar.Form.Spec.md),
    [Klar.Form.Layout](Klar.Form.Layout.md), [Klar.Form.Check](Klar.Form.Check.md),
    [Klar.Ids](Klar.Ids.md), [Klar.Field](Klar.Field.md),
    [Klar.Validate](Klar.Validate.md), [Klar.TextInput](Klar.TextInput.md),
    [Klar.TextArea](Klar.TextArea.md), [Klar.NumberInput](Klar.NumberInput.md),
    [Klar.PasswordInput](Klar.PasswordInput.md), [Klar.SearchInput](Klar.SearchInput.md),
    [Klar.TagInput](Klar.TagInput.md), [Klar.FileDrop](Klar.FileDrop.md),
    [Klar.InlineEdit](Klar.InlineEdit.md), [Klar.Checkbox](Klar.Checkbox.md),
    [Klar.CheckboxGroup](Klar.CheckboxGroup.md), [Klar.Radio](Klar.Radio.md),
    [Klar.Switch](Klar.Switch.md), [Klar.Slider](Klar.Slider.md),
    [Klar.SegmentedControl](Klar.SegmentedControl.md),
    [Klar.MaskedInput](Klar.MaskedInput.md), [Klar.Money](Klar.Money.md),
    [Klar.MoneyInput](Klar.MoneyInput.md)
  - **Choosing**: [Klar.Select](Klar.Select.md), [Klar.MultiSelect](Klar.MultiSelect.md),
    [Klar.Autocomplete](Klar.Autocomplete.md), [Klar.VirtualList](Klar.VirtualList.md),
    [Klar.TreeSelect](Klar.TreeSelect.md), [Klar.Cascader](Klar.Cascader.md),
    [Klar.Transfer](Klar.Transfer.md), [Klar.Picking](Klar.Picking.md)
  - **Date and time**: [Klar.Date](Klar.Date.md), [Klar.DatePicker](Klar.DatePicker.md),
    [Klar.DateRangePicker](Klar.DateRangePicker.md), [Klar.TimePicker](Klar.TimePicker.md),
    [Klar.DateTimePicker](Klar.DateTimePicker.md), [Klar.Calendar](Klar.Calendar.md),
    [Klar.Recurrence](Klar.Recurrence.md), [Klar.RecurrencePicker](Klar.RecurrencePicker.md)
  - **Tables and lists**: [Klar.Table](Klar.Table.md),
    [Klar.Pagination](Klar.Pagination.md), [Klar.ListItem](Klar.ListItem.md),
    [Klar.Tree](Klar.Tree.md)
  - **Overlays**: [Klar.Modal](Klar.Modal.md), [Klar.ConfirmDialog](Klar.ConfirmDialog.md),
    [Klar.Drawer](Klar.Drawer.md), [Klar.Toast](Klar.Toast.md),
    [Klar.Popover](Klar.Popover.md), [Klar.Tooltip](Klar.Tooltip.md),
    [Klar.ContextMenu](Klar.ContextMenu.md),
    [Klar.CommandPalette](Klar.CommandPalette.md),
    [Klar.ShortcutHelp](Klar.ShortcutHelp.md)
  - **Navigation and structure**: [Klar.AppShell](Klar.AppShell.md),
    [Klar.SideNav](Klar.SideNav.md), [Klar.PageHeader](Klar.PageHeader.md),
    [Klar.Breadcrumbs](Klar.Breadcrumbs.md), [Klar.Tabs](Klar.Tabs.md),
    [Klar.Stepper](Klar.Stepper.md), [Klar.Accordion](Klar.Accordion.md),
    [Klar.Toolbar](Klar.Toolbar.md), [Klar.DescriptionList](Klar.DescriptionList.md)
  - **Arranging**: [Klar.Sortable](Klar.Sortable.md), [Klar.Splitter](Klar.Splitter.md)
  - **Pages and flow**: [Klar.StatusPage](Klar.StatusPage.md), [Klar.BulkBar](Klar.BulkBar.md),
    [Klar.LeaveGuard](Klar.LeaveGuard.md), [Klar.History](Klar.History.md)
  - **Text and change**: [Klar.Markdown](Klar.Markdown.md),
    [Klar.MarkdownEditor](Klar.MarkdownEditor.md), [Klar.Diff](Klar.Diff.md),
    [Klar.Compare](Klar.Compare.md)
  - **Access and approval**: [Klar.PermissionMatrix](Klar.PermissionMatrix.md),
    [Klar.ApprovalFlow](Klar.ApprovalFlow.md)
  - **Data display**: [Klar.Stat](Klar.Stat.md), [Klar.Chart](Klar.Chart.md),
    [Klar.Timeline](Klar.Timeline.md), [Klar.Avatar](Klar.Avatar.md),
    [Klar.JsonViewer](Klar.JsonViewer.md)
  - **Rules and filters**: [Klar.Rule](Klar.Rule.md),
    [Klar.RuleBuilder](Klar.RuleBuilder.md), [Klar.FilterBar](Klar.FilterBar.md),
    [Klar.SavedViews](Klar.SavedViews.md)
  - **Data and utilities**: [Klar.Remote](Klar.Remote.md), [Klar.RemoteView](Klar.RemoteView.md),
    [Klar.Search](Klar.Search.md),
    [Klar.Format](Klar.Format.md), [Klar.Shortcut](Klar.Shortcut.md)

## The stylesheet

### `stylesheet`

```elm
stylesheet : Html msg
```

The stylesheet of the package as an element: render it once, anywhere in your
view (`Browser.document` and `Browser.application` put it in the body). It is a
constant, so Elm skips it when it compares two renderings of the view.

    Browser.document
        { title = "Orders"
        , body = [ Klar.stylesheet, viewPage model ]
        }

### `css`

```elm
css : String
```

The same rules as text. Use it where the ready-made element does not fit: to
give the `<style>` element a `nonce` of your own, or to put the rules into a shadow
root.

    Html.node "style" [ Html.Attributes.attribute "nonce" model.nonce ] [ Html.text Klar.css ]
