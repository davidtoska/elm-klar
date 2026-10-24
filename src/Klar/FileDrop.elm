module Klar.FileDrop exposing
    ( view, Attribute
    , State, Msg, init, update
    , FileInfo, values, rawFiles, chosen, rejected, hasProblems, isTouched
    , Problem, problemText, isWrongType, isTooLarge, isTooMany, isDuplicate
    , setValues, clear
    , accept, maxSize, maxFiles, multiple
    , label, labelHidden, hint, error, errorMaybe, required, optionalText
    , compact, disabled
    , locale
    )

{-| Choose files by dropping them on a zone or with a "Choose files" button.

Use when: a form where the choice of files matters and the application only needs their names, sizes and types.
Do not use when: you want the library to upload or read the file (it hands over the `File`; the request is yours).
Quick path: `init`, `update`, `view`, `values`, `rawFiles`

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
    FileDrop.values model.attachments -- List FileInfo, only the accepted ones

The `String` given to `init` is the DOM id of the (hidden) file input, so there
is no `id` attribute.

**Reading and uploading are yours.** The library never knows HTTP, so it
does not send the file. It gives you the browser's own `File` values (from
[elm/file](https://package.elm-lang.org/packages/elm/file/latest/)) with
`rawFiles`, and you read them (`File.toString`, `File.toBytes`) or send them in
your request (`Http.filePart`, `Http.fileBody`). `values` is the plain
`name`, `size` and `mime` of the same files, for showing them, checking them and
keeping the list in a form.

    -- the accepted files, ready for one request
    FileDrop.rawFiles model.attachments -- List File

    -- or one request per file, each with what to show about it
    FileDrop.chosen model.attachments -- List { info : FileInfo, file : File }

A file you put in with `setValues` (an attachment the server already has) is in
`values` but has no `File`, so `rawFiles` and `chosen` can be shorter: they are
the files the user chose in this session, which are the ones to upload.

Every file is checked against `accept` (extensions like `.pdf`, types like
`application/pdf` and groups like `image/*`), `maxSize` (bytes), `maxFiles` and
duplicates (same name and size). Files that fail stay in the list with their
message and a remove button, and are left out of `values`; `rejected` and
`hasProblems` tell the application about them. The result stays with the file:
when the user removes another file, only a file that was refused for being one
too many or a duplicate is checked again, since there may be room now. Without
`multiple` (and with `maxFiles 1`) a new choice replaces the old one when it is
accepted: a refused file does not throw the good one away, it is shown next to it.

The rules are written out as a hint (or your own `hint`) between the label and
the drop zone, so people read what is allowed before they choose: with the
example above "Allowed types: PDF, images · Max 5.0 MB per file · Up to 3 files".

**Keyboard and accessibility.** The button ("Choose files", or "Choose file"
without `multiple`) is reachable with Tab and opens the file dialog with Enter
or Space; files can also be pasted (a screenshot with Ctrl+V) while the focus is
in the zone. Each file has a remove button; when one is removed, the focus goes to
the remove button of the next file (or the one before), and to the file input
when the list is empty. The list of files is labelled "Selected files". What a
choice did is announced once, politely ("2 files added, 1 refused"), not once per
file. The zone lights up only for files being dragged over it, not for dragged
text.

**Files dropped elsewhere.** A file dropped outside a drop zone is opened by the
browser, which replaces the whole application. [Klar.AppShell](Klar-AppShell)
cancels such drops with `onStrayDrop`. A file dropped on a `disabled` zone is
cancelled by the zone itself, and nothing is added.

`label`, `labelHidden`, `hint`, `error`, `errorMaybe`, `required` and
`optionalText` are the common field attributes. They come with the field
wrapper ([Klar.Field](Klar-Field)) that most Klar inputs are built on, so they
mean the same in all of them: the wrapper draws the label, the required marker
and the error message around the field and connects them for screen readers
(`for`, `aria-describedby`, `aria-invalid`, `aria-required`). Here the hint is
drawn above the drop zone instead of below it. The drop zone is always inside the
wrapper, also when there is no `label` or `error` to draw, so it stays where it
is when the application shows an error.

The built-in texts (the button, the drop zone, the rules and the messages) and
the file sizes follow `locale`.


# View

@docs view, Attribute


# State

@docs State, Msg, init, update


# The chosen files

@docs FileInfo, values, rawFiles, chosen, rejected, hasProblems, isTouched


# Why a file was refused

@docs Problem, problemText, isWrongType, isTooLarge, isTooMany, isDuplicate


# Changing the files from the application

@docs setValues, clear


# Rules

@docs accept, maxSize, maxFiles, multiple


# Label, hint and error

@docs label, labelHidden, hint, error, errorMaybe, required, optionalText


# Appearance and behavior

@docs compact, disabled


# Language

@docs locale

-}

import File exposing (File)
import Html exposing (Html)
import Html.Attributes as Attr
import Html.Events as Events
import Html.Keyed as Keyed
import Json.Decode as Decode exposing (Decoder)
import Klar.Button as Button
import Klar.Field as Field
import Klar.Format as Format
import Klar.Icon as Icon exposing (Icon)
import Klar.Internal as Internal
import Klar.Locale as Locale exposing (Locale)



-- FILES


{-| What the browser tells about a chosen file: its `name`, its `size` in bytes
and its `mime` type (`"application/pdf"`), which is empty when the browser does
not know. This is all the application gets; the contents of the file are not
read.
-}
type alias FileInfo =
    { name : String
    , size : Int
    , mime : String
    }


{-| Why a file was not accepted: its type does not match `accept`
(`isWrongType`), it is bigger than `maxSize` (`isTooLarge`), there are already
`maxFiles` accepted files (`isTooMany`), or a file with the same name and size is
already in the list (`isDuplicate`). `problemText` says it in words, with the
limit that refused it.

A file with several problems gets the first of them in the order duplicate, type,
size, number. The result stays with the file. Only the number and the duplicate
depend on the other files, so only they are checked again when the user removes a
file. It is opaque so that a new reason to refuse a file is not a breaking change.

-}
type Problem
    = WrongType
    | TooLarge Int
    | TooMany Int
    | Duplicate


{-| `True` for a file whose type does not match `accept`.
-}
isWrongType : Problem -> Bool
isWrongType problem =
    problem == WrongType


{-| `True` for a file that is bigger than `maxSize`.
-}
isTooLarge : Problem -> Bool
isTooLarge problem =
    case problem of
        TooLarge _ ->
            True

        _ ->
            False


{-| `True` for a file that came when there were already `maxFiles` accepted
files. It is accepted again when the user removes another file.
-}
isTooMany : Problem -> Bool
isTooMany problem =
    case problem of
        TooMany _ ->
            True

        _ ->
            False


{-| `True` for a file with the same name and size as one already in the list.
-}
isDuplicate : Problem -> Bool
isDuplicate problem =
    problem == Duplicate


{-| The problem in words, in the language, as the field shows it under the file:
"File type not allowed", "File is too large (max 5.0 MB)", "Too many files (max
3)", "File already added". For an error summary or a log of your own.

    FileDrop.rejected model.attachments
        |> List.map (\( file, problem ) -> file.name ++ ": " ++ FileDrop.problemText Locale.en problem)

-}
problemText : Locale -> Problem -> String
problemText lang problem =
    case problem of
        WrongType ->
            Locale.pick lang { nb = "Filtypen er ikke tillatt", en = "File type not allowed" }

        TooLarge bytes ->
            Locale.pick lang
                { nb = "Filen er for stor (maks " ++ Format.bytes lang bytes ++ ")"
                , en = "File is too large (max " ++ Format.bytes lang bytes ++ ")"
                }

        TooMany count ->
            Locale.pick lang
                { nb = "For mange filer (maks " ++ String.fromInt count ++ ")"
                , en = "Too many files (max " ++ String.fromInt count ++ ")"
                }

        Duplicate ->
            Locale.pick lang { nb = "Filen er allerede lagt til", en = "File already added" }


