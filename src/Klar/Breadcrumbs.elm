module Klar.Breadcrumbs exposing
    ( view, viewStatic
    , Crumb, link, button, text, withIcon
    , Attribute, items, maxItems, ariaLabel, locale
    , State, init, isOpen, close, Msg, update
    )

{-| The path to the current page: links separated by chevrons, where the last item
is the current page.

Use when: the user must see where the current page sits in the application, as a trail of links.
Do not use when: you need the main navigation (use `Klar.SideNav`) or sections within one page (use `Klar.Tabs`).
Quick path: `viewStatic` for a trail of at most `maxItems` levels; `init`, `update`, `view` for a trail that can grow deeper

Which one: a trail with a fixed depth of two or three levels (Orders, then an order)
is `viewStatic`, with no state. A trail built from a path that can be deep (folders,
regions, a category tree) is `view`, which folds its middle into a "more" button and
keeps whether that list is open in a `State`:

    import Klar.Breadcrumbs as Breadcrumbs

    -- model: crumbs : Breadcrumbs.State
    -- init:  Breadcrumbs.init "page-crumbs"

    -- update
    CrumbsMsg m ->
        let
            ( crumbs, cmd ) =
                Breadcrumbs.update m model.crumbs
        in
        ( { model | crumbs = crumbs }, Cmd.map CrumbsMsg cmd )

    -- view
    Breadcrumbs.view CrumbsMsg
        [ Breadcrumbs.items
            [ Breadcrumbs.link { label = "Home", href = "#/" }
            , Breadcrumbs.link { label = "Customers", href = "#/customers" }
            , Breadcrumbs.text "Ada Lovelace"
            ]
        ]
        model.crumbs

When there are at least two crumbs more than `maxItems`, the first crumb and the last
`maxItems - 1` crumbs stay visible and the ones in between fold into a "more" button
that opens a small list of them (Escape closes it and gives focus back to the button,
the arrow keys move between the levels, Tab moves on). A trail only one crumb longer
is shown whole: a button for a single crumb would save no room. The list closes by
itself when the trail changes under it (Back, a shortcut).

The last crumb is always the current page: it is shown as plain text and marked
with `aria-current="page"`, even if it was made with `link`. Every other crumb
that has a link is a real link, so routing, middle click and "open in new tab"
work as usual; a `button` crumb sends a message instead, for a trail that is not made
of addresses (the levels of a folder browser or a drill-down inside one page). The
built-in text (the name of the navigation landmark and of the "more" button) follows
`locale`, English by default.


# Views

@docs view, viewStatic


# Crumbs

@docs Crumb, link, button, text, withIcon


# Attributes

@docs Attribute, items, maxItems, ariaLabel, locale


# State

@docs State, init, isOpen, close, Msg, update

-}

import Html exposing (Html)
import Html.Attributes as Attr
import Html.Events as Events
import Json.Decode as Decode exposing (Decoder)
import Klar.Button as Button
import Klar.Icon as Icon exposing (Icon)
import Klar.Internal as Internal
import Klar.Locale as Locale exposing (Locale)



-- CRUMBS


{-| One level of the trail. Make it with `link`, `button` or `text` and refine it with
`withIcon`. The `msg` is your message type, sent by a `button` crumb.
-}
type Crumb msg
    = Crumb
        { label : String
        , target : Target msg
        , icon : Maybe Icon
        }


type Target msg
    = Href String
    | OnClick msg
    | NoTarget


{-| A level with a link. Use `#/path` for navigation inside a single page application.
The last crumb of a trail is always shown as the current page, as plain text, whether
or not it has a link.

    Breadcrumbs.link { label = "Customers", href = "#/customers" }

-}
link : { label : String, href : String } -> Crumb msg
link options =
    Crumb { label = options.label, target = Href options.href, icon = Nothing }


