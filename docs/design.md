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

The prototype currently contains two authored square levels:
- Level 1 is a 5x5 introductory map with a mountain in the center.
- Level 2 is a 7x7 map with a horizontal river and two fixed bridge crossings.

The playable area has no surrounding gameplay padding border.

The 3D world should show dense forest outside all four edges of the playable grid so angled camera views never reveal an empty void beyond small maps. This surrounding forest is visual only and does not add playable tiles.

The camera may show the surrounding visual forest, but it cannot be panned beyond that authored margin.

The grid itself should not be rendered visually as debug lines. The playable area should have a thin visible outline around its outer edge so the player can read the boundary without seeing internal grid lines.

The map starts with only the start and goal tiles placed. All other tiles are empty.

Both the start and goal positions are T-crossings rotated so their open side faces inward toward the center of the map:
- The start tile at the bottom has openings facing left, right, and up.
- The goal tile at the top has openings facing left, right, and down.

The start position is at the bottom center of the playable area. The goal position is at the top center.

For the current levels:
- 5x5 start position = `(2, 4)`, goal position = `(2, 0)`
- 7x7 start position = `(3, 6)`, goal position = `(3, 0)`

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

The camera starts by showing the full map, then zooms toward the start position. It follows the pawn while a movement tween is active and briefly settles on the destination after movement resolves. It does not continuously follow the player while idle or manually panning.

The camera position is clamped to the playable map plus a visual forest margin.

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

The player starts a new game with:
- 10 food
- 4 health
- 0 gold
- 1 base power
- a Knife that adds 1 power

Food, gold, health, max health, base power, and backpack contents carry from one completed level into the next. Restarting a level restores the values held when that level began. Restarting the game resets all progression.

The movement itself should be tweened/interpolated over a short duration so the marker appears to travel along the road rather than teleport instantly.

Movement should feel smooth and tactile, but still quick.

Gameplay interaction should be temporarily disabled during movement tweening.

---

# Cards and Decks

Version 1 uses one generated deck per level.

There is no persistent personal deck or progression between games. The current run is a sequence of two authored levels. Completing level 1 advances to level 2 while carrying player resources and inventory. Restarting the game returns to level 1 with the initial player values.

Deck size is based on map size and level:
- shortest path steps = map size - 1
- base card count = round(map size * 3.5 + 0.5)
- every three levels remove one card as a difficulty penalty
- total card count is never lower than three times the shortest path length

The current decks contain:
- Level 1, 5x5: 18 cards
- Level 2, 7x7: 25 cards

The deck composition is:
- 75% road cards
- 25% event cards

Road card subtype distribution applies only within the road card category.

The deck is shuffled randomly at the start of each level.

The hand is normally maintained at 4 cards. Idea can temporarily increase it above that size.

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
- a "Use" button appears directly below the focused card

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

Special road counts scale from map size and level. The current decks contain:
- Level 1: 3 enemy roads, 2 berry-bush roads, and 2 cache roads
- Level 2: 5 enemy roads, 3 berry-bush roads, and 3 cache roads

Encounter road cards:
- still place normal road tiles
- still use the same road connection and rotation rules
- show enough card text to communicate that an encounter is attached
- attach the encounter to the placed tile

Enemy encounters are revealed when placed so the player can see the threat on the map.

Berry-bush encounters grant food when reached. Cache encounters grant gold and may also contain a weapon.

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

Version 1 contains four event cards. Event cards repeat in order as needed when a deck contains more than four events:
- Mirage destroys a placed tile.
- Idea draws two extra cards.
- Doubt rotates a placed tile.
- Lucky Find grants either 3 food or 4 gold.

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

Idea draws two extra cards immediately after its normal replacement card is drawn. If fewer than two additional cards remain in the deck, it draws whatever is left. This can temporarily increase the hand above four cards.

Doubt uses the same targeting restrictions as Mirage. Selecting a road previews clockwise rotation; confirming requires a changed rotation, and cancelling restores the original rotation.

These events stay small and explicit rather than using a generic effect system.

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
- open a loot screen after defeat

The player has:
- food
- health
- gold
- power

Food remains the primary movement resource.

Health is lost through combat. Reaching 0 health ends the run.

Gold is a simple collected resource for the prototype.

Power comes from the player's base value plus the strongest carried weapon bonus.

Berry bushes contain food. Caches and defeated enemies always grant gold and may also contain a weapon.

Food and gold loot are collected directly.

Items go into the inventory if there is space.

The inventory is a three-slot backpack that starts with a Knife. Weapons may provide power. Only the strongest carried weapon contributes to the player's power. Weapons range from +1 power for a Knife to +5 power for a Katana.

Food and gold are collected immediately when loot opens. Item loot can be dragged into the backpack, swapped with carried items, or collected with Take All when enough slots are free. Backpack items can also be reordered by drag and drop.

---

# Win Condition

Moving onto level 1's goal opens a placeholder between-level shop screen with a Next level action. No shop interaction is implemented yet.

Moving onto level 2's goal wins the game and shows a Restart game action.

---

# Resources and Run End

Movement consumes food.

Every movement action costs 1 food.

The current level is lost when the player has no food remaining after movement resolves or health reaches 0. The loss screen restarts the current level from its captured level-start progression.

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
