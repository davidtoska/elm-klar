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
import Showcase.Config as Config
import Showcase.Doc as Doc
import Showcase.Options as Options


view : Config.Config -> Locale -> Html msg
view playground locale =
    let
        entries =
            List.map Avatar.entry people

        labelled caption avatar =
            Layout.stack (Options.klarLayout playground (List.concat [ Config.keep playground "Layout" "gap" (Layout.gap 1), Config.keep playground "Layout" "alignCenter" Layout.alignCenter ])) [ avatar, Text.caption caption ]
    in
    Doc.configuredSection playground
        [ "Avatar" ]
        "Avatars"
        "Initials on a muted background. The color is derived from the name and is the same everywhere, so the same name always has the same color. A picture is laid over the initials, so a picture address that does not work still leaves something readable."
        [ Doc.configuredExample playground
            [ "Avatar" ]
            { title = "Sizes, status and picture"
            , description = Just "The status dot has a text version for screen readers. An avatar without a name shows a question mark. When the name is written next to the avatar, add decorative so that it is not read twice."
            , code = Just """Avatar.view [] "Ada Lovelace"

Avatar.view [ Avatar.size Large, Avatar.status Avatar.online ] "Grace Hopper"

Avatar.view [ Avatar.image url ] "Alan Turing"

Avatar.view [ Avatar.icon Icon.building, Avatar.square ] "Rotterdam Hub"

-- the name is written next to the avatar: hide the avatar from screen readers
Layout.row [] [ Avatar.view [ Avatar.decorative ] name, Text.strong name ]"""
            }
            (Layout.row (Options.klarLayout playground (List.concat [ Config.keep playground "Layout" "gap" (Layout.gap 5), Config.keep playground "Layout" "alignEnd" Layout.alignEnd, Config.keep playground "Layout" "wrap" Layout.wrap ]))
                [ labelled "18" (Avatar.view (Options.klarAvatar playground (List.concat [ Config.keep playground "Avatar" "extraSmall" Avatar.extraSmall ])) "Ada Lovelace")
                , labelled "22" (Avatar.view (Options.klarAvatar playground (List.concat [ Config.keep playground "Avatar" "size" (Avatar.size Small) ])) "Grace Hopper")
                , labelled "30" (Avatar.view [] "Alan Turing")
                , labelled "40" (Avatar.view (Options.klarAvatar playground (List.concat [ Config.keep playground "Avatar" "size" (Avatar.size Large) ])) "Margaret Hamilton")
                , labelled "64" (Avatar.view (Options.klarAvatar playground (List.concat [ Config.keep playground "Avatar" "extraLarge" Avatar.extraLarge ])) "Zoë Ångström")
                , labelled "Online" (Avatar.view (Options.klarAvatar playground (List.concat [ Config.keep playground "Avatar" "size" (Avatar.size Large), Config.keep playground "Avatar" "status" (Avatar.status Avatar.online), Config.keep playground "Avatar" "locale" (Avatar.locale locale) ])) "Edsger Dijkstra")
                , labelled "Away" (Avatar.view (Options.klarAvatar playground (List.concat [ Config.keep playground "Avatar" "size" (Avatar.size Large), Config.keep playground "Avatar" "status" (Avatar.status Avatar.away), Config.keep playground "Avatar" "locale" (Avatar.locale locale) ])) "Barbara Liskov")
                , labelled "Busy" (Avatar.view (Options.klarAvatar playground (List.concat [ Config.keep playground "Avatar" "size" (Avatar.size Large), Config.keep playground "Avatar" "status" (Avatar.status Avatar.busy), Config.keep playground "Avatar" "locale" (Avatar.locale locale) ])) "Donald Knuth")
                , labelled "Offline" (Avatar.view (Options.klarAvatar playground (List.concat [ Config.keep playground "Avatar" "size" (Avatar.size Large), Config.keep playground "Avatar" "status" (Avatar.status Avatar.offline), Config.keep playground "Avatar" "locale" (Avatar.locale locale) ])) "Katherine Johnson")
                , labelled "Picture" (Avatar.view (Options.klarAvatar playground (List.concat [ Config.keep playground "Avatar" "size" (Avatar.size Large), Config.keep playground "Avatar" "image" (Avatar.image portrait) ])) "Dennis Ritchie")
                , labelled "Broken picture" (Avatar.view (Options.klarAvatar playground (List.concat [ Config.keep playground "Avatar" "size" (Avatar.size Large), Config.keep playground "Avatar" "image" (Avatar.image "data:image/png;base64,AAAA") ])) "Radia Perlman")
                , labelled "Icon" (Avatar.view (Options.klarAvatar playground (List.concat [ Config.keep playground "Avatar" "size" (Avatar.size Large), Config.keep playground "Avatar" "square" Avatar.square, Config.keep playground "Avatar" "icon" (Avatar.icon Icon.building) ])) "Rotterdam Hub")
                , labelled "System" (Avatar.view (Options.klarAvatar playground (List.concat [ Config.keep playground "Avatar" "size" (Avatar.size Large), Config.keep playground "Avatar" "icon" (Avatar.icon Icon.server) ])) "Order service")
                , labelled "No name" (Avatar.view (Options.klarAvatar playground (List.concat [ Config.keep playground "Avatar" "size" (Avatar.size Large) ])) "")
                , labelled "Decorative"
                    (Layout.row (Options.klarLayout playground (List.concat [ Config.keep playground "Layout" "gap" (Layout.gap 2) ]))
                        [ Avatar.view (Options.klarAvatar playground (List.concat [ Config.keep playground "Avatar" "size" (Avatar.size Large), Config.keep playground "Avatar" "decorative" Avatar.decorative ])) "Linus Torvalds"
                        , Text.strong "Linus Torvalds"
                        ]
                    )
                ]
            )
        , Doc.configuredExample playground
            [ "Avatar" ]
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
            (Layout.row (Options.klarLayout playground (List.concat [ Config.keep playground "Layout" "gap" (Layout.gap 6), Config.keep playground "Layout" "wrap" Layout.wrap, Config.keep playground "Layout" "alignCenter" Layout.alignCenter ]))
                [ Avatar.group (Options.klarAvatar playground (List.concat [ Config.keep playground "Avatar" "maxShown" (Avatar.maxShown 4), Config.keep playground "Avatar" "size" (Avatar.size Small), Config.keep playground "Avatar" "locale" (Avatar.locale locale) ])) (List.take 9 entries)
                , Avatar.group (Options.klarAvatar playground (List.concat [ Config.keep playground "Avatar" "maxShown" (Avatar.maxShown 5), Config.keep playground "Avatar" "locale" (Avatar.locale locale) ])) entries
                , Avatar.group (Options.klarAvatar playground (List.concat [ Config.keep playground "Avatar" "maxShown" (Avatar.maxShown 3), Config.keep playground "Avatar" "size" (Avatar.size Large), Config.keep playground "Avatar" "locale" (Avatar.locale locale) ])) (List.take 5 entries)
                , Avatar.group (Options.klarAvatar playground (List.concat [ Config.keep playground "Avatar" "locale" (Avatar.locale locale) ])) (List.take 2 entries)
                , Avatar.group (Options.klarAvatar playground (List.concat [ Config.keep playground "Avatar" "maxShown" (Avatar.maxShown 3), Config.keep playground "Avatar" "size" (Avatar.size Large), Config.keep playground "Avatar" "locale" (Avatar.locale locale) ]))
                    [ Avatar.entry "Dennis Ritchie" |> Avatar.withImage (Just portrait)
                    , Avatar.entry "Radia Perlman"
                    , Avatar.entry "Linus Torvalds" |> Avatar.withImage (Just portrait)
                    , Avatar.entry "Frances Allen"
                    ]
                ]
            )
        , Doc.configuredExample playground
            [ "Avatar" ]
            { title = "The colors follow the name"
            , description = Nothing
            , code = Nothing
            }
            (Layout.row (Options.klarLayout playground (List.concat [ Config.keep playground "Layout" "gap" (Layout.gap 2), Config.keep playground "Layout" "wrap" Layout.wrap ]))
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
