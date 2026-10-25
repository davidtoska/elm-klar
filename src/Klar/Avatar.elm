module Klar.Avatar exposing
    ( view, group
    , Attribute, size, extraSmall, extraLarge, square, image, icon, status
    , Status, online, away, busy, offline
    , Entry, entry, withImage, maxShown
    , decorative, locale
    , initials
    )

{-| Avatars: a person, an organization or a system shown as a small badge with
initials, a picture or an icon.

Use when: a person, an organization or a system is shown as a small badge with initials, a picture or an icon.
Do not use when: a short text label or status is shown, use `Klar.Badge`.

    import Klar.Avatar as Avatar
    import Klar.Icon as Icon
    import Klar.Theme exposing (Size(..))

    Avatar.view [] "Ada Lovelace"

    Avatar.view [ Avatar.size Large, Avatar.status Avatar.online ] "Grace Hopper"

    Avatar.view [ Avatar.image "/images/grace.jpg" ] "Grace Hopper"

    Avatar.view [ Avatar.icon Icon.server, Avatar.square ] "Order service"

    Avatar.group [ Avatar.maxShown 4 ]
        (List.map (\person -> Avatar.entry person.name |> Avatar.withImage person.picture) people)

Without an image the avatar shows the initials of the name on a muted
background. The color is derived from the name, so the same name has the same
color everywhere. An image is laid over the initials, so a broken image URL
still leaves something readable behind it.

For screen readers an avatar is an image labelled with the name, and with the
status if there is one ("Grace Hopper, online"). When the name is written out
right next to the avatar, add `decorative` so that it is not read twice.

`group` shows several avatars side by side, overlapping, and folds the ones that
do not fit into a "+N" bubble. It takes a list of entries, made with `entry` and
given a picture with `withImage` (a `Maybe String`, so an optional picture
needs no `case`). In a group the `image` and `status`
attributes have no effect: every entry brings its own picture, and an entry has
no status (that is for single avatars).


# Views

@docs view, group


# Look

@docs Attribute, size, extraSmall, extraLarge, square, image, icon, status
@docs Status, online, away, busy, offline


# Groups

@docs Entry, entry, withImage, maxShown


# Accessibility and text

@docs decorative, locale


# Helpers

@docs initials

-}

import Html exposing (Html)
import Html.Attributes as Attr
import Klar.Avatar.Entry as E
import Klar.Format as Format
import Klar.Icon as Icon exposing (Icon)
import Klar.Internal as Internal
import Klar.Locale as Locale exposing (Locale)
import Klar.Theme exposing (Size(..))
import Klar.Tooltip as Tooltip


{-| A setting of an avatar. Make them with the functions below and pass a list
to `view` or `group`; later attributes win over earlier ones.
-}
type Attribute
    = Attribute (Config -> Config)


{-| Whether a person or a system is available, shown as a small colored dot in
the corner of the avatar and added to its accessible name: `online` (green),
`away` (amber), `busy` (red) or `offline` (gray). Pass one to `status`. The type
is opaque, so that statuses can be added in a later version.
-}
type Status
    = Online
    | Away
    | Busy
    | Offline


{-| Available: a green dot, "online" for screen readers.
-}
online : Status
online =
    Online


{-| Away for a while: an amber dot, "away" for screen readers.
-}
away : Status
away =
    Away


{-| Present but not to be disturbed: a red dot, "busy" for screen readers.
-}
busy : Status
busy =
    Busy


{-| Not available: a gray dot, "offline" for screen readers.
-}
offline : Status
offline =
    Offline


type alias Config =
    { scale : String
    , image : Maybe String
    , icon : Maybe Icon
    , status : Maybe Status
    , square : Bool
    , decorative : Bool
    , maxShown : Int
    , locale : Locale
    }


configure : List Attribute -> Config
configure attributes =
    List.foldl (\(Attribute change) config -> change config)
        { scale = "md"
        , image = Nothing
        , icon = Nothing
        , status = Nothing
        , square = False
        , decorative = False
        , maxShown = 4
        , locale = Locale.default
        }
        attributes



-- ATTRIBUTES


{-| The size of the avatar: `Small` is 22px, `Medium` 30px (the default) and
`Large` 40px. For 18px and 64px see `extraSmall` and `extraLarge`.
-}
size : Size -> Attribute
size value =
    Attribute
        (\config ->
            { config
                | scale =
                    case value of
                        Small ->
                            "sm"

                        Medium ->
                            "md"

                        Large ->
                            "lg"
            }
        )


