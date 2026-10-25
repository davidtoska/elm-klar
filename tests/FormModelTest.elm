module FormModelTest exposing (suite)

{-| Tests of `Klar.Form.Model`: what the rules produce, the round trip of a
record, dirty after typing and undoing, the derived DOM ids, and a server
problem that goes away when its field is edited. Typing is done through the
rendered controls, so the opaque messages are the real ones.
-}

import Expect
import FormDocExample
import Html exposing (Html)
import Json.Encode as Encode
import Klar.Date as Date
import Klar.FileDrop as FileDrop
import Klar.Form as Form
import Klar.Form.Check as Check
import Klar.Form.Spec as Spec
import Klar.Ids as Ids exposing (Ids)
import Klar.Locale as Locale
import Klar.Remote as Remote
import Klar.Rule as Rule
import Klar.Select as Select
import Klar.TextArea as TextArea
import Klar.Validate as Validate
import Test exposing (Test, describe, test)
import Test.Html.Event as Event
import Test.Html.Query as Query
import Test.Html.Selector as Selector


type CountryId
    = CountryId String


type CategoryId
    = CategoryId Int


countryIds : Ids CountryId
countryIds =
    Ids.make { toKey = \(CountryId code) -> code, fromKey = Just << CountryId }


categoryIds : Ids CategoryId
categoryIds =
    Ids.make
        { toKey = \(CategoryId n) -> String.fromInt n
        , fromKey = Maybe.map CategoryId << String.toInt
        }


type alias Fields =
    { name : Form.Field String
    , website : Form.Field String
    , age : Form.Field (Maybe Float)
    , country : Form.Field (Maybe CountryId)
    , categories : Form.Field (List CategoryId)
    , news : Form.Field Bool
    }


type alias Values =
    { name : String
    , website : Maybe String
    , age : Float
    , country : CountryId
    , categories : List CategoryId
    , news : Bool
    }


form : Form.Form () Fields Values
form =
    Spec.define "supplier" Fields Values
        |> Spec.with (Spec.text "Name" |> Spec.required |> Spec.rules [ Validate.maxLength 10 ])
        |> Spec.with (Spec.text "Website" |> Spec.rules [ Validate.email ])
        |> Spec.with (Spec.number "Age" |> Spec.required |> Spec.range 18 99 |> Spec.whole)
        |> Spec.with (Spec.choice countryIds "Country" |> Spec.required)
        |> Spec.with (Spec.choices categoryIds "Categories" |> Spec.atLeast 1)
        |> Spec.with (Spec.toggle "Newsletter")
        |> Spec.build


f : Fields
f =
    Form.fields form


sample : Values
sample =
    { name = "Acme"
    , website = Just "sales@acme.example"
    , age = 42
    , country = CountryId "no"
    , categories = [ CategoryId 2, CategoryId 1 ]
    , news = True
    }


fill : Values -> Form.State () -> Form.State ()
fill v =
    Form.set f.name v.name
        >> Form.set f.website (Maybe.withDefault "" v.website)
        >> Form.set f.age (Just v.age)
        >> Form.set f.country (Just v.country)
        >> Form.set f.categories v.categories
        >> Form.set f.news v.news


filled : Form.State ()
filled =
    Form.init form |> fill sample |> Form.markClean


countries : Remote.Remote (List (Select.Option CountryId))
countries =
    Remote.Loaded [ Select.option (CountryId "no") "Norway", Select.option (CountryId "se") "Sweden" ]


bound : Form.State () -> Form.View Form.Msg
bound state =
    Form.bind Locale.en identity form state


{-| Sends an event to the first input of a control and runs the form's update
on the message that comes back.
-}
fire : (Form.View Form.Msg -> Html Form.Msg) -> ( String, Encode.Value ) -> Form.State () -> Form.State ()
fire draw event state =
    draw (bound state)
        |> Query.fromHtml
        |> Query.find [ Selector.tag "input" ]
        |> Event.simulate event
        |> Event.toResult
        |> Result.map (\msg -> Form.update form msg state |> Tuple.first)
        |> Result.withDefault state


