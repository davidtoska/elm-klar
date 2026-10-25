module Klar.MarkdownEditor exposing
    ( view
    , State, init, value, setValue, focus, Msg, update
    , Attribute, label, labelHidden, hint, error, errorMaybe, required, optionalText
    , rows, placeholder, maxLength, disabled, readOnly, onFocus, onBlur
    , tabbed, sideBySide, preview, syntaxHelp, locale
    )

{-| A text area for Markdown with a toolbar and a live preview: the editor of a
note, a description, a comment, or the instruction to a language model.

Use when: the user writes Markdown and should see the result as it is typed.
Do not use when: the text is only shown, use `Klar.Markdown`, or when plain text is enough, use `Klar.TextArea`.
Quick path: `init`, `update`, `view`, `value`

    import Klar.MarkdownEditor as MarkdownEditor

    -- model: description : MarkdownEditor.State
    -- init:  MarkdownEditor.init "order-description"

    -- update
    DescriptionMsg m ->
        let
            ( description, cmd ) =
                MarkdownEditor.update m model.description
        in
        ( { model | description = description }, Cmd.map DescriptionMsg cmd )

    -- view
    MarkdownEditor.view DescriptionMsg
        [ MarkdownEditor.label "Description"
        , MarkdownEditor.hint "Shown on the packing slip."
        , MarkdownEditor.maxLength 2000
        ]
        model.description

The state holds the text: read it with `value` and compare it before and after an
update to react to a change, as with the other inputs; set it from outside with
`setValue`. The text is exactly what the user typed, with line breaks as `\n`.

**Writing and previewing.** On a wide container the text area and the preview are
side by side; on a narrow one there are two tabs, "Write" and "Preview". The
container decides, not the window, so an editor in a narrow column of a wide page
gets tabs. `tabbed` and `sideBySide` fix the layout. The preview is the view of
[Klar.Markdown](Klar-Markdown), so everything that is true there is true here: raw
HTML is shown as text, links are checked, images are not loaded unless you say so
with `preview`; the ids of its headings start with the id of the editor and `-md-`, so
that text written in the editor cannot make an element with the id of the label or
the hint of the field. The preview follows the text as it is typed; for a text of more than
8,000 characters it waits for a pause of a quarter of a second, so typing never
waits for it, and says that it is catching up (`aria-busy`). It is not announced to
screen readers, which would be noise.

The editor needs a width: it is as wide as the place it is in, and in a container that
is as wide as its content (a flex item without a width, an inline block, a table
cell) it falls back to a minimum of 16em. Give such a place a width.

**The toolbar** has bold, italic, code, link, heading, quote, bullet list, numbered
list and task list. They act on the selection, or on the lines it touches, and give
the selection back: the text that was selected stays selected, so a button pressed
twice undoes itself. Bold, italic and link also have the keyboard shortcuts
`Ctrl B`, `Ctrl I` and `Ctrl K` (`Cmd` on a Mac). Those, and `Ctrl Z`, `Ctrl Y` and
`Ctrl Shift Z` while the text is exactly what the last button left (see below), are
the only keys the text area takes over; every other key is the browser's. A key the
text area takes over goes no further: when the application has a shortcut of its own on
`Ctrl K` (a command palette), the cursor in the text gets the link and the palette does
not open as well.

**What cannot be done in plain Elm, and what is done about it.** A text area has a
selection, and an application cannot read or write it without JavaScript. The editor
reads it from the events of the text area (`selectionStart` and `selectionEnd` of
the event target), which is exact. It writes it by setting the same two properties
of the element when the text is changed by a button, in the same update as the new
text, so the caret is where the change leaves it and does not jump to the end, which
is what a browser does when a script gives a text area a new value. Two things
follow, and both are about the browser, not about this module:

  - Setting the text from a script makes the browser forget the undo history of the
    text area. The editor keeps the last 20 changes of the buttons and undoes them
    with `Ctrl Z` (and redoes them with `Ctrl Y` or `Ctrl Shift Z`) while the text is
    as that change left it. After typing, `Ctrl Z` is the browser's again, and when
    it has undone the typing it reaches the editor's changes again.
  - The scroll position of a long text after a button is the browser's choice.
  - A text area that is made again (the editor was left out of the view and put back)
    is given the selection of the last button change once, clamped to the text. The
    property cannot be taken away: Elm would write `null`, which for a selection is 0.

**The text is the user's.** The editor changes it only for a button or a shortcut,
and never by itself. `maxLength` does not cut anything off: the counter turns red
and an error says by how many characters the text is too long, and the browser's
`maxlength` is not set, because that would cut off a pasted text without a word.
Check `String.length (MarkdownEditor.value state)` before you save.

The accessible name of the text area is its label; the preview is a group named
"Preview" and takes the Tab key, so that it can be scrolled. All built-in text comes
in English and Norwegian Bokmål (`locale`).


# View

@docs view


# State

@docs State, init, value, setValue, focus, Msg, update


# Label, hint and error

@docs Attribute, label, labelHidden, hint, error, errorMaybe, required, optionalText


# The text area

@docs rows, placeholder, maxLength, disabled, readOnly, onFocus, onBlur


# Layout and preview

@docs tabbed, sideBySide, preview, syntaxHelp, locale

-}

