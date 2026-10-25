module Klar.UploadQueue exposing
    ( view
    , State, init, Msg, update, files, rawFiles, rejected, canAdd, clear
    , Upload, upload, withStatus, FileInfo
    , Status, pending, transferring, completed, failed, cancelled
    , Attribute, accept, maxSize, maxFiles, disabled, onStart, onStartAll, onRetry, onCancel, onRemove, locale
    )

{-| A local file-transfer workbench: validated file staging, an explicit add
action, and an application-controlled queue with exact byte progress.

Use when: users upload several files and need to inspect validation, progress, failures and cancellation per file.
Do not use when: choosing attachments is the whole task; use `Klar.FileDrop`.
Quick path: `init`, `update`, `view`, `upload`, `withStatus`

    import Klar.UploadQueue as UploadQueue

    -- model: { uploadPicker : UploadQueue.State } -- UploadQueue.init "order-files"
    -- update:
    UploadPickerMsg inner ->
        let
            ( uploadPicker, cmd ) =
                UploadQueue.update inner model.uploadPicker
        in
        ( { model | uploadPicker = uploadPicker }, Cmd.map UploadPickerMsg cmd )

    -- view:
    UploadQueue.view UploadPickerMsg
        [ UploadQueue.accept [ ".pdf", "image/*" ]
        , UploadQueue.maxSize 10000000
        , UploadQueue.maxFiles 5
        , UploadQueue.onStart StartUpload
        , UploadQueue.onRetry RetryUpload
        , UploadQueue.onCancel CancelUpload
        , UploadQueue.onRemove RemoveUpload
        ]
        { label = "Order attachments", ids = uploadIds
        , uploads = model.uploads, onAdd = AddFilesToQueue
        }
        model.uploadPicker

**The application owns transmission.** `onAdd` receives the accepted browser
`File` values only after the person clicks "Add files to queue". Give them your
own ids, keep the files in your model, add `upload` values and `clear` the staging
state. No request starts until your application starts one. The component reads
neither file contents nor HTTP, and performs no automatic retry. Metadata in the
queue is separate from source `File` values; persisting metadata cannot restore a
browser file after a reload.

The queue is local data, so it is a plain list rather than `Remote`. Each transfer
has its own explicit status. Use `RemoteView` around separately fetched upload
history if that is part of the page. Queue ids must be unique; duplicate keys
keep every row visible but disable ambiguous transfer actions with an explicit warning.

**Progress is bytes, not completion.** `transferring` draws exact sent/total byte
counts, without rounding a nearly finished upload to 100%. Unknown totals are
indeterminate. A zero-byte transfer waits for confirmation. Sending every byte
still says "Waiting for confirmation" until the application supplies `completed`.
Negative counts and sent counts exceeding the total remain visible as invalid
reports; they are never quietly clamped into a successful-looking bar.

**Validation and focus.** Staging reuses `Klar.FileDrop`, including extension/MIME,
size, count and duplicate checks, and keeps rejected selections visible. Removing
another staged file can resolve duplicate and count-limit rejections. Staging is
bound to the rules under which it began. Changing a rule disables adding that
batch, with an explicit message to clear it and choose files again. Files remain
visible; no selection is discarded or silently reinterpreted. `canAdd` exposes
the same check for application submission controls.
The add action is unavailable until rejections are resolved and actual browser
files exist. Limits apply to each staged batch, not completed queue history.
The region's `init` id is a stable focus target: when a retry/start/cancel/remove
action disappears after your update, run `Klar.focus "order-files" NoOp` in that
handler. The view's "Clear selection" action restores focus to its file chooser;
the pure `clear` function does not move focus.

@docs view


# Staging

@docs State, init, Msg, update, files, rawFiles, rejected, canAdd, clear


# Queue entries

@docs Upload, upload, withStatus, FileInfo


# Transfer states

@docs Status, pending, transferring, completed, failed, cancelled


# Attributes

@docs Attribute, accept, maxSize, maxFiles, disabled, onStart, onStartAll, onRetry, onCancel, onRemove, locale

-}

