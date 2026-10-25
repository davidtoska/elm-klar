module Klar.Kanban exposing
    ( view
    , Column, column, cards, Limit, limit, withLimit
    , State, init, Msg, update, focusCard
    , Move, move, cardId, source, target, position, applyMove, Problem, problemText
    , Attribute, onOpen, disabled, headingLevel, onRetry, locale, settings
    )

{-| A dense board of ordered work columns, with explicit card moves, work-in-progress
limits and keyboard operation that does not depend on dragging.

Use when: work moves between stages and the order inside a stage matters.
Do not use when: one list only needs reordering; use `Klar.Sortable`, or `Klar.WorkQueue` for reviewing one record beside its details.
Quick path: `column`, `init`, `update`, `move`, `applyMove`, `view`

    import Klar.Kanban as Kanban

    -- model: board : Kanban.State, columns : List (Kanban.Column StageId Order)
    --        moveProblem : Maybe Kanban.Problem
    -- init: Kanban.init "orders-board"
    BoardMsg inner ->
        let
            ( board, cmd ) =
                Kanban.update inner model.board

            next =
                { model | board = board }
        in
        case Kanban.move orderIds stageIds model.board board of
            Just change ->
                case Kanban.applyMove orderIds stageIds .id change model.columns of
                    Ok columns ->
                        ( { next | columns = columns, moveProblem = Nothing }, Cmd.map BoardMsg cmd )

                    Err problem ->
                        ( { next | moveProblem = Just problem }, Cmd.map BoardMsg cmd )

            Nothing ->
                ( next, Cmd.map BoardMsg cmd )

    -- view:
    Kanban.view BoardMsg []
        { label = "Order fulfilment", columns = Remote.Loaded model.columns
        , columnIds = stageIds, cardIds = orderIds, cardId = .id
        , title = .number, content = viewOrderSummary
        }
        model.board

Make columns with `column`; `limit` validates a non-negative capacity and `withLimit`
attaches it. A full column refuses incoming cards, while cards already there may
be reordered or moved out, even if a server update put the count over the limit.
The board never truncates or silently removes cards.

Press a card's move button, then use Up/Down or Home/End to choose its position and
Left/Right to choose the next available column. Enter or Space confirms; Escape or Tab
cancels. Pointer users use the same button and the native destination/position
selectors. A move is a request: only the application applies or persists it.
`applyMove` rejects a request when column order, card ids/order or limits changed
since the move began. Editing only card content does not invalidate a move.
Show a rejected move with `problemText` in the page; do not silently discard an `Err`.

Column ids must be unique; card ids must be unique across the whole board. Bad data
is still shown, with a warning and all movement disabled. Unknown ids or stale
requests produce an explicit `Problem`, never a guessed destination. The board
draws all loaded cards, so page large boards in the application. There is no drag
gesture, virtualisation or swimlane model; all operations have ordinary controls.

Keep the command from `update`: it restores focus to the moved card after a local
move. For a server-confirmed move, call `focusCard` after applying the answer.
Use the root id from `init` with `Klar.focus` in a retry handler. Every `Remote`
state is drawn; stale or refreshing data remains visible but cannot be moved.

@docs view


# Columns

@docs Column, column, cards, Limit, limit, withLimit


# State

@docs State, init, Msg, update, focusCard


# Move requests

@docs Move, move, cardId, source, target, position, applyMove, Problem, problemText


# Attributes

@docs Attribute, onOpen, disabled, headingLevel, onRetry, locale, settings

-}

import Html exposing (Html)
import Html.Attributes as Attr
import Html.Events as Events
import Html.Keyed as Keyed
import Json.Decode as Decode
import Klar.Button as Button
import Klar.Format as Format
import Klar.Icon as Icon
import Klar.Ids as Ids exposing (Ids)
import Klar.Internal as Internal
import Klar.Internal.Collection as Collection
import Klar.Locale as Locale exposing (Locale)
import Klar.Remote as Remote exposing (Remote)
import Klar.Settings as Settings exposing (Settings)
import Set


{-| One stage, containing your records in their displayed order.
-}
type Column columnId card
    = Column { id : columnId, title : String, cards : List card, limit : Maybe Int }


