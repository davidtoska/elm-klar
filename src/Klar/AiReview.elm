module Klar.AiReview exposing
    ( view
    , Proposal, proposal, Source, source
    , State, init, Msg, update, reset
    , Decision, decisions
    , Attribute, onSubmit, saving, errorMaybe, discussion, onRetry, locale, settings
    )

{-| Review server-generated AI proposals one statement or change at a time, with
evidence, exact before/after values, a reason and explicit approval or rejection.

Use when: a person must understand and decide on AI suggestions before a server applies them.
Do not use when: approving ordinary workflow stages; use `Klar.ApprovalFlow`.
Quick path: `proposal`, `init`, `update`, `view`, `onSubmit`

    import Klar.AiReview as Review

    -- model: { review : Review.State } -- Review.init "ai-review"
    -- update:
    ReviewMsg inner ->
        let
            ( review, cmd ) =
                Review.update inner model.review
        in
        ( { model | review = review }, Cmd.map ReviewMsg cmd )

    -- view:
    Review.view ReviewMsg [ Review.onSubmit SaveDecisions ]
        { label = "Review AI suggestions", ids = proposalIds, proposals = model.proposals }
        model.review

Every decision remembers the complete displayed proposal, including sources. A
changed revision, explanation, source or value requires a new decision. Duplicate
ids block submission. Empty, loading, failed, refreshing and stale data cannot be
submitted. Rejection requires a nonblank reason; approval may include one.

The application sends decisions to its own server, which must authorize the user,
compare each revision with the current proposal and target-record revision, and
apply only approved changes atomically. A click is a request, never a successful
save. Keep `saving True` until acknowledgement, show `errorMaybe` on failure, and
replace the proposals with the server result on success. Use request tickets to
ignore late responses. Reset when changing case or tenant, even with identical ids.

`discussion` embeds [Klar.CommentThread](Klar-CommentThread) or custom structured
evidence beside each statement. Its callback receives id and revision; store threads
by both so a comment never silently moves to a revised statement. Source excerpts
are plain text and URLs are checked. Evidence is supplied by the application; the
component does not verify claims or manufacture confidence scores. All proposal
text is shown in full as plain text, including unusually long values.

@docs view


# Proposals and evidence

@docs Proposal, proposal, Source, source


# Local review

@docs State, init, Msg, update, reset


# Saving

@docs Decision, decisions


# Attributes

@docs Attribute, onSubmit, saving, errorMaybe, discussion, onRetry, locale, settings

-}

import Dict exposing (Dict)
import Html exposing (Html)
import Html.Attributes as Attr
import Html.Events as Events
import Html.Keyed as Keyed
import Klar.Button as Button
import Klar.Ids as Ids exposing (Ids)
import Klar.Internal as Internal
import Klar.Internal.Freshness as Freshness
import Klar.Link as Link
import Klar.Locale as Locale exposing (Locale)
import Klar.Remote as Remote exposing (Remote)
import Klar.RemoteView as RemoteView
import Klar.Settings as Settings exposing (Settings)
import Klar.TextArea as TextArea
import Set


{-| A source label, URL and exact excerpt. This is evidence to inspect, not verified truth.
-}
type Source
    = Source { label : String, url : String, excerpt : String }


{-| Creates evidence. Unsafe URLs remain visible text without a link.
-}
source : { label : String, url : String, excerpt : String } -> Source
source =
    Source


type alias Snapshot =
    { revision : String, title : String, before : String, after : String, rationale : String, sources : List Source }


{-| A server proposal with an application id and an opaque server revision token.
-}
type Proposal id
    = Proposal id Snapshot


{-| One independently reviewable statement or change. For a new statement, use an
empty `before`. Include assumptions and limitations in `rationale`.
-}
proposal : { id : id, revision : String, title : String, before : String, after : String, rationale : String, sources : List Source } -> Proposal id
proposal p =
    Proposal p.id { revision = p.revision, title = p.title, before = p.before, after = p.after, rationale = p.rationale, sources = p.sources }


type alias Choice =
    { snapshot : Snapshot, approved : Maybe Bool, reason : String }


{-| Local decisions bound to exact reviewed content; no server writes or functions.
-}
type State
    = State { id : String, choices : Dict String Choice }


{-| Empty review. The string is a DOM id unique on the page.
-}
init : String -> State
init id =
    State { id = id, choices = Dict.empty }


{-| Clears decisions when moving to another case, preserving the DOM id.
-}
reset : State -> State
reset (State state) =
    init state.id


{-| Internal choices and raw review notes. Route through `update`.
-}
type Msg
    = Choose String Snapshot Bool
    | Reason String Snapshot String


{-| Updates a version-bound choice or reason. No commands are needed.
-}
update : Msg -> State -> ( State, Cmd Msg )
update msg (State state) =
    let
        change key snapshot f =
            State { state | choices = Dict.insert key (f (choice key snapshot (State state))) state.choices }
    in
    ( case msg of
        Choose key snapshot approved ->
            change key snapshot (\c -> { c | approved = Just approved })

        Reason key snapshot reason ->
            change key snapshot (\c -> { c | reason = reason })
    , Cmd.none
    )