{-| A file in the list. The key is given when it is added and never changes, so
the row of a file stays the same element when others are removed.
-}
type alias Entry =
    { key : Int
    , file : FileInfo
    , raw : Maybe File
    , problem : Maybe Problem
    }


{-| What the last change did, for the announcement of screen readers.
-}
type Change
    = Unchanged
    | Added { accepted : Int, refused : List ( FileInfo, Problem ) }
    | Removed String



-- STATE


{-| The state of a file field: the files the user has chosen, with the verdict
on each, and whether files are being dragged over the zone. Make one with
`init`, keep it in your model and give it to `view` and `update`.
-}
type State
    = State Fields


type alias Fields =
    { id : String
    , entries : List Entry
    , nextKey : Int
    , dragging : Int
    , touched : Bool
    , change : Change
    }


{-| A field without files. The `String` is the DOM id of the (hidden) file
input; it must be unique on the page, because the label, hint and error point
at it.
-}
init : String -> State
init id =
    State { id = id, entries = [], nextKey = 0, dragging = 0, touched = False, change = Unchanged }


{-| The accepted files, in the order they were added. Files that failed a rule
are not in this list; see `rejected`.
-}
values : State -> List FileInfo
values (State state) =
    state.entries
        |> List.filter (\entry -> entry.problem == Nothing)
        |> List.map .file


{-| The browser's `File` values of the accepted files, in the order they were
added, for reading them or sending them in a request. A file put in with
`setValues` has none, so this list is the files the user chose here and can be
shorter than `values`. Nothing is read or sent by this library.

    FileDrop.rawFiles model.attachments
        |> List.map (Http.filePart "attachment")
        |> Http.multipartBody

-}
rawFiles : State -> List File
rawFiles (State state) =
    state.entries
        |> List.filter (\entry -> entry.problem == Nothing)
        |> List.filterMap .raw


