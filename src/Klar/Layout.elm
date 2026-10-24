module Klar.Layout exposing
    ( stack, row, grid, container
    , Attribute, gap, padding, fill, grow, width, fillRest, maxWidth, maxHeight, scroll
    , alignStart, alignCenter, alignEnd, alignStretch, alignBaseline, justifyCenter, justifyEnd, justifyBetween, wrap
    , columns, minColumn
    , id, ariaLabel
    , spacer, divider, dividerLabelled, dividerVertical
    )

{-| Layout primitives: vertical stacks, horizontal rows and grids, with spacing
from a fixed scale.

Use when: you arrange content in stacks, rows, grids or a page column with spacing from the design scale.
Do not use when: you need a frame for a whole application (as `Klar.AppShell`) or a grouped surface (as `Klar.Card`).

    import Klar.Layout as Layout
    import Klar.Text as Text

    Layout.stack [ Layout.gap 4 ]
        [ Text.title "Orders"
        , Layout.row [ Layout.gap 2, Layout.alignCenter ]
            [ searchField, Layout.spacer, newOrderButton ]
        , Layout.grid [ Layout.minColumn 240 ] (List.map viewOrderCard orders)
        ]

A `stack` puts its children below each other, a `row` next to each other and a
`grid` in columns. A `container` is a centered page column with a maximum width.
They are plain `div` elements that you configure with a list of attributes.
Not every attribute applies to every layout: `wrap` and `alignBaseline` are for
rows, `justifyCenter`, `justifyEnd` and `justifyBetween` for rows and stacks,
`columns` and `minColumn` for grids and `maxWidth` for containers. An attribute
that does not apply is ignored.

Spacing uses the 4px scale of the design tokens in the stylesheet: step `n` is
the custom property `--klar-space-n`, so `gap 2` is 8px, `gap 4` is 16px and
`gap 6` is 24px. Valid steps are 0, 1, 2, 3, 4, 5, 6, 8, 10 and 12. Other
numbers are rounded down to the step below (7 becomes 6, 9 becomes 8, 11 becomes
10), numbers above 12 become 12 and numbers below 1 become 0.


# Layouts

@docs stack, row, grid, container


# Spacing and size

@docs Attribute, gap, padding, fill, grow, width, fillRest, maxWidth, maxHeight, scroll


# Alignment

@docs alignStart, alignCenter, alignEnd, alignStretch, alignBaseline, justifyCenter, justifyEnd, justifyBetween, wrap


# Grid columns

@docs columns, minColumn


# Names

@docs id, ariaLabel


# Separators

@docs spacer, divider, dividerLabelled, dividerVertical

-}

import Html exposing (Html)
import Html.Attributes as Attr
import Klar.Internal as Internal


{-| A setting of a layout. Make them with the functions below and pass a list to
`stack`, `row`, `grid` or `container`; later attributes win over earlier ones.
-}
type Attribute msg
    = Attribute (Config -> Config)


type alias Config =
    { gap : Int
    , align : String
    , justify : String
    , wrap : Bool
    , padding : Int
    , fill : Bool
    , grow : Bool
    , width : Maybe Int
    , fillRest : Bool
    , columns : Maybe Int
    , minColumn : Maybe Int
    , maxWidth : Maybe Int
    , maxHeight : Maybe Int
    , scroll : Bool
    , id : Maybe String
    , ariaLabel : Maybe String
    }


defaults : Config
defaults =
    { gap = 3
    , align = ""
    , justify = ""
    , wrap = False
    , padding = 0
    , fill = False
    , grow = False
    , width = Nothing
    , fillRest = False
    , columns = Nothing
    , minColumn = Nothing
    , maxWidth = Nothing
    , maxHeight = Nothing
    , scroll = False
    , id = Nothing
    , ariaLabel = Nothing
    }


configure : List (Attribute msg) -> Config
configure attributes =
    List.foldl (\(Attribute change) config -> change config) defaults attributes



-- ATTRIBUTES


{-| The space between the children, on the 4px scale: `gap 2` is 8px. The
default is 3 (12px). It applies to `stack`, `row` and `grid`.
-}
gap : Int -> Attribute msg
gap n =
    Attribute (\config -> { config | gap = n })


{-| The space between the edge of the element and its children, on the same
scale as `gap`. The default is 0 (none).
-}
padding : Int -> Attribute msg
padding n =
    Attribute (\config -> { config | padding = n })


{-| Aligns the children at the start of the cross axis: at the top of a row, at
the left edge of a stack. On a `container` it makes a narrow column at the left
edge of its parent (see `container`).
-}
alignStart : Attribute msg
alignStart =
    Attribute (\config -> { config | align = "start" })


