# Klar.StatusPage

A page that stands for a whole result: "Order created", "No access", "Page not found", "Something went wrong on our side", "Down for maintenance".

Import: `import Klar.StatusPage as StatusPage` | Group: Pages and flow

Types: `Kind`, `Attribute`

## Signatures

```elm
-- View
view : List (Attribute msg) -> Kind -> Html msg

-- Kinds of pages
type Kind  -- opaque: no constructors are exposed
success : Kind
notFound : Kind
denied : Kind
sessionExpired : Kind
serverError : Kind
offline : Kind
maintenance : Kind
fromProblem : Remote.Problem -> Kind

-- Content
type Attribute msg  -- opaque: no constructors are exposed
title : String -> Attribute msg
description : String -> Attribute msg
icon : Icon.Icon -> Attribute msg
actions : List (Html msg) -> Attribute msg
reference : String -> Attribute msg
onRetry : msg -> Attribute msg

-- Structure and text
headingLevel : Int -> Attribute msg
standalone : Attribute msg
id : String -> Attribute msg
locale : Locale.Locale -> Attribute msg

-- Focus
focusTitle : String -> msg -> Cmd msg
```

## Documentation

A page that stands for a whole result: "Order created", "No access", "Page
not found", "Something went wrong on our side", "Down for maintenance".

Use when: the whole page is one result, such as not found, no access, a server error, maintenance or success after a submit.
Do not use when: the result sits inside a table, card or panel, use `Klar.EmptyState` or `Klar.ErrorState`.

    import Klar.Button as Button
    import Klar.Link as Link
    import Klar.StatusPage as StatusPage

    -- the router found nothing for the address
    StatusPage.view
        [ StatusPage.actions [ Button.view [ Button.primary, Button.href (Link.internal "#/orders") ] "Go to orders" ] ]
        StatusPage.notFound

    -- the data of the page failed to load: the page follows the kind of the problem
    case model.order of
        Failure problem ->
            StatusPage.view
                [ StatusPage.onRetry ReloadOrder
                , StatusPage.reference "req-7f3a-91c2"
                ]
                (StatusPage.fromProblem problem)

        _ ->
            viewOrder model

    -- a form was submitted and the result replaces it
    StatusPage.view
        [ StatusPage.title "Order 1042 created"
        , StatusPage.description "A confirmation was sent to ada@example.com."
        , StatusPage.actions [ Button.view [ Button.href (Link.internal "#/orders/1042") ] "Open the order" ]
        ]
        StatusPage.success

It is the whole-page version of [Klar.EmptyState](Klar.EmptyState.md) and
[Klar.ErrorState](Klar.ErrorState.md): use those inside a table, a card or a panel,
and this when the result is the page. The page is centered, with a large calm
title, a sentence under it and a row of actions that you give as buttons. The
kind of page (`notFound`, `denied`, `serverError` ...) chooses the icon, the color
and the built-in texts, in English and Norwegian Bokmål (see `locale`); `title`
and `description` replace them. The kinds are values of an opaque type, so that
more can be added later.

## Semantics

The title is the `h1` of the page. Use `headingLevel` when the page sits in a
layout that already has one (a panel under a page header, say). There is no
`role` and no live region: a page that appears when the user navigates is
content, announced by the navigation itself (the application moves focus to the
content, see `AppShell.focusContent`, and changes the document title), and
`role="alert"` would interrupt a screen reader in the middle of a sentence for
something the user asked for. A live region that
is inserted together with its text is also announced by too few screen readers
to rely on.

When the page replaces what the user was looking at without a navigation (the
form that was just submitted, a list that failed to load), the focused button is
gone with it and focus falls to the page body, so nothing is read. Give the page an
`id` and, in the same `update` that shows it, call `focusTitle` with the same text:
the title takes focus and the screen reader reads the result. Keep the text in one
place, a value of your own, so that the two cannot differ; `focusTitle` does nothing
when no element has the id.

    orderCreated : String
    orderCreated =
        "order-created"

    StatusPage.view [ StatusPage.id orderCreated ] StatusPage.success

    StatusPage.focusTitle orderCreated NoOp

The page fills the height of the region it is in (the content of an `AppShell`, a
panel with a height) without making it scroll, and grows when its content needs
more room. A page that stands on its own, with no shell around it, is `standalone`:
it is as tall as the window and is the `main` landmark.

A `reference` is a correlation id that support can find in a log. Copying to the
clipboard needs JavaScript, so the reference is a monospace line that one click
selects completely (`user-select: all`); then `Ctrl C` copies it.

## View

### `view`

```elm
view : List (Attribute msg) -> Kind -> Html msg
```

The page: an icon, the title, a sentence, the actions and the reference,
centered in the region.

    StatusPage.view [ StatusPage.actions [ homeButton ] ] StatusPage.denied

## Kinds of pages

### `Kind`

```elm
type Kind  -- opaque: no constructors are exposed
```

What the page is about. Make one with `success`, `notFound`, `denied`,
`sessionExpired`, `serverError`, `offline`, `maintenance` or, for a failed
request, `fromProblem`, and give it to `view`. The type is opaque, so that new
kinds can be added without breaking anyone.

### `success`

```elm
success : Kind
```

The action went through: "Order created". A green check, the title "Done" and
a short sentence; you will usually set your own `title` and `description`.