typeName : String -> Form.State () -> Form.State ()
typeName text =
    fire (\v -> Form.textInput v f.name []) (Event.input text)


typeAge : String -> Form.State () -> Form.State ()
typeAge text =
    fire (\v -> Form.numberInput v f.age []) (Event.input text)


leaveName : Form.State () -> Form.State ()
leaveName =
    fire (\v -> Form.textInput v f.name []) Event.blur


problemsOf : Form.State () -> List ( String, String )
problemsOf state =
    case Form.toValues Locale.en form state of
        Ok _ ->
            []

        Err problems ->
            List.map (\p -> ( p.field, p.message )) problems


showsText : String -> Html Form.Msg -> Expect.Expectation
showsText wanted html =
    html |> Query.fromHtml |> Query.has [ Selector.text wanted ]


hidesText : String -> Html Form.Msg -> Expect.Expectation
hidesText unwanted html =
    html |> Query.fromHtml |> Query.hasNot [ Selector.text unwanted ]


suite : Test
suite =
    describe "Klar.Form.Model"
        [ validation
        , roundTrips
        , dirty
        , derivedIds
        , serverProblems
        , visibility
        , everythingShowing
        , tagsAndFiles
        , idsInRules
        , docExample
        , mapOptionTest
        ]


validation : Test
validation =
    describe "rules and the output type"
        [ test "a valid form produces the record, with required fields unwrapped" <|
            \_ -> Form.toValues Locale.en form filled |> Expect.equal (Ok sample)
        , test "a blank optional text is Nothing and the output is trimmed" <|
            \_ ->
                filled
                    |> Form.set f.website "   "
                    |> Form.set f.name "  Acme  "
                    |> Form.toValues Locale.en form
                    |> Result.map (\v -> ( v.name, v.website ))
                    |> Expect.equal (Ok ( "Acme", Nothing ))
        , test "an empty form lists every problem in declaration order" <|
            \_ ->
                problemsOf (Form.init form)
                    |> Expect.equal
                        [ ( "supplier-name", "Required" )
                        , ( "supplier-age", "Required" )
                        , ( "supplier-country", "Required" )
                        , ( "supplier-categories", "Choose at least 1" )
                        ]
        , test "the messages come in the language asked for" <|
            \_ ->
                Form.toValues Locale.nb form (Form.init form)
                    |> Result.mapError (List.map .message)
                    |> Expect.equal (Err [ "Må fylles ut", "Må fylles ut", "Må fylles ut", "Velg minst 1" ])
        , test "rules run on the text as typed" <|
            \_ ->
                problemsOf (Form.set f.name "A very long name" filled)
                    |> Expect.equal [ ( "supplier-name", "Must be at most 10 characters" ) ]
        , test "a rule of Klar.Validate runs on an optional text" <|
            \_ ->
                problemsOf (Form.set f.website "not an email" filled)
                    |> Expect.equal [ ( "supplier-website", "Invalid email address" ) ]
        , test "range and whole check a number and do not move it" <|
            \_ ->
                ( problemsOf (Form.set f.age (Just 17) filled)
                , problemsOf (Form.set f.age (Just 20.5) filled)
                , Form.get f.age (Form.set f.age (Just 17) filled)
                )
                    |> Expect.equal
                        ( [ ( "supplier-age", "Must be between 18 and 99" ) ]
                        , [ ( "supplier-age", "Must be a whole number" ) ]
                        , Just 17
                        )
        , test "text that is not a number is a problem, also when the field is optional" <|
            \_ ->
                let
                    optional =
                        Spec.define "n" identity identity
                            |> Spec.with (Spec.number "Weight")
                            |> Spec.build

                    handle =
                        Form.fields optional

                    typed =
                        Form.init optional
                            |> (\state ->
                                    Form.bind Locale.en identity optional state
                                        |> (\v -> Form.numberInput v handle [])
                                        |> Query.fromHtml
                                        |> Query.find [ Selector.tag "input" ]
                                        |> Event.simulate (Event.input "abc")
                                        |> Event.toResult
                                        |> Result.map (\msg -> Form.update optional msg state |> Tuple.first)
                                        |> Result.withDefault state
                               )
                in
                Form.toValues Locale.en optional typed
                    |> Expect.equal (Err [ { field = "n-weight", label = "Weight", message = "Must be a number", step = Nothing } ])
        , test "atLeast counts the choices" <|
            \_ ->
                ( Form.set f.categories [] filled |> problemsOf
                , Form.set f.categories [ CategoryId 9 ] filled |> problemsOf
                )
                    |> Expect.equal ( [ ( "supplier-categories", "Choose at least 1" ) ], [] )
        , test "one turns a list into a Maybe and refuses two" <|
            \_ ->
                let
                    single =
                        Spec.define "s" identity identity
                            |> Spec.with (Spec.choices categoryIds "Pick" |> Spec.one)
                            |> Spec.build

                    pick h ids_ =
                        Form.init single |> Form.set h ids_ |> Form.toValues Locale.en single
                in
                ( pick (Form.fields single) []
                , pick (Form.fields single) [ CategoryId 1 ]
                , pick (Form.fields single) [ CategoryId 1, CategoryId 2 ] |> Result.mapError (List.map .message)
                )
                    |> Expect.equal ( Ok Nothing, Ok (Just (CategoryId 1)), Err [ "Only one is allowed" ] )
        , test "withMessage replaces the message of the rule added last, per language" <|
            \_ ->
                let
                    custom =
                        Spec.define "m" identity identity
                            |> Spec.with
                                (Spec.text "Name"
                                    |> Spec.required
                                    |> Spec.withMessage (\locale -> Locale.pick locale { nb = "Oppgi navn", en = "Enter a name" })
                                )
                            |> Spec.build

                    messages locale =
                        Form.toValues locale custom (Form.init custom) |> Result.mapError (List.map .message)
                in
                ( messages Locale.en, messages Locale.nb )
                    |> Expect.equal ( Err [ "Enter a name" ], Err [ "Oppgi navn" ] )
        , test "withMessage reaches the rule added last, not an earlier one" <|
            \_ ->
                let
                    custom =
                        Spec.define "m" identity identity
                            |> Spec.with
                                (Spec.text "Name"
                                    |> Spec.required
                                    |> Spec.rules [ Validate.maxLength 3 ]
                                    |> Spec.withMessage (\_ -> "Too long")
                                )
                            |> Spec.build

                    state =
                        Form.init custom
                in
                ( Form.toValues Locale.en custom state |> Result.mapError (List.map .message)
                , Form.toValues Locale.en custom (Form.set (Form.fields custom) "abcdef" state) |> Result.mapError (List.map .message)
                )
                    |> Expect.equal ( Err [ "Required" ], Err [ "Too long" ] )
        ]


