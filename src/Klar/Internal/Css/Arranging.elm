module Klar.Internal.Css.Arranging exposing (css)

{-| The rules of `arranging`, part of the stylesheet of the package. Edit the CSS here;
`Klar.Internal.Css` puts the parts together in order.
-}


css : String
css =
    """
/* ==========================================================================
   Arranging: Sortable, Splitter
   ========================================================================== */

/* ==========================================================================
   Sortable
   ========================================================================== */

.klar-sortable {
  --_gap: var(--klar-space-1);
  position: relative;
  min-width: 0;
}

.klar-sortable__list {
  display: flex;
  flex-direction: column;
  gap: var(--_gap);
  margin: 0;
  padding: 0;
  list-style: none;
}

.klar-sortable--horizontal .klar-sortable__list {
  flex-direction: row;
  flex-wrap: wrap;
}

.klar-sortable__item {
  position: relative;
  display: flex;
  align-items: center;
  gap: var(--klar-space-2);
  min-width: 0;
  min-height: var(--klar-control);
  padding: var(--klar-space-1) var(--klar-space-3) var(--klar-space-1) var(--klar-space-1);
  border: 1px solid var(--klar-border);
  border-radius: var(--klar-radius);
  background: var(--klar-surface);
  color: var(--klar-text);
  transition:
    background var(--klar-dur-fast) var(--klar-ease),
    border-color var(--klar-dur-fast) var(--klar-ease),
    box-shadow var(--klar-dur-fast) var(--klar-ease);
}

.klar-sortable--horizontal .klar-sortable__item {
  flex: 0 1 auto;
  min-height: var(--klar-control-sm);
  padding-right: var(--klar-space-2);
}

.klar-sortable__content {
  flex: 1 1 auto;
  min-width: 0;
}

.klar-sortable--horizontal .klar-sortable__content {
  flex: 0 1 auto;
}

/* ---- The move buttons (`moveButtons`): the way that needs no dragging ------ */

.klar-sortable__moves {
  display: inline-flex;
  flex: none;
  gap: var(--klar-space-1);
}

.klar-sortable__move {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  width: var(--klar-control-sm);
  height: var(--klar-control-sm);
  padding: 0;
  border: 1px solid transparent;
  border-radius: var(--klar-radius);
  background: transparent;
  color: var(--klar-text-secondary);
  font: inherit;
  cursor: pointer;
}

.klar-sortable__move:hover { background: var(--klar-surface-hover); color: var(--klar-text); }

.klar-sortable__move:focus-visible {
  outline: 2px solid var(--klar-focus-color);
  outline-offset: 1px;
}

.klar-sortable__move[aria-disabled="true"],
.klar-sortable__move[aria-disabled="true"]:hover {
  background: transparent;
  color: var(--klar-text-disabled);
  cursor: default;
}

@media (forced-colors: active) {
  .klar-sortable__move { border-color: ButtonText; }
  .klar-sortable__move[aria-disabled="true"] { border-color: GrayText; color: GrayText; }
}

/* ---- The handle: a button that is a tab stop of its own ---------------- */

.klar-sortable__handle {
  display: inline-flex;
  flex: none;
  align-items: center;
  justify-content: center;
  width: 24px;
  height: 24px;
  padding: 0;
  border: 0;
  border-radius: var(--klar-radius);
  background: transparent;
  color: var(--klar-text-muted);
  cursor: grab;
  /* A finger that goes down on the handle drags; it must not scroll the page. */
  touch-action: none;
  -webkit-user-select: none;
  user-select: none;
  -webkit-touch-callout: none;
}

.klar-sortable__handle:hover {
  background: var(--klar-gray-150);
  color: var(--klar-text);
}

.klar-sortable__handle:focus-visible {
  outline: 2px solid var(--klar-focus-color);
  outline-offset: 1px;
}

.klar-sortable__handle[aria-pressed="true"] {
  background: var(--klar-primary);
  color: var(--klar-on-primary);
  cursor: grabbing;
}

.klar-sortable__lock {
  display: inline-flex;
  flex: none;
  align-items: center;
  justify-content: center;
  width: 24px;
  height: 24px;
  color: var(--klar-text-muted);
}

.klar-sortable__item--fixed {
  background: var(--klar-surface-subtle);
}

/* The whole item can be taken hold of (wholeItem). */
.klar-sortable__item--grab {
  cursor: grab;
}

/* ---- Held: the item stays where it is and looks lifted ----------------- */

.klar-sortable__item--lifted {
  border-color: var(--klar-primary);
  background: var(--klar-primary-subtle);
  box-shadow: var(--klar-shadow-md);
}

.klar-sortable--dragging {
  -webkit-user-select: none;
  user-select: none;
}

.klar-sortable--dragging .klar-sortable__handle,
.klar-sortable--dragging .klar-sortable__item--grab {
  cursor: grabbing;
}

/* The line that shows where the item would land. It is drawn in the gap
   between two items and takes no room, so nothing moves. */

.klar-sortable__item--drop-before::before,
.klar-sortable__item--drop-after::after {
  content: "";
  position: absolute;
  z-index: 1;
  left: 0;
  right: 0;
  height: 2px;
  border-radius: var(--klar-radius-full);
  background: var(--klar-primary);
  pointer-events: none;
}

.klar-sortable__item--drop-before::before { top: calc(var(--_gap) / -2 - 1px); }
.klar-sortable__item--drop-after::after { bottom: calc(var(--_gap) / -2 - 1px); }

.klar-sortable--horizontal .klar-sortable__item--drop-before::before,
.klar-sortable--horizontal .klar-sortable__item--drop-after::after {
  top: 0;
  bottom: 0;
  left: auto;
  right: auto;
  width: 2px;
  height: auto;
}

.klar-sortable--horizontal .klar-sortable__item--drop-before::before { left: calc(var(--_gap) / -2 - 1px); }
.klar-sortable--horizontal .klar-sortable__item--drop-after::after { right: calc(var(--_gap) / -2 - 1px); }

/* ---- Held with the pointer: one cursor for the window, a label that follows -- */

.klar-sortable__extras { display: contents; }

.klar-sortable__layer {
  position: fixed;
  inset: 0;
  z-index: var(--klar-z-tooltip);
  background: transparent;
  cursor: grabbing;
  -webkit-user-select: none;
  user-select: none;
}

.klar-sortable__ghost {
  position: fixed;
  top: 0;
  left: 0;
  z-index: calc(var(--klar-z-tooltip) + 1);
  max-width: 260px;
  padding: var(--klar-space-1) var(--klar-space-2);
  border-radius: var(--klar-radius);
  background: var(--klar-gray-800);
  color: var(--klar-white);
  font-size: var(--klar-text-sm);
  line-height: var(--klar-leading-tight);
  box-shadow: var(--klar-shadow-md);
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
  pointer-events: none;
  transform: translate(calc(var(--klar-x, 0px) + 14px), calc(var(--klar-y, 0px) + 14px));
}

/* A finger covers what is below it: the label goes above it. */
.klar-sortable__ghost--touch {
  transform: translate(calc(var(--klar-x, 0px) - 40px), calc(var(--klar-y, 0px) - 56px));
}

/* ---- States ------------------------------------------------------------- */

.klar-sortable--disabled .klar-sortable__handle {
  opacity: 0.4;
  cursor: not-allowed;
}

.klar-sortable--disabled .klar-sortable__handle:hover {
  background: transparent;
  color: var(--klar-text-muted);
}

.klar-sortable__empty {
  padding: var(--klar-space-4);
  border: 1px dashed var(--klar-border-strong);
  border-radius: var(--klar-radius);
  color: var(--klar-text-muted);
  text-align: center;
}

@media (prefers-reduced-motion: reduce) {
  .klar-sortable__item { transition: none; }
}

@media (forced-colors: active) {
  .klar-sortable__item--drop-before::before,
  .klar-sortable__item--drop-after::after {
    forced-color-adjust: none;
    background: Highlight;
  }

  .klar-sortable__item--lifted {
    outline: 2px solid Highlight;
    outline-offset: -2px;
  }
}

/* ==========================================================================
   Splitter
   ========================================================================== */

.klar-splitter {
  /* The width of the strip between two panes. Klar.Splitter.Machine.gutter says
     the same in pixels: change both. */
  --klar-split-gutter: 8px;
  position: relative;
  display: flex;
  flex-direction: row;
  width: 100%;
  height: var(--klar-split-h, 100%);
  min-width: 0;
  min-height: 0;
  /* The panes keep their pixel minimums (--klar-min). When those add up to more than
     the container has (a phone, a narrow column), the panes would spill out of it and
     the last one could not be reached: the splitter scrolls sideways instead. */
  overflow-x: auto;
  overflow-y: hidden;
}

.klar-splitter--stacked {
  flex-direction: column;
  overflow-x: hidden;
  overflow-y: auto;
}
.klar-splitter--fill-rest { height: auto; }

/* A pane shares the room that is left by its size (--klar-grow is a number: the
   panes' numbers add up to 100). It starts at nothing and grows, so the share is
   exact; and it may be smaller than its content (min-width: 0), which a flex
   item does not allow by default - that is what makes a pane scroll instead of
   pushing the others out. */
.klar-splitter__pane {
  position: relative;
  flex: var(--klar-grow, 1) 1 0px;
  min-width: var(--klar-min, 0px);
  max-width: var(--klar-max, none);
  min-height: 0;
  overflow: auto;
}

.klar-splitter--stacked > .klar-splitter__pane {
  min-width: 0;
  max-width: none;
  min-height: var(--klar-min, 0px);
  max-height: var(--klar-max, none);
}

/* A folded pane has no room, and it is not there for the keyboard and for screen
   readers either. Its content stays in the page. */
.klar-splitter__pane--folded {
  min-width: 0;
  min-height: 0;
  overflow: hidden;
  visibility: hidden;
}

.klar-splitter__separator {
  position: relative;
  z-index: 1;
  flex: none;
  width: var(--klar-split-gutter);
  cursor: col-resize;
  /* A finger that goes down on a separator drags it; it must not scroll the page. */
  touch-action: none;
  -webkit-user-select: none;
  user-select: none;
  -webkit-touch-callout: none;
}

.klar-splitter--stacked > .klar-splitter__separator {
  width: auto;
  height: var(--klar-split-gutter);
  cursor: row-resize;
}

/* The line: thin until the pointer or the keyboard is on the separator. It is
   drawn over the strip, so nothing moves when it grows. */
.klar-splitter__separator::before {
  content: "";
  position: absolute;
  top: 0;
  bottom: 0;
  left: 50%;
  width: 1px;
  margin-left: -0.5px;
  background: var(--klar-border);
  transition: background var(--klar-dur-fast) var(--klar-ease), width var(--klar-dur-fast) var(--klar-ease), margin var(--klar-dur-fast) var(--klar-ease);
}

.klar-splitter--stacked > .klar-splitter__separator::before {
  top: 50%;
  bottom: auto;
  left: 0;
  right: 0;
  width: auto;
  height: 1px;
  margin: -0.5px 0 0;
}

.klar-splitter__separator:hover::before,
.klar-splitter__separator:focus-visible::before,
.klar-splitter__separator--active::before {
  width: 3px;
  margin-left: -1.5px;
  background: var(--klar-primary);
}

.klar-splitter--stacked > .klar-splitter__separator:hover::before,
.klar-splitter--stacked > .klar-splitter__separator:focus-visible::before,
.klar-splitter--stacked > .klar-splitter__separator--active::before {
  width: auto;
  height: 3px;
  margin: -1.5px 0 0;
}

.klar-splitter__separator:focus-visible {
  outline: 2px solid var(--klar-focus-color);
  outline-offset: -2px;
  border-radius: var(--klar-radius);
}

/* A finger needs more to aim at than a mouse: the hit area reaches into the panes. */
@media (pointer: coarse) {
  .klar-splitter__separator::after {
    content: "";
    position: absolute;
    inset: 0 -8px;
  }

  .klar-splitter--stacked > .klar-splitter__separator::after { inset: -8px 0; }
}

.klar-splitter--dragging {
  -webkit-user-select: none;
  user-select: none;
}

/* While the mouse drags, a layer over the window keeps the cursor, keeps text from
   being selected and keeps the mouse from reaching what is below. */
.klar-splitter__layer {
  position: fixed;
  inset: 0;
  z-index: var(--klar-z-tooltip);
  background: transparent;
  cursor: col-resize;
  -webkit-user-select: none;
  user-select: none;
}

.klar-splitter--stacked > .klar-splitter__layer { cursor: row-resize; }

@media (prefers-reduced-motion: reduce) {
  .klar-splitter__separator::before { transition: none; }
}

@media (forced-colors: active) {
  .klar-splitter__separator::before {
    forced-color-adjust: none;
    background: ButtonText;
  }

  .klar-splitter__separator:hover::before,
  .klar-splitter__separator:focus-visible::before,
  .klar-splitter__separator--active::before { background: Highlight; }
}
"""
