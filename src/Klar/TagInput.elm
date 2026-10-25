module Klar.TagInput exposing
    ( view, Attribute
    , State, Msg, init, update
    , values, setValues, draft, clear, isTouched
    , delimiters, maxTags, validate, keepDraftOnBlur
    , label, labelHidden, hint, error, errorMaybe, required, optionalText
    , placeholder, size, disabled, readOnly
    , locale
    )

{-| Free-form tags: type a word, press Enter or comma, get a chip.

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

@docs values, setValues, draft, clear, isTouched


# What counts as a tag

@docs delimiters, maxTags, validate, keepDraftOnBlur


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
import Json.Decode as Decode exposing (Decoder)
import Klar.Field as Field
import Klar.Icon as Icon
import Klar.Internal as Internal
import Klar.Internal.TextField as TextField
import Klar.Locale as Locale exposing (Locale)
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
    , settled : String
    , ended : Maybe ( String, Bool )
    , message : Maybe String
    , announcement : Announcement
    , touched : Bool
    , refocusing : Bool
    }


{-| What the hidden live region says next.
-}
type Announcement
    = Silent
    | Added (List String)
    | Removed String


{-| A field without tags. The `String` is the DOM id of the text input; it must
be unique on the page, because the label, hint and error point at it (and the
chips' remove buttons get ids made from it).
-}
init : String -> State
init id =
    State
        { id = id
        , tags = []
        , draft = ""
        , settled = ""
        , ended = Nothing
        , message = Nothing
        , announcement = Silent
        , touched = False
        , refocusing = False
        }


{-| The tags in the field, in the order they were added. Compare it before and
after `update` to react to a change.
-}
values : State -> List String
values (State state) =
    state.tags


{-| Replaces all tags, for example with the values from the server, and clears
the text being typed and any refusal message. The tags are taken as they are:
duplicates, `maxTags` and `validate` are not checked.
-}
setValues : List String -> State -> State
setValues tags (State state) =
    State { state | tags = tags, draft = "", settled = "", ended = Nothing, message = Nothing }


{-| The text being typed, not yet a tag. After a refusal it holds the refused
text, so that the user can correct it.
-}
draft : State -> String
draft (State state) =
    state.draft


{-| Removes all tags and the text being typed, and forgets that the user has
been in the field (`isTouched` is `False` again).
-}
clear : State -> State
clear (State state) =
    State { state | tags = [], draft = "", settled = "", ended = Nothing, message = Nothing, announcement = Silent, touched = False }


{-| `True` once the user has left the field. Use it to show errors only after
the first visit.
-}
isTouched : State -> Bool
isTouched (State state) =
    state.touched



-- UPDATE


{-| What `update` must know of the attributes of the view. Data only: the
`validate` of the application runs in the view, and its verdict comes in each
`Piece`.
-}
type alias Rules =
    { maxTags : Maybe Int
    , keepDraft : Bool
    , delimiters : List Char
    , joiner : String
    , lang : Locale
    }


{-| A piece of typed or pasted text (trimmed), with what `validate` said of it.
-}
type alias Piece =
    { text : String
    , problem : Maybe String
    }


{-| What an input event (or the end of a composition) found in the text input:
the whole text, and the pieces it becomes if it is split. For typing, the text
after the last delimiter is the `rest`, still being typed; a paste or a drop is
all pieces. `ending` is the end of a composition.
-}
type alias Change =
    { raw : String
    , pieces : List Piece
    , rest : String
    , ending : Bool
    }


type Toward
    = Back
    | Forward


{-| The messages a tag field sends: typing, pasting, Enter, Backspace, the
chips and their remove buttons, and leaving the field. `view` wraps them with
the function you give it; hand them to `update` when they come back. They hold
data only, so they can be compared and stored.
-}
type Msg
    = Changed Rules Change
    | Composed String
    | Entered Rules (List Piece)
    | Left Rules (List Piece)
    | RemoveAt Int
    | RemoveFocused Int Toward
    | RemoveLast
    | FocusChip Int
    | FocusInput
    | Refocused
    | Noop


{-| Moves the field on after one of its messages. The `Cmd` moves the keyboard
focus: to the text input after a click in the field or on a chip's remove
button, and between the chips when they are used with the keyboard. Pass it on
with `Cmd.map`.
-}
update : Msg -> State -> ( State, Cmd Msg )
update msg ((State state) as current) =
    case msg of
        Changed rules change ->
            if state.ended == Just ( change.raw, not change.ending ) then
                -- The input event that some browsers send next to the end of a
                -- composition (after it or before it), with the same text: it
                -- was handled once already.
                ( State { state | ended = Nothing }, Cmd.none )

            else
                let
                    next =
                        if delimiterCount rules.delimiters change.raw > delimiterCount rules.delimiters state.settled then
                            -- a delimiter was typed or pasted: split
                            absorb rules change.pieces change.rest state

                        else
                            -- Ordinary typing. The delimiters that were already
                            -- there (the refused text of a paste, kept to be
                            -- corrected) do not split the text again: Enter,
                            -- leaving the field or a new delimiter does.
                            { state | draft = change.raw, settled = change.raw, message = Nothing }
                in
                ( State
                    { next
                        | ended = Just ( change.raw, change.ending )
                        , refocusing = False
                    }
                , Cmd.none
                )

        Composed raw ->
            -- `settled` stays: the end of the composition is compared with the
            -- text from before it
            ( State { state | draft = raw, ended = Nothing, message = Nothing, refocusing = False }, Cmd.none )

        Entered rules pieces ->
            ( State (absorb rules pieces "" { state | ended = Nothing, refocusing = False }), Cmd.none )

        Left rules pieces ->
            let
                touched =
                    { state | touched = True, ended = Nothing }
            in
            if state.refocusing then
                -- The blur of a chip's button that was removed while it had the
                -- focus (Chrome sends one): the focus is being moved on purpose
                -- and stays in the field.
                ( State { state | refocusing = False }, Cmd.none )

            else if rules.keepDraft || List.isEmpty pieces then
                ( State touched, Cmd.none )

            else
                ( State (absorb rules pieces "" touched), Cmd.none )

        RemoveAt index ->
            case removeAt index state of
                Just after ->
                    ( State { after | refocusing = True }, Internal.focus state.id Refocused )

                Nothing ->
                    ( current, Cmd.none )

        RemoveFocused index toward ->
            case removeAt index state of
                Just after ->
                    let
                        left =
                            List.length after.tags

                        target =
                            case toward of
                                Back ->
                                    if index > 0 then
                                        Just (index - 1)

                                    else if left > 0 then
                                        Just 0

                                    else
                                        Nothing

                                Forward ->
                                    if index < left then
                                        Just index

                                    else
                                        Nothing
                    in
                    ( State { after | refocusing = True }
                    , case target of
                        Just next ->
                            Internal.focus (chipId state.id next) Refocused

                        Nothing ->
                            Internal.focus state.id Refocused
                    )

                Nothing ->
                    ( current, Cmd.none )

        RemoveLast ->
            case List.reverse state.tags of
                last :: rest ->
                    ( State { state | tags = List.reverse rest, message = Nothing, announcement = Removed last }, Cmd.none )

                [] ->
                    ( current, Cmd.none )

        FocusChip index ->
            ( current, Internal.focus (chipId state.id index) Noop )

        FocusInput ->
            ( current, Internal.focus state.id Noop )

        Refocused ->
            ( State { state | refocusing = False }, Cmd.none )

        Noop ->
            ( current, Cmd.none )


removeAt : Int -> Fields -> Maybe Fields
removeAt index state =
    List.drop index state.tags
        |> List.head
        |> Maybe.map
            (\removed ->
                { state
                    | tags = List.take index state.tags ++ List.drop (index + 1) state.tags
                    , message = Nothing
                    , announcement = Removed removed
                }
            )


{-| Adds the pieces that are not refused as tags. The refused ones stay in the
text, followed by `rest` (what is still being typed), so that the user can
correct them; the last refusal is the message.
-}
absorb : Rules -> List Piece -> String -> Fields -> Fields
absorb rules pieces rest state =
    let
        step piece ( fields, added, refused ) =
            case refusal rules fields piece of
                Just problem ->
                    ( { fields | message = Just problem }, added, refused ++ [ piece.text ] )

                Nothing ->
                    ( { fields | tags = fields.tags ++ [ piece.text ] }, added ++ [ piece.text ], refused )

        ( after, addedTags, refusedTexts ) =
            List.foldl step ( { state | message = Nothing }, [], [] ) pieces
    in
    let
        text =
            String.join rules.joiner
                (refusedTexts
                    ++ (if rest == "" then
                            []

                        else
                            [ rest ]
                       )
                )
    in
    { after
        | draft = text
        , settled = text
        , announcement =
            if List.isEmpty addedTags then
                after.announcement

            else
                Added addedTags
    }


{-| Why a piece cannot become a tag: a duplicate (ignoring case), over the
limit, or what `validate` said, in this order.
-}
refusal : Rules -> Fields -> Piece -> Maybe String
refusal rules state piece =
    if List.any (\existing -> String.toLower existing == String.toLower piece.text) state.tags then
        Just
            (Locale.pick rules.lang
                { nb = "«" ++ piece.text ++ "» er allerede lagt til"
                , en = "\"" ++ piece.text ++ "\" has already been added"
                }
            )

    else if reachedLimit rules.maxTags state.tags then
        let
            limit =
                Maybe.withDefault 0 rules.maxTags
        in
        Just
            (Locale.pick rules.lang
                { nb =
                    "Du kan bare legge til "
                        ++ String.fromInt limit
                        ++ (if limit == 1 then
                                " verdi"

                            else
                                " verdier"
                           )
                , en =
                    "You can only add "
                        ++ String.fromInt limit
                        ++ (if limit == 1 then
                                " value"

                            else
                                " values"
                           )
                }
            )

    else
        piece.problem


reachedLimit : Maybe Int -> List String -> Bool
reachedLimit maxCount existing =
    case maxCount of
        Just limit ->
            List.length existing >= limit

        Nothing ->
            False


{-| How many delimiters a text holds.
-}
delimiterCount : List Char -> String -> Int
delimiterCount separators text =
    String.foldl
        (\c n ->
            if isDelimiter separators c then
                n + 1

            else
                n
        )
        0
        text


chipId : String -> Int -> String
chipId id index =
    id ++ "-tag-" ++ String.fromInt index



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
    , keepDraft : Bool
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
        , keepDraft = False
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
input (and of the list of chips). Give every field a label, or hide it with
`labelHidden`.
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
`values` for an empty list yourself and show an `error`.
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


{-| At most this many tags. The field then shows a counter such as `3/8`. Once
the limit is reached the user can still type, but a new tag is refused with a
message ("You can only add 8 values" in English) and its text stays in the
field; so are the tags over the limit in a pasted list. Default: no limit.
-}
maxTags : Int -> Attribute msg
maxTags limit =
    Attribute (\config -> { config | maxTags = Just limit })


{-| The characters that end a tag when they are typed or pasted. Default
`[ ',' ]`; add `';'` to accept semicolons too. Enter always ends a tag, and a
pasted tab or line break always splits. With an empty list only Enter (and
leaving the field) adds tags, and a comma becomes part of the tag. The comma and
semicolon of Chinese and Japanese input (`，` `、` `；`) count as `,` and `;`.

    TagInput.delimiters [ ',', ';' ]

-}
delimiters : List Char -> Attribute msg
delimiters chars =
    Attribute (\config -> { config | delimiters = chars })


{-| A check that runs on each new tag (trimmed, and after the checks for
duplicates and `maxTags`). Return `Just message` to refuse the tag: the message
is shown under the field and the text of the tag stays in the field so that the
user can correct it. Return `Nothing` to accept the tag. Default: every tag is
accepted. The check runs in the view, so the messages of the field hold its
verdict and never the function.

    TagInput.validate (Validate.run Locale.en (Validate.maxLength 20))

-}
validate : (String -> Maybe String) -> Attribute msg
validate check =
    Attribute (\config -> { config | validate = check })


{-| Leaving the field keeps the text that is still being typed as text instead
of turning it into a tag. By default leaving the field adds it, as Enter does.
-}
keepDraftOnBlur : Attribute msg
keepDraftOnBlur =
    Attribute (\config -> { config | keepDraft = True })


{-| While `True` the field is dimmed, nothing can be typed, and the chips lose
their remove buttons. Default `False`.
-}
disabled : Bool -> Attribute msg
disabled value =
    Attribute (\config -> { config | disabled = value })


{-| While `True` the user can focus the field but not add or remove tags: the
chips lose their remove buttons, and Backspace removes nothing. Default `False`.
-}
readOnly : Bool -> Attribute msg
readOnly value =
    Attribute (\config -> { config | readOnly = value })


{-| The size of the field and of its chips: `Small`, `Medium` or `Large`, from
[Klar.Theme](Klar-Theme). The field is at least 26px, 32px or 40px high at the
default density (see `Klar.Theme` for the others), and grows when the chips
wrap onto more lines. Default `Medium`.
-}
size : Size -> Attribute msg
size value =
    Attribute (\config -> { config | size = value })


{-| The language of the built-in text: the refusal messages ("... has already
been added", "You can only add 8 values"), what screen readers are told ("...
added", "... removed", "2 values: red, blue") and the name of each remove button
("Remove ..."). Default `Locale.default`, which is English. Texts you pass in
yourself are shown as they are.
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
            { maxTags = config.maxTags
            , keepDraft = config.keepDraft
            , delimiters = config.delimiters
            , joiner =
                case config.delimiters of
                    first :: _ ->
                        String.fromChar first ++ " "

                    [] ->
                        " "
            , lang = config.locale
            }

        field =
            config.field
                |> Field.setId state.id
                |> Field.setError
                    (case state.message of
                        Just refusal_ ->
                            Just refusal_

                        Nothing ->
                            config.field.error
                    )

        inactive =
            config.disabled || config.readOnly

        count =
            List.length state.tags

        summaryId =
            state.id ++ "-values"

        chips =
            List.indexedMap
                (\index tag ->
                    ( "tag-" ++ String.fromInt index
                    , viewChip toMsg
                        { config = config, rules = rules, id = state.id, draft = state.draft, count = count, inactive = inactive }
                        index
                        tag
                    )
                )
                state.tags
    in
    -- stable: the field makes messages of its own while the user types
    Field.view field
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
                [ ( "tags"
                  , Keyed.node "div"
                        [ Internal.cls [ "klar-taginput__tags" ]
                        , Attr.attribute "role" "list"
                        , Internal.attrIf (field.label /= Nothing) (Attr.attribute "aria-labelledby" (Field.labelId field))
                        ]
                        chips
                  )
                , ( "input"
                  , Html.input
                        (TextField.controlAttributes field
                            { describedBy =
                                if count > 0 then
                                    [ summaryId ]

                                else
                                    []
                            , invalid = False
                            }
                            ++ [ Internal.cls [ "klar-taginput__input" ]
                               , Attr.type_ "text"
                               , Attr.value state.draft
                               , Attr.placeholder
                                    (if count == 0 then
                                        config.placeholder

                                     else
                                        ""
                                    )
                               , Attr.disabled config.disabled
                               , Attr.readonly config.readOnly
                               , Attr.attribute "autocomplete" "off"
                               ]
                            ++ (if inactive then
                                    []

                                else
                                    [ Events.on "input" (inputDecoder toMsg config rules)
                                    , Events.on "compositionend" (changeDecoder toMsg config rules True)
                                    , Events.on "blur" (leaving state.id (targetPieces config) |> Decode.map (\found -> toMsg (Left rules found)))
                                    , Events.preventDefaultOn "keydown" (keyDecoder toMsg config rules count)
                                    ]
                               )
                        )
                        []
                  )
                , ( "count"
                  , case config.maxTags of
                        Just limit ->
                            Html.span [ Internal.cls [ "klar-taginput__count", "klar-tabular" ], Attr.attribute "aria-hidden" "true" ]
                                [ Html.text (String.fromInt count ++ "/" ++ String.fromInt limit) ]

                        Nothing ->
                            Html.text ""
                  )
                ]
            , Html.span [ Internal.cls [ "klar-sr-only" ], Attr.id summaryId ]
                [ Html.text (summary config.locale config.maxTags state.tags) ]
            , Html.span
                [ Internal.cls [ "klar-sr-only" ]
                , Attr.attribute "role" "status"
                , Attr.attribute "aria-live" "polite"
                ]
                [ Html.text (spoken config.locale state.announcement) ]
            ]
        )


{-| One chip. Its remove button is not a Tab stop: the chips are reached with
the arrow keys from the text input, and the button is what takes the focus.
-}
viewChip :
    (Msg -> msg)
    -> { config : Config, rules : Rules, id : String, draft : String, count : Int, inactive : Bool }
    -> Int
    -> String
    -> Html msg
viewChip toMsg chip index tag =
    let
        removeLabel =
            Locale.pick chip.config.locale { nb = "Fjern ", en = "Remove " } ++ tag
    in
    Html.span
        [ Internal.cls [ "klar-tag", "klar-tag--" ++ Internal.sizeSuffix chip.config.size ]
        , Attr.attribute "role" "listitem"
        ]
        [ Html.span [ Internal.cls [ "klar-tag__label" ], Internal.attrIf (String.length tag > 18) (Attr.title tag) ] [ Html.text tag ]
        , if chip.inactive then
            Html.text ""

          else
            Html.button
                [ Internal.cls [ "klar-tag__remove" ]
                , Attr.type_ "button"
                , Attr.id (chipId chip.id index)
                , Attr.tabindex -1
                , Attr.attribute "aria-label" removeLabel
                , Attr.title removeLabel
                , Internal.onMouseDownPrevent (toMsg Noop)
                , Events.stopPropagationOn "click" (clickDecoder toMsg index)
                , Events.preventDefaultOn "keydown" (chipKeyDecoder toMsg index chip.count)

                -- leaving the field from a chip ends the field like leaving the text does
                , Events.on "blur"
                    (leaving chip.id (Decode.succeed (cutPieces chip.config chip.draft))
                        |> Decode.map (\found -> toMsg (Left chip.rules found))
                    )
                ]
                [ Icon.sized Icon.ExtraSmall Icon.close ]
        ]


{-| Succeeds only when the focus goes to something outside the field: moving
between the text input and the chips is not leaving it.
-}
leaving : String -> Decoder a -> Decoder a
leaving id decoder =
    Decode.oneOf [ Decode.at [ "relatedTarget", "id" ] Decode.string, Decode.succeed "" ]
        |> Decode.andThen
            (\next ->
                if next == id || String.startsWith (id ++ "-tag-") next then
                    Decode.fail "the focus stays in the field"

                else
                    decoder
            )


{-| A click with the mouse (`detail` 1 or more) removes the chip and puts the
cursor in the text input; one from Enter or Space on the focused button
(`detail` 0) keeps the focus on the chips.
-}
clickDecoder : (Msg -> msg) -> Int -> Decoder ( msg, Bool )
clickDecoder toMsg index =
    Decode.oneOf [ Decode.field "detail" Decode.int, Decode.succeed 0 ]
        |> Decode.map
            (\clicks ->
                if clicks > 0 then
                    ( toMsg (RemoveAt index), True )

                else
                    ( toMsg (RemoveFocused index Forward), True )
            )


chipKeyDecoder : (Msg -> msg) -> Int -> Int -> Decoder ( msg, Bool )
chipKeyDecoder toMsg index count =
    Internal.keyEvent
        |> Decode.andThen
            (\event ->
                if event.ctrl || event.meta || event.alt then
                    Decode.fail "modifier"

                else
                    case event.key of
                        "ArrowLeft" ->
                            Decode.succeed ( toMsg (FocusChip (Basics.max 0 (index - 1))), True )

                        "ArrowRight" ->
                            if index + 1 < count then
                                Decode.succeed ( toMsg (FocusChip (index + 1)), True )

                            else
                                Decode.succeed ( toMsg FocusInput, True )

                        "Home" ->
                            Decode.succeed ( toMsg (FocusChip 0), True )

                        "End" ->
                            Decode.succeed ( toMsg FocusInput, True )

                        "Escape" ->
                            Decode.succeed ( toMsg FocusInput, True )

                        "Backspace" ->
                            Decode.succeed ( toMsg (RemoveFocused index Back), True )

                        "Delete" ->
                            Decode.succeed ( toMsg (RemoveFocused index Forward), True )

                        _ ->
                            Decode.fail "unhandled key"
            )


{-| What screen readers hear when the text input gets focus: how many tags
there are, and which.
-}
summary : Locale -> Maybe Int -> List String -> String
summary lang maxCount tags =
    let
        count =
            List.length tags

        amount =
            case maxCount of
                Just limit ->
                    Locale.pick lang
                        { nb = String.fromInt count ++ " av " ++ String.fromInt limit ++ " verdier"
                        , en = String.fromInt count ++ " of " ++ String.fromInt limit ++ " values"
                        }

                Nothing ->
                    Locale.pick lang
                        { nb =
                            String.fromInt count
                                ++ (if count == 1 then
                                        " verdi"

                                    else
                                        " verdier"
                                   )
                        , en =
                            String.fromInt count
                                ++ (if count == 1 then
                                        " value"

                                    else
                                        " values"
                                   )
                        }
    in
    if count == 0 then
        ""

    else
        amount ++ ": " ++ String.join ", " tags


{-| The text of the hidden live region.
-}
spoken : Locale -> Announcement -> String
spoken lang announcement =
    case announcement of
        Added [ tag ] ->
            tag ++ Locale.pick lang { nb = " lagt til", en = " added" }

        Added tags ->
            String.fromInt (List.length tags) ++ Locale.pick lang { nb = " verdier lagt til", en = " values added" }

        Removed tag ->
            tag ++ Locale.pick lang { nb = " fjernet", en = " removed" }

        Silent ->
            ""



-- DECODERS


inputDecoder : (Msg -> msg) -> Config -> Rules -> Decoder msg
inputDecoder toMsg config rules =
    TextField.composing
        |> Decode.andThen
            (\isComposing ->
                if isComposing then
                    -- The text of an input method is not final: never split it.
                    -- Chrome sends no input event after the composition, so its
                    -- end (`compositionend`) is where a composed comma splits.
                    Decode.at [ "target", "value" ] Decode.string
                        |> Decode.map (\raw -> toMsg (Composed raw))

                else
                    changeDecoder toMsg config rules False
            )


{-| The text of the input, and the pieces it is cut into when it is split: all of
them for a paste or a drop, the ones before the last delimiter for typing.
`ending` is the end of a composition.
-}
changeDecoder : (Msg -> msg) -> Config -> Rules -> Bool -> Decoder msg
changeDecoder toMsg config rules ending =
    Decode.map2
        (\inputType raw ->
            if String.startsWith "insertFromPaste" inputType || inputType == "insertFromDrop" then
                toMsg (Changed rules { raw = raw, pieces = cutPieces config raw, rest = "", ending = ending })

            else
                let
                    parts =
                        splitParts config.delimiters raw

                    complete =
                        List.take (List.length parts - 1) parts

                    rest =
                        List.drop (List.length parts - 1) parts |> List.head |> Maybe.withDefault ""
                in
                toMsg
                    (Changed rules
                        { raw = raw
                        , pieces = List.filterMap (toPiece config) complete
                        , rest = String.trimLeft rest
                        , ending = ending
                        }
                    )
        )
        (Decode.oneOf [ Decode.field "inputType" Decode.string, Decode.succeed "" ])
        (Decode.at [ "target", "value" ] Decode.string)


{-| The pieces of the text in the input, at the moment of the event.
-}
targetPieces : Config -> Decoder (List Piece)
targetPieces config =
    Decode.at [ "target", "value" ] Decode.string
        |> Decode.map (cutPieces config)


keyDecoder : (Msg -> msg) -> Config -> Rules -> Int -> Decoder ( msg, Bool )
keyDecoder toMsg config rules count =
    Decode.map2 Tuple.pair TextField.composing Internal.keyEvent
        |> Decode.andThen
            (\( isComposing, event ) ->
                if isComposing then
                    -- Enter confirms the composed word; the arrows pick one
                    Decode.fail "composing"

                else if event.ctrl || event.meta || event.alt then
                    Decode.fail "modifier"

                else
                    case event.key of
                        "Enter" ->
                            -- Never submit the surrounding form from here.
                            targetPieces config
                                |> Decode.map (\found -> ( toMsg (Entered rules found), True ))

                        "Backspace" ->
                            Decode.map2 Tuple.pair
                                (Decode.at [ "target", "value" ] Decode.string)
                                (Decode.oneOf [ Decode.field "repeat" Decode.bool, Decode.succeed False ])
                                |> Decode.andThen
                                    (\( text, repeated ) ->
                                        if text /= "" || count == 0 then
                                            Decode.fail "ordinary backspace"

                                        else if repeated then
                                            -- only a fresh press: holding Backspace to delete
                                            -- the text must not go on to remove every tag
                                            Decode.succeed ( toMsg Noop, True )

                                        else
                                            Decode.succeed ( toMsg RemoveLast, True )
                                    )

                        "ArrowLeft" ->
                            Decode.map2 Tuple.pair
                                (Decode.at [ "target", "selectionStart" ] Decode.int)
                                (Decode.at [ "target", "selectionEnd" ] Decode.int)
                                |> Decode.andThen
                                    (\( start, end ) ->
                                        if count > 0 && start == 0 && end == 0 then
                                            Decode.succeed ( toMsg (FocusChip (count - 1)), True )

                                        else
                                            Decode.fail "the caret moves"
                                    )

                        _ ->
                            Decode.fail "unhandled key"
            )


{-| A text cut into pieces at the delimiters, each one trimmed and checked by
`validate`; empty pieces are left out.
-}
cutPieces : Config -> String -> List Piece
cutPieces config raw =
    List.filterMap (toPiece config) (splitParts config.delimiters raw)


toPiece : Config -> String -> Maybe Piece
toPiece config text =
    case String.trim text of
        "" ->
            Nothing

        trimmed ->
            Just { text = trimmed, problem = config.validate trimmed }


splitParts : List Char -> String -> List String
splitParts separators raw =
    raw
        |> String.map
            (\c ->
                if isDelimiter separators c then
                    '\n'

                else
                    c
            )
        |> String.split "\n"


{-| A delimiter of the field, the comma and semicolon of Chinese and Japanese
input counted as theirs, or a line break or tab, which always split.
-}
isDelimiter : List Char -> Char -> Bool
isDelimiter separators c =
    c == '\n' || c == '\u{000D}' || c == '\t' || List.member c separators || List.member (latinPunctuation c) separators


latinPunctuation : Char -> Char
latinPunctuation c =
    case c of
        '，' ->
            ','

        '、' ->
            ','

        '；' ->
            ';'

        _ ->
            c
