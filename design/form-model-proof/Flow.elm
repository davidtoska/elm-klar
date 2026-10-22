module Flow exposing
    ( Effects
    , Env
    , Model
    , Msg
    , firstFocus
    , init
    , initEditing
    , isDirty
    , overlays
    , update
    , view
    )

{-| The supplier flow: five steps, used to create a supplier and to edit one.
-}

import Api
import Backend exposing (Behaviour, Db)
import Domain exposing (..)
import Html exposing (Html)
import Klar.Alert as Alert
import Klar.Button as Button
import Klar.Card as Card
import Klar.Compare as Compare
import Klar.ConfirmDialog as ConfirmDialog
import Klar.DescriptionList as DescriptionList
import Klar.FileDrop as FileDrop
import Klar.Form as Form
import Klar.Form.Layout as FormLayout
import Klar.Form.Spec as Spec
import Klar.Icon as Icon
import Klar.Layout as Layout
import Klar.Locale as Locale
import Klar.MultiSelect as MultiSelect
import Klar.NumberInput as NumberInput
import Klar.Overlay exposing (Overlay)
import Klar.PageHeader as PageHeader
import Klar.Remote as Remote exposing (Remote)
import Klar.Rule as Rule
import Klar.RuleBuilder as RuleBuilder
import Klar.Select as Select
import Klar.Stepper as Stepper
import Klar.TagInput as TagInput
import Klar.Text as Text
import Klar.TextArea as TextArea
import Klar.TextInput as TextInput
import Klar.Theme exposing (Tone(..))
import Klar.Validate as Validate



-- THE FORM


type Step
    = Company
    | Contacts
    | Delivery
    | Pricing
    | Review


type alias ContactFields =
    { name : Form.Field String
    , email : Form.Field String
    , phone : Form.Field String
    , role : Form.Field (Maybe ContactRole)
    }


contactForm : Form.Form () ContactFields Contact
contactForm =
    Spec.define "contact" ContactFields Contact
        |> Spec.with (Spec.text "Name" |> Spec.required)
        |> Spec.with (Spec.text "Email" |> Spec.required |> Spec.rules [ Validate.email ])
        |> Spec.with (Spec.text "Phone" |> Spec.rules [ Validate.phone ])
        |> Spec.with (Spec.choice contactRoleIds "Role" |> Spec.required)
        |> Spec.build


type alias Fields =
    { name : Form.Field String
    , legalName : Form.Field String
    , orgNumber : Form.Field String
    , country : Form.Field (Maybe CountryId)
    , categories : Form.Field (List CategoryId)
    , paymentTerms : Form.Field (Maybe PaymentTermsId)
    , website : Form.Field String
    , preferred : Form.Field Bool
    , certifications : Form.Field (List String)
    , contract : Form.Field (List FileDrop.FileInfo)
    , contacts : Form.Field (Form.Rows ContactFields)
    , leadTime : Form.Field (Maybe Float)
    , minimumOrder : Form.Field (Maybe Float)
    , shipsTo : Form.Field (List CountryId)
    , dropShipping : Form.Field Bool
    , notes : Form.Field String
    }


type alias Values =
    { name : String
    , legalName : Maybe String
    , orgNumber : String
    , country : CountryId
    , categories : List CategoryId
    , paymentTerms : PaymentTermsId
    , website : Maybe String
    , preferred : Bool
    , certifications : List String
    , contract : FileDrop.FileInfo
    , contacts : List Contact
    , leadTime : Float
    , minimumOrder : Maybe Float
    , shipsTo : List CountryId
    , dropShipping : Bool
    , notes : Maybe String
    }


form : Form.Form Step Fields Values
form =
    Spec.define "supplier" Fields Values
        |> Spec.step Company "Company"
        |> Spec.with (Spec.text "Name" |> Spec.required |> Spec.rules [ Validate.maxLength 80 ])
        |> Spec.with (Spec.text "Legal name" |> Spec.rules [ Validate.maxLength 120 ])
        |> Spec.with (Spec.text "Organisation number" |> Spec.required |> Spec.hint "Nine digits." |> Spec.rules [ orgNumberRule ])
        |> Spec.with (Spec.choice countryIds "Country" |> Spec.required)
        |> Spec.with (Spec.choices categoryIds "Categories" |> Spec.atLeast 1)
        |> Spec.with (Spec.choice paymentTermsIds "Payment terms" |> Spec.required)
        |> Spec.with (Spec.text "Website" |> Spec.rules [ websiteRule ])
        |> Spec.with (Spec.toggle "Preferred supplier" |> Spec.hint "Preferred suppliers are offered first on new orders.")
        |> Spec.with (Spec.tags "Certifications" |> Spec.hint "Type a name and press Enter, for example ISO 9001.")
        |> Spec.with (Spec.files "Signed contract" |> Spec.one |> Spec.required |> Spec.withMessage (\lang -> Locale.pick lang { nb = "Legg ved den signerte kontrakten", en = "Attach the signed contract." }))
        |> Spec.step Contacts "Contacts"
        |> Spec.with (Spec.rows { label = "Contacts", item = "Contact" } contactForm |> Spec.atLeast 1 |> Spec.withMessage (\lang -> Locale.pick lang { nb = "Legg til minst én kontakt", en = "Add at least one contact." }))
        |> Spec.step Delivery "Delivery terms"
        |> Spec.with (Spec.number "Lead time in days" |> Spec.required |> Spec.whole |> Spec.range 0 120)
        |> Spec.with (Spec.number "Minimum order" |> Spec.range 0 10000000)
        |> Spec.with (Spec.choices countryIds "Ships to" |> Spec.atLeast 1)
        |> Spec.with (Spec.toggle "Drop shipping" |> Spec.hint "Goods are sent straight to the customer.")
        |> Spec.with (Spec.text "Notes" |> Spec.rules [ Validate.maxLength 500 ])
        |> Spec.step Pricing "Pricing rules"
        |> Spec.step Review "Review"
        |> Spec.build