{-| The accepted files the user chose in this session, each with its `File`, in
the order they were added: for an upload of one request per file that shows
which file it is about. The files put in with `setValues` are not in it, as they
have no `File`.

    FileDrop.chosen model.attachments
        |> List.map (\{ info, file } -> uploadAttachment info.name file)
        |> Cmd.batch

-}
chosen : State -> List { info : FileInfo, file : File }
chosen (State state) =
    state.entries
        |> List.filter (\entry -> entry.problem == Nothing)
        |> List.filterMap (\entry -> Maybe.map (\file -> { info = entry.file, file = file }) entry.raw)


{-| The files that were refused, in the order they were added, each with the
reason. They stay in the list on the screen, with a message and a remove button,
until the user removes them.
-}
rejected : State -> List ( FileInfo, Problem )
rejected (State state) =
    state.entries
        |> List.filterMap
            (\entry ->
                entry.problem |> Maybe.map (\problem -> ( entry.file, problem ))
            )


{-| `True` when at least one file was refused. Use it, for example, to keep a
form from being submitted until the refused files are removed.
-}
hasProblems : State -> Bool
hasProblems state =
    not (List.isEmpty (rejected state))


{-| Shows these files without checking them against the rules, for example
attachments the server already has, and forgets that the user has been in the
field (`isTouched` is `False`). They stay accepted: removing another file does
not check them or refuse them later. They do count towards `maxFiles`, and a new
file that repeats one of them is refused as `Duplicate`.
-}
setValues : List FileInfo -> State -> State
setValues list (State state) =
    State
        { state
            | entries = List.indexedMap (\index file -> { key = state.nextKey + index, file = file, raw = Nothing, problem = Nothing }) list
            , nextKey = state.nextKey + List.length list
            , dragging = 0
            , touched = False
            , change = Unchanged
        }


{-| Removes all files, accepted and refused, and forgets that the user has been
in the field (`isTouched` is `False` again).
-}
clear : State -> State
clear (State state) =
    State { state | entries = [], dragging = 0, touched = False, change = Unchanged }


{-| `True` once the user has chosen or dropped files, or removed one. Use it to
show errors only after the first visit.
-}
isTouched : State -> Bool
isTouched (State state) =
    state.touched



-- UPDATE


type alias Rules =
    { accept : List String
    , maxSize : Maybe Int
    , maxFiles : Maybe Int
    , multiple : Bool
    }


type alias Incoming =
    { info : FileInfo
    , raw : Maybe File
    }


{-| The messages a file field sends: choosing, dropping or pasting files,
removing one and dragging over the zone. `view` wraps them with the function you
give it; hand them to `update` when they come back.
-}
type Msg
    = Picked Rules (List Incoming)
    | Dropped Rules (List Incoming)
    | Remove Rules Int
    | DragEntered
    | DragLeft
    | DraggedOver
    | Noop


{-| Moves the field on after one of its messages. The `Cmd` moves the focus
after a file was removed (to the next remove button, or to the file input), so
pass it on with `Cmd.map`.
-}
update : Msg -> State -> ( State, Cmd Msg )
update msg (State state) =
    case msg of
        Picked rules incoming ->
            ( State (add rules incoming { state | touched = True }), Cmd.none )

        Dropped rules incoming ->
            ( State (add rules incoming { state | dragging = 0, touched = True }), Cmd.none )

        Remove rules key ->
            let
                ( before, after ) =
                    splitAt key state.entries

                -- the remove button is gone: the focus goes to the one of the
                -- next file, or the one before, or to "Choose files" (the file
                -- input) instead of being lost to the page
                next =
                    List.map (removeId state.id) (List.take 1 (List.drop 1 after) ++ List.take 1 (List.reverse before))
                        ++ [ state.id ]
            in
            case after of
                removed :: rest ->
                    ( State
                        { state
                            | entries = revalidate rules (before ++ rest)
                            , touched = True
                            , change = Removed removed.file.name
                        }
                    , Internal.focusFirst next Noop
                    )

                [] ->
                    ( State state, Cmd.none )

        DragEntered ->
            ( State { state | dragging = state.dragging + 1 }, Cmd.none )

        DragLeft ->
            ( State { state | dragging = Basics.max 0 (state.dragging - 1) }, Cmd.none )

        DraggedOver ->
            ( State { state | dragging = Basics.max 1 state.dragging }, Cmd.none )

        Noop ->
            ( State state, Cmd.none )


{-| The entries before the one with this key, and the rest from it on.
-}
splitAt : Int -> List Entry -> ( List Entry, List Entry )
splitAt key entries =
    let
        before =
            List.filter (\entry -> entry.key < key) entries
    in
    ( before, List.drop (List.length before) entries )


removeId : String -> Entry -> String
removeId id entry =
    id ++ "-remove-" ++ String.fromInt entry.key


