# Klar.FileDrop

Choose files by dropping them on a zone or with a "Choose files" button.

Import: `import Klar.FileDrop as FileDrop` | Group: Inputs

Types: `Msg`, `State`, `Problem`, `Attribute`, `FileInfo`

## Signatures

```elm
-- View
type Attribute msg  -- opaque: no constructors are exposed
view : (Msg -> msg) -> List (Attribute msg) -> State -> Html msg

-- State
type State  -- opaque: no constructors are exposed
type Msg  -- opaque: no constructors are exposed
init : String -> State
update : Msg -> State -> ( State, Cmd Msg )

-- The chosen files
type alias FileInfo = { name : String, size : Int, mime : String }
type Problem = WrongType | TooLarge | TooMany | Duplicate
files : State -> List FileInfo
rawFiles : State -> List File.File
rejected : State -> List ( FileInfo, Problem )
hasProblems : State -> Bool
isTouched : State -> Bool

-- Changing the files from the application
setFiles : List FileInfo -> State -> State
clear : State -> State

-- Rules
accept : List String -> Attribute msg
maxSize : Int -> Attribute msg
maxFiles : Int -> Attribute msg
multiple : Attribute msg

-- Label, hint and error
label : String -> Attribute msg
labelHidden : Attribute msg
hint : String -> Attribute msg
error : String -> Attribute msg
errorMaybe : Maybe String -> Attribute msg
required : Attribute msg
optionalText : String -> Attribute msg

-- Appearance and behavior
compact : Attribute msg
disabled : Bool -> Attribute msg

-- Language
locale : Locale.Locale -> Attribute msg
```

## Documentation

Choose files by dropping them on a zone or with a "Choose files" button.

Use when: a form where the choice of files matters and the application only needs their names, sizes and types.
Do not use when: you want the library to upload or read the file (it hands over the `File`; the request is yours).
Quick path: `init`, `update`, `view`, `files`, `rawFiles`

    import Klar.FileDrop as FileDrop

    type alias Model =
        { attachments : FileDrop.State }

    init : Model
    init =
        { attachments = FileDrop.init "invoice-attachments" }

    -- update
    AttachmentsMsg inner ->
        let
            ( attachments, cmd ) =
                FileDrop.update inner model.attachments
        in
        ( { model | attachments = attachments }, Cmd.map AttachmentsMsg cmd )

    -- view
    FileDrop.view AttachmentsMsg
        [ FileDrop.label "Attachments"
        , FileDrop.accept [ ".pdf", "image/*" ]
        , FileDrop.maxSize 5000000
        , FileDrop.maxFiles 3
        ]
        model.attachments

    -- read them
    FileDrop.files model.attachments -- List FileInfo, only the accepted ones

The `String` given to `init` is the DOM id of the (hidden) file input, so there
is no `id` attribute.

