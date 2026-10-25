module FormSubmissionTest exposing (suite)

import Expect
import Html.Attributes as Attr
import Klar.Form as Form
import Klar.Form.Layout as Layout
import Klar.Form.Spec as Spec
import Klar.Form.Submission as Submission
import Klar.Locale as Locale
import Klar.Remote as Remote
import Test exposing (Test, describe, test)
import Test.Html.Event as Event
import Test.Html.Query as Query
import Test.Html.Selector as Selector


type alias Fields =
    { name : Form.Field String, email : Form.Field String }


type alias Values =
    { name : String, email : String }


form : Form.Form () Fields Values
form =
    Spec.define "contact" Fields Values
        |> Spec.with (Spec.text "Name" |> Spec.required)
        |> Spec.with (Spec.text "Email" |> Spec.serverKey "email_address" |> Spec.required |> Spec.withMessage (\_ -> "An email is required."))
        |> Spec.build


fields : Fields
fields =
    Form.fields form


filled : Form.State ()
filled =
    Form.init form |> Form.set fields.name "Aurora" |> Form.set fields.email "orders@aurora.example" |> Form.markClean


withRequest : Form.State () -> ({ ticket : Submission.Ticket, values : Values } -> Form.State () -> Expect.Expectation) -> Expect.Expectation
withRequest state check =
    let
        attempt =
            Form.submit Locale.en form state
    in
    case attempt.request of
        Just request ->
            check request attempt.state

        Nothing ->
            Expect.fail "Expected one validated request"


suite : Test
suite =
    describe "Form submission"
        [ test "invalid input reveals problems and sends no request" <|
            \_ ->
                let
                    attempt =
                        Form.submit Locale.en form (Form.init form)
                in
                Expect.all
                    [ \_ -> Expect.equal Nothing attempt.request
                    , \_ -> Expect.equal Layout.Idle (Submission.status (Form.submission attempt.state))
                    , \_ -> Form.summary (Form.bind Locale.en identity form attempt.state) |> Query.fromHtml |> Query.has [ Selector.text "Required" ]
                    ]
                    ()
        , test "pending requests guard double submit and expose readonly inputs" <|
            \_ ->
                withRequest filled <|
                    \_ state ->
                        Expect.all
                            [ \_ -> Expect.equal Nothing (Form.submit Locale.en form state).request
                            , \_ -> Expect.equal Layout.Submitting (Submission.status (Form.submission state))
                            , \_ -> Form.textInput (Form.bind Locale.en identity form state) fields.name [] |> Query.fromHtml |> Query.has [ Selector.attribute (Attr.readonly True) ]
                            ]
                            ()
        , test "control messages cannot alter a pending submission" <|
            \_ ->
                withRequest filled <|
                    \_ state ->
                        case Form.textInput (Form.bind Locale.en identity form state) fields.name [] |> Query.fromHtml |> Query.find [ Selector.tag "input" ] |> Event.simulate (Event.input "Changed") |> Event.toResult of
                            Err message ->
                                Expect.fail message

                            Ok msg ->
                                Expect.equal "Aurora" (Form.get fields.name (Tuple.first (Form.update form msg state)))
        , test "success marks the submitted snapshot clean, not newer programmatic values" <|
            \_ ->
                withRequest filled <|
                    \request state ->
                        let
                            changed =
                                Form.set fields.name "Newer draft" state

                            saved =
                                Tuple.first (Form.finish request.ticket (Ok "Saved") form changed)
                        in
                        Expect.all
                            [ \_ -> Expect.equal "Newer draft" (Form.get fields.name saved)
                            , \_ -> Expect.equal True (Form.isDirty saved)
                            , \_ -> Expect.equal "Aurora" (Form.get fields.name (Form.revert form saved))
                            ]
                            ()
        , test "server keys map through required and withMessage without changing DOM ids" <|
            \_ ->
                withRequest filled <|
                    \request state ->
                        let
                            rejected =
                                Tuple.first (Form.finish request.ticket (Err (Submission.Rejected [ { field = "email_address", message = "Already registered" } ])) form state)
                        in
                        Expect.all
                            [ \_ -> Expect.equal "contact-email" (Form.domId fields.email)
                            , \_ -> Form.textInput (Form.bind Locale.en identity form rejected) fields.email [] |> Query.fromHtml |> Query.has [ Selector.text "Already registered" ]
                            , \_ -> Expect.equal [ "contact-email" ] (List.map .field (Form.problems Locale.en form rejected))
                            ]
                            ()
        , test "unplaced problems are preserved without a broken summary link and can be resubmitted" <|
            \_ ->
                withRequest filled <|
                    \request state ->
                        let
                            rejected =
                                Tuple.first (Form.finish request.ticket (Err (Submission.Rejected [ { field = "billing_account", message = "Account suspended" } ])) form state)

                            summary =
                                Form.summary (Form.bind Locale.en identity form rejected) |> Query.fromHtml
                        in
                        Expect.all
                            [ \_ -> summary |> Query.has [ Selector.text "Account suspended" ]
                            , \_ -> summary |> Query.hasNot [ Selector.tag "button" ]
                            , \_ -> Expect.equal [ "" ] (List.map .field (Form.problems Locale.en form rejected))
                            , \_ -> Expect.notEqual Nothing (Form.submit Locale.en form rejected).request
                            ]
                            ()
        , test "a failed request keeps values and a late reply cannot finish a newer retry" <|
            \_ ->
                withRequest filled <|
                    \first pending ->
                        let
                            failed =
                                Tuple.first (Form.finish first.ticket (Err (Submission.Failed (Remote.problem Remote.network))) form pending)
                        in
                        withRequest failed <|
                            \second retrying ->
                                let
                                    late =
                                        Tuple.first (Form.finish first.ticket (Ok "Old reply") form retrying)

                                    saved =
                                        Tuple.first (Form.finish second.ticket (Ok "Saved") form late)
                                in
                                Expect.all
                                    [ \_ -> Expect.equal Layout.Submitting (Submission.status (Form.submission late))
                                    , \_ -> Expect.equal (Layout.Succeeded "Saved") (Submission.status (Form.submission saved))
                                    , \_ -> Expect.equal (Ok { name = "Aurora", email = "orders@aurora.example" }) (Form.toValues Locale.en form saved)
                                    , \_ -> Expect.equal saved (Tuple.first (Form.finish first.ticket (Ok "Duplicate") form saved))
                                    ]
                                    ()
        , test "discard invalidates outstanding replies without reusing their tickets" <|
            \_ ->
                withRequest filled <|
                    \first pending ->
                        withRequest (Form.revert form pending) <|
                            \second retrying ->
                                Expect.all
                                    [ \_ -> Expect.notEqual first.ticket second.ticket
                                    , \_ -> Expect.equal retrying (Tuple.first (Form.finish first.ticket (Ok "Old") form retrying))
                                    ]
                                    ()
        ]
