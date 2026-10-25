module MarkdownEditorTest exposing (suite)

{-| The Markdown editor as a component: what it renders, how its messages change
its state, and what the events of the text area and of the buttons do.

The messages are made the way the browser makes them: by simulating an event on the
element and handing what comes out to `update`.

-}

import Expect
import Html.Attributes as Attr
import Json.Encode as Encode
import Klar.Locale as Locale
import Klar.Markdown as Markdown
import Klar.MarkdownEditor as Editor exposing (Msg, State)
import Test exposing (Test, describe, test)
import Test.Html.Event as Event
import Test.Html.Query as Query
import Test.Html.Selector as Selector


suite : Test
suite =
    describe "Markdown editor"
        [ stateTests
        , eventTests
        , historyTests
        , previewTests
        , renderTests
        , textTests
        ]



-- HELPERS


start : String -> State
start text =
    Editor.setValue text (Editor.init "note")


render : List (Editor.Attribute Msg) -> State -> Query.Single Msg
render attributes state =
    Query.fromHtml (Editor.view identity attributes state)


textarea : Query.Single Msg -> Query.Single Msg
textarea =
    Query.find [ Selector.tag "textarea" ]


{-| What the browser sends for an event on the text area: the element is the target.
-}
target : String -> Int -> Int -> List ( String, Encode.Value )
target text selectionStart selectionEnd =
    [ ( "target"
      , Encode.object
            [ ( "value", Encode.string text )
            , ( "selectionStart", Encode.int selectionStart )
            , ( "selectionEnd", Encode.int selectionEnd )
            ]
      )
    ]


{-| Does the text area say that it changed? The result is the message, or the reason
it is none.
-}
typed : String -> Int -> State -> State
typed text caret state =
    let
        message =
            render [] state
                |> textarea
                |> Event.simulate (Event.custom "input" (Encode.object (target text caret caret)))
                |> Event.toResult
    in
    case message of
        Ok msg ->
            Editor.update msg state |> Tuple.first

        Err _ ->
            state


{-| The click of a toolbar button while the text area has the focus.
-}
pressed : String -> String -> Int -> Int -> State -> Result String ( State, Cmd Msg )
pressed buttonLabel text selectionStart selectionEnd state =
    let
        click =
            Encode.object
                [ ( "target"
                  , Encode.object
                        [ ( "ownerDocument"
                          , Encode.object
                                [ ( "activeElement"
                                  , Encode.object
                                        [ ( "id", Encode.string "note" )
                                        , ( "value", Encode.string text )
                                        , ( "selectionStart", Encode.int selectionStart )
                                        , ( "selectionEnd", Encode.int selectionEnd )
                                        ]
                                  )
                                ]
                          )
                        ]
                  )
                ]
    in
    render [] state
        |> Query.find [ Selector.tag "button", Selector.attribute (Attr.attribute "aria-label" buttonLabel) ]
        |> Event.simulate (Event.custom "click" click)
        |> Event.toResult
        |> Result.map (\msg -> Editor.update msg state)


keydown : { key : String, ctrl : Bool, shift : Bool } -> String -> Int -> Int -> ( String, Encode.Value )
keydown keys text selectionStart selectionEnd =
    Event.custom "keydown"
        (Encode.object
            (( "key", Encode.string keys.key )
                :: ( "ctrlKey", Encode.bool keys.ctrl )
                :: ( "metaKey", Encode.bool False )
                :: ( "shiftKey", Encode.bool keys.shift )
                :: ( "altKey", Encode.bool False )
                :: target text selectionStart selectionEnd
            )
        )


shortcut : { key : String, ctrl : Bool, shift : Bool } -> String -> Int -> Int -> State -> Result String ( State, Cmd Msg )
shortcut keys text selectionStart selectionEnd state =
    render [] state
        |> textarea
        |> Event.simulate (keydown keys text selectionStart selectionEnd)
        |> Event.toResult
        |> Result.map (\msg -> Editor.update msg state)


value : Result String ( State, Cmd Msg ) -> Maybe String
value result =
    result |> Result.toMaybe |> Maybe.map (Tuple.first >> Editor.value)



-- STATE


