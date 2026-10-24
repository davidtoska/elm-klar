module Klar.Internal.Css.Forms exposing (css)

{-| The rules of `forms`, part of the stylesheet of the package. Edit the CSS here;
`Klar.Internal.Css` puts the parts together in order.
-}


css : String
css =
    """
/* ==========================================================================
   Forms: text area, number, password, radio, checkbox group, switch, slider,
   segmented control, search, tag input, file drop, inline edit, form layout.
   Text fields reuse the `.klar-input` shell from core.css.
   ========================================================================== */

/* ---- Text area ------------------------------------------------------- */

.klar-textarea-wrap {
  display: flex;
  flex-direction: column;
  gap: 4px;
  min-width: 0;
}

.klar-textarea {
  --_pad-y: 6px;
  --_pad-x: var(--klar-control-px);
  display: grid;
  width: 100%;
  background: var(--klar-surface);
  border: 1px solid var(--klar-border-strong);
  border-radius: var(--klar-radius);
  color: var(--klar-text);
  transition: border-color var(--klar-dur-fast) var(--klar-ease), box-shadow var(--klar-dur-fast) var(--klar-ease);
}

.klar-textarea--sm { --_pad-y: 4px; --_pad-x: 8px; font-size: var(--klar-text-sm); }
.klar-textarea--lg { --_pad-y: 8px; --_pad-x: 12px; font-size: var(--klar-text-lg); }

.klar-textarea:hover { border-color: var(--klar-gray-400); }

.klar-textarea:focus-within {
  border-color: var(--klar-focus-color);
  box-shadow: var(--klar-focus-ring);
}

.klar-textarea--invalid,
.klar-textarea--invalid:hover { border-color: var(--klar-danger); }

.klar-textarea--invalid:focus-within {
  border-color: var(--klar-danger);
  box-shadow: var(--klar-focus-ring-danger);
}

.klar-textarea--disabled { background: var(--klar-gray-50); color: var(--klar-text-disabled); cursor: not-allowed; }
.klar-textarea--disabled:hover { border-color: var(--klar-border-strong); }
.klar-textarea--readonly { background: var(--klar-gray-50); }

.klar-textarea__control {
  grid-area: 1 / 1;
  display: block;
  width: 100%;
  min-width: 0;
  margin: 0;
  padding: var(--_pad-y) var(--_pad-x);
  border: 0;
  outline: 0;
  background: transparent;
  color: inherit;
  font: inherit;
  line-height: var(--klar-leading);
  resize: vertical;
}

.klar-textarea__control::placeholder { color: var(--klar-text-muted); opacity: 1; }
.klar-textarea__control:disabled { cursor: not-allowed; resize: none; }

.klar-textarea--resize-none .klar-textarea__control { resize: none; }
.klar-textarea--resize-vertical .klar-textarea__control { resize: vertical; }
.klar-textarea--disabled .klar-textarea__control { resize: none; }

/* Forced colors: the same focus outline and dashed invalid border as the input shell. */
@media (forced-colors: active) {
  .klar-textarea { border-color: CanvasText; }
  .klar-textarea:focus-within { outline: 2px solid Highlight; outline-offset: 1px; border-color: Highlight; }
  .klar-textarea--invalid,
  .klar-textarea--invalid:hover { border-style: dashed; border-width: 2px; }
  .klar-textarea--disabled { border-color: GrayText; color: GrayText; }
}

/* Auto-grow: the field is as tall as its text, between min and max rows. */
.klar-textarea--autogrow .klar-textarea__control {
  field-sizing: content;
  min-height: calc(var(--klar-rows-min, 3) * 1em * var(--klar-leading) + 2 * var(--_pad-y));
  max-height: calc(var(--klar-rows-max, 1000) * 1em * var(--klar-leading) + 2 * var(--_pad-y));
}

/* Without `field-sizing`: a hidden copy of the text (from data-replica)
   shares the grid cell and sets the height; the textarea fills the cell. */
@supports not (field-sizing: content) {
  .klar-textarea--autogrow::after {
    content: attr(data-replica) " ";
    grid-area: 1 / 1;
    visibility: hidden;
    overflow: hidden;
    padding: var(--_pad-y) var(--_pad-x);
    font: inherit;
    line-height: var(--klar-leading);
    white-space: pre-wrap;
    overflow-wrap: break-word;
    min-height: calc(var(--klar-rows-min, 3) * 1em * var(--klar-leading) + 2 * var(--_pad-y));
    max-height: calc(var(--klar-rows-max, 1000) * 1em * var(--klar-leading) + 2 * var(--_pad-y));
  }

  .klar-textarea--autogrow .klar-textarea__control {
    height: 100%;
    min-height: 0;
    max-height: none;
    overflow: auto;
  }
}

/* The line under a field that carries something at its end (`Field.viewWithAside`):
   hint and error on the left, the counter on the right. */
.klar-field__foot {
  display: flex;
  align-items: baseline;
  justify-content: space-between;
  gap: var(--klar-space-3);
}

.klar-field__messages {
  display: flex;
  flex: 1 1 auto;
  flex-direction: column;
  gap: 4px;
  min-width: 0;
}

.klar-field__foot > :not(.klar-field__messages) { flex: none; }

/* The inputs always sit inside a field, even with no label, hint or error to
   draw, so that they stay put (and keep the keyboard focus) when an error
   appears while the user types. A field around nothing but a text input must lay
   out like the input alone: the input is `width: 100%`, a bare one fills a flex
   row, but its wrapper is as wide as its content unless it is told to be as
   wide as the input would be. A field with a label, a hint or an error is not
   touched. (The toolbar sets the width of both, `navigation.css`.) */
.klar-field:has(> .klar-input:only-child) { width: 100%; }

.klar-textarea__counter {
  font-size: var(--klar-text-xs);
  color: var(--klar-text-muted);
  font-variant-numeric: tabular-nums;
  white-space: nowrap;
}

.klar-textarea__counter--near { color: var(--klar-amber-700); }
.klar-textarea__counter--over { color: var(--klar-danger); font-weight: var(--klar-weight-bold); }

/* The character counter of TextInput and TextArea, at the end of the line under
   the field. The text says what the color says (12/200, 260/200). */
.klar-counter {
  font-size: var(--klar-text-xs);
  color: var(--klar-text-muted);
  font-variant-numeric: tabular-nums;
  white-space: nowrap;
}

.klar-counter--near { color: var(--klar-amber-700); }
.klar-counter--over { color: var(--klar-danger); font-weight: var(--klar-weight-bold); }

@media (forced-colors: active) {
  .klar-counter--near,
  .klar-counter--over { color: CanvasText; }
  .klar-counter--over { text-decoration: underline; }
}

/* ---- Number input ---------------------------------------------------- */

.klar-number__control { font-variant-numeric: tabular-nums; }
.klar-number__control--end { text-align: end; }

.klar-number__steps {
  display: flex;
  align-self: stretch;
  flex: none;
  margin-block: 0;
  margin-inline: 2px calc(var(--klar-control-px) * -1);
  border-inline-start: 1px solid var(--klar-border);
}

.klar-input--sm .klar-number__steps { margin-inline-end: -8px; }
.klar-input--lg .klar-number__steps { margin-inline-end: -12px; }

.klar-number__step {
  display: flex;
  align-items: center;
  justify-content: center;
  width: 24px;
  padding: 0;
  border: 0;
  background: transparent;
  color: var(--klar-text-secondary);
  transition: background-color var(--klar-dur-fast) var(--klar-ease);
}

.klar-number__step + .klar-number__step { border-inline-start: 1px solid var(--klar-border-subtle); }
.klar-number__step:last-child {
  border-start-end-radius: calc(var(--klar-radius) - 1px);
  border-end-end-radius: calc(var(--klar-radius) - 1px);
}
.klar-number__step:hover:not(:disabled) { background: var(--klar-gray-100); color: var(--klar-text); }
.klar-number__step:active:not(:disabled) { background: var(--klar-gray-150); }
.klar-number__step:disabled { color: var(--klar-text-disabled); cursor: not-allowed; }

/* ---- Password input -------------------------------------------------- */

.klar-password {
  display: flex;
  flex-direction: column;
  gap: 6px;
  min-width: 0;
}

.klar-password__toggle {
  display: flex;
  align-items: center;
  justify-content: center;
  flex: none;
  width: 24px;
  height: 24px;
  margin-inline-end: -4px;
  padding: 0;
  border: 0;
  border-radius: var(--klar-radius);
  background: transparent;
  color: var(--klar-text-muted);
}

.klar-password__toggle:hover:not(:disabled) { background: var(--klar-gray-100); color: var(--klar-text); }
.klar-password__toggle:disabled { cursor: not-allowed; color: var(--klar-text-disabled); }

.klar-password__meter {
  display: flex;
  align-items: center;
  gap: var(--klar-space-2);
}

.klar-password__bars {
  display: flex;
  flex: 0 0 120px;
  gap: 3px;
}

.klar-password__bar {
  flex: 1;
  height: 4px;
  border-radius: var(--klar-radius-sm);
  background: var(--klar-gray-200);
  transition: background-color var(--klar-dur) var(--klar-ease);
}

.klar-password__meter--1 .klar-password__bar--on { background: var(--klar-red-500); }
.klar-password__meter--2 .klar-password__bar--on { background: var(--klar-amber-500); }
.klar-password__meter--3 .klar-password__bar--on { background: var(--klar-blue-500); }
.klar-password__meter--4 .klar-password__bar--on { background: var(--klar-green-500); }

.klar-password__strength {
  font-size: var(--klar-text-sm);
  color: var(--klar-text-secondary);
}

.klar-password__caps {
  display: flex;
  align-items: center;
  gap: var(--klar-space-1);
  font-size: var(--klar-text-sm);
  color: var(--klar-amber-700);
}

/* Forced colors take the background of the bars away: draw their outline, and
   fill the bars that are on with the system highlight. */
@media (forced-colors: active) {
  .klar-password__bar { border: 1px solid CanvasText; }
  .klar-password__bar--on { forced-color-adjust: none; background: Highlight; }
  .klar-password__caps { color: CanvasText; }
}

/* ---- Radio group and checkbox group ---------------------------------- */

.klar-radio-group,
.klar-checkgroup {
  min-width: 0;
  margin: 0;
  padding: 0;
  border: 0;
}

.klar-radio-group__legend,
.klar-checkgroup__legend {
  display: block;
  padding: 0;
  margin-bottom: 6px;
}

.klar-radio-group:focus-visible,
.klar-checkgroup:focus-visible {
  outline: 2px solid var(--klar-focus-color);
  outline-offset: 4px;
  border-radius: var(--klar-radius);
}

.klar-radio-group__options,
.klar-checkgroup__options {
  display: flex;
  flex-direction: column;
  gap: 8px;
}

.klar-radio-group__options--horizontal,
.klar-checkgroup__options--horizontal {
  flex-direction: row;
  flex-wrap: wrap;
  gap: 8px 20px;
}

.klar-checkgroup__all {
  margin-bottom: 8px;
  padding-bottom: 8px;
  border-bottom: 1px solid var(--klar-border-subtle);
}

.klar-radio {
  --_box: 16px;
  position: relative;
  display: inline-flex;
  align-items: flex-start;
  align-self: flex-start;
  gap: 8px;
  cursor: pointer;
  line-height: var(--_box);
  -webkit-user-select: none;
  user-select: none;
}

.klar-radio--sm { --_box: 14px; font-size: var(--klar-text-sm); }
.klar-radio--lg { --_box: 18px; font-size: var(--klar-text-lg); }

.klar-radio__input {
  position: absolute;
  width: var(--_box);
  height: var(--_box);
  margin: 0;
  opacity: 0;
  cursor: pointer;
}

.klar-radio__dot {
  position: relative;
  flex: none;
  width: var(--_box);
  height: var(--_box);
  background: var(--klar-surface);
  border: 1px solid var(--klar-gray-400);
  border-radius: 50%;
  transition: border-color var(--klar-dur-fast) var(--klar-ease), box-shadow var(--klar-dur-fast) var(--klar-ease);
}

.klar-radio__dot::after {
  content: "";
  position: absolute;
  inset: 3px;
  border-radius: 50%;
  background: var(--klar-primary);
  transform: scale(0);
  transition: transform var(--klar-dur-fast) var(--klar-ease);
}

.klar-radio:hover .klar-radio__dot { border-color: var(--klar-primary); }

.klar-radio__input:checked + .klar-radio__dot { border-color: var(--klar-primary); }
.klar-radio__input:checked + .klar-radio__dot::after { transform: scale(1); }

.klar-radio__input:focus-visible + .klar-radio__dot {
  box-shadow: var(--klar-focus-ring);
  border-color: var(--klar-focus-color);
}

.klar-radio-group--invalid .klar-radio__dot { border-color: var(--klar-danger); }

/* Like the radio group: an invalid checkbox group outlines its empty boxes in red. */
.klar-checkgroup--invalid .klar-check:not(.klar-check--disabled):not(.klar-check--indeterminate) .klar-check__input:not(:checked) + .klar-check__box {
  border-color: var(--klar-danger);
}

.klar-radio--disabled { cursor: not-allowed; opacity: 0.55; }
.klar-radio--disabled .klar-radio__input { cursor: not-allowed; }
.klar-radio--disabled:hover .klar-radio__dot { border-color: var(--klar-gray-400); }
.klar-radio--disabled .klar-radio__input:checked + .klar-radio__dot,
.klar-radio--disabled:hover .klar-radio__input:checked + .klar-radio__dot { border-color: var(--klar-primary); }

.klar-radio__text { display: flex; flex-direction: column; gap: 2px; }
.klar-radio__label { color: var(--klar-text); }
.klar-radio__description { font-size: var(--klar-text-sm); color: var(--klar-text-muted); line-height: 1.35; }

/* ---- Switch ---------------------------------------------------------- */

.klar-switch {
  --_w: 34px;
  --_h: 20px;
  --_gap: 2px;
  position: relative;
  display: inline-flex;
  align-items: flex-start;
  gap: 10px;
  cursor: pointer;
  -webkit-user-select: none;
  user-select: none;
}

.klar-switch--sm { --_w: 28px; --_h: 16px; font-size: var(--klar-text-sm); }
.klar-switch--lg { --_w: 44px; --_h: 24px; --_gap: 3px; font-size: var(--klar-text-lg); }

.klar-switch__input {
  position: absolute;
  width: var(--_w);
  height: var(--_h);
  margin: 0;
  opacity: 0;
  cursor: pointer;
}

.klar-switch__track {
  position: relative;
  flex: none;
  width: var(--_w);
  height: var(--_h);
  border-radius: var(--klar-radius-full);
  background: var(--klar-gray-300);
  transition: background-color var(--klar-dur) var(--klar-ease), box-shadow var(--klar-dur-fast) var(--klar-ease);
}

.klar-switch__thumb {
  position: absolute;
  top: var(--_gap);
  left: var(--_gap);
  width: calc(var(--_h) - 2 * var(--_gap));
  height: calc(var(--_h) - 2 * var(--_gap));
  border-radius: 50%;
  background: var(--klar-white);
  box-shadow: var(--klar-shadow-sm);
  transition: transform var(--klar-dur) var(--klar-ease);
}

.klar-switch:hover .klar-switch__track { background: var(--klar-gray-400); }

.klar-switch--on .klar-switch__track { background: var(--klar-primary); }
.klar-switch--on:hover .klar-switch__track { background: var(--klar-primary-hover); }
.klar-switch--on .klar-switch__thumb { transform: translateX(calc(var(--_w) - var(--_h))); }

.klar-switch__input:focus-visible + .klar-switch__track { box-shadow: var(--klar-focus-ring); }

.klar-switch--invalid .klar-switch__track { box-shadow: 0 0 0 1px var(--klar-danger); }

.klar-switch--disabled { cursor: not-allowed; opacity: 0.55; }
.klar-switch--disabled .klar-switch__input { cursor: not-allowed; }
.klar-switch--disabled:hover .klar-switch__track { background: var(--klar-gray-300); }
.klar-switch--disabled.klar-switch--on:hover .klar-switch__track { background: var(--klar-primary); }

.klar-switch--loading { cursor: progress; }
.klar-switch--loading .klar-switch__input { cursor: progress; }

/* "Clicks are ignored while saving": without this a click still flipped the
   hidden checkbox, so screen readers heard the opposite of what the switch
   shows until the save was done. */
.klar-switch--loading { pointer-events: none; }

.klar-switch--loading .klar-switch__thumb::after {
  content: "";
  position: absolute;
  inset: 2px;
  border: 1.5px solid var(--klar-primary);
  border-right-color: transparent;
  border-radius: 50%;
  animation: klar-spin 0.7s linear infinite;
}

.klar-switch__text {
  display: flex;
  flex-direction: column;
  gap: 2px;
  min-width: 0;
}

.klar-switch__label { color: var(--klar-text); line-height: var(--_h); }
.klar-switch__description { font-size: var(--klar-text-sm); color: var(--klar-text-muted); line-height: 1.35; }
.klar-switch__error { font-size: var(--klar-text-sm); color: var(--klar-danger); line-height: 1.35; }

.klar-switch--control-end {
  display: flex;
  flex-direction: row-reverse;
  justify-content: space-between;
  width: 100%;
}

/* ---- Slider and range slider ----------------------------------------- */

.klar-slider-field {
  display: flex;
  flex-direction: column;
  gap: 4px;
  min-width: 0;
}

.klar-slider {
  --_thumb: 16px;
  --_track: 4px;
  --_color: var(--klar-primary);
  --_fill: calc(var(--_thumb) / 2 + (100% - var(--_thumb)) * var(--klar-pct, 0));
  display: flex;
  align-items: flex-start;
  gap: var(--klar-space-3);
  width: 100%;
  min-width: 0;
}

.klar-slider--invalid { --_color: var(--klar-danger); }
.klar-slider--disabled { --_color: var(--klar-gray-400); }

.klar-slider__body {
  position: relative;
  isolation: isolate;
  flex: 1 1 auto;
  min-width: 0;
  height: var(--_thumb);
}

.klar-slider__body:has(.klar-slider__ticks) { margin-bottom: 10px; }
.klar-slider__body:has(.klar-slider__marks) { margin-bottom: 26px; }

/* The thumb is 16px but the control is 24px tall (WCAG 2.5.8); the 4px above and below
   overlap the space around the slider. */
.klar-slider__input {
  -webkit-appearance: none;
  appearance: none;
  display: block;
  width: 100%;
  height: max(24px, var(--_thumb));
  margin: calc((var(--_thumb) - max(24px, var(--_thumb))) / 2) 0;
  padding: 0;
  background: transparent;
  cursor: pointer;
}

.klar-slider__input:focus { outline: none; }
.klar-slider__input:disabled { cursor: not-allowed; }

.klar-slider__input::-webkit-slider-runnable-track {
  height: var(--_track);
  border-radius: var(--klar-radius-full);
  background: linear-gradient(
    to right,
    var(--_color) 0,
    var(--_color) var(--_fill),
    var(--klar-gray-200) var(--_fill),
    var(--klar-gray-200) 100%
  );
}

.klar-slider__input::-webkit-slider-thumb {
  -webkit-appearance: none;
  appearance: none;
  box-sizing: border-box;
  width: var(--_thumb);
  height: var(--_thumb);
  margin-top: calc((var(--_track) - var(--_thumb)) / 2);
  border: 2px solid var(--_color);
  border-radius: 50%;
  background: var(--klar-surface);
  box-shadow: var(--klar-shadow-sm);
  transition: box-shadow var(--klar-dur-fast) var(--klar-ease), background-color var(--klar-dur-fast) var(--klar-ease);
}

.klar-slider__input::-moz-range-track {
  height: var(--_track);
  border-radius: var(--klar-radius-full);
  background: var(--klar-gray-200);
}

.klar-slider__input::-moz-range-progress {
  height: var(--_track);
  border-radius: var(--klar-radius-full);
  background: var(--_color);
}

.klar-slider__input::-moz-range-thumb {
  box-sizing: border-box;
  width: var(--_thumb);
  height: var(--_thumb);
  border: 2px solid var(--_color);
  border-radius: 50%;
  background: var(--klar-surface);
  box-shadow: var(--klar-shadow-sm);
}

.klar-slider__input:hover:not(:disabled)::-webkit-slider-thumb { background: var(--klar-primary-subtle); }
.klar-slider__input:active:not(:disabled)::-webkit-slider-thumb { background: var(--klar-primary-subtle-hover); }
.klar-slider__input:focus-visible::-webkit-slider-thumb { box-shadow: var(--klar-focus-ring); }
.klar-slider__input:focus-visible::-moz-range-thumb { box-shadow: var(--klar-focus-ring); }

.klar-slider__input:disabled::-webkit-slider-thumb { background: var(--klar-gray-50); box-shadow: none; }
.klar-slider__input:disabled::-moz-range-thumb { background: var(--klar-gray-50); box-shadow: none; }

/* The line above the track: label on the left, value on the right. The value
   is not beside the track, so the track is as long as the field whatever the
   value says, and it does not change length while the thumb moves. */
.klar-slider-field__head {
  display: flex;
  align-items: baseline;
  justify-content: space-between;
  gap: var(--klar-space-3);
  min-width: 0;
}

.klar-slider-field__head--end { justify-content: flex-end; }
.klar-slider-field__head > .klar-field__label { min-width: 0; }

.klar-slider__value {
  flex: none;
  margin-left: auto;
  text-align: right;
  color: var(--klar-text);
  white-space: nowrap;
}

.klar-slider-field--disabled .klar-slider__value { color: var(--klar-text-disabled); }

.klar-slider__bubble {
  position: absolute;
  bottom: calc(100% + 6px);
  left: calc(var(--_thumb) / 2 + (100% - var(--_thumb)) * var(--klar-pct, 0));
  z-index: 3;
  padding: 2px 6px;
  border-radius: var(--klar-radius);
  background: var(--klar-gray-800);
  color: var(--klar-white);
  font-size: var(--klar-text-xs);
  font-variant-numeric: tabular-nums;
  white-space: nowrap;
  pointer-events: none;
  opacity: 0;
  transform: translateX(-50%);
  transition: opacity var(--klar-dur-fast) var(--klar-ease);
}

.klar-slider__bubble--range {
  left: calc(var(--_thumb) / 2 + (100% - var(--_thumb)) * ((var(--klar-lo, 0) + var(--klar-hi, 1)) / 2));
}

.klar-slider__body:hover .klar-slider__bubble,
.klar-slider__body:has(.klar-slider__input:focus-visible) .klar-slider__bubble,
.klar-slider__body:has(.klar-slider__input:active) .klar-slider__bubble { opacity: 1; }

.klar-slider__ticks,
.klar-slider__marks {
  position: absolute;
  left: 0;
  right: 0;
  pointer-events: none;
}

.klar-slider__ticks { top: calc(var(--_thumb) + 1px); height: 4px; }
.klar-slider__marks { top: calc(var(--_thumb) + 8px); }

.klar-slider__tick,
.klar-slider__mark {
  position: absolute;
  left: calc(var(--_thumb) / 2 + (100% - var(--_thumb)) * var(--klar-at, 0));
  transform: translateX(-50%);
}

.klar-slider__tick {
  top: 0;
  width: 1px;
  height: 4px;
  background: var(--klar-gray-400);
}

.klar-slider__mark {
  top: 0;
  font-size: var(--klar-text-xs);
  color: var(--klar-text-muted);
  white-space: nowrap;
}

/* Range slider: two inputs on top of each other. Only the thumbs take the
   mouse, so the two never fight for a click on the track. */

.klar-range__track {
  position: absolute;
  left: 0;
  right: 0;
  top: calc((var(--_thumb) - var(--_track)) / 2);
  height: var(--_track);
  border-radius: var(--klar-radius-full);
  background: var(--klar-gray-200);
}

.klar-range__fill {
  position: absolute;
  top: 0;
  bottom: 0;
  left: calc(var(--_thumb) / 2 + (100% - var(--_thumb)) * var(--klar-lo, 0));
  width: calc((100% - var(--_thumb)) * (var(--klar-hi, 1) - var(--klar-lo, 0)));
  border-radius: var(--klar-radius-full);
  background: var(--_color);
}

.klar-range__input {
  position: absolute;
  left: 0;
  top: 0;
  z-index: 1;
  pointer-events: none;
}

.klar-range__input--front { z-index: 2; }

.klar-range__input::-webkit-slider-runnable-track { background: transparent; }
.klar-range__input::-moz-range-track { background: transparent; }
.klar-range__input::-moz-range-progress { background: transparent; }
.klar-range__input::-webkit-slider-thumb { pointer-events: auto; cursor: pointer; }
.klar-range__input::-moz-range-thumb { pointer-events: auto; cursor: pointer; }
.klar-range__input:disabled::-webkit-slider-thumb { cursor: not-allowed; }
.klar-range__input:disabled::-moz-range-thumb { cursor: not-allowed; }

/* ---- Segmented control ----------------------------------------------- */

.klar-segmented-field {
  display: flex;
  flex-direction: column;
  gap: 4px;
  min-width: 0;
}

.klar-segmented {
  --_h: calc(var(--klar-control) - 6px);
  display: inline-flex;
  align-items: stretch;
  align-self: flex-start;
  gap: 2px;
  max-width: 100%;
  padding: 2px;
  background: var(--klar-gray-100);
  border: 1px solid var(--klar-border);
  border-radius: var(--klar-radius);
}

.klar-segmented--sm { --_h: calc(var(--klar-control-sm) - 6px); }
.klar-segmented--lg { --_h: calc(var(--klar-control-lg) - 6px); }

.klar-segmented--full {
  display: flex;
  align-self: stretch;
  width: 100%;
}

.klar-segmented--full .klar-segmented__item { flex: 1 1 0; }

.klar-segmented--invalid { border-color: var(--klar-danger); }

.klar-segmented__item {
  position: relative;
  display: flex;
  min-width: 0;
  cursor: pointer;
}

.klar-segmented__input {
  position: absolute;
  inset: 0;
  width: 100%;
  height: 100%;
  margin: 0;
  opacity: 0;
  cursor: pointer;
}

.klar-segmented__content {
  display: flex;
  flex: 1;
  align-items: center;
  justify-content: center;
  gap: 6px;
  min-width: 0;
  height: var(--_h);
  padding: 0 12px;
  border-radius: var(--klar-radius-sm);
  color: var(--klar-text-secondary);
  font-weight: var(--klar-weight-medium);
  white-space: nowrap;
  transition: background-color var(--klar-dur-fast) var(--klar-ease), color var(--klar-dur-fast) var(--klar-ease);
}

.klar-segmented__label {
  min-width: 0;
  overflow: hidden;
  text-overflow: ellipsis;
}

.klar-segmented--sm .klar-segmented__content { padding: 0 8px; font-size: var(--klar-text-sm); gap: 5px; }
.klar-segmented--lg .klar-segmented__content { padding: 0 16px; font-size: var(--klar-text-lg); }

.klar-segmented__content--icon-only,
.klar-segmented--sm .klar-segmented__content--icon-only,
.klar-segmented--lg .klar-segmented__content--icon-only {
  width: var(--_h);
  padding: 0;
}

.klar-segmented__item:hover .klar-segmented__content {
  background: var(--klar-gray-150);
  color: var(--klar-text);
}

.klar-segmented__input:checked + .klar-segmented__content {
  background: var(--klar-surface);
  color: var(--klar-blue-700);
  box-shadow: var(--klar-shadow-sm), 0 0 0 1px var(--klar-border-strong);
}

.klar-segmented__input:focus-visible + .klar-segmented__content {
  outline: 2px solid var(--klar-focus-color);
  outline-offset: 1px;
}

.klar-segmented__item--disabled { cursor: not-allowed; opacity: 0.5; }
.klar-segmented__item--disabled .klar-segmented__input { cursor: not-allowed; }
.klar-segmented__item--disabled:hover .klar-segmented__content { background: transparent; color: var(--klar-text-secondary); }
.klar-segmented__item--disabled:hover .klar-segmented__input:checked + .klar-segmented__content { background: var(--klar-surface); color: var(--klar-blue-700); }

.klar-segmented--disabled .klar-segmented__item { cursor: not-allowed; }

/* ---- Search input ---------------------------------------------------- */

.klar-search__control::-webkit-search-decoration,
.klar-search__control::-webkit-search-cancel-button,
.klar-search__control::-webkit-search-results-button,
.klar-search__control::-webkit-search-results-decoration {
  -webkit-appearance: none;
  appearance: none;
  display: none;
}

.klar-search__spinner {
  display: flex;
  align-items: center;
  flex: none;
  color: var(--klar-text-muted);
}

.klar-search__keys {
  display: flex;
  flex: none;
}

.klar-search__keys .klar-kbd {
  height: 18px;
  min-width: 18px;
  padding: 0 4px;
  border-bottom-width: 1px;
  color: var(--klar-text-muted);
}

/* ---- Tag input ------------------------------------------------------- */

.klar-taginput-wrap { min-width: 0; }

.klar-input.klar-taginput {
  flex-wrap: wrap;
  align-items: center;
  gap: 4px;
  height: auto;
  min-height: var(--klar-control);
  padding: 3px 6px;
  cursor: text;
}

.klar-input--sm.klar-taginput { min-height: var(--klar-control-sm); padding: 2px 4px; }
.klar-input--lg.klar-taginput { min-height: var(--klar-control-lg); padding: 5px 8px; }

/* The chips sit in a wrapper so the input is never moved when they come and go
   (see TagInput.view); the wrapper takes no box of its own. */
.klar-taginput__tags { display: contents; }

.klar-taginput__input {
  flex: 1 1 96px;
  min-width: 96px;
  height: 24px;
  padding: 0 2px;
  border: 0;
  outline: 0;
  background: transparent;
  color: inherit;
  font: inherit;
}

.klar-taginput__input::placeholder { color: var(--klar-text-muted); opacity: 1; }
.klar-taginput__input:disabled { cursor: not-allowed; }

.klar-taginput__count {
  flex: none;
  margin-inline-start: auto;
  font-size: var(--klar-text-xs);
  color: var(--klar-text-muted);
}

/* ---- File drop ------------------------------------------------------- */

.klar-filedrop {
  display: flex;
  flex-direction: column;
  gap: var(--klar-space-2);
  min-width: 0;
}

.klar-filedrop__zone {
  position: relative;
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  gap: var(--klar-space-2);
  padding: var(--klar-space-5) var(--klar-space-4);
  background: var(--klar-surface-subtle);
  border: 1px dashed var(--klar-border-strong);
  border-radius: var(--klar-radius-lg);
  text-align: center;
  transition: border-color var(--klar-dur-fast) var(--klar-ease), background-color var(--klar-dur-fast) var(--klar-ease);
}

.klar-filedrop__zone:hover { border-color: var(--klar-gray-400); }

.klar-filedrop--over .klar-filedrop__zone {
  background: var(--klar-primary-subtle);
  border-color: var(--klar-primary);
}

.klar-filedrop--invalid .klar-filedrop__zone { border-color: var(--klar-danger); }

.klar-filedrop--disabled .klar-filedrop__zone {
  background: var(--klar-gray-50);
  opacity: 0.6;
  cursor: not-allowed;
}

/* Hidden but focusable: the "Velg filer" label is its visible face. */
.klar-filedrop__input {
  position: absolute;
  width: 1px;
  height: 1px;
  margin: -1px;
  padding: 0;
  overflow: hidden;
  clip: rect(0, 0, 0, 0);
  opacity: 0;
  border: 0;
}

.klar-filedrop__input:focus-visible ~ .klar-filedrop__text .klar-filedrop__browse {
  box-shadow: var(--klar-focus-ring);
  border-color: var(--klar-focus-color);
}

.klar-filedrop__icon {
  display: flex;
  align-items: center;
  justify-content: center;
  width: 40px;
  height: 40px;
  border-radius: 50%;
  background: var(--klar-gray-100);
  color: var(--klar-gray-500);
  transition: background-color var(--klar-dur-fast) var(--klar-ease), color var(--klar-dur-fast) var(--klar-ease);
}

.klar-filedrop--over .klar-filedrop__icon {
  background: var(--klar-primary-subtle-hover);
  color: var(--klar-primary);
}

.klar-filedrop__text {
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  justify-content: center;
  gap: 6px 10px;
}

.klar-filedrop__title { font-weight: var(--klar-weight-medium); color: var(--klar-text); }
.klar-filedrop__or { color: var(--klar-text-muted); }

.klar-filedrop--compact .klar-filedrop__zone {
  flex-direction: row;
  justify-content: flex-start;
  padding: var(--klar-space-2) var(--klar-space-3);
  text-align: left;
}

.klar-filedrop--compact .klar-filedrop__icon { width: 28px; height: 28px; }

.klar-filedrop__list {
  display: flex;
  flex-direction: column;
  background: var(--klar-surface);
  border: 1px solid var(--klar-border);
  border-radius: var(--klar-radius-lg);
}

.klar-filedrop__file {
  display: flex;
  align-items: center;
  gap: var(--klar-space-3);
  padding: 4px var(--klar-space-2) 4px var(--klar-space-3);
  min-height: 40px;
}

.klar-filedrop__file + .klar-filedrop__file { border-top: 1px solid var(--klar-border-subtle); }

.klar-filedrop__file-icon { display: flex; color: var(--klar-text-muted); }
.klar-filedrop__file--invalid .klar-filedrop__file-icon { color: var(--klar-danger); }

.klar-filedrop__file-text {
  display: flex;
  flex: 1;
  flex-wrap: wrap;
  align-items: baseline;
  gap: 0 var(--klar-space-3);
  min-width: 0;
}

.klar-filedrop__file-name { max-width: 100%; font-weight: var(--klar-weight-medium); }

.klar-filedrop__file-meta {
  font-size: var(--klar-text-sm);
  color: var(--klar-text-muted);
  font-variant-numeric: tabular-nums;
}

.klar-filedrop__file-problem {
  flex-basis: 100%;
  font-size: var(--klar-text-sm);
  color: var(--klar-danger);
}

/* ---- Inline edit ----------------------------------------------------- */

.klar-inline-edit {
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  gap: 4px 12px;
  min-width: 0;
}

.klar-inline-edit--editing {
  display: block;
  min-width: min(260px, 100%);
}

.klar-inline-edit__display {
  display: inline-flex;
  align-items: center;
  gap: 6px;
  position: relative;
  left: -5px;
  max-width: 100%;
  min-height: var(--klar-control-sm);
  margin: 0;
  padding: 0 4px;
  border: 1px solid transparent;
  border-radius: var(--klar-radius);
  background: transparent;
  color: var(--klar-text);
  font: inherit;
  text-align: left;
  cursor: text;
  transition: background-color var(--klar-dur-fast) var(--klar-ease), border-color var(--klar-dur-fast) var(--klar-ease);
}

.klar-inline-edit__display:hover {
  background: var(--klar-gray-50);
  border-color: var(--klar-border);
}

/* While saving or after a failed save the text keeps its place (and the
   keyboard focus), but cannot be edited. */
.klar-inline-edit__display--busy { cursor: default; }

.klar-inline-edit__display--busy:hover {
  background: transparent;
  border-color: transparent;
}

.klar-inline-edit__pencil {
  display: flex;
  color: var(--klar-text-muted);
  opacity: 0;
  transition: opacity var(--klar-dur-fast) var(--klar-ease);
}

.klar-inline-edit__display:hover .klar-inline-edit__pencil,
.klar-inline-edit__display:focus-visible .klar-inline-edit__pencil { opacity: 1; }

/* No hover on touch screens: keep the pencil visible there. */
@media (hover: none) {
  .klar-inline-edit__pencil { opacity: 1; }
}

.klar-inline-edit__static {
  display: inline-flex;
  align-items: center;
  min-height: var(--klar-control-sm);
}

.klar-inline-edit__text { min-width: 0; overflow-wrap: anywhere; }
.klar-inline-edit__text--empty { color: var(--klar-text-muted); }

.klar-inline-edit__box { width: 100%; padding-right: 2px; }

.klar-inline-edit__action {
  display: flex;
  align-items: center;
  justify-content: center;
  flex: none;
  width: 22px;
  height: 22px;
  padding: 0;
  border: 0;
  border-radius: var(--klar-radius);
  background: transparent;
  color: var(--klar-text-muted);
}

.klar-inline-edit__action:hover { background: var(--klar-gray-100); color: var(--klar-text); }
.klar-inline-edit__action--save { color: var(--klar-success); }
.klar-inline-edit__action--save:hover { background: var(--klar-success-subtle); color: var(--klar-green-700); }

/* an editor that is open when the field is disabled: its buttons are inert */
.klar-inline-edit__action:disabled,
.klar-inline-edit__action:disabled:hover { background: transparent; color: var(--klar-text-disabled); cursor: not-allowed; }

.klar-inline-edit__error { margin-top: 4px; }

.klar-inline-edit__saving {
  display: inline-flex;
  align-items: center;
  gap: 6px;
  font-size: var(--klar-text-sm);
  color: var(--klar-text-muted);
}

.klar-inline-edit__failure {
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  gap: 6px var(--klar-space-2);
  padding: 4px var(--klar-space-2);
  background: var(--klar-danger-subtle);
  border: 1px solid var(--klar-danger-border);
  border-radius: var(--klar-radius);
  font-size: var(--klar-text-sm);
  color: var(--klar-red-700);
}

.klar-inline-edit__failure-icon { display: flex; color: var(--klar-danger); }

/* ---- Form layout ----------------------------------------------------- */

.klar-form {
  display: flex;
  flex-direction: column;
  gap: var(--klar-space-6);
  min-width: 0;
}

.klar-form-section {
  display: grid;
  grid-template-columns: minmax(0, 1fr);
  gap: var(--klar-space-3);
  padding-top: var(--klar-space-6);
  border-top: 1px solid var(--klar-border);
}

.klar-form-section:first-child {
  padding-top: 0;
  border-top: 0;
}

@media (min-width: 880px) {
  .klar-form-section {
    grid-template-columns: minmax(180px, 1fr) minmax(0, 2fr);
    column-gap: var(--klar-space-8);
  }
}

.klar-form--stacked .klar-form-section { grid-template-columns: minmax(0, 1fr); }

.klar-form-section__title {
  font-size: var(--klar-text-lg);
  font-weight: var(--klar-weight-bold);
  line-height: var(--klar-leading-tight);
}

.klar-form-section__description {
  max-width: 40ch;
  margin-top: 4px;
  font-size: var(--klar-text-sm);
  color: var(--klar-text-muted);
}

.klar-form-section__body {
  display: flex;
  flex-direction: column;
  gap: var(--klar-space-4);
  min-width: 0;
  max-width: 640px;
}

.klar-form-grid {
  display: grid;
  grid-template-columns: repeat(var(--klar-cols, 2), minmax(0, 1fr));
  gap: var(--klar-space-4);
  align-items: start;
}

.klar-form-grid__full {
  grid-column: 1 / -1;
  min-width: 0;
}

@media (max-width: 640px) {
  .klar-form-grid { grid-template-columns: minmax(0, 1fr); }
}

.klar-form-actions {
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  justify-content: flex-end;
  gap: var(--klar-space-2);
  padding-top: var(--klar-space-4);
  border-top: 1px solid var(--klar-border);
}

/* The status takes the free space and wraps inside itself, so a long message never
   pushes the buttons onto a second line. */
.klar-form-actions > .klar-form-statusregion { flex: 1 1 0; min-width: 0; }

.klar-form-actions--sticky {
  position: sticky;
  bottom: 0;
  z-index: var(--klar-z-sticky);
  padding: var(--klar-space-3) var(--klar-space-4);
  background: var(--klar-surface);
  box-shadow: 0 -1px 0 var(--klar-border), 0 -6px 10px -8px color-mix(in srgb, var(--klar-gray-900) 25%, transparent);
}

/* A sticky element stops at the scroll container's padding, so the page
   content scrolled through the strip between the bar and the window edge.
   The strip is filled (the page content padding of the app shell, nothing
   elsewhere). */
.klar-form-actions--sticky::after,
.klar-form-unsaved--sticky::before {
  content: "";
  position: absolute;
  left: 0;
  right: 0;
  height: var(--klar-content-pad, 0px);
  background: var(--klar-surface);
  pointer-events: none;
}

.klar-form-actions--sticky::after { top: 100%; }
.klar-form-unsaved--sticky::before { bottom: 100%; }

.klar-form-summary:focus { outline: none; }
.klar-form-summary:focus-visible { outline: 2px solid var(--klar-focus-color); outline-offset: 2px; }

.klar-form-summary__intro { margin-bottom: 4px; }

.klar-form-summary__list {
  display: flex;
  flex-direction: column;
  gap: 2px;
  padding-left: 18px;
  list-style: disc;
}

.klar-form-summary__link {
  /* WCAG 2.2 target size (2.5.8): at least 24 by 24 CSS pixels */
  min-width: 24px;
  min-height: 24px;
  padding: 2px 4px;
  border: 0;
  background: none;
  font: inherit;
  text-align: left;
  color: var(--klar-red-700);
  text-decoration: underline;
  cursor: pointer;
}
.klar-form-summary__link:hover { color: var(--klar-danger-hover); }

/* The region around the status message: it can take focus (Form.focusStatus),
   so the retry button being replaced by "Saving ..." does not drop focus to the page. */
.klar-form-statusregion:focus { outline: none; }

.klar-form-statusregion:focus-visible {
  outline: 2px solid var(--klar-focus-color);
  outline-offset: 2px;
  border-radius: var(--klar-radius);
}

.klar-form-status {
  display: inline-flex;
  align-items: center;
  gap: var(--klar-space-2);
  color: var(--klar-text-secondary);
}

.klar-form-status__code { font-family: var(--klar-font-mono); font-size: var(--klar-text-xs); color: var(--klar-text-muted); }

/* "Unsaved changes" in a footer: a dot and a few words, no box. */
.klar-form-flag {
  display: inline-flex;
  align-items: center;
  gap: var(--klar-space-2);
  font-size: var(--klar-text-sm);
  color: var(--klar-text-secondary);
}

.klar-form-flag__dot {
  width: 8px;
  height: 8px;
  border-radius: var(--klar-radius-full);
  background: var(--klar-warning);
}

.klar-form-unsaved--sticky {
  position: sticky;
  top: 0;
  z-index: var(--klar-z-sticky);
}

/* The banner reads as one line: title, explanation, buttons at the end. */
.klar-form-unsaved .klar-alert__content {
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  gap: 4px var(--klar-space-4);
}

.klar-form-unsaved .klar-alert__title { margin-bottom: 0; }
.klar-form-unsaved .klar-alert__message { flex: 1 1 260px; color: var(--klar-text-secondary); }
.klar-form-unsaved .klar-alert__actions { margin: 0 0 0 auto; }

/* ---- Narrow containers ----------------------------------------------- */

/* `Layout.container [ maxWidth n, alignStart ]`: a column of limited width at the
   left edge of its parent instead of a centred page container. */
.klar-container--align-start {
  margin-inline: 0;
  padding-inline: 0;
}
"""
