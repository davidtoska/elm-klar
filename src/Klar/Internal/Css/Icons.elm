module Klar.Internal.Css.Icons exposing (css)

{-| The rules of `icons`, part of the stylesheet of the package. Edit the CSS here;
`Klar.Internal.Css` puts the parts together in order.
-}


css : String
css =
    """
/* ==========================================================================
   Icons - CSS masks over inline SVG (24x24, 2px round stroke).
   The shape is a mask, the color is `currentColor`, so an icon always
   follows the text color of its parent. The shapes are not here: every icon is
   an Elm value (Klar.Icon, Klar.Icon.*) that carries its own SVG and sets the
   custom property `--klar-icon` on its element. This file has only the
   frame: size, mask and the dashed box shown by a `custom` icon without a rule.
   ========================================================================== */

.klar-icon {
  --klar-icon-size: 16px;
  /* Shown while an icon has no shape of its own (a `custom` name whose rule is not
     written yet): a dashed box, not a solid square. */
  --_missing: url("data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' fill='none' stroke='black' stroke-width='2' stroke-linecap='round' stroke-dasharray='3 4'><rect x='4' y='4' width='16' height='16' rx='3'/></svg>");
  display: inline-block;
  flex: none;
  width: var(--klar-icon-size);
  height: var(--klar-icon-size);
  background-color: currentColor;
  -webkit-mask: var(--klar-icon, var(--_missing)) center / contain no-repeat;
  mask: var(--klar-icon, var(--_missing)) center / contain no-repeat;
  vertical-align: -0.2em;
  /* The color is a background, which a browser leaves out when it prints: keep it, or
     every icon, status icons included, prints as nothing. */
  -webkit-print-color-adjust: exact;
  print-color-adjust: exact;
}

/* Windows high contrast mode replaces background colors, which would turn the
   mask of an icon into an empty box. The mask is the icon: keep its color (it is
   currentColor, which the system sets to the text color of the context). */
@media (forced-colors: active) {
  .klar-icon {
    forced-color-adjust: none;
  }
}

/* Icon.Size. The modifiers start with `size-`, which the name of an icon (also a
   `klar-icon--` modifier) never does in practice, so `custom "lg"` is not a size. */
.klar-icon--size-12 { --klar-icon-size: 12px; }
.klar-icon--size-14 { --klar-icon-size: 14px; }
.klar-icon--size-20 { --klar-icon-size: 20px; }
.klar-icon--size-24 { --klar-icon-size: 24px; }
.klar-icon--size-32 { --klar-icon-size: 32px; }
"""
