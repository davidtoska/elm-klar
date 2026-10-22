module Klar.Accordion exposing
    ( view
    , Section, section, lazySection, withSubtitle, withIcon, withCount, withBadge, disabledSection
    , Attribute, sections, multiple, bordered, flush, small, headingLevel
    , State, init, setMultiple, isOpen, openKeys, open, openMany, close, closeAll, toggle, Msg, update
    )

{-| Sections that open and close: the details of a record, groups of settings,
advanced filters.

Use when: sections of content should open and close in place, such as the details of a record or groups of settings.
Do not use when: the sections are views the user switches between (use `Klar.Tabs`).
Quick path: `init`, `update`, `view`, `isOpen`, `open`, `closeAll`

    import Klar.Accordion as Accordion

    -- model: accordion : Accordion.State
    -- init:  Accordion.init "order-sections"

    -- update
    AccordionMsg m ->
        let
            ( accordion, cmd ) =
                Accordion.update m model.accordion
        in
        ( { model | accordion = accordion }, Cmd.map AccordionMsg cmd )

    -- view
    Accordion.view AccordionMsg
        [ Accordion.sections
            [ Accordion.section "shipping" "Shipping address" [ shippingView model ]
            , Accordion.section "items" "Line items" [ itemsView model ]
                |> Accordion.withCount 4
            , Accordion.lazySection "log" "Activity log" (\_ -> [ logView model ])
            , Accordion.section "billing" "Billing" [ billingView model ]
                |> Accordion.disabledSection
            ]
        ]
        model.accordion

By default opening a section closes the others; `setMultiple True` on the state
lets several stay open. The body of a closed section is not rendered at all.
`section` still builds its content eagerly (Elm is strict), `lazySection` takes a
function so that the content of a closed section is never computed.

The state is the list of open section keys and that mode. Read it with `isOpen`
and `openKeys`, and change it from the application with `open`, `openMany`,
`close`, `closeAll` and `toggle`, for instance to open the section that holds a
field with an error. `open`, `toggle` and a click on a header all follow the mode
of the state, so they never disagree: in the default mode they leave only the
opened section open, after `setMultiple True` they leave the others alone.
`openMany` sets exactly which sections are open, whatever the mode. The
`multiple` attribute of `view` still works, but it only affects clicks, so prefer
`setMultiple`.

Each header is a button inside a heading (level 3 unless you set `headingLevel`)
with `aria-expanded`. With six sections or fewer an open body is also a `region`
named by its header; with more, the bodies are left out of the landmarks so that
the page does not get a long list of them.

Keyboard: Enter and Space toggle the focused header. Arrow Up and Down move to
the previous and next enabled header, wrapping around at the ends, Home and End
to the first and last.


# View

@docs view


# Sections

@docs Section, section, lazySection, withSubtitle, withIcon, withCount, withBadge, disabledSection


# Attributes

@docs Attribute, sections, multiple, bordered, flush, small, headingLevel


# State

@docs State, init, setMultiple, isOpen, openKeys, open, openMany, close, closeAll, toggle, Msg, update

-}

import Html exposing (Html)
import Html.Attributes as Attr
import Html.Events as Events
import Klar.Icon as Icon exposing (Icon)
import Klar.Internal as Internal



-- SECTIONS


{-| One section of the accordion: a header and a body. Make it with `section` or
`lazySection` and refine it with `withSubtitle`, `withIcon`, `withCount`,
`withBadge` and `disabledSection`. The `msg` is the message type of the Html in
the body and in `withBadge`.
-}
type Section msg
    = Section
        { key : String
        , title : String
        , subtitle : Maybe String
        , icon : Maybe Icon
        , count : Maybe Int
        , badge : Maybe (Html msg)
        , disabled : Bool
        , content : () -> List (Html msg)
        }


{-| A section: the key, the title and the content of its body. The key identifies
the section in the state (`isOpen`, `open` and the others) and must be unique
within the accordion; the title is the text of the header.

    Accordion.section "shipping" "Shipping address" [ shippingView model ]

-}
section : String -> String -> List (Html msg) -> Section msg
section key title content =
    lazySection key title (\_ -> content)


