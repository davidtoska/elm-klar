module Klar.ListItem exposing
    ( view, content, heading, Attribute
    , secondary, meta, icon, avatar, leading, trailing, accent
    , onClick, href, selected, disabled, id, rowAriaLabel
    , list, keyedList, ListAttribute, ariaLabel, undivided, density, bordered, maxHeight
    , viewRemote, skeleton, skeletonRows, onRetry, emptyState, locale, settings
    )

{-| A dense list row, and the list that holds the rows.

Use when: the application shows records such as orders, tickets and files, a menu of things to open, or a master list next to a detail pane.
Do not use when: people must search, sort and act on many rows of one kind (use `Klar.Table`), or the list has thousands of rows (use `Klar.VirtualList` with `ListItem.content`).

    import Klar.ListItem as ListItem
    import Klar.Remote as Remote

    -- a list that never changes while the user is on it
    ListItem.list [ ListItem.ariaLabel "Settings" ]
        [ ListItem.view [ ListItem.icon Icon.user, ListItem.href "#/settings/profile" ] "Profile"
        , ListItem.view [ ListItem.icon Icon.lock, ListItem.href "#/settings/security" ] "Security"
        ]

    -- records from the backend: every row keyed by the id of its record
    ListItem.viewRemote
        [ ListItem.ariaLabel "Tickets", ListItem.onRetry ReloadTickets ]
        (Remote.map (List.map (\ticket -> ( ticket.id, viewTicket model ticket ))) model.tickets)

    viewTicket : Model -> Ticket -> Html Msg
    viewTicket model ticket =
        ListItem.view
            [ ListItem.avatar ticket.customer
            , ListItem.secondary ticket.subject
            , ListItem.meta ticket.received
            , ListItem.selected (model.selected == Just ticket.id)
            , ListItem.onClick (TicketSelected ticket.id)
            , ListItem.trailing [ ticketMenu ticket ]
            ]
            ticket.customer

A row is made of a leading element (an icon, an avatar or any HTML), a title
with a secondary line, a meta text on the right and trailing actions. A row with
`onClick` or `href` is one button or link, so the whole row is the click target
and `Tab` moves between rows; the trailing actions are separate controls and do
not trigger the row. A row with both is a link that also sends the `onClick`
message when it is followed with a plain click. The selected row is marked with
`aria-current`. The title, the secondary line and the meta text are each cut with
an ellipsis when they do not fit; the whole text is the tooltip.

Rows that can come, go or move while the user is on them (records from the
backend, a polled queue) go into a `keyedList`, or `viewRemote`, with the id of
the record as the key. Then a new row at the top never moves the keyboard focus
or the next `Enter` onto another record, which is what happens with a `list`,
whose rows are matched by their place. A refresh, a failed refresh and old data
(`Remote.Kept`) keep the rows where they are, so the focus stays on its row.

When the rows have several columns that the user compares or sorts, use
[Klar.Table](Klar-Table) instead.

There are two kinds of attributes: `Attribute` configures a row and goes to
`view`, `ListAttribute` configures the list and goes to `list`, `keyedList` and
`viewRemote`.


# Rows

@docs view, content, heading, Attribute

A row of a [Klar.VirtualList](Klar-VirtualList) is an `li` of the list's own, so what
goes into it is `content`, the row without the `li` and without anything to click.


# Row content

@docs secondary, meta, icon, avatar, leading, trailing, accent


# Row behavior

@docs onClick, href, selected, disabled, id, rowAriaLabel


# Lists

@docs list, keyedList, ListAttribute, ariaLabel, undivided, density, bordered, maxHeight


# Data from a backend

@docs viewRemote, skeleton, skeletonRows, onRetry, emptyState, locale, settings

-}

