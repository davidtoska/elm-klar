module FormStepsTest exposing (suite)

{-| Tests of the steps and the repeating rows of `Klar.Form.Model`: the keys of
the rows, add and remove through the real buttons, one dirty flag over every
step and row, the checks across rows, the step control (`advance`, `goTo`, the
stepper) and the problems that lead to the right step.
-}

import Expect
import Html exposing (Html)
import Klar.Form as Form
import Klar.Form.Check as Check
import Klar.Form.Core as Core
import Klar.Form.Spec as Spec
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
    { name : Form.Field String
    , email : Form.Field String
    , role : Form.Field (Maybe Role)
    , primary : Form.Field Bool
    }


type alias Contact =
    { name : String
    , email : String
    , role : Role
    , primary : Bool
    }


contactForm : Form.Form () ContactFields Contact
contactForm =
    Spec.define "contact" ContactFields Contact
        |> Spec.with (Spec.text "Name" |> Spec.required)
        |> Spec.with (Spec.text "Email" |> Spec.required |> Spec.rules [ Validate.email ])
        |> Spec.with (Spec.choice roleIds "Role" |> Spec.required)
        |> Spec.with (Spec.toggle "Primary")
        |> Spec.build


type alias Fields =
    { name : Form.Field String
    , contacts : Form.Field (Form.Rows ContactFields)
    , leadTime : Form.Field (Maybe Float)
    , notes : Form.Field String
    }


type alias Values =
    { name : String
    , contacts : List Contact
    , leadTime : Float
    , notes : Maybe String
    }


form : Form.Form Step Fields Values
form =
    Spec.define "s" Fields Values
        |> Spec.step Company "Company"
        |> Spec.with (Spec.text "Name" |> Spec.required)
        |> Spec.step Contacts "Contacts"
        |> Spec.with (Spec.rows { label = "Contacts", item = "Contact" } contactForm |> Spec.atLeast 1)
        |> Spec.step Delivery "Delivery"
        |> Spec.with (Spec.number "Lead time" |> Spec.required |> Spec.whole)
        |> Spec.with (Spec.text "Notes")
        |> Spec.step Review "Review"
        |> Spec.check
            (\h state _ ->
                Form.rowFields h.contacts state
                    |> List.filter (\row -> Form.get row.primary state)
                    |> List.drop 1
                    |> List.map (\row -> Form.problem row.primary "Only one contact can be the primary.")
            )
        |> Spec.build


f : Fields
f =
    Form.fields form


fresh : Form.State Step
fresh =
    Form.init form


alice : Contact
alice =
    { name = "Alice", email = "alice@acme.example", role = Sales, primary = True }


bob : Contact
bob =
    { name = "Bob", email = "bob@acme.example", role = Finance, primary = False }


fillContact : Contact -> ContactFields -> Form.State Step -> Form.State Step
fillContact c row =
    Form.set row.name c.name
        >> Form.set row.email c.email
        >> Form.set row.role (Just c.role)
        >> Form.set row.primary c.primary


sample : Values
sample =
    { name = "Acme", contacts = [ alice, bob ], leadTime = 7, notes = Just "Call first" }


fill : Values -> Form.State Step -> Form.State Step
fill v =
    Form.set f.name v.name
        >> Form.fillRows f.contacts fillContact v.contacts
        >> Form.set f.leadTime (Just v.leadTime)
        >> Form.set f.notes (Maybe.withDefault "" v.notes)


filled : Form.State Step
filled =
    fresh |> fill sample |> Form.markClean


bound : Form.State Step -> Form.View Form.Msg
bound state =
    Form.bind Locale.en identity form state


{-| Sends a click to the n-th button of what is drawn and runs the update on
the message that comes back.
-}
click : Int -> Html Form.Msg -> Form.State Step -> Form.State Step
click index html state =
    html
        |> Query.fromHtml
        |> Query.findAll [ Selector.tag "button" ]
        |> Query.index index
        |> Event.simulate Event.click
        |> Event.toResult
        |> Result.map (\msg -> Form.update form msg state |> Tuple.first)
        |> Result.withDefault state


