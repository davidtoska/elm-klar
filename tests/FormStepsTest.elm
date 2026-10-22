module FormStepsTest exposing (suite)

{-| Tests of the steps and the repeating rows of `Klar.Form.Model`: the keys of
the rows, add and remove through the real buttons, one dirty flag over every
step and row, the checks across rows, the step control (`advance`, `goTo`, the
stepper) and the problems that lead to the right step.
-}

import Expect
import Html exposing (Html)
import Klar.Form.Model as Fm
import Klar.Ids as Ids exposing (Ids)
import Klar.Locale as Locale
import Klar.Validate as Validate
import Test exposing (Test, describe, test)
import Test.Html.Event as Event
import Test.Html.Query as Query
import Test.Html.Selector as Selector


type Step
    = Company
    | Contacts
    | Delivery
    | Review


type Role
    = Sales
    | Finance


roleIds : Ids Role
roleIds =
    Ids.make
        { toKey =
            \role ->
                case role of
                    Sales ->
                        "sales"

                    Finance ->
                        "finance"
        , fromKey =
            \key ->
                case key of
                    "sales" ->
                        Just Sales

                    "finance" ->
                        Just Finance

                    _ ->
                        Nothing
        }


type alias ContactFields =
    { name : Fm.Field String
    , email : Fm.Field String
    , role : Fm.Field (Maybe Role)
    , primary : Fm.Field Bool
    }


type alias Contact =
    { name : String
    , email : String
    , role : Role
    , primary : Bool
    }


contactForm : Fm.Form () ContactFields Contact
contactForm =
    Fm.define "contact" ContactFields Contact
        |> Fm.with (Fm.text "Name" |> Fm.required)
        |> Fm.with (Fm.text "Email" |> Fm.required |> Fm.rules [ Validate.email ])
        |> Fm.with (Fm.choice roleIds "Role" |> Fm.required)
        |> Fm.with (Fm.toggle "Primary")
        |> Fm.build


type alias Fields =
    { name : Fm.Field String
    , contacts : Fm.Field (Fm.Rows ContactFields)
    , leadTime : Fm.Field (Maybe Float)
    , notes : Fm.Field String
    }


type alias Values =
    { name : String
    , contacts : List Contact
    , leadTime : Float
    , notes : Maybe String
    }


form : Fm.Form Step Fields Values
form =
    Fm.define "s" Fields Values
        |> Fm.step Company "Company"
        |> Fm.with (Fm.text "Name" |> Fm.required)
        |> Fm.step Contacts "Contacts"
        |> Fm.with (Fm.rows { label = "Contacts", item = "Contact" } contactForm |> Fm.atLeast 1)
        |> Fm.step Delivery "Delivery"
        |> Fm.with (Fm.number "Lead time" |> Fm.required |> Fm.whole)
        |> Fm.with (Fm.text "Notes")
        |> Fm.step Review "Review"
        |> Fm.check
            (\h state _ ->
                Fm.rowFields h.contacts state
                    |> List.filter (\row -> Fm.get row.primary state)
                    |> List.drop 1
                    |> List.map (\row -> Fm.problem row.primary "Only one contact can be the primary.")
            )
        |> Fm.build


f : Fields
f =
    Fm.fields form


fresh : Fm.State Step
fresh =
    Fm.init form


alice : Contact
alice =
    { name = "Alice", email = "alice@acme.example", role = Sales, primary = True }


bob : Contact
bob =
    { name = "Bob", email = "bob@acme.example", role = Finance, primary = False }


fillContact : Contact -> ContactFields -> Fm.State Step -> Fm.State Step
fillContact c row =
    Fm.set row.name c.name
        >> Fm.set row.email c.email
        >> Fm.set row.role (Just c.role)
        >> Fm.set row.primary c.primary


sample : Values
sample =
    { name = "Acme", contacts = [ alice, bob ], leadTime = 7, notes = Just "Call first" }


fill : Values -> Fm.State Step -> Fm.State Step
fill v =
    Fm.set f.name v.name
        >> Fm.fillRows f.contacts fillContact v.contacts
        >> Fm.set f.leadTime (Just v.leadTime)
        >> Fm.set f.notes (Maybe.withDefault "" v.notes)


filled : Fm.State Step
filled =
    fresh |> fill sample |> Fm.markClean


bound : Fm.State Step -> Fm.View Fm.Msg
bound state =
    Fm.bind Locale.en identity form state


