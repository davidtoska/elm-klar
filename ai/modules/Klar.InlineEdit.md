# Klar.InlineEdit

Click-to-edit text.

Import: `import Klar.InlineEdit as InlineEdit` | Group: Inputs

Types: `Msg`, `State`, `Attribute`

## Signatures

```elm
-- View
type Attribute msg  -- opaque: no constructors are exposed
view : (Msg -> msg) -> List (Attribute msg) -> State -> Html msg

-- State
type State  -- opaque: no constructors are exposed
type Msg  -- opaque: no constructors are exposed
init : String -> String -> State
update : Msg -> State -> ( State, Cmd Msg )

-- Reading the state
value : State -> String
isEditing : State -> Bool
isSaving : State -> Bool
isFailed : State -> Bool
pending : State -> Maybe String

-- Saving and changing it from the application
saved : State -> State
failed : Remote.Problem -> State -> State
setValue : String -> State -> State
edit : State -> ( State, Cmd Msg )

-- Name and texts
ariaLabel : String -> Attribute msg
placeholder : String -> Attribute msg
emptyText : String -> Attribute msg

-- Rules
validate : (String -> Maybe String) -> Attribute msg
maxLength : Int -> Attribute msg

-- Behavior
disabled : Bool -> Attribute msg

-- Language
locale : Locale.Locale -> Attribute msg
```

## Documentation

Click-to-edit text. In reading mode it looks like text (with a pencil on
hover); a click turns it into an input.

Use when: a single text that is edited in place and saved at once, such as a customer name on a detail page.
Do not use when: the text is one field of a form that is saved with a button; use `Klar.TextInput`.
Quick path: `init`, `update`, `view`, `pending`, `saved`, `failed`

    import Klar.InlineEdit as InlineEdit
    import Klar.Locale as Locale
    import Klar.Validate as Validate

    type alias Model =
        { customerName : InlineEdit.State }

    init : Model
    init =
        { customerName = InlineEdit.init "customer-name" "Ada Lovelace" }

    -- update
    CustomerNameMsg inner ->
        let
            ( customerName, cmd ) =
                InlineEdit.update inner model.customerName

            startsSaving =
                InlineEdit.isSaving customerName
                    && not (InlineEdit.isSaving model.customerName)
        in
        ( { model | customerName = customerName }
        , Cmd.batch
            [ Cmd.map CustomerNameMsg cmd
            , case ( startsSaving, InlineEdit.pending customerName ) of
                ( True, Just text ) ->
                    saveCustomerName text

                _ ->
                    Cmd.none
            ]
        )

    CustomerNameSaved (Ok _) ->
        ( { model | customerName = InlineEdit.saved model.customerName }, Cmd.none )

    CustomerNameSaved (Err problem) ->
        -- problem : Klar.Remote.Problem
        ( { model | customerName = InlineEdit.failed problem model.customerName }, Cmd.none )

    -- view
    InlineEdit.view CustomerNameMsg
        [ InlineEdit.ariaLabel "Customer name"
        , InlineEdit.validate (Validate.run Locale.en Validate.required)
        ]
        model.customerName

The first `String` given to `init` is the DOM id of the input that is shown while
editing, so there is no `id` attribute; the second is the text to show.

**Keyboard.** Enter saves, Escape cancels, leaving the field saves, and the text
is a button: Tab reaches it and Space or Enter starts editing. The Enter or
Escape that ends an IME composition (Japanese, Chinese, Korean input) only picks
the characters. Escape is handled here and its default is prevented, so a
surrounding dialog that respects `defaultPrevented` stays open. Switching to
another window (Alt+Tab) does not count as leaving the field: the editor stays
open with the text, and nothing is saved.

**Saving.** When the user confirms a changed text, `isSaving` turns `True`: that
is the application's cue to send the new text (`pending`) to the backend. The
text keeps showing the new value with a spinner, and screen readers hear "Saving
..." and then "Saved". When the backend answers, call `saved` (the value is now
`pending`) or `failed` with a [Klar.Remote](Klar.Remote.md) `Problem`: the text is
then shown with the problem, a "Try again" button (which makes `isSaving` `True`
again; left out when `Remote.isRetryable` says the problem would fail the same
way, such as a conflict or a validation problem) and a "Cancel" button (which
goes back to the old value). A click on the text opens the editor again with the
refused text and the problem under it, so the user can correct it. Confirming
the text unchanged saves nothing. An answer that comes when no save is on its
way (a late one, after a `setValue` or a "Cancel") changes nothing.