addContact : Form.State Step -> Form.State Step
addContact state =
    click 0 (Form.addRow (bound state) f.contacts [] "Add contact") state


removeContact : Int -> Form.State Step -> Form.State Step
removeContact position state =
    Form.removeRow (bound state) f.contacts position []
        |> Query.fromHtml
        |> Event.simulate Event.click
        |> Event.toResult
        |> Result.map (\msg -> Form.update form msg state |> Tuple.first)
        |> Result.withDefault state


contactKeys : Form.State Step -> List String
contactKeys state =
    Form.rowFields f.contacts state |> List.map (\row -> (Form.problem row.name "").field)


problemsOf : Form.State Step -> List ( String, String )
problemsOf state =
    Form.problems Locale.en form state |> List.map (\p -> ( p.label, p.message ))


stepOf : Form.State Step -> Maybe Step
stepOf =
    Form.currentStep form


showsText : String -> Html Form.Msg -> Expect.Expectation
showsText wanted html =
    html |> Query.fromHtml |> Query.has [ Selector.text wanted ]


hidesText : String -> Html Form.Msg -> Expect.Expectation
hidesText unwanted html =
    html |> Query.fromHtml |> Query.hasNot [ Selector.text unwanted ]


{-| What `advance` does, as the state and whether a record came out.
-}
advanced : Form.State Step -> ( Form.State Step, Maybe Values )
advanced state =
    let
        next =
            Form.advance form state
    in
    ( next.state, next.submit )


{-| `Form.stepBody`: the children of the body carry the step in their keys. Elm cannot be run
in these tests, so the keys are what is checked: without them the diff of two steps
reuses the focused input of the old step for the field at the same place in the new
one (benchmark run 1, T05).
-}
stepBodies : Test
stepBodies =
    let
        keysAt state =
            Core.stepKeys (bound state) [ Html.text "first field", Html.text "second field" ]
                |> List.map Tuple.first
    in
    describe "stepBody"
        [ test "the keys of two steps never share a key" <|
            \_ ->
                let
                    onCompany =
                        keysAt fresh

                    onContacts =
                        keysAt (Form.goTo form Contacts filled |> Tuple.first)
                in
                List.filter (\key -> List.member key onContacts) onCompany
                    |> Expect.equal []
        , test "the keys inside one step are different from each other" <|
            \_ ->
                keysAt fresh
                    |> (\keys ->
                            List.length
                                (List.foldl
                                    (\key seen ->
                                        if List.member key seen then
                                            seen

                                        else
                                            key :: seen
                                    )
                                    []
                                    keys
                                )
                       )
                    |> Expect.equal 2
        , test "the body draws every child" <|
            \_ ->
                Form.stepBody (bound fresh) [ Html.text "first field", Html.text "second field" ]
                    |> showsText "second field"
        ]


suite : Test
suite =
    describe "Klar.Form.Model: steps and rows"
        [ stepBodies
        , rowKeys
        , rowValues
        , rowDirty
        , crossRow
        , ruleOfAGroup
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
                Form.rowFields f.contacts state
                    |> List.map (\row -> Form.get row.name state)
                    |> Expect.equal [ "Bob" ]
        , test "the handles are the rows' own, at the keys the DOM uses" <|
            \_ ->
                Form.textInput (bound fresh) (List.head (Form.rowFields f.contacts fresh) |> Maybe.map .name |> Maybe.withDefault f.name) []
                    |> Query.fromHtml
                    |> Query.has [ Selector.id "s-contacts-1-name" ]
        ]


