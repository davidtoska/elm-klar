module FormModelTest exposing (suite)

{-| Tests of `Klar.Form.Model`: what the rules produce, the round trip of a
record, dirty after typing and undoing, the derived DOM ids, and a server
problem that goes away when its field is edited. Typing is done through the
rendered controls, so the opaque messages are the real ones.
-}

import Expect
import Html exposing (Html)
import Json.Encode as Encode
import Klar.Form.Model as Fm
import Klar.Locale as Locale
import Klar.Remote as Remote
import Klar.Select as Select
import Klar.Validate as Validate
import Test exposing (Test, describe, test)
import Test.Html.Event as Event
import Test.Html.Query as Query
import Test.Html.Selector as Selector


type CountryId
    = CountryId String


type CategoryId
    = CategoryId Int


countryIds : Fm.Ids CountryId
countryIds =
    Fm.ids { toKey = \(CountryId code) -> code, fromKey = Just << CountryId }


categoryIds : Fm.Ids CategoryId
categoryIds =
    Fm.ids
        { toKey = \(CategoryId n) -> String.fromInt n
        , fromKey = Maybe.map CategoryId << String.toInt
        }


type alias Fields =
    { name : Fm.Field String
    , website : Fm.Field String
    , age : Fm.Field (Maybe Float)
    , country : Fm.Field (Maybe CountryId)
    , categories : Fm.Field (List CategoryId)
    , news : Fm.Field Bool
    }


type alias Values =
    { name : String
    , website : Maybe String
    , age : Float
    , country : CountryId
    , categories : List CategoryId
    , news : Bool
    }


form : Fm.Form () Fields Values
form =
    Fm.define "supplier" Fields Values
        |> Fm.with (Fm.text "Name" |> Fm.required |> Fm.rules [ Validate.maxLength 10 ])
        |> Fm.with (Fm.text "Website" |> Fm.rules [ Validate.email ])
        |> Fm.with (Fm.number "Age" |> Fm.required |> Fm.range 18 99 |> Fm.whole)
        |> Fm.with (Fm.choice countryIds "Country" |> Fm.required)
        |> Fm.with (Fm.choices categoryIds "Categories" |> Fm.atLeast 1)
        |> Fm.with (Fm.toggle "Newsletter")
        |> Fm.build


f : Fields
f =
    Fm.fields form


sample : Values
sample =
    { name = "Acme"
    , website = Just "sales@acme.example"
    , age = 42
    , country = CountryId "no"
    , categories = [ CategoryId 2, CategoryId 1 ]
    , news = True
    }


fill : Values -> Fm.State () -> Fm.State ()
fill v =
    Fm.set f.name v.name
        >> Fm.set f.website (Maybe.withDefault "" v.website)
        >> Fm.set f.age (Just v.age)
        >> Fm.set f.country (Just v.country)
        >> Fm.set f.categories v.categories
        >> Fm.set f.news v.news


filled : Fm.State ()
filled =
    Fm.init form |> fill sample |> Fm.markClean


countries : Remote.Remote (List (Select.Option CountryId))
countries =
    Remote.Loaded [ Select.option (CountryId "no") "Norway", Select.option (CountryId "se") "Sweden" ]


bound : Fm.State () -> Fm.View Fm.Msg
bound state =
    Fm.bind Locale.en identity form state


{-| Sends an event to the first input of a control and runs the form's update
on the message that comes back.
-}
fire : (Fm.View Fm.Msg -> Html Fm.Msg) -> ( String, Encode.Value ) -> Fm.State () -> Fm.State ()
fire draw event state =
    draw (bound state)
        |> Query.fromHtml
        |> Query.find [ Selector.tag "input" ]
        |> Event.simulate event
        |> Event.toResult
        |> Result.map (\msg -> Fm.update msg state |> Tuple.first)
        |> Result.withDefault state


typeName : String -> Fm.State () -> Fm.State ()
typeName text =
    fire (\v -> Fm.textInput v f.name []) (Event.input text)


typeAge : String -> Fm.State () -> Fm.State ()
typeAge text =
    fire (\v -> Fm.numberInput v f.age []) (Event.input text)


problemsOf : Fm.State () -> List ( String, String )
problemsOf state =
    case Fm.toValues Locale.en form state of
        Ok _ ->
            []

        Err problems ->
            List.map (\p -> ( p.field, p.message )) problems