**Validation.** `validate` is checked when the user confirms; a message keeps
the input open and is shown under it.

**The application's own changes.** `setValue` replaces the saved text. While the
user is editing, or a save is on its way, it never touches what they typed or
the save: the editor stays open with their text, and "Cancel" goes back to the
new value. This is the rule of every Klar input: what the user types wins.

**No field wrapper.** Unlike most inputs, this one is not built on the field
wrapper ([Klar.Field](Klar.Field.md)), so it has no visible label, hint, required
marker or `error` attribute. `ariaLabel` is the name screen readers hear, and the
message of `validate` is shown under the input.

The built-in texts (the buttons, "Click to add", "Saving ...") follow `locale`.

## View

### `Attribute`

```elm
type Attribute msg  -- opaque: no constructors are exposed
```

A setting of an inline edit. Make them with the functions below and pass a
list to `view`; later attributes win over earlier ones.

### `view`

```elm
view : (Msg -> msg) -> List (Attribute msg) -> State -> Html msg
```

The text, which turns into an input when the user clicks it. The first
argument wraps the field's own messages in one of yours, and the state comes
last.

    InlineEdit.view CustomerNameMsg
        [ InlineEdit.ariaLabel "Customer name"
        , InlineEdit.emptyText "No name yet"
        ]
        model.customerName

## State

### `State`

```elm
type State  -- opaque: no constructors are exposed
```

The state of an inline edit: the saved text, the text being edited, and
where the user is in the cycle of reading, editing, saving and failing. Make one
with `init`, keep it in your model and give it to `view` and `update`.

### `Msg`

```elm
type Msg  -- opaque: no constructors are exposed
```

The messages an inline edit sends: starting to edit, typing, confirming,
cancelling and the two buttons after a failure. `view` wraps them with the
function you give it; hand them to `update` when they come back.

### `init`

```elm
init : String -> String -> State
```

Starts in reading mode with the given text. The first `String` is the DOM id
of the input shown while editing; it must be unique on the page. The second is
the text to show.

    InlineEdit.init "customer-name" "Ada Lovelace"

### `update`

```elm
update : Msg -> State -> ( State, Cmd Msg )
```

Moves the field on after one of its messages. The `Cmd` moves the keyboard
focus (into the input when editing starts, back to the text when it ends), so
pass it on with `Cmd.map`. Compare `isSaving` before and after to find out when
to start a save.

## Reading the state

### `value`

```elm
value : State -> String
```

The saved text: the one the field started with, or the last one confirmed
with `saved` or put there with `setValue`. While the user is editing, or a save
is on its way, it is still the old text; see `pending`.

### `isEditing`

```elm
isEditing : State -> Bool
```

`True` while the input is open for editing.

### `isSaving`

```elm
isSaving : State -> Bool
```

`True` from the moment a changed text is confirmed until `saved` or
`failed` is called, and again after the user chooses "Try again". Start the
save when this turns `True`: compare it before and after `update`.

### `isFailed`

```elm
isFailed : State -> Bool
```

`True` after `failed` until the user chooses "Try again" or "Cancel", or
clicks the text to correct it. The text is shown with the problem and the
buttons.

### `pending`

```elm
pending : State -> Maybe String
```

The text waiting to be saved: the confirmed text while `isSaving`, and after
a failure until the user cancels or opens the editor again. Otherwise `Nothing`.

## Saving and changing it from the application

### `saved`

```elm
saved : State -> State
```

The save went well: the pending text is now the value, and the field is back
in reading mode. Call it when the backend answers. It does nothing when no save
is on its way, so a late answer cannot close an editor the user opened since.

### `failed`

```elm
failed : Remote.Problem -> State -> State
```