### `notFound`

```elm
notFound : Kind
```

The address matches nothing (404): "Page not found". A search icon in a
quiet gray. For a single record that is missing, use `fromProblem` with
`Remote.notFound` so that the texts of the problem are used.

### `denied`

```elm
denied : Kind
```

The user may not see this (403): "No access", and the advice to contact an
administrator. A lock in a quiet gray. It is `fromProblem` for a
`Remote.forbidden` problem.

### `sessionExpired`

```elm
sessionExpired : Kind
```

The user has to sign in again (401): "Please sign in again". It is
`fromProblem` for a `Remote.unauthorized` problem. Give it a sign-in button
as an action.

### `serverError`

```elm
serverError : Kind
```

The server failed (500): "Something went wrong on our side", in red. It is
`fromProblem` for a `Remote.server` problem, and worth trying again (`onRetry`).

### `offline`

```elm
offline : Kind
```

There is no contact with the server: "Can't reach the service". It is
`fromProblem` for a `Remote.network` problem, and worth trying again
(`onRetry`).

### `maintenance`

```elm
maintenance : Kind
```

The service is down on purpose: "Down for maintenance", with a wrench. Worth
trying again (`onRetry`) in a few minutes.

### `fromProblem`

```elm
fromProblem : Remote.Problem -> Kind
```

The page for a failed request. The icon and the color follow the kind of the
problem (see [`Remote.Kind`](Klar.Remote.md#kind)); the title, the explanation and
the code are the problem's own, which are the ready-made texts for its kind in
the language of the page unless you changed them with `Remote.withTitle` and
friends. The code, when the problem has one, is shown with the reference.
`onRetry` adds a "Try again" button for problems worth trying again.

    StatusPage.fromProblem (Remote.problem Remote.notFound |> Remote.withTitle "Order not found")

## Content

### `Attribute`

```elm
type Attribute msg  -- opaque: no constructors are exposed
```

A setting of a status page. Make them with the functions below and pass a
list to `view`; later attributes win over earlier ones.

### `title`

```elm
title : String -> Attribute msg
```

The large title, replacing the one of the kind. A blank title leaves out the
heading altogether, so then another element of the page must be its `h1`.

### `description`

```elm
description : String -> Attribute msg
```

The sentence under the title, replacing the one of the kind. A blank text
leaves it out.

### `icon`

```elm
icon : Icon.Icon -> Attribute msg
```

Another icon than the one of the kind, for example `Icon.package` on a
success page that is about a shipment. The color still follows the kind.

### `actions`

```elm
actions : List (Html msg) -> Attribute msg
```

The row of actions under the text: buttons or links, in the order you give
them, the most important first. There are none by default. A page nearly always
needs one, so that the user is never left in a dead end.

    StatusPage.actions
        [ Button.view [ Button.primary, Button.href (Link.internal "#/orders") ] "Go to orders"
        , Button.view [ Button.href (Link.internal "#/") ] "Home"
        ]

### `reference`

```elm
reference : String -> Attribute msg
```

A correlation id for support, such as the id of the failed request, shown
small under the actions as "Reference: req-7f3a-91c2". The text is selected
completely by one click, so that `Ctrl C` copies it (a button that copies needs
JavaScript). There is none by default, and a blank one is left out, like a blank
title.

### `onRetry`

```elm
onRetry : msg -> Attribute msg
```

The message sent by a "Try again" button, placed before your own actions. The
button is there only when trying again can help: for `serverError`, `offline`,
`maintenance` and a `fromProblem` page whose problem is worth retrying
(`Remote.isRetryable`), and never for the others. Without `onRetry` there is no
button.

## Structure and text

### `headingLevel`

```elm
headingLevel : Int -> Attribute msg
```

The level of the title element, from 1 to 6. The default is 1, because the
page is normally the whole page. Use another level when the page sits inside a
layout that already has an `h1`. A number outside the range counts as the nearest
level. The level changes the element, not the look.

### `standalone`

```elm
standalone : Attribute msg
```

The page stands on its own, with no `AppShell` around it: it is at least as
tall as the window and it is the `main` landmark of the document. Without it the
page fills the region it is placed in and is an ordinary `div`.

### `id`

```elm
id : String -> Attribute msg
```

The DOM id of the element that `focusTitle` moves focus to, which must be unique
on the page: the title, which becomes focusable, or the whole page when it has no
title (a blank `title`), so that there is always something to focus. Give `focusTitle`
the same text. There is no id by default, and without one `focusTitle` finds nothing
and does nothing.

### `locale`

```elm
locale : Locale.Locale -> Attribute msg
```

The language of the built-in text: the texts of the kinds, "Try again" and
the label of the reference. The default is [`Locale.default`](Klar.Locale.md#default),
which is English. The title and the explanation of a `fromProblem` page come from
the problem, in this language.

## Focus

### `focusTitle`

```elm
focusTitle : String -> msg -> Cmd msg
```

Moves focus to the title of the page that has this `id` (the page itself when it
has no title; see the attribute `id`). Pass the same text as to `id`: if no element
has it, nothing happens. Call it in the same `update` that starts to show the page,
when the page replaces what the user was working with. The message is sent when it is
done, whether it worked or not.

    StatusPage.focusTitle "order-created" NoOp