import File exposing (File)
import Html exposing (Html)
import Html.Attributes as Attr
import Html.Keyed as Keyed
import Klar.Button as Button
import Klar.FileDrop as FileDrop
import Klar.Format as Format
import Klar.Icon as Icon
import Klar.Ids as Ids exposing (Ids)
import Klar.Internal as Internal
import Klar.Locale as Locale exposing (Locale)
import Klar.Remote as Remote
import Set


{-| The file's name, byte size and MIME type. This is metadata, not a browser file.
-}
type alias FileInfo =
    FileDrop.FileInfo


{-| The file chooser's local state. Queue entries and source files are application data.
-}
type State
    = State { id : String, picker : FileDrop.State, policy : Maybe Policy, invalidated : Bool }


type alias Policy =
    { accept : List String, maxSize : Maybe Int, maxFiles : Maybe Int }


{-| Creates empty staging. The string is a DOM id unique on the page and the
stable queue focus target; the file chooser uses this id with `-choose` appended.
-}
init : String -> State
init id =
    State { id = id, picker = FileDrop.init (id ++ "-choose"), policy = Nothing, invalidated = False }


{-| File-staging interactions. Route them through `update`.
-}
type Msg
    = Picker Policy FileDrop.Msg
    | ClearStaging
    | NoOp


{-| Updates staging and keeps file-picker focus after removing or clearing files.
Transfer status and requests remain in your application's update.
-}
update : Msg -> State -> ( State, Cmd Msg )
update msg (State state) =
    case msg of
        Picker rules inner ->
            let
                ( picker, cmd ) =
                    FileDrop.update inner state.picker

                wasEmpty =
                    pickerEmpty state.picker

                nowEmpty =
                    pickerEmpty picker

                changed =
                    ( FileDrop.values state.picker, FileDrop.rejected state.picker ) /= ( FileDrop.values picker, FileDrop.rejected picker )
            in
            ( State
                { state
                    | picker = picker
                    , policy =
                        if nowEmpty then
                            Nothing

                        else if wasEmpty then
                            Just rules

                        else
                            state.policy
                    , invalidated = not nowEmpty && not wasEmpty && (state.invalidated || (changed && state.policy /= Just rules))
                }
            , Cmd.map (Picker rules) cmd
            )

        ClearStaging ->
            ( clear (State state), Internal.focus (state.id ++ "-choose") NoOp )

        NoOp ->
            ( State state, Cmd.none )


{-| Metadata of accepted staged files, in selection order. Rejected files are excluded.
-}
files : State -> List FileInfo
files (State state) =
    FileDrop.values state.picker


{-| Actual accepted browser files, without reading them. Only these are eligible
for the explicit add-to-queue action.
-}
rawFiles : State -> List File
rawFiles (State state) =
    FileDrop.rawFiles state.picker


{-| Every rejected staged file and its `Klar.FileDrop.Problem`, in selection order.
-}
rejected : State -> List ( FileInfo, FileDrop.Problem )
rejected (State state) =
    FileDrop.rejected state.picker


pickerEmpty : FileDrop.State -> Bool
pickerEmpty picker =
    List.isEmpty (FileDrop.values picker) && List.isEmpty (FileDrop.rejected picker)


{-| Whether staging can be added under the current rules: actual browser files
exist, no rejected selections remain, the original policy still matches and the
component is enabled. Use this alongside `rawFiles` for a custom submit action.
-}
canAdd : List (Attribute id msg) -> State -> Bool
canAdd attributes ((State state) as staging) =
    let
        c =
            configure attributes
    in
    not c.disabled
        && not state.invalidated
        && state.policy
        == Just (policyOf c)
        && not (List.isEmpty (rawFiles staging))
        && List.isEmpty (rejected staging)