f : Fields
f =
    Form.fields form


orgNumberRule : Validate.Validator
orgNumberRule =
    Validate.custom
        (\s -> String.length s == 9 && String.all Char.isDigit s)
        { nb = "Oppgi ni sifre", en = "Enter nine digits" }


websiteRule : Validate.Validator
websiteRule =
    Validate.custom
        (\s -> String.startsWith "https://" s || String.startsWith "http://" s)
        { nb = "Adressen må starte med https://", en = "The address must start with https://" }


fill : SupplierData -> Form.State Step -> Form.State Step
fill d =
    Form.set f.name d.company.name
        >> Form.set f.legalName (Maybe.withDefault "" d.company.legalName)
        >> Form.set f.orgNumber d.company.orgNumber
        >> Form.set f.country (Just d.company.country)
        >> Form.set f.categories d.company.categories
        >> Form.set f.paymentTerms (Just d.company.paymentTerms)
        >> Form.set f.website (Maybe.withDefault "" d.company.website)
        >> Form.set f.preferred d.company.preferred
        >> Form.set f.certifications d.certifications
        >> Form.set f.contract (d.contract |> Maybe.map (\c -> [ { name = c.name, size = c.size, mime = "application/pdf" } ]) |> Maybe.withDefault [])
        >> Form.fillRows f.contacts fillContact d.contacts
        >> Form.set f.leadTime (Just d.delivery.leadTimeDays)
        >> Form.set f.minimumOrder d.delivery.minimumOrder
        >> Form.set f.shipsTo d.delivery.shipsTo
        >> Form.set f.dropShipping d.delivery.dropShipping
        >> Form.set f.notes (Maybe.withDefault "" d.delivery.notes)


fillContact : Contact -> ContactFields -> Form.State Step -> Form.State Step
fillContact c row =
    Form.set row.name c.name
        >> Form.set row.email c.email
        >> Form.set row.phone (Maybe.withDefault "" c.phone)
        >> Form.set row.role (Just c.role)


toData : Values -> List PriceRule -> SupplierData
toData v rules =
    { company =
        { name = v.name
        , legalName = v.legalName
        , orgNumber = v.orgNumber
        , country = v.country
        , categories = v.categories
        , paymentTerms = v.paymentTerms
        , website = v.website
        , preferred = v.preferred
        }
    , contacts = v.contacts
    , delivery =
        { leadTimeDays = v.leadTime
        , minimumOrder = v.minimumOrder
        , shipsTo = v.shipsTo
        , dropShipping = v.dropShipping
        , notes = v.notes
        }
    , priceRules = rules
    , certifications = v.certifications
    , contract = Just { name = v.contract.name, size = v.contract.size }
    }


{-| What the server refused, tied to the fields of the form. A contact is named
by its position in the list that was sent.
-}
fromViolation : Form.State Step -> Violation -> Maybe (Form.Problem Step)
fromViolation state v =
    let
        contact i pick =
            Form.rowFields f.contacts state
                |> List.drop i
                |> List.head
                |> Maybe.map (\row -> Form.problem (pick row) v.message)
    in
    case v.field of
        FName ->
            Just (Form.problem f.name v.message)

        FOrgNumber ->
            Just (Form.problem f.orgNumber v.message)

        FCountry ->
            Just (Form.problem f.country v.message)

        FCategories ->
            Just (Form.problem f.categories v.message)

        FPaymentTerms ->
            Just (Form.problem f.paymentTerms v.message)

        FWebsite ->
            Just (Form.problem f.website v.message)

        FCertifications ->
            Just (Form.problem f.certifications v.message)

        FContract ->
            Just (Form.problem f.contract v.message)

        FContactEmail i ->
            contact i .email

        FContactName i ->
            contact i .name

        FLeadTime ->
            Just (Form.problem f.leadTime v.message)

        FShipsTo ->
            Just (Form.problem f.shipsTo v.message)

        FRule _ ->
            Nothing

        FRuleDiscount _ ->
            Nothing



-- MODEL


type Mode
    = Creating
    | Editing Supplier


{-| A price rule is edited by the rule builder and a discount: the one part of
the flow that is not a field of the form model.
-}
type alias RuleRow =
    { key : Int
    , builder : RuleBuilder.State
    , discount : NumberInput.State
    }


type alias Model =
    { mode : Mode
    , baseVersion : Int
    , form : Form.State Step
    , rules : List RuleRow
    , nextRuleKey : Int
    , ruleBaseline : List ( Rule.Rule, Maybe Float )
    , ruleServer : List ( Int, String )
    , status : FormLayout.Status
    , conflict : Maybe Supplier
    , confirm : ConfirmDialog.State
    , onlyDifferences : Bool
    }