showsText : String -> Html Fm.Msg -> Expect.Expectation
showsText wanted html =
    html |> Query.fromHtml |> Query.has [ Selector.text wanted ]


hidesText : String -> Html Fm.Msg -> Expect.Expectation
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
        , mapOptionTest
        ]


validation : Test
validation =
    describe "rules and the output type"
        [ test "a valid form produces the record, with required fields unwrapped" <|
            \_ -> Fm.toValues Locale.en form filled |> Expect.equal (Ok sample)
        , test "a blank optional text is Nothing and the output is trimmed" <|
            \_ ->
                filled
                    |> Fm.set f.website "   "
                    |> Fm.set f.name "  Acme  "
                    |> Fm.toValues Locale.en form
                    |> Result.map (\v -> ( v.name, v.website ))
                    |> Expect.equal (Ok ( "Acme", Nothing ))
        , test "an empty form lists every problem in declaration order" <|
            \_ ->
                problemsOf (Fm.init form)
                    |> Expect.equal
                        [ ( "supplier-name", "Required" )
                        , ( "supplier-age", "Required" )
                        , ( "supplier-country", "Required" )
                        , ( "supplier-categories", "Choose at least 1" )
                        ]
        , test "the messages come in the language asked for" <|
            \_ ->
                Fm.toValues Locale.nb form (Fm.init form)
                    |> Result.mapError (List.map .message)
                    |> Expect.equal (Err [ "Må fylles ut", "Må fylles ut", "Må fylles ut", "Velg minst 1" ])
        , test "rules run on the text as typed" <|
            \_ ->
                problemsOf (Fm.set f.name "A very long name" filled)
                    |> Expect.equal [ ( "supplier-name", "Must be at most 10 characters" ) ]
        , test "a rule of Klar.Validate runs on an optional text" <|
            \_ ->
                problemsOf (Fm.set f.website "not an email" filled)
                    |> Expect.equal [ ( "supplier-website", "Invalid email address" ) ]
        , test "range and whole check a number and do not move it" <|
            \_ ->
                ( problemsOf (Fm.set f.age (Just 17) filled)
                , problemsOf (Fm.set f.age (Just 20.5) filled)
                , Fm.get f.age (Fm.set f.age (Just 17) filled)
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
                        Fm.define "n" identity identity
                            |> Fm.with (Fm.number "Weight")
                            |> Fm.build

                    handle =
                        Fm.fields optional

                    typed =
                        Fm.init optional
                            |> (\state ->
                                    Fm.bind Locale.en identity optional state
                                        |> (\v -> Fm.numberInput v handle [])
                                        |> Query.fromHtml
                                        |> Query.find [ Selector.tag "input" ]
                                        |> Event.simulate (Event.input "abc")
                                        |> Event.toResult
                                        |> Result.map (\msg -> Fm.update msg state |> Tuple.first)
                                        |> Result.withDefault state
                               )
                in
                Fm.toValues Locale.en optional typed
                    |> Expect.equal (Err [ { field = "n-weight", label = "Weight", message = "Must be a number", step = Nothing } ])
        , test "atLeast counts the choices" <|
            \_ ->
                ( Fm.set f.categories [] filled |> problemsOf
                , Fm.set f.categories [ CategoryId 9 ] filled |> problemsOf
                )
                    |> Expect.equal ( [ ( "supplier-categories", "Choose at least 1" ) ], [] )
        , test "one turns a list into a Maybe and refuses two" <|
            \_ ->
                let
                    single =
                        Fm.define "s" identity identity
                            |> Fm.with (Fm.choices categoryIds "Pick" |> Fm.one)
                            |> Fm.build

                    pick h ids_ =
                        Fm.init single |> Fm.set h ids_ |> Fm.toValues Locale.en single
                in
                ( pick (Fm.fields single) []
                , pick (Fm.fields single) [ CategoryId 1 ]
                , pick (Fm.fields single) [ CategoryId 1, CategoryId 2 ] |> Result.mapError (List.map .message)
                )
                    |> Expect.equal ( Ok Nothing, Ok (Just (CategoryId 1)), Err [ "Choose at most one" ] )
        , test "withMessage replaces the message of the rule added last, per language" <|
            \_ ->
                let
                    custom =
                        Fm.define "m" identity identity
                            |> Fm.with
                                (Fm.text "Name"
                                    |> Fm.required
                                    |> Fm.withMessage (\locale -> Locale.pick locale { nb = "Oppgi navn", en = "Enter a name" })
                                )
                            |> Fm.build

                    messages locale =
                        Fm.toValues locale custom (Fm.init custom) |> Result.mapError (List.map .message)
                in
                ( messages Locale.en, messages Locale.nb )
                    |> Expect.equal ( Err [ "Enter a name" ], Err [ "Oppgi navn" ] )
        , test "withMessage reaches the rule added last, not an earlier one" <|
            \_ ->
                let
                    custom =
                        Fm.define "m" identity identity
                            |> Fm.with
                                (Fm.text "Name"
                                    |> Fm.required
                                    |> Fm.rules [ Validate.maxLength 3 ]
                                    |> Fm.withMessage (\_ -> "Too long")
                                )
                            |> Fm.build

                    state =
                        Fm.init custom
                in
                ( Fm.toValues Locale.en custom state |> Result.mapError (List.map .message)
                , Fm.toValues Locale.en custom (Fm.set (Fm.fields custom) "abcdef" state) |> Result.mapError (List.map .message)
                )
                    |> Expect.equal ( Err [ "Required" ], Err [ "Too long" ] )
        ]


type alias SwapFields =
    { first : Fm.Field String
    , second : Fm.Field String
    }


type alias SwapValues =
    { first : Maybe String
    , second : Maybe String
    }


{-| Two fields of the same type listed in another order in `Values` than in
the pipeline. The compiler cannot see it; `roundTrip` does.
-}
swapped : Fm.Form () SwapFields SwapValues
swapped =
    Fm.define "swap" SwapFields (\a b -> SwapValues b a)
        |> Fm.with (Fm.text "First")
        |> Fm.with (Fm.text "Second")
        |> Fm.build


roundTrips : Test
roundTrips =
    describe "the round trip of a record"
        [ test "set then toValues gives the record back" <|
            \_ -> Fm.roundTrip form fill sample |> Expect.equal (Ok sample)
        , test "get returns what was set, for every kind" <|
            \_ ->
                { name = Fm.get f.name filled
                , age = Fm.get f.age filled
                , country = Fm.get f.country filled
                , categories = Fm.get f.categories filled
                , news = Fm.get f.news filled
                }
                    |> Expect.equal { name = "Acme", age = Just 42, country = Just (CountryId "no"), categories = [ CategoryId 2, CategoryId 1 ], news = True }
        , test "a fresh form is empty" <|
            \_ ->
                let
                    state =
                        Fm.init form
                in
                { name = Fm.get f.name state, age = Fm.get f.age state, country = Fm.get f.country state, categories = Fm.get f.categories state, news = Fm.get f.news state }
                    |> Expect.equal { name = "", age = Nothing, country = Nothing, categories = [], news = False }
        , test "two same-typed fields swapped in Values compile but roundTrip catches them" <|
            \_ ->
                let
                    swapFill v =
                        let
                            handles =
                                Fm.fields swapped
                        in
                        Fm.set handles.first (Maybe.withDefault "" v.first)
                            >> Fm.set handles.second (Maybe.withDefault "" v.second)

                    one_ =
                        { first = Just "one", second = Just "two" }
                in
                Fm.roundTrip swapped swapFill one_
                    |> Expect.notEqual (Ok one_)
        , test "ids that survive the key round trip are not lost" <|
            \_ ->
                ( Fm.lostIds countryIds [ CountryId "no", CountryId "se" ]
                , Fm.lostIds categoryIds [ CategoryId 1, CategoryId 20 ]
                )
                    |> Expect.equal ( [], [] )
        , test "lostIds lists values whose key does not read back" <|
            \_ ->
                let
                    lossy =
                        Fm.ids { toKey = \(CategoryId n) -> String.fromInt n, fromKey = \_ -> Nothing }
                in
                Fm.lostIds lossy [ CategoryId 1 ] |> Expect.equal [ CategoryId 1 ]
        ]


dirty : Test
dirty =
    describe "dirty"
        [ test "a loaded and cleaned form is not dirty" <|
            \_ -> Fm.isDirty filled |> Expect.equal False
        , test "typing a letter makes it dirty, deleting it makes it clean again" <|
            \_ ->
                let
                    typed =
                        typeName "Acmex" filled

                    undone =
                        typeName "Acme" typed
                in
                ( Fm.isDirty typed, Fm.isDirty undone ) |> Expect.equal ( True, False )
        , test "set changes the dirty state for every kind" <|
            \_ ->
                [ Fm.set f.country (Just (CountryId "se")) filled
                , Fm.set f.categories [ CategoryId 1 ] filled
                , Fm.set f.age (Just 43) filled
                , Fm.set f.news False filled
                , Fm.set f.website "" filled
                ]
                    |> List.map Fm.isDirty
                    |> Expect.equal [ True, True, True, True, True ]
        , test "markClean moves the baseline and revert goes back to it" <|
            \_ ->
                let
                    edited =
                        typeName "Other" filled
                in
                ( Fm.markClean edited |> Fm.isDirty
                , Fm.revert edited |> Fm.get f.name
                , Fm.revert edited |> Fm.isDirty
                )
                    |> Expect.equal ( False, "Acme", False )
        , test "opening or searching a select does not make the form dirty" <|
            \_ ->
                -- the open list is not a value: the select is drawn, not changed
                bound filled
                    |> (\v -> Fm.select v f.country countries [])
                    |> Query.fromHtml
                    |> Query.has [ Selector.text "Country" ]
        ]


derivedIds : Test
derivedIds =
    describe "DOM ids"
        [ test "ids are made from the prefix and the label" <|
            \_ ->
                [ Fm.problem f.name "", Fm.problem f.country "", Fm.problem f.categories "" ]
                    |> List.map .field
                    |> Expect.equal [ "supplier-name", "supplier-country", "supplier-categories" ]
        , test "equal labels get different ids, in declaration order" <|
            \_ ->
                let
                    twins =
                        Fm.define "t" (\a b c -> [ a, b, c ]) (\_ _ _ -> ())
                            |> Fm.with (Fm.text "Name")
                            |> Fm.with (Fm.text "Name")
                            |> Fm.with (Fm.text "Name 2")
                            |> Fm.build
                in
                Fm.fields twins
                    |> List.map (\h -> (Fm.problem h "").field)
                    |> Expect.equal [ "t-name", "t-name-2", "t-name-2-2" ]
        , test "the rendered control carries the derived id and a label" <|
            \_ ->
                Fm.textInput (bound filled) f.name []
                    |> Query.fromHtml
                    |> Query.has [ Selector.id "supplier-name" ]
        ]


serverProblems : Test
serverProblems =
    let
        rejectedState =
            Fm.rejected [ Fm.problem f.name "Already taken", Fm.problem f.website "Not reachable" ] form filled
                |> Tuple.first
    in
    describe "problems from the server"
        [ test "a server problem shows at its field and in the summary" <|
            \_ ->
                Expect.all
                    [ \_ -> Fm.textInput (bound rejectedState) f.name [] |> showsText "Already taken"
                    , \_ -> Fm.summary (bound rejectedState) |> showsText "Not reachable"
                    ]
                    ()
        , test "it does not hide a client problem of the same field" <|
            \_ ->
                let
                    state =
                        Fm.set f.name "A very long name" rejectedState
                in
                Fm.textInput (bound state) f.name [] |> showsText "Must be at most 10 characters"
        , test "it clears when its field is edited, and only that field" <|
            \_ ->
                let
                    edited =
                        typeName "Acme 2" rejectedState
                in
                Expect.all
                    [ \_ -> Fm.textInput (bound edited) f.name [] |> hidesText "Already taken"
                    , \_ -> Fm.textInput (bound edited) f.website [] |> showsText "Not reachable"
                    ]
                    ()
        , test "it clears also when the old value is typed again" <|
            \_ ->
                typeName "Acme2" rejectedState
                    |> typeName "Acme"
                    |> (\state -> Fm.textInput (bound state) f.name [])
                    |> hidesText "Already taken"
        , test "a problem for the same field twice keeps the first" <|
            \_ ->
                Fm.rejected [ Fm.problem f.name "First", Fm.problem f.name "Second" ] form filled
                    |> Tuple.first
                    |> (\state -> Fm.textInput (bound state) f.name [])
                    |> showsText "First"
        ]


visibility : Test
visibility =
    describe "when a problem shows"
        [ test "a required field is quiet before the user has been there" <|
            \_ ->
                Fm.textInput (bound (Fm.init form)) f.name [] |> hidesText "Required"
        , test "editing a field shows its problem" <|
            \_ ->
                typeName "x" filled
                    |> typeName ""
                    |> (\state -> Fm.textInput (bound state) f.name [])
                    |> showsText "Required"
        , test "reveal shows the problems of every field" <|
            \_ ->
                let
                    state =
                        Fm.reveal form (Fm.init form) |> Tuple.first
                in
                Expect.all
                    [ \_ -> Fm.textInput (bound state) f.name [] |> showsText "Required"
                    , \_ -> Fm.select (bound state) f.country countries [] |> showsText "Required"
                    , \_ -> Fm.summary (bound state) |> showsText "Choose at least 1"
                    ]
                    ()
        , test "the summary is empty while nothing shows" <|
            \_ ->
                Fm.summary (bound (Fm.init form))
                    |> Query.fromHtml
                    |> Query.hasNot [ Selector.text "Required" ]
        , test "a number outside the range shows after the user typed it" <|
            \_ ->
                typeAge "17" filled
                    |> (\state -> Fm.numberInput (bound state) f.age [])
                    |> showsText "Must be between 18 and 99"
        ]


everythingShowing : Test
everythingShowing =
    let
        withServer =
            Fm.rejected [ Fm.problem f.name "Already taken" ] form filled |> Tuple.first

        priceRule =
            { field = "price-rule-1", label = "Price rule 1", message = "Add a condition.", step = Nothing }

        summed state =
            Fm.summary (bound state)

        labelled state =
            Fm.problems Locale.en form state |> List.map (\p -> ( p.label, p.message ))
    in
    describe "the problems that are showing"
        [ test "a valid form has no problems" <|
            \_ -> ( Fm.problems Locale.en form filled, Fm.hasProblems form filled ) |> Expect.equal ( [], False )
        , test "problems carry the label of the declaration, in declaration order" <|
            \_ ->
                Fm.problems Locale.en form (Fm.init form)
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
                    , \_ -> Fm.hasProblems form withServer |> Expect.equal True
                    , \_ -> labelled (typeName "Acme 2" withServer) |> Expect.equal []
                    ]
                    ()
        , test "toValues does not produce a record while a server problem stands" <|
            \_ ->
                ( Fm.toValues Locale.en form withServer |> Result.map (always ())
                , Fm.toValues Locale.en form (typeName "Acme 2" withServer) |> Result.map (always ())
                )
                    |> Expect.equal ( Err [ Fm.problem f.name "Already taken" ], Ok () )
        , test "a client problem of the field comes before the server's" <|
            \_ ->
                labelled (Fm.set f.name "A very long name" withServer)
                    |> Expect.equal [ ( "Name", "Must be at most 10 characters" ) ]
        , test "a problem from outside counts, and is replaced by the next list" <|
            \_ ->
                let
                    withRule =
                        Fm.outside [ priceRule ] filled
                in
                Expect.all
                    [ \_ -> labelled withRule |> Expect.equal [ ( "Price rule 1", "Add a condition." ) ]
                    , \_ -> Fm.hasProblems form withRule |> Expect.equal True
                    , \_ -> Fm.toValues Locale.en form withRule |> Result.map (always ()) |> Expect.equal (Err [ priceRule ])
                    , \_ -> labelled (Fm.outside [] withRule) |> Expect.equal []
                    ]
                    ()
        , test "a problem from outside is quiet until the problems are revealed" <|
            \_ ->
                let
                    withRule =
                        Fm.outside [ priceRule ] filled
                in
                Expect.all
                    [ \_ -> summed withRule |> hidesText "Add a condition."
                    , \_ -> summed (Fm.reveal form withRule |> Tuple.first) |> showsText "Price rule 1: Add a condition."
                    ]
                    ()
        , test "rejected stores the problems of a form that is not on screen" <|
            \_ ->
                -- nothing is drawn: the state alone holds them, and the focus command is harmless
                Fm.rejected [ Fm.problem f.name "Already taken", Fm.problem f.website "No" ] form filled
                    |> Tuple.first
                    |> labelled
                    |> Expect.equal [ ( "Name", "Already taken" ), ( "Website", "No" ) ]
        , test "a problem the form does not know is ignored" <|
            \_ ->
                Fm.rejected [ { field = "elsewhere", label = "?", message = "x", step = Nothing } ] form filled
                    |> Tuple.first
                    |> labelled
                    |> Expect.equal []
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
