#!/usr/bin/env zsh
set -euo pipefail

# --- Resolve Godot binary ---
# Override with GODOT_BIN env var, or auto-detect from PATH / common locations.
if [[ -z "${GODOT_BIN:-}" ]]; then
	if command -v godot &>/dev/null; then
		GODOT_BIN="godot"
	elif [[ -x "/Applications/Godot.app/Contents/MacOS/Godot" ]]; then
		GODOT_BIN="/Applications/Godot.app/Contents/MacOS/Godot"
	else
		print -u2 "ERROR: Cannot find Godot binary. Set GODOT_BIN or add godot to PATH."
		exit 1
	fi
fi

TIMEOUT_SECONDS="${TEST_TIMEOUT:-30}"
passed=0
failed=0
failed_tests=()

tests=(
	tests/test_model_assets.gd
	tests/test_camera_input_handler.gd
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
	tests/test_guiding_charm.gd
	tests/test_shop.gd
	tests/test_remove_card_shop.gd
	tests/test_special_cards.gd
	tests/test_game_over.gd
	tests/test_event_cards.gd
	tests/test_encounter_event_cards.gd
	tests/test_permanent_encounters.gd
	tests/test_rotation_locks_and_graveyard.gd
	tests/test_level_scene.gd
	tests/test_debug_level_shortcuts.gd
	tests/test_level_progression.gd
)

# Allow running a single test via argument: ./run_tests.sh tests/test_foo.gd
if [[ $# -gt 0 ]]; then
	tests=("$@")
fi

for test_script in "${tests[@]}"; do
	print "RUN  ${test_script}"
	output_file="$(mktemp)"
	test_passed=true

	if command -v timeout &>/dev/null; then
		if ! timeout "${TIMEOUT_SECONDS}" "${GODOT_BIN}" --headless --path . -s "${test_script}" 2>&1 | tee "${output_file}"; then
			test_passed=false
		fi
	else
		if ! "${GODOT_BIN}" --headless --path . -s "${test_script}" 2>&1 | tee "${output_file}"; then
			test_passed=false
		fi
	fi

	if ${test_passed} && grep -qE "^(ERROR|SCRIPT ERROR):" "${output_file}"; then
		test_passed=false
	fi

	rm -f "${output_file}"

	if ${test_passed}; then
		print "PASS ${test_script}"
		((++passed))
	else
		print "FAIL ${test_script}"
		((++failed))
		failed_tests+=("${test_script}")
	fi
done

# --- Summary ---
print ""
print "=== Results: ${passed} passed, ${failed} failed ==="
if (( failed > 0 )); then
	print "Failed tests:"
	for t in "${failed_tests[@]}"; do
		print "  - ${t}"
	done
	exit 1
fi