{-| Like `section`, but the content is a function that is only called while the
section is open, so the content of a closed section is never computed. Use it for
bodies that are expensive to build.

    Accordion.lazySection "log" "Activity log" (\_ -> [ logView model ])

-}
lazySection : String -> String -> (() -> List (Html msg)) -> Section msg
lazySection key title content =
    Section
        { key = key
        , title = title
        , subtitle = Nothing
        , icon = Nothing
        , count = Nothing
        , badge = Nothing
        , disabled = False
        , content = content
        }


{-| A line of small gray text in the header, after the title. It is cut with an
ellipsis when the header is too narrow.
-}
withSubtitle : String -> Section msg -> Section msg
withSubtitle text (Section config) =
    Section { config | subtitle = Just text }


{-| An icon before the title. It is decorative: the title still names the header.
-}
withIcon : Icon -> Section msg -> Section msg
withIcon icon (Section config) =
    Section { config | icon = Just icon }


{-| A small number pill at the right end of the header, such as the number of
items in the section. It is shown as it is, without shortening large numbers.
-}
withCount : Int -> Section msg -> Section msg
withCount n (Section config) =
    Section { config | count = Just n }


{-| Any badge or status at the right end of the header, after the count if there
is one.

    Accordion.section "billing" "Billing" [ billingView model ]
        |> Accordion.withBadge (Badge.view [ Badge.tone Warning ] "Overdue")

-}
withBadge : Html msg -> Section msg -> Section msg
withBadge html (Section config) =
    Section { config | badge = Just html }


{-| Visible but cannot be opened: the header is a disabled button and the arrow
keys skip it. A disabled section is shown closed even when its key is in the
state.
-}
disabledSection : Section msg -> Section msg
disabledSection (Section config) =
    Section { config | disabled = True }



-- ATTRIBUTES


{-| A setting of the accordion. Make them with the functions below and pass a
list to `view`; later attributes win over earlier ones.
-}
type Attribute msg
    = Attribute (Config msg -> Config msg)


type alias Config msg =
    { sections : List (Section msg)
    , multiple : Bool
    , flush : Bool
    , small : Bool
    , headingLevel : Int
    }


configure : List (Attribute msg) -> Config msg
configure attributes =
    List.foldl (\(Attribute change) config -> change config)
        { sections = []
        , multiple = False
        , flush = False
        , small = False
        , headingLevel = 3
        }
        attributes


{-| The sections, from top to bottom. Their keys must be unique.
-}
sections : List (Section msg) -> Attribute msg
sections value =
    Attribute (\config -> { config | sections = value })


{-| Lets several sections stay open when the user clicks headers. It is the same
as `setMultiple True` on the state, but only for clicks: `open` and `toggle` obey
the state alone, so prefer `setMultiple`. Without either, a click on the header of
a closed section opens that section and closes all the others.
-}
multiple : Attribute msg
multiple =
    Attribute (\config -> { config | multiple = True })


{-| A thin gray border around the whole accordion and a line between the sections,
on a white background. This is the default; it undoes an earlier `flush`.
-}
bordered : Attribute msg
bordered =
    Attribute (\config -> { config | flush = False })


{-| No outer border and no background, only a thin line under each section and
above the first one. For use inside a card or a drawer.
-}
flush : Attribute msg
flush =
    Attribute (\config -> { config | flush = True })


{-| Lower headers with smaller text, for dense panels.
-}
small : Attribute msg
small =
    Attribute (\config -> { config | small = True })


{-| The level, 1 to 6, of the heading element that wraps each header button
(`h3` by default; other numbers are moved into that range). Pick the level that
fits below the headings of the page around the accordion, so that the outline of
the page stays correct.
-}
headingLevel : Int -> Attribute msg
headingLevel level =
    Attribute (\config -> { config | headingLevel = clamp 1 6 level })



-- STATE