{-| Creates a stage without a WIP limit. The label is your text; empty stages stay visible.
-}
column : columnId -> String -> List card -> Column columnId card
column columnId_ title items =
    Column { id = columnId_, title = title, cards = items, limit = Nothing }


{-| Records in a stage, in order. The application owns these values.
-}
cards : Column columnId card -> List card
cards (Column data) =
    data.cards


{-| A validated maximum number of cards permitted to enter a stage.
-}
type Limit
    = Limit Int


{-| Validates a capacity. Zero accepts no incoming cards; negatives return `Nothing`.
-}
limit : Int -> Maybe Limit
limit count =
    if count >= 0 then
        Just (Limit count)

    else
        Nothing


{-| Attaches a capacity to a stage. Existing cards are never removed or hidden.
-}
withLimit : Limit -> Column columnId card -> Column columnId card
withLimit (Limit maximum) (Column data) =
    Column { data | limit = Just maximum }


type alias Stage =
    { key : String, cards : List String, limit : Maybe Int }


type alias Snapshot =
    List Stage


type alias Session =
    { card : String, source : String, target : String, position : Int, title : String, snapshot : Snapshot }


type Note
    = Quiet
    | Picked String
    | Placed String Int
    | Submitted String String Int
    | Cancelled
    | Full
    | EndOfStages
    | Changed


{-| Interaction state only: the current move proposal, not your application records.
-}
type State
    = State { id : String, session : Maybe Session, serial : Int, last : Maybe Session, note : Note }


{-| Creates a board with no card being moved. The DOM id must be unique on the page.
-}
init : String -> State
init domId =
    State { id = domId, session = Nothing, serial = 0, last = Nothing, note = Quiet }


{-| Internal move controls. Route every message through `update`.
-}
type Msg
    = Begin Session
    | SelectColumn String
    | SelectPosition Int
    | StepColumn Int
    | StepPosition Int
    | First
    | Last
    | Commit Snapshot
    | Cancel
    | Leave
    | NoOp


findStage : String -> Snapshot -> Maybe Stage
findStage key stages =
    stages |> List.filter (.key >> (==) key) |> List.head


sizeWithout : Session -> Stage -> Int
sizeWithout session stage =
    List.length stage.cards
        - (if stage.key == session.source then
            1

           else
            0
          )


accepts : Session -> Stage -> Bool
accepts session stage =
    stage.key == session.source || (stage.limit |> Maybe.map (\maximum -> List.length stage.cards < maximum) |> Maybe.withDefault True)


handleId : String -> String -> String
handleId domId key =
    domId ++ "-move-" ++ Internal.percentEncode key


