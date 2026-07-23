# Repository Instructions

## Product goal

Build the V0.1 vertical slice of a fantasy adventurer-guild management game.
The player indirectly shapes outcomes through contracts, staffing, preparation,
values, and resource trade-offs. The current goal is to validate the management
loop, not to build the full planned game.

Read these documents before relevant work:

- `docs/01_v0.1_product_spec.md`
- `docs/02_core_loop_and_rules.md`
- `docs/03_godot_architecture.md`
- `docs/04_data_model.md`
- the task file referenced by the user

When documents conflict, product scope wins over implementation convenience.
Accepted ADRs override older technical guidance.

## Stack

- Godot 4.7 stable
- GDScript with static type annotations
- Desktop-first
- Control-based UI
- No third-party addons in V0.1

Do not change the engine version, language, dependencies, save schema, or Autoload
list unless the task explicitly authorizes it.

## Architecture rules

- Domain simulation must run without a scene tree or UI.
- UI must not contain game formulas or mutate multiple domain objects directly.
- Static `*Definition` Resources are read-only at runtime.
- Mutable campaign data lives in `*State` objects.
- All simulation randomness must use an explicit seed or injected
  `RandomNumberGenerator`.
- Every meaningful state change must have a structured reason entry.
- Prefer small typed `RefCounted` services over globally accessible Nodes.
- Maximum V0.1 Autoloads: `GameSession`, `DataCatalog`, and `SceneRouter`.
- Do not add a global event bus.
- Do not use executable strings for world rules or triggers.

## Godot conventions

- Use `snake_case` for folders, files, variables, and functions.
- Use `PascalCase` for node names and named classes.
- Keep assets close to the feature or scene that owns them unless they are truly
  shared.
- Use explicit node references or exported references; avoid brittle deep
  `$Path/To/Node` access from unrelated scenes.
- Use signals for notification, not hidden multi-step control flow.
- Do not edit generated `.godot/` content.

## Scope discipline

Do not implement features listed as out of scope in the product spec.
Do not create speculative frameworks for future combat, multiplayer, procedural
content, ECS, staff departments, equipment affixes, or multi-squad execution.
Choose the smallest implementation that satisfies the current acceptance tests.

## Testing

Run the focused tests for the changed module and then the complete suite:

```bash
godot --headless --path . --script res://tests/run_all.gd
```

New rule behavior requires tests. Deterministic simulation changes require a test
that repeats the same input and seed. Save changes require a round-trip test.
Do not update golden expectations automatically; report the difference for human
review.

## Task execution

Before editing:

1. Read this file and the referenced task.
2. Inspect existing code and tests.
3. State any blocking contradiction in the task report; otherwise make the
   narrowest reasonable implementation.

After editing:

1. Run tests.
2. Review the diff for scope creep and accidental shared Resource mutation.
3. Report files changed, behavior, tests and results, assumptions, and remaining
   risks.

Do not claim tests passed unless they were actually run successfully.
