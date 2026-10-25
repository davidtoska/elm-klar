module Page.Gallery.Actions.Links exposing
    ( Model
    , Msg
    , init
    , section
    , update
    )

{-| The link of the gallery page "Actions and links". Internal links use the
fragments of the showcase: `#/...` is a real page, `#links/...` is ignored by the
router, so a click stays on this page.
-}

import Html exposing (Html)
import Klar.Icon as Icon
import Klar.Layout as Layout
import Klar.Link as Link
import Klar.Locale exposing (Locale)
import Klar.Text as Text
import Klar.Tooltip as Tooltip
import Showcase.Config as Config
import Showcase.Doc as Doc
import Showcase.Options as Options



-- MODEL


type alias Model =
    { page : Page
    }


{-| Which of the pretend pages is "the page the user is on".
-}
type Page
    = Overview
    | Orders
    | Customers


init : Model
init =
    { page = Orders }


type Msg
    = Opened Page


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        Opened page ->
            ( { model | page = page }, Cmd.none )


pageTitle : Page -> String
pageTitle page =
    case page of
        Overview ->
            "Overview"

        Orders ->
            "Orders"

        Customers ->
            "Customers"


pageAddress : Page -> String
pageAddress page =
    "#links/" ++ String.toLower (pageTitle page)



-- VIEW