{-| Centers the children on the cross axis: vertically in a row, horizontally
in a stack. This is the default of a `row`.
-}
alignCenter : Attribute msg
alignCenter =
    Attribute (\config -> { config | align = "center" })


{-| Aligns the children at the end of the cross axis: at the bottom of a row,
at the right edge of a stack.
-}
alignEnd : Attribute msg
alignEnd =
    Attribute (\config -> { config | align = "end" })


{-| Stretches the children to fill the cross axis: as tall as the row, as wide as
the stack. This is the default of a `stack`.
-}
alignStretch : Attribute msg
alignStretch =
    Attribute (\config -> { config | align = "stretch" })


{-| Lines up the first line of text of every child, which looks right when the
children have different sizes. Rows only.
-}
alignBaseline : Attribute msg
alignBaseline =
    Attribute (\config -> { config | align = "baseline" })


{-| Centers the children along the main axis: horizontally in a row, vertically
in a stack that is taller than its content. Rows and stacks only.
-}
justifyCenter : Attribute msg
justifyCenter =
    Attribute (\config -> { config | justify = "center" })


{-| Packs the children at the end of the main axis: at the right end of a row,
at the bottom of a stack that is taller than its content. Rows and stacks only.
-}
justifyEnd : Attribute msg
justifyEnd =
    Attribute (\config -> { config | justify = "end" })


{-| Spreads the children along the main axis, with the first at the start, the
last at the end and the free space shared between them. Rows and stacks only.
To push just one child away, use `spacer`.
-}
justifyBetween : Attribute msg
justifyBetween =
    Attribute (\config -> { config | justify = "between" })


{-| Lets the children of a row continue on a new line when they do not fit
instead of being squeezed. Rows only.
-}
wrap : Attribute msg
wrap =
    Attribute (\config -> { config | wrap = True })


{-| Makes the element as wide as its parent.
-}
fill : Attribute msg
fill =
    Attribute (\config -> { config | fill = True })


{-| Lets the element take the space that is left over in the `row` or `stack`
it sits in. Give it to the part that should flex, such as the main column next
to a fixed sidebar.

    Layout.row [ Layout.gap 4, Layout.alignStart ]
        [ sidebar
        , Layout.stack [ Layout.grow ] [ content ]
        ]

-}
grow : Attribute msg
grow =
    Attribute (\config -> { config | grow = True })


{-| Gives the element a fixed width in pixels, and lets it keep that width in a `row`
(it does not grow or shrink), so that the part next to it can `grow`: a tree, a filter
panel or a list beside the main area. On a screen narrower than the width it shrinks
to the width of its parent. At least 16 pixels.

    Layout.row [ Layout.gap 4, Layout.alignStart ]
        [ Layout.stack [ Layout.width 240 ] [ locationTree ]
        , Layout.stack [ Layout.grow ] [ table ]
        ]

-}
width : Int -> Attribute msg
width px =
    Attribute (\config -> { config | width = Just (max 16 px) })


{-| Makes a `stack` as tall as the room that is left in its parent, and hands
that height on to its children: the way to give a `Table.fillHeight` a table
that fills the rest of the page. Inside an `AppShell` the parent is the content
area, so the stack is as tall as the window under the top bar; in a flex column
of your own it takes what the other children leave. The stack can still grow
beyond that when its content cannot be squeezed.

    AppShell.view attributes
        [ Layout.stack [ Layout.fillRest ]
            [ PageHeader.view [ PageHeader.title "Inbox" ]
            , Table.view TableMsg [ Table.fillHeight, Table.columns columns, Table.rows model.orders ] model.table
            ]
        ]

It works where the parent is a flex column with a height: the content area of an
`AppShell` (with the stack as its direct child), another `fillRest` stack, or a
`container` that is given `fillRest` itself, which then hands the height on in the
same way:

    Layout.container [ Layout.fillRest ]
        [ Layout.stack [ Layout.fillRest ] [ header, table ] ]

Inside anything else (a plain `div`, a `Card`) the stack is as tall as its content.
For stacks and containers; without it a stack is as tall as its content. Add `scroll`
to make the rest of the height a scroll area of its own.

-}
fillRest : Attribute msg
fillRest =
    Attribute (\config -> { config | fillRest = True })


{-| A `grid` with this many equal columns. There is always at least one column:
0 and negative numbers count as 1. If a grid has both `columns` and `minColumn`,
`columns` wins.
-}
columns : Int -> Attribute msg
columns n =
    Attribute (\config -> { config | columns = Just (max 1 n) })


