class_name GameClock
extends RefCounted
## Wall-clock time for energy, seasons, rivals and notifications.
## Local device time for now (the player can move it); the online service will
## replace it with server time. `--` user argument `clock_hours=N` shifts it
## for testing recharges and season changes without waiting.

static var offset_seconds := 0


static func now() -> int:
	return int(Time.get_unix_time_from_system()) + offset_seconds


static func today_key() -> String:
	return Time.get_date_string_from_unix_time(now())


## "1 h 05 min", "12 min", "45 s".
static func format_duration(seconds: int) -> String:
	seconds = maxi(seconds, 0)
	if seconds >= 86400:
		return "%d d %d h" % [seconds / 86400, (seconds % 86400) / 3600]
	if seconds >= 3600:
		return "%d h %02d min" % [seconds / 3600, (seconds % 3600) / 60]
	if seconds >= 60:
		return "%d:%02d" % [seconds / 60, seconds % 60]
	return "%d s" % seconds
