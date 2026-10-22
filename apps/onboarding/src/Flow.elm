module Flow exposing
    ( Ctx
    , Model
    , Msg
    , Out(..)
    , editingId
    , init
    , isDirty
    , modalOpen
    , overlays
    , update
    , view
    )

{-| The five-step onboarding flow: company, contacts, delivery terms, pricing rules,
review. It is used for a new supplier and for editing a whole record again.
-}

import Api
import Backend exposing (Store)
import Domain exposing (..)
import Html exposing (Html)
import Ids
import Klar.Alert as Alert
import Klar.Badge as Badge
import Klar.Button as Button
import Klar.Card as Card
import Klar.ConfirmDialog as ConfirmDialog
import Klar.DescriptionList as DescriptionList
import Klar.EmptyState as EmptyState
import Klar.FileDrop as FileDrop
import Klar.Form as Form
import Klar.Icon as Icon
import Klar.Layout as Layout
import Klar.Locale as Locale
import Klar.Modal as Modal
import Klar.MultiSelect as MultiSelect
import Klar.NumberInput as NumberInput
import Klar.Remote as Remote exposing (Remote)
import Klar.Rule as Rule
import Klar.RuleBuilder as RuleBuilder
import Klar.Select as Select
import Klar.Stepper as Stepper
import Klar.Switch as Switch
import Klar.Tag as Tag
import Klar.TagInput as TagInput
import Klar.Text as Text
import Klar.TextArea as TextArea
import Klar.TextInput as TextInput
import Klar.Theme as Theme
import Klar.Validate as Validate
import RuleFields



-- CONTEXT AND OUTPUT


type alias Ctx =
    { countries : Remote (List Country)
    , categories : Remote (List Category)
    , terms : Remote (List PaymentTerms)
    , store : Store
    , sim : Api.Sim
    }


type Out
    = StoreChanged Store
    | ToastOut Theme.Tone String
    | Navigate String
    | ReloadReference
    | FaultUsed


type alias Ref =
    { categories : List Category
    , countries : List Country
    , terms : List PaymentTerms
    }


refOf : Ctx -> Ref
refOf ctx =
    { categories = Remote.withDefault [] ctx.categories
    , countries = Remote.withDefault [] ctx.countries
    , terms = Remote.withDefault [] ctx.terms
    }



-- MODEL


type Mode
    = Creating
    | Editing SupplierId


-- KLAR GAP: no uniform dirty/load across stateful controls (O-018)
{-| What the user has typed and chosen, read out of all the component states. Dirty
means: different from the baseline.
-}
type alias Draft =
    { name : String
    , legalName : String
    , registration : String
    , website : String
    , country : Maybe CountryId
    , categories : List CategoryId
    , certifications : List String
    , contract : List FileDrop.FileInfo
    , contacts : List Contact
    , leadTime : Maybe Float
    , minimumOrder : Maybe Float
    , deliversTo : List CountryId
    , paymentTerms : Maybe PaymentTermsId
    , notes : String
    , priceRules : List PriceRule
    }


type alias Problem =
    { step : Int, field : String, message : String }


type alias Editor =
    { index : Maybe Int
    , name : String
    , discount : NumberInput.State
    , builder : RuleBuilder.State
    , attempted : Bool
    }


type alias Model =
    { mode : Mode
    , baseVersion : Int
    , step : Int
    , furthest : Int
    , attempted : List Int
    , reviewAttempted : Bool
    , name : String
    , legalName : String
    , registration : String
    , website : String
    , country : Select.State CountryId
    , categories : MultiSelect.State CategoryId
    , certifications : TagInput.State
    , contract : FileDrop.State
    , contacts : List Contact
    , leadTime : NumberInput.State
    , minimumOrder : NumberInput.State
    , deliversTo : MultiSelect.State CountryId
    , paymentTerms : Select.State PaymentTermsId
    , notes : String
    , priceRules : List PriceRule
    , editor : Maybe Editor
    , editorModal : Modal.State
    , status : Form.Status
    , serverProblems : List Problem
    , conflict : Maybe Supplier
    , conflictModal : Modal.State
    , takeTheirs : ConfirmDialog.State
    , baseline : Draft
    }


stepNames : List String
stepNames =
    [ "Company", "Contacts", "Delivery terms", "Pricing rules", "Review" ]


lastStep : Int
lastStep =
    4


emptyContact : Bool -> Contact
emptyContact primary =
    { name = "", email = "", phone = "", role = "", primary = primary }


leadTimeAttrs : List (NumberInput.Attribute msg)
leadTimeAttrs =
    [ NumberInput.min 1, NumberInput.max 365, NumberInput.decimals 0 ]


minimumOrderAttrs : List (NumberInput.Attribute msg)
minimumOrderAttrs =
    [ NumberInput.min 0, NumberInput.decimals 2 ]


discountAttrs : List (NumberInput.Attribute msg)
discountAttrs =
    [ NumberInput.min 0.1, NumberInput.max 100, NumberInput.decimals 1 ]


init : Maybe Supplier -> Model
init maybeSupplier =
    let
        blank =
            { mode = Creating
            , baseVersion = 0
            , step = 0
            , furthest = 0
            , attempted = []
            , reviewAttempted = False
            , name = ""
            , legalName = ""
            , registration = ""
            , website = ""
            , country = Select.init Ids.country
            , categories = MultiSelect.init Ids.categories
            , certifications = TagInput.init Ids.certifications
            , contract = FileDrop.init Ids.contract
            , contacts = [ emptyContact True ]
            , leadTime = NumberInput.init Ids.leadTime |> NumberInput.setLimits leadTimeAttrs
            , minimumOrder = NumberInput.init Ids.minimumOrder |> NumberInput.setLimits minimumOrderAttrs
            , deliversTo = MultiSelect.init Ids.deliversTo
            , paymentTerms = Select.init Ids.paymentTerms
            , notes = ""
            , priceRules = []
            , editor = Nothing
            , editorModal = Modal.init Ids.priceRuleEditor
            , status = Form.Idle
            , serverProblems = []
            , conflict = Nothing
            , conflictModal = Modal.init Ids.conflictModal
            , takeTheirs = ConfirmDialog.init Ids.reloadDialog
            , baseline = emptyDraft
            }
    in
    case maybeSupplier of
        Nothing ->
            withBaseline blank

        Just s ->
            load s { blank | furthest = lastStep } |> withBaseline


emptyDraft : Draft
emptyDraft =
    { name = ""
    , legalName = ""
    , registration = ""
    , website = ""
    , country = Nothing
    , categories = []
    , certifications = []
    , contract = []
    , contacts = []
    , leadTime = Nothing
    , minimumOrder = Nothing
    , deliversTo = []
    , paymentTerms = Nothing
    , notes = ""
    , priceRules = []
    }


withBaseline : Model -> Model
withBaseline m =
    { m | baseline = toDraft m }


{-| Puts a saved supplier into all the component states.
-}
load : Supplier -> Model -> Model
load s m =
    { m
        | mode = Editing s.id
        , baseVersion = s.version
        , name = s.name
        , legalName = s.legalName
        , registration = s.registrationNumber
        , website = s.website
        , country = Select.setValue s.country m.country
        , categories = MultiSelect.setValues s.categories m.categories
        , certifications = TagInput.setTags s.certifications m.certifications
        , contract =
            FileDrop.setFiles
                (case s.contractFile of
                    Just f ->
                        [ { name = f.name, size = f.size, mime = "application/pdf" } ]

                    Nothing ->
                        []
                )
                m.contract
        , contacts = s.contacts
        , leadTime = NumberInput.setValue (Just (toFloat s.delivery.leadTimeDays)) m.leadTime
        , minimumOrder = NumberInput.setValue (Just s.delivery.minimumOrder) m.minimumOrder
        , deliversTo = MultiSelect.setValues s.delivery.deliversTo m.deliversTo
        , paymentTerms = Select.setValue s.delivery.paymentTerms m.paymentTerms
        , notes = s.delivery.notes
        , priceRules = s.priceRules
    }