import Html exposing (Html)
import Html.Attributes as Attr
import Html.Events as Events
import Html.Keyed as Keyed
import Json.Decode as Decode
import Klar.Avatar as Avatar
import Klar.EmptyState as EmptyState
import Klar.ErrorState as ErrorState
import Klar.Icon as Icon exposing (Icon)
import Klar.Internal as Internal
import Klar.Internal.Freshness as Freshness
import Klar.Locale as Locale exposing (Locale)
import Klar.Remote as Remote exposing (Problem, Remote)
import Klar.Settings as Settings exposing (Settings)
import Klar.Skeleton as Skeleton
import Klar.Theme exposing (Density(..), Tone)



-- ROW


{-| A setting of a row. Make them with the functions below and pass a list to
`view`; later attributes win over earlier ones.
-}
type Attribute msg
    = Attribute (RowConfig msg -> RowConfig msg)


type Leading msg
    = NoLeading
    | LeadingIcon Icon
    | LeadingAvatar String
    | LeadingHtml (Html msg)


type alias RowConfig msg =
    { secondary : Maybe String
    , meta : Maybe String
    , leading : Leading msg
    , trailing : List (Html msg)
    , selected : Bool
    , disabled : Bool
    , onClick : Maybe msg
    , href : Maybe String
    , accent : Maybe Tone
    , id : Maybe String
    , ariaLabel : Maybe String
    }


configureRow : List (Attribute msg) -> RowConfig msg
configureRow attributes =
    List.foldl (\(Attribute change) config -> change config)
        { secondary = Nothing
        , meta = Nothing
        , leading = NoLeading
        , trailing = []
        , selected = False
        , disabled = False
        , onClick = Nothing
        , href = Nothing
        , accent = Nothing
        , id = Nothing
        , ariaLabel = Nothing
        }
        attributes


{-| A second line under the title, in gray: a customer, an address or a short
description.
-}
secondary : String -> Attribute msg
secondary text =
    Attribute (\config -> { config | secondary = Just text })


{-| Small gray text at the right end of the row: a date, a count or a status.
The digits are tabular, so numbers line up from row to row.
-}
meta : String -> Attribute msg
meta text =
    Attribute (\config -> { config | meta = Just text })


{-| An icon in a quiet box in front of the title.
-}
icon : Icon -> Attribute msg
icon value =
    Attribute (\config -> { config | leading = LeadingIcon value })


{-| An avatar for this name in front of the title. The avatar is decorative
(hidden from screen readers), so the name should also be in the text of the row.
-}
avatar : String -> Attribute msg
avatar name =
    Attribute (\config -> { config | leading = LeadingAvatar name })


{-| Anything else in front of the title, such as a thumbnail. It sits inside the
button or link of the row, so it should not contain buttons or links of its own:
use `trailing` for those.
-}
leading : Html msg -> Attribute msg
leading html =
    Attribute (\config -> { config | leading = LeadingHtml html })


{-| Buttons, menus or badges at the end of the row. They are separate
controls: clicking them does not click the row.
-}
trailing : List (Html msg) -> Attribute msg
trailing html =
    Attribute (\config -> { config | trailing = html })


{-| Marks the current row of a master list: tinted, with a bar at the left, and
`aria-current` for screen readers. The default is `False`.
-}
selected : Bool -> Attribute msg
selected value =
    Attribute (\config -> { config | selected = value })


{-| Visible but dimmed and not clickable: `onClick` and `href` are ignored, and
the row is marked `aria-disabled`. The default is `False`.

A row with `onClick` or `href` stays the same button or link while it is
disabled, without the click and out of the `Tab` order, so a row that is disabled
while it has the focus (during a save) keeps the focus.

-}
disabled : Bool -> Attribute msg
disabled value =
    Attribute (\config -> { config | disabled = value })


{-| Makes the row a button that sends this message when it is clicked or
activated with the keyboard. If the row also has an `href`, it is a link, and
the message is sent when the link is followed with a plain click: the main mouse
button or the keyboard, without Ctrl, Cmd, Shift or Alt. A click that opens the
link elsewhere sends nothing, and the link works as usual.
-}
onClick : msg -> Attribute msg
onClick msg =
    Attribute (\config -> { config | onClick = Just msg })


