module Klar.Breadcrumbs exposing
    ( view, static
    , Crumb, link, text, withIcon
    , Attribute, items, maxItems, ariaLabel, locale
    , State, init, isOpen, close, Msg, update
    )

{-| The path to the current page: links separated by chevrons, where the last item
is the current page.

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
            [ Breadcrumbs.link "Home" "#/"
            , Breadcrumbs.link "Customers" "#/customers"
            , Breadcrumbs.text "Ada Lovelace"
            ]
        ]
        model.crumbs

When there are more than `maxItems` crumbs, the first crumb and the last
`maxItems - 1` crumbs stay visible and the ones in between fold into a "more"
button that opens a small list of links (Escape closes it, the arrow keys move
between the links). The state only remembers whether that list is open. A trail
that never grows long needs no state: use `static`.

The last crumb is always the current page: it is shown as plain text and marked
with `aria-current="page"`, even if it was made with `link`. Every other crumb
that has a link is a real link, so routing, middle click and "open in new tab"
work as usual. The built-in text (the name of the navigation landmark and of the
"more" button) follows `locale`, English by default.


# Views

@docs view, static


# Crumbs

@docs Crumb, link, text, withIcon


# Attributes

@docs Attribute, items, maxItems, ariaLabel, locale


# State

@docs State, init, isOpen, close, Msg, update

-}

import Html exposing (Html)
import Html.Attributes as Attr
import Html.Events as Events
import Klar.Button as Button
import Klar.Icon as Icon exposing (Icon)
import Klar.Internal as Internal
import Klar.Locale as Locale exposing (Locale)



-- CRUMBS


{-| One level of the trail. Make it with `link` or `text` and refine it with
`withIcon`.
-}
type Crumb
    = Crumb
        { label : String
        , href : Maybe String
        , icon : Maybe Icon
        }


{-| A level with a link: the label first, then the URL. Use `#/path` for
navigation inside a single page application. The last crumb of a trail is always
shown as the current page, as plain text, whether or not it has a link.

    Breadcrumbs.link "Customers" "#/customers"

-}
link : String -> String -> Crumb
link label href =
    Crumb { label = label, href = Just href, icon = Nothing }


{-| A level without a link, just the label. The current page is always shown as
plain text, so the last crumb normally uses this. A level in the middle of the
trail that has no page of its own can use it too.

    Breadcrumbs.text "Ada Lovelace"

-}
text : String -> Crumb
text label =
    Crumb { label = label, href = Nothing, icon = Nothing }


{-| An icon before the label, for example `Icon.home` on the first level. The icon
is decorative: the label still names the crumb.

    Breadcrumbs.link "Home" "#/"
        |> Breadcrumbs.withIcon Icon.home

-}
withIcon : Icon -> Crumb -> Crumb
withIcon icon (Crumb crumb) =
    Crumb { crumb | icon = Just icon }



-- ATTRIBUTES


{-| A setting of the trail. Make them with the functions below and pass a list to
`view` or `static`; later attributes win over earlier ones. Breadcrumbs send no
messages of their own, so the type has no `msg` parameter.
-}
type Attribute
    = Attribute (Config -> Config)


type alias Config =
    { items : List Crumb
    , maxItems : Int
    , ariaLabel : Maybe String
    , locale : Locale
    }


configure : List Attribute -> Config
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
items : List Crumb -> Attribute
items value =
    Attribute (\config -> { config | items = value })


{-| The most crumbs shown at once. Default 4; a smaller number counts as 2. When
the trail is longer, the first crumb and the last `n - 1` crumbs stay visible and
the ones between fold into the "more" button (only `view` folds a trail, `static`
shows every crumb).
-}
maxItems : Int -> Attribute
maxItems value =
    Attribute (\config -> { config | maxItems = max 2 value })


{-| The accessible name of the `nav` landmark. Default "Breadcrumb" (in the
language of `locale`).
-}
ariaLabel : String -> Attribute
ariaLabel value =
    Attribute (\config -> { config | ariaLabel = Just value })