import Html exposing (Html)
import Html.Attributes as Attr
import Html.Events as Events
import Html.Lazy as Lazy
import Json.Decode as Decode exposing (Decoder)
import Json.Encode as Encode
import Klar.Button as Button
import Klar.Field as Field
import Klar.Icon as Icon exposing (Icon)
import Klar.Icon.Editor as EditorIcon
import Klar.Internal as Internal
import Klar.Locale as Locale exposing (Locale)
import Klar.Markdown as Markdown
import Klar.MarkdownEditor.Edit as Edit exposing (Action(..), Selection)
import Klar.Tabs as Tabs
import Klar.Toolbar as Toolbar
import Process
import Task



-- STATE


{-| What the editor remembers: the text, where its selection is, the parsed text for
the preview, the last changes of the buttons (for `Ctrl Z`) and which tab is shown
when the layout has tabs. Make one with `init`, keep it in your model and give it to
`view` and `update`.
-}
type State
    = State
        { id : String
        , value : String
        , selection : Selection
        , document : Markdown.Document
        , stale : Bool
        , ticket : Int
        , restore : Maybe Restore
        , history : History
        , tabs : Tabs.State String
        }


{-| The selection that the text area is told to show, and a flip that makes the
same selection a new value for the browser every time (see `restoreAttributes`).
-}
type alias Restore =
    { selection : Selection
    , flip : Bool
    }


type alias Entry =
    { before : Edit.Edit
    , after : Edit.Edit
    }


type alias History =
    { past : List Entry
    , future : List Entry
    }


{-| A text of this many characters or fewer is parsed for the preview at every key
press; a longer one after a pause.
-}
immediateLimit : Int
immediateLimit =
    8000


{-| The most changes of the buttons that can be undone.
-}
historyLimit : Int
historyLimit =
    20


{-| An editor with no text. The `String` is the DOM id of the text area and the
prefix of the ids of the parts around it: it must be unique on the page.

    MarkdownEditor.init "order-description"

-}
init : String -> State
init id =
    State
        { id = id
        , value = ""
        , selection = { start = 0, end = 0 }
        , document = Markdown.parse ""
        , stale = False
        , ticket = 0
        , restore = Nothing
        , history = { past = [], future = [] }
        , tabs = Tabs.init (id ++ "-tabs") "write"
        }


{-| The text. This is what the user typed, with line breaks as `\n`.
-}
value : State -> String
value (State state) =
    state.value


{-| Replaces the text, for example with the one that was saved, or empty after a
save. The caret goes to the end, as in any text area, and the changes that `Ctrl Z`
could undo are forgotten. Line breaks written as `\r\n` or `\r` become `\n`, because a
text area cannot hold them.
-}
setValue : String -> State -> State
setValue text (State state) =
    let
        normal =
            text |> String.replace "\u{000D}\n" "\n" |> String.replace "\u{000D}" "\n"
    in
    State
        { state
            | value = normal
            , selection = { start = String.length normal, end = String.length normal }
            , document = Markdown.parse normal
            , stale = False
            , history = { past = [], future = [] }
        }


{-| Moves the keyboard focus to the text area, for example when a dialog with the
editor opens. When the editor has tabs and the Preview tab is shown, the Write tab
is shown first, because a text area that is not shown cannot take the focus. Map the
command with your message constructor.
-}
focus : State -> Cmd Msg
focus _ =
    Task.perform (\_ -> Focus) (Task.succeed ())



-- MESSAGES AND UPDATE


type alias Reading =
    { value : String
    , selection : Selection
    }


{-| What happens in the editor: the text changes, the selection moves, a button or
a shortcut is used, a pause ends, a tab is chosen. Wrap it in a constructor of your
own message type, give that constructor to `view` and hand the messages you get back
to `update`.
-}
type Msg
    = Changed String Selection
    | Moved String Selection
    | Acted Edit.Placeholders Action (Maybe Reading)
    | Shortcut Edit.Placeholders Action Reading
    | Undo
    | Redo
    | Settled Int
    | TabsMsg (Tabs.Msg String)
    | Focus
    | Noop


