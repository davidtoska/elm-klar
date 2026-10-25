module Klar.CommentThread exposing
    ( view
    , Comment, comment, replyTo, edited, removed, resolved
    , State, init, Msg, update, draft, setDraft, setReplyTo, reset
    , Submission, submission, submissionBody, submissionParent, acknowledge
    , Attribute, onSubmit, sending, errorMaybe, maxLength, onResolve, actions, onLoadMore, onRetry, locale, settings
    )

{-| A reply thread with safe Markdown, exact timestamps and a draft that survives
failed posting, refreshes and late acknowledgements.

Use when: people discuss a case, order or document and need replies in context.
Do not use when: the content records immutable system changes; use `Klar.AuditLog`.
Quick path: `comment`, `init`, `update`, `view`, `acknowledge`

    import Klar.CommentThread as Thread

    -- model: { thread : Thread.State } -- Thread.init "order-discussion"
    -- update:
    ThreadMsg inner ->
        let
            ( thread, cmd ) =
                Thread.update inner model.thread
        in
        ( { model | thread = thread }, Cmd.map ThreadMsg cmd )

    -- view:
    Thread.view ThreadMsg [ Thread.onSubmit PostComment ]
        { label = "Order discussion", ids = commentIds, comments = model.comments }
        model.thread

`PostComment` receives an opaque `Submission`: send `submissionBody` and
`submissionParent` to your backend. On failure keep the draft and show `errorMaybe`.
On success append the server's comment and call `acknowledge sentSubmission`.
It clears only the exact draft that was sent. A person may keep writing while a
post is pending; a late answer never clears that newer work. Use `sending True`
to prevent a second post while the first is outstanding. The application owns
request tickets and permissions; this component never sends anything itself.

Comments arrive as a flat list. `replyTo` groups replies beneath their parents;
roots and siblings retain input order. Missing parents are labelled. Cycles and
duplicate ids are visibly reported and every record remains visible. Deep chains
stop indenting after three levels, keeping the reply context readable on narrow
screens. Supply unique ids in normal use. Markdown cannot load images or run HTML.
Removed comments keep their place and replies but their body is never rendered.
Markdown headings start at h3, fitting a discussion under a page or card's h2.

The optional composer stays mounted in every remote state. It keeps raw input,
including whitespace and text over the limit; invalid text is never truncated.
Posting needs nonblank, valid-length text and current data. A reply to a comment
that disappeared is blocked until the person changes its target. Plain Enter
always inserts a newline: only clicking Post submits. Mentions are ordinary text;
the library does not infer recipients or notify anyone.

Give each thread a unique `init` id. Use `reset` when switching to another record:
it invalidates outstanding draft acknowledgements. The root id is a stable focus
target for the application's retry/load-more handlers (`Klar.focus`).

@docs view


# Comments

@docs Comment, comment, replyTo, edited, removed, resolved


# Local state

@docs State, init, Msg, update, draft, setDraft, setReplyTo, reset


# Posting

@docs Submission, submission, submissionBody, submissionParent, acknowledge


# Attributes

@docs Attribute, onSubmit, sending, errorMaybe, maxLength, onResolve, actions, onLoadMore, onRetry, locale, settings

-}

import Dict
import Html exposing (Html)
import Html.Attributes as Attr
import Html.Events as Events
import Html.Keyed as Keyed
import Klar.Avatar as Avatar
import Klar.Badge as Badge
import Klar.Button as Button
import Klar.CommentThread.Structure as Structure
import Klar.Format as Format
import Klar.Ids as Ids exposing (Ids)
import Klar.Internal as Internal
import Klar.Internal.Collection as Collection
import Klar.Locale as Locale exposing (Locale)
import Klar.Markdown as Markdown
import Klar.Remote as Remote exposing (Remote)
import Klar.Settings as Settings exposing (Settings)
import Klar.TextArea as TextArea
import Time


{-| A comment's content, context and moderation state. Build it with `comment`.
-}
type Comment id
    = Comment
        { id : id
        , author : String
        , body : String
        , at : Time.Posix
        , parent : Maybe id
        , editedAt : Maybe Time.Posix
        , removed : Bool
        , resolved : Bool
        }


{-| A top-level comment with exact source text and an instant. No text is parsed
or changed until it is rendered; raw HTML remains text.
-}
comment : { id : id, author : String, body : String, at : Time.Posix } -> Comment id
comment data =
    Comment { id = data.id, author = data.author, body = data.body, at = data.at, parent = Nothing, editedAt = Nothing, removed = False, resolved = False }