type alias SwapFields =
    { first : Form.Field String
    , second : Form.Field String
    }


type alias SwapValues =
    { first : Maybe String
    , second : Maybe String
    }


{-| Two fields of the same type listed in another order in `Values` than in
the pipeline. The compiler cannot see it; `roundTrip` does.
-}
swapped : Form.Form () SwapFields SwapValues
swapped =
    Spec.define "swap" SwapFields (\a b -> SwapValues b a)
        |> Spec.with (Spec.text "First")
        |> Spec.with (Spec.text "Second")
        |> Spec.build


roundTrips : Test
roundTrips =
    describe "the round trip of a record"
        [ test "set then toValues gives the record back" <|
            \_ -> Check.roundTrip form fill sample |> Expect.equal (Ok sample)
        , test "get returns what was set, for every kind" <|
            \_ ->
                { name = Form.get f.name filled
                , age = Form.get f.age filled
                , country = Form.get f.country filled
                , categories = Form.get f.categories filled
                , news = Form.get f.news filled
                }
                    |> Expect.equal { name = "Acme", age = Just 42, country = Just (CountryId "no"), categories = [ CategoryId 2, CategoryId 1 ], news = True }
        , test "a fresh form is empty" <|
            \_ ->
                let
                    state =
                        Form.init form
                in
                { name = Form.get f.name state, age = Form.get f.age state, country = Form.get f.country state, categories = Form.get f.categories state, news = Form.get f.news state }
                    |> Expect.equal { name = "", age = Nothing, country = Nothing, categories = [], news = False }
        , test "two same-typed fields swapped in Values compile but roundTrip catches them" <|
            \_ ->
                let
                    swapFill v =
                        let
                            handles =
                                Form.fields swapped
                        in
                        Form.set handles.first (Maybe.withDefault "" v.first)
                            >> Form.set handles.second (Maybe.withDefault "" v.second)

                    one_ =
                        { first = Just "one", second = Just "two" }
                in
                Check.roundTrip swapped swapFill one_
                    |> Expect.notEqual (Ok one_)
        , test "ids that survive the key round trip are not lost" <|
            \_ ->
                ( Check.lostIds countryIds [ CountryId "no", CountryId "se" ]
                , Check.lostIds categoryIds [ CategoryId 1, CategoryId 20 ]
                )
                    |> Expect.equal ( [], [] )
        , test "lostIds lists values whose key does not read back" <|
            \_ ->
                let
                    lossy =
                        Ids.make { toKey = \(CategoryId n) -> String.fromInt n, fromKey = \_ -> Nothing }
                in
                Check.lostIds lossy [ CategoryId 1 ] |> Expect.equal [ CategoryId 1 ]
        ]


