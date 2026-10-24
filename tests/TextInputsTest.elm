module TextInputsTest exposing (suite)

{-| The text fields: `TagInput` (messages that hold data only, chips that are no
Tab stops, input methods, refusals that keep their text), the counter that
`TextInput` and `TextArea` share (never cuts the text), the ids of unlabelled
fields, `SearchInput` (Escape, input methods, `remote`, `shortcut`),
`PasswordInput` (the value in the state, Caps Lock, the live regions) and
`NumberInput` (rounding as `Klar.Format` does, Norwegian `10.000`, Escape).

A test draws the component, finds a control the way a user would, simulates the
event, takes the message that the control sends and gives it to `update`.

-}

import Expect exposing (Expectation)
import Html exposing (Html)
import Html.Attributes as Attr
import Json.Encode as Encode exposing (Value)
import Klar.Locale as Locale
import Klar.NumberInput as NumberInput
import Klar.PasswordInput as PasswordInput
import Klar.Remote as Remote
import Klar.SearchInput as SearchInput
import Klar.Shortcut as Shortcut
import Klar.TagInput as TagInput
import Klar.TextArea as TextArea
import Klar.TextInput as TextInput
import Test exposing (Test, describe, test)
import Test.Html.Event as Event
import Test.Html.Query as Query
import Test.Html.Selector as Selector exposing (Selector)


type Msg
    = Tags TagInput.Msg
    | Search SearchInput.Msg
    | Password PasswordInput.Msg
    | Number NumberInput.Msg
    | Typed String
    | Entered


suite : Test
suite =
    describe "the text fields"
        [ tagInputTests
        , counterTests
        , idTests
        , textInputTests
        , textAreaTests
        , searchInputTests
        , passwordInputTests
        , numberInputTests
        ]



-- EVENTS


{-| A key press, with the fields the decoders read.
-}
key : List ( String, Value ) -> String -> ( String, Value )
key extra name =
    Event.custom "keydown"
        (Encode.object
            ([ ( "key", Encode.string name )
             , ( "ctrlKey", Encode.bool False )
             , ( "metaKey", Encode.bool False )
             , ( "shiftKey", Encode.bool False )
             , ( "altKey", Encode.bool False )
             ]
                ++ extra
            )
        )


{-| A key press in a text input that holds this text, with the caret at its end.
-}
keyIn : String -> String -> ( String, Value )
keyIn text name =
    key [ ( "target", target text (String.length text) ) ] name


target : String -> Int -> Value
target text caret =
    Encode.object
        [ ( "value", Encode.string text )
        , ( "selectionStart", Encode.int caret )
        , ( "selectionEnd", Encode.int caret )
        ]


composingKey : String -> ( String, Value )
composingKey name =
    key [ ( "isComposing", Encode.bool True ), ( "target", target "nihao" 5 ) ] name


inputEvent : List ( String, Value ) -> String -> ( String, Value )
inputEvent extra text =
    Event.custom "input" (Encode.object (( "target", Encode.object [ ( "value", Encode.string text ) ] ) :: extra))


paste : String -> ( String, Value )
paste text =
    inputEvent [ ( "inputType", Encode.string "insertFromPaste" ) ] text


composingInput : String -> ( String, Value )
composingInput text =
    inputEvent [ ( "isComposing", Encode.bool True ) ] text


blurWith : String -> String -> ( String, Value )
blurWith text next =
    Event.custom "blur"
        (Encode.object
            [ ( "target", Encode.object [ ( "value", Encode.string text ) ] )
            , ( "relatedTarget", Encode.object [ ( "id", Encode.string next ) ] )
            ]
        )


sends : List Selector -> ( String, Value ) -> Html Msg -> Result String Msg
sends selectors event html =
    html
        |> Query.fromHtml
        |> Query.find selectors
        |> Event.simulate event
        |> Event.toResult


sendsNothing : Result String Msg -> Expectation
sendsNothing result =
    case result of
        Err _ ->
            Expect.pass

        Ok _ ->
            Expect.fail "The element sent a message, but it should send none."


attr : String -> String -> Selector
attr name value =
    Selector.attribute (Attr.attribute name value)


has : List Selector -> List Selector -> Html Msg -> Expectation
has find selectors html =
    html |> Query.fromHtml |> Query.find find |> Query.has selectors


hasNot : List Selector -> List Selector -> Html Msg -> Expectation
hasNot find selectors html =
    html |> Query.fromHtml |> Query.find find |> Query.hasNot selectors


