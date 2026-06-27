# Implementation Design

## Project Structure

Godot 4.6, modular scene-oriented structure. Root folders: `scenes/`, `scripts/`, `assets/`, `data/`, `ui/`, `levels/`. Keep it lightweight — small focused game, not a reusable engine.

---

## Main Scene (`scenes/main.tscn`)

Responsibilities:
- Load levels in sequence, carry/restore/reset progression
- Open between-level shop, apply pending potion bonuses
- Configure player deck modifiers (removals, special cards)
- Debug shortcuts (keyboard only)

---

## Level Scene

Base scene: `scenes/level.tscn`. Level overrides (e.g. `levels/level_001.tscn`): map size, fixed features, hand size, balance level.

Scene tree:
```
Level (Node)
├── Map (Node3D) → MapVisuals
├── Roads (Node3D)
├── Player (Node3D)
├── PlacementController (Node3D)
├── Camera3D
├── Sun
├── UI (CanvasLayer) → Hand, Loot, Inventory, PlayerStats, GameOver
└── DeckController → DeckBuilder
```

The Level script owns the run state enum and coordinates input between children.

---

## Game States

Simple enum on Level: `IDLE`, `CARD_FOCUSED`, `PLACEMENT_MODE`, `EVENT_TARGETING`, `PLAYER_MOVING`, `GAME_OVER`, `RUN_WON`. Entering a state disables conflicting inputs (e.g. placement disables movement). No generic state machine needed.

---

## Map Node

Owns: playable dimensions, tile data, placement/movement validation, coordinate conversion, fixed terrain features (mountains/rivers/bridges as lightweight metadata).

Key methods: `get_tile`, `can_place_tile`, `can_move_between`, `get_neighbors`, `is_inside_playable_area`, `world_to_grid`, `grid_to_world`.

Does not know about cards or UI. Rejects openings pointing off-map. Single owner of coordinate conversion.

---

## Roads Node

Owns spawned visual tile scenes. Spawns, removes, and updates visuals. No gameplay rules — logical validation stays in Map.

---

## Road Tile Representation

Data-driven via `TileDefinition` resources (single source of truth for connections). Stores: tile type, rotation, directional openings (north/east/south/west booleans). Rotation transforms openings dynamically.

`RoadTile` scene (`Node3D`): displays visuals, supports rotation and highlight tinting. Does not own gameplay rules.

---

## Player

`Node3D` with `Rewards` and `Visuals` children.

Owns: grid position, movement tweening (multi-hop), food/health/gold, and multi-round contested-roll combat (`total_power + 1d6` versus `enemy_power + 1d6`) coordinated with a blocking Fight/Retreat/OK popup. Entering an enemy tile spends normal movement food before combat. Defeat and tie allow another Fight or a free Retreat to the origin tile; a loss deals exactly 1 health.

Exposes `move_to(grid_position)`. Asks Map to validate before moving. Emits `move_started`, `moved`, `move_failed`, `game_over`, `run_won` upward to Level.

PlayerRewards: collects resource loot and inventory items. Stays small and direct.

---

## DeckController / DeckBuilder / GameBalance

**DeckController** owns: shuffling, draw pile, draw logic, hand refill, immediate event execution (Idea, Lucky Find, restart_level), deck-count reporting.

**DeckBuilder** owns: road/event card generation, base+level+player-special components, road subtype distribution, encounter attachment, debug hands.

**GameBalance** is the shared source for starting values, deck-size formulas, encounter counts, enemy power ranges, and reward values.

---

## Hand System

`Hand` (Control) → `CardContainer`. Owns: card selection/focus, animations, spacing compression, drag recognition, dragged-card ghost, inactive hand position during placement.

Signals upward: `card_focused`, `card_unfocused`, `card_drag_started`, `card_drag_moved`, `card_drag_finished`. Does not manipulate map state.

**Card scene** (Control): Title, Category, Detail, TouchButton. Displays visuals and forwards input. No gameplay rules. `CardDefinition` resources contain category, tile_definition, event_type, optional encounter data.

---

## PlacementController