{-| Handles the messages of the editor. The `Cmd` gives the keyboard focus back to
the text area after a button, waits for the pause of a long text, and moves the focus
of the tabs, so map it with your message constructor.
-}
update : Msg -> State -> ( State, Cmd Msg )
update msg (State state) =
    case msg of
        Changed text selection ->
            -- typing ends what could be redone
            { state | value = text, selection = selection, history = { past = state.history.past, future = [] } }
                |> refreshPreview

        Moved text selection ->
            -- the text of the event is the text of the text area; when the browser has not
            -- caught up with a change that was just made, its selection is not ours
            if text == state.value then
                ( State { state | selection = selection }, Cmd.none )

            else
                ( State state, Cmd.none )

        Acted placeholders action reading ->
            act placeholders action (selectionOf state.value state.selection reading) state

        Shortcut placeholders action reading ->
            act placeholders action (selectionOf state.value state.selection (Just reading)) state

        Undo ->
            case state.history.past of
                entry :: older ->
                    if state.value == entry.after.text then
                        replace entry.before { state | history = { past = older, future = entry :: state.history.future } }

                    else
                        ( State state, Cmd.none )

                [] ->
                    ( State state, Cmd.none )

        Redo ->
            case state.history.future of
                entry :: newer ->
                    if state.value == entry.before.text then
                        replace entry.after { state | history = { past = entry :: state.history.past, future = newer } }

                    else
                        ( State state, Cmd.none )

                [] ->
                    ( State state, Cmd.none )

        Settled ticket ->
            if ticket == state.ticket && state.stale then
                ( State { state | document = Markdown.parse state.value, stale = False }, Cmd.none )

            else
                ( State state, Cmd.none )

        TabsMsg tabsMsg ->
            let
                ( tabs, cmd ) =
                    Tabs.update tabsMsg state.tabs
            in
            ( State { state | tabs = tabs }, Cmd.map TabsMsg cmd )

        Focus ->
            ( State { state | tabs = Tabs.setActive "write" state.tabs }, Internal.focus state.id Noop )

        Noop ->
            ( State state, Cmd.none )


type alias Fields =
    { id : String
    , value : String
    , selection : Selection
    , document : Markdown.Document
    , stale : Bool
    , ticket : Int
    , restore : Maybe Restore
    , history : History
    , tabs : Tabs.State String
    }


{-| The selection a change starts from: the one the text area had when the button
was pressed, when it had the focus (the page can say), otherwise the last one seen.
-}
selectionOf : String -> Selection -> Maybe Reading -> Selection
selectionOf text remembered reading =
    case reading of
        Just read ->
            if read.value == text then
                read.selection

            else
                remembered

        Nothing ->
            remembered


act : Edit.Placeholders -> Action -> Selection -> Fields -> ( State, Cmd Msg )
act placeholders action selection state =
    let
        before =
            { text = state.value, selection = Edit.clampSelection state.value selection }

        after =
            Edit.apply placeholders action before
    in
    if after == before then
        ( State { state | selection = after.selection }, Internal.focus state.id Noop )

    else
        replace after
            { state
                | history =
                    { past = { before = before, after = after } :: List.take (historyLimit - 1) state.history.past
                    , future = []
                    }
            }


{-| Puts a text and a selection in the text area.
-}
replace : Edit.Edit -> Fields -> ( State, Cmd Msg )
replace edit state =
    let
        flip =
            case state.restore of
                Just restore ->
                    not restore.flip

                Nothing ->
                    False

        ( State next, cmd ) =
            refreshPreview
                { state
                    | value = edit.text
                    , selection = edit.selection
                    , restore = Just { selection = edit.selection, flip = flip }
                }
    in
    ( State next, Cmd.batch [ cmd, Internal.focus state.id Noop ] )


{-| Reads the text again for the preview: at once when it is short, after a pause
when it is long, so that typing never waits for the parser.
-}
refreshPreview : Fields -> ( State, Cmd Msg )
refreshPreview state =
    if String.length state.value <= immediateLimit then
        ( State { state | document = Markdown.parse state.value, stale = False }, Cmd.none )

    else
        let
            ticket =
                state.ticket + 1
        in
        ( State { state | stale = True, ticket = ticket }
        , Process.sleep 250 |> Task.perform (\_ -> Settled ticket)
        )



-- ATTRIBUTES


{-| A setting of the editor. Make them with the functions below and pass a list to
`view`; later attributes win over earlier ones.
-}
type Attribute msg
    = Attribute (Config msg -> Config msg)


type Layout
    = ResponsiveLayout
    | TabsLayout
    | SideBySideLayout