choice : String -> Snapshot -> State -> Choice
choice key snapshot (State state) =
    Dict.get key state.choices
        |> Maybe.andThen
            (\c ->
                if c.snapshot == snapshot then
                    Just c

                else
                    Nothing
            )
        |> Maybe.withDefault { snapshot = snapshot, approved = Nothing, reason = "" }


{-| A request to record a decision against this exact server revision. The server
must validate the revision and permissions before applying an approved proposal.
-}
type alias Decision id =
    { id : id, revision : String, approved : Bool, reason : String }


{-| Complete, nonempty decisions, or `Nothing` for missing/invalid decisions,
duplicate ids or unavailable/stale/refreshing proposals. Rejections need a reason.
-}
decisions : Ids id -> Remote (List (Proposal id)) -> State -> Maybe (List (Decision id))
decisions ids remote state =
    if Remote.isRefreshing remote || Remote.isStale remote then
        Nothing

    else
        Remote.toMaybe remote
            |> Maybe.andThen
                (\items ->
                    let
                        keys =
                            List.map (\(Proposal id _) -> Ids.toKey ids id) items

                        read (Proposal id snapshot) =
                            let
                                c =
                                    choice (Ids.toKey ids id) snapshot state
                            in
                            c.approved
                                |> Maybe.andThen
                                    (\approved ->
                                        if not approved && String.trim c.reason == "" then
                                            Nothing

                                        else
                                            Just { id = id, revision = snapshot.revision, approved = approved, reason = c.reason }
                                    )

                        results =
                            List.filterMap read items
                    in
                    if List.isEmpty items || Set.size (Set.fromList keys) /= List.length items || List.length results /= List.length items then
                        Nothing

                    else
                        Just results
                )


{-| Review behaviour; no submit action or discussion by default.
-}
type Attribute id msg
    = Attribute (Config id msg -> Config id msg)


type alias Config id msg =
    { onSubmit : Maybe (List (Decision id) -> msg), saving : Bool, error : Maybe String, discussion : Maybe (id -> String -> Html msg), onRetry : Maybe msg, locale : Locale, settings : Settings }


{-| Adds the explicit save action, receiving all decisions, including rejections.
-}
onSubmit : (List (Decision id) -> msg) -> Attribute id msg
onSubmit f =
    Attribute (\c -> { c | onSubmit = Just f })


{-| Disables editing and submission during a server write. Defaults to `False`.
-}
saving : Bool -> Attribute id msg
saving value =
    Attribute (\c -> { c | saving = value })


{-| A failed server write. Keeps every local choice and note. Absent by default.
-}
errorMaybe : Maybe String -> Attribute id msg
errorMaybe value =
    Attribute (\c -> { c | error = value })


{-| Content beneath each proposal, receiving its application id and revision.
Use a separate CommentThread state for each pair. Absent by default.
-}
discussion : (id -> String -> Html msg) -> Attribute id msg
discussion f =
    Attribute (\c -> { c | discussion = Just f })


{-| Retries initial load or refresh failures. Absent by default.
-}
onRetry : msg -> Attribute id msg
onRetry msg =
    Attribute (\c -> { c | onRetry = Just msg })


{-| Language of built-in text. Defaults to English.
-}
locale : Locale -> Attribute id msg
locale value =
    Attribute (\c -> { c | locale = value })


{-| Timestamp formatting of retained data. Defaults to `Settings.default`.
-}
settings : Settings -> Attribute id msg
settings value =
    Attribute (\c -> { c | settings = value })


