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
- Main

Responsibilities:
- loading levels
- global game startup
- scene transitions if needed later

Version 1 should stay minimal.

---

# Level Scene

Each playable map is represented by a Level scene.

Example:
- levels/level_001.tscn

The Level scene is responsible for:
- map state
- tile placement
- player placement
- card interactions
- camera
- game state
- win/loss handling

Suggested Level scene structure:

- Level (Node2D)
  - Map
  - Roads
  - Player
  - DeckController
  - PlacementController
  - Camera
  - UI
    - Hand
    - HUD

The Level scene should contain very little direct gameplay logic itself.

Most logic should live in dedicated child nodes and scripts.

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
- win_screen

This is primarily to simplify touch interactions and prevent conflicting input behavior.

Version 1 does not need a large generic state machine framework.

A simple enum and straightforward logic is sufficient.

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

The Map should not know anything about cards or UI.

It only understands tiles and rules.

The Map should be the single owner of world/grid coordinate conversion.

The Map should own all logical tile data.

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

Suggested structure:

- Tile (Node2D)
  - Sprite2D
  - Highlight

The Tile scene should:
- display visuals
- support rotation
- support placement highlighting

The Tile scene should not own gameplay rules.

The Tile scene should read connection information from TileDefinition resources.

Road visuals should remain perfectly square and aligned to the grid.

Preview tiles should use light tinting to indicate valid or invalid placement.

---

# Player

The Player scene represents the pawn on the map.

Suggested structure:

- Player (Node2D)
  - Sprite2D

Responsibilities:
- current grid position
- movement tweening
- movement state

The player should expose:
- move_to(grid_position)

The Player scene should not directly validate movement.

The Map handles validation.

Movement should always resolve one step at a time.

The player pawn itself visually indicates the current tile.

---

# DeckController

DeckController owns:
- deck generation
- deck shuffling
- draw pile
- draw logic
- hand refill

The DeckController should not contain hand UI logic.

The Hand node only displays cards.

---

# Hand System

The hand is its own isolated UI system.

Suggested structure:

- Hand (Control)
  - CardContainer

Cards:
- ui/hand/card.tscn

The Hand system owns:
- card selection
- focus state
- animations
- dynamic spacing/compression

Cards are not manually reorderable in version 1.

The Level scene should only receive high-level signals such as:
- card_selected
- card_used

The hand should not directly manipulate map state.

---

# Card Scene

Suggested structure:

- Card (Control)
  - Background
  - Icon
  - Label
  - UseButton

Responsibilities:
- displaying card visuals
- focus animation
- input forwarding

The Card should not know gameplay rules.

It only knows:
- card category
- visual state

CardDefinition resources should minimally contain:
- card_category
- tile_definition for road cards
- event_type for event cards

---

# Placement Mode

Placement mode should be handled by a dedicated PlacementController node.

Responsibilities:
- showing preview tile
- moving preview tile
- rotating preview
- validating placement
- confirming placement
- cancelling placement

The controller should query the Map for validation.

The controller should not permanently modify map state until confirmation.

Placement flow:
- player presses Use on a road card
- player taps anywhere on the map
- preview tile snaps to the tapped tile
- preview becomes green or red depending on validity
- player may rotate the preview
- player confirms or cancels

The player may tap another tile to move the preview.

There should be:
- no dragging
- no follow-finger placement
- no continuous movement placement

Double tapping the preview tile should rotate it.

Version 1 does not need a generic placement framework.

---

# Event Cards

Event cards should use the same card pipeline as road cards.

The difference should primarily exist in:
- card data
- explicit card behavior

Avoid generic effect systems in version 1.

Examples:
- road cards enter placement mode
- destroy cards enter target selection mode
- draw cards immediately draw cards

Future event cards may use different targeting patterns.

Avoid separate UI systems for event cards.

---

# Camera

The Camera node should:
- support pinch zoom
- support two-finger pan
- clamp to playable map bounds

The camera should not automatically follow the player.

Suggested structure:

- Camera2D

Prefer implementing touch handling in a dedicated camera controller script.

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