dirty : Test
dirty =
    describe "dirty"
        [ test "a loaded and cleaned form is not dirty" <|
            \_ -> Form.isDirty filled |> Expect.equal False
        , test "typing a letter makes it dirty, deleting it makes it clean again" <|
            \_ ->
                let
                    typed =
                        typeName "Acmex" filled

                    undone =
                        typeName "Acme" typed
                in
                ( Form.isDirty typed, Form.isDirty undone ) |> Expect.equal ( True, False )
        , test "set changes the dirty state for every kind" <|
            \_ ->
                [ Form.set f.country (Just (CountryId "se")) filled
                , Form.set f.categories [ CategoryId 1 ] filled
                , Form.set f.age (Just 43) filled
                , Form.set f.news False filled
                , Form.set f.website "" filled
                ]
                    |> List.map Form.isDirty
                    |> Expect.equal [ True, True, True, True, True ]
        , test "markClean moves the baseline and revert goes back to it" <|
            \_ ->
                let
                    edited =
                        typeName "Other" filled
                in
                ( Form.markClean edited |> Form.isDirty
                , Form.revert form edited |> Form.get f.name
                , Form.revert form edited |> Form.isDirty
                )
                    |> Expect.equal ( False, "Acme", False )
        , test "opening or searching a select does not make the form dirty" <|
            \_ ->
                -- the open list is not a value: the select is drawn, not changed
                bound filled
                    |> (\v -> Form.select v f.country countries [])
                    |> Query.fromHtml
                    |> Query.has [ Selector.text "Country" ]
        ]


derivedIds : Test
derivedIds =
    describe "DOM ids"
        [ test "ids are made from the prefix and the label" <|
            \_ ->
                [ Form.problem f.name "", Form.problem f.country "", Form.problem f.categories "" ]
                    |> List.map .field
                    |> Expect.equal [ "supplier-name", "supplier-country", "supplier-categories" ]
        , test "equal labels get different ids, in declaration order" <|
            \_ ->
                let
                    twins =
                        Spec.define "t" (\a b c -> [ a, b, c ]) (\_ _ _ -> ())
                            |> Spec.with (Spec.text "Name")
                            |> Spec.with (Spec.text "Name")
                            |> Spec.with (Spec.text "Name 2")
                            |> Spec.build
                in
                Form.fields twins
                    |> List.map (\h -> (Form.problem h "").field)
                    |> Expect.equal [ "t-name", "t-name-2", "t-name__2" ]
        , test "the rendered control carries the derived id and a label" <|
            \_ ->
                Form.textInput (bound filled) f.name []
                    |> Query.fromHtml
                    |> Query.has [ Selector.id "supplier-name" ]
        ]