stateTests : Test
stateTests =
    describe "state"
        [ test "a new editor has no text" <|
            \_ ->
                Editor.value (Editor.init "note")
                    |> Expect.equal ""
        , test "setValue sets the text" <|
            \_ ->
                Editor.value (start "Hello")
                    |> Expect.equal "Hello"
        , test "line breaks are as a text area has them" <|
            \_ ->
                Editor.value (start "a\u{000D}\nb\u{000D}c")
                    |> Expect.equal "a\nb\nc"
        , test "typing changes the text" <|
            \_ ->
                typed "Hello!" 6 (start "Hello")
                    |> Editor.value
                    |> Expect.equal "Hello!"
        , test "the text is kept exactly as typed" <|
            \_ ->
                typed "  **a**\t \n\n" 5 (start "")
                    |> Editor.value
                    |> Expect.equal "  **a**\t \n\n"
        ]



-- EVENTS


eventTests : Test
eventTests =
    describe "buttons and shortcuts"
        [ test "bold on the selection" <|
            \_ ->
                pressed "Bold" "a b c" 2 3 (start "a b c")
                    |> value
                    |> Expect.equal (Just "a **b** c")
        , test "italic" <|
            \_ ->
                pressed "Italic" "a b c" 2 3 (start "a b c")
                    |> value
                    |> Expect.equal (Just "a *b* c")
        , test "code" <|
            \_ ->
                pressed "Code" "a b c" 2 3 (start "a b c")
                    |> value
                    |> Expect.equal (Just "a `b` c")
        , test "link" <|
            \_ ->
                pressed "Link" "a b c" 2 3 (start "a b c")
                    |> value
                    |> Expect.equal (Just "a [b](https://) c")
        , test "heading, quote and the lists work on the line" <|
            \_ ->
                [ pressed "Heading" "a" 1 1 (start "a")
                , pressed "Quote" "a" 1 1 (start "a")
                , pressed "Bulleted list" "a" 1 1 (start "a")
                , pressed "Numbered list" "a" 1 1 (start "a")
                , pressed "Task list" "a" 1 1 (start "a")
                ]
                    |> List.map value
                    |> Expect.equal [ Just "## a", Just "> a", Just "- a", Just "1. a", Just "- [ ] a" ]
        , test "the buttons use the selection of the page, not the last one seen" <|
            \_ ->
                pressed "Bold" "a b c" 0 1 (start "a b c" |> typed "a b c" 3)
                    |> value
                    |> Expect.equal (Just "**a** b c")
        , test "when the text area is not what the page sees, the last selection seen is used" <|
            \_ ->
                -- the text of the page's element is not the text of the editor
                pressed "Bold" "something else" 0 4 (typed "a b c" 3 (start "a b c"))
                    |> value
                    |> Expect.equal (Just "a b**** c")
        , test "bold with a keyboard shortcut" <|
            \_ ->
                shortcut { key = "b", ctrl = True, shift = False } "a b c" 2 3 (start "a b c")
                    |> value
                    |> Expect.equal (Just "a **b** c")
        , test "the key in capitals, as with the caps lock on" <|
            \_ ->
                shortcut { key = "B", ctrl = True, shift = False } "a b c" 2 3 (start "a b c")
                    |> value
                    |> Expect.equal (Just "a **b** c")
        , test "italic and link with shortcuts" <|
            \_ ->
                [ shortcut { key = "i", ctrl = True, shift = False } "a b c" 2 3 (start "a b c")
                , shortcut { key = "k", ctrl = True, shift = False } "a b c" 2 3 (start "a b c")
                ]
                    |> List.map value
                    |> Expect.equal [ Just "a *b* c", Just "a [b](https://) c" ]
        , test "a shortcut of the editor goes no further, so that the application's own Ctrl K does not fire as well" <|
            \_ ->
                [ "b", "i", "k" ]
                    |> List.map
                        (\key _ ->
                            render [] (start "a b c")
                                |> textarea
                                |> Event.simulate (keydown { key = key, ctrl = True, shift = False } "a b c" 2 3)
                                |> Expect.all [ Event.expectStopPropagation, Event.expectPreventDefault ]
                        )
                    |> (\checks -> Expect.all checks ())
        , test "a key that is the browser's is passed on and not prevented" <|
            \_ ->
                render [] (start "a b c")
                    |> textarea
                    |> Event.simulate (keydown { key = "a", ctrl = True, shift = False } "a b c" 2 3)
                    |> Event.toResult
                    |> Result.toMaybe
                    |> Expect.equal Nothing
        , test "a key without ctrl or cmd is not a shortcut, and the browser keeps it" <|
            \_ ->
                shortcut { key = "b", ctrl = False, shift = False } "a b c" 2 3 (start "a b c")
                    |> Result.toMaybe
                    |> Expect.equal Nothing
        , test "other keys with ctrl are the browser's" <|
            \_ ->
                [ "a", "c", "v", "x", "s", "p", "f", "Enter", "Tab" ]
                    |> List.map (\key -> shortcut { key = key, ctrl = True, shift = False } "a b c" 2 3 (start "a b c") |> Result.toMaybe)
                    |> Expect.equal (List.repeat 9 Nothing)
        , test "on a layout without Latin letters the physical key is the shortcut" <|
            \_ ->
                render [] (start "a b c")
                    |> textarea
                    |> Event.simulate
                        (Event.custom "keydown"
                            (Encode.object
                                (( "key", Encode.string "и" )
                                    :: ( "code", Encode.string "KeyB" )
                                    :: ( "ctrlKey", Encode.bool True )
                                    :: ( "metaKey", Encode.bool False )
                                    :: ( "shiftKey", Encode.bool False )
                                    :: ( "altKey", Encode.bool False )
                                    :: target "a b c" 2 3
                                )
                            )
                        )
                    |> Event.toResult
                    |> Result.map (\msg -> Editor.update msg (start "a b c"))
                    |> value
                    |> Expect.equal (Just "a **b** c")
        , test "a Latin layout follows the letter, not the place of the key" <|
            \_ ->
                -- on a French keyboard the letter b is where it is everywhere, but z is where w is on others
                render [] (start "a b c")
                    |> textarea
                    |> Event.simulate
                        (Event.custom "keydown"
                            (Encode.object
                                (( "key", Encode.string "a" )
                                    :: ( "code", Encode.string "KeyQ" )
                                    :: ( "ctrlKey", Encode.bool True )
                                    :: ( "metaKey", Encode.bool False )
                                    :: ( "shiftKey", Encode.bool False )
                                    :: ( "altKey", Encode.bool False )
                                    :: target "a b c" 2 3
                                )
                            )
                        )
                    |> Event.toResult
                    |> Result.toMaybe
                    |> Expect.equal Nothing
        , test "a key that ends a composition is never a shortcut" <|
            \_ ->
                render [] (start "a b c")
                    |> textarea
                    |> Event.simulate
                        (Event.custom "keydown"
                            (Encode.object
                                (( "key", Encode.string "b" )
                                    :: ( "keyCode", Encode.int 229 )
                                    :: ( "ctrlKey", Encode.bool True )
                                    :: ( "metaKey", Encode.bool False )
                                    :: ( "shiftKey", Encode.bool False )
                                    :: ( "altKey", Encode.bool False )
                                    :: target "a b c" 2 3
                                )
                            )
                        )
                    |> Event.toResult
                    |> Result.toMaybe
                    |> Expect.equal Nothing
        , test "shift changes the meaning of a letter, so it is not bold" <|
            \_ ->
                shortcut { key = "b", ctrl = True, shift = True } "a b c" 2 3 (start "a b c")
                    |> Result.toMaybe
                    |> Expect.equal Nothing
        , test "no buttons while the editor is read only or disabled" <|
            \_ ->
                Expect.all
                    [ \_ ->
                        render [ Editor.readOnly True ] (start "a")
                            |> Query.find [ Selector.tag "button", Selector.attribute (Attr.attribute "aria-label" "Bold") ]
                            |> Query.has [ Selector.disabled True ]
                    , \_ ->
                        render [ Editor.disabled True ] (start "a")
                            |> Query.find [ Selector.tag "button", Selector.attribute (Attr.attribute "aria-label" "Bold") ]
                            |> Query.has [ Selector.disabled True ]
                    ]
                    ()
        , test "a read only editor has no shortcuts" <|
            \_ ->
                render [ Editor.readOnly True ] (start "a b c")
                    |> textarea
                    |> Event.simulate (Event.custom "keydown" (Encode.object (( "key", Encode.string "b" ) :: ( "ctrlKey", Encode.bool True ) :: ( "metaKey", Encode.bool False ) :: ( "shiftKey", Encode.bool False ) :: ( "altKey", Encode.bool False ) :: target "a b c" 2 3)))
                    |> Event.toResult
                    |> Result.toMaybe
                    |> Expect.equal Nothing
        , test "the focus goes back to the text area" <|
            \_ ->
                pressed "Bold" "a b c" 2 3 (start "a b c")
                    |> Result.map (Tuple.second >> (\cmd -> cmd /= Cmd.none))
                    |> Expect.equal (Ok True)
        , test "a button that changes nothing changes nothing" <|
            \_ ->
                pressed "Bold" " " 0 1 (start " ")
                    |> value
                    |> Expect.equal (Just " ")
        ]



