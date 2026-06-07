#!/usr/bin/env zsh
set -euo pipefail

GODOT_BIN="${GODOT_BIN:-/Users/robin.reicher/Downloads/Godot 2.app/Contents/MacOS/Godot}"

tests=(
	tests/test_model_assets.gd
	tests/test_tile_definitions.gd
	tests/test_game_balance.gd
	tests/test_roads.gd
	tests/test_player_movement.gd
	tests/test_hand.gd
	tests/test_placement_controller.gd
	tests/test_deck_controller.gd
	tests/test_weapon_loot.gd
	tests/test_enemy_combat.gd
	tests/test_loot_ui.gd
	tests/test_player_stats_ui.gd
	tests/test_inventory_ui.gd
	tests/test_game_over.gd
	tests/test_event_cards.gd
	tests/test_encounter_event_cards.gd
	tests/test_level_scene.gd
	tests/test_level_progression.gd
)

for test_script in "${tests[@]}"; do
	print "RUN ${test_script}"
	output_file="$(mktemp)"
	if ! "${GODOT_BIN}" --headless --path . -s "${test_script}" 2>&1 | tee "${output_file}"; then
		rm -f "${output_file}"
		exit 1
	fi
	if grep -E "^(ERROR|SCRIPT ERROR|WARNING):" "${output_file}" >/dev/null; then
		print "Godot reported errors or warnings while running ${test_script}."
		rm -f "${output_file}"
		exit 1
	fi
	rm -f "${output_file}"
done
