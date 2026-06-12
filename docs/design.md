# Version 1 Design Document

## Overview

> Is it fun to build roads, manage a hand of cards, and navigate through a map using limited movement resources?

A calm, tactical, singleplayer mobile game on a square grid. The player travels bottom-to-top by placing road tiles from a card hand, managing food, and handling encounters. Should feel readable, tactile, and strategic on a phone.

---

## Visual Style

Angled 3D perspective (~45°) over a flat orthogonal grid. Gameplay coordinates remain square; only the camera is angled.

- Empty tiles: flat grass with a few trees
- Road tiles: raised road geometry on grass
- Player/enemies: simple 3D pawns
- Start/goal: landmark shapes
- UI (cards, stats, loot, inventory, placement controls): 2D overlays

The 3D presentation does not change any gameplay rules.

---

## Map Structure

Three authored levels:
- Level 1: 5×5, mountain at center
- Level 2: 7×7, horizontal river with two bridge crossings
- Level 3: 9×9, six scattered mountains with a pre-placed shortcut road guarded by a strong enemy

Start at bottom center, goal at top center. Both are T-crossings facing inward. Coordinates: X left→right, Y top→bottom. Current positions: 5×5 start `(2,4)` goal `(2,0)`; 7×7 start `(3,6)` goal `(3,0)`; 9×9 start `(4,8)` goal `(4,0)`.

No gameplay border. A thick visual-only forest surrounds all edges so the camera never reveals empty void. A thin outline marks the playable boundary; no internal grid lines.

Start/goal tiles are permanent. Road openings may never point outside the map.

Fixed terrain: mountains block placement/movement; rivers block placement/movement; bridges are fixed crossings with road connections.

---

## Camera and Controls

Portrait mobile. Pinch to zoom, two fingers to pan. Zoom clamped between close-up and full-map view. Camera clamped to playable area plus forest margin.

On level start: shows full map, then zooms toward start. Follows pawn during movement tween, settles briefly after. Does not follow while idle.

Touch only. In placement mode: single finger = placement, two fingers = camera.

---

## Movement

Tap an adjacent connected tile to move. Rules:
- Orthogonal only, one tile at a time, costs 1 food
- Both tiles must connect toward each other (bidirectional)
- Backtracking allowed if roads and food exist
- Tweened hop animation; input disabled during move

Starting stats: 10 food, 4 health, 0 gold, 0 base power, a Walking Stick (+1 power).

Food, gold, health, max health, base power, and backpack carry between levels. Restarting a level restores level-start values. Restarting the game resets everything.

---

## Cards and Decks

Each level's deck = base deck − player removals + level deck + player special cards.

- Level 1: 18 cards (base only)
- Level 2: 25 cards (18 base + 7 harder level cards)
- Level 3: 32 cards (18 base + 14 level cards)

Deck size formula: `round(map_size * 3.5 + 0.5)`, minus 1 card per 3 levels, floor at `shortest_path * 3`.

Composition: 75% road, 25% event. Shuffled once at level start; no reshuffle.

Hand size: 4. Using a card draws a replacement. No discard. Player may freely mix movement and placement in any order.

Player special cards are bought in the shop and persist for the run. Clear Path,
Wild Berries, Lost Belongings, and Sleep are shop-only special cards and never
appear in generated base or level decks. Base-card removals are stored as
modifiers; the authored deck is never changed.

---

## Between-Level Shop

Opens after completing a non-final level. Shows next map info, resources, backpack, and a start button.

Features:
- Sell items by dragging to sell zone
- Buy food, healing, next-map-only potions
- Two item offers (drag to empty slot)
- Three random special-card offers, without duplicate card types in one shop
- Deck overlay for viewing the full deck or removing one base or player special card (increasingly expensive)

The removal menu is unavailable when the player cannot afford the current price. Protected road types (Straight, Corner, T-Junction) cannot have their last copy removed. Potion bonuses apply only to the next map.

Special card: "It Was All a Dream" is a level card injected on levels 2+; it restarts the current level from its saved state.

---

## Hand Presentation

Cards shown in a curved arc at screen bottom, dynamically compressed to fit width.

Tap to focus (card lifts and enlarges). Drag upward to play:
- Below activation boundary: visual copy follows finger
- Above boundary: enters placement/targeting mode; hand hides half-off-screen
- Road cards become tile preview; targeted events become target preview
- Dragging back into hand cancels; releasing outside both cancels
- Release over map: preview stays, controls appear (rotate/confirm/cancel)