none : List Selector -> Html Msg -> Expectation
none find html =
    html |> Query.fromHtml |> Query.findAll find |> Query.count (Expect.equal 0)


count : Int -> List Selector -> Html Msg -> Expectation
count n find html =
    html |> Query.fromHtml |> Query.findAll find |> Query.count (Expect.equal n)


input : List Selector
input =
    [ Selector.tag "input" ]



-- TAG INPUT


type alias TagStep =
    TagInput.State -> Result String TagInput.State


tagEvent : List (TagInput.Attribute Msg) -> List Selector -> ( String, Value ) -> TagStep
tagEvent attributes selectors event state =
    TagInput.view Tags attributes state
        |> sends selectors event
        |> Result.andThen
            (\msg ->
                case msg of
                    Tags inner ->
                        Ok (Tuple.first (TagInput.update inner state))

                    _ ->
                        Err "not a message of the tag field"
            )


afterTags : List TagStep -> TagInput.State -> Result String TagInput.State
afterTags steps state =
    List.foldl (\step result -> Result.andThen step result) (Ok state) steps


expectTags : List String -> String -> Result String TagInput.State -> Expectation
expectTags tags text result =
    case result of
        Ok state ->
            Expect.equal ( tags, text ) ( TagInput.values state, TagInput.draft state )

        Err problem ->
            Expect.fail problem


tagField : TagInput.State
tagField =
    TagInput.init "tags"


withTags : List String -> TagInput.State
withTags tags =
    TagInput.setValues tags tagField


atLeastThree : TagInput.Attribute Msg
atLeastThree =
    TagInput.validate
        (\tag ->
            if String.length tag < 3 then
                Just "At least 3 characters"

            else
                Nothing
        )


removeButtons : List Selector
removeButtons =
    [ Selector.class "klar-tag__remove" ]


