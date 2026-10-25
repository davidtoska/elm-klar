module Klar.WorkQueue exposing
    ( view
    , State, init, Msg, update, selected, setSelected, query
    , Attribute, searchable, onLoadMore, onRetry, locale, settings
    )

{-| A keyboard-driven work list beside a detail pane, for processing one record
at a time without losing the surrounding queue.

Use when: a person works through cases, approvals or incoming orders one by one.
Do not use when: the main task is comparing rows and columns; use `Klar.Table`.
Quick path: `init`, `update`, `view`, `selected`

    import Klar.WorkQueue as WorkQueue

    -- model: { queue : WorkQueue.State } -- WorkQueue.init "orders-queue"
    -- update:
    QueueMsg inner ->
        let
            ( queue, cmd ) =
                WorkQueue.update inner model.queue
        in
        ( { model | queue = queue }, Cmd.map QueueMsg cmd )

    -- view:
    WorkQueue.view QueueMsg [ WorkQueue.searchable ]
        { label = "Orders to review", items = model.orders
        , ids = orderIds, id = .id, title = .number, summary = .customer
        , detail = viewOrder
        }
        model.queue

Read `selected orderIds queue` before and after update to fetch extra detail when
selection changes. Actions such as approve and reject belong in `detail`, so they
retain the application's business rules and busy/error states. The queue never
approves anything on a navigation key.

Arrow keys, j/k, Home and End move selection and focus inside the list. Tab leaves
the list for the detail pane. Search matches loaded titles and summaries, preserves
their order and does not erase the selection. A selected record missing after a
refresh is reported, never silently replaced with another record. The detail pane
is keyed by id, so native form state cannot leak between records. All remote states,
including retained empty data, are drawn. This queue renders the loaded page;
use paging for very large queues, or `Klar.Table` with virtual rows.

@docs view


# State

@docs State, init, Msg, update, selected, setSelected, query


# Attributes

@docs Attribute, searchable, onLoadMore, onRetry, locale, settings

-}

import Array
import Html exposing (Html)
import Html.Attributes as Attr
import Html.Events as Events
import Html.Keyed as Keyed
import Klar.Format as Format
import Klar.Ids as Ids exposing (Ids)
import Klar.Internal as Internal
import Klar.Internal.Collection as Collection
import Klar.Locale as Locale exposing (Locale)
import Klar.Remote exposing (Remote)
import Klar.Search as Search
import Klar.Settings as Settings exposing (Settings)
import Klar.TextInput as TextInput


{-| Queue-local selection and search text; no application records are kept here.
-}
type State
    = State { id : String, selected : Maybe String, query : String }


{-| Creates an unselected queue. The string is a DOM id unique on the page.
-}
init : String -> State
init id =
    State { id = id, selected = Nothing, query = "" }


{-| Internal queue interactions. Route them through `update`.
-}
type Msg
    = Choose String String
    | Search String
    | NoOp


{-| Applies selection and search changes and moves focus on keyboard navigation.
-}
update : Msg -> State -> ( State, Cmd Msg )
update msg (State state) =
    case msg of
        Choose key focusId ->
            ( State { state | selected = Just key }, Internal.focus focusId NoOp )

        Search value ->
            ( State { state | query = value }, Cmd.none )

        NoOp ->
            ( State state, Cmd.none )


{-| The selected application id, or `Nothing` before selection or for an unknown key.
It may refer to a record outside the loaded page; the view reports that separately.
-}
selected : Ids id -> State -> Maybe id
selected ids (State state) =
    state.selected |> Maybe.andThen (Ids.fromKey ids)


{-| Sets or clears selection without moving focus. Search is preserved.
-}
setSelected : Ids id -> Maybe id -> State -> State
setSelected ids value (State state) =
    State { state | selected = Maybe.map (Ids.toKey ids) value }


{-| Current search text. Initially empty; search is local to the loaded page.
-}
query : State -> String
query (State state) =
    state.query


{-| Queue settings. No search or load-more action is shown by default.
-}
type Attribute msg
    = Attribute (Config msg -> Config msg)


type alias Config msg =
    { searchable : Bool, onLoadMore : Maybe msg, onRetry : Maybe msg, locale : Locale, settings : Settings }


{-| Adds a search field for loaded titles and summaries. Off by default.
-}
searchable : Attribute msg
searchable =
    Attribute (\c -> { c | searchable = True })


{-| Adds a load-more button. The application appends or replaces the loaded page.
-}
onLoadMore : msg -> Attribute msg
onLoadMore msg =
    Attribute (\c -> { c | onLoadMore = Just msg })


{-| Retry for initial failures and failed refreshes. Absent by default.
-}
onRetry : msg -> Attribute msg
onRetry msg =
    Attribute (\c -> { c | onRetry = Just msg })


{-| Built-in text language. Defaults to English.
-}
locale : Locale -> Attribute msg
locale value =
    Attribute (\c -> { c | locale = value })


{-| Formatting of retained-data timestamps. Defaults to `Settings.default`.
-}
settings : Settings -> Attribute msg
settings value =
    Attribute (\c -> { c | settings = value })


