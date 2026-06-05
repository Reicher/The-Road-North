# Version 1 Design Document

## Overview

The goal of version 1 is to build a small mobile-first technical demo focused on one question:

> Is it fun to build roads, manage a hand of cards, and navigate through a map using limited movement resources?

The game is a calm, tactical, singleplayer experience played on a square grid. The player travels from the bottom of the map to the top by placing road tiles using cards drawn from a deck, managing food, and dealing with simple encounters placed on some roads.

The game should feel readable, tactile, strategic, and pleasant to interact with on a phone.

---

## Visual Style and Perspective

The game map should be viewed from a slightly elevated angled 3D perspective, roughly 45 degrees above the ground.

However, the gameplay grid itself should remain a normal square grid. Tiles should not use isometric diamonds or rotated coordinate systems. Movement and placement logic should still operate on a clean orthogonal grid with north/south/east/west adjacency.

Visually, this means:
- square gameplay coordinates
- square tile logic
- non-isometric gameplay rules
- but rendered with a simple angled 3D camera

The overall feel should resemble a simple stylized tabletop adventure map viewed from slightly above and at an angle.

Menus, cards, stats, loot, inventory, and placement controls remain 2D UI.

The map itself is rendered in simple real 3D using primitive low-detail shapes:
- empty tiles are flat grass surfaces with a few small trees
- road tiles are flat grass surfaces with raised road geometry and a few trees placed away from the road
- player and enemies are simple readable 3D pawns
- start and goal use simple 3D landmark shapes

The 3D presentation must not change any placement, movement, deck, encounter, or win/loss rules.

---

# Map Structure

The prototype supports multiple square levels. The base run target remains a compact square grid, with the current level set including a small 5x5 introductory map and a larger 7x7 map.

The playable area has no surrounding gameplay padding border.

The 3D world should show dense forest outside all four edges of the playable grid so angled camera views never reveal an empty void beyond small maps. This surrounding forest is visual only and does not add playable tiles.

The camera must never show outside the playable map area.

The grid itself should not be rendered visually as debug lines. The playable area should have a thin visible outline around its outer edge so the player can read the boundary without seeing internal grid lines.

The map starts with only the start and goal tiles placed. All other tiles are empty.

Both the start and goal positions are T-crossings rotated so their open side faces inward toward the center of the map:
- The start tile at the bottom has openings facing left, right, and up.
- The goal tile at the top has openings facing left, right, and down.

The start position is at the bottom center of the playable area. The goal position is at the top center.

For a 9x9 map:
- Start position = `(4, 8)`
- Goal position = `(4, 0)`

Coordinates use:
- X increasing left to right
- Y increasing top to bottom

Road openings may never point outside the playable map.

The start and goal tiles are permanent occupied tiles and may never be overwritten.

Some authored levels may include fixed terrain features:
- mountains block placement and movement
- rivers block placement and movement
- bridges are fixed road-like crossings over rivers

Fixed terrain features are level content, not player-placed roads. They should remain simple obstacles or crossings that support the road-building puzzle without adding new systems.

---

# Camera and Controls

The game is designed primarily for portrait mobile play.

The player can:
- pinch to zoom
- use two fingers to pan the camera

Zoom is clamped between a minimum zoom level and a maximum that shows the full playable area.

The camera briefly focuses on the player after movement resolves so the pawn stays readable during play. It should not continuously follow the player while the player is idle or manually panning.

The camera position must be clamped so the player can never pan outside the playable map boundaries.

All interaction should work entirely through touch.

When placement mode is active:
- single-finger interaction controls placement
- two-finger gestures may still pan and zoom the camera

---

# Movement

The player is represented by a simple marker or pawn.

The player pawn visually indicates the current tile position.

When the player taps an adjacent tile that has a valid road connection, the player marker moves there.

Movement rules:
- only orthogonal movement
- one tile at a time
- movement costs 1 food
- movement is only allowed if both tiles connect correctly toward each other
- movement is processed one step at a time

Connections are fully bidirectional.

The player may freely backtrack if valid roads and food exist.

The player starts each run with food equal to approximately one quarter of the playable map area. On a 9x9 map this is 20 food.

The movement itself should be tweened/interpolated over a short duration so the marker appears to travel along the road rather than teleport instantly.

Movement should feel smooth and tactile, but still quick.

Gameplay interaction should be temporarily disabled during movement tweening.

---

# Cards and Decks

Version 1 uses a single shared deck per run.

There is no persistent personal deck or meta-progression between runs. The prototype may include a short sequence of authored levels during one play session; completing a level advances to the next level, while restarting the game returns to the first level.

The deck contains one card per playable tile — on a 9x9 map that is 81 cards total.

The deck composition is:
- 75% road cards
- 25% event cards

Road card subtype distribution applies only within the road card category.

The deck is shuffled randomly at the start of each level.

The player always has 4 cards in hand.

When a card is used:
- it disappears from the hand
- a new card is immediately drawn from the deck, if any remain

Cards are not reshuffled during a run.

When the deck is empty, no new cards are drawn.

The player may continue moving and playing remaining cards freely.

There is no discard action.

The player may:
- move multiple times before placing
- place multiple tiles before moving
- freely mix actions in any order

---

# Hand Presentation

The player’s hand is displayed at the bottom of the screen.

Cards are shown overlapping slightly in a curved arc.

The hand should always fit within the screen width by dynamically compressing the spacing between cards when necessary.

When the player taps a card:
- that card moves upward and toward the center
- the surrounding cards compress slightly outward
- the selected card becomes larger and easier to read
- a "Use" button appears on the lower part of the focused card