serverProblems : Test
serverProblems =
    let
        rejectedState =
            Form.rejected [ Form.problem f.name "Already taken", Form.problem f.website "Not reachable" ] form filled
                |> Tuple.first
    in
    describe "problems from the server"
        [ test "a server problem shows at its field and in the summary" <|
            \_ ->
                Expect.all
                    [ \_ -> Form.textInput (bound rejectedState) f.name [] |> showsText "Already taken"
                    , \_ -> Form.summary (bound rejectedState) |> showsText "Not reachable"
                    ]
                    ()
        , test "it does not hide a client problem of the same field" <|
            \_ ->
                let
                    state =
                        Form.set f.name "A very long name" rejectedState
                in
                Form.textInput (bound state) f.name [] |> showsText "Must be at most 10 characters"
        , test "it clears when its field is edited, and only that field" <|
            \_ ->
                let
                    edited =
                        typeName "Acme 2" rejectedState
                in
                Expect.all
                    [ \_ -> Form.textInput (bound edited) f.name [] |> hidesText "Already taken"
                    , \_ -> Form.textInput (bound edited) f.website [] |> showsText "Not reachable"
                    ]
                    ()
        , test "it clears also when the old value is typed again" <|
            \_ ->
                typeName "Acme2" rejectedState
                    |> typeName "Acme"
                    |> (\state -> Form.textInput (bound state) f.name [])
                    |> hidesText "Already taken"
        , test "a problem for the same field twice keeps the first" <|
            \_ ->
                Form.rejected [ Form.problem f.name "First", Form.problem f.name "Second" ] form filled
                    |> Tuple.first
                    |> (\state -> Form.textInput (bound state) f.name [])
                    |> showsText "First"
        ]


visibility : Test
visibility =
    describe "when a problem shows"
        [ test "a required field is quiet before the user has been there" <|
            \_ ->
                Form.textInput (bound (Form.init form)) f.name [] |> hidesText "Required"
        , test "typing alone does not show the problem of a text yet" <|
            \_ ->
                typeName "x" filled
                    |> typeName ""
                    |> (\state -> Form.textInput (bound state) f.name [])
                    |> hidesText "Required"
        , test "a text shows its problem once it is left, and from then on follows every keystroke" <|
            \_ ->
                let
                    left =
                        typeName "" filled |> leaveName
                in
                Expect.all
                    [ \_ -> Form.textInput (bound left) f.name [] |> showsText "Required"
                    , \_ -> Form.textInput (bound (typeName "a very long name" left)) f.name [] |> showsText "Must be at most 10 characters"
                    , \_ -> Form.textInput (bound (typeName "Acme" left)) f.name [] |> hidesText "Required"
                    ]
                    ()
        , test "reveal shows the problems of every field" <|
            \_ ->
                let
                    state =
                        Form.reveal form (Form.init form) |> Tuple.first
                in
                Expect.all
                    [ \_ -> Form.textInput (bound state) f.name [] |> showsText "Required"
                    , \_ -> Form.select (bound state) f.country countries [] |> showsText "Required"
                    , \_ -> Form.summary (bound state) |> showsText "Choose at least 1"
                    ]
                    ()
        , test "the summary is empty while nothing shows" <|
            \_ ->
                Form.summary (bound (Form.init form))
                    |> Query.fromHtml
                    |> Query.hasNot [ Selector.text "Required" ]
        , test "a number outside the range shows after the user typed it and left the field" <|
            \_ ->
                typeAge "17" filled
                    |> fire (\v -> Form.numberInput v f.age []) Event.blur
                    |> (\state -> Form.numberInput (bound state) f.age [])
                    |> showsText "Must be between 18 and 99"
        ]


