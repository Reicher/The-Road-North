# Version 1 Design Document

## Overview

The goal of version 1 is to build a small mobile-first technical demo focused entirely on one question:

> Is it fun to build roads, manage a hand of cards, and navigate through a map using limited movement resources?

The game is a calm, tactical, singleplayer experience played on a square grid. The player travels from the bottom of the map to the top by placing road tiles using cards drawn from a deck.

The game should feel readable, tactile, strategic, and pleasant to interact with on a phone.

---

## Visual Style and Perspective

The game should be viewed from a slightly elevated angled perspective, roughly 45 degrees above the ground, so the player and road tiles are seen from a soft top-down angle rather than directly overhead. The player should not appear as just the top of a head, but instead be visible slightly from the side, giving the world more depth and adventure feeling.

However, the gameplay grid itself should remain a normal square grid. Tiles should not use isometric diamonds or rotated coordinate systems. Movement and placement logic should still operate on a clean orthogonal grid with north/south/east/west adjacency.

Visually, this means:
- square gameplay coordinates
- square tile logic
- non-isometric gameplay rules
- but rendered from an angled camera perspective

The overall feel should resemble a simple stylized tabletop adventure map viewed from slightly above and at an angle.

The game is fully 2D. All rendering uses 2D sprites and assets drawn to suggest this angled perspective. There is no 3D rendering, no 3D camera, and no isometric coordinate system.


# Map Structure

The playable map is a square grid, initially 9x9.

The playable area is surrounded by a visual padding area that is always 3 tiles thick on every side. This padding exists only for camera framing and visual presentation.

The player cannot:
- walk on padding tiles
- place cards on padding tiles

The camera must never show outside this padded area.

The grid itself should not be rendered visually as debug lines. The player should feel like they are navigating a world rather than interacting with a spreadsheet.

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

---

# Camera and Controls

The game is designed primarily for portrait mobile play.

The player can:
- pinch to zoom
- use two fingers to pan the camera

Zoom is clamped between a minimum of 3 tiles visible across the screen and a maximum that shows the full playable area including its padding border.

The camera does not automatically follow the player.

The camera position must be clamped so the player can never pan outside the padded map boundaries.

All interaction should work entirely through touch.

---

# Movement

The player is represented by a simple marker or pawn.

When the player taps an adjacent tile that has a valid road connection, the player marker moves there.

Movement rules:
- only orthogonal movement
- one tile at a time
- movement costs 1 food
- movement is only allowed if both tiles connect correctly toward each other

The player starts each run with food equal to the playable map width multiplied by 3. On a 9x9 map this is 27 food. In version 1 there is no way to gain additional food.

The movement itself should be tweened/interpolated over a short duration so the marker appears to travel along the road rather than teleport instantly.

Movement should feel smooth and tactile, but still quick.

---

# Cards and Decks

Version 1 uses a single shared deck per run. There is no persistent personal deck and no progression between runs.

The deck contains one card per playable tile — on a 9x9 map that is 81 cards total. The distribution percentages apply to this total.

The player always has 5 cards in hand.

When a card is used:
- it disappears from the hand
- a new card is immediately drawn from the deck, if any remain

Cards are not reshuffled during a run.

When the deck is empty, no new cards are drawn. The player continues with whatever cards remain in hand. Having fewer than 5 cards is not a losing state. The player simply plays until they reach the goal or run out of food.

There is no discard action. The player must sometimes work with an awkward or bad hand instead of freely cycling cards.

---

# Hand Presentation

The player’s hand is displayed at the bottom of the screen.

Cards are shown overlapping slightly in a curved arc so the hand feels physical and readable on mobile screens.

When the player taps a card:
- that card moves upward and toward the center
- the surrounding cards compress slightly outward
- the selected card becomes larger and easier to read
- a "Use" button appears on the lower part of the focused card

The Use button is only visible when a card is focused. Tapping a card that is not focused only focuses it — it does not trigger any action.

Tapping the Use button on a road card enters placement mode. Tapping the Use button on an event card triggers the event immediately (or enters selection mode if the event requires a target).

Tapping a different card focuses that card instead. Tapping outside the hand deselects the current card.

The player should also be able to:
- press and hold a card
- drag it sideways
- reorder cards manually inside the hand

This reordering is purely organizational and does not trigger card usage.

The hand interaction should feel tactile and pleasant, almost like handling real cards.

---

# Card Types

Version 1 contains two categories of cards:
- Road Cards
- Event Cards

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

Suggested distribution:
- Straight: 30%
- Corner: 30%
- T-Junction: 20%
- Four-Way: 10%
- Dead End: 10%

Road cards can be rotated before placement.

When the player selects a road card from their hand, the game enters placement mode. In placement mode:
- a preview of the tile follows the player's finger across the map
- the preview tile is highlighted green when placement is valid
- the preview tile is highlighted red when placement is invalid
- three buttons appear below the preview: a rotate button, a confirm placement button, and a cancel button
- the rotate button turns the tile 90 degrees clockwise
- the confirm placement button is only active while the preview is green
- the cancel button exits placement mode and returns the card to the hand

A road card may only be placed:
- on an empty playable tile
- directly adjacent to the player’s current position

A placement is only valid if all of the following are true:
- the new tile is adjacent to the player's current tile
- the new tile connects correctly to the player's current tile
- the new tile connects correctly to all other neighboring tiles
- all neighboring tiles with an opening toward the new tile are matched back

It is not sufficient for the new tile to connect somewhere else in the road network. The connection must always pass through the player's current position.

---

# Event Cards

Version 1 contains two simple event cards.

One event destroys a neighboring placed tile. When this card is played, the player is shown all placed tiles adjacent to their current position and must select one to destroy. The start and goal tiles cannot be targeted. The UI for this mirrors road placement: eligible tiles are highlighted, and two buttons appear — confirm and cancel. There is no rotate button. Cancelling returns the card to the hand.

The second event draws two extra cards immediately. If fewer than two cards remain in the deck, it draws whatever is left.

These exist mainly to test whether non-road cards create interesting decisions and help prevent hard locks.

---

# Win Condition

The run is won when the player moves onto the goal tile at the top of the map.

In version 1, no further logic is needed. A simple placeholder message such as "You won" is sufficient.

---

# Resources and Run End

Movement consumes food.

Every movement action costs 1 food.

The run ends when the player runs out of food or becomes stuck with no valid moves remaining. In version 1 there is no hard lock prevention. If the player gets stuck they must restart the run manually.

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
