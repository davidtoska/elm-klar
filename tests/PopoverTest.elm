module PopoverTest exposing (suite)

{-| `Klar.Popover`: the names of the button and the panel, `aria-controls` only
while open, the layered `Escape`, `Tab` out of the panel, and the guard that brings
focus back when the element that had it in the panel goes away.
-}

import Expect
import Html exposing (Html)
import Html.Attributes as Attr
import Json.Encode as Encode
import Klar.Icon as Icon
import Klar.Popover as Popover
import Support.Css as Css
import Test exposing (Test, describe, test)
import Test.Html.Event as Event
import Test.Html.Query as Query
import Test.Html.Selector as Selector exposing (Selector)


type Msg
    = PopoverMsg Popover.Msg


closed : Popover.State
closed =
    Popover.init "filter"


opened : Popover.State
opened =
    Popover.open closed |> Tuple.first


draw : List (Popover.Attribute Msg) -> Popover.State -> Html Msg
draw attributes state =
    Popover.view PopoverMsg attributes state "Filter" [ Html.button [ Attr.id "apply" ] [ Html.text "Apply" ] ]


attribute : String -> String -> Selector
attribute name value =
    Selector.attribute (Attr.attribute name value)


{-| What the element sends for this event, given to `update`.
-}
after : List Selector -> ( String, Encode.Value ) -> Popover.State -> Result String ( Popover.State, Cmd Popover.Msg )
after selectors event state =
    draw [] state
        |> Query.fromHtml
        |> Query.find selectors
        |> Event.simulate event
        |> Event.toResult
        |> Result.map (\(PopoverMsg inner) -> Popover.update inner state)


escape : List ( String, Encode.Value ) -> ( String, Encode.Value )
escape extra =
    Event.custom "keydown"
        (Encode.object
            ([ ( "key", Encode.string "Escape" )
             , ( "target", Encode.object [ ( "id", Encode.string "apply" ), ( "parentElement", Encode.object [ ( "id", Encode.string "filter-popup" ) ] ) ] )
             ]
                ++ extra
            )
        )


focusOut : Encode.Value -> ( String, Encode.Value )
focusOut related =
    Event.custom "focusout" (Encode.object [ ( "relatedTarget", related ) ])