everythingShowing : Test
everythingShowing =
    let
        withServer =
            Form.rejected [ Form.problem f.name "Already taken" ] form filled |> Tuple.first

        priceRule =
            { field = "price-rule-1", label = "Price rule 1", message = "Add a condition.", step = Nothing }

        summed state =
            Form.summary (bound state)

        labelled state =
            Form.problems Locale.en form state |> List.map (\p -> ( p.label, p.message ))
    in
    describe "the problems that are showing"
        [ test "a valid form has no problems" <|
            \_ -> ( Form.problems Locale.en form filled, Form.hasProblems form filled ) |> Expect.equal ( [], False )
        , test "problems carry the label of the declaration, in declaration order" <|
            \_ ->
                Form.problems Locale.en form (Form.init form)
                    |> List.map (\p -> ( p.label, p.message ))
                    |> Expect.equal
                        [ ( "Name", "Required" )
                        , ( "Age", "Required" )
                        , ( "Country", "Required" )
                        , ( "Categories", "Choose at least 1" )
                        ]
        , test "a server problem is a problem until its field is edited" <|
            \_ ->
                Expect.all
                    [ \_ -> labelled withServer |> Expect.equal [ ( "Name", "Already taken" ) ]
                    , \_ -> Form.hasProblems form withServer |> Expect.equal True
                    , \_ -> labelled (typeName "Acme 2" withServer) |> Expect.equal []
                    ]
                    ()
        , test "toValues does not produce a record while a server problem stands" <|
            \_ ->
                ( Form.toValues Locale.en form withServer |> Result.map (always ())
                , Form.toValues Locale.en form (typeName "Acme 2" withServer) |> Result.map (always ())
                )
                    |> Expect.equal ( Err [ Form.problem f.name "Already taken" ], Ok () )
        , test "a client problem of the field comes before the server's" <|
            \_ ->
                labelled (Form.set f.name "A very long name" withServer)
                    |> Expect.equal [ ( "Name", "Must be at most 10 characters" ) ]
        , test "a problem from outside counts, and is replaced by the next list" <|
            \_ ->
                let
                    withRule =
                        Form.outside form [ priceRule ] filled
                in
                Expect.all
                    [ \_ -> labelled withRule |> Expect.equal [ ( "Price rule 1", "Add a condition." ) ]
                    , \_ -> Form.hasProblems form withRule |> Expect.equal True
                    , \_ -> Form.toValues Locale.en form withRule |> Result.map (always ()) |> Expect.equal (Err [ priceRule ])
                    , \_ -> labelled (Form.outside form [] withRule) |> Expect.equal []
                    ]
                    ()
        , test "a problem from outside is quiet until the problems are revealed" <|
            \_ ->
                let
                    withRule =
                        Form.outside form [ priceRule ] filled
                in
                Expect.all
                    [ \_ -> summed withRule |> hidesText "Add a condition."
                    , \_ -> summed (Form.reveal form withRule |> Tuple.first) |> showsText "Price rule 1: Add a condition."
                    ]
                    ()
        , test "rejected stores the problems of a form that is not on screen" <|
            \_ ->
                -- nothing is drawn: the state alone holds them, and the focus command is harmless
                Form.rejected [ Form.problem f.name "Already taken", Form.problem f.website "No" ] form filled
                    |> Tuple.first
                    |> labelled
                    |> Expect.equal [ ( "Name", "Already taken" ), ( "Website", "No" ) ]
        , test "a problem the form does not know is ignored" <|
            \_ ->
                Form.rejected [ { field = "elsewhere", label = "?", message = "x", step = Nothing } ] form filled
                    |> Tuple.first
                    |> labelled
                    |> Expect.equal []
        ]


type alias DocFields =
    { note : Form.Field String
    , certifications : Form.Field (List String)
    , contract : Form.Field (List FileDrop.FileInfo)
    }


type alias DocValues =
    { note : Maybe String
    , certifications : List String
    , contract : FileDrop.FileInfo
    }


docForm : Form.Form () DocFields DocValues
docForm =
    Spec.define "doc" DocFields DocValues
        |> Spec.with
            (Spec.text "Note"
                |> Spec.rules [ Validate.custom (String.startsWith "ok") (\locale -> Locale.pick locale { nb = "Må starte med ok", en = "Must start with ok" }) ]
            )
        |> Spec.with (Spec.tags "Certifications" |> Spec.atLeast 1)
        |> Spec.with
            (Spec.files "Contract"
                |> Spec.one
                |> Spec.required
                |> Spec.withMessage (\_ -> "Attach the contract.")
            )
        |> Spec.build


