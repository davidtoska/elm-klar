module Page.Gallery.Review.Diffs exposing (Model, Msg, init, update, view)

{-| The diff section of the review page: a shipping policy in two layouts, a CSV of
stock levels, an order as JSON compared by position and by key, the fields of an
order as audit log entries, two versions that are equal, a diff with many changes,
one that is too large to compare and one huge block of new lines.
-}

import Html exposing (Html)
import Klar.Button as Button
import Klar.Card as Card
import Klar.Diff as Diff
import Klar.Layout as Layout
import Klar.Locale exposing (Locale)
import Klar.Switch as Switch
import Klar.Text as Text
import Page.Gallery.Review.Samples as Samples exposing (AuditEntry)
import Showcase.Config as Config
import Showcase.Doc as Doc
import Showcase.Options as Options



-- MODEL


type alias Model =
    { policy : Diff.State
    , ignoreSpace : Bool
    , wrap : Bool
    , policyDiff : Diff.Diff
    , stock : Diff.State
    , stockDiff : Diff.Diff
    , order : Diff.State
    , byKey : Bool
    , orderDiff : Diff.Diff
    , audit : Diff.State
    , showUnchanged : Bool
    , same : Diff.State
    , many : Diff.State
    , manyDiff : Maybe Diff.Diff
    , big : Diff.State
    , bigDiff : Maybe Diff.Diff
    , block : Diff.State
    , blockDiff : Maybe Diff.Diff
    }


type Msg
    = PolicyMsg Diff.Msg
    | GoToPolicyChange String
    | IgnoreSpace Bool
    | Wrap Bool
    | StockMsg Diff.Msg
    | OrderMsg Diff.Msg
    | ByKey Bool
    | AuditMsg Diff.Msg
    | ShowUnchanged Bool
    | SameMsg Diff.Msg
    | ManyMsg Diff.Msg
    | CompareMany
    | BigMsg Diff.Msg
    | CompareBig
    | BlockMsg Diff.Msg
    | CompareBlock


init : Model
init =
    { policy = Diff.init "review-policy"
    , ignoreSpace = False
    , wrap = True
    , policyDiff = policyDiff False
    , stock = Diff.init "review-stock"
    , stockDiff = Diff.lines [] Samples.stockBefore Samples.stockAfter
    , order = Diff.init "review-order"
    , byKey = False
    , orderDiff = orderDiff False
    , audit = Diff.init "review-audit"
    , showUnchanged = False
    , same = Diff.init "review-same"
    , many = Diff.init "review-many"
    , manyDiff = Nothing
    , big = Diff.init "review-big"
    , bigDiff = Nothing
    , block = Diff.init "review-block"
    , blockDiff = Nothing
    }


policyDiff : Bool -> Diff.Diff
policyDiff ignoreSpace =
    Diff.lines
        (if ignoreSpace then
            [ Diff.ignoreWhitespace ]

         else
            []
        )
        Samples.policyBefore
        Samples.policyAfter


orderDiff : Bool -> Diff.Diff
orderDiff byKey =
    Diff.json
        (if byKey then
            [ Diff.matchBy "sku" ]

         else
            []
        )
        Samples.orderBefore
        Samples.orderAfter


{-| The fields of each audit log entry, made once.
-}
auditDiffs : List ( AuditEntry, Diff.Diff )
auditDiffs =
    List.map (\entry -> ( entry, Diff.fields entry.fields )) Samples.auditEntries


{-| Two texts that differ only in white space, compared with that option.
-}
sameDiff : Diff.Diff
sameDiff =
    Diff.lines [ Diff.ignoreWhitespace ] "Total:  42\n" "Total: 42\n"