Immediate events (Idea, Lucky Find, Sleep, It Was All a Dream) trigger on release over map. No manual reorder in v1.

---

## Road Cards

Types: Straight, Corner, T-Junction (20%), Four-Way (15%), Dead End (20%). Straight and Corner split the remainder equally.

Special road: **Bridge** — a straight road that may be placed on river tiles (normal connection rules still apply). Injected as a level card on level 2.

Player special road cards may carry permanent encounters. Each offer receives
one of the five normal road shapes at random. These encounters remain on the
map and open whenever the player reaches their road:

- Campfire: trade 1 food for 1 health, without reducing food to 0
- Tavern: trade 1 gold for 1 food
- Witch's Hut: preview a random special card, then trade 2 health to add it
  immediately to the hand and permanently to the player's special deck
- Shrine: trade 1 food to draw 2 extra cards, without reducing food to 0

Can be rotated before placement. Some carry hidden encounters (enemy, berry bush, cache). Encounter counts scale with map size and level:
- Level 1: 4 enemy, 2 berry, 2 cache
- Level 2: 6 enemy, 3 berry, 3 cache
- Level 3: 8 enemy, 4 berry, 4 cache

Placement mode:
- Preview follows drag, snaps to tiles; green = valid, red = invalid
- After release: drag preview to move it, buttons for rotate/confirm/cancel
- Double-tap preview to rotate; confirm only active when valid
- Must be on an empty tile within orthogonal target range (default 1)

Validity requires: empty tile, within range, connects correctly to player's tile, matches all neighboring connections, no openings off-map. Only the current preview shows validity — no advance hints.

---

## Event Cards

Five generated types, four shop-only special types, and level-specific events:

| Event | Effect |
|-------|--------|
| Mirage | Destroy a placed tile |
| Idea | Draw 2 extra cards |
| Doubt | Rotate a placed tile |
| Lucky Find | Gain 3 food or 4 gold |
| Clear Path | Remove encounter from a road (shop-only special) |
| Ambush | Add enemy to a road |
| Wild Berries | Add berry bush to a road (shop-only special) |
| Lost Belongings | Add cache to a road (shop-only special) |
| Sleep | Discard full hand, redraw to normal hand size (shop-only special) |
| It Was All a Dream | Restart level with fresh shuffle and reset state (level card, levels 2+) |

Targeting rules: same orthogonal range as road placement. Cannot target start, goal, or player's tile. Clear Path requires an encounter present; Ambush/Wild Berries/Lost Belongings require no encounter. Mirage/Doubt share targeting restrictions; Doubt previews clockwise rotation.

If no valid targets exist, the player may cancel. Destroying tiles may create awkward layouts.

---

## Combat, Loot, and Inventory

Encounters add risk/reward to route planning without changing the road-building loop.

**Enemies:** power is uniformly rolled from `level` to `level + 2`, giving an average of `level + 1` (L1: 1–3, L2: 2–4, L3: 3–5). All enemy encounters in the current level use that level's range, including enemies added by road cards and Ambush. Trigger on move. Damage = max(0, enemy_power − player_power). Removed after combat. Grant gold.

**Player power** = base power + strongest carried weapon bonus.

**Loot:** Berry bushes → food. Caches → exactly one item. Enemies → gold only. Food/gold collected directly; items go to inventory if space exists (drag or Take All).

**Inventory:** 3-slot backpack, starts with Walking Stick. Weapons: Walking Stick +1, Dagger +2, Hatchet +3, Machete +4, Sword +5, Mace +6, Spear +7, Sword & Shield +8, Great Axe +9. Only strongest weapon counts.

Cache weapons normally have power from `level` to `level + 2`, evenly distributed, with a 15% chance for a rare `level + 3` weapon instead (L1: +1–3, rarely +4; L2: +2–4, rarely +5). If that power does not exist in the weapon catalog, available powers are used.

**Utility items:** Caches have a total 15% chance to contain a uniformly
selected utility item instead of a weapon.

- Binoculars: +1 target range (Manhattan distance 2)
- Goldsmith's Scale: doubles all gold gained
- Field Medic's Bag: +2 max health while carried

---

## Win/Loss

Reaching the goal on a non-final level opens the shop. Reaching the goal on level 3 wins the game.

Loss: 0 food remaining after a move, or 0 health. Loss screen restarts the level from captured level-start state. Soft-lock detection deferred.

---

## Design Goal

The prototype works if players naturally think:
- "I should save this junction for later."
- "I may need a backup route."
- "This dead end could trap me."
- "I should not waste food backtracking."
- "I need to work around this hand."