{-| Clears only staging; it never removes queued transfers or moves focus. Call
after copying `rawFiles` to your model. The view's clear action also restores focus.
-}
clear : State -> State
clear (State state) =
    State { state | picker = FileDrop.clear state.picker, policy = Nothing, invalidated = False }


{-| A transfer's explicit state. Use the constructors below; the set can grow
without adding public union constructors.
-}
type Status
    = Pending
    | Transferring { sent : Int, total : Maybe Int }
    | Completed
    | Failed Remote.Problem
    | Cancelled


{-| Waiting for an explicit start action. This is a new upload's default state.
-}
pending : Status
pending =
    Pending


{-| Bytes sent and optional total bytes, supplied by your transport. Unknown or
zero totals are indeterminate; inconsistent reports stay visibly invalid. Even a
fully sent transfer waits for `completed` before it is called complete.
-}
transferring : { sent : Int, total : Maybe Int } -> Status
transferring =
    Transferring


{-| The server has confirmed completion. No transfer actions remain except removal.
-}
completed : Status
completed =
    Completed


{-| A transfer failed. Retry appears only if an `onRetry` callback is supplied
and `Remote.isRetryable` says trying again can help.
-}
failed : Remote.Problem -> Status
failed =
    Failed


{-| Cancellation was confirmed by the application. An explicit retry is available
when supplied; a cancel click itself does not manufacture this state.
-}
cancelled : Status
cancelled =
    Cancelled


{-| One application-identified transfer, with immutable file metadata and a status.
-}
type Upload id
    = Upload { id : id, file : FileInfo, status : Status }


{-| Creates a pending transfer from an application id and file metadata. Keep
its browser `File` separately in your own model.
-}
upload : { id : id, file : FileInfo } -> Upload id
upload data =
    Upload { id = data.id, file = data.file, status = Pending }


{-| Replaces a transfer's status after your application receives new information.
The component does not start, retry, finish or cancel a transfer by itself.
-}
withStatus : Status -> Upload id -> Upload id
withStatus status (Upload data) =
    Upload { data | status = status }


{-| Optional staging rules and transfer actions. Later attributes win.
-}
type Attribute id msg
    = Attribute (Config id msg -> Config id msg)


type alias Config id msg =
    { accept : List String
    , maxSize : Maybe Int
    , maxFiles : Maybe Int
    , disabled : Bool
    , onStart : Maybe (id -> msg)
    , onStartAll : Maybe (List id -> msg)
    , onRetry : Maybe (id -> msg)
    , onCancel : Maybe (id -> msg)
    , onRemove : Maybe (id -> msg)
    , locale : Locale
    }


configure : List (Attribute id msg) -> Config id msg
configure attributes =
    List.foldl (\(Attribute change) acc -> change acc)
        { accept = [], maxSize = Nothing, maxFiles = Nothing, disabled = False, onStart = Nothing, onStartAll = Nothing, onRetry = Nothing, onCancel = Nothing, onRemove = Nothing, locale = Locale.default }
        attributes


policyOf : Config id msg -> Policy
policyOf c =
    { accept = c.accept |> List.map (String.trim >> String.toLower) |> Set.fromList |> Set.toList
    , maxSize = c.maxSize
    , maxFiles = c.maxFiles
    }


{-| Allowed extensions (`.pdf`), MIME types or groups (`image/*`) for staging.
Defaults to all file types. Native selection and drops use the same rules.
-}
accept : List String -> Attribute id msg
accept patterns =
    Attribute (\c -> { c | accept = patterns })


{-| Maximum staged file size in bytes, inclusive. No limit by default. A negative
limit accepts no files; it is never silently converted into an unlimited value.
-}
maxSize : Int -> Attribute id msg
maxSize bytes =
    Attribute (\c -> { c | maxSize = Just bytes })


{-| Maximum accepted files in one staged batch, not the length of queue history.
No limit by default. A limit of one uses FileDrop's replace-on-next-choice mode.
-}
maxFiles : Int -> Attribute id msg
maxFiles count =
    Attribute (\c -> { c | maxFiles = Just count })


