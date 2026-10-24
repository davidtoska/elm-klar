module Page.Gallery.Foundations exposing (Model, Msg, init, subscriptions, update, view)

{-| Gallery page: colors, typography, icons, layout and cards. Only the icon
search has state.
-}

import Api.Types as Types exposing (OrderStatus(..))
import Html exposing (Html)
import Klar.Badge as Badge
import Klar.Button as Button
import Klar.Card as Card
import Klar.Date as Date
import Klar.EmptyState as EmptyState
import Klar.Format as Format
import Klar.Icon as Icon exposing (Icon)
import Klar.Icon.Library as Library
import Klar.Kbd as Kbd
import Klar.Layout as Layout
import Klar.Locale exposing (Locale)
import Klar.Search as Search
import Klar.Shortcut as Shortcut
import Klar.Tag as Tag
import Klar.Text as Text
import Klar.TextInput as TextInput
import Klar.Theme exposing (Tone(..))
import Showcase.Doc as Doc
import Showcase.Sample as Sample
import View.Labels as Labels



-- MODEL


type alias Model =
    { iconQuery : String
    }


type Msg
    = IconQueryChanged String


init : ( Model, Cmd Msg )
init =
    ( { iconQuery = "" }, Cmd.none )


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        IconQueryChanged query ->
            ( { model | iconQuery = query }, Cmd.none )


subscriptions : Model -> Sub Msg
subscriptions _ =
    Sub.none



-- VIEW


view : Locale -> Model -> Html Msg
view locale model =
    Doc.page
        { title = "Foundations"
        , description = "The colors, typography, icons, layout primitives and cards that everything else is built from. Gray, white and blue, with thin gray lines and small radii."
        }
        [ colors
        , typography locale
        , icons locale model.iconQuery
        , layout
        , cards locale
        ]



-- COLORS


colors : Html Msg
colors =
    Doc.section "Colors"
        "Every color is a design token, a CSS custom property. Components never use fixed color codes, so redefining a few tokens gives the whole library a new look."
        [ Doc.example
            { title = "Gray (neutral)"
            , description = Just "Surfaces, lines and text. Lines are 1px in --klar-gray-200 or --klar-gray-300."
            , code = Nothing
            }
            (swatches grayScale)
        , Doc.example
            { title = "Blue (primary)"
            , description = Just "Primary actions, focus and the selected state. 600 is the default."
            , code = Nothing
            }
            (swatches blueScale)
        , Doc.example
            { title = "Status"
            , description = Just "Muted colors for success, warning and error. 600 is the main color, 50 the tinted background and 100 its border; 500 and 700 are a lighter and a darker step."
            , code = Nothing
            }
            (Layout.stack [ Layout.gap 4 ]
                [ swatches greenScale
                , swatches amberScale
                , swatches redScale
                ]
            )
        , Doc.example
            { title = "Semantic tokens: surfaces and text"
            , description = Just "What the components actually use. Each token points at a color of the palette, shown under its name. To restyle the library, put your own CSS after the library's stylesheet and redefine tokens on :root for the whole page, or on a container for part of it."
            , code = Just """:root {
  --klar-primary: #0b7285;
  --klar-primary-hover: #095c6b;
  --klar-font: "Inter", system-ui, sans-serif;
}"""
            }
            (swatches surfaceTokens)
        , Doc.example
            { title = "Semantic tokens: tones"
            , description = Just "The colors of the tones Primary, Info, Success, Warning and Danger (Neutral is gray). Each tone also has a -subtle token for backgrounds and a -border token, for example --klar-success-subtle."
            , code = Nothing
            }
            (swatches toneTokens)
        ]


swatches : List ( String, String, Bool ) -> Html Msg
swatches tokens =
    Layout.grid [ Layout.minColumn 120, Layout.gap 3 ]
        (List.map
            (\( token, value, textOnColor ) ->
                Doc.swatch { token = token, value = value, textOnColor = textOnColor }
            )
            tokens
        )


{-| Token, value and whether text on the color should be light.
-}
grayScale : List ( String, String, Bool )
grayScale =
    [ ( "--klar-white", "#ffffff", False )
    , ( "--klar-gray-25", "#fafbfc", False )
    , ( "--klar-gray-50", "#f5f7f9", False )
    , ( "--klar-gray-100", "#edf0f4", False )
    , ( "--klar-gray-150", "#e4e8ee", False )
    , ( "--klar-gray-200", "#d9dfe6", False )
    , ( "--klar-gray-300", "#c6ced8", False )
    , ( "--klar-gray-400", "#9ea9b7", False )
    , ( "--klar-gray-500", "#7a8696", True )
    , ( "--klar-gray-600", "#5d6978", True )
    , ( "--klar-gray-700", "#455060", True )
    , ( "--klar-gray-800", "#2e3744", True )
    , ( "--klar-gray-900", "#1b222c", True )
    ]