-- HISTORY: CTRL Z


historyTests : Test
historyTests =
    let
        bolded =
            pressed "Bold" "a b c" 2 3 (start "a b c") |> Result.map Tuple.first |> Result.withDefault (start "")
    in
    describe "undo and redo of the buttons"
        [ test "ctrl z undoes the last change of a button" <|
            \_ ->
                shortcut { key = "z", ctrl = True, shift = False } "a **b** c" 4 5 bolded
                    |> value
                    |> Expect.equal (Just "a b c")
        , test "and ctrl y redoes it" <|
            \_ ->
                shortcut { key = "z", ctrl = True, shift = False } "a **b** c" 4 5 bolded
                    |> Result.map Tuple.first
                    |> Result.andThen (shortcut { key = "y", ctrl = True, shift = False } "a b c" 2 3)
                    |> value
                    |> Expect.equal (Just "a **b** c")
        , test "ctrl shift z redoes it" <|
            \_ ->
                shortcut { key = "z", ctrl = True, shift = False } "a **b** c" 4 5 bolded
                    |> Result.map Tuple.first
                    |> Result.andThen (shortcut { key = "z", ctrl = True, shift = True } "a b c" 2 3)
                    |> value
                    |> Expect.equal (Just "a **b** c")
        , test "several changes are undone one at a time" <|
            \_ ->
                let
                    twice =
                        pressed "Italic" "a **b** c" 4 5 bolded |> Result.map Tuple.first |> Result.withDefault (start "")
                in
                shortcut { key = "z", ctrl = True, shift = False } "a ***b*** c" 5 6 twice
                    |> Result.map Tuple.first
                    |> Result.andThen (shortcut { key = "z", ctrl = True, shift = False } "a **b** c" 4 5)
                    |> value
                    |> Expect.equal (Just "a b c")
        , test "ctrl z is the browser's when nothing was changed by a button" <|
            \_ ->
                shortcut { key = "z", ctrl = True, shift = False } "a b c" 2 3 (start "a b c")
                    |> Result.toMaybe
                    |> Expect.equal Nothing
        , test "ctrl z is the browser's after typing" <|
            \_ ->
                shortcut { key = "z", ctrl = True, shift = False } "a **b** c!" 10 10 (typed "a **b** c!" 10 bolded)
                    |> Result.toMaybe
                    |> Expect.equal Nothing
        , test "ctrl y is the browser's when there is nothing to redo" <|
            \_ ->
                shortcut { key = "y", ctrl = True, shift = False } "a **b** c" 4 5 bolded
                    |> Result.toMaybe
                    |> Expect.equal Nothing
        , test "typing after an undo ends what could be redone" <|
            \_ ->
                shortcut { key = "z", ctrl = True, shift = False } "a **b** c" 4 5 bolded
                    |> Result.map (Tuple.first >> typed "a b c!" 6)
                    |> Result.andThen (shortcut { key = "y", ctrl = True, shift = False } "a b c!" 6 6)
                    |> Result.toMaybe
                    |> Expect.equal Nothing
        , test "only the last twenty changes are kept" <|
            \_ ->
                let
                    once state =
                        pressed "Quote" (Editor.value state) 0 0 state |> Result.map Tuple.first |> Result.withDefault state

                    after =
                        List.foldl (\_ state -> once state) (start "a") (List.range 1 25)

                    undo state =
                        shortcut { key = "z", ctrl = True, shift = False } (Editor.value state) 0 0 state
                            |> Result.map Tuple.first
                            |> Result.withDefault state

                    undone =
                        List.foldl (\_ state -> undo state) after (List.range 1 30)
                in
                -- the quote is put on and taken off, 25 times: "> a". Twenty undos lead to the
                -- text after the fifth, which is "> a" as well; without a limit all 25 would
                -- lead to "a".
                Expect.equal "> a" (Editor.value undone)
        , test "setValue forgets the changes" <|
            \_ ->
                shortcut { key = "z", ctrl = True, shift = False } "x" 1 1 (Editor.setValue "x" bolded)
                    |> Result.toMaybe
                    |> Expect.equal Nothing
        ]



