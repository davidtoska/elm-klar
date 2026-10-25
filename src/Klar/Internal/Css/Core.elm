module Klar.Internal.Css.Core exposing (css)

{-| The rules of `core`, part of the stylesheet of the package. Edit the CSS here;
`Klar.Internal.Css` puts the parts together in order.
-}


css : String
css =
    """
/* ==========================================================================
   Core components: text, layout, card, button, badge, spinner, skeleton,
   alert, empty/error state, field, text input, checkbox, menu
   ========================================================================== */

/* ---- Text ------------------------------------------------------------ */

.klar-text--title {
  font-size: var(--klar-text-2xl);
  line-height: var(--klar-leading-tight);
  font-weight: var(--klar-weight-bold);
  letter-spacing: -0.01em;
  color: var(--klar-text);
}

.klar-text--figure {
  font-size: var(--klar-text-2xl);
  line-height: var(--klar-leading-tight);
  font-weight: var(--klar-weight-bold);
  letter-spacing: -0.01em;
  color: var(--klar-text);
}

.klar-text--heading {
  font-size: var(--klar-text-xl);
  line-height: var(--klar-leading-tight);
  font-weight: var(--klar-weight-bold);
  color: var(--klar-text);
}

.klar-text--subheading {
  font-size: var(--klar-text-lg);
  line-height: var(--klar-leading-tight);
  font-weight: var(--klar-weight-bold);
  color: var(--klar-text);
}

.klar-text--overline {
  font-size: var(--klar-text-xs);
  line-height: 1;
  font-weight: var(--klar-weight-bold);
  letter-spacing: 0.08em;
  text-transform: uppercase;
  color: var(--klar-text-muted);
}

.klar-text--lead {
  font-size: var(--klar-text-lg);
  color: var(--klar-text-secondary);
  max-width: 72ch;
}

.klar-text--paragraph {
  color: var(--klar-text);
  max-width: 80ch;
}

.klar-text--caption {
  font-size: var(--klar-text-sm);
  color: var(--klar-text-muted);
}

.klar-text--secondary {
  color: var(--klar-text-secondary);
}

.klar-text--muted {
  color: var(--klar-text-muted);
}

.klar-text--strong {
  font-weight: var(--klar-weight-bold);
}

/* Underlined, so that a link in a line of text is not told apart by its color alone. */
.klar-link {
  color: var(--klar-text-link);
  text-decoration: underline;
  text-decoration-thickness: 1px;
  text-underline-offset: 0.15em;
}

.klar-link:hover { text-decoration-thickness: 2px; }

.klar-code {
  font-family: var(--klar-font-mono);
  font-size: 0.92em;
  padding: 1px 5px;
  background: var(--klar-gray-100);
  border: 1px solid var(--klar-border-subtle);
  border-radius: var(--klar-radius);
  color: var(--klar-gray-800);
}

.klar-code-block {
  margin: 0;
  padding: var(--klar-space-3) var(--klar-space-4);
  background: var(--klar-code-bg);
  color: var(--klar-code-text);
  border-radius: var(--klar-radius-lg);
  font-family: var(--klar-font-mono);
  font-size: var(--klar-text-sm);
  line-height: 1.55;
  overflow: auto;
  white-space: pre;
}

.klar-code-block code {
  font: inherit;
}

.klar-kbd {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  min-width: 20px;
  height: 20px;
  padding: 0 5px;
  font-family: var(--klar-font);
  font-size: 11px;
  font-weight: var(--klar-weight-medium);
  line-height: 1;
  color: var(--klar-gray-700);
  background: var(--klar-gray-50);
  border: 1px solid var(--klar-border-strong);
  border-bottom-width: 2px;
  border-radius: var(--klar-radius);
}

.klar-kbd-combo {
  display: inline-flex;
  align-items: center;
  gap: 3px;
}

/* ---- Layout ---------------------------------------------------------- */

.klar-stack {
  display: flex;
  flex-direction: column;
  gap: var(--klar-gap, var(--klar-space-3));
}

.klar-row {
  display: flex;
  flex-direction: row;
  align-items: center;
  gap: var(--klar-gap, var(--klar-space-3));
}

.klar-grid {
  display: grid;
  grid-template-columns: var(--klar-grid-template, repeat(auto-fit, minmax(240px, 1fr)));
  gap: var(--klar-gap, var(--klar-space-3));
}

.klar-row--wrap { flex-wrap: wrap; }
.klar-row--align-start, .klar-grid--align-start { align-items: flex-start; }
.klar-row--align-center, .klar-grid--align-center { align-items: center; }
.klar-row--align-end, .klar-grid--align-end { align-items: flex-end; }
.klar-row--align-stretch, .klar-grid--align-stretch { align-items: stretch; }
.klar-row--align-baseline { align-items: baseline; }
.klar-row--justify-center { justify-content: center; }
.klar-row--justify-end { justify-content: flex-end; }
.klar-row--justify-between { justify-content: space-between; }

.klar-stack--align-start { align-items: flex-start; }
.klar-stack--align-center { align-items: center; }
.klar-stack--align-end { align-items: flex-end; }
.klar-stack--align-stretch { align-items: stretch; }
.klar-stack--justify-center { justify-content: center; }
.klar-stack--justify-end { justify-content: flex-end; }
.klar-stack--justify-between { justify-content: space-between; }

.klar-scroll { max-height: var(--klar-max-h); overflow: auto; }

/* A scroll area takes keyboard focus (tabindex 0): the ring goes inside. */
.klar-scroll:focus-visible { outline-offset: -2px; }

.klar-fill { width: 100%; }
.klar-grow { flex: 1 1 0; min-width: 0; }
.klar-fixed-w { flex: 0 0 var(--klar-fixed-w); width: var(--klar-fixed-w); max-width: 100%; min-width: 0; }
.klar-fill-rest { flex: 1 1 auto; min-height: 0; }
.klar-padded { padding: var(--klar-pad, 0); }
.klar-spacer { flex: 1 1 auto; }

.klar-container {
  width: 100%;
  max-width: var(--klar-max-w, var(--klar-page-max));
  margin-inline: auto;
  padding-inline: var(--klar-space-6);
}

.klar-divider {
  border: 0;
  border-top: 1px solid var(--klar-border);
  margin: 0;
  width: 100%;
}

.klar-divider--labelled {
  display: flex;
  align-items: center;
  gap: var(--klar-space-3);
  border: 0;
  color: var(--klar-text-muted);
  font-size: var(--klar-text-sm);
}

.klar-divider--labelled::before,
.klar-divider--labelled::after {
  content: "";
  flex: 1;
  border-top: 1px solid var(--klar-border);
}

/* ---- Card ------------------------------------------------------------ */

.klar-card {
  position: relative;
  display: flex;
  flex-direction: column;
  background: var(--klar-surface);
  border: 1px solid var(--klar-border);
  border-radius: var(--klar-radius-lg);
  min-width: 0;
}

.klar-card--raised { box-shadow: var(--klar-shadow-sm); }
.klar-card--sunken { background: var(--klar-surface-sunken); }

.klar-card--accent { border-left-width: 3px; }
.klar-card--accent-neutral { border-left-color: var(--klar-gray-400); }
.klar-card--accent-primary { border-left-color: var(--klar-primary); }
.klar-card--accent-info { border-left-color: var(--klar-info); }
.klar-card--accent-success { border-left-color: var(--klar-success); }
.klar-card--accent-warning { border-left-color: var(--klar-warning); }
.klar-card--accent-danger { border-left-color: var(--klar-danger); }

.klar-card__header {
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  justify-content: space-between;
  gap: var(--klar-space-2) var(--klar-space-3);
  padding: var(--klar-space-3) var(--klar-space-4);
  border-bottom: 1px solid var(--klar-border);
  min-height: 44px;
}

/* The actions drop below the title when the title would get narrower than 12rem. */
.klar-card__heading { flex: 1 1 12rem; min-width: 0; overflow-wrap: anywhere; }

.klar-card__title {
  font-size: var(--klar-text-lg);
  font-weight: var(--klar-weight-bold);
  line-height: var(--klar-leading-tight);
}

.klar-card__subtitle {
  margin-top: 2px;
  font-size: var(--klar-text-sm);
  color: var(--klar-text-muted);
}

.klar-card__actions {
  display: flex;
  align-items: center;
  gap: var(--klar-space-2);
  flex: none;
}

.klar-card__body {
  flex: 1 1 auto;
  padding: var(--klar-space-4);
  min-width: 0;
}

.klar-card--flush > .klar-card__body { padding: 0; }

.klar-card__footer {
  padding: var(--klar-space-3) var(--klar-space-4);
  border-top: 1px solid var(--klar-border);
  background: var(--klar-surface-subtle);
  border-radius: 0 0 var(--klar-radius-lg) var(--klar-radius-lg);
}

/* ---- Button ---------------------------------------------------------- */

.klar-button {
  --_bg: var(--klar-surface);
  --_fg: var(--klar-text);
  --_border: var(--klar-border-strong);
  display: inline-flex;
  align-items: center;
  justify-content: center;
  gap: 6px;
  height: var(--klar-control);
  padding: 0 12px;
  border: 1px solid var(--_border);
  border-radius: var(--klar-radius);
  background: var(--_bg);
  color: var(--_fg);
  font-family: inherit;
  font-size: var(--klar-text-md);
  font-weight: var(--klar-weight-medium);
  line-height: 1;
  white-space: nowrap;
  text-decoration: none;
  cursor: pointer;
  -webkit-user-select: none;
  user-select: none;
  transition: background-color var(--klar-dur-fast) var(--klar-ease),
    border-color var(--klar-dur-fast) var(--klar-ease),
    box-shadow var(--klar-dur-fast) var(--klar-ease);
}

.klar-button:hover { text-decoration: none; }

.klar-button:focus-visible {
  outline: none;
  box-shadow: var(--klar-focus-ring);
  border-color: var(--klar-focus-color);
}

.klar-button--secondary {
  box-shadow: var(--klar-shadow-xs);
}

.klar-button--secondary:hover { --_bg: var(--klar-gray-50); --_border: var(--klar-gray-400); }
.klar-button--secondary:active { --_bg: var(--klar-gray-100); }

.klar-button--primary {
  --_bg: var(--klar-primary);
  --_fg: var(--klar-on-primary);
  --_border: var(--klar-primary);
}
.klar-button--primary:hover { --_bg: var(--klar-primary-hover); --_border: var(--klar-primary-hover); }
.klar-button--primary:active { --_bg: var(--klar-primary-active); --_border: var(--klar-primary-active); }

.klar-button--danger {
  --_bg: var(--klar-danger);
  --_fg: var(--klar-on-solid);
  --_border: var(--klar-danger);
}
.klar-button--danger:hover { --_bg: var(--klar-danger-hover); --_border: var(--klar-danger-hover); }
.klar-button--danger:active { --_bg: var(--klar-red-700); }

.klar-button--ghost {
  --_bg: transparent;
  --_fg: var(--klar-text-secondary);
  --_border: transparent;
}
.klar-button--ghost:hover { --_bg: var(--klar-gray-100); --_fg: var(--klar-text); }
.klar-button--ghost:active { --_bg: var(--klar-gray-150); }

.klar-button--link {
  --_bg: transparent;
  --_fg: var(--klar-text-link);
  --_border: transparent;
  height: auto;

  /* A link button is a control on its own, not a link in a sentence: the target
     is at least 24 by 24 px (WCAG 2.2, 2.5.8). */
  min-width: 24px;
  min-height: 24px;
  padding: 0;
  font-weight: var(--klar-weight);
}
.klar-button--link:hover { text-decoration: underline; }

/* A toggle button that is on (Button.pressed True). The quiet looks take the accent
   color, so that it reads as "selected" and not just as "hovered"; the solid look
   goes one step darker; a link stays underlined. */
.klar-button--secondary[aria-pressed="true"],
.klar-button--ghost[aria-pressed="true"] {
  --_bg: var(--klar-primary-subtle);
  --_fg: var(--klar-primary);
  --_border: var(--klar-primary-border);
}
.klar-button--secondary[aria-pressed="true"]:hover,
.klar-button--ghost[aria-pressed="true"]:hover {
  --_bg: var(--klar-primary-subtle-hover);
  --_fg: var(--klar-primary-hover);
}
.klar-button--primary[aria-pressed="true"] { --_bg: var(--klar-primary-active); --_border: var(--klar-primary-active); }
.klar-button--link[aria-pressed="true"] { text-decoration: underline; }

/* A destructive action that is not the loud solid red button: the secondary,
   ghost or link look stays and only the text (and the border of a secondary
   button) turns red. The solid red button is .klar-button--danger. */

.klar-button--tone-danger { --_fg: var(--klar-danger); }

.klar-button--secondary.klar-button--tone-danger { --_border: var(--klar-danger); }
.klar-button--secondary.klar-button--tone-danger:hover {
  --_bg: var(--klar-danger-subtle);
  --_fg: var(--klar-danger-hover);
  --_border: var(--klar-danger-hover);
}
.klar-button--secondary.klar-button--tone-danger:active { --_bg: var(--klar-danger-border); }

.klar-button--ghost.klar-button--tone-danger:hover {
  --_bg: var(--klar-danger-subtle);
  --_fg: var(--klar-danger-hover);
}
.klar-button--ghost.klar-button--tone-danger:active { --_bg: var(--klar-danger-border); }

.klar-button--link.klar-button--tone-danger:hover { --_fg: var(--klar-danger-hover); }

.klar-button--sm { height: var(--klar-control-sm); padding: 0 8px; font-size: var(--klar-text-sm); gap: 5px; }
.klar-button--lg { height: var(--klar-control-lg); padding: 0 16px; font-size: var(--klar-text-lg); }

.klar-button--icon-only { width: var(--klar-control); padding: 0; }
.klar-button--icon-only.klar-button--sm { width: var(--klar-control-sm); }
.klar-button--icon-only.klar-button--lg { width: var(--klar-control-lg); }

.klar-button--block { display: flex; width: 100%; }

.klar-button--disabled,
.klar-button[disabled] {
  opacity: 0.5;
  cursor: not-allowed;
  pointer-events: none;
}

.klar-button--loading { cursor: progress; pointer-events: none; }
.klar-button--loading .klar-button__label { opacity: 0.75; }

/* The button has line-height 1; a label that clips its overflow would cut the
   descenders (g, j, p, y) off. The button has a fixed height, so a taller line
   box changes nothing but shows the whole letter. */
.klar-button__label { overflow: hidden; text-overflow: ellipsis; line-height: 1.35; }

/* ---- Spinner --------------------------------------------------------- */

.klar-spinner {
  display: inline-block;
  flex: none;
  width: 14px;
  height: 14px;
  border: 2px solid currentColor;
  border-right-color: transparent;
  border-radius: 50%;
  animation: klar-spin 0.7s linear infinite;
  vertical-align: -0.15em;
}

.klar-spinner--sm { width: 12px; height: 12px; border-width: 1.5px; }
.klar-spinner--lg { width: 22px; height: 22px; border-width: 2.5px; color: var(--klar-primary); }

/* The same padding as the empty and error states (.klar-state), so a region that
   goes from loading to empty or failed keeps its place. */
.klar-spinner-panel {
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  gap: var(--klar-space-3);
  padding: var(--klar-space-12) var(--klar-space-6);
  color: var(--klar-text-secondary);
}

.klar-spinner-panel--compact,
:where([data-klar-density="compact"]) .klar-spinner-panel:where(:not(.klar-spinner-panel--compact)) { padding: var(--klar-space-6) var(--klar-space-4); gap: var(--klar-space-2); }

/* A wait shorter than the delay shows no spinner at all, so a fast answer does not
   flash: the panel fades in after 400ms. Its live text is there from the start.
   A labelled spinner or a panel that is not loading keeps its live region in the
   page as .klar-sr-only, empty, so the next wait is announced. */
.klar-spinner-panel--delayed > * { animation: klar-spinner-appear 150ms ease-out 400ms both; }

@keyframes klar-spinner-appear {
  from { opacity: 0; }
  to { opacity: 1; }
}

.klar-spinner-panel__text { font-size: var(--klar-text-md); }

/* ---- Skeleton -------------------------------------------------------- */

.klar-skeleton {
  display: block;
  background: linear-gradient(90deg, var(--klar-gray-100) 25%, var(--klar-gray-150) 37%, var(--klar-gray-100) 63%);
  background-size: 200% 100%;
  animation: klar-shimmer 1.4s ease-in-out infinite;
  border-radius: var(--klar-radius);
}

.klar-skeleton--line { height: 10px; }
.klar-skeleton--block { width: 100%; }
.klar-skeleton--circle { border-radius: 50%; flex: none; }

.klar-skeleton-lines {
  display: flex;
  flex-direction: column;
  gap: 8px;
  width: 100%;
}

/* Reduced motion, the same for every loading indicator of Klar: what turns (the
   spinner, the indeterminate ring) keeps turning at 1.6s a round, because it says
   "working"; a bar that runs takes 3.2s; stripes and the shimmer stand still. */
@media (prefers-reduced-motion: reduce) {
  .klar-skeleton { animation: none; }
  .klar-spinner { animation-duration: 1.6s; }
}

/* High contrast drops the gradient and paints the background as the page: an
   outline keeps the shape of every placeholder. */
@media (forced-colors: active) {
  .klar-skeleton { outline: 1px solid GrayText; outline-offset: -1px; }
}

/* ---- Badge ----------------------------------------------------------- */

.klar-badge {
  --_fg: var(--klar-gray-700);
  --_bg: var(--klar-gray-100);
  --_border: var(--klar-gray-200);
  --_solid: var(--klar-gray-600);
  display: inline-flex;
  align-items: center;
  gap: 5px;
  height: 20px;
  padding: 0 7px;
  border: 1px solid var(--_border);
  border-radius: var(--klar-radius);
  background: var(--_bg);
  color: var(--_fg);
  font-size: var(--klar-text-sm);
  font-weight: var(--klar-weight-medium);
  line-height: 1;
  white-space: nowrap;
  max-width: 100%;
}

/* Long text is cut with an ellipsis (the whole text is the tooltip) instead of
   pushing the badge out of its container. */
.klar-badge__label,
.klar-status__label {
  min-width: 0;
  overflow: hidden;
  text-overflow: ellipsis;
  /* the badge has line-height 1: a clipped label would lose its descenders */
  line-height: 1.35;
}

.klar-badge--sm { height: 16px; padding: 0 5px; font-size: 10.5px; }
.klar-badge--lg { height: 24px; padding: 0 9px; font-size: var(--klar-text-md); }

.klar-badge--primary, .klar-badge--info { --_fg: var(--klar-blue-700); --_bg: var(--klar-blue-50); --_border: var(--klar-blue-200); --_solid: var(--klar-blue-600); }
.klar-badge--success { --_fg: var(--klar-green-700); --_bg: var(--klar-green-50); --_border: var(--klar-green-100); --_solid: var(--klar-green-600); }
/* White on amber-600 is 3.85 : 1, so a solid warning is filled with amber-700 (5.9 : 1). */
.klar-badge--warning { --_fg: var(--klar-amber-700); --_bg: var(--klar-amber-50); --_border: var(--klar-amber-100); --_solid: var(--klar-amber-700); }
.klar-badge--danger { --_fg: var(--klar-red-700); --_bg: var(--klar-red-50); --_border: var(--klar-red-100); --_solid: var(--klar-red-600); }

.klar-badge--solid { background: var(--_solid); border-color: var(--_solid); color: var(--klar-on-solid); }
.klar-badge--outline { background: transparent; border-color: var(--_solid); color: var(--_fg); }

.klar-badge__dot {
  width: 6px;
  height: 6px;
  border-radius: 50%;
  background: currentColor;
  flex: none;
}

.klar-badge .klar-icon { --klar-icon-size: 12px; }

/* The count takes its colors from the tone and style classes (solid by default). */
.klar-badge--count {
  min-width: 18px;
  height: 18px;
  padding: 0 5px;
  justify-content: center;
  border-radius: var(--klar-radius-full);
  font-size: 11px;
  font-variant-numeric: tabular-nums;
}

.klar-badge--count.klar-badge--sm { min-width: 16px; height: 16px; padding: 0 4px; font-size: 10px; }
.klar-badge--count.klar-badge--lg { min-width: 22px; height: 22px; padding: 0 6px; font-size: var(--klar-text-sm); }

.klar-status {
  --_c: var(--klar-gray-600);
  display: inline-flex;
  align-items: center;
  gap: 6px;
  max-width: 100%;
  white-space: nowrap;
}

.klar-status__dot {
  width: 8px;
  height: 8px;
  border-radius: 50%;
  background: var(--_c);
  flex: none;
}

/* The -600 steps keep 3 : 1 against the page (amber-500 is 2.8 : 1), so a column of
   statuses can be scanned by color. */
.klar-status--primary, .klar-status--info { --_c: var(--klar-blue-600); }
.klar-status--success { --_c: var(--klar-green-600); }
.klar-status--warning { --_c: var(--klar-amber-600); }
.klar-status--danger { --_c: var(--klar-red-600); }

/* High contrast paints backgrounds with Canvas: the dots keep their own color. */
@media (forced-colors: active) {
  .klar-badge__dot,
  .klar-status__dot { forced-color-adjust: none; }
}

/* ---- Mark: the dot that colors an option or a tag ----------------------
   A status color (a tone, follows the theme) or a color of the data (--klar-mark, set from
   a checked color code). It is for the eye only; the label carries the meaning. */

.klar-mark {
  --_c: var(--klar-gray-500);
  display: inline-block;
  flex: none;
  width: 8px;
  height: 8px;
  border-radius: 50%;
  background: var(--klar-mark, var(--_c));
  box-shadow: inset 0 0 0 1px var(--klar-tint-border);
}

.klar-mark--primary, .klar-mark--info { --_c: var(--klar-blue-500); }
.klar-mark--success { --_c: var(--klar-green-500); }
.klar-mark--warning { --_c: var(--klar-amber-500); }
.klar-mark--danger { --_c: var(--klar-red-500); }

@media (forced-colors: active) {
  .klar-mark { forced-color-adjust: none; }
}

/* ---- Tag (chip) ------------------------------------------------------ */

.klar-tag {
  --_fg: var(--klar-gray-800);
  --_bg: var(--klar-gray-100);
  --_border: var(--klar-gray-200);
  display: inline-flex;
  align-items: center;
  gap: 4px;
  max-width: 100%;
  height: 22px;
  padding: 0 4px 0 8px;
  background: var(--_bg);
  border: 1px solid var(--_border);
  border-radius: var(--klar-radius);
  color: var(--_fg);
  font-size: var(--klar-text-sm);
  line-height: 1;
  white-space: nowrap;
}

.klar-tag--sm { height: 18px; padding-left: 6px; font-size: 11px; }
.klar-tag--lg { height: 26px; padding-left: 10px; font-size: var(--klar-text-md); }

.klar-tag--primary, .klar-tag--info { --_fg: var(--klar-blue-700); --_bg: var(--klar-blue-50); --_border: var(--klar-blue-200); }
.klar-tag--success { --_fg: var(--klar-green-700); --_bg: var(--klar-green-50); --_border: var(--klar-green-100); }
.klar-tag--warning { --_fg: var(--klar-amber-700); --_bg: var(--klar-amber-50); --_border: var(--klar-amber-100); }
.klar-tag--danger { --_fg: var(--klar-red-700); --_bg: var(--klar-red-50); --_border: var(--klar-red-100); }
.klar-tag--outline { background: transparent; }

.klar-tag:not(:has(.klar-tag__remove)) { padding-right: 8px; }
.klar-tag .klar-icon { --klar-icon-size: 12px; }
.klar-tag__label { min-width: 0; overflow: hidden; text-overflow: ellipsis; line-height: 1.35; }

/* The glyph is 16px but the target is 24px (WCAG 2.5.8): the extra 4px are padding that
   is taken back with a negative margin, and only the content box is painted. */
.klar-tag__remove {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  flex: none;
  width: 24px;
  height: 24px;
  margin: -4px -4px -4px -2px;
  padding: 4px;
  border: 0;
  border-radius: var(--klar-radius-sm);
  background: transparent;
  background-clip: content-box;
  color: inherit;
  opacity: 0.65;
}

.klar-tag__remove:hover { opacity: 1; background: var(--klar-tint-border); }

/* ---- Alert ----------------------------------------------------------- */

.klar-alert {
  --_fg: var(--klar-blue-700);
  --_bg: var(--klar-info-subtle);
  --_border: var(--klar-info-border);
  --_icon: var(--klar-blue-600);
  display: flex;
  align-items: flex-start;
  gap: var(--klar-space-3);
  padding: var(--klar-space-3) var(--klar-space-4);
  background: var(--_bg);
  border: 1px solid var(--_border);
  border-left: 3px solid var(--_icon);
  border-radius: var(--klar-radius);
  color: var(--klar-text);
}

.klar-alert--neutral { --_bg: var(--klar-gray-50); --_border: var(--klar-gray-200); --_icon: var(--klar-gray-500); }
.klar-alert--success { --_bg: var(--klar-success-subtle); --_border: var(--klar-success-border); --_icon: var(--klar-green-600); }
.klar-alert--warning { --_bg: var(--klar-warning-subtle); --_border: var(--klar-warning-border); --_icon: var(--klar-amber-600); }
.klar-alert--danger { --_bg: var(--klar-danger-subtle); --_border: var(--klar-danger-border); --_icon: var(--klar-red-600); }

.klar-alert--compact,
:where([data-klar-density="compact"]) .klar-alert:where(:not(.klar-alert--compact, .klar-alert--comfortable)) { padding: var(--klar-space-2) var(--klar-space-3); font-size: var(--klar-text-sm); }

.klar-alert--banner {
  border-radius: 0;
  border-width: 0 0 1px 0;
  border-left-width: 0;
  box-shadow: inset 3px 0 0 var(--_icon);
}

.klar-alert__icon {
  display: flex;
  color: var(--_icon);
  padding-top: 1px;
}

.klar-alert__content { flex: 1; min-width: 0; }
.klar-alert__title { font-weight: var(--klar-weight-bold); margin-bottom: 2px; }
.klar-alert__message { color: var(--klar-text); }
.klar-alert__actions { display: flex; gap: var(--klar-space-2); margin-top: var(--klar-space-2); }

/* A 24px target (WCAG 2.5.8) that reaches into the padding of the alert. */
.klar-alert__close {
  flex: none;
  display: flex;
  align-items: center;
  justify-content: center;
  width: 24px;
  height: 24px;
  margin-block: -3px;
  margin-inline-end: -7px;
  padding: 0;
  border: 0;
  border-radius: var(--klar-radius);
  background: transparent;
  color: var(--klar-text-secondary);
}

.klar-alert__close:hover { background: var(--klar-tint-hover); color: var(--klar-text); }

/* ---- Empty & error states ------------------------------------------- */

.klar-state {
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  gap: var(--klar-space-2);
  padding: var(--klar-space-12) var(--klar-space-6);
  text-align: center;
  color: var(--klar-text-secondary);
}

.klar-state--compact,
:where([data-klar-density="compact"]) .klar-state:where(:not(.klar-state--compact, .klar-state--comfortable)) { padding: var(--klar-space-6) var(--klar-space-4); gap: var(--klar-space-1); }

.klar-state__icon {
  display: flex;
  align-items: center;
  justify-content: center;
  width: 48px;
  height: 48px;
  margin-bottom: var(--klar-space-1);
  border-radius: 50%;
  background: var(--klar-gray-100);
  color: var(--klar-gray-500);
}

.klar-state--compact .klar-state__icon,
:where([data-klar-density="compact"]) .klar-state:where(:not(.klar-state--compact, .klar-state--comfortable)) .klar-state__icon { width: 36px; height: 36px; }
.klar-state--error .klar-state__icon { background: var(--klar-danger-subtle); color: var(--klar-red-600); }

/* Titles and details come from the backend: a long word or an address breaks
   instead of pushing the state wider than its container. */
.klar-state__title { margin: 0; font-size: var(--klar-text-lg); font-weight: var(--klar-weight-bold); color: var(--klar-text); overflow-wrap: anywhere; }
.klar-state__description { max-width: 46ch; color: var(--klar-text-secondary); overflow-wrap: anywhere; }
/* One click selects the whole code ("503 / req-8f2"), to paste into a support request. */
.klar-state__code { font-family: var(--klar-font-mono); font-size: var(--klar-text-xs); color: var(--klar-text-muted); overflow-wrap: anywhere; -webkit-user-select: all; user-select: all; }
.klar-state__actions { margin-top: var(--klar-space-3); display: flex; flex-wrap: wrap; justify-content: center; gap: var(--klar-space-2); }

/* ---- Field ----------------------------------------------------------- */

.klar-field {
  display: flex;
  flex-direction: column;
  gap: 4px;
  min-width: 0;
}

.klar-field__label {
  font-size: var(--klar-text-sm);
  font-weight: var(--klar-weight-medium);
  color: var(--klar-gray-700);
  line-height: 1.3;
}

.klar-field__required { margin-left: 3px; color: var(--klar-danger); }
.klar-field__optional { margin-left: 6px; font-weight: var(--klar-weight); color: var(--klar-text-muted); }
.klar-field__hint { font-size: var(--klar-text-sm); color: var(--klar-text-muted); }

.klar-field__error {
  font-size: var(--klar-text-sm);
  color: var(--klar-danger);
}

/* ---- Text input (also the shell for select triggers etc.) ------------ */

.klar-input {
  display: flex;
  align-items: center;
  gap: 6px;
  width: 100%;
  height: var(--klar-control);
  padding: 0 var(--klar-control-px);
  background: var(--klar-surface);
  border: 1px solid var(--klar-border-strong);
  border-radius: var(--klar-radius);
  color: var(--klar-text);
  transition: border-color var(--klar-dur-fast) var(--klar-ease), box-shadow var(--klar-dur-fast) var(--klar-ease);
}

.klar-input:hover { border-color: var(--klar-gray-400); }

.klar-input:focus-within {
  border-color: var(--klar-focus-color);
  box-shadow: var(--klar-focus-ring);
}

.klar-input--sm { height: var(--klar-control-sm); font-size: var(--klar-text-sm); padding: 0 8px; }
.klar-input--lg { height: var(--klar-control-lg); font-size: var(--klar-text-lg); padding: 0 12px; }

.klar-input--invalid,
.klar-input--invalid:hover { border-color: var(--klar-danger); }
.klar-input--invalid:focus-within { border-color: var(--klar-danger); box-shadow: var(--klar-focus-ring-danger); }

.klar-input--disabled { background: var(--klar-gray-50); color: var(--klar-text-disabled); cursor: not-allowed; }
.klar-input--disabled:hover { border-color: var(--klar-border-strong); }
.klar-input--readonly { background: var(--klar-gray-50); }

.klar-input__control {
  flex: 1;
  min-width: 0;
  height: 100%;
  padding: 0;
  border: 0;
  outline: 0;
  background: transparent;
  color: inherit;
  font: inherit;
}

.klar-input__control::placeholder { color: var(--klar-text-muted); opacity: 1; }
.klar-input__control:disabled { cursor: not-allowed; }

.klar-input__adornment {
  display: flex;
  align-items: center;
  color: var(--klar-text-muted);
  flex: none;
}

.klar-input__adornment--text { font-size: var(--klar-text-sm); }

.klar-input__clear {
  display: flex;
  align-items: center;
  justify-content: center;
  width: 18px;
  height: 18px;
  padding: 0;
  border: 0;
  border-radius: 50%;
  background: transparent;
  color: var(--klar-text-muted);
  flex: none;
}

.klar-input__clear:hover { background: var(--klar-gray-150); color: var(--klar-text); }
.klar-input__clear .klar-icon { --klar-icon-size: 12px; }

.klar-input__counter {
  flex: none;
  font-size: var(--klar-text-xs);
  color: var(--klar-text-muted);
  font-variant-numeric: tabular-nums;
}

/* ---- Checkbox -------------------------------------------------------- */

.klar-check {
  position: relative;
  display: inline-flex;
  align-items: flex-start;
  gap: 8px;
  cursor: pointer;
  line-height: 16px;
  -webkit-user-select: none;
  user-select: none;
}

.klar-check--bare { gap: 0; }

.klar-check__input {
  position: absolute;
  width: 16px;
  height: 16px;
  margin: 0;
  opacity: 0;
  cursor: pointer;
}

.klar-check__box {
  position: relative;
  flex: none;
  width: 16px;
  height: 16px;
  background: var(--klar-surface);
  border: 1px solid var(--klar-gray-400);
  border-radius: var(--klar-radius-sm);
  transition: background-color var(--klar-dur-fast) var(--klar-ease), border-color var(--klar-dur-fast) var(--klar-ease);
}

.klar-check:hover .klar-check__box { border-color: var(--klar-primary); }

.klar-check__input:focus-visible + .klar-check__box {
  box-shadow: var(--klar-focus-ring);
  border-color: var(--klar-focus-color);
}

.klar-check__input:checked + .klar-check__box,
.klar-check--indeterminate .klar-check__box {
  background: var(--klar-primary);
  border-color: var(--klar-primary);
}

.klar-check__box::after {
  content: "";
  position: absolute;
  inset: 0;
  background: var(--klar-on-primary);
  opacity: 0;
  -webkit-mask: url("data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' fill='none' stroke='black' stroke-width='3.2' stroke-linecap='round' stroke-linejoin='round'><polyline points='20 6 9 17 4 12'/></svg>") center / 12px no-repeat;
  mask: url("data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' fill='none' stroke='black' stroke-width='3.2' stroke-linecap='round' stroke-linejoin='round'><polyline points='20 6 9 17 4 12'/></svg>") center / 12px no-repeat;
}

.klar-check__input:checked + .klar-check__box::after { opacity: 1; }

.klar-check--indeterminate .klar-check__box::after {
  opacity: 1;
  -webkit-mask: url("data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' fill='none' stroke='black' stroke-width='3.2' stroke-linecap='round'><line x1='5' y1='12' x2='19' y2='12'/></svg>") center / 12px no-repeat;
  mask: url("data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' fill='none' stroke='black' stroke-width='3.2' stroke-linecap='round'><line x1='5' y1='12' x2='19' y2='12'/></svg>") center / 12px no-repeat;
}

.klar-check--invalid .klar-check__box,
.klar-check--invalid:hover .klar-check__input:not(:checked) + .klar-check__box { border-color: var(--klar-danger); }

.klar-check--disabled { cursor: not-allowed; opacity: 0.55; }
.klar-check--disabled .klar-check__input { cursor: not-allowed; }
.klar-check--disabled:hover .klar-check__input:not(:checked) + .klar-check__box { border-color: var(--klar-gray-400); }

.klar-check__text { display: flex; flex-direction: column; gap: 2px; }
.klar-check__label { color: var(--klar-text); }
.klar-check__hint { font-size: var(--klar-text-sm); color: var(--klar-text-muted); line-height: 1.35; }
.klar-check__error { font-size: var(--klar-text-sm); color: var(--klar-danger); line-height: 1.35; }

/* ---- Menu ------------------------------------------------------------ */

.klar-menu__popup {
  min-width: max(180px, 100%);
  /* A long menu scrolls instead of running off the screen. */
  max-height: min(26rem, calc(100vh - 16px));
  overflow-y: auto;
  padding: 4px;
  outline: none;
  /* The popup sits inside its trigger's container: a row menu in a centered
     table cell must not center its items. */
  text-align: start;
}

@supports (position-anchor: --klar-a) {
  .klar-menu__popup {
    min-width: max(180px, anchor-size(width));
  }
}

.klar-menu__item {
  display: flex;
  align-items: center;
  gap: 8px;
  height: 30px;
  padding: 0 8px;
  border-radius: var(--klar-radius);
  color: var(--klar-text);
  cursor: pointer;
  white-space: nowrap;
}

.klar-menu__item--highlighted { background: var(--klar-gray-100); }
.klar-menu__item--danger { color: var(--klar-danger); }
.klar-menu__item--danger.klar-menu__item--highlighted { background: var(--klar-danger-subtle); }
.klar-menu__item--disabled { color: var(--klar-text-disabled); cursor: not-allowed; }

.klar-menu__icon { width: 16px; display: flex; flex: none; color: var(--klar-text-secondary); }
.klar-menu__item--danger .klar-menu__icon { color: inherit; }
.klar-menu__label { flex: 1; min-width: 0; overflow: hidden; text-overflow: ellipsis; }
.klar-menu__hint { margin-left: 16px; font-size: var(--klar-text-sm); color: var(--klar-text-muted); }

.klar-menu__separator { height: 1px; margin: 4px -4px; background: var(--klar-border); }

.klar-menu__heading {
  padding: 6px 8px 2px;
  font-size: var(--klar-text-xs);
  font-weight: var(--klar-weight-bold);
  letter-spacing: 0.06em;
  text-transform: uppercase;
  color: var(--klar-text-muted);
}
"""