type alias Env =
    { behaviour : Behaviour
    , db : Db
    , lookups : Remote Lookups
    }


type alias Effects =
    { db : Maybe Db
    , saved : Maybe Supplier
    , reloadLookups : Bool
    }


noEffects : Effects
noEffects =
    { db = Nothing, saved = Nothing, reloadLookups = False }


locale : Locale.Locale
locale =
    Locale.default


init : Model
init =
    { mode = Creating
    , baseVersion = 0
    , form = Form.init form
    , rules = []
    , nextRuleKey = 0
    , ruleBaseline = []
    , ruleServer = []
    , status = FormLayout.Idle
    , conflict = Nothing
    , confirm = ConfirmDialog.init "confirm-load-theirs"
    , onlyDifferences = False
    }


initEditing : Supplier -> Model
initEditing supplier =
    let
        ruleRows =
            supplier.data.priceRules
                |> List.indexedMap
                    (\i r ->
                        { key = i
                        , builder = RuleBuilder.init (ruleDomId i) |> RuleBuilder.setRule r.rule
                        , discount = NumberInput.init (ruleDomId i ++ "-discount") |> NumberInput.setLimits discountLimits |> NumberInput.setValue (Just r.discountPercent)
                        }
                    )
    in
    { init
        | mode = Editing supplier
        , baseVersion = supplier.version
        , form = Form.init form |> fill supplier.data |> Form.markClean
        , rules = ruleRows
        , nextRuleKey = List.length ruleRows
        , ruleBaseline = ruleSnapshot ruleRows
    }


{-| The focus of a page that has just opened the flow.
-}
firstFocus : Cmd Msg
firstFocus =
    Form.focus f.name |> Cmd.map FormMsg


isDirty : Model -> Bool
isDirty model =
    Form.isDirty model.form || ruleSnapshot model.rules /= model.ruleBaseline


ruleSnapshot : List RuleRow -> List ( Rule.Rule, Maybe Float )
ruleSnapshot rows =
    List.map (\row -> ( RuleBuilder.rule row.builder, NumberInput.value row.discount )) rows


savedId : Model -> Maybe SupplierId
savedId model =
    case model.mode of
        Creating ->
            Nothing

        Editing s ->
            Just s.id



-- PRICE RULES


discountLimits : List (NumberInput.Attribute msg)
discountLimits =
    [ NumberInput.min 0, NumberInput.max 100 ]


ruleDomId : Int -> String
ruleDomId key =
    "price-rule-" ++ String.fromInt key


ruleFields : Remote Lookups -> List (Rule.Field ())
ruleFields lookups =
    [ Rule.choiceFieldOf categoryIds "category" "Category" (categoryOptions lookups |> Remote.withDefault []) (\_ -> Nothing)
        |> Rule.withOperators [ Rule.Is, Rule.IsNot, Rule.IsAnyOf ]
    , Rule.bareField "quantity" "Quantity" Rule.NumberKind
    , Rule.bareField "orderTotal" "Order total" Rule.NumberKind
    , Rule.choiceFieldOf countryIds "destination" "Destination country" (countryOptions lookups |> Remote.withDefault []) (\_ -> Nothing)
        |> Rule.withOperators [ Rule.Is, Rule.IsNot, Rule.IsAnyOf ]
    ]


discountError : RuleRow -> Maybe String
discountError row =
    case NumberInput.value row.discount of
        Nothing ->
            Just "Enter a discount between 0 and 100."

        Just n ->
            if n < 0 || n > 100 then
                Just "The discount must be between 0 and 100."

            else
                Nothing


{-| The problems of the price rules, for the form to count, list and mark on the
stepper like its own.
-}
ruleProblems : Remote Lookups -> Model -> List (Form.Problem Step)
ruleProblems lookups model =
    model.rules
        |> List.indexedMap
            (\position row ->
                let
                    rule =
                        RuleBuilder.rule row.builder

                    name =
                        "Price rule " ++ String.fromInt (position + 1)

                    problem target label message =
                        { field = target, label = label, message = message, step = Just Pricing }

                    conditions =
                        if Rule.conditionCount rule == 0 then
                            [ problem (ruleDomId row.key ++ "-discount") name "Add at least one condition." ]

                        else
                            Rule.validate locale (ruleFields lookups) rule
                                |> List.take 1
                                |> List.map (\i -> problem (ruleDomId row.key ++ "-discount") name i.message)

                    discount =
                        case ( discountError row, List.filter (\( k, _ ) -> k == row.key) model.ruleServer ) of
                            ( Just m, _ ) ->
                                [ problem (ruleDomId row.key ++ "-discount") (name ++ " discount") m ]

                            ( Nothing, ( _, m ) :: _ ) ->
                                [ problem (ruleDomId row.key ++ "-discount") (name ++ " discount") m ]

                            _ ->
                                []
                in
                conditions ++ discount
            )
        |> List.concat


priceRules : Model -> List PriceRule
priceRules model =
    model.rules
        |> List.filterMap
            (\row ->
                NumberInput.value row.discount
                    |> Maybe.map (\d -> { rule = RuleBuilder.rule row.builder, discountPercent = d })
            )



