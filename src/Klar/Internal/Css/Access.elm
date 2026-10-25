module Klar.Internal.Css.Access exposing (css)

{-| The rules of `access`, part of the stylesheet of the package. Edit the CSS here;
`Klar.Internal.Css` puts the parts together in order.
-}


css : String
css =
    """
/* ==========================================================================
   Access and approval (Klar.PermissionMatrix, Klar.ApprovalFlow)

   PermissionMatrix:
     .klar-permissions                 frame, density variables
       .klar-permissions__toolbar      filter, number of unsaved changes, the application's buttons
       .klar-permissions__scroll       the scroll area: sticky headers and sticky first column
         table.klar-permissions__grid  role="grid"
       .klar-permissions__notes        counts, locked roles and their reasons

   ApprovalFlow:
     .klar-approval                    the list of steps, vertical or horizontal
   ========================================================================== */

/* ---- PermissionMatrix --------------------------------------------------- */

.klar-permissions {
  --_row-h: var(--klar-row);
  --_cell-px: var(--klar-space-3);
  --_font: var(--klar-text-md);
  --_label-w: 240px;
  /* wide enough for "Administrator" with its lock: at 124px the longest role name of the
     showcase was cut down to "Administrato..." */
  --_col-w: 132px;
  display: flex;
  flex-direction: column;
  min-width: 0;
  background: var(--klar-surface);
  border: 1px solid var(--klar-border);
  border-radius: var(--klar-radius-lg);
  overflow: clip;
  font-size: var(--_font);
}

/* The frame takes focus (Klar.focus with the id of init) when "Try again" goes away. */
.klar-permissions:focus { outline: none; }

.klar-permissions:focus-visible {
  outline: 2px solid var(--klar-focus-color);
  outline-offset: 2px;
}

/* An explicit density (a modifier) wins over the density of the application. */
.klar-permissions--normal {
  --_row-h: var(--klar-row);
  --_cell-px: var(--klar-space-3);
}

.klar-permissions--compact,
:where([data-klar-density="compact"]) .klar-permissions:where(:not(.klar-permissions--compact, .klar-permissions--normal, .klar-permissions--comfortable)) {
  --_row-h: var(--klar-row-compact);
  --_cell-px: var(--klar-space-2);
  --_font: var(--klar-text-sm);
  --_label-w: 210px;
  --_col-w: 108px;
}

.klar-permissions--comfortable,
:where([data-klar-density="comfortable"]) .klar-permissions:where(:not(.klar-permissions--compact, .klar-permissions--normal, .klar-permissions--comfortable)) {
  --_row-h: var(--klar-row-comfortable);
  --_cell-px: var(--klar-space-4);
}

/* A failure or an empty matrix sits in the frame with some room around it. */
.klar-permissions--failed,
.klar-permissions--empty { padding: var(--klar-space-2); }

/* ---- Toolbar and notes -------------------------------------------------- */

.klar-permissions__toolbar {
  display: flex;
  flex: none;
  flex-wrap: wrap;
  align-items: center;
  gap: var(--klar-space-2) var(--klar-space-3);
  padding: var(--klar-space-2) var(--klar-space-3);
  border-bottom: 1px solid var(--klar-border);
}

.klar-permissions__filter {
  flex: 1 1 200px;
  min-width: 160px;
  max-width: 320px;
}

.klar-permissions__changes {
  display: inline-flex;
  align-items: center;
  gap: 6px;
  min-height: 1em;
  color: var(--klar-text-secondary);
  font-size: var(--klar-text-sm);
}

.klar-permissions__changes--some {
  color: var(--klar-blue-700);
  font-weight: var(--klar-weight-medium);
}

.klar-permissions__actions {
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  gap: var(--klar-space-2);
  margin-left: auto;
}

.klar-permissions__notes {
  flex: none;
  display: flex;
  flex-direction: column;
  gap: var(--klar-space-1);
  padding: var(--klar-space-2) var(--klar-space-3);
  border-top: 1px solid var(--klar-border);
}


.klar-permissions__note {
  margin: 0;
  color: var(--klar-text-muted);
  font-size: var(--klar-text-sm);
}

.klar-permissions__note--warning {
  display: flex;
  align-items: center;
  gap: 6px;
  color: var(--klar-warning);
  font-weight: var(--klar-weight-medium);
}

.klar-permissions__locked-list {
  display: flex;
  flex-direction: column;
  gap: 2px;
  margin: 0;
  padding: 0;
  list-style: none;
  color: var(--klar-text-secondary);
  font-size: var(--klar-text-sm);
}

.klar-permissions__locked-list > li {
  display: flex;
  align-items: center;
  gap: 6px;
}

/* ---- The scroll area --------------------------------------------------- */

/* Both headers stay in view while the rest scrolls. The scroll padding keeps a
   cell that gets focus clear of the sticky header and the sticky first column. */
.klar-permissions__scroll {
  flex: 1 1 auto;
  min-height: 0;
  max-height: 70vh;
  overflow: auto;
  overscroll-behavior-x: contain;
  scroll-padding-top: var(--_row-h);
  scroll-padding-left: var(--_label-w);
}

.klar-permissions__grid {
  width: max(100%, calc(var(--_label-w) + var(--klar-pm-cols, 1) * var(--_col-w)));
  table-layout: fixed;
  border-collapse: separate;
  border-spacing: 0;
}

.klar-permissions__col-label { width: var(--_label-w); }
.klar-permissions__col-role { width: var(--_col-w); }

.klar-permissions__row { height: var(--_row-h); }
.klar-permissions__row--head { position: relative; }

/* ---- Headers ------------------------------------------------------------ */

.klar-permissions__th {
  height: var(--_row-h);
  padding: 0 var(--_cell-px);
  overflow: hidden;
  background: var(--klar-surface);
  border-bottom: 1px solid var(--klar-border-subtle);
  color: var(--klar-text);
  font-weight: var(--klar-weight);
  text-align: left;
  text-overflow: ellipsis;
  white-space: nowrap;
  vertical-align: middle;
}

/* Stacking of the sticky parts, lowest first: the first column and the group rows
   (z-sticky) are under the header row (z-sticky + 2), and the corner, which is both a
   header and a first column, is over everything (z-sticky + 3). */
.klar-permissions__th--role,
.klar-permissions__th--corner {
  position: sticky;
  top: 0;
  z-index: calc(var(--klar-z-sticky) + 2);
  background: var(--klar-gray-50);
  border-bottom-color: var(--klar-border);
  color: var(--klar-text-secondary);
  font-size: var(--klar-text-sm);
  font-weight: var(--klar-weight-bold);
}

.klar-permissions__th--role {
  text-align: center;
  border-left: 1px solid var(--klar-border-subtle);
}

.klar-permissions__th--locked { color: var(--klar-text-muted); }

.klar-permissions__th--permission,
.klar-permissions__th--group,
.klar-permissions__th--corner {
  position: sticky;
  left: 0;
  z-index: var(--klar-z-sticky);
  border-right: 1px solid var(--klar-border);
}

.klar-permissions__th--corner { z-index: calc(var(--klar-z-sticky) + 3); }

.klar-permissions__th--indented { padding-left: calc(var(--_cell-px) + 8px); }

.klar-permissions__th:focus,
.klar-permissions__cell:focus { outline: none; }

.klar-permissions__th:focus-visible,
.klar-permissions__cell:focus-visible {
  outline: 2px solid var(--klar-focus-color);
  outline-offset: -2px;
}

/* The checkbox of a header sits in front of the name, in line with it. */
.klar-permissions__th .klar-check {
  margin-right: 8px;
  vertical-align: middle;
}

.klar-permissions__name {
  display: inline-block;
  max-width: calc(100% - 32px);
  overflow: hidden;
  text-overflow: ellipsis;
  vertical-align: middle;
  white-space: nowrap;
}

.klar-permissions__th--group .klar-permissions__name { max-width: 100%; }

.klar-permissions__lock {
  display: inline-block;
  margin-left: 4px;
  vertical-align: middle;
  color: var(--klar-text-muted);
}

/* ---- Group rows ----------------------------------------------------------- */

.klar-permissions__row--group .klar-permissions__th,
.klar-permissions__row--group .klar-permissions__cell {
  background: var(--klar-gray-50);
  border-bottom-color: var(--klar-border);
}

.klar-permissions__th--group {
  color: var(--klar-text);
  font-weight: var(--klar-weight-bold);
  cursor: pointer;
}

.klar-permissions__chevron {
  display: inline-flex;
  margin-right: 4px;
  vertical-align: middle;
  color: var(--klar-text-muted);
  pointer-events: none;
}

.klar-permissions__group-name {
  display: inline-block;
  max-width: calc(100% - 64px);
  overflow: hidden;
  text-overflow: ellipsis;
  vertical-align: middle;
  white-space: nowrap;
}

.klar-permissions__count {
  display: inline-block;
  margin-left: 8px;
  color: var(--klar-text-muted);
  font-size: var(--klar-text-sm);
  font-weight: var(--klar-weight);
  vertical-align: middle;
}

.klar-permissions__cell--summary {
  color: var(--klar-text-muted);
  font-size: var(--klar-text-sm);
  cursor: pointer;
}

/* ---- Cells ---------------------------------------------------------------- */

.klar-permissions__cell {
  position: relative;
  height: var(--_row-h);
  padding: 0 4px;
  overflow: hidden;
  background: var(--klar-surface);
  border-bottom: 1px solid var(--klar-border-subtle);
  border-left: 1px solid var(--klar-border-subtle);
  text-align: center;
  vertical-align: middle;
}

/* What is inside a cell is decoration for the pointer and for screen readers: the
   cell itself carries the name and the events, and is always where a click lands. */
.klar-permissions__content {
  display: inline-flex;
  max-width: 100%;
  align-items: center;
  justify-content: center;
  gap: 6px;
  pointer-events: none;
}

.klar-permissions__mark {
  display: inline-flex;
  flex: none;
  align-items: center;
  justify-content: center;
  width: 18px;
  height: 18px;
  background: var(--klar-surface);
  border: 1px solid var(--klar-gray-400);
  border-radius: var(--klar-radius-sm);
  color: transparent;
}

.klar-permissions__cell--granted .klar-permissions__mark {
  background: var(--klar-primary);
  border-color: var(--klar-primary);
  color: var(--klar-on-primary);
}

.klar-permissions--readonly .klar-permissions__cell--denied .klar-permissions__mark {
  background: var(--klar-surface-sunken);
  border-color: var(--klar-border-strong);
  color: var(--klar-text-muted);
}

/* Inherited: a dashed box, so it differs from a direct value in shape. */
.klar-permissions__cell--inherited .klar-permissions__mark { border-style: dashed; }

.klar-permissions__cell--inherited.klar-permissions__cell--granted .klar-permissions__mark {
  background: var(--klar-primary-subtle);
  border-color: var(--klar-primary);
  color: var(--klar-primary);
}

.klar-permissions__word {
  min-width: 0;
  overflow: hidden;
  color: var(--klar-text-secondary);
  font-size: var(--klar-text-sm);
  text-overflow: ellipsis;
  white-space: nowrap;
}

.klar-permissions__cell--inherited .klar-permissions__word { color: var(--klar-text-muted); font-style: italic; }

/* An own access over an inherited one: a plain box, and a mark that goes back to inheriting. */
.klar-permissions__reset {
  position: absolute;
  top: 50%;
  right: 6px;
  display: none;
  align-items: center;
  justify-content: center;
  width: 20px;
  height: 20px;
  margin-top: -10px;
  background: var(--klar-surface);
  border: 1px solid var(--klar-border-strong);
  border-radius: var(--klar-radius);
  color: var(--klar-text-secondary);
  cursor: pointer;
}

.klar-permissions__reset * { pointer-events: none; }
.klar-permissions__reset:hover { background: var(--klar-surface-hover); color: var(--klar-text); }

.klar-permissions__cell--override:hover > .klar-permissions__reset,
.klar-permissions__cell--override:focus > .klar-permissions__reset { display: inline-flex; }

/* a small corner mark tells that the cell has an own value over an inherited one */
.klar-permissions__cell--override::before {
  content: "";
  position: absolute;
  top: 0;
  left: 0;
  border-top: 7px solid var(--klar-primary);
  border-right: 7px solid transparent;
}

.klar-permissions__cell--editable { cursor: pointer; }
.klar-permissions__cell--editable:hover { background: var(--klar-surface-hover); }
.klar-permissions__cell--editable:hover .klar-permissions__mark { border-color: var(--klar-primary); }

.klar-permissions__cell--locked {
  background: var(--klar-surface-subtle);
  cursor: not-allowed;
}

.klar-permissions__cell--locked .klar-permissions__mark { opacity: 0.7; }

/* An unsaved change: a dot in the corner (and "unsaved change" in the name). */
.klar-permissions__dot {
  display: inline-block;
  flex: none;
  width: 7px;
  height: 7px;
  background: var(--klar-primary);
  border-radius: 50%;
}

.klar-permissions__dot--cell {
  position: absolute;
  pointer-events: none;
  top: 5px;
  right: 6px;
  outline: 2px solid var(--klar-surface);
}

.klar-permissions__cell--changed { background: var(--klar-primary-subtle); }
.klar-permissions__cell--changed.klar-permissions__cell--editable:hover { background: var(--klar-primary-subtle-hover); }

@media (forced-colors: active) {
  .klar-permissions__cell--granted .klar-permissions__mark {
    forced-color-adjust: none;
    background: Highlight;
    border-color: Highlight;
    color: HighlightText;
  }

  /* inherited and granted: a dashed box with the check, in the same system colour */
  .klar-permissions__cell--inherited.klar-permissions__cell--granted .klar-permissions__mark {
    forced-color-adjust: none;
    background: Canvas;
    border-color: Highlight;
    color: Highlight;
  }

  /* the corner mark of an own value over an inherited one */
  .klar-permissions__cell--override::before {
    forced-color-adjust: none;
    border-top-color: CanvasText;
  }

  /* an unsaved change keeps more than its dot: a frame around the cell */
  .klar-permissions__cell--changed {
    outline: 1px dashed Highlight;
    outline-offset: -3px;
  }

  .klar-permissions__dot { forced-color-adjust: none; background: Highlight; }
}

/* ---- Skeleton -------------------------------------------------------------- */

.klar-permissions--skeleton { overflow: hidden; }

.klar-permissions__skeleton-row {
  display: grid;
  grid-template-columns: 2.4fr repeat(4, 1fr);
  align-items: center;
  justify-items: center;
  gap: var(--klar-space-3);
  height: var(--_row-h);
  padding: 0 var(--klar-space-3);
  border-bottom: 1px solid var(--klar-border-subtle);
}

.klar-permissions__skeleton-row > :first-child { justify-self: start; width: 100%; }
.klar-permissions__skeleton-row--head { background: var(--klar-gray-50); border-bottom-color: var(--klar-border); }

/* ---- ApprovalFlow ------------------------------------------------------------- */

.klar-approval {
  --_marker: 24px;
  display: flex;
  flex-direction: column;
  gap: var(--klar-space-3);
  min-width: 0;
}

/* Focused by Klar.focus with the ApprovalFlow.id, after the buttons that had focus are gone. */
.klar-approval:focus { outline: none; }

.klar-approval:focus-visible {
  outline: 2px solid var(--klar-focus-color);
  outline-offset: 2px;
  border-radius: var(--klar-radius-lg);
}

.klar-approval__summary {
  display: inline-flex;
  align-items: center;
  gap: 6px;
  margin: 0;
  color: var(--klar-blue-700);
  font-weight: var(--klar-weight-bold);
}

.klar-approval__summary--approved { color: var(--klar-success); }
.klar-approval__summary--rejected { color: var(--klar-danger); }
.klar-approval__summary--in-progress,
.klar-approval__summary--waiting,
.klar-approval__summary--skipped { color: var(--klar-blue-700); }

.klar-approval__steps {
  display: flex;
  flex-direction: column;
  margin: 0;
  padding: 0;
  list-style: none;
}

.klar-approval__step {
  position: relative;
  display: grid;
  grid-template-columns: var(--_marker) minmax(0, 1fr);
  column-gap: var(--klar-space-3);
  padding-bottom: var(--klar-space-4);
}

.klar-approval--vertical .klar-approval__steps { flex-direction: column; }

.klar-approval__step:last-child { padding-bottom: 0; }

/* The line to the next step: it starts under the marker and ends where the next marker begins. */
.klar-approval__step::before {
  content: "";
  position: absolute;
  top: var(--_marker);
  bottom: 0;
  left: calc(var(--_marker) / 2 - 0.5px);
  width: 1px;
  background: var(--klar-gray-300);
}

.klar-approval__step:last-child::before { display: none; }
.klar-approval__step--approved::before { background: var(--klar-success); }

.klar-approval__marker {
  display: inline-flex;
  grid-column: 1;
  align-items: center;
  justify-content: center;
  width: var(--_marker);
  height: var(--_marker);
  background: var(--klar-surface);
  border: 1.5px solid var(--klar-gray-300);
  border-radius: 50%;
  color: var(--klar-gray-600);
  font-size: var(--klar-text-sm);
  font-weight: var(--klar-weight-bold);
  line-height: 1;
  font-variant-numeric: tabular-nums;
}

.klar-approval__step--approved .klar-approval__marker {
  background: var(--klar-success);
  border-color: var(--klar-success);
  color: var(--klar-on-solid);
}

.klar-approval__step--rejected .klar-approval__marker {
  background: var(--klar-danger);
  border-color: var(--klar-danger);
  color: var(--klar-on-solid);
}

.klar-approval__step--in-progress .klar-approval__marker {
  background: var(--klar-blue-50);
  border-color: var(--klar-primary);
  color: var(--klar-blue-700);
  box-shadow: 0 0 0 3px var(--klar-primary-subtle-hover);
}

.klar-approval__step--skipped .klar-approval__marker {
  background: var(--klar-gray-50);
  border-style: dashed;
  color: var(--klar-gray-500);
}

.klar-approval__body {
  grid-column: 2;
  display: flex;
  flex-direction: column;
  gap: var(--klar-space-2);
  min-width: 0;
  padding: 2px 0 0;
}

/* The step that is being decided stands out: a frame, in the colour of what is going on. */
.klar-approval__step--current .klar-approval__body {
  margin: -6px 0 0 -8px;
  padding: 6px var(--klar-space-2) var(--klar-space-2);
  background: var(--klar-primary-subtle);
  border: 1px solid var(--klar-primary-border);
  border-radius: var(--klar-radius-lg);
}

.klar-approval__step--rejected.klar-approval__step--current .klar-approval__body {
  background: var(--klar-danger-subtle);
  border-color: var(--klar-danger-border);
}

.klar-approval__step--overdue.klar-approval__step--current .klar-approval__body {
  background: var(--klar-warning-subtle);
  border-color: var(--klar-warning-border);
}

.klar-approval__head {
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  gap: 2px var(--klar-space-3);
}

/* A heading (ApprovalFlow.headingLevel) that reads as the line it is. */
.klar-approval__title {
  margin: 0;
  color: var(--klar-text);
  font-size: inherit;
  font-weight: var(--klar-weight-bold);
  line-height: inherit;
}

.klar-approval__step--waiting .klar-approval__title,
.klar-approval__step--skipped .klar-approval__title { color: var(--klar-text-secondary); }

.klar-approval__status {
  display: inline-flex;
  align-items: center;
  gap: 4px;
  color: var(--klar-text-secondary);
  font-size: var(--klar-text-sm);
}

.klar-approval__step--approved .klar-approval__status { color: var(--klar-success); }
.klar-approval__step--rejected .klar-approval__status { color: var(--klar-danger); }
.klar-approval__step--in-progress .klar-approval__status { color: var(--klar-blue-700); }

.klar-approval__meta {
  display: flex;
  flex-wrap: wrap;
  gap: 0 var(--klar-space-3);
  margin: 0;
  color: var(--klar-text-muted);
  font-size: var(--klar-text-sm);
}

.klar-approval__due--overdue {
  color: var(--klar-danger);
  font-weight: var(--klar-weight-medium);
}

.klar-approval__due { white-space: nowrap; }
.klar-approval__time { white-space: nowrap; }

.klar-approval__people {
  display: flex;
  flex-direction: column;
  gap: var(--klar-space-2);
  margin: 0;
  padding: 0;
  list-style: none;
}

.klar-approval__person {
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  gap: 2px var(--klar-space-2);
  min-width: 0;
}

.klar-approval__name {
  min-width: 0;
  overflow: hidden;
  color: var(--klar-text);
  text-overflow: ellipsis;
  white-space: nowrap;
}

.klar-approval__you { color: var(--klar-text-muted); }

.klar-approval__decision {
  display: inline-flex;
  align-items: center;
  gap: 4px;
  color: var(--klar-text-secondary);
  font-size: var(--klar-text-sm);
}

.klar-approval__person--approved .klar-approval__decision { color: var(--klar-success); }
.klar-approval__person--rejected .klar-approval__decision { color: var(--klar-danger); }

/* Not asked on this step: not needed any more, not asked yet, or not reached. */
.klar-approval__person--idle .klar-approval__decision { color: var(--klar-text-muted); }

.klar-approval__when {
  color: var(--klar-text-muted);
  font-size: var(--klar-text-sm);
}

.klar-approval__when:empty { display: none; }

.klar-approval__comment {
  flex: 1 0 100%;
  margin: 2px 0 0 26px;
  padding-left: var(--klar-space-2);
  border-left: 2px solid var(--klar-border-strong);
  color: var(--klar-text-secondary);
  font-size: var(--klar-text-sm);
  overflow-wrap: anywhere;
}

.klar-approval__actions {
  display: flex;
  flex-wrap: wrap;
  gap: var(--klar-space-2);
  margin-top: var(--klar-space-1);
}

/* Side by side: the markers in a row, the line runs to the right. */
.klar-approval--horizontal .klar-approval__steps {
  flex-direction: row;
  padding: 4px 4px 8px;
  margin: -4px;
  overflow-x: auto;
  border-radius: var(--klar-radius);
}

/* The strip is a tab stop of its own, so it can be scrolled with the arrow keys. */
.klar-approval--horizontal .klar-approval__steps:focus { outline: none; }

.klar-approval--horizontal .klar-approval__steps:focus-visible {
  outline: 2px solid var(--klar-focus-color);
  outline-offset: -2px;
}

.klar-approval--horizontal .klar-approval__step {
  flex: 1 0 230px;
  display: flex;
  flex-direction: column;
  gap: var(--klar-space-2);
  padding: 0 var(--klar-space-4) 0 0;
}

.klar-approval--horizontal .klar-approval__step:last-child { flex: 0 0 auto; min-width: 230px; }

.klar-approval--horizontal .klar-approval__step::before {
  top: calc(var(--_marker) / 2 - 0.5px);
  right: var(--klar-space-2);
  bottom: auto;
  left: calc(var(--_marker) + var(--klar-space-2));
  width: auto;
  height: 1px;
}

.klar-approval--horizontal .klar-approval__step--current .klar-approval__body { margin-left: 0; }

/* ---- Skeleton, failure, empty --------------------------------------------------- */

.klar-approval--skeleton { gap: var(--klar-space-4); }

/* The failure and the empty state sit in the same root, under an old data marker if any. */
.klar-approval--failed,
.klar-approval--empty { gap: var(--klar-space-2); }

.klar-approval__skeleton-step {
  display: flex;
  align-items: flex-start;
  gap: var(--klar-space-3);
}

.klar-approval__skeleton-text {
  display: flex;
  flex: 1 1 auto;
  flex-direction: column;
  gap: var(--klar-space-2);
  padding-top: 4px;
}

@media (forced-colors: active) {
  .klar-approval__marker { forced-color-adjust: none; border-color: CanvasText; }
  .klar-approval__step--approved .klar-approval__marker,
  .klar-approval__step--rejected .klar-approval__marker { background: Highlight; color: HighlightText; }

  /* the step being decided: its ring is a box-shadow, which forced colours remove */
  .klar-approval__step--in-progress .klar-approval__marker { outline: 2px solid Highlight; outline-offset: 1px; }
  .klar-approval__step--current .klar-approval__body { border-color: Highlight; }
}
"""
