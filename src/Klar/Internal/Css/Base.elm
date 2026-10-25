module Klar.Internal.Css.Base exposing (css)

{-| The rules of `base`, part of the stylesheet of the package. Edit the CSS here;
`Klar.Internal.Css` puts the parts together in order.
-}


css : String
css =
    """
/* ==========================================================================
   Base: reset, typography, focus, utilities, motion, popup primitives
   ========================================================================== */

*,
*::before,
*::after {
  box-sizing: border-box;
}

html {
  -webkit-text-size-adjust: 100%;
  text-size-adjust: 100%;
}

body {
  margin: 0;
  background: var(--klar-bg);
  color: var(--klar-text);
  font-family: var(--klar-font);
  font-size: var(--klar-text-md);
  line-height: var(--klar-leading);
  font-weight: var(--klar-weight);
  -webkit-font-smoothing: antialiased;
  -moz-osx-font-smoothing: grayscale;
  text-rendering: optimizeLegibility;
}

/* Page scroll is locked while a modal-like surface is open. */
body:has(.klar-modal-lock) {
  overflow: hidden;
}

button,
input,
select,
textarea {
  font: inherit;
  color: inherit;
  margin: 0;
}

button {
  cursor: pointer;
}

h1,
h2,
h3,
h4,
h5,
h6,
p,
figure,
blockquote,
dl,
dd {
  margin: 0;
}

ul,
ol {
  margin: 0;
  padding: 0;
  list-style: none;
}

a {
  color: var(--klar-text-link);
  text-decoration: none;
}

a:hover {
  text-decoration: underline;
}

hr {
  border: 0;
  border-top: 1px solid var(--klar-border);
  margin: 0;
}

img,
svg {
  display: block;
  max-width: 100%;
}

table {
  border-collapse: collapse;
  border-spacing: 0;
}

::selection {
  background: var(--klar-selection);
}

[hidden] {
  display: none !important;
}

/* ---- Focus ---------------------------------------------------------- */

:focus {
  outline: none;
}

:focus-visible {
  outline: 2px solid var(--klar-focus-color);
  outline-offset: 1px;
}

/* Forced colors (Windows high contrast) drop every box-shadow, and most components draw
   their focus ring as one, next to `outline: none`. Every element that shows focus gets
   the outline back there, in the system color of a highlight, whatever its own rules
   say (`!important`); its offset stays the component's own. */
@media (forced-colors: active) {
  :focus-visible {
    outline: 2px solid Highlight !important;
  }
}

/* ---- Scrollbars (thin, gray) ---------------------------------------- */

* {
  scrollbar-width: thin;
  scrollbar-color: var(--klar-gray-300) transparent;
}

*::-webkit-scrollbar {
  width: 10px;
  height: 10px;
}

*::-webkit-scrollbar-thumb {
  background: var(--klar-gray-300);
  border-radius: var(--klar-radius-full);
  border: 2px solid transparent;
  background-clip: content-box;
}

*::-webkit-scrollbar-thumb:hover {
  background: var(--klar-gray-400);
  background-clip: content-box;
}

*::-webkit-scrollbar-corner {
  background: transparent;
}

/* ---- Utilities ------------------------------------------------------ */

.klar-sr-only {
  position: absolute;
  width: 1px;
  height: 1px;
  margin: -1px;
  padding: 0;
  overflow: hidden;
  clip: rect(0, 0, 0, 0);
  clip-path: inset(50%);
  white-space: nowrap;
  border: 0;
}

.klar-truncate {
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
  min-width: 0;
}

.klar-nowrap {
  white-space: nowrap;
}

.klar-mono {
  font-family: var(--klar-font-mono);
  font-size: 0.95em;
}

.klar-tabular {
  font-variant-numeric: tabular-nums;
}

.klar-no-select {
  -webkit-user-select: none;
  user-select: none;
}

/* A highlighted match inside search results (Klar.Search.highlight). Its own class:
   `klar-dot` is the colour dot of options and tags (Core). */
.klar-highlight {
  background: var(--klar-highlight);
  box-shadow: none;
  color: inherit;
  border-radius: 2px;
  padding: 0 1px;
}

/* Forced colors drop the background: a match takes the system colors of a mark
   (Highlight where a browser does not know Mark). */
@media (forced-colors: active) {
  .klar-highlight {
    background: Highlight;
    color: HighlightText;
    background: Mark;
    color: MarkText;
  }
}

/* ---- Motion --------------------------------------------------------- */

@keyframes klar-fade-in {
  from { opacity: 0; }
  to { opacity: 1; }
}

/* Entrance animations move (transform) and never fade (opacity): while a surface
   with text is partly transparent, the contrast that a checker computes is the
   contrast of text on a half-covered background, and it reports a violation that
   is gone a moment later. Only the backdrop fades; it carries no text. */
@keyframes klar-pop-in {
  from { transform: translateY(-4px); }
  to { transform: none; }
}

@keyframes klar-modal-in {
  from { transform: translateY(8px) scale(0.985); }
  to { transform: none; }
}

@keyframes klar-slide-in-right {
  from { transform: translateX(24px); }
  to { transform: none; }
}

@keyframes klar-slide-in-left {
  from { transform: translateX(-24px); }
  to { transform: none; }
}

@keyframes klar-slide-in-up {
  from { transform: translateY(12px); }
  to { transform: none; }
}

@keyframes klar-spin {
  to { transform: rotate(360deg); }
}

@keyframes klar-shimmer {
  0% { background-position: -200% 0; }
  100% { background-position: 200% 0; }
}

@keyframes klar-pulse {
  0%, 100% { opacity: 1; }
  50% { opacity: 0.45; }
}

/* Reduced motion: the one list for every animation of the library.

   - Entrances and exits (popups, dialogs, drawers, toasts, tips, bars that fade in)
     and every transition run on the duration tokens, which are 0ms under reduced
     motion (Tokens), so they appear at once. Only what has a duration of its own is
     named here.
   - Busy indicators (spinners, an indeterminate bar or ring) keep moving, more
     slowly: a spinner that stands still looks like a program that hangs.
   - Decoration that moves while something loads (the shimmer of a skeleton, the
     stripes of a bar) stops, and a sweeping progress line becomes a still line.
   - Not motion, and left alone: the focus guard of a dialog (`klar-focus-lost`,
     whose start is a message) and the scroll shadows of a table, which follow the
     scroll position and not the clock.

   `!important`, because these rules come early in the stylesheet and must win over
   the rules of every component, whatever their specificity. A new animation with a
   duration of its own gets a line here. */
@media (prefers-reduced-motion: reduce) {
  .klar-modal__dialog--nudge-a,
  .klar-modal__dialog--nudge-b,
  .klar-skeleton,
  .klar-progress--striped .klar-progress__bar {
    animation: none !important;
  }

  /* Overlays come in at once: no fade, slide or scale (and no animation events). */
  .klar-toast,
  .klar-modal__backdrop,
  .klar-modal__dialog,
  .klar-palette__backdrop,
  .klar-palette__panel {
    animation: none !important;
  }

  .klar-spinner,
  .klar-switch--loading .klar-switch__thumb::after,
  .klar-progress-ring__arc {
    animation-duration: 1.6s !important;
  }

  .klar-progress--indeterminate .klar-progress__bar {
    animation-duration: 3.2s !important;
  }

  .klar-progress--indeterminate .klar-progress__segment {
    --_wave: 3.2s !important;
  }

  .klar-table__progress::after,
  .klar-compare__progress::after {
    animation: none !important;
    width: 100% !important;
    opacity: 0.5 !important;
    transform: none !important;
  }

  .klar-refreshing::after {
    animation: none !important;
    background: var(--klar-blue-200) !important;
  }
}

/* ---- Popup primitives -----------------------------------------------
   A popup lives inside a `.klar-anchor` wrapper that also holds its trigger.
   With CSS anchor positioning the popup is `position: fixed`, so it escapes
   any overflow-clipping ancestor, follows its anchor, and flips when there
   is no room. Older browsers fall back to plain absolute positioning.
   ---------------------------------------------------------------------- */

.klar-anchor {
  position: relative;
  display: inline-block;
  max-width: 100%;
}

.klar-anchor--block {
  display: block;
}

/* Transparent full-viewport layer: a click anywhere outside the popup
   lands on it and closes the popup. */
.klar-layer {
  position: fixed;
  inset: 0;
  z-index: var(--klar-z-layer);
  background: transparent;
}

.klar-popup {
  position: absolute;
  top: calc(100% + 4px);
  left: 0;
  z-index: var(--klar-z-popup);
  min-width: 100%;
  max-width: min(520px, calc(100vw - 16px));
  background: var(--klar-surface);
  border: 1px solid var(--klar-border-strong);
  border-radius: var(--klar-radius-lg);
  box-shadow: var(--klar-shadow-md);
  animation: klar-pop-in var(--klar-dur) var(--klar-ease);
  color: var(--klar-text);
  font-size: var(--klar-text-md);
}

.klar-popup--end {
  left: auto;
  right: 0;
}

.klar-popup--up {
  top: auto;
  bottom: calc(100% + 4px);
}

/* Fallback (absolute) wide popup. Declared before the @supports block so the
   anchored version below wins in browsers that support it - percentages on a
   fixed popup would resolve against the viewport, not the anchor. */
.klar-popup--wide {
  min-width: max(100%, 320px);
}

@supports (anchor-name: --klar-a) and (position-anchor: --klar-a) and (anchor-scope: --klar-a) {
  .klar-anchor {
    anchor-name: --klar-anchor;
    anchor-scope: --klar-anchor;
  }

  .klar-popup {
    position: fixed;
    position-anchor: --klar-anchor;
    top: anchor(bottom);
    left: anchor(left);
    right: auto;
    bottom: auto;
    margin-top: 4px;
    min-width: anchor-size(width);
    position-try-fallbacks: flip-block, flip-inline, flip-block flip-inline;
  }

  .klar-popup--end {
    left: auto;
    right: anchor(right);
  }

  .klar-popup--up {
    top: auto;
    bottom: anchor(top);
    margin-top: 0;
    margin-bottom: 4px;
  }

  .klar-popup--wide {
    min-width: max(anchor-size(width), 320px);
  }
}

/* ---- Hairline helpers ------------------------------------------------ */

.klar-hairline {
  border: 1px solid var(--klar-border);
}

.klar-divider-v {
  width: 1px;
  align-self: stretch;
  background: var(--klar-border);
}

/* ---- Print -----------------------------------------------------------
   Icons, color dots, check marks, progress bars and the lines of a chart are a
   background color, most of them shaped by a mask, and a browser leaves
   backgrounds out of a print unless told: without `print-color-adjust: exact`
   they print as nothing. What only works on a screen stays off the paper: the
   click-away layers and their popups, toasts, tooltips, the moving line of a
   refresh, and the tab stops that keep focus inside a dialog. */
@media print {
  [class*="klar-"] {
    -webkit-print-color-adjust: exact;
    print-color-adjust: exact;
  }

  .klar-layer,
  .klar-popup,
  .klar-toasts,
  .klar-tip-bubble,
  .klar-modal__guard,
  .klar-modal__sentinel {
    display: none !important;
  }

  .klar-refreshing::after {
    content: none;
  }
}
"""
