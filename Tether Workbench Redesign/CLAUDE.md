# Tether Workbench — design principles

Binding rules for all design work in this project. Break one only deliberately, never by accident.

## Intent first
- Start from user intent, not visuals. Answer "what did the user come to do?" before drawing anything.
- Web pages are scripts: each screen leads to the next obvious step.
- Add functionality only when intent expands. No filters/cards/menus "just in case."
- Novelty is allowed only when it improves the task. "Unusual" is not an argument.

## Workbench intent
The workflow is: capture trace → find failed node → inspect prompt/response → patch output → replay.
Every choice must make it faster to answer: what happened, where it failed, what the model saw, what it returned, was it cached, what it cost, what can I patch/replay.

## Content & layout
- Decide the content structure before the design.
- Lists/cards show only scan-critical fields (status, model, latency, cost, cache, state); push detail to the detail/inspector view.
- Use familiar layout patterns: top-to-bottom, left-to-right; nav top/side; primary action easy to find.
- Progressive disclosure: show the basics immediately, reveal complexity on request. Menus/collapsibles/popovers save space, not for decoration.

## Robustness
- Design for bad content: long names/IDs/URLs, empty data, errors, no results, overflow.
- Truncate/wrap long text deliberately — layout must never break.
- Guarantee contrast: text/icons over busy backgrounds need a backing or another solution.
- Empty, loading, and error states are designed deliberately.

## Interaction
- Every control needs feedback: hover, press, and loading states.
- Animation must add clarity or function; "just pleasant" is suspect. No scrolljacking.
- Prefer "Load more" over infinite scroll where it preserves control and footer access.
- Interactions are fast and quiet: selection, hover, active, optimistic UI.

## Visual system (this project)
Light shell, white panels with subtle borders. Dark compact node cards ONLY inside the graph/failure path. Neutral palette + meaningful status colors: success green, cached cyan, error red/pink, stale amber, selected near-black. Radius ≤ 8px. Tight, dense typography (title 24–30, section 13–15, table 12–13, code 12 mono). No marketing hero, gradients, blobs, or oversized type.

## Code
No comments — self-documenting names. Minimal, intentional, no dead code, no placeholders except real empty/loading states.
