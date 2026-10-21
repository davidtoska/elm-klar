module Klar.FileDrop exposing
    ( view, Attribute
    , State, Msg, init, update
    , FileInfo, files, Problem(..), rejected, hasProblems, isTouched
    , setFiles, clear
    , accept, maxSize, maxFiles, multiple
    , label, labelHidden, hint, error, errorMaybe, required, optionalText
    , compact, disabled
    , locale
    )

{-| Choose files by dropping them on a zone or with a "Choose files" button.

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

**What it does not do: read or upload the file.** The browser's file objects are
read from `change` and `drop` events as plain data (`name`, `size`, `type`)
without `elm/file`, which this library does not use. So the application learns
which files the user picked and can show them, check them and keep the list in
its form, but there is nothing to send to a server. Use it for forms where the
choice itself matters, or combine it with an upload built on `elm/file` in your
application.

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
browser, which replaces the whole application. [Klar.AppShell](Klar-AppShell)
cancels such drops with `onStrayDrop`.

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

@docs FileInfo, files, Problem, rejected, hasProblems, isTouched


# Changing the files from the application

@docs setFiles, clear


# Rules

@docs accept, maxSize, maxFiles, multiple


# Label, hint and error

@docs label, labelHidden, hint, error, errorMaybe, required, optionalText


# Appearance and behavior

@docs compact, disabled


# Language

@docs locale

-}

import Html exposing (Html)
import Html.Attributes as Attr
import Html.Events as Events
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


{-| Why a file was not accepted:

  - `WrongType`: it does not match `accept`
  - `TooLarge`: it is bigger than `maxSize`
  - `TooMany`: there are already `maxFiles` accepted files
  - `Duplicate`: a file with the same name and size is already in the list

A file with several problems gets the first of them in the order `Duplicate`,
`WrongType`, `TooLarge`, `TooMany`. The result stays with the file. Only
`TooMany` and `Duplicate` depend on the other files, so only they are checked
again when the user removes a file.

-}
type Problem
    = WrongType
    | TooLarge
    | TooMany
    | Duplicate


type alias Entry =
    { file : FileInfo
    , problem : Maybe Problem
    }



-- STATE


{-| The state of a file field: the files the user has chosen, with the verdict
on each, and whether files are being dragged over the zone. Make one with
`init`, keep it in your model and give it to `view` and `update`.
-}
type State
    = State
        { id : String
        , entries : List Entry
        , dragging : Int
        , touched : Bool
        }


{-| A field without files. The `String` is the DOM id of the (hidden) file
input; it must be unique on the page, because the label, hint and error point
at it.
-}
init : String -> State
init id =
    State { id = id, entries = [], dragging = 0, touched = False }


{-| The accepted files, in the order they were added. Files that failed a rule
are not in this list; see `rejected`.
-}
files : State -> List FileInfo
files (State state) =
    state.entries
        |> List.filter (\entry -> entry.problem == Nothing)
        |> List.map .file


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
setFiles : List FileInfo -> State -> State
setFiles list (State state) =
    State
        { state
            | entries = List.map (\file -> { file = file, problem = Nothing }) list
            , dragging = 0
            , touched = False
        }


{-| Removes all files, accepted and refused, and forgets that the user has been
in the field (`isTouched` is `False` again).
-}
clear : State -> State
clear (State state) =
    State { state | entries = [], dragging = 0, touched = False }


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


{-| The messages a file field sends: choosing or dropping files, removing one and
dragging over the zone. `view` wraps them with the function you give it; hand
them to `update` when they come back.
-}
type Msg
    = Picked Rules (List FileInfo)
    | Dropped Rules (List FileInfo)
    | Removed Rules Int
    | DragEntered
    | DragLeft
    | DraggedOver
    | Noop


{-| Moves the field on after one of its messages. The `Cmd` moves the focus to
the file input after a file was removed, so pass it on with `Cmd.map`.
-}
update : Msg -> State -> ( State, Cmd Msg )
update msg (State state) =
    case msg of
        Picked rules incoming ->
            ( State { state | entries = addFiles rules incoming state.entries, touched = True }, Cmd.none )

        Dropped rules incoming ->
            ( State { state | entries = addFiles rules incoming state.entries, dragging = 0, touched = True }, Cmd.none )

        Removed rules index ->
            ( State
                { state
                    | entries = revalidate rules (List.take index state.entries ++ List.drop (index + 1) state.entries)
                    , touched = True
                }
              -- the remove button is gone: give focus to "Choose files" (the
              -- file input) instead of losing it to the page
            , Internal.focus state.id Noop
            )

        DragEntered ->
            ( State { state | dragging = state.dragging + 1 }, Cmd.none )

        DragLeft ->
            ( State { state | dragging = Basics.max 0 (state.dragging - 1) }, Cmd.none )

        DraggedOver ->
            ( State { state | dragging = Basics.max 1 state.dragging }, Cmd.none )

        Noop ->
            ( State state, Cmd.none )


addFiles : Rules -> List FileInfo -> List Entry -> List Entry
addFiles rules incoming existing =
    let
        base =
            if rules.multiple then
                existing

            else
                []

        wanted =
            if rules.multiple then
                incoming

            else
                List.take 1 incoming
    in
    List.foldl
        (\file entries -> entries ++ [ { file = file, problem = check rules entries file } ])
        base
        wanted


