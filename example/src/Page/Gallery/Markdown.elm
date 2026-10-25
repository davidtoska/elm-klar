module Page.Gallery.Markdown exposing (Model, Msg, init, subscriptions, update, view)

{-| Gallery page: the Markdown view, with a document that has every feature and a table
of contents made from its headings; an answer that arrives a few characters at a
time; text that tries to do harm; and the Markdown editor with its preview.
-}

import Browser.Dom as Dom
import Html exposing (Html)
import Html.Attributes as Attr
import Html.Events as Events
import Json.Decode as Decode
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
import Showcase.Config as Config
import Showcase.Doc as Doc
import Showcase.Options as Options
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


view : Config.Config -> Locale -> Model -> Html Msg
view playground locale model =
    Doc.configuredPage playground
        { title = "Markdown"
        , description = "A safe Markdown renderer that copes with unfinished text, and an editor with preview."
        }
        [ documentSection playground locale model
        , streamingSection playground locale model
        , safetySection playground locale model
        , editorSection playground locale model
        , optionsSection playground
        ]


documentSection : Config.Config -> Locale -> Model -> Html Msg
documentSection playground locale model =
    let
        headings =
            Markdown.headings (Options.klarMarkdown playground (List.concat [ Config.keep playground "Markdown" "idPrefix" (Markdown.idPrefix idPrefix) ])) model.document

        entry heading =
            Options.buttonView playground
                (Options.klarButton playground
                    (List.concat
                        [ Config.keep playground "Button" "link" Button.link
                        , Config.keep playground "Button" "small" Button.small
                        , Config.keep playground "Button" "onClick" (Button.onClick (ScrollTo (Markdown.headingId heading)))
                        ]
                    )
                )
                (String.repeat (Markdown.headingLevel heading - 1) "\u{2003}" ++ Markdown.headingText heading)
    in
    Doc.configuredSection playground
        [ "Markdown" ]
        "A document"
        "Headings, paragraphs, emphasis, links, quotes, lists (loose, nested, numbered, tasks), code, tables and images. The parser is part of the library, not the browser: HTML is shown as text, links are checked, and images are links until the page says otherwise. The table of contents is made from Markdown.headings and moves the box to the heading by its id. A link in the text to one of its headings ([the notes](#notes)) gets the prefix, #doc-notes; this showcase is a Browser.application, where such a click is a UrlRequest, so the page draws these links with Markdown.customLink and moves the box itself."
        [ Doc.configuredExample playground
            [ "Markdown" ]
            { title = "Every feature, and a table of contents"
            , description = Just "Wide tables and code scroll inside their own box, and a box that can scroll takes the Tab key. Each paragraph chooses its direction."
            , code = Just """let
    document =
        Markdown.parse model.text
in
Layout.row [ Layout.gap 4 ]
    [ Layout.stack [] (List.map tocEntry (Markdown.headings [ Markdown.idPrefix "doc-" ] document))
    , Markdown.viewDocument [ Markdown.idPrefix "doc-", Markdown.customLink headingLink ] document
    ]

-- in a Browser.application a link is a UrlRequest: the page moves the box itself
headingLink link =
    if String.startsWith "#doc-" link.href then
        Just (Html.a [ Attr.href link.href, Events.preventDefaultOn "click" (Decode.succeed ( ScrollTo (String.dropLeft 1 link.href), True )) ] link.content)

    else
        Nothing"""
            }
            (Layout.row (Options.klarLayout playground (List.concat [ Config.keep playground "Layout" "gap" (Layout.gap 6), Config.keep playground "Layout" "alignStart" Layout.alignStart ]))
                [ Layout.stack (Options.klarLayout playground (List.concat [ Config.keep playground "Layout" "gap" (Layout.gap 1), Config.keep playground "Layout" "alignStart" Layout.alignStart ])) (List.map entry headings)
                , Html.div
                    [ Attr.id boxId
                    , Attr.style "flex" "1 1 420px"
                    , Attr.style "min-width" "0"
                    , Attr.style "max-height" "460px"
                    , Attr.style "overflow" "auto"
                    , Attr.style "padding-right" "12px"
                    ]
                    [ Markdown.viewDocument (Options.klarMarkdown playground (List.concat [ Config.keep playground "Markdown" "locale" (Markdown.locale locale), Config.keep playground "Markdown" "idPrefix" (Markdown.idPrefix idPrefix), Config.keep playground "Markdown" "customLink" (Markdown.customLink headingLink) ])) model.document ]
                ]
            )
        , Doc.configuredExample playground
            [ "Markdown" ]
            { title = "Links of your own: citations"
            , description = Just "Markdown.customLink draws the links that the page wants to draw itself, after the checks of the module, and gives Nothing for the others. Here [1](#cite-1) becomes a button that shows its source. Character references such as &nbsp;, &mdash;, &amp; and &copy; are the characters they stand for, never markup."
            , code = Just """Markdown.view [ Markdown.customLink citation ] answer

citation link =
    if String.startsWith "#cite-" link.href then
        Just (Button.view [ Button.link, Button.small, Button.onClick (Cite (String.dropLeft 6 link.href)) ] (String.dropLeft 6 link.href))

    else
        Nothing"""
            }
            (Layout.stack (Options.klarLayout playground (List.concat [ Config.keep playground "Layout" "gap" (Layout.gap 2) ]))
                [ Markdown.view (Options.klarMarkdown playground (List.concat [ Config.keep playground "Markdown" "locale" (Markdown.locale locale), Config.keep playground "Markdown" "customLink" (Markdown.customLink (citation playground)) ])) Sample.cited
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
        , Doc.configuredExample playground
            [ "Markdown" ]
            { title = "Headings in a page that has headings"
            , description = Just "With headingOffset 2 a # is an h3. The levels stop at h6 and never skip one."
            , code = Just "Markdown.view [ Markdown.headingOffset 2 ] \"# Title\\n\\n## Section\\n\\n#### Detail\""
            }
            (Markdown.view (Options.klarMarkdown playground (List.concat [ Config.keep playground "Markdown" "headingOffset" (Markdown.headingOffset 2) ])) "# Title\n\n## Section\n\n#### Detail, written as level four")
        ]


{-| A link of the document to one of its own headings (`[the notes](#notes)`, which is
`#doc-notes` on the page). The showcase is a `Browser.application`: a click on a link
is a `UrlRequest`, and `Main` leaves fragments that are not routes alone, so the link
moves the box with the document to the heading itself.
-}
headingLink : { href : String, external : Bool, title : String, content : List (Html Msg) } -> Maybe (Html Msg)
headingLink link =
    if String.startsWith ("#" ++ idPrefix) link.href then
        Just
            (Html.a
                [ Attr.href link.href
                , Attr.class "klar-md__link"
                , Events.preventDefaultOn "click" (Decode.succeed ( ScrollTo (String.dropLeft 1 link.href), True ))
                ]
                link.content
            )

    else
        Nothing


{-| The citations of an answer, `[1](#cite-1)`, as buttons that show their source.
-}
citation : Config.Config -> { href : String, external : Bool, title : String, content : List (Html Msg) } -> Maybe (Html Msg)
citation playground link =
    if String.startsWith "#cite-" link.href then
        let
            source =
                String.dropLeft 6 link.href
        in
        Just (Options.buttonView playground (Options.klarButton playground (List.concat [ Config.keep playground "Button" "link" Button.link, Config.keep playground "Button" "small" Button.small, Config.keep playground "Button" "onClick" (Button.onClick (Cite source)) ])) source)

    else
        Nothing


streamingSection : Config.Config -> Locale -> Model -> Html Msg
streamingSection playground locale model =
    let
        shown =
            String.left model.revealed Sample.answer

        total =
            String.length Sample.answer
    in
    Doc.configuredSection playground
        [ "Markdown" ]
        "Text that is still arriving"
        "The same function reads every prefix of the text. An open bold, an open code span, a link whose address has not come, a half table row and an open code fence are shown as far as they go, and what is complete does not move. The text is cut in the middle of the emoji at the end on purpose: half of a character is left out until the rest arrives."
        [ Doc.configuredExample playground
            [ "Markdown" ]
            { title = "An answer, a few characters at a time"
            , description = Just "Pause it anywhere, or restart. Left: the text as it has arrived. Right: what the reader sees."
            , code = Just """-- every tick: model.shown = model.shown + 3
Markdown.view [] (String.left model.shown answer)"""
            }
            (Layout.stack (Options.klarLayout playground (List.concat [ Config.keep playground "Layout" "gap" (Layout.gap 4) ]))
                [ Layout.row (Options.klarLayout playground (List.concat [ Config.keep playground "Layout" "gap" (Layout.gap 2), Config.keep playground "Layout" "alignCenter" Layout.alignCenter ]))
                    [ Options.buttonView playground (Options.klarButton playground (List.concat [ Config.keep playground "Button" "icon" (Button.icon Icon.refresh), Config.keep playground "Button" "onClick" (Button.onClick Restart) ])) "Restart"
                    , Options.buttonView playground
                        (Options.klarButton playground
                            (List.concat
                                [ Config.keep playground
                                    "Button"
                                    "icon"
                                    (Button.icon
                                        (if model.running then
                                            Icon.pause

                                         else
                                            Icon.play
                                        )
                                    )
                                , Config.keep playground "Button" "disabled" (Button.disabled (not model.running && model.revealed >= total))
                                , Config.keep playground "Button" "onClick" (Button.onClick PauseOrResume)
                                ]
                            )
                        )
                        (if model.running then
                            "Pause"

                         else
                            "Continue"
                        )
                    , Text.muted (Format.int locale model.revealed ++ " of " ++ Format.int locale total ++ " characters")
                    ]
                , Layout.grid (Options.klarLayout playground (List.concat [ Config.keep playground "Layout" "minColumn" (Layout.minColumn 320), Config.keep playground "Layout" "gap" (Layout.gap 4) ]))
                    [ Html.div []
                        [ Text.overline "As it arrives"
                        , Text.codeBlock shown
                        ]
                    , Html.div []
                        [ Text.overline "As it is read"
                        , Markdown.view (Options.klarMarkdown playground (List.concat [ Config.keep playground "Markdown" "locale" (Markdown.locale locale) ])) shown
                        ]
                    ]
                ]
            )
        ]


safetySection : Config.Config -> Locale -> Model -> Html Msg
safetySection playground locale model =
    Doc.configuredSection playground
        [ "Markdown" ]
        "Text you do not trust"
        "Edit the text, or leave it. A script, a tag with an event handler, a link that runs code, a link to a page of its own and a picture that tells another server that you read this are all shown as what they are. Links that may be followed carry rel=\"noopener noreferrer\" and a small arrow."
        [ Doc.configuredExample playground
            [ "Markdown" ]
            { title = "Harmful text, rendered harmlessly"
            , description = Just "Images are not loaded unless you turn them on. The image address here is made up and goes nowhere."
            , code = Just """Markdown.view [] text

-- images from anywhere, or from the hosts you trust
Markdown.view [ Markdown.images ] text
Markdown.view [ Markdown.imagesFrom (List.filterMap Markdown.imageHost [ "cdn.example.com" ]) ] text"""
            }
            (Layout.stack (Options.klarLayout playground (List.concat [ Config.keep playground "Layout" "gap" (Layout.gap 4) ]))
                [ Layout.grid (Options.klarLayout playground (List.concat [ Config.keep playground "Layout" "minColumn" (Layout.minColumn 320), Config.keep playground "Layout" "gap" (Layout.gap 4) ]))
                    [ TextArea.view
                        (Options.klarTextArea playground
                            (List.concat
                                [ Config.keep playground "TextArea" "label" (TextArea.label "Text")
                                , Config.keep playground "TextArea" "id" (TextArea.id "md-harmful")
                                , Config.keep playground "TextArea" "rows" (TextArea.rows 9)
                                , Config.keep playground "TextArea" "value" (TextArea.value model.harmful)
                                , Config.keep playground "TextArea" "onInput" (TextArea.onInput HarmfulChanged)
                                ]
                            )
                        )
                    , Html.div []
                        [ Text.overline "As it is read"
                        , Markdown.view
                            (Markdown.locale locale
                                :: (if model.loadImages then
                                        Options.klarMarkdown playground (List.concat [ Config.keep playground "Markdown" "images" Markdown.images ])

                                    else
                                        []
                                   )
                            )
                            model.harmful
                        ]
                    ]
                , Checkbox.view
                    (Options.klarCheckbox playground
                        (List.concat
                            [ Config.keep playground "Checkbox" "label" (Checkbox.label "Load images (Markdown.images)")
                            , Config.keep playground "Checkbox" "hint" (Checkbox.hint "Only for text you trust: the picture is fetched from another server.")
                            , Config.keep playground "Checkbox" "checked" (Checkbox.checked model.loadImages)
                            , Config.keep playground "Checkbox" "onCheck" (Checkbox.onCheck ImagesToggled)
                            ]
                        )
                    )
                ]
            )
        ]


editorSection : Config.Config -> Locale -> Model -> Html Msg
editorSection playground locale model =
    Doc.configuredSection playground
        [ "MarkdownEditor" ]
        "The editor"
        "A text area with a toolbar and a preview that follows the text. The container decides the layout: side by side when it is wide, two tabs when it is narrow. The buttons and Ctrl B, Ctrl I and Ctrl K act on the selection and give it back, so pressing a button twice undoes it. Ctrl Z undoes the last changes of the buttons. Nothing is cut off at the limit: the counter turns red and an error says by how much."
        [ Doc.configuredExample playground
            [ "MarkdownEditor" ]
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
            (Layout.stack (Options.klarLayout playground (List.concat [ Config.keep playground "Layout" "gap" (Layout.gap 3) ]))
                [ MarkdownEditor.view WideMsg (editorAttributes playground locale) model.wide
                , Layout.row (Options.klarLayout playground (List.concat [ Config.keep playground "Layout" "gap" (Layout.gap 2), Config.keep playground "Layout" "alignCenter" Layout.alignCenter ]))
                    [ Options.buttonView playground (Options.klarButton playground (List.concat [ Config.keep playground "Button" "small" Button.small, Config.keep playground "Button" "onClick" (Button.onClick LoadSample) ])) "Load the sample"
                    , Options.buttonView playground (Options.klarButton playground (List.concat [ Config.keep playground "Button" "small" Button.small, Config.keep playground "Button" "onClick" (Button.onClick ClearEditors) ])) "Clear"
                    , Text.muted (Format.int locale (String.length (MarkdownEditor.value model.wide)) ++ " characters in the model")
                    ]
                ]
            )
        , Doc.configuredExample playground
            [ "MarkdownEditor" ]
            { title = "Narrow: tabs"
            , description = Just "The same editor in a column of 380 pixels. Write and Preview are tabs; the arrow keys move between them."
            , code = Just "MarkdownEditor.view DescriptionMsg [ MarkdownEditor.label \"Description\" ] model.description"
            }
            (Layout.container (Options.klarLayout playground (List.concat [ Config.keep playground "Layout" "maxWidth" (Layout.maxWidth 380) ]))
                [ MarkdownEditor.view NarrowMsg (editorAttributes playground locale) model.narrow ]
            )
        , Doc.configuredExample playground
            [ "MarkdownEditor" ]
            { title = "States"
            , description = Just "Read only, disabled, and with an error from the application."
            , code = Nothing
            }
            (Layout.stack (Options.klarLayout playground (List.concat [ Config.keep playground "Layout" "gap" (Layout.gap 4) ]))
                [ MarkdownEditor.view LockedMsg
                    (Options.klarMarkdownEditor playground (List.concat [ Config.keep playground "MarkdownEditor" "label" (MarkdownEditor.label "Read only"), Config.keep playground "MarkdownEditor" "readOnly" (MarkdownEditor.readOnly True), Config.keep playground "MarkdownEditor" "rows" (MarkdownEditor.rows 4), Config.keep playground "MarkdownEditor" "locale" (MarkdownEditor.locale locale) ]))
                    model.locked
                , MarkdownEditor.view ErroredMsg
                    (Options.klarMarkdownEditor playground
                        (List.concat
                            [ Config.keep playground "MarkdownEditor" "label" (MarkdownEditor.label "With an error")
                            , Config.keep playground
                                "MarkdownEditor"
                                "errorMaybe"
                                (MarkdownEditor.errorMaybe
                                    (if String.trim (MarkdownEditor.value model.errored) == "" then
                                        Just "A description is needed before the order can be saved."

                                     else
                                        Nothing
                                    )
                                )
                            , Config.keep playground "MarkdownEditor" "required" MarkdownEditor.required
                            , Config.keep playground "MarkdownEditor" "rows" (MarkdownEditor.rows 4)
                            , Config.keep playground "MarkdownEditor" "sideBySide" MarkdownEditor.sideBySide
                            , Config.keep playground "MarkdownEditor" "locale" (MarkdownEditor.locale locale)
                            ]
                        )
                    )
                    model.errored
                ]
            )
        ]


editorAttributes : Config.Config -> Locale -> List (MarkdownEditor.Attribute msg)
editorAttributes playground locale =
    Options.klarMarkdownEditor playground
        (List.concat
            [ Config.keep playground "MarkdownEditor" "label" (MarkdownEditor.label "Description")
            , Config.keep playground "MarkdownEditor" "hint" (MarkdownEditor.hint "Shown on the packing slip. Markdown is supported.")
            , Config.keep playground "MarkdownEditor" "maxLength" (MarkdownEditor.maxLength 400)
            , Config.keep playground "MarkdownEditor" "rows" (MarkdownEditor.rows 9)
            , Config.keep playground "MarkdownEditor" "syntaxHelp" MarkdownEditor.syntaxHelp
            , Config.keep playground "MarkdownEditor" "locale" (MarkdownEditor.locale locale)
            ]
        )


optionsSection : Config.Config -> Html Msg
optionsSection playground =
    Doc.configuredSection playground
        [ "Markdown" ]
        "Options"
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
