module InlineEditTest exposing (suite)

{-| The cycle of an inline edit driven through its view: the keys, leaving the
field, validation, a late answer from the backend, the application's own
changes while the user is editing, and correcting a refused text.
-}

import Expect
import Html.Attributes
import Json.Encode as Encode exposing (Value)
import Klar.InlineEdit as InlineEdit
import Klar.Locale as Locale
import Klar.Remote as Remote
import Test exposing (Test, describe, test)
import Test.Html.Event as Event
import Test.Html.Query as Query
import Test.Html.Selector as Selector exposing (Selector)


type Msg
    = Edit InlineEdit.Msg


type alias Step =
    InlineEdit.State -> Result String InlineEdit.State


customer : InlineEdit.State
customer =
    InlineEdit.init "customer" "Ada Lovelace"


required : List (InlineEdit.Attribute Msg)
required =
    [ InlineEdit.validate
        (\text ->
            if text == "" then
                Just "Enter a name"

            else
                Nothing
        )
    ]


on : List (InlineEdit.Attribute Msg) -> List Selector -> ( String, Value ) -> Step
on attributes selectors event state =
    InlineEdit.view Edit attributes state
        |> Query.fromHtml
        |> Query.find selectors
        |> Event.simulate event
        |> Event.toResult
        |> Result.map (\(Edit inner) -> Tuple.first (InlineEdit.update inner state))


{-| The command of `update` after an event, which says where the focus goes.
-}
command : List (InlineEdit.Attribute Msg) -> List Selector -> ( String, Value ) -> InlineEdit.State -> Result String (Cmd InlineEdit.Msg)
command attributes selectors event state =
    InlineEdit.view Edit attributes state
        |> Query.fromHtml
        |> Query.find selectors
        |> Event.simulate event
        |> Event.toResult
        |> Result.map (\(Edit inner) -> Tuple.second (InlineEdit.update inner state))


display : List Selector
display =
    [ Selector.class "klar-inline-edit__display" ]


input : List Selector
input =
    [ Selector.tag "input" ]


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


{-| A key with the text that is in the input when it is pressed.
-}
keyWithText : String -> String -> ( String, Value )
keyWithText text name =
    key [ ( "target", Encode.object [ ( "value", Encode.string text ) ] ) ] name


{-| Leaving the input, with the id of the element that has the focus of the page
while it happens: `"customer"` when the window lost the focus, `""` (the page)
when the user went elsewhere in it.
-}
blur : String -> ( String, Value )
blur focused =
    Event.custom "blur"
        (Encode.object
            [ ( "target"
              , Encode.object
                    [ ( "value", Encode.string "Ada Byron" )
                    , ( "ownerDocument", Encode.object [ ( "activeElement", Encode.object [ ( "id", Encode.string focused ) ] ) ] )
                    ]
              )
            ]
        )


steps : List Step -> InlineEdit.State -> Result String InlineEdit.State
steps list state =
    List.foldl (\step result -> Result.andThen step result) (Ok state) list


start : Step
start =
    on [] display Event.click


typed : String -> Step
typed text =
    on [] input (Event.input text)


enter : Step
enter =
    on [] input (key [] "Enter")


editing : InlineEdit.State
editing =
    steps [ start, typed "Ada Byron" ] customer |> Result.withDefault customer


saving : InlineEdit.State
saving =
    steps [ start, typed "Ada Byron", enter ] customer |> Result.withDefault customer


refused : InlineEdit.State
refused =
    InlineEdit.failed (Remote.problem Remote.validation |> Remote.withDetail "This name is taken.") saving


summary : InlineEdit.State -> { editing : Bool, saving : Bool, failed : Bool, value : String, pending : Maybe String }
summary state =
    { editing = InlineEdit.isEditing state
    , saving = InlineEdit.isSaving state
    , failed = InlineEdit.isFailed state
    , value = InlineEdit.value state
    , pending = InlineEdit.pending state
    }


suite : Test
suite =
    describe "InlineEdit"
        [ keyTests
        , blurTests
        , validationTests
        , lateAnswerTests
        , setValueTests
        , correctionTests
        , announcementTests
        , nameTests
        , multilineTests
        ]


