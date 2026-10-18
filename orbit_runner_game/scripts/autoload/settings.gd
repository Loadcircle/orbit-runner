extends Node
## Player options, persisted through SaveService and applied immediately.

signal changed

enum Quality { LOW, MEDIUM, HIGH }

const DEFAULTS := {
	"master_volume": 0.9,
	"music_volume": 0.7,
	"sfx_volume": 0.9,
	"language": "",            # empty = follow the device
	"touch_scale": 1.0,
	"touch_opacity": 0.65,
	"left_handed": false,
	"quality": -1,             # -1 = choose automatically on first launch
	"max_fps": 60,
	"vibration": true,
	"camera_sensitivity": 1.0,
	"screen_shake": true,
	"show_timer": true,
	"show_ghost": true,
	"notifications": true,
}
const LANGUAGES := ["es", "en"]
const FPS_OPTIONS := [30, 60, 120]

var _values: Dictionary


func _ready() -> void:
	_values = SaveService.section("settings")
	for key in DEFAULTS:
		if not _values.has(key):
			_values[key] = DEFAULTS[key]
	if int(_values["quality"]) < 0:
		_values["quality"] = _detect_quality()
	apply()


func get_value(key: String) -> Variant:
	return _values.get(key, DEFAULTS.get(key))


func set_value(key: String, value: Variant) -> void:
	if _values.get(key) == value:
		return
	_values[key] = value
	apply()
	SaveService.request_save()


func quality() -> Quality:
	return int(get_value("quality")) as Quality


func language() -> String:
	var lang: String = get_value("language")
	if lang.is_empty():
		lang = OS.get_locale_language()
	# Unsupported device languages fall back to English.
	return lang if lang in LANGUAGES else "en"


func apply() -> void:
	_set_bus("Master", float(get_value("master_volume")))
	_set_bus("Music", float(get_value("music_volume")))
	_set_bus("SFX", float(get_value("sfx_volume")))
	TranslationServer.set_locale(language())
	Engine.max_fps = int(get_value("max_fps"))
	var viewport := get_viewport()
	if viewport:
		match quality():
			Quality.LOW:
				viewport.scaling_3d_scale = 0.75
				viewport.msaa_3d = Viewport.MSAA_DISABLED
			Quality.MEDIUM:
				viewport.scaling_3d_scale = 1.0
				viewport.msaa_3d = Viewport.MSAA_DISABLED
			Quality.HIGH:
				viewport.scaling_3d_scale = 1.0
				viewport.msaa_3d = Viewport.MSAA_2X
	changed.emit()


func vibrate(duration_ms: int) -> void:
	if bool(get_value("vibration")) and OS.has_feature("mobile"):
		Input.vibrate_handheld(duration_ms)


func _set_bus(bus_name: String, linear: float) -> void:
	var index := AudioServer.get_bus_index(bus_name)
	if index < 0:
		return
	AudioServer.set_bus_mute(index, linear <= 0.001)
	AudioServer.set_bus_volume_db(index, linear_to_db(maxf(linear, 0.001)))


func _detect_quality() -> int:
	# Mobile starts at Medium (battery/thermals); players can raise it.
	return Quality.HIGH if not OS.has_feature("mobile") else Quality.MEDIUM
