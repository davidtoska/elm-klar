module Klar.Link exposing
    ( view
    , Target, internal, external, download
    , Attribute, current, disabled, inline, standalone, truncate, icon, id, onClick, locale
    )

{-| A real link (`<a href>`) that cannot be built wrong: for a page of the
application, for another site, for an email address or a telephone number.

Use when: the user navigates to a page of the application, another site, an email address or a phone number.
Do not use when: the click is an action and not a navigation (as `Klar.Button`).

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

**The destination is a `Target`**, made by `internal`, `external` or
`download`, and no other string ever becomes an `href`; a
[Klar.Button](Klar-Button) that is a link (`Button.href`) takes the same
`Target`. `external` accepts only `http`, `https`,
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
`onUrlRequest`, use a [Klar.Button](Klar-Button) for anything that is not a
navigation (an action, a skip link, an error-summary entry).

**A file to save** is a `download` target: the text is put in the link itself
(a `data:` address, encoded so that any character is safe), the browser saves it
under the name given instead of opening it, and no request goes to a server.

**Disabled and current.** A `disabled` link has no `href`, so it cannot be
followed, but it stays in the tab order: it is drawn dimmed and a screen reader
finds it as a link that is unavailable (`aria-disabled`), the way it finds a
disabled button, and a link that is disabled while it has focus keeps it. Use it
for a destination that exists but that the user may not visit, and say why in a
[Klar.Tooltip](Klar-Tooltip) around it, which the keyboard reaches too. A link to
the page that the user is on is `current` (`aria-current="page"`).

**Inline or standalone.** The default is `inline`: underlined and in the link
color, a different color once visited, for a link inside a sentence. A link
that stands on its own (a cell in a table, an item of a list, a line of a menu)
is `standalone`: no underline until the pointer is over it, and no visited
color. `truncate` keeps the text on one line and ends it with an ellipsis when
the link is wider than the room it has; the whole text is the native tooltip.

The built-in text ("opens in a new tab") follows `locale` (English by default).


# View

@docs view


# Destinations

@docs Target, internal, external, download


# Attributes

@docs Attribute, current, disabled, inline, standalone, truncate, icon, id, onClick, locale

-}

import Html exposing (Html)
import Html.Attributes as Attr
import Html.Events as Events
import Json.Decode as Decode
import Klar.Icon as Icon exposing (Icon)
import Klar.Internal as Internal
import Klar.Link.Click as Click
import Klar.Link.Destination as Destination
import Klar.Locale as Locale exposing (Locale)



-- TARGET


