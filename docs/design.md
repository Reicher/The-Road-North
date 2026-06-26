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

No gameplay border. A thick visual-only forest surrounds all edges so the camera never reveals empty void. A thin outline marks the playable boundary, and very thin internal grid lines show every tile beneath roads, trees, and fixed features.

Start/goal tiles are permanent. Road openings may never point outside the map.

Fixed terrain: mountains block placement/movement; rivers block placement/movement; bridges are fixed crossings with road connections.

---

## Camera and Controls

Portrait mobile. Pinch to zoom, two fingers to pan. Zoom clamped between close-up and full-map view. Camera clamped to playable area plus forest margin.

On level start: shows full map, then zooms toward start. Follows pawn during movement tween, settles briefly after. Does not follow while idle.

Touch only. In placement mode: single finger = placement, two fingers = camera.

---

## Movement

Tap any map tile to select it. The selected tile gets a clear outline and a
label naming its terrain, road, and encounter where applicable. A reachable
connected road tile also shows a green confirm button; pressing that button is
the only way to begin movement to the selected tile along the shortest path.
Rules:
- Movement is orthogonal, one tile at a time, and costs 1 food per tile
- Both tiles in every step must connect toward each other (bidirectional)
- Enemies, loot, and other encounters do not affect path selection
- Backtracking is allowed if roads and food exist
- Selecting and confirming a new reachable tile during movement replaces the current destination after the active tile hop
- The confirmed destination flashes briefly
- Selecting and confirming the tile occupied by the player makes the pawn jump once without spending food
- Movement uses a tweened hop animation; destination input remains enabled during normal movement

Starting stats: 10 food, 4 health, 0 gold, 0 base power, a Walking Stick (+1 power).

Food, gold, health, max health, base power, and backpack carry between levels. Restarting a level restores level-start values. Restarting the game resets everything.

---

## Cards and Decks

Each level's deck = base deck − player removals + level deck + player special cards.

- Level 1: 18 cards (base only)
- Level 2: 30 cards (18 base + 12 authored level cards)
- Level 3: 32 cards (18 base + 14 level cards)

The 18-card base deck is generated fresh at the start of each level:
- Roads: 4 Straight, 4 Corner, 3 T-Junction, 2 Four-Way, 2 Dead End
- Encounters: exactly 1 enemy, 1 berry bush, and 1 cache, assigned to random base roads
- Events: exactly 1 Idea, 1 Lucky Find, and 1 Mirage

The Level 2 addition is generated fresh from a fixed 12-card recipe:
- Roads: 2 Straight, 1 Corner, 1 T-Junction, 1 Four-Way, 2 Dead End, 1 Bridge
- Encounters: exactly 3 enemies, 2 berry bushes, and 2 caches, assigned randomly across the eight Level 2 roads; one road stays plain
- Events: exactly 1 Trouble, 1 Idea, 1 Lucky Find, and 1 Mirage

The Level 3 addition is generated fresh from a fixed 14-card recipe:
- Roads: 2 Straight, 2 Corner, 1 T-Junction, 1 Four-Way, 3 Dead End
- Encounters: exactly 5 enemies, 2 berry bushes, and 2 caches, assigning one to every Level 3 road
- Events: exactly 1 Trouble, 1 Idea, 1 Lucky Find, 1 Mirage, and 1 Doubt

The combined deck is shuffled once at level start; no reshuffle.

The editable source of truth for these recipes is `data/deck_recipes.tres`.
Changing road, encounter, or event counts there changes the decks created by the
game. Roads without assigned encounters are plain. Every playable level must
have an authored entry.

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

Special road: **Bridge** — a straight road that may be placed on river tiles
(normal connection rules still apply). Included as a plain road in Level 2's
authored deck recipe.

Player special road cards may carry permanent encounters. Each offer receives
one of the five normal road shapes at random. These encounters remain on the
map and open whenever the player reaches their road:

- Campfire: trade 1 food for 1 health, without reducing food to 0
- Tavern: trade 1 gold for 1 food
- Witch's Hut: preview a random special card, then trade 2 health to add it
  immediately to the hand and permanently to the player's special deck
- Shrine: trade 1 food to draw 2 extra cards, without reducing food to 0

Can be rotated before placement. Some carry hidden encounters (enemy, berry
bush, cache). Total authored encounter counts before player special cards:
- Level 1: 1 enemy, 1 berry, 1 cache
- Level 2: 4 enemy, 3 berry, 3 cache
- Level 3: 6 enemy, 3 berry, 3 cache

Road cards may be rotation-locked. A lock is shown clearly on the card, fixes
its current orientation before placement, and does not otherwise change the
placed road. When each level deck is created, `level - 1` of its road cards are
chosen randomly and locked at random valid starting rotations (none in Level 1).

Placement mode:
- Preview follows drag, snaps to tiles; green = valid, red = invalid
- After release: drag preview to move it, buttons for rotate/confirm/cancel
- Double-tap preview to rotate; confirm only active when valid
- Must be on an empty tile within Sight. The player starts with Sight 2.

During road placement and directed event targeting, cells within Sight are shown
normally and all cells outside Sight are dimmed with fog-of-war. The overlay is
hidden during normal movement and other game states. The world outside the
playable map boundary is always covered by fog-of-war while the overlay is active.

Validity requires: empty tile, within Sight, connects correctly to player's tile, matches all neighboring connections, no openings off-map. Only the current preview shows validity — no advance hints.

---

## Event Cards

Authored deck events and shop-only special events:

