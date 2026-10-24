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
import Showcase.Doc as Doc



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


section : Locale -> Model -> Html Msg
section locale model =
    Doc.section "Link"
        "A real anchor that cannot be built wrong. The destination is a Target made by Link.internal (an address in your application) or Link.external (another site, an email address, a telephone number), and no other string ever becomes an href. A link to another site opens in a new tab and says so, in writing for screen readers and with an icon."
        [ Doc.example
            { title = "Inside the application"
            , description = Just "The link to the page you are on is current (aria-current). Here a click makes a link the current one, with Link.onClick, which also keeps the browser from following the address; a click with Ctrl, Cmd or Shift is left to the browser, so it still opens a new tab. This showcase is a Browser.application, so Elm reports these clicks to onUrlRequest as well (and the router ignores them): in your own application you handle them there and need no onClick."
            , code = Just internalCode
            }
            (Layout.stack [ Layout.gap 3 ]
                [ Layout.row [ Layout.gap 4, Layout.alignCenter, Layout.wrap ]
                    (List.map (pageLink locale model) [ Overview, Orders, Customers ])
                , Text.paragraphWith
                    [ Html.text "A link in a sentence is "
                    , Link.view [ Link.locale locale ] (Link.internal "#/components/actions") "underlined"
                    , Html.text ", and has another color once it has been visited. A real page of this showcase: "
                    , Link.view [ Link.locale locale ] (Link.internal "#/orders") "all orders"
                    , Html.text "."
                    ]
                ]
            )
        , Doc.example
            { title = "Another site, email and telephone"
            , description = Just "A page on the web opens in a new tab (target=_blank with rel=noopener noreferrer) and is marked. An email address and a telephone number open in the same tab and are not marked. Link.external accepts only http, https, mailto and tel."
            , code = Just externalCode
            }
            (Layout.row [ Layout.gap 4, Layout.alignCenter, Layout.wrap ]
                [ external locale [] "https://package.elm-lang.org/packages/davidtoska/elm-klar/latest/" "Documentation"
                , external locale [ Link.icon Icon.fileText ] "https://guide.elm-lang.org/" "The Elm guide"
                , external locale [ Link.icon Icon.mail ] "mailto:orders@example.com?subject=Order%2010001" "orders@example.com"
                , external locale [ Link.icon Icon.phone ] "tel:+4722000000" "+47 22 00 00 00"
                ]
            )
        , Doc.example
            { title = "An address from your data"
            , description = Just "Link.external answers Nothing for an address that cannot be a link, and the application decides what to show. A javascript: address, a data: address or a text with a space in it is never turned into a link."
            , code = Just dataCode
            }
            (Layout.stack [ Layout.gap 2 ]
                (List.map (customerWebsite locale)
                    [ ( "Acme Logistics", "https://acme.example/" )
                    , ( "Nordic Freight", "HTTP://NORDIC.EXAMPLE/en" )
                    , ( "Harbor Supply", "www.harbor.example" )
                    , ( "Blue Warehouse", "javascript:alert('Blue')" )
                    , ( "Corner Store", "data:text/html,<b>Corner</b>" )
                    , ( "River Goods", "java\tscript:alert(1)" )
                    ]
                )
            )
        , Doc.example
            { title = "Inline, standalone, truncated and disabled"
            , description = Just "Inline (the default) is underlined, for text. Standalone has no underline until the pointer is over it, for a cell or a list. Truncate cuts a long text with an ellipsis and keeps the whole text as the tooltip. A disabled link has no href, is not in the tab order, and is announced as unavailable; say why in a tooltip."
            , code = Just looksCode
            }
            (Layout.stack [ Layout.gap 3 ]
                [ Layout.row [ Layout.gap 5, Layout.alignCenter, Layout.wrap ]
                    [ Link.view [ Link.locale locale ] (Link.internal "#links/inline") "Inline"
                    , Link.view [ Link.standalone, Link.locale locale ] (Link.internal "#links/standalone") "Standalone"
                    , Link.view [ Link.standalone, Link.icon Icon.fileText ] (Link.internal "#links/invoice") "With an icon"
                    , Tooltip.wrap [ Tooltip.focusable, Tooltip.id "actions-link-disabled-tip" ]
                        "Only the owner of the order can open the invoice"
                        (\_ -> Link.view [ Link.disabled True ] (Link.internal "#links/invoice") "Disabled")
                    ]
                , Layout.container [ Layout.maxWidth 260, Layout.alignStart ]
                    [ Link.view [ Link.standalone, Link.truncate ]
                        (Link.internal "#links/long")
                        "Order 10001 for Harbor Supply, delivery to the warehouse in the north"
                    ]
                ]
            )
        ]


pageLink : Locale -> Model -> Page -> Html Msg
pageLink locale model page =
    Link.view
        [ Link.standalone
        , Link.current (model.page == page)
        , Link.onClick (Opened page)
        , Link.locale locale
        ]
        (Link.internal (pageAddress page))
        (pageTitle page)


external : Locale -> List (Link.Attribute msg) -> String -> String -> Html msg
external locale attributes address label =
    case Link.external address of
        Just target ->
            Link.view (Link.locale locale :: attributes) target label

        Nothing ->
            Html.text label


customerWebsite : Locale -> ( String, String ) -> Html msg
customerWebsite locale ( customer, website ) =
    Layout.row [ Layout.gap 3, Layout.alignCenter ]
        [ Text.strong customer
        , case Link.external website of
            Just target ->
                Link.view [ Link.locale locale ] target (String.trim website)

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


looksCode : String
looksCode =
    """Link.view [] target "Inline"
Link.view [ Link.standalone ] target "Standalone"
Link.view [ Link.standalone, Link.truncate ] target "Order 10001 for Harbor Supply, ..."

-- a disabled link is not in the tab order: the wrapper takes focus for it
Tooltip.wrap [ Tooltip.focusable, Tooltip.id "invoice-tip" ] "Only the owner of the order can open the invoice"
    (\\_ -> Link.view [ Link.disabled True ] target "Invoice")
"""
