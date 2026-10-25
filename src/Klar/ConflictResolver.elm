module Klar.ConflictResolver exposing
    ( view
    , Field, field
    , State, init, Msg, update, resolved, reset
    , Attribute, onApply, saving, onRetry, locale, settings
    )

{-| A three-way field merge that makes concurrent edits explicit and requires
a decision for every conflicting value before the result can be applied.

Use when: saving a record failed because someone else edited the same version.
Do not use when: a person only needs to inspect changes; use `Klar.Diff` or `Klar.Compare`.
Quick path: `field`, `init`, `update`, `view`, `resolved`

    import Klar.ConflictResolver as Conflict

    -- model: { conflict : Conflict.State } -- Conflict.init "order-conflict"
    -- update:
    ConflictMsg inner ->
        let
            ( conflict, cmd ) =
                Conflict.update inner model.conflict
        in
        ( { model | conflict = conflict }, Cmd.map ConflictMsg cmd )

    -- view:
    Conflict.view ConflictMsg [ Conflict.onApply ApplyMergedFields ]
        { label = "Resolve order changes", ids = fieldIds, fields = model.conflictingFields }
        model.conflict

`field` receives the common base, your edit and their latest edit. Equal edits
agree automatically. If only one side changed from the base, that change is kept.
When both changed differently, neither wins until the person chooses. Values are
compared exactly, including spaces; `Nothing` and `Just ""` are distinct.

Decisions remember all three versions they were made against. If refreshed data
changes any version, the decision no longer resolves that field. Reset the state
when beginning a different record, even when it has the same field ids. Applying
is disabled during refresh, with stale data, while saving, and until every field
is resolved. The application saves the result with its server revision token;
the component performs no writes. A failed save belongs beside this component
as an `Alert` or a form error. Unique field ids are required.

@docs view


# Fields

@docs Field, field


# State

@docs State, init, Msg, update, resolved, reset


# Attributes

@docs Attribute, onApply, saving, onRetry, locale, settings

-}

import Dict exposing (Dict)
import Html exposing (Html)
import Html.Attributes as Attr
import Html.Events as Events
import Html.Keyed as Keyed
import Klar.Button as Button
import Klar.Format as Format
import Klar.Ids as Ids exposing (Ids)
import Klar.Internal as Internal
import Klar.Internal.Collection as Collection
import Klar.Locale as Locale exposing (Locale)
import Klar.Remote as Remote exposing (Remote)
import Klar.Settings as Settings exposing (Settings)


type alias Versions =
    { base : Maybe String, yours : Maybe String, theirs : Maybe String }


{-| One field with an application id, label and three exact optional text values.
-}
type Field id
    = Field id String Versions


{-| Creates a three-way comparison. `Nothing` means absent, `Just ""` means empty.
-}
field : id -> String -> { base : Maybe String, yours : Maybe String, theirs : Maybe String } -> Field id
field =
    Field


type Side
    = Yours
    | Theirs


{-| Decisions tied to the exact versions reviewed; contains no functions.
-}
type State
    = State { id : String, decisions : Dict String ( Versions, Side ) }


{-| Creates an empty resolver. The string is a DOM id unique on the page.
-}
init : String -> State
init id =
    State { id = id, decisions = Dict.empty }


{-| Internal choice messages, handled by `update`.
-}
type Msg
    = Choose String Versions Side
    | ChooseAll (List ( String, Versions )) Side


{-| Records an individual or explicit bulk choice. No commands are needed.
-}
update : Msg -> State -> ( State, Cmd Msg )
update msg (State state) =
    let
        save pairs side =
            State { state | decisions = List.foldl (\( key, versions ) acc -> Dict.insert key ( versions, side ) acc) state.decisions pairs }
    in
    ( case msg of
        Choose key versions side ->
            save [ ( key, versions ) ] side

        ChooseAll pairs side ->
            save pairs side
    , Cmd.none
    )


{-| Clears all choices, keeping the DOM id. Use when starting a different record.
-}
reset : State -> State
reset (State state) =
    State { state | decisions = Dict.empty }


automatic : Versions -> Maybe (Maybe String)
automatic versions =
    if versions.yours == versions.theirs then
        Just versions.yours

    else if versions.yours == versions.base then
        Just versions.theirs

    else if versions.theirs == versions.base then
        Just versions.yours

    else
        Nothing


decision : String -> Versions -> State -> Maybe Side
decision key versions (State state) =
    Dict.get key state.decisions
        |> Maybe.andThen
            (\( reviewed, side ) ->
                if reviewed == versions then
                    Just side

                else
                    Nothing
            )