toDraft : Model -> Draft
toDraft m =
    { name = m.name
    , legalName = m.legalName
    , registration = m.registration
    , website = m.website
    , country = Select.value m.country
    , categories = MultiSelect.values m.categories
    , certifications = TagInput.tags m.certifications
    , contract = FileDrop.files m.contract
    , contacts = m.contacts
    , leadTime = NumberInput.value m.leadTime
    , minimumOrder = NumberInput.value m.minimumOrder
    , deliversTo = MultiSelect.values m.deliversTo
    , paymentTerms = Select.value m.paymentTerms
    , notes = m.notes
    , priceRules = m.priceRules
    }


isDirty : Model -> Bool
isDirty m =
    toDraft m /= m.baseline


editingId : Model -> Maybe SupplierId
editingId m =
    case m.mode of
        Creating ->
            Nothing

        Editing id ->
            Just id


modalOpen : Model -> Bool
modalOpen m =
    Modal.isOpen m.editorModal || Modal.isOpen m.conflictModal || ConfirmDialog.isOpen m.takeTheirs


toSupplier : Model -> Maybe Supplier
toSupplier m =
    case ( ( Select.value m.country, Select.value m.paymentTerms ), ( NumberInput.value m.leadTime, NumberInput.value m.minimumOrder ) ) of
        ( ( Just country, Just terms ), ( Just lead, Just minOrder ) ) ->
            Just
                { id = Maybe.withDefault (SupplierId 0) (editingId m)
                , version = m.baseVersion
                , name = String.trim m.name
                , legalName = String.trim m.legalName
                , registrationNumber = String.trim m.registration
                , website = String.trim m.website
                , country = country
                , categories = MultiSelect.values m.categories
                , certifications = TagInput.tags m.certifications
                , contractFile = FileDrop.files m.contract |> List.head |> Maybe.map (\f -> { name = f.name, size = f.size })
                , contacts = m.contacts
                , delivery =
                    { leadTimeDays = round lead
                    , minimumOrder = minOrder
                    , deliversTo = MultiSelect.values m.deliversTo
                    , paymentTerms = terms
                    , notes = String.trim m.notes
                    }
                , priceRules = m.priceRules
                }

        _ ->
            Nothing



-- PROBLEMS


fromErrors : Int -> List Validate.Error -> List Problem
fromErrors step errors =
    List.map (\e -> { step = step, field = e.field, message = e.message }) errors


-- KLAR GAP: Validate only checks Strings, so a required Select / MultiSelect / FileDrop is checked by hand
requiredValue : Int -> String -> String -> Maybe a -> List Problem
requiredValue step field message value =
    case value of
        Just _ ->
            []

        Nothing ->
            [ { step = step, field = field, message = message } ]


nonEmptyList : Int -> String -> String -> List a -> List Problem
nonEmptyList step field message items =
    if List.isEmpty items then
        [ { step = step, field = field, message = message } ]

    else
        []


validateText : List ( String, List Validate.Validator, String ) -> List Validate.Error
validateText =
    Validate.collect Locale.en


registrationFormat : Validate.Validator
registrationFormat =
    Validate.custom
        (\s -> String.length (String.trim s) == 8 && String.all Char.isDigit (String.trim s))
        { nb = "Må være 8 siffer", en = "Must be 8 digits" }


httpUrl : Validate.Validator
httpUrl =
    Validate.custom
        (\s -> String.trim s == "" || String.startsWith "http://" s || String.startsWith "https://" s)
        { nb = "Må starte med http:// eller https://", en = "Must start with http:// or https://" }


companyProblems : Model -> List Problem
companyProblems m =
    List.concat
        [ fromErrors 0
            (validateText
                [ ( Ids.name, [ Validate.required, Validate.maxLength 80 ], m.name )
                , ( Ids.legalName, [ Validate.required ], m.legalName )
                , ( Ids.registration, [ Validate.required, registrationFormat ], m.registration )
                , ( Ids.website, [ httpUrl ], m.website )
                ]
            )
        , requiredValue 0 Ids.country "Choose the country of the company" (Select.value m.country)
        , nonEmptyList 0 Ids.categories "Choose at least one product category" (MultiSelect.values m.categories)
        , if List.isEmpty (FileDrop.files m.contract) then
            [ { step = 0, field = Ids.contract, message = "Attach the signed contract" } ]

          else if FileDrop.hasProblems m.contract then
            [ { step = 0, field = Ids.contract, message = "Remove the files that were refused" } ]

          else
            []
        ]


contactProblems : Model -> List Problem
contactProblems m =
    let
        forContact i c =
            fromErrors 1
                (validateText
                    [ ( Ids.contactName i, [ Validate.required ], c.name )
                    , ( Ids.contactEmail i, [ Validate.required, Validate.email ], c.email )
                    , ( Ids.contactPhone i, [ Validate.phone ], c.phone )
                    ]
                )

        primaries =
            List.length (List.filter .primary m.contacts)
    in
    List.concat
        [ nonEmptyList 1 Ids.contacts "Add at least one contact" m.contacts
        , List.concat (List.indexedMap forContact m.contacts)
        , if not (List.isEmpty m.contacts) && primaries /= 1 then
            [ { step = 1, field = Ids.contactPrimary 0, message = "Exactly one contact must be the primary contact" } ]

          else
            []
        ]


numberProblems : Int -> String -> String -> NumberInput.State -> List Problem
numberProblems step field rangeMessage state =
    case NumberInput.value state of
        Nothing ->
            [ { step = step, field = field, message = "Enter a number" } ]

        Just _ ->
            if NumberInput.isValid state then
                []

            else
                [ { step = step, field = field, message = rangeMessage } ]


deliveryProblems : Model -> List Problem
deliveryProblems m =
    List.concat
        [ numberProblems 2 Ids.leadTime "Lead time must be between 1 and 365 days" m.leadTime
        , case NumberInput.value m.leadTime of
            Just n ->
                if n /= toFloat (round n) then
                    [ { step = 2, field = Ids.leadTime, message = "Use whole days" } ]

                else
                    []

            Nothing ->
                []
        , numberProblems 2 Ids.minimumOrder "The minimum order cannot be negative" m.minimumOrder
        , nonEmptyList 2 Ids.deliversTo "Choose at least one country the supplier delivers to" (MultiSelect.values m.deliversTo)
        , requiredValue 2 Ids.paymentTerms "Choose the payment terms" (Select.value m.paymentTerms)
        ]


