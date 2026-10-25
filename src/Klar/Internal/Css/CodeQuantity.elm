module Klar.Internal.Css.CodeQuantity exposing (css)

{-| The source viewer and the quantity-with-unit field.
-}


css : String
css =
    """
.klar-code-block {
  min-inline-size: 0;
  border: 1px solid var(--klar-border);
  border-radius: var(--klar-radius-lg);
  background: var(--klar-surface);
  color: var(--klar-text);
  font-size: var(--klar-text-sm);
}
.klar-code-block__toolbar { display: flex; flex-wrap: wrap; align-items: baseline; justify-content: space-between; gap: var(--klar-space-3); padding: var(--klar-space-2) var(--klar-space-3); border-block-end: 1px solid var(--klar-border); background: var(--klar-surface-subtle); }
.klar-code-block__download { color: var(--klar-text-link); }
.klar-code-block__scroll { display: flex; align-items: stretch; overflow: auto; max-block-size: var(--klar-code-height, none); min-inline-size: 0; }
.klar-code-block__source,
.klar-code-block__numbers { margin: 0; padding: var(--klar-space-3); font: inherit; font-family: var(--klar-font-mono); line-height: var(--klar-leading); tab-size: 4; white-space: pre; }
.klar-code-block__source { flex: 1; min-inline-size: max-content; }
.klar-code-block__source code { font: inherit; white-space: inherit; }
.klar-code-block__numbers { flex: none; color: var(--klar-text-secondary); text-align: end; background: var(--klar-surface-subtle); border-inline-end: 1px solid var(--klar-border); user-select: none; }
.klar-code-block__line { white-space: pre; }
.klar-code-block__line--marked { background: var(--klar-primary-subtle); text-decoration: underline; text-decoration-color: var(--klar-primary); text-underline-offset: var(--klar-space-1); }
.klar-code-block__token--keyword { color: var(--klar-text-link); font-weight: var(--klar-weight-bold); }
.klar-code-block__token--quoted { color: var(--klar-text); }
.klar-code-block__token--number { color: var(--klar-text-link); }
.klar-code-block__token--comment { color: var(--klar-text-secondary); font-style: italic; }
.klar-code-block__notice { padding: var(--klar-space-2) var(--klar-space-3); border-block-start: 1px solid var(--klar-border); background: var(--klar-surface-subtle); color: var(--klar-text-secondary); }
.klar-quantity { display: flex; min-inline-size: 0; background: var(--klar-surface); border: 1px solid var(--klar-border-strong); border-radius: var(--klar-radius); color: var(--klar-text); }
.klar-quantity:focus-within { border-color: var(--klar-focus-color); box-shadow: var(--klar-focus-ring); }
.klar-quantity--invalid { border-color: var(--klar-danger); }
.klar-quantity--disabled { background: var(--klar-surface-sunken); color: var(--klar-text-disabled); }
.klar-quantity__number,
.klar-quantity__unit { min-inline-size: 0; margin: 0; padding: var(--klar-space-2) var(--klar-space-3); border: 0; border-radius: var(--klar-radius); background: transparent; color: inherit; font: inherit; min-block-size: var(--klar-control); }
.klar-quantity__number { flex: 1 1 8rem; inline-size: 0; font-variant-numeric: tabular-nums; }
.klar-quantity__number::placeholder { color: var(--klar-text-muted); }
.klar-quantity__unit { flex: 0 1 45%; border-inline-start: 1px solid var(--klar-border); border-start-start-radius: 0; border-end-start-radius: 0; background: var(--klar-surface-subtle); }
.klar-quantity__unit option { color: var(--klar-text); background: var(--klar-surface); }
.klar-quantity__number:disabled,
.klar-quantity__unit:disabled { color: var(--klar-text-disabled); cursor: not-allowed; }
"""