rowValues : Test
rowValues =
    describe "the values and problems of rows"
        [ test "the rows come out as a list, in order" <|
            \_ -> Form.toValues Locale.en form filled |> Expect.equal (Ok sample)
        , test "the round trip of a record with rows" <|
            \_ -> Check.roundTrip form fill sample |> Expect.equal (Ok sample)
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
                    |> Form.fillRows f.contacts fillContact [ bob ]
                    |> Form.rowFields f.contacts
                    |> List.length
                    |> Expect.equal 1
        , test "the add button shows the group's problem once it is revealed" <|
            \_ ->
                let
                    none =
                        fresh |> removeContact 0 |> Form.reveal form |> Tuple.first
                in
                Form.addRow (bound none) f.contacts [] "Add contact" |> showsText "Add at least 1"
        , test "a row added after the problems were revealed starts quiet" <|
            \_ ->
                let
                    state =
                        fresh |> Form.reveal form |> Tuple.first |> addContact

                    second =
                        Form.rowFields f.contacts state |> List.drop 1 |> List.head
                in
                case second of
                    Just row ->
                        Form.textInput (bound state) row.name [] |> hidesText "Required"

                    Nothing ->
                        Expect.fail "no second row"
        ]


rowDirty : Test
rowDirty =
    describe "one dirty flag"
        [ test "a loaded form is clean" <|
            \_ -> Form.isDirty filled |> Expect.equal False
        , test "adding a row makes it dirty and removing that row makes it clean again" <|
            \_ ->
                let
                    added =
                        addContact filled
                in
                ( Form.isDirty added, Form.isDirty (removeContact 2 added) ) |> Expect.equal ( True, False )
        , test "removing a row that was loaded makes it dirty" <|
            \_ -> filled |> removeContact 0 |> Form.isDirty |> Expect.equal True
        , test "a value in a row counts, and a value on another step too" <|
            \_ ->
                let
                    inRow =
                        Form.rowFields f.contacts filled
                            |> List.head
                            |> Maybe.map (\row -> Form.set row.email "x@y.example" filled)
                            |> Maybe.withDefault filled
                in
                ( Form.isDirty inRow, Form.isDirty (Form.set f.leadTime (Just 9) filled), Form.isDirty (Form.set f.name "Other" filled) )
                    |> Expect.equal ( True, True, True )
        , test "revert brings back the removed row and drops the added one" <|
            \_ ->
                let
                    changed =
                        filled |> removeContact 0 |> addContact |> addContact

                    reverted =
                        Form.revert form changed
                in
                ( Form.isDirty reverted, Form.toValues Locale.en form reverted ) |> Expect.equal ( False, Ok sample )
        , test "a row added after a revert gets a number that was never used" <|
            \_ ->
                filled
                    |> removeContact 1
                    |> Form.revert form
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
                        filled |> Form.fillRows f.contacts fillContact [ alice, { bob | primary = True } ]
                in
                Form.problems Locale.en form two
                    |> List.map (\p -> ( p.label, p.message, p.step ))
                    |> Expect.equal [ ( "Contact 2, Primary", "Only one contact can be the primary.", Just Contacts ) ]
        , test "the rule waits until every field is valid on its own" <|
            \_ ->
                let
                    broken =
                        filled |> Form.fillRows f.contacts fillContact [ alice, { bob | primary = True, email = "nope" } ]
                in
                problemsOf broken |> Expect.equal [ ( "Contact 2, Email", "Invalid email address" ) ]
        ]


type alias RuledFields =
    { name : Form.Field String
    , contacts : Form.Field (Form.Rows ContactFields)
    , leadTime : Form.Field (Maybe Float)
    }


type alias RuledValues =
    { name : String
    , contacts : List Contact
    , leadTime : Float
    }


{-| The same steps, with the rule across the rows on the group instead of a check.
-}
ruled : Form.Form Step RuledFields RuledValues
ruled =
    Spec.define "r" RuledFields RuledValues
        |> Spec.step Company "Company"
        |> Spec.with (Spec.text "Name" |> Spec.required)
        |> Spec.step Contacts "Contacts"
        |> Spec.with
            (Spec.rows { label = "Contacts", item = "Contact" } contactForm
                |> Spec.atLeast 1
                |> Spec.rule (\contacts -> List.length (List.filter .primary contacts) <= 1) (\_ -> "At most one contact is the primary.")
            )
        |> Spec.step Delivery "Delivery"
        |> Spec.with (Spec.number "Lead time" |> Spec.required)
        |> Spec.build