{-| The state of an accordion: the keys of the open sections, and whether several
may be open at once. Make one with `init`, keep it in your model, and give it to
`view`.
-}
type State
    = State
        { id : String
        , open : List String
        , multiple : Bool
        }


{-| An accordion with every section closed, in the default mode: opening a section
closes the others. The id must be unique on the page: it is the prefix of the DOM
ids of the headers and bodies.

    Accordion.init "order-sections"

-}
init : String -> State
init id =
    State { id = id, open = [], multiple = False }


{-| Sets the mode of the state. With `True` several sections can be open at once;
with `False`, the default, opening a section closes the others. `open`, `toggle`
and a click on a header all follow it. Sections that are open now stay open.

    Accordion.init "order-sections" |> Accordion.setMultiple True

-}
setMultiple : Bool -> State -> State
setMultiple value (State state) =
    State { state | multiple = value }


{-| Whether the section with this key is open.
-}
isOpen : String -> State -> Bool
isOpen key (State state) =
    List.member key state.open


{-| The keys of the open sections, in the order they were opened. Save them to
restore the accordion later with `openMany`.
-}
openKeys : State -> List String
openKeys (State state) =
    state.open


{-| Opens one section, like a click on its header does: in the default mode the
other sections are closed, after `setMultiple True` they stay as they are. Use
`openMany` to set exactly which sections are open.
-}
open : String -> State -> State
open key ((State state) as current) =
    openIn state.multiple key current


{-| Opens a section; with `several` the sections that are open stay open, without
it the section is the only one that is open.
-}
openIn : Bool -> String -> State -> State
openIn several key (State state) =
    if not several then
        State { state | open = [ key ] }

    else if List.member key state.open then
        State state

    else
        State { state | open = state.open ++ [ key ] }


{-| Opens exactly these sections and closes all the others, whatever the mode, for
example to restore what the user had open.
-}
openMany : List String -> State -> State
openMany keys (State state) =
    State { state | open = keys }


{-| Closes one section.
-}
close : String -> State -> State
close key (State state) =
    State { state | open = List.filter (\other -> other /= key) state.open }


{-| Closes every section.
-}
closeAll : State -> State
closeAll (State state) =
    State { state | open = [] }


{-| Opens a closed section, as `open` does, and closes an open one, like a click on
its header does. In the default mode opening a section closes the others.
-}
toggle : String -> State -> State
toggle key state =
    if isOpen key state then
        close key state

    else
        open key state


{-| The messages of an accordion: a header was clicked, an arrow key was pressed.
Wrap it in a constructor of your own message type, pass that constructor to
`view`, and hand the messages you get back to `update`.
-}
type Msg
    = Toggle String Bool
    | Focus String
    | Noop


{-| Opens and closes sections when their headers are clicked, and moves keyboard
focus between the headers. The `Cmd` does the focus move, so map it with your
message constructor.
-}
update : Msg -> State -> ( State, Cmd Msg )
update msg ((State state) as current) =
    case msg of
        Toggle key exclusive ->
            if isOpen key current then
                ( close key current, Cmd.none )

            else
                -- the state and the `multiple` attribute of the view can each allow several
                ( openIn (state.multiple || not exclusive) key current, Cmd.none )

        Focus domId ->
            ( current, Internal.focus domId Noop )

        Noop ->
            ( current, Cmd.none )


headerId : String -> String -> String
headerId id key =
    id ++ "-header-" ++ Internal.sanitizeId key


bodyId : String -> String -> String
bodyId id key =
    id ++ "-body-" ++ Internal.sanitizeId key



-- VIEW


{-| The accordion. The first argument wraps the accordion's `Msg` in your own
message type. Closed sections render only their header.
-}
view : (Msg -> msg) -> List (Attribute msg) -> State -> Html msg
view toMsg attributes ((State state) as current) =
    let
        config =
            configure attributes

        enabledKeys =
            config.sections
                |> List.filterMap
                    (\(Section data) ->
                        if data.disabled then
                            Nothing

                        else
                            Just data.key
                    )

        landmarks =
            List.length config.sections <= 6
    in
    Html.div
        [ Internal.cls
            [ "klar-accordion"
            , if config.flush then
                "klar-accordion--flush"

              else
                "klar-accordion--bordered"
            , if config.small then
                "klar-accordion--sm"

              else
                ""
            ]
        ]
        (List.map (viewSection toMsg config landmarks state.id enabledKeys current) config.sections)