{-| A 64px avatar, for profile headers and the top of a page.
-}
extraLarge : Attribute
extraLarge =
    Attribute (\config -> { config | scale = "xl" })


{-| An 18px avatar, for a byline or a dense table cell.
-}
extraSmall : Attribute
extraSmall =
    Attribute (\config -> { config | scale = "xs" })


{-| The URL of a picture, which covers the avatar. The initials stay behind it,
so something readable remains if the picture cannot be loaded. It has no effect
in a `group`, where every entry has its own picture.
-}
image : String -> Attribute
image url =
    Attribute (\config -> { config | image = Just url })


{-| An icon instead of the initials, for systems, rooms and organizations. Often
combined with `square`. In a `group` it applies to every avatar.
-}
icon : Icon -> Attribute
icon value =
    Attribute (\config -> { config | icon = Just value })


{-| A small dot in the corner that shows the status. The status is also added to
the accessible name ("Grace Hopper, online"). It has no effect in a `group`.
-}
status : Status -> Attribute
status value =
    Attribute (\config -> { config | status = Just value })


{-| A rounded square instead of a circle. Use it for things that are not people,
such as organizations, systems and warehouses.
-}
square : Attribute
square =
    Attribute (\config -> { config | square = True })


{-| Hides the avatar from screen readers. Use it when the name is written out
right next to the avatar. On a `group` it hides the whole group: the avatars,
the group itself and the "+N" bubble.
-}
decorative : Attribute
decorative =
    Attribute (\config -> { config | decorative = True })


{-| How many avatars `group` shows before it folds the rest into a "+N" bubble.
The default is 4, and the smallest value is 1.
-}
maxShown : Int -> Attribute
maxShown n =
    Attribute (\config -> { config | maxShown = max 1 n })


{-| The language of the built-in text: the status in the accessible name of an
avatar ("online", "away" ...) and the accessible names of a `group` and its "+N"
bubble. The default is `Locale.default`, which is English.
-}
locale : Locale -> Attribute
locale value =
    Attribute (\config -> { config | locale = value })



-- VIEW


{-| One avatar for the given name: its initials, or the picture or icon you give
it. The name is also the tooltip (except on a `decorative` avatar, whose name is
written next to it) and the accessible name. An avatar with a blank name and no
status has nothing to say, so it is hidden from assistive technology like a
`decorative` one.

    Avatar.view [ Avatar.status Avatar.away ] "Ada Lovelace"

-}
view : List Attribute -> String -> Html msg
view attributes name =
    let
        config =
            configure attributes
    in
    render config { name = name, image = config.image }


{-| One entry of an avatar group: a name and, if you give one with `withImage`,
a picture. The type is opaque, so that an entry can learn more in a later
version without breaking your code. Make one with `entry`.
-}
type alias Entry =
    E.Entry


{-| An entry for `group` with this name and no picture.

    Avatar.entry "Ada Lovelace"

-}
entry : String -> Entry
entry =
    E.entry


{-| The URL of the picture of an entry, which covers its initials (they stay
behind it, so something readable remains if the picture cannot be loaded). It
takes a `Maybe`, because a picture is usually optional data: `Nothing` leaves the
initials.

    Avatar.entry person.name |> Avatar.withImage person.picture

    Avatar.entry "Grace Hopper" |> Avatar.withImage (Just "/images/grace.jpg")

-}
withImage : Maybe String -> Entry -> Entry
withImage =
    E.withImage


{-| Overlapping avatars for a list of entries, with a "+N" bubble for those that
do not fit (see `maxShown`). The tooltip and the accessible name of the bubble
list the names that are hidden, up to 12 of them; the keyboard reaches the bubble
(one Tab stop), and its tooltip shows on focus too. The group as a whole has an
accessible name that tells how many avatars it holds, such as "3 avatars". An
empty list shows nothing.

    Avatar.group [ Avatar.maxShown 3 ]
        [ Avatar.entry "Ada Lovelace"
        , Avatar.entry "Grace Hopper"
        , Avatar.entry "Alan Turing" |> Avatar.withImage (Just "/images/alan.jpg")
        , Avatar.entry "Edsger Dijkstra"
        ]

-}
group : List Attribute -> List Entry -> Html msg
group attributes entries =
    if List.isEmpty entries then
        Html.text ""

    else
        groupOf attributes entries