add : Rules -> List Incoming -> Fields -> Fields
add rules incoming state =
    let
        entries =
            addFiles rules state.nextKey incoming state.entries

        new =
            List.filter (\entry -> entry.key >= state.nextKey) entries
    in
    { state
        | entries = entries
        , nextKey = state.nextKey + List.length incoming
        , change =
            Added
                { accepted = List.length (List.filter (\entry -> entry.problem == Nothing) new)
                , refused = List.filterMap (\entry -> Maybe.map (\problem -> ( entry.file, problem )) entry.problem) new
                }
    }


{-| The new files, each checked against the rules and the files before it. In a
single-file field the new file replaces the old ones when it is accepted; a
refused one is shown next to the accepted file instead, which stays.
-}
addFiles : Rules -> Int -> List Incoming -> List Entry -> List Entry
addFiles rules firstKey incoming existing =
    let
        entry index item entries =
            { key = firstKey + index, file = item.info, raw = item.raw, problem = check rules entries item.info }
    in
    if rules.multiple then
        List.foldl (\( index, item ) entries -> entries ++ [ entry index item entries ])
            existing
            (List.indexedMap Tuple.pair incoming)

    else
        case incoming of
            first :: _ ->
                let
                    alone =
                        entry 0 first []
                in
                if alone.problem == Nothing then
                    [ alone ]

                else
                    List.filter (\old -> old.problem == Nothing) existing ++ [ alone ]

            [] ->
                existing


check : Rules -> List Entry -> FileInfo -> Maybe Problem
check rules existing file =
    if List.any (\entry -> entry.file.name == file.name && entry.file.size == file.size) existing then
        Just Duplicate

    else if not (isAccepted rules.accept file) then
        Just WrongType

    else
        case rules.maxSize of
            Just bytes ->
                if file.size > bytes then
                    Just (TooLarge bytes)

                else
                    overLimit rules.maxFiles existing

            Nothing ->
                overLimit rules.maxFiles existing


overLimit : Maybe Int -> List Entry -> Maybe Problem
overLimit limit existing =
    case limit of
        Just count ->
            if List.length (List.filter (\entry -> entry.problem == Nothing) existing) >= count then
                Just (TooMany count)

            else
                Nothing

        Nothing ->
            Nothing


{-| After a removal, check again the files that were refused for being one too
many or a duplicate: there may be room now, or the file they repeated may be gone. The
result of every other file stays as it is. That includes the accepted ones: a
file that `setValues` added without a check must not be refused later, because
some other file was removed.
-}
revalidate : Rules -> List Entry -> List Entry
revalidate rules entries =
    List.foldl
        (\entry checked ->
            if Maybe.map (\problem -> isTooMany problem || isDuplicate problem) entry.problem == Just True then
                checked ++ [ { entry | problem = check rules checked entry.file } ]

            else
                checked ++ [ entry ]
        )
        []
        entries


isAccepted : List String -> FileInfo -> Bool
isAccepted patterns file =
    if List.isEmpty patterns then
        True

    else
        List.any (matchesPattern file) patterns


matchesPattern : FileInfo -> String -> Bool
matchesPattern file raw =
    let
        pattern =
            String.toLower (String.trim raw)

        name =
            String.toLower file.name

        mime =
            mimeOf file
    in
    if String.startsWith "." pattern then
        String.endsWith pattern name

    else if not (String.contains "/" pattern) then
        -- `pdf` without the point is an extension too
        String.endsWith ("." ++ pattern) name

    else if String.endsWith "/*" pattern then
        String.startsWith (String.dropRight 1 pattern) mime

    else
        pattern == mime


{-| The media type of a file: the one the browser gives, or, when it gives none
(a HEIC photo or an Outlook message on some systems), the one of its extension
for the common kinds, so that `image/*` and `application/pdf` still match.
-}
mimeOf : FileInfo -> String
mimeOf file =
    if String.trim file.mime /= "" then
        String.toLower file.mime

    else
        case List.reverse (String.split "." (String.toLower file.name)) of
            extension :: _ :: _ ->
                knownTypes
                    |> List.filter (\( ending, _ ) -> ending == extension)
                    |> List.head
                    |> Maybe.map Tuple.second
                    |> Maybe.withDefault ""

            _ ->
                ""


knownTypes : List ( String, String )
knownTypes =
    [ ( "jpg", "image/jpeg" )
    , ( "jpeg", "image/jpeg" )
    , ( "png", "image/png" )
    , ( "gif", "image/gif" )
    , ( "webp", "image/webp" )
    , ( "avif", "image/avif" )
    , ( "heic", "image/heic" )
    , ( "heif", "image/heif" )
    , ( "svg", "image/svg+xml" )
    , ( "tif", "image/tiff" )
    , ( "tiff", "image/tiff" )
    , ( "bmp", "image/bmp" )
    , ( "pdf", "application/pdf" )
    , ( "txt", "text/plain" )
    , ( "csv", "text/csv" )
    , ( "json", "application/json" )
    , ( "xml", "application/xml" )
    , ( "zip", "application/zip" )
    , ( "doc", "application/msword" )
    , ( "docx", "application/vnd.openxmlformats-officedocument.wordprocessingml.document" )
    , ( "xls", "application/vnd.ms-excel" )
    , ( "xlsx", "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet" )
    , ( "msg", "application/vnd.ms-outlook" )
    , ( "eml", "message/rfc822" )
    , ( "mp4", "video/mp4" )
    , ( "mov", "video/quicktime" )
    , ( "webm", "video/webm" )
    , ( "mp3", "audio/mpeg" )
    , ( "wav", "audio/wav" )
    , ( "m4a", "audio/mp4" )
    ]