tagInputTests : Test
tagInputTests =
    describe "TagInput"
        [ test "a comma adds the word as a tag" <|
            \_ -> afterTags [ tagEvent [] input (inputEvent [] "red,") ] tagField |> expectTags [ "red" ] ""
        , test "its messages hold data only, so two of them can be compared" <|
            \_ ->
                let
                    once () =
                        TagInput.view Tags [ atLeastThree ] tagField |> sends input (paste "red, blue")
                in
                Expect.equal (once ()) (once ())
        , test "a refused word that was typed stays in the field, with the message" <|
            \_ ->
                Expect.all
                    [ expectTags [] "ab"
                    , \result ->
                        case result of
                            Ok state ->
                                has [ Selector.class "klar-field__error" ] [ Selector.text "At least 3 characters" ] (TagInput.view Tags [ atLeastThree ] state)

                            Err problem ->
                                Expect.fail problem
                    ]
                    (afterTags [ tagEvent [ atLeastThree ] input (inputEvent [] "ab,") ] tagField)
        , test "the refused pieces of a paste stay in the field" <|
            \_ ->
                afterTags [ tagEvent [ atLeastThree ] input (paste "red, xy, blue, z") ] tagField
                    |> expectTags [ "red", "blue" ] "xy, z"
        , test "a duplicate is refused, whatever its case, and its text stays" <|
            \_ -> afterTags [ tagEvent [] input (inputEvent [] "red,") ] (withTags [ "Red" ]) |> expectTags [ "Red" ] "red"
        , test "over the limit a tag is refused and kept as text, and the input stays editable" <|
            \_ ->
                Expect.all
                    [ \_ -> afterTags [ tagEvent [ TagInput.maxTags 1 ] input (inputEvent [] "b,") ] (withTags [ "a" ]) |> expectTags [ "a" ] "b"
                    , \_ -> hasNot input [ Selector.attribute (Attr.readonly True) ] (TagInput.view Tags [ TagInput.maxTags 1 ] (withTags [ "a" ]))
                    ]
                    ()
        , test "Enter adds the text" <|
            \_ -> afterTags [ tagEvent [] input (keyIn "red" "Enter") ] tagField |> expectTags [ "red" ] ""
        , test "Enter adds every piece of a text that holds commas" <|
            \_ -> afterTags [ tagEvent [] input (keyIn "red, blue" "Enter") ] tagField |> expectTags [ "red", "blue" ] ""
        , test "the Enter that confirms a composed word adds nothing" <|
            \_ -> TagInput.view Tags [] tagField |> sends input (composingKey "Enter") |> sendsNothing
        , test "text that is still being composed is never split" <|
            \_ -> afterTags [ tagEvent [] input (composingInput "a,b") ] tagField |> expectTags [] "a,b"
        , test "the comma of a Chinese or Japanese input method ends a tag" <|
            \_ -> afterTags [ tagEvent [] input (inputEvent [] "红，蓝、") ] tagField |> expectTags [ "红", "蓝" ] ""
        , test "a tab in a pasted row splits it" <|
            \_ -> afterTags [ tagEvent [] input (paste "red\tblue") ] tagField |> expectTags [ "red", "blue" ] ""
        , test "Backspace in the empty field removes the last tag" <|
            \_ -> afterTags [ tagEvent [] input (keyIn "" "Backspace") ] (withTags [ "a", "b" ]) |> expectTags [ "a" ] ""
        , test "a held Backspace does not go on to remove the tags" <|
            \_ ->
                afterTags [ tagEvent [] input (key [ ( "repeat", Encode.bool True ), ( "target", target "" 0 ) ] "Backspace") ] (withTags [ "a", "b" ])
                    |> expectTags [ "a", "b" ] ""
        , test "Backspace in a read-only field removes nothing" <|
            \_ -> TagInput.view Tags [ TagInput.readOnly True ] (withTags [ "a" ]) |> sends input (keyIn "" "Backspace") |> sendsNothing
        , test "the remove buttons are not Tab stops, and say what they remove" <|
            \_ ->
                TagInput.view Tags [] (withTags [ "red", "blue" ])
                    |> Expect.all
                        [ count 2 (removeButtons ++ [ Selector.attribute (Attr.tabindex -1) ])
                        , count 1 (removeButtons ++ [ attr "aria-label" "Remove red", Selector.id "tags-tag-0" ])
                        ]
        , test "the chips are a list named by the label" <|
            \_ ->
                TagInput.view Tags [ TagInput.label "Colors" ] (withTags [ "red", "blue" ])
                    |> Expect.all
                        [ has [ attr "role" "list" ] [ attr "aria-labelledby" "tags-label" ]
                        , count 2 [ attr "role" "listitem" ]
                        ]
        , test "the input tells how many tags there are, and which" <|
            \_ ->
                TagInput.view Tags [] (withTags [ "red", "blue" ])
                    |> Expect.all
                        [ has input [ attr "aria-describedby" "tags-values" ]
                        , has [ Selector.id "tags-values" ] [ Selector.text "2 values: red, blue" ]
                        ]
        , test "arrow left at the start of the text moves to the chips, elsewhere it moves the caret" <|
            \_ ->
                Expect.all
                    [ \_ -> TagInput.view Tags [] (withTags [ "a" ]) |> sends input (key [ ( "target", target "" 0 ) ] "ArrowLeft") |> Result.map (\_ -> ()) |> Expect.equal (Ok ())
                    , \_ -> TagInput.view Tags [] (withTags [ "a" ]) |> sends input (key [ ( "target", target "xy" 2 ) ] "ArrowLeft") |> sendsNothing
                    ]
                    ()
        , test "Delete on a chip removes it" <|
            \_ ->
                afterTags [ tagEvent [] [ Selector.id "tags-tag-0" ] (key [] "Delete") ] (withTags [ "a", "b" ])
                    |> expectTags [ "b" ] ""
        , test "Enter or Space on a chip (a click without a press) removes it, and a mouse click does too" <|
            \_ ->
                Expect.all
                    [ \_ -> afterTags [ tagEvent [] [ Selector.id "tags-tag-1" ] (Event.custom "click" (Encode.object [ ( "detail", Encode.int 0 ) ])) ] (withTags [ "a", "b" ]) |> expectTags [ "a" ] ""
                    , \_ -> afterTags [ tagEvent [] [ Selector.id "tags-tag-1" ] (Event.custom "click" (Encode.object [ ( "detail", Encode.int 1 ) ])) ] (withTags [ "a", "b" ]) |> expectTags [ "a" ] ""
                    ]
                    ()
        , test "leaving the field adds the text being typed" <|
            \_ -> afterTags [ tagEvent [] input (blurWith "red" "") ] tagField |> expectTags [ "red" ] ""
        , test "keepDraftOnBlur keeps the text, and the field is touched" <|
            \_ ->
                case afterTags [ tagEvent [ TagInput.keepDraftOnBlur ] input (blurWith "red" "") ] tagField of
                    Ok state ->
                        Expect.equal ( [], True ) ( TagInput.values state, TagInput.isTouched state )

                    Err problem ->
                        Expect.fail problem
        , test "moving from the text to a chip is not leaving the field" <|
            \_ -> TagInput.view Tags [] (withTags [ "a" ]) |> sends input (blurWith "red" "tags-tag-0") |> sendsNothing
        , test "the live region says what was added, in Norwegian too" <|
            \_ ->
                case afterTags [ tagEvent [ TagInput.locale Locale.nb ] input (paste "rød, blå") ] tagField of
                    Ok state ->
                        has [ attr "role" "status" ] [ Selector.text "2 verdier lagt til" ] (TagInput.view Tags [ TagInput.locale Locale.nb ] state)

                    Err problem ->
                        Expect.fail problem
        ]