{-| Disables file selection and every action while `True`. Statuses stay visible.
Defaults to `False`.
-}
disabled : Bool -> Attribute id msg
disabled value =
    Attribute (\c -> { c | disabled = value })


{-| Adds a start action to pending transfers. The callback receives the application id.
-}
onStart : (id -> msg) -> Attribute id msg
onStart toMsg =
    Attribute (\c -> { c | onStart = Just toMsg })


{-| Adds a bulk start action sending only pending ids in queue order. Disabled
when none are pending; retries never join this action.
-}
onStartAll : (List id -> msg) -> Attribute id msg
onStartAll toMsg =
    Attribute (\c -> { c | onStartAll = Just toMsg })


{-| Adds retry to retryable failures and confirmed cancellations. Nothing retries
automatically, and retrying sends only the application's upload id.
-}
onRetry : (id -> msg) -> Attribute id msg
onRetry toMsg =
    Attribute (\c -> { c | onRetry = Just toMsg })


{-| Adds a cancel request to active transfers. Keep the transfer active until
your transport confirms cancellation or completion.
-}
onCancel : (id -> msg) -> Attribute id msg
onCancel toMsg =
    Attribute (\c -> { c | onCancel = Just toMsg })


{-| Adds removal to pending and terminal transfers. Active transfers must be
cancelled before removal, so no running request is silently forgotten.
-}
onRemove : (id -> msg) -> Attribute id msg
onRemove toMsg =
    Attribute (\c -> { c | onRemove = Just toMsg })


{-| Built-in text and number language. Defaults to English.
-}
locale : Locale -> Attribute id msg
locale value =
    Attribute (\c -> { c | locale = value })


{-| Draws validated staging and the controlled queue. `label` names the region;
`ids` writes unique application ids; `onAdd` receives actual accepted files only
after an explicit click. It does not also clear staging or start a request.
-}
view :
    (Msg -> msg)
    -> List (Attribute id msg)
    -> { label : String, ids : Ids id, uploads : List (Upload id), onAdd : List File -> msg }
    -> State
    -> Html msg
