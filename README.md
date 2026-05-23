# Road to Karlskoga

Small mobile-first Godot prototype about building roads with cards and travelling across a square map with limited food.

The goal of version 1 is to answer one question: is it fun to build roads, manage a hand of cards, and navigate through a map using limited movement resources?

## Project status

Early prototype.

The current scope is defined in [`docs/design.md`](docs/design.md).

## Engine

Godot 4.6.

## Version 1 focus

- square grid map
- mobile-first touch controls
- road cards
- event cards
- food-limited movement
- simple win condition
- simple restart/manual retry flow

## Repository structure

Expected structure:

```text
assets/
data/
docs/
levels/
scenes/
scripts/
ui/
```

## Development notes

Keep version 1 small. Prefer simple, Godot-like scenes and resources over abstract systems. Do not add progression, meta systems, extra resources, or polish-heavy features before the core loop is playable.
