module Klar.Internal.Css.Budget exposing (css)

{-| Editable budget sheets. All colors and spacing follow the Klar theme.
-}


css : String
css =
    """
.klar-budget {
  min-width: 0;
  border: 1px solid var(--klar-border);
  border-radius: var(--klar-radius-lg);
  background: var(--klar-surface);
  overflow: clip;
  font-size: var(--klar-text-md);
}
.klar-budget__header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: var(--klar-space-3);
  padding: var(--klar-space-4);
}
.klar-budget__title { margin: 0; font-size: var(--klar-text-lg); font-weight: 600; }
.klar-budget__currency {
  padding: var(--klar-space-1) var(--klar-space-2);
  border: 1px solid var(--klar-border);
  border-radius: var(--klar-radius-sm);
  font-size: var(--klar-text-sm);
  color: var(--klar-text-muted);
}
.klar-budget__scroll { overflow-x: auto; }
.klar-budget__table { width: 100%; border-collapse: separate; border-spacing: 0; }
.klar-budget__table th {
  background: var(--klar-surface-subtle);
  padding: var(--klar-space-3);
  text-align: left;
  font-weight: 500;
  color: var(--klar-text-muted);
  border-block: 1px solid var(--klar-border);
  white-space: nowrap;
}
.klar-budget__cell { padding: var(--klar-space-1); border-bottom: 1px solid var(--klar-border); min-width: 8rem; }
.klar-budget__line:hover .klar-budget__cell { background: var(--klar-surface-subtle); }
.klar-budget__cell:first-child { width: 100%; min-width: 12rem; }
.klar-budget__input {
  display: block;
  width: 100%;
  min-width: 0;
  box-sizing: border-box;
  border: 1px solid transparent;
  border-radius: var(--klar-radius-sm);
  background: transparent;
  padding: var(--klar-space-2);
  color: var(--klar-text);
  font: inherit;
}
.klar-budget__input:hover { background: var(--klar-surface-subtle); border-color: var(--klar-border); }
.klar-budget__input[aria-invalid="true"] { border-color: var(--klar-danger); background: var(--klar-danger-subtle); }
.klar-budget__input:focus-visible { outline: 2px solid var(--klar-primary); outline-offset: -2px; background: var(--klar-surface); }
.klar-budget__number, .klar-budget__table th.klar-budget__number { text-align: right; font-variant-numeric: tabular-nums; }
.klar-budget__cell > span { display: block; padding: var(--klar-space-2); }
.klar-budget__result {
  position: sticky;
  right: 0;
  min-width: 11rem;
  background: var(--klar-surface);
  padding: var(--klar-space-3);
  border-left: 1px solid var(--klar-border);
  border-bottom: 1px solid var(--klar-border);
  text-align: right;
  font-variant-numeric: tabular-nums;
}
.klar-budget__table th.klar-budget__result { text-align: right; }
.klar-budget__amount { display: flex; align-items: center; justify-content: flex-end; gap: var(--klar-space-3); white-space: nowrap; }
.klar-budget__remove, .klar-budget__add {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  gap: var(--klar-space-2);
  padding: var(--klar-space-2);
  border: 1px solid transparent;
  border-radius: var(--klar-radius-sm);
  background: transparent;
  color: var(--klar-text-muted);
  font: inherit;
  cursor: pointer;
}
.klar-budget__remove:hover { color: var(--klar-danger); background: var(--klar-surface-subtle); }
.klar-budget__add { color: var(--klar-primary); font-weight: 500; }
.klar-budget__add:hover { background: var(--klar-surface-subtle); border-color: var(--klar-border); }
.klar-budget__remove:focus-visible, .klar-budget__add:focus-visible, .klar-budget__scroll:focus-visible { outline: 2px solid var(--klar-primary); outline-offset: -2px; }
.klar-budget__error { max-width: 18rem; font-size: var(--klar-text-sm); color: var(--klar-danger); text-align: left; }
.klar-budget__error:empty { display: none; }
.klar-budget__table tfoot th, .klar-budget__table tfoot td { border-top: 0; border-bottom: 0; background: var(--klar-surface-subtle); padding: var(--klar-space-4) var(--klar-space-3); color: var(--klar-text); font-weight: 600; }
.klar-budget__grand-total { color: var(--klar-primary); font-size: var(--klar-text-lg); font-weight: 600; white-space: nowrap; }
.klar-budget__empty { padding: var(--klar-space-6); text-align: center; color: var(--klar-text-muted); border-bottom: 1px solid var(--klar-border); }
.klar-budget__footer { display: flex; align-items: center; flex-wrap: wrap; justify-content: space-between; gap: var(--klar-space-3); padding: var(--klar-space-2) var(--klar-space-3); border-top: 1px solid var(--klar-border); }
.klar-budget__note { font-size: var(--klar-text-sm); color: var(--klar-text-muted); }
"""