{-| Makes the row a link to this URL. Use `#/path` for links inside a single page
application. If the row also has an `onClick` message, it is sent when the link
is followed with a plain click (see `onClick`).
-}
href : String -> Attribute msg
href url =
    Attribute (\config -> { config | href = Just url })


{-| A colored strip at the left edge: a status the user should see in a long
list. `Neutral` is gray, `Primary` and `Info` are blue, and `Success`, `Warning`
and `Danger` have colors of their own. A color says nothing to a screen reader,
so the status must also be in the text of the row (the `meta` or the
`secondary` line); in the high-contrast mode of Windows the strip is drawn in
the color of the text.
-}
accent : Tone -> Attribute msg
accent value =
    Attribute (\config -> { config | accent = Just value })


{-| The DOM id of the row. A row with `onClick` or `href` puts it on its button
or link, the element that takes the focus, so `Klar.focus` with this id brings
the keyboard back to the row (after a delete or a retry); any other row puts it on
its `li`.

    ListItem.id ("order-" ++ order.id)

-}
id : String -> Attribute msg
id value =
    Attribute (\config -> { config | id = Just value })


{-| An accessible name (`aria-label`) for the button or link of the row, which
only screen readers hear. It replaces the text of the row when a screen reader
reads it, so use it only when the title and the secondary text would not make
sense out of context. A row that is neither a button nor a link (it has no
`onClick` or `href`) is plain content and ignores it.
-}
rowAriaLabel : String -> Attribute msg
rowAriaLabel text =
    Attribute (\config -> { config | ariaLabel = Just text })


{-| One row of a list. The text is the title. The row is an `li`, so put it in a
`list`, a `keyedList` or `viewRemote`.

    ListItem.view [ ListItem.icon Icon.fileText, ListItem.meta "2 MB" ] "invoice-2041.pdf"

-}
view : List (Attribute msg) -> String -> Html msg
view attributes title =
    row Html.li (configureRow attributes) title


{-| What is in a row, for a place that makes the `li` itself, such as a
[Klar.VirtualList](Klar-VirtualList): the same look as `view` (a title, a second
line, a meta text, an icon or an avatar, a colored edge) in a `div`. It is not a
button or a link, so `onClick`, `href`, `rowAriaLabel` and `trailing` do nothing in
it: the row around it is what is clicked.

    ListItem.content [ ListItem.secondary "Ada Lovelace", ListItem.meta "Today" ] "Order 1042"

-}
content : List (Attribute msg) -> String -> Html msg
content attributes title =
    let
        config =
            configureRow attributes
    in
    row Html.div { config | onClick = Nothing, href = Nothing, trailing = [] } title


