#!/usr/bin/env bash
# Runs the validation bot v2 over the campaign levels.
# Usage (from orbit_runner_game/): bash ../dev_tools/validation/run_campaign_bot.sh [profile] [attempts]
GD="${GODOT:-/c/Program Files/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe}"
PROFILE="${1:-perfect}"
ATTEMPTS="${2:-1}"
for l in tutorial w1_l1 w1_l2 w1_l3 w1_l4 w2_l1 w2_l2 w2_l3 w3_l1 w3_l2 w3_l3; do
	timeout 120 "$GD" --headless --fixed-fps 60 --path . res://tools/bot/run_bot.tscn -- "res://scenes/levels/$l.tscn" "$PROFILE" "$ATTEMPTS" 300 2>&1 \
		| grep -E "^(BOT|SUMMARY)" | sed -E 's/"landing_margins":\[[^]]*\],//'
done
