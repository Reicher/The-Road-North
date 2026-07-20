# Asset Inventory

## Pictures

✅ = final image exists, 🟨 = placeholder exists, ❌ = missing

| | Filename | Dimensions | Description |
|-|----------|-----------|-------------|
| ✅ | card_base.png | 174×250 | Card background texture |
| ✅ | card_art_road_straight.svg | 132×72 | Card art for Straight Road |
| ✅ | card_art_road_corner.svg | 132×72 | Card art for Corner |
| ✅ | card_art_road_t_junction.svg | 132×72 | Card art for T-Junction |
| ✅ | card_art_road_four_way.svg | 132×72 | Card art for Four-Way Intersection |
| ✅ | card_art_road_dead_end.svg | 132×72 | Card art for Dead End |
| 🟨 | card_art_road_bridge.svg | 132×72 | Placeholder card art for Bridge (tile exists; deck injection not implemented yet) |
| ✅ | card_art_event_fallback.png | 132×72 | Fallback event card art (star) |
| ✅ | card_art_event_destroy_tile.png | 132×72 | Card art for Destroy Tile event |
| ✅ | card_art_event_draw_two.png | 132×72 | Card art for Draw Two event |
| ✅ | card_art_event_lucky_find.png | 132×72 | Card art for Lucky Find event |
| ✅ | card_art_event_rotate_tile.png | 132×72 | Card art for Rotate Tile event |
| 🟨 | card_art_event_clear_path.svg | 132×72 | Placeholder card art for Clear Path |
| 🟩 | card_art_event_trouble.png | 132×72 | Card art for Trouble |
| 🟨 | card_art_event_wild_berries.svg | 132×72 | Placeholder card art for Wild Berries |
| 🟨 | card_art_event_lost_belongings.svg | 132×72 | Placeholder card art for Lost Belongings |
| 🟨 | card_art_event_sleep.svg | 132×72 | Placeholder card art for Sleep |
| 🟨 | card_art_event_restart_level.svg | 132×72 | Placeholder card art for It Was All a Dream |
| ✅ | card_marker_enemy.png | 34×34 | Enemy encounter marker on card |
| ✅ | card_marker_berry.png | 28×28 | Berry bush encounter marker on card |
| ✅ | card_marker_cache.png | 28×28 | Cache encounter marker on card |
| ✅ | stat_health.png | 128×128 | HUD icon for health (displayed 54×54) |
| ✅ | stat_power.png | 128×128 | HUD icon for power (displayed 54×54) |
| ✅ | stat_food.png | 128×128 | HUD icon for food (displayed 54×54) |
| ✅ | stat_gold.png | 128×128 | HUD icon for gold (displayed 54×54) |
| ✅ | stat_deck.png | 128×128 | HUD icon for deck size (displayed 54×54) |
| ✅ | inventory_backpack.png | 144×144 | Backpack toggle button icon |
| ✅ | item_binoculars.png | 94×94 | Item icon: Binoculars (displayed up to 93×93) |
| ✅ | item_goldsmiths_scale.png | 94×94 | Item icon: Goldsmith's Scale (displayed up to 93×93) |
| ✅ | item_field_medics_bag.png | 94×94 | Item icon: Field Medic's Bag (displayed up to 93×93) |
| ✅ | item_walking_stick.png | 94×94 | Item icon: Walking Stick (displayed up to 93×93) |
| ✅ | item_dagger.png | 94×94 | Item icon: Dagger (displayed up to 93×93) |
| ✅ | item_hatchet.png | 94×94 | Item icon: Hatchet (displayed up to 93×93) |
| ✅ | item_machete.png | 94×94 | Item icon: Machete (displayed up to 93×93) |
| ✅ | item_sword.png | 94×94 | Item icon: Sword (displayed up to 93×93) |
| ✅ | item_mace.png | 94×94 | Item icon: Mace (displayed up to 93×93) |
| ✅ | item_spear.png | 94×94 | Item icon: Spear (displayed up to 93×93) |
| ✅ | item_sword_and_shield.png | 94×94 | Item icon: Sword & Shield (displayed up to 93×93) |
| ✅ | item_great_axe.png | 94×94 | Item icon: Great Axe (displayed up to 93×93) |
| ✅ | item_guiding_charm.png | 94×94 | Item icon: Guiding Charm (displayed up to 93×93) |
| ✅ | item_fallback.png | 94×94 | Fallback item icon for unknown items |

Pictures are grouped by role:
- Card textures and markers: `assets/images/cards/`
- Item icons: `assets/images/items/`
- Stat icons: `assets/images/stats/`
- General interface icons: `assets/images/ui/`

Raster image dimensions use even numbers and match the largest normal runtime
presentation size where practical. Reusable stat icons remain at 128×128
because they are shared by the HUD, shop chips, and in-world enemy labels.

---

## 3D Models

✅ = exists, ❌ = missing (procedural placeholder)

| | Filename | Dimensions | Description |
|-|----------|-----------|-------------|
| ✅ | player_pawn_lightblue_no_shadow.obj | low-poly, ~30 faces | Player pawn (scaled tile_size × 0.5) |
| ✅ | enemy.obj | low-poly, ~20 faces | Enemy pawn (scaled tile_size × 0.66) |
| ✅ | tree.obj | low-poly, ~12 faces | Forest/road tree (scaled tile_size × 0.7–0.9) |
| ✅ | house.obj | low-poly, ~10 faces | Start camp & goal town building (scaled tile_size × 1.0) |
| ❌ | mountain.obj | low-poly, ~20–40 faces | Mountain feature (currently two CylinderMesh cones) |
| ❌ | river.obj | low-poly, ~10–20 faces | River feature (currently a flat blue BoxMesh) |
| ❌ | bridge.obj | low-poly, ~20–40 faces | Bridge feature (currently a brown BoxMesh slab) |
| ❌ | bush.obj | low-poly, ~15–30 faces | Berry bush encounter (currently SphereMesh) |
| ❌ | cache.obj | low-poly, ~15–30 faces | Loot cache crate (currently a brown BoxMesh) |
| ❌ | question_mark.obj | low-poly, ~10 faces | Unrevealed enemy marker (currently thin BoxMesh column) |

All models live in `assets/models/`. Materials are in shared MTL files
(`the_road_north_models.mtl`, `player_pawn_lightblue.mtl`). Keep models
low-poly (≤60 faces) and untextured (colour via MTL) to match the existing
style.
