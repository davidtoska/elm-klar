module Klar.Internal.Css.Structured exposing (css)

{-| The rules of `structured`, part of the stylesheet of the package. Edit the CSS here;
`Klar.Internal.Css` puts the parts together in order.
-}


css : String
css =
    """
/* MaskedInput, Money, MoneyInput.
   Both fields reuse the `.klar-input` shell from core.css (border, focus ring, the
   invalid, disabled and read-only looks, the three sizes). */

/* ---- Masked input ----------------------------------------------------- */

/* An identifier reads from left to right in every language (the input has `dir="ltr"`),
   with figures of equal width so that groups line up as they are typed. */
.klar-masked__control {
  font-variant-numeric: tabular-nums;
  letter-spacing: 0.02em;
  text-align: start;
}

/* The count of characters ("6/9") at the end of the field. */
.klar-masked .klar-input__counter { margin-inline-start: var(--klar-space-1); }

/* ---- Money input ------------------------------------------------------ */

.klar-money__control {
  min-width: 0;
  font-variant-numeric: tabular-nums;
}

.klar-money__control--end { text-align: end; }

/* The code of the currency, always in view at the end of the field. */
.klar-money__currency {
  padding-inline-start: var(--klar-space-1);
  font-variant-numeric: tabular-nums;
  font-weight: var(--klar-weight-medium);
  letter-spacing: 0.04em;
  white-space: nowrap;
}

.klar-money.klar-input--disabled .klar-money__currency { color: var(--klar-text-disabled); }

/* Forced colors: the dimmed code of a disabled field keeps its meaning. */
@media (forced-colors: active) {
  .klar-money.klar-input--disabled .klar-money__currency { color: GrayText; }
}
"""