pricingProblems : Ref -> Model -> List Problem
pricingProblems ref m =
    let
        forRule i r =
            if String.trim r.name == "" then
                [ { step = 3, field = Ids.priceRuleRow i, message = "The rule needs a name" } ]

            else if Rule.conditionCount r.rule == 0 then
                [ { step = 3, field = Ids.priceRuleRow i, message = "The rule has no conditions" } ]

            else
                case Rule.validate Locale.en (RuleFields.fields ref) r.rule of
                    issue :: _ ->
                        [ { step = 3, field = Ids.priceRuleRow i, message = issue.message } ]

                    [] ->
                        if r.discountPercent <= 0 || r.discountPercent > 100 then
                            [ { step = 3, field = Ids.priceRuleRow i, message = "The discount must be between 0 and 100 percent" } ]

                        else
                            []
    in
    nonEmptyList 3 Ids.priceRules "Add at least one pricing rule" m.priceRules
        ++ List.concat (List.indexedMap forRule m.priceRules)


clientProblems : Ref -> Model -> List Problem
clientProblems ref m =
    List.concat [ companyProblems m, contactProblems m, deliveryProblems m, pricingProblems ref m ]


serverProblem : Backend.Problem -> Problem
serverProblem p =
    case p.field of
        Backend.Name ->
            { step = 0, field = Ids.name, message = p.message }

        Backend.LegalName ->
            { step = 0, field = Ids.legalName, message = p.message }

        Backend.Registration ->
            { step = 0, field = Ids.registration, message = p.message }

        Backend.Website ->
            { step = 0, field = Ids.website, message = p.message }

        Backend.CountryField ->
            { step = 0, field = Ids.country, message = p.message }

        Backend.ContactName i ->
            { step = 1, field = Ids.contactName i, message = p.message }

        Backend.ContactEmail i ->
            { step = 1, field = Ids.contactEmail i, message = p.message }

        Backend.ContactPhone i ->
            { step = 1, field = Ids.contactPhone i, message = p.message }

        Backend.LeadTime ->
            { step = 2, field = Ids.leadTime, message = p.message }

        Backend.MinimumOrder ->
            { step = 2, field = Ids.minimumOrder, message = p.message }

        Backend.PricingRule i ->
            { step = 3, field = Ids.priceRuleRow i, message = p.message }


-- KLAR GAP: merging server and client problems per field (O-019)
{-| The problems the user should see now: of the steps they have tried to leave (all of
them after a try on the review step), and the ones the server sent.
-}
visibleProblems : Ref -> Model -> List Problem
visibleProblems ref m =
    let
        client =
            if m.reviewAttempted then
                clientProblems ref m

            else
                clientProblems ref m |> List.filter (\p -> List.member p.step m.attempted)

        serverOnly =
            List.filter (\sp -> not (List.any (\p -> p.field == sp.field) client)) m.serverProblems
    in
    client ++ serverOnly


errorFor : List Problem -> String -> Maybe String
errorFor problems field =
    List.filter (\p -> p.field == field) problems |> List.head |> Maybe.map .message


-- KLAR GAP: field-tied server problems have no home in Klar (O-019)
{-| A server problem goes away as soon as the value it is about is edited.
-}
edited : Bool -> String -> Model -> Model
edited changed field m =
    if changed then
        { m | serverProblems = List.filter (\p -> p.field /= field) m.serverProblems }

    else
        m


firstFieldOf : Int -> String
firstFieldOf step =
    case step of
        0 ->
            Ids.name

        1 ->
            Ids.contactName 0

        2 ->
            Ids.leadTime

        3 ->
            Ids.priceRules

        _ ->
            Ids.flowForm



-- UPDATE


type TextField
    = NameField
    | LegalNameField
    | RegistrationField
    | WebsiteField
    | NotesField


type ContactField
    = ContactNameField
    | ContactEmailField
    | ContactPhoneField
    | ContactRoleField


type Msg
    = TextChanged TextField String
    | CountryMsg (Select.Msg CountryId)
    | CategoriesMsg (MultiSelect.Msg CategoryId)
    | CertificationsMsg TagInput.Msg
    | ContractMsg FileDrop.Msg
    | ContactChanged Int ContactField String
    | ContactPrimaryToggled Int Bool
    | AddContact
    | RemoveContact Int
    | LeadTimeMsg NumberInput.Msg
    | MinimumOrderMsg NumberInput.Msg
    | DeliversToMsg (MultiSelect.Msg CountryId)
    | PaymentTermsMsg (Select.Msg PaymentTermsId)
    | AddRule
    | EditRule Int
    | RemoveRule Int
    | EditorModalMsg Modal.Msg
    | RuleNameChanged String
    | DiscountMsg NumberInput.Msg
    | BuilderMsg RuleBuilder.Msg
    | SaveRule
    | CancelRule
    | GoStep Int
    | Back
    | Submit
    | Retry
    | FocusField String
    | SaveArrived Supplier (Result Remote.Problem ())
    | ConflictModalMsg Modal.Msg
    | OpenConflict
    | OverwriteMine
    | AskTakeTheirs
    | TakeTheirsMsg ConfirmDialog.Msg
    | ConfirmTakeTheirs
    | CancelTakeTheirs
    | KeepEditing
    | OpenSaved
    | Cancel
    | ReloadRef
    | NoOp


saveButtonId : String
saveButtonId =
    "flow-save-button"


addRuleButtonId : String
addRuleButtonId =
    "pricing-add-rule"


