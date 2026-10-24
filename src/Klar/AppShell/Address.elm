module Klar.AppShell.Address exposing (Follow(..), follow, samePage, targetId)

{-| The decisions `Klar.AppShell` makes about addresses, as pure functions: how a click
on a link inside the application is followed, and whether a new address is a new page
or the same page with another query.
-}

import Url exposing (Url)


{-| How a click on a link inside the application is followed.

  - `Push`: a new page or a new query, a new entry in the history.
  - `Replace`: the address the user is on already (the link of the current page in the
    side menu): the page is entered again, without another entry in the history, so
    Back does not need one press per click.
  - `Anchor`: only the fragment differs and it is not a route (`#field-id`, not
    `#/orders`): a link to an element of the page. The shell moves focus there, and
    follows the address as a route only when no element has that id.

-}
type Follow
    = Push String
    | Replace String
    | Anchor String


{-| How to follow a click from the address the user is on to the one the link names.
-}
follow : Url -> Url -> Follow
follow current wanted =
    if Url.toString wanted == Url.toString current then
        Replace (Url.toString wanted)

    else
        case targetId current wanted of
            Just target ->
                Anchor target

            Nothing ->
                Push (Url.toString wanted)


{-| The id an in-page link points at: the fragment, when it is the only difference
from the address the user is on and it is not a route (a route fragment starts with
`/`).
-}
targetId : Url -> Url -> Maybe String
targetId current wanted =
    case wanted.fragment of
        Just fragment ->
            if
                (fragment /= "")
                    && not (String.startsWith "/" fragment)
                    && ({ wanted | fragment = Nothing } == { current | fragment = Nothing })
            then
                Just (Maybe.withDefault fragment (Url.percentDecode fragment))

            else
                Nothing

        Nothing ->
            Nothing


{-| Whether two addresses show the same page: the same path and, for an application that
routes on the fragment, the same fragment up to its own `?`. The query (filters, the sort,
the active tab) is not part of the page, so a `replaceUrl` that only changes it keeps the
scroll position, the drawer and the focus: `#/orders?status=open` and
`#/orders?status=done` are the same page, `#/orders` and `#/orders/10482` are not.
-}
samePage : Url -> Url -> Bool
samePage a b =
    pageOf a == pageOf b


pageOf : Url -> ( String, String )
pageOf url =
    ( url.path
    , case url.fragment of
        Just fragment ->
            fragment |> String.split "?" |> List.head |> Maybe.withDefault ""

        Nothing ->
            ""
    )
