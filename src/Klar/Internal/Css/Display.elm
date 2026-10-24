module Klar.Internal.Css.Display exposing (css)

{-| The rules of `display`, part of the stylesheet of the package. Edit the CSS here;
`Klar.Internal.Css` puts the parts together in order.
-}


css : String
css =
    """
/* ==========================================================================
   Data display: avatar, progress, chart, stat, list item, timeline,
   JSON viewer, tree.
   Owned by the display component group.
   ========================================================================== */

/* ---- Palette tokens -------------------------------------------------------
   Categorical chart colors, in a FIXED order (the order is what keeps
   neighbouring series apart for color-blind readers - never cycle or shuffle).
   Slots 1-5 are in the lightness band with real chroma, and the adjacent pairs
   clear the normal-vision floor (dE >= 15) and the color-blind floor (dE >= 8);
   checked with the dataviz palette validator. Slot 4 (amber) is below 3:1
   against white: it is legal because every chart also has a legend, native
   tooltips and a data table for screen readers. Slots 6-8 are the neutral
   "rest" colors (charcoal, pale blue, gray). Status colors are reserved for
   series that MEAN good/bad: use a tone for those, not slot 2 or 5.
   ------------------------------------------------------------------------ */

:root {
  --klar-chart-1: var(--klar-blue-600);
  --klar-chart-2: var(--klar-green-500);
  --klar-chart-3: var(--klar-blue-400);
  --klar-chart-4: var(--klar-amber-500);
  --klar-chart-5: var(--klar-red-500);
  --klar-chart-6: var(--klar-gray-700);
  --klar-chart-7: var(--klar-blue-300);
  --klar-chart-8: var(--klar-gray-500);

  --klar-chart-grid: var(--klar-gray-150);
  --klar-chart-axis: var(--klar-gray-300);
  --klar-chart-label: var(--klar-gray-600);
  --klar-chart-track: var(--klar-gray-100);
  --klar-chart-hover: rgba(16, 24, 40, 0.05);

  /* Avatar palette: muted tint + readable ink, assigned from the name. */
  --klar-avatar-0-bg: var(--klar-blue-100);
  --klar-avatar-0-fg: var(--klar-blue-800);
  --klar-avatar-1-bg: var(--klar-gray-150);
  --klar-avatar-1-fg: var(--klar-gray-800);
  --klar-avatar-2-bg: var(--klar-green-100);
  --klar-avatar-2-fg: var(--klar-green-700);
  --klar-avatar-3-bg: #d3ebee;
  --klar-avatar-3-fg: #1c5a63;
  --klar-avatar-4-bg: #e1e5f6;
  --klar-avatar-4-fg: #38418a;
  --klar-avatar-5-bg: #f0e9d8;
  --klar-avatar-5-fg: #6a5a2b;
  --klar-avatar-6-bg: var(--klar-amber-100);
  --klar-avatar-6-fg: var(--klar-amber-700);
  --klar-avatar-7-bg: #f3e1e3;
  --klar-avatar-7-fg: #7d3340;
}

@property --klar-p {
  syntax: "<number>";
  inherits: true;
  initial-value: 0;
}

/* ==========================================================================
   Avatar
   ========================================================================== */

.klar-avatar {
  --_bg: var(--klar-avatar-0-bg);
  --_fg: var(--klar-avatar-0-fg);
  --_size: 30px;
  position: relative;
  display: inline-flex;
  flex: none;
  align-items: center;
  justify-content: center;
  box-sizing: border-box;
  width: var(--_size);
  height: var(--_size);
  border-radius: 50%;
  background: var(--_bg);
  color: var(--_fg);
  font-size: max(8px, calc(var(--_size) * 0.38));
  font-weight: var(--klar-weight-bold);
  line-height: 1;
  letter-spacing: 0.02em;
  vertical-align: middle;
  -webkit-user-select: none;
  user-select: none;
}

.klar-avatar--xs { --_size: 18px; }
.klar-avatar--sm { --_size: 22px; }
.klar-avatar--lg { --_size: 40px; }
.klar-avatar--xl { --_size: 64px; }
.klar-avatar--square { border-radius: var(--klar-radius-lg); }
.klar-avatar--xl.klar-avatar--square { border-radius: 8px; }

.klar-avatar--c0 { --_bg: var(--klar-avatar-0-bg); --_fg: var(--klar-avatar-0-fg); }
.klar-avatar--c1 { --_bg: var(--klar-avatar-1-bg); --_fg: var(--klar-avatar-1-fg); }
.klar-avatar--c2 { --_bg: var(--klar-avatar-2-bg); --_fg: var(--klar-avatar-2-fg); }
.klar-avatar--c3 { --_bg: var(--klar-avatar-3-bg); --_fg: var(--klar-avatar-3-fg); }
.klar-avatar--c4 { --_bg: var(--klar-avatar-4-bg); --_fg: var(--klar-avatar-4-fg); }
.klar-avatar--c5 { --_bg: var(--klar-avatar-5-bg); --_fg: var(--klar-avatar-5-fg); }
.klar-avatar--c6 { --_bg: var(--klar-avatar-6-bg); --_fg: var(--klar-avatar-6-fg); }
.klar-avatar--c7 { --_bg: var(--klar-avatar-7-bg); --_fg: var(--klar-avatar-7-fg); }
.klar-avatar--neutral { --_bg: var(--klar-gray-100); --_fg: var(--klar-gray-500); }

.klar-avatar__initials,
.klar-avatar__glyph {
  display: flex;
  align-items: center;
  justify-content: center;
}

.klar-avatar__glyph .klar-icon {
  --klar-icon-size: calc(var(--_size) * 0.55);
}

.klar-avatar__image {
  position: absolute;
  inset: 0;
  border-radius: inherit;
  background-position: center;
  background-size: cover;
  background-repeat: no-repeat;
}

.klar-avatar__status {
  position: absolute;
  right: -1px;
  bottom: -1px;
  width: max(8px, calc(var(--_size) * 0.3));
  height: max(8px, calc(var(--_size) * 0.3));
  border-radius: 50%;
  background: var(--klar-gray-400);
  box-shadow: 0 0 0 2px var(--klar-surface);
}

.klar-avatar--xs .klar-avatar__status,
.klar-avatar--sm .klar-avatar__status { width: 8px; height: 8px; box-shadow: 0 0 0 1.5px var(--klar-surface); }
.klar-avatar__status--online { background: var(--klar-green-500); }
.klar-avatar__status--away { background: var(--klar-amber-500); }
.klar-avatar__status--busy { background: var(--klar-red-500); }
.klar-avatar__status--offline { background: var(--klar-gray-400); }

.klar-avatar-group {
  display: inline-flex;
  align-items: center;
  vertical-align: middle;
}

.klar-avatar-group > .klar-avatar {
  box-shadow: 0 0 0 2px var(--klar-surface);
}

.klar-avatar-group > .klar-avatar + .klar-avatar { margin-left: -6px; }
.klar-avatar-group--xs > .klar-avatar + .klar-avatar { margin-left: -4px; }
.klar-avatar-group--sm > .klar-avatar + .klar-avatar { margin-left: -5px; }
.klar-avatar-group--lg > .klar-avatar + .klar-avatar { margin-left: -8px; }
.klar-avatar-group--xl > .klar-avatar + .klar-avatar { margin-left: -14px; }

.klar-avatar--more {
  --_bg: var(--klar-gray-150);
  --_fg: var(--klar-gray-700);
  width: auto;
  min-width: var(--_size);
  padding: 0 6px;
  border-radius: var(--klar-radius-full);
  font-variant-numeric: tabular-nums;
}

/* ==========================================================================
   Progress
   ========================================================================== */

.klar-progress,
.klar-progress-ring {
  --_c: var(--klar-primary);
  --_track: var(--klar-blue-100);
}

.klar-progress--neutral { --_c: var(--klar-gray-500); --_track: var(--klar-gray-150); }
.klar-progress--success { --_c: var(--klar-success); --_track: var(--klar-green-100); }
.klar-progress--warning { --_c: var(--klar-warning); --_track: var(--klar-amber-100); }
.klar-progress--danger { --_c: var(--klar-danger); --_track: var(--klar-red-100); }

.klar-progress {
  --_h: 8px;
  display: flex;
  flex-direction: column;
  gap: 6px;
  width: 100%;
  min-width: 0;
}

.klar-progress--sm { --_h: 4px; }
.klar-progress--lg { --_h: 12px; }

.klar-progress__head {
  display: flex;
  align-items: baseline;
  justify-content: space-between;
  gap: var(--klar-space-3);
  font-size: var(--klar-text-sm);
  line-height: 1.2;
}

.klar-progress__label { color: var(--klar-text); font-weight: var(--klar-weight-medium); min-width: 0; }
.klar-progress__value { color: var(--klar-text-secondary); flex: none; }

.klar-progress__track {
  position: relative;
  height: var(--_h);
  overflow: hidden;
  border-radius: var(--klar-radius-full);
  background: var(--_track);
}

.klar-progress__bar {
  height: 100%;
  width: calc(var(--klar-p) * 1%);
  border-radius: inherit;
  background: var(--_c);
  transition: width var(--klar-dur-slow) var(--klar-ease);
}

.klar-progress--striped .klar-progress__bar {
  background-image: repeating-linear-gradient(
    45deg,
    color-mix(in srgb, var(--klar-white) 28%, transparent) 0,
    color-mix(in srgb, var(--klar-white) 28%, transparent) 6px,
    transparent 6px,
    transparent 12px
  );
  background-size: 17px 17px;
  animation: klar-progress-stripes 0.9s linear infinite;
}

.klar-progress--indeterminate .klar-progress__bar {
  width: 38%;
  transition: none;
  animation: klar-progress-slide 1.35s cubic-bezier(0.4, 0, 0.2, 1) infinite;
}

.klar-progress__segments {
  display: flex;
  gap: 3px;
}

.klar-progress__segment {
  flex: 1 1 0;
  height: var(--_h);
  min-width: 0;
  border-radius: var(--klar-radius-sm);
  background: var(--_track);
  transition: background-color var(--klar-dur) var(--klar-ease);
}

.klar-progress__segment--filled { background: var(--_c); }

/* An indeterminate bar with steps fills none of them: a highlight runs over the
   steps instead. Every step starts later by its place in the row (--klar-seg of
   --klar-segs steps), so the wave crosses the bar once per round. */
.klar-progress--indeterminate .klar-progress__segment {
  --_wave: 1.35s;
  animation: klar-progress-wave var(--_wave) ease-in-out infinite;
  animation-delay: calc(var(--klar-seg, 0) / var(--klar-segs, 1) * var(--_wave));
}

@keyframes klar-progress-wave {
  0%, 60%, 100% { background-color: var(--_track); }
  25% { background-color: var(--_c); }
}

@keyframes klar-progress-slide {
  from { transform: translateX(-100%); }
  to { transform: translateX(263%); }
}

@keyframes klar-progress-stripes {
  from { background-position: 0 0; }
  to { background-position: 17px 0; }
}

@keyframes klar-progress-ring-spin {
  to { transform: rotate(360deg); }
}

@media (prefers-reduced-motion: reduce) {
  .klar-progress--striped .klar-progress__bar { animation: none; }
  .klar-progress--indeterminate .klar-progress__bar { animation-duration: 3.2s; }
  .klar-progress--indeterminate .klar-progress__segment { --_wave: 3.2s; }
}

/* Ring: a conic-gradient arc masked into a ring, text in the middle. */

.klar-progress-ring {
  --_d: 64px;
  --_t: 6px;
  position: relative;
  display: inline-flex;
  flex: none;
  align-items: center;
  justify-content: center;
  width: var(--_d);
  height: var(--_d);
  vertical-align: middle;
}

.klar-progress-ring--sm { --_d: 36px; --_t: 4px; }
.klar-progress-ring--lg { --_d: 88px; --_t: 8px; }

.klar-progress-ring__arc {
  position: absolute;
  inset: 0;
  border-radius: 50%;
  background: conic-gradient(var(--_c) calc(var(--klar-p) * 1%), var(--_track) 0);
  -webkit-mask: radial-gradient(farthest-side, transparent calc(100% - var(--_t)), #000 calc(100% - var(--_t) + 0.5px));
  mask: radial-gradient(farthest-side, transparent calc(100% - var(--_t)), #000 calc(100% - var(--_t) + 0.5px));
  transition: --klar-p var(--klar-dur-slow) var(--klar-ease);
}

.klar-progress--indeterminate.klar-progress-ring .klar-progress-ring__arc {
  background: conic-gradient(from 0deg, transparent 0, transparent 22%, var(--_c) 100%);
  background-color: var(--_track);
  background-blend-mode: normal;
  animation: klar-progress-ring-spin 0.95s linear infinite;
}

.klar-progress-ring__center {
  position: relative;
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  max-width: calc(var(--_d) - 2 * var(--_t) - 4px);
  text-align: center;
  line-height: 1.1;
}

.klar-progress-ring__value {
  font-size: max(10px, calc(var(--_d) * 0.24));
  font-weight: var(--klar-weight-bold);
  color: var(--klar-text);
}

.klar-progress-ring__label {
  max-width: 100%;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
  font-size: max(9px, calc(var(--_d) * 0.14));
  color: var(--klar-text-muted);
}

.klar-progress-ring--sm .klar-progress-ring__label { display: none; }

/* ==========================================================================
   Chart
   Charts are plain HTML and CSS: bars, markers, donut slices and tooltips are
   elements, text is HTML, geometry is percentages. Only lines and areas are
   SVG - a data-URI mask made by Klar.Chart, painted with the series color - so
   a chart fills its container and keeps 11px text and 2px lines at any width.
   ========================================================================== */

@property --klar-f {
  syntax: "<number>";
  inherits: true;
  initial-value: 0;
}

.klar-chart-s0, .klar-chart-t-primary, .klar-chart-t-info { --_c: var(--klar-chart-1); --_t: var(--klar-blue-100); }
.klar-chart-s1 { --_c: var(--klar-chart-2); --_t: var(--klar-green-100); }
.klar-chart-s2 { --_c: var(--klar-chart-3); --_t: var(--klar-blue-100); }
.klar-chart-s3 { --_c: var(--klar-chart-4); --_t: var(--klar-amber-100); }
.klar-chart-s4 { --_c: var(--klar-chart-5); --_t: var(--klar-red-100); }
.klar-chart-s5 { --_c: var(--klar-chart-6); --_t: var(--klar-gray-150); }
.klar-chart-s6 { --_c: var(--klar-chart-7); --_t: var(--klar-blue-100); }
.klar-chart-s7, .klar-chart-t-neutral { --_c: var(--klar-chart-8); --_t: var(--klar-gray-150); }
.klar-chart-t-success { --_c: var(--klar-green-500); --_t: var(--klar-green-100); }
.klar-chart-t-warning { --_c: var(--klar-amber-500); --_t: var(--klar-amber-100); }
.klar-chart-t-danger { --_c: var(--klar-red-500); --_t: var(--klar-red-100); }
.klar-chart-t-primary, .klar-chart-t-info { --_c: var(--klar-primary); }

.klar-chart {
  display: flex;
  flex-direction: column;
  gap: var(--klar-space-3);
  min-width: 0;
  max-width: 100%;
  margin: 0;
}

.klar-chart__caption {
  display: flex;
  flex-direction: column;
  gap: 2px;
}

.klar-chart__title {
  font-size: var(--klar-text-md);
  font-weight: var(--klar-weight-bold);
  color: var(--klar-text);
}

.klar-chart__description {
  font-size: var(--klar-text-sm);
  color: var(--klar-text-muted);
}

/* The plot grid: value axis | plot, with the category axis underneath. */

.klar-chart__frame {
  display: grid;
  /* The label gutter never takes more than 38% of the chart: on a phone the
     long category names of a horizontal bar chart are cut with an ellipsis and
     the bars keep room. */
  grid-template-columns: min(var(--klar-chart-gutter, 40px), 38%) minmax(0, 1fr);
  grid-template-rows: var(--klar-chart-h, 220px) auto;
  column-gap: 8px;
  padding: 8px 18px 0 0;
  font-size: var(--klar-text-xs);
  line-height: 1.2;
  color: var(--klar-chart-label);
}

.klar-chart__y {
  position: relative;
  grid-column: 1;
  grid-row: 1;
}

.klar-chart__plot {
  position: relative;
  grid-column: 2;
  grid-row: 1;
  min-width: 0;
}

.klar-chart__x {
  position: relative;
  grid-column: 2;
  grid-row: 2;
  height: 18px;
  margin-top: 6px;
}

.klar-chart__tick,
.klar-chart__ylabel {
  position: absolute;
  right: 0;
  text-align: right;
  white-space: nowrap;
  transform: translateY(-50%);
}

.klar-chart__ylabel {
  max-width: 100%;
  overflow: hidden;
  text-overflow: ellipsis;
}


.klar-chart__xlabel {
  position: absolute;
  top: 0;
  overflow: hidden;
  text-align: center;
  text-overflow: ellipsis;
  white-space: nowrap;
  transform: translateX(-50%);
}

.klar-chart__xtick {
  position: absolute;
  top: 0;
  white-space: nowrap;
  transform: translateX(-50%);
}

/* In a narrow plot every second tick of the value axis is left out (the last
   one stays), so the labels do not run into each other. */
.klar-chart__x { container-type: inline-size; }

@container (max-width: 250px) {
  .klar-chart__xtick:nth-child(even):not(:last-child) { display: none; }
}

/* Gridlines and the baseline: one hairline each, never dashed. */

.klar-chart__grid,
.klar-chart__axis {
  position: absolute;
  left: 0;
  right: 0;
  height: 0;
  border-top: 1px solid var(--klar-chart-grid);
  pointer-events: none;
}

.klar-chart__axis { border-top-color: var(--klar-chart-axis); }

.klar-chart__grid--v,
.klar-chart__axis--v {
  top: 0;
  bottom: 0;
  left: auto;
  right: auto;
  width: 0;
  height: auto;
  border-top: 0;
  border-left: 1px solid var(--klar-chart-grid);
}

.klar-chart__axis--v { border-left-color: var(--klar-chart-axis); }

/* Lines and areas: a mask in the shape of the data, filled with the series
   color. `vector-effect` in the mask keeps the stroke 2px at any stretch. */

.klar-chart__line,
.klar-chart__area {
  position: absolute;
  inset: 0;
  background: var(--_c);
  -webkit-mask: var(--klar-mask) center / 100% 100% no-repeat;
  mask: var(--klar-mask) center / 100% 100% no-repeat;
  pointer-events: none;
}

.klar-chart__area { opacity: 0.1; }

/* One slot per category, laid over the plot: it carries the tooltip, the hover
   wash and the markers of that category. */

.klar-chart__slots {
  position: absolute;
  inset: 0;
  display: grid;
  grid-template-columns: repeat(var(--klar-n, 1), minmax(0, 1fr));
}

.klar-chart__plot--horizontal .klar-chart__slots {
  grid-template-columns: none;
  grid-template-rows: repeat(var(--klar-n, 1), minmax(0, 1fr));
}

.klar-chart__slot {
  position: relative;
  min-width: 0;
  min-height: 0;
}

.klar-chart__slot:hover { background: var(--klar-chart-hover); }

.klar-chart__slots:not(.klar-chart__bars) .klar-chart__slot::before {
  content: "";
  position: absolute;
  top: 0;
  bottom: 0;
  left: 50%;
  width: 1px;
  margin-left: -0.5px;
  background: var(--klar-chart-axis);
  opacity: 0;
}

.klar-chart__slots:not(.klar-chart__bars) .klar-chart__slot:hover::before { opacity: 1; }

.klar-chart__point {
  position: absolute;
  left: 50%;
  width: 8px;
  height: 8px;
  margin: -4px 0 0 -4px;
  border-radius: 50%;
  background: var(--_c);
  box-shadow: 0 0 0 2px var(--klar-surface);
}

.klar-chart__point--quiet { opacity: 0; }
.klar-chart__slot:hover .klar-chart__point--quiet { opacity: 1; }

/* Bars: a lane is never wider than 24px (18px tall when horizontal), however
   wide the slot is; only the data end is rounded; stacked segments are
   separated by a 2px surface-colored gap. */

.klar-chart__lanes {
  position: absolute;
  inset: 0 14%;
  display: flex;
  justify-content: center;
  gap: 2px;
}

.klar-chart__lane {
  position: relative;
  flex: 1 1 0;
  min-width: 1px;
  max-width: 24px;
}

.klar-chart__bar {
  position: absolute;
  left: 0;
  right: 0;
  min-height: 2px;
  background: var(--_c);
  transition: opacity var(--klar-dur-fast) var(--klar-ease);
}

.klar-chart__bar--up { border-radius: 4px 4px 0 0; }
.klar-chart__bar--down { border-radius: 0 0 4px 4px; }
.klar-chart__bar--right { border-radius: 0 4px 4px 0; }
.klar-chart__bar--left { border-radius: 4px 0 0 4px; }

.klar-chart__bar--stacked.klar-chart__bar--pos { box-shadow: 0 2px 0 var(--klar-surface); }
.klar-chart__bar--stacked.klar-chart__bar--neg { box-shadow: 0 -2px 0 var(--klar-surface); }

.klar-chart__plot--horizontal .klar-chart__lanes {
  inset: 14% 0;
  flex-direction: column;
}

.klar-chart__plot--horizontal .klar-chart__lane {
  flex: 1 1 0;
  min-width: 0;
  min-height: 1px;
  max-width: none;
  max-height: 18px;
}

.klar-chart__plot--horizontal .klar-chart__bar {
  top: 0;
  bottom: 0;
  left: auto;
  right: auto;
  min-height: 0;
  min-width: 2px;
}

.klar-chart__plot--horizontal .klar-chart__bar--stacked.klar-chart__bar--pos { box-shadow: -2px 0 0 var(--klar-surface); }
.klar-chart__plot--horizontal .klar-chart__bar--stacked.klar-chart__bar--neg { box-shadow: 2px 0 0 var(--klar-surface); }

.klar-chart__bars:has(.klar-chart__bar:hover) .klar-chart__bar:not(:hover) { opacity: 0.5; }

.klar-chart__value {
  position: absolute;
  left: 50%;
  margin-top: -4px;
  font-size: var(--klar-text-xs);
  color: var(--klar-text-secondary);
  white-space: nowrap;
  transform: translate(-50%, -100%);
  pointer-events: none;
}

.klar-chart__value--neg {
  margin-top: 4px;
  transform: translate(-50%, 0);
}

.klar-chart__plot--horizontal .klar-chart__value {
  top: 50%;
  left: auto;
  margin: 0 0 0 5px;
  transform: translateY(-50%);
}

.klar-chart__plot--horizontal .klar-chart__value--neg {
  margin: 0 5px 0 0;
  transform: translate(-100%, -50%);
}

/* Legend */

.klar-chart__legend {
  display: flex;
  flex-wrap: wrap;
  gap: 4px 16px;
  margin: 0;
  padding: 0;
  list-style: none;
  font-size: var(--klar-text-sm);
  color: var(--klar-text-secondary);
}

.klar-chart__legend-item {
  display: inline-flex;
  align-items: center;
  gap: 6px;
  min-width: 0;
}

.klar-chart__swatch {
  flex: none;
  background: var(--_c);
}

.klar-chart__swatch--bar {
  width: 10px;
  height: 10px;
  border-radius: 2px;
}

.klar-chart__swatch--line {
  width: 14px;
  height: 2px;
  border-radius: 1px;
}

.klar-chart__swatch--dashed {
  background: repeating-linear-gradient(90deg, var(--_c) 0, var(--_c) 4px, transparent 4px, transparent 7px);
}

.klar-chart__legend-label {
  max-width: 240px;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.klar-chart__legend-detail { color: var(--klar-text-muted); white-space: nowrap; }

/* Donut: every slice is a full-size element clipped to a ring sector, so the
   pointer hits (and the tooltip belongs to) the slice, not the whole disc. */

.klar-chart__donut {
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  gap: var(--klar-space-4) var(--klar-space-8);
}

.klar-chart__donut-frame {
  position: relative;
  flex: none;
  width: var(--klar-chart-w, 168px);
  max-width: 100%;
  aspect-ratio: 1;
}

.klar-chart__segments {
  position: absolute;
  inset: 0;
}

.klar-chart__segment {
  position: absolute;
  inset: 0;
  background: var(--_c);
  transition: opacity var(--klar-dur-fast) var(--klar-ease);
}

.klar-chart__segments:has(.klar-chart__segment:hover) .klar-chart__segment:not(:hover) { opacity: 0.45; }

.klar-chart__center {
  position: absolute;
  inset: 20%;
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  gap: 2px;
  text-align: center;
  pointer-events: none;
}

.klar-chart__center-value {
  max-width: 100%;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
  font-size: var(--klar-text-2xl);
  font-weight: var(--klar-weight-bold);
  line-height: 1.1;
  letter-spacing: -0.01em;
  color: var(--klar-text);
}

.klar-chart__center-caption {
  max-width: 100%;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
  font-size: var(--klar-text-xs);
  color: var(--klar-text-muted);
}

.klar-chart__donut .klar-chart__legend {
  flex: 0 1 360px;
  flex-direction: column;
  flex-wrap: nowrap;
  gap: 7px;
  min-width: 0;
}

.klar-chart__donut .klar-chart__legend-item {
  display: grid;
  grid-template-columns: 10px minmax(0, 1fr) auto;
  gap: 8px;
}

/* Gauge: a conic-gradient half disc cut into a ring. The value arc is the
   zone color, the rest of the ring a light step of the same color. */

.klar-chart__gauge {
  position: relative;
  width: var(--klar-chart-w, 200px);
  max-width: 100%;
}

.klar-chart__gauge-arc {
  width: 100%;
  aspect-ratio: 2 / 1;
  background: conic-gradient(
    from -90deg at 50% 100%,
    var(--_c) calc(var(--klar-f) * 180deg),
    var(--_t) 0 180deg,
    transparent 0
  );
  -webkit-mask: radial-gradient(farthest-side at 50% 100%, transparent 86%, #000 86.6%, #000 99.4%, transparent 100%);
  mask: radial-gradient(farthest-side at 50% 100%, transparent 86%, #000 86.6%, #000 99.4%, transparent 100%);
  transition: --klar-f var(--klar-dur-slow) var(--klar-ease);
}

.klar-chart__gauge-mark {
  position: absolute;
  bottom: 0;
  left: 50%;
  width: 50%;
  height: 2px;
  margin-bottom: -1px;
  background: var(--klar-surface);
  transform: rotate(calc((1 - var(--klar-f)) * -180deg));
  transform-origin: 0 50%;
  pointer-events: none;
}

.klar-chart__center--gauge {
  inset: auto 18% 22px 18%;
  justify-content: flex-end;
}

.klar-chart__gauge-scale {
  display: flex;
  justify-content: space-between;
  margin-top: 4px;
  padding: 0 2%;
  font-size: var(--klar-text-xs);
  color: var(--klar-chart-label);
}

/* Meter */

.klar-chart--meter { gap: 8px; min-width: 220px; }

.klar-meter__head {
  display: flex;
  align-items: baseline;
  justify-content: space-between;
  gap: var(--klar-space-3);
  font-size: var(--klar-text-sm);
}

.klar-meter__label { font-weight: var(--klar-weight-medium); color: var(--klar-text); }
.klar-meter__value { font-weight: var(--klar-weight-bold); color: var(--klar-text); }

.klar-meter__track {
  position: relative;
  height: 10px;
  border-radius: var(--klar-radius-full);
  background: var(--klar-chart-track);
}

.klar-meter__zone {
  position: absolute;
  top: 0;
  bottom: 0;
  background: var(--_t);
}

.klar-meter__zone:first-child { border-radius: var(--klar-radius-full) 0 0 var(--klar-radius-full); }
.klar-meter__zone:nth-last-child(2) { border-radius: 0 var(--klar-radius-full) var(--klar-radius-full) 0; }
.klar-meter__zone:first-child:nth-last-child(2) { border-radius: var(--klar-radius-full); }

.klar-meter__marker {
  position: absolute;
  top: -3px;
  bottom: -3px;
  width: 4px;
  margin-left: -2px;
  border-radius: 2px;
  background: var(--_c);
  box-shadow: 0 0 0 2px var(--klar-surface);
}

.klar-meter__scale {
  display: flex;
  justify-content: space-between;
  font-size: var(--klar-text-xs);
  color: var(--klar-chart-label);
}

/* Sparkline */

.klar-chart-spark {
  position: relative;
  display: inline-block;
  box-sizing: border-box;
  width: var(--klar-chart-w, 100%);
  max-width: 100%;
  height: var(--klar-chart-sh, 28px);
  vertical-align: middle;
}

.klar-chart-spark__field {
  position: absolute;
  inset: 2px;
}

.klar-chart-spark--empty,
.klar-chart-spark--loading {
  display: inline-flex;
  align-items: center;
  justify-content: center;
}

.klar-chart-spark--empty { color: var(--klar-text-disabled); }
.klar-chart-spark--loading > * { width: 100%; }

/* Selectable categories (Chart.onSelect): every slot is a button with a
   visible focus ring and a tooltip of its values (data-tip) on hover and on
   keyboard focus, so a keyboard or touch user can read every value. */

.klar-chart__slot--button {
  display: block;
  margin: 0;
  padding: 0;
  border: 0;
  border-radius: 0;
  background: transparent;
  color: inherit;
  font: inherit;
  text-align: inherit;
  cursor: pointer;
}

.klar-chart__slot--button:focus-visible {
  z-index: 1;
  outline: 2px solid var(--klar-focus-color);
  outline-offset: -2px;
  background: var(--klar-chart-hover);
}

.klar-chart__slots:not(.klar-chart__bars) .klar-chart__slot--button:focus-visible::before { opacity: 1; }
.klar-chart__slot--button:focus-visible .klar-chart__point--quiet { opacity: 1; }

.klar-chart__slot--button:hover::after,
.klar-chart__slot--button:focus-visible::after {
  content: attr(data-tip);
  position: absolute;
  bottom: calc(100% + var(--klar-space-1));
  left: 50%;
  z-index: var(--klar-z-tooltip);
  width: max-content;
  max-width: 240px;
  padding: var(--klar-space-1) var(--klar-space-2);
  border-radius: var(--klar-radius-sm);
  background: var(--klar-text);
  color: var(--klar-surface);
  font-size: var(--klar-text-xs);
  line-height: 1.4;
  text-align: start;
  white-space: pre-line;
  pointer-events: none;
  translate: -50% 0;
}

.klar-chart__plot--horizontal .klar-chart__slot--button:hover::after,
.klar-chart__plot--horizontal .klar-chart__slot--button:focus-visible::after {
  bottom: auto;
  top: 50%;
  left: 100%;
  translate: var(--klar-space-1) -50%;
}

.klar-chart__segment--button { cursor: pointer; }

.klar-chart__legend-entry {
  display: contents;
}

.klar-chart__legend-item--button {
  margin: calc(-1 * var(--klar-space-1));
  padding: var(--klar-space-1);
  border: 0;
  border-radius: var(--klar-radius-sm);
  background: transparent;
  color: inherit;
  font: inherit;
  text-align: start;
  cursor: pointer;
}

.klar-chart__legend-item--button:hover { background: var(--klar-chart-hover); }

.klar-chart__legend-item--button:focus-visible {
  outline: 2px solid var(--klar-focus-color);
  outline-offset: 0;
}

@media (forced-colors: active) {
  .klar-chart__slot--button:focus-visible,
  .klar-chart__legend-item--button:focus-visible {
    outline: 2px solid Highlight;
  }

  .klar-chart__slot--button:hover::after,
  .klar-chart__slot--button:focus-visible::after {
    border: 1px solid CanvasText;
    background: Canvas;
    color: CanvasText;
  }
}

/* ==========================================================================
   Stat (KPI tile)
   Values use the default proportional figures: tabular digits are for
   columns that must line up, not for a big standalone number.
   ========================================================================== */

.klar-stat {
  display: flex;
  flex-direction: column;
  gap: 8px;
  min-width: 0;
  padding: 12px 16px 14px;
  background: var(--klar-surface);
  border: 1px solid var(--klar-border);
  border-radius: var(--klar-radius-lg);
  color: var(--klar-text);
  font: inherit;
  text-align: left;
}

.klar-stat--flat {
  padding-left: 0;
  padding-right: 0;
  background: transparent;
  border-color: transparent;
}

.klar-stat--interactive {
  cursor: pointer;
  transition: border-color var(--klar-dur-fast) var(--klar-ease), background-color var(--klar-dur-fast) var(--klar-ease);
}

.klar-stat--interactive:hover { border-color: var(--klar-gray-300); background: var(--klar-surface-subtle); }
.klar-stat--interactive:focus-visible { outline: 2px solid var(--klar-focus-color); outline-offset: -2px; }

.klar-stat__head {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 8px;
  min-height: 16px;
}

.klar-stat__label {
  min-width: 0;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
  font-size: var(--klar-text-sm);
  font-weight: var(--klar-weight-medium);
  color: var(--klar-text-secondary);
}

.klar-stat__icon {
  display: flex;
  flex: none;
  color: var(--klar-text-muted);
}

.klar-stat__body {
  display: flex;
  flex-direction: column;
  gap: 6px;
  min-width: 0;
}

.klar-stat__figure {
  display: flex;
  flex-wrap: wrap;
  align-items: baseline;
  gap: 0 6px;
  min-width: 0;
}

/* A number is never cut off with an ellipsis (a truncated figure reads as a
   different figure). Long ones get a smaller size from the component, and what
   still does not fit breaks onto a second line. */

.klar-stat { --_fs: 26px; }
.klar-stat--sm { --_fs: 20px; }
.klar-stat--lg { --_fs: 34px; }

.klar-stat__value {
  min-width: 0;
  max-width: 100%;
  overflow-wrap: anywhere;
  font-size: var(--_fs);
  font-weight: var(--klar-weight-bold);
  line-height: 1.1;
  letter-spacing: -0.015em;
  color: var(--klar-text);
}

.klar-stat__value--long { font-size: calc(var(--_fs) * 0.8); }
.klar-stat__value--xlong { font-size: calc(var(--_fs) * 0.64); }
.klar-stat__value--missing { color: var(--klar-text-disabled); }

.klar-stat__unit {
  flex: none;
  font-size: var(--klar-text-md);
  color: var(--klar-text-muted);
}

.klar-stat__change {
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  gap: 2px 8px;
  font-size: var(--klar-text-sm);
}

.klar-stat__delta {
  display: inline-flex;
  align-items: center;
  gap: 3px;
  font-weight: var(--klar-weight-medium);
  color: var(--klar-gray-600);
}

.klar-stat__delta--success { color: var(--klar-green-700); }
.klar-stat__delta--danger { color: var(--klar-red-700); }
.klar-stat__delta--warning { color: var(--klar-amber-700); }
.klar-stat__delta--primary, .klar-stat__delta--info { color: var(--klar-blue-700); }

.klar-stat__delta-label,
.klar-stat__caption {
  font-size: var(--klar-text-sm);
  color: var(--klar-text-muted);
}

.klar-stat__trend {
  display: block;
  margin: 2px -4px -4px;
}

.klar-stat__skeleton {
  display: block;
  width: 56%;
}

.klar-stat__skeleton--short { width: 36%; }

.klar-stat__failure {
  display: flex;
  flex-direction: column;
  align-items: flex-start;
  gap: 4px;
  font-size: var(--klar-text-sm);
  color: var(--klar-text-secondary);
}

.klar-stat__failure-text {
  display: flex;
  align-items: center;
  gap: 6px;
  color: var(--klar-red-700);
}

/* A row of tiles: one bordered strip, hairlines between the tiles. */

.klar-stat-row {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
  overflow: hidden;
  background: var(--klar-surface);
  border: 1px solid var(--klar-border);
  border-radius: var(--klar-radius-lg);
}

/* Each tile draws the hairline on its own top and left edge and overlaps its
   neighbour by that one pixel; for the first column and row the line falls
   outside the strip and is clipped by it. */

.klar-stat-row > .klar-stat {
  margin: -1px 0 0 -1px;
  border: 0;
  border-top: 1px solid var(--klar-border);
  border-left: 1px solid var(--klar-border);
  border-radius: 0;
}

/* ==========================================================================
   List item
   ========================================================================== */

.klar-list {
  display: flex;
  flex-direction: column;
  min-width: 0;
  margin: 0;
  padding: 0;
  list-style: none;
}

.klar-list--scroll {
  overflow-y: auto;
}

/* A scrolling list takes keyboard focus (tabindex 0): the ring goes inside. */
.klar-list--scroll:focus-visible { outline-offset: -2px; }

.klar-list--bordered,
.klar-list-state--bordered {
  overflow: hidden;
  background: var(--klar-surface);
  border: 1px solid var(--klar-border);
  border-radius: var(--klar-radius-lg);
}

.klar-list-item {
  --_a: transparent;
  position: relative;
  display: flex;
  align-items: stretch;
  min-width: 0;
  list-style: none;
}

.klar-list-item::before {
  content: "";
  position: absolute;
  top: 0;
  bottom: 0;
  left: 0;
  width: 3px;
  background: var(--_a);
  pointer-events: none;
}

.klar-list--divided > .klar-list-item + .klar-list-item,
.klar-list--divided > .klar-list__heading + .klar-list-item { border-top: 1px solid var(--klar-border-subtle); }

.klar-list-item__main {
  display: flex;
  flex: 1 1 auto;
  align-items: center;
  gap: 10px;
  min-width: 0;
  min-height: 44px;
  padding: 7px 12px;
  background: transparent;
  border: 0;
  border-radius: 0;
  color: inherit;
  font: inherit;
  text-align: left;
  text-decoration: none;
}

.klar-list--compact .klar-list-item__main,
:where([data-klar-density="compact"]) .klar-list:where(:not(.klar-list--compact, .klar-list--comfortable)) .klar-list-item__main {
  gap: 8px;
  min-height: 32px;
  padding: 4px 10px;
}

.klar-list-item--interactive .klar-list-item__main { cursor: pointer; }
.klar-list-item--interactive:hover { background: var(--klar-surface-hover); }
.klar-list-item--interactive .klar-list-item__main:hover { text-decoration: none; }

.klar-list-item__main:focus-visible {
  outline: 2px solid var(--klar-focus-color);
  outline-offset: -2px;
}

.klar-list-item--selected {
  --_a: var(--klar-primary);
  background: var(--klar-primary-subtle);
}

.klar-list-item--selected.klar-list-item--interactive:hover { background: var(--klar-primary-subtle-hover); }

.klar-list-item--accent-neutral { --_a: var(--klar-gray-400); }
.klar-list-item--accent-primary { --_a: var(--klar-primary); }
.klar-list-item--accent-info { --_a: var(--klar-info); }
.klar-list-item--accent-success { --_a: var(--klar-success); }
.klar-list-item--accent-warning { --_a: var(--klar-warning); }
.klar-list-item--accent-danger { --_a: var(--klar-danger); }

.klar-list-item--disabled { opacity: 0.55; }
.klar-list-item--disabled .klar-list-item__main { cursor: not-allowed; }

.klar-list-item__leading {
  display: flex;
  flex: none;
  align-items: center;
  justify-content: center;
}

.klar-list-item__leading--icon {
  width: 30px;
  height: 30px;
  background: var(--klar-gray-100);
  border-radius: var(--klar-radius-lg);
  color: var(--klar-gray-600);
}

.klar-list--compact .klar-list-item__leading--icon,
:where([data-klar-density="compact"]) .klar-list:where(:not(.klar-list--compact, .klar-list--comfortable)) .klar-list-item__leading--icon { width: 22px; height: 22px; }

.klar-list-item__body {
  display: flex;
  flex: 1 1 auto;
  flex-direction: column;
  gap: 1px;
  min-width: 0;
}

.klar-list-item__title {
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
  font-weight: var(--klar-weight-medium);
  color: var(--klar-text);
}

.klar-list-item__secondary {
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
  font-size: var(--klar-text-sm);
  color: var(--klar-text-secondary);
}

/* A long meta text is cut (the whole text is the tooltip); it never pushes the
   title out of the row. */
.klar-list-item__meta {
  flex: 0 1 auto;
  min-width: 0;
  max-width: 45%;
  overflow: hidden;
  text-overflow: ellipsis;
  font-size: var(--klar-text-sm);
  color: var(--klar-text-muted);
  white-space: nowrap;
}

.klar-list-item__trailing {
  display: flex;
  flex: none;
  align-items: center;
  gap: 4px;
  padding: 0 8px 0 0;
}

.klar-list__heading {
  padding: 12px 12px 4px;
  font-size: var(--klar-text-xs);
  font-weight: var(--klar-weight-bold);
  letter-spacing: 0.06em;
  text-transform: uppercase;
  color: var(--klar-text-muted);
  list-style: none;
}

.klar-list-item--skeleton .klar-list-item__main { pointer-events: none; }


/* ==========================================================================
   Timeline
   ========================================================================== */

.klar-timeline {
  --_time-w: 52px;
  --_rail-w: 24px;
  display: flex;
  flex-direction: column;
  gap: var(--klar-space-4);
  min-width: 0;
}

.klar-timeline--scroll {
  overflow-y: auto;
  padding-right: 4px;
}

.klar-timeline__days {
  display: flex;
  flex-direction: column;
  gap: var(--klar-space-4);
  min-width: 0;
}

.klar-timeline__day {
  display: flex;
  flex-direction: column;
  gap: 8px;
  min-width: 0;
}

.klar-timeline__day-title {
  display: flex;
  align-items: baseline;
  gap: 8px;
  margin: 0;
  padding-left: calc(var(--_time-w) + var(--_rail-w) + 10px);
  font-size: var(--klar-text-sm);
  line-height: 1.3;
}

.klar-timeline__day-name { font-weight: var(--klar-weight-bold); color: var(--klar-text); }
.klar-timeline__day-date { color: var(--klar-text-muted); }

.klar-timeline__list {
  display: flex;
  flex-direction: column;
  margin: 0;
  padding: 0;
  list-style: none;
}

.klar-timeline__item {
  --_c: var(--klar-gray-400);
  position: relative;
  display: grid;
  grid-template-columns: var(--_time-w) var(--_rail-w) minmax(0, 1fr);
  padding-bottom: 14px;
}

.klar-timeline__item:last-child { padding-bottom: 2px; }

.klar-timeline__item--primary, .klar-timeline__item--info { --_c: var(--klar-blue-500); }
.klar-timeline__item--success { --_c: var(--klar-green-500); }
.klar-timeline__item--warning { --_c: var(--klar-amber-500); }
.klar-timeline__item--danger { --_c: var(--klar-red-500); }

/* The thin gray line between the markers of one day. */

.klar-timeline__item::before {
  content: "";
  position: absolute;
  top: 0;
  bottom: 0;
  left: calc(var(--_time-w) + var(--_rail-w) / 2);
  width: 1px;
  margin-left: -0.5px;
  background: var(--klar-border);
}

.klar-timeline__item:first-child::before { top: 10px; }
.klar-timeline__item:last-child::before { bottom: auto; height: 10px; }
.klar-timeline__item:only-child::before { display: none; }
.klar-timeline__item:first-child:last-child::before { display: none; }

.klar-timeline__time {
  padding-right: 8px;
  font-size: var(--klar-text-sm);
  line-height: 20px;
  text-align: right;
  color: var(--klar-text-muted);
  white-space: nowrap;
}

.klar-timeline__rail {
  position: relative;
  z-index: 1;
  display: flex;
  justify-content: center;
  align-items: flex-start;
}

.klar-timeline__marker {
  display: flex;
  align-items: center;
  justify-content: center;
  box-sizing: border-box;
  width: 20px;
  height: 20px;
  background: var(--klar-surface);
  border: 1px solid var(--_c);
  border-radius: 50%;
  color: var(--_c);
}

.klar-timeline__marker .klar-icon { --klar-icon-size: 12px; }

.klar-timeline__marker--dot {
  width: 9px;
  height: 9px;
  margin-top: 5.5px;
  background: var(--_c);
  box-shadow: 0 0 0 3px var(--klar-surface);
}

.klar-timeline__content {
  min-width: 0;
  padding-left: 10px;
}

.klar-timeline__headline {
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  gap: 2px 12px;
  min-height: 20px;
}

.klar-timeline__title {
  font-weight: var(--klar-weight-medium);
  line-height: 20px;
  color: var(--klar-text);
  overflow-wrap: anywhere;
}

.klar-timeline__author {
  display: inline-flex;
  flex: 0 1 auto;
  min-width: 0;
  max-width: 100%;
  white-space: nowrap;
  align-items: center;
  gap: 5px;
  font-size: var(--klar-text-sm);
  color: var(--klar-text-secondary);
}

.klar-timeline__author > .klar-avatar { flex: none; }

.klar-timeline__author-name {
  min-width: 0;
  overflow: hidden;
  text-overflow: ellipsis;
}

.klar-timeline__description {
  max-width: 76ch;
  margin: 2px 0 0;
  font-size: var(--klar-text-sm);
  line-height: 1.5;
  color: var(--klar-text-secondary);
  overflow-wrap: anywhere;
}

.klar-timeline__details { margin-top: 4px; }

.klar-timeline__summary {
  display: inline-flex;
  align-items: center;
  gap: 4px;
  padding: 2px 0;
  font-size: var(--klar-text-sm);
  color: var(--klar-text-link);
  cursor: pointer;
  list-style: none;
  -webkit-user-select: none;
  user-select: none;
}

.klar-timeline__summary::-webkit-details-marker { display: none; }
.klar-timeline__summary:hover { text-decoration: underline; }

.klar-timeline__summary .klar-icon { transition: transform var(--klar-dur-fast) var(--klar-ease); }
.klar-timeline__details[open] > .klar-timeline__summary .klar-icon { transform: rotate(90deg); }
.klar-timeline__summary-hide { display: none; }
.klar-timeline__details[open] > .klar-timeline__summary .klar-timeline__summary-show { display: none; }
.klar-timeline__details[open] > .klar-timeline__summary .klar-timeline__summary-hide { display: inline; }

.klar-timeline__details-body {
  max-width: 76ch;
  margin-top: 6px;
  padding: 8px 12px;
  background: var(--klar-surface-subtle);
  border-left: 2px solid var(--klar-border-strong);
  border-radius: 0 var(--klar-radius) var(--klar-radius) 0;
  font-size: var(--klar-text-sm);
}

.klar-timeline__footer {
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  gap: 4px 12px;
  min-height: 32px;
  padding-left: calc(var(--_time-w) + var(--_rail-w) + 10px);
}

.klar-timeline__footer-text {
  display: inline-flex;
  align-items: center;
  gap: 6px;
  font-size: var(--klar-text-sm);
  color: var(--klar-text-muted);
}

.klar-timeline__footer-text--error { color: var(--klar-red-700); }

.klar-timeline__list--skeleton .klar-timeline__time { display: block; padding-top: 5px; }
.klar-timeline__list--skeleton .klar-timeline__content { display: flex; flex-direction: column; gap: 8px; padding-top: 5px; }
.klar-timeline__list--skeleton .klar-timeline__rail { padding-top: 0; }

/* Compact: a dot, one line per event, the time at the right. */

.klar-timeline--compact {
  --_time-w: 0px;
  --_rail-w: 16px;
  gap: 10px;
}

.klar-timeline--compact .klar-timeline__days { gap: 10px; }

.klar-timeline--compact .klar-timeline__day-title { padding-left: 0; }
.klar-timeline--compact .klar-timeline__footer { padding-left: 0; }

.klar-timeline--compact .klar-timeline__item {
  grid-template-columns: var(--_rail-w) minmax(0, 1fr);
  padding-bottom: 4px;
}

.klar-timeline--compact .klar-timeline__item:last-child { padding-bottom: 0; }
.klar-timeline--compact .klar-timeline__item::before { left: calc(var(--_rail-w) / 2); }
.klar-timeline--compact .klar-timeline__item:first-child::before { top: 10px; }
.klar-timeline--compact .klar-timeline__item:last-child::before { height: 10px; }

.klar-timeline--compact .klar-timeline__marker--dot {
  width: 7px;
  height: 7px;
  margin-top: 6.5px;
  box-shadow: 0 0 0 2px var(--klar-surface);
}

.klar-timeline--compact .klar-timeline__content { padding-left: 6px; }

.klar-timeline__line {
  display: flex;
  align-items: center;
  gap: 8px;
  min-height: 20px;
  min-width: 0;
}

.klar-timeline--compact .klar-timeline__title {
  flex: none;
  max-width: 55%;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}

/* The description gives way first (shrink factor 20), then the author's name. */

.klar-timeline--compact .klar-timeline__description {
  flex: 1 20 auto;
  min-width: 0;
  max-width: none;
  margin: 0;
  color: var(--klar-text-muted);
}

.klar-timeline--compact .klar-timeline__time {
  flex: none;
  margin-left: auto;
  padding: 0;
}

.klar-timeline--compact .klar-timeline__details-body { margin-top: 4px; }
.klar-timeline--compact .klar-timeline__details { margin-top: 0; }


/* ==========================================================================
   JSON viewer
   ========================================================================== */

.klar-json {
  min-width: 0;
  background: var(--klar-surface);
  border: 1px solid var(--klar-border);
  border-radius: var(--klar-radius-lg);
  font-family: var(--klar-font-mono);
  font-size: var(--klar-text-sm);
  line-height: 20px;
  color: var(--klar-text);
}

.klar-json--error {
  padding: var(--klar-space-3) var(--klar-space-4);
  color: var(--klar-red-700);
  font-family: var(--klar-font);
}

.klar-json__toolbar {
  display: flex;
  gap: 4px;
  padding: 6px 8px;
  background: var(--klar-surface-subtle);
  border-bottom: 1px solid var(--klar-border);
  border-radius: var(--klar-radius-lg) var(--klar-radius-lg) 0 0;
  font-family: var(--klar-font);
}

.klar-json__scroll {
  overflow: auto;
  padding: 8px 12px 10px;
}

.klar-json__tree,
.klar-json__children {
  margin: 0;
  padding: 0;
  list-style: none;
}

.klar-json__children {
  margin-left: 5px;
  padding-left: 15px;
  border-left: 1px solid var(--klar-border-subtle);
}

/* Every row is about 24px high, so that a toggle is a target of at least 24px (WCAG 2.5.8). */
.klar-json__row {
  display: block;
  padding: 3px 0 3px 17px;
  overflow-wrap: anywhere;
}

.klar-json__node { display: block; }

/* Every row is a treeitem with one tab stop: the ring goes around the row's own
   line, never around a whole open node. */
.klar-json__row:focus-visible,
.klar-json__node:focus-visible { outline: none; }

.klar-json__row:focus-visible,
.klar-json__node:focus-visible > .klar-json__toggle {
  border-radius: var(--klar-radius);
  box-shadow: inset 0 0 0 2px var(--klar-focus-color);
}

.klar-json__toggle {
  display: inline-flex;
  align-items: center;
  gap: 5px;
  max-width: 100%;
  min-height: 24px;
  padding: 0 4px 0 0;
  background: transparent;
  border: 0;
  border-radius: var(--klar-radius);
  color: inherit;
  font: inherit;
  text-align: left;
  cursor: pointer;
}

.klar-json__toggle:hover { background: var(--klar-gray-100); }

.klar-json__text {
  min-width: 0;
  overflow-wrap: anywhere;
}

.klar-json__chevron {
  display: inline-flex;
  flex: none;
  align-self: center;
  width: 12px;
  color: var(--klar-gray-500);
}

.klar-json__chevron .klar-icon { transition: transform var(--klar-dur-fast) var(--klar-ease); }
.klar-json__node--open > .klar-json__toggle .klar-json__chevron .klar-icon { transform: rotate(90deg); }

.klar-json__key { color: var(--klar-blue-800); }
.klar-json__index { color: var(--klar-text-muted); }
.klar-json__string { color: var(--klar-green-700); }
.klar-json__string--cut { cursor: help; }
.klar-json__number { color: var(--klar-blue-600); }
.klar-json__boolean { color: var(--klar-amber-700); }
.klar-json__null { color: var(--klar-text-muted); font-style: italic; }
.klar-json__punct { color: var(--klar-text-muted); }
.klar-json__hint { color: var(--klar-text-muted); white-space: pre-wrap; }

.klar-json__summary {
  margin-left: 8px;
  font-family: var(--klar-font);
  font-size: var(--klar-text-xs);
  color: var(--klar-text-muted);
}

.klar-json__close { padding-left: 17px; }

.klar-json__more {
  padding: 0;
  background: none;
  border: 0;
  font-family: var(--klar-font);
  font-size: var(--klar-text-sm);
  color: var(--klar-text-link);
  cursor: pointer;
}

.klar-json__more:hover { text-decoration: underline; }

@media (forced-colors: active) {
  .klar-json__row:focus-visible,
  .klar-json__node:focus-visible > .klar-json__toggle {
    outline: 2px solid Highlight;
    outline-offset: -2px;
  }
}

/* ==========================================================================
   Tree
   ========================================================================== */

.klar-tree-wrap {
  --_h: 28px;
  display: flex;
  flex-direction: column;
  gap: 8px;
  min-width: 0;
}

.klar-tree--compact,
:where([data-klar-density="compact"]) .klar-tree:where(:not(.klar-tree--compact, .klar-tree--comfortable)) { --_h: 24px; }

.klar-tree__scroll { overflow: auto; }

.klar-tree,
.klar-tree__group {
  margin: 0;
  padding: 0;
  list-style: none;
}

.klar-tree__item {
  list-style: none;
}

.klar-tree__item:focus,
.klar-tree__item:focus-visible { outline: none; }

.klar-tree__row {
  position: relative;
  display: flex;
  align-items: center;
  gap: 6px;
  height: var(--_h);
  padding: 0 8px 0 calc(8px + var(--klar-level, 0) * 16px);
  border-radius: var(--klar-radius);
  color: var(--klar-text);
  cursor: pointer;
  -webkit-user-select: none;
  user-select: none;
}

/* Thin gray guide lines: one per level, drawn in the row's indent so they
   join from row to row. */

.klar-tree__row::before,
.klar-tree__status::before {
  content: "";
  position: absolute;
  top: 0;
  bottom: 0;
  left: 8px;
  width: calc(var(--klar-level, 0) * 16px);
  background-image: repeating-linear-gradient(
    90deg,
    transparent 0,
    transparent 7px,
    var(--klar-border) 7px,
    var(--klar-border) 8px,
    transparent 8px,
    transparent 16px
  );
  pointer-events: none;
}

.klar-tree__row:hover { background: var(--klar-surface-hover); }
.klar-tree__row--selected { background: var(--klar-selection); }
.klar-tree__row--selected:hover { background: var(--klar-primary-subtle-hover); }

.klar-tree__item:focus-visible > .klar-tree__row {
  outline: 2px solid var(--klar-focus-color);
  outline-offset: -2px;
}

.klar-tree__row--disabled {
  color: var(--klar-text-disabled);
  cursor: not-allowed;
}

/* A node that cannot be selected does not light up under the pointer. */
.klar-tree__row--disabled:not(.klar-tree__row--selected):hover { background: transparent; }

.klar-tree__toggle {
  display: inline-flex;
  flex: none;
  align-items: center;
  justify-content: center;
  width: 16px;
  height: 16px;
  padding: 0;
  background: transparent;
  border: 0;
  border-radius: var(--klar-radius-sm);
  color: var(--klar-gray-500);
  cursor: pointer;
}

.klar-tree__toggle:hover { background: var(--klar-gray-150); color: var(--klar-text); }
.klar-tree__toggle .klar-icon { transition: transform var(--klar-dur-fast) var(--klar-ease); }
.klar-tree__item[aria-expanded="true"] > .klar-tree__row .klar-tree__toggle .klar-icon { transform: rotate(90deg); }

.klar-tree__spacer {
  flex: none;
  width: 16px;
}

.klar-tree__check {
  display: inline-flex;
  flex: none;
  align-items: center;
}

.klar-tree__icon {
  display: inline-flex;
  flex: none;
  color: var(--klar-gray-600);
}

.klar-tree__label {
  flex: 1 1 auto;
  min-width: 0;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.klar-tree__hint,
.klar-tree__count {
  flex: none;
  font-size: var(--klar-text-sm);
  color: var(--klar-text-muted);
}

.klar-tree__hint {
  max-width: 40%;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.klar-tree__badge { display: inline-flex; flex: none; }

.klar-tree__status {
  position: relative;
  display: flex;
  align-items: center;
  min-height: var(--_h);
  padding: 0 8px 0 calc(8px + var(--klar-level, 0) * 16px + 22px);
  font-size: var(--klar-text-sm);
  color: var(--klar-text-muted);
  list-style: none;
}

.klar-tree__status-text {
  display: inline-flex;
  align-items: center;
  gap: 8px;
}

.klar-tree__status-text--error { color: var(--klar-red-700); }

.klar-tree__skeleton {
  display: flex;
  flex-direction: column;
  gap: 12px;
  padding: 8px;
}

.klar-tree__skeleton-row { padding-left: calc(var(--klar-level, 0) * 16px + 22px); }


/* ==========================================================================
   Forced colors (Windows high contrast): keep the marks that carry data.
   ========================================================================== */

@media (forced-colors: active) {
  .klar-chart__bar,
  .klar-chart__segment,
  .klar-chart__point,
  .klar-chart__line,
  .klar-chart__area,
  .klar-chart__swatch,
  .klar-chart__gauge-arc,
  .klar-meter__zone,
  .klar-meter__marker,
  .klar-progress__bar,
  .klar-progress__segment,
  .klar-progress-ring__arc,
  .klar-avatar,
  .klar-timeline__marker {
    forced-color-adjust: none;
  }

  .klar-tree__row--selected,
  .klar-list-item--selected {
    outline: 2px solid Highlight;
    outline-offset: -2px;
  }
}
"""