value : String -> Versions -> State -> Maybe (Maybe String)
value key versions state =
    case automatic versions of
        Just agreed ->
            Just agreed

        Nothing ->
            decision key versions state
                |> Maybe.map
                    (\side ->
                        case side of
                            Yours ->
                                versions.yours

                            Theirs ->
                                versions.theirs
                    )


{-| Returns all field ids and resolved values in input order, or every unresolved
id. Choices against old versions are rejected. This pure function does not inspect
remote freshness; save only from current, authoritative server data.
-}
resolved : Ids id -> List (Field id) -> State -> Result (List id) (List ( id, Maybe String ))
resolved ids fields state =
    let
        results =
            List.map (\(Field id _ versions) -> ( id, value (Ids.toKey ids id) versions state )) fields

        missing =
            List.filterMap
                (\( id, result ) ->
                    if result == Nothing then
                        Just id

                    else
                        Nothing
                )
                results
    in
    if List.isEmpty missing then
        Ok (List.filterMap (\( id, result ) -> Maybe.map (Tuple.pair id) result) results)

    else
        Err missing


{-| Optional resolver behaviour. By default there is no apply action.
-}
type Attribute id msg
    = Attribute (Config id msg -> Config id msg)


type alias Config id msg =
    { onApply : Maybe (List ( id, Maybe String ) -> msg), saving : Bool, onRetry : Maybe msg, locale : Locale, settings : Settings }


{-| Adds an apply button. Receives the complete resolved field list only after
an explicit click. Disabled for stale, refreshing, empty or unresolved data.
-}
onApply : (List ( id, Maybe String ) -> msg) -> Attribute id msg
onApply toMsg =
    Attribute (\c -> { c | onApply = Just toMsg })


{-| Disables choices and shows the apply button busy while a save is pending.
Defaults to `False`.
-}
saving : Bool -> Attribute id msg
saving value_ =
    Attribute (\c -> { c | saving = value_ })


{-| Retry for initial failures and failed refreshes. Absent by default.
-}
onRetry : msg -> Attribute id msg
onRetry msg =
    Attribute (\c -> { c | onRetry = Just msg })


{-| Language of built-in text. Defaults to English.
-}
locale : Locale -> Attribute id msg
locale value_ =
    Attribute (\c -> { c | locale = value_ })


{-| Formatting of retained-data timestamps. Defaults to `Settings.default`.
-}
settings : Settings -> Attribute id msg
settings value_ =
    Attribute (\c -> { c | settings = value_ })