{-| Marks a comment as a reply to an application id. Missing parents stay visible.
-}
replyTo : id -> Comment id -> Comment id
replyTo parent (Comment data) =
    Comment { data | parent = Just parent }


{-| Shows when the comment was edited, without changing its creation time.
-}
edited : Time.Posix -> Comment id -> Comment id
edited at (Comment data) =
    Comment { data | editedAt = Just at }


{-| Hides a removed comment's body and keeps its identity and replies in place.
The author and timestamps remain; remove those upstream if they must be redacted.
-}
removed : Comment id -> Comment id
removed (Comment data) =
    Comment { data | removed = True }


{-| The application's resolved state. It adds a visible label and never hides replies.
False by default; `onResolve` asks the application to change it.
-}
resolved : Bool -> Comment id -> Comment id
resolved value (Comment data) =
    Comment { data | resolved = value }


{-| A raw draft, optional reply key and acknowledgement revision. No records or
functions are stored in the state.
-}
type State
    = State { id : String, draft : String, reply : Maybe String, preview : Bool, revision : Int }


{-| An empty draft. The string is a DOM id unique on the page.
-}
init : String -> State
init id =
    State { id = id, draft = "", reply = Nothing, preview = False, revision = 0 }


{-| Internal draft, preview and focus interactions. Route through `update`.
-}
type Msg
    = Draft String
    | Reply String
    | StartNew
    | Preview Bool
    | FocusComment String
    | NoOp


{-| Updates the local draft or reply target. Reply controls move focus to the
composer; returning to a parent moves focus to that comment's stable article.
-}
update : Msg -> State -> ( State, Cmd Msg )
update msg (State state) =
    case msg of
        Draft text ->
            ( setDraft text (State state), Cmd.none )

        Reply key ->
            ( State { state | reply = Just key, preview = False, revision = state.revision + 1 }
            , Internal.focus (state.id ++ "-draft") NoOp
            )

        StartNew ->
            ( State { state | reply = Nothing, preview = False, revision = state.revision + 1 }
            , Internal.focus (state.id ++ "-draft") NoOp
            )

        Preview value ->
            ( State { state | preview = value }, Cmd.none )

        FocusComment domId ->
            ( State state, Internal.focus domId NoOp )

        NoOp ->
            ( State state, Cmd.none )


{-| Exactly the draft text, including leading/trailing spaces and incomplete Markdown.
-}
draft : State -> String
draft (State state) =
    state.draft


{-| Sets draft text explicitly and invalidates acknowledgements for an earlier draft.
Setting the same text leaves its revision alone.
-}
setDraft : String -> State -> State
setDraft text (State state) =
    if text == state.draft then
        State state

    else
        State { state | draft = text, revision = state.revision + 1 }


{-| Sets or clears the reply target without changing the text or moving focus.
Changing the target invalidates an earlier submission's acknowledgement.
-}
setReplyTo : Ids id -> Maybe id -> State -> State
setReplyTo ids parent (State state) =
    let
        key =
            Maybe.map (Ids.toKey ids) parent
    in
    if key == state.reply then
        State state

    else
        State { state | reply = key, revision = state.revision + 1 }


{-| Clears the draft and target, preserving the DOM id and invalidating pending
acknowledgements. Use when beginning a different record's discussion.
-}
reset : State -> State
reset (State state) =
    State { state | draft = "", reply = Nothing, preview = False, revision = state.revision + 1 }


{-| An immutable snapshot of the body, parent and draft revision that was posted.
-}
type Submission id
    = Submission { body : String, parent : Maybe id, instance : String, revision : Int }


{-| Captures a nonblank draft and decodes its parent with your ids. Returns
Nothing for blank text or an undecodable parent. This pure accessor does not check
the current catalogue, length limit or remote freshness; `view` checks those too.
-}
submission : Ids id -> State -> Maybe (Submission id)
submission ids (State state) =
    let
        build parent =
            Submission { body = state.draft, parent = parent, instance = state.id, revision = state.revision }
    in
    if String.trim state.draft == "" then
        Nothing

    else
        case state.reply of
            Nothing ->
                Just (build Nothing)

            Just key ->
                Ids.fromKey ids key |> Maybe.map (Just >> build)


{-| The exact submitted text. It is not trimmed or reformatted.
-}
submissionBody : Submission id -> String
submissionBody (Submission sent) =
    sent.body


{-| The parent application id; Nothing means a top-level comment.
-}
submissionParent : Submission id -> Maybe id
submissionParent (Submission sent) =
    sent.parent


{-| Clears a successfully posted draft only when its instance and revision still
match. If the person typed or changed target meanwhile, their newer draft survives.
-}
acknowledge : Submission id -> State -> State
acknowledge (Submission sent) ((State state) as original) =
    if sent.instance == state.id && sent.revision == state.revision then
        reset original

    else
        original


