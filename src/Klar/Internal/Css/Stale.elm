module Klar.Internal.Css.Stale exposing (css)

{-| The rules of `stale`, part of the stylesheet of the package. Edit the CSS here;
`Klar.Internal.Css` puts the parts together in order.
-}


css : String
css =
    """
/* ==========================================================================
   Old and refreshing data (Klar.Remote.Kept): the marker every data component
   draws, and the dimming while a refresh is on its way.
   ========================================================================== */

/* The box around the content (Freshness.wrap): the same element in every state, so a
   refresh never replaces the content. It adds nothing to the layout; the component
   gives it its own classes. Its first child is the slot of the marker, which is always
   there (with its live region) and is laid out as if its children were the box's own. */
.klar-fresh { min-width: 0; }

.klar-fresh__slot { display: contents; }

.klar-stale {
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  gap: var(--klar-space-1) var(--klar-space-2);
  padding: var(--klar-space-1) var(--klar-space-3);
  background: var(--klar-warning-subtle);
  border: 1px solid var(--klar-warning-border);
  border-radius: var(--klar-radius);
  color: var(--klar-amber-700);
  font-size: var(--klar-text-sm);
  line-height: 1.4;
}

.klar-stale--inline { padding: 0 var(--klar-space-2); border-radius: var(--klar-radius-full); }

.klar-stale__text { font-weight: 500; }

.klar-stale__reason { color: var(--klar-text-secondary); }

.klar-stale__action { margin-inline-start: auto; }

/* Dimming is limited by contrast: muted text stays at 4.5:1 down to about 92%. A thin
   moving line at the top says the rest. */
.klar-refreshing { position: relative; cursor: progress; }

.klar-refreshing::after {
  content: "";
  position: absolute;
  inset: 0 0 auto 0;
  height: 2px;
  background: linear-gradient(90deg, transparent, var(--klar-blue-500), transparent) 0 0 / 40% 100% no-repeat;
  animation: klar-refreshing-line 1.2s var(--klar-ease) infinite;
  pointer-events: none;
}

@keyframes klar-refreshing-line {
  from { background-position: -40% 0; }
  to { background-position: 140% 0; }
}

/* Under reduced motion the line stands still (the list in Base). Forced colors drop
   backgrounds: the line keeps a system color, and the marker its border. */
@media (forced-colors: active) {
  .klar-refreshing::after {
    forced-color-adjust: none;
    background: Highlight;
  }

  .klar-stale { border-color: CanvasText; }
}

.klar-refreshing > :not(.klar-stale):not(.klar-sr-only):not(.klar-fresh__slot) {
  opacity: 0.92;
  transition: opacity var(--klar-dur) var(--klar-ease);
}

/* The body of a card, dialog or drawer that shows remote data. */
.klar-remote-body { display: flex; flex-direction: column; gap: var(--klar-space-3); }

.klar-remote-body--loading { min-height: 96px; }

/* Wrappers that put the marker above a component. */
.klar-chart-fresh,
.klar-list-fresh,
.klar-tree-fresh {
  display: flex;
  flex-direction: column;
  gap: var(--klar-space-2);
}
"""