{-| Changes only the proposal until confirmation, then records one request and
restores focus to the card's move button. The application still decides what to save.
-}
update : Msg -> State -> ( State, Cmd Msg )
update msg (State state) =
    let
        quiet updated =
            ( State updated, Cmd.none )

        preview wanted session =
            case findStage wanted session.snapshot of
                Just stage ->
                    if accepts session stage then
                        let
                            next =
                                { session | target = wanted, position = min session.position (sizeWithout session stage) }
                        in
                        quiet { state | session = Just next, note = Placed next.target (next.position + 1) }

                    else
                        quiet { state | note = Full }

                Nothing ->
                    quiet { state | note = Changed }

        positionAt wanted session =
            case findStage session.target session.snapshot of
                Just stage ->
                    let
                        next =
                            { session | position = clamp 0 (sizeWithout session stage) wanted }
                    in
                    quiet { state | session = Just next, note = Placed next.target (next.position + 1) }

                Nothing ->
                    quiet { state | note = Changed }
    in
    case msg of
        Begin session ->
            ( State { state | session = Just session, note = Picked session.title }, Internal.focusFirst [ handleId state.id session.card, state.id ] NoOp )

        Cancel ->
            case state.session of
                Just session ->
                    ( State { state | session = Nothing, note = Cancelled }, Internal.focusFirst [ handleId state.id session.card, state.id ] NoOp )

                Nothing ->
                    quiet state

        Leave ->
            quiet { state | session = Nothing, note = Cancelled }

        NoOp ->
            quiet state

        _ ->
            case state.session of
                Nothing ->
                    quiet state

                Just session ->
                    case msg of
                        SelectColumn wanted ->
                            preview wanted session

                        SelectPosition wanted ->
                            positionAt wanted session

                        StepPosition delta ->
                            positionAt (session.position + delta) session

                        First ->
                            positionAt 0 session

                        Last ->
                            case findStage session.target session.snapshot of
                                Just stage ->
                                    positionAt (sizeWithout session stage) session

                                Nothing ->
                                    quiet { state | note = Changed }

                        StepColumn delta ->
                            let
                                current =
                                    session.snapshot |> List.indexedMap (\index stage -> ( index, stage )) |> List.filter (Tuple.second >> .key >> (==) session.target) |> List.head |> Maybe.map Tuple.first |> Maybe.withDefault 0

                                candidates =
                                    session.snapshot
                                        |> List.indexedMap Tuple.pair
                                        |> List.filter
                                            (\( index, _ ) ->
                                                if delta < 0 then
                                                    index < current

                                                else
                                                    index > current
                                            )
                                        |> (if delta < 0 then
                                                List.reverse

                                            else
                                                identity
                                           )
                                        |> List.filter (Tuple.second >> accepts session)
                            in
                            case List.head candidates of
                                Just ( _, stage ) ->
                                    preview stage.key session

                                Nothing ->
                                    quiet { state | note = EndOfStages }

                        Commit current ->
                            case findStage session.target current of
                                Just stage ->
                                    if current /= session.snapshot then
                                        quiet { state | note = Changed }

                                    else if not (accepts session stage) then
                                        quiet { state | note = Full }

                                    else
                                        ( State { state | session = Nothing, serial = state.serial + 1, last = Just session, note = Submitted session.title session.target (session.position + 1) }
                                        , Internal.focusFirst [ handleId state.id session.card, state.id ] NoOp
                                        )

                                Nothing ->
                                    quiet { state | note = Changed }

                        _ ->
                            quiet state


{-| Restores focus after an asynchronous server answer moves a card. Map the command
with the same message constructor used for `update`.
-}
focusCard : Ids cardId -> cardId -> State -> Cmd Msg
focusCard ids value (State state) =
    Internal.focusFirst [ handleId state.id (Ids.toKey ids value), state.id ] NoOp


{-| A request tied to the exact board order and limits the person reviewed.
-}
type Move cardId columnId
    = Move { card : cardId, source : columnId, target : columnId, position : Int, snapshot : Snapshot }


{-| Reads a confirmation from the states immediately before and after one `update`.
The same pair cannot describe multiple moves; unknown keys return `Nothing`.
-}
move : Ids cardId -> Ids columnId -> State -> State -> Maybe (Move cardId columnId)
move cardIds columnIds (State before) (State after) =
    if after.serial /= before.serial + 1 then
        Nothing

    else
        after.last
            |> Maybe.andThen
                (\session ->
                    Maybe.map3 (\card source_ target_ -> Move { card = card, source = source_, target = target_, position = session.position, snapshot = session.snapshot })
                        (Ids.fromKey cardIds session.card)
                        (Ids.fromKey columnIds session.source)
                        (Ids.fromKey columnIds session.target)
                )


{-| Application id of the card that should move.
-}
cardId : Move cardId columnId -> cardId
cardId (Move change) =
    change.card


{-| Application id of the stage the card came from.
-}
source : Move cardId columnId -> columnId
source (Move change) =
    change.source


{-| Application id of the destination stage.
-}
target : Move cardId columnId -> columnId
target (Move change) =
    change.target


{-| Zero-based insertion index in the destination after removing the card from its
source. A move within one stage uses this same rule and never counts the card twice.
-}
position : Move cardId columnId -> Int
position (Move change) =
    change.position


{-| A rejected request. Read its localised explanation with `problemText`.
-}
type Problem
    = InvalidBoard
    | BoardChanged
    | ColumnFull
    | InvalidMove