-- THE COUNTER OF TEXTINPUT AND TEXTAREA


textOf : Int -> String
textOf n =
    String.repeat n "a"


counterTests : Test
counterTests =
    describe "the counter of TextInput and TextArea never cuts the text"
        [ test "a text input has no maxlength, so a paste is never cut" <|
            \_ -> none [ Selector.attribute (Attr.maxlength 20) ] (TextInput.view [ TextInput.id "x", TextInput.maxLength 20 ])
        , test "a text area has no maxlength either" <|
            \_ -> none [ Selector.attribute (Attr.maxlength 20) ] (TextArea.view [ TextArea.id "x", TextArea.maxLength 20 ])
        , test "the field is described by the count" <|
            \_ ->
                TextArea.view [ TextArea.id "note", TextArea.hint "h", TextArea.value (textOf 12), TextArea.maxLength 500 ]
                    |> Expect.all
                        [ has [ Selector.tag "textarea" ] [ attr "aria-describedby" "note-hint note-counter" ]
                        , has [ Selector.id "note-counter" ] [ Selector.text "12 of 500 characters" ]
                        ]
        , test "far from the limit the counter is plain and says nothing" <|
            \_ ->
                TextArea.view [ TextArea.id "x", TextArea.value (textOf 449), TextArea.maxLength 500 ]
                    |> Expect.all
                        [ hasNot [ Selector.class "klar-counter" ] [ Selector.class "klar-counter--near" ]
                        , has [ Selector.class "klar-counter" ] [ Selector.containing [ attr "role" "status" ] ]
                        , none [ attr "role" "status", Selector.containing [ Selector.text "limit" ] ]
                        ]
        , test "near the limit it turns amber and says so once" <|
            \_ ->
                TextArea.view [ TextArea.id "x", TextArea.value (textOf 450), TextArea.maxLength 500 ]
                    |> Expect.all
                        [ has [ Selector.class "klar-counter" ] [ Selector.class "klar-counter--near" ]
                        , has [ Selector.class "klar-counter", Selector.containing [ attr "role" "status" ] ] [ Selector.text "Almost at the limit of 500 characters" ]
                        ]
        , test "the spoken text does not change on every keystroke near the limit" <|
            \_ ->
                let
                    spoken n =
                        TextArea.view [ TextArea.id "x", TextArea.value (textOf n), TextArea.maxLength 500 ]
                            |> Query.fromHtml
                            |> Query.find [ attr "role" "status" ]
                            |> Query.has [ Selector.text "Almost at the limit of 500 characters" ]
                in
                Expect.all [ \_ -> spoken 460, \_ -> spoken 490, \_ -> spoken 499 ] ()
        , test "at the limit it says so" <|
            \_ ->
                has [ attr "role" "status" ]
                    [ Selector.text "Limit of 20 characters reached" ]
                    (TextInput.view [ TextInput.id "x", TextInput.value (textOf 20), TextInput.maxLength 20 ])
        , test "past the limit the text stays, the counter and the field are red and invalid" <|
            \_ ->
                TextInput.view [ TextInput.id "x", TextInput.value (textOf 25), TextInput.maxLength 20 ]
                    |> Expect.all
                        [ has input [ Selector.attribute (Attr.value (textOf 25)), attr "aria-invalid" "true" ]
                        , has [ Selector.class "klar-input" ] [ Selector.class "klar-input--invalid" ]
                        , has [ Selector.class "klar-counter" ] [ Selector.class "klar-counter--over", Selector.text "25/20" ]
                        , has [ Selector.id "x-counter" ] [ Selector.text "25 of 20 characters, 5 too many" ]
                        , has [ attr "role" "status" ] [ Selector.text "Over the limit of 20 characters" ]
                        ]
        , test "the texts are in Norwegian too" <|
            \_ ->
                TextArea.view [ TextArea.id "x", TextArea.value (textOf 25), TextArea.maxLength 20, TextArea.locale Locale.nb ]
                    |> Expect.all
                        [ has [ Selector.id "x-counter" ] [ Selector.text "25 av 20 tegn, 5 for mange" ]
                        , has [ attr "role" "status" ] [ Selector.text "Over grensen på 20 tegn" ]
                        ]
        ]