update : Ctx -> Msg -> Model -> ( Model, Cmd Msg, List Out )
update ctx msg m =
    let
        ref =
            refOf ctx

        quiet ( model, cmd ) =
            ( model, cmd, [] )
    in
    case msg of
        NoOp ->
            ( m, Cmd.none, [] )

        ReloadRef ->
            ( m, Cmd.none, [ ReloadReference ] )

        TextChanged field value ->
            case field of
                NameField ->
                    ( edited True Ids.name { m | name = value }, Cmd.none, [] )

                LegalNameField ->
                    ( edited True Ids.legalName { m | legalName = value }, Cmd.none, [] )

                RegistrationField ->
                    ( edited True Ids.registration { m | registration = value }, Cmd.none, [] )

                WebsiteField ->
                    ( edited True Ids.website { m | website = value }, Cmd.none, [] )

                NotesField ->
                    ( { m | notes = value }, Cmd.none, [] )

        CountryMsg inner ->
            let
                ( s, cmd ) =
                    Select.update inner m.country
            in
            quiet ( edited (Select.value s /= Select.value m.country) Ids.country { m | country = s }, Cmd.map CountryMsg cmd )

        CategoriesMsg inner ->
            let
                ( s, cmd ) =
                    MultiSelect.update inner m.categories
            in
            quiet ( { m | categories = s }, Cmd.map CategoriesMsg cmd )

        CertificationsMsg inner ->
            let
                ( s, cmd ) =
                    TagInput.update inner m.certifications
            in
            quiet ( { m | certifications = s }, Cmd.map CertificationsMsg cmd )

        ContractMsg inner ->
            let
                ( s, cmd ) =
                    FileDrop.update inner m.contract
            in
            quiet ( { m | contract = s }, Cmd.map ContractMsg cmd )

        ContactChanged i field value ->
            let
                change c =
                    case field of
                        ContactNameField ->
                            { c | name = value }

                        ContactEmailField ->
                            { c | email = value }

                        ContactPhoneField ->
                            { c | phone = value }

                        ContactRoleField ->
                            { c | role = value }

                fieldId =
                    case field of
                        ContactNameField ->
                            Ids.contactName i

                        ContactEmailField ->
                            Ids.contactEmail i

                        ContactPhoneField ->
                            Ids.contactPhone i

                        ContactRoleField ->
                            Ids.contactRole i
            in
            ( edited True fieldId { m | contacts = List.indexedMap (\j c -> if j == i then change c else c) m.contacts }
            , Cmd.none
            , []
            )

        ContactPrimaryToggled i on ->
            ( { m | contacts = List.indexedMap (\j c -> { c | primary = on && j == i || (not on && c.primary && j /= i) }) m.contacts }
            , Cmd.none
            , []
            )

        AddContact ->
            ( { m | contacts = m.contacts ++ [ emptyContact (List.isEmpty m.contacts) ] }
            , Form.focusField (Ids.contactName (List.length m.contacts)) NoOp
            , []
            )

        RemoveContact i ->
            ( { m | contacts = List.indexedMap Tuple.pair m.contacts |> List.filter (\( j, _ ) -> j /= i) |> List.map Tuple.second }
            , Form.focusField Ids.contacts NoOp
            , []
            )

        LeadTimeMsg inner ->
            let
                ( s, cmd ) =
                    NumberInput.update inner m.leadTime
            in
            quiet ( edited (NumberInput.value s /= NumberInput.value m.leadTime) Ids.leadTime { m | leadTime = s }, Cmd.map LeadTimeMsg cmd )

        MinimumOrderMsg inner ->
            let
                ( s, cmd ) =
                    NumberInput.update inner m.minimumOrder
            in
            quiet ( { m | minimumOrder = s }, Cmd.map MinimumOrderMsg cmd )

        DeliversToMsg inner ->
            let
                ( s, cmd ) =
                    MultiSelect.update inner m.deliversTo
            in
            quiet ( { m | deliversTo = s }, Cmd.map DeliversToMsg cmd )

        PaymentTermsMsg inner ->
            let
                ( s, cmd ) =
                    Select.update inner m.paymentTerms
            in
            quiet ( { m | paymentTerms = s }, Cmd.map PaymentTermsMsg cmd )

        -- Pricing rules
        AddRule ->
            openEditor addRuleButtonId Nothing { name = "", rule = Rule.emptyGroup, discountPercent = 0 } m

        EditRule i ->
            case List.drop i m.priceRules |> List.head of
                Just r ->
                    openEditor (Ids.priceRuleRow i ++ "-edit") (Just i) r m

                Nothing ->
                    ( m, Cmd.none, [] )

        RemoveRule i ->
            ( { m
                | priceRules = List.indexedMap Tuple.pair m.priceRules |> List.filter (\( j, _ ) -> j /= i) |> List.map Tuple.second
                , serverProblems = List.filter (\p -> p.step /= 3) m.serverProblems
              }
            , Form.focusField addRuleButtonId NoOp
            , []
            )

        EditorModalMsg inner ->
            let
                ( s, cmd ) =
                    Modal.update inner m.editorModal
            in
            quiet ( { m | editorModal = s }, Cmd.map EditorModalMsg cmd )

        RuleNameChanged value ->
            ( mapEditor (\e -> { e | name = value }) m, Cmd.none, [] )

        DiscountMsg inner ->
            case m.editor of
                Just e ->
                    let
                        ( s, cmd ) =
                            NumberInput.update inner e.discount
                    in
                    quiet ( { m | editor = Just { e | discount = s } }, Cmd.map DiscountMsg cmd )

                Nothing ->
                    ( m, Cmd.none, [] )

        BuilderMsg inner ->
            case m.editor of
                Just e ->
                    let
                        ( s, cmd ) =
                            RuleBuilder.update inner e.builder
                    in
                    quiet ( { m | editor = Just { e | builder = s } }, Cmd.map BuilderMsg cmd )

                Nothing ->
                    ( m, Cmd.none, [] )

        SaveRule ->
            case m.editor of
                Just e ->
                    let
                        rule =
                            RuleBuilder.rule e.builder

                        discount =
                            NumberInput.value e.discount

                        ok =
                            String.trim e.name /= ""
                                && Rule.conditionCount rule > 0
                                && List.isEmpty (Rule.validate Locale.en (RuleFields.fields ref) rule)
                                && NumberInput.isValid e.discount
                                && discount /= Nothing
                    in
                    if ok then
                        let
                            newRule =
                                { name = String.trim e.name, rule = rule, discountPercent = Maybe.withDefault 0 discount }

                            rules =
                                case e.index of
                                    Just i ->
                                        List.indexedMap (\j r -> if j == i then newRule else r) m.priceRules

                                    Nothing ->
                                        m.priceRules ++ [ newRule ]

                            ( modal, cmd ) =
                                Modal.close m.editorModal
                        in
                        ( { m | priceRules = rules, editor = Nothing, editorModal = modal, serverProblems = List.filter (\p -> p.step /= 3) m.serverProblems }
                        , Cmd.map EditorModalMsg cmd
                        , []
                        )

                    else
                        ( { m | editor = Just { e | attempted = True, builder = RuleBuilder.showIssues e.builder } }, Cmd.none, [] )

                Nothing ->
                    ( m, Cmd.none, [] )

        CancelRule ->
            let
                ( modal, cmd ) =
                    Modal.close m.editorModal
            in
            ( { m | editor = Nothing, editorModal = modal }, Cmd.map EditorModalMsg cmd, [] )

        -- Steps
        GoStep i ->
            if i <= m.furthest && i /= m.step then
                ( { m | step = i, attempted = markAttempted m.step m.attempted }, Form.focusField (firstFieldOf i) NoOp, [] )

            else
                ( m, Cmd.none, [] )

        Back ->
            ( { m | step = max 0 (m.step - 1), attempted = markAttempted m.step m.attempted }
            , Form.focusField (firstFieldOf (max 0 (m.step - 1))) NoOp
            , []
            )

        Retry ->
            send ctx m False

        Submit ->
            if m.status == Form.Submitting then
                ( m, Cmd.none, [] )

            else if m.step < lastStep then
                let
                    own =
                        clientProblems ref m |> List.filter (\p -> p.step == m.step)
                in
                if List.isEmpty own then
                    ( { m | step = m.step + 1, furthest = max m.furthest (m.step + 1), attempted = markAttempted m.step m.attempted }
                    , Form.focusField (firstFieldOf (m.step + 1)) NoOp
                    , []
                    )

                else
                    ( { m | attempted = markAttempted m.step m.attempted }, Form.focusSummary Ids.flowForm NoOp, [] )

            else if List.isEmpty (clientProblems ref m) then
                send ctx m False

            else
                ( { m | reviewAttempted = True }, Form.focusSummary Ids.flowForm NoOp, [] )

        FocusField field ->
            let
                step =
                    (clientProblems ref m ++ m.serverProblems)
                        |> List.filter (\p -> p.field == field)
                        |> List.head
                        |> Maybe.map .step
                        |> Maybe.withDefault m.step
            in
            ( { m | step = step }, Form.focusField field NoOp, [] )

        SaveArrived submitted result ->
            case result of
                Err problem ->
                    ( { m | status = Form.Failed problem }
                    , Cmd.none
                    , [ FaultUsed, ToastOut Theme.Danger "Could not save the supplier. Nothing you entered was lost." ]
                    )

                Ok () ->
                    case Backend.save ctx.store submitted of
                        Ok ( saved, store ) ->
                            ( withBaseline
                                { m
                                    | mode = Editing saved.id
                                    , baseVersion = saved.version
                                    , status = Form.Succeeded ("Saved as version " ++ String.fromInt saved.version ++ ".")
                                    , serverProblems = []
                                    , conflict = Nothing
                                }
                            , Cmd.none
                            , [ FaultUsed, StoreChanged store, ToastOut Theme.Success (saved.name ++ " was saved.") ]
                            )

                        Err (Backend.Invalid problems) ->
                            let
                                converted =
                                    List.map serverProblem problems
                            in
                            ( { m
                                | status =
                                    Form.Failed
                                        (Remote.problem Remote.validation
                                            |> Remote.withTitle "The server rejected the supplier"
                                            |> Remote.withDetail (String.fromInt (List.length converted) ++ " fields need attention. Nothing you entered was lost.")
                                        )
                                , serverProblems = converted
                                , reviewAttempted = True
                                , step = lastStep
                              }
                            , Form.focusSummary Ids.flowForm NoOp
                            , [ FaultUsed, ToastOut Theme.Danger "The server found problems with the supplier." ]
                            )

                        Err (Backend.Conflict theirs) ->
                            let
                                ( modal, cmd ) =
                                    Modal.open saveButtonId m.conflictModal
                            in
                            ( { m
                                | conflict = Just theirs
                                , conflictModal = modal
                                , status =
                                    Form.Failed
                                        (Remote.problem Remote.conflict
                                            |> Remote.withDetail "Someone else changed this supplier while you were editing."
                                        )
                              }
                            , Cmd.map ConflictModalMsg cmd
                            , [ FaultUsed ]
                            )

        ConflictModalMsg inner ->
            let
                ( s, cmd ) =
                    Modal.update inner m.conflictModal
            in
            quiet ( { m | conflictModal = s }, Cmd.map ConflictModalMsg cmd )

        OpenConflict ->
            let
                ( modal, cmd ) =
                    Modal.open saveButtonId m.conflictModal
            in
            quiet ( { m | conflictModal = modal }, Cmd.map ConflictModalMsg cmd )

        KeepEditing ->
            let
                ( modal, cmd ) =
                    Modal.close m.conflictModal
            in
            quiet ( { m | conflictModal = modal }, Cmd.map ConflictModalMsg cmd )

        OverwriteMine ->
            case m.conflict of
                Just theirs ->
                    let
                        ( modal, cmd ) =
                            Modal.close m.conflictModal

                        ( sent, sendCmd, outs ) =
                            send ctx { m | baseVersion = theirs.version, conflictModal = modal } False
                    in
                    ( sent, Cmd.batch [ Cmd.map ConflictModalMsg cmd, sendCmd ], outs )

                Nothing ->
                    ( m, Cmd.none, [] )

        AskTakeTheirs ->
            let
                ( dialog, cmd ) =
                    ConfirmDialog.open "conflict-take-theirs" m.takeTheirs
            in
            quiet ( { m | takeTheirs = dialog }, Cmd.map TakeTheirsMsg cmd )

        TakeTheirsMsg inner ->
            let
                ( s, cmd ) =
                    ConfirmDialog.update inner m.takeTheirs
            in
            quiet ( { m | takeTheirs = s }, Cmd.map TakeTheirsMsg cmd )

        CancelTakeTheirs ->
            let
                ( dialog, cmd ) =
                    ConfirmDialog.close m.takeTheirs
            in
            quiet ( { m | takeTheirs = dialog }, Cmd.map TakeTheirsMsg cmd )

        ConfirmTakeTheirs ->
            case m.conflict of
                Just theirs ->
                    let
                        fresh =
                            init (Just theirs)
                    in
                    ( { fresh | step = lastStep, furthest = lastStep, reviewAttempted = False }
                    , Form.focusField Ids.flowForm NoOp
                    , [ ToastOut Theme.Info "Loaded the latest version of the supplier." ]
                    )

                Nothing ->
                    ( m, Cmd.none, [] )

        Cancel ->
            ( m
            , Cmd.none
            , [ Navigate
                    (case m.mode of
                        Editing id ->
                            "#/suppliers/" ++ supplierIdToString id

                        Creating ->
                            "#/"
                    )
              ]
            )

        OpenSaved ->
            case m.mode of
                Editing id ->
                    ( m, Cmd.none, [ Navigate ("#/suppliers/" ++ supplierIdToString id) ] )

                Creating ->
                    ( m, Cmd.none, [] )