d : DocFields
d =
    Form.fields docForm


pdf : FileDrop.FileInfo
pdf =
    { name = "contract.pdf", size = 1200, mime = "application/pdf" }


docsFilled : Form.State ()
docsFilled =
    Form.init docForm
        |> Form.set d.note "ok, signed"
        |> Form.set d.certifications [ "ISO 9001", "ISO 14001" ]
        |> Form.set d.contract [ pdf ]
        |> Form.markClean


docView : Form.State () -> Form.View Form.Msg
docView state =
    Form.bind Locale.en identity docForm state


tagsAndFiles : Test
tagsAndFiles =
    describe "tags, files and long text"
        [ test "an empty optional text passes every rule, also a custom one" <|
            \_ ->
                Form.problems Locale.en docForm (Form.init docForm)
                    |> List.map (\p -> ( p.label, p.message ))
                    |> Expect.equal [ ( "Certifications", "Add at least 1" ), ( "Contract", "Attach the contract." ) ]
        , test "a filled text still meets the rule" <|
            \_ ->
                Form.problems Locale.en docForm (Form.set d.note "not ok" docsFilled)
                    |> List.map (\p -> ( p.label, p.message ))
                    |> Expect.equal [ ( "Note", "Must start with ok" ) ]
        , test "tags and a single file come out as a list and a file" <|
            \_ ->
                Form.toValues Locale.en docForm docsFilled
                    |> Expect.equal (Ok { note = Just "ok, signed", certifications = [ "ISO 9001", "ISO 14001" ], contract = pdf })
        , test "the round trip keeps the tags in order and the file" <|
            \_ ->
                let
                    docSample =
                        { note = Just "ok", certifications = [ "B", "A" ], contract = pdf }

                    fillDoc v =
                        Form.set d.note (Maybe.withDefault "" v.note)
                            >> Form.set d.certifications v.certifications
                            >> Form.set d.contract [ v.contract ]
                in
                Check.roundTrip docForm fillDoc docSample |> Expect.equal (Ok docSample)
        , test "two files are refused by one" <|
            \_ ->
                Form.problems Locale.en docForm (Form.set d.contract [ pdf, { pdf | name = "other.pdf" } ] docsFilled)
                    |> List.map .message
                    |> Expect.equal [ "Only one is allowed" ]
        , test "changing the tags or the file makes the form dirty, putting them back makes it clean" <|
            \_ ->
                ( Form.set d.certifications [ "ISO 9001" ] docsFilled |> Form.isDirty
                , Form.set d.contract [] docsFilled |> Form.isDirty
                , Form.set d.certifications [ "ISO 9001", "ISO 14001" ] docsFilled |> Form.isDirty
                )
                    |> Expect.equal ( True, True, False )
        , test "removing a chip with the mouse edits the field and shows its problem" <|
            \_ ->
                let
                    one =
                        Form.set d.certifications [ "ISO 9001" ] docsFilled

                    removed =
                        Form.tagInput (docView one) d.certifications []
                            |> Query.fromHtml
                            |> Query.find [ Selector.tag "button" ]
                            |> Event.simulate Event.click
                            |> Event.toResult
                            |> Result.map (\msg -> Form.update docForm msg one |> Tuple.first)
                            |> Result.withDefault one
                in
                Expect.all
                    [ \_ -> Form.get d.certifications removed |> Expect.equal []
                    , \_ -> Form.isDirty removed |> Expect.equal True
                    , \_ -> Form.tagInput (docView removed) d.certifications [] |> showsText "Add at least 1"
                    ]
                    ()
        , test "the problems of tags and files are in the summary once revealed" <|
            \_ ->
                let
                    revealed =
                        Form.reveal docForm (Form.init docForm) |> Tuple.first
                in
                Expect.all
                    [ \_ -> Form.summary (docView revealed) |> showsText "Certifications: Add at least 1"
                    , \_ -> Form.summary (docView revealed) |> showsText "Contract: Attach the contract."
                    , \_ -> Form.fileDrop (docView revealed) d.contract [] |> showsText "Attach the contract."
                    ]
                    ()
        , test "a server problem on the file shows at the drop zone" <|
            \_ ->
                Form.rejected [ Form.problem d.contract "The file is damaged." ] docForm docsFilled
                    |> Tuple.first
                    |> (\state -> Form.fileDrop (docView state) d.contract [])
                    |> showsText "The file is damaged."
        , test "a text area is drawn from a text handle, with the label and the error" <|
            \_ ->
                let
                    bad =
                        Form.set d.note "no" docsFilled |> Form.reveal docForm |> Tuple.first
                in
                Form.textArea (docView bad) d.note [ TextArea.rows 4 ]
                    |> Query.fromHtml
                    |> Query.has [ Selector.tag "textarea", Selector.id "doc-note" ]
        , test "a text area reports what is typed" <|
            \_ ->
                Form.textArea (docView docsFilled) d.note []
                    |> Query.fromHtml
                    |> Query.find [ Selector.tag "textarea" ]
                    |> Event.simulate (Event.input "ok, changed")
                    |> Event.toResult
                    |> Result.map (\msg -> Form.update docForm msg docsFilled |> Tuple.first |> Form.get d.note)
                    |> Expect.equal (Ok "ok, changed")
        ]