-- IDS


idTests : Test
idTests =
    describe "the ids of fields without an id"
        [ test "two fields without a label get different ids from what they show" <|
            \_ ->
                Expect.all
                    [ \_ -> has input [ Selector.id "klar-input-order-number" ] (TextInput.view [ TextInput.placeholder "Order number" ])
                    , \_ -> has input [ Selector.id "klar-input-sku" ] (TextInput.view [ TextInput.name "sku" ])
                    ]
                    ()
        , test "a field with nothing to make an id from gets no id, never a shared one" <|
            \_ ->
                Expect.all
                    [ hasNot input [ Selector.id "klar-input-field" ]
                    , hasNot input [ Selector.id "klar-input-" ]
                    , hasNot input [ Selector.attribute (Attr.id "") ]
                    ]
                    (TextInput.view [ TextInput.value "x" ])
        , test "a text area without a label takes its id from the placeholder" <|
            \_ -> has [ Selector.tag "textarea" ] [ Selector.id "klar-textarea-a-note" ] (TextArea.view [ TextArea.placeholder "A note" ])
        ]



-- TEXT INPUT


textInputTests : Test
textInputTests =
    describe "TextInput"
        [ test "Enter sends onEnter" <|
            \_ -> TextInput.view [ TextInput.id "x", TextInput.onEnter Entered ] |> sends input (keyIn "" "Enter") |> Expect.equal (Ok Entered)
        , test "the Enter that confirms a composed word sends nothing" <|
            \_ -> TextInput.view [ TextInput.id "x", TextInput.onEnter Entered ] |> sends input (composingKey "Enter") |> sendsNothing
        , test "Shift+Enter sends nothing" <|
            \_ -> TextInput.view [ TextInput.id "x", TextInput.onEnter Entered ] |> sends input (key [ ( "shiftKey", Encode.bool True ) ] "Enter") |> sendsNothing
        , test "verbatim switches off spell checking, capitals and autocorrect" <|
            \_ ->
                has input
                    [ attr "spellcheck" "false", attr "autocapitalize" "off", attr "autocorrect" "off" ]
                    (TextInput.view [ TextInput.id "sku", TextInput.verbatim ])
        ]



-- TEXT AREA


textAreaTests : Test
textAreaTests =
    describe "TextArea"
        [ test "Ctrl+Enter sends onCtrlEnter" <|
            \_ ->
                TextArea.view [ TextArea.id "x", TextArea.onCtrlEnter Entered ]
                    |> sends [ Selector.tag "textarea" ] (key [ ( "ctrlKey", Encode.bool True ) ] "Enter")
                    |> Expect.equal (Ok Entered)
        , test "Cmd+Enter does too" <|
            \_ ->
                TextArea.view [ TextArea.id "x", TextArea.onCtrlEnter Entered ]
                    |> sends [ Selector.tag "textarea" ] (key [ ( "metaKey", Encode.bool True ) ] "Enter")
                    |> Expect.equal (Ok Entered)
        , test "a plain Enter is a new line" <|
            \_ -> TextArea.view [ TextArea.id "x", TextArea.onCtrlEnter Entered ] |> sends [ Selector.tag "textarea" ] (key [] "Enter") |> sendsNothing
        , test "a fixed height can be dragged, unless noResize; a growing one never" <|
            \_ ->
                Expect.all
                    [ \_ -> has [ Selector.class "klar-textarea" ] [ Selector.class "klar-textarea--resize-vertical" ] (TextArea.view [ TextArea.id "a" ])
                    , \_ -> has [ Selector.class "klar-textarea" ] [ Selector.class "klar-textarea--resize-none" ] (TextArea.view [ TextArea.id "a", TextArea.noResize ])
                    , \_ -> has [ Selector.class "klar-textarea" ] [ Selector.class "klar-textarea--resize-none" ] (TextArea.view [ TextArea.id "a", TextArea.minRows 2 ])
                    ]
                    ()
        ]



-- SEARCH INPUT


searchStep : List (SearchInput.Attribute Msg) -> ( String, Value ) -> SearchInput.State -> Result String SearchInput.State
searchStep attributes event state =
    SearchInput.view Search attributes state
        |> sends input event
        |> Result.andThen
            (\msg ->
                case msg of
                    Search inner ->
                        Ok (Tuple.first (SearchInput.update inner state))

                    _ ->
                        Err "not a message of the search field"
            )


