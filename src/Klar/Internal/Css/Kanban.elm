module Klar.Internal.Css.Kanban exposing (css)

{-| Ordered work stages with explicit accessible moving controls.
-}


css : String
css =
    """
.klar-kanban { min-inline-size: 0; color: var(--klar-text); font-size: var(--klar-text-sm); }
.klar-kanban__help { margin: 0 0 var(--klar-space-3); color: var(--klar-text-secondary); font-size: var(--klar-text-xs); line-height: var(--klar-leading); }
.klar-kanban__columns {
  display: grid;
  grid-auto-flow: column;
  grid-auto-columns: minmax(min(100%, 16rem), 1fr);
  align-items: start;
  gap: var(--klar-space-3);
  overflow-x: auto;
  padding-block-end: var(--klar-space-2);
  min-inline-size: 0;
}
.klar-kanban__columns:focus-visible { outline: 2px solid var(--klar-focus-color); outline-offset: 2px; }
.klar-kanban__column { min-inline-size: 0; border: 1px solid var(--klar-border); border-radius: var(--klar-radius-lg); background: var(--klar-surface-subtle); }
.klar-kanban__column-head { display: flex; align-items: baseline; justify-content: space-between; gap: var(--klar-space-2); padding: var(--klar-space-3); border-block-end: 1px solid var(--klar-border); }
.klar-kanban__column-head > :first-child { margin: 0; font-size: var(--klar-text-sm); font-weight: var(--klar-weight-bold); overflow-wrap: anywhere; }
.klar-kanban__count { flex: none; font-family: var(--klar-font-mono); color: var(--klar-text-secondary); font-variant-numeric: tabular-nums; }
.klar-kanban__count--full { color: var(--klar-amber-700); font-weight: var(--klar-weight-bold); }
.klar-kanban__limit { margin: 0; padding: var(--klar-space-2) var(--klar-space-3); background: var(--klar-amber-50); color: var(--klar-amber-700); font-size: var(--klar-text-xs); }
.klar-kanban__cards { display: flex; flex-direction: column; gap: var(--klar-space-2); list-style: none; margin: 0; padding: var(--klar-space-2); }
.klar-kanban__card { min-inline-size: 0; padding: var(--klar-space-3); border: 1px solid var(--klar-border); border-radius: var(--klar-radius); background: var(--klar-surface); overflow-wrap: anywhere; }
.klar-kanban__card--moving { border-color: var(--klar-primary); background: var(--klar-primary-subtle); }
.klar-kanban__card-head { display: flex; align-items: center; gap: var(--klar-space-2); margin-block-end: var(--klar-space-2); }
.klar-kanban__handle { display: inline-flex; flex: none; align-items: center; justify-content: center; min-inline-size: var(--klar-control-sm); min-block-size: var(--klar-control-sm); border: 1px solid var(--klar-border); border-radius: var(--klar-radius); padding: var(--klar-space-1); background: var(--klar-surface); color: var(--klar-text-secondary); cursor: pointer; }
.klar-kanban__handle:hover { background: var(--klar-surface-hover); color: var(--klar-text); }
.klar-kanban__handle[aria-pressed="true"] { color: var(--klar-primary); border-color: var(--klar-primary); }
.klar-kanban__handle:disabled { color: var(--klar-text-disabled); cursor: default; }
.klar-kanban__title { min-inline-size: 0; padding: 0; border: 0; border-radius: var(--klar-radius-sm); background: transparent; color: var(--klar-text-link); font: inherit; font-weight: var(--klar-weight-bold); text-align: start; cursor: pointer; overflow-wrap: anywhere; }
.klar-kanban__title:hover { text-decoration: underline; }
.klar-kanban__card-title { min-inline-size: 0; overflow-wrap: anywhere; }
.klar-kanban__empty { padding: var(--klar-space-4); margin: 0; color: var(--klar-text-secondary); }
.klar-kanban__move { display: flex; align-items: end; flex-wrap: wrap; gap: var(--klar-space-3); padding: var(--klar-space-3); margin-block-end: var(--klar-space-3); border: 1px solid var(--klar-primary-border); border-radius: var(--klar-radius); background: var(--klar-primary-subtle); }
.klar-kanban__move > strong { flex: 1 0 100%; overflow-wrap: anywhere; }
.klar-kanban__move > p { flex: 1 0 100%; margin: 0; }
.klar-kanban__control { display: flex; flex-direction: column; gap: var(--klar-space-1); font-weight: var(--klar-weight-medium); max-inline-size: 100%; }
.klar-kanban__control select { min-block-size: var(--klar-control-sm); max-inline-size: 100%; padding: var(--klar-space-1) var(--klar-space-2); border: 1px solid var(--klar-border-strong); border-radius: var(--klar-radius); background: var(--klar-surface); color: var(--klar-text); font: inherit; }
.klar-kanban__control select:disabled { color: var(--klar-text-disabled); }
.klar-kanban__destination { align-self: center; color: var(--klar-text-secondary); font-variant-numeric: tabular-nums; }
.klar-kanban__warning { margin: 0 0 var(--klar-space-3); padding: var(--klar-space-3); border: 1px solid var(--klar-amber-200); border-radius: var(--klar-radius); color: var(--klar-amber-700); background: var(--klar-amber-50); }
@media (forced-colors: active) {
  .klar-kanban__card--moving { outline: 2px solid Highlight; outline-offset: -2px; }
}
"""
