module Klar.Link exposing
    ( view
    , Target, internal, external
    , Attribute, current, disabled, inline, standalone, truncate, icon, id, onClick, locale
    )

{-| A real link (`<a href>`) that cannot be built wrong: for a page of the
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
`onUrlRequest`, use a [Klar.Button](Klar-Button) for anything that is not a
navigation (an action, a skip link, an error-summary entry).

**Disabled and current.** A `disabled` link has no `href` and is not in the tab
order: it is drawn dimmed and a screen reader finds it as a link that is
unavailable (`aria-disabled`), the way it finds a disabled button. Use it for a
destination that exists but that the user may not visit, and say why in a
[Klar.Tooltip](Klar-Tooltip) around it. A link to the page that the user is on is
`current` (`aria-current="page"`).

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

@docs Target, internal, external


# Attributes

@docs Attribute, current, disabled, inline, standalone, truncate, icon, id, onClick, locale

-}

import Html exposing (Html)
import Html.Attributes as Attr
import Html.Events as Events
import Json.Decode as Decode
import Klar.Icon as Icon exposing (Icon)
import Klar.Internal as Internal
import Klar.Link.Address as Address
import Klar.Link.Click as Click
import Klar.Locale as Locale exposing (Locale)



-- TARGET


{-| Where a link leads. Make one with `internal` or `external`; the type is
opaque, so it always holds an address that has been checked.
-}
type Target
    = Target { href : String, kind : Kind }


type Kind
    = Inside
    | Outside Address.Kind


{-| A page of your application, given as a path (`"/orders/12"`), as a route in
the fragment (`"#/orders/12"`) or as a query (`"?page=2"`): the text that your own
route function makes. The link stays in the application, whatever the text:
a text that does not begin with `/`, `#` or `?` gets a `/` in front, several
leading slashes become one, and control characters are removed, so `"//evil.example"`
and `"javascript:alert(1)"` become paths of your application (`"/evil.example"`,
`"/javascript:alert(1)"`) that do not exist, and never a link that leaves it.
-}
internal : String -> Target
internal text =
    Target { href = Address.path text, kind = Inside }


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
external text =
    Address.external text
        |> Maybe.map (\checked -> Target { href = checked.href, kind = Outside checked.kind })


{-| Does the link open in a new tab? Only a page on the web does.
-}
opensInNewTab : Target -> Bool
opensInNewTab (Target target) =
    target.kind == Outside Address.Web



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


{-| A destination the user may not visit now. The link has no `href`, cannot be
reached with Tab or clicked, and screen readers find it as a link that is
unavailable (`aria-disabled`). It is drawn dimmed, and sends nothing. The default is
`False`.
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
new tab (another site) is not meant for it, because the click would not open
the tab any more.

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
view attributes ((Target target) as destination) label =
    let
        config =
            configure attributes

        newTab =
            opensInNewTab destination && not config.disabled

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
    if config.disabled then
        Html.a
            [ classNames
            , Attr.attribute "role" "link"
            , Attr.attribute "aria-disabled" "true"
            , Internal.attrMaybe Attr.id config.id
            ]
            content

    else
        Html.a
            [ classNames
            , Attr.href target.href
            , Internal.attrIf newTab (Attr.target "_blank")
            , Internal.attrIf newTab (Attr.rel "noopener noreferrer")
            , Internal.attrIf config.current (Attr.attribute "aria-current" "page")
            , Internal.attrIf config.truncate (Attr.title label)
            , Internal.attrMaybe Attr.id config.id
            , Internal.attrMaybe
                (\msg -> Events.preventDefaultOn "click" (Decode.map (\_ -> ( msg, True )) Click.plain))
                config.onClick
            ]
            content