blueScale : List ( String, String, Bool )
blueScale =
    [ ( "--klar-blue-50", "#eff5fc", False )
    , ( "--klar-blue-100", "#dde9f7", False )
    , ( "--klar-blue-200", "#bfd5ef", False )
    , ( "--klar-blue-300", "#94b9e3", False )
    , ( "--klar-blue-400", "#5f95d3", False )
    , ( "--klar-blue-500", "#2f74bf", True )
    , ( "--klar-blue-600", "#1560b0", True )
    , ( "--klar-blue-700", "#0f4f93", True )
    , ( "--klar-blue-800", "#0c3d73", True )
    , ( "--klar-blue-900", "#082a50", True )
    ]


greenScale : List ( String, String, Bool )
greenScale =
    [ ( "--klar-green-50", "#ecf7f1", False )
    , ( "--klar-green-100", "#d3eddf", False )
    , ( "--klar-green-500", "#2a9461", True )
    , ( "--klar-green-600", "#1e7d50", True )
    , ( "--klar-green-700", "#17653f", True )
    ]


amberScale : List ( String, String, Bool )
amberScale =
    [ ( "--klar-amber-50", "#fff7e6", False )
    , ( "--klar-amber-100", "#ffecc2", False )
    , ( "--klar-amber-500", "#d98a0b", False )
    , ( "--klar-amber-600", "#9a5f06", True )
    , ( "--klar-amber-700", "#8f5806", True )
    ]


redScale : List ( String, String, Bool )
redScale =
    [ ( "--klar-red-50", "#fdf0ee", False )
    , ( "--klar-red-100", "#fadad6", False )
    , ( "--klar-red-500", "#d6453a", True )
    , ( "--klar-red-600", "#bd352b", True )
    , ( "--klar-red-700", "#962a22", True )
    ]


surfaceTokens : List ( String, String, Bool )
surfaceTokens =
    [ ( "--klar-bg", "gray-50", False )
    , ( "--klar-surface", "white", False )
    , ( "--klar-surface-sunken", "gray-100", False )
    , ( "--klar-border", "gray-200", False )
    , ( "--klar-border-strong", "gray-300", False )
    , ( "--klar-text", "gray-900", True )
    , ( "--klar-text-secondary", "gray-700", True )
    , ( "--klar-text-muted", "gray-600", True )
    , ( "--klar-text-disabled", "gray-400", False )
    , ( "--klar-text-link", "blue-600", True )
    ]


toneTokens : List ( String, String, Bool )
toneTokens =
    [ ( "--klar-primary", "blue-600", True )
    , ( "--klar-primary-hover", "blue-700", True )
    , ( "--klar-primary-subtle", "blue-50", False )
    , ( "--klar-info", "blue-600", True )
    , ( "--klar-info-subtle", "blue-50", False )
    , ( "--klar-success", "green-600", True )
    , ( "--klar-success-subtle", "green-50", False )
    , ( "--klar-warning", "amber-600", True )
    , ( "--klar-warning-subtle", "amber-50", False )
    , ( "--klar-danger", "red-600", True )
    , ( "--klar-danger-hover", "red-700", True )
    , ( "--klar-danger-subtle", "red-50", False )
    ]



-- TYPOGRAPHY


typography : Locale -> Html Msg
typography locale =
    Doc.section "Typography"
        "The system font (Segoe UI on Windows) at 13px, for dense interfaces. Digits in counters, pagination and charts are tabular, so numbers line up."
        [ headings
        , inlineText locale
        , codeAndKeys
        ]


headings : Html Msg
headings =
    Doc.example
        { title = "Headings and body text"
        , description = Just "title is the h1, heading an h2 and subheading an h3, so the outline of the page is right for screen readers. Use title once per page: this gallery page already has one."
        , code = Just """Layout.stack [ Layout.gap 3 ]
    [ Text.overline "Overview"
    , Text.title "Orders and fulfillment"
    , Text.lead "A short introduction that puts the page in context."
    , Text.heading "Recent activity"
    , Text.paragraph "Body text is set at 13px ..."
    , Text.subheading "Details"
    , Layout.row [ Layout.gap 4, Layout.wrap ]
        [ Text.secondary "Secondary text"
        , Text.muted "Muted text for hints and metadata"
        , Text.caption "Small caption"
        , Text.strong "Bold text"
        ]
    ]"""
        }
        (Layout.stack [ Layout.gap 3 ]
            [ Text.overline "Overview"
            , Text.title "Orders and fulfillment"
            , Text.lead "A short introduction that puts the page in context."
            , Text.heading "Recent activity"
            , Text.paragraph "Body text is set at 13px with a line height of 1.45. Lines are limited to about 80 characters, so they stay easy to read, also on dense screens."
            , Text.subheading "Details"
            , Layout.row [ Layout.gap 4, Layout.wrap ]
                [ Text.secondary "Secondary text"
                , Text.muted "Muted text for hints and metadata"
                , Text.caption "Small caption"
                , Text.strong "Bold text"
                ]
            ]
        )


