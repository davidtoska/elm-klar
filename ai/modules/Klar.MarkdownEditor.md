# Klar.MarkdownEditor

A text area for Markdown with a toolbar and a live preview: the editor of a note, a description, a comment, or the instruction to a language model.

Import: `import Klar.MarkdownEditor as MarkdownEditor` | Group: Text and change

Types: `Msg`, `State`, `Attribute`

## Signatures

```elm
-- View
view : (Msg -> msg) -> List (Attribute msg) -> State -> Html msg

-- State
type State  -- opaque: no constructors are exposed
type Msg  -- opaque: no constructors are exposed
init : String -> State
value : State -> String
setValue : String -> State -> State
focus : State -> Cmd Msg
update : Msg -> State -> ( State, Cmd Msg )

-- Label, hint and error
type Attribute msg  -- opaque: no constructors are exposed
label : String -> Attribute msg
labelHidden : Attribute msg
hint : String -> Attribute msg
error : String -> Attribute msg
errorMaybe : Maybe String -> Attribute msg
required : Attribute msg
optionalText : String -> Attribute msg

-- The text area
rows : Int -> Attribute msg
placeholder : String -> Attribute msg
maxLength : Int -> Attribute msg
disabled : Bool -> Attribute msg
readOnly : Bool -> Attribute msg
onFocus : msg -> Attribute msg
onBlur : msg -> Attribute msg

-- Layout and preview
tabbed : Attribute msg
sideBySide : Attribute msg
preview : List Markdown.Attribute -> Attribute msg
syntaxHelp : Attribute msg
locale : Locale.Locale -> Attribute msg
```

## Documentation

A text area for Markdown with a toolbar and a live preview: the editor of a
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
[Klar.Markdown](Klar.Markdown.md), so everything that is true there is true here: raw
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
the only keys the text area takes over; every other key is the browser's.

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

## View

### `view`

```elm
view : (Msg -> msg) -> List (Attribute msg) -> State -> Html msg
```

The editor: a label, a toolbar, the text area and the preview, a hint and an
error. The first argument wraps the editor's messages in your own type.

    MarkdownEditor.view DescriptionMsg [ MarkdownEditor.label "Description" ] model.description

## State

### `State`

```elm
type State  -- opaque: no constructors are exposed
```

What the editor remembers: the text, where its selection is, the parsed text for
the preview, the last changes of the buttons (for `Ctrl Z`) and which tab is shown
when the layout has tabs. Make one with `init`, keep it in your model and give it to
`view` and `update`.

### `Msg`

```elm
type Msg  -- opaque: no constructors are exposed
```

What happens in the editor: the text changes, the selection moves, a button or
a shortcut is used, a pause ends, a tab is chosen. Wrap it in a constructor of your
own message type, give that constructor to `view` and hand the messages you get back
to `update`.

### `init`

```elm
init : String -> State
```

An editor with no text. The `String` is the DOM id of the text area and the
prefix of the ids of the parts around it: it must be unique on the page.

    MarkdownEditor.init "order-description"

### `value`

```elm
value : State -> String
```

The text. This is what the user typed, with line breaks as `\n`.

### `setValue`

```elm
setValue : String -> State -> State
```

Replaces the text, for example with the one that was saved, or empty after a
save. The caret goes to the end, as in any text area, and the changes that `Ctrl Z`
could undo are forgotten. Line breaks written as `\r\n` or `\r` become `\n`, because a
text area cannot hold them.

### `focus`

```elm
focus : State -> Cmd Msg
```

Moves the keyboard focus to the text area, for example when a dialog with the
editor opens. When the editor has tabs and the Preview tab is shown, the Write tab
is shown first, because a text area that is not shown cannot take the focus. Map the
command with your message constructor.

### `update`

```elm
update : Msg -> State -> ( State, Cmd Msg )
```

Handles the messages of the editor. The `Cmd` gives the keyboard focus back to
the text area after a button, waits for the pause of a long text, and moves the focus
of the tabs, so map it with your message constructor.

## Label, hint and error

### `Attribute`

```elm
type Attribute msg  -- opaque: no constructors are exposed
```

A setting of the editor. Make them with the functions below and pass a list to
`view`; later attributes win over earlier ones.