markAttempted : Int -> List Int -> List Int
markAttempted step attempted =
    if step < lastStep && not (List.member step attempted) then
        step :: attempted

    else
        attempted


send : Ctx -> Model -> Bool -> ( Model, Cmd Msg, List Out )
send ctx m _ =
    case toSupplier m of
        Just supplier ->
            ( { m | status = Form.Submitting }
            , Cmd.batch [ Api.call ctx.sim (SaveArrived supplier), Form.focusStatus Ids.flowForm NoOp ]
            , []
            )

        Nothing ->
            ( m, Cmd.none, [] )


openEditor : String -> Maybe Int -> PriceRule -> Model -> ( Model, Cmd Msg, List Out )
openEditor opener index r m =
    let
        ( modal, cmd ) =
            Modal.openWith { opener = opener, focus = [ Ids.priceRuleName ] } m.editorModal
    in
    ( { m
        | editor =
            Just
                { index = index
                , name = r.name
                , discount =
                    NumberInput.init Ids.priceRuleDiscount
                        |> NumberInput.setLimits discountAttrs
                        |> NumberInput.setValue
                            (if r.discountPercent == 0 then
                                Nothing

                             else
                                Just r.discountPercent
                            )
                , builder = RuleBuilder.init Ids.ruleBuilder |> RuleBuilder.setRule r.rule
                , attempted = False
                }
        , editorModal = modal
      }
    , Cmd.map EditorModalMsg cmd
    , []
    )


mapEditor : (Editor -> Editor) -> Model -> Model
mapEditor f m =
    { m | editor = Maybe.map f m.editor }



-- VIEW


view : Ctx -> Model -> Html Msg
view ctx m =
    let
        ref =
            refOf ctx

        visible =
            visibleProblems ref m

        hasProblems step =
            List.any (\p -> p.step == step) visible

        steps =
            List.indexedMap
                (\i name ->
                    Stepper.step name
                        |> (if hasProblems i then
                                Stepper.failed

                            else
                                identity
                           )
                        |> (if i > m.furthest then
                                Stepper.disabledStep

                            else
                                identity
                           )
                )
                stepNames

        title =
            case m.mode of
                Creating ->
                    "New supplier"

                Editing _ ->
                    "Edit " ++ m.name
    in
    Layout.stack [ Layout.gap 5 ]
        [ Text.title title
        , Stepper.view [ Stepper.current m.step, Stepper.onSelect GoStep, Stepper.ariaLabel "Onboarding steps" ] steps
        , Form.view (formAttributes m)
            [ summary ref m visible
            , stepBody ctx ref m visible
            , actions m
            ]
        ]


