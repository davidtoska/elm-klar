module Klar.Internal.Css.Uploads exposing (css)

{-| File staging and controlled transfer-queue presentation.
-}


css : String
css =
    """
.klar-upload-queue { min-inline-size: 0; color: var(--klar-text); font-size: var(--klar-text-sm); }
.klar-upload-queue__staging-actions,
.klar-upload-queue__bar,
.klar-upload-queue__actions { display: flex; flex-wrap: wrap; align-items: center; gap: var(--klar-space-2); }
.klar-upload-queue__staging-actions { margin-block: var(--klar-space-3) var(--klar-space-4); }
.klar-upload-queue__bar { justify-content: space-between; background: var(--klar-surface-subtle); padding: var(--klar-space-3); border: 1px solid var(--klar-border); border-radius: var(--klar-radius-lg) var(--klar-radius-lg) 0 0; }
.klar-upload-queue__list { list-style: none; padding: 0; margin: 0; border: 1px solid var(--klar-border); border-block-start: 0; border-radius: 0 0 var(--klar-radius-lg) var(--klar-radius-lg); }
.klar-upload-queue__item { display: grid; grid-template-columns: minmax(0, 1fr) minmax(0, 1fr) auto; align-items: center; gap: var(--klar-space-4); padding: var(--klar-space-3); background: var(--klar-surface); border-block-end: 1px solid var(--klar-border-subtle); }
.klar-upload-queue__item:last-child { border-block-end: 0; }
.klar-upload-queue__file { min-inline-size: 0; display: flex; align-items: center; gap: var(--klar-space-2); }
.klar-upload-queue__description,
.klar-upload-queue__transfer,
.klar-upload-queue__status { min-inline-size: 0; display: flex; flex-direction: column; gap: var(--klar-space-1); }
.klar-upload-queue__name { overflow-wrap: anywhere; }
.klar-upload-queue__meta { color: var(--klar-text-secondary); font-size: var(--klar-text-xs); overflow-wrap: anywhere; font-variant-numeric: tabular-nums; }
.klar-upload-queue__status { overflow-wrap: anywhere; }
.klar-upload-queue__status--complete { flex-direction: row; align-items: center; color: var(--klar-green-700); }
.klar-upload-queue__status--failed { color: var(--klar-red-700); }
.klar-upload-queue__invalid { margin: 0; padding: var(--klar-space-3); color: var(--klar-red-700); background: var(--klar-surface-subtle); border: 1px solid var(--klar-border); }
.klar-upload-queue__progress { display: block; inline-size: 100%; min-inline-size: 0; block-size: var(--klar-space-2); accent-color: var(--klar-primary); border: 0; border-radius: var(--klar-radius-full); overflow: hidden; background: var(--klar-surface-sunken); }
.klar-upload-queue__progress::-webkit-progress-bar { background: var(--klar-surface-sunken); }
.klar-upload-queue__progress::-webkit-progress-value { background: var(--klar-primary); }
.klar-upload-queue__progress::-moz-progress-bar { background: var(--klar-primary); }
.klar-upload-queue__empty { margin: 0; padding: var(--klar-space-6); text-align: center; color: var(--klar-text-secondary); border: 1px solid var(--klar-border); border-block-start: 0; border-radius: 0 0 var(--klar-radius-lg) var(--klar-radius-lg); }
@media (max-width: 640px) {
  .klar-upload-queue__item { grid-template-columns: minmax(0, 1fr); gap: var(--klar-space-3); }
}
"""
