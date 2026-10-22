# Klar.PasswordInput

A password field with a "show password" button and an optional strength meter.

Import: `import Klar.PasswordInput as PasswordInput` | Group: Inputs

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
isRevealed : State -> Bool
reveal : State -> State
hide : State -> State

-- Value and events
value : String -> Attribute msg
onInput : (String -> msg) -> Attribute msg
onEnter : msg -> Attribute msg
onBlur : msg -> Attribute msg

-- Label, hint and error
label : String -> Attribute msg
labelHidden : Attribute msg
hint : String -> Attribute msg
error : String -> Attribute msg
errorMaybe : Maybe String -> Attribute msg
required : Attribute msg
optionalText : String -> Attribute msg

-- Password managers
currentPassword : Attribute msg
newPassword : Attribute msg
autocomplete : String -> Attribute msg

-- Strength
strengthMeter : Attribute msg
strength : String -> Int

-- Appearance and behavior
placeholder : String -> Attribute msg
size : Theme.Size -> Attribute msg
disabled : Bool -> Attribute msg
readOnly : Bool -> Attribute msg
name : String -> Attribute msg

-- Language
locale : Locale.Locale -> Attribute msg
```

## Documentation

A password field with a "show password" button and an optional strength
meter.

    import Klar.PasswordInput as PasswordInput

    type alias Model =
        { password : String
        , passwordField : PasswordInput.State
        }

    init : Model
    init =
        { password = ""
        , passwordField = PasswordInput.init "account-password"
        }

    -- update
    PasswordChanged text ->
        ( { model | password = text }, Cmd.none )

    PasswordMsg inner ->
        let
            ( passwordField, cmd ) =
                PasswordInput.update inner model.passwordField
        in
        ( { model | passwordField = passwordField }, Cmd.map PasswordMsg cmd )

    -- view
    PasswordInput.view PasswordMsg
        [ PasswordInput.label "New password"
        , PasswordInput.value model.password
        , PasswordInput.onInput PasswordChanged
        , PasswordInput.newPassword
        , PasswordInput.strengthMeter
        ]
        model.passwordField

The text itself is owned by the application, as in
[Klar.TextInput](Klar.TextInput.md); the state only remembers whether the password
is shown. The `String` given to `init` is the DOM id of the input, so there is
no `id` attribute.

`label`, `labelHidden`, `hint`, `error`, `errorMaybe`, `required` and
`optionalText` are the common field attributes. They come with the field
wrapper ([Klar.Field](Klar.Field.md)) that most Klar inputs are built on, so they
mean the same in all of them: the wrapper draws the label, the required marker,
the hint and the error message around the input and connects them for screen
readers (`for`, `aria-describedby`, `aria-invalid`, `aria-required`). An error
message is announced when it appears. The field is always inside the wrapper,
also when there is no `label`, `hint` or `error` to draw, so it stays where it is
(and keeps the keyboard focus) when the application shows an error while the user
is typing.

**Show and hide.** A button at the end of the field switches between dots and
plain text. Its name is "Show password" or "Hide password", and `aria-pressed`
says whether the password is shown. A mouse click on it leaves the keyboard
focus in the field, and a keyboard user stays on the button. The application can
do the same with `reveal` and `hide`. The field also switches off automatic
capital letters, autocorrect and spell checking.

**Password managers.** Use `currentPassword` on a login form and `newPassword`
when choosing one, so that password managers do the right thing.

**Strength.** `strengthMeter` shows four bars and a word under the field while
it has text, and screen readers are told the result ("Password strength:
Weak"). It is a rough guide (length, mix of characters, obvious patterns and the
most common passwords), not a security guarantee: the application should still
enforce its own rules, and can use `strength` for that. It counts the letters of
every script as letters, and it knows the common passwords of English and
Norwegian whatever the `locale`.

The built-in texts (the name of the button and the strength meter) follow
`locale`.

## View

### `Attribute`

```elm
type Attribute msg  -- opaque: no constructors are exposed
```

A setting of a password field. Make them with the functions below and pass a
list to `view`; later attributes win over earlier ones.

### `view`

```elm
view : (Msg -> msg) -> List (Attribute msg) -> State -> Html msg
```

A password field with its label, hint and error message, and a button that
shows or hides the password. The first argument wraps the field's own messages
in one of yours, and the state comes last.

    PasswordInput.view PasswordMsg
        [ PasswordInput.label "Password"
        , PasswordInput.currentPassword
        , PasswordInput.value model.password
        , PasswordInput.onInput PasswordChanged
        ]
        model.passwordField

## State

### `State`

```elm
type State  -- opaque: no constructors are exposed
```

The state of a password field. It only remembers whether the password is
shown; the text itself lives in your model. Make one with `init`, keep it in your
model and give it to `view` and `update`.

### `Msg`

```elm
type Msg  -- opaque: no constructors are exposed
```

The messages of the show/hide button. `view` wraps them with the function
you give it; hand them to `update` when they come back.

### `init`

```elm
init : String -> State
```

A field that hides the password. The `String` is the DOM id of the input; it
must be unique on the page, because the label, hint and error point at it.

### `update`

```elm
update : Msg -> State -> ( State, Cmd Msg )
```

Moves the field on after one of its messages: the button toggles whether the
password is shown. Call it from your own `update` and pass the `Cmd` on with
`Cmd.map`.

### `isRevealed`

```elm
isRevealed : State -> Bool
```

`True` while the password is shown as plain text.

### `reveal`

```elm
reveal : State -> State
```

Shows the password as plain text, as if the user had pressed the button.

### `hide`

```elm
hide : State -> State
```

Hides the password behind dots again, for example when a form is shown anew.

## Value and events

### `value`

```elm
value : String -> Attribute msg
```

The password, as your model has it. The input always shows exactly this
string, as dots or as plain text, so update it from `onInput`. Default: empty.

### `onInput`

```elm
onInput : (String -> msg) -> Attribute msg
```

Sends the new password each time the user changes the field, by typing or
pasting. The function gets the whole text. Store it in your model and pass it
back with `value`.

    PasswordInput.onInput PasswordChanged -- PasswordChanged : String -> Msg

### `onEnter`

```elm
onEnter : msg -> Attribute msg
```

Sends this message when the user presses Enter in the field (without Shift,
Ctrl, Alt or Cmd). The key press is cancelled, so it does not submit a
surrounding `form`; leave `onEnter` out to let Enter submit it.

### `onBlur`

```elm
onBlur : msg -> Attribute msg
```

Sends this message when the field loses focus. A good moment to validate, so
that an error does not appear while the user is still typing.

## Label, hint and error

### `label`

```elm
label : String -> Attribute msg
```

The label shown above the field. It is connected to the input, so clicking
it focuses the input and screen readers read it as the name of the input. Give
every field a label, or hide it with `labelHidden`.

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
To show an error only sometimes, use `errorMaybe`.

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
`aria-required` on the input. This does not validate anything; check the value
yourself and show an `error`.

### `optionalText`

```elm
optionalText : String -> Attribute msg
```

Text such as `"(optional)"` shown after the label of a field that is not
`required`. By default nothing is shown.

## Password managers

### `currentPassword`

```elm
currentPassword : Attribute msg
```

For a login form: the field holds the password the user already has
(`autocomplete="current-password"`), so password managers offer to fill it in.

### `newPassword`

```elm
newPassword : Attribute msg
```

For choosing a new password (`autocomplete="new-password"`): password
managers can suggest one, and browsers do not fill in the old one.

### `autocomplete`

```elm
autocomplete : String -> Attribute msg
```

The HTML `autocomplete` token. It tells the browser and password managers
what the field contains: `"current-password"`, `"new-password"` or
`"one-time-code"`. `currentPassword` and `newPassword` are shortcuts for the
first two. Default: none, so the browser decides.

## Strength

### `strengthMeter`

```elm
strengthMeter : Attribute msg
```

Shows four bars and a word ("Weak", "Fair", "Good" or "Strong") under the
field while it has text. Screen readers are told the result as a status
("Password strength: Weak"). The meter uses `strength`, which is a rough guide.

### `strength`

```elm
strength : String -> Int
```

A rough strength of a password, from 0 (empty) to 4. It looks at the length,
the kinds of characters (lowercase letters, uppercase letters, digits and
everything else) and a few obvious patterns, and it is what `strengthMeter`
shows.

  - 1 weak: shorter than 8 characters, only one kind of character, or an obvious
    pattern (`password123`, `abcdefgh`, `aaaaaaaa`)
  - 2 fair: at least 8 characters of two kinds
  - 3 good: at least 10 characters of three kinds
  - 4 strong: at least 16 characters of three kinds, or 12 of all four

It reads the password as Unicode text. A letter counts as a letter in any
script: `é`, `ü`, `ж` and `Ω` are lowercase or uppercase letters like `e` and
`E`, and the letters of a script without case (Chinese, Arabic, Hebrew ...) count
with the lowercase ones. Digits of other scripts are digits. Punctuation, signs
and emoji are the "everything else" kind, and a combining accent counts for
nothing on its own. The length is the number of characters, not of UTF-16 units,
so an emoji is one.

A password that contains one of the most common passwords (`password`, `qwerty`,
`letmein` ... and the usual Norwegian ones) is weak however long it is. The meter
has no locale, so the English and the Norwegian entries always count. The list is
short, as is every other pattern the meter knows: it is a guide for the user, not
a security check.

## Appearance and behavior

### `placeholder`

```elm
placeholder : String -> Attribute msg
```

Text shown inside the empty field. It is not a substitute for a `label`, and
it disappears as soon as the user types. Default: none.

### `size`

```elm
size : Theme.Size -> Attribute msg
```

The size of the field: `Small` (26px high), `Medium` (32px) or `Large`
(40px), from [Klar.Theme](Klar.Theme.md). Default `Medium`.

### `disabled`

```elm
disabled : Bool -> Attribute msg
```

While `True` the field and its show/hide button are dimmed and cannot be
focused or changed. Default `False`.

### `readOnly`

```elm
readOnly : Bool -> Attribute msg
```

While `True` the user can focus the field but not change it. The show/hide
button still works. Default `False`.

### `name`

```elm
name : String -> Attribute msg
```

The HTML `name` of the input. Browsers use it to fill in saved values, and a
native form sends the value under this name. Default: none.

## Language

### `locale`

```elm
locale : Locale.Locale -> Attribute msg
```

The language of the built-in text: the name of the show/hide button ("Show
password" and "Hide password") and the strength meter ("Password strength:" and
the words "Weak", "Fair", "Good" and "Strong"). Default `Locale.default`, which
is English. Texts you pass in yourself are shown as they are.