row : (List (Html.Attribute msg) -> List (Html msg) -> Html msg) -> RowConfig msg -> String -> Html msg
row root config title =
    let
        -- A row that has something to click keeps its button or link while it is
        -- disabled: replacing the element would take the focus from it.
        clickable =
            config.onClick /= Nothing || config.href /= Nothing

        interactive =
            clickable && not config.disabled

        mainContent =
            [ viewLeading config.leading
            , Html.span [ Internal.cls [ "klar-list-item__body" ] ]
                [ Html.span [ Internal.cls [ "klar-list-item__title" ], Attr.title title ] [ Html.text title ]
                , Internal.viewMaybe
                    (\text -> Html.span [ Internal.cls [ "klar-list-item__secondary" ], Attr.title text ] [ Html.text text ])
                    config.secondary
                ]
            , Internal.viewMaybe
                (\text -> Html.span [ Internal.cls [ "klar-list-item__meta", "klar-tabular" ], Attr.title text ] [ Html.text text ])
                config.meta
            ]

        commonAttributes =
            [ Internal.cls [ "klar-list-item__main" ]
            , Internal.attrIf config.selected (Attr.attribute "aria-current" "true")
            , Internal.attrIf config.disabled (Attr.attribute "aria-disabled" "true")
            ]

        -- Only a button or a link can have a name of its own. A plain `div`
        -- has no role that takes `aria-label`, so it gets none.
        clickableAttributes =
            [ Internal.attrMaybe (Attr.attribute "aria-label") config.ariaLabel
            , Internal.attrMaybe Attr.id config.id

            -- out of the Tab order, but still able to hold the focus it has
            , Internal.attrIf config.disabled (Attr.attribute "tabindex" "-1")
            ]

        main_ =
            if clickable then
                case config.href of
                    Just url ->
                        Html.a
                            (commonAttributes
                                ++ clickableAttributes
                                ++ (if config.disabled then
                                        -- a link without `href` has no role of its own
                                        [ Attr.attribute "role" "link" ]

                                    else
                                        [ Attr.href url
                                        , Internal.attrMaybe plainClick config.onClick
                                        ]
                                   )
                            )
                            mainContent

                    Nothing ->
                        Html.button
                            (commonAttributes
                                ++ clickableAttributes
                                ++ [ Attr.type_ "button"
                                   , if config.disabled then
                                        Internal.noAttr

                                     else
                                        Internal.attrMaybe Events.onClick config.onClick
                                   ]
                            )
                            mainContent

            else
                Html.div commonAttributes mainContent
    in
    root
        [ Internal.cls
            [ "klar-list-item"
            , if interactive then
                "klar-list-item--interactive"

              else
                ""
            , if config.selected then
                "klar-list-item--selected"

              else
                ""
            , if config.disabled then
                "klar-list-item--disabled"

              else
                ""
            , case config.accent of
                Just tone ->
                    "klar-list-item--accent klar-list-item--accent-" ++ Internal.toneSuffix tone

                Nothing ->
                    ""
            ]
        , if clickable then
            Internal.noAttr

          else
            Internal.attrMaybe Attr.id config.id
        ]
        [ main_
        , if List.isEmpty config.trailing then
            Html.text ""

          else
            Html.span [ Internal.cls [ "klar-list-item__trailing" ] ] config.trailing
        ]


viewLeading : Leading msg -> Html msg
viewLeading value =
    case value of
        NoLeading ->
            Html.text ""

        LeadingIcon glyph ->
            Html.span [ Internal.cls [ "klar-list-item__leading", "klar-list-item__leading--icon" ] ] [ Icon.view glyph ]

        LeadingAvatar name ->
            Html.span [ Internal.cls [ "klar-list-item__leading" ] ] [ Avatar.view [ Avatar.decorative ] name ]

        LeadingHtml html ->
            Html.span [ Internal.cls [ "klar-list-item__leading" ] ] [ html ]


{-| The click handler of a row that is a link and has an `onClick` message too.
It sends the message for a plain click (the main mouse button, or the keyboard,
without Ctrl, Cmd, Shift or Alt) and ignores a click that opens the link
elsewhere. It never prevents the default action, so the link works as usual.
Fields that are missing from the event count as "not pressed".
-}
plainClick : msg -> Html.Attribute msg
plainClick msg =
    let
        flag name =
            Decode.oneOf [ Decode.field name Decode.bool, Decode.succeed False ]

        isPlain button ctrlKey metaKey shiftKey altKey =
            button == 0 && not (ctrlKey || metaKey || shiftKey || altKey)
    in
    Events.on "click"
        (Decode.map5 isPlain
            (Decode.oneOf [ Decode.field "button" Decode.int, Decode.succeed 0 ])
            (flag "ctrlKey")
            (flag "metaKey")
            (flag "shiftKey")
            (flag "altKey")
            |> Decode.andThen
                (\plain ->
                    if plain then
                        Decode.succeed msg

                    else
                        Decode.fail "not a plain click"
                )
        )