-- THE PREVIEW


previewTests : Test
previewTests =
    let
        long =
            String.repeat 9000 "a "
    in
    describe "the preview"
        [ test "follows the text at once when it is short" <|
            \_ ->
                render [] (typed "**hi**" 6 (start ""))
                    |> Query.find [ Selector.attribute (Attr.attribute "aria-label" "Preview") ]
                    |> Query.has [ Selector.tag "strong" ]
        , test "says that it is empty" <|
            \_ ->
                render [] (start "  ")
                    |> Query.find [ Selector.attribute (Attr.attribute "aria-label" "Preview") ]
                    |> Query.has [ Selector.text "Nothing to preview yet." ]
        , test "waits for a pause when the text is long" <|
            \_ ->
                let
                    state =
                        typed (long ++ "**x**") 0 (start "")
                in
                render [] state
                    |> Query.find [ Selector.attribute (Attr.attribute "aria-label" "Preview") ]
                    |> Expect.all
                        [ Query.hasNot [ Selector.tag "strong" ]
                        , Query.has [ Selector.attribute (Attr.attribute "aria-busy" "true") ]
                        ]
        , test "setValue does not wait" <|
            \_ ->
                render [] (start (long ++ "**x**"))
                    |> Query.find [ Selector.attribute (Attr.attribute "aria-label" "Preview") ]
                    |> Query.has [ Selector.tag "strong" ]
        , test "the headings of the preview are two levels down, so a form has no h1" <|
            \_ ->
                render [] (start "# Title\n\n## Part")
                    |> Query.find [ Selector.attribute (Attr.attribute "aria-label" "Preview") ]
                    |> Expect.all
                        [ Query.has [ Selector.tag "h3" ]
                        , Query.has [ Selector.tag "h4" ]
                        , Query.hasNot [ Selector.tag "h1" ]
                        ]
        , test "a heading of the preview looks like the same heading in the result" <|
            \_ ->
                Expect.all
                    [ \_ ->
                        render [] (start "# Title\n\n## Part")
                            |> Query.find [ Selector.attribute (Attr.attribute "aria-label" "Preview") ]
                            |> Expect.all
                                [ Query.find [ Selector.tag "h3" ] >> Query.has [ Selector.class "klar-md__h1" ]
                                , Query.find [ Selector.tag "h4" ] >> Query.has [ Selector.class "klar-md__h2" ]
                                ]
                    , \_ ->
                        Query.fromHtml (Markdown.view [] "# Title")
                            |> Query.find [ Selector.tag "h1" ]
                            |> Query.has [ Selector.class "klar-md__h1" ]
                    ]
                    ()
        , test "the application chooses the offset of the preview" <|
            \_ ->
                render [ Editor.preview [ Markdown.headingOffset 0 ] ] (start "# Title")
                    |> Query.find [ Selector.attribute (Attr.attribute "aria-label" "Preview") ]
                    |> Query.has [ Selector.tag "h1" ]
        , test "the preview is not announced" <|
            \_ ->
                render [] (start "text")
                    |> Query.find [ Selector.attribute (Attr.attribute "aria-label" "Preview") ]
                    |> Query.hasNot [ Selector.attribute (Attr.attribute "aria-live" "polite") ]
        , test "the preview is safe in the same way as the view" <|
            \_ ->
                render [] (start "<script>alert(1)</script> [x](javascript:alert(1))")
                    |> Expect.all
                        [ Query.hasNot [ Selector.tag "script" ]
                        , Query.hasNot [ Selector.tag "a" ]
                        ]
        , test "attributes for the preview" <|
            \_ ->
                render [ Editor.preview [ Markdown.images ] ] (start "![a](/a.png)")
                    |> Query.has [ Selector.tag "img" ]
        , test "images are not loaded unless asked for" <|
            \_ ->
                render [] (start "![a](https://example.com/a.png)")
                    |> Query.hasNot [ Selector.tag "img" ]
        ]



