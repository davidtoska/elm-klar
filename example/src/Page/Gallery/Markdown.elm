module Page.Gallery.Markdown exposing (Model, Msg, init, subscriptions, update, view)

{-| Gallery page: the Markdown view, with a document that has every feature and a table
of contents made from its headings; an answer that arrives a few characters at a
time; text that tries to do harm; and the Markdown editor with its preview.
-}

import Browser.Dom as Dom
import Html exposing (Html)
import Html.Attributes as Attr
import Klar.Button as Button
import Klar.Checkbox as Checkbox
import Klar.Format as Format
import Klar.Icon as Icon
import Klar.Layout as Layout
import Klar.Locale as Locale exposing (Locale)
import Klar.Markdown as Markdown
import Klar.MarkdownEditor as MarkdownEditor
import Klar.Text as Text
import Klar.TextArea as TextArea
import Page.Gallery.Markdown.Sample as Sample
import Showcase.Doc as Doc
import Task
import Time



-- MODEL


type alias Model =
    { document : Markdown.Document
    , revealed : Int
    , running : Bool
    , harmful : String
    , loadImages : Bool
    , wide : MarkdownEditor.State
    , narrow : MarkdownEditor.State
    , errored : MarkdownEditor.State
    , locked : MarkdownEditor.State
    , cited : Maybe String
    }


type Msg
    = Tick
    | Restart
    | PauseOrResume
    | HarmfulChanged String
    | ImagesToggled Bool
    | WideMsg MarkdownEditor.Msg
    | NarrowMsg MarkdownEditor.Msg
    | ErroredMsg MarkdownEditor.Msg
    | LockedMsg MarkdownEditor.Msg
    | LoadSample
    | ClearEditors
    | ScrollTo String
    | Scrolled
    | Cite String


init : ( Model, Cmd Msg )
init =
    ( { document = Markdown.parse Sample.document
      , revealed = 0
      , running = True
      , harmful = Sample.unsafe
      , loadImages = False
      , wide = MarkdownEditor.init "md-wide" |> MarkdownEditor.setValue Sample.note
      , narrow = MarkdownEditor.init "md-narrow" |> MarkdownEditor.setValue Sample.note
      , errored = MarkdownEditor.init "md-error"
      , locked = MarkdownEditor.init "md-locked" |> MarkdownEditor.setValue Sample.note
      , cited = Nothing
      }
    , Cmd.none
    )


{-| Three characters at a time, every 40 milliseconds: about the speed of a model.
-}
step : Int
step =
    3


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        Tick ->
            let
                revealed =
                    min (String.length Sample.answer) (model.revealed + step)
            in
            ( { model | revealed = revealed, running = revealed < String.length Sample.answer }, Cmd.none )

        Restart ->
            ( { model | revealed = 0, running = True }, Cmd.none )

        PauseOrResume ->
            ( { model | running = not model.running && model.revealed < String.length Sample.answer }, Cmd.none )

        HarmfulChanged text ->
            ( { model | harmful = text }, Cmd.none )

        ImagesToggled on ->
            ( { model | loadImages = on }, Cmd.none )

        WideMsg inner ->
            let
                ( wide, cmd ) =
                    MarkdownEditor.update inner model.wide
            in
            ( { model | wide = wide }, Cmd.map WideMsg cmd )

        NarrowMsg inner ->
            let
                ( narrow, cmd ) =
                    MarkdownEditor.update inner model.narrow
            in
            ( { model | narrow = narrow }, Cmd.map NarrowMsg cmd )

        ErroredMsg inner ->
            let
                ( errored, cmd ) =
                    MarkdownEditor.update inner model.errored
            in
            ( { model | errored = errored }, Cmd.map ErroredMsg cmd )

        LockedMsg inner ->
            let
                ( locked, cmd ) =
                    MarkdownEditor.update inner model.locked
            in
            ( { model | locked = locked }, Cmd.map LockedMsg cmd )

        LoadSample ->
            ( { model
                | wide = MarkdownEditor.setValue Sample.note model.wide
                , narrow = MarkdownEditor.setValue Sample.note model.narrow
              }
            , Cmd.none
            )

        ClearEditors ->
            ( { model
                | wide = MarkdownEditor.setValue "" model.wide
                , narrow = MarkdownEditor.setValue "" model.narrow
              }
            , Cmd.none
            )

        ScrollTo id ->
            ( model, scrollTo id )

        Scrolled ->
            ( model, Cmd.none )

        Cite source ->
            ( { model | cited = Just source }, Cmd.none )