inlineText : Locale -> Html Msg
inlineText locale =
    Doc.example
        { title = "Inline text and figures"
        , description = Just "paragraphWith mixes plain text with strong text, links, code and keys. figure is a large number that is not a heading; a row with alignBaseline keeps a label tidy next to it."
        , code = Just """Layout.stack [ Layout.gap 4 ]
    [ Text.paragraphWith
        [ Text.text "Orders are shipped within "
        , Text.strong "two days"
        , Text.text ". Press "
        , Kbd.view [ Kbd.inline ] (Shortcut.mod (Shortcut.char 'k'))
        , Text.text " to search, or "
        , Text.link { href = "#/orders", label = "open all orders" }
        , Text.text "."
        ]
    , Layout.row [ Layout.gap 2, Layout.alignBaseline ]
        [ Text.figure (Format.int locale (List.length orders))
        , Text.muted "orders in total"
        ]
    ]"""
        }
        (Layout.stack [ Layout.gap 4 ]
            [ Text.paragraphWith
                [ Text.text "Orders are shipped within "
                , Text.strong "two days"
                , Text.text ". Press "
                , Kbd.view [ Kbd.inline ] (Shortcut.mod (Shortcut.char 'k'))
                , Text.text " to search, or "
                , Text.link { href = "#/orders", label = "open all orders" }
                , Text.text "."
                ]
            , Layout.row [ Layout.gap 2, Layout.alignBaseline ]
                [ Text.figure (Format.int locale (List.length Sample.orders))
                , Text.muted "orders in total"
                ]
            ]
        )


codeAndKeys : Html Msg
codeAndKeys =
    Doc.example
        { title = "Code and keys"
        , description = Just "Inline code, ids in monospace, key caps and code blocks. Key caps come from Klar.Kbd: Kbd.view draws a shortcut, Kbd.key a single key."
        , code = Just """Layout.stack [ Layout.gap 3 ]
    [ Layout.row [ Layout.gap 3 ]
        [ Text.code "Table.view"
        , Text.mono "ORD-10001"
        , Kbd.view [ Kbd.inline ] (Shortcut.mod (Shortcut.char 'k'))
        , Kbd.key [ Kbd.inline ] "Esc"
        ]
    , Text.codeBlock "Select.view CountryMsg [ ... ] model.country"
    ]"""
        }
        (Layout.stack [ Layout.gap 3 ]
            [ Layout.row [ Layout.gap 3 ]
                [ Text.code "Table.view"
                , Text.mono "ORD-10001"
                , Kbd.view [ Kbd.inline ] (Shortcut.mod (Shortcut.char 'k'))
                , Kbd.key [ Kbd.inline ] "Esc"
                ]
            , Text.codeBlock selectSample
            ]
        )


selectSample : String
selectSample =
    """Select.view CountryMsg
    [ Select.label "Country"
    , Select.options countryOptions
    , Select.placeholder "Choose a country"
    ]
    model.country"""



-- ICONS


icons : Locale -> String -> Html Msg
icons locale query =
    Doc.section "Icons"
        "A library of line icons in one style: a 24 by 24 grid, a 2 pixel stroke, round ends. Every icon is an Elm value that carries its own drawing, so the compiler leaves out the ones an application does not use. They take the color of the text around them and scale with a size."
        [ allIcons locale query
        , iconSizes
        , iconColors
        , ownIcons
        ]


allIcons : Locale -> String -> Html Msg
allIcons locale query =
    let
        matching =
            Library.groups
                |> List.map (\group -> { group | icons = Search.filter Icon.name query group.icons })
                |> List.filter (\group -> not (List.isEmpty group.icons))

        found =
            List.sum (List.map (\group -> List.length group.icons) matching)

        summary =
            if found == Library.count then
                Format.int locale Library.count ++ " icons in " ++ Format.int locale (List.length Library.groups) ++ " modules."

            else
                Format.int locale found ++ " of " ++ Format.int locale Library.count ++ " icons."
    in
    Doc.example
        { title = "All icons"
        , description = Just (summary ++ " The name under each icon is its name in the stylesheet: chevron-down is Icon.chevronDown. The everyday icons are in Klar.Icon, the others in one module per theme, for example Klar.Icon.Arrows.")
        , code = Just """import Klar.Icon as Icon
import Klar.Icon.Logistics as Logistics

Layout.row [ Layout.gap 4 ]
    [ Icon.view Icon.search
    , Icon.sized Icon.Large Logistics.forklift
    , Icon.labelled "Delete" Icon.trash
    ]"""
        }
        (Layout.stack [ Layout.gap 4 ]
            (Layout.container [ Layout.maxWidth 360, Layout.alignStart ]
                [ TextInput.view
                    [ TextInput.id "foundations-icon-search"
                    , TextInput.label "Search icons"
                    , TextInput.labelHidden
                    , TextInput.search
                    , TextInput.clearable
                    , TextInput.locale locale
                    , TextInput.placeholder "Search icons, for example \"arrow\" ..."
                    , TextInput.value query
                    , TextInput.onInput IconQueryChanged
                    ]
                ]
                :: (if List.isEmpty matching then
                        [ EmptyState.view
                            [ EmptyState.icon Icon.search
                            , EmptyState.title "No icons found"
                            , EmptyState.description "Try another word, for example \"file\" or \"chevron\"."
                            , EmptyState.action (Button.view [ Button.onClick (IconQueryChanged "") ] "Clear search")
                            ]
                        ]

                    else
                        List.map iconGroup matching
                   )
            )
        )