{-| Sends a click to the n-th button of what is drawn and runs the update on
the message that comes back.
-}
click : Int -> Html Fm.Msg -> Fm.State Step -> Fm.State Step
click index html state =
    html
        |> Query.fromHtml
        |> Query.findAll [ Selector.tag "button" ]
        |> Query.index index
        |> Event.simulate Event.click
        |> Event.toResult
        |> Result.map (\msg -> Fm.update form msg state |> Tuple.first)
        |> Result.withDefault state


addContact : Fm.State Step -> Fm.State Step
addContact state =
    click 0 (Fm.addRow (bound state) f.contacts [] "Add contact") state


removeContact : Int -> Fm.State Step -> Fm.State Step
removeContact position state =
    Fm.removeRow (bound state) f.contacts position []
        |> Query.fromHtml
        |> Event.simulate Event.click
        |> Event.toResult
        |> Result.map (\msg -> Fm.update form msg state |> Tuple.first)
        |> Result.withDefault state


contactKeys : Fm.State Step -> List String
contactKeys state =
    Fm.rowFields f.contacts state |> List.map (\row -> (Fm.problem row.name "").field)


problemsOf : Fm.State Step -> List ( String, String )
problemsOf state =
    Fm.problems Locale.en form state |> List.map (\p -> ( p.label, p.message ))


stepOf : Fm.State Step -> Maybe Step
stepOf =
    Fm.currentStep form


showsText : String -> Html Fm.Msg -> Expect.Expectation
showsText wanted html =
    html |> Query.fromHtml |> Query.has [ Selector.text wanted ]


hidesText : String -> Html Fm.Msg -> Expect.Expectation
hidesText unwanted html =
    html |> Query.fromHtml |> Query.hasNot [ Selector.text unwanted ]


{-| What `advance` does, as the state and whether a record came out.
-}
advanced : Fm.State Step -> ( Fm.State Step, Maybe Values )
advanced state =
    let
        next =
            Fm.advance form state
    in
    ( next.state, next.submit )


suite : Test
suite =
    describe "Klar.Form.Model: steps and rows"
        [ rowKeys
        , rowValues
        , rowDirty
        , crossRow
        , stepControl
        , stepProblems
        , outsideProblems
        ]


rowKeys : Test
rowKeys =
    describe "the keys of the rows"
        [ test "a group that needs one row starts with one empty row" <|
            \_ -> contactKeys fresh |> Expect.equal [ "s-contacts-1-name" ]
        , test "an added row gets the next number" <|
            \_ ->
                addContact fresh
                    |> contactKeys
                    |> Expect.equal [ "s-contacts-1-name", "s-contacts-2-name" ]
        , test "a removed row takes its number with it: the others keep theirs" <|
            \_ ->
                fresh
                    |> addContact
                    |> addContact
                    |> removeContact 0
                    |> contactKeys
                    |> Expect.equal [ "s-contacts-2-name", "s-contacts-3-name" ]
        , test "a number is never used twice" <|
            \_ ->
                fresh
                    |> addContact
                    |> removeContact 1
                    |> addContact
                    |> contactKeys
                    |> Expect.equal [ "s-contacts-1-name", "s-contacts-3-name" ]
        , test "the values of a row stay with the row when an earlier one is removed" <|
            \_ ->
                let
                    state =
                        filled |> removeContact 0
                in
                Fm.rowFields f.contacts state
                    |> List.map (\row -> Fm.get row.name state)
                    |> Expect.equal [ "Bob" ]
        , test "the handles are the rows' own, at the keys the DOM uses" <|
            \_ ->
                Fm.textInput (bound fresh) (List.head (Fm.rowFields f.contacts fresh) |> Maybe.map .name |> Maybe.withDefault f.name) []
                    |> Query.fromHtml
                    |> Query.has [ Selector.id "s-contacts-1-name" ]
        ]


