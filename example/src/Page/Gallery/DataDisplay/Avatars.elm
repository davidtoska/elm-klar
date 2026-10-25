module Page.Gallery.DataDisplay.Avatars exposing (portrait, view)

{-| The avatar section: sizes, status, pictures, icons and groups.
-}

import Html exposing (Html)
import Klar.Avatar as Avatar
import Klar.Icon as Icon
import Klar.Layout as Layout
import Klar.Locale exposing (Locale)
import Klar.Text as Text
import Klar.Theme exposing (Size(..))
import Showcase.Doc as Doc


view : Locale -> Html msg
view locale =
    let
        entries =
            List.map Avatar.entry people

        labelled caption avatar =
            Layout.stack [ Layout.gap 1, Layout.alignCenter ] [ avatar, Text.caption caption ]
    in
    Doc.section "Avatars"
        "Initials on a muted background. The color is derived from the name and is the same everywhere, so the same name always has the same color. A picture is laid over the initials, so a picture address that does not work still leaves something readable."
        [ Doc.example
            { title = "Sizes, status and picture"
            , description = Just "The status dot has a text version for screen readers. An avatar without a name shows a question mark. When the name is written next to the avatar, add decorative so that it is not read twice."
            , code = Just """Avatar.view [] "Ada Lovelace"

Avatar.view [ Avatar.size Large, Avatar.status Avatar.online ] "Grace Hopper"

Avatar.view [ Avatar.image url ] "Alan Turing"

Avatar.view [ Avatar.icon Icon.building, Avatar.square ] "Rotterdam Hub"

-- the name is written next to the avatar: hide the avatar from screen readers
Layout.row [] [ Avatar.view [ Avatar.decorative ] name, Text.strong name ]"""
            }
            (Layout.row [ Layout.gap 5, Layout.alignEnd, Layout.wrap ]
                [ labelled "18" (Avatar.view [ Avatar.extraSmall ] "Ada Lovelace")
                , labelled "22" (Avatar.view [ Avatar.size Small ] "Grace Hopper")
                , labelled "30" (Avatar.view [] "Alan Turing")
                , labelled "40" (Avatar.view [ Avatar.size Large ] "Margaret Hamilton")
                , labelled "64" (Avatar.view [ Avatar.extraLarge ] "Zoë Ångström")
                , labelled "Online" (Avatar.view [ Avatar.size Large, Avatar.status Avatar.online, Avatar.locale locale ] "Edsger Dijkstra")
                , labelled "Away" (Avatar.view [ Avatar.size Large, Avatar.status Avatar.away, Avatar.locale locale ] "Barbara Liskov")
                , labelled "Busy" (Avatar.view [ Avatar.size Large, Avatar.status Avatar.busy, Avatar.locale locale ] "Donald Knuth")
                , labelled "Offline" (Avatar.view [ Avatar.size Large, Avatar.status Avatar.offline, Avatar.locale locale ] "Katherine Johnson")
                , labelled "Picture" (Avatar.view [ Avatar.size Large, Avatar.image portrait ] "Dennis Ritchie")
                , labelled "Broken picture" (Avatar.view [ Avatar.size Large, Avatar.image "data:image/png;base64,AAAA" ] "Radia Perlman")
                , labelled "Icon" (Avatar.view [ Avatar.size Large, Avatar.square, Avatar.icon Icon.building ] "Rotterdam Hub")
                , labelled "System" (Avatar.view [ Avatar.size Large, Avatar.icon Icon.server ] "Order service")
                , labelled "No name" (Avatar.view [ Avatar.size Large ] "")
                , labelled "Decorative"
                    (Layout.row [ Layout.gap 2 ]
                        [ Avatar.view [ Avatar.size Large, Avatar.decorative ] "Linus Torvalds"
                        , Text.strong "Linus Torvalds"
                        ]
                    )
                ]
            )
        , Doc.example
            { title = "Group with “+N”"
            , description = Just "The avatars that do not fit become a “+N” bubble, and its tooltip lists their names. An entry can carry a picture of its own."
            , code = Just """Avatar.group [ Avatar.maxShown 4 ] (List.map Avatar.entry names)

Avatar.group [ Avatar.maxShown 3 ]
    [ Avatar.entry "Ada Lovelace"
    , Avatar.entry "Alan Turing" |> Avatar.withImage (Just url)
    , Avatar.entry "Grace Hopper"
    , Avatar.entry "Edsger Dijkstra"
    ]"""
            }
            (Layout.row [ Layout.gap 6, Layout.wrap, Layout.alignCenter ]
                [ Avatar.group [ Avatar.maxShown 4, Avatar.size Small, Avatar.locale locale ] (List.take 9 entries)
                , Avatar.group [ Avatar.maxShown 5, Avatar.locale locale ] entries
                , Avatar.group [ Avatar.maxShown 3, Avatar.size Large, Avatar.locale locale ] (List.take 5 entries)
                , Avatar.group [ Avatar.locale locale ] (List.take 2 entries)
                , Avatar.group [ Avatar.maxShown 3, Avatar.size Large, Avatar.locale locale ]
                    [ Avatar.entry "Dennis Ritchie" |> Avatar.withImage (Just portrait)
                    , Avatar.entry "Radia Perlman"
                    , Avatar.entry "Linus Torvalds" |> Avatar.withImage (Just portrait)
                    , Avatar.entry "Frances Allen"
                    ]
                ]
            )
        , Doc.example
            { title = "The colors follow the name"
            , description = Nothing
            , code = Nothing
            }
            (Layout.row [ Layout.gap 2, Layout.wrap ]
                (List.map (\name -> Avatar.view [] name) people)
            )
        ]


people : List String
people =
    [ "Ada Lovelace"
    , "Grace Hopper"
    , "Alan Turing"
    , "Margaret Hamilton"
    , "Edsger Dijkstra"
    , "Barbara Liskov"
    , "Donald Knuth"
    , "Katherine Johnson"
    , "Dennis Ritchie"
    , "Radia Perlman"
    , "Linus Torvalds"
    , "Frances Allen"
    , "Ken Thompson"
    , "Hedy Lamarr"
    , "Tim Berners-Lee"
    , "Jean Sammet"
    , "John McCarthy"
    , "Karen Spärck Jones"
    , "Niklaus Wirth"
    , "Sophie Wilson"
    , "Claude Shannon"
    , "Evelyn Boyd Granville"
    , "Leslie Lamport"
    , "Shafi Goldwasser"
    ]


{-| A picture as a data address, so the example needs no file.
-}
portrait : String
portrait =
    "data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 40 40'><rect width='40' height='40' fill='%2394b9e3'/><circle cx='20' cy='15' r='7' fill='%23ffffff'/><path d='M6 40c2-10 8-14 14-14s12 4 14 14z' fill='%23ffffff'/></svg>"