type alias Config msg =
    { field : Field.Config
    , placeholder : String
    , rows : Int
    , maxLength : Maybe Int
    , disabled : Bool
    , readOnly : Bool
    , onFocus : Maybe msg
    , onBlur : Maybe msg
    , layout : Layout
    , preview : List Markdown.Attribute
    , syntaxHelp : Bool
    , locale : Locale
    }


configure : List (Attribute msg) -> Config msg
configure attributes =
    List.foldl (\(Attribute change) config -> change config)
        { field = Field.empty
        , placeholder = ""
        , rows = 12
        , maxLength = Nothing
        , disabled = False
        , readOnly = False
        , onFocus = Nothing
        , onBlur = Nothing
        , layout = ResponsiveLayout
        , preview = []
        , syntaxHelp = False
        , locale = Locale.default
        }
        attributes


updateField : (Field.Config -> Field.Config) -> Attribute msg
updateField change =
    Attribute (\config -> { config | field = change config.field })


{-| The label above the editor. Clicking it focuses the text area and screen readers
read it as the name of the text area. Give every editor a label, or hide it with
`labelHidden`.
-}
label : String -> Attribute msg
label text =
    updateField (Field.setLabel text)


{-| Hides the `label` visually but keeps it for screen readers.
-}
labelHidden : Attribute msg
labelHidden =
    updateField Field.setLabelHidden


{-| Help text under the editor, for example what the text is for. Screen readers read
it together with the label.
-}
hint : String -> Attribute msg
hint text =
    updateField (Field.setHint text)


{-| Shows an error message under the editor and marks it invalid. Screen readers
announce the message when it appears. An editor with a `maxLength` shows its own
error when the text is too long, unless you give one. To show an error only
sometimes, use `errorMaybe`.
-}
error : String -> Attribute msg
error text =
    updateField (Field.setError (Just text))


{-| Like `error`, but takes a `Maybe`: `Just message` shows the message and `Nothing`
shows none.
-}
errorMaybe : Maybe String -> Attribute msg
errorMaybe maybe =
    updateField (Field.setError maybe)


{-| Marks the field as required: an asterisk after the label and `aria-required` on
the text area. This checks nothing: look at the text yourself and show an `error`.
-}
required : Attribute msg
required =
    updateField (Field.setRequired True)


{-| Text such as `"(optional)"` after the label of a field that is not `required`.
By default nothing is shown.
-}
optionalText : String -> Attribute msg
optionalText text =
    updateField (Field.setOptionalText text)


{-| The height of the text area and of the preview, in lines of text. Default 12,
and never less than 3. The text scrolls inside the editor, so the page does not
change height as the text grows.
-}
rows : Int -> Attribute msg
rows lines =
    Attribute (\config -> { config | rows = max 3 lines })


{-| Text shown in the empty text area, for example an example of what to write. It is
not a substitute for the `label`. Default: none.
-}
placeholder : String -> Attribute msg
placeholder text =
    Attribute (\config -> { config | placeholder = text })


{-| Shows a counter such as `120/2000` under the editor at the end of the line with
the hint. It turns amber when the limit is near and red, with an error that says by
how many characters, when the text is longer. Nothing is cut off, and the user can
still type and paste: a limit that silently loses a pasted text is not honest.
Check the length before you save.
-}
maxLength : Int -> Attribute msg
maxLength limit =
    Attribute (\config -> { config | maxLength = Just limit })


{-| While `True` the editor is dimmed and cannot be focused or changed. Default
`False`. The preview still shows the text.
-}
disabled : Bool -> Attribute msg
disabled isDisabled =
    Attribute (\config -> { config | disabled = isDisabled })


{-| While `True` the user can focus the text, select it and read the preview, but
the text cannot be changed and the toolbar is off. Default `False`.
-}
readOnly : Bool -> Attribute msg
readOnly isReadOnly =
    Attribute (\config -> { config | readOnly = isReadOnly })


{-| Sends this message when the text area gets the focus.
-}
onFocus : msg -> Attribute msg
onFocus msg =
    Attribute (\config -> { config | onFocus = Just msg })


{-| Sends this message when the text area loses the focus: a good moment to check
the text, so that an error does not appear while the user is still typing.
-}
onBlur : msg -> Attribute msg
onBlur msg =
    Attribute (\config -> { config | onBlur = Just msg })


{-| Always two tabs, "Write" and "Preview", also when the container is wide. Use it
for a narrow place that is not narrow enough for the editor to notice, or when you
want one thing at a time. Without it and without `sideBySide` the layout follows the
width of the container: tabs below 40em, side by side above.
-}
tabbed : Attribute msg
tabbed =
    Attribute (\config -> { config | layout = TabsLayout })


{-| Always the text area and the preview side by side, also in a narrow container.
-}
sideBySide : Attribute msg
sideBySide =
    Attribute (\config -> { config | layout = SideBySideLayout })