{-| A small caption between groups of rows, such as "Today" and "Earlier",
shown in capital letters. Put it among the rows in the list (in a `keyedList`,
with a key of its own).

    ListItem.list []
        [ ListItem.heading "Today"
        , ListItem.view [] "Order 1042"
        , ListItem.heading "Earlier"
        , ListItem.view [] "Order 1017"
        ]

-}
heading : String -> Html msg
heading text =
    Html.li [ Internal.cls [ "klar-list__heading" ], Attr.attribute "role" "presentation" ] [ Html.text text ]


{-| One placeholder row for data that is on its way. The number only varies the
widths of the two text lines, so that a stack of placeholders does not look
uniform: pass the index of the row. `viewRemote` shows placeholder rows by
itself.
-}
skeleton : Int -> Html msg
skeleton count =
    Html.li [ Internal.cls [ "klar-list-item", "klar-list-item--skeleton" ], Attr.attribute "aria-hidden" "true" ]
        [ Html.div [ Internal.cls [ "klar-list-item__main" ] ]
            [ Html.span [ Internal.cls [ "klar-list-item__leading" ] ] [ Skeleton.circle 30 ]
            , Html.span [ Internal.cls [ "klar-list-item__body" ] ]
                [ Skeleton.line (50 + modBy 30 (count * 17))
                , Skeleton.line (28 + modBy 25 (count * 11))
                ]
            ]
        ]



-- LIST


{-| A setting of a list. Make them with the functions below and pass a list to
`list`, `keyedList` or `viewRemote`; later attributes win over earlier ones.
Settings of a single row are `Attribute`s, which go to `view`.
-}
type ListAttribute msg
    = ListAttribute (ListConfig msg -> ListConfig msg)


type alias ListConfig msg =
    { divided : Bool
    , density : Maybe Density
    , bordered : Bool
    , maxHeight : Maybe Int
    , ariaLabel : Maybe String
    , onRetry : Maybe msg
    , emptyState : List (EmptyState.Attribute msg)
    , skeletonRows : Int
    , locale : Locale
    , settings : Settings
    }


configureList : List (ListAttribute msg) -> ListConfig msg
configureList attributes =
    List.foldl (\(ListAttribute change) config -> change config)
        { divided = True
        , density = Nothing
        , bordered = False
        , maxHeight = Nothing
        , ariaLabel = Nothing
        , onRetry = Nothing
        , emptyState = []
        , skeletonRows = 4
        , locale = Locale.default
        , settings = Settings.default
        }
        attributes


{-| No thin lines between the rows. By default the rows are divided.
-}
undivided : ListAttribute msg
undivided =
    ListAttribute (\config -> { config | divided = False })


{-| How tightly the rows are packed: `Compact` (32 pixels, less padding and a
smaller box around the `icon`), `Normal` (44 pixels) or `Comfortable` (52
pixels). Without it the list follows the density of the application
(`Klar.Settings`), so give it only to a list that must differ from the rest.

    ListItem.density Compact

-}
density : Density -> ListAttribute msg
density value =
    ListAttribute (\config -> { config | density = Just value })


{-| A border and rounded corners around the list, on a white background.
-}
bordered : ListAttribute msg
bordered =
    ListAttribute (\config -> { config | bordered = True })


{-| Scrolls inside the list when it is taller than this many pixels: for long
lists in a panel. By default the list grows with its rows.

A list that scrolls can take the keyboard focus (`tabindex="0"`), so that
keyboard users can scroll it with the arrow keys. It stays a `list`; give it an
`ariaLabel` to name it.

-}
maxHeight : Int -> ListAttribute msg
maxHeight pixels =
    ListAttribute (\config -> { config | maxHeight = Just pixels })


{-| The accessible name of the list (`aria-label`), which only screen readers
hear, such as "Tickets". There is none by default; give one to every list when
a page has more than one.
-}
ariaLabel : String -> ListAttribute msg
ariaLabel text =
    ListAttribute (\config -> { config | ariaLabel = Just text })