groupOf : List Attribute -> List Entry -> Html msg
groupOf attributes entries =
    let
        config =
            configure attributes

        shown =
            List.take config.maxShown entries

        hidden =
            List.drop config.maxShown entries

        hiddenCount =
            List.length hidden

        hiddenNames =
            hidden
                |> List.take 12
                |> List.map E.name
                |> String.join ", "
                |> (\names ->
                        if hiddenCount > 12 then
                            names ++ " ..."

                        else
                            names
                   )

        overflow =
            if hiddenCount == 0 then
                Html.text ""

            else
                Html.span
                    (Internal.cls [ "klar-avatar", "klar-avatar--" ++ config.scale, "klar-avatar--more" ]
                        :: (if config.decorative then
                                [ Attr.title hiddenNames, Attr.attribute "aria-hidden" "true" ]

                            else
                                -- The keyboard reaches the bubble, and its tip lists the
                                -- names that are folded into it (a title shows on hover only).
                                Tooltip.attrs [ Tooltip.focusable ] hiddenNames
                                    ++ [ Attr.attribute "role" "img"
                                       , Attr.attribute "aria-label"
                                            (Format.int config.locale hiddenCount
                                                ++ " "
                                                ++ Locale.pick config.locale { nb = "til", en = "more" }
                                                ++ ": "
                                                ++ hiddenNames
                                            )
                                       ]
                           )
                    )
                    [ Html.span [ Internal.cls [ "klar-avatar__initials" ], Attr.attribute "aria-hidden" "true" ]
                        [ Html.text ("+" ++ Format.int config.locale hiddenCount) ]
                    ]

        total =
            List.length entries

        -- A group can hold people, organizations and systems, so its name only
        -- counts the avatars.
        groupName =
            Format.int config.locale total
                ++ " "
                ++ Format.plural config.locale
                    total
                    { one = Locale.pick config.locale { nb = "avatar", en = "avatar" }
                    , other = Locale.pick config.locale { nb = "avatarer", en = "avatars" }
                    }
    in
    Html.span
        (Internal.cls [ "klar-avatar-group", "klar-avatar-group--" ++ config.scale ]
            :: (if config.decorative then
                    [ Attr.attribute "aria-hidden" "true" ]

                else
                    [ Attr.attribute "role" "group", Attr.attribute "aria-label" groupName ]
               )
        )
        (List.map (\e -> render { config | status = Nothing } { name = E.name e, image = E.image e }) shown ++ [ overflow ])


render : Config -> { name : String, image : Maybe String } -> Html msg
render config person =
    let
        label =
            case ( Internal.nonEmpty person.name, config.status ) of
                ( Just name, Just s ) ->
                    name ++ ", " ++ statusLabel config.locale s

                ( Just name, Nothing ) ->
                    name

                ( Nothing, Just s ) ->
                    statusLabel config.locale s

                ( Nothing, Nothing ) ->
                    ""

        tone =
            if String.isEmpty (String.trim person.name) && config.icon == Nothing then
                "klar-avatar--neutral"

            else
                "klar-avatar--c" ++ String.fromInt (colorIndex person.name)
    in
    Html.span
        ([ Internal.cls
            [ "klar-avatar"
            , "klar-avatar--" ++ config.scale
            , tone
            , if config.square then
                "klar-avatar--square"

              else
                ""
            ]
         , Internal.attrIf (not config.decorative) (Attr.title person.name)
         ]
            ++ (if config.decorative || label == "" then
                    -- nothing to say about an avatar without a name or a status
                    [ Attr.attribute "aria-hidden" "true" ]

                else
                    [ Attr.attribute "role" "img", Attr.attribute "aria-label" label ]
               )
        )
        [ case config.icon of
            Just glyph ->
                Html.span [ Internal.cls [ "klar-avatar__glyph" ], Attr.attribute "aria-hidden" "true" ] [ Icon.view glyph ]

            Nothing ->
                Html.span [ Internal.cls [ "klar-avatar__initials" ], Attr.attribute "aria-hidden" "true" ]
                    [ Html.text (initials person.name) ]
        , case person.image of
            Just url ->
                Html.span
                    [ Internal.cls [ "klar-avatar__image" ]
                    , Internal.styleVars [ ( "background-image", cssUrl url ) ]
                    , Attr.attribute "aria-hidden" "true"
                    ]
                    []

            Nothing ->
                Html.text ""
        , case config.status of
            Just s ->
                Html.span [ Internal.cls [ "klar-avatar__status", "klar-avatar__status--" ++ statusSuffix s ] ] []

            Nothing ->
                Html.text ""
        ]