view toMsg attributes data ((State state) as staging) =
    let
        c =
            configure attributes

        pick en nb =
            Locale.pick c.locale { en = en, nb = nb }

        actualFiles =
            rawFiles staging

        hasStaging =
            not (List.isEmpty (files staging) && List.isEmpty (rejected staging))

        policyChanged =
            hasStaging && (state.invalidated || state.policy /= Just (policyOf c))

        pendingIds =
            List.filterMap
                (\(Upload item) ->
                    if item.status == Pending then
                        Just item.id

                    else
                        Nothing
                )
                data.uploads

        ambiguousIds =
            (data.uploads |> List.map (\(Upload item) -> Ids.toKey data.ids item.id) |> Set.fromList |> Set.size) /= List.length data.uploads

        count predicate =
            List.filter (\(Upload item) -> predicate item.status) data.uploads |> List.length |> Format.int c.locale

        summary =
            String.join " · "
                [ Format.int c.locale (List.length data.uploads) ++ pick " files" " filer"
                , count ((==) Pending) ++ pick " waiting" " venter"
                , count
                    (\status ->
                        case status of
                            Transferring _ ->
                                True

                            _ ->
                                False
                    )
                    ++ pick " transferring" " overføres"
                , count
                    (\status ->
                        case status of
                            Failed _ ->
                                True

                            _ ->
                                False
                    )
                    ++ pick " failed" " feilet"
                , count ((==) Completed) ++ pick " completed" " fullført"
                , count ((==) Cancelled) ++ pick " cancelled" " avbrutt"
                ]

        row index (Upload item) =
            let
                action maybeHandler label =
                    case maybeHandler of
                        Just handler ->
                            [ Button.view [ Button.small, Button.ghost, Button.disabled (c.disabled || ambiguousIds), Button.ariaLabel (label ++ ": " ++ item.file.name), Button.onClick (handler item.id) ] label ]

                        Nothing ->
                            []

                actions =
                    case item.status of
                        Pending ->
                            action c.onStart (pick "Start" "Start") ++ action c.onRemove (pick "Remove" "Fjern")

                        Transferring _ ->
                            action c.onCancel (pick "Cancel" "Avbryt")

                        Failed problem ->
                            (if Remote.isRetryable problem then
                                action c.onRetry (pick "Retry" "Prøv igjen")

                             else
                                []
                            )
                                ++ action c.onRemove (pick "Remove" "Fjern")

                        Cancelled ->
                            action c.onRetry (pick "Retry" "Prøv igjen") ++ action c.onRemove (pick "Remove" "Fjern")

                        Completed ->
                            action c.onRemove (pick "Remove" "Fjern")
            in
            ( if ambiguousIds then
                "duplicate-row-" ++ String.fromInt index

              else
                Ids.toKey data.ids item.id
            , Html.li [ Internal.cls [ "klar-upload-queue__item" ] ]
                [ Html.div [ Internal.cls [ "klar-upload-queue__file" ] ]
                    [ Icon.view Icon.file
                    , Html.div [ Internal.cls [ "klar-upload-queue__description" ] ]
                        [ Html.strong [ Internal.cls [ "klar-upload-queue__name" ] ] [ Html.text item.file.name ]
                        , Html.span [ Internal.cls [ "klar-upload-queue__meta" ] ]
                            [ Html.text
                                (Format.bytes c.locale item.file.size
                                    ++ (if item.file.mime == "" then
                                            ""

                                        else
                                            " · " ++ item.file.mime
                                       )
                                )
                            ]
                        ]
                    ]
                , viewStatus c.locale item.file.name item.status
                , Html.div [ Internal.cls [ "klar-upload-queue__actions" ] ] actions
                ]
            )
    in
    Html.section [ Attr.id state.id, Attr.tabindex -1, Attr.attribute "aria-label" data.label, Internal.cls [ "klar-upload-queue" ] ]
        [ FileDrop.view (Picker (policyOf c) >> toMsg)
            ([ FileDrop.label (pick "Add files" "Legg til filer"), FileDrop.multiple, FileDrop.accept c.accept, FileDrop.disabled c.disabled, FileDrop.locale c.locale ]
                ++ List.filterMap identity [ Maybe.map FileDrop.maxSize c.maxSize, Maybe.map FileDrop.maxFiles c.maxFiles ]
            )
            state.picker
        , Html.div [ Internal.cls [ "klar-upload-queue__staging-actions" ] ]
            [ Button.view [ Button.primary, Button.small, Button.disabled (not (canAdd attributes staging)), Button.onClick (data.onAdd actualFiles) ] (pick "Add files to queue" "Legg filer i køen")
            , if hasStaging then
                Button.view [ Button.small, Button.disabled c.disabled, Button.onClick (toMsg ClearStaging) ] (pick "Clear selection" "Tøm utvalget")

              else
                Html.text ""
            ]
        , if policyChanged then
            Html.p [ Internal.cls [ "klar-upload-queue__invalid" ], Attr.attribute "role" "alert" ]
                [ Html.text (pick "File rules changed. Clear the selection and choose files again before adding them." "Filreglene er endret. Tøm utvalget og velg filene på nytt før du legger dem til.") ]

          else
            Html.text ""
        , Html.div [ Internal.cls [ "klar-upload-queue__bar" ] ]
            [ Html.span [ Attr.attribute "role" "status" ] [ Html.text summary ]
            , case c.onStartAll of
                Just handler ->
                    Button.view [ Button.small, Button.disabled (c.disabled || ambiguousIds || List.isEmpty pendingIds), Button.onClick (handler pendingIds) ] (pick "Start pending files" "Start ventende filer")

                Nothing ->
                    Html.text ""
            ]
        , if ambiguousIds then
            Html.p [ Internal.cls [ "klar-upload-queue__invalid" ], Attr.attribute "role" "alert" ]
                [ Html.text (pick "Duplicate upload ids: transfer actions are unavailable. Every upload needs a unique id." "Dupliserte opplastings-ID-er: overføringshandlinger er utilgjengelige. Hver opplasting må ha en unik ID.") ]

          else
            Html.text ""
        , if List.isEmpty data.uploads then
            Html.p [ Internal.cls [ "klar-upload-queue__empty" ], Attr.attribute "role" "status" ] [ Html.text (pick "No files in the queue" "Ingen filer i køen") ]

          else
            Keyed.ul [ Internal.cls [ "klar-upload-queue__list" ], Attr.attribute "aria-label" (pick "Transfer queue" "Overføringskø") ] (List.indexedMap row data.uploads)
        ]