The save failed. The text is shown with "Could not save." and the `title` of
the problem, followed by its `detail` when you gave one with `Remote.withDetail`
(the server's message for this field), a "Try again" button (which makes
`isSaving` `True` again, but only when `Remote.isRetryable` allows it: not for a
conflict or a validation problem, which would fail the same way) and a "Cancel"
button that goes back to the old value. A click on the text opens the editor
with the refused text and the message under it. The `Problem` is from
[Klar.Remote](Klar.Remote.md); make one from your own error with `Remote.problem`.
It does nothing when no save is on its way, like `saved`.

    InlineEdit.failed (Remote.problem Remote.network) model.customerName

A refusal that names the field:

    InlineEdit.failed
        (Remote.problem Remote.validation |> Remote.withDetail "This domain is blocked.")
        model.website
    -- "Could not save. The form has errors: This domain is blocked."

### `setValue`

```elm
setValue : String -> State -> State
```

Replaces the saved text, for example after the record was loaded again. In
reading mode the new text is shown at once. While the user is editing, the text
they typed stays in the editor and only the saved text changes: "Cancel" and
Escape go back to the new one. (When they have not changed anything yet, the
editor shows the new text too, so an Enter does not save the old one over it.)
While a save is on its way or has failed, the save goes on: `saved` still makes
`pending` the value, and "Cancel" goes back to the new text.

### `edit`

```elm
edit : State -> ( State, Cmd Msg )
```

Opens the editor from the application, as a click on the text does: for a
keyboard shortcut such as F2 on the row, or an "Edit" item in a menu. The `Cmd`
moves the focus into the input, so pass it on with `Cmd.map`. It does nothing
while the editor is open or a save is on its way. Do not call it for a field
that is `disabled`: its editor would open inert.

    EditNameClicked ->
        let
            ( customerName, cmd ) =
                InlineEdit.edit model.customerName
        in
        ( { model | customerName = customerName }, Cmd.map CustomerNameMsg cmd )

## Name and texts

### `ariaLabel`

```elm
ariaLabel : String -> Attribute msg
```

What the text is about, such as `"Customer name"`, for screen readers only:
it is the accessible name of the input, and part of the name of the text button
("Edit Customer name: Ada Lovelace", in the case it was given). Give every inline
edit one; the visible label, when there is one, is yours (a `DescriptionList`
term, a heading).

### `placeholder`

```elm
placeholder : String -> Attribute msg
```

Text shown inside the input while editing, when the input is empty. Default:
none.

### `emptyText`

```elm
emptyText : String -> Attribute msg
```

Shown in gray in reading mode when the text is empty. Default "Click to add"
(see `locale`).

    InlineEdit.emptyText "No reference"

## Rules

### `validate`

```elm
validate : (String -> Maybe String) -> Attribute msg
```

Checked when the user confirms, with the text trimmed. Return `Just message`
to keep the input open and show the message under it (it goes away when the user
types again), or `Nothing` to go on and save. Default: every text is accepted.

    InlineEdit.validate
        (Validate.run Locale.en
            (Validate.all [ Validate.required, Validate.maxLength 60 ])
        )

### `maxLength`

```elm
maxLength : Int -> Attribute msg
```

Limits the text to this many characters (the HTML `maxlength` of the input).
There is no counter. Default: no limit.

## Behavior

### `disabled`

```elm
disabled : Bool -> Attribute msg
```

While `True` the text cannot be edited: no pencil, and a click does nothing.
It stays the same button, marked `aria-disabled` and out of the Tab order, so a
field that becomes disabled while it has the focus keeps it. Default `False`.

If the field becomes disabled while the input is open, the input stays on the
screen with the text typed so far, but it is inert. It is read-only, it is no
longer handled (leaving it, Enter, Escape and the two buttons do nothing), so
nothing is saved and nothing is cancelled. Editing goes on where it stopped when
the field is enabled again. The "Try again" and "Cancel" buttons after a failed
save are inactive as well while it is disabled.

## Language

### `locale`

```elm
locale : Locale.Locale -> Attribute msg
```

The language of the built-in text: "Click to add", the accessible name "Edit
...", the "Save" and "Cancel" buttons, "Saving ...", "Saved", "Could not save."
and "Try again". Default `Locale.default`, which is English. Texts you pass in
yourself are shown as they are.
