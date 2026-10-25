module Page.Gallery.FormModel.Terms exposing (Model, Msg, init, update, view)

{-| Gallery: the kinds of `Klar.Form` on Klar's own types. A customer's terms with
a radio choice (company or private person), an organisation number that is only
there for a company (`Spec.shownWhen`, `Spec.requiredWhen`), a credit limit in
exact money with its limits, a first delivery date with an earliest day, a
contract period, and a checkbox that must be ticked.
-}

import Html exposing (Html)
import Klar.Button as Button
import Klar.Date as Date exposing (Date)
import Klar.Form as Form
import Klar.Form.Layout as FormLayout
import Klar.Form.Spec as Spec
import Klar.Ids as Ids exposing (Ids)
import Klar.Layout as Layout
import Klar.Locale as Locale exposing (Locale)
import Klar.MaskedInput as MaskedInput
import Klar.Money as Money exposing (Money)
import Klar.Radio as Radio
import Klar.Select as Select
import Klar.Text as Text
import Showcase.Config as Config
import Showcase.Options as Options


type Kind
    = Company
    | Person


kindIds : Ids Kind
kindIds =
    Ids.list
        (\kind ->
            case kind of
                Company ->
                    "company"

                Person ->
                    "person"
        )
        [ Company, Person ]


kinds : List (Select.Option Kind)
kinds =
    [ Select.option Company "Company"
    , Select.option Person "Private person" |> Select.withDescription "Pays in advance, no organisation number."
    ]


type alias Fields =
    { kind : Form.Field (Maybe Kind)
    , organisationNumber : Form.Field (Maybe String)
    , creditLimit : Form.Field (Maybe Money)
    , firstDelivery : Form.Field (Maybe Date)
    , contract : Form.Field (Maybe ( Date, Date ))
    , accepted : Form.Field Bool
    }


type alias Terms =
    { kind : Kind
    , organisationNumber : Maybe String
    , creditLimit : Money
    , firstDelivery : Date
    , contract : Maybe ( Date, Date )
    , accepted : Bool
    }


isCompany : Fields -> Form.State () -> Bool
isCompany handles state =
    Form.get handles.kind state == Just Company


form : Form.Form () Fields Terms
form =
    Spec.define "terms" Fields Terms
        |> Spec.with (Spec.choice kindIds "Customer kind" |> Spec.required)
        |> Spec.with (Spec.masked MaskedInput.norwegianOrganisationNumber "Organisation number")
        |> Spec.with
            (Spec.money Money.nok "Credit limit"
                |> Spec.required
                |> Spec.minMoney (Money.zero Money.nok)
                |> Spec.maxMoney highestCreditLimit
                |> Spec.hint "0 to 500 000 NOK."
            )
        |> Spec.with (Spec.date "First delivery" |> Spec.required |> Spec.minDate firstDeliveryDay)
        |> Spec.with (Spec.dateRange "Contract period")
        |> Spec.with
            (Spec.toggle "I accept the terms of delivery"
                |> Spec.rule identity (\lang -> Locale.pick lang { nb = "Godta vilkårene for å gå videre", en = "Accept the terms to go on" })
            )
        |> Spec.shownWhen isCompany .organisationNumber
        |> Spec.requiredWhen isCompany .organisationNumber
        |> Spec.build


f : Fields
f =
    Form.fields form


highestCreditLimit : Money
highestCreditLimit =
    Money.fromMinor Money.nok 50000000 |> Maybe.withDefault (Money.zero Money.nok)


firstDeliveryDay : Date
firstDeliveryDay =
    Date.fromParts 2026 11 2 |> Maybe.withDefault (Date.fromEpochDay 0)


type alias Model =
    { form : Form.State ()
    , saved : Maybe Terms
    }


type Msg
    = FormMsg Form.Msg
    | Save


init : Model
init =
    { form = Form.init form, saved = Nothing }


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        FormMsg inner ->
            Form.update form inner model.form |> Tuple.mapBoth (\s -> { model | form = s }) (Cmd.map FormMsg)

        Save ->
            case Form.toValues Locale.default form model.form of
                Ok terms ->
                    ( { model | form = Form.markClean model.form, saved = Just terms }, Cmd.none )

                Err _ ->
                    Form.reveal form model.form |> Tuple.mapBoth (\s -> { model | form = s }) (Cmd.map FormMsg)


view : Config.Config -> Locale -> Model -> Html Msg
view playground locale model =
    let
        v =
            Form.bind locale FormMsg form model.form
    in
    Layout.stack (Options.klarLayout playground (List.concat [ Config.keep playground "Layout" "gap" (Layout.gap 3) ]))
        [ FormLayout.view (Options.klarFormLayout playground (List.concat [ Config.keep playground "Form.Layout" "id" (FormLayout.id "terms"), Config.keep playground "Form.Layout" "onSubmit" (FormLayout.onSubmit Save) ]))
            [ Form.summary v
            , FormLayout.grid 2
                [ FormLayout.fullRow (Form.radio v f.kind kinds (Options.klarRadio playground (List.concat [ Config.keep playground "Radio" "horizontal" Radio.horizontal ])))
                , Form.maskedInput v f.organisationNumber []
                , Form.moneyInput v f.creditLimit []
                , Form.datePicker v f.firstDelivery []
                , Form.dateRangePicker v f.contract []
                , FormLayout.fullRow (Form.checkbox v f.accepted [])
                ]
            , FormLayout.actions [ Layout.spacer, Options.buttonView playground (Options.klarButton playground (List.concat [ Config.keep playground "Button" "primary" Button.primary, Config.keep playground "Button" "submit" Button.submit ])) "Save terms" ]
            ]
        , Text.caption
            (case model.saved of
                Just terms ->
                    "Saved: " ++ Money.toString locale terms.creditLimit ++ ", first delivery " ++ Date.toIso terms.firstDelivery ++ "."

                Nothing ->
                    "Nothing saved yet."
            )
        ]