-- KLAR GAP begins: the model cannot hold the rule builder (custom editors stay out), so its problems are handed over at the end of every update


{-| The form counts the price rules as long as the application tells it what
they are: at the end of every update.
-}
sync : Remote Lookups -> Model -> Model
sync lookups model =
    { model | form = Form.outside form (ruleProblems lookups model) model.form }



-- KLAR GAP ends
-- UPDATE


type Msg
    = FormMsg Form.Msg
    | RuleBuilderMsg Int RuleBuilder.Msg
    | DiscountMsg Int NumberInput.Msg
    | AddRule
    | RemoveRule Int
    | Next
    | Back
    | GoTo Step
    | Retry
    | Replied Db (Result SaveError Supplier)
    | Overwrite
    | KeepEditing
    | AskLoadTheirs
    | LoadTheirs
    | ConfirmMsg ConfirmDialog.Msg
    | CancelConfirm
    | OnlyDifferences Bool
    | ReloadLookups
    | NoOp


update : Env -> Msg -> Model -> ( Model, Cmd Msg, Effects )
update env msg model =
    let
        ( next, cmd, effects ) =
            step env msg model
    in
    ( sync env.lookups next, cmd, effects )


step : Env -> Msg -> Model -> ( Model, Cmd Msg, Effects )
step env msg model =
    case msg of
        FormMsg inner ->
            Form.update form inner model.form |> moved model

        RuleBuilderMsg key m ->
            case List.filter (\r -> r.key == key) model.rules of
                row :: _ ->
                    let
                        ( state, cmd ) =
                            RuleBuilder.update m row.builder
                    in
                    ( { model | rules = replaceRule key { row | builder = state } model.rules }
                    , Cmd.map (RuleBuilderMsg key) cmd
                    , noEffects
                    )

                [] ->
                    ( model, Cmd.none, noEffects )

        DiscountMsg key m ->
            case List.filter (\r -> r.key == key) model.rules of
                row :: _ ->
                    let
                        ( state, cmd ) =
                            NumberInput.update m row.discount

                        changed =
                            NumberInput.value state /= NumberInput.value row.discount
                    in
                    ( { model
                        | rules = replaceRule key { row | discount = state } model.rules
                        , ruleServer =
                            if changed then
                                List.filter (\( k, _ ) -> k /= key) model.ruleServer

                            else
                                model.ruleServer
                      }
                    , Cmd.map (DiscountMsg key) cmd
                    , noEffects
                    )

                [] ->
                    ( model, Cmd.none, noEffects )

        AddRule ->
            let
                key =
                    model.nextRuleKey

                row =
                    { key = key
                    , builder =
                        RuleBuilder.init (ruleDomId key)
                            |> RuleBuilder.setRule (Rule.addCondition (ruleFields env.lookups) 0 Rule.emptyGroup)
                    , discount = NumberInput.init (ruleDomId key ++ "-discount") |> NumberInput.setLimits discountLimits
                    }
            in
            ( { model | rules = model.rules ++ [ row ], nextRuleKey = key + 1 }
            , FormLayout.focusField (ruleDomId key ++ "-discount") NoOp
            , noEffects
            )

        RemoveRule key ->
            ( { model
                | rules = List.filter (\r -> r.key /= key) model.rules
                , ruleServer = List.filter (\( k, _ ) -> k /= key) model.ruleServer
              }
            , FormLayout.focusField "add-rule" NoOp
            , noEffects
            )

        Next ->
            if model.status == FormLayout.Submitting then
                ( model, Cmd.none, noEffects )

            else
                let
                    next =
                        Form.advance form model.form
                in
                case next.submit of
                    Just values ->
                        send env model values

                    Nothing ->
                        moved model ( next.state, next.cmd )

        Back ->
            Form.back form model.form |> moved model

        GoTo target ->
            Form.goTo form target model.form |> moved model

        Retry ->
            case Form.toValues locale form model.form of
                Ok values ->
                    send env model values

                Err _ ->
                    ( model, Cmd.none, noEffects )

        Replied db result ->
            case result of
                Ok supplier ->
                    ( { model
                        | mode = Editing supplier
                        , baseVersion = supplier.version
                        , status = FormLayout.Succeeded "The supplier was saved."
                        , conflict = Nothing
                        , form = Form.markClean model.form
                        , ruleBaseline = ruleSnapshot model.rules
                        , ruleServer = []
                      }
                    , Cmd.none
                    , { noEffects | db = Just db, saved = Just supplier }
                    )

                Err (Invalid violations) ->
                    let
                        -- KLAR GAP begins: server problems on the price rules, kept by the application because the rule editor is its own
                        ruleServer =
                            violations
                                |> List.filterMap
                                    (\v ->
                                        case v.field of
                                            FRule i ->
                                                ruleKeyAt i model |> Maybe.map (\key -> ( key, v.message ))

                                            FRuleDiscount i ->
                                                ruleKeyAt i model |> Maybe.map (\key -> ( key, v.message ))

                                            _ ->
                                                Nothing
                                    )

                        -- KLAR GAP ends
                        ( rejectedForm, cmd ) =
                            Form.rejected (List.filterMap (fromViolation model.form) violations)
                                form
                                (sync env.lookups { model | ruleServer = ruleServer }).form

                        count =
                            List.length violations
                    in
                    ( { model
                        | form = rejectedForm
                        , ruleServer = ruleServer
                        , status =
                            FormLayout.Failed
                                (Remote.problem Remote.validation
                                    |> Remote.withTitle "The server did not accept the supplier"
                                    |> Remote.withDetail
                                        (String.fromInt count
                                            ++ (if count == 1 then
                                                    " field needs a change."

                                                else
                                                    " fields need a change."
                                               )
                                            ++ " Nothing you entered was lost."
                                        )
                                )
                      }
                    , Cmd.map FormMsg cmd
                    , { noEffects | db = Just db }
                    )

                Err (Conflict theirs) ->
                    ( { model | conflict = Just theirs, status = FormLayout.Idle }
                    , FormLayout.focusField "conflict-alert" NoOp
                    , { noEffects | db = Just db }
                    )

                Err (Unavailable problem) ->
                    ( { model | status = FormLayout.Failed problem }
                    , FormLayout.focusStatus formId NoOp
                    , { noEffects | db = Just db }
                    )

        Overwrite ->
            case model.conflict of
                Just theirs ->
                    step env Retry { model | baseVersion = theirs.version, conflict = Nothing }

                Nothing ->
                    ( model, Cmd.none, noEffects )

        KeepEditing ->
            case model.conflict of
                Just theirs ->
                    ( { model | baseVersion = theirs.version, conflict = Nothing }
                    , FormLayout.focusField "save-supplier" NoOp
                    , noEffects
                    )

                Nothing ->
                    ( model, Cmd.none, noEffects )

        AskLoadTheirs ->
            let
                ( confirm, cmd ) =
                    ConfirmDialog.open "load-theirs" model.confirm
            in
            ( { model | confirm = confirm }, Cmd.map ConfirmMsg cmd, noEffects )

        LoadTheirs ->
            case model.conflict of
                Just theirs ->
                    let
                        ( confirm, cmd ) =
                            ConfirmDialog.close model.confirm

                        fresh =
                            initEditing theirs
                    in
                    ( { fresh | form = Form.goTo form Review fresh.form |> Tuple.first, confirm = confirm }
                    , Cmd.map ConfirmMsg cmd
                    , noEffects
                    )

                Nothing ->
                    ( model, Cmd.none, noEffects )

        ConfirmMsg m ->
            let
                ( confirm, cmd ) =
                    ConfirmDialog.update m model.confirm
            in
            ( { model | confirm = confirm }, Cmd.map ConfirmMsg cmd, noEffects )

        CancelConfirm ->
            let
                ( confirm, cmd ) =
                    ConfirmDialog.close model.confirm
            in
            ( { model | confirm = confirm }, Cmd.map ConfirmMsg cmd, noEffects )

        OnlyDifferences flag ->
            ( { model | onlyDifferences = flag }, Cmd.none, noEffects )

        ReloadLookups ->
            ( model, Cmd.none, { noEffects | reloadLookups = True } )

        NoOp ->
            ( model, Cmd.none, noEffects )