iconGroup : Library.Group -> Html Msg
iconGroup group =
    Layout.stack [ Layout.gap 3 ]
        [ Layout.row [ Layout.gap 3, Layout.alignCenter, Layout.wrap ]
            [ Text.subheading group.title
            , Text.mono group.moduleName
            , Text.caption (String.fromInt (List.length group.icons) ++ " icons")
            ]
        , Layout.grid [ Layout.minColumn 150, Layout.gap 2 ]
            (List.map iconCell group.icons)
        ]


iconCell : Icon -> Html Msg
iconCell icon =
    Layout.row [ Layout.gap 2, Layout.alignCenter ]
        [ Icon.sized Icon.Large icon
        , Text.caption (Icon.name icon)
        ]


iconSizes : Html Msg
iconSizes =
    let
        entry ( size, name, pixels ) =
            Layout.stack [ Layout.gap 2, Layout.alignCenter ]
                [ Icon.sized size Icon.heart
                , Text.caption (name ++ ", " ++ String.fromInt pixels ++ "px")
                ]
    in
    Doc.example
        { title = "Sizes"
        , description = Just "Six sizes from 12 to 32 pixels. view is the Medium size, 16px. labelled has no size and is always 16px; use it for an icon that stands alone, without a text next to it, so that screen readers can announce it."
        , code = Just """Layout.row [ Layout.gap 4, Layout.alignCenter ]
    [ Icon.sized Icon.ExtraSmall Icon.heart
    , Icon.sized Icon.Small Icon.heart
    , Icon.sized Icon.Medium Icon.heart
    , Icon.sized Icon.Large Icon.heart
    , Icon.sized Icon.ExtraLarge Icon.heart
    , Icon.sized Icon.Huge Icon.heart
    ]"""
        }
        (Layout.row [ Layout.gap 6, Layout.alignEnd, Layout.wrap ]
            (List.map entry
                [ ( Icon.ExtraSmall, "ExtraSmall", 12 )
                , ( Icon.Small, "Small", 14 )
                , ( Icon.Medium, "Medium", 16 )
                , ( Icon.Large, "Large", 20 )
                , ( Icon.ExtraLarge, "ExtraLarge", 24 )
                , ( Icon.Huge, "Huge", 32 )
                ]
            )
        )


iconColors : Html Msg
iconColors =
    Doc.example
        { title = "Color and states"
        , description = Just "An icon takes the color of its parent, so it follows the tone, the disabled state and danger without extra work."
        , code = Just """Layout.row [ Layout.gap 3, Layout.wrap ]
    [ Button.view [ Button.primary, Button.icon Icon.plus ] "New order"
    , Button.view [ Button.icon Icon.download, Button.disabled True ] "Export"
    , Button.view [ Button.danger, Button.icon Icon.trash ] "Delete"
    , Badge.view [ Badge.tone Warning, Badge.icon Icon.warning ] "Overdue"
    , Badge.view [ Badge.tone Success, Badge.icon Icon.checkCircle ] "Delivered"
    ]"""
        }
        (Layout.row [ Layout.gap 3, Layout.wrap ]
            [ Button.view [ Button.primary, Button.icon Icon.plus ] "New order"
            , Button.view [ Button.icon Icon.download, Button.disabled True ] "Export"
            , Button.view [ Button.danger, Button.icon Icon.trash ] "Delete"
            , Badge.view [ Badge.tone Warning, Badge.icon Icon.warning ] "Overdue"
            , Badge.view [ Badge.tone Success, Badge.icon Icon.checkCircle ] "Delivered"
            ]
        )


ownIcons : Html Msg
ownIcons =
    Doc.example
        { title = "Your own icons"
        , description = Just "fromSvg takes a name and the shapes of an SVG, drawn on a 24 by 24 grid with strokes only. The icon is a plain Elm value: it needs no stylesheet, and it fits next to the built-in icons because the stroke width and the round ends are set for you. custom is the other way: it takes the CSS name of an icon whose drawing is in your own stylesheet."
        , code = Just invoiceIconSample
        }
        (Layout.row [ Layout.gap 4, Layout.alignCenter ]
            [ Icon.sized Icon.Large invoiceIcon
            , Text.code "Icon.fromSvg \"invoice\" ..."
            , Icon.sized Icon.Large (Icon.custom "heart")
            , Text.code "Icon.custom \"heart\""
            , Text.secondary "is the built-in heart, by its name"
            ]
        )


invoiceIcon : Icon
invoiceIcon =
    Icon.fromSvg "invoice"
        "<path d='M5 3h14v18l-2.5-2-2.5 2-2.5-2-2.5 2-2.5-2-1.5 2z'/><line x1='9' y1='8' x2='15' y2='8'/><line x1='9' y1='12' x2='15' y2='12'/>"