{-| Scrolls the box with the document so that the heading is at its top.
-}
scrollTo : String -> Cmd Msg
scrollTo id =
    Task.map3
        (\box boxElement heading -> box.viewport.y + heading.element.y - boxElement.element.y - 4)
        (Dom.getViewportOf boxId)
        (Dom.getElement boxId)
        (Dom.getElement id)
        |> Task.andThen (Dom.setViewportOf boxId 0)
        |> Task.attempt (\_ -> Scrolled)


boxId : String
boxId =
    "md-document-box"


idPrefix : String
idPrefix =
    "doc-"


subscriptions : Model -> Sub Msg
subscriptions model =
    if model.running then
        Time.every 40 (\_ -> Tick)

    else
        Sub.none



-- VIEW


view : Locale -> Model -> Html Msg
view locale model =
    Doc.page
        { title = "Markdown"
        , description = "A safe Markdown renderer that copes with unfinished text, and an editor with preview."
        }
        [ documentSection locale model
        , streamingSection locale model
        , safetySection locale model
        , editorSection locale model
        , optionsSection
        ]


documentSection : Locale -> Model -> Html Msg
documentSection locale model =
    let
        headings =
            Markdown.headings [ Markdown.idPrefix idPrefix ] model.document

        entry heading =
            Button.view
                [ Button.link
                , Button.small
                , Button.onClick (ScrollTo (Markdown.headingId heading))
                ]
                (String.repeat (Markdown.headingLevel heading - 1) "\u{2003}" ++ Markdown.headingText heading)
    in
    Doc.section "A document"
        "Headings, paragraphs, emphasis, links, quotes, lists (loose, nested, numbered, tasks), code, tables and images. The parser is part of the library, not the browser: HTML is shown as text, links are checked, and images are links until the page says otherwise. The table of contents is made from Markdown.headings and moves the box to the heading by its id."
        [ Doc.example
            { title = "Every feature, and a table of contents"
            , description = Just "Wide tables and code scroll inside their own box, and a box that can scroll takes the Tab key. Each paragraph chooses its direction."
            , code = Just """let
    document =
        Markdown.parse model.text
in
Layout.row [ Layout.gap 4 ]
    [ Layout.stack [] (List.map tocEntry (Markdown.headings [ Markdown.idPrefix "doc-" ] document))
    , Markdown.viewDocument [ Markdown.idPrefix "doc-" ] document
    ]"""
            }
            (Layout.row [ Layout.gap 6, Layout.alignStart ]
                [ Layout.stack [ Layout.gap 1, Layout.alignStart ] (List.map entry headings)
                , Html.div
                    [ Attr.id boxId
                    , Attr.style "flex" "1 1 420px"
                    , Attr.style "min-width" "0"
                    , Attr.style "max-height" "460px"
                    , Attr.style "overflow" "auto"
                    , Attr.style "padding-right" "12px"
                    ]
                    [ Markdown.viewDocument [ Markdown.locale locale, Markdown.idPrefix idPrefix ] model.document ]
                ]
            )
        , Doc.example
            { title = "Links of your own: citations"
            , description = Just "Markdown.customLink draws the links that the page wants to draw itself, after the checks of the module, and gives Nothing for the others. Here [1](#cite-1) becomes a button that shows its source. Character references such as &nbsp;, &mdash;, &amp; and &copy; are the characters they stand for, never markup. A link in the text to one of its headings ([Pricing](#pricing)) goes to the id of that heading, with the prefix."
            , code = Just """Markdown.view [ Markdown.customLink citation ] answer

citation link =
    if String.startsWith "#cite-" link.href then
        Just (Button.view [ Button.link, Button.small, Button.onClick (Cite (String.dropLeft 6 link.href)) ] (String.dropLeft 6 link.href))

    else
        Nothing"""
            }
            (Layout.stack [ Layout.gap 2 ]
                [ Markdown.view [ Markdown.locale locale, Markdown.customLink citation ] Sample.cited
                , Text.caption
                    (case model.cited of
                        Just "1" ->
                            "Source 1: the price list of spring 2026."

                        Just "2" ->
                            "Source 2: the delivery plan for the Oslo warehouse."

                        Just other ->
                            "Source " ++ other

                        Nothing ->
                            "Press a number to see its source."
                    )
                ]
            )
        , Doc.example
            { title = "Headings in a page that has headings"
            , description = Just "With headingOffset 2 a # is an h3. The levels stop at h6 and never skip one."
            , code = Just "Markdown.view [ Markdown.headingOffset 2 ] \"# Title\\n\\n## Section\\n\\n#### Detail\""
            }
            (Markdown.view [ Markdown.headingOffset 2 ] "# Title\n\n## Section\n\n#### Detail, written as level four")
        ]