-- KLAR GAP begins: the model has nothing to focus on a step whose fields it does not hold


{-| Takes the new state of the form and its command, and focuses the price rules
when the form has just moved to their step (they are not a field of the form, so
the form has nothing to focus there).
-}
moved : Model -> ( Form.State Step, Cmd Form.Msg ) -> ( Model, Cmd Msg, Effects )
moved model ( state, cmd ) =
    let
        enteredPricing =
            Form.currentStep form state == Just Pricing && Form.currentStep form model.form /= Just Pricing
    in
    ( { model | form = state }
    , Cmd.batch
        [ Cmd.map FormMsg cmd
        , if enteredPricing then
            FormLayout.focusField (firstRuleTarget model) NoOp

          else
            Cmd.none
        ]
    , noEffects
    )


firstRuleTarget : Model -> String
firstRuleTarget model =
    case model.rules of
        row :: _ ->
            ruleDomId row.key ++ "-discount"

        [] ->
            "add-rule"



-- KLAR GAP ends


send : Env -> Model -> Values -> ( Model, Cmd Msg, Effects )
send env model values =
    ( { model | status = FormLayout.Submitting, conflict = Nothing }
    , Cmd.batch
        [ Api.save env.behaviour
            env.db
            { id = savedId model, baseVersion = model.baseVersion, data = toData values (priceRules model) }
            Replied
        , FormLayout.focusStatus formId NoOp
        ]
    , noEffects
    )


ruleKeyAt : Int -> Model -> Maybe Int
ruleKeyAt i model =
    model.rules |> List.drop i |> List.head |> Maybe.map .key


replaceRule : Int -> RuleRow -> List RuleRow -> List RuleRow
replaceRule key row rows =
    List.map
        (\r ->
            if r.key == key then
                row

            else
                r
        )
        rows



-- VIEW


formId : String
formId =
    "supplier-flow"


overlays : Model -> List (Overlay Msg)
overlays model =
    [ ConfirmDialog.view ConfirmMsg
        [ ConfirmDialog.title "Load their version?"
        , ConfirmDialog.message "Your changes in this form are replaced by the version someone else saved. This cannot be undone."
        , ConfirmDialog.danger
        , ConfirmDialog.confirmLabel "Discard my changes and load theirs"
        , ConfirmDialog.cancelLabel "Keep my changes"
        , ConfirmDialog.onConfirm LoadTheirs
        , ConfirmDialog.onCancel CancelConfirm
        ]
        model.confirm
    ]