{-| A level that sends a message instead of following an address: the label, then the
message. For trails that are not routes, such as the folders of a file browser or the
levels of a drill-down in a chart; it looks like a link. As the last crumb it is the
current level and plain text, like any last crumb.

    Breadcrumbs.button "2025" (DrillUpTo Year)

-}
button : String -> msg -> Crumb msg
button label msg =
    Crumb { label = label, target = OnClick msg, icon = Nothing }


{-| A level without a link, just the label. The current page is always shown as
plain text, so the last crumb normally uses this. A level in the middle of the
trail that has no page of its own can use it too.

    Breadcrumbs.text "Ada Lovelace"

-}
text : String -> Crumb msg
text label =
    Crumb { label = label, target = NoTarget, icon = Nothing }


{-| An icon before the label, for example `Icon.home` on the first level. The icon
is decorative: the label still names the crumb.

    Breadcrumbs.link { label = "Home", href = "#/" }
        |> Breadcrumbs.withIcon Icon.home

-}
withIcon : Icon -> Crumb msg -> Crumb msg
withIcon icon (Crumb crumb) =
    Crumb { crumb | icon = Just icon }



-- ATTRIBUTES


{-| A setting of the trail. Make them with the functions below and pass a list to
`view` or `viewStatic`; later attributes win over earlier ones. The `msg` is your
message type, of the `button` crumbs.
-}
type Attribute msg
    = Attribute (Config msg -> Config msg)


type alias Config msg =
    { items : List (Crumb msg)
    , maxItems : Int
    , ariaLabel : Maybe String
    , locale : Locale
    }


configure : List (Attribute msg) -> Config msg
configure attributes =
    List.foldl (\(Attribute change) config -> change config)
        { items = []
        , maxItems = 4
        , ariaLabel = Nothing
        , locale = Locale.default
        }
        attributes


{-| The trail, from the top level to the current page, which comes last.
-}
items : List (Crumb msg) -> Attribute msg
items value =
    Attribute (\config -> { config | items = value })


{-| The most crumbs shown at once by `view`. Default 4; a smaller number counts as 2.
When the trail has at least two crumbs more, the first crumb and the last `n - 1`
crumbs stay visible and the ones between fold into the "more" button; a trail only
one crumb longer is shown whole. `viewStatic` shows every crumb.
-}
maxItems : Int -> Attribute msg
maxItems value =
    Attribute (\config -> { config | maxItems = max 2 value })


{-| The accessible name of the `nav` landmark. Default "Breadcrumb" (in the
language of `locale`).
-}
ariaLabel : String -> Attribute msg
ariaLabel value =
    Attribute (\config -> { config | ariaLabel = Just value })


{-| The language of the built-in text: the name of the `nav` landmark and of the
"more" button ("Show 3 hidden levels"). Default `Locale.en`.
-}
locale : Locale -> Attribute msg
locale value =
    Attribute (\config -> { config | locale = value })



-- STATE


{-| The state of a trail: whether the list of hidden levels is open. Make one
with `init`, keep it in your model, and give it to `view`. A trail shown with
`viewStatic` needs none.
-}
type State
    = State
        { id : String

        -- The hidden levels the list was opened for: a list opened for another
        -- trail (the route changed under it) is not drawn.
        , openFor : Maybe String
        }


{-| A trail with its list of hidden levels closed. The id must be unique on the
page: it is the prefix of the DOM ids of the "more" button and of the list that
it opens.

    Breadcrumbs.init "page-crumbs"

-}
init : String -> State
init id =
    State { id = id, openFor = Nothing }


{-| Whether the list of hidden levels has been opened and not closed since. The list
is only drawn while the trail still folds the same levels.
-}
isOpen : State -> Bool
isOpen (State state) =
    state.openFor /= Nothing


{-| The messages of a trail: the "more" button was used, a key was pressed in the
list of hidden levels. Wrap it in a constructor of your own message type, pass
that constructor to `view`, and hand the messages you get back to `update`.
-}
type Msg
    = Toggle String String
    | Open String String
    | Close
    | CloseQuiet
    | Focus String
    | Noop


