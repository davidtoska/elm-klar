# Klar.Link

A real link (`<a href>`) that cannot be built wrong: for a page of the application, for another site, for an email address or a telephone number.

Import: `import Klar.Link as Link` | Group: Actions

Types: `Target`, `Attribute`

## Signatures

```elm
-- View
view : List (Attribute msg) -> Target -> String -> Html msg

-- Destinations
type Target  -- opaque: no constructors are exposed
internal : String -> Target
external : String -> Maybe Target

-- Attributes
type Attribute msg  -- opaque: no constructors are exposed
current : Bool -> Attribute msg
disabled : Bool -> Attribute msg
inline : Attribute msg
standalone : Attribute msg
truncate : Attribute msg
icon : Icon.Icon -> Attribute msg
id : String -> Attribute msg
onClick : msg -> Attribute msg
locale : Locale.Locale -> Attribute msg
```

## Documentation

A real link (`<a href>`) that cannot be built wrong: for a page of the
application, for another site, for an email address or a telephone number.

    import Klar.Link as Link

    -- inside the application: the string comes from your own route function
    Link.view [] (Link.internal (Route.toPath (Route.Order orderId))) "Order 10001"

    -- another site: the address is data, so it may be wrong
    case Link.external customer.website of
        Just target ->
            Link.view [] target "Website"

        Nothing ->
            Html.text customer.website

    Link.view [ Link.current (model.route == Route.Orders) ] (Link.internal "/orders") "Orders"

**The destination is a `Target`**, made by `internal` or `external`, and no
other string ever becomes an `href`. `external` accepts only `http`, `https`,
`mailto` and `tel` and answers `Nothing` for anything else, so a `javascript:`
address from a database cannot be turned into a link. `internal` takes an
address in your own application (`"/orders/12"`, or `"#/orders/12"` for a
program with routes in the fragment) and keeps it there: whatever the text, the
link cannot lead to another site.

**A link to another site** (`http` or `https`) opens in a new tab, so the user
does not lose the page that they work on. It is marked with an arrow icon and
with the text "(opens in a new tab)" for screen readers, and it has
`target="_blank"` and `rel="noopener noreferrer"`. A link to a page of the
application, a `mailto:` and a `tel:` link open in the same tab and are not
marked, and have no `target`.

**In a program made with `Browser.application`**, Elm reports every click on a
link to `onUrlRequest`, with `Internal` for the pages of the application and
`External` for the others. Handle them there; the link needs nothing else:

    UrlRequested (Browser.Internal url) ->
        ( model, Nav.pushUrl model.key (Url.toString url) )

    UrlRequested (Browser.External href) ->
        ( model, Nav.load href )

Links that open in a new tab (`target`) are left to the browser, and the clicks
that the browser handles itself (Ctrl or Cmd for a new tab, Shift for a new
window, the middle button) are never taken over. Because every `<a href>` reaches
`onUrlRequest`, use a [Klar.Button](Klar.Button.md) for anything that is not a
navigation (an action, a skip link, an error-summary entry).

**Disabled and current.** A `disabled` link has no `href` and is not in the tab
order: it is drawn dimmed and a screen reader finds it as a link that is
unavailable (`aria-disabled`), the way it finds a disabled button. Use it for a
destination that exists but that the user may not visit, and say why in a
[Klar.Tooltip](Klar.Tooltip.md) around it. A link to the page that the user is on is
`current` (`aria-current="page"`).

**Inline or standalone.** The default is `inline`: underlined and in the link
color, a different color once visited, for a link inside a sentence. A link
that stands on its own (a cell in a table, an item of a list, a line of a menu)
is `standalone`: no underline until the pointer is over it, and no visited
color. `truncate` keeps the text on one line and ends it with an ellipsis when
the link is wider than the room it has; the whole text is the native tooltip.

The built-in text ("opens in a new tab") follows `locale` (English by default).

## View

### `view`

```elm
view : List (Attribute msg) -> Target -> String -> Html msg
```

A link to the target, with this text. The text names the link for screen
readers, so make it say where the link leads ("Order 10001"), not "click here".

    Link.view [ Link.standalone ] (Link.internal "/orders/10001") "Order 10001"

## Destinations

### `Target`

```elm
type Target  -- opaque: no constructors are exposed
```