-- RENDER


renderTests : Test
renderTests =
    describe "markup"
        [ test "the label belongs to the text area" <|
            \_ ->
                render [ Editor.label "Description" ] (start "")
                    |> Expect.all
                        [ Query.find [ Selector.tag "label" ] >> Query.has [ Selector.text "Description", Selector.attribute (Attr.for "note") ]
                        , textarea >> Query.has [ Selector.id "note" ]
                        ]
        , test "hint and error are joined to the text area" <|
            \_ ->
                render [ Editor.label "Description", Editor.hint "Shown on the slip.", Editor.error "Required." ] (start "")
                    |> textarea
                    |> Query.has
                        [ Selector.attribute (Attr.attribute "aria-describedby" "note-hint note-error")
                        , Selector.attribute (Attr.attribute "aria-invalid" "true")
                        ]
        , test "required" <|
            \_ ->
                render [ Editor.label "Description", Editor.required ] (start "")
                    |> textarea
                    |> Query.has [ Selector.attribute (Attr.attribute "aria-required" "true") ]
        , test "a toolbar with nine buttons, each with a name" <|
            \_ ->
                render [] (start "")
                    |> Query.find [ Selector.attribute (Attr.attribute "aria-label" "Formatting") ]
                    |> Query.findAll [ Selector.tag "button" ]
                    |> Expect.all
                        [ Query.count (Expect.equal 9)
                        , Query.each (Query.has [ Selector.attribute (Attr.attribute "type" "button") ])
                        ]
        , test "the names of the buttons" <|
            \_ ->
                [ "Bold", "Italic", "Code", "Link", "Heading", "Quote", "Bulleted list", "Numbered list", "Task list" ]
                    |> List.map
                        (\name ->
                            \_ ->
                                render [] (start "")
                                    |> Query.find [ Selector.tag "button", Selector.attribute (Attr.attribute "aria-label" name) ]
                                    |> Query.has [ Selector.attribute (Attr.attribute "data-tip" (name ++ shortcutOf name)) ]
                        )
                    |> (\checks -> Expect.all checks ())
        , test "a tab for writing and one for previewing" <|
            \_ ->
                render [] (start "")
                    |> Query.find [ Selector.attribute (Attr.attribute "role" "tablist") ]
                    |> Query.findAll [ Selector.attribute (Attr.attribute "role" "tab") ]
                    |> Expect.all
                        [ Query.count (Expect.equal 2)
                        , Query.index 0 >> Query.has [ Selector.text "Write", Selector.attribute (Attr.attribute "aria-selected" "true") ]
                        , Query.index 1 >> Query.has [ Selector.text "Preview", Selector.attribute (Attr.attribute "aria-selected" "false") ]
                        ]
        , test "the tabs point at no panel, because the panes are always there" <|
            \_ ->
                render [] (start "")
                    |> Query.hasNot [ Selector.attribute (Attr.attribute "aria-controls" "note-tabs-panel-write") ]
        , test "the preview is a named group that can be scrolled with the keyboard" <|
            \_ ->
                render [] (start "text")
                    |> Query.find [ Selector.id "note-preview" ]
                    |> Query.has
                        [ Selector.attribute (Attr.attribute "role" "group")
                        , Selector.attribute (Attr.attribute "aria-label" "Preview")
                        , Selector.attribute (Attr.tabindex 0)
                        ]
        , test "the height is in lines" <|
            \_ ->
                render [ Editor.rows 5 ] (start "")
                    |> Expect.all
                        [ Query.has [ Selector.attribute (Attr.attribute "style" "--klar-mdeditor-rows:5") ]
                        , textarea >> Query.has [ Selector.attribute (Attr.rows 5) ]
                        ]
        , test "the layout can be fixed" <|
            \_ ->
                Expect.all
                    [ \_ -> render [ Editor.tabbed ] (start "") |> Query.has [ Selector.class "klar-mdeditor--tabs" ]
                    , \_ -> render [ Editor.sideBySide ] (start "") |> Query.has [ Selector.class "klar-mdeditor--split" ]
                    , \_ -> render [] (start "") |> Query.hasNot [ Selector.class "klar-mdeditor--tabs" ]
                    ]
                    ()
        , test "disabled and read only" <|
            \_ ->
                Expect.all
                    [ \_ -> render [ Editor.disabled True ] (start "") |> textarea |> Query.has [ Selector.disabled True ]
                    , \_ -> render [ Editor.readOnly True ] (start "") |> textarea |> Query.has [ Selector.attribute (Attr.readonly True) ]
                    ]
                    ()
        , test "the placeholder" <|
            \_ ->
                render [ Editor.placeholder "Write something" ] (start "")
                    |> textarea
                    |> Query.has [ Selector.attribute (Attr.placeholder "Write something") ]
        , test "the help is there when asked for" <|
            \_ ->
                Expect.all
                    [ \_ -> render [ Editor.syntaxHelp ] (start "") |> Query.has [ Selector.tag "details", Selector.text "Markdown is supported" ]
                    , \_ -> render [] (start "") |> Query.hasNot [ Selector.tag "details" ]
                    ]
                    ()
        , test "the text area stays where it is when an error appears" <|
            \_ ->
                -- it is in the same place in the tree with and without a label, a hint or an error
                let
                    depth attributes =
                        render attributes (start "")
                            |> textarea
                            |> Query.has [ Selector.tag "textarea" ]
                in
                Expect.all
                    [ \_ -> depth []
                    , \_ -> depth [ Editor.error "No" ]
                    ]
                    ()
        ]


