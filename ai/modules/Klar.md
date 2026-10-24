# Klar

Klar (Norwegian for "clear" and "ready") is a toolkit of interface components for data-intensive applications.

Import: `import Klar` | Group: Start here

## Signatures

```elm
-- The stylesheet
stylesheet : Html msg
stylesheetFor : Settings.Settings -> Html msg
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

That is all the setup there is (with a theme of your choice it is `stylesheetFor`, see
"Styling"). The stylesheet is part of the package, so there is
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
overrides (state flags such as `loading`, `failed` and `remote` add up instead).

**Components with state.** A component that has a state of its own (a select that is
open, a table that is sorted, a date field with half-typed text) comes with `State`,
`Msg`, `update` and `view`, and is wired like any child in the Elm Architecture. The
state holds the value too (`PasswordInput` is the exception: the application keeps the
text); read it with a function and compare before and after
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
(`NotAsked | Loading | Loaded a | Failed Problem | Kept (Kept a)`) and draw the loading skeleton,
the failure with a retry button and the empty state themselves. A screen is correct in every
state without you writing the five cases every time. Data you already have stays on
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

The look is one of ten themes, each with a light and a dark mode, chosen in a
[Klar.Settings](Klar.Settings.md) and drawn by `stylesheetFor` in place of `stylesheet`:

    Klar.stylesheetFor (Settings.default |> Settings.withTheme Theme.ocean |> Settings.withMode Theme.System)

An application writes no CSS of its own. The design tokens (CSS custom properties such as
`--klar-primary`) are listed in [Klar.Theme](Klar.Theme.md) as a reference, with the vocabulary
components share (`Tone`, `Size`, `Density`).

## The modules

The modules are listed by group in the package's `elm.json` and on its page on
package.elm-lang.org, in the same order.

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

### `stylesheetFor`

```elm
stylesheetFor : Settings.Settings -> Html msg
```

The stylesheet with the theme and the mode of the settings: the same element
as `stylesheet` and, after it, the colors of the theme. Use this one when the
application chooses a theme or lets the person choose light or dark.

    Klar.stylesheetFor model.settings

With the default settings it draws exactly what `stylesheet` does.

### `css`

```elm
css : String
```

The same rules as text. Use it where the ready-made element does not fit: to
give the `<style>` element a `nonce` of your own, or to put the rules into a shadow
root.

    Html.node "style" [ Html.Attributes.attribute "nonce" model.nonce ] [ Html.text Klar.css ]
