# Implementation Design

## Project Structure

The project should follow normal Godot 4.6 scene and script conventions.

The codebase should remain modular and scene-oriented rather than centered around large manager scripts.

Suggested root structure:

- scenes/
- scripts/
- assets/
- data/
- ui/
- levels/

Version 1 should remain lightweight and avoid unnecessary abstractions.

The project should feel like a small focused game rather than a reusable engine.

---

# Main Scene Structure

The game starts from a single root scene.

Main scene:
- `scenes/main.tscn`

Current responsibilities:
- load the two authored levels in sequence
- capture player and inventory progression at level start
- carry progression into the next level
- restore level-start progression when restarting a level
- reset progression when restarting the game
- provide keyboard-only debug shortcuts

---

# Level Scene

Each playable map is represented by a Level scene.

Example:
- levels/level_001.tscn

Shared level plumbing should live in a reusable base scene:
- scenes/level.tscn

Individual level scenes inherit from the base scene and currently override:
- map size
- fixed terrain features
- hand size
- balance level used by deck and encounter generation

The Level scene is responsible for:
- map state
- tile placement
- player placement
- card interactions
- camera
- game state
- win/loss handling

Current shared Level scene structure:

- Level (Node)
  - Map (Node3D)
    - MapVisuals
  - Roads (Node3D)
  - Player (Node3D)
  - PlacementController (Node3D)
  - Camera3D
  - Sun
  - UI (CanvasLayer)
    - Hand
    - Loot
    - Inventory
    - PlayerStats
    - GameOver
  - DeckController

The Level script owns the high-level run state and input coordination. Gameplay rules remain in dedicated child nodes and scripts.

There should only be one PlacementController in the scene.

---

# Game States

The game should use explicit high-level states.

Suggested states:
- idle
- card_focused
- placement_mode
- event_targeting
- player_moving
- game_over
- run_won

This is primarily to simplify touch interactions and prevent conflicting input behavior.

Version 1 does not need a large generic state machine framework.

A simple enum and straightforward logic is sufficient.

The Level node owns the high-level run state and coordinates input availability between child nodes. For example, entering placement mode disables player movement, and entering player_moving disables gameplay input until movement resolves.

---

# Map Node

The Map node owns:
- playable dimensions
- tile lookup
- placement validation
- movement validation
- coordinate conversion
- helper coordinate functions

The Map node should expose helper methods such as:
- get_tile(position)
- can_place_tile(position, connections)
- can_move_between(a, b)
- get_neighbors(position)
- is_inside_playable_area(position)
- world_to_grid(position)
- grid_to_world(position)

The Map does not know anything about cards or UI.

It only understands tiles, coordinate helpers, movement and placement rules, and lightweight tile metadata such as an encounter dictionary attached to a placed tile.

Placement validation rejects road openings pointing outside the playable area. The surrounding visual forest should be substantially denser than trees on playable empty tiles so the boundary reads as impassable.

The Map should be the single owner of world/grid coordinate conversion.

The Map should own all logical tile data.

Authored levels may also define fixed terrain features owned by the Map:
- mountains and rivers block road placement
- bridges occupy their tile and expose fixed road connections

These features are lightweight map metadata rather than a separate terrain system. Mountains and rivers block placement and movement. Bridges are fixed crossings with road connections.

---

# Roads Node

The Roads node owns all spawned visual road tile scenes.

Responsibilities:
- spawning tile scenes
- removing tile scenes
- updating tile visuals

The Roads node should not contain gameplay rules.

Logical validation should remain inside the Map node.

---

# Road Tile Representation

Road tiles should be data-driven.

A tile should contain:
- tile type
- rotation
- directional openings

Suggested directions:
- north
- east
- south
- west

The openings should preferably be represented internally as booleans or bitmasks.

Example:
- Straight vertical = north + south
- Corner = north + east

Rotation should transform openings dynamically rather than requiring separate scenes for every orientation.