viewSection : (Msg -> msg) -> Config msg -> Bool -> String -> List String -> State -> Section msg -> Html msg
viewSection toMsg config landmarks id enabledKeys current (Section data) =
    let
        expanded =
            isOpen data.key current && not data.disabled

        neighbour offset =
            case indexOf data.key enabledKeys of
                Just index ->
                    enabledKeys
                        |> List.drop (modBy (List.length enabledKeys) (index + offset))
                        |> List.head
                        |> Maybe.map (headerId id)

                Nothing ->
                    Nothing

        keys =
            List.filterMap identity
                [ neighbour 1 |> Maybe.map (\target -> ( "ArrowDown", toMsg (Focus target) ))
                , neighbour -1 |> Maybe.map (\target -> ( "ArrowUp", toMsg (Focus target) ))
                , List.head enabledKeys |> Maybe.map (\key -> ( "Home", toMsg (Focus (headerId id key)) ))
                , List.head (List.reverse enabledKeys) |> Maybe.map (\key -> ( "End", toMsg (Focus (headerId id key)) ))
                ]

        heading =
            Internal.heading config.headingLevel
    in
    Html.div
        [ Internal.cls
            [ "klar-accordion__section"
            , if expanded then
                "klar-accordion__section--open"

              else
                ""
            , if data.disabled then
                "klar-accordion__section--disabled"

              else
                ""
            ]
        ]
        [ heading [ Internal.cls [ "klar-accordion__heading" ] ]
            [ Html.button
                ([ Internal.cls [ "klar-accordion__header" ]
                 , Attr.id (headerId id data.key)
                 , Attr.type_ "button"
                 , Attr.attribute "aria-expanded"
                    (if expanded then
                        "true"

                     else
                        "false"
                    )
                 , Internal.attrIf expanded (Attr.attribute "aria-controls" (bodyId id data.key))
                 , Attr.disabled data.disabled
                 ]
                    ++ (if data.disabled then
                            []

                        else
                            [ Events.onClick (toMsg (Toggle data.key (not config.multiple)))
                            , Internal.onKeys keys
                            ]
                       )
                )
                [ Html.span [ Internal.cls [ "klar-accordion__chevron" ] ] [ Icon.view Icon.chevronRight ]
                , Internal.viewMaybe
                    (\icon -> Html.span [ Internal.cls [ "klar-accordion__icon" ] ] [ Icon.view icon ])
                    data.icon
                , Html.span [ Internal.cls [ "klar-accordion__title" ] ] [ Html.text data.title ]
                , Internal.viewMaybe
                    (\text -> Html.span [ Internal.cls [ "klar-accordion__subtitle" ] ] [ Html.text text ])
                    data.subtitle
                , Html.span [ Internal.cls [ "klar-accordion__aside" ] ]
                    [ Internal.viewMaybe
                        (\n -> Html.span [ Internal.cls [ "klar-accordion__count", "klar-tabular" ] ] [ Html.text (String.fromInt n) ])
                        data.count
                    , Internal.viewMaybe identity data.badge
                    ]
                ]
            ]
        , if expanded then
            Html.div
                [ Internal.cls [ "klar-accordion__body" ]
                , Attr.id (bodyId id data.key)
                , Internal.attrIf landmarks (Attr.attribute "role" "region")
                , Internal.attrIf landmarks (Attr.attribute "aria-labelledby" (headerId id data.key))
                ]
                (data.content ())

          else
            Html.text ""
        ]


indexOf : String -> List String -> Maybe Int
indexOf target list =
    list
        |> List.indexedMap Tuple.pair
        |> List.filter (\( _, key ) -> key == target)
        |> List.head
        |> Maybe.map Tuple.first
