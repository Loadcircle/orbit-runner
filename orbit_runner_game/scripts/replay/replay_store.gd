class_name ReplayStore
extends RefCounted
## Best run per level on this device (user://replays/<key>.rpl).

const DIR := "user://replays"


static func path_for(key: String) -> String:
	return "%s/%s.rpl" % [DIR, key.validate_filename()]


static func load_best(key: String) -> RunReplay:
	var path := path_for(key)
	if not FileAccess.file_exists(path):
		return null
	return RunReplay.from_bytes(FileAccess.get_file_as_bytes(path))


## Keeps `replay` if it beats the stored one. Returns true when saved.
static func save_if_best(replay: RunReplay) -> bool:
	if not SaveService.persist:
		return false
	var current := load_best(replay.key)
	if current and current.time <= replay.time:
		return false
	DirAccess.make_dir_recursive_absolute(DIR)
	var file := FileAccess.open(path_for(replay.key), FileAccess.WRITE)
	if file == null:
		push_warning("ReplayStore: cannot write %s" % path_for(replay.key))
		return false
	file.store_buffer(replay.to_bytes())
	file.close()
	return true


static func delete_all() -> void:
	var dir := DirAccess.open(DIR)
	if dir == null:
		return
	for f in dir.get_files():
		dir.remove(f)