{-| The language of the built-in text: the name of the `nav` landmark and of the
"more" button ("Show 3 hidden levels"). Default `Locale.en`.
-}
locale : Locale -> Attribute
locale value =
    Attribute (\config -> { config | locale = value })



-- STATE


{-| The state of a trail: whether the list of hidden levels is open. Make one
with `init`, keep it in your model, and give it to `view`. A trail shown with
`static` needs none.
-}
type State
    = State
        { id : String
        , open : Bool
        }


{-| A trail with its list of hidden levels closed. The id must be unique on the
page: it is the prefix of the DOM ids of the "more" button and of the list that
it opens.

    Breadcrumbs.init "page-crumbs"

-}
init : String -> State
init id =
    State { id = id, open = False }


{-| Whether the list of hidden levels has been opened and not closed since. The
list is only drawn while the trail is long enough to fold.
-}
isOpen : State -> Bool
isOpen (State state) =
    state.open


{-| The messages of a trail: the "more" button was used, a key was pressed in the
list of hidden levels. Wrap it in a constructor of your own message type, pass
that constructor to `view`, and hand the messages you get back to `update`.
-}
type Msg
    = Toggle String
    | Open String
    | Close
    | Focus String
    | Noop


{-| Opens and closes the list of hidden levels and moves keyboard focus into and
out of it. The `Cmd` does the focus move, so map it with your message
constructor.
-}
update : Msg -> State -> ( State, Cmd Msg )
update msg ((State state) as current) =
    case msg of
        Toggle firstId ->
            if state.open then
                close current

            else
                ( State { state | open = True }, Internal.focus firstId Noop )

        Open firstId ->
            ( State { state | open = True }, Internal.focus firstId Noop )

        Close ->
            close current

        Focus domId ->
            ( current, Internal.focus domId Noop )

        Noop ->
            ( current, Cmd.none )