-- UPDATE


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        PolicyMsg inner ->
            let
                ( state, cmd ) =
                    Diff.update inner model.policy
            in
            ( { model | policy = state }, Cmd.map PolicyMsg cmd )

        GoToPolicyChange key ->
            let
                ( state, cmd ) =
                    Diff.goToHunk model.policyDiff key model.policy
            in
            ( { model | policy = state }, Cmd.map PolicyMsg cmd )

        IgnoreSpace value ->
            ( { model | ignoreSpace = value, policyDiff = policyDiff value }, Cmd.none )

        Wrap value ->
            ( { model | wrap = value }, Cmd.none )

        StockMsg inner ->
            let
                ( state, cmd ) =
                    Diff.update inner model.stock
            in
            ( { model | stock = state }, Cmd.map StockMsg cmd )

        OrderMsg inner ->
            let
                ( state, cmd ) =
                    Diff.update inner model.order
            in
            ( { model | order = state }, Cmd.map OrderMsg cmd )

        ByKey value ->
            ( { model | byKey = value, orderDiff = orderDiff value }, Cmd.none )

        AuditMsg inner ->
            let
                ( state, cmd ) =
                    Diff.update inner model.audit
            in
            ( { model | audit = state }, Cmd.map AuditMsg cmd )

        ShowUnchanged value ->
            ( { model | showUnchanged = value }, Cmd.none )

        SameMsg inner ->
            let
                ( state, cmd ) =
                    Diff.update inner model.same
            in
            ( { model | same = state }, Cmd.map SameMsg cmd )

        ManyMsg inner ->
            let
                ( state, cmd ) =
                    Diff.update inner model.many
            in
            ( { model | many = state }, Cmd.map ManyMsg cmd )

        CompareMany ->
            ( { model | manyDiff = Just (Diff.lines [] Samples.manyBefore Samples.manyAfter) }, Cmd.none )

        BigMsg inner ->
            let
                ( state, cmd ) =
                    Diff.update inner model.big
            in
            ( { model | big = state }, Cmd.map BigMsg cmd )

        CompareBig ->
            ( { model | bigDiff = Just (Diff.lines [] Samples.bigBefore Samples.bigAfter) }, Cmd.none )

        BlockMsg inner ->
            let
                ( state, cmd ) =
                    Diff.update inner model.block
            in
            ( { model | block = state }, Cmd.map BlockMsg cmd )

        CompareBlock ->
            ( { model | blockDiff = Just (Diff.lines [] "" (blockOfLines 20000)) }, Cmd.none )



-- VIEW


view : Config.Config -> Locale -> Model -> Html Msg
view playground locale model =
    Doc.configuredSection playground
        []
        "Diff"
        "What changed between two versions, so that a person can see it and decide. A text is compared line by line with the shortest set of changes, and the words that changed are marked inside a changed line. The viewer folds the unchanged lines, says \"Showing 200 of 400 changes\" when it draws only the first changes, and says that a diff is too large instead of freezing. Changes are marked with a sign and with hidden text as well as with color. The box that scrolls is a tab stop; \"Next change\" and \"Previous change\" move the focus to a change, and the keys n and p do the same while the focus is in the box."
        [ policyExample playground locale model
        , stockExample playground locale model
        , orderExample playground locale model
        , auditExample playground locale model
        , sameExample playground locale model
        , manyExample playground locale model
        , bigExample playground locale model
        , blockExample playground locale model
        ]


policyExample : Config.Config -> Locale -> Model -> Html Msg
policyExample playground locale model =
    Doc.configuredExample playground
        [ "Switch", "Diff" ]
        { title = "Two versions of a shipping policy"
        , description = Just "Unified and side by side (the buttons in the toolbar). Long lines wrap, the unchanged lines are folded into a row that opens when it is pressed, and the changed words are marked inside a changed line (a changed number digit by digit). \"Ignore white space\" leaves out the two edits that only touch spaces, and the viewer says so; side by side, the old column still shows the old text. The buttons under the viewer go to a change by its key (Diff.goToHunk), and the pressed one is the change the user is on (Diff.currentHunk), which is where a panel to accept or reject that change would go."
        , code = Just """-- when the texts are known (in update):
{ model | policyDiff = Diff.lines [ Diff.ignoreWhitespace ] oldText newText }

-- in view:
Diff.view PolicyMsg
    [ Diff.ariaLabel "Changes to the shipping policy"
    , Diff.wrapLines
    , Diff.locale locale
    ]
    model.policy
    model.policyDiff

-- in update:
PolicyMsg inner ->
    let
        ( state, cmd ) =
            Diff.update inner model.policy
    in
    ( { model | policy = state }, Cmd.map PolicyMsg cmd )"""
        }
        (Layout.stack (Options.klarLayout playground (List.concat [ Config.keep playground "Layout" "gap" (Layout.gap 3) ]))
            [ Layout.row (Options.klarLayout playground (List.concat [ Config.keep playground "Layout" "gap" (Layout.gap 4), Config.keep playground "Layout" "wrap" Layout.wrap, Config.keep playground "Layout" "alignCenter" Layout.alignCenter ]))
                [ Switch.view (Options.klarSwitch playground (List.concat [ Config.keep playground "Switch" "label" (Switch.label "Ignore white space"), Config.keep playground "Switch" "checked" (Switch.checked model.ignoreSpace), Config.keep playground "Switch" "onCheck" (Switch.onCheck IgnoreSpace) ]))
                , Switch.view (Options.klarSwitch playground (List.concat [ Config.keep playground "Switch" "label" (Switch.label "Wrap long lines"), Config.keep playground "Switch" "checked" (Switch.checked model.wrap), Config.keep playground "Switch" "onCheck" (Switch.onCheck Wrap) ]))
                ]
            , Diff.view PolicyMsg
                (List.concat
                    [ Options.klarDiff playground (List.concat [ Config.keep playground "Diff" "ariaLabel" (Diff.ariaLabel "Changes to the shipping policy"), Config.keep playground "Diff" "locale" (Diff.locale locale) ])
                    , if model.wrap then
                        Options.klarDiff playground (List.concat [ Config.keep playground "Diff" "wrapLines" Diff.wrapLines ])

                      else
                        []
                    ]
                )
                model.policy
                model.policyDiff
            , Layout.row (Options.klarLayout playground (List.concat [ Config.keep playground "Layout" "gap" (Layout.gap 2), Config.keep playground "Layout" "wrap" Layout.wrap, Config.keep playground "Layout" "alignCenter" Layout.alignCenter ]))
                (Text.caption "Go to:"
                    :: List.indexedMap
                        (\index hunk ->
                            Options.buttonView playground
                                (Options.klarButton playground
                                    (List.concat
                                        [ Config.keep playground "Button" "small" Button.small
                                        , Config.keep playground "Button" "pressed" (Button.pressed (Maybe.map Diff.hunkKey (Diff.currentHunk model.policyDiff model.policy) == Just (Diff.hunkKey hunk)))
                                        , Config.keep playground "Button" "onClick" (Button.onClick (GoToPolicyChange (Diff.hunkKey hunk)))
                                        ]
                                    )
                                )
                                ("Change " ++ String.fromInt (index + 1))
                        )
                        (Diff.hunks model.policyDiff)
                )
            ]
        )


