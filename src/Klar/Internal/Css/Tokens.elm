module Klar.Internal.Css.Tokens exposing (css)

{-| The rules of `tokens`, part of the stylesheet of the package. Edit the CSS here;
`Klar.Internal.Css` puts the parts together in order.
-}


css : String
css =
    """
/* ==========================================================================
   Klar design tokens
   Gray / white / blue. Calm, dense, precise. Thin 1px lines, small radii.
   Components must use these tokens - never hard-coded colors or sizes.
   ========================================================================== */

:root {
  /* ---- Neutral scale (cool gray) ---- */
  --klar-white: #ffffff;
  --klar-gray-25: #fafbfc;
  --klar-gray-50: #f5f7f9;
  --klar-gray-100: #edf0f4;
  --klar-gray-150: #e4e8ee;
  --klar-gray-200: #d9dfe6;
  --klar-gray-300: #c6ced8;
  --klar-gray-400: #9ea9b7;
  --klar-gray-500: #7a8696;
  --klar-gray-600: #5d6978;
  --klar-gray-700: #455060;
  --klar-gray-800: #2e3744;
  --klar-gray-900: #1b222c;

  /* ---- Blue scale (primary) ---- */
  --klar-blue-50: #eff5fc;
  --klar-blue-100: #dde9f7;
  --klar-blue-200: #bfd5ef;
  --klar-blue-300: #94b9e3;
  --klar-blue-400: #5f95d3;
  --klar-blue-500: #2f74bf;
  --klar-blue-600: #1560b0;
  --klar-blue-700: #0f4f93;
  --klar-blue-800: #0c3d73;
  --klar-blue-900: #082a50;

  /* ---- Status colors (muted) ---- */
  --klar-green-50: #ecf7f1;
  --klar-green-100: #d3eddf;
  --klar-green-500: #2a9461;
  --klar-green-600: #1e7d50;
  --klar-green-700: #17653f;

  --klar-amber-50: #fff7e6;
  --klar-amber-100: #ffecc2;
  --klar-amber-500: #d98a0b;
  /* The warning color is text too (a warning note, a solid badge with white text): 5.2:1
     on white and 4.9:1 on amber-50, where the brighter #b87208 was 3.9:1 and failed AA. */
  --klar-amber-600: #9a5f06;
  --klar-amber-700: #8f5806;

  --klar-red-50: #fdf0ee;
  --klar-red-100: #fadad6;
  --klar-red-500: #d6453a;
  --klar-red-600: #bd352b;
  --klar-red-700: #962a22;

  /* ---- Semantic colors ---- */
  --klar-bg: var(--klar-gray-50);
  --klar-surface: var(--klar-white);
  --klar-surface-subtle: var(--klar-gray-25);
  --klar-surface-sunken: var(--klar-gray-100);
  --klar-surface-hover: var(--klar-gray-50);
  --klar-surface-active: var(--klar-gray-100);

  --klar-border: var(--klar-gray-200);
  --klar-border-strong: var(--klar-gray-300);
  --klar-border-subtle: var(--klar-gray-150);

  --klar-text: var(--klar-gray-900);
  /* Both pass WCAG AA (4.5:1) on every surface of the library, the gray page background
     and the sunken gray included. Disabled text is exempt and lighter. */
  --klar-text-secondary: var(--klar-gray-700);
  --klar-text-muted: var(--klar-gray-600);
  --klar-text-disabled: var(--klar-gray-400);
  --klar-text-link: var(--klar-blue-600);

  /* Code blocks are dark in every theme, light mode included. */
  --klar-code-bg: var(--klar-gray-900);
  --klar-code-text: var(--klar-gray-100);

  --klar-primary: var(--klar-blue-600);
  --klar-primary-hover: var(--klar-blue-700);
  --klar-primary-active: var(--klar-blue-800);
  --klar-primary-subtle: var(--klar-blue-50);
  --klar-primary-subtle-hover: var(--klar-blue-100);
  --klar-primary-border: var(--klar-blue-200);
  --klar-on-primary: var(--klar-white);
  --klar-on-solid: var(--klar-white);

  --klar-success: var(--klar-green-600);
  --klar-success-subtle: var(--klar-green-50);
  --klar-success-border: var(--klar-green-100);
  --klar-warning: var(--klar-amber-600);
  --klar-warning-subtle: var(--klar-amber-50);
  --klar-warning-border: var(--klar-amber-100);
  --klar-danger: var(--klar-red-600);
  --klar-danger-hover: var(--klar-red-700);
  --klar-danger-subtle: var(--klar-red-50);
  --klar-danger-border: var(--klar-red-100);
  --klar-info: var(--klar-blue-600);
  --klar-info-subtle: var(--klar-blue-50);
  --klar-info-border: var(--klar-blue-200);

  --klar-overlay: rgba(27, 34, 44, 0.45);
  --klar-tint-hover: rgba(16, 24, 40, 0.08);
  --klar-tint-border: rgba(16, 24, 40, 0.1);
  --klar-selection: var(--klar-blue-100);
  --klar-highlight: #fff3c4;

  /* ---- Typography ---- */
  --klar-font: "Segoe UI", system-ui, -apple-system, "Helvetica Neue", Roboto, Arial, sans-serif;
  --klar-font-mono: "Cascadia Mono", "SF Mono", ui-monospace, Consolas, "Liberation Mono", monospace;
  --klar-text-xs: 11px;
  --klar-text-sm: 12px;
  --klar-text-md: 13px;
  --klar-text-lg: 14px;
  --klar-text-xl: 16px;
  --klar-text-2xl: 20px;
  --klar-text-3xl: 24px;
  --klar-leading: 1.45;
  --klar-leading-tight: 1.25;
  --klar-weight: 400;
  --klar-weight-medium: 500;
  --klar-weight-bold: 600;

  /* ---- Spacing (4px grid) ---- */
  --klar-space-1: 4px;
  --klar-space-2: 8px;
  --klar-space-3: 12px;
  --klar-space-4: 16px;
  --klar-space-5: 20px;
  --klar-space-6: 24px;
  --klar-space-8: 32px;
  --klar-space-10: 40px;
  --klar-space-12: 48px;

  /* ---- Shape ---- */
  --klar-radius-sm: 2px;
  --klar-radius: 3px;
  --klar-radius-lg: 5px;
  --klar-radius-full: 999px;

  /* ---- Controls ---- */
  --klar-control-sm: 26px;
  --klar-control: 32px;
  --klar-control-lg: 40px;
  --klar-control-px: 10px;
  /* The row of a list in a popup. Elm computes the scroll position of a row from 32px
     (Select.Popup.rowHeight, VirtualList), so it is the same at every density. */
  --klar-option-h: 32px;

  /* ---- Table rows ---- */
  --klar-row-compact: 28px;
  --klar-row: 36px;
  --klar-row-comfortable: 46px;

  /* ---- Elevation ---- */
  --klar-shadow-xs: 0 1px 1px rgba(16, 24, 40, 0.04);
  --klar-shadow-sm: 0 1px 2px rgba(16, 24, 40, 0.06), 0 1px 1px rgba(16, 24, 40, 0.04);
  --klar-shadow-md: 0 4px 12px rgba(16, 24, 40, 0.1), 0 1px 3px rgba(16, 24, 40, 0.06);
  --klar-shadow-lg: 0 12px 32px rgba(16, 24, 40, 0.16), 0 2px 6px rgba(16, 24, 40, 0.08);

  /* ---- Focus ---- */
  --klar-focus-color: var(--klar-blue-500);
  --klar-focus-ring: 0 0 0 3px rgba(47, 116, 191, 0.25);
  --klar-focus-ring-danger: 0 0 0 3px rgba(189, 53, 43, 0.2);

  /* ---- Motion ---- */
  --klar-ease: cubic-bezier(0.2, 0, 0, 1);
  --klar-dur-fast: 90ms;
  --klar-dur: 150ms;
  --klar-dur-slow: 240ms;

  /* ---- Layering ---- */
  --klar-z-sticky: 10;
  --klar-z-header: 40;
  --klar-z-layer: 900;
  --klar-z-popup: 910;
  --klar-z-drawer: 1000;
  --klar-z-modal: 1100;
  --klar-z-toast: 1200;
  --klar-z-tooltip: 1300;
  --klar-z-palette: 1400;

  /* ---- Layout ---- */
  --klar-header-h: 48px;
  --klar-sidebar-w: 232px;
  --klar-sidebar-w-collapsed: 52px;
  --klar-page-max: 1440px;

  color-scheme: light;
}

/* Every transition and every entrance runs on these durations, so under reduced
   motion they end at once. What has a duration of its own is in the list of Base. */
@media (prefers-reduced-motion: reduce) {
  :root {
    --klar-dur-fast: 0ms;
    --klar-dur: 0ms;
    --klar-dur-slow: 0ms;
  }
}
"""