ruledFields : RuledFields
ruledFields =
    Form.fields ruled


twoPrimaries : Form.State Step
twoPrimaries =
    Form.init ruled
        |> Form.set ruledFields.name "Acme"
        |> Form.fillRows ruledFields.contacts fillRuledContact [ alice, { bob | primary = True } ]
        |> Form.goTo ruled Contacts
        |> Tuple.first


fillRuledContact : Contact -> ContactFields -> Form.State Step -> Form.State Step
fillRuledContact c row =
    Form.set row.name c.name
        >> Form.set row.email c.email
        >> Form.set row.role (Just c.role)
        >> Form.set row.primary c.primary


ruleOfAGroup : Test
ruleOfAGroup =
    describe "a rule of a group of rows, and a check"
        [ test "the rule holds the step back while a later step is still empty" <|
            \_ ->
                let
                    next =
                        Form.advance ruled twoPrimaries
                in
                Expect.all
                    [ \_ -> Form.currentStep ruled next.state |> Expect.equal (Just Contacts)
                    , \_ -> Form.problems Locale.en ruled next.state |> List.map (\p -> ( p.label, p.message, p.step )) |> List.take 1 |> Expect.equal [ ( "Contacts", "At most one contact is the primary.", Just Contacts ) ]
                    ]
                    ()
        , test "its problem shows at the add button once the step was tried" <|
            \_ ->
                let
                    next =
                        Form.advance ruled twoPrimaries
                in
                Form.addRow (Form.bind Locale.en identity ruled next.state) ruledFields.contacts [] "Add contact"
                    |> Query.fromHtml
                    |> Query.has [ Selector.text "At most one contact is the primary." ]
        , test "once there is one primary the step lets go" <|
            \_ ->
                twoPrimaries
                    |> Form.fillRows ruledFields.contacts fillRuledContact [ alice, bob ]
                    |> Form.advance ruled
                    |> .state
                    |> Form.currentStep ruled
                    |> Expect.equal (Just Delivery)
        , test "a check over the whole form waits until every step is valid" <|
            \_ ->
                -- two primaries, but the lead time is empty: the check has nothing to say yet
                filled
                    |> Form.fillRows f.contacts fillContact [ alice, { bob | primary = True } ]
                    |> Form.set f.leadTime Nothing
                    |> problemsOf
                    |> Expect.equal [ ( "Lead time", "Required" ) ]
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
                    , \_ -> Form.summary (bound state) |> showsText "Name: Required"
                    , \_ -> Form.attempted form Company state |> Expect.equal True
                    , \_ -> Form.attempted form Contacts state |> Expect.equal False
                    ]
                    ()
        , test "the summary of a step lists the problems of that step only" <|
            \_ ->
                let
                    ( state, _ ) =
                        advanced fresh
                in
                Form.summary (bound state) |> hidesText "Lead time"
        , test "advance without problems moves to the next step" <|
            \_ ->
                fresh
                    |> Form.set f.name "Acme"
                    |> advanced
                    |> Tuple.first
                    |> stepOf
                    |> Expect.equal (Just Contacts)
        , test "back is free, and does nothing on the first step" <|
            \_ ->
                let
                    onContacts =
                        fresh |> Form.set f.name "Acme" |> advanced |> Tuple.first
                in
                ( onContacts |> Form.back form |> Tuple.first |> stepOf
                , fresh |> Form.back form |> Tuple.first |> stepOf
                )
                    |> Expect.equal ( Just Company, Just Company )
        , test "going forward stops at the first step on the way that has problems" <|
            \_ ->
                let
                    ( state, _ ) =
                        Form.goTo form Delivery (Form.set f.name "Acme" fresh)
                in
                Expect.all
                    [ \_ -> stepOf state |> Expect.equal (Just Contacts)
                    , \_ -> Form.summary (bound state) |> showsText "Contact 1, Name: Required"
                    ]
                    ()
        , test "going forward over valid steps arrives" <|
            \_ ->
                Form.goTo form Review filled |> Tuple.first |> stepOf |> Expect.equal (Just Review)
        , test "going back is never blocked" <|
            \_ ->
                let
                    atReview =
                        Form.goTo form Review filled |> Tuple.first
                in
                Form.goTo form Company (atReview |> Form.set f.name "") |> Tuple.first |> stepOf |> Expect.equal (Just Company)
        , test "the stepper's click goes through the same check" <|
            \_ ->
                let
                    onCompany =
                        Form.set f.name "Acme" fresh

                    clicked =
                        click 2 (Form.stepper (bound onCompany) []) onCompany
                in
                stepOf clicked |> Expect.equal (Just Contacts)
        , test "advance on the last step gives the record when everything is valid" <|
            \_ ->
                let
                    ( state, submit ) =
                        Form.goTo form Review filled |> Tuple.first |> advanced
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
                    , \_ -> Form.attempted form Company state |> Expect.equal True
                    , \_ -> Form.attempted form Delivery state |> Expect.equal True
                    ]
                    ()
        ]


