# Processes and state

Open `http://localhost:8000/#/applications/process-studio` after `npm start`.
The studio is an Elm example application, using public Klar components and an
in-memory Elm server simulator. It makes no external AI calls and creates no real
memberships, publications or uploads. Reloading the browser resets the simulator;
use **Save definition** and **Import JSON** to keep and exchange designs.

## The components

| Module | Responsibility |
| --- | --- |
| `Klar.Workflow` | Ordered nodes, explicit edges, kind vocabulary and validation |
| `Klar.WorkflowBuilder` | Vertical diagram, palette, inspector, connections and reordering |
| `Klar.WorkflowNode` | Selectable node with kind, role, bindings and status |
| `Klar.Workflow.Engine` | Pure execution transitions and immutable run snapshots |
| `Klar.WorkflowRun` | Live diagram, per-node state, output, context and attempts; remote states |
| `Klar.Workflow.Codec` | Version 1 definition JSON using the application's `Ids` |
| `Klar.StateMachine` | A smaller event-driven state graph and enabled transitions |

Each module has its own address in the component gallery, for example
`#/components/workflow-builder`, `#/components/workflow-run` and
`#/components/state-machine`. The group overview is `#/components/processes`.

This is a deliberately small workflow vocabulary rather than a BPMN importer:
human input, AI task, human task, human review, branch, wait and output. The node
list is the diagram's vertical order. Edges are explicit, so skipping a review or
branching to a different output is visible in the definition. There are no implicit
parallel joins, distributed compensation or executable condition expressions.

## Build a definition

Choose a template or edit its process name and designer role. Select a node to
edit its instructions, initial JSON object, input/output binding and assigned
performer/approver role. Selecting a node and adding from the palette inserts
after it. A single forward edge is rewired through the inserted node. Branches
are preserved for explicit editing. Move up/down changes visual order; invalid
backward edges are reported instead of silently rewritten.

Connections have a destination and a unique label within their source. Returns
have a positive traversal budget. The budget counts traversals of that edge over
the entire run, not attempts at the destination. Exhausted exits disappear from
the offered choices, and the engine also refuses forged attempts to use them.
Every named output has one owning node. The `feedback` binding is reserved for
review notes and cannot be used as a node output. Every node must have a path to an output.
AI nodes need a named output. Initial state must be a JSON object. The engine
validates a definition before starting and reports disconnected nodes, duplicate
identifiers, missing destinations and invalid exits.

The standalone state-machine tab lets a person create, name and remove states,
mark terminal states, connect events and exercise their enabled transitions.
It illustrates a step's lifecycle independently from the process definition.

## Run a process

Provide a brief and optionally choose a reference image. The demo reads a local
preview URL and includes its metadata/reference in the initial context. It does
not upload the bytes. The character template returns twelve deterministic SVG
illustration placeholders. The AI node's `imageCount` state field controls the
number of previews (1–24); invalid values fail explicitly instead of being clamped. Their appearance is simulated, not inferred from the
reference image. Instructions and input are retained in the mock AI result so
the server boundary is inspectable.

A run keeps a frozen definition. Later draft edits affect subsequent runs.
Named context is shared between steps; each node separately retains its initial
configuration and latest output. Attempts retain earlier outputs, failures,
feedback and the actor recorded by the simulated server. A return clears
downstream context bindings and current node outputs, so earlier approvals or
results cannot be mistaken for current evidence; their attempts remain inspectable. Inline image payloads
are abbreviated in the inspector; **Export results** retains the original values.

AI and wait nodes use delayed server requests. The initial input is a one-time entry point; use human tasks to collect later input.
Human tasks, reviews and branches
stop for an explicit decision. The document template deliberately asks the person
to select a confidence route; a production server would evaluate its condition.
Feedback is passed back into context for subsequent AI attempts. Failure injection
demonstrates retrying a node while retaining previous attempts. Pause, resume,
cancel, retry and run selection are available in the execution view. Leaving an
application route pauses its active process and invalidates pending page replies.

## Membership and approval

The membership template follows this sequence:

1. **Coordinator** starts an application.
2. **Interviewer** performs the interview and records notes.
3. **Coordinator** recommends admission, requests another interview, or closes it.
4. **Managing director** approves, requests clarification, or declines.
5. **Registrar** confirms enrollment and records a member reference.
6. The output returns the receipt. Declined applications finish through a separate
   output without creating an enrollment binding.

Use **Demo session** to switch between these fictional people. A manual task uses
its performer role; a review uses its approver role. The first node's performer
role controls starting the process. The definition's owner role controls draft
editing in the studio. Edit its value and choose **Apply designer role** to
transfer ownership explicitly, without revoking permission while typing. The starter or a `workflow-admin` can pause/cancel/retry.
The server checks permission again when a decision arrives and records the actor
in the attempt, so hiding a button is not the permission check.

These roles are a policy demonstration. The session selector is not
authentication. Production must resolve identities from verified server sessions,
store authoritative versioned definitions and role assignments, scope visibility
to authorized users, and enforce editing/start permissions against those stored
definitions. The pure engine and UI do not authenticate or authorize callers.
For approval-specific quorum rules and multiple approvers, `Klar.ApprovalFlow`
remains available alongside the workflow components; this studio assigns one role
per checkpoint and does not implement quorum voting.

## The request boundary

`example/src/Api/Workflows.elm` delays a request and hands it to
`Backend.WorkflowServer.handle` on arrival. The server owns run snapshots,
identifiers and revisions. Requests represent start, worker completion, decision,
pause, resume, retry, cancel and load. Replies are `Result String (Engine.Run id)`.
The page only shows accepted replies and retains notes if a write fails.

Every mutation of an existing run carries its id and expected revision. The
transport captures its session identity at submission; switching demo sessions
cannot grant privileges to an already submitted request or change its audit actor. A stale
or duplicate command fails before it can advance a different version. The page
also uses a generation ticket so replies from a cancelled request or previous
page session are ignored. Worker requests are internal simulator events; they
must be a server-owned queue/callback in a real service, not a user-accessible
endpoint accepting arbitrary completion claims.

To connect a real backend, replace `Api.Workflows.send` with the application's
HTTP/SSE/WebSocket transport, execute AI and timers on that backend, persist run
and attempt data, and deliver acknowledged snapshots back to `WorkflowRun`.
Klar stays transport neutral and never stores provider credentials or sends files.
