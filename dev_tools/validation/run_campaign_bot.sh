#!/usr/bin/env bash
# Runs the validation bot v2 over the campaign levels.
# Usage (from orbit_runner_game/): bash ../dev_tools/validation/run_campaign_bot.sh [profile] [attempts]
GD="${GODOT:-/c/Program Files/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe}"
PROFILE="${1:-perfect}"
ATTEMPTS="${2:-1}"
# Every level of the catalog, in campaign order.
for scene in $(grep -o 'res://scenes/levels/[a-z0-9_]*\.tscn' resources/levels/level_catalog.tres); do
	timeout 240 "$GD" --headless --fixed-fps 60 --path . res://tools/bot/run_bot.tscn -- "$scene" "$PROFILE" "$ATTEMPTS" 300 2>&1 \
		| grep -E "^(BOT|SUMMARY)" | sed -E 's/"landing_margins":\[[^]]*\],//'
done