searchField : SearchInput.State
searchField =
    SearchInput.init "search"


searchInputTests : Test
searchInputTests =
    describe "SearchInput"
        [ test "Escape in a field with text clears it" <|
            \_ ->
                searchStep [] (key [] "Escape") (SearchInput.setText "fjord" searchField)
                    |> Result.map SearchInput.text
                    |> Expect.equal (Ok "")
        , test "Escape in an empty field is left alone, so that a dialog can close" <|
            \_ -> SearchInput.view Search [] searchField |> sends input (key [] "Escape") |> sendsNothing
        , test "the Enter that confirms a composed word commits nothing" <|
            \_ -> SearchInput.view Search [] (SearchInput.setText "a" searchField) |> sends input (composingKey "Enter") |> sendsNothing
        , test "text that is being composed is not committed, even without a delay" <|
            \_ ->
                searchStep [ SearchInput.debounce 0 ] (composingInput "nihao") searchField
                    |> Result.map (\state -> ( SearchInput.text state, SearchInput.committed state ))
                    |> Expect.equal (Ok ( "nihao", "" ))
        , test "without a delay every keystroke commits" <|
            \_ ->
                searchStep [ SearchInput.debounce 0 ] (inputEvent [] "fjord") searchField
                    |> Result.map SearchInput.committed
                    |> Expect.equal (Ok "fjord")
        , test "a space at the end starts no new search" <|
            \_ ->
                searchStep [ SearchInput.debounce 0 ] (inputEvent [] "fjord ") (SearchInput.setText "fjord" searchField)
                    |> Result.map (\state -> ( SearchInput.committed state, SearchInput.isPending state ))
                    |> Expect.equal (Ok ( "fjord", False ))
        , test "Enter commits at once" <|
            \_ ->
                searchStep [] (inputEvent [] "fjord") searchField
                    |> Result.andThen (searchStep [] (key [] "Enter"))
                    |> Result.map SearchInput.committed
                    |> Expect.equal (Ok "fjord")
        , test "while the remote loads or refreshes there is a spinner, and the status says so" <|
            \_ ->
                Expect.all
                    [ \_ -> has [ attr "role" "status" ] [ Selector.text "Searching ..." ] (SearchInput.view Search [ SearchInput.remote Remote.Loading ] searchField)
                    , \_ -> has [ Selector.class "klar-search" ] [ Selector.containing [ Selector.class "klar-search__spinner" ] ] (SearchInput.view Search [ SearchInput.remote Remote.Loading ] searchField)
                    , \_ -> none [ Selector.class "klar-search__spinner" ] (SearchInput.view Search [ SearchInput.remote (Remote.Loaded [ 1 ]) ] searchField)
                    ]
                    ()
        , test "the status is there before anything is loading, so that its first text is read" <|
            \_ -> count 1 [ attr "role" "status" ] (SearchInput.view Search [ SearchInput.remote Remote.NotAsked ] searchField)
        , test "the shortcut is drawn from the keys the application binds" <|
            \_ ->
                SearchInput.view Search [ SearchInput.shortcut (Shortcut.mod (Shortcut.char 'k')) ] searchField
                    |> Expect.all
                        [ has [ Selector.class "klar-search__keys" ] [ Selector.containing [ Selector.tag "kbd", Selector.text "Ctrl" ] ]
                        , has [ Selector.class "klar-search__keys" ] [ attr "aria-hidden" "true" ]
                        ]
        ]



-- PASSWORD INPUT


passwordStep : List Selector -> ( String, Value ) -> PasswordInput.State -> Result String PasswordInput.State
passwordStep selectors event state =
    PasswordInput.view Password [ PasswordInput.strengthMeter ] state
        |> sends selectors event
        |> Result.andThen
            (\msg ->
                case msg of
                    Password inner ->
                        Ok (Tuple.first (PasswordInput.update inner state))

                    _ ->
                        Err "not a message of the password field"
            )


passwordField : PasswordInput.State
passwordField =
    PasswordInput.init "pw"


toggleButton : List Selector
toggleButton =
    [ Selector.class "klar-password__toggle" ]


