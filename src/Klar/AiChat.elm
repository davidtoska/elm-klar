module Klar.AiChat exposing
    ( view
    , Message, message, Role(..), Status(..)
    , State, init, Msg, update, draft, setDraft, reset
    , Submission, submissionText, acknowledge
    , Attribute, onSend, onStop, onRetry, maxLength, content, locale, settings
    )

{-| A transport-neutral AI conversation with safe Markdown, streamed answers,
explicit generation status and a composer that preserves newer drafts.

Use when: an application talks to AI on its own server and needs a conversation UI.
Do not use when: discussing an ordinary record; use `Klar.CommentThread`.
Quick path: `message`, `init`, `update`, `view`, `onSend`, `acknowledge`

    import Klar.AiChat as Chat

    -- model: { chat : Chat.State } -- Chat.init "assistant"
    -- update:
    ChatMsg inner ->
        let
            ( chat, cmd ) =
                Chat.update inner model.chat
        in
        ( { model | chat = chat }, Cmd.map ChatMsg cmd )

    -- view:
    Chat.view ChatMsg [ Chat.onSend SendPrompt, Chat.onStop StopGeneration ]
        { label = "Operations assistant", ids = messageIds, messages = model.messages, status = model.status }
        model.chat

Send `submissionText` to your application server. Keep provider keys, tool execution,
authorization and retrieval on the server. Set `Generating` while awaiting/streaming
a response. Append chunks to the same assistant message id. Acknowledge the captured
submission only when the server accepts the prompt; a newer draft survives a late
acknowledgement. Failed requests preserve the draft. Keep request tickets in the
application and discard chunks/completions from stopped or replaced runs.

Stop is an explicit request to the application, which cancels the transport and sets
`Interrupted`; partial text stays visible. `Failed` also retains the conversation.
Retry reissues the failed generation, rather than posting the draft again. Do not
persist `Generating` indefinitely after a connection loss. `reset` invalidates draft
acknowledgements when switching conversations. Send is blocked during generation,
unavailable/stale/refreshing history, blank or over-limit input, and duplicate ids.

Enter inserts a newline; only the Send button submits. No automatic scrolling steals
the reader's place. Streamed text is not a live region; only concise status changes
are announced. Tool messages are plain reported results, never executable commands.
Embed proposal review, tables or JSON through `content`. Markdown cannot run HTML or
load images; truncated Markdown is visibly marked by the renderer.

@docs view


# Conversation

@docs Message, message, Role, Status


# Composer

@docs State, init, Msg, update, draft, setDraft, reset


# Server acknowledgement

@docs Submission, submissionText, acknowledge


# Attributes

@docs Attribute, onSend, onStop, onRetry, maxLength, content, locale, settings

-}

import Html exposing (Html)
import Html.Attributes as Attr
import Html.Keyed as Keyed
import Klar.Button as Button
import Klar.Ids as Ids exposing (Ids)
import Klar.Internal as Internal
import Klar.Internal.Freshness as Freshness
import Klar.Locale as Locale exposing (Locale)
import Klar.Markdown as Markdown
import Klar.Remote as Remote exposing (Remote)
import Klar.RemoteView as RemoteView
import Klar.Settings as Settings exposing (Settings)
import Klar.TextArea as TextArea
import Set


{-| Who produced a message. Tool results are display data and execute nothing.
-}
type Role
    = User
    | Assistant
    | Tool


{-| State of the server generation, independent of loading conversation history.
Interrupted and failed generations keep all partial messages visible.
-}
type Status
    = Idle
    | Generating
    | Interrupted
    | Failed String


{-| A stable application id, role, display name and raw Markdown body.
-}
type Message id
    = Message { id : id, role : Role, author : String, body : String }


{-| Creates a message. During streaming replace its body, keeping its id stable.
-}
message : { id : id, role : Role, author : String, body : String } -> Message id
message =
    Message


{-| A raw composer and monotonically increasing acknowledgement revision.
-}
type State
    = State { id : String, draft : String, revision : Int }


{-| Empty composer. The string is a unique DOM id for this conversation.
-}
init : String -> State
init id =
    State { id = id, draft = "", revision = 0 }


{-| Internal text input. Route through `update`.
-}
type Msg
    = Draft String


{-| Preserves exactly the input text. No commands are needed.
-}
update : Msg -> State -> ( State, Cmd Msg )
update (Draft text) state =
    ( setDraft text state, Cmd.none )