{-| A responsive `grid`: as many columns as fit, each at least this many pixels
wide, sharing the free space between them. Columns that would be empty collapse
(`auto-fit`), so two children in a wide grid share the whole row. On a screen narrower than one column
there is a single column of full width. A grid with neither `columns` nor
`minColumn` behaves like `minColumn 240`. The smallest width is 16 pixels:
smaller numbers (and 0 and negative numbers) count as 16.
-}
minColumn : Int -> Attribute msg
minColumn px =
    Attribute (\config -> { config | minColumn = Just (max 16 px) })


{-| The maximum width of a `container`, in pixels. The default is 1440. Other
layouts ignore it.
-}
maxWidth : Int -> Attribute msg
maxWidth px =
    Attribute (\config -> { config | maxWidth = Just px })


{-| Limits the height to this many pixels and scrolls the content that does not
fit: a scroll area for lists and panels. It works on every layout. By default
the layout grows with its content.

A scroll area can take the keyboard focus (`tabindex="0"`), so that keyboard
users can scroll it with the arrow keys; give it an `ariaLabel`, so that a screen
reader says what it is when it gets there. Layouts without `maxHeight` or `scroll`
are not focusable.

-}
maxHeight : Int -> Attribute msg
maxHeight px =
    Attribute (\config -> { config | maxHeight = Just px })


{-| Scrolls the content that does not fit in the height the layout gets from its
parent: with `fillRest` or `grow`, a panel beside a table that is as tall as the
window and scrolls on its own. Like `maxHeight` (which scrolls by itself), the area
takes the keyboard focus; give it an `ariaLabel`.

    Layout.row [ Layout.alignStretch, Layout.fillRest ]
        [ Layout.stack [ Layout.width 280, Layout.scroll, Layout.ariaLabel "Customers" ] customerList
        , Layout.stack [ Layout.grow ] [ table ]
        ]

-}
scroll : Attribute msg
scroll =
    Attribute (\config -> { config | scroll = True })


{-| The DOM id of the layout element: the target of `Klar.focus`, of a skip link or
of an `aria-labelledby` of your own.
-}
id : String -> Attribute msg
id value =
    Attribute (\config -> { config | id = Just value })


{-| A name that only a screen reader hears. It makes the layout a named region
(`role="region"`), which a screen reader lists with the landmarks of the page: use it
for a scroll area (`maxHeight`, `scroll`), whose focus would otherwise land on an
element with no name, and for a panel a person should be able to jump to. An empty
text is no name.

    Layout.stack [ Layout.maxHeight 320, Layout.ariaLabel "Recent orders" ] rows

-}
ariaLabel : String -> Attribute msg
ariaLabel value =
    Attribute (\config -> { config | ariaLabel = Internal.nonEmpty value })



-- VIEWS


{-| Lays the children out vertically, one below the other. By default the
children are stretched to the width of the stack; `alignStart`, `alignCenter`
and `alignEnd` let them keep their natural width.

    Layout.stack [ Layout.gap 2 ] [ Text.heading "Shipping", Text.paragraph "Two days." ]

-}
stack : List (Attribute msg) -> List (Html msg) -> Html msg
stack attributes children =
    let
        config =
            configure attributes
    in
    Html.div (commonAttributes "klar-stack" [] config) children


{-| Lays the children out next to each other, centered vertically unless you say
otherwise. Add `wrap` to let them continue on the next line.

    Layout.row [ Layout.gap 2 ] [ Button.view [] "Cancel", Button.view [ Button.primary ] "Save" ]

-}
row : List (Attribute msg) -> List (Html msg) -> Html msg
row attributes children =
    let
        config =
            configure attributes
    in
    Html.div (commonAttributes "klar-row" [] config) children


{-| Lays the children out in a CSS grid. Use `columns n` for a fixed number of
equal columns or `minColumn px` for a responsive grid that adds and removes
columns as the space changes.

    Layout.grid [ Layout.columns 3, Layout.gap 4 ] cards

-}
grid : List (Attribute msg) -> List (Html msg) -> Html msg
grid attributes children =
    let
        config =
            configure attributes

        template =
            case ( config.columns, config.minColumn ) of
                ( Just n, _ ) ->
                    "repeat(" ++ String.fromInt n ++ ", minmax(0, 1fr))"

                -- `min(..., 100%)`: a column never gets wider than the grid,
                -- so a narrow screen gets one full-width column instead of
                -- a column that sticks out and scrolls the page sideways
                ( Nothing, Just px ) ->
                    "repeat(auto-fit, minmax(min(" ++ String.fromInt px ++ "px, 100%), 1fr))"

                ( Nothing, Nothing ) ->
                    "repeat(auto-fit, minmax(min(240px, 100%), 1fr))"
    in
    Html.div
        (commonAttributes "klar-grid" [ ( "--klar-grid-template", template ) ] config)
        children


