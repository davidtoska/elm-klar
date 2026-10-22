module Klar.ListItem exposing
    ( view, content, heading, Attribute
    , secondary, meta, icon, avatar, leading, trailing, accent
    , onClick, href, selected, disabled, id, label
    , list, ListAttribute, listLabel, undivided, compact, bordered, maxHeight
    , remote, skeleton, skeletonRows, onRetry, emptyTitle, emptyDescription, emptyIcon, locale, settings
    )

{-| A dense list row, and the list that holds the rows.

Use when: the application shows records such as orders, tickets and files, a menu of things to open, or a master list next to a detail pane.
Do not use when: people must search, sort and act on many rows of one kind (as `Klar.Table`).

    import Klar.ListItem as ListItem

    ListItem.list [ ListItem.listLabel "Tickets" ]
        [ ListItem.view
            [ ListItem.avatar "Ada Lovelace"
            , ListItem.secondary "Order 1042 arrived damaged"
            , ListItem.meta "Today 14:05"
            , ListItem.selected (model.selected == Just 1042)
            , ListItem.onClick (TicketSelected 1042)
            , ListItem.trailing [ ticketMenu ]
            ]
            "Ada Lovelace"
        ]

    -- from the backend: skeleton, failure with retry, empty state and rows
    ListItem.remote
        [ ListItem.onRetry ReloadTickets, ListItem.emptyTitle "No tickets" ]
        viewTicket
        model.tickets

A row is made of a leading element (an icon, an avatar or any HTML), a title
with a secondary line, a meta text on the right and trailing actions. A row with
`onClick` or `href` is one button or link, so the whole row is the click target
and `Tab` moves between rows; the trailing actions are separate controls and do
not trigger the row. A row with both is a link that also sends the `onClick`
message when it is followed with a plain click. The selected row is marked with
`aria-current`. The title, the secondary line and the meta text are each cut with
an ellipsis when they do not fit; the whole text is the tooltip.

When the rows have several columns that the user compares or sorts, use
[Klar.Table](Klar-Table) instead.

There are two kinds of attributes: `Attribute` configures a row and goes to
`view`, `ListAttribute` configures the list and goes to `list` and `remote`.


# Rows

@docs view, content, heading, Attribute

A row of a [Klar.VirtualList](Klar-VirtualList) is an `li` of the list's own, so what
goes into it is `content`, the row without the `li` and without anything to click.


# Row content

@docs secondary, meta, icon, avatar, leading, trailing, accent


# Row behavior

@docs onClick, href, selected, disabled, id, label


# Lists

@docs list, ListAttribute, listLabel, undivided, compact, bordered, maxHeight


# Data from a backend

@docs remote, skeleton, skeletonRows, onRetry, emptyTitle, emptyDescription, emptyIcon, locale, settings

-}

import Html exposing (Html)
import Html.Attributes as Attr
import Html.Events as Events
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
import Klar.Theme as Theme exposing (Tone)



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
and `Danger` have colors of their own.
-}
accent : Tone -> Attribute msg
accent value =
    Attribute (\config -> { config | accent = Just value })


{-| The DOM id of the row (its `li` element).
-}
id : String -> Attribute msg
id value =
    Attribute (\config -> { config | id = Just value })


{-| An accessible name (`aria-label`) for the button or link of the row. It
replaces the text of the row when a screen reader reads it, so use it only when
the title and the secondary text would not make sense out of context. A row that
is neither a button nor a link (it has no `onClick` or `href`, or it is
`disabled`) is plain content and ignores the label.
-}
label : String -> Attribute msg
label text =
    Attribute (\config -> { config | ariaLabel = Just text })


{-| One row of a list. The text is the title. The row is an `li`, so put it in a
`list`.

    ListItem.view [ ListItem.icon Icon.fileText, ListItem.meta "2 MB" ] "invoice-2041.pdf"

-}
view : List (Attribute msg) -> String -> Html msg
view attributes title =
    row Html.li (configureRow attributes) title