{-| Opens and closes the list of hidden levels and moves keyboard focus into and
out of it. The `Cmd` does the focus move, so map it with your message
constructor.
-}
update : Msg -> State -> ( State, Cmd Msg )
update msg ((State state) as current) =
    case msg of
        Toggle signature firstId ->
            if state.openFor == Just signature then
                close current

            else
                ( State { state | openFor = Just signature }, Internal.focus firstId Noop )

        Open signature firstId ->
            ( State { state | openFor = Just signature }, Internal.focus firstId Noop )

        Close ->
            close current

        CloseQuiet ->
            -- Tab moves on by itself: focus must not be pulled back to the button.
            ( State { state | openFor = Nothing }, Cmd.none )

        Focus domId ->
            ( current, Internal.focus domId Noop )

        Noop ->
            ( current, Cmd.none )


{-| Closes the list of hidden levels and gives keyboard focus back to the "more"
button (only when the list was open). The list also closes by itself when the trail
changes, so this is for closing it from your own code, such as a shortcut.
-}
close : State -> ( State, Cmd Msg )
close (State state) =
    ( State { state | openFor = Nothing }
    , if state.openFor /= Nothing then
        Internal.focus (triggerId state.id) Noop

      else
        Cmd.none
    )


triggerId : String -> String
triggerId id =
    id ++ "-more"


popupId : String -> String
popupId id =
    id ++ "-hidden"


hiddenLinkId : String -> Int -> String
hiddenLinkId id index =
    id ++ "-hidden-" ++ String.fromInt index



-- VIEW


{-| How a trail of `total` crumbs folds for `maxItems`: the number of crumbs between the
first one and the visible tail that go into the "more" list, 0 when it shows whole.
-}
hiddenCount : Int -> Int -> Int
hiddenCount most total =
    if total - most >= 2 then
        total - most

    else
        0


{-| A trail that folds its middle into a "more" button when it has at least two crumbs
more than `maxItems`. The button opens a list of the hidden levels. The first argument
wraps the trail's `Msg` in your own message type.
-}
view : (Msg -> msg) -> List (Attribute msg) -> State -> Html msg
view toMsg attributes current =
    let
        config =
            configure attributes

        hiding =
            hiddenCount config.maxItems (List.length config.items)
    in
    if hiding > 0 then
        let
            visibleHead =
                List.take 1 config.items

            hidden =
                config.items |> List.drop 1 |> List.take hiding

            visibleTail =
                List.drop (1 + hiding) config.items
        in
        wrapper config
            (List.map (viewCrumb False) visibleHead
                ++ [ viewMore toMsg config current hidden ]
                ++ viewAll visibleTail
            )

    else
        wrapper config (viewAll config.items)


{-| A trail that always shows every level, however many. No state and no messages of
its own; a trail that does not fit on one line wraps onto more lines.

    Breadcrumbs.viewStatic
        [ Breadcrumbs.items
            [ Breadcrumbs.link { label = "Orders", href = "#/orders" }
            , Breadcrumbs.text "Order 10482"
            ]
        ]

-}
viewStatic : List (Attribute msg) -> Html msg
viewStatic attributes =
    let
        config =
            configure attributes
    in
    wrapper config (viewAll config.items)


wrapper : Config msg -> List (Html msg) -> Html msg
wrapper config children =
    Html.nav
        [ Internal.cls [ "klar-breadcrumbs" ]
        , Attr.attribute "aria-label"
            (Maybe.withDefault (Locale.pick config.locale { nb = "Brødsmulesti", en = "Breadcrumb" }) config.ariaLabel)
        ]
        [ Html.ol [ Internal.cls [ "klar-breadcrumbs__list" ] ] children ]


{-| The crumbs in order; the last of them is the current page.
-}
viewAll : List (Crumb msg) -> List (Html msg)
viewAll crumbs =
    let
        lastIndex =
            List.length crumbs - 1
    in
    List.indexedMap (\index crumb -> viewCrumb (index == lastIndex) crumb) crumbs