section : Config.Config -> Locale -> Model -> Html Msg
section playground locale model =
    Doc.configuredSection playground
        [ "Link" ]
        "Link"
        "A real anchor that cannot be built wrong. The destination is a Target made by Link.internal (an address in your application) or Link.external (another site, an email address, a telephone number), and no other string ever becomes an href. A link to another site opens in a new tab and says so, in writing for screen readers and with an icon."
        [ Doc.configuredExample playground
            [ "Link" ]
            { title = "Inside the application"
            , description = Just "The link to the page you are on is current (aria-current). Here a click makes a link the current one, with Link.onClick, which also keeps the browser from following the address; a click with Ctrl, Cmd or Shift is left to the browser, so it still opens a new tab. This showcase is a Browser.application, so Elm reports these clicks to onUrlRequest as well (and the router ignores them): in your own application you handle them there and need no onClick."
            , code = Just internalCode
            }
            (Layout.stack (Options.klarLayout playground (List.concat [ Config.keep playground "Layout" "gap" (Layout.gap 3) ]))
                [ Layout.row (Options.klarLayout playground (List.concat [ Config.keep playground "Layout" "gap" (Layout.gap 4), Config.keep playground "Layout" "alignCenter" Layout.alignCenter, Config.keep playground "Layout" "wrap" Layout.wrap ]))
                    (List.map (pageLink playground locale model) [ Overview, Orders, Customers ])
                , Text.paragraphWith
                    [ Html.text "A link in a sentence is "
                    , Link.view (Options.klarLink playground (List.concat [ Config.keep playground "Link" "locale" (Link.locale locale) ])) (Link.internal "#/components/actions") "underlined"
                    , Html.text ", and has another color once it has been visited. A real page of this showcase: "
                    , Link.view (Options.klarLink playground (List.concat [ Config.keep playground "Link" "locale" (Link.locale locale) ])) (Link.internal "#/orders") "all orders"
                    , Html.text "."
                    ]
                ]
            )
        , Doc.configuredExample playground
            [ "Link" ]
            { title = "Another site, email and telephone"
            , description = Just "A page on the web opens in a new tab (target=_blank with rel=noopener noreferrer) and is marked. An email address and a telephone number open in the same tab and are not marked. Link.external accepts only http, https, mailto and tel."
            , code = Just externalCode
            }
            (Layout.row (Options.klarLayout playground (List.concat [ Config.keep playground "Layout" "gap" (Layout.gap 4), Config.keep playground "Layout" "alignCenter" Layout.alignCenter, Config.keep playground "Layout" "wrap" Layout.wrap ]))
                [ external locale [] "https://package.elm-lang.org/packages/davidtoska/elm-klar/latest/" "Documentation"
                , external locale (Options.klarLink playground (List.concat [ Config.keep playground "Link" "icon" (Link.icon Icon.fileText) ])) "https://guide.elm-lang.org/" "The Elm guide"
                , external locale (Options.klarLink playground (List.concat [ Config.keep playground "Link" "icon" (Link.icon Icon.mail) ])) "mailto:orders@example.com?subject=Order%2010001" "orders@example.com"
                , external locale (Options.klarLink playground (List.concat [ Config.keep playground "Link" "icon" (Link.icon Icon.phone) ])) "tel:+4722000000" "+47 22 00 00 00"
                ]
            )
        , Doc.configuredExample playground
            [ "Link" ]
            { title = "An address from your data"
            , description = Just "Link.external answers Nothing for an address that cannot be a link, and the application decides what to show. A javascript: address, a data: address or a text with a space in it is never turned into a link."
            , code = Just dataCode
            }
            (Layout.stack (Options.klarLayout playground (List.concat [ Config.keep playground "Layout" "gap" (Layout.gap 2) ]))
                (List.map (customerWebsite playground locale)
                    [ ( "Acme Logistics", "https://acme.example/" )
                    , ( "Nordic Freight", "HTTP://NORDIC.EXAMPLE/en" )
                    , ( "Harbor Supply", "www.harbor.example" )
                    , ( "Blue Warehouse", "javascript:alert('Blue')" )
                    , ( "Corner Store", "data:text/html,<b>Corner</b>" )
                    , ( "River Goods", "java\tscript:alert(1)" )
                    ]
                )
            )
        , Doc.configuredExample playground
            [ "Link" ]
            { title = "Inline, standalone, truncated and disabled"
            , description = Just "Inline (the default) is underlined, for text. Standalone has no underline until the pointer is over it, for a cell or a list. Truncate cuts a long text with an ellipsis and keeps the whole text as the tooltip. A disabled link has no href, stays in the tab order (so the tooltip that says why can be read from the keyboard), and is announced as unavailable."
            , code = Just looksCode
            }
            (Layout.stack (Options.klarLayout playground (List.concat [ Config.keep playground "Layout" "gap" (Layout.gap 3) ]))
                [ Layout.row (Options.klarLayout playground (List.concat [ Config.keep playground "Layout" "gap" (Layout.gap 5), Config.keep playground "Layout" "alignCenter" Layout.alignCenter, Config.keep playground "Layout" "wrap" Layout.wrap ]))
                    [ Link.view (Options.klarLink playground (List.concat [ Config.keep playground "Link" "locale" (Link.locale locale) ])) (Link.internal "#links/inline") "Inline"
                    , Link.view (Options.klarLink playground (List.concat [ Config.keep playground "Link" "standalone" Link.standalone, Config.keep playground "Link" "locale" (Link.locale locale) ])) (Link.internal "#links/standalone") "Standalone"
                    , Link.view (Options.klarLink playground (List.concat [ Config.keep playground "Link" "standalone" Link.standalone, Config.keep playground "Link" "icon" (Link.icon Icon.fileText) ])) (Link.internal "#links/invoice") "With an icon"
                    , Tooltip.wrap [ Tooltip.focusable, Tooltip.id "actions-link-disabled-tip" ]
                        "Only the owner of the order can open the invoice"
                        (\_ -> Link.view (Options.klarLink playground (List.concat [ Config.keep playground "Link" "disabled" (Link.disabled True) ])) (Link.internal "#links/invoice") "Disabled")
                    ]
                , Layout.container (Options.klarLayout playground (List.concat [ Config.keep playground "Layout" "maxWidth" (Layout.maxWidth 260), Config.keep playground "Layout" "alignStart" Layout.alignStart ]))
                    [ Link.view (Options.klarLink playground (List.concat [ Config.keep playground "Link" "standalone" Link.standalone, Config.keep playground "Link" "truncate" Link.truncate ]))
                        (Link.internal "#links/long")
                        "Order 10001 for Harbor Supply, delivery to the warehouse in the north"
                    ]
                ]
            )
        , Doc.configuredExample playground
            [ "Link" ]
            { title = "A file to save"
            , description = Just "Link.download puts a text of the application in the link (a data: address, encoded so that any character, an emoji or a line break, is safe) and the browser saves it under the file name instead of opening it. No server is asked. A button that looks like a button takes the same target: Button.href (Link.download ...)."
            , code = Just downloadCode
            }
            (Layout.row (Options.klarLayout playground (List.concat [ Config.keep playground "Layout" "gap" (Layout.gap 5), Config.keep playground "Layout" "alignCenter" Layout.alignCenter, Config.keep playground "Layout" "wrap" Layout.wrap ]))
                [ Link.view (Options.klarLink playground (List.concat [ Config.keep playground "Link" "icon" (Link.icon Icon.download) ]))
                    (Link.download { fileName = "orders.csv", mimeType = "text/csv", content = ordersCsv })
                    "Download orders.csv"
                ]
            )
        ]


