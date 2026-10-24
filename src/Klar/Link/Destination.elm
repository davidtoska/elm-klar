module Klar.Link.Destination exposing
    ( Target
    , download
    , external
    , fileName
    , href
    , inactiveAttributes
    , internal
    , opensInNewTab
    )

{-| Where a link leads: the type behind `Klar.Link.Target`, kept here so that
`Klar.Button` (a link that looks like a button) can read it too.

Not meant for application code: an application makes a target with
`Link.internal`, `Link.external` or `Link.download`.

-}

import Html
import Html.Attributes as Attr
import Klar.Internal as Internal
import Klar.Link.Address as Address


{-| A checked address and what it is.
-}
type Target
    = Target { href : String, kind : Kind }


type Kind
    = Inside
    | Outside Address.Kind
    | File String


{-| A page of the application (see `Address.path`).
-}
internal : String -> Target
internal text =
    Target { href = Address.path text, kind = Inside }


{-| An address outside the application, or `Nothing` (see `Address.external`).
-}
external : String -> Maybe Target
external text =
    Address.external text
        |> Maybe.map (\checked -> Target { href = checked.href, kind = Outside checked.kind })


{-| A file made from a text: a `data:` address with the text percent-encoded as
UTF-8 (with `Internal.percentEncode`, which never throws on half of an emoji), and
the name the browser saves it under. A media type that is not `type/subtype`
becomes `application/octet-stream`, and an empty name becomes `download`.
-}
download : { fileName : String, mimeType : String, content : String } -> Target
download file =
    Target
        { href = "data:" ++ mediaType file.mimeType ++ ";charset=utf-8," ++ Internal.percentEncode file.content
        , kind =
            File
                (if String.isEmpty (String.trim file.fileName) then
                    "download"

                 else
                    String.trim file.fileName
                )
        }


mediaType : String -> String
mediaType text =
    let
        cleaned =
            String.toLower (String.trim text)

        allowed char =
            Char.isAlphaNum char || String.contains (String.fromChar char) "!#$&^_.+-/"
    in
    case String.split "/" cleaned of
        [ kind, sub ] ->
            if kind /= "" && sub /= "" && String.all allowed cleaned then
                cleaned

            else
                "application/octet-stream"

        _ ->
            "application/octet-stream"


{-| The text to put in `href`.
-}
href : Target -> String
href (Target target) =
    target.href


{-| Does the link open in a new tab? Only a page on the web does.
-}
opensInNewTab : Target -> Bool
opensInNewTab (Target target) =
    target.kind == Outside Address.Web


{-| The name to save a file under, for a target made with `download`.
-}
fileName : Target -> Maybe String
fileName (Target target) =
    case target.kind of
        File name ->
            Just name

        _ ->
            Nothing


{-| The attributes of a link that cannot be followed now (disabled, busy). It has
no `href`, so it is not a link for the browser; `role="link"` and
`aria-disabled` say what it is to a screen reader. A `focusable` one has
`tabindex="0"` and stays in the tab order, so that a link that becomes
unavailable while it has focus keeps the focus and a tooltip around it can be
read from the keyboard.

`target="_self"` changes nothing for an anchor without `href`, but it is the mark
that tells `Browser.application` to leave the click alone: Elm reports a click on
every other `<a>` to `onUrlRequest`, one without `href` as `External ""`, and the
usual `Nav.load ""` reloads the page.

-}
inactiveAttributes : { focusable : Bool } -> List (Html.Attribute msg)
inactiveAttributes { focusable } =
    [ Attr.attribute "role" "link"
    , Attr.attribute "aria-disabled" "true"
    , Internal.attrIf focusable (Attr.tabindex 0)
    , Attr.attribute "target" "_self"
    ]