invoiceIconSample : String
invoiceIconSample =
    """invoice : Icon
invoice =
    Icon.fromSvg "invoice"
        "<path d='M5 3h14v18l-2.5-2-2.5 2-2.5-2-2.5 2-2.5-2-1.5 2z'/><line x1='9' y1='8' x2='15' y2='8'/><line x1='9' y1='12' x2='15' y2='12'/>"

Icon.view invoice
"""



-- LAYOUT


layout : Html Msg
layout =
    Doc.section "Layout"
        "Stack, row, grid and container: plain elements that you configure with a list of attributes. Spacing comes from the 4px scale of the design tokens."
        [ spacing
        , rowAlignment
        , rowDistribution
        , stackAlignment
        , dividers
        , columnsAndGrow
        ]


{-| A name above the thing it names.
-}
labelled : String -> Html Msg -> Html Msg
labelled name content =
    Layout.stack [ Layout.gap 2 ] [ Text.mono name, content ]


{-| A card for the examples on this page. The title of an example is an `h3`, so
the title of a card in it is an `h4`.
-}
card : List (Card.Attribute Msg) -> List (Html Msg) -> Html Msg
card attributes =
    Card.view (Card.headingLevel 4 :: attributes)


spacing : Html Msg
spacing =
    let
        cells step =
            [ Text.mono ("Layout.gap " ++ String.fromInt step ++ " = " ++ String.fromInt (step * 4) ++ "px")
            , Layout.row [ Layout.gap step ]
                [ Badge.view [ Badge.tone Primary, Badge.solid ] "A"
                , Badge.view [ Badge.tone Primary, Badge.solid ] "B"
                ]
            ]
    in
    Doc.example
        { title = "Spacing scale"
        , description = Just "Step n is the token --klar-space-n, so gap 2 is 8px and gap 4 is 16px. The valid steps are 0, 1, 2, 3, 4, 5, 6, 8, 10 and 12; other numbers are rounded down to the step below. padding uses the same scale."
        , code = Just """Layout.stack [ Layout.gap 4 ]
    [ Layout.row [ Layout.gap 1 ] [ Badge.view [] "A", Badge.view [] "B" ]
    , Layout.row [ Layout.gap 6 ] [ Badge.view [] "A", Badge.view [] "B" ]
    ]"""
        }
        (Layout.grid [ Layout.columns 2, Layout.gap 2, Layout.alignCenter ]
            (List.concatMap cells [ 0, 1, 2, 3, 4, 5, 6, 8, 10, 12 ])
        )


rowAlignment : Html Msg
rowAlignment =
    let
        mixed name attribute =
            labelled name
                (Layout.row [ Layout.gap 3, attribute ]
                    [ card [ Card.title "Card" ] [ Text.caption "The tallest child" ]
                    , Badge.view [ Badge.tone Primary ] "Badge"
                    , Button.view [ Button.small ] "Button"
                    ]
                )
    in
    Doc.example
        { title = "Aligning the children of a row"
        , description = Just "A row centers its children vertically. alignStart and alignEnd move them to the top and the bottom, and alignBaseline lines up the first line of text of every child. alignStretch makes children as tall as the row, if their height is not fixed: the short card grows, the badge and the button keep their height."
        , code = Just """Layout.stack [ Layout.gap 5 ]
    [ Layout.row [ Layout.gap 3, Layout.alignEnd ]
        [ Card.view [ Card.title "Card" ] [ Text.caption "The tallest child" ]
        , Badge.view [ Badge.tone Primary ] "Badge"
        , Button.view [ Button.small ] "Button"
        ]
    , Layout.row [ Layout.gap 3, Layout.alignStretch ]
        [ Card.view [ Card.title "Tall card" ] [ Text.paragraph "More content, so this card is taller." ]
        , Card.view [ Card.title "Short card" ] [ Text.caption "Grows to the height of the row." ]
        ]
    ]"""
        }
        (Layout.grid [ Layout.minColumn 300, Layout.gap 5 ]
            [ mixed "Layout.alignStart" Layout.alignStart
            , mixed "Layout.alignCenter (the default)" Layout.alignCenter
            , mixed "Layout.alignEnd" Layout.alignEnd
            , mixed "Layout.alignBaseline" Layout.alignBaseline
            , labelled "Layout.alignStretch"
                (Layout.row [ Layout.gap 3, Layout.alignStretch ]
                    [ card [ Card.title "Tall card" ] [ Text.paragraph "More content, so this card is taller." ]
                    , card [ Card.title "Short card" ] [ Text.caption "Grows to the height of the row." ]
                    ]
                )
            ]
        )