{-| Closes the list of hidden levels and gives keyboard focus back to the "more"
button (only when the list was open). Use it to close the list from your own
code, for instance when the route changes while the list is open.
-}
close : State -> ( State, Cmd Msg )
close (State state) =
    ( State { state | open = False }
    , if state.open then
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


{-| A trail that folds its middle into a "more" button when it has more than
`maxItems` crumbs. The button opens a list of the hidden levels. The first
argument wraps the trail's `Msg` in your own message type.
-}
view : (Msg -> msg) -> List Attribute -> State -> Html msg
view toMsg attributes current =
    let
        config =
            configure attributes

        total =
            List.length config.items

        collapsed =
            total > config.maxItems

        hiddenCount =
            total - config.maxItems
    in
    if collapsed then
        let
            visibleHead =
                List.take 1 config.items

            hidden =
                config.items |> List.drop 1 |> List.take hiddenCount

            visibleTail =
                List.drop (1 + hiddenCount) config.items
        in
        wrapper config
            (List.map (viewCrumb False) visibleHead
                ++ [ viewMore toMsg config current hidden ]
                ++ viewTail visibleTail
            )

    else
        wrapper config (viewAll config.items)


{-| A trail that always shows every level, however many. No state and no
messages; a trail that does not fit on one line wraps onto more lines.

    Breadcrumbs.static
        [ Breadcrumbs.items
            [ Breadcrumbs.link "Orders" "#/orders"
            , Breadcrumbs.text "Order 10482"
            ]
        ]

-}
static : List Attribute -> Html msg
static attributes =
    let
        config =
            configure attributes
    in
    wrapper config (viewAll config.items)


wrapper : Config -> List (Html msg) -> Html msg
wrapper config children =
    Html.nav
        [ Internal.cls [ "klar-breadcrumbs" ]
        , Attr.attribute "aria-label"
            (Maybe.withDefault (Locale.pick config.locale { nb = "Brødsmulesti", en = "Breadcrumb" }) config.ariaLabel)
        ]
        [ Html.ol [ Internal.cls [ "klar-breadcrumbs__list" ] ] children ]


viewAll : List Crumb -> List (Html msg)
viewAll crumbs =
    let
        lastIndex =
            List.length crumbs - 1
    in
    List.indexedMap (\index crumb -> viewCrumb (index == lastIndex) crumb) crumbs


{-| The tail always ends with the current page.
-}
viewTail : List Crumb -> List (Html msg)
viewTail crumbs =
    viewAll crumbs


viewCrumb : Bool -> Crumb -> Html msg
viewCrumb isCurrent (Crumb crumb) =
    let
        content =
            [ Internal.viewMaybe Icon.view crumb.icon
            , Html.span [ Internal.cls [ "klar-breadcrumbs__label" ] ] [ Html.text crumb.label ]
            ]
    in
    Html.li [ Internal.cls [ "klar-breadcrumbs__item" ] ]
        [ case ( isCurrent, crumb.href ) of
            ( False, Just href ) ->
                Html.a
                    [ Internal.cls [ "klar-breadcrumbs__link" ]
                    , Attr.href href
                    , Attr.title crumb.label
                    ]
                    content

            _ ->
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
        , Internal.viewIf (not isCurrent) separator
        ]


separator : Html msg
separator =
    Html.span [ Internal.cls [ "klar-breadcrumbs__separator" ], Attr.attribute "aria-hidden" "true" ]
        [ Icon.sized Icon.ExtraSmall Icon.chevronRight ]


viewMore : (Msg -> msg) -> Config -> State -> List Crumb -> Html msg
viewMore toMsg config (State state) hidden =
    let
        indexed =
            List.indexedMap Tuple.pair hidden

        focusable =
            indexed
                |> List.filterMap
                    (\( index, Crumb crumb ) ->
                        if crumb.href /= Nothing then
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

        label =
            Locale.pick config.locale
                { nb = "Vis " ++ String.fromInt (List.length hidden) ++ " skjulte nivåer"
                , en = "Show " ++ String.fromInt (List.length hidden) ++ " hidden levels"
                }
    in
    Html.li [ Internal.cls [ "klar-breadcrumbs__item", "klar-breadcrumbs__item--more" ] ]
        [ Html.div [ Internal.cls [ "klar-anchor" ] ]
            [ Button.iconOnly
                [ Button.ghost
                , Button.small
                , Button.id (triggerId state.id)
                , Button.expanded state.open
                , Button.htmlAttrs
                    -- A list of links, not a menu: `aria-expanded` and
                    -- `aria-controls`, no `aria-haspopup` (a screen reader would
                    -- announce a "menu button" and look for menu items).
                    [ Internal.attrIf state.open (Attr.attribute "aria-controls" (popupId state.id))
                    , Internal.onKeys [ ( "ArrowDown", toMsg (Open firstId) ) ]
                    ]
                , Button.onClick (toMsg (Toggle firstId))
                ]
                Icon.moreHorizontal
                label
            , if state.open then
                viewHidden toMsg state.id focusable indexed

              else
                Html.text ""
            ]
        , separator
        ]


viewHidden : (Msg -> msg) -> String -> List Int -> List ( Int, Crumb ) -> Html msg
viewHidden toMsg id focusable indexed =
    Html.div
        [ Internal.cls [ "klar-layer" ]
        , Events.onClick (toMsg Close)
        , Internal.onKeysPassive
            [ ( "Escape", toMsg Close )
            , ( "Tab", toMsg Close )
            , ( "Shift+Tab", toMsg Close )
            ]
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


viewHiddenCrumb : (Msg -> msg) -> String -> List Int -> ( Int, Crumb ) -> Html msg
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
        [ case crumb.href of
            Just href ->
                Html.a
                    [ Internal.cls [ "klar-breadcrumbs__hidden-item" ]
                    , Attr.href href
                    , Attr.id (hiddenLinkId id index)
                    , Internal.onKeys keys
                    ]
                    content

            Nothing ->
                Html.span [ Internal.cls [ "klar-breadcrumbs__hidden-item", "klar-breadcrumbs__hidden-item--text" ] ] content
        ]
