module Klar.Internal.Css.Workflow exposing (css)

{-| Workflow diagrams and inspectors, using the Klar theme and spacing tokens.
-}


css : String
css =
    """
.klar-workflow-node { display:flex; align-items:center; gap:var(--klar-space-3); width:100%; min-width:0; text-align:left; color:var(--klar-text); background:var(--klar-surface); border:1px solid var(--klar-border); border-radius:var(--klar-radius); padding:var(--klar-space-3); font:inherit; }
button.klar-workflow-node { cursor:pointer; }
button.klar-workflow-node:hover { border-color:var(--klar-primary); background:var(--klar-surface-hover); }
button.klar-workflow-node:focus-visible { outline:2px solid var(--klar-primary); outline-offset:2px; }
.klar-workflow-node--selected { border-color:var(--klar-primary); box-shadow:0 0 0 1px var(--klar-primary-border); }
.klar-workflow-node__icon { display:flex; align-items:center; justify-content:center; padding:var(--klar-space-2); color:var(--klar-primary); background:var(--klar-primary-subtle); border-radius:var(--klar-radius); }
.klar-workflow-node[data-kind="human"] .klar-workflow-node__icon { color:var(--klar-warning); background:var(--klar-warning-subtle); }
.klar-workflow-node[data-kind="output"] .klar-workflow-node__icon { color:var(--klar-success); background:var(--klar-success-subtle); }
.klar-workflow-node__body { display:flex; flex:1; min-width:0; flex-direction:column; gap:var(--klar-space-1); overflow-wrap:anywhere; }
.klar-workflow-node__kind,.klar-workflow-node__ports,.klar-workflow-node__detail { color:var(--klar-text-muted); font-size:var(--klar-text-xs); }
.klar-workflow-node__kind { text-transform:uppercase; letter-spacing:.06em; }
.klar-workflow-node__status { font-size:var(--klar-text-xs); color:var(--klar-text-secondary); }
.klar-workflow-builder { display:grid; grid-template-columns:minmax(0,1fr); gap:var(--klar-space-4); }
.klar-workflow-builder h3,.klar-workflow-builder h4,.klar-workflow-run h3 { margin:0 0 var(--klar-space-3); font-size:var(--klar-text-sm); }
.klar-workflow-builder__palette,.klar-workflow-builder__inspector,.klar-workflow-builder__canvas { background:var(--klar-surface); border:1px solid var(--klar-border); border-radius:var(--klar-radius); padding:var(--klar-space-4); min-width:0; }
.klar-workflow-builder__palette p { color:var(--klar-text-muted); line-height:var(--klar-leading); }
.klar-workflow-builder__kinds { display:flex; flex-wrap:wrap; gap:var(--klar-space-2); }
.klar-workflow-builder__canvas { background:var(--klar-surface-subtle); }
.klar-workflow-builder__caption { color:var(--klar-text-muted); font-size:var(--klar-text-xs); margin-bottom:var(--klar-space-2); letter-spacing:.08em; }
.klar-workflow-builder__steps,.klar-workflow-run__steps { margin:0; padding:0; list-style:none; }
.klar-workflow-builder__steps { display:grid; grid-template-columns:var(--klar-space-5) minmax(0,1fr); }
.klar-workflow-builder__return-rail { position:relative; grid-column:1; grid-row:var(--klar-workflow-row)/var(--klar-workflow-end); pointer-events:none; border:1px solid var(--klar-warning); border-right:0; border-radius:var(--klar-radius-lg) 0 0 var(--klar-radius-lg); margin-top:var(--klar-space-6); margin-bottom:var(--klar-space-10); }
.klar-workflow-builder__return-rail::before { content:"→"; position:absolute; right:0; top:calc(-1 * var(--klar-space-2)); color:var(--klar-warning); }
.klar-workflow-builder__step { grid-column:2; grid-row:var(--klar-workflow-row); position:relative; padding-left:var(--klar-space-3); border-left:1px solid var(--klar-border-strong); }
.klar-workflow-builder__edges { display:flex; flex-wrap:wrap; gap:var(--klar-space-2); padding:var(--klar-space-2) 0; }
.klar-workflow-builder__edge { display:flex; align-items:center; gap:var(--klar-space-1); color:var(--klar-text-muted); min-width:0; max-width:100%; flex-wrap:wrap; }
.klar-workflow-builder__edge--return { border-left:2px solid var(--klar-warning); border-radius:var(--klar-radius); padding-left:var(--klar-space-2); color:var(--klar-warning); }
.klar-workflow-builder__edge small { white-space:nowrap; }
.klar-workflow-builder__inspector { display:flex; flex-direction:column; gap:var(--klar-space-3); align-self:start; }
.klar-workflow-builder__reorder { display:flex; gap:var(--klar-space-2); flex-wrap:wrap; }
.klar-workflow-builder__transitions { display:flex; flex-direction:column; gap:var(--klar-space-3); }
.klar-workflow-builder__connection { padding:var(--klar-space-3); border:1px solid var(--klar-border-subtle); border-radius:var(--klar-radius); display:flex; flex-direction:column; gap:var(--klar-space-2); }
.klar-workflow-builder__field { display:flex; flex-direction:column; gap:var(--klar-space-1); font-size:var(--klar-text-xs); }
.klar-workflow-builder__field select { color:var(--klar-text); background:var(--klar-surface); border:1px solid var(--klar-border); padding:var(--klar-space-2); border-radius:var(--klar-radius); width:100%; }
.klar-workflow-builder__validation { grid-column:1/-1; color:var(--klar-danger); font-size:var(--klar-text-sm); }
.klar-workflow-builder__validation ul:empty { display:none; }
.klar-workflow-run { border:1px solid var(--klar-border); border-radius:var(--klar-radius); background:var(--klar-surface); min-width:0; }
.klar-workflow-run__header { display:flex; flex-wrap:wrap; justify-content:space-between; gap:var(--klar-space-2); padding:var(--klar-space-4); border-bottom:1px solid var(--klar-border); }
.klar-workflow-run__header span { color:var(--klar-primary); font-size:var(--klar-text-xs); }
.klar-workflow-run__layout { display:grid; grid-template-columns:minmax(0,1fr); }
.klar-workflow-run__steps { padding:var(--klar-space-4); background:var(--klar-surface-subtle); }
.klar-workflow-run__step { padding-left:var(--klar-space-3); border-left:2px solid var(--klar-border); }
.klar-workflow-run__step--active { border-left-color:var(--klar-primary); }
.klar-workflow-run__routes { display:flex; flex-direction:column; gap:var(--klar-space-1); padding:var(--klar-space-2); color:var(--klar-text-muted); font-size:var(--klar-text-xs); overflow-wrap:anywhere; }
.klar-workflow-run__inspector { min-width:0; padding:var(--klar-space-4); border-top:1px solid var(--klar-border); }
.klar-workflow-run__json { overflow:auto; max-height:24em; background:var(--klar-surface-subtle); border:1px solid var(--klar-border-subtle); border-radius:var(--klar-radius); padding:var(--klar-space-3); font-size:var(--klar-text-xs); }
.klar-state-machine { padding:var(--klar-space-3); border:1px solid var(--klar-border); border-radius:var(--klar-radius); }
.klar-state-machine > p { color:var(--klar-primary); font-size:var(--klar-text-sm); }
.klar-state-machine__states { padding:0; margin:0; list-style:none; display:flex; flex-wrap:wrap; gap:var(--klar-space-3); }
.klar-state-machine__state { flex:1 1 10em; padding:var(--klar-space-3); border:1px solid var(--klar-border); border-radius:var(--klar-radius); display:flex; flex-direction:column; gap:var(--klar-space-2); min-width:0; }
.klar-state-machine__state--current { border-color:var(--klar-primary); background:var(--klar-primary-subtle); }
.klar-state-machine__state small { color:var(--klar-text-muted); }
.klar-state-machine__events { display:flex; flex-direction:column; align-items:flex-start; }
@media (min-width:760px) { .klar-workflow-builder { grid-template-columns:minmax(0,1.4fr) minmax(0,1fr); } .klar-workflow-builder__palette { grid-column:1/-1; } }
@media (min-width:1100px) { .klar-workflow-builder__palette { grid-column:auto; } .klar-workflow-builder { grid-template-columns:minmax(9em,.65fr) minmax(15em,1.8fr) minmax(15em,1.1fr); } .klar-workflow-builder__kinds { flex-direction:column; align-items:stretch; } }
@media (min-width:760px) { .klar-workflow-run__layout { grid-template-columns:minmax(0,1.2fr) minmax(0,1fr); } .klar-workflow-run__inspector { border-top:0; border-left:1px solid var(--klar-border); } }
"""