view : Remote Lookups -> Model -> Html Msg
view lookups model =
    let
        v =
            Form.bind locale FormMsg form model.form

        title =
            case model.mode of
                Creating ->
                    "New supplier"

                Editing s ->
                    "Edit " ++ s.data.company.name

        current =
            Form.currentStep form model.form

        last =
            current == Just Review
    in
    Layout.stack [ Layout.gap 4 ]
        [ PageHeader.view
            [ PageHeader.title title
            , PageHeader.subtitle "Five steps. Every step is checked before you move on."
            ]
        , Form.stepper v [ Stepper.ariaLabel "Onboarding steps" ]
        , FormLayout.view [ FormLayout.id formId, FormLayout.onSubmit Next, FormLayout.ariaLabel "Supplier" ]
            [ viewStep lookups model v
            , FormLayout.unsavedChanges [ FormLayout.sticky ] (isDirty model)
            , FormLayout.actions
                [ FormLayout.status [ FormLayout.id formId, FormLayout.onRetry Retry ] model.status
                , Layout.spacer
                , Button.view [ Button.href "#/suppliers" ] "Cancel"
                , if current == Just Company then
                    Html.text ""

                  else
                    Button.view [ Button.onClick Back, Button.icon Icon.arrowLeft ] "Back"
                , Button.view
                    [ Button.primary
                    , Button.submit
                    , Button.id "save-supplier"
                    , Button.loading (model.status == FormLayout.Submitting)
                    , Button.iconRight
                        (if last then
                            Icon.save

                         else
                            Icon.arrowRight
                        )
                    ]
                    (if last then
                        "Save supplier"

                     else
                        "Next"
                    )
                ]
            ]
        ]


viewStep : Remote Lookups -> Model -> Form.View Msg -> Html Msg
viewStep lookups model v =
    case Form.currentStep form model.form of
        Just Company ->
            viewCompany lookups v

        Just Contacts ->
            viewContacts model v

        Just Delivery ->
            viewDelivery lookups v

        Just Pricing ->
            viewPricing lookups model v

        _ ->
            viewReview lookups model v


countryOptions : Remote Lookups -> Remote (List (Select.Option CountryId))
countryOptions =
    Remote.map (.countries >> List.map (\c -> Select.option c.id c.name))


categoryOptions : Remote Lookups -> Remote (List (Select.Option CategoryId))
categoryOptions =
    Remote.map (.categories >> List.map (\c -> Select.option c.id c.name))


termsOptions : Remote Lookups -> Remote (List (Select.Option PaymentTermsId))
termsOptions =
    Remote.map (.paymentTerms >> List.map (\c -> Select.option c.id c.name))


viewCompany : Remote Lookups -> Form.View Msg -> Html Msg
viewCompany lookups v =
    Layout.stack [ Layout.gap 4 ]
        [ Form.summary v
        , FormLayout.section "Company"
            "Who the supplier is."
            [ FormLayout.grid 2
                [ Form.textInput v f.name []
                , Form.textInput v f.legalName []
                , Form.textInput v f.orgNumber [ TextInput.inputMode "numeric" ]
                , Form.textInput v f.website [ TextInput.url, TextInput.placeholder "https://" ]
                ]
            ]
        , FormLayout.section "Business"
            "Where it is registered and what it sells."
            [ FormLayout.grid 2
                [ Form.select v f.country (countryOptions lookups) [ Select.onRetry ReloadLookups, Select.placeholder "Choose a country" ]
                , Form.select v f.paymentTerms (termsOptions lookups) [ Select.onRetry ReloadLookups ]
                , FormLayout.fullRow (Form.multiSelect v f.categories (categoryOptions lookups) [ MultiSelect.onRetry ReloadLookups ])
                , FormLayout.fullRow (Form.switch v f.preferred [])
                ]
            ]
        , FormLayout.section "Certifications and contract"
            "Certificates the supplier holds, and the signed agreement."
            [ Form.tagInput v f.certifications [ TagInput.delimiters [ ',', ';' ], TagInput.maxTags 8 ]
            , Form.fileDrop v f.contract [ FileDrop.accept [ ".pdf" ], FileDrop.maxSize 5000000, FileDrop.maxFiles 1 ]
            ]
        ]


viewContacts : Model -> Form.View Msg -> Html Msg
viewContacts model v =
    let
        card i row =
            Card.view
                [ Card.headingLevel 2
                , Card.title ("Contact " ++ String.fromInt (i + 1))
                , Card.actions [ Form.removeRow v f.contacts i [] ]
                ]
                [ FormLayout.grid 2
                    [ Form.textInput v row.name []
                    , Form.textInput v row.email [ TextInput.email ]
                    , Form.textInput v row.phone [ TextInput.tel ]
                    , Form.select v row.role (Remote.Loaded (List.map (\role -> Select.option role (contactRoleLabel role)) contactRoles)) []
                    ]
                ]
    in
    Layout.stack [ Layout.gap 4 ]
        (Form.summary v
            :: List.indexedMap card (Form.rowFields f.contacts model.form)
            ++ [ Form.addRow v f.contacts [] "Add contact" ]
        )