{-| What goes to the file dialog of the browser: a bare word is an extension
there too.
-}
acceptValue : String -> String
acceptValue raw =
    let
        pattern =
            String.trim raw
    in
    if String.startsWith "." pattern || String.contains "/" pattern then
        pattern

    else
        "." ++ pattern


{-| The plain data of a file, and the `File` itself when the value is one (it is
in every browser; a value that is only a record of the three fields, such as a
test makes, has none).
-}
fileDecoder : Decoder Incoming
fileDecoder =
    Decode.map2 Incoming
        (Decode.map3 FileInfo
            (Decode.field "name" Decode.string)
            (Decode.field "size" Decode.int)
            (Decode.oneOf [ Decode.field "type" Decode.string, Decode.succeed "" ])
        )
        (Decode.oneOf [ File.decoder |> Decode.map Just, Decode.succeed Nothing ])



-- ATTRIBUTES


{-| A setting of a file field. Make them with the functions below and pass a
list to `view`; later attributes win over earlier ones.
-}
type Attribute msg
    = Attribute (Config -> Config)


type alias Config =
    { field : Field.Config
    , accept : List String
    , maxSize : Maybe Int
    , maxFiles : Maybe Int
    , multiple : Bool
    , compact : Bool
    , disabled : Bool
    , locale : Locale
    }


configure : List (Attribute msg) -> Config
configure attributes =
    List.foldl (\(Attribute change) config -> change config)
        { field = Field.empty
        , accept = []
        , maxSize = Nothing
        , maxFiles = Nothing
        , multiple = False
        , compact = False
        , disabled = False
        , locale = Locale.default
        }
        attributes


{-| Whether the field takes several files. `maxFiles 1` makes it a single-file
field, also when `multiple` is set: one file at most is a field that the next
choice replaces, not a list that refuses its second entry.
-}
isMultiple : Config -> Bool
isMultiple config =
    config.multiple && config.maxFiles /= Just 1


updateField : (Field.Config -> Field.Config) -> Attribute msg
updateField change =
    Attribute (\config -> { config | field = change config.field })


{-| The label shown above the field. It is connected to the file input, so
clicking it focuses the input and screen readers read it as the name of the
input. Give every field a label, or hide it with `labelHidden`.
-}
label : String -> Attribute msg
label value =
    updateField (Field.setLabel value)


{-| Hides the `label` visually but keeps it for screen readers. Use it when the
surroundings already show what the field is for.
-}
labelHidden : Attribute msg
labelHidden =
    updateField Field.setLabelHidden


{-| Help text shown between the label and the drop zone, so that people read
what is allowed before they choose. Screen readers read it together with the
label (`aria-describedby`). Without a `hint`, the text is built from the rules
(`accept`, `maxSize`, `maxFiles`), for example "Allowed types: PDF · Max 5.0 MB
per file"; a `hint` replaces it.
-}
hint : String -> Attribute msg
hint value =
    updateField (Field.setHint value)


{-| Shows an error message under the field and marks the field invalid (red
border on the drop zone, `aria-invalid`). Screen readers announce the message
when it appears. To show an error only sometimes, use `errorMaybe`. The
messages for refused files are shown on the files themselves; this one is for
what the application knows, such as "Attach at least one file".
-}
error : String -> Attribute msg
error value =
    updateField (Field.setError (Just value))


{-| Like `error`, but takes a `Maybe`: `Just message` shows the message and
`Nothing` shows no error. It fits the result of a validator.
-}
errorMaybe : Maybe String -> Attribute msg
errorMaybe maybe =
    updateField (Field.setError maybe)


{-| Marks the field as required: an asterisk after the label and
`aria-required` on the file input. This does not validate anything; check
`files` for an empty list yourself and show an `error`.
-}
required : Attribute msg
required =
    updateField (Field.setRequired True)


{-| Text such as `"(optional)"` shown after the label of a field that is not
`required`. By default nothing is shown.
-}
optionalText : String -> Attribute msg
optionalText value =
    updateField (Field.setOptionalText value)


{-| The kinds of file that are allowed: extensions (`".pdf"`), media types
(`"application/pdf"`) and groups (`"image/*"`). A file is accepted when it
matches any of them, without regard to case. The list also goes to the browser's
file dialog, and dropped files are checked too. Default: every file is accepted.

    FileDrop.accept [ ".pdf", ".docx", "image/*" ]

-}
accept : List String -> Attribute msg
accept patterns =
    Attribute (\config -> { config | accept = patterns })