keyTests : Test
keyTests =
    describe "keys"
        [ test "Enter saves the text that is in the input, also before the next render" <|
            \_ ->
                steps [ start, typed "Ada Byron", on [] input (keyWithText "Ada King" "Enter") ] customer
                    |> Result.map InlineEdit.pending
                    |> Expect.equal (Ok (Just "Ada King"))
        , test "Escape cancels, and its default is prevented so a dialog around it stays open" <|
            \_ ->
                InlineEdit.view Edit [] editing
                    |> Query.fromHtml
                    |> Query.find input
                    |> Event.simulate (key [] "Escape")
                    |> Event.expectPreventDefault
        , test "Escape goes back to the old text" <|
            \_ ->
                on [] input (key [] "Escape") editing
                    |> Result.map summary
                    |> Expect.equal (Ok { editing = False, saving = False, failed = False, value = "Ada Lovelace", pending = Nothing })
        , test "the Enter that ends an IME composition does not save" <|
            \_ -> on [] input (key [ ( "isComposing", Encode.bool True ) ] "Enter") editing |> Expect.err
        , test "the Escape that ends an IME composition does not cancel" <|
            \_ -> on [] input (key [ ( "isComposing", Encode.bool True ) ] "Escape") editing |> Expect.err
        , test "a key with the keyCode 229 of a composition does nothing" <|
            \_ -> on [] input (key [ ( "keyCode", Encode.int 229 ) ] "Enter") editing |> Expect.err
        , test "a message can be compared: no function travels in it" <|
            \_ ->
                let
                    -- two renders make two decoders; a function in the message
                    -- would make (==) crash
                    message () =
                        InlineEdit.view Edit required editing
                            |> Query.fromHtml
                            |> Query.find input
                            |> Event.simulate (key [] "Enter")
                            |> Event.toResult
                in
                Expect.equal (message ()) (message ())
        , test "edit opens the editor from the application" <|
            \_ ->
                InlineEdit.edit customer
                    |> Tuple.first
                    |> InlineEdit.isEditing
                    |> Expect.equal True
        ]


blurTests : Test
blurTests =
    describe "leaving the field"
        [ test "going elsewhere on the page saves" <|
            \_ ->
                on [] input (blur "") editing
                    |> Result.map InlineEdit.isSaving
                    |> Expect.equal (Ok True)
        , test "switching to another window does not: the input keeps the focus of its page" <|
            \_ -> on [] input (blur "customer") editing |> Expect.err
        , test "leaving the field does not pull the focus back: Tab and a click elsewhere keep it" <|
            \_ -> command [] input (blur "") editing |> Expect.equal (Ok Cmd.none)
        , test "Enter gives the focus back to the text, as the editor goes away under it" <|
            \_ ->
                command [] input (key [] "Enter") editing
                    |> Result.map (\cmd -> cmd /= Cmd.none)
                    |> Expect.equal (Ok True)
        , test "leaving an unchanged editor does not pull the focus back either" <|
            \_ ->
                steps [ start ] customer
                    |> Result.andThen (command [] input (Event.custom "blur" (Encode.object [])))
                    |> Expect.equal (Ok Cmd.none)
        ]


validationTests : Test
validationTests =
    describe "validation"
        [ test "a message keeps the editor open and is shown under it" <|
            \_ ->
                steps [ start, typed "", on required input (keyWithText "  " "Enter") ] customer
                    |> Result.map
                        (\state ->
                            InlineEdit.view Edit required state
                                |> Query.fromHtml
                                |> Query.find [ Selector.class "klar-inline-edit__error" ]
                                |> Query.has [ Selector.text "Enter a name" ]
                        )
                    |> Result.withDefault (Expect.fail "the editor did not take the keys")
        , test "the text that was refused stays in the editor" <|
            \_ ->
                steps [ start, typed "", on required input (keyWithText "" "Enter") ] customer
                    |> Result.map summary
                    |> Expect.equal (Ok { editing = True, saving = False, failed = False, value = "Ada Lovelace", pending = Nothing })
        ]


lateAnswerTests : Test
lateAnswerTests =
    describe "an answer when no save is on its way"
        [ test "saved does not close an editor the user opened since" <|
            \_ ->
                InlineEdit.saved editing
                    |> summary
                    |> Expect.equal (summary editing)
        , test "failed does not replace an open editor" <|
            \_ ->
                InlineEdit.failed (Remote.problem Remote.network) editing
                    |> summary
                    |> Expect.equal (summary editing)
        , test "failed on text that is only read changes nothing" <|
            \_ ->
                InlineEdit.failed (Remote.problem Remote.network) customer
                    |> InlineEdit.isFailed
                    |> Expect.equal False
        , test "saved makes the pending text the value once" <|
            \_ ->
                saving
                    |> InlineEdit.saved
                    |> InlineEdit.saved
                    |> summary
                    |> Expect.equal { editing = False, saving = False, failed = False, value = "Ada Byron", pending = Nothing }
        ]