Where a link leads. Make one with `internal` or `external`; the type is
opaque, so it always holds an address that has been checked.

### `internal`

```elm
internal : String -> Target
```

A page of your application, given as a path (`"/orders/12"`), as a route in
the fragment (`"#/orders/12"`) or as a query (`"?page=2"`): the text that your own
route function makes. The link stays in the application, whatever the text:
a text that does not begin with `/`, `#` or `?` gets a `/` in front, several
leading slashes become one, and control characters are removed, so `"//evil.example"`
and `"javascript:alert(1)"` become paths of your application (`"/evil.example"`,
`"/javascript:alert(1)"`) that do not exist, and never a link that leaves it.

### `external`

```elm
external : String -> Maybe Target
```

An address that is not in your application, or `Nothing` when it cannot be a
link: only `http://` and `https://` addresses with a host, `mailto:` with an
email address and `tel:` with a number are accepted, in any case, and the text
is trimmed. Anything else, a `javascript:` or `data:` address among them, a text
with a space or a control character in it, and the empty text, give `Nothing`.
Decide what to show then, usually the plain text.

    Link.external "https://example.com/docs" -- Just ...

    Link.external "mailto:ada@example.com" -- Just ...

    Link.external "javascript:alert(1)" -- Nothing

## Attributes

### `Attribute`

```elm
type Attribute msg  -- opaque: no constructors are exposed
```

A setting of a link. Make them with the functions below and pass a list to
`view`; later attributes win over earlier ones.

### `current`

```elm
current : Bool -> Attribute msg
```

Says that the link leads to the page that the user is on (`aria-current="page"`
for screen readers; the text is a little heavier and not underlined). Give it a
comparison from your model, so it follows the route:

    Link.current (model.route == Route.Orders)

The default is `False`.

### `disabled`

```elm
disabled : Bool -> Attribute msg
```

A destination the user may not visit now. The link has no `href`, cannot be
reached with Tab or clicked, and screen readers find it as a link that is
unavailable (`aria-disabled`). It is drawn dimmed, and sends nothing. The default is
`False`.

### `inline`

```elm
inline : Attribute msg
```

A link in the middle of a sentence: in the link color, underlined (so it is
not told apart by color alone), and in another color once the user has visited
it. This is the default; it replaces `standalone`.

### `standalone`

```elm
standalone : Attribute msg
```

A link that stands on its own, such as a cell of a table, an item of a list or
a line of a menu: in the link color without an underline until the pointer is
over it, and without a color for visited links. It replaces `inline`.

### `truncate`

```elm
truncate : Attribute msg
```

Keeps the text on one line and ends it with an ellipsis when the link is wider
than the room it has, and makes the whole text its native tooltip. Give the
link a container with a width (a table cell with a width, a column of a grid),
because a link that may grow as wide as it likes has nothing to be cut by.

### `icon`

```elm
icon : Icon.Icon -> Attribute msg
```

An icon before the text. It is decoration: the text names the link. See
[Klar.Icon](Klar.Icon.md).

    Link.view [ Link.icon Icon.fileText ] (Link.internal "/invoices/7") "Invoice 7"

### `id`

```elm
id : String -> Attribute msg
```

The DOM id of the link, to give focus back to it, for example with
`Modal.open`.

### `onClick`

```elm
onClick : msg -> Attribute msg
```

Lets the application take over a click: `msg` is sent when the user clicks the
link with the main mouse button and no modifier key, and the browser does not
follow the link then. Ctrl, Cmd, Shift and Alt clicks and the middle button are left
alone, so "open in a new tab" keeps working, and so does a link that the
keyboard follows with Enter, which also counts as a click.

Use it in a program made with `Browser.element` or `Browser.document` that
keeps its own page state, or for a link that opens a panel of the same page
when it is clicked and still leads to a page when it is opened in a new tab.
In a `Browser.application` you do not need it: Elm reports the click to
`onUrlRequest` anyway, and `msg` would be sent as well. A link that opens in a
new tab (a page on another site) ignores `onClick`: taking the click over would
keep the browser from opening the tab, which is the point of the link. Such a link
is always left to the browser.

### `locale`

```elm
locale : Locale.Locale -> Attribute msg
```

The language of the built-in text, "(opens in a new tab)", which screen
readers read after the text of a link to another site. The default is
`Locale.default`, which is `Locale.en`.
