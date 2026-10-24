module Klar.Internal.Css.Density exposing (css)

{-| The rules of `density`, part of the stylesheet of the package. Edit the CSS here;
`Klar.Internal.Css` puts the parts together in order.
-}


css : String
css =
    """
/* ==========================================================================
   Density of the whole application.

   The application states its density once (Klar.Settings, given to the app shell or to
   `Settings.scope`). The shell carries data-klar-density="compact" or "comfortable" (nothing for
   normal) and everything inside follows:

   - the control tokens below, which buttons, inputs and the triggers of selects already use;
   - the compact and comfortable rules of the components that have their own density, which are
     written next to each component as a second selector (`:where([data-klar-density=...])`).
     Those have the specificity of the component's own class and leave out a component that has
     its own explicit density, so `Table.setDensity` still wins for that table.

   The rows of a table, compare and permission matrix follow through those component rules, so
   --klar-row is not changed here.

   --klar-option-h (a row of a select, a picker, a transfer list or a time list) is not changed
   either: it stays 32px at every density, because Elm does the arithmetic of those lists in
   pixels (which rows to draw, where to scroll to bring the highlighted row into view) with a
   row of 32px (Select.Popup.rowHeight, TimePicker, VirtualList). A row of another height would
   put the highlighted row out of view and draw the wrong rows of a long list.
   ========================================================================== */

[data-klar-density="compact"] {
  /* --klar-control-sm stays 26px: smaller buttons in a group, which overlap by a border, fall under the 24px of a target */
  --klar-control: 28px;
  --klar-control-lg: 36px;
  --klar-control-px: 8px;
}

[data-klar-density="comfortable"] {
  --klar-control-sm: 32px;
  --klar-control: 40px;
  --klar-control-lg: 48px;
  --klar-control-px: 12px;
}

/* ---- Card ------------------------------------------------------------------ */

[data-klar-density="compact"] .klar-card__header { padding: var(--klar-space-2) var(--klar-space-3); }
[data-klar-density="compact"] .klar-card__body { padding: var(--klar-space-3); }
[data-klar-density="compact"] .klar-card__footer { padding: var(--klar-space-2) var(--klar-space-3); }

[data-klar-density="comfortable"] .klar-card__header { padding: var(--klar-space-4) var(--klar-space-5); }
[data-klar-density="comfortable"] .klar-card__body { padding: var(--klar-space-5); }
[data-klar-density="comfortable"] .klar-card__footer { padding: var(--klar-space-4) var(--klar-space-5); }

[data-klar-density] .klar-card--flush > .klar-card__body { padding: 0; }

/* ---- Stat ------------------------------------------------------------------ */

:where([data-klar-density="compact"]) .klar-stat:where(:not(.klar-stat--sm, .klar-stat--lg)) { --_fs: 20px; }
:where([data-klar-density="comfortable"]) .klar-stat:where(:not(.klar-stat--sm, .klar-stat--lg)) { --_fs: 30px; }

/* ---- Timeline --------------------------------------------------------------
   `Timeline.compact` is a different layout (a dot, one line, the time at the right), so the
   density only changes the space between the events of the usual layout. */

[data-klar-density="compact"] .klar-timeline:not(.klar-timeline--compact) .klar-timeline__item:not(:last-child) { padding-bottom: 8px; }
[data-klar-density="comfortable"] .klar-timeline:not(.klar-timeline--compact) .klar-timeline__item:not(:last-child) { padding-bottom: 20px; }

/* ---- The box of Settings.scope ------------------------------------------------ */

.klar-settings { display: contents; }
"""
