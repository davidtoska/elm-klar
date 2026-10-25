# Klar.TagInput

Free-form tags: type a word, press Enter or comma, get a chip.

Import: `import Klar.TagInput as TagInput` | Group: Inputs

Types: `Msg`, `State`, `Attribute`

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

-- Reading and setting the tags
values : State -> List String
setValues : List String -> State -> State
draft : State -> String
clear : State -> State
isTouched : State -> Bool

-- What counts as a tag
delimiters : List Char -> Attribute msg
maxTags : Int -> Attribute msg
validate : (String -> Maybe String) -> Attribute msg
keepDraftOnBlur : Attribute msg

-- Label, hint and error
label : String -> Attribute msg
labelHidden : Attribute msg
hint : String -> Attribute msg
error : String -> Attribute msg
errorMaybe : Maybe String -> Attribute msg
required : Attribute msg
optionalText : String -> Attribute msg

-- Appearance and behavior
placeholder : String -> Attribute msg
size : Theme.Size -> Attribute msg
disabled : Bool -> Attribute msg
readOnly : Bool -> Attribute msg

-- Language
locale : Locale.Locale -> Attribute msg
```

## Documentation

Free-form tags: type a word, press Enter or comma, get a chip.

Use when: the user enters a list of free words, such as keywords or e-mail addresses.
Do not use when: the tags come from a fixed list (use `Klar.MultiSelect`).
Quick path: `init`, `update`, `view`, `values`

    import Klar.Locale as Locale
    import Klar.TagInput as TagInput
    import Klar.Validate as Validate

    type alias Model =
        { keywords : TagInput.State }

    init : Model
    init =
        { keywords = TagInput.init "product-keywords" }

    -- update
    KeywordsMsg inner ->
        let
            ( keywords, cmd ) =
                TagInput.update inner model.keywords
        in
        ( { model | keywords = keywords }, Cmd.map KeywordsMsg cmd )

    -- view
    TagInput.view KeywordsMsg
        [ TagInput.label "Keywords"
        , TagInput.placeholder "Type a word and press Enter"
        , TagInput.maxTags 8
        , TagInput.validate (Validate.run Locale.en (Validate.maxLength 20))
        ]
        model.keywords

    -- read them
    TagInput.values model.keywords -- List String

The `String` given to `init` is the DOM id of the text input, so there is no
`id` attribute.

  - **Enter or comma** adds the text as a tag (also `;` if you ask for it with
    `delimiters`). The Enter key never submits a surrounding form. The comma and
    semicolon that an input method for Chinese or Japanese types (`，` `、`
    `；`) count as `,` and `;`, and the Enter that confirms a composed word adds
    nothing.
  - **Backspace** in the empty field removes the last tag (a fresh press, so
    holding Backspace to delete the text stops at the tags).
  - **The chips** are not Tab stops: Tab goes straight to the text input and on
    out of the field. Arrow left at the start of the text moves to the last
    chip; there, arrow left and right move between the chips, Home goes to the
    first, Backspace or Delete (or Enter or Space) removes the chip and keeps the
    focus on the chips, and arrow right past the last chip, End or Escape go back
    to the text. A click on a chip's × removes it and puts the cursor in the text.
  - **Pasting** `a, b, c` adds three tags; a tab between the pieces (a row copied
    from a spreadsheet) splits them too. Tags are trimmed, and empty ones are
    ignored.
  - **Duplicates** (ignoring case), tags that fail `validate` and tags over
    `maxTags` are refused with a message under the field, and their text stays in
    the field (all of it, also after a paste) so that it can be corrected and
    added with Enter. Typing in that text does not split it again at the commas
    it holds: Enter, leaving the field or a new comma does.
  - Leaving the field adds the text that is still being typed
    (`keepDraftOnBlur` keeps it as text instead).
  - A click anywhere in the field puts the cursor in the text input.

Changes to the tags are read with `values`; compare before and after `update` to
react. The chips are a list for screen readers, the text input tells how many
tags there are and which ("2 values: red, blue"), and a hidden live region tells
about added and removed tags.

`label`, `labelHidden`, `hint`, `error`, `errorMaybe`, `required` and
`optionalText` are the common field attributes. They come with the field
wrapper ([Klar.Field](Klar.Field.md)) that most Klar inputs are built on, so they
mean the same in all of them: the wrapper draws the label, the required marker,
the hint and the error message around the field and connects them for screen
readers (`for`, `aria-describedby`, `aria-invalid`, `aria-required`). The tag
field is always inside the wrapper, so the text input does not move, and keeps
the keyboard focus, when its own refusal messages come and go.

The built-in texts (the refusal messages, what screen readers are told, the
name of each remove button) follow `locale`.

## View

### `Attribute`

```elm
type Attribute msg  -- opaque: no constructors are exposed
```

A setting of a tag field. Make them with the functions below and pass a list
to `view`; later attributes win over earlier ones.

### `view`

```elm
view : (Msg -> msg) -> List (Attribute msg) -> State -> Html msg
```

A tag field with its label, hint and error message. The first argument wraps
the field's own messages in one of yours, and the state comes last.

    TagInput.view KeywordsMsg
        [ TagInput.label "Keywords"
        , TagInput.delimiters [ ',', ';' ]
        ]
        model.keywords

## State

### `State`

```elm
type State  -- opaque: no constructors are exposed
```

The state of a tag field: the tags, the text being typed and the latest
refusal message. Make one with `init`, keep it in your model and give it to
`view` and `update`.

### `Msg`

```elm
type Msg  -- opaque: no constructors are exposed
```

The messages a tag field sends: typing, pasting, Enter, Backspace, the
chips and their remove buttons, and leaving the field. `view` wraps them with
the function you give it; hand them to `update` when they come back. They hold
data only, so they can be compared and stored.

### `init`

```elm
init : String -> State
```

A field without tags. The `String` is the DOM id of the text input; it must
be unique on the page, because the label, hint and error point at it (and the
chips' remove buttons get ids made from it).

### `update`

```elm
update : Msg -> State -> ( State, Cmd Msg )
```

Moves the field on after one of its messages. The `Cmd` moves the keyboard
focus: to the text input after a click in the field or on a chip's remove
button, and between the chips when they are used with the keyboard. Pass it on
with `Cmd.map`.

## Reading and setting the tags

### `values`

```elm
values : State -> List String
```

The tags in the field, in the order they were added. Compare it before and
after `update` to react to a change.

### `setValues`

```elm
setValues : List String -> State -> State
```

Replaces all tags, for example with the values from the server, and clears
the text being typed and any refusal message. The tags are taken as they are:
duplicates, `maxTags` and `validate` are not checked.

### `draft`

```elm
draft : State -> String
```

The text being typed, not yet a tag. After a refusal it holds the refused
text, so that the user can correct it.

### `clear`

```elm
clear : State -> State
```

Removes all tags and the text being typed, and forgets that the user has
been in the field (`isTouched` is `False` again).

### `isTouched`

```elm
isTouched : State -> Bool
```

`True` once the user has left the field. Use it to show errors only after
the first visit.

## What counts as a tag

### `delimiters`

```elm
delimiters : List Char -> Attribute msg
```

The characters that end a tag when they are typed or pasted. Default
`[ ',' ]`; add `';'` to accept semicolons too. Enter always ends a tag, and a
pasted tab or line break always splits. With an empty list only Enter (and
leaving the field) adds tags, and a comma becomes part of the tag. The comma and
semicolon of Chinese and Japanese input (`，` `、` `；`) count as `,` and `;`.

    TagInput.delimiters [ ',', ';' ]

### `maxTags`

```elm
maxTags : Int -> Attribute msg
```

At most this many tags. The field then shows a counter such as `3/8`. Once
the limit is reached the user can still type, but a new tag is refused with a
message ("You can only add 8 values" in English) and its text stays in the
field; so are the tags over the limit in a pasted list. Default: no limit.

### `validate`

```elm
validate : (String -> Maybe String) -> Attribute msg
```

A check that runs on each new tag (trimmed, and after the checks for
duplicates and `maxTags`). Return `Just message` to refuse the tag: the message
is shown under the field and the text of the tag stays in the field so that the
user can correct it. Return `Nothing` to accept the tag. Default: every tag is
accepted. The check runs in the view, so the messages of the field hold its
verdict and never the function.

    TagInput.validate (Validate.run Locale.en (Validate.maxLength 20))

### `keepDraftOnBlur`

```elm
keepDraftOnBlur : Attribute msg
```

Leaving the field keeps the text that is still being typed as text instead
of turning it into a tag. By default leaving the field adds it, as Enter does.

## Label, hint and error

### `label`

```elm
label : String -> Attribute msg
```

The label shown above the field. It is connected to the text input, so
clicking it focuses the input and screen readers read it as the name of the
input (and of the list of chips). Give every field a label, or hide it with
`labelHidden`.

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

Help text shown under the field, for example the format you expect. Screen
readers read it together with the label (`aria-describedby`).

### `error`

```elm
error : String -> Attribute msg
```

Shows an error message under the field and marks the field invalid (red
border, `aria-invalid`). Screen readers announce the message when it appears.
To show an error only sometimes, use `errorMaybe`. A refusal from the field
itself (a duplicate, a tag that fails `validate`, too many tags) is shown
instead until the next keystroke.

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
`aria-required` on the text input. This does not validate anything; check
`values` for an empty list yourself and show an `error`.

### `optionalText`

```elm
optionalText : String -> Attribute msg
```

Text such as `"(optional)"` shown after the label of a field that is not
`required`. By default nothing is shown.

## Appearance and behavior

### `placeholder`

```elm
placeholder : String -> Attribute msg
```

Text shown inside the field while there are no tags; it disappears when the
first tag is added. It is not a substitute for a `label`. Default: none.

### `size`

```elm
size : Theme.Size -> Attribute msg
```

The size of the field and of its chips: `Small`, `Medium` or `Large`, from
[Klar.Theme](Klar.Theme.md). The field is at least 26px, 32px or 40px high at the
default density (see `Klar.Theme` for the others), and grows when the chips
wrap onto more lines. Default `Medium`.

### `disabled`

```elm
disabled : Bool -> Attribute msg
```

While `True` the field is dimmed, nothing can be typed, and the chips lose
their remove buttons. Default `False`.

### `readOnly`

```elm
readOnly : Bool -> Attribute msg
```

While `True` the user can focus the field but not add or remove tags: the
chips lose their remove buttons, and Backspace removes nothing. Default `False`.

## Language

### `locale`

```elm
locale : Locale.Locale -> Attribute msg
```

The language of the built-in text: the refusal messages ("... has already
been added", "You can only add 8 values"), what screen readers are told ("...
added", "... removed", "2 values: red, blue") and the name of each remove button
("Remove ..."). Default `Locale.default`, which is English. Texts you pass in
yourself are shown as they are.