rowValues : Test
rowValues =
    describe "the values and problems of rows"
        [ test "the rows come out as a list, in order" <|
            \_ -> Fm.toValues Locale.en form filled |> Expect.equal (Ok sample)
        , test "the round trip of a record with rows" <|
            \_ -> Fm.roundTrip form fill sample |> Expect.equal (Ok sample)
        , test "a problem in a row says which row, by position" <|
            \_ ->
                filled
                    |> removeContact 0
                    |> addContact
                    |> problemsOf
                    |> Expect.equal
                        [ ( "Contact 2, Name", "Required" )
                        , ( "Contact 2, Email", "Required" )
                        , ( "Contact 2, Role", "Required" )
                        ]
        , test "removing a row takes its problems with it" <|
            \_ ->
                filled
                    |> addContact
                    |> removeContact 2
                    |> problemsOf
                    |> Expect.equal []
        , test "a group that needs rows complains when none is left" <|
            \_ ->
                fresh
                    |> removeContact 0
                    |> problemsOf
                    |> List.filter (\( label, _ ) -> label == "Contacts")
                    |> Expect.equal [ ( "Contacts", "Add at least 1" ) ]
        , test "fillRows replaces the rows that were there" <|
            \_ ->
                fresh
                    |> Fm.fillRows f.contacts fillContact [ bob ]
                    |> Fm.rowFields f.contacts
                    |> List.length
                    |> Expect.equal 1
        , test "the add button shows the group's problem once it is revealed" <|
            \_ ->
                let
                    none =
                        fresh |> removeContact 0 |> Fm.reveal form |> Tuple.first
                in
                Fm.addRow (bound none) f.contacts [] "Add contact" |> showsText "Add at least 1"
        , test "a row added after the problems were revealed starts quiet" <|
            \_ ->
                let
                    state =
                        fresh |> Fm.reveal form |> Tuple.first |> addContact

                    second =
                        Fm.rowFields f.contacts state |> List.drop 1 |> List.head
                in
                case second of
                    Just row ->
                        Fm.textInput (bound state) row.name [] |> hidesText "Required"

                    Nothing ->
                        Expect.fail "no second row"
        ]


rowDirty : Test
rowDirty =
    describe "one dirty flag"
        [ test "a loaded form is clean" <|
            \_ -> Fm.isDirty filled |> Expect.equal False
        , test "adding a row makes it dirty and removing that row makes it clean again" <|
            \_ ->
                let
                    added =
                        addContact filled
                in
                ( Fm.isDirty added, Fm.isDirty (removeContact 2 added) ) |> Expect.equal ( True, False )
        , test "removing a row that was loaded makes it dirty" <|
            \_ -> filled |> removeContact 0 |> Fm.isDirty |> Expect.equal True
        , test "a value in a row counts, and a value on another step too" <|
            \_ ->
                let
                    inRow =
                        Fm.rowFields f.contacts filled
                            |> List.head
                            |> Maybe.map (\row -> Fm.set row.email "x@y.example" filled)
                            |> Maybe.withDefault filled
                in
                ( Fm.isDirty inRow, Fm.isDirty (Fm.set f.leadTime (Just 9) filled), Fm.isDirty (Fm.set f.name "Other" filled) )
                    |> Expect.equal ( True, True, True )
        , test "revert brings back the removed row and drops the added one" <|
            \_ ->
                let
                    changed =
                        filled |> removeContact 0 |> addContact |> addContact

                    reverted =
                        Fm.revert form changed
                in
                ( Fm.isDirty reverted, Fm.toValues Locale.en form reverted ) |> Expect.equal ( False, Ok sample )
        , test "a row added after a revert gets a number that was never used" <|
            \_ ->
                filled
                    |> removeContact 1
                    |> Fm.revert form
                    |> addContact
                    |> contactKeys
                    |> Expect.equal [ "s-contacts-2-name", "s-contacts-3-name", "s-contacts-4-name" ]
        ]


crossRow : Test
crossRow =
    describe "rules across rows"
        [ test "two primaries are refused, on the second row's own field" <|
            \_ ->
                let
                    two =
                        filled |> Fm.fillRows f.contacts fillContact [ alice, { bob | primary = True } ]
                in
                Fm.problems Locale.en form two
                    |> List.map (\p -> ( p.label, p.message, p.step ))
                    |> Expect.equal [ ( "Contact 2, Primary", "Only one contact can be the primary.", Just Contacts ) ]
        , test "the rule waits until every field is valid on its own" <|
            \_ ->
                let
                    broken =
                        filled |> Fm.fillRows f.contacts fillContact [ alice, { bob | primary = True, email = "nope" } ]
                in
                problemsOf broken |> Expect.equal [ ( "Contact 2, Email", "Invalid email address" ) ]
        ]


