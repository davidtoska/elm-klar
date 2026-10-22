module Ids exposing
    ( assignDialog
    , assignPerson
    , bulkAssign
    , drawer
    , filters
    , help
    , linesTable
    , mainNav
    , netMenu
    , newViewDialog
    , newViewName
    , noteField
    , orders
    , ordersSearch
    , palette
    , shareDialog
    , shell
    , statusButton
    , statusDialog
    , tabs
    , userMenu
    , views
    )

{-| The DOM ids of the page, in one place so that none is used twice.
-}


shell : String
shell =
    "app-shell"


mainNav : String
mainNav =
    "main-nav"


userMenu : String
userMenu =
    "user-menu"


netMenu : String
netMenu =
    "net-menu"


orders : String
orders =
    "orders"


ordersSearch : String
ordersSearch =
    "orders-search"


filters : String
filters =
    "order-filters"


views : String
views =
    "order-views"


drawer : String
drawer =
    "order-drawer"


tabs : String
tabs =
    "order-tabs"


linesTable : String
linesTable =
    "order-lines"


statusDialog : String
statusDialog =
    "status-dialog"


statusButton : String -> String
statusButton key =
    "status-to-" ++ key


noteField : String
noteField =
    "order-note"


bulkAssign : String
bulkAssign =
    "bulk-assign"


assignDialog : String
assignDialog =
    "assign-dialog"


assignPerson : String
assignPerson =
    "assign-person"


newViewDialog : String
newViewDialog =
    "new-view-dialog"


newViewName : String
newViewName =
    "new-view-name"


shareDialog : String
shareDialog =
    "share-view-dialog"


palette : String
palette =
    "palette"


help : String
help =
    "shortcut-help"