{-| The largest size of a file, in bytes (`5000000` is 5 MB). A larger file is
refused as `TooLarge`; a file of exactly this size is accepted. Default: no
limit.
-}
maxSize : Int -> Attribute msg
maxSize bytes =
    Attribute (\config -> { config | maxSize = Just bytes })


{-| The most files that can be accepted. A limit above 1 also allows choosing
several files at once (it implies `multiple`). Files over the limit are refused
as `TooMany`, and are accepted again if the user removes other files.

`maxFiles 1` is the single-file field, whatever else is set: the file input does
not take several files, "Choose file" is its button, and choosing or dropping a
file replaces the one that is there. The rules text then leaves out "Up to 1
files". Default: no limit.

-}
maxFiles : Int -> Attribute msg
maxFiles count =
    Attribute (\config -> { config | maxFiles = Just count, multiple = True })


{-| Allows more than one file. Without it a new choice replaces the old one, and
when several files are dropped at once only the first is used. `maxFiles 1` takes
priority: it keeps the field a single-file field.
-}
multiple : Attribute msg
multiple =
    Attribute (\config -> { config | multiple = True })


{-| A one-line drop zone for tight forms, instead of the taller default.
-}
compact : Attribute msg
compact =
    Attribute (\config -> { config | compact = True })


{-| While `True` the field is dimmed and the button and the drop zone do nothing.
Default `False`.
-}
disabled : Bool -> Attribute msg
disabled value =
    Attribute (\config -> { config | disabled = value })