{-| Optional thread interactions. Reading is enabled by default; posting is opt-in.
-}
type Attribute id msg
    = Attribute (Config id msg -> Config id msg)


type alias Config id msg =
    { onSubmit : Maybe (Submission id -> msg)
    , sending : Bool
    , error : Maybe String
    , maxLength : Int
    , onResolve : Maybe (id -> Bool -> msg)
    , actions : id -> List (Html msg)
    , onLoadMore : Maybe msg
    , onRetry : Maybe msg
    , locale : Locale
    , settings : Settings
    }


{-| Adds the draft composer and explicit post button. Receives an exact snapshot;
the application sends it, updates comments and acknowledges success. Absent by default.
-}
onSubmit : (Submission id -> msg) -> Attribute id msg
onSubmit toMsg =
    Attribute (\c -> { c | onSubmit = Just toMsg })


{-| Marks a pending post and blocks another submit. The draft stays editable so
the next comment can be written while the current one is sent. False by default.
-}
sending : Bool -> Attribute id msg
sending value =
    Attribute (\c -> { c | sending = value })


{-| A posting error announced above the composer. The draft is kept for retry.
Nothing by default. This is separate from failures to load comment history.
-}
errorMaybe : Maybe String -> Attribute id msg
errorMaybe value =
    Attribute (\c -> { c | error = value })


{-| The draft limit, default 10,000 UTF-16 code units, matching native text controls.
Over-limit text remains editable and is shown with an error, never truncated.
Configuration below zero means zero.
-}
maxLength : Int -> Attribute id msg
maxLength value =
    Attribute (\c -> { c | maxLength = max 0 value })


{-| Adds Resolve/Reopen controls. Receives the comment id and requested new state;
the application supplies `resolved` data and handles permissions/persistence.
These controls are disabled while history is stale or refreshing.
-}
onResolve : (id -> Bool -> msg) -> Attribute id msg
onResolve toMsg =
    Attribute (\c -> { c | onResolve = Just toMsg })


{-| Additional per-comment actions, keyed by your own id. Empty by default.
Permission checks and edit/delete confirmation belong to the application.
-}
actions : (id -> List (Html msg)) -> Attribute id msg
actions render =
    Attribute (\c -> { c | actions = render })


{-| Adds a load-more action, including when no comments are loaded. Append the
response and focus the thread root in its handler if the button will disappear.
-}
onLoadMore : msg -> Attribute id msg
onLoadMore msg =
    Attribute (\c -> { c | onLoadMore = Just msg })


{-| Retry for loading failures and stale history. Absent by default.
-}
onRetry : msg -> Attribute id msg
onRetry msg =
    Attribute (\c -> { c | onRetry = Just msg })


{-| Built-in text language. Defaults to English.
-}
locale : Locale -> Attribute id msg
locale value =
    Attribute (\c -> { c | locale = value })


{-| Time zone for creation/edit times and retained-data notices. Defaults to UTC.
-}
settings : Settings -> Attribute id msg
settings value =
    Attribute (\c -> { c | settings = value })


