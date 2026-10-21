module Page.Products.Category exposing (Branch(..), Category, find, fromProducts, includes, pathLabel)

{-| The category hierarchy of the products, as the tree on the products page
shows it.

A product carries its category as a path, such as `[ "Hardware", "Fasteners",
"Bolts" ]`. There is no separate list of categories: they are read off the
products. Every beginning of a path is a category, so this product counts for
"Hardware", for "Hardware > Fasteners" and for "Hardware > Fasteners > Bolts".
A product without a category belongs to no branch; it is only in the table when
no category is chosen.

The module knows nothing about the user interface, which keeps the page itself
about the components.

-}

import Api.Types exposing (Product)
import Dict exposing (Dict)


{-| One category. `id` is made from the path: unique in the whole tree, as
`Klar.Tree` demands, and the same after every load. `count` is the number of
products in this category and everything below it.
-}
type alias Category =
    { id : String
    , name : String
    , path : List String
    , count : Int
    }


{-| A category with the branches below it. (A record cannot contain itself, so
the nesting needs a type of its own.)
-}
type Branch
    = Branch Category (List Branch)


{-| The top level of the hierarchy, with the categories in alphabetical order
at every level.
-}
fromProducts : List Product -> List Branch
fromProducts products =
    let
        counts =
            List.foldl countPaths Dict.empty products
    in
    branchesOf (Dict.toList counts) []


{-| Every path that occurs, with the number of products at or below it. Lists
of strings are `comparable`, so a `Dict` can be keyed by a path, and `Dict.toList`
puts a category before its children and the siblings in alphabetical order.
-}
countPaths : Product -> Dict (List String) Int -> Dict (List String) Int
countPaths product counts =
    List.foldl
        (\path -> Dict.update path (\n -> Just (Maybe.withDefault 0 n + 1)))
        counts
        (beginnings product.category)


{-| `[ a, b, c ]` becomes `[ [ a ], [ a, b ], [ a, b, c ] ]`.
-}
beginnings : List a -> List (List a)
beginnings path =
    List.range 1 (List.length path)
        |> List.map (\length -> List.take length path)


{-| The categories directly below `parent` (the top level for `[]`). Every call
looks at every path again, which is nothing for the hundreds of categories of a
catalog.
-}
branchesOf : List ( List String, Int ) -> List String -> List Branch
branchesOf counts parent =
    let
        depth =
            List.length parent + 1
    in
    counts
        |> List.filter (\( path, _ ) -> List.length path == depth && List.take (depth - 1) path == parent)
        |> List.map
            (\( path, count ) ->
                Branch
                    { id = idOf path
                    , name = path |> List.drop (depth - 1) |> List.head |> Maybe.withDefault ""
                    , path = path
                    , count = count
                    }
                    (branchesOf counts path)
            )


{-| Joined with a control character, the "unit separator", which no name
contains. A slash would do for most catalogs, but "Audio/Video" below "Media"
and "Video" below "Media/Audio" would then have the same id.
-}
idOf : List String -> String
idOf path =
    String.join "\u{001F}" path


{-| The category with this id, wherever it is in the hierarchy.
-}
find : String -> List Branch -> Maybe Category
find id branches =
    case branches of
        [] ->
            Nothing

        (Branch category below) :: rest ->
            if category.id == id then
                Just category

            else
                case find id below of
                    Just found ->
                        Just found

                    Nothing ->
                        find id rest


{-| Is the product in this category, or somewhere below it?
-}
includes : Category -> Product -> Bool
includes category product =
    List.take (List.length category.path) product.category == category.path


{-| A path for people to read: `Hardware > Fasteners > Bolts`.
-}
pathLabel : List String -> String
pathLabel path =
    String.join " > " path