{-| A human explanation of an invalid board, changed snapshot, full stage or unknown
destination. No application data is changed when `applyMove` returns a problem.
-}
problemText : Locale -> Problem -> String
problemText loc problem =
    let
        pick en nb =
            Locale.pick loc { en = en, nb = nb }
    in
    case problem of
        InvalidBoard ->
            pick "Column and card ids must be unique. Moving is disabled." "Kolonne- og kort-ID-er må være unike. Flytting er deaktivert."

        BoardChanged ->
            pick "The board changed. Cancel this move and choose again." "Tavlen ble endret. Avbryt flyttingen og velg på nytt."

        ColumnFull ->
            pick "The destination has reached its work-in-progress limit." "Målet har nådd grensen for pågående arbeid."

        InvalidMove ->
            pick "The card or destination is no longer available." "Kortet eller målet er ikke lenger tilgjengelig."


snapshot : Ids cardId -> Ids columnId -> (card -> cardId) -> List (Column columnId card) -> Snapshot
snapshot cardIds columnIds toId columns =
    List.map (\(Column data) -> { key = Ids.toKey columnIds data.id, cards = List.map (toId >> Ids.toKey cardIds) data.cards, limit = data.limit }) columns


valid : Snapshot -> Bool
valid stages =
    let
        keys =
            List.map .key stages

        allCards =
            List.concatMap .cards stages

        unique values =
            Set.size (Set.fromList values) == List.length values
    in
    unique keys && unique allCards


{-| Applies one request to current application data, or returns a problem without
changing it. Uses exact ids/order/limits as a revision guard; card content may change.
Reordering an already over-limit stage is allowed because it does not increase WIP.
-}
applyMove : Ids cardId -> Ids columnId -> (card -> cardId) -> Move cardId columnId -> List (Column columnId card) -> Result Problem (List (Column columnId card))
applyMove cardIds columnIds toId (Move change) columns =
    let
        current =
            snapshot cardIds columnIds toId columns

        cardKey =
            Ids.toKey cardIds change.card

        sourceKey =
            Ids.toKey columnIds change.source

        targetKey =
            Ids.toKey columnIds change.target

        found =
            columns |> List.filter (\(Column data) -> Ids.toKey columnIds data.id == sourceKey) |> List.concatMap cards |> List.filter (toId >> Ids.toKey cardIds >> (==) cardKey) |> List.head

        session =
            { card = cardKey, source = sourceKey, target = targetKey, position = change.position, title = "", snapshot = current }
    in
    if not (valid current) then
        Err InvalidBoard

    else if current /= change.snapshot then
        Err BoardChanged

    else
        case ( found, findStage targetKey current ) of
            ( Just item, Just stage ) ->
                if not (accepts session stage) then
                    Err ColumnFull

                else if change.position < 0 || change.position > sizeWithout session stage then
                    Err InvalidMove

                else
                    Ok
                        (List.map
                            (\(Column data) ->
                                let
                                    key =
                                        Ids.toKey columnIds data.id

                                    without =
                                        if key == sourceKey then
                                            List.filter (toId >> Ids.toKey cardIds >> (/=) cardKey) data.cards

                                        else
                                            data.cards

                                    next =
                                        if key == targetKey then
                                            List.take change.position without ++ [ item ] ++ List.drop change.position without

                                        else
                                            without
                                in
                                Column { data | cards = next }
                            )
                            columns
                        )

            _ ->
                Err InvalidMove


{-| Optional board behaviour. Later attributes win; the board is movable by default.
-}
type Attribute cardId msg
    = Attribute (Config cardId msg -> Config cardId msg)


type alias Config cardId msg =
    { onOpen : Maybe (cardId -> msg), disabled : Bool, headingLevel : Int, onRetry : Maybe msg, locale : Locale, settings : Settings }


{-| Turns card titles into buttons sending their application id. Absent by default.
-}
onOpen : (cardId -> msg) -> Attribute cardId msg
onOpen toMsg =
    Attribute (\c -> { c | onOpen = Just toMsg })


{-| Prevents new moves and confirmation. Existing cards remain readable. Defaults to `False`.
-}
disabled : Bool -> Attribute cardId msg
disabled value =
    Attribute (\c -> { c | disabled = value })


{-| Level of column headings, from 1 through 6. Defaults to 3; other values use 3.
-}
headingLevel : Int -> Attribute cardId msg
headingLevel value =
    Attribute (\c -> { c | headingLevel = value })


{-| Retry message for initial errors and failed refreshes. Absent by default.
-}
onRetry : msg -> Attribute cardId msg
onRetry msg =
    Attribute (\c -> { c | onRetry = Just msg })