{-| A named remote history and optional composer. The root id from `init` is
stable in every remote state. Replies and Markdown heading ids are scoped to it.
-}
view : (Msg -> msg) -> List (Attribute id msg) -> { label : String, ids : Ids id, comments : Remote (List (Comment id)) } -> State -> Html msg
view toMsg attributes data ((State state) as original) =
    let
        c =
            List.foldl (\(Attribute change) acc -> change acc)
                { onSubmit = Nothing, sending = False, error = Nothing, maxLength = 10000, onResolve = Nothing, actions = always [], onLoadMore = Nothing, onRetry = Nothing, locale = Locale.default, settings = Settings.default }
                attributes

        pick en nb =
            Locale.pick c.locale { en = en, nb = nb }

        key =
            Ids.toKey data.ids

        loaded =
            Remote.toMaybe data.comments |> Maybe.withDefault []

        known =
            List.foldr (\(Comment item) acc -> Dict.insert (key item.id) item acc) Dict.empty loaded

        commentId value =
            state.id ++ "-comment-" ++ Internal.percentEncode value

        safe =
            Remote.toMaybe data.comments /= Nothing && not (Remote.isRefreshing data.comments) && not (Remote.isStale data.comments)

        parentExists =
            case state.reply of
                Just target ->
                    Dict.member target known

                Nothing ->
                    True

        excessive =
            String.length state.draft > c.maxLength

        render comments =
            let
                rows =
                    Structure.arrange (List.map (\((Comment item) as whole) -> { key = key item.id, parent = Maybe.map key item.parent, value = whole }) comments)

                row placed =
                    let
                        (Comment item) =
                            placed.value

                        domId =
                            case placed.suffix of
                                Nothing ->
                                    commentId placed.key

                                Just index ->
                                    state.id ++ "-duplicate-" ++ String.fromInt index

                        warning =
                            case placed.link of
                                Structure.Missing ->
                                    Just (pick "Reply to a comment outside the loaded history" "Svar på en kommentar utenfor innlastet historikk")

                                Structure.Cycle ->
                                    Just (pick "Reply chain contains a cycle" "Svarkjeden inneholder en sirkel")

                                Structure.Duplicate ->
                                    Just (pick "Duplicate comment id" "Duplisert kommentar-ID")

                                _ ->
                                    Nothing

                        parentContext =
                            placed.parent |> Maybe.andThen (\parent -> Dict.get parent known |> Maybe.map (Tuple.pair parent))
                    in
                    ( domId
                    , Html.li [ Internal.cls [ "klar-comment-thread__row" ], Internal.styleVars [ ( "--klar-comment-depth", String.fromInt (min 3 placed.depth) ) ] ]
                        [ Html.article [ Attr.id domId, Attr.tabindex -1, Attr.attribute "aria-label" (pick "Comment by " "Kommentar fra " ++ item.author), Internal.cls [ "klar-comment-thread__comment" ] ]
                            [ Html.div [ Internal.cls [ "klar-comment-thread__byline" ] ]
                                [ Avatar.view [ Avatar.extraSmall, Avatar.decorative ] item.author
                                , Html.strong [] [ Html.text item.author ]
                                , Html.span [ Internal.cls [ "klar-comment-thread__time" ] ] [ Html.text (Settings.dateTime c.locale c.settings item.at) ]
                                , case item.editedAt of
                                    Just at ->
                                        Html.span [ Internal.cls [ "klar-comment-thread__time" ] ] [ Html.text (pick "Edited " "Redigert " ++ Settings.dateTime c.locale c.settings at) ]

                                    Nothing ->
                                        Html.text ""
                                , if item.resolved then
                                    Badge.view [] (pick "Resolved" "Løst")

                                  else
                                    Html.text ""
                                ]
                            , case warning of
                                Just text ->
                                    Html.p [ Internal.cls [ "klar-comment-thread__notice" ] ] [ Html.text text ]

                                Nothing ->
                                    Html.text ""
                            , case parentContext of
                                Just ( parentKey, parent ) ->
                                    if placed.link == Structure.Duplicate then
                                        Html.text ""

                                    else
                                        Button.view [ Button.small, Button.link, Button.onClick (toMsg (FocusComment (commentId parentKey))) ] (pick "In reply to " "Som svar til " ++ parent.author)

                                Nothing ->
                                    Html.text ""
                            , if item.removed then
                                Html.p [ Internal.cls [ "klar-comment-thread__removed" ] ] [ Html.text (pick "This comment was removed" "Denne kommentaren er fjernet") ]

                              else
                                Markdown.view [ Markdown.locale c.locale, Markdown.idPrefix (domId ++ "-md-"), Markdown.headingOffset 2 ] item.body
                            , Html.div [ Internal.cls [ "klar-comment-thread__actions" ] ]
                                (if placed.link == Structure.Duplicate then
                                    []

                                 else
                                    (case c.onSubmit of
                                        Just _ ->
                                            [ Button.view [ Button.small, Button.ghost, Button.onClick (toMsg (Reply placed.key)) ] (pick "Reply" "Svar") ]

                                        Nothing ->
                                            []
                                    )
                                        ++ (case c.onResolve of
                                                Just callback ->
                                                    [ Button.view [ Button.small, Button.ghost, Button.disabled (not safe), Button.onClick (callback item.id (not item.resolved)) ]
                                                        (if item.resolved then
                                                            pick "Reopen" "Åpne igjen"

                                                         else
                                                            pick "Resolve" "Marker som løst"
                                                        )
                                                    ]

                                                Nothing ->
                                                    []
                                           )
                                        ++ c.actions item.id
                                )
                            ]
                        ]
                    )
            in
            Html.div []
                [ Html.div [ Internal.cls [ "klar-comment-thread__count" ], Attr.attribute "role" "status" ] [ Html.text (Format.int c.locale (List.length comments) ++ pick " loaded comments" " innlastede kommentarer") ]
                , Keyed.ol [ Internal.cls [ "klar-comment-thread__list" ] ] (List.map row rows)
                , Collection.more c.locale c.onLoadMore
                ]

        composer =
            case c.onSubmit of
                Nothing ->
                    Html.text ""

                Just submit ->
                    Html.div [ Internal.cls [ "klar-comment-thread__composer" ] ]
                        [ Html.div [ Internal.cls [ "klar-comment-thread__target" ] ]
                            [ case state.reply of
                                Nothing ->
                                    Html.strong [] [ Html.text (pick "New comment" "Ny kommentar") ]

                                Just target ->
                                    Html.span [] [ Html.text (Dict.get target known |> Maybe.map (\item -> pick "Replying to " "Svarer til " ++ item.author) |> Maybe.withDefault (pick "Reply target is unavailable" "Kommentaren du svarer på er utilgjengelig")) ]
                            , if state.reply == Nothing then
                                Html.text ""

                              else
                                Button.view [ Button.small, Button.ghost, Button.onClick (toMsg StartNew) ] (pick "Start a new comment instead" "Skriv en ny kommentar i stedet")
                            ]
                        , case c.error of
                            Just message ->
                                Html.div [ Attr.attribute "role" "alert", Internal.cls [ "klar-comment-thread__error" ] ] [ Html.text message ]

                            Nothing ->
                                Html.text ""
                        , Html.div [ Internal.cls [ "klar-comment-thread__actions" ] ]
                            [ Button.view [ Button.small, Button.pressed (not state.preview), Button.onClick (toMsg (Preview False)) ] (pick "Write" "Skriv")
                            , Button.view [ Button.small, Button.pressed state.preview, Button.onClick (toMsg (Preview True)) ] (pick "Preview" "Forhåndsvis")
                            ]
                        , Html.div [ Attr.hidden state.preview ]
                            [ TextArea.view
                                [ TextArea.id (state.id ++ "-draft")
                                , TextArea.label (pick "Comment" "Kommentar")
                                , TextArea.hint (pick "Markdown supported. Enter inserts a new line." "Markdown støttes. Enter setter inn en ny linje.")
                                , TextArea.value state.draft
                                , TextArea.onInput (Draft >> toMsg)
                                , TextArea.minRows 3
                                , TextArea.maxRows 10
                                , TextArea.locale c.locale
                                , TextArea.errorMaybe
                                    (if excessive then
                                        Just (pick "Comment exceeds the character limit" "Kommentaren overskrider tegngrensen")

                                     else
                                        Nothing
                                    )
                                ]
                            ]
                        , Html.div [ Attr.hidden (not state.preview), Internal.cls [ "klar-comment-thread__preview" ], Attr.attribute "role" "region", Attr.attribute "aria-label" (pick "Comment preview" "Forhåndsvisning av kommentar"), Attr.tabindex 0 ]
                            [ if not state.preview then
                                Html.text ""

                              else if String.trim state.draft == "" then
                                Html.text (pick "Nothing to preview" "Ingenting å forhåndsvise")

                              else
                                Markdown.view [ Markdown.locale c.locale, Markdown.idPrefix (state.id ++ "-preview-md-"), Markdown.headingOffset 2 ] state.draft
                            ]
                        , Html.div [ Internal.cls [ "klar-comment-thread__footer" ] ]
                            [ Html.span
                                [ Internal.cls [ "klar-comment-thread__time" ]
                                , Attr.attribute "aria-live"
                                    (if excessive then
                                        "polite"

                                     else
                                        "off"
                                    )
                                ]
                                [ Html.text (Format.int c.locale (String.length state.draft) ++ " / " ++ Format.int c.locale c.maxLength) ]
                            , case submission data.ids original of
                                Just sent ->
                                    Button.view [ Button.primary, Button.loading c.sending, Button.disabled (c.sending || excessive || not safe || not parentExists), Button.onClick (submit sent) ] (pick "Post comment" "Publiser kommentar")

                                Nothing ->
                                    Button.view [ Button.primary, Button.disabled True ] (pick "Post comment" "Publiser kommentar")
                            ]
                        , if safe then
                            Html.text ""

                          else
                            Html.p [ Internal.cls [ "klar-comment-thread__notice" ] ] [ Html.text (pick "Load current comments before posting" "Last gjeldende kommentarer før du publiserer") ]
                        ]
    in
    Html.section [ Attr.id state.id, Attr.tabindex -1, Attr.attribute "aria-label" data.label, Internal.cls [ "klar-comment-thread" ] ]
        [ Html.div [ Internal.cls [ "klar-comment-thread__history" ] ]
            (Collection.view { locale = c.locale, settings = c.settings, onRetry = c.onRetry, onLoadMore = c.onLoadMore } (pick "No comments yet" "Ingen kommentarer ennå") data.comments render)
        , composer
        ]