formAttributes : Model -> List (Form.Attribute Msg)
formAttributes m =
    [ Form.id Ids.flowForm
    , Form.ariaLabel "Supplier onboarding"
    , Form.onSubmit Submit
    , Form.onFocusField FocusField
    , Form.onRetry Retry
    , Form.labels
        (List.concat
            [ [ ( Ids.name, "Name" )
              , ( Ids.legalName, "Legal name" )
              , ( Ids.registration, "Registration number" )
              , ( Ids.website, "Website" )
              , ( Ids.country, "Country" )
              , ( Ids.categories, "Categories" )
              , ( Ids.contract, "Contract" )
              , ( Ids.contacts, "Contacts" )
              , ( Ids.leadTime, "Lead time" )
              , ( Ids.minimumOrder, "Minimum order" )
              , ( Ids.deliversTo, "Delivers to" )
              , ( Ids.paymentTerms, "Payment terms" )
              , ( Ids.priceRules, "Pricing rules" )
              ]
            , List.indexedMap
                (\i _ ->
                    [ ( Ids.contactName i, "Contact " ++ String.fromInt (i + 1) ++ " name" )
                    , ( Ids.contactEmail i, "Contact " ++ String.fromInt (i + 1) ++ " email" )
                    , ( Ids.contactPhone i, "Contact " ++ String.fromInt (i + 1) ++ " phone" )
                    , ( Ids.contactPrimary i, "Primary contact" )
                    ]
                )
                m.contacts
                |> List.concat
            , List.indexedMap (\i r -> ( Ids.priceRuleRow i, "Rule " ++ r.name )) m.priceRules
            ]
        )
    ]


summary : Ref -> Model -> List Problem -> Html Msg
summary _ m visible =
    let
        shown =
            if m.step == lastStep then
                visible

            else
                List.filter (\p -> p.step == m.step) visible
    in
    Form.errorSummary (formAttributes m) (List.map (\p -> { field = p.field, message = p.message }) shown)


actions : Model -> Html Msg
actions m =
    let
        last =
            m.step == lastStep
    in
    Form.actions
        [ Button.view [ Button.ghost, Button.onClick Cancel ] "Cancel"
        , Form.unsavedFlag [] (isDirty m)
        , Layout.spacer
        , Form.status (formAttributes m) m.status
        , if m.status == Form.Submitting then
            Html.text ""

          else
            case ( m.status, m.mode ) of
                ( Form.Succeeded _, Editing _ ) ->
                    Button.view [ Button.id "flow-open-saved", Button.onClick OpenSaved, Button.iconRight Icon.arrowRight ] "Open supplier"

                _ ->
                    Html.text ""
        , if m.step > 0 then
            Button.view [ Button.onClick Back, Button.icon Icon.arrowLeft ] "Back"

          else
            Html.text ""
        , Button.view
            [ Button.id saveButtonId
            , Button.primary
            , Button.submit
            , Button.loading (m.status == Form.Submitting)
            ]
            (if last then
                "Save supplier"

             else
                "Next"
            )
        ]


stepBody : Ctx -> Ref -> Model -> List Problem -> Html Msg
stepBody ctx ref m visible =
    case m.step of
        0 ->
            companyStep ctx m (errorFor visible)

        1 ->
            contactsStep m (errorFor visible)

        2 ->
            deliveryStep ctx m (errorFor visible)

        3 ->
            pricingStep ref m (errorFor visible)

        _ ->
            reviewStep ref m visible


countryOptions : Remote (List Country) -> Remote (List (Select.Option CountryId))
countryOptions =
    Remote.map (List.map (\c -> Select.option c.id c.name |> Select.withDescription c.code))


companyStep : Ctx -> Model -> (String -> Maybe String) -> Html Msg
companyStep ctx m err =
    Form.section "Company"
        "Who the supplier is, as registered."
        [ Form.grid 2
            [ TextInput.view
                [ TextInput.id Ids.name
                , TextInput.label "Name"
                , TextInput.hint "How the supplier appears in lists."
                , TextInput.required
                , TextInput.value m.name
                , TextInput.onInput (TextChanged NameField)
                , TextInput.errorMaybe (err Ids.name)
                ]
            , TextInput.view
                [ TextInput.id Ids.legalName
                , TextInput.label "Legal name"
                , TextInput.required
                , TextInput.value m.legalName
                , TextInput.onInput (TextChanged LegalNameField)
                , TextInput.errorMaybe (err Ids.legalName)
                ]
            , TextInput.view
                [ TextInput.id Ids.registration
                , TextInput.label "Registration number"
                , TextInput.hint "8 digits."
                , TextInput.required
                , TextInput.value m.registration
                , TextInput.onInput (TextChanged RegistrationField)
                , TextInput.errorMaybe (err Ids.registration)
                ]
            , TextInput.view
                [ TextInput.id Ids.website
                , TextInput.label "Website"
                , TextInput.url
                , TextInput.optionalText "(optional)"
                , TextInput.value m.website
                , TextInput.onInput (TextChanged WebsiteField)
                , TextInput.errorMaybe (err Ids.website)
                ]
            , Select.view CountryMsg
                [ Select.label "Country"
                , Select.required
                , Select.remote (countryOptions ctx.countries)
                , Select.onRetry ReloadRef
                , Select.valueText (\(CountryId code) -> code)
                , Select.errorMaybe (err Ids.country)
                ]
                m.country
            , MultiSelect.view CategoriesMsg
                [ MultiSelect.label "Product categories"
                , MultiSelect.required
                , MultiSelect.remote
                    (Remote.map
                        (List.map (\c -> Select.option c.id c.name |> Select.withGroup c.group))
                        ctx.categories
                    )
                , MultiSelect.onRetry ReloadRef
                , MultiSelect.valueText (\(CategoryId n) -> "Category " ++ String.fromInt n)
                , MultiSelect.errorMaybe (err Ids.categories)
                ]
                m.categories
            , Form.fullRow
                (TagInput.view CertificationsMsg
                    [ TagInput.label "Certifications"
                    , TagInput.optionalText "(optional)"
                    , TagInput.placeholder "Type a certification and press Enter"
                    , TagInput.hint "For example ISO 9001."
                    , TagInput.maxTags 10
                    ]
                    m.certifications
                )
            , Form.fullRow
                (FileDrop.view ContractMsg
                    [ FileDrop.label "Signed contract"
                    , FileDrop.required
                    , FileDrop.accept [ ".pdf" ]
                    , FileDrop.maxSize 5000000
                    , FileDrop.maxFiles 1
                    , FileDrop.errorMaybe (err Ids.contract)
                    ]
                    m.contract
                )
            ]
        ]


contactsStep : Model -> (String -> Maybe String) -> Html Msg
contactsStep m err =
    let
        contactCard i c =
            Card.view
                [ Card.title ("Contact " ++ String.fromInt (i + 1))
                , Card.actions
                    [ if List.length m.contacts > 1 then
                        Button.view
                            [ Button.small
                            , Button.ghost
                            , Button.danger
                            , Button.icon Icon.trash
                            , Button.ariaLabel ("Remove contact " ++ String.fromInt (i + 1))
                            , Button.onClick (RemoveContact i)
                            ]
                            "Remove"

                      else
                        Html.text ""
                    ]
                ]
                [ Form.grid 2
                    [ TextInput.view
                        [ TextInput.id (Ids.contactName i)
                        , TextInput.label "Name"
                        , TextInput.required
                        , TextInput.value c.name
                        , TextInput.onInput (ContactChanged i ContactNameField)
                        , TextInput.errorMaybe (err (Ids.contactName i))
                        ]
                    , TextInput.view
                        [ TextInput.id (Ids.contactRole i)
                        , TextInput.label "Role"
                        , TextInput.optionalText "(optional)"
                        , TextInput.value c.role
                        , TextInput.onInput (ContactChanged i ContactRoleField)
                        ]
                    , TextInput.view
                        [ TextInput.id (Ids.contactEmail i)
                        , TextInput.label "Email"
                        , TextInput.email
                        , TextInput.required
                        , TextInput.value c.email
                        , TextInput.onInput (ContactChanged i ContactEmailField)
                        , TextInput.errorMaybe (err (Ids.contactEmail i))
                        ]
                    , TextInput.view
                        [ TextInput.id (Ids.contactPhone i)
                        , TextInput.label "Phone"
                        , TextInput.tel
                        , TextInput.optionalText "(optional)"
                        , TextInput.value c.phone
                        , TextInput.onInput (ContactChanged i ContactPhoneField)
                        , TextInput.errorMaybe (err (Ids.contactPhone i))
                        ]
                    , Form.fullRow
                        (Switch.view
                            [ Switch.id (Ids.contactPrimary i)
                            , Switch.label "Primary contact"
                            , Switch.checked c.primary
                            , Switch.onToggle (ContactPrimaryToggled i)
                            , case err (Ids.contactPrimary i) of
                                Just message ->
                                    Switch.error message

                                Nothing ->
                                    Switch.description "Receives orders and invoices."
                            ]
                        )
                    ]
                ]
    in
    Form.section "Contacts"
        "The people we talk to. Exactly one is the primary contact."
        (List.indexedMap contactCard m.contacts
            ++ [ Layout.row [ Layout.gap 3, Layout.alignCenter ]
                    [ Button.view [ Button.id Ids.contacts, Button.icon Icon.userPlus, Button.onClick AddContact ] "Add contact"
                    , case err Ids.contacts of
                        Just message ->
                            Text.text message

                        Nothing ->
                            Html.text ""
                    ]
               ]
        )


