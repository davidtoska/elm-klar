module Klar.Internal.Css.Ai exposing (css)

{-| AI evidence review and conversation surfaces.
-}


css : String
css =
    """
.klar-ai-review, .klar-ai-chat { min-inline-size: 0; color: var(--klar-text); font-size: var(--klar-text-sm); }
.klar-ai-review__proposal, .klar-ai-chat__message { min-inline-size: 0; padding: var(--klar-space-4); margin-block-end: var(--klar-space-4); border: 1px solid var(--klar-border); border-radius: var(--klar-radius-lg); background: var(--klar-surface); overflow-wrap: anywhere; }
.klar-ai-review h3, .klar-ai-chat h3 { margin-block: 0 var(--klar-space-2); font-size: var(--klar-text-md); }
.klar-ai-review h4 { margin-block: var(--klar-space-4) var(--klar-space-2); font-size: var(--klar-text-sm); }
.klar-ai__meta { color: var(--klar-text-secondary); font-size: var(--klar-text-xs); }
.klar-ai-review__comparison { display: grid; grid-template-columns: repeat(2, minmax(0, 1fr)); gap: var(--klar-space-3); }
.klar-ai-review__value { min-inline-size: 0; padding: var(--klar-space-3); border: 1px solid var(--klar-border); background: var(--klar-surface-subtle); border-radius: var(--klar-radius); }
.klar-ai-review__value pre, .klar-ai-review__rationale, .klar-ai-review blockquote { white-space: pre-wrap; overflow-wrap: anywhere; font: inherit; }
.klar-ai-review blockquote { margin: var(--klar-space-2) 0 var(--klar-space-3); padding-inline-start: var(--klar-space-3); border-inline-start: var(--klar-space-1) solid var(--klar-border); color: var(--klar-text-secondary); }
.klar-ai-review__decision { margin-block: var(--klar-space-4); padding: var(--klar-space-3); border: 1px solid var(--klar-border); border-radius: var(--klar-radius); }
.klar-ai-review__decision > label { display: inline-flex; align-items: center; gap: var(--klar-space-2); margin-inline-end: var(--klar-space-4); margin-block-end: var(--klar-space-3); }
.klar-ai__status, .klar-ai__actions { padding-block: var(--klar-space-2); }
.klar-ai__actions { display: flex; flex-wrap: wrap; gap: var(--klar-space-2); }
.klar-ai-chat__message--assistant { background: var(--klar-surface-subtle); border-inline-start: var(--klar-space-1) solid var(--klar-primary); }
.klar-ai-chat__composer { padding: var(--klar-space-4); border: 1px solid var(--klar-border); border-radius: var(--klar-radius-lg); background: var(--klar-surface); }
@media (max-width: 640px) { .klar-ai-review__comparison { grid-template-columns: minmax(0, 1fr); } }
"""