viewCrumb : Bool -> Crumb msg -> Html msg
viewCrumb isCurrent (Crumb crumb) =
    let
        content =
            [ Internal.viewMaybe Icon.view crumb.icon
            , Html.span [ Internal.cls [ "klar-breadcrumbs__label" ] ] [ Html.text crumb.label ]
            ]

        plain =
            Html.span
                [ Internal.cls
                    [ "klar-breadcrumbs__text"
                    , if isCurrent then
                        "klar-breadcrumbs__text--current"

                      else
                        ""
                    ]
                , Attr.title crumb.label
                , Internal.attrIf isCurrent (Attr.attribute "aria-current" "page")
                ]
                content
    in
    Html.li [ Internal.cls [ "klar-breadcrumbs__item" ] ]
        [ if isCurrent then
            plain

          else
            case crumb.target of
                Href href ->
                    Html.a
                        [ Internal.cls [ "klar-breadcrumbs__link" ]
                        , Attr.href href
                        , Attr.title crumb.label
                        ]
                        content

                OnClick msg ->
                    Html.button
                        [ Internal.cls [ "klar-breadcrumbs__link", "klar-breadcrumbs__link--button" ]
                        , Attr.type_ "button"
                        , Attr.title crumb.label
                        , Events.onClick msg
                        ]
                        content

                NoTarget ->
                    plain
        , Internal.viewIf (not isCurrent) separator
        ]


separator : Html msg
separator =
    Html.span [ Internal.cls [ "klar-breadcrumbs__separator" ], Attr.attribute "aria-hidden" "true" ]
        [ Icon.sized Icon.ExtraSmall Icon.chevronRight ]


isTarget : Crumb msg -> Bool
isTarget (Crumb crumb) =
    case crumb.target of
        NoTarget ->
            False

        _ ->
            True


viewMore : (Msg -> msg) -> Config msg -> State -> List (Crumb msg) -> Html msg
viewMore toMsg config (State state) hidden =
    let
        indexed =
            List.indexedMap Tuple.pair hidden

        focusable =
            indexed
                |> List.filterMap
                    (\( index, crumb ) ->
                        if isTarget crumb then
                            Just index

                        else
                            Nothing
                    )

        firstId =
            case focusable of
                first :: _ ->
                    hiddenLinkId state.id first

                [] ->
                    popupId state.id

        -- what the list is opened for: these hidden levels, in this order
        signature =
            hidden
                |> List.map (\(Crumb crumb) -> crumb.label)
                |> String.join "\n"

        open =
            state.openFor == Just signature

        count =
            List.length hidden

        label =
            Locale.pick config.locale
                { nb = "Vis " ++ String.fromInt count ++ " skjulte nivåer"
                , en = "Show " ++ String.fromInt count ++ " hidden levels"
                }
    in
    Html.li [ Internal.cls [ "klar-breadcrumbs__item", "klar-breadcrumbs__item--more" ] ]
        [ Html.div [ Internal.cls [ "klar-anchor" ] ]
            [ Button.iconOnly
                [ Button.ghost
                , Button.small
                , Button.id (triggerId state.id)
                , Button.expanded open
                , Button.htmlAttrs
                    -- A list of links, not a menu: `aria-expanded` and
                    -- `aria-controls`, no `aria-haspopup` (a screen reader would
                    -- announce a "menu button" and look for menu items).
                    [ Internal.attrIf open (Attr.attribute "aria-controls" (popupId state.id))
                    , Internal.onKeys [ ( "ArrowDown", toMsg (Open signature firstId) ) ]
                    ]
                , Button.onClick (toMsg (Toggle signature firstId))
                ]
                Icon.moreHorizontal
                label
            , if open then
                viewHidden toMsg state.id focusable indexed

              else
                Html.text ""
            ]
        , separator
        ]


