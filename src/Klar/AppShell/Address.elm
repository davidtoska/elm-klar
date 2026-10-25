module Klar.AppShell.Address exposing
    ( Effect(..)
    , Follow(..)
    , Landing(..)
    , Nav
    , arrive
    , follow
    , followLink
    , samePage
    , targetId
    )

{-| The decisions `Klar.AppShell` makes about addresses, as pure functions: how a click
on a link inside the application is followed, whether a new address is a new page or
the same page with another query, and where focus goes when a page arrives.

`followLink` and `arrive` are the whole state machine of the shell's navigation. They
return the effects as data (`Effect`), which `Klar.AppShell` turns into commands, so the
rules can be tested without a `Nav.Key`.

-}

import Browser
import Url exposing (Url)


{-| How a click on a link inside the application is followed.

  - `Push`: a new page or a new query, a new entry in the history.
  - `Replace`: the address the user is on already (the link of the current page in the
    side menu): the page is entered again, without another entry in the history, so
    Back does not need one press per click.
  - `Anchor`: only the fragment differs and it is not a route (`#field-id`, not
    `#/orders`): a link to an element of the page. The shell scrolls the content to it,
    moves focus there (when it can take focus) and stays on the page.

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



-- THE STATE MACHINE


{-| The part of the shell's state that navigation reads and changes.

  - `url`: the address the user is on.
  - `drawerOpen`: whether the sidebar drawer of a narrow shell is open.
  - `enterOn`: the link of the side menu that Enter was pressed on, before its click.
  - `landing`: where focus goes when the next new page arrives.

-}
type alias Nav =
    { url : Url
    , drawerOpen : Bool
    , enterOn : Maybe Url
    , landing : Landing
    }


{-| Where focus goes when the next new page arrives.

  - `Stay`: no link of the shell is on its way. The new address is the Back or Forward
    button, or a `pushUrl` of the application, which comes from a control that may well
    keep focus (route tabs, a row of a list, a step): focus stays where it is.
  - `ToContent`: the shell followed a link, whose element goes with the old page: focus
    goes to the content.
  - `OnLink`: the user chose the page with Enter on a link of the side menu, which stays:
    focus stays on that link.

-}
type Landing
    = Stay
    | ToContent
    | OnLink


{-| What the shell does, as data.
-}
type Effect
    = PushUrl String
    | ReplaceUrl String
    | Load String
    | FocusContent
    | ResetScroll
    | ShowElement String


{-| A click on a link, as `AppShell.follow` handles it. A link chosen in the open drawer
closes the drawer and sends focus to the content at once, because the links of a closed
drawer cannot hold it (also when only the query changes, so no new page comes).
-}
followLink : Browser.UrlRequest -> Nav -> ( Nav, List Effect )
followLink request nav =
    case request of
        Browser.Internal wanted ->
            let
                fromDrawer =
                    if nav.drawerOpen then
                        [ FocusContent ]

                    else
                        []

                landing =
                    if not nav.drawerOpen && nav.enterOn == Just wanted then
                        OnLink

                    else
                        ToContent

                leaving =
                    { nav | drawerOpen = False, enterOn = Nothing, landing = landing }
            in
            case follow nav.url wanted of
                Push href ->
                    ( leaving, PushUrl href :: fromDrawer )

                Replace href ->
                    -- The same address: no new page comes.
                    ( { leaving | landing = Stay }, ReplaceUrl href :: fromDrawer )

                Anchor target ->
                    ( { nav | enterOn = Nothing }, [ ShowElement target ] )

        Browser.External href ->
            ( { nav | enterOn = Nothing }, [ Load href ] )


{-| A new address, from a link, the Back or Forward button or a `pushUrl` of the
application. A new page closes the drawer and scrolls the content to the top; focus goes
to the content when the shell followed a link to it (see `Landing`) or when the drawer
that held focus closes. The same page with another query changes none of that.
-}
arrive : Url -> Nav -> ( Nav, List Effect )
arrive url nav =
    let
        newPage =
            not (samePage nav.url url)

        next =
            { nav
                | url = url
                , drawerOpen = nav.drawerOpen && not newPage
                , enterOn = Nothing
                , landing = Stay
            }
    in
    if newPage then
        ( next
        , if nav.drawerOpen || nav.landing == ToContent then
            [ ResetScroll, FocusContent ]

          else
            [ ResetScroll ]
        )

    else
        ( next, [] )