stepControl : Test
stepControl =
    describe "the step control"
        [ test "a form starts on its first step" <|
            \_ -> stepOf fresh |> Expect.equal (Just Company)
        , test "advance with a problem stays, shows it and marks the step" <|
            \_ ->
                let
                    ( state, submit ) =
                        advanced fresh
                in
                Expect.all
                    [ \_ -> stepOf state |> Expect.equal (Just Company)
                    , \_ -> submit |> Expect.equal Nothing
                    , \_ -> Fm.summary (bound state) |> showsText "Name: Required"
                    , \_ -> Fm.attempted form Company state |> Expect.equal True
                    , \_ -> Fm.attempted form Contacts state |> Expect.equal False
                    ]
                    ()
        , test "the summary of a step lists the problems of that step only" <|
            \_ ->
                let
                    ( state, _ ) =
                        advanced fresh
                in
                Fm.summary (bound state) |> hidesText "Lead time"
        , test "advance without problems moves to the next step" <|
            \_ ->
                fresh
                    |> Fm.set f.name "Acme"
                    |> advanced
                    |> Tuple.first
                    |> stepOf
                    |> Expect.equal (Just Contacts)
        , test "back is free, and does nothing on the first step" <|
            \_ ->
                let
                    onContacts =
                        fresh |> Fm.set f.name "Acme" |> advanced |> Tuple.first
                in
                ( onContacts |> Fm.back form |> Tuple.first |> stepOf
                , fresh |> Fm.back form |> Tuple.first |> stepOf
                )
                    |> Expect.equal ( Just Company, Just Company )
        , test "going forward stops at the first step on the way that has problems" <|
            \_ ->
                let
                    ( state, _ ) =
                        Fm.goTo form Delivery (Fm.set f.name "Acme" fresh)
                in
                Expect.all
                    [ \_ -> stepOf state |> Expect.equal (Just Contacts)
                    , \_ -> Fm.summary (bound state) |> showsText "Contact 1, Name: Required"
                    ]
                    ()
        , test "going forward over valid steps arrives" <|
            \_ ->
                Fm.goTo form Review filled |> Tuple.first |> stepOf |> Expect.equal (Just Review)
        , test "going back is never blocked" <|
            \_ ->
                let
                    atReview =
                        Fm.goTo form Review filled |> Tuple.first
                in
                Fm.goTo form Company (atReview |> Fm.set f.name "") |> Tuple.first |> stepOf |> Expect.equal (Just Company)
        , test "the stepper's click goes through the same check" <|
            \_ ->
                let
                    onCompany =
                        Fm.set f.name "Acme" fresh

                    clicked =
                        click 2 (Fm.stepper (bound onCompany) []) onCompany
                in
                stepOf clicked |> Expect.equal (Just Contacts)
        , test "advance on the last step gives the record when everything is valid" <|
            \_ ->
                let
                    ( state, submit ) =
                        Fm.goTo form Review filled |> Tuple.first |> advanced
                in
                ( stepOf state, submit ) |> Expect.equal ( Just Review, Just sample )
        , test "advance on the last step with a problem gives no record, stays on the review step and shows every problem" <|
            \_ ->
                let
                    ( state, submit ) =
                        brokenAtReview |> advanced
                in
                Expect.all
                    [ \_ -> submit |> Expect.equal Nothing
                    , \_ -> stepOf state |> Expect.equal (Just Review)
                    , \_ -> Fm.attempted form Company state |> Expect.equal True
                    , \_ -> Fm.attempted form Delivery state |> Expect.equal True
                    ]
                    ()
        ]


{-| The review step reached over valid steps, and then a name, an email and the
lead time are taken away (with `set`, which is not an edit by the user).
-}
brokenAtReview : Fm.State Step
brokenAtReview =
    Fm.goTo form Review filled
        |> Tuple.first
        |> Fm.set f.name ""
        |> Fm.set f.leadTime Nothing