| Event | Effect |
|-------|--------|
| Mirage | Destroy a placed tile |
| Idea | Draw 2 extra cards |
| Doubt | Rotate a placed tile to another valid orientation |
| Lucky Find | Gain 3 food or 4 gold |
| Clear Path | Remove encounter from a road (shop-only special) |
| Trouble | Add enemy to a road |
| Wild Berries | Add berry bush to a road (shop-only special) |
| Lost Belongings | Add cache to a road (shop-only special) |
| Sleep | Discard full hand, redraw to normal hand size (shop-only special) |
| It Was All a Dream | Restart level with fresh shuffle and reset state (shop special) |

Targeting rules: same Sight as road placement. Cannot target start, goal, or player's tile. Clear Path requires an encounter present; Trouble/Wild Berries/Lost Belongings require no encounter. Mirage/Doubt share targeting restrictions. Doubt only offers functionally different rotations that still obey map-edge and neighboring-connection placement rules; a road with no alternative valid rotation cannot be targeted.

## Graveyard

The base deck contains one permanent Graveyard encounter, assigned randomly to
an otherwise plain base road. Its road is surrounded by gravestones and crosses.
Each time the player enters it, one random unlocked road card from the remaining
base draw pile or current hand is locked in its current orientation. The lock is
a permanent run modifier once the level is completed and is then reapplied when
the base deck is rebuilt for later levels. Restarting the current level, including
with It Was All a Dream, restores the locks from level start and discards any
Graveyard locks gained during that level. Nothing happens if every remaining
base road is already locked. The Graveyard remains on the map and can therefore
lock multiple cards during one level.

If no valid targets exist, the player may cancel. Destroying tiles may create awkward layouts.

---

## Combat, Loot, and Inventory

Encounters add risk/reward to route planning without changing the road-building loop.

**Enemies:** power is uniformly rolled from `level` to `level + 2`, giving an average of `level + 1` (L1: 1–3, L2: 2–4, L3: 3–5). All enemy encounters in the current level use that level's range, including enemies added by road cards and Trouble. Attempting combat first moves the player onto the enemy tile and immediately spends the normal 1 food. Each Fight rolls `player_power + 1d6` against `enemy_power + 1d6`. A higher player score defeats and removes the enemy and grants loot. A higher enemy score deals exactly 1 health damage; a tie deals no damage. Defeat and tie keep the combat dialog open, allowing another Fight or a Retreat. Retreat moves the player back to the previous tile without another food cost and leaves the enemy unchanged.

Enemy power-number color communicates risk before combat by comparing player power to enemy power: red at -2 or lower, orange at -1, yellow at equal power, light green at +1, and green at +2 or higher. After moving onto the enemy tile, a blocking popup shows power symbols and values for both fighters with `VS` between them, square pip dice showing `?`, and unknown totals below a visible full-width sum line. A `+` sits beside the player die on the dice row. The popup blocks other input without tinting the map or resource UI. Fight and Retreat remain visible but disabled while dice animate. Fight reveals both pip dice, plain totals, and Victory/Defeat/Tie. Defeat and Tie re-enable Fight and Retreat. Victory removes the enemy, resolves loot, and replaces both buttons with **OK**; pressing OK closes the popup and continues gameplay. A defeat at 0 health closes combat and immediately starts the normal death flow.

**Player power** = base power + Power from all carried items.

**Loot:** Berry bushes → food. Caches → exactly one item. Enemies → gold only. Food/gold collected directly; items go to inventory if space exists (drag or Take All).

**Items:** Every item has a `stats` dictionary, calculated `item_score`, dynamic
`rarity`, and `size`. Supported stats are Max Health, Power, Sight, and Max Hand
Size; more stat keys may be added later. Stats may be positive or negative, so
some items can trade one stat down for a stronger bonus elsewhere. `item_score`
is the sum of stats plus a score for special effects. Items with special effects
are always at least Rare.

At game startup, all items are sorted by `item_score` and divided into Common
(50%), Uncommon (30%), Rare (15%), and Epic (5%) rank percentiles. Small catalog
rounding keeps the highest-ranked item Epic. A cache first rolls rarity with the
same 50/30/15/5 distribution, then uniformly chooses an item from that group.
Every item is available from level 1; cache loot is not level-specific.

**Inventory:** 3-slot backpack, starts with Walking Stick. Every carried item is
active and contributes its stats. The backpack may contain at most one `large`
item, while `small` items have no size-specific limit. Heavier weapons are
large, while Dagger and Hatchet are small weapons. Binoculars, Goldsmith's
Scale, Guiding Charm, Watchman's Lantern, and Traveler's Pack are small; Field
Medic's Bag is large equipment. Item icons show `▲` for large and `•` for small.

Items: Walking Stick +1 Power, Short Blade +1 Power, Bent Spear +2 Power/-1
Sight, Old Sword +2 Power/-1 Sight, Dagger +2 Power, Hatchet +3 Power, Hunter's
Knife +1 Power/+1 Sight, Heavy Club +4 Power/-1 Sight, Scout's Spear +3 Power/+1
Max Hand Size, Cursed Blade +7 Power/-1 Max Hand Size, Watchman's Lantern +2
Sight/-1 Power, Traveler's Pack +1 Max Health/+1 Max Hand Size/-1 Power, Machete
+4 Power, Sword +5 Power, Mace +6 Power, Spear +7 Power, Sword & Shield +8
Power/+1 Max Health, Great Axe +9 Power. Utility effects: Binoculars +1 Sight,
Goldsmith's Scale doubles gold gained, Field Medic's Bag +2 Max Health, and
Guiding Charm +1 Max Hand Size.

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
