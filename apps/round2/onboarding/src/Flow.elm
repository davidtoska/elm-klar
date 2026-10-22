module Flow exposing
    ( Effects
    , Env
    , Model
    , Msg
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
import Klar.Form.Model as Fm
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
import Klar.TextInput as TextInput
import Klar.Theme exposing (Tone(..))
import Klar.Validate as Validate



-- STEPS


type Step
    = StepCompany
    | StepContacts
    | StepDelivery
    | StepPricing
    | StepReview


steps : List Step
steps =
    [ StepCompany, StepContacts, StepDelivery, StepPricing, StepReview ]


stepLabel : Step -> String
stepLabel step =
    case step of
        StepCompany ->
            "Company"

        StepContacts ->
            "Contacts"

        StepDelivery ->
            "Delivery terms"

        StepPricing ->
            "Pricing rules"

        StepReview ->
            "Review"


stepIndex : Step -> Int
stepIndex step =
    steps |> List.indexedMap Tuple.pair |> List.filter (\( _, s ) -> s == step) |> List.head |> Maybe.map Tuple.first |> Maybe.withDefault 0


stepAt : Int -> Step
stepAt i =
    steps |> List.drop i |> List.head |> Maybe.withDefault StepCompany


locale : Locale.Locale
locale =
    Locale.default



-- FORM DECLARATIONS


type alias CompanyFields =
    { name : Fm.Field String
    , legalName : Fm.Field String
    , orgNumber : Fm.Field String
    , country : Fm.Field (Maybe CountryId)
    , categories : Fm.Field (List CategoryId)
    , paymentTerms : Fm.Field (Maybe PaymentTermsId)
    , website : Fm.Field String
    , preferred : Fm.Field Bool
    }


companyForm : Fm.Form () CompanyFields Company
companyForm =
    Fm.define "company" CompanyFields Company
        |> Fm.with (Fm.text "Name" |> Fm.required |> Fm.rules [ Validate.maxLength 80 ])
        |> Fm.with (Fm.text "Legal name" |> Fm.rules [ Validate.maxLength 120 ])
        |> Fm.with
            (Fm.text "Organisation number"
                |> Fm.required
                |> Fm.hint "Nine digits."
                |> Fm.rules [ orgNumberRule ]
            )
        |> Fm.with (Fm.choice countryIds "Country" |> Fm.required)
        |> Fm.with (Fm.choices categoryIds "Categories" |> Fm.atLeast 1)
        |> Fm.with (Fm.choice paymentTermsIds "Payment terms" |> Fm.required)
        |> Fm.with (Fm.text "Website" |> Fm.rules [ websiteRule ])
        |> Fm.with (Fm.toggle "Preferred supplier" |> Fm.hint "Preferred suppliers are offered first on new orders.")
        |> Fm.build


company : CompanyFields
company =
    Fm.fields companyForm


orgNumberRule : Validate.Validator
orgNumberRule =
    Validate.custom
        (\s -> String.length s == 9 && String.all Char.isDigit s)
        { nb = "Oppgi ni sifre", en = "Enter nine digits" }


websiteRule : Validate.Validator
websiteRule =
    Validate.custom
        (\s -> String.isEmpty s || String.startsWith "https://" s || String.startsWith "http://" s)
        { nb = "Adressen må starte med https://", en = "The address must start with https://" }


type alias ContactFields =
    { name : Fm.Field String
    , email : Fm.Field String
    , phone : Fm.Field String
    , role : Fm.Field (Maybe ContactRole)
    }


contactForm : Int -> Fm.Form () ContactFields Contact
contactForm key =
    Fm.define ("contact-" ++ String.fromInt key) ContactFields Contact
        |> Fm.with (Fm.text "Name" |> Fm.required)
        |> Fm.with (Fm.text "Email" |> Fm.required |> Fm.rules [ Validate.email ])
        |> Fm.with (Fm.text "Phone" |> Fm.rules [ Validate.phone ])
        |> Fm.with (Fm.choice contactRoleIds "Role" |> Fm.required)
        |> Fm.build


type alias DeliveryFields =
    { leadTime : Fm.Field (Maybe Float)
    , minimumOrder : Fm.Field (Maybe Float)
    , shipsTo : Fm.Field (List CountryId)
    , dropShipping : Fm.Field Bool
    , notes : Fm.Field String
    }


deliveryForm : Fm.Form () DeliveryFields Delivery
deliveryForm =
    Fm.define "delivery" DeliveryFields Delivery
        |> Fm.with (Fm.number "Lead time in days" |> Fm.required |> Fm.whole |> Fm.range 0 120)
        |> Fm.with (Fm.number "Minimum order" |> Fm.range 0 10000000)
        |> Fm.with (Fm.choices countryIds "Ships to" |> Fm.atLeast 1)
        |> Fm.with (Fm.toggle "Drop shipping" |> Fm.hint "Goods are sent straight to the customer.")
        |> Fm.with (Fm.text "Notes" |> Fm.rules [ Validate.maxLength 500 ])
        |> Fm.build


delivery : DeliveryFields
delivery =
    Fm.fields deliveryForm



-- MODEL


type Mode
    = Creating
    | Editing Supplier


type alias ContactRow =
    { key : Int
    , form : Fm.State ()
    }


type alias RuleRow =
    { key : Int
    , builder : RuleBuilder.State
    , discount : NumberInput.State
    }


type alias Baseline =
    { contactKeys : List Int
    , tags : List String
    , files : List FileDrop.FileInfo
    , rules : List ( Rule.Rule, Maybe Float )
    }


type alias Model =
    { mode : Mode
    , baseVersion : Int
    , step : Step
    , tried : List Step
    , company : Fm.State ()
    , certs : TagInput.State
    , contract : FileDrop.State
    , contacts : List ContactRow
    , nextContactKey : Int
    , delivery : Fm.State ()
    , rules : List RuleRow
    , nextRuleKey : Int
    , status : Form.Status
    , certsProblem : Maybe String
    , contractProblem : Maybe String
    , ruleProblems : List ( Int, String )
    , serverIssues : List ServerIssue
    , conflict : Maybe Supplier
    , confirm : ConfirmDialog.State
    , onlyDifferences : Bool
    , baseline : Baseline
    }


-- KLAR GAP: Fm.toValues does not return server problems, so I keep my own copy (R2O-007).
-- KLAR GAP begins here and ends after `serverIssueOf`.
{-| A problem the server gave to a field of the form model, with what the field
held then: it stands until the field holds something else.
-}
type alias ServerIssue =
    { issue : Issue
    , what : Probe
    , at : String
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


discountLimits : List (NumberInput.Attribute msg)
discountLimits =
    [ NumberInput.min 0, NumberInput.max 100 ]


newContactRow : Int -> ContactRow
newContactRow key =
    { key = key, form = Fm.init (contactForm key) }


newRuleRow : Int -> RuleRow
newRuleRow key =
    { key = key
    , builder = RuleBuilder.init (ruleDomId key)
    , discount = NumberInput.init (ruleDomId key ++ "-discount") |> NumberInput.setLimits discountLimits
    }


ruleDomId : Int -> String
ruleDomId key =
    "price-rule-" ++ String.fromInt key


init : Model
init =
    rebase
        { mode = Creating
        , baseVersion = 0
        , step = StepCompany
        , tried = []
        , company = Fm.init companyForm
        , certs = TagInput.init "supplier-certifications"
        , contract = FileDrop.init "supplier-contract"
        , contacts = [ newContactRow 0 ]
        , nextContactKey = 1
        , delivery = Fm.init deliveryForm
        , rules = []
        , nextRuleKey = 0
        , status = Form.Idle
        , certsProblem = Nothing
        , contractProblem = Nothing
        , ruleProblems = []
        , serverIssues = []
        , conflict = Nothing
        , confirm = ConfirmDialog.init "confirm-load-theirs"
        , onlyDifferences = False
        , baseline = { contactKeys = [], tags = [], files = [], rules = [] }
        }


initEditing : Supplier -> Model
initEditing supplier =
    let
        data =
            supplier.data

        c =
            data.company

        d =
            data.delivery

        contactRows =
            data.contacts
                |> List.indexedMap
                    (\i contact ->
                        let
                            f =
                                Fm.fields (contactForm i)
                        in
                        { key = i
                        , form =
                            Fm.init (contactForm i)
                                |> Fm.set f.name contact.name
                                |> Fm.set f.email contact.email
                                |> Fm.set f.phone (Maybe.withDefault "" contact.phone)
                                |> Fm.set f.role (Just contact.role)
                        }
                    )

        ruleRows =
            data.priceRules
                |> List.indexedMap
                    (\i r ->
                        { key = i
                        , builder = RuleBuilder.init (ruleDomId i) |> RuleBuilder.setRule r.rule
                        , discount = NumberInput.init (ruleDomId i ++ "-discount") |> NumberInput.setLimits discountLimits |> NumberInput.setValue (Just r.discountPercent)
                        }
                    )
    in
    rebase
        { init
            | mode = Editing supplier
            , baseVersion = supplier.version
            , company =
                Fm.init companyForm
                    |> Fm.set company.name c.name
                    |> Fm.set company.legalName (Maybe.withDefault "" c.legalName)
                    |> Fm.set company.orgNumber c.orgNumber
                    |> Fm.set company.country (Just c.country)
                    |> Fm.set company.categories c.categories
                    |> Fm.set company.paymentTerms (Just c.paymentTerms)
                    |> Fm.set company.website (Maybe.withDefault "" c.website)
                    |> Fm.set company.preferred c.preferred
            , certs = TagInput.init "supplier-certifications" |> TagInput.setTags data.certifications
            , contract =
                FileDrop.init "supplier-contract"
                    |> FileDrop.setFiles
                        (data.contract
                            |> Maybe.map (\f -> [ { name = f.name, size = f.size, mime = "application/pdf" } ])
                            |> Maybe.withDefault []
                        )
            , contacts = contactRows
            , nextContactKey = List.length contactRows
            , delivery =
                Fm.init deliveryForm
                    |> Fm.set delivery.leadTime (Just d.leadTimeDays)
                    |> Fm.set delivery.minimumOrder d.minimumOrder
                    |> Fm.set delivery.shipsTo d.shipsTo
                    |> Fm.set delivery.dropShipping d.dropShipping
                    |> Fm.set delivery.notes (Maybe.withDefault "" d.notes)
            , rules = ruleRows
            , nextRuleKey = List.length ruleRows
        }


{-| The current values become what "unchanged" means.
-}
rebase : Model -> Model
rebase model =
    { model
        | company = Fm.markClean model.company
        , delivery = Fm.markClean model.delivery
        , contacts = List.map (\row -> { row | form = Fm.markClean row.form }) model.contacts
        , baseline =
            { contactKeys = List.map .key model.contacts
            , tags = TagInput.tags model.certs
            , files = FileDrop.files model.contract
            , rules = ruleSnapshot model
            }
    }


ruleSnapshot : Model -> List ( Rule.Rule, Maybe Float )
ruleSnapshot model =
    List.map (\row -> ( RuleBuilder.rule row.builder, NumberInput.value row.discount )) model.rules


isDirty : Model -> Bool
isDirty model =
    Fm.isDirty model.company
        || Fm.isDirty model.delivery
        || List.any (.form >> Fm.isDirty) model.contacts
        || List.map .key model.contacts
        /= model.baseline.contactKeys
        || TagInput.tags model.certs
        /= model.baseline.tags
        || FileDrop.files model.contract
        /= model.baseline.files
        || ruleSnapshot model
        /= model.baseline.rules



-- ISSUES


type alias Issue =
    { step : Step
    , target : String
    , message : String
    }


ruleFields : Remote Lookups -> List (Rule.Field ())
ruleFields lookups =
    let
        data =
            Remote.withDefault { countries = [], categories = [], paymentTerms = [] } lookups
    in
    [ Rule.bareField "category"
        "Category"
        (Rule.ChoiceKind (List.map (\c -> { value = categoryKey c.id, label = c.name }) data.categories))
        |> Rule.withOperators [ Rule.Is, Rule.IsNot, Rule.IsAnyOf ]
    , Rule.bareField "quantity" "Quantity" Rule.NumberKind
    , Rule.bareField "orderTotal" "Order total" Rule.NumberKind
    , Rule.bareField "destination"
        "Destination country"
        (Rule.ChoiceKind (List.map (\c -> { value = countryKey c.id, label = c.name }) data.countries))
        |> Rule.withOperators [ Rule.Is, Rule.IsNot, Rule.IsAnyOf ]
    ]


formIssues : Step -> Result (List Fm.Problem) a -> List Issue
formIssues step result =
    case result of
        Ok _ ->
            []

        Err problems ->
            List.map (\p -> { step = step, target = p.field, message = p.message }) problems


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


stepIssues : Remote Lookups -> Step -> Model -> List Issue
stepIssues lookups step model =
    case step of
        StepCompany ->
            List.concat
                [ formIssues StepCompany (Fm.toValues locale companyForm model.company)
                , standing StepCompany model
                , model.certsProblem
                    |> Maybe.map (\m -> [ { step = StepCompany, target = "supplier-certifications", message = m } ])
                    |> Maybe.withDefault []
                , if FileDrop.hasProblems model.contract then
                    [ { step = StepCompany, target = "supplier-contract", message = "Remove the refused file." } ]

                  else if List.isEmpty (FileDrop.files model.contract) then
                    [ { step = StepCompany, target = "supplier-contract", message = "Attach the signed contract." } ]

                  else
                    model.contractProblem
                        |> Maybe.map (\m -> [ { step = StepCompany, target = "supplier-contract", message = m } ])
                        |> Maybe.withDefault []
                ]

        StepContacts ->
            if List.isEmpty model.contacts then
                [ { step = StepContacts, target = "add-contact", message = "Add at least one contact." } ]

            else
                (model.contacts
                    |> List.concatMap (\row -> formIssues StepContacts (Fm.toValues locale (contactForm row.key) row.form))
                )
                    ++ standing StepContacts model

        StepDelivery ->
            formIssues StepDelivery (Fm.toValues locale deliveryForm model.delivery)
                ++ standing StepDelivery model

        StepPricing ->
            model.rules
                |> List.concatMap
                    (\row ->
                        let
                            rule =
                                RuleBuilder.rule row.builder

                            ruleIssues =
                                if Rule.conditionCount rule == 0 then
                                    [ { step = StepPricing, target = ruleDomId row.key, message = "Add at least one condition." } ]

                                else
                                    Rule.validate locale (ruleFields lookups) rule
                                        |> List.take 1
                                        |> List.map (\i -> { step = StepPricing, target = ruleDomId row.key, message = i.message })

                            discountIssues =
                                case ( discountError row, List.filter (\( k, _ ) -> k == row.key) model.ruleProblems ) of
                                    ( Just m, _ ) ->
                                        [ { step = StepPricing, target = ruleDomId row.key ++ "-discount", message = m } ]

                                    ( Nothing, ( _, m ) :: _ ) ->
                                        [ { step = StepPricing, target = ruleDomId row.key ++ "-discount", message = m } ]

                                    _ ->
                                        []
                        in
                        ruleIssues ++ discountIssues
                    )

        StepReview ->
            []


standing : Step -> Model -> List Issue
standing step model =
    model.serverIssues
        |> List.filter (\s -> s.issue.step == step && probe s.what model == s.at)
        |> List.map .issue


type Probe
    = ProbeName
    | ProbeOrg
    | ProbeCountry
    | ProbeCategories
    | ProbeTerms
    | ProbeWebsite
    | ProbeLead
    | ProbeShipsTo
    | ProbeContactEmail Int
    | ProbeContactName Int


probe : Probe -> Model -> String
probe what m =
    let
        contact key pick =
            m.contacts
                |> List.filter (\r -> r.key == key)
                |> List.head
                |> Maybe.map (\r -> Fm.get (pick (Fm.fields (contactForm key))) r.form)
                |> Maybe.withDefault ""
    in
    case what of
        ProbeName ->
            Fm.get company.name m.company

        ProbeOrg ->
            Fm.get company.orgNumber m.company

        ProbeCountry ->
            Fm.get company.country m.company |> Maybe.map countryKey |> Maybe.withDefault ""

        ProbeCategories ->
            Fm.get company.categories m.company |> List.map categoryKey |> String.join ","

        ProbeTerms ->
            (Fm.get company.paymentTerms m.company |> Maybe.map paymentTermsKey |> Maybe.withDefault "")
                ++ yesNo (Fm.get company.preferred m.company)

        ProbeWebsite ->
            Fm.get company.website m.company

        ProbeLead ->
            Fm.get delivery.leadTime m.delivery |> Maybe.map String.fromFloat |> Maybe.withDefault ""

        ProbeShipsTo ->
            Fm.get delivery.shipsTo m.delivery |> List.map countryKey |> String.join ","

        ProbeContactEmail key ->
            contact key .email

        ProbeContactName key ->
            contact key .name


serverIssueOf : Model -> Violation -> Maybe ServerIssue
serverIssueOf model v =
    let
        make step target what =
            Just { issue = { step = step, target = target, message = v.message }, what = what, at = probe what model }

        rowAt i =
            model.contacts |> List.drop i |> List.head
    in
    case v.field of
        FName ->
            make StepCompany "company-name" ProbeName

        FOrgNumber ->
            make StepCompany "company-organisation-number" ProbeOrg

        FCountry ->
            make StepCompany "company-country" ProbeCountry

        FCategories ->
            make StepCompany "company-categories" ProbeCategories

        FPaymentTerms ->
            make StepCompany "company-payment-terms" ProbeTerms

        FWebsite ->
            make StepCompany "company-website" ProbeWebsite

        FLeadTime ->
            make StepDelivery "delivery-lead-time-in-days" ProbeLead

        FShipsTo ->
            make StepDelivery "delivery-ships-to" ProbeShipsTo

        FContactEmail i ->
            rowAt i |> Maybe.andThen (\row -> make StepContacts ("contact-" ++ String.fromInt row.key ++ "-email") (ProbeContactEmail row.key))

        FContactName i ->
            rowAt i |> Maybe.andThen (\row -> make StepContacts ("contact-" ++ String.fromInt row.key ++ "-name") (ProbeContactName row.key))

        _ ->
            Nothing


-- KLAR GAP: end of the server-problem copy (R2O-007).
allIssues : Remote Lookups -> Model -> List Issue
allIssues lookups model =
    List.concatMap (\s -> stepIssues lookups s model) steps


buildData : Model -> Maybe SupplierData
buildData model =
    let
        contacts =
            model.contacts
                |> List.map (\row -> Fm.toValues locale (contactForm row.key) row.form |> Result.toMaybe)
                |> allJust

        rules =
            model.rules
                |> List.map
                    (\row ->
                        NumberInput.value row.discount
                            |> Maybe.map (\d -> { rule = RuleBuilder.rule row.builder, discountPercent = d })
                    )
                |> allJust
    in
    Maybe.map5
        (\co ( con, ru ) de ( certs, contract ) _ ->
            { company = co
            , contacts = con
            , delivery = de
            , priceRules = ru
            , certifications = certs
            , contract = contract
            }
        )
        (Fm.toValues locale companyForm model.company |> Result.toMaybe)
        (Maybe.map2 Tuple.pair contacts rules)
        (Fm.toValues locale deliveryForm model.delivery |> Result.toMaybe)
        (Just
            ( TagInput.tags model.certs
            , FileDrop.files model.contract |> List.head |> Maybe.map (\f -> { name = f.name, size = f.size })
            )
        )
        (Just ())


allJust : List (Maybe a) -> Maybe (List a)
allJust list =
    List.foldr (Maybe.map2 (::)) (Just []) list



-- UPDATE


type Msg
    = CompanyFormMsg Fm.Msg
    | DeliveryFormMsg Fm.Msg
    | ContactFormMsg Int Fm.Msg
    | CertsMsg TagInput.Msg
    | ContractMsg FileDrop.Msg
    | RuleBuilderMsg Int RuleBuilder.Msg
    | DiscountMsg Int NumberInput.Msg
    | AddContact
    | RemoveContact Int
    | AddRule
    | RemoveRule Int
    | Next
    | Back
    | GoTo Step
    | SelectStep Int
    | GoToIssue Issue
    | Save
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
    case msg of
        CompanyFormMsg m ->
            let
                ( state, cmd ) =
                    Fm.update m model.company
            in
            ( { model | company = state }, Cmd.map CompanyFormMsg cmd, noEffects )

        DeliveryFormMsg m ->
            let
                ( state, cmd ) =
                    Fm.update m model.delivery
            in
            ( { model | delivery = state }, Cmd.map DeliveryFormMsg cmd, noEffects )

        ContactFormMsg key m ->
            case List.filter (\r -> r.key == key) model.contacts of
                row :: _ ->
                    let
                        ( state, cmd ) =
                            Fm.update m row.form
                    in
                    ( { model | contacts = replaceRow key { row | form = state } model.contacts }
                    , Cmd.map (ContactFormMsg key) cmd
                    , noEffects
                    )

                [] ->
                    ( model, Cmd.none, noEffects )

        CertsMsg m ->
            let
                ( state, cmd ) =
                    TagInput.update m model.certs

                changed =
                    TagInput.tags state /= TagInput.tags model.certs
            in
            ( { model
                | certs = state
                , certsProblem =
                    if changed then
                        Nothing

                    else
                        model.certsProblem
              }
            , Cmd.map CertsMsg cmd
            , noEffects
            )

        ContractMsg m ->
            let
                ( state, cmd ) =
                    FileDrop.update m model.contract

                changed =
                    FileDrop.files state /= FileDrop.files model.contract
            in
            ( { model
                | contract = state
                , contractProblem =
                    if changed then
                        Nothing

                    else
                        model.contractProblem
              }
            , Cmd.map ContractMsg cmd
            , noEffects
            )

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
                        , ruleProblems =
                            if changed then
                                List.filter (\( k, _ ) -> k /= key) model.ruleProblems

                            else
                                model.ruleProblems
                      }
                    , Cmd.map (DiscountMsg key) cmd
                    , noEffects
                    )

                [] ->
                    ( model, Cmd.none, noEffects )

        AddContact ->
            let
                key =
                    model.nextContactKey
            in
            ( { model
                | contacts = model.contacts ++ [ newContactRow key ]
                , nextContactKey = key + 1
              }
            , Form.focusField ("contact-" ++ String.fromInt key ++ "-name") NoOp
            , noEffects
            )

        RemoveContact key ->
            ( { model | contacts = List.filter (\r -> r.key /= key) model.contacts }
            , Form.focusField "add-contact" NoOp
            , noEffects
            )

        AddRule ->
            let
                key =
                    model.nextRuleKey

                row =
                    newRuleRow key

                withCondition =
                    { row
                        | builder =
                            RuleBuilder.setRule
                                (Rule.addCondition (ruleFields env.lookups) 0 Rule.emptyGroup)
                                row.builder
                    }
            in
            ( { model | rules = model.rules ++ [ withCondition ], nextRuleKey = key + 1 }
            , Form.focusField (ruleDomId key ++ "-discount") NoOp
            , noEffects
            )

        RemoveRule key ->
            ( { model
                | rules = List.filter (\r -> r.key /= key) model.rules
                , ruleProblems = List.filter (\( k, _ ) -> k /= key) model.ruleProblems
              }
            , Form.focusField "add-rule" NoOp
            , noEffects
            )

        Next ->
            if model.step == StepReview then
                update env Save model

            else
                let
                    ( tried, cmd ) =
                        attempt env.lookups model.step model
                in
                if List.isEmpty (stepIssues env.lookups model.step model) then
                    enter env.lookups (stepAt (stepIndex model.step + 1)) model

                else
                    ( tried, cmd, noEffects )

        Back ->
            enter env.lookups (stepAt (stepIndex model.step - 1)) model

        GoTo step ->
            enter env.lookups step model

        SelectStep i ->
            let
                target =
                    stepAt i
            in
            if i <= stepIndex model.step then
                enter env.lookups target model

            else
                -- forward: every step on the way must be valid
                case
                    steps
                        |> List.filter (\s -> stepIndex s >= stepIndex model.step && stepIndex s < i)
                        |> List.filter (\s -> not (List.isEmpty (stepIssues env.lookups s model)))
                        |> List.head
                of
                    Nothing ->
                        enter env.lookups target model

                    Just bad ->
                        let
                            ( tried, cmd ) =
                                attempt env.lookups bad model
                        in
                        ( { tried | step = bad }, cmd, noEffects )

        GoToIssue issue ->
            ( { model | step = issue.step }
            , Form.focusField issue.target NoOp
            , noEffects
            )

        Save ->
            case ( model.status, buildData model, List.isEmpty (allIssues env.lookups model) ) of
                ( Form.Submitting, _, _ ) ->
                    ( model, Cmd.none, noEffects )

                ( _, Just data, True ) ->
                    ( { model | status = Form.Submitting, conflict = Nothing }
                    , Cmd.batch
                        [ Api.save env.behaviour
                            env.db
                            { id = savedId model, baseVersion = model.baseVersion, data = data }
                            Replied
                        , Form.focusStatus formId NoOp
                        ]
                    , noEffects
                    )

                _ ->
                    let
                        revealed =
                            revealAll env.lookups model
                    in
                    ( { revealed | step = StepReview }
                    , Form.focusField "review-problems" NoOp
                    , noEffects
                    )

        Retry ->
            update env Save model

        Replied db result ->
            case result of
                Ok supplier ->
                    let
                        saved =
                            rebase
                                { model
                                    | mode = Editing supplier
                                    , baseVersion = supplier.version
                                    , status = Form.Succeeded "The supplier was saved."
                                    , conflict = Nothing
                                    , serverIssues = []
                                }
                    in
                    ( saved, Cmd.none, { noEffects | db = Just db, saved = Just supplier } )

                Err (Invalid violations) ->
                    let
                        ( next, cmd ) =
                            applyViolations env.lookups violations model
                    in
                    ( next, cmd, { noEffects | db = Just db } )

                Err (Conflict theirs) ->
                    ( { model | conflict = Just theirs, status = Form.Idle }
                    , Form.focusField "conflict-alert" NoOp
                    , { noEffects | db = Just db }
                    )

                Err (Unavailable problem) ->
                    ( { model | status = Form.Failed problem }
                    , Form.focusStatus formId NoOp
                    , { noEffects | db = Just db }
                    )

        Overwrite ->
            case model.conflict of
                Just theirs ->
                    update env Save { model | baseVersion = theirs.version, conflict = Nothing }

                Nothing ->
                    ( model, Cmd.none, noEffects )

        KeepEditing ->
            case model.conflict of
                Just theirs ->
                    ( { model | baseVersion = theirs.version, conflict = Nothing }
                    , Form.focusField "save-supplier" NoOp
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
                    ( { fresh | step = StepReview, confirm = confirm }
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


savedId : Model -> Maybe SupplierId
savedId model =
    case model.mode of
        Creating ->
            Nothing

        Editing s ->
            Just s.id


replaceRow : Int -> ContactRow -> List ContactRow -> List ContactRow
replaceRow key row rows =
    List.map
        (\r ->
            if r.key == key then
                row

            else
                r
        )
        rows


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


{-| Moves to a step and puts focus on its first field.
-}
enter : Remote Lookups -> Step -> Model -> ( Model, Cmd Msg, Effects )
enter lookups step model =
    ( { model | step = step }
    , Form.focusField (firstFieldId lookups step model) NoOp
    , noEffects
    )


-- KLAR GAP: no Fm.focus / Fm.domId, the generated DOM ids are written out by hand (R2O-006).
firstFieldId : Remote Lookups -> Step -> Model -> String
firstFieldId lookups step model =
    case step of
        StepCompany ->
            "company-name"

        StepContacts ->
            case model.contacts of
                row :: _ ->
                    "contact-" ++ String.fromInt row.key ++ "-name"

                [] ->
                    "add-contact"

        StepDelivery ->
            "delivery-lead-time-in-days"

        StepPricing ->
            case model.rules of
                row :: _ ->
                    ruleDomId row.key ++ "-discount"

                [] ->
                    "add-rule"

        StepReview ->
            if List.isEmpty (allIssues lookups model) then
                "save-supplier"

            else
                "review-problems"


{-| The user tried to leave a step: show every problem in it at once.
-}
attempt : Remote Lookups -> Step -> Model -> ( Model, Cmd Msg )
attempt lookups step model =
    let
        marked =
            { model | tried = step :: model.tried }
    in
    case step of
        StepCompany ->
            let
                ( state, cmd ) =
                    Fm.reveal companyForm model.company
            in
            ( { marked | company = state }
            , case ( Fm.toValues locale companyForm model.company, stepIssues lookups StepCompany model ) of
                ( Ok _, first :: _ ) ->
                    Form.focusField first.target NoOp

                _ ->
                    Cmd.map CompanyFormMsg cmd
            )

        StepDelivery ->
            let
                ( state, cmd ) =
                    Fm.reveal deliveryForm model.delivery
            in
            ( { marked | delivery = state }, Cmd.map DeliveryFormMsg cmd )

        StepContacts ->
            let
                revealed =
                    List.map
                        (\row ->
                            let
                                ( state, cmd ) =
                                    Fm.reveal (contactForm row.key) row.form
                            in
                            ( { row | form = state }, Cmd.map (ContactFormMsg row.key) cmd )
                        )
                        model.contacts

                firstBad =
                    List.map2 Tuple.pair model.contacts revealed
                        |> List.filter (\( row, _ ) -> Fm.toValues locale (contactForm row.key) row.form |> Result.toMaybe |> (==) Nothing)
                        |> List.head
                        |> Maybe.map (\( _, ( _, cmd ) ) -> cmd)
                        |> Maybe.withDefault
                            (if List.isEmpty model.contacts then
                                Form.focusField "add-contact" NoOp

                             else
                                Cmd.none
                            )
            in
            ( { marked | contacts = List.map Tuple.first revealed }, firstBad )

        StepPricing ->
            let
                shown =
                    List.map (\row -> { row | builder = RuleBuilder.showIssues row.builder }) model.rules

                first =
                    stepIssues lookups StepPricing model |> List.head
            in
            ( { marked | rules = shown }
            , first |> Maybe.map (\i -> Form.focusField i.target NoOp) |> Maybe.withDefault Cmd.none
            )

        StepReview ->
            ( marked, Cmd.none )


revealAll : Remote Lookups -> Model -> Model
revealAll lookups model =
    List.foldl (\s m -> attempt lookups s m |> Tuple.first) model [ StepCompany, StepContacts, StepDelivery, StepPricing ]


{-| Gives the problems of a failed save to the fields they belong to, and goes
to the first step that has one.
-}
applyViolations : Remote Lookups -> List Violation -> Model -> ( Model, Cmd Msg )
applyViolations lookups violations model0 =
    let
        model =
            revealAll lookups model0

        companyProblems =
            List.filterMap
                (\v ->
                    case v.field of
                        FName ->
                            Just (Fm.problem company.name v.message)

                        FOrgNumber ->
                            Just (Fm.problem company.orgNumber v.message)

                        FCountry ->
                            Just (Fm.problem company.country v.message)

                        FCategories ->
                            Just (Fm.problem company.categories v.message)

                        FPaymentTerms ->
                            Just (Fm.problem company.paymentTerms v.message)

                        FWebsite ->
                            Just (Fm.problem company.website v.message)

                        _ ->
                            Nothing
                )
                violations

        deliveryProblems =
            List.filterMap
                (\v ->
                    case v.field of
                        FLeadTime ->
                            Just (Fm.problem delivery.leadTime v.message)

                        FShipsTo ->
                            Just (Fm.problem delivery.shipsTo v.message)

                        _ ->
                            Nothing
                )
                violations

        contactProblems row i =
            let
                f =
                    Fm.fields (contactForm row.key)
            in
            List.filterMap
                (\v ->
                    case v.field of
                        FContactEmail j ->
                            if i == j then
                                Just (Fm.problem f.email v.message)

                            else
                                Nothing

                        FContactName j ->
                            if i == j then
                                Just (Fm.problem f.name v.message)

                            else
                                Nothing

                        _ ->
                            Nothing
                )
                violations

        certsMessage =
            List.filterMap
                (\v ->
                    if v.field == FCertifications then
                        Just v.message

                    else
                        Nothing
                )
                violations
                |> List.head

        contractMessage =
            List.filterMap
                (\v ->
                    if v.field == FContract then
                        Just v.message

                    else
                        Nothing
                )
                violations
                |> List.head

        ruleMessages =
            model.rules
                |> List.indexedMap
                    (\i row ->
                        violations
                            |> List.filterMap
                                (\v ->
                                    if v.field == FRuleDiscount i || v.field == FRule i then
                                        Just ( row.key, v.message )

                                    else
                                        Nothing
                                )
                    )
                |> List.concat

        ( company2, companyCmd ) =
            if List.isEmpty companyProblems then
                ( model.company, Cmd.none )

            else
                Fm.rejected companyProblems companyForm model.company

        ( delivery2, deliveryCmd ) =
            if List.isEmpty deliveryProblems then
                ( model.delivery, Cmd.none )

            else
                Fm.rejected deliveryProblems deliveryForm model.delivery

        contactResults =
            model.contacts
                |> List.indexedMap
                    (\i row ->
                        case contactProblems row i of
                            [] ->
                                ( row, Nothing )

                            ps ->
                                let
                                    ( state, cmd ) =
                                        Fm.rejected ps (contactForm row.key) row.form
                                in
                                ( { row | form = state }, Just (Cmd.map (ContactFormMsg row.key) cmd) )
                    )

        targetStep =
            [ ( StepCompany, not (List.isEmpty companyProblems) || certsMessage /= Nothing || contractMessage /= Nothing )
            , ( StepContacts, List.any (\( _, c ) -> c /= Nothing) contactResults )
            , ( StepDelivery, not (List.isEmpty deliveryProblems) )
            , ( StepPricing, not (List.isEmpty ruleMessages) )
            ]
                |> List.filter Tuple.second
                |> List.head
                |> Maybe.map Tuple.first
                |> Maybe.withDefault StepReview

        count =
            List.length violations

        next =
            { model
                | company = company2
                , delivery = delivery2
                , contacts = List.map Tuple.first contactResults
                , certsProblem = certsMessage
                , contractProblem = contractMessage
                , ruleProblems = ruleMessages
                , serverIssues = List.filterMap (serverIssueOf model) violations
                , step = targetStep
                , status =
                    Form.Failed
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

        focus =
            case targetStep of
                StepCompany ->
                    if List.isEmpty companyProblems then
                        Form.focusField
                            (if certsMessage /= Nothing then
                                "supplier-certifications"

                             else
                                "supplier-contract"
                            )
                            NoOp

                    else
                        Cmd.map CompanyFormMsg companyCmd

                StepContacts ->
                    contactResults |> List.filterMap Tuple.second |> List.head |> Maybe.withDefault Cmd.none

                StepDelivery ->
                    Cmd.map DeliveryFormMsg deliveryCmd

                StepPricing ->
                    ruleMessages |> List.head |> Maybe.map (\( k, _ ) -> Form.focusField (ruleDomId k ++ "-discount") NoOp) |> Maybe.withDefault Cmd.none

                StepReview ->
                    Cmd.none
    in
    ( next, focus )



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
        issuesByStep s =
            stepIssues lookups s model

        stepperSteps =
            steps
                |> List.map
                    (\s ->
                        if List.member s model.tried && not (List.isEmpty (issuesByStep s)) then
                            Stepper.step (stepLabel s) |> Stepper.failed

                        else
                            Stepper.step (stepLabel s)
                    )

        title =
            case model.mode of
                Creating ->
                    "New supplier"

                Editing s ->
                    "Edit " ++ s.data.company.name

        last =
            model.step == StepReview
    in
    Layout.stack [ Layout.gap 4 ]
        [ PageHeader.view
            [ PageHeader.title title
            , PageHeader.subtitle "Five steps. Every step is checked before you move on."
            ]
        , Stepper.view
            [ Stepper.current (stepIndex model.step)
            , Stepper.onSelect SelectStep
            , Stepper.ariaLabel "Onboarding steps"
            ]
            stepperSteps
        , Form.view [ Form.id formId, Form.onSubmit Next, Form.ariaLabel (stepLabel model.step) ]
            [ viewStep lookups model
            , Form.unsavedChanges [ Form.sticky ] (isDirty model)
            , Form.actions
                [ Form.status [ Form.id formId, Form.onRetry Retry ] model.status
                , Layout.spacer
                , Button.view [ Button.href "#/suppliers" ] "Cancel"
                , if model.step == StepCompany then
                    Html.text ""

                  else
                    Button.view [ Button.onClick Back, Button.icon Icon.arrowLeft ] "Back"
                , Button.view
                    [ Button.primary
                    , Button.submit
                    , Button.id "save-supplier"
                    , Button.loading (model.status == Form.Submitting)
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


viewStep : Remote Lookups -> Model -> Html Msg
viewStep lookups model =
    case model.step of
        StepCompany ->
            viewCompany lookups model

        StepContacts ->
            viewContacts model

        StepDelivery ->
            viewDelivery lookups model

        StepPricing ->
            viewPricing lookups model

        StepReview ->
            viewReview lookups model


countryOptions : Remote Lookups -> Remote (List (Select.Option CountryId))
countryOptions =
    Remote.map (.countries >> List.map (\c -> Select.option c.id c.name))


categoryOptions : Remote Lookups -> Remote (List (Select.Option CategoryId))
categoryOptions =
    Remote.map (.categories >> List.map (\c -> Select.option c.id c.name))


termsOptions : Remote Lookups -> Remote (List (Select.Option PaymentTermsId))
termsOptions =
    Remote.map (.paymentTerms >> List.map (\c -> Select.option c.id c.name))


viewCompany : Remote Lookups -> Model -> Html Msg
viewCompany lookups model =
    let
        v =
            Fm.bind locale CompanyFormMsg companyForm model.company

        certsError =
            if List.member StepCompany model.tried then
                model.certsProblem

            else
                model.certsProblem

        contractError =
            if List.member StepCompany model.tried || model.contractProblem /= Nothing then
                case ( FileDrop.files model.contract, model.contractProblem ) of
                    ( [], _ ) ->
                        Just "Attach the signed contract."

                    ( _, problem ) ->
                        problem

            else
                Nothing
    in
    Layout.stack [ Layout.gap 4 ]
        [ Fm.summary v
        , Form.section "Company"
            "Who the supplier is."
            [ Form.grid 2
                [ Fm.textInput v company.name []
                , Fm.textInput v company.legalName []
                , Fm.textInput v company.orgNumber [ TextInput.inputMode "numeric" ]
                , Fm.textInput v company.website [ TextInput.url, TextInput.placeholder "https://" ]
                ]
            ]
        , Form.section "Business"
            "Where it is registered and what it sells."
            [ Form.grid 2
                [ Fm.select v company.country (countryOptions lookups) [ Select.onRetry ReloadLookups, Select.placeholder "Choose a country" ]
                , Fm.select v company.paymentTerms (termsOptions lookups) [ Select.onRetry ReloadLookups ]
                , Form.fullRow (Fm.multiSelect v company.categories (categoryOptions lookups) [ MultiSelect.onRetry ReloadLookups ])
                , Form.fullRow (Fm.switch v company.preferred [])
                ]
            ]
        , Form.section "Certifications and contract"
            "Certificates the supplier holds, and the signed agreement."
            [ TagInput.view CertsMsg
                [ TagInput.label "Certifications"
                , TagInput.hint "Type a name and press Enter, for example ISO 9001."
                , TagInput.delimiters [ ',', ';' ]
                , TagInput.maxTags 8
                , TagInput.errorMaybe certsError
                ]
                model.certs
            , FileDrop.view ContractMsg
                [ FileDrop.label "Signed contract"
                , FileDrop.accept [ ".pdf" ]
                , FileDrop.maxSize 5000000
                , FileDrop.maxFiles 1
                , FileDrop.required
                , FileDrop.errorMaybe contractError
                ]
                model.contract
            ]
        ]


viewContacts : Model -> Html Msg
viewContacts model =
    let
        row index r =
            let
                form =
                    contactForm r.key

                f =
                    Fm.fields form

                v =
                    Fm.bind locale (ContactFormMsg r.key) form r.form
            in
            Card.view
                [ Card.headingLevel 2
                , Card.title ("Contact " ++ String.fromInt (index + 1))
                , Card.actions
                    [ Button.iconOnly
                        [ Button.ghost, Button.onClick (RemoveContact r.key) ]
                        Icon.trash
                        ("Remove contact " ++ String.fromInt (index + 1))
                    ]
                ]
                [ Layout.stack [ Layout.gap 3 ]
                    [ Fm.summary v
                    , Form.grid 2
                        [ Fm.textInput v f.name []
                        , Fm.textInput v f.email [ TextInput.email ]
                        , Fm.textInput v f.phone [ TextInput.tel ]
                        , Fm.select v f.role (Remote.Loaded (List.map (\role -> Select.option role (contactRoleLabel role)) contactRoles)) []
                        ]
                    ]
                ]
    in
    Layout.stack [ Layout.gap 4 ]
        (List.indexedMap row model.contacts
            ++ [ if List.isEmpty model.contacts && List.member StepContacts model.tried then
                    Alert.view [ Alert.tone Danger, Alert.compact ] "Add at least one contact."

                 else
                    Html.text ""
               , Layout.row [] [ Button.view [ Button.id "add-contact", Button.icon Icon.plus, Button.onClick AddContact ] "Add contact" ]
               ]
        )


viewDelivery : Remote Lookups -> Model -> Html Msg
viewDelivery lookups model =
    let
        v =
            Fm.bind locale DeliveryFormMsg deliveryForm model.delivery
    in
    Layout.stack [ Layout.gap 4 ]
        [ Fm.summary v
        , Form.section "Delivery terms"
            "How fast, how much and where."
            [ Form.grid 2
                [ Fm.numberInput v delivery.leadTime [ NumberInput.suffixText "days" ]
                , Fm.numberInput v delivery.minimumOrder [ NumberInput.prefixText "NOK", NumberInput.grouped ]
                , Form.fullRow (Fm.multiSelect v delivery.shipsTo (countryOptions lookups) [ MultiSelect.onRetry ReloadLookups ])
                , Form.fullRow (Fm.switch v delivery.dropShipping [])
                , Form.fullRow (Fm.textInput v delivery.notes [])
                ]
            ]
        ]


viewPricing : Remote Lookups -> Model -> Html Msg
viewPricing lookups model =
    let
        fields =
            ruleFields lookups

        shown =
            List.member StepPricing model.tried

        row index r =
            let
                rule =
                    RuleBuilder.rule r.builder

                discount =
                    NumberInput.value r.discount

                problem =
                    case ( shown, discountError r ) of
                        ( True, Just m ) ->
                            Just m

                        _ ->
                            List.filter (\( k, _ ) -> k == r.key) model.ruleProblems
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
                        r.builder
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
        (Text.paragraph "A rule says: if the order matches these conditions, this discount applies."
            :: List.indexedMap row model.rules
            ++ [ Layout.row [] [ Button.view [ Button.id "add-rule", Button.icon Icon.plus, Button.onClick AddRule ] "Add price rule" ] ]
        )


viewReview : Remote Lookups -> Model -> Html Msg
viewReview lookups model =
    let
        issues =
            allIssues lookups model

        data =
            buildData model

        data_ =
            Remote.withDefault { countries = [], categories = [], paymentTerms = [] } lookups

        countryName id =
            data_.countries |> List.filter (\c -> c.id == id) |> List.head |> Maybe.map .name |> Maybe.withDefault (countryKey id)

        categoryName id =
            data_.categories |> List.filter (\c -> c.id == id) |> List.head |> Maybe.map .name |> Maybe.withDefault (categoryKey id)

        termsName id =
            data_.paymentTerms |> List.filter (\c -> c.id == id) |> List.head |> Maybe.map .name |> Maybe.withDefault (paymentTermsKey id)

        section step cardTitle items =
            Card.view
                [ Card.headingLevel 2
                , Card.title cardTitle
                , Card.actions [ Button.view [ Button.small, Button.onClick (GoTo step) ] "Edit" ]
                ]
                [ DescriptionList.view [ DescriptionList.columns 2, DescriptionList.compact ] items ]

        summaryOf d =
            Layout.stack [ Layout.gap 4 ]
                [ section StepCompany
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
                , section StepContacts
                    "Contacts"
                    (d.contacts
                        |> List.map (\c -> DescriptionList.text (contactRoleLabel c.role) (c.name ++ ", " ++ c.email))
                    )
                , section StepDelivery
                    "Delivery terms"
                    [ DescriptionList.text "Lead time" (String.fromFloat d.delivery.leadTimeDays ++ " days")
                    , DescriptionList.maybe "Minimum order" (d.delivery.minimumOrder |> Maybe.map (\n -> "NOK " ++ String.fromFloat n))
                    , DescriptionList.text "Ships to" (d.delivery.shipsTo |> List.map countryName |> String.join ", ")
                    , DescriptionList.text "Drop shipping" (yesNo d.delivery.dropShipping)
                    , DescriptionList.maybe "Notes" d.delivery.notes
                    ]
                , section StepPricing
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
        , case ( issues, data ) of
            ( [], Just d ) ->
                Layout.stack [ Layout.gap 4 ]
                    [ Alert.view [ Alert.tone Success, Alert.compact ] "Everything is filled in. Read it once more, then save."
                    , summaryOf d
                    ]

            _ ->
                Alert.viewWith [ Alert.tone Danger, Alert.title (String.fromInt (List.length issues) ++ " things need your attention") ]
                    [ Layout.stack [ Layout.gap 2 ]
                        (Text.paragraph "Fix these before the supplier can be saved."
                            :: List.indexedMap
                                (\i issue ->
                                    Layout.row []
                                        [ Text.strong (stepLabel issue.step ++ ":")
                                        , Text.text issue.message
                                        , Button.view
                                            ([ Button.small, Button.link, Button.onClick (GoToIssue issue) ]
                                                ++ (if i == 0 then
                                                        [ Button.id "review-problems" ]

                                                    else
                                                        []
                                                   )
                                            )
                                            "Go to field"
                                        ]
                                )
                                issues
                        )
                    ]
        ]


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

                joinWith f ids =
                    ids |> List.map f |> String.join ", "

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
