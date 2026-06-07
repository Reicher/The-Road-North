# Road to Karlskoga

Small mobile-first Godot prototype about building roads with cards and travelling across a square map with limited food.

The goal of version 1 is to answer one question: is it fun to build roads, manage a hand of cards, and navigate through a map using limited movement resources?

## Project status

Playable two-level prototype.

The current scope is defined in [`docs/design.md`](docs/design.md).

## Engine

Godot 4.6.

To run the game on an Android phone, follow [`docs/android.md`](docs/android.md).

## Version 1 focus

- square grid map
- mobile-first touch controls
- road cards
- four event cards
- food-limited movement
- enemies, berry bushes, and loot caches
- health, gold, weapons, loot, and a three-slot backpack
- progression between two authored levels
- level restart and full-game restart flows

## Repository structure

Current structure:

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

Keep version 1 small. Prefer simple, Godot-like scenes and resources over abstract systems. Do not add systems outside the scope in [`docs/design.md`](docs/design.md).

## Tests

Run the headless test suite from the repository root:

```sh
scripts/run_tests.sh
```
