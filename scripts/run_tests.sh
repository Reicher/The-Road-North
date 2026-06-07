#!/usr/bin/env bash
set -euo pipefail

if [[ -n "${GODOT_BIN:-}" ]]; then
	godot_bin="${GODOT_BIN}"
elif command -v godot >/dev/null 2>&1; then
	godot_bin="$(command -v godot)"
elif command -v godot4 >/dev/null 2>&1; then
	godot_bin="$(command -v godot4)"
else
	printf '%s\n' "Could not find Godot. Set GODOT_BIN or install a godot/godot4 executable." >&2
	exit 127
fi

if [[ ! -x "${godot_bin}" ]]; then
	printf 'Godot executable is not runnable: %s\n' "${godot_bin}" >&2
	exit 126
fi

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
	tests/test_level_scene.gd
	tests/test_level_progression.gd
)

for test_script in "${tests[@]}"; do
	printf 'RUN %s\n' "${test_script}"
	output_file="$(mktemp)"
	if ! "${godot_bin}" --headless --path . -s "${test_script}" 2>&1 | tee "${output_file}"; then
		rm -f "${output_file}"
		exit 1
	fi
	if grep -E "^(ERROR|SCRIPT ERROR|WARNING):" "${output_file}" >/dev/null; then
		printf 'Godot reported errors or warnings while running %s.\n' "${test_script}"
		rm -f "${output_file}"
		exit 1
	fi
	rm -f "${output_file}"
done