{-| Attributes for the preview, which is a [Klar.Markdown](Klar-Markdown) view:
`Markdown.images`, `Markdown.imagesFrom`, `Markdown.headingOffset` and the others.
The `locale` and the `idPrefix` of the preview are the editor's own, and a
`Markdown.locale` or `Markdown.idPrefix` in this list wins over them. Define the list
once (a constant) and the preview is not redrawn while the text waits for its pause.

    MarkdownEditor.preview [ Markdown.imagesFrom hosts ]

-}
preview : List Markdown.Attribute -> Attribute msg
preview attributes =
    Attribute (\config -> { config | preview = attributes })


{-| A line under the editor, "Markdown is supported", that opens a short list of the
syntax. Off by default.
-}
syntaxHelp : Attribute msg
syntaxHelp =
    Attribute (\config -> { config | syntaxHelp = True })


{-| The language of the built-in text: the buttons, the tabs, the preview, the count
and the error of the limit. Default `Locale.default`, which is English. Texts you
give yourself are shown as they are.
-}
locale : Locale -> Attribute msg
locale value_ =
    Attribute (\config -> { config | locale = value_ })



-- TEXTS


type alias Texts =
    { formatting : String
    , bold : String
    , italic : String
    , code : String
    , link : String
    , heading : String
    , quote : String
    , bullets : String
    , numbers : String
    , tasks : String
    , write : String
    , preview : String
    , views : String
    , nothing : String
    , linkText : String
    , tooLong : Int -> String
    , counted : Int -> Int -> String
    }


texts : Locale -> Texts
texts lang =
    let
        pick nb en =
            Locale.pick lang { nb = nb, en = en }
    in
    { formatting = pick "Formatering" "Formatting"
    , bold = pick "Fet" "Bold"
    , italic = pick "Kursiv" "Italic"
    , code = pick "Kode" "Code"
    , link = pick "Lenke" "Link"
    , heading = pick "Overskrift" "Heading"
    , quote = pick "Sitat" "Quote"
    , bullets = pick "Punktliste" "Bulleted list"
    , numbers = pick "Nummerert liste" "Numbered list"
    , tasks = pick "Oppgaveliste" "Task list"
    , write = pick "Skriv" "Write"
    , preview = pick "Forhåndsvisning" "Preview"
    , views = pick "Skriv eller forhåndsvis" "Write or preview"
    , nothing = pick "Ingenting å forhåndsvise ennå." "Nothing to preview yet."
    , linkText = pick "tekst" "text"
    , tooLong =
        \over ->
            pick
                ("Teksten er " ++ String.fromInt over ++ " tegn for lang.")
                ("The text is " ++ String.fromInt over ++ " characters too long.")
    , counted =
        \length limit ->
            pick
                (String.fromInt length ++ " av " ++ String.fromInt limit ++ " tegn")
                (String.fromInt length ++ " of " ++ String.fromInt limit ++ " characters")
    }



-- VIEW


{-| The editor: a label, a toolbar, the text area and the preview, a hint and an
error. The first argument wraps the editor's messages in your own type.

    MarkdownEditor.view DescriptionMsg [ MarkdownEditor.label "Description" ] model.description

-}
view : (Msg -> msg) -> List (Attribute msg) -> State -> Html msg
view toMsg attributes (State state) =
    let
        config =
            configure attributes

        words =
            texts config.locale

        length =
            String.length state.value

        over =
            case config.maxLength of
                Just limit ->
                    length - limit

                Nothing ->
                    0

        field =
            let
                base =
                    Field.setId state.id config.field
            in
            if over > 0 && base.error == Nothing then
                Field.setError (Just (words.tooLong over)) base

            else
                base

        showingPreview =
            Tabs.active state.tabs == "preview"

        inactive =
            config.disabled || config.readOnly

        box =
            Html.div
                [ Internal.cls
                    [ "klar-mdeditor"
                    , case config.layout of
                        ResponsiveLayout ->
                            ""

                        TabsLayout ->
                            "klar-mdeditor--tabs"

                        SideBySideLayout ->
                            "klar-mdeditor--split"
                    , if showingPreview then
                        "klar-mdeditor--showing-preview"

                      else
                        ""
                    , if config.disabled then
                        "klar-mdeditor--disabled"

                      else
                        ""
                    , if field.error /= Nothing then
                        "klar-mdeditor--invalid"

                      else
                        ""
                    , if state.stale then
                        "klar-mdeditor--stale"

                      else
                        ""
                    ]
                , Internal.styleVars [ ( "--klar-mdeditor-rows", String.fromInt config.rows ) ]
                ]
                [ Html.div [ Internal.cls [ "klar-mdeditor__bar" ] ]
                    [ Html.div [ Internal.cls [ "klar-mdeditor__tabs" ] ]
                        [ Tabs.view (TabsMsg >> toMsg)
                            [ Tabs.tabs [ Tabs.tab "write" words.write, Tabs.tab "preview" words.preview ]
                            , Tabs.ariaLabel words.views
                            , Tabs.small
                            ]
                            state.tabs
                        ]
                    , Html.div [ Internal.cls [ "klar-mdeditor__toolbar" ] ] [ viewToolbar toMsg words state.id inactive ]
                    ]
                , Html.div [ Internal.cls [ "klar-mdeditor__panes" ] ]
                    [ Html.div [ Internal.cls [ "klar-mdeditor__pane", "klar-mdeditor__pane--write" ] ]
                        [ viewControl toMsg config words field state ]
                    , viewPreview config words state
                    ]
                , if config.syntaxHelp then
                    viewHelp config.locale

                  else
                    Html.text ""
                ]
    in
    case config.maxLength of
        Just limit ->
            Field.viewWithAside field (viewCounter words length limit) box

        Nothing ->
            Field.view field box


