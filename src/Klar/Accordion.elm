module Klar.Accordion exposing
    ( view
    , Section, section, lazySection, withSubtitle, withIcon, withCount, withBadge, disabledSection
    , Attribute, bordered, flush, small, headingLevel
    , State, init, setMultiple, Msg, update
    , isExpanded, expandedIds, expand, collapse, toggle, expandAll, collapseAll, setExpandedIds
    )

{-| Sections that open and close in place: the details of a record, groups of
settings, advanced filters.

Use when: sections of content should open and close in place, such as the details of a record or groups of settings.
Do not use when: the sections are views the user switches between (use `Klar.Tabs`), or one block of content opens on its own (a `Klar.Card` with a button of your own).
Quick path: `init`, `update`, `view`, `section`, `isExpanded`, `expand`

    import Klar.Accordion as Accordion
    import Klar.Ids as Ids exposing (Ids)

    type OrderSection
        = Shipping
        | Items
        | Log

    sectionIds : Ids OrderSection
    sectionIds =
        Ids.list
            (\key ->
                case key of
                    Shipping ->
                        "shipping"

                    Items ->
                        "items"

                    Log ->
                        "log"
            )
            [ Shipping, Items, Log ]

Then the model, the update and the view:

    -- model: accordion : Accordion.State OrderSection
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
        []
        model.accordion
        [ Accordion.section sectionIds Shipping "Shipping address" [ shippingView model ]
        , Accordion.section sectionIds Items "Line items" [ itemsView model ]
            |> Accordion.withCount 4
        , Accordion.lazySection sectionIds Log "Activity log" (\_ -> [ logView model ])
        ]

The sections are keyed by a type of your own (`OrderSection`), compared with
`==`, so a typo is a compile error and not a section that silently never opens.
The [Klar.Ids](Klar-Ids) writes a key as text once, for the DOM ids of the
headers and bodies; plain text keys take `Ids.string`.

By default opening a section closes the others; `setMultiple True` on the state
lets several stay open. The state is the list of open sections and that mode.
Read it with `isExpanded` and `expandedIds`, and change it from the application
with `expand`, `collapse`, `toggle`, `expandAll`, `collapseAll` and
`setExpandedIds`, for instance to open the section that holds a field with an
error. `expand`, `toggle` and a click on a header all follow the mode of the
state, so they never disagree: in the default mode they leave only the opened
section open, after `setMultiple True` they leave the others alone.
`setExpandedIds` sets exactly which sections are open and `expandAll` opens a list
of them, whatever the mode.

The body of a closed `section` stays in the page, hidden (`hidden="until-found"`):
the find-in-page of the browser finds its text, and a link to an id inside it
opens the section by itself (in Chrome and Edge; elsewhere it is plain hidden). A
closed body is built at a size of zero, so content that measures itself (a chart,
a `Klar.VirtualList`, a `Klar.Splitter`) belongs in a `lazySection`, which takes a
function: the content of a closed one is never computed and not in the page.

Each header is a button inside a heading (level 3 unless you set `headingLevel`)
with `aria-expanded`. With six sections or fewer a body is also a `region` named
by its header; with more, the bodies are left out of the landmarks so that the
page does not get a long list of them. The sections are keyed, so a section that
appears above the focused header does not move the focus to another section.

Keyboard: Enter and Space toggle the focused header. Arrow Up and Down move to
the previous and next enabled header, wrapping around at the ends, Home and End
to the first and last.


# View

@docs view


# Sections

@docs Section, section, lazySection, withSubtitle, withIcon, withCount, withBadge, disabledSection


# Attributes

@docs Attribute, bordered, flush, small, headingLevel


# State

@docs State, init, setMultiple, Msg, update


# Open sections

@docs isExpanded, expandedIds, expand, collapse, toggle, expandAll, collapseAll, setExpandedIds

-}

import Html exposing (Html)
import Html.Attributes as Attr
import Html.Events as Events
import Html.Keyed as Keyed
import Json.Decode as Decode
import Klar.Icon as Icon exposing (Icon)
import Klar.Ids as Ids exposing (Ids)
import Klar.Internal as Internal



-- SECTIONS


{-| One section of the accordion: a header and a body. Make it with `section` or
`lazySection` and refine it with `withSubtitle`, `withIcon`, `withCount`,
`withBadge` and `disabledSection`. The `key` is your type of section keys, the
`msg` the message type of the Html in the body and in `withBadge`.
-}
type Section key msg
    = Section
        { key : key
        , domKey : String
        , title : String
        , subtitle : Maybe String
        , icon : Maybe Icon
        , count : Maybe Int
        , badge : Maybe (Html msg)
        , disabled : Bool
        , lazy : Bool
        , content : () -> List (Html msg)
        }