{-| Exact proposal text, evidence, version-bound radio decisions and optional
discussion. The root is a stable focus target in every remote state.
-}
view : (Msg -> msg) -> List (Attribute id msg) -> { label : String, ids : Ids id, proposals : Remote (List (Proposal id)) } -> State -> Html msg
view toMsg attributes data state =
    let
        (State local) =
            state

        c =
            List.foldl (\(Attribute f) acc -> f acc) { onSubmit = Nothing, saving = False, error = Nothing, discussion = Nothing, onRetry = Nothing, locale = Locale.default, settings = Settings.default } attributes

        pick en nb =
            Locale.pick c.locale { en = en, nb = nb }

        locked =
            c.saving || Remote.isRefreshing data.proposals || Remote.isStale data.proposals

        evidence (Source s) =
            Html.li []
                [ case Link.external s.url of
                    Just target ->
                        Link.view [ Link.locale c.locale ] target s.label

                    Nothing ->
                        Html.span [] [ Html.text (s.label ++ " · " ++ s.url) ]
                , Html.blockquote [] [ Html.text s.excerpt ]
                ]

        row duplicate index (Proposal id p) =
            let
                key =
                    Ids.toKey data.ids id

                domId =
                    local.id
                        ++ "-proposal-"
                        ++ (if duplicate then
                                String.fromInt index

                            else
                                Internal.percentEncode key
                           )

                selected =
                    choice key p state

                option approved label =
                    Html.label []
                        [ Html.input [ Attr.type_ "radio", Attr.name (domId ++ "-decision"), Attr.checked (selected.approved == Just approved), Attr.disabled locked, Events.onCheck (\_ -> toMsg (Choose key p approved)) ] []
                        , Html.text label
                        ]

                value title text =
                    Html.div [ Internal.cls [ "klar-ai-review__value" ] ] [ Html.strong [] [ Html.text title ], Html.pre [] [ Html.text text ] ]
            in
            ( if duplicate then
                String.fromInt index

              else
                key
            , Html.article [ Internal.cls [ "klar-ai-review__proposal" ], Attr.attribute "aria-labelledby" (domId ++ "-title") ]
                [ Html.h3 [ Attr.id (domId ++ "-title") ] [ Html.text p.title ]
                , Html.p [ Internal.cls [ "klar-ai__meta" ] ] [ Html.text (pick "AI proposal · Revision " "AI-forslag · Versjon " ++ p.revision) ]
                , Html.div [ Internal.cls [ "klar-ai-review__comparison" ] ] [ value (pick "Current" "Nåværende") p.before, value (pick "Proposed" "Foreslått") p.after ]
                , Html.h4 [] [ Html.text (pick "Reasoning and limitations" "Begrunnelse og begrensninger") ]
                , Html.p [ Internal.cls [ "klar-ai-review__rationale" ] ] [ Html.text p.rationale ]
                , Html.h4 [] [ Html.text (pick "Sources to verify" "Kilder som må kontrolleres") ]
                , if List.isEmpty p.sources then
                    Html.p [] [ Html.text (pick "No sources provided" "Ingen kilder oppgitt") ]

                  else
                    Html.ul [] (List.map evidence p.sources)
                , Html.fieldset [ Attr.disabled locked, Internal.cls [ "klar-ai-review__decision" ] ]
                    [ Html.legend [] [ Html.text (pick "Your decision" "Din vurdering") ]
                    , option True (pick "Approve" "Godkjenn")
                    , option False (pick "Reject" "Avvis")
                    , TextArea.view [ TextArea.id (domId ++ "-reason"), TextArea.label (pick "Review note (required for rejection)" "Vurdering (påkrevd ved avvisning)"), TextArea.value selected.reason, TextArea.onInput (Reason key p >> toMsg), TextArea.disabled locked ]
                    ]
                , Maybe.map (\renderDiscussion -> renderDiscussion id p.revision) c.discussion |> Maybe.withDefault (Html.text "")
                ]
            )

        render items =
            let
                duplicate =
                    Set.size (Set.fromList (List.map (\(Proposal id _) -> Ids.toKey data.ids id) items)) /= List.length items
            in
            [ Html.p [ Attr.attribute "role" "status" ]
                [ Html.text
                    (if duplicate then
                        pick "Duplicate proposal ids. Review cannot be saved." "Dupliserte forslags-ID-er. Vurderingen kan ikke lagres."

                     else
                        pick "Review every proposal before saving. Nothing is applied automatically." "Vurder alle forslag før lagring. Ingenting utføres automatisk."
                    )
                ]
            , Keyed.node "div" [] (List.indexedMap (row duplicate) items)
            ]

        body =
            case Freshness.settle data.proposals of
                ( Remote.Loaded items, freshness ) ->
                    [ Freshness.wrap { locale = c.locale, settings = c.settings, onRetry = c.onRetry, inline = False }
                        []
                        freshness
                        (if List.isEmpty items then
                            [ Html.p [] [ Html.text (pick "No AI proposals to review" "Ingen AI-forslag å vurdere") ] ]

                         else
                            render items
                        )
                    ]

                ( settled, _ ) ->
                    RemoteView.view ([ RemoteView.locale c.locale ] ++ (Maybe.map (RemoteView.onRetry >> List.singleton) c.onRetry |> Maybe.withDefault [])) settled (always [])
    in
    Freshness.region local.id
        [ Internal.cls [ "klar-ai-review" ], Attr.attribute "aria-label" data.label ]
        (if Freshness.waiting data.proposals then
            pick "Loading AI proposals" "Laster AI-forslag"

         else
            ""
        )
        (body
            ++ [ Html.div [ Attr.attribute "role" "alert" ] [ Html.text (Maybe.withDefault "" c.error) ]
               , case c.onSubmit of
                    Just submit ->
                        let
                            ready =
                                decisions data.ids data.proposals state
                        in
                        Button.view ([ Button.primary, Button.loading c.saving, Button.disabled (locked || ready == Nothing) ] ++ (Maybe.map (submit >> Button.onClick >> List.singleton) ready |> Maybe.withDefault [])) (pick "Save review decisions" "Lagre vurderinger")

                    Nothing ->
                        Html.text ""
               ]
        )