stockExample : Config.Config -> Locale -> Model -> Html Msg
stockExample playground locale model =
    Doc.configuredExample playground
        [ "Diff" ]
        { title = "Stock levels as CSV"
        , description = Just "Lines that keep their length, as in code and data files, scroll sideways inside the box and not the page. One line of context around each change. A changed number is marked digit by digit, and the viewer remembers which folds were opened when the data is compared again."
        , code = Just """Diff.view StockMsg
    [ Diff.ariaLabel "Changes to the stock levels"
    , Diff.context 1
    , Diff.maxHeight 360
    ]
    model.stock
    (Diff.lines [] oldCsv newCsv)"""
        }
        (Diff.view StockMsg
            (Options.klarDiff playground (List.concat [ Config.keep playground "Diff" "ariaLabel" (Diff.ariaLabel "Changes to the stock levels"), Config.keep playground "Diff" "context" (Diff.context 1), Config.keep playground "Diff" "maxHeight" (Diff.maxHeight 360), Config.keep playground "Diff" "locale" (Diff.locale locale) ]))
            model.stock
            model.stockDiff
        )


orderExample : Config.Config -> Locale -> Model -> Html Msg
orderExample playground locale model =
    Doc.configuredExample playground
        [ "Switch", "Diff" ]
        { title = "An order as JSON"
        , description = Just "Every change by path, in a fixed order (the keys of an object alphabetically). Numbers are compared exactly: 0.30000000000000004 is not 0.3. Arrays are compared by position, which makes a reordered list of lines a mess; with \"Match order lines by sku\" the records are paired by their sku, and moving a line is no change. An added or removed object is one change, and a changed text shows what changed inside it."
        , code = Just """Diff.json [ Diff.matchBy "sku" ] oldOrder newOrder

Diff.view OrderMsg [ Diff.ariaLabel "Changes to the order" ] model.order model.orderDiff"""
        }
        (Layout.stack (Options.klarLayout playground (List.concat [ Config.keep playground "Layout" "gap" (Layout.gap 3) ]))
            [ Switch.view (Options.klarSwitch playground (List.concat [ Config.keep playground "Switch" "label" (Switch.label "Match order lines by sku"), Config.keep playground "Switch" "checked" (Switch.checked model.byKey), Config.keep playground "Switch" "onCheck" (Switch.onCheck ByKey) ]))
            , Diff.view OrderMsg
                (Options.klarDiff playground (List.concat [ Config.keep playground "Diff" "ariaLabel" (Diff.ariaLabel "Changes to the order"), Config.keep playground "Diff" "locale" (Diff.locale locale) ]))
                model.order
                model.orderDiff
            ]
        )


