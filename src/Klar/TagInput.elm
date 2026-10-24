module Klar.TagInput exposing
    ( view, Attribute
    , State, Msg, init, update
    , tags, setTags, draft, clear, isTouched
    , delimiters, maxTags, validate, addOnBlur
    , label, labelHidden, hint, error, errorMaybe, required, optionalText
    , placeholder, size, disabled, readOnly
    , locale
    )

{-| Free-form tags: type a word, press Enter or comma, get a chip.

Use when: the user enters a list of free words, such as keywords or e-mail addresses.
Do not use when: the tags come from a fixed list (use `Klar.MultiSelect`).
Quick path: `init`, `update`, `view`, `tags`

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
    TagInput.tags model.keywords -- List String

The `String` given to `init` is the DOM id of the text input, so there is no
`id` attribute.

  - **Enter or comma** adds the text as a tag (also `;` if you ask for it with
    `delimiters`). The Enter key never submits a surrounding form.
  - **Backspace** in the empty field removes the last tag (a fresh press, so
    holding Backspace to delete the text stops at the tags); every chip also
    has a remove button.
  - **Pasting** `a, b, c` adds three tags. Tags are trimmed, and empty ones are
    ignored.
  - **Duplicates** (ignoring case) and tags that fail `validate` are refused
    with a message under the field; `maxTags` refuses the rest.
  - Leaving the field adds the text that is still being typed
    (`addOnBlur False` turns that off).
  - A click anywhere in the field puts the cursor in the text input.

Changes to the tags are read with `tags`; compare before and after `update` to
react. A hidden live region tells screen readers about added and removed tags.

`label`, `labelHidden`, `hint`, `error`, `errorMaybe`, `required` and
`optionalText` are the common field attributes. They come with the field
wrapper ([Klar.Field](Klar-Field)) that most Klar inputs are built on, so they
mean the same in all of them: the wrapper draws the label, the required marker,
the hint and the error message around the field and connects them for screen
readers (`for`, `aria-describedby`, `aria-invalid`, `aria-required`). The tag
field is always inside the wrapper, so the text input does not move, and keeps
the keyboard focus, when its own refusal messages come and go.

The built-in texts (the refusal messages, what screen readers are told, the
name of each remove button) follow `locale`.


# View

@docs view, Attribute


# State

@docs State, Msg, init, update


# Reading and setting the tags

@docs tags, setTags, draft, clear, isTouched


# What counts as a tag

@docs delimiters, maxTags, validate, addOnBlur


# Label, hint and error

@docs label, labelHidden, hint, error, errorMaybe, required, optionalText


# Appearance and behavior

@docs placeholder, size, disabled, readOnly


# Language

@docs locale

-}

import Html exposing (Html)
import Html.Attributes as Attr
import Html.Events as Events
import Html.Keyed as Keyed
import Json.Decode as Decode
import Klar.Field as Field
import Klar.Internal as Internal
import Klar.Locale as Locale exposing (Locale)
import Klar.Tag as Tag
import Klar.Theme as Theme exposing (Size(..))



-- STATE


{-| The state of a tag field: the tags, the text being typed and the latest
refusal message. Make one with `init`, keep it in your model and give it to
`view` and `update`.
-}
type State
    = State Fields


type alias Fields =
    { id : String
    , tags : List String
    , draft : String
    , message : Maybe String
    , announcement : Announcement
    , touched : Bool
    }


{-| What the hidden live region says next.
-}
type Announcement
    = Silent
    | Added String
    | Removed String


{-| A field without tags. The `String` is the DOM id of the text input; it must
be unique on the page, because the label, hint and error point at it.
-}
init : String -> State
init id =
    State { id = id, tags = [], draft = "", message = Nothing, announcement = Silent, touched = False }


{-| The tags in the field, in the order they were added. Compare it before and
after `update` to react to a change.
-}
tags : State -> List String
tags (State state) =
    state.tags


{-| Replaces all tags, for example with the values from the server, and clears
the text being typed and any refusal message. The tags are taken as they are:
duplicates, `maxTags` and `validate` are not checked.
-}
setTags : List String -> State -> State
setTags values (State state) =
    State { state | tags = values, draft = "", message = Nothing }