{-| Where a link leads. Make one with `internal`, `external` or `download`; the
type is opaque, so it always holds an address that has been checked.
[`Button.href`](Klar-Button#href) takes it too.
-}
type alias Target =
    Destination.Target


{-| A page of your application, given as a path (`"/orders/12"`), as a route in
the fragment (`"#/orders/12"`), as a query (`"?page=2"`) or as a path relative to
the page (`"./reports/q3.html"`, for an application that is not at the root of its
site): the text that your own route function makes. The link stays in the
application, whatever the text: a text that does not begin with `/`, `#`, `?`,
`./` or `../` gets a `/` in front, several
leading slashes become one, and control characters are removed, so `"//evil.example"`
and `"javascript:alert(1)"` become paths of your application (`"/evil.example"`,
`"/javascript:alert(1)"`) that do not exist, and never a link that leaves it.
-}
internal : String -> Target
internal =
    Destination.internal


{-| An address that is not in your application, or `Nothing` when it cannot be a
link: only `http://` and `https://` addresses with a host, `mailto:` with an
email address and `tel:` with a number are accepted, in any case, and the text
is trimmed. Anything else, a `javascript:` or `data:` address among them, a text
with a space or a control character in it, and the empty text, give `Nothing`.
Decide what to show then, usually the plain text.

    Link.external "https://example.com/docs" -- Just ...

    Link.external "mailto:ada@example.com" -- Just ...

    Link.external "javascript:alert(1)" -- Nothing

-}
external : String -> Maybe Target
external =
    Destination.external


{-| A file that the browser saves when the link is followed, made from a text of
your application: a CSV export, a JSON file, an invoice as text. The text is put
in the link as a `data:` address, encoded as UTF-8 with every character that is
not plain made safe (an emoji, a line break, a `#`), so no server is asked and
nothing is lost. The link has the `download` attribute with the file name, opens
in the same tab and is never taken over by `Browser.application`.

    Link.view [ Link.icon Icon.download ]
        (Link.download { fileName = "orders.csv", mimeType = "text/csv", content = ordersCsv })
        "Download orders"

The `mimeType` is `type/subtype` (`text/csv`, `application/json`); anything else
becomes `application/octet-stream`. An empty `fileName` becomes `download`. Keep
the text to a few megabytes: it is part of the page.

-}
download : { fileName : String, mimeType : String, content : String } -> Target
download =
    Destination.download



-- ATTRIBUTES


{-| A setting of a link. Make them with the functions below and pass a list to
`view`; later attributes win over earlier ones.
-}
type Attribute msg
    = Attribute (Config msg -> Config msg)


type Look
    = Inline
    | Standalone


type alias Config msg =
    { current : Bool
    , disabled : Bool
    , look : Look
    , truncate : Bool
    , icon : Maybe Icon
    , id : Maybe String
    , onClick : Maybe msg
    , locale : Locale
    }


configure : List (Attribute msg) -> Config msg
configure attributes =
    List.foldl (\(Attribute change) config -> change config)
        { current = False
        , disabled = False
        , look = Inline
        , truncate = False
        , icon = Nothing
        , id = Nothing
        , onClick = Nothing
        , locale = Locale.default
        }
        attributes


{-| Says that the link leads to the page that the user is on (`aria-current="page"`
for screen readers; the text is a little heavier and not underlined). Give it a
comparison from your model, so it follows the route:

    Link.current (model.route == Route.Orders)

The default is `False`.

-}
current : Bool -> Attribute msg
current value =
    Attribute (\config -> { config | current = value })


{-| A destination the user may not visit now. The link has no `href`, so it
cannot be followed, and screen readers find it as a link that is unavailable
(`aria-disabled`). It stays in the tab order (`tabindex="0"`), so that a link
disabled while it has focus keeps it and a [Klar.Tooltip](Klar-Tooltip) around it
can say why to a keyboard user. It is drawn dimmed and sends nothing, also in a
`Browser.application`. The default is `False`.
-}
disabled : Bool -> Attribute msg
disabled value =
    Attribute (\config -> { config | disabled = value })


{-| A link in the middle of a sentence: in the link color, underlined (so it is
not told apart by color alone), and in another color once the user has visited
it. This is the default; it replaces `standalone`.
-}
inline : Attribute msg
inline =
    Attribute (\config -> { config | look = Inline })


{-| A link that stands on its own, such as a cell of a table, an item of a list or
a line of a menu: in the link color without an underline until the pointer is
over it, and without a color for visited links. It replaces `inline`.
-}
standalone : Attribute msg
standalone =
    Attribute (\config -> { config | look = Standalone })


{-| Keeps the text on one line and ends it with an ellipsis when the link is wider
than the room it has, and makes the whole text its native tooltip. Give the
link a container with a width (a table cell with a width, a column of a grid),
because a link that may grow as wide as it likes has nothing to be cut by.
-}
truncate : Attribute msg
truncate =
    Attribute (\config -> { config | truncate = True })


{-| An icon before the text. It is decoration: the text names the link. See
[Klar.Icon](Klar-Icon).

    Link.view [ Link.icon Icon.fileText ] (Link.internal "/invoices/7") "Invoice 7"

-}
icon : Icon -> Attribute msg
icon value =
    Attribute (\config -> { config | icon = Just value })


{-| The DOM id of the link, to give focus back to it, for example with
`Modal.open`.
-}
id : String -> Attribute msg
id value =
    Attribute (\config -> { config | id = Just value })


{-| Lets the application take over a click: `msg` is sent when the user clicks the
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
keep the browser from opening the tab, which is the point of the link. Such a link,
and a `download` link, is always left to the browser.

-}
onClick : msg -> Attribute msg
onClick msg =
    Attribute (\config -> { config | onClick = Just msg })


{-| The language of the built-in text, "(opens in a new tab)", which screen
readers read after the text of a link to another site. The default is
`Locale.default`, which is `Locale.en`.
-}
locale : Locale -> Attribute msg
locale value =
    Attribute (\config -> { config | locale = value })



-- VIEW


{-| A link to the target, with this text. The text names the link for screen
readers, so make it say where the link leads ("Order 10001"), not "click here".

    Link.view [ Link.standalone ] (Link.internal "/orders/10001") "Order 10001"

-}
view : List (Attribute msg) -> Target -> String -> Html msg
view attributes destination label =
    let
        config =
            configure attributes

        newTab =
            Destination.opensInNewTab destination && not config.disabled

        file =
            Destination.fileName destination

        classNames =
            Internal.cls
                [ "klar-link"
                , case config.look of
                    Inline ->
                        "klar-link--inline"

                    Standalone ->
                        "klar-link--standalone"
                , if config.current then
                    "klar-link--current"

                  else
                    ""
                , if config.disabled then
                    "klar-link--disabled"

                  else
                    ""
                , if config.truncate then
                    "klar-link--truncate"

                  else
                    ""
                ]

        content =
            [ Internal.viewMaybe (\leading -> Html.span [ Internal.cls [ "klar-link__icon" ] ] [ Icon.view leading ]) config.icon
            , Html.span [ Internal.cls [ "klar-link__text" ] ]
                [ Html.text label
                , Internal.viewIf newTab
                    (Html.span [ Internal.cls [ "klar-sr-only" ] ]
                        [ Html.text (" " ++ Locale.pick config.locale { nb = "(åpnes i en ny fane)", en = "(opens in a new tab)" }) ]
                    )
                ]
            , Internal.viewIf newTab
                (Html.span [ Internal.cls [ "klar-link__external" ] ] [ Icon.sized Icon.Small Icon.externalLink ])
            ]
    in
    -- One element whether it is disabled or not, so that a link that is disabled
    -- while it has focus keeps it.
    if config.disabled then
        Html.a
            (classNames
                :: Internal.attrIf config.current (Attr.attribute "aria-current" "page")
                :: Internal.attrIf config.truncate (Attr.title label)
                :: Internal.attrMaybe Attr.id config.id
                :: Destination.inactiveAttributes { focusable = True }
            )
            content

    else
        Html.a
            [ classNames
            , Attr.href (Destination.href destination)
            , Internal.attrIf newTab (Attr.target "_blank")
            , Internal.attrIf newTab (Attr.rel "noopener noreferrer")
            , Internal.attrMaybe Attr.download file
            , Internal.attrIf config.current (Attr.attribute "aria-current" "page")
            , Internal.attrIf config.truncate (Attr.title label)
            , Internal.attrMaybe Attr.id config.id

            -- A link that opens a new tab or saves a file is left to the browser:
            -- stopping the click would stop the tab or the file.
            , Internal.attrMaybe
                (\msg -> Events.preventDefaultOn "click" (Decode.map (\_ -> ( msg, True )) Click.plain))
                (if newTab || file /= Nothing then
                    Nothing

                 else
                    config.onClick
                )
            ]
            content