setValueTests : Test
setValueTests =
    describe "setValue while the user is busy"
        [ test "the text the user typed stays in the editor" <|
            \_ ->
                InlineEdit.setValue "Ada King" editing
                    |> summary
                    |> Expect.equal { editing = True, saving = False, failed = False, value = "Ada King", pending = Nothing }
        , test "Escape then goes back to the new value" <|
            \_ ->
                InlineEdit.setValue "Ada King" editing
                    |> on [] input (key [] "Escape")
                    |> Result.map InlineEdit.value
                    |> Expect.equal (Ok "Ada King")
        , test "an editor the user has not changed shows the new value, so Enter does not save the old one" <|
            \_ ->
                steps [ start ] customer
                    |> Result.map (InlineEdit.setValue "Ada King")
                    |> Result.andThen enter
                    |> Result.map summary
                    |> Expect.equal (Ok { editing = False, saving = False, failed = False, value = "Ada King", pending = Nothing })
        , test "a save on its way goes on, and saved still makes the pending text the value" <|
            \_ ->
                saving
                    |> InlineEdit.setValue "Ada King"
                    |> InlineEdit.saved
                    |> InlineEdit.value
                    |> Expect.equal "Ada Byron"
        , test "in reading mode the new value is shown at once" <|
            \_ ->
                InlineEdit.setValue "Ada King" customer
                    |> InlineEdit.value
                    |> Expect.equal "Ada King"
        ]


correctionTests : Test
correctionTests =
    describe "correcting a refused text"
        [ test "a click on the text opens the editor with the refused text" <|
            \_ ->
                start refused
                    |> Result.map
                        (\state ->
                            InlineEdit.view Edit [] state
                                |> Query.fromHtml
                                |> Query.find input
                                |> Query.has [ Selector.attribute (Html.Attributes.value "Ada Byron") ]
                        )
                    |> Result.withDefault (Expect.fail "the text did not open the editor")
        , test "the problem is shown under the editor until the user types" <|
            \_ ->
                start refused
                    |> Result.map
                        (\state ->
                            InlineEdit.view Edit [] state
                                |> Query.fromHtml
                                |> Query.find [ Selector.class "klar-inline-edit__error" ]
                                |> Query.has [ Selector.text "Could not save. The request was rejected: This name is taken." ]
                        )
                    |> Result.withDefault (Expect.fail "the text did not open the editor")
        , test "typing takes the problem away" <|
            \_ ->
                steps [ start, typed "Ada B." ] refused
                    |> Result.map
                        (\state ->
                            InlineEdit.view Edit [] state
                                |> Query.fromHtml
                                |> Query.hasNot [ Selector.class "klar-inline-edit__error" ]
                        )
                    |> Result.withDefault (Expect.fail "the editor did not take the text")
        , test "Enter sends the corrected text" <|
            \_ ->
                steps [ start, typed "Ada B.", enter ] refused
                    |> Result.map summary
                    |> Expect.equal (Ok { editing = False, saving = True, failed = False, value = "Ada Lovelace", pending = Just "Ada B." })
        , test "leaving the unchanged refused text brings the failure back and sends nothing" <|
            \_ ->
                steps [ start, on [] input (blur "") ] refused
                    |> Result.map summary
                    |> Expect.equal (Ok { editing = False, saving = False, failed = True, value = "Ada Lovelace", pending = Just "Ada Byron" })
        , test "Enter on the unchanged text of a validation problem does not send it again" <|
            \_ ->
                steps [ start, enter ] refused
                    |> Result.map summary
                    |> Expect.equal (Ok { editing = False, saving = False, failed = True, value = "Ada Lovelace", pending = Just "Ada Byron" })
        , test "Enter on the unchanged text of a network problem sends it again, as Try again does" <|
            \_ ->
                steps [ start, enter ] (InlineEdit.failed (Remote.problem Remote.network) saving)
                    |> Result.map summary
                    |> Expect.equal (Ok { editing = False, saving = True, failed = False, value = "Ada Lovelace", pending = Just "Ada Byron" })
        , test "leaving the unchanged text of a network problem sends nothing" <|
            \_ ->
                steps [ start, on [] input (blur "") ] (InlineEdit.failed (Remote.problem Remote.network) saving)
                    |> Result.map InlineEdit.isSaving
                    |> Expect.equal (Ok False)
        , test "the failure that comes back can be opened again" <|
            \_ ->
                steps [ start, on [] input (blur ""), start ] refused
                    |> Result.map summary
                    |> Expect.equal (Ok { editing = True, saving = False, failed = False, value = "Ada Lovelace", pending = Nothing })
        , test "Escape goes back to the old value and forgets the refused text" <|
            \_ ->
                steps [ start, on [] input (key [] "Escape") ] refused
                    |> Result.map summary
                    |> Expect.equal (Ok { editing = False, saving = False, failed = False, value = "Ada Lovelace", pending = Nothing })
        ]