passwordInputTests : Test
passwordInputTests =
    describe "PasswordInput"
        [ test "what is typed is in the state" <|
            \_ -> passwordStep input (inputEvent [] "secret") passwordField |> Result.map PasswordInput.value |> Expect.equal (Ok "secret")
        , test "the button says what it does, has no aria-pressed, and the change is announced" <|
            \_ ->
                case passwordStep toggleButton Event.click passwordField of
                    Ok state ->
                        PasswordInput.view Password [] state
                            |> Expect.all
                                [ has toggleButton [ attr "aria-label" "Hide password" ]
                                , hasNot toggleButton [ attr "aria-pressed" "true" ]
                                , has [ attr "role" "status", Selector.containing [ Selector.text "Password shown" ] ] []
                                ]

                    Err problem ->
                        Expect.fail problem
        , test "a capital without Shift shows the Caps Lock warning, a small letter takes it away" <|
            \_ ->
                let
                    warned state =
                        PasswordInput.view Password [] state
                            |> Query.fromHtml
                            |> Query.findAll [ Selector.class "klar-password__caps" ]
                            |> Query.count (Expect.equal 1)
                in
                Expect.all
                    [ \_ -> passwordStep input (key [] "A") passwordField |> Result.map warned |> Result.withDefault (Expect.fail "no message")
                    , \_ ->
                        passwordStep input (key [] "A") passwordField
                            |> Result.andThen (passwordStep input (key [] "a"))
                            |> Result.map (\state -> none [ Selector.class "klar-password__caps" ] (PasswordInput.view Password [] state))
                            |> Result.withDefault (Expect.fail "no message")
                    ]
                    ()
        , test "a capital with Shift is no sign of Caps Lock" <|
            \_ -> PasswordInput.view Password [] passwordField |> sends input (key [ ( "shiftKey", Encode.bool True ) ] "A") |> sendsNothing
        , test "the strength is a status that is there before the first letter" <|
            \_ ->
                PasswordInput.view Password [ PasswordInput.strengthMeter ] passwordField
                    |> has [ Selector.id "pw-strength" ] [ attr "role" "status" ]
        , test "with text, the field is described by its strength" <|
            \_ ->
                PasswordInput.view Password [ PasswordInput.strengthMeter ] (PasswordInput.setValue "correcthorsebatterystaple" passwordField)
                    |> Expect.all
                        [ has input [ attr "aria-describedby" "pw-strength" ]
                        , has [ Selector.id "pw-strength" ] [ Selector.text "Password strength: Strong" ]
                        ]
        , test "clear empties the field and hides the password" <|
            \_ ->
                PasswordInput.clear (PasswordInput.reveal (PasswordInput.setValue "x" passwordField))
                    |> (\state -> ( PasswordInput.value state, PasswordInput.isRevealed state ))
                    |> Expect.equal ( "", False )
        ]



-- NUMBER INPUT


numberStep : List (NumberInput.Attribute Msg) -> ( String, Value ) -> NumberInput.State -> Result String NumberInput.State
numberStep attributes event state =
    NumberInput.view Number attributes state
        |> sends input event
        |> Result.andThen
            (\msg ->
                case msg of
                    Number inner ->
                        Ok (Tuple.first (NumberInput.update inner state))

                    _ ->
                        Err "not a message of the number field"
            )


typedAndLeft : List (NumberInput.Attribute Msg) -> String -> Result String NumberInput.State
typedAndLeft attributes text =
    numberStep attributes (Event.input text) (NumberInput.init "n")
        |> Result.andThen (numberStep attributes Event.blur)


