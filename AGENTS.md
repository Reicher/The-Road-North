# AGENTS

## Rules

Read `docs/design.md` before implementing features.

Prioritize:
- small scope
- playable prototype
- Godot-like scene structure
- mobile-first usability
- simple implementations

Prefer:
- scenes over deep inheritance
- resources for static data
- explicit naming
- direct gameplay code over premature abstraction

## Do not

Do not introduce new dependencies without explaining why.
Do not rewrite unrelated code.
Do not add systems not described in the design document.
Do not silently change gameplay rules from the design.
Do not silence errors or tests to make a task pass.
