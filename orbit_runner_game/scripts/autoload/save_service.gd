extends Node
## Persists a single versioned JSON document in user://.
##
## Writes are atomic: data goes to a temp file first, the previous save is kept
## as a backup, then the temp file replaces the save. Loading falls back to the
## temp file and then the backup if the main file is missing or corrupt.

signal saved

const SAVE_PATH := "user://orbit_runner_save.json"
const TEMP_PATH := "user://orbit_runner_save.tmp"
const BACKUP_PATH := "user://orbit_runner_save.bak"
## Bump when the layout changes and add a step to _migrate().
const DATA_VERSION := 1
const SAVE_DELAY := 0.4

var data: Dictionary = {}
## False while validation tools play levels: progress stays in memory only.
var persist := true
var _dirty := false
var _timer: Timer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_timer = Timer.new()
	_timer.one_shot = true
	_timer.wait_time = SAVE_DELAY
	_timer.timeout.connect(save_now)
	add_child(_timer)
	load_data()


func load_data() -> void:
	var loaded := _read(SAVE_PATH)
	if loaded.is_empty():
		loaded = _read(TEMP_PATH)
	if loaded.is_empty():
		loaded = _read(BACKUP_PATH)
	data = _migrate(loaded)


## Returns the dictionary stored under `name`, creating it if needed.
func section(name: String) -> Dictionary:
	if not data.has(name) or typeof(data[name]) != TYPE_DICTIONARY:
		data[name] = {}
	return data[name]


## Schedules a save shortly; several requests in a row produce one write.
func request_save() -> void:
	if not persist:
		return
	_dirty = true
	if _timer.is_stopped():
		_timer.start()


func save_now() -> void:
	_timer.stop()
	if not persist:
		return
	data["version"] = DATA_VERSION
	data["saved_at"] = Time.get_unix_time_from_system()
	var text := JSON.stringify(data, "\t")
	var file := FileAccess.open(TEMP_PATH, FileAccess.WRITE)
	if file == null:
		push_error("SaveService: cannot write %s (%s)" % [TEMP_PATH, FileAccess.get_open_error()])
		return
	file.store_string(text)
	file.flush()
	file.close()
	var dir := DirAccess.open("user://")
	if dir == null:
		push_error("SaveService: cannot open user://")
		return
	if dir.file_exists(SAVE_PATH.get_file()):
		if dir.file_exists(BACKUP_PATH.get_file()):
			dir.remove(BACKUP_PATH.get_file())
		dir.rename(SAVE_PATH.get_file(), BACKUP_PATH.get_file())
	var err := dir.rename(TEMP_PATH.get_file(), SAVE_PATH.get_file())
	if err != OK:
		push_error("SaveService: rename failed (%s)" % err)
		return
	_dirty = false
	saved.emit()


## Deletes every saved file and resets the in-memory data.
func wipe() -> void:
	var dir := DirAccess.open("user://")
	if dir:
		for path in [SAVE_PATH, TEMP_PATH, BACKUP_PATH]:
			if dir.file_exists(path.get_file()):
				dir.remove(path.get_file())
	data = _migrate({})


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_WM_CLOSE_REQUEST, NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_APPLICATION_FOCUS_OUT, \
		NOTIFICATION_PREDELETE:
			if _dirty:
				save_now()


func _read(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var text := FileAccess.get_file_as_string(path)
	if text.is_empty():
		return {}
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY or not parsed.has("version"):
		push_warning("SaveService: ignoring unreadable save %s" % path)
		return {}
	return parsed


func _migrate(source: Dictionary) -> Dictionary:
	var result := source.duplicate(true)
	var version := int(result.get("version", 0))
	if version == 0:
		result = {"version": 1, "settings": {}, "progress": {}}
		version = 1
	# Future layout changes: `if version == 1: ...; version = 2`.
	result["version"] = version
	return result
