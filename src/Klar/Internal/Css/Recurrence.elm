module Klar.Internal.Css.Recurrence exposing (css)

{-| The rules of `recurrence`, part of the stylesheet of the package. Edit the CSS here;
`Klar.Internal.Css` puts the parts together in order.
-}


css : String
css =
    """
/* Recurrence, RecurrencePicker. */

/* ---- The field ------------------------------------------------------- */

/* A fieldset with a legend, like the radio and checkbox groups. */
.klar-recurrence {
  min-width: 0;
  margin: 0;
  padding: 0;
  border: 0;
}

.klar-recurrence__legend {
  display: block;
  padding: 0;
  margin-bottom: 6px;
}

/* The parts that are shown depend on the frequency. They are keyed children of
   one column, so a part that comes or goes does not move the others in the DOM. */
.klar-recurrence__body {
  display: flex;
  flex-direction: column;
  gap: var(--klar-space-3);
  min-width: 0;
}

/* The five frequencies keep their words: in a narrow column they go onto a second
   line, and are not cut down to "D.." and "W..". */
.klar-recurrence .klar-segmented { flex-wrap: wrap; }
.klar-recurrence .klar-segmented__item { flex: 0 0 auto; }
.klar-recurrence .klar-segmented__label { overflow: visible; text-overflow: clip; }

.klar-recurrence__interval,
.klar-recurrence__end-field {
  max-width: 260px;
}

.klar-recurrence__weekdays,
.klar-recurrence__by,
.klar-recurrence__missing {
  min-width: 0;
}

.klar-recurrence__end {
  display: flex;
  flex-direction: column;
  gap: var(--klar-space-2);
  min-width: 0;
}

/* The reason why the last weekday did not turn off. The element is always in
   the page (a live region has to be there before its text comes), and takes no
   room while it is empty. */
.klar-recurrence__note {
  margin: 0;
  font-size: var(--klar-text-sm);
  color: var(--klar-text-secondary);
}

.klar-recurrence__note:not(:empty) {
  margin-top: var(--klar-space-1);
}

/* ---- The sentence and the next dates -------------------------------- */

.klar-recurrence__summary {
  margin: 0;
  padding: var(--klar-space-2) var(--klar-space-3);
  border: 1px solid var(--klar-border-subtle);
  border-radius: var(--klar-radius);
  background: var(--klar-surface-subtle);
  color: var(--klar-text);
  font-weight: var(--klar-weight-medium);
  overflow-wrap: anywhere;
}

/* An empty live region is kept but draws nothing. */
.klar-recurrence__summary:empty {
  padding: 0;
  border: 0;
}

.klar-recurrence--readonly .klar-recurrence__summary {
  padding: 0;
  border: 0;
  background: none;
}

.klar-recurrence--invalid .klar-recurrence__summary {
  border-color: var(--klar-danger-border);
}

.klar-recurrence__preview {
  display: flex;
  flex-direction: column;
  gap: var(--klar-space-1);
  min-width: 0;
}

.klar-recurrence__preview-title {
  margin: 0;
  font-size: var(--klar-text-sm);
  font-weight: var(--klar-weight-medium);
  color: var(--klar-text-secondary);
}

.klar-recurrence__dates {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(12rem, 1fr));
  gap: var(--klar-space-1) var(--klar-space-4);
  margin: 0;
  padding: 0;
  list-style: none;
  font-variant-numeric: tabular-nums;
}

.klar-recurrence__date {
  min-width: 0;
  color: var(--klar-text);
}

.klar-recurrence__more,
.klar-recurrence__none {
  margin: 0;
  color: var(--klar-text-muted);
}

/* ---- Skipped dates --------------------------------------------------- */

.klar-recurrence__skipped {
  display: flex;
  flex-direction: column;
  align-items: flex-start;
  gap: var(--klar-space-1);
  min-width: 0;
}

.klar-recurrence__skipped-title {
  margin: 0;
  font-size: var(--klar-text-sm);
  font-weight: var(--klar-weight-medium);
  color: var(--klar-text-secondary);
}

.klar-recurrence__skipped-list {
  display: flex;
  flex-wrap: wrap;
  gap: var(--klar-space-1) var(--klar-space-2);
  margin: 0;
  padding: 0;
  list-style: none;
}

.klar-recurrence__skipped-item {
  min-width: 0;
}
"""
