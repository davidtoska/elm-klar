# Klar.UploadQueue

A local file-transfer workbench: validated file staging, an explicit add action, and an application-controlled queue with exact byte progress.

Import: `import Klar.UploadQueue as UploadQueue` | Group: Files and media

Types: `Msg`, `State`, `Status`, `Upload`, `Attribute`, `FileInfo`

## Signatures

```elm
view :
    (Msg -> msg)
    -> List (Attribute id msg)
    -> { label : String, ids : Ids.Ids id, uploads : List (Upload id), onAdd : List File.File -> msg }
    -> State
    -> Html msg

-- Staging
type State  -- opaque: no constructors are exposed
type Msg  -- opaque: no constructors are exposed
init : String -> State
update : Msg -> State -> ( State, Cmd Msg )
files : State -> List FileInfo
rawFiles : State -> List File.File
rejected : State -> List ( FileInfo, FileDrop.Problem )
canAdd : List (Attribute id msg) -> State -> Bool
clear : State -> State

-- Queue entries
type Upload id  -- opaque: no constructors are exposed
type alias FileInfo = FileDrop.FileInfo
upload : { id : id, file : FileInfo } -> Upload id
withStatus : Status -> Upload id -> Upload id

-- Transfer states
type Status  -- opaque: no constructors are exposed
pending : Status
transferring : { sent : Int, total : Maybe Int } -> Status
completed : Status
failed : Remote.Problem -> Status
cancelled : Status

-- Attributes
type Attribute id msg  -- opaque: no constructors are exposed
accept : List String -> Attribute id msg
maxSize : Int -> Attribute id msg
maxFiles : Int -> Attribute id msg
disabled : Bool -> Attribute id msg
onStart : (id -> msg) -> Attribute id msg
onStartAll : (List id -> msg) -> Attribute id msg
onRetry : (id -> msg) -> Attribute id msg
onCancel : (id -> msg) -> Attribute id msg
onRemove : (id -> msg) -> Attribute id msg
locale : Locale.Locale -> Attribute id msg
```

## Documentation

A local file-transfer workbench: validated file staging, an explicit add
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

### `view`

```elm
view :
    (Msg -> msg)
    -> List (Attribute id msg)
    -> { label : String, ids : Ids.Ids id, uploads : List (Upload id), onAdd : List File.File -> msg }
    -> State
    -> Html msg
```

Draws validated staging and the controlled queue. `label` names the region;
`ids` writes unique application ids; `onAdd` receives actual accepted files only
after an explicit click. It does not also clear staging or start a request.

## Staging

### `State`

```elm
type State  -- opaque: no constructors are exposed
```

The file chooser's local state. Queue entries and source files are application data.

### `Msg`

```elm
type Msg  -- opaque: no constructors are exposed
```

File-staging interactions. Route them through `update`.

### `init`

```elm
init : String -> State
```

Creates empty staging. The string is a DOM id unique on the page and the
stable queue focus target; the file chooser uses this id with `-choose` appended.

### `update`

```elm
update : Msg -> State -> ( State, Cmd Msg )
```

Updates staging and keeps file-picker focus after removing or clearing files.
Transfer status and requests remain in your application's update.

### `files`

```elm
files : State -> List FileInfo
```

Metadata of accepted staged files, in selection order. Rejected files are excluded.

### `rawFiles`

```elm
rawFiles : State -> List File.File
```

Actual accepted browser files, without reading them. Only these are eligible
for the explicit add-to-queue action.

### `rejected`

```elm
rejected : State -> List ( FileInfo, FileDrop.Problem )
```

Every rejected staged file and its `Klar.FileDrop.Problem`, in selection order.

### `canAdd`

```elm
canAdd : List (Attribute id msg) -> State -> Bool
```

Whether staging can be added under the current rules: actual browser files
exist, no rejected selections remain, the original policy still matches and the
component is enabled. Use this alongside `rawFiles` for a custom submit action.

### `clear`