### `label`

```elm
label : String -> Attribute msg
```

The label above the editor. Clicking it focuses the text area and screen readers
read it as the name of the text area. Give every editor a label, or hide it with
`labelHidden`.

### `labelHidden`

```elm
labelHidden : Attribute msg
```

Hides the `label` visually but keeps it for screen readers.

### `hint`

```elm
hint : String -> Attribute msg
```

Help text under the editor, for example what the text is for. Screen readers read
it together with the label.

### `error`

```elm
error : String -> Attribute msg
```

Shows an error message under the editor and marks it invalid. Screen readers
announce the message when it appears. An editor with a `maxLength` shows its own
error when the text is too long, unless you give one. To show an error only
sometimes, use `errorMaybe`.

### `errorMaybe`

```elm
errorMaybe : Maybe String -> Attribute msg
```

Like `error`, but takes a `Maybe`: `Just message` shows the message and `Nothing`
shows none.

### `required`

```elm
required : Attribute msg
```

Marks the field as required: an asterisk after the label and `aria-required` on
the text area. This checks nothing: look at the text yourself and show an `error`.

### `optionalText`

```elm
optionalText : String -> Attribute msg
```

Text such as `"(optional)"` after the label of a field that is not `required`.
By default nothing is shown.

## The text area

### `rows`

```elm
rows : Int -> Attribute msg
```

The height of the text area and of the preview, in lines of text. Default 12,
and never less than 3. The text scrolls inside the editor, so the page does not
change height as the text grows.

### `placeholder`

```elm
placeholder : String -> Attribute msg
```

Text shown in the empty text area, for example an example of what to write. It is
not a substitute for the `label`. Default: none.

### `maxLength`

```elm
maxLength : Int -> Attribute msg
```

Shows a counter such as `120/2000` under the editor at the end of the line with
the hint. It turns amber when the limit is near and red, with an error that says by
how many characters, when the text is longer. Nothing is cut off, and the user can
still type and paste: a limit that silently loses a pasted text is not honest.
Check the length before you save.

### `disabled`

```elm
disabled : Bool -> Attribute msg
```

While `True` the editor is dimmed and cannot be focused or changed. Default
`False`. The preview still shows the text.

### `readOnly`

```elm
readOnly : Bool -> Attribute msg
```

While `True` the user can focus the text, select it and read the preview, but
the text cannot be changed and the toolbar is off. Default `False`.

### `onFocus`

```elm
onFocus : msg -> Attribute msg
```

Sends this message when the text area gets the focus.

### `onBlur`

```elm
onBlur : msg -> Attribute msg
```

Sends this message when the text area loses the focus: a good moment to check
the text, so that an error does not appear while the user is still typing.

## Layout and preview

### `tabbed`

```elm
tabbed : Attribute msg
```

Always two tabs, "Write" and "Preview", also when the container is wide. Use it
for a narrow place that is not narrow enough for the editor to notice, or when you
want one thing at a time. Without it and without `sideBySide` the layout follows the
width of the container: tabs below 40em, side by side above.

### `sideBySide`

```elm
sideBySide : Attribute msg
```

Always the text area and the preview side by side, also in a narrow container.

### `preview`

```elm
preview : List Markdown.Attribute -> Attribute msg
```

Attributes for the preview, which is a [Klar.Markdown](Klar.Markdown.md) view:
`Markdown.images`, `Markdown.imagesFrom`, `Markdown.headingOffset` and the others.
The `locale` and the `idPrefix` of the preview are the editor's own, and a
`Markdown.locale` or `Markdown.idPrefix` in this list wins over them. Define the list
once (a constant) and the preview is not redrawn while the text waits for its pause.

    MarkdownEditor.preview [ Markdown.imagesFrom hosts ]

### `syntaxHelp`

```elm
syntaxHelp : Attribute msg
```

A line under the editor, "Markdown is supported", that opens a short list of the
syntax. Off by default.

### `locale`

```elm
locale : Locale.Locale -> Attribute msg
```

The language of the built-in text: the buttons, the tabs, the preview, the count
and the error of the limit. Default `Locale.default`, which is English. Texts you
give yourself are shown as they are.