{-| The message sent by the "Try again" button of `viewRemote`: in the failure
state, and beside "Old data from 14:05" when a refresh failed. Without it there
is no button. The button is also hidden when trying again would not help (see
[Klar.ErrorState](Klar-ErrorState)).
-}
onRetry : msg -> ListAttribute msg
onRetry msg =
    ListAttribute (\config -> { config | onRetry = Just msg })


{-| Changes the empty state of `viewRemote`, which shows when the list has no
rows: by default a small inbox icon and the title "Nothing to show". These
attributes are applied after the defaults, so yours win. Use it to say why the
list is empty and what to do next.

    ListItem.emptyState
        [ EmptyState.title "No orders"
        , EmptyState.description "No order matches the filter."
        , EmptyState.icon Icon.search
        ]

-}
emptyState : List (EmptyState.Attribute msg) -> ListAttribute msg
emptyState attributes =
    ListAttribute (\config -> { config | emptyState = attributes })


{-| How many placeholder rows `viewRemote` shows while the data is loading. The
default is 4, and the value is kept between 1 and 20.
-}
skeletonRows : Int -> ListAttribute msg
skeletonRows n =
    ListAttribute (\config -> { config | skeletonRows = clamp 1 20 n })


{-| The settings of the application (`Klar.Settings`): the time zone of the time in
"Old data from 14:05". Without it the time is written in UTC and ends in "UTC".

    ListItem.settings model.settings

-}
settings : Settings -> ListAttribute msg
settings given =
    ListAttribute (\config -> { config | settings = given })


{-| The language of the built-in text of `viewRemote`: "Loading" for screen
readers, the default title of the empty state ("Nothing to show" in English), the
marker for old data and the "Try again" button. The default is `Locale.default`,
which is English.
-}
locale : Locale -> ListAttribute msg
locale value =
    ListAttribute (\config -> { config | locale = value })


{-| The container of the rows: a `ul` with the role `list`. Its children are rows
made with `view` and, between groups, `heading`s. The rows are matched by their
place when the list is drawn again, so use it for rows that do not come and go
while the user is on them; otherwise use `keyedList`.

    ListItem.list [ ListItem.bordered, ListItem.density Compact ]
        [ ListItem.view [] "Order 1042"
        , ListItem.view [] "Order 1043"
        ]

-}
list : List (ListAttribute msg) -> List (Html msg) -> Html msg
list attributes rows =
    Html.ul (listAttributes (configureList attributes)) rows


{-| A `list` whose rows are each given with a key that names their record, such
as the id of an order. When a row is added, removed or moved, the other rows keep
their elements, so the keyboard focus stays on its record and the next `Enter`
does not open another one. Every key must be unique in the list; a `heading` needs
one too.

    ListItem.keyedList [ ListItem.ariaLabel "Orders" ]
        (List.map (\order -> ( order.id, viewOrder order )) model.orders)

-}
keyedList : List (ListAttribute msg) -> List ( String, Html msg ) -> Html msg
keyedList attributes rows =
    Keyed.ul (listAttributes (configureList attributes)) rows


listAttributes : ListConfig msg -> List (Html.Attribute msg)
listAttributes config =
    [ listClass config
    , Attr.attribute "role" "list"
    , Internal.attrMaybe (Attr.attribute "aria-label") config.ariaLabel
    , case config.maxHeight of
        Just pixels ->
            Internal.styleVars [ ( "max-height", Internal.px pixels ) ]

        Nothing ->
            Internal.noAttr

    -- A list that scrolls must be reachable with the keyboard. It keeps its
    -- role `list`: a role `region` would take the list semantics away from
    -- the rows.
    , Internal.attrIf (config.maxHeight /= Nothing) (Attr.tabindex 0)
    ]