{-| The three versions and per-field choices. Radio groups are named by the
resolver id and field id; two resolvers on a page must have distinct `init` ids.
The root is a stable focus target for retry handlers.
-}
view : (Msg -> msg) -> List (Attribute id msg) -> { label : String, ids : Ids id, fields : Remote (List (Field id)) } -> State -> Html msg
view toMsg attributes data state =
    let
        (State local) =
            state

        c =
            List.foldl (\(Attribute change) acc -> change acc)
                { onApply = Nothing, saving = False, onRetry = Nothing, locale = Locale.default, settings = Settings.default }
                attributes

        pick en nb =
            Locale.pick c.locale { en = en, nb = nb }

        yours =
            pick "Yours" "Din"

        theirs =
            pick "Theirs" "Deres"

        show maybeText =
            Html.div [ Internal.cls [ "klar-conflict-resolver__value" ] ]
                [ case maybeText of
                    Nothing ->
                        Html.em [] [ Html.text (pick "Not provided" "Ikke oppgitt") ]

                    Just "" ->
                        Html.em [] [ Html.text (pick "Empty text" "Tom tekst") ]

                    Just text ->
                        Html.text text
                ]

        render fields =
            let
                outcome =
                    resolved data.ids fields state

                remaining =
                    case outcome of
                        Ok _ ->
                            0

                        Err missing ->
                            List.length missing

                conflicts =
                    List.filterMap
                        (\(Field id _ versions) ->
                            if automatic versions == Nothing then
                                Just ( Ids.toKey data.ids id, versions )

                            else
                                Nothing
                        )
                        fields

                safe =
                    not (Remote.isRefreshing data.fields) && not (Remote.isStale data.fields)

                row (Field id label versions) =
                    let
                        key =
                            Ids.toKey data.ids id

                        auto =
                            automatic versions

                        chosen =
                            decision key versions state

                        choice side title content =
                            Html.label [ Internal.classes [ ( "klar-conflict-resolver__choice", True ), ( "klar-conflict-resolver__choice--selected", chosen == Just side ) ] ]
                                [ Html.span [ Internal.cls [ "klar-workbench__check" ] ]
                                    [ Html.input [ Attr.type_ "radio", Attr.name (local.id ++ "-field-" ++ Internal.percentEncode key), Attr.checked (chosen == Just side), Attr.disabled c.saving, Events.onCheck (\_ -> toMsg (Choose key versions side)) ] []
                                    , Html.strong [] [ Html.text title ]
                                    ]
                                , show content
                                ]
                    in
                    ( key
                    , Html.fieldset [ Internal.cls [ "klar-conflict-resolver__field" ], Attr.disabled c.saving ]
                        [ Html.legend [] [ Html.text label ]
                        , Html.div [ Internal.cls [ "klar-conflict-resolver__versions" ] ]
                            [ Html.div [ Internal.cls [ "klar-conflict-resolver__base" ] ] [ Html.strong [] [ Html.text (pick "Common base" "Felles utgangspunkt") ], show versions.base ]
                            , if auto == Nothing then
                                choice Yours yours versions.yours

                              else
                                Html.div [ Internal.cls [ "klar-conflict-resolver__base" ] ] [ Html.strong [] [ Html.text yours ], show versions.yours ]
                            , if auto == Nothing then
                                choice Theirs theirs versions.theirs

                              else
                                Html.div [ Internal.cls [ "klar-conflict-resolver__base" ] ] [ Html.strong [] [ Html.text theirs ], show versions.theirs ]
                            ]
                        , case value key versions state of
                            Just merged ->
                                Html.div [ Internal.cls [ "klar-conflict-resolver__result" ] ]
                                    [ Html.strong []
                                        [ Html.text
                                            (if auto /= Nothing then
                                                pick "Automatic result" "Automatisk resultat"

                                             else
                                                pick "Chosen result" "Valgt resultat"
                                            )
                                        ]
                                    , show merged
                                    ]

                            Nothing ->
                                Html.p [ Internal.cls [ "klar-conflict-resolver__pending" ] ] [ Html.text (pick "Choose a version to resolve this field" "Velg en versjon for å løse dette feltet") ]
                        ]
                    )
            in
            Html.div []
                [ Html.div [ Internal.cls [ "klar-workbench__bar" ] ]
                    [ Html.span [ Attr.attribute "role" "status" ] [ Html.text (Format.int c.locale remaining ++ pick " unresolved of " " uløste av " ++ Format.int c.locale (List.length fields)) ]
                    , if List.isEmpty conflicts then
                        Html.text ""

                      else
                        Html.div [ Internal.cls [ "klar-workbench__actions" ] ]
                            [ Button.view [ Button.small, Button.disabled c.saving, Button.onClick (toMsg (ChooseAll conflicts Yours)) ] (pick "Use all yours" "Bruk alle dine")
                            , Button.view [ Button.small, Button.disabled c.saving, Button.onClick (toMsg (ChooseAll conflicts Theirs)) ] (pick "Use all theirs" "Bruk alle deres")
                            ]
                    ]
                , Keyed.node "div" [ Internal.cls [ "klar-conflict-resolver__fields" ] ] (List.map row fields)
                , case c.onApply of
                    Just apply ->
                        Html.div [ Internal.cls [ "klar-workbench__bar" ] ]
                            [ case outcome of
                                Ok merged ->
                                    Button.view [ Button.primary, Button.loading c.saving, Button.disabled (not safe || c.saving), Button.onClick (apply merged) ] (pick "Apply resolved values" "Bruk løste verdier")

                                Err _ ->
                                    Button.view [ Button.primary, Button.disabled True ] (pick "Apply resolved values" "Bruk løste verdier")
                            , if safe then
                                Html.text ""

                              else
                                Html.span [] [ Html.text (pick "Refresh successfully before applying" "Oppdater uten feil før du bruker resultatet") ]
                            ]

                    Nothing ->
                        Html.text ""
                ]
    in
    Html.section [ Attr.id local.id, Attr.tabindex -1, Attr.attribute "aria-label" data.label, Internal.cls [ "klar-conflict-resolver" ] ]
        (Collection.view { locale = c.locale, settings = c.settings, onRetry = c.onRetry, onLoadMore = Nothing } (pick "No fields to resolve" "Ingen felt å løse") data.fields render)