pageLink : Config.Config -> Locale -> Model -> Page -> Html Msg
pageLink playground locale model page =
    Link.view
        (Options.klarLink playground
            (List.concat
                [ Config.keep playground "Link" "standalone" Link.standalone
                , Config.keep playground "Link" "current" (Link.current (model.page == page))
                , Config.keep playground "Link" "onClick" (Link.onClick (Opened page))
                , Config.keep playground "Link" "locale" (Link.locale locale)
                ]
            )
        )
        (Link.internal (pageAddress page))
        (pageTitle page)


external : Locale -> List (Link.Attribute msg) -> String -> String -> Html msg
external locale attributes address label =
    case Link.external address of
        Just target ->
            Link.view (Link.locale locale :: attributes) target label

        Nothing ->
            Html.text label


customerWebsite : Config.Config -> Locale -> ( String, String ) -> Html msg
customerWebsite playground locale ( customer, website ) =
    Layout.row (Options.klarLayout playground (List.concat [ Config.keep playground "Layout" "gap" (Layout.gap 3), Config.keep playground "Layout" "alignCenter" Layout.alignCenter ]))
        [ Text.strong customer
        , case Link.external website of
            Just target ->
                Link.view (Options.klarLink playground (List.concat [ Config.keep playground "Link" "locale" (Link.locale locale) ])) target (String.trim website)

            Nothing ->
                Text.muted (printable website ++ "  (not a link)")
        ]


{-| The address as one can read it, with the control characters made visible.
-}
printable : String -> String
printable text =
    String.map
        (\c ->
            if Char.toCode c < 0x20 then
                '·'

            else
                c
        )
        text



-- CODE


internalCode : String
internalCode =
    """-- the string comes from your own route function
Link.view [ Link.standalone, Link.current (model.route == Orders) ]
    (Link.internal (Route.toPath Orders))
    "Orders"

-- in a Browser.application, handle the click where Elm reports it
UrlRequested (Browser.Internal url) ->
    ( model, Nav.pushUrl model.key (Url.toString url) )

UrlRequested (Browser.External href) ->
    ( model, Nav.load href )

-- in a Browser.element: take the click over (Ctrl, Cmd and Shift clicks are left alone)
Link.view [ Link.onClick (Opened Orders) ] (Link.internal "/orders") "Orders"
"""


externalCode : String
externalCode =
    """case Link.external "https://guide.elm-lang.org/" of
    Just target ->
        Link.view [ Link.icon Icon.fileText ] target "The Elm guide"

    Nothing ->
        Html.text "The Elm guide"

-- the same for mailto: and tel:
Link.external "mailto:orders@example.com?subject=Order%2010001"
Link.external "tel:+4722000000"
"""


dataCode : String
dataCode =
    """-- customer.website comes from a database: it may be anything
case Link.external customer.website of
    Just target ->
        Link.view [] target customer.website

    Nothing ->
        Text.muted customer.website

Link.external "javascript:alert(1)"   -- Nothing
Link.external "www.harbor.example"    -- Nothing: no scheme
Link.external "HTTP://NORDIC.EXAMPLE" -- Just ...
"""


ordersCsv : String
ordersCsv =
    "id,customer,total\n10001,Harbor Supply,1240.50\n10002,Nordic Freight,88.00\n"


downloadCode : String
downloadCode =
    """Link.view [ Link.icon Icon.download ]
    (Link.download { fileName = "orders.csv", mimeType = "text/csv", content = ordersCsv })
    "Download orders.csv"

-- the same target on a button
Button.view [ Button.icon Icon.download, Button.href (Link.download { fileName = "orders.csv", mimeType = "text/csv", content = ordersCsv }) ] "Export"
"""


looksCode : String
looksCode =
    """Link.view [] target "Inline"
Link.view [ Link.standalone ] target "Standalone"
Link.view [ Link.standalone, Link.truncate ] target "Order 10001 for Harbor Supply, ..."

-- a disabled link is not in the tab order: the wrapper takes focus for it
Tooltip.wrap [ Tooltip.focusable, Tooltip.id "invoice-tip" ] "Only the owner of the order can open the invoice"
    (\\_ -> Link.view [ Link.disabled True ] target "Invoice")
"""
