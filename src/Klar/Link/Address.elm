module Klar.Link.Address exposing (Checked, Kind(..), external, path)

{-| The two checks that keep an unchecked string from becoming a link: an address
outside the application must have one of four schemes, and an address inside the
application can only be a path of the application. Not exposed; `Klar.Link` uses
it, and the tests of the package read it.
-}


{-| What an outside address is: a page on the web (it opens in a new tab), an
email address or a telephone number (they hand over to another program).
-}
type Kind
    = Web
    | Email
    | Phone


{-| An address that passed the check: the text to put in `href`, and what it is.
-}
type alias Checked =
    { href : String
    , kind : Kind
    }


{-| An address outside the application, or `Nothing` when it is not one that a
link may have. Only `http`, `https`, `mailto` and `tel` pass, so `javascript:`,
`data:`, `vbscript:`, `file:`, `blob:` and every other scheme cannot be built.
The scheme is compared without regard to case, and the text is trimmed.

A text that holds a control character (a tab or a line break in the middle of
`java script:` is thrown away by browsers, which is how a check on the plain
text gets fooled), a space or a backslash is not an address at all.

  - `http` and `https` need `//` and a host: `https://example.com/orders`.
  - `mailto` needs an address with an `@` before any `?`: `mailto:ada@example.com`.
  - `tel` needs a number with at least one digit: `tel:+4722000000`.

-}
external : String -> Maybe Checked
external raw =
    let
        text =
            String.trim raw
    in
    if String.isEmpty text || String.any isForbidden text then
        Nothing

    else
        case splitScheme text of
            Just ( scheme, rest ) ->
                case scheme of
                    "http" ->
                        web text rest

                    "https" ->
                        web text rest

                    "mailto" ->
                        if String.contains "@" (beforeQuery rest) && not (String.startsWith "@" (beforeQuery rest)) then
                            Just { href = text, kind = Email }

                        else
                            Nothing

                    "tel" ->
                        if String.any Char.isDigit rest then
                            Just { href = text, kind = Phone }

                        else
                            Nothing

                    _ ->
                        Nothing

            Nothing ->
                Nothing


web : String -> String -> Maybe Checked
web text rest =
    if String.startsWith "//" rest && hasHost (String.dropLeft 2 rest) then
        Just { href = text, kind = Web }

    else
        Nothing


{-| The part after `//`: up to the first `/`, `?` or `#` is the authority, and
its host (after a `user@`, before a `:port`) must not be empty.
-}
hasHost : String -> Bool
hasHost afterSlashes =
    let
        authority =
            afterSlashes
                |> String.split "/"
                |> List.head
                |> Maybe.withDefault ""
                |> String.split "?"
                |> List.head
                |> Maybe.withDefault ""
                |> String.split "#"
                |> List.head
                |> Maybe.withDefault ""

        hostAndPort =
            authority
                |> String.split "@"
                |> List.reverse
                |> List.head
                |> Maybe.withDefault ""

        host =
            if String.startsWith "[" hostAndPort then
                hostAndPort

            else
                hostAndPort |> String.split ":" |> List.head |> Maybe.withDefault ""
    in
    not (String.isEmpty host)


beforeQuery : String -> String
beforeQuery text =
    text |> String.split "?" |> List.head |> Maybe.withDefault ""


{-| `"https://x"` is `Just ( "https", "//x" )`. The scheme is lowercase and made of
the letters a browser allows in one; a text with a colon in a path before any
scheme (`/a:b`) has none.
-}
splitScheme : String -> Maybe ( String, String )
splitScheme text =
    case String.split ":" text of
        scheme :: _ :: _ ->
            if isScheme scheme then
                Just ( String.toLower scheme, String.dropLeft (String.length scheme + 1) text )

            else
                Nothing

        _ ->
            Nothing


isScheme : String -> Bool
isScheme scheme =
    case String.toList scheme of
        first :: rest ->
            isAsciiLetter first && List.all (\c -> isAsciiLetter c || Char.isDigit c || c == '+' || c == '-' || c == '.') rest

        [] ->
            False


isAsciiLetter : Char -> Bool
isAsciiLetter c =
    (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z')


{-| Spaces, control characters (also the ones a browser deletes from an address
without telling) and the backslash, which browsers read as a slash.
-}
isForbidden : Char -> Bool
isForbidden c =
    let
        code =
            Char.toCode c
    in
    code <= 0x20 || (code >= 0x7F && code <= 0x9F) || c == '\\'


{-| An address inside the application, as a path: whatever text comes in, the
result starts with a single `/` (and then no further slash), with `#` (a route in
the fragment) or with `?` (a query), so it can never leave the application: not
as `//evil.example` (which a browser reads as another site), not as
`javascript:...` or any other scheme.

  - `"/orders/12"`, `"#/orders/12"` and `"?page=2"` stay as they are.
  - `"orders/12"` becomes `"/orders/12"`, and `"javascript:alert(1)"` becomes the
    harmless path `"/javascript:alert(1)"`.
  - Several leading slashes (or backslashes, which browsers read as slashes)
    become one: `"//evil.example/x"` is `"/evil.example/x"`.
  - Control characters are removed, because a browser deletes them from an
    address before it reads it (`"/\t/evil.example"` would become `//evil.example`).

-}
path : String -> String
path raw =
    let
        text =
            raw
                |> String.trim
                |> String.filter (\c -> not (isControl c))
                |> String.map
                    (\c ->
                        if c == '\\' then
                            '/'

                        else
                            c
                    )
    in
    case String.uncons text of
        Nothing ->
            "/"

        Just ( '#', _ ) ->
            text

        Just ( '?', _ ) ->
            text

        Just ( '/', rest ) ->
            "/" ++ dropSlashes rest

        Just _ ->
            "/" ++ text


dropSlashes : String -> String
dropSlashes text =
    case String.uncons text of
        Just ( '/', rest ) ->
            dropSlashes rest

        _ ->
            text


isControl : Char -> Bool
isControl c =
    let
        code =
            Char.toCode c
    in
    code < 0x20 || (code >= 0x7F && code <= 0x9F)