viewDelivery : Remote Lookups -> Form.View Msg -> Html Msg
viewDelivery lookups v =
    Layout.stack [ Layout.gap 4 ]
        [ Form.summary v
        , FormLayout.section "Delivery terms"
            "How fast, how much and where."
            [ FormLayout.grid 2
                [ Form.numberInput v f.leadTime [ NumberInput.suffixText "days" ]
                , Form.numberInput v f.minimumOrder [ NumberInput.prefixText "NOK", NumberInput.grouped ]
                , FormLayout.fullRow (Form.multiSelect v f.shipsTo (countryOptions lookups) [ MultiSelect.onRetry ReloadLookups ])
                , FormLayout.fullRow (Form.switch v f.dropShipping [])
                , FormLayout.fullRow (Form.textArea v f.notes [ TextArea.rows 3 ])
                ]
            ]
        ]


viewPricing : Remote Lookups -> Model -> Form.View Msg -> Html Msg
viewPricing lookups model v =
    let
        fields =
            ruleFields lookups

        tried =
            Form.attempted form Pricing model.form

        row index r =
            let
                builder =
                    if tried then
                        RuleBuilder.showIssues r.builder

                    else
                        r.builder

                rule =
                    RuleBuilder.rule r.builder

                discount =
                    NumberInput.value r.discount

                problem =
                    case ( tried, discountError r ) of
                        ( True, Just m ) ->
                            Just m

                        _ ->
                            List.filter (\( k, _ ) -> k == r.key) model.ruleServer
                                |> List.head
                                |> Maybe.map Tuple.second
            in
            Card.view
                [ Card.headingLevel 2
                , Card.title ("Price rule " ++ String.fromInt (index + 1))
                , Card.actions
                    [ Button.iconOnly
                        [ Button.ghost, Button.onClick (RemoveRule r.key) ]
                        Icon.trash
                        ("Remove price rule " ++ String.fromInt (index + 1))
                    ]
                , Card.footer
                    (Text.paragraph
                        ("If "
                            ++ String.toLower (Rule.describe locale fields rule)
                            ++ ", the discount is "
                            ++ (discount |> Maybe.map (\d -> String.fromFloat d ++ "%") |> Maybe.withDefault "not set")
                            ++ "."
                        )
                    )
                ]
                [ Layout.stack [ Layout.gap 3 ]
                    [ RuleBuilder.view (RuleBuilderMsg r.key)
                        [ RuleBuilder.fields fields
                        , RuleBuilder.label ("Condition of price rule " ++ String.fromInt (index + 1))
                        , RuleBuilder.maxDepth 2
                        ]
                        builder
                    , NumberInput.view (DiscountMsg r.key)
                        [ NumberInput.label "Discount"
                        , NumberInput.suffixText "%"
                        , NumberInput.min 0
                        , NumberInput.max 100
                        , NumberInput.required
                        , NumberInput.errorMaybe problem
                        ]
                        r.discount
                    ]
                ]
    in
    Layout.stack [ Layout.gap 4 ]
        (Form.summary v
            :: Text.paragraph "A rule says: if the order matches these conditions, this discount applies."
            :: List.indexedMap row model.rules
            ++ [ Layout.row [] [ Button.view [ Button.id "add-rule", Button.icon Icon.plus, Button.onClick AddRule ] "Add price rule" ] ]
        )