{-| What is in a row, for a place that makes the `li` itself, such as a
[Klar.VirtualList](Klar-VirtualList): the same look as `view` (a title, a second
line, a meta text, an icon or an avatar, a colored edge) in a `div`. It is not a
button or a link, so `onClick`, `href`, `label` and `trailing` do nothing in it:
the row around it is what is clicked.

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
        interactive =
            not config.disabled && (config.onClick /= Nothing || config.href /= Nothing)

        mainClass =
            Internal.cls [ "klar-list-item__main" ]

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
            [ mainClass
            , Internal.attrIf config.selected (Attr.attribute "aria-current" "true")
            ]

        -- Only a button or a link can have a name of its own. A plain `div`
        -- has no role that takes `aria-label`, so it gets none.
        nameAttribute =
            Internal.attrMaybe (Attr.attribute "aria-label") config.ariaLabel

        main_ =
            if interactive then
                case config.href of
                    Just url ->
                        Html.a
                            (commonAttributes
                                ++ [ nameAttribute
                                   , Attr.href url
                                   , Internal.attrMaybe plainClick config.onClick
                                   ]
                            )
                            mainContent

                    Nothing ->
                        Html.button
                            (commonAttributes
                                ++ [ nameAttribute
                                   , Attr.type_ "button"
                                   , Internal.attrMaybe Events.onClick config.onClick
                                   ]
                            )
                            mainContent

            else
                Html.div
                    (commonAttributes
                        ++ [ Internal.attrIf config.disabled (Attr.attribute "aria-disabled" "true") ]
                    )
                    mainContent
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
                    "klar-list-item--accent klar-list-item--accent-" ++ Theme.toneSuffix tone

                Nothing ->
                    ""
            ]
        , Internal.attrMaybe Attr.id config.id
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
shown in capital letters. Put it among the rows in the list.

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
uniform: pass the index of the row. `remote` shows placeholder rows by itself.
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
`list` or `remote`; later attributes win over earlier ones. Settings of a single
row are `Attribute`s, which go to `view`.
-}
type ListAttribute msg
    = ListAttribute (ListConfig msg -> ListConfig msg)


type alias ListConfig msg =
    { divided : Bool
    , compact : Bool
    , bordered : Bool
    , maxHeight : Maybe Int
    , label : Maybe String
    , onRetry : Maybe msg
    , emptyTitle : Maybe String
    , emptyDescription : Maybe String
    , emptyIcon : Icon
    , skeletonRows : Int
    , locale : Locale
    , settings : Settings
    }


