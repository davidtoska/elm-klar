module Klar.Internal.Css.Overlay exposing (css)

{-| The rules of `overlay`, part of the stylesheet of the package. Edit the CSS here;
`Klar.Internal.Css` puts the parts together in order.
-}


css : String
css =
    """
/* ==========================================================================
   overlay.css - owned by the overlay component group
   Modal, drawer, confirm dialog, toast, popover, tooltip, context menu,
   command palette, shortcut help.

   House rules: overlays animate with `animation` only. No persistent
   transform, filter or will-change on an element that can contain a popup
   (it would turn the fixed popup into a box relative to that element).
   ========================================================================== */

/* ---- Overlay host ---------------------------------------------------- */

.klar-overlay-host {
  min-height: 100%;
}

.klar-overlay-host__page:focus { outline: none; }

.klar-overlay-host:focus {
  outline: none;
}

/* Wrappers that only carry an event listener (the overlay layer listens to the
   focus on the page through them). They take no part in the layout. */
.klar-contents {
  display: contents;
}

/* ---- Modal & drawer -------------------------------------------------- */

.klar-modal-lock {
  display: none;
}

/* base.css hides the page scrollbar while a dialog is open (the page would
   otherwise jump 10px sideways). Keep its place free, and paint the strip like
   the dimmed page so that it does not show up as a light edge. */
html:has(.klar-modal-lock) {
  scrollbar-gutter: stable;
  background: linear-gradient(var(--klar-overlay), var(--klar-overlay)), var(--klar-bg);
}

.klar-modal {
  --klar-modal-w: 560px;
  position: fixed;
  inset: 0;
  z-index: var(--klar-z-modal);
  display: flex;
  align-items: center;
  justify-content: center;
  padding: var(--klar-space-6);
}

.klar-modal--sm { --klar-modal-w: 400px; }
.klar-modal--md { --klar-modal-w: 560px; }
.klar-modal--lg { --klar-modal-w: 800px; }

.klar-modal__backdrop {
  position: absolute;
  inset: 0;
  background: var(--klar-overlay);
  animation: klar-fade-in var(--klar-dur) var(--klar-ease);
}

/* Focus that falls out of the open dialog (the focused element was removed or
   disabled, and the page fell back to the body) is the only thing in the DOM that
   no event reports. This element runs an animation exactly while no overlay
   contains focus; the dialog on top hears `animationstart` and takes focus back.
   The animation does nothing visible. The same selector list names every
   surface that can hold focus: the dialogs, the palette and the toasts. */
.klar-modal__guard {
  position: absolute;
  width: 0;
  height: 0;
  pointer-events: none;
}

:root:not(:has(.klar-modal__dialog:focus-within, .klar-palette__panel:focus-within, .klar-toasts:focus-within))
  .klar-modal__guard {
  animation: klar-focus-lost 1ms;
}

@keyframes klar-focus-lost {
  from { opacity: 0.99; }
  to { opacity: 1; }
}

/* Invisible tab stops that keep keyboard focus inside the dialog. */
.klar-modal__sentinel {
  position: fixed;
  top: 0;
  left: 0;
  width: 1px;
  height: 1px;
  opacity: 0;
  pointer-events: none;
  outline: none;
}

.klar-modal__dialog {
  position: relative;
  display: flex;
  flex-direction: column;
  width: var(--klar-modal-w);
  max-width: 100%;
  max-height: 100%;
  background: var(--klar-surface);
  border: 1px solid var(--klar-border-strong);
  border-radius: var(--klar-radius-lg);
  box-shadow: var(--klar-shadow-lg);
  color: var(--klar-text);
  animation: klar-modal-in var(--klar-dur-slow) var(--klar-ease);
  outline: none;
}

.klar-modal--tall > .klar-modal__dialog {
  height: 100%;
}


.klar-modal__header {
  flex: none;
  display: flex;
  align-items: flex-start;
  gap: var(--klar-space-3);
  padding: var(--klar-space-3) var(--klar-space-3) var(--klar-space-3) var(--klar-space-5);
  border-bottom: 1px solid var(--klar-border);
}

.klar-modal__heading {
  flex: 1;
  min-width: 0;
  padding-top: 5px;
}

.klar-modal__title {
  font-size: var(--klar-text-xl);
  font-weight: var(--klar-weight-bold);
  line-height: var(--klar-leading-tight);
  color: var(--klar-text);
  overflow-wrap: anywhere;
}

.klar-modal__subtitle {
  margin-top: 2px;
  font-size: var(--klar-text-sm);
  color: var(--klar-text-muted);
}

.klar-modal__close {
  flex: none;
}

.klar-modal__body {
  flex: 1 1 auto;
  min-height: 0;
  overflow: auto;
  overscroll-behavior: contain;
  overflow-wrap: break-word;
  padding: var(--klar-space-4) var(--klar-space-5);
}

.klar-modal__body--flush {
  padding: 0;
}

.klar-modal__end {
  height: 0;
  outline: none;
}

.klar-modal__footer {
  flex: none;
  display: flex;
  align-items: center;
  gap: var(--klar-space-3);
  padding: var(--klar-space-3) var(--klar-space-5);
  border-top: 1px solid var(--klar-border);
  background: var(--klar-surface-subtle);
  border-radius: 0 0 var(--klar-radius-lg) var(--klar-radius-lg);
  outline: none;
}

/* The footer is where Shift+Tab lands after wrapping around: make it visible. */
.klar-modal__footer:focus-visible {
  outline: 2px solid var(--klar-focus-color);
  outline-offset: -2px;
}

.klar-modal__footer-start {
  display: flex;
  align-items: center;
  gap: var(--klar-space-2);
  min-width: 0;
  color: var(--klar-text-secondary);
  font-size: var(--klar-text-sm);
}

.klar-modal__footer-actions {
  display: flex;
  align-items: center;
  gap: var(--klar-space-2);
  margin-left: auto;
}

/* Long content at the start (a failed save with its "Try again") takes a
   line of its own above the actions instead of being squeezed beside them. */
.klar-modal__footer { flex-wrap: wrap; }
.klar-modal__footer-start { flex: 1 1 auto; }

/* Side panel (drawer) */

.klar-modal--side {
  padding: 0;
  align-items: stretch;
}

.klar-modal--side > .klar-modal__dialog {
  height: 100%;
  max-height: 100%;
  border-radius: 0;
}

.klar-modal--side .klar-modal__footer {
  border-radius: 0;
}

.klar-modal--side.klar-modal--sm { --klar-modal-w: 360px; }
.klar-modal--side.klar-modal--md { --klar-modal-w: 480px; }
.klar-modal--side.klar-modal--lg { --klar-modal-w: 720px; }

.klar-modal--right { justify-content: flex-end; }
.klar-modal--right > .klar-modal__dialog {
  border-width: 0 0 0 1px;
  animation-name: klar-slide-in-right;
}

.klar-modal--left { justify-content: flex-start; }
.klar-modal--left > .klar-modal__dialog {
  border-width: 0 1px 0 0;
  animation-name: klar-slide-in-left;
}

/* A nudge when someone tries to dismiss a static dialog. Two names, so that
   switching between them restarts the animation. */
.klar-modal.klar-modal .klar-modal__dialog--nudge-a { animation: klar-modal-nudge-a 200ms var(--klar-ease); }
.klar-modal.klar-modal .klar-modal__dialog--nudge-b { animation: klar-modal-nudge-b 200ms var(--klar-ease); }

@keyframes klar-modal-nudge-a {
  0%, 100% { transform: none; }
  40% { transform: scale(1.012); }
}

@keyframes klar-modal-nudge-b {
  0%, 100% { transform: none; }
  40% { transform: scale(1.012); }
}
@media (max-width: 640px) {
  .klar-modal {
    padding: var(--klar-space-2);
  }

  .klar-modal--side {
    padding: 0;
  }

  .klar-modal__header,
  .klar-modal__footer {
    padding-left: var(--klar-space-4);
    padding-right: var(--klar-space-4);
  }

  .klar-modal__body {
    padding-left: var(--klar-space-4);
    padding-right: var(--klar-space-4);
  }
}

/* ---- Confirm dialog -------------------------------------------------- */

.klar-confirm {
  display: flex;
  align-items: flex-start;
  gap: var(--klar-space-4);
}

.klar-confirm__icon {
  flex: none;
  display: flex;
  align-items: center;
  justify-content: center;
  width: 36px;
  height: 36px;
  border-radius: 50%;
  background: var(--klar-primary-subtle);
  color: var(--klar-primary);
}

.klar-confirm__icon--warning {
  background: var(--klar-warning-subtle);
  color: var(--klar-warning);
}

.klar-confirm__icon--danger {
  background: var(--klar-danger-subtle);
  color: var(--klar-danger);
}

.klar-confirm__content {
  flex: 1;
  min-width: 0;
  display: flex;
  flex-direction: column;
  gap: var(--klar-space-4);
  padding-top: 2px;
}

.klar-confirm__text {
  display: flex;
  flex-direction: column;
  gap: var(--klar-space-3);
}

.klar-confirm__message {
  color: var(--klar-text);
  overflow-wrap: anywhere;
}

.klar-confirm__list {
  display: flex;
  flex-direction: column;
  gap: 4px;
  padding-left: 18px;
  list-style: disc;
  color: var(--klar-text-secondary);
}

.klar-confirm__list li::marker {
  color: var(--klar-text-muted);
}

/* Only carries a click handler around the retry button. */
.klar-confirm__retry {
  display: contents;
}

/* ---- Toast ----------------------------------------------------------- */

.klar-toasts {
  position: fixed;
  right: var(--klar-space-4);
  bottom: var(--klar-space-4);
  z-index: var(--klar-z-toast);
  display: flex;
  flex-direction: column;
  align-items: stretch;
  gap: var(--klar-space-2);
  width: 380px;
  max-width: calc(100vw - 2 * var(--klar-space-4));
  pointer-events: none;
}

/* While a dialog is open the toasts leave the corner, where they would cover the
   footer buttons, and sit at the top of the window instead. */
:root:has(.klar-modal-lock) .klar-toasts {
  top: var(--klar-space-4);
  bottom: auto;
  left: 0;
  right: 0;
  margin-inline: auto;
}

/* Beside a drawer they go to the other side of the window, at the bottom, so that the
   title and the close button of the drawer stay in reach. On a narrow screen the
   drawer fills the window and they are at the top again. */
:root:has(.klar-modal--side.klar-modal--right) .klar-toasts {
  top: auto;
  bottom: var(--klar-space-4);
  left: var(--klar-space-4);
  right: auto;
  margin-inline: 0;
}

:root:has(.klar-modal--side.klar-modal--left) .klar-toasts {
  top: auto;
  bottom: var(--klar-space-4);
  left: auto;
  right: var(--klar-space-4);
  margin-inline: 0;
}

@media (max-width: 640px) {
  :root:has(.klar-modal--side.klar-modal--right) .klar-toasts,
  :root:has(.klar-modal--side.klar-modal--left) .klar-toasts {
    top: var(--klar-space-4);
    bottom: auto;
    left: 0;
    right: 0;
    margin-inline: auto;
  }
}

.klar-toast {
  --_accent: var(--klar-blue-600);
  pointer-events: auto;
  display: flex;
  align-items: flex-start;
  gap: var(--klar-space-3);
  padding: var(--klar-space-3) var(--klar-space-2) var(--klar-space-3) var(--klar-space-3);
  background: var(--klar-surface);
  border: 1px solid var(--klar-border-strong);
  border-left: 3px solid var(--_accent);
  border-radius: var(--klar-radius-lg);
  box-shadow: var(--klar-shadow-md);
  color: var(--klar-text);
  animation: klar-slide-in-right var(--klar-dur-slow) var(--klar-ease);
}

.klar-toast--success { --_accent: var(--klar-green-600); }
.klar-toast--warning { --_accent: var(--klar-amber-600); }
.klar-toast--danger { --_accent: var(--klar-red-600); }
.klar-toast--neutral { --_accent: var(--klar-gray-500); }

.klar-toast__icon {
  display: flex;
  padding-top: 1px;
  color: var(--_accent);
}

.klar-toast__content {
  flex: 1;
  min-width: 0;
  display: flex;
  flex-direction: column;
  gap: 2px;
  padding-top: 1px;
}

.klar-toast__title {
  font-weight: var(--klar-weight-bold);
  overflow-wrap: anywhere;
}

.klar-toast__message {
  color: var(--klar-text-secondary);
  overflow-wrap: anywhere;
}

.klar-toast__title + .klar-toast__message {
  color: var(--klar-text-secondary);
}

/* It carries the click that dismisses the toast after the action. Only as wide as
   its buttons: a click beside "Angre" must not dismiss the toast (and the
   chance to undo) without running the action. */
.klar-toast__actions {
  display: flex;
  align-self: flex-start;
  gap: var(--klar-space-2);
  margin-top: var(--klar-space-2);
}

.klar-toasts__more {
  align-self: flex-end;
  padding: 2px var(--klar-space-3);
  background: var(--klar-surface);
  border: 1px solid var(--klar-border);
  border-radius: var(--klar-radius-full);
  box-shadow: var(--klar-shadow-xs);
  color: var(--klar-text-muted);
  font-size: var(--klar-text-sm);
}


/* ---- Popover --------------------------------------------------------- */

.klar-popover__popup {
  padding: 0;
  outline: none;
}

.klar-popover__header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: var(--klar-space-2);
  min-height: 40px;
  padding: 4px var(--klar-space-2) 4px var(--klar-space-4);
  border-bottom: 1px solid var(--klar-border);
}

.klar-popover__title {
  font-weight: var(--klar-weight-bold);
  line-height: var(--klar-leading-tight);
}

.klar-popover__body {
  display: flex;
  flex-direction: column;
  gap: var(--klar-space-3);
  max-height: min(70vh, 520px);
  overflow: auto;
  padding: var(--klar-space-3) var(--klar-space-4) var(--klar-space-4);
}

.klar-popover__body--flush {
  padding: 0;
}

/* ---- Tooltip --------------------------------------------------------- */

[data-tip]::after,
.klar-tip-bubble {
  box-sizing: border-box;
  z-index: var(--klar-z-tooltip);
  width: max-content;
  max-width: min(280px, calc(100vw - 16px));
  padding: 5px 8px;
  border-radius: var(--klar-radius);
  background: var(--klar-gray-900);
  box-shadow: var(--klar-shadow-md);
  color: var(--klar-white);
  font: var(--klar-weight) var(--klar-text-sm) / 1.35 var(--klar-font);
  font-style: normal;
  letter-spacing: normal;
  text-align: left;
  text-decoration: none;
  text-indent: 0;
  text-shadow: none;
  text-transform: none;
  white-space: normal;
  overflow-wrap: anywhere;
  cursor: default;
  pointer-events: none;
  display: none;
}

[data-tip]::after {
  content: attr(data-tip) " " attr(data-tip-key) / "";
}

/* A tip does not exist until it is wanted, so it is laid out (and placed, and
   flipped) with the scroll position of that moment. It fades in after a short
   delay, so that moving the pointer across a toolbar does not flash tips.
   Keyboard focus gets it sooner. */
[data-tip]:hover::after,
.klar-tip-wrap:hover > .klar-tip-bubble {
  display: block;
  animation: klar-tip-in var(--klar-dur-fast) var(--klar-ease) 450ms backwards;
}

[data-tip]:focus-visible::after,
.klar-tip-wrap:focus-visible > .klar-tip-bubble,
.klar-tip-wrap:has(:focus-visible) > .klar-tip-bubble {
  display: block;
  animation: klar-tip-in var(--klar-dur-fast) var(--klar-ease) 150ms backwards;
}

[data-tip]:active::after,
.klar-tip-wrap:active > .klar-tip-bubble {
  display: none;
}

@keyframes klar-tip-in {
  from { opacity: 0; }
  to { opacity: 1; }
}

.klar-tip-wrap {
  display: inline-flex;
  max-width: 100%;
  min-width: 0;
  vertical-align: top;
}

.klar-tip-wrap:focus-visible {
  outline: 2px solid var(--klar-focus-color);
  outline-offset: 1px;
  border-radius: var(--klar-radius-sm);
}

.klar-tip-bubble__keys {
  display: inline-flex;
  margin-left: var(--klar-space-2);
  vertical-align: middle;
}

.klar-tip-bubble .klar-kbd {
  height: 16px;
  min-width: 16px;
  padding: 0 4px;
  border-color: color-mix(in srgb, var(--klar-white) 30%, transparent);
  background: color-mix(in srgb, var(--klar-white) 14%, transparent);
  color: var(--klar-white);
  font-size: 10.5px;
}

/* The tip sits centered above the element and 6px away. Anchor-centering
   keeps it inside the window at the left and right edges, and flip-block puts
   it below when there is no room above. */
@supports (anchor-name: --klar-a) and (anchor-scope: --klar-a) and (justify-self: anchor-center) {
  [data-tip],
  .klar-tip-wrap {
    anchor-name: --klar-tip;
    anchor-scope: --klar-tip;
  }

  [data-tip]::after,
  .klar-tip-bubble {
    position: fixed;
    position-anchor: --klar-tip;
    top: auto;
    bottom: anchor(top);
    justify-self: anchor-center;
    margin: 0 8px 6px;
    position-try-fallbacks: flip-block;
  }

  [data-tip-below]::after,
  [data-tip-below] > .klar-tip-bubble {
    top: anchor(bottom);
    bottom: auto;
    margin: 6px 8px 0;
  }
}

/* Browsers without anchor positioning: centered above the element. */
@supports not ((anchor-name: --klar-a) and (anchor-scope: --klar-a) and (justify-self: anchor-center)) {
  [data-tip],
  .klar-tip-wrap {
    position: relative;
  }

  [data-tip]::after,
  .klar-tip-bubble {
    position: absolute;
    bottom: calc(100% + 6px);
    left: 50%;
    transform: translateX(-50%);
  }
}

/* ---- Context menu ---------------------------------------------------- */

/* A zero-size box at the pointer. The menu inside is the ordinary menu popup,
   anchored to this point: it opens down and to the right, and flips towards
   the free side near the edges of the window. */
.klar-context {
  position: fixed;
  left: var(--klar-cx, 0px);
  top: var(--klar-cy, 0px);
  width: 0;
  height: 0;
  z-index: var(--klar-z-toast);
}

.klar-context > .klar-anchor {
  display: block;
  width: 0;
  height: 0;
}

.klar-context .klar-popup {
  margin: 2px 0 0;
  min-width: 200px;
}

.klar-context-area {
  min-width: 0;
  border-radius: var(--klar-radius);
}

.klar-context-area:hover {
  background: var(--klar-surface-hover);
}

.klar-context-area:focus-visible {
  outline-offset: -2px;
}

.klar-context-area--active,
.klar-context-area--active:hover {
  background: var(--klar-primary-subtle);
}

/* ---- Command palette ------------------------------------------------- */

/* Row heights below are mirrored in Klar/CommandPalette.elm (they let the
   keyboard keep the highlighted row in view): padding 4, heading 28,
   item 36, notice 40. */

.klar-palette {
  position: fixed;
  inset: 0;
  z-index: var(--klar-z-palette);
  display: flex;
  align-items: flex-start;
  justify-content: center;
  padding: min(14vh, 112px) var(--klar-space-4) var(--klar-space-4);
}

.klar-palette__backdrop {
  position: absolute;
  inset: 0;
  background: var(--klar-overlay);
  animation: klar-fade-in var(--klar-dur) var(--klar-ease);
}

.klar-palette__panel {
  position: relative;
  display: flex;
  flex-direction: column;
  width: 640px;
  max-width: 100%;
  max-height: 100%;
  overflow: hidden;
  background: var(--klar-surface);
  border: 1px solid var(--klar-border-strong);
  border-radius: var(--klar-radius-lg);
  box-shadow: var(--klar-shadow-lg);
  color: var(--klar-text);
  animation: klar-modal-in var(--klar-dur-slow) var(--klar-ease);
  outline: none;
}

.klar-palette__search {
  flex: none;
  display: flex;
  align-items: center;
  gap: 10px;
  height: 48px;
  padding: 0 var(--klar-space-3) 0 var(--klar-space-4);
  border-bottom: 1px solid var(--klar-border);
}

.klar-palette__search:focus-within {
  box-shadow: inset 0 -2px 0 var(--klar-primary);
}

.klar-palette__search-icon {
  display: flex;
  flex: none;
  color: var(--klar-text-muted);
}

.klar-palette__input {
  flex: 1;
  min-width: 0;
  height: 100%;
  padding: 0;
  border: 0;
  outline: 0;
  background: transparent;
  color: var(--klar-text);
  font: inherit;
  font-size: var(--klar-text-xl);
}

.klar-palette__input::placeholder {
  color: var(--klar-text-muted);
  opacity: 1;
}

.klar-palette__esc {
  display: flex;
  flex: none;
}

.klar-palette__clear {
  display: flex;
  align-items: center;
  justify-content: center;
  flex: none;
  width: 22px;
  height: 22px;
  padding: 0;
  border: 0;
  border-radius: 50%;
  background: transparent;
  color: var(--klar-text-muted);
}

.klar-palette__clear:hover {
  background: var(--klar-gray-150);
  color: var(--klar-text);
}

.klar-palette__results {
  flex: 1 1 auto;
  min-height: 0;
  max-height: 400px;
  overflow-y: auto;
  overscroll-behavior: contain;
  padding: 4px;
}

.klar-palette__heading {
  display: flex;
  align-items: flex-end;
  height: 28px;
  padding: 0 10px 4px;
  color: var(--klar-text-muted);
  font-size: var(--klar-text-xs);
  font-weight: var(--klar-weight-bold);
  letter-spacing: 0.06em;
  text-transform: uppercase;
}

.klar-palette__row {
  height: 36px;
}

.klar-palette__item {
  display: flex;
  align-items: center;
  gap: 10px;
  width: 100%;
  height: 100%;
  padding: 0 10px;
  border-radius: var(--klar-radius);
  cursor: pointer;
}

.klar-palette__item--active {
  background: var(--klar-primary-subtle);
}

.klar-palette__item--loading {
  cursor: default;
}

.klar-palette__icon {
  display: flex;
  flex: none;
  justify-content: center;
  width: 20px;
  color: var(--klar-text-secondary);
}

.klar-palette__item--active .klar-palette__icon {
  color: var(--klar-primary);
}

.klar-palette__text {
  flex: 1;
  min-width: 0;
  display: flex;
  align-items: baseline;
  gap: 10px;
}

.klar-palette__item--loading .klar-palette__text {
  align-items: center;
}

.klar-palette__label {
  flex: 0 1 auto;
  color: var(--klar-text);
}

.klar-palette__description {
  flex: 1 1 0;
  color: var(--klar-text-muted);
  font-size: var(--klar-text-sm);
}

.klar-palette__keys {
  display: inline-flex;
  flex: none;
  align-items: center;
  gap: 8px;
}

.klar-palette__notice {
  display: flex;
  align-items: center;
  gap: 10px;
  height: 40px;
  padding: 0 10px;
  color: var(--klar-text-secondary);
}

.klar-palette__notice-icon {
  display: flex;
  flex: none;
  justify-content: center;
  width: 20px;
}

.klar-palette__notice--error .klar-palette__notice-icon {
  color: var(--klar-danger);
}

.klar-palette__notice-text {
  flex: 1;
  min-width: 0;
}

.klar-palette__footer {
  flex: none;
  display: flex;
  align-items: center;
  gap: var(--klar-space-4);
  height: 34px;
  padding: 0 var(--klar-space-4);
  border-top: 1px solid var(--klar-border);
  background: var(--klar-surface-subtle);
  color: var(--klar-text-muted);
  font-size: var(--klar-text-sm);
}

.klar-palette__hint {
  display: inline-flex;
  align-items: center;
  gap: 6px;
}

@media (max-width: 640px) {
  .klar-palette {
    padding-top: var(--klar-space-4);
  }

  .klar-palette__keys {
    display: none;
  }
}

/* ---- Shortcut help --------------------------------------------------- */

.klar-shortcuts {
  display: flex;
  flex-direction: column;
  gap: var(--klar-space-4);
}

.klar-shortcuts__groups {
  display: flex;
  flex-direction: column;
  gap: var(--klar-space-5);
}

.klar-shortcuts__group {
  display: flex;
  flex-direction: column;
  gap: var(--klar-space-1);
}

.klar-shortcuts__list {
  display: flex;
  flex-direction: column;
}

.klar-shortcuts__row {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: var(--klar-space-4);
  min-height: 34px;
  border-bottom: 1px solid var(--klar-border-subtle);
}

.klar-shortcuts__row:last-child {
  border-bottom: 0;
}

.klar-shortcuts__label {
  min-width: 0;
  overflow-wrap: anywhere;
}

.klar-shortcuts__note {
  margin-left: var(--klar-space-2);
  color: var(--klar-text-muted);
  font-size: var(--klar-text-xs);
}

.klar-shortcuts__keys {
  display: inline-flex;
  flex: none;
  align-items: center;
  gap: 6px;
}

.klar-shortcuts__then {
  color: var(--klar-text-muted);
  font-size: var(--klar-text-xs);
}
"""