{-| Escape closes the list and gives focus back to the button, and prevents its
default, so that a drawer or a dialog around the trail leaves that press alone; Tab and
Shift+Tab close it quietly and move on. The Escape that ends an IME composition is not
acted on.
-}
layerKeys : (Msg -> msg) -> Decoder ( msg, Bool )
layerKeys toMsg =
    Decode.map3
        (\key composing keyCode ->
            if composing || keyCode == 229 then
                Nothing

            else if key == "Escape" then
                Just ( toMsg Close, True )

            else if key == "Tab" then
                -- Shift+Tab too: its key is Tab as well
                Just ( toMsg CloseQuiet, False )

            else
                Nothing
        )
        (Decode.field "key" Decode.string)
        (Decode.oneOf [ Decode.field "isComposing" Decode.bool, Decode.succeed False ])
        (Decode.oneOf [ Decode.field "keyCode" Decode.int, Decode.succeed 0 ])
        |> Decode.andThen
            (\handled ->
                case handled of
                    Just result ->
                        Decode.succeed result

                    Nothing ->
                        Decode.fail "not a key of the list"
            )


viewHidden : (Msg -> msg) -> String -> List Int -> List ( Int, Crumb msg ) -> Html msg
viewHidden toMsg id focusable indexed =
    Html.div
        [ Internal.cls [ "klar-layer" ]
        , Events.onClick (toMsg Close)
        , Events.preventDefaultOn "keydown" (layerKeys toMsg)
        ]
        [ Html.div
            [ Internal.cls [ "klar-popup", "klar-breadcrumbs__popup" ]
            , Attr.id (popupId id)
            , Attr.tabindex -1
            ]
            [ Html.ul [ Internal.cls [ "klar-breadcrumbs__hidden" ] ]
                (List.map (viewHiddenCrumb toMsg id focusable) indexed)
            ]
        ]


viewHiddenCrumb : (Msg -> msg) -> String -> List Int -> ( Int, Crumb msg ) -> Html msg
viewHiddenCrumb toMsg id focusable ( index, Crumb crumb ) =
    let
        content =
            [ Internal.viewMaybe Icon.view crumb.icon
            , Html.span [ Internal.cls [ "klar-truncate" ] ] [ Html.text crumb.label ]
            ]

        count =
            List.length focusable

        position =
            focusable |> List.indexedMap Tuple.pair |> List.filter (\( _, i ) -> i == index) |> List.head |> Maybe.map Tuple.first

        -- the neighbour `offset` places away, wrapping around the ends
        at offset =
            case position of
                Just p ->
                    focusable |> List.drop (modBy count (p + offset)) |> List.head |> Maybe.map (hiddenLinkId id)

                Nothing ->
                    Nothing

        keys =
            List.filterMap identity
                [ at 1 |> Maybe.map (\target -> ( "ArrowDown", toMsg (Focus target) ))
                , at -1 |> Maybe.map (\target -> ( "ArrowUp", toMsg (Focus target) ))
                , focusable |> List.head |> Maybe.map (\i -> ( "Home", toMsg (Focus (hiddenLinkId id i)) ))
                , focusable |> List.reverse |> List.head |> Maybe.map (\i -> ( "End", toMsg (Focus (hiddenLinkId id i)) ))
                ]
    in
    Html.li []
        [ case crumb.target of
            Href href ->
                Html.a
                    [ Internal.cls [ "klar-breadcrumbs__hidden-item" ]
                    , Attr.href href
                    , Attr.id (hiddenLinkId id index)
                    , Internal.onKeys keys
                    ]
                    content

            OnClick msg ->
                -- The click also reaches the layer, which closes the list.
                Html.button
                    [ Internal.cls [ "klar-breadcrumbs__hidden-item", "klar-breadcrumbs__hidden-item--button" ]
                    , Attr.type_ "button"
                    , Attr.id (hiddenLinkId id index)
                    , Events.onClick msg
                    , Internal.onKeys keys
                    ]
                    content

            NoTarget ->
                Html.span [ Internal.cls [ "klar-breadcrumbs__hidden-item", "klar-breadcrumbs__hidden-item--text" ] ] content
        ]