rowDistribution : Html Msg
rowDistribution =
    Doc.example
        { title = "Distributing the children of a row"
        , description = Just "justifyBetween spreads the children over the width, justifyCenter and justifyEnd pack them together, a spacer pushes everything after it to the far end, and wrap lets the children continue on the next line when they do not fit."
        , code = Just """Layout.stack [ Layout.gap 5 ]
    [ Layout.row [ Layout.justifyBetween ]
        [ Button.view [ Button.icon Icon.arrowLeft ] "Back"
        , Button.view [ Button.primary, Button.iconRight Icon.arrowRight ] "Next"
        ]
    , Layout.row [ Layout.justifyEnd, Layout.gap 2 ]
        [ Button.view [] "Cancel"
        , Button.view [ Button.primary ] "Save"
        ]
    , Layout.row []
        [ Text.heading "Orders"
        , Layout.spacer
        , Button.view [ Button.primary, Button.icon Icon.plus ] "New order"
        ]
    , Layout.row [ Layout.wrap, Layout.gap 2 ]
        (List.map (Tag.view []) cities)
    ]"""
        }
        (Layout.stack [ Layout.gap 5 ]
            [ labelled "Layout.justifyBetween"
                (Layout.row [ Layout.justifyBetween ]
                    [ Button.view [ Button.icon Icon.arrowLeft ] "Back"
                    , Button.view [ Button.primary, Button.iconRight Icon.arrowRight ] "Next"
                    ]
                )
            , labelled "Layout.justifyCenter"
                (Layout.row [ Layout.justifyCenter, Layout.gap 2 ]
                    [ Button.view [] "Cancel"
                    , Button.view [ Button.primary ] "Save"
                    ]
                )
            , labelled "Layout.justifyEnd"
                (Layout.row [ Layout.justifyEnd, Layout.gap 2 ]
                    [ Button.view [] "Cancel"
                    , Button.view [ Button.primary ] "Save"
                    ]
                )
            , labelled "Layout.spacer"
                (Layout.row []
                    [ Text.heading "Orders"
                    , Layout.spacer
                    , Button.view [ Button.primary, Button.icon Icon.plus ] "New order"
                    ]
                )
            , labelled "Layout.wrap"
                (Layout.row [ Layout.wrap, Layout.gap 2 ]
                    (List.map (Tag.view []) (List.take 24 Sample.cities))
                )
            ]
        )


stackAlignment : Html Msg
stackAlignment =
    let
        column name attributes =
            card [ Card.title name, Card.sunken ]
                [ Layout.stack (Layout.gap 2 :: attributes)
                    [ Button.view [] "Save"
                    , Button.view [ Button.primary ] "Save and close"
                    ]
                ]
    in
    Doc.example
        { title = "Aligning the children of a stack"
        , description = Just "A stack stretches its children to its own width. alignStart, alignCenter and alignEnd let them keep their natural width instead."
        , code = Just """Layout.stack [ Layout.gap 2, Layout.alignStart ]
    [ Button.view [] "Save"
    , Button.view [ Button.primary ] "Save and close"
    ]"""
        }
        (Layout.grid [ Layout.minColumn 200, Layout.gap 4 ]
            [ column "Stretch (the default)" []
            , column "Layout.alignStart" [ Layout.alignStart ]
            , column "Layout.alignCenter" [ Layout.alignCenter ]
            , column "Layout.alignEnd" [ Layout.alignEnd ]
            ]
        )


dividers : Html Msg
dividers =
    Doc.example
        { title = "Dividers and narrow columns"
        , description = Just "divider is a thin line across the width and dividerLabelled puts a word in it. A container is the centered page column of an application; with alignStart and maxWidth it is a narrow column at the left edge instead."
        , code = Just """Layout.grid [ Layout.minColumn 320, Layout.gap 6 ]
    [ Layout.stack [ Layout.gap 3 ]
        [ Text.subheading "Shipping"
        , Text.paragraph "Orders leave the warehouse within two working days."
        , Layout.divider
        , Text.subheading "Returns"
        , Text.paragraph "Unused items can be returned within 30 days."
        ]
    , Layout.container [ Layout.maxWidth 360, Layout.alignStart ]
        [ Layout.stack [ Layout.gap 3 ]
            [ Button.view [ Button.primary, Button.block ] "Continue with e-mail"
            , Layout.dividerLabelled "or"
            , Button.view [ Button.block ] "Continue with single sign-on"
            ]
        ]
    ]"""
        }
        (Layout.grid [ Layout.minColumn 320, Layout.gap 6 ]
            [ Layout.stack [ Layout.gap 3 ]
                [ Text.subheading "Shipping"
                , Text.paragraph "Orders leave the warehouse within two working days."
                , Layout.divider
                , Text.subheading "Returns"
                , Text.paragraph "Unused items can be returned within 30 days."
                ]
            , Layout.container [ Layout.maxWidth 360, Layout.alignStart ]
                [ Layout.stack [ Layout.gap 3 ]
                    [ Button.view [ Button.primary, Button.block ] "Continue with e-mail"
                    , Layout.dividerLabelled "or"
                    , Button.view [ Button.block ] "Continue with single sign-on"
                    ]
                ]
            ]
        )