{-| The text being typed, not yet a tag.
-}
draft : State -> String
draft (State state) =
    state.draft


{-| Removes all tags and the text being typed, and forgets that the user has
been in the field (`isTouched` is `False` again).
-}
clear : State -> State
clear (State state) =
    State { state | tags = [], draft = "", message = Nothing, announcement = Silent, touched = False }


{-| `True` once the user has left the field. Use it to show errors only after
the first visit.
-}
isTouched : State -> Bool
isTouched (State state) =
    state.touched



-- UPDATE


type alias Rules =
    { delimiters : List Char
    , maxTags : Maybe Int
    , validate : String -> Maybe String
    , addOnBlur : Bool
    , lang : Locale
    }


type Origin
    = Typing
    | Pasting


{-| The messages a tag field sends: typing, pasting, Enter, Backspace, the
remove buttons and leaving the field. `view` wraps them with the function you
give it; hand them to `update` when they come back.
-}
type Msg
    = Changed Rules Origin String
    | Add Rules
    | RemoveAt Int
    | RemoveLast
    | Blurred Rules
    | FocusInput
    | Noop


{-| Moves the field on after one of its messages. The `Cmd` moves the focus to
the text input after a click in the field or on a chip's remove button, so pass
it on with `Cmd.map`.
-}
update : Msg -> State -> ( State, Cmd Msg )
update msg ((State state) as current) =
    case msg of
        Changed rules origin raw ->
            ( changed rules origin raw state, Cmd.none )

        Add rules ->
            ( State (addDraft rules state), Cmd.none )

        RemoveAt index ->
            case List.drop index state.tags |> List.head of
                Just removed ->
                    ( State
                        { state
                            | tags = List.take index state.tags ++ List.drop (index + 1) state.tags
                            , message = Nothing
                            , announcement = Removed removed
                        }
                    , Internal.focus state.id Noop
                    )

                Nothing ->
                    ( current, Cmd.none )

        RemoveLast ->
            case List.reverse state.tags of
                last :: rest ->
                    ( State { state | tags = List.reverse rest, message = Nothing, announcement = Removed last }, Cmd.none )

                [] ->
                    ( current, Cmd.none )

        Blurred rules ->
            let
                touched =
                    { state | touched = True }
            in
            if rules.addOnBlur && String.trim touched.draft /= "" then
                ( State (addDraft rules touched), Cmd.none )

            else
                ( State touched, Cmd.none )

        FocusInput ->
            ( current, Internal.focus state.id Noop )

        Noop ->
            ( current, Cmd.none )


changed : Rules -> Origin -> String -> Fields -> State
changed rules origin raw state =
    if List.any (\c -> String.contains (String.fromChar c) raw) rules.delimiters then
        let
            pieces =
                splitOnDelimiters rules.delimiters raw

            ( complete, remainder ) =
                case origin of
                    Pasting ->
                        ( pieces, "" )

                    Typing ->
                        ( List.take (List.length pieces - 1) pieces
                        , List.drop (List.length pieces - 1) pieces |> List.head |> Maybe.withDefault ""
                        )

            after =
                List.foldl (\piece fields -> addTag rules piece fields) { state | message = Nothing } complete
        in
        case ( origin, after.message ) of
            ( Typing, Just _ ) ->
                -- Keep a refused word in the field so it can be corrected.
                State
                    { after
                        | draft =
                            if remainder == "" then
                                complete |> List.reverse |> List.head |> Maybe.withDefault "" |> String.trim

                            else
                                remainder
                    }

            _ ->
                State { after | draft = remainder }

    else
        State { state | draft = raw, message = Nothing }


addDraft : Rules -> Fields -> Fields
addDraft rules state =
    let
        trimmed =
            String.trim state.draft
    in
    if trimmed == "" then
        { state | draft = "" }

    else
        let
            after =
                addTag rules trimmed { state | message = Nothing }
        in
        case after.message of
            Just _ ->
                after

            Nothing ->
                { after | draft = "" }


