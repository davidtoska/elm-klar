module Klar.Internal.Css.Workbench exposing (css)

{-| Cards, queues, notifications, audit trails and conflict review.
-}


css : String
css =
    """
.klar-card-list,
.klar-work-queue,
.klar-audit-log,
.klar-notification-center,
.klar-conflict-resolver {
  min-inline-size: 0;
  color: var(--klar-text);
  background: var(--klar-surface);
  font-size: var(--klar-text-sm);
}
.klar-work-queue,
.klar-audit-log,
.klar-notification-center,
.klar-conflict-resolver {
  border: 1px solid var(--klar-border);
  border-radius: var(--klar-radius-lg);
}
.klar-workbench__bar {
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  justify-content: space-between;
  gap: var(--klar-space-3);
  padding: var(--klar-space-3);
  border-block-end: 1px solid var(--klar-border);
  background: var(--klar-surface-subtle);
}
.klar-workbench__bar > .klar-field { flex: 1 1 16rem; }
.klar-workbench__actions,
.klar-workbench__check,
.klar-workbench__meta {
  display: flex;
  align-items: center;
  flex-wrap: wrap;
  gap: var(--klar-space-2);
}
.klar-workbench__actions:empty { display: none; }
.klar-workbench__check { cursor: pointer; }
.klar-workbench__check input,
.klar-conflict-resolver__choice input { accent-color: var(--klar-primary); }
.klar-workbench__title-button {
  appearance: none;
  border: 0;
  border-radius: var(--klar-radius-sm);
  padding: 0;
  background: transparent;
  color: var(--klar-text-link);
  font: inherit;
  font-weight: var(--klar-weight-bold);
  text-align: start;
  cursor: pointer;
  overflow-wrap: anywhere;
}
.klar-workbench__title-button:hover { text-decoration: underline; }
.klar-workbench__prose { margin: var(--klar-space-2) 0; white-space: pre-wrap; overflow-wrap: anywhere; }
.klar-workbench__meta { color: var(--klar-text-secondary); font-size: var(--klar-text-xs); font-variant-numeric: tabular-nums; }
.klar-workbench__more { padding: var(--klar-space-3); display: flex; justify-content: center; }
.klar-card-list__grid {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(min(100%, 16rem), 1fr));
  gap: var(--klar-space-3);
  list-style: none;
  padding: var(--klar-space-3) 0;
  margin: 0;
}
.klar-card-list__card {
  min-inline-size: 0;
  display: flex;
  flex-direction: column;
  gap: var(--klar-space-3);
  padding: var(--klar-space-4);
  border: 1px solid var(--klar-border);
  border-radius: var(--klar-radius-lg);
  background: var(--klar-surface);
}
.klar-card-list__card--selected { border-color: var(--klar-primary); background: var(--klar-primary-subtle); }
.klar-card-list__head { display: flex; align-items: baseline; gap: var(--klar-space-2); overflow-wrap: anywhere; }
.klar-card-list__fields { display: grid; grid-template-columns: minmax(0, 1fr) minmax(0, 2fr); gap: var(--klar-space-2) var(--klar-space-3); margin: 0; }
.klar-card-list__fields dt { color: var(--klar-text-secondary); }
.klar-card-list__fields dd { margin: 0; overflow-wrap: anywhere; }
.klar-card-list__card > .klar-workbench__actions { margin-block-start: auto; }
.klar-work-queue__panes { display: grid; grid-template-columns: minmax(12rem, 1fr) minmax(0, 2fr); }
.klar-work-queue__list-pane { min-inline-size: 0; border-inline-end: 1px solid var(--klar-border); }
.klar-work-queue__list { list-style: none; margin: 0; padding: 0; }
.klar-work-queue__item {
  display: flex;
  flex-direction: column;
  gap: var(--klar-space-1);
  inline-size: 100%;
  padding: var(--klar-space-3);
  border: 0;
  border-block-end: 1px solid var(--klar-border-subtle);
  border-inline-start: var(--klar-space-1) solid transparent;
  background: transparent;
  color: var(--klar-text);
  font: inherit;
  text-align: start;
  cursor: pointer;
  overflow-wrap: anywhere;
}
.klar-work-queue__item:hover { background: var(--klar-surface-hover); }
.klar-work-queue__item--selected { background: var(--klar-primary-subtle); border-inline-start-color: var(--klar-primary); }
.klar-work-queue__summary { color: var(--klar-text-secondary); }
.klar-work-queue__help { margin: 0; padding: var(--klar-space-3); color: var(--klar-text-secondary); font-size: var(--klar-text-xs); }
.klar-work-queue__detail { min-inline-size: 0; padding: var(--klar-space-4); overflow-wrap: anywhere; }
.klar-audit-log__list { list-style: none; padding: var(--klar-space-4); margin: 0; }
.klar-audit-log__entry { display: flex; gap: var(--klar-space-3); }
.klar-audit-log__rail { position: relative; flex: 0 0 var(--klar-space-3); border-inline-start: 1px solid var(--klar-border-strong); margin-inline-start: var(--klar-space-1); }
.klar-audit-log__rail::before { content: ""; position: absolute; inset-inline-start: calc(var(--klar-space-1) * -1); inset-block-start: var(--klar-space-1); inline-size: var(--klar-space-2); block-size: var(--klar-space-2); border-radius: var(--klar-radius-full); background: var(--klar-primary); }
.klar-audit-log__entry:last-child .klar-audit-log__rail { border-color: transparent; }
.klar-audit-log__body { flex: 1; min-inline-size: 0; padding-block-end: var(--klar-space-5); overflow-wrap: anywhere; }
.klar-audit-log__entry:last-child .klar-audit-log__body { padding-block-end: 0; }
.klar-audit-log__head { display: flex; flex-wrap: wrap; justify-content: space-between; align-items: baseline; gap: var(--klar-space-2); }
.klar-audit-log__diff { margin-block-start: var(--klar-space-2); }
.klar-audit-log__diff > summary { cursor: pointer; color: var(--klar-text-link); padding-block: var(--klar-space-1); }
.klar-notification-center__list { list-style: none; margin: 0; padding: 0; }
.klar-notification-center__item { display: flex; align-items: start; justify-content: space-between; flex-wrap: wrap; gap: var(--klar-space-3); padding: var(--klar-space-4); border-block-end: 1px solid var(--klar-border-subtle); border-inline-start: var(--klar-space-1) solid transparent; }
.klar-notification-center__item--unread { border-inline-start-color: var(--klar-primary); background: var(--klar-primary-subtle); }
.klar-notification-center__content { min-inline-size: 0; flex: 1 1 14rem; overflow-wrap: anywhere; }
.klar-conflict-resolver__fields { padding: var(--klar-space-3); display: grid; gap: var(--klar-space-4); }
.klar-conflict-resolver__field { min-inline-size: 0; margin: 0; padding: var(--klar-space-3); border: 1px solid var(--klar-border); border-radius: var(--klar-radius); }
.klar-conflict-resolver__field legend { padding-inline: var(--klar-space-2); font-weight: var(--klar-weight-bold); }
.klar-conflict-resolver__versions { display: grid; grid-template-columns: repeat(3, minmax(0, 1fr)); gap: var(--klar-space-3); }
.klar-conflict-resolver__base,
.klar-conflict-resolver__choice { min-inline-size: 0; display: flex; flex-direction: column; gap: var(--klar-space-2); padding: var(--klar-space-3); border: 1px solid var(--klar-border); border-radius: var(--klar-radius); background: var(--klar-surface-subtle); }
.klar-conflict-resolver__choice { cursor: pointer; background: var(--klar-surface); }
.klar-conflict-resolver__choice:hover { border-color: var(--klar-border-strong); }
.klar-conflict-resolver__choice--selected { border-color: var(--klar-primary); background: var(--klar-primary-subtle); }
.klar-conflict-resolver__value { white-space: pre-wrap; overflow-wrap: anywhere; font-family: var(--klar-font-mono); font-size: var(--klar-text-sm); }
.klar-conflict-resolver__value em { color: var(--klar-text-secondary); font-family: var(--klar-font); }
.klar-conflict-resolver__result { display: flex; flex-direction: column; gap: var(--klar-space-2); margin-block-start: var(--klar-space-3); padding: var(--klar-space-3); background: var(--klar-surface-subtle); border-inline-start: var(--klar-space-1) solid var(--klar-primary); }
.klar-conflict-resolver__pending { margin: var(--klar-space-3) 0 0; color: var(--klar-text-secondary); }
@media (max-width: 640px) {
  .klar-work-queue__panes { grid-template-columns: minmax(0, 1fr); }
  .klar-work-queue__list-pane { border-inline-end: 0; border-block-end: 1px solid var(--klar-border); }
  .klar-conflict-resolver__versions { grid-template-columns: minmax(0, 1fr); }
}
"""