{-| An empty, flexible element that pushes the elements after it to the far end
of a `row`.

    Layout.row [] [ Text.heading "Orders", Layout.spacer, newOrderButton ]

-}
spacer : Html msg
spacer =
    Html.span [ Internal.cls [ "klar-spacer" ] ] []


{-| A centered page column with a maximum width (`maxWidth`, 1440px by default)
and 24px of padding on both sides.

    Layout.container [] [ pageContent ]

With `alignStart` it sits at the left edge of its parent instead, without side
padding: a narrow column of limited width.

    Layout.container [ Layout.maxWidth 640, Layout.alignStart ] [ form ]

-}
container : List (Attribute msg) -> List (Html msg) -> Html msg
container attributes children =
    let
        config =
            configure attributes
    in
    Html.div (commonAttributes "klar-container" [] config) children


{-| A thin horizontal line (an `hr` element) across the full width.
-}
divider : Html msg
divider =
    Html.hr [ Internal.cls [ "klar-divider" ] ] []


{-| A thin horizontal line with a label in the middle, such as "or" between two
groups of options.

    Layout.dividerLabelled "or"

-}
dividerLabelled : String -> Html msg
dividerLabelled label =
    Html.div [ Internal.cls [ "klar-divider", "klar-divider--labelled" ] ]
        [ Html.span [ Internal.cls [ "klar-divider__label" ] ] [ Html.text label ] ]


{-| A thin vertical line between groups in a `row`, such as the groups of buttons
of a toolbar or a filter row. It is as tall as the row, and a screen reader hears it
as a separator.

    Layout.row [ Layout.gap 2 ] [ boldButton, italicButton, Layout.dividerVertical, undoButton ]

-}
dividerVertical : Html msg
dividerVertical =
    Html.span
        [ Internal.cls [ "klar-divider-v" ]
        , Attr.attribute "role" "separator"
        , Attr.attribute "aria-orientation" "vertical"
        ]
        []



-- INTERNAL


commonAttributes : String -> List ( String, String ) -> Config -> List (Html.Attribute msg)
commonAttributes block extra config =
    let
        scrolls =
            config.scroll || config.maxHeight /= Nothing

        declarations =
            extra
                ++ List.filterMap identity
                    [ Just ( "--klar-gap", spaceVar config.gap )
                    , if config.padding > 0 then
                        Just ( "--klar-pad", spaceVar config.padding )

                      else
                        Nothing
                    , config.maxWidth |> Maybe.map (\w -> ( "--klar-max-w", String.fromInt w ++ "px" ))
                    , case config.maxHeight of
                        Just h ->
                            Just ( "--klar-max-h", String.fromInt h ++ "px" )

                        -- set, so that a scroll area never inherits the limit of one around it
                        Nothing ->
                            if config.scroll then
                                Just ( "--klar-max-h", "none" )

                            else
                                Nothing
                    , config.width |> Maybe.map (\w -> ( "--klar-fixed-w", String.fromInt w ++ "px" ))
                    ]
    in
    [ Internal.cls
        [ block
        , if config.align /= "" then
            block ++ "--align-" ++ config.align

          else
            ""
        , if config.justify /= "" then
            block ++ "--justify-" ++ config.justify

          else
            ""
        , if config.wrap then
            block ++ "--wrap"

          else
            ""
        , if config.fill then
            "klar-fill"

          else
            ""
        , if config.grow then
            "klar-grow"

          else
            ""
        , if config.width /= Nothing then
            "klar-fixed-w"

          else
            ""
        , if config.fillRest then
            "klar-fill-rest"

          else
            ""
        , if config.padding > 0 then
            "klar-padded"

          else
            ""
        , if scrolls then
            "klar-scroll"

          else
            ""
        ]
    , Internal.styleVars declarations

    -- A scroll area must be reachable with the keyboard, or its content cannot
    -- be read without a mouse.
    , Internal.attrIf scrolls (Attr.tabindex 0)
    , Internal.attrMaybe Attr.id config.id
    , Internal.attrIf (config.ariaLabel /= Nothing) (Attr.attribute "role" "region")
    , Internal.attrMaybe (Attr.attribute "aria-label") config.ariaLabel
    ]


spaceVar : Int -> String
spaceVar n =
    if n <= 0 then
        "0px"

    else
        "var(--klar-space-" ++ String.fromInt (clampStep n) ++ ")"


clampStep : Int -> Int
clampStep n =
    if n == 7 then
        6

    else if n == 9 then
        8

    else if n == 11 then
        10

    else
        min 12 n