{-| Add one tag unless it is empty, a duplicate, over the limit or invalid.
A refusal sets the message.
-}
addTag : Rules -> String -> Fields -> Fields
addTag rules piece state =
    let
        tag =
            String.trim piece
    in
    if tag == "" then
        state

    else if List.any (\existing -> String.toLower existing == String.toLower tag) state.tags then
        { state
            | message =
                Just
                    (Locale.pick rules.lang
                        { nb = "«" ++ tag ++ "» er allerede lagt til"
                        , en = "\"" ++ tag ++ "\" has already been added"
                        }
                    )
        }

    else if reachedLimit rules state.tags then
        { state
            | message =
                Just
                    (Locale.pick rules.lang
                        { nb = "Du kan bare legge til " ++ String.fromInt (Maybe.withDefault 0 rules.maxTags) ++ " verdier"
                        , en = "You can only add " ++ String.fromInt (Maybe.withDefault 0 rules.maxTags) ++ " values"
                        }
                    )
        }

    else
        case rules.validate tag of
            Just problem ->
                { state | message = Just problem }

            Nothing ->
                { state
                    | tags = state.tags ++ [ tag ]
                    , announcement = Added tag
                }


reachedLimit : Rules -> List String -> Bool
reachedLimit rules existing =
    case rules.maxTags of
        Just limit ->
            List.length existing >= limit

        Nothing ->
            False


splitOnDelimiters : List Char -> String -> List String
splitOnDelimiters separators raw =
    raw
        |> String.map
            (\c ->
                if List.member c separators || c == '\n' || c == '\u{000D}' then
                    '\n'

                else
                    c
            )
        |> String.split "\n"



-- ATTRIBUTES


{-| A setting of a tag field. Make them with the functions below and pass a list
to `view`; later attributes win over earlier ones.
-}
type Attribute msg
    = Attribute (Config -> Config)


type alias Config =
    { field : Field.Config
    , placeholder : String
    , delimiters : List Char
    , maxTags : Maybe Int
    , validate : String -> Maybe String
    , addOnBlur : Bool
    , disabled : Bool
    , readOnly : Bool
    , size : Size
    , locale : Locale
    }


configure : List (Attribute msg) -> Config
configure attributes =
    List.foldl (\(Attribute change) config -> change config)
        { field = Field.empty
        , placeholder = ""
        , delimiters = [ ',' ]
        , maxTags = Nothing
        , validate = \_ -> Nothing
        , addOnBlur = True
        , disabled = False
        , readOnly = False
        , size = Medium
        , locale = Locale.default
        }
        attributes


updateField : (Field.Config -> Field.Config) -> Attribute msg
updateField change =
    Attribute (\config -> { config | field = change config.field })


