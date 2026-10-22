module ButtonGroupTest exposing (suite)

import Expect
import Html exposing (Html)
import Html.Attributes as Attr
import Klar.Button as Button
import Klar.ButtonGroup as ButtonGroup
import Klar.Icon as Icon
import Klar.Menu as Menu
import Klar.Theme exposing (Size(..))
import Support.ActionsQuery as ActionsQuery
import Test exposing (Test, describe, test)
import Test.Html.Event as Event
import Test.Html.Query as Query
import Test.Html.Selector as Selector


suite : Test
suite =
    describe "Klar.ButtonGroup"
        [ test "is a group with an accessible name" <|
            \_ ->
                group []
                    |> Query.fromHtml
                    |> Query.has
                        [ Selector.tag "fieldset"
                        , Selector.attribute (Attr.attribute "role" "group")
                        , Selector.attribute (Attr.attribute "aria-label" "Order actions")
                        ]
        , test "holds ordinary buttons, in order, each one still a button" <|
            \_ ->
                group []
                    |> Query.fromHtml
                    |> Expect.all
                        [ ActionsQuery.count [ Selector.tag "button" ] >> Expect.equal 3
                        , Query.children [ Selector.tag "button" ] >> Query.count (Expect.equal 3)
                        , Query.children [] >> Query.first >> Query.has [ Selector.text "Edit" ]
                        , Query.children [] >> Query.index 2 >> Query.has [ Selector.attribute (Attr.attribute "aria-label" "Print") ]
                        ]
        , test "the buttons keep their messages" <|
            \_ ->
                group []
                    |> Query.fromHtml
                    |> Query.find [ Selector.tag "button", Selector.containing [ Selector.text "Duplicate" ] ]
                    |> Event.simulate Event.click
                    |> Event.expect Duplicate
        , test "a menu button can be one of the buttons" <|
            \_ ->
                ButtonGroup.view [] "Order actions" [ Button.view [] "Edit", menuButton ]
                    |> Query.fromHtml
                    |> Query.find [ Selector.attribute (Attr.attribute "aria-haspopup" "menu") ]
                    |> Query.has [ Selector.tag "button" ]
        , describe "disabled"
            [ test "is the disabled attribute of the fieldset, which the browser passes on to the buttons" <|
                \_ ->
                    Expect.all
                        [ \_ -> group [ ButtonGroup.disabled True ] |> Query.fromHtml |> Query.has [ Selector.disabled True, Selector.class "klar-btn-group--disabled" ]
                        , \_ -> group [ ButtonGroup.disabled False ] |> Query.fromHtml |> Query.has [ Selector.disabled False ]
                        , \_ -> group [] |> Query.fromHtml |> Query.has [ Selector.disabled False ]
                        , \_ -> group [ ButtonGroup.disabled True, ButtonGroup.disabled False ] |> Query.fromHtml |> Query.has [ Selector.disabled False ]
                        ]
                        ()
            ]
        , describe "size"
            [ test "a small or a large group says so in its class; a medium one does not, so a toolbar still sets the size" <|
                \_ ->
                    Expect.all
                        [ \_ -> group [ ButtonGroup.size Small ] |> Query.fromHtml |> Query.has [ Selector.class "klar-btn-group--sm" ]
                        , \_ -> group [ ButtonGroup.size Large ] |> Query.fromHtml |> Query.has [ Selector.class "klar-btn-group--lg" ]
                        , \_ -> group [ ButtonGroup.size Large, ButtonGroup.size Medium ] |> Query.fromHtml |> Query.hasNot [ Selector.class "klar-btn-group--lg" ]
                        , \_ -> group [] |> Query.fromHtml |> Query.hasNot [ Selector.class "klar-btn-group--sm" ]
                        ]
                        ()
            , test "the buttons keep a size of their own" <|
                \_ ->
                    ButtonGroup.view [ ButtonGroup.size Large ] "Sizes" [ Button.view [ Button.small ] "Small", Button.view [] "Default" ]
                        |> Query.fromHtml
                        |> Query.children []
                        |> Query.first
                        |> Query.has [ Selector.class "klar-button--sm" ]
            ]
        ]


type Msg
    = Edit
    | Duplicate
    | Print
    | MenuMsg Menu.Msg


group : List ButtonGroup.Attribute -> Html Msg
group attributes =
    ButtonGroup.view attributes
        "Order actions"
        [ Button.view [ Button.icon Icon.edit, Button.onClick Edit ] "Edit"
        , Button.view [ Button.onClick Duplicate ] "Duplicate"
        , Button.iconOnly [ Button.onClick Print ] Icon.print "Print"
        ]


menuButton : Html Msg
menuButton =
    Menu.view MenuMsg [ Menu.label "More", Menu.items [ Menu.item "Archive" Edit ] ] (Menu.init "order-more")