columnsAndGrow : Html Msg
columnsAndGrow =
    Doc.example
        { title = "Columns and growing"
        , description = Just "columns n makes a grid of n equal columns; minColumn, used in the examples above and below, adds and removes columns as the space changes. grow lets one part of a row take the space that is left, such as the main column next to a sidebar."
        , code = Just """Layout.stack [ Layout.gap 5 ]
    [ Layout.grid [ Layout.columns 3, Layout.gap 3 ]
        (List.map (\\n -> Card.view [] [ Text.paragraph ("Column " ++ String.fromInt n) ]) (List.range 1 6))
    , Layout.row [ Layout.gap 4, Layout.alignStart ]
        [ Card.view [ Card.title "Filters" ] [ Text.paragraph "As wide as its content." ]
        , Layout.stack [ Layout.grow, Layout.gap 3 ]
            [ Card.view [ Card.title "Orders" ] [ Text.paragraph "Takes the space that is left." ] ]
        ]
    ]"""
        }
        (Layout.stack [ Layout.gap 5 ]
            [ Layout.grid [ Layout.columns 3, Layout.gap 3 ]
                (List.map
                    (\n -> card [] [ Text.paragraph ("Column " ++ String.fromInt n) ])
                    (List.range 1 6)
                )
            , Layout.row [ Layout.gap 4, Layout.alignStart ]
                [ card [ Card.title "Filters" ] [ Text.paragraph "As wide as its content." ]
                , Layout.stack [ Layout.grow, Layout.gap 3 ]
                    [ card [ Card.title "Orders" ] [ Text.paragraph "Takes the space that is left." ] ]
                ]
            ]
        )



-- CARDS


cards : Locale -> Html Msg
cards locale =
    Doc.section "Cards"
        "A bordered surface that groups related content. The header shows when the card has a title, a subtitle or actions."
        [ cardGrid locale
        , cardHeader
        , cardLooks
        , cardAccents
        , cardList
        ]


cardGrid : Locale -> Html Msg
cardGrid locale =
    Doc.example
        { title = "Grid of cards"
        , description = Just "Layout.grid with minColumn fills the row with as many columns as fit. The figures are counted from the sample orders and written with Klar.Format, so they follow the language switch in the top bar (Alt L)."
        , code = Just """Layout.grid [ Layout.minColumn 240, Layout.gap 4 ]
    [ Card.view [ Card.title "New orders", Card.subtitle "Last 30 days" ]
        [ Layout.row [ Layout.justifyBetween ]
            [ Text.figure "598", Badge.view [ Badge.tone Success ] "+2.9%" ]
        ]
    , Card.view [ Card.title "Awaiting confirmation", Card.accent Warning ]
        [ Layout.row [ Layout.justifyBetween ]
            [ Text.figure "160", Badge.view [ Badge.tone Warning ] "Follow up" ]
        ]
    , Card.view [ Card.title "Cancelled", Card.sunken ]
        [ Layout.row [ Layout.justifyBetween ]
            [ Text.figure "108", Badge.view [] "Archive" ]
        ]
    ]"""
        }
        (Layout.grid [ Layout.minColumn 240, Layout.gap 4 ]
            [ card [ Card.title "New orders", Card.subtitle "Last 30 days" ]
                [ Layout.row [ Layout.justifyBetween ]
                    [ Text.figure (Format.int locale figures.recent), trendBadge locale ]
                ]
            , card [ Card.title "Awaiting confirmation", Card.accent Warning ]
                [ Layout.row [ Layout.justifyBetween ]
                    [ Text.figure (Format.int locale figures.drafts), Badge.view [ Badge.tone Warning ] "Follow up" ]
                ]
            , card [ Card.title "Cancelled", Card.sunken ]
                [ Layout.row [ Layout.justifyBetween ]
                    [ Text.figure (Format.int locale figures.cancelled), Badge.view [] "Archive" ]
                ]
            ]
        )


cardHeader : Html Msg
cardHeader =
    Doc.example
        { title = "Header, actions and footer"
        , description = Just "Actions sit at the right end of the header and move below the title on a narrow card. The footer takes one element: wrap several in a Layout.row. The title is an h3 unless headingLevel says otherwise; the cards on this page use 4, one below the title of their example."
        , code = Just """Card.view
    [ Card.title "Order notes"
    , Card.headingLevel 4
    , Card.subtitle "From the warehouse team"
    , Card.actions
        [ Button.view [ Button.small ] "Export"
        , Button.iconOnly [ Button.small, Button.ghost ] Icon.moreHorizontal "More actions"
        ]
    , Card.footer (Text.caption "Updated 3 minutes ago")
    ]
    [ Text.paragraph "Fragile, handle with care." ]"""
        }
        (card
            [ Card.title "Order notes"
            , Card.subtitle "From the warehouse team"
            , Card.actions
                [ Button.view [ Button.small ] "Export"
                , Button.iconOnly [ Button.small, Button.ghost ] Icon.moreHorizontal "More actions"
                ]
            , Card.footer (Text.caption "Updated 3 minutes ago")
            ]
            [ Layout.stack [ Layout.gap 2 ]
                (List.map
                    (\( id, note ) ->
                        Layout.row [ Layout.gap 3, Layout.alignBaseline ]
                            [ Text.mono id, Text.secondary note ]
                    )
                    orderNotes
                )
            ]
        )