TileDefinition resources should be the single source of truth for connection data.

Avoid duplicating connection logic across scenes or scripts.

---

# Tile Scene

Road tiles should use a reusable Tile scene.

The reusable Tile scene is a `Node3D` that builds simple road, landmark, encounter, and highlight visuals.

The Tile scene should:
- display visuals
- support rotation
- support placement highlighting

The Tile scene should not own gameplay rules.

The Tile scene should read connection information from TileDefinition resources.

Road visuals should remain perfectly square and aligned to the grid.

The map should not draw internal debug grid lines. It should draw only a thin outline around the playable area's outer boundary.

Preview tiles should use light tinting to indicate valid or invalid placement.

---

# Player

The Player scene represents the pawn on the map.

The Player is a `Node3D` with separate `Combat`, `Rewards`, and `Visuals` children.

Responsibilities:
- current grid position
- movement tweening
- movement state
- food, health, gold, and simple combat/reward resolution

The player should expose:
- move_to(grid_position)

The Player asks the Map to validate movement before spending food or starting a move. Movement is animated as a short multi-hop tween.

Movement should always resolve one step at a time.

The player pawn itself visually indicates the current tile.

The Player emits movement and run outcome signals upward. Level uses those signals to update the high-level run state.

Player child helpers handle narrow combat and reward responsibilities:
- Combat: reads enemy encounter data and computes damage
- Rewards: collects resource loot and inventory item loot

These helpers should remain small and direct. They should not become generic effect systems.

---

# DeckController

DeckController owns:
- deck shuffling
- draw pile
- draw logic
- hand refill
- event-card execution for Idea and Lucky Find
- deck-count reporting

DeckBuilder owns:
- road and event card generation
- road subtype distribution
- enemy, berry-bush, and cache encounter attachment
- debug hand generation

GameBalance is the shared source for starting values, deck-size formulas, encounter counts, enemy power ranges, and reward values.

The DeckController should not contain hand UI logic.

The Hand node displays cards and owns focus/drag interaction, but does not execute card effects.

---

# Hand System

The hand is its own isolated UI system.

Current structure:

- Hand (Control)
  - CardContainer

Cards:
- ui/card.tscn

The Hand system owns:
- card selection
- focus state
- animations
- dynamic spacing/compression
- card drag recognition
- the temporary dragged-card visual
- the tweened inactive hand position used during placement and targeting

Cards are not manually reorderable in version 1.

The Level scene receives high-level interaction and outcome signals such as:
- card_focused
- card_unfocused
- placement_started
- placement_confirmed
- movement_finished
- run_won

The hand should not directly manipulate map state.

---

# Card Scene

Current structure:

- Card (Control)
  - Title
  - Category
  - Detail
  - TouchButton

Responsibilities:
- displaying card visuals
- focus animation
- input forwarding

The Card should not know gameplay rules.

It only knows:
- card category
- visual state

CardDefinition resources contain:
- category
- tile_definition for road cards
- event_type for event cards
- optional encounter data

---

# Placement Mode

Placement mode should be handled by a dedicated PlacementController node.

Responsibilities:
- showing preview tile
- moving preview tile
- rotating preview
- validating placement
- applying the player's current orthogonal target range
- showing one green or red preview for the currently selected targeted-event tile
- confirming placement
- cancelling placement

The controller should query the Map for validation.

The controller should not permanently modify map state until confirmation.

Placement flow:
- player drags a road card upward from the hand
- crossing the activation boundary starts placement mode
- the preview tile follows the drag and snaps to map tiles
- placement controls stay hidden while the drag remains active
- releasing over the map leaves the preview selected
- releasing over the map shows the relevant placement controls
- preview becomes green or red depending on validity
- player may rotate the preview
- player confirms or cancels

The player must drag from the current preview tile to move it. Tapping another tile does not move the preview.

Once released, the preview remains draggable while the existing rotate, confirm, and cancel flow remains active.

Double tapping the preview tile should rotate it.