announcementTests : Test
announcementTests =
    let
        status state =
            InlineEdit.view Edit [] state
                |> Query.fromHtml
                |> Query.find [ Selector.attribute (Html.Attributes.attribute "role" "status") ]
    in
    describe "what screen readers hear"
        [ test "Saving ... while the save is on its way" <|
            \_ -> status saving |> Query.has [ Selector.text "Saving ..." ]
        , test "Saved after it" <|
            \_ -> status (InlineEdit.saved saving) |> Query.has [ Selector.text "Saved" ]
        , test "the live region is there before anything happens" <|
            \_ -> status customer |> Query.has [ Selector.class "klar-sr-only" ]
        , test "in Norwegian" <|
            \_ ->
                InlineEdit.view Edit [ InlineEdit.locale Locale.nb ] (InlineEdit.saved saving)
                    |> Query.fromHtml
                    |> Query.has [ Selector.text "Lagret" ]
        ]


nameTests : Test
nameTests =
    describe "the name of the text button"
        [ test "keeps the case of the name it was given" <|
            \_ ->
                InlineEdit.view Edit [ InlineEdit.ariaLabel "VAT number" ] (InlineEdit.init "vat" "NO974760673")
                    |> Query.fromHtml
                    |> Query.find display
                    |> Query.has [ Selector.attribute (Html.Attributes.attribute "aria-label" "Edit VAT number: NO974760673") ]
        ]


multilineTests : Test
multilineTests =
    let
        note =
            [ InlineEdit.multiline ]

        area =
            [ Selector.tag "textarea" ]

        openNote =
            InlineEdit.init "note" "Leave at the door"
                |> on note display Event.click
                |> Result.andThen (on note area (Event.input "Leave at the door\nRing twice"))
    in
    describe "a text of several lines"
        [ test "is edited in a text area" <|
            \_ ->
                openNote
                    |> Result.map (InlineEdit.view Edit note >> Query.fromHtml >> Query.has [ Selector.tag "textarea" ])
                    |> Result.withDefault (Expect.fail "the editor did not open")
        , test "Enter is a new line, not a save" <|
            \_ -> openNote |> Result.andThen (on note area (key [] "Enter")) |> Expect.err
        , test "Ctrl+Enter saves" <|
            \_ ->
                openNote
                    |> Result.andThen (on note area (key [ ( "ctrlKey", Encode.bool True ) ] "Enter"))
                    |> Result.map InlineEdit.pending
                    |> Expect.equal (Ok (Just "Leave at the door\nRing twice"))
        , test "Cmd+Enter saves" <|
            \_ ->
                openNote
                    |> Result.andThen (on note area (key [ ( "metaKey", Encode.bool True ) ] "Enter"))
                    |> Result.map InlineEdit.isSaving
                    |> Expect.equal (Ok True)
        , test "Escape cancels" <|
            \_ ->
                openNote
                    |> Result.andThen (on note area (key [] "Escape"))
                    |> Result.map InlineEdit.isEditing
                    |> Expect.equal (Ok False)
        , test "a single line does not save on Ctrl+Enter, which belongs to the page" <|
            \_ -> on [] input (key [ ( "ctrlKey", Encode.bool True ) ] "Enter") editing |> Expect.err
        , test "the line breaks are kept in reading mode" <|
            \_ ->
                InlineEdit.view Edit note (InlineEdit.init "note" "One\nTwo")
                    |> Query.fromHtml
                    |> Query.has [ Selector.class "klar-inline-edit__text--multiline" ]
        ]