viewStatus : Locale -> String -> Status -> Html msg
viewStatus lang fileName status =
    let
        pick en nb =
            Locale.pick lang { en = en, nb = nb }

        text sentence =
            Html.span [ Internal.cls [ "klar-upload-queue__status" ] ] [ Html.text sentence ]
    in
    case status of
        Pending ->
            text (pick "Waiting to start" "Venter på start")

        Completed ->
            Html.span [ Internal.cls [ "klar-upload-queue__status", "klar-upload-queue__status--complete" ] ] [ Icon.view Icon.check, Html.text (pick "Completed" "Fullført") ]

        Cancelled ->
            text (pick "Cancelled" "Avbrutt")

        Failed problem ->
            Html.div [ Internal.cls [ "klar-upload-queue__status", "klar-upload-queue__status--failed" ], Attr.attribute "role" "alert" ]
                [ Html.strong [] [ Html.text (pick "Failed: " "Feilet: " ++ Remote.title lang problem) ]
                , Html.span [] [ Html.text (Remote.detail lang problem |> Maybe.withDefault "") ]
                ]

        Transferring report ->
            let
                invalid =
                    report.sent < 0 || Maybe.map (\total -> total < 0 || report.sent > total) report.total == Just True

                exact =
                    Format.int lang report.sent ++ (report.total |> Maybe.map (\total -> pick " of " " av " ++ Format.int lang total) |> Maybe.withDefault "") ++ pick " bytes sent" " byte sendt"

                waiting =
                    report.total == Just report.sent

                label =
                    if waiting then
                        pick "Waiting for confirmation" "Venter på bekreftelse"

                    else
                        pick "Transferring" "Overfører"

                determinate =
                    report.total
                        |> Maybe.andThen
                            (\total ->
                                if total > 0 && not invalid then
                                    Just total

                                else
                                    Nothing
                            )
            in
            Html.div [ Internal.cls [ "klar-upload-queue__transfer" ], Internal.attrIf invalid (Attr.attribute "role" "alert") ]
                [ Html.strong []
                    [ Html.text
                        (if invalid then
                            pick "Invalid progress report" "Ugyldig fremdriftsrapport"

                         else
                            label
                        )
                    ]
                , if invalid then
                    Html.text ""

                  else
                    Html.progress
                        ([ Internal.cls [ "klar-upload-queue__progress" ]
                         , Attr.attribute "aria-label" (pick "Bytes sent: " "Byte sendt: " ++ fileName)
                         , Attr.attribute "aria-valuetext" exact
                         ]
                            ++ (case determinate of
                                    Just total ->
                                        [ Attr.value (String.fromInt report.sent), Attr.max (String.fromInt total), Attr.attribute "aria-valuenow" (String.fromInt report.sent), Attr.attribute "aria-valuemin" "0", Attr.attribute "aria-valuemax" (String.fromInt total) ]

                                    Nothing ->
                                        []
                               )
                        )
                        []
                , Html.span [ Internal.cls [ "klar-upload-queue__meta" ] ] [ Html.text exact ]
                ]