suite : Test
suite =
    describe "Klar.Popover"
        [ describe "names"
            [ test "the label is the text of the button" <|
                \_ ->
                    draw [] closed
                        |> Query.fromHtml
                        |> Query.find [ Selector.id "filter-trigger" ]
                        |> Query.has [ Selector.text "Filter" ]
            , test "an icon-only button is named by the label" <|
                \_ ->
                    draw [ Popover.icon Icon.filter, Popover.iconOnly ] closed
                        |> Query.fromHtml
                        |> Query.find [ Selector.id "filter-trigger" ]
                        |> Query.has [ attribute "aria-label" "Filter" ]
            , test "the panel is named by its title" <|
                \_ ->
                    draw [ Popover.title "Quick filter" ] opened
                        |> Query.fromHtml
                        |> Expect.all
                            [ Query.find [ Selector.id "filter-popup" ] >> Query.has [ attribute "aria-labelledby" "filter-title", attribute "role" "dialog" ]
                            , Query.find [ Selector.id "filter-title" ] >> Query.has [ Selector.text "Quick filter" ]
                            ]
            , test "a panel without a title is named by the label" <|
                \_ ->
                    draw [] opened
                        |> Query.fromHtml
                        |> Query.find [ Selector.id "filter-popup" ]
                        |> Query.has [ attribute "aria-label" "Filter" ]
            ]
        , describe "the button"
            [ test "points at the panel while it is open" <|
                \_ ->
                    draw [] opened
                        |> Query.fromHtml
                        |> Expect.all
                            [ Query.find [ Selector.id "filter-trigger" ] >> Query.has [ attribute "aria-controls" "filter-popup", attribute "aria-expanded" "true" ]
                            , Query.has [ Selector.id "filter-popup" ]
                            ]
            , test "points at nothing while it is closed" <|
                \_ ->
                    draw [] closed
                        |> Query.fromHtml
                        |> Expect.all
                            [ Query.find [ Selector.id "filter-trigger" ] >> Query.hasNot [ attribute "aria-controls" "filter-popup" ]
                            , Query.find [ Selector.id "filter-trigger" ] >> Query.has [ attribute "aria-expanded" "false" ]
                            , Query.hasNot [ Selector.id "filter-popup" ]
                            ]
            , test "opens the panel" <|
                \_ ->
                    after [ Selector.id "filter-trigger" ] Event.click closed
                        |> Result.map (Tuple.first >> Popover.isOpen)
                        |> Expect.equal (Ok True)
            ]
        , describe "Escape"
            [ test "closes the panel and gives focus back to the button" <|
                \_ ->
                    after [ Selector.class "klar-layer" ] (escape []) opened
                        |> Result.map (\( state, cmd ) -> ( Popover.isOpen state, cmd == Cmd.none ))
                        |> Expect.equal (Ok ( False, False ))
            , test "that a control in the panel handled leaves it open" <|
                \_ ->
                    after [ Selector.class "klar-layer" ] (escape [ ( "defaultPrevented", Encode.bool True ) ]) opened
                        |> Expect.err
            , test "that ends an IME composition leaves it open" <|
                \_ ->
                    after [ Selector.class "klar-layer" ] (escape [ ( "isComposing", Encode.bool True ) ]) opened
                        |> Expect.err
            , test "in a popup open inside the panel leaves it open" <|
                \_ ->
                    after [ Selector.class "klar-layer" ]
                        (Event.custom "keydown"
                            (Encode.object
                                [ ( "key", Encode.string "Escape" )
                                , ( "target"
                                  , Encode.object
                                        [ ( "className", Encode.string "klar-popup klar-menu__popup" )
                                        , ( "parentElement", Encode.object [ ( "id", Encode.string "filter-popup" ) ] )
                                        ]
                                  )
                                ]
                            )
                        )
                        opened
                        |> Expect.err
            ]
        , describe "Tab out of the panel"
            [ test "to an element outside closes it, without taking focus back" <|
                \_ ->
                    after [ Selector.id "filter-popup" ] (focusOut (Encode.object [ ( "id", Encode.string "next-field" ) ])) opened
                        |> Result.map (\( state, cmd ) -> ( Popover.isOpen state, cmd == Cmd.none ))
                        |> Expect.equal (Ok ( False, True ))
            , test "to an element inside keeps it open" <|
                \_ ->
                    after [ Selector.id "filter-popup" ]
                        (focusOut (Encode.object [ ( "id", Encode.string "apply" ), ( "parentElement", Encode.object [ ( "id", Encode.string "filter-popup" ) ] ) ]))
                        opened
                        |> Expect.err
            , test "to nowhere (the element was removed) keeps it open, for the guard" <|
                \_ ->
                    after [ Selector.id "filter-popup" ] (focusOut Encode.null) opened
                        |> Expect.err
            ]
        , describe "lost focus"
            [ test "the open panel keeps watch, as a direct child of the panel" <|
                \_ ->
                    draw [] opened
                        |> Query.fromHtml
                        |> Query.find [ Selector.id "filter-popup" ]
                        |> Query.children [ Selector.class "klar-modal__guard" ]
                        |> Query.count (Expect.equal 1)
            , test "focus that fell to the page goes back to the panel" <|
                \_ ->
                    after [ Selector.class "klar-modal__guard" ]
                        (Event.custom "animationstart"
                            (Encode.object
                                [ ( "animationName", Encode.string "klar-focus-lost" )
                                , ( "target", Encode.object [ ( "ownerDocument", Encode.object [ ( "activeElement", Encode.object [ ( "tagName", Encode.string "BODY" ) ] ) ] ) ] )
                                ]
                            )
                        )
                        opened
                        |> Result.map (\( state, cmd ) -> ( Popover.isOpen state, cmd == Cmd.none ))
                        |> Expect.equal (Ok ( True, False ))
            , test "focus that something on the page has stays there" <|
                \_ ->
                    after [ Selector.class "klar-modal__guard" ]
                        (Event.custom "animationstart"
                            (Encode.object
                                [ ( "animationName", Encode.string "klar-focus-lost" )
                                , ( "target", Encode.object [ ( "ownerDocument", Encode.object [ ( "activeElement", Encode.object [ ( "tagName", Encode.string "INPUT" ) ] ) ] ) ] )
                                ]
                            )
                        )
                        opened
                        |> Expect.err
            , test "a panel on the page keeps watch only while no dialog is open, so it cannot pull focus out of one" <|
                \_ ->
                    Css.rules
                        |> String.contains ".klar-toasts--recover,.klar-modal-lock)) .klar-popover__popup:not(:has(.klar-popover__popup)) > .klar-modal__guard{animation: klar-focus-lost 1ms 60ms}"
                        |> Expect.equal True
            , test "a panel inside a dialog keeps watch for it" <|
                \_ ->
                    Css.rules
                        |> String.contains ",.klar-modal__dialog .klar-popover__popup:not(:has(.klar-popover__popup))) > .klar-modal__guard"
                        |> Expect.equal True
            ]
        ]