Version 1 does not need a generic placement framework.

---

# Event Cards

Event cards should use the same card pipeline as road cards.

The difference should primarily exist in:
- card data
- explicit card behavior

Avoid generic effect systems in version 1.

Current events:
- Mirage enters target selection mode and destroys one placed tile.
- Idea consumes itself, draws its normal replacement, then draws up to two extra cards.
- Doubt enters target selection mode and previews rotation of one placed road tile.
- Lucky Find consumes itself and grants either 3 food or 4 gold.

All events are dragged onto the map. Idea and Lucky Find resolve immediately when released over the playable map. Mirage and Doubt enter targeting when dragged above the hand, follow the drag for their initial target, and remain draggable in the normal confirm/cancel flow after release.

Road placement and targeted events currently share a simple orthogonal target range of one tile from the player. The range is an explicit PlacementController value so future items can increase it without changing each card's targeting rules.

PlacementController reads target range bonuses from InventoryUI. Kikare contributes `target_range_bonus: 1`, expanding valid targets to Manhattan distance two. Each cache contains exactly one item and has a 15% chance to contain Kikare instead of a weapon. Enemy loot contains only gold.

Road placement deliberately does not show valid empty tiles before the player previews them. Only the active road preview communicates validity through its green or red tint.

Targeted events follow the same rule and do not reveal valid targets in advance. Only the currently previewed target tile is marked green or red.

Future event cards may use different targeting patterns.

Avoid separate UI systems for event cards.

---

# Combat, Loot, and Inventory

Combat, loot, and inventory are part of the current version 1 prototype structure.

They should stay layered on top of the road-card loop:
- DeckBuilder may attach enemy or reward encounter data to road cards.
- GameBalance calculates encounter counts from level and map size.
- Roads stores encounter data on the placed tile and passes it to the visual tile.
- Player resolves encounters when entering a tile.
- PlayerRewards handles resource/item collection.
- PlayerCombat handles simple enemy damage calculations.
- LootUI presents loot and collection interaction.
- InventoryUI stores a small fixed backpack and computes the strongest weapon power bonus.

The structure should remain simple:
- no generic effect engine
- no economy system
- no progression persisted between separate games
- no equipment slot framework beyond the strongest weapon power bonus
- no separate encounter scene hierarchy unless the current tile drawing becomes unmanageable

The Level scene may include Loot and Inventory under UI, but those systems should not own map, deck, or placement rules.

---

# Camera

The Camera3D node:
- support pinch zoom
- support two-finger pan
- support mouse/trackpad pan and zoom during desktop development
- reserve the hand area when calculating the visible map viewport
- clamp to the playable map plus a three-tile visual forest margin
- show the full map, then zoom toward the start position
- follow the pawn while movement is active
- briefly settle on the player after movement resolves

The camera does not continuously follow the player while idle.

The dedicated camera controller script is attached directly to `Camera3D`.

When placement mode is active:
- single finger controls placement
- two finger gestures may still pan/zoom

---

# Data Definitions

Road cards and event cards should use Godot Resources.

Version 1 should avoid:
- JSON config systems
- generic scripting systems
- external data pipelines

Example concepts:
- CardDefinition
- TileDefinition

This keeps gameplay rules separate from scenes while staying simple.

---

# Signals

Use signals primarily upward through the scene hierarchy.

Examples:
- card_used
- placement_confirmed
- movement_finished
- tile_destroyed
- run_won

Prefer direct references downward.

Avoid unnecessary signal chains or event-bus-style architecture.

---

# Recommended Philosophy

Version 1 should optimize for:
- clean scene separation
- simple responsibilities
- readable code
- iteration speed
- minimal architecture

Avoid:
- singleton-heavy architecture
- overengineering
- premature save systems
- multiplayer assumptions
- generic frameworks
- factories
- registries
- generic effect pipelines
- reusable engine-style abstractions

The project should feel like a small focused Godot game rather than an engine.