numberInputTests : Test
numberInputTests =
    describe "NumberInput"
        [ test "1.005 with two decimals is 1.01, as Klar.Format rounds it" <|
            \_ -> typedAndLeft [ NumberInput.decimals 2 ] "1.005" |> Result.map NumberInput.value |> Expect.equal (Ok (Just 1.01))
        , test "a half is rounded away from zero, also below zero" <|
            \_ ->
                Expect.all
                    [ \_ -> typedAndLeft [ NumberInput.decimals 2 ] "-0.125" |> Result.map NumberInput.value |> Expect.equal (Ok (Just -0.13))
                    , \_ -> typedAndLeft [ NumberInput.decimals 2 ] "0.125" |> Result.map NumberInput.value |> Expect.equal (Ok (Just 0.13))
                    , \_ -> typedAndLeft [ NumberInput.decimals 1 ] "1.45" |> Result.map NumberInput.value |> Expect.equal (Ok (Just 1.5))
                    ]
                    ()
        , test "in Norwegian 10.000 is ten thousand" <|
            \_ -> typedAndLeft [ NumberInput.locale Locale.nb ] "10.000" |> Result.map NumberInput.value |> Expect.equal (Ok (Just 10000))
        , test "a computed number is shown without the noise of floating point" <|
            \_ ->
                Expect.all
                    [ \_ -> has input [ Selector.attribute (Attr.value "0.3") ] (NumberInput.view Number [] (NumberInput.setValue (Just (0.1 + 0.2)) (NumberInput.init "n")))
                    , \_ -> has input [ Selector.attribute (Attr.value "0.0000001") ] (NumberInput.view Number [] (NumberInput.setValue (Just 1.0e-7) (NumberInput.init "n")))
                    , \_ -> has input [ Selector.attribute (Attr.value "12.50") ] (NumberInput.view Number [ NumberInput.decimals 2 ] (NumberInput.setValue (Just 12.5) (NumberInput.init "n")))
                    ]
                    ()
        , test "Escape throws away what is being typed and brings the number back" <|
            \_ ->
                numberStep [] (Event.input "99") (NumberInput.setValue (Just 12) (NumberInput.init "n"))
                    |> Result.andThen (numberStep [] (key [] "Escape"))
                    |> Result.map NumberInput.value
                    |> Expect.equal (Ok (Just 12))
        , test "Escape with nothing typed is left alone" <|
            \_ -> NumberInput.view Number [] (NumberInput.setValue (Just 12) (NumberInput.init "n")) |> sends input (key [] "Escape") |> sendsNothing
        , test "the numeric keyboard only for a field that takes no negative number" <|
            \_ ->
                Expect.all
                    [ \_ -> has input [ attr "inputmode" "decimal" ] (NumberInput.view Number [ NumberInput.min 0 ] (NumberInput.init "n"))
                    , \_ -> has input [ attr "inputmode" "numeric" ] (NumberInput.view Number [ NumberInput.min 1, NumberInput.decimals 0 ] (NumberInput.init "n"))
                    , \_ -> hasNot input [ attr "inputmode" "decimal" ] (NumberInput.view Number [ NumberInput.min -10 ] (NumberInput.init "n"))
                    , \_ -> hasNot input [ attr "inputmode" "decimal" ] (NumberInput.view Number [] (NumberInput.init "n"))
                    ]
                    ()
        , test "screen readers read the number as the field shows it" <|
            \_ ->
                has input
                    [ attr "aria-valuetext" "1234,5" ]
                    (NumberInput.view Number [ NumberInput.locale Locale.nb ] (NumberInput.setValue (Just 1234.5) (NumberInput.init "n")))
        , test "noSteppers takes the buttons away" <|
            \_ -> none [ Selector.class "klar-number__steps" ] (NumberInput.view Number [ NumberInput.noSteppers ] (NumberInput.init "n"))
        , test "a pasted number with the unit of the field is read without it" <|
            \_ ->
                Expect.all
                    [ \_ -> typedAndLeft [ NumberInput.suffixText "kg" ] "12 kg" |> Result.map NumberInput.value |> Expect.equal (Ok (Just 12))
                    , \_ -> typedAndLeft [ NumberInput.prefixText "USD" ] "usd 1,250.50" |> Result.map NumberInput.value |> Expect.equal (Ok (Just 1250.5))
                    , \_ -> typedAndLeft [ NumberInput.suffixText "%", NumberInput.locale Locale.nb ] "55 %" |> Result.map NumberInput.value |> Expect.equal (Ok (Just 55))
                    , \_ -> typedAndLeft [ NumberInput.suffixText "kg" ] "12 lb" |> Result.map NumberInput.value |> Expect.equal (Ok Nothing)
                    ]
                    ()
        , test "stepping keeps to the grid of the steps" <|
            \_ ->
                let
                    stepped keyName =
                        numberStep [ NumberInput.step 5 ] (key [] keyName) (NumberInput.setValue (Just 3) (NumberInput.init "n"))
                            |> Result.map NumberInput.value
                in
                Expect.equal [ Ok (Just 5), Ok (Just 0) ] [ stepped "ArrowUp", stepped "ArrowDown" ]
        , test "the grid starts at min" <|
            \_ ->
                numberStep [ NumberInput.min 1, NumberInput.step 5 ] (key [] "ArrowUp") (NumberInput.setValue (Just 1) (NumberInput.init "n"))
                    |> Result.map NumberInput.value
                    |> Expect.equal (Ok (Just 6))
        , test "aria-valuenow stays inside the limits; the text says the number" <|
            \_ ->
                has input
                    [ attr "aria-valuenow" "50", attr "aria-valuetext" "55" ]
                    (NumberInput.view Number [ NumberInput.max 50 ] (NumberInput.setValue (Just 55) (NumberInput.init "n")))
        ]