deliveryStep : Ctx -> Model -> (String -> Maybe String) -> Html Msg
deliveryStep ctx m err =
    Form.section "Delivery terms"
        "How fast and where the supplier delivers, and how we pay."
        [ Form.grid 2
            [ NumberInput.view LeadTimeMsg
                ([ NumberInput.label "Lead time"
                 , NumberInput.suffixText "days"
                 , NumberInput.required
                 , NumberInput.errorMaybe (err Ids.leadTime)
                 ]
                    ++ leadTimeAttrs
                )
                m.leadTime
            , NumberInput.view MinimumOrderMsg
                ([ NumberInput.label "Minimum order value"
                 , NumberInput.suffixText "EUR"
                 , NumberInput.required
                 , NumberInput.grouped
                 , NumberInput.errorMaybe (err Ids.minimumOrder)
                 ]
                    ++ minimumOrderAttrs
                )
                m.minimumOrder
            , Form.fullRow
                (MultiSelect.view DeliversToMsg
                    [ MultiSelect.label "Delivers to"
                    , MultiSelect.required
                    , MultiSelect.remote (countryOptions ctx.countries)
                    , MultiSelect.onRetry ReloadRef
                    , MultiSelect.valueText (\(CountryId code) -> code)
                    , MultiSelect.errorMaybe (err Ids.deliversTo)
                    ]
                    m.deliversTo
                )
            , Select.view PaymentTermsMsg
                [ Select.label "Payment terms"
                , Select.required
                , Select.remote (Remote.map (List.map (\t -> Select.option t.id t.label |> Select.withDescription t.description)) ctx.terms)
                , Select.onRetry ReloadRef
                , Select.valueText paymentTermsKey
                , Select.errorMaybe (err Ids.paymentTerms)
                ]
                m.paymentTerms
            , Form.fullRow
                (TextArea.view
                    [ TextArea.id Ids.notes
                    , TextArea.label "Delivery notes"
                    , TextArea.optionalText "(optional)"
                    , TextArea.value m.notes
                    , TextArea.onInput (TextChanged NotesField)
                    , TextArea.maxLength 300
                    , TextArea.rows 3
                    ]
                )
            ]
        ]


pricingStep : Ref -> Model -> (String -> Maybe String) -> Html Msg
pricingStep ref m err =
    let
        ruleCard i r =
            Card.view
                ([ Card.title r.name
                 , Card.id (Ids.priceRuleRow i)
                 , Card.actions
                    [ Button.view [ Button.id (Ids.priceRuleRow i ++ "-edit"), Button.small, Button.icon Icon.edit, Button.ariaLabel ("Edit rule " ++ r.name), Button.onClick (EditRule i) ] "Edit"
                    , Button.view [ Button.small, Button.ghost, Button.danger, Button.icon Icon.trash, Button.ariaLabel ("Remove rule " ++ r.name), Button.onClick (RemoveRule i) ] "Remove"
                    ]
                 ]
                    ++ (case err (Ids.priceRuleRow i) of
                            Just _ ->
                                [ Card.accent Theme.Danger ]

                            Nothing ->
                                []
                       )
                )
                [ Text.text (RuleFields.describe ref r.rule ++ ": " ++ String.fromFloat r.discountPercent ++ "% discount")
                , case err (Ids.priceRuleRow i) of
                    Just message ->
                        Alert.view [ Alert.tone Theme.Danger, Alert.compact ] message

                    Nothing ->
                        Html.text ""
                ]
    in
    Form.section "Pricing rules"
        "Discounts the supplier gives, built from conditions."
        (if List.isEmpty m.priceRules then
            [ EmptyState.view
                [ EmptyState.icon Icon.percent
                , EmptyState.title "No pricing rules yet"
                , EmptyState.description "Add a rule such as: if the category is Cables and the quantity is above 100, the discount is 5%."
                , EmptyState.action (Button.view [ Button.id addRuleButtonId, Button.primary, Button.icon Icon.plus, Button.onClick AddRule ] "Add pricing rule")
                ]
            , case err Ids.priceRules of
                Just message ->
                    Alert.view [ Alert.tone Theme.Danger, Alert.compact ] message

                Nothing ->
                    Html.text ""
            ]

         else
            List.indexedMap ruleCard m.priceRules
                ++ [ Button.view [ Button.id addRuleButtonId, Button.icon Icon.plus, Button.onClick AddRule ] "Add pricing rule" ]
        )


reviewStep : Ref -> Model -> List Problem -> Html Msg
reviewStep ref m visible =
    let
        countryName (CountryId code) =
            List.filter (\c -> c.id == CountryId code) ref.countries |> List.head |> Maybe.map .name |> Maybe.withDefault code

        categoryName id =
            List.filter (\c -> c.id == id) ref.categories |> List.head |> Maybe.map .name |> Maybe.withDefault (categoryKey id)

        termsName id =
            List.filter (\t -> t.id == id) ref.terms |> List.head |> Maybe.map .label |> Maybe.withDefault (paymentTermsKey id)

        section step title items =
            Card.view
                [ Card.title title
                , Card.actions [ Button.view [ Button.small, Button.icon Icon.edit, Button.onClick (GoStep step) ] "Edit" ]
                , if List.any (\p -> p.step == step) visible then
                    Card.accent Theme.Danger

                  else
                    Card.sunken
                ]
                [ DescriptionList.view [ DescriptionList.compact ] items ]

        draft =
            toDraft m

        dash text =
            if String.trim text == "" then
                "-"

            else
                text
    in
    Form.section "Review"
        "Check everything. Problems are listed above, each with a way to go to it."
        [ conflictAlert m
        , section 0
            "Company"
            [ DescriptionList.text "Name" (dash m.name)
            , DescriptionList.text "Legal name" (dash m.legalName)
            , DescriptionList.text "Registration number" (dash m.registration)
            , DescriptionList.text "Website" (dash m.website)
            , DescriptionList.text "Country" (draft.country |> Maybe.map countryName |> Maybe.withDefault "-")
            , DescriptionList.text "Categories" (draft.categories |> List.map categoryName |> String.join ", " |> dash)
            , DescriptionList.values "Certifications"
                (if List.isEmpty draft.certifications then
                    [ Html.text "-" ]

                 else
                    List.map (\t -> Tag.view [] t) draft.certifications
                )
            , DescriptionList.text "Contract" (draft.contract |> List.map .name |> String.join ", " |> dash)
            ]
        , section 1
            "Contacts"
            (List.map
                (\c ->
                    DescriptionList.text
                        (if c.primary then
                            c.name ++ " (primary)"

                         else
                            c.name
                        )
                        (c.email ++ (if c.phone == "" then "" else ", " ++ c.phone))
                )
                m.contacts
            )
        , section 2
            "Delivery terms"
            [ DescriptionList.text "Lead time" (draft.leadTime |> Maybe.map (\n -> String.fromFloat n ++ " days") |> Maybe.withDefault "-")
            , DescriptionList.text "Minimum order" (draft.minimumOrder |> Maybe.map (\n -> String.fromFloat n ++ " EUR") |> Maybe.withDefault "-")
            , DescriptionList.text "Delivers to" (draft.deliversTo |> List.map countryName |> String.join ", " |> dash)
            , DescriptionList.text "Payment terms" (draft.paymentTerms |> Maybe.map termsName |> Maybe.withDefault "-")
            , DescriptionList.text "Notes" (dash m.notes)
            ]
        , section 3
            "Pricing rules"
            (if List.isEmpty m.priceRules then
                [ DescriptionList.text "Rules" "-" ]

             else
                List.map (\r -> DescriptionList.text r.name (RuleFields.describe ref r.rule ++ ": " ++ String.fromFloat r.discountPercent ++ "%")) m.priceRules
            )
        ]