{-| Built-in text language. Defaults to English.
-}
locale : Locale -> Attribute cardId msg
locale value =
    Attribute (\c -> { c | locale = value })


{-| Formats retained-data timestamps in the application's zone. Defaults to `Settings.default`.
-}
settings : Settings -> Attribute cardId msg
settings value =
    Attribute (\c -> { c | settings = value })


{-| Draws the supplied stages and records without truncation. Ids are your types;
`title` names each card and `content` supplies its body without wrapping its actions.
Stale and refreshing boards cannot be moved; inspect or retry them first.
-}
view : (Msg -> msg) -> List (Attribute cardId msg) -> { label : String, columns : Remote (List (Column columnId card)), columnIds : Ids columnId, cardIds : Ids cardId, cardId : card -> cardId, title : card -> String, content : card -> Html msg } -> State -> Html msg
view toMsg attributes data (State state) =
    let
        c =
            List.foldl (\(Attribute change) acc -> change acc) { onOpen = Nothing, disabled = False, headingLevel = 3, onRetry = Nothing, locale = Locale.default, settings = Settings.default } attributes

        pick en nb =
            Locale.pick c.locale { en = en, nb = nb }

        helpId =
            state.id ++ "-help"

        number =
            Format.int c.locale

        stageName key =
            Remote.toMaybe data.columns
                |> Maybe.withDefault []
                |> List.filterMap
                    (\(Column col) ->
                        if Ids.toKey data.columnIds col.id == key then
                            Just col.title

                        else
                            Nothing
                    )
                |> List.head
                |> Maybe.withDefault (pick "Unavailable stage" "Utilgjengelig kolonne")

        announce =
            case state.note of
                Quiet ->
                    ""

                Picked title ->
                    title ++ pick " selected for moving." " er valgt for flytting."

                Placed destination at ->
                    pick "Proposed: " "Foreslått: " ++ stageName destination ++ pick ", position " ", plassering " ++ number at

                Submitted title destination at ->
                    title ++ pick ": move requested to " ": flytting forespurt til " ++ stageName destination ++ pick ", position " ", plassering " ++ number at

                Cancelled ->
                    pick "Move cancelled." "Flytting avbrutt."

                Full ->
                    problemText c.locale ColumnFull

                EndOfStages ->
                    pick "No available stage in that direction." "Ingen tilgjengelig kolonne i den retningen."

                Changed ->
                    problemText c.locale BoardChanged

        render columns =
            let
                current =
                    snapshot data.cardIds data.columnIds data.cardId columns

                good =
                    valid current

                available =
                    not c.disabled && not (Remote.isRefreshing data.columns) && not (Remote.isStale data.columns) && good

                stageLabel key =
                    columns
                        |> List.filterMap
                            (\(Column col) ->
                                if Ids.toKey data.columnIds col.id == key then
                                    Just col.title

                                else
                                    Nothing
                            )
                        |> List.head
                        |> Maybe.withDefault ""

                panel =
                    case state.session of
                        Nothing ->
                            Html.text ""

                        Just session ->
                            let
                                unchanged =
                                    current == session.snapshot

                                destination =
                                    findStage session.target current

                                maximum =
                                    destination |> Maybe.map (sizeWithout session) |> Maybe.withDefault 0

                                safe =
                                    available && unchanged
                            in
                            Html.div [ Internal.cls [ "klar-kanban__move" ], Attr.attribute "role" "group", Attr.attribute "aria-label" (pick "Move " "Flytt " ++ session.title) ]
                                [ Html.strong [] [ Html.text (pick "Moving: " "Flytter: " ++ session.title) ]
                                , if unchanged then
                                    Html.text ""

                                  else
                                    Html.p [ Attr.attribute "role" "alert" ] [ Html.text (problemText c.locale BoardChanged) ]
                                , Html.label [ Internal.cls [ "klar-kanban__control" ] ]
                                    [ Html.span [] [ Html.text (pick "Destination" "Mål") ]
                                    , Html.select [ Attr.value session.target, Attr.disabled (not safe), Events.onInput (SelectColumn >> toMsg) ]
                                        (List.map
                                            (\(Column col) ->
                                                let
                                                    key =
                                                        Ids.toKey data.columnIds col.id

                                                    stage =
                                                        { key = key, cards = List.map (data.cardId >> Ids.toKey data.cardIds) col.cards, limit = col.limit }
                                                in
                                                Html.option [ Attr.value key, Attr.selected (key == session.target), Attr.disabled (not (accepts session stage)) ] [ Html.text (col.title ++ " (" ++ number (List.length col.cards) ++ ")") ]
                                            )
                                            columns
                                        )
                                    ]
                                , Html.label [ Internal.cls [ "klar-kanban__control" ] ]
                                    [ Html.span [] [ Html.text (pick "Position" "Plassering") ]
                                    , Html.select [ Attr.value (String.fromInt session.position), Attr.disabled (not safe), Events.onInput (String.toInt >> Maybe.map SelectPosition >> Maybe.withDefault NoOp >> toMsg) ]
                                        (List.range 0 maximum |> List.map (\index -> Html.option [ Attr.value (String.fromInt index), Attr.selected (session.position == index) ] [ Html.text (number (index + 1) ++ pick " of " " av " ++ number (maximum + 1)) ]))
                                    ]
                                , Button.view [ Button.small, Button.primary, Button.disabled (not safe), Button.onClick (toMsg (Commit current)) ] (pick "Move here" "Flytt hit")
                                , Button.view [ Button.small, Button.onClick (toMsg Cancel) ] (pick "Cancel" "Avbryt")
                                , Html.span [ Internal.cls [ "klar-kanban__destination" ] ] [ Html.text (stageLabel session.target ++ " · " ++ pick "position " "plassering " ++ number (session.position + 1)) ]
                                ]

                drawColumn columnIndex (Column col) =
                    let
                        colKey =
                            Ids.toKey data.columnIds col.id

                        titleId =
                            state.id ++ "-column-" ++ String.fromInt columnIndex

                        count =
                            List.length col.cards

                        full =
                            col.limit |> Maybe.map (\maximum -> count >= maximum) |> Maybe.withDefault False

                        drawCard index card =
                            let
                                key =
                                    Ids.toKey data.cardIds (data.cardId card)

                                active =
                                    state.session |> Maybe.map (.card >> (==) key) |> Maybe.withDefault False

                                session =
                                    { card = key, source = colKey, target = colKey, position = index, title = data.title card, snapshot = current }

                                canCommit =
                                    available && (state.session |> Maybe.map (.snapshot >> (==) current) |> Maybe.withDefault False)

                                keys =
                                    if active then
                                        [ ( "Escape", toMsg Cancel ) ]
                                            ++ (if canCommit then
                                                    [ ( "ArrowUp", toMsg (StepPosition -1) ), ( "ArrowDown", toMsg (StepPosition 1) ), ( "ArrowLeft", toMsg (StepColumn -1) ), ( "ArrowRight", toMsg (StepColumn 1) ), ( "Home", toMsg First ), ( "End", toMsg Last ), ( "Enter", toMsg (Commit current) ), ( " ", toMsg (Commit current) ) ]

                                                else
                                                    []
                                               )

                                    else
                                        []
                            in
                            ( if good then
                                key

                              else
                                key ++ "-duplicate-" ++ String.fromInt index
                            , Html.li [ Internal.classes [ ( "klar-kanban__card", True ), ( "klar-kanban__card--moving", active ) ] ]
                                [ Html.div [ Internal.cls [ "klar-kanban__card-head" ] ]
                                    [ if good then
                                        Html.button
                                            [ Attr.type_ "button"
                                            , Attr.id (handleId state.id key)
                                            , Internal.cls [ "klar-kanban__handle" ]
                                            , Attr.attribute "aria-label" (pick "Move " "Flytt " ++ data.title card)
                                            , Attr.attribute "aria-describedby" helpId
                                            , Attr.attribute "aria-pressed"
                                                (if active then
                                                    "true"

                                                 else
                                                    "false"
                                                )
                                            , Attr.disabled (not available && not active)
                                            , Events.onClick
                                                (toMsg
                                                    (if active then
                                                        if canCommit then
                                                            Commit current

                                                        else
                                                            Cancel

                                                     else
                                                        Begin session
                                                    )
                                                )
                                            , Events.preventDefaultOn "keydown"
                                                (Internal.keyEvent
                                                    |> Decode.andThen
                                                        (\event ->
                                                            if active && event.key == "Tab" then
                                                                Decode.succeed ( toMsg Leave, False )

                                                            else if event.ctrl || event.meta || event.alt || event.shift then
                                                                Decode.fail "modified key"

                                                            else
                                                                case List.filter (Tuple.first >> (==) event.key) keys |> List.head of
                                                                    Just ( _, message ) ->
                                                                        Decode.succeed ( message, True )

                                                                    Nothing ->
                                                                        Decode.fail "unhandled key"
                                                        )
                                                )
                                            ]
                                            [ Icon.view Icon.move ]

                                      else
                                        Html.text ""
                                    , case c.onOpen of
                                        Just open ->
                                            Html.button [ Attr.type_ "button", Internal.cls [ "klar-kanban__title" ], Events.onClick (open (data.cardId card)) ] [ Html.text (data.title card) ]

                                        Nothing ->
                                            Html.strong [ Internal.cls [ "klar-kanban__card-title" ] ] [ Html.text (data.title card) ]
                                    ]
                                , data.content card
                                ]
                            )
                    in
                    ( if good then
                        colKey

                      else
                        colKey ++ "-duplicate-" ++ String.fromInt columnIndex
                    , Html.section [ Internal.cls [ "klar-kanban__column" ], Attr.attribute "aria-labelledby" titleId ]
                        [ Html.header [ Internal.cls [ "klar-kanban__column-head" ] ]
                            [ Internal.heading c.headingLevel [ Attr.id titleId ] [ Html.text col.title ]
                            , Html.span [ Internal.classes [ ( "klar-kanban__count", True ), ( "klar-kanban__count--full", full ) ] ]
                                [ Html.text (number count ++ (col.limit |> Maybe.map (\cap -> " / " ++ number cap) |> Maybe.withDefault ""))
                                , Html.span [ Internal.cls [ "klar-sr-only" ] ] [ Html.text (pick " cards" " kort") ]
                                ]
                            ]
                        , if full then
                            Html.p [ Internal.cls [ "klar-kanban__limit" ] ] [ Html.text (pick "WIP limit reached" "Grensen for pågående arbeid er nådd") ]

                          else
                            Html.text ""
                        , if List.isEmpty col.cards then
                            Html.p [ Internal.cls [ "klar-kanban__empty" ] ] [ Html.text (pick "No cards" "Ingen kort") ]

                          else
                            Keyed.ol [ Internal.cls [ "klar-kanban__cards" ] ] (List.indexedMap drawCard col.cards)
                        ]
                    )
            in
            Html.div []
                [ if good then
                    Html.text ""

                  else
                    Html.p [ Internal.cls [ "klar-kanban__warning" ], Attr.attribute "role" "alert" ] [ Html.text (problemText c.locale InvalidBoard) ]
                , panel
                , Keyed.node "div" [ Internal.cls [ "klar-kanban__columns" ], Attr.tabindex 0, Attr.attribute "role" "region", Attr.attribute "aria-label" (pick "Work stages" "Arbeidskolonner") ] (List.indexedMap drawColumn columns)
                ]
    in
    Html.section [ Attr.id state.id, Attr.tabindex -1, Attr.attribute "aria-label" data.label, Internal.cls [ "klar-kanban" ] ]
        [ Html.p [ Attr.id helpId, Internal.cls [ "klar-kanban__help" ] ] [ Html.text (pick "Choose a move button. Arrow keys choose a stage and position; Enter confirms, Escape or Tab cancels. Destination controls also work with a pointer." "Velg en flytteknapp. Piltastene velger kolonne og plassering; Enter bekrefter, Escape eller Tab avbryter. Mål og plassering kan også velges med pekeren.") ]
        , Html.div [ Internal.cls [ "klar-sr-only" ], Attr.attribute "role" "status", Attr.attribute "aria-live" "polite", Attr.attribute "aria-atomic" "true" ] [ Html.text announce ]
        , Html.div [] (Collection.view { locale = c.locale, settings = c.settings, onRetry = c.onRetry, onLoadMore = Nothing } (pick "No stages" "Ingen kolonner") data.columns render)
        ]