The Use button is only visible when a card is focused.

Tapping the Use button on a road card enters placement mode.

Tapping the Use button on an event card triggers the event immediately or enters targeting mode.

Tapping a different card focuses that card instead.

Tapping outside the hand deselects the current card.

Cards cannot be manually reordered in version 1.

---

# Card Types

Version 1 contains two categories of cards:
- Road Cards
- Event Cards

Some road cards may also contain encounters. Encounter data modifies the road tile being placed, but the card is still a road card and follows the normal road placement rules.

---

# Road Cards

Road cards place tiles onto the map.

The initial road tile types are:
- Straight Road
- Corner
- T-Junction
- Four-Way Intersection
- Dead End

Dead ends should appear relatively rarely.

Suggested distribution within road cards:
- Straight: 30%
- Corner: 30%
- T-Junction: 20%
- Four-Way: 10%
- Dead End: 10%

Road cards can be rotated before placement.

Some road cards contain a hidden enemy or reward encounter.

Suggested encounter distribution within road cards:
- Enemy encounter: 20%
- Reward encounter: 15%

Encounter road cards:
- still place normal road tiles
- still use the same road connection and rotation rules
- show enough card text to communicate that an encounter is attached
- attach the encounter to the placed tile

Enemy encounters are revealed when placed so the player can see the threat on the map.

Reward encounters may grant food or an item when the player reaches the tile.

When the player selects a road card from their hand, the game enters placement mode.

In placement mode:
- the player may tap any tile on the map
- a preview tile snaps to the tapped tile
- the preview tile is tinted green when placement is valid
- the preview tile is tinted red when placement is invalid
- the preview tile itself acts as the visual placement hint
- three buttons appear below the preview: rotate, confirm, and cancel
- the rotate button turns the tile 90 degrees clockwise
- double tapping the preview tile also rotates it
- invalid preview tiles may still be rotated
- the confirm button is only active while the preview is valid
- tapping another tile moves the preview there
- the cancel button exits placement mode and returns the card to the hand

There is no dragging, follow-finger behavior, or continuous placement movement.

A road card may only be legally placed:
- on an empty playable tile
- orthogonally adjacent to the player’s current tile

A placement is only valid if all of the following are true:
- the new tile is adjacent to the player's current tile
- the new tile connects correctly to the player's current tile
- the new tile connects correctly to all neighboring tiles
- all neighboring tiles with an opening toward the new tile are matched back
- the tile does not create openings outside the playable map

Neighboring tiles without openings toward the new tile are valid.

A connection is only valid if both tiles connect toward each other.

---

# Event Cards

Version 1 contains a small set of simple event cards.

One event destroys a placed tile.

When this card is played:
- the player is shown all placed tiles
- the player selects one tile to destroy
- the start and goal tiles cannot be targeted
- the tile the player is currently standing on cannot be targeted

The UI mirrors placement mode:
- eligible tiles are highlighted
- confirm and cancel buttons appear
- there is no rotate button
- cancelling returns the card to the hand

Destroying a tile is allowed to create strange or awkward road layouts.

If an event card has no valid targets, the player may simply cancel it.

Future event cards may use different targeting rules such as:
- orthogonal targeting
- diagonal targeting
- random tile targeting
- unrestricted map targeting

Another event draws two extra cards immediately. If fewer than two cards remain in the deck, it draws whatever is left.

Additional prototype event cards may:
- restart the current map
- rotate a placed tile
- grant a small random food or gold reward

These events should stay small and explicit. They should not grow into a generic effect system for version 1.

---

# Combat, Loot, and Inventory

Version 1 includes a simple encounter layer on top of road placement.

The goal of encounters is to add risk and reward to route planning without changing the core road-building loop.

Enemy encounters:
- are attached to some placed road tiles
- have a simple power value
- set power from the level's three-value power range: level 1 uses 1-3, level 2 uses 4-6, and so on
- trigger when the player moves onto the tile
- cost the normal 1 food movement cost before combat resolves
- damage the player by max(0, enemy power - player power)
- are removed from the tile after combat resolves
- may open a loot screen after defeat

The player has:
- food
- health
- gold
- power

Food remains the primary movement resource.

Health is lost through combat. Reaching 0 health ends the run.

Gold is a simple collected resource for the prototype.

Power comes from the player's base value plus the strongest equipped weapon bonus.

Loot may contain:
- food
- gold
- items

Food and gold loot are collected directly.

Items go into the inventory if there is space.

The inventory is a small fixed-size backpack. Weapons may provide power. For version 1, only the strongest weapon contributes to the player's power. Weapons range from +1 power for a knife to +5 power for a katana.

The loot and inventory UI should stay simple and touch-friendly. They should support direct collection and basic drag/drop backpack interaction, but should not grow into a full equipment or economy system in version 1.

---

# Win Condition

The run is won immediately when the player moves onto the goal tile at the top of the map.

A simple placeholder message such as "You won" is sufficient.

---

# Resources and Run End

Movement consumes food.

Every movement action costs 1 food.

The run ends when the player has no food remaining or health reaches 0.

Soft-lock detection, such as ending the run because no valid movement is available, is intentionally deferred.

Food should feel like a constant pressure that discourages unnecessary movement and backtracking.

---

# Main Goal of the Prototype

The prototype succeeds if players naturally begin thinking things like:
- “I should save this junction for later.”
- “I may need a backup route.”
- “This dead end could trap me.”
- “I should not waste food backtracking.”
- “I need to work around this hand.”

If those feelings emerge naturally, then the core design is working.