{-| Raw draft including spaces and incomplete Markdown.
-}
draft : State -> String
draft (State state) =
    state.draft


{-| Sets raw text, invalidating earlier acknowledgements only when it changes.
-}
setDraft : String -> State -> State
setDraft text (State state) =
    if text == state.draft then
        State state

    else
        State { state | draft = text, revision = state.revision + 1 }


{-| Clears the composer and invalidates outstanding acknowledgements. Use when
switching conversations, even when the new conversation has the same draft.
-}
reset : State -> State
reset (State state) =
    State { state | draft = "", revision = state.revision + 1 }


{-| Exact submitted draft, bound to its composer and editing revision.
-}
type Submission
    = Submission { id : String, text : String, revision : Int }


{-| Exact prompt text to send to your own server.
-}
submissionText : Submission -> String
submissionText (Submission sent) =
    sent.text


{-| Clears only the accepted draft. Late responses never erase newer writing.
-}
acknowledge : Submission -> State -> State
acknowledge (Submission sent) (State state) =
    if sent.id == state.id && sent.revision == state.revision && sent.text == state.draft then
        reset (State state)

    else
        State state


{-| Optional actions and embedded structured message content.
-}
type Attribute id msg
    = Attribute (Config id msg -> Config id msg)


type alias Config id msg =
    { onSend : Maybe (Submission -> msg), onStop : Maybe msg, onRetry : Maybe msg, maxLength : Int, content : Maybe (id -> Html msg), locale : Locale, settings : Settings }


{-| Adds the composer and an explicit Send button. Receives an immutable draft.
-}
onSend : (Submission -> msg) -> Attribute id msg
onSend f =
    Attribute (\c -> { c | onSend = Just f })


{-| Requests that the application cancel the active server run. Absent by default.
-}
onStop : msg -> Attribute id msg
onStop msg =
    Attribute (\c -> { c | onStop = Just msg })


{-| Retry action for failed history or a failed/interrupted generation.
The application decides which request to repeat. Absent by default.
-}
onRetry : msg -> Attribute id msg
onRetry msg =
    Attribute (\c -> { c | onRetry = Just msg })


{-| Maximum prompt length, at least one character. Defaults to 8000.
Over-limit input remains visible and is never truncated.
-}
maxLength : Int -> Attribute id msg
maxLength n =
    Attribute (\c -> { c | maxLength = max 1 n })


{-| Structured content beneath a message, receiving its application id. Embed
AiReview, tables, charts or JsonViewer here. Absent by default.
-}
content : (id -> Html msg) -> Attribute id msg
content f =
    Attribute (\c -> { c | content = Just f })


{-| Language of built-in text. Defaults to English.
-}
locale : Locale -> Attribute id msg
locale value =
    Attribute (\c -> { c | locale = value })


{-| Retained-data timestamp formatting. Defaults to `Settings.default`.
-}
settings : Settings -> Attribute id msg
settings value =
    Attribute (\c -> { c | settings = value })


