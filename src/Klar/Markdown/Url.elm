module Klar.Markdown.Url exposing (Kind(..), classify, host, hostName, maxLength)

{-| Which addresses a piece of Markdown may link to.

Text that comes from a person, or from a language model, is not trusted: an
address such as `javascript:alert(1)` must never reach an `href`. This module
decides, and it decides by an allowlist. An address is acceptable only when it
is

  - a fragment (`#intro`),
  - a relative path (`/orders/17`, `../orders`, `orders?page=2`),
  - an `http:` or `https:` address, which must have `//` straight after the
    colon (`https://example.com`), or one that starts with `//`,
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
                        schemeKind (String.toLower (String.left position first)) (String.dropLeft (position + 1) raw)


{-| The host of an `http:` or `https:` address, in lower case, or `Nothing` for
anything that is not clearly one. The host is read from the `//` that comes
straight after the scheme (or from the start of an address that begins with `//`),
and from nowhere else. An address with a user name, a port, a backslash, a percent
sign, brackets, a trailing dot or characters other than letters, digits, hyphens and
dots in the host is refused on purpose: it has no host that can be compared.
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
                        case String.indexes ":" raw of
                            position :: _ ->
                                String.dropLeft (position + 3) raw

                            [] ->
                                ""
            in
            hostName (firstSegment afterScheme)

        _ ->
            Nothing


{-| A host name as it is written in an address: labels of letters, digits and
hyphens (not at the ends of a label) separated by dots, each 1 to 63 and all
together at most 253 characters. Capitals become small letters. No port, no
trailing dot, no wildcard, no user name.
-}
hostName : String -> Maybe String
hostName text =
    let
        lower =
            String.toLower text

        labels =
            String.split "." lower
    in
    if lower == "" || String.length lower > 253 || not (List.all validLabel labels) then
        Nothing

    else
        Just lower


validLabel : String -> Bool
validLabel label =
    String.length label
        >= 1
        && String.length label
        <= 63
        && String.all (\c -> (c >= 'a' && c <= 'z') || isDigit c || c == '-') label
        && not (String.startsWith "-" label)
        && not (String.endsWith "-" label)


schemeKind : String -> String -> Maybe Kind
schemeKind scheme afterColon =
    if not (validScheme scheme) then
        Nothing

    else if scheme == "http" || scheme == "https" then
        -- the `//` must come straight after the colon: a browser reads `http:evil.example`
        -- and `http:/evil.example` as addresses on evil.example, and a check of the host that
        -- looks for the first `//` anywhere would be fooled by `http:evil.example//cdn.example.com`
        if String.startsWith "//" afterColon then
            Just External

        else
            Nothing

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
    if isNaN (toFloat code) then
        -- the first half of a pair without the second
        False

    else if code < 0x80 then
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