stepProblems : Test
stepProblems =
    let
        everything =
            brokenAtReview |> Fm.fillRows f.contacts fillContact [ { alice | email = "" } ]
    in
    describe "problems and steps"
        [ test "a problem carries the step of its field, rows included" <|
            \_ ->
                Fm.problems Locale.en form fresh
                    |> List.map (\p -> ( p.label, p.step ))
                    |> Expect.equal
                        [ ( "Name", Just Company )
                        , ( "Contact 1, Name", Just Contacts )
                        , ( "Contact 1, Email", Just Contacts )
                        , ( "Contact 1, Role", Just Contacts )
                        , ( "Lead time", Just Delivery )
                        ]
        , test "the stepper marks a step only when its problems are showing" <|
            \_ ->
                let
                    ( tried, _ ) =
                        advanced fresh
                in
                Expect.all
                    [ \_ -> Fm.stepper (bound fresh) [] |> Query.fromHtml |> Query.hasNot [ Selector.class "klar-stepper__step--failed" ]
                    , \_ ->
                        Fm.stepper (bound tried) []
                            |> Query.fromHtml
                            |> Query.find [ Selector.class "klar-stepper__step--failed" ]
                            |> Query.has [ Selector.text "Company" ]
                    ]
                    ()
        , test "the review step lists every problem of every step, with the step" <|
            \_ ->
                Expect.all
                    [ \_ -> Fm.summary (bound everything) |> showsText "Name (Company): Required"
                    , \_ -> Fm.summary (bound everything) |> showsText "Contact 1, Email (Contacts): Required"
                    , \_ -> Fm.summary (bound everything) |> showsText "Lead time (Delivery): Required"
                    ]
                    ()
        , test "going to the review step passes only valid steps" <|
            \_ ->
                -- the lead time is missing: the way to the review stops at the delivery step
                filled |> Fm.set f.leadTime Nothing |> Fm.goTo form Review |> Tuple.first |> stepOf |> Expect.equal (Just Delivery)
        , test "a line of the summary goes to its step and focuses its field" <|
            \_ ->
                let
                    ( state, _ ) =
                        Fm.goToProblem form
                            { field = "s-lead-time", label = "Lead time", message = "Required", step = Just Delivery }
                            everything
                in
                stepOf state |> Expect.equal (Just Delivery)
        , test "a server problem on a row's field sends the form to that step and shows at the field" <|
            \_ ->
                let
                    row =
                        Fm.rowFields f.contacts filled |> List.drop 1 |> List.head

                    ( state, _ ) =
                        case row of
                            Just r ->
                                Fm.rejected [ Fm.problem r.email "This domain is blocked." ] form (Fm.goTo form Company filled |> Tuple.first)

                            Nothing ->
                                ( filled, Cmd.none )
                in
                Expect.all
                    [ \_ -> stepOf state |> Expect.equal (Just Contacts)
                    , \_ -> Fm.summary (bound state) |> showsText "Contact 2, Email: This domain is blocked."
                    , \_ ->
                        Fm.rowFields f.contacts state
                            |> List.drop 1
                            |> List.head
                            |> Maybe.map (\r -> Fm.textInput (bound state) r.email [])
                            |> Maybe.withDefault (Html.text "")
                            |> showsText "This domain is blocked."
                    ]
                    ()
        , test "a standing server problem blocks the step, and editing the field lets it pass" <|
            \_ ->
                let
                    ( rejectedState, _ ) =
                        Fm.rejected [ Fm.problem f.name "Taken." ] form (Fm.goTo form Company filled |> Tuple.first)

                    typed =
                        Fm.textInput (bound rejectedState) f.name []
                            |> Query.fromHtml
                            |> Query.find [ Selector.tag "input" ]
                            |> Event.simulate (Event.input "Acme 2")
                            |> Event.toResult
                            |> Result.map (\msg -> Fm.update form msg rejectedState |> Tuple.first)
                            |> Result.withDefault rejectedState
                in
                ( advanced rejectedState |> Tuple.first |> stepOf
                , advanced typed |> Tuple.first |> stepOf
                )
                    |> Expect.equal ( Just Company, Just Contacts )
        ]


outsideProblems : Test
outsideProblems =
    let
        rule =
            { field = "price-rule-1", label = "Price rule 1", message = "Add a condition.", step = Just Delivery }

        withRule =
            filled |> Fm.outside form [ rule ] |> Fm.goTo form Delivery |> Tuple.first
    in
    describe "problems from outside, on a step"
        [ test "they block the step they belong to" <|
            \_ ->
                let
                    ( state, submit ) =
                        advanced withRule
                in
                ( stepOf state, submit, Fm.attempted form Delivery state ) |> Expect.equal ( Just Delivery, Nothing, True )
        , test "they show in the summary and in the stepper once their step was tried" <|
            \_ ->
                let
                    ( tried, _ ) =
                        advanced withRule
                in
                Expect.all
                    [ \_ -> Fm.summary (bound withRule) |> hidesText "Add a condition."
                    , \_ -> Fm.summary (bound tried) |> showsText "Price rule 1: Add a condition."
                    , \_ ->
                        Fm.stepper (bound tried) []
                            |> Query.fromHtml
                            |> Query.find [ Selector.class "klar-stepper__step--failed" ]
                            |> Query.has [ Selector.text "Delivery" ]
                    ]
                    ()
        , test "they are gone when the application stops giving them" <|
            \_ ->
                let
                    ( state, _ ) =
                        withRule |> Fm.outside form [] |> advanced
                in
                ( Fm.hasProblems form (Fm.outside form [] withRule), stepOf state ) |> Expect.equal ( False, Just Review )
        ]