{-| A section: the `Ids` of your key type, the key, the title and the content of
its body. The key identifies the section in the state (`isExpanded`, `expand` and
the others) and must be unique within the accordion; the title is the text of the
header.

    Accordion.section sectionIds Shipping "Shipping address" [ shippingView model ]

The body of a closed section stays in the page, hidden, so that find-in-page
reaches it (see the top of this page). It is built at a size of zero, so use
`lazySection` for a body that is expensive to build or that measures itself.

-}
section : Ids key -> key -> String -> List (Html msg) -> Section key msg
section ids key title content =
    make False ids key title (\_ -> content)


{-| Like `section`, but the content is a function that is only called while the
section is open, so the content of a closed section is never computed and not in
the page. Use it for bodies that are expensive to build.

    Accordion.lazySection sectionIds Log "Activity log" (\_ -> [ logView model ])

-}
lazySection : Ids key -> key -> String -> (() -> List (Html msg)) -> Section key msg
lazySection =
    make True


make : Bool -> Ids key -> key -> String -> (() -> List (Html msg)) -> Section key msg
make lazy ids key title content =
    Section
        { key = key
        , domKey = Ids.toKey ids key
        , title = title
        , subtitle = Nothing
        , icon = Nothing
        , count = Nothing
        , badge = Nothing
        , disabled = False
        , lazy = lazy
        , content = content
        }


{-| A line of small gray text in the header, after the title. It is cut with an
ellipsis when the header is too narrow.
-}
withSubtitle : String -> Section key msg -> Section key msg
withSubtitle text (Section config) =
    Section { config | subtitle = Just text }


{-| An icon before the title. It is decorative: the title still names the header.
-}
withIcon : Icon -> Section key msg -> Section key msg
withIcon icon (Section config) =
    Section { config | icon = Just icon }


{-| A small number pill at the right end of the header, such as the number of
items in the section. It is shown as it is, without shortening large numbers.
-}
withCount : Int -> Section key msg -> Section key msg
withCount n (Section config) =
    Section { config | count = Just n }


{-| A badge or status at the right end of the header, after the count if there
is one. It is drawn inside the header button, so it must not be a button or a
link itself (a click on it opens and closes the section).

    Accordion.section sectionIds Billing "Billing" [ billingView model ]
        |> Accordion.withBadge (Badge.view [ Badge.tone Warning ] "Overdue")

-}
withBadge : Html msg -> Section key msg -> Section key msg
withBadge html (Section config) =
    Section { config | badge = Just html }


{-| Visible but cannot be opened: the header is a disabled button and the arrow
keys skip it. A disabled section is shown closed even when its key is in the
state.
-}
disabledSection : Section key msg -> Section key msg
disabledSection (Section config) =
    Section { config | disabled = True }



-- ATTRIBUTES


{-| A setting of the accordion. Make them with the functions below and pass a
list to `view`; later attributes win over earlier ones.
-}
type Attribute msg
    = Attribute (Config -> Config)


type alias Config =
    { flush : Bool
    , small : Bool
    , headingLevel : Int
    }


configure : List (Attribute msg) -> Config
configure attributes =
    List.foldl (\(Attribute change) config -> change config)
        { flush = False
        , small = False
        , headingLevel = 3
        }
        attributes


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
`view`. The `key` is your type of section keys.
-}
type State key
    = State
        { id : String
        , open : List key
        , multiple : Bool
        }


{-| An accordion with every section closed, in the default mode: opening a section
closes the others. The id must be unique on the page: it is the prefix of the DOM
ids of the headers and bodies.

    Accordion.init "order-sections"

-}
init : String -> State key
init id =
    State { id = id, open = [], multiple = False }


{-| Sets the mode of the state, the one place where it is set. With `True` several
sections can be open at once; with `False`, the default, opening a section closes
the others. `expand`, `toggle` and a click on a header all follow it. Sections
that are open now stay open.

    Accordion.init "order-sections" |> Accordion.setMultiple True

-}
setMultiple : Bool -> State key -> State key
setMultiple value (State state) =
    State { state | multiple = value }


{-| Whether the section with this key is open.
-}
isExpanded : key -> State key -> Bool
isExpanded key (State state) =
    List.member key state.open


{-| The keys of the open sections, in the order they were opened. Save them to
restore the accordion later with `setExpandedIds`.
-}
expandedIds : State key -> List key
expandedIds (State state) =
    state.open


{-| Opens one section, like a click on its header does: in the default mode the
other sections are closed, after `setMultiple True` they stay as they are. Use
`setExpandedIds` to set exactly which sections are open.
-}
expand : key -> State key -> State key
expand key (State state) =
    if not state.multiple then
        State { state | open = [ key ] }

    else if List.member key state.open then
        State state

    else
        State { state | open = state.open ++ [ key ] }