{-| The citations of an answer, `[1](#cite-1)`, as buttons that show their source.
-}
citation : { href : String, external : Bool, title : String, content : List (Html Msg) } -> Maybe (Html Msg)
citation link =
    if String.startsWith "#cite-" link.href then
        let
            source =
                String.dropLeft 6 link.href
        in
        Just (Button.view [ Button.link, Button.small, Button.onClick (Cite source) ] source)

    else
        Nothing


streamingSection : Locale -> Model -> Html Msg
streamingSection locale model =
    let
        shown =
            String.left model.revealed Sample.answer

        total =
            String.length Sample.answer
    in
    Doc.section "Text that is still arriving"
        "The same function reads every prefix of the text. An open bold, an open code span, a link whose address has not come, a half table row and an open code fence are shown as far as they go, and what is complete does not move. The text is cut in the middle of the emoji at the end on purpose: half of a character is left out until the rest arrives."
        [ Doc.example
            { title = "An answer, a few characters at a time"
            , description = Just "Pause it anywhere, or restart. Left: the text as it has arrived. Right: what the reader sees."
            , code = Just """-- every tick: model.shown = model.shown + 3
Markdown.view [] (String.left model.shown answer)"""
            }
            (Layout.stack [ Layout.gap 4 ]
                [ Layout.row [ Layout.gap 2, Layout.alignCenter ]
                    [ Button.view [ Button.icon Icon.refresh, Button.onClick Restart ] "Restart"
                    , Button.view
                        [ Button.icon
                            (if model.running then
                                Icon.pause

                             else
                                Icon.play
                            )
                        , Button.disabled (not model.running && model.revealed >= total)
                        , Button.onClick PauseOrResume
                        ]
                        (if model.running then
                            "Pause"

                         else
                            "Continue"
                        )
                    , Text.muted (Format.int locale model.revealed ++ " of " ++ Format.int locale total ++ " characters")
                    ]
                , Layout.grid [ Layout.minColumn 320, Layout.gap 4 ]
                    [ Html.div []
                        [ Text.overline "As it arrives"
                        , Text.codeBlock shown
                        ]
                    , Html.div []
                        [ Text.overline "As it is read"
                        , Markdown.view [ Markdown.locale locale ] shown
                        ]
                    ]
                ]
            )
        ]


safetySection : Locale -> Model -> Html Msg
safetySection locale model =
    Doc.section "Text you do not trust"
        "Edit the text, or leave it. A script, a tag with an event handler, a link that runs code, a link to a page of its own and a picture that tells another server that you read this are all shown as what they are. Links that may be followed carry rel=\"noopener noreferrer\" and a small arrow."
        [ Doc.example
            { title = "Harmful text, rendered harmlessly"
            , description = Just "Images are not loaded unless you turn them on. The image address here is made up and goes nowhere."
            , code = Just """Markdown.view [] text

-- images from anywhere, or from the hosts you trust
Markdown.view [ Markdown.images ] text
Markdown.view [ Markdown.imagesFrom (List.filterMap Markdown.imageHost [ "cdn.example.com" ]) ] text"""
            }
            (Layout.stack [ Layout.gap 4 ]
                [ Layout.grid [ Layout.minColumn 320, Layout.gap 4 ]
                    [ TextArea.view
                        [ TextArea.label "Text"
                        , TextArea.id "md-harmful"
                        , TextArea.rows 9
                        , TextArea.value model.harmful
                        , TextArea.onInput HarmfulChanged
                        ]
                    , Html.div []
                        [ Text.overline "As it is read"
                        , Markdown.view
                            (Markdown.locale locale
                                :: (if model.loadImages then
                                        [ Markdown.images ]

                                    else
                                        []
                                   )
                            )
                            model.harmful
                        ]
                    ]
                , Checkbox.view
                    [ Checkbox.label "Load images (Markdown.images)"
                    , Checkbox.hint "Only for text you trust: the picture is fetched from another server."
                    , Checkbox.checked model.loadImages
                    , Checkbox.onCheck ImagesToggled
                    ]
                ]
            )
        ]