auditExample : Config.Config -> Locale -> Model -> Html Msg
auditExample playground locale model =
    Doc.configuredExample playground
        [ "Card", "Switch", "Diff" ]
        { title = "Fields of an order, as an audit log"
        , description = Just "The text of each side is yours, so dates and amounts are written the way users read them. A field that did not change is left out (and can be shown, muted). A log with many entries uses the view without state, which has no toolbar and no id. The last card uses the view with state, to step through the fields with the keyboard."
        , code = Just """Diff.fields
    [ { label = "Status", before = Just "Open", after = Just "Shipped" }
    , { label = "Carrier", before = Nothing, after = Just "Nordic Freight" }
    , { label = "Customer", before = Just "Northwind Traders", after = Just "Northwind Traders" }
    ]

-- one entry in a list of many:
Diff.viewStatic [ Diff.ariaLabel "Changes by Ada Lovelace, 12 Oct 2026" ] entryDiff"""
        }
        (Layout.stack (Options.klarLayout playground (List.concat [ Config.keep playground "Layout" "gap" (Layout.gap 3) ]))
            (List.map (auditCard playground locale) auditDiffs
                ++ [ Card.view (Options.klarCard playground (List.concat [ Config.keep playground "Card" "title" (Card.title "With the toolbar"), Config.keep playground "Card" "headingLevel" (Card.headingLevel 4) ]))
                        [ Layout.stack (Options.klarLayout playground (List.concat [ Config.keep playground "Layout" "gap" (Layout.gap 3) ]))
                            [ Switch.view (Options.klarSwitch playground (List.concat [ Config.keep playground "Switch" "label" (Switch.label "Show the fields that did not change"), Config.keep playground "Switch" "checked" (Switch.checked model.showUnchanged), Config.keep playground "Switch" "onCheck" (Switch.onCheck ShowUnchanged) ]))
                            , Diff.view AuditMsg
                                (List.concat
                                    [ Options.klarDiff playground (List.concat [ Config.keep playground "Diff" "ariaLabel" (Diff.ariaLabel "Changes to the order"), Config.keep playground "Diff" "locale" (Diff.locale locale) ])
                                    , if model.showUnchanged then
                                        Options.klarDiff playground (List.concat [ Config.keep playground "Diff" "showUnchangedFields" Diff.showUnchangedFields ])

                                      else
                                        []
                                    ]
                                )
                                model.audit
                                (Tuple.second (firstAudit auditDiffs))
                            ]
                        ]
                   ]
            )
        )


firstAudit : List ( AuditEntry, Diff.Diff ) -> ( AuditEntry, Diff.Diff )
firstAudit entries =
    case entries of
        first :: _ ->
            first

        [] ->
            ( { who = "", when = "", fields = [] }, Diff.fields [] )


auditCard : Config.Config -> Locale -> ( AuditEntry, Diff.Diff ) -> Html Msg
auditCard playground locale ( entry, diff ) =
    Card.view (Options.klarCard playground (List.concat [ Config.keep playground "Card" "title" (Card.title entry.who), Config.keep playground "Card" "subtitle" (Card.subtitle entry.when), Config.keep playground "Card" "headingLevel" (Card.headingLevel 4) ]))
        [ Diff.viewStatic
            (Options.klarDiff playground (List.concat [ Config.keep playground "Diff" "ariaLabel" (Diff.ariaLabel ("Changes by " ++ entry.who ++ ", " ++ entry.when)), Config.keep playground "Diff" "locale" (Diff.locale locale) ]))
            diff
        ]


sameExample : Config.Config -> Locale -> Model -> Html Msg
sameExample playground locale model =
    Doc.configuredExample playground
        [ "Diff" ]
        { title = "No changes"
        , description = Just "Two equal versions say so, instead of showing an empty box. When an option was used the viewer says that too, as here: the two texts differ only in white space."
        , code = Just """Diff.lines [ Diff.ignoreWhitespace ] "Total:  42" "Total: 42"
    |> Diff.isEmpty -- True"""
        }
        (Diff.view SameMsg
            (Options.klarDiff playground (List.concat [ Config.keep playground "Diff" "ariaLabel" (Diff.ariaLabel "Changes to the total"), Config.keep playground "Diff" "locale" (Diff.locale locale) ]))
            model.same
            sameDiff
        )


