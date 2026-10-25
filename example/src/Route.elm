module Route exposing
    ( Route(..)
    , fromUrl
    , path
    , title
    )

{-| Hash-based routing (`index.html#/orders`), so the application works from any
static file server without rewrite rules.

    #/                          Overview
    #/orders                    Orders
    #/orders/ORD-10001          Orders, with that order open
    #/products                  Products
    #/components                The component gallery
    #/components/tables         One page of the gallery

-}

import Api.Types exposing (OrderId, orderId, orderIdText)
import Page.Applications.Catalog as Applications
import Url exposing (Url)
import Url.Parser as Parser exposing ((</>), Parser)


type Route
    = Overview
    | Orders
    | OrderDetail OrderId
    | Products
    | Components (Maybe String)
    | Application Applications.Page
    | NotFound


fromUrl : Url -> Route
fromUrl url =
    { url | path = Maybe.withDefault "" url.fragment, query = Nothing, fragment = Nothing }
        |> Parser.parse parser
        |> Maybe.withDefault NotFound


parser : Parser (Route -> a) a
parser =
    Parser.oneOf
        [ Parser.map Overview Parser.top
        , Parser.map Orders (Parser.s "orders")
        , Parser.map (orderId >> OrderDetail) (Parser.s "orders" </> Parser.string)
        , Parser.map Products (Parser.s "products")
        , Parser.map (Components Nothing) (Parser.s "components")
        , Parser.map (\slug -> Components (Just slug)) (Parser.s "components" </> Parser.string)
        , Parser.map Application (Parser.s "applications" </> Parser.custom "application example" Applications.fromSlug)
        ]


{-| The URL fragment for a route, with the leading `#/`.
-}
path : Route -> String
path route =
    "#/"
        ++ (case route of
                Overview ->
                    ""

                Orders ->
                    "orders"

                OrderDetail id ->
                    "orders/" ++ orderIdText id

                Products ->
                    "products"

                Components Nothing ->
                    "components"

                Components (Just slug) ->
                    "components/" ++ slug

                Application page ->
                    "applications/" ++ Applications.slug page

                NotFound ->
                    "not-found"
           )


title : Route -> String
title route =
    case route of
        Overview ->
            "Overview"

        Orders ->
            "Orders"

        OrderDetail _ ->
            "Order"

        Products ->
            "Products"

        Components _ ->
            "Components"

        Application page ->
            Applications.title page

        NotFound ->
            "Page not found"