{-| The label shown above the field. It is connected to the text input, so
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


{-| Help text shown under the field, for example the format you expect. Screen
readers read it together with the label (`aria-describedby`).
-}
hint : String -> Attribute msg
hint value =
    updateField (Field.setHint value)


{-| Shows an error message under the field and marks the field invalid (red
border, `aria-invalid`). Screen readers announce the message when it appears.
To show an error only sometimes, use `errorMaybe`. A refusal from the field
itself (a duplicate, a tag that fails `validate`, too many tags) is shown
instead until the next keystroke.
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
`aria-required` on the text input. This does not validate anything; check
`tags` for an empty list yourself and show an `error`.
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


{-| Text shown inside the field while there are no tags; it disappears when the
first tag is added. It is not a substitute for a `label`. Default: none.
-}
placeholder : String -> Attribute msg
placeholder value =
    Attribute (\config -> { config | placeholder = value })


{-| At most this many tags. The field then shows a counter such as `3/8`, and
when the limit is reached the text input becomes read-only. A tag over the limit,
for example from pasting a long list, is refused with a message ("You can only
add 8 values" in English). Default: no limit.
-}
maxTags : Int -> Attribute msg
maxTags limit =
    Attribute (\config -> { config | maxTags = Just limit })


{-| The characters that end a tag when they are typed or pasted. Default
`[ ',' ]`; add `';'` to accept semicolons too. Enter always ends a tag. With an
empty list only Enter (and leaving the field, see `addOnBlur`) adds tags, and a
comma becomes part of the tag.

    TagInput.delimiters [ ',', ';' ]

-}
delimiters : List Char -> Attribute msg
delimiters chars =
    Attribute (\config -> { config | delimiters = chars })


{-| A check that runs on each new tag (trimmed, and after the checks for
duplicates and `maxTags`). Return `Just message` to refuse the tag: the message
is shown under the field and a typed word stays in the field so that the user
can correct it. Return `Nothing` to accept the tag. Default: every tag is
accepted.

    TagInput.validate (Validate.run Locale.en (Validate.maxLength 20))

-}
validate : (String -> Maybe String) -> Attribute msg
validate check =
    Attribute (\config -> { config | validate = check })


{-| Whether leaving the field turns the text still being typed into a tag.
Default `True`.

    TagInput.addOnBlur False

-}
addOnBlur : Bool -> Attribute msg
addOnBlur value =
    Attribute (\config -> { config | addOnBlur = value })


{-| While `True` the field is dimmed, nothing can be typed, and the chips lose
their remove buttons. Default `False`.
-}
disabled : Bool -> Attribute msg
disabled value =
    Attribute (\config -> { config | disabled = value })


{-| While `True` the user can focus the field but not add or remove tags: the
chips lose their remove buttons. Default `False`.
-}
readOnly : Bool -> Attribute msg
readOnly value =
    Attribute (\config -> { config | readOnly = value })


{-| The size of the field and of its chips: `Small`, `Medium` or `Large`, from
[Klar.Theme](Klar-Theme). The field is at least 26px, 32px or 40px high, and
grows when the chips wrap onto more lines. Default `Medium`.
-}
size : Size -> Attribute msg
size value =
    Attribute (\config -> { config | size = value })


{-| The language of the built-in text: the refusal messages ("... has already
been added", "You can only add 8 values"), what screen readers are told when a
tag is added or removed ("... added", "... removed") and the name of each remove
button ("Remove ..."). Default `Locale.default`, which is English. Texts you pass
in yourself are shown as they are.
-}
locale : Locale -> Attribute msg
locale value =
    Attribute (\config -> { config | locale = value })



-- VIEW


{-| A tag field with its label, hint and error message. The first argument wraps
the field's own messages in one of yours, and the state comes last.

    TagInput.view KeywordsMsg
        [ TagInput.label "Keywords"
        , TagInput.delimiters [ ',', ';' ]
        ]
        model.keywords

-}
view : (Msg -> msg) -> List (Attribute msg) -> State -> Html msg
view toMsg attributes (State state) =
    let
        config =
            configure attributes

        rules =
            { delimiters = config.delimiters
            , maxTags = config.maxTags
            , validate = config.validate
            , addOnBlur = config.addOnBlur
            , lang = config.locale
            }

        field =
            config.field
                |> Field.setId state.id
                |> Field.setError
                    (case state.message of
                        Just refusal ->
                            Just refusal

                        Nothing ->
                            config.field.error
                    )

        inactive =
            config.disabled || config.readOnly

        atLimit =
            reachedLimit rules state.tags

        removeAttributes index =
            if inactive then
                []

            else
                [ Tag.onRemove (toMsg (RemoveAt index)) ]

        tagList =
            List.indexedMap
                (\index tag ->
                    ( "tag-" ++ String.fromInt index
                    , Tag.view
                        ([ Tag.size config.size, Tag.locale config.locale ] ++ removeAttributes index)
                        tag
                    )
                )
                state.tags
    in
    -- stable: the field makes messages of its own while the user types
    Field.viewStable field
        (Html.div [ Internal.cls [ "klar-taginput-wrap" ] ]
            [ -- The input comes after a list of chips that grows and shrinks.
              -- The chips sit in a wrapper of their own (`display: contents`,
              -- so the layout does not change), and the field keys its three
              -- parts: the input is then never moved when chips come and go.
              -- Moving it (which is what happened when several chips were
              -- added at once, by pasting "a, b, c") makes the browser drop
              -- keyboard focus; rebuilding it did the same after Enter, comma
              -- or Backspace before the chips were keyed.
              Keyed.node "div"
                ([ Internal.cls
                    [ "klar-input"
                    , "klar-input--" ++ Internal.sizeSuffix config.size
                    , "klar-taginput"
                    , if field.error /= Nothing then
                        "klar-input--invalid"

                      else
                        ""
                    , if config.disabled then
                        "klar-input--disabled"

                      else
                        ""
                    , if config.readOnly then
                        "klar-input--readonly"

                      else
                        ""
                    ]
                 ]
                    ++ (if inactive then
                            []

                        else
                            [ Events.onClick (toMsg FocusInput) ]
                       )
                )
                (( "tags", Keyed.node "div" [ Internal.cls [ "klar-taginput__tags" ] ] tagList )
                    :: [ ( "input"
                         , Html.input
                            (Field.controlAttributes field
                                ++ [ Internal.cls [ "klar-taginput__input" ]
                                   , Attr.type_ "text"
                                   , Attr.value state.draft
                                   , Attr.placeholder
                                        (if List.isEmpty state.tags then
                                            config.placeholder

                                         else
                                            ""
                                        )
                                   , Attr.disabled config.disabled
                                   , Attr.readonly (config.readOnly || atLimit)
                                   , Attr.attribute "autocomplete" "off"
                                   , Events.on "input" (inputDecoder toMsg rules)
                                   , Events.onBlur (toMsg (Blurred rules))
                                   , Events.preventDefaultOn "keydown" (keyDecoder toMsg rules (state.draft == "") (not (List.isEmpty state.tags)))
                                   ]
                            )
                            []
                         )
                       , ( "count"
                         , case config.maxTags of
                            Just limit ->
                                Html.span [ Internal.cls [ "klar-taginput__count", "klar-tabular" ] ]
                                    [ Html.text (String.fromInt (List.length state.tags) ++ "/" ++ String.fromInt limit) ]

                            Nothing ->
                                Html.text ""
                         )
                       ]
                )
            , Html.span
                [ Internal.cls [ "klar-sr-only" ]
                , Attr.attribute "role" "status"
                , Attr.attribute "aria-live" "polite"
                ]
                [ Html.text (spoken config.locale state.announcement) ]
            ]
        )


{-| The text of the hidden live region.
-}
spoken : Locale -> Announcement -> String
spoken lang announcement =
    case announcement of
        Added tag ->
            tag ++ Locale.pick lang { nb = " lagt til", en = " added" }

        Removed tag ->
            tag ++ Locale.pick lang { nb = " fjernet", en = " removed" }

        Silent ->
            ""


inputDecoder : (Msg -> msg) -> Rules -> Decode.Decoder msg
inputDecoder toMsg rules =
    Decode.map2
        (\origin raw -> toMsg (Changed rules origin raw))
        (Decode.oneOf
            [ Decode.field "inputType" Decode.string
                |> Decode.map
                    (\inputType ->
                        if String.startsWith "insertFromPaste" inputType || inputType == "insertFromDrop" then
                            Pasting

                        else
                            Typing
                    )
            , Decode.succeed Typing
            ]
        )
        (Decode.at [ "target", "value" ] Decode.string)


keyDecoder : (Msg -> msg) -> Rules -> Bool -> Bool -> Decode.Decoder ( msg, Bool )
keyDecoder toMsg rules draftIsEmpty hasTags =
    Internal.keyEvent
        |> Decode.andThen
            (\event ->
                if event.ctrl || event.meta || event.alt then
                    Decode.fail "modifier"

                else
                    case event.key of
                        "Enter" ->
                            -- Never submit the surrounding form from here.
                            Decode.succeed ( toMsg (Add rules), True )

                        "Backspace" ->
                            if draftIsEmpty && hasTags then
                                -- only a fresh press: holding Backspace to
                                -- delete the text must not go on to remove
                                -- every tag
                                Decode.oneOf [ Decode.field "repeat" Decode.bool, Decode.succeed False ]
                                    |> Decode.andThen
                                        (\repeated ->
                                            if repeated then
                                                Decode.succeed ( toMsg Noop, True )

                                            else
                                                Decode.succeed ( toMsg RemoveLast, True )
                                        )

                            else
                                Decode.fail "ordinary backspace"

                        _ ->
                            Decode.fail "unhandled key"
            )