**Reading and uploading are yours.** The library never knows HTTP, so it
does not send the file. It gives you the browser's own `File` values (from
[elm/file](https://package.elm-lang.org/packages/elm/file/latest/)) with
`rawFiles`, and you read them (`File.toString`, `File.toBytes`) or send them in
your request (`Http.filePart`, `Http.fileBody`). `files` is the plain
`name`, `size` and `mime` of the same files, for showing them, checking them and
keeping the list in a form.

    -- the accepted files, ready for the request
    FileDrop.rawFiles model.attachments -- List File

A file you put in with `setFiles` (an attachment the server already has) is in
`files` but has no `File`, so `rawFiles` can be shorter: it is the files the
user chose in this session, which are the ones to upload.

Every file is checked against `accept` (extensions like `.pdf`, types like
`application/pdf` and groups like `image/*`), `maxSize` (bytes), `maxFiles` and
duplicates (same name and size). Files that fail stay in the list with their
message and a remove button, and are left out of `files`; `rejected` and
`hasProblems` tell the application about them. The result stays with the file:
when the user removes another file, only a file that was refused as `TooMany` or
`Duplicate` is checked again, since there may be room now. Without `multiple`
(and with `maxFiles 1`) a new choice replaces the old one.

The rules are written out as a hint (or your own `hint`) between the label and
the drop zone, so people read what is allowed before they choose: with the
example above "Allowed types: PDF, images · Max 5.0 MB per file · Up to 3 files".

**Keyboard and accessibility.** The button ("Choose files", or "Choose file"
without `multiple`) is reachable with Tab and opens the file dialog with Enter
or Space; each file has a remove button, and the focus returns to the file input
when one is removed. The list of files is labelled "Selected files", and the
message of a refused file is announced when it appears. The zone lights up only
for files being dragged over it, not for dragged text.

**Files dropped elsewhere.** A file dropped outside a drop zone is opened by the
browser, which replaces the whole application. [Klar.AppShell](Klar.AppShell.md)
cancels such drops with `onStrayDrop`.

`label`, `labelHidden`, `hint`, `error`, `errorMaybe`, `required` and
`optionalText` are the common field attributes. They come with the field
wrapper ([Klar.Field](Klar.Field.md)) that most Klar inputs are built on, so they
mean the same in all of them: the wrapper draws the label, the required marker
and the error message around the field and connects them for screen readers
(`for`, `aria-describedby`, `aria-invalid`, `aria-required`). Here the hint is
drawn above the drop zone instead of below it. The drop zone is always inside the
wrapper, also when there is no `label` or `error` to draw, so it stays where it
is when the application shows an error.

The built-in texts (the button, the drop zone, the rules and the messages) and
the file sizes follow `locale`.

## View

### `Attribute`

```elm
type Attribute msg  -- opaque: no constructors are exposed
```

A setting of a file field. Make them with the functions below and pass a
list to `view`; later attributes win over earlier ones.

### `view`

```elm
view : (Msg -> msg) -> List (Attribute msg) -> State -> Html msg
```

A file field: a drop zone with a button, and below it the list of chosen
files with their problems. The first argument wraps the field's own messages in
one of yours, and the state comes last.

    FileDrop.view AttachmentsMsg
        [ FileDrop.label "Photo"
        , FileDrop.accept [ "image/*" ]
        , FileDrop.compact
        ]
        model.attachments

## State

### `State`

```elm
type State  -- opaque: no constructors are exposed
```

The state of a file field: the files the user has chosen, with the verdict
on each, and whether files are being dragged over the zone. Make one with
`init`, keep it in your model and give it to `view` and `update`.

### `Msg`

```elm
type Msg  -- opaque: no constructors are exposed
```

The messages a file field sends: choosing or dropping files, removing one and
dragging over the zone. `view` wraps them with the function you give it; hand
them to `update` when they come back.

### `init`

```elm
init : String -> State
```

A field without files. The `String` is the DOM id of the (hidden) file
input; it must be unique on the page, because the label, hint and error point
at it.

### `update`

```elm
update : Msg -> State -> ( State, Cmd Msg )
```

Moves the field on after one of its messages. The `Cmd` moves the focus to
the file input after a file was removed, so pass it on with `Cmd.map`.

## The chosen files

### `FileInfo`

```elm
type alias FileInfo = { name : String, size : Int, mime : String }
```

What the browser tells about a chosen file: its `name`, its `size` in bytes
and its `mime` type (`"application/pdf"`), which is empty when the browser does
not know. This is all the application gets; the contents of the file are not
read.

### `Problem`

```elm
type Problem = WrongType | TooLarge | TooMany | Duplicate
```

Why a file was not accepted:

  - `WrongType`: it does not match `accept`
  - `TooLarge`: it is bigger than `maxSize`
  - `TooMany`: there are already `maxFiles` accepted files
  - `Duplicate`: a file with the same name and size is already in the list

A file with several problems gets the first of them in the order `Duplicate`,
`WrongType`, `TooLarge`, `TooMany`. The result stays with the file. Only
`TooMany` and `Duplicate` depend on the other files, so only they are checked
again when the user removes a file.

### `files`

```elm
files : State -> List FileInfo
```

The accepted files, in the order they were added. Files that failed a rule
are not in this list; see `rejected`.

### `rawFiles`

```elm
rawFiles : State -> List File.File
```

The browser's `File` values of the accepted files, in the order they were
added, for reading them or sending them in a request. A file put in with
`setFiles` has none, so this list is the files the user chose here and can be
shorter than `files`. Nothing is read or sent by this library.

    FileDrop.rawFiles model.attachments
        |> List.map (Http.filePart "attachment")
        |> Http.multipartBody

### `rejected`

```elm
rejected : State -> List ( FileInfo, Problem )
```

The files that were refused, in the order they were added, each with the
reason. They stay in the list on the screen, with a message and a remove button,
until the user removes them.

### `hasProblems`

```elm
hasProblems : State -> Bool
```

`True` when at least one file was refused. Use it, for example, to keep a
form from being submitted until the refused files are removed.

### `isTouched`

```elm
isTouched : State -> Bool
```

`True` once the user has chosen or dropped files, or removed one. Use it to
show errors only after the first visit.

## Changing the files from the application

### `setFiles`

```elm
setFiles : List FileInfo -> State -> State
```

Shows these files without checking them against the rules, for example
attachments the server already has, and forgets that the user has been in the
field (`isTouched` is `False`). They stay accepted: removing another file does
not check them or refuse them later. They do count towards `maxFiles`, and a new
file that repeats one of them is refused as `Duplicate`.

### `clear`

```elm
clear : State -> State
```

Removes all files, accepted and refused, and forgets that the user has been
in the field (`isTouched` is `False` again).

## Rules

### `accept`

```elm
accept : List String -> Attribute msg
```

The kinds of file that are allowed: extensions (`".pdf"`), media types
(`"application/pdf"`) and groups (`"image/*"`). A file is accepted when it
matches any of them, without regard to case. The list also goes to the browser's
file dialog, and dropped files are checked too. Default: every file is accepted.

    FileDrop.accept [ ".pdf", ".docx", "image/*" ]

### `maxSize`

```elm
maxSize : Int -> Attribute msg
```

The largest size of a file, in bytes (`5000000` is 5 MB). A larger file is
refused as `TooLarge`; a file of exactly this size is accepted. Default: no
limit.

### `maxFiles`

```elm
maxFiles : Int -> Attribute msg
```

The most files that can be accepted. A limit above 1 also allows choosing
several files at once (it implies `multiple`). Files over the limit are refused
as `TooMany`, and are accepted again if the user removes other files.

`maxFiles 1` is the single-file field, whatever else is set: the file input does
not take several files, "Choose file" is its button, and choosing or dropping a
file replaces the one that is there. The rules text then leaves out "Up to 1
files". Default: no limit.

### `multiple`

```elm
multiple : Attribute msg
```

Allows more than one file. Without it a new choice replaces the old one, and
when several files are dropped at once only the first is used. `maxFiles 1` takes
priority: it keeps the field a single-file field.

## Label, hint and error

### `label`

```elm
label : String -> Attribute msg
```

The label shown above the field. It is connected to the file input, so
clicking it focuses the input and screen readers read it as the name of the
input. Give every field a label, or hide it with `labelHidden`.

### `labelHidden`

```elm
labelHidden : Attribute msg
```

Hides the `label` visually but keeps it for screen readers. Use it when the
surroundings already show what the field is for.

### `hint`

```elm
hint : String -> Attribute msg
```

Help text shown between the label and the drop zone, so that people read
what is allowed before they choose. Screen readers read it together with the
label (`aria-describedby`). Without a `hint`, the text is built from the rules
(`accept`, `maxSize`, `maxFiles`), for example "Allowed types: PDF · Max 5.0 MB
per file"; a `hint` replaces it.

### `error`

```elm
error : String -> Attribute msg
```

Shows an error message under the field and marks the field invalid (red
border on the drop zone, `aria-invalid`). Screen readers announce the message
when it appears. To show an error only sometimes, use `errorMaybe`. The
messages for refused files are shown on the files themselves; this one is for
what the application knows, such as "Attach at least one file".

### `errorMaybe`

```elm
errorMaybe : Maybe String -> Attribute msg
```

Like `error`, but takes a `Maybe`: `Just message` shows the message and
`Nothing` shows no error. It fits the result of a validator.

### `required`

```elm
required : Attribute msg
```

Marks the field as required: an asterisk after the label and
`aria-required` on the file input. This does not validate anything; check
`files` for an empty list yourself and show an `error`.

### `optionalText`

```elm
optionalText : String -> Attribute msg
```

Text such as `"(optional)"` shown after the label of a field that is not
`required`. By default nothing is shown.

## Appearance and behavior

### `compact`

```elm
compact : Attribute msg
```

A one-line drop zone for tight forms, instead of the taller default.

### `disabled`

```elm
disabled : Bool -> Attribute msg
```

While `True` the field is dimmed and the button and the drop zone do nothing.
Default `False`.

## Language

### `locale`

```elm
locale : Locale.Locale -> Attribute msg
```

The language of the built-in text: the button and the drop zone ("Choose
files", "Drag and drop files here", "or"), the text built from the rules, the
messages of refused files ("File type not allowed", "File is too large (max
5.0 MB)", "Too many files (max 3)", "File already added"), the names of the
remove buttons and of the list ("Selected files"), and the format of the file
sizes. Default `Locale.default`, which is English. Texts you pass in yourself are
shown as they are.
