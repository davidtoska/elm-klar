module Klar.Internal.Css exposing (css)

{-| The stylesheet of the package: the parts in `Klar.Internal.Css.*`, in the order the
rules must come (tokens first, density last). A new part is a new module here and a line
in this list.
-}

import Klar.Internal.Css.Access as Access
import Klar.Internal.Css.Actions as Actions
import Klar.Internal.Css.Ai as Ai
import Klar.Internal.Css.Arranging as Arranging
import Klar.Internal.Css.Base as Base
import Klar.Internal.Css.Budget as Budget
import Klar.Internal.Css.CodeQuantity as CodeQuantity
import Klar.Internal.Css.Comments as Comments
import Klar.Internal.Css.Core as Core
import Klar.Internal.Css.DateTime as DateTime
import Klar.Internal.Css.Density as Density
import Klar.Internal.Css.Display as Display
import Klar.Internal.Css.Flow as Flow
import Klar.Internal.Css.Forms as Forms
import Klar.Internal.Css.Icons as Icons
import Klar.Internal.Css.Kanban as Kanban
import Klar.Internal.Css.Markdown as Markdown
import Klar.Internal.Css.Navigation as Navigation
import Klar.Internal.Css.Overlay as Overlay
import Klar.Internal.Css.Picking as Picking
import Klar.Internal.Css.Recurrence as Recurrence
import Klar.Internal.Css.Review as Review
import Klar.Internal.Css.Rules as Rules
import Klar.Internal.Css.Select as Select
import Klar.Internal.Css.Stale as Stale
import Klar.Internal.Css.Structured as Structured
import Klar.Internal.Css.Table as Table
import Klar.Internal.Css.Tokens as Tokens
import Klar.Internal.Css.Uploads as Uploads
import Klar.Internal.Css.Workbench as Workbench
import Klar.Internal.Css.Workflow as Workflow


{-| All rules of the library.
-}
css : String
css =
    String.join "\n"
        [ Tokens.css
        , Base.css
        , Icons.css
        , Core.css
        , Stale.css
        , Forms.css
        , Select.css
        , DateTime.css
        , Table.css
        , Budget.css
        , Navigation.css
        , Display.css
        , Overlay.css
        , Rules.css
        , Arranging.css
        , Actions.css
        , Flow.css
        , Markdown.css
        , Review.css
        , Structured.css
        , Picking.css
        , Access.css
        , Recurrence.css
        , Workbench.css
        , Comments.css
        , Kanban.css
        , Uploads.css
        , CodeQuantity.css
        , Ai.css
        , Workflow.css
        , Density.css
        ]