Dedicated `Node3D` handling preview tile, rotation, validation, and confirm/cancel flow.

Modes: road placement, destroy targeting, rotate targeting, encounter targeting.

Flow: card dragged above hand → mode starts → preview follows drag → release shows controls → drag preview to move it → rotate/confirm/cancel. Double-tap rotates. Queries Map for validity; does not modify state until confirmation.

Sight = base (1) + inventory bonus (Binoculars), measured as square/Chebyshev
distance so diagonals are included. Placement and directed event modes dim cells
outside Sight with fog-of-war. Only the active preview shows green/red — no
advance hints.

---

## PlacementValidator

Focused `RefCounted` helper. Road placement hints (too far, occupied, terrain, off-map, doesn't fit). Tile targeting validation. Sight checks via callable for live Sight. Keeps PlacementController focused on interaction.

---

## Event Cards

Same card pipeline as road cards, differing only in data and explicit behavior. No generic effect system.

Immediate: Idea (draw 2 extra), Lucky Find (3 food or 4 gold), It was all a dream (restart level).
Targeted: Mirage (destroy tile), Doubt (rotate tile), Clear Path (remove encounter), Trouble (add enemy), Wild Berries (add berry bush), Lost Belongings (add cache).

All dragged onto map. Immediate events resolve on release. Targeted events enter confirm/cancel flow.

---

## Combat, Loot, and Inventory

Layered on road-card loop:
- DeckBuilder attaches encounter data to road cards
- GameBalance calculates encounter counts
- Roads stores encounters on tiles
- Player resolves encounters inline on enter
- PlayerRewards collects loot
- LootUI presents collection; InventoryUI stores the 3-slot backpack and sums all carried item stats

No generic effect engine or separate active/equipped state. Every carried item applies its stats; the backpack enforces at most one large item.

---

## ItemCatalog

Static `RefCounted` and single source of truth for weapons and utility items. Each item has `stats`, calculated `item_score`, startup-assigned `rarity`, and `size`; stats may be negative for tradeoff items. Cache loot first rolls Common/Uncommon/Rare/Epic at 50/30/15/5, then chooses uniformly from that group. Loot is not level-specific. Inventory supports Power, Sight, Max Health, and Max Hand Size stats plus explicit special effects such as the gold multiplier. Dagger and Hatchet are small weapons; heavier weapons and Field Medic's Bag are large.

---

## ShopUI

Standalone `Control` instantiated by Main. Features: food (5/4g), heal (2HP/5g), power potion (8g), max-health potion (10g), sell zone, two item offers (Dagger 7g, Hatchet 12g), three special-card offers, and a visual deck overlay with one base- or player-special-card removal per shop (base 12g, +6g each). The removal button requires enough gold. Protected types: Straight, Corner, T-Junction.

Emits `play_next_requested(progression)`. Potions stored as `pending_*` keys, applied by Main on next level load.

---

## GameConstants

Static `RefCounted`, single source of truth: card categories, encounter types, feature types, event type strings, targeted/encounter event arrays, deck sources, direction vectors/opposites, stat icon paths, `card_signature()` utility.

---

## Camera

Script on `Camera3D`. Pinch zoom, two-finger pan, mouse/trackpad for desktop. Reserves hand area for viewport calc. Clamped to map + 3-tile margin. Start sequence: full map → zoom to start. Follows pawn during movement, settles after. Input handled by `CameraInputHandler` (RefCounted).

---

## Data Definitions

Use Godot Resources (`CardDefinition`, `TileDefinition`). Avoid JSON configs, scripting systems, or external pipelines.

---

## Signals

Signals upward, direct references downward. Key signals: `placement_started`, `placement_confirmed`, `tile_destroyed`, `tile_rotated`, `encounter_changed`, `moved`, `run_won`. No event-bus architecture.

---

## Philosophy

Optimize for: clean scene separation, simple responsibilities, readable code, iteration speed, minimal architecture.

Avoid: singletons, overengineering, multiplayer assumptions, generic frameworks, factories, registries, effect pipelines, engine-style abstractions.

Small focused Godot game, not an engine.