{-| The review step reached over valid steps, and then a name, an email and the
lead time are taken away (with `set`, which is not an edit by the user).
-}
brokenAtReview : Form.State Step
brokenAtReview =
    Form.goTo form Review filled
        |> Tuple.first
        |> Form.set f.name ""
        |> Form.set f.leadTime Nothing


stepProblems : Test
stepProblems =
    let
        everything =
            brokenAtReview |> Form.fillRows f.contacts fillContact [ { alice | email = "" } ]
    in
    describe "problems and steps"
        [ test "a problem carries the step of its field, rows included" <|
            \_ ->
                Form.problems Locale.en form fresh
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
                    [ \_ -> Form.stepper (bound fresh) [] |> Query.fromHtml |> Query.hasNot [ Selector.class "klar-stepper__step--failed" ]
                    , \_ ->
                        Form.stepper (bound tried) []
                            |> Query.fromHtml
                            |> Query.find [ Selector.class "klar-stepper__step--failed" ]
                            |> Query.has [ Selector.text "Company" ]
                    ]
                    ()
        , test "the review step lists every problem of every step, with the step" <|
            \_ ->
                Expect.all
                    [ \_ -> Form.summary (bound everything) |> showsText "Name (Company): Required"
                    , \_ -> Form.summary (bound everything) |> showsText "Contact 1, Email (Contacts): Required"
                    , \_ -> Form.summary (bound everything) |> showsText "Lead time (Delivery): Required"
                    ]
                    ()
        , test "going to the review step passes only valid steps" <|
            \_ ->
                -- the lead time is missing: the way to the review stops at the delivery step
                filled |> Form.set f.leadTime Nothing |> Form.goTo form Review |> Tuple.first |> stepOf |> Expect.equal (Just Delivery)
        , test "a line of the summary goes to its step and focuses its field" <|
            \_ ->
                let
                    ( state, _ ) =
                        Form.goToProblem form
                            { field = "s-lead-time", label = "Lead time", message = "Required", step = Just Delivery }
                            everything
                in
                stepOf state |> Expect.equal (Just Delivery)
        , test "a server problem on a row's field sends the form to that step and shows at the field" <|
            \_ ->
                let
                    row =
                        Form.rowFields f.contacts filled |> List.drop 1 |> List.head

                    ( state, _ ) =
                        case row of
                            Just r ->
                                Form.rejected [ Form.problem r.email "This domain is blocked." ] form (Form.goTo form Company filled |> Tuple.first)

                            Nothing ->
                                ( filled, Cmd.none )
                in
                Expect.all
                    [ \_ -> stepOf state |> Expect.equal (Just Contacts)
                    , \_ -> Form.summary (bound state) |> showsText "Contact 2, Email: This domain is blocked."
                    , \_ ->
                        Form.rowFields f.contacts state
                            |> List.drop 1
                            |> List.head
                            |> Maybe.map (\r -> Form.textInput (bound state) r.email [])
                            |> Maybe.withDefault (Html.text "")
                            |> showsText "This domain is blocked."
                    ]
                    ()
        , test "a standing server problem blocks the step, and editing the field lets it pass" <|
            \_ ->
                let
                    ( rejectedState, _ ) =
                        Form.rejected [ Form.problem f.name "Taken." ] form (Form.goTo form Company filled |> Tuple.first)

                    typed =
                        Form.textInput (bound rejectedState) f.name []
                            |> Query.fromHtml
                            |> Query.find [ Selector.tag "input" ]
                            |> Event.simulate (Event.input "Acme 2")
                            |> Event.toResult
                            |> Result.map (\msg -> Form.update form msg rejectedState |> Tuple.first)
                            |> Result.withDefault rejectedState
                in
                ( advanced rejectedState |> Tuple.first |> stepOf
                , advanced typed |> Tuple.first |> stepOf
                )
                    |> Expect.equal ( Just Company, Just Contacts )
        , test "a rejected save on the review step stays there and lists every problem with a way to go to it" <|
            \_ ->
                let
                    onReview =
                        filled |> Form.goTo form Review |> Tuple.first

                    ( state, _ ) =
                        Form.rejected [ Form.problem f.name "Taken." ] form onReview

                    goToIt =
                        Form.problems Locale.en form state
                            |> List.head
                            |> Maybe.map (\p -> Form.goToProblem form p state |> Tuple.first)
                            |> Maybe.withDefault state
                in
                Expect.all
                    [ \_ -> stepOf state |> Expect.equal (Just Review)
                    , \_ -> Form.summary (bound state) |> showsText "Name (Company): Taken."
                    , \_ ->
                        Form.stepper (bound state) []
                            |> Query.fromHtml
                            |> Query.find [ Selector.class "klar-stepper__step--failed" ]
                            |> Query.has [ Selector.text "Company" ]
                    , \_ -> Form.hasProblems form state |> Expect.equal True
                    , \_ -> stepOf goToIt |> Expect.equal (Just Company)
                    ]
                    ()
        , test "a rejected save on the review step stays there also when the problem is in a later step's row" <|
            \_ ->
                let
                    row =
                        Form.rowFields f.contacts filled |> List.drop 1 |> List.head

                    ( state, _ ) =
                        case row of
                            Just r ->
                                Form.rejected [ Form.problem r.email "This domain is blocked." ] form (Form.goTo form Review filled |> Tuple.first)

                            Nothing ->
                                ( filled, Cmd.none )
                in
                Expect.all
                    [ \_ -> stepOf state |> Expect.equal (Just Review)
                    , \_ -> Form.summary (bound state) |> showsText "Contact 2, Email (Contacts): This domain is blocked."
                    ]
                    ()
        ]