{-| Conversation history, stable stream status and optional composer. The root
remains a focus target while history loads or fails. Message ids must be unique.
-}
view : (Msg -> msg) -> List (Attribute id msg) -> { label : String, ids : Ids id, messages : Remote (List (Message id)), status : Status } -> State -> Html msg
view toMsg attributes data (State state) =
    let
        c =
            List.foldl (\(Attribute f) acc -> f acc) { onSend = Nothing, onStop = Nothing, onRetry = Nothing, maxLength = 8000, content = Nothing, locale = Locale.default, settings = Settings.default } attributes

        pick en nb =
            Locale.pick c.locale { en = en, nb = nb }

        items =
            Remote.toMaybe data.messages |> Maybe.withDefault []

        unique =
            Set.size (Set.fromList (List.map (\(Message m) -> Ids.toKey data.ids m.id) items)) == List.length items

        fresh =
            Remote.toMaybe data.messages /= Nothing && not (Remote.isRefreshing data.messages || Remote.isStale data.messages)

        generating =
            data.status == Generating

        valid =
            String.trim state.draft /= "" && String.length state.draft <= c.maxLength

        statusText =
            case data.status of
                Idle ->
                    pick "Ready" "Klar"

                Generating ->
                    pick "AI is generating a response" "AI genererer et svar"

                Interrupted ->
                    pick "Generation stopped. The partial response is retained." "Genereringen er stoppet. Det ufullstendige svaret er beholdt."

                Failed problem ->
                    pick "Generation failed: " "Genereringen feilet: " ++ problem

        row index (Message m) =
            let
                role =
                    case m.role of
                        User ->
                            pick "You" "Du"

                        Assistant ->
                            pick "AI assistant" "AI-assistent"

                        Tool ->
                            pick "Tool result" "Verktøyresultat"

                domId =
                    state.id
                        ++ "-message-"
                        ++ (if unique then
                                Internal.percentEncode (Ids.toKey data.ids m.id)

                            else
                                String.fromInt index
                           )
            in
            ( if unique then
                Ids.toKey data.ids m.id

              else
                String.fromInt index
            , Html.article [ Internal.classes [ ( "klar-ai-chat__message", True ), ( "klar-ai-chat__message--assistant", m.role == Assistant ) ], Attr.attribute "aria-labelledby" domId ]
                [ Html.h3 [ Attr.id domId ] [ Html.text (m.author ++ " · " ++ role) ]
                , Markdown.view [ Markdown.locale c.locale, Markdown.headingOffset 3, Markdown.idPrefix domId ] m.body
                , Maybe.map (\render -> render m.id) c.content |> Maybe.withDefault (Html.text "")
                ]
            )

        history =
            case Freshness.settle data.messages of
                ( Remote.Loaded messages, freshness ) ->
                    [ Freshness.wrap { locale = c.locale, settings = c.settings, onRetry = c.onRetry, inline = False }
                        []
                        freshness
                        [ if List.isEmpty messages then
                            Html.p [] [ Html.text (pick "Start a conversation with AI" "Start en samtale med AI") ]

                          else
                            Keyed.node "div" [] (List.indexedMap row messages)
                        ]
                    ]

                ( settled, _ ) ->
                    RemoteView.view ([ RemoteView.locale c.locale ] ++ (Maybe.map (RemoteView.onRetry >> List.singleton) c.onRetry |> Maybe.withDefault [])) settled (always [])

        retry =
            case data.status of
                Failed _ ->
                    True

                Interrupted ->
                    True

                _ ->
                    False
    in
    Freshness.region state.id
        [ Internal.cls [ "klar-ai-chat" ], Attr.attribute "aria-label" data.label ]
        (if Freshness.waiting data.messages then
            pick "Loading conversation" "Laster samtalen"

         else
            ""
        )
        (history
            ++ [ Html.div [ Attr.attribute "role" "status", Internal.cls [ "klar-ai__status" ] ] [ Html.text statusText ]
               , if unique then
                    Html.text ""

                 else
                    Html.p [ Attr.attribute "role" "alert" ] [ Html.text (pick "Duplicate message ids. Sending is disabled." "Dupliserte meldings-ID-er. Sending er deaktivert.") ]
               , Html.div [ Internal.cls [ "klar-ai__actions" ] ]
                    (List.filterMap identity
                        [ if generating then
                            Maybe.map (\msg -> Button.view [ Button.onClick msg ] (pick "Stop generating" "Stopp generering")) c.onStop

                          else
                            Nothing
                        , if retry && fresh then
                            Maybe.map (\msg -> Button.view [ Button.onClick msg ] (pick "Retry response" "Prøv svaret på nytt")) c.onRetry

                          else
                            Nothing
                        ]
                    )
               , case c.onSend of
                    Nothing ->
                        Html.text ""

                    Just send ->
                        Html.div [ Internal.cls [ "klar-ai-chat__composer" ] ]
                            [ TextArea.view [ TextArea.id (state.id ++ "-draft"), TextArea.label (pick "Message to AI" "Melding til AI"), TextArea.value state.draft, TextArea.onInput (Draft >> toMsg) ]
                            , Html.p [ Attr.attribute "role" "status" ]
                                [ Html.text
                                    (if String.length state.draft > c.maxLength then
                                        pick "Prompt exceeds the character limit: " "Meldingen overskrider tegngrensen: " ++ String.fromInt c.maxLength

                                     else
                                        ""
                                    )
                                ]
                            , Button.view [ Button.primary, Button.disabled (generating || not fresh || not unique || not valid), Button.onClick (send (Submission { id = state.id, text = state.draft, revision = state.revision })) ] (pick "Send message" "Send melding")
                            ]
               ]
        )