cardLooks : Html Msg
cardLooks =
    Doc.example
        { title = "Looks"
        , description = Just "sunken uses a light gray background for less prominent content and raised a subtle shadow. A card without a title, a subtitle or actions has no header."
        , code = Just """Layout.grid [ Layout.minColumn 200, Layout.gap 4 ]
    [ Card.view [ Card.title "Default" ] [ Text.paragraph "White, with a thin gray border." ]
    , Card.view [ Card.title "Sunken", Card.sunken ] [ Text.paragraph "A light gray background." ]
    , Card.view [ Card.title "Raised", Card.raised ] [ Text.paragraph "A subtle shadow." ]
    , Card.view [] [ Text.paragraph "No header." ]
    ]"""
        }
        (Layout.grid [ Layout.minColumn 200, Layout.gap 4 ]
            [ card [ Card.title "Default" ] [ Text.paragraph "White, with a thin gray border." ]
            , card [ Card.title "Sunken", Card.sunken ] [ Text.paragraph "A light gray background for less prominent content." ]
            , card [ Card.title "Raised", Card.raised ] [ Text.paragraph "A subtle shadow lifts the card off the page." ]
            , card [] [ Text.paragraph "Without a title, a subtitle or actions the card has no header." ]
            ]
        )


cardAccents : Html Msg
cardAccents =
    let
        accent name tone meaning =
            card [ Card.title name, Card.accent tone ] [ Text.paragraph meaning ]
    in
    Doc.example
        { title = "Accent"
        , description = Just "A colored strip along the left edge marks a status. Primary and Info share the accent color of the application."
        , code = Just """Card.view [ Card.title "Payment failed", Card.accent Danger ]
    [ Text.paragraph "The card was declined." ]"""
        }
        (Layout.grid [ Layout.minColumn 220, Layout.gap 4 ]
            [ accent "Neutral" Neutral "Plain information or no particular meaning."
            , accent "Primary" Primary "The accent color of the application."
            , accent "Info" Info "Something worth noting."
            , accent "Success" Success "It worked, or the state is good."
            , accent "Warning" Warning "Needs attention but nothing is broken."
            , accent "Danger" Danger "An error, or an action that cannot be undone."
            ]
        )


cardList : Html Msg
cardList =
    Doc.example
        { title = "Edge to edge and scrolling"
        , description = Just "flush removes the padding of the body, so lines between rows reach the edges of the card. Layout.maxHeight limits the height of the stack and scrolls the rest."
        , code = Just """Card.view [ Card.title "Latest orders", Card.subtitle "Scrolls inside the card", Card.flush ]
    [ Layout.stack [ Layout.gap 0, Layout.maxHeight 240 ]
        (List.intersperse Layout.divider (List.map viewOrder orders))
    ]"""
        }
        (card
            [ Card.title "Latest orders"
            , Card.subtitle "Scrolls inside the card"
            , Card.flush
            ]
            [ Layout.stack [ Layout.gap 0, Layout.maxHeight 240 ]
                (List.intersperse Layout.divider
                    (List.map orderRow (List.take 20 Sample.orders))
                )
            ]
        )


orderRow : Types.Order -> Html Msg
orderRow order =
    Layout.row [ Layout.gap 3, Layout.padding 3 ]
        [ Text.mono (Types.orderIdText order.id)
        , Text.secondary order.customer
        , Layout.spacer
        , Labels.statusBadge order.status
        ]


trendBadge : Locale -> Html Msg
trendBadge locale =
    let
        change =
            if figures.before == 0 then
                0

            else
                toFloat (figures.recent - figures.before) / toFloat figures.before

        rising =
            change >= 0
    in
    Badge.view
        [ Badge.tone
            (if rising then
                Success

             else
                Danger
            )
        ]
        ((if rising then
            "+"

          else
            ""
         )
            ++ Format.percent locale 1 change
        )



-- SAMPLE FIGURES


type alias Figures =
    { recent : Int
    , before : Int
    , drafts : Int
    , cancelled : Int
    }


{-| Counted once from the sample orders: created in the last 30 days, in the 30
days before that, still drafts, and cancelled.
-}
figures : Figures
figures =
    let
        daysOld order =
            Date.diffDays order.created Sample.today

        count keep =
            List.length (List.filter keep Sample.orders)
    in
    { recent = count (\order -> daysOld order >= 0 && daysOld order < 30)
    , before = count (\order -> daysOld order >= 30 && daysOld order < 60)
    , drafts = count (\order -> order.status == Draft)
    , cancelled = count (\order -> order.status == Cancelled)
    }


{-| The id and the note of the first three orders that have a note.
-}
orderNotes : List ( String, String )
orderNotes =
    Sample.orders
        |> List.filter (\order -> order.note /= "")
        |> List.take 3
        |> List.map (\order -> ( Types.orderIdText order.id, order.note ))