listClass : ListConfig msg -> Html.Attribute msg
listClass config =
    Internal.cls
        [ "klar-list"
        , if config.divided then
            "klar-list--divided"

          else
            ""
        , case config.density of
            Just Compact ->
                "klar-list--compact"

            Just Normal ->
                "klar-list--normal"

            Just Comfortable ->
                "klar-list--comfortable"

            Nothing ->
                ""
        , if config.bordered then
            "klar-list--bordered"

          else
            ""
        , if config.maxHeight /= Nothing then
            "klar-list--scroll"

          else
            ""
        ]


{-| A `keyedList` of records from the backend, in every state of the `Remote`.
Shape the records into keyed rows with `Remote.map`; the key is the id of the
record.

    ListItem.viewRemote [ ListItem.ariaLabel "Orders", ListItem.onRetry ReloadOrders ]
        (Remote.map (List.map (\order -> ( order.id, viewOrder order ))) model.orders)

While the data is `NotAsked` or `Loading` the list shows placeholder rows
(`skeletonRows`) and says "Loading" to screen readers, a `Failed` shows an error
state with a retry button (`onRetry`), no rows show the empty state
(`emptyState`), and otherwise the rows are shown. Data that is `Kept` stays:
dimmed and busy while it is refreshed, and under "Old data from 14:05" with a
retry (`onRetry`) when the last refresh failed, also when it has no rows. The
rows are drawn inside the same elements whether the data is fresh, refreshing or
old, so a refresh that starts or ends never takes the focus from a row.

-}
viewRemote : List (ListAttribute msg) -> Remote (List ( String, Html msg )) -> Html msg
viewRemote attributes data =
    let
        config =
            configureList attributes
    in
    case Freshness.settle data of
        ( Remote.Loaded rows, freshness ) ->
            Html.div
                [ Internal.cls [ "klar-list-fresh", Freshness.className freshness ]
                , Freshness.busyAttr freshness
                ]
                [ Freshness.notice
                    { locale = config.locale, settings = config.settings, onRetry = config.onRetry, inline = False }
                    freshness
                , if List.isEmpty rows then
                    framed config (emptyView config)

                  else
                    Keyed.ul (listAttributes config) rows
                ]

        ( Remote.Failed problem, _ ) ->
            framed config (failureView config problem)

        _ ->
            loadingView config


framed : ListConfig msg -> Html msg -> Html msg
framed config inner =
    Html.div
        [ Internal.cls
            [ "klar-list-state"
            , if config.bordered then
                "klar-list-state--bordered"

              else
                ""
            ]
        ]
        [ inner ]


emptyView : ListConfig msg -> Html msg
emptyView config =
    EmptyState.view
        ([ EmptyState.compact
         , EmptyState.icon Icon.inbox
         , EmptyState.title (Locale.pick config.locale { nb = "Ingenting å vise", en = "Nothing to show" })
         ]
            ++ config.emptyState
        )


{-| The placeholder rows, hidden from screen readers, which hear "Loading"
instead.
-}
loadingView : ListConfig msg -> Html msg
loadingView config =
    Html.div [ Internal.cls [ "klar-list-fresh" ], Attr.attribute "aria-busy" "true" ]
        [ Html.span [ Internal.cls [ "klar-sr-only" ], Attr.attribute "role" "status" ]
            [ Html.text (Locale.pick config.locale { nb = "Laster", en = "Loading" }) ]
        , Html.ul
            [ listClass config
            , Internal.attrMaybe (Attr.attribute "aria-label") config.ariaLabel
            , case config.maxHeight of
                Just pixels ->
                    Internal.styleVars [ ( "max-height", Internal.px pixels ) ]

                Nothing ->
                    Internal.noAttr
            ]
            (List.range 1 config.skeletonRows |> List.map skeleton)
        ]


failureView : ListConfig msg -> Problem -> Html msg
failureView config problem =
    ErrorState.view
        (List.filterMap identity
            [ Just ErrorState.compact
            , Just (ErrorState.locale config.locale)
            , Maybe.map ErrorState.onRetry config.onRetry
            ]
        )
        problem