viewCounter : Texts -> Int -> Int -> Html msg
viewCounter words length limit =
    let
        remaining =
            limit - length

        near =
            remaining <= max 10 (limit // 10)
    in
    Html.span
        [ Internal.cls
            [ "klar-textarea__counter"
            , if remaining < 0 then
                "klar-textarea__counter--over"

              else if near then
                "klar-textarea__counter--near"

              else
                ""
            ]
        , Internal.attrIf near (Attr.attribute "aria-live" "polite")
        ]
        [ Html.span [ Attr.attribute "aria-hidden" "true" ] [ Html.text (String.fromInt length ++ "/" ++ String.fromInt limit) ]
        , Html.span [ Internal.cls [ "klar-sr-only" ] ] [ Html.text (words.counted length limit) ]
        ]



-- THE TEXT AREA


{-| The text area. It is a plain `textarea` with the attributes of a field, because
the editor needs two things that `Klar.TextArea` cannot give it: handlers for the
events that report the selection, and the properties that set it.
-}
viewControl : (Msg -> msg) -> Config msg -> Texts -> Field.Config -> { a | value : String, restore : Maybe Restore, history : History } -> Html msg
viewControl toMsg config words field state =
    let
        placeholders =
            { linkText = words.linkText }

        reading =
            readingDecoder

        canUndo =
            case state.history.past of
                entry :: _ ->
                    state.value == entry.after.text

                [] ->
                    False

        canRedo =
            case state.history.future of
                entry :: _ ->
                    state.value == entry.before.text

                [] ->
                    False
    in
    Html.textarea
        (Field.controlAttributes field
            ++ [ Internal.cls [ "klar-mdeditor__control" ]
               , Attr.value state.value
               , Attr.placeholder config.placeholder
               , Attr.rows config.rows
               , Attr.disabled config.disabled
               , Attr.readonly config.readOnly
               , Attr.attribute "autocomplete" "off"
               , Events.on "input" (Decode.map (\r -> toMsg (Changed r.value r.selection)) reading)
               , Events.on "keyup" (Decode.map (\r -> toMsg (Moved r.value r.selection)) reading)
               , Events.on "mouseup" (Decode.map (\r -> toMsg (Moved r.value r.selection)) reading)
               , Events.on "select" (Decode.map (\r -> toMsg (Moved r.value r.selection)) reading)
               , Events.on "focusout" (Decode.map (\r -> toMsg (Moved r.value r.selection)) reading)
               , Internal.attrIf (not (config.disabled || config.readOnly))
                    -- a shortcut of the editor is handled completely: it goes no further, so
                    -- the shortcut of the application on the same keys (Ctrl K opens a command
                    -- palette) does not fire as well
                    (Events.custom "keydown"
                        (shortcutDecoder toMsg placeholders canUndo canRedo
                            |> Decode.map (\( message, _ ) -> { message = message, stopPropagation = True, preventDefault = True })
                        )
                    )
               , Internal.attrMaybe Events.onFocus config.onFocus
               , Internal.attrMaybe Events.onBlur config.onBlur
               ]
            -- these come after `value`: the browser puts the caret at the end when it
            -- gets a new value, and the selection is set after that
            ++ restoreAttributes state.restore
        )
        []


{-| The properties that give the text area a selection. Elm sets a property when
its value is not the one it set before, so the same selection a second time would
be ignored. The value is therefore written as a number one time and as the same
number in a string the next: the browser reads both alike, Elm sees a change.

The properties are never taken away again once they are there. Elm would put a
property that goes away back to `null`, which for a selection is 0.

`selectionEnd` is set first: setting `selectionStart` after the end is before
the old start would otherwise move the end.

-}
restoreAttributes : Maybe Restore -> List (Html.Attribute msg)
restoreAttributes maybe =
    case maybe of
        Nothing ->
            []

        Just restore ->
            let
                number n =
                    if restore.flip then
                        Encode.string (String.fromInt n)

                    else
                        Encode.int n
            in
            [ Attr.property "selectionEnd" (number restore.selection.end)
            , Attr.property "selectionStart" (number restore.selection.start)
            ]


readingDecoder : Decoder Reading
readingDecoder =
    Decode.map2 Reading
        (Decode.at [ "target", "value" ] Decode.string)
        (Decode.map2 Selection
            (Decode.at [ "target", "selectionStart" ] Decode.int)
            (Decode.at [ "target", "selectionEnd" ] Decode.int)
        )


{-| Ctrl or Cmd with B, I or K are bold, italic and link; Z and Y undo and redo the
last changes of the buttons while that is what the text is. Any other key is left to
the browser: the handler fails, so the default is not prevented. A key that is handled
is not passed on either (see the call): an application that has Ctrl K for something of
its own gets the link of the editor while the cursor is in the text.
-}
shortcutDecoder : (Msg -> msg) -> Edit.Placeholders -> Bool -> Bool -> Decoder ( msg, Bool )
shortcutDecoder toMsg placeholders canUndo canRedo =
    Decode.map5
        (\key ctrl meta shift alt -> { key = String.toLower key, modifier = ctrl || meta, shift = shift, alt = alt })
        (Decode.field "key" Decode.string)
        (Decode.field "ctrlKey" Decode.bool)
        (Decode.field "metaKey" Decode.bool)
        (Decode.field "shiftKey" Decode.bool)
        (Decode.field "altKey" Decode.bool)
        |> Decode.andThen
            (\event ->
                Decode.oneOf [ Decode.field "isComposing" Decode.bool, Decode.succeed False ]
                    |> Decode.andThen
                        (\composing ->
                            if composing || not event.modifier || event.alt then
                                Decode.fail "not a shortcut"

                            else
                                case ( event.key, event.shift ) of
                                    ( "b", False ) ->
                                        formatting toMsg placeholders Bold

                                    ( "i", False ) ->
                                        formatting toMsg placeholders Italic

                                    ( "k", False ) ->
                                        formatting toMsg placeholders Link

                                    ( "z", False ) ->
                                        if canUndo then
                                            Decode.succeed ( toMsg Undo, True )

                                        else
                                            Decode.fail "the browser undoes"

                                    ( "z", True ) ->
                                        if canRedo then
                                            Decode.succeed ( toMsg Redo, True )

                                        else
                                            Decode.fail "the browser redoes"

                                    ( "y", False ) ->
                                        if canRedo then
                                            Decode.succeed ( toMsg Redo, True )

                                        else
                                            Decode.fail "the browser redoes"

                                    _ ->
                                        Decode.fail "not a shortcut"
                        )
            )


formatting : (Msg -> msg) -> Edit.Placeholders -> Action -> Decoder ( msg, Bool )
formatting toMsg placeholders action =
    Decode.map (\read -> ( toMsg (Shortcut placeholders action read), True )) readingDecoder



-- THE TOOLBAR


viewToolbar : (Msg -> msg) -> Texts -> String -> Bool -> Html msg
viewToolbar toMsg words id inactive =
    let
        button action icon name shortcut =
            Button.iconOnly
                [ Button.ghost
                , Button.small
                , Button.disabled inactive
                , Button.title
                    (case shortcut of
                        Just key ->
                            name ++ " (Ctrl/Cmd+" ++ key ++ ")"

                        Nothing ->
                            name
                    )
                , Button.htmlAttrs
                    [ -- the text area keeps the focus (and so its selection) while the mouse is
                      -- on a button; the button reads the selection from the focused element
                      Internal.onMouseDownPrevent (toMsg Noop)
                    , Events.on "click" (Decode.map (\read -> toMsg (Acted { linkText = words.linkText } action read)) (focusedReading id))
                    , Internal.attrMaybe (\_ -> Attr.attribute "aria-keyshortcuts" (shortcutKeys action)) shortcut
                    ]
                ]
                icon
                name
    in
    Toolbar.view [ Toolbar.ariaLabel words.formatting, Toolbar.small, Toolbar.plain ]
        [ Toolbar.group
            [ button Bold Icon.bold words.bold (Just "B")
            , button Italic Icon.italic words.italic (Just "I")
            , button Code Icon.code words.code Nothing
            , button Link Icon.link words.link (Just "K")
            ]
        , Toolbar.separator
        , Toolbar.group
            [ button Heading Icon.heading words.heading Nothing
            , button Quote EditorIcon.quote words.quote Nothing
            ]
        , Toolbar.separator
        , Toolbar.group
            [ button BulletList Icon.list words.bullets Nothing
            , button NumberedList Icon.listOrdered words.numbers Nothing
            , button TaskList EditorIcon.listTodo words.tasks Nothing
            ]
        ]


shortcutKeys : Action -> String
shortcutKeys action =
    case action of
        Bold ->
            "Control+B Meta+B"

        Italic ->
            "Control+I Meta+I"

        Link ->
            "Control+K Meta+K"

        _ ->
            ""


{-| The text area, if it is the element that has the focus: the page's active
element. A button that is pressed with the mouse does not take the focus (see
`onMouseDownPrevent`), so the selection of the text area is read, whatever it was
doing since the last event. A button that is pressed with the keyboard has the
focus itself; then there is nothing to read and the last selection seen is used.
-}
focusedReading : String -> Decoder (Maybe Reading)
focusedReading id =
    Decode.oneOf
        [ Decode.at [ "target", "ownerDocument", "activeElement" ]
            (Decode.field "id" Decode.string
                |> Decode.andThen
                    (\found ->
                        if found == id then
                            Decode.map Just
                                (Decode.map2 Reading
                                    (Decode.field "value" Decode.string)
                                    (Decode.map2 Selection (Decode.field "selectionStart" Decode.int) (Decode.field "selectionEnd" Decode.int))
                                )

                        else
                            Decode.succeed Nothing
                    )
            )
        , Decode.succeed Nothing
        ]



-- THE PREVIEW


viewPreview : Config msg -> Texts -> { a | id : String, value : String, document : Markdown.Document, stale : Bool } -> Html msg
viewPreview config words state =
    Html.div
        [ Internal.cls [ "klar-mdeditor__pane", "klar-mdeditor__pane--preview" ]
        , Attr.id (state.id ++ "-preview")
        , Attr.attribute "role" "group"
        , Attr.attribute "aria-label" words.preview
        , Attr.tabindex 0
        , Internal.attrIf state.stale (Attr.attribute "aria-busy" "true")
        ]
        [ if String.trim state.value == "" then
            Html.p [ Internal.cls [ "klar-mdeditor__empty" ] ] [ Html.text words.nothing ]

          else
            Lazy.lazy4 previewOf config.locale (state.id ++ "-md-") config.preview state.document
        ]


{-| The preview: the ids of its headings start with the id of the editor, so that the
text of the user cannot make an element with the id of a part of the field (the hint
that `aria-describedby` points at, the text area itself). The attributes of the
application come later and so win.
-}
previewOf : Locale -> String -> List Markdown.Attribute -> Markdown.Document -> Html msg
previewOf lang prefix attributes document =
    Markdown.viewDocument (Markdown.idPrefix prefix :: Markdown.locale lang :: attributes) document


viewHelp : Locale -> Html msg
viewHelp lang =
    let
        pick nb en =
            Locale.pick lang { nb = nb, en = en }

        row syntax meaning =
            Html.li [ Internal.cls [ "klar-mdeditor__syntax" ] ]
                [ Html.code [] [ Html.text syntax ]
                , Html.span [] [ Html.text meaning ]
                ]
    in
    Html.details [ Internal.cls [ "klar-mdeditor__help" ] ]
        [ Html.summary [] [ Html.text (pick "Markdown støttes" "Markdown is supported") ]
        , Html.ul [ Internal.cls [ "klar-mdeditor__syntax-list" ] ]
            [ row "**bold**" (pick "fet" "bold")
            , row "*italic*" (pick "kursiv" "italic")
            , row "~~strike~~" (pick "gjennomstreket" "strikethrough")
            , row "`code`" (pick "kode i teksten" "code in a line")
            , row "[text](https://...)" (pick "lenke" "a link")
            , row "# Heading" (pick "overskrift, ## og ### er mindre" "a heading, ## and ### are smaller")
            , row "> quote" (pick "sitat" "a quote")
            , row "- item" (pick "punktliste" "a bulleted list")
            , row "1. item" (pick "nummerert liste" "a numbered list")
            , row "- [ ] task" (pick "oppgave, [x] er utført" "a task, [x] is done")
            , row "```" (pick "kodeblokk, avsluttes med ```" "a block of code, ends with ```")
            , row "| a | b |" (pick "tabell, med |---|---| på linjen under" "a table, with |---|---| on the line below")
            , row "---" (pick "skillelinje" "a dividing line")
            ]
        ]