manyExample : Config.Config -> Locale -> Model -> Html Msg
manyExample playground locale model =
    Doc.configuredExample playground
        [ "Diff" ]
        { title = "A diff with many changes"
        , description = Just "400 changes in 1 200 lines. The first 200 are drawn, and the footer says so and shows more on request. \"Next change\" goes on to the 201st change by itself."
        , code = Just """Diff.view ManyMsg [ Diff.maxChanges 200 ] model.many model.manyDiff"""
        }
        (case model.manyDiff of
            Nothing ->
                Layout.row (Options.klarLayout playground (List.concat [ Config.keep playground "Layout" "gap" (Layout.gap 3), Config.keep playground "Layout" "alignCenter" Layout.alignCenter ]))
                    [ Options.buttonView playground (Options.klarButton playground (List.concat [ Config.keep playground "Button" "onClick" (Button.onClick CompareMany) ])) "Compare two texts of 1 200 lines"
                    , Text.caption "About a tenth of a second."
                    ]

            Just diff ->
                Diff.view ManyMsg
                    (Options.klarDiff playground (List.concat [ Config.keep playground "Diff" "ariaLabel" (Diff.ariaLabel "Changes to the pick list"), Config.keep playground "Diff" "maxHeight" (Diff.maxHeight 420), Config.keep playground "Diff" "locale" (Diff.locale locale) ]))
                    model.many
                    diff
        )


bigExample : Config.Config -> Locale -> Model -> Html Msg
bigExample playground locale model =
    Doc.configuredExample playground
        [ "Diff" ]
        { title = "Too large to compare"
        , description = Just "Two exports of 3 000 lines with nothing in common. The shortest set of changes would take far longer than the viewer allows (about a third of a second), so the diff degrades to a summary, and says so. Diff.tooLarge tells the application, which can offer the two files for download."
        , code = Just """case Diff.tooLarge diff of
    True ->
        -- offer the two texts for download
        ...

    False ->
        Diff.view DiffMsg [] model.state diff"""
        }
        (case model.bigDiff of
            Nothing ->
                Layout.row (Options.klarLayout playground (List.concat [ Config.keep playground "Layout" "gap" (Layout.gap 3), Config.keep playground "Layout" "alignCenter" Layout.alignCenter ]))
                    [ Options.buttonView playground (Options.klarButton playground (List.concat [ Config.keep playground "Button" "onClick" (Button.onClick CompareBig) ])) "Compare two exports of 3 000 lines"
                    , Text.caption "Takes about a third of a second."
                    ]

            Just diff ->
                Diff.view BigMsg
                    (Options.klarDiff playground (List.concat [ Config.keep playground "Diff" "ariaLabel" (Diff.ariaLabel "Changes between the exports"), Config.keep playground "Diff" "locale" (Diff.locale locale) ]))
                    model.big
                    diff
        )


{-| A log of that many lines, all of them new.
-}
blockOfLines : Int -> String
blockOfLines count =
    List.range 1 count
        |> List.map (\i -> "2026-03-04 09:" ++ String.padLeft 2 '0' (String.fromInt (modBy 60 i)) ++ " order " ++ String.fromInt (1000 + i) ++ " picked")
        |> String.join "\n"


blockExample : Config.Config -> Locale -> Model -> Html Msg
blockExample playground locale model =
    Doc.configuredExample playground
        [ "Diff" ]
        { title = "One huge block"
        , description = Just "A log of 20 000 lines that did not exist before is one change. The viewer draws the first 500 lines, says \"Showing 500 of 20,000 changed lines\" and offers 500 more; the focus goes to the first new line. A static view cuts the block the same way and has no button."
        , code = Just """Diff.lines [] "" newLog
    |> Diff.view BlockMsg [ Diff.maxHeight 420 ] model.block"""
        }
        (case model.blockDiff of
            Nothing ->
                Layout.row (Options.klarLayout playground (List.concat [ Config.keep playground "Layout" "gap" (Layout.gap 3), Config.keep playground "Layout" "alignCenter" Layout.alignCenter ]))
                    [ Options.buttonView playground (Options.klarButton playground (List.concat [ Config.keep playground "Button" "onClick" (Button.onClick CompareBlock) ])) "Compare with a new log of 20 000 lines"
                    , Text.caption "Draws 500 lines, not 20 000."
                    ]

            Just diff ->
                Diff.view BlockMsg
                    (Options.klarDiff playground (List.concat [ Config.keep playground "Diff" "ariaLabel" (Diff.ariaLabel "The new log"), Config.keep playground "Diff" "maxHeight" (Diff.maxHeight 420), Config.keep playground "Diff" "locale" (Diff.locale locale) ]))
                    model.block
                    diff
        )