check : Rules -> List Entry -> FileInfo -> Maybe Problem
check rules existing file =
    if List.any (\entry -> entry.file.name == file.name && entry.file.size == file.size) existing then
        Just Duplicate

    else if not (isAccepted rules.accept file) then
        Just WrongType

    else if tooLarge rules.maxSize file then
        Just TooLarge

    else if overLimit rules.maxFiles existing then
        Just TooMany

    else
        Nothing


tooLarge : Maybe Int -> FileInfo -> Bool
tooLarge limit file =
    case limit of
        Just bytes ->
            file.size > bytes

        Nothing ->
            False


overLimit : Maybe Int -> List Entry -> Bool
overLimit limit existing =
    case limit of
        Just count ->
            List.length (List.filter (\entry -> entry.problem == Nothing) existing) >= count

        Nothing ->
            False


{-| After a removal, check again the files that were refused as `TooMany` or
`Duplicate`: there may be room now, or the file they repeated may be gone. The
result of every other file stays as it is. That includes the accepted ones: a
file that `setFiles` added without a check must not be refused later, because
some other file was removed.
-}
revalidate : Rules -> List Entry -> List Entry
revalidate rules entries =
    List.foldl
        (\entry checked ->
            if entry.problem == Just TooMany || entry.problem == Just Duplicate then
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
            String.toLower file.mime
    in
    if String.startsWith "." pattern then
        String.endsWith pattern name

    else if String.endsWith "/*" pattern then
        String.startsWith (String.dropRight 1 pattern) mime

    else
        pattern == mime


fileDecoder : Decoder FileInfo
fileDecoder =
    Decode.map3 FileInfo
        (Decode.field "name" Decode.string)
        (Decode.field "size" Decode.int)
        (Decode.oneOf [ Decode.field "type" Decode.string, Decode.succeed "" ])



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
                   , viewList toMsg config rules state.entries
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
                    []

                else
                    [ Events.preventDefaultOn "dragenter" (dragDecoder DragEntered toMsg)
                    , Events.preventDefaultOn "dragover" (dragDecoder DraggedOver toMsg)
                    , Events.on "dragleave" (Decode.succeed (toMsg DragLeft))
                    , Events.preventDefaultOn "drop"
                        (Decode.at [ "dataTransfer", "files" ] (Decode.list fileDecoder)
                            |> Decode.map (\dropped -> ( toMsg (Dropped rules dropped), True ))
                        )
                    ]
               )
        )
        [ Html.input
            (Field.controlAttributes field
                ++ [ Internal.cls [ "klar-filedrop__input" ]
                   , Attr.type_ "file"
                   , Attr.multiple (isMultiple config)
                   , Internal.attrIf (not (List.isEmpty config.accept)) (Attr.accept (String.join "," config.accept))
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


viewList : (Msg -> msg) -> Config -> Rules -> List Entry -> Html msg
viewList toMsg config rules entries =
    if List.isEmpty entries then
        Html.text ""

    else
        Html.ul
            [ Internal.cls [ "klar-filedrop__list" ]
            , Attr.attribute "aria-label" (Locale.pick config.locale { nb = "Valgte filer", en = "Selected files" })
            ]
            (List.indexedMap (viewEntry toMsg config rules) entries)


viewEntry : (Msg -> msg) -> Config -> Rules -> Int -> Entry -> Html msg
viewEntry toMsg config rules index entry =
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
                    Html.span
                        [ Internal.cls [ "klar-filedrop__file-problem" ]
                        , Attr.attribute "role" "alert"
                        ]
                        [ Html.text (problemText config problem) ]

                Nothing ->
                    Html.text ""
            ]
        , Button.iconOnly
            [ Button.ghost
            , Button.small
            , Button.onClick (toMsg (Removed rules index))
            ]
            Icon.close
            removeLabel
        ]


iconFor : FileInfo -> Icon
iconFor file =
    if String.startsWith "image/" (String.toLower file.mime) then
        Icon.image

    else if String.endsWith ".pdf" (String.toLower file.name) || file.mime == "application/pdf" then
        Icon.fileText

    else
        Icon.file


problemText : Config -> Problem -> String
problemText config problem =
    case problem of
        WrongType ->
            Locale.pick config.locale { nb = "Filtypen er ikke tillatt", en = "File type not allowed" }

        TooLarge ->
            Locale.pick config.locale
                { nb = "Filen er for stor (maks " ++ sizeText config ++ ")"
                , en = "File is too large (max " ++ sizeText config ++ ")"
                }

        TooMany ->
            Locale.pick config.locale
                { nb = "For mange filer (maks " ++ String.fromInt (Maybe.withDefault 0 config.maxFiles) ++ ")"
                , en = "Too many files (max " ++ String.fromInt (Maybe.withDefault 0 config.maxFiles) ++ ")"
                }

        Duplicate ->
            Locale.pick config.locale { nb = "Filen er allerede lagt til", en = "File already added" }


sizeText : Config -> String
sizeText config =
    Format.bytes config.locale (Maybe.withDefault 0 config.maxSize)


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

            else
                pattern
