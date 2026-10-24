module Klar.Internal.Css.Select exposing (css)

{-| The rules of `select`, part of the stylesheet of the package. Edit the CSS here;
`Klar.Internal.Css` puts the parts together in order.
-}


css : String
css =
    """
/* ==========================================================================
   Select family: Select, MultiSelect, Autocomplete, and the VirtualList they
   render their options with. Every row (options, group headings, skeleton
   rows) is exactly --klar-option-h high, so long lists can be windowed and
   keyboard navigation can scroll by arithmetic.
   ========================================================================== */

/* ---- Virtual list ---------------------------------------------------- */

.klar-vlist {
  position: relative;
  overflow-x: hidden;
  overflow-y: auto;
  overscroll-behavior: contain;
  outline: none;
}

.klar-vlist__spacer {
  pointer-events: none;
}

/* ---- A list of rows of its own (VirtualList.list) ----------------------- */

.klar-vlist--list {
  margin: 0;
  padding: 0;
  list-style: none;
  background: var(--klar-surface);
  border: 1px solid var(--klar-border);
  border-radius: var(--klar-radius-lg);
  box-sizing: content-box;
}

.klar-vlist--list:focus-visible {
  outline: 2px solid var(--klar-focus-color);
  outline-offset: -2px;
}

/* Every row is as high as the list says (--klar-vlist-row): what does not fit is cut. */
.klar-vlist__item {
  display: flex;
  flex-direction: column;
  justify-content: center;
  box-sizing: border-box;
  height: var(--klar-vlist-row);
  overflow: hidden;
  border-bottom: 1px solid var(--klar-border-subtle);
  list-style: none;
}

.klar-vlist__item > .klar-list-item { flex: 1 1 auto; min-height: 0; }
.klar-vlist__item .klar-list-item__main { min-height: 0; height: 100%; }

.klar-vlist--interactive .klar-vlist__item { cursor: pointer; }
.klar-vlist--interactive .klar-vlist__item:hover { background: var(--klar-surface-hover); }

.klar-vlist__item--selected,
.klar-vlist--interactive .klar-vlist__item--selected:hover { background: var(--klar-primary-subtle); }

/* The active row is marked while the list has the focus. */
.klar-vlist--list:focus-visible .klar-vlist__item--active {
  outline: 2px solid var(--klar-focus-color);
  outline-offset: -2px;
}

/* The pinned section heading is a sticky first child that takes no room:
   it sits on top of the first visible row while the rows scroll under it. */
.klar-vlist__pinned {
  position: sticky;
  top: 0;
  z-index: 1;
  height: 0;
}

.klar-vlist__pinned--active {
  height: var(--klar-vlist-row);
  margin-bottom: calc(-1 * var(--klar-vlist-row));
}

/* ---- Field (the closed select) -------------------------------------- */

.klar-select,
.klar-autocomplete {
  width: 100%;
}

.klar-select__control {
  position: relative;
  gap: 4px;
  padding-right: 6px;
  cursor: pointer;
}

.klar-select__control.klar-input--disabled {
  cursor: not-allowed;
}

.klar-select__control.klar-input--readonly {
  cursor: default;
}

.klar-select--open > .klar-select__control {
  border-color: var(--klar-focus-color);
  box-shadow: var(--klar-focus-ring);
}

.klar-select--open > .klar-select__control.klar-input--invalid {
  border-color: var(--klar-danger);
  box-shadow: 0 0 0 3px var(--klar-red-100);
}

.klar-select__trigger {
  display: flex;
  align-items: center;
  gap: 6px;
  flex: 1 1 auto;
  min-width: 0;
  height: 100%;
  padding: 0;
  border: 0;
  background: transparent;
  color: inherit;
  font: inherit;
  text-align: left;
  cursor: inherit;
}

.klar-select__trigger:focus,
.klar-select__trigger:focus-visible {
  outline: none;
}

.klar-select__trigger:disabled {
  color: inherit;
  cursor: not-allowed;
}

.klar-select__value,
.klar-select__placeholder {
  min-width: 0;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.klar-select__placeholder,
.klar-select__value--unknown {
  color: var(--klar-text-muted);
}

.klar-input--disabled .klar-select__placeholder,
.klar-input--disabled .klar-select__value--unknown {
  color: var(--klar-text-disabled);
}

.klar-select__value-icon {
  display: flex;
  flex: none;
  color: var(--klar-text-secondary);
}

.klar-select__chevron {
  display: flex;
  flex: none;
  color: var(--klar-text-muted);
  pointer-events: none;
  transition: transform var(--klar-dur-fast) var(--klar-ease);
}

.klar-select--open .klar-select__chevron {
  transform: rotate(180deg);
}

.klar-input--disabled .klar-select__chevron {
  color: var(--klar-text-disabled);
}

/* ---- Multi select: chips in the field -------------------------------- */

.klar-select__control--multi,
.klar-select__control--multi.klar-input--md {
  height: auto;
  min-height: var(--klar-control);
  padding-top: 4px;
  padding-bottom: 4px;
}

.klar-select__control--multi.klar-input--sm {
  height: auto;
  min-height: var(--klar-control-sm);
  padding-top: 3px;
  padding-bottom: 3px;
}

.klar-select__control--multi.klar-input--lg {
  height: auto;
  min-height: var(--klar-control-lg);
  padding-top: 8px;
  padding-bottom: 8px;
}

/* A transparent button under the chips: the field's focus target and
   combobox; clicks between the chips land on it. */
.klar-select__trigger--overlay {
  position: absolute;
  inset: 0;
  z-index: 0;
  width: 100%;
  height: 100%;
  border-radius: inherit;
}

.klar-select__chips {
  position: relative;
  z-index: 1;
  display: flex;
  flex: 1 1 auto;
  flex-wrap: wrap;
  align-items: center;
  gap: 4px;
  min-width: 0;
  pointer-events: none;
}

.klar-select__chip {
  display: inline-flex;
  min-width: 0;
  max-width: 100%;
  pointer-events: auto;
}

.klar-select__more .klar-tag {
  color: var(--klar-text-secondary);
}

/* A chosen value whose label has not arrived yet (or could not be fetched). */
.klar-select__chip--unknown .klar-tag {
  color: var(--klar-text-muted);
}

.klar-select__control--multi .klar-select__clear,
.klar-select__control--multi .klar-select__chevron {
  position: relative;
  z-index: 1;
}

.klar-input--disabled .klar-select__chip {
  opacity: 0.7;
}

/* ---- Popup ----------------------------------------------------------- */

.klar-select__popup {
  display: flex;
  flex-direction: column;
  width: 100%;
  min-width: 260px;
  max-width: calc(100vw - 16px);
  padding: 0;
  overflow: hidden;
}

/* Room for the counts and the two actions in the footer. */
.klar-select--multi .klar-select__popup {
  min-width: 340px;
}

@supports (anchor-name: --klar-a) and (position-anchor: --klar-a) and (anchor-scope: --klar-a) {
  /* As wide as the field at least, and as wide as the longest option (with its
     description) up to a limit, so descriptions are not cut. */
  .klar-select__popup {
    width: max-content;
    min-width: max(260px, anchor-size(width));
    max-width: min(36rem, calc(100vw - 16px));
  }
}

/* A popup wider than its field (the 340px of a multi select on a phone) may
   fit neither left-aligned nor right-aligned with the field: then it keeps to
   the window edge instead of being cut off. */
@position-try --klar-select-below-edge {
  top: anchor(bottom);
  bottom: auto;
  left: auto;
  right: 8px;
  margin: 4px 0 0;
}

@position-try --klar-select-above-edge {
  top: auto;
  bottom: anchor(top);
  left: auto;
  right: 8px;
  margin: 0 0 4px;
}

@supports (anchor-name: --klar-a) and (position-anchor: --klar-a) and (anchor-scope: --klar-a) {
  .klar-select__popup {
    position-try-fallbacks:
      flip-block,
      flip-inline,
      flip-block flip-inline,
      --klar-select-below-edge,
      --klar-select-above-edge;
  }
}

/* Suggestions line up with the text in the input. */
.klar-select__popup--suggest .klar-select__option {
  padding-left: var(--klar-control-px);
}

.klar-select__search {
  display: flex;
  flex: none;
  align-items: center;
  gap: 8px;
  height: 36px;
  padding: 0 8px 0 10px;
  border-bottom: 1px solid var(--klar-border);
  color: var(--klar-text-muted);
}

.klar-select__search-icon,
.klar-select__search-spinner {
  display: flex;
  flex: none;
}

.klar-select__search-input {
  flex: 1;
  min-width: 0;
  height: 100%;
  padding: 0;
  border: 0;
  outline: 0;
  background: transparent;
  color: var(--klar-text);
  font: inherit;
}

.klar-select__search-input:focus-visible {
  outline: none;
}

.klar-select__search-input::placeholder {
  color: var(--klar-text-muted);
  opacity: 1;
}

.klar-select__list {
  flex: none;
}

/* ---- Rows ------------------------------------------------------------ */

.klar-select__option {
  display: flex;
  align-items: center;
  gap: 8px;
  height: var(--klar-option-h);
  padding: 0 10px 0 8px;
  color: var(--klar-text);
  white-space: nowrap;
  cursor: pointer;
  -webkit-user-select: none;
  user-select: none;
}

.klar-select__option--highlighted {
  background: var(--klar-gray-100);
}

.klar-select__option--selected .klar-select__option-label {
  font-weight: var(--klar-weight-medium);
}

.klar-select--multi .klar-select__option--selected .klar-select__option-label {
  font-weight: var(--klar-weight);
}

.klar-select__option--disabled {
  color: var(--klar-text-disabled);
  cursor: not-allowed;
}

.klar-select__option--disabled.klar-select__option--highlighted {
  background: var(--klar-gray-50);
}

.klar-select__option--create {
  color: var(--klar-text-link);
}

.klar-select__check {
  display: flex;
  flex: none;
  align-items: center;
  justify-content: center;
  width: 16px;
  color: var(--klar-primary);
}

.klar-select__checkbox {
  display: flex;
  flex: none;
}

/* The checkbox in a multi-select row is only a picture of the state: the
   row is the control (role=option, aria-selected). */
.klar-select__checkbox .klar-check {
  pointer-events: none;
}

.klar-select__checkbox .klar-check__input {
  visibility: hidden;
}

/* Rows are reused for other options while scrolling: no fade between states. */
.klar-select__checkbox .klar-check__box {
  transition: none;
}

.klar-select__option-icon {
  display: flex;
  flex: none;
  color: var(--klar-text-secondary);
}

.klar-select__option--disabled .klar-select__option-icon {
  color: inherit;
}

.klar-select__option-label {
  flex: 0 1 auto;
  min-width: 0;
  overflow: hidden;
  text-overflow: ellipsis;
}

/* The description gives way first: it shrinks four times faster than the
   label and never takes more than half the row. */
.klar-select__option-description {
  flex: 0 4 auto;
  min-width: 0;
  max-width: 50%;
  margin-left: auto;
  padding-left: 12px;
  overflow: hidden;
  text-overflow: ellipsis;
  color: var(--klar-text-muted);
  font-size: var(--klar-text-sm);
}

.klar-select__option--disabled .klar-select__option-description {
  color: var(--klar-text-disabled);
}

.klar-select__group {
  display: flex;
  align-items: center;
  height: var(--klar-option-h);
  padding: 0 10px;
  border-bottom: 1px solid var(--klar-border-subtle);
  background: var(--klar-gray-50);
  color: var(--klar-text-secondary);
  font-size: var(--klar-text-xs);
  font-weight: var(--klar-weight-bold);
  letter-spacing: 0.06em;
  text-transform: uppercase;
  white-space: nowrap;
  cursor: default;
  -webkit-user-select: none;
  user-select: none;
}

.klar-select__group-label {
  min-width: 0;
  overflow: hidden;
  text-overflow: ellipsis;
}

.klar-vlist__pinned .klar-select__group {
  border-bottom-color: var(--klar-border);
}

/* ---- Loading, empty, failed ----------------------------------------- */

.klar-select__skeleton {
  padding: 4px 0;
}

.klar-select__skeleton-row {
  display: flex;
  align-items: center;
  height: var(--klar-option-h);
  padding: 0 16px 0 32px;
}

.klar-select__state .klar-state--compact {
  padding: var(--klar-space-5) var(--klar-space-4);
}

.klar-select__message {
  padding: 8px 12px;
  color: var(--klar-text-muted);
  font-size: var(--klar-text-sm);
}

/* ---- Footer ---------------------------------------------------------- */

.klar-select__footer {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 8px;
  min-height: 30px;
  padding: 2px 4px 2px 10px;
  border-top: 1px solid var(--klar-border);
  background: var(--klar-surface-subtle);
  color: var(--klar-text-muted);
  font-size: var(--klar-text-xs);
}

.klar-select__status {
  min-width: 0;
}

.klar-select__actions {
  display: flex;
  flex: none;
  align-items: center;
  gap: 2px;
}
"""