outsideProblems : Test
outsideProblems =
    let
        rule =
            { field = "price-rule-1", label = "Price rule 1", message = "Add a condition.", step = Just Delivery }

        withRule =
            filled |> Form.outside form [ rule ] |> Form.goTo form Delivery |> Tuple.first
    in
    describe "problems from outside, on a step"
        [ test "they block the step they belong to" <|
            \_ ->
                let
                    ( state, submit ) =
                        advanced withRule
                in
                ( stepOf state, submit, Form.attempted form Delivery state ) |> Expect.equal ( Just Delivery, Nothing, True )
        , test "they show in the summary and in the stepper once their step was tried" <|
            \_ ->
                let
                    ( tried, _ ) =
                        advanced withRule
                in
                Expect.all
                    [ \_ -> Form.summary (bound withRule) |> hidesText "Add a condition."
                    , \_ -> Form.summary (bound tried) |> showsText "Price rule 1: Add a condition."
                    , \_ ->
                        Form.stepper (bound tried) []
                            |> Query.fromHtml
                            |> Query.find [ Selector.class "klar-stepper__step--failed" ]
                            |> Query.has [ Selector.text "Delivery" ]
                    ]
                    ()
        , test "they are gone when the application stops giving them" <|
            \_ ->
                let
                    ( state, _ ) =
                        withRule |> Form.outside form [] |> advanced
                in
                ( Form.hasProblems form (Form.outside form [] withRule), stepOf state ) |> Expect.equal ( False, Just Review )
        ]