viewReview : Remote Lookups -> Model -> Form.View Msg -> Html Msg
viewReview lookups model v =
    let
        names =
            Remote.withDefault { countries = [], categories = [], paymentTerms = [] } lookups

        nameOf all id =
            all |> List.filter (\c -> c.id == id) |> List.head |> Maybe.map .name

        countryName id =
            nameOf names.countries id |> Maybe.withDefault (countryKey id)

        categoryName id =
            nameOf names.categories id |> Maybe.withDefault (categoryKey id)

        termsName id =
            nameOf names.paymentTerms id |> Maybe.withDefault (paymentTermsKey id)

        section target cardTitle items =
            Card.view
                [ Card.headingLevel 2
                , Card.title cardTitle
                , Card.actions [ Button.view [ Button.small, Button.onClick (GoTo target) ] "Edit" ]
                ]
                [ DescriptionList.view [ DescriptionList.columns 2, DescriptionList.compact ] items ]

        summaryOf d =
            Layout.stack [ Layout.gap 4 ]
                [ section Company
                    "Company"
                    [ DescriptionList.text "Name" d.company.name
                    , DescriptionList.maybe "Legal name" d.company.legalName
                    , DescriptionList.text "Organisation number" d.company.orgNumber
                    , DescriptionList.text "Country" (countryName d.company.country)
                    , DescriptionList.text "Categories" (d.company.categories |> List.map categoryName |> String.join ", ")
                    , DescriptionList.text "Payment terms" (termsName d.company.paymentTerms)
                    , DescriptionList.maybe "Website" d.company.website
                    , DescriptionList.text "Preferred" (yesNo d.company.preferred)
                    , DescriptionList.text "Certifications" (String.join ", " d.certifications)
                    , DescriptionList.maybe "Contract" (d.contract |> Maybe.map .name)
                    ]
                , section Contacts
                    "Contacts"
                    (d.contacts
                        |> List.map (\c -> DescriptionList.text (contactRoleLabel c.role) (c.name ++ ", " ++ c.email))
                    )
                , section Delivery
                    "Delivery terms"
                    [ DescriptionList.text "Lead time" (String.fromFloat d.delivery.leadTimeDays ++ " days")
                    , DescriptionList.maybe "Minimum order" (d.delivery.minimumOrder |> Maybe.map (\n -> "NOK " ++ String.fromFloat n))
                    , DescriptionList.text "Ships to" (d.delivery.shipsTo |> List.map countryName |> String.join ", ")
                    , DescriptionList.text "Drop shipping" (yesNo d.delivery.dropShipping)
                    , DescriptionList.maybe "Notes" d.delivery.notes
                    ]
                , section Pricing
                    "Pricing rules"
                    (if List.isEmpty d.priceRules then
                        [ DescriptionList.text "Rules" "No price rules" ]

                     else
                        d.priceRules
                            |> List.indexedMap
                                (\i r ->
                                    DescriptionList.text ("Rule " ++ String.fromInt (i + 1))
                                        ("If " ++ String.toLower (Rule.describe locale (ruleFields lookups) r.rule) ++ ": " ++ String.fromFloat r.discountPercent ++ "% off")
                                )
                    )
                ]
    in
    Layout.stack [ Layout.gap 4 ]
        [ viewConflict lookups model
        , Form.summary v
        , case buildData model of
            Just d ->
                Layout.stack [ Layout.gap 4 ]
                    [ Alert.view [ Alert.tone Success, Alert.compact ] "Everything is filled in. Read it once more, then save."
                    , summaryOf d
                    ]

            Nothing ->
                Html.text ""
        ]


buildData : Model -> Maybe SupplierData
buildData model =
    Form.toValues locale form model.form
        |> Result.toMaybe
        |> Maybe.map (\values -> toData values (priceRules model))


yesNo : Bool -> String
yesNo flag =
    if flag then
        "Yes"

    else
        "No"


type alias Side =
    { key : String, title : String, version : Int, data : SupplierData }


viewConflict : Remote Lookups -> Model -> Html Msg
viewConflict lookups model =
    case ( model.conflict, buildData model ) of
        ( Just theirs, Just mine ) ->
            let
                sides =
                    [ { key = "mine", title = "Your version", version = model.baseVersion, data = mine }
                    , { key = "theirs", title = "Saved by someone else", version = theirs.version, data = theirs.data }
                    ]

                names =
                    Remote.withDefault { countries = [], categories = [], paymentTerms = [] } lookups

                joinWith g ids =
                    ids |> List.map g |> String.join ", "

                countryName id =
                    names.countries |> List.filter (\c -> c.id == id) |> List.head |> Maybe.map .name |> Maybe.withDefault (countryKey id)

                categoryName id =
                    names.categories |> List.filter (\c -> c.id == id) |> List.head |> Maybe.map .name |> Maybe.withDefault (categoryKey id)

                termsName id =
                    names.paymentTerms |> List.filter (\c -> c.id == id) |> List.head |> Maybe.map .name |> Maybe.withDefault (paymentTermsKey id)
            in
            Alert.viewWith [ Alert.tone Warning, Alert.title "Someone else saved this supplier while you were editing" ]
                [ Layout.stack [ Layout.gap 3 ]
                    [ Text.paragraph "Nothing you entered was lost. Compare the two versions, then choose."
                    , Compare.view
                        [ Compare.baseline "mine"
                        , Compare.onlyDifferences model.onlyDifferences OnlyDifferences
                        ]
                        { label = "Your version against the saved version"
                        , records = Remote.Loaded sides
                        , id = .key
                        , toKey = identity
                        , header = \s -> Text.strong (s.title ++ " (v" ++ String.fromInt s.version ++ ")")
                        , fields =
                            [ Compare.text "Name" (.data >> .company >> .name)
                            , Compare.text "Organisation number" (.data >> .company >> .orgNumber)
                            , Compare.text "Country" (.data >> .company >> .country >> countryName)
                            , Compare.text "Categories" (.data >> .company >> .categories >> joinWith categoryName)
                            , Compare.text "Payment terms" (.data >> .company >> .paymentTerms >> termsName)
                            , Compare.text "Preferred" (.data >> .company >> .preferred >> yesNo)
                            , Compare.text "Lead time" (.data >> .delivery >> .leadTimeDays >> String.fromFloat)
                            , Compare.text "Contacts" (.data >> .contacts >> List.map .name >> String.join ", ")
                            , Compare.text "Price rules" (.data >> .priceRules >> List.length >> String.fromInt)
                            ]
                        }
                    , Layout.row [ Layout.wrap ]
                        [ Button.view [ Button.id "conflict-alert", Button.primary, Button.onClick Overwrite ] "Save mine over theirs"
                        , Button.view [ Button.onClick KeepEditing ] "Keep editing on top of theirs"
                        , Button.view [ Button.id "load-theirs", Button.danger, Button.onClick AskLoadTheirs ] "Discard mine and load theirs"
                        ]
                    ]
                ]

        _ ->
            Html.text ""