{-| Opens exactly these sections and closes all the others, whatever the mode, for
example to restore what the user had open.
-}
setExpandedIds : List key -> State key -> State key
setExpandedIds keys (State state) =
    State { state | open = keys }


{-| Opens every section of this list of keys, whatever the mode; sections that are
open stay open, and the new ones come after them in `expandedIds`. Give it the keys
of all your sections, such as the list you gave to `Ids.list`. A
`disabledSection` is drawn closed even when its key is open.

    Accordion.expandAll [ Shipping, Items, Log ] model.accordion

-}
expandAll : List key -> State key -> State key
expandAll keys (State state) =
    State
        { state
            | open =
                List.foldl
                    (\key open ->
                        if List.member key open then
                            open

                        else
                            open ++ [ key ]
                    )
                    state.open
                    keys
        }


{-| Closes one section.
-}
collapse : key -> State key -> State key
collapse key (State state) =
    State { state | open = List.filter (\other -> other /= key) state.open }


{-| Closes every section.
-}
collapseAll : State key -> State key
collapseAll (State state) =
    State { state | open = [] }


{-| Opens a closed section, as `expand` does, and closes an open one, like a click
on its header does. In the default mode opening a section closes the others.
-}
toggle : key -> State key -> State key
toggle key state =
    if isExpanded key state then
        collapse key state

    else
        expand key state


{-| The messages of an accordion: a header was clicked, an arrow key was pressed,
the browser found text in a closed section. Wrap it in a constructor of your own
message type, pass that constructor to `view`, and hand the messages you get back
to `update`.
-}
type Msg key
    = Toggle key
    | Reveal key
    | Focus String
    | Noop


{-| Opens and closes sections when their headers are clicked, and moves keyboard
focus between the headers. The `Cmd` does the focus move, so map it with your
message constructor.
-}
update : Msg key -> State key -> ( State key, Cmd (Msg key) )
update msg current =
    case msg of
        Toggle key ->
            ( toggle key current, Cmd.none )

        Reveal key ->
            ( expand key current, Cmd.none )

        Focus domId ->
            ( current, Internal.focus domId Noop )

        Noop ->
            ( current, Cmd.none )


headerId : String -> String -> String
headerId id domKey =
    id ++ "-header-" ++ Internal.sanitizeId domKey


bodyId : String -> String -> String
bodyId id domKey =
    id ++ "-body-" ++ Internal.sanitizeId domKey



-- VIEW


{-| The accordion: the constructor that wraps its messages, the attributes, the
state and the sections from top to bottom (their keys must be unique).
-}
view : (Msg key -> msg) -> List (Attribute msg) -> State key -> List (Section key msg) -> Html msg
view toMsg attributes ((State state) as current) sections =
    let
        config =
            configure attributes

        enabledKeys =
            sections
                |> List.filterMap
                    (\(Section data) ->
                        if data.disabled then
                            Nothing

                        else
                            Just data.domKey
                    )

        landmarks =
            List.length sections <= 6
    in
    Keyed.node "div"
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
        (List.map
            (\((Section data) as one) ->
                ( data.domKey, viewSection toMsg config landmarks state.id enabledKeys current one )
            )
            sections
        )


viewSection : (Msg key -> msg) -> Config -> Bool -> String -> List String -> State key -> Section key msg -> Html msg
viewSection toMsg config landmarks id enabledKeys current (Section data) =
    let
        expanded =
            isExpanded data.key current && not data.disabled

        -- a closed `section` keeps its body in the page, hidden until found
        rendered =
            expanded || not data.lazy

        neighbour offset =
            case indexOf data.domKey enabledKeys of
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
                 , Attr.id (headerId id data.domKey)
                 , Attr.type_ "button"
                 , Attr.attribute "aria-expanded"
                    (if expanded then
                        "true"

                     else
                        "false"
                    )
                 , Internal.attrIf (rendered && not data.disabled) (Attr.attribute "aria-controls" (bodyId id data.domKey))
                 , Attr.disabled data.disabled
                 ]
                    ++ (if data.disabled then
                            []

                        else
                            [ Events.onClick (toMsg (Toggle data.key))
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
        , if rendered && not data.disabled then
            Html.div
                [ Internal.cls [ "klar-accordion__body" ]
                , Attr.id (bodyId id data.domKey)
                , Internal.attrIf landmarks (Attr.attribute "role" "region")
                , Internal.attrIf landmarks (Attr.attribute "aria-labelledby" (headerId id data.domKey))
                , Internal.attrIf (not expanded) (Attr.attribute "hidden" "until-found")
                , if expanded then
                    Internal.noAttr

                  else
                    Events.on "beforematch" (Decode.succeed (toMsg (Reveal data.key)))
                ]
                [ Html.div [ Internal.cls [ "klar-accordion__content" ] ] (data.content ()) ]

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