-- HELPERS


{-| The initials an avatar shows for a name: the first letter of the first and of
the last word, in capital letters. Words in brackets ("(Finance)"), the suffixes
Jr, Sr, II, III and IV, and symbols and emoji do not count. A single word gives
one letter, and a name without letters gives "?".

    Avatar.initials "Ada Lovelace" --> "AL"

    Avatar.initials "Ada Lovelace (Finance)" --> "AL"

    Avatar.initials "Martin Luther King Jr." --> "MK"

    Avatar.initials "Warehouse" --> "W"

    Avatar.initials "" --> "?"

-}
initials : String -> String
initials name =
    let
        letters =
            String.words name
                |> withoutBrackets
                |> List.filter (not << isSuffix)
                |> List.map firstLetter
                |> List.filter (\l -> l /= "")

        fallback =
            -- a name that is only a suffix or only in brackets still has letters
            String.words name
                |> List.map firstLetter
                |> List.filter (\l -> l /= "")
    in
    case
        if List.isEmpty letters then
            fallback

        else
            letters
    of
        [] ->
            "?"

        [ only ] ->
            String.toUpper only

        first :: rest ->
            String.toUpper (first ++ (List.reverse rest |> List.head |> Maybe.withDefault ""))


firstLetter : String -> String
firstLetter word =
    word
        |> String.toList
        |> List.filter isLetter
        |> List.head
        |> Maybe.map String.fromChar
        |> Maybe.withDefault ""


{-| The words outside brackets: "Ada Lovelace (Finance team)" is "Ada Lovelace".
-}
withoutBrackets : List String -> List String
withoutBrackets words =
    let
        step word ( depth, kept ) =
            let
                opens =
                    String.length (String.filter (\c -> c == '(' || c == '[') word)

                closes =
                    String.length (String.filter (\c -> c == ')' || c == ']') word)

                inside =
                    depth > 0 || opens > 0
            in
            ( max 0 (depth + opens - closes)
            , if inside then
                kept

              else
                word :: kept
            )
    in
    List.foldl step ( 0, [] ) words
        |> Tuple.second
        |> List.reverse


isSuffix : String -> Bool
isSuffix word =
    List.member (String.toLower (String.filter Char.isAlpha word)) [ "jr", "sr", "ii", "iii", "iv" ]
        && not (String.isEmpty (String.filter Char.isAlpha word))


{-| A letter or a digit of any script: the code points above ASCII count, except
punctuation, symbols, arrows, dingbats and emoji.
-}
isLetter : Char -> Bool
isLetter c =
    let
        code =
            Char.toCode c
    in
    if code < 128 then
        Char.isAlphaNum c

    else
        not
            ((code >= 0xA0 && code <= 0xBF)
                || code
                == 0xD7
                || code
                == 0xF7
                || (code >= 0x2000 && code <= 0x2BFF)
                || (code >= 0x3000 && code <= 0x303F)
                || (code >= 0xFE00 && code <= 0xFE0F)
                || (code >= 0xFF00 && code <= 0xFF0F)
                || code
                >= 0x0001F000
            )


{-| A stable number from 0 to 7 for a name.
-}
colorIndex : String -> Int
colorIndex name =
    name
        |> String.toLower
        |> String.trim
        |> String.foldl (\c h -> modBy 100003 (h * 31 + Char.toCode c)) 7
        |> modBy 8


statusSuffix : Status -> String
statusSuffix value =
    case value of
        Online ->
            "online"

        Away ->
            "away"

        Busy ->
            "busy"

        Offline ->
            "offline"


statusLabel : Locale -> Status -> String
statusLabel loc value =
    case value of
        Online ->
            Locale.pick loc { nb = "pålogget", en = "online" }

        Away ->
            Locale.pick loc { nb = "borte", en = "away" }

        Busy ->
            Locale.pick loc { nb = "opptatt", en = "busy" }

        Offline ->
            Locale.pick loc { nb = "frakoblet", en = "offline" }


{-| `url("...")` with the characters that could end the string escaped.
-}
cssUrl : String -> String
cssUrl url =
    "url(\""
        ++ (url
                |> String.replace "\\" "%5C"
                |> String.replace "\"" "%22"
                |> String.replace "\n" ""
                |> String.replace "\u{000D}" ""
           )
        ++ "\")"