{-| Draws a named queue of uniquely identified records and the selected record's
detail. The stable region id from `init` is also a focus target for retry handlers.
-}
view :
    (Msg -> msg)
    -> List (Attribute msg)
    -> { label : String, items : Remote (List record), ids : Ids id, id : record -> id, title : record -> String, summary : record -> String, detail : record -> Html msg }
    -> State
    -> Html msg
view toMsg attributes data (State state) =
    let
        c =
            List.foldl (\(Attribute change) acc -> change acc)
                { searchable = False, onLoadMore = Nothing, onRetry = Nothing, locale = Locale.default, settings = Settings.default }
                attributes

        pick en nb =
            Locale.pick c.locale { en = en, nb = nb }

        key record =
            Ids.toKey data.ids (data.id record)

        itemId record =
            state.id ++ "-item-" ++ Internal.percentEncode (key record)

        choose record =
            toMsg (Choose (key record) (itemId record))

        render records =
            let
                visible =
                    if c.searchable then
                        List.filter (\record -> Search.matches state.query (data.title record ++ " " ++ data.summary record)) records

                    else
                        records

                active =
                    records |> List.filter (key >> Just >> (==) state.selected) |> List.head

                tabKey =
                    if List.any (key >> Just >> (==) state.selected) visible then
                        state.selected

                    else
                        List.head visible |> Maybe.map key

                indexed =
                    Array.fromList visible

                lastIndex =
                    Array.length indexed - 1

                at index =
                    Array.get index indexed

                row index record =
                    let
                        bindings =
                            [ ( "ArrowDown", at (min lastIndex (index + 1)) )
                            , ( "j", at (min lastIndex (index + 1)) )
                            , ( "ArrowUp", at (max 0 (index - 1)) )
                            , ( "k", at (max 0 (index - 1)) )
                            , ( "Home", List.head visible )
                            , ( "End", at lastIndex )
                            ]
                                |> List.filterMap (\( name, maybe ) -> Maybe.map (\target -> ( name, choose target )) maybe)
                    in
                    ( key record
                    , Html.li []
                        [ Html.button
                            [ Attr.type_ "button"
                            , Attr.id (itemId record)
                            , Internal.classes [ ( "klar-work-queue__item", True ), ( "klar-work-queue__item--selected", state.selected == Just (key record) ) ]
                            , Attr.tabindex
                                (if tabKey == Just (key record) then
                                    0

                                 else
                                    -1
                                )
                            , Internal.attrIf (state.selected == Just (key record)) (Attr.attribute "aria-current" "true")
                            , Attr.attribute "aria-controls" (state.id ++ "-detail")
                            , Events.onClick (choose record)
                            , Internal.onKeys bindings
                            ]
                            [ Html.strong [] [ Html.text (data.title record) ]
                            , Html.span [ Internal.cls [ "klar-work-queue__summary" ] ] [ Html.text (data.summary record) ]
                            ]
                        ]
                    )
            in
            Html.div []
                [ Html.div [ Internal.cls [ "klar-workbench__bar" ] ]
                    [ if c.searchable then
                        TextInput.view [ TextInput.id (state.id ++ "-search"), TextInput.label (pick "Search loaded queue" "Søk i innlastet kø"), TextInput.value state.query, TextInput.onInput (Search >> toMsg), TextInput.search, TextInput.locale c.locale ]

                      else
                        Html.text ""
                    , Html.span [ Attr.attribute "role" "status" ] [ Html.text (Format.int c.locale (List.length visible) ++ pick " of " " av " ++ Format.int c.locale (List.length records) ++ pick " loaded" " innlastet") ]
                    ]
                , Html.div [ Internal.cls [ "klar-work-queue__panes" ] ]
                    [ Html.div [ Internal.cls [ "klar-work-queue__list-pane" ] ]
                        [ if List.isEmpty visible then
                            Collection.empty (pick "No matches in loaded queue" "Ingen treff i innlastet kø")

                          else
                            Keyed.ul [ Internal.cls [ "klar-work-queue__list" ], Attr.attribute "aria-label" data.label ] (List.indexedMap row visible)
                        , Html.p [ Internal.cls [ "klar-work-queue__help" ] ] [ Html.text (pick "↑ ↓ or j/k to navigate · Tab for details" "↑ ↓ eller j/k for å navigere · Tab for detaljer") ]
                        , Collection.more c.locale c.onLoadMore
                        ]
                    , Html.section [ Attr.id (state.id ++ "-detail"), Attr.tabindex 0, Attr.attribute "aria-label" (pick "Selected item" "Valgt post"), Internal.cls [ "klar-work-queue__detail" ] ]
                        [ case active of
                            Just record ->
                                Keyed.node "div" [] [ ( key record, data.detail record ) ]

                            Nothing ->
                                Collection.empty
                                    (if state.selected == Nothing then
                                        pick "Choose an item to review" "Velg en post å behandle"

                                     else
                                        pick "Selected item is no longer in the loaded queue" "Valgt post finnes ikke lenger i den innlastede køen"
                                    )
                        ]
                    ]
                ]
    in
    Html.section [ Attr.id state.id, Attr.tabindex -1, Attr.attribute "aria-label" data.label, Internal.cls [ "klar-work-queue" ] ]
        (Collection.view { locale = c.locale, settings = c.settings, onRetry = c.onRetry, onLoadMore = c.onLoadMore } (pick "Queue is empty" "Køen er tom") data.items render)