type Category
    = Perishables
    | Machinery


categoryIdsForRules : Ids Category
categoryIdsForRules =
    Ids.make
        { toKey =
            \category ->
                case category of
                    Perishables ->
                        "perishables"

                    Machinery ->
                        "machinery"
        , fromKey =
            \key ->
                case key of
                    "perishables" ->
                        Just Perishables

                    "machinery" ->
                        Just Machinery

                    _ ->
                        Nothing
        }


idsInRules : Test
idsInRules =
    let
        options =
            [ Select.option Perishables "Perishables", Select.option Machinery "Machinery" ]

        field =
            Rule.choiceFieldOf categoryIdsForRules "category" "Category" options .category
    in
    describe "one Ids for the form and the rule builder"
        [ test "the choices of a rule field are the options, written with the same keys" <|
            \_ ->
                Rule.fieldKind field
                    |> Expect.equal (Rule.choiceKind [ { value = "perishables", label = "Perishables" }, { value = "machinery", label = "Machinery" } ])
        , test "a row is matched by its typed id" <|
            \_ ->
                let
                    today =
                        Date.fromEpochDay 0

                    condition =
                        Rule.ConditionRule { id = 1, field = "category", operator = Rule.Is, values = [ "machinery" ] }
                in
                ( Rule.matches today [ field ] condition { category = Just Machinery }
                , Rule.matches today [ field ] condition { category = Nothing }
                )
                    |> Expect.equal ( True, False )
        , test "the same Ids pass the check for the form" <|
            \_ -> Check.lostIds categoryIdsForRules [ Perishables, Machinery ] |> Expect.equal []
        ]


docExample : Test
docExample =
    describe "the example of the module documentation"
        [ test "it starts clean, with nothing to show" <|
            \_ -> Form.isDirty FormDocExample.init.form |> Expect.equal False
        ]


mapOptionTest : Test
mapOptionTest =
    test "Select.mapOption changes the value and keeps label, group, description, keywords and disabled" <|
        \_ ->
            Select.option 7 "Contoso"
                |> Select.withGroup "Preferred"
                |> Select.withDescription "Berlin"
                |> Select.withKeywords [ "ctso" ]
                |> Select.disabledOption
                |> Select.mapOption String.fromInt
                |> Expect.equal
                    (Select.option "7" "Contoso"
                        |> Select.withGroup "Preferred"
                        |> Select.withDescription "Berlin"
                        |> Select.withKeywords [ "ctso" ]
                        |> Select.disabledOption
                    )
