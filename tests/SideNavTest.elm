module SideNavTest exposing (suite)

{-| The keyboard of `Klar.SideNav`: the order of the arrow keys, open and collapsed, and
Right and Left on groups; the counts in the language of the menu; the tooltip only
where the label is hidden.
-}

import Expect
import Html exposing (Html)
import Html.Attributes as Attr
import Json.Encode as Encode
import Klar.Ids as Ids
import Klar.Locale as Locale
import Klar.SideNav as SideNav
import Test exposing (Test, describe, test)
import Test.Html.Event as Event
import Test.Html.Query as Query
import Test.Html.Selector as Selector


menu : List (SideNav.Entry String msg)
menu =
    [ SideNav.section "Workspace"
        [ SideNav.item Ids.string { key = "orders", label = "Orders", href = "#/orders" }
        , SideNav.group Ids.string
            { key = "reports", label = "Reports" }
            [ SideNav.item Ids.string { key = "monthly", label = "Monthly", href = "#/reports/monthly" }
            , SideNav.item Ids.string { key = "yearly", label = "Yearly", href = "#/reports/yearly" }
            , SideNav.item Ids.string { key = "secret", label = "Secret", href = "#/reports/secret" } |> SideNav.disabledItem
            ]
        , SideNav.item Ids.string { key = "customers", label = "Customers", href = "#/customers" }
        ]
    ]


closed : SideNav.State String
closed =
    SideNav.init "nav"


open : SideNav.State String
open =
    SideNav.expandGroup Ids.string "reports" closed


nav : List (SideNav.Attribute String SideNav.Msg) -> SideNav.State String -> Html SideNav.Msg
nav attributes state =
    SideNav.view identity (SideNav.entries menu :: attributes) state


key : String -> ( String, Encode.Value )
key name =
    Event.custom "keydown"
        (Encode.object
            [ ( "key", Encode.string name )
            , ( "ctrlKey", Encode.bool False )
            , ( "metaKey", Encode.bool False )
            , ( "shiftKey", Encode.bool False )
            , ( "altKey", Encode.bool False )
            ]
        )


{-| The message a key press on the element with this id sends.
-}
press : String -> String -> Html SideNav.Msg -> Result String SideNav.Msg
press domId name html =
    html
        |> Query.fromHtml
        |> Query.find [ Selector.id domId ]
        |> Event.simulate (key name)
        |> Event.toResult


link : String -> String
link name =
    "nav-link-" ++ name


group : String -> String
group name =
    "nav-group-" ++ name


suite : Test
suite =
    describe "Klar.SideNav"
        [ describe "the order of the arrow keys"
            [ test "Down from an open group goes to its first child (the same place Up from the second child goes)" <|
                \_ ->
                    press (group "reports") "ArrowDown" (nav [] open)
                        |> Expect.equal (press (link "yearly") "ArrowUp" (nav [] open))
            , test "Down from a closed group skips its children" <|
                \_ ->
                    -- End goes to the last entry, Customers
                    press (group "reports") "ArrowDown" (nav [] closed)
                        |> Expect.equal (press (link "orders") "End" (nav [] closed))
            , test "a collapsed menu has the same order: the drawer of a shell shows the full menu with the flag" <|
                \_ ->
                    press (group "reports") "ArrowDown" (nav [ SideNav.collapsed True ] open)
                        |> Expect.equal (press (link "yearly") "ArrowUp" (nav [ SideNav.collapsed True ] open))
            , test "Down from the last child of an open group leaves the group" <|
                \_ ->
                    press (link "yearly") "ArrowDown" (nav [] open)
                        |> Expect.equal (press (link "orders") "End" (nav [] open))
            , test "a disabled link is skipped: Up from the next entry goes past it" <|
                \_ ->
                    press (link "customers") "ArrowUp" (nav [] open)
                        |> Expect.equal (press (link "monthly") "ArrowDown" (nav [] open))
            , test "Up on the first entry does nothing" <|
                \_ ->
                    press (link "orders") "ArrowUp" (nav [] open)
                        |> Expect.err
            , test "Home and End reach the ends from anywhere" <|
                \_ ->
                    Expect.all
                        [ \_ -> press (link "yearly") "Home" (nav [] open) |> Expect.equal (press (link "customers") "Home" (nav [] open))
                        , \_ -> press (link "orders") "End" (nav [] open) |> Expect.equal (press (link "monthly") "End" (nav [] open))
                        ]
                        ()
            ]
        , describe "Right and Left"
            [ test "Right opens a closed group" <|
                \_ ->
                    press (group "reports") "ArrowRight" (nav [] closed)
                        |> Result.map (\msg -> SideNav.update msg closed |> Tuple.first |> SideNav.isExpanded Ids.string "reports")
                        |> Expect.equal (Ok True)
            , test "Right on an open group goes to its first child" <|
                \_ ->
                    press (group "reports") "ArrowRight" (nav [] open)
                        |> Expect.equal (press (group "reports") "ArrowDown" (nav [] open))
            , test "Left closes an open group" <|
                \_ ->
                    press (group "reports") "ArrowLeft" (nav [] open)
                        |> Result.map (\msg -> SideNav.update msg open |> Tuple.first |> SideNav.isExpanded Ids.string "reports")
                        |> Expect.equal (Ok False)
            , test "Left on an entry in a group goes to the group" <|
                \_ ->
                    press (link "yearly") "ArrowLeft" (nav [] open)
                        |> Expect.equal (press (link "monthly") "ArrowUp" (nav [] open))
            , test "Left on a top-level link does nothing" <|
                \_ ->
                    press (link "orders") "ArrowLeft" (nav [] open)
                        |> Expect.err
            ]
        , describe "counts and tooltips"
            [ test "a count above 99 reads 99+, with the number in the tooltip in the language of the menu" <|
                \_ ->
                    SideNav.view identity
                        [ SideNav.locale Locale.nb
                        , SideNav.entries [ SideNav.item Ids.string { key = "orders", label = "Orders", href = "#/orders" } |> SideNav.withCount 12345 ]
                        ]
                        closed
                        |> Query.fromHtml
                        |> Query.find [ Selector.class "klar-side-nav__count" ]
                        |> Query.has [ Selector.text "99+", Selector.attribute (Attr.title "12\u{00A0}345") ]
            , test "a link of the full menu has no tooltip: its label is there" <|
                \_ ->
                    nav [] open
                        |> Query.fromHtml
                        |> Query.find [ Selector.id (link "orders") ]
                        |> Query.hasNot [ Selector.attribute (Attr.title "Orders") ]
            , test "a link of the collapsed menu names its icon with a tooltip" <|
                \_ ->
                    nav [ SideNav.collapsed True ] open
                        |> Query.fromHtml
                        |> Query.find [ Selector.id (link "orders") ]
                        |> Query.has [ Selector.attribute (Attr.title "Orders") ]
            , test "the current link is marked for screen readers" <|
                \_ ->
                    nav [ SideNav.current "yearly" ] open
                        |> Query.fromHtml
                        |> Query.find [ Selector.id (link "yearly") ]
                        |> Query.has [ Selector.attribute (Attr.attribute "aria-current" "page") ]
            , test "a disabled link is not a link" <|
                \_ ->
                    nav [] open
                        |> Query.fromHtml
                        |> Query.find [ Selector.attribute (Attr.attribute "aria-disabled" "true") ]
                        |> Query.has [ Selector.tag "span", Selector.text "Secret" ]
            ]
        ]