shortcutOf : String -> String
shortcutOf name =
    case name of
        "Bold" ->
            " (Ctrl/Cmd+B)"

        "Italic" ->
            " (Ctrl/Cmd+I)"

        "Link" ->
            " (Ctrl/Cmd+K)"

        _ ->
            ""



-- TEXT


textTests : Test
textTests =
    describe "text"
        [ test "the counter" <|
            \_ ->
                render [ Editor.maxLength 20 ] (start "hello")
                    |> Query.has [ Selector.class "klar-textarea__counter", Selector.text "5/20" ]
        , test "the counter says what it counts to a screen reader" <|
            \_ ->
                render [ Editor.maxLength 20 ] (start "hello")
                    |> Query.has [ Selector.text "5 of 20 characters" ]
        , test "no counter without a limit" <|
            \_ ->
                render [] (start "hello")
                    |> Query.hasNot [ Selector.class "klar-textarea__counter" ]
        , test "a text that is too long says so and is not cut" <|
            \_ ->
                let
                    state =
                        start (String.repeat 30 "a")
                in
                render [ Editor.maxLength 20 ] state
                    |> Expect.all
                        [ Query.has [ Selector.class "klar-textarea__counter--over" ]
                        , Query.has [ Selector.text "The text is longer than 20 characters." ]
                        , Query.has [ Selector.text "30/20" ]
                        , textarea >> Query.has [ Selector.attribute (Attr.attribute "aria-invalid" "true") ]
                        , textarea >> Query.hasNot [ Selector.attribute (Attr.maxlength 20) ]
                        ]
        , test "the error of the limit has the same words at every key, so it is heard once" <|
            \_ ->
                Expect.all
                    (List.map
                        (\count ->
                            \_ ->
                                render [ Editor.maxLength 20 ] (start (String.repeat count "a"))
                                    |> Query.find [ Selector.class "klar-field__error" ]
                                    |> Query.has [ Selector.text "The text is longer than 20 characters." ]
                        )
                        [ 21, 25, 26, 400 ]
                    )
                    ()
        , test "the counter is not a live region, and its status speaks only at the limits" <|
            \_ ->
                let
                    status text =
                        render [ Editor.maxLength 20 ] (start text)
                            |> Query.find [ Selector.class "klar-textarea__counter" ]
                            |> Query.find [ Selector.attribute (Attr.attribute "role" "status") ]
                in
                Expect.all
                    [ \_ -> render [ Editor.maxLength 20 ] (start "hello") |> Query.hasNot [ Selector.attribute (Attr.attribute "aria-live" "polite") ]
                    , \_ -> status "hello" |> Query.hasNot [ Selector.text "limit" ]
                    , \_ -> status (String.repeat 18 "a") |> Query.has [ Selector.text "The text is close to the limit of 20 characters." ]
                    , \_ -> status (String.repeat 19 "a") |> Query.has [ Selector.text "The text is close to the limit of 20 characters." ]

                    -- over the limit the error says it, and the status is quiet
                    , \_ -> status (String.repeat 25 "a") |> Query.hasNot [ Selector.text "characters." ]
                    ]
                    ()
        , test "over the limit with an error of the application, the status says it" <|
            \_ ->
                render [ Editor.maxLength 5, Editor.error "Not allowed." ] (start "too long")
                    |> Query.find [ Selector.class "klar-textarea__counter" ]
                    |> Query.find [ Selector.attribute (Attr.attribute "role" "status") ]
                    |> Query.has [ Selector.text "The text is longer than 5 characters." ]
        , test "typing past the limit is allowed" <|
            \_ ->
                typed (String.repeat 25 "a") 25 (start "")
                    |> Editor.value
                    |> String.length
                    |> Expect.equal 25
        , test "the error of the application wins over the error of the limit" <|
            \_ ->
                render [ Editor.maxLength 5, Editor.error "Not allowed." ] (start "too long")
                    |> Expect.all
                        [ Query.has [ Selector.text "Not allowed." ]
                        , Query.find [ Selector.class "klar-field__error" ] >> Query.hasNot [ Selector.text "longer than" ]
                        ]
        , test "a text of exactly the limit is not too long" <|
            \_ ->
                render [ Editor.maxLength 5 ] (start "12345")
                    |> Query.hasNot [ Selector.class "klar-textarea__counter--over" ]
        , test "everything in Norwegian" <|
            \_ ->
                render [ Editor.locale Locale.nb, Editor.maxLength 5, Editor.syntaxHelp ] (start "too long")
                    |> Expect.all
                        [ Query.has [ Selector.attribute (Attr.attribute "aria-label" "Formatering") ]
                        , Query.has [ Selector.attribute (Attr.attribute "aria-label" "Fet") ]
                        , Query.has [ Selector.attribute (Attr.attribute "aria-label" "Oppgaveliste") ]
                        , Query.has [ Selector.text "Skriv" ]
                        , Query.has [ Selector.text "Forhåndsvisning" ]
                        , Query.has [ Selector.text "Teksten er lengre enn 5 tegn." ]
                        , Query.has [ Selector.text "8 av 5 tegn" ]
                        , Query.has [ Selector.text "Markdown støttes" ]
                        ]
        , test "the link text that a button inserts is in the language" <|
            \_ ->
                let
                    state =
                        start "a"

                    viewNb =
                        Query.fromHtml (Editor.view identity [ Editor.locale Locale.nb ] state)

                    click =
                        Encode.object [ ( "target", Encode.object [ ( "ownerDocument", Encode.object [ ( "activeElement", Encode.object [ ( "id", Encode.string "note" ), ( "value", Encode.string "a" ), ( "selectionStart", Encode.int 1 ), ( "selectionEnd", Encode.int 1 ) ] ) ] ) ] ) ]
                in
                viewNb
                    |> Query.find [ Selector.tag "button", Selector.attribute (Attr.attribute "aria-label" "Lenke") ]
                    |> Event.simulate (Event.custom "click" click)
                    |> Event.toResult
                    |> Result.map (\msg -> Editor.update msg state |> Tuple.first |> Editor.value)
                    |> Expect.equal (Ok "a[tekst](https://)")
        ]
