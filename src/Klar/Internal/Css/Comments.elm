module Klar.Internal.Css.Comments exposing (css)

{-| Comment history, replies and the stable draft composer.
-}


css : String
css =
    """
.klar-comment-thread { min-inline-size: 0; color: var(--klar-text); background: var(--klar-surface); font-size: var(--klar-text-sm); border: 1px solid var(--klar-border); border-radius: var(--klar-radius-lg); }
.klar-comment-thread__history { min-inline-size: 0; }
.klar-comment-thread__count { padding: var(--klar-space-3); color: var(--klar-text-secondary); border-block-end: 1px solid var(--klar-border); }
.klar-comment-thread__list { list-style: none; margin: 0; padding: var(--klar-space-3); }
.klar-comment-thread__row { margin-inline-start: calc(var(--klar-comment-depth, 0) * var(--klar-space-6)); margin-block-end: var(--klar-space-3); }
.klar-comment-thread__row:last-child { margin-block-end: 0; }
.klar-comment-thread__comment { min-inline-size: 0; padding: var(--klar-space-3); border-inline-start: var(--klar-space-1) solid var(--klar-border); overflow-wrap: anywhere; }
.klar-comment-thread__byline { display: flex; flex-wrap: wrap; align-items: center; gap: var(--klar-space-2); margin-block-end: var(--klar-space-2); }
.klar-comment-thread__time { color: var(--klar-text-secondary); font-size: var(--klar-text-xs); font-variant-numeric: tabular-nums; }
.klar-comment-thread__notice { color: var(--klar-text-secondary); margin: var(--klar-space-2) 0; }
.klar-comment-thread__removed { color: var(--klar-text-secondary); font-style: italic; }
.klar-comment-thread__actions { display: flex; flex-wrap: wrap; align-items: center; gap: var(--klar-space-2); }
.klar-comment-thread__actions:empty { display: none; }
.klar-comment-thread__composer { min-inline-size: 0; display: grid; gap: var(--klar-space-3); padding: var(--klar-space-4); border-block-start: 1px solid var(--klar-border); background: var(--klar-surface-subtle); }
.klar-comment-thread__target, .klar-comment-thread__footer { display: flex; flex-wrap: wrap; align-items: center; justify-content: space-between; gap: var(--klar-space-2); }
.klar-comment-thread__preview { min-block-size: calc(var(--klar-space-12) * 2); padding: var(--klar-space-3); border: 1px solid var(--klar-border); border-radius: var(--klar-radius); background: var(--klar-surface); overflow-wrap: anywhere; }
.klar-comment-thread__preview[hidden] { display: none; }
.klar-comment-thread__error { padding: var(--klar-space-3); color: var(--klar-red-700); background: var(--klar-red-50); border-inline-start: var(--klar-space-1) solid var(--klar-red-700); }
@media (max-width: 640px) { .klar-comment-thread__row { margin-inline-start: calc(var(--klar-comment-depth, 0) * var(--klar-space-2)); } }
"""
