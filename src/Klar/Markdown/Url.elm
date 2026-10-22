module Klar.Markdown.Url exposing (Kind(..), classify, host, maxLength)

{-| Which addresses a piece of Markdown may link to.

Text that comes from a person, or from a language model, is not trusted: an
address such as `javascript:alert(1)` must never reach an `href`. This module
decides, and it decides by an allowlist. An address is acceptable only when it
is

  - a fragment (`#intro`),
  - a relative path (`/orders/17`, `../orders`, `orders?page=2`),
  - an `http:` or `https:` address (or one that starts with `//`),
  - a `mailto:` or `tel:` address.

Everything else is refused: other schemes (`javascript:`, `data:`, `vbscript:`,
`file:` ...), a scheme written with control characters, white space or a
percent-encoded colon, a backslash, an empty address, and an address that is
very long.

-}


{-| What a safe address points at.
-}
type Kind
    = Fragment
    | Relative
    | Contact
    | External


{-| The longest address that is linked, in characters.
-}
maxLength : Int
maxLength =
    2048


{-| Is the address safe to put in an `href`, and what is it?
-}
classify : String -> Maybe Kind
classify raw =
    if raw == "" || String.length raw > maxLength || not (String.all acceptable raw) then
        Nothing

    else
        case String.uncons raw of
            Just ( '#', _ ) ->
                Just Fragment

            Just ( '/', rest ) ->
                if String.startsWith "/" rest then
                    Just External

                else
                    Just Relative

            _ ->
                let
                    first =
                        firstSegment raw
                in
                case String.indexes ":" first of
                    [] ->
                        if hasEncodedColon first || String.contains "&" first then
                            Nothing

                        else
                            Just Relative

                    position :: _ ->
                        schemeKind (String.toLower (String.left position first))


{-| The host of an `http:` or `https:` address, in lower case, or `Nothing` for
anything that is not clearly one: an address with a user name, a backslash, a
percent sign or brackets in the host part is refused on purpose. A protocol
relative address (`//host/path`) has a host as well.
-}
host : String -> Maybe String
host raw =
    case classify raw of
        Just External ->
            let
                afterScheme =
                    if String.startsWith "//" raw then
                        String.dropLeft 2 raw

                    else
                        case String.indexes "//" raw of
                            position :: _ ->
                                String.dropLeft (position + 2) raw

                            [] ->
                                ""

                authority =
                    firstSegment afterScheme

                name =
                    case String.indexes ":" authority of
                        position :: _ ->
                            String.left position authority

                        [] ->
                            authority
            in
            if name == "" || String.any (\c -> c == '@' || c == '%' || c == '[' || c == ']') authority then
                Nothing

            else
                Just (String.toLower name)

        _ ->
            Nothing


schemeKind : String -> Maybe Kind
schemeKind scheme =
    if not (validScheme scheme) then
        Nothing

    else if scheme == "http" || scheme == "https" then
        Just External

    else if scheme == "mailto" || scheme == "tel" then
        Just Contact

    else
        Nothing


validScheme : String -> Bool
validScheme scheme =
    case String.uncons scheme of
        Just ( first, rest ) ->
            isAsciiLetter first && String.all (\c -> isAsciiLetter c || isDigit c || c == '+' || c == '-' || c == '.') rest

        Nothing ->
            False


{-| The text up to the first `/`, `?` or `#`.
-}
firstSegment : String -> String
firstSegment text =
    String.foldr
        (\c rest ->
            if c == '/' || c == '?' || c == '#' then
                ""

            else
                String.cons c rest
        )
        ""
        text


hasEncodedColon : String -> Bool
hasEncodedColon segment =
    String.contains "%3a" (String.toLower segment)


{-| Characters an address may contain: printable, no white space of any kind (a
browser removes tabs and new lines inside an address, which is how
`java<tab>script:` gets through a naive check), no control characters and no
backslash (a browser reads it as a slash).
-}
acceptable : Char -> Bool
acceptable c =
    let
        code =
            Char.toCode c
    in
    if code < 0x80 then
        code > 0x20 && code < 0x7F && not (List.member c [ '\\', '<', '>', '"', '`' ])

    else
        -- C1 controls and the no-break space, the soft hyphen, the spaces and the
        -- invisible and direction-changing characters of U+2000 to U+206F, the byte
        -- order mark and lone halves of a surrogate pair
        not (code <= 0xA0 || code == 0xAD || code == 0x1680 || (code >= 0x2000 && code <= 0x206F) || code == 0x3000 || code == 0xFEFF || (code >= 0xD800 && code <= 0xDFFF))


isAsciiLetter : Char -> Bool
isAsciiLetter c =
    (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z')


isDigit : Char -> Bool
isDigit c =
    c >= '0' && c <= '9'
