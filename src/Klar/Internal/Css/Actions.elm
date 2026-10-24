module Klar.Internal.Css.Actions exposing (css)

{-| The rules of `actions`, part of the stylesheet of the package. Edit the CSS here;
`Klar.Internal.Css` puts the parts together in order.
-}


css : String
css =
    """
/* ==========================================================================
   Actions: ButtonGroup, ToggleGroup, SplitButton, Link, Kbd.

   Spacing, radii, colors and type sizes are tokens. Three kinds of literal stay,
   each with a comment where it is used: the 1px that joined buttons overlap by
   (the width of a border), z-index 1 and 2 (the stacking of siblings among each
   other, not a layer of the page, so none of the --klar-z-* tokens fits), and
   sizes that no token has (marked "no token").
   ========================================================================== */

/* ---- Button group ---------------------------------------------------- */

/* Joined buttons: shared borders, only the outer corners rounded. The group is a
   fieldset (so that `disabled` reaches every button), reset to a plain box. It
   never wraps. A child may be a wrapper (the anchor of a menu button), so the
   rules read "the first and the last child, or the button inside it". */
.klar-btn-group {
  display: inline-flex;
  flex-wrap: nowrap;
  align-items: stretch;
  max-width: 100%;
  min-width: 0;
  min-inline-size: 0;
  margin: 0;
  padding: 0;
  border: 0;
  vertical-align: middle;
}

.klar-btn-group > * { flex: 0 1 auto; min-width: 0; }

/* The 1px is the width of a border: neighbors share one. */
.klar-btn-group > * + * { margin-left: -1px; }

.klar-btn-group .klar-button { border-radius: 0; }

.klar-btn-group > .klar-button:first-child,
.klar-btn-group > :first-child .klar-button {
  border-top-left-radius: var(--klar-radius);
  border-bottom-left-radius: var(--klar-radius);
}

.klar-btn-group > .klar-button:last-child,
.klar-btn-group > :last-child .klar-button {
  border-top-right-radius: var(--klar-radius);
  border-bottom-right-radius: var(--klar-radius);
}

/* One ring per button, always in front of its neighbors: a button that is
   pointed at, pressed or focused is lifted over the shared borders. The z-index
   values only order siblings (as in core.css for Button.group). */
.klar-btn-group .klar-button:hover,
.klar-btn-group .klar-button[aria-pressed="true"] { position: relative; z-index: 1; }
.klar-btn-group .klar-button:focus-visible { position: relative; z-index: 2; }

/* Two solid buttons side by side would melt into one: a pale line between. */
.klar-btn-group > .klar-button--primary + .klar-button--primary:not(:focus-visible),
.klar-btn-group > .klar-button--danger + .klar-button--danger:not(:focus-visible) {
  border-left-color: color-mix(in srgb, var(--klar-white) 40%, transparent);
}

/* The size of the buttons that have none of their own (a toolbar sets the same
   custom property). A small or large button keeps its size. The values are those
   of .klar-button--sm and .klar-button--lg in core.css. */
.klar-btn-group--sm { --klar-control: var(--klar-control-sm); }
.klar-btn-group--lg { --klar-control: var(--klar-control-lg); }

.klar-btn-group--sm .klar-button--md:not(.klar-button--icon-only) {
  padding: 0 var(--klar-space-2);
  font-size: var(--klar-text-sm);
  gap: 5px; /* no token: the gap of .klar-button--sm */
}

.klar-btn-group--lg .klar-button--md:not(.klar-button--icon-only) {
  padding: 0 var(--klar-space-4);
  font-size: var(--klar-text-lg);
}

/* A disabled group is a fieldset that is disabled (it turns its buttons off) and
   inert (the same for a link that looks like a button, which is not a form control,
   and for the keyboard). The dimming is for the eye; a browser without `inert`
   still stops the pointer on a link. */
.klar-btn-group--disabled .klar-button { opacity: 0.5; }
.klar-btn-group--disabled a.klar-button { pointer-events: none; }

/* ---- Toggle group ----------------------------------------------------- */

/* The outer element of a group. It is not a .klar-field itself, so a toolbar does not
   give it the 240px that it gives a text field. */
.klar-toggle {
  min-width: 0;
  max-width: 100%;
}

.klar-toggle-field {
  display: flex;
  flex-direction: column;
  gap: var(--klar-space-1);
  min-width: 0;
}

.klar-toggle-group { align-self: flex-start; }

/* The words of the options are what the user chooses by, so a group that does not fit
   goes onto a second line (six statuses on a phone were cut down to "D..", "Co..",
   "Pi.."). The joined look of a button group is kept in each line. A full width group
   shares one line and has its own rule below. */
.klar-toggle-group { flex-wrap: wrap; }
.klar-toggle-group:not(.klar-toggle-group--full) > .klar-button { flex: 0 0 auto; }

.klar-toggle-group--full {
  display: flex;
  align-self: stretch;
  width: 100%;
}

.klar-toggle-group--full > .klar-button { flex: 1 1 0; }

/* A full width group shares the line equally. On a phone seven days get 44px each, and
   with the padding of a button "Mon" was cut down to "M..": less room at the sides,
   so that a short word keeps all of its letters. */
.klar-toggle-group--full > .klar-button:not(.klar-button--icon-only) { padding-inline: var(--klar-space-1); }

.klar-toggle-group--invalid .klar-button { --_border: var(--klar-danger); }

/* Windows high contrast replaces the colors of a button: what is switched on must not
   depend on a background. A frame inside the button marks it (an outline would be
   taken by the focus ring). */
@media (forced-colors: active) {
  .klar-toggle-group .klar-button[aria-pressed="true"]::after {
    content: "";
    position: absolute;
    inset: 3px;
    border: 2px solid Highlight;
    border-radius: 2px;
    pointer-events: none;
  }
}

/* ---- Split button ----------------------------------------------------- */

/* A button joined to a small arrow that opens a menu. The menu is the one of
   Klar.Menu inside the arrow's wrapper; the whole split button is its anchor, so
   the menu is as wide as the split button at least and ends where it ends. The
   element is there with no arrow too (no items), so the main button is never
   rebuilt when items arrive. */
.klar-split {
  position: relative;
  display: inline-flex;
  align-items: stretch;
  max-width: 100%;
  vertical-align: middle;
}

.klar-split > .klar-button {
  flex: 0 1 auto;
  min-width: 0;
  border-top-right-radius: 0;
  border-bottom-right-radius: 0;
}

/* No arrow: the main button is a button of its own again. */
.klar-split--single > .klar-button { border-radius: var(--klar-radius); }

.klar-split > .klar-menu {
  position: static;
  display: flex;
  flex: none;
  margin-left: -1px; /* the width of the border that the two parts share */
}

/* The arrow is a little narrower than a square button. It has no text: Klar.Menu
   draws an empty label before the chevron. */
.klar-split > .klar-menu .klar-button {
  /* never narrower than the 24px that a target needs, in a compact density too */
  width: max(24px, calc(var(--klar-control) * 0.85));
  padding: 0;
  border-top-left-radius: 0;
  border-bottom-left-radius: 0;
}

.klar-split > .klar-menu .klar-button__label { display: none; }

/* the small arrow is square: it must be at least 24px wide to be hit */
.klar-split--sm > .klar-menu .klar-button { width: var(--klar-control-sm); }
.klar-split--lg > .klar-menu .klar-button { width: calc(var(--klar-control-lg) * 0.85); }

.klar-split .klar-button:hover,
.klar-split .klar-button[aria-expanded="true"] { position: relative; z-index: 1; }
.klar-split .klar-button:focus-visible { position: relative; z-index: 2; }

/* A solid button next to its arrow keeps a pale line between the two. */
.klar-split > .klar-button--primary + .klar-menu .klar-button:not(:focus-visible),
.klar-split > .klar-button--danger + .klar-menu .klar-button:not(:focus-visible) {
  border-left-color: color-mix(in srgb, var(--klar-white) 40%, transparent);
}

/* While the main part is busy the arrow cannot be used (it is aria-disabled, so
   it keeps the focus), but it is not dimmed: the spinner says "wait". */
.klar-split--loading > .klar-menu .klar-button--disabled { opacity: 1; }

@supports (anchor-name: --klar-a) and (position-anchor: --klar-a) and (anchor-scope: --klar-a) {
  .klar-split {
    anchor-name: --klar-anchor;
    anchor-scope: --klar-anchor;
  }

  .klar-split > .klar-menu {
    anchor-name: none;
    anchor-scope: none;
  }
}

/* ---- Link ------------------------------------------------------------- */

/* The base look (link color, underline) is .klar-link in core.css. */

.klar-link--inline:visited {
  color: color-mix(in srgb, var(--klar-primary) 70%, var(--klar-gray-700));
}

.klar-link--standalone { text-decoration: none; }
.klar-link--standalone:hover { text-decoration: underline; }

.klar-link--current,
.klar-link--current:visited {
  color: var(--klar-text);
  font-weight: var(--klar-weight-bold);
  text-decoration: none;
}

.klar-link--disabled,
.klar-link--disabled:hover {
  color: var(--klar-text-disabled);
  text-decoration: none;
  cursor: not-allowed;
}

/* The icons are sized and spaced in em, so they follow the text of the link. */
.klar-link__icon,
.klar-link__external {
  display: inline-flex;
  flex: none;
  vertical-align: -0.15em;
}

.klar-link__icon { margin-right: 0.35em; }
.klar-link__external { margin-left: 0.3em; }

.klar-link--truncate {
  display: inline-flex;
  align-items: center;
  max-width: 100%;
  vertical-align: bottom;
}

.klar-link--truncate .klar-link__text {
  min-width: 0;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}

/* ---- Kbd -------------------------------------------------------------- */

/* The key cap itself is .klar-kbd in core.css. */

.klar-keys {
  display: inline-flex;
  align-items: center;
  vertical-align: middle;
  white-space: nowrap;
}

.klar-keys__caps {
  display: inline-flex;
  align-items: center;
  gap: var(--klar-space-2);
}

.klar-keys__then {
  font-size: var(--klar-text-sm);
  color: var(--klar-text-muted);
}

/* The compact cap, as in a tooltip (overlay.css). No token: there is no 16px
   control and no 10.5px text size. */
.klar-keys--sm .klar-kbd {
  height: 16px;
  min-width: 16px;
  padding: 0 var(--klar-space-1);
  font-size: 10.5px;
}

/* In a sentence: the caps follow the text around them and do not make the
   line taller. */
.klar-keys--inline,
.klar-keys--inline .klar-keys__caps,
.klar-keys--inline .klar-kbd-combo {
  display: inline;
  vertical-align: baseline;
}

.klar-keys--inline .klar-kbd {
  display: inline-block;
  height: auto;
  min-width: 0;
  padding: 0.05em 0.4em;
  font-size: 0.85em;
  line-height: 1.35;
}

.klar-keys--inline .klar-kbd + .klar-kbd { margin-left: 0.25em; }
.klar-keys--inline .klar-keys__then { margin: 0 0.35em; font-size: 0.9em; }
"""