editorSection : Locale -> Model -> Html Msg
editorSection locale model =
    Doc.section "The editor"
        "A text area with a toolbar and a preview that follows the text. The container decides the layout: side by side when it is wide, two tabs when it is narrow. The buttons and Ctrl B, Ctrl I and Ctrl K act on the selection and give it back, so pressing a button twice undoes it. Ctrl Z undoes the last changes of the buttons. Nothing is cut off at the limit: the counter turns red and an error says by how much."
        [ Doc.example
            { title = "Wide: side by side"
            , description = Just "Select a word and press Ctrl B, or a line and press the list button. Paste a long text to see the counter."
            , code = Just """MarkdownEditor.view DescriptionMsg
    [ MarkdownEditor.label "Description"
    , MarkdownEditor.hint "Shown on the packing slip."
    , MarkdownEditor.maxLength 400
    , MarkdownEditor.syntaxHelp
    ]
    model.description"""
            }
            (Layout.stack [ Layout.gap 3 ]
                [ MarkdownEditor.view WideMsg (editorAttributes locale) model.wide
                , Layout.row [ Layout.gap 2, Layout.alignCenter ]
                    [ Button.view [ Button.small, Button.onClick LoadSample ] "Load the sample"
                    , Button.view [ Button.small, Button.onClick ClearEditors ] "Clear"
                    , Text.muted (Format.int locale (String.length (MarkdownEditor.value model.wide)) ++ " characters in the model")
                    ]
                ]
            )
        , Doc.example
            { title = "Narrow: tabs"
            , description = Just "The same editor in a column of 380 pixels. Write and Preview are tabs; the arrow keys move between them."
            , code = Just "MarkdownEditor.view DescriptionMsg [ MarkdownEditor.label \"Description\" ] model.description"
            }
            (Layout.container [ Layout.maxWidth 380 ]
                [ MarkdownEditor.view NarrowMsg (editorAttributes locale) model.narrow ]
            )
        , Doc.example
            { title = "States"
            , description = Just "Read only, disabled, and with an error from the application."
            , code = Nothing
            }
            (Layout.stack [ Layout.gap 4 ]
                [ MarkdownEditor.view LockedMsg
                    [ MarkdownEditor.label "Read only", MarkdownEditor.readOnly True, MarkdownEditor.rows 4, MarkdownEditor.locale locale ]
                    model.locked
                , MarkdownEditor.view ErroredMsg
                    [ MarkdownEditor.label "With an error"
                    , MarkdownEditor.errorMaybe
                        (if String.trim (MarkdownEditor.value model.errored) == "" then
                            Just "A description is needed before the order can be saved."

                         else
                            Nothing
                        )
                    , MarkdownEditor.required
                    , MarkdownEditor.rows 4
                    , MarkdownEditor.sideBySide
                    , MarkdownEditor.locale locale
                    ]
                    model.errored
                ]
            )
        ]


editorAttributes : Locale -> List (MarkdownEditor.Attribute msg)
editorAttributes locale =
    [ MarkdownEditor.label "Description"
    , MarkdownEditor.hint "Shown on the packing slip. Markdown is supported."
    , MarkdownEditor.maxLength 400
    , MarkdownEditor.rows 9
    , MarkdownEditor.syntaxHelp
    , MarkdownEditor.locale locale
    ]


optionsSection : Html Msg
optionsSection =
    Doc.section "Options"
        ""
        [ Doc.props
            [ { name = "Markdown.view"
              , type_ = "List Attribute -> String -> Html msg"
              , description = "The text as HTML. Parse once with Markdown.parse and show with viewDocument when the text is shown again and again."
              }
            , { name = "Markdown.headings"
              , type_ = "Document -> List Heading"
              , description = "Level, text and id of every heading, for a table of contents. Ids are unique in the document and start with the idPrefix: md-intro, md-intro-1."
              }
            , { name = "Markdown.plainText"
              , type_ = "Document -> String"
              , description = "The text without markup, for search and previews."
              }
            , { name = "Markdown.headingOffset"
              , type_ = "Int -> Attribute"
              , description = "Moves every heading down, 0 to 5 levels; never past h6 and never with a gap."
              }
            , { name = "Markdown.images / imagesFrom"
              , type_ = "Attribute / List String -> Attribute"
              , description = "Load images from anywhere, or from the hosts made with imageHost. Default: an image is a link with its description."
              }
            , { name = "Markdown.idPrefix"
              , type_ = "String -> Attribute"
              , description = "Text before every heading id (default md-), for a page with several documents. Text from others cannot make an element with an id of the page."
              }
            , { name = "MarkdownEditor.maxLength"
              , type_ = "Int -> Attribute msg"
              , description = "A counter and an error when the text is longer. Nothing is cut."
              }
            , { name = "MarkdownEditor.tabbed / sideBySide"
              , type_ = "Attribute msg"
              , description = "Fix the layout. Default: it follows the width of the container."
              }
            , { name = "MarkdownEditor.preview"
              , type_ = "List (Markdown.Attribute msg) -> Attribute msg"
              , description = "Attributes of the preview, such as images."
              }
            , { name = "MarkdownEditor.setValue"
              , type_ = "String -> State -> State"
              , description = "Replace the text, for example after a save."
              }
            ]
        ]