{-| The language of the built-in text: the button and the drop zone ("Choose
files", "Drag and drop files here", "or"), the text built from the rules, the
messages of refused files ("File type not allowed", "File is too large (max
5.0 MB)", "Too many files (max 3)", "File already added"), the names of the
remove buttons and of the list ("Selected files"), and the format of the file
sizes. Default `Locale.default`, which is English. Texts you pass in yourself are
shown as they are.
-}
locale : Locale -> Attribute msg
locale value =
    Attribute (\config -> { config | locale = value })



-- VIEW


{-| A file field: a drop zone with a button, and below it the list of chosen
files with their problems. The first argument wraps the field's own messages in
one of yours, and the state comes last.

    FileDrop.view AttachmentsMsg
        [ FileDrop.label "Photo"
        , FileDrop.accept [ "image/*" ]
        , FileDrop.compact
        ]
        model.attachments

-}
view : (Msg -> msg) -> List (Attribute msg) -> State -> Html msg
view toMsg attributes (State state) =
    let
        config =
            configure attributes

        rules =
            { accept = config.accept
            , maxSize = config.maxSize
            , maxFiles = config.maxFiles
            , multiple = isMultiple config
            }

        hasRejected =
            List.any (\entry -> entry.problem /= Nothing) state.entries

        field =
            config.field
                |> Field.setId state.id
                |> (\f ->
                        if f.hint == Nothing then
                            case ruleSummary config of
                                "" ->
                                    f

                                text ->
                                    Field.setHint text f

                        else
                            f
                   )

        dragging =
            state.dragging > 0 && not config.disabled

        -- The rules (or the application's own hint) are read before the zone
        -- and the list of files: they say what to choose, so they come first.
        -- The input's aria-describedby points at this paragraph.
        hintBefore =
            case field.hint of
                Just text ->
                    [ Html.p
                        [ Internal.cls [ "klar-field__hint", "klar-filedrop__hint" ]
                        , Attr.id (Field.hintId field)
                        ]
                        [ Html.text text ]
                    ]

                Nothing ->
                    []
    in
    -- stable: the application may show an error after a drop, and the zone must
    -- not move into the wrapper then (the focus is on the file input inside it)
    Field.viewStable { field | hint = Nothing }
        (Html.div
            [ Internal.cls
                [ "klar-filedrop"
                , if dragging then
                    "klar-filedrop--over"

                  else
                    ""
                , if config.disabled then
                    "klar-filedrop--disabled"

                  else
                    ""
                , if field.error /= Nothing || hasRejected then
                    "klar-filedrop--invalid"

                  else
                    ""
                , if config.compact then
                    "klar-filedrop--compact"

                  else
                    ""
                ]
            ]
            (hintBefore
                ++ [ viewZone toMsg config rules field state.id
                   , viewList toMsg config rules state
                   , viewAnnouncement config state.change
                   ]
            )
        )


viewZone : (Msg -> msg) -> Config -> Rules -> Field.Config -> String -> Html msg
viewZone toMsg config rules field inputId =
    let
        buttonText =
            if isMultiple config then
                Locale.pick config.locale { nb = "Velg filer", en = "Choose files" }

            else
                Locale.pick config.locale { nb = "Velg fil", en = "Choose file" }

        titleText =
            if isMultiple config then
                Locale.pick config.locale { nb = "Dra og slipp filer her", en = "Drag and drop files here" }

            else
                Locale.pick config.locale { nb = "Dra og slipp en fil her", en = "Drag and drop a file here" }
    in
    Html.div
        ([ Internal.cls [ "klar-filedrop__zone" ] ]
            ++ (if config.disabled then
                    -- A file dropped here must not replace the page: the drop is
                    -- cancelled, and nothing is added.
                    [ Events.preventDefaultOn "dragover" (Decode.succeed ( toMsg Noop, True ))
                    , Events.preventDefaultOn "drop" (Decode.succeed ( toMsg Noop, True ))
                    ]

                else
                    [ Events.preventDefaultOn "dragenter" (dragDecoder DragEntered toMsg)
                    , Events.preventDefaultOn "dragover" (dragDecoder DraggedOver toMsg)
                    , Events.on "dragleave" (Decode.succeed (toMsg DragLeft))
                    , Events.preventDefaultOn "drop"
                        (Decode.at [ "dataTransfer", "files" ] (Decode.list fileDecoder)
                            |> Decode.map (\dropped -> ( toMsg (Dropped rules dropped), True ))
                        )
                    , Events.preventDefaultOn "paste" (pasteDecoder (\pasted -> toMsg (Picked rules pasted)))
                    ]
               )
        )
        [ Html.input
            (Field.controlAttributes field
                ++ [ Internal.cls [ "klar-filedrop__input" ]
                   , Attr.type_ "file"
                   , Attr.multiple (isMultiple config)
                   , Internal.attrIf (not (List.isEmpty config.accept)) (Attr.accept (String.join "," (List.map acceptValue config.accept)))
                   , Attr.disabled config.disabled
                   , Attr.value ""
                   , Events.on "change"
                        (Decode.at [ "target", "files" ] (Decode.list fileDecoder)
                            |> Decode.map (\picked -> toMsg (Picked rules picked))
                        )
                   ]
            )
            []
        , Html.span [ Internal.cls [ "klar-filedrop__icon" ] ] [ Icon.sized Icon.Large Icon.upload ]
        , Html.span [ Internal.cls [ "klar-filedrop__text" ] ]
            [ Html.span [ Internal.cls [ "klar-filedrop__title" ] ] [ Html.text titleText ]
            , Html.span [ Internal.cls [ "klar-filedrop__or" ] ]
                [ Html.text (Locale.pick config.locale { nb = "eller", en = "or" }) ]
            , Html.label
                [ Internal.cls
                    [ "klar-button"
                    , "klar-button--secondary"
                    , "klar-button--md"
                    , "klar-filedrop__browse"
                    , if config.disabled then
                        "klar-button--disabled"

                      else
                        ""
                    ]
                , Attr.for inputId
                ]
                [ Html.span [ Internal.cls [ "klar-button__label" ] ] [ Html.text buttonText ] ]
            ]
        ]


{-| `Files` must be among the dragged types, so dragging a piece of text over
the zone does not light it up.
-}
dragDecoder : Msg -> (Msg -> msg) -> Decoder ( msg, Bool )
dragDecoder msg toMsg =
    -- The fallback is only for browsers whose `types` cannot be read; it must
    -- not catch the "not a file" failure (it did, so text lit the zone up).
    Decode.oneOf
        [ Decode.at [ "dataTransfer", "types" ] (Decode.list Decode.string) |> Decode.map Just
        , Decode.succeed Nothing
        ]
        |> Decode.andThen
            (\types ->
                case types of
                    Just list ->
                        if List.member "Files" list then
                            Decode.succeed ( toMsg msg, True )

                        else
                            Decode.fail "not a file"

                    Nothing ->
                        Decode.succeed ( toMsg msg, True )
            )


{-| Files on the clipboard (a screenshot, files copied in the file manager). Text
on the clipboard is left alone: the paste is not cancelled.
-}
pasteDecoder : (List Incoming -> msg) -> Decoder ( msg, Bool )
pasteDecoder toMsg =
    Decode.at [ "clipboardData", "files" ] (Decode.list fileDecoder)
        |> Decode.andThen
            (\pasted ->
                if List.isEmpty pasted then
                    Decode.fail "no files"

                else
                    Decode.succeed ( toMsg pasted, True )
            )


{-| The rows are keyed by the key of their file, so removing a file does not
make the rows after it again.
-}
viewList : (Msg -> msg) -> Config -> Rules -> Fields -> Html msg
viewList toMsg config rules state =
    if List.isEmpty state.entries then
        Html.text ""

    else
        Keyed.ul
            [ Internal.cls [ "klar-filedrop__list" ]
            , Attr.attribute "aria-label" (Locale.pick config.locale { nb = "Valgte filer", en = "Selected files" })
            ]
            (List.map (\entry -> ( String.fromInt entry.key, viewEntry toMsg config rules state.id entry )) state.entries)


{-| What the last choice or removal did, said once and politely: "2 files added,
1 refused". The region is always there, so screen readers hear what changes in it.
-}
viewAnnouncement : Config -> Change -> Html msg
viewAnnouncement config change =
    Html.p
        [ Internal.cls [ "klar-sr-only" ]
        , Attr.attribute "role" "status"
        ]
        [ Html.text (announcementText config.locale change) ]


announcementText : Locale -> Change -> String
announcementText lang change =
    let
        files n =
            if n == 1 then
                Locale.pick lang { nb = "1 fil", en = "1 file" }

            else
                String.fromInt n ++ Locale.pick lang { nb = " filer", en = " files" }
    in
    case change of
        Unchanged ->
            ""

        Added { accepted, refused } ->
            case ( accepted, refused ) of
                ( _, [] ) ->
                    files accepted ++ Locale.pick lang { nb = " lagt til", en = " added" }

                ( 0, [ ( file, problem ) ] ) ->
                    Locale.pick lang { nb = "Avvist: ", en = "Refused: " } ++ file.name ++ ", " ++ problemText lang problem

                ( 0, _ ) ->
                    files (List.length refused) ++ Locale.pick lang { nb = " avvist", en = " refused" }

                ( _, [ ( file, problem ) ] ) ->
                    files accepted
                        ++ Locale.pick lang { nb = " lagt til. Avvist: ", en = " added. Refused: " }
                        ++ file.name
                        ++ ", "
                        ++ problemText lang problem

                _ ->
                    files accepted
                        ++ Locale.pick lang { nb = " lagt til, ", en = " added, " }
                        ++ String.fromInt (List.length refused)
                        ++ Locale.pick lang { nb = " avvist", en = " refused" }

        Removed name ->
            Locale.pick lang { nb = "Fjernet ", en = "Removed " } ++ name


viewEntry : (Msg -> msg) -> Config -> Rules -> String -> Entry -> Html msg
viewEntry toMsg config rules id entry =
    let
        removeLabel =
            Locale.pick config.locale { nb = "Fjern ", en = "Remove " } ++ entry.file.name
    in
    Html.li
        [ Internal.cls
            [ "klar-filedrop__file"
            , if entry.problem /= Nothing then
                "klar-filedrop__file--invalid"

              else
                ""
            ]
        ]
        [ Html.span [ Internal.cls [ "klar-filedrop__file-icon" ] ] [ Icon.view (iconFor entry.file) ]
        , Html.span [ Internal.cls [ "klar-filedrop__file-text" ] ]
            [ Html.span [ Internal.cls [ "klar-filedrop__file-name", "klar-truncate" ], Attr.title entry.file.name ]
                [ Html.text entry.file.name ]
            , Html.span [ Internal.cls [ "klar-filedrop__file-meta" ] ]
                [ Html.text (Format.bytes config.locale entry.file.size) ]
            , case entry.problem of
                Just problem ->
                    -- announced once with the others by the live region of the field
                    Html.span [ Internal.cls [ "klar-filedrop__file-problem" ] ]
                        [ Html.text (problemText config.locale problem) ]

                Nothing ->
                    Html.text ""
            ]
        , Button.iconOnly
            [ Button.ghost
            , Button.small
            , Button.id (removeId id entry)
            , Button.onClick (toMsg (Remove rules entry.key))
            ]
            Icon.close
            removeLabel
        ]


iconFor : FileInfo -> Icon
iconFor file =
    if String.startsWith "image/" (mimeOf file) then
        Icon.image

    else if String.endsWith ".pdf" (String.toLower file.name) || mimeOf file == "application/pdf" then
        Icon.fileText

    else
        Icon.file


{-| "Allowed types: PDF, images · Max 5.0 MB per file · Up to 3 files"
-}
ruleSummary : Config -> String
ruleSummary config =
    [ if List.isEmpty config.accept then
        Nothing

      else
        Just
            (Locale.pick config.locale { nb = "Tillatte typer: ", en = "Allowed types: " }
                ++ String.join ", " (List.map (typeName config.locale) config.accept)
            )
    , config.maxSize
        |> Maybe.map
            (\bytes ->
                Locale.pick config.locale
                    { nb = "Maks " ++ Format.bytes config.locale bytes ++ " per fil"
                    , en = "Max " ++ Format.bytes config.locale bytes ++ " per file"
                    }
            )
    , config.maxFiles
        |> Maybe.andThen
            (\count ->
                -- one file is not a limit to write out: it is the single-file field
                if count == 1 then
                    Nothing

                else
                    Just
                        (Locale.pick config.locale
                            { nb = "Opptil " ++ String.fromInt count ++ " filer"
                            , en = "Up to " ++ String.fromInt count ++ " files"
                            }
                        )
            )
    ]
        |> List.filterMap identity
        |> String.join " · "


typeName : Locale -> String -> String
typeName lang pattern =
    let
        lower =
            String.toLower (String.trim pattern)
    in
    case lower of
        "image/*" ->
            Locale.pick lang { nb = "bilder", en = "images" }

        "video/*" ->
            Locale.pick lang { nb = "video", en = "video" }

        "audio/*" ->
            Locale.pick lang { nb = "lyd", en = "audio" }

        "application/pdf" ->
            "PDF"

        _ ->
            if String.startsWith "." lower then
                String.toUpper (String.dropLeft 1 lower)

            else if not (String.contains "/" lower) then
                String.toUpper lower

            else
                pattern
