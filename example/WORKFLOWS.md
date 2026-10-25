# Process studio

Run `npm start` and open `http://localhost:8000/#/applications/process-studio`.
This is an Elm application with an in-memory server simulator. It makes no real
AI calls, memberships, publications or uploads. Reload resets the simulator;
**Save definition** and **Import JSON** preserve designs explicitly.

For component contracts, use the generated references for
[Workflow](../ai/modules/Klar.Workflow.md),
[WorkflowBuilder](../ai/modules/Klar.WorkflowBuilder.md),
[Workflow.Engine](../ai/modules/Klar.Workflow.Engine.md),
[WorkflowRun](../ai/modules/Klar.WorkflowRun.md) and
[StateMachine](../ai/modules/Klar.StateMachine.md).

## Try the studio

1. Choose a template, select a node and edit its instructions, JSON state, bindings
   and assigned role. Adding after a selected node rewires a single forward edge;
   branches remain explicit. Invalid connections are reported for correction.
2. Start a run with a brief. An optional image contributes a local preview reference
   and metadata, not uploaded bytes. Character outputs are deterministic SVG
   placeholders, not images inferred from the reference.
3. Complete human tasks/reviews and choose branch decisions. The document template
   asks a person for its confidence route; a real server would evaluate that policy.
4. Inject a worker failure and retry. Inspect earlier attempts and feedback; pause,
   resume, cancel and switch runs. Leaving an application route pauses its process
   and invalidates pending page replies.
5. Edit the draft during a run: the active run keeps its frozen definition.
   Use **Export results** for full outputs; large inline payloads are shortened
   only in the inspector.

The state-machine component page separately lets you create states, connect events
and exercise a step lifecycle.

## Membership scenario

The membership template passes an application through coordinator, interviewer,
coordinator recommendation, managing-director approval and registrar enrollment.
Decline finishes separately without an enrollment binding. Switch **Demo session**
to exercise the role gates; **Apply designer role** explicitly changes draft ownership.
The starter or `workflow-admin` can pause/cancel/retry.

This selector is not authentication. The simulator checks the captured actor and
expected revision when a decision arrives; changing sessions cannot change an
already submitted request's actor. Real services must resolve verified identities
and authorize against stored definitions, roles and tenant ownership. The studio
assigns one role per checkpoint; it does not implement approval quorum voting.

## Replace the simulator

[Api/Workflows.elm](src/Api/Workflows.elm) delays requests and sends them to
[Backend/WorkflowServer.elm](src/Backend/WorkflowServer.elm). That boundary owns
run snapshots, ids, revisions, role checks and worker-completion events. The page
shows acknowledged replies and keeps notes after a failed write.

In a real app, replace this boundary with ordinary HTTP calls to its Go server,
persist definitions/runs/attempts in SQLite, and execute AI work and timers there.
Treat worker completion as a server-owned event, not an endpoint where users may
claim arbitrary completion. Keep reply correlation, permissions and revision
checks at the server boundary. Provider credentials and file transfer remain
application responsibilities; Klar only draws the acknowledged state.
