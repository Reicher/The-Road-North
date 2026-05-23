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

---

# Main Scene Structure

The game starts from a single root scene.

Main scene:
- Main

Responsibilities:
- loading levels
- global game startup
- scene transitions
- persistent systems if needed later

Version 1 should remain lightweight.

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
- win/loss state

Suggested Level scene structure:

- Level (Node2D)
  - Map
  - Roads
  - Player
  - Camera
  - UI
    - Hand
    - HUD
    - PlacementUI

The Level scene should contain very little direct gameplay logic itself.

Most logic should live in dedicated child nodes and scripts.

---

# Map Node

The Map node owns:
- playable dimensions
- padding dimensions
- tile lookup
- placement validation
- helper coordinate functions

The Map node should expose helper methods such as:
- get_tile(position)
- can_place_tile(position, connections)
- get_neighbors(position)
- is_inside_playable_area(position)

The Map should not know anything about cards or UI.

It only understands tiles and rules.

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

---

# Tile Scene

Road tiles should use a reusable Tile scene.

Suggested structure:

- Tile (Node2D)
  - Sprite2D
  - Highlight

The Tile scene should:
- display visuals
- expose connection data
- support rotation
- support placement highlighting

The Tile scene should not own gameplay rules.

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

---

# Hand System

The hand is its own isolated UI system.

Suggested structure:

- Hand (Control)
  - CardContainer

Cards:
- ui/hand/card.tscn

The Hand system owns:
- card ordering
- card selection
- drag reordering
- focus state
- animations

The Level scene should only receive high-level signals such as:
- card_selected
- card_used
- card_reordered

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
- card type
- visual state

---

# Placement Mode

Placement mode should be its own isolated controller.

Suggested node:
- PlacementController

Responsibilities:
- showing preview tile
- rotating preview
- validating placement
- confirming placement
- cancelling placement

The controller should query the Map for validation.

The controller should not permanently modify map state until confirmation.

---

# Event Cards

Event cards should use the same card pipeline as road cards.

The difference should primarily exist in:
- card data
- execution behavior

Avoid separate UI systems for event cards.

---

# Camera

The Camera node should:
- support pinch zoom
- support two-finger pan
- clamp to padded map bounds

The camera should not automatically follow the player.

Suggested structure:

- Camera2D

Prefer implementing touch handling in a dedicated camera controller script.

---

# Data Definitions

Road cards and event cards should preferably be data-defined.

Possible approaches:
- Resources
- JSON
- dictionaries

Version 1 can use lightweight Godot Resources.

Example concepts:
- CardDefinition
- TileDefinition

This keeps gameplay rules separate from scenes.

---

# Signals

Use Godot signals heavily.

Examples:
- card_used
- placement_confirmed
- movement_finished
- tile_destroyed
- run_won

Avoid tight coupling between UI and gameplay systems.

---

# Recommended Philosophy

Version 1 should optimize for:
- clean scene separation
- simple responsibilities
- readable code
- iteration speed

Avoid:
- singleton-heavy architecture
- overengineering
- premature save systems
- multiplayer assumptions
- generic frameworks

The project should feel like a small, focused Godot game rather than an engine.