configureList : List (ListAttribute msg) -> ListConfig msg
configureList attributes =
    List.foldl (\(ListAttribute change) config -> change config)
        { divided = True
        , compact = False
        , bordered = False
        , maxHeight = Nothing
        , label = Nothing
        , onRetry = Nothing
        , emptyTitle = Nothing
        , emptyDescription = Nothing
        , emptyIcon = Icon.inbox
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


{-| Tighter rows: less padding and a smaller box around the `icon`. Lists follow a
compact density of the application (`Klar.Settings`) without it.
-}
compact : ListAttribute msg
compact =
    ListAttribute (\config -> { config | compact = True })


{-| A border and rounded corners around the list, on a white background.
-}
bordered : ListAttribute msg
bordered =
    ListAttribute (\config -> { config | bordered = True })


{-| Scrolls inside the list when it is taller than this many pixels: for long
lists in a panel. By default the list grows with its rows.

A list that scrolls can take the keyboard focus (`tabindex="0"`), so that
keyboard users can scroll it with the arrow keys. It stays a `list`; give it a
`listLabel` to name it.

-}
maxHeight : Int -> ListAttribute msg
maxHeight pixels =
    ListAttribute (\config -> { config | maxHeight = Just pixels })


{-| The accessible name of the list (`aria-label`), such as "Tickets".
-}
listLabel : String -> ListAttribute msg
listLabel text =
    ListAttribute (\config -> { config | label = Just text })


{-| The message sent by the "Try again" button in the failure state of `remote`.
Without it there is no button. The button is also hidden when trying again would
not help (see [Klar.ErrorState](Klar-ErrorState)).
-}
onRetry : msg -> ListAttribute msg
onRetry msg =
    ListAttribute (\config -> { config | onRetry = Just msg })


{-| The title of the empty state of `remote`. The default is the built-in
"Nothing to show".
-}
emptyTitle : String -> ListAttribute msg
emptyTitle text =
    ListAttribute (\config -> { config | emptyTitle = Just text })


{-| The text under the title of the empty state of `remote`. There is none by
default.
-}
emptyDescription : String -> ListAttribute msg
emptyDescription text =
    ListAttribute (\config -> { config | emptyDescription = Just text })


{-| The icon of the empty state of `remote`. The default is `Icon.inbox`.
-}
emptyIcon : Icon -> ListAttribute msg
emptyIcon value =
    ListAttribute (\config -> { config | emptyIcon = value })


{-| How many placeholder rows `remote` shows while the data is loading. The
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


{-| The language of the built-in text of `remote`: the default title of the empty
state ("Nothing to show" in English) and the "Try again" button. The default is
`Locale.default`, which is English.
-}
locale : Locale -> ListAttribute msg
locale value =
    ListAttribute (\config -> { config | locale = value })


{-| The container of the rows: a `ul` with the role `list`. Its children are rows
made with `view` and, between groups, `heading`s.

    ListItem.list [ ListItem.bordered, ListItem.compact ]
        [ ListItem.view [] "Order 1042"
        , ListItem.view [] "Order 1043"
        ]

-}
list : List (ListAttribute msg) -> List (Html msg) -> Html msg
list attributes rows =
    let
        config =
            configureList attributes
    in
    Html.ul
        [ listClass config
        , Attr.attribute "role" "list"
        , Internal.attrMaybe (Attr.attribute "aria-label") config.label
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
        rows


listClass : ListConfig msg -> Html.Attribute msg
listClass config =
    Internal.cls
        [ "klar-list"
        , if config.divided then
            "klar-list--divided"

          else
            ""
        , if config.compact then
            "klar-list--compact"

          else
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


{-| A list of records from the backend. `toRow` turns one record into a row,
usually with `view`. While the data is `NotAsked` or `Loading` the list shows
placeholder rows (`skeletonRows`), a `Failed` shows an error state with a retry
button (`onRetry`), an empty list shows an empty state (`emptyTitle`) and
otherwise the rows are shown in a `list`. Data that is `Kept` stays: dimmed and
busy while it is refreshed, and under "Old data from 14:05" with a retry
(`onRetry`) when the last refresh failed.

    ListItem.remote [ ListItem.onRetry ReloadOrders ] viewOrder model.orders

-}
remote : List (ListAttribute msg) -> (a -> Html msg) -> Remote (List a) -> Html msg
remote attributes toRow data =
    let
        config =
            configureList attributes

        framed inner =
            Html.div [ Internal.cls [ "klar-list-state" ], Internal.attrIf config.bordered (Internal.cls [ "klar-list-state--bordered" ]) ] [ inner ]
    in
    case Freshness.settle data of
        ( Remote.Loaded items, freshness ) ->
            if List.isEmpty items then
                framed (emptyView config)

            else
                case freshness of
                    Freshness.Fresh ->
                        list attributes (List.map toRow items)

                    _ ->
                        Html.div
                            [ Internal.cls [ "klar-list-fresh", Freshness.className freshness ]
                            , Freshness.busyAttr freshness
                            ]
                            [ Freshness.notice
                                { locale = config.locale, settings = config.settings, onRetry = config.onRetry, inline = False }
                                freshness
                            , list attributes (List.map toRow items)
                            ]

        ( settled, _ ) ->
            remoteWithout config framed settled


remoteWithout : ListConfig msg -> (Html msg -> Html msg) -> Remote (List a) -> Html msg
remoteWithout config framed data =
    case data of
        Remote.NotAsked ->
            skeletonList config

        Remote.Loading ->
            skeletonList config

        Remote.Failed problem ->
            framed (failureView config problem)

        _ ->
            skeletonList config


emptyView : ListConfig msg -> Html msg
emptyView config =
    EmptyState.view
        (List.filterMap identity
            [ Just EmptyState.compact
            , Just (EmptyState.icon config.emptyIcon)
            , Just
                (EmptyState.title
                    (Maybe.withDefault (Locale.pick config.locale { nb = "Ingenting å vise", en = "Nothing to show" }) config.emptyTitle)
                )
            , Maybe.map EmptyState.description config.emptyDescription
            ]
        )


skeletonList : ListConfig msg -> Html msg
skeletonList config =
    Html.ul
        [ listClass config
        , Attr.attribute "aria-busy" "true"
        , Internal.attrMaybe (Attr.attribute "aria-label") config.label
        ]
        (List.range 1 config.skeletonRows |> List.map skeleton)


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