conflictAlert : Model -> Html Msg
conflictAlert m =
    case m.conflict of
        Just theirs ->
            Alert.view
                [ Alert.tone Theme.Warning
                , Alert.title "A newer version exists"
                , Alert.actions [ Button.view [ Button.small, Button.onClick OpenConflict ] "Resolve" ]
                ]
                ("Someone else saved version " ++ String.fromInt theirs.version ++ " of this supplier. Your input is still here.")

        Nothing ->
            Html.text ""



-- OVERLAYS


overlays : Ctx -> Model -> List (Html Msg)
overlays ctx m =
    [ editorModal ctx m
    , conflictDialog ctx m
    , ConfirmDialog.view TakeTheirsMsg
        [ ConfirmDialog.warning
        , ConfirmDialog.title "Discard your changes?"
        , ConfirmDialog.message "Your input will be replaced by the version that was saved by the other person."
        , ConfirmDialog.consequences (changedSections m)
        , ConfirmDialog.confirmLabel "Load their version"
        , ConfirmDialog.onConfirm ConfirmTakeTheirs
        , ConfirmDialog.onCancel CancelTakeTheirs
        ]
        m.takeTheirs
    ]


changedSections : Model -> List String
changedSections m =
    case ( m.conflict, toSupplier m ) of
        ( Just theirs, Just mine ) ->
            sectionsDiffering mine theirs |> List.map (\s -> s ++ " will be replaced")

        _ ->
            [ "All sections will be replaced" ]


sectionsDiffering : Supplier -> Supplier -> List String
sectionsDiffering mine theirs =
    List.filterMap identity
        [ if mine.name /= theirs.name || mine.legalName /= theirs.legalName || mine.registrationNumber /= theirs.registrationNumber || mine.website /= theirs.website || mine.country /= theirs.country || mine.categories /= theirs.categories || mine.certifications /= theirs.certifications || mine.contractFile /= theirs.contractFile then
            Just "Company"

          else
            Nothing
        , if mine.contacts /= theirs.contacts then
            Just "Contacts"

          else
            Nothing
        , if mine.delivery /= theirs.delivery then
            Just "Delivery terms"

          else
            Nothing
        , if mine.priceRules /= theirs.priceRules then
            Just "Pricing rules"

          else
            Nothing
        ]


conflictDialog : Ctx -> Model -> Html Msg
conflictDialog _ m =
    let
        differing =
            case ( m.conflict, toSupplier m ) of
                ( Just theirs, Just mine ) ->
                    sectionsDiffering mine theirs

                _ ->
                    []
    in
    Modal.view ConflictModalMsg
        [ Modal.title "Someone else changed this supplier"
        , Modal.small
        , Modal.static
        , Modal.footer
            [ Button.view [ Button.onClick KeepEditing ] "Keep editing"
            , Button.view [ Button.danger, Button.onClick AskTakeTheirs ] "Load their version"
            , Button.view [ Button.primary, Button.onClick OverwriteMine ] "Save mine over theirs"
            ]
        ]
        m.conflictModal
        [ Layout.stack [ Layout.gap 3 ]
            [ Text.paragraph
                (case m.conflict of
                    Just theirs ->
                        "Version " ++ String.fromInt theirs.version ++ " was saved while you were working on version " ++ String.fromInt (theirs.version - 1) ++ ". Everything you entered is still here."

                    Nothing ->
                        ""
                )
            , if List.isEmpty differing then
                Text.muted "Your input and the saved version are the same."

              else
                Layout.stack [ Layout.gap 1 ]
                    (Text.strong "Sections that differ:" :: List.map Text.paragraph differing)
            ]
        ]


editorModal : Ctx -> Model -> Html Msg
editorModal ctx m =
    let
        ref =
            refOf ctx

        fields =
            RuleFields.fields ref
    in
    case m.editor of
        Nothing ->
            Modal.view EditorModalMsg [ Modal.title "Pricing rule" ] m.editorModal []

        Just e ->
            let
                rule =
                    RuleBuilder.rule e.builder

                nameError =
                    if e.attempted && String.trim e.name == "" then
                        Just "Give the rule a name"

                    else
                        Nothing

                discountError =
                    if e.attempted && NumberInput.value e.discount == Nothing then
                        Just "Enter the discount"

                    else
                        Nothing
            in
            Modal.view EditorModalMsg
                [ Modal.title
                    (case e.index of
                        Just _ ->
                            "Edit pricing rule"

                        Nothing ->
                            "New pricing rule"
                    )
                , Modal.large
                , Modal.footer
                    [ Button.view [ Button.onClick CancelRule ] "Cancel"
                    , Button.view [ Button.primary, Button.onClick SaveRule ] "Save rule"
                    ]
                ]
                m.editorModal
                [ Layout.stack [ Layout.gap 4 ]
                    [ TextInput.view
                        [ TextInput.id Ids.priceRuleName
                        , TextInput.label "Rule name"
                        , TextInput.required
                        , TextInput.value e.name
                        , TextInput.onInput RuleNameChanged
                        , TextInput.errorMaybe nameError
                        ]
                    , Text.strong "If"
                    , RuleBuilder.view BuilderMsg
                        [ RuleBuilder.fields fields
                        , RuleBuilder.label "Conditions of the pricing rule"
                        ]
                        e.builder
                    , if e.attempted && Rule.conditionCount rule == 0 then
                        Alert.view [ Alert.tone Theme.Danger, Alert.compact ] "Add at least one condition."

                      else
                        Html.text ""
                    , Text.strong "Then"
                    , NumberInput.view DiscountMsg
                        ([ NumberInput.label "Discount"
                         , NumberInput.suffixText "%"
                         , NumberInput.required
                         , NumberInput.errorMaybe discountError
                         ]
                            ++ discountAttrs
                        )
                        e.discount
                    ]
                ]