```elm
clear : State -> State
```

Clears only staging; it never removes queued transfers or moves focus. Call
after copying `rawFiles` to your model. The view's clear action also restores focus.

## Queue entries

### `Upload`

```elm
type Upload id  -- opaque: no constructors are exposed
```

One application-identified transfer, with immutable file metadata and a status.

### `FileInfo`

```elm
type alias FileInfo = FileDrop.FileInfo
```

The file's name, byte size and MIME type. This is metadata, not a browser file.

### `upload`

```elm
upload : { id : id, file : FileInfo } -> Upload id
```

Creates a pending transfer from an application id and file metadata. Keep
its browser `File` separately in your own model.

### `withStatus`

```elm
withStatus : Status -> Upload id -> Upload id
```

Replaces a transfer's status after your application receives new information.
The component does not start, retry, finish or cancel a transfer by itself.

## Transfer states

### `Status`

```elm
type Status  -- opaque: no constructors are exposed
```

A transfer's explicit state. Use the constructors below; the set can grow
without adding public union constructors.

### `pending`

```elm
pending : Status
```

Waiting for an explicit start action. This is a new upload's default state.

### `transferring`

```elm
transferring : { sent : Int, total : Maybe Int } -> Status
```

Bytes sent and optional total bytes, supplied by your transport. Unknown or
zero totals are indeterminate; inconsistent reports stay visibly invalid. Even a
fully sent transfer waits for `completed` before it is called complete.

### `completed`

```elm
completed : Status
```

The server has confirmed completion. No transfer actions remain except removal.

### `failed`

```elm
failed : Remote.Problem -> Status
```

A transfer failed. Retry appears only if an `onRetry` callback is supplied
and `Remote.isRetryable` says trying again can help.

### `cancelled`

```elm
cancelled : Status
```

Cancellation was confirmed by the application. An explicit retry is available
when supplied; a cancel click itself does not manufacture this state.

## Attributes

### `Attribute`

```elm
type Attribute id msg  -- opaque: no constructors are exposed
```

Optional staging rules and transfer actions. Later attributes win.

### `accept`

```elm
accept : List String -> Attribute id msg
```

Allowed extensions (`.pdf`), MIME types or groups (`image/*`) for staging.
Defaults to all file types. Native selection and drops use the same rules.

### `maxSize`

```elm
maxSize : Int -> Attribute id msg
```

Maximum staged file size in bytes, inclusive. No limit by default. A negative
limit accepts no files; it is never silently converted into an unlimited value.

### `maxFiles`

```elm
maxFiles : Int -> Attribute id msg
```

Maximum accepted files in one staged batch, not the length of queue history.
No limit by default. A limit of one uses FileDrop's replace-on-next-choice mode.

### `disabled`

```elm
disabled : Bool -> Attribute id msg
```

Disables file selection and every action while `True`. Statuses stay visible.
Defaults to `False`.

### `onStart`

```elm
onStart : (id -> msg) -> Attribute id msg
```

Adds a start action to pending transfers. The callback receives the application id.

### `onStartAll`

```elm
onStartAll : (List id -> msg) -> Attribute id msg
```

Adds a bulk start action sending only pending ids in queue order. Disabled
when none are pending; retries never join this action.

### `onRetry`

```elm
onRetry : (id -> msg) -> Attribute id msg
```

Adds retry to retryable failures and confirmed cancellations. Nothing retries
automatically, and retrying sends only the application's upload id.

### `onCancel`

```elm
onCancel : (id -> msg) -> Attribute id msg
```

Adds a cancel request to active transfers. Keep the transfer active until
your transport confirms cancellation or completion.

### `onRemove`

```elm
onRemove : (id -> msg) -> Attribute id msg
```

Adds removal to pending and terminal transfers. Active transfers must be
cancelled before removal, so no running request is silently forgotten.

### `locale`

```elm
locale : Locale.Locale -> Attribute id msg
```

Built-in text and number language. Defaults to English.
